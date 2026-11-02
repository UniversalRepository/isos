#!/bin/sh
set -eu

case "${1-}:${2-}" in
    void:x86_64|void:x86_64-musl|chimera:x86_64|alpine:x86_64) ;;
    *)
        echo "Usage: $0 <void|chimera|alpine> <architecture>" >&2
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
        apk add git ca-certificates util-linux util-linux-mount
        git clone --depth 1 https://github.com/chimera-linux/chimera-live.git "$work/src"
        cd "$work/src"
        image="chimera-linux-$arch-LIVE-$datecode-base.iso"
        ./mklive-image.sh -b base -- -a "$arch" -o "$image"
        ;;
    alpine)
        [ "$(apk --print-arch)" = "$arch" ] || {
            echo "Alpine builds require a native $arch container." >&2
            exit 1
        }
        printf '%s\n' \
            https://dl-cdn.alpinelinux.org/alpine/edge/main \
            https://dl-cdn.alpinelinux.org/alpine/edge/community \
            > /etc/apk/repositories
        apk update
        apk upgrade --available
        apk add alpine-keys abuild alpine-conf apk-tools busybox \
            ca-certificates fakeroot git grub-efi mtools openssl \
            squashfs-tools syslinux xorriso
        git clone --depth 1 https://github.com/alpinelinux/aports.git "$work/src"

        sed -i 's/ add --initdb --no-chown/ add --initdb/g' "$work/src/scripts/mkimage.sh"

        signing="$work/signing"
        trap 'rm -rf "$signing"' 0
        trap 'exit 1' HUP INT TERM
        export ABUILD_USERDIR="$signing"
        export ABUILD_USERCONF="$signing/abuild.conf"
        mkdir -p "$signing"
        abuild-keygen -a -n
        . "$ABUILD_USERCONF"
        export PACKAGER_PRIVKEY
        export PACKAGER_PUBKEY="$PACKAGER_PRIVKEY.pub"

        cd "$work/src"
        sh ./scripts/mkimage.sh --tag "edge-$datecode" \
            --arch "$arch" --profile standard \
            --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
            --repository https://dl-cdn.alpinelinux.org/alpine/edge/community \
            --workdir "$work/mkimage" --outdir "$work/images"
        image="$work/images/alpine-standard-edge-$datecode-$arch.iso"
        ;;
esac

[ -s "$image" ] || { echo "Missing image: $image" >&2; exit 1; }
cp "$image" "$out/"
{
    printf 'Source: %s\n' "$(git remote get-url origin)"
    printf 'Commit: %s\n' "$(git rev-parse HEAD)"
    printf 'Built: %s\n' "$(date -u +%FT%TZ)"
} > "$out/$(basename "$image").source.txt"
