
#! /bin/bash
# shellcheck disable=SC2154
 # Script For Building Android arm64 Kernel
 # Copyright (c) 2018-2021 Update script by Ivan_Ssl
 #
 # thanks to Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
#
#
#
set -e
#Kernel building script
# Function to show an informational message
msg() {
	echo
    echo -e "\e[1;32m$*\e[0m"
    echo
}

err() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

cdir() {
	cd "$1" 2>/dev/null || \
		err "The directory $1 doesn't exists !"
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR="$(pwd)"
BASEDIR="$(basename "$KERNEL_DIR")"
# The name of the Kernel, to name the ZIP
Anykernel3=$Anykernel3
ZIPNAME=$ZIPNAME
# Build Author
# Take care, it should be a universal and most probably, case-sensitive
AUTHOR="@Arrayfs"
# Architecture
ARCH=arm64
# The name of the device for which the kernel is built
MODEL="Xiaomi f"
# The codename of the device
DEVICE=riva
# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=final_defconfig
# Build modules. 0 = NO | 1 = YES
MODULES=0
# Specify compiler. 
# 'clang' or 'gcc'
COMPILER=gcc
# Specify linker.
# 'ld.lld'(default)
LINKER=ld.lld
# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=1
# Push ZIP to Telegram. 1 is YES | 0 is NO(default)
PTTG=1
	if [ $PTTG = 1 ]
	then
		# Set Telegram Chat ID
		chat_id="-1001267809228"
token=$token
	fi

# Generate a full DEFCONFIG prior building. 1 is YES | 0 is NO(default)
DEF_REG=0
# Files/artifacts
FILES=Image.gz-dtb
# Build dtbo.img (select this only if your source has support to building dtbo.img)
# 1 is YES | 0 is NO(default)
BUILD_DTBO=0
	if [ $BUILD_DTBO = 1 ]
	then 
		# Set this to your dtbo path. 
		# Defaults in folder out/arch/arm64/boot/dts
		DTBO_PATH=qcom/msm8917-pmi8937.dtb
	fi

# Sign the zipfile
# 1 is YES | 0 is NO
SIGN=0
	if [ $SIGN = 1 ]
	then
		#Check for java
		if command -v java > /dev/null 2>&1; then
			SIGN=1
		else
			SIGN=0
		fi
	fi

# Silence the compilation
# 1 is YES(default) | 0 is NO
SILENCE=0

# Debug purpose. Send logs on every successfull builds
# 1 is YES | 0 is NO(default)
LOG_DEBUG=0

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

# Check if we are using a dedicated CI ( Continuous Integration ), and
# set KBUILD_BUILD_VERSION and KBUILD_BUILD_HOST and CI_BRANCH

## Set defaults first
DISTRO=$(source /etc/os-release && echo ${NAME})
KBUILD_BUILD_HOST=$AUTHOR_HOST
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)
TERM=xterm
export KBUILD_BUILD_HOST CI_BRANCH TERM

## Check for CI
if [ "$CI" ]
then
	if [ "$CIRCLECI" ]
	then
		export KBUILD_BUILD_VERSION=$CIRCLE_BUILD_NUM
		export KBUILD_BUILD_HOST=$AUTHOR_HOST
		export CI_BRANCH=$CIRCLE_BRANCH
	fi
	if [ "$DRONE" ]
	then
		export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
		export KBUILD_BUILD_HOST=$DRONE_SYSTEM_HOST
		export CI_BRANCH=$DRONE_BRANCH
		export BASEDIR=$DRONE_REPO_NAME # overriding
		export SERVER_URL="${DRONE_SYSTEM_PROTO}://${DRONE_SYSTEM_HOSTNAME}/${AUTHOR}/${BASEDIR}/${KBUILD_BUILD_VERSION}"
	else
		echo "Not presetting Build Version"
	fi
fi

#Check Kernel Version
KERVER=$(make kernelversion)


# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Set Date 
DATE=$(TZ=GMT+7 date +"%Y%m%d-%H%M")

