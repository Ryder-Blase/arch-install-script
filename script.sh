#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_VERSION="2026-04-12-main-ui-polish"
WORKDIR="/tmp/arch-installer"
LOG_FILE="$WORKDIR/install.log"
TARGET_MOUNT="/mnt"
ARCH_CONFIG_PATH="$TARGET_MOUNT/root/arch-install.conf"
ARCH_CHROOT_SCRIPT="$TARGET_MOUNT/root/arch-postinstall.sh"
UI_BACKEND=""
UI_HEIGHT=22
UI_WIDTH=86
UI_MENU_HEIGHT=14
DEBUG_INSTALL="yes"
CURRENT_STEP="Initialisation"
UI_CANCEL_STATUS=252
SCRIPT_LANG="fr"
declare -A T=()

mkdir -p "$WORKDIR"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

declare -a PACSTRAP_PACKAGES=()
declare -a OFFICIAL_PACKAGES=()
declare -a CHAOTIC_PACKAGES=()
declare -a AUR_PACKAGES=()
declare -a SERVICES_TO_ENABLE=()

HOSTNAME="archlinux"
USERNAME="user"
TIMEZONE="Europe/Paris"
LOCALE="fr_FR.UTF-8"
KEYMAP="fr-latin9"
XKB_LAYOUT="fr"
CPU_VENDOR="amd"
GPU_VENDOR="headless"
NETWORK_STACK="networkmanager"
AUDIO_STACK="pipewire"
DESKTOP_CHOICE="gnome"
SESSION_STACK="both"
DISPLAY_MANAGER="gdm"
ENABLE_MULTILIB="yes"
ENABLE_AVAHI="yes"
ENABLE_BLUETOOTH="yes"
ENABLE_OPENSSH="no"
ENABLE_CUPS="no"
ENABLE_SWAPFILE="no"
SWAPFILE_SIZE_GIB="4"
ENABLE_ZRAM="no"
INSTALL_PICOM="no"
USER_SHELL_CHOICE="bash"
INSTALL_OH_MY_ZSH="no"
INSTALL_POWERLEVEL10K="no"
EXTRA_UTILITY_PACKAGES="fastfetch"
EXTRA_APP_PACKAGES=""
INSTALL_VIRT_SUITE="no"
INSTALL_GNS3="no"
GAMING_TWEAKS="no"
USE_OS_PROBER="yes"
PREPARE_CHAOTIC="no"
BOOTLOADER="grub"
EFI_MOUNT_TARGET="/boot/efi"
KERNEL_REPO_URL=""
STORAGE_STACK="standard"
USE_BTRFS_SUBVOLUMES="no"
FORMAT_ROOT_CONTAINER="no"
LUKS_NAME="cryptroot"
LUKS_PASSWORD=""
LVM_VG_NAME="vg0"
LVM_ROOT_NAME="root"
LVM_HOME_NAME="home"
LVM_SWAP_NAME="swap"
LVM_CREATE_HOME="no"
LVM_CREATE_SWAP="yes"
ROOT_LV_SIZE_GIB="80"
LVM_SWAP_SIZE_GIB="8"
FINAL_ROOT_DEVICE=""
FINAL_HOME_DEVICE=""
FINAL_SWAP_DEVICE=""

KERNEL_MODE="official"
KERNEL_PACKAGE="linux"
KERNEL_HEADERS_PACKAGE="linux-headers"
MESA_MODE="official"
CUSTOM_MESA_PACKAGE=""
CUSTOM_MESA_LIB32_PACKAGE=""

TARGET_DISK=""
PARTITION_MODE="manual"
EFI_PART=""
ROOT_PART=""
HOME_PART=""
SWAP_PART=""
FORMAT_EFI="no"
FORMAT_ROOT="yes"
FORMAT_HOME="no"
ROOT_FS="ext4"
HOME_FS="ext4"
AUTO_CREATE_HOME="no"
AUTO_CREATE_SWAP="yes"
AUTO_SWAP_SIZE_GIB="4"
AUTO_ROOT_SIZE_GIB="80"

AUTOLOGIN="no"
AUTOSTART_WM="no"

# ─── i18n: chargement des traductions ───

load_lang_fr() {
	T=(
		# --- Sections ---
		[sec_init]="Initialisation"
		[sec_memory]="MEMOIRE"
		[sec_network]="RESEAU"
		[sec_identity]="IDENTITE"
		[sec_system]="SYSTEME"
		[sec_user]="UTILISATEUR"
		[sec_tkg]="LINUX-TKG"
		[sec_storage]="STOCKAGE"
		[sec_part_auto]="PARTITIONNEMENT AUTO"
		[sec_part_manual]="PARTITIONNEMENT MANUEL"
		[sec_disks]="DISQUES"
		[sec_partitions]="PARTITIONS"
		[sec_menu]="MENU"
		[sec_verify]="VERIFICATION"
		[sec_save_profile]="SAUVEGARDE PROFIL"
		[sec_load_profile]="CHARGEMENT PROFIL"

		# --- Main menu ---
		[menu_title]="ARCH INSTALLER"
		[menu_identity]="Identite"
		[menu_system]="Systeme"
		[menu_user]="Utilisateur"
		[menu_storage]="Stockage"
		[menu_network]="Connexion live"
		[menu_tkg]="Linux-tkg"
		[menu_save]="Sauver"
		[menu_save_desc]="Sauvegarder le profil"
		[menu_load]="Charger"
		[menu_load_desc]="Restaurer un profil"
		[menu_summary]="Resume"
		[menu_summary_desc]="Verification pre-install"
		[menu_install]="Installer"
		[menu_install_desc]="Lancer l'installation"
		[menu_quit]="Quitter"
		[menu_main]="MENU PRINCIPAL"

		# --- Dashboard ---
		[dash_pc]="PC"
		[dash_hw]="HW"
		[dash_state]="Etat"
		[dash_cancel]="[Cancel] Retour  [Ctrl+C] Quitter"

		# --- Identity ---
		[hostname]="Hostname"
		[hostname_invalid]="HOSTNAME INVALIDE"
		[hostname_rule]="Doit commencer par a-z, contenir a-z 0-9 - (max 63 car.)"
		[username]="Utilisateur"
		[username_invalid]="NOM INVALIDE"
		[username_root]="Le nom d'utilisateur ne peut pas etre root."
		[username_rule]="Doit commencer par a-z ou _, contenir a-z 0-9 _ - (max 32 car.)"
		[timezone]="Timezone"
		[locale_label]="LOCALE"
		[keymap_label]="CLAVIER"
		[password_root]="Mot de passe ROOT"
		[password_same]="Meme mot de passe pour %s ?"
		[password_user]="Mot de passe %s"
		[cpu_label]="MICROCODE CPU"
		[cpu_none]="Aucun"

		# --- System ---
		[enable_multilib]="Activer le depot multilib ?"
		[add_chaotic]="Ajouter Chaotic-AUR ?"
		[net_label]="RESEAU"
		[net_none]="Aucun"
		[audio_label]="AUDIO"
		[audio_alsa]="ALSA uniquement"
		[boot_label]="BOOTLOADER"
		[osprober]="Activer os-prober (detection multi-boot) ?"
		[sdboot_warn]="systemd-boot stocke noyau et initramfs sur l'ESP (/boot). Verifier la taille en dual-boot."
		[desktop_label]="BUREAU / WM"
		[desktop_tty]="TTY uniquement"
		[session_label]="SESSION GRAPHIQUE"
		[dm_label]="DISPLAY MANAGER"
		[dm_none]="Aucun"
		[autologin]="Autologin TTY1 ?"
		[autostart_wm]="Demarrage auto du DE/WM apres login TTY ?"
		[gpu_label]="GPU"
		[gpu_nvidia]="NVIDIA (proprietaire)"
		[gpu_generic]="Generique / VM"
		[mesa_label]="SOURCE MESA"
		[mesa_official]="Officiel"
		[mesa_compilation]="AUR (compilation)"
		[mesa_pkg_chaotic]="Package Mesa Chaotic"
		[mesa_pkg_aur]="Package Mesa AUR"
		[mesa_pkg_lib32]="Package lib32 Mesa"
		[mesa_pkg_lib32_aur]="Package lib32 Mesa AUR"
		[kernel_label]="NOYAU"
		[kernel_tkg]="linux-tkg (compilation Git)"
		[kernel_chaotic]="Chaotic-AUR (custom)"
		[kernel_aur]="AUR (compilation)"
		[kernel_pkg_chaotic]="Package noyau Chaotic-AUR"
		[kernel_pkg_aur]="Package noyau AUR"
		[kernel_pkg_headers]="Package headers"
		[enable_avahi]="Activer Avahi (mDNS) ?"
		[enable_bt]="Activer Bluetooth ?"
		[enable_ssh]="Activer OpenSSH ?"
		[enable_cups]="Activer CUPS (impression) ?"

		# --- User extras ---
		[install_picom]="Installer picom (compositeur X11) ?"
		[shell_label]="SHELL"
		[install_ohmyzsh]="Installer Oh My Zsh ?"
		[install_p10k]="Installer Powerlevel10k ?"
		[cli_label]="OUTILS CLI"
		[apps_label]="APPLICATIONS"
		[steam_note]="Steam (multilib requis)"
		[install_virt]="Installer QEMU + libvirt + virt-manager ?"
		[install_gns3]="Installer GNS3 ?"
		[gaming_tweaks]="Appliquer les tweaks gaming ?"

		# --- TKG ---
		[tkg_warn_select]="Selectionner d'abord 'linux-tkg (compilation Git)' dans SYSTEME > NOYAU."
		[tkg_warn]="linux-tkg sera compile localement — la compilation prend du temps."
		[tkg_info]="linux-tkg utilise ses propres menus interactifs.\nLe script se contente de cloner le depot et lancer makepkg -si."
		[tkg_url_official]="URL officielle du depot linux-tkg ?"
		[tkg_url_custom]="URL du depot linux-tkg"

		# --- Storage ---
		[storage_schema]="SCHEMA DE STOCKAGE"
		[luks_name]="Nom LUKS"
		[luks_reuse]="Reutiliser le mot de passe LUKS ?"
		[luks_password]="Mot de passe LUKS"
		[lvm_vg]="Nom du VG"
		[lvm_lv_root]="Nom du LV /"
		[lvm_create_home]="Creer un LV /home ?"
		[lvm_root_size]="Taille LV / (GiB)"
		[lvm_lv_home]="Nom du LV /home"
		[lvm_create_swap]="Creer un LV swap ?"
		[lvm_swap_size]="Taille LV swap (GiB)"
		[lvm_lv_swap]="Nom du LV swap"

		# --- Partitioning ---
		[part_mode]="MODE DE PARTITIONNEMENT"
		[part_existing]="Partitions existantes"
		[part_cfdisk]="cfdisk + selection manuelle"
		[part_auto]="Partitionnement auto (efface le disque)"
		[auto_wipe_warn]="ATTENTION: toutes les donnees sur %s seront effacees.\n\nLancer le partitionnement automatique ?"
		[auto_cancelled]="Partitionnement automatique annule."
		[fs_root]="Systeme de fichiers pour la racine /"
		[fs_home]="Systeme de fichiers pour /home"
		[fs_home_lv]="Systeme de fichiers du volume logique /home"
		[fs_lv_home]="Systeme de fichiers du volume logique /home"
		[fs_root_lv]="Systeme de fichiers du volume logique /"
		[fs_lv_root]="Systeme de fichiers du volume logique /"
		[fs_luks_existing]="Systeme de fichiers deja present dans le conteneur LUKS"
		[fs_for]="Systeme de fichiers pour %s"
		[btrfs_layout]="Layout btrfs (@, @home, @log, @pkg, @snapshots) ?"
		[auto_swap]="Creer une partition swap ?"
		[auto_swap_size]="Taille swap (GiB)"
		[auto_home]="Creer une partition /home ?"
		[auto_root_size]="Taille / (GiB)"
		[select_disk]="Selectionner le disque."
		[disk_target]="DISQUE CIBLE"
		[disk_path]="Chemin du disque cible (ex: /dev/nvme0n1)"
		[disk_invalid]="Le disque saisi n'est pas valide."
		[part_select]="PARTITION"
		[part_skip]="Ne pas utiliser cette partition"
		[part_efi]="Partition EFI a utiliser"
		[part_root]="Partition racine / a utiliser"
		[part_home]="Partition /home a utiliser"
		[part_swap]="Partition swap a utiliser"
		[part_format]="Reformater %s (FAT32) ?"
		[part_luks_init]="Initialiser LUKS sur %s ?"
		[part_reformat_root]="Reformater / ?"
		[part_sep_home]="Partition /home separee ?"
		[part_reformat]="Reformater %s ?"
		[part_swap_ded]="Partition swap dediee ?"

		# --- Memory ---
		[create_swapfile]="Creer un swapfile ?"
		[swapfile_size]="Taille swapfile (GiB)"
		[enable_zram]="Activer zram ?"

		# --- Network (live) ---
		[net_detected]="Connexion Internet detectee dans l'environnement live."
		[net_no_auto]="La connectivite n'a pas pu etre validee automatiquement. L'installation continue; pacstrap echouera si le reseau du live n'est pas pret."
		[net_none_detected]="Aucune connexion Internet detectee."
		[net_no_conn]="Pas de connexion Internet."
		[net_iwctl]="Lancer iwctl (Wi-Fi)"
		[net_continue]="Continuer sans reseau"
		[net_abort]="Annuler"
		[net_detected_manual]="Connexion Internet detectee apres configuration manuelle."
		[net_still_none]="Toujours aucune connexion validee. Pacstrap risque d'echouer."
		[net_continue_warn]="Installation poursuivie sans verification reseau."
		[net_abort_die]="Installation annulee a ta demande."

		# --- Summary ---
		[summary_title]="RESUME"
		[summary_confirm]="Confirmer et lancer l'installation ?"
		[danger_title]="⚠ CONFIRMATION DESTRUCTIVE"
		[danger_msg_header]="⚠  AVERTISSEMENT — OPÉRATION IRRÉVERSIBLE"
		[danger_msg_body]="Les données suivantes vont être DÉTRUITES :"
		[danger_no_undo]="Il n'est pas possible d'annuler après cette étape."
		[danger_confirm]="Confirmer la destruction des données ?"
		[danger_confirm_cli]="Confirmer la destruction ?"
		[unknown]="inconnu"

		# --- Summary labels ---
		[sum_identity]="IDENTITE"
		[sum_machine]="Machine"
		[sum_user]="Utilisateur"
		[sum_locale]="Locale"
		[sum_timezone]="Timezone"
		[sum_secrets]="Secrets"
		[sum_system]="SYSTEME"
		[sum_boot]="Boot"
		[sum_kernel]="Noyau"
		[sum_desktop]="Bureau"
		[sum_gpu]="GPU"
		[sum_network]="Reseau"
		[sum_audio]="Audio"
		[sum_shell]="Shell"
		[sum_cli]="CLI"
		[sum_options]="Options"
		[sum_virt]="Virt"
		[sum_extras]="Extras"
		[sum_none]="aucun"
		[sum_storage]="STOCKAGE"
		[sum_mode]="Mode"
		[sum_disk]="Disque"
		[sum_efi]="EFI"
		[sum_root]="Racine"
		[sum_home]="Home"
		[sum_swap]="Swap"
		[sum_swapfile]="Swapfile"
		[sum_zram]="Zram"
		[sum_luks]="LUKS"
		[sum_lvm]="LVM"
		[sum_btrfs]="btrfs"
		[sum_packages]="PAQUETS"
		[sum_base]="Base"
		[sum_official]="Officiels"
		[sum_chaotic]="Chaotic"
		[sum_aur]="AUR"
		[sum_services]="Services"

		# --- Profile ---
		[profile_path]="Chemin du profil"
		[profile_saved]="Profil enregistre dans %s"
		[profile_no_pass]="Les mots de passe ne sont pas sauvegardes dans les profils."
		[profile_notfound]="Profil introuvable: %s"
		[profile_loaded]="Profil charge depuis %s"
		[profile_pass_warn]="Les mots de passe restent a ressaisir avant l'installation."

		# --- Pre-install checks ---
		[check_no_pass]="Les mots de passe systeme n'ont pas encore ete saisis."
		[check_no_luks]="Le mot de passe LUKS n'a pas encore ete saisi."
		[check_no_part]="Le partitionnement n'est pas encore defini."

		# --- pretty_label ---
		[pl_none]="Aucun"
		[pl_nvidia]="NVIDIA proprietaire"
		[pl_generic]="Generique / VM"
		[pl_no_gpu]="Sans GPU"
		[pl_manual]="Manuel"
		[pl_simple]="Simple"
		[pl_official]="officiel"
		[pl_git_repo]="depot Git"

		# --- Describe ---
		[desc_secrets]="secrets"
		[desc_no_extra]="aucun extra"
		[desc_extra_s]="extra"
		[desc_extras_s]="extras"
		[desc_active]="Actif"
		[desc_inactive]="Inactif"

		# --- Misc errors ---
		[err_root]="Ce script doit etre lance en root depuis l'Arch ISO."
		[err_uefi]="Ce script cible un demarrage UEFI avec une partition EFI montee sur /boot/efi ou /boot selon le bootloader choisi."
		[err_cmd_missing]="Commande requise introuvable: %s"
		[err_value_empty]="La valeur ne peut pas etre vide."
		[err_integer]="Merci de saisir un entier strictement positif."
		[err_password_empty]="Le mot de passe ne peut pas etre vide."
		[err_password_mismatch]="Les mots de passe ne correspondent pas."
		[err_choice_invalid]="Choix invalide."
		[err_part_invalid]="La partition saisie n'est pas valide."
		[err_umount]="Impossible de preparer l'installation tant que %s est occupe."
		[umount_ask]="Tout demonter sous %s avant de preparer l'installation ?"
		[umount_busy]="Le point de montage %s est deja utilise."

		# --- Whiptail titles ---
		[wt_confirm]="Confirmation"
		[wt_input]="Saisie"
		[wt_required]="Valeur requise"
		[wt_password]="Mot de passe"
		[wt_password_confirm]="Confirmation"
		[wt_password_confirm_msg]="Confirmer %s"
		[wt_password_required]="Mot de passe requis"
		[wt_integer]="Nombre"
		[wt_integer_invalid]="Entier invalide"
		[wt_select]="Selection"
		[wt_multi_select]="Selection multiple"

		# --- Language chooser ---
		[lang_label]="LANGUE"

		# --- Steam multilib warn ---
		[steam_multilib_warn]="Steam necessite le depot multilib. Activation automatique de multilib."

		# --- Misc prompts ---
		[yn_invalid]="Reponse invalide. Merci de repondre par oui/non."
	)
}

