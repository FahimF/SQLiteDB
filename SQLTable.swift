//
//  SQLTable.swift
//  SQLiteDB-iOS
//
//  Created by Fahim Farook on 6/11/15.
//  Copyright © 2015 RookSoft Pte. Ltd. All rights reserved.
//

#if os(iOS)
	import UIKit
#else
	import AppKit
#endif

@objc(SQLTable)
class SQLTable:NSObject {
	private var table:String!
	
	private static var table:String {
		let cls = "\(self.classForCoder())".lowercaseString
		let tnm = cls.hasSuffix("y") ? cls.substringToIndex(cls.endIndex.predecessor()) + "ies" : cls + "s"
		return tnm
	}
	
	required override init() {
		super.init()
		// Table name
		let cls = "\(self.classForCoder)".lowercaseString
		let tnm = cls.hasSuffix("y") ? cls.substringToIndex(cls.endIndex.predecessor()) + "ies" : cls + "s"
		self.table = tnm
	}
	
	// MARK:- Table property management
	func primaryKey() -> String {
		return "id"
	}
	
	func ignoredKeys() -> [String] {
		return []
	}
	
	func setPrimaryKey(val:AnyObject) {
		setValue(val, forKey:primaryKey())
	}

	func getPrimaryKey() -> AnyObject? {
		return valueForKey(primaryKey())
	}
	
	// MARK:- Class Methods
	class func rows(filter:String="", order:String="", limit:Int=0) -> [SQLTable] {
		var sql = "SELECT * FROM \(table)"
		if !filter.isEmpty {
			sql += " WHERE \(filter)"
		}
		if !order.isEmpty {
			sql += " ORDER BY \(order)"
		}
		if limit > 0 {
			sql += " LIMIT 0, \(limit)"
		}
		return self.rowsFor(sql)
	}

	class func rowsFor(sql:String="") -> [SQLTable] {
		var res = [SQLTable]()
		let tmp = self.init()
		let data = tmp.values()
		let db = SQLiteDB.sharedInstance
		let fsql = sql.isEmpty ? "SELECT * FROM \(table)" : sql
		let arr = db.query(fsql)
		for row in arr {
			let t = self.init()
			for (key, _) in data {
				if let val = row[key] {
					t.setValue(val, forKey:key)
				}
			}
			res.append(t)
		}
		return res
		
	}
	
	class func rowByID(rid:Int) -> SQLTable? {
		let row = self.init()
		let data = row.values()
		let db = SQLiteDB.sharedInstance
		let sql = "SELECT * FROM \(table) WHERE \(row.primaryKey())=\(rid)"
		let arr = db.query(sql)
		if arr.count == 0 {
			return nil
		}
		for (key, _) in data {
			if let val = arr[0][key] {
				row.setValue(val, forKey:key)
			}
		}
		return row
	}
	
	class func count(filter:String="") -> Int {
		let db = SQLiteDB.sharedInstance
		var sql = "SELECT COUNT(*) AS count FROM \(table)"
		if !filter.isEmpty {
			sql += " WHERE \(filter)"
		}
		let arr = db.query(sql)
		if arr.count == 0 {
			return 0
		}
		if let val = arr[0]["count"] as? Int {
			return val
		}
		return 0
	}
	
	class func row(rowNumber:Int, filter:String="", order:String="") -> SQLTable? {
		let row = self.init()
		let data = row.values()
		let db = SQLiteDB.sharedInstance
		var sql = "SELECT * FROM \(table)"
		if !filter.isEmpty {
			sql += " WHERE \(filter)"
		}
		if !order.isEmpty {
			sql += " ORDER BY \(order)"
		}
		// Limit to specified row
		sql += " LIMIT 1 OFFSET \(rowNumber-1)"
		let arr = db.query(sql)
		if arr.count == 0 {
			return nil
		}
		for (key, _) in data {
			if let val = arr[0][key] {
				row.setValue(val, forKey:key)
			}
		}
		return row
	}
	
	class func remove(filter:String = "") -> Bool {
		let db = SQLiteDB.sharedInstance
		let sql:String
		if filter.isEmpty {
			// Delete all records
			sql = "DELETE FROM \(table)"
		} else {
			// Use filter to delete
			sql = "DELETE FROM \(table) WHERE \(filter)"
		}
		let rc = db.execute(sql)
		return (rc != 0)
	}
	
