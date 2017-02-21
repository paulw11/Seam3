//
//  EventTableViewController.swift
//  Seam3
//
//  Created by Paul Wilkinson on 20/2/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Cocoa
import Seam3

class EventTableViewController: NSViewController {

    @IBOutlet weak var tableview: NSTableView!
    
    var managedObjectContext: NSManagedObjectContext!
    var events: [Event]?
    var appDelegate: AppDelegate!
    
    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        appDelegate = NSApplication.shared().delegate as! AppDelegate
        self.managedObjectContext = appDelegate.managedObjectContext
        
        self.loadData()
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: SMStoreNotification.SyncDidFinish), object: nil, queue: nil) { notification in
            
            if notification.userInfo != nil {
                let appDelegate = NSApplication.shared().delegate as! AppDelegate
                appDelegate.smStore?.triggerSync(complete: true)
            }
            
            self.managedObjectContext?.refreshAllObjects()
            
            DispatchQueue.main.async {
                self.loadData()
            }
        }
        
    }
    
    func loadData() {
        
        
        let fetchRequest = Event.fetchRequest() as NSFetchRequest<Event>
        
        let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            if let events = try self.managedObjectContext?.fetch(fetchRequest) {
                self.events = events
            }
            
            self.tableview.reloadData()
            
        } catch {}
    }
    
    @IBAction func eventAdd(_ sender: NSButton) {
        if let context = self.managedObjectContext {
            
            let newEvent: Event
            
            if #available(OSX 10.12, *) {
                newEvent = Event(context: context)
            } else {
                newEvent = NSEntityDescription.insertNewObject(forEntityName: "Event", into: context) as! Event
            }
            
            newEvent.timestamp = NSDate()
            newEvent.creatingDevice = self.appDelegate.device
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
}

extension EventTableViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.events?.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let event = self.events![row]
        if tableColumn == tableView.tableColumns[0] {
            let dateString = self.dateFormatter.string(from: event.timestamp as! Date)
            return dateString
        } else {
            return "\(event.intAttribute)"
        }
    }
    
}
