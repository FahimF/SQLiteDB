//
//  SQLTable.swift
//  SQLiteDB-iOS
//
//  Created by Fahim Farook on 6/11/15.
//  Copyright © 2015 RookSoft Pte. Ltd. All rights reserved.
//

import Foundation
import CloudKit

/// Enumerator to be used in fetching data via some methods where you might need to specify whether you want all records, only records marked for deletion, or only records not marked for deletion.
@objc
enum FetchType: Int {
	case all, deleted, nondeleted
}

@objc
enum DBType: Int {
	case none, publicDB, privateDB, sharedDB
}

protocol SQLTableProtocol {}

// MARK: - SQLiteDB Class
/// Base class for providing object-based access to SQLite tables. Simply define the properties and their default values (a value has to be there in order to determine value type) and SQLTable will handle the basic CRUD (creating, reading, updating, deleting) actions for you without any additional code.
@objcMembers
class SQLTable: NSObject, SQLTableProtocol, Identifiable {
	/// Every SQLTable sub-class will contain an `isDeleted` flag. Instead of deleting records, you should set the flag to `true` for deletions and filter your data accordingly when fetching data from `SQLTable`. This flag will be used to synchronize deletions via CloudKit
	public var isDeleted = false

	/// Every SQLTable sub-class will contain a `created` property indicating the creation date of the record.
	public var created = Date()

	/// Every SQLTable sub-class will contain a `updated` property indicating the last modification date of the record.
	public var updated = Date()

	/// Internal reference to the SQLite table name as determined based on the name of the `SQLTable` sub-class name. The sub-class name should be in the singular - for example, Task for a tasks table.
	internal var table = ""

	/// The CloudKit meta data
	internal var ckMeta = Data()

	/// Internal dictionary to keep track of whether a specific table was verfied to be in existence in the database. This dictionary is used to automatically create the table if it does not exist in the DB.
	private static var verified = [String: Bool]()

	/// Internal pointer to the main database
	internal var db = SQLiteDB.shared

	/// The primary key for the table - defaults to `id`. Override this in `SQLTable` sub-classes to define a different column name as the primary key.
	var primaryKey: String {
		"id"
	}

	/// An array of property names (in a sub-classed instance of `SQLTable`) that are to be ignored when fetching/saving information to the DB. Override this method in sub-classes when you have properties that you don't want persisted to the database.
	var ignoredKeys: [String] {
		return []
	}

