SQLiteDB
========

This is a basic SQLite wrapper for Swift. It is very simple at the moment and does not provide any advanced functionality. Additionally, it's not pure Swift at the moment due to some difficulties in making all of the necessary sqlite C API calls from Swift.

**Important** If you are new to Swift or have not bothered to read up on the Swift documentation, please do not contact me about Swift functionality. I just don't have the time to answer your queries about Swift. Of course, if you're willing to pay for my time though, feel free to contact me :)

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

* You can make SQL queries using the `query` method (the results are returned as an array of `SQLRow` objects):
```swift
	let data = db.query("SELECT * FROM customers WHERE name='John'")
	let row = data[0]
	if let name = row["name"] {
		textLabel.text = name.string
	}
```
In the above, `db` is a reference to the shared SQLite database instance and `SQLRow` is a class defined to model a data row in SQLiteDB.

* You can execute all non-query SQL commands (INSERT, DELETE, UPDATE etc.) using the `execute` method:
```swift
	db.execute("DELETE * FROM customers WHERE last_name='Smith'")
```

* You can also create SQL statements with variable/dynamic values quite easily using Swift's string manipulation functionality. (And you do not need to use the SQLite bind API calls.)
```swift
	let name = "Smith"
	db.execute("DELETE * FROM customers WHERE last_name='\(name)'")
```

* If your variable values contain quotes, remember to use the `esc` method to quote and escape the special characters in your input data. Otherwise, you will get a runtime error when trying to execute your SQL statements. (Note that the `esc` method encloses your data in quotes - so you don't have to enclose the final value in quotes when building your SQL statement.)
```swift
	let db = SQLiteDB.sharedInstance()
	let name = db.esc("John's Name")
	let sql = "SELECT * FROM clients WHERE name=\(name)"
```

Questions?
---
* FAQ: [FAQs](https://github.com/FahimF/SQLiteDB/wiki/FAQs)
* Email: [fahimf@gmail.com](mailto:fahimf@gmail.com)
* Web: [http://rooksoft.sg/](http://rooksoft.sg/)
* Twitter: [http://twitter.com/FahimFarook](http://twitter.com/FahimFarook)

SQLiteDB is under DWYWPL - Do What You Will Public License :) Do whatever you want either personally or commercially with the code but if you'd like, feel free to attribute in your app.



