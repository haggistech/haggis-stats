#!/bin/sh
#
# This is a trivial helper script for converting our collection of various
# Linux distribution's logos from PNG to ASCII art. Once converted the logos
# can be manually tweaked and inserted into the Stats script.
#

for logo in *.png; do
    echo "Logo: $logo"
    convert $logo jpg:- | jp2a --background=light --colors --height=20 -
done
