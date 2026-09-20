---
id: TASK-174
title: install.sh/uninstall.sh 고정 커밋 핀을 main HEAD(1081887)로 갱신
status: Done
assignee: []
created_date: '2026-09-20 10:43'
updated_date: '2026-09-20 10:45'
labels: []
dependencies: []
references:
  - decision-1
documentation:
  - install.sh
modified_files:
  - install.sh
  - uninstall.sh
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-167/170과 동일한 유지보수 - PR #20(TASK-170 핀 갱신, TASK-171 companion 들여쓰기, TASK-172 SonarCloud 제거, TASK-173 테스트 속도 개선) 머지 후 install.sh:45/uninstall.sh:23의 LANGTOOLCHAIN_BRANCH 기본값을 25ffaf7에서 108188739d7cf493981a1cdb89789612d2790b5a로 갱신.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 install.sh/uninstall.sh의 LANGTOOLCHAIN_BRANCH 기본값이 108188739d7cf493981a1cdb89789612d2790b5a로 갱신된다
- [x] #2 두 파일의 값이 서로 일치한다
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
install.sh:45/uninstall.sh:23의 LANGTOOLCHAIN_BRANCH 기본값을 25ffaf7에서 108188739d7cf493981a1cdb89789612d2790b5a(PR #20 머지 후 main HEAD)로 갱신, git rev-parse/cat-file로 값 확인 후 적용, 두 파일 일치 확인. shellcheck 기존 SC3043 외 신규 없음, dash -n 통과, shellspec repo_override_spec 5/5 통과.
<!-- SECTION:FINAL_SUMMARY:END -->