load_lang_en() {
	T=(
		# --- Sections ---
		[sec_init]="Initialization"
		[sec_memory]="MEMORY"
		[sec_network]="NETWORK"
		[sec_identity]="IDENTITY"
		[sec_system]="SYSTEM"
		[sec_user]="USER"
		[sec_tkg]="LINUX-TKG"
		[sec_storage]="STORAGE"
		[sec_part_auto]="AUTO PARTITIONING"
		[sec_part_manual]="MANUAL PARTITIONING"
		[sec_disks]="DISKS"
		[sec_partitions]="PARTITIONS"
		[sec_menu]="MENU"
		[sec_verify]="VERIFICATION"
		[sec_save_profile]="SAVE PROFILE"
		[sec_load_profile]="LOAD PROFILE"

		# --- Main menu ---
		[menu_title]="ARCH INSTALLER"
		[menu_identity]="Identity"
		[menu_system]="System"
		[menu_user]="User"
		[menu_storage]="Storage"
		[menu_network]="Live connection"
		[menu_tkg]="Linux-tkg"
		[menu_save]="Save"
		[menu_save_desc]="Save profile"
		[menu_load]="Load"
		[menu_load_desc]="Restore profile"
		[menu_summary]="Summary"
		[menu_summary_desc]="Pre-install check"
		[menu_install]="Install"
		[menu_install_desc]="Start installation"
		[menu_quit]="Quit"
		[menu_main]="MAIN MENU"

		# --- Dashboard ---
		[dash_pc]="PC"
		[dash_hw]="HW"
		[dash_state]="Status"
		[dash_cancel]="[Cancel] Back  [Ctrl+C] Quit"

		# --- Identity ---
		[hostname]="Hostname"
		[hostname_invalid]="INVALID HOSTNAME"
		[hostname_rule]="Must start with a-z, contain a-z 0-9 - (max 63 chars)"
		[username]="Username"
		[username_invalid]="INVALID NAME"
		[username_root]="Username cannot be root."
		[username_rule]="Must start with a-z or _, contain a-z 0-9 _ - (max 32 chars)"
		[timezone]="Timezone"
		[locale_label]="LOCALE"
		[keymap_label]="KEYBOARD"
		[password_root]="ROOT password"
		[password_same]="Same password for %s?"
		[password_user]="Password for %s"
		[cpu_label]="CPU MICROCODE"
		[cpu_none]="None"

		# --- System ---
		[enable_multilib]="Enable multilib repository?"
		[add_chaotic]="Add Chaotic-AUR?"
		[net_label]="NETWORK"
		[net_none]="None"
		[audio_label]="AUDIO"
		[audio_alsa]="ALSA only"
		[boot_label]="BOOTLOADER"
		[osprober]="Enable os-prober (multi-boot detection)?"
		[sdboot_warn]="systemd-boot stores kernel and initramfs on ESP (/boot). Check size for dual-boot."
		[desktop_label]="DESKTOP / WM"
		[desktop_tty]="TTY only"
		[session_label]="GRAPHICAL SESSION"
		[dm_label]="DISPLAY MANAGER"
		[dm_none]="None"
		[autologin]="Autologin TTY1?"
		[autostart_wm]="Auto-start DE/WM after TTY login?"
		[gpu_label]="GPU"
		[gpu_nvidia]="NVIDIA (proprietary)"
		[gpu_generic]="Generic / VM"
		[mesa_label]="MESA SOURCE"
		[mesa_official]="Official"
		[mesa_compilation]="AUR (build from source)"
		[mesa_pkg_chaotic]="Mesa Chaotic package"
		[mesa_pkg_aur]="Mesa AUR package"
		[mesa_pkg_lib32]="lib32 Mesa package"
		[mesa_pkg_lib32_aur]="lib32 Mesa AUR package"
		[kernel_label]="KERNEL"
		[kernel_tkg]="linux-tkg (Git build)"
		[kernel_chaotic]="Chaotic-AUR (custom)"
		[kernel_aur]="AUR (build from source)"
		[kernel_pkg_chaotic]="Chaotic-AUR kernel package"
		[kernel_pkg_aur]="AUR kernel package"
		[kernel_pkg_headers]="Headers package"
		[enable_avahi]="Enable Avahi (mDNS)?"
		[enable_bt]="Enable Bluetooth?"
		[enable_ssh]="Enable OpenSSH?"
		[enable_cups]="Enable CUPS (printing)?"

		# --- User extras ---
		[install_picom]="Install picom (X11 compositor)?"
		[shell_label]="SHELL"
		[install_ohmyzsh]="Install Oh My Zsh?"
		[install_p10k]="Install Powerlevel10k?"
		[cli_label]="CLI TOOLS"
		[apps_label]="APPLICATIONS"
		[steam_note]="Steam (multilib required)"
		[install_virt]="Install QEMU + libvirt + virt-manager?"
		[install_gns3]="Install GNS3?"
		[gaming_tweaks]="Apply gaming tweaks?"

		# --- TKG ---
		[tkg_warn_select]="Select 'linux-tkg (Git build)' in SYSTEM > KERNEL first."
		[tkg_warn]="linux-tkg will be compiled locally — this takes time."
		[tkg_info]="linux-tkg uses its own interactive menus.\nThe script just clones the repo and runs makepkg -si."
		[tkg_url_official]="Use official linux-tkg repo URL?"
		[tkg_url_custom]="linux-tkg repo URL"

		# --- Storage ---
		[storage_schema]="STORAGE SCHEME"
		[luks_name]="LUKS name"
		[luks_reuse]="Reuse LUKS password?"
		[luks_password]="LUKS password"
		[lvm_vg]="VG name"
		[lvm_lv_root]="LV / name"
		[lvm_create_home]="Create /home LV?"
		[lvm_root_size]="LV / size (GiB)"
		[lvm_lv_home]="LV /home name"
		[lvm_create_swap]="Create swap LV?"
		[lvm_swap_size]="LV swap size (GiB)"
		[lvm_lv_swap]="LV swap name"

		# --- Partitioning ---
		[part_mode]="PARTITIONING MODE"
		[part_existing]="Existing partitions"
		[part_cfdisk]="cfdisk + manual selection"
		[part_auto]="Auto partitioning (wipes disk)"
		[auto_wipe_warn]="WARNING: all data on %s will be erased.\n\nProceed with auto partitioning?"
		[auto_cancelled]="Auto partitioning cancelled."
		[fs_root]="Filesystem for root /"
		[fs_home]="Filesystem for /home"
		[fs_home_lv]="Filesystem for /home logical volume"
		[fs_lv_home]="Filesystem for /home logical volume"
		[fs_root_lv]="Filesystem for / logical volume"
		[fs_lv_root]="Filesystem for / logical volume"
		[fs_luks_existing]="Existing filesystem inside LUKS container"
		[fs_for]="Filesystem for %s"
		[btrfs_layout]="Btrfs layout (@, @home, @log, @pkg, @snapshots)?"
		[auto_swap]="Create a swap partition?"
		[auto_swap_size]="Swap size (GiB)"
		[auto_home]="Create a /home partition?"
		[auto_root_size]="Root / size (GiB)"
		[select_disk]="Select disk."
		[disk_target]="TARGET DISK"
		[disk_path]="Target disk path (e.g. /dev/nvme0n1)"
		[disk_invalid]="The specified disk is not valid."
		[part_select]="PARTITION"
		[part_skip]="Skip this partition"
		[part_efi]="EFI partition to use"
		[part_root]="Root / partition to use"
		[part_home]="/home partition to use"
		[part_swap]="Swap partition to use"
		[part_format]="Reformat %s (FAT32)?"
		[part_luks_init]="Initialize LUKS on %s?"
		[part_reformat_root]="Reformat /?"
		[part_sep_home]="Separate /home partition?"
		[part_reformat]="Reformat %s?"
		[part_swap_ded]="Dedicated swap partition?"

		# --- Memory ---
		[create_swapfile]="Create a swapfile?"
		[swapfile_size]="Swapfile size (GiB)"
		[enable_zram]="Enable zram?"

		# --- Network (live) ---
		[net_detected]="Internet connection detected in live environment."
		[net_no_auto]="Connectivity could not be validated automatically. Installation continues; pacstrap will fail if network is not ready."
		[net_none_detected]="No Internet connection detected."
		[net_no_conn]="No Internet connection."
		[net_iwctl]="Launch iwctl (Wi-Fi)"
		[net_continue]="Continue without network"
		[net_abort]="Cancel"
		[net_detected_manual]="Internet connection detected after manual configuration."
		[net_still_none]="Still no validated connection. Pacstrap may fail."
		[net_continue_warn]="Installation continues without network verification."
		[net_abort_die]="Installation cancelled at your request."

		# --- Summary ---
		[summary_title]="SUMMARY"
		[summary_confirm]="Confirm and start installation?"
		[danger_title]="⚠ DESTRUCTIVE CONFIRMATION"
		[danger_msg_header]="⚠  WARNING — IRREVERSIBLE OPERATION"
		[danger_msg_body]="The following data will be DESTROYED:"
		[danger_no_undo]="This cannot be undone after this step."
		[danger_confirm]="Confirm data destruction?"
		[danger_confirm_cli]="Confirm destruction?"
		[unknown]="unknown"

		# --- Summary labels ---
		[sum_identity]="IDENTITY"
		[sum_machine]="Machine"
		[sum_user]="User"
		[sum_locale]="Locale"
		[sum_timezone]="Timezone"
		[sum_secrets]="Secrets"
		[sum_system]="SYSTEM"
		[sum_boot]="Boot"
		[sum_kernel]="Kernel"
		[sum_desktop]="Desktop"
		[sum_gpu]="GPU"
		[sum_network]="Network"
		[sum_audio]="Audio"
		[sum_shell]="Shell"
		[sum_cli]="CLI"
		[sum_options]="Options"
		[sum_virt]="Virt"
		[sum_extras]="Extras"
		[sum_none]="none"
		[sum_storage]="STORAGE"
		[sum_mode]="Mode"
		[sum_disk]="Disk"
		[sum_efi]="EFI"
		[sum_root]="Root"
		[sum_home]="Home"
		[sum_swap]="Swap"
		[sum_swapfile]="Swapfile"
		[sum_zram]="Zram"
		[sum_luks]="LUKS"
		[sum_lvm]="LVM"
		[sum_btrfs]="btrfs"
		[sum_packages]="PACKAGES"
		[sum_base]="Base"
		[sum_official]="Official"
		[sum_chaotic]="Chaotic"
		[sum_aur]="AUR"
		[sum_services]="Services"

		# --- Profile ---
		[profile_path]="Profile path"
		[profile_saved]="Profile saved to %s"
		[profile_no_pass]="Passwords are not saved in profiles."
		[profile_notfound]="Profile not found: %s"
		[profile_loaded]="Profile loaded from %s"
		[profile_pass_warn]="Passwords still need to be entered before installation."

		# --- Pre-install checks ---
		[check_no_pass]="System passwords have not been entered yet."
		[check_no_luks]="LUKS password has not been entered yet."
		[check_no_part]="Partitioning has not been defined yet."

		# --- pretty_label ---
		[pl_none]="None"
		[pl_nvidia]="NVIDIA proprietary"
		[pl_generic]="Generic / VM"
		[pl_no_gpu]="No GPU"
		[pl_manual]="Manual"
		[pl_simple]="Simple"
		[pl_official]="official"
		[pl_git_repo]="Git repo"

		# --- Describe ---
		[desc_secrets]="secrets"
		[desc_no_extra]="no extras"
		[desc_extra_s]="extra"
		[desc_extras_s]="extras"
		[desc_active]="Active"
		[desc_inactive]="Inactive"

		# --- Misc errors ---
		[err_root]="This script must be run as root from the Arch ISO."
		[err_uefi]="This script targets UEFI boot with an EFI partition mounted on /boot/efi or /boot."
		[err_cmd_missing]="Required command not found: %s"
		[err_value_empty]="Value cannot be empty."
		[err_integer]="Please enter a strictly positive integer."
		[err_password_empty]="Password cannot be empty."
		[err_password_mismatch]="Passwords do not match."
		[err_choice_invalid]="Invalid choice."
		[err_part_invalid]="The specified partition is not valid."
		[err_umount]="Cannot prepare installation while %s is busy."
		[umount_ask]="Unmount everything under %s before preparing installation?"
		[umount_busy]="Mount point %s is already in use."

		# --- Whiptail titles ---
		[wt_confirm]="Confirm"
		[wt_input]="Input"
		[wt_required]="Required"
		[wt_password]="Password"
		[wt_password_confirm]="Confirm"
		[wt_password_confirm_msg]="Confirm %s"
		[wt_password_required]="Password required"
		[wt_integer]="Number"
		[wt_integer_invalid]="Invalid integer"
		[wt_select]="Selection"
		[wt_multi_select]="Multiple selection"

		# --- Language chooser ---
		[lang_label]="LANGUAGE"

		# --- Steam multilib warn ---
		[steam_multilib_warn]="Steam requires multilib repository. Enabling multilib automatically."

		# --- Misc prompts ---
		[yn_invalid]="Invalid answer. Please answer yes/no."
	)
}

# Load default language
load_lang_fr

section() {
	CURRENT_STEP=$1
	printf '\n== %s ==\n' "$1"
}

info() {
	printf '[INFO] %s\n' "$1"
}

warn() {
	printf '[WARN] %s\n' "$1" >&2
}

die() {
	printf '[ERR ] %s\n' "$1" >&2
	exit 1
}

format_command() {
	local item
	for item in "$@"; do
		printf '%q ' "$item"
	done
}

log_command() {
	printf '[CMD ] '
	format_command "$@"
	printf '\n'
}

run_logged() {
	log_command "$@"
	"$@"
}

handle_error() {
	local exit_code=$1
	local line_no=$2
	local failed_command=$3

	printf '\n[ERR ] Echec pendant: %s\n' "${CURRENT_STEP:-etape inconnue}" >&2
	printf '[ERR ] Ligne: %s\n' "$line_no" >&2
	printf '[ERR ] Commande: %s\n' "$failed_command" >&2
	printf '[ERR ] Log: %s\n' "$LOG_FILE" >&2
	exit "$exit_code"
}

handle_interrupt() {
	local signal_name=${1:-INT}

	trap - ERR INT TERM
	printf '\n[WARN] Interruption recue (%s). Installation stoppee.\n' "$signal_name" >&2
	printf '[WARN] Log: %s\n' "$LOG_FILE" >&2
	exit 130
}

trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
trap 'handle_interrupt INT' INT
trap 'handle_interrupt TERM' TERM

is_ui_cancel_status() {
	[[ "${1:-0}" -eq "$UI_CANCEL_STATUS" ]]
}

capture_value() {
	local var_name=$1
	shift
	local value status=0

	value=$("$@") || status=$?
	if is_ui_cancel_status "$status"; then
		return "$UI_CANCEL_STATUS"
	fi
	if (( status != 0 )); then
		return "$status"
	fi

	printf -v "$var_name" '%s' "$value"
}

set_yes_no_var() {
	local var_name=$1
	local prompt=$2
	local default=${3:-y}
	local status=0

	if prompt_yes_no "$prompt" "$default"; then
		printf -v "$var_name" 'yes'
		return 0
	fi

	status=$?
	if is_ui_cancel_status "$status"; then
		return "$UI_CANCEL_STATUS"
	fi

	printf -v "$var_name" 'no'
}

run_menu_action() {
	local status=0

	"$@" || status=$?
	if is_ui_cancel_status "$status"; then
		return 0
	fi

	return "$status"
}

append_unique() {
	local -n array_ref=$1
	shift

	local candidate existing found
	for candidate in "$@"; do
		[[ -z "$candidate" ]] && continue
		found=0
		for existing in "${array_ref[@]}"; do
			if [[ "$existing" == "$candidate" ]]; then
				found=1
				break
			fi
		done
		if (( ! found )); then
			array_ref+=("$candidate")
		fi
	done
}

require_root() {
	if (( EUID != 0 )); then
		die "${T[err_root]}"
	fi
}

require_uefi() {
	if [[ ! -d /sys/firmware/efi ]]; then
		die "${T[err_uefi]}"
	fi
}

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		die "$(printf "${T[err_cmd_missing]}" "$1")"
	fi
}

use_tui() {
	[[ "$UI_BACKEND" == "whiptail" ]] && [[ -e /dev/tty ]]
}

init_ui() {
	if command -v whiptail >/dev/null 2>&1 && [[ -e /dev/tty ]]; then
		UI_BACKEND="whiptail"
	else
		UI_BACKEND="cli"
	fi
}

choose_script_language() {
	local lang_choice status=0

	if use_tui; then
		lang_choice=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "LANGUAGE / LANGUE" --menu \
			"Choose the installer language / Choisir la langue" \
			10 "$UI_WIDTH" 2 \
			"fr" "Francais" \
			"en" "English") || status=$?
		if (( status != 0 )); then
			lang_choice="fr"
		fi
	else
		printf '1) Francais\n2) English\n'
		local reply
		read -rp "Language / Langue [1]: " reply
		case "${reply:-1}" in
			2|en) lang_choice="en" ;;
			*) lang_choice="fr" ;;
		esac
	fi

	SCRIPT_LANG="$lang_choice"
	case "$SCRIPT_LANG" in
		en) load_lang_en ;;
		*) load_lang_fr ;;
	esac
}

run_whiptail_capture() {
	local output status

	output=$(whiptail "$@" --output-fd 3 3>&1 1>/dev/tty 2>/dev/tty) || status=$?
	status=${status:-0}
	printf '%s' "$output"
	return "$status"
}

show_message() {
	local title=$1
	local message=$2

	if use_tui; then
		whiptail --backtitle "$SCRIPT_NAME" --title "$title" --msgbox "$message" "$UI_HEIGHT" "$UI_WIDTH" </dev/tty >/dev/tty 2>/dev/tty
	else
		section "$title"
		printf '%s\n' "$message"
	fi
}

run_interactive_command() {
	"$@" </dev/tty >/dev/tty 2>/dev/tty
}

prompt_yes_no() {
	local prompt=$1
	local default=${2:-y}
	local suffix reply status

	if use_tui; then
		if [[ "$default" == "n" ]]; then
			whiptail --backtitle "$SCRIPT_NAME" --title "${T[wt_confirm]}" --defaultno --yesno "$prompt" 10 "$UI_WIDTH" </dev/tty >/dev/tty 2>/dev/tty
		else
			whiptail --backtitle "$SCRIPT_NAME" --title "${T[wt_confirm]}" --yesno "$prompt" 10 "$UI_WIDTH" </dev/tty >/dev/tty 2>/dev/tty
		fi
		status=$?
		case "$status" in
			0)
				return 0
				;;
			1)
				return 1
				;;
			*)
				return "$UI_CANCEL_STATUS"
				;;
		esac
	fi

	if [[ "$default" == "y" ]]; then
		suffix="[Y/n]"
	else
		suffix="[y/N]"
	fi

	while true; do
		read -rp "$prompt $suffix " reply
		reply=${reply:-$default}
		case "${reply,,}" in
			y|yes|o|oui)
				return 0
				;;
			n|no|non)
				return 1
				;;
			*)
				warn "${T[yn_invalid]}"
				;;
		esac
	done
}

prompt_with_default() {
	local prompt=$1
	local default=$2
	local reply status=0

	if use_tui; then
		reply=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "${T[wt_input]}" --inputbox "$prompt" 11 "$UI_WIDTH" "$default") || status=$?
		if (( status != 0 )); then
			return "$UI_CANCEL_STATUS"
		fi
		printf '%s\n' "${reply:-$default}"
		return 0
	fi

	read -rp "$prompt [$default]: " reply
	printf '%s\n' "${reply:-$default}"
}

prompt_non_empty() {
	local prompt=$1
	local reply status=0

	while true; do
		if use_tui; then
			reply=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "${T[wt_input]}" --inputbox "$prompt" 11 "$UI_WIDTH" "") || status=$?
			if (( status != 0 )); then
				return "$UI_CANCEL_STATUS"
			fi
		else
		read -rp "$prompt: " reply
		fi
		if [[ -n "$reply" ]]; then
			printf '%s\n' "$reply"
			return 0
		fi
		if use_tui; then
			show_message "${T[wt_required]}" "${T[err_value_empty]}"
		else
			warn "${T[err_value_empty]}"
		fi
	done
}

prompt_positive_integer() {
	local prompt=$1
	local default=$2
	local reply status=0

	while true; do
		if use_tui; then
			reply=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "${T[wt_integer]}" --inputbox "$prompt" 11 "$UI_WIDTH" "$default") || status=$?
			if (( status != 0 )); then
				return "$UI_CANCEL_STATUS"
			fi
		else
			read -rp "$prompt [$default]: " reply
		fi
		reply=${reply:-$default}
		if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply > 0 )); then
			printf '%s\n' "$reply"
			return 0
		fi
		if use_tui; then
			show_message "${T[wt_integer_invalid]}" "${T[err_integer]}"
		else
			warn "${T[err_integer]}"
		fi
	done
}

configure_memory_features() {
	local swapfile_default zram_default

	section "${T[sec_memory]}"

	swapfile_default=$([[ "$ENABLE_SWAPFILE" == "yes" ]] && printf 'y' || printf 'n')
	set_yes_no_var ENABLE_SWAPFILE "${T[create_swapfile]}" "$swapfile_default" || return "$?"
	if [[ "$ENABLE_SWAPFILE" == "yes" ]]; then
		capture_value SWAPFILE_SIZE_GIB prompt_positive_integer "${T[swapfile_size]}" "$SWAPFILE_SIZE_GIB" || return "$?"
	fi

	zram_default=$([[ "$ENABLE_ZRAM" == "yes" ]] && printf 'y' || printf 'n')
	set_yes_no_var ENABLE_ZRAM "${T[enable_zram]}" "$zram_default" || return "$?"
}

prompt_password_twice() {
	local prompt=$1
	local first second status=0

	while true; do
		if use_tui; then
			first=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "${T[wt_password]}" --passwordbox "$prompt" 11 "$UI_WIDTH") || status=$?
			if (( status != 0 )); then
				return "$UI_CANCEL_STATUS"
			fi
			if [[ -z "$first" ]]; then
				show_message "${T[wt_password_required]}" "${T[err_password_empty]}"
				continue
			fi
			second=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "${T[wt_password_confirm]}" --passwordbox "$(printf "${T[wt_password_confirm_msg]}" "$prompt")" 11 "$UI_WIDTH") || status=$?
			if (( status != 0 )); then
				return "$UI_CANCEL_STATUS"
			fi
		else
		read -rsp "$prompt: " first
		printf '\n'
		read -rsp "$(printf "${T[wt_password_confirm_msg]}" "$prompt"): " second
		printf '\n'
		fi

		if [[ -z "$first" ]]; then
			if use_tui; then
				show_message "${T[wt_password_required]}" "${T[err_password_empty]}"
			else
				warn "${T[err_password_empty]}"
			fi
			continue
		fi

		if [[ "$first" != "$second" ]]; then
			if use_tui; then
				show_message "${T[wt_password]}" "${T[err_password_mismatch]}"
			else
				warn "${T[err_password_mismatch]}"
			fi
			continue
		fi

		printf '%s\n' "$first"
		return 0
	done
}

