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
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}

	override func viewWillAppear(_ animated:Bool) {
		super.viewWillAppear(animated)
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	// UITableView Delegates
	func tableView(_ tv:UITableView, numberOfRowsInSection section:Int) -> Int {
		let cnt = Category.count()
		return cnt
	}
	
	func tableView(_ tv:UITableView, cellForRowAt indexPath:IndexPath) -> UITableViewCell {
		let cell = tv.dequeueReusableCell(withIdentifier: "CategoryCell")!
		if let cat = Category.row(number: indexPath.row, order: "name") {
			cell.textLabel?.text = cat.name
		}
		return cell
	}
}

