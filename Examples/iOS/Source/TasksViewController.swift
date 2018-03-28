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
	var data = [Task]()
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}

	override func viewWillAppear(_ animated:Bool) {
		super.viewWillAppear(animated)
//		data = Task.rows(order:"task ASC")
		data = Task.rows(order:"id ASC")
		table.reloadData()
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	// UITableView Delegates
	func tableView(_ tv:UITableView, numberOfRowsInSection section:Int) -> Int {
		let cnt = data.count
		return cnt
	}
	
	func tableView(_ tv:UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tv.dequeueReusableCell(withIdentifier: "TaskCell")!
		let task = data[indexPath.row]
		cell.textLabel?.text = task.task
		return cell
	}
}

