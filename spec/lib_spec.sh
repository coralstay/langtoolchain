# shellcheck shell=bash
# Unit tests for scripts/lib.sh - the pure-function utilities every
# install/uninstall phase script sources. No mocking needed here: these
# functions do not shell out (except run(), tested with a real no-op
# command), so failures here mean a real logic regression, not an
# environment quirk.
Describe 'scripts/lib.sh'
  Include scripts/lib.sh

  Describe 'version_core()'
    It 'extracts X.Y.Z out of an asdf vendor-version string (TASK-53)'
      When call version_core 'temurin-25.0.2+10.0.LTS'
      The output should eq '25.0.2'
    End

    It 'extracts a bare X.Y.Z version unchanged'
      When call version_core '1.94.0'
      The output should eq '1.94.0'
    End

    It 'extracts an X.Y version with no patch number'
      When call version_core '1.26'
      The output should eq '1.26'
    End

    It 'takes the first version-shaped substring when more than one exists'
      When call version_core 'go1.26.1 (built with go1.25.0)'
      The output should eq '1.26.1'
    End

    It 'prints nothing and fails for a non-numeric alias like "lts"'
      When call version_core 'lts'
      The output should eq ''
      The status should be failure
    End

    It 'prints nothing and fails for "system"'
      When call version_core 'system'
      The output should eq ''
      The status should be failure
    End
  End

  Describe 'binary_for_plugin()'
    It 'maps nodejs -> node'
      When call binary_for_plugin nodejs
      The output should eq 'node'
    End

    It 'maps java -> java'
      When call binary_for_plugin java
      The output should eq 'java'
    End

    It 'maps python -> python'
      When call binary_for_plugin python
      The output should eq 'python'
    End

    It 'maps rust -> rustc'
      When call binary_for_plugin rust
      The output should eq 'rustc'
    End

    It 'maps golang -> go'
      When call binary_for_plugin golang
      The output should eq 'go'
    End

    It 'falls back to the plugin name itself for an unknown plugin'
      When call binary_for_plugin some-custom-plugin
      The output should eq 'some-custom-plugin'
    End
  End

  Describe 'lt_companion_for_plugin() (m-7/TASK-99)'
    It 'maps nodejs -> pnpm'
      When call lt_companion_for_plugin nodejs
      The output should eq 'pnpm'
    End

    It 'maps java -> gradle'
      When call lt_companion_for_plugin java
      The output should eq 'gradle'
    End

    It 'maps python -> uv (m-12/TASK-121, decision-5)'
      When call lt_companion_for_plugin python
      The output should eq 'uv'
    End

    It 'has no companion for rust (cargo already bundled)'
      When call lt_companion_for_plugin rust
      The output should eq ''
    End

    It 'has no companion for golang (go tool already bundled)'
      When call lt_companion_for_plugin golang
      The output should eq ''
    End

    It 'has no companion for an unknown plugin'
      When call lt_companion_for_plugin some-custom-plugin
      The output should eq ''
    End
  End

  Describe 'flag_for_binary()'
    It 'uses -v for node'
      When call flag_for_binary node
      The output should eq '-v'
    End

    It 'uses -version for java'
      When call flag_for_binary java
      The output should eq '-version'
    End

    It 'uses --version for python'
      When call flag_for_binary python
      The output should eq '--version'
    End

    It 'uses --version for rustc'
      When call flag_for_binary rustc
      The output should eq '--version'
    End

    It 'uses version (no dash) for go'
      When call flag_for_binary go
      The output should eq 'version'
    End

    It 'guesses --version for an unknown binary'
      When call flag_for_binary some-unknown-tool
      The output should eq '--version'
    End
  End

  Describe 'each_tool()'
    setup() {
      tool_versions="$(mktemp)"
      cat > "$tool_versions" <<'EOF'
# a leading comment should be skipped
nodejs lts


java temurin-25.0.2+10.0.LTS
python 3.12.13
EOF
    }
    cleanup() { rm -f "$tool_versions"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'skips comment and blank lines, printing only "plugin version" pairs'
      When call each_tool "$tool_versions"
      expected="$(printf 'nodejs lts\njava temurin-25.0.2+10.0.LTS\n'\
'python 3.12.13')"
      The output should eq "$expected"
    End
  End

  Describe 'detect_rc_file()'
    It 'picks .zshrc for zsh'
      export SHELL=/bin/zsh
      When call detect_rc_file
      The output should eq "$HOME/.zshrc"
    End

    It 'picks .bash_profile for bash (macOS Terminal runs login shells)'
      export SHELL=/bin/bash
      When call detect_rc_file
      The output should eq "$HOME/.bash_profile"
    End

    It 'defaults to .zshrc for an unrecognized login shell'
      export SHELL=/usr/local/bin/fish
      When call detect_rc_file
      The output should eq "$HOME/.zshrc"
    End
  End

  Describe 'read_scope()'
    It 'defaults to "global" when the file has no scope comment'
      config="$(mktemp)"
      printf 'nodejs lts\n' > "$config"
      When call read_scope "$config"
      The output should eq 'global'
      rm -f "$config"
    End

    It 'reports "local:<dir>" when a scope comment is present'
      config="$(mktemp)"
      printf '# scope: local /Users/example/project\nnodejs lts\n' > "$config"
      When call read_scope "$config"
      The output should eq 'local:/Users/example/project'
      rm -f "$config"
    End
  End

  Describe 'append_env_var()'
    setup() { rc_file="$(mktemp)"; }
    cleanup() { rm -f "$rc_file"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'appends the line when the search pattern is not already present'
      When call append_env_var "$rc_file" 'ASDF_DATA_DIR' \
        'export ASDF_DATA_DIR="$HOME/.asdf"'
      The contents of file "$rc_file" should include 'export'\
' ASDF_DATA_DIR="$HOME/.asdf"'
    End

    It 'does not duplicate the line on a second call (idempotent re-runs)'
      append_env_var "$rc_file" 'ASDF_DATA_DIR' \
        'export ASDF_DATA_DIR="$HOME/.asdf"'
      When call append_env_var "$rc_file" 'ASDF_DATA_DIR' \
        'export ASDF_DATA_DIR="$HOME/.asdf"'
      count="$(grep -c 'ASDF_DATA_DIR' "$rc_file")"
      The variable count should eq 1
    End
  End

  Describe 'prepend_env_var()'
    setup() { rc_file="$(mktemp)"; printf 'existing line\n' > "$rc_file"; }
    cleanup() { rm -f "$rc_file"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'inserts the new line ahead of the file''s existing content'
      When call prepend_env_var "$rc_file" 'brew shellenv' \
        'eval "$(/opt/homebrew/bin/brew shellenv)"'
      The line 1 of contents of file "$rc_file" should include 'brew shellenv'
      The line 2 of contents of file "$rc_file" should eq 'existing line'
    End

    It 'does not duplicate the line on a second call (idempotent re-runs)'
      prepend_env_var "$rc_file" 'brew shellenv' \
        'eval "$(/opt/homebrew/bin/brew shellenv)"'
      When call prepend_env_var "$rc_file" 'brew shellenv' \
        'eval "$(/opt/homebrew/bin/brew shellenv)"'
      count="$(grep -c 'brew shellenv' "$rc_file")"
      The variable count should eq 1
    End
  End

  Describe 'lt_asdf_data_dir()'
    It 'prints the default $HOME/.asdf when ASDF_DATA_DIR is unset'
      unset ASDF_DATA_DIR
      When call lt_asdf_data_dir
      The output should eq "$HOME/.asdf"
    End

    It 'prints a live ASDF_DATA_DIR override instead of the default'
      export ASDF_DATA_DIR=/tmp/custom-asdf-data
      When call lt_asdf_data_dir
      The output should eq '/tmp/custom-asdf-data'
    End
  End

  Describe 'ensure_asdf_on_path()'
    It 'defaults ASDF_DATA_DIR to $HOME/.asdf when unset'
      unset ASDF_DATA_DIR
      When call ensure_asdf_on_path
      The variable ASDF_DATA_DIR should eq "$HOME/.asdf"
    End

    It 'respects an already-exported custom ASDF_DATA_DIR (TASK-57)'
      export ASDF_DATA_DIR=/tmp/custom-asdf-data
      When call ensure_asdf_on_path
      The variable ASDF_DATA_DIR should eq '/tmp/custom-asdf-data'
      The variable PATH should include '/tmp/custom-asdf-data/shims:'
    End

    It 'does not add a duplicate shims entry if PATH already has it'
      export ASDF_DATA_DIR=/tmp/custom-asdf-data
      export PATH="/tmp/custom-asdf-data/shims:$PATH"
      before="$PATH"
      When call ensure_asdf_on_path
      The variable PATH should eq "$before"
    End
  End

  Describe 'ensure_brew_on_path()'
    It 'is a no-op when brew is already resolvable on PATH'
      Mock brew
        echo mock-brew
      End
      before="$PATH"
      When call ensure_brew_on_path
      The variable PATH should eq "$before"
    End

    It 'prepends the fixed Homebrew prefix bin dir when brew is'\
' missing from PATH but installed there (TASK-78)'
      fake_prefix="$(mktemp -d)"
      mkdir -p "$fake_prefix/bin"
      printf '#!/bin/sh\necho fake-brew\n' > "$fake_prefix/bin/brew"
      chmod +x "$fake_prefix/bin/brew"
      lt_homebrew_prefix() { echo "$fake_prefix"; }
      PATH="/usr/bin:/bin"
      When call ensure_brew_on_path
      The variable PATH should include "$fake_prefix/bin:"
      rm -rf "$fake_prefix"
    End

    It 'does not error when brew is not resolvable anywhere'\
' (fixed prefix included)'
      lt_homebrew_prefix() { echo "/nonexistent-homebrew-prefix-$$"; }
      PATH="/usr/bin:/bin"
      before="$PATH"
      When call ensure_brew_on_path
      The status should be success
      The variable PATH should eq "$before"
    End
  End

  Describe 'ensure_build_flags() (batched brew --prefix)'
    It 'builds LDFLAGS/CPPFLAGS/PKG_CONFIG_PATH from one batched'\
' "brew --prefix" call, in argument order'
      # One Mocked `brew` handles both ensure_brew_on_path's `command -v brew`
      # check and the actual `--prefix openssl readline sqlite3 zlib` call -
      # its four-line output must land in the same openssl/readline/sqlite/
      # zlib order the positional-parameter split assumes.
      Mock brew
        printf '%s\n' /fake/openssl /fake/readline /fake/sqlite /fake/zlib
      End
      When call ensure_build_flags
      The variable LDFLAGS should eq '-L/fake/openssl/lib -L/fake/readline/lib'\
' -L/fake/sqlite/lib -L/fake/zlib/lib'
      The variable CPPFLAGS should eq '-I/fake/openssl/include'\
' -I/fake/readline/include -I/fake/sqlite/include -I/fake/zlib/include'
      The variable PKG_CONFIG_PATH should eq '/fake/openssl/lib/pkgconfig:'\
'/fake/readline/lib/pkgconfig:/fake/sqlite/lib/pkgconfig'
    End
  End

  Describe 'acquire_lock() / release_lock() (TASK-84)'
    setup() {
      scratch="$(mktemp -d)"
      LT_LOCK_DIR="$scratch/lt-test.lock"
    }
    cleanup() { rm -rf "$scratch"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'creates the lock dir and records this process pid'
      When call acquire_lock
      The status should be success
      The path "$LT_LOCK_DIR" should be exist
      The contents of file "$LT_LOCK_DIR/pid" should eq "$$"
    End

    It 'release_lock removes the lock dir'
      acquire_lock
      When call release_lock
      The path "$LT_LOCK_DIR" should not be exist
    End

    It 'release_lock is a no-op when no lock was ever acquired'
      When call release_lock
      The status should be success
    End

    It 'a second acquire while the first is still held by a live pid'\
' dies with a clear error'
      # acquire_lock's die() path calls a real `exit`, which would tear down
      # the shellspec runner itself under `When call` (same-process). Run it
      # as a real subprocess instead, so its exit only ends that subprocess.
      acquire_lock
      When run command env LT_LOCK_DIR="$LT_LOCK_DIR" sh -c \
        '. ./scripts/lib.sh && acquire_lock'
      The status should be failure
      The error should include 'appears to be running'
      The path "$LT_LOCK_DIR" should be exist
    End

    It 'reclaims a stale lock left by a pid that no longer exists'
      mkdir "$LT_LOCK_DIR"
      printf '999999999\n' > "$LT_LOCK_DIR/pid"
      When call acquire_lock
      The status should be success
      The contents of file "$LT_LOCK_DIR/pid" should eq "$$"
    End

    It 'reports the live winner instead of a generic failure when'\
' this process loses the stale-lock reclaim race'
      # Simulates two processes reclaiming the same stale lock at once
      # (lib.sh's own comment on this branch): pre-seed a dead pid so the
      # first check finds it stale, then make `mkdir` behave as if another
      # process's reclaim won the race right after this one's `rm -rf` -
      # the second `mkdir` "fails" but leaves behind a directory a live pid
      # actually owns, instead of leaving nothing (a real crash) behind.
      mkdir "$LT_LOCK_DIR"
      printf '999999999\n' > "$LT_LOCK_DIR/pid"
      When run command env LT_LOCK_DIR="$LT_LOCK_DIR" sh -c '
        . ./scripts/lib.sh
        mkdir() {
          if [ "$1" = "$LT_LOCK_DIR" ] && [ -d "$LT_LOCK_DIR" ]; then
            command mkdir "$LT_LOCK_DIR" 2>/dev/null
            echo $$ > "$LT_LOCK_DIR/pid"
            return 1
          fi
          command mkdir "$@"
        }
        acquire_lock
      '
      The status should be failure
      The error should include 'appears to be running'
      The error should not include 'Could not acquire lock'
    End
  End

  Describe 'lt_die_if_lock_held()'
    setup() {
      scratch="$(mktemp -d)"
      LT_LOCK_DIR="$scratch/lt-test.lock"
      mkdir "$LT_LOCK_DIR"
    }
    cleanup() { rm -rf "$scratch"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'is a no-op when there is no pid file'
      When call lt_die_if_lock_held
      The status should be success
    End

    It 'is a no-op when the recorded pid is no longer alive'
      printf '999999999\n' > "$LT_LOCK_DIR/pid"
      When call lt_die_if_lock_held
      The status should be success
    End

    It 'dies with a clear message when the recorded pid is alive'
      printf '%s\n' "$$" > "$LT_LOCK_DIR/pid"
      When run command env LT_LOCK_DIR="$LT_LOCK_DIR" sh -c \
        '. ./scripts/lib.sh && lt_die_if_lock_held'
      The status should be failure
      The error should include 'appears to be running'
    End
  End

  Describe 'retry() (TASK-88)'
    It 'returns success immediately when the command succeeds on the first try'
      When call retry 3 1 true
      The status should be success
    End

    It 'retries and succeeds once a later attempt works'
      Mock sleep
        :
      End
      attempt_file="$(mktemp)"
      printf '0' > "$attempt_file"
      flaky() {
        n="$(cat "$attempt_file")"
        n=$((n + 1))
        printf '%s' "$n" > "$attempt_file"
        [ "$n" -ge 2 ]
      }
      When call retry 3 1 flaky
      The status should be success
      The output should include 'attempt 1/3 failed'
      The contents of file "$attempt_file" should eq '2'
      rm -f "$attempt_file"
    End

    It 'fails after exhausting all attempts'
      Mock sleep
        :
      End
      When call retry 2 1 false
      The status should be failure
      The output should include 'attempt 1/2 failed'
    End
  End

  Describe 'lt_run_with_timeout() (TASK-138.1, decision-10)'
    It 'returns the command exit status when it finishes before the timeout'
      When call lt_run_with_timeout 5 true
      The status should be success
    End

    It 'propagates a failing command status when it finishes in time'
      When call lt_run_with_timeout 5 false
      The status should be failure
    End

    It 'still prints the command output when it finishes in time'
      When call lt_run_with_timeout 5 echo 'inside the timeout'
      The output should eq 'inside the timeout'
    End

    It 'returns promptly once the command finishes, not after the full timeout'
      start_ts=$(date +%s)
      lt_run_with_timeout 30 true
      end_ts=$(date +%s)
      elapsed=$((end_ts - start_ts))
      fast_enough=false
      [ "$elapsed" -lt 10 ] && fast_enough=true
      When call true
      The variable fast_enough should eq 'true'
    End

    It 'kills a command that never finishes on its own and returns 124'
      # Simulates decision-10's DNS/TCP/TLS handshake blackhole - a command
      # that would otherwise hang forever - without touching a real network.
      never_ending() { sleep 30; }
      start_ts=$(date +%s)
      status=0
      lt_run_with_timeout 1 never_ending || status=$?
      end_ts=$(date +%s)
      elapsed=$((end_ts - start_ts))
      killed_in_time=false
      [ "$status" -eq 124 ] && [ "$elapsed" -lt 10 ] && killed_in_time=true
      When call true
      The variable killed_in_time should eq 'true'
    End
  End

  Describe 'ensure_disk_space() (TASK-91)'
    It 'passes when there is enough free space'
      Mock df
        printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted' \
          '/dev/disk1 100000000 0 10485760 1% /'
      End
      When call ensure_disk_space 5
      The status should be success
    End

    It 'dies with a clear message when free space is below the threshold'
      # Real `exit` inside die() - run as a subprocess (same reasoning as
      # acquire_lock's die() path above), with `df` Mocked for that
      # subprocess too since Mock's PATH change is example-scoped.
      Mock df
        printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted' \
          '/dev/disk1 100000000 0 1048576 1% /'
      End
      When run command sh -c '. ./scripts/lib.sh && ensure_disk_space 5'
      The status should be failure
      The error should include 'Only 1GB free'
    End
  End

  Describe 'handle_interrupt() (TASK-90)'
    It 'prints a clear interrupted message and exits 130'
      # Real `exit`, so run as a subprocess rather than `When call` in this
      # same process — same reasoning as acquire_lock's die() path above.
      When run command sh -c '. ./scripts/lib.sh && handle_interrupt'
      The status should equal 130
      The output should include 'Interrupted'
    End

    It 'kills the tracked LT_CHILD_PID before exiting'
      # Everything - the background sleep, the kill, and the liveness poll -
      # runs inside one subprocess script, not directly in this It block:
      # a bare `sleep 30 &` started straight in shellspec's own evaluation
      # shell leaks its async "Terminated" job-control notification into
      # shellspec's own signal handling once killed, which shellspec then
      # misreads as this example itself having been interrupted (an
      # "Example aborted" false failure, not a real one - the actual
      # regression to catch is only about handle_interrupt's own kill).
      runner_script="$(mktemp)"
      cat > "$runner_script" <<'RUNNER_EOF'
# The shell's own async "job N Terminated" notification for the killed
# background sleep below is diagnostic noise, not this test's concern -
# silence it rather than let it register as unexpected stderr output.
exec 2>/dev/null
sleep 30 &
child_pid=$!
# LT_CHILD_PID must be set AFTER sourcing lib.sh, not via env before it -
# lib.sh's own top-level `LT_CHILD_PID=""` initialization would otherwise
# clobber an inherited env value right back to empty, same as it does on
# every real run_phase() invocation between phases.
sh -c ". ./scripts/lib.sh; LT_CHILD_PID=$child_pid;\
 handle_interrupt" >/dev/null 2>&1
child_alive=true
i=0
while [ "$i" -lt 20 ]; do
  kill -0 "$child_pid" 2>/dev/null || { child_alive=false; break; }
  sleep 0.1
  i=$((i + 1))
done
echo "child_alive:$child_alive"
# safety net if the loop above ever finds it still alive
kill "$child_pid" 2>/dev/null
exit 0
RUNNER_EOF
      When run command sh "$runner_script"
      The output should include 'child_alive:false'
      rm -f "$runner_script"
    End
  End

  Describe 'run_phase() (TASK-93)'
    It "returns the phase script's own exit status instead of always 0"
      phase_script="$(mktemp)"
      echo 'exit 1' > "$phase_script"
      When call run_phase "$phase_script"
      The status should be failure
      rm -f "$phase_script"
    End

    It 'returns success when the phase script succeeds'
      phase_script="$(mktemp)"
      echo 'exit 0' > "$phase_script"
      When call run_phase "$phase_script"
      The status should be success
      rm -f "$phase_script"
    End

    It 'clears LT_CHILD_PID once the phase has finished'
      phase_script="$(mktemp)"
      echo 'exit 0' > "$phase_script"
      run_phase "$phase_script"
      The variable LT_CHILD_PID should eq ''
      rm -f "$phase_script"
    End

    It 'terminates a long-running phase promptly on SIGTERM instead'\
' of waiting for it to finish (regression)'
      # Reproduces the exact TASK-32/TASK-93 CI failure at unit-test speed:
      # a phase mid-sleep must be killed and its lock released the instant
      # SIGTERM arrives, not only after the phase finishes naturally.
      phase_script="$(mktemp)"
      echo 'sleep 30' > "$phase_script"
      runner_script="$(mktemp)"
      cat > "$runner_script" <<'RUNNER_EOF'
. ./scripts/lib.sh
trap 'handle_interrupt' INT TERM
run_phase "$1" &
runner_pid=$!
sleep 1
kill -TERM "$runner_pid"
wait "$runner_pid" 2>/dev/null
exit 0
RUNNER_EOF
      start_ts=$(date +%s)
      sh "$runner_script" "$phase_script" || true
      end_ts=$(date +%s)
      elapsed=$((end_ts - start_ts))
      # 1s built-in delay before the kill, generous slack for CI jitter -
      # nowhere near the 30s the un-fixed bug would have blocked for.
      fast_enough=false
      [ "$elapsed" -lt 10 ] && fast_enough=true
      When call true
      The variable fast_enough should eq 'true'
      rm -f "$phase_script" "$runner_script"
    End
  End

  Describe 'run()'
    It 'executes the command for real when DRY_RUN is false'
      DRY_RUN=false
      When call run echo hello-from-run
      The output should eq 'hello-from-run'
    End

    It 'only prints what would run, prefixed with "+", under DRY_RUN=true'
      DRY_RUN=true
      When call run echo hello-from-run
      The output should eq '  + echo hello-from-run'
    End
  End

  Describe 'lt_report() (m-10/TASK-107)'
    setup() { LT_REPORT_FILE="$(mktemp)"; }
    cleanup() { rm -f "$LT_REPORT_FILE"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'appends a timestamped action/detail line when DRY_RUN is false'
      DRY_RUN=false
      When call lt_report installed 'asdf plugin: pnpm'
      The status should be success
      The contents of file "$LT_REPORT_FILE" should include '[installed]'\
' asdf plugin: pnpm'
      # e.g. "2026-08-30 12:34:56 [installed] ..." - a real date, not
      # literal text.
      The contents of file "$LT_REPORT_FILE" should match pattern '[0-9][0-9]'\
'[0-9][0-9]-*'
    End

    It 'writes nothing under DRY_RUN=true - a preview made no real'\
' change to report'
      DRY_RUN=true
      When call lt_report installed 'asdf plugin: pnpm'
      The status should be success
      The contents of file "$LT_REPORT_FILE" should eq ''
    End

    It 'appends multiple calls as separate lines, not overwriting'
      DRY_RUN=false
      lt_report installed 'first'
      lt_report removed 'second'
      # awk, not `wc -l` - BSD wc (macOS) pads its count with leading
      # whitespace ("       2"), which a plain numeric `eq` comparison
      # would then fail on.
      count="$(awk 'END { print NR }' "$LT_REPORT_FILE")"
      When call true
      The variable count should eq 2
    End
  End

  Describe 'lt_snapshot_prior_asdf_state() / lt_prior_state_get()'\
' (m-13/TASK-123, decision-6)'
    # SAFETY: `brew`/`asdf` are always Mocked below, never left to resolve
    # for real - same reasoning as purge_asdf_core_spec.sh/
    # bootstrap_asdf_spec.sh's own header comments (this dev machine has a
    # real Homebrew-installed asdf; a Mock is what actually shadows it
    # regardless of PATH, since it wins the lookup first). Genuine "asdf is
    # not resolvable at all" isn't exercised here for the same reason those
    # two files don't either - Mock necessarily creates A resolvable
    # command, so `command -v asdf` can't be made to fail this way; that
    # gap is covered by e2e-verify.yml on real, disposable CI hardware.
    # `ASDF_DATA_DIR` is set explicitly to a scratch dir in every test below
    # (a live override), never left to fall back to lt_asdf_data_dir()'s
    # $HOME-derived default - LT_ASDF_DATA_DIR_DEFAULT is computed once,
    # from the REAL $HOME, at the point `Include scripts/lib.sh` sources
    # this file, so overriding $HOME inside a single example afterward
    # wouldn't actually change it (unlike ASDF_DATA_DIR, which
    # lt_asdf_data_dir() re-reads live on every call).
    setup() {
      fake_home="$(mktemp -d)"
      LT_PRIOR_STATE_FILE="$fake_home/.langtoolchain-prior-asdf-state"
      export DRY_RUN=false
      export ASDF_DATA_DIR="$fake_home/.asdf"
    }
    cleanup() { rm -rf "$fake_home"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'records everything as pre-existing when asdf/its data'\
' dir/plugins already exist'
      Mock brew
        case "$1 $2" in
          "list asdf") exit 0 ;;
        esac
      End
      Mock asdf
        case "$1 $2" in
          "plugin list") printf '%s\n' nodejs java ;;
        esac
      End
      mkdir -p "$ASDF_DATA_DIR/shims"
      When call lt_snapshot_prior_asdf_state
      The status should be success
      The contents of file "$LT_PRIOR_STATE_FILE" should include \
        'asdf_preexisting=true'
      The contents of file "$LT_PRIOR_STATE_FILE" should include \
        "asdf_data_dir=$ASDF_DATA_DIR"
      The contents of file "$LT_PRIOR_STATE_FILE" should include \
        'asdf_data_dir_preexisting=true'
      The contents of file "$LT_PRIOR_STATE_FILE" should include \
        'asdf_plugins_preexisting=nodejs java'
    End

    It 'records asdf/its data dir as NOT pre-existing on what looks'\
' like a fresh machine'
      Mock brew
        case "$1 $2" in
          "list asdf") exit 1 ;;
        esac
      End
      Mock asdf
        case "$1 $2" in
          "plugin list") exit 1 ;;
        esac
      End
      When call lt_snapshot_prior_asdf_state
      The status should be success
      The contents of file "$LT_PRIOR_STATE_FILE" should include \
        'asdf_preexisting=false'
      The contents of file "$LT_PRIOR_STATE_FILE" should include \
        'asdf_data_dir_preexisting=false'
      The contents of file "$LT_PRIOR_STATE_FILE" should include \
        'asdf_plugins_preexisting='
    End

    It 'does not overwrite an existing snapshot on a second call'\
' (re-run safety)'
      Mock brew
        case "$1 $2" in
          "list asdf") exit 0 ;;
        esac
      End
      Mock asdf
        case "$1 $2" in
          "plugin list") printf '%s\n' nodejs ;;
        esac
      End
      printf 'asdf_preexisting=false\n'\
'asdf_data_dir=/original\n'\
'asdf_data_dir_preexisting=false\n'\
'asdf_plugins_preexisting=\n' > "$LT_PRIOR_STATE_FILE"
      When call lt_snapshot_prior_asdf_state
      The status should be success
      The contents of file "$LT_PRIOR_STATE_FILE" should include \
        'asdf_data_dir=/original'
      The contents of file "$LT_PRIOR_STATE_FILE" should not include 'nodejs'
    End

    It 'writes nothing under DRY_RUN=true - a preview must not'\
' create a fake baseline'
      DRY_RUN=true
      Mock brew
        case "$1 $2" in
          "list asdf") exit 0 ;;
        esac
      End
      Mock asdf
        case "$1 $2" in
          "plugin list") printf '%s\n' nodejs ;;
        esac
      End
      When call lt_snapshot_prior_asdf_state
      The status should be success
      The path "$LT_PRIOR_STATE_FILE" should not be exist
    End

    It 'lt_prior_state_get reads back a key written by the snapshot'
      printf 'asdf_preexisting=true\n'\
