---
id: TASK-158
title: README.md 개명 + 저장소 구조 섹션 추가
status: Done
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 16:03'
labels: []
milestone: m-21
dependencies: []
documentation:
  - backlog/config.yml
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
readme.md -> README.md로 파일명 관례 통일(git-format/claude-rails와 일치) + README에 저장소 구조 섹션. 추가로 사용자가 공식 Backlog.md(github.com/MrLesk/Backlog.md) 저장소 자체의 backlog/ 스캐폴딩(루트 backlog/readme.md + 서브폴더별 readme.md)과 git-format의 실제 관행(각 폴더 readme.md에 무엇인가/언제 쓰나/관련 명령 + 이 프로젝트만의 특이점을 담음)을 참고해 langtoolchain의 backlog/ 하위 전체(루트, archive, completed, decisions, docs, drafts, milestones, tasks)에도 동일하게 readme.md를 채우도록 범위 확장. 이전에 '별도 구조 문서 안 만든다'고 정했던 결정을 사용자가 공식 컨벤션 확인 후 뒤집음 - git-format 스타일(Korean, 프로젝트별 실제 현황 반영)을 따름.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 readme.md가 README.md로 git mv 되어 있다
- [x] #2 README에 저장소 구조 섹션이 있고 backlog/config.yml의 filesystem_only/remote_operations 설정이 언급되어 있다
- [x] #3 backlog/readme.md(루트) + backlog/{archive,completed,decisions,docs,drafts,milestones,tasks}/readme.md 총 8개가 git-format 스타일(무엇인가/언제 쓰나/관련 명령)로 존재한다
- [x] #4 각 readme.md가 langtoolchain의 실제 현재 현황(태스크/decision/milestone 개수, 특이사항)을 반영한다
- [x] #5 루트 backlog/readme.md가 저장소 최상위 docs/ 폴더와 backlog/docs/ 폴더가 서로 다르다는 점을 명시한다
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
readme.md->README.md 개명 + 저장소 구조 섹션(디렉토리 표 + backlog/config.yml 특이설정) 추가. 공식 Backlog.md 저장소 자체의 backlog/ 스캐폴딩과 git-format의 실제 폴더별 readme 관행을 gh api로 직접 확인한 뒤, backlog/ 루트+7개 서브폴더 전체에 langtoolchain 실제 현황(태스크 242개/decision 19개/milestone 22개, filesystem_only:true 등)을 반영한 readme.md를 작성. 최상위 docs/와 backlog/docs/가 이름만 같고 다른 폴더라는 점도 루트 backlog/readme.md와 backlog/docs/readme.md 양쪽에 명시. 커밋 c20e53a.
<!-- SECTION:FINAL_SUMMARY:END -->
