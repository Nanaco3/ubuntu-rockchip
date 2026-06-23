#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${SUITE} ]]; then
    echo "Error: SUITE is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/suites/${SUITE}.sh"

# Clone the kernel repo
if ! git -C linux-rockchip pull; then
    git clone --progress -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" linux-rockchip --depth=2
fi

cd linux-rockchip
git checkout "${KERNEL_BRANCH}"

# 変更後
cd linux-rockchip
git checkout "${KERNEL_BRANCH}"

# ==========================================
# KernelSUの組み込み処理（追記ここから）
# ==========================================
# 1. KernelSUのソースをカーネルツリーに統合
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

# 2. .config ファイルへ設定を追記
# （ビルドプロセス内で後から作成される可能性があるため、ここでダミーのconfigを作るか、
# 既存のconfigファイルの末尾に設定を追記する）
echo "CONFIG_KSU=y" >> .config
echo "CONFIG_KALLSYMS=y" >> .config
echo "CONFIG_KALLSYMS_ALL=y" >> .config
# ==========================================
# （追記ここまで）

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=aarch64-linux-gnu-gcc
export LANG=C

# Compile the kernel into a deb package
fakeroot debian/rules clean binary-headers binary-rockchip do_mainline_build=true v=1
