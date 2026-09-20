#!/usr/bin/env sh
# langtoolchain — one-line installer
#
#   curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 \
#     https://raw.githubusercontent.com/coralstay/langtoolchain/main/install.sh | sh
#
# This file only gets the real installer onto disk and runs it. The actual
# logic lives in scripts/install/*.sh (one file per responsibility) so it's
# easy to read, test, and modify one phase at a time — see readme.md.
#
# Any flags you pass are forwarded, e.g.:
#   curl -fsSL .../install.sh | sh -s -- --all --yes
set -eu

# Where to fetch a fresh checkout from, when there isn't one on disk already.
# NOTE: kept in sync by hand with uninstall.sh's copy of these same two
# lines. This file runs via `curl | bash` before any repo is on disk, so it
# can't `source` lib.sh for a shared constant (chicken-and-egg: lib.sh lives
# inside the very repo this script's job is to fetch). If you change the
# defaults here, change uninstall.sh too.
#
# Pinned to a specific commit, not a floating branch name (TASK-117.1,
# decision-1). Before this, `--branch main` trusted whatever `main`
# happened to point to at the exact instant curl|sh ran - a force-pushed
# bad commit landing in that window would get executed sight unseen. This
# defends against unintended branch drift, a leaked-but-limited push token,
# and gives every curl|sh run a reproducible, auditable exact commit (see
# docs/download-integrity-techniques.md #8 and decision-1 for what this
# does and does NOT defend against - a full repo/account takeover can
# rewrite this very constant too, which decision-1 explicitly puts outside
# this script's threat model).
#
# Bump the BRANCH default by hand whenever you want curl|sh to pick up work
# merged to main since the last pin: `git rev-parse origin/main` on a fresh
# checkout, paste the result here (and into uninstall.sh's copy).
#
# LANGTOOLCHAIN_REPO_URL / LANGTOOLCHAIN_BRANCH (TASK-117.6): explicit
# opt-in overrides for testing against a fork or a different ref, without
# touching the trusted default path above - decision-1's scope already
# rules out a self-referential pin defending against a full account
# takeover, so accepting an override here doesn't weaken anything the
# default path actually promised. Only fires the warning below when one of
# these is actually set, so the default (no env vars) path stays silent.
readonly REPO_URL="${LANGTOOLCHAIN_REPO_URL:-https://github.com/coralstay/langtoolchain.git}"
readonly BRANCH="${LANGTOOLCHAIN_BRANCH:-25ffaf71d7a65d69d68c1f22ca87b50d9dedca11}"

# $0 is this file's own path when it was executed from an actual file on
# disk — but POSIX sh has no BASH_SOURCE, and unlike bash, $0 is USUALLY
# non-empty even when the script's content was streamed straight into sh's
# stdin (curl | sh sets it to something like "sh", not empty). The `-f`
# check below is what actually does the discrimination: a real on-disk
# invocation gives a $0 that resolves to an existing file, while the
# piped-stdin case gives a bare interpreter name with no such file in the
# current directory. Verified empirically for both cases.
readonly SELF_PATH="$0"
if [ -n "$SELF_PATH" ] && [ -f "$SELF_PATH" ]; then
  SELF_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
  readonly SELF_DIR
fi

if [ -n "${SELF_DIR:-}" ] && [ -d "$SELF_DIR/scripts/install" ]; then
  # Running from an existing local clone — use it as-is, no network needed.
  # `exec` replaces this process instead of spawning a child, so there's no
  # extra shell left dangling once the real installer takes over.
  exec sh "$SELF_DIR/scripts/install/main.sh" "$@"
fi

# Running via `curl | bash` — there is no local checkout, so fetch one.
command -v git >/dev/null 2>&1 || {
  printf '%s%s\n' "ERROR: git is required for the one-line installer (macOS " \
    "ships it with Xcode Command Line Tools)." >&2
  exit 1
}

# Only reachable once we're actually about to fetch over the network, so
# this never fires on the local-clone shortcut above (which doesn't use
# REPO_URL/BRANCH at all).
if [ -n "${LANGTOOLCHAIN_REPO_URL:-}" ] ||
   [ -n "${LANGTOOLCHAIN_BRANCH:-}" ]; then
  printf '%s%s%s%s\n' "WARNING: LANGTOOLCHAIN_REPO_URL/LANGTOOLCHAIN_BRANCH " \
    "override detected (REPO_URL=$REPO_URL, BRANCH=$BRANCH) — this source " \
    "has not been reviewed or pinned by this tool. Only use this to test " \
    "your own fork/branch." >&2
fi

# A scratch directory for the throwaway clone.
WORKDIR="$(mktemp -d)"
readonly WORKDIR
# Clean it up no matter how this script exits (success, error, Ctrl-C).
#
# Deliberately NOT `exec`d below: exec replaces this process image outright
# (execve), which skips the shell's own exit sequence entirely — so a trap
# registered here would never fire on the common (successful) path, only
# on an early failure before we ever get there. Confirmed empirically.
# Plain invocation + explicit exit lets this trap actually run every time.
trap 'rm -rf "$WORKDIR"' EXIT