#Now Its time for other stuffs like cloning, exporting, etc

 clone() {
	echo " "
	if [ $COMPILER = "gcc" ]
	then
		msg "|| Cloning GCC in Proccessing ||"
		wget -O 64.zip https://github.com/mvaisakh/gcc-arm64/archive/1a4410a4cf49c78ab83197fdad1d2621760bdc73.zip;unzip 64.zip;mv gcc-arm64-1a4410a4cf49c78ab83197fdad1d2621760bdc73 gcc64
		wget -O 32.zip https://github.com/mvaisakh/gcc-arm/archive/c8b46a6ab60d998b5efa1d5fb6aa34af35a95bad.zip;unzip 32.zip;mv gcc-arm-c8b46a6ab60d998b5efa1d5fb6aa34af35a95bad gcc32

		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32
		ELF_DIR=$KERNEL_DIR/$GCC64_DIR/aarch64-elf

	fi
	
	if [ $COMPILER = "clang" ]
	then
		msg "|| Cloning Clang in Proccessing ||"
		git clone --depth=1 https://github.com/Correctl/proton-clang clang-llvm
		# Toolchain Directory defaults to clang-llvm
		TC_DIR=$KERNEL_DIR/clang-llvm
	fi

	msg "|| Cloning Anykernel3 ||"
	git clone --depth 1 --no-single-branch https://github.com/RandomiDn/Anykernel3 -b stock-riva
	msg "|| Cloning libufdt ||"
	git clone https://android.googlesource.com/platform/system/libufdt "$KERNEL_DIR"/scripts/ufdt/libufdt
	if [ $MODULES = "1" ]
	then
	    msg "|| Cloning modules ||"
	    git clone --depth 1 https://github.com/neternels/neternels-modules Mod
	fi
}

##------------------------------------------------------##

exports() {
	KBUILD_BUILD_USER=$AUTHOR
	SUBARCH=$ARCH

	if [ $COMPILER = "clang" ]
	then
		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$PATH
	elif [ $COMPILER = "gcc" ]
	then
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$ELF_DIR/bin:/usr/local/bin:/usr/bin:$PATH
	fi

	BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	PROCS=$(nproc --all)

	export KBUILD_BUILD_USER ARCH SUBARCH PATH \
		KBUILD_COMPILER_STRING BOT_MSG_URL \
		BOT_BUILD_URL PROCS
}

##---------------------------------------------------------##

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$chat_id" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

tg_post_build() {
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$chat_id"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$2 | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

##----------------------------------------------------------##

build_kernel() {
	if [ $INCREMENTAL = 0 ]
	then
		msg "|| Cleaning Sources ||"
		make clean && make mrproper && rm -rf out
	fi

	if [ "$PTTG" = 1 ]
 	then
		tg_post_msg "<b>🔌Group On: [<a href='https://t.me/Random_iDn'>@Random_iDn</a>]</b>%0A<b>🔌Builder Name: </b><code>$AUTHOR</code>%0A<b>🔌Straight: [$KBUILD_BUILD_VERSION]-[$COMPILER]</b>%0A<b>🔌Machine: </b><code>$DISTRO</code>%0A<b>🔌Kernel: </b><code>$KERVER</code>%0A<b>Date: </b><code>$(TZ=$TZ date)</code>%0A<b>Device: </b><code>$MODEL[$DEVICE]</code>%0A<b>🔌PipeLine: </b><code>$(uname | awk -F: '{ print $1 }') $(uname -a | awk -F: '{ print $1 }')</code>%0A<b>🔌Core: </b><code>$PROCS</code>%0A<b>🔌Tools: </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>🔌Branch: </b><code>$CI_BRANCH</code>%0A<b>🔌Commit: </b><code>$COMMIT_HEAD</code>%0A[<a href='$SERVER_URL'><a href='https://t.me/RandomiDn'>©Channel</a>]</a>"
	fi

	make O=out $DEFCONFIG
	if [ $DEF_REG = 1 ]
	then
		cp .config out/arch/arm64/configs/$DEFCONFIG
		git add arch/arm64/configs/$DEFCONFIG
		git commit -m "load_defconfig: Regenerate config setup release

						This is an auto-generated commit"
	fi

	BUILD_START=$(date +"%s")
	
	if [ $COMPILER = "clang" ]
	then
		MAKE+=(
			CROSS_COMPILE=aarch64-linux-gnu- \
			CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
			CC=clang \
			AR=llvm-ar \
			OBJDUMP=llvm-objdump \
			STRIP=llvm-strip
		)
	elif [ $COMPILER = "gcc" ]
	then
		MAKE+=(
			CROSS_COMPILE_ARM32=arm-eabi- \
			CROSS_COMPILE=aarch64-elf-
			LD=aarch64-elf-ld.bfd
		)
	fi
	
	if [ $SILENCE = "1" ]
	then
		MAKE+=( -s )
	fi

	msg "|| Started Compilation ||"
	tg_post_msg "<code>|🔛|execute...</code>"
	make -j"$PROCS" O=out \
	LD=$LINKER "${MAKE[@]}" 2>&1 | tee error.log
	if [ $MODULES = "1" ]
	then
	    make -j"$PROCS" O=out \
		 "${MAKE[@]}" modules_prepare
	    make -j"$PROCS" O=out \
		 "${MAKE[@]}" modules INSTALL_MOD_PATH="$KERNEL_DIR"/out/modules
	    make -j"$PROCS" O=out \
		 "${MAKE[@]}" modules_install INSTALL_MOD_PATH="$KERNEL_DIR"/out/modules
	    find "$KERNEL_DIR"/out/modules -type f -iname '*.ko' -exec cp {} Mod/system/lib/modules/ \;
	fi

		BUILD_END=$(date +"%s")
		DIFF=$((BUILD_END - BUILD_START))

		if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/$FILES ]
		then
			msg "|| Kernel Successfully Compiled ||"
			tg_post_msg "<code>|✅|Done...</code>"
			if [ $BUILD_DTBO = 1 ]
			then
				msg "|| Building DTBO ||"
				tg_post_msg "<code>Building DTBO..</code>"
				python2 "$KERNEL_DIR/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
					create "$KERNEL_DIR/out/arch/arm64/boot/dtbo.img" --page_size=4096 "$KERNEL_DIR/out/arch/arm64/boot/dts/$DTBO_PATH"
			fi
				gen_zip
			else
			if [ "$PTTG" = 1 ]
 			then
				tg_post_build "error.log" "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
			fi
		fi
	
}

