//
//  AddCategoryViewController.swift
//  TasksGalore
//
//  Created by Fahim Farook on 11/6/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//

import UIKit

class AddCategoryViewController: UITableViewController {
	@IBOutlet var txtCat: UITextField!
	
	@IBAction func save() {
		// Hide keyboard
		if txtCat.isFirstResponder {
			txtCat.resignFirstResponder()
		}
		// Validations
		if txtCat.text!.isEmpty {
			let alert = UIAlertController(title: "SQLiteDB", message: "Please add a category name first!", preferredStyle: UIAlertControllerStyle.alert)
			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
			present(alert, animated: true, completion: nil)
		}
		// Save task
		let cat = Category()
		cat.name = txtCat.text!
		if cat.save() != 0 {
			let alert = UIAlertController(title: "SQLiteDB", message: "Category successfully saved!", preferredStyle: UIAlertControllerStyle.alert)
			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
			present(alert, animated: true, completion: nil)
		}
	}
}
