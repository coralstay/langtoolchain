#!/usr/bin/env sh
# Shared utilities sourced by the phase scripts under scripts/install/ and
# scripts/uninstall/. Pure functions only — sourcing this file has no side
# effects, so any phase script can source it standalone, in any order,
# without depending on another phase script having run first.
#
# Written for POSIX sh (TASK-71/72) — no [[ ]], no arrays, no BASH_REMATCH,
# no other bash-only syntax. `local` is the one non-POSIX-standard
# exception kept deliberately (see TASK-71): it's supported by every real
# POSIX-compliant shell this tool targets (dash included), and dropping it
# would mean every function falls back to polluting the global namespace.

# DRY_RUN is exported by main.sh before it launches each phase script as a
# child process. `:-false` makes this file safe to source on its own too
# (e.g. while testing a single phase by hand) — it just defaults to "do it
# for real".
DRY_RUN="${DRY_RUN:-false}"

# ---- Shared constants ----
# Literal values (paths, filenames, package lists, rc-file search/write
# patterns) that used to be typed independently into multiple phase
# scripts, which let them silently drift out of sync with each other (see
# e.g. the Intel-Mac sqlite PATH bug fixed alongside TASK-61, or the
# BSD-sed java-hook bug fixed by TASK-56). Each entry below is its own
# clearly-separated block so another branch adding one more entry here
# merges cleanly. This section is data only — it holds no control flow,
# and no phase script's own logic is meant to move here.

# Homebrew formulas needed to compile Python's (and friends') C extensions.
# Single source of truth for scripts/install/03_install_system_deps.sh,
# scripts/uninstall/04_remove_system_deps.sh, and ensure_build_flags() below
# (which only needs the openssl/readline/sqlite3/zlib subset — see there).
readonly LT_BUILD_DEPS="openssl readline sqlite3 xz zlib tcl-tk"

# lt_homebrew_prefix (TASK-61): prints Homebrew's install prefix for the
# CPU architecture this script is running on right now. Apple Silicon and
# Intel Macs use two different fixed Homebrew locations; every script that
# needs a Homebrew-rooted path (the brew binary itself, a keg-only
# formula's bin dir, etc.) should compute it by calling this function
# instead of re-typing its own `uname -m` case — that duplication is what
# let the sqlite PATH line go stale to an Apple-Silicon-only path on Intel
# Macs.
#######################################
# Print Homebrew's install prefix for the current CPU architecture.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes the Homebrew prefix path to STDOUT.
# Returns:
#   None
#######################################
lt_homebrew_prefix() {
  case "$(uname -m)" in
    arm64) echo "/opt/homebrew" ;;  # Apple Silicon
    *)     echo "/usr/local" ;;     # Intel
  esac
}

# LT_ASDF_DATA_DIR_NAME / LT_ASDF_DATA_DIR_DEFAULT (TASK-62): asdf's own
# default data directory when the caller's environment hasn't set
# ASDF_DATA_DIR — this is where every asdf-managed download, plugin, and
# shim actually lives. Split into a bare directory NAME and the expanded
# DEFAULT path so both shapes are available: scripts doing real filesystem
# work (ensure_asdf_on_path's fallback, uninstall's delete target) want the
# expanded absolute path; a script writing a line into an rc file for a
# *future* shell to evaluate wants the bare name so it can keep `$HOME`
# itself literal (unexpanded) in what gets written, exactly like the
# original code did — resolving $HOME at write time instead would bake in
# whatever $HOME happened to be during install rather than at each future
# shell's own startup.
readonly LT_ASDF_DATA_DIR_NAME=".asdf"
readonly LT_ASDF_DATA_DIR_DEFAULT="$HOME/$LT_ASDF_DATA_DIR_NAME"

# lt_asdf_data_dir: prints the effective asdf data directory — a live
# ASDF_DATA_DIR override if the caller's environment already has one, else
# the default above. Split out of ensure_asdf_on_path() (which also exports
# it and touches PATH) so callers that only need the *value* — teardown
# checks that must NOT put asdf back on PATH — don't have to re-type the
# same "${ASDF_DATA_DIR:-$LT_ASDF_DATA_DIR_DEFAULT}" fallback themselves.
#######################################
# Print the effective asdf data directory.
# Globals:
#   ASDF_DATA_DIR
#   LT_ASDF_DATA_DIR_DEFAULT
# Arguments:
#   None
# Outputs:
#   Writes the effective asdf data directory path to STDOUT.
# Returns:
#   None
#######################################
lt_asdf_data_dir() {
  echo "${ASDF_DATA_DIR:-$LT_ASDF_DATA_DIR_DEFAULT}"
}

# LT_RC_FILE_ZSH / LT_RC_FILE_BASH / LT_RC_FILE_BASH_INTERACTIVE /
# LT_KNOWN_RC_FILES (TASK-66): the rc filenames (bare, relative to $HOME)
# this tool knows how to write into or clean up.
#
# detect_rc_file() (below) picks exactly ONE of these at install time,
# based on the current $SHELL — the installer only ever writes into the rc
# file matching whichever shell is actually running it.
#
# uninstall/03_clean_env_vars.sh instead sweeps ALL of LT_KNOWN_RC_FILES:
# the $SHELL active when uninstall runs isn't necessarily the same one that
# was active when install ran, so it can't assume which single file was
# written to and has to check every rc file this tool has ever been able to
# write. This install-picks-one vs. uninstall-sweeps-all asymmetry is
# intentional, not an oversight.
readonly LT_RC_FILE_ZSH=".zshrc"
# macOS Terminal runs login shells.
readonly LT_RC_FILE_BASH=".bash_profile"
# Never picked by detect_rc_file; swept by uninstall only.
readonly LT_RC_FILE_BASH_INTERACTIVE=".bashrc"
readonly LT_KNOWN_RC_FILES="$LT_RC_FILE_ZSH $LT_RC_FILE_BASH \
$LT_RC_FILE_BASH_INTERACTIVE"

# LT_LOCAL_PINS_FILE_NAME (TASK-83): bare filename, under $ASDF_DATA_DIR, of
# the registry 06_set_globals.sh appends a directory to every time it pins
# versions LOCALLY (never globally) to that directory. 01_uninstall_runtimes.sh
# reads it back so a runtime version only ever pinned inside some project
# directory (never in the global ~/.tool-versions) still gets asdf-uninstalled.
# Deliberately lives under $ASDF_DATA_DIR: 05_purge_asdf_core.sh's `rm -rf
# $ASDF_DATA_DIR` deletes this file too, so there's nothing extra to clean up.
readonly LT_LOCAL_PINS_FILE_NAME="langtoolchain-local-pins"

# LT_LOCK_DIR (TASK-84): a single lock shared by install/main.sh and
# uninstall/main.sh, so an install can never run concurrently with another
# install, an uninstall, or itself — all of them mutate the same asdf/
# Homebrew state. `mkdir` is used as the lock primitive (not `flock`, which
# macOS doesn't ship) because directory creation is atomic on every real
# filesystem: at most one concurrent `mkdir LT_LOCK_DIR` can succeed.
# `${LT_LOCK_DIR:-default}`, same override pattern as ASDF_DATA_DIR below:
# lets a test (or an unusual caller) point this somewhere other than the
# real shared path without that being a special case in acquire_lock itself.
LT_LOCK_DIR="${LT_LOCK_DIR:-${TMPDIR:-/tmp}/langtoolchain.lock}"

# LT_REPORT_FILE (m-10/TASK-107): a human-readable audit trail of every
# real change install/uninstall made - what got installed/removed/modified
# and where. Deliberately under $HOME directly, not $ASDF_DATA_DIR (unlike
# LT_LOCAL_PINS_FILE_NAME above) - a `rm -rf $ASDF_DATA_DIR` during
# uninstall would otherwise erase the very history someone might want to
# check right before/after running it. Override-able like LT_LOCK_DIR, so
# tests can point it at a scratch file instead of a real $HOME.
LT_REPORT_FILE="${LT_REPORT_FILE:-$HOME/.langtoolchain-report.log}"

# lt_report <action> <detail>: appends one line to LT_REPORT_FILE. Skipped
# under DRY_RUN by design - a preview run didn't actually change anything,
# so it has nothing real to add to the audit trail.
#######################################
# Append one timestamped audit-trail line to LT_REPORT_FILE.
# Globals:
#   DRY_RUN
#   LT_REPORT_FILE
# Arguments:
#   $1: action label
#   $2: detail text
# Outputs:
#   None to STDOUT/STDERR. Appends "<timestamp> [<action>] <detail>" to
#   LT_REPORT_FILE (skipped entirely under DRY_RUN).
# Returns:
#   None
#######################################
lt_report() {
  [ "$DRY_RUN" = "true" ] && return
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" \
    >> "$LT_REPORT_FILE"
}

# LT_PRIOR_STATE_FILE (m-13/TASK-123, decision-6): records whether asdf/its
# data dir/any plugins already existed on this machine BEFORE this tool
# touched anything, so uninstall (TASK-124) can avoid deleting state it
# didn't create. Deliberately a separate file from LT_REPORT_FILE, not
# just another line in it: that one is a human-readable audit log
# (lt_report's timestamped lines); this one is parsed by uninstall to make
# an actual delete/skip decision, so it needs a stable, parse-only format
# (see lt_snapshot_prior_asdf_state/lt_prior_state_get below) instead of a
# log line's free-text "detail" field. Same $HOME-not-$ASDF_DATA_DIR
# placement as LT_REPORT_FILE and for the identical reason: a `rm -rf
# $ASDF_DATA_DIR` during uninstall must never delete the very file
# uninstall is about to consult to decide whether to run that rm -rf.
LT_PRIOR_STATE_FILE="${LT_PRIOR_STATE_FILE:-$HOME/\
.langtoolchain-prior-asdf-state}"

# lt_snapshot_prior_asdf_state: writes LT_PRIOR_STATE_FILE with whether asdf
# (brew list asdf), its data directory (lt_asdf_data_dir), and any asdf
# plugins already existed, as simple `key=value` lines - not the
# lt_report()-style timestamped log format, since this file's only reader is
# uninstall's own conditional logic (TASK-124.1), not a human. See decision-6
# for the full format writeup.
#
# Must run before ANY phase that could itself install asdf or create its
# data dir (01_bootstrap_asdf.sh) - callers are responsible for that
# ordering (install/main.sh calls this right after language selection,
# before the phase loop starts).
#
# Only ever writes once: if LT_PRIOR_STATE_FILE already exists, a later
# call is necessarily a re-run of install (Ctrl-C recovery, adding more
# languages, etc.) where asdf/its data dir may now contain state THIS tool
# itself created in an earlier run - overwriting the file at that point
# would corrupt the "before this tool touched anything" baseline uninstall
# depends on.
#######################################
# Snapshot whether asdf/its data dir/plugins pre-existed before this tool.
# Globals:
#   DRY_RUN
#   LT_PRIOR_STATE_FILE
# Arguments:
#   None
# Outputs:
#   None to STDOUT. Writes asdf_preexisting/asdf_data_dir/
#   asdf_data_dir_preexisting/asdf_plugins_preexisting key=value lines to
#   LT_PRIOR_STATE_FILE (skipped under DRY_RUN or if the file already
#   exists).
# Returns:
#   None
#######################################
lt_snapshot_prior_asdf_state() {
  [ "$DRY_RUN" = "true" ] && return
  [ -f "$LT_PRIOR_STATE_FILE" ] && return

  # `brew list asdf` below needs `brew` resolvable in THIS process - see
  # ensure_brew_on_path's own comment for why that isn't automatic.
  ensure_brew_on_path

  local asdf_preexisting=false data_dir_preexisting=false plugins="" data_dir
  data_dir="$(lt_asdf_data_dir)"

  brew list asdf >/dev/null 2>&1 && asdf_preexisting=true
  [ -d "$data_dir" ] && data_dir_preexisting=true

  # Only attempt to list plugins when the asdf binary is actually
  # resolvable - matches the task's "asdf 자체가 없으면 생략" requirement
  # instead of letting a missing-command error leak into the snapshot.
  if command -v asdf >/dev/null 2>&1; then
    plugins="$(asdf plugin list 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"
  fi

  {
    printf 'asdf_preexisting=%s\n' "$asdf_preexisting"
    printf 'asdf_data_dir=%s\n' "$data_dir"
    printf 'asdf_data_dir_preexisting=%s\n' "$data_dir_preexisting"
    printf 'asdf_plugins_preexisting=%s\n' "$plugins"
  } > "$LT_PRIOR_STATE_FILE"
}

