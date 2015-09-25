# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+

import os
from ftsdk import Command, SUCCESS, ERROR_UNEXPECTED_STATE, ERROR_MISSING_TOOLS, ERROR_NOTFOUND,\
    MissingAttributeException
import tempfile
import subprocess
from abc import ABCMeta
import shutil
import re
from ftsdk.osutil import mkdirs, SearchPathAgent, SearchPath
from ftsdk.templates import JinjaTemplates
import glob

# +----------------------------------------------------------------------------------------------------------+

class XCRunCommand(Command):
    '''
    Common baseclass for commands that use 'xcrun' to select and use build tools.
    '''

    __metaclass__ = ABCMeta

    def setup(self, script, previousCommand):
        self._inheritAttribute("LOCAL_REPOSITORY", script)
        self._inheritAttribute("ARTIFACTS_DIRECTORY", script)
        self._inheritAttribute("ABS_ARTIFACTS_DIRECTORY", script)
        self._inheritAttribute("SDKS", script)
        self._inheritAttribute("target", script)

        if not os.path.isdir(self.ABS_ARTIFACTS_DIRECTORY):
            script.ENVIRONMENT.error("\033[31mNo build directory (expected build output at {})\033[0m".format(self.ABS_ARTIFACTS_DIRECTORY))
            return ERROR_UNEXPECTED_STATE

        if SUCCESS != script.ENVIRONMENT.checkTool('xcrun', '''
            \033[1mxcrun\033[0m\033[31m is required\033[0m

            get it:
                xcode-select --install

            '''):
            return ERROR_MISSING_TOOLS

        return SUCCESS

# +----------------------------------------------------------------------------------------------------------+

class MergeArchives(XCRunCommand):
    '''
    Merges the object files from the SDK and Core archives into a single archive.
    '''

    def run(self, script, previousCommand):
        self._inheritAttribute("PACKAGENAME", script)
        sdkArchives = {}
        coreArchives = {}
        project = self.PACKAGENAME

        for sdk in self.SDKS:
            targetPath = self._makeTargetPath(project, self.target, sdk)
            if os.path.isdir(targetPath):
                for architectureName in os.listdir(targetPath):
                    sdkArchivePath = os.path.join(targetPath, architectureName, "lib{}.a".format(project))
                    if os.path.isfile(sdkArchivePath):
                        coreArchivePath = os.path.join(self._makeTargetPath("Core", self.target, sdk), architectureName, "libCore.a")
                        if not os.path.isfile(coreArchivePath):
                            script.ENVIRONMENT.error("No core library found for {}".format(architectureName))
                            return ERROR_UNEXPECTED_STATE
                        script.ENVIRONMENT.debug("Found sdkArchives {} and {}".format(sdkArchivePath, coreArchivePath))
                        sdkArchives[sdkArchivePath] = architectureName
                        coreArchives[coreArchivePath] = architectureName


        if len(sdkArchives) == 0:
            script.ENVIRONMENT.error("No built sdkArchives found.")
            return ERROR_UNEXPECTED_STATE

        self._inheritAttribute("TMPBUILDDIR", script)

        expandedArchives = {}
        self._expandAll(sdkArchives, expandedArchives)
        self._expandAll(coreArchives, expandedArchives)

        mergedArchives = {}
        for expandedArchive, archiveArch in expandedArchives.iteritems():
            mergedArchive = os.path.join(self.TMPBUILDDIR, "lib", archiveArch, "lib{}.a".format(self.PACKAGENAME))
            mkdirs(os.path.dirname(mergedArchive))
            objectFiles = glob.glob("{}/*.o".format(expandedArchive))
            if len(objectFiles) == 0:
                script.ENVIRONMENT.error("No object files found under {}?".format(expandedArchive))
                return ERROR_UNEXPECTED_STATE
            subprocess.check_call("xcrun -sdk iphoneos ar rcs {} {}".format(mergedArchive, " ".join(objectFiles)), cwd=expandedArchive, shell=True)
            mergedArchives[mergedArchive] = archiveArch

        setattr(self, "ARCHIVES", mergedArchives)
        return SUCCESS

    # +--------------------------------------------------------------------------------------------------+
    # | PRIVATE
    # +--------------------------------------------------------------------------------------------------+
    def _expandAll(self, archives, outPaths):
        for archivePath, archiveArch in archives.iteritems():
            copiedPath = os.path.join(self.TMPBUILDDIR, "obj", archiveArch, "unmerged-{}".format(os.path.basename(archivePath)))
            mkdirs(os.path.dirname(copiedPath))
            shutil.copyfile(archivePath, copiedPath)
            outPaths[os.path.dirname(copiedPath)] = archiveArch
            subprocess.check_call('xcrun -sdk iphoneos ar x {}'.format(copiedPath), cwd=os.path.dirname(copiedPath), shell=True)

    def _makeTargetPath(self, project, target, sdk):
        projectdirname = "{}.build".format(project)
        targetdirname = "{}-{}".format(target, sdk)
        return os.path.join(self.ABS_ARTIFACTS_DIRECTORY, projectdirname, targetdirname, projectdirname, "Objects-normal")

