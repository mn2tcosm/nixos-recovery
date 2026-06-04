#!/usr/bin/env bash
# bootstrap.sh — doomsday entry point (public nixos-recovery)
#   화면 출력 = ASCII 영어 (ISO TTY 호환). 주석(#) = 한글.
#
# minimal ISO 에서:
#   sudo -i
#   curl -fLO https://raw.githubusercontent.com/mn2tcosm/nixos-recovery/main/bootstrap.sh
#   bash bootstrap.sh
#
# 하는 일:
#   - (minimal ISO 대비) nix 실험기능 켜고, 필요한 도구를 nix shell 로 채워 자기 재실행
#   - keys.tar.gpg 받아 gpg 복호(headless=loopback) -> /root/.ssh (git/borg/ghost + config + known_hosts, 600)
#   - nixos-config 를 RAM(/root)에 clone -> setup.sh 메뉴(툴박스) 실행
set -euo pipefail

# minimal ISO 는 nix-command/flakes 가 기본 꺼져 있음 -> 켜고 시작
# (export 라 재실행된 자신 + 이후 nixos-install --flake 까지 상속됨)
export NIX_CONFIG="experimental-features = nix-command flakes"

# ISO 에 없을 수 있는 도구를 nix shell 로 채워 자기 자신을 재실행
if ! command -v git >/dev/null || ! command -v gpg >/dev/null || ! command -v sgdisk >/dev/null \
   || ! command -v mkfs.btrfs >/dev/null || ! command -v rsync >/dev/null; then
  echo "preparing tools (git/gnupg/gptfdisk/btrfs-progs/rsync/...)..."
  exec nix shell nixpkgs#git nixpkgs#gnupg nixpkgs#gptfdisk nixpkgs#dosfstools \
       nixpkgs#e2fsprogs nixpkgs#btrfs-progs nixpkgs#parted nixpkgs#rsync \
       --command bash "$0" "$@"
fi

RAW="https://raw.githubusercontent.com/mn2tcosm/nixos-recovery/main"
REPO_SSH="git@github.com:mn2tcosm/nixos-config"

echo "=== recovery bootstrap ==="
cd /root
echo "1) fetching key bundle..."
curl -fLO "$RAW/keys.tar.gpg"

echo "2) decrypt (enter gpg passphrase at the prompt):"
# 헤드리스 ISO 엔 pinentry 창이 없음 -> loopback 으로 터미널에서 직접 입력
mkdir -p /root/.gnupg && chmod 700 /root/.gnupg
grep -q allow-loopback-pinentry /root/.gnupg/gpg-agent.conf 2>/dev/null \
  || echo allow-loopback-pinentry >> /root/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent 2>/dev/null || true
gpg --pinentry-mode loopback -d keys.tar.gpg | tar -xz

mkdir -p /root/.ssh
cp git_ed25519 borg_ed25519 ghost_ed25519 config known_hosts /root/.ssh/
chmod 700 /root/.ssh; chmod 600 /root/.ssh/*
echo "   keys installed -> /root/.ssh"

echo "3) cloning nixos-config to RAM..."
rm -rf /root/nixos-config
git clone "$REPO_SSH" /root/nixos-config

echo "4) launching toolbox menu (pick disk + action there)..."
exec bash /root/nixos-config/setup.sh
