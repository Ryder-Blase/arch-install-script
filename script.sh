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
USER_SHELL_CHOICE="bash"
INSTALL_OH_MY_ZSH="no"
INSTALL_POWERLEVEL10K="no"
EXTRA_UTILITY_PACKAGES="fastfetch"
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
		die "Ce script doit etre lance en root depuis l'Arch ISO."
	fi
}

require_uefi() {
	if [[ ! -d /sys/firmware/efi ]]; then
		die "Ce script cible un demarrage UEFI avec une partition EFI montee sur /boot/efi ou /boot selon le bootloader choisi."
	fi
}

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		die "Commande requise introuvable: $1"
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
			whiptail --backtitle "$SCRIPT_NAME" --title "Confirmation" --defaultno --yesno "$prompt" 10 "$UI_WIDTH" </dev/tty >/dev/tty 2>/dev/tty
		else
			whiptail --backtitle "$SCRIPT_NAME" --title "Confirmation" --yesno "$prompt" 10 "$UI_WIDTH" </dev/tty >/dev/tty 2>/dev/tty
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
				warn "Reponse invalide. Merci de repondre par oui/non."
				;;
		esac
	done
}

prompt_with_default() {
	local prompt=$1
	local default=$2
	local reply status=0

	if use_tui; then
		reply=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "Saisie" --inputbox "$prompt" 11 "$UI_WIDTH" "$default") || status=$?
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
			reply=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "Saisie" --inputbox "$prompt" 11 "$UI_WIDTH" "") || status=$?
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
			show_message "Valeur requise" "La valeur ne peut pas etre vide."
		else
			warn "La valeur ne peut pas etre vide."
		fi
	done
}

prompt_positive_integer() {
	local prompt=$1
	local default=$2
	local reply status=0

	while true; do
		if use_tui; then
			reply=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "Nombre" --inputbox "$prompt" 11 "$UI_WIDTH" "$default") || status=$?
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
			show_message "Entier invalide" "Merci de saisir un entier strictement positif."
		else
			warn "Merci de saisir un entier strictement positif."
		fi
	done
}

prompt_password_twice() {
	local prompt=$1
	local first second status=0

	while true; do
		if use_tui; then
			first=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "Mot de passe" --passwordbox "$prompt" 11 "$UI_WIDTH") || status=$?
			if (( status != 0 )); then
				return "$UI_CANCEL_STATUS"
			fi
			if [[ -z "$first" ]]; then
				show_message "Mot de passe requis" "Le mot de passe ne peut pas etre vide."
				continue
			fi
			second=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "Confirmation" --passwordbox "Confirmer $prompt" 11 "$UI_WIDTH") || status=$?
			if (( status != 0 )); then
				return "$UI_CANCEL_STATUS"
			fi
		else
		read -rsp "$prompt: " first
		printf '\n'
		read -rsp "Confirmer $prompt: " second
		printf '\n'
		fi

		if [[ -z "$first" ]]; then
			if use_tui; then
				show_message "Mot de passe requis" "Le mot de passe ne peut pas etre vide."
			else
				warn "Le mot de passe ne peut pas etre vide."
			fi
			continue
		fi

		if [[ "$first" != "$second" ]]; then
			if use_tui; then
				show_message "Mot de passe" "Les mots de passe ne correspondent pas."
			else
				warn "Les mots de passe ne correspondent pas."
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
		output=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "Selection" --default-item "${options[default_index-1]%%|*}" --menu "$prompt" "$UI_HEIGHT" "$UI_WIDTH" "$UI_MENU_HEIGHT" "${menu_args[@]}") || status=$?
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

		warn "Choix invalide."
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

		output=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "Selection multiple" --checklist "$prompt" 24 110 14 "${checklist_args[@]}") || status=$?
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
			disk_options+=("$disk" "${label:-disque}")
		done < <(lsblk -dn -o PATH,TYPE | awk '$2 == "disk" {print $1}')

		if (( ${#disk_options[@]} > 0 )); then
			disk=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "Choix du disque" --menu "Choisis le disque qui recevra l'installation." "$UI_HEIGHT" "$UI_WIDTH" "$UI_MENU_HEIGHT" "${disk_options[@]}") || status=$?
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
		section "Disques disponibles"
		list_block_devices
		disk=$(prompt_non_empty "Chemin du disque cible (ex: /dev/nvme0n1)")

		if [[ -b "$disk" ]] && [[ "$(lsblk -dn -o TYPE "$disk")" == "disk" ]]; then
			printf '%s\n' "$disk"
			return 0
		fi

		warn "Le disque saisi n'est pas valide."
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
			part_options=("__skip__" "Ne pas utiliser cette partition" "${part_options[@]}")
			default_tag="__skip__"
		else
			default_tag="${part_options[0]:-}"
		fi

		if (( ${#part_options[@]} > 0 )); then
			part=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "Choix de partition" --default-item "$default_tag" --menu "$prompt" "$UI_HEIGHT" "$UI_WIDTH" "$UI_MENU_HEIGHT" "${part_options[@]}") || status=$?
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
		section "Partitions disponibles"
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

		warn "La partition saisie n'est pas valide."
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
			ask_filesystem "Systeme de fichiers pour $partition" "$fallback_index"
			;;
	esac
}

ensure_target_mount_available() {
	if mountpoint -q "$TARGET_MOUNT"; then
		warn "Le point de montage $TARGET_MOUNT est deja utilise."
		if prompt_yes_no "Tout demonter sous $TARGET_MOUNT avant de preparer l'installation ?" "y"; then
			umount -R "$TARGET_MOUNT"
		else
			die "Impossible de preparer l'installation tant que $TARGET_MOUNT est occupe."
		fi
	fi

	mkdir -p "$TARGET_MOUNT"
}

configure_live_network() {
	local mode=${1:-interactive}
	local prompt_message network_ok="no" choice

	section "Reseau live"

	if ip route get 1.1.1.1 >/dev/null 2>&1 && ping -n -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
		network_ok="yes"
	elif getent hosts archlinux.org >/dev/null 2>&1 && ping -n -c1 -W2 archlinux.org >/dev/null 2>&1; then
		network_ok="yes"
	fi

	if [[ "$network_ok" == "yes" ]]; then
		info "Connexion Internet detectee dans l'environnement live."
		return 0
	fi

	if [[ "$mode" == "noninteractive" ]]; then
		warn "La connectivite n'a pas pu etre validee automatiquement. L'installation continue; pacstrap echouera si le reseau du live n'est pas pret."
		return 0
	fi

	prompt_message="Aucune connexion Internet n'a ete validee dans l'environnement live.

Tu peux ouvrir iwctl pour configurer le Wi-Fi, poursuivre sans verification,
ou annuler pour revenir en arriere."

	warn "Aucune connexion Internet validee pour le live."
	capture_value choice choose_option "$prompt_message" 2 \
		"iwctl|Ouvrir iwctl pour configurer le Wi-Fi" \
		"continue|Continuer sans verification reseau" \
		"abort|Annuler pour revenir au live" || return "$?"
	case "$choice" in
		iwctl)
			run_interactive_command iwctl
			if ip route get 1.1.1.1 >/dev/null 2>&1 && ping -n -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
				info "Connexion Internet detectee apres configuration manuelle."
			else
				warn "Toujours aucune connexion validee. Pacstrap risque d'echouer."
			fi
			;;
		continue)
			warn "Installation poursuivie sans verification reseau."
			;;
		abort)
			die "Installation annulee a ta demande."
			;;
	esac
}

