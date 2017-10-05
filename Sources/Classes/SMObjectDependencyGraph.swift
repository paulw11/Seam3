//
//  SMObjectDependencyGraph.swift
//
//  Created by hugo on 9/29/17.
//

import Foundation
import CoreData

class SMObjectDependencyGraph {
  private var unsorted: [NSManagedObject]
  private var ancestorGraph = [String:[[String]]]()
  
  init(objects: [NSManagedObject]) {
    unsorted = objects
    var dependencyGraph: [String:Set<String>] = [:]
    
    for o in unsorted {
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
    
    func recursivelyMakeDependencyChains(chain: [String]) -> [[String]] {
      if let last = chain.last, let dependencies = dependencyGraph[last], dependencies.count > 0 {
        var chains = [[String]]()
        for dependency in dependencies {
          var augmentedChain = chain
          if chain.contains(dependency) {
            print("WARNING Loop Detected! Path \(chain) already contains '\(dependency)'")
            chains.append(chain)
          } else {
            augmentedChain.append(dependency)
            for chainFromNextRecursiveIteration in recursivelyMakeDependencyChains(chain: augmentedChain) {
              chains.append(chainFromNextRecursiveIteration)
            }
          }
        }
        return chains
      } else {
        return [chain]
      }
    }
    
    
    for entityName in dependencyGraph.keys {
      ancestorGraph[entityName] = recursivelyMakeDependencyChains(chain: [entityName])
    }
  }
  
  var sorted: [NSManagedObject] {
    let results = unsorted.sorted { (o1:NSManagedObject, o2:NSManagedObject) -> Bool in
      if let entityName1 = o1.entity.name, let chains1 = ancestorGraph[entityName1] {
        if let entityName2 = o2.entity.name, let chains2 = ancestorGraph[entityName2] {
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
          
          if entityName2 == entityName1 {
            let identifier1 = o1.objectID.uriRepresentation().absoluteString
            let identifier2 = o2.objectID.uriRepresentation().absoluteString
            // Different instances, same entity: order doesn't matter but we must be consistent across instances (assuming no cycles in dependency chains)
            return identifier1 < identifier2
          } else {
            // Different entities, doesn't really matter as long as we are consistent across chains
            let root1 = chains1.last!.last!
            let root2 = chains2.last!.last!
            return root1 < root2
          }
        } else {
          return false      // o1 after o2
        }
      } else {
        return true         // o1 before o2
      }
    }
    /*let debugArray = results.map { (object: NSManagedObject) -> String in
      return object.entity.name ?? "(Entity Has No Name)"
    }
    print("OK sorted = \(debugArray)")*/
    return results
  }
}
