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
		if txtCat.isFirstResponder() {
			txtCat.resignFirstResponder()
		}
		// Validations
		if txtCat.text!.isEmpty {
			let alert = UIAlertView(title:"SQLiteDB", message:"Please add a category name first!", delegate:nil, cancelButtonTitle: "OK")
			alert.show()
		}
		// Save task
		let db = SQLiteDB.sharedInstance()
		let sql = "INSERT INTO categories(name) VALUES (?)"
		let params = [txtCat.text!]
		let rc = db.execute(sql, parameters:params)
		if rc != 0 {
			let alert = UIAlertView(title:"SQLiteDB", message:"Category successfully saved!", delegate:nil, cancelButtonTitle: "OK")
			alert.show()
		}
	}
	
}