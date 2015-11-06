//
//  Task.swift
//  SQLiteDB-iOS
//
//  Created by Fahim Farook on 6/11/15.
//  Copyright © 2015 RookSoft Pte. Ltd. All rights reserved.
//

import UIKit

class Task:SQLTable {
	var id = -1
	var task = ""
	var categoryID = -1
	
	init() {
		super.init(tableName:"tasks")
	}

	required convenience init(tableName:String) {
		self.init()
	}
}
