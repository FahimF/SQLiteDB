//
//  TasksViewController.swift
//  TasksGalore
//
//  Created by Fahim Farook on 11/6/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//

import UIKit

class TasksViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
	@IBOutlet var table:UITableView!
	var data = [SQLRow]()
	let db = SQLiteDB.sharedInstance()
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		data = db.query("SELECT * FROM tasks ORDER BY task ASC")
		table.reloadData()
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	// UITableView Delegates
	func tableView(tv:UITableView, numberOfRowsInSection section:Int) -> Int {
		let cnt = data.count
		return cnt
	}
	
	func tableView(tv:UITableView, cellForRowAtIndexPath indexPath:NSIndexPath) -> UITableViewCell {
		let cell:UITableViewCell = tv.dequeueReusableCellWithIdentifier("TaskCell") as UITableViewCell
		let row = data[indexPath.row]
		if let task = row["task"] {
			cell.textLabel?.text = task.asString()
		}
		return cell
	}
}

