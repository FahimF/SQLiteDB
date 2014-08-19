//
//  SQLiteDB.swift
//  TasksGalore
//
//  Created by Fahim Farook on 12/6/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//

import Foundation
import UIKit

let SQLITE_DATE = SQLITE_NULL + 1

@objc class SQLColumn {
	var value:AnyObject? = nil
	var type:CInt = -1

	init(value:AnyObject, type:CInt) {
//		println("SQLiteDB - Initialize column with type: \(type), value: \(value)")
		self.value = value
		self.type = type
	}
	
	// New conversion functions
	func asString()->String {
		switch (type) {
			case SQLITE_INTEGER, SQLITE_FLOAT:
				return "\(value!)"
			case SQLITE_TEXT:
				return value as String
			case SQLITE_BLOB:
				let str = NSString(data:value as NSData, encoding:NSUTF8StringEncoding)
				return str
			case SQLITE_NULL:
				return ""
			case SQLITE_DATE:
				let fmt = NSDateFormatter()
				fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
				return fmt.stringFromDate(value as NSDate)
			default:
				return ""
		}
	}

	func asInt()->Int {
		switch (type) {
			case SQLITE_INTEGER, SQLITE_FLOAT:
				return value as Int
			case SQLITE_TEXT:
				let str = value as NSString
				return str.integerValue
			case SQLITE_BLOB:
				let str = NSString(data:value as NSData, encoding:NSUTF8StringEncoding)
				return str.integerValue
			case SQLITE_NULL:
				return 0
			case SQLITE_DATE:
				return Int((value as NSDate).timeIntervalSince1970)
			default:
				return 0
		}
	}
	
	func asDouble()->Double {
		switch (type) {
			case SQLITE_INTEGER, SQLITE_FLOAT:
				return value as Double
			case SQLITE_TEXT:
				let str = value as NSString
				return str.doubleValue
			case SQLITE_BLOB:
				let str = NSString(data:value as NSData, encoding:NSUTF8StringEncoding)
				return str.doubleValue
			case SQLITE_NULL:
				return 0.0
			case SQLITE_DATE:
				return (value as NSDate).timeIntervalSince1970
			default:
				return 0.0
		}
	}
	
	func asData()->NSData? {
		switch (type) {
			case SQLITE_INTEGER, SQLITE_FLOAT:
				let str = "\(value)" as NSString
				return str.dataUsingEncoding(NSUTF8StringEncoding)
			case SQLITE_TEXT:
				let str = value as NSString
				return str.dataUsingEncoding(NSUTF8StringEncoding)
			case SQLITE_BLOB:
				return value as? NSData
			case SQLITE_NULL:
				return nil
			case SQLITE_DATE:
				let fmt = NSDateFormatter()
				fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
				let str = fmt.stringFromDate(value as NSDate)
				return str.dataUsingEncoding(NSUTF8StringEncoding)
			default:
				return nil
		}
	}
	
	func asDate()->NSDate? {
		switch (type) {
			case SQLITE_INTEGER, SQLITE_FLOAT:
				let tm = value as Double
				return NSDate(timeIntervalSince1970:tm)
			case SQLITE_TEXT:
				let fmt = NSDateFormatter()
				fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
				return fmt.dateFromString(value as String)
			case SQLITE_BLOB:
				let str = NSString(data:value as NSData, encoding:NSUTF8StringEncoding)
				let fmt = NSDateFormatter()
				fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
				return fmt.dateFromString(str)
			case SQLITE_NULL:
				return nil
			case SQLITE_DATE:
				return value as? NSDate
			default:
				return nil
		}
	}
	
	// Old variable functions - uncomment if you still need these
/*
	var string:String {
		if value != nil {
			if type == SQLITE_TEXT {
				return value as String
			} else {
				return ""
			}
		}
		return ""
	}
	
	var integer:Int {
		if type == SQLITE_INTEGER {
			return value as Int
		} else {
			return 0
		}
	}
	
	var data:NSData? {
		if type == SQLITE_BLOB {
			return value as? NSData
		} else {
			return nil
		}
	}
	
	var date:NSDate? {
		if type == SQLITE_DATE {
			return value as? NSDate
		} else {
			return nil
		}
	}
*/
}

