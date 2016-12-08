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


import CoreData
import CloudKit
import ObjectiveC

enum SMStoreRecordChangeType: Int16 {
    case recordNoChange = 0
    case recordUpdated = 1
    case recordDeleted = 2
    case recordInserted = 3
}

public struct SMStoreNotification {
    public static let SyncDidStart = "SMStoreDidStartSyncOperationNotification"
    public static let SyncDidFinish = "SMStoreDidFinishSyncOperationNotification"
}

enum SMLocalStoreRecordChangeType: Int16 {
    case recordNoChange = 0
    case recordUpdated  = 1
    case recordDeleted  = 2
    case recordInserted = 3
}

enum SMStoreError: Error {
    case backingStoreFetchRequestError
    case invalidRequest
    case backingStoreCreationFailed
    case backingStoreUpdateError
    case missingInverseRelationship
    case manyToManyUnsupported
    case missingRelatedObject
}

open class SMStore: NSIncrementalStore {
    
    var syncAutomatically: Bool = true
    var recordConflictResolutionBlock:((_ clientRecord:CKRecord,_ serverRecord:CKRecord)->CKRecord)?
    
    static let SMStoreSyncConflictResolutionPolicyOption = "SMStoreSyncConflictResolutionPolicyOption"
    static let SMStoreErrorDomain = "SMStoreErrorDomain"
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
    
    fileprivate var automaticStoreMigration = false
    fileprivate var inferMappingModel = false
    
    fileprivate lazy var backingMOC: NSManagedObjectContext = {
        var moc = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        moc.persistentStoreCoordinator = self.backingPersistentStoreCoordinator
        moc.retainsRegisteredObjects = true
        moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return moc     }()
    
    override open class func initialize() {
        NSPersistentStoreCoordinator.registerStoreClass(self, forStoreType: self.type)
    }
    
    override init(persistentStoreCoordinator root: NSPersistentStoreCoordinator?, configurationName name: String?, at url: URL, options: [AnyHashable: Any]?) {
        self.database = CKContainer.default().privateCloudDatabase
        if let opts = options {
            if let syncConflictPolicy = opts[SMStore.SMStoreSyncConflictResolutionPolicyOption] as? SMSyncConflictResolutionPolicy {
                self.cksStoresSyncConflictPolicy = syncConflictPolicy
            }
            
            if let migrationPolicy = opts[NSMigratePersistentStoresAutomaticallyOption] as? Bool {
                self.automaticStoreMigration = migrationPolicy
            }
            
            if let inferMapping = opts[NSInferMappingModelAutomaticallyOption] as? Bool {
                self.inferMappingModel = inferMapping
            }
            
        }
        super.init(persistentStoreCoordinator: root, configurationName: name, at: url, options: options)
    }
    
    class open var type:String {
        return NSStringFromClass(self)
    }
    
    override open func loadMetadata() throws {
        self.metadata=[
            NSStoreUUIDKey: ProcessInfo().globallyUniqueString,
            NSStoreTypeKey: type(of: self).type
        ]
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
    
    func entitiesToParticipateInSync() -> [NSEntityDescription]? {
        return self.backingMOC.persistentStoreCoordinator?.managedObjectModel.entities.filter { object in
            let entity: NSEntityDescription = object
            return (entity.name)! != SMStore.SMLocalStoreChangeSetEntityName
        }
    }
    
    open func triggerSync() {
        
        guard self.operationQueue?.operationCount == 0 else {
            return
        }
        
        let syncOperationBlock = {
            self.syncOperation = SMStoreSyncOperation(persistentStoreCoordinator: self.backingPersistentStoreCoordinator, entitiesToSync: self.entitiesToParticipateInSync()!, conflictPolicy: self.cksStoresSyncConflictPolicy)
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
                        return self.newObjectID(for: toOneRelationship.entity, referenceObject: reference)
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
