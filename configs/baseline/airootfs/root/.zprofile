# Lance Calamares automatiquement sur tty1
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ]; then
    exec xinit /root/.xinitrc -- :0 vt1
fi
