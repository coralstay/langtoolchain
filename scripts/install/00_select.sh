#!/usr/bin/env sh
# Interactive language/version picker.
#
# Prints nothing but a single file path to stdout on success (the resulting
# .tool-versions-style selection file) — every prompt and menu line goes to
# /dev/tty instead, so this script is safe to call via command substitution
# (`SELECTION_FILE="$(sh 00_select.sh)"`).
#
# Flags:
#   --all         skip the menu, select every language at its default version
#   --yes         skip the final "install these?" confirmation
#   --local[=DIR] pin to DIR (default: current directory) instead of asking;
#                 skips the interactive global/local prompt too
#
# If there is no controlling terminal at all (CI, fully non-interactive
# pipes), falls back to --all behavior automatically instead of hanging on
# a `read` that can never return. Pin scope likewise defaults to global
# when there's no tty to ask.

# -e: any unhandled non-zero exit kills the script. -u: referencing an
# unset variable is an error. (No pipefail — that's a bash/ksh/zsh
# extension, not POSIX; dash doesn't have it. This script avoids relying on
# it — see the fd-3 process-substitution replacement below for why piping
# straight into a loop was already avoided regardless.)
set -eu

# Resolve this script's own directory, regardless of the caller's cwd, so
# `. lib.sh` below always finds the right file. $0 (not ${BASH_SOURCE[0]}
# — POSIX sh has no BASH_SOURCE) works here because every caller always
# invokes this script by path (never a bare name looked up on PATH).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
# Pull in log/step/die/run/each_tool/binary_for_plugin/etc.
. "$SCRIPT_DIR/../lib.sh"

# Two directories up from scripts/install/ is the repo root.
REPO_ROOT="$(repo_root_from "$0")"
readonly REPO_ROOT
# The shipped, default list of languages/versions this repo installs.
readonly DEFAULT_CONFIG="$REPO_ROOT/.tool-versions"
# Bail out early with a clear message if the repo is somehow missing it.
[ -f "$DEFAULT_CONFIG" ] || die "Config file not found: $DEFAULT_CONFIG"

# Flags default to off; the loop below flips them on if passed.
SELECT_ALL=false
AUTO_YES=false
# SCOPE is empty until either a --local flag or the interactive prompt
# (further below) sets it to "global" or "local".
SCOPE=""
SCOPE_DIR=""
for arg in "$@"; do
  case "$arg" in
    --all) SELECT_ALL=true ;;
    --yes) AUTO_YES=true ;;
    --local) SCOPE="local"; SCOPE_DIR="$(pwd)" ;;
    --local=*) SCOPE="local"; SCOPE_DIR="${arg#--local=}" ;;
    # (unrecognized flags are silently ignored here — main.sh validates them)
  esac
done

# resolve_scope_dir <dir>: validates <dir> exists, then prints its absolute
# path — resolved now, once, so 06_set_globals.sh (running later, as its own
# process, possibly with a different cwd) gets an unambiguous path
# regardless of where it happens to be invoked from. Shared by both the
# --local=DIR flag path here and the interactive local-scope prompt below.
#######################################
# Validate <dir> exists and print its resolved absolute path.
# Globals:
#   None
# Arguments:
#   $1: dir — directory path to validate
# Outputs:
#   Writes the absolute, resolved directory path to STDOUT. On failure,
#   writes an error message to STDERR (via die()).
# Returns:
#   Does not return on failure — exits (via die()) with status 1.
#######################################
resolve_scope_dir() {
  [ -d "$1" ] || die "Directory not found: $1"
  ( cd "$1" && pwd )
}

if [ "$SCOPE" = "local" ]; then
  SCOPE_DIR="$(resolve_scope_dir "$SCOPE_DIR")"
fi

# scope_line: the "# scope: ..." line written as the first line of the
# output file — a comment, so each_tool's plugin/version parsing (which
# skips lines starting with '#') never has to know this exists.
#######################################
# Print the "# scope: ..." comment line for the selection file.
# Globals:
#   SCOPE
#   SCOPE_DIR
# Arguments:
#   None
# Outputs:
#   Writes "# scope: local <dir>" or "# scope: global" to STDOUT.
# Returns:
#   None
#######################################
scope_line() {
  if [ "$SCOPE" = "local" ]; then
    printf '# scope: local %s\n' "$SCOPE_DIR"
  else
    printf '# scope: global\n'
  fi
}

# write_with_scope <source-file> <dest-file>: prepends the scope line
# ahead of <source-file>'s content into <dest-file>.
#######################################
# Write <source-file>'s content into <dest-file>, prefixed by the scope line.
# Globals:
#   None
# Arguments:
#   $1: source file to read
#   $2: dest file to write
# Outputs:
#   None to STDOUT. Writes the scope line followed by <source-file>'s
#   content to <dest-file>.
# Returns:
#   None
#######################################
write_with_scope() {
  { scope_line; cat "$1"; } > "$2"
}

