#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Make sure mandatory directories exist.
mkdir -p /config/log

# make sure the user owns autopsy
# take-ownership /autopsy-$AUTOPSY_VERSION

# Take ownership of the output directory.
take-ownership --not-recursive /data

# vim:ft=sh:ts=4:sw=4:et:sts=4