	class func zap() {
		let db = SQLiteDB.sharedInstance
		let sql = "DELETE FROM \(table)"
		db.execute(sql)
	}
	
	// MARK:- Public Methods
	func save() -> Int {
		let db = SQLiteDB.sharedInstance
		let key = primaryKey()
		let data = values()
		var insert = true
		if let rid = data[key] {
			let sql = "SELECT COUNT(*) AS count FROM \(table) WHERE \(primaryKey())=\(rid)"
			let arr = db.query(sql)
			if arr.count == 1 {
				if let cnt = arr[0]["count"] as? Int {
					insert = (cnt == 0)
				}
			}
		}
		// Insert or update
		let (sql, params) = getSQL(data, forInsert:insert)
		let rc = db.execute(sql, parameters:params)
		// Update primary key
		let rid = Int(rc)
		if insert {
			setValue(rid, forKey:key)
		}
		let res = (rc != 0)
		if !res {
			NSLog("Error saving record!")
		}
		return rid
	}
	
	func delete() -> Bool {
		let db = SQLiteDB.sharedInstance
		let key = primaryKey()
		let data = values()
		if let rid = data[key] {
			let sql = "DELETE FROM \(table) WHERE \(primaryKey())=\(rid)"
			let rc = db.execute(sql)
			return (rc != 0)
		}
		return false
	}
	
	func refresh() {
		let db = SQLiteDB.sharedInstance
		let key = primaryKey()
		let data = values()
		if let rid = data[key] {
			let sql = "SELECT * FROM \(table) WHERE \(primaryKey())=\(rid)"
			let arr = db.query(sql)
			for (key, _) in data {
				if let val = arr[0][key] {
					setValue(val, forKey:key)
				}
			}
		}
	}
	
	// MARK:- Private Methods
//	private func properties() -> [String] {
//		var res = [String]()
//		for c in Mirror(reflecting:self).children {
//			if let name = c.label{
//				res.append(name)
//			}
//		}
//		return res
//	}
	
	private func values() -> [String:AnyObject] {
		var res = [String:AnyObject]()
		let obj = Mirror(reflecting:self)
		for (_, attr) in obj.children.enumerate() {
			if let name = attr.label {
				// Ignore special properties and lazy vars
				if ignoredKeys().contains(name) || name.hasSuffix(".storage") {
					continue
				}
				res[name] = getValue(attr.value as! AnyObject)
			}
		}
		return res
	}
	
	private func getValue(val:AnyObject) -> AnyObject {
		if val is String {
			return val as! String
		} else if val is Int {
			return val as! Int
		} else if val is Float {
			return val as! Float
		} else if val is Double {
			return val as! Double
		} else if val is Bool {
			return val as! Bool
		} else if val is NSDate {
			return val as! NSDate
		} else if val is NSData {
			return val as! NSData
		}
		return "nAn"
	}
	
	private func getSQL(data:[String:AnyObject], forInsert:Bool = true) -> (String, [AnyObject]?) {
		var sql = ""
		var params:[AnyObject]? = nil
		if forInsert {
			// INSERT INTO tasks(task, categoryID) VALUES ('\(txtTask.text)', 1)
			sql = "INSERT INTO \(table)("
		} else {
			// UPDATE tasks SET task = ? WHERE categoryID = ?
			sql = "UPDATE \(table) SET "
		}
		let pkey = primaryKey()
		var wsql = ""
		var rid:AnyObject?
		var first = true
		for (key, val) in data {
			// Primary key handling
			if pkey == key {
				if forInsert {
					if val is Int && (val as! Int) == -1 {
						// Do not add this since this is (could be?) an auto-increment value
						continue
					}
				} else {
					// Update - set up WHERE clause
					wsql += " WHERE " + key + " = ?"
					rid = val
					continue
				}
			}
			// Set up parameter array - if we get here, then there are parameters
			if first && params == nil {
				params = [AnyObject]()
			}
			if forInsert {
				sql += first ? "\(key)" : ", \(key)"
				wsql += first ? " VALUES (?" : ", ?"
				params!.append(val)
			} else {
				sql += first ? "\(key) = ?" : ", \(key) = ?"
				params!.append(val)
			}
			first = false
		}
		// Finalize SQL
		if forInsert {
			sql += ")" + wsql + ")"
		} else if params != nil && !wsql.isEmpty {
			sql += wsql
			params!.append(rid!)
		}
//		NSLog("Final SQL: \(sql) with parameters: \(params)")
		return (sql, params)
	}
}
