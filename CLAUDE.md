<!-- BACKLOG.MD GUIDELINES START -->
<!-- backlog.md-instructions-version: 1.51.0 -->

<CRITICAL_INSTRUCTION>

## Backlog.md Workflow

This project uses Backlog.md for task and project management.

**For every user request in this project, run `backlog instructions overview` before answering or taking action.**

Use the overview to decide whether to search, read, create, or update Backlog tasks.

Before task lifecycle actions, read the matching detailed guide:

- `backlog instructions task-creation` before creating or splitting tasks
- `backlog instructions task-execution` before planning, changing status or assignee, adding a plan or implementation notes, or implementing task work
- `backlog instructions task-finalization` before checking acceptance criteria, writing final summaries, or moving tasks to terminal statuses

Use `backlog <command> --help` before running unfamiliar commands. Help shows options, fields, and examples.

Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use the `backlog` CLI so metadata, relationships, and history stay consistent.

</CRITICAL_INSTRUCTION>
<!-- BACKLOG.MD GUIDELINES END -->

## 이 저장소의 backlog.md 설정 특이사항

`backlog/config.yml`: `task_prefix: "task"`, `filesystem_only: true`,
`remote_operations: false`. git-format(`GF`)/claude-rails(`task`, 하지만
`remote_operations: true`)와 비교하면 이 저장소는 원격 동기화 없이 로컬 git
저장소 안에서만 동작하는 구성이다 — 다른 backlog.md 프로젝트를 오가다 오면
원격 관련 동작이 다를 수 있다는 점에 유의.

decision-9/task-114가 "CLAUDE.md의 claude-rails 워크플로 그대로 유지"를
언급하지만, 이 저장소에는 실제로 CLAUDE.md 파일이 없었다(2026-09-20까지) —
claude-rails 훅 자체의 상세 동작(active-task 확인, task/\<ID\> 브랜치 강제,
Done+final-summary 없으면 push 차단 등)은 사용자의 글로벌
`~/.claude/CLAUDE.md`와 세션 메모리에 있으므로 여기서 중복 기술하지 않는다.
이 파일은 이 저장소에만 해당하는 내용만 담는다.

**`require_active_task.py` 훅은 파일 경로가 아니라 현재 작업 디렉토리(cwd)
기준으로 backlog 프로젝트인지 판단한다** — cwd가 이 저장소인 한, 저장소 밖
파일(예: `~/.claude/plans/`의 plan mode 계획 파일)을 쓰려는 Edit/Write도 In
Progress 태스크가 없으면 막힌다. plan mode의 "계획 파일만은 예외"라는 전제와
실제로 충돌한 적이 있다(2026-09-20) — plan 파일을 못 쓰면 계획을 채팅
텍스트로만 공유하고 넘어갈 것.

**`pre_merge_check.py` 훅은 `git merge`에 `-s`(strategy) 플래그를 금지한다**
(fast-forward 전용 정책) — 다만 이 검사가 Bash 도구 호출 전체 문자열을
스캔하는 것으로 보여, 같은 한 번의 Bash 호출 안에 `git merge`와 무관한
`-s`(예: `backlog task edit ... -s Done`)가 섞여 있어도 오탐으로 막힐 수
있다. `git merge`를 실행할 때는 `-s`가 들어간 다른 명령과 같은 Bash 호출에
묶지 말고, `backlog task edit`에는 `-s` 대신 `--status`를 쓸 것.

## POSIX sh 유의사항

이 저장소는 macOS 기본 `/bin/sh`(POSIX 모드)에서 그대로 동작해야 하는 순수
POSIX sh 프로젝트다(bash 특수문법 금지). 스타일 규칙은
[docs/shell-style-guide.md](docs/shell-style-guide.md), POSIX sh를 계속
유지하기로 한 조사/근거는 [docs/posix-sh-vs-bash-research.md](docs/posix-sh-vs-bash-research.md)
(decision-19) 참고. `local` 키워드는 POSIX 표준은 아니지만(`shellcheck`
SC3043 경고 대상) 이 저장소 전체에서 의도적으로 계속 쓴다 — dash를 포함한
실제 타겟 셸들이 지원하는 것을 확인했고 기존 경고는 무시 대상이다.

코드를 고쳤으면 항상: `shellcheck -s sh` → `dash -n`(macOS 기본 `/bin/sh`는
posix 모드 bash라 진짜 POSIX 위반을 놓침) → `shellspec`/`shellspec --shell dash`로
`spec/` 스위트 실행.