	/// The CloudKit meta data key name for the table - defaults to `ckMeta`. Override this in sub-classes to define a different column name. This key should be data type and will be using `encodeSystemFieldsWithCoder(with:)` to to store data from a `CKRecord` instance.
	var cloudKey: String {
		"ckMeta"
	}

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
		}
	}

	// MARK: - NSCoding / NSCopying Support
	func copy(to: SQLTable) {
		to.created = created
		to.updated = updated
		to.isDeleted = isDeleted
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
		var sql = "UPDATE \(table) SET isDeleted = ?, updated = ?"
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
		// Call pre-save method
		preSave()
		// Save data
		let data = values()
		var insert = true
		if let rid = data[primaryKey] {
			var val = "\(rid)"
			if rid is String {
				val = "'\(rid)'"
			}
			let sql = "SELECT COUNT(*) AS count FROM \(table) WHERE \(primaryKey)=\(val)"
			let arr = db.query(sql: sql)
			if arr.count == 1 {
				if let cnt = arr[0]["count"] as? Int {
					insert = (cnt == 0)
				}
			}
		}
		// Insert or update
		updated = Date()
		let (sql, params) = getSQL(data: data, forInsert: insert)
		let rc = db.execute(sql: sql, parameters: params)
		if rc == 0 {
			NSLog("Error saving record!")
			return 0
		}
		// Update primary key
		let pid = data[primaryKey]
		if insert {
			if pid is Int64 {
				setValue(rc, forKey: primaryKey)
			} else if pid is Int {
				setValue(Int(rc), forKey: primaryKey)
			}
		}
		// Do cloud update - check (as to whether to save to cloud is done by DB)
		if updateCloud && db.cloudEnabled {
			SQLTable.save(items: [self]) {(error) in
				if let error = error {
					NSLog("Error saving data to iCloud: \(error)")
				}
			}
		}
		return rc
	}

	/// Delete the row for this particular `SQLTable` sub-class instance from the database.
	///
	/// - Parameter force: Flag indicating whether to force delete the records or simply mark them as deleted. Defaluts to `false`.
	/// - Returns: A boolean value indicating the success or failure of the operation.
	func delete(updateCloud: Bool = true, force: Bool = false) -> Bool {
		let data = values()
		var res = 0
		if let rid = data[primaryKey] {
			var params: [Any]? = [true, Date()]
			var sql = "UPDATE \(table) SET isDeleted = ?, updated = ? WHERE \(primaryKey)=\(rid)"
			if force {
				params = nil
				sql = "DELETE FROM \(table) WHERE \(primaryKey)=\(rid)"
			}
			res = db.execute(sql: sql, parameters: params)
		}
		if updateCloud && db.cloudEnabled {
			cloudDelete()
		}
		return (res != 0)
	}

	/// Delete a record from CloudKit
	func cloudDelete() {
		let ckDB = CloudDB.shared
		let db = ckDB.dbFor(scope: Self.cloudDB)
		// Set up remote ID
		guard let ckid = recordID() else { return }
		db.delete(withRecordID: ckid) { rid, error in
			if let error = error {
				NSLog("Error deleting CloudKit record: \(error.localizedDescription)")
				return
			}
			NSLog("Deleted record successfully! ID - \(rid!.recordName)")
		}
	}

	/// Update the data for this particular `SQLTable` sub-class instance from the database so that all values are updated with the latest values from the database.
	func refresh() {
		let data = values()
		if let rid = data[primaryKey] {
			let sql = "SELECT * FROM \(table) WHERE \(primaryKey)=\(rid)"
			let arr = db.query(sql: sql)
			for (key, _) in data {
				if let val = arr[0][key] {
					setValue(val, forKey: key)
				}
			}
		}
	}

	/// Sub-classed method which is called before saving data in case you needed to set up data to be saved
	func postLoad() {
		// To be overridden in sub-class
	}
	
	/// Sub-classed method which is called after loading data in case you needed to set up extra properties based on loaded data
	func preSave() {
		// To be overridden in sub-class
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

	/// Create a `CKRecord` instance from contained data and the previously stored meta data (if it exists)
	internal func getRecord() -> CKRecord {
		let data = values()
		guard let pid = data[primaryKey] else {
			fatalError("Could not get Primary Key for data: \(data)")
		}
		let name = "\(table)-\(pid)"
		let rid = CKRecord.ID(recordName: name, zoneID: Self.zoneID)
		var rec = CKRecord(recordType: Self.recordType, recordID: rid)
		// Set up CloudKit meta data
		if let meta = data[cloudKey] as? Data, !meta.isEmpty {
			do {
				let unarchiver = try NSKeyedUnarchiver(forReadingFrom: meta)
				unarchiver.requiresSecureCoding = true
				if let r = CKRecord(coder: unarchiver) {
					rec = r
				}
			} catch {
				NSLog("Error unarchive CKRecord meta data: \(error)")
			}
		}
		// Load data
		for key in data.keys {
			if key == cloudKey {
				continue
			}
			rec[key] = data[key] as? __CKRecordObjCValue
		}
		return rec
	}

	/// Load data from a passed in `CKRecord` instance and store the meta data from the `CKRecord`
	internal func cloudLoad(record: CKRecord, onlyMeta: Bool = false) {
		let data = values()
		let archiver = NSKeyedArchiver(requiringSecureCoding: true)
		record.encodeSystemFields(with: archiver)
		let meta = archiver.encodedData
		self.setValue(meta, forKey: cloudKey)
		if onlyMeta {
			return
		}
		// Set primary key from record info
		var name = record.recordID.recordName
		name = name.replacingOccurrences(of: "\(table)-", with: "")
		if let pid = Int(name) {
			self.setValue(pid, forKey: primaryKey)
		}
		// Set the rest of the data based on class properties
		for key in data.keys {
			// Skip meta data key and primary key since we've already set them
			if key == cloudKey || key == primaryKey {
				continue
			}
			if let value = record[key] {
				self.setValue(value, forKey: key)
			}
		}
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

	/// Get the CloudKit record ID for the passed in SQLTable sub-class. The method creates a record ID if there's a valid record ID. If not, it returns `nil`.
	///   - row: The SQLTable instance to be deleted remotely.
	///   - type: The database type - should be one of `.public`, `.private`, or `.shared`.
	private func recordID() -> CKRecord.ID? {
		let data = values()
		// Set up remote ID
		if let meta = data[cloudKey] as? Data, !meta.isEmpty {
			if let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: meta) {
				unarchiver.requiresSecureCoding = true
				let rec = CKRecord(coder: unarchiver)
				return rec?.recordID
			}
		}
		// Set up record ID based on local ID and type
		if let pid = data[primaryKey] {
			let name = "\(table)-\(pid)"
			let rid = CKRecord.ID(recordName: name, zoneID: Self.zoneID)
			return rid
		}
		return nil
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
				if ignoredKeys.contains(name) || name.hasSuffix(".storage") || name.hasPrefix("_") {
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
			sql = "INSERT INTO \"\(table)\"("
		} else {
			// UPDATE tasks SET task = ? WHERE categoryID = ?
			sql = "UPDATE \"\(table)\" SET "
		}
		var wsql = ""
		var rid: Any?
		var first = true
		for (key, val) in data {
			// Primary key handling
			if primaryKey == key {
				if forInsert {
					// Skip primary key only if it is not set, since if the data is coming from the cloud, the primary key will be already set
                    if let sid = val as? String, sid.isEmpty {
                        continue
                    } else if let nid = val as? Int, nid == -1 {
                        continue
                    }
				} else {
					// Update - set up WHERE clause
					wsql += " WHERE \"" + key + "\" = ?"
					rid = val
					continue
				}
			}
			// Set up parameter array - if we get here, then there are parameters
			if first, params == nil {
				params = [Any]()
			}
			if forInsert {
				sql += first ? "\"\(key)\"" : ", \"\(key)\""
				if val is String || val is Data || val is Date {
					wsql += first ? " VALUES (?" : ", ?"
					params!.append(val)
				} else {
					wsql += first ? " VALUES (\(val)" : ", \(val)"
				}
			} else {
				if val is String || val is Data || val is Date {
					sql += first ? "\"\(key)\" = ?" : ", \"\(key)\" = ?"
					params!.append(val)
				} else {
					sql += first ? "\"\(key)\" = \(val)" : ", \"\(key)\" = \(val)"
				}
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
			if key == primaryKey {
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
			} else if val is Data {
				sql += "BLOB"
			} else {
				// Default to text
				sql += "TEXT"
			}
			if key == primaryKey {
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

	static var recordType: String {
		return "\(classForCoder())"
	}
	/// The CloudKit database type for the table - defaults to `private`. Override this in sub-classes to define a different type for a specific table.
	///
	/// - Returns: A `CKDatabase.Scope` enum indicating the CloudKit database type for the table. Defaults to `private`.
	static var cloudDB: CKDatabase.Scope {
		.private
	}

	/// The custom internal CloudKit zone, or the default one for databases that don't support custom zones
	static var zone: CKRecordZone {
		if cloudDB != .public {
			return CKRecordZone(zoneName: "custom-zone")
		}
		return CKRecordZone.default()
	}

	/// The CloudKit zone ID for the internal custom zone
	static var zoneID: CKRecordZone.ID {
		zone.zoneID
	}

	/// Create a custom zone to contain our records. We only have to do this once.
	static func createZone(completion: @escaping (Error?) -> Void) {
		let ckDB = CloudDB.shared
		let db = ckDB.dbFor(scope: Self.cloudDB)
		let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: [])
		operation.modifyRecordZonesResultBlock = { result in
			switch result {
			case .failure(let error):
				NSLog("Error modifying record zones: \(error)")
				completion(error)
				
			case .success:
				completion(nil)
			}
		}
		db.add(operation)
	}

	/// Get all records for this table from CloudKit that match passed in predicate, or all records if no predicate is provided
    static func records(predicate: NSPredicate = NSPredicate(value: true), completion: @escaping ([Self], Error?) -> Void) {
		var res = [Self]()
		let ckDB = CloudDB.shared
		let db = ckDB.dbFor(scope: Self.cloudDB)
		let query = CKQuery(recordType: recordType, predicate: predicate)
        var cnt = 0
        // Create query operation since db.perform only fetches a few hundreds records at most and not the full set of data. Query operation also has a maximum, but also returns a cursor when there are more records
        var qop = CKQueryOperation(query: query)
        qop.zoneID = zoneID
        // Query operation record fetch block to handle fetched records
		qop.recordMatchedBlock = {rid, result in
			switch result {
			case .failure(let error):
				NSLog("Record matched error: \(error)")
				
			case .success(let rec):
				cnt += 1
				let t = Self.init()
				t.cloudLoad(record: rec)
				res.append(t)
			}
		}
        // Query operation completion block
		qop.queryResultBlock = { result in
			switch result {
			case .failure(let error):
				DispatchQueue.main.async {
					completion(res, error)
				}
				
			case .success(let cursor):
				// Did we get a cursor back?
				if let cursor = cursor {
					NSLog("*** Cursor - sending another query")
					let newq = CKQueryOperation(cursor: cursor)
					newq.zoneID = zoneID
					newq.queryResultBlock = qop.queryResultBlock
					newq.recordMatchedBlock = qop.recordMatchedBlock
					// We must hang on to the new query so as to complete everything correctly
					qop = newq
					db.add(qop)
				} else {
					NSLog("*** At end: processed \(cnt) records")
					// We are done
					DispatchQueue.main.async {
						completion(res, nil)
					}
				}
			}
		}
        db.add(qop)
	}

	/// Fetch a record from CloudKit for a given record name
	func record(name: String, completion: @escaping (CKRecord?, Error?) -> Void) {
		let ckDB = CloudDB.shared
		let db = ckDB.dbFor(scope: Self.cloudDB)
		let recordID = CKRecord.ID(recordName: name, zoneID: Self.zoneID)
		let operation = CKFetchRecordsOperation(recordIDs: [recordID])
		// We want only a single record - so perRecordResultBlock works. If we wanted a batch of records, then we'd have to batch up the results from perRecordResultBlock and then wait for fetchRecordsResultBlock completion to call the final closure with the full batch of results
		operation.perRecordResultBlock = { recordID, result in
			switch result {
			case .failure(let error):
				completion(nil, error)

			case .success(let record):
				completion(record, nil)
			}
		}
//		operation.fetchRecordsResultBlock = { result in
//			switch result {
//			case .failure(let error):
//				completion(nil, error)
//
//			case .success:
//				completion(records, nil)
//			}
//		}
		db.add(operation)
	}

	/// Save a record to CloudKit
	static func save(items: [Self], completion: @escaping (Error?) -> Void) {
		let ckDB = CloudDB.shared
		let db = ckDB.dbFor(scope: Self.cloudDB)
		// Get CKRecords
		var records = [CKRecord]()
		for item in items {
			let r = item.getRecord()
			records.append(r)
		}
		let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
        operation.savePolicy = .changedKeys
		// Should handle saved and deleted records via perRecordsSaveBlock and perRecordsDeleteBlock individually and if the data needs to be sent via closure, batch to separate arrays that can be sent when modifyRecordsResultBlock is executed/called.
		operation.perRecordSaveBlock = { recordID, result in
			switch result {
			case .failure(let error):
				// Cascade down to see if the error is ZoneNotFound
				guard let ckerror = error as? CKError else {
					NSLog("CloudKit save returned non-CKError: \(error)")
					return
				}
#if os(iOS)
				guard ckerror.code == .zoneNotFound else {
					NSLog("CloudKit save returned CKError that isn't ZoneNotFound: \(error)")
					return
				}
#endif
				// ZoneNotFound is the one error we can reasonably expect & handle here, since the zone isn't created automatically for us until we've saved one record. create the zone and, if successful, try again
				Self.createZone { error in
					guard error == nil else {
						// If we cannot create Zone, then that's it. Error out.
						completion(error)
						return
					}
					self.save(items: items, completion: completion)
				}
				
			case .success(let record):
				if let ndx = records.firstIndex(of: record) {
					let t = items[ndx]
					t.cloudLoad(record: record, onlyMeta: true)
				}
				// Comletion will be called from modifyRecordsResultBlock at the end of processing all records
			}
		}
		operation.modifyRecordsResultBlock = { result in
			switch result {
			case .failure(let error):
				NSLog("Error saving CloudKit records: \(error)")
				completion(error)
				
			case .success:
				completion(nil)
			}
		}
//		operation.modifyRecordsCompletionBlock = {(saved, deleted, error) in
//			guard error == nil else {
//				guard let ckerror = error as? CKError else {
//					completion(error)
//					return
//				}
//#if os(iOS)
//				guard ckerror.code == .zoneNotFound else {
//					completion(error)
//					return
//				}
//#endif
//				// ZoneNotFound is the one error we can reasonably expect & handle here, since the zone isn't created automatically for us until we've saved one record. create the zone and, if successful, try again
//				Self.createZone { error in
//					guard error == nil else {
//						completion(error)
//						return
//					}
//					self.save(items: items, completion: completion)
//				}
//				return
//			}
//			if let saved = saved, saved.count == items.count {
//				// Update meta data from CloudKit
//				for (index, row) in saved.enumerated() {
//					let t = items[index]
//					t.cloudLoad(record: row, onlyMeta: true)
//				}
//			} else {
//				NSLog("No saved records returned even though there was no error or different count returned")
//			}
//			completion(nil)
//		}
		db.add(operation)
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
			// Call post-load for data record
			t.postLoad()
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
		let sql = "SELECT * FROM \(table) WHERE \(row.primaryKey)=\(val)"
		let arr = db.query(sql: sql)
		if arr.count == 0 {
			return nil
		}
		for (key, _) in data {
			if let val = arr[0][key] {
				row.setValue(val, forKey: key)
			}
		}
		// Call post-load for data record
		row.postLoad()
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
		// Call post-load for data record
		row.postLoad()
		return row
	}
}
