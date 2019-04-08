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
 | To - many    | To many relationships are not explicitly created. Seam3 only creates and manages to-one relationships on the CloudKit Servers. <br/> <strong>Example</strong> -> If an Employee has a to-one relationship to Department and Department has a to-many relationship to Employee than Seam3 will only create the former on the CloudKit Servers. It will fullfil the later by using the to-one relationship. If all employees of a department are accessed Seam3 will fulfil it by fetching all the employees that belong to that particular department.|
 
 <strong>Note :</strong> You must create inverse relationships in your app's CoreData Model or Seam3 wouldn't be able to translate CoreData Models in to CloudKit Records. Unexpected errors and corruption of data can possibly occur.
 
 ## Sync
 
 Seam3 keeps the CoreData store in sync with the CloudKit Servers. It let's you know when the sync operation starts and finishes by throwing the following two notifications.
 - SMStoreDidStartSyncOperationNotification
 - SMStoreDidFinishSyncOperationNotification
 
 If an error occurred during the sync operation, then the `userInfo` property of the `SMStoreDidFinishSyncOperationNotification` notification will contain an `Error` object for the key `SMStore.SMStoreErrorDomain`
 
 #### Resolution Policies
 In case of any sync conflicts, Seam3 exposes 4 conflict resolution policies.
 
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
 - For iOS9 and earlier, add a store type of `SMStore.type` to your app's NSPersistentStoreCoordinator and assign it to the property created in the previous step.
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
import os.log


public struct SMStoreNotification {
    public static let SyncDidStart = "SMStoreDidStartSyncOperationNotification"
    public static let SyncDidFinish = "SMStoreDidFinishSyncOperationNotification"
    public static let SyncOperationError = "SMStoreSyncOperationError"
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
    /// More than one match was found for a 'to-one' relationship
    case tooManyRelatedObjects
    /// Missing/bad backing store record
    case backingStoreRecordInvalid
}

