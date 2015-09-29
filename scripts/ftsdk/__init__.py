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
from abc import ABCMeta, abstractmethod
import subprocess
import re
from fnmatch import fnmatch

'''
Package containing Command objects that can be arranged into build scripts (see script package for such arrangements).
'''

SUCCESS = 0
ERROR_MISSING_TOOLS = 1
ERROR_UNEXPECTED_STATE = 2
ERROR_SHELLSCRIPT = 3
ERROR_INVALID_INPUT = 4
ERROR_NOTFOUND = 5
ERROR_UNEXPECTED_RESPONSE = 6

    
# +----------------------------------------------------------------------------------------------------------+

class MissingAttributeException(RuntimeError):
    pass

# +----------------------------------------------------------------------------------------------------------+

class Command(object):
    '''
    Protocol for all objects run as part of a script command.
    '''
    __metaclass__ = ABCMeta
    
    def __init__(self):
        super(Command, self).__init__()
        
    def setup(self, script, previousCommand):
        return SUCCESS

    @abstractmethod
    def run(self, script, previousCommand):
        return SUCCESS
    
    def teardown(self, script, previousCommand):
        return SUCCESS
    
    def getEnvironment(self, script):
        return getattr(script, "ENVIRONMENT")

    # +------------------------------------------------------------------------------------------------------+
    # | PROTECTED
    # +------------------------------------------------------------------------------------------------------+
    def _inheritAttributeOrDefault(self, attribute, fromCommand, defaultValue):
        try:
            return self._inheritAttribute(attribute, fromCommand, type(defaultValue))
        except MissingAttributeException:
            setattr(self, attribute, defaultValue)
            return defaultValue

    def _inheritAttribute(self, attribute, fromCommand, requiredType=None):
        if hasattr(self, attribute):
            value = getattr(self, attribute)
        elif hasattr(fromCommand, attribute):
            value = getattr(fromCommand, attribute)
        else:
            raise MissingAttributeException("failed to inherit attribute {} from {}".format(attribute, type(fromCommand).__name__))
        
        if value is None:
            raise MissingAttributeException("attribute inherited from {} {} was None.".format(type(fromCommand).__name__, attribute))
        
        if requiredType is not None and type(value) is not requiredType and issubclass(type(value), requiredType):
            raise MissingAttributeException("attribute inherited from {} was of type {}. Expected type {}".format(type(fromCommand).__name__, type(attribute).__name__, requiredType.__name__))
        
        setattr(self, attribute, value)
        return value

