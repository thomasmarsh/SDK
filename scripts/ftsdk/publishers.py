# +----------------------------------------------------------------------------------------------------------+
# |   ,--.
# |  | 53 |
# |   `--'  SDK
# |
# | Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
# |
# +----------------------------------------------------------------------------------------------------------+
from ftsdk import Command, SUCCESS, ERROR_UNEXPECTED_STATE, ERROR_UNEXPECTED_RESPONSE
import shutil
import os
import httplib
import sys
import json
import urllib
import urlparse
from ftsdk.osutil import LoggingFileInputStream
from ftsdk.environ import bold

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
            setattr(self, "SDK_ARCHIVE", archiveName)
            script.ENVIRONMENT.info("Created SDK bundle at {}".format(archiveName))
            return SUCCESS
        else:
            script.ENVIRONMENT.error("Expected SDK bundle at {}.[extension]".format(basepath))
            return ERROR_UNEXPECTED_STATE

    
# +----------------------------------------------------------------------------------------------------------+

class PublishStaticFrameworkToGithubRelease(Command):
    '''
    Uploads SDK_ARCHIVE from the script as SDK_VERSION_STRING using an oauth otoken provided as GITHUB_ACCESS_TOKEN
    to a release tagged as "sdk${SDK_VERSION_STRING}"
    
    protip: you can invoke this command directly by defining the SDK_ARCHIVE environment variable
    
        SDK_ARCHIVE=path/to/.build/buildarchive.tar.bz2 python -m ftsdk.scripts -env [myenv] PublishStaticFrameworkToGithubRelease

    '''
    USER_AGENT_HEADER = "python {}.{} httplib".format(sys.version_info.major, sys.version_info.minor)
    
    def run(self, script, previousCommand):
        self._inheritAttribute("SDK_ARCHIVE", script)
        self._inheritAttribute("SDK_VERSION_STRING", script)
        self._inheritAttribute("GITHUB_ACCESS_TOKEN", script)
        self._inheritAttributeOrDefault("GITHUB_OWNER", script, "FiftyThree")
        self._inheritAttribute("LOCAL_REPOSITORY", script)
        self._inheritAttribute("GITCOMMIT_SHORT", script)
        
        githubapi = httplib.HTTPSConnection('api.github.com')

        try:
            release_response = self._get_release(script, githubapi)

            response_map = json.JSONDecoder().decode(release_response.read())
            self._debug_response(script, release_response, response_map)
            
            if release_response.status < 200 or release_response.status > 299:
                create_response = self._create_release(script, githubapi)
                create_response_map = json.JSONDecoder().decode(create_response.read())

                self._debug_response(script, create_response, create_response_map)

                if create_response.status == httplib.UNPROCESSABLE_ENTITY:
                    script.warn("Release {} already exists.".format(create_response["name"]))
                    return ERROR_UNEXPECTED_STATE
                elif create_response.status < 200 or create_response.status > 299:
                    script.error("upload failed with {} ({})".format(str(create_response.status), str(create_response_map)))
                    return ERROR_UNEXPECTED_RESPONSE

                # replace the release objects with the newly created release
                release_response = create_response
                response_map = create_response_map

            if not response_map.get("prerelease"):
                script.hr()
                script.pushContext()
                try:
                    github_edit_release_url = "https://github.com/{}/{}/releases/edit/sdk{}".format(self.GITHUB_OWNER, 
                                                                                                   os.path.basename(self.LOCAL_REPOSITORY),
                                                                                                   self.SDK_VERSION_STRING)
                    script.shift()
                    script.warn(bold("sdk{} was already released.".format(self.SDK_VERSION_STRING)))
                    script.shift()
                    script.warn("If you want to re-release this version you will first have to go to ")
                    script.warn(github_edit_release_url)
                    script.warn("and mark the github release as a \"pre-release\". This script will only")
                    script.warn("upload to pre-release marked releases to prevent overwriting final artifacts.")
                    return ERROR_UNEXPECTED_STATE
                finally:
                    script.popContext()
                    script.hr()

        finally:
            githubapi.close()

        asset_name = "{1}-{0}".format(os.path.basename(self.SDK_ARCHIVE), self.GITCOMMIT_SHORT)

        if self._is_in_release(response_map, asset_name):
            script.warn("{} already exists. Nothing to do.".format(asset_name))
        else:
            upload_url = self._create_upload_url(script, 
                                                 response_map["upload_url"], 
                                                 name=asset_name, 
                                                 access_token=self.GITHUB_ACCESS_TOKEN)

            upload_response = self._simple_upload(script, upload_url)

            self._debug_response(script, upload_response)
        
            if upload_response.status < 200 or upload_response.status > 299:
                return ERROR_UNEXPECTED_RESPONSE
            else:
                script.info("Successfully uploaded artifact {} to \"{}\" release".format(asset_name, response_map["name"]))

        return SUCCESS

    # +--------------------------------------------------------------------------------------------------+
    # | PRIVATE
    # +--------------------------------------------------------------------------------------------------+
    def _debug_response(self, script, response, response_json=None):
        if script.willPrintDebug():
            if response_json is None:
                response_json = json.JSONDecoder().decode(response.read())
            script.debug("STATUS = {}\n{}".format(response.status, json.dumps(response_json, sort_keys=True, indent=4, separators=(',', ': '))))

    def _is_in_release(self, release, asset_name):
        if "assets" in release:
            assets = release["assets"]
            for asset in assets:
                if asset["name"] == asset_name:
                    return True
        return False
        
    def _create_release(self, script, githubapi):
        createjson = json.JSONEncoder().encode({ "tag_name": "sdk{}".format(self.SDK_VERSION_STRING),
                                                 "name" : "FiftyThree SDK for iOS v{}".format(self.SDK_VERSION_STRING),
                                                 "prerelease" : True })
        githubapi.request("POST", "https://api.github.com/repos/{}/{}/releases?access_token={}".format(
                                        self.GITHUB_OWNER, 
                                        os.path.basename(self.LOCAL_REPOSITORY), 
                                        self.GITHUB_ACCESS_TOKEN), 
                          createjson, {"User-Agent":self.USER_AGENT_HEADER})

        return githubapi.getresponse()

    def _get_release(self, script, githubapi):
        createjson = json.JSONEncoder().encode({ "tag_name": "sdk{}".format(self.SDK_VERSION_STRING),
                                                     "name" : "FiftyThree SDK for iOS v{}".format(self.SDK_VERSION_STRING)})
        githubapi.request("GET", "https://api.github.com/repos/{}/{}/releases/tags/sdk{}?access_token={}".format(
                                        self.GITHUB_OWNER, 
                                        os.path.basename(self.LOCAL_REPOSITORY),
                                        self.SDK_VERSION_STRING, 
                                        self.GITHUB_ACCESS_TOKEN), 
                          createjson, {"User-Agent":self.USER_AGENT_HEADER})

        return githubapi.getresponse()

    def _simple_upload(self, script, url):
        '''
        The Github API doesn't seem to like multi-part upload for this so just do a simple POST. 
        '''
        parsed = urlparse.urlsplit(url)
        requestpath = parsed.path + "?" + parsed.query
        uploadhost = httplib.HTTPSConnection(parsed.hostname)
        with LoggingFileInputStream(self.SDK_ARCHIVE, "rb", script) as sdkfile:
            headers = {"Content-Type": "application/x-gtar",
                       "User-Agent":self.USER_AGENT_HEADER,
                       }
            
            script.debug(requestpath)
            uploadhost.request("POST", requestpath, sdkfile, headers)
            return uploadhost.getresponse()

    def _create_upload_url(self, script, hypermedia_upload_url, **arguments):
        #TODO: use real hypermedia url library.
        script.ENVIRONMENT.verbose("_create_upload_url: Searching through " + hypermedia_upload_url)
        param_start = hypermedia_upload_url.find("{?")
        
        if param_start == -1:
            script.ENVIRONMENT.error("hypermedia upload_url did not have parameters?")
            return None
        
        request_url = hypermedia_upload_url[:param_start] + "?"
        
        request_url += urllib.urlencode(arguments)
        return request_url

