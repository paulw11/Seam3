//
//  AppDelegate.swift
//  Seam3
//
///    The MIT License (MIT)
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

import UIKit
import CoreData
import CloudKit
import Seam3

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    
    var window: UIWindow?
    
    var smStore: SMStore?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        
        let masterNavigationController = splitViewController.viewControllers[0] as! UINavigationController
        let controller = masterNavigationController.topViewController as! MasterViewController
        
        let container = self.persistentContainer
        
        controller.managedObjectContext = container.viewContext
        
        application.registerForRemoteNotifications()
        
        self.smStore = container.persistentStoreCoordinator.persistentStores.first as? SMStore
        
        // Uncomment the following block to use `clientTellsWhichWins` conflict resolution
        
        /* self.smStore?.recordConflictResolutionBlock =  ({(serverRecord, clientRecord, ancestorRecord) -> CKRecord in
         
         if let serverInt = serverRecord["intAttribute"] as? NSNumber,
         let clientInt = clientRecord["intAttribute"] as? NSNumber {
         
         if clientInt.intValue > serverInt.intValue {
         serverRecord["intAttribute"] = clientInt
         }
         
         }
         
         
         return serverRecord
         
         } )*/
        
        
        self.validateCloudKitAndSync() {
            let device = self.setupDeviceRecord()
            
            controller.device = device
        }
        
        return true
    }
    
    func validateCloudKitAndSync(_ completion:@escaping (() -> Void)) {
        
        self.smStore?.verifyCloudKitConnectionAndUser() { (status, user, error) in
            guard status == .available, error == nil else {
                NSLog("Unable to verify CloudKit Connection \(error!)")
                return
            }
            
            guard let currentUser = user else {
                NSLog("No current CloudKit user")
                return
            }
            
            if let previousUser = UserDefaults.standard.string(forKey: "CloudKitUser") {
                if  previousUser != currentUser  {
                    do {
                        print("New user")
                        try self.smStore?.resetBackingStore()
                    } catch {
                        NSLog("Error resetting backing store - \(error.localizedDescription)")
                        return
                    }
                }
            }
            
            UserDefaults.standard.set(currentUser, forKey:"CloudKitUser")
            
            self.smStore?.triggerSync(complete: true)
            
            completion()
        }
        
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        self.saveContext()
    }
    
    // MARK: - Split view
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
        if topAsDetailController.detailItem == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }
    
    // Mark: - Device record
    
    func setupDeviceRecord() -> Device?{
        
        let moc = self.persistentContainer.viewContext
        
        let deviceFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Device")
        
        let deviceID = UIDevice.current.identifierForVendor!.uuidString
        
        let predicate = NSPredicate(format: "deviceID == %@", deviceID)
        
        deviceFetch.predicate = predicate
        
        var fetchedDevice: Device? = nil
        
        do {
            if let fetchedDevices = try moc.fetch(deviceFetch) as? [Device] {
                if let device = fetchedDevices.first {
                    fetchedDevice = device
                    print("Retrieved device id \(fetchedDevice!.deviceID!)")
                    let moid = fetchedDevice!.objectID
                    print("moid=\(moid)")
                }
            }
        } catch {}
        
        if fetchedDevice == nil {
            fetchedDevice = NSEntityDescription.insertNewObject(forEntityName: "Device", into: moc) as? Device
            fetchedDevice!.deviceID = deviceID
            let 🐱 = #imageLiteral(resourceName: "kitten")
            if let data = UIImageJPEGRepresentation(🐱, 0.5) {
                fetchedDevice!.image = data 
            }
            do {
                try moc.save()
                print("Created device id \(fetchedDevice!.deviceID!)")
            } catch {}
        }
        
        return fetchedDevice
    }
    
    // MARK: - Remote notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Registered for remote notifications")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Remote notification registration failed")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Received push")

        smStore?.handlePush(userInfo: userInfo) { (result) in
            completionHandler(result.uiBackgroundFetchResult)
        }
    }
    
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        
        SMStore.registerStoreClass()
        
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Seam3Demo")
        
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        if let applicationDocumentsDirectory = urls.last {
            
            let url = applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
            
            let storeDescription = NSPersistentStoreDescription(url: url)
            
            storeDescription.type = SMStore.type
            
            storeDescription.setOption("iCloud.org.cocoapods.demo.Seam3-Example" as NSString, forKey: SMStore.SMStoreContainerOption)
            
            // Uncomment next line for "client wins" conflict resolution policy
            //storeDescription.setOption(NSNumber(value:SMSyncConflictResolutionPolicy.clientRecordWins.rawValue), forKey:SMStore.SMStoreSyncConflictResolutionPolicyOption)
            
            // Uncomment the next line for `clientTellsWhichWins` conflict resolution
            
            //   storeDescription.setOption(NSNumber(value:SMSyncConflictResolutionPolicy.clientTellsWhichWins.rawValue), forKey:SMStore.SMStoreSyncConflictResolutionPolicyOption)
            
            container.persistentStoreDescriptions=[storeDescription]
            
            container.loadPersistentStores(completionHandler: { (storeDescription, error) in
                if let error = error as NSError? {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    
                    /*
                     Typical reasons for an error here include:
                     * The parent directory does not exist, cannot be created, or disallows writing.
                     * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                     * The device is out of space.
                     * The store could not be migrated to the current model version.
                     Check the error message to determine what the actual problem was.
                     */
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            })
            return container
        }
        
        fatalError("Unable to access documents directory")
        
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
}

