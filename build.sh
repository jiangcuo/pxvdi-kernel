#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tag="138.0.0"
url="https://atomgit.com/openeuler/kernel"
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
    ;;
    "aarch64"|"arm64")
        DEFCONFIG="openeuler_defconfig"
        CROSS_COMPILE="aarch64-linux-gnu-"
        ARCH=arm64
    ;;
    "loongarch64"|"loong64")
        DEFCONFIG="loongson3_defconfig"
        CROSS_COMPILE="loongarch64-linux-gnu-"
        ARCH=loongarch
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

    make  ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" $DEFCONFIG
    ./scripts/kconfig/merge_config.sh -m .config  $DIR/config/$ARCH.kconfig
    ./scripts/kconfig/merge_config.sh -m .config  $DIR/config/common.kconfig
    make ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" olddefconfig

    make  ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" LOCALVERSION="" bindeb-pkg -j $(nproc) 
}

build


