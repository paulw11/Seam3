# Seam3

[![CI Status](http://img.shields.io/travis/paulw/Seam3.svg?style=flat)](https://travis-ci.org/paulw/Seam3)
[![Version](https://img.shields.io/cocoapods/v/Seam3.svg?style=flat)](http://cocoapods.org/pods/Seam3)
[![License](https://img.shields.io/cocoapods/l/Seam3.svg?style=flat)](http://cocoapods.org/pods/Seam3)
[![Platform](https://img.shields.io/cocoapods/p/Seam3.svg?style=flat)](http://cocoapods.org/pods/Seam3)
[![GitHub stars](https://img.shields.io/github/stars/paulw11/Seam3.svg)](https://github.com/paulw11/Seam3/stargazers)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

Seam3 is a framework built to bridge gaps between CoreData and CloudKit. It almost handles all the CloudKit hassle. 
All you have to do is use it as a store type for your CoreData store. 
Local caching and sync is taken care of. 

Seam3 is based on [Seam](https://github.com/nofelmahmood/Seam) by [nofelmahmood](https://github.com/nofelmahmood)

Changes in Seam3 include:

* Corrects one-to-many and many-to-one relationship mapping between CoreData and CloudKit
* Adds mapping between binary attributes in CoreData and CKAssets in CloudKit
* Code updates for Swift 3.0 on iOS 10, Mac OS 10.11 & tvOS 10
* Restructures code to eliminate the use of global variables

## CoreData to CloudKit

### Attributes

| CoreData  | CloudKit |
| ------------- | ------------- |
| NSDate    | Date/Time
| Binary Data | Bytes or CKAsset (See below) |
| NSString  | String   |
| Integer16 | Int(64) |
| Integer32 | Int(64) |
| Integer64 | Int(64) |
| Decimal | Double | 
| Float | Double |
| Boolean | Int(64) |
| NSManagedObject | Reference |

**In the table above :** `Integer16`, `Integer32`, `Integer64`, `Decimal`, `Float` and `Boolean` are referring to the instance of `NSNumber` used 
to represent them in CoreData Models. `NSManagedObject` refers to a `to-one relationship` in a CoreData Model.

If a `Binary Data` attribute has the *Allows External Storage* option selected, it will be stored as a `CKAsset` in Cloud Kit, otherwise it will be stored as `Bytes` in the `CKRecord` itself.

### Relationships

| CoreData Relationship  | Translation on CloudKit |
| ------------- | ------------- |
| To - one    | To one relationships are translated as CKReferences on the CloudKit Servers.|
| To - many    | To many relationships are not explicitly created. Seam3 only creates and manages to-one relationships on the CloudKit Servers. <br/> <strong>Example</strong> -> If an Employee has a to-one relationship to Department and Department has a to-many relationship to Employee than Seam3 will only create the former on the CloudKit Servers. It will fullfil the later by using the to-one relationship. If all employees of a department are accessed Seam3 will fulfil it by fetching all the employees that belong to that particular department.|

<strong>Note :</strong> You must create inverse relationships in your app's CoreData Model or Seam3 wouldn't be able to translate CoreData Models in to CloudKit Records. Unexpected errors and corruption of data can possibly occur.

## Sync

Seam3 keeps the CoreData store in sync with the CloudKit Servers. It let's you know when the sync operation starts and finishes by throwing the following two notifications.
- SMStoreDidStartSyncOperationNotification
- SMStoreDidFinishSyncOperationNotification

If an error occurred during the sync operation, then the `userInfo` property of the `SMStoreDidFinishSyncOperationNotification` notification will contain an `Error` object for the key `SMStore.SMStoreErrorDomain`

#### Conflict Resolution Policies
In case of any sync conflicts, Seam3 exposes 3 conflict resolution policies.

- `clientTellsWhichWins`

This policy requires you to set the `syncConflictResolutionBlock` property of your `SMStore`. The closure you specify will receive three `CKRecord` arguments; The first is the current server record.  The second is the current client record and the third is the client record before the most recent change.  Your closure must modify and return the server record that was passed as the first argument.

- `serverRecordWins`

This is the default. It considers the server record as the true record.

- `clientRecordWins`

This considers the client record as the true record.

## How to use

- Declare a SMStore type property in the class where your CoreData stack resides.
```swift
var smStore: SMStore
```
- For iOS9 and earlier or macOS, add a store type of `SMStore.type` to your app's NSPersistentStoreCoordinator and assign it to the property created in the previous step.
```swift

SMStore.registerStoreClass()
do 
{
   self.smStore = try coordinator.addPersistentStoreWithType(SMStore.type, configuration: nil, URL: url, options: nil) as? SMStore
}
```
- For iOS10 using `NSPersistentContainer`:

```swift
lazy var persistentContainer: NSPersistentContainer = {

        SMStore.registerStoreClass()

        let container = NSPersistentContainer(name: "Seam3Demo2")
        
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        if let applicationDocumentsDirectory = urls.last {
            
            let url = applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
            
            let storeDescription = NSPersistentStoreDescription(url: url)
            
            storeDescription.type = SMStore.type
            
            container.persistentStoreDescriptions=[storeDescription]
            
            container.loadPersistentStores(completionHandler: { (storeDescription, error) in
                if let error = error as NSError? {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    
                    /*
                     Typical reasons for an error here include:
                     * The parent directory does not exist, cannot be created, or disallows writing.
                     * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                     * The device is out of space.
                     * The store could not be migrated to the current model version.
                     Check the error message to determine what the actual problem was.
                     */
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            })
            return container
        }
        
        fatalError("Unable to access documents directory")
        
    }()
```
You can access the `SMStore` instance using:
```
self.smStore = container.persistentStoreCoordinator.persistentStores.first as? SMStore
```
Before triggering a sync, you should check the Cloud Kit authentication status and check for a changed Cloud Kit user:
```
self.smStore?.verifyCloudKitConnectionAndUser() { (status, user, error) in
    guard status == .available, error == nil else {
        NSLog("Unable to verify CloudKit Connection \(error)")
        return  
    } 

    guard let currentUser = user else {
        NSLog("No current CloudKit user")
        return
    }

    var completeSync = false

    let previousUser = UserDefaults.standard.string(forKey: "CloudKitUser")
    if  previousUser != currentUser {
        do {
            print("New user")
            try self.smStore?.resetBackingStore()
            completeSync = true
        } catch {
            NSLog("Error resetting backing store - \(error.localizedDescription)")
            return
        }
    }

    UserDefaults.standard.set(currentUser, forKey:"CloudKitUser")

    self.smStore?.triggerSync(complete: completeSync)
}
```
- Enable Push Notifications for your app.
![](http://s29.postimg.org/rb9vj0egn/Screen_Shot_2015_08_23_at_5_44_59_pm.png)
- Implement didReceiveRemoteNotification Method in your AppDelegate and call `handlePush` on the instance of SMStore created earlier.
```swift
 func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) 
 {
    self.smStore?.handlePush(userInfo: userInfo)
 }
```
- Enjoy

## Cross-platform considerations
The default Cloud Kit container is named using your app or application's *bundle identifier*.  If you want to share Cloud Kit data between apps on different platforms (e.g. iOS and macOS) then you need to use a named Cloud Kit container.  You can specify a cloud kit container when you create your SMStore instance.

On iOS10, specify the `SMStore.SMStoreContainerOption` using the `NSPersistentStoreDescription` object

```
let storeDescription = NSPersistentStoreDescription(url: url)
storeDescription.type = SMStore.type
storeDescription.setOption("iCloud.org.cocoapods.demo.Seam3-Example" as NSString, forKey: SMStore.SMStoreContainerOption)
```

On iOS9 and macOS specify an options dictionary to the persistent store coordinator

```
let options:[String:Any] = [SMStore.SMStoreContainerOption:"iCloud.org.cocoapods.demo.Seam3-Example"]
self.smStore = try coordinator!.addPersistentStore(ofType: SMStore.type, configurationName: nil, at: url, options: options) as? SMStore
```
Ensure that you specify the value you specify is selected under *iCloud containers* on the *capabilities* tab for your app in Xcode.

## Migrating from Seam to Seam3

Migration should be quite straight-forward, as the format used to store data in CloudKit and in the local backing store haven't changed.
Change the import statement to `import Seam3` and you should be good to go.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.  If you are running on the simulator, make sure that you log in to iCloud using the settings app in the simulator.

## Installation

Seam3 is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "Seam3"
```

## Author

paulw, paulw@wilko.me

## License

Seam3 is available under the MIT license. See the LICENSE file for more info.
