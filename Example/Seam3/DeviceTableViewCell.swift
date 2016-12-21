//
//  DeviceTableViewCell.swift
//  Seam3
//
//  Created by Paul Wilkinson on 21/12/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

class DeviceTableViewCell: UITableViewCell {
    
    @IBOutlet weak var deviceLabel: UILabel!
    @IBOutlet weak var deviceImage: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
