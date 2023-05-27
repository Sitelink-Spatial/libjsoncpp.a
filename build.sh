#!/bin/bash

# Examples:
#
#   Build for desktop
#   > ./build.sh build release arm64-apple-macosx
#
#   Build for iphone
#   > ./build.sh build release arm64-apple-ios14.0
#
#   Build for iphone
#   > ./build.sh build release x86_64-apple-ios14.0-simulator

# Package layout
#
# ├── Info.plist
# ├── [ios-arm64]
# │     ├── mylib.a
# │     └── [include]
# ├── [ios-arm64_x86_64-simulator]
# │     ├── mylib.a
# │     └── [include]
# └── [macos-arm64_x86_64]
#       ├── mylib.a
#       └── [include]


#--------------------------------------------------------------------
# Script params

LIBNAME="libjsoncpp"

# What to do (build, test)
BUILDWHAT="$1"

# Build type (release, debug)
BUILDTYPE="$2"

# Build target, i.e. arm64-apple-macosx, aarch64-apple-ios14.0, x86_64-apple-ios14.0-simulator, ...
BUILDTARGET="$3"

# Build Output
BUILDOUT="$4"

#--------------------------------------------------------------------
# Functions

Log()
{
    echo ">>>>>> $@"
}

exitWithError()
{
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "$@"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit -1
}

gitCheckout()
{
    local LIBGIT="$1"
    local LIBGITVER="$2"
    local LIBBUILD="$3"

    # Check out c++ library if needed
    if [ ! -d "${LIBBUILD}" ]; then
        Log "Checking out: ${LIBGIT} -> ${LIBGITVER}"
        if [ ! -z "${LIBGITVER}" ]; then
            git clone --depth 1 -b ${LIBGITVER} ${LIBGIT} ${LIBBUILD}
        else
            git clone ${LIBGIT} ${LIBBUILD}
        fi
    fi

    if [ ! -d "${LIBBUILD}" ]; then
        exitWithError "Failed to checkout $LIBGIT"
    fi
}


#--------------------------------------------------------------------
# Options

# Sync command
SYNC="rsync -a"

# Default build what
if [ -z "${BUILDWHAT}" ]; then
    BUILDWHAT="build"
fi

# Default build type
if [ -z "${BUILDTYPE}" ]; then
    BUILDTYPE="release"
fi

if [ -z "${BUILDTARGET}" ]; then
    BUILDTARGET="arm64-apple-macosx"
fi

# ios-arm64_x86_64-simulator
if [[ $BUILDTARGET == *"ios"* ]]; then
    if [[ $BUILDTARGET == *"simulator"* ]]; then
        TGT_OS="ios-simulator"
    else
    TGT_OS="ios"
    fi
else
    TGT_OS="macos"
fi

if [[ $BUILDTARGET == *"arm64"* ]]; then
    if [[ $BUILDTARGET == *"x86_64"* ]]; then
        TGT_ARCH="arm64_x86_64"
    else
        TGT_ARCH="arm64"
    fi
else
    TGT_ARCH="x86_64"
fi

TARGET="${TGT_OS}-${TGT_ARCH}"

# NUMCPUS=1
NUMCPUS=$(sysctl -n hw.physicalcpu)

#--------------------------------------------------------------------
# Get root script path
SCRIPTPATH=$(realpath $0)
if [ ! -z "$SCRIPTPATH" ]; then
    ROOTDIR=$(dirname $SCRIPTPATH)
else
    SCRIPTPATH=.
    ROOTDIR=.
fi

#--------------------------------------------------------------------
# Defaults

if [ -z $BUILDOUT ]; then
    BUILDOUT="${ROOTDIR}/build"
else
    # Get path to current directory if needed to use as custom directory
    if [ "$BUILDOUT" == "." ] || [ "$BUILDOUT" == "./" ]; then
        BUILDOUT="$(pwd)"
    fi
fi

# Make custom output directory if it doesn't exist
if [ ! -z "$BUILDOUT" ] && [ ! -d "$BUILDOUT" ]; then
    mkdir -p "$BUILDOUT"
