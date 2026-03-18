#!/bin/bash
# ============================================================
#  FWS — Setup Calamares depuis l'AUR + Repo local
#  Autostart via autologin + .zprofile (méthode fiable)
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!!]${NC} $1"; }
error()   { echo -e "${RED}[ERR]${NC} $1"; exit 1; }
step()    { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ============================================================
IS_GITBASH=false
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || -n "$WINDIR" ]]; then
    IS_GITBASH=true
fi

if $IS_GITBASH; then
    info "Git Bash détecté — Recherche de la distro Arch dans WSL..."
    export MSYS_NO_PATHCONV=1
    export MSYS2_ARG_CONV_EXCL="*"

    ARCH_DISTRO=""
    for name in "Arch" "ArchLinux" "archlinux" "arch" "ArchWSL"; do
        if wsl.exe -d "$name" -u root -- echo "ok" > /dev/null 2>&1; then
            ARCH_DISTRO="$name"; break
        fi
    done

    if [ -z "$ARCH_DISTRO" ]; then
        warn "Impossible de détecter automatiquement."
        read -r -p "Nom de ta distro Arch WSL > " ARCH_DISTRO
        ARCH_DISTRO=$(echo "$ARCH_DISTRO" | tr -d '\r\n')
    fi

    success "Distro : '$ARCH_DISTRO'"

    SCRIPT_DIR_WIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W)"
    SCRIPT_PATH_WSL=$(MSYS_NO_PATHCONV=1 wsl.exe -d "$ARCH_DISTRO" -u root -- \
        wslpath "$(echo "$SCRIPT_DIR_WIN" | sed 's|/|\\\\|g')/setup-calamares.sh" 2>/dev/null | tr -d '\r\n')

    info "Lancement dans WSL ($ARCH_DISTRO)..."
    MSYS_NO_PATHCONV=1 wsl.exe -d "$ARCH_DISTRO" -u root -- bash "$SCRIPT_PATH_WSL"
    exit 0
fi

# ============================================================
if ! command -v pacman &>/dev/null; then error "Pas dans Arch WSL !"; fi
if [ "$EUID" -ne 0 ]; then exec su -c "bash $0" root; fi
success "Arch Linux WSL — root"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$SCRIPT_DIR/local-repo"
BUILD_DIR="/tmp/fws-aur-build"

PACMAN_CONF=""
for c in "$SCRIPT_DIR/releng/pacman.conf" "$SCRIPT_DIR/configs/baseline/pacman.conf" \
         "$SCRIPT_DIR/configs/releng/pacman.conf" "$SCRIPT_DIR/pacman.conf"; do
    [ -f "$c" ] && { PACMAN_CONF="$c"; success "pacman.conf : $c"; break; }
done
[ -z "$PACMAN_CONF" ] && error "pacman.conf introuvable !"

PACKAGES_FILE=""
for c in "$SCRIPT_DIR/releng/packages.x86_64" "$SCRIPT_DIR/configs/baseline/packages.x86_64" \
         "$SCRIPT_DIR/configs/releng/packages.x86_64" "$SCRIPT_DIR/packages.x86_64"; do
    [ -f "$c" ] && { PACKAGES_FILE="$c"; success "packages.x86_64 : $c"; break; }
done
[ -z "$PACKAGES_FILE" ] && error "packages.x86_64 introuvable !"

AIROOTFS=""
for c in "$SCRIPT_DIR/airootfs" "$SCRIPT_DIR/configs/baseline/airootfs" \
         "$SCRIPT_DIR/releng/airootfs"; do
    [ -d "$c" ] && { AIROOTFS="$c"; success "airootfs : $c"; break; }
done
[ -z "$AIROOTFS" ] && error "airootfs introuvable !"

# ============================================================
step "ÉTAPE 1 — Outils de build"
# ============================================================
pacman -S --needed --noconfirm base-devel git || error "Échec"
success "Outils OK"

# ============================================================
step "ÉTAPE 2 — Rebuild Calamares"
# ============================================================
warn "Nettoyage..."
rm -rf "$BUILD_DIR" "$LOCAL_REPO"
mkdir -p "$LOCAL_REPO"

if ! id "fwsbuild" &>/dev/null; then
    useradd -m fwsbuild
    echo "fwsbuild ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

mkdir -p "$BUILD_DIR"
chown fwsbuild:fwsbuild "$BUILD_DIR"

info "Clonage AUR..."
su - fwsbuild -c "git clone https://aur.archlinux.org/calamares.git $BUILD_DIR/calamares" || error "Clonage échoué"

info "Build Calamares..."
su - fwsbuild -c "cd $BUILD_DIR/calamares && makepkg -s --noconfirm" || error "Build échoué"
success "Build OK"

