//    SMServerStoreSetupOperation.swift
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

class SMServerStoreSetupOperation:Operation {
    
    var database:CKDatabase?
    var setupOperationCompletionBlock:((_ customZoneCreated:Bool,_ customZoneSubscriptionCreated:Bool,_ error: Error?)->Void)?
    
    init(cloudDatabase:CKDatabase?) {
        self.database = cloudDatabase
        super.init()
    }
    
    override func main() {
        let operationQueue = OperationQueue()
        let zone = CKRecordZone(zoneName: SMStore.SMStoreCloudStoreCustomZoneName)
        var error: Error?
        var customZoneCreated = false
        var subscriptionCreated = false
        
        let defaults = UserDefaults.standard
        
        let fetchRecordZonesOperation = CKFetchRecordZonesOperation(recordZoneIDs: [zone.zoneID])
        if #available(iOS 11.0, tvOS 11.0, OSX 10.13, *) {
          let config = CKOperation.Configuration()
          config.timeoutIntervalForResource = 10.0
          fetchRecordZonesOperation.configuration = config
        } else if #available(iOS 10.0, tvOS 11.0, OSX 10.12, *) {
          fetchRecordZonesOperation.timeoutIntervalForResource = 10.0
        }
        fetchRecordZonesOperation.database = self.database
        
        fetchRecordZonesOperation.fetchRecordZonesCompletionBlock = ({(zones,operationError) -> Void in
            
            error = operationError
            var ckError = operationError as? CKError
            
            if ckError?.partialErrorsByItemID != nil {
                ckError = ckError?.partialErrorsByItemID?.values.first as? CKError
            }
            
            if error == nil || ckError?.code == .zoneNotFound || ckError?.code == .userDeletedZone {
                error = nil
                if zones?.first == nil {
                    
                    let modifyRecordZonesOperation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
                    modifyRecordZonesOperation.database = self.database
                    modifyRecordZonesOperation.modifyRecordZonesCompletionBlock = ({(savedRecordZones, deletedRecordZonesIDs, operationError) -> Void in
                        error = operationError
                        
                        if operationError == nil {
                            customZoneCreated = true
                            defaults.set(true, forKey: SMStore.SMStoreCloudStoreCustomZoneName)
                        }
                    })
                    operationQueue.addOperation(modifyRecordZonesOperation)
                } else {
                    customZoneCreated = true
                    defaults.set(true, forKey: SMStore.SMStoreCloudStoreCustomZoneName)
                }
            }
        })
        
        operationQueue.addOperation(fetchRecordZonesOperation)
        operationQueue.waitUntilAllOperationsAreFinished()
        
        #if !os(watchOS)
        if error == nil {
            
            let fetchSubscription = CKFetchSubscriptionsOperation(subscriptionIDs: [SMStore.SMStoreCloudStoreSubscriptionName])
            
            fetchSubscription.database = self.database
            
            fetchSubscription.fetchSubscriptionCompletionBlock = ({(subscriptions,operationError)->Void in
                error = operationError
                var ckError = operationError as? CKError
                
                if ckError?.partialErrorsByItemID != nil {
                    ckError = ckError?.partialErrorsByItemID?.values.first as? CKError
                }
                if operationError == nil || ckError?.code == .unknownItem {
                    if subscriptions?.first == nil {
                        let recordZoneID = CKRecordZone.ID.smCloudStoreCustomZoneID()
                        let subscription = CKRecordZoneSubscription(zoneID: recordZoneID, subscriptionID: SMStore.SMStoreCloudStoreSubscriptionName)
                        
                        let subscriptionNotificationInfo = CKSubscription.NotificationInfo()
                        subscriptionNotificationInfo.shouldSendContentAvailable = true
                        subscription.notificationInfo = subscriptionNotificationInfo
                        if #available(iOS 9.0, tvOS 10.0, *) {
                            subscriptionNotificationInfo.shouldBadge = false
                        }
                        
                        let subscriptionsOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
                        subscriptionsOperation.database = self.database
                        subscriptionsOperation.modifySubscriptionsCompletionBlock=({ (modified,created,operationError) -> Void in
                            if operationError == nil {
                                UserDefaults.standard.set(true, forKey: SMStore.SMStoreCloudStoreSubscriptionName)
                                subscriptionCreated = true
                            }
                            error = operationError
                        })
                        operationQueue.addOperation(subscriptionsOperation)
                    } else {
                        subscriptionCreated = true
                        defaults.set(true, forKey: SMStore.SMStoreCloudStoreSubscriptionName)
                    }
                }
            })
            
            operationQueue.addOperation(fetchSubscription)
            operationQueue.waitUntilAllOperationsAreFinished()
        }
        #endif
        
        if let completionBlock = self.setupOperationCompletionBlock {
            completionBlock(customZoneCreated,subscriptionCreated,error)
        }
    }
}