# Probe for a controlling terminal. `true < /dev/tty` tries to open
# /dev/tty for reading and does nothing with it; if that open fails (no
# tty — e.g. cron, CI, or this being piped through something with no
# terminal at all), the `||` sets INTERACTIVE=false. Uses `true`, not `:` —
# POSIX mandates that a redirection error on a *special* built-in (`:` is
# one) unconditionally kills a non-interactive shell script, bypassing
# `set -e`/`||` entirely; `true` is an ordinary command, so its redirection
# failure is just a normal non-zero status the `||` can catch.
INTERACTIVE=true
{ true < /dev/tty; } 2>/dev/null || INTERACTIVE=false

# tty_out/tty_prompt: write straight to the terminal device, bypassing this
# script's own stdout. That keeps stdout free to carry only the final
# result (the selection file path) back to whoever called this script via
# `$(...)`, even while stdin is something else entirely (a curl pipe).
#######################################
# Print a line straight to the controlling terminal.
# Globals:
#   None
# Arguments:
#   $*: message to print
# Outputs:
#   Writes <msg> to /dev/tty (not STDOUT).
# Returns:
#   None
#######################################
tty_out() { printf '%s\n' "$*" > /dev/tty; }
#######################################
# Print a prompt straight to the controlling terminal, no trailing newline.
# Globals:
#   None
# Arguments:
#   $*: prompt text to print
# Outputs:
#   Writes <text> to /dev/tty (not STDOUT), with no trailing newline.
# Returns:
#   None
#######################################
# No trailing newline: prompt stays on the input line.
tty_prompt() { printf '%s' "$*" > /dev/tty; }

