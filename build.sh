#!/bin/bash

# Examples:
#
#   Build for desktop
#   > ./build.sh build release arm64-apple-macosx
#
#   Build for iphone
#   > ./build.sh build release arm64-apple-ios14.0


#--------------------------------------------------------------------
# Script params

LIBNAME="libjsoncpp"

# What to do (build, test)
BUILDWHAT="$1"

# Build type (release, debug)
BUILDTYPE="$2"

# Build target, i.e. arm64-apple-macosx, aarch64-apple-ios11.0, x86_64-apple-ios13.0-simulator, ...
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
    LIBGIT="$1"
    LIBGITVER="$2"
    LIBBUILD="$3"

    # Check out c++ library if needed
    if [ ! -d "${LIBBUILD}" ]; then
        Log "Checking out: ${LIBGIT} -> ${LIBGITVER}"
        git clone ${LIBGIT} ${LIBBUILD}
        if [ ! -z "${LIBGITVER}" ]; then
            git clone -b ${LIBGITVER} ${LIBGIT} ${LIBBUILD}
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

if [[ $BUILDTARGET == *"ios"* ]]; then
    OS="ios"
else
    OS="macos"
fi

if [[ $BUILDTARGET == *"arm64"* ]]; then
    ARCH="arm64"
else
    ARCH="x86_64"
fi

TARGET="${OS}-${ARCH}"

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
    TOOLCHAIN="-DCMAKE_TOOLCHAIN_FILE=${LIBROOT}/ios-cmake/ios.toolchain.cmake -DPLATFORM=OS64"
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

    Log "Rebuilding ${LIBNAME}"

    cd "${LIBBUILD}"

    cmake . -B ./build -DCMAKE_BUILD_TYPE=${BUILDTYPE} \
                    ${TOOLCHAIN} \
                    -DCMAKE_INSTALL_PREFIX="${LIBINSTFULL}"

    cmake --build ./build -j$NUMCPUS

    cmake --install ./build

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

    # Copy lib file
    cp -R "${LIBINSTFULL}/lib/${LIBNAME}.a" "${PKGROOT}/${TARGET}/"

    # Copy manifest
    cp "${ROOTDIR}/Info.target.plist.in" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%OS%%|${OS}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%ARCH%%|${ARCH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
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
        if [ -f "$PKGNAME" ]; then
            rm "$PKGNAME"
        fi

        # Create new package
        zip -r "${PKGOUT}" "$PKGNAME" -x "*.DS_Store"
        # touch "${PKGOUT}"

        # Calculate sha256
        openssl dgst -sha256 < "${PKGOUT}" > "${PKGOUT}.zip.sha256.txt"

        cd "${BUILDOUT}"

    fi
fi
