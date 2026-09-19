# drafts

**무엇인가**: 아직 사용자 승인을 받지 못한 계획 초안을 담는다. task와 달리 곧바로
실행되지 않으며, 검토와 승인을 거쳐야 정식 태스크가 된다.

**지금 상태**: 비어 있다. 최근 만들어진 draft(문서/디렉토리 정리 5건, 버전 선택 UX
3건, Ctrl-C raw 모드 버그 1건)는 전부 사용자 재승인 후 `backlog draft promote`로
TASK-158~166으로 승격 완료됐다.

**언제 쓰나**: 이 저장소의 CLAUDE.md 워크플로대로, plan mode에서 세운 계획을 프롬프트로
먼저 보여주고 승인받은 뒤 그 결과를 `backlog draft create`로 기록한다. 사용자가 draft를
확인하고 다시 승인하면 그때 `backlog draft promote`로 실제 태스크로 승격한다 — 이
두 번째 승인 전까지는 실행을 시작하지 않는다.

**관련 명령**:

- `backlog draft create "title" --description "..."` — 새 초안 생성
- `backlog draft promote DRAFT-N` — 승인된 초안을 정식 태스크(TASK-N)로 승격
- `backlog draft list` — 대기 중인 초안 목록 조회
