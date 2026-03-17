# 🚀 FWS
![Stars](https://img.shields.io/github/stars/You-re-like-Windows-a-bitch/fws?style=for-the-badge&color=yellow)
![Commits](https://img.shields.io/github/commit-activity/m/You-re-like-Windows-a-bitch/fws?style=for-the-badge&color=blue)
![Issues](https://img.shields.io/github/issues/You-re-like-Windows-a-bitch/fws?style=for-the-badge&color=orange)
![Forks](https://img.shields.io/github/forks/You-re-like-Windows-a-bitch/fws?style=for-the-badge&color=808080)
![Last Commit](https://img.shields.io/github/last-commit/You-re-like-Windows-a-bitch/fws?style=for-the-badge&color=blue)

> **Un live CD basé sur Arch Linux customisé et optimisé (FWS), qui peut être généré automatiquement depuis l'environnement WSL de Windows.**

---

## 🧐 Aperçu
![AntiAdBlockZone](Asset/Img/banner.png)

## ✨ Fonctionnalités
- ✅ **Base Arch Linux** : Profite d'un système live léger, moderne et à jour.
- ✅ **Build Facile via Windows** : Un script de build `build.sh` permet la création automatique de l'ISO FWS depuis ton environnement Windows en utilisant WSL.
- ✅ **Intégration Outils** : Personnalisation de l'invite de commande et configuration avec `fastfetch` pré-installé.

## 🛠 Tech Stack
| Technologie | Usage |
| :--- | :--- |
| ![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white) | Scripts de génération et paramétrage système |
| ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=arch-linux&logoColor=white) | Système d'exploitation et environnement parent |
| ![WSL](https://img.shields.io/badge/WSL-0x0078D6?style=flat-square&logo=windows&logoColor=white) | Compilation et exécution du build sous Windows |

## 🚀 Installation & Lancement

1. **Cloner le projet**
   ```bash
   git clone https://github.com/You-re-like-Windows-a-bitch/fws.git
   cd fws
   ```
2. **Lancer la compilation de l'ISO**
   Assurez-vous d'avoir Git Bash et WSL avec la distribution Arch d'installés (sinon le script tentera de l'installer). Exécutez :
   ```bash
   ./build.sh
   ```
3. **Récupérer l'ISO**
   L'image générée `fws-*.iso` se trouvera automatiquement dans le dossier local `out/`.

## 📖 Utilisation
  Vous pouvez utiliser l'ISO FWS dans une machine virtuelle (comme QEMU ou VirtualBox) ou la flasher sur une clé USB via BalenaEtcher ou Rufus.
  ```bash
  # Petit snippet pour booter l'ISO sur QEMU
  qemu-system-x86_64 -m 2G -boot d -cdrom out/fws-*.iso
  ```

## 🤝 Contribution
1. Forkez le projet
2. Créez votre branche (`git checkout -b feature/AmazingFeature`)
3. Commit (`git commit -m 'Add some AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## 👤 Auteur

**You-re-like-Windows-a-bitch**
![Follow](https://img.shields.io/github/followers/You-re-like-Windows-a-bitch?label=Follow%20Me&style=social)

**BlackAngelTVdev**
![Follow](https://img.shields.io/github/followers/BlackAngelTVdev?label=Follow%20Me&style=social)

**fkDeath**
![Follow](https://img.shields.io/github/followers/fkDeath?label=Follow%20Me&style=social)

---
## 📄 Licence

Ce projet est sous licence :
![GitHub License](https://img.shields.io/github/license/You-re-like-Windows-a-bitch/fws?style=flat-square&color=blue)