# ANSI escape building blocks for lt_arrow_menu below, and the raw-mode
# safety net: _LT_RAW_STTY holds the terminal's pre-raw-mode settings
# whenever a menu is actually mid-read, so the EXIT trap (registered after
# OUT_FILE below) can restore it even if a signal interrupts mid-keypress -
# without this, Ctrl-C during a menu would leave the terminal stuck in raw/
# no-echo mode (typing invisible, no line editing) for the rest of the
# session. `printf '\033[...'` (not `tput`) - this repo has no other tput
# dependency and printf's escapes are simpler to reason about here.
_LT_ESC="$(printf '\033')"
_LT_CYAN="$(printf '\033[36m')"
_LT_GREEN="$(printf '\033[32m')"
_LT_DIM="$(printf '\033[2m')"
_LT_BOLD="$(printf '\033[1m')"
_LT_RESET="$(printf '\033[0m')"
_LT_RAW_STTY=""
# _LT_RAW_STTY_FILE (TASK-166): _LT_RAW_STTY alone can't reach the EXIT trap
# below when lt_arrow_menu() runs inside a `$(...)` command substitution -
# every call site does exactly that to capture its return value, and POSIX
# forks a subshell for command substitution, so the assignment lt_arrow_menu
# makes when entering raw mode never propagates back to this process. A
# Ctrl-C during any menu left the terminal raw/no-echo forever as a result.
# Persist the pre-raw-mode stty settings to a $$-scoped file instead - same
# pattern as LT_VERSION_LIST_UNREACHABLE_FILE below, which crosses the exact
# same subshell boundary for the same reason.
_LT_RAW_STTY_FILE="${TMPDIR:-/tmp}/langtoolchain-raw-stty.$$"
#######################################
# Restore the terminal's pre-raw-mode stty settings, if any were saved.
# Globals:
#   _LT_RAW_STTY
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   Always 0 (see prose above — this runs from the EXIT trap and must never
#   override the script's actual exit status).
#######################################
lt_restore_raw_stty() {
  # Always exits 0 - this runs from the EXIT trap, where a failing command
  # would otherwise override the script's actual exit status (the whole
  # point of `$SUCCESS || rm -f "$OUT_FILE"` right after it is to preserve
  # that status, which a failure here would clobber). The common case -
  # nothing was ever put into raw mode - is not an error, just a no-op.
  if [ -n "$_LT_RAW_STTY" ]; then
    stty "$_LT_RAW_STTY" < /dev/tty 2>/dev/null || true
  elif [ -f "$_LT_RAW_STTY_FILE" ]; then
    # The common case in practice (TASK-166): _LT_RAW_STTY is always empty
    # here because it was only ever set inside lt_arrow_menu()'s command-
    # substitution subshell, never in this process - the file is what
    # actually crossed that boundary.
    stty "$(cat "$_LT_RAW_STTY_FILE")" < /dev/tty 2>/dev/null || true
  fi
  rm -f "$_LT_RAW_STTY_FILE"
}

# lt_arrow_menu <question> <default-index 1-based> <option...> (m-10/
# TASK-106 v2): a real arrow-key-navigable menu, drawn and read straight
# against /dev/tty — Up/Down moves the highlighted option, Enter confirms,
# a bare digit jumps straight to that option. Redraws the whole block in
# place (cursor-up + reprint) on every keypress, clack-prompts-style, then
# collapses it to a single "✔ <question> <chosen>" summary line once
# confirmed. Prints the chosen option's 1-based index to stdout.
#
# Reads one raw keypress at a time via `stty -icanon -echo` (put the tty in
# non-canonical mode) + `dd bs=1 count=1` (read exactly one byte) — NOT
# bash's `read -n1`, which POSIX sh has no equivalent of and dash flatly
# rejects ("Illegal option -n"). `stty`/`dd` are ordinary external commands
# with no such gap, so this works identically under dash — verified against
# a real dash process over an actual pty (not just bash) before landing.
# Escape sequences for arrow keys are 3 bytes (ESC, `[`, `A`/`B`); a lone
# byte that isn't ESC is either Enter (empty read) or a digit shortcut.
#
# lt_draw_arrow_menu <question> <option...>: prints one frame of the menu
# lt_arrow_menu below draws/redraws. Reads $selected as a shell dynamic-
# scope variable rather than taking it as a parameter — every caller is
# lt_arrow_menu itself, which always has `selected` set as a local right
# before calling this, and POSIX sh functions see their caller's locals
# (there's no lexical closure to fake otherwise). Split out to a top-level
# function instead of nested inside lt_arrow_menu purely so it's defined
# once, not redefined on every single lt_arrow_menu call.
#######################################
# Print one frame of the arrow-key menu, highlighting the selected option.
# Globals:
#   _LT_CYAN, _LT_BOLD, _LT_DIM, _LT_RESET (read)
#   selected (read — not a true global; a caller-set local visible here via
#     POSIX dynamic scoping, see prose above)
# Arguments:
#   $1: question text
#   $2..: option labels
# Outputs:
#   Writes the question line and each option line (highlighted if selected)
#   to /dev/tty.
# Returns:
#   None
#######################################
lt_draw_arrow_menu() {
  local i opt
  tty_out "${_LT_CYAN}?${_LT_RESET} $1"
  shift
  i=1
  for opt in "$@"; do
    if [ "$i" -eq "$selected" ]; then
      tty_out "  ${_LT_CYAN}>${_LT_RESET} ${_LT_BOLD}$opt${_LT_RESET}"
    else
      tty_out "    ${_LT_DIM}$opt${_LT_RESET}"
    fi
    i=$((i + 1))
  done
}

# lt_read_menu_key <option-count> (m-8): reads exactly one raw keypress
# from /dev/tty (caller must already have put the tty in raw mode - this
# just does the read) and classifies it: UP/DOWN for an arrow escape
# sequence, ENTER for a bare Enter, a digit string for a valid 1..n
# shortcut, or OTHER for anything else (caller ignores it and reads again).
# Split out of lt_arrow_menu (m-8, extracted 2026 refactor pass) so "what
# does this keypress mean" has its own name, separate from "what do I do
# about it" (still lt_arrow_menu's job) and "how do I redraw" (already its
# own lt_draw_arrow_menu).
#######################################
# Read and classify exactly one raw keypress from /dev/tty.
# Globals:
#   _LT_ESC
# Arguments:
#   $1: n — valid option count, for classifying digit shortcuts
# Outputs:
#   Writes UP, DOWN, ENTER, a digit string (1..n), or OTHER to STDOUT.
# Returns:
#   None
#######################################
lt_read_menu_key() {
  local n="$1" key1 key2 key3
  key1="$(dd if=/dev/tty bs=1 count=1 2>/dev/null)"
  if [ "$key1" = "$_LT_ESC" ]; then
    key2="$(dd if=/dev/tty bs=1 count=1 2>/dev/null)"
    key3="$(dd if=/dev/tty bs=1 count=1 2>/dev/null)"
    case "$key2$key3" in
      '[A') echo UP ;;
      '[B') echo DOWN ;;
      *) echo OTHER ;;
    esac
  elif [ -z "$key1" ]; then
    echo ENTER
  else
    case "$key1" in
      [1-9]) if [ "$key1" -le "$n" ]; then echo "$key1"; else echo OTHER; fi ;;
      *) echo OTHER ;;
    esac
  fi
}

