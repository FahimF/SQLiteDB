//
//  SQLTable.swift
//  SQLiteDB-iOS
//
//  Created by Fahim Farook on 6/11/15.
//  Copyright © 2015 RookSoft Pte. Ltd. All rights reserved.
//

import Foundation

/// Enumerator to be used in fetching data via some methods where you might need to specify whether you want all records, only records marked for deletion, or only records not marked for deletion.
@objc
enum FetchType: Int {
	case all, deleted, nondeleted
}

protocol SQLTableProtocol {}

// MARK: - SQLiteDB Class
/// Base class for providing object-based access to SQLite tables. Simply define the properties and their default values (a value has to be there in order to determine value type) and SQLTable will handle the basic CRUD (creating, reading, updating, deleting) actions for you without any additional code.
@objcMembers
class SQLTable: NSObject, SQLTableProtocol {
	/// Every SQLTable sub-class will contain an `isDeleted` flag. Instead of deleting records, you should set the flag to `true` for deletions and filter your data accordingly when fetching data from `SQLTable`. This flag will be used to synchronize deletions via CloudKit
	public var isDeleted = false
	/// Every SQLTable sub-class will contain a `created` property indicating the creation date of the record.
	public var created = Date()
	/// Every SQLTable sub-class will contain a `modified` property indicating the last modification date of the record.
	public var modified = Date()
	/// Internal reference to the SQLite table name as determined based on the name of the `SQLTable` sub-class name. The sub-class name should be in the singular - for example, Task for a tasks table.
	internal var table = ""
	/// Internal dictionary to keep track of whether a specific table was verfied to be in existence in the database. This dictionary is used to automatically create the table if it does not exist in the DB.
	private static var verified = [String: Bool]()
	/// Internal pointer to the main database
	internal var db = SQLiteDB.shared

	/// Base initialization which sets up the table name and then verifies that the table exists in the DB, and if it does not, creates it.
	override required init() {
		super.init()
		// Table name
		self.table = type(of: self).table
		let verified = SQLTable.verified[table]
		if verified == nil || !verified! {
			// Verify that the table exists in DB
			var sql = "SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='\(table)'"
			let cnt = db.query(sql: sql).count
			if cnt == 1 {
				// Table exists, verify strutcure and then proceed
				verifyStructure()
				SQLTable.verified[table] = true
			} else if cnt == 0 {
				// Table does not exist, create it
				sql = "CREATE TABLE IF NOT EXISTS \(table) ("
				// Columns
				let cols = values()
				var first = true
				for col in cols {
					if first {
						first = false
						sql += getColumnSQL(column: col)
					} else {
						sql += ", " + getColumnSQL(column: col)
					}
				}
				// Close query
				sql += ")"
				let rc = db.execute(sql: sql)
				if rc == 0 {
					assert(false, "Error creating table - \(table) with SQL: \(sql)")
				}
				SQLTable.verified[table] = true
			} else {
				assert(false, "Got more than one table in DB with same name! Count: \(cnt) for \(table)")
			}
			// Create CloudKit zone, if necessary
			if db.cloudEnabled {
				if remoteDB() == DBType.privateDB {
					db.createCloudZone(table: self) {
						self.db.getCloudUpdates(table: self)
					}
				} else {
					db.getCloudUpdates(table: self)
				}
			}
		}
	}

	// MARK: - NSCoding / NSCopying Support
	func copy(to: SQLTable) {
		to.created = created
		to.modified = modified
		to.isDeleted = isDeleted
	}

	// MARK: - Table property management
	/// The primary key for the table - defaults to `id`. Override this in `SQLTable` sub-classes to define a different column name as the primary key.
	///
	/// - Returns: A string indicating the name of the primary key column for the table. Defaults to `id`.
	func primaryKey() -> String {
		"id"
	}

	/// The remote key for the table for data saved to CloudKit - defaults to `ckid`. Override this in `SQLTable` sub-classes to define a different column name as the remote key.
	///
	/// - Returns: A string indicating the name of the remote key column for the table. Defaults to `ckid`.
	func remoteKey() -> String {
		"ckid"
	}

	/// The remote database for the table for data saved to CloudKit - defaults to `private`. Override this in `SQLTable` sub-classes to define a different database for a specific table.
	///
	/// - Returns: A `DBType` enum indicating the remote database for the table. Defaults to `private`.
	func remoteDB() -> DBType {
		DBType.privateDB
	}