# +----------------------------------------------------------------------------------------------------------+

class StripArchives(XCRunCommand):
    '''
    Runs the appropriate strip command on each archive in ARCHIVES
    '''

    def run(self, script, previousCommand):
        self._inheritAttribute("ARCHIVES", script, dict)
        self._inheritAttribute("TMPBUILDDIR", script)
        self._inheritAttribute("PACKAGENAME", script)

        unstrippedArchives = self.ARCHIVES.copy()
        for archivePath, archiveArch in unstrippedArchives.iteritems():
            strippedPath = os.path.join(self.TMPBUILDDIR, "stripped", archiveArch, "lib{}.a".format(self.PACKAGENAME))
            mkdirs(os.path.dirname(strippedPath))
            script.ENVIRONMENT.info("Stripping debug symbols from {}".format(archivePath))
            subprocess.check_call('xcrun -sdk iphoneos strip -S -x -o {} {}'.format(strippedPath, archivePath), shell=True)
            self.ARCHIVES.pop(archivePath)
            self.ARCHIVES[strippedPath] = archiveArch
        return SUCCESS

# +----------------------------------------------------------------------------------------------------------+

class MakeFatArchive(XCRunCommand):
    '''
    Combines archives provided in ARCHIVES into a single fat binary.
    '''

    def run(self, script, previousCommand):
        self._inheritAttribute("ARCHIVES", script, type(dict))
        self._inheritAttribute("TMPBUILDDIR", script)
        self._inheritAttribute("FRAMEWORK_CURRENT_VERSION_ARCHIVE", script)
        self._inheritAttribute("PACKAGENAME", script)

        lipocreate = ["xcrun -sdk iphoneos lipo", "-create"]
        for archivePath, archiveArch in self.ARCHIVES.iteritems():
            lipocreate.append("-arch {} {}".format(archiveArch, archivePath))

        lipocreate.append("-o")
        fatArchive = os.path.join(self.TMPBUILDDIR, "lib{}.a".format(self.PACKAGENAME))
        lipocreate.append(fatArchive)

        subprocess.check_call(' '.join(lipocreate), shell=True)

        subprocess.call("xcrun -sdk iphoneos lipo -info {}".format(fatArchive), shell=True)

        shutil.copy(fatArchive, self.FRAMEWORK_CURRENT_VERSION_ARCHIVE)

        return SUCCESS

# +----------------------------------------------------------------------------------------------------------+