# lt_prior_state_get <key>: prints the value for <key> from
# LT_PRIOR_STATE_FILE. Fails (nothing printed, exit 1) when the file
# doesn't exist at all OR has no such key - callers (TASK-124.1) must treat
# that failure as "unknown", never silently coerce it to "false", since an
# absent snapshot is exactly the "installed before this feature existed"
# case decision-6 calls out. Deliberately grep+cut, not `.`/`eval` on the
# file - a plain key=value read doesn't need a full shell eval, and this
# avoids that risk entirely even though this file is only ever written by
# this tool itself.
#######################################
# Print the value for <key> from LT_PRIOR_STATE_FILE.
# Globals:
#   LT_PRIOR_STATE_FILE
# Arguments:
#   $1: key to look up
# Outputs:
#   Writes the value to STDOUT on success; nothing on a miss.
# Returns:
#   None
#######################################
lt_prior_state_get() {
  local key="$1" line
  [ -f "$LT_PRIOR_STATE_FILE" ] || return 1
  line="$(grep "^${key}=" "$LT_PRIOR_STATE_FILE" 2>/dev/null | head -n 1)"
  [ -n "$line" ] || return 1
  printf '%s\n' "${line#*=}"
}

# lt_env_var_defs [java_hook_file] (TASK-64): prints one line per rc-file
# entry this tool's installer manages, formatted
# "<search-pattern>|||<placement>|||<line-to-write>" (triple-pipe
# separators, since none of the fields contain them). Bash 3.2 has no
# associative arrays, so this is a flat list of delimited lines, meant to
# be read with `while IFS= read -r def; do ... done < <(lt_env_var_defs
# ...)` — the same shape each_tool() already uses for .tool-versions
# lines, just with a different separator since these lines contain spaces
# of their own.
#
# install/04_configure_shell_env.sh writes each <line-to-write>, guarded
# by <search-pattern>, calling prepend_env_var or append_env_var depending
# on <placement> ("prepend" or "append") — the placement decision lives
# here as data, not as a string the caller has to recognize, so it can't
# go stale independently of the pattern it applies to.
# uninstall/03_clean_env_vars.sh only needs the <search-pattern> field —
# it turns each one into a `sed -E -e '/pattern/d'` expression. Both read
# from this one function instead of each independently retyping the same
# patterns — that exact kind of drift is what caused TASK-56 (BSD sed
# never actually deleting the java-hook line, because uninstall's own copy
# of the pattern used a GNU-only regex extension the install side never
# had to match against). To add a new rc line, add one entry here; both
# install and uninstall pick it up automatically.
#
# The java-hook line's content depends on which shell's variant is in use
# (only install knows this, from the rc file it picked), so the caller
# passes it in as $1; uninstall doesn't pass anything, since it only ever
# reads the search-pattern field of that entry, never the content.
#
# "brew shellenv" is the only "prepend" entry — it must land ahead of the
# asdf shim PATH line, or a same-named Homebrew formula could shadow the
# asdf shim (see prepend_env_var's own comment). Everything else appends.
#######################################
# Print the rc-file entries this tool's installer manages, as data lines.
# Globals:
#   LT_ASDF_DATA_DIR_NAME
# Arguments:
#   $1: (optional) java hook filename to embed in the java-hook rc line
# Outputs:
#   Writes one "<search-pattern>|||<placement>|||<line-to-write>" line per
#   rc-file entry to STDOUT.
# Returns:
#   None
#######################################
lt_env_var_defs() {
  local java_hook_file="${1:-}"
  local homebrew_prefix
  homebrew_prefix="$(lt_homebrew_prefix)"
  printf '%s\n' \
    "brew shellenv|||prepend|||eval \
\"\$($homebrew_prefix/bin/brew shellenv)\"" \
    "export ASDF_DATA_DIR=|||append|||export \
ASDF_DATA_DIR=\"\$HOME/$LT_ASDF_DATA_DIR_NAME\"" \
    "ASDF_DATA_DIR/shims|||append|||export \
PATH=\"\$ASDF_DATA_DIR/shims:\$PATH\"" \
    "set-java-home\.|||append|||. \
\$HOME/$LT_ASDF_DATA_DIR_NAME/plugins/java/$java_hook_file" \
    "opt/sqlite/bin|||append|||export \
PATH=\"$homebrew_prefix/opt/sqlite/bin:\$PATH\"" \
    "LDFLAGS.*openssl|||append|||export LDFLAGS=\"-L\$(brew --prefix \
openssl)/lib -L\$(brew --prefix readline)/lib -L\$(brew --prefix \
sqlite3)/lib -L\$(brew --prefix zlib)/lib\"" \
    "CPPFLAGS.*openssl|||append|||export CPPFLAGS=\"-I\$(brew --prefix \
openssl)/include -I\$(brew --prefix readline)/include -I\$(brew --prefix \
sqlite3)/include -I\$(brew --prefix zlib)/include\"" \
    "PKG_CONFIG_PATH.*openssl|||append|||export PKG_CONFIG_PATH=\"\$(brew \
--prefix openssl)/lib/pkgconfig:\$(brew --prefix \
readline)/lib/pkgconfig:\$(brew --prefix sqlite3)/lib/pkgconfig\""
}

# log <msg>: plain status line to stdout.
#######################################
# Print a plain status line.
# Globals:
#   None
# Arguments:
#   $*: message to print
# Outputs:
#   Writes <msg> to STDOUT.
# Returns:
#   None
#######################################
log()  { printf '%s\n' "$*"; }
# step <msg>: a section header, e.g. "== Phase 3: ... ==", to visually
# separate phases in the console output.
#######################################
# Print a visually separated section header.
# Globals:
#   None
# Arguments:
#   $*: section header text
# Outputs:
#   Writes a blank line then "== <msg> ==" to STDOUT.
# Returns:
#   None
#######################################
step() { printf '\n== %s ==\n' "$*"; }
# die <msg>: print to stderr and exit the whole script immediately.
#######################################
# Print an error message and terminate the script.
# Globals:
#   None
# Arguments:
#   $*: error message
# Outputs:
#   Writes "ERROR: <msg>" to STDERR.
# Returns:
#   Does not return — exits the calling script with status 1.
#######################################
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# run <cmd...>: the dry-run gate. Every command that actually mutates the
# system (brew install, asdf install, rm -rf, ...) goes through this
# instead of being called directly.
#######################################
# Run <cmd...>, or describe it instead when DRY_RUN is set.
# Globals:
#   DRY_RUN
# Arguments:
#   $@: command and arguments to execute
# Outputs:
#   Under DRY_RUN, writes the command line (prefixed "  + ") to STDOUT.
#   Otherwise none of its own — whatever "$@" itself writes passes through.
# Returns:
#   Exit status of "$@" when not under DRY_RUN; 0 under DRY_RUN.
#######################################
run() {
  # Under --dry-run, print what *would* run (prefixed with "+", like `set -x`)
  # instead of running it.
  if [ "$DRY_RUN" = "true" ]; then
    printf '  + %s\n' "$*"
  else
    # "$@" preserves each argument's word boundaries/quoting exactly as the
    # caller passed them — unlike "$*", this is safe for arguments with
    # spaces.
    "$@"
  fi
}