collect_identity() {
	local status=0

	section "Identite"
	capture_value HOSTNAME prompt_with_default "Hostname" "$HOSTNAME" || return "$?"
	capture_value USERNAME prompt_with_default "Utilisateur principal" "$USERNAME" || return "$?"
	capture_value TIMEZONE prompt_with_default "Timezone" "$TIMEZONE" || return "$?"
	capture_value LOCALE prompt_with_default "Locale" "$LOCALE" || return "$?"
	capture_value KEYMAP prompt_with_default "Keymap console" "$KEYMAP" || return "$?"

	capture_value ROOT_PASSWORD prompt_password_twice "Mot de passe root" || return "$?"
	if prompt_yes_no "Utiliser le meme mot de passe pour $USERNAME ?" "y"; then
		USER_PASSWORD=$ROOT_PASSWORD
	else
		status=$?
		if is_ui_cancel_status "$status"; then
			return "$status"
		fi
		capture_value USER_PASSWORD prompt_password_twice "Mot de passe pour $USERNAME" || return "$?"
	fi

	capture_value CPU_VENDOR choose_option "Microcode CPU" 1 \
		"amd|AMD" \
		"intel|Intel" \
		"none|Aucun" || return "$?"
}

collect_system_stack() {
	local kernel_choice status=0

	section "Systeme"

	set_yes_no_var ENABLE_MULTILIB "Activer le depot multilib ?" "y" || return "$?"
	set_yes_no_var PREPARE_CHAOTIC "Ajouter Chaotic-AUR (paquets compiled: mesa-tkg, linux-cachyos…) ?" "n" || return "$?"

	capture_value NETWORK_STACK choose_option "Service reseau a installer" 1 \
		"networkmanager|NetworkManager - simple et polyvalent" \
		"systemd-networkd|systemd-networkd + resolved - leger et natif" \
		"iwd|iwd + resolved - Wi-Fi minimal" \
		"none|Aucun service reseau active par defaut" || return "$?"

	capture_value AUDIO_STACK choose_option "Pile audio a installer" 1 \
		"pipewire|PipeWire - moderne et polyvalent" \
		"pulseaudio|PulseAudio - compatibilite classique" \
		"none|ALSA uniquement - installation minimale" || return "$?"

	capture_value BOOTLOADER choose_option "Chargeur de demarrage UEFI" 1 \
		"grub|GRUB - flexible et pratique en multi-boot" \
		"systemd-boot|systemd-boot - simple et leger pour Arch" || return "$?"

	case "$BOOTLOADER" in
		grub)
			EFI_MOUNT_TARGET="/boot/efi"
			set_yes_no_var USE_OS_PROBER "Activer os-prober pour detecter automatiquement les autres OS dans GRUB ?" "y" || return "$?"
			;;
		systemd-boot)
			EFI_MOUNT_TARGET="/boot"
			USE_OS_PROBER="no"
			warn "systemd-boot utilisera l'ESP montee sur /boot pour y stocker noyau et initramfs. Verifie sa taille, surtout en dual boot."
			;;
	esac

	capture_value DESKTOP_CHOICE choose_option "Environnement de bureau / WM" 1 \
		"gnome|GNOME" \
		"kde|KDE Plasma" \
		"xfce|XFCE" \
		"lxqt|LXQt" \
		"hyprland|Hyprland" \
		"i3|i3" \
		"icewm|IceWM" \
		"sway|Sway" \
		"labwc|Labwc" \
		"none|Aucun (TTY only)" || return "$?"

	case "$DESKTOP_CHOICE" in
		gnome|kde)
			capture_value SESSION_STACK choose_option "Session graphique" 3 \
				"x11|X11 uniquement" \
				"wayland|Wayland uniquement" \
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
		capture_value DISPLAY_MANAGER choose_option "Gestionnaire de session" 1 \
			"none|Aucun" \
			"gdm|GDM" \
			"sddm|SDDM" || return "$?"

		if [[ "$DISPLAY_MANAGER" == "none" ]]; then
			set_yes_no_var AUTOLOGIN "Autologin sur TTY1 (connexion automatique sans saisir le mot de passe) ?" "n" || return "$?"
			set_yes_no_var AUTOSTART_WM "Lancer automatiquement le DE/WM apres le login TTY1 ?" "y" || return "$?"
		else
			AUTOLOGIN="no"
			AUTOSTART_WM="no"
		fi

		capture_value GPU_VENDOR choose_option "GPU principal" 1 \
			"amd|AMD" \
			"intel|Intel" \
			"amd-intel|AMD + Intel" \
			"nvidia|NVIDIA proprietaire" \
			"generic|Generique / VM" || return "$?"

		if [[ "$GPU_VENDOR" == "nvidia" ]]; then
			MESA_MODE="nvidia"
			CUSTOM_MESA_PACKAGE=""
			CUSTOM_MESA_LIB32_PACKAGE=""
		else
			capture_value MESA_MODE choose_option "Source de Mesa" 1 \
				"official|Mesa officiel" \
				"chaotic|Package Mesa custom via Chaotic-AUR" \
				"aur|Package Mesa custom via AUR" || return "$?"

			if [[ "$MESA_MODE" == "chaotic" ]]; then
				PREPARE_CHAOTIC="yes"
				capture_value CUSTOM_MESA_PACKAGE prompt_with_default "Package Mesa custom (ex: mesa-tkg-git, mesa-git)" "mesa-tkg-git" || return "$?"
				if [[ "$ENABLE_MULTILIB" == "yes" ]]; then
					capture_value CUSTOM_MESA_LIB32_PACKAGE prompt_with_default "Package lib32 associe" "lib32-$CUSTOM_MESA_PACKAGE" || return "$?"
				fi
			elif [[ "$MESA_MODE" == "aur" ]]; then
				capture_value CUSTOM_MESA_PACKAGE prompt_with_default "Package Mesa AUR a compiler" "mesa-git" || return "$?"
				if [[ "$ENABLE_MULTILIB" == "yes" ]]; then
					capture_value CUSTOM_MESA_LIB32_PACKAGE prompt_with_default "Package lib32 AUR associe" "lib32-$CUSTOM_MESA_PACKAGE" || return "$?"
				fi
			fi
		fi
	else
		DISPLAY_MANAGER="none"
		GPU_VENDOR="headless"
		MESA_MODE="headless"
	fi

	capture_value kernel_choice choose_option "Noyau Linux" 1 \
			"linux|linux (officiel)" \
			"linux-lts|linux-lts (officiel)" \
			"linux-zen|linux-zen (officiel)" \
			"linux-hardened|linux-hardened (officiel)" \
			"linux-tkg-repo|Compiler linux-tkg depuis le depot Git" \
			"chaotic-custom|Autre package noyau via Chaotic-AUR" \
			"aur-custom|Compiler un noyau custom via AUR" || return "$?"

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
			capture_value KERNEL_PACKAGE prompt_non_empty "Package noyau Chaotic-AUR (nom exact, ex: linux-cachyos)" || return "$?"
			capture_value KERNEL_HEADERS_PACKAGE prompt_with_default "Package headers associe" "${KERNEL_PACKAGE}-headers" || return "$?"
			KERNEL_REPO_URL=""
			;;
		aur-custom)
			KERNEL_MODE="aur"
			capture_value KERNEL_PACKAGE prompt_non_empty "Package noyau AUR a compiler (nom exact)" || return "$?"
			capture_value KERNEL_HEADERS_PACKAGE prompt_with_default "Package headers associe" "${KERNEL_PACKAGE}-headers" || return "$?"
			KERNEL_REPO_URL=""
			;;
	esac

	set_yes_no_var ENABLE_AVAHI "Activer Avahi pour la decouverte locale (mDNS / .local) ?" "y" || return "$?"
	set_yes_no_var ENABLE_BLUETOOTH "Activer Bluetooth au demarrage ?" "y" || return "$?"
	set_yes_no_var ENABLE_OPENSSH "Installer et activer OpenSSH ?" "n" || return "$?"

	configure_user_extras || return "$?"
}