	/// An array of property names (in a sub-classed instance of `SQLTable`) that are to be ignored when fetching/saving information to the DB. Override this method in sub-classes when you have properties that you don't want persisted to the database.
	///
	/// - Returns: An array of String values indicating property/value names to be ignored when persisting data to the database.
	func ignoredKeys() -> [String] {
		[]
	}

	// MARK: - Class Methods
	/// Returns a WHERE clause, or an empty string, depending on the passed in `FetchType`.
	///
	/// - Paramter type: The type of fetch operation to be performed.
	/// - Returns: A String for the SQL WHERE clause, or an empty string if there is no WHERE clause.
	class func whereFor(type: FetchType) -> String {
		switch type {
		case .all:
			return ""

		case .deleted:
			return " WHERE isDeleted"

		case .nondeleted:
			return " WHERE (NOT isDeleted OR isDeleted IS NULL)"
		}
	}

	/// Return the count of rows in the table, or the count of rows matching a specific filter criteria, if one was provided.
	///
	/// - Parameters:
	///   - filter: The optional filter criteria to be used in fetching the data. Specify the filter criteria in the form of a valid SQLite WHERE clause (but without the actual WHERE keyword). If this parameter is omitted or a blank string is provided, the count of all rows, deleted rows, or non-deleted rows (depending on the `type` parameter) will be returned.
	///   - type: The type of records to fetch. Defined via the `FetchType` enumerator and defaults to `nondeleted`.
	/// - Returns: An integer value indicating the total number of rows, if no filter criteria was provided, or the number of rows matching the provided filter criteria.
	class func count(filter: String = "", fetch: FetchType = .nondeleted) -> Int {
		let db = SQLiteDB.shared
		var sql = "SELECT COUNT(*) AS count FROM \(table)"
		let wsql = SQLTable.whereFor(type: fetch)
		if filter.isEmpty {
			sql += wsql
		} else {
			if wsql.isEmpty {
				sql += " WHERE \(filter)"
			} else {
				sql += wsql + " AND \(filter)"
			}
		}
		let arr = db.query(sql: sql)
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
	/// - Parameters:
	///   - filter: The optional filter criteria to be used in removing data rows. Specify the filter criteria in the form of a valid SQLite WHERE clause (but without the actual WHERE keyword). If this parameter is omitted or a blank string is provided, all rows will be deleted from the underlying table.
	///   - force: Flag indicating whether to force delete the records or simply mark them as deleted. Defaluts to `false`.
	/// - Returns: A boolean value indicating whether the row deletion was successful or not.
	class func remove(filter: String = "", force: Bool = false) -> Bool {
		let db = SQLiteDB.shared
		var params: [Any]? = [true, Date()]
		var sql = "UPDATE \(table) SET isDeleted = ?, modified = ?"
		if force {
			params = nil
			sql = "DELETE FROM \(table)"
		}
		if !filter.isEmpty {
			// Use filter to delete
			sql += " WHERE \(filter)"
		}
		let rc = db.execute(sql: sql, parameters: params)
		return (rc != 0)
	}

	/// Remove all records marked as deleted.
	///
	/// Parameter filter: The optional filter criteria to be used in removing data rows. Specify the filter criteria in the form of a valid SQLite WHERE clause (but without the actual WHERE keyword). If this parameter is omitted or a blank string is provided, all rows marked as deleted will be removed from the underlying table.
	class func clearTrash(filter: String = "") {
		let db = SQLiteDB.shared
		var sql = "DELETE FROM \(table) WHERE isDeleted"
		if !filter.isEmpty {
			// Use filter to delete
			sql += " AND \(filter)"
		}
		_ = db.execute(sql: sql)
	}

	/// Remove all rows from the underlying table to create an empty table.
	class func zap() {
		let db = SQLiteDB.shared
		let sql = "DELETE FROM \(table)"
		_ = db.execute(sql: sql)
	}

