# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
from ftsdk import Command, SUCCESS
import shutil
import os

class PublishStaticFrameworkToBuildArtifacts(Command):
    '''
    Simple copy of framework into a file archive in the local build artifacts.
    '''
    
    def run(self, script, previousCommand):
        self._inheritAttributeOrDefault("ARCHIVE_FORMAT", script, "bztar")
        self._inheritAttribute("PACKAGENAME", script)
        self._inheritAttribute("ABS_ARTIFACTS_DIRECTORY", script)
        self._inheritAttribute("TMPPACKAGEDIR", script)
        self._inheritAttribute("SDK_VERSION_STRING", script)
        basename = os.path.join(self.ABS_ARTIFACTS_DIRECTORY, "fiftythree-public-sdk-{}".format(self.SDK_VERSION_STRING))
        shutil.make_archive(basename, 
                            self.ARCHIVE_FORMAT, 
                            os.path.abspath(os.path.join(self.TMPPACKAGEDIR, os.pardir)), 
                            os.path.basename(self.TMPPACKAGEDIR), 
                            verbose=script.ENVIRONMENT.willPrintVerbose(), 
                            logger=script.ENVIRONMENT)
        return SUCCESS
