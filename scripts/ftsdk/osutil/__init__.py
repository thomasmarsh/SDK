# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
import os
import errno
import fnmatch
from abc import ABCMeta
import re

def mkdirs(path):
    '''
    Portable mkdir -p
    '''
    try:
        os.makedirs(path)
    except OSError as exc: # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise

# +----------------------------------------------------------------------------------------------------------+

class GitIgnoreParser(object):
    '''
    Collects all ignore rules from a .gitignore found in a provided path.
    '''
    
    LINECOMMENT_PATTERN = re.compile("^\s?\#")
    ONLYWHITESPACE_PATTERN = re.compile("^\s+$")
    
    def __init__(self):
        raise Exception("static only")
    
    @classmethod
    def parse(cls, basepath, ignoreRules=[]):
        ignorefile = os.path.join(basepath, ".gitignore")
        if os.path.isfile(ignorefile):
            with open(ignorefile) as gitignore:
                for line in gitignore:
                    if len(line) is 0 or cls.ONLYWHITESPACE_PATTERN.match(line):
                        continue
                    if cls.LINECOMMENT_PATTERN.match(line):
                        continue
                    ignoreRules.append(line.strip())
        return ignoreRules
    
# +----------------------------------------------------------------------------------------------------------+

class SearchPathAgent(object):
    '''
    SearchPath design adapted from the Arturo project on GitHub.
    '''
    
    KEEP_GOING = 1
    DONE = 0
    DONE_WITH_THIS_DIR = 2
    
    __metaclass__ = ABCMeta
    
    def __init__(self, exclusions=None, useDefaultExcludes=True, followLinks=False):
        super(SearchPathAgent, self).__init__()
        self._visitedDirMemopad = set()
        self._followLinks = followLinks
        self._useDefaultExcludes = useDefaultExcludes
        self._exclusions = exclusions
        self._resultList = list()
        self._resultSet = set()
        
    def getFollowLinks(self):
        return self._followLinks

    def getUseDefaultExcludes(self):
        return self._useDefaultExcludes

    def getVisitedDirMemopad(self):
        return self._visitedDirMemopad
    
    def getExclusions(self):
        return self._exclusions

    def onVisitFile(self, parentPath, rootPath, containingFolderName, filename, fqFilename):
        return SearchPathAgent.KEEP_GOING
    
    def onVisitDir(self, parentPath, rootPath, foldername, fqFolderName, canonicalPath, depth):
        return SearchPathAgent.KEEP_GOING
    
    def getResults(self, ordered=True):
        if ordered:
            return self._resultList
        else:
            return self._resultSet

    def hasResult(self, result):
        return (result in self._resultSet)

    # +-----------------------------------------------------------------------+
    # | PROTECTED
    # +-----------------------------------------------------------------------+
    def _addResult(self, result):
        if result not in self._resultSet:
            self._resultSet.add(result)
            self._resultList.append(result)

# +----------------------------------------------------------------------------------------------------------+

class SearchPath(object):
    '''
    SearchPath design adapted from the Arturo project on GitHub.
    '''

    def __init__(self, environment, basedir):
        super(SearchPath, self).__init__()
        self._env = environment
        self._basedir = basedir
        self._excludeGlobs = GitIgnoreParser.parse(basedir, [".git"])
    
    def __str__(self):
        return str(self._basedir)

    def getPaths(self):
        return self._envpath

    def scanDirs(self, searchIn, searchAgent):
        if searchAgent is None or not isinstance(searchAgent, SearchPathAgent):
            raise ValueError("You must provide a SearchPathAgent object to use the scanDirs method.")
        parentPath = os.path.realpath(os.path.join(searchIn, os.path.pardir))
        canonicalPath = os.path.realpath(searchIn)
        self._scanDirsRecursive(parentPath, searchIn, os.path.basename(searchIn), canonicalPath, searchAgent, 0)
        return searchAgent

    # +-----------------------------------------------------------------------+
    # | PRIVATE
    # +-----------------------------------------------------------------------+
    def _isExcludedByDefault(self, name):
        for excludeGlob in self._excludeGlobs:
            if fnmatch.fnmatch(name, excludeGlob):
                return True
        return False

    def _scanDirsRecursive(self, parentPath, folderPath, folderName, canonicalRoot, searchAgent, folderDepth):
        '''
        Cycle safe, recursive file tree search function.
        '''
        visitedMemopad = searchAgent.getVisitedDirMemopad()
        visitedMemopad.add(canonicalRoot)

        dirThings = os.listdir(folderPath)
        exclusions = searchAgent.getExclusions()
        useDefaultExcludes = searchAgent.getUseDefaultExcludes()

        dirsToTraverse = []
        for name in dirThings:
            if useDefaultExcludes and self._isExcludedByDefault(name):
                self._env.verbose("Ignoring {}".format(name))
                continue
            
            if exclusions is not None and name in exclusions:
                continue

            fullPath = os.path.join(folderPath, name)
            if os.path.isdir(fullPath):
                canonicalDir = os.path.realpath(fullPath)
                resultOfVisit = searchAgent.onVisitDir(parentPath, folderPath, name, fullPath, canonicalDir, folderDepth)
                if resultOfVisit != SearchPathAgent.KEEP_GOING:
                    return resultOfVisit

                if (searchAgent.getFollowLinks() or not os.path.islink(fullPath)) and canonicalDir not in visitedMemopad:
                    dirsToTraverse.append([fullPath, name, canonicalDir])

            else:
                resultOfVisit = searchAgent.onVisitFile(parentPath, folderPath, folderName, name, fullPath)
                if resultOfVisit != SearchPathAgent.KEEP_GOING:
                    return resultOfVisit

        for dirPath, dirName, canonicalDirPath in dirsToTraverse:
            result = self._scanDirsRecursive(folderPath, dirPath, dirName, canonicalDirPath, searchAgent, folderDepth + 1)
            if result == SearchPathAgent.DONE:
                return result
        
        return SearchPathAgent.KEEP_GOING