fi

if [ ! -d "$BUILDOUT" ]; then
    exitWithError "Failed to create diretory : $BUILDOUT"
fi

LIBROOT="${BUILDOUT}/${TARGET}/lib3"
LIBINST="${BUILDOUT}/${TARGET}/install"

PKGNAME="${LIBNAME}.a.xcframework"
PKGROOT="${BUILDOUT}/pkg/${BUILDTYPE}/${PKGNAME}"
PKGOUT="${BUILDOUT}/pkg/${BUILDTYPE}/${PKGNAME}.zip"

# iOS toolchain
if [[ $BUILDTARGET == *"ios"* ]]; then

    gitCheckout "https://github.com/leetal/ios-cmake.git" "4.3.0" "${LIBROOT}/ios-cmake"

    if [[ $BUILDWHAT == *"xbuild"* ]]; then
        TOOLCHAIN="-GXcode"
    fi

    # https://github.com/leetal/ios-cmake/blob/master/ios.toolchain.cmake
    if [[ $BUILDTARGET == *"simulator"* ]]; then
        if [ "${TGT_ARCH}" == "x86" ]; then
            TGT_PLATFORM="SIMULATOR"
        elif [ "${TGT_ARCH}" == "x86_64" ]; then
            TGT_PLATFORM="SIMULATOR64"
        else
            TGT_PLATFORM="SIMULATORARM64"
        fi
    else
        TOOLCHAIN=
        if [ "${TGT_ARCH}" == "x86" ]; then
            TGT_PLATFORM="OS"
        elif [ "${TGT_ARCH}" == "x86_64" ]; then
            TGT_ARCH="arm64_x86_64"
            TGT_PLATFORM="OS64COMBINED"
        else
            TGT_PLATFORM="OS64"
        fi
    fi

    TOOLCHAIN="${TOOLCHAIN} \
               -DCMAKE_TOOLCHAIN_FILE=${LIBROOT}/ios-cmake/ios.toolchain.cmake \
               -DPLATFORM=${TGT_PLATFORM} \
               -DENABLE_BITCODE=OFF \
               "
fi


#--------------------------------------------------------------------
echo ""
Log "#--------------------------------------------------------------------"
Log "LIBNAME        : ${LIBNAME}"
Log "BUILDWHAT      : ${BUILDWHAT}"
Log "BUILDTYPE      : ${BUILDTYPE}"
Log "BUILDTARGET    : ${BUILDTARGET}"
Log "ROOTDIR        : ${ROOTDIR}"
Log "BUILDOUT       : ${BUILDOUT}"
Log "TARGET         : ${TARGET}"
Log "PLATFORM       : ${TGT_PLATFORM}"
Log "PKGNAME        : ${PKGNAME}"
Log "PKGROOT        : ${PKGROOT}"
Log "LIBROOT        : ${LIBROOT}"
Log "#--------------------------------------------------------------------"
echo ""

#-------------------------------------------------------------------
# Rebuild lib and copy files if needed
#-------------------------------------------------------------------
if [ ! -d "${LIBROOT}" ]; then

    Log "Reinitializing install..."

    mkdir -p "${LIBROOT}"

    REBUILDLIBS="YES"
fi


LIBBUILD="${LIBROOT}/${LIBNAME}"
LIBBUILDOUT="${LIBBUILD}/build"
LIBINSTFULL="${LIBINST}/${BUILDTARGET}/${BUILDTYPE}"