choose_option() {
	local prompt=$1
	local default_index=$2
	shift 2
	local -a options=("$@")
	local choice label key index output status=0

	if use_tui; then
		local -a menu_args=()
		for choice in "${options[@]}"; do
			key=${choice%%|*}
			label=${choice#*|}
			menu_args+=("$key" "$label")
		done
		output=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "${T[wt_select]}" --default-item "${options[default_index-1]%%|*}" --menu "$prompt" "$UI_HEIGHT" "$UI_WIDTH" "$UI_MENU_HEIGHT" "${menu_args[@]}") || status=$?
		if (( status != 0 )); then
			return "$UI_CANCEL_STATUS"
		fi
		printf '%s\n' "${output:-${options[default_index-1]%%|*}}"
		return 0
	fi

	while true; do
		printf '%s\n' "$prompt"
		index=1
		for choice in "${options[@]}"; do
			key=${choice%%|*}
			label=${choice#*|}
			printf '  %d) %s\n' "$index" "$label"
			((index++))
		done

		read -rp "Choix [$default_index]: " choice
		choice=${choice:-$default_index}

		if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
			printf '%s\n' "${options[choice-1]%%|*}"
			return 0
		fi

		warn "${T[err_choice_invalid]}"
	done
}

option_index_for_key() {
	local target=$1
	shift
	local index=1 option

	for option in "$@"; do
		if [[ "${option%%|*}" == "$target" ]]; then
			printf '%s\n' "$index"
			return 0
		fi
		((index++))
	done

	printf '1\n'
}

contains_word() {
	local needle=$1
	shift
	local word

	for word in "$@"; do
		[[ "$word" == "$needle" ]] && return 0
	done

	return 1
}

selection_string_contains() {
	local selection_string=$1
	local needle=$2
	local -a selection_words=()

	read -r -a selection_words <<< "$selection_string"
	contains_word "$needle" "${selection_words[@]}"
}

choose_multi_option() {
	local prompt=$1
	local current_values=$2
	shift 2
	local -a options=("$@")
	local -a current_words=() selected_words=() checklist_args=()
	local option key label state output status=0

	read -r -a current_words <<< "$current_values"

	if use_tui; then
		for option in "${options[@]}"; do
			key=${option%%|*}
			label=${option#*|}
			state="OFF"
			contains_word "$key" "${current_words[@]}" && state="ON"
			checklist_args+=("$key" "$label" "$state")
		done

		output=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "${T[wt_multi_select]}" --checklist "$prompt" 24 110 14 "${checklist_args[@]}") || status=$?
		if (( status != 0 )); then
			return "$UI_CANCEL_STATUS"
		fi

		output=${output//\"/}
		read -r -a selected_words <<< "$output"
		printf '%s\n' "${selected_words[*]}"
		return 0
	fi

	for option in "${options[@]}"; do
		key=${option%%|*}
		label=${option#*|}
		if contains_word "$key" "${current_words[@]}"; then
			state="y"
		else
			state="n"
		fi

		if prompt_yes_no "$label ?" "$state"; then
			append_unique selected_words "$key"
		fi
	done

	printf '%s\n' "${selected_words[*]}"
}

write_scalar_vars() {
	local destination=$1
	shift
	local var_name

	for var_name in "$@"; do
		printf '%s=%q\n' "$var_name" "${!var_name}" >> "$destination"
	done
}

list_block_devices() {
	lsblk -e7 -o PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
}

list_disks() {
	lsblk -dn -o PATH,SIZE,MODEL,TYPE | awk '$4 == "disk" {print $1, $2, $3}'
}

select_disk() {
	local disk label status=0
	local -a disk_options=()

	if use_tui; then
		while IFS= read -r disk; do
			[[ -n "$disk" ]] || continue
			label=$(lsblk -dn -o SIZE,MODEL "$disk" | head -n1 | xargs)
			disk_options+=("$disk" "${label:-disk}")
		done < <(lsblk -dn -o PATH,TYPE | awk '$2 == "disk" {print $1}')

		if (( ${#disk_options[@]} > 0 )); then
			disk=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "${T[disk_target]}" --menu "${T[select_disk]}" "$UI_HEIGHT" "$UI_WIDTH" "$UI_MENU_HEIGHT" "${disk_options[@]}") || status=$?
			if (( status != 0 )); then
				return "$UI_CANCEL_STATUS"
			fi
			if [[ -n "$disk" && -b "$disk" ]]; then
				printf '%s\n' "$disk"
				return 0
			fi
		fi
	fi

	while true; do
		section "${T[sec_disks]}"
		list_block_devices
		disk=$(prompt_non_empty "${T[disk_path]}")

		if [[ -b "$disk" ]] && [[ "$(lsblk -dn -o TYPE "$disk")" == "disk" ]]; then
			printf '%s\n' "$disk"
			return 0
		fi

		warn "${T[disk_invalid]}"
	done
}

prompt_partition() {
	local prompt=$1
	local allow_empty=${2:-no}
	local part default_tag status=0
	local -a part_options=()

	if use_tui; then
		while IFS= read -r part; do
			[[ -n "$part" ]] || continue
			part_options+=("$part" "$(lsblk -dn -o SIZE,FSTYPE,MOUNTPOINTS "$part" | head -n1 | xargs)")
		done < <(lsblk -rpn -o PATH,TYPE | awk '$2 != "disk" && $2 != "rom" {print $1}')

		if [[ "$allow_empty" == "yes" ]]; then
			part_options=("__skip__" "${T[part_skip]}" "${part_options[@]}")
			default_tag="__skip__"
		else
			default_tag="${part_options[0]:-}"
		fi

		if (( ${#part_options[@]} > 0 )); then
			part=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "${T[part_select]}" --default-item "$default_tag" --menu "$prompt" "$UI_HEIGHT" "$UI_WIDTH" "$UI_MENU_HEIGHT" "${part_options[@]}") || status=$?
			if (( status != 0 )); then
				return "$UI_CANCEL_STATUS"
			fi
			if [[ "$part" == "__skip__" ]]; then
				printf '\n'
				return 0
			fi
			if [[ -b "$part" ]]; then
				printf '%s\n' "$part"
				return 0
			fi
		fi
	fi

	while true; do
		section "${T[sec_partitions]}"
		list_block_devices
		if [[ "$allow_empty" == "yes" ]]; then
			read -rp "$prompt (laisser vide pour ignorer): " part
			if [[ -z "$part" ]]; then
				printf '\n'
				return 0
			fi
		else
			read -rp "$prompt: " part
		fi

		if [[ -b "$part" ]]; then
			printf '%s\n' "$part"
			return 0
		fi

		warn "${T[err_part_invalid]}"
	done
}

ask_filesystem() {
	local prompt=$1
	local default_index=$2

	choose_option "$prompt" "$default_index" \
		"ext4|ext4" \
		"btrfs|btrfs" \
		"xfs|xfs" \
		"f2fs|f2fs"
}

partition_path() {
	local disk=$1
	local index=$2

	if [[ "$disk" =~ (nvme|mmcblk|loop) ]]; then
		printf '%s\n' "${disk}p${index}"
	else
		printf '%s\n' "${disk}${index}"
	fi
}

partition_fstype() {
	lsblk -no FSTYPE "$1" | head -n1 | tr -d '[:space:]'
}

detect_or_prompt_filesystem() {
	local partition=$1
	local fallback_index=$2
	local detected

	detected=$(partition_fstype "$partition")
	case "$detected" in
		ext4|btrfs|xfs|f2fs)
			printf '%s\n' "$detected"
			;;
		*)
			ask_filesystem "$(printf "${T[fs_for]}" "$partition")" "$fallback_index"
			;;
	esac
}

ensure_target_mount_available() {
	if mountpoint -q "$TARGET_MOUNT"; then
		warn "$(printf "${T[umount_busy]}" "$TARGET_MOUNT")"
		if prompt_yes_no "$(printf "${T[umount_ask]}" "$TARGET_MOUNT")" "y"; then
			umount -R "$TARGET_MOUNT"
		else
			die "$(printf "${T[err_umount]}" "$TARGET_MOUNT")"
		fi
	fi

	mkdir -p "$TARGET_MOUNT"
}

configure_live_network() {
	local mode=${1:-interactive}
	local prompt_message network_ok="no" choice

	section "${T[sec_network]}"

	if ip route get 1.1.1.1 >/dev/null 2>&1 && ping -n -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
		network_ok="yes"
	elif getent hosts archlinux.org >/dev/null 2>&1 && ping -n -c1 -W2 archlinux.org >/dev/null 2>&1; then
		network_ok="yes"
	fi

	if [[ "$network_ok" == "yes" ]]; then
		info "${T[net_detected]}"
		return 0
	fi

	if [[ "$mode" == "noninteractive" ]]; then
		warn "${T[net_no_auto]}"
		return 0
	fi

	prompt_message="${T[net_none_detected]}"

	warn "${T[net_no_conn]}"
	capture_value choice choose_option "$prompt_message" 2 \
		"iwctl|${T[net_iwctl]}" \
		"continue|${T[net_continue]}" \
		"abort|${T[net_abort]}" || return "$?"
	case "$choice" in
		iwctl)
			run_interactive_command iwctl
			if ip route get 1.1.1.1 >/dev/null 2>&1 && ping -n -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
				info "${T[net_detected_manual]}"
			else
				warn "${T[net_still_none]}"
			fi
			;;
		continue)
			warn "${T[net_continue_warn]}"
			;;
		abort)
			die "${T[net_abort_die]}"
			;;
	esac
}

collect_identity() {
	local status=0

	section "${T[sec_identity]}"

	while true; do
		capture_value HOSTNAME prompt_with_default "${T[hostname]}" "$HOSTNAME" || return "$?"
		if [[ "$HOSTNAME" =~ ^[a-z][a-z0-9-]{0,62}$ ]]; then
			break
		fi
		show_message "${T[hostname_invalid]}" "${T[hostname_rule]}"
	done

	while true; do
		capture_value USERNAME prompt_with_default "${T[username]}" "$USERNAME" || return "$?"
		if [[ "$USERNAME" == "root" ]]; then
			show_message "${T[username_invalid]}" "${T[username_root]}"
			continue
		fi
		if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
			break
		fi
		show_message "${T[username_invalid]}" "${T[username_rule]}"
	done
	capture_value TIMEZONE prompt_with_default "${T[timezone]}" "$TIMEZONE" || return "$?"

	capture_value LOCALE choose_option "${T[locale_label]}" "$(option_index_for_key "$LOCALE" \
		"fr_FR.UTF-8|Francais (France)" \
		"en_US.UTF-8|English (US)" \
		"en_GB.UTF-8|English (UK)" \
		"de_DE.UTF-8|Deutsch" \
		"es_ES.UTF-8|Espanol" \
		"it_IT.UTF-8|Italiano" \
		"pt_PT.UTF-8|Portugues" \
		"pt_BR.UTF-8|Portugues (Brasil)" \
		"nl_NL.UTF-8|Nederlands" \
		"pl_PL.UTF-8|Polski" \
		"ru_RU.UTF-8|Russkij" \
		"sv_SE.UTF-8|Svenska" \
		"da_DK.UTF-8|Dansk" \
		"fi_FI.UTF-8|Suomi" \
		"nb_NO.UTF-8|Norsk" \
		"hu_HU.UTF-8|Magyar" \
		"cs_CZ.UTF-8|Cesky" \
		"ro_RO.UTF-8|Romana" \
		"ca_ES.UTF-8|Catala" \
		"ja_JP.UTF-8|Japanese" \
		"zh_CN.UTF-8|Chinese (Simplified)")" \
		"fr_FR.UTF-8|Francais (France)" \
		"en_US.UTF-8|English (US)" \
		"en_GB.UTF-8|English (UK)" \
		"de_DE.UTF-8|Deutsch" \
		"es_ES.UTF-8|Espanol" \
		"it_IT.UTF-8|Italiano" \
		"pt_PT.UTF-8|Portugues" \
		"pt_BR.UTF-8|Portugues (Brasil)" \
		"nl_NL.UTF-8|Nederlands" \
		"pl_PL.UTF-8|Polski" \
		"ru_RU.UTF-8|Russkij" \
		"sv_SE.UTF-8|Svenska" \
		"da_DK.UTF-8|Dansk" \
		"fi_FI.UTF-8|Suomi" \
		"nb_NO.UTF-8|Norsk" \
		"hu_HU.UTF-8|Magyar" \
		"cs_CZ.UTF-8|Cesky" \
		"ro_RO.UTF-8|Romana" \
		"ca_ES.UTF-8|Catala" \
		"ja_JP.UTF-8|Japanese" \
		"zh_CN.UTF-8|Chinese (Simplified)" || return "$?"

	local keymap_choice
	capture_value keymap_choice choose_option "${T[keymap_label]}" "$(option_index_for_key "$KEYMAP" \
		"fr-latin9|Francais (fr)" \
		"us|English US" \
		"uk|English UK" \
		"de-latin1|Deutsch (de)" \
		"es|Espanol (es)" \
		"it|Italiano (it)" \
		"pt-latin1|Portugues (pt)" \
		"be-latin1|Belge (be)" \
		"br-abnt2|Brasileiro (br)" \
		"ca|Canadien (ca)" \
		"ch|Suisse (ch)" \
		"latam|Latinoamerica" \
		"ru|Russkij (ru)" \
		"pl|Polski (pl)" \
		"nl|Nederlands (nl)" \
		"se|Svenska (se)" \
		"dk|Dansk (dk)" \
		"fi|Suomi (fi)" \
		"no|Norsk (no)" \
		"hu|Magyar (hu)" \
		"cz|Cesky (cz)" \
		"ro|Romana (ro)")" \
		"fr-latin9|Francais (fr)" \
		"us|English US" \
		"uk|English UK" \
		"de-latin1|Deutsch (de)" \
		"es|Espanol (es)" \
		"it|Italiano (it)" \
		"pt-latin1|Portugues (pt)" \
		"be-latin1|Belge (be)" \
		"br-abnt2|Brasileiro (br)" \
		"ca|Canadien (ca)" \
		"ch|Suisse (ch)" \
		"latam|Latinoamerica" \
		"ru|Russkij (ru)" \
		"pl|Polski (pl)" \
		"nl|Nederlands (nl)" \
		"se|Svenska (se)" \
		"dk|Dansk (dk)" \
		"fi|Suomi (fi)" \
		"no|Norsk (no)" \
		"hu|Magyar (hu)" \
		"cz|Cesky (cz)" \
		"ro|Romana (ro)" || return "$?"
	KEYMAP="$keymap_choice"
	XKB_LAYOUT="${KEYMAP%%-*}"
	[[ "$XKB_LAYOUT" == "uk" ]] && XKB_LAYOUT="gb"

	capture_value ROOT_PASSWORD prompt_password_twice "${T[password_root]}" || return "$?"
	if prompt_yes_no "$(printf "${T[password_same]}" "$USERNAME")" "y"; then
		USER_PASSWORD=$ROOT_PASSWORD
	else
		status=$?
		if is_ui_cancel_status "$status"; then
			return "$status"
		fi
		capture_value USER_PASSWORD prompt_password_twice "$(printf "${T[password_user]}" "$USERNAME")" || return "$?"
	fi

	capture_value CPU_VENDOR choose_option "${T[cpu_label]}" 1 \
		"amd|AMD" \
		"intel|Intel" \
		"none|${T[cpu_none]}" || return "$?"
}

collect_system_stack() {
	local kernel_choice status=0

	section "${T[sec_system]}"

	set_yes_no_var ENABLE_MULTILIB "${T[enable_multilib]}" "y" || return "$?"
	set_yes_no_var PREPARE_CHAOTIC "${T[add_chaotic]}" "n" || return "$?"

	capture_value NETWORK_STACK choose_option "${T[net_label]}" 1 \
		"networkmanager|NetworkManager" \
		"systemd-networkd|systemd-networkd + resolved" \
		"iwd|iwd + resolved" \
		"none|${T[net_none]}" || return "$?"

	capture_value AUDIO_STACK choose_option "${T[audio_label]}" 1 \
		"pipewire|PipeWire" \
		"pulseaudio|PulseAudio" \
		"none|${T[audio_alsa]}" || return "$?"

	capture_value BOOTLOADER choose_option "${T[boot_label]}" 1 \
		"grub|GRUB" \
		"systemd-boot|systemd-boot" || return "$?"

	case "$BOOTLOADER" in
		grub)
			EFI_MOUNT_TARGET="/boot/efi"
			set_yes_no_var USE_OS_PROBER "${T[osprober]}" "y" || return "$?"
			;;
		systemd-boot)
			EFI_MOUNT_TARGET="/boot"
			USE_OS_PROBER="no"
			warn "${T[sdboot_warn]}"
			;;
	esac

	capture_value DESKTOP_CHOICE choose_option "${T[desktop_label]}" 1 \
		"gnome|GNOME" \
		"kde|KDE Plasma" \
		"xfce|XFCE" \
		"lxqt|LXQt" \
		"hyprland|Hyprland" \
		"i3|i3" \
		"icewm|IceWM" \
		"sway|Sway" \
		"labwc|Labwc" \
		"none|${T[desktop_tty]}" || return "$?"

	case "$DESKTOP_CHOICE" in
		gnome|kde)
			capture_value SESSION_STACK choose_option "${T[session_label]}" 3 \
				"x11|X11" \
				"wayland|Wayland" \
				"both|X11 + Wayland" || return "$?"
			;;
		xfce|lxqt|i3|icewm)
			SESSION_STACK="x11"
			;;
		hyprland|sway|labwc)
			SESSION_STACK="wayland"
			;;
		none)
			SESSION_STACK="tty"
			;;
	esac

	if [[ "$DESKTOP_CHOICE" != "none" ]]; then
		capture_value DISPLAY_MANAGER choose_option "${T[dm_label]}" 1 \
			"none|${T[dm_none]}" \
			"gdm|GDM" \
			"sddm|SDDM" || return "$?"

		if [[ "$DISPLAY_MANAGER" == "none" ]]; then
			set_yes_no_var AUTOLOGIN "${T[autologin]}" "n" || return "$?"
			set_yes_no_var AUTOSTART_WM "${T[autostart_wm]}" "y" || return "$?"
		else
			AUTOLOGIN="no"
			AUTOSTART_WM="no"
		fi

		capture_value GPU_VENDOR choose_option "${T[gpu_label]}" 1 \
			"amd|AMD" \
			"intel|Intel" \
			"amd-intel|AMD + Intel" \
			"nvidia|${T[gpu_nvidia]}" \
			"generic|${T[gpu_generic]}" || return "$?"

		if [[ "$GPU_VENDOR" == "nvidia" ]]; then
			MESA_MODE="nvidia"
			CUSTOM_MESA_PACKAGE=""
			CUSTOM_MESA_LIB32_PACKAGE=""
		else
			capture_value MESA_MODE choose_option "${T[mesa_label]}" 1 \
				"official|${T[mesa_official]}" \
				"chaotic|Chaotic-AUR" \
				"aur|${T[mesa_compilation]}" || return "$?"

			if [[ "$MESA_MODE" == "chaotic" ]]; then
				PREPARE_CHAOTIC="yes"
				capture_value CUSTOM_MESA_PACKAGE prompt_with_default "${T[mesa_pkg_chaotic]}" "mesa-tkg-git" || return "$?"
				if [[ "$ENABLE_MULTILIB" == "yes" ]]; then
					capture_value CUSTOM_MESA_LIB32_PACKAGE prompt_with_default "${T[mesa_pkg_lib32]}" "lib32-$CUSTOM_MESA_PACKAGE" || return "$?"
				fi
			elif [[ "$MESA_MODE" == "aur" ]]; then
				capture_value CUSTOM_MESA_PACKAGE prompt_with_default "${T[mesa_pkg_aur]}" "mesa-git" || return "$?"
				if [[ "$ENABLE_MULTILIB" == "yes" ]]; then
					capture_value CUSTOM_MESA_LIB32_PACKAGE prompt_with_default "${T[mesa_pkg_lib32_aur]}" "lib32-$CUSTOM_MESA_PACKAGE" || return "$?"
				fi
			fi
		fi
	else
		DISPLAY_MANAGER="none"
		GPU_VENDOR="headless"
		MESA_MODE="headless"
	fi

	capture_value kernel_choice choose_option "${T[kernel_label]}" 1 \
			"linux|linux" \
			"linux-lts|linux-lts" \
			"linux-zen|linux-zen" \
			"linux-hardened|linux-hardened" \
			"linux-tkg-repo|${T[kernel_tkg]}" \
			"chaotic-custom|${T[kernel_chaotic]}" \
			"aur-custom|${T[kernel_aur]}" || return "$?"

	case "$kernel_choice" in
		linux|linux-lts|linux-zen|linux-hardened)
			KERNEL_MODE="official"
			KERNEL_PACKAGE="$kernel_choice"
			KERNEL_HEADERS_PACKAGE="${kernel_choice}-headers"
			KERNEL_REPO_URL=""
			;;
		linux-tkg-repo)
			KERNEL_MODE="repo"
			KERNEL_PACKAGE="linux-tkg"
			KERNEL_HEADERS_PACKAGE="auto"
			KERNEL_REPO_URL="https://github.com/Frogging-Family/linux-tkg.git"
			;;
		chaotic-custom)
			KERNEL_MODE="chaotic"
			PREPARE_CHAOTIC="yes"
			capture_value KERNEL_PACKAGE prompt_non_empty "${T[kernel_pkg_chaotic]}" || return "$?"
			capture_value KERNEL_HEADERS_PACKAGE prompt_with_default "${T[kernel_pkg_headers]}" "${KERNEL_PACKAGE}-headers" || return "$?"
			KERNEL_REPO_URL=""
			;;
		aur-custom)
			KERNEL_MODE="aur"
			capture_value KERNEL_PACKAGE prompt_non_empty "${T[kernel_pkg_aur]}" || return "$?"
			capture_value KERNEL_HEADERS_PACKAGE prompt_with_default "${T[kernel_pkg_headers]}" "${KERNEL_PACKAGE}-headers" || return "$?"
			KERNEL_REPO_URL=""
			;;
	esac

	set_yes_no_var ENABLE_AVAHI "${T[enable_avahi]}" "y" || return "$?"
	set_yes_no_var ENABLE_BLUETOOTH "${T[enable_bt]}" "y" || return "$?"
	set_yes_no_var ENABLE_OPENSSH "${T[enable_ssh]}" "n" || return "$?"
	set_yes_no_var ENABLE_CUPS "${T[enable_cups]}" "$([[ "$ENABLE_CUPS" == "yes" ]] && printf 'y' || printf 'n')" || return "$?"

	configure_user_extras || return "$?"
}

configure_user_extras() {
	local status=0

	section "${T[sec_user]}"

	if [[ "$DESKTOP_CHOICE" == "i3" ]]; then
		set_yes_no_var INSTALL_PICOM "${T[install_picom]}" "$([[ "$INSTALL_PICOM" == "yes" ]] && printf 'y' || printf 'n')" || return "$?"
	fi

	capture_value USER_SHELL_CHOICE choose_option "${T[shell_label]}" "$(option_index_for_key "$USER_SHELL_CHOICE" \
		"bash|Bash" \
		"zsh|Zsh")" \
		"bash|Bash" \
		"zsh|Zsh" || return "$?"

	if [[ "$USER_SHELL_CHOICE" == "zsh" ]]; then
		set_yes_no_var INSTALL_OH_MY_ZSH "${T[install_ohmyzsh]}" "$([[ "$INSTALL_OH_MY_ZSH" == "yes" ]] && printf 'y' || printf 'n')" || return "$?"
		if [[ "$INSTALL_OH_MY_ZSH" == "yes" ]]; then
			set_yes_no_var INSTALL_POWERLEVEL10K "${T[install_p10k]}" "$([[ "$INSTALL_POWERLEVEL10K" == "yes" ]] && printf 'y' || printf 'n')" || return "$?"
		else
			INSTALL_POWERLEVEL10K="no"
		fi
	else
		INSTALL_OH_MY_ZSH="no"
		INSTALL_POWERLEVEL10K="no"
	fi

	capture_value EXTRA_UTILITY_PACKAGES choose_multi_option "${T[cli_label]}" "$EXTRA_UTILITY_PACKAGES" \
		"fastfetch|fastfetch" \
		"btop|btop" \
		"neovim|neovim" \
		"tmux|tmux" \
		"fzf|fzf" \
		"ripgrep|ripgrep" \
		"fd|fd" \
		"bat|bat" \
		"eza|eza" \
		"unzip|unzip" \
		"zip|zip" \
		"reflector|reflector" || return "$?"

	capture_value EXTRA_APP_PACKAGES choose_multi_option "${T[apps_label]}" "$EXTRA_APP_PACKAGES" \
		"chromium|Chromium" \
		"firefox|Firefox" \
		"discord|Discord" \
		"telegram-desktop|Telegram" \
		"thunderbird|Thunderbird" \
		"vlc|VLC" \
		"mpv|mpv" \
		"gimp|GIMP" \
		"inkscape|Inkscape" \
		"obs-studio|OBS Studio" \
		"kdenlive|Kdenlive" \
		"audacity|Audacity" \
		"steam|${T[steam_note]}" \
		"lutris|Lutris" \
		"gamemode|Gamemode" \
		"wine|Wine" \
		"mangohud|MangoHud" || return "$?"

	set_yes_no_var INSTALL_VIRT_SUITE "${T[install_virt]}" "n" || return "$?"
	set_yes_no_var INSTALL_GNS3 "${T[install_gns3]}" "n" || return "$?"

	# Auto-suggere si des paquets gaming sont selectionnes
	local gaming_default="n"
	local _pkg
	for _pkg in steam lutris gamemode wine mangohud; do
		if [[ " $EXTRA_APP_PACKAGES " == *" $_pkg "* ]]; then
			gaming_default="y"
			break
		fi
	done
	set_yes_no_var GAMING_TWEAKS "${T[gaming_tweaks]}" "$gaming_default" || return "$?"
}

collect_linux_tkg_options() {
	local status=0

	section "${T[sec_tkg]}"

	if [[ "$KERNEL_MODE" != "repo" ]]; then
		warn "${T[tkg_warn_select]}"
		return 0
	fi

	cat <<'EOF'
linux-tkg utilise ses propres menus interactifs.
Le script se contente de cloner le depot et lancer makepkg -si.
EOF

	if prompt_yes_no "${T[tkg_url_official]}" "y"; then
		KERNEL_REPO_URL="https://github.com/Frogging-Family/linux-tkg.git"
	else
		status=$?
		if is_ui_cancel_status "$status"; then
			return "$status"
		fi
		capture_value KERNEL_REPO_URL prompt_non_empty "${T[tkg_url_custom]}" || return "$?"
	fi
}

choose_storage_stack() {
	local storage_options status=0

	section "${T[sec_storage]}"
	storage_options=(
		"standard|Standard"
		"luks|LUKS"
		"luks-lvm|LUKS + LVM"
	)
	capture_value STORAGE_STACK choose_option "${T[storage_schema]}" "$(option_index_for_key "$STORAGE_STACK" "${storage_options[@]}")" "${storage_options[@]}" || return "$?"

	case "$STORAGE_STACK" in
		standard)
			FORMAT_ROOT_CONTAINER="no"
			LUKS_PASSWORD=""
			;;
		luks|luks-lvm)
			FORMAT_ROOT_CONTAINER="yes"
			capture_value LUKS_NAME prompt_with_default "${T[luks_name]}" "$LUKS_NAME" || return "$?"
			if [[ -n "$LUKS_PASSWORD" ]]; then
				if prompt_yes_no "${T[luks_reuse]}" "y"; then
					:
				else
					status=$?
					if is_ui_cancel_status "$status"; then
						return "$status"
					fi
					capture_value LUKS_PASSWORD prompt_password_twice "${T[luks_password]}" || return "$?"
				fi
			else
				capture_value LUKS_PASSWORD prompt_password_twice "${T[luks_password]}" || return "$?"
			fi
			if [[ "$STORAGE_STACK" == "luks-lvm" ]]; then
				capture_value LVM_VG_NAME prompt_with_default "${T[lvm_vg]}" "$LVM_VG_NAME" || return "$?"
				capture_value LVM_ROOT_NAME prompt_with_default "${T[lvm_lv_root]}" "$LVM_ROOT_NAME" || return "$?"
				set_yes_no_var LVM_CREATE_HOME "${T[lvm_create_home]}" "$([[ "$LVM_CREATE_HOME" == "yes" ]] && printf 'y' || printf 'n')" || return "$?"
				if [[ "$LVM_CREATE_HOME" == "yes" ]]; then
					capture_value ROOT_LV_SIZE_GIB prompt_positive_integer "${T[lvm_root_size]}" "$ROOT_LV_SIZE_GIB" || return "$?"
					capture_value LVM_HOME_NAME prompt_with_default "${T[lvm_lv_home]}" "$LVM_HOME_NAME" || return "$?"
				fi
				set_yes_no_var LVM_CREATE_SWAP "${T[lvm_create_swap]}" "$([[ "$LVM_CREATE_SWAP" == "yes" ]] && printf 'y' || printf 'n')" || return "$?"
				if [[ "$LVM_CREATE_SWAP" == "yes" ]]; then
					capture_value LVM_SWAP_SIZE_GIB prompt_positive_integer "${T[lvm_swap_size]}" "$LVM_SWAP_SIZE_GIB" || return "$?"
					capture_value LVM_SWAP_NAME prompt_with_default "${T[lvm_lv_swap]}" "$LVM_SWAP_NAME" || return "$?"
				fi
			fi
			;;
	esac
}

configure_btrfs_layout_if_needed() {
	local default_answer

	if [[ "$ROOT_FS" != "btrfs" ]]; then
		USE_BTRFS_SUBVOLUMES="no"
		return 0
	fi

	default_answer=$([[ "$USE_BTRFS_SUBVOLUMES" == "yes" ]] && printf 'y' || printf 'n')
	set_yes_no_var USE_BTRFS_SUBVOLUMES "${T[btrfs_layout]}" "$default_answer"
}

validate_stack_choices() {
	case "$BOOTLOADER" in
		grub)
			EFI_MOUNT_TARGET="/boot/efi"
			;;
		systemd-boot)
			EFI_MOUNT_TARGET="/boot"
			USE_OS_PROBER="no"
			;;
		*)
			die "Bootloader non pris en charge: $BOOTLOADER"
			;;
	esac

	if [[ "$DESKTOP_CHOICE" == "none" ]]; then
		DISPLAY_MANAGER="none"
	fi

	if [[ "$DESKTOP_CHOICE" =~ ^(xfce|lxqt|i3|icewm)$ ]]; then
		SESSION_STACK="x11"
	fi

	if [[ "$DESKTOP_CHOICE" =~ ^(hyprland|sway|labwc)$ ]]; then
		SESSION_STACK="wayland"
	fi

	if [[ "$ROOT_FS" != "btrfs" ]]; then
		USE_BTRFS_SUBVOLUMES="no"
	fi

	case "$STORAGE_STACK" in
		standard)
			FORMAT_ROOT_CONTAINER="no"
			;;
		luks)
			[[ -n "$LUKS_NAME" ]] || die "Le mapping LUKS racine doit avoir un nom."
			;;
		luks-lvm)
			[[ -n "$LUKS_NAME" ]] || die "Le mapping LUKS racine doit avoir un nom."
			[[ -n "$LVM_VG_NAME" && -n "$LVM_ROOT_NAME" ]] || die "Le VG/LV racine doivent etre definis pour LUKS+LVM."
			HOME_PART=""
			SWAP_PART=""
			;;
		*)
			die "Stack de stockage non pris en charge: $STORAGE_STACK"
			;;
	esac

	if [[ "$GPU_VENDOR" == "nvidia" && "$KERNEL_HEADERS_PACKAGE" == "" ]]; then
		die "NVIDIA DKMS requiert un package headers."
	fi

	if [[ "$ENABLE_SWAPFILE" == "yes" ]]; then
		[[ "$SWAPFILE_SIZE_GIB" =~ ^[0-9]+$ ]] && (( SWAPFILE_SIZE_GIB > 0 )) || die "La taille du fichier swap doit etre un entier strictement positif."
	fi

	if [[ "$ENABLE_MULTILIB" != "yes" ]] && selection_string_contains "$EXTRA_APP_PACKAGES" "steam"; then
		warn "${T[steam_multilib_warn]}"
		ENABLE_MULTILIB="yes"
	fi
}

