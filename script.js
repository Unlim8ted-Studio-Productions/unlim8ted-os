const revealItems = [...document.querySelectorAll(".reveal")];
const horizontalSections = [...document.querySelectorAll("[data-horizontal-section]")].map((section) => ({
  section,
  sticky: section.querySelector("[data-horizontal-sticky]"),
  track: section.querySelector("[data-horizontal-track]")
}));
const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const heroCanvas = document.querySelector("#heroModelCanvas");
const heroViewerStatus = document.querySelector("#heroViewerStatus");
const heroViewerFile = document.querySelector("#heroViewerFile");
const viewerChips = [...document.querySelectorAll(".hero__viewer-controls [data-view-file]")];
const modelActions = [...document.querySelectorAll(".model-card__action[data-view-file]")];
let heroRenderer = null;
let activeHeroFile = "main_case.scad";
let horizontalScrollCleanup = [];
let horizontalRefreshTimer = 0;
let horizontalScrollRaf = 0;
const meshCache = new Map();
const MAX_RENDER_TRIANGLES = 18000;
const HIGH_DETAIL_TRIANGLES = 9000;
const meshFileMap = {
  "main_case.scad": "./3d/STL/Main_Case.stl",
  "Back_Cover.scad": "./3d/STL/Back_Cover.stl",
  "Bottom_cover.scad": "./3d/STL/Bottom_Cover.stl",
  "Compute_module_holder.scad": "./3d/STL/Compute Module Plane.stl",
  "Battery_holder.scad": "./3d/STL/Battery_Holder.stl",
  "Battery_controller_holder.scad": "./3d/STL/Battery_Controller_Holder.stl",
  "Camera_bump.scad": "./3d/STL/Back_Cover_Camera_Bump.stl",
  "TypeC_Entrance.scad": "./3d/STL/Type_C_Port_Entrance.stl",
  "phone.stl": "./3d/STL/phone.stl"
};

boot();

function boot() {
  initRevealObserver();
  initHeroViewer();
  initHorizontalScroll();

  window.addEventListener("load", queueHorizontalRefresh, { once: true });
  window.addEventListener("resize", queueHorizontalRefresh);

  document.querySelectorAll("img").forEach((image) => {
    if (!image.complete) {
      image.addEventListener("load", queueHorizontalRefresh, { once: true });
    }
  });
}

function initRevealObserver() {
  if (prefersReducedMotion || !("IntersectionObserver" in window)) {
    revealItems.forEach((item) => item.classList.add("is-visible"));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    },
    {
      threshold: 0.18,
      rootMargin: "0px 0px -10% 0px"
    }
  );

  revealItems.forEach((item) => observer.observe(item));
}

