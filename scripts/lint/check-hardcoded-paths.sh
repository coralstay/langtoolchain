#!/usr/bin/env sh
# check-hardcoded-paths.sh (TASK-125.3, decision-7): grep-based detector for
# the "hardcoded path/env-var instead of the shared lib.sh helper" regression
# class documented in docs/hardcoded-paths-patterns.md (TASK-125.1),
# based on real bugs fixed by TASK-57, 61, 65, 70.
#
# Checks (see docs/hardcoded-paths-patterns.md for the full rationale):
#   1. A literal ".asdf" path component instead of $ASDF_DATA_DIR /
#      lt_asdf_data_dir() / $LT_ASDF_DATA_DIR_DEFAULT.
#   2. A literal "/opt/homebrew" (Apple Silicon) or "/usr/local" (Intel)
#      Homebrew prefix instead of lt_homebrew_prefix() (TASK-148: the
#      original check only grepped the Apple Silicon side, so a script
#      that hardcoded the Intel prefix instead — the exact mirror image
#      of the TASK-61 bug this check exists to catch — passed clean).
#   3. "$HOME/.asdf" or "~/.asdf" spelled out directly instead of going
#      through the ASDF_DATA_DIR helpers above.
#
# Each check has a small, explicit allowlist for the legitimate definition
# sites in lib.sh itself (where the literal has to appear exactly once, to be
# wrapped into the helper everything else should call instead). Adding a new
# legitimate literal (e.g. a new helper's own definition) means adding one
# line to the matching allowlist below — do not widen a regex to "fix" a
# false positive without checking whether an allowlist entry is the right
# tool instead.
#
# Usage: scripts/lint/check-hardcoded-paths.sh [file ...]
#   No args: scans install.sh, uninstall.sh, scripts/lib.sh, and every
#   scripts/install/*.sh + scripts/uninstall/*.sh phase script — i.e. the
#   actual product code this class of bug hit before.
#   With args: scans exactly those files (used by CI to scan changed files,
#   or by hand to check a single file while writing it).
#
# Deliberately NOT in the default scan (TASK-125.3 smoke test found these
# would be pure false positives, not real bugs):
#   - spec/*.sh: shellspec tests legitimately assert against the literal
#     default (e.g. "defaults ASDF_DATA_DIR to $HOME/.asdf when unset") —
#     that literal is the expected *value* under test, not a hardcoded
#     shortcut a script took instead of calling the helper.
#   - scripts/lint/*.sh: this checker's own source necessarily contains the
#     literals it searches for, in its labels/patterns/allowlists.
#
# Exit status: 0 if clean, 1 if any violation was found (prints each
# violation as "file:line: message" to stderr along with the offending line).

set -eu

# ---- allowlists (file:line pairs that are the ONE legitimate definition
# site for a given literal, not a caller that should have used the helper) ----
readonly ASDF_LITERAL_ALLOWLIST='
scripts/lib.sh:LT_ASDF_DATA_DIR_NAME=
'
readonly HOMEBREW_PREFIX_ALLOWLIST='
scripts/lib.sh:arm64) echo "/opt/homebrew"
scripts/lib.sh:*)     echo "/usr/local"
'

violations=0

is_allowlisted() {
  # $1 = file, $2 = line content, $3 = allowlist (newline-separated
  # "path:substring" entries)
  local file line list old_ifs entry entry_file entry_substr
  file="$1"
  line="$2"
  list="$3"
  old_ifs="$IFS"
  IFS='
'
  for entry in $list; do
    IFS="$old_ifs"
    [ -z "$entry" ] && continue
    entry_file="${entry%%:*}"
    entry_substr="${entry#*:}"
    if [ "$file" = "$entry_file" ]; then
      case "$line" in
        *"$entry_substr"*) return 0 ;;
      esac
    fi
  done
  IFS="$old_ifs"
  return 1
}

# check <label> <grep-pattern> <allowlist> <file...>
check() {
  local label pattern allowlist file lineno content trimmed
  label="$1"
  pattern="$2"
  allowlist="$3"
  shift 3
  for file in "$@"; do
    [ -f "$file" ] || continue
    # -n: line numbers. -E: extended regex. Skip comment-only lines (leading
    # '#' after whitespace) to keep this a code check, not a prose check.
    while IFS=: read -r lineno content; do
      [ -z "${lineno:-}" ] && continue
      trimmed="${content#"${content%%[! ]*}"}"
      case "$trimmed" in
        \#*) continue ;;  # comment-only line
      esac
      if is_allowlisted "$file" "$content" "$allowlist"; then
        continue
      fi
      printf '%s:%s: %s\n  %s\n' "$file" "$lineno" "$label" "$content" >&2
      violations=$((violations + 1))
    done <<EOF
$(grep -nE "$pattern" "$file" 2>/dev/null || true)
EOF
  done
}

if [ "$#" -eq 0 ]; then
  set -- install.sh uninstall.sh scripts/lib.sh
  for f in scripts/install/*.sh scripts/uninstall/*.sh; do
    [ -f "$f" ] && set -- "$@" "$f"
  done
fi

# shellcheck disable=SC2016
# single-quoted labels/patterns deliberately keep their $ literal
check '하드코딩된 .asdf 리터럴 — $ASDF_DATA_DIR/lt_asdf_data_dir()/'\
'$LT_ASDF_DATA_DIR_DEFAULT를 대신 사용하세요 (TASK-57/65 재발 패턴)' \
  '(^|[^A-Za-z0-9_/.])\.asdf(/|["'"'"']|$)' \
  "$ASDF_LITERAL_ALLOWLIST" "$@"

check '하드코딩된 /opt/homebrew 또는 /usr/local — lt_homebrew_prefix()를 대신 사용하세요'\
' (TASK-61/148 재발 패턴, Apple Silicon·Intel Mac 중 한쪽에서 깨짐)' \
  '(/opt/homebrew|/usr/local)' \
  "$HOMEBREW_PREFIX_ALLOWLIST" "$@"

# shellcheck disable=SC2016
# single-quoted label/pattern deliberately keep their $ literal
check '하드코딩된 $HOME/.asdf 또는 ~/.asdf — ASDF_DATA_DIR 헬퍼를 대신 사용하세요' \
  '(\$HOME/\.asdf|~/\.asdf)' \
  '' "$@"

if [ "$violations" -gt 0 ]; then
  echo "" >&2
  echo "check-hardcoded-paths.sh: ${violations}건 위반 발견." >&2
  exit 1
fi

echo "check-hardcoded-paths.sh: OK — 하드코딩된 경로/환경변수 리터럴 없음."
