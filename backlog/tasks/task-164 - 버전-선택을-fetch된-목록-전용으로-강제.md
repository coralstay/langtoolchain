---
id: TASK-164
title: 버전 선택을 fetch된 목록 전용으로 강제
status: Done
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 19:44'
labels: []
milestone: m-22
dependencies:
  - TASK-163
modified_files:
  - scripts/lib.sh
  - scripts/install/00_select.sh
  - spec/lib_spec.sh
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
재현 태스크에서 규명된 원인에 맞춰 수정 - 어떤 환경(stty 실패 폴백 포함)에서도 fetch된 목록 밖 값이 선택/설치되지 않도록 보장. ask_version()/lt_arrow_menu()가 언어(nodejs/java/python/rust/golang)와 동반툴(pnpm/gradle/uv) 공통 함수라 한 번 수정으로 8개 플러그인 전부에 적용됨. shellspec에 '목록 밖 입력은 무시되고 기본값 유지'를 검증하는 케이스 추가. 재현 태스크에 의존. m-22 소속 예정.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 어떤 환경에서도 fetch된 목록 밖 값이 선택/설치되지 않는다
- [x] #2 shellspec에 목록 밖 입력 무시 케이스가 추가된다
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
TASK-163에서 재현한 stty 폴백 자체는 이미 목록 밖 값을 안 받아들였지만(숫자만, 범위체크), 그 case 패턴이 [1-9] 단일문자 글롭이라 10 이상 옵션은 몇 자리를 입력해도 매칭이 안 되고 조용히 기본값으로 남는 별개 버그를 발견해서 같이 고침 - '목록 전용 강제'라는 AC 취지상 유효한 옵션이 선택 불가능한 것도 결함이라 판단.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
lt_valid_menu_choice() 헬퍼를 lib.sh에 추가(all-digits + 1..n 범위 체크)하고 00_select.sh의 폴백에서 이걸로 교체 - 이전엔 [1-9] 글롭이라 10 이상 옵션이 원천 선택 불가였음. spec/lib_spec.sh에 6개 케이스 추가(140 examples 0 failures). expect+가짜 stty로 실제 재현: 옵션 '10' 입력 시 install list에 정확히 그 버전(26.4.0)이 기록됨을 확인. 커밋 23306ef.
<!-- SECTION:FINAL_SUMMARY:END -->
