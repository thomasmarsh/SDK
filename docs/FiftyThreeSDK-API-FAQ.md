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

