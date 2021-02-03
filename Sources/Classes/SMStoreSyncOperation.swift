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
import os.log


enum SMSyncOperationError: Error {
    case localChangesFetchError
    case conflictsDetected(conflictedRecords: [SeamConflictedRecord])
    case missingReferences(referringRcords: [CKRecord])
    case shouldRetryError
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
        case .shouldRetryError:
            return ""
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
    fileprivate var backingMOC: NSManagedObjectContext?
    fileprivate var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    fileprivate var entities: Array<NSEntityDescription>
    fileprivate var database: CKDatabase?
    fileprivate let RETRYLIMIT = 5
    var syncConflictPolicy: SMSyncConflictResolutionPolicy
    var syncCompletionBlock: ((_ result: FetchResult, _ syncError:NSError?) -> ())?
    
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
        SMStore.logger?.info("Cloud Sync Started")
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = 1
        self.localStoreMOC = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        NotificationCenter.default.addObserver(self, selector: #selector(SMStoreSyncOperation.backingContextDidSave(notification:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: backingMOC)
        
        self.localStoreMOC.persistentStoreCoordinator = self.persistentStoreCoordinator
        if let completionBlock = self.syncCompletionBlock {
            NotificationCenter.default.removeObserver(self)
            do {
                let result = try self.performSync()
                completionBlock(result, nil)
            } catch let error as NSError {
                completionBlock(.failed, error)
            }
        }
        
    }
    
    @objc func backingContextDidSave(notification: Notification) {
        self.localStoreMOC.performAndWait {
            self.localStoreMOC.mergeChanges(fromContextDidSave: notification)
        }
    }
    
    struct LocalChanges {
        var insertedOrUpdatedCKRecords: [CKRecord] = []
        var deletedCKRecordIDs: [CKRecord.ID] = []
    }
    
    func performSync() throws -> FetchResult {
        let localChangesInServerRepresentation = try self.localChangesInServerRepresentation()
        return try performSync(localChanges: localChangesInServerRepresentation)
    }
    
    private func performSync(localChanges: LocalChanges) throws -> FetchResult {
        let hasLocalChanges =
                localChanges.insertedOrUpdatedCKRecords.count != 0 ||
                localChanges.deletedCKRecordIDs.count != 0
        var hasRemoteChanges = false
        do {
            try self.applyLocalChangesToServer(insertedOrUpdatedCKRecords: localChanges.insertedOrUpdatedCKRecords, deletedCKRecordIDs: localChanges.deletedCKRecordIDs)
            hasRemoteChanges = try self.fetchAndApplyServerChangesToLocalDatabase()
            SMServerTokenHandler.defaultHandler.commit()
            try SMStoreChangeSetHandler.defaultHandler.removeAllQueuedChangeSets(backingContext: self.localStoreMOC!)
        } catch SMSyncOperationError.conflictsDetected(let conflictedRecords) {
            let resolvedRecords = self.resolveConflicts(conflictedRecords)
            var insertedOrUpdatedCKRecordsWithRecordIDStrings: Dictionary<String,CKRecord> = Dictionary<String,CKRecord>()
            for record in localChanges.insertedOrUpdatedCKRecords {
                let ckRecord: CKRecord = record as CKRecord
                insertedOrUpdatedCKRecordsWithRecordIDStrings[ckRecord.recordID.recordName] = ckRecord
            }
            for record in resolvedRecords {
                insertedOrUpdatedCKRecordsWithRecordIDStrings[record.recordID.recordName] = record
            }
            var localChangesResolved = localChanges
            localChangesResolved.insertedOrUpdatedCKRecords = Array(insertedOrUpdatedCKRecordsWithRecordIDStrings.values)
            return try performSync(localChanges: localChangesResolved)
        } catch SMSyncOperationError.shouldRetryError {
            SMStore.logger?.info("Retrying performSync")
            return try performSync()
        } catch {
            SMStore.logger?.error("ERROR during performSync() \(error.localizedDescription)")
            #if DEBUG
            if let conflictList = (error as NSError).userInfo["conflictList"] as? [NSMergeConflict] {
                for conflict in conflictList {
                    let message = """
                    conflict:
                    objectSnapshot: \(conflict.objectSnapshot ?? [:])
                    cachedSnapshot: \(conflict.cachedSnapshot ?? [:])
                    persistedSnapshot: \(conflict.persistedSnapshot ?? [:])
                    """
                    SMStore.logger?.error(message)
                }
            }
            #endif
            throw error
        }
        return hasLocalChanges || hasRemoteChanges ? .newData : .noData
    }
    
