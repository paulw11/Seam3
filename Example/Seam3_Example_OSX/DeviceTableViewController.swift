//
//  DeviceTableViewController.swift
//  Seam3
//
//  Created by Paul Wilkinson on 20/2/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Cocoa
import Seam3

class DeviceTableViewController: NSViewController {

    @IBOutlet weak var tableview: NSTableView!
    
    var managedObjectContext: NSManagedObjectContext!
    var devices: [Device]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        self.managedObjectContext = appDelegate.managedObjectContext
        
        self.loadData()
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: SMStoreNotification.SyncDidFinish), object: nil, queue: nil) { notification in
            
            if notification.userInfo != nil {
                let appDelegate = NSApplication.shared.delegate as! AppDelegate
                appDelegate.smStore?.triggerSync(complete: true)
            }
            
            self.managedObjectContext?.refreshAllObjects()
            
            DispatchQueue.main.async {
                self.loadData()
            }
        }
        
       /* self.tableview.autoresizingMask = .viewWidthSizable
        self.tableview.tableColumns[0].resizingMask = .autoresizingMask
        self.tableview.tableColumns[0].sizeToFit()*/
        
    }
    
    func loadData() {
        
        
        let deviceFetchRequest = Device.fetchRequest() as NSFetchRequest<Device>
        
        let sortDescriptor = NSSortDescriptor(key: "deviceID", ascending: false)
        
        deviceFetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            if let devices = try self.managedObjectContext?.fetch(deviceFetchRequest) {
                self.devices = devices
            }
            
            self.tableview.reloadData()
            
        } catch {}
    }
    
}

extension DeviceTableViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.devices?.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let device = self.devices![row]
        if tableColumn == tableView.tableColumns[0] {
            return device.deviceID
        } else {
            
            var returnImage: NSImage?
            
            if let imageData = device.image {
                returnImage = NSImage(data: imageData as Data)
            }
            return returnImage
        }
    }
    
}