# lt_collapse_menu <question> <chosen-label> <option-count> (m-8): clears
# the question+options block lt_draw_arrow_menu drew (option-count + 1
# lines) and replaces it with a single confirmed "✔ <question> <chosen>"
# summary line. Split out of lt_arrow_menu for the same reason as
# lt_read_menu_key above - "how do I finalize" is a distinct concern from
# "how do I read input" and "how do I redraw".
#######################################
# Clear the drawn menu block and print a single confirmed summary line.
# Globals:
#   _LT_ESC, _LT_GREEN, _LT_DIM, _LT_RESET (read)
# Arguments:
#   $1: question text
#   $2: chosen — the chosen option's label
#   $3: n — option count (how many lines to clear)
# Outputs:
#   Writes cursor-movement/clear escape sequences, then "✔ <question>
#   <chosen>", to /dev/tty.
# Returns:
#   None
#######################################
lt_collapse_menu() {
  local question="$1" chosen="$2" n="$3" j=0
  printf '%s[%dA' "$_LT_ESC" "$((n + 1))" > /dev/tty
  while [ "$j" -le "$n" ]; do
    printf '%s[2K\n' "$_LT_ESC" > /dev/tty
    j=$((j + 1))
  done
  printf '%s[%dA' "$_LT_ESC" "$((n + 1))" > /dev/tty
  tty_out "${_LT_GREEN}✔${_LT_RESET} $question ${_LT_DIM}$chosen${_LT_RESET}"
}

# Falls back to the plain always-worked numbered prompt if raw mode isn't
# available at all (`stty -g` failing to read the tty's own attributes —
# some unusual terminal) - still fully interactive, just no arrow keys.
#######################################
# Run an arrow-key (or numbered-prompt fallback) menu and return the choice.
# Globals:
#   _LT_ESC (read)
#   _LT_RAW_STTY (written)
# Arguments:
#   $1: question text
#   $2: default 1-based selected index
#   $3..: option labels
# Outputs:
#   Draws/redraws the menu and the final collapsed summary line to
#   /dev/tty. Writes the chosen option's 1-based index to STDOUT.
# Returns:
#   None
#######################################
lt_arrow_menu() {
  local question="$1" selected="$2" n old_stty action i opt chosen
  shift 2
  n=$#

  old_stty="$(stty -g < /dev/tty 2>/dev/null)" || {
    tty_out "$question"
    i=1
    for opt in "$@"; do
      if [ "$i" -eq "$selected" ]; then
        tty_out "  $i) $opt (default)"
      else
        tty_out "  $i) $opt"
      fi
      i=$((i + 1))
    done
    tty_prompt "  > "
    read -r action < /dev/tty || action=""
    lt_valid_menu_choice "$action" "$n" && selected="$action"
    printf '%s\n' "$selected"
    return
  }

  lt_draw_arrow_menu "$question" "$@"
  # Tracked globally so the safety-net EXIT trap (see below) can restore
  # the terminal even if this function never reaches its own restore below
  # - a signal arriving mid-read would otherwise leave the tty stuck in
  # raw/no-echo mode (invisible typing) for the rest of the session.
  _LT_RAW_STTY="$old_stty"
  # TASK-166: also persist to the $$-scoped file - this assignment above
  # only lives in this command-substitution subshell (see _LT_RAW_STTY_FILE's
  # own comment), so the parent's EXIT trap needs the file to recover it.
  printf '%s\n' "$old_stty" > "$_LT_RAW_STTY_FILE"
  stty -icanon -echo min 1 time 0 < /dev/tty

  while :; do
    action="$(lt_read_menu_key "$n")"
    case "$action" in
      UP)
        if [ "$selected" -gt 1 ]; then
          selected=$((selected - 1))
        else
          selected=$n
        fi
        ;;
      DOWN)
        if [ "$selected" -lt "$n" ]; then
          selected=$((selected + 1))
        else
          selected=1
        fi
        ;;
      ENTER)
        stty "$old_stty" < /dev/tty
        _LT_RAW_STTY=""
        rm -f "$_LT_RAW_STTY_FILE"
        break
        ;;
      [1-9])
        selected="$action"
        stty "$old_stty" < /dev/tty
        _LT_RAW_STTY=""
        rm -f "$_LT_RAW_STTY_FILE"
        break
        ;;
    esac
    printf '%s[%dA' "$_LT_ESC" "$((n + 1))" > /dev/tty
    lt_draw_arrow_menu "$question" "$@"
  done

  i=1
  chosen=""
  for opt in "$@"; do
    [ "$i" -eq "$selected" ] && chosen="$opt"
    i=$((i + 1))
  done
  lt_collapse_menu "$question" "$chosen" "$n"

  printf '%s\n' "$selected"
}