auto_partition_disk() {
	local next_index=1
	local status=0

	section "${T[sec_auto_part]}"
	capture_value TARGET_DISK select_disk || return "$?"

	if prompt_yes_no "$(printf "${T[auto_wipe_warn]}" "$TARGET_DISK")" "n"; then
		:
	else
		status=$?
		if is_ui_cancel_status "$status"; then
			return "$status"
		fi
		die "${T[auto_cancelled]}"
	fi

	capture_value ROOT_FS ask_filesystem "${T[fs_root]}" 1 || return "$?"
	configure_btrfs_layout_if_needed || return "$?"

	if [[ "$STORAGE_STACK" == "luks-lvm" ]]; then
		if [[ "$LVM_CREATE_HOME" == "yes" ]]; then
			capture_value HOME_FS ask_filesystem "${T[fs_home_lv]}" 1 || return "$?"
			FORMAT_HOME="yes"
		else
			HOME_PART=""
			FORMAT_HOME="no"
		fi
		AUTO_CREATE_HOME="no"
		AUTO_CREATE_SWAP="no"
		SWAP_PART=""
	else
		set_yes_no_var AUTO_CREATE_SWAP "${T[auto_swap]}" "y" || return "$?"
		if [[ "$AUTO_CREATE_SWAP" == "yes" ]]; then
			capture_value AUTO_SWAP_SIZE_GIB prompt_positive_integer "${T[auto_swap_size]}" "$AUTO_SWAP_SIZE_GIB" || return "$?"
		fi

		set_yes_no_var AUTO_CREATE_HOME "${T[auto_home]}" "n" || return "$?"
		if [[ "$AUTO_CREATE_HOME" == "yes" ]]; then
			capture_value AUTO_ROOT_SIZE_GIB prompt_positive_integer "${T[auto_root_size]}" "$AUTO_ROOT_SIZE_GIB" || return "$?"
			capture_value HOME_FS ask_filesystem "${T[fs_home]}" 1 || return "$?"
		else
			HOME_PART=""
		fi
	fi

	wipefs -af "$TARGET_DISK"
	sgdisk -Z "$TARGET_DISK"
	sgdisk -o "$TARGET_DISK"

	sgdisk -n ${next_index}:0:+1G -t ${next_index}:ef00 -c ${next_index}:"EFI System" "$TARGET_DISK"
	EFI_PART=$(partition_path "$TARGET_DISK" "$next_index")
	((next_index++))

	if [[ "$STORAGE_STACK" != "luks-lvm" && "$AUTO_CREATE_SWAP" == "yes" ]]; then
		sgdisk -n ${next_index}:0:+${AUTO_SWAP_SIZE_GIB}G -t ${next_index}:8200 -c ${next_index}:"Linux swap" "$TARGET_DISK"
		SWAP_PART=$(partition_path "$TARGET_DISK" "$next_index")
		((next_index++))
	else
		SWAP_PART=""
	fi

	if [[ "$STORAGE_STACK" == "luks-lvm" ]]; then
		sgdisk -n ${next_index}:0:0 -t ${next_index}:8300 -c ${next_index}:"Arch crypt root" "$TARGET_DISK"
		ROOT_PART=$(partition_path "$TARGET_DISK" "$next_index")
		HOME_PART=""
	elif [[ "$AUTO_CREATE_HOME" == "yes" ]]; then
		sgdisk -n ${next_index}:0:+${AUTO_ROOT_SIZE_GIB}G -t ${next_index}:8300 -c ${next_index}:"Arch root" "$TARGET_DISK"
		ROOT_PART=$(partition_path "$TARGET_DISK" "$next_index")
		((next_index++))

		sgdisk -n ${next_index}:0:0 -t ${next_index}:8300 -c ${next_index}:"Arch home" "$TARGET_DISK"
		HOME_PART=$(partition_path "$TARGET_DISK" "$next_index")
	else
		sgdisk -n ${next_index}:0:0 -t ${next_index}:8300 -c ${next_index}:"Arch root" "$TARGET_DISK"
		ROOT_PART=$(partition_path "$TARGET_DISK" "$next_index")
	fi

	partprobe "$TARGET_DISK"
	udevadm settle

	FORMAT_EFI="yes"
	FORMAT_ROOT="yes"
	if [[ "$STORAGE_STACK" != "standard" ]]; then
		FORMAT_ROOT_CONTAINER="yes"
	fi
	FORMAT_HOME=$([[ -n "$HOME_PART" ]] && printf 'yes' || printf 'no')
}

manual_partition_layout() {
	local status=0

	section "${T[sec_manual_part]}"

	capture_value TARGET_DISK select_disk || return "$?"
	if [[ "$PARTITION_MODE" == "cfdisk" ]]; then
		run_interactive_command cfdisk "$TARGET_DISK"
	fi

	capture_value EFI_PART prompt_partition "${T[part_efi]}" || return "$?"
	set_yes_no_var FORMAT_EFI "$(printf "${T[part_format]}" "$EFI_PART" "FAT32")" "n" || return "$?"

	capture_value ROOT_PART prompt_partition "${T[part_root]}" || return "$?"
	case "$STORAGE_STACK" in
		standard|luks)
			if [[ "$STORAGE_STACK" == "luks" ]]; then
				set_yes_no_var FORMAT_ROOT_CONTAINER "$(printf "${T[part_luks_init]}" "$ROOT_PART")" "y" || return "$?"
			fi

			if prompt_yes_no "${T[part_reformat_root]}" "y"; then
				FORMAT_ROOT="yes"
				capture_value ROOT_FS ask_filesystem "${T[fs_root]}" 1 || return "$?"
			else
				status=$?
				if is_ui_cancel_status "$status"; then
					return "$status"
				fi
				FORMAT_ROOT="no"
				if [[ "$STORAGE_STACK" == "standard" ]]; then
					capture_value ROOT_FS detect_or_prompt_filesystem "$ROOT_PART" 1 || return "$?"
				else
					capture_value ROOT_FS ask_filesystem "${T[fs_luks_existing]}" 1 || return "$?"
				fi
			fi
			configure_btrfs_layout_if_needed || return "$?"

			if prompt_yes_no "${T[part_sep_home]}" "n"; then
				capture_value HOME_PART prompt_partition "${T[part_home]}" || return "$?"
				if prompt_yes_no "$(printf "${T[part_reformat]}" "$HOME_PART")" "n"; then
					FORMAT_HOME="yes"
					capture_value HOME_FS ask_filesystem "${T[fs_home]}" 1 || return "$?"
				else
					status=$?
					if is_ui_cancel_status "$status"; then
						return "$status"
					fi
					FORMAT_HOME="no"
					capture_value HOME_FS detect_or_prompt_filesystem "$HOME_PART" 1 || return "$?"
				fi
			else
				status=$?
				if is_ui_cancel_status "$status"; then
					return "$status"
				fi
				HOME_PART=""
				FORMAT_HOME="no"
			fi

			if prompt_yes_no "${T[part_swap_ded]}" "y"; then
				capture_value SWAP_PART prompt_partition "${T[part_swap]}" || return "$?"
			else
				status=$?
				if is_ui_cancel_status "$status"; then
					return "$status"
				fi
				SWAP_PART=""
			fi
			;;
		luks-lvm)
			FORMAT_ROOT_CONTAINER="yes"
			FORMAT_ROOT="yes"
			capture_value ROOT_FS ask_filesystem "${T[fs_root_lv]}" 1 || return "$?"
			configure_btrfs_layout_if_needed || return "$?"
			HOME_PART=""
			SWAP_PART=""
			if [[ "$LVM_CREATE_HOME" == "yes" ]]; then
				FORMAT_HOME="yes"
				capture_value HOME_FS ask_filesystem "${T[fs_lv_home]}" 1 || return "$?"
			else
				FORMAT_HOME="no"
			fi
			;;
	esac
}

collect_partitioning() {
	choose_storage_stack || return "$?"

	capture_value PARTITION_MODE choose_option "${T[part_mode]}" 1 \
		"manual|${T[part_existing]}" \
		"cfdisk|${T[part_cfdisk]}" \
		"auto|${T[part_auto]}" || return "$?"

	case "$PARTITION_MODE" in
		auto)
			auto_partition_disk || return "$?"
			;;
		manual|cfdisk)
			manual_partition_layout || return "$?"
			;;
	esac

	configure_memory_features || return "$?"
}

format_partition() {
	local partition=$1
	local filesystem=$2

	case "$filesystem" in
		ext4)
			run_logged mkfs.ext4 -F "$partition"
			;;
		btrfs)
			run_logged mkfs.btrfs -f "$partition"
			;;
		xfs)
			run_logged mkfs.xfs -f "$partition"
			;;
		f2fs)
			run_logged mkfs.f2fs -f "$partition"
			;;
		*)
			die "Filesystem non pris en charge: $filesystem"
			;;
	esac
}

open_luks_root() {
	if cryptsetup status "$LUKS_NAME" >/dev/null 2>&1; then
		return 0
	fi

	printf '%s' "$LUKS_PASSWORD" | cryptsetup open "$ROOT_PART" "$LUKS_NAME" --key-file -
}

create_btrfs_subvolume_layout() {
	local root_source=$1
	local create_home_subvol=$2
	local mount_opts="noatime,compress=zstd:1"

	run_logged mount "$root_source" "$TARGET_MOUNT"
	if [[ "$FORMAT_ROOT" == "yes" ]]; then
		btrfs subvolume show "$TARGET_MOUNT/@" >/dev/null 2>&1 || run_logged btrfs subvolume create "$TARGET_MOUNT/@"
		if [[ "$create_home_subvol" == "yes" ]]; then
			btrfs subvolume show "$TARGET_MOUNT/@home" >/dev/null 2>&1 || run_logged btrfs subvolume create "$TARGET_MOUNT/@home"
		fi
		btrfs subvolume show "$TARGET_MOUNT/@log" >/dev/null 2>&1 || run_logged btrfs subvolume create "$TARGET_MOUNT/@log"
		btrfs subvolume show "$TARGET_MOUNT/@pkg" >/dev/null 2>&1 || run_logged btrfs subvolume create "$TARGET_MOUNT/@pkg"
		btrfs subvolume show "$TARGET_MOUNT/@snapshots" >/dev/null 2>&1 || run_logged btrfs subvolume create "$TARGET_MOUNT/@snapshots"
	fi
	run_logged umount "$TARGET_MOUNT"

	run_logged mount -o "subvol=@,$mount_opts" "$root_source" "$TARGET_MOUNT"
	run_logged mkdir -p "$TARGET_MOUNT/home" "$TARGET_MOUNT/var/log" "$TARGET_MOUNT/var/cache/pacman/pkg" "$TARGET_MOUNT/.snapshots"
	if [[ "$create_home_subvol" == "yes" ]]; then
		run_logged mount -o "subvol=@home,$mount_opts" "$root_source" "$TARGET_MOUNT/home"
	fi
	run_logged mount -o "subvol=@log,$mount_opts" "$root_source" "$TARGET_MOUNT/var/log"
	run_logged mount -o "subvol=@pkg,$mount_opts" "$root_source" "$TARGET_MOUNT/var/cache/pacman/pkg"
	run_logged mount -o "subvol=@snapshots,$mount_opts" "$root_source" "$TARGET_MOUNT/.snapshots"
}

prepare_target_filesystems() {
	section "PREPARATION DISQUES"
	local root_source="$ROOT_PART"
	local home_source="$HOME_PART"
	local swap_source="$SWAP_PART"
	local create_home_subvol="yes"

	ensure_target_mount_available
	FINAL_ROOT_DEVICE=""
	FINAL_HOME_DEVICE=""
	FINAL_SWAP_DEVICE=""

	if [[ "$FORMAT_EFI" == "yes" ]]; then
		info "Formatage de la partition EFI: $EFI_PART"
		run_logged mkfs.fat -F32 "$EFI_PART"
	fi

	case "$STORAGE_STACK" in
		standard)
			:
			;;
		luks)
			if [[ "$FORMAT_ROOT_CONTAINER" == "yes" ]]; then
				info "Creation du conteneur LUKS sur $ROOT_PART"
				printf '%s' "$LUKS_PASSWORD" | cryptsetup luksFormat --batch-mode "$ROOT_PART" -
			fi
			info "Ouverture du conteneur chiffre $LUKS_NAME"
			open_luks_root
			root_source="/dev/mapper/$LUKS_NAME"
			;;
		luks-lvm)
			if [[ "$FORMAT_ROOT_CONTAINER" == "yes" ]]; then
				info "Creation du conteneur LUKS sur $ROOT_PART"
				printf '%s' "$LUKS_PASSWORD" | cryptsetup luksFormat --batch-mode "$ROOT_PART" -
			fi
			info "Ouverture du conteneur chiffre $LUKS_NAME"
			open_luks_root
			run_logged pvcreate -ff -y "/dev/mapper/$LUKS_NAME"
			run_logged vgcreate "$LVM_VG_NAME" "/dev/mapper/$LUKS_NAME"
			if [[ "$LVM_CREATE_SWAP" == "yes" ]]; then
				run_logged lvcreate -L "${LVM_SWAP_SIZE_GIB}G" -n "$LVM_SWAP_NAME" "$LVM_VG_NAME"
				swap_source="/dev/$LVM_VG_NAME/$LVM_SWAP_NAME"
			else
				swap_source=""
			fi
			if [[ "$LVM_CREATE_HOME" == "yes" ]]; then
				run_logged lvcreate -L "${ROOT_LV_SIZE_GIB}G" -n "$LVM_ROOT_NAME" "$LVM_VG_NAME"
				run_logged lvcreate -l 100%FREE -n "$LVM_HOME_NAME" "$LVM_VG_NAME"
				home_source="/dev/$LVM_VG_NAME/$LVM_HOME_NAME"
			else
				run_logged lvcreate -l 100%FREE -n "$LVM_ROOT_NAME" "$LVM_VG_NAME"
				home_source=""
			fi
			root_source="/dev/$LVM_VG_NAME/$LVM_ROOT_NAME"
			;;
	esac

	if [[ "$FORMAT_ROOT" == "yes" ]]; then
		format_partition "$root_source" "$ROOT_FS"
	fi

	if [[ -n "$home_source" && "$FORMAT_HOME" == "yes" ]]; then
		format_partition "$home_source" "$HOME_FS"
	fi

	if [[ "$ROOT_FS" == "btrfs" && "$USE_BTRFS_SUBVOLUMES" == "yes" ]]; then
		if [[ -n "$home_source" ]]; then
			create_home_subvol="no"
		fi
		create_btrfs_subvolume_layout "$root_source" "$create_home_subvol"
	else
		run_logged mount "$root_source" "$TARGET_MOUNT"
	fi
	run_logged mkdir -p "$TARGET_MOUNT$EFI_MOUNT_TARGET"
	run_logged mount "$EFI_PART" "$TARGET_MOUNT$EFI_MOUNT_TARGET"

	if [[ -n "$home_source" ]]; then
		run_logged mkdir -p "$TARGET_MOUNT/home"
		run_logged mount "$home_source" "$TARGET_MOUNT/home"
	fi

	if [[ -n "$swap_source" ]]; then
		run_logged mkswap "$swap_source"
		run_logged swapon "$swap_source"
	fi

	FINAL_ROOT_DEVICE="$root_source"
	FINAL_HOME_DEVICE="$home_source"
	FINAL_SWAP_DEVICE="$swap_source"
}

build_package_lists() {
	PACSTRAP_PACKAGES=(
		base
		base-devel
		linux-firmware
		sudo
		nano
		vim
		git
		curl
		wget
		rsync
		man-db
		man-pages
		texinfo
		bash-completion
		archlinux-keyring
	)

	OFFICIAL_PACKAGES=(
		efibootmgr
		dosfstools
		mtools
		libdisplay-info
		xdg-user-dirs
		xdg-utils
		noto-fonts
		noto-fonts-emoji
		ttf-dejavu
		vulkan-tools
	)

	CHAOTIC_PACKAGES=()
	AUR_PACKAGES=()
	SERVICES_TO_ENABLE=()

	case "$ROOT_FS" in
		btrfs)
			append_unique PACSTRAP_PACKAGES btrfs-progs
			;;
		xfs)
			append_unique PACSTRAP_PACKAGES xfsprogs
			;;
		f2fs)
			append_unique PACSTRAP_PACKAGES f2fs-tools
			;;
	esac

	case "$HOME_FS" in
		btrfs)
			append_unique PACSTRAP_PACKAGES btrfs-progs
			;;
		xfs)
			append_unique PACSTRAP_PACKAGES xfsprogs
			;;
		f2fs)
			append_unique PACSTRAP_PACKAGES f2fs-tools
			;;
	esac

	case "$CPU_VENDOR" in
		amd)
			append_unique OFFICIAL_PACKAGES amd-ucode
			;;
		intel)
			append_unique OFFICIAL_PACKAGES intel-ucode
			;;
	esac

	case "$STORAGE_STACK" in
		luks)
			append_unique OFFICIAL_PACKAGES cryptsetup
			;;
		luks-lvm)
			append_unique OFFICIAL_PACKAGES cryptsetup lvm2
			;;
	esac

	case "$KERNEL_MODE" in
		official)
			append_unique OFFICIAL_PACKAGES "$KERNEL_PACKAGE" "$KERNEL_HEADERS_PACKAGE"
			;;
		chaotic)
			append_unique CHAOTIC_PACKAGES "$KERNEL_PACKAGE" "$KERNEL_HEADERS_PACKAGE"
			;;
		aur)
			append_unique AUR_PACKAGES "$KERNEL_PACKAGE" "$KERNEL_HEADERS_PACKAGE"
			;;
		repo)
			:
			;;
	esac

	case "$BOOTLOADER" in
		grub)
			append_unique OFFICIAL_PACKAGES grub
			[[ "$USE_OS_PROBER" == "yes" ]] && append_unique OFFICIAL_PACKAGES os-prober
			;;
		systemd-boot)
			append_unique SERVICES_TO_ENABLE systemd-boot-update.service
			;;
	esac

	case "$NETWORK_STACK" in
		networkmanager)
			append_unique OFFICIAL_PACKAGES networkmanager
			append_unique SERVICES_TO_ENABLE NetworkManager
			;;
		systemd-networkd)
			append_unique SERVICES_TO_ENABLE systemd-networkd systemd-resolved
			;;
		iwd)
			append_unique OFFICIAL_PACKAGES iwd
			append_unique SERVICES_TO_ENABLE iwd systemd-resolved
			;;
	esac

	case "$AUDIO_STACK" in
		pipewire)
			append_unique OFFICIAL_PACKAGES alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol
			;;
		pulseaudio)
			append_unique OFFICIAL_PACKAGES alsa-utils pulseaudio pulseaudio-alsa pavucontrol
			;;
		none)
			append_unique OFFICIAL_PACKAGES alsa-utils
			;;
	esac

	if [[ "$ENABLE_AVAHI" == "yes" ]]; then
		append_unique OFFICIAL_PACKAGES avahi nss-mdns
		append_unique SERVICES_TO_ENABLE avahi-daemon
	fi

	if [[ "$ENABLE_BLUETOOTH" == "yes" ]]; then
		append_unique OFFICIAL_PACKAGES bluez bluez-utils
		append_unique SERVICES_TO_ENABLE bluetooth
	fi

	if [[ "$ENABLE_OPENSSH" == "yes" ]]; then
		append_unique OFFICIAL_PACKAGES openssh
		append_unique SERVICES_TO_ENABLE sshd
	fi

	if [[ "$ENABLE_CUPS" == "yes" ]]; then
		append_unique OFFICIAL_PACKAGES cups
		append_unique SERVICES_TO_ENABLE cups.service
	fi

	if [[ "$ENABLE_ZRAM" == "yes" ]]; then
		append_unique OFFICIAL_PACKAGES zram-generator
	fi

	if [[ "$ENABLE_MULTILIB" == "yes" ]]; then
		append_unique OFFICIAL_PACKAGES lib32-libdisplay-info
	fi

	if [[ "$USER_SHELL_CHOICE" == "zsh" ]]; then
		append_unique OFFICIAL_PACKAGES zsh
	fi

	local -a extra_utility_packages=()
	read -r -a extra_utility_packages <<< "$EXTRA_UTILITY_PACKAGES"
	if ((${#extra_utility_packages[@]})); then
		append_unique OFFICIAL_PACKAGES "${extra_utility_packages[@]}"
	fi

	local -a extra_app_packages=()
	read -r -a extra_app_packages <<< "$EXTRA_APP_PACKAGES"
	if ((${#extra_app_packages[@]})); then
		append_unique OFFICIAL_PACKAGES "${extra_app_packages[@]}"
		if [[ "$ENABLE_MULTILIB" == "yes" ]]; then
			contains_word "gamemode" "${extra_app_packages[@]}" && append_unique OFFICIAL_PACKAGES lib32-gamemode
			contains_word "wine" "${extra_app_packages[@]}" && append_unique OFFICIAL_PACKAGES lib32-gnutls lib32-libpulse
			contains_word "mangohud" "${extra_app_packages[@]}" && append_unique OFFICIAL_PACKAGES lib32-mangohud
		fi
	fi

	if [[ "$INSTALL_GNS3" == "yes" ]]; then
		append_unique OFFICIAL_PACKAGES docker wireshark-qt qemu-full libvirt dnsmasq iptables-nft gperftools tigervnc inetutils python-pip
		append_unique AUR_PACKAGES gns3-gui dynamips ubridge vpcs
		append_unique SERVICES_TO_ENABLE docker libvirtd virtlogd
	fi

	if [[ "$INSTALL_VIRT_SUITE" == "yes" ]]; then
		append_unique OFFICIAL_PACKAGES qemu-full libvirt virt-manager virt-viewer dnsmasq iptables-nft edk2-ovmf swtpm
		append_unique SERVICES_TO_ENABLE libvirtd virtlogd
	fi

	if [[ "$DESKTOP_CHOICE" != "none" ]]; then
		append_unique OFFICIAL_PACKAGES dbus-broker gvfs thunar
	fi

	# qt5ct/qt6ct pour le theming Qt sur les WM minimalistes (pas besoin sur GNOME/KDE)
	if [[ "$DESKTOP_CHOICE" != "gnome" && "$DESKTOP_CHOICE" != "kde" && "$DESKTOP_CHOICE" != "none" ]]; then
		append_unique OFFICIAL_PACKAGES qt5ct qt6ct
	fi

	if [[ "$SESSION_STACK" == "x11" || "$SESSION_STACK" == "both" ]]; then
		append_unique OFFICIAL_PACKAGES xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xinput
	fi

	if [[ "$SESSION_STACK" == "wayland" || "$SESSION_STACK" == "both" ]]; then
		append_unique OFFICIAL_PACKAGES wayland wayland-protocols xdg-desktop-portal xdg-desktop-portal-gtk qt5-wayland qt6-wayland wl-clipboard
	fi

	if [[ "$DESKTOP_CHOICE" != "none" ]]; then
		case "$GPU_VENDOR" in
			amd)
				case "$MESA_MODE" in
					official)
						append_unique OFFICIAL_PACKAGES mesa mesa-utils vulkan-radeon libva-mesa-driver
						[[ "$ENABLE_MULTILIB" == "yes" ]] && append_unique OFFICIAL_PACKAGES lib32-mesa lib32-vulkan-radeon
						;;
					chaotic)
						append_unique CHAOTIC_PACKAGES "$CUSTOM_MESA_PACKAGE"
						[[ "$ENABLE_MULTILIB" == "yes" && -n "$CUSTOM_MESA_LIB32_PACKAGE" ]] && append_unique CHAOTIC_PACKAGES "$CUSTOM_MESA_LIB32_PACKAGE"
						;;
					aur)
						append_unique AUR_PACKAGES "$CUSTOM_MESA_PACKAGE"
						[[ "$ENABLE_MULTILIB" == "yes" && -n "$CUSTOM_MESA_LIB32_PACKAGE" ]] && append_unique AUR_PACKAGES "$CUSTOM_MESA_LIB32_PACKAGE"
						;;
				esac
				;;
			intel)
				case "$MESA_MODE" in
					official)
						append_unique OFFICIAL_PACKAGES mesa mesa-utils vulkan-intel intel-media-driver
						[[ "$ENABLE_MULTILIB" == "yes" ]] && append_unique OFFICIAL_PACKAGES lib32-mesa lib32-vulkan-intel
						;;
					chaotic)
						append_unique CHAOTIC_PACKAGES "$CUSTOM_MESA_PACKAGE"
						[[ "$ENABLE_MULTILIB" == "yes" && -n "$CUSTOM_MESA_LIB32_PACKAGE" ]] && append_unique CHAOTIC_PACKAGES "$CUSTOM_MESA_LIB32_PACKAGE"
						;;
					aur)
						append_unique AUR_PACKAGES "$CUSTOM_MESA_PACKAGE"
						[[ "$ENABLE_MULTILIB" == "yes" && -n "$CUSTOM_MESA_LIB32_PACKAGE" ]] && append_unique AUR_PACKAGES "$CUSTOM_MESA_LIB32_PACKAGE"
						;;
				esac
				;;
			amd-intel)
				case "$MESA_MODE" in
					official)
						append_unique OFFICIAL_PACKAGES mesa mesa-utils vulkan-radeon vulkan-intel intel-media-driver libva-mesa-driver
						[[ "$ENABLE_MULTILIB" == "yes" ]] && append_unique OFFICIAL_PACKAGES lib32-mesa lib32-vulkan-radeon lib32-vulkan-intel
						;;
					chaotic)
						append_unique CHAOTIC_PACKAGES "$CUSTOM_MESA_PACKAGE"
						[[ "$ENABLE_MULTILIB" == "yes" && -n "$CUSTOM_MESA_LIB32_PACKAGE" ]] && append_unique CHAOTIC_PACKAGES "$CUSTOM_MESA_LIB32_PACKAGE"
						;;
					aur)
						append_unique AUR_PACKAGES "$CUSTOM_MESA_PACKAGE"
						[[ "$ENABLE_MULTILIB" == "yes" && -n "$CUSTOM_MESA_LIB32_PACKAGE" ]] && append_unique AUR_PACKAGES "$CUSTOM_MESA_LIB32_PACKAGE"
						;;
				esac
				;;
			nvidia)
				append_unique OFFICIAL_PACKAGES dkms nvidia-dkms nvidia-utils nvidia-settings
				[[ "$ENABLE_MULTILIB" == "yes" ]] && append_unique OFFICIAL_PACKAGES lib32-nvidia-utils
				;;
			generic)
				case "$MESA_MODE" in
					official)
						append_unique OFFICIAL_PACKAGES mesa mesa-utils
						[[ "$ENABLE_MULTILIB" == "yes" ]] && append_unique OFFICIAL_PACKAGES lib32-mesa
						;;
					chaotic)
						append_unique CHAOTIC_PACKAGES "$CUSTOM_MESA_PACKAGE"
						[[ "$ENABLE_MULTILIB" == "yes" && -n "$CUSTOM_MESA_LIB32_PACKAGE" ]] && append_unique CHAOTIC_PACKAGES "$CUSTOM_MESA_LIB32_PACKAGE"
						;;
					aur)
						append_unique AUR_PACKAGES "$CUSTOM_MESA_PACKAGE"
						[[ "$ENABLE_MULTILIB" == "yes" && -n "$CUSTOM_MESA_LIB32_PACKAGE" ]] && append_unique AUR_PACKAGES "$CUSTOM_MESA_LIB32_PACKAGE"
						;;
				esac
				;;
		esac
	fi

	case "$DESKTOP_CHOICE" in
		gnome)
			append_unique OFFICIAL_PACKAGES gnome gnome-tweaks
			;;
		kde)
			append_unique OFFICIAL_PACKAGES plasma-meta konsole dolphin kate ark spectacle
			;;
		xfce)
			append_unique OFFICIAL_PACKAGES xfce4 xfce4-goodies
			;;
		lxqt)
			append_unique OFFICIAL_PACKAGES lxqt qterminal featherpad breeze-icons
			;;
		hyprland)
			append_unique OFFICIAL_PACKAGES hyprland kitty foot waybar wofi rofi swaybg swaylock mako grim slurp brightnessctl playerctl nautilus virt-manager code kservice elementary-icon-theme xdg-desktop-portal-hyprland polkit-gnome
			[[ "$NETWORK_STACK" == "networkmanager" ]] && append_unique OFFICIAL_PACKAGES network-manager-applet
			[[ "$ENABLE_BLUETOOTH" == "yes" ]] && append_unique OFFICIAL_PACKAGES blueman
			;;
		i3)
			append_unique OFFICIAL_PACKAGES i3-wm i3status i3lock kitty rofi feh dunst maim slop xclip brightnessctl playerctl thunar virt-manager code polkit-gnome
			[[ "$INSTALL_PICOM" == "yes" ]] && append_unique OFFICIAL_PACKAGES picom
			[[ "$NETWORK_STACK" == "networkmanager" ]] && append_unique OFFICIAL_PACKAGES network-manager-applet
			[[ "$ENABLE_BLUETOOTH" == "yes" ]] && append_unique OFFICIAL_PACKAGES blueman
			;;
		icewm)
			append_unique OFFICIAL_PACKAGES icewm xterm xorg-setxkbmap
			;;
		sway)
			append_unique OFFICIAL_PACKAGES sway foot swaybg swayidle swaylock waybar wofi mako grim slurp brightnessctl playerctl thunar virt-manager code elementary-icon-theme xdg-desktop-portal-wlr polkit-gnome
			[[ "$NETWORK_STACK" == "networkmanager" ]] && append_unique OFFICIAL_PACKAGES network-manager-applet
			[[ "$ENABLE_BLUETOOTH" == "yes" ]] && append_unique OFFICIAL_PACKAGES blueman
			;;
		labwc)
			append_unique OFFICIAL_PACKAGES labwc swaybg swayidle swaylock waybar wofi xdg-desktop-portal-wlr polkit-gnome
			;;
	esac

	case "$DISPLAY_MANAGER" in
		gdm)
			append_unique OFFICIAL_PACKAGES gdm
			append_unique SERVICES_TO_ENABLE gdm
			;;
		sddm)
			append_unique OFFICIAL_PACKAGES sddm
			append_unique SERVICES_TO_ENABLE sddm
			;;
	esac
}