#-------------------------------------------------------------------
# Checkout and build library
#-------------------------------------------------------------------
if    [ ! -z "${REBUILDLIBS}" ] \
   || [ ! -d "${LIBROOT}/${LIBNAME}" ]; then

    rm -Rf "$LIBBUILD" "${PKGROOT}/${TARGET}"
    gitCheckout "https://github.com/open-source-parsers/jsoncpp.git" "1.9.5" "${LIBBUILD}"

    Log "Building ${LIBNAME}"

    cd "${LIBBUILD}"

    echo "\n====================== CONFIGURING =====================\n"
    cmake . -B ./build -DCMAKE_BUILD_TYPE=${BUILDTYPE} \
                    ${TOOLCHAIN} \
                    -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=YES \
                    -DCMAKE_INSTALL_PREFIX="${LIBINSTFULL}"

    if [[ $BUILDWHAT == *"xbuild"* ]]; then

        echo "\n==================== XCODE BUILDING ====================\n"

        # Get targets: xcodebuild -list -project mylib.xcodeproj
        xcodebuild -project "${LIBBUILDOUT}/jsoncpp.xcodeproj" \
                   -target jsoncpp_static \
                   -configuration Release \
                   -sdk iphonesimulator

        mkdir -p "${LIBINSTFULL}/include"
        cp -R "${LIBROOT}/${LIBNAME}/include/." "${LIBINSTFULL}/include/"

        mkdir -p "${LIBINSTFULL}/lib"
        cp -R "${LIBBUILDOUT}/lib/Release/." "${LIBINSTFULL}/lib/"

    else
        echo "\n======================= BUILDING =======================\n"
        cmake --build ./build -j$NUMCPUS

        echo "\n====================== INSTALLING ======================\n"
        cmake --install ./build
    fi

    cd "${BUILDOUT}"
fi

#-------------------------------------------------------------------
# Create target package
#-------------------------------------------------------------------
if    [ ! -z "${REBUILDLIBS}" ] \
   || [ ! -f "${PKGROOT}/${TARGET}" ]; then

    INCPATH="include"
    LIBPATH="${LIBNAME}.a"

    # Re initialize directory
    if [ -d "${PKGROOT}/${TARGET}" ]; then
        rm -Rf "${PKGROOT}/${TARGET}"
    fi
    mkdir -p "${PKGROOT}/${TARGET}"

    # Copy include files
    mkdir -p "${PKGROOT}/${TARGET}/include"
    cp -R "${LIBINSTFULL}/include/." "${PKGROOT}/${TARGET}/include/"
    if [ -z "$(ls -A "${PKGROOT}/${TARGET}/include/")" ]; then
        exitWithError "Failed to copy include files"
    fi

    # Copy lib file
    cp -R "${LIBINSTFULL}/lib/${LIBNAME}.a" "${PKGROOT}/${TARGET}/"
    if [ ! -f "${PKGROOT}/${TARGET}/${LIBNAME}.a" ]; then
        exitWithError "Failed to copy library file: ${LIBNAME}.a"
    fi

    # Copy manifest
    cp "${ROOTDIR}/Info.target.plist.in" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%OS%%|${TGT_OS}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%ARCH%%|${TGT_ARCH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%INCPATH%%|${INCPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%LIBPATH%%|${LIBPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"

fi


#-------------------------------------------------------------------
# Create full package
#-------------------------------------------------------------------
if [ -d "${PKGROOT}" ]; then

    cd "${PKGROOT}"

    TARGETINFO=
    for SUB in */; do
        echo "Adding: $SUB"
        if [ -f "${SUB}/Info.target.plist" ]; then
            TARGETINFO="$TARGETINFO$(cat "${SUB}/Info.target.plist")"
        fi
    done

    if [ ! -z "$TARGETINFO" ]; then

        TARGETINFO=""${TARGETINFO//$'\n'/\\n}""

        cp "${ROOTDIR}/Info.plist.in" "${PKGROOT}/Info.plist"
        sed -i '' "s|%%TARGETS%%|${TARGETINFO}|g" "${PKGROOT}/Info.plist"

        cd "${PKGROOT}/.."

        # Remove old package if any
        if [ -f "${PKGOUT}" ]; then
            rm "${PKGOUT}"
        fi

        # Create new package
        zip -r "${PKGOUT}" "$PKGNAME" -x "*.DS_Store"
        # touch "${PKGOUT}"

        # Calculate sha256
        openssl dgst -sha256 < "${PKGOUT}" > "${PKGOUT}.sha256.txt"

        cd "${BUILDOUT}"

    fi
fi
