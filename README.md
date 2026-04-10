# Arch Install Script

Installateur interactif Arch Linux en CLI/TUI, pense pour couvrir un flux complet depuis le Live ISO jusqu'a un systeme preconfigure avec environnement de bureau, shell utilisateur et extras utiles.

> W.I.P.
> 
> Ce projet est encore en cours de developpement. Il est experimental, destructif, et ne remplace pas encore un outil stable pour une installation critique.

## Vision

L'idee est simple: proposer un installateur dans l'esprit d'`archinstall`, mais avec une approche plus large, plus configurable, et plus orientee "power user".

Le script cherche a couvrir:

- partitionnement et preparation du disque
- installation de la base Arch
- configuration du bootloader
- configuration reseau, audio et session graphique
- choix du noyau, de l'environnement de bureau ou du window manager
- options avancees comme LUKS, LVM, btrfs, Chaotic-AUR, linux-tkg
- personnalisation utilisateur avec Bash ou Zsh, Oh My Zsh, Powerlevel10k et fastfetch

## Etat Actuel

Le script supporte deja une grosse partie du flux d'installation, mais le projet reste en W.I.P.

Fonctionnalites actuellement presentes:

- menu interactif type TUI avec `whiptail`
- partitionnement manuel, `cfdisk` ou automatique
- gestion de GRUB et `systemd-boot`
- stockage standard, LUKS root, LUKS + LVM, btrfs avec sous-volumes
- choix reseau: `NetworkManager`, `systemd-networkd`, `iwd` ou aucun
- choix audio: `PipeWire`, `PulseAudio` ou ALSA only
- choix desktop / WM: GNOME, KDE Plasma, XFCE, LXQt, Hyprland, i3, IceWM, Sway, Labwc ou TTY only
- choix du shell utilisateur: Bash ou Zsh
- installation optionnelle de `oh-my-zsh` et `powerlevel10k`
- installation optionnelle d'utilitaires: `fastfetch`, `btop`, `neovim`, `tmux`, `fzf`, `ripgrep`, `fd`, `bat`, `eza`, `zip`, `unzip`, `reflector`
- generation automatique de la config `fastfetch`
- prise en charge de noyaux officiels, noyaux custom, et `linux-tkg` via build upstream interactif
- integration Chaotic-AUR
- logs verbeux pendant l'installation

## Limitations Connues

- W.I.P.: le script n'est pas encore considere comme "production ready"
- UEFI uniquement
- pas de gestion RAID pour le moment
- les chemins avances doivent encore etre testes plus largement en condition reelle
- une mauvaise selection de disque ou de formatage peut detruire des donnees

## Installation

Depuis le Live ISO Arch Linux:

```bash
chmod +x script.sh
./script.sh
```

Le script doit etre lance en root depuis un environnement Arch ISO compatible UEFI.

## Ce Que Le Script Configure

Le flux d'installation peut inclure selon tes choix:

- `pacstrap` de la base systeme
- generation du `fstab`
- configuration locale, timezone, hostname et users
- activation des services systeme
- installation du bootloader
- configuration de la session graphique
- personnalisation du shell utilisateur
- ajout d'une config `fastfetch` dans `~/.config/fastfetch/config.jsonc`

## Philosophie

Ce repo ne cherche pas a faire un simple wrapper minimal autour des commandes Arch.

Le but est plutot de construire un vrai installeur interactif maison, lisible, hackable, et extensible, avec une approche orientee:

- controle utilisateur
- options avancees
- debug visible pendant l'installation
- personnalisation post-install des la premiere session

## Roadmap

Quelques axes probables pour la suite:

- durcir les validations avant operations destructives
- etendre les options post-install
- ajouter plus de profils desktop et shell
- ameliorer les conflits de paquets custom et les cas limites
- renforcer les tests en VM et sur materiel reel
- documenter davantage les flux avances

## Avertissement

Ce script peut partitionner, formater et modifier des disques.

Si tu l'utilises, fais-le uniquement:

- sur une machine de test
- dans une VM
- ou en sachant exactement ce que tu fais

Toujours verifier le disque cible, les partitions et les options de formatage avant de lancer l'installation.

## Statut

**W.I.P. - Experimental Arch installer**

Le projet avance, mais il est encore en construction.