SQLiteDB
========

This is a basic SQLite wrapper for Swift. It is very simple at the moment and does not provide any advanced functionality. Additionally, it's not pure Swift at the moment due to some difficulties in making all of the necessary sqlite C API calls from Swift.

Adding to Your Project
---
* Create your SQLite database however you like, but name it `data.db` and then add the `data.db` file to your Xcode project. (If you want to name the database file something other than `data.db`, then change the `DB_NAME` constant in the `SQLiteDB` class accordingly.)
* Add all of the included source files (except for README.md, of course) to your project.
* If you don't have a bridging header file, use the included `Bridging-Header.h` file. If you already have a bridging header file, then copy the contents from the included `Bridging-Header.h` file in to your own bridging header file.
* If you didn't have a bridging header file, make sure that you modify your project settings to point to the new bridging header file. This will be under the "Build Settings" for your target and will be named "Objective-C Bridging Header".
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
	if let name = row.["name"] {
		textLabel.text = name.string
	}
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



