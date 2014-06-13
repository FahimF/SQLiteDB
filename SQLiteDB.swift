//
//  SQLiteDB.swift
//  TasksGalore
//
//  Created by Fahim Farook on 12/6/14.
//  Copyright (c) 2014 RookSoft Pte. Ltd. All rights reserved.
//

import Foundation
import UIKit

class SQLiteDB {
	let DB_NAME:CString = "data.db"
	var db:COpaquePointer = nil
	var queue:dispatch_queue_t = dispatch_queue_create("SQLiteDB", nil)
	
	class func sharedInstance() -> SQLiteDB! {
		struct Static {
			static var instance: SQLiteDB? = nil
			static var onceToken: dispatch_once_t = 0
		}
		
		dispatch_once(&Static.onceToken) {
			println("SQLiteDB - Dispatch once")
			Static.instance = self()
		}
		return Static.instance!
	}
 
	@required init() {
		println("SQLiteDB - Init method")
		// Get path to DB in Documents directory
		let docDir:AnyObject = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
		let dbName:String = String.fromCString(DB_NAME)
		let path = docDir.stringByAppendingPathComponent(dbName)
		// Check if copy of DB is there in Documents directory
		let fm = NSFileManager.defaultManager()
		if !(fm.fileExistsAtPath(path)) {
			// The database does not exist, so copy to Documents directory
			let from = NSBundle.mainBundle().resourcePath.stringByAppendingPathComponent(dbName)
			var error:NSError?
			if !fm.copyItemAtPath(from, toPath: path, error: &error) {
				println("SQLiteDB - failed to open DB!")
				println("Error - \(error!.localizedDescription)")
				return
			}
		}
		// Open the DB
		let cpath = path.bridgeToObjectiveC().cString()
		let error = sqlite3_open(cpath, &db)
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
		if db {
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
			var cSql:CString = sql.bridgeToObjectiveC().cString()
			var stmt:COpaquePointer = nil
			// Prepare
			result = sqlite3_prepare_v2(self.db, cSql, 0, &stmt, nil)
			if result != SQLITE_OK {
				sqlite3_finalize(stmt)
				let msg = "SQLiteDB - failed to prepare SQL: \(sql), Error: \(self.lastSQLError())"
				println(msg)
				self.alert(msg: msg)
				return
			}
			// Step
			result = sqlite3_step(stmt)
			if result != SQLITE_OK {
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
	func query(sql:String)->Dictionary<String, String>[] {
		var rows = Dictionary<String, String>[]()
		dispatch_sync(queue) {
			var cSql:CString = sql.bridgeToObjectiveC().cString()
			var stmt:COpaquePointer = nil
			var result:CInt = 0
			// Prepare statement
			result = sqlite3_prepare_v2(self.db, cSql, -1, &stmt, nil)
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
			var columnNames = String[]()
			var columnTypes = String[]()
			result = sqlite3_step(stmt)
			while result == SQLITE_ROW {
				// Should we get column info?
				if fetchColumnInfo {
					columnCount = sqlite3_column_count(stmt)
					for index in 0..columnCount {
						// Get column name
						let name = sqlite3_column_name(stmt, index)
						columnNames += String.fromCString(name)
						// Get column type
						columnTypes += self.getColumnType(index, stmt: stmt)
					}
					fetchColumnInfo = false
				}
				// Get row data for each column
				var row = Dictionary<String, String>()
				for index in 0..columnCount {
					let key = columnNames[Int(index)]
					row[key] = self.getColumnValue(index, stmt: stmt)
				}
				rows.append(row)
				// Next row
				result = sqlite3_step(stmt)
			}
			sqlite3_finalize(stmt)
		}
		return rows
	}
	
	// SQL escape string
	func esc(str: String)->String {
		var cstr:CString = str.bridgeToObjectiveC().cString()
//		var ptr:CMutablePointer<CString> = &cstr
//		cstr = sqlite3_vmprintf("%Q", CVaListPointer(fromUnsafePointer: ptr))
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
		var err:CString? = nil
		dispatch_sync(queue) {
			err = sqlite3_errmsg(self.db)
		}
		return (err ? NSString(CString:err!) : "")
	}
	
	// Show alert with either supplied message or last error
	func alert(msg:String? = nil) {
		var txt = msg ? msg! : lastSQLError()
		let alert = UIAlertView(title: "SQLiteDB", message: txt, delegate: nil, cancelButtonTitle: "OK")
		alert.show()
	}
	
	// Get column type
	func getColumnType(index:CInt, stmt:COpaquePointer)->String {
		var type = ""
		
		return type
	}
	
	// Get column value
	func getColumnValue(index:CInt, stmt:COpaquePointer)->String {
		var value = ""
		let buf:UnsafePointer<CUnsignedChar> = sqlite3_column_text(stmt, index)
		let cstr = CString(buf)
		value = String.fromCString(cstr)
		return value
	}
}

/*
-(id)columnValueAtIndex:(int)column withColumnType:(int)columnType inStatement:(sqlite3_stmt *)statement {
	if (columnType == SQLITE_INTEGER) {
		return @(sqlite3_column_int(statement, column));
	}
	if (columnType == SQLITE_FLOAT) {
		return [[NSDecimalNumber alloc] initWithDouble:sqlite3_column_double(statement, column)];
	}
	if (columnType == SQLITE_TEXT) {
		const char *text = (const char *)sqlite3_column_text(statement, column);
		if (text != NULL) {
			return @(text);
		}
	}
	if (columnType == SQLITE_BLOB) {
		return [NSData dataWithBytes:sqlite3_column_blob(statement, column) length:sqlite3_column_bytes(statement, column)];
	}
	if (columnType == SQLITE_DATE) {
		const char *text = (const char *)sqlite3_column_text(statement, column);
		if (text != NULL) {
			NSString *buf = @(text);
			NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"-:"];
			if ([buf rangeOfCharacterFromSet:set].location != NSNotFound) {
				time_t t;
				struct tm tm;
				strptime([buf cStringUsingEncoding:NSUTF8StringEncoding], "%Y-%m-%d %H:%M:%S", &tm);
				tm.tm_isdst = -1;
				t = mktime(&tm);
				return [NSDate dateWithTimeIntervalSince1970:t + [[NSTimeZone localTimeZone] secondsFromGMT]];
			}
		}
		return [[NSDecimalNumber alloc] initWithDouble:sqlite3_column_double(statement, column)];
	}
	return [NSNull null];
}


-(NSString *)esc:(NSString *)str {
	if (!str || [str length] == 0) {
		return @"";
	}
	return @(sqlite3_mprintf("%Q", [str cStringUsingEncoding:NSUTF8StringEncoding]));
}

-(NSArray *)query:(NSString *)sql {
	return [self query:sql asObject:[NSMutableDictionary class]];
}


-(SEL)selectorForSettingColumnName:(NSString *)column {
	return NSSelectorFromString([NSString stringWithFormat:@"set%@:", [NSString capitalizeFirstCharacterInString:column]]);
}

-(int)columnTypeAtIndex:(int)column inStatement:(sqlite3_stmt *)statement {
	// Declared data types - http://www.sqlite.org/datatype3.html (section 2.2 table column 1)
	const NSSet *blobTypes = [NSSet setWithObjects:@"BINARY", @"BLOB", @"VARBINARY", nil];
	const NSSet *charTypes = [NSSet setWithObjects:@"CHAR", @"CHARACTER", @"CLOB", @"NATIONAL VARYING CHARACTER", @"NATIVE CHARACTER", @"NCHAR", @"NVARCHAR", @"TEXT", @"VARCHAR", @"VARIANT", @"VARYING CHARACTER", nil];
	const NSSet *dateTypes = [NSSet setWithObjects:@"DATE", @"DATETIME", @"TIME", @"TIMESTAMP", nil];
	const NSSet *intTypes  = [NSSet setWithObjects:@"BIGINT", @"BIT", @"BOOL", @"BOOLEAN", @"INT", @"INT2", @"INT8", @"INTEGER", @"MEDIUMINT", @"SMALLINT", @"TINYINT", nil];
	const NSSet *nullTypes = [NSSet setWithObjects:@"NULL", nil];
	const NSSet *realTypes = [NSSet setWithObjects:@"DECIMAL", @"DOUBLE", @"DOUBLE PRECISION", @"FLOAT", @"NUMERIC", @"REAL", nil];
	// Determine data type of the column - http://www.sqlite.org/c3ref/c_blob.html
	const char *columnType = (const char *)sqlite3_column_decltype(statement, column);
	if (columnType != NULL) {
		NSString *dataType = [@(columnType) uppercaseString];
		NSRange end = [dataType rangeOfString:@"("];
		if (end.location != NSNotFound) {
			dataType = [dataType substringWithRange:NSMakeRange(0, end.location)];
		}
		if ([dataType hasPrefix:@"UNSIGNED"]) {
			dataType = [dataType substringWithRange:NSMakeRange(0, 8)];
		}
		dataType = [dataType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if ([intTypes containsObject:dataType]) {
			return SQLITE_INTEGER;
		}
		if ([realTypes containsObject:dataType]) {
			return SQLITE_FLOAT;
		}
		if ([charTypes containsObject:dataType]) {
			return SQLITE_TEXT;
		}
		if ([blobTypes containsObject:dataType]) {
			return SQLITE_BLOB;
		}
		if ([nullTypes containsObject:dataType]) {
			return SQLITE_NULL;
		}
		if ([dateTypes containsObject:dataType]) {
			return SQLITE_DATE;
		}
		return SQLITE_TEXT;
	}
	return sqlite3_column_type(statement, column);
}

*/