# CLONE_FETCH_TIMEOUT (TASK-145.3): wall-clock timeout, in seconds, for the
# `git fetch` inside clone_pinned() below. Same DNS/TCP/TLS-handshake-
# blackhole exposure lt_run_with_timeout() (scripts/lib.sh, TASK-138.1)
# exists to close — `git fetch` alone has no wall-clock cap, only a
# connect-then-stall guard (which never engages if the connection
# blackholes before any byte moves, decision-10) — but this file can't
# `source` lib.sh (see the note above: no repo on disk yet, chicken-and-
# egg) and can't rely on `timeout(1)`/`gtimeout(1)` either (decision-10:
# neither ships pre-Homebrew, and this file runs at the very first entry
# point, before Homebrew is guaranteed to exist). So this is a small
# inline duplicate of lt_run_with_timeout()'s wall-clock-kill idea instead
# of a shared call — same reasoning as REPO_URL/BRANCH/clone_pinned()
# itself already being duplicated rather than shared with uninstall.sh.
# Deliberately simpler than lt_run_with_timeout() though: no stdout/stderr
# tempfile capture, since every caller here already discards
# clone_pinned()'s output wholesale (`>/dev/null 2>&1` in the retry loop
# below) rather than needing it back as a string.
readonly CLONE_FETCH_TIMEOUT="${LANGTOOLCHAIN_CLONE_TIMEOUT:-30}"

# clone_fetch_with_timeout <ref>: runs the actual network step of
# clone_pinned() below (`git fetch`) under CLONE_FETCH_TIMEOUT, killing it
# if it hasn't finished in time. `kill -0` only tests whether the
# background job is still alive — a fetch that finishes before the
# watchdog wakes never gets signaled at all.
#######################################
# Run `git fetch --depth 1 origin <ref>` under a hard wall-clock timeout.
# Globals:
#   CLONE_FETCH_TIMEOUT
# Arguments:
#   $1: ref — commit SHA, tag, or branch name to fetch
# Outputs:
#   git's own (-q-quieted) output, same as any other step in clone_pinned().
# Returns:
#   124 if the fetch was killed for exceeding CLONE_FETCH_TIMEOUT;
#   otherwise git fetch's own exit status.
#######################################
clone_fetch_with_timeout() {
  local ref="$1" fetch_pid watchdog_pid status timeout_marker
  timeout_marker="$(mktemp -u)"
  git fetch -q --depth 1 origin "$ref" &
  fetch_pid=$!
  (
    sleep "$CLONE_FETCH_TIMEOUT"
    if kill -0 "$fetch_pid" 2>/dev/null; then
      : > "$timeout_marker"
      kill -TERM "$fetch_pid" 2>/dev/null
    fi
  ) &
  watchdog_pid=$!
  status=0
  wait "$fetch_pid" || status=$?
  kill "$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null
  if [ -f "$timeout_marker" ]; then
    rm -f "$timeout_marker"
    return 124
  fi
  rm -f "$timeout_marker"
  return "$status"
}

# clone_pinned <ref>: fetches exactly <ref> (a commit SHA, a tag, or a
# branch name all work the same way here) into $WORKDIR/langtoolchain -
# pinned to that ref regardless of what a same-named branch is doing right
# now. `git clone --branch` only reliably resolves refs GitHub advertises
# (branches/tags); it does not reliably accept an arbitrary commit SHA. The
# `init` + `remote add` + `fetch <ref>` + `checkout FETCH_HEAD` idiom below
# works uniformly for all three ref kinds against GitHub (which enables
# fetch-by-SHA for public repos) - verified by hand against a local bare
# repo for all three cases before adopting this (TASK-117.1).
#######################################
# Clone exactly <ref> (SHA/tag/branch) into $WORKDIR/langtoolchain.
# Globals:
#   WORKDIR
#   REPO_URL
# Arguments:
#   $1: ref — commit SHA, tag, or branch name to fetch and check out
# Outputs:
#   None of its own — git's own (-q-quieted) output passes through unless
#   the caller redirects it (the retry loop below sends it to /dev/null).
# Returns:
#   0 if every git step succeeds; non-zero (the subshell's status) if any
#   step in the init/remote/fetch/checkout chain fails (including 124 if
#   the fetch step specifically timed out).
#######################################
clone_pinned() {
  rm -rf "$WORKDIR/langtoolchain"
  mkdir -p "$WORKDIR/langtoolchain"
  (
    cd "$WORKDIR/langtoolchain" &&
    git init -q &&
    git remote add origin "$REPO_URL" &&
    clone_fetch_with_timeout "$1" &&
    git checkout -q FETCH_HEAD
  )
}

# --depth 1: only the latest commit, not the full history — this clone is
# thrown away right after, so there's no reason to download more than
# necessary.
#
# Retries a transient clone failure (network blip) a few times before
# giving up entirely (TASK-88). lib.sh's retry() isn't available here — see
# the note above on why this file can't source it — so this is a small
# inline equivalent, same idea as REPO_URL/BRANCH already being duplicated
# rather than shared.
CLONE_ATTEMPT=1
until clone_pinned "$BRANCH" >/dev/null 2>&1; do
  if [ "$CLONE_ATTEMPT" -ge 3 ]; then
    printf '%s\n' "ERROR: git clone failed after $CLONE_ATTEMPT attempts." >&2
    exit 1
  fi
  printf '%s\n' "git clone failed (attempt $CLONE_ATTEMPT/3) — retrying..." >&2
  # No explicit rm -rf here — clone_pinned() removes $WORKDIR/langtoolchain
  # itself at the start of every attempt, including the next one this loop
  # triggers.
  sleep $((CLONE_ATTEMPT * 5))
  CLONE_ATTEMPT=$((CLONE_ATTEMPT + 1))
done
sh "$WORKDIR/langtoolchain/scripts/install/main.sh" "$@"
exit $?