@objc class SQLRow {
	var data = Dictionary<String, SQLColumn>()
	
	subscript(key: String) -> SQLColumn? {
		get {
			return data[key]
		}
		
		set(newVal) {
			data[key] = newVal
		}
	}
}

@objc class SQLiteDB {
	let DB_NAME = "data.db"
	let QUEUE_LABLE = "SQLiteDB"
	var db:COpaquePointer = nil
	var queue:dispatch_queue_t
	
	struct Static {
		static var instance:SQLiteDB? = nil
		static var token:dispatch_once_t = 0
	}
	
	class func sharedInstance() -> SQLiteDB! {
		dispatch_once(&Static.token) {
//			println("SQLiteDB - Dispatch once")
			Static.instance = self()
		}
		return Static.instance!
	}
 
	required init() {
//		println("SQLiteDB - Init method")
		assert(Static.instance == nil, "Singleton already initialized!")
		// Set queue
		queue = dispatch_queue_create(QUEUE_LABLE, nil)
		// Get path to DB in Documents directory
		let docDir:AnyObject = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
		let dbName:String = String.fromCString(DB_NAME)!
		let path = docDir.stringByAppendingPathComponent(dbName)
		// Check if copy of DB is there in Documents directory
		let fm = NSFileManager.defaultManager()
		if !(fm.fileExistsAtPath(path)) {
			// The database does not exist, so copy to Documents directory
			if let from = NSBundle.mainBundle().resourcePath?.stringByAppendingPathComponent(dbName) {
				var error:NSError?
				if !fm.copyItemAtPath(from, toPath: path, error: &error) {
					println("SQLiteDB - failed to copy writable version of DB!")
					println("Error - \(error!.localizedDescription)")
					return
				}
			}
		}
		// Open the DB
		let cpath = path.cStringUsingEncoding(NSUTF8StringEncoding)
		let error = sqlite3_open(cpath!, &db)
		if error != SQLITE_OK {
			// Open failed, close DB and fail
			println("SQLiteDB - failed to open DB!")
			sqlite3_close(db)
		}
	}
	
	deinit {
		closeDatabase()
	}
 
	func closeDatabase() {
		if db != nil {
			// Get launch count value
			let ud = NSUserDefaults.standardUserDefaults()
			var launchCount = ud.integerForKey("LaunchCount")
			launchCount--
			println("SQLiteDB - Launch count \(launchCount)")
			var clean = false
			if launchCount < 0 {
				clean = true
				launchCount = 500
			}
			ud.setInteger(launchCount, forKey: "LaunchCount")
			ud.synchronize()
			// Do we clean DB?
			if !clean {
				sqlite3_close(db)
				return
			}
			// Clean DB
			println("SQLiteDB - Optimize DB")
			let sql = "VACUUM; ANALYZE"
			if execute(sql) != SQLITE_OK {
				println("SQLiteDB - Error cleaning DB")
			}
			sqlite3_close(db)
		}
	}
	
	// Execute SQL and return result code
	func execute(sql:String)->CInt {
		var result:CInt = 0
		dispatch_sync(queue) {
			var cSql = sql.cStringUsingEncoding(NSUTF8StringEncoding)
			var stmt:COpaquePointer = nil
			// Prepare
			result = sqlite3_prepare_v2(self.db, cSql!, -1, &stmt, nil)
			if result != SQLITE_OK {
				sqlite3_finalize(stmt)
				let msg = "SQLiteDB - failed to prepare SQL: \(sql), Error: \(self.lastSQLError())"
				println(msg)
				self.alert(msg: msg)
				return
			}
			// Step
			result = sqlite3_step(stmt)
			if result != SQLITE_OK && result != SQLITE_DONE {
				sqlite3_finalize(stmt)
				let msg = "SQLiteDB - failed to execute SQL: \(sql), Error: \(self.lastSQLError())"
				println(msg)
				self.alert(msg: msg)
				return
			}
			// Is this an insert
			if sql.uppercaseString.hasPrefix("INSERT ") {
				// Known limitations: http://www.sqlite.org/c3ref/last_insert_rowid.html
				let rid = sqlite3_last_insert_rowid(self.db)
				result = CInt(rid)
			} else {
				result = 1
			}
			// Finalize
			sqlite3_finalize(stmt)
		}
		return result
	}
	
