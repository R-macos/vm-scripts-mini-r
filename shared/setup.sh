#!/bin/bash

set -e

while [[ $# -gt 0 ]]; do
    case "$1" in
	-r) RECIPES=1; shift ;;
	-a) AUTOC=1; shift ;;
	-h) echo "
 Usage: $0 [-r | -a | -h]

 Options: -h = help (this screen)
          -a = also add autoconf (needed for maintainer mode)
          -r = minimal setup to build recipes only

"; exit 0 ;;
	*) echo "!! WARNING: ignoring unkown parameter $1"; shift ;;
    esac
done

: ${SRC:=/Volumes/My\ Shared\ Files}
if [ ! -e "$SRC" ]; then
    echo "ERROR: cannot find SRC: '$SRC' - typically, that is the automounted source volume"
    exit 1
fi

ARCH=`uname -m`
echo "============================================="
echo "  Setting up environment for $ARCH builds"
echo ''

OLDWD="`pwd`"
cd "$SRC"

echo Testing sudo
sudo id

#if [ ! -e /etc/sudoers.d/10admins ]; then
#    echo "Setting up paswordless sudo"
#    sudo bash -c "echo '%admin ALL = (ALL) NOPASSWD: ALL' > /etc/sudoers.d/10admins"
#fi

echo Enforce the use of CLT
sudo xcode-select -s /Library/Developer/CommandLineTools

echo Copy CMake
if [ -e /Applications/CMake.app ]; then
    echo ' - already present, skipping'
else
    if [ ! -e "$SRC/CMake.app" ]; then
	cmake_ver=3.31.9
	echo " - no cmake, downloading CMake ${cmake_ver}"
	curl -fL https://github.com/Kitware/CMake/releases/download/v${cmake_ver}/cmake-${cmake_ver}-macos-universal.tar.gz | tar xz --strip 1 -C "$SRC"
    fi
    if [ ! -e "$SRC/CMake.app" ]; then
	echo "ERROR: CMake.app not found - download it from https://cmake.org/ and copy CMake.app in '$SRC'"
	exit 1
    fi
    rsync -a "$SRC/CMake.app/" /Applications/CMake.app/
fi

echo Extract GFortran
if [ -e /opt/gfortran/bin/gfortran ]; then
    echo ' - already present, skipping'
else
    GFXZ=gfortran-14.2-darwin20-r2.tar.xz
    if [ ! -e $GFXZ ]; then
	echo "ERROR: missing $GFXZ -- downloading from https://github.com/R-macos/gcc-14-branch/releases"
	curl -fL -o $GFXZ https://github.com/R-macos/gcc-14-branch/releases/download/gcc-14.2-darwin-r2.1/gfortran-14.2-darwin20-r2-universal.tar.xz
    fi
    sudo mkdir -p /opt/gfortran
    sudo chown -R $USER /opt/gfortran
    tar fxj $GFXZ -C /
fi
/opt/gfortran/bin/gfortran --version | head -n1

echo Install XQuartz
if [ -e /opt/X11/lib/pkgconfig/xt.pc ]; then
    echo ' - already present'
else
    if [ ! -e xquartz-2.8.5.tar.xz ]; then
	echo "   xquartz-2.8.5.tar.xz not found, downloading"
	curl -fLO https://mac.r-project.org/xquartz-2.8.5.tar.xz
    fi
    sudo tar fxj xquartz-2.8.5.tar.xz -C /
    sudo chown -R $USER:admin /opt/X11
fi
if [ ! -e /usr/X11/lib/pkgconfig/xt.pc ]; then
    echo ' - setting X11 to /opt/X11'
    [[ -x /usr/libexec/x11-select ]] && sudo /usr/libexec/x11-select /opt/X11
fi

if [ ! -e /opt/R/$ARCH ]; then
    sudo mkdir -p /opt/R/$ARCH
    sudo chown -R $USER /opt/R/$ARCH
fi

if [ -n "$RECIPES" ]; then
    echo ''
    echo "Requested recipes bootstrap, done. You are ready to build recipes."
    echo "Re-start this script after building recipes to continue."
    echo ''
    cd "$OLDWD"
    exit 0
fi

echo Install recipies binaries
if [ -e /opt/R/$ARCH/lib/liblzma.a ]; then
    echo ' - already present, skipping'
else
    if [ ! -e dist-darwin20-$ARCH/sys-stubs-*.tar.xz ]; then
	echo " - cached content not present, creating cache from mac.r-project.org/bin"
	tars=`curl -fL https://mac.R-project.org/bin/darwin20/$ARCH/.bootstrap`
	if [ -z "$tars" ]; then
	    echo "ERROR: cannot get bootstrap list from https://mac.R-project.org/bin/darwin20/$ARCH/.bootstrap" >&2
	    exit 1
	fi
	mkdir -p dist-darwin20-$ARCH
	for i in $tars; do
	    echo Download `basename $i`
	    ( cd dist-darwin20-$ARCH && curl -fLO $i )
	done
    fi
    if [ ! -e dist-darwin20-$ARCH/sys-stubs-*.tar.xz ]; then
	echo "ERROR: binary recipes are incomplete. Create dist-darwin20-$ARCH and use"
	echo "       install.libs(c('r-base-dev','readline5'), action='download') from https://mac.r-project.org/bin/"
	exit 1
    fi
    for i in `ls dist-darwin20-$ARCH/|grep 'tar.xz$'`; do
	echo Installing `echo $i|sed s:-darwin.*::` ...
	tar fxj dist-darwin20-$ARCH/$i -C /
    done