# retry <max_attempts> <delay_seconds> <cmd...> (TASK-88): runs <cmd...>,
# and if it fails, retries with exponential backoff (delay doubles each
# time) up to <max_attempts> total attempts. Meant for genuinely transient
# failures (a network blip mid-download) — not a substitute for fixing a
# real error, which is why it still returns failure (not `|| true`) once
# attempts are exhausted, so the caller decides what that means.
#
# Compose with run(): `retry 3 5 run asdf install "$plugin" "$version"`.
# Under DRY_RUN, run() prints and returns success on the first call, so
# retry's own loop exits immediately too — no repeated dry-run output.
#######################################
# Run <cmd...>, retrying with exponential backoff on failure.
# Globals:
#   None
# Arguments:
#   $1: max_attempts
#   $2: delay_seconds (doubles after each failed attempt)
#   $3..: cmd and its arguments
# Outputs:
#   Writes "(attempt N/max failed, retrying in ...)" progress lines to
#   STDOUT (via log()) between attempts.
# Returns:
#   0 as soon as <cmd...> succeeds; 1 once <max_attempts> is exhausted.
#######################################
retry() {
  local max_attempts="$1" delay="$2" attempt=1
  shift 2
  while true; do
    if "$@"; then
      return 0
    fi
    if [ "$attempt" -ge "$max_attempts" ]; then
      return 1
    fi
    log "  (attempt $attempt/$max_attempts failed, retrying in ${delay}s...)"
    sleep "$delay"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

# lt_run_with_timeout <seconds> <cmd> [args...] (TASK-138.1, decision-10):
# runs <cmd...> under a hard wall-clock timeout, killing it if it hasn't
# finished after <seconds>. This exists because a "started transfer that's
# now slow" guard (curl --max-time, git's http.lowSpeedLimit/lowSpeedTime -
# see lt_upstream_latest_version's python branch below) never even engages
# when the connection blackholes BEFORE any bytes move (DNS/TCP/TLS
# handshake hang) - decision-10 confirms no POSIX-safe fix for that exists
# inside curl/git themselves. `timeout(1)`/`gtimeout(1)` were considered and
# rejected too (decision-10): neither ships on a fresh Mac before Homebrew
# installs GNU coreutils, and this needs to run at phase 0, before Homebrew
# is guaranteed to exist. So this is built from POSIX sh primitives already
# used elsewhere in this file - background job + `wait`, same shape as
# run_phase() above: run <cmd...> in the background, race it against a
# watchdog subshell that sleeps <seconds> and kills it if it's still alive.
#
# A killed-or-not marker file (not a variable) carries the "did we have to
# kill it" fact back out of the watchdog subshell - a background job is a
# separate process, so any variable it set would vanish with it; a file is
# the one thing both sides can see.
#
# <cmd...>'s stdout/stderr are captured to temp files rather than left
# connected straight through to this function's own fds, and only `cat`
# out afterward - deliberately, not just for convenience. If <cmd...>
# itself spawns a child of its own (e.g. `git ls-remote` on an https:// URL
# execs a `git-remote-https` helper to do the actual network work) and this
# function kills only the single PID it tracked, that grandchild can be
# left running as an orphan. A POSIX-portable way to reliably signal a
# whole process tree at once (a job-control process-group kill) turned out
# NOT to be one: `set -m` does make bash put each background job in its own
# process group, but verified by hand that dash does not, so `kill -TERM
# -"$cmd_pid"` would silently fail to reach anything under dash - not an
# option in a codebase that has to run under both. Piping <cmd...>'s output
# straight into a caller's own `$(...)` instead would hit exactly this: a
# pipe's read side only sees EOF once EVERY process holding its write end
# open has exited, so a lingering orphaned grandchild - still holding that
# same fd - would keep the caller's `$(...)` blocked for the orphan's
# entire remaining lifetime, regardless of how fast this function itself
# gives up. A plain file has no such problem: reading one is never blocked
# by some other process still holding it open for writing, so an orphan
# left behind after the timeout can't hang this function's own caller even
# though it may (rarely, harmlessly) still be running somewhere in the
# background. The trade-off is buffering - a caller streaming this in real
# time would now see nothing until <cmd...> finishes or is killed - but no
# call site here needs that; every existing caller already fully captures
# this kind of output via `$(...)` first anyway.
#######################################
# Run <cmd...> under a hard wall-clock timeout, killing it if it overruns.
# Globals:
#   None
# Arguments:
#   $1: seconds — wall-clock timeout
#   $2..: cmd and its arguments
# Outputs:
#   Writes <cmd...>'s captured STDOUT to this function's STDOUT, and its
#   captured STDERR to this function's STDERR.
# Returns:
#   124 if <cmd...> was killed for exceeding the timeout; otherwise
#   <cmd...>'s own exit status.
#######################################
lt_run_with_timeout() {
  local secs="$1"
  shift
  local cmd_pid watchdog_pid status timeout_marker stdout_file stderr_file
  timeout_marker="$(mktemp -u)"
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  "$@" >"$stdout_file" 2>"$stderr_file" &
  cmd_pid=$!

  # `kill -0` sends no signal, it only tests whether cmd_pid is still a
  # live process - so a command that finishes before <seconds> is up never
  # gets the marker written for it, and never gets signaled at all.
  (
    sleep "$secs"
    if kill -0 "$cmd_pid" 2>/dev/null; then
      : > "$timeout_marker"
      kill -TERM "$cmd_pid" 2>/dev/null
    fi
  ) &
  watchdog_pid=$!

  status=0
  wait "$cmd_pid" 2>/dev/null || status=$?

  # By the time the wait above returns, the watchdog has either already
  # fired or is now pointless - kill+wait it here so it never outlives this
  # function as an orphaned background job. `|| true` on both: a caller
  # under `set -eu` must not abort on the watchdog's own (expected, ignored)
  # exit status.
  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true

  cat "$stdout_file"
  cat "$stderr_file" >&2
  rm -f "$stdout_file" "$stderr_file"

  if [ -f "$timeout_marker" ]; then
    rm -f "$timeout_marker"
    return 124
  fi
  return "$status"
}

# ensure_disk_space <min_gb> (TASK-91): dies with a clear message if the
# filesystem containing $HOME has less than <min_gb> GB free. A best-effort
# up-front check, not a guarantee — a specific runtime's download+compile
# could still fail on genuinely tight disk even after this passes.
# `df -Pk`: POSIX output format (portable across BSD and GNU df) in 1024-byte
# blocks, so dividing by 1024 twice gets whole GB without needing `-g` (a
# GNU-only flag BSD/macOS df doesn't have).
#######################################
# Die with a clear message if $HOME's filesystem has too little free space.
# Globals:
#   HOME
# Arguments:
#   $1: min_gb — minimum free GB required
# Outputs:
#   None on success. On failure, writes an error message to STDERR (via
#   die()).
# Returns:
#   Does not return on failure — exits (via die()) with status 1.
#######################################
ensure_disk_space() {
  local min_gb="$1" available_kb available_gb
  available_kb="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
  available_gb=$((available_kb / 1024 / 1024))
  if [ "$available_gb" -lt "$min_gb" ]; then
    die "Only ${available_gb}GB free on the filesystem containing \$HOME" \
      "(need at least ${min_gb}GB for Homebrew + asdf runtime compiles)." \
      "Free up space and try again."
  fi
}

# LT_CHILD_PID: the currently-running phase child process, if any — set by
# run_phase() below, read by handle_interrupt() so a trapped signal can
# kill it directly instead of leaving it to run to completion untouched.
LT_CHILD_PID=""

# run_phase <script>: runs a phase script and waits for it — but as a
# backgrounded job + `wait`, not a plain synchronous `sh "$script"` call.
# This matters for TASK-90: a signal for which a trap is registered does
# NOT interrupt a shell blocked on a plain foreground command's exit —
# POSIX shells only dispatch the trap once that command returns on its own,
# which for a multi-minute `asdf install` mid-compile means Ctrl-C/SIGTERM
# would sit unprocessed (and the lock unreleased) until the compile
# finishes naturally. `wait` is different: POSIX explicitly guarantees it
# returns early the moment a trapped signal arrives, letting the trap fire
# immediately. (Found via a real CI failure, not by inspection: the TASK-32
# "kill mid-install then re-run" job failed with "another install appears
# to be running" — the first run's lock was still held, uncollected, when
# the second one started, because main.sh hadn't processed its own SIGTERM
# yet.) Only the immediate child is targeted, not further descendants (e.g.
# `asdf install`'s own compiler subprocesses) — sufficient to make the
# *lock* release promptly, which is what re-running depends on; deeper
# orphans left briefly behind (if any) aren't this process's to manage.
# Returns the phase's own exit status (not just whatever the trailing
# `LT_CHILD_PID=""` assignment would return, which is always 0) so a
# failing phase under the caller's `set -eu` actually stops the run instead
# of being silently treated as success.
#######################################
# Run a phase script as a backgrounded, waited-on child so signals
# interrupt it promptly.
# Globals:
#   LT_CHILD_PID (written)
# Arguments:
#   $1: path to the phase script to run
# Outputs:
#   None of its own — whatever the phase script itself writes passes
#   through.
# Returns:
#   The phase script's own exit status.
#######################################
run_phase() {
  # Between backgrounding the child and capturing its PID there's a brief
  # window where handle_interrupt has nothing to kill yet: a signal landing
  # exactly there would see an empty LT_CHILD_PID, skip the kill, and still
  # exit 130 — freeing the lock while this phase's child keeps running
  # unsupervised, the very orphan-plus-early-unlock this function exists to
  # prevent. Ignoring INT/TERM for that instant closes the window: POSIX
  # signals aren't queued while ignored, so a signal delivered there is
  # simply dropped rather than deferred — worst case it takes a second
  # Ctrl-C, which beats leaking an orphaned child.
  trap '' INT TERM
  sh "$1" &
  LT_CHILD_PID=$!
  trap 'handle_interrupt' INT TERM
  local status=0
  wait "$LT_CHILD_PID" || status=$?
  LT_CHILD_PID=""
  return "$status"
}

# handle_interrupt (TASK-90): registered via `trap handle_interrupt INT
# TERM` in install/main.sh and uninstall/main.sh, right after acquire_lock.
# Without this, Ctrl-C just kills the script with no explanation of what
# state it's left in. Every phase script this tool runs is safe to re-run
# (each one checks "already present"/"already absent" before acting — see
# design principle 1 in readme.md), so the honest, reassuring answer really
# is "just run it again." Kills LT_CHILD_PID first (see run_phase above) so
# a phase mid-flight actually stops instead of continuing to completion
# untouched. `exit 130` (128+SIGINT, the conventional exit code for Ctrl-C)
# still triggers the separately-registered EXIT trap afterward — INT/TERM
# and EXIT are independent trap slots, so this doesn't clobber the
# lock-release/cleanup trap the way two traps on the SAME signal would.
#######################################
# Handle an INT/TERM signal: kill the running phase child, then exit.
# Globals:
#   LT_CHILD_PID
# Arguments:
#   None
# Outputs:
#   Writes an interrupt notice to STDOUT (via log()).
# Returns:
#   Does not return — exits with status 130.
#######################################
handle_interrupt() {
  if [ -n "$LT_CHILD_PID" ]; then
    kill "$LT_CHILD_PID" 2>/dev/null || true
  fi
  log ""
  log "Interrupted. Anything already finished will be skipped on a" \
    "re-run - just run the same command again to continue."
  exit 130
}

# lt_die_if_lock_held: reads $LT_LOCK_DIR/pid and dies with the "another
# instance is running" message if that PID is still alive. Shared by
# acquire_lock()'s two check points below (the initial mkdir failure and the
# stale-lock reclaim race) so the message/logic can't drift between them.
#######################################
# Die if the PID recorded in the lock directory is still a live process.
# Globals:
#   LT_LOCK_DIR
# Arguments:
#   None
# Outputs:
#   None on success. On failure, writes an error message to STDERR (via
#   die()).
# Returns:
#   Does not return on failure — exits (via die()) with status 1.
#######################################
lt_die_if_lock_held() {
  local holder_pid=""
  [ -f "$LT_LOCK_DIR/pid" ] &&
    holder_pid="$(cat "$LT_LOCK_DIR/pid" 2>/dev/null)"
  if [ -n "$holder_pid" ] && kill -0 "$holder_pid" 2>/dev/null; then
    die "Another langtoolchain install/uninstall (pid $holder_pid)" \
      "appears to be running. If you're sure it isn't, remove" \
      "$LT_LOCK_DIR and retry."
  fi
}

# acquire_lock (TASK-84): takes the exclusive lock at LT_LOCK_DIR so two
# install/uninstall runs can never mutate asdf/Homebrew state at the same
# time. `mkdir` either succeeds (lock acquired) or fails because the
# directory already exists (someone else holds it) — nothing in between, so
# this can't race. If it's already held, checks whether the PID recorded
# inside it is still alive (`kill -0`, POSIX-specified, sends no signal):
# a live PID means a real concurrent run, so this dies with a clear message;
# a dead PID means whatever held the lock crashed/was killed before its own
# `release_lock` trap could fire, so the stale lock is reclaimed instead of
# permanently blocking every future run. Caller must `trap 'release_lock'
# EXIT` (or fold it into an existing combined trap) right after calling this.
#######################################
# Take the exclusive install/uninstall lock at LT_LOCK_DIR.
# Globals:
#   LT_LOCK_DIR
# Arguments:
#   None
# Outputs:
#   None on success (writes $$ into $LT_LOCK_DIR/pid). On failure, writes
#   an error message to STDERR (via die()).
# Returns:
#   Does not return on failure — exits (via die()) with status 1.
#######################################
acquire_lock() {
  if ! mkdir "$LT_LOCK_DIR" 2>/dev/null; then
    lt_die_if_lock_held
    # Stale lock (holder died before its own release_lock trap could run):
    # reclaim it. Two processes can observe the same stale lock at the same
    # instant and both reach this point — `rm -rf` on an already-removed
    # directory is a silent no-op, so at most one of the two `mkdir`s right
    # after it actually succeeds. The loser re-checks who holds the lock
    # now instead of assuming the worst: if the winner just legitimately
    # took it, that's reported as a real concurrent run, not a mystery
    # "could not acquire" failure.
    rm -rf "$LT_LOCK_DIR" 2>/dev/null
    if ! mkdir "$LT_LOCK_DIR" 2>/dev/null; then
      lt_die_if_lock_held
      die "Could not acquire lock at $LT_LOCK_DIR"
    fi
  fi
  echo $$ > "$LT_LOCK_DIR/pid"
}

# release_lock: removes the lock directory. Safe to call even when no lock
# was ever acquired (e.g. acquire_lock itself just died) — rm -rf on a path
# that doesn't exist is a no-op, not an error.
#######################################
# Remove the lock directory taken by acquire_lock().
# Globals:
#   LT_LOCK_DIR
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
release_lock() {
  rm -rf "$LT_LOCK_DIR"
}

# repo_root_from <path-to-a-file-inside-scripts/install-or-uninstall>:
# prints the repository root (two directories up from scripts/install/ or
# scripts/uninstall/). Each phase script calls this with its own $0 so it
# can find .tool-versions regardless of the caller's current working
# directory.
#######################################
# Print the repository root, given a path to a file inside scripts/install
# or scripts/uninstall.
# Globals:
#   None
# Arguments:
#   $1: path to a file inside scripts/install or scripts/uninstall
# Outputs:
#   Writes the repository root absolute path to STDOUT.
# Returns:
#   None
#######################################
repo_root_from() {
  # Run in a subshell so the `cd` here doesn't change the calling script's
  # own working directory; `pwd` then prints the absolute, resolved path.
  ( cd "$(dirname "$1")/../.." && pwd )
}

# each_tool <config-file>: reads a .tool-versions-style file and prints
# "plugin version" pairs, one per line — skipping comment lines (starting
# with #) and blank/whitespace-only lines.
#######################################
# Print "plugin version" pairs from a .tool-versions-style file.
# Globals:
#   None
# Arguments:
#   $1: path to the .tool-versions-style config file
# Outputs:
#   Writes one "<plugin> <version>" line per entry to STDOUT.
# Returns:
#   None
#######################################
each_tool() {
  # /^[^# \t]/ matches lines whose first character is neither '#' nor a
  # space/tab, i.e. real plugin lines; $1/$2 are the plugin name and version
  # columns.
  awk '/^[^# \t]/ {print $1, $2}' "$1"
}

# detect_rc_file: prints the shell rc file the installer should edit,
# based on the user's login shell ($SHELL), not the shell currently running
# this script (curl | bash always runs under bash regardless of what the
# user actually uses day to day).
#######################################
# Print the shell rc file the installer should edit.
# Globals:
#   SHELL
#   HOME
#   LT_RC_FILE_ZSH
#   LT_RC_FILE_BASH
# Arguments:
#   None
# Outputs:
#   Writes the chosen rc file's absolute path to STDOUT.
# Returns:
#   None
#######################################
detect_rc_file() {
  case "$(basename "${SHELL:-}")" in
    zsh)  echo "$HOME/$LT_RC_FILE_ZSH" ;;
    bash) echo "$HOME/$LT_RC_FILE_BASH" ;;
    # unknown shell: default to zsh (macOS's own default since Catalina)
    *)    echo "$HOME/$LT_RC_FILE_ZSH" ;;
  esac
}

# append_env_var <rc_file> <search> <line>: appends <line> to <rc_file>,
# unless <rc_file> already contains something matching the grep pattern
# <search> — so re-running the installer never duplicates a line.
#######################################
# Append <line> to <rc_file>, unless <search> already matches something in it.
# Globals:
#   DRY_RUN
# Arguments:
#   $1: rc_file — path to the rc file to edit
#   $2: search — grep pattern that marks the line as already present
#   $3: line — the line to append
# Outputs:
#   Under DRY_RUN, writes a description of the pending write to STDOUT.
#   Otherwise none to STDOUT (appends <line> to <rc_file> on disk when not
#   already present).
# Returns:
#   None
#######################################
append_env_var() {
  local rc_file="$1" search="$2" line="$3"
  if [ "$DRY_RUN" = "true" ]; then
    # Dry-run: describe the write instead of performing it.
    printf '  + append to %s if missing: %s\n' "$rc_file" "$line"
    return
  fi
  # grep -q: no output, just an exit code. 2>/dev/null swallows the "no
  # such file" error the very first time this runs against a fresh rc file
  # (grep failing is also what makes `||` fall through to appending).
  grep -q "$search" "$rc_file" 2>/dev/null ||
    printf '%s\n' "$line" >> "$rc_file"
}

