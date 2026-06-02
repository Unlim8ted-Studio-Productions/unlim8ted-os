import argparse
import json
import os
import subprocess
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


RUNTIME_LOG = os.path.join(os.path.dirname(__file__), "solver_server_runtime.log")


def write_log(message):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {message}"
    print(line, flush=True)
    with open(RUNTIME_LOG, "a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def detect_solver_dependencies():
    modules = {}
    errors = {}
    for module_name in ("numpy", "scipy", "sfepy", "trimesh"):
        try:
            module = __import__(module_name)
            modules[module_name] = getattr(module, "__version__", "unknown")
        except Exception as exc:
            modules[module_name] = None
            errors[module_name] = str(exc)
    return modules, errors


def read_log_tail(log_path, max_lines=8):
    if not log_path or not os.path.isfile(log_path):
        return []
    try:
        with open(log_path, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.readlines()
    except OSError:
        return []
    return [line.rstrip() for line in lines[-max_lines:] if line.rstrip()]


def update_job(server, job_id, **fields):
    with server.jobs_lock:
        job = server.jobs.get(job_id)
        if job is None:
            return None
        job.update(fields)
        return dict(job)


def start_solver_job(server, case_dir, runner_path, case_name):
    log_path = os.path.join(case_dir, "sfepy_server.log")
    job_id = uuid.uuid4().hex
    job = {
        "job_id": job_id,
        "case_name": case_name or os.path.basename(case_dir),
        "case_dir": case_dir,
        "runner_path": runner_path,
        "log_path": log_path,
        "status": "queued",
        "message": "Queued for solve",
        "created_at": time.time(),
        "started_at": None,
        "completed_at": None,
        "return_code": None,
    }
    with server.jobs_lock:
        server.jobs[job_id] = job

    def run_job():
        server.last_case_dir = case_dir
        server.last_status = f"running:{job_id}"
        update_job(server, job_id, status="running", message="Running solver", started_at=time.time())
        write_log(f"solve job started id='{job_id}' case='{job['case_name']}' case_dir='{case_dir}'")
        try:
            with open(log_path, "w", encoding="utf-8") as handle:
                process = subprocess.Popen(
                    [sys.executable, runner_path],
                    cwd=case_dir,
                    stdout=handle,
                    stderr=subprocess.STDOUT,
                    text=True,
                )
                return_code = process.wait()
            if return_code == 0:
                update_job(
                    server,
                    job_id,
                    status="ok",
                    message="Solve completed",
                    completed_at=time.time(),
                    return_code=return_code,
                )
                server.last_status = "ok"
                write_log(f"solve job completed id='{job_id}' case_dir='{case_dir}' log='{log_path}'")
                return
            update_job(
                server,
                job_id,
                status="error",
                message=f"Solve failed, see {log_path}",
                completed_at=time.time(),
                return_code=return_code,
            )
            server.last_status = f"solve_failed: {log_path}"
            write_log(
                f"solve job failed id='{job_id}' case_dir='{case_dir}' "
                f"return_code={return_code} log='{log_path}'"
            )
        except OSError as exc:
            update_job(
                server,
                job_id,
                status="error",
                message=f"Failed to start solver: {exc}",
                completed_at=time.time(),
            )
            server.last_status = f"start_failed: {exc}"
            write_log(f"solve job start failed id='{job_id}' case_dir='{case_dir}' error='{exc}'")

    thread = threading.Thread(target=run_job, name=f"heatsim-solve-{job_id[:8]}", daemon=True)
    thread.start()
    return job


class SolverHandler(BaseHTTPRequestHandler):
    server_version = "HeatSimSolverServer/0.1"

    def _send(self, status_code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self._send(
                200,
                {
                    "status": "ok",
                    "solver_ready": self.server.solver_ready,
                    "python": sys.executable,
                    "uptime_s": round(time.time() - self.server.started_at, 3),
                    "last_case_dir": self.server.last_case_dir,
                    "last_status": self.server.last_status,
                    "active_jobs": sum(
                        1 for job in self.server.jobs.values() if job["status"] in {"queued", "running"}
                    ),
                    "modules": self.server.modules,
                    "module_errors": self.server.module_errors,
                },
            )
            return
        if self.path.startswith("/job/"):
            job_id = self.path.rsplit("/", 1)[-1]
            with self.server.jobs_lock:
                job = self.server.jobs.get(job_id)
            if job is None:
                self._send(404, {"status": "error", "message": f"Job not found: {job_id}"})
                return
            self._send(200, dict(job, log_tail=read_log_tail(job.get("log_path", ""))))
            return
        self._send(404, {"status": "error", "message": "Not found"})

    def do_POST(self):
        try:
            if self.path != "/solve":
                self._send(404, {"status": "error", "message": "Not found"})
                return

            length = int(self.headers.get("Content-Length", "0"))
            try:
                payload = json.loads(self.rfile.read(length).decode("utf-8"))
            except json.JSONDecodeError:
                self._send(400, {"status": "error", "message": "Invalid JSON payload"})
                return

            case_dir = payload.get("case_dir")
            runner_path = payload.get("runner_path")
            case_name = payload.get("case_name", "")
            if not case_dir or not runner_path:
                self._send(400, {"status": "error", "message": "case_dir and runner_path are required"})
                return
            if not os.path.isdir(case_dir):
                self._send(400, {"status": "error", "message": f"Case directory does not exist: {case_dir}"})
                return
            if not os.path.isfile(runner_path):
                self._send(400, {"status": "error", "message": f"Runner script does not exist: {runner_path}"})
                return
            if not self.server.solver_ready:
                self._send(
                    503,
                    {
                        "status": "error",
                        "message": "Solver server dependencies are not ready",
                        "modules": self.server.modules,
                        "module_errors": self.server.module_errors,
                    },
                )
                return

            write_log(
                f"solve request accepted case='{case_name or os.path.basename(case_dir)}' "
                f"runner='{runner_path}'"
            )
            job = start_solver_job(self.server, case_dir, runner_path, case_name)
            self._send(
                202,
                {
                    "status": "accepted",
                    "message": "Solve queued",
                    "job_id": job["job_id"],
                    "log_path": job["log_path"],
                },
            )
        except Exception as exc:
            write_log(f"request handler failure path='{self.path}' error='{exc}'")
            self._send(500, {"status": "error", "message": f"Server exception: {exc}"})

    def log_message(self, format, *args):
        write_log(format % args)


def main():
    parser = argparse.ArgumentParser(description="External SfePy solver server for the Blender Heat Sim add-on")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    write_log(f"starting solver server host={args.host} port={args.port} python='{sys.executable}'")
    server = ThreadingHTTPServer((args.host, args.port), SolverHandler)
    server.started_at = time.time()
    server.last_case_dir = ""
    server.last_status = "idle"
    server.jobs = {}
    server.jobs_lock = threading.Lock()
    server.modules, server.module_errors = detect_solver_dependencies()
    server.solver_ready = all(server.modules.get(name) for name in ("numpy", "scipy", "sfepy", "trimesh"))
    if server.solver_ready:
        write_log(
            "solver dependencies ready "
            + " ".join(f"{name}={version}" for name, version in server.modules.items())
        )
    else:
        write_log(f"solver dependencies missing errors={server.module_errors}")
    try:
        write_log("solver server ready")
        server.serve_forever()
    except KeyboardInterrupt:
        write_log("solver server interrupted")
    finally:
        server.server_close()
        write_log("solver server stopped")


if __name__ == "__main__":
    main()
