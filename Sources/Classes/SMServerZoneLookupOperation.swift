//
//    SMServerStoreLookupOperation.swift
//    Created by hugo on 10/5/17.
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
