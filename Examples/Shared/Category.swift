//
//  Category.swift
//  SQLiteDB-iOS
//
//  Created by Fahim Farook on 6/11/15.
//  Copyright © 2015 RookSoft Pte. Ltd. All rights reserved.
//

import UIKit

class Category:SQLTable {
	var id = -1
	var name = ""
	
	init() {
		super.init(tableName:"categories")
	}
	
	required convenience init(tableName:String) {
		self.init()
	}
}
