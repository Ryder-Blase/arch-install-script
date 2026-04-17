# arch-install-script

> **⚠ W.I.P. — expérimental, destructif, à utiliser sur VM ou matériel de test.**

Installateur interactif Arch Linux en TUI (`whiptail`), conçu pour couvrir le flux complet depuis le Live ISO jusqu'à un système entièrement configuré : stockage, bureau, shell, thème sombre et applications.

---

## Lancement

```bash
# depuis le Live ISO Arch (UEFI, root)
chmod +x script.sh
./script.sh
```

---

## Ce que le script couvre

### Stockage
| Mode | Description |
|------|-------------|
| Standard | partition(s) ext4/fat32 classiques |
| LUKS root | chiffrement de la partition root |
| LUKS + LVM | chiffrement + volumes logiques (root, home, swap) |
| btrfs | avec sous-volumes (`@`, `@home`, `@snapshots`) |

Partitionnement : manuel, `cfdisk` interactif, ou automatique.  
Mémoire : partition swap, **swapfile persistant**, et **zram** avec taille configurable.  
Bootloaders supportés : `GRUB`, `systemd-boot`.

### Noyau
- Noyaux officiels : `linux`, `linux-lts`, `linux-zen`, `linux-hardened`
- Noyau custom (URL de dépôt)
- **linux-tkg** : build depuis les sources via le script upstream, avec choix du scheduler (BMQ, BORE, PDS, MuQSS…)

### Réseau / Audio
- Réseau : `NetworkManager`, `systemd-networkd + iwd`, `iwd` seul, ou aucun
- Audio : `PipeWire`, `PulseAudio`, ou ALSA uniquement

### Environnements graphiques
| Wayland | X11 |
|---------|-----|
| GNOME | GNOME (Xorg) |
| KDE Plasma | KDE Plasma (X11) |
| Hyprland | XFCE |
| Sway | LXQt |
| Labwc | i3 |
| | IceWM |
| | TTY only |

Session : Wayland uniquement, X11 uniquement, ou les deux.  
Display managers : `GDM`, `SDDM`, `LightDM`, ou aucun (TTY).

### Shell & personnalisation utilisateur
- Shell : **Bash** ou **Zsh**
- Options Zsh : Oh My Zsh, Powerlevel10k
- `fastfetch` avec config générée (`~/.config/fastfetch/config.jsonc`)
- Aliases, historique persistant, et prompt moderne générés dans `.bashrc` / `.zshrc`

### Post-install automatique
- Création des répertoires XDG (`~/Documents`, `~/Downloads`, `~/Pictures`…) et `~/.config/user-dirs.dirs`
- **Thème sombre** appliqué automatiquement (hors GNOME/KDE, qui gèrent ça nativement) :
  - GTK 3 & 4 : `Adwaita-dark`
  - Qt via `qt5ct` / `qt6ct` + style Fusion
  - `dconf` : `prefer-dark` pour les apps libadwaita
  - Chromium : `--force-dark-mode` dans `chromium-flags.conf`
  - Variables d'environnement dans `~/.config/environment.d/` et `~/.xprofile`
- **Disposition clavier** : `setxkbmap` injecté dans `.xprofile` et `.xinitrc` pour tous les environnements X11
- Configs générées automatiquement :
  - **i3** : config complète avec keybindings, polybar, picom (optionnel), Thunar
  - **i3status** : barre de statut réseau / CPU / RAM / batterie / horloge
  - **Sway** : config complète avec waybar, swaylock, Thunar
  - **Waybar** : config JSON + CSS générée selon le compositeur (Hyprland ou Sway)
  - **Hyprland** : config complète avec keybindings et monitors

### Options système avancées
| Option | Détail |
|--------|--------|
| Chaotic-AUR | dépôt avec paquets précompilés (mesa-tkg, linux-cachyos…) |
| Suite QEMU/libvirt | `qemu-full`, `libvirt`, `virt-manager`, `dnsmasq`, OVMF, SWTPM — utilisateur ajouté au groupe `libvirt` |
| GNS3 | `gns3-gui`, `dynamips`, `ubridge`, `vpcs` via AUR + `gns3-server` via `python-pip` (`python -m pip --user --break-system-packages`) + `docker`, `wireshark-qt`, `qemu-full`, `libvirt`, `tigervnc`, `inetutils` — groupes, lien `/usr/bin/gns3server` et services configurés |
| Autologin TTY1 | override systemd getty |
| Autostart WM | `.bash_profile` / `.zprofile` avec garde TTY1 |
| Multilib | activation automatique du dépôt 32 bits |
| Bluetooth | `bluez`, `bluez-utils`, blueman |
| Avahi | mDNS / découverte réseau locale |
| CUPS | serveur d'impression installé et activé au démarrage |
| OpenSSH | serveur SSH activé |
| Swapfile / zram | création d'un fichier swap persistant dans `fstab` et génération d'une config `zram-generator` |
| os-prober | détection multi-boot |
| picom | compositeur X11 optionnel (transparence, ombres) |

### Paquets supplémentaires (sélection interactive)
**Utilitaires CLI** : `fastfetch`, `btop`, `neovim`, `tmux`, `fzf`, `ripgrep`, `fd`, `bat`, `eza`, `unzip`, `zip`, `reflector`

**Applications** : `chromium`, `firefox`, `discord`, `telegram-desktop`, `thunderbird`, `vlc`, `mpv`, `gimp`, `inkscape`, `obs-studio`, `kdenlive`, `audacity`, `steam`, `lutris`, `gamemode`, `wine`, `mangohud`  
_(lib32 automatiquement ajoutées si multilib activé)_

---

## Flux d'installation

```
1. Détection du backend TUI (whiptail / dialog)
2. Collecte interactive des options (stockage, réseau, bureau, shell, extras…)
3. Récapitulatif — confirmation avant toute opération destructive
4. Partitionnement et formatage
5. pacstrap (base + paquets sélectionnés)
6. Génération fstab
7. arch-chroot : locale, timezone, hostname, utilisateurs, bootloader, services
8. Personnalisation post-install : dotfiles, thème, configs WM/shell
9. Démontage et redémarrage
```

Logs disponibles dans `/tmp/arch-installer/install.log` pendant l'installation.

---

## Prérequis

- Live ISO Arch Linux récent
- Démarrage en mode **UEFI**
- Connexion internet active
- Lancé en **root**

---

## Limitations connues

- UEFI uniquement (pas de BIOS legacy)
- Pas de gestion RAID
- Les flux LUKS/LVM/btrfs doivent encore être testés sur plus de configurations matérielles
- **Une mauvaise sélection de disque ou de formatage détruit les données** — toujours vérifier avant de confirmer

---

## Philosophie

Le script ne cherche pas à être un wrapper minimal autour des commandes Arch.  
L'objectif est un installateur interactif lisible, hackable et extensible, orienté :

- contrôle total de l'utilisateur
- options avancées sans sacrifier la simplicité
- debug visible et logs persistants
- système opérationnel dès la première session (thème, WM, shell, apps)

---

## Statut

**W.I.P. — expérimental.**  
Convient pour des VMs, du matériel de test, ou des utilisateurs qui savent ce qu'ils font.