configure_user_extras() {
	local status=0

	section "Utilisateur"

	capture_value USER_SHELL_CHOICE choose_option "Shell principal pour $USERNAME" "$(option_index_for_key "$USER_SHELL_CHOICE" \
		"bash|Bash" \
		"zsh|Zsh")" \
		"bash|Bash" \
		"zsh|Zsh" || return "$?"

	if [[ "$USER_SHELL_CHOICE" == "zsh" ]]; then
		set_yes_no_var INSTALL_OH_MY_ZSH "Installer Oh My Zsh ?" "$([[ "$INSTALL_OH_MY_ZSH" == "yes" ]] && printf 'y' || printf 'n')" || return "$?"
		if [[ "$INSTALL_OH_MY_ZSH" == "yes" ]]; then
			set_yes_no_var INSTALL_POWERLEVEL10K "Installer Powerlevel10k ?" "$([[ "$INSTALL_POWERLEVEL10K" == "yes" ]] && printf 'y' || printf 'n')" || return "$?"
		else
			INSTALL_POWERLEVEL10K="no"
		fi
	else
		INSTALL_OH_MY_ZSH="no"
		INSTALL_POWERLEVEL10K="no"
	fi

	capture_value EXTRA_UTILITY_PACKAGES choose_multi_option "Paquets utiles a installer (liste non exhaustive)" "$EXTRA_UTILITY_PACKAGES" \
		"fastfetch|fastfetch - infos systeme stylisees" \
		"btop|btop - moniteur systeme moderne" \
		"neovim|neovim - editeur terminal" \
		"tmux|tmux - multiplexeur terminal" \
		"fzf|fzf - fuzzy finder" \
		"ripgrep|ripgrep - recherche ultra rapide" \
		"fd|fd - find moderne" \
		"bat|bat - cat colore" \
		"eza|eza - remplacement moderne de ls" \
		"unzip|unzip - support zip" \
		"zip|zip - creation d'archives zip" \
		"reflector|reflector - optimisation des miroirs Arch" || return "$?"
}

collect_linux_tkg_options() {
	local status=0

	section "Linux-tkg"

	if [[ "$KERNEL_MODE" != "repo" ]]; then
		warn "Passe d'abord le noyau sur 'Compiler linux-tkg depuis le depot Git' dans Stack systeme."
		return 0
	fi

	cat <<'EOF'
Le mode linux-tkg ne force plus aucune preconfiguration.

Pendant le build, le PKGBUILD/linux-tkg utilisera ses propres menus interactifs
et son propre customization.cfg upstream. Le script d'installation se contente de:
- cloner / mettre a jour le depot
- lancer makepkg -si dans le chroot
- laisser linux-tkg te poser ses questions lui-meme
EOF

	if prompt_yes_no "Utiliser l'URL officielle du depot linux-tkg ?" "y"; then
		KERNEL_REPO_URL="https://github.com/Frogging-Family/linux-tkg.git"
	else
		status=$?
		if is_ui_cancel_status "$status"; then
			return "$status"
		fi
		capture_value KERNEL_REPO_URL prompt_non_empty "URL du depot linux-tkg" || return "$?"
	fi
}

