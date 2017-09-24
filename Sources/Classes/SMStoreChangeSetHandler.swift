//    SMStoreChangeSetHandler.swift
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


import Foundation
import CoreData
import CloudKit


enum SMLocalStoreRecordChangeType: Int16 {
    case recordNoChange = 0
    case recordUpdated  = 1
    case recordDeleted  = 2
    case recordInserted = 3
}

class SMStoreChangeSetHandler {
    
    static let SMLocalStoreEntityNameAttributeName = "sm_LocalStore_EntityName"
    static let SMLocalStoreChangeTypeAttributeName="sm_LocalStore_ChangeType"
    static let SMLocalStoreChangeQueuedAttributeName = "sm_LocalStore_Queued"
    
    static let defaultHandler = SMStoreChangeSetHandler()
    
    func changedPropertyKeys(_ keys: [String], entity: NSEntityDescription) -> [String] {
        return keys.filter({ (key) -> Bool in
            let property = entity.propertiesByName[key]
            if property != nil && property is NSRelationshipDescription {
                let relationshipDescription: NSRelationshipDescription = property as! NSRelationshipDescription
                return relationshipDescription.isToMany == false
            }
            return true
        })
    }
    
    func addExtraBackingStoreAttributes(toEntity entity: NSEntityDescription) {
        let recordIDAttribute: NSAttributeDescription = NSAttributeDescription()
        recordIDAttribute.name = SMStore.SMLocalStoreRecordIDAttributeName
        recordIDAttribute.isOptional = false
        recordIDAttribute.isIndexed = true
        recordIDAttribute.attributeType = NSAttributeType.stringAttributeType
        entity.properties.append(recordIDAttribute)
        let recordEncodedValuesAttribute: NSAttributeDescription = NSAttributeDescription()
        recordEncodedValuesAttribute.name = SMStore.SMLocalStoreRecordEncodedValuesAttributeName
        recordEncodedValuesAttribute.attributeType = NSAttributeType.binaryDataAttributeType
        recordEncodedValuesAttribute.isOptional = true
        entity.properties.append(recordEncodedValuesAttribute)
    }
    
    func changeSetEntity() -> NSEntityDescription {
        let changeSetEntity: NSEntityDescription = NSEntityDescription()
        changeSetEntity.name = SMStore.SMLocalStoreChangeSetEntityName
        let entityNameAttribute: NSAttributeDescription = NSAttributeDescription()
        entityNameAttribute.name = SMStoreChangeSetHandler.SMLocalStoreEntityNameAttributeName
        entityNameAttribute.attributeType = NSAttributeType.stringAttributeType
        entityNameAttribute.isOptional = true
        changeSetEntity.properties.append(entityNameAttribute)
        let recordIDAttribute: NSAttributeDescription = NSAttributeDescription()
        recordIDAttribute.name = SMStore.SMLocalStoreRecordIDAttributeName
        recordIDAttribute.attributeType = NSAttributeType.stringAttributeType
        recordIDAttribute.isOptional = false
        recordIDAttribute.isIndexed = true
        changeSetEntity.properties.append(recordIDAttribute)
        let recordChangedPropertiesAttribute: NSAttributeDescription = NSAttributeDescription()
        recordChangedPropertiesAttribute.name = SMStore.SMLocalStoreRecordChangedPropertiesAttributeName
        recordChangedPropertiesAttribute.attributeType = NSAttributeType.stringAttributeType
        recordChangedPropertiesAttribute.isOptional = true
        changeSetEntity.properties.append(recordChangedPropertiesAttribute)
        let recordChangeTypeAttribute: NSAttributeDescription = NSAttributeDescription()
        recordChangeTypeAttribute.name = SMStoreChangeSetHandler.SMLocalStoreChangeTypeAttributeName
        recordChangeTypeAttribute.attributeType = NSAttributeType.integer16AttributeType
        recordChangeTypeAttribute.isOptional = false
        recordChangeTypeAttribute.defaultValue = NSNumber(value: SMLocalStoreRecordChangeType.recordInserted.rawValue as Int16)
        changeSetEntity.properties.append(recordChangeTypeAttribute)
        let changeTypeQueuedAttribute: NSAttributeDescription = NSAttributeDescription()
        changeTypeQueuedAttribute.name = SMStoreChangeSetHandler.SMLocalStoreChangeQueuedAttributeName
        changeTypeQueuedAttribute.isOptional = false
        changeTypeQueuedAttribute.attributeType = NSAttributeType.booleanAttributeType
        changeTypeQueuedAttribute.defaultValue = NSNumber(value: false as Bool)
        changeSetEntity.properties.append(changeTypeQueuedAttribute)
        return changeSetEntity
    }
    
