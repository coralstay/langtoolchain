# milestones

**무엇인가**: 관련 태스크 여러 개를 하나의 큰 목표(Epic)로 묶는다. 태스크 자체가
아니라 태스크들을 그룹화하는 상위 단위다. 현재 활성 마일스톤은 m-0부터 m-22까지
22개(m-9만 진행하지 않기로 하고 `archive/milestones/`로 보관됨)다.

**최근 마일스톤 예시**: m-18(curl HTTPS 강제 하드닝), m-19(SonarCloud-GitHub Issues
동기화 양방향화), m-20(S7688/POSIX sh 유지 근거 문서화), m-21(문서/디렉토리 정리 —
이 readme들도 그 일부), m-22(버전 선택 UX 개선 — TASK-163~166).

**언제 쓰나**: 여러 태스크가 하나의 큰 흐름을 이룰 때, `task list`만으로는 그 묶음이
안 보이므로 milestone으로 묶어둔다.

**관련 명령**:

- `backlog milestone add "name" --description "..."` — 새 마일스톤 생성
- `backlog task edit TASK-N -m "milestone"` — 태스크를 마일스톤에 배정
- `backlog milestone list --show-completed` — 완료/보관된 마일스톤까지 포함해 조회
