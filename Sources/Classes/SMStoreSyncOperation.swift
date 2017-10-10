//    SMStoreSyncOperation.swift
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
import CloudKit
import CoreData


enum SMSyncOperationError: Error {
    case localChangesFetchError
    case conflictsDetected(conflictedRecords: [SeamConflictedRecord])
    case missingReferences(referringRcords: [CKRecord])
    case unknownError
}

extension SMSyncOperationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .localChangesFetchError:
            return NSLocalizedString("Failed to fetch local changes.", comment: "localChangesFetchError")
        case .conflictsDetected(let records):
            return String(format:NSLocalizedString("%d conflicted records detected.", comment: "conflictsDetected"),records.count)
        case .missingReferences(let records):
            return String(format:NSLocalizedString("%d records with missing references.", comment: "conflictsDetected"),records.count)
        case .unknownError:
            return NSLocalizedString("Unknown Seam3 error.", comment: "unknownError")
        }
    }
}

public struct SeamConflictedRecord {
    var serverRecord: CKRecord
    var clientRecord: CKRecord
    var clientAncestorRecord: CKRecord
}


class SMStoreSyncOperation: Operation {
    
    static let SMStoreSyncOperationErrorDomain = "SMStoreSyncOperationDomain"
    static let SMSyncConflictsResolvedRecordsKey = "SMSyncConflictsResolvedRecordsKey"
    
    fileprivate var operationQueue: OperationQueue!
    fileprivate var localStoreMOC: NSManagedObjectContext!
    fileprivate var backingMOC: NSManagedObjectContext
    fileprivate var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    fileprivate var entities: Array<NSEntityDescription>
    fileprivate var database: CKDatabase?
    fileprivate let RETRYLIMIT = 5
    var syncConflictPolicy: SMSyncConflictResolutionPolicy
    var syncCompletionBlock: ((_ syncError:NSError?) -> ())?
    
    var syncConflictResolutionBlock: SMStore.SMStoreConflictResolutionBlock?
    
  init(persistentStoreCoordinator:NSPersistentStoreCoordinator?, entitiesToSync entities:[NSEntityDescription], conflictPolicy:SMSyncConflictResolutionPolicy = .serverRecordWins, database: CKDatabase?, backingMOC: NSManagedObjectContext) {
        self.persistentStoreCoordinator = persistentStoreCoordinator
        self.entities = entities
        self.database = database
        self.syncConflictPolicy = conflictPolicy
        self.backingMOC = backingMOC
        super.init()
    }
    
