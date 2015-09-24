# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
import os
import subprocess
from ftsdk import Command, ERROR_MISSING_TOOLS, SUCCESS
from abc import ABCMeta, abstractmethod
from ftsdk.osutil import mkdirs
import re
from ftsdk.templates import JinjaTemplates
import shutil

class XCToolCommand(Command):
    '''
    local build script: Script to run a local https://github.com/facebook/xctool build of the SDK to
    reproduce CI builds on a developer machine. The state of the local repository after this build completes
    should be suitable for a packager to use.
    '''
    
    __metaclass__ = ABCMeta
    
    @abstractmethod
    def __init__(self, scheme, command, sdk=None, buildconfig=None):
        super(XCToolCommand, self).__init__()
        self._scheme = scheme
        self._command = command
        self.SDK = sdk
        self._buildconfig = buildconfig


    @staticmethod
    def is_master_branch(branchname):  return bool(re.match('^(origin/)?master',  branchname))
    @staticmethod
    def is_develop_branch(branchname):  return bool(re.match('^(origin/)?develop',  branchname))
    @staticmethod
    def is_preview_branch(branchname):  return bool(re.match('^(origin/)?preview\\/.+',  branchname))
    @staticmethod
    def is_release_branch(branchname):  return bool(re.match('^(origin/)?release\\/.+',  branchname))
    @staticmethod
    def is_hotfix_branch(branchname):   return bool(re.match('^(origin/)?hotfix\\/.+',   branchname))
    @staticmethod
    def is_retail_branch(branchname):   return bool(re.match('^(origin/)?build\\/appleRetail\/.+', branchname))

    def _getXCToolCommand(self, script, workspace, artifactsDir):
        self._inheritAttributeOrDefault("JENKINS_BUILD", script, False)
        self._inheritAttributeOrDefault("ONLY_ACTIVE_ARCH", script, "NO")
        self._inheritAttributeOrDefault("DEBUG_INFORMATION_FORMAT", script, "dwarf-with-dsym")
        self._inheritAttribute("BUILD_BRANCH_NAME", script)
        self._inheritAttribute('SDK_VERSION_STRING', script)
        
        required = ['xctool',
                'ONLY_ACTIVE_ARCH={}'.format(self.ONLY_ACTIVE_ARCH),
                '-scheme "{}"'.format(self._scheme),
                self._command,
                '-workspace "{}"'.format(workspace),
                '-configuration "{}"'.format(self.target),
                'BUNDLE_VERSION_STRING={}'.format(self.SDK_VERSION_STRING),
                'BUILD_NAME={}'.format(self._scheme),
                'DEBUG_INFORMATION_FORMAT={}'.format(self.DEBUG_INFORMATION_FORMAT),
                'JENKINS_BUILD={}'.format(str(self.JENKINS_BUILD)),
                'BUILD_BRANCH_NAME={}'.format(self.BUILD_BRANCH_NAME),
                'MASTER_BRANCH_BUILD={}'.format(str(self.is_master_branch(self.BUILD_BRANCH_NAME))),
                'PREVIEW_BRANCH_BUILD={}'.format(str(self.is_preview_branch(self.BUILD_BRANCH_NAME))),
                'CONFIGURATION_BUILD_DIR="{}"'.format(artifactsDir),
                'OBJROOT="{}"'.format(artifactsDir),
                'SYMROOT="{}"'.format(artifactsDir),
                'DSTROOT="{}"'.format(artifactsDir),
        ]
        if self._buildconfig is not None:
            required += self._buildconfig
        if self.SDK is not None:
            required.append('-sdk {}'.format(self.SDK))
        return required
    
    def setup(self, script, previousCommand):
        setattr(self, "SDKS", ["iphoneos", "iphonesimulator"])
        self._inheritAttribute("ARTIFACTS_DIRECTORY", script)
        
        if SUCCESS != script.ENVIRONMENT.checkTool('xcode-select', '''
            \033[1mxcode\033[0m\033[31m is required\033[0m
            
            To get it download from https://developer.apple.com/
        
            '''):
            return ERROR_MISSING_TOOLS
        
        if SUCCESS != script.ENVIRONMENT.checkTool('xctool', '''
            \033[1mxctool\033[0m\033[31m is required\033[0m
            
            get it:
                brew install xctool
        
            '''):
            return ERROR_MISSING_TOOLS
        
        self._inheritAttribute("LOCAL_REPOSITORY", script)
        setattr(self, "ABS_ARTIFACTS_DIRECTORY", os.path.join(self.LOCAL_REPOSITORY, self.ARTIFACTS_DIRECTORY))
        return SUCCESS

    def run(self, script, previousCommand):
        self._inheritAttribute("target", script)
        self._inheritAttribute("ABS_ARTIFACTS_DIRECTORY", script)
        mkdirs(self.ARTIFACTS_DIRECTORY)
        
        setattr(self, "WORKSPACE", os.path.join(self.LOCAL_REPOSITORY, "FiftyThreeSdkTestApp", "FiftyThreeSdkTestApp.xcworkspace"))
        
        script.ENVIRONMENT.info("will build the {} target of the {} workspace into {}".format(self.target, self.WORKSPACE, self.ABS_ARTIFACTS_DIRECTORY))
        
        XCTOOL_COMMAND = self._getXCToolCommand(script, self.WORKSPACE, self.ABS_ARTIFACTS_DIRECTORY)
        
        # Build
        subprocess.check_call(' '.join(XCTOOL_COMMAND), shell=True)
        
        return SUCCESS

