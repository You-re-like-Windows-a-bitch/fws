#!/bin/bash
# ============================================================
#  FWS — Setup Calamares + Xorg autostart
#  v4 — Version stable avec toutes les corrections
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
step()    { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; \
            echo -e "${CYAN}  $1${NC}"; \
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ============================================================
#  DÉTECTION Git Bash / WSL
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
        warn "Détection automatique impossible."
        read -r -p "Nom de ta distro Arch WSL > " ARCH_DISTRO
        ARCH_DISTRO=$(echo "$ARCH_DISTRO" | tr -d '\r\n')
    fi

    success "Distro : '$ARCH_DISTRO'"

    SCRIPT_DIR_WIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W)"
    SCRIPT_PATH_WSL=$(MSYS_NO_PATHCONV=1 wsl.exe -d "$ARCH_DISTRO" -u root -- \
        wslpath "$(echo "$SCRIPT_DIR_WIN" | sed 's|/|\\\\|g')/setup-calamares.sh" \
        2>/dev/null | tr -d '\r\n')

    info "Lancement dans WSL ($ARCH_DISTRO) en root..."
    MSYS_NO_PATHCONV=1 wsl.exe -d "$ARCH_DISTRO" -u root -- bash "$SCRIPT_PATH_WSL"
    exit 0
fi

# ============================================================
#  VÉRIFICATIONS
# ============================================================
if ! command -v pacman &>/dev/null; then error "Pas dans Arch WSL !"; fi
if [ "$EUID" -ne 0 ]; then exec su -c "bash $0" root; fi
success "Arch Linux WSL — root ✓"

# ─── Détection des chemins du projet ────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$SCRIPT_DIR/local-repo"
BUILD_DIR="/tmp/fws-aur-build"

PACMAN_CONF=""
for c in "$SCRIPT_DIR/releng/pacman.conf" \
         "$SCRIPT_DIR/configs/baseline/pacman.conf" \
         "$SCRIPT_DIR/configs/releng/pacman.conf" \
         "$SCRIPT_DIR/pacman.conf"; do
    [ -f "$c" ] && { PACMAN_CONF="$c"; success "pacman.conf : $c"; break; }
done
[ -z "$PACMAN_CONF" ] && error "pacman.conf introuvable !"

PACKAGES_FILE=""
for c in "$SCRIPT_DIR/releng/packages.x86_64" \
         "$SCRIPT_DIR/configs/baseline/packages.x86_64" \
         "$SCRIPT_DIR/configs/releng/packages.x86_64" \
         "$SCRIPT_DIR/packages.x86_64"; do
    [ -f "$c" ] && { PACKAGES_FILE="$c"; success "packages.x86_64 : $c"; break; }
done
[ -z "$PACKAGES_FILE" ] && error "packages.x86_64 introuvable !"

AIROOTFS=""
for c in "$SCRIPT_DIR/airootfs" \
         "$SCRIPT_DIR/configs/baseline/airootfs" \
         "$SCRIPT_DIR/releng/airootfs"; do
    [ -d "$c" ] && { AIROOTFS="$c"; success "airootfs : $c"; break; }
done
[ -z "$AIROOTFS" ] && error "airootfs introuvable !"

# ============================================================
step "ÉTAPE 1 — Outils de build"
# ============================================================
pacman -S --needed --noconfirm base-devel git || error "Échec install outils"
success "base-devel + git OK"

# ============================================================
step "ÉTAPE 2 — Rebuild Calamares depuis l'AUR"
# ============================================================
warn "Suppression ancien build et repo local..."
rm -rf "$BUILD_DIR" "$LOCAL_REPO"
mkdir -p "$LOCAL_REPO"

if ! id "fwsbuild" &>/dev/null; then
    useradd -m fwsbuild
    echo "fwsbuild ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    success "Utilisateur fwsbuild créé"
fi

mkdir -p "$BUILD_DIR"
chown fwsbuild:fwsbuild "$BUILD_DIR"

info "Clonage de calamares depuis l'AUR..."
su - fwsbuild -c \
    "git clone https://aur.archlinux.org/calamares.git $BUILD_DIR/calamares" \
    || error "Clonage échoué"

info "Build de Calamares (plusieurs minutes)..."
su - fwsbuild -c \
    "cd $BUILD_DIR/calamares && makepkg -s --noconfirm" \
    || error "Build échoué"
success "Calamares buildé ✓"

# ============================================================
step "ÉTAPE 3 — Création du repo local pacman"
# ============================================================
cp "$BUILD_DIR/calamares"/calamares-[0-9]*.pkg.tar.zst "$LOCAL_REPO/" \
    || error "Paquet introuvable"
repo-add "$LOCAL_REPO/fws-local.db.tar.gz" \
    "$LOCAL_REPO"/calamares-[0-9]*.pkg.tar.zst \
    || error "repo-add échoué"
success "Repo local prêt : $LOCAL_REPO"

# ============================================================
step "ÉTAPE 4 — Nettoyage packages.x86_64"
# ============================================================
# Supprime les paquets invalides/AUR
for pkg in "mkinitcpio-openswap" "qt5-webengine" \
           "calamares-configs" "zshcalamares" "xorg-init"; do
    if grep -q "^${pkg}$" "$PACKAGES_FILE"; then
        sed -i "/^${pkg}$/d" "$PACKAGES_FILE"
        warn "Supprimé (invalide) : $pkg"
    fi
done

