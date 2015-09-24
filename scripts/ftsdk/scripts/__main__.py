# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
from ftsdk.scripts import getAllCommands, Script, getCommandNamesFromCommandline
import sys
from ftsdk import ERROR_INVALID_INPUT
    
if __name__ == '__main__':
    commands = getAllCommands()
    commandNames = getCommandNamesFromCommandline();
    if len(commandNames) == 0:
        for commandName in commands.keys():
            print "{}".format(commandName)
    else:
        commandObjects = []
        for commandArg in commandNames:
            try :
                commandObjects.append(commands[commandArg]())
            except KeyError:
                print "{} is not a valid command.".format(commandArg)
                sys.exit(ERROR_INVALID_INPUT)
        
        unknownScript = Script("", *commandObjects)
        sys.exit(unknownScript.run())
