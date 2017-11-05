//
//    SMObjectDependencyGraph.swift
//    Created by hugo on 9/29/17.
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

class SMObjectDependencyGraph {
  private var unsorted: [SMObject]
  private var ancestorGraph = [String:[[String]]]()
  private var dependencyGraph: [String:Set<String>] = [:]
  
  init(records: [CKRecord], for entities: [NSEntityDescription]) {
    unsorted = records
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
            //print("\(entityName2) depends on \(entityName1)")
            return true
          }
        }
        for chain1 in chains1 {
          if chain1.contains(entityName2) {
            // o1 is dependent on o2
            //print("\(entityName1) depends on \(entityName1)")
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
    
    let results = unsorted.sorted { (o1:SMObject, o2:SMObject) -> Bool in
      
      if o2.entityIdentifier == o1.entityIdentifier {
        // Different instances, same entity: order doesn't matter but we must be consistent across instances (assuming no cycles in dependency chains)
        return o1.instanceIdentifier < o2.instanceIdentifier
      }
      
      if let index1 = sortedEntityNames.index(of: o1.entityIdentifier), let index2 = sortedEntityNames.index(of: o2.entityIdentifier) {
        // Same order as entities
        return index2 > index1
      }
      print("WARNING Entity '\(o1.entityIdentifier)' or '\(o2.entityIdentifier)' not referenced in sortedEntityNames (this should never happen)")
      return false
    }
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


protocol SMObject {
  var entityIdentifier: String {get}
  var instanceIdentifier: String {get}
}

extension NSManagedObject: SMObject {
  var entityIdentifier: String {
    return entity.name!
  }
  var instanceIdentifier: String {
    return objectID.uriRepresentation().absoluteString
  }
}

extension CKRecord: SMObject {
  var entityIdentifier: String {
    return recordType
  }
  var instanceIdentifier: String {
    return recordID.recordName
  }
}