    func fetchAndApplyServerChangesToLocalDatabase() throws -> Bool {
        let returnValue = self.fetchRecordChangesFromServer()
        let hasNewData =
            returnValue.insertedOrUpdatedCKRecords.count != 0 ||
            returnValue.deletedRecordIDs.count != 0
        var executeError: Error?
        self.localStoreMOC.performAndWait {
            do {
                try self.applyServerChangesToLocalDatabase(returnValue.insertedOrUpdatedCKRecords, deletedCKRecordIDs: returnValue.deletedRecordIDs)
            } catch {
                executeError = error
            }
        }
        if let error = executeError {
            throw error
        }
        return hasNewData
    }
    
    // MARK: Local Changes
    private func managedObjectsByType(_ objects: Set<NSManagedObject>) -> [String:Int] {
        let objectsByType = objects.reduce([String:Int]()) { (result: [String:Int], managedObject: NSManagedObject) -> [String:Int] in
            
            guard let entityName = managedObject.entity.name else {
                return result
            }
            var result = result
            if result[entityName] == nil {
                result[entityName] = 0
            }
            result[entityName] = result[entityName]! + 1
            return result
        }
        return objectsByType
    }
    
    func applyServerChangesToLocalDatabase(_ insertedOrUpdatedCKRecords: [CKRecord], deletedCKRecordIDs:[CKRecord.ID]) throws {
        try self.insertOrUpdateManagedObjects(fromCKRecords: insertedOrUpdatedCKRecords)
        try self.deleteManagedObjects(fromCKRecordIDs: deletedCKRecordIDs)
        let registeredObjects = self.localStoreMOC.registeredObjects
        let objectsByType = managedObjectsByType(registeredObjects)
        SMStore.logger?.info("OK SMStore will try to save to persistent store \(registeredObjects.count) objects\n\n\(objectsByType)")
        try self.localStoreMOC.saveIfHasChanges()
    }
    