	// Run SQL query
	func query(sql:String)->[SQLRow] {
		var rows = [SQLRow]()
		dispatch_sync(queue) {
			var cSql = sql.cStringUsingEncoding(NSUTF8StringEncoding)
			var stmt:COpaquePointer = nil
			var result:CInt = 0
			// Prepare statement
			result = sqlite3_prepare_v2(self.db, cSql!, -1, &stmt, nil)
			if result != SQLITE_OK {
				sqlite3_finalize(stmt)
				let msg = "SQLiteDB - failed to prepare SQL: \(sql), Error: \(self.lastSQLError())"
				println(msg)
				self.alert(msg: msg)
				return
			}
			// Execute query
			var fetchColumnInfo = true
			var columnCount:CInt = 0
			var columnNames = [String]()
			var columnTypes = [CInt]()
			result = sqlite3_step(stmt)
			while result == SQLITE_ROW {
				// Should we get column info?
				if fetchColumnInfo {
					columnCount = sqlite3_column_count(stmt)
					for index in 0..<columnCount {
						// Get column name
						let name = sqlite3_column_name(stmt, index)
						columnNames.append(String.fromCString(name)!)
						// Get column type
						columnTypes.append(self.getColumnType(index, stmt: stmt))
					}
					fetchColumnInfo = false
				}
				// Get row data for each column
				var row = SQLRow()
				for index in 0..<columnCount {
					let key = columnNames[Int(index)]
					let type = columnTypes[Int(index)]
					if let val:AnyObject = self.getColumnValue(index, type: type, stmt: stmt) {
						let col = SQLColumn(value: val, type: type)
						row[key] = col
					}
				}
				rows.append(row)
				// Next row
				result = sqlite3_step(stmt)
			}
			sqlite3_finalize(stmt)
		}
		return rows
	}
	
	// SQL escape string - hacky version using an intermediate Objective-C class to make it work
	func esc(str: String)->String {
		println("SQLiteDB - Original string: \(str)")
		let sql = Bridge.esc(str)
		println("SQLiteDB - Escaped string: \(sql)")
		return sql
	}
	
	// SQL escape string - original version, does not work correctly at the moment
	func esc2(str: String)->String {
		println("SQLiteDB - Original string: \(str)")
		let args = getVaList([str as CVarArgType])
//		var buf = UnsafePointer<Int8>.alloc(100)
//		let cstr = sqlite3_vsnprintf(100, buf, "%Q", args)
//		println("SQLiteDB - Escaped result: \(cstr), buffer: \(buf.memory)")
		let cstr = sqlite3_vmprintf("%Q", args)
		println("SQLiteDB - Escaped result: \(cstr), Raw: \(cstr.debugDescription)")
		if let sql = String.fromCString(cstr) {
//		sqlite3_free(cstr)
			println("SQLiteDB - Escaped string: \(sql)")
			return sql
		}
		return ""
	}
	
	// Return last insert ID
	func lastInsertedRowID()->Int64 {
		var lid:Int64 = 0
		dispatch_sync(queue) {
			lid = sqlite3_last_insert_rowid(self.db)
		}
		return lid
	}
	
	// Return last SQL error
	func lastSQLError()->String {
		let buf = sqlite3_errmsg(self.db)
		return NSString(CString:buf, encoding:NSUTF8StringEncoding)
	}
	
	// Show alert with either supplied message or last error
	func alert(msg:String? = nil) {
		var txt = msg != nil ? msg! : lastSQLError()
		let alert = UIAlertView(title: "SQLiteDB", message: txt, delegate: nil, cancelButtonTitle: "OK")
		alert.show()
	}
	
