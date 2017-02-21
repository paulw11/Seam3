//    SMStore.swift
//
//    The MIT License (MIT)
//
//    Copyright (c) 2016 Paul Wilkinson ( https://github.com/paulw11 )
//
//    Based on work by Nofel Mahmood
//
//    Portions copyright (c) 2015 Nofel Mahmood ( https://twitter.com/NofelMahmood )
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

/** 
 
  # Seam3

Seam3 is a framework built to bridge gaps between CoreData and CloudKit. It almost handles all the CloudKit hassle.
All you have to do is use it as a store type for your CoreData store.
Local caching and sync is taken care of.

Seam3 is based on [Seam](https://github.com/nofelmahmood/Seam) by [nofelmahmood](https://github.com/nofelmahmood)

Changes in Seam3 include:

* Corrects one-to-many and many-to-one relationship mapping between CoreData and CloudKit
* Adds mapping between binary attributes in CoreData and CKAssets in CloudKit (Not yet :( )
* Code updates for Swift 3.0 and iOS 10
* Restructures code to eliminate the use of global variables

## CoreData to CloudKit

### Attributes

| CoreData  | CloudKit |
| ------------- | ------------- |
| NSDate    | Date/Time
| NSData | Bytes
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

### Relationships

| CoreData Relationship  | Translation on CloudKit |
| ------------- | ------------- |
| To - one    | To one relationships are translated as CKReferences on the CloudKit Servers.|
| To - many    | To many relationships are not explicitly created. Seam only creates and manages to-one relationships on the CloudKit Servers. <br/> <strong>Example</strong> -> If an Employee has a to-one relationship to Department and Department has a to-many relationship to Employee than Seam will only create the former on the CloudKit Servers. It will fullfil the later by using the to-one relationship. If all employees of a department are accessed Seam will fulfil it by fetching all the employees that belong to that particular department.|

<strong>Note :</strong> You must create inverse relationships in your app's CoreData Model or Seam wouldn't be able to translate CoreData Models in to CloudKit Records. Unexpected errors and corruption of data can possibly occur.

## Sync

Seam keeps the CoreData store in sync with the CloudKit Servers. It let's you know when the sync operation starts and finishes by throwing the following two notifications.
- SMStoreDidStartSyncOperationNotification
- SMStoreDidFinishSyncOperationNotification

#### Resolution Policies
In case of any sync conflicts, Seam exposes 4 conflict resolution policies.

- ClientTellsWhichWins

This policy requires you to set syncConflictResolutionBlock block of SMStore. You get both versions of the record as arguments. You do whatever changes you want on the second argument and return it.
    
    - ServerRecordWins

This is the default. It considers the server record as the true record.

- ClientRecordWins

This considers the client record as the true record.

## How to use

- Declare a SMStore type property in the class where your CoreData stack resides.
```swift
var smStore: SMStore
```
- For iOS9 and earlier, add a store type of `SeamStoreType` to your app's NSPersistentStoreCoordinator and assign it to the property created in the previous step.
```swift
do
{
    self.smStore = try coordinator.addPersistentStoreWithType(SeamStoreType, configuration: nil, URL: url, options: nil) as? SMStore
}
```
- For iOS10 using `NSPersistentContainer`:

```swift
lazy var persistentContainer: NSPersistentContainer = {
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
- Enable Push Notifications for your app.
    ![](http://s29.postimg.org/rb9vj0egn/Screen_Shot_2015_08_23_at_5_44_59_pm.png)
    - Implement didReceiveRemoteNotification Method in your AppDelegate and call `handlePush` on the instance of SMStore created earlier.
    ```swift
func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject])
{
    self.smStore?.handlePush(userInfo: userInfo)
}
```
*/

import CoreData
import CloudKit
import ObjectiveC

public struct SMStoreNotification {
    public static let SyncDidStart = "SMStoreDidStartSyncOperationNotification"
    public static let SyncDidFinish = "SMStoreDidFinishSyncOperationNotification"
}

/// Potential errors from SMStore operations
enum SMStoreError: Error {
    /// Error occurred executing a Core Data fetch request against the backing store
    case backingStoreFetchRequestError
    /// Invalid request
    case invalidRequest
    /// Error occurred creating the backing store
    case backingStoreCreationFailed
    /// Error occurred resetting the backing store
    case backingStoreResetFailed
    /// Error occurred updating the backing store
    case backingStoreUpdateError
    /// A relationship in the Core Data model is missing the required inverse relationship
    case missingInverseRelationship
    //// "To-many" relationships are not supported
    case manyToManyUnsupported
    /// The related object could not be found to satisfy a relationship
    case missingRelatedObject
}