# ask_yes_no <label> (m-10/TASK-106): arrow-key Yes/No menu. Returns success
# for yes, failure for no.
#######################################
# Ask a Yes/No question via the arrow-key menu.
# Globals:
#   None
# Arguments:
#   $1: label — the question text
# Outputs:
#   Draws the menu to /dev/tty (via lt_arrow_menu); nothing to this
#   function's own STDOUT.
# Returns:
#   0 if the user chose "Yes"; 1 if "No".
#######################################
ask_yes_no() {
  [ "$(lt_arrow_menu "$1" 1 "Yes" "No")" = "1" ]
}

# ask_version <plugin> <default> (m-15/TASK-129.1, decision-17): arrow-key
# menu over the plugin's actual installable version list. Replaces m-10/
# TASK-106's default-vs-free-text-input menu entirely - that comment used
# to explain why a live version browser wasn't reliable from phase 0 (asdf/
# the plugin not guaranteed to exist yet); decision-15 already established
# every source this repo fetches from (language-official APIs/indexes) is
# reachable from phase 0 without asdf at all, which is exactly what makes
# a real list-based menu possible here now.
#
# lt_resolve_version_list() (fresh cache -> live fetch -> failure, with a
# session-wide circuit breaker so one offline plugin doesn't make every
# later one pay its own full LT_VERSION_FETCH_TIMEOUT) and
# lt_version_menu_options() (caps/dedupes the fetched list against
# <default> into the menu's option labels) both live in lib.sh, not here -
# unlike this function, neither touches /dev/tty, so lib.sh's Include-based
# shellspec pattern (see spec/lib_spec.sh) can unit-test them directly; no
# other scripts/install/*.sh script is tested that way (they all run with
# top-level side effects, so specs only ever exec them as a subprocess -
# see spec/select_spec.sh's own comment on why the interactive parts of
# this exact script aren't covered).
#
# <default> is the same fully-resolved value callers already had before
# this task (lt_resolve_default_version() in lib.sh, unchanged) - it's
# always shown as the first, highlighted option, never re-derived from the
# list fetched here (see decision-17: merging that into a single fetch was
# considered and rejected, since nodejs's default is the "lts" alias,
# which never appears as a member of its own version list).
#
# If the list can't be resolved at all (offline, cache miss + live fetch
# failure, unmapped plugin), <default> is still the only option ever
# offered - decision-17's replacement for the old free-text path is a
# single-option confirm through this exact same widget, not a separate
# manual-entry prompt. Installation is never blocked by a list-fetch
# failure either way.
#######################################
# Ask for a version via the real-version-list arrow-key menu.
# Globals:
#   None
# Arguments:
#   $1: plugin — asdf plugin name (used to fetch the version list)
#   $2: default — the already-resolved default version string to offer
# Outputs:
#   Draws the menu to /dev/tty (via lt_arrow_menu). Writes the chosen
#   version string to STDOUT.
# Returns:
#   None
#######################################
# lt_version_walkthrough <default> (TASK-168): reads option labels one per
# line on stdin (lt_version_menu_options()'s output - same list ask_version
# always builds) and walks through them in order against /dev/tty: bare
# Enter picks the current candidate, anything else + Enter moves to the
# next one. This is ask_version()'s no-raw-mode counterpart to
# lt_arrow_menu() - no number or version string is ever typed, only Enter
# vs. not-Enter, so it needs no lt_valid_menu_choice()-style validation.
# Exhausting every candidate without an Enter (the user skipped all of
# them) falls back to <default>, same "installation is never blocked"
# guarantee decision-17 already established for the arrow-menu's own
# failure path.
#######################################
# Walk through version candidates one at a time; bare Enter selects.
# Globals:
#   None
# Arguments:
#   $1: default — the already-resolved default version string
# Outputs:
#   Draws each "<label> 사용?" prompt to /dev/tty. Writes the chosen
#   version string to STDOUT.
# Returns:
#   None
#######################################
lt_version_walkthrough() {
  local default="$1" label i=1 reply
  while IFS= read -r label; do
    tty_prompt "  ${label} 사용? [Enter=예, 다른 키+Enter=다음] > "
    read -r reply < /dev/tty || reply=""
    if [ -z "$reply" ]; then
      # Option 1 always carries the "(default)" suffix cosmetically added
      # by lt_version_menu_options() - print the bare $default instead of
      # that decorated label, same convention as the arrow-menu path below.
      if [ "$i" -eq 1 ]; then
        printf '%s\n' "$default"
      else
        printf '%s\n' "$label"
      fi
      return
    fi
    i=$((i + 1))
  done
  printf '%s\n' "$default"
}

