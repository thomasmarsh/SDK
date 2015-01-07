FiftyThree, Inc. Confidential.

##FiftyThree SDK Quick Start Guide##

### Requirements ###

This SDK requires the following:

1) iOS 7 or above. We use a number of newer CoreBluetooth APIs. You can check at run time and not use ```FTPenManager``` if you're on iOS 6. Older versions of iOS aren't supported at all and will crash at app start up.

2) Bluetooth Low Energy (BTLE) compatible hardware. BTLE isn't supported on the iPad 2, iPhone 4 and earlier.

### Quick Start ###
1)	Add FiftyThreeSdk.framework to your xcode project, ensure you're linking against libc++, CoreBluetooth, CoreGraphics, and QuartzCore. Add ```-ObjC``` flag to "Other Linker Flags" build settings.

2)	First ```#include <FiftyThreeSdk/FiftyThreeSdk.h>```. Update your main.m to use ```FTApplication```, via the third parameter of UIApplicationMain, e.g.:
``` 
@autoreleasepool {
          return UIApplicationMain(argc,
                                   argv,
                                   // This is typically nil, use FTApplication here.
                                   NSStringFromClass([FTApplication class]), 
                                   NSStringFromClass([YourAppDelegate class]));
     }
```
   Alternatively, your custom application can subclass ```FTApplication``` or you can use ```FTEventDispatcher```. 
   Note: the FiftyThree SDK only uses touch events, not keyboard events.

3) You will probably want multi-touch enabled for your primary view. In the [viewDidLoad:] method of your root UIViewController you’ll need to add:

```
    // Multi touch is required for processing palm and pen touches.
    // See handleTouches below.
    [self.view setMultipleTouchEnabled:YES];
    [self.view setUserInteractionEnabled:YES];
```

4) Modify your root UIViewController to implement the following delegate protocols:

```
FTTouchClassificationsChangedDelegate
FTPenManagerDelegate
```


5) Add the pairing UI to your application. In your [viewDidLoad:] method you might do something like:

```
UIView *pencilPairingView = [[FTPenManager sharedInstance] pairingButtonWithStyle:FTPairingUIStyleDefault];

pencilPairingView.frame = CGRectMake(0.0f, 768 - 100, v.frame.size.width, v.frame.size.height);
[self.view addSubview:pencilPairingView];
```

Then subscribe to get notifications via the two delegates you’ve implemented.

```
    [FTPenManager sharedInstance].classifier.delegate = self;
    [FTPenManager sharedInstance].delegate = self;
```

The pairing UI should now appear in your view.  Pressing the control with your Pencil will trigger the connection sequence and animations, as in Paper’s tray view.


6) Handle re-classification of touches.  Touches can transition between the states enumerated in ``` FTTouchClassification``` 


Once per frame, you will receive a collection of all the touches whose classification has changed that you'll need to process e.g.,

```
- (void)classificationsDidChangeForTouches:(NSSet *)touches
{
    for (FTTouchClassificationInfo *info in touches)
    {
        NSLog(@"Touch %d was %d now %d", info.touchId, info.oldValue, info.newValue);
        
        // Your app might:
        // 1. Render touches that have been reclassified as "pen".
        // 2. Implement 1-finger smudge for touches that have been classified as "finger".
        // 3. Use touches that have been classified as "finger" for gestures.
        //
        // Classification of a touch can change, so you'll need to handle transitions between any classifications. 
        // 1. Revert a pen stroke for a touch that was previously classified as "pen" but has been reclassified as "palm".
        // 2. Change a pen stroke to a smudge that was previously classified as "pen" but has been reclassified as "finger".
        //
        // Bear in mind that classification can even change _after_ a touch has ended.
    }
} 
```

You can use these classifications to alter how strokes are rendered and to implement flip-to-erase functionality.

7) You will probably only want to use one vendor's stylus SDK at a time; use ```[FTPenManager shutdown]``` to ensure the FiftyThree SDK isn't using any CoreBluetooth resources. 

8) (Optional) Add support for status. 
In the implementation of ```penInformationDidChange``` you can use 
``` [FTPenManager sharedInstance].info``` to populate a tableview of settings. See ```FTASettingsViewController``` for an example.


### Known Issues ###
1) ```FTPenInformation``` can take up to 30 seconds to report the correct battery status.

2) The sample apps are still in development. There is one is now included in the tar file, see ```FTAViewController``` for basic connection & classification application support.
