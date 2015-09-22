# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
from ftsdk import SUCCESS, ERROR_SHELLSCRIPT, ERROR_UNEXPECTED_STATE, Command, builders, packagers, validators,\
    MissingAttributeException, ERROR_INVALID_INPUT, ERROR_NOTFOUND, publishers
from subprocess import CalledProcessError
import inspect
from abc import ABCMeta
from ftsdk.environ import getAllEnvironments
import argparse
import sys

def _is_concrete_command_subclass(commandClass):
    if inspect.isclass(commandClass) and issubclass(commandClass, Command) and not inspect.isabstract(commandClass) and not commandClass == Command:
        return True
    else:
        return False

def getArguments():
    module = sys.modules[__name__]
    if not hasattr(module, "__argcache__"):
        parser = argparse.ArgumentParser(description='FiftyThree SDK modular build script.')
        environmentHelpString = "The build environment ("
        environmentHelpString += ', '.join(getAllEnvironments().keys())
        environmentHelpString += ")"
        parser.add_argument('-env', required=True, help=environmentHelpString)
        parser.add_argument('commands', nargs=argparse.REMAINDER)
        parser.add_argument('-t', '--target', 
                            default="Production", 
                            help="Scheme build flavor.")
        parser.add_argument('-v', '--verbose',
                            default=False,
                            action='store_true',
                            help='Enable verbose logging.')
        parser.add_argument('-d', '--debug',
                            default=False,
                            action='store_true',
                            help='Enable debug logging.')
        parser.add_argument('--messy',
                            default=False,
                            action='store_true',
                            help="Don't cleanup intermediates.")
        setattr(module, "__argcache__", parser.parse_args())
    return module.__argcache__

def getAllCommands():
    commands = []
    commands += inspect.getmembers(builders, _is_concrete_command_subclass)
    commands += inspect.getmembers(packagers, _is_concrete_command_subclass)
    commands += inspect.getmembers(validators, _is_concrete_command_subclass)
    commands += inspect.getmembers(publishers, _is_concrete_command_subclass)
    #TODO: determine this via reflection
    commands += [
                 ("ftsdk.scripts.build", None),
                 ("ftsdk.scripts.publish", None),
                 ("ftsdk.scripts.publish.nostrip", None)
                 ]
    commandDict = {name: commandClass for name, commandClass in commands}
    return commandDict

def getCommandNamesFromCommandline():
    return getArguments().commands
    
def createEnvironmentFromCommandline():
    args = getArguments()
    environmentName = args.env
    for environmentTypeName, environmentType in getAllEnvironments().iteritems():
        if environmentName == environmentTypeName:
            return environmentType(args)
    return None

'''
Package containing modules that assemble commands into programs. To invoke load a script module as main:

    python -m ftsdk.scripts.myscript
    
To manually run commands list them in order after ftsdk.scripts:

    python -m ftsdk.scripts MyCommand0 MyCommand1 ... MyCommandN

To list available commands invoke ftsdk.scripts directly:

    python -m ftsdk.scripts

'''

# +----------------------------------------------------------------------------------------------------------+

class Script(object):
    '''
    Helper object to run the Command protocol over a list of Commands.
    '''
    
    def __init__(self, name, *commands):
        super(Script, self).__init__()
        self._commands = commands
        self._name = name
        self.ENVIRONMENT = createEnvironmentFromCommandline()
    
    def __str__(self):
        return self._name

    def __getattr__(self, name):            
        if self.ENVIRONMENT is not None and self.ENVIRONMENT.willPrintVerbose():
            self.ENVIRONMENT.verbose("Begin {} lookup.".format(name))

        try:
            value = object.__getattr__(self, name)
            if self.ENVIRONMENT is not None and self.ENVIRONMENT.willPrintVerbose():
                self.ENVIRONMENT.info("Attribute {}={} was provided by {}.".format(name, str(value), type(self).__name__))
            return value
        except AttributeError:
            pass

        try:
            value = getattr(self.ENVIRONMENT, name)
            if self.ENVIRONMENT is not None and self.ENVIRONMENT.willPrintVerbose():
                self.ENVIRONMENT.info("Attribute {}={} was provided by {}.".format(name, str(value), type(self.ENVIRONMENT).__name__))
            return value
        except AttributeError:
            pass
        
        for command in self._commands:
            try:
                value = getattr(command, name)
                if self.ENVIRONMENT is not None and self.ENVIRONMENT.willPrintVerbose():
                    self.ENVIRONMENT.info("Attribute {}={} was provided by {}.".format(name, str(value), type(command).__name__))
                return value
            except AttributeError:
                pass

        if self.ENVIRONMENT is not None and self.ENVIRONMENT.willPrintVerbose():
            self.ENVIRONMENT.info("Attribute {} was not found.".format(name))
        raise AttributeError(name)
        
    def run(self, dryrun=False):
        if self.ENVIRONMENT is None:
            print "Environment must be one of {}".format(', '.join(getAllEnvironments().keys()))
            return ERROR_INVALID_INPUT 
        
        result = self._dophase("setup")
        if SUCCESS != result:
            return result
        
        if not dryrun:
            result = self._dophase("run")
            if SUCCESS != result:
                return result
        
        return self._dophase("teardown")
        
    def _dophase(self, phaseName):
        previousCommand = None
        
        for command in self._commands:
            try:
                result = getattr(command, phaseName)(self, previousCommand)
                if SUCCESS != result:
                    self.ENVIRONMENT.error("{}.{}.{}({}) failed".format(str(self), command.__class__.__name__, phaseName, previousCommand.__class__.__name__ if previousCommand is not None else "None"))
                    return result
                previousCommand = command
            except MissingAttributeException as e:
                self.ENVIRONMENT.error("{}.{}.{}({}) failed because it was missing a required attribute \n{}".format(
                     str(self), 
                     command.__class__.__name__, 
                     phaseName, previousCommand.__class__.__name__ if previousCommand is not None else "None",
                     str(e)))
                return ERROR_UNEXPECTED_STATE
            except CalledProcessError as e:
                self.ENVIRONMENT.error("{}.{}.{}({}) failed executing a shell command: \n{}".format(
                     str(self), 
                     command.__class__.__name__, 
                     phaseName, previousCommand.__class__.__name__ if previousCommand is not None else "None",
                     str(e)))
                return ERROR_SHELLSCRIPT

        return SUCCESS
