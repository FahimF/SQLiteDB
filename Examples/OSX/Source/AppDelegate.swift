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
	let db = SQLiteDB.sharedInstance()

	func applicationDidFinishLaunching(notification: NSNotification) {
		// Insert code here to initialize your application
	}
	
	func applicationWillTerminate(aNotification: NSNotification) {
		// Insert code here to tear down your application
	}


}

