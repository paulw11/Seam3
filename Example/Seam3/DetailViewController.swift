//
//  DetailViewController.swift
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
            self.stringTextField.text = detail.stringAttribute ?? ""
            self.creatingDeviceField.text = detail.creatingDevice?.deviceID
            print("EVents owned=\(detail.creatingDevice!.events!)")
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
                    print("moc= \(self.managedObjectContext)")
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

