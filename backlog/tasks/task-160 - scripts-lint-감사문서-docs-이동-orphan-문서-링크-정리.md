---
id: TASK-160
title: scripts/lint 감사문서 docs/ 이동 + orphan 문서 링크 정리
status: Done
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 16:09'
labels: []
milestone: m-21
dependencies: []
documentation:
  - scripts/lint/check-hardcoded-paths.sh
modified_files:
  - scripts/lint/check-hardcoded-paths.sh
  - docs/hardcoded-paths-patterns.md
  - docs/sed-portability-audit.md
  - README.md
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
scripts/lint/hardcoded-paths-patterns.md, scripts/lint/sed-portability-audit.md를 docs/로 이동하고 scripts/lint/check-hardcoded-paths.sh 내부 주석의 경로 참조 갱신. 이동한 2개 + 기존에 어디서도 안 걸려있던 docs/posix-sh-vs-bash-research.md까지 총 3개 문서를 README나 docs/architecture.md에서 링크 추가. backlog/tasks/*.md 안의 옛 경로 언급(과거 기록)은 손대지 않음. m-21 소속 예정.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 scripts/lint/hardcoded-paths-patterns.md, sed-portability-audit.md가 docs/로 이동돼 있다
- [x] #2 check-hardcoded-paths.sh의 경로 주석이 새 위치를 가리킨다
- [x] #3 이동한 2개 + posix-sh-vs-bash-research.md가 README나 docs/architecture.md에서 링크된다
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
2개 감사문서를 scripts/lint/에서 docs/로 git mv, check-hardcoded-paths.sh의 경로 주석 2곳 갱신, README 기여하기 섹션에 3개 문서(이동한 2개 + posix-sh-vs-bash-research.md) 링크 추가. shellcheck 기존 SC3043 경고 외 신규 없음. 커밋 a479c37.
<!-- SECTION:FINAL_SUMMARY:END -->