    func modelForLocalStore(usingModel model: NSManagedObjectModel) -> NSManagedObjectModel {
        let backingModel: NSManagedObjectModel = model.copy() as! NSManagedObjectModel
        for entity in backingModel.entities {
          let hasSuperEntity = entity.superentity != nil
          if !hasSuperEntity {
            self.addExtraBackingStoreAttributes(toEntity: entity)
          }
        }
        backingModel.entities.append(self.changeSetEntity())
        return backingModel
    }
    
    // MARK: Creation
    func createChangeSet(ForInsertedObjectRecordID recordID: String, entityName: String, backingContext: NSManagedObjectContext) {
        let changeSet = NSEntityDescription.insertNewObject(forEntityName: SMStore.SMLocalStoreChangeSetEntityName, into: backingContext)
        changeSet.setValue(recordID, forKey: SMStore.SMLocalStoreRecordIDAttributeName)
        changeSet.setValue(entityName, forKey: SMStoreChangeSetHandler.SMLocalStoreEntityNameAttributeName)
        changeSet.setValue(NSNumber(value: SMLocalStoreRecordChangeType.recordInserted.rawValue as Int16), forKey: SMStoreChangeSetHandler.SMLocalStoreChangeTypeAttributeName)
    }
    
    func createChangeSet(ForUpdatedObject object: NSManagedObject, usingContext context: NSManagedObjectContext) {
        let changeSet = NSEntityDescription.insertNewObject(forEntityName: SMStore.SMLocalStoreChangeSetEntityName, into: context)
        let changedPropertyKeys = self.changedPropertyKeys(Array(object.changedValues().keys), entity: object.entity)
        let recordIDString: String = object.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as! String
        let changedPropertyKeysString = changedPropertyKeys.joined(separator: ",")
        changeSet.setValue(recordIDString, forKey: SMStore.SMLocalStoreRecordIDAttributeName)
        changeSet.setValue(object.entity.name!, forKey: SMStoreChangeSetHandler.SMLocalStoreEntityNameAttributeName)
        changeSet.setValue(changedPropertyKeysString, forKey: SMStore.SMLocalStoreRecordChangedPropertiesAttributeName)
        changeSet.setValue(NSNumber(value: SMLocalStoreRecordChangeType.recordUpdated.rawValue as Int16), forKey: SMStoreChangeSetHandler.SMLocalStoreChangeTypeAttributeName)
    }
    
    func createChangeSet(ForDeletedObjectRecordID recordID:String, backingContext: NSManagedObjectContext) {
        let changeSet = NSEntityDescription.insertNewObject(forEntityName: SMStore.SMLocalStoreChangeSetEntityName, into: backingContext)
        changeSet.setValue(recordID, forKey: SMStore.SMLocalStoreRecordIDAttributeName)
        changeSet.setValue(NSNumber(value: SMLocalStoreRecordChangeType.recordDeleted.rawValue as Int16), forKey: SMStoreChangeSetHandler.SMLocalStoreChangeTypeAttributeName)
    }
    
