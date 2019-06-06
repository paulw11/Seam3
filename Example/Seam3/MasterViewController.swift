//
//  MasterViewController.swift
//
//    The MIT License (MIT)
//
//    Copyright (c) 2016 Paul Wilkinson ( https://github.com/paulw11 )
//
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
import Seam3

class MasterViewController: UITableViewController, NSFetchedResultsControllerDelegate {

    var detailViewController: DetailViewController? = nil
    var managedObjectContext: NSManagedObjectContext? = nil
    var device: Device?
    var events = [Event]()
    var devices = [Device]()
    
    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }()


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.leftBarButtonItem = self.editButtonItem

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
        self.navigationItem.rightBarButtonItem = addButton
        self.loadData()
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        NotificationCenter.default.addObserver(forName: .smSyncDidFinish, object: nil, queue: nil) { notification in
            
            if notification.userInfo != nil {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.smStore?.triggerSync(complete: true)
            }
            
            self.managedObjectContext?.refreshAllObjects()
            
            DispatchQueue.main.async {
                self.loadData()
            }
        }
    }

    
    
    override func viewWillAppear(_ animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadData() {
        
        
        let deviceFetchRequest = Device.fetchRequest() as NSFetchRequest<Device>
        
        
        let fetchRequest = Event.fetchRequest() as NSFetchRequest<Event>
        
        let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            if let devices = try self.managedObjectContext?.fetch(deviceFetchRequest) {
                self.devices = devices
            }
            
            if let events = try self.managedObjectContext?.fetch(fetchRequest){
                self.events = events
               
            }
            
            self.tableView.reloadData()
            
        } catch {}
    }
    

    @objc func insertNewObject(_ sender: Any) {
        if let context = self.managedObjectContext {
            let newEvent = Event(context: context)
            
            // If appropriate, configure the new managed object.
            newEvent.timestamp = Date()
            newEvent.creatingDevice = self.device
            // Save the context.
            do {
                try context.save()
                self.loadData()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // MARK: - Segues

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if let indexPath = self.tableView.indexPathForSelectedRow {
            if indexPath.section == 0 {
                return true
            }
        }
        
        return false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
            let object = self.events[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = object
                controller.managedObjectContext = self.managedObjectContext!
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return self.events.count
        } else {
            return self.devices.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell
        
        if indexPath.section == 0 {
            cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            let event = self.events[indexPath.row]
            self.configureCell(cell, withEvent: event)
        } else {
            let deviceCell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceTableViewCell
            let device = self.devices[indexPath.row]
            self.configureCell(deviceCell, withDevice: device)
            cell = deviceCell
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return indexPath.section == 0
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let context = self.managedObjectContext {
                context.delete(self.events[indexPath.row])
                
                do {
                    try context.save()
                } catch {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    let nserror = error as NSError
                    fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                }
                self.events.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Events"
        } else {
            return "Devices"
        }
    }

    func configureCell(_ cell: UITableViewCell, withEvent event: Event) {
        if let timestamp = event.timestamp {
            let dateString = self.dateFormatter.string(from: timestamp as Date)
            cell.textLabel!.text = dateString
        } else {
            cell.textLabel!.text = "Missing timestamp!"
        }
    }
    
    func configureCell(_ cell: DeviceTableViewCell, withDevice device: Device) {
        cell.deviceLabel!.text = device.deviceID ?? "Missing device id"
        if let imageData = device.image {
            cell.deviceImage.image = UIImage(data: imageData as Data)
        } else {
            cell.deviceImage.image = nil
        }
    }
    
}

