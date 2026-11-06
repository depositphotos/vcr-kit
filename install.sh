#!/bin/bash
#
# vcr-kit bootstrap: installs what is needed to fetch the VistaCreate engineering kit, then hands over to it.
#
#   curl -fsSL https://raw.githubusercontent.com/depositphotos/vcr-kit/master/install.sh | bash
#
# Its steps: Homebrew, the GitLab CLI (glab), a browser sign-in to GitLab, a clone of the private kit repository's
# release branch into ~/.local/share/vcr-kit, the `vcr-kit` command in ~/.local/bin, then `vcr-kit setup`. Express by default (each step
# goes ahead); VCR_KIT_DETAILED=1 asks before every step.
# Running it again updates the clone (and puts it on the release branch when it is on another one).
#
# Env overrides: VCR_KIT_HOME (where the kit is cloned), VCR_KIT_BIN (where the `vcr-kit` command is linked),
# VCR_KIT_DETAILED=1 (ask before every step, here and in `vcr-kit setup`; the default is express),
# VCR_KIT_REF (the kit's branch, default release; master runs the newest, unreleased code).
#
# Everything runs from main(), called on the last line, so a truncated download executes nothing.
# Compatible with bash 3.2 (the macOS system bash). macOS only.

set -euo pipefail

GITLAB_HOST="gitlab.com"
KIT_PATH="vistaprint-org/vistacreate/automation/vcr-kit"
KIT_URL="https://$GITLAB_HOST/$KIT_PATH.git"
KIT_HOME="${VCR_KIT_HOME:-$HOME/.local/share/vcr-kit}"
KIT_BIN="${VCR_KIT_BIN:-$HOME/.local/bin}"
KIT_REF="${VCR_KIT_REF:-release}"

# ------------------------------------------------------------------- output --

if [ -t 1 ]; then
	BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; RESET=$'\033[0m'
else
	BOLD=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
die()  { printf '%s✗ %s%s\n' "$RED" "$*" "$RESET" >&2; exit 1; }
step() { printf '\n%s%s%s\n' "$BOLD" "$*" "$RESET"; }

# Under `curl | bash` stdin is the script itself, so every answer is read from the terminal.
# Express by default: every question takes its default (yes), and `vcr-kit setup` runs express too. With
# VCR_KIT_DETAILED=1 every question waits for an answer; the variable reaches `vcr-kit setup` as well.
ask() {   # ask "question" → 0 for yes (the default), 1 for no
	local reply
	printf '%s [Y/n]: ' "$1" >/dev/tty
	if [ -z "${VCR_KIT_DETAILED:-}" ]; then
		printf 'yes (express)\n' >/dev/tty
		return 0
	fi
	IFS= read -r reply </dev/tty || reply="n"
	case "$reply" in
		""|y|Y|yes|Yes|YES) return 0 ;;
		*) return 1 ;;
	esac
}

# -------------------------------------------------------------- shell setup --

profile_file() {
	case "${SHELL##*/}" in
		zsh) echo "$HOME/.zprofile" ;;
		bash) echo "$HOME/.bash_profile" ;;
		*) echo "" ;;
	esac
}

ensure_profile_line() {   # ensure_profile_line LINE WHY
	local line="$1" why="$2" file
	file="$(profile_file)"
	if [ -z "$file" ]; then
		warn "Add this line to your shell's startup file $why: $line"
		return
	fi
	if grep -qxF "$line" "$file" 2>/dev/null; then
		return
	fi
	if ask "Add '$line' to $file $why?"; then
		printf '\n%s\n' "$line" >>"$file"
		ok "Added to $file. New terminals pick it up."
	else
		warn "Skipped. Add it yourself $why: $line"
	fi
}

# -------------------------------------------------------------------- steps --

check_terminal() {
	if ! (exec </dev/tty) 2>/dev/null; then
		die "This installer asks questions and needs an interactive terminal. Run it from Terminal or iTerm."
	fi
}

check_macos() {
	[ "$(uname -s)" = "Darwin" ] || die "vcr-kit supports macOS only for now."
	ok "macOS $(sw_vers -productVersion 2>/dev/null || echo)"
}

find_brew() {
	if command -v brew >/dev/null 2>&1; then command -v brew; return; fi
	local candidate
	for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
		if [ -x "$candidate" ]; then echo "$candidate"; return; fi
	done
}

check_brew() {
	step "Homebrew"
	local brew on_path=1
	command -v brew >/dev/null 2>&1 || on_path=0
	brew="$(find_brew)"
	if [ -z "$brew" ]; then
		say "Homebrew installs the command-line tools the kit needs (glab now; kubectl, telepresence, vault later)."
		ask "Homebrew is required. Install it?" || die "Homebrew is required. Install it from https://brew.sh and run this again."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
		brew="$(find_brew)"
		[ -n "$brew" ] || die "Homebrew did not install. See the messages above, then run this again."
	fi
	if [ "$on_path" = 0 ]; then
		eval "$("$brew" shellenv)"
		ensure_profile_line "eval \"\$($brew shellenv)\"" "so that Homebrew's tools are found in new terminals"
	fi
	ok "Homebrew $("$brew" --version 2>/dev/null | head -n 1 | sed 's/^Homebrew //')"
}

check_git() {
	if ! git --version >/dev/null 2>&1; then
		die "git is missing. Install Apple's command-line tools with 'xcode-select --install', then run this again."
	fi
}

