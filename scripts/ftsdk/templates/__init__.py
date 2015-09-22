# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
import os
import jinja2
from jinja2.loaders import PackageLoader
from jinja2.runtime import DebugUndefined, StrictUndefined
import time

class JinjaTemplate(object):
    '''
    Wrapper around a jinja2 template object which sets up the provided environment for the template when rendered.
    '''
    
    JINJASUFFIX = ".jinja"
    
    def __init__(self, jinjaEnvironment, templateName, parentTemplateName=None):
        self._templateName = templateName
        self._parentTemplate = parentTemplateName + self.JINJASUFFIX if parentTemplateName is not None else None
        self._template = None
        self._jinjaEnv = jinjaEnvironment
    
    def getTemplate(self):
        if self._template is None:
            self._template = self._jinjaEnv.get_template(self._templateName, parent=self._parentTemplate)
        return self._template
    
    def renderTo(self, targetFilePath, params=dict()):
        with open(targetFilePath, 'wt') as f:
            f.write(self.render(targetFilePath, params))
            f.write('\n')

    def render(self, targetFilePath, params=dict()):
        try:
            params['this'] = {
                    'template' : self._templateName,
                    'filename' : os.path.basename(targetFilePath),
                    'path'     : targetFilePath,
                }
            return self.getTemplate().render(params)
        finally:
            params.pop('this')
    
class JinjaTemplates(object):
    
    @classmethod
    def createJinjaEnvironmentForTemplates(cls, script):
        if not hasattr(cls, "_jinjaenv"):
            jinjaEnv = jinja2.Environment(loader=PackageLoader("ftsdk"), undefined=StrictUndefined)
            jinjaEnv.globals['script'] = script
            jinjaEnv.filters['datetimeformat'] = cls._format_strftime
            setattr(cls, "_jinjaenv", jinjaEnv)
        return getattr(cls, "_jinjaenv")
        
    @classmethod
    def getTemplate(cls, script, templateName, parentTemplateName=None):
        return JinjaTemplate(cls.createJinjaEnvironmentForTemplates(script), templateName, parentTemplateName)
    
    @staticmethod
    def _format_strftime(value, value_format):
        return time.strftime(value_format, value)