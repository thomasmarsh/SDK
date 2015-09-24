# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
from ftsdk.scripts import Script
from ftsdk.builders import XCToolBuildTests, XCToolClean, XCToolCleanTests,\
    XCToolBuild, VersionSdkSource
import sys

cibuildScript = Script("Compile and link", 
               XCToolClean(), 
               XCToolCleanTests(),
               VersionSdkSource(),
               XCToolBuild(), 
               XCToolBuildTests())

cibuildScript.ENVIRONMENT.info("Automated Release Build")
sys.exit(cibuildScript.run())