'asdf_data_dir=/x/.asdf\n'\
'asdf_data_dir_preexisting=true\n'\
'asdf_plugins_preexisting=nodejs java\n' > "$LT_PRIOR_STATE_FILE"
      When call lt_prior_state_get asdf_data_dir_preexisting
      The output should eq 'true'
    End

    It 'lt_prior_state_get fails for a key not present in an existing file'
      printf 'asdf_preexisting=true\n' > "$LT_PRIOR_STATE_FILE"
      When call lt_prior_state_get asdf_data_dir_preexisting
      The status should be failure
      The output should eq ''
    End

    It 'lt_prior_state_get fails when the snapshot file does not exist at all'
      When call lt_prior_state_get asdf_data_dir_preexisting
      The status should be failure
      The output should eq ''
    End
  End

  Describe 'lt_upstream_latest_version() (m-12/TASK-119, decision-4)'
    # Every case below mocks curl/git so these tests never touch the real
    # network (mandatory for this repo - see spec_helper/README safety
    # rules) - each Mock's canned response is a trimmed real-shape fixture
    # captured from the actual upstream API/manifest during TASK-118's
    # research, not an invented shape.

    It 'passes nodejs straight through as "lts" - no network call at all'
      Mock curl
        echo 'MOCK CURL SHOULD NEVER RUN FOR nodejs' >&2
        exit 1
      End
      When call lt_upstream_latest_version nodejs
      The status should be success
      The output should eq 'lts'
    End

    It 'extracts the version field from the npm registry for pnpm'
      Mock curl
        echo '{"name":"pnpm","version":"12.3.1","dist":{"shasum":"x"}}'
      End
      When call lt_upstream_latest_version pnpm
      The status should be success
      The output should eq '12.3.1'
    End

    It 'extracts the version field from services.gradle.org for gradle'
      Mock curl
        echo '{"version":"9.7.1","current":true,"snapshot":false}'
      End
      When call lt_upstream_latest_version gradle
      The status should be success
      The output should eq '9.7.1'
    End

    It 'extracts the tag_name from GitHub Releases for uv'\
