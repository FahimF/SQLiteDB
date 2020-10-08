//
//  CloudDB.swift
//  SQLiteDB-iOS
//
//  Created by Fahim Farook on 10/4/2017.
//  Copyright © 2017 RookSoft Pte. Ltd. All rights reserved.
//

import CloudKit

@objc
enum DBType: Int {
	case none, publicDB, privateDB, sharedDB
}

// MARK:- CloudDB Class
/// Class for remotely saving local SQLiteDB data using CloudKit
@objc(CloudDB)
class CloudDB: NSObject {
	/// Singleton instance for access to the CloudDB class
	static let shared = CloudDB()
	/// Default CloudKit container
	private let container = CKContainer.default()
	/// Reference to public CloudKit database
	private let publicDB: CKDatabase
	/// Reference to private CloudKit database
	private let privateDB: CKDatabase
	/// Reference to shared CloudKit database
	private let sharedDB: CKDatabase!

	override private init() {
		self.publicDB = container.publicCloudDatabase
		self.privateDB = container.privateCloudDatabase
		if #available(iOS 10.0, macOS 10.12, tvOS 10.0, watchOS 3.0, *) {
			self.sharedDB = container.sharedCloudDatabase
		} else {
			self.sharedDB = nil
		}
		super.init()
	}
	
	/// Create a record zone in the private DB for the given table
	/// - Parameter version: An integer value indicating the new DB version.
	func creaeZone(table: SQLTable, completion: @escaping ()->Void) {
		let zone = CKRecordZone(zoneName: table.table)
		privateDB.save(zone) {(_, error) in
			if let error = error {
				NSLog("Error creating record zone for: \(table.table) - \(error.localizedDescription)")
			}
			completion()
		}
	}
	
	func getUpdates(table: SQLTable) {
		if table.remoteDB() == DBType.privateDB {
			// Get updates via CKFetchRecordChangesOperation
		} else {
			// Get all updates via CKFetchDatabaseChangesOperation
		}
	}
	
	/// Save data to the cloud via CloudKit
	/// - Parameters:
	///   - row: The SQLTable instance to be saved remotely.
	///   - dbOverride: A `DBType` indicating the database to save the remote data to. If set, this overrides the database set by default for the table via the `remoteDB` method. Defaults to `none`.
	func saveToCloud(row: SQLTable, dbOverride: DBType = .none) {
		var type = row.remoteDB()
		if dbOverride != .none {
			type = dbOverride
		}
		// Set up remote ID
		let idName = row.remoteKey()
		var sid = ""
		let rid = recordIDFor(row: row, type: type)
		if let rid = rid {
			sid = rid.recordName
		}
		// Create CloudKit record
		let record = recordFor(recordID: rid, row: row, type: type)
		// Save to DB
		let db = dbFor(type: type)
		db.save(record) {(rec, error) in
			if let error = error {
				NSLog("Error saving CloudKit data: \(error.localizedDescription)")
				return
			}
			// Save remote id locally
			if let rec = rec {
				let ckid = rec.recordID.recordName
				if sid != ckid {
					row.setValue(ckid, forKey: idName)
					_ = row.save(updateCloud: false)
				}
				NSLog("Saved record successfully! ID - \(ckid)")
			}
		}
	}
	
	/// Delete data from the cloud via CloudKit
	/// - Parameters:
	///   - row: The SQLTable instance to be deleted remotely.
	///   - dbOverride: A `DBType` indicating the database to delete the remote data from. If set, this overrides the database set by default for the table via the `remoteDB` method. Defaults to `none`.
	func deleteFromCloud(row: SQLTable, dbOverride: DBType = .none) {
		var type = row.remoteDB()
		if dbOverride != .none {
			type = dbOverride
		}
		// DB to use
		let db = dbFor(type: type)
		// Set up remote ID
		guard let ckid = recordIDFor(row: row, type: type) else { return }
		db.delete(withRecordID: ckid) { (rid, error) in
			if let error = error {
				NSLog("Error deleting CloudKit record: \(error.localizedDescription)")
				return
			}
			NSLog("Deleted record successfully! ID - \(rid!.recordName)")
		}
	}
	
	/// Fetch changes for a given SQLTable sub-class and update the table with the changes. This can only be run on the private CloudKit database - so assumes that the call is for the private DB.
	/// - Parameter row: A instance from an `SQLTable` sub-class. We need this to get relevant row information. So if necessary, just pass a newly created instance - the passed in row is not modified in any way.
	func fetchChanges(row:SQLTable) {
		
	}
	
	// MARK:- Private Methods
	/// Get the CloudKit database to use dependent on the passed-in database type
	/// - Parameter type: The database type - should be one of `.public`, `.private`, or `.shared`.
	private func dbFor(type: DBType) -> CKDatabase {
		// DB to use
		switch type {
		case .publicDB:
			return publicDB
		case .privateDB:
			return privateDB
		case .sharedDB:
			return sharedDB
		case .none:
			assertionFailure("Should not have received a DBType of .none to get DB!")
		}
		return publicDB
	}
	
	/// Get the CloudKit record ID for the passed in SQLTable sub-class. The method creates a record ID if there's a valid record ID. If not, it returns `nil`.
	///   - row: The SQLTable instance to be deleted remotely.
	///   - type: The database type - should be one of `.public`, `.private`, or `.shared`.
	private func recordIDFor(row: SQLTable, type: DBType) -> CKRecord.ID? {
		let data = row.values()
		// Set up remote ID
		let idName = row.remoteKey()
		if let sid = data[idName] as? String, !sid.isEmpty {
			if type == .privateDB {
				let zone = CKRecordZone.ID(zoneName: row.table, ownerName: CKCurrentUserDefaultName)
				return CKRecord.ID(recordName: sid, zoneID: zone)
			} else {
				return CKRecord.ID(recordName: sid)
			}
		}
		return nil
	}
	
	/// Get the CloudKit record for the passed in SQLTable sub-class. The method creates a new CKRecord instance containing the data from the `SQLTable` sub-class.
	///   - row: The SQLTable instance to be deleted remotely.
	///   - type: The database type - should be one of `.public`, `.private`, or `.shared`.
	private func recordFor(recordID: CKRecord.ID?, row: SQLTable, type: DBType) -> CKRecord {
		let data = row.values()
		let idName = row.remoteKey()
		let record: CKRecord
		if let ckid = recordID {
			record = CKRecord(recordType: row.table, recordID: ckid)
		} else {
			if type == .privateDB {
//				let zone = CKRecordZone.ID(zoneName: row.table, ownerName: CKCurrentUserDefaultName)
//				let ckid = CKRecord.ID(recordName: "", zoneID: zone)
//				record = CKRecord(recordType: row.table, recordID: ckid)
				record = CKRecord(recordType: row.table)
			} else {
				record = CKRecord(recordType: row.table)
			}
		}
		for (key, val) in data {
			if let ckval = val as? CKRecordValue {
				// Handle CloudKit ID
				if key == idName {
					continue
				}
				record[key] = ckval
			}
		}
		return record
	}
}