pretty_bool() {
	case "$1" in
		yes)
			printf 'ON'
			;;
		no)
			printf 'OFF'
			;;
		*)
			printf '%s' "$1"
			;;
	esac
}

pretty_label() {
	local category=$1
	local value=$2

	case "$category:$value" in
		cpu:amd)
			printf 'AMD'
			;;
		cpu:intel)
			printf 'Intel'
			;;
		cpu:none)
			printf '%s' "${T[pl_none]}"
			;;
		gpu:amd)
			printf 'AMD'
			;;
		gpu:intel)
			printf 'Intel'
			;;
		gpu:amd-intel)
			printf 'AMD + Intel'
			;;
		gpu:nvidia)
			printf '%s' "${T[pl_nvidia]}"
			;;
		gpu:generic)
			printf '%s' "${T[pl_generic]}"
			;;
		gpu:headless)
			printf '%s' "${T[pl_no_gpu]}"
			;;
		network:networkmanager)
			printf 'NetworkManager'
			;;
		network:systemd-networkd)
			printf 'systemd-networkd'
			;;
		network:iwd)
			printf 'iwd'
			;;
		network:none)
			printf '%s' "${T[pl_manual]}"
			;;
		audio:pipewire)
			printf 'PipeWire'
			;;
		audio:pulseaudio)
			printf 'PulseAudio'
			;;
		audio:none)
			printf 'ALSA'
			;;
		bootloader:grub)
			printf 'GRUB'
			;;
		bootloader:systemd-boot)
			printf 'systemd-boot'
			;;
		desktop:gnome)
			printf 'GNOME'
			;;
		desktop:kde)
			printf 'KDE Plasma'
			;;
		desktop:xfce)
			printf 'XFCE'
			;;
		desktop:lxqt)
			printf 'LXQt'
			;;
		desktop:hyprland)
			printf 'Hyprland'
			;;
		desktop:i3)
			printf 'i3'
			;;
		desktop:icewm)
			printf 'IceWM'
			;;
		desktop:sway)
			printf 'Sway'
			;;
		desktop:labwc)
			printf 'Labwc'
			;;
		desktop:none)
			printf 'TTY'
			;;
		session:x11)
			printf 'X11'
			;;
		session:wayland)
			printf 'Wayland'
			;;
		session:both)
			printf 'X11 + Wayland'
			;;
		session:tty)
			printf 'TTY'
			;;
		display:none)
			printf '%s' "${T[pl_none]}"
			;;
		display:gdm)
			printf 'GDM'
			;;
		display:sddm)
			printf 'SDDM'
			;;
		shell:bash)
			printf 'Bash'
			;;
		shell:zsh)
			printf 'Zsh'
			;;
		storage:standard)
			printf '%s' "${T[pl_simple]}"
			;;
		storage:luks)
			printf 'LUKS'
			;;
		storage:luks-lvm)
			printf 'LUKS + LVM'
			;;
		kernel-mode:official)
			printf '%s' "${T[pl_official]}"
			;;
		kernel-mode:repo)
			printf '%s' "${T[pl_git_repo]}"
			;;
		kernel-mode:chaotic)
			printf 'Chaotic-AUR'
			;;
		kernel-mode:aur)
			printf 'AUR'
			;;
		*)
			printf '%s' "$value"
			;;
	esac
}

short_device_label() {
	local value=${1:-}

	if [[ -n "$value" ]]; then
		printf '%s' "${value##*/}"
	else
		printf 'TODO'
	fi
}

ready_label() {
	if [[ -n "${1:-}" ]]; then
		printf 'OK'
	else
		printf 'TODO'
	fi
}

pair_ready_label() {
	if [[ -n "${1:-}" && -n "${2:-}" ]]; then
		printf 'OK'
	else
		printf 'TODO'
	fi
}

count_selected_items() {
	local values=${1:-}
	local -a items=()

	read -r -a items <<< "$values"
	printf '%s' "${#items[@]}"
}

compact_inline_text() {
	local value=${1:-}

	value=$(printf '%s' "$value" | tr '\n' ' ' | xargs 2>/dev/null || true)
	printf '%s' "$value"
}

truncate_display_text() {
	local value max_length

	value=$(compact_inline_text "${1:-}")
	max_length=${2:-64}

	if (( ${#value} > max_length )); then
		printf '%s...' "${value:0:max_length-3}"
	else
		printf '%s' "$value"
	fi
}

describe_live_pc_label() {
	local vendor="" product="" label=""

	[[ -r /sys/devices/virtual/dmi/id/sys_vendor ]] && vendor=$(</sys/devices/virtual/dmi/id/sys_vendor)
	[[ -r /sys/devices/virtual/dmi/id/product_name ]] && product=$(</sys/devices/virtual/dmi/id/product_name)
	label=$(printf '%s %s' "$vendor" "$product" | xargs 2>/dev/null || true)
	[[ -z "$label" ]] && label="Live ISO"

	truncate_display_text "$label" 72
}

describe_live_pc_specs() {
	local cpu_label ram_label disk_label first_disk=""
	local mem_total_kib=""
	local disk_count=0
	local disk=""

	cpu_label=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null | xargs 2>/dev/null || true)
	[[ -z "$cpu_label" ]] && cpu_label="CPU non detecte"

	mem_total_kib=$(awk '/MemTotal/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)
	if [[ -n "$mem_total_kib" ]]; then
		ram_label=$(awk -v kib="$mem_total_kib" 'BEGIN { printf "%.1f GiB", kib / 1048576 }')
	else
		ram_label="RAM n/a"
	fi

	while IFS= read -r disk; do
		((disk_count += 1))
		if (( disk_count == 1 )); then
			first_disk=$(lsblk -dn -o SIZE,MODEL "$disk" 2>/dev/null | head -n1 | xargs 2>/dev/null || true)
			[[ -z "$first_disk" ]] && first_disk=$(lsblk -dn -o SIZE "$disk" 2>/dev/null | head -n1 | xargs 2>/dev/null || true)
		fi
	done < <(lsblk -dn -o PATH,TYPE 2>/dev/null | awk '$2 == "disk" {print $1}' || true)

	if (( disk_count == 0 )); then
		disk_label="DISK n/a"
	elif (( disk_count == 1 )); then
		disk_label="DISK ${first_disk:-non detecte}"
	else
		disk_label="DISK ${first_disk:-non detecte} (+$((disk_count - 1)))"
	fi

	printf 'CPU %s / RAM %s / %s' "$(truncate_display_text "$cpu_label" 28)" "$ram_label" "$(truncate_display_text "$disk_label" 28)"
}

describe_identity_status() {
	printf '%s / %s / %s %s' "$HOSTNAME" "$USERNAME" "${T[desc_secrets]}" "$(pair_ready_label "$ROOT_PASSWORD" "$USER_PASSWORD")"
}

describe_system_status() {
	printf '%s / %s / %s' "$(pretty_label bootloader "$BOOTLOADER")" "$KERNEL_PACKAGE" "$(pretty_label desktop "$DESKTOP_CHOICE")"
}

describe_user_status() {
	local extra_count

	extra_count=$(count_selected_items "$EXTRA_UTILITY_PACKAGES")
	if (( extra_count == 0 )); then
		printf '%s / %s' "$(pretty_label shell "$USER_SHELL_CHOICE")" "${T[desc_no_extra]}"
	else
		printf '%s / %s %s' "$(pretty_label shell "$USER_SHELL_CHOICE")" "$extra_count" "$([[ "$extra_count" -gt 1 ]] && printf '%s' "${T[desc_extras_s]}" || printf '%s' "${T[desc_extra_s]}")"
	fi
}

describe_storage_status() {
	local memory_parts=()

	if [[ "$ENABLE_SWAPFILE" == "yes" ]]; then
		memory_parts+=("swapfile ${SWAPFILE_SIZE_GIB}G")
	fi
	if [[ "$ENABLE_ZRAM" == "yes" ]]; then
		memory_parts+=("zram auto")
	fi

	if ((${#memory_parts[@]})); then
		printf '%s / root %s / %s' "$(pretty_label storage "$STORAGE_STACK")" "$(short_device_label "$ROOT_PART")" "$(IFS=', '; printf '%s' "${memory_parts[*]}")"
	else
		printf '%s / root %s' "$(pretty_label storage "$STORAGE_STACK")" "$(short_device_label "$ROOT_PART")"
	fi
}

describe_tkg_status() {
	if [[ "$KERNEL_MODE" == "repo" ]]; then
		printf '%s' "${T[desc_active]}"
	else
		printf '%s' "${T[desc_inactive]}"
	fi
}

render_summary() {
	cat <<EOF
${T[sum_identity]}
  ${T[sum_machine]}      : $HOSTNAME
  ${T[sum_user]}  : $USERNAME
  ${T[sum_locale]}       : $LOCALE / $KEYMAP ($XKB_LAYOUT)
  ${T[sum_timezone]}     : $TIMEZONE
  ${T[sum_secrets]}      : root $(ready_label "$ROOT_PASSWORD") / user $(ready_label "$USER_PASSWORD") / luks $(ready_label "$LUKS_PASSWORD")

${T[sum_system]}
  ${T[sum_boot]}         : $(pretty_label bootloader "$BOOTLOADER")
  ${T[sum_kernel]}        : $KERNEL_PACKAGE
  ${T[sum_desktop]}       : $(pretty_label desktop "$DESKTOP_CHOICE") / $(pretty_label session "$SESSION_STACK")
  ${T[sum_gpu]}          : $(pretty_label gpu "$GPU_VENDOR")
  ${T[sum_network]}       : $(pretty_label network "$NETWORK_STACK")
  ${T[sum_audio]}        : $(pretty_label audio "$AUDIO_STACK")
  ${T[sum_shell]}        : $(pretty_label shell "$USER_SHELL_CHOICE")
  ${T[sum_cli]}          : ${EXTRA_UTILITY_PACKAGES:-${T[sum_none]}}
  ${T[sum_options]}      : multilib $(pretty_bool "$ENABLE_MULTILIB") / avahi $(pretty_bool "$ENABLE_AVAHI") / bt $(pretty_bool "$ENABLE_BLUETOOTH") / ssh $(pretty_bool "$ENABLE_OPENSSH") / cups $(pretty_bool "$ENABLE_CUPS")
  ${T[sum_virt]}         : qemu $(pretty_bool "$INSTALL_VIRT_SUITE") / gns3 $(pretty_bool "$INSTALL_GNS3")
  ${T[sum_extras]}       : os-prober $(pretty_bool "$USE_OS_PROBER") / chaotic $(pretty_bool "$PREPARE_CHAOTIC") / tkg $([[ "$KERNEL_MODE" == "repo" ]] && printf 'ON' || printf 'OFF')

${T[sum_storage]}
  ${T[sum_mode]}         : $(pretty_label storage "$STORAGE_STACK")
  ${T[sum_disk]}       : ${TARGET_DISK:---}
  ${T[sum_efi]}          : ${EFI_PART:---} / format $(pretty_bool "$FORMAT_EFI")
  ${T[sum_root]}      : ${ROOT_PART:---} / ${ROOT_FS:-n/a}
  ${T[sum_home]}         : ${HOME_PART:---} / ${HOME_FS:-n/a}
  ${T[sum_swap]}         : ${SWAP_PART:---}
  ${T[sum_swapfile]}     : $([[ "$ENABLE_SWAPFILE" == "yes" ]] && printf '%s GiB' "$SWAPFILE_SIZE_GIB" || printf 'OFF')
  ${T[sum_zram]}         : $([[ "$ENABLE_ZRAM" == "yes" ]] && printf 'ON (auto)' || printf 'OFF')
  ${T[sum_luks]}         : $([[ "$STORAGE_STACK" == "standard" ]] && printf 'OFF' || printf '%s' "$LUKS_NAME")
  ${T[sum_lvm]}          : $([[ "$STORAGE_STACK" == "luks-lvm" ]] && printf '%s [%s,%s,%s]' "$LVM_VG_NAME" "$LVM_ROOT_NAME" "$LVM_HOME_NAME" "$LVM_SWAP_NAME" || printf 'OFF')
  ${T[sum_btrfs]}        : subvol $(pretty_bool "$USE_BTRFS_SUBVOLUMES")

${T[sum_packages]}
  ${T[sum_base]}         : ${#PACSTRAP_PACKAGES[@]}
  ${T[sum_official]}    : ${#OFFICIAL_PACKAGES[@]}
  ${T[sum_chaotic]}      : ${#CHAOTIC_PACKAGES[@]}
  ${T[sum_aur]}          : ${#AUR_PACKAGES[@]}
  ${T[sum_services]}     : ${SERVICES_TO_ENABLE[*]:---}
EOF
}

render_dashboard_overview() {
	local pc_label hw_label

	pc_label=$(describe_live_pc_label)
	hw_label=$(describe_live_pc_specs)

	cat <<EOF
${T[dash_pc]} : $pc_label
${T[dash_hw]} : $hw_label

${T[dash_cancel]}

${T[dash_state]} : ${T[menu_identity]} $(pair_ready_label "$ROOT_PASSWORD" "$USER_PASSWORD") / ${T[menu_storage]} $(ready_label "$ROOT_PART")
EOF
}

show_summary() {
	local confirm=${1:-yes}

	section "${T[sec_verify]}"
	if use_tui; then
		local summary_file
		summary_file=$(mktemp "$WORKDIR/summary.XXXXXX")
		render_summary > "$summary_file"
		whiptail --backtitle "$SCRIPT_NAME" --title "${T[summary_title]}" --scrolltext --textbox "$summary_file" 30 100 </dev/tty >/dev/tty 2>/dev/tty
		rm -f "$summary_file"
	else
		render_summary
	fi

	[[ "$confirm" == "no" ]] && return 0

	if ! prompt_yes_no "${T[summary_confirm]}" "n"; then
		local status=$?
		if is_ui_cancel_status "$status"; then
			return "$status"
		fi
		return "$UI_CANCEL_STATUS"
	fi

	# Confirmation destructive explicite : affiche le disque et les partitions cibles
	local danger_msg
	danger_msg="$(printf \
'%s\n\n'\
'%s :\n\n'\
'  Disque    : %s\n'\
'  EFI       : %s\n'\
'  Root      : %s\n'\
'%s'\
'%s'\
'\n%s\n\n'\
'%s' \
		"${T[danger_msg_header]}" \
		"${T[danger_msg_body]}" \
		"${TARGET_DISK:-${T[unknown]}}" \
		"${EFI_PART:-—}" \
		"${ROOT_PART:-—}" \
		"$([ -n "$HOME_PART" ] && printf '  Home      : %s\n' "$HOME_PART")" \
		"$([ -n "$SWAP_PART" ] && printf '  Swap      : %s\n' "$SWAP_PART")" \
		"${T[danger_no_undo]}" \
		"${T[danger_confirm]}")"

	if use_tui; then
		if ! whiptail --backtitle "$SCRIPT_NAME" --title "${T[danger_title]}" \
			--defaultno --yesno "$danger_msg" 18 70 </dev/tty >/dev/tty 2>/dev/tty; then
			return "$UI_CANCEL_STATUS"
		fi
	else
		warn "$danger_msg"
		if ! prompt_yes_no "${T[danger_confirm_cli]}" "n"; then
			return "$UI_CANCEL_STATUS"
		fi
	fi

	return 0
}

save_profile_interactive() {
	local profile_path

	section "${T[sec_save_profile]}"
	mkdir -p "$WORKDIR/profiles"
	capture_value profile_path prompt_with_default "${T[profile_path]}" "$WORKDIR/profiles/default.conf" || return "$?"
	: > "$profile_path"
	write_scalar_vars "$profile_path" \
		HOSTNAME USERNAME TIMEZONE LOCALE KEYMAP XKB_LAYOUT CPU_VENDOR GPU_VENDOR \
		NETWORK_STACK AUDIO_STACK DESKTOP_CHOICE SESSION_STACK DISPLAY_MANAGER \
		ENABLE_MULTILIB ENABLE_AVAHI ENABLE_BLUETOOTH ENABLE_OPENSSH ENABLE_CUPS USER_SHELL_CHOICE \
		INSTALL_OH_MY_ZSH INSTALL_POWERLEVEL10K EXTRA_UTILITY_PACKAGES EXTRA_APP_PACKAGES INSTALL_VIRT_SUITE INSTALL_GNS3 GAMING_TWEAKS USE_OS_PROBER \
		PREPARE_CHAOTIC AUTOLOGIN AUTOSTART_WM INSTALL_PICOM BOOTLOADER EFI_MOUNT_TARGET KERNEL_REPO_URL STORAGE_STACK \
		USE_BTRFS_SUBVOLUMES FORMAT_ROOT_CONTAINER LUKS_NAME LVM_VG_NAME LVM_ROOT_NAME \
		LVM_HOME_NAME LVM_SWAP_NAME LVM_CREATE_HOME LVM_CREATE_SWAP ROOT_LV_SIZE_GIB \
		LVM_SWAP_SIZE_GIB KERNEL_MODE KERNEL_PACKAGE KERNEL_HEADERS_PACKAGE MESA_MODE \
		CUSTOM_MESA_PACKAGE CUSTOM_MESA_LIB32_PACKAGE TARGET_DISK PARTITION_MODE EFI_PART \
		ROOT_PART HOME_PART SWAP_PART FORMAT_EFI FORMAT_ROOT FORMAT_HOME ROOT_FS HOME_FS \
		AUTO_CREATE_HOME AUTO_CREATE_SWAP AUTO_SWAP_SIZE_GIB AUTO_ROOT_SIZE_GIB \
		ENABLE_SWAPFILE SWAPFILE_SIZE_GIB ENABLE_ZRAM
	chmod 600 "$profile_path"
	info "$(printf "${T[profile_saved]}" "$profile_path")"
	warn "${T[profile_no_pass]}"
}

load_profile_interactive() {
	local profile_path

	section "${T[sec_load_profile]}"
	capture_value profile_path prompt_with_default "${T[profile_path]}" "$WORKDIR/profiles/default.conf" || return "$?"
	[[ -f "$profile_path" ]] || die "$(printf "${T[profile_notfound]}" "$profile_path")"

	# shellcheck disable=SC1090
	source "$profile_path"
	FINAL_ROOT_DEVICE=""
	FINAL_HOME_DEVICE=""
	FINAL_SWAP_DEVICE=""
	validate_stack_choices
	info "$(printf "${T[profile_loaded]}" "$profile_path")"
	if [[ -z "$ROOT_PASSWORD" || -z "$USER_PASSWORD" ]]; then
		warn "${T[profile_pass_warn]}"
	fi
}

ensure_ready_for_install() {
	if [[ -z "$ROOT_PASSWORD" || -z "$USER_PASSWORD" ]]; then
		warn "${T[check_no_pass]}"
		collect_identity || return "$?"
	fi

	if [[ "$STORAGE_STACK" != "standard" && -z "$LUKS_PASSWORD" ]]; then
		warn "${T[check_no_luks]}"
		choose_storage_stack || return "$?"
	fi

	if [[ -z "$EFI_PART" || -z "$ROOT_PART" ]]; then
		warn "${T[check_no_part]}"
		collect_partitioning || return "$?"
	fi

	validate_stack_choices
	build_package_lists
	show_summary
}

main_menu_loop() {
	local menu_options action action_status menu_text

	while true; do
		if use_tui; then
			menu_text=$(render_dashboard_overview)
			action=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "${T[menu_title]}" --default-item "${T[menu_identity]}" --menu "$menu_text" 24 100 11 \
				"${T[menu_identity]}" "$(describe_identity_status)" \
				"${T[menu_system]}" "$(describe_system_status)" \
				"${T[menu_user]}" "$(describe_user_status)" \
				"${T[menu_storage]}" "$(describe_storage_status)" \
				"${T[menu_network]}" "${T[menu_network]}" \
				"${T[menu_tkg]}" "$(describe_tkg_status)" \
				"${T[menu_save]}" "${T[menu_save_desc]}" \
				"${T[menu_load]}" "${T[menu_load_desc]}" \
				"${T[menu_summary]}" "${T[menu_summary_desc]}" \
				"${T[menu_install]}" "${T[menu_install_desc]}" \
				"${T[menu_quit]}" "${T[menu_quit]}") || action="${T[menu_quit]}"
		else
			section "${T[sec_menu]}"
			printf '%s   : %s\n' "${T[dash_pc]}" "$(describe_live_pc_label)"
			printf '%s   : %s\n' "${T[dash_hw]}" "$(describe_live_pc_specs)"
			printf '%s: %s=%s, %s=%s, %s=%s\n' "${T[dash_state]}" "${T[menu_identity]}" "$(pair_ready_label "$ROOT_PASSWORD" "$USER_PASSWORD")" "${T[menu_system]}" "$KERNEL_PACKAGE" "${T[menu_storage]}" "$(ready_label "$ROOT_PART")"
			menu_options=(
				"${T[menu_identity]}|$(describe_identity_status)"
				"${T[menu_system]}|$(describe_system_status)"
				"${T[menu_user]}|$(describe_user_status)"
				"${T[menu_storage]}|$(describe_storage_status)"
				"${T[menu_network]}|${T[menu_network]}"
				"${T[menu_tkg]}|$(describe_tkg_status)"
				"${T[menu_save]}|${T[menu_save_desc]}"
				"${T[menu_load]}|${T[menu_load_desc]}"
				"${T[menu_summary]}|${T[menu_summary_desc]}"
				"${T[menu_install]}|${T[menu_install_desc]}"
				"${T[menu_quit]}|${T[menu_quit]}"
			)
			action=$(choose_option "${T[menu_main]}" 1 "${menu_options[@]}")
		fi

		case "$action" in
			"${T[menu_identity]}")
				run_menu_action collect_identity
				;;
			"${T[menu_system]}")
				run_menu_action collect_system_stack
				;;
			"${T[menu_user]}")
				run_menu_action configure_user_extras
				;;
			"${T[menu_storage]}")
				run_menu_action collect_partitioning
				;;
			"${T[menu_network]}")
				run_menu_action configure_live_network
				;;
			"${T[menu_tkg]}")
				run_menu_action collect_linux_tkg_options
				;;
			"${T[menu_save]}")
				run_menu_action save_profile_interactive
				;;
			"${T[menu_load]}")
				run_menu_action load_profile_interactive
				;;
			"${T[menu_summary]}")
				validate_stack_choices
				build_package_lists
				run_menu_action show_summary "no"
				;;
			"${T[menu_install]}")
				if ensure_ready_for_install; then
					return 0
				fi
				action_status=$?
				if is_ui_cancel_status "$action_status"; then
					continue
				fi
				return "$action_status"
				;;
			"${T[menu_quit]}")
				exit 0
				;;
		esac
		done
}