# +----------------------------------------------------------------------------------------------------------+ 

class Nuke(Command):
    '''
    rm -rf the build directory.
    '''
    
    def run(self, script, previousCommand):
        self._inheritAttribute("LOCAL_REPOSITORY", script)
        self._inheritAttribute("ARTIFACTS_DIRECTORY", script)
        setattr(self, "ABS_ARTIFACTS_DIRECTORY", os.path.join(self.LOCAL_REPOSITORY, self.ARTIFACTS_DIRECTORY))
        shutil.rmtree(self.ABS_ARTIFACTS_DIRECTORY)
        return SUCCESS
    
# +----------------------------------------------------------------------------------------------------------+

class XCToolBuild(XCToolCommand):
    '''
    Build the SDK
    '''
    def __init__(self):
        super(XCToolBuild, self).__init__("TestApp", "build", sdk="iphoneos")

# +----------------------------------------------------------------------------------------------------------+ 

class XCToolClean(XCToolCommand):
    '''
    Clean SDK artifacts
    '''
    def __init__(self):
        super(XCToolClean, self).__init__("TestApp", "clean")

# +----------------------------------------------------------------------------------------------------------+ 
    
class XCToolBuildTests(XCToolCommand):
    '''
    Build the SDK unit tests.
    '''

    def __init__(self):
        super(XCToolBuildTests, self).__init__("FiftyThreeSdkUnitTests", "build-tests", "iphonesimulator")

# +----------------------------------------------------------------------------------------------------------+ 

class XCToolCleanTests(XCToolCommand):
    '''
    Clean test artifacts
    '''
    def __init__(self):
        super(XCToolCleanTests, self).__init__("FiftyThreeSdkUnitTests", "clean",)

# +----------------------------------------------------------------------------------------------------------+ 

class XCToolUseExistingArtifacts(XCToolCommand):
    '''
    Build that does nothing. Use to reuse existing build artifacts in packaging commands.
    '''
    def __init__(self):
        super(XCToolUseExistingArtifacts, self).__init__("", "")
        
    def run(self, script, previousCommand):
        return SUCCESS

# +----------------------------------------------------------------------------------------------------------+ 

class VersionSdkSource(Command):
    '''
    Modify the build source to include build and SCM stamping. This command must be run before compilation to
    include the source information in the object files.
    '''

    def run(self, script, previousCommand):
        self._inheritAttribute("LOCAL_REPOSITORY", script)
        self._inheritAttribute("SDK_VERSION_STRING", script)
        version_match = re.match("(\d+)\.(\d+)\.(\d+)", self.SDK_VERSION_STRING)
        setattr(self, "FRAMEWORK_MAJOR_VERSION", version_match.group(1))
        setattr(self, "FRAMEWORK_MINOR_VERSION", version_match.group(2))
        setattr(self, "FRAMEWORK_PATCH_VERSION", version_match.group(3))
        
        setattr(self, "FTSDKVERSIONINFO_PATH", os.path.join(self.LOCAL_REPOSITORY, "FiftyThreeSdk", "FiftyThreeSdk", "FTSDKVersionInfo.m"))
        JinjaTemplates.getTemplate(script, "FTSDKVersionInfo.m.jinja").renderTo(self.FTSDKVERSIONINFO_PATH)
        return SUCCESS

    def teardown(self, script, previousCommand):
        self._inheritAttribute("messy", script)
        if not self.messy:
            subprocess.check_call('git checkout {}'.format(self.FTSDKVERSIONINFO_PATH), shell=True)
        return super(VersionSdkSource, self).teardown(script, previousCommand)


