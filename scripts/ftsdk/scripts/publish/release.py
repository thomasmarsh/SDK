# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
from ftsdk.scripts import Script
from ftsdk.publishers import PublishStaticFrameworkToGithubRelease
import sys

if __name__ == '__main__':
    '''
    If the release does not exist create it as a pre-release and upload to it.
    If the release does exist but it is _not_ a pre-release treat it as immutable and refuse to upload.
    If the release does exist and it _is_ a pre-release then upload a new version that overwrites previous versions.
    If the release was updated and SDK_FINALIZE_RELEASE is True then update the release setting prerelease = False
    '''

    cibuildScript = Script("Upload artifact as a release", 
                   PublishStaticFrameworkToGithubRelease())

    cibuildScript.ENVIRONMENT.info("Release existing artifacts.")
    sys.exit(cibuildScript.run())

