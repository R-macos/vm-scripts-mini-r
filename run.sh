#!/bin/bash

if [ "x$1" = x-h ]; then
    echo "
 Usage: $0 [-p | -h]

 Starts a VM and displays the ssh command to login.

 Options: -p = permanent (otherwise it will be ephemeral)

 MACOSVM env var can be set to point to macosvm executable,
 otherwise PATH and . are searched.

"
    exit 0
fi

eph='--ephemeral'
if [ "x$1" = x-p ]; then
    eph=''
    shift
fi

if [ -z "$MACOSVM" ]; then
    MACOSVM=$(which macosvm)
fi
if [ -z "$MACOSVM" -a -e macosvm ]; then
    MACOSVM=./macosvm
fi
if [ -z "$MACOSVM" ]; then
    echo "** ERROR: cannot find macosvm - put it on the PATH or put a symlink into this directory."
    exit 1
fi

$MACOSVM $eph --vol "$(pwd)/shared",automount --script ./launch.sh "$@" vm.json
