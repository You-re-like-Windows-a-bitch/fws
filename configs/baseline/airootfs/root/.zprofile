# Fallback si les services systemd n'ont pas démarré Calamares
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ]; then
    Xorg :0 vt1 &
    sleep 2
    DISPLAY=:0 openbox &
    sleep 1
    DISPLAY=:0 calamares
fi
