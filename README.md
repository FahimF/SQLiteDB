SQLiteDB 
========

This is a simple and lightweight SQLite wrapper for Swift. It allows all basic SQLite functionality including being able to bind values to parameters in an SQL statement. The framework does require an initial SQLite databae to be included in your project - it does not create the database for you via code.

**Important:** If you are new to Swift or have not bothered to read up on the Swift documentation, please do not contact me about Swift functionality. I just don't have the time to answer your queries about Swift. Of course, if you're willing to pay for my time though, feel free to contact me :)

Adding to Your Project
---
* Create your SQLite database however you like, but name it `data.db` and then add the `data.db` file to your Xcode project. (If you want to name the database file something other than `data.db`, then change the `DB_NAME` constant in the `SQLiteDB` class accordingly.)

    **Note:** Remember to add the database file above to your application target when you add it to the project. If you don't add the database file to a project target, it will not be copied to the device along with the other project resources.
	
* Add all of the included source files (except for README.md, of course) to your project.

* If you don't have a bridging header file, use the included `Bridging-Header.h` file. If you already have a bridging header file, then copy the contents from the included `Bridging-Header.h` file to your own bridging header file.

* If you didn't have a bridging header file, make sure that you modify your project settings to point to the new bridging header file. This will be under  **Build Settings** for your target and will be named **Objective-C Bridging Header**.

* Add the SQLite library (libsqlite3.0.dylib) to your project under **Build Phases** - **Link Binary With Libraries** section.

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
		textLabel.text = name.asString()
	}
```
In the above, `db` is a reference to the shared SQLite database instance and `SQLRow` is a class defined to model a data row in SQLiteDB. You can access a column from your query results by subscripting the `SQLRow` instance based on the column name. That returns an `SQLColumn` instance from which you can retrieve the data as a native data type by using the `asString`, `asInt`, `asDouble`, `asData`, and `asDate` methods provided by `SQLColumn`.

* If you'd prefer to bind values to your query instead of creating the full SQL string, then you can execute the above SQL also like this:
```swift
	let name = "John"
	let data = db.query("SELECT * FROM customers WHERE name=?", parameters:[name])
```

* Of course, you can also construct the above SQL query by using Swift's string manipulation functionality as well (without using the SQLite bind functionality):
```swift
	let name = "John"
	let data = db.query("SELECT * FROM customers WHERE name='\(name)'", parameters:[name])
```

* You can execute all non-query SQL commands (INSERT, DELETE, UPDATE etc.) using the `execute` method:
```swift
	let result = db.execute("DELETE FROM customers WHERE last_name='Smith'")
	// If the result is 0 then the operation failed
```

* The `esc` method which was previously available in SQLiteDB is no longer there. So, for instance, if you need to escape strings with embedded quotes, you should use the SQLite parameter binding functionality as shown above.

Questions?
---
* FAQ: [FAQs](https://github.com/FahimF/SQLiteDB/wiki/FAQs)
* Email: [fahimf@gmail.com](mailto:fahimf@gmail.com)
* Web: [http://rooksoft.sg/](http://rooksoft.sg/)
* Twitter: [http://twitter.com/FahimFarook](http://twitter.com/FahimFarook)

SQLiteDB is under DWYWPL - Do What You Will Public License :) Do whatever you want either personally or commercially with the code but if you'd like, feel free to attribute in your app.



