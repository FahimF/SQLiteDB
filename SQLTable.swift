//
//  SQLTable.swift
//  SQLiteDB-iOS
//
//  Created by Fahim Farook on 6/11/15.
//  Copyright © 2015 RookSoft Pte. Ltd. All rights reserved.
//

import Foundation

// MARK:- SQLiteDB Class
/// Base class for providing object-based access to SQLite tables. Simply define the properties and their default values (a value has to be there in order to determine value type) and SQLTable will handle the basic CRUD (creating, reading, updating, deleting) actions for you without any additional code.
@objcMembers
class SQLTable: NSObject {
	/// Internal reference to the SQLite table name as determined based on the name of the `SQLTable` sub-class name. The sub-class name should be in the singular - for example, Task for a tasks table.
	internal var table = ""
	/// Internal dictionary to keep track of whether a specific table was verfied to be in existence in the database. This dictionary is used to automatically create the table if it does not exist in the DB.
	private static var verified = [String:Bool]()
	/// Internal pointer to the main database
	private var db = SQLiteDB.shared
	
	/// Static variable indicating the table name - used in class methods since the instance variable `table` is not accessible in class methods.
	private static var table:String {
		let cls = "\(classForCoder())".lowercased()
		let ndx = cls.index(before:cls.endIndex)
		let tnm = cls.hasSuffix("y") ? cls[..<ndx] + "ies" : (cls.hasSuffix("s") ? cls + "es" : cls + "s")
		return tnm
	}
	
	/// Base initialization which sets up the table name and then verifies that the table exists in the DB, and if it does not, creates it.
	required override init() {
		super.init()
		// Table name
		self.table = type(of: self).table
		let verified = SQLTable.verified[table]
		if verified == nil || !verified! {
			// Verify that the table exists in DB
			var sql = "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='\(table)'"
			let cnt = db.query(sql:sql).count
			if cnt == 1 {
				// Table exists, proceed
				SQLTable.verified[table] = true
			} else if cnt == 0 {
				// Table does not exist, create it
				sql = "CREATE TABLE IF NOT EXISTS \(table) ("
				// Columns
				let cols = values()
				sql += getColumnSQL(columns:cols)
				// Close query
				sql += ")"
				let rc = db.execute(sql:sql)
				if rc == 0 {
					assert(false, "Error creating table - \(table) with SQL: \(sql)")
				}
				SQLTable.verified[table] = true
			} else {
				assert(false, "Got more than one table in DB with same name! Count: \(cnt) for \(table)")
			}
		}
	}
	
	// MARK:- Table property management
	/// The primary key for the table - defaults to `id`. Override this in `SQLTable` sub-classes to define a different column name as the primary key.
	///
	/// - Returns: A string indicating the name of the primary key column for the table. Defaults to `id`.
	func primaryKey() -> String {
		return "id"
	}
	
	/// An array of property names (in a sub-classed instance of `SQLTable`) that are to be ignored when fetching/saving information to the DB. Override this method in sub-classes when you have properties that you don't want persisted to the database.
	///
	/// - Returns: An array of String values indicating property/value names to be ignored when persisting data to the database.
	func ignoredKeys() -> [String] {
		return []
	}
	