function initHorizontalScroll() {
  horizontalScrollCleanup.forEach((cleanup) => cleanup());
  horizontalScrollCleanup = [];
  window.cancelAnimationFrame(horizontalScrollRaf);
  horizontalScrollRaf = 0;

  if (prefersReducedMotion || window.innerWidth <= 900) {
    horizontalSections.forEach(({ section, sticky, track }) => {
      if (!section || !sticky || !track) return;
      section.style.height = "";
      sticky.style.height = "";
      sticky.style.position = "";
      sticky.style.top = "";
      track.style.transform = "";
      track.style.willChange = "";
    });
    return;
  }

  const measuredSections = [];

  horizontalSections.forEach(({ section, sticky, track }) => {
    if (!section || !sticky || !track) return;

    const viewportWidth = sticky.clientWidth;
    const maxShift = Math.max(0, track.scrollWidth - viewportWidth);
    if (maxShift <= 0) {
      section.style.height = "";
      sticky.style.height = "";
      sticky.style.position = "";
      sticky.style.top = "";
      track.style.transform = "";
      return;
    }

    const stickyOffset = sticky.offsetTop;
    const sectionTop = section.getBoundingClientRect().top + window.scrollY;
    const scrollDistance = maxShift;
    section.style.height = `${Math.ceil(stickyOffset + window.innerHeight + scrollDistance)}px`;
    sticky.style.height = `${window.innerHeight}px`;
    sticky.style.position = "sticky";
    sticky.style.top = "0";
    track.style.willChange = "transform";
    measuredSections.push({
      section,
      sticky,
      track,
      maxShift,
      start: sectionTop + stickyOffset,
      end: sectionTop + stickyOffset + scrollDistance
    });

    horizontalScrollCleanup.push(() => {
      section.style.height = "";
      sticky.style.height = "";
      sticky.style.position = "";
      sticky.style.top = "";
      track.style.transform = "";
      track.style.willChange = "";
    });
  });

  const updateHorizontalSections = () => {
    const currentY = window.scrollY;

    measuredSections.forEach(({ track, maxShift, start, end }) => {
      if (!track || maxShift <= 0) {
        if (track) track.style.transform = "";
        return;
      }
      const progress = end <= start ? 0 : Math.min(Math.max((currentY - start) / (end - start), 0), 1);
      const shift = Math.round(progress * maxShift);
      track.style.transform = `translate3d(${-shift}px, 0, 0)`;
    });

    horizontalScrollRaf = 0;
  };

  const scheduleHorizontalUpdate = () => {
    if (horizontalScrollRaf) return;
    horizontalScrollRaf = window.requestAnimationFrame(updateHorizontalSections);
  };

  scheduleHorizontalUpdate();
  window.addEventListener("scroll", scheduleHorizontalUpdate, { passive: true });
  horizontalScrollCleanup.push(() => {
    window.removeEventListener("scroll", scheduleHorizontalUpdate);
    window.cancelAnimationFrame(horizontalScrollRaf);
    horizontalScrollRaf = 0;
  });
}

function queueHorizontalRefresh() {
  window.clearTimeout(horizontalRefreshTimer);
  horizontalRefreshTimer = window.setTimeout(() => {
    initHorizontalScroll();
  }, 160);
}

async function initHeroViewer() {
  if (!heroCanvas) return;

  heroRenderer = createCanvasRenderer(heroCanvas, {
    backgroundTop: "rgba(35, 45, 72, 0.18)",
    backgroundBottom: "rgba(7, 8, 12, 0)"
  });
  heroRenderer.start();

  viewerChips.forEach((chip) => {
    chip.addEventListener("click", () => {
      activateViewerFile(chip.dataset.viewFile || "");
    });
  });

  modelActions.forEach((button) => {
    button.addEventListener("click", () => {
      activateViewerFile(button.dataset.viewFile || "");
    });
  });

  let dragPointerId = null;
  let lastDragX = 0;
  let lastDragY = 0;

  heroCanvas.addEventListener("pointerdown", (event) => {
    if (!heroRenderer) return;
    dragPointerId = event.pointerId;
    lastDragX = event.clientX;
    lastDragY = event.clientY;
    heroRenderer.setPointerActive(true);
    heroRenderer.setDragging(true);
    heroCanvas.setPointerCapture?.(event.pointerId);
  });

  heroCanvas.addEventListener("pointermove", (event) => {
    if (!heroRenderer) return;
    if (dragPointerId !== event.pointerId) return;
    const deltaX = event.clientX - lastDragX;
    const deltaY = event.clientY - lastDragY;
    lastDragX = event.clientX;
    lastDragY = event.clientY;
    heroRenderer.nudgeRotation(deltaX, deltaY);
  });

  const endHeroDrag = (event) => {
    if (!heroRenderer || dragPointerId !== event.pointerId) return;
    heroCanvas.releasePointerCapture?.(event.pointerId);
    dragPointerId = null;
    heroRenderer.setDragging(false);
    heroRenderer.setPointerActive(false);
  };

  heroCanvas.addEventListener("pointerenter", () => {
    heroRenderer?.setPointerActive(true);
  });

  heroCanvas.addEventListener("pointerleave", () => {
    if (dragPointerId !== null) return;
    heroRenderer?.setPointerActive(false);
    heroRenderer?.setDragging(false);
  });

  heroCanvas.addEventListener("pointerup", endHeroDrag);
  heroCanvas.addEventListener("pointercancel", endHeroDrag);

  loadHeroFile(activeHeroFile);
}

