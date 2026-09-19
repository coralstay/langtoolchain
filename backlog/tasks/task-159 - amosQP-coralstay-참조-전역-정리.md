---
id: TASK-159
title: amosQP -> coralstay 참조 전역 정리
status: To Do
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 15:44'
labels: []
milestone: m-21
dependencies:
  - TASK-158
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
GitHub 계정이 amosQP에서 coralstay로 개명(동일인, 확인됨)됐는데 README.md의 curl 설치/제거 URL 3곳, git clone 안내, 하단 크레딧(총 6곳)과 .github/workflows/e2e-verify.yml:146의 curl 설치 URL이 여전히 옛 이름을 참조 중. curl-pipe 설치 원라이너라 계정명이 나중에 제3자에게 재등록되면 조용히 낯선 소스로 넘어갈 위험. SonarCloud 프로젝트 키/조직명(sonar-project.properties, sonarcloud-issues-to-github.yml의 amosqp/amosQP_langtoolchain)은 사용자가 SonarCloud 재설정 시 별도 처리 예정이라 이번 범위에서 제외. m-21 소속 예정.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 README.md/e2e-verify.yml의 amosQP 참조가 coralstay로 바뀌어 있다 (SonarCloud 키 제외)
- [ ] #2 grep -rn amosQP 결과 sonar-project.properties/sonarcloud-issues-to-github.yml 외엔 안 남아있다
<!-- AC:END -->