choose_storage_stack() {
	local storage_options status=0

	section "Stockage"
	storage_options=(
		"standard|Partitions classiques sans chiffrement"
		"luks|Racine chiffree avec LUKS"
		"luks-lvm|LUKS + LVM pour plus de souplesse"
	)
	capture_value STORAGE_STACK choose_option "Choisis le schema de stockage" "$(option_index_for_key "$STORAGE_STACK" "${storage_options[@]}")" "${storage_options[@]}" || return "$?"

	case "$STORAGE_STACK" in
		standard)
			FORMAT_ROOT_CONTAINER="no"
			LUKS_PASSWORD=""
			;;
		luks|luks-lvm)
			FORMAT_ROOT_CONTAINER="yes"
			capture_value LUKS_NAME prompt_with_default "Nom du conteneur LUKS" "$LUKS_NAME" || return "$?"
			if [[ -n "$LUKS_PASSWORD" ]]; then
				if prompt_yes_no "Reutiliser le mot de passe LUKS deja saisi ?" "y"; then
					:
				else
					status=$?
					if is_ui_cancel_status "$status"; then
						return "$status"
					fi
					capture_value LUKS_PASSWORD prompt_password_twice "Mot de passe LUKS" || return "$?"
				fi
			else
				capture_value LUKS_PASSWORD prompt_password_twice "Mot de passe LUKS" || return "$?"
			fi
			if [[ "$STORAGE_STACK" == "luks-lvm" ]]; then
				capture_value LVM_VG_NAME prompt_with_default "Nom du groupe de volumes" "$LVM_VG_NAME" || return "$?"
				capture_value LVM_ROOT_NAME prompt_with_default "Nom du volume logique /" "$LVM_ROOT_NAME" || return "$?"
				set_yes_no_var LVM_CREATE_HOME "Creer un volume logique /home ?" "$([[ "$LVM_CREATE_HOME" == "yes" ]] && printf 'y' || printf 'n')" || return "$?"
				if [[ "$LVM_CREATE_HOME" == "yes" ]]; then
					capture_value ROOT_LV_SIZE_GIB prompt_positive_integer "Taille du volume logique / (GiB)" "$ROOT_LV_SIZE_GIB" || return "$?"
					capture_value LVM_HOME_NAME prompt_with_default "Nom du volume logique /home" "$LVM_HOME_NAME" || return "$?"
				fi
				set_yes_no_var LVM_CREATE_SWAP "Creer un volume logique swap ?" "$([[ "$LVM_CREATE_SWAP" == "yes" ]] && printf 'y' || printf 'n')" || return "$?"
				if [[ "$LVM_CREATE_SWAP" == "yes" ]]; then
					capture_value LVM_SWAP_SIZE_GIB prompt_positive_integer "Taille du volume logique swap (GiB)" "$LVM_SWAP_SIZE_GIB" || return "$?"
					capture_value LVM_SWAP_NAME prompt_with_default "Nom du volume logique swap" "$LVM_SWAP_NAME" || return "$?"
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
	set_yes_no_var USE_BTRFS_SUBVOLUMES "Utiliser le layout btrfs recommande (@, @home, @log, @pkg, @snapshots) ?" "$default_answer"
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
}

auto_partition_disk() {
	local next_index=1
	local status=0

	section "Partitionnement auto"
	capture_value TARGET_DISK select_disk || return "$?"

	if prompt_yes_no "ATTENTION: toutes les donnees sur $TARGET_DISK seront effacees.

Lancer le partitionnement automatique ?" "n"; then
		:
	else
		status=$?
		if is_ui_cancel_status "$status"; then
			return "$status"
		fi
		die "Partitionnement automatique annule."
	fi

	capture_value ROOT_FS ask_filesystem "Systeme de fichiers pour la racine /" 1 || return "$?"
	configure_btrfs_layout_if_needed || return "$?"

	if [[ "$STORAGE_STACK" == "luks-lvm" ]]; then
		if [[ "$LVM_CREATE_HOME" == "yes" ]]; then
			capture_value HOME_FS ask_filesystem "Systeme de fichiers du volume logique /home" 1 || return "$?"
			FORMAT_HOME="yes"
		else
			HOME_PART=""
			FORMAT_HOME="no"
		fi
		AUTO_CREATE_HOME="no"
		AUTO_CREATE_SWAP="no"
		SWAP_PART=""
	else
		set_yes_no_var AUTO_CREATE_SWAP "Creer une partition swap dediee ?" "y" || return "$?"
		if [[ "$AUTO_CREATE_SWAP" == "yes" ]]; then
			capture_value AUTO_SWAP_SIZE_GIB prompt_positive_integer "Taille de la partition swap (GiB)" "$AUTO_SWAP_SIZE_GIB" || return "$?"
		fi

		set_yes_no_var AUTO_CREATE_HOME "Creer une partition /home distincte ?" "n" || return "$?"
		if [[ "$AUTO_CREATE_HOME" == "yes" ]]; then
			capture_value AUTO_ROOT_SIZE_GIB prompt_positive_integer "Taille de la partition / avant /home (GiB)" "$AUTO_ROOT_SIZE_GIB" || return "$?"
			capture_value HOME_FS ask_filesystem "Systeme de fichiers pour /home" 1 || return "$?"
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

	section "Partitionnement manuel"

	capture_value TARGET_DISK select_disk || return "$?"
	if [[ "$PARTITION_MODE" == "cfdisk" ]]; then
		run_interactive_command cfdisk "$TARGET_DISK"
	fi

	capture_value EFI_PART prompt_partition "Partition EFI a utiliser" || return "$?"
	set_yes_no_var FORMAT_EFI "Reformater $EFI_PART en FAT32 ?" "n" || return "$?"

	capture_value ROOT_PART prompt_partition "Partition racine / a utiliser" || return "$?"
	case "$STORAGE_STACK" in
		standard|luks)
			if [[ "$STORAGE_STACK" == "luks" ]]; then
				set_yes_no_var FORMAT_ROOT_CONTAINER "Initialiser un conteneur LUKS sur $ROOT_PART ?" "y" || return "$?"
			fi

			if prompt_yes_no "Reformater le filesystem de / ?" "y"; then
				FORMAT_ROOT="yes"
				capture_value ROOT_FS ask_filesystem "Systeme de fichiers pour la racine /" 1 || return "$?"
			else
				status=$?
				if is_ui_cancel_status "$status"; then
					return "$status"
				fi
				FORMAT_ROOT="no"
				if [[ "$STORAGE_STACK" == "standard" ]]; then
					capture_value ROOT_FS detect_or_prompt_filesystem "$ROOT_PART" 1 || return "$?"
				else
					capture_value ROOT_FS ask_filesystem "Systeme de fichiers deja present dans le conteneur LUKS" 1 || return "$?"
				fi
			fi
			configure_btrfs_layout_if_needed || return "$?"

			if prompt_yes_no "Utiliser une partition /home distincte ?" "n"; then
				capture_value HOME_PART prompt_partition "Partition /home a utiliser" || return "$?"
				if prompt_yes_no "Reformater $HOME_PART ?" "n"; then
					FORMAT_HOME="yes"
					capture_value HOME_FS ask_filesystem "Systeme de fichiers pour /home" 1 || return "$?"
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

			if prompt_yes_no "Activer une partition swap dediee ?" "y"; then
				capture_value SWAP_PART prompt_partition "Partition swap a utiliser" || return "$?"
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
			capture_value ROOT_FS ask_filesystem "Systeme de fichiers du volume logique /" 1 || return "$?"
			configure_btrfs_layout_if_needed || return "$?"
			HOME_PART=""
			SWAP_PART=""
			if [[ "$LVM_CREATE_HOME" == "yes" ]]; then
				FORMAT_HOME="yes"
				capture_value HOME_FS ask_filesystem "Systeme de fichiers du volume logique /home" 1 || return "$?"
			else
				FORMAT_HOME="no"
			fi
			;;
	esac
}

