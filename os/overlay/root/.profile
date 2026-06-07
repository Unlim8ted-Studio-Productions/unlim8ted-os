if [ -t 0 ] && [ "${UNLIM8TED_FIRSTBOOT_LOGIN_GUARD:-0}" != "1" ] && [ ! -f /var/lib/unlim8ted/packages-installed ]; then
    tty_path=$(tty 2>/dev/null || true)
    if [ "$tty_path" = "/dev/tty1" ] && [ -x /opt/unlim8ted/bin/firstboot-install.sh ]; then
        export UNLIM8TED_FIRSTBOOT_LOGIN_GUARD=1
        /opt/unlim8ted/bin/firstboot-install.sh || printf '\nUnlim8ted first boot install failed. Check /var/log/unlim8ted-firstboot-install.log\n'
    fi
fi
