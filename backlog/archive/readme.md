# archive

**무엇인가**: 완료되지 못한 채 도중에 폐기/보류된 태스크·초안·마일스톤을 담는
soft-delete 보관소다. 삭제가 아니라 이동이라서 이력은 남는다. `completed/`가
"끝까지 갔다"라면 archive는 "가다가 멈췄다"다.

**지금 들어있는 것**: `milestones/m-9 - 쉘 파일명 역할별 프리픽스 네이밍`뿐이다.
`scripts/install/00_select.sh` 같은 numeric-prefix 파일명을 role-prefix로 바꾸자는
제안이었는데, 참조 지점이 너무 많아 진행하지 않기로 하고 보관됐다 — 실제 파일명은
지금도 numeric-prefix 그대로다. `archive/tasks/`, `archive/drafts/`는 비어 있다.

**언제 쓰나**: 계획을 세웠지만 진행하지 않기로 한 태스크, 혹은 방향이 바뀌어 더 이상
의미가 없어진 태스크/초안/마일스톤을 옮길 때 생긴다.

**관련 명령**:

- `backlog task archive TASK-N` — 태스크를 이 폴더로 이동(soft delete)
- `backlog milestone archive "name"` — 마일스톤을 이 폴더로 이동
- `backlog task list --plain` — archive된 태스크는 기본 목록에서 제외되고 조회됨