run_pacstrap() {
	section "PACSTRAP"
	info "Mode debug verbeux actif. Log live: $LOG_FILE"
	configure_live_network noninteractive
	run_logged timedatectl set-ntp true || true
	run_logged pacman -Sy --noconfirm archlinux-keyring
	run_logged pacstrap -K "$TARGET_MOUNT" "${PACSTRAP_PACKAGES[@]}"
}

generate_fstab() {
	section "FSTAB"
	log_command genfstab -U "$TARGET_MOUNT"
	genfstab -U "$TARGET_MOUNT" >> "$TARGET_MOUNT/etc/fstab"
	run_logged cp -L /etc/resolv.conf "$TARGET_MOUNT/etc/resolv.conf"
}

write_target_config() {
	section "CHROOT"
	umask 077
	: > "$ARCH_CONFIG_PATH"
	write_scalar_vars "$ARCH_CONFIG_PATH" \
		HOSTNAME USERNAME TIMEZONE LOCALE KEYMAP XKB_LAYOUT CPU_VENDOR GPU_VENDOR NETWORK_STACK \
		AUDIO_STACK DESKTOP_CHOICE SESSION_STACK DISPLAY_MANAGER ENABLE_MULTILIB \
		ENABLE_AVAHI ENABLE_BLUETOOTH ENABLE_OPENSSH ENABLE_CUPS USER_SHELL_CHOICE \
		INSTALL_OH_MY_ZSH INSTALL_POWERLEVEL10K EXTRA_UTILITY_PACKAGES EXTRA_APP_PACKAGES INSTALL_VIRT_SUITE INSTALL_GNS3 GAMING_TWEAKS \
		USE_OS_PROBER PREPARE_CHAOTIC AUTOLOGIN AUTOSTART_WM INSTALL_PICOM \
		BOOTLOADER EFI_MOUNT_TARGET KERNEL_REPO_URL STORAGE_STACK USE_BTRFS_SUBVOLUMES \
		FORMAT_ROOT_CONTAINER LUKS_NAME LVM_VG_NAME LVM_ROOT_NAME \
		LVM_HOME_NAME LVM_SWAP_NAME LVM_CREATE_HOME LVM_CREATE_SWAP ROOT_LV_SIZE_GIB \
		LVM_SWAP_SIZE_GIB TARGET_DISK PARTITION_MODE EFI_PART ROOT_PART HOME_PART \
		SWAP_PART FORMAT_EFI FORMAT_ROOT FORMAT_HOME ROOT_FS HOME_FS AUTO_CREATE_HOME \
		AUTO_CREATE_SWAP AUTO_SWAP_SIZE_GIB AUTO_ROOT_SIZE_GIB FINAL_ROOT_DEVICE \
		FINAL_HOME_DEVICE FINAL_SWAP_DEVICE KERNEL_MODE KERNEL_PACKAGE \
		KERNEL_HEADERS_PACKAGE MESA_MODE CUSTOM_MESA_PACKAGE CUSTOM_MESA_LIB32_PACKAGE \
		ENABLE_SWAPFILE SWAPFILE_SIZE_GIB ENABLE_ZRAM ROOT_PASSWORD USER_PASSWORD
	declare -p OFFICIAL_PACKAGES CHAOTIC_PACKAGES AUR_PACKAGES SERVICES_TO_ENABLE >> "$ARCH_CONFIG_PATH"

	chmod 600 "$ARCH_CONFIG_PATH"

	cat > "$ARCH_CHROOT_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/root/arch-install.conf"
CHROOT_LOG_FILE="/root/arch-postinstall.log"
CURRENT_STEP="Initialisation du chroot"

touch "$CHROOT_LOG_FILE"
exec > >(tee -a "$CHROOT_LOG_FILE") 2>&1

section() {
	CURRENT_STEP=$1
	printf '\n== %s ==\n' "$1"
}

info() {
	printf '[INFO] %s\n' "$1"
}

warn() {
	printf '[WARN] %s\n' "$1" >&2
}

die() {
	printf '[ERR ] %s\n' "$1" >&2
	exit 1
}

format_command() {
	local item
	for item in "$@"; do
		printf '%q ' "$item"
	done
}

log_command() {
	printf '[CMD ] '
	format_command "$@"
	printf '\n'
}

run_logged() {
	log_command "$@"
	"$@"
}

handle_error() {
	local exit_code=$1
	local line_no=$2
	local failed_command=$3

	printf '\n[ERR ] Echec dans le chroot pendant: %s\n' "${CURRENT_STEP:-etape inconnue}" >&2
	printf '[ERR ] Ligne: %s\n' "$line_no" >&2
	printf '[ERR ] Commande: %s\n' "$failed_command" >&2
	printf '[ERR ] Log chroot: %s\n' "$CHROOT_LOG_FILE" >&2
	exit "$exit_code"
}

handle_interrupt() {
	local signal_name=${1:-INT}

	trap - ERR INT TERM
	printf '\n[WARN] Interruption recue dans le chroot (%s). Installation stoppee.\n' "$signal_name" >&2
	printf '[WARN] Log chroot: %s\n' "$CHROOT_LOG_FILE" >&2
	exit 130
}

trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
trap 'handle_interrupt INT' INT
trap 'handle_interrupt TERM' TERM

contains_word() {
	local needle=$1
	shift
	local word

	for word in "$@"; do
		[[ "$word" == "$needle" ]] && return 0
	done

	return 1
}

selection_string_contains() {
	local selection_string=$1
	local needle=$2
	local -a selection_words=()

	read -r -a selection_words <<< "$selection_string"
	contains_word "$needle" "${selection_words[@]}"
}

join_quoted() {
	local item
	for item in "$@"; do
		printf '%q ' "$item"
	done
}

ensure_user_build_dir() {
	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "/home/$USERNAME/builds"
}

append_user_to_existing_groups() {
	local group group_list
	local -a groups_to_add=()

	for group in "$@"; do
		if getent group "$group" >/dev/null 2>&1; then
			groups_to_add+=("$group")
		else
			warn "Groupe absent, ajout ignore: $group"
		fi
	done

	if ((${#groups_to_add[@]} == 0)); then
		return 0
	fi

	group_list=$(IFS=,; printf '%s' "${groups_to_add[*]}")
	run_logged usermod -aG "$group_list" "$USERNAME"
}

enable_temp_build_sudo() {
	if [[ "$KERNEL_MODE" != "repo" && ${#AUR_PACKAGES[@]} == 0 ]]; then
		return 0
	fi

	cat > /etc/sudoers.d/99-installer-nopasswd <<'SUDOERS'
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
SUDOERS
	chmod 440 /etc/sudoers.d/99-installer-nopasswd
}

resolve_kernel_pkgbase() {
	local pkgbase_file detected="" candidate

	# Priorite 1 : vmlinuz deja present pour KERNEL_PACKAGE connu
	if [[ -n "$KERNEL_PACKAGE" && -e "/boot/vmlinuz-$KERNEL_PACKAGE" ]]; then
		printf '%s\n' "$KERNEL_PACKAGE"
		return 0
	fi

	# Priorite 2 : lire /usr/lib/modules/*/pkgbase — prefer tkg
	for pkgbase_file in /usr/lib/modules/*/pkgbase; do
		[[ -f "$pkgbase_file" ]] || continue
		candidate=$(<"$pkgbase_file")
		[[ -z "$detected" ]] && detected="$candidate"
		if [[ "$candidate" == *tkg* ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	if [[ -n "$detected" ]]; then
		printf '%s\n' "$detected"
		return 0
	fi

	die "Impossible de determiner le pkgbase du noyau installe."
}

build_kernel_cmdline() {
	local container_uuid root_uuid cmdline root_target

	case "$STORAGE_STACK" in
		standard)
			root_uuid=$(blkid -s UUID -o value "$FINAL_ROOT_DEVICE" 2>/dev/null || true)
			if [[ -n "$root_uuid" ]]; then
				cmdline="root=UUID=$root_uuid"
			else
				cmdline="root=$FINAL_ROOT_DEVICE"
			fi
			;;
		luks)
			container_uuid=$(blkid -s UUID -o value "$ROOT_PART")
			root_target="/dev/mapper/$LUKS_NAME"
			cmdline="cryptdevice=UUID=$container_uuid:$LUKS_NAME root=$root_target"
			;;
		luks-lvm)
			container_uuid=$(blkid -s UUID -o value "$ROOT_PART")
			root_target="/dev/$LVM_VG_NAME/$LVM_ROOT_NAME"
			cmdline="cryptdevice=UUID=$container_uuid:$LUKS_NAME root=$root_target"
			;;
		*)
			die "Stack de stockage non pris en charge pour le cmdline: $STORAGE_STACK"
			;;
	esac

	if [[ "$ROOT_FS" == "btrfs" && "$USE_BTRFS_SUBVOLUMES" == "yes" ]]; then
		cmdline="$cmdline rootflags=subvol=@"
	fi

	printf '%s rw\n' "$cmdline"
}

ensure_fstab_swap_entry() {
	local entry=$1

	if grep -Fqx "$entry" /etc/fstab; then
		return 0
	fi

	printf '%s\n' "$entry" >> /etc/fstab
}

configure_persistent_swapfile() {
	local swapfile_dir="/swap"
	local swapfile_path="$swapfile_dir/swapfile"
	local swapfile_size="${SWAPFILE_SIZE_GIB}G"

	if [[ "$ENABLE_SWAPFILE" != "yes" ]]; then
		return 0
	fi

	section "SWAPFILE"
	run_logged install -d -m 0700 "$swapfile_dir"
	rm -f "$swapfile_path"

	if [[ "$ROOT_FS" == "btrfs" ]]; then
		run_logged btrfs filesystem mkswapfile --size "$swapfile_size" "$swapfile_path"
	else
		run_logged fallocate -l "$swapfile_size" "$swapfile_path"
		run_logged chmod 600 "$swapfile_path"
		run_logged mkswap "$swapfile_path"
	fi

	ensure_fstab_swap_entry "$swapfile_path none swap defaults 0 0"
}

configure_zram() {
	if [[ "$ENABLE_ZRAM" != "yes" ]]; then
		return 0
	fi

	section "ZRAM"
	run_logged install -d -m 0755 /etc/systemd
	cat > /etc/systemd/zram-generator.conf <<'ZRAMCONF'
[zram0]
compression-algorithm = zstd
zram-size = ram
swap-priority = 100
fs-type = swap
ZRAMCONF
}

configure_mkinitcpio() {
	local hooks

	if [[ "$GAMING_TWEAKS" == "yes" ]]; then
		# Hooks systemd-based : boot plus rapide, initramfs allege
		case "$STORAGE_STACK" in
			standard)
				hooks="systemd autodetect kms block filesystems"
				;;
			luks)
				hooks="systemd autodetect kms block sd-encrypt filesystems"
				;;
			luks-lvm)
				hooks="systemd autodetect kms block sd-encrypt lvm2 filesystems"
				;;
			*)
				die "Stack de stockage non pris en charge pour mkinitcpio: $STORAGE_STACK"
				;;
		esac
		# Compression lz4 : decompression tres rapide au boot
		if grep -Eq '^COMPRESSION=' /etc/mkinitcpio.conf; then
			sed -i 's/^COMPRESSION=.*/COMPRESSION="lz4"/' /etc/mkinitcpio.conf
		else
			printf '\nCOMPRESSION="lz4"\n' >> /etc/mkinitcpio.conf
		fi
	else
		case "$STORAGE_STACK" in
			standard)
				hooks="base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck"
				;;
			luks)
				hooks="base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck"
				;;
			luks-lvm)
				hooks="base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck"
				;;
			*)
				die "Stack de stockage non pris en charge pour mkinitcpio: $STORAGE_STACK"
				;;
		esac
	fi

	if grep -Eq '^HOOKS=' /etc/mkinitcpio.conf; then
		sed -i "s/^HOOKS=.*/HOOKS=($hooks)/" /etc/mkinitcpio.conf
	else
		printf '\nHOOKS=(%s)\n' "$hooks" >> /etc/mkinitcpio.conf
	fi
}

enable_multilib_repo() {
	if [[ "$ENABLE_MULTILIB" != "yes" ]]; then
		return 0
	fi

	if grep -Eq '^\[multilib\]' /etc/pacman.conf; then
		return 0
	fi

	sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman\.d\/mirrorlist/s/^#//' /etc/pacman.conf
}

enable_chaotic_repo() {
	if [[ "$PREPARE_CHAOTIC" != "yes" ]]; then
		return 0
	fi

	if grep -Eq '^\[chaotic-aur\]' /etc/pacman.conf; then
		return 0
	fi

	run_logged pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
	run_logged pacman-key --lsign-key 3056513887B78AEB
	run_logged pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
	run_logged pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
	printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' >> /etc/pacman.conf
}

configure_timezone_locale() {
	section "TIMEZONE / LOCALE"
	ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
	hwclock --systohc

	if ! grep -Eq "^${LOCALE//./\\.} UTF-8" /etc/locale.gen; then
		printf '%s UTF-8\n' "$LOCALE" >> /etc/locale.gen
	fi
	sed -i "s/^#\(${LOCALE//./\\.} UTF-8\)/\1/" /etc/locale.gen || true
	run_logged locale-gen

	printf 'LANG=%s\n' "$LOCALE" > /etc/locale.conf
	printf 'KEYMAP=%s\n' "$KEYMAP" > /etc/vconsole.conf
}

configure_x11_keyboard() {
	if [[ "$DESKTOP_CHOICE" == "none" ]]; then
		return 0
	fi

	section "CLAVIER X11"
	install -d -m 0755 /etc/X11/xorg.conf.d
	cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<XKBEOF
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "$XKB_LAYOUT"
        Option "XkbModel" "pc105"
EndSection
XKBEOF
	info "Layout X11 configure: $XKB_LAYOUT"
}

configure_hostname_hosts() {
	section "HOSTNAME"
	printf '%s\n' "$HOSTNAME" > /etc/hostname
	cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${HOSTNAME}.localdomain $HOSTNAME
HOSTS
}

configure_network_files() {
	section "RESEAU"

	case "$NETWORK_STACK" in
		systemd-networkd)
			mkdir -p /etc/systemd/network
			cat > /etc/systemd/network/20-wired.network <<'NET'
[Match]
Name=en* eth* wl*

[Network]
DHCP=yes
NET
			ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
			;;
		iwd)
			mkdir -p /etc/iwd
			cat > /etc/iwd/main.conf <<'IWD'
[General]
EnableNetworkConfiguration=true
IWD
			ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
			;;
	esac
}

create_accounts() {
	section "UTILISATEURS"

	chpasswd <<< "root:$ROOT_PASSWORD"

	if ! id "$USERNAME" >/dev/null 2>&1; then
		useradd -m -G wheel,audio,video,storage,optical,input -s /bin/bash "$USERNAME"
	fi

	chpasswd <<< "$USERNAME:$USER_PASSWORD"

	cat > /etc/sudoers.d/10-wheel <<'SUDOERS'
%wheel ALL=(ALL:ALL) ALL
SUDOERS
	chmod 440 /etc/sudoers.d/10-wheel

	# Créer les répertoires XDG standards + écrire user-dirs.dirs explicitement.
	# On utilise xdg-user-dirs-update avec la locale cible pour créer les dossiers
	# dans la bonne langue (Téléchargements au lieu de Downloads pour fr_FR, etc.)
	# Cela évite le popup GNOME de renommage au premier login.
	local user_home="/home/$USERNAME"

	install -d -m 0700 -o "$USERNAME" -g "$USERNAME" "$user_home/.config"

	# Exécuter xdg-user-dirs-update en tant que l'utilisateur avec la bonne locale
	if command -v xdg-user-dirs-update >/dev/null 2>&1; then
		runuser -u "$USERNAME" -- env HOME="$user_home" LANG="$LOCALE" LC_ALL="$LOCALE" \
			xdg-user-dirs-update --force 2>/dev/null || true
	fi

	# Vérifier que user-dirs.dirs a été créé, sinon fallback anglais
	if [[ ! -f "$user_home/.config/user-dirs.dirs" ]]; then
		local dir
		for dir in Desktop Documents Downloads Music Pictures Videos Templates Public; do
			install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/$dir"
		done
		cat > "$user_home/.config/user-dirs.dirs" <<'USERDIRS'
# This file is written by the installer.
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
USERDIRS
		chown "$USERNAME:$USERNAME" "$user_home/.config/user-dirs.dirs"
	else
		# Créer les dossiers référencés dans user-dirs.dirs
		local xdg_dir
		while IFS='=' read -r _ xdg_dir; do
			[[ "$xdg_dir" =~ ^\"(.+)\"$ ]] && xdg_dir="${BASH_REMATCH[1]}"
			xdg_dir="${xdg_dir//\$HOME/$user_home}"
			[[ -n "$xdg_dir" ]] && install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$xdg_dir"
		done < <(grep '^XDG_' "$user_home/.config/user-dirs.dirs")
	fi

	# Écrire le fichier locale pour que xdg-user-dirs-gtk-update ne propose pas de renommer
	printf '%s\n' "$LOCALE" > "$user_home/.config/user-dirs.locale"

	# Correction defensive des permissions : tout le home doit appartenir a l'utilisateur.
	# Certaines fonctions (install -d) peuvent laisser des intermediaires en root:root.
	chown -R "$USERNAME:$USERNAME" "$user_home"
}

write_fastfetch_config() {
	local user_home="/home/$USERNAME"

	if ! selection_string_contains "$EXTRA_UTILITY_PACKAGES" "fastfetch"; then
		return 0
	fi

	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/.config/fastfetch"
	cat > "$user_home/.config/fastfetch/config.jsonc" <<'FASTFETCH'
{
	"$schema": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json",
	"modules": [
		"title",
		"separator",
		"os",
		"host",
		"kernel",
		"uptime",
		"packages",
		"shell",
		"display",
		"de",
		"wm",
		"wmtheme",
		"theme",
		"icons",
		"font",
		"cursor",
		"terminal",
		"terminalfont",
		"cpu",
		"gpu",
		"memory",
		"swap",
		"disk",
		"localip",
		"battery",
		"poweradapter",
		"locale",
		"break",
		"colors"
	],
	"logo": {
		"type": "small",
		"color": {
			"1": "white"
		},
		"padding": {
			"top": 3,
			"right": 6,
			"left": 6
		}
	}
}
FASTFETCH
	chown "$USERNAME:$USERNAME" "$user_home/.config/fastfetch/config.jsonc"
}

write_shell_setup() {
	local user_home="/home/$USERNAME"
	local zsh_theme="robbyrussell"
	local user_shell_path
	local fastfetch_line=""

	if selection_string_contains "$EXTRA_UTILITY_PACKAGES" "fastfetch"; then
		fastfetch_line='[[ $- == *i* ]] && command -v fastfetch &>/dev/null && fastfetch'
	fi

	# .bashrc — toujours écrit, shell bash ou zsh
	cat > "$user_home/.bashrc" <<EOFBASH
# ~/.bashrc

[[ \$- != *i* ]] && return

alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'

export HISTSIZE=5000
export HISTFILESIZE=10000
export HISTCONTROL=ignoredups:erasedups

${fastfetch_line}
EOFBASH
	chown "$USERNAME:$USERNAME" "$user_home/.bashrc"

	if [[ "$USER_SHELL_CHOICE" != "zsh" ]]; then
		return 0
	fi

	user_shell_path=$(command -v zsh || printf '/usr/bin/zsh')
	run_logged usermod -s "$user_shell_path" "$USERNAME"

	if [[ "$INSTALL_OH_MY_ZSH" == "yes" ]]; then
		if [[ ! -d "$user_home/.oh-my-zsh/.git" ]]; then
			run_logged runuser -u "$USERNAME" -- git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$user_home/.oh-my-zsh"
		fi

		if [[ "$INSTALL_POWERLEVEL10K" == "yes" ]]; then
			zsh_theme="powerlevel10k/powerlevel10k"
			install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/.oh-my-zsh/custom/themes"
			if [[ ! -d "$user_home/.oh-my-zsh/custom/themes/powerlevel10k/.git" ]]; then
				run_logged runuser -u "$USERNAME" -- git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$user_home/.oh-my-zsh/custom/themes/powerlevel10k"
			fi
		fi

		cat > "$user_home/.zshrc" <<EOFZSH
export ZSH="$user_home/.oh-my-zsh"
ZSH_THEME="$zsh_theme"
plugins=(git)

source "\$ZSH/oh-my-zsh.sh"
[[ -f "\$HOME/.p10k.zsh" ]] && source "\$HOME/.p10k.zsh"

${fastfetch_line}
EOFZSH
	else
		cat > "$user_home/.zshrc" <<EOFZSH
autoload -Uz compinit
compinit

setopt autocd histignoredups sharehistory
HISTSIZE=5000
SAVEHIST=5000

alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'

${fastfetch_line}
EOFZSH
	fi

	chown "$USERNAME:$USERNAME" "$user_home/.zshrc"
}

write_foot_config() {
	local user_home="/home/$USERNAME"
	local foot_config="$user_home/.config/foot/foot.ini"

	if [[ "$DESKTOP_CHOICE" != "hyprland" && "$DESKTOP_CHOICE" != "sway" ]]; then
		return 0
	fi

	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/.config/foot"

	cat > "$foot_config" <<'EOFFOOT'
# -*- conf -*-

# term=foot (or xterm-256color if built with -Dterminfo=disabled)
# login-shell=no


# font-bold=<bold variant of regular font>
# font-italic=<italic variant of regular font>
# font-bold-italic=<bold+italic variant of regular font>
# line-height=<font metrics>
# letter-spacing=0
# horizontal-letter-offset=0
# vertical-letter-offset=0
# box-drawings-uses-font-glyphs=no
# dpi-aware=yes

# initial-window-size-pixels=700x500  # Or,
# initial-window-size-chars=<COLSxROWS>
# initial-window-mode=windowed
pad=25x25
# resize-delay-ms=100

# notify=notify-send -a foot -i foot ${title} ${body}
# url-launch=xdg-open ${url}

# bold-text-in-bright=no
# bell=none
# word-delimiters=,│`|:"'()[]{}<>
# jump-label-letters=sadfjklewcmpgh
# selection-target=primary
# workers=<number of logical CPUs>
# osc8-underline=url-mode

[scrollback]
# lines=1000
# multiplier=3.0
# indicator-position=relative
# indicator-format=

[cursor]
# style=block
# color=111111 dcdccc
# blink=no

[mouse]
# hide-when-typing=no
# alternate-scroll-mode=yes

[colors-dark]
alpha=0.7
background=000000
# selection-foreground=<inverse foreground/background>
# selection-background=<inverse foreground/background>
# jump-labels=<regular0> <regular3>
# urls=<regular3>

[csd]
# preferred=server
# size=26
# color=<foreground color>
# button-width=26
# button-minimize-color=<regular4>
# button-maximize-color=<regular2>
# button-close-color=<regular1>

[key-bindings]
# scrollback-up-page=Shift+Page_Up
# scrollback-up-half-page=none
# scrollback-up-line=none
# scrollback-down-page=Shift+Page_Down
# scrollback-down-half-page=none
# scrollback-down-line=none
# clipboard-copy=Control+Shift+c
# clipboard-paste=Control+Shift+v
# primary-paste=Shift+Insert
# search-start=Control+Shift+r
# font-increase=Control+plus Control+equal Control+KP_Add
# font-decrease=Control+minus Control+KP_Subtract
# font-reset=Control+0 Control+KP_0
# spawn-terminal=Control+Shift+n
# minimize=none
# maximize=none
# fullscreen=none
# pipe-visible=[sh -c "xurls | fuzzel | xargs -r firefox"] none
# pipe-scrollback=[sh -c "xurls | fuzzel | xargs -r firefox"] none
# pipe-selected=[xargs -r firefox] none
# show-urls-launch=Control+Shift+u
# show-urls-copy=none

[search-bindings]
# cancel=Control+g Escape
# commit=Return
# find-prev=Control+r
# find-next=Control+s
# cursor-left=Left Control+b
# cursor-left-word=Control+Left Mod1+b
# cursor-right=Right Control+f
# cursor-right-word=Control+Right Mod1+f
# cursor-home=Home Control+a
# cursor-end=End Control+e
# delete-prev=BackSpace
# delete-prev-word=Mod1+BackSpace Control+BackSpace
# delete-next=Delete
# delete-next-word=Mod1+d Control+Delete
# extend-to-word-boundary=Control+w
# extend-to-next-whitespace=Control+Shift+w
# clipboard-paste=Control+v Control+y
# primary-paste=Shift+Insert

[url-bindings]
# cancel=Control+g Control+d Escape
# toggle-url-visible=t

[mouse-bindings]
# primary-paste=BTN_MIDDLE
# select-begin=BTN_LEFT
# select-begin-block=Control+BTN_LEFT
# select-extend=BTN_RIGHT
# select-extend-character-wise=Control+BTN_RIGHT
# select-word=BTN_LEFT-2
# select-word-whitespace=Control+BTN_LEFT-2
# select-row=BTN_LEFT-3
EOFFOOT

	chown "$USERNAME:$USERNAME" "$foot_config"
}

write_hyprland_dotfiles() {
	local user_home="/home/$USERNAME"
	local hypr_config="$user_home/.config/hypr/hyprland.conf"

	if [[ "$DESKTOP_CHOICE" != "hyprland" ]]; then
		return 0
	fi

	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" \
		"$user_home/.config/hypr" \
		"$user_home/Images"

	cat > "$hypr_config" <<'EOFHYPR'
# ----------------- Monitor -----------------
monitor = , preferred, auto, 1

# ----------------- Startup -----------------
exec-once = sh -c '[ -f "$HOME/Images/wallpaper6.jpg" ] && exec swaybg -i "$HOME/Images/wallpaper6.jpg" -m fill'
exec-once = hyprctl setcursor elementary 60
EOFHYPR

	if [[ "$ENABLE_BLUETOOTH" == "yes" ]]; then
		printf 'exec-once = blueman-applet\n' >> "$hypr_config"
	fi

	if [[ "$NETWORK_STACK" == "networkmanager" ]]; then
		printf 'exec-once = nm-applet\n' >> "$hypr_config"
	fi

	cat >> "$hypr_config" <<'EOFHYPR'
exec-once = mako

# ----------------- Environment -----------------
#env = XCURSOR_THEME,Breeze
#env = XCURSOR_SIZE,24
#env = QT_QPA_PLATFORMTHEME,qt5ct

# ----------------- Render / Compositor -----------------
render {
	new_render_scheduling = true
	direct_scanout         = 1
}

misc {
	disable_hyprland_logo    = true
	disable_splash_rendering = true
	vfr = true
	vrr = 0
}

cursor {
  no_hardware_cursors = true
}

# ----------------- Input -----------------
input {
	kb_layout     = fr
	kb_variant    =
	kb_model      =
	kb_options    =
	kb_rules      =
	repeat_rate   = 50
	repeat_delay  = 300
	follow_mouse  = 1

	touchpad {
		natural_scroll        = true
		tap-to-click          = true
		disable_while_typing  = true
		scroll_factor         = 1.0
	}

	sensitivity   = 1
	accel_profile = adaptive
}

gestures {
	workspace_swipe_invert   = true
	workspace_swipe_distance = 700
	gesture                  = 3, horizontal, workspace
	gesture                  = 3, swipe, mod: SUPER, resize
	gesture                  = 3, down, close
	gesture                  = 4, pinch, fullscreen
}

# ----------------- General -----------------
general {
	gaps_in             = 5
	gaps_out            = 20
	border_size         = 1
	col.active_border   = rgba(ffffff80)
	col.inactive_border = rgba(586e75ff)
	layout              = dwindle
	allow_tearing       = false
	resize_on_border    = false
}

# ----------------- Decoration -----------------
decoration {
	rounding = 10

	active_opacity     = 1.0
	inactive_opacity   = 1.0
	fullscreen_opacity = 1.0

	dim_inactive = false
	dim_strength = 0.1
	dim_special  = 0.8

	shadow {
		enabled      = false
		range        = 10
		render_power = 5
	}

	blur {
		enabled           = true
		size              = 6
		passes            = 2
		ignore_opacity    = true
		new_optimizations = true
		special           = true
		popups            = true
	}
}

# ----------------- Animations -----------------
animations {
	enabled = true
	bezier = wind, 0.05, 0.85, 0.03, 0.97
	bezier = winIn, 0.07, 0.88, 0.04, 0.99
	bezier = winOut, 0.20, -0.15, 0, 1
	bezier = liner, 1, 1, 1, 1
	bezier = md3_standard, 0.12, 0, 0, 1
	bezier = md3_decel, 0.05, 0.80, 0.10, 0.97
	bezier = md3_accel, 0.20, 0, 0.80, 0.08
	bezier = overshot, 0.05, 0.85, 0.07, 1.04
	bezier = crazyshot, 0.1, 1.22, 0.68, 0.98
	bezier = hyprnostretch, 0.05, 0.82, 0.03, 0.94
	bezier = menu_decel, 0.05, 0.82, 0, 1
	bezier = menu_accel, 0.20, 0, 0.82, 0.10
	bezier = easeInOutCirc, 0.75, 0, 0.15, 1
	bezier = easeOutCirc, 0, 0.48, 0.38, 1
	bezier = easeOutExpo, 0.10, 0.94, 0.23, 0.98
	bezier = softAcDecel, 0.20, 0.20, 0.15, 1
	bezier = md2, 0.30, 0, 0.15, 1
	bezier = OutBack, 0.28, 1.40, 0.58, 1

	animation = border, 1, 1.6, liner
	animation = windowsIn, 1, 3.2, winIn, slide
	animation = windowsOut, 1, 2.8, easeOutCirc
	animation = windowsMove, 1, 3.0, wind, slide
	animation = fade, 1, 1.8, md3_decel
	animation = layersIn, 1, 1.8, menu_decel, slide
	animation = layersOut, 1, 1.5, menu_accel
	animation = fadeLayersIn, 1, 1.6, menu_decel
	animation = fadeLayersOut, 1, 1.8, menu_accel
	animation = workspaces, 1, 4.0, menu_decel, slide
	animation = specialWorkspace, 1, 2.3, md3_decel, slidefadevert 15%
}

# ----------------- Layouts -----------------
dwindle {
	pseudotile           = yes
	preserve_split       = yes
	force_split          = 2
	special_scale_factor = 0.8
}

master {
	new_status = master
	new_on_top = 1
	mfact      = 0.5
}

# ----------------- Window rules -----------------
#windowrulev2 = tile, class:(.*)
#windowrulev2 = tile, title:(.*)
#windowrulev2 = float, class:^(steam_app_.*)$
#windowrulev2 = fullscreen, class:^(steam_app_.*)$
#windowrulev2 = float, class:^(.*\.exe)$
#windowrulev2 = fullscreen, class:^(.*\.exe)$
#windowrulev2 = noshadow, class:^(steam)$

# ----------------- XWayland -----------------
xwayland {
	enabled            = true
	force_zero_scaling = true
}

# ----------------- Keybindings -----------------
$mainMod = SUPER
bind = $mainMod, RETURN, exec, foot
bind = $mainMod, D, exec, rofi -show drun
bind = $mainMod, E, exec, nautilus
bind = $mainMod, V, exec, virt-manager
bind = $mainMod, C, exec, code
bind = $mainMod, Escape, exec, swaylock -c 000000

bind = $mainMod, Q, killactive,
bind = $mainMod, F, fullscreen, 1
bind = $mainMod SHIFT, F, fullscreen, 0
bind = $mainMod, P, pseudo,
bind = $mainMod, T, togglesplit,

bind = $mainMod, S, exec, grim -g "$(slurp)" - | tee ~/Images/screenshot-$(date +%Y-%m-%d-%H%M%S).png | wl-copy

bind = $mainMod, LEFT, movefocus, l
bind = $mainMod, RIGHT, movefocus, r
bind = $mainMod, UP, movefocus, u
bind = $mainMod, DOWN, movefocus, d
bind = $mainMod, H, movefocus, l
bind = $mainMod, L, movefocus, r
bind = $mainMod, K, movefocus, u
bind = $mainMod, J, movefocus, d

bind = $mainMod SHIFT, LEFT, movewindow, l
bind = $mainMod SHIFT, RIGHT, movewindow, r
bind = $mainMod SHIFT, UP, movewindow, u
bind = $mainMod SHIFT, DOWN, movewindow, d
bind = $mainMod SHIFT, H, movewindow, l
bind = $mainMod SHIFT, L, movewindow, r
bind = $mainMod SHIFT, K, movewindow, u
bind = $mainMod SHIFT, J, movewindow, d

bind = $mainMod, R, submap, resize
submap = resize
binde = , RIGHT, resizeactive, 10 0
binde = , LEFT, resizeactive, -10 0
binde = , UP, resizeactive, 0 -10
binde = , DOWN, resizeactive, 0 10
binde = , L, resizeactive, 10 0
binde = , H, resizeactive, -10 0
binde = , K, resizeactive, 0 -10
binde = , J, resizeactive, 0 10
bind = , ESCAPE, submap, reset
bind = , RETURN, submap, reset
submap = reset

bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9

bind = $mainMod CTRL, LEFT, workspace, -1
bind = $mainMod CTRL, RIGHT, workspace, +1
bind = $mainMod CTRL, UP, workspace, -3
bind = $mainMod CTRL, DOWN, workspace, +3

bind = $mainMod CTRL SHIFT, LEFT, movetoworkspace, -1
bind = $mainMod CTRL SHIFT, RIGHT, movetoworkspace, +1

bind = $mainMod, grave, togglespecialworkspace, magic
bind = $mainMod SHIFT, grave, movetoworkspace, special:magic

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Brightness control
bind = , XF86MonBrightnessUp, exec, brightnessctl -e set +5%
bind = , XF86MonBrightnessDown, exec, brightnessctl -e set 5%-

# Volume control
bind = , XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%
bind = , XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%
bind = , XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle
bind = , XF86AudioMicMute, exec, pactl set-source-mute @DEFAULT_SOURCE@ toggle

# Media control
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioPause, exec, playerctl pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous

bind = ALT, TAB, cyclenext,
bind = ALT, TAB, bringactivetotop,
bind = ALT SHIFT, TAB, cyclenext, prev
bind = ALT SHIFT, TAB, bringactivetotop,

bind = $mainMod SHIFT, R, exec, hyprctl reload
bind = $mainMod SHIFT, Q, exit,
EOFHYPR

	sed -i "s/kb_layout     = fr/kb_layout     = $XKB_LAYOUT/" "$hypr_config"
	chown "$USERNAME:$USERNAME" "$hypr_config"
}

write_sway_dotfiles() {
	local user_home="/home/$USERNAME"
	local sway_config="$user_home/.config/sway/config"

	if [[ "$DESKTOP_CHOICE" != "sway" ]]; then
		return 0
	fi

	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" \
		"$user_home/.config/sway" \
		"$user_home/Images"

	cat > "$sway_config" <<'EOFSWAY'
set $mod Mod4

output * mode preferred

floating_modifier $mod normal
default_border pixel 1
gaps inner 5
gaps outer 20
focus_follows_mouse yes

exec_always --no-startup-id sh -c '[ -f "$HOME/Images/wallpaper6.jpg" ] && exec swaybg -i "$HOME/Images/wallpaper6.jpg" -m fill'
exec_always --no-startup-id waybar
exec --no-startup-id mako
exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
EOFSWAY

	if [[ "$ENABLE_BLUETOOTH" == "yes" ]]; then
		printf 'exec --no-startup-id blueman-applet\n' >> "$sway_config"
	fi

	if [[ "$NETWORK_STACK" == "networkmanager" ]]; then
		printf 'exec --no-startup-id nm-applet\n' >> "$sway_config"
	fi

	cat >> "$sway_config" <<'EOFSWAY'

seat * xcursor_theme elementary 60

input type:keyboard {
	xkb_layout fr
	repeat_delay 300
	repeat_rate 50
}

input type:touchpad {
	natural_scroll enabled
	tap enabled
	dwt enabled
	scroll_factor 1.0
}

set $term foot
set $menu wofi --show drun

bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+e exec thunar
bindsym $mod+v exec virt-manager
bindsym $mod+c exec code
bindsym $mod+Escape exec swaylock -c 000000

bindsym $mod+q kill

bindsym $mod+Left focus left
bindsym $mod+Right focus right
bindsym $mod+Up focus up
bindsym $mod+Down focus down
bindsym $mod+h focus left
bindsym $mod+l focus right
bindsym $mod+k focus up
bindsym $mod+j focus down

bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Right move right
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+h move left
bindsym $mod+Shift+l move right
bindsym $mod+Shift+k move up
bindsym $mod+Shift+j move down

mode "resize" {
	bindsym Right resize grow width 10 px
	bindsym Left resize shrink width 10 px
	bindsym Up resize shrink height 10 px
	bindsym Down resize grow height 10 px
	bindsym l resize grow width 10 px
	bindsym h resize shrink width 10 px
	bindsym k resize shrink height 10 px
	bindsym j resize grow height 10 px
	bindsym Escape mode "default"
	bindsym Return mode "default"
}
bindsym $mod+r mode "resize"

bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9

bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9

bindsym $mod+Ctrl+Left workspace prev_on_output
bindsym $mod+Ctrl+Right workspace next_on_output
bindsym $mod+Ctrl+Up workspace prev_on_output
bindsym $mod+Ctrl+Down workspace next_on_output

bindsym $mod+Ctrl+Shift+Left move container to workspace prev_on_output
bindsym $mod+Ctrl+Shift+Right move container to workspace next_on_output

bindsym $mod+grave scratchpad show
bindsym $mod+Shift+grave move scratchpad

bindsym --whole-window $mod+button4 workspace prev_on_output
bindsym --whole-window $mod+button5 workspace next_on_output

bindsym XF86MonBrightnessUp exec brightnessctl -e set +5%
bindsym XF86MonBrightnessDown exec brightnessctl -e set 5%-
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86AudioMicMute exec pactl set-source-mute @DEFAULT_SOURCE@ toggle
bindsym XF86AudioPlay exec playerctl play-pause
bindsym XF86AudioPause exec playerctl pause
bindsym XF86AudioNext exec playerctl next
bindsym XF86AudioPrev exec playerctl previous

bindsym Mod1+Tab focus next
bindsym Mod1+Shift+Tab focus prev

bindsym $mod+Shift+r reload
bindsym $mod+Shift+q exec swaymsg exit
EOFSWAY

	sed -i "s/xkb_layout fr/xkb_layout $XKB_LAYOUT/" "$sway_config"
	chown "$USERNAME:$USERNAME" "$sway_config"

	# Thunar comme gestionnaire de fichiers par defaut
	run_logged runuser -u "$USERNAME" -- xdg-mime default thunar.desktop inode/directory
	run_logged runuser -u "$USERNAME" -- xdg-mime default thunar.desktop application/x-gnome-saved-search
}

write_waybar_config() {
	local user_home="/home/$USERNAME"
	local waybar_dir="$user_home/.config/waybar"
	local wm_module

	if [[ "$DESKTOP_CHOICE" == "hyprland" ]]; then
		wm_module="hyprland/workspaces"
	elif [[ "$DESKTOP_CHOICE" == "sway" ]]; then
		wm_module="sway/workspaces"
	else
		return 0
	fi

	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$waybar_dir"

	cat > "$waybar_dir/config" <<EOFWAYBAR
{
    "layer": "top",
    "position": "top",
    "height": 28,
    "spacing": 6,
    "modules-left": ["${wm_module}", "custom/sep"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "battery", "tray"],

    "${wm_module}": {
        "format": "{icon}",
        "format-icons": {
            "active": "",
            "default": ""
        },
        "persistent-workspaces": {}
    },

    "custom/sep": {
        "format": "|",
        "tooltip": false
    },

    "clock": {
        "format": "{:%d/%m  %H:%M}",
        "tooltip-format": "<tt>{calendar}</tt>"
    },

    "cpu": {
        "format": "CPU {usage}%",
        "interval": 2
    },

    "memory": {
        "format": "RAM {used:.1f}G",
        "interval": 5
    },

    "battery": {
        "format": "BAT {capacity}%",
        "format-charging": "+ {capacity}%",
        "format-full": "= 100%",
        "states": {
            "warning": 20,
            "critical": 10
        }
    },

    "network": {
        "format-wifi": "W: {signalStrength}%",
        "format-ethernet": "E: {ipaddr}",
        "format-disconnected": "offline"
    },

    "pulseaudio": {
        "format": "VOL {volume}%",
        "format-muted": "MUTE",
        "on-click": "pactl set-sink-mute @DEFAULT_SINK@ toggle"
    },

    "tray": {
        "spacing": 8
    }
}
EOFWAYBAR

	cat > "$waybar_dir/style.css" <<'EOFCSS'
* {
    font-family: "DejaVu Sans Mono", monospace;
    font-size: 12px;
    border: none;
    border-radius: 0;
    min-height: 0;
}

window#waybar {
    background-color: rgba(10, 10, 10, 0.85);
    color: #cdd6f4;
}

#workspaces button {
    padding: 0 6px;
    color: #6c7086;
}

#workspaces button.active,
#workspaces button.focused {
    color: #cdd6f4;
}

#clock,
#cpu,
#memory,
#battery,
#network,
#pulseaudio,
#tray,
#custom-sep {
    padding: 0 8px;
    color: #cdd6f4;
}