' (m-12/TASK-121, decision-5)'
      Mock curl
        echo '{"tag_name":"0.12.9","name":"0.12.9",'\
'"draft":false,"prerelease":false}'
      End
      When call lt_upstream_latest_version uv
      The status should be success
      The output should eq '0.12.9'
    End

    It 'extracts and strips the "go" prefix from go.dev/dl for golang'
      Mock curl
        echo '[{"version":"go1.27.1","stable":true},'\
'{"version":"go1.26.1","stable":true}]'
      End
      When call lt_upstream_latest_version golang
      The status should be success
      The output should eq '1.27.1'
    End

    It 'extracts the [pkg.rust] version from the channel manifest for rust'
      Mock curl
        printf 'manifest-version = "2"\ndate = "2026-08-20"\n\n[pkg.cargo]\n'\
'version = "0.99.0 (deadbeef 2026-08-05)"\n\n[pkg.rust]\n'\
'version = "1.98.0 (88d9e12ae 2026-08-18)"\ngit_commit_hash = "88d9e12ae"\n'
      End
      When call lt_upstream_latest_version rust
      The status should be success
      The output should eq '1.98.0'
    End

    It 'filters cpython pre-release tags and numerically sorts'\
' final releases for python'
      Mock git
        printf 'aaa\trefs/tags/v3.9.9\n'
        printf 'bbb\trefs/tags/v3.14.7\n'
        printf 'ccc\trefs/tags/v3.14.7rc1\n'
        printf 'ddd\trefs/tags/v3.14.10\n'
        printf 'eee\trefs/tags/v3.14.7a1\n'
        printf 'fff\trefs/tags/v3.14.2\n'
      End
      When call lt_upstream_latest_version python
      The status should be success
      # 3.14.10 must sort after 3.14.7/3.14.9 numerically (field-by-field),
      # not lexicographically (where "3.14.10" < "3.14.7" as plain text) -
      # this is exactly the macOS-BSD-sort-has-no--V gap the implementation
      # comment calls out.
      The output should eq '3.14.10'
    End

    It 'fails quickly instead of hanging forever when git ls-remote'\