	// MARK: - Public Methods
	/// Save the current values for this particular `SQLTable` sub-class instance to the database.
	///
	/// - Parameters:
	///   - updateCloud: A boolean indicating whether the save operation should save to the cloud as well. Defaults to `true`.
	///   - dbOverride: A `DBType` indicating the database to save the remote data to. If set, this overrides the database set by default for the table via the `remoteDB` method. Defaults to `none`.
	/// - Returns: An integer value indicating either the row id (in case of an insert) or the status of the save - a non-zero value indicates success and a 0 indicates failure.
	func save(updateCloud: Bool = true, dbOverride: DBType = .none) -> Int {
		let key = primaryKey()
		let data = values()
		var insert = true
		if let rid = data[key] {
			var val = "\(rid)"
			if rid is String {
				val = "'\(rid)'"
			}
			let sql = "SELECT COUNT(*) AS count FROM \(table) WHERE \(primaryKey())=\(val)"
			let arr = db.query(sql: sql)
			if arr.count == 1 {
				if let cnt = arr[0]["count"] as? Int {
					insert = (cnt == 0)
				}
			}
		}
		// Insert or update
		modified = Date()
		let (sql, params) = getSQL(data: data, forInsert: insert)
		let rc = db.execute(sql: sql, parameters: params)
		if rc == 0 {
			NSLog("Error saving record!")
			return 0
		}
		// Do cloud update - check (as to whether to save to cloud is done by DB)
		if updateCloud {
			db.saveToCloud(row: self)
		}
		// Update primary key
		let pid = data[key]
		if insert {
			if pid is Int64 {
				setValue(rc, forKey: key)
			} else if pid is Int {
				setValue(Int(rc), forKey: key)
			}
		}
		return rc
	}

	/// Delete the row for this particular `SQLTable` sub-class instance from the database.
	///
	/// - Parameter force: Flag indicating whether to force delete the records or simply mark them as deleted. Defaluts to `false`.
	/// - Returns: A boolean value indicating the success or failure of the operation.
	func delete(force: Bool = false) -> Bool {
		let key = primaryKey()
		let data = values()
		if let rid = data[key] {
			var params: [Any]? = [true, Date()]
			var sql = "UPDATE \(table) SET isDeleted = ?, modified = ? WHERE \(primaryKey())=\(rid)"
			if force {
				params = nil
				sql = "DELETE FROM \(table) WHERE \(primaryKey())=\(rid)"
			}
			let rc = db.execute(sql: sql, parameters: params)
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
			let arr = db.query(sql: sql)
			for (key, _) in data {
				if let val = arr[0][key] {
					setValue(val, forKey: key)
				}
			}
		}
	}

	// MARK: - Internal Methods
	/// Fetch a dictionary of property names and their corresponding values that are supposed to be persisted to the underlying table. Any property names returned via the `ignoredKeys` method will be left out of the dictionary.
	///
	/// - Returns: A dictionary of property names and their corresponding values.
	internal func values() -> [String: Any] {
		var res = [String: Any]()
		let obj = Mirror(reflecting: self)
		processMirror(obj: obj, results: &res)
		// Add super-class properties via recursion
		getValues(obj: obj.superclassMirror, results: &res)
		return res
	}

	// MARK: - Private Methods
	/// Recursively walk down the super-class hierarchy to get all the properties for a `SQLTable` sub-class instance
	///
	/// - Parameters:
	///   - obj: The `Mirror` instance for the super-class.
	///   - results: A dictionary of properties and values which will be modified in-place.
	private func getValues(obj: Mirror?, results: inout [String: Any]) {
		guard let obj = obj else { return }
		processMirror(obj: obj, results: &results)
		// Call method recursively
		getValues(obj: obj.superclassMirror, results: &results)
	}

	/// Creates a dictionary of property names and values based on a `Mirror` instance of an object.
	///
	/// - Parameters:
	///   - obj: The `Mirror` instance to be used.
	///   - results: A dictionary of properties and values which will be modified in-place.
	private func processMirror(obj: Mirror, results: inout [String: Any]) {
		for (_, attr) in obj.children.enumerated() {
			if let name = attr.label {
				// Ignore the table and db properties used internally
				if name == "table" || name == "db" {
					continue
				}
				// Ignore lazy vars
				if name.hasPrefix("$__lazy_storage_$_") {
					continue
				}
				// Ignore special properties and lazy vars
				if ignoredKeys().contains(name) || name.hasSuffix(".storage") {
					continue
				}
				results[name] = attr.value
			}
		}
	}

	/// Verify the structure of the underlying SQLite table and add any missing columns to the table as per the `SQLTable` sub-class definition.
	private func verifyStructure() {
		// Get table structure
		var sql = "PRAGMA table_info(\(table));"
		let arr = db.query(sql: sql)
		// Extract column names
		var columns = [String]()
		for row in arr {
			if let txt = row["name"] as? String {
				columns.append(txt)
			}
		}
		// Get SQLTable columns
		let cols = values()
		let names = cols.keys
		// Validate the SQLTable columns exist in actual DB table
		for nm in names {
			if columns.contains(nm) {
				continue
			}
			// Add missing column
			if let val = cols[nm] {
				let col = (key: nm, value: val)
				sql = "ALTER TABLE \(table) ADD COLUMN " + getColumnSQL(column: col)
				_ = db.execute(sql: sql)
			}
		}
	}