# prepend_env_var <rc_file> <search> <line>: like append_env_var, but
# inserts <line> at the very TOP of the file instead of the bottom.
#
# Order matters for PATH: whichever export runs LAST at shell startup wins
# (each `export PATH="X:$PATH"` prepends X ahead of everything already
# there). `brew shellenv` needs to run before asdf's shim PATH line — not
# after — or a Homebrew formula that happens to share a name with
# something asdf manages (e.g. a `node` formula installed some other way)
# would silently shadow the asdf shim. append_env_var can't guarantee this
# on a machine with a pre-existing rc file, since it only ever adds to the
# bottom; this guarantees first-in-file, and therefore correct priority,
# regardless of what else already lives in the rc file.
#######################################
# Prepend <line> to <rc_file>, unless <search> already matches something in it.
# Globals:
#   DRY_RUN
# Arguments:
#   $1: rc_file — path to the rc file to edit
#   $2: search — grep pattern that marks the line as already present
#   $3: line — the line to prepend
# Outputs:
#   Under DRY_RUN, writes a description of the pending write to STDOUT.
#   Otherwise none to STDOUT (rewrites <rc_file> on disk with <line> at the
#   top, when not already present).
# Returns:
#   None
#######################################
prepend_env_var() {
  local rc_file="$1" search="$2" line="$3"
  if [ "$DRY_RUN" = "true" ]; then
    printf '  + prepend to %s if missing: %s\n' "$rc_file" "$line"
    return
  fi
  grep -q "$search" "$rc_file" 2>/dev/null && return
  local tmp
  tmp="$(mktemp)"
  # New line first, then the file's existing content, all written to a
  # temp file, then swapped into place — `cat` never edits a file in place
  # while also reading from it.
  { printf '%s\n' "$line"; cat "$rc_file"; } > "$tmp"
  mv "$tmp" "$rc_file"
}

# read_scope <config_file>: reads the optional "# scope: ..." first line a
# selection file from 00_select.sh may carry, and prints either "global" or
# "local:<dir>". A config file with no such line (including this repo's own
# .tool-versions, which nothing ever adds this line to) defaults to
# "global" — keeps every phase working unmodified when TOOL_VERSIONS_FILE
# isn't set.
#######################################
# Print the scope ("global" or "local:<dir>") recorded in a config file.
# Globals:
#   None
# Arguments:
#   $1: config_file to read the scope line from
# Outputs:
#   Writes "global" or "local:<dir>" to STDOUT.
# Returns:
#   None
#######################################
read_scope() {
  local config_file="$1" first_line
  first_line="$(head -n 1 "$config_file" 2>/dev/null)"
  case "$first_line" in
    "# scope: local "*) echo "local:${first_line#"# scope: local "}" ;;
    *)                  echo "global" ;;
  esac
}

# Modern Homebrew asdf (v0.16+, the Go rewrite) is a single binary with no
# libexec/asdf.sh to source — shell integration is just putting
# $ASDF_DATA_DIR/shims on PATH. Every phase that shells out to `asdf` or an
# asdf shim calls this first, so no phase depends on another phase having
# exported anything into this process already (main.sh runs each phase as
# its own separate `bash` child process, so nothing carries over
# automatically).
#######################################
# Export ASDF_DATA_DIR and put its shims directory on PATH for this process.
# Globals:
#   ASDF_DATA_DIR (written)
#   PATH (read, written)
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
ensure_asdf_on_path() {
  # Default to asdf's own default data directory if the caller's
  # environment hasn't already set ASDF_DATA_DIR.
  export ASDF_DATA_DIR="$(lt_asdf_data_dir)"
  # Only prepend the shims directory if it isn't already on PATH — colons
  # bracket the check so a partial/substring match (e.g. a differently
  # named sibling directory) can't produce a false positive.
  case ":$PATH:" in
    *":$ASDF_DATA_DIR/shims:"*) ;;                      # already present: no-op
    # not present: prepend it
    *) export PATH="$ASDF_DATA_DIR/shims:$PATH" ;;
  esac
}

# ensure_brew_on_path: makes `brew` callable from *this* process, even if
# Homebrew was only just installed moments ago by a DIFFERENT phase's
# process (main.sh runs every phase as its own `bash` child, so nothing
# exported by phase 01's Homebrew install carries over automatically).
#
# Homebrew's own installer never edits PATH itself — it prints an
# `eval "$(brew shellenv)"` line for the user to add to their rc file by
# hand, which only takes effect in brand-new shells. Since our own rc-file
# write for that line (see 04_configure_shell_env.sh) doesn't help THIS
# still-running install either, this falls back to Homebrew's two
# fixed, architecture-specific install locations directly.
#######################################
# Make `brew` callable from this process, even if just installed.
# Globals:
#   PATH (read, written)
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
ensure_brew_on_path() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi
  local brew_bin
  brew_bin="$(lt_homebrew_prefix)/bin"
  if [ -x "$brew_bin/brew" ]; then
    export PATH="$brew_bin:$PATH"
  fi
}

# ensure_build_flags: re-exports the Homebrew build flags Python (and
# friends) need to compile against keg-only openssl/readline/sqlite3/zlib.
# Homebrew deliberately doesn't put keg-only formulas on PATH/in the
# compiler's default search path, so without these exports `asdf install
# python ...` fails to find OpenSSL/SQLite headers. Any phase that runs
# `asdf install` calls this itself rather than trusting an earlier phase's
# export to still be in scope (again: separate child processes).
#
# Of the full LT_BUILD_DEPS list, only these four (openssl, readline,
# sqlite3, zlib) actually need compiler/linker flags — xz and tcl-tk don't,
# so they're intentionally left out below.
#######################################
# Re-export the Homebrew build flags needed to compile against keg-only deps.
# Globals:
#   PATH (written)
#   LDFLAGS (written)
#   CPPFLAGS (written)
#   PKG_CONFIG_PATH (written)
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
ensure_build_flags() {
  # `brew --prefix` below needs `brew` itself resolvable first.
  ensure_brew_on_path
  # Declared and assigned separately (not inline inside the export) so a
  # failing `brew --prefix`/`lt_homebrew_prefix` (e.g. the formula somehow
  # isn't actually installed) trips `set -e` here instead of being silently
  # swallowed — `export LDFLAGS="...$(cmd)..."` always "succeeds" as a
  # command even if the command substitution inside it failed, masking the
  # real error and leaving LDFLAGS built from an empty/wrong path.
  local homebrew_prefix openssl_prefix readline_prefix sqlite_prefix
  local zlib_prefix prefixes
  homebrew_prefix="$(lt_homebrew_prefix)"
  export PATH="$homebrew_prefix/opt/sqlite/bin:$PATH"
  # One `brew --prefix` call for all four formulas (each spawns brew's own
  # Ruby interpreter, so four separate calls means four avoidable startups)
  # instead of one call per formula. Order matches the arguments, one prefix
  # per line; `set --` (not `read`, which would eat the last line without a
  # trailing newline) re-splits that into positional params on newlines only,
  # same idiom used for SELECT_OPTS/SED_ARGS elsewhere in this codebase.
  prefixes="$(brew --prefix openssl readline sqlite3 zlib)"
  IFS="
"
  # shellcheck disable=SC2086
  set -- $prefixes
  unset IFS
  openssl_prefix="$1" readline_prefix="$2" sqlite_prefix="$3" zlib_prefix="$4"
  export LDFLAGS="-L$openssl_prefix/lib -L$readline_prefix/lib \
-L$sqlite_prefix/lib -L$zlib_prefix/lib"
  export CPPFLAGS="-I$openssl_prefix/include -I$readline_prefix/include \
-I$sqlite_prefix/include -I$zlib_prefix/include"
  export PKG_CONFIG_PATH="$openssl_prefix/lib/pkgconfig:\
$readline_prefix/lib/pkgconfig:$sqlite_prefix/lib/pkgconfig"
}

# binary_for_plugin <asdf-plugin-name>: prints the primary CLI command that
# plugin installs (e.g. "nodejs" -> "node"). Implemented as a `case`
# instead of an associative array (`declare -A`) because bash 3.2 — the
# actual /bin/bash macOS ships — predates associative arrays entirely, and
# `curl | bash` may run under whatever `bash` is first on the user's PATH.
#######################################
# Print the primary CLI binary an asdf plugin installs.
# Globals:
#   None
# Arguments:
#   $1: asdf plugin name
# Outputs:
#   Writes the binary name to STDOUT.
# Returns:
#   None
#######################################
binary_for_plugin() {
  case "$1" in
    nodejs) echo node ;;
    java)   echo java ;;
    python) echo python ;;
    rust)   echo rustc ;;
    golang) echo go ;;
    # unknown plugin: assume the plugin name IS the binary name
    *)      echo "$1" ;;
  esac
}

# lt_companion_for_plugin <asdf-plugin-name> (m-7/TASK-99; python/uv added
# m-12/TASK-121, decision-5): prints the space-separated companion
# plugin(s) this language commonly needs alongside it - a package/build
# manager the base language plugin does NOT already bundle. nodejs's asdf
# plugin installs a bare Node runtime with only npm, so pnpm is a genuinely
# separate, commonly-wanted install; java's plugin installs only a JDK with
# no build tool at all, so gradle is closer to required than optional for
# real projects; python's plugin installs a bare interpreter with only pip,
# so uv (decision-5: chosen over poetry - single-binary install fits this
# repo's asdf-plugin-per-tool model, and leads poetry in both ecosystem
# adoption and asdf plugin activity as of that decision) fills the same gap
# pnpm/gradle fill for their languages. rust and golang have no entry here
# on purpose, not by omission: asdf-rust bundles cargo and the golang
# plugin's `go` binary already includes modules/build tooling, so there's
# no equivalent "separate package manager" gap to fill for them. Same
# `case` pattern as binary_for_plugin() above, for the same bash-3.2-has-
# no-associative-arrays reason. Empty output means "no companion for this
# plugin" - callers must treat that as a valid, common case, not an error.
#######################################
# Print the companion plugin(s) commonly needed alongside a base plugin.
# Globals:
#   None
# Arguments:
#   $1: asdf plugin name
# Outputs:
#   Writes the companion plugin name to STDOUT, or nothing if this plugin
#   has no companion.
# Returns:
#   None
#######################################
lt_companion_for_plugin() {
  case "$1" in
    nodejs) echo pnpm ;;
    java)   echo gradle ;;
    python) echo uv ;;
    *)      echo "" ;;
  esac
}

# flag_for_binary <binary-name>: prints the flag that binary uses to print
# its own version (they're not all the same — `go version` has no dashes,
# `node -v` is a short flag, `java -version` is a single dash, etc).
#######################################
# Print the flag a binary uses to print its own version.
# Globals:
#   None
# Arguments:
#   $1: binary name
# Outputs:
#   Writes the version flag to STDOUT.
# Returns:
#   None
#######################################
flag_for_binary() {
  case "$1" in
    node)   echo -v ;;
    java)   echo -version ;;
    python) echo --version ;;
    rustc)  echo --version ;;
    go)     echo version ;;
    *)      echo --version ;;   # unknown binary: guess the common long flag
  esac
}

# version_core <version-string>: extracts the first X.Y[.Z] numeric version
# substring (e.g. asdf's "temurin-25.0.2+10.0.LTS" -> "25.0.2"). Prints
# nothing (and fails) if the string has no such pattern (e.g. the alias
# "lts"), so callers can skip a version comparison instead of false-warning.
#
# POSIX sh has no [[ =~ ]]/BASH_REMATCH, so this uses sed instead: strip
# every leading non-digit character (`[^0-9]*`, greedy but unable to eat
# into a digit, so it always stops at the *first* digit run — this is what
# gives leftmost-match behavior, same as the old regex), then capture an
# X.Y or X.Y.Z run and discard everything after it. Plain BRE (no -E), so
# this is portable to both BSD and GNU sed without needing -E.
#######################################
# Extract the first X.Y[.Z] numeric version substring from a string.
# Globals:
#   None
# Arguments:
#   $1: version string to extract from
# Outputs:
#   Writes the extracted X.Y[.Z] substring to STDOUT on success; nothing on
#   no match.
# Returns:
#   None
#######################################
version_core() {
  local result
  result="$(printf '%s\n' "$1" |
    sed -n 's/[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\(\.[0-9][0-9]*\)*\).*/\1/p')"
  [ -n "$result" ] || return 1
  printf '%s\n' "$result"
}

# LT_VERSION_FETCH_TIMEOUT (m-12/TASK-119): per-network-call timeout, in
# seconds, for lt_upstream_latest_version()'s curl/git calls below.
# Override-able like LT_LOCK_DIR/LT_REPORT_FILE elsewhere in this file, so
# a test can shrink it instead of waiting out a real timeout.
LT_VERSION_FETCH_TIMEOUT="${LT_VERSION_FETCH_TIMEOUT:-5}"

