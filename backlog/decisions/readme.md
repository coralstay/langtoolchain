# decisions

**무엇인가**: 아키텍처/정책 판단을 기록한 역사적 기록이다. 태스크가 아니라 "왜
이렇게 하기로 했는지"에 대한 근거를 남긴다. 현재 decision-1부터 decision-19까지
19건이 있고, 전부 `accepted` 상태다 — git-format과 달리 지금까지 한 decision이
다른 decision을 대체(supersede)한 사례는 없다.

**대표적인 예**:

- decision-9: 태스크 관리는 backlog.md 하나로만 하고 GitHub Issues는 도입하지 않는다
- decision-14: 단, SonarCloud가 찾은 이슈는 decision-9의 예외로 GitHub Issues에
  발행한다(범위 한정)
- decision-13: 정적분석 도구로 SonarQube Cloud 채택, CodeQL은 shell 미지원으로 기각
- decision-19: POSIX sh 유지 + SonarCloud S7688 규칙 활성 유지(오탐 회귀 탐지용)

**언제 쓰나**: 여러 방식 중 하나를 선택하고 그 선택이 앞으로의 작업에 계속 영향을 줄
때(예: 언어/도구 선택 정책, 정적분석 도구, POSIX sh 유지 여부) 기록한다.

**CLI 제약**: `decision update`나 `decision delete` 명령이 없다. 이미 만든 decision의
내용을 고쳐야 하면 CLAUDE.md의 "backlog task/draft/document/decision/milestone
마크다운을 직접 수정하지 말고 CLI로만 수정하라"는 원칙과 충돌하는 지점이라, 정책이
바뀌면 기존 파일을 고치기보다 새 decision을 만들어 관계를 본문에 명시하는 쪽을
우선 고려할 것.

**관련 명령**:

- `backlog decision create "title"` — 새 의사결정 기록 생성
- `backlog decision list` — 전체 의사결정 목록 조회
