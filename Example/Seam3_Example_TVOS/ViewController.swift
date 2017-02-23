//
//  ViewController.swift
//  Seam_Example_TVOS
//
//  Created by Paul Wilkinson on 21/2/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import CoreData
import Seam3

class ViewController: UIViewController {

    @IBOutlet weak var eventsTableView: UITableView!
    @IBOutlet weak var devicesTableView: UITableView!
    
    var events: [Event]?
    var devices: [Device]?
    var managedObjectContext: NSManagedObjectContext?
    
    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()
    
    var tableTitles = [UITableView:String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.tableTitles[eventsTableView] = "Events"
        self.tableTitles[devicesTableView] = "Devices"
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.managedObjectContext = appDelegate.persistentContainer.viewContext
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: SMStoreNotification.SyncDidFinish), object: nil, queue: nil) { notification in
            
            if notification.userInfo != nil {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.smStore?.triggerSync(complete: true)
            }
            
            self.managedObjectContext?.refreshAllObjects()
            
            DispatchQueue.main.async {
                self.loadData()
            }
        }
        
        self.loadData()
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
            
            self.eventsTableView.reloadData()
            self.devicesTableView.reloadData()
            
        } catch {}
    }

}

extension ViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.devicesTableView {
            return self.devices?.count ?? 0
        } else {
            return self.events?.count ?? 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView ==  self.devicesTableView {
            return self.deviceTableView(tableView, cellForRowAt: indexPath)
        } else {
            return self.eventTableView(tableView, cellForRowAt: indexPath)
        }
    }
    
    func deviceTableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceTableViewCell
        
        let device = self.devices![indexPath.row]
        
        cell.idLabel.text = device.deviceID
        
        if let data = device.image as? Data {
        
            cell.deviceImage.image = UIImage(data: data)
        } else {
            cell.deviceImage.image = nil
        }
        
        
        return cell
        
    }
    
    func eventTableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EventCell", for: indexPath) as! EventTableViewCell
        
        let event = self.events![indexPath.row]
        
        if let date = event.timestamp as? Date {
            cell.eventLabel.text = self.dateFormatter.string(from: date)
        } else {
            cell.eventLabel.text = ""
        }
        
        
        return cell
        
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableTitles[tableView]
    }
    
}