function activateViewerFile(file) {
  if (!file || file === activeHeroFile) return;
  activeHeroFile = file;
  viewerChips.forEach((node) => node.classList.toggle("is-active", node.dataset.viewFile === file));
  loadHeroFile(file);
}

async function loadHeroFile(file) {
  if (!heroRenderer) return;

  heroViewerStatus.textContent = "Loading render mesh";
  heroViewerFile.textContent = file;

  try {
    const mesh = await getMeshForFile(file);
    heroRenderer.setMesh(mesh);
    heroViewerStatus.textContent = mesh.sourceTriangleCount > mesh.triangleCount
      ? "Drag to inspect simplified preview"
      : "Drag to inspect geometry";
  } catch (error) {
    heroViewerStatus.textContent = "Viewer failed to load";
    console.error(error);
  }
}

async function getMeshForFile(file) {
  if (meshCache.has(file)) {
    return meshCache.get(file);
  }

  const meshPath = meshFileMap[file];
  if (!meshPath) {
    throw new Error(`No mesh path mapped for ${file}`);
  }

  const response = await fetch(meshPath);
  if (!response.ok) {
    throw new Error(`Failed to load ${meshPath}`);
  }

  const mesh = parseBinaryStl(await response.arrayBuffer());
  meshCache.set(file, mesh);
  return mesh;
}

function parseBinaryStl(binary) {
  const bytes = binary instanceof Uint8Array ? binary : new Uint8Array(binary);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const triangleCount = view.getUint32(80, true);
  const triangles = [];
  const stride = Math.max(1, Math.ceil(triangleCount / MAX_RENDER_TRIANGLES));
  let offset = 84;

  for (let i = 0; i < triangleCount; i += 1) {
    offset += 12;
    const vertices = [];

    for (let j = 0; j < 3; j += 1) {
      vertices.push({
        x: view.getFloat32(offset, true),
        y: view.getFloat32(offset + 4, true),
        z: view.getFloat32(offset + 8, true)
      });
      offset += 12;
    }

    if (i % stride === 0) {
      triangles.push({ vertices });
    }
    offset += 2;
  }

  return normalizeMesh(triangles, triangleCount);
}

function normalizeMesh(triangles, sourceTriangleCount = triangles.length) {
  let minX = Infinity;
  let minY = Infinity;
  let minZ = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  let maxZ = -Infinity;

  triangles.forEach((triangle) => {
    triangle.vertices.forEach((vertex) => {
      minX = Math.min(minX, vertex.x);
      minY = Math.min(minY, vertex.y);
      minZ = Math.min(minZ, vertex.z);
      maxX = Math.max(maxX, vertex.x);
      maxY = Math.max(maxY, vertex.y);
      maxZ = Math.max(maxZ, vertex.z);
    });
  });

  const center = {
    x: (minX + maxX) / 2,
    y: (minY + maxY) / 2,
    z: (minZ + maxZ) / 2
  };
  const size = Math.max(maxX - minX, maxY - minY, maxZ - minZ) || 1;
  const scale = 2 / size;

  return {
    sourceTriangleCount,
    triangleCount: triangles.length,
    allowAutoSpin: triangles.length <= HIGH_DETAIL_TRIANGLES,
    triangles: triangles.map((triangle) => {
      const vertices = triangle.vertices.map((vertex) => ({
        x: (vertex.x - center.x) * scale,
        y: (vertex.y - center.y) * scale,
        z: (vertex.z - center.z) * scale
      }));
      const edge1 = subtract(vertices[1], vertices[0]);
      const edge2 = subtract(vertices[2], vertices[0]);

      return {
        vertices,
        normal: normalizeVector(cross(edge1, edge2))
      };
    })
  };
}