# LT_PYTHON_TAGS_TIMEOUT (TASK-145.2): the python branch below lists
# cpython's ENTIRE tag history (1000+ tags, final releases mixed with
# pre-releases) via `git ls-remote --tags --refs`, unlike every other
# branch here which fetches a few hundred bytes of JSON for a single
# already-latest value - LT_VERSION_FETCH_TIMEOUT's 5s default is tuned
# for that JSON case and this call routinely exceeds it even on a normal
# connection, so lt_run_with_timeout() kills it and the caller silently
# falls back to a stale static default (the feature never actually
# engages). A server-side refs filter (e.g. `refs/tags/v3.*`) was
# considered instead of a bigger budget, but rejected: it would require
# already knowing the latest major.minor to filter for, which is exactly
# what this call exists to discover - filtering could silently miss a
# new major/minor's tags. Given its own larger budget instead.
# Override-able like LT_VERSION_FETCH_TIMEOUT (test can shrink it), so
# not readonly.
LT_PYTHON_TAGS_TIMEOUT="${LT_PYTHON_TAGS_TIMEOUT:-20}"

# LT_LARGE_LIST_TIMEOUT (TASK-169): same reasoning as LT_PYTHON_TAGS_TIMEOUT
# above, for lt_upstream_version_list()'s pnpm and uv branches specifically.
# Measured live: nodejs's own list JSON is ~331KB, but pnpm's npm-registry
# response is ~1.88MB and uv's GitHub Releases response is ~9.65MB - 4x and
# 23x larger respectively, on the same shared 5s LT_VERSION_FETCH_TIMEOUT
# budget every other (small-payload) branch uses. On an ordinary (not
# fast/low-latency) connection either is a plausible single point of
# failure that then trips the session-wide circuit breaker (decision-17)
# for every plugin asked afterward - which is exactly what made companion
# tools (asked after their parent language) look broken while the parent
# itself resolved fine. Override-able like every other *_TIMEOUT above.
LT_LARGE_LIST_TIMEOUT="${LT_LARGE_LIST_TIMEOUT:-20}"

# lt_adoptium_arch: prints the CPU architecture name Adoptium's API expects
# (used by lt_upstream_latest_version's java case below) - different from
# lt_homebrew_prefix's own uname -m mapping only in spelling ("aarch64" vs
# "arm64"), so this can't just reuse that function.
#######################################
# Print the CPU architecture name Adoptium's API expects.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes the Adoptium architecture name ("aarch64" or "x64") to STDOUT.
# Returns:
#   None
#######################################
lt_adoptium_arch() {
  case "$(uname -m)" in
    arm64) echo aarch64 ;;  # Apple Silicon
    *)     echo x64 ;;      # Intel
  esac
}

# lt_json_field <key> [value_prefix] (m-16/TASK-133): reads a JSON body
# from stdin and prints the string value of the first "<key>": "<value>"
# pair, quotes stripped. Factored out of lt_upstream_latest_version below,
# whose pnpm/gradle/golang/java/uv branches each inlined this same
# grep+head+sed sequence (pnpm/gradle were byte-for-byte identical; golang/
# java were prefix variants) - one place to fix the extraction now instead
# of five.
#
# value_prefix, if given, requires the matched value to literally start
# with it and strips it from the printed result - e.g. go.dev's
# "version":"go1.27.1" needs prefix "go" to yield "1.27.1". Omit it for a
# plain string field (pnpm/gradle/java/uv all pass no prefix here; java's
# own "temurin-" decoration is added by its caller afterward, since that
# prefix goes on the *output* rather than stripping one from the *input* -
# a different operation this helper doesn't need to know about).
#
# Same head -1/sed shape as the original inline code: no match still exits
# 0 with empty output (sed processes zero lines cleanly), matching how
# every existing call site/test already treats a missing field as "nothing
# printed", not a hard failure.
#######################################
# Print the string value of the first "<key>":"<value>" pair in a JSON body.
# Globals:
#   None
# Arguments:
#   $1: key — JSON key name to search for
#   $2: (optional) value_prefix the matched value must start with (also
#       stripped from the printed result)
# Outputs:
#   Reads a JSON body from STDIN. Writes the matched field's value to
#   STDOUT, or nothing if no match.
# Returns:
#   None
#######################################
lt_json_field() {
  local key="$1" prefix="${2:-}"
  grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"${prefix}[^\"]*\"" |
    head -1 |
    sed -E "s/.*\"${prefix}([^\"]*)\"\$/\1/"
}

# lt_upstream_latest_version <plugin> (m-12/TASK-118 decision, decision-4):
# fetches this plugin's latest stable version straight from that language's
# own official distribution index/API - deliberately NOT via `asdf latest`/
# `asdf list all` (see decision-4: those require the plugin to already be
# added to asdf, which 00_select.sh can't guarantee at phase 0 - see
# ask_version()'s own comment in scripts/install/00_select.sh). Every
# branch below needs nothing but curl (or git, for python) and the network
# - no asdf, no plugin - so it's safe to call directly from phase 0.
#
# Prints the version string on success. Returns 1 (nothing printed) on any
# failure - missing curl, network/DNS failure, non-2xx response, empty or
# unparseable body - so callers must always have a static fallback ready
# (see lt_default_version below, the function every real call site uses).
#
# Same case-dispatch style as binary_for_plugin()/lt_companion_for_plugin()
# above, for the same bash-3.2-has-no-associative-arrays reason.
#######################################
# Fetch a plugin's latest stable version from its official upstream index.
# Globals:
#   LT_VERSION_FETCH_TIMEOUT
#   LT_PYTHON_TAGS_TIMEOUT
# Arguments:
#   $1: asdf plugin name
# Outputs:
#   Writes the fetched version string to STDOUT on success; nothing on
#   failure.
# Returns:
#   None
#######################################
lt_upstream_latest_version() {
  # No up-front `command -v curl` guard here on purpose: every branch below
  # that needs curl (or git, for python) already chains `|| return 1` onto
  # its own call, which catches a missing binary (exit 127) exactly like
  # any other failure - a shared guard would also incorrectly gate the
  # nodejs branch (which shells out to nothing at all).
  local plugin="$1" body lts_major semver
  case "$plugin" in
    nodejs)
      # asdf-nodejs resolves the "lts" alias itself, fresh, at actual
      # `asdf install nodejs lts` time - a network call here would only
      # ever produce a snapshot that's already stale by the time asdf uses
      # it, so this passes the alias straight through instead of
      # pre-resolving it. (This is also why .tool-versions already carries
      # "lts", not a pinned number, for nodejs.)
      echo lts
      ;;
    pnpm)
      # npm registry - the same place asdf-pnpm's own installer downloads
      # pnpm from.
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
        'https://registry.npmjs.org/pnpm/latest' 2>/dev/null)" || return 1
      printf '%s\n' "$body" | lt_json_field version
      ;;
    gradle)
      # Gradle's own official "current version" API - a single value, no
      # rc/milestone noise to filter (unlike asdf-gradle's list-all).
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
        'https://services.gradle.org/versions/current' 2>/dev/null)" || return 1
      printf '%s\n' "$body" | lt_json_field version
      ;;
    golang)
      # go.dev's official download index - first array entry is the
      # current stable release.
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
        'https://go.dev/dl/?mode=json' 2>/dev/null)" || return 1
      printf '%s\n' "$body" | lt_json_field version go
      ;;
    rust)
      # Rust's official release channel manifest (TOML) - the [pkg.rust]
      # section's version field specifically, since the file also lists
      # cargo/rustfmt/etc.'s own versions under the same "version" key.
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
        'https://static.rust-lang.org/dist/channel-rust-stable.toml' \
        2>/dev/null)" || return 1
      printf '%s\n' "$body" |
        awk '/^\[pkg\.rust\]/{f=1; next} f && /^version/{print; exit}' |
        sed -E 's/version = "([0-9.]+).*/\1/'
      ;;
    python)
      # No official JSON index with a working "just the latest" server-side
      # filter (python.org's release API doesn't order/filter the way its
      # own docs suggest - checked directly, see TASK-118.1 notes) - cpython's
      # own tags are the next best official source. Tags mix final releases
      # (vX.Y.Z) with pre-releases (vX.Y.ZaN/bN/rcN); filter down to final
      # releases only, then sort each dotted field numerically (macOS's BSD
      # sort has no -V/version-sort, unlike GNU sort) and take the highest.
      #
      # http.lowSpeedLimit/http.lowSpeedTime only catch a transfer that
      # already started and then stalled - they never engage if the
      # connection blackholes during DNS/TCP/TLS handshake, before any byte
      # has moved (TASK-131.2/decision-10). lt_run_with_timeout (TASK-138.1)
      # wraps the whole call in a hard wall-clock kill so that case can't
      # hang past LT_PYTHON_TAGS_TIMEOUT either - the two guards are kept
      # together rather than one replacing the other, since the lowSpeed*
      # flags cost nothing extra and still cover the "slow, not stalled"
      # case a bit more gracefully (git's own clean abort vs. a SIGTERM).
      # Its own larger LT_PYTHON_TAGS_TIMEOUT budget (TASK-145.2), not the
      # shared LT_VERSION_FETCH_TIMEOUT every other branch above uses -
      # listing cpython's entire tag history is a much bigger call than a
      # few hundred bytes of JSON, and routinely overran the 5s default.
      body="$(lt_run_with_timeout "$LT_PYTHON_TAGS_TIMEOUT" git \
        -c http.lowSpeedLimit=1000 \
        -c http.lowSpeedTime="$LT_PYTHON_TAGS_TIMEOUT" \
        ls-remote --tags --refs https://github.com/python/cpython.git \
        2>/dev/null)" || return 1
      printf '%s\n' "$body" |
        awk '{print $2}' |
        sed -n 's#^refs/tags/v##p' |
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' |
        sort -t. -k1,1n -k2,2n -k3,3n |
        tail -1
      ;;
    java)
      # Two-step Eclipse Adoptium (Temurin) lookup: which major version is
      # the current LTS, then that major's latest GA JDK build for this
      # Mac's own architecture. The "semver" field comes back pre-formatted
      # exactly like asdf-java's own version strings (e.g.
      # "25.0.4+101.0.LTS"), so no reformatting is needed beyond prepending
      # "temurin-". os=mac is hardcoded - this repo is macOS-only.
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
        'https://api.adoptium.net/v3/info/available_releases' \
        2>/dev/null)" || return 1
      lts_major="$(printf '%s\n' "$body" |
        grep -o '"most_recent_lts"[[:space:]]*:[[:space:]]*[0-9]*' |
        grep -o '[0-9]*$')"
      [ -n "$lts_major" ] || return 1
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" "https://api.adoptium.net/v3/assets/latest/$lts_major/hotspot?vendor=eclipse&os=mac&image_type=jdk&architecture=$(lt_adoptium_arch)" 2>/dev/null)" || return 1
      semver="$(printf '%s\n' "$body" | lt_json_field semver)"
      if [ -n "$semver" ]; then
        printf 'temurin-%s\n' "$semver"
      else
        return 1
      fi
      ;;
    uv)
      # uv (m-12/TASK-121, decision-5's companion pick for python) has no
      # official JSON distribution index of its own (unlike the 7 languages
      # above, each with a dedicated official index/API) - GitHub's Releases
      # API is the fallback decision-4 already set aside for exactly this
      # case.
      #
      # TASK-169: this used to hit /releases/latest directly - a second,
      # independent GitHub API call on top of the /releases?per_page=100
      # list call every normal run already needs (ask_version() resolves
      # both the default and the full list for every plugin). GitHub's
      # unauthenticated rate limit (60 req/hour/IP) is easy to exhaust
      # across a few installs while testing, deterministically reproducing
      # "uv's version list/default never resolves" for up to an hour after.
      # Routing through lt_resolve_version_list() (its cache, not a raw
      # lt_upstream_version_list() call) instead means this is a cache hit
      # - not a second network call - whenever TASK-169's sequential
      # prefetch (00_select.sh) already warmed uv's list moments earlier in
      # the same run, which is the common case now. lt_upstream_version_
      # list()'s uv branch already returns newest-first (lt_github_release_
      # tags' contract), so the first line is exactly "latest".
      body="$(lt_resolve_version_list uv 2>/dev/null)" || return 1
      [ -n "$body" ] || return 1
      printf '%s\n' "$body" | head -1
      ;;
    *)
      # Unknown plugin (e.g. this repo's own custom TOOL_VERSIONS_FILE users
      # could pass one this function has no case for): no source to fetch
      # from, so fail like any other lookup miss - callers fall back to the
      # static default.
      return 1
      ;;
  esac
}

