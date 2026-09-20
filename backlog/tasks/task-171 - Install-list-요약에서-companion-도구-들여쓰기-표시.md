---
id: TASK-171
title: Install list 요약에서 companion 도구 들여쓰기 표시
status: Done
assignee: []
created_date: '2026-09-20 10:05'
updated_date: '2026-09-20 10:08'
labels: []
dependencies: []
modified_files:
  - scripts/install/00_select.sh
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
00_select.sh:875-878의 '== Install list ==' 요약 루프가 부모 언어와 companion(pnpm/gradle/uv) 구분 없이 전부 같은 들여쓰기로 출력됨. 대화형 질문 단계('  Also install X (companion to Y)?')는 이미 들여쓰기로 구분하는데 요약에서만 사라짐. ALL_COMPANIONS(이미 계산돼 있는 companion 플러그인 이름 목록)로 각 줄이 companion인지 판단해서 추가 들여쓰기(또는 표시)를 준다.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Install list 요약에서 companion 도구(pnpm/gradle/uv) 줄이 부모 언어보다 더 들여써져서 시각적으로 구분된다
- [x] #2 shellspec 회귀 없음
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
ALL_COMPANIONS로 companion 여부를 판별해 Install list 요약에서 companion 줄만 추가 들여쓰기(4칸 vs 2칸)하도록 수정. expect+가짜 stty로 nodejs+pnpm 조합 확인, shellspec 151 examples 0 failures, --all --dry-run 회귀 없음.
<!-- SECTION:FINAL_SUMMARY:END -->
