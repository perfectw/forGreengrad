//
//  RSData.swift
//  forGreengrad
//
//  Created by Roman Spirichkin on 06/02/16.
//  Copyright © 2016 rs. All rights reserved.
//

import UIKit


class Song {
    let label, author : String
    var id : Int
    init(label:  String, author: String, id: Int) {
        self.label = label
        self.author = author
        self.id = id
    }
}

class RSSongCell: UICollectionViewCell {
    @IBOutlet weak var RSAuthorLabel: UILabel!
    @IBOutlet weak var RSSongLabel: UILabel!
    
}