function createCanvasRenderer(canvas, palette) {
  const context = canvas.getContext("2d", { alpha: true });
  const state = {
    mesh: null,
    rotation: { x: -0.5, y: 0.75 },
    targetRotation: { x: -0.5, y: 0.75 },
    spin: 0,
    isVisible: true,
    isPointerInside: false,
    isDragging: false,
    needsRender: true,
    lastFrameTime: 0
  };
  const light = normalizeVector({ x: 0.35, y: 0.72, z: 1 });
  const rimLight = normalizeVector({ x: -0.6, y: 0.1, z: 0.7 });

  if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver(
      (entries) => {
        state.isVisible = Boolean(entries[0]?.isIntersecting);
        if (state.isVisible) state.needsRender = true;
      },
      { threshold: 0.08 }
    );
    observer.observe(canvas);
  }

  function resize() {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 1.35);
    const width = Math.max(1, Math.round(rect.width * dpr));
    const height = Math.max(1, Math.round(rect.height * dpr));

    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
    }
  }

  function setMesh(mesh) {
    state.mesh = mesh;
    state.needsRender = true;
  }

  function setRotation(rotation) {
    state.targetRotation = rotation;
    state.needsRender = true;
  }

  function nudgeRotation(deltaX, deltaY) {
    state.targetRotation = {
      x: clamp(state.targetRotation.x - deltaY * 0.008, -1.2, 1.2),
      y: state.targetRotation.y + deltaX * 0.01
    };
    state.spin += deltaX * 0.0008;
    state.needsRender = true;
  }

  function setPointerActive(isPointerInside) {
    state.isPointerInside = isPointerInside;
    state.needsRender = true;
  }

  function setDragging(isDragging) {
    state.isDragging = isDragging;
    state.needsRender = true;
  }

  function start() {
    const frame = () => {
      const now = performance.now();
      const targetFps = state.isDragging ? 30 : 18;
      if (now - state.lastFrameTime >= 1000 / targetFps) {
        draw();
        state.lastFrameTime = now;
      }
      window.requestAnimationFrame(frame);
    };
    window.requestAnimationFrame(frame);
  }

  function draw() {
    if (!state.needsRender && !state.isDragging && !shouldAnimate()) {
      return;
    }

    resize();
    const width = canvas.width;
    const height = canvas.height;
    const cx = width / 2;
    const cy = height / 2;

    const gradient = context.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, palette.backgroundTop);
    gradient.addColorStop(1, palette.backgroundBottom);
    context.clearRect(0, 0, width, height);
    context.fillStyle = gradient;
    context.fillRect(0, 0, width, height);
    drawAtmosphere(context, width, height);

    if (!state.mesh) {
      state.needsRender = false;
      return;
    }

    state.rotation.x += (state.targetRotation.x - state.rotation.x) * 0.1;
    state.rotation.y += (state.targetRotation.y - state.rotation.y) * 0.1;
    if (shouldAnimate()) {
      state.spin += 0.006;
    }
    state.spin *= 0.992;

    drawGroundShadow(context, width, height, state.rotation, state.spin);

    const faces = state.mesh.triangles
      .map((triangle) => projectTriangle(triangle, state.rotation, state.spin, width, height, cx, cy, light, rimLight))
      .filter(Boolean)
      .sort((a, b) => a.depth - b.depth);

    for (const face of faces) {
      context.beginPath();
      context.moveTo(face.points[0].x, face.points[0].y);
      context.lineTo(face.points[1].x, face.points[1].y);
      context.lineTo(face.points[2].x, face.points[2].y);
      context.closePath();
      context.fillStyle = face.fill;
      context.strokeStyle = face.stroke;
      context.lineWidth = Math.max(1, width * 0.0012);
      context.fill();
      context.stroke();
    }

    state.needsRender = shouldAnimate() || state.isDragging || rotationDrifting();
  }

  function rotationDrifting() {
    return (
      Math.abs(state.targetRotation.x - state.rotation.x) > 0.001 ||
      Math.abs(state.targetRotation.y - state.rotation.y) > 0.001 ||
      Math.abs(state.spin) > 0.0005
    );
  }

  function shouldAnimate() {
    return Boolean(
      state.mesh &&
      state.isVisible &&
      !prefersReducedMotion &&
      !state.isDragging &&
      state.mesh.allowAutoSpin
    );
  }

  return { start, setMesh, setRotation, nudgeRotation, setPointerActive, setDragging };
}