    // MARK: Fetch
    fileprivate func changeSets(ForChangeType changeType:SMLocalStoreRecordChangeType, propertiesToFetch: Array<String>,  backingContext: NSManagedObjectContext) throws -> [AnyObject]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: SMStore.SMLocalStoreChangeSetEntityName)
        let predicate: NSPredicate = NSPredicate(format: "%K == %@", SMStoreChangeSetHandler.SMLocalStoreChangeTypeAttributeName, NSNumber(value: changeType.rawValue as Int16))
        fetchRequest.predicate = predicate
        fetchRequest.resultType = NSFetchRequestResultType.dictionaryResultType
        fetchRequest.propertiesToFetch = propertiesToFetch
        let results = try backingContext.fetch(fetchRequest)
        return results as [AnyObject]?
    }

    
    func recordIDsForDeletedObjects(_ backingContext: NSManagedObjectContext) throws -> [CKRecordID]? {
        let propertiesToFetch = [SMStore.SMLocalStoreRecordIDAttributeName]
        if let deletedObjectsChangeSets = try self.changeSets(ForChangeType: SMLocalStoreRecordChangeType.recordDeleted, propertiesToFetch: propertiesToFetch, backingContext: backingContext) {
            if !deletedObjectsChangeSets.isEmpty  {
                return deletedObjectsChangeSets.map({ (object) -> CKRecordID in
                    let valuesDictionary: Dictionary<String,NSObject> = object as! Dictionary<String,NSObject>
                    let recordID: String = valuesDictionary[SMStore.SMLocalStoreRecordIDAttributeName] as! String
                    let cksRecordZoneID: CKRecordZoneID = CKRecordZoneID(zoneName: SMStore.SMStoreCloudStoreCustomZoneName, ownerName: CKOwnerDefaultName)
                    return CKRecordID(recordName: recordID, zoneID: cksRecordZoneID)
                })
            }
        }
        return nil
    }
    
    func recordsForUpdatedObjects(backingContext context: NSManagedObjectContext) throws -> [CKRecord]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: SMStore.SMLocalStoreChangeSetEntityName)
        fetchRequest.predicate = NSPredicate(format: "%K == %@ || %K == %@", SMStoreChangeSetHandler.SMLocalStoreChangeTypeAttributeName, NSNumber(value: SMLocalStoreRecordChangeType.recordInserted.rawValue as Int16), SMStoreChangeSetHandler.SMLocalStoreChangeTypeAttributeName, NSNumber(value: SMLocalStoreRecordChangeType.recordUpdated.rawValue as Int16))
        let results = try context.fetch(fetchRequest)
        var ckRecords: [CKRecord] = [CKRecord]()
        if !results.isEmpty {
            let recordIDSubstitution = "recordIDString"
            let predicate = NSPredicate(format: "%K == $recordIDString", SMStore.SMLocalStoreRecordIDAttributeName)
            for result in results as! [NSManagedObject] {
                result.setValue(NSNumber(value: true as Bool), forKey: SMStoreChangeSetHandler.SMLocalStoreChangeQueuedAttributeName)
                let entityName: String = result.value(forKey: SMStoreChangeSetHandler.SMLocalStoreEntityNameAttributeName) as! String
                let recordIDString: String = result.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as! String
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                fetchRequest.predicate = predicate.withSubstitutionVariables([recordIDSubstitution:recordIDString])
                fetchRequest.fetchLimit = 1
                let objects = try context.fetch(fetchRequest)
                if objects.count > 0 {
                    let object: NSManagedObject = objects.last as! NSManagedObject
                    let changedPropertyKeys = result.value(forKey: SMStore.SMLocalStoreRecordChangedPropertiesAttributeName) as? String
                    var changedPropertyKeysArray: [String]?
                    if changedPropertyKeys != nil && changedPropertyKeys!.isEmpty == false {
                        if changedPropertyKeys!.range(of: ",") != nil {
                            changedPropertyKeysArray = changedPropertyKeys!.components(separatedBy: ",")
                        } else {
                            changedPropertyKeysArray = [changedPropertyKeys!]
                        }
                    }
                    if let ckRecord = object.createOrUpdateCKRecord(usingValuesOfChangedKeys: changedPropertyKeysArray) {
                        ckRecords.append(ckRecord)
                    }
                }
            }
        }
        try context.saveIfHasChanges()
        return ckRecords
    }

    func removeAllQueuedChangeSetsFromQueue(backingContext context: NSManagedObjectContext) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: SMStore.SMLocalStoreChangeSetEntityName)
        fetchRequest.predicate = NSPredicate(format: "%K == %@", SMStoreChangeSetHandler.SMLocalStoreChangeQueuedAttributeName, NSNumber(value: true as Bool))
        let results = try context.fetch(fetchRequest)
        for result in results as! [NSManagedObject] {
            result.setValue(NSNumber(value: false as Bool), forKey: SMStoreChangeSetHandler.SMLocalStoreChangeQueuedAttributeName)
        }
        try context.saveIfHasChanges()
    }
    
    func removeAllQueuedChangeSets(backingContext context: NSManagedObjectContext) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: SMStore.SMLocalStoreChangeSetEntityName)
        fetchRequest.includesPropertyValues = false
        fetchRequest.predicate = NSPredicate(format: "%K == %@", SMStoreChangeSetHandler.SMLocalStoreChangeQueuedAttributeName, NSNumber(value: true as Bool))
        let results = try context.fetch(fetchRequest)
        if !results.isEmpty {
            for managedObject in results as! [NSManagedObject] {
                context.delete(managedObject)
            }
            try context.saveIfHasChanges()
        }
    }
}