    // MARK: Sync
    override func main() {
        print("Sync Started", terminator: "\n")
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = 1
        self.localStoreMOC = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        self.localStoreMOC.persistentStoreCoordinator = self.persistentStoreCoordinator
        NotificationCenter.default.addObserver(self, selector: #selector(SMStoreSyncOperation.backingContextDidSave(notification:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: backingMOC)
        if let completionBlock = self.syncCompletionBlock {
            do {
                try self.performSync()
                print("Sync Performed", terminator: "\n")
                completionBlock(nil)
            } catch let error as NSError {
                print("Sync Performed with Error", terminator: "\n")
                completionBlock(error)
            }
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    func performSync() throws {
        var localChangesInServerRepresentation = try self.localChangesInServerRepresentation()
        do {
            try self.applyLocalChangesToServer(insertedOrUpdatedCKRecords: localChangesInServerRepresentation.insertedOrUpdatedCKRecords, deletedCKRecordIDs: localChangesInServerRepresentation.deletedCKRecordIDs)
            try self.fetchAndApplyServerChangesToLocalDatabase()
            SMServerTokenHandler.defaultHandler.commit()
            try SMStoreChangeSetHandler.defaultHandler.removeAllQueuedChangeSets(backingContext: self.localStoreMOC!)
            return
        } catch SMSyncOperationError.conflictsDetected(let conflictedRecords) {
            let resolvedRecords = self.resolveConflicts(conflictedRecords)
            var insertedOrUpdatedCKRecordsWithRecordIDStrings: Dictionary<String,CKRecord> = Dictionary<String,CKRecord>()
            for record in localChangesInServerRepresentation.insertedOrUpdatedCKRecords! {
                let ckRecord: CKRecord = record as CKRecord
                insertedOrUpdatedCKRecordsWithRecordIDStrings[ckRecord.recordID.recordName] = ckRecord
            }
            for record in resolvedRecords {
                insertedOrUpdatedCKRecordsWithRecordIDStrings[record.recordID.recordName] = record
            }
            localChangesInServerRepresentation.insertedOrUpdatedCKRecords = Array(insertedOrUpdatedCKRecordsWithRecordIDStrings.values)
            try self.applyLocalChangesToServer(insertedOrUpdatedCKRecords: localChangesInServerRepresentation.insertedOrUpdatedCKRecords, deletedCKRecordIDs: localChangesInServerRepresentation.deletedCKRecordIDs)
            try self.fetchAndApplyServerChangesToLocalDatabase()
            SMServerTokenHandler.defaultHandler.commit()
            try SMStoreChangeSetHandler.defaultHandler.removeAllQueuedChangeSets(backingContext: self.localStoreMOC!)
        } catch {
            throw error
        }
    }
    
    func fetchAndApplyServerChangesToLocalDatabase() throws {
        var moreComing = true
        var insertedOrUpdatedCKRecordsFromServer = [CKRecord]()
        var deletedCKRecordIDsFromServer = [CKRecordID]()
        while moreComing {
            let returnValue = self.fetchRecordChangesFromServer()
            insertedOrUpdatedCKRecordsFromServer.append(contentsOf: [] + returnValue.insertedOrUpdatedCKRecords)
            deletedCKRecordIDsFromServer.append(contentsOf: [] + returnValue.deletedRecordIDs)
            moreComing = returnValue.moreComing
        }
        try self.applyServerChangesToLocalDatabase(insertedOrUpdatedCKRecordsFromServer, deletedCKRecordIDs: deletedCKRecordIDsFromServer)
    }
    
    // MARK: Local Changes
    func applyServerChangesToLocalDatabase(_ insertedOrUpdatedCKRecords: [CKRecord], deletedCKRecordIDs:[CKRecordID]) throws {
        try self.insertOrUpdateManagedObjects(fromCKRecords: insertedOrUpdatedCKRecords)
        try self.deleteManagedObjects(fromCKRecordIDs: deletedCKRecordIDs)
    }
    
    func applyLocalChangesToServer(insertedOrUpdatedCKRecords: Array<CKRecord>? , deletedCKRecordIDs: Array<CKRecordID>?) throws {
        
        if insertedOrUpdatedCKRecords == nil && deletedCKRecordIDs == nil {
            return
        }
        
        var changedRecords = [String:CKRecord]()
        
        for record in insertedOrUpdatedCKRecords ?? [] {
            let recordName = record.recordID.recordName
            if let currentRecord = changedRecords[recordName] {
                if let currentDate = currentRecord.modificationDate,
                    let newDate = record.modificationDate {
                    if newDate > currentDate {
                        changedRecords[recordName] = record
                    }
                }
            } else {
                changedRecords[recordName] = record
            }
        }
        
        let ckModifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: Array(changedRecords.values), recordIDsToDelete: deletedCKRecordIDs)
        ckModifyRecordsOperation.database = self.database
        let savedRecords: [CKRecord] = [CKRecord]()
        var conflictedRecords = [SeamConflictedRecord]()
        ckModifyRecordsOperation.modifyRecordsCompletionBlock = ({(savedRecords,deletedRecordIDs,operationError)->Void in
            if operationError != nil {
                if let error = operationError as? CKError {
                    if let recordErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecordID:CKError] {
                        for recordError in recordErrors.values {
                            if recordError.code != CKError.serverRecordChanged {
                                print("Operation error:\(recordError)")
                            }
                        }
                    }
                } else {
                    print("Operation error \(operationError!)")
                }
            }
        })
        ckModifyRecordsOperation.perRecordCompletionBlock = ({(ckRecord,operationError)->Void in
            
            guard let error = operationError as? CKError else {
                return
            }
            
            if error.code == CKError.serverRecordChanged {
                guard let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
                    let clientRecord = error.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord,
                    let ancestorRecord = error.userInfo[CKRecordChangedErrorAncestorRecordKey] as? CKRecord
                    else {
                        return
                }
                let conflict = SeamConflictedRecord(serverRecord: serverRecord, clientRecord: clientRecord, clientAncestorRecord: ancestorRecord)
                conflictedRecords.append(conflict)
            }
        })
        self.operationQueue.addOperation(ckModifyRecordsOperation)
        self.operationQueue.waitUntilAllOperationsAreFinished()
        guard conflictedRecords.isEmpty else {
            throw SMSyncOperationError.conflictsDetected(conflictedRecords: conflictedRecords)
        }
        if !savedRecords.isEmpty {
            let recordIDSubstitution = "recordIDSubstitution"
            let fetchPredicate: NSPredicate = NSPredicate(format: "%K == $recordIDSubstitution", SMStore.SMLocalStoreRecordIDAttributeName)
            for record in savedRecords {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: record.recordType)
                let recordIDString: String = record.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as! String
                fetchRequest.predicate = fetchPredicate.withSubstitutionVariables([recordIDSubstitution:recordIDString])
                fetchRequest.fetchLimit = 1
                let results = try self.localStoreMOC!.fetch(fetchRequest)
                if results.count > 0 {
                    let managedObject = results.last as? NSManagedObject
                    let encodedFields = record.encodedSystemFields()
                    managedObject?.setValue(encodedFields, forKey: SMStore.SMLocalStoreRecordEncodedValuesAttributeName)
                }
            }
            try self.localStoreMOC.saveIfHasChanges()
        }
    }
    
