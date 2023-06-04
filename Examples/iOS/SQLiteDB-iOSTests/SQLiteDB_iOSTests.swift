//
//  SQLiteDB_iOSTests.swift
//  SQLiteDB-iOSTests
//
//  Created by Fahim Farook on 17/3/2017.
//  Copyright © 2017 RookSoft Pte. Ltd. All rights reserved.
//

import XCTest

class SQLiteDB_iOSTests: XCTestCase {
	var db: SQLiteDB!
	
    override func setUp() {
        super.setUp()
		db = SQLiteDB.shared
		_ = db.open()
    }
    
    override func tearDown() {
		db.closeDB()
        super.tearDown()
    }
	
	// MARK:- Tests
	func testQuery() {
		_ = getCount()
	}
	
	func testDBInsert() {
		let prevCount = getCount()
		let sql = "INSERT INTO Categories(name) VALUES (?)"
		let result = db.execute(sql:sql, parameters:["John's Category"])
		XCTAssertNotEqual(result, 0, "SQL Insert failed")
		let count = getCount()
		XCTAssertEqual(count-1, prevCount, "The record count has to increase by one after insert")
		let lastID = getLastID()
		XCTAssertEqual(result, lastID, "The last ID should match the Insert result")
	}
	
	func testDBUpdate()  {
		let lastID = getLastID()
		var sql = "UPDATE Categories SET name = ? WHERE id = \(lastID)"
		let newCat = "Jane's Category"
		let result = db.execute(sql:sql, parameters:[newCat])
		XCTAssertNotEqual(result, 0, "SQL Update failed")
		sql = "SELECT * FROM Categories WHERE id = \(lastID)"
		let arr = db.query(sql:sql)
		XCTAssertNotEqual(arr.count, 0, "The query should have resulted in at least one row")
		if let txt = arr[0]["name"] as? String {
			XCTAssertEqual(txt, newCat, "The category name was not changed after Update")
		}
	}
	
	func testDBDelete() {
		let lastID = getLastID()
		let prevCount = getCount()
		let sql = "DELETE FROM Categories WHERE id = \(lastID)"
		let result = db.execute(sql:sql)
		XCTAssertNotEqual(result, 0, "SQL Delete failed")
		let count = getCount()
		XCTAssertEqual(count, prevCount-1, "The record count has to decrease by one after delete")
	}
	
	// MARK:- Helper Methods
	func getCount() -> Int {
		var count = 0
		let sql = "SELECT COUNT(*) AS cnt FROM Categories"
		let arr = db.query(sql:sql)
		XCTAssertNotEqual(arr.count, 0, "The count query should have resulted in at least one row")
		if let cnt = arr[0]["cnt"] as? Int {
			count = cnt
		}
		XCTAssertNotEqual(count, -1, "The table should have a record count")
		return count
	}
	
	func getLastID() -> Int {
		var lastID = 0
		let sql = "SELECT * FROM Categories ORDER BY id DESC LIMIT 1"
		let arr = db.query(sql:sql)
		XCTAssertNotEqual(arr.count, 0, "The last ID query should have resulted in at least one row")
		if let lid = arr[0]["id"] as? Int {
			lastID = lid
		}
		XCTAssertNotEqual(lastID, 0, "The last ID should not be 0")
		return lastID
	}
}