/// Sync conflict resolution policies
public enum SMSyncConflictResolutionPolicy: Int16 {
    /// Client determines sync winner using resolution closure
    case clientTellsWhichWins = 0
    /// Server record always wins
    case serverRecordWins = 1
    /// Client record always wins
    case clientRecordWins = 2
}

/** ## SMStore
 SMStore implements an `NSIncrementalStore` that is backed by CloudKit to provide synchronisation between devices.
 */

open class SMStore: NSIncrementalStore {
    /// If true, a sync is triggered automatically when a save operation is performed against the store. Defaults to `true`
    public var syncAutomatically: Bool = true
    
    /// The closure that will be invoked to resolve sync conflicts when the `SMStoreSyncConflictResolutionPolicyOption` is set to `clientTellsWhichWins`
    /// - parameter clientRecord:   a `CKRecord` representing the client record state
    /// - parameter serverRecord:   a `CKRecord` representing the server (cloud) record state
    /// - returns: The record that will be saved to both the client and cloud
    public var recordConflictResolutionBlock:((_ clientRecord:CKRecord,_ serverRecord:CKRecord)->CKRecord)?
    
    public static let SMStoreSyncConflictResolutionPolicyOption = "SMStoreSyncConflictResolutionPolicyOption"
    public static let SMStoreErrorDomain = "SMStoreErrorDomain"
 
    /**
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
    */
    public static let SMStoreContainerOption = "SMStoreContainerOption"
    
    static let SMStoreCloudStoreCustomZoneName = "SMStoreCloudStore_CustomZone"
    static let SMStoreCloudStoreSubscriptionName = "SM_CloudStore_Subscription"
    static let SMLocalStoreRecordIDAttributeName="sm_LocalStore_RecordID"
    static let SMLocalStoreRecordChangedPropertiesAttributeName = "sm_LocalStore_ChangedProperties"
    static let SMLocalStoreRecordEncodedValuesAttributeName = "sm_LocalStore_EncodedValues"
    static let SMLocalStoreChangeSetEntityName = "SM_LocalStore_ChangeSetEntity"
    
    
    
    fileprivate var syncOperation: SMStoreSyncOperation?
    fileprivate var cloudStoreSetupOperation: SMServerStoreSetupOperation?
    fileprivate var cksStoresSyncConflictPolicy: SMSyncConflictResolutionPolicy = SMSyncConflictResolutionPolicy.serverRecordWins
    fileprivate var database: CKDatabase?
    fileprivate var operationQueue: OperationQueue?
    fileprivate var backingPersistentStoreCoordinator: NSPersistentStoreCoordinator?
    fileprivate var backingPersistentStore: NSPersistentStore?
    fileprivate var ckContainer: CKContainer?
    
    fileprivate var automaticStoreMigration = false
    fileprivate var inferMappingModel = false
    
    fileprivate var cloudKitValid = false
    
    fileprivate lazy var backingMOC: NSManagedObjectContext = {
        var moc = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        moc.persistentStoreCoordinator = self.backingPersistentStoreCoordinator
        moc.retainsRegisteredObjects = true
        moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return moc     }()
    
    /// Initialize this store
    /// -SeeAlso: `NSIncrementalStore.initialize`
    override open class func initialize() {
        NSPersistentStoreCoordinator.registerStoreClass(self, forStoreType: self.type)
    }
    
    /// Returns a store initialized with the given arguments
    /// - parameter persistentStoreCoordinator: A persistent store coordinator
    /// - parameter configurationName: The name of the managed object model configuration to use. Pass nil if you do not want to specify a configuration.
    /// - parameter url: The URL of the store to load.
    /// - parameter options: A dictionary containing configuration options. See `NSPersistentStoreCoordinator` for a list of key names for options in this dictionary. `SMStoreSyncConflictResolutionPolicyOption` can also be specified in this dictionary.  `SMStoreContainerOption` can be used to specify a specific cloudkit container
    /// - returns: A new store object, associated with coordinator, that represents a persistent store at url using the options in options and—if it is not nil—the managed object model configuration configurationName.
    
