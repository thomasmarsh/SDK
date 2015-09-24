# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
from ftsdk import Command, SUCCESS, ERROR_UNEXPECTED_STATE
import os

class CheckForArchitectures(Command):
    '''
    Gate to ensure we've build the expected binary artifacts before continuing.
    '''
    
    def run(self, script, previousCommand):
        setattr(self, "REQUIRED_ARCHITECTURES", ('x86_64', 'i386', 'arm64', 'armv7'))
        setattr(self, "REQUIRED_PACKAGES", ('Core', 'FiftyThreeSdk'))
        self._inheritAttribute("SDKS", script)
        self._inheritAttribute("target", script)
        self._inheritAttribute("ABS_ARTIFACTS_DIRECTORY", script)
        
        for packageName in self.REQUIRED_PACKAGES:
            unfoundArchitectures = set(self.REQUIRED_ARCHITECTURES)
            for sdk in self.SDKS:
                projectdirname = "{}.build".format(packageName)
                targetdirname = "{}-{}".format(self.target, sdk)
                objectPath = os.path.join(self.ABS_ARTIFACTS_DIRECTORY, projectdirname, targetdirname, projectdirname, "Objects-normal")
                for architectureName in os.listdir(objectPath):
                    unfoundArchitectures.remove(architectureName)
            
            if len(unfoundArchitectures) > 0:
                script.ENVIRONMENT.error("Missing {} architectures for {} package.".format(", ".join(unfoundArchitectures), packageName))
                return ERROR_UNEXPECTED_STATE

        return SUCCESS
