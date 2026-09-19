# completed

**무엇인가**: `backlog cleanup`이 옮긴, 완료된 지 일정 기간이 지난 Done 태스크의
보관소다. `tasks/`가 진행 중/최근 완료 작업으로만 붐비지 않도록 오래된 기록을 덜어낸다.

**지금 상태**: 비어 있다. 이 저장소는 아직 `backlog cleanup`을 실행한 적이 없어서,
Done 태스크 242개가 전부 `tasks/`에 그대로 남아 있다.

**언제 쓰나**: `backlog cleanup` 실행 시 선택한 기준보다 오래된 Done 태스크가 있으면
자동으로 여기로 옮겨진다. 완료됐다고 바로 옮겨지는 게 아니라 "완료된 지 오래된" 것만
옮겨진다는 점이 `archive/`(완료되지 않고 중도 폐기된 것)와 다르다.

**관련 명령**:

- `backlog cleanup` — 기준 age보다 오래된 Done 태스크를 이 폴더로 이동
- `backlog task list --plain` — 이동 여부와 무관하게 태스크 전체 조회는 그대로 가능
