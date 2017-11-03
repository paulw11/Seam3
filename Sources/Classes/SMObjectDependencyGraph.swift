//
//  SMObjectDependencyGraph.swift
//
//  Created by hugo on 9/29/17.
//

import Foundation
import CoreData
import CloudKit

class SMObjectDependencyGraph {
  private var unsorted: [Any]
  private var ancestorGraph = [String:[[String]]]()
  //private var sortedEntityNames = [String]()
  private var dependencyGraph: [String:Set<String>] = [:]
  
  init(records: [CKRecord], for entities: [NSEntityDescription]) {
    unsorted = records
    //var dependencyGraph: [String:Set<String>] = [:]
    
    for r in records {
      let entityName = r.recordType
      let entity = entities.first(where: { (entityDesc: NSEntityDescription) -> Bool in
        entityDesc.name == entityName
      })
      if let entity = entity, dependencyGraph[entityName] == nil {
        dependencyGraph[entityName] = Set<String>()
        for property in entity.properties {
          if let relationship = property as? NSRelationshipDescription, !relationship.isToMany {
            if let destinationName = relationship.destinationEntity?.name {
              dependencyGraph[entityName]?.insert(destinationName)
            }
          }
        }
      }
    }
    
    for entityName in dependencyGraph.keys {
      ancestorGraph[entityName] = SMObjectDependencyGraph.recursivelyMakeDependencyChains(chain: [entityName], dependencyGraph: dependencyGraph)
    }
  }
  
  init(objects: [NSManagedObject]) {
    unsorted = objects
    //var dependencyGraph: [String:Set<String>] = [:]
    
    for o in objects {
      if let entityName = o.entity.name, dependencyGraph[entityName] == nil {
        dependencyGraph[entityName] = Set<String>()
        for property in o.entity.properties {
          if let relationship = property as? NSRelationshipDescription, !property.isOptional {
            if let destinationName = relationship.destinationEntity?.name {
              dependencyGraph[entityName]?.insert(destinationName)
            }
          }
        }
      }
    }
    
    for entityName in dependencyGraph.keys {
      ancestorGraph[entityName] = SMObjectDependencyGraph.recursivelyMakeDependencyChains(chain: [entityName], dependencyGraph: dependencyGraph)
    }
  }
  
  var sorted: [Any] {
    
    let sortedEntityNames = dependencyGraph.keys.sorted(by: { (entityName1: String, entityName2: String) -> Bool in
      if let chains1 = ancestorGraph[entityName1], let chains2 = ancestorGraph[entityName2] {
        
        for chain2 in chains2 {
          if chain2.contains(entityName1) {
            // o2 is dependent on o1
            print("\(entityName2) depends on \(entityName1)")
            return true
          }
        }
        for chain1 in chains1 {
          if chain1.contains(entityName2) {
            // o1 is dependent on o2
            print("\(entityName1) depends on \(entityName1)")
            return false
          }
        }
        
        // Finally if chains don't intersect, it doesn't really matter as long as we are consistent across chains
        let root1 = chains1.last!.last!
        let root2 = chains2.last!.last!
        return root1 < root2
      }
      return false // This should never happen
    })
    
    let results = unsorted.sorted { (o1:Any, o2:Any) -> Bool in
      var entityName1: String!
      var entityName2: String!
      var instanceIdentifier1: String!
      var instanceIdentifier2: String!
      if let mo1 = o1 as? NSManagedObject,  let mo2 = o2 as? NSManagedObject {
        entityName1 = mo1.entity.name
        entityName2 = mo2.entity.name
        instanceIdentifier1 = mo1.objectID.uriRepresentation().absoluteString
        instanceIdentifier2 = mo2.objectID.uriRepresentation().absoluteString
      } else if let ro1 = o1 as? CKRecord,  let ro2 = o2 as? CKRecord {
        entityName1 = ro1.recordType
        entityName2 = ro2.recordType
        instanceIdentifier1 = ro1.recordID.recordName
        instanceIdentifier2 = ro2.recordID.recordName
      }
      
      if entityName2 == entityName1 {
        // Different instances, same entity: order doesn't matter but we must be consistent across instances (assuming no cycles in dependency chains)
        return instanceIdentifier1 < instanceIdentifier2
      }
      
      if let index1 = sortedEntityNames.index(of: entityName1), let index2 = sortedEntityNames.index(of: entityName2) {
        // Same order as entities
        return index2 > index1
      }
      
      print("WARNING Entity '\(entityName1)' or '\(entityName2)' not referenced in sortedEntityNames (this should never happen)")
      return false

      
    }
    /*let debugArray = results.map { (object: NSManagedObject) -> String in
      return object.entity.name ?? "(Entity Has No Name)"
    }
    print("OK sorted = \(debugArray)")*/
    return results
  }
  
  fileprivate class func recursivelyMakeDependencyChains(chain: [String], dependencyGraph: [String:Set<String>]) -> [[String]] {
    if let last = chain.last, let dependencies = dependencyGraph[last], dependencies.count > 0 {
      var chains = [[String]]()
      for dependency in dependencies {
        var augmentedChain = chain
        if chain.contains(dependency) {
          print("WARNING Loop Detected! Path \(chain) already contains '\(dependency)'")
          chains.append(chain)
        } else {
          augmentedChain.append(dependency)
          for chainFromNextRecursiveIteration in recursivelyMakeDependencyChains(chain: augmentedChain, dependencyGraph: dependencyGraph) {
            chains.append(chainFromNextRecursiveIteration)
          }
        }
      }
      return chains
    } else {
      return [chain]
    }
  }
}
