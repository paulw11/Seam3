//    NSManagedObject+CKRecord.swift
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

extension NSManagedObject {
    fileprivate func setAttributesValues(ofCKRecord ckRecord:CKRecord, withValuesOfAttributeWithKeys keys: [String]?) {
        
        let attributes = keys ?? Array(self.entity.attributesByNameByRemovingBackingStoreAttributes().keys)
        
        let valuesDictionary = self.dictionaryWithValues(forKeys: attributes)
        for (key,_) in valuesDictionary {
            if let attributeDescription = self.entity.attributesByName[key] {
                let attrName = attributeDescription.name
            if  self.value(forKey: attributeDescription.name) != nil {
                switch(attributeDescription.attributeType) {
                case .stringAttributeType:
                    ckRecord.setObject(self.value(forKey: attrName) as! String as CKRecordValue?, forKey: attrName)
                case .dateAttributeType:
                    ckRecord.setObject(self.value(forKey: attrName) as! Date as CKRecordValue?, forKey: attrName)
                case .booleanAttributeType:
                    ckRecord.setObject(self.value(forKey: attrName) as! NSNumber, forKey: attrName)
                case .decimalAttributeType:
                    ckRecord.setObject(self.value(forKey: attrName) as! NSNumber, forKey: attrName)
                case .doubleAttributeType:
                    ckRecord.setObject(self.value(forKey: attrName) as! NSNumber, forKey: attrName)
                case .floatAttributeType:
                    ckRecord.setObject(self.value(forKey: attrName) as! NSNumber, forKey: attrName)
                case .integer16AttributeType:
                    ckRecord.setObject(self.value(forKey: attrName) as! NSNumber, forKey:attrName)
                case .integer32AttributeType:
                    ckRecord.setObject(self.value(forKey: attrName) as! NSNumber, forKey: attrName)
                case .integer64AttributeType:
                    ckRecord.setObject(self.value(forKey: attrName) as! NSNumber, forKey: attrName)
                case .binaryDataAttributeType:
                    if attributeDescription.allowsExternalBinaryDataStorage {
                        if let asset = self.createAsset(data: self.value(forKey: attrName) as! Data) {
                            ckRecord.setObject(asset, forKey:attrName)
                        }
                    } else {
                        ckRecord.setObject(self.value(forKey: attrName) as! Data as CKRecordValue?, forKey: attrName)
                    }
                default:
                    break
                }
            } else {
                ckRecord.setObject(nil, forKey: attrName)
            }
            }
        }
    }
    
    fileprivate func createAsset(data: Data) -> CKAsset? {
        
        var returnAsset: CKAsset? = nil
        
        let tempStr = ProcessInfo.processInfo.globallyUniqueString
        
        let filename = "\(tempStr)_file.bin"
        
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
        
        let fileURL = baseURL.appendingPathComponent(filename, isDirectory: false)
        
        do {
            try data.write(to: fileURL, options: [.atomicWrite])
            
            returnAsset = CKAsset(fileURL: fileURL)
            
        } catch {
            print("Error creating asset: \(error)")
        }
        
        return returnAsset
        
    }
    
    fileprivate func setRelationshipValues(ofCKRecord ckRecord:CKRecord, withValuesOfRelationshipWithKeys keys: [String]?) {
        var relationships: [String] = [String]()
        if keys != nil {
            relationships = keys!
        } else {
            relationships = Array(self.entity.toOneRelationshipsByName().keys)
        }
        for relationship in relationships {
            if let relationshipManagedObject = self.value(forKey: relationship) as? NSManagedObject {
                let recordIDString: String = relationshipManagedObject.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as! String
                let ckRecordZoneID: CKRecordZoneID = CKRecordZoneID.smCloudStoreCustomZoneID()
                let ckRecordID: CKRecordID = CKRecordID(recordName: recordIDString, zoneID: ckRecordZoneID)
                let ckReference: CKReference = CKReference(recordID: ckRecordID, action: CKReferenceAction.deleteSelf)
                ckRecord.setObject(ckReference, forKey: relationship)
            }
        }
    }
    
    public func createOrUpdateCKRecord(usingValuesOfChangedKeys keys: [String]?) -> CKRecord? {
        let encodedFields: Data? = self.value(forKey: SMStore.SMLocalStoreRecordEncodedValuesAttributeName) as? Data
        var ckRecord: CKRecord?
        if encodedFields != nil {
            ckRecord = CKRecord.recordWithEncodedFields(encodedFields!)
        } else {
            let recordIDString = self.value(forKey: SMStore.SMLocalStoreRecordIDAttributeName) as! String
            let ckRecordZoneID: CKRecordZoneID = CKRecordZoneID.smCloudStoreCustomZoneID()
            let ckRecordID: CKRecordID = CKRecordID(recordName: recordIDString, zoneID: ckRecordZoneID)
            ckRecord = CKRecord(recordType: self.entity.name!, recordID: ckRecordID)
        }
        if keys != nil {
            let attributeKeys = self.entity.attributesByName.filter { (object) -> Bool in
                return keys!.contains(object.0)
                }.map { (object) -> String in
                    return object.0
            }
            let relationshipKeys = self.entity.relationshipsByName.filter { (object) -> Bool in
                return keys!.contains(object.0)
                }.map { (object) -> String in
                    return object.0
            }
            self.setAttributesValues(ofCKRecord: ckRecord!, withValuesOfAttributeWithKeys: attributeKeys)
            self.setRelationshipValues(ofCKRecord: ckRecord!, withValuesOfRelationshipWithKeys: relationshipKeys)
            return ckRecord
        }
        self.setAttributesValues(ofCKRecord: ckRecord!, withValuesOfAttributeWithKeys: nil)
        self.setRelationshipValues(ofCKRecord: ckRecord!, withValuesOfRelationshipWithKeys: nil)
        return ckRecord
    }
}