# lt_github_release_tags (m-15/TASK-128.1): reads a GitHub Releases API JSON
# array from STDIN and prints every entry's tag_name, one per line, in the
# array's own order (newest first, since that's how GitHub returns it) -
# but only for entries that are neither a draft nor a prerelease. Factored
# out because rust's and uv's lt_upstream_version_list() branches below
# both need this exact same parse (same "one helper instead of two near-
# duplicates" reasoning lt_json_field above was factored out for).
#
# GitHub's response is pretty-printed with tag_name/draft/prerelease as
# sibling fields inside the same release object (confirmed against a live
# fetch) but not reliably adjacent lines the way gradle's/golang's simpler
# state machines below can assume - so this tracks all three per object
# and only decides once "prerelease" (always the last of the three to
# appear) is seen, rather than deciding on every field like those two.
#######################################
# Print every non-draft, non-prerelease tag_name from a GitHub Releases API
# JSON body.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Reads a GitHub Releases API JSON array from STDIN. Writes one tag_name
#   per line to STDOUT for each non-draft, non-prerelease entry.
# Returns:
#   None
#######################################
lt_github_release_tags() {
  awk '
    /"tag_name"[ \t]*:/ {
      tag = $0
      sub(/.*"tag_name"[ \t]*:[ \t]*"/, "", tag)
      sub(/".*/, "", tag)
      next
    }
    /"draft"[ \t]*:/ {
      draft = $0
      sub(/.*"draft"[ \t]*:[ \t]*/, "", draft)
      sub(/,.*/, "", draft)
      next
    }
    /"prerelease"[ \t]*:/ {
      pre = $0
      sub(/.*"prerelease"[ \t]*:[ \t]*/, "", pre)
      sub(/,.*/, "", pre)
      if (tag != "" && draft == "false" && pre == "false") print tag
      tag = ""; draft = ""; pre = ""
      next
    }
  '
}

# lt_upstream_version_list <plugin> (m-15/TASK-128.1, decision-15): fetches
# EVERY version this plugin's official upstream index/API currently lists
# as installable - not just the single latest one lt_upstream_latest_
# version() above returns. Same "no asdf, no plugin required" property as
# that function (decision-15 confirmed all 8 sources need nothing but curl/
# git and the network, so this is just as safe to call from phase 0), and
# the same case-dispatch plugin set, but deliberately kept as a fully
# separate function rather than a second mode grafted onto
# lt_upstream_latest_version() - that function already ships with TASK-
# 119.3's shellspec coverage and is in real use by lt_resolve_default_
# version() below; growing it with a second concern (one value vs. a list)
# would risk a regression in an already-shipped, tested path for no
# benefit a new function doesn't already give just as well.
#
# Prints one version per line, newest first, on success. Returns 1
# (nothing printed) on any failure - same failure contract as
# lt_upstream_latest_version(): missing curl/git, network/DNS failure,
# non-2xx response, empty/unparseable body. Callers must be ready for a
# failure here exactly like that function's callers already are (see
# TASK-128.3, which layers caching on top, and TASK-129's UI, which falls
# back to the existing default-vs-free-text flow on a miss rather than
# growing a fallback into this layer).
#
# Known gap (decision-15's "닫히지 않는 갭", unchanged here since this
# reuses the exact same sources): every version below is what the
# LANGUAGE ITSELF calls installable, not what this repo's asdf plugin for
# it can actually install today - decision-12 already found those two can
# disagree (an asdf plugin can lag its language's own upstream index).
# This function does not cross-check against `asdf list all` - that
# range-fix (if TASK-129's UI needs one) is out of scope here.
#
# nodejs's branch is the one exception to "same plugin set as
# lt_upstream_latest_version()": that function deliberately fetches
# nothing for nodejs (asdf-nodejs resolves the "lts" alias itself at
# install time - see its comment above), but a "list every version"
# request has no equivalent alias to defer to, so this branch fetches
# nodejs.org's own release index instead - "lts" is not a member of the
# list this returns.
#
# Companion tools (m-15/TASK-128.2 - pnpm/gradle/uv, the ones
# lt_companion_for_plugin() above can return): confirmed each one is
# already just a plugin-name branch in the case below like any language -
# 00_select.sh's own lt_offer_language() already calls lt_resolve_default_
# version() (this function's single-value sibling) on a companion's plain
# plugin name with no special-casing, so this function needs none either.
# TASK-128.2's own description flags that a companion COULD be something
# other than a real asdf plugin (see TASK-99/100) - that's not true for
# any companion that exists today, so there's nothing further to branch
# on here; a future companion that genuinely isn't a plugin would need its
# own case below, same as any other new plugin would.
#######################################
# Fetch every version a plugin's official upstream index/API currently
# lists as installable.
# Globals:
#   LT_VERSION_FETCH_TIMEOUT
#   LT_PYTHON_TAGS_TIMEOUT
# Arguments:
#   $1: asdf plugin name
# Outputs:
#   Writes one version per line (newest first) to STDOUT on success;
#   nothing on failure.
# Returns:
#   None
#######################################
lt_upstream_version_list() {
  # Same no-up-front-`command -v` reasoning as lt_upstream_latest_version()
  # above: every branch below already chains `|| return 1`/`|| continue`
  # onto its own curl/git call, which catches a missing binary exactly
  # like any other failure.
  local plugin="$1" body ltses major semver found
  case "$plugin" in
    nodejs)
      # No "lts" shortcut applies to a full list request (unlike the
      # single-value branch above) - nodejs.org's own official release
      # index is the direct equivalent of every other language's source
      # here, so this is the one plugin whose list branch calls the
      # network even though its default-version branch above never does.
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
        'https://nodejs.org/dist/index.json' 2>/dev/null)" || return 1
      printf '%s\n' "$body" |
        grep -o '"version":"v[0-9][0-9.]*"' |
        sed -E 's/.*"v([0-9.]*)"/\1/'
      ;;
    pnpm)
      # Sibling "everything ever published" endpoint to the /pnpm/latest
      # single-value branch above: the same npm registry document, just
      # without the /latest suffix. The "install-v1" Accept header asks
      # npm for its abbreviated metadata format - still one full record
      # per version (npm has no lighter "just the version numbers"
      # endpoint), but noticeably smaller than the default full-manifest
      # format for no loss here. grep pulls only clean X.Y.Z keys straight
      # out of the "versions" object, dropping dev/beta/rc/pr channel tags
      # (e.g. "6.23.7-202112041634"), then a numeric sort (macOS's BSD
      # sort has no -V, same reason the python branch below needs one)
      # puts them newest-first regardless of the registry's own publish-
      # order listing. LT_LARGE_LIST_TIMEOUT (TASK-169), not the generic
      # LT_VERSION_FETCH_TIMEOUT every small-payload branch uses - this
      # response runs ~1.88MB, measured live, well past what 5s budgets for.
      body="$(curl -fsS --max-time "$LT_LARGE_LIST_TIMEOUT" \
        -H 'Accept: application/vnd.npm.install-v1+json' \
        'https://registry.npmjs.org/pnpm' 2>/dev/null)" || return 1
      printf '%s\n' "$body" |
        grep -oE '"[0-9]+\.[0-9]+\.[0-9]+":\{"name":"pnpm"' |
        sed -E 's/^"([^"]*)".*/\1/' |
        sort -t. -k1,1nr -k2,2nr -k3,3nr
      ;;
    gradle)
      # Sibling "every known build, including snapshots/RCs/milestones"
      # endpoint to /versions/current above - each entry carries its own
      # snapshot/rcFor/milestoneFor flags, so a genuine GA release is one
      # with snapshot=false and both *For fields empty. "version" is
      # always the first field inside each entry (confirmed against a
      # live fetch), so this walks the pretty-printed JSON line by line
      # and flushes/filters the previous entry each time a new "version"
      # line starts the next one - the same "state machine over one awk
      # pass" shape the rust branch above uses for its TOML sections,
      # since this repo has no jq and RS-as-regex is a gawk extension it
      # can't assume macOS's awk supports.
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
        'https://services.gradle.org/versions/all' 2>/dev/null)" || return 1
      printf '%s\n' "$body" | awk '
        function flush() {
          if (ver != "" && snap == "false" && rc == "" && ms == "") {
            print ver
          }
        }
        /"version"[ \t]*:/ {
          flush()
          ver = $0
          sub(/.*"version"[ \t]*:[ \t]*"/, "", ver)
          sub(/".*/, "", ver)
          snap = ""; rc = ""; ms = ""
          next
        }
        /"snapshot"[ \t]*:/ {
          snap = $0
          sub(/.*"snapshot"[ \t]*:[ \t]*/, "", snap)
          sub(/,.*/, "", snap)
          next
        }
        /"rcFor"[ \t]*:/ {
          rc = $0
          sub(/.*"rcFor"[ \t]*:[ \t]*"/, "", rc)
          sub(/".*/, "", rc)
          next
        }
        /"milestoneFor"[ \t]*:/ {
          ms = $0
          sub(/.*"milestoneFor"[ \t]*:[ \t]*"/, "", ms)
          sub(/".*/, "", ms)
          next
        }
        END { flush() }
      ' |
        sort -t. -k1,1nr -k2,2nr -k3,3nr
      ;;
    golang)
      # go.dev/dl/?mode=json alone (the single-value branch's own source
      # above) is capped at just the 1-2 CURRENTLY stable releases;
      # &include=all is the sibling switch returning every release this
      # index has ever listed, stable and not. Each top-level release
      # object's own "version"/"stable" fields sit at 2-space indent,
      # while those same two field names also recur once per platform
      # file nested inside that release's "files" array at 4-space indent
      # - the 2-space anchor is what keeps this from picking up those
      # nested duplicates. "version"/"stable" are adjacent lines in every
      # release object (confirmed against a live fetch), so a version is
      # held pending until its matching "stable" line resolves it.
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
        'https://go.dev/dl/?mode=json&include=all' 2>/dev/null)" ||
        return 1
      printf '%s\n' "$body" | awk '
        /^  "version":/ {
          v = $0
          sub(/^  "version": "go/, "", v)
          sub(/".*/, "", v)
          pending = v
          next
        }
        /^  "stable": true/ {
          if (pending != "") print pending
          pending = ""
          next
        }
        /^  "stable": false/ { pending = ""; next }
      '
      ;;
    rust)
      # rust's single-value branch above reads the official channel
      # manifest, but that TOML only ever names the CURRENT stable
      # version - it has no equivalent of a full history, and decision-15
      # explicitly left the full-list source for this task to pick.
      # static.rust-lang.org's own dist/ prefix has no directory-listing
      # endpoint to enumerate (confirmed via a live request - a bare GET
      # there 416s, it's a raw S3 bucket with no index), so this uses
      # rust-lang/rust's official GitHub Releases instead - the same
      # "GitHub Releases as a stand-in for a missing JSON index" fallback
      # decision-4 already set aside for uv below. tag_name comes back
      # bare (e.g. "1.98.1", no "v" prefix, confirmed all-final/no-
      # prerelease in the most recent 100 via a live fetch), matching this
      # plugin's version format directly - no reformatting needed, same as
      # the single-value branch's [pkg.rust] value.
      #
      # per_page=100 (GitHub's max per page) is one page - a couple of
      # years of releases as of this writing, not literally every version
      # rust has ever shipped back to 1.0. Not paginating further is a
      # deliberate choice, not a shortcut: decision-16's own "lazy,
      # occasional, no exhaustive prefetch" reasoning for this whole
      # feature applies just as well to "don't walk 20+ pages of a
      # personal installer's version picker to reach a decade-old
      # release".
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
        'https://api.github.com/repos/rust-lang/rust/releases?per_page=100' \
        2>/dev/null)" || return 1
      printf '%s\n' "$body" | lt_github_release_tags
      ;;
    python)
      # Same cpython tag source as the single-value branch above, but
      # keeping every filtered final-release tag instead of the tail -1
      # that branch takes - a descending numeric sort (BSD sort has no -V,
      # same reasoning as that branch's own comment) puts the newest
      # first.
      body="$(lt_run_with_timeout "$LT_PYTHON_TAGS_TIMEOUT" git \
        -c http.lowSpeedLimit=1000 \
        -c http.lowSpeedTime="$LT_PYTHON_TAGS_TIMEOUT" \
        ls-remote --tags --refs https://github.com/python/cpython.git \
        2>/dev/null)" || return 1
      printf '%s\n' "$body" |
        awk '{print $2}' |
        sed -n 's#^refs/tags/v##p' |
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' |
        sort -t. -k1,1nr -k2,2nr -k3,3nr
      ;;
    java)
      # decision-15: "여러 LTS major 나열" - one entry per currently-
      # supported LTS major (available_lts_releases - e.g. 8/11/17/21/25
      # as of this writing), each resolved to its own latest GA build via
      # the same two-step lookup the single-value branch above uses for
      # just the newest major. The array can come back either pretty-
      # printed (one number per line, confirmed via a live fetch) or as a
      # single compact line, so the digits are pulled with a presence
      # check per line rather than assuming one particular layout.
      #
      # A major with no build for this Mac's own architecture (e.g.
      # Adoptium ships no aarch64 JDK for major 8 as of this writing -
      # confirmed via a live request, x64-only) silently drops out of the
      # list instead of failing the whole call, matching every other
      # branch's "empty/unparseable = skip, not abort" contract. Iterated
      # newest-major-first to match every other branch's newest-first
      # convention (available_lts_releases itself comes back oldest-
      # first) - the classic `sed '1!G;h;$!d'` line-reversal idiom, since
      # macOS has no `tac`.
      body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
        'https://api.adoptium.net/v3/info/available_releases' \
        2>/dev/null)" || return 1
      ltses="$(printf '%s\n' "$body" | awk '
        /"available_lts_releases"/ { grab = 1 }
        grab && /[0-9]/ {
          line = $0
          gsub(/[^0-9]/, " ", line)
          gsub(/^ +| +$/, "", line)
          if (line != "") print line
        }
        grab && /\]/ { exit }
      ')"
      [ -n "$ltses" ] || return 1
      ltses="$(printf '%s\n' "$ltses" | sed '1!G;h;$!d')"
      found=false
      for major in $ltses; do
        body="$(curl -fsS --max-time "$LT_VERSION_FETCH_TIMEOUT" \
          "https://api.adoptium.net/v3/assets/latest/$major/hotspot?vendor=eclipse&os=mac&image_type=jdk&architecture=$(lt_adoptium_arch)" \
          2>/dev/null)" || continue
        semver="$(printf '%s\n' "$body" | lt_json_field semver)"
        # `if`, not `[ -n ... ] && printf` - the latter's own exit status
        # (false whenever a major has no build, e.g. no aarch64 JDK for
        # major 8 as of this writing) would otherwise become this whole
        # function's exit status once it's the last thing the last loop
        # iteration runs, wrongly reporting failure - and would abort a
        # `set -eu` caller mid-loop on the exact same false, per this
        # repo's own POSIX pitfall list (docs/shell-style-guide.md).
        if [ -n "$semver" ]; then
          printf 'temurin-%s\n' "$semver"
          found=true
        fi
      done
      # Every major came back empty/unreachable (e.g. a total Adoptium
      # outage right after the available_releases call above somehow still
      # succeeded) - fail like every other branch's "nothing usable ->
      # return 1" contract instead of silently succeeding with no output.
      [ "$found" = true ] || return 1
      ;;
    uv)
      # GitHub Releases list endpoint - see rust's branch above for why
      # per_page=100 (one page) rather than paginating through this repo's
      # full release history (300+ tags as of this writing). The single-
      # value branch above (lt_upstream_latest_version's uv case) no longer
      # hits its own endpoint (TASK-169) - it calls lt_resolve_version_list,
      # which lands here on a cache miss, so this is now the only place uv's
      # GitHub API budget gets spent. LT_LARGE_LIST_TIMEOUT (TASK-169), not
      # the generic LT_VERSION_FETCH_TIMEOUT - this response runs ~9.65MB,
      # measured live, 23x nodejs's own list JSON.
      body="$(curl -fsS --max-time "$LT_LARGE_LIST_TIMEOUT" \
        'https://api.github.com/repos/astral-sh/uv/releases?per_page=100' \
        2>/dev/null)" || return 1
      printf '%s\n' "$body" | lt_github_release_tags
      ;;
    *)
      # Unknown plugin: no source to fetch from, same as the single-value
      # branch above.
      return 1
      ;;
  esac
}

