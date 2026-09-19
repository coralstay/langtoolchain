# backlog

**무엇인가**: 이 저장소(langtoolchain)의 작업 기록 전체를 담는 최상위 디렉토리다. 할 일부터
초안, 참고 문서, 의사결정, 마일스톤, 완료/보관 태스크까지 Backlog.md CLI가 관리하는 모든
산출물이 여기 들어간다.

**언제 쓰나**: 이 프로젝트는 코드를 먼저 짜다가(task-1 참고) 중간에 Backlog.md를 도입했다.
`task_prefix`는 `"task"`(대문자 없음, git-format의 `GF`와 다름)로 고정돼 있고, 이후로는
직접 건드릴 일 없이 아래 서브폴더별 CLI 명령을 통해서만 내용이 채워진다.

**관련 명령**:

- `backlog overview` — 전체 현황(진행 중 태스크, 마일스톤 진척도 등) 요약
- `backlog board view` — 상태별 칸반 보드로 태스크 확인
- `backlog search "query"` — 태스크/문서/의사결정 전체에서 키워드 검색

**서브폴더 안내**: `tasks/`, `drafts/`, `docs/`, `decisions/`, `milestones/`, `completed/`,
`archive/` — 각 폴더의 역할은 폴더 안의 readme.md를 참고한다.

**이름이 겹치는 두 `docs/` 폴더 — 헷갈리기 쉬운 지점**: 이 저장소 최상위에도 `docs/`
폴더가 있다(architecture.md, shell-style-guide.md 등 5개 마크다운 — 사람이 읽는 프로덕트
문서). 여기 `backlog/docs/`는 완전히 다른 것으로, `backlog doc create`로 만드는 CLI
관리 문서 엔터티(doc-1, doc-2, ...)가 들어간다. 경로만 보면 구분이 안 되니 `backlog/`
접두어가 붙었는지로 구분할 것.

**이 프로젝트만의 특이점**: `backlog/config.yml`에 `filesystem_only: true`,
`remote_operations: false`가 설정돼 있다 — git-format/claude-rails는 둘 다
`remote_operations: true`/`filesystem_only: false`를 쓰므로, 다른 프로젝트에서
넘어오면 원격 동기화 관련 동작이 다를 수 있다는 점에 유의. 또한 `require_active_task.py`
훅은 이 저장소가 backlog 프로젝트인지를 **파일 경로가 아니라 현재 작업 디렉토리(cwd)**
기준으로 판단해서, cwd가 이 저장소인 한 저장소 밖 파일(예: `~/.claude/plans/`의 plan
파일)을 쓰려는 Edit/Write도 In Progress 태스크가 없으면 막는다 — plan mode의 "계획
파일만은 예외"라는 전제와 실제로 충돌한 적이 있다(2026-09-20).