#battery.warning { color: #f9e2af; }
#battery.critical { color: #f38ba8; }
EOFCSS

	chown -R "$USERNAME:$USERNAME" "$waybar_dir"
}

write_i3status_config() {
	local user_home="/home/$USERNAME"
	local i3status_config="$user_home/.config/i3status/config"

	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/.config/i3status"

	cat > "$i3status_config" <<'EOFI3S'
general {
	colors = true
	interval = 2
	color_good     = "#98c379"
	color_bad      = "#e06c75"
	color_degraded = "#e5c07b"
}

order += "wireless _first_"
order += "ethernet _first_"
order += "battery all"
order += "cpu_usage"
order += "memory"
order += "tztime local"

wireless _first_ {
	format_up   = "W: %quality %essid %ip"
	format_down = "W: -"
}

ethernet _first_ {
	format_up   = "E: %ip"
	format_down = "E: -"
}

battery all {
	format                = "BAT: %status %percentage %remaining"
	format_down           = ""
	last_full_capacity    = true
	integer_battery_capacity = true
	low_threshold         = 15
	threshold_type        = percentage
	status_chr  = "+"
	status_bat  = ""
	status_unk  = "?"
	status_full = "="
}

cpu_usage {
	format        = "CPU: %usage"
	max_threshold = 90
}

memory {
	format             = "RAM: %used"
	threshold_degraded = "1G"
	threshold_critical = "200M"
}

tztime local {
	format = "%d/%m %H:%M"
}
EOFI3S

	chown "$USERNAME:$USERNAME" "$i3status_config"
}

write_i3_dotfiles() {
	local user_home="/home/$USERNAME"
	local i3_config="$user_home/.config/i3/config"

	if [[ "$DESKTOP_CHOICE" != "i3" ]]; then
		return 0
	fi

	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" \
		"$user_home/.config/i3" \
		"$user_home/Images"

	cat > "$i3_config" <<'EOFI3'
set $mod Mod4
font pango:DejaVu Sans Mono 10

floating_modifier $mod
default_border pixel 1
gaps inner 5
gaps outer 20
focus_follows_mouse yes

exec_always --no-startup-id sh -c '[ -f "$HOME/Images/wallpaper6.jpg" ] && exec feh --bg-fill "$HOME/Images/wallpaper6.jpg"'
exec --no-startup-id dunst
exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
EOFI3

	[[ "$INSTALL_PICOM" == "yes" ]] && printf 'exec_always --no-startup-id picom\n' >> "$i3_config"

	if [[ "$ENABLE_BLUETOOTH" == "yes" ]]; then
		printf 'exec --no-startup-id blueman-applet\n' >> "$i3_config"
	fi

	if [[ "$NETWORK_STACK" == "networkmanager" ]]; then
		printf 'exec --no-startup-id nm-applet\n' >> "$i3_config"
	fi

	cat >> "$i3_config" <<'EOFI3'

set $term kitty
set $menu rofi -show drun

bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+e exec thunar
bindsym $mod+v exec virt-manager
bindsym $mod+c exec code
bindsym $mod+Escape exec i3lock -c 000000

bindsym $mod+q kill

bindsym $mod+Left focus left
bindsym $mod+Right focus right
bindsym $mod+Up focus up
bindsym $mod+Down focus down
bindsym $mod+h focus left
bindsym $mod+l focus right
bindsym $mod+k focus up
bindsym $mod+j focus down

bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Right move right
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+h move left
bindsym $mod+Shift+l move right
bindsym $mod+Shift+k move up
bindsym $mod+Shift+j move down

mode "resize" {
	bindsym Right resize grow width 10 px or 10 ppt
	bindsym Left resize shrink width 10 px or 10 ppt
	bindsym Up resize shrink height 10 px or 10 ppt
	bindsym Down resize grow height 10 px or 10 ppt
	bindsym l resize grow width 10 px or 10 ppt
	bindsym h resize shrink width 10 px or 10 ppt
	bindsym k resize shrink height 10 px or 10 ppt
	bindsym j resize grow height 10 px or 10 ppt
	bindsym Escape mode "default"
	bindsym Return mode "default"
}
bindsym $mod+r mode "resize"

bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9

bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9

bindsym $mod+Ctrl+Left workspace prev
bindsym $mod+Ctrl+Right workspace next
bindsym $mod+Ctrl+Up workspace prev
bindsym $mod+Ctrl+Down workspace next

bindsym $mod+Ctrl+Shift+Left move container to workspace prev
bindsym $mod+Ctrl+Shift+Right move container to workspace next

bindsym $mod+grave scratchpad show
bindsym $mod+Shift+grave move scratchpad

bindsym --whole-window $mod+button4 workspace prev
bindsym --whole-window $mod+button5 workspace next

bindsym XF86MonBrightnessUp exec brightnessctl -e set +5%
bindsym XF86MonBrightnessDown exec brightnessctl -e set 5%-
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86AudioMicMute exec pactl set-source-mute @DEFAULT_SOURCE@ toggle
bindsym XF86AudioPlay exec playerctl play-pause
bindsym XF86AudioPause exec playerctl pause
bindsym XF86AudioNext exec playerctl next
bindsym XF86AudioPrev exec playerctl previous

bindsym Mod1+Tab focus next
bindsym Mod1+Shift+Tab focus prev

bindsym $mod+Shift+r reload
bindsym $mod+Shift+q exec i3-msg exit

bar {
	status_command i3status
}
EOFI3

	chown "$USERNAME:$USERNAME" "$i3_config"

	# Thunar comme gestionnaire de fichiers par defaut
	run_logged runuser -u "$USERNAME" -- xdg-mime default thunar.desktop inode/directory
	run_logged runuser -u "$USERNAME" -- xdg-mime default thunar.desktop application/x-gnome-saved-search
	write_i3status_config
}

