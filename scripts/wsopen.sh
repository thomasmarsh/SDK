#!/usr/bin/env bash

# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# |   wsopen script: convenience shortcut to open the designated iOS SDK workspace in xcode from any PWD
# | within the FiftyThreeSDK-iOS repository. Assumes the iOS open command for *.xcworkspace is mapped to the
# | correct XCode.app.
# |
# +----------------------------------------------------------------------------------------------------------+


LOCAL_WORKSPACE=$(git rev-parse --show-toplevel)/FiftyThreeSdkTestApp/FiftyThreeSdkTestApp.xcworkspace

echo -e "\033[1mOpening ${LOCAL_WORKSPACE} as the SDK workspace…\033[0m\n"

open ${LOCAL_WORKSPACE}