# Ajoute les paquets requis
for pkg in "calamares" \
           "xorg-server" "xorg-xinit" "xorg-xrandr" "xorg-xsetroot" \
           "openbox" "ttf-dejavu" \
           "qt5-base" "qt5-svg" \
           "kpmcore" "polkit" "polkit-gnome"; do
    if ! grep -q "^${pkg}$" "$PACKAGES_FILE"; then
        echo "$pkg" >> "$PACKAGES_FILE"
        success "Ajouté : $pkg"
    else
        info "Déjà présent : $pkg"
    fi
done

# ============================================================
step "ÉTAPE 5 — Patch pacman.conf"
# ============================================================
# Supprime [community] obsolète
if grep -q "\[community\]" "$PACMAN_CONF"; then
    sed -i '/^\[community\]/,/^Include.*mirrorlist/d' "$PACMAN_CONF"
    warn "[community] supprimé"
fi

# Supprime l'ancien bloc fws-local et le réécrit proprement
sed -i '/^\[fws-local\]/,/^$/d' "$PACMAN_CONF"
PACMAN_TMP=$(mktemp)
printf '[fws-local]\nSigLevel = Optional TrustAll\nServer = file://%s\n\n' \
    "$LOCAL_REPO" > "$PACMAN_TMP"
cat "$PACMAN_CONF" >> "$PACMAN_TMP"
mv "$PACMAN_TMP" "$PACMAN_CONF"
success "[fws-local] ajouté → $LOCAL_REPO"

# ============================================================
step "ÉTAPE 6 — Config airootfs (services + Calamares)"
# ============================================================

# ─── Nettoyage des anciens fichiers ─────────────────────────
rm -f "$AIROOTFS/etc/systemd/system/calamares-autostart.service"
rm -f "$AIROOTFS/etc/systemd/system/multi-user.target.wants/calamares-autostart.service"
rm -f "$AIROOTFS/etc/systemd/system/getty@tty1.service.d/calamares.conf"
rmdir "$AIROOTFS/etc/systemd/system/getty@tty1.service.d" 2>/dev/null || true

# ─── Autologin root sur tty1 ────────────────────────────────
info "Autologin root sur tty1..."
mkdir -p "$AIROOTFS/etc/systemd/system/getty@tty1.service.d"
cat > "$AIROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf" << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF
success "Autologin configuré"

# ─── Service xorg-start ──────────────────────────────────────
info "Service xorg-start.service..."
mkdir -p "$AIROOTFS/etc/systemd/system"
cat > "$AIROOTFS/etc/systemd/system/xorg-start.service" << 'EOF'
[Unit]
Description=Xorg Display Server
After=systemd-logind.service
Wants=systemd-logind.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/Xorg :0 vt1 -nolisten tcp
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "$AIROOTFS/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/xorg-start.service \
    "$AIROOTFS/etc/systemd/system/multi-user.target.wants/xorg-start.service"
success "xorg-start.service activé"

# ─── Service calamares ───────────────────────────────────────
info "Service calamares.service..."
cat > "$AIROOTFS/etc/systemd/system/calamares.service" << 'EOF'
[Unit]
Description=Calamares Installer
After=xorg-start.service
Requires=xorg-start.service

[Service]
Type=simple
User=root
Environment=DISPLAY=:0
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/calamares
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

ln -sf /etc/systemd/system/calamares.service \
    "$AIROOTFS/etc/systemd/system/multi-user.target.wants/calamares.service"
success "calamares.service activé"

# ─── .zprofile fallback ──────────────────────────────────────
info "Création .zprofile (fallback)..."
mkdir -p "$AIROOTFS/root"
cat > "$AIROOTFS/root/.zprofile" << 'EOF'
# Fallback si les services systemd n'ont pas démarré Calamares
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ]; then
    Xorg :0 vt1 &
    sleep 2
    DISPLAY=:0 openbox &
    sleep 1
    DISPLAY=:0 calamares
fi
EOF
success ".zprofile fallback créé"

# ─── settings.conf Calamares ─────────────────────────────────
info "settings.conf Calamares..."
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

# ─── Vérification finale ─────────────────────────────────────
echo ""
info "Vérification des fichiers créés..."
for f in \
    "$AIROOTFS/etc/systemd/system/xorg-start.service" \
    "$AIROOTFS/etc/systemd/system/calamares.service" \
    "$AIROOTFS/etc/systemd/system/multi-user.target.wants/xorg-start.service" \
    "$AIROOTFS/etc/systemd/system/multi-user.target.wants/calamares.service" \
    "$AIROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf" \
    "$AIROOTFS/root/.zprofile" \
    "$AIROOTFS/etc/calamares/settings.conf"
do
    if [ -e "$f" ]; then
        success "$(basename $f)"
    else
        warn "MANQUANT : $f"
    fi
done

# ============================================================
step "NETTOYAGE"
# ============================================================
userdel -r fwsbuild 2>/dev/null || true
sed -i '/fwsbuild ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers
success "Utilisateur fwsbuild supprimé"

# ============================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Setup terminé ! Lance maintenant :         ║${NC}"
echo -e "${GREEN}║      ./build.sh                                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Séquence de boot de l'ISO :${NC}"
echo -e "  1. Boot ISO FWS"
echo -e "  2. systemd → xorg-start.service  → Xorg :0 démarre"
echo -e "  3. systemd → calamares.service   → DISPLAY=:0 calamares"
echo -e "  4. Calamares s'ouvre automatiquement ✓"
echo -e ""
echo -e "  ${CYAN}Si service échoue → fallback :${NC}"
echo -e "  autologin root tty1 → .zprofile → Xorg + Calamares"
echo ""
