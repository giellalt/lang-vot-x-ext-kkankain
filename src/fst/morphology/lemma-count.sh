#!/bin/bash

# For debugging, uncomment this command:
# set -x

srcdir=$1

lemmacount=$(fgrep ';' $srcdir/src/fst/morphology/ext-github_kristiank/data/giellatekno/morphology/stems/*.lexc | wc -l)

echo $lemmacount
