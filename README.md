# nixos-recovery

최악의 상황(삼성·인텔 NVMe 동시 사망, 새 디스크 1개, 주변에 도와줄 컴퓨터 없음)에서
내 NixOS 환경을 맨바닥부터 되살리기 위한 **부트스트랩 키트**.

- `keys.tar.gpg` — ssh 개인키 + vorta 프로필을 **AES256으로 암호화**한 묶음.
  GitHub 비밀스캔은 평문만 잡으므로 암호화된 이 blob 은 공개 repo에 둬도 안전.
  **단, 암호(passphrase)를 분실하면 영구히 못 엽니다.**
- `make-bundle.sh` — 이 번들을 만든/다시 만드는 스크립트(비밀 없음).

## 들어있는 것
- `git_ed25519` (+.pub) — private repo `nixos-config` clone 용 (설치 단계)
- `borg_ed25519` (+.pub) — borgbase **서버 접속** 열쇠 (백업 안에서 못 꺼냄=순환이라 바깥에 보관)
- `borg-passphrase.txt` — borgbase **데이터 복호** 암호 (repokey-blake2)
- `ghost_ed25519` (+.pub) — incus ghost 컨테이너 용
- `config` — ssh 매핑(github→git키, *.repo.borgbase.com→borg키)
- `known_hosts` — github·borgbase 서버 신분증(미리 넣어둬서 ssh-keyscan 불필요)
- `vorta_profile.json` — borgbase repo 주소 등

> borg는 접속 키(ssh) + 데이터 암호(passphrase) **둘 다** 필요 — 성격이 다른 별개의 비밀.
> 둘 다 번들에 넣었으니, 기억할 건 이 번들을 여는 **gpg 암호 하나뿐**.

## 복호화 (gpg 있는 평소 시스템)
```sh
gpg -d keys.tar.gpg | tar -xz
```

## 최악 시나리오 부트스트랩 (NixOS minimal ISO — gpg 없음)
1. minimal ISO 부팅 → 네트워크 연결 → `sudo -i` (root 로)
2. 번들 내려받기:
   ```sh
   curl -LO https://raw.githubusercontent.com/mn2tcosm/nixos-recovery/main/keys.tar.gpg
   ```
3. 일회용 gpg 로 복호 (ISO엔 gpg 미설치):
   ```sh
   nix run nixpkgs#gnupg -- -d keys.tar.gpg | tar -xz
   ```
4. 키 배치 (root):
   ```sh
   mkdir -p /root/.ssh
   cp git_ed25519 borg_ed25519 ghost_ed25519 config known_hosts /root/.ssh/
   chmod 700 /root/.ssh
   chmod 600 /root/.ssh/*
   # known_hosts 를 같이 넣어 ssh-keyscan 불필요.
   # 단, 혹시 "REMOTE HOST IDENTIFICATION HAS CHANGED" 뜨면(서버 키 교체 등):
   #   ssh-keygen -R github.com -f /root/.ssh/known_hosts && ssh-keyscan github.com >> /root/.ssh/known_hosts
   ```
5. **시스템 설치 먼저** (git+ssh 로 private flake 직접 설치, `/dev/nvme0n1`=새 디스크):
   ```sh
   disko-install --flake git+ssh://git@github.com/mn2tcosm/nixos-config#nixos --disk main /dev/nvme0n1
   ```
6. 재부팅 → 새 시스템 로그인(root 임시암호 설정 → TTY 에서 `passwd mn2tcosm`)
7. **그 다음 데이터 복원** (borgbase → `/mnt/mn2/state`). 단일 디스크라
   `/mnt/mn2` 는 별도 디스크가 아니라 root 위의 폴더가 됨(거기로 복원):
   ```sh
   export BORG_RSH='ssh -i /root/.ssh/borg_ed25519'
   borg extract 'ssh://tm75386d@tm75386d.repo.borgbase.com/./repo::<아카이브이름>'
   ```
   (borg passphrase 는 위에서 푼 `borg-passphrase.txt` 값 사용 — 프롬프트에 입력)

> 순서가 중요: **설치(껍데기) → 복원(데이터)**. 거꾸로 하면 disko 가 데이터를 밀어버림.
> 상세 절차는 private 의 `복구시나리오.md` 참고.