##--------------------------------------------------------------##

gen_zip() {
	msg "|| Zipping into a Flashable zip ||"
	mv $(pwd)/out/arch/arm64/boot/$FILES Anykernel3/$FILES
	if [ $BUILD_DTBO = 1 ]
	then
		mv "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img
	fi
	cdir $Anykernel3
	zip -r $ZIPNAME-$DEVICE-$KERVER . -x ".git*" -x "README.md" -x "*.zip"
	if [ $MODULES = "1" ]
	then
	    cdir ../Mod
	    rm -rf system/lib/modules/placeholder
	    zip -r $ZIPNAME-$DEVICE-modules-$KERVER . -x ".git*" -x "LICENSE.md" -x "*.zip"
	    MOD_NAME="$ZIPNAME-$DEVICE-modules-$KERVER"
	    cdir ../AnyKernel3
	fi

	## Prepare a final zip variable
	ZIP_FINAL="$ZIPNAME-$DEVICE-$KERVER"

	if [ $SIGN = 1 ]
	then
		## Sign the zip before sending it to telegram
		if [ "$PTTG" = 1 ]
 		then
 			msg "|| Signing Zip ||"
			tg_post_msg "<code>|📥|Signing zip...</code>"
 		fi
		curl -sLo zipsigner-3.0.jar https://raw.githubusercontent.com/RandomiDn/AnyKernel3/stock-riva/zipsigner-3.0.jar
		java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
		ZIP_FINAL="$ZIP_FINAL-sig"
	fi

	if [ "$PTTG" = 1 ]
 	then
	    tg_post_build "$ZIP_FINAL.zip" "<b>🛠Successfull Kernel for device #riva / #rolex </b>%0A<b>Minutes: </b><code>$((DIFF / 60))(s)</code>%0A<b>Seconds: </b><code>$((DIFF % 60))(s)</code>"
	    if [ $MODULES = "1" ]
	    then
		cd ../Mod
		tg_post_build "$MOD_NAME.zip" "Flash this in magisk for loadable kernel modules"
	    fi
	fi
	cd ..
}

clone
exports
build_kernel

if [ $LOG_DEBUG = "1" ]
then
	tg_post_build "error.log" "$chat_id" "Debug Mode Logs"
fi

##----------------*****-----------------------------##