ask_version() {
  local plugin="$1" default="$2" list_tmp options_tmp opt chosen i
  list_tmp="$(mktemp)"
  if ! lt_resolve_version_list "$plugin" > "$list_tmp"; then
    tty_out "  (couldn't fetch $plugin's version list - offering $default only)"
  fi

  options_tmp="$(mktemp)"
  lt_version_menu_options "$default" < "$list_tmp" > "$options_tmp"
  rm -f "$list_tmp"

  # TASK-168: probe raw-mode capability ourselves, ahead of lt_arrow_menu -
  # when it's not available, skip that widget entirely (rather than letting
  # it degrade into its own generic numbered-prompt fallback, which is
  # shared with ask_yes_no()/the scope prompt and still requires typing a
  # digit) and walk the candidates one at a time instead, never typing a
  # number or version string.
  if stty -g < /dev/tty > /dev/null 2>&1; then
    # Load the option labels into this function's own positional params
    # (fd redirection, not a pipe, so this loop runs in the current shell -
    # same reasoning as the EACH_TOOL_TMP/fd-3 loop further below).
    set --
    while IFS= read -r opt; do
      set -- "$@" "$opt"
    done < "$options_tmp"
    rm -f "$options_tmp"

    chosen="$(lt_arrow_menu "Version:" 1 "$@")"
    i=1
    for opt in "$@"; do
      if [ "$i" -eq "$chosen" ]; then
        # Option 1 always carries the "(default)" suffix cosmetically added
        # by lt_version_menu_options() above - print the bare $default
        # instead of that decorated label.
        if [ "$i" -eq 1 ]; then
          printf '%s\n' "$default"
        else
          printf '%s\n' "$opt"
        fi
        break
      fi
      i=$((i + 1))
    done
  else
    tty_out "  Version candidates:"
    lt_render_version_table < "$options_tmp" > /dev/tty
    lt_version_walkthrough "$default" < "$options_tmp"
    rm -f "$options_tmp"
  fi
}

# Create the file the selection will be written to. `-t` gives it a
# predictable prefix under the system temp dir (e.g. /tmp on Linux,
# $TMPDIR on macOS) with a random unique suffix.
OUT_FILE="$(mktemp -t langtoolchain-selection)"
readonly OUT_FILE
# Clean up on every exit path except the one deliberate success below.
# Emptiness alone isn't a reliable signal here: the interactive scope
# prompt can `die` (e.g. on an invalid --local directory) *after*
# language selections are already written to $OUT_FILE, which would look
# "successful" to an emptiness check and leak the file. SUCCESS is only
# ever set true right before the two real `echo "$OUT_FILE"` handoffs.
SUCCESS=false
# The version-list circuit breaker marker (m-15/TASK-129.2, decision-17,
# see LT_VERSION_LIST_UNREACHABLE_FILE's own comment in lib.sh) is cleaned
# up unconditionally, unlike $OUT_FILE - it's scoped to this one process
# ($$-named) regardless of whether the run ends up succeeding, so there's
# nothing to preserve on any exit path. A no-op `rm -f` if ask_version()
# was never called at all (--all/non-interactive) or never hit a fetch
# failure.
trap 'lt_restore_raw_stty; $SUCCESS || rm -f "$OUT_FILE"; \
  rm -f "$LT_VERSION_LIST_UNREACHABLE_FILE"' EXIT

# Non-interactive session, or the caller explicitly asked for everything:
# skip the language menu entirely and use the default config as-is. Scope
# still comes from --local if given; otherwise there's no tty to ask, so
# it defaults to global (scope_line() already does this when SCOPE="").
if ! $INTERACTIVE || $SELECT_ALL; then
  # Only announce this when it's the SILENT fallback (no tty, no --all) -
  # a caller who explicitly passed --all already knows what they asked for.
  # Without this, a CI run with no flags at all installs every language with
  # no indication that's what just happened (found during a UX pass,
  # m-6/TASK-95.1). To stderr, not tty_out - there may be no /dev/tty to
  # write to at all in this exact branch, and stdout is reserved for the
  # OUT_FILE path handoff below.
  if ! $INTERACTIVE && ! $SELECT_ALL; then
    echo "No controlling terminal detected - installing every language" \
      "in $DEFAULT_CONFIG (same as --all)." >&2
  fi
  write_with_scope "$DEFAULT_CONFIG" "$OUT_FILE"
  SUCCESS=true
  echo "$OUT_FILE"   # the one line of "real" stdout output
  exit 0
fi

# Interactive path: start the selection file empty and build it up below.
: > "$OUT_FILE"

tty_out ""
tty_out "== Select languages to install (Enter = yes) =="

# fd 3, not stdin — see scripts/install/02_install_plugins.sh for why
# (the /dev/tty reads below are already redirected per-command so they're
# safe either way, but fd 3 keeps every loop in this codebase consistent).
# `each_tool` prints "plugin version" pairs for every language in the
# default config; POSIX sh has no process substitution (`<(...)` is a
# bash/ksh/zsh extension), so this writes each_tool's output to a temp
# file first and reads that on fd 3 instead of the loop's own stdin (fd 0).
EACH_TOOL_TMP="$(mktemp)"
readonly EACH_TOOL_TMP
each_tool "$DEFAULT_CONFIG" > "$EACH_TOOL_TMP"

