//
//  Task.swift
//  SQLiteDB-iOS
//
//  Created by Fahim Farook on 6/11/15.
//  Copyright © 2015 RookSoft Pte. Ltd. All rights reserved.
//

#if os(iOS)
	import UIKit
#else
	import AppKit
#endif

class Task:SQLTable {
	var id = -1
	var task = ""
	var categoryID = -1
}
