<div align="center">

# 🧰 langtoolchain

**macOS 한 줄 명령으로 Node.js · Java · Python · Rust · Go 컴파일러를 통째로 설치**

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS-000000?logo=apple&logoColor=white)](#-사전-요구사항)
[![Shell](https://img.shields.io/badge/shell-POSIX%20sh-4EAA25)](#-기여하기)
[![Powered by asdf](https://img.shields.io/badge/powered%20by-asdf-F16436)](https://asdf-vm.com)

`git clone`도, 수동 설치도 필요 없습니다. 터미널에 한 줄 붙여넣으면 끝.

</div>

<br>

```zsh
curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/coralstay/langtoolchain/main/install.sh | sh
```

<br>

> ⚠️ **macOS 전용, 개인 툴링입니다.** Linux/Windows(WSL 포함) 지원 계획이 없고, 범용
> 프로덕션 도구로 만든 게 아니라 제 개인 Mac 워크플로우에 맞춰 만든 도구입니다 — 다른
> 환경에서의 동작이나 일반적인 사용 사례를 보장하지 않습니다.

## 왜 만들었나

새 Mac마다 Homebrew·asdf 설치, 플러그인 추가, `.zshrc` 손보기를 반복하는 게 지겨워서 만들었습니다. **이제는 한 줄이면 됩니다.** Homebrew·asdf 설치부터 언어 선택, 셸 설정까지 전부 자동입니다.

- 🍺 **Homebrew 없어도 OK** — 없으면 공식 스크립트로 자동 설치 (sudo 비밀번호만 직접 입력)
- ☑️ **체크박스 같은 대화형 설치** — 언어별로 설치 여부와 버전을 확인하고 골라서 설치
- 🌐 **`curl | sh` 완전 지원** — 로컬에 아무것도 없어도 원격 저장소를 알아서 clone해서 실행
- 🌍 **전역 or 디렉토리별 버전 고정** — 시스템 전체 기본값으로도, 특정 프로젝트에만도 자유롭게
- 🔙 **깔끔한 제거** — 설치한 건 전부 되돌릴 수 있음 (`.bak` 백업까지 남김)
- 🖥️ **POSIX sh 호환** — macOS 기본 셸(`/bin/sh`)에서도 그대로 동작, bash 특수문법 없음

<br>

## 목차

- [빠른 시작](#-빠른-시작)
- [사전 요구사항](#-사전-요구사항)
- [설치/제거되는 것](#-설치제거되는-것)
- [아키텍처](#-아키텍처)
- [저장소 구조](#-저장소-구조)
- [알려진 한계 / 기술적 한계](#-알려진-한계--기술적-한계)
- [기여하기](#-기여하기)
- [License](#-license)

<br>

## 🚀 빠른 시작

```zsh
curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/coralstay/langtoolchain/main/install.sh | sh
```

로컬에 이미 클론해뒀다면:

```zsh
git clone https://github.com/coralstay/langtoolchain.git && cd langtoolchain
./install.sh
```

언어별 설치 여부(↑/↓로 고르고 Enter로 확정, 숫자 키로 바로 선택도 가능)와 버전을 확인한 뒤,
마지막 확인을 거쳐 설치를 시작합니다. 각 질문에 답하면 그 자리에서 한 줄로 접혀서 다음 질문으로
넘어갑니다 — 아래는 실제 실행 화면입니다.

```text
== Select languages to install ==

✔ Install nodejs (node)? Yes
✔ Version: lts (default)
✔ Also install pnpm (companion to nodejs)? Yes
✔ Version: 10.33.0 (default)

✔ Install java (java)? No
...
== Install list ==
  nodejs  lts
  pnpm    10.33.0
  python  3.12.13
  rust    1.94.0
  golang  1.26.1

✔ Pin these versions: Globally
✔ Install? Yes
```

> 마지막 프롬프트는 이번에 설치한 버전을 전역(`~/.tool-versions`)에 고정할지, 지금 디렉토리에만
> 로컬로 고정할지 고릅니다(`asdf`의 표준 메커니즘 그대로 — nvm의 `.nvmrc` 같은 걸 언어 상관없이
> `.tool-versions` 하나로 통일한 것뿐입니다).
>
> 동반 도구(pnpm/gradle) 질문은 그 부모 언어(nodejs/java)를 수락했을 때만 따라 나옵니다 — 위
> 예시에서 java를 `n`으로 거절하니 gradle 질문 자체가 안 뜨는 걸 볼 수 있습니다.

<details>
<summary><b>옵션 플래그</b> (<code>curl | sh -s -- &lt;옵션&gt;</code> 형태로 전달 가능)</summary>
<br>

| 플래그                      | 대상                | 동작                                                     |
| --------------------------- | ------------------- | -------------------------------------------------------- |
| `--all`                     | install             | 언어 선택 화면 없이 `.tool-versions`에 있는 걸 전부 설치 |
| `--yes`                     | install / uninstall | 마지막 확인 프롬프트를 건너뜀                            |
| `--dry-run`                 | install / uninstall | 실제로 아무것도 바꾸지 않고, 뭘 할지만 출력              |
| `--local` / `--local=<dir>` | install             | 전역 대신 현재(또는 지정한) 디렉토리에만 버전 고정       |

여러 개를 조합할 수 있습니다: `curl ... | sh -s -- --all --yes --dry-run`처럼.
터미널(tty)이 없는 환경(CI 등)에서 실행하면 자동으로 `--all`처럼 동작합니다 — 입력을 기다리다 멈추지 않습니다.

</details>

<br>

## 📋 사전 요구사항

| 필요한 것            | 없으면?                                                            |
| -------------------- | ------------------------------------------------------------------ |
| macOS                | 이 도구는 macOS 전용입니다                                         |
| `git` (원격 설치 시) | Xcode Command Line Tools에 기본 포함                               |
| ~~Homebrew~~         | 없으면 설치기가 알아서 설치합니다 (sudo 비밀번호는 직접 입력 필요) |
| ~~asdf~~             | 없으면 `brew install asdf`로 알아서 설치합니다                     |

<br>

## 📦 설치/제거되는 것

`.tool-versions`에 정의된 기본 언어/버전 — 설치 화면에서 개별적으로 켜고 끄거나 버전을 바꿀 수 있습니다.
동반 도구(pnpm/gradle)는 각각 그 부모 언어를 설치할 때만 물어보는 선택 사항입니다.

| 언어 / 동반 도구            | 기본 버전                 |
| --------------------------- | ------------------------- |
| 🟩 Node.js                  | `lts`                     |
| &nbsp;&nbsp;└ pnpm (동반)   | `10.33.0`                 |
| ☕ Java (Temurin)           | `temurin-25.0.2+10.0.LTS` |
| &nbsp;&nbsp;└ gradle (동반) | `9.4.1`                   |
| 🐍 Python                   | `3.12.13`                 |
| 🦀 Rust                     | `1.94.0`                  |
| 🐹 Go                       | `1.26.1`                  |

Python 컴파일에 필요한 Homebrew 패키지(`openssl`, `readline`, `sqlite3`, `xz`, `zlib`, `tcl-tk`)도 함께 설치됩니다.

이 도구는 위 언어(+동반 도구)와 그걸 위한 Homebrew 패키지 6개만 건드립니다 — 이미 있거나 앞으로
설치할 다른 `brew` 패키지, 이 도구가 깔지 않은 다른 asdf 플러그인은 install 쪽에서든 uninstall
쪽에서든 손대지 않습니다. uninstall은 langtoolchain이 설치하지 않은 asdf 플러그인 각각도,
`asdf` 자체와 `~/.asdf/`(asdf 데이터 디렉토리) 전체 삭제도 모두 설치 시점 스냅샷을 기준으로
판단합니다 — **개별 플러그인이든 `~/.asdf/` 전체든, 설치 시점에 이미 있었다는 게 확인되면(또는
확인할 수 없으면) 삭제를 건너뛰고 경고만 남깁니다** — 다른 asdf 플러그인이 있어도 무조건 함께
지워지던 예전 동작과 다릅니다. uninstall이 phase 전체를 에러 없이 마치면 이 설치 시점 스냅샷
자체도 지워집니다 — 다음 install이 그 시점의 실제 상태로 새 기준선을 잡습니다.

> **⚠️ 동작 변경 안내(m-13)**: 이 변경 이전 버전으로 이미 설치해 둔 상태에서 langtoolchain을
> 업데이트만 한 경우, install 시점 스냅샷이 없으므로 uninstall을 실행해도 안전을 위해 asdf
> 플러그인 개별 삭제와 `~/.asdf/` 전체 삭제가 모두 기본적으로 스킵됩니다(설치 전부터 있던
> 상태인지 판단할 근거가 없기 때문 — "모르면 지우지 않는다"는 원칙). langtoolchain이 설치한
> 런타임까지 포함해 완전히 지우고 싶다면, uninstall 실행 후 화면에 안내되는 대로
> `rm -rf ~/.asdf`를 직접 실행하세요.

```zsh
curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/coralstay/langtoolchain/main/uninstall.sh | sh
```

실행 전 한 번 확인을 물으며(`--yes`로 생략 가능), `--dry-run`도 동일하게 지원합니다. 설치/제거
후에는 `exec $SHELL`로 새 셸 세션을 열어야 PATH 등 캐시된 상태가 완전히 사라집니다.

<br>

## 🗺️ 아키텍처

install.sh/uninstall.sh가 각각 어떤 phase를 순서대로 거치는지, uninstall의 안전장치
(설치 전부터 있던 asdf 상태는 안 지운다)가 정확히 어느 지점에서 개입하는지를 다이어그램
으로 정리해뒀습니다 — [docs/architecture.md](docs/architecture.md).

<br>

## 🗂️ 저장소 구조

| 경로                                     | 역할                                                                                                           |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `install.sh` / `uninstall.sh`            | curl-pipe 진입점. 로컬 clone이 있으면 그대로 실행, 없으면 고정 커밋을 self-clone 후 실행                       |
| `scripts/install/`, `scripts/uninstall/` | 번호가 매겨진 phase 스크립트(00, 01, 02, ...) + 각각의 `main.sh`                                               |
| `scripts/lib.sh`                         | 설치/제거 전체가 공유하는 함수 라이브러리 (버전 fetch/캐시, 락, 타임아웃 등)                                   |
| `scripts/lint/`                          | shellcheck 외에 이 저장소 자체 lint 스크립트(하드코딩 경로 검사 등)                                            |
| `spec/`                                  | shellspec 테스트 스위트                                                                                        |
| `docs/`                                  | 사람이 읽는 프로덕트 문서(아키텍처, 스타일 가이드, 조사 기록 등)                                               |
| `backlog/`                               | Backlog.md CLI가 관리하는 태스크/의사결정/마일스톤 — 폴더별 역할은 [backlog/readme.md](backlog/readme.md) 참고 |

이 저장소의 `backlog/config.yml`은 `filesystem_only: true`, `remote_operations: false`로
설정돼 있습니다 — 원격 동기화 없이 로컬 git 저장소 안에서만 동작하는 구성입니다. 더 자세한
내용(각 폴더 안내, 의사결정 이력)은 `backlog decision list`나 `backlog task view <ID>`로
직접 조회하는 걸 권장합니다 — 여기서 전부 옮겨 적지는 않습니다.

<br>

## 🧭 알려진 한계 / 기술적 한계

### 범위상 한계

- **macOS 전용** — Linux/Windows 미지원.
- **언어 5개 고정** — Node.js/Java/Python/Rust/Go 외 언어는 코드를 직접 고쳐야 추가 가능. 순수 asdf처럼 임의 플러그인을 자유롭게 추가하는 기능은 없음.
- **동반 도구는 nodejs/java/python 셋뿐** — pnpm(nodejs), gradle(java), uv(python, poetry 대신 채택 — decision-5) 외 언어는 동반 도구 개념이 없음(Rust/Go는 cargo/모듈 시스템이 이미 내장이라 필요 없다고 판단). 언어당 동반 도구는 항상 1개만 제안하는 UX라 poetry를 쓰고 싶다면 "직접 입력" 경로로 pin하거나 저장소 밖에서 따로 관리해야 함.
- **핵심 목적("컴파일러 설치")보다 넓은 기능이 있음** — 전역/로컬 버전 고정, 대화형 선택기는 사실 asdf 버전 관리를 감싼 부가 기능. 한 번 검토를 거쳐 "유지"로 결정했고, 걷어낼 계획은 없음.
- **Homebrew/asdf 외 도구체인은 지원 대상 아님** — MacPorts(`/opt/local`)는 경로 자체가 겹치지 않아 파일 충돌은 없지만, 같은 이름의 바이너리를 깔았다면 rc 파일에서 나중에 소싱되는 쪽이 이긴다. `mise`처럼 `.tool-versions`를 직접 읽고 자체 PATH 훅으로 셸을 활성화하는 도구는 더 실질적인 위험 — rc 파일에서 langtoolchain보다 나중에 로드되면 asdf shim을 조용히 가릴 수 있음. 둘 다 감지/경고 로직은 없음.
- **동적 기본값이 asdf가 아직 못 따라잡은 최신 버전을 제안할 수 있음** — 언어 버전 기본값을 언어 공식 소스(예: cpython 태그)에서 실시간으로 가져오는데(m-12), asdf 플러그인이 그 버전을 아직 지원 안 하면 설치가 "version not installable"로 실패할 수 있음(decision-12). m-15(실제 설치 가능한 버전 목록 기반 선택 UI)가 완료되면 애초에 asdf 미지원 버전은 선택지에도 안 뜨게 되어 구조적으로 해소될 예정.

### 다운로드/설치 체인 신뢰 경계 (m-11)

이 저장소가 실제로 무결성을 검증하는 지점과, Homebrew/asdf 같은 상위 도구에 신뢰를
위임했거나 저장소가 직접 손댈 수 없는 지점을 구분해 명시합니다. 지점별 상세(파일:라인,
현재 검증 수준)는 [docs/download-points-inventory.md](docs/download-points-inventory.md),
검증 기법 자체의 조사는 [docs/download-integrity-techniques.md](docs/download-integrity-techniques.md)를
참고하세요.

**이 저장소가 직접 검증하는 지점**

| 지점                                        | 방식                                                                                                |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `install.sh`/`uninstall.sh`의 self-clone    | 플로팅 브랜치 대신 고정 커밋 SHA로 pin — 브랜치가 강제 push돼도 이미 pin된 커밋만 받음              |
| Homebrew 공식 설치 스크립트(`curl \| bash`) | 고정 커밋으로 pin + 이 프로젝트가 직접 계산한 SHA-256 체크섬을 fetch 직후 대조, 불일치 시 실행 거부 |

**위임/통제 밖 지점 (이 저장소가 직접 검증하지 않음)**

| 지점                                                        | 위임 대상 / 통제 밖인 이유                                                                                                      |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `brew install asdf`, `brew install <시스템 의존성 6개>`     | Homebrew 자체의 bottle 서명/체크섬 체계에 위임                                                                                  |
| `asdf plugin add`(asdf-nodejs/asdf-python 등 플러그인 소스) | asdf CLI(0.20.0)가 커밋 고정을 지원하지 않음 — 검토 후 미고정 결정, 매 install 실행마다 각 플러그인 저장소의 최신 HEAD로 갱신됨 |
| `asdf install`(실제 언어 런타임 다운로드)                   | 각 asdf 플러그인 내부 로직 — 이 저장소가 직접 관여할 수 없음                                                                    |

**명시적으로 범위 밖: GitHub 저장소/계정 자체의 탈취.** 공격자가 저장소나 메인테이너 계정을
완전히 장악하면 install.sh에 박힌 고정 커밋 SHA 자체도 함께 바꿀 수 있어, 위 pin들로는
막을 수 없습니다. 이건 GitHub 쪽 계정 레벨 통제(브랜치 보호 규칙, 서명된 커밋 요구, 2FA)의
영역이며, 셸 설치 스크립트 하나가 풀 수 있는 문제가 아니라고 판단해 이 마일스톤의 범위 밖으로
뒀습니다.

### 테스트 검증의 한계

- **로컬 shellspec은 실제 Homebrew/asdf를 건드리지 않음** — `spec/`의 183개 예제는 전부 실제 `brew`/`asdf` 명령을 모킹하거나 `DRY_RUN=true`로 실행되도록 설계됨(진짜 컴파일/설치는 느리고 개발 머신을 오염시키므로). 그래서 "진짜로 설치가 되는가" 자체는 로컬 스위트가 보장하지 않고, `.github/workflows/e2e-verify.yml`(GitHub 호스팅 macOS 러너, arm64+Intel)이 유일한 실기기 검증 경로임 — `main` 브랜치에 `scripts/**`/`install.sh`/`uninstall.sh`/`.tool-versions`가 바뀔 때만 push/PR로 자동 실행(그 외 커밋은 `workflow_dispatch`로 수동 실행).
- **화살표 키 TUI는 표준 터미널 기준으로만 검증** — `stty`/`dd`로 raw 모드를 읽는 `lt_arrow_menu()`는 `expect`로 구동한 실제 pty(및 일반 터미널 앱)에서는 확인했지만, 모든 터미널 에뮬레이터·멀티플렉서(tmux/screen 등)·SSH 경유 세션 조합까지 다 검증하지는 않음 — 표준 3바이트 ANSI 이스케이프(`ESC [ A/B`)를 벗어나는 비표준 키 전송 방식에서는 예상과 다르게 동작할 수 있음.
- **`curl | sh`의 "기본" 원격 clone 경로(진짜 GitHub 대상)는 로컬에서 재현하기 어려움** — `LANGTOOLCHAIN_REPO_URL`/`LANGTOOLCHAIN_BRANCH` 환경변수로 fork/다른 브랜치를 가리켜 override하는 경로 자체는 TASK-117.6 이후 로컬 bare 저장소(`file://`)를 대상으로 `spec/repo_override_spec.sh`가 커버함(pinned-fetch 메커니즘의 exact-ref 동작까지 포함). 다만 override 없이 기본값(고정 커밋 SHA, 실제 GitHub)을 타는 경로 자체는 여전히 로컬 스위트 대상이 아니며, 실제 `curl | sh`로 이 저장소를 직접 당겨 검증한 것과 `.github/workflows/e2e-verify.yml`의 `no-git-curl-pipe` 잡(실제 GitHub의 `main` raw 파일을 당김)이 유일한 검증 경로.

### 앞으로 살펴볼 만한 것

- MacPorts/mise 같은 경쟁 도구체인에 대한 감지·경고 로직(지금은 문서화만 하고 자동 감지는 없음).
- Linux 지원 — 지금은 계획이 없지만, 만약 하게 된다면 Homebrew macOS 전용 경로 판단 로직과 rc 파일 목록부터 다시 봐야 함.

<br>

## 🤝 기여하기

- 언어/버전을 바꾸려면 `.tool-versions` 한 줄만 수정하면 됩니다.
- 각 설치/제거 단계는 `scripts/install/`, `scripts/uninstall/` 아래 역할별로 분리돼 있고, 개별 실행도 가능합니다: `DRY_RUN=true sh scripts/install/05_install_runtimes.sh`
- 코드를 고쳤으면: `shellcheck -s sh` → `dash -n`(macOS 기본 `/bin/sh`는 posix 모드 bash라 진짜 POSIX 위반을 놓침) → `shellspec`/`shellspec --shell dash`로 `spec/` 스위트 실행.
- 스타일 규칙(들여쓰기/네이밍/따옴표 등)은 [docs/shell-style-guide.md](docs/shell-style-guide.md) 참고 — Google Shell Style Guide를 기반으로 이 저장소의 POSIX sh 제약에 맞게 조정한 버전입니다.
- 경로/환경변수 하드코딩 재발 방지 감사([docs/hardcoded-paths-patterns.md](docs/hardcoded-paths-patterns.md))와 `sed`의 BSD/GNU 이식성 감사([docs/sed-portability-audit.md](docs/sed-portability-audit.md))는 각각 `scripts/lint/check-hardcoded-paths.sh`와 `scripts/lib.sh`/`scripts/uninstall/03_clean_env_vars.sh`의 실제 회귀 사례를 근거로 정리한 문서입니다.
- POSIX sh를 계속 유지하기로 한 근거(bash로 옮겼을 때의 실제 이점/함정 조사)는 [docs/posix-sh-vs-bash-research.md](docs/posix-sh-vs-bash-research.md)(decision-19) 참고.
- 전체 흐름만 확인: `./install.sh --dry-run --all --yes`, `./uninstall.sh --dry-run --yes`
- 실기기 검증(Homebrew 부트스트랩, Intel Mac 등)은 `.github/workflows/e2e-verify.yml` — `scripts/**`/`install.sh`/`uninstall.sh`/`.tool-versions`가 바뀐 채로 `main`에 push/PR되면 자동 실행되고, 그 외에는 `workflow_dispatch`로 수동 실행. GitHub 호스팅 macOS 러너(arm64+Intel)에서 검증, 공개 저장소라 무료.

<br>

## 📝 License

<div align="center">

[MIT](https://opensource.org/licenses/MIT) — 누구나 자유롭게 가져다 쓰고 고칠 수 있습니다. (이 저장소의 [LICENSE](LICENSE) 파일도 동일한 내용입니다.)

Made with 🧉 by [coralstay](https://github.com/coralstay)

</div>
