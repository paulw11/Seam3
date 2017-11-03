//
//  SMServerStoreLookupOperation.swift
//  Seam3_Example
//
//  Created by hugo on 10/5/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import CloudKit

class SMServerZoneLookupOperation:Operation {
  
  var database:CKDatabase?
  var lookupOperationCompletionBlock:((_ customZoneExists:Bool,_ error: Error?)->Void)?
  
  init(cloudDatabase:CKDatabase?) {
    self.database = cloudDatabase
    super.init()
  }
  
  override func main() {
    
    let zone = CKRecordZone(zoneName: SMStore.SMStoreCloudStoreCustomZoneName)
    var error: Error?
    var customZoneExists = false
    let operationQueue = OperationQueue()
    let fetchRecordZonesOperation = CKFetchRecordZonesOperation(recordZoneIDs: [zone.zoneID])
    
    fetchRecordZonesOperation.database = self.database
    
    fetchRecordZonesOperation.fetchRecordZonesCompletionBlock = ({(zones,operationError) -> Void in
      
      error = operationError
      var ckError = operationError as? CKError
      
      if ckError?.partialErrorsByItemID != nil {
        ckError = ckError?.partialErrorsByItemID?.values.first as? CKError
      }
      
      customZoneExists = (ckError?.code != .zoneNotFound)
      if ckError?.code == .zoneNotFound {
        error = nil
      }
    })
    
    operationQueue.addOperation(fetchRecordZonesOperation)
    operationQueue.waitUntilAllOperationsAreFinished()
    if let completion = self.lookupOperationCompletionBlock {
      completion(customZoneExists, error)
    }
  }
}