' blackholes (TASK-138.2, decision-10)'
      # Simulates the DNS/TCP/TLS handshake blackhole decision-10 describes:
      # git never returns anything, ever. Without lt_run_with_timeout
      # wrapping this call, this test would hang for real (no network used -
      # the mock just sleeps) instead of failing fast.
      Mock git
        sleep 30
      End
      LT_PYTHON_TAGS_TIMEOUT=1
      start_ts=$(date +%s)
      status=0
      lt_upstream_latest_version python >/dev/null || status=$?
      end_ts=$(date +%s)
      elapsed=$((end_ts - start_ts))
      failed_fast=false
      [ "$status" -ne 0 ] && [ "$elapsed" -lt 10 ] && failed_fast=true
      When call true
      The variable failed_fast should eq 'true'
    End

    It 'resolves the current LTS major then its latest GA build for'\
' java (two curl calls)'
      Mock curl
        case "$*" in
          *available_releases*)
            echo '{"available_lts_releases":[8,11,17,21,25],'\
'"most_recent_lts":25}'
            ;;
          *assets/latest*)
            echo '{"version":{"semver":"25.0.4+101.0.LTS"}}'
            ;;
          *)
            exit 1
            ;;
        esac
      End
      When call lt_upstream_latest_version java
      The status should be success
      The output should eq 'temurin-25.0.4+101.0.LTS'
    End

    It 'fails without printing anything for an unknown plugin'
      When call lt_upstream_latest_version some-unmapped-plugin
      The status should be failure
      The output should eq ''
    End

    It 'fails cleanly (not a script abort) when the network call itself fails'
      Mock curl
        exit 1
      End
      When call lt_upstream_latest_version pnpm
      The status should be failure
      The output should eq ''
    End

    It 'fails cleanly when java second call (asset lookup) fails'\
