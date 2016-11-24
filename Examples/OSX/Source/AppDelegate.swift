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
	let db = SQLiteDB.sharedInstance

	func applicationDidFinishLaunching(_ notification:Notification) {
		// Insert code here to initialize your application
		let cats = Category.rows(order:"id ASC") as! [Category]
		NSLog("Got categories: \(cats)")
	}
	
	func applicationWillTerminate(aNotification: NSNotification) {
		// Insert code here to tear down your application
	}


}