    fileprivate func resolveConflicts(_ conflictedRecords: [SeamConflictedRecord]) -> [CKRecord]
    {
        var finalCKRecords: [CKRecord] = [CKRecord]()
        
        for conflict in conflictedRecords {
            let serverRecord = conflict.serverRecord
            let clientRecord = conflict.clientRecord
            let ancestorRecord = conflict.clientAncestorRecord
            
            switch self.syncConflictPolicy {
            case .serverRecordWins:
                finalCKRecords.append(conflict.serverRecord)
                
            case .clientRecordWins:
                

                for key in serverRecord.allKeys() {
                    serverRecord[key] = clientRecord[key]
                }
                
                finalCKRecords.append(conflict.serverRecord)
                
            case .clientTellsWhichWins:
                guard let conflictResolutionBlock = self.syncConflictResolutionBlock else {
                    fatalError("Conflict resolution policy .clientTellsWhichWins requires a syncConflictResolutionBlock")
                }
                
                let updatedRecord = conflictResolutionBlock(serverRecord, clientRecord, ancestorRecord)
                guard updatedRecord == serverRecord else {
                    fatalError("Conflict resolution block must return serverRecord")
                }
                finalCKRecords.append(updatedRecord)
            }
        }
        
        
        return finalCKRecords
    }
    
    func localChangesInServerRepresentation() throws -> (insertedOrUpdatedCKRecords:Array<CKRecord>?,deletedCKRecordIDs:Array<CKRecordID>?) {
        let changeSetHandler = SMStoreChangeSetHandler.defaultHandler
        let insertedOrUpdatedCKRecords = try changeSetHandler.recordsForUpdatedObjects(backingContext: self.localStoreMOC!)
        let deletedCKRecordIDs = try changeSetHandler.recordIDsForDeletedObjects(self.localStoreMOC!)
        return (insertedOrUpdatedCKRecords,deletedCKRecordIDs)
    }
    
