//
//  DBTable.swift
//  SpamBGone
//
//  Created by Fahim Farook on 23-10-2020.
//  Copyright © 2020 RookSoft Ltd. All rights reserved.
//

import CloudKit
import Foundation

protocol DBTableProtocol {}

@objcMembers
class DBTable: NSObject, DBTableProtocol {
	internal var table = ""
	internal var ckMeta = Data()
	internal var order = -1

	/// An array of property names (in a sub-classed instance of `SQLTable`) that are to be ignored when fetching/saving information to the DB. Override this method in sub-classes when you have properties that you don't want persisted to the database.
	var ignoredKeys: [String] {
		return []
	}

	/// The CloudKit meta data key name for the table - defaults to `ckMeta`. Override this in sub-classes to define a different column name. This key should be data type and will be using `encodeSystemFieldsWithCoder(with:)` to to store data from a `CKRecord` instance.
	var cloudKey: String {
		"ckMeta"
	}

	override required init() {
		self.table = type(of: self).table
	}

	/// Delete a record from CloudKit
	func delete() {
		let ckDB = DBManager.shared
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

	// MARK: - Internal Methods
	/// Create a `CKRecord` instance from contained data and the previously stored meta data (if it exists)
	internal func getRecord() -> CKRecord {
		let data = values()
		let rid = CKRecord.ID(zoneID: Self.zoneID)
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
	internal func load(record: CKRecord, onlyMeta: Bool = false) {
		let data = values()
		let archiver = NSKeyedArchiver(requiringSecureCoding: true)
		record.encodeSystemFields(with: archiver)
		let meta = archiver.encodedData
		self.setValue(meta, forKey: cloudKey)
		if onlyMeta {
			return
		}
		// Set the rest of the data based on class properties
		for key in data.keys {
			// Skip meta data key since we've already set that one
			if key == cloudKey {
				continue
			}
			if let value = record[key] {
				self.setValue(value, forKey: key)
			}
		}
	}

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
		return nil
	}

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
				if ignoredKeys.contains(name) || name.hasSuffix(".storage") {
					continue
				}
				results[name] = attr.value
			}
		}
	}
}

extension DBTableProtocol where Self: DBTable {
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

	/// The CloudKit zone name for the table - defaults to table name + `-zone`. Override to set your own custom zone name.
	static var zoneName: String {
		table + "-zone"
	}

	/// The CloudKit zone based on the `zoneName`.
	static var zone: CKRecordZone {
		if cloudDB == .private {
			return CKRecordZone(zoneName: zoneName)
		}
		return CKRecordZone.default()
	}

	/// The CloudKit zone ID based on the `zoneName`.
	static var zoneID: CKRecordZone.ID {
		zone.zoneID
	}


	/// Create a custom zone to contain our records. We only have to do this once.
	static func createZone(completion: @escaping (Error?) -> Void) {
		let ckDB = DBManager.shared
		let db = ckDB.dbFor(scope: Self.cloudDB)
		let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: [])
		operation.modifyRecordZonesCompletionBlock = { _, _, error in
			guard error == nil else {
				completion(error)
				return
			}
			completion(nil)
		}
		db.add(operation)
	}

	/// Get all records for this table from CloudKit
	static func records(completion: @escaping ([Self], Error?) -> Void) {
		var res = [Self]()
		let ckDB = DBManager.shared
		let db = ckDB.dbFor(scope: Self.cloudDB)
		let predicate = NSPredicate(value: true)
		let query = CKQuery(recordType: recordType, predicate: predicate)
		db.perform(query, inZoneWith: zoneID) { results, error in
			if let error = error {
				DispatchQueue.main.async {
					completion(res, error)
				}
				return
			}
			guard let results = results else { return }
			for row in results {
				let t = Self.init()
				t.load(record: row)
				res.append(t)
			}
			DispatchQueue.main.async {
				completion(res, nil)
			}
		}
	}

	/// Fetch a record from CloudKit
	func record(name: String, completion: @escaping (CKRecord?, Error?) -> Void) {
		let ckDB = DBManager.shared
		let db = ckDB.dbFor(scope: Self.cloudDB)
		let recordID = CKRecord.ID(recordName: name, zoneID: Self.zoneID)
		let operation = CKFetchRecordsOperation(recordIDs: [recordID])
		operation.fetchRecordsCompletionBlock = { records, error in
			guard error == nil else {
				completion(nil, error)
				return
			}
			guard let noteRecord = records?[recordID] else {
				// Didn't get the record we asked about? This shouldn’t happen but we’ll be defensive.
				completion(nil, CKError.unknownItem as? Error)
				return
			}
			completion(noteRecord, nil)
		}
		db.add(operation)
	}

	/// Save a record to CloudKit
	static func save(items: [Self], completion: @escaping (Error?) -> Void) {
		let ckDB = DBManager.shared
		let db = ckDB.dbFor(scope: Self.cloudDB)
		// Get CKRecords
		var records = [CKRecord]()
		for (ndx, item) in items.enumerated() {
			item.order = ndx
			let r = item.getRecord()
			records.append(r)
		}
		let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
		operation.modifyRecordsCompletionBlock = {(saved, deleted, error) in
			guard error == nil else {
				guard let ckerror = error as? CKError else {
					completion(error)
					return
				}
				guard ckerror.isZoneNotFound() else {
					completion(error)
					return
				}
				// ZoneNotFound is the one error we can reasonably expect & handle here, since the zone isn't created automatically for us until we've saved one record. create the zone and, if successful, try again
				Self.createZone { error in
					guard error == nil else {
						completion(error)
						return
					}
					self.save(items: items, completion: completion)
				}
				return
			}
			if let saved = saved, saved.count == items.count {
				// Update meta data from CloudKit
				for (index, row) in saved.enumerated() {
					let t = items[index]
					t.load(record: row, onlyMeta: true)
				}
			} else {
				NSLog("No saved records returned even though there was no error or different count returned")
			}
			completion(nil)
		}
		db.add(operation)
	}
}
