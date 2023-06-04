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
		if txtTask.isFirstResponder {
			txtTask.resignFirstResponder()
		}
		// Validations
		if txtTask.text!.isEmpty {
			let alert = UIAlertController(title: "SQLiteDB", message: "Please add a task description first!", preferredStyle: UIAlertControllerStyle.alert)
			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
			present(alert, animated: true, completion: nil)
		}
		// Save task
		let task = Task()
		task.task = txtTask.text!
		if task.save() != 0 {
			let alert = UIAlertController(title: "SQLiteDB", message: "Task successfully saved!", preferredStyle: UIAlertControllerStyle.alert)
			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
			present(alert, animated: true, completion: nil)
		}
	}
}
