# SQLiteDB

SQLiteDB is a simple and lightweight SQLite wrapper for Swift. It allows all basic SQLite functionality including being able to bind values to parameters in an SQL statement. You can either include an SQLite database file with your project (in case you want to pre-load data) and have it be copied over automatically in to your documents folder, or have the necessary database and the relevant table structures created automatically for you via SQLiteDB.

SQLiteDB also provides an `SQLTable` class which allows you to use SQLiteDB as an ORM so that you can define your table structures via `SQLTable` sub-classes and be able to access the underlying data directly instead of having to deal with SQL queries, parameters, etc.

**Update: (28 Mar 2018)** The latest version of SQLiteDB changes the `openDB()` method to `open()`  and changes the parameters for the method as well. Please be aware of this change when updating an existing project. The `open` method parameters have default values which should work for most general cases - so you probably will not need to modify existing code except to change the method name.

The `row(number:filter:order:type:)` method now takes 0-based row numbers instead of 1-based. This change was made to be in line with how the row number is used in all the use cases I've seen up to now.

Also do not try to use the cloud database functionality available with the latest code since that is not yet ready for prime time - that code is still a work in progress. However, the rest of SQLiteDB code will function as it should without any issues. 

## Adding to Your Project

* If you want to pre-load data or have the table structures and indexes pre-created, or, if you are not using `SQLTable` sub-classes but are instead using `SQLiteDB` directly, then you need to create an SQLite database file to be included in your project.

  Create your SQLite database however you like, but name it `data.db` and then add the `data.db` file to your Xcode project. (If you want to name the database file something other than `data.db`, then set the `DB_NAME` property in the `SQLiteDB` class accordingly.)

    **Note:** Remember to add the database file above to your application target when you add it to the project. If you don't add the database file to a project target, it will not be copied to the device along with the other project resources.
  
  If you do not want to pre-load data and are using `SQLTable` sub-classes to access your tables, you can skip the above step since SQLiteDB will automatically create your table structures for you if the database file is not included in the project. However, in order for this to work, you need to pass `false` as the parameter for the `open` method when you invoke it, like this:
	
  	​```swift
  	db.open(copyFile: false)
  	​```
	
* Add all of the included source files (except for README.md, of course) to your project.

* If you don't have a bridging header file, use the included `Bridging-Header.h` file. If you already have a bridging header file, then copy the contents from the included `Bridging-Header.h` file to your own bridging header file.

* If you didn't have a bridging header file, make sure that you modify your project settings to point to the new bridging header file. This will be under  **Build Settings** for your target and will be named **Objective-C Bridging Header**.

* Add the SQLite library (libsqlite3.dylib or libsqlite3.tbd, depending on your Xcode version) to your project under **Build Phases** - **Link Binary With Libraries** section.

That's it. You're set!

## Usage

There are several ways you can use `SQLiteDB` in your project:

### Basic - Direct

You can use the `SQLiteBase` class to open one or more SQLite databases directly by passing the path to the database file to the `open` method like this:

```swift
let db = SQLiteBase()
_ = db.open(dbPath: path)
```

You can then use the `db` instance to query the database. You can have multiple instances of `SQLiteBase` be in existence at the same time and point to different databases without any issues.

### Basic - Singleton