class CopyPublicHeaders(XCRunCommand, SearchPathAgent):
    '''
    Finds and copies the publishes headers of the SDK to the framework.
    '''

    FIFTYTHREE_HEADER_NAME = "FiftyThreeSdk.h"

    def onVisitFile(self, parentPath, rootPath, containingFolderName, filename, fqFilename):
        if filename == self.FIFTYTHREE_HEADER_NAME:
            setattr(self, "HEADERFOLDER", parentPath)
            setattr(self, "SDKHEADER", fqFilename)
            return SearchPathAgent.DONE
        return SearchPathAgent.KEEP_GOING

    def setup(self, script, previousCommand):
        setattr(self, "HEADERINCLUDEPATTERN", re.compile("^\\s*#(?:include|import)\\s*[<\"](\\S+)[\">]"))
        return super(CopyPublicHeaders, self).setup(script, previousCommand)

    def run(self, script, previousCommand):
        self._inheritAttribute("FRAMEWORK_CURRENT_VERSION_HEADERS", script)

        headerSearchPath = SearchPath(script.ENVIRONMENT, self.LOCAL_REPOSITORY)
        headerSearchPath.scanDirs(os.path.join(self.LOCAL_REPOSITORY, "FiftyThreeSdk"), self)
        if not hasattr(self, "SDKHEADER"):
            script.ENVIRONMENT.error("Failed to find the master SDK include {}".format(self.FIFTYTHREE_HEADER_NAME))
            return ERROR_NOTFOUND

        shutil.copy(self.SDKHEADER, self.FRAMEWORK_CURRENT_VERSION_HEADERS)

        with open(self.SDKHEADER, "r") as sdkHeader:
            script.ENVIRONMENT.error("Looking for public headers by parsing {}".format(self.SDKHEADER))
            publicHeaders = self._find_public_headers(self.HEADERFOLDER, sdkHeader)

        for publicHeader in publicHeaders:
            shutil.copy(publicHeader, self.FRAMEWORK_CURRENT_VERSION_HEADERS)

        return SUCCESS

    # +--------------------------------------------------------------------------------------------------+
    # | PRIVATE
    # +--------------------------------------------------------------------------------------------------+

    def _find_public_headers(self, basepath, src_lines):
        includes = []
        for line in src_lines:
            match = self.HEADERINCLUDEPATTERN.match(line)
            if match:
                includes.append(os.path.join(basepath, match.group(1)))

        return includes

# +----------------------------------------------------------------------------------------------------------+

class HeaderDocGen(Command):
    '''
    Generates HTML documentation by reading headerdoc in SDK header files.
    '''

    def tool_exist(self, name):
        try:
            devnull = open(os.devnull)
            subprocess.Popen([name], stdout=devnull, stderr=devnull).communicate()
        except OSError as e:
            if e.errno == os.errno.ENOENT:
                return False
        return True

    def run(self, script, previousCommand):
        self._inheritAttribute("LOCAL_REPOSITORY", script)
        self._inheritAttribute("FRAMEWORK_CURRENT_VERSION_HEADERS", script)
        self._inheritAttribute("FRAMEWORK_CURRENT_VERSION_DOCS", script)

        if self.tool_exist('headerdoc2html') == True:
            original_working_dir = os.getcwd()

            headerdoc_process_dir = os.path.join(self.LOCAL_REPOSITORY, 'HeaderDoc')
            os.chdir(headerdoc_process_dir)

            current_working_dir = os.getcwd()

            currentVersionHeaderPath = os.path.relpath(self.FRAMEWORK_CURRENT_VERSION_HEADERS, current_working_dir)
            currentVersionDocsPath = os.path.relpath(self.FRAMEWORK_CURRENT_VERSION_DOCS, current_working_dir)

            headerdoc2htmlScript = "headerdoc2html -o {} {}".format(currentVersionDocsPath, currentVersionHeaderPath)

            subprocess.check_call(headerdoc2htmlScript, shell=True)
            subprocess.check_call("gatherheaderdoc {}".format(currentVersionDocsPath), shell=True)

            shutil.copytree(os.path.join(headerdoc_process_dir, "Resources"), os.path.join(currentVersionDocsPath, "Resources"))

            os.chdir(original_working_dir)

            return SUCCESS

        else:
            script.ENVIRONMENT.error("Command headerdoc2html does not exist")
            return ERROR_NOTFOUND

# +----------------------------------------------------------------------------------------------------------+

