#!/bin/sh
set -eu

SRC="${1:?kernel source path required}"

KCONFIG="$SRC/drivers/misc/Kconfig"
MAKEFILE="$SRC/drivers/misc/Makefile"
DRIVER="$SRC/drivers/misc/unlim8ted_identity.c"

if [ ! -f "$KCONFIG" ] || [ ! -f "$MAKEFILE" ]; then
    printf 'invalid kernel tree: %s\n' "$SRC" >&2
    exit 1
fi

if ! grep -q '^config UNLIM8TED_IDENTITY$' "$KCONFIG"; then
    python3 - "$KCONFIG" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = 'menu "Misc devices"\n'
insert = (
    'menu "Misc devices"\n\n'
    'config UNLIM8TED_IDENTITY\n'
    '    bool "Unlim8ted identity driver"\n'
    '    default n\n'
    '    help\n'
    '      Expose a small procfs entry that identifies an Unlim8ted kernel build.\n'
)
if needle not in text:
    raise SystemExit("failed to find insertion point in Kconfig")
text = text.replace(needle, insert, 1)
path.write_text(text, encoding="utf-8")
PY
fi

if ! grep -q '^obj-\$(CONFIG_UNLIM8TED_IDENTITY) += unlim8ted_identity.o$' "$MAKEFILE"; then
    printf '%s\n' 'obj-$(CONFIG_UNLIM8TED_IDENTITY) += unlim8ted_identity.o' >> "$MAKEFILE"
fi

cat > "$DRIVER" <<'EOF'
// SPDX-License-Identifier: GPL-2.0
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <generated/utsrelease.h>

#define UNLIM8TED_PROC_NAME "unlim8ted_identity"

static int unlim8ted_identity_show(struct seq_file *m, void *v)
{
    seq_puts(m, "name=Unlim8ted OS\n");
    seq_puts(m, "component=kernel\n");
    seq_printf(m, "release=%s\n", UTS_RELEASE);
    seq_printf(m, "build=%s %s\n", __DATE__, __TIME__);
    return 0;
}

static int unlim8ted_identity_open(struct inode *inode, struct file *file)
{
    return single_open(file, unlim8ted_identity_show, NULL);
}

static const struct proc_ops unlim8ted_identity_proc_ops = {
    .proc_open = unlim8ted_identity_open,
    .proc_read = seq_read,
    .proc_lseek = seq_lseek,
    .proc_release = single_release,
};

static int __init unlim8ted_identity_init(void)
{
    if (!proc_create(UNLIM8TED_PROC_NAME, 0444, NULL, &unlim8ted_identity_proc_ops))
        return -ENOMEM;

    pr_info("unlim8ted_identity: registered /proc/%s\n", UNLIM8TED_PROC_NAME);
    return 0;
}

static void __exit unlim8ted_identity_exit(void)
{
    remove_proc_entry(UNLIM8TED_PROC_NAME, NULL);
}

module_init(unlim8ted_identity_init);
module_exit(unlim8ted_identity_exit);

MODULE_DESCRIPTION("Unlim8ted identity driver");
MODULE_AUTHOR("Unlim8ted");
MODULE_LICENSE("GPL");
EOF

printf '[unlim8ted] installed custom kernel feature into %s\n' "$SRC"
