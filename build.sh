#!/bin/bash

export MSYS_NO_PATHCONV=1

set -e
trap 'echo -e "\e[31mErreur lors de l execution (build.sh).\e[0m"; exit 1' ERR

DISTRO_NAME="Arch"

if [ -n "$WSL_DISTRO_NAME" ]; then
    echo -e "\e[36mBuild exécuté depuis WSL ($WSL_DISTRO_NAME) en tant que root...\e[0m"
    IN_WSL=1
else
    echo -e "\e[36mLancement du processus de build dans WSL ($DISTRO_NAME) en tant que root...\e[0m"
fi

if [ -z "$IN_WSL" ]; then
    # ── Depuis Git Bash ──────────────────────────────────────
    SCRIPT_DIR_WIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W)"
    WORK_DIR_WSL=$(MSYS_NO_PATHCONV=1 wsl.exe -d "$DISTRO_NAME" -u root -- \
        wslpath "$(echo "$SCRIPT_DIR_WIN" | sed 's|/|\\\\|g')" 2>/dev/null | tr -d '\r\n')

    echo "==> Dossier de travail WSL : $WORK_DIR_WSL"

    MSYS_NO_PATHCONV=1 wsl.exe -d "$DISTRO_NAME" -u root -- bash << EOF
set -e
WORK_DIR="${WORK_DIR_WSL}"
echo "==> Dossier de travail : \$WORK_DIR"

echo "==> Mise à jour des miroirs et installation de archiso..."
pacman -Sy --noconfirm reflector || true
reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist || true
pacman -Sy --noconfirm archiso

echo "==> Préparation de l'environnement de build..."
rm -rf /tmp/fws-build
mkdir -p /tmp/fws-build/releng
cp -ar "\$WORK_DIR/configs/releng/"* /tmp/fws-build/releng/

if ls "\$WORK_DIR/local-repo/"*.pkg.tar.zst &>/dev/null 2>&1; then
    echo "==> Copie du repo local Calamares..."
    mkdir -p /tmp/fws-build/local-repo
    cp -a "\$WORK_DIR/local-repo/"* /tmp/fws-build/local-repo/

    echo "==> Injection du repo [fws-local] dans pacman.conf..."
    # Supprime tout bloc fws-local existant (peu importe son format)
    sed -i '/^\[fws-local\]/,/^\[/{ /^\[fws-local\]/d; /^SigLevel/d; /^Server/d }' \
        /tmp/fws-build/releng/pacman.conf

    # Réécrit proprement le bloc en tête du fichier
    PACMAN_TMP=\$(mktemp)
    printf '[fws-local]\nSigLevel = Optional TrustAll\nServer = file:///tmp/fws-build/local-repo\n\n' \
        > "\$PACMAN_TMP"
    cat /tmp/fws-build/releng/pacman.conf >> "\$PACMAN_TMP"
    mv "\$PACMAN_TMP" /tmp/fws-build/releng/pacman.conf

    echo "==> Vérification pacman.conf :"
    head -6 /tmp/fws-build/releng/pacman.conf
else
    echo "==> Aucun repo local détecté (local-repo/ absent ou vide)."
fi

echo "==> Correction des retours à la ligne Windows (dos2unix)..."
pacman -S --needed --noconfirm dos2unix
find /tmp/fws-build/releng -type f -exec dos2unix {} + 2>/dev/null

echo "==> Lancement de mkarchiso..."
mkdir -p "\$WORK_DIR/out"
mkarchiso -v -w /tmp/fws-build/work -o "\$WORK_DIR/out" /tmp/fws-build/releng

echo "==> Nettoyage..."
rm -rf /tmp/fws-build/work

echo "==> Build terminé ! ISO dans \$WORK_DIR/out"
EOF

else
    # ── Déjà dans WSL ────────────────────────────────────────
    WORK_DIR="$PWD"
    echo "==> Dossier de travail : $WORK_DIR"

    echo "==> Mise à jour et installation de archiso..."
    pacman -Sy --noconfirm reflector || true
    reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist || true
    pacman -Sy --noconfirm archiso

    echo "==> Préparation de l'environnement de build..."
    rm -rf /tmp/fws-build
    mkdir -p /tmp/fws-build/releng
    cp -ar "$WORK_DIR/configs/releng/"* /tmp/fws-build/releng/

    if ls "$WORK_DIR/local-repo/"*.pkg.tar.zst &>/dev/null 2>&1; then
        echo "==> Copie du repo local Calamares..."
        mkdir -p /tmp/fws-build/local-repo
        cp -a "$WORK_DIR/local-repo/"* /tmp/fws-build/local-repo/

        echo "==> Injection du repo [fws-local] dans pacman.conf..."
        sed -i '/^\[fws-local\]/,/^\[/{ /^\[fws-local\]/d; /^SigLevel/d; /^Server/d }' \
            /tmp/fws-build/releng/pacman.conf

        PACMAN_TMP=$(mktemp)
        printf '[fws-local]\nSigLevel = Optional TrustAll\nServer = file:///tmp/fws-build/local-repo\n\n' \
            > "$PACMAN_TMP"
        cat /tmp/fws-build/releng/pacman.conf >> "$PACMAN_TMP"
        mv "$PACMAN_TMP" /tmp/fws-build/releng/pacman.conf

        echo "==> Vérification pacman.conf :"
        head -6 /tmp/fws-build/releng/pacman.conf
    else
        echo "==> Aucun repo local détecté."
    fi

    echo "==> Correction des retours à la ligne Windows (dos2unix)..."
    pacman -S --needed --noconfirm dos2unix
    find /tmp/fws-build/releng -type f -exec dos2unix {} + 2>/dev/null

    echo "==> Lancement de mkarchiso..."
    mkdir -p "$WORK_DIR/out"
    mkarchiso -v -w /tmp/fws-build/work -o "$WORK_DIR/out" /tmp/fws-build/releng

    echo "==> Nettoyage..."
    rm -rf /tmp/fws-build/work

    echo "==> Build terminé ! L'ISO se trouve dans '$WORK_DIR/out'."
fi

echo -e "\e[32mScript de build terminé avec succès.\e[0m"