#!/bin/sh
set -eu

case "${1-}:${2-}" in
    void:x86_64|void:x86_64-musl|chimera:x86_64) ;;
    *)
        echo "Usage: $0 <void|chimera> <architecture>" >&2
        exit 1
        ;;
esac

[ "$(id -u)" -eq 0 ] || { echo "Run inside a privileged container as root." >&2; exit 1; }

distro=$1
arch=$2
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
out="$root/out"
mkdir -p "$out" "$root/work"
work=$(mktemp -d "$root/work/$distro-$arch.XXXXXX")
datecode=$(date -u +%Y%m%d)

case "$distro" in
    void)
        xbps-install -Syu xbps
        xbps-install -Syu
        xbps-install -y bash git ca-certificates kmod xz lzo outils dosfstools e2fsprogs
        git clone --depth 1 https://github.com/void-linux/void-mklive.git "$work/src"
        cd "$work/src"
        ./mkiso.sh -a "$arch" -b base -d "$datecode"
        image="void-live-$arch-$datecode-base.iso"
        ;;
    chimera)
        apk update
        apk upgrade
        apk add git ca-certificates util-linux
        git clone --depth 1 https://github.com/chimera-linux/chimera-live.git "$work/src"
        cd "$work/src"
        image="chimera-linux-$arch-LIVE-$datecode-base.iso"
        ./mklive-image.sh -b base -- -a "$arch" -o "$image"
        ;;
esac

[ -s "$image" ] || { echo "Missing image: $image" >&2; exit 1; }
cp "$image" "$out/"
{
    printf 'Source: %s\n' "$(git remote get-url origin)"
    printf 'Commit: %s\n' "$(git rev-parse HEAD)"
    printf 'Built: %s\n' "$(date -u +%FT%TZ)"
} > "$out/$image.source.txt"