	// Get column type
	func getColumnType(index:CInt, stmt:COpaquePointer)->CInt {
		var type:CInt = 0
		// Column types - http://www.sqlite.org/datatype3.html (section 2.2 table column 1)
		let blobTypes = ["BINARY", "BLOB", "VARBINARY"]
		let charTypes = ["CHAR", "CHARACTER", "CLOB", "NATIONAL VARYING CHARACTER", "NATIVE CHARACTER", "NCHAR", "NVARCHAR", "TEXT", "VARCHAR", "VARIANT", "VARYING CHARACTER"]
		let dateTypes = ["DATE", "DATETIME", "TIME", "TIMESTAMP"]
		let intTypes  = ["BIGINT", "BIT", "BOOL", "BOOLEAN", "INT", "INT2", "INT8", "INTEGER", "MEDIUMINT", "SMALLINT", "TINYINT"]
		let nullTypes = ["NULL"]
		let realTypes = ["DECIMAL", "DOUBLE", "DOUBLE PRECISION", "FLOAT", "NUMERIC", "REAL"]
		// Determine type of column - http://www.sqlite.org/c3ref/c_blob.html
		let buf = sqlite3_column_decltype(stmt, index)
//		println("SQLiteDB - Got column type: \(buf)")
		if buf != nil {
			var tmp = String.fromCString(buf)!.uppercaseString
			// Remove brackets
			let pos = tmp.positionOf("(")
			if pos > 0 {
				tmp = tmp.subStringTo(pos)
			}
			// Remove unsigned?
			// Remove spaces
			// Is the data type in any of the pre-set values?
//			println("SQLiteDB - Cleaned up column type: \(tmp)")
			if contains(intTypes, tmp) {
				return SQLITE_INTEGER
			}
			if contains(realTypes, tmp) {
				return SQLITE_FLOAT
			}
			if contains(charTypes, tmp) {
				return SQLITE_TEXT
			}
			if contains(blobTypes, tmp) {
				return SQLITE_BLOB
			}
			if contains(nullTypes, tmp) {
				return SQLITE_NULL
			}
			if contains(dateTypes, tmp) {
				return SQLITE_DATE
			}
			return SQLITE_TEXT
		} else {
			// For expressions and sub-queries
			type = sqlite3_column_type(stmt, index)
		}
		return type
	}
	
	// Get column value
	func getColumnValue(index:CInt, type:CInt, stmt:COpaquePointer)->AnyObject? {
		// Integer
		if type == SQLITE_INTEGER {
			let val = sqlite3_column_int(stmt, index)
			return Int(val)
		}
		// Float
		if type == SQLITE_FLOAT {
			let val = sqlite3_column_double(stmt, index)
			return Double(val)
		}
		// Text - handled by default handler at end
		// Blob
		if type == SQLITE_BLOB {
			let data = sqlite3_column_blob(stmt, index)
			let size = sqlite3_column_bytes(stmt, index)
			let val = NSData(bytes:data, length: Int(size))
			return val
		}
		// Null
		if type == SQLITE_NULL {
			return nil
		}
		// Date
		if type == SQLITE_DATE {
			// Is this a text date
			let txt = UnsafePointer<Int8>(sqlite3_column_text(stmt, index))
			if txt != nil {
				let buf = NSString(CString:txt, encoding:NSUTF8StringEncoding) as NSString
				let set = NSCharacterSet(charactersInString: "-:")
				let range = buf.rangeOfCharacterFromSet(set)
				if range.location != NSNotFound {
					// Convert to time
					var time:tm = tm(tm_sec: 0, tm_min: 0, tm_hour: 0, tm_mday: 0, tm_mon: 0, tm_year: 0, tm_wday: 0, tm_yday: 0, tm_isdst: 0, tm_gmtoff: 0, tm_zone:nil)
					strptime(txt, "%Y-%m-%d %H:%M:%S", &time)
					time.tm_isdst = -1
					let diff = NSTimeZone.localTimeZone().secondsFromGMT
					let t = mktime(&time) + diff
					let ti = NSTimeInterval(t)
					let val = NSDate(timeIntervalSince1970:ti)
					return val
				}
			}
			// If not a text date, then it's a time interval
			let val = sqlite3_column_double(stmt, index)
			let dt = NSDate(timeIntervalSince1970: val)
			return dt
		}
		// If nothing works, return a string representation
		let buf = UnsafePointer<Int8>(sqlite3_column_text(stmt, index))
		let val = String.fromCString(buf)
//		println("SQLiteDB - Got value: \(val)")
		return val
	}
}