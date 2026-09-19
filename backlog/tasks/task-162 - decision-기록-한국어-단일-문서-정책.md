---
id: TASK-162
title: 'decision 기록: 한국어 단일 문서 정책'
status: Done
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 19:31'
labels: []
milestone: m-21
dependencies: []
references:
  - task-115
modified_files:
  - backlog/decisions/decision-20 - 문서는-한국어-단일화-영문-대응본-유지-안-함.md
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
커밋 ba9d43c(영문 readme.en.md 제거, 사용자 요청)를 근거로 '문서는 한국어 단일화' 정책을 backlog decision create로 명문화. task-115(README 알려진 한계 섹션 확충 - 한/영 양쪽)의 Done 기록이 당시엔 정확했지만 이후 영문판 전체 제거로 지금 상태와 안 맞아 보이는 간극을 decision으로 추적 가능하게 함. task-115 자체는 과거 기록이라 손대지 않음. m-21 소속 예정.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 backlog decision create로 한국어 단일 문서 정책 decision이 생성돼 있다
- [x] #2 커밋 ba9d43c와 task-115의 간극이 decision 안에서 설명된다
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
backlog decision create는 title/status만 받고 본문(Context/Decision/Consequences)을 채우는 CLI 명령이 없다(update도 없음) - git-format의 decisions/readme.md가 문서화한 것과 동일한 gray area라 본문은 직접 파일 편집으로 채움.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
decision-20 생성 - 커밋 ba9d43c(영문 readme.en.md 제거) 근거로 '문서 한국어 단일화' 정책 명문화, task-115 Done 기록과의 간극을 Context/Consequences에서 설명. 커밋 1402e57.
<!-- SECTION:FINAL_SUMMARY:END -->
