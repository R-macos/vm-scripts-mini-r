#!/bin/bash

## sample script to build R

set -e

SVOL='/Volumes/My Shared Files'
if [ ! -e "$SVOL" ]; then
    echo "** ERROR: Cannot find shared volume - make sure you used --vol /Volumes/VM/shared,automount or similar."
    exit 1
fi

## setup environment for R builds
## append -a to setup.sh if you need autoconf for mainaitner mode
( cd '/Volumes/My Shared Files' && ./setup.sh )

ARCH=$(uname -m)
export PATH=/opt/R/$ARCH/bin:/opt/gfortran/bin:$PATH

## decide what and where to build
## anything other than '/Volumes/My Shared\Files' is ephemeral
## so you can either build inside the VM or on the mounted volume

## let's assume that the use has R source in the "R" directoru of
## the mounted volume - if not, create R-devel there
cd '/Volumes/My Shared Files'
if [ ! -e R ]; then
    svn co https://svn.r-project.org/R/trunk R-devel
    ( cd R-devel && tools/rsync-recommended )
    ln -s R-devel R
fi

## run the build in a separate directory
bdir=R-build-$(date +%s)
mkdir -p $bdir

( cd $bdir &&
  ../R/configure --enable-R-shlib LDFLAGS=-L/opt/R/$ARCH/lib CPPFLAGS=-I/opt/R/$ARCH/include && \
  make -j12 dist && \
  cp -p R*.tar.gz ../ )