    override init(persistentStoreCoordinator root: NSPersistentStoreCoordinator?, configurationName name: String?, at url: URL, options: [AnyHashable: Any]?) {
       
        if let opts = options {
            
            if let containerIdentifier = opts[SMStore.SMStoreContainerOption] as? String {
                self.ckContainer = CKContainer(identifier: containerIdentifier)
            }
            
            if let syncConflictPolicyRawValue = opts[SMStore.SMStoreSyncConflictResolutionPolicyOption] as? NSNumber {
                if let syncConflictPolicy = SMSyncConflictResolutionPolicy(rawValue: syncConflictPolicyRawValue.int16Value) {
                    self.cksStoresSyncConflictPolicy = syncConflictPolicy
                }
            }
            
            if let migrationPolicy = opts[NSMigratePersistentStoresAutomaticallyOption] as? Bool {
                self.automaticStoreMigration = migrationPolicy
            }
            
            if let inferMapping = opts[NSInferMappingModelAutomaticallyOption] as? Bool {
                self.inferMappingModel = inferMapping
            }
            
        }
        
        if self.ckContainer == nil {
            self.ckContainer = CKContainer.default()
        }
        
        print("Using container \(self.ckContainer!)")
        
        self.database = self.ckContainer!.privateCloudDatabase
        
        super.init(persistentStoreCoordinator: root, configurationName: name, at: url, options: options)
    }
    
    /// The type string of the receiver. (`SMStore`)
    
    class open var type:String {
        return NSStringFromClass(self)
    }
    
    
    /// Instructs the receiver to load its metadata.
    /// - returns: `true` if the metadata was loaded correctly, otherwise `false`.
    /// - throws: An `SMStoreError` if the backing store could not be created

    override open func loadMetadata() throws {
        self.metadata=[
            NSStoreUUIDKey: ProcessInfo().globallyUniqueString,
            NSStoreTypeKey: type(of: self).type
        ]
        
        try self.createBackingStore()
    }
    
    /// Reset the backing store.  This function should be called where the local store should be cleared prior to a re-sync from the cloud.  E.g. Where a change in CloudKit user has been identified.
    /// - throws: An `SMStoreError` if the backing store could not be reset
    public func resetBackingStore() throws {
       
        guard let backingMOM = self.backingModel() else {
            throw SMStoreError.backingStoreResetFailed
        }
        
        for entity in backingMOM.entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            try self.backingMOC.execute(deleteRequest)
            
        }
        
        
        let defaults = UserDefaults.standard
        
        defaults.set(false, forKey:SMStore.SMStoreCloudStoreCustomZoneName)
        