class MakeFrameworkPlist(XCRunCommand):
    '''
    Instantiates a plist template and populates with framework attributes
    '''

    def run(self, script, previousCommand):
        self._inheritAttribute("FRAMEWORK_CURRENT_VERSION_RESOURCES", script)
        plistPath = os.path.join(self.FRAMEWORK_CURRENT_VERSION_RESOURCES, "Info.plist")
        JinjaTemplates.getTemplate(script, "Info.plist.jinja").renderTo(plistPath)

        if not os.path.isfile(plistPath):
            script.ENVIRONMENT.error("Failed to write Info.plist.jinja to {}".format(plistPath))
            return ERROR_UNEXPECTED_STATE
        else:
            script.ENVIRONMENT.info("Created {}".format(plistPath))

        return SUCCESS

# +----------------------------------------------------------------------------------------------------------+

class CopySampleApp(Command):
    '''
    Copy over the SDK sample app into the SDK bundle.
    '''
    def run(self, script, previousCommand):
        self._inheritAttribute("TMPPACKAGEDIR", script)
        self._inheritAttribute("LOCAL_REPOSITORY", script)

        script.ENVIRONMENT.info('Copying Sample App contents to %s' % self.TMPPACKAGEDIR)

        sample_app_dir = os.path.join(self.LOCAL_REPOSITORY, 'FiftyThreeSimpleSampleApp')
        test_app_src_dir = os.path.join(self.LOCAL_REPOSITORY, 'FiftyThreeSdkTestApp', 'TestApp', 'TestApp')

        target_dir = os.path.join(self.TMPPACKAGEDIR, 'FiftyThreeSimpleSampleApp' )
        target_src_dir = os.path.join(target_dir, 'FiftyThreeSimpleSampleApp' )
        target_shaders_dir = os.path.join(target_src_dir, 'Shaders' )

        shutil.copytree(sample_app_dir, target_dir, symlinks=True)
        mkdirs(target_shaders_dir)

        for source_file in glob.glob(os.path.join(test_app_src_dir, "*.[hm]")):
            shutil.copy(source_file, target_src_dir)

        for shader_file in glob.glob(os.path.join(test_app_src_dir, "Shaders", "*.*")):
            shutil.copy(shader_file, target_shaders_dir)

        return super(CopySampleApp, self).run(script, previousCommand)

# +----------------------------------------------------------------------------------------------------------+

class AddReadmeToSdk(Command):
    '''
    Publishes the README.md template to TMPPACKAGEDIR/README.md
    '''
    def run(self, script, previousCommand):
        self._inheritAttribute("TMPPACKAGEDIR", script)
        JinjaTemplates.getTemplate(script, "README.md.jinja").renderTo(os.path.join(self.TMPPACKAGEDIR,"README.md"))
        return SUCCESS

# +----------------------------------------------------------------------------------------------------------+

class CopyStaticDocs(Command):
    '''
    Copy everything under the docs folder to the sdk package.
    '''

    def run(self, script, previousCommand):
        self._inheritAttribute("LOCAL_REPOSITORY", script)
        self._inheritAttribute("TMPPACKAGEDIR", script)
        docsdir = os.path.join(self.LOCAL_REPOSITORY, "docs")
        for filename in os.listdir(docsdir):
            fullpath = os.path.join(docsdir, filename)
            if os.path.isdir(fullpath):
                shutil.copytree(fullpath, os.path.join(self.TMPPACKAGEDIR, filename))
            else:
                shutil.copy(fullpath, self.TMPPACKAGEDIR)
        return SUCCESS

# +----------------------------------------------------------------------------------------------------------+

