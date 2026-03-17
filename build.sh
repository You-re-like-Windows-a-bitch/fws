#!/bin/bash

# Empêcher Git Bash de traduire automatiquement les chemins (ce qui causait C:/Program Files/Git/...)
export MSYS_NO_PATHCONV=1

set -e
trap 'echo -e "\e[31mErreur lors de l'exécution (build.sh).\e[0m"; exit 1' ERR

# Nom de ta distribution WSL (par défaut "Arch")
DISTRO_NAME="Arch"

# Si on est déjà dans WSL, on ne relance pas wsl.exe (c'est inutile et cela casse)
if [ -n "$WSL_DISTRO_NAME" ]; then
    echo -e "\e[36mBuild exécuté depuis WSL ($WSL_DISTRO_NAME) en tant que root...\e[0m"
    DISTRO_NAME="$WSL_DISTRO_NAME"
    IN_WSL=1
else
    echo -e "\e[36mLancement du processus de build dans WSL ($DISTRO_NAME) en tant que root...\e[0m"
fi

# Si on n'est pas déjà dans WSL, on execute le build dans la distribution via wsl.exe
if [ -z "$IN_WSL" ]; then
    # On envoie tout le script bash directement dans WSL via l'entrée standard
    # WSL démarre automatiquement dans le dossier actuel traduit sous Linux (ex: /mnt/e/dev/fws)
    wsl.exe -d "$DISTRO_NAME" -u root bash << 'EOF'
    set -e

# $PWD sera la traduction exacte de là où tu as lancé le script
WORK_DIR="$PWD"

echo "==> Dossier de travail : $WORK_DIR"

echo "==> Mise à jour et installation de archiso..."
pacman -Sy --noconfirm archiso

echo "==> Préparation de l'environnement de build (système de fichiers Linux natif)..."
rm -rf /tmp/fws-build
mkdir -p /tmp/fws-build/releng
cp -ar "$WORK_DIR/configs/releng/"* /tmp/fws-build/releng/

# Sous Windows, git ajoute parfois des retours à la ligne `\r\n` (CRLF) qui font planter le bash d'Arch.
# On force la conversion de tous les fichiers textes vers le format UNIX (`\n`) !
echo "==> Correction des retours à la ligne Windows (dos2unix)..."
pacman -S --needed --noconfirm dos2unix
find /tmp/fws-build/releng -type f -exec dos2unix {} + 2>/dev/null

echo "==> Lancement de mkarchiso..."
mkdir -p "$WORK_DIR/out"
mkarchiso -v -w /tmp/fws-build/work -o "$WORK_DIR/out" /tmp/fws-build/releng

echo "==> Nettoyage..."
rm -rf /tmp/fws-build/work

echo "==> Build terminé ! L'ISO se trouve dans le dossier 'out' de ton projet sous Windows."
EOF
else
    # On est déjà dans WSL, on exécute directement les mêmes étapes

    # $PWD sera la traduction exacte de là où tu as lancé le script
    WORK_DIR="$PWD"

    echo "==> Dossier de travail : $WORK_DIR"

    echo "==> Mise à jour et installation de archiso..."
    pacman -Sy --noconfirm archiso

    echo "==> Préparation de l'environnement de build (système de fichiers Linux natif)..."
    rm -rf /tmp/fws-build
    mkdir -p /tmp/fws-build/releng
    cp -ar "$WORK_DIR/configs/releng/"* /tmp/fws-build/releng/

    # Sous Windows, git ajoute parfois des retours à la ligne `\r\n` (CRLF) qui font planter le bash d'Arch.
    # On force la conversion de tous les fichiers textes vers le format UNIX (`\n`) !
    echo "==> Correction des retours à la ligne Windows (dos2unix)..."
    pacman -S --needed --noconfirm dos2unix
    find /tmp/fws-build/releng -type f -exec dos2unix {} + 2>/dev/null

    echo "==> Lancement de mkarchiso..."
    mkdir -p "$WORK_DIR/out"
    mkarchiso -v -w /tmp/fws-build/work -o "$WORK_DIR/out" /tmp/fws-build/releng

    echo "==> Nettoyage..."
    rm -rf /tmp/fws-build/work

    echo "==> Build terminé ! L'ISO se trouve dans le dossier 'out' de ton projet sous Windows."
fi

echo -e "\e[32mScript de build terminé avec succès.\e[0m"