check_glab() {
	step "GitLab CLI (glab)"
	if ! command -v glab >/dev/null 2>&1; then
		say "glab signs you in to GitLab and fetches the kit from its private repository."
		ask "glab authenticated to the Vistaprint GitLab is required. Install it?" \
			|| die "glab is required. Install it with 'brew install glab' and run this again."
		say "Updating Homebrew's formula list first (brew update)."
		brew update || warn "brew update failed: installing from the current formula list."
		brew install glab
	fi
	ok "$(glab --version 2>/dev/null | head -n 1)"
}

check_login() {
	step "Sign-in to GitLab"
	if glab auth status --hostname "$GITLAB_HOST" >/dev/null 2>&1; then
		ok "Signed in to $GITLAB_HOST"
		return
	fi
	say "The kit and the team's repositories are private, in the GitLab group ${KIT_PATH%%/automation/*}. glab, GitLab's"
	say "command-line tool, signs you in once: git clones with it, and agents open merge requests with it."
	say "A browser window opens: sign in to $GITLAB_HOST with your Vistaprint account, authorize glab, then come back here."
	ask "Sign in to GitLab now?" || die "The kit lives in a private GitLab repository, so a sign-in is required."
	glab auth login --hostname "$GITLAB_HOST" --web --git-protocol https </dev/tty
	glab auth status --hostname "$GITLAB_HOST" >/dev/null 2>&1 || die "The sign-in did not complete. Run this again."
	ok "Signed in to $GITLAB_HOST"
}

check_access() {
	if ! glab api "projects/${KIT_PATH//\//%2F}" >/dev/null 2>&1; then
		die "Your GitLab account cannot see $KIT_PATH. Ask your team lead for access to the GitLab group ${KIT_PATH%/*}, then run this again."
	fi
	ok "Access to $KIT_PATH"
}

fetch_kit() {
	step "The kit"
	check_git
	if [ -d "$KIT_HOME/.git" ]; then
		follow_branch || die "Could not update $KIT_HOME to its $KIT_REF branch (local changes?). Fix it, or move it away and run this again."
		ok "Updated $KIT_HOME ($KIT_REF)"
		return
	fi
	if [ -e "$KIT_HOME" ]; then
		die "$KIT_HOME exists but is not a vcr-kit clone. Move it away, or set VCR_KIT_HOME, and run this again."
	fi
	mkdir -p "$(dirname "$KIT_HOME")"
	# HTTPS with glab as the only credential helper: works with the browser sign-in, no SSH key needed.
	git -c credential.helper= -c 'credential.helper=!glab auth git-credential' clone --quiet --branch "$KIT_REF" "$KIT_URL" "$KIT_HOME"
	git -C "$KIT_HOME" config --add credential.helper ''
	git -C "$KIT_HOME" config --add credential.helper '!glab auth git-credential'
	ok "Cloned into $KIT_HOME ($KIT_REF)"
}

follow_branch() {   # puts the clone on KIT_REF (switching to it once) and fast-forwards it
	git -C "$KIT_HOME" fetch --quiet origin "+refs/heads/$KIT_REF:refs/remotes/origin/$KIT_REF" || return 1
	if [ "$(git -C "$KIT_HOME" symbolic-ref --quiet --short HEAD 2>/dev/null || true)" != "$KIT_REF" ]; then
		if git -C "$KIT_HOME" rev-parse --quiet --verify "refs/heads/$KIT_REF" >/dev/null; then
			git -C "$KIT_HOME" switch --quiet "$KIT_REF" || return 1
		else
			git -C "$KIT_HOME" switch --quiet --create "$KIT_REF" --track "origin/$KIT_REF" || return 1
		fi
	fi
	git -C "$KIT_HOME" merge --ff-only --quiet "origin/$KIT_REF"
}

link_command() {
	local kit="$KIT_HOME/vcr-kit" path_line
	if [ ! -x "$kit" ]; then
		warn "The kit's main script is not published yet. Nothing more to do for now; run this again later."
		exit 0
	fi
	mkdir -p "$KIT_BIN"
	ln -sf "$kit" "$KIT_BIN/vcr-kit"
	ok "Command: $KIT_BIN/vcr-kit"
	case ":$PATH:" in
		*":$KIT_BIN:"*) ;;
		*)
			if [ "$KIT_BIN" = "$HOME/.local/bin" ]; then
				# shellcheck disable=SC2016  # the line is written to the profile unexpanded, on purpose
				path_line='export PATH="$HOME/.local/bin:$PATH"'
			else
				path_line="export PATH=\"$KIT_BIN:\$PATH\""
			fi
			ensure_profile_line "$path_line" "so that the vcr-kit command is found in new terminals"
			export PATH="$KIT_BIN:$PATH"
			;;
	esac
}

main() {
	check_terminal
	printf '%svcr-kit%s — sets up the VistaCreate engineering kit on this Mac.\n' "$BOLD" "$RESET"
	say "Claude Code with the team's plugins, the workspace with the VistaCreate repositories, and the tokens the agents"
	say "use. It takes 20-30 minutes; have these ready:"
	say "  - your Vistaprint GitLab account, with access to the vistaprint-org/vistacreate group (signed in to in the browser);"
	say "  - a seat in the company's Claude organisation;"
	say "  - access to Jira (vistaprint.atlassian.net), Jenkins and Sentry, where you create two tokens on the way;"
	say "  - your LDAP login and password, and the VPN for Jenkins and the dev cluster."
	check_macos
	check_brew
	check_glab
	check_login
	check_access
	fetch_kit
	link_command
	step "Handing over to vcr-kit setup"
	exec "$KIT_BIN/vcr-kit" setup </dev/tty
}

main "$@"