collect_partitioning() {
	choose_storage_stack || return "$?"

	capture_value PARTITION_MODE choose_option "Comment veux-tu preparer le stockage ?" 1 \
		"manual|Utiliser des partitions deja creees" \
		"cfdisk|Ouvrir cfdisk puis choisir les partitions" \
		"auto|Effacer un disque et creer EFI + / (+ /home et swap optionnels)" || return "$?"

	case "$PARTITION_MODE" in
		auto)
			auto_partition_disk || return "$?"
			;;
		manual|cfdisk)
			manual_partition_layout || return "$?"
			;;
	esac
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
	section "Preparation et montage des partitions"
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
			if [[ "$LVM_CREATE_HOME" == "yes" ]]; then
				run_logged lvcreate -L "${ROOT_LV_SIZE_GIB}G" -n "$LVM_ROOT_NAME" "$LVM_VG_NAME"
			fi
			if [[ "$LVM_CREATE_SWAP" == "yes" ]]; then
				run_logged lvcreate -L "${LVM_SWAP_SIZE_GIB}G" -n "$LVM_SWAP_NAME" "$LVM_VG_NAME"
				swap_source="/dev/$LVM_VG_NAME/$LVM_SWAP_NAME"
			else
				swap_source=""
			fi
			if [[ "$LVM_CREATE_HOME" == "yes" ]]; then
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

	if [[ "$USER_SHELL_CHOICE" == "zsh" ]]; then
		append_unique OFFICIAL_PACKAGES zsh
	fi

	local -a extra_utility_packages=()
	read -r -a extra_utility_packages <<< "$EXTRA_UTILITY_PACKAGES"
	if ((${#extra_utility_packages[@]})); then
		append_unique OFFICIAL_PACKAGES "${extra_utility_packages[@]}"
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
			append_unique OFFICIAL_PACKAGES i3-wm i3status i3lock kitty rofi feh picom dunst maim slop xclip brightnessctl playerctl nautilus virt-manager code polkit-gnome
			[[ "$NETWORK_STACK" == "networkmanager" ]] && append_unique OFFICIAL_PACKAGES network-manager-applet
			[[ "$ENABLE_BLUETOOTH" == "yes" ]] && append_unique OFFICIAL_PACKAGES blueman
			;;
		icewm)
			append_unique OFFICIAL_PACKAGES icewm icewm-extra xterm
			;;
		sway)
			append_unique OFFICIAL_PACKAGES sway foot swaybg swayidle swaylock waybar wofi mako grim slurp brightnessctl playerctl nautilus virt-manager code elementary-icon-theme xdg-desktop-portal-wlr polkit-gnome
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
			printf 'Oui'
			;;
		no)
			printf 'Non'
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
			printf 'Aucun'
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
			printf 'NVIDIA proprietaire'
			;;
		gpu:generic)
			printf 'Generique / VM'
			;;
		gpu:headless)
			printf 'Sans GPU'
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
			printf 'Manuel'
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
			printf 'Aucun'
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
			printf 'Simple'
			;;
		storage:luks)
			printf 'LUKS'
			;;
		storage:luks-lvm)
			printf 'LUKS + LVM'
			;;
		kernel-mode:official)
			printf 'officiel'
			;;
		kernel-mode:repo)
			printf 'depot Git'
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
		printf 'a faire'
	fi
}

ready_label() {
	if [[ -n "${1:-}" ]]; then
		printf 'OK'
	else
		printf 'A faire'
	fi
}

pair_ready_label() {
	if [[ -n "${1:-}" && -n "${2:-}" ]]; then
		printf 'OK'
	else
		printf 'A faire'
	fi
}

count_selected_items() {
	local values=${1:-}
	local -a items=()

	read -r -a items <<< "$values"
	printf '%s' "${#items[@]}"
}

describe_identity_status() {
	printf '%s / %s / secrets %s' "$HOSTNAME" "$USERNAME" "$(pair_ready_label "$ROOT_PASSWORD" "$USER_PASSWORD")"
}

describe_system_status() {
	printf '%s / %s / %s' "$(pretty_label bootloader "$BOOTLOADER")" "$KERNEL_PACKAGE" "$(pretty_label desktop "$DESKTOP_CHOICE")"
}

describe_user_status() {
	local extra_count

	extra_count=$(count_selected_items "$EXTRA_UTILITY_PACKAGES")
	if (( extra_count == 0 )); then
		printf '%s / aucun extra' "$(pretty_label shell "$USER_SHELL_CHOICE")"
	else
		printf '%s / %s extra%s' "$(pretty_label shell "$USER_SHELL_CHOICE")" "$extra_count" "$([[ "$extra_count" -gt 1 ]] && printf 's')"
	fi
}

describe_storage_status() {
	printf '%s / root %s' "$(pretty_label storage "$STORAGE_STACK")" "$(short_device_label "$ROOT_PART")"
}

describe_tkg_status() {
	if [[ "$KERNEL_MODE" == "repo" ]]; then
		printf 'Actif'
	else
		printf 'Inactif'
	fi
}