	// MARK:- Class Methods
	/// Return an array of values for an `SQLTable` sub-class (optionally) matching specified filter criteria, (optionally) in a given column order, and (optionally) limited to a specific number of rows.
	///
	/// - Parameters:
	///   - filter: The optional filter criteria to be used in fetching the data. Specify the filter criteria in the form of a valid SQLite WHERE clause (but without the actual WHERE keyword). If this parameter is omitted or a blank string is provided, all rows will be fetched.
	///   - order: The optional sort order for the data. Specify the sort order as valid SQLite statements as they would appear in an ORDER BY caluse (but without the ORDER BY part). If this parameter is omitted, or a blank string is provided, the data will not be ordered and will be retrieved in the order it was entered into the database.
	///   - limit: The optional number of rows to fetch. If no value is provide or a 0 value is passed in, all rows will be fetched. Otherwise, up to "n" rows, where "n" is the number specified by the `limit` parameter, will be fetched depending on the other passed in parameters.
	/// - Returns: An array of `SQLTable` sub-class instances matching the criteria as specified in the `filter` and `limit` parameters orderd as per the `order` parameter.
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
		return self.rowsFor(sql:sql)
	}

	/// Return an array of values for an `SQLTable` sub-class based on a passed in SQL query.
	///
	/// - Parameter sql: The SQL query to be used to fetch the data. This should be a valid (and complete) SQL query
	/// - Returns: Returns an empty array if no matching rows were found. Otherwise, returns an array of `SQLTable` sub-class instances matching the criterias specified as per the SQL query passed in via the `sql` parameter.
	class func rowsFor(sql:String="") -> [SQLTable] {
		var res = [SQLTable]()
		let tmp = self.init()
		let data = tmp.values()
		let db = SQLiteDB.shared
		let fsql = sql.isEmpty ? "SELECT * FROM \(table)" : sql
		let arr = db.query(sql:fsql)
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
	
	/// Return an instance of `SQLTable` sub-class for a given primary key value.
	///
	/// - Parameter id: The primary key value for the row of data you want to get.
	/// - Returns: Return an instance of `SQLTable` sub-class if a matching row for the primary key was found, otherwise, returns nil.
	class func rowBy(id:Any) -> SQLTable? {
		let row = self.init()
		let data = row.values()
		let db = SQLiteDB.shared
		var val = "\(id)"
		if id is String {
			val = "'\(id)'"
		}
		let sql = "SELECT * FROM \(table) WHERE \(row.primaryKey())=\(val)"
		let arr = db.query(sql:sql)
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
	
	/// Return an instance of `SQLTable` sub-class for a given 1-based row number matching specific (optional) filtering and sorting criteria. Especially useful for fetching just one row to populate a `UITableView` as needed instead of populating a full array of data that you might (or might not) need.
	///
	/// - Parameters:
	///   - number: 1-based row number.
	///   - filter: The optional filter criteria to be used in fetching the data. Specify the filter criteria in the form of a valid SQLite WHERE clause (but without the actual WHERE keyword). If this parameter is omitted or a blank string is provided, all rows will be fetched.
	///   - order: The optional sort order for the data. Specify the sort order as valid SQLite statements as they would appear in an ORDER BY caluse (but without the ORDER BY part). If this parameter is omitted, or a blank string is provided, the data will not be ordered and will be retrieved in the order it was entered into the database.
	/// - Returns: Return an instance of `SQLTable` sub-class if a matching row for the provided row number and filter criteria was found, otherwise, returns nil.
	class func row(number:Int, filter:String="", order:String="") -> SQLTable? {
		let row = self.init()
		let data = row.values()
		let db = SQLiteDB.shared
		var sql = "SELECT * FROM \(table)"
		if !filter.isEmpty {
			sql += " WHERE \(filter)"
		}
		if !order.isEmpty {
			sql += " ORDER BY \(order)"
		}
		// Limit to specified row
		sql += " LIMIT 1 OFFSET \(number-1)"
		let arr = db.query(sql:sql)
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
	
	/// Return the count of rows in the table, or the count of rows matching a specific filter criteria, if one was provided.
	///
	/// - Parameter filter: The optional filter criteria to be used in fetching the data. Specify the filter criteria in the form of a valid SQLite WHERE clause (but without the actual WHERE keyword). If this parameter is omitted or a blank string is provided, all rows will be fetched.
	/// - Returns: An integer value indicating the total number of rows, if no filter criteria was provided, or the number of rows matching the provided filter criteria.
	class func count(filter:String="") -> Int {
		let db = SQLiteDB.shared
		var sql = "SELECT COUNT(*) AS count FROM \(table)"
		if !filter.isEmpty {
			sql += " WHERE \(filter)"
		}
		let arr = db.query(sql:sql)
		if arr.count == 0 {
			return 0
		}
		if let val = arr[0]["count"] as? Int {
			return val
		}
		return 0
	}
	
	/// Remove all the rows in the underlying table, or just the rows matching a provided criteria.
	///
	/// - Parameter filter: The optional filter criteria to be used in removing data rows. Specify the filter criteria in the form of a valid SQLite WHERE clause (but without the actual WHERE keyword). If this parameter is omitted or a blank string is provided, all rows will be deleted from the underlying table.
	/// - Returns: A boolean value indicating whether the row deletion was successful or not.
	class func remove(filter:String = "") -> Bool {
		let db = SQLiteDB.shared
		let sql:String
		if filter.isEmpty {
			// Delete all rows
			sql = "DELETE FROM \(table)"
		} else {
			// Use filter to delete
			sql = "DELETE FROM \(table) WHERE \(filter)"
		}
		let rc = db.execute(sql:sql)
		return (rc != 0)
	}
	
	/// Remove all rows from the underlying table to create an empty table.
	class func zap() {
		let db = SQLiteDB.shared
		let sql = "DELETE FROM \(table)"
		_ = db.execute(sql:sql)
	}
	
	// MARK:- Public Methods
	/// Save the current values for this particular `SQLTable` sub-class instance to the database.
	///
	/// - Returns: An integer value indicating either the row id (in case of an insert) or the status of the save - a non-zero value indicates success and a 0 indicates failure.
	func save() -> Int {
		let db = SQLiteDB.shared
		let key = primaryKey()
		let data = values()
		var insert = true
		if let rid = data[key] {
			var val = "\(rid)"
			if rid is String {
				val = "'\(rid)'"
			}
			let sql = "SELECT COUNT(*) AS count FROM \(table) WHERE \(primaryKey())=\(val)"
			let arr = db.query(sql:sql)
			if arr.count == 1 {
				if let cnt = arr[0]["count"] as? Int {
					insert = (cnt == 0)
				}
			}
		}
		// Insert or update
		let (sql, params) = getSQL(data:data, forInsert:insert)
		let rc = db.execute(sql:sql, parameters:params)
		if rc == 0 {
			NSLog("Error saving record!")
			return 0
		}
		// Update primary key
		let pid = data[key]
		if insert {
			if pid is Int64 {
				setValue(rc, forKey:key)
			} else if pid is Int {
				setValue(Int(rc), forKey:key)
			}
		}
		return rc
	}
	
	/// Delete the row for this particular `SQLTable` sub-class instance from the database.
	///
	/// - Returns: A boolean value indicating the success or failure of the operation.
	func delete() -> Bool {
		let key = primaryKey()
		let data = values()
		if let rid = data[key] {
			let sql = "DELETE FROM \(table) WHERE \(primaryKey())=\(rid)"
			let rc = db.execute(sql:sql)
			return (rc != 0)
		}
		return false
	}
	
	/// Update the data for this particular `SQLTable` sub-class instance from the database so that all values are updated with the latest values from the database.
	func refresh() {
		let key = primaryKey()
		let data = values()
		if let rid = data[key] {
			let sql = "SELECT * FROM \(table) WHERE \(primaryKey())=\(rid)"
			let arr = db.query(sql:sql)
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
	
	/// Fetch a dictionary of property names and their corresponding values that are supposed to be persisted to the underlying table. Any property names returned via the `ignoredKeys` method will be left out of the dictionary.
	///
	/// - Returns: A dictionary of property names and their corresponding values.
	internal func values() -> [String:Any] {
		var res = [String:Any]()
		let obj = Mirror(reflecting:self)
		for (_, attr) in obj.children.enumerated() {
			if let name = attr.label {
				// Ignore special properties and lazy vars
				if ignoredKeys().contains(name) || name.hasSuffix(".storage") {
					continue
				}
				res[name] = attr.value
			}
		}
		return res
	}
	
	/// Returns a valid SQL statement and matching list of bound parameters needed to insert a new row into the database or to update an existing row of data.
	///
	/// - Parameters:
	///   - data: A dictionary of property names and their corresponding values that need to be persisted to the underlying table.
	///   - forInsert: A boolean value indicating whether this is an insert or update action.
	/// - Returns: A tuple containing a valid SQL command to persist data to the underlying table and the bound parameters for the SQL command, if any.
	private func getSQL(data:[String:Any], forInsert:Bool = true) -> (String, [Any]?) {
		var sql = ""
		var params:[Any]? = nil
		if forInsert {
			// INSERT INTO tasks(task, categoryID) VALUES ('\(txtTask.text)', 1)
			sql = "INSERT INTO \(table)("
		} else {
			// UPDATE tasks SET task = ? WHERE categoryID = ?
			sql = "UPDATE \(table) SET "
		}
		let pkey = primaryKey()
		var wsql = ""
		var rid:Any?
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
	
	/// Returns a valid SQL fragment for creating the columns, with the correct data type, for the underlying table.
	///
	/// - Parameter columns: A dictionary of property names and their corresponding values for the `SQLTable` sub-class
	/// - Returns: A string containing an SQL fragment for delcaring the columns for the underlying table with the correct data type 
	private func getColumnSQL(columns:[String:Any]) -> String {
		var sql = ""
		for key in columns.keys {
			let val = columns[key]!
			var col = "'\(key)' "
			if val is Int {
				// Integers
				col += "INTEGER"
				if key == primaryKey() {
					col += " PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE"
				}
			} else {
				// Other values
				if val is Float || val is Double {
					col += "REAL"
				} else if val is Bool {
					col += "BOOLEAN"
				} else if val is Date {
					col += "DATE"
				} else if val is NSData {
					col += "BLOB"
				} else {
					// Default to text
					col += "TEXT"
				}
				if key == primaryKey() {
					col += " PRIMARY KEY NOT NULL UNIQUE"
				}
			}
			if sql.isEmpty {
				sql = col
			} else {
				sql += ", " + col
			}
		}
		return sql
	}
}