function projectTriangle(triangle, rotation, spin, width, height, cx, cy, light, rimLight) {
  const rotated = triangle.vertices.map((vertex) => {
    let point = rotateY(vertex, rotation.y + spin);
    point = rotateX(point, rotation.x);
    point.z += 3.4;
    return point;
  });

  const rotatedNormal = rotateX(rotateY(triangle.normal, rotation.y + spin), rotation.x);
  if (rotatedNormal.z >= -0.05) {
    return null;
  }

  const projected = rotated.map((point) => {
    const perspective = 420 / point.z;
    return {
      x: cx + point.x * perspective * (width / 1200),
      y: cy - point.y * perspective * (height / 900),
      z: point.z
    };
  });

  const depth = (projected[0].z + projected[1].z + projected[2].z) / 3;
  const diffuse = Math.max(0.16, dot(rotatedNormal, light) * 0.72 + 0.28);
  const rim = Math.pow(Math.max(0, dot(rotatedNormal, rimLight)), 1.8) * 0.38;
  const specular = Math.pow(Math.max(0, dot(rotatedNormal, normalizeVector({ x: 0.2, y: 0.3, z: 1 }))), 8) * 0.24;
  const intensity = Math.min(1.1, diffuse + rim + specular);
  const alpha = 0.9 + Math.min(0.08, specular);

  return {
    points: projected,
    depth,
    fill: `rgba(${Math.round(56 + intensity * 128)}, ${Math.round(76 + intensity * 144)}, ${Math.round(128 + intensity * 122)}, ${alpha})`,
    stroke: `rgba(${Math.round(120 + intensity * 60)}, ${Math.round(196 + intensity * 42)}, 255, ${Math.min(0.52, 0.16 + intensity * 0.24)})`
  };
}

function drawAtmosphere(context, width, height) {
  const glowA = context.createRadialGradient(width * 0.72, height * 0.18, 0, width * 0.72, height * 0.18, width * 0.52);
  glowA.addColorStop(0, "rgba(109, 124, 255, 0.26)");
  glowA.addColorStop(1, "rgba(109, 124, 255, 0)");
  context.fillStyle = glowA;
  context.fillRect(0, 0, width, height);

  const glowB = context.createRadialGradient(width * 0.28, height * 0.74, 0, width * 0.28, height * 0.74, width * 0.42);
  glowB.addColorStop(0, "rgba(53, 214, 255, 0.16)");
  glowB.addColorStop(1, "rgba(53, 214, 255, 0)");
  context.fillStyle = glowB;
  context.fillRect(0, 0, width, height);
}

function drawGroundShadow(context, width, height, rotation, spin) {
  const shadowX = width * (0.5 + Math.sin(rotation.y + spin) * 0.06);
  const shadowY = height * 0.76 + Math.sin(rotation.x) * 18;
  context.save();
  context.fillStyle = "rgba(3, 8, 18, 0.44)";
  context.filter = "blur(24px)";
  context.beginPath();
  context.ellipse(shadowX, shadowY, width * 0.18, height * 0.06, 0, 0, Math.PI * 2);
  context.fill();
  context.restore();
}

function rotateX(point, angle) {
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  return {
    x: point.x,
    y: point.y * cos - point.z * sin,
    z: point.y * sin + point.z * cos
  };
}

function rotateY(point, angle) {
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  return {
    x: point.x * cos + point.z * sin,
    y: point.y,
    z: -point.x * sin + point.z * cos
  };
}

function subtract(a, b) {
  return {
    x: a.x - b.x,
    y: a.y - b.y,
    z: a.z - b.z
  };
}

function cross(a, b) {
  return {
    x: a.y * b.z - a.z * b.y,
    y: a.z * b.x - a.x * b.z,
    z: a.x * b.y - a.y * b.x
  };
}

function dot(a, b) {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

function normalizeVector(vector) {
  const length = Math.hypot(vector.x, vector.y, vector.z) || 1;
  return {
    x: vector.x / length,
    y: vector.y / length,
    z: vector.z / length
  };
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}
