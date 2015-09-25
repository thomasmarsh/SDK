# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
from ftsdk import Command, SUCCESS, ERROR_UNEXPECTED_STATE
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
        basepath = os.path.join(self.ABS_ARTIFACTS_DIRECTORY, "{}.build".format(self.PACKAGENAME), "fiftythree-public-sdk-{}".format(self.SDK_VERSION_STRING))
        archiveName = shutil.make_archive(basepath, 
                            self.ARCHIVE_FORMAT, 
                            os.path.abspath(os.path.join(self.TMPPACKAGEDIR, os.pardir)), 
                            os.path.basename(self.TMPPACKAGEDIR), 
                            verbose=script.ENVIRONMENT.willPrintVerbose(), 
                            logger=script.ENVIRONMENT)

        if os.path.isfile(archiveName):
            script.ENVIRONMENT.debug("Created SDK bundle at {}".format(archiveName))
            return SUCCESS
        else:
            script.ENVIRONMENT.error("Expected SDK bundle at {}.[extension]".format(basepath))
            return ERROR_UNEXPECTED_STATE
