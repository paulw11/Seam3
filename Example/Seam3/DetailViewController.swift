//
//  DetailViewController.swift
//  CoreDataTest
//
//  Created by Paul Wilkinson on 1/12/16.
//  Copyright © 2016 Paul Wilkinson. All rights reserved.
//

import UIKit
import CoreData

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var integerTextField: UITextField!
    @IBOutlet weak var stringTextField: UITextField!
    @IBOutlet weak var creatingDeviceField: UILabel!

    var managedObjectContext: NSManagedObjectContext!

    func configureView() {
        // Update the user interface for the detail item.
        if let detail = self.detailItem {
            self.detailDescriptionLabel.text = detail.timestamp!.description
            self.integerTextField.text = String(detail.intAttribute)
            self.stringTextField.text = detail.stringAttribute ?? "<nil>"
            self.creatingDeviceField.text = detail.creatingDevice?.deviceID
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
         if let detail = self.detailItem {
            detail.stringAttribute = self.stringTextField.text
            if let number = Int16(self.integerTextField.text!) {
                detail.intAttribute = number
            }
            
            if detail.hasChanges {
                do {
                    try self.managedObjectContext.save()
                } catch {
                    print("Error saving: \(error)")
                }
            }
        }
    }

    var detailItem: Event? {
        didSet {
            // Update the view.
            if self.detailDescriptionLabel != nil {
            self.configureView()
            }
        }
    }


}

