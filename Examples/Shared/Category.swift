//
//  Category.swift
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

class Category:SQLTable {
	var id = -1
	var name = ""
	
	override var description:String {
		return "id: \(id), name: \(name)"
	}
}