# LT_VERSION_CACHE_FILE / LT_VERSION_CACHE_TTL (m-12/TASK-119.3): where
# lt_resolve_default_version below remembers a plugin's last successfully
# fetched upstream version, and how long (seconds) that memory stays fresh
# before the next call re-fetches instead of trusting it. Deliberately
# under $HOME directly, like LT_REPORT_FILE - not under $ASDF_DATA_DIR,
# since this cache's whole purpose (avoiding a repeat network round-trip
# across nearby installer runs) has nothing to do with asdf's own state and
# shouldn't be wiped by `05_purge_asdf_core.sh`'s `rm -rf $ASDF_DATA_DIR`.
# Both override-able, same pattern as LT_LOCK_DIR/LT_REPORT_FILE, so a test
# can point this at a scratch file/short TTL instead of touching a real
# $HOME or waiting out a real day. 86400s = 24h: this is a personal,
# occasionally-run installer, not a CI job re-invoked every minute - daily
# freshness is already more current than the static .tool-versions it
# replaces, without re-hitting every upstream API on every single run
# during, say, a single afternoon of repeated installs while testing.
LT_VERSION_CACHE_FILE="${LT_VERSION_CACHE_FILE:-$HOME/\
.langtoolchain-version-cache}"
LT_VERSION_CACHE_TTL="${LT_VERSION_CACHE_TTL:-86400}"

# lt_cached_version_lookup <plugin>: prints <plugin>'s cached version if
# LT_VERSION_CACHE_FILE has a line for it written within the last
# LT_VERSION_CACHE_TTL seconds; fails (nothing printed) on a cache miss -
# no file yet, no line for this plugin, or a line older than the TTL.
# Internal to this file - lt_resolve_default_version below is the only
# caller, and the only supported way to read this cache.
#
# Cache line format: "<plugin>|||<unix-epoch>|||<version>", one per plugin,
# same triple-pipe-delimited shape lt_env_var_defs() above already uses for
# its own multi-field lines (none of these fields can contain "|||").
#######################################
# Print a plugin's cached version if it's still fresh.
# Globals:
#   LT_VERSION_CACHE_FILE
#   LT_VERSION_CACHE_TTL
# Arguments:
#   $1: plugin name
# Outputs:
#   Writes the cached version to STDOUT on a fresh cache hit; nothing on a
#   miss.
# Returns:
#   None
#######################################
lt_cached_version_lookup() {
  local plugin="$1" line ts version now
  [ -f "$LT_VERSION_CACHE_FILE" ] || return 1
  # grep finding nothing here is a normal cache miss, not an error - `|| true`
  # keeps that from tripping callers running under `set -e`.
  line="$(grep "^$plugin|||" "$LT_VERSION_CACHE_FILE" 2>/dev/null |
    tail -1)" || true
  [ -n "$line" ] || return 1
  ts="$(printf '%s\n' "$line" | awk -F'\\|\\|\\|' '{print $2}')"
  version="$(printf '%s\n' "$line" | awk -F'\\|\\|\\|' '{print $3}')"
  [ -n "$version" ] || return 1
  # A non-numeric ts (hand-edited/corrupted cache file - this cache is
  # never written with anything but a real `date +%s` epoch) would make the
  # arithmetic comparison below a hard shell error, not just a false
  # result - reject it as a miss instead of letting that abort the caller.
  case "$ts" in
    '' | *[!0-9]*) return 1 ;;
  esac
  now="$(date +%s)"
  # ts in the future (clock stepped back after a transient forward jump,
  # e.g. NTP correction) would make `now - ts` negative, and a negative
  # value is always "< TTL" - misreading a bogus-future entry as
  # permanently fresh instead of treating it as stale like any other
  # untrustworthy timestamp.
  [ "$ts" -le "$now" ] || return 1
  [ $((now - ts)) -lt "$LT_VERSION_CACHE_TTL" ] || return 1
  printf '%s\n' "$version"
}

# lt_cache_version <plugin> <version>: (over)writes <plugin>'s line in
# LT_VERSION_CACHE_FILE with <version> and the current time, replacing any
# previous line for the same plugin (never appending a stale duplicate).
# Internal to this file, same as lt_cached_version_lookup above.
#######################################
# (Over)write a plugin's cached version line in LT_VERSION_CACHE_FILE.
# Globals:
#   LT_VERSION_CACHE_FILE
# Arguments:
#   $1: plugin name
#   $2: version string to cache
# Outputs:
#   None to STDOUT (rewrites LT_VERSION_CACHE_FILE with the new/updated
#   line).
# Returns:
#   None
#######################################
lt_cache_version() {
  local plugin="$1" version="$2" tmp
  tmp="$(mktemp)"
  if [ -f "$LT_VERSION_CACHE_FILE" ]; then
    # No existing line for this plugin is a normal case (first time it's
    # ever been cached), not an error - `|| true` so `set -e` callers don't
    # abort on grep's "found nothing" exit status.
    grep -v "^$plugin|||" "$LT_VERSION_CACHE_FILE" > "$tmp" 2>/dev/null || true
  else
    : > "$tmp"
  fi
  printf '%s|||%s|||%s\n' "$plugin" "$(date +%s)" "$version" >> "$tmp"
  mv "$tmp" "$LT_VERSION_CACHE_FILE"
}

# lt_resolve_default_version <plugin> <static-default> (m-12/TASK-119.2/
# TASK-119.3, decision-4): the actual call site scripts/install/
# 00_select.sh's ask_version() comment refers to. Order of preference:
#
#   1. a fresh (within LT_VERSION_CACHE_TTL) cached value - no network call
#      at all, so re-running the installer soon after a previous run (e.g.
#      while testing, or a `--local` install right after a global one)
#      doesn't re-hit every upstream API for versions it already just
#      fetched.
#   2. a live lt_upstream_latest_version() lookup - cached for next time on
#      success.
#   3. <static-default> (the .tool-versions value 00_select.sh already has
#      on hand) - whenever both of the above come up empty (offline,
#      rate-limited, timeout, unmapped plugin, or simply no cache yet and
#      the live lookup also failed).
#
# Callers never see an empty default, and a completely offline machine
# behaves exactly as it did before m-12: the static .tool-versions value,
# install proceeds unblocked.
#######################################
# Resolve a plugin's default version: fresh cache, else live fetch, else
# the caller's static default.
# Globals:
#   None
# Arguments:
#   $1: plugin name
#   $2: static_default — fallback version if no cached/live value is found
# Outputs:
#   Writes the resolved version string to STDOUT.
# Returns:
#   None
#######################################
lt_resolve_default_version() {
  local plugin="$1" static_default="$2" cached fetched
  cached="$(lt_cached_version_lookup "$plugin" 2>/dev/null)" || cached=""
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached"
    return 0
  fi
  fetched="$(lt_upstream_latest_version "$plugin" 2>/dev/null)" || fetched=""
  if [ -n "$fetched" ]; then
    lt_cache_version "$plugin" "$fetched"
    printf '%s\n' "$fetched"
    return 0
  fi
  printf '%s\n' "$static_default"
}

# LT_VERSION_LIST_CACHE_FILE / LT_VERSION_LIST_CACHE_TTL (m-15/TASK-128.3,
# decision-16): the list-shaped sibling of LT_VERSION_CACHE_FILE/
# LT_VERSION_CACHE_TTL above - a completely separate file/TTL, not a
# reuse. decision-16 chose separation deliberately: the single-value cache
# above already shipped with TASK-119.3's own tested behavior in real use,
# and folding "sometimes a list" into it would mean a new branch inside an
# already-proven function for every reader/caller to reason about, for a
# concern (caching MANY versions) that a same-shaped-but-separate file/
# pair of functions covers just as well with zero risk to the existing
# path. Same "${VAR:-default}" override pattern as every other LT_* file/
# TTL pair in this file (LT_LOCK_DIR, LT_REPORT_FILE, LT_VERSION_CACHE_FILE
# itself) - not readonly, for the same test-can-override reason documented
# next to those. 86400s TTL default matches LT_VERSION_CACHE_TTL's own
# value today, but decision-16 keeps it a distinct variable rather than
# reusing that one - same reasoning this file already applies to keeping
# LT_VERSION_FETCH_TIMEOUT and LT_PYTHON_TAGS_TIMEOUT separate despite
# both starting from a similar-looking budget: two independently-tunable
# knobs cost nothing extra and avoid one setting silently doing double
# duty for two different callers with potentially different freshness
# needs later.
LT_VERSION_LIST_CACHE_FILE="${LT_VERSION_LIST_CACHE_FILE:-$HOME/\
.langtoolchain-version-list-cache}"
LT_VERSION_LIST_CACHE_TTL="${LT_VERSION_LIST_CACHE_TTL:-86400}"

