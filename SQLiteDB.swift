//
//  SQLiteDB.swift
//  TasksGalore
//
//  Created by Fahim Farook on 12/6/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//
import Foundation

// MARK:- SQLiteDB Class
/// Simple wrapper class to provide basic SQLite database access.
@objc(SQLiteDB)
class SQLiteDB: SQLiteBase {
	/// Does this database have CloudKit support for remote data saving?
	var cloudEnabled = false {
		didSet {
			if cloudEnabled {
				self.cloudDB = CloudDB.shared
			} else {
				self.cloudDB = nil
			}
		}
	}
	/// Singleton instance for access to the SQLiteDB class
	static let shared = SQLiteDB()
	/// Internal reference to CloudDB instance
	private var cloudDB: CloudDB!
	
	private override init() {
		super.init()
	}
	
	/// Output the current SQLite database path
	override var description:String {
		return "SQLiteDB: \(path ?? "")"
	}
	
	// MARK:- Public Methods
	/// Open the database specified by the `DB_NAME` variable and assigns the internal DB references. If a database is currently open, the method first closes the current database and gets a new DB references to the current database pointed to by `DB_NAME`
	///
	/// - Parameter copyFile: Whether to copy the file named in `DB_NAME` from resources or to create a new empty database file. Defaults to `true`
	/// - Returns: Returns a boolean value indicating if the database was successfully opened or not.
	override func open(dbPath: String = "", copyFile: Bool = true, inMemory: Bool = false) -> Bool {
		NSLog("DB Open called with path: \(dbPath)")
		var path = ""
		if !inMemory {
			if dbPath.isEmpty {
				guard let url = Bundle.main.resourceURL else { return false }
				path = url.appendingPathComponent(DB_NAME).path
			} else {
				path = URL(fileURLWithPath: dbPath).path
			}
		}
		NSLog("Calling Super Open with path: \(path)")
		return super.open(dbPath: path, copyFile: copyFile, inMemory: inMemory)
	}
	
	/// Close the currently open SQLite database. Before closing the DB, the framework automatically takes care of optimizing the DB at frequent intervals by running the following commands:
	/// 1. **VACUUM** - Repack the DB to take advantage of deleted data
	/// 2. **ANALYZE** - Gather information about the tables and indices so that the query optimizer can use the information to make queries work better.
	override func closeDB() {
		if db != nil {
			// Get launch count value
			let ud = UserDefaults.standard
			var launchCount = ud.integer(forKey:"LaunchCount")
			launchCount -= 1
			NSLog("SQLiteDB - Launch count \(launchCount)")
			var clean = false
			if launchCount < 0 {
				clean = true
				launchCount = 500
			}
			ud.set(launchCount, forKey:"LaunchCount")
			ud.synchronize()
			// Do we clean DB?
			if !clean {
				sqlite3_close(db)
				return
			}
			// Clean DB
			NSLog("SQLiteDB - Optimize DB")
			let sql = "VACUUM; ANALYZE"
			if CInt(execute(sql:sql)) != SQLITE_OK {
				NSLog("SQLiteDB - Error cleaning DB")
			}
			super.closeDB()
		}
	}
	
	/// Create a record zone in the private DB for the given table
	/// - Parameter version: An integer value indicating the new DB version.
	func createCloudZone(table: SQLTable, completion: @escaping ()->Void) {
		cloudDB.creaeZone(table: table) {
			completion()
		}
	}
	
	func getCloudUpdates(table: SQLTable) {
		cloudDB.getUpdates(table: table)
	}
	
	/// Save data to the cloud via CloudKit
	/// - Parameters:
	///   - row: The SQLTable instance to be saved remotely.
	///   - dbOverride: A `DBType` indicating the database to save the remote data to. If set, this overrides the database set by default for the table via the `remoteDB` method. Defaults to `none`.
	func saveToCloud(row: SQLTable, dbOverride: DBType = .none) {
		if !cloudEnabled {
			return
		}
		// Save to cloude
		cloudDB.saveToCloud(row: row)
	}
}
