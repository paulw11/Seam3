//
//  AppDelegate.swift
//  Seam3_Example_OSX
//
//  Created by Paul Wilkinson on 18/2/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Cocoa
import Seam3

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var smStore: SMStore?

    var device: Device?
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        NSApplication.shared().registerForRemoteNotifications(matching:[])

        let _ = self.persistentStoreCoordinator // Make sure SMStore is loaded
        
        self.validateCloudKitAndSync() {
             self.device = self.setupDeviceRecord()
        }
    }
    
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Registered for remote notifications")
    }
    
    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications \(error)")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        print("Recieved push")
        self.smStore?.handlePush(userInfo: userInfo)
    }
    
    func validateCloudKitAndSync(_ completion:@escaping (() -> Void)) {
        
        self.smStore?.verifyCloudKitConnectionAndUser() { (status, user, error) in
            guard status == .available, error == nil else {
                NSLog("Unable to verify CloudKit Connection \(error)")
                return
            }
            
            guard let currentUser = user else {
                NSLog("No current CloudKit user")
                return
            }
            
            var completeSync = false
            
            let previousUser = UserDefaults.standard.string(forKey: "CloudKitUser")
            if  previousUser != currentUser {
                do {
                    print("New user")
                    try self.smStore?.resetBackingStore()
                    completeSync = true
                } catch {
                    NSLog("Error resetting backing store - \(error.localizedDescription)")
                    return
                }
            }
            
            UserDefaults.standard.set(currentUser, forKey:"CloudKitUser")
            
            self.smStore?.triggerSync(complete: completeSync)
            
            completion()
        }
        
    }
    
    func setupDeviceRecord() -> Device?{
        
        let moc = self.managedObjectContext
        
        let deviceFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Device")
        
        let deviceID = self.macSerialNumber()
        
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
            let macImage = #imageLiteral(resourceName: "Mac")
            let cgImage = macImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            if let jpegData = bitmapRep.representation(using: NSBitmapImageFileType.JPEG, properties: [:]) {
                fetchedDevice!.image = jpegData as NSData
            }
            do {
                try moc.save()
                print("Created device id \(fetchedDevice!.deviceID!)")
            } catch {}
        }
        
        return fetchedDevice
    }
    
    func macSerialNumber() -> String {
        
        // Get the platform expert
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
        
        // Get the serial number as a CFString ( actually as Unmanaged<AnyObject>! )
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString!, kCFAllocatorDefault, 0);
        
        // Release the platform expert (we're responsible)
        IOObjectRelease(platformExpert);
        
        // Take the unretained value of the unmanaged-any-object
        // (so we're not responsible for releasing it)
        // and pass it back as a String or, if it fails, an empty string
        return (serialNumberAsCFString?.takeUnretainedValue() as? String) ?? ""
        
    }
    
    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: Foundation.URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.apple.toolsQA.CocoaApp_CD" in the user's Application Support directory.
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[urls.count - 1]
        return appSupportURL.appendingPathComponent("com.apple.toolsQA.CocoaApp_CD")
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "Seam3Demo", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.) This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        let fileManager = FileManager.default
        var failError: NSError? = nil
        var shouldFail = false
        var failureReason = "There was an error creating or loading the application's saved data."

        // Make sure the application files directory is there
        do {
            let properties = try self.applicationDocumentsDirectory.resourceValues(forKeys: [URLResourceKey.isDirectoryKey])
            if !properties.isDirectory! {
                failureReason = "Expected a folder to store application data, found a file \(self.applicationDocumentsDirectory.path)."
                shouldFail = true
            }
        } catch  {
            let nserror = error as NSError
            if nserror.code == NSFileReadNoSuchFileError {
                do {
                    try fileManager.createDirectory(atPath: self.applicationDocumentsDirectory.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    failError = nserror
                }
            } else {
                failError = nserror
            }
        }
        
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = nil
        if failError == nil {
            coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
            let url = self.applicationDocumentsDirectory.appendingPathComponent("Seam3Demo.storedata")
            do {
                let options:[String:Any] = [SMStore.SMStoreContainerOption:"iCloud.org.cocoapods.demo.Seam3-Example"]
                self.smStore = try coordinator!.addPersistentStore(ofType: SMStore.type, configurationName: nil, at: url, options: options) as? SMStore
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                 
                /*
                 Typical reasons for an error here include:
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                failError = error as NSError
            }
        }
        
        if shouldFail || (failError != nil) {
            // Report any error we got.
            if let error = failError {
                NSApplication.shared().presentError(error)
                fatalError("Unresolved error: \(error), \(error.userInfo)")
            }
            fatalError("Unsresolved error: \(failureReason)")
        } else {
            return coordinator!
        }
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving and Undo support

    @IBAction func saveAction(_ sender: AnyObject?) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        if !managedObjectContext.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                let nserror = error as NSError
                NSApplication.shared().presentError(nserror)
            }
        }
    }

    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return managedObjectContext.undoManager
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplicationTerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        
        if !managedObjectContext.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }
        
        if !managedObjectContext.hasChanges {
            return .terminateNow
        }
        
        do {
            try managedObjectContext.save()
        } catch {
            let nserror = error as NSError
            // Customize this code block to include application-specific recovery steps.
            let result = sender.presentError(nserror)
            if (result) {
                return .terminateCancel
            }
            
            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == NSAlertSecondButtonReturn {
                return .terminateCancel
            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
    }

}