# Companion plugins (m-7/TASK-100, e.g. pnpm for nodejs, gradle for java —
# see lt_companion_for_plugin() in lib.sh) don't get their own top-level
# "Install X?" question here: asked alone, out of context, "Install pnpm
# (pnpm)? [Y/n]" gives no hint it's tied to nodejs. Instead they're offered
# as a follow-up right after their parent is accepted, below. Precomputed
# once here (plain stdin, not fd 3 - this small loop doesn't touch
# /dev/tty) so the main loop can skip them on sight.
ALL_COMPANIONS=""
while read -r each_plugin _each_version; do
  companion="$(lt_companion_for_plugin "$each_plugin")"
  [ -n "$companion" ] && ALL_COMPANIONS="$ALL_COMPANIONS $companion"
done < "$EACH_TOOL_TMP"

# lt_forget_language_lines <plugin> (TASK-165, decision-21): remove
# <plugin>'s line (and its companion's, if any) from $OUT_FILE. Used only
# when the user backs up into a language that was already answered, so
# lt_offer_language() can re-record it without leaving a stale duplicate
# line from the answer being reconsidered.
#######################################
# Remove a plugin's (and its companion's) recorded line from $OUT_FILE.
# Globals:
#   OUT_FILE (read, written)
# Arguments:
#   $1: plugin — asdf plugin name whose line(s) to drop
# Outputs:
#   None
# Returns:
#   None
#######################################
lt_forget_language_lines() {
  local plugin="$1" forget forget_tmp p v keep sp
  forget="$plugin $(lt_companion_for_plugin "$plugin")"
  forget_tmp="$(mktemp)"
  : > "$forget_tmp"
  while read -r p v; do
    keep=true
    for sp in $forget; do
      [ "$p" = "$sp" ] && keep=false
    done
    $keep && printf '%s %s\n' "$p" "$v" >> "$forget_tmp"
  done < "$OUT_FILE"
  mv "$forget_tmp" "$OUT_FILE"
}

# lt_offer_language <plugin> <default-version> <allow-back> (m-8, TASK-165/
# decision-21): asks whether to install one language, its version, then
# loops through that language's companion tool(s) (if any). Extracted from
# the loop below so the loop itself reads as "for each candidate language,
# offer it" instead of carrying the full per-language interaction inline.
#
# <allow-back> ("true"/"false") controls whether a third "◀ 뒤로" option is
# offered on the language's own yes/no question - only when there is a
# previous language to go back to (decision-21 scopes back-navigation to
# whole languages, not the finer version/companion sub-steps within one).
#######################################
# Offer to install one language (and its companion tool(s), if accepted).
# Globals:
#   OUT_FILE (written)
#   EACH_TOOL_TMP (read)
# Arguments:
#   $1: plugin — asdf plugin name
#   $2: default_version — this plugin's static default version
#   $3: allow_back — "true" to offer a back option, "false" to omit it
# Outputs:
#   Draws prompts to /dev/tty (via tty_out/lt_arrow_menu/ask_version).
#   Appends one "<plugin> <version>" line to $OUT_FILE per accepted
#   language or companion.
# Returns:
#   0 to move forward (whether or not the language was accepted); 1 if the
#   user chose to go back to the previous language instead
#######################################
lt_offer_language() {
  local plugin="$1" default_version="$2" allow_back="$3"
  local cmd version companion choice
  local companion_default companion_version
  # Just for a friendlier prompt line, e.g. "nodejs (node)".
  cmd="$(binary_for_plugin "$plugin")"
  tty_out ""
  if [ "$allow_back" = "true" ]; then
    choice="$(lt_arrow_menu "Install $plugin ($cmd)?" 1 \
      "Yes" "No" "◀ 뒤로 (이전 언어 다시 선택)")"
  else
    choice="$(lt_arrow_menu "Install $plugin ($cmd)?" 1 "Yes" "No")"
  fi
  [ "$choice" = "3" ] && return 1

  if [ "$choice" = "1" ]; then
    # Fetched here, lazily - only for a language the user just said yes to,
    # never eagerly for all of them up front (m-12/TASK-119.2's fetch-timing
    # decision: waiting on this alongside a prompt the user is already
    # answering is imperceptible; fetching for languages they end up
    # declining would just be wasted network calls).
    version="$(ask_version "$plugin" \
      "$(lt_resolve_default_version "$plugin" "$default_version")")"

    # Record this language/version as one line of the selection file.
    printf '%s %s\n' "$plugin" "$version" >> "$OUT_FILE"

    # Offer this language's companion(s), if it has any AND the config file
    # actually carries a default version for it (a config file with no
    # companion line - e.g. this repo's own custom TOOL_VERSIONS_FILE users
    # can pass - has nothing to offer, so silently skip rather than
    # prompting for a version with no default).
    for companion in $(lt_companion_for_plugin "$plugin"); do
      companion_default="$(awk -v p="$companion" \
        '$1 == p { print $2; exit }' "$EACH_TOOL_TMP")"
      [ -n "$companion_default" ] || continue
      if ask_yes_no "  Also install $companion (companion to $plugin)?"; then
        companion_version="$(ask_version "$companion" \
          "$(lt_resolve_default_version "$companion" "$companion_default")")"
        printf '%s %s\n' "$companion" "$companion_version" >> "$OUT_FILE"
      fi
    done
  fi
  return 0
}