You can use the `SQLiteDB` class, which is a singleton, to get a reference to one central database. Similar to the `SQLiteBase, instance above, you can then run queries (or execute statements) on the database using this reference.

Unlike with a `SQLiteBase` class instance, you cannot open multiple databases with `SQLiteDB` - it will only work with the database file specified via the `DB_NAME` property for the class.

* You can gain access to the shared database instance as follows:

```swift
let db = SQLiteDB.shared
```

* Before you make any SQL queries, or execute commands, you should open the SQLite database. In most cases, this needs to be done only once per application and so you can do it in your `AppDelegate`, for example:
	
```swift
db.open()
```

* You can make SQL queries using the `query` method (the results are returned as an array of dictionaries where the key is a `String` and the value is of type `Any`):

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

* Of course, you can also construct the above SQL query by using Swift's string interpolation functionality as well (without using the SQLite bind functionality):

```swift
let name = "John"
let data = db.query(sql:"SELECT * FROM customers WHERE name='\(name)'")
```

* You can execute all non-query SQL commands (INSERT, DELETE, UPDATE etc.) using the `execute` method:

```swift
let result = db.execute(sql:"DELETE FROM customers WHERE last_name='Smith'")
// If the result is 0 then the operation failed, for inserts the result gives the newly inserted record ID
```

**Note:** If you need to escape strings with embedded quotes, or other special strings which might not work with Swift string interpolation, you should use the SQLite parameter binding functionality as shown above.

### Using `SQLTable`

If you would prefer to model your database tables as classes and do any data access via class instances instead of using SQL statements, SQLiteDB also provides an `SQLTable` class which does most of the heavy lifting for you.

If you create a sub-class of `SQLTable`, define properties where the names match the column names in your SQLite table, then you can use the sub-class to save to/update the database without having to write all the necessary boilerplate code yourself.

Additionally, with this approach, you don't need to include an SQLite database project with your app (unless you need/want to). Each `SQLTable` instance in your app will infer the structure for the underlying tables based on your `SQLTable` sub-classes and automatically create the necessary tables for you, if they aren't present.

In fact, while you develop your app, if you add new properties to your `SQLTable` sub-class instance, the necessary underlying SQLite columns will be added automatically to the database the next time the code is run. Again, SQLiteDB does all the work for you.

For example, say that you have a `Categories` table with just two columns - `id` and `name`. Then, the `SQLTable` sub-class definition for the table would look something like this:

```swift
class Category:SQLTable {
	var id = -1
	var name = ""
}
```

It's as simple as that! You don't have to write any insert, update, or delete methods since `SQLTable` handles all of that for you behind the scenese :) And on top of that, if you were to later add another property to the `Category` class later, say some sort of a usage count called `count`, that column would be added to the underlying table when you next run your code.

**Note:** Do note that for a table named `Categories`, the class has to be named `Category` - the table name has to be plural, and the class name has to be singular. The table names are plural while the classes are singular. Again, if you let `SQLTable` create the table structure for you, then it would all be handled correctly for you automatically. But if you create the tables yourself, do make sure that the table names are correct.

The only additional thing you need to do when you use `SQLTable` sub-classes and want the table structures to be automatically created for you is that you have to specify that you don't want to create a copy of a database in your project resources when you invoke `open`. So you have to have your `open` call be something like this:

```swift
db.open(copyFile:false)
```

Once you do that, you can run any SQL queries or execute commands on the database without any issues. 

Here are some quick examples of how you use the `Category` class from the above example:

* Add a new `Category` item to the table:

```swift
let category = Category()
category.name = "My New Category"
_ = category.save()
```

The save method returns a non-zero value if the save was successful. In the case of a new record, the return value is the `id` of the newly inserted row. You can check the return value to see if the save was sucessful or not since a `0` value means that the save failed for some reason.

* Get a `Category` by `id`:

```swift
if let category = Category.rowBy(id: 10) {
	NSLog("Found category with ID = 10")
}
```

* Query the `Category` table:

```swift
let array = Category.rows(filter: "id > 10")
```

* Get a specific `Category` row (to display categories via a `UITableView`, for example) by row number. The row numbers start at 0, the same as `UITableView` row indexes:

```swift
if let category = row(number: 0) {
	NSLog("Got first un-ordered category row")
}
```

* Delete a `Category`:

```swift
if let category = Category.rowBy(id: 10) {
	category.delete()
	NSLog("Deleted category with ID = 10")
}
```

You can refer to the sample iOS and macOS projects for more examples of how to implement data access using `SQLTable`.

## Questions?

* FAQ: [FAQs](https://github.com/FahimF/SQLiteDB/wiki/FAQs)
* [![Get help on Codementor](https://cdn.codementor.io/badges/get_help_github.svg)](https://www.codementor.io/fahimfarook?utm_source=github&utm_medium=button&utm_term=fahimfarook&utm_campaign=github)
* Web: [http://rooksoft.sg/](http://rooksoft.sg/)
* Twitter: [http://twitter.com/FahimFarook](http://twitter.com/FahimFarook)

SQLiteDB is under DWYWPL - Do What You Will Public License :) Do whatever you want either personally or commercially with the code but if you'd like, feel free to attribute in your app.