	/// Returns a valid SQL statement and matching list of bound parameters needed to insert a new row into the database or to update an existing row of data.
	///
	/// - Parameters:
	///   - data: A dictionary of property names and their corresponding values that need to be persisted to the underlying table.
	///   - forInsert: A boolean value indicating whether this is an insert or update action.
	/// - Returns: A tuple containing a valid SQL command to persist data to the underlying table and the bound parameters for the SQL command, if any.
	private func getSQL(data: [String: Any], forInsert: Bool = true) -> (String, [Any]?) {
		var sql = ""
		var params: [Any]?
		if forInsert {
			// INSERT INTO tasks(task, categoryID) VALUES ('\(txtTask.text)', 1)
			sql = "INSERT INTO \(table)("
		} else {
			// UPDATE tasks SET task = ? WHERE categoryID = ?
			sql = "UPDATE \(table) SET "
		}
		let pkey = primaryKey()
		var wsql = ""
		var rid: Any?
		var first = true
		for (key, val) in data {
			// Primary key handling
			if pkey == key {
				if forInsert {
					if val is Int, (val as! Int) == -1 {
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
			if first, params == nil {
				params = [Any]()
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
		} else if params != nil, !wsql.isEmpty {
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
	private func getColumnSQL(column: (key: String, value: Any)) -> String {
		let key = column.key
		let val = column.value
		var sql = "'\(key)' "
		if val is Int {
			// Integers
			sql += "INTEGER"
			if key == primaryKey() {
				sql += " PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE"
			} else {
				sql += " DEFAULT \(val)"
			}
		} else {
			// Other values
			if val is Float || val is Double {
				sql += "REAL DEFAULT \(val)"
			} else if val is Bool {
				sql += "BOOLEAN DEFAULT " + ((val as! Bool) ? "1" : "0")
			} else if val is Date {
				sql += "DATE"
				// Cannot add a default when modifying a table, but can do so on new table creation
//				if let dt = val as? Date {
//					let now = Date()
//					if now.timeIntervalSince(dt) < 3600 {
//						sql += " DEFAULT current_timestamp"
//					}
//				}
			} else if val is NSData {
				sql += "BLOB"
			} else {
				// Default to text
				sql += "TEXT"
			}
			if key == primaryKey() {
				sql += " PRIMARY KEY NOT NULL UNIQUE"
			}
		}
		return sql
	}
}

extension SQLTableProtocol where Self: SQLTable {
	/// Static variable indicating the table name - used in class methods since the instance variable `table` is not accessible in class methods.
	static var table: String {
		let cls = "\(classForCoder())".lowercased()
		let ndx = cls.index(before: cls.endIndex)
		let tnm = cls.hasSuffix("y") ? cls[..<ndx] + "ies" : (cls.hasSuffix("s") ? cls + "es" : cls + "s")
		return tnm
	}

	/// Return an array of values for an `SQLTable` sub-class (optionally) matching specified filter criteria, (optionally) in a given column order, and (optionally) limited to a specific number of rows.
	///
	/// - Parameters:
	///   - filter: The optional filter criteria to be used in fetching the data. Specify the filter criteria in the form of a valid SQLite WHERE clause (but without the actual WHERE keyword). If this parameter is omitted or a blank string is provided, all rows will be fetched.
	///   - order: The optional sort order for the data. Specify the sort order as valid SQLite statements as they would appear in an ORDER BY caluse (but without the ORDER BY part). If this parameter is omitted, or a blank string is provided, the data will not be ordered and will be retrieved in the order it was entered into the database.
	///   - limit: The optional number of rows to fetch. If no value is provide or a 0 value is passed in, all rows will be fetched. Otherwise, up to "n" rows, where "n" is the number specified by the `limit` parameter, will be fetched depending on the other passed in parameters.
	///   - type: The type of records to fetch. Defined via the `FetchType` enumerator and defaults to `nondeleted`.
	/// - Returns: An array of `SQLTable` sub-class instances matching the criteria as specified in the `filter` and `limit` parameters orderd as per the `order` parameter.
	static func rows(filter: String = "", order: String = "", limit: Int = 0, type: FetchType = .nondeleted) -> [Self] {
		var sql = "SELECT * FROM \(table)"
		let wsql = SQLTable.whereFor(type: type)
		if filter.isEmpty {
			sql += wsql
		} else {
			if wsql.isEmpty {
				sql += " WHERE \(filter)"
			} else {
				sql += wsql + " AND \(filter)"
			}
		}
		if !order.isEmpty {
			sql += " ORDER BY \(order)"
		}
		if limit > 0 {
			sql += " LIMIT 0, \(limit)"
		}
		return rowsFor(sql: sql)
	}

	/// Return an array of values for an `SQLTable` sub-class based on a passed in SQL query.
	///
	/// - Parameter sql: The SQL query to be used to fetch the data. This should be a valid (and complete) SQL query
	/// - Returns: Returns an empty array if no matching rows were found. Otherwise, returns an array of `SQLTable` sub-class instances matching the criterias specified as per the SQL query passed in via the `sql` parameter. Returns any matching row, even if they are marked for deletion, unless the provided SQL query specifically excluded deleted records.
	static func rowsFor(sql: String = "") -> [Self] {
		var res = [Self]()
		let tmp = self.init()
		let data = tmp.values()
		let db = SQLiteDB.shared
		let fsql = sql.isEmpty ? "SELECT * FROM \(table)" : sql
		let arr = db.query(sql: fsql)
		for row in arr {
			let t = self.init()
			for (key, _) in data {
				if let val = row[key] {
					t.setValue(val, forKey: key)
				}
			}
			res.append(t)
		}
		return res
	}

	/// Return an instance of `SQLTable` sub-class for a given primary key value.
	///
	/// - Parameter id: The primary key value for the row of data you want to get.
	/// - Returns: Return an instance of `SQLTable` sub-class if a matching row for the primary key was found, otherwise, returns nil. Returns any row, even if it is marked for deletion, as long as the provided ID matches.
	static func rowBy(id: Any) -> Self? {
		let row = self.init()
		let data = row.values()
		let db = SQLiteDB.shared
		var val = "\(id)"
		if id is String {
			val = "'\(id)'"
		}
		let sql = "SELECT * FROM \(table) WHERE \(row.primaryKey())=\(val)"
		let arr = db.query(sql: sql)
		if arr.count == 0 {
			return nil
		}
		for (key, _) in data {
			if let val = arr[0][key] {
				row.setValue(val, forKey: key)
			}
		}
		return row
	}

	/// Return an instance of `SQLTable` sub-class for a given 0-based row number matching specific (optional) filtering and sorting criteria. Especially useful for fetching just one row to populate a `UITableView` as needed instead of populating a full array of data that you might (or might not) need.
	///
	/// - Parameters:
	///   - number: 0-based row number, used mostly for accessing rows for display in UITableViews.
	///   - filter: The optional filter criteria to be used in fetching the data. Specify the filter criteria in the form of a valid SQLite WHERE clause (but without the actual WHERE keyword). If this parameter is omitted or a blank string is provided, all rows will be fetched.
	///   - order: The optional sort order for the data. Specify the sort order as valid SQLite statements as they would appear in an ORDER BY caluse (but without the ORDER BY part). If this parameter is omitted, or a blank string is provided, the data will not be ordered and will be retrieved in the order it was entered into the database.
	///   - type: The type of records to fetch. Defined via the `FetchType` enumerator and defaults to `nondeleted`.
	/// - Returns: Return an instance of `SQLTable` sub-class if a matching row for the provided row number and filter criteria was found, otherwise, returns nil.
	static func row(number: Int, filter: String = "", order: String = "", type: FetchType = .nondeleted) -> Self? {
		let row = self.init()
		let data = row.values()
		let db = SQLiteDB.shared
		var sql = "SELECT * FROM \(table)"
		let wsql = SQLTable.whereFor(type: type)
		if filter.isEmpty {
			sql += wsql
		} else {
			if wsql.isEmpty {
				sql += " WHERE \(filter)"
			} else {
				sql += wsql + " AND \(filter)"
			}
		}
		if !order.isEmpty {
			sql += " ORDER BY \(order)"
		}
		// Limit to specified row
		sql += " LIMIT 1 OFFSET \(number)"
		let arr = db.query(sql: sql)
		if arr.count == 0 {
			return nil
		}
		for (key, _) in data {
			if let val = arr[0][key] {
				row.setValue(val, forKey: key)
			}
		}
		return row
	}
}
