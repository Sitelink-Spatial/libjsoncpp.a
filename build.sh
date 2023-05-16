#!/bin/bash

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
            cd "${LIBBUILD}"
            git checkout ${LIBGITVER}
            cd "${BUILDOUT}"
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


LIBROOT="${BUILDOUT}/lib3"
LIBINSTFULL="${BUILDOUT}/install/${BUILDTARGET}/${BUILDTYPE}"

# iOS toolchain
if [[ $BUILDTARGET == *"ios"* ]]; then
    OS="ios"
    ARCH="arm64"
    gitCheckout "https://github.com/leetal/ios-cmake.git" "4.3.0" "${LIBROOT}/ios-cmake"
    TOOLCHAIN="-DCMAKE_TOOLCHAIN_FILE=${LIBROOT}/ios-cmake/ios.toolchain.cmake -DPLATFORM=OS64"
else
    OS="mac"
    ARCH="arm64"
fi

TARGET="${OS}-${ARCH}"
PKGNAME="${LIBNAME}.a.xcframework"
PKGROOT="${BUILDOUT}/pkg/${BUILDTYPE}/${PKGNAME}"
PKGOUT="${BUILDOUT}/pkg/${BUILDTYPE}/${PKGNAME}.zip"

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


#-------------------------------------------------------------------
# Checkout and build library
#-------------------------------------------------------------------
if    [ ! -z "${REBUILDLIBS}" ] \
   || [ ! -d "${LIBROOT}/${LIBNAME}" ]; then

    LIBBUILD="${LIBROOT}/${LIBNAME}"
    LIBBUILDOUT="${LIBBUILD}/build"

    rm -Rf "$LIBBUILD" "$PKGROOT"
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
# Create package
#-------------------------------------------------------------------
if    [ ! -z "${REBUILDLIBS}" ] \
   || [ ! -f "${PKGOUT}" ]; then

    INCPATH="include"
    LIBPATH="${LIBNAME}.a"

    mkdir -p "${PKGROOT}/${TARGET}"

    # Copy include files
    mkdir -p "${PKGROOT}/${TARGET}/include"
    cp -R "${LIBINSTFULL}/include/." "${PKGROOT}/${TARGET}/include/"

    # Copy lib file
    cp -R "${LIBINSTFULL}/lib/${LIBNAME}.a" "${PKGROOT}/${TARGET}/"

    # Copy manifest
    cp "${ROOTDIR}/Info.plist.in" "${PKGROOT}/Info.plist"
    sed -i '' "s#%%OS%%#${OS}#g" "${PKGROOT}/Info.plist"
    sed -i '' "s#%%ARCH%%#${ARCH}#g" "${PKGROOT}/Info.plist"
    sed -i '' "s#%%INCPATH%%#${INCPATH}#g" "${PKGROOT}/Info.plist"
    sed -i '' "s#%%LIBPATH%%#${LIBPATH}#g" "${PKGROOT}/Info.plist"

    # Create package
    cd "${PKGROOT}/.."
    zip -r "${PKGOUT}" "$PKGNAME" -x "*.DS_Store"
    cd "${BUILDOUT}"

    # Calculate sha256
    openssl dgst -sha256 < "${PKGOUT}" > "${PKGOUT}.sha256.txt"

fi