/// Error description key for `userinfo` dictionary on an `SMStoreError` error
public  let SMStoreErrorDescription = "SMStore_error_description"

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
    // MARK:- Public properties
    
    /// Default value of `syncAutomatically` assigned to new `SMStore` instances.
    /// Defaults to `true`
    public static var syncAutomatically: Bool = true
    weak public static var logger: SMLogDelegate? = SMLogger.sharedInstance
    
    /// If true, a sync is triggered automatically when a save operation is performed against the store. Defaults to `true`
    @objc public var syncAutomatically: Bool = SMStore.syncAutomatically
    
    public typealias SMStoreConflictResolutionBlock = (_ serverRecord:CKRecord,_ clientRecord:CKRecord, _ ancestorRecord:CKRecord )->CKRecord
    
    /// The closure that will be invoked to resolve sync conflicts when the `SMStoreSyncConflictResolutionPolicyOption` is set to `clientTellsWhichWins`
    /// - parameter clientRecord:   a `CKRecord` representing the client record state
    /// - parameter serverRecord:   a `CKRecord` representing the server (cloud) record state
    /// - returns: The record that will be saved to both the client and cloud
    @objc public var recordConflictResolutionBlock: SMStoreConflictResolutionBlock?
    
    @objc public static let SMStoreSyncConflictResolutionPolicyOption = "SMStoreSyncConflictResolutionPolicyOption"
    @objc public static let SMStoreErrorDomain = "SMStoreErrorDomain"
    
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
    
    // MARK:- Constants
    
    public static let SMStoreContainerOption = "SMStoreContainerOption"
    
    static let SMStoreCloudStoreCustomZoneName = "SMStoreCloudStore_CustomZone"
    static let SMStoreCloudStoreSubscriptionName = "SM_CloudStore_Subscription"
    static let SMLocalStoreRecordIDAttributeName="sm_LocalStore_RecordID"
    static let SMLocalStoreRecordChangedPropertiesAttributeName = "sm_LocalStore_ChangedProperties"
    static let SMLocalStoreRecordEncodedValuesAttributeName = "sm_LocalStore_EncodedValues"
    static let SMLocalStoreChangeSetEntityName = "SM_LocalStore_ChangeSetEntity"
    
    // MARK:- Private properties
    
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
        return moc
    }()
    
    fileprivate lazy var localStoreMOC: NSManagedObjectContext = {
        var moc = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        moc.persistentStoreCoordinator = self.persistentStoreCoordinator
        moc.retainsRegisteredObjects = true
        moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return moc
    }()
    
    fileprivate static var storeRegistered = false
    
    // MARK:- Public methods
    
    /// Initialize this store
    /// -SeeAlso: `NSIncrementalStore.initialize`
    /*  override open class func initialize() {
     NSPersistentStoreCoordinator.registerStoreClass(self, forStoreType: self.type)
     }*/
    
    /**
     You must call this function to register the SMStore class before attempting
     to create a store
     */
    
    @objc public class func registerStoreClass() {
        if !storeRegistered {
            NSPersistentStoreCoordinator.registerStoreClass(self, forStoreType: self.type)
            storeRegistered = true
        }
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
        
        self.database = self.ckContainer!.privateCloudDatabase
        
        super.init(persistentStoreCoordinator: root, configurationName: name, at: url, options: options)
    }
    
    /// The type string of the receiver. (`SMStore`)
    
    @objc class open var type:String {
        return NSStringFromClass(self)
    }
    
    
    /// Instructs the receiver to load its metadata.
    /// - returns: `true` if the metadata was loaded correctly, otherwise `false`.
    /// - throws: An `SMStoreError` if the backing store could not be created
    
    override open func loadMetadata() throws {
        self.metadata=[
            NSStoreUUIDKey: "A9909604-1EF0-4049-BD7F-2CF6AE3D3A6D",
            NSStoreTypeKey: Swift.type(of: self).type
        ]
        
        try self.createBackingStore()
    }
    
    /// Reset the backing store.  This function should be called where the local store should be cleared prior to a re-sync from the cloud.  E.g. Where a change in CloudKit user has been identified.
    /// - throws: An `SMStoreError` if the backing store could not be reset
    @objc public func resetBackingStore() throws {
        
        guard let backingMOM = self.backingModel() else {
            throw SMStoreError.backingStoreResetFailed
        }
        
        for entity in backingMOM.entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            var executeError: Error?
            self.backingMOC.performAndWait {
                do {
                    try self.backingMOC.execute(deleteRequest)
                } catch {
                    executeError = error
                }
            }

            if let error = executeError {
                throw error
            }
        }
        
        let defaults = UserDefaults.standard
        
        defaults.set(false, forKey:SMStore.SMStoreCloudStoreCustomZoneName)
        
        defaults.set(false, forKey:SMStore.SMStoreCloudStoreSubscriptionName)
    }
    
    /// Marks all local data for resending to the cloud as new objects. For use with a new user or when the custom Zone was deleted.
    @objc public func resetCloudFieldsInBackingStore() throws {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey:SMStore.SMStoreCloudStoreCustomZoneName)
        defaults.set(false, forKey:SMStore.SMStoreCloudStoreSubscriptionName)
        defaults.synchronize()
        
        self.backingMOC.performAndWait {
            do {
                for entity in entitiesToParticipateInSync() ?? [] {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entity.name!)
                    fetchRequest.predicate = NSPredicate(format: "\(SMStore.SMLocalStoreRecordEncodedValuesAttributeName) != null")
                    let records = try self.backingMOC.fetch(fetchRequest)
                    for record in records {
                        // clear CloudKit encoded values
                        record.setValue(nil, forKey: SMStore.SMLocalStoreRecordEncodedValuesAttributeName)
                    }
                }
                try self.backingMOC.saveIfHasChanges()

                for entity in entitiesToParticipateInSync() ?? [] {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entity.name!)
                    let records = try self.localStoreMOC.fetch(fetchRequest)
                    for record in records {
                        // touch the record data
                        if let key = entity.attributesByNameByRemovingBackingStoreAttributes().keys.first {
                            let value = record.value(forKey: key)
                            record.setValue(value, forKey: key)
                        }
                    }
                }
                try self.localStoreMOC.saveIfHasChanges()
                
            } catch {
                SMStore.logger?.error("Failed to reset cloud fields in backing store: \(error.localizedDescription)")
            }
        }
    }

    
    /// Retrieve an `NSPredicate` that will match the supplied `NSManagedObject`.
    /// - parameter for: The name of the relationship that holds the reference to the target object
    /// - parameter object: The related `NSManagedObject` to search for
    /// - returns: An `NSPredicate` that will retrieve the supplied object or nil if a related object cannot be found.
    
    public func predicate(for relationship: String, referencing object: NSManagedObject) -> NSPredicate? {
        guard let recordID = self.referenceObject(for: object.objectID) as? String else {
            return nil
        }
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: object.entity.name!)
        let predicate = NSPredicate(format: "%K == %@", SMStore.SMLocalStoreRecordIDAttributeName,recordID)
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = predicate
        fetchRequest.resultType = NSFetchRequestResultType.managedObjectResultType
        var resultPredicate: NSPredicate?
        self.backingMOC.performAndWait {
            if let result = (try? self.backingMOC.fetch(fetchRequest) as? [NSManagedObject])??.first {
                resultPredicate = NSPredicate(format: "%K == %@", relationship,result)
            }
        }
        return resultPredicate
    }
    
    /// Retrieve an `NSPredicate` that will match the supplied `NSManagedObject` in a to-many.
    /// - parameter forToMany: The name of the to-many relationship that holds the reference to the target object
    /// - parameter object: The related `NSManagedObject` to search for
    /// - returns: An `NSPredicate` that will retrieve the supplied object from a to-many relationship or nil if the target object could not be located.
    
    public func predicate(forToMany relationship: String, referencing object: NSManagedObject) -> NSPredicate? {
        
        guard let recordID = self.referenceObject(for: object.objectID) as? String else {
            return nil
        }
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: object.entity.name!)
        let predicate = NSPredicate(format: "%K == %@", SMStore.SMLocalStoreRecordIDAttributeName,recordID)
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = predicate
        fetchRequest.resultType = NSFetchRequestResultType.managedObjectResultType
        do {
            if let results = try self.backingMOC.fetch(fetchRequest) as? [NSManagedObject]  {
                if let result = results.first {
                    let predicate: NSPredicate = NSPredicate(format: "%K CONTAINS %@", relationship,result)
                    
                    return predicate
                }
            }
        } catch {
            
        }
        return nil
    }
    
    /// Verify that Cloud Kit is connected and return a connection status
    /// - SeeAlso: `verifyCloudKitConnectionAndUser(_)`
    /// - parameter completionHandler: A closure to be invoked with the result of the Cloud Kit operations
    /// - parameter status: The current Cloud Kit authentication status
    /// - parameter error: Any error that resulted from the operation
    
    
    @available(swift,deprecated:1.0.7, message:"Use verifyCloudKitConnectionAndUser")
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
    
    @objc open func verifyCloudKitConnectionAndUser(_ completionHandler: ((_ status: CKAccountStatus, _ userIdentifier: String?, _ error: Error?) -> Void )?) -> Void {
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
    
    open func verifyCloudKitStoreExists(_ completionHandler: ((_ exists: Bool, _ error: Error?) -> Void)?) {
        guard self.cloudKitValid else {
            SMStore.logger?.error("Access to CloudKit has not been verified by calling verifyCloudKitConnection")
            return
        }
        let operation = SMServerZoneLookupOperation(cloudDatabase: database)
        operation.lookupOperationCompletionBlock = completionHandler
        let queue = OperationQueue()
        queue.addOperation(operation)
    }
    
    /// Trigger a sync operation.
    /// - parameter complete: If `true` then all records are retrieved from Cloud Kit.  If `false` then only changes since the last sync are fetched
    
    /*open func triggerSync(complete: Bool = false, fetchCompletionHandler completion: ((Error?)->Void)? = nil) {
     self.triggerSync(block: false, complete: complete, fetchCompletionHandler: nil)
     }*/
    
    @objc open func triggerSync(complete: Bool = false, fetchCompletionHandler completion: ((FetchResult, Error?)->Void)? = nil) {
        guard self.cloudKitValid else {
            SMStore.logger?.error("Access to CloudKit has not been verified by calling verifyCloudKitConnection")
            return
        }
        
        if UserDefaults.standard.bool(forKey: SMStore.SMStoreCloudStoreCustomZoneName) == false ||
            UserDefaults.standard.bool(forKey: SMStore.SMStoreCloudStoreSubscriptionName) == false {
            SMServerTokenHandler.defaultHandler.delete()
        }
        
        if complete {
            SMServerTokenHandler.defaultHandler.delete()
        }
        
        let syncOperationBlock: (_ error: Error?) -> Void = { error in
            
            if let error = error {
                SMStore.logger?.error("Sync failed \(error.localizedDescription)")
                OperationQueue.main.addOperation {
                    NotificationCenter.default.post(name: Notification.Name(rawValue: SMStoreNotification.SyncDidFinish), object: self, userInfo: [SMStore.SMStoreErrorDomain:error])
                }
                completion?(.failed, error)
            } else {
                
                self.syncOperation = SMStoreSyncOperation(persistentStoreCoordinator: self.backingPersistentStoreCoordinator, entitiesToSync: self.entitiesToParticipateInSync()!, conflictPolicy: self.cksStoresSyncConflictPolicy, database: self.database, backingMOC: self.backingMOC)
                
                self.syncOperation!.syncConflictResolutionBlock = self.recordConflictResolutionBlock
                
                self.syncOperation!.syncCompletionBlock =  { result, error in
                    if let error = error {
                        SMStore.logger?.error("Sync failed \(error)")
                        OperationQueue.main.addOperation {
                            NotificationCenter.default.post(name: Notification.Name(rawValue: SMStoreNotification.SyncDidFinish), object: self, userInfo: [SMStore.SMStoreErrorDomain:error])
                        }
                    } else {
                        SMStore.logger?.info("Sync completed successfully")
                        OperationQueue.main.addOperation {
                            NotificationCenter.default.post(name: Notification.Name(rawValue: SMStoreNotification.SyncDidFinish), object: self)
                        }
                    }
                    completion?(result, error)
                }
                self.operationQueue?.addOperation(self.syncOperation!)
            }
        }
        
        let defaults = UserDefaults.standard
        
        if defaults.bool(forKey: SMStore.SMStoreCloudStoreCustomZoneName) == false || defaults.bool(forKey: SMStore.SMStoreCloudStoreSubscriptionName) == false {
            
            self.cloudStoreSetupOperation = SMServerStoreSetupOperation(cloudDatabase: self.database)
            self.cloudStoreSetupOperation!.setupOperationCompletionBlock = { customZoneWasCreated, customZoneSubscriptionWasCreated, error in
                if let error = error {
                    SMStore.logger?.error("Error setting up cloudkit: \(error.localizedDescription)")
                    syncOperationBlock(error)
                } else {
                    syncOperationBlock(nil)
                }
            }
            self.operationQueue?.addOperation(self.cloudStoreSetupOperation!)
        } else {
            syncOperationBlock(nil)
        }
        NotificationCenter.default.post(name: Notification.Name(rawValue: SMStoreNotification.SyncDidStart), object: self)
    }
    
    /// Handle a push notification that indicates records have been updated in Cloud Kit
    /// - parameter userInfo: The userInfo dictionary from the push notification
    
    @objc open func handlePush(userInfo:[AnyHashable: Any], fetchCompletionHandler completionHandler: ((FetchResult) -> Void)?=nil) {
        let u = userInfo as! [String : NSObject]
        let ckNotification = CKNotification(fromRemoteNotificationDictionary: u)
        if ckNotification?.notificationType == CKNotification.NotificationType.recordZone {
            let recordZoneNotification = CKRecordZoneNotification(fromRemoteNotificationDictionary: u)
            if let zoneID = recordZoneNotification?.recordZoneID {
                if zoneID.zoneName == SMStore.SMStoreCloudStoreCustomZoneName {
                    //self.triggerSync(block: true)
                    self.triggerSync(complete: false) { (result, error) in
                        if error != nil {
                            completionHandler?(.failed)
                        } else {
                            completionHandler?(result)
                        }
                    }
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
    
    override open func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
        var executeError: Error?
        var result: Any?
        let executeBlock = {
            do {
                switch request.requestType {
                case .fetchRequestType:
                    guard let fetchRequest = request as? NSFetchRequest<NSFetchRequestResult> else {
                        throw NSError(domain: SMStore.SMStoreErrorDomain, code: SMStoreError.invalidRequest._code, userInfo: nil)
                    }
                    if fetchRequest.resultType == .countResultType {
                        result = try self.executeInResponseToCountFetchRequest(fetchRequest, context: context!)
                    } else {
                        result = try self.executeInResponseToFetchRequest(fetchRequest, context: context!)
                    }
                case .saveRequestType:
                    guard let saveChangesRequest: NSSaveChangesRequest = request as? NSSaveChangesRequest else {
                        throw NSError(domain: SMStore.SMStoreErrorDomain, code: SMStoreError.invalidRequest._code, userInfo: nil)
                    }
                    result = try self.executeInResponseToSaveChangesRequest(saveChangesRequest, context: context!)
                    
                case .batchDeleteRequestType:
                    guard let batchDeleteRequest: NSBatchDeleteRequest = request as? NSBatchDeleteRequest else {
                        throw  NSError(domain: SMStore.SMStoreErrorDomain, code: SMStoreError.invalidRequest._code, userInfo: nil)
                    }
                    result = try self.executeInResponseToBatchDeleteRequest(batchDeleteRequest, context: context!)
                    
                case .batchUpdateRequestType:
                    throw NSError(domain: SMStore.SMStoreErrorDomain, code: SMStoreError.invalidRequest._code, userInfo: nil)
                @unknown default:
                    break
                }
            } catch {
                executeError = error
            }
        }
        
        // Under some circumstances CoreData may call execute() with .mainQueueConcurrencyType, where 'performAndWait' cannot be used
        if let concurrencyType = context?.concurrencyType, concurrencyType == .privateQueueConcurrencyType {
            context!.performAndWait(executeBlock)
        } else {
            executeBlock()
        }
        
        
        if let error = executeError {
            throw error
        }
        return result!
    }
    
    override open func newValuesForObject(with objectID: NSManagedObjectID, with context: NSManagedObjectContext) throws -> NSIncrementalStoreNode {
        
        let targetEntities = context.persistentStoreCoordinator!.managedObjectModel.entitiesByName
        
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
        
        var fetchError: Error?
        var incrementalStoreNode = NSIncrementalStoreNode(objectID: objectID, withValues: [:], version: 1)
        self.backingMOC.performAndWait {
            do {
                let results = try self.backingMOC.fetch(fetchRequest)
                if var backingObjectValues = results.last as? Dictionary<String,NSObject> {
                    for (key,value) in backingObjectValues {
                        if let managedObjectID = value as? NSManagedObjectID {
                            let managedObject = try self.backingMOC.existingObject(with: managedObjectID)
                            if let identifier = managedObject.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as? String {
                                if let targetEntity = targetEntities[managedObject.entity.name!] {
                                    let objID = self.newObjectID(for: targetEntity, referenceObject:identifier)
                                    
                                    backingObjectValues[key] = objID
                                }
                            }
                        }
                    }
                    
                    incrementalStoreNode = NSIncrementalStoreNode(objectID: objectID, withValues: backingObjectValues, version: 1)
                }
            } catch {
                fetchError = error
            }
        }
        
        if let error = fetchError {
            throw error
        }
        return incrementalStoreNode
    }
    
    override open func newValue(forRelationship relationship: NSRelationshipDescription, forObjectWith objectID: NSManagedObjectID, with context: NSManagedObjectContext?) throws -> Any {
        var result: Any?
        var executeError: Error?
        let executeBlock = {
            do {
                if relationship.isToMany {
                    guard let targetRelationship = relationship.inverseRelationship else {
                        throw SMStoreError.missingInverseRelationship
                    }
                    guard targetRelationship.isToMany == false else {
                        throw SMStoreError.manyToManyUnsupported
                    }
                    
                    result = try self.toManyValues(forRelationship: targetRelationship, forObjectWith: objectID, with: context)
                } else {
                    result = try self.toOneValue(forRelationship: relationship, forObjectWith: objectID, with: context)
                }
            } catch {
                executeError = error
            }
        }
        
        // CoreData may call execute() with .mainQueueConcurrencyType
        // ...in these circumstances, 'performAndWait' cannot be used
        if let concurrencyType = context?.concurrencyType, concurrencyType == .privateQueueConcurrencyType {
            context!.performAndWait(executeBlock)
        } else {
            executeBlock()
        }
        
        
        if let error = executeError {
            throw error
        }
        return result!
    }
    
    fileprivate func toOneValue(forRelationship relationship: NSRelationshipDescription, forObjectWith objectID: NSManagedObjectID, with context: NSManagedObjectContext?) throws -> Any {
        
        let recordID:String = self.referenceObject(for: objectID) as! String
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: objectID.entity.name!)
        let predicate = NSPredicate(format: "%K == %@", SMStore.SMLocalStoreRecordIDAttributeName,recordID)
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = predicate
        fetchRequest.resultType = NSFetchRequestResultType.dictionaryResultType
        let results = try self.backingMOC.fetch(fetchRequest)
        
        if let result = results.last as? [String:NSObject] {
            if let referencedObject = result[relationship.name] {
                return self.newObjectID(for: relationship.destinationEntity!, referenceObject: referencedObject)
            }
        }
        
        if relationship.isOptional {
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
    
    // MARK: - Private functions
    
    func entitiesToParticipateInSync() -> [NSEntityDescription]? {
        let syncEntities =  self.backingMOC.persistentStoreCoordinator?.managedObjectModel.entities.filter { object in
            let entity: NSEntityDescription = object
            return (entity.name)! != SMStore.SMLocalStoreChangeSetEntityName
        }
        
        return syncEntities
    }
    
    
    fileprivate func toManyValues(forRelationship relationship: NSRelationshipDescription, forObjectWith objectID: NSManagedObjectID, with context: NSManagedObjectContext?) throws -> [NSManagedObjectID] {
        
        let recordID:String = self.referenceObject(for: objectID) as! String
        
        if let targetObjectID = try self.objectIDForBackingObjectForEntity(objectID.entity.name!, withReferenceObject: recordID) {
            
            let targetsFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: relationship.entity.name!)
            let targetsPredicate = NSPredicate(format: "%K == %@", relationship.name,targetObjectID)
            targetsFetchRequest.predicate = targetsPredicate
            targetsFetchRequest.resultType = .managedObjectResultType
            targetsFetchRequest.propertiesToFetch = [SMStore.SMLocalStoreRecordIDAttributeName]
            if let targetResults = try self.backingMOC.fetch(targetsFetchRequest) as? [NSManagedObject] {
                if !targetResults.isEmpty {
                    let retValues = targetResults.map {
                        let reference = $0.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName)
                        return self.newObjectID(for: relationship.entity, referenceObject: reference as Any)
                        
                        } as [NSManagedObjectID]
                    return retValues
                }
            }
        }
        return [NSManagedObjectID]()
    }
    
    fileprivate func backingModel() -> NSManagedObjectModel? {
        if let persistentStoreModel = self.persistentStoreCoordinator?.managedObjectModel {
            let backingModel: NSManagedObjectModel = SMStoreChangeSetHandler.defaultHandler.modelForLocalStore(usingModel: persistentStoreModel)
            return backingModel
        }
        return nil
    }
    
    // MARK:- Request handlers
    
    func executeInResponseToFetchRequest(_ fetchRequest:NSFetchRequest<NSFetchRequestResult>,context:NSManagedObjectContext) throws ->[Any] {
        let resultsFromLocalStore = try self.backingMOC.fetch(fetchRequest)
        if !resultsFromLocalStore.isEmpty {
            switch fetchRequest.resultType {
            case .managedObjectResultType:
                return resultsFromLocalStore.map({(result)->NSManagedObject in
                    let result = result as! NSManagedObject
                    let recordID: String = result.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as! String
                    let entity = self.persistentStoreCoordinator?.managedObjectModel.entitiesByName[fetchRequest.entityName!]
                    let objectID = self.newObjectID(for: entity!, referenceObject: recordID)
                    let object = context.object(with: objectID)
                    return object
                })
                
            case .dictionaryResultType:
                return resultsFromLocalStore.map({(result)->[String:Any] in
                    var result = result as! [String:Any]
                    result[SMStore.SMLocalStoreRecordIDAttributeName] = nil
                    return result
                })
            case .managedObjectIDResultType:
                return resultsFromLocalStore.map({(result)->NSManagedObjectID in
                    let result = result as! NSManagedObjectID
                    let object = self.backingMOC.registeredObject(for: result)!
                    let recordID: String = object.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as! String
                    let entity = self.persistentStoreCoordinator?.managedObjectModel.entitiesByName[fetchRequest.entityName!]
                    let objectID = self.newObjectID(for: entity!, referenceObject: recordID)
                    return objectID
                })
            case .countResultType:
                return [resultsFromLocalStore.count]
            default:
                break
            }
        }
        return []
    }
    
    func executeInResponseToCountFetchRequest(_ fetchRequest:NSFetchRequest<NSFetchRequestResult>,context:NSManagedObjectContext) throws ->[Int] {
        let resultsFromLocalStore = try self.backingMOC.count(for:fetchRequest)
        return [resultsFromLocalStore]
    }
    
    fileprivate func executeInResponseToSaveChangesRequest(_ saveRequest:NSSaveChangesRequest,context:NSManagedObjectContext) throws -> Array<AnyObject> {
        try self.deleteObjectsFromBackingStore(objectsToDelete: context.deletedObjects, mainContext: context)
        try self.insertObjectsInBackingStore(objectsToInsert: context.insertedObjects, mainContext: context)
        try self.updateObjectsInBackingStore(objectsToUpdate: context.updatedObjects, mainContext: context)
        
        try self.backingMOC.saveIfHasChanges()
        let allObjects = context.deletedObjects.union(context.insertedObjects).union(context.updatedObjects)
        for object in allObjects {
            context.refresh(object, mergeChanges: true)
        }
        if self.syncAutomatically {
            self.triggerSync()
        }
        return []
    }
    
    fileprivate func executeInResponseToBatchDeleteRequest(_ deleteRequest:NSBatchDeleteRequest, context:NSManagedObjectContext) throws -> NSBatchDeleteResult {
        
        guard let entity = deleteRequest.fetchRequest.entityName else {
            throw NSError(domain: SMStore.SMStoreErrorDomain, code: SMStoreError.invalidRequest._code, userInfo: nil)
        }
        
        let fr = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        fr.predicate = deleteRequest.fetchRequest.predicate
        fr.resultType = .managedObjectResultType
        guard let results = try context.fetch(fr) as? [NSManagedObject] else {
            throw NSError(domain: SMStore.SMStoreErrorDomain, code: SMStoreError.invalidRequest._code, userInfo: nil)
        }
        
        let deleteSet = Set<NSManagedObject>(results)
        
        try self.deleteObjectsFromBackingStore(objectsToDelete: deleteSet, mainContext: context)
        try self.backingMOC.saveIfHasChanges()
        for object in deleteSet {
            context.refresh(object, mergeChanges: true)
        }
        if self.syncAutomatically {
            self.triggerSync()
        }
        
        let resultType = deleteRequest.resultType
        var result: Any? = nil
        switch resultType {
        case .resultTypeCount:
            result = results.count
        case .resultTypeObjectIDs:
            result =  results.map {
                return $0.objectID
            }
        case .resultTypeStatusOnly:
            result = nil
        @unknown default:
            break
        }
        
        let returnResult = SMBatchDeleteResult(resultType: resultType, result: result)
        return returnResult
    }
    
    func objectIDForBackingObjectForEntity(_ entityName: String, withReferenceObject referenceObject: String?) throws -> NSManagedObjectID? {
        guard let referenceObj = referenceObject else {
            return nil
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.resultType = NSFetchRequestResultType.managedObjectIDResultType
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "%K == %@", SMStore.SMLocalStoreRecordIDAttributeName,referenceObj)
        
        let results = try self.backingMOC.fetch(fetchRequest)
        
        return results.last as? NSManagedObjectID ?? nil
        
    }
    
    fileprivate func setRelationshipValuesForBackingObject(_ backingObject:NSManagedObject, inContext: NSManagedObjectContext?, sourceObject:NSManagedObject) throws -> Void {
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
                    inContext?.refresh(sourceObject, mergeChanges: true)
                }
            }
        }
    }
    
    func insertObjectsInBackingStore(objectsToInsert objects:Set<NSObject>, mainContext: NSManagedObjectContext) throws -> Void {
        let mobs = Array(objects) as! [NSManagedObject]
        let sorted = SMObjectDependencyGraph(objects: mobs).sorted as! [NSManagedObject]
        for object in sorted {
            let managedObject:NSManagedObject = NSEntityDescription.insertNewObject(forEntityName: (object.entity.name)!, into: self.backingMOC) as NSManagedObject
            let keys = Array(object.entity.attributesByName.keys)
            let dictionary = object.dictionaryWithValues(forKeys: keys)
            managedObject.setValuesForKeys(dictionary)
            let referenceObject: String = self.referenceObject(for: object.objectID) as! String
            managedObject.setValue(referenceObject, forKey: SMStore.SMLocalStoreRecordIDAttributeName)
            mainContext.willChangeValue(forKey: "objectID")
            try mainContext.obtainPermanentIDs(for: [object])
            mainContext.didChangeValue(forKey: "objectID")
            SMStoreChangeSetHandler.defaultHandler.createChangeSet(ForInsertedObjectRecordID: referenceObject, entityName: object.entity.name!, backingContext: self.backingMOC)
            try self.setRelationshipValuesForBackingObject(managedObject, inContext:mainContext, sourceObject: object)
            // Don't save the MOC here: rolling up all the saves into a single one will prevent saving data in an inconsistent save
            // All saves are now performed in 'executeInResponseToSaveChangesRequest()'
        }
    }
    
    
    fileprivate func deleteObjectsFromBackingStore(objectsToDelete objects: Set<NSManagedObject>, mainContext: NSManagedObjectContext) throws -> Void {
        let predicateObjectRecordIDKey = "objectRecordID"
        let predicate: NSPredicate = NSPredicate(format: "%K == $objectRecordID", SMStore.SMLocalStoreRecordIDAttributeName)
        for object in objects {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: object.entity.name!)
            let recordID: String = self.referenceObject(for: object.objectID) as! String
            fetchRequest.predicate = predicate.withSubstitutionVariables([predicateObjectRecordIDKey: recordID])
            fetchRequest.fetchLimit = 1
            let results = try self.backingMOC.fetch(fetchRequest)
            if !results.isEmpty {
                if let backingObject: NSManagedObject = results.last as? NSManagedObject {
                    SMStoreChangeSetHandler.defaultHandler.createChangeSet(ForDeletedObjectRecordID: recordID, backingContext: self.backingMOC)
                    self.backingMOC.delete(backingObject)
                    // Don't save the MOC here: rolling up all the saves into a single one will prevent saving data in an inconsistent save
                    // All saves are now performed in 'executeInResponseToSaveChangesRequest()'
                }
            }
        }
    }
    
    fileprivate func updateObjectsInBackingStore(objectsToUpdate objects: Set<NSManagedObject>, mainContext: NSManagedObjectContext) throws -> Void {
        let predicateObjectRecordIDKey = "objectRecordID"
        let predicate: NSPredicate = NSPredicate(format: "%K == $objectRecordID", SMStore.SMLocalStoreRecordIDAttributeName)
        for object in objects {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: object.entity.name!)
            let recordID: String = self.referenceObject(for: object.objectID) as! String
            fetchRequest.predicate = predicate.withSubstitutionVariables([predicateObjectRecordIDKey:recordID])
            fetchRequest.fetchLimit = 1
            let results = try self.backingMOC.fetch(fetchRequest)
            if !results.isEmpty {
                if let backingObject: NSManagedObject = results.last as? NSManagedObject {
                    let keys = Array(self.persistentStoreCoordinator!.managedObjectModel.entitiesByName[object.entity.name!]!.attributesByName.keys)
                    let sourceObjectValues = object.dictionaryWithValues(forKeys: keys)
                    backingObject.setValuesForKeys(sourceObjectValues)
                    SMStoreChangeSetHandler.defaultHandler.createChangeSet(ForUpdatedObject: backingObject, usingContext: self.backingMOC)
                    try self.setRelationshipValuesForBackingObject(backingObject, inContext: nil, sourceObject: object)
                    // Don't save the MOC here: rolling up all the saves into a single one will prevent saving data in an inconsistent save
                    // All saves are now performed in 'executeInResponseToSaveChangesRequest()'
                }
            }
        }
    }
}

// MARK: - Fetch Result

@objc public enum FetchResult: UInt {
    case newData = 0
    case noData = 1
    case failed = 2
}

#if os(iOS) || os(tvOS)
import UIKit

public extension FetchResult {
     var uiBackgroundFetchResult: UIBackgroundFetchResult {
        switch self {
        case .newData: return .newData
        case .noData: return .noData
        case .failed: return .failed
        }
    }
}
#endif
