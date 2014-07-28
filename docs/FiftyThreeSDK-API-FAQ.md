## FiftyThree SDK API NOTES AND FAQ ##

Most of this is pretty straightforward and it is similiar to the other stylus APIs on the market.

### Overview of the major API objects ###

```FTPenManager```      - deals with connection, CoreBluetooth coordination, and SDK object lifetime. 

```FTTouchClassifier``` - provides information about what we think a touch is. 

```FTApplication```     - provides a hook for getting events for touch classification. When the SDK is disabled, this just invokes ```[super sendEvent];```.

```FTPenInformation```  - a collection of readonly properties that can be shown in a settings or details view.

```FTEventDispatcher```  - *Optional.*  If you don't want to subclass or use FTApplication. You'll need to forward UIEvents to FiftyThree's classifier via ```[[FTEventDispatcher sharedInstance] sendEvent:]```.

### FAQ ###

#####What is this ```FTApplication``` object? Why do I need to use it?

For the classification code to be effective it needs to watch all the
touches in the system and all BTLE related pen information. In Paper we found
it easiest to override UIApplication's sendEvent method and get touch data that
way. We also provide a ```FTEventDispatcher```, which is a singleton, and you can 
invoke sendEvent on that if for some reason you're adverse to using FTApplication.

#####Why is ```FTPenManagerState``` so complicated? Isn't this just a boolean?

Our pairing model doesn't use the BTLE bonded/encrypted pair. Instead we allow the device to repair with other ipads. This provides what we (FiftyThree) think is a better pairing UX model which is more transparent to the user. However it means that our connection flow has more states. Most of this should be opaque to the API user as we're providing the pairing animation UI. 


#####Why does ```FTPenManager``` have all this firmware update state?

We've improved the Pencil connection experience and this required updating Pencil firmware. Since the UI for Pencil firmware update is rather involved, we provided an API to open Paper by FiftyThree and invoke the firmware upgrade path there. ```x-callback-urls``` is used to do inter-app communication. We provide a minimal set of functions in the SDK to check if newer firmware can be installed, if the proper version of Paper is installed, and to invoke Paper with the right parameters to install the firmware. Typically, you'd add a button in a settings table view.

If you want to add support for this in your app you'll need to do the following:

* First turn on the check for firmware update when you setup FTPenManager.

```
[FTPenManager sharedInstance].shouldCheckForFirmwareUpdates = YES;
```

* Implement the optional method in the ```FTPenManagerDelegate``` protocol ```penManagerFirmwareUpdateIsAvailableDidChange```. In this method you want to check if there's new firmware *and* if the proper version of Paper is installed.  Paper version 1.6.3 or later is required to perform the firmware update, and if either no version or earlier versions are installed,  the ```canInvokePaperToUpdatePencilFirmware``` property will return false.  For instance:

```
- (void)penManagerFirmwareUpdateIsAvailableDidChange
{
    NSNumber *firmwareUpdateIsAvailable = [FTPenManager sharedInstance].firmwareUpdateIsAvailable;

    if (firmwareUpdateIsAvailable != nil && [firmwareUpdateIsAvailable boolValue])
    {
        // Note, we always enable the button but if Paper isn't installed that button
        // will open the support site.
        self.updateFirmwareButton.enabled = YES;
    }
    else
    {
        self.updateFirmwareButton.enabled = NO;
    }
}
```

* If your user taps the firmware update button you've shown above, you'll need to invoke firmware update. The API we provide allows you to provide callback URLs to your app. You'd need to add these URLs to your application's URL Types in your Info.plist. Shown below is the sample code to invoke firmware upgrade.

```
- (void)updateFirmware:(id)sender
{
    NSNumber *firmwareUpdateIsAvailable = [FTPenManager sharedInstance].firmwareUpdateIsAvailable;

    if (firmwareUpdateIsAvailable != nil && [firmwareUpdateIsAvailable boolValue])
    {
        BOOL isPaperInstalled = [FTPenManager sharedInstance].canInvokePaperToUpdatePencilFirmware;
        if (isPaperInstalled)
        {
            // We invoke Paper via url handlers. You can optionally specify urls so that
            // Paper can return to your app. The application name is shown in a button labelled:
            // Back To {Application Name}
            NSString *applicationName = @"SDK Test App";
            // In the plist we register sdktestapp as an url type. See The app delegate.
            NSURL *successUrl = [NSURL URLWithString:@"sdktestapp://x-callback-url/success"];
            NSURL *cancelUrl = [NSURL URLWithString:@"sdktestapp://x-callback-url/cancel"];
            NSURL *errorUrl = [NSURL URLWithString:@"sdktestapp://x-callback-url/error"];

            BOOL result = [[FTPenManager  sharedInstance] invokePaperToUpdatePencilFirmware:applicationName
                                                                                    success:successUrl
                                                                                      error:errorUrl
                                                                                     cancel:cancelUrl];

            if (!result)
            {
                // If we for some reason couldn't open the url. We might alert to user.
            }
        }
        else
        {
            // If Paper isn't installed or is too old to support firmware update,
            // we'll direct the user to FiftyThree's support site. 
            // This site walks them through installing Paper and doing firmware update.
            NSURL *firmwareUpdateSupportUrl = [FTPenManager sharedInstance].firmwareUpdateSupportLink;
            BOOL result = [[UIApplication sharedApplication] openURL:firmwareUpdateSupportUrl];
            if (!result)
            {
                // Very unlikely that opening mobile safari would fail. But you might alert the user here.
            }
        }
    }
}
```

