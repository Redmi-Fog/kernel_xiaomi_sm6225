#!/bin/bash
#
# Compile script for vauxite Kernel
# Copyright (C) 2020-2021 Adithya R.

SECONDS=0 # builtin bash timer
ZIPNAME="NoName-fog-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$(pwd)/tc/clang-r450784e"
AK3_DIR="$(pwd)/android/AnyKernel3"

BASE_DEFCONFIG="vendor/bengal-perf_defconfig"
FOG_CONFIG="vendor/xiaomi/fog.config"
KSU_CONFIG="vendor/ksu.config"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

export PATH="$TC_DIR/bin:$PATH"
export KBUILD_BUILD_USER=dp02xd
export KBUILD_BUILD_HOST=android-build

if ! [ -d "$TC_DIR" ]; then
	echo "AOSP clang not found! Cloning to $TC_DIR..."
	if ! git clone --depth=1 -b 14 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"; then
		echo "Cloning failed! Aborting..."
		exit 1
	fi
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
	rm -rf out
fi

mkdir -p out

echo -e "\nMerging configuration fragments for fog..."
MAKE_ARGS="ARCH=arm64" ARCH=arm64 ./scripts/kconfig/merge_config.sh -O out \
	"arch/arm64/configs/$BASE_DEFCONFIG" \
	"arch/arm64/configs/$FOG_CONFIG" \
	"arch/arm64/configs/$KSU_CONFIG" || exit 1

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make O=out ARCH=arm64 savedefconfig
	cp out/defconfig arch/arm64/configs/vendor/fog-perf_defconfig
	echo -e "\nSuccessfully saved merged defconfig to arch/arm64/configs/vendor/fog-perf_defconfig"
	exit 0
fi

if [[ $1 = "-rf" || $1 = "--regen-full" ]]; then
	cp out/.config arch/arm64/configs/vendor/fog-perf_defconfig
	echo -e "\nSuccessfully saved full combined config to arch/arm64/configs/vendor/fog-perf_defconfig"
	exit 0
fi

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 Image.gz dtb dtbo.img 2> >(tee log.txt >&2) || exit $?

kernel="out/arch/arm64/boot/Image.gz"
dtb="out/arch/arm64/boot/dtb"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ -f "$kernel" ]; then
	echo -e "\nKernel compiled successfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r "$AK3_DIR" AnyKernel3
	elif ! git clone -q https://github.com/CHRISL7/AnyKernel3 -b master; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
	cp $kernel $dtb $dtbo AnyKernel3
	cd AnyKernel3
	git checkout master &> /dev/null
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
else
	echo -e "\nCompilation failed!"
	exit 1
fi
