---
id: TASK-167
title: install.sh/uninstall.sh 고정 커밋 핀을 새 main HEAD로 갱신
status: Done
assignee: []
created_date: '2026-09-20 00:58'
updated_date: '2026-09-20 01:04'
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
install.sh:45/uninstall.sh:23의 LANGTOOLCHAIN_BRANCH 기본값(고정 커밋 SHA, TASK-117.1/decision-1)이 896b4c5a(2026-09-03, TASK-122)로 박혀있는데, TASK-129(2026-09-05, m-15 - 자유 텍스트 버전 입력 제거)를 포함한 그 이후 수십 개 태스크가 전혀 반영 안 된 채 방치돼 있었음. 사용자가 실사용 중 'Enter a specific version' 자유 텍스트 프롬프트를 봤다고 제보한 게 이 스테일 핀 때문임을 확인(896b4c5a 시점 코드에 그 문자열이 실제로 있음, TASK-129 이후 삭제됨) - curl|sh 사용자는 지금도 계속 이 옛날 코드를 받는 중. 핀을 PR #17 머지 후 새 main HEAD로 갱신하고, install.sh/uninstall.sh 둘 다 동일하게 맞춘다(README 주석의 '손으로 갱신' 관례 그대로 따름 - 자동화는 별도 논의).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 install.sh/uninstall.sh의 LANGTOOLCHAIN_BRANCH 기본값이 PR #17 머지 후 main HEAD로 갱신된다
- [x] #2 두 파일의 값이 서로 일치한다
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
재발 방지(자동 갱신 CI 등)는 이번 범위 밖으로 사용자와 명시적으로 합의 - 이 핀은 계속 손으로 관리되고 다음 main 병합 시점부터 다시 스테일해질 것.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
install.sh:45/uninstall.sh:23의 LANGTOOLCHAIN_BRANCH 기본값을 896b4c5a(2026-09-03)에서 15432bd(PR #17 머지 후 main HEAD, 2026-09-20)로 갱신, 두 파일 값 일치 확인. 사용자가 실사용 중 본 'Enter a specific version' 자유 텍스트 프롬프트가 이 스테일 핀(TASK-129 이전 코드) 때문이었음을 git show로 직접 확인. shellcheck 기존 SC3043 외 신규 없음, dash -n 통과, shellspec repo_override_spec 5/5 통과, git cat-file로 해당 SHA가 origin에 실제 존재함을 확인. 커밋 37b8dd6.
<!-- SECTION:FINAL_SUMMARY:END -->