    func fetchRecordChangesFromServer() -> (insertedOrUpdatedCKRecords:Array<CKRecord>,deletedRecordIDs:Array<CKRecordID>,moreComing:Bool) {
        
        var syncOperationError: Error? = nil
        var moreComing = false
        
        let token = SMServerTokenHandler.defaultHandler.token()
        let recordZoneID = CKRecordZoneID(zoneName: SMStore.SMStoreCloudStoreCustomZoneName, ownerName: CKOwnerDefaultName)
        let fetchRecordChangesOperation = CKFetchRecordChangesOperation(recordZoneID: recordZoneID, previousServerChangeToken: token)
        fetchRecordChangesOperation.database = self.database
        var insertedOrUpdatedCKRecords: [CKRecord] = [CKRecord]()
        var deletedCKRecordIDs: [CKRecordID] = [CKRecordID]()
        fetchRecordChangesOperation.fetchRecordChangesCompletionBlock = { serverChangeToken,clientChangeToken,operationError in
            if operationError == nil {
                SMServerTokenHandler.defaultHandler.save(serverChangeToken: serverChangeToken!)
                SMServerTokenHandler.defaultHandler.commit()
            } else {
                syncOperationError = operationError
            }
        }
        fetchRecordChangesOperation.recordChangedBlock = { record in
            let ckRecord:CKRecord = record as CKRecord
            insertedOrUpdatedCKRecords.append(ckRecord)
        }
        fetchRecordChangesOperation.recordWithIDWasDeletedBlock = { recordID in
            deletedCKRecordIDs.append(recordID as CKRecordID)
        }
        self.operationQueue!.addOperation(fetchRecordChangesOperation)
        self.operationQueue!.waitUntilAllOperationsAreFinished()
        if syncOperationError == nil {
            
            if !insertedOrUpdatedCKRecords.isEmpty {
                let recordIDs: [CKRecordID] = insertedOrUpdatedCKRecords.map { record in
                    return record.recordID
                }
                var recordTypes: Set<String> = Set<String>()
                for record in insertedOrUpdatedCKRecords {
                    recordTypes.insert(record.recordType)
                }
                var desiredKeys: [String]?
                for recordType in recordTypes {
                    if desiredKeys == nil {
                        desiredKeys = [String]()
                    }
                    let entity = self.persistentStoreCoordinator?.managedObjectModel.entitiesByName[recordType]
                    if entity != nil {
                        let properties = Array(entity!.propertiesByName.keys).filter {  key in
                            if key == SMStore.SMLocalStoreRecordIDAttributeName || key == SMStore.SMLocalStoreRecordEncodedValuesAttributeName {
                                return false
                            }
                            return true
                        }
                        desiredKeys!.append(contentsOf: properties)
                    }
                }
                insertedOrUpdatedCKRecords.removeAll()
                let fetchRecordsOperation: CKFetchRecordsOperation = CKFetchRecordsOperation(recordIDs: recordIDs)
                fetchRecordsOperation.desiredKeys = desiredKeys
                fetchRecordsOperation.database = self.database
                fetchRecordsOperation.fetchRecordsCompletionBlock =  { recordsByRecordID,operationError in
                    if operationError == nil && recordsByRecordID != nil {
                        insertedOrUpdatedCKRecords = Array(recordsByRecordID!.values)
                    }
                }
                self.operationQueue.addOperation(fetchRecordsOperation)
                self.operationQueue.waitUntilAllOperationsAreFinished()
            }
            if fetchRecordChangesOperation.moreComing {
                print("More records coming", terminator: "\n")
            } else {
                print("No more records coming", terminator: "\n")
            }
            moreComing = fetchRecordChangesOperation.moreComing
        } else {
            if let error = syncOperationError as? CKError {
                if error.code == .changeTokenExpired {
                    SMServerTokenHandler.defaultHandler.delete()
                    return self.fetchRecordChangesFromServer()
                }
            }
        }
        return (insertedOrUpdatedCKRecords,deletedCKRecordIDs,moreComing)
    }
    
    func insertOrUpdateManagedObjects(fromCKRecords ckRecords:Array<CKRecord>, retryCount: Int = 0) throws {
        var deferredRecords = [CKRecord]()
        for record in ckRecords {
            var success = false
            do {
                let _ = try record.createOrUpdateManagedObjectFromRecord(usingContext: self.localStoreMOC!)
                success = true
            } catch SMStoreError.missingRelatedObject {
                deferredRecords.append(record)
            }
            if success {
                try self.localStoreMOC.saveIfHasChanges()
            }
        }
        
        if !deferredRecords.isEmpty {
            
            if retryCount < self.RETRYLIMIT  {
                try self.insertOrUpdateManagedObjects(fromCKRecords: deferredRecords, retryCount:retryCount+1)
            } else {
                throw SMSyncOperationError.missingReferences(referringRcords: deferredRecords)
            }
        }
    }
    
    func deleteManagedObjects(fromCKRecordIDs ckRecordIDs:Array<CKRecordID>) throws {
        if !ckRecordIDs.isEmpty {
            let predicate = NSPredicate(format: "%K IN $ckRecordIDs",SMStore.SMLocalStoreRecordIDAttributeName)
            let ckRecordIDStrings = ckRecordIDs.map({(object)->String in
                let ckRecordID:CKRecordID = object
                return ckRecordID.recordName
            })
            let entityNames = self.entities.map { (entity) in
                return entity.name!
            }
            for name in entityNames {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name as String)
                fetchRequest.predicate = predicate.withSubstitutionVariables(["ckRecordIDs":ckRecordIDStrings])
                let results = try self.localStoreMOC.fetch(fetchRequest)
                if !results.isEmpty {
                    for object in results as! [NSManagedObject] {
                        self.localStoreMOC.delete(object)
                    }
                }
            }
        }
        try self.localStoreMOC.saveIfHasChanges()
    }
  
    // MARK: Prevent Conflicts
    @objc func backingContextDidSave(notification: Notification) {
      print("OK backingContextDidSave")
      self.localStoreMOC.performAndWait {
        self.localStoreMOC.mergeChanges(fromContextDidSave: notification)
      }
    }
}
