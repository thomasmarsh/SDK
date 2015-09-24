# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
from abc import ABCMeta, abstractmethod
import os
import subprocess
import inspect
import sys
from subprocess import CalledProcessError
from ftsdk import ERROR_MISSING_TOOLS, SUCCESS
from distutils.util import strtobool
import string
import re
import time

def _is_concrete_environment_subclass(environmentClass):
    if inspect.isclass(environmentClass) and issubclass(environmentClass, Environment) and not inspect.isabstract(environmentClass):
        return True
    else:
        return False
    
def getAllEnvironments():
    module = sys.modules[__name__]
    if not hasattr(module, "__envtype_cache__"):
        environments = []
        environments += inspect.getmembers(sys.modules[__name__], _is_concrete_environment_subclass)
        environmentsDict = {name: environmentClass for name, environmentClass in environments}
        setattr(module, "__envtype_cache__", environmentsDict)
    return getattr(module, "__envtype_cache__")

# +----------------------------------------------------------------------------------------------------------+

class Environment(object):
    '''
    Abstraction for the environment scripts are running within.
    '''
    __metaclass__ = ABCMeta

    @abstractmethod
    def __init__(self, args):
        super(Environment, self).__init__()
        self._loglevel = 0
        self._contexts = []
        self._indents = 0
        self._indent = ""
        self._resetIndent()
        self._args = args
        if getattr(args, "verbose"):
            self._loglevel = 2
            self.verbose('enabling verbose logging.')
        elif getattr(args, "debug"):
            self._loglevel = 1
            self.debug('enabling debug logging.')

    def checkTool(self, tool, getitmessage):
        try:   
            subprocess.check_output("command -v {} >/dev/null 2>&1".format(tool), shell=True)
            return SUCCESS
        except CalledProcessError:
            self.error(getitmessage)
            return ERROR_MISSING_TOOLS

    def __getattr__(self, name):
        try:
            value = getattr(self._args, name)
            if self.willPrintVerbose():
                self.verbose("Attribute {}={} was provided by commandline arguments.".format(name, str(value)))
            return value
        except AttributeError:
            pass
        
        try:
            value = object.__getattr__(self, name)
            if self.willPrintVerbose():
                self.verbose("Attribute {}={} was provided by {}".format(name, str(value), type(self).__name__))
        except AttributeError:
            pass 
        try:
            value = os.environ[name]
            if self.willPrintVerbose():
                self.verbose("Attribute {}={} was provided by the os (os.environ[\"{}\"]).".format(name, str(value), name))
            return value
        except (KeyError, NameError):
            # Use the latest git tag as the sdk version
            if name == 'SDK_VERSION_STRING':
                value = self._getSdkVersionFromGitTag()
                if self.willPrintVerbose():
                    self.verbose("Attribute {}={} was provided by querying git.".format(name, str(value)))
                setattr(self, name, value)
                return value
            elif name == 'BUILD_BRANCH_NAME':
                value = self._getBranchnameFromGit()
                if self.willPrintVerbose():
                    self.verbose("Attribute {}={} was provided by querying git.".format(name, str(value)))
                return value
            elif name == 'BUILDTIME':
                value = time.localtime()
                if self.willPrintVerbose():
                    self.verbose("Attribute {}={} was provided by time.localtime().".format(name, str(value)))
                return value
            elif name == 'GITCOMMIT':
                value = self._getCurrentGitHash()
                if self.willPrintVerbose():
                    self.verbose("Attribute {}={} was provided by quering git".format(name, str(value)))
                return value
            raise AttributeError(name)

    # +---------------------------------------------------------------------------+
    # | CONSOLE OUTPUT
    # +---------------------------------------------------------------------------+
    INDENTATION = "    "
        
    def shift(self):
        '''
        Increase console indentation by 1.
        '''
        self._indents += 1
        self._resetIndent()
    
    def unshift(self):
        '''
        Decrease console indentation by 1.
        '''
        if self._indents > 0:
            self._indents -= 1
            self._resetIndent()

    def pushContext(self):
        '''
        Push the current state of the console into the context stack and expose a new set of states. Use
        push/popContext to handle restoring the original context when an exception is thrown. For example:
        
            try:
                console.pushContext()
                ...
            finally:
                console.popContext()
        '''
        # For now context==indentation but this may change in the future.
        self._contexts.append(self._indents)
        
    def popContext(self):
        '''
        Pop the last console state from the context stack and restore.
        '''
        # For now context==indentation but this may change in the future.
        if len(self._contexts) > 0:
            currentIndents = self._indents
            self._indents = self._contexts.pop()
            if currentIndents != self._indents:
                self._resetIndent()

    def willPrintVerbose(self):
        return (self._loglevel > 1)

    def verbose(self, message, *args):
        if self.willPrintVerbose():
            self._printMessage(message, *args)
            
    def willPrintDebug(self):
        return (self._loglevel > 0)

    def debug(self, message, *args):
        if self.willPrintDebug():
            self._printMessage(message, *args)

    def info(self, message, *args):
        self._printMessage(message, *args)
        
    def warn(self, message, *args):
        self._printMessage(message, *args)

    def error(self, message, *args):
        self._printMessage(message, *args)

    def stdout(self, *tokens):
        for token in tokens:
            print token,

    # +---------------------------------------------------------------------------+
    # | PRIVATE
    # +---------------------------------------------------------------------------+
    def _getBranchnameFromGit(self):
        return subprocess.check_output('git rev-parse --abbrev-ref HEAD', shell=True).strip()
        
    def _getSdkVersionFromGitTag(self):
        tags = subprocess.check_output('git tag -l --sort=-refname sdk*', shell=True)
        value = tags.split('\n')[0]
        return re.match("sdk(\d+\.\d+\.\d+)", value, flags=re.IGNORECASE).group(1)
    
    def _getCurrentGitHash(self):
        return subprocess.check_output('git rev-parse HEAD', shell=True).strip()

    def _resetIndent(self):
        self._indent = ""
        for i in range(0, self._indents):  # @UnusedVariable
            self._indent += self.INDENTATION
            
    def _printMessage(self, message, *args):
        if len(args) > 0:
            print self._indent + (message % args)
        else:
            print self._indent + message

    def _colourize(self, text, colour):
        if string.lower(colour) in ('red'):
            return "\x1b[31m" + text + "\x1b[0m"
        return text

# +----------------------------------------------------------------------------------------------------------+

class ShipIo(Environment):
    '''
    Environments compatible with the Ship.io managed CI service.
    '''
    
    def __init__(self, args):
        super(ShipIo, self).__init__(args)
        self.PACKAGENAME = "FiftyThreeSdk"

    def __getattr__(self, name):
        try:
            return super(ShipIo, self).__getattr__(name)
        except AttributeError as e:
            if name == 'LOCAL_REPOSITORY':
                value = subprocess.check_output("git rev-parse --show-toplevel", shell=True).strip()
                if self.willPrintVerbose():
                    self.verbose("Attribute {}={} was provided by querying git.".format(name, str(value)))
                setattr(self, 'LOCAL_REPOSITORY', value)
                return value
            elif name == 'BUILD_BRANCH_NAME':
                try:
                    return os.environ['BRANCH']
                except (KeyError, NameError):
                    raise e
            elif name == 'ARTIFACTS_DIRECTORY':
                try:
                    return os.environ['ARTIFACTS_DIRECTORY']
                except (KeyError, NameError):
                    return ".build"
            else:
                raise e