write_gtk_dark_theme() {
	# GNOME et KDE ont leur propre gestionnaire de themes : ne pas leur imposer nos fichiers.
	if [[ "$DESKTOP_CHOICE" == "gnome" || "$DESKTOP_CHOICE" == "kde" ]]; then
		return 0
	fi

	local user_home="/home/$USERNAME"

	# --- GTK3 ---
	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/.config/gtk-3.0"
	cat > "$user_home/.config/gtk-3.0/settings.ini" <<'EOFGTK3'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=true
gtk-button-images=false
gtk-menu-images=false
gtk-enable-animations=true
EOFGTK3
	chown "$USERNAME:$USERNAME" "$user_home/.config/gtk-3.0/settings.ini"

	# --- GTK4 / libadwaita ---
	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/.config/gtk-4.0"
	cat > "$user_home/.config/gtk-4.0/settings.ini" <<'EOFGTK4'
[Settings]
gtk-application-prefer-dark-theme=true
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
EOFGTK4
	chown "$USERNAME:$USERNAME" "$user_home/.config/gtk-4.0/settings.ini"

	# --- qt5ct : theming Qt5 sombre ---
	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/.config/qt5ct"
	cat > "$user_home/.config/qt5ct/qt5ct.conf" <<'EOFQT5CT'
[Appearance]
color_scheme_path=/usr/share/qt5ct/colors/darker.conf
custom_palette=true
icon_theme=Adwaita
standard_dialogs=default
style=Fusion

[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x12\0M\0o\0n\0o\0s\0p\0a\0c\0e@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x6\0S\0a\0n\0s@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
EOFQT5CT
	chown "$USERNAME:$USERNAME" "$user_home/.config/qt5ct/qt5ct.conf"

	# --- qt6ct : theming Qt6 sombre ---
	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/.config/qt6ct"
	cat > "$user_home/.config/qt6ct/qt6ct.conf" <<'EOFQT6CT'
[Appearance]
color_scheme_path=/usr/share/qt6ct/colors/darker.conf
custom_palette=true
icon_theme=Adwaita
standard_dialogs=default
style=Fusion

[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x12\0M\0o\0n\0o\0s\0p\0a\0c\0e@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x6\0S\0a\0n\0s@$\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
EOFQT6CT
	chown "$USERNAME:$USERNAME" "$user_home/.config/qt6ct/qt6ct.conf"

	# --- Variables d'environnement GTK + QT ---
	# Wayland (Hyprland/Sway/labwc) : systemd user environment.d
	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/.config/environment.d"
	cat > "$user_home/.config/environment.d/10-gtk-dark.conf" <<'EOFENV'
GTK_THEME=Adwaita:dark
QT_QPA_PLATFORMTHEME=qt5ct
QT_STYLE_OVERRIDE=Fusion
EOFENV
	chown "$USERNAME:$USERNAME" "$user_home/.config/environment.d/10-gtk-dark.conf"

	# X11 (i3/XFCE/LXQt/IceWM) : .xprofile lu par xinit/display manager
	cat > "$user_home/.xprofile" <<EOFXPROFILE
export GTK_THEME=Adwaita:dark
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=Fusion
setxkbmap $XKB_LAYOUT
EOFXPROFILE
	chown "$USERNAME:$USERNAME" "$user_home/.xprofile"

	# --- dconf systemwide : color-scheme prefer-dark pour les apps libadwaita ---
	# Fonctionne sans session D-Bus active (via le backend keyfile de dconf).
	install -d -m 0755 /etc/dconf/db/local.d
	cat > /etc/dconf/db/local.d/00-dark-theme <<'EOFDCONF'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
gtk-theme='Adwaita-dark'
icon-theme='Adwaita'
cursor-theme='Adwaita'
cursor-size=24
font-name='Sans 10'
EOFDCONF

	if command -v dconf >/dev/null 2>&1; then
		run_logged dconf update
	fi
}

write_gaming_tweaks() {
	[[ "$GAMING_TWEAKS" == "yes" ]] || return 0

	section "GAMING TWEAKS"

	# Service systemd : latences PCI pour reduire la latence GPU/CPU en jeu
	cat > /etc/systemd/system/pci-latency-gaming.service <<'PCISVC'
[Unit]
Description=Set PCI Express latencies for gaming
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'setpci -v -s "*:*" latency_timer=20; setpci -v -s "0:0" latency_timer=0; setpci -v -d "*:*:04xx" latency_timer=80'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
PCISVC
	run_logged systemctl enable pci-latency-gaming.service

	# drirc : desactive le vsync OpenGL (vblank_mode=0) pour eviter le plafonnement au refresh rate
	cat > /etc/drirc <<'DRIRC'
<driconf>
   <device>
       <application name="Default">
           <option name="vblank_mode" value="0" />
       </application>
   </device>
</driconf>
DRIRC

	# Variables d'environnement gaming
	cat >> /etc/environment <<'ENVGAMING'

# --- Gaming tweaks ---
MESA_NO_ERROR=1
MESA_SHADER_CACHE=1
MESA_GLTHREAD=true
vblank_mode=0
DRI_NO_MSAA=1
RADV_PERFTEST=aco,bolist,fastclears,nggc,dpbb,dpp,tc_compat_cm,shader_object,zerovram
RADV_TEX_ANISO=0
RADV_TESS_FACTOR_LIMIT=1
WINEDEBUG=-all,fixme-all
MESA_NO_DITHER=1
MESA_DEBUG=silent
DXVK_LOG_LEVEL=none
VKD3D_DEBUG=none
VKD3D_SHADER_DEBUG=none
MALLOCCHECK=0
MALLOC_TRIM_THRESHOLD_=131072
MALLOC_MMAP_THRESHOLD_=131072
MALLOC_MMAP_MAX_=65536
ENVGAMING

	# Limites systeme : fichiers ouverts, threads, priorite temps-reel, memlock
	cat >> /etc/security/limits.conf <<LIMITSGAMING

# --- Gaming tweaks ---
* soft nofile 524288
* hard nofile 1048576
* soft nproc 32768
* hard nproc 65536

$USERNAME soft rtprio 10
$USERNAME hard rtprio 20
$USERNAME - nice -10
$USERNAME soft memlock unlimited
$USERNAME hard memlock unlimited
$USERNAME soft stack 8192
$USERNAME hard stack 16384

root soft rtprio 99
root hard rtprio 99
root - nice -20
root soft memlock unlimited
root hard memlock unlimited
LIMITSGAMING

	# Sysctl : parametres noyau gaming et reseau
	cat > /etc/sysctl.d/99-sysctl.conf <<'SYSCTLGAMING'
vm.swappiness = 25
vm.vfs_cache_pressure = 50
vm.dirty_background_bytes = 67108864
vm.dirty_bytes = 268435456
vm.dirty_writeback_centisecs = 1500
vm.page-cluster = 0
vm.compaction_proactiveness = 0
kernel.nmi_watchdog = 0
kernel.unprivileged_userns_clone = 1
kernel.kptr_restrict = 1
kernel.randomize_va_space = 2
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq_codel
net.core.netdev_max_backlog = 4096
fs.file-max = 2097152
vm.max_map_count = 16777216
net.ipv4.ip_forward = 1
SYSCTLGAMING
	run_logged sysctl --system

	# THP : persistent via tmpfiles.d (defrag=defer+madvise, enabled=madvise)
	cat > /etc/tmpfiles.d/thp.conf <<'THPFILES'
# Persistent THP defrag setting
w /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise
w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise
THPFILES
	run_logged systemd-tmpfiles --create /etc/tmpfiles.d/thp.conf
}

write_chromium_wayland_flags() {
	if [[ "$SESSION_STACK" != "wayland" && "$SESSION_STACK" != "both" ]]; then
		return 0
	fi
	if ! selection_string_contains "$EXTRA_APP_PACKAGES" "chromium"; then
		return 0
	fi

	local user_home="/home/$USERNAME"
	install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/.config"
	cat > "$user_home/.config/chromium-flags.conf" <<'EOFCHROMIUM'
--ozone-platform-hint=wayland
--enable-features=TouchpadOverscrollHistoryNavigation
EOFCHROMIUM
	chown "$USERNAME:$USERNAME" "$user_home/.config/chromium-flags.conf"
	info "Chromium Wayland flags installes."
}

write_user_customizations() {
	section "PERSONNALISATION"
	write_fastfetch_config
	write_shell_setup
	write_foot_config
	write_gtk_dark_theme
	write_waybar_config
	write_hyprland_dotfiles
	write_sway_dotfiles
	write_i3_dotfiles
	write_chromium_wayland_flags
	write_gaming_tweaks
}

sync_and_install_packages() {
	section "PAQUETS"
	run_logged pacman -Syu --noconfirm

	if ((${#CHAOTIC_PACKAGES[@]})); then
		run_logged pacman -S --noconfirm --needed "${CHAOTIC_PACKAGES[@]}"
	fi

	if ((${#OFFICIAL_PACKAGES[@]})); then
		run_logged pacman -S --noconfirm --needed "${OFFICIAL_PACKAGES[@]}"
	fi
}

install_yay_if_needed() {
	local aur_cmd

	if ((${#AUR_PACKAGES[@]} == 0)); then
		return 0
	fi

	if ! command -v yay >/dev/null 2>&1; then
		ensure_user_build_dir
		run_logged runuser -u "$USERNAME" -- bash -lc 'set -euo pipefail; sudo pacman -S --noconfirm --needed git base-devel; cd ~/builds; rm -rf yay-bin; git clone https://aur.archlinux.org/yay-bin.git; cd yay-bin; makepkg -si --noconfirm --needed'
	fi

	aur_cmd=$(join_quoted "${AUR_PACKAGES[@]}")
	run_logged runuser -u "$USERNAME" -- bash -lc "set -euo pipefail; yay -S --noconfirm --needed --answerclean None --answerdiff None $aur_cmd"
}

install_gns3_server_if_needed() {
	local user_local_dir user_local_bin user_gns3server

	if [[ "$INSTALL_GNS3" != "yes" ]]; then
		return 0
	fi

	section "GNS3 PIP"
	user_local_dir="/home/$USERNAME/.local"
	user_local_bin="/home/$USERNAME/.local/bin"
	user_gns3server="$user_local_bin/gns3server"

	install -d -m 0755 "$user_local_dir" "$user_local_bin" "$user_local_dir/lib"
	run_logged chown -R "$USERNAME:$USERNAME" "$user_local_dir"
	run_logged runuser -u "$USERNAME" -- bash -lc 'set -euo pipefail; python -m pip install --user --upgrade --break-system-packages gns3-server'
	[[ -x "$user_gns3server" ]] || die "Le binaire gns3server n'a pas ete installe dans $user_gns3server"
	run_logged ln -sfn "$user_gns3server" /usr/bin/gns3server
}

install_repo_kernel_if_needed() {
	local repo_url_quoted repo_name detected_pkgbase

	if [[ "$KERNEL_MODE" != "repo" ]]; then
		return 0
	fi

	section "LINUX-TKG BUILD"
	ensure_user_build_dir

	repo_name="linux-tkg"
	repo_url_quoted=$(printf '%q' "$KERNEL_REPO_URL")

	# Clone ou mise a jour — build directement dans le clone (linux-tkg exige un vrai depot git)
	run_logged runuser -u "$USERNAME" -- bash -lc "set -euo pipefail; cd ~/builds; if [[ -d ${repo_name}-src/.git ]]; then cd ${repo_name}-src; git pull --ff-only; else git clone $repo_url_quoted ${repo_name}-src; fi"
	run_logged runuser -u "$USERNAME" -- bash -lc "set -euo pipefail; cd ~/builds/${repo_name}-src; makepkg -si --noconfirm --needed"

	detected_pkgbase=$(resolve_kernel_pkgbase)
	KERNEL_PACKAGE="$detected_pkgbase"
	KERNEL_HEADERS_PACKAGE="${detected_pkgbase}-headers"
}

install_proton_ge_if_needed() {
	if ! selection_string_contains "$EXTRA_APP_PACKAGES" "steam"; then
		return 0
	fi

	section "PROTON-GE"
	local script_file="/tmp/install-proton-ge.sh"
	cat > "$script_file" <<'EOFPROTON'
set -euo pipefail
rm -rf /tmp/proton-ge-custom
mkdir -p /tmp/proton-ge-custom
cd /tmp/proton-ge-custom
tarball_url=$(curl -fsSL https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep browser_download_url | cut -d'"' -f4 | grep ".tar.gz" | head -n1)
[[ -n "$tarball_url" ]]
tarball_name=$(basename "$tarball_url")
curl -fsSL "$tarball_url" -o "$tarball_name"
checksum_url=$(curl -fsSL https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep browser_download_url | cut -d'"' -f4 | grep ".sha512sum" | head -n1)
[[ -n "$checksum_url" ]]
checksum_name=$(basename "$checksum_url")
curl -fsSL "$checksum_url" -o "$checksum_name"
sha512sum -c "$checksum_name"
mkdir -p ~/.steam/steam/compatibilitytools.d
tar -xf "$tarball_name" -C ~/.steam/steam/compatibilitytools.d/
rm -rf /tmp/proton-ge-custom
EOFPROTON
	chmod +x "$script_file"
	run_logged runuser -u "$USERNAME" -- bash -l "$script_file"
	rm -f "$script_file"
}

enable_services() {
	local service

	section "SERVICES"
	for service in "${SERVICES_TO_ENABLE[@]}"; do
		run_logged systemctl enable "$service"
	done

	if pacman -Q dbus-broker >/dev/null 2>&1; then
		run_logged systemctl enable dbus-broker.service || true
	fi
}

configure_gns3_libvirt_network() {
	if [[ "$INSTALL_GNS3" != "yes" ]]; then
		return 0
	fi

	install -d -m 0755 /usr/local/lib/arch-installer
	cat > /usr/local/lib/arch-installer/gns3-libvirt-network.sh <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v virsh >/dev/null 2>&1; then
	exit 0
fi

if ! virsh net-info default >/dev/null 2>&1; then
	if [[ -f /usr/share/libvirt/networks/default.xml ]]; then
		virsh net-define /usr/share/libvirt/networks/default.xml || true
	elif [[ -f /etc/libvirt/qemu/networks/default.xml ]]; then
		virsh net-define /etc/libvirt/qemu/networks/default.xml || true
	fi
fi

virsh net-autostart default || true
virsh net-start default || true
SCRIPT
	chmod 755 /usr/local/lib/arch-installer/gns3-libvirt-network.sh

	cat > /etc/systemd/system/gns3-libvirt-network.service <<'UNIT'
[Unit]
Description=Prepare libvirt default network for GNS3
After=libvirtd.service network-online.target
Wants=network-online.target
Requires=libvirtd.service

[Service]
Type=oneshot
ExecStart=/usr/local/lib/arch-installer/gns3-libvirt-network.sh

[Install]
WantedBy=multi-user.target
UNIT

	run_logged systemctl enable gns3-libvirt-network.service
}

configure_grub() {
	local kernel_cmdline

	section "GRUB"
	kernel_cmdline=$(build_kernel_cmdline)

	if grep -Eq '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
		sed -i "s#^GRUB_CMDLINE_LINUX=.*#GRUB_CMDLINE_LINUX=\"$kernel_cmdline\"#" /etc/default/grub
	else
		printf '\nGRUB_CMDLINE_LINUX="%s"\n' "$kernel_cmdline" >> /etc/default/grub
	fi

	if [[ "$USE_OS_PROBER" == "yes" ]]; then
		if grep -Eq '^#?GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
			sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
		else
			printf '\nGRUB_DISABLE_OS_PROBER=false\n' >> /etc/default/grub
		fi
	fi

	run_logged grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux --recheck
	run_logged grub-mkconfig -o /boot/grub/grub.cfg
}

configure_systemd_boot() {
	local kernel_base microcode_image kernel_cmdline

	section "SYSTEMD-BOOT"
	kernel_cmdline=$(build_kernel_cmdline)

	mkdir -p /boot/loader/entries

	if ! run_logged bootctl --esp-path=/boot install; then
		warn "bootctl n'a pas pu ecrire les variables EFI depuis le chroot. Nouvelle tentative sans variables."
		run_logged bootctl --esp-path=/boot --no-variables install
	fi

	cat > /boot/loader/loader.conf <<'LOADER'
default arch.conf
timeout 4
console-mode max
editor no
LOADER

	kernel_base=$(resolve_kernel_pkgbase)
	microcode_image=""
	case "$CPU_VENDOR" in
		amd)
			microcode_image="/amd-ucode.img"
			;;
		intel)
			microcode_image="/intel-ucode.img"
			;;
	esac

	{
		printf 'title   Arch Linux\n'
		printf 'linux   /vmlinuz-%s\n' "$kernel_base"
		if [[ -n "$microcode_image" ]]; then
			printf 'initrd  %s\n' "$microcode_image"
		fi
		printf 'initrd  /initramfs-%s.img\n' "$kernel_base"
		printf 'options %s\n' "$kernel_cmdline"
	} > /boot/loader/entries/arch.conf

	{
		printf 'title   Arch Linux (fallback initramfs)\n'
		printf 'linux   /vmlinuz-%s\n' "$kernel_base"
		if [[ -n "$microcode_image" ]]; then
			printf 'initrd  %s\n' "$microcode_image"
		fi
		printf 'initrd  /initramfs-%s-fallback.img\n' "$kernel_base"
		printf 'options %s\n' "$kernel_cmdline"
	} > /boot/loader/entries/arch-fallback.conf
}

configure_bootloader() {
	case "$BOOTLOADER" in
		grub)
			configure_grub
			;;
		systemd-boot)
			configure_systemd_boot
			;;
		*)
			die "Bootloader non pris en charge dans le chroot: $BOOTLOADER"
			;;
	esac
}

write_session_helpers() {
	local xinit_exec=""
	local wayland_exec=""
	local notes_file="/root/POST_INSTALL_NOTES.txt"

	section "SESSION TTY"

	if [[ "$DISPLAY_MANAGER" == "none" ]]; then
		case "$DESKTOP_CHOICE" in
			gnome)
				xinit_exec="gnome-session"
				wayland_exec="dbus-run-session gnome-session"
				;;
			kde)
				xinit_exec="startplasma-x11"
				wayland_exec="dbus-run-session startplasma-wayland"
				;;
			xfce)
				xinit_exec="startxfce4"
				;;
			lxqt)
				xinit_exec="startlxqt"
				;;
			i3)
				xinit_exec="i3"
				;;
			icewm)
				xinit_exec="icewm-session"
				;;
			hyprland)
				wayland_exec="Hyprland"
				;;
			sway)
				wayland_exec="sway"
				;;
			labwc)
				wayland_exec="dbus-run-session labwc"
				;;
		esac

		if [[ -n "$xinit_exec" ]]; then
			cat > "/home/$USERNAME/.xinitrc" <<XINIT
setxkbmap $XKB_LAYOUT
exec $xinit_exec
XINIT
			chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xinitrc"
		fi

		# Autologin via getty systemd override
		if [[ "$AUTOLOGIN" == "yes" ]]; then
			install -d -m 0755 /etc/systemd/system/getty@tty1.service.d
			cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USERNAME --noclear %I \$TERM
AUTOLOGIN
		fi

		# Autostart WM via .bash_profile / .zprofile
		if [[ "$AUTOSTART_WM" == "yes" ]]; then
			local start_cmd=""
			if [[ -n "$wayland_exec" ]]; then
				start_cmd="$wayland_exec"
			elif [[ -n "$xinit_exec" ]]; then
				start_cmd="exec startx"
			fi
			if [[ -n "$start_cmd" ]]; then
				# Lance le WM uniquement sur TTY1 et uniquement si pas de session graphique active
				cat > "/home/$USERNAME/.bash_profile" <<BASHPROFILE
# Auto-start the graphical session on TTY1
[[ -z "\$DISPLAY" && -z "\$WAYLAND_DISPLAY" && "\$(tty)" == '/dev/tty1' ]] && exec $start_cmd
BASHPROFILE
				chown "$USERNAME:$USERNAME" "/home/$USERNAME/.bash_profile"

				if [[ "$USER_SHELL_CHOICE" == "zsh" ]]; then
					cat > "/home/$USERNAME/.zprofile" <<ZPROFILE
# Auto-start the graphical session on TTY1
[[ -z "\$DISPLAY" && -z "\$WAYLAND_DISPLAY" && "\$(tty)" == '/dev/tty1' ]] && exec $start_cmd
ZPROFILE
					chown "$USERNAME:$USERNAME" "/home/$USERNAME/.zprofile"
				fi
			fi
		fi
	fi

	{
		printf 'Installation terminee.\n\n'
		if [[ "$DISPLAY_MANAGER" == "none" ]]; then
			printf 'Aucun display manager active.\n'
			printf 'Connectez-vous en TTY pour demarrer votre session.\n'
			if [[ -n "$xinit_exec" ]]; then
				printf '  - Session X11: startx\n'
			fi
			if [[ -n "$wayland_exec" ]]; then
				printf '  - Session Wayland: %s\n' "$wayland_exec"
			fi
		else
			printf 'Display manager active: %s\n' "$DISPLAY_MANAGER"
		fi
		if [[ "$DESKTOP_CHOICE" == "hyprland" ]]; then
			printf '\nDotfile Hyprland: ~/.config/hypr/hyprland.conf\n'
			printf 'Config Foot: ~/.config/foot/foot.ini\n'
			printf 'Fond d''ecran attendu: ~/Images/wallpaper6.jpg\n'
		elif [[ "$DESKTOP_CHOICE" == "sway" ]]; then
			printf '\nConfig Sway: ~/.config/sway/config\n'
			printf 'Config Foot: ~/.config/foot/foot.ini\n'
			printf 'Fond d''ecran attendu: ~/Images/wallpaper6.jpg\n'
		elif [[ "$DESKTOP_CHOICE" == "i3" ]]; then
			printf '\nConfig i3: ~/.config/i3/config\n'
			printf 'Fond d''ecran attendu: ~/Images/wallpaper6.jpg\n'
		fi
		if [[ "$INSTALL_GNS3" == "yes" ]]; then
			printf '\nGNS3 installe: services docker/libvirtd actives au boot.\n'
			printf 'gns3server est installe via python -m pip (gns3-server) dans ~/.local/bin puis lie vers /usr/bin/gns3server.\n'
			printf 'Le reseau libvirt par defaut sera prepare automatiquement au premier demarrage.\n'
			printf 'Une reconnexion ou un reboot est recommande pour appliquer les groupes docker/wireshark/kvm/libvirt.\n'
		fi
	} > "$notes_file"
}

cleanup_sensitive_files() {
	rm -f /root/arch-install.conf /root/arch-postinstall.sh
	rm -f /etc/sudoers.d/99-installer-nopasswd
}

cleanup_package_cache() {
	section "CACHE CLEANUP"
	rm -rf /var/cache/pacman/pkg/*
	rm -rf /var/lib/pacman/sync/*.db.sig
	info "Package cache cleared."
}

main() {
	if [[ ! -f "$CONFIG_FILE" ]]; then
		die "Fichier de configuration introuvable dans le chroot."
	fi

	# shellcheck disable=SC1090
	source "$CONFIG_FILE"
	trap 'rm -f /etc/sudoers.d/99-installer-nopasswd' EXIT

	enable_multilib_repo
	enable_chaotic_repo
	configure_timezone_locale
	configure_x11_keyboard
	configure_hostname_hosts
	create_accounts
	configure_network_files
	sync_and_install_packages
	enable_temp_build_sudo
	install_yay_if_needed
	install_gns3_server_if_needed
	install_repo_kernel_if_needed
	install_proton_ge_if_needed
	configure_persistent_swapfile
	configure_zram
	configure_mkinitcpio
	run_logged mkinitcpio -P || true
	configure_bootloader
	enable_services
	configure_gns3_libvirt_network
	local -a installer_groups=()
	[[ "$INSTALL_VIRT_SUITE" == "yes" ]] && installer_groups+=(libvirt)
	[[ "$INSTALL_GNS3" == "yes" ]] && installer_groups+=(docker wireshark kvm libvirt)
	append_user_to_existing_groups "${installer_groups[@]}"
	write_user_customizations
	write_session_helpers
	cleanup_package_cache
	cleanup_sensitive_files

	section "CHROOT OK"
		printf 'Shell utilisateur: %s\n' "$USER_SHELL_CHOICE"
		printf 'Extras utilitaires: %s\n' "${EXTRA_UTILITY_PACKAGES:-<aucun>}"
		if selection_string_contains "$EXTRA_UTILITY_PACKAGES" "fastfetch"; then
			printf 'Config fastfetch: ~/.config/fastfetch/config.jsonc\n'
		fi
		if [[ "$INSTALL_POWERLEVEL10K" == "yes" ]]; then
			printf 'Theme Zsh: powerlevel10k (lance p10k configure apres la premiere ouverture de session).\n'
		fi
		printf '\n'
	info "Configuration terminee."
}

main "$@"
EOF

	chmod 700 "$ARCH_CHROOT_SCRIPT"
}

run_chroot_install() {
	local chroot_help

	section "ARCH-CHROOT"
	chroot_help=$(arch-chroot -h 2>&1 || true)

	if [[ "$BOOTLOADER" == "systemd-boot" && "$chroot_help" == *" -S"* ]]; then
		run_logged arch-chroot -S "$TARGET_MOUNT" /root/arch-postinstall.sh
	else
		run_logged arch-chroot "$TARGET_MOUNT" /root/arch-postinstall.sh
	fi
}

final_message() {
	section "INSTALLATION TERMINEE"
	printf 'Le systeme est installe sous %s.\n' "$TARGET_MOUNT"
	printf 'Notes post-install: %s\n' "$TARGET_MOUNT/root/POST_INSTALL_NOTES.txt"
	printf 'Log live: %s\n' "$LOG_FILE"

	if prompt_yes_no "Demonter les partitions maintenant ?" "n"; then
		swapoff -a || true
		umount -R "$TARGET_MOUNT"
		info "Partitions demontees. Vous pouvez redemarrer."
	else
		info "Partitions laissees montees pour inspection."
	fi
}

main() {
	require_root
	require_uefi
	init_ui
	choose_script_language
	info "Version du script: $SCRIPT_VERSION"
	info "Chemin du script: $(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
	require_command pacstrap
	require_command genfstab
	require_command arch-chroot
	require_command lsblk
	require_command sgdisk
	require_command mkfs.fat
	require_command partprobe
	require_command udevadm

	main_menu_loop
	prepare_target_filesystems
	run_pacstrap
	generate_fstab
	write_target_config
	run_chroot_install
	final_message
}

main "$@"