class MakeStaticFramework(Command):
    '''
    Packages up binaries and creates the required folder structure to allow other build steps to populate a
    static framework. The root of this framework will be defined in the setup phase as TMPPACKAGEDIR. This
    directory will be deleted in the teardown phase unless --messy is specified.
    '''

    def setup(self, script, previousCommand):
        result = super(MakeStaticFramework, self).setup(script, previousCommand)
        if SUCCESS != result:
            return result

        self._inheritAttribute("LOCAL_REPOSITORY", script)
        self._inheritAttribute("ARTIFACTS_DIRECTORY", script)
        self._inheritAttribute("SDK_VERSION_STRING", script)

        setattr(self, "ABS_ARTIFACTS_DIRECTORY", os.path.join(self.LOCAL_REPOSITORY, self.ARTIFACTS_DIRECTORY))
        try:
            self._inheritAttribute("TMPBUILDDIR", script)
        except MissingAttributeException:
            setattr(self, "TMPBUILDDIR", tempfile.mkdtemp(dir=self.ABS_ARTIFACTS_DIRECTORY))

        setattr(self, "TMPPACKAGEDIR", os.path.join(self.TMPBUILDDIR, "fiftythree-public-sdk-{}".format(self.SDK_VERSION_STRING)))

        self._inheritAttribute("ABS_ARTIFACTS_DIRECTORY", script)
        self._inheritAttribute("TMPBUILDDIR", script)
        self._inheritAttribute("PACKAGENAME", script)
        setattr(self, "FRAMEWORK_VERSION", "A")

        setattr(self, "FRAMEWORK_BUNDLE", os.path.join(self.TMPPACKAGEDIR, "{}.framework".format(self.PACKAGENAME)))

        targetDir = os.path.join(self.ABS_ARTIFACTS_DIRECTORY, "framework")
        if os.path.exists(targetDir):
            script.ENVIRONMENT.info("Cleaning existing framework under {}".format(targetDir))
            shutil.rmtree(targetDir)

        versionedDir = os.path.join(self.FRAMEWORK_BUNDLE, "Versions", self.FRAMEWORK_VERSION)
        versionedResources = os.path.join(versionedDir, "Resources")
        versionedHeaders   = os.path.join(versionedDir, "Headers")
        versionedDocs      = os.path.join(versionedDir, "Documentation")

        mkdirs(versionedDir)
        mkdirs(versionedResources)
        mkdirs(versionedHeaders)
        mkdirs(versionedDocs)

        setattr(self, "FRAMEWORK_CURRENT_VERSION_HEADERS", versionedHeaders)
        setattr(self, "FRAMEWORK_CURRENT_VERSION_RESOURCES", versionedResources)
        setattr(self, "FRAMEWORK_CURRENT_VERSION_DOCS", versionedDocs)
        setattr(self, "FRAMEWORK_CURRENT_VERSION_ARCHIVE", os.path.join(versionedDir, self.PACKAGENAME))

        currentVersion = os.path.join(self.FRAMEWORK_BUNDLE, "Versions", "Current")
        os.symlink(versionedDir, currentVersion)
        os.symlink(versionedResources, os.path.join(self.FRAMEWORK_BUNDLE, "Resources"))
        os.symlink(versionedDocs, os.path.join(self.FRAMEWORK_BUNDLE, "Documentation"))
        os.symlink(versionedHeaders, os.path.join(self.FRAMEWORK_BUNDLE, "Headers"))

        return SUCCESS

    def run(self, script, previousCommand):
        if not os.path.isfile(self.FRAMEWORK_CURRENT_VERSION_ARCHIVE):
            script.ENVIRONMENT.error("No SDK fat archive found at {}".format(self.FRAMEWORK_CURRENT_VERSION_ARCHIVE))
            return ERROR_UNEXPECTED_STATE

        os.symlink(self.FRAMEWORK_CURRENT_VERSION_ARCHIVE, os.path.join(self.FRAMEWORK_BUNDLE, self.PACKAGENAME))
        return super(MakeStaticFramework, self).run(script, previousCommand)

    def teardown(self, script, previousCommand):
        self._inheritAttribute("messy", script)
        if not self.messy:
            shutil.rmtree(self.TMPBUILDDIR)
            delattr(self, "TMPBUILDDIR")
        return super(MakeStaticFramework, self).teardown(script, previousCommand)