' after the first succeeds'
      Mock curl
        case "$*" in
          *available_releases*) echo '{"most_recent_lts":25}' ;;
          *) exit 1 ;;
        esac
      End
      When call lt_upstream_latest_version java
      The status should be failure
      The output should eq ''
    End

    It 'fails cleanly (TASK-146) when the asset lookup succeeds but its'\
' body has no parseable semver'
      Mock curl
        case "$*" in
          *available_releases*) echo '{"most_recent_lts":25}' ;;
          *assets/latest*) echo '{"version":{}}' ;;
          *) exit 1 ;;
        esac
      End
      When call lt_upstream_latest_version java
      The status should be failure
      The output should eq ''
    End
  End

  Describe 'lt_upstream_version_list() (m-15/TASK-128.1, decision-15)'
    # Same "never touch the real network" rule as lt_upstream_latest_
    # version() above - every example mocks curl/git with a trimmed
    # real-shape fixture captured from the actual upstream API during
    # this task's research, not an invented shape.

    It 'fetches nodejs.org/dist/index.json and strips the "v" prefix -'\
' unlike the single-value branch, this one DOES call the network'
      Mock curl
        echo '[{"version":"v26.8.1","lts":false},'\
'{"version":"v26.8.0","lts":false},'\
'{"version":"v24.10.0","lts":"Krypton"}]'
      End
      When call lt_upstream_version_list nodejs
      The status should be success
      The line 1 of output should eq '26.8.1'
      The line 2 of output should eq '26.8.0'
      The line 3 of output should eq '24.10.0'
    End

    It 'extracts clean semver keys from the pnpm registry doc and sorts'\
' them newest-first, dropping dev/beta channel tags'
      Mock curl
        echo '{"name":"pnpm","versions":{'\
'"9.5.0":{"name":"pnpm"},'\
'"12.3.1":{"name":"pnpm"},'\
'"6.23.7-202112041634":{"name":"pnpm"}'\
'}}'
      End
      When call lt_upstream_version_list pnpm
      The status should be success
      The line 1 of output should eq '12.3.1'
      The line 2 of output should eq '9.5.0'
      The lines of output should eq 2
    End

    It 'keeps only final GA gradle releases (snapshot=false, no rcFor/'\
'milestoneFor) and sorts them newest-first'
      Mock curl
        printf '%s\n' '[ {' \
          '  "version" : "9.6.0",' \
          '  "snapshot" : false,' \
          '  "rcFor" : "",' \
          '  "milestoneFor" : ""' \
          '}, {' \
          '  "version" : "9.8.0-20260905023534+0000",' \
          '  "snapshot" : true,' \
          '  "rcFor" : "",' \
          '  "milestoneFor" : ""' \
          '}, {' \
          '  "version" : "9.8.0-rc-1",' \
          '  "snapshot" : false,' \
          '  "rcFor" : "9.8.0",' \
          '  "milestoneFor" : ""' \
          '}, {' \
          '  "version" : "9.7.1",' \
          '  "snapshot" : false,' \
          '  "rcFor" : "",' \
          '  "milestoneFor" : ""' \
          '} ]'
      End
      When call lt_upstream_version_list gradle
      The status should be success
      The line 1 of output should eq '9.7.1'
      The line 2 of output should eq '9.6.0'
      The lines of output should eq 2
    End

    It 'keeps only stable golang releases from the ?include=all index,'\