render_summary() {
	cat <<EOF
Identite
Machine        : $HOSTNAME
Utilisateur    : $USERNAME
Locale         : $LOCALE / $KEYMAP
Fuseau         : $TIMEZONE
Secrets        : root $(ready_label "$ROOT_PASSWORD") / user $(ready_label "$USER_PASSWORD") / luks $(ready_label "$LUKS_PASSWORD")

Systeme
Boot           : $(pretty_label bootloader "$BOOTLOADER")
Noyau          : $KERNEL_PACKAGE
Bureau         : $(pretty_label desktop "$DESKTOP_CHOICE") / $(pretty_label session "$SESSION_STACK")
GPU            : $(pretty_label gpu "$GPU_VENDOR")
Reseau         : $(pretty_label network "$NETWORK_STACK")
Audio          : $(pretty_label audio "$AUDIO_STACK")
Shell          : $(pretty_label shell "$USER_SHELL_CHOICE")
Extras         : ${EXTRA_UTILITY_PACKAGES:-aucun}
Options        : multilib $(pretty_bool "$ENABLE_MULTILIB") / avahi $(pretty_bool "$ENABLE_AVAHI") / bluetooth $(pretty_bool "$ENABLE_BLUETOOTH") / ssh $(pretty_bool "$ENABLE_OPENSSH")
Boot extras    : os-prober $(pretty_bool "$USE_OS_PROBER") / chaotic $(pretty_bool "$PREPARE_CHAOTIC")
Linux-tkg      : $([[ "$KERNEL_MODE" == "repo" ]] && printf 'Actif' || printf 'Inactif')

Stockage
Mode           : $(pretty_label storage "$STORAGE_STACK")
Disque         : ${TARGET_DISK:-<non choisi>}
EFI            : ${EFI_PART:-<non choisi>} / format $(pretty_bool "$FORMAT_EFI")
Racine         : ${ROOT_PART:-<non choisi>} / ${ROOT_FS:-n/a}
Home           : ${HOME_PART:-<aucun>} / ${HOME_FS:-n/a}
Swap           : ${SWAP_PART:-<aucune>}
Chiffrement    : $([[ "$STORAGE_STACK" == "standard" ]] && printf 'Non' || printf '%s' "$LUKS_NAME")
LVM            : $([[ "$STORAGE_STACK" == "luks-lvm" ]] && printf '%s [%s,%s,%s]' "$LVM_VG_NAME" "$LVM_ROOT_NAME" "$LVM_HOME_NAME" "$LVM_SWAP_NAME" || printf 'Non')
btrfs          : subvolumes $(pretty_bool "$USE_BTRFS_SUBVOLUMES")

Paquets
Base           : ${#PACSTRAP_PACKAGES[@]}
Officiels      : ${#OFFICIAL_PACKAGES[@]}
Chaotic        : ${#CHAOTIC_PACKAGES[@]}
AUR            : ${#AUR_PACKAGES[@]}
Services       : ${SERVICES_TO_ENABLE[*]:-<aucun>}
EOF
}

render_dashboard_overview() {
	cat <<EOF
Configuration Arch

Cancel = retour
Ctrl+C = quitter

Etat : identite $(pair_ready_label "$ROOT_PASSWORD" "$USER_PASSWORD") / stockage $(ready_label "$ROOT_PART")
EOF
}

show_summary() {
	local confirm=${1:-yes}

	section "Verification finale"
	if use_tui; then
		local summary_file
		summary_file=$(mktemp "$WORKDIR/summary.XXXXXX")
		render_summary > "$summary_file"
		whiptail --backtitle "$SCRIPT_NAME" --title "Verification finale" --scrolltext --textbox "$summary_file" 30 100 </dev/tty >/dev/tty 2>/dev/tty
		rm -f "$summary_file"
	else
		render_summary
	fi

	[[ "$confirm" == "no" ]] && return 0

	if prompt_yes_no "Confirmer et lancer l'installation ?" "n"; then
		return 0
	fi
	local status=$?
	if is_ui_cancel_status "$status"; then
		return "$status"
	fi
	return "$UI_CANCEL_STATUS"
}

save_profile_interactive() {
	local profile_path

	section "Sauvegarde du profil"
	mkdir -p "$WORKDIR/profiles"
	capture_value profile_path prompt_with_default "Chemin du profil" "$WORKDIR/profiles/default.conf" || return "$?"
	: > "$profile_path"
	write_scalar_vars "$profile_path" \
		HOSTNAME USERNAME TIMEZONE LOCALE KEYMAP CPU_VENDOR GPU_VENDOR \
		NETWORK_STACK AUDIO_STACK DESKTOP_CHOICE SESSION_STACK DISPLAY_MANAGER \
		ENABLE_MULTILIB ENABLE_AVAHI ENABLE_BLUETOOTH ENABLE_OPENSSH USER_SHELL_CHOICE \
		INSTALL_OH_MY_ZSH INSTALL_POWERLEVEL10K EXTRA_UTILITY_PACKAGES USE_OS_PROBER \
		PREPARE_CHAOTIC AUTOLOGIN AUTOSTART_WM BOOTLOADER EFI_MOUNT_TARGET KERNEL_REPO_URL STORAGE_STACK \
		USE_BTRFS_SUBVOLUMES FORMAT_ROOT_CONTAINER LUKS_NAME LVM_VG_NAME LVM_ROOT_NAME \
		LVM_HOME_NAME LVM_SWAP_NAME LVM_CREATE_HOME LVM_CREATE_SWAP ROOT_LV_SIZE_GIB \
		LVM_SWAP_SIZE_GIB KERNEL_MODE KERNEL_PACKAGE KERNEL_HEADERS_PACKAGE MESA_MODE \
		CUSTOM_MESA_PACKAGE CUSTOM_MESA_LIB32_PACKAGE TARGET_DISK PARTITION_MODE EFI_PART \
		ROOT_PART HOME_PART SWAP_PART FORMAT_EFI FORMAT_ROOT FORMAT_HOME ROOT_FS HOME_FS \
		AUTO_CREATE_HOME AUTO_CREATE_SWAP AUTO_SWAP_SIZE_GIB AUTO_ROOT_SIZE_GIB
	chmod 600 "$profile_path"
	info "Profil enregistre dans $profile_path"
	warn "Les mots de passe ne sont pas sauvegardes dans les profils."
}

load_profile_interactive() {
	local profile_path

	section "Chargement du profil"
	capture_value profile_path prompt_with_default "Chemin du profil" "$WORKDIR/profiles/default.conf" || return "$?"
	[[ -f "$profile_path" ]] || die "Profil introuvable: $profile_path"

	# shellcheck disable=SC1090
	source "$profile_path"
	FINAL_ROOT_DEVICE=""
	FINAL_HOME_DEVICE=""
	FINAL_SWAP_DEVICE=""
	validate_stack_choices
	info "Profil charge depuis $profile_path"
	if [[ -z "$ROOT_PASSWORD" || -z "$USER_PASSWORD" ]]; then
		warn "Les mots de passe restent a ressaisir avant l'installation."
	fi
}

ensure_ready_for_install() {
	if [[ -z "$ROOT_PASSWORD" || -z "$USER_PASSWORD" ]]; then
		warn "Les mots de passe systeme n'ont pas encore ete saisis."
		collect_identity || return "$?"
	fi

	if [[ "$STORAGE_STACK" != "standard" && -z "$LUKS_PASSWORD" ]]; then
		warn "Le mot de passe LUKS n'a pas encore ete saisi."
		choose_storage_stack || return "$?"
	fi

	if [[ -z "$EFI_PART" || -z "$ROOT_PART" ]]; then
		warn "Le partitionnement n'est pas encore defini."
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
			action=$(run_whiptail_capture --backtitle "$SCRIPT_NAME" --title "Configuration Arch" --default-item "Identite" --menu "$menu_text" 24 100 14 \
				"Identite" "$(describe_identity_status)" \
				"Systeme" "$(describe_system_status)" \
				"Utilisateur" "$(describe_user_status)" \
				"Stockage" "$(describe_storage_status)" \
				"Reseau" "Connexion du live ISO" \
				"Linux-tkg" "$(describe_tkg_status)" \
				"Sauver" "Enregistrer un profil" \
				"Charger" "Charger un profil" \
				"Resume" "Verifier avant installation" \
				"Installer" "Demarrer l'installation" \
				"Quitter" "Fermer l'installateur") || action="Quitter"
		else
			section "Menu principal"
			printf 'Etat: identite=%s, systeme=%s, stockage=%s\n' "$(pair_ready_label "$ROOT_PASSWORD" "$USER_PASSWORD")" "$KERNEL_PACKAGE" "$(ready_label "$ROOT_PART")"
			menu_options=(
				"Identite|$(describe_identity_status)"
				"Systeme|$(describe_system_status)"
				"Utilisateur|$(describe_user_status)"
				"Stockage|$(describe_storage_status)"
				"Reseau|Connexion du live ISO"
				"Linux-tkg|$(describe_tkg_status)"
				"Sauver|Enregistrer un profil"
				"Charger|Charger un profil"
				"Resume|Verifier avant installation"
				"Installer|Demarrer l'installation"
				"Quitter|Fermer l'installateur"
			)
			action=$(choose_option "Choisis une section" 1 "${menu_options[@]}")
		fi

		case "$action" in
			Identite)
				run_menu_action collect_identity
				;;
			Systeme)
				run_menu_action collect_system_stack
				;;
			Utilisateur)
				run_menu_action configure_user_extras
				;;
			Stockage)
				run_menu_action collect_partitioning
				;;
			Reseau)
				run_menu_action configure_live_network
				;;
			Linux-tkg)
				run_menu_action collect_linux_tkg_options
				;;
			Sauver)
				run_menu_action save_profile_interactive
				;;
			Charger)
				run_menu_action load_profile_interactive
				;;
			Resume)
				validate_stack_choices
				build_package_lists
				run_menu_action show_summary "no"
				;;
			Installer)
				if ensure_ready_for_install; then
					return 0
				fi
				action_status=$?
				if is_ui_cancel_status "$action_status"; then
					continue
				fi
				return "$action_status"
				;;
			Quitter)
				exit 0
				;;
		esac
		done
}

