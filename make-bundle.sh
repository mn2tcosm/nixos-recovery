#!/usr/bin/env bash
# 복구 번들 생성기 — ssh 개인키 + vorta 프로필을 AES256으로 암호화해서 keys.tar.gpg 생성.
#
#   - 평문 묶음은 tmpfs(RAM, /run/user/1000)에서만 만들고 끝나면 즉시 삭제 → 디스크에 평문 안 남음.
#   - 암호(passphrase)는 실행할 때 직접 입력. 절대 파일/스크립트에 평문으로 박지 말 것.
#   - 이 스크립트 자체엔 비밀이 없으니 공개 repo에 커밋해도 됨(번들을 어떻게 만들었는지 기록용).
set -euo pipefail

SSH=/mnt/mn2/state/users/mn2tcosm/auth/ssh
PROFILE=/mnt/mn2/debian-archive/vorta_profile.json
OUT="$(dirname "$(realpath "$0")")/keys.tar.gpg"

STG="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/recovery.XXXXXX")"
trap 'rm -rf "$STG"' EXIT

# git키=설치용, borg키=borgbase 접속 열쇠(백업 안에서 못 꺼냄=순환), ghost키, config=ssh 매핑.
cp "$SSH"/{git_ed25519,git_ed25519.pub,borg_ed25519,borg_ed25519.pub,ghost_ed25519,ghost_ed25519.pub,config} "$STG"/
cp "$PROFILE" "$STG"/

# borgbase 데이터 복호용 passphrase 를 번들에 포함 → 평소엔 gpg 암호 하나만 기억하면 됨.
# (borgbase 는 repokey-blake2 라 'borg 키 + 이 암호' 둘 다 있어야 백업 복호 가능)
printf 'borgbase passphrase 입력(화면에 안 보임, 없으면 그냥 Enter): '
read -rs BORG_PASS; echo
[ -n "$BORG_PASS" ] && printf '%s' "$BORG_PASS" > "$STG/borg-passphrase.txt"
unset BORG_PASS

echo "묶을 내용:"; ls -1 "$STG"
echo "암호를 입력하세요(두 번). 분실하면 이 번들은 영구히 못 엽니다 ↓"
tar -czf - -C "$STG" . | gpg --symmetric --cipher-algo AES256 -o "$OUT"
echo "생성됨: $OUT"