# lt_cached_version_list_lookup <plugin>: prints <plugin>'s cached version
# list (one version per line, same shape lt_upstream_version_list() itself
# prints) if LT_VERSION_LIST_CACHE_FILE has a line for it written within
# the last LT_VERSION_LIST_CACHE_TTL seconds; fails (nothing printed) on a
# cache miss - no file yet, no line for this plugin, or a line older than
# the TTL. Same structure as lt_cached_version_lookup() above (same clock-
# skew/corrupted-timestamp guards, same reasoning for each), just reading
# from the separate list cache file and splitting the stored comma-joined
# value back into one line per version on a hit.
#
# Cache line format: "<plugin>|||<unix-epoch>|||<v1>,<v2>,<v3>,...", one
# per plugin - same triple-pipe-delimited shape as
# LT_VERSION_CACHE_FILE's own lines above, with the third field a comma-
# joined list instead of a single version (decision-16's own chosen
# format; none of this repo's version strings can contain a literal
# comma, so it's a safe separator for every plugin lt_upstream_version_
# list() supports).
#######################################
# Print a plugin's cached version list if it's still fresh.
# Globals:
#   LT_VERSION_LIST_CACHE_FILE
#   LT_VERSION_LIST_CACHE_TTL
# Arguments:
#   $1: plugin name
# Outputs:
#   Writes the cached version list, one version per line, to STDOUT on a
#   fresh cache hit; nothing on a miss.
# Returns:
#   None
#######################################
lt_cached_version_list_lookup() {
  local plugin="$1" line ts joined now
  [ -f "$LT_VERSION_LIST_CACHE_FILE" ] || return 1
  # grep finding nothing here is a normal cache miss, not an error - `|| true`
  # keeps that from tripping callers running under `set -e`.
  line="$(grep "^$plugin|||" "$LT_VERSION_LIST_CACHE_FILE" 2>/dev/null |
    tail -1)" || true
  [ -n "$line" ] || return 1
  ts="$(printf '%s\n' "$line" | awk -F'\\|\\|\\|' '{print $2}')"
  joined="$(printf '%s\n' "$line" | awk -F'\\|\\|\\|' '{print $3}')"
  [ -n "$joined" ] || return 1
  # A non-numeric ts (hand-edited/corrupted cache file - this cache is
  # never written with anything but a real `date +%s` epoch) would make the
  # arithmetic comparison below a hard shell error, not just a false
  # result - reject it as a miss instead of letting that abort the caller.
  case "$ts" in
    '' | *[!0-9]*) return 1 ;;
  esac
  now="$(date +%s)"
  # ts in the future (clock stepped back after a transient forward jump,
  # e.g. NTP correction) would make `now - ts` negative, and a negative
  # value is always "< TTL" - misreading a bogus-future entry as
  # permanently fresh instead of treating it as stale like any other
  # untrustworthy timestamp.
  [ "$ts" -le "$now" ] || return 1
  [ $((now - ts)) -lt "$LT_VERSION_LIST_CACHE_TTL" ] || return 1
  printf '%s\n' "$joined" | tr ',' '\n'
}

# lt_cache_version_list <plugin> <versions>: (over)writes <plugin>'s line
# in LT_VERSION_LIST_CACHE_FILE with <versions> (one version per line, the
# same shape lt_upstream_version_list() prints - e.g. called as
# `lt_cache_version_list "$plugin" "$(lt_upstream_version_list "$plugin")"`)
# and the current time, replacing any previous line for the same plugin
# (never appending a stale duplicate). Same structure as lt_cache_version()
# above, just joining the newline-separated input into the comma-joined
# third field this cache's line format uses.
#######################################
# (Over)write a plugin's cached version list line in
# LT_VERSION_LIST_CACHE_FILE.
# Globals:
#   LT_VERSION_LIST_CACHE_FILE
# Arguments:
#   $1: plugin name
#   $2: versions — one version per line (e.g. lt_upstream_version_list()'s
#       own output)
# Outputs:
#   None to STDOUT (rewrites LT_VERSION_LIST_CACHE_FILE with the new/
#   updated line).
# Returns:
#   None
#######################################
lt_cache_version_list() {
  local plugin="$1" versions="$2" tmp joined
  joined="$(printf '%s\n' "$versions" | tr '\n' ',' | sed 's/,$//')"
  tmp="$(mktemp)"
  if [ -f "$LT_VERSION_LIST_CACHE_FILE" ]; then
    # No existing line for this plugin is a normal case (first time it's
    # ever been cached), not an error - `|| true` so `set -e` callers don't
    # abort on grep's "found nothing" exit status.
    grep -v "^$plugin|||" "$LT_VERSION_LIST_CACHE_FILE" > "$tmp" \
      2>/dev/null || true
  else
    : > "$tmp"
  fi
  printf '%s|||%s|||%s\n' "$plugin" "$(date +%s)" "$joined" >> "$tmp"
  mv "$tmp" "$LT_VERSION_LIST_CACHE_FILE"
}

# LT_VERSION_LIST_UNREACHABLE_FILE (m-15/TASK-129.2, decision-17): a marker
# file whose mere EXISTENCE (its content is never read) is this whole
# script process's circuit breaker for lt_resolve_version_list() below -
# "some earlier plugin in this run already failed a live list fetch, stop
# trying for the rest of them".
#
# A plain in-memory shell variable cannot do this job here, unlike every
# other "${VAR:-default}" tunable in this file: scripts/install/
# 00_select.sh's ask_version() calls lt_resolve_version_list() through a
# command substitution (`version="$(ask_version ...)"`, needed to capture
# the chosen version off ask_version()'s own STDOUT) for every single
# language the user opts into, and POSIX command substitution always runs
# in its own subshell whose variable assignments never propagate back to
# the caller - a variable tripped inside one call would already have
# evaporated by the time the next call starts, defeating the whole point.
# A file on disk has no such boundary: any subshell can create it, and
# every later subshell (including ones from completely separate command
# substitutions) sees it immediately.
#
# $$ - not mktemp - names the default path: mktemp would create (and need
# cleaning up) a file on every single source of this library, even for
# processes that never call lt_resolve_version_list() at all; $$ is stable
# for the whole script's lifetime (POSIX: a subshell/command substitution
# inherits its parent's $$ unchanged - only a real new process gets a new
# one) and this costs nothing until actually tripped for the first time.
# scripts/install/00_select.sh removes this file from its own EXIT trap
# alongside its other temp files. Overridable like every other LT_* file
# path in this file, so a test can point it at its own scratch path.
LT_VERSION_LIST_UNREACHABLE_FILE="${LT_VERSION_LIST_UNREACHABLE_FILE:-\
${TMPDIR:-/tmp}/langtoolchain-version-list-unreachable.$$}"

# lt_resolve_version_list <plugin> (m-15/TASK-129.1, decision-17): the
# list-shaped counterpart to lt_resolve_default_version() above - fresh
# cache, else live fetch (cached on success), else failure. Unlike that
# function, a total miss here prints nothing and returns 1 rather than
# falling back to a static value - there is no static "full list" in
# .tool-versions to fall back to (it only ever carries one version per
# plugin), so a miss is purely the caller's problem. scripts/install/
# 00_select.sh's ask_version() is the only caller today, and decision-17
# covers how it handles a miss (a single-option menu offering just its own
# already-resolved default, replacing the old free-text-input fallback).
#######################################
# Resolve a plugin's full version list: fresh cache, else live fetch.
# Globals:
#   LT_VERSION_LIST_UNREACHABLE_FILE (read, written - see its own comment
#     above for why this is a file and not a variable)
# Arguments:
#   $1: plugin name
# Outputs:
#   Writes the version list, one per line (newest first), to STDOUT on
#   success; nothing on failure.
# Returns:
#   0 on success (cache hit or live fetch); 1 if both missed.
#######################################
lt_resolve_version_list() {
  local plugin="$1" cached fetched
  cached="$(lt_cached_version_list_lookup "$plugin" 2>/dev/null)" || cached=""
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached"
    return 0
  fi
  # Session circuit breaker (decision-17): see LT_VERSION_LIST_UNREACHABLE_
  # FILE's own comment above for why this has to be a file, not a variable.
  if [ -f "$LT_VERSION_LIST_UNREACHABLE_FILE" ]; then
    return 1
  fi
  fetched="$(lt_upstream_version_list "$plugin" 2>/dev/null)" || fetched=""
  if [ -n "$fetched" ]; then
    lt_cache_version_list "$plugin" "$fetched"
    printf '%s\n' "$fetched"
    return 0
  fi
  : > "$LT_VERSION_LIST_UNREACHABLE_FILE"
  return 1
}

# LT_VERSION_MENU_MAX (m-15/TASK-129.2, decision-17): the most version
# options scripts/install/00_select.sh's ask_version() will ever show in
# one lt_arrow_menu() call, enforced by lt_version_menu_options() below.
# lt_arrow_menu() redraws its whole option block in place on every
# keypress, which only stays legible up to roughly a screen's worth of
# lines - node/java's real upstream catalogs run into the hundreds, so
# without a cap the menu would be unusable long before the list ran out.
# lt_upstream_version_list() already returns its list newest-first by
# contract, so capping to the first N is exactly "show the N most recent
# versions", not a random sample. Not readonly, same override-for-tests
# reasoning as every other plain-global tunable in this file.
LT_VERSION_MENU_MAX=15

# lt_version_menu_options <default> (m-15/TASK-129.2, decision-17): reads a
# version list from STDIN (newest first, e.g. lt_resolve_version_list()'s
# own output) and prints the capped, deduped set of ask_version() menu
# option labels - <default> first (suffixed "(default)"), then up to
# LT_VERSION_MENU_MAX - 1 more versions, skipping any entry equal to
# <default> itself so it's never offered twice.
#
# Always returns 0 regardless of whether the read loop below ran zero,
# some, or LT_VERSION_MENU_MAX - 1 times - a `while ... read` whose last
# evaluation is the failing (EOF) read still exits the whole `while`
# construct at 0 per POSIX (a loop's exit status is that of the last
# *body* run, not the failing controlling command), but this is stated
# explicitly rather than left implicit, since ask_version() calls this
# under `set -eu` and any other outcome here would abort that whole
# script.
#######################################
# Build the capped, deduped list of version-menu option labels.
# Globals:
#   LT_VERSION_MENU_MAX
# Arguments:
#   $1: default — the version to pin as the first, highlighted option
# Inputs:
#   STDIN: versions, one per line, newest-first
# Outputs:
#   Writes one menu option label per line to STDOUT.
# Returns:
#   Always 0.
#######################################
lt_version_menu_options() {
  local default="$1" v count
  printf '%s (default)\n' "$default"
  count=1
  while [ "$count" -lt "$LT_VERSION_MENU_MAX" ] && IFS= read -r v; do
    if [ "$v" != "$default" ]; then
      printf '%s\n' "$v"
      count=$((count + 1))
    fi
  done
  return 0
}

# lt_valid_menu_choice <input> <option-count> (TASK-164): is <input> a valid
# 1-based menu selection? Used by scripts/install/00_select.sh's
# lt_arrow_menu() numbered-prompt fallback (stty -g < /dev/tty failing),
# which reads a whole line via `read -r` (not one raw keypress like the
# normal arrow-mode loop's own digit-shortcut classifier), so a two-digit
# choice like "10" is a normal, expected input there - a `case ... in
# [1-9])` glob only ever matches a single character and silently rejected
# every option past 9 before this existed. Lives here rather than in
# 00_select.sh, same reasoning as lt_resolve_version_list/
# lt_version_menu_options above: no /dev/tty access, so it's unit-testable
# directly instead of only through a subprocess.
#######################################
# Check whether a string is a valid 1-based menu selection.
# Globals:
#   None
# Arguments:
#   $1: input — the raw string to validate
#   $2: n — the valid option count
# Outputs:
#   None
# Returns:
#   0 if <input> is all-digits and within 1..<n>; 1 otherwise
#######################################
lt_valid_menu_choice() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$1" -ge 1 ] && [ "$1" -le "$2" ]
}

# lt_nth_arg <n> <arg...> (TASK-165, decision-21): print the n-th (1-based)
# remaining argument. POSIX sh has no arrays, so 00_select.sh's per-language
# back-navigation loop keeps its plugin/version pairs as one flat positional-
# parameter list (via `set --`) and needs random-access-by-index into it to
# support stepping the index backward - a plain `while read` over a stream
# can only move forward. Uses `shift` on this function's own copy of the
# arguments (a function call gets its own positional parameters), so the
# caller's own "$@" is untouched.
#######################################
# Print the n-th (1-based) of the remaining arguments.
# Globals:
#   None
# Arguments:
#   $1: n — 1-based index
#   $2..: the list to index into
# Outputs:
#   The n-th argument, to STDOUT
# Returns:
#   None (undefined output if n is out of range - callers control both
#   sides of this list and keep n in range)
#######################################
lt_nth_arg() {
  local n="$1"
  shift
  while [ "$n" -gt 1 ]; do
    shift
    n=$((n - 1))
  done
  printf '%s\n' "$1"
}

# lt_render_version_table (TASK-168): render an SDKMAN `sdk list`-flavored
# numbered table from lt_version_menu_options()'s output (one option label
# per line on stdin, first line already carrying the " (default)" suffix).
# Used only by 00_select.sh's ask_version() when the terminal can't do
# raw-mode arrow-key input (stty -g failing) - that path replaces typing a
# number with a plain Enter/skip walkthrough (lt_version_walkthrough() in
# 00_select.sh), so this table is purely informational: it lets the user
# see every fetched candidate up front before being walked through them one
# at a time. No /dev/tty access here (plain stdin/stdout), so it's
# unit-testable directly, same reasoning as lt_version_menu_options above.
#######################################
# Render a numbered version table from one label per line on stdin.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   A header row, a separator line, and one numbered row per input line,
#   to STDOUT.
# Returns:
#   None
#######################################
lt_render_version_table() {
  local i=1 line
  printf '  %-4s%s\n' '#' '버전'
  printf '  %-4s%s\n' '---' '----------------'
  while IFS= read -r line; do
    printf '  %-4s%s\n' "$i)" "$line"
    i=$((i + 1))
  done
}