    func applyLocalChangesToServer(insertedOrUpdatedCKRecords: Array<CKRecord> , deletedCKRecordIDs: Array<CKRecord.ID>) throws {
        
        var changedRecords = [String:CKRecord]()
        
        for record in insertedOrUpdatedCKRecords {
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
        SMStore.logger?.debug("Will attempt saving (insert/update) to the cloud \(changedRecords.count) CKRecords \(changedRecords.keys) (zone=\(String(describing: changedRecords.randomElement()?.value.recordID.zoneID.zoneName)))\n\(changedRecords.map {return $0.value})")
        SMStore.logger?.debug("Will attempt deleting from the cloud \(deletedCKRecordIDs.count) CKRecords \((deletedCKRecordIDs).map {$0.recordName}) (zone=\(String(describing: deletedCKRecordIDs.first?.zoneID.zoneName)))")
        
        var outerSavedRecords: [CKRecord] = []
        var outerDeletedRecordIDs: [CKRecord.ID] = []
        var conflictedRecords = [SeamConflictedRecord]()
        var shouldResetZone = false
        var shouldRetry = false
        
        // Split the changed records and deleted record IDs into multiple batches of 400 elements each,
        // because this is the maximum number of items possible in a single modify request.
        if let splitChangedRecords = self.splitArray(Array(changedRecords.values), maximumNumberOfItems: 400) as? [[CKRecord]],
           let splitDeletedRecordIDs = self.splitArray(deletedCKRecordIDs, maximumNumberOfItems: 400) as? [[CKRecord.ID]] {
            for index in 0...max(splitChangedRecords.count, splitDeletedRecordIDs.count) {
                let changedRecords = splitChangedRecords.count > index ? splitChangedRecords[index] : nil
                let deletedRecordIDs = splitDeletedRecordIDs.count > index ? splitDeletedRecordIDs[index] : nil
                
                let ckModifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: changedRecords, recordIDsToDelete: deletedRecordIDs)
                ckModifyRecordsOperation.database = self.database
                ckModifyRecordsOperation.modifyRecordsCompletionBlock = ({(savedRecords,deletedRecordIDs,operationError)->Void in
                    if let savedRecords = savedRecords {
                        outerSavedRecords.append(contentsOf: savedRecords)
                    }

                    if let deletedRecordIDs = deletedRecordIDs {
                        outerDeletedRecordIDs.append(contentsOf: deletedRecordIDs)
                    }
                })
                ckModifyRecordsOperation.perRecordCompletionBlock = ({(ckRecord,operationError)->Void in
                    guard let error = operationError as? CKError else {
                        SMStore.logger?.debug("OK Completed CKRecord operation (change/insert or delete to the cloud) for \(ckRecord.recordID.recordName)")
                        return
                    }
                    
                    let underLyingerror = error.userInfo["NSUnderlyingError"] as? CKError ?? error
                    SMStore.logger?.error("Operation error: \(underLyingerror.localizedDescription)\n")
                    
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
                    else if error.code == CKError.unknownItem {
                        SMStore.logger?.debug("Clearing iCloud encoded fields for record for retry: \(ckRecord.recordType) \(ckRecord.recordID.recordName)");
                        do {
                            let mob = try ckRecord.managedObjectForRecord(context: self.backingMOC!)
                            mob?.setValue(nil, forKey: SMStore.SMLocalStoreRecordEncodedValuesAttributeName)
                            shouldRetry = true
                        } catch {
                            SMStore.logger?.error("Failed to fetch and clear CloudKit encoded values from matching ManagedObject for \(ckRecord.recordID.recordName)")
                        }
                    }
                    else if underLyingerror.code == .userDeletedZone ||
                        underLyingerror.code == .zoneNotFound {
                        shouldResetZone = true
                    }
                })
                
                self.operationQueue.addOperation(ckModifyRecordsOperation)
                self.operationQueue.waitUntilAllOperationsAreFinished()
            }
        }
        
        if shouldResetZone {
            UserDefaults.standard.set(false, forKey:SMStore.SMStoreCloudStoreCustomZoneName)
            // TODO: should retry here after executing SMServerStoreSetupOperation, but that is tricky currently
        }
        guard conflictedRecords.isEmpty else {
            let conflict = SMSyncOperationError.conflictsDetected(conflictedRecords: conflictedRecords)
            throw conflict
        }
        if shouldRetry {
            try self.backingMOC?.saveIfHasChanges()
            throw SMSyncOperationError.shouldRetryError
        }
        SMStore.logger?.info("Uploaded \(outerSavedRecords.count) inserts/updates and \(outerDeletedRecordIDs.count) deletes to the cloud")
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
    
    func localChangesInServerRepresentation() throws -> LocalChanges {
        let changeSetHandler = SMStoreChangeSetHandler.defaultHandler
        var insertedOrUpdatedCKRecords: Array<CKRecord> = []
        var deletedCKRecordIDs: Array<CKRecord.ID> = []
        var executeError: Error?
        self.localStoreMOC!.performAndWait {
            do {
                insertedOrUpdatedCKRecords = try changeSetHandler.recordsForUpdatedObjects(backingContext: self.localStoreMOC!) ?? []
                deletedCKRecordIDs = try changeSetHandler.recordIDsForDeletedObjects(self.localStoreMOC!) ?? []
            } catch {
                executeError = error
            }
        }
        if let error = executeError {
            throw error
        }
        let insertedIds = insertedOrUpdatedCKRecords.map {$0.recordID.recordName}
        let deletedIds = deletedCKRecordIDs.map {$0.recordName}
        SMStore.logger?.debug("Local insert/update changes detected: \(insertedOrUpdatedCKRecords.count) insertedOrUpdated\n\(insertedIds)")
        SMStore.logger?.debug("Local delete changes detected: \(deletedCKRecordIDs.count) deleted\n\(deletedIds)")
        return LocalChanges(insertedOrUpdatedCKRecords: insertedOrUpdatedCKRecords, deletedCKRecordIDs: deletedCKRecordIDs)
    }
    
    func fetchRecordChangesFromServer() -> (insertedOrUpdatedCKRecords: Array<CKRecord>, deletedRecordIDs: Array<CKRecord.ID>) {
        var syncOperationError: Error? = nil
        
        let token = SMServerTokenHandler.defaultHandler.token()
        let recordZoneID = CKRecordZone.ID(zoneName: SMStore.SMStoreCloudStoreCustomZoneName, ownerName: CKCurrentUserDefaultName)
        if let token = token {
            SMStore.logger?.debug("OK Will fetch server changes with previousServerChangeToken=\(token)")
        } else {
             SMStore.logger?.debug("No previous change token")
        }
        let fetchRecordChangesOperation = CKFetchRecordZoneChangesOperation()
        fetchRecordChangesOperation.recordZoneIDs = [recordZoneID]
        /* By Tifroz: the commented code below (fetchRecordChangesOperation.configurationsByRecordZoneID) doesn't work at all - at least on iOS12
         1/ previousServerChangeToken does not seem to be taken into account
         2/ seems to mess with zone subscriptions (in particular, delete notification 'recordWithIDWasDeletedBlock' does not get called
        */
        /*if #available(iOS 12.0, watchOS 5.0, macOS 10.14, tvOS 12.0, *) {
         fetchRecordChangesOperation.configurationsByRecordZoneID?[recordZoneID] = CKFetchRecordZoneChangesOperation.ZoneConfiguration(previousServerChangeToken: token, resultsLimit: nil, desiredKeys: nil)
         } else {
        }*/
        let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
        options.previousServerChangeToken = token
        var optionsByRecordZoneID = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions]()
        optionsByRecordZoneID[recordZoneID] = options
        fetchRecordChangesOperation.optionsByRecordZoneID = optionsByRecordZoneID
        fetchRecordChangesOperation.database = self.database

        var insertedOrUpdatedCKRecords: [CKRecord] = [CKRecord]()
        var deletedCKRecordIDs: [CKRecord.ID] = [CKRecord.ID]()
        fetchRecordChangesOperation.recordZoneFetchCompletionBlock = { recordZoneID, serverChangeToken, clientChangeTokenData, moreComing, recordZoneError in
            SMStore.logger?.debug("OK (sync operation) recordZoneFetchCompletionBlock called with serverChangeToken=\(String(describing: serverChangeToken)), clientChangeTokenData=\(String(describing: clientChangeTokenData))")
            guard let token = serverChangeToken, recordZoneError == nil else {
                syncOperationError = recordZoneError
                return
            }
            SMServerTokenHandler.defaultHandler.save(serverChangeToken: token)
        }
        fetchRecordChangesOperation.recordZoneChangeTokensUpdatedBlock = { recordZoneID, serverChangeToken, clientChangeTokenData in
            SMStore.logger?.debug("OK (sync operation) recordZoneChangeTokensUpdatedBlock called with serverChangeToken=\(String(describing: serverChangeToken)), clientChangeTokenData=\(String(describing: clientChangeTokenData))")
            if let token = serverChangeToken {
                SMServerTokenHandler.defaultHandler.save(serverChangeToken: token)
            }
        }
        fetchRecordChangesOperation.fetchRecordZoneChangesCompletionBlock = { error in
            if error != nil {
                syncOperationError = error
            } else {
                SMStore.logger?.info("OK (sync operation) fetchRecordZoneChangesCompletionBlock returned with no error")
            }
        }
        
        fetchRecordChangesOperation.recordChangedBlock = { record in
            let ckRecord = record as CKRecord
            insertedOrUpdatedCKRecords.append(ckRecord)
            SMStore.logger?.debug("OK (sync operation) recordChangedBlock called for record: \(ckRecord.recordID.recordName)")
        }
        fetchRecordChangesOperation.recordWithIDWasDeletedBlock = { recordID, recordType in
            deletedCKRecordIDs.append(recordID as CKRecord.ID)
            SMStore.logger?.debug("OK (sync operation) recordWithIDWasDeletedBlock called for record: \(recordID.recordName)")
        }
        self.operationQueue!.addOperation(fetchRecordChangesOperation)
        self.operationQueue!.waitUntilAllOperationsAreFinished()
        if syncOperationError == nil {
            
            if !insertedOrUpdatedCKRecords.isEmpty {
                let recordIDs: [CKRecord.ID] = insertedOrUpdatedCKRecords.map { record in
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
                
                // Split the record IDs into multiple batches of 400 elements each, because
                // this is the maximum number of items possible in a single fetch request.
                if let splitRecordIDs = self.splitArray(recordIDs, maximumNumberOfItems: 400) as? [[CKRecord.ID]] {
                    for recordIDs in splitRecordIDs {
                        let fetchRecordsOperation: CKFetchRecordsOperation = CKFetchRecordsOperation(recordIDs: recordIDs)
                        fetchRecordsOperation.desiredKeys = desiredKeys
                        fetchRecordsOperation.database = self.database
                        fetchRecordsOperation.fetchRecordsCompletionBlock =  { recordsByRecordID,operationError in
                            if operationError == nil && recordsByRecordID != nil {
                                insertedOrUpdatedCKRecords.append(contentsOf: recordsByRecordID!.values)
                            }
                        }
                        self.operationQueue.addOperation(fetchRecordsOperation)
                        self.operationQueue.waitUntilAllOperationsAreFinished()
                    }
                }
            }
            
        } else {
            if let error = syncOperationError as? CKError {
                if error.code == .changeTokenExpired {
                    SMServerTokenHandler.defaultHandler.delete()
                    return self.fetchRecordChangesFromServer()
                }
            }
        }
        let insertedIds = insertedOrUpdatedCKRecords.map {$0.recordID.recordName}
        let deletedIds = deletedCKRecordIDs.map {$0.recordName}
        SMStore.logger?.debug("OK (sync operation) cloud changes detected: \(insertedOrUpdatedCKRecords.count) insertedOrUpdated\n\(insertedIds)")
        SMStore.logger?.debug("OK (sync operation) cloud changes detected: \(deletedCKRecordIDs.count) deleted\n\(deletedIds)")
        
        return (insertedOrUpdatedCKRecords, deletedCKRecordIDs)
    }
    
    func insertOrUpdateManagedObjects(fromCKRecords ckRecords:Array<CKRecord>) throws {
        var deferredRecords = [CKRecord]()
        
        // Sorting records using the dependancy graph can cut down dramatically ...
        //  ...the number of deferred attempts necessary (see deferredRecords)
        let sorted = SMObjectDependencyGraph(records: ckRecords, for: entities).sorted as! [CKRecord]
        for record in sorted {
            do {
                let _ = try record.createOrUpdateManagedObjectFromRecord(usingContext: self.localStoreMOC!)
            } catch SMStoreError.missingRelatedObject {
                deferredRecords.append(record)
            } catch SMStoreError.ckRecordInvalid(let record, let missingAttributes) {
                // It would be preferable to delegate the handling of this error through a delegate call. For now just log'n forget
                SMStore.logger?.error("CKRecord '\(record.recordType)' (recordName=\(record.recordID.recordName)), is missing non-optional attributes (\(missingAttributes)). Will skip record")
            } catch SMStoreError.backingStoreIndividualRecordSaveError(let cause) {
                // It would be preferable to delegate the handling of this error through a delegate call. For now just log'n forget
                SMStore.logger?.error("Will skip CKRecord '\(record.recordType)' (recordName \(record.recordID.recordName)).\n\nreason=\(cause.localizedDescription)")
            }
            // Don't save the MOC here: rolling up all the saves into a single one will prevent saving data in an inconsistent save
            // All saves are now performed in 'applyServerChangesToLocalDatabase()'
        }
        
        if deferredRecords.count == 0 {
            return // We are done inserting/updating records
        
        } else if deferredRecords.count < ckRecords.count {
            SMStore.logger?.info("\(deferredRecords.count) records could not be inserted or updated due to missing references. Will try again")
            try self.insertOrUpdateManagedObjects(fromCKRecords: deferredRecords)
        
        } else {
            for record in deferredRecords {
                SMStore.logger?.error("ERROR will skip record \(record.recordID.recordName) of type '\(record.recordType)' (missing references: record has dependencies on other related records, which could not be found).")
            }
        }
    }
    
    func deleteManagedObjects(fromCKRecordIDs ckRecordIDs:Array<CKRecord.ID>) throws {
        if !ckRecordIDs.isEmpty {
            let predicate = NSPredicate(format: "%K IN $ckRecordIDs",SMStore.SMLocalStoreRecordIDAttributeName)
            let ckRecordIDStrings = ckRecordIDs.map({(object)->String in
                let ckRecordID:CKRecord.ID = object
                return ckRecordID.recordName
            })
            let entityNames = self.entities.map { (entity) in
                return entity.name!
            }
            for name in entityNames {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name as String)
                //fetchRequest.predicate = NSPredicate.
                let _ = try self.localStoreMOC.fetch(fetchRequest) as! [NSManagedObject]
                fetchRequest.predicate = predicate.withSubstitutionVariables(["ckRecordIDs":ckRecordIDStrings])
                let results = try self.localStoreMOC.fetch(fetchRequest)
                if !results.isEmpty {
                    for object in results as! [NSManagedObject] {
                        self.localStoreMOC.delete(object)
                    }
                }
            }
        }
        // Don't save the MOC here: rolling up all the saves into a single one will prevent saving data in an inconsistent save
        // All saves are now performed in 'applyServerChangesToLocalDatabase()'
    }
    
    // MARK: Helpers
    private func splitArray(_ array: Array<Any>, maximumNumberOfItems: Int) -> [[Any]] {
        return stride(from: 0, to: array.count, by: maximumNumberOfItems).map {
            Array(array[$0 ..< Swift.min($0 + maximumNumberOfItems, array.count)])
        }
    }
}
