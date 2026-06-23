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

# 変更後
cd linux-rockchip
git checkout "${KERNEL_BRANCH}"

# ==========================================
# KernelSUの組み込み処理
# ==========================================
# 1. KernelSUのソースをカーネルツリーに統合
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

# 2. KernelSUが勝手に「モジュール(M)」化されるのを防ぐ（強制組み込み化）
sed -i 's/tristate/bool/g' drivers/kernelsu/Kconfig

# 3. KSUが要求している存在しない関数（ext4_unregister_sysfs）の呼び出しをソースコードから削除
sed -i '/ext4_unregister_sysfs/d' drivers/kernelsu/runtime/boot_event.c

# 4. Debianビルド用の共通コンフィグファイル群へ設定を追記
echo "CONFIG_KSU=y" >> debian.rockchip/config/config.common.ubuntu
echo "CONFIG_KALLSYMS=y" >> debian.rockchip/config/config.common.ubuntu
echo "CONFIG_KALLSYMS_ALL=y" >> debian.rockchip/config/config.common.ubuntu
# ==========================================

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=aarch64-linux-gnu-gcc
export LANG=C

# Compile the kernel into a deb package
fakeroot debian/rules clean binary-headers binary-rockchip do_mainline_build=true v=1