fi

if [ -n "$AUTOC" -a ! -e /opt/R/$ARCH/bin/autoconf ]; then
    echo "Installing automake + autoconf"
    ## NOTE: this is a bit of a hack where we rely on the fact that we know the exact dependencies
    urls=$(curl -fsS https://mac.r-project.org/bin/darwin20/$ARCH/PACKAGES | sed -nE 's/^Binary: (autoconf|automake|m4)(-.*tar[.]xz).*$/\1\2/gp')
    if [ -z "$urls" ]; then echo "ERROR: cannot get index of darwin20/$ARCH" >&2; exit 1; fi
    for i in $urls; do
	echo Download $i
	## we will cache the binaries so next time we don't have to land here
	( cd dist-darwin20-$ARCH && curl -fLO https://mac.r-project.org/bin/darwin20/$ARCH/$i )
	tar fxj dist-darwin20-$ARCH/$i -C /
    done
fi

if [ ! -e /opt/R/$ARCH/bin/svn ]; then
    echo Install subversion
    if [ ! -e "$SRC/subversion-1.14.2-darwin.20-$ARCH.tar.xz" ]; then
	curl -fLO https://mac.r-project.org/bin/darwin20/$ARCH/subversion-1.14.2-darwin.20-$ARCH.tar.xz
    fi
    tar fxj "$SRC/subversion-1.14.2-darwin.20-$ARCH.tar.xz" -C /
fi

if [ ! -e opt/R/${ARCH}/lib/libiconv.a ]; then
    if [ -e libiconv-1.11-${ARCH}.tar.gz ]; then
	echo Install static iconv
	tar fxz libiconv-1.11-${ARCH}.tar.gz -C /
    else
	echo NOTE: libiconv-1.11-${ARCH}.tar.gz is not present, will use system iconv instead.
	echo       System iconv is not reliable depending on the macOS version so if you want stable iconv
	echo       to replicate CRAN build, fetch https://mac.r-project.org/libiconv-1.11-${ARCH}.tar.gz
    fi
fi

if [ ! -e /opt/R/$ARCH/lib/tkConfig.sh ]; then
    echo Install Tcl/Tk
    if [ ! -e "tcltk-$ARCH.pkg" ]; then
	TCLVER=8.6.13
	echo " - tcltk-$ARCH.pkg missing, downloading Tcl/Tk $TCLVER installers from https://mac.r-project.org/"
	curl -fL -o tcltk-$ARCH.pkg https://mac.r-project.org/tcltk-$TCLVER-$ARCH.pkg
    fi
    sudo installer -pkg "tcltk-$ARCH.pkg" -target /
    ## have to make sure root is not the owner so recipies won't fail to unpack
    sudo chown -R $USER /opt/R/$ARCH
fi

if [ -n "$FORCETEX" -o ! -e /opt/TinyTeX ]; then
    echo Install TinyTeX
    if [ ! -e TinyTeX.tgz ]; then
	echo " - TinyTeX.tgz is missing, downloading"
	curl -fLO https://github.com/rstudio/tinytex-releases/releases/download/daily/TinyTeX.tgz
    fi
    sudo mkdir /opt/TinyTeX
    sudo chown $USER:admin /opt/TinyTeX
    tar fxz TinyTeX.tgz -C /opt/
fi

if [ ! -e /opt/R/$ARCH/bin/pdflatex ]; then
    echo Activate TinyTeX
    cd /opt/TinyTeX/bin/universal-darwin/
    ./tlmgr option sys_bin /opt/R/$ARCH/bin
    ./tlmgr postaction install script xetex
    ./tlmgr path add
    echo Update tlmgr
    ./tlmgr update --self
    echo Install texinfo
    ## needed for PDF manuals
    ./tlmgr install texinfo
    cd "$SRC"
fi

## this is not strictly needed unless you want to edit files ;)
if [ ! -e /opt/R/$ARCH/bin/emacs ]; then
    echo Install emacs
    curl -fL https://mac.r-project.org/bin/darwin20/$ARCH/$(curl -sL https://mac.r-project.org/bin/darwin20/$ARCH/PACKAGES | sed -ne 's/^Binary: emacs-/emacs-/p') | tar xz - -C /
fi

if [ ! -e /Library/Java/JavaVirtualMachines/jdk* ]; then
    echo Install Java
    : ${JAVATAR=OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.8_9.tar.gz}
    if [ ! -e "$JAVATAR" ]; then
	curl -fL -o "$JAVATAR" https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.8%2B9/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.8_9.tar.gz
    fi
    if [ ! -e "$JAVATAR" ]; then
	echo "ERROR: missing Java $JAVATAR"
	exit 1
    fi
    sudo tar fxz "$JAVATAR" -C /Library/Java/JavaVirtualMachines/
fi

## not needed for R except for knitr-based help
if [ ! -e /opt/R/$ARCH/bin/pandoc ]; then
    echo Install pandoc
    if [ ! -e pandoc ]; then
	echo " - downloading pandoc"
	curl -fL https://mac.r-project.org/pandoc.xz | /opt/R/$ARCH/bin/xz -dc > pandoc
	chmod a+rx pandoc
	echo " - verify signature"
	codesign -v pandoc
    fi
    cp -p pandoc /opt/R/$ARCH/bin/
fi

echo Done.
cd "$OLDWD"
