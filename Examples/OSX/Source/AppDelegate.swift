//
//  AppDelegate.swift
//  SQLiteDB-OSX
//
//  Created by Fahim Farook on 9/26/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	let db = SQLiteDB.shared

	func applicationDidFinishLaunching(_ notification:Notification) {
		// Open DB first
		if db.open() {
			// Query category
			let cats = Category.rows(order:"id ASC")
			NSLog("Got categories: \(cats)")
		}
	}
	
	func applicationWillTerminate(aNotification: NSNotification) {
		// Insert code here to tear down your application
	}


}