# Language list as one flat positional-parameter list ("plugin1" "ver1"
# "plugin2" "ver2" ...) instead of a stream read in place (m-8's original
# `while read <&3` loop) - TASK-165/decision-21's back-navigation needs to
# step the index backward, which a single forward-only stream read can't
# do. Built inside a function so `set --` only touches this function's own
# "$@", not this script's own CLI-argument positional parameters.
#######################################
# Walk the candidate language list, offering each in turn; supports going
# back to the previous language (decision-21).
# Globals:
#   EACH_TOOL_TMP (read), ALL_COMPANIONS (read), OUT_FILE (read/written via
#   lt_offer_language/lt_forget_language_lines)
# Arguments:
#   None
# Outputs:
#   See lt_offer_language.
# Returns:
#   None
#######################################
lt_run_language_loop() {
  local total i plugin default_version allow_back prev_plugin
  set --
  while read -r plugin default_version; do
    # Companion plugin: handled as a follow-up to its parent, not here.
    case " $ALL_COMPANIONS " in *" $plugin "*) continue ;; esac
    set -- "$@" "$plugin" "$default_version"
  done < "$EACH_TOOL_TMP"
  total=$(($# / 2))

  i=1
  while [ "$i" -le "$total" ]; do
    plugin="$(lt_nth_arg $(((i - 1) * 2 + 1)) "$@")"
    default_version="$(lt_nth_arg $(((i - 1) * 2 + 2)) "$@")"
    if [ "$i" -gt 1 ]; then allow_back=true; else allow_back=false; fi

    if lt_offer_language "$plugin" "$default_version" "$allow_back"; then
      i=$((i + 1))
    else
      # Went back: the language being left behind never got as far as
      # writing to $OUT_FILE (BACK only fires on its own first question),
      # but the previous language it's returning to already did - forget
      # that so it can be answered again without leaving a stale duplicate.
      prev_plugin="$(lt_nth_arg $(((i - 2) * 2 + 1)) "$@")"
      lt_forget_language_lines "$prev_plugin"
      i=$((i - 1))
    fi
  done
}

lt_run_language_loop
rm -f "$EACH_TOOL_TMP"

# `-s` = file exists and is non-empty. If the user answered "n" to every
# single language, there's nothing to install — stop here instead of
# silently proceeding with an empty plan.
if [ ! -s "$OUT_FILE" ]; then
  tty_out ""
  tty_out "No languages selected. Cancelling installation."
  exit 1
fi

# Recap what was selected before asking for final confirmation.
tty_out ""
tty_out "== Install list =="
while read -r plugin version; do
  tty_out "  $plugin  $version"
done < "$OUT_FILE"
tty_out ""

# Ask where to pin these versions, unless --local[=DIR] already decided it.
if [ -z "$SCOPE" ]; then
  if [ "$(lt_arrow_menu "Pin these versions:" 1 "Globally" \
    "Only in this directory")" = "2" ]; then
    tty_prompt "  Which directory? [default: current directory] > "
    read -r scope_dir_answer < /dev/tty || scope_dir_answer=""
    SCOPE_DIR="$(resolve_scope_dir "${scope_dir_answer:-$(pwd)}")"
    SCOPE="local"
  else
    SCOPE="global"
  fi
fi

if ! $AUTO_YES; then
  tty_out ""
  if ! ask_yes_no "Install?"; then
    tty_out "Cancelled."
    exit 1
  fi
fi

# Prepend the scope line now that it's finally settled (flag or prompt).
SCOPE_TMP="$(mktemp)"
readonly SCOPE_TMP
write_with_scope "$OUT_FILE" "$SCOPE_TMP"
mv "$SCOPE_TMP" "$OUT_FILE"

# The ONLY thing written to real stdout: the path main.sh should read the
# final selection from.
SUCCESS=true
echo "$OUT_FILE"
