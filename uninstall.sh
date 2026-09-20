#!/usr/bin/env sh
# langtoolchain — one-line uninstaller
#
#   curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 \
#     https://raw.githubusercontent.com/coralstay/langtoolchain/main/uninstall.sh | sh
#
# Thin entry point — real logic lives in scripts/uninstall/*.sh. See
# install.sh (its sibling) for a more detailed line-by-line explanation of
# this local-clone-vs-curl dispatch — the two are intentionally identical
# in structure.
set -eu

# NOTE: kept in sync by hand with install.sh's copy of these same two
# lines — see install.sh for why this can't source lib.sh instead. If you
# change the defaults here, change install.sh too.
#
# Pinned to a specific commit, not a floating branch name (TASK-117.1,
# decision-1) — see install.sh's copy of this comment for the full
# reasoning. Keep this in sync with install.sh's BRANCH default by hand.
#
# LANGTOOLCHAIN_REPO_URL / LANGTOOLCHAIN_BRANCH (TASK-117.6): same opt-in
# override as install.sh — see its copy of this comment for the reasoning.
readonly REPO_URL="${LANGTOOLCHAIN_REPO_URL:-https://github.com/coralstay/langtoolchain.git}"
readonly BRANCH="${LANGTOOLCHAIN_BRANCH:-108188739d7cf493981a1cdb89789612d2790b5a}"

# $0, not ${BASH_SOURCE[0]:-} (POSIX sh has no BASH_SOURCE) — see
# install.sh for why the -f check below is what actually does the real/
# piped-stdin discrimination, verified empirically there.
readonly SELF_PATH="$0"
if [ -n "$SELF_PATH" ] && [ -f "$SELF_PATH" ]; then
  SELF_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
  readonly SELF_DIR
fi

if [ -n "${SELF_DIR:-}" ] && [ -d "$SELF_DIR/scripts/uninstall" ]; then
  # Local clone: run in place, no network needed.
  exec sh "$SELF_DIR/scripts/uninstall/main.sh" "$@"
fi

# `curl | sh`: no local checkout exists, so fetch a throwaway one.
command -v git >/dev/null 2>&1 || {
  printf '%s%s\n' "ERROR: git is required for the one-line uninstaller " \
    "(macOS ships it with Xcode Command Line Tools)." >&2
  exit 1
}

# See install.sh's copy of this check for the reasoning — only fires once
# we're actually about to fetch over the network.
if [ -n "${LANGTOOLCHAIN_REPO_URL:-}" ] ||
   [ -n "${LANGTOOLCHAIN_BRANCH:-}" ]; then
  printf '%s%s%s%s\n' "WARNING: LANGTOOLCHAIN_REPO_URL/LANGTOOLCHAIN_BRANCH " \
    "override detected (REPO_URL=$REPO_URL, BRANCH=$BRANCH) — this source " \
    "has not been reviewed or pinned by this tool. Only use this to test " \
    "your own fork/branch." >&2
fi

# Deliberately NOT `exec`d below — see install.sh for why: exec replaces
# this process image outright, which skips the trap on the successful
# path entirely (only fires on an early failure before we get here).
WORKDIR="$(mktemp -d)"
readonly WORKDIR
trap 'rm -rf "$WORKDIR"' EXIT

# CLONE_FETCH_TIMEOUT / clone_fetch_with_timeout (TASK-145.3): see
# install.sh's copy of these for the full reasoning — a small inline
# duplicate of lt_run_with_timeout()'s (scripts/lib.sh, TASK-138.1)
# wall-clock-kill idea, since this file can't source lib.sh (no repo on
# disk yet) or rely on timeout(1)/gtimeout(1) (pre-Homebrew, decision-10)
# either. `git fetch` alone has no wall-clock cap against a DNS/TCP/TLS
# handshake blackhole (decision-10). Simpler than lt_run_with_timeout()
# though: no stdout/stderr tempfile capture, since every caller here
# already discards clone_pinned()'s output wholesale (`>/dev/null 2>&1`
# in the retry loop below).
readonly CLONE_FETCH_TIMEOUT="${LANGTOOLCHAIN_CLONE_TIMEOUT:-30}"

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

# clone_pinned <ref>: see install.sh's copy of this function for the full
# reasoning (fetches exactly <ref> — SHA, tag, or branch name — instead of
# trusting whatever a branch currently points to; `git clone --branch`
# can't reliably target an arbitrary commit SHA the way `fetch <ref>` can).
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

# Retries a transient clone failure a few times before giving up (TASK-88)
# — see install.sh for why this is an inline duplicate of lib.sh's retry()
# rather than a shared call.
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
sh "$WORKDIR/langtoolchain/scripts/uninstall/main.sh" "$@"
exit $?
