#!/usr/bin/env bash

# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# |   local build script: glue to simulate a command issued as part of an automated build.
# |
# +----------------------------------------------------------------------------------------------------------+


if [ -z ${REPOSITORY+x} ]; then
    REPOSITORY=$(git rev-parse --show-toplevel)
fi

# sudo easy_install jinja2
PYTHONPATH=$PYTHONPATH:$REPOSITORY/scripts python -m ftsdk.scripts.build -env ShipIo --target Production

# tests will be run by CI environment. Use xcode to run tests locally.

PYTHONPATH=$PYTHONPATH:$REPOSITORY/scripts python -m ftsdk.scripts.publish -env ShipIo --target Production
