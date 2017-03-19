# SQLiteDB 

This is a simple and lightweight SQLite wrapper for Swift. It allows all basic SQLite functionality including being able to bind values to parameters in an SQL statement. The framework does require an initial SQLite database to be included in your project - it does not create the database for you via code.

**Update: (29 Jun 2016)** The latest version of SQLiteDB has the `SQLTable` subclasses infer the underlying table name by adding an "s" to the end of the subclass name in lower-case - for example, an `SQLTable` subclass named `Category` will look for an underlying table named `categorys` in the  database. Please be aware of this change when using `SQLTable` subclasses. (See the included iOS sample project for an example of this.)

**Update: (6 Nov 2015)** The latest version of SQLiteDB will break existing code since the `SQLRow` and `SQLColumn` classes have been removed. Instead, there's a new `SQLTable` class which can be sub-classed to model your individual database tables. (See the included iOS sample project for details.)

**Important:** If you are new to Swift or have not bothered to read up on the Swift documentation, please do not contact me about Swift functionality. I just don't have the time to answer your queries about Swift. On the other hand, if you're not looking for free advice but are willing to pay for my time, do feel free to contact me :)

## Adding to Your Project

* Create your SQLite database however you like, but name it `data.db` and then add the `data.db` file to your Xcode project. (If you want to name the database file something other than `data.db`, then change the `DB_NAME` constant in the `SQLiteDB` class accordingly.)

    **Note:** Remember to add the database file above to your application target when you add it to the project. If you don't add the database file to a project target, it will not be copied to the device along with the other project resources.
	
* Add all of the included source files (except for README.md, of course) to your project.

* If you don't have a bridging header file, use the included `Bridging-Header.h` file. If you already have a bridging header file, then copy the contents from the included `Bridging-Header.h` file to your own bridging header file.

* If you didn't have a bridging header file, make sure that you modify your project settings to point to the new bridging header file. This will be under  **Build Settings** for your target and will be named **Objective-C Bridging Header**.

* Add the SQLite library (libsqlite3.0.dylib or libsqlite3.tbd) to your project under **Build Phases** - **Link Binary With Libraries** section.

That's it. You're set!

## Usage

There are two ways you can use `SQLiteDB` in your project:

### Basic

You can use the `SQLiteDB` class directly to get a reference to the database and then run queries (or execute statements) on the database directly.

* You can gain access to the shared database instance as follows:
```swift
	let db = SQLiteDB.shared
```

* You can make SQL queries using the `query` method (the results are returned as an array of dictionaries where the key is a `String` and the value is of type `AnyObject`):
```swift
	let data = db.query(sql:"SELECT * FROM customers WHERE name='John'")
	let row = data[0]
	if let name = row["name"] {
		textLabel.text = name as! String
	}
```
In the above, `db` is a reference to the shared SQLite database instance. You can access a column from your query results by subscripting a row of the returned results (the rows are dictionaries) based on the column name. That returns an optional `Any` value which you can cast to the relevant data type.

* If you'd prefer to bind values to your query instead of creating the full SQL statement, then you can execute the above SQL also like this:
```swift
	let name = "John"
	let data = db.query(sql:"SELECT * FROM customers WHERE name=?", parameters:[name])
```

* Of course, you can also construct the above SQL query by using Swift's string manipulation functionality as well (without using the SQLite bind functionality):
```swift
	let name = "John"
	let data = db.query(sql:"SELECT * FROM customers WHERE name='\(name)'")
```

* You can execute all non-query SQL commands (INSERT, DELETE, UPDATE etc.) using the `execute` method:
```swift
	let result = db.execute(sql:"DELETE FROM customers WHERE last_name='Smith'")
	// If the result is 0 then the operation failed, for inserts the result gives the newly inserted record ID
```

* The `esc` method which was previously available in SQLiteDB is no longer there. So, for instance, if you need to escape strings with embedded quotes, you should use the SQLite parameter binding functionality as shown above.

### Using `SQLTable`

If you would prefer to model your database tables as classes and do any data access via the classes, SQLiteDB also provides an `SQLTable` class which does most of the heavy lifting for you. 

If you create a sub-class of `SQLTable`, define properties where the names match the column names in your SQLite table, then you can use the sub-class to save to/update the database without having to write all the necessary boilerplate code yourself. 

For example, say that you have a `Categories` table with just two columns - `id` and `name`. Then, the SQLTable sub-class definition for the table would look something like this:

```swift
class Category:SQLTable {
	var id = -1
	var name = ""
}
```

It's as simple as that! You don't have to write any insert, update, or delete methods since `SQLTable` handles all of that for you behind the scenese :)

**Note:** Do note that for a table named `Categories`, the class has to be named `Category` - the table name has to be plural, and the class name has to be singular.

Here are some quick examples of how you use the above class:

* Add a new Category item to the table:

```swift
let category = Category()
category.name = "My New Category"
_ = category.save()
```

The save method returns a non-zero value if the save was successful. In the case of a new record, the return value is the `id` of the newly inserted row. You can check the return value to see if the save was sucessful or not since a 0 value means that the save failed for some reason.

* Get a Category by `id`:

```swift
if let category = Category.rowBy(id:10) as? Category {
	NSLog("Found category with ID = 10")
}
```

* Query the Categories table:

```swift
let array = Category.rows(filter:"id > 10") as! [Category]
```

* Get a specific category row (to display categories via a `UITableView`, for example):

```swift
if let category = row(number:1) as? Category {
	NSLog("Got first un-ordered category row")
}
```

* Delete a category:

```swift
if let category = Category.rowBy(id:10) as? Category {
	category.delete()
	NSLog("Deleted category with ID = 10")
}
```

You can refer to the sample iOS and macOS projects for more examples of how to implement data access using `SQLTable`.

## Questions?

* FAQ: [FAQs](https://github.com/FahimF/SQLiteDB/wiki/FAQs)
* Email: [fahimf@gmail.com](mailto:fahimf@gmail.com)
* Web: [http://rooksoft.sg/](http://rooksoft.sg/)
* Twitter: [http://twitter.com/FahimFarook](http://twitter.com/FahimFarook)

SQLiteDB is under DWYWPL - Do What You Will Public License :) Do whatever you want either personally or commercially with the code but if you'd like, feel free to attribute in your app.



