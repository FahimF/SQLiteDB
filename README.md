SQLiteDB
========

This is a basic SQLite wrapper for Swift. It is very simple at the moment and does not provide any advance functionality.

Adding to Your Project
---
* Add SQLiteDB.swift to your project
* If you don't have a bridging header file, create one. (It's just a header file - but it's usually named Bridging-Header.h or &lt;projectname&gt;-Bridging-Header.h).
* If you added a bridging header file, then make sure that you modify your project settings to point to the bridging header file. This will be under the "Build Settings" for your target and will be named "Objective-C Bridging Header".
* Add the following imports to your bridging header file:
```objective-c
#import <sqlite3.h>
#import <time.h>
```
* Add the SQLite library (libsqlite3.0.dylib) to your project under the "Build Phases" - "Link Binary With Libraries" section.

That's it. You're set!

Usage
---
* You can gain access to the shared database instance as follows:
```swift
	let db = SQLiteDB.sharedInstance()
```

* You can make an SQL query like this (the results are returned as an array of SQLRow objects):
```swift
	let data = db.query("SELECT * FROM customers WHERE name='John'")
	let row = data[0]
	let name = row.valueForKey("name")	
```
In the above, `db` is a reference to the shared SQLite database instance and `SQLRow` is a class defined to model a data row in SQLiteDB.

* You can execute an SQL command (INSERT, DELETE, UPDATE etc.) like this:
```swift
	db.execute("DELETE * FROM customers WHERE last_name='Smith'")
```

Questions?
---
* Email: [fahimf@gmail.com](mailto:fahimf@gmail.com)
* Web: [http://rooksoft.sg/](http://rooksoft.sg/)
* Twitter: [http://twitter.com/FahimFarook](http://twitter.com/FahimFarook)



