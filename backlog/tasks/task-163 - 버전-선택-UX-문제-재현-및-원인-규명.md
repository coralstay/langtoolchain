---
id: TASK-163
title: 버전 선택 UX 문제 재현 및 원인 규명
status: Done
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 19:34'
labels: []
milestone: m-22
dependencies: []
documentation:
  - scripts/install/00_select.sh
type: spike
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-129/m-15가 Done이지만 실사용(로컬 clone 후 ./install.sh 직접 실행)에서 버전 선택 단계가 화살표 메뉴가 아니라 번호를 타이핑하는 프롬프트처럼 느껴진다는 사용자 제보. scripts/install/00_select.sh의 lt_arrow_menu()(line 353-424)는 stty -g < /dev/tty가 실패하면 번호-타이핑 폴백(line 358-376)으로 조용히 전환되는데, 이게 원인인지 다른 원인(예: 목록 fetch 자체 실패, 다른 코드 경로)인지 실제 터미널에서 재현해 확정. AC: 재현 절차/로그로 정확한 실패 지점을 기록. m-22 소속 예정, 스파이크.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 실제 터미널에서 버전 선택 단계를 재현해 stty 폴백인지 다른 원인인지 확정한다
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
재현 방법: PATH에 항상 exit 1하는 가짜 stty를 얹고 expect로 실제 pty에서 00_select.sh --dry-run 구동. 정상 pty(가짜 stty 없이)에서는 lt_arrow_menu가 의도대로 화살표 메뉴로 동작함을 먼저 확인(fetch된 nodejs 실제 버전 목록 표시됨). stty -g < /dev/tty가 실패하는 조건에서만 lt_arrow_menu()의 358-376행 폴백이 켜지고, 그게 정확히 사용자가 '프롬프팅 입력'이라 부른 번호-타이핑 UI(화살표/하이라이트 없이 숫자 입력 요구)였음을 재현으로 확인. 부수 발견: 이 폴백의 372행 'case "$action" in [1-9])' 패턴이 단일 문자 글롭이라 옵션 10번 이상은 두 자리 숫자를 입력해도 절대 매칭이 안 되고 조용히 기본값 유지됨(action=10; n=15로 직접 검증) - TASK-164에서 같이 고칠 것.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
expect+가짜 stty로 실제 pty에서 재현: stty -g < /dev/tty 실패가 원인이며, 그때 lt_arrow_menu()가 화살표 메뉴 대신 번호-타이핑 폴백(00_select.sh:358-376)으로 전환되는 게 사용자가 겪은 '프롬프팅 입력' 경험의 정확한 코드 경로. 정상 pty에서는 fetch된 실제 버전 목록이 화살표 메뉴로 잘 뜨는 것도 대조 확인. 추가로 그 폴백의 case 패턴이 두 자리 숫자(10번 이상 옵션)를 절대 못 받는 별개 버그도 발견 - TASK-164로 이관.
<!-- SECTION:FINAL_SUMMARY:END -->
