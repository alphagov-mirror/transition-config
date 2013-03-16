#!/bin/sh

set -e -x

ruby -v

#
#  depends upon mustache
#
bundle install --deployment

#
#  bootstrap makefiles ..
#
make data/sites
make makefiles

#
#  test, validate and build project ..
#
make ci

exit $?
