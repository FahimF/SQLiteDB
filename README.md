SQLiteDB
========

This is a basic SQLite wrapper for Swift. It is very simple at the moment and does not provide any advance functionality.

Usage
---
* You can gain access to the shared database instance as follows:
```swift
	let db = SQLiteDB.sharedInstance()
```

* You can make an SQL query like this (the results are returned as an array of Dictionary objects):
```swift
	let data = db.query("SELECT * FROM customers WHERE name='John'")
```
In the above, `db` is a reference to the shared SQLite database instance.

* You can execute an SQL command (INSERT, DELETE, UPDATE etc.) like this:
```swift
	db.execute("DELETE * FROM customers WHERE last_name='Smith'")
```

Questions?
---
* Email: [fahimf@gmail.com](mailto:fahimf@gmail.com)
* Web: [http://rooksoft.sg/](http://rooksoft.sg/)
* Twitter: [http://twitter.com/FahimFarook](http://twitter.com/FahimFarook)



