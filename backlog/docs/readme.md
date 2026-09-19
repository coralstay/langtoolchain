# docs (backlog 전용 — 저장소 최상위 `docs/`와 다름)

**무엇인가**: `backlog doc create`로 만드는 CLI 관리 문서 엔터티가 들어간다. 지금은
`doc-1`(m-11~m-14 서브에이전트 마일스톤 실행 회고) 하나뿐이다.

**저장소 최상위 `docs/`와 헷갈리지 말 것**: 이 저장소에는 사람이 읽는 프로덕트 문서
전용 폴더가 최상위에 따로 있다 — `docs/architecture.md`, `docs/shell-style-guide.md`,
`docs/download-points-inventory.md`, `docs/download-integrity-techniques.md`,
`docs/posix-sh-vs-bash-research.md`. 이 5개는 `backlog doc`으로 만든 게 아니라 그냥
git으로 관리되는 일반 마크다운 파일이라 `backlog doc list`에 안 뜬다. 반대로 여기
`backlog/docs/`의 doc-1은 저장소 최상위 `docs/`에서는 안 보인다.

**언제 쓰나**: 태스크나 의사결정으로 분류하기엔 애매한 회고·조사 기록을 backlog CLI
안에서 관리하고 싶을 때. 이 저장소는 지금까지 이런 성격의 기록을 대부분 최상위
`docs/`(사람이 링크 걸어 찾아가는 참고 자료)나 태스크 본문(작업 회고)에 남겨왔고,
`backlog doc`은 doc-1 한 건에만 썼다.

**관련 명령**:

- `backlog doc create "title"` — 새 문서 생성
- `backlog doc view doc-N --plain` — 문서 내용 조회
- `backlog doc list` — 전체 문서 목록 조회
