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
	var data = [Category]()
	let db = SQLiteDB.sharedInstance()
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		data = Category().allRows("name ASC")
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
		let cell = tv.dequeueReusableCellWithIdentifier("CategoryCell")!
		let cat = data[indexPath.row]
		cell.textLabel?.text = cat.name
		return cell
	}
}

