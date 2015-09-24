# SDK Internal README and release process.

<a href='https://app.ship.io/dashboard#/jobs/10687/history' target='_blank'><img src='https://app.ship.io/jobs/VYUOpF5AR0mYJs7k/build_status.png' width='160' /></a> Develop

<a href='https://app.ship.io/dashboard#/jobs/10690/history' target='_blank'><img src='https://app.ship.io/jobs/lSVsEGrXl8qkSHdU/build_status.png' width='160' /></a> Master

## Components
- docs/ these are all copied into a tar.bz2 as part of the automated build. This includes branding guidelines, quick start guide and legal notices.
- FiftyThreeSdk/ contains the library source code used by both Paper and FiftyThreeSDK project. The public headers which are copied with the .framework are the ones in FiftyThreeSdk.h
- FiftyThreeSdkTestApp/ contains the source code of a test app. This source code is included with the SDK so don't put any private API calls there.
- FiftyThreeSimpleSampleApp/ contains *only* a xcodeporoject file, with out any FiftyThree build configuration settings. This is packaged and built as part of the automated build process. If you add files to the test app you'll need to add them here too.

## Building (Internally):
For debugging open FiftyThreeSdkTestApp/FiftyThreeSdkTestApp.xcworkspace/ in xcode. Note, this test app ships as part of the SDK but compiles non-framework versions so it's easy to step in the debugger.

To build from the commandline use the python scripts provided in the script folder.

### Python Script Cookbook

(using the [`ShipIo`](https://support.ship.io/environment/build-environment) environment. It's possible there are other environments available)

##### List available commands
```
python -m ftsdk.scripts -env ShipIo
```

##### Simple build (no clean) using [XCTool](https://github.com/facebook/xctool)
```
python -m ftsdk.scripts -env ShipIo XCToolBuild
```

##### Full build using [XCTool](https://github.com/facebook/xctool)
```
python -m ftsdk.scripts.build -env ShipIo
```

##### Create static framework
```
python -m ftsdk.scripts.publish -env ShipIo
```

##### Create static framework with debug symbols
```
python -m ftsdk.scripts.publish.nostrip -env ShipIo
```

##### Print build variable resolutions
```
python -m ftsdk.scripts -v -env ShipIo XCToolBuild
```

##### Debug build (Production is the default)
```
python -m ftsdk.scripts --target Debug -env ShipIo XCToolBuild
```

##### Override any variable in the python scripts
You can override any variable used by the python scripts (see "Print build variable resolutions" above for how to see these variables) by setting the same variable in your environment.
For example:
```
ARTIFACTS_DIRECTORY=.developbuild python -m ftsdk.scripts.build --target Develop -env ShipIo
```

## Release
### Release Checklist:
- Bump version in Build/build.py and check in.

- Run copy changes and header documentation changes by EricR.

- check jenkins for the release artefacts fiftythree-public-sdk.tar.bz2

```
https://int.fiftythree.com/jenkins/job/Paper_develop/
```

- ensure the tar.bz2 project compiles and runs as expected.

- tag the git repo
git tag -a sdk1.X.X
use tag name as annotation when prompted
git push --tags

- copy the tar.bz2 files to partners dropbox folders & let them know via email.