' ignoring "version" fields nested inside each files[] entry'
      Mock curl
        printf '%s\n' '[' \
          ' {' \
          '  "version": "go1.27.1",' \
          '  "stable": true,' \
          '  "files": [' \
          '   {' \
          '    "filename": "go1.27.1.src.tar.gz",' \
          '    "version": "go1.27.1"' \
          '   }' \
          '  ]' \
          ' },' \
          ' {' \
          '  "version": "go1.27.0-rc1",' \
          '  "stable": false,' \
          '  "files": []' \
          ' },' \
          ' {' \
          '  "version": "go1.26.8",' \
          '  "stable": true,' \
          '  "files": []' \
          ' }' \
          ']'
      End
      When call lt_upstream_version_list golang
      The status should be success
      The line 1 of output should eq '1.27.1'
      The line 2 of output should eq '1.26.8'
      The lines of output should eq 2
    End

    It 'lists rust-lang/rust GitHub release tags, dropping drafts/'\
'prereleases (rust has no full-history JSON index of its own, decision-15)'
      Mock curl
        printf '%s\n' '[' \
          '  {' \
          '    "tag_name": "1.98.1",' \
          '    "draft": false,' \
          '    "prerelease": false' \
          '  },' \
          '  {' \
          '    "tag_name": "1.98.0",' \
          '    "draft": false,' \
          '    "prerelease": false' \
          '  },' \
          '  {' \
          '    "tag_name": "1.99.0-beta.1",' \
          '    "draft": false,' \
          '    "prerelease": true' \
          '  }' \
          ']'
      End
      When call lt_upstream_version_list rust
      The status should be success
      The line 1 of output should eq '1.98.1'
      The line 2 of output should eq '1.98.0'
      The lines of output should eq 2
    End

    It 'lists every final cpython tag (not just the highest one) sorted'\
' newest-first, still filtering pre-releases like the single-value branch'
      Mock git
        printf 'aaa\trefs/tags/v3.9.9\n'
        printf 'bbb\trefs/tags/v3.14.7\n'
        printf 'ccc\trefs/tags/v3.14.7rc1\n'
        printf 'ddd\trefs/tags/v3.14.10\n'
        printf 'eee\trefs/tags/v3.14.7a1\n'
        printf 'fff\trefs/tags/v3.14.2\n'
      End
      When call lt_upstream_version_list python
      The status should be success
      The line 1 of output should eq '3.14.10'
      The line 2 of output should eq '3.14.7'
      The line 3 of output should eq '3.14.2'
      The line 4 of output should eq '3.9.9'
      The lines of output should eq 4
    End

    It 'lists one entry per available LTS major (newest major first),'\
