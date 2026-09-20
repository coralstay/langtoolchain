---
id: TASK-170
title: install.sh/uninstall.sh 고정 커밋 핀을 main HEAD(25ffaf7)로 갱신
status: Done
assignee: []
created_date: '2026-09-20 10:01'
updated_date: '2026-09-20 10:03'
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
TASK-167과 동일한 유지보수 - PR #19(TASK-168 raw 폴백 개선, TASK-169 사전다운로드+companion fetch 튜닝) 머지 후 install.sh:45/uninstall.sh:23의 LANGTOOLCHAIN_BRANCH 기본값을 15432bd에서 25ffaf7로 갱신. curl|sh 사용자가 이번 개선을 바로 받게 함.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 install.sh/uninstall.sh의 LANGTOOLCHAIN_BRANCH 기본값이 25ffaf7로 갱신된다
- [x] #2 두 파일의 값이 서로 일치한다
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
install.sh:45/uninstall.sh:23의 LANGTOOLCHAIN_BRANCH 기본값을 15432bd에서 25ffaf7(PR #19 머지 후 main HEAD)로 갱신, git cat-file로 해당 SHA가 origin에 실제 존재함을 확인, 두 파일 값 일치 확인. shellcheck 기존 SC3043 외 신규 없음, dash -n 통과, shellspec repo_override_spec 5/5 통과. 커밋 참고.
<!-- SECTION:FINAL_SUMMARY:END -->