# ============================================================
step "ÉTAPE 3 — Repo local"
# ============================================================
cp "$BUILD_DIR/calamares"/calamares-[0-9]*.pkg.tar.zst "$LOCAL_REPO/"
repo-add "$LOCAL_REPO/fws-local.db.tar.gz" "$LOCAL_REPO"/calamares-[0-9]*.pkg.tar.zst
success "Repo local : $LOCAL_REPO"

# ============================================================
step "ÉTAPE 4 — packages.x86_64"
# ============================================================
for pkg in "mkinitcpio-openswap" "qt5-webengine" "calamares-configs" "zshcalamares" "xorg-init"; do
    if grep -q "^${pkg}$" "$PACKAGES_FILE"; then
        sed -i "/^${pkg}$/d" "$PACKAGES_FILE"
        warn "Supprimé : $pkg"
    fi
done

for pkg in "calamares" "xorg-server" "xorg-xinit" "xorg-xrandr" "openbox" "ttf-dejavu" \
           "qt5-base" "qt5-svg" "kpmcore" "polkit" "polkit-gnome"; do
    if ! grep -q "^${pkg}$" "$PACKAGES_FILE"; then
        echo "$pkg" >> "$PACKAGES_FILE"
        success "Ajouté : $pkg"
    fi
done

# ============================================================
step "ÉTAPE 5 — pacman.conf"
# ============================================================
if grep -q "\[community\]" "$PACMAN_CONF"; then
    sed -i '/^\[community\]/,/^Include.*mirrorlist/d' "$PACMAN_CONF"
    warn "[community] supprimé"
fi

# Supprime l'ancien bloc fws-local et le réécrit proprement
sed -i '/^\[fws-local\]/,/^$/d' "$PACMAN_CONF"
PACMAN_TMP=$(mktemp)
printf '[fws-local]\nSigLevel = Optional TrustAll\nServer = file://%s\n\n' "$LOCAL_REPO" > "$PACMAN_TMP"
cat "$PACMAN_CONF" >> "$PACMAN_TMP"
mv "$PACMAN_TMP" "$PACMAN_CONF"
success "[fws-local] → $LOCAL_REPO"

# ============================================================
step "ÉTAPE 6 — Autostart Calamares dans airootfs"
# ============================================================

# Supprime les anciens services mal configurés
rm -f "$AIROOTFS/etc/systemd/system/calamares.service"
rm -f "$AIROOTFS/etc/systemd/system/calamares-autostart.service"
rm -f "$AIROOTFS/etc/systemd/system/multi-user.target.wants/calamares-autostart.service"
rm -f "$AIROOTFS/etc/systemd/system/getty@tty1.service.d/calamares.conf"
rmdir "$AIROOTFS/etc/systemd/system/getty@tty1.service.d" 2>/dev/null || true

# ─── Autologin root sur tty1 ────────────────────────────────
info "Configuration autologin root sur tty1..."
mkdir -p "$AIROOTFS/etc/systemd/system/getty@tty1.service.d"
cat > "$AIROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf" << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF
success "Autologin root activé"

# ─── .zprofile : lance X + Calamares dès le login sur tty1 ──
info "Création de /root/.zprofile..."
mkdir -p "$AIROOTFS/root"
cat > "$AIROOTFS/root/.zprofile" << 'EOF'
# Lance Calamares automatiquement sur tty1
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ]; then
    exec xinit /root/.xinitrc -- :0 vt1
fi
EOF
success ".zprofile créé"

# ─── .xinitrc ───────────────────────────────────────────────
cat > "$AIROOTFS/root/.xinitrc" << 'EOF'
#!/bin/sh
openbox &
sleep 1
exec calamares
EOF
chmod +x "$AIROOTFS/root/.xinitrc"
success ".xinitrc créé"

# ─── settings.conf Calamares ────────────────────────────────
mkdir -p "$AIROOTFS/etc/calamares/modules"
cat > "$AIROOTFS/etc/calamares/settings.conf" << 'EOF'
---
modules-search: [ local, /usr/lib/calamares/modules ]

sequence:
  - show:
    - welcome
    - locale
    - keyboard
    - partition
    - users
    - summary
  - exec:
    - partition
    - mount
    - unpackfs
    - fstab
    - locale
    - keyboard
    - localecfg
    - users
    - initcpio
    - bootloader
    - services-systemd
    - umount
  - show:
    - finished

branding: default
prompt-install: false
dont-chroot: false
EOF
success "settings.conf créé"

# ============================================================
step "NETTOYAGE"
# ============================================================
userdel -r fwsbuild 2>/dev/null || true
sed -i '/fwsbuild ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers
success "fwsbuild supprimé"

# ============================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Tout est prêt ! Lance maintenant :     ║${NC}"
echo -e "${GREEN}║      ./build.sh                             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Séquence de boot :${NC}"
echo -e "  Boot ISO → autologin root sur tty1"
echo -e "  → .zprofile détecte tty1 → xinit → openbox → calamares"
echo ""