' silently skipping a major with no build for this Mac (e.g. no aarch64'\
' JDK for major 8, confirmed against a live Adoptium fetch)'
      Mock curl
        case "$*" in
          *available_releases*)
            printf '%s\n' '{' \
              '    "available_lts_releases": [' \
              '        8,' \
              '        11,' \
              '        17' \
              '    ]' \
              '}'
            ;;
          */assets/latest/17/*) echo '{"version":{"semver":"17.0.20+101"}}' ;;
          */assets/latest/11/*) echo '{"version":{"semver":"11.0.32+101"}}' ;;
          */assets/latest/8/*) echo '[]' ;;
          *) exit 1 ;;
        esac
      End
      When call lt_upstream_version_list java
      The status should be success
      The line 1 of output should eq 'temurin-17.0.20+101'
      The line 2 of output should eq 'temurin-11.0.32+101'
      The lines of output should eq 2
    End

    It 'fails (not succeeds with empty output) when every LTS major'\
' comes back empty - never lets a per-major skip leak into the overall'\
' exit status (would also abort a set -eu caller mid-loop otherwise)'
      Mock curl
        case "$*" in
          *available_releases*)
            printf '%s\n' '{' \
              '    "available_lts_releases": [' \
              '        8' \
              '    ]' \
              '}'
            ;;
          *) echo '[]' ;;
        esac
      End
      When call lt_upstream_version_list java
      The status should be failure
      The output should eq ''
    End

    It 'lists astral-sh/uv GitHub release tags the same way as rust'\
' above (m-12/TASK-121, decision-5 companion pick for python)'
      Mock curl
        printf '%s\n' '[' \
          '  {' \
          '    "tag_name": "0.12.10",' \
          '    "draft": false,' \
          '    "prerelease": false' \
          '  },' \
          '  {' \
          '    "tag_name": "0.12.9",' \
          '    "draft": false,' \
          '    "prerelease": false' \
          '  },' \
          '  {' \
          '    "tag_name": "0.13.0-rc.1",' \
          '    "draft": false,' \
          '    "prerelease": true' \
          '  }' \
          ']'
      End
      When call lt_upstream_version_list uv
      The status should be success
      The line 1 of output should eq '0.12.10'
      The line 2 of output should eq '0.12.9'
      The lines of output should eq 2
    End

    It 'fails without printing anything for an unknown plugin'
      When call lt_upstream_version_list some-unmapped-plugin
      The status should be failure
      The output should eq ''
    End

    It 'fails cleanly (not a script abort) when the network call itself'\
' fails'
      Mock curl
        exit 1
      End
      When call lt_upstream_version_list pnpm
      The status should be failure
      The output should eq ''
    End
  End

  Describe 'lt_upstream_version_list() covers every companion plugin'\
' lt_companion_for_plugin() can return (m-15/TASK-128.2)'
    # 128.1 already gave pnpm/gradle/uv their own branches in
    # lt_upstream_version_list() (they're plain asdf plugin names, same as
    # any language) - this Describe block is the 128.2 deliverable itself:
    # proof that the companion each language actually points to (not a
    # hardcoded plugin name guessed by the test) resolves to a working
    # branch, so the wiring between lt_companion_for_plugin() and
    # lt_upstream_version_list() is what's under test, not the parsing
    # logic already covered above.

    It "resolves nodejs's companion (pnpm)"
      companion="$(lt_companion_for_plugin nodejs)"
      Mock curl
        echo '{"name":"pnpm","versions":{"12.3.1":{"name":"pnpm"}}}'
      End
      When call lt_upstream_version_list "$companion"
      The status should be success
      The output should eq '12.3.1'
    End

    It "resolves java's companion (gradle)"
      companion="$(lt_companion_for_plugin java)"
      Mock curl
        printf '%s\n' '[ {' \
          '  "version" : "9.7.1",' \
          '  "snapshot" : false,' \
          '  "rcFor" : "",' \
          '  "milestoneFor" : ""' \
          '} ]'
      End
      When call lt_upstream_version_list "$companion"
      The status should be success
      The output should eq '9.7.1'
    End

    It "resolves python's companion (uv, decision-5)"
      companion="$(lt_companion_for_plugin python)"
      Mock curl
        printf '%s\n' '[' \
          '  {' \
          '    "tag_name": "0.12.10",' \
          '    "draft": false,' \
          '    "prerelease": false' \
          '  }' \
          ']'
      End
      When call lt_upstream_version_list "$companion"
      The status should be success
      The output should eq '0.12.10'
    End

    It 'rust and golang have no companion (by design, see'\
' lt_companion_for_plugin()) - nothing for this function to resolve'
      When call lt_companion_for_plugin rust
      The output should eq ''
    End
  End

  Describe 'lt_resolve_default_version() (m-12/TASK-119.2/TASK-119.3)'
    # Every example here points the cache at a scratch file, never the real
    # $HOME/.langtoolchain-version-cache - lt_resolve_default_version's
    # success path writes to LT_VERSION_CACHE_FILE, and this repo's own
    # safety rule is that tests never touch real machine state.
    setup() {
      LT_VERSION_CACHE_FILE="$(mktemp)"
      rm -f "$LT_VERSION_CACHE_FILE"
    }
    cleanup() { rm -f "$LT_VERSION_CACHE_FILE"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'prefers the dynamic lookup when it succeeds (and caches it)'
      Mock curl
        echo '{"version":"12.3.1"}'
      End
      When call lt_resolve_default_version pnpm '10.33.0'
      The status should be success
      The output should eq '12.3.1'
      The contents of file "$LT_VERSION_CACHE_FILE" should include 'pnpm|||'
      The contents of file "$LT_VERSION_CACHE_FILE" should include '|||12.3.1'
    End

    It 'falls back to the static default when the dynamic lookup'\
' fails (and does not cache it)'
      Mock curl
        exit 1
      End
      When call lt_resolve_default_version pnpm '10.33.0'
      The status should be success
      The output should eq '10.33.0'
      The path "$LT_VERSION_CACHE_FILE" should not be exist
    End

    It 'falls back to the static default for a plugin'\
' lt_upstream_latest_version does not map'
      When call lt_resolve_default_version some-unmapped-plugin '1.2.3'
      The status should be success
      The output should eq '1.2.3'
    End

    It 'never fails itself even when the network is completely'\
' unreachable (install must not stop)'
      Mock curl
        exit 7
      End
      Mock git
        exit 1
      End
      When call lt_resolve_default_version python '3.12.13'
      The status should be success
      The output should eq '3.12.13'
    End

    It 'reuses a fresh cache entry instead of calling curl again'
      Mock curl
        echo 'MOCK CURL SHOULD NOT RUN - CACHE SHOULD HAVE SHORT-CIRCUITED' >&2
        exit 1
      End
      printf 'pnpm|||%s|||9.9.9\n' "$(date +%s)" > "$LT_VERSION_CACHE_FILE"
      When call lt_resolve_default_version pnpm '10.33.0'
      The status should be success
      The output should eq '9.9.9'
    End

    It 'ignores a stale (past-TTL) cache entry and re-fetches'
      LT_VERSION_CACHE_TTL=60
      # 3600s old - well past a 60s TTL.
      printf 'pnpm|||%s|||9.9.9\n' "$(($(date +%s) - 3600))" \
        > "$LT_VERSION_CACHE_FILE"
      Mock curl
        echo '{"version":"12.3.1"}'
      End
      When call lt_resolve_default_version pnpm '10.33.0'
      The status should be success
      The output should eq '12.3.1'
    End

    It 'treats a future-timestamped cache entry (clock skew) as'\
' stale and re-fetches'
      # ts 3600s in the future - e.g. the system clock jumped forward
      # and then got corrected back by NTP. now - ts is negative here,
      # which must not be misread as "well under the TTL".
      printf 'pnpm|||%s|||9.9.9\n' "$(($(date +%s) + 3600))" \
        > "$LT_VERSION_CACHE_FILE"
      Mock curl
        echo '{"version":"12.3.1"}'
      End
      When call lt_resolve_default_version pnpm '10.33.0'
      The status should be success
      The output should eq '12.3.1'
    End

    It 'only refreshes the plugin it looked up - other cached'\
' plugins are left alone'
      printf 'pnpm|||%s|||9.9.9\n' "$(date +%s)" > "$LT_VERSION_CACHE_FILE"
      Mock curl
        echo '{"version":"9.7.1"}'
      End
      When call lt_resolve_default_version gradle '9.4.1'
      The status should be success
      The output should eq '9.7.1'
      The contents of file "$LT_VERSION_CACHE_FILE" should include 'pnpm|||'
      The contents of file "$LT_VERSION_CACHE_FILE" should include '|||9.9.9'
      The contents of file "$LT_VERSION_CACHE_FILE" should include 'gradle|||'
    End

    It 'resolves the companion tool uv through the same'\
' dynamic+cache path as the 7 languages (m-12/TASK-121.3)'
      Mock curl
        echo '{"tag_name":"0.12.9"}'
      End
      When call lt_resolve_default_version uv '0.12.9'
      The status should be success
      The output should eq '0.12.9'
      The contents of file "$LT_VERSION_CACHE_FILE" should include 'uv|||'
    End
  End

  Describe 'lt_cached_version_list_lookup() / lt_cache_version_list()'\
' (m-15/TASK-128.3, decision-16)'
    # Own scratch file, never LT_VERSION_LIST_CACHE_FILE's real default
    # ($HOME/.langtoolchain-version-list-cache) - same real-machine-state
    # safety rule as lt_resolve_default_version()'s own Describe block
    # above.
    setup() {
      LT_VERSION_LIST_CACHE_FILE="$(mktemp)"
      rm -f "$LT_VERSION_LIST_CACHE_FILE"
    }
    cleanup() { rm -f "$LT_VERSION_LIST_CACHE_FILE"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'writes a comma-joined line and reads it back split one'\
' version per line - same shape lt_upstream_version_list() itself prints'
      lt_cache_version_list pnpm "$(printf '12.3.1\n12.3.0\n9.5.0')"
      When call lt_cached_version_list_lookup pnpm
      The status should be success
      The line 1 of output should eq '12.3.1'
      The line 2 of output should eq '12.3.0'
      The line 3 of output should eq '9.5.0'
      The contents of file "$LT_VERSION_LIST_CACHE_FILE" should include \
        'pnpm|||'
      The contents of file "$LT_VERSION_LIST_CACHE_FILE" should include \
        '|||12.3.1,12.3.0,9.5.0'
    End

    It 'misses (fails, nothing printed) when the cache file does not'\
' exist yet'
      When call lt_cached_version_list_lookup pnpm
      The status should be failure
      The output should eq ''
    End

    It 'misses for a plugin with no line in an existing cache file'
      lt_cache_version_list pnpm "$(printf '12.3.1')"
      When call lt_cached_version_list_lookup gradle
      The status should be failure
      The output should eq ''
    End

    It 'ignores a stale (past-TTL) entry and reports a miss'
      LT_VERSION_LIST_CACHE_TTL=60
      printf 'pnpm|||%s|||12.3.1,12.3.0\n' "$(($(date +%s) - 3600))" \
        > "$LT_VERSION_LIST_CACHE_FILE"
      When call lt_cached_version_list_lookup pnpm
      The status should be failure
      The output should eq ''
    End

    It 'treats a future-timestamped entry (clock skew) as stale'
      printf 'pnpm|||%s|||12.3.1,12.3.0\n' "$(($(date +%s) + 3600))" \
        > "$LT_VERSION_LIST_CACHE_FILE"
      When call lt_cached_version_list_lookup pnpm
      The status should be failure
      The output should eq ''
    End

    It 'treats a corrupted (non-numeric) timestamp as a miss instead'\
' of a hard arithmetic error'
      printf 'pnpm|||not-a-timestamp|||12.3.1,12.3.0\n' \
        > "$LT_VERSION_LIST_CACHE_FILE"
      When call lt_cached_version_list_lookup pnpm
      The status should be failure
      The output should eq ''
    End

    It 'overwrites only the plugin it caches - other cached plugins'\
' are left alone'
      lt_cache_version_list pnpm "$(printf '9.9.9')"
      lt_cache_version_list gradle "$(printf '9.7.1\n9.6.0')"
      lt_cache_version_list pnpm "$(printf '12.3.1\n12.3.0')"
      When call lt_cached_version_list_lookup pnpm
      The status should be success
      The line 1 of output should eq '12.3.1'
      The line 2 of output should eq '12.3.0'
      The contents of file "$LT_VERSION_LIST_CACHE_FILE" should include \
        'gradle|||'
      The contents of file "$LT_VERSION_LIST_CACHE_FILE" should include \
        '|||9.7.1,9.6.0'
    End

    It 'is a completely separate file from the single-value cache'\
' (LT_VERSION_CACHE_FILE) - decision-16'\''s whole point'
      LT_VERSION_CACHE_FILE="$(mktemp)"
      rm -f "$LT_VERSION_CACHE_FILE"
      lt_cache_version_list pnpm "$(printf '12.3.1\n12.3.0')"
      The path "$LT_VERSION_CACHE_FILE" should not be exist
      rm -f "$LT_VERSION_CACHE_FILE"
    End
  End

  Describe 'lt_resolve_version_list() (m-15/TASK-129.1, decision-17)'
    # Own scratch files (never the real $HOME/$$-named defaults) and a
    # not-yet-tripped breaker before every case, same isolation rules as
    # the Describe blocks above. LT_VERSION_LIST_UNREACHABLE_FILE is a
    # *marker* (existence, not content, is what matters - see its own
    # comment in lib.sh for why this is a file and not a variable: the
    # real caller, ask_version(), invokes this through a command
    # substitution subshell, where a plain variable's mutations would
    # never survive back to the next call), so setup only needs to make
    # sure it starts out absent.
    setup() {
      LT_VERSION_LIST_CACHE_FILE="$(mktemp)"
      rm -f "$LT_VERSION_LIST_CACHE_FILE"
      LT_VERSION_LIST_UNREACHABLE_FILE="$(mktemp -u)"
    }
    cleanup() {
      rm -f "$LT_VERSION_LIST_CACHE_FILE" "$LT_VERSION_LIST_UNREACHABLE_FILE"
    }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'returns a fresh cache hit without calling curl at all'
      lt_cache_version_list nodejs "$(printf '24.5.0\n22.1.0')"
      Mock curl
        exit 1
      End
      When call lt_resolve_version_list nodejs
      The status should be success
      The line 1 of output should eq '24.5.0'
      The line 2 of output should eq '22.1.0'
    End

    It 'fetches live and caches the result on a cold cache'
      Mock curl
        echo '"version":"v24.5.0","version":"v22.1.0"'
      End
      When call lt_resolve_version_list nodejs
      The status should be success
      The output should include '24.5.0'
      The output should include '22.1.0'
      The contents of file "$LT_VERSION_LIST_CACHE_FILE" should include \
        'nodejs|||'
      The path "$LT_VERSION_LIST_UNREACHABLE_FILE" should not be exist
    End

    It 'fails (nothing printed) and trips the circuit breaker marker'\
' file when the live fetch fails on a cold cache'
      Mock curl
        exit 1
      End
      When call lt_resolve_version_list nodejs
      The status should be failure
      The output should eq ''
      The path "$LT_VERSION_LIST_UNREACHABLE_FILE" should be exist
    End

    It 'skips the live fetch entirely once the circuit breaker marker'\
' file already exists, even though a fetch would otherwise succeed'
      : > "$LT_VERSION_LIST_UNREACHABLE_FILE"
      Mock curl
        echo '"version":"v24.5.0"'
      End
      When call lt_resolve_version_list nodejs
      The status should be failure
      The output should eq ''
    End

    It 'still checks the cache first even after the circuit breaker has'\
' tripped - a fresh cache hit for a different plugin is not blocked'
      : > "$LT_VERSION_LIST_UNREACHABLE_FILE"
      lt_cache_version_list golang "$(printf '1.26.1\n1.25.0')"
      Mock curl
        exit 1
      End
      When call lt_resolve_version_list golang
      The status should be success
      The line 1 of output should eq '1.26.1'
    End
  End

  Describe 'lt_version_menu_options() (m-15/TASK-129.2, decision-17)'
    # lt_version_menu_options reads its version list from STDIN, but
    # `When call` has no built-in way to pipe stdin into the function under
    # test - this thin wrapper (itself Include'd, so it sees the same
    # lt_version_menu_options() as everything else in this file) does the
    # piping so each It below can just pass the list as a plain argument.
    version_menu_options_from() {
      # The `[ -n ]` guard matters for the empty-list case below: an
      # unconditional `printf '%s\n' "$1"` would still emit one blank
      # line for $1="" , which lt_version_menu_options would then read as
      # a real (empty-string) version entry instead of zero entries.
      if [ -n "$1" ]; then
        printf '%s\n' "$1"
      fi | lt_version_menu_options "$2"
    }

    setup() { LT_VERSION_MENU_MAX=15; }
    BeforeEach 'setup'

    It 'puts the default first, suffixed "(default)", ahead of the'\
' fetched list (newest first, unchanged)'
      When call version_menu_options_from \
        "$(printf '1.2.0\n1.1.0\n1.0.0')" '1.3.0'
      The line 1 of output should eq '1.3.0 (default)'
      The line 2 of output should eq '1.2.0'
      The line 3 of output should eq '1.1.0'
      The line 4 of output should eq '1.0.0'
    End

    It 'skips a list entry equal to the default instead of listing it'\
' twice'
      When call version_menu_options_from \
        "$(printf '1.3.0\n1.2.0\n1.1.0')" '1.3.0'
      The line 1 of output should eq '1.3.0 (default)'
      The line 2 of output should eq '1.2.0'
      The line 3 of output should eq '1.1.0'
      The lines of output should eq 3
    End

    It 'caps the total option count at LT_VERSION_MENU_MAX (m-15/TASK-129.2)'
      LT_VERSION_MENU_MAX=5
      When call version_menu_options_from \
        "$(awk 'BEGIN { for (i = 50; i >= 1; i--) print "1." i ".0" }')" \
        '9.9.9'
      The lines of output should eq 5
      The line 1 of output should eq '9.9.9 (default)'
    End

    It 'always succeeds even when the input list is empty (no live/cached'\
' versions at all - decision-17 offline fallback)'
      When call version_menu_options_from '' '9.9.9'
      The status should be success
      The lines of output should eq 1
      The line 1 of output should eq '9.9.9 (default)'
    End
  End

  Describe 'lt_valid_menu_choice() (TASK-164)'
    It 'accepts a value within 1..n'
      When call lt_valid_menu_choice '10' '15'
      The status should be success
    End

    It 'rejects a value above n (silent default-keep territory before'\
' this fix)'
      When call lt_valid_menu_choice '16' '15'
      The status should be failure
    End

    It 'rejects zero'
      When call lt_valid_menu_choice '0' '15'
      The status should be failure
    End

    It 'rejects non-digit input'
      When call lt_valid_menu_choice 'abc' '15'
      The status should be failure
    End

    It 'rejects an empty string'
      When call lt_valid_menu_choice '' '15'
      The status should be failure
    End

    It 'accepts a two-digit value at the upper bound (the exact bug this'\
' task fixes - a single-char [1-9] glob could never match "15")'
      When call lt_valid_menu_choice '15' '15'
      The status should be success
    End
  End
End