run_pacstrap() {
	section "Installation de la base systeme"
	info "Mode debug verbeux actif. Log live: $LOG_FILE"
	configure_live_network noninteractive
	run_logged timedatectl set-ntp true || true
	run_logged pacman -Sy --noconfirm archlinux-keyring
	run_logged pacstrap -K "$TARGET_MOUNT" "${PACSTRAP_PACKAGES[@]}"
}

generate_fstab() {
	section "fstab"
	log_command genfstab -U "$TARGET_MOUNT"
	genfstab -U "$TARGET_MOUNT" >> "$TARGET_MOUNT/etc/fstab"
	run_logged cp -L /etc/resolv.conf "$TARGET_MOUNT/etc/resolv.conf"
}

write_target_config() {
	section "Preparation du chroot"
	umask 077
	: > "$ARCH_CONFIG_PATH"
	write_scalar_vars "$ARCH_CONFIG_PATH" \
		HOSTNAME USERNAME TIMEZONE LOCALE KEYMAP CPU_VENDOR GPU_VENDOR NETWORK_STACK \
		AUDIO_STACK DESKTOP_CHOICE SESSION_STACK DISPLAY_MANAGER ENABLE_MULTILIB \
		ENABLE_AVAHI ENABLE_BLUETOOTH ENABLE_OPENSSH USER_SHELL_CHOICE \
		INSTALL_OH_MY_ZSH INSTALL_POWERLEVEL10K EXTRA_UTILITY_PACKAGES \
		USE_OS_PROBER PREPARE_CHAOTIC AUTOLOGIN AUTOSTART_WM \
		BOOTLOADER EFI_MOUNT_TARGET KERNEL_REPO_URL STORAGE_STACK USE_BTRFS_SUBVOLUMES \
		FORMAT_ROOT_CONTAINER LUKS_NAME LVM_VG_NAME LVM_ROOT_NAME \
		LVM_HOME_NAME LVM_SWAP_NAME LVM_CREATE_HOME LVM_CREATE_SWAP ROOT_LV_SIZE_GIB \
		LVM_SWAP_SIZE_GIB TARGET_DISK PARTITION_MODE EFI_PART ROOT_PART HOME_PART \
		SWAP_PART FORMAT_EFI FORMAT_ROOT FORMAT_HOME ROOT_FS HOME_FS AUTO_CREATE_HOME \
		AUTO_CREATE_SWAP AUTO_SWAP_SIZE_GIB AUTO_ROOT_SIZE_GIB FINAL_ROOT_DEVICE \
		FINAL_HOME_DEVICE FINAL_SWAP_DEVICE KERNEL_MODE KERNEL_PACKAGE \
		KERNEL_HEADERS_PACKAGE MESA_MODE CUSTOM_MESA_PACKAGE CUSTOM_MESA_LIB32_PACKAGE \
		ROOT_PASSWORD USER_PASSWORD
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
	local pkgbase_file detected=""

	if [[ -n "$KERNEL_PACKAGE" && -e "/boot/vmlinuz-$KERNEL_PACKAGE" ]]; then
		printf '%s\n' "$KERNEL_PACKAGE"
		return 0
	fi

	for pkgbase_file in /usr/lib/modules/*/pkgbase; do
		[[ -f "$pkgbase_file" ]] || continue
		if [[ -z "$detected" ]]; then
			detected=$(<"$pkgbase_file")
		fi
		if grep -q 'tkg' "$pkgbase_file"; then
			cat "$pkgbase_file"
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

configure_mkinitcpio() {
	local hooks

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
	section "Timezone / locale"
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

configure_hostname_hosts() {
	section "Hostname"
	printf '%s\n' "$HOSTNAME" > /etc/hostname
	cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${HOSTNAME}.localdomain $HOSTNAME
HOSTS
}

configure_network_files() {
	section "Configuration reseau"

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
	section "Utilisateurs"

	echo "root:$ROOT_PASSWORD" | chpasswd

	if ! id "$USERNAME" >/dev/null 2>&1; then
		useradd -m -G wheel,audio,video,storage,optical,input -s /bin/bash "$USERNAME"
	fi

	echo "$USERNAME:$USER_PASSWORD" | chpasswd

	cat > /etc/sudoers.d/10-wheel <<'SUDOERS'
%wheel ALL=(ALL:ALL) ALL
SUDOERS
	chmod 440 /etc/sudoers.d/10-wheel

	# Créer les répertoires XDG standards + écrire user-dirs.dirs explicitement.
	# GNOME/KDE le font via PAM ; les WM minimalistes (i3/Hyprland/Sway) ne le font pas.
	# xdg-user-dirs-update dans un chroot tourne sans locale → user-dirs.dirs pas écrit →
	# Nautilus affiche "Aucun répertoire personnel". On écrit donc tout manuellement.
	local user_home="/home/$USERNAME"
	local dir
	for dir in Desktop Documents Downloads Music Pictures Videos Templates Public; do
		install -d -m 0755 -o "$USERNAME" -g "$USERNAME" "$user_home/$dir"
	done

	install -d -m 0700 -o "$USERNAME" -g "$USERNAME" "$user_home/.config"
	cat > "$user_home/.config/user-dirs.dirs" <<'USERDIRS'
# This file is written by the installer.
# Format: XDG_xxx_DIR="$HOME/relative-path"
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

	# Indique a xdg-user-dirs de ne pas renommer les dossiers selon la locale du premier login
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
monitor = eDP-1, 2560x1600@165, 0x0, 1.6666

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

output eDP-1 mode 2560x1600@165Hz pos 0 0 scale 1.6666

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
bindsym $mod+e exec nautilus
bindsym $mod+v exec virt-manager
bindsym $mod+c exec code
bindsym $mod+Escape exec swaylock -c 000000

bindsym $mod+q kill
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+f fullscreen disable
bindsym $mod+p floating toggle
bindsym $mod+t layout toggle split
bindsym $mod+s exec grim -g "$(slurp)" - | tee ~/Images/screenshot-$(date +%Y-%m-%d-%H%M%S).png | wl-copy

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

	chown "$USERNAME:$USERNAME" "$sway_config"
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
exec_always --no-startup-id picom
exec --no-startup-id dunst
exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
EOFI3

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
bindsym $mod+e exec nautilus
bindsym $mod+v exec virt-manager
bindsym $mod+c exec code
bindsym $mod+Escape exec i3lock -c 000000

bindsym $mod+q kill
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+f fullscreen disable
bindsym $mod+p floating toggle
bindsym $mod+t layout toggle split
bindsym $mod+s exec maim -s | tee ~/Images/screenshot-$(date +%Y-%m-%d-%H%M%S).png | xclip -selection clipboard -t image/png

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
	cat > "$user_home/.xprofile" <<'EOFXPROFILE'
export GTK_THEME=Adwaita:dark
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=Fusion
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

write_user_customizations() {
	section "Personnalisation utilisateur"
	write_fastfetch_config
	write_shell_setup
	write_foot_config
	write_gtk_dark_theme
	write_waybar_config
	write_hyprland_dotfiles
	write_sway_dotfiles
	write_i3_dotfiles
}

sync_and_install_packages() {
	section "Installation des paquets"
	run_logged pacman -Syu --noconfirm

	if ((${#CHAOTIC_PACKAGES[@]})); then
		run_logged pacman -S --noconfirm --needed "${CHAOTIC_PACKAGES[@]}"
	fi

	if ((${#OFFICIAL_PACKAGES[@]})); then
		run_logged pacman -S --noconfirm --needed "${OFFICIAL_PACKAGES[@]}"
	fi
}

install_paru_if_needed() {
	local aur_cmd

	if ((${#AUR_PACKAGES[@]} == 0)); then
		return 0
	fi

	if ! command -v paru >/dev/null 2>&1; then
		if grep -Eq '^\[chaotic-aur\]' /etc/pacman.conf; then
			run_logged pacman -S --noconfirm --needed paru-bin || true
		fi
	fi

	if ! command -v paru >/dev/null 2>&1; then
		ensure_user_build_dir
		run_logged runuser -u "$USERNAME" -- bash -lc 'set -euo pipefail; cd ~/builds; rm -rf paru; git clone https://aur.archlinux.org/paru.git; cd paru; makepkg -si --noconfirm --needed'
	fi

	aur_cmd=$(join_quoted "${AUR_PACKAGES[@]}")
	run_logged runuser -u "$USERNAME" -- bash -lc "set -euo pipefail; paru -S --noconfirm --needed --skipreview $aur_cmd"
}

install_repo_kernel_if_needed() {
	local repo_url_quoted repo_name build_dir detected_pkgbase

	if [[ "$KERNEL_MODE" != "repo" ]]; then
		return 0
	fi

	section "Compilation du noyau depuis le depot"
	ensure_user_build_dir

	repo_name="linux-tkg"
	build_dir="/home/$USERNAME/builds/${repo_name}-build"
	repo_url_quoted=$(printf '%q' "$KERNEL_REPO_URL")
	run_logged runuser -u "$USERNAME" -- bash -lc "set -euo pipefail; cd ~/builds; if [[ -d ${repo_name}-src/.git ]]; then cd ${repo_name}-src; git pull --ff-only; else git clone $repo_url_quoted ${repo_name}-src; fi; rm -rf ${repo_name}-build; mkdir -p ${repo_name}-build; rsync -a --delete --exclude=.git ${repo_name}-src/ ${repo_name}-build/"
	run_logged runuser -u "$USERNAME" -- bash -lc "set -euo pipefail; cd ~/builds/${repo_name}-build; makepkg -si --noconfirm --needed"

	detected_pkgbase=$(resolve_kernel_pkgbase)
	KERNEL_PACKAGE="$detected_pkgbase"
	KERNEL_HEADERS_PACKAGE="${detected_pkgbase}-headers"
}

enable_services() {
	local service

	section "Activation des services"
	for service in "${SERVICES_TO_ENABLE[@]}"; do
		run_logged systemctl enable "$service"
	done

	if pacman -Q dbus-broker >/dev/null 2>&1; then
		run_logged systemctl enable dbus-broker.service || true
	fi
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

	section "systemd-boot"
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

	section "Session sans display manager"

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
	} > "$notes_file"
}

cleanup_sensitive_files() {
	rm -f /root/arch-install.conf /root/arch-postinstall.sh
	rm -f /etc/sudoers.d/99-installer-nopasswd
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
	configure_hostname_hosts
	create_accounts
	configure_network_files
	sync_and_install_packages
	enable_temp_build_sudo
	install_paru_if_needed
	install_repo_kernel_if_needed
	configure_mkinitcpio
	run_logged mkinitcpio -P || true
	configure_bootloader
	enable_services
	write_user_customizations
	write_session_helpers
	cleanup_sensitive_files

	section "Chroot termine"
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

	section "arch-chroot"
	chroot_help=$(arch-chroot -h 2>&1 || true)

	if [[ "$BOOTLOADER" == "systemd-boot" && "$chroot_help" == *" -S"* ]]; then
		run_logged arch-chroot -S "$TARGET_MOUNT" /root/arch-postinstall.sh
	else
		run_logged arch-chroot "$TARGET_MOUNT" /root/arch-postinstall.sh
	fi
}

final_message() {
	section "Installation terminee"
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
