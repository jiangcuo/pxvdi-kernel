#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/env.sh"

ARCH=$1
kertag="${tag%%.*}"

if [ -z $ARCH ]; then
    ARCH=$(arch)
fi

if [ ! -d  "$DIR/linux" ]; then
    git clone $url -b 6.6.0-$tag --depth=1  "$DIR/linux"
fi

rm -rf build

rsync -a linux/ build

case "$ARCH" in
    "x86_64"|"amd64")
        DEFCONFIG="openeuler_defconfig"
        CROSS_COMPILE="x86_64-linux-gnu-"
        ARCH=x86_64
        DEB_ARCH=amd64
    ;;
    "aarch64"|"arm64")
        DEFCONFIG="openeuler_defconfig"
        CROSS_COMPILE="aarch64-linux-gnu-"
        ARCH=arm64
        DEB_ARCH=arm64
    ;;
    "loongarch64"|"loong64")
        DEFCONFIG="loongson3_defconfig"
        CROSS_COMPILE="loongarch64-linux-gnu-"
        ARCH=loongarch
        DEB_ARCH=loong64
    ;;
    *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

build(){
    cd $DIR/build
    sed -i \
    -e "5c\EXTRAVERSION = -pxvdi" \
    -e "4c\SUBLEVEL = $kertag" \
    Makefile

    rm -rf $DIR/build/.git

    ARCH="$ARCH" make CROSS_COMPILE="$CROSS_COMPILE" $DEFCONFIG
    ARCH="$ARCH" ./scripts/kconfig/merge_config.sh -m .config  $DIR/config/common.kconfig
    ARCH="$ARCH" ./scripts/kconfig/merge_config.sh -m .config  $DIR/config/$ARCH.kconfig
    ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" make olddefconfig

    ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" make LOCALVERSION="" bindeb-pkg -j $(nproc)
}

build_meta(){
    local kernel_ver="6.6.${kertag}-pxvdi"
    local meta_name="linux-image-6.6-pxvdi"
    local tmpdir="$DIR/.meta-pkg-tmp"

    rm -rf "$tmpdir"
    mkdir -p "$tmpdir/DEBIAN"

    cat > "$tmpdir/DEBIAN/control" << EOF
Package: ${meta_name}
Version: ${tag}
Architecture: ${DEB_ARCH}
Maintainer: pxvdi
Depends: linux-image-${kernel_ver}
Section: metapackages
Priority: optional
Description: pxvdi kernel meta package
 Meta package pointing to the pxvdi custom kernel ${kernel_ver}.
EOF

    dpkg-deb --build "$tmpdir" "$DIR/${meta_name}_${tag}_${DEB_ARCH}.deb"
    rm -rf "$tmpdir"
    echo "Meta package: ${meta_name}_${tag}_${DEB_ARCH}.deb"
}

build
build_meta
