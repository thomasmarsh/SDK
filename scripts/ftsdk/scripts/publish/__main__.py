# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
from ftsdk.scripts import Script

from ftsdk.builders import XCToolUseExistingArtifacts
import sys
from ftsdk.packagers import MergeArchives, MakeFatArchive, CopyPublicHeaders, MakeFrameworkPlist,\
    MakeStaticFramework, StripArchives, CopySampleApp, AddReadmeToSdk, CopyStaticDocs
from ftsdk.publishers import PublishStaticFrameworkToBuildArtifacts
from ftsdk.validators import CheckForArchitectures

if __name__ == '__main__':
    cibuildScript = Script("Default publishing command.", 
                   XCToolUseExistingArtifacts(),
                   CheckForArchitectures(),
                   MergeArchives(),
                   StripArchives(),
                   MakeFatArchive(),
                   CopyPublicHeaders(),
                   MakeFrameworkPlist(),
                   MakeStaticFramework(),
                   CopySampleApp(),
                   AddReadmeToSdk(),
                   CopyStaticDocs(),
                   PublishStaticFrameworkToBuildArtifacts())

    cibuildScript.ENVIRONMENT.info("Package existing artifacts from a previous build.")
    sys.exit(cibuildScript.run())
