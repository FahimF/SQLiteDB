//
//  CategoryViewController.swift
//  TasksGalore
//
//  Created by Fahim Farook on 11/6/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//

import UIKit

class CategoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
	@IBOutlet var table:UITableView!
	var data:[SQLRow]? = nil
	let db = SQLiteDB.sharedInstance()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		db.query("SELECT * FROM categories ORDER BY name ASC", completion:{(arr:[SQLRow]?)->Void in
			self.data = arr
			self.table.reloadData()
		})
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	// UITableView Delegates
	func tableView(tv:UITableView, numberOfRowsInSection section:Int) -> Int {
		var cnt = 0
		if data != nil {
			cnt = data!.count
		}
		return cnt
	}
	
	func tableView(tv:UITableView, cellForRowAtIndexPath indexPath:NSIndexPath) -> UITableViewCell {
		let cell:UITableViewCell = tv.dequeueReusableCellWithIdentifier("CategoryCell") as UITableViewCell
		let row = data![indexPath.row]
		if let name = row["name"] {
			cell.textLabel?.text = name.asString()
		}
		return cell
	}
}