        defaults.set(false, forKey:SMStore.SMStoreCloudStoreSubscriptionName)
    }
    
    /// Verify that Cloud Kit is connected and return a connection status
    /// - SeeAlso: `verifyCloudKitConnectionAndUser(_)`
    /// - parameter completionHandler: A closure to be invoked with the result of the Cloud Kit operations
    /// - parameter status: The current Cloud Kit authentication status
    /// - parameter error: Any error that resulted from the operation

    
    @available(*,deprecated:1.0.7, message:"Use verifyCloudKitConnectionAndUser")
    open func verifyCloudKitConnection(_ completionHandler: ((_ status: CKAccountStatus, _ error: Error?) -> Void )?) -> Void {
        CKContainer.default().accountStatus { (status, error) in
            
            if status == CKAccountStatus.available {
                self.cloudKitValid = true
            } else {
                self.cloudKitValid = false
            }
            completionHandler?(status, error)
        }
    }
    
    /// Verify that Cloud Kit is connected and return a user identifier for the current Cloud 
    /// Kit user
    /// - parameter completionHandler: A closure to be invoked with the result of the Cloud Kit operations
    /// - parameter status: The current Cloud Kit authentication status
    /// - parameter userIdentifier: An identifier for the current Cloud Kit user.  
    ///   Note that this is not a userid or email address, merely a unique identifier
    /// - parameter error: Any error that resulted from the operation
    
    open func verifyCloudKitConnectionAndUser(_ completionHandler: ((_ status: CKAccountStatus, _ userIdentifier: String?, _ error: Error?) -> Void )?) -> Void {
        guard let container = self.ckContainer else {
            completionHandler?(CKAccountStatus.couldNotDetermine ,nil,SMStoreError.invalidRequest)
            return
        }
        container.accountStatus { (status, error) in
            
            if status == CKAccountStatus.available {
                self.cloudKitValid = true
            } else {
                self.cloudKitValid = false
            }
            if error != nil  {
                completionHandler?(status, nil, error)
            } else {
                container.fetchUserRecordID { (recordid, error) in
                    completionHandler?(status, recordid?.recordName, error)
                }
            }
        }
    }
    
    /// Trigger a sync operation.  
    /// - parameter complete: If `true` then all records are retrieved from Cloud Kit.  If `false` then only changes since the last sync are fetched
    
    open func triggerSync(complete: Bool = false) {
        
        guard self.cloudKitValid else {
            NSLog("Access to CloudKit has not been verified by calling verifyCloudKitConnection")
            return
        }
        
        guard self.operationQueue?.operationCount == 0 else {
            return
        }
        
        if complete {
            SMServerTokenHandler.defaultHandler.delete()
        }
        
        let syncOperationBlock = {
            self.syncOperation = SMStoreSyncOperation(persistentStoreCoordinator: self.backingPersistentStoreCoordinator, entitiesToSync: self.entitiesToParticipateInSync()!, conflictPolicy: self.cksStoresSyncConflictPolicy, database: self.database)
            self.syncOperation!.syncConflictResolutionBlock = self.recordConflictResolutionBlock
    
            self.syncOperation!.syncCompletionBlock =  { error in
                if let error = error {
                    print("Sync unsuccessful \(error)")
                    OperationQueue.main.addOperation {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: SMStoreNotification.SyncDidFinish), object: self, userInfo: error.userInfo)
                    }
                } else {
                    print("Sync performed successfully")
                    OperationQueue.main.addOperation {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: SMStoreNotification.SyncDidFinish), object: self)
                    }
                }
            }
            self.operationQueue?.addOperation(self.syncOperation!)
        }
        
        let defaults = UserDefaults.standard
        
        if defaults.bool(forKey: SMStore.SMStoreCloudStoreCustomZoneName) == false || defaults.bool(forKey: SMStore.SMStoreCloudStoreSubscriptionName) == false {
            
            self.cloudStoreSetupOperation = SMServerStoreSetupOperation(cloudDatabase: self.database)
            self.cloudStoreSetupOperation!.setupOperationCompletionBlock = { customZoneWasCreated, customZoneSubscriptionWasCreated in
                syncOperationBlock()
            }
            self.operationQueue?.addOperation(self.cloudStoreSetupOperation!)
        } else {
            syncOperationBlock()
        }
        NotificationCenter.default.post(name: Notification.Name(rawValue: SMStoreNotification.SyncDidStart), object: self)
    }
    
    /// Handle a push notification that indicates records have been updated in Cloud Kit
    /// - parameter userInfo: The userInfo dictionary from the push notification
    
    open func handlePush(userInfo:[AnyHashable: Any]) {
        let u = userInfo as! [String : NSObject]
        let ckNotification = CKNotification(fromRemoteNotificationDictionary: u)
        if ckNotification.notificationType == CKNotificationType.recordZone {
            let recordZoneNotification = CKRecordZoneNotification(fromRemoteNotificationDictionary: u)
            if let zoneID = recordZoneNotification.recordZoneID {
                if zoneID.zoneName == SMStore.SMStoreCloudStoreCustomZoneName {
                    self.triggerSync()
                }
            }
        }
    }
    
    func createBackingStore() throws {
        let storeURL=self.url
        guard let backingMOM = self.backingModel() else {
            throw SMStoreError.backingStoreCreationFailed
        }
        self.backingPersistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: backingMOM)
        do {
            
            let options = [NSMigratePersistentStoresAutomaticallyOption: self.automaticStoreMigration, NSInferMappingModelAutomaticallyOption: self.inferMappingModel]
            
            self.backingPersistentStore = try self.backingPersistentStoreCoordinator?.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
            self.operationQueue = OperationQueue()
            self.operationQueue!.maxConcurrentOperationCount = 1
        } catch {
            throw SMStoreError.backingStoreCreationFailed
        }
        return
    }
    
    func backingModel() -> NSManagedObjectModel? {
        if let persistentStoreModel = self.persistentStoreCoordinator?.managedObjectModel {
            let backingModel: NSManagedObjectModel = SMStoreChangeSetHandler.defaultHandler.modelForLocalStore(usingModel: persistentStoreModel)
            return backingModel
        }
        return nil
    }
    
    func entitiesToParticipateInSync() -> [NSEntityDescription]? {
        let syncEntities =  self.backingMOC.persistentStoreCoordinator?.managedObjectModel.entities.filter { object in
            let entity: NSEntityDescription = object
            return (entity.name)! != SMStore.SMLocalStoreChangeSetEntityName
        }
        
        return syncEntities
    }
    
    
    override open func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
        if request.requestType == NSPersistentStoreRequestType.fetchRequestType {
            let fetchRequest = request as! NSFetchRequest<NSFetchRequestResult>
            return try self.executeInResponseToFetchRequest(fetchRequest, context: context!)
        } else if request.requestType == NSPersistentStoreRequestType.saveRequestType {
            let saveChangesRequest: NSSaveChangesRequest = request as! NSSaveChangesRequest
            return try self.executeInResponseToSaveChangesRequest(saveChangesRequest, context: context!)
        } else {
            throw NSError(domain: SMStore.SMStoreErrorDomain, code: SMStoreError.invalidRequest._code, userInfo: nil)
        }
    }
    
    override open func newValuesForObject(with objectID: NSManagedObjectID, with context: NSManagedObjectContext) throws -> NSIncrementalStoreNode {
        let recordID:String = self.referenceObject(for: objectID) as! String
        let propertiesToFetch = Array(objectID.entity.propertiesByName.values).filter { object  in
            if let relationshipDescription = object as? NSRelationshipDescription {
                return relationshipDescription.isToMany == false
            }
            return true
            }.map {
                return $0.name
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: objectID.entity.name!)
        let predicate = NSPredicate(format: "%K == %@", SMStore.SMLocalStoreRecordIDAttributeName,recordID)
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = predicate
        fetchRequest.resultType = NSFetchRequestResultType.dictionaryResultType
        fetchRequest.propertiesToFetch = propertiesToFetch
        let results = try self.backingMOC.fetch(fetchRequest)
        var backingObjectValues = results.last as! Dictionary<String,NSObject>
        for (key,value) in backingObjectValues {
            if let managedObjectID = value as? NSManagedObjectID {
                let managedObject = try self.backingMOC.existingObject(with: managedObjectID)
                if let identifier = managedObject.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as? String {
                    let objID = self.newObjectID(for: managedObject.entity, referenceObject:identifier)
                    backingObjectValues[key] = objID
                }
            }
        }
        let incrementalStoreNode = NSIncrementalStoreNode(objectID: objectID, withValues: backingObjectValues, version: 1)
        return incrementalStoreNode
        
    }
    
    override open func newValue(forRelationship relationship: NSRelationshipDescription, forObjectWith objectID: NSManagedObjectID, with context: NSManagedObjectContext?) throws -> Any {
        
        var toOneRelationship = relationship
        
        if relationship.isToMany {
            guard let targetRelationship = relationship.inverseRelationship else {
                throw SMStoreError.missingInverseRelationship
            }
            toOneRelationship = targetRelationship
        }
        
        guard toOneRelationship.isToMany == false else {
            throw SMStoreError.manyToManyUnsupported
        }
        
        let recordID:String = self.referenceObject(for: objectID) as! String
        
        if let targetObjectID = try self.objectIDForBackingObjectForEntity(objectID.entity.name!, withReferenceObject: recordID) {
            
            let targetsFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: toOneRelationship.entity.name!)
            let targetsPredicate = NSPredicate(format: "%K == %@", toOneRelationship.name,targetObjectID)
            targetsFetchRequest.predicate = targetsPredicate
            targetsFetchRequest.resultType = .managedObjectResultType
            targetsFetchRequest.propertiesToFetch = [SMStore.SMLocalStoreRecordIDAttributeName]
            if let targetResults = try self.backingMOC.fetch(targetsFetchRequest) as? [NSManagedObject] {
                if !targetResults.isEmpty {
                    let retValues = targetResults.map {
                        let reference = $0.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName)
                        return self.newObjectID(for: toOneRelationship.entity, referenceObject: reference as Any)
                        
                        } as [NSManagedObjectID]
                    return retValues
                }
            }
        }
        if toOneRelationship.isOptional {
            return NSNull()
        } else {
            throw SMStoreError.missingRelatedObject
        }
    }

    override open func obtainPermanentIDs(for array: [NSManagedObject]) throws -> [NSManagedObjectID] {
        return array.map { object in
            let insertedObject:NSManagedObject = object as NSManagedObject
            let newRecordID: String = UUID().uuidString
            return self.newObjectID(for: insertedObject.entity, referenceObject: newRecordID)
        }
    }
    
    // MARK : Fetch Request
    func executeInResponseToFetchRequest(_ fetchRequest:NSFetchRequest<NSFetchRequestResult>,context:NSManagedObjectContext) throws ->[NSManagedObject] {
        let resultsFromLocalStore = try self.backingMOC.fetch(fetchRequest)
        if !resultsFromLocalStore.isEmpty {
            return resultsFromLocalStore.map({(result)->NSManagedObject in
                let result = result as! NSManagedObject
                let recordID: String = result.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as! String
                let entity = self.persistentStoreCoordinator?.managedObjectModel.entitiesByName[fetchRequest.entityName!]
                let objectID = self.newObjectID(for: entity!, referenceObject: recordID)
                let object = context.object(with: objectID)
                return object
            })
        }
        return []
    }
    
    // MARK : SaveChanges Request
    fileprivate func executeInResponseToSaveChangesRequest(_ saveRequest:NSSaveChangesRequest,context:NSManagedObjectContext) throws -> Array<AnyObject> {
        
        try self.deleteObjectsFromBackingStore(objectsToDelete: context.deletedObjects, mainContext: context)
        try self.insertObjectsInBackingStore(objectsToInsert: context.insertedObjects, mainContext: context)
        try self.updateObjectsInBackingStore(objectsToUpdate: context.updatedObjects)
        
        try self.backingMOC.saveIfHasChanges()
        print("Saved")
        self.triggerSync()
        return []
    }
    
    func objectIDForBackingObjectForEntity(_ entityName: String, withReferenceObject referenceObject: String?) throws -> NSManagedObjectID? {
        if referenceObject == nil {
            return nil
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.resultType = NSFetchRequestResultType.managedObjectIDResultType
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "%K == %@", SMStore.SMLocalStoreRecordIDAttributeName,referenceObject!)
        let results = try self.backingMOC.fetch(fetchRequest)
        if !results.isEmpty {
            return results.last as? NSManagedObjectID
        }
        return nil
    }
    
    fileprivate func setRelationshipValuesForBackingObject(_ backingObject:NSManagedObject,sourceObject:NSManagedObject) throws -> Void {
        for relationship in Array(sourceObject.entity.relationshipsByName.values) as [NSRelationshipDescription] {
            if sourceObject.hasFault(forRelationshipNamed: relationship.name) || sourceObject.value(forKey: relationship.name) == nil {
                continue
            }
            if relationship.isToMany  {
                let relationshipValue: Set<NSObject> = sourceObject.value(forKey: relationship.name) as! Set<NSObject>
                var backingRelationshipValue: Set<NSObject> = Set<NSObject>()
                for relationshipObject in relationshipValue {
                    let relationshipManagedObject: NSManagedObject = relationshipObject as! NSManagedObject
                    if relationshipManagedObject.objectID.isTemporaryID == false {
                        let referenceObject: String = self.referenceObject(for: relationshipManagedObject.objectID) as! String
                        let backingRelationshipObjectID = try self.objectIDForBackingObjectForEntity(relationship.destinationEntity!.name!, withReferenceObject: referenceObject)
                        if backingRelationshipObjectID != nil {
                            let backingRelationshipObject = try backingObject.managedObjectContext?.existingObject(with: backingRelationshipObjectID!)
                            backingRelationshipValue.insert(backingRelationshipObject!)
                        }
                    }
                }
                backingObject.setValue(backingRelationshipValue, forKey: relationship.name)
            } else {
                let relationshipValue: NSManagedObject = sourceObject.value(forKey: relationship.name) as! NSManagedObject
                if relationshipValue.objectID.isTemporaryID == false {
                    let referenceObject: String = self.referenceObject(for: relationshipValue.objectID) as! String
                    let backingRelationshipObjectID = try self.objectIDForBackingObjectForEntity(relationship.destinationEntity!.name!, withReferenceObject: referenceObject)
                    if backingRelationshipObjectID != nil {
                        let backingRelationshipObject = try self.backingMOC.existingObject(with: backingRelationshipObjectID!)
                        backingObject.setValue(backingRelationshipObject, forKey: relationship.name)
                    }
                }
            }
        }
    }
    
    func insertObjectsInBackingStore(objectsToInsert objects:Set<NSObject>, mainContext: NSManagedObjectContext) throws -> Void {
        for object in objects {
            let sourceObject: NSManagedObject = object as! NSManagedObject
            let managedObject:NSManagedObject = NSEntityDescription.insertNewObject(forEntityName: (sourceObject.entity.name)!, into: self.backingMOC) as NSManagedObject
            let keys = Array(sourceObject.entity.attributesByName.keys)
            let dictionary = sourceObject.dictionaryWithValues(forKeys: keys)
            managedObject.setValuesForKeys(dictionary)
            let referenceObject: String = self.referenceObject(for: sourceObject.objectID) as! String
            managedObject.setValue(referenceObject, forKey: SMStore.SMLocalStoreRecordIDAttributeName)
            mainContext.willChangeValue(forKey: "objectID")
            try mainContext.obtainPermanentIDs(for: [sourceObject])
            mainContext.didChangeValue(forKey: "objectID")
            SMStoreChangeSetHandler.defaultHandler.createChangeSet(ForInsertedObjectRecordID: referenceObject, entityName: sourceObject.entity.name!, backingContext: self.backingMOC)
            try self.setRelationshipValuesForBackingObject(managedObject, sourceObject: sourceObject)
            try self.backingMOC.saveIfHasChanges()
        }
    }
    
    fileprivate func deleteObjectsFromBackingStore(objectsToDelete objects: Set<NSObject>, mainContext: NSManagedObjectContext) throws -> Void {
        let predicateObjectRecordIDKey = "objectRecordID"
        let predicate: NSPredicate = NSPredicate(format: "%K == $objectRecordID", SMStore.SMLocalStoreRecordIDAttributeName)
        for object in objects {
            let sourceObject: NSManagedObject = object as! NSManagedObject
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: sourceObject.entity.name!)
            let recordID: String = self.referenceObject(for: sourceObject.objectID) as! String
            fetchRequest.predicate = predicate.withSubstitutionVariables([predicateObjectRecordIDKey: recordID])
            fetchRequest.fetchLimit = 1
            let results = try self.backingMOC.fetch(fetchRequest)
            let backingObject: NSManagedObject = results.last as! NSManagedObject
            SMStoreChangeSetHandler.defaultHandler.createChangeSet(ForDeletedObjectRecordID: recordID, backingContext: self.backingMOC)
            self.backingMOC.delete(backingObject)
            try self.backingMOC.saveIfHasChanges()
        }
    }
    
    fileprivate func updateObjectsInBackingStore(objectsToUpdate objects: Set<NSObject>) throws -> Void {
        let predicateObjectRecordIDKey = "objectRecordID"
        let predicate: NSPredicate = NSPredicate(format: "%K == $objectRecordID", SMStore.SMLocalStoreRecordIDAttributeName)
        for object in objects {
            let sourceObject: NSManagedObject = object as! NSManagedObject
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: sourceObject.entity.name!)
            let recordID: String = self.referenceObject(for: sourceObject.objectID) as! String
            fetchRequest.predicate = predicate.withSubstitutionVariables([predicateObjectRecordIDKey:recordID])
            fetchRequest.fetchLimit = 1
            let results = try self.backingMOC.fetch(fetchRequest)
            let backingObject: NSManagedObject = results.last as! NSManagedObject
            let keys = Array(self.persistentStoreCoordinator!.managedObjectModel.entitiesByName[sourceObject.entity.name!]!.attributesByName.keys)
            let sourceObjectValues = sourceObject.dictionaryWithValues(forKeys: keys)
            backingObject.setValuesForKeys(sourceObjectValues)
            SMStoreChangeSetHandler.defaultHandler.createChangeSet(ForUpdatedObject: backingObject, usingContext: self.backingMOC)
            try self.setRelationshipValuesForBackingObject(backingObject, sourceObject: sourceObject)
            try self.backingMOC.saveIfHasChanges()
        }
    }
}
