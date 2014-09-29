//
//  AddTaskViewController.swift
//  TasksGalore
//
//  Created by Fahim Farook on 11/6/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//

import UIKit

class AddTaskViewController: UITableViewController {
	@IBOutlet var txtTask: UITextField!

	@IBAction func save() {
		// Hide keyboard
		if txtTask.isFirstResponder() {
			txtTask.resignFirstResponder()
		}
		// Validations
		if txtTask.text.isEmpty {
			let alert = UIAlertView(title:"SQLiteDB", message:"Please add a task description first!", delegate:nil, cancelButtonTitle: "OK")
			alert.show()
		}
		// Save task
		let db = SQLiteDB.sharedInstance()
		let sql = "INSERT INTO tasks(task, categoryID) VALUES ('\(txtTask.text)', 1)"
		let rc = db.execute(sql)
		if rc != 0 {
			let alert = UIAlertView(title:"SQLiteDB", message:"Task successfully saved!", delegate:nil, cancelButtonTitle: "OK")
			alert.show()
		}
	}
}