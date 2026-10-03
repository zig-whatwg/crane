This is the Third Edition of Indexed Database API. The [First
Edition](https://www.w3.org/TR/2015/REC-IndexedDB-20150108/), simply
titled \"Indexed Database API\", became a W3C Recommendation on 8
January 2015. The [Second
Edition](https://www.w3.org/TR/2018/REC-IndexedDB-2-20180130/), titled
\"Indexed Database API 2.0\", became a W3C Recommendation on 30 January
2018.

Indexed Database API 3.0 is intended to supersede Indexed Database API
2.0.

## 1. Introduction

User agents need to store large numbers of objects locally in order to
satisfy off-line data requirements of Web applications.
[\[WEBSTORAGE\]](#biblio-webstorage "Web Storage (Second Edition)")
is useful for storing pairs of keys and their corresponding values.
However, it does not provide in-order retrieval of keys, efficient
searching over values, or storage of duplicate values for a key.

This specification provides a concrete API to perform advanced key-value
data management that is at the heart of most sophisticated query
processors. It does so by using transactional databases to store keys
and their corresponding values (one or more per key), and providing a
means of traversing keys in a deterministic order. This is often
implemented through the use of persistent B-tree data structures that
are considered efficient for insertion and deletion as well as in-order
traversal of very large numbers of data records.

The following example uses the
API to access a `"library"` database. It has a `"books"` object store
that holds books records stored by their `"isbn"` property as the
primary key.

Book records have a `"title"` property. This example artificially
requires that book titles are unique. The code enforces this by creating
an index named `"by_title"` with the
[`unique`](#dom-idbindexparameters-unique) option set. This index is used to look up books by
title, and will prevent adding books with non-unique titles.

Book records also have an `"author"` property, which is not
[required] to be unique. The code creates another index
named `"by_author"` to allow look-ups by this property.

The code first opens a connection to the database. The
[`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded) event handler code creates the object store
and indexes, if needed. The
[`success`](#eventdef-idbrequest-success) event handler code saves the opened
connection for use in later examples.

```
const request = indexedDB.open("library");
let db;

request.onupgradeneeded = function() {
 // The database did not previously exist, so create object stores and indexes.
 const db = request.result;
 const store = db.createObjectStore("books", {keyPath: "isbn"});
 const titleIndex = store.createIndex("by_title", "title", {unique: true});
 const authorIndex = store.createIndex("by_author", "author");

 // Populate with initial data.
 store.put({title: "Quarry Memories", author: "Fred", isbn: 123456});
 store.put({title: "Water Buffaloes", author: "Fred", isbn: 234567});
 store.put({title: "Bedrock Nights", author: "Barney", isbn: 345678});
};

request.onsuccess = function() {
 db = request.result;
};
```

The following example populates the database using a transaction.

```
const tx = db.transaction("books", "readwrite");
const store = tx.objectStore("books");

store.put({title: "Quarry Memories", author: "Fred", isbn: 123456});
store.put({title: "Water Buffaloes", author: "Fred", isbn: 234567});
store.put({title: "Bedrock Nights", author: "Barney", isbn: 345678});

tx.oncomplete = function() {
 // All requests have succeeded and the transaction has committed.
};
```

The following example looks up a single book in the database by title
using an index.

```
const tx = db.transaction("books", "readonly");
const store = tx.objectStore("books");
const index = store.index("by_title");

const request = index.get("Bedrock Nights");
request.onsuccess = function() {
 const matching = request.result;
 if (matching !== undefined) {
 // A match was found.
 report(matching.isbn, matching.title, matching.author);
 } else {
 // No match was found.
 report(null);
 }
};
```

The following example looks up all books in the database by author using
an index and a cursor.

```
const tx = db.transaction("books", "readonly");
const store = tx.objectStore("books");
const index = store.index("by_author");

const request = index.openCursor(IDBKeyRange.only("Fred"));
request.onsuccess = function() {
 const cursor = request.result;
 if (cursor) {
 // Called for each matching record.
 report(cursor.value.isbn, cursor.value.title, cursor.value.author);
 cursor.continue();
 } else {
 // No more matching records.
 report(null);
 }
};
```

The following example shows one way to handle errors when a request
fails.

```
const tx = db.transaction("books", "readwrite");
const store = tx.objectStore("books");
const request = store.put({title: "Water Buffaloes", author: "Slate", isbn: 987654});
request.onerror = function(event) {
 // The uniqueness constraint of the "by_title" index failed.
 report(request.error);
 // Could call event.preventDefault() to prevent the transaction from aborting.
};
tx.onabort = function() {
 // Otherwise the transaction will automatically abort due the failed request.
 report(tx.error);
};
```

The database connection can be closed when it is no longer needed.

```
db.close();
```

In the future, the database might have grown to contain other object
stores and indexes. The following example shows one way to handle
migrating from an older version.

```
const request = indexedDB.open("library", 3); // Request version 3.
let db;

request.onupgradeneeded = function(event) {
 const db = request.result;
 if (event.oldVersion < 1) {
 // Version 1 is the first version of the database.
 const store = db.createObjectStore("books", {keyPath: "isbn"});
 const titleIndex = store.createIndex("by_title", "title", {unique: true});
 const authorIndex = store.createIndex("by_author", "author");
 }
 if (event.oldVersion < 2) {
 // Version 2 introduces a new index of books by year.
 const bookStore = request.transaction.objectStore("books");
 const yearIndex = bookStore.createIndex("by_year", "year");
 }
 if (event.oldVersion < 3) {
 // Version 3 introduces a new object store for magazines with two indexes.
 const magazines = db.createObjectStore("magazines");
 const publisherIndex = magazines.createIndex("by_publisher", "publisher");
 const frequencyIndex = magazines.createIndex("by_frequency", "frequency");
 }
};

request.onsuccess = function() {
 db = request.result; // db.version will be 3.
};
```

A single database can be used by
multiple clients (pages and workers) simultaneously --- transactions
ensure they don't clash while reading and writing. If a new client wants
to upgrade the database (via the
[`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded) event), it cannot do so until all other
clients close their connection to the current version of the database.

To avoid blocking a new client from upgrading, clients can listen for
the
[`versionchange`](#eventdef-idbdatabase-versionchange) event. This fires when another client is
wanting to upgrade the database. To allow this to continue, react to the
[`versionchange`](#eventdef-idbdatabase-versionchange) event by doing something that ultimately
closes this client's [connection](#connection) to the database.

One way of doing this is to reload the page:

```
db.onversionchange = function() {
 // First, save any unsaved data:
 saveUnsavedData().then(function() {
 // If the document isn't being actively used, it could be appropriate to reload
 // the page without the user's interaction.
 if (!document.hasFocus()) {
 location.reload();
 // Reloading will close the database, and also reload with the new JavaScript
 // and database definitions.
 } else {
 // If the document has focus, it can be too disruptive to reload the page.
 // Maybe ask the user to do it manually:
 displayMessage("Please reload this page for the latest version.");
 }
 });
};

function saveUnsavedData() {
 // How you do this depends on your app.
}

function displayMessage() {
 // Show a non-modal message to the user.
}
```

Another way is to call the
[connection](#connection)'s
[`close()`](#dom-idbdatabase-close) method. However, you need to make sure your app is
aware of this, as subsequent attempts to access the database will fail.

```
db.onversionchange = function() {
 saveUnsavedData().then(function() {
 db.close();
 stopUsingTheDatabase();
 });
};

function stopUsingTheDatabase() {
 // Put the app into a state where it no longer uses the database.
}
```

The new client (the one attempting the upgrade) can use the
[`blocked`](#eventdef-idbopendbrequest-blocked) event to detect if other clients are
preventing the upgrade from happening. The
[`blocked`](#eventdef-idbopendbrequest-blocked) event fires if other clients still hold a
connection to the database after their
[`versionchange`](#eventdef-idbdatabase-versionchange) events have fired.

```
const request = indexedDB.open("library", 4); // Request version 4.
let blockedTimeout;

request.onblocked = function() {
 // Give the other clients time to save data asynchronously.
 blockedTimeout = setTimeout(function() {
 displayMessage("Upgrade blocked - Please close other tabs displaying this site.");
 }, 1000);
};

request.onupgradeneeded = function(event) {
 clearTimeout(blockedTimeout);
 hideMessage();
 // ...
};

function hideMessage() {
 // Hide a previously displayed message.
}
```

The user will only see the above message if another client fails to
disconnect from the database. Ideally the user will never see this.

## 2. Constructs

A [name] is a
[string](https://infra.spec.whatwg.org/#string) equivalent to a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString); that is, an arbitrary sequence of 16-bit code units of
any length, including the empty string. [Names](#name) are always compared as opaque sequences of 16-bit code
units.

[NOTE:] As a result, [name](#name) comparison is sensitive to variations in case as well
as other minor variations such as normalization form, the inclusion or
omission of controls, and other variations in Unicode text.
[\[Charmod-Norm\]](#biblio-charmod-norm "Character Model for the World Wide Web: String Matching")

If an implementation uses a storage mechanism which does not support
arbitrary strings, the implementation can use an escaping mechanism or
something similar to map the provided name to a string that it can
store.

To [create a sorted name list] from a
[list](https://infra.spec.whatwg.org/#list) `names`, run these steps:

1. Let `sorted` be `names` [sorted in ascending
 order](https://infra.spec.whatwg.org/#list-sort-in-ascending-order) with the [code unit less
 than](https://infra.spec.whatwg.org/#code-unit-less-than) algorithm.

2. Return a new
 [`DOMStringList`](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#domstringlist) associated with `sorted`.

This matches the
[`sort()`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array.prototype.sort) method on an
[`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects) of
[`String`](https://tc39.es/ecma262/multipage/text-processing.html#sec-string-objects). This ordering compares the 16-bit code units in each
string, producing a highly efficient, consistent, and deterministic sort
order. The resulting list will not match any particular alphabet or
lexicographical order, particularly for code points represented by a
surrogate pair.

### 2.1. Database

Each [storage
key](https://storage.spec.whatwg.org/#storage-key) has an associated set of
[databases](#database). A
[database] has
zero or more [object stores](#object-store) which hold the data stored in the database.

A [database](#database) has a
[name] which identifies it within a specific
[storage
key](https://storage.spec.whatwg.org/#storage-key). The name is a [name](#name), and stays constant for the lifetime of the database.

A [database](#database) has a
[version]. When a database is first created, its
[version](#database-version)
is 0 (zero).

[NOTE:] Each [database](#database) has one version at a time; a
[database](#database) can't exist in
multiple versions at once. The only way to change the version is using
an [upgrade
transaction](#upgrade-transaction).

A [database](#database) has at most
one associated [upgrade transaction], which is
either null or an [upgrade
transaction](#upgrade-transaction), and is initially null.

#### 2.1.1. Database connection

Script does not interact with [databases](#database) directly. Instead, script has indirect access via a
[connection]. A
[connection](#connection) object
can be used to manipulate the objects of that
[database](#database). It is also
the only way to obtain a
[transaction](#transaction-concept) for that [database](#database).

The act of opening a [database](#database) creates a
[connection](#connection). There
may be multiple [connections](#connection) to a given [database](#database) at any given time.

A [connection](#connection) can
only access [databases](#database)
associated with the [storage
key](https://storage.spec.whatwg.org/#storage-key) of the global scope from which the
[connection](#connection) is
opened.

[NOTE:] This is not affected by changes to the
[`Document`](https://dom.spec.whatwg.org/#document)'s
[`domain`](https://html.spec.whatwg.org/multipage/browsers.html#dom-document-domain).

A [connection](#connection) has a
[version], which is set when the
[connection](#connection) is
created. It remains constant for the lifetime of the
[connection](#connection) unless
an [upgrade is
aborted](#abort-an-upgrade-transaction), in which case it is set to the previous version of the
[database](#database). Once the
[connection](#connection) is
closed the [version](#connection-version) does not change.

Each connection has a [close pending
flag] which is initially
false.

When a [connection](#connection)
is initially created it is in an opened state. The connection can be
[closed] through several means. If the execution
context where the [connection](#connection) was created is destroyed (for example due to the user
navigating away from that page), the connection is closed. The
connection can also be closed explicitly using the steps to [close a
database
connection](#close-a-database-connection). When the connection is closed its [close pending
flag](#connection-close-pending-flag) is always set to true if it hasn't already been.

A [connection](#connection) may
be closed by a user agent in exceptional circumstances, for example due
to loss of access to the file system, a permission change, or clearing
of the [storage
key](https://storage.spec.whatwg.org/#storage-key)'s storage. If this occurs the user agent must run
[close a database
connection](#close-a-database-connection) with the
[connection](#connection) and
with the `forced flag` set to true.

A [connection](#connection) has
an [object store set], which is initialized
to the set of [object stores](#object-store) in the associated
[database](#database) when the
[connection](#connection) is
created. The contents of the set will remain constant except when an
[upgrade
transaction](#upgrade-transaction) is [live](#transaction-live).

A [connection](#connection)'s
[get the
parent](https://dom.spec.whatwg.org/#get-the-parent) algorithm returns null.

An event with type [`versionchange`] will be fired at an open
[connection](#connection) if an
attempt is made to upgrade or delete the
[database](#database). This gives
the [connection](#connection) the
opportunity to close to allow the upgrade or delete to proceed.

An event with type [`close`]
will be fired at a [connection](#connection) if the connection is
[closed](#close-a-database-connection) abnormally.

### 2.2. Object store

An [object store] is the primary storage mechanism for storing data in a
[database](#database).

Each database has a set of [object
stores](#object-store). The set
of [object stores](#object-store) can be changed, but only using an [upgrade
transaction](#upgrade-transaction), i.e. in response to an
[`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded) event. When a new database is created it
doesn't contain any [object
stores](#object-store).

An [object store](#object-store)
has a [list of records] which hold the data
stored in the object store. Each [record] consists
of a [key](#key) and a
[value](#value). The list is sorted
according to key in [ascending](#greater-than) order. There can never be multiple records in a given
object store with the same key.

An [object store](#object-store)
has a [name], which is a [name](#name). At any one time, the name is unique within the
[database](#database) to which it
belongs.

An [object store](#object-store)
optionally has a [key path]. If the object store
has a key path it is said to use [in-line
keys]. Otherwise it is said
to use [out-of-line keys].

An [object store](#object-store)
optionally has a [key generator](#key-generator).

An object store can derive a [key](#key)
for a [record](#object-store-record) from one of three sources:

1. A [key generator](#key-generator). A key generator generates a monotonically
 increasing numbers every time a key is needed.

2. Keys can be derived via a [key
 path](#object-store-key-path).

3. Keys can also be explicitly specified when a
 [value](#value) is stored in the
 object store.

#### 2.2.1. Object store handle

Script does not interact with [object
stores](#object-store) directly.
Instead, within a
[transaction](#transaction-concept), script has indirect access via an [object store
handle].

An [object store
handle](#object-store-handle) has an associated [object
store] and an
associated [transaction].
Multiple handles may be associated with the same [object
store](#object-store) in
different
[transactions](#transaction-concept), but there must be only one [object store
handle](#object-store-handle) associated with a particular [object
store](#object-store) within a
[transaction](#transaction-concept).

An [object store
handle](#object-store-handle) has an [index set],
which is initialized to the set of
[indexes](#index-concept) that
reference the associated [object
store](#object-store-handle-object-store) when the [object store
handle](#object-store-handle) is created. The contents of the set will remain
constant except when an [upgrade
transaction](#upgrade-transaction) is [live](#transaction-live).

An [object store
handle](#object-store-handle) has a [name],
which is initialized to the
[name](#object-store-name)
of the associated [object
store](#object-store-handle-object-store) when the [object store
handle](#object-store-handle) is created. The name will remain constant except when
an [upgrade
transaction](#upgrade-transaction) is [live](#transaction-live).

### 2.3. Values

Each record is associated with a [value]. User agents must support any [serializable
object](https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects). This includes simple types such as
[`String`](https://tc39.es/ecma262/multipage/text-processing.html#sec-string-objects) primitive values and
[`Date`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-date-objects) objects as well as
[`Object`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-object-objects) and
[`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects) instances,
[`File`](https://w3c.github.io/FileAPI/#dfn-file) objects,
[`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob) objects,
[`ImageData`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagedata) objects, and so on. Record
[values](#value) are stored and
retrieved by value rather than by reference; later changes to a value
have no effect on the record stored in the database.

Record [values](#value) are
[Records](https://webidl.spec.whatwg.org/#idl-record) output by the
[StructuredSerializeForStorage](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeforstorage) operation.

### 2.4. Keys

In order to efficiently retrieve
[records](#object-store-record) stored in an indexed database, each
[record](#object-store-record) is organized according to its [key].

A [key](#key) has an associated
[type] which is one of: *number*, *date*, *string*, *binary*, or
*array*.

A [key](#key) also has an associated
[value], which will be either: an
[`unrestricted double`](https://webidl.spec.whatwg.org/#idl-unrestricted-double) if type is *number* or *date*, a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) if type is *string*, a [byte
sequence](https://infra.spec.whatwg.org/#byte-sequence) if type is *binary*, or a
[list](https://infra.spec.whatwg.org/#list) of other [keys](#key) if
type is *array*.

An ECMAScript
[\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification")
value can be converted to a [key](#key)
by following the steps to [convert a value to a
key](#convert-a-value-to-a-key).

[NOTE:] The following ECMAScript types are valid keys:

- [`Number`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-number-objects) primitive values, except NaN. This includes Infinity
 and -Infinity.

- [`Date`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-date-objects) objects, except where the \[\[DateValue\]\] internal
 slot is NaN.

- [`String`](https://tc39.es/ecma262/multipage/text-processing.html#sec-string-objects) primitive values.

- [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) objects (or views on buffers such as
 [`Uint8Array`](https://webidl.spec.whatwg.org/#idl-Uint8Array)).

- [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects) objects, where every item is defined, is itself a
 valid key, and does not directly or indirectly contain itself. This
 includes empty arrays. Arrays can contain other arrays.

Attempting to convert other ECMAScript values to a
[key](#key) will fail.

An [array key]
is a [key](#key) with
[type](#key-type) *array*. The
[subkeys] of an
[array key](#array-key) are the
[items](https://infra.spec.whatwg.org/#list-item) of the [array key](#array-key)'s [value](#key-value).

To [compare two keys] `a` and `b`, run these steps:

1. Let `ta` be the [type](#key-type) of `a`.

2. Let `tb` be the [type](#key-type) of `b`.

3. If `ta` does not equal `tb`, then run these
 steps:

 1. If `ta` is *array*, then return 1.

 2. If `tb` is *array*, then return -1.

 3. If `ta` is *binary*, then return 1.

 4. If `tb` is *binary*, then return -1.

 5. If `ta` is *string*, then return 1.

 6. If `tb` is *string*, then return -1.

 7. If `ta` is *date*, then return 1.

 8. [Assert](https://infra.spec.whatwg.org/#assert): `tb` is *date*.

 9. Return -1.

4. Let `va` be the [value](#key-value) of `a`.

5. Let `vb` be the [value](#key-value) of `b`.

6. Switch on `ta`:

 *number*\
 *date*

 : 1. If `va` is greater than `vb`, then
 return 1.

 2. If `va` is less than `vb`, then return
 -1.

 3. Return 0.

 *string*

 : 1. If `va` is [code unit less
 than](https://infra.spec.whatwg.org/#code-unit-less-than) `vb`, then return -1.

 2. If `vb` is [code unit less
 than](https://infra.spec.whatwg.org/#code-unit-less-than) `va`, then return 1.

 3. Return 0.

 *binary*

 : 1. If `va` is [byte less
 than](https://infra.spec.whatwg.org/#byte-less-than) `vb`, then return -1.

 2. If `vb` is [byte less
 than](https://infra.spec.whatwg.org/#byte-less-than) `va`, then return 1.

 3. Return 0.

 *array*

 : 1. Let `length` be the lesser of `va`'s
 [size](https://infra.spec.whatwg.org/#list-size) and `vb`'s
 [size](https://infra.spec.whatwg.org/#list-size).

 2. Let `i` be 0.

 3. While `i` is less than `length`, then:

 1. Let `c` be the result of recursively
 [comparing two
 keys](#compare-two-keys) with `va`\[`i`\]
 and `vb`\[`i`\].

 2. If `c` is not 0, return `c`.

 3. Increase `i` by 1.

 4. If `va`'s
 [size](https://infra.spec.whatwg.org/#list-size) is greater than `vb`'s
 [size](https://infra.spec.whatwg.org/#list-size), then return 1.

 5. If `va`'s
 [size](https://infra.spec.whatwg.org/#list-size) is less than `vb`'s
 [size](https://infra.spec.whatwg.org/#list-size), then return -1.

 6. Return 0.

The [key](#key) `a` is
[greater than] the [key](#key) `b` if the result of [comparing two
keys](#compare-two-keys)
with `a` and `b` is 1.

The [key](#key) `a` is [less
than] the
[key](#key) `b` if the result
of [comparing two keys](#compare-two-keys) with `a` and `b` is -1.

The [key](#key) `a` is [equal
to] the
[key](#key) `b` if the result
of [comparing two keys](#compare-two-keys) with `a` and `b` is 0.

[NOTE:] As a result of the above rules, negative infinity is
the lowest possible value for a [key](#key). *Number* keys are less than *date* keys. *Date* keys
are less than *string* keys. *String* keys are less than *binary* keys.
*Binary* keys are less than *array* keys. There is no highest possible
[key](#key) value. This is because an
array of any candidate highest [key](#key) followed by another [key](#key) is even higher.

[NOTE:] Members of *binary* keys are compared as unsigned
[byte](https://infra.spec.whatwg.org/#byte) values (in the range 0 to 255 inclusive) rather than
signed
[`byte`](https://webidl.spec.whatwg.org/#idl-byte) values (in the range -128 to 127 inclusive).

### 2.5. Key path

A [key path] is
a string or list of strings that defines how to extract a
[key](#key) from a
[value](#value). A [valid key
path] is
one of:

- An empty string.

- An [identifier], which is a string matching the
 [IdentifierName](https://tc39.github.io/ecma262/#prod-IdentifierName) production from the ECMAScript Language Specification
 [\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification").

- A string consisting of two or more
 [identifiers](#identifier)
 separated by periods (U+002E FULL STOP).

- A non-empty list containing only strings conforming to the above
 requirements.

[NOTE:] Spaces are not allowed within a key path.

[Key path](#key-path) values can only
be accessed from properties explicitly copied by
[StructuredSerializeForStorage](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeforstorage), as well as the following type-specific
properties:

Type

Properties

[`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob)

[`size`](https://w3c.github.io/FileAPI/#dfn-size),
[`type`](https://w3c.github.io/FileAPI/#dfn-type)

[`File`](https://w3c.github.io/FileAPI/#dfn-file)

[`name`](https://w3c.github.io/FileAPI/#dfn-name),
[`lastModified`](https://w3c.github.io/FileAPI/#dfn-lastModified)

[`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects)

`length`

[`String`](https://tc39.es/ecma262/multipage/text-processing.html#sec-string-objects)

`length`

### 2.6. Index

It is sometimes useful to retrieve
[records](#object-store-record) in an [object
store](#object-store) through
other means than their [key](#key). An
[index]
allows looking up
[records](#object-store-record) in an [object
store](#object-store) using
properties of the [values](#value) in
the [object stores](#object-store)
[records](#object-store-record).

An index is a specialized persistent key-value storage and has a
[referenced] [object
store](#object-store). The
index has a [list of records] which hold the data stored
in the index. The [records] in an index are
automatically populated whenever records in the
[referenced](#index-referenced) object store are inserted, updated or deleted. There
can be several [indexes](#index-concept) referencing the same [object
store](#object-store), in which
changes to the object store cause all such indexes to get updated.

The [values] in the index's
[records](#index-records) are
always values of [keys](#key) in the
index's [referenced](#index-referenced) object store. The [keys] are derived from the
referenced object store's [values](#value) using a [key path]. If a given
[record](#object-store-record) with key `X` in the object store referenced
by the index has the value `A`, and
[evaluating](#extract-a-key-from-a-value-using-a-key-path) the index's [key
path](#index-key-path) on
`A` yields the result `Y`, then the index will
contain a record with key `Y` and value `X`.

For example, if an index's
[referenced](#index-referenced) object store contains a record with the key `123` and
the value `{ name: "Alice", title: "CEO" }`, and the index's [key
path](#index-key-path) is
\"`name`\" then the index would contain a record with the key
\"`Alice`\" and the value `123`.

Records in an index are said to have a [referenced
value]. This is the value of the record in the
index's referenced object store which has a key equal to the index's
record's value. So in the example above, the record in the index whose
[key](#index-keys) is
`Y` and value is `X` has a [referenced
value](#index-referenced-value) of `A`.

In the preceding
example, the record in the index with key \"`Alice`\" and value `123`
would have a [referenced
value](#index-referenced-value) of `{ name: "Alice", title: "CEO" }`.

[NOTE:] Each record in an index references one and only one
record in the index's
[referenced](#index-referenced) object store. However there can be multiple records in
an index which reference the same record in the object store. And there
can also be no records in an index which reference a given record in an
object store.

The [records](#object-store-record) in an index are always sorted according to the
[record](#object-store-record)'s key. However unlike object stores, a given index can
contain multiple records with the same key. Such records are
additionally sorted according to the
[index](#index-concept)'s
[record](#object-store-record)'s value (meaning the key of the record in the
referenced [object store](#object-store)).

An [index](#index-concept) has
a [name], which is a [name](#name).
At any one time, the name is unique within index's
[referenced](#index-referenced) [object store](#object-store).

An [index](#index-concept) has
a [unique flag]. When true, the index enforces that no two
[records](#object-store-record) in the index has the same key. If a
[record](#object-store-record) in the index's referenced object store is attempted to
be inserted or modified such that evaluating the index's key path on the
records new value yields a result which already exists in the index,
then the attempted modification to the object store fails.

An [index](#index-concept) has
a [multiEntry flag]. This flag affects how the
index behaves when the result of evaluating the index's [key
path](#index-key-path) yields
an [array key](#array-key). If its
[multiEntry flag](#index-multientry-flag) is false, then a single
[record](#object-store-record) whose [key](#key) is an
[array key](#array-key) is added to
the index. If its [multiEntry
flag](#index-multientry-flag) is true, then one
[record](#object-store-record) is added to the index for each of the
[subkeys](#subkeys).

#### 2.6.1. Index handle

Script does not interact with
[indexes](#index-concept)
directly. Instead, within a
[transaction](#transaction-concept), script has indirect access via an [index
handle].

An [index handle](#index-handle)
has an associated [index] and an associated
[object store handle]. The
[transaction] of an [index
handle](#index-handle) is the
[transaction](#object-store-handle-transaction) of its associated [object store
handle](#object-store-handle). Multiple handles may be associated with the same
[index](#index-concept) in
different
[transactions](#transaction-concept), but there must be only one [index
handle](#index-handle)
associated with a particular
[index](#index-concept) within
a [transaction](#transaction-concept).

An [index handle](#index-handle)
has a [name], which is initialized to the
[name](#index-name) of the
associated [index](#index-handle-index) when the [index
handle](#index-handle) is
created. The name will remain constant except when an [upgrade
transaction](#upgrade-transaction) is [live](#transaction-live).

### 2.7. Transactions

A [transaction] is used to interact with the data in a
[database](#database). Whenever
data is read or written to the database it is done by using a
[transaction](#transaction-concept).

[Transactions](#transaction-concept) offer some protection from application and system
failures. A
[transaction](#transaction-concept) may be used to store multiple data records or to
conditionally modify certain data records. A
[transaction](#transaction-concept) represents an atomic and durable set of data access and
data mutation operations.

All transactions are created through a
[connection](#connection), which
is the transaction's [connection].

A [transaction](#transaction-concept) has a [scope] which is a
[set](https://infra.spec.whatwg.org/#ordered-set) of [object
stores](#object-store) that the
transaction may interact with.

[NOTE:] A
[transaction](#transaction-concept)'s
[scope](#transaction-scope)
remains fixed unless the
[transaction](#transaction-concept) is an [upgrade
transaction](#upgrade-transaction).

Two [transactions](#transaction-concept) have [overlapping scope] if any [object
store](#object-store) is in
both transactions\'
[scope](#transaction-scope).

A [transaction](#transaction-concept) has a [mode] that determines which
types of interactions can be performed upon that transaction. The
[mode](#transaction-mode) is
set when the transaction is created and remains fixed for the life of
the transaction. A
[transaction](#transaction-concept)'s [mode](#transaction-mode) is one of the following:

\"[`readonly`](#dom-idbtransactionmode-readonly)\"

: The transaction is only allowed to read data. No modifications can
 be done by this type of transaction. This has the advantage that
 several [read-only
 transactions](#transaction-read-only-transaction) can be
 [started](#transaction-start) at the same time even if their
 [scopes](#transaction-scope) are
 [overlapping](#transaction-overlap), i.e. if they are using the same object stores.
 This type of transaction can be created any time once a database has
 been opened.

\"[`readwrite`](#dom-idbtransactionmode-readwrite)\"

: The transaction is allowed to read, modify and delete data from
 existing object stores. However object stores and indexes can't be
 added or removed. Multiple
 \"[`readwrite`](#dom-idbtransactionmode-readwrite)\" transactions can't be
 [started](#transaction-start) at the same time if their
 [scopes](#transaction-scope) are
 [overlapping](#transaction-overlap) since that would mean that they can modify each
 other's data in the middle of the transaction. This type of
 transaction can be created any time once a database has been opened.

\"[`versionchange`](#dom-idbtransactionmode-versionchange)\"

: The transaction is allowed to read, modify and delete data from
 existing object stores, and can also create and remove object stores
 and indexes. It is the only type of transaction that can do so. This
 type of transaction can't be manually created, but instead is
 created automatically when an
 [`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded) event is fired.

A [transaction](#transaction-concept) has a [durability hint].
This is a hint to the user agent of whether to prioritize performance or
durability when committing the transaction. The [durability
hint](#transaction-durability-hint) is one of the following:

\"[`strict`](#dom-idbtransactiondurability-strict)\"

: The user agent may consider that the
 [transaction](#transaction-concept) has successfully
 [committed](#transaction-commit) only after verifying that all outstanding changes
 have been successfully written to a persistent storage medium.

\"[`relaxed`](#dom-idbtransactiondurability-relaxed)\"

: The user agent may consider that the
 [transaction](#transaction-concept) has successfully
 [committed](#transaction-commit) as soon as all outstanding changes have been
 written to the operating system, without subsequent verification.

\"[`default`](#dom-idbtransactiondurability-default)\"

: The user agent should use its default durability behavior for the
 [storage
 bucket](https://storage.spec.whatwg.org/#storage-bucket). This is the default for
 [transactions](#transaction-concept) if not otherwise specified.

[NOTE:] In a typical implementation,
\"[`strict`](#dom-idbtransactiondurability-strict)\" is a hint to the user agent to flush any operating
system I/O buffers before a
[`complete`](#eventdef-idbtransaction-complete) event is fired. While this provides greater
confidence that the changes will be persisted in case of subsequent
operating system crash or power loss, flushing buffers can take
significant time and consume battery life on portable devices.

Web applications are encouraged to use
\"[`relaxed`](#dom-idbtransactiondurability-relaxed)\" for ephemeral data such as caches or quickly changing
records, and
\"[`strict`](#dom-idbtransactiondurability-strict)\" in cases where reducing the risk of data loss
outweighs the impact to performance and power. Implementations are
encouraged to weigh the durability hint from applications against the
impact to users and devices.

A [transaction](#transaction-concept) optionally has a [cleanup event
loop] which is an [event
loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop).

A [transaction](#transaction-concept) has a [request list] of
pending [requests](#request) which
have been made against the transaction.

A [transaction](#transaction-concept) has a [error] which is set if the
[transaction](#transaction-concept) is
[aborted](#transaction-abort).

[NOTE:] Implementors need to keep in mind that the value
\"null\" is considered an error, as it is set from
[`abort()`](#dom-idbtransaction-abort)

A [transaction](#transaction-concept)'s [get the
parent](https://dom.spec.whatwg.org/#get-the-parent) algorithm returns the transaction's
[connection](#transaction-connection).

A [read-only transaction] is a
[transaction](#transaction-concept) with
[mode](#transaction-mode)
\"[`readonly`](#dom-idbtransactionmode-readonly)\".

A [read/write transaction] is a
[transaction](#transaction-concept) with
[mode](#transaction-mode)
\"[`readwrite`](#dom-idbtransactionmode-readwrite)\".

#### 2.7.1. Transaction lifecycle

A [transaction](#transaction-concept) has a [state], which is one of the
following:

[active]

: A transaction is in this state when it is first
 [created](#transaction-created), and during dispatch of an event from a
 [request](#request) associated
 with the transaction.

 New [requests](#request) can be
 made against the transaction when it is in this state.

[inactive]

: A transaction is in this state after control returns to the event
 loop after its creation, and when events are not being dispatched.

 No [requests](#request) can be
 made against the transaction when it is in this state.

[committing]

: Once all [requests](#request)
 associated with a transaction have completed, the transaction will
 enter this state as it attempts to
 [commit](#transaction-commit).

 No [requests](#request) can be
 made against the transaction when it is in this state.

[finished]

: Once a transaction has committed or aborted, it enters this state.

 No [requests](#request) can be
 made against the transaction when it is in this state.

Transactions are expected to be short lived. This is encouraged by the
[automatic committing](#transaction-commit) functionality described below.

[NOTE:] Authors can still cause transactions to stay
[alive](#transaction-live)
for a long time; however, this usage pattern is not advised as it can
lead to a poor user experience.

The [lifetime] of a
[transaction](#transaction-concept) is as follows:

1. A transaction is [created] with a
 [scope](#transaction-scope) and a
 [mode](#transaction-mode). When a transaction is created its
 [state](#transaction-state) is initially
 [active](#transaction-active).

2. When an implementation is able to enforce the constraints for the
 transaction's
 [scope](#transaction-scope) and
 [mode](#transaction-mode), defined [below](#transaction-scheduling), the
 implementation must [queue a database
 task](#queue-a-database-task) to [start]
 the transaction asynchronously.

 Once the transaction has been
 [started](#transaction-start) the implementation can begin executing the
 [requests](#request) placed
 against the transaction. Requests must be executed in the order in
 which they were made against the transaction. Likewise, their
 results must be returned in the order the requests were placed
 against a specific transaction. There is no guarantee about the
 order that results from requests in different transactions are
 returned.

 [NOTE:] Transaction
 [modes](#transaction-mode) ensure that two requests placed against different
 transactions can execute in any order without affecting what
 resulting data is stored in the database.

3. When each [request](#request)
 associated with a transaction is
 [processed](#request-processed), a
 [`success`](#eventdef-idbrequest-success) or
 [`error`](#eventdef-idbrequest-error)
 [event](https://dom.spec.whatwg.org/#concept-event) will be fired. While the event is being
 [dispatched](https://dom.spec.whatwg.org/#concept-event-dispatch), the transaction
 [state](#transaction-state) is set to
 [active](#transaction-active), allowing additional requests to be made against
 the transaction. Once the event dispatch is complete, the
 transaction's
 [state](#transaction-state) is set to
 [inactive](#transaction-inactive) again.

4. A transaction can be [aborted] at any time before it is
 [finished](#transaction-finished), even if the transaction isn't currently
 [active](#transaction-active) or hasn't yet
 [started](#transaction-start).

 An explicit call to
 [`abort()`](#dom-idbtransaction-abort) will initiate an
 [abort](#transaction-abort). An abort will also be initiated following a failed
 request that is not handled by script.

 When a transaction is aborted the implementation must undo (roll
 back) any changes that were made to the
 [database](#database) during
 that transaction. This includes both changes to the contents of
 [object stores](#object-store) as well as additions and removals of [object
 stores](#object-store) and
 [indexes](#index-concept).

5. The implementation must attempt to [commit] an
 [inactive](#transaction-inactive) transaction when all
 [requests](#request) placed
 against the transaction have completed and their returned results
 handled, no new requests have been placed against the transaction,
 and the transaction has not been
 [aborted](#transaction-abort)

 An explicit call to
 [`commit()`](#dom-idbtransaction-commit) will initiate a
 [commit](#transaction-commit) without waiting for request results to be handled
 by script.

 When committing, the transaction
 [state](#transaction-state) is set to
 [committing](#transaction-committing). The implementation must atomically write any
 changes to the [database](#database) made by requests placed against the transaction.
 That is, either all of the changes must be written, or if an error
 occurs, such as a disk write error, the implementation must not
 write any of the changes to the database, and the steps to [abort a
 transaction](#abort-a-transaction) will be followed.

6. When a transaction is
 [committed](#transaction-commit) or
 [aborted](#transaction-abort), its
 [state](#transaction-state) is set to
 [finished](#transaction-finished).

The implementation must allow [requests](#request) to be [placed](#request-placed) against the transaction whenever it is
[active](#transaction-active). This is the case even if the transaction has not yet
been [started](#transaction-start). Until the transaction is
[started](#transaction-start) the implementation must not execute these requests;
however, the implementation must keep track of the
[requests](#request) and their
order.

A [transaction](#transaction-concept) is said to be [live] from when
it is [created](#transaction-created) until its
[state](#transaction-state)
is set to
[finished](#transaction-finished).

To [cleanup Indexed Database
transactions], run the following
steps. They will return true if any transactions were cleaned up, or
false otherwise.

1. If there are no
 [transactions](#transaction-concept) with [cleanup event
 loop](#transaction-cleanup-event-loop) matching the current [event
 loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop), return false.

2. For each
 [transaction](#transaction-concept) `transaction` with [cleanup event
 loop](#transaction-cleanup-event-loop) matching the current [event
 loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop):

 1. Set `transaction`'s
 [state](#transaction-state) to
 [inactive](#transaction-inactive).

 2. Clear `transaction`'s [cleanup event
 loop](#transaction-cleanup-event-loop).

3. Return true.

[NOTE:] These steps are invoked by
[\[HTML\]](#biblio-html "HTML Standard"). They
ensure that
[transactions](#transaction-concept) created by a script call to
[`transaction()`](#dom-idbdatabase-transaction) are deactivated once the task that invoked the script
has completed. The steps are run at most once for each
[transaction](#transaction-concept).

An event with type [`complete`] is fired at a
[transaction](#transaction-concept) that has successfully
[committed](#transaction-commit).

An event with type [`abort`] is fired at a
[transaction](#transaction-concept) that has
[aborted](#transaction-abort).

#### 2.7.2. Transaction scheduling

The following constraints define when a
[transaction](#transaction-concept) can be
[started](#transaction-start):

- A [read-only
 transactions](#transaction-read-only-transaction) `tx` can
 [start](#transaction-start) when there are no [read/write
 transactions](#transaction-read-write-transaction) which:

 - Were [created](#transaction-created) before `tx`; and

 - have [overlapping
 scopes](#transaction-overlap) with `tx`; and

 - are not
 [finished](#transaction-finished).

- A [read/write
 transaction](#transaction-read-write-transaction) `tx` can
 [start](#transaction-start) when there are no
 [transactions](#transaction-concept) which:

 - Were [created](#transaction-created) before `tx`; and

 - have [overlapping
 scopes](#transaction-overlap) with `tx`; and

 - are not
 [finished](#transaction-finished).

Implementations may impose additional constraints. For example,
implementations are not required to
[start](#transaction-start)
non-[overlapping](#transaction-overlap) [read/write
transactions](#transaction-read-write-transaction) in parallel, or may impose limits on the number of
[started](#transaction-start) transactions.

[NOTE:] These constraints imply the following:

- Any number of [read-only
 transactions](#transaction-read-only-transaction) are allowed to be
 [started](#transaction-start) concurrently, even if they have [overlapping
 scopes](#transaction-overlap).

- As long as a [read-only
 transaction](#transaction-read-only-transaction) is
 [live](#transaction-live),
 the data that the implementation returns through
 [requests](#request) created with
 that transaction remains constant. That is, two requests to read the
 same piece of data yield the same result both for the case when data
 is found and the result is that data, and for the case when data is
 not found and a lack of data is indicated.

- A [read/write
 transaction](#transaction-read-write-transaction) is only affected by changes to [object
 stores](#object-store) that
 are made using the transaction itself. The implementation ensures that
 another transaction does not modify the contents of [object
 stores](#object-store) in the
 [read/write
 transaction](#transaction-read-write-transaction)'s
 [scope](#transaction-scope). The implementation also ensures that if the
 [read/write
 transaction](#transaction-read-write-transaction) completes successfully, the changes written to
 [object stores](#object-store) using the transaction can be committed to the
 [database](#database) without
 merge conflicts.

- If multiple [read/write
 transactions](#transaction-read-write-transaction) are attempting to access the same object store (i.e.
 if they have [overlapping
 scopes](#transaction-overlap)), the transaction that was
 [created](#transaction-created) first is the transaction which gets access to the
 object store first, and it is the only transaction which has access to
 the object store until the transaction is
 [finished](#transaction-finished).

- Any transaction
 [created](#transaction-created) after a [read/write
 transaction](#transaction-read-write-transaction) sees the changes written by the [read/write
 transaction](#transaction-read-write-transaction). For example, if a [read/write
 transaction](#transaction-read-write-transaction) A, is created, and later another transaction B, is
 created, and the two transactions have [overlapping
 scopes](#transaction-overlap), then transaction B sees any changes made to any
 [object stores](#object-store) that are part of that [overlapping
 scope](#transaction-overlap). This also means that transaction B does not have
 access to any [object stores](#object-store) in that overlapping
 [scope](#transaction-scope) until transaction A is
 [finished](#transaction-finished).

#### 2.7.3. Upgrade transactions

An [upgrade transaction] is a
[transaction](#transaction-concept) with
[mode](#transaction-mode)
\"[`versionchange`](#dom-idbtransactionmode-versionchange)\".

An [upgrade
transaction](#upgrade-transaction) is automatically created when running the steps to
[upgrade a database](#upgrade-a-database) after a [connection](#connection) is opened to a
[database](#database), if a
[version](#database-version)
greater than the current
[version](#database-version)
is specified. This
[transaction](#transaction-concept) will be active inside the
[`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded) event handler.

[NOTE:] An [upgrade
transaction](#upgrade-transaction) enables the creation, renaming, and deletion of [object
stores](#object-store) and
[indexes](#index-concept) in a
[database](#database).

An [upgrade
transaction](#upgrade-transaction) is exclusive. The steps to [open a database
connection](#open-a-database-connection) ensure that only one
[connection](#connection) to the
database is open when an [upgrade
transaction](#upgrade-transaction) is [live](#transaction-live). The
[`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded) event isn't fired, and thus the [upgrade
transaction](#upgrade-transaction) isn't started, until all other
[connections](#connection) to the
same [database](#database) are
closed. This ensures that all previous transactions are
[finished](#transaction-finished).

As long as an [upgrade
transaction](#upgrade-transaction) is [live](#transaction-live), attempts to open more
[connections](#connection) to the
same [database](#database) are
delayed, and any attempts to use the same
[connection](#connection) to
start additional transactions by calling
[`transaction()`](#dom-idbdatabase-transaction) will throw an exception. This ensures that no other
transactions are [live](#transaction-live) concurrently, and also ensures that no new transactions
are queued against the same [database](#database) as long as the [upgrade
transaction](#upgrade-transaction) is [live](#transaction-live).

This further ensures that once an [upgrade
transaction](#upgrade-transaction) is complete, the set of [object
stores](#object-store) and
[indexes](#index-concept) in a
[database](#database) remain
constant for the lifetime of all subsequent
[connections](#connection) and
[transactions](#transaction-concept).

### 2.8. Requests

Each asynchronous operation on a
[database](#database) is done using
a [request].
Every request represents one operation.

A [request](#request) has a
[processed flag] which is initially false.
This flag is set to true when the operation associated with the request
has been executed.

A [request](#request) is said to be
[processed] when its [processed
flag](#request-processed-flag) is true.

A [request](#request) has a [done
flag] which is initially false. This flag is set
to true when the result of the operation associated with the request is
available.

A [request](#request) has a
[source] object.

A [request](#request) has a
[result] and an [error], neither of
which are accessible until its [done
flag](#request-done-flag) is
true.

A [request](#request) has a
[transaction] which is initially null. This will be set
when a request is [placed] against a
[transaction](#transaction-concept) using the steps to [asynchronously execute a
request](#asynchronously-execute-a-request).

When a request is made, a new [request](#request) is returned with its [done
flag](#request-done-flag)
set to false. If a request completes successfully, its [done
flag](#request-done-flag)
is set to true, its [result](#request-result) is set to the result of the request, and an event with
type [`success`] is fired at
the [request](#request).

If an error occurs while performing the operation, the request's [done
flag](#request-done-flag)
is set to true, the request's
[error](#request-error) is set
to the error, and an event with type
[`error`] is fired at the
request.

A [request](#request)'s [get the
parent](https://dom.spec.whatwg.org/#get-the-parent) algorithm returns the request's
[transaction](#request-transaction).

[NOTE:] Requests are not typically re-used, but there are
exceptions. When a [cursor](#cursor) is
iterated, the success of the iteration is reported on the same
[request](#request) object used to
open the cursor. And when an [upgrade
transaction](#upgrade-transaction) is necessary, the same [open
request](#request-open-request) is used for both the
[`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded) event and final result of the open
operation itself. In some cases, the request's [done
flag](#request-done-flag)
will be set to false, then set to true again, and the
[result](#request-result) can
change or [error](#request-error) could be set instead.

#### 2.8.1. Open requests

An [open request] is a special type of
[request](#request) used when
opening a [connection](#connection) or deleting a [database](#database). In addition to
[`success`](#eventdef-idbrequest-success) and
[`error`](#eventdef-idbrequest-error) events,
[`blocked`] and
[`upgradeneeded`] events may be fired at an [open
request](#request-open-request) to indicate progress.

The [source](#request-source)
of an [open
request](#request-open-request) is always null.

The [transaction](#request-transaction) of an [open
request](#request-open-request) is null unless an
[`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded) event has been fired.

An [open request](#request-open-request)'s [get the
parent](https://dom.spec.whatwg.org/#get-the-parent) algorithm returns null.

#### 2.8.2. Connection queues

[Open requests](#request-open-request) are processed in a [connection queue]. The queue contains all
[open requests](#request-open-request) associated with an [storage
key](https://storage.spec.whatwg.org/#storage-key) and a [name](#database-name). Requests added to the [connection
queue](#connection-queue)
processed in order and each request must run to completion before the
next request is processed. An open request may be blocked on other
[connections](#connection),
requiring those connections to
[close](#connection-closed)
before the request can complete and allow further requests to be
processed.

[NOTE:] A [connection
queue](#connection-queue) is
not a [task
queue](https://html.spec.whatwg.org/multipage/webappapis.html#task-queue) associated with an [event
loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop), as the requests are processed outside any specific
[browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#browsing-context). The delivery of events to completed [open
request](#request-open-request) still goes through a [task
queue](https://html.spec.whatwg.org/multipage/webappapis.html#task-queue) associated with the [event
loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop) of the context where the request was made.

### 2.9. Key range

Records can be retrieved from [object
stores](#object-store) and
[indexes](#index-concept)
using either [keys](#key) or [key
ranges](#key-range). A [key
range] is a
continuous interval over some data type used for keys.

A [key range](#key-range) has an
associated [lower bound] (null or a
[key](#key)).

A [key range](#key-range) has an
associated [upper bound] (null or a
[key](#key)).

A [key range](#key-range) has an
associated [lower open flag]. Unless
otherwise stated it is false.

A [key range](#key-range) has an
associated [upper open flag]. Unless
otherwise stated it is false.

A [key range](#key-range) may have
a [lower bound](#key-range-lower-bound) [equal to](#equal-to) its [upper
bound](#key-range-upper-bound). A [key range](#key-range) must not have a [lower
bound](#key-range-lower-bound) [greater than](#greater-than) its [upper
bound](#key-range-upper-bound).

A [key range](#key-range)
[containing only] `key` has both [lower
bound](#key-range-lower-bound) and [upper
bound](#key-range-upper-bound) equal to `key`.

A `key` is [in a key range] `range` if both of the
following conditions are fulfilled:

- The `range`'s [lower
 bound](#key-range-lower-bound) is null, or it is [less
 than](#less-than)
 `key`, or it is both [equal
 to](#equal-to) `key`
 and the `range`'s [lower open
 flag](#key-range-lower-open-flag) is false.

- The `range`'s [upper
 bound](#key-range-upper-bound) is null, or it is [greater
 than](#greater-than)
 `key`, or it is both [equal
 to](#equal-to) `key`
 and the `range`'s [upper open
 flag](#key-range-upper-open-flag) is false.

[NOTE:]

- If a [key range](#key-range)'s
 [lower open
 flag](#key-range-lower-open-flag) is false, the [lower
 bound](#key-range-lower-bound) [key](#key) of the
 [key range](#key-range) is
 included in the range itself.

- If a [key range](#key-range)'s
 [lower open
 flag](#key-range-lower-open-flag) is true, the [lower
 bound](#key-range-lower-bound) [key](#key) of the
 [key range](#key-range) is
 excluded from the range itself.

- If a [key range](#key-range)'s
 [upper open
 flag](#key-range-upper-open-flag) is false, the [upper
 bound](#key-range-upper-bound) [key](#key) of the
 [key range](#key-range) is
 included in the range itself.

- If a [key range](#key-range)'s
 [upper open
 flag](#key-range-upper-open-flag) is true, the [upper
 bound](#key-range-upper-bound) [key](#key) of the
 [key range](#key-range) is
 excluded from the range itself.

An [unbounded key range] is a [key
range](#key-range) that has both
[lower bound](#key-range-lower-bound) and [upper
bound](#key-range-upper-bound) equal to null. All [keys](#key) are [in](#in) an
[unbounded key range](#unbounded-key-range).

To [convert a value to a key range] with `value` and
optional `null disallowed flag`, run these steps:

1. If `value` is a [key
 range](#key-range), return
 `value`.

2. If `value` is undefined or is null, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if `null disallowed flag` is true, or
 return an [unbounded key
 range](#unbounded-key-range) otherwise.

3. Let `key` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `value`. Rethrow any exceptions.

4. If `key` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Return a [key range](#key-range) [containing
 only](#containing-only)
 `key`.

A [potentially valid key range] is an ECMAScript value that has
a type that is convertible to a [key
range](#key-range). Whether the
specific value will successfully convert to a [key
range](#key-range), i.e.
[converting a value to a key
range](#convert-a-value-to-a-key-range) with it throws an exception, is not relevant.

[NOTE:] For example, a [detached
BufferSource](https://webidl.spec.whatwg.org/#buffersource-detached) is a [potentially valid key
range](#potentially-valid-key-range) that will throw an exception when used with [convert a
value to a key
range](#convert-a-value-to-a-key-range).

To determine when a value [is a potentially valid key
range] with ECMAScript `value`, run
these steps:

1. If `value` is a [key
 range](#key-range), return
 true.

2. Let `key` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `value`.

3. If `key` is \"invalid type\" return false.

4. Else return true.

[NOTE:] The
[`getAll()`](#dom-idbobjectstore-getall) and
[`getAllKeys()`](#dom-idbobjectstore-getallkeys) methods use [is a potentially valid key
range](#is-a-potentially-valid-key-range) to handle their first argument. If the argument is a
[potentially valid key
range](#potentially-valid-key-range),
[`getAll()`](#dom-idbobjectstore-getall) and
[`getAllKeys()`](#dom-idbobjectstore-getallkeys) run [convert a value to a key
range](#convert-a-value-to-a-key-range) with the argument. Otherwise,
[`IDBGetAllOptions`](#dictdef-idbgetalloptions) is used for the first argument.

[`getAll()`](#dom-idbobjectstore-getall) and
[`getAllKeys()`](#dom-idbobjectstore-getallkeys) throw exceptions for
[`Date`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-date-objects),
[`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects), and
[`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) first arguments that return \"invalid value\" when used
with [convert a value to a
key](#convert-a-value-to-a-key). For example, running
[`getAll()`](#dom-idbobjectstore-getall) with a NaN
[`Date`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-date-objects) first argument throws an exception instead of
successfully using an
[`IDBGetAllOptions`](#dictdef-idbgetalloptions) dictionary with default values.

### 2.10. Cursor

A [cursor] is used
to iterate over a range of records in an
[index](#index-concept) or an
[object store](#object-store)
in a specific direction.

A [cursor](#cursor) has a [source
handle], which is the [index
handle](#index-handle) or the
[object store
handle](#object-store-handle) that opened the cursor.

A [cursor](#cursor) has a
[transaction], which is the
[transaction](#transaction-concept) from the cursor's [source
handle](#cursor-source-handle).

A [cursor](#cursor) has a
[range] of records in either an
[index](#index-concept) or an
[object store](#object-store).

A [cursor](#cursor) has a
[source], which is an
[index](#index-concept) or an
[object store](#object-store)
from the cursor's [source
handle](#cursor-source-handle). The cursor's
[source](#cursor-source)
indicates which [index](#index-concept) or [object
store](#object-store) is
associated with the records over which the
[cursor](#cursor) is iterating. If the
cursor's [source
handle](#cursor-source-handle) is an [index
handle](#index-handle), then the
cursor's [source](#cursor-source) is [the index handle's associated
index](#index-handle-index). Otherwise, cursor's
[source](#cursor-source) is
[the object store handle's associated object
store](#object-store-handle-object-store).

A [cursor](#cursor) has a
[direction] that determines whether it moves in
monotonically increasing or decreasing order of the
[record](#object-store-record) keys when iterated, and if it skips duplicated values
when iterating indexes. The direction of a cursor also determines if the
cursor initial position is at the start of its
[source](#cursor-source) or at
its end. A cursor's
[direction](#cursor-direction) is one of the following:

\"[`next`](#dom-idbcursordirection-next)\"

: This direction causes the cursor to be opened at the start of the
 [source](#cursor-source).
 When iterated, the [cursor](#cursor) should yield all records, including duplicates, in
 monotonically increasing order of keys.

\"[`nextunique`](#dom-idbcursordirection-nextunique)\"

: This direction causes the cursor to be opened at the start of the
 [source](#cursor-source).
 When iterated, the [cursor](#cursor) should not yield records with the same key, but
 otherwise yield all records, in monotonically increasing order of
 keys. For every key with duplicate values, only the first record is
 yielded. When the [source](#cursor-source) is an [object
 store](#object-store) or an
 [index](#index-concept)
 with its [unique
 flag](#index-unique-flag) set to true, this direction has exactly the same
 behavior as
 \"[`next`](#dom-idbcursordirection-next)\".

\"[`prev`](#dom-idbcursordirection-prev)\"

: This direction causes the cursor to be opened at the end of the
 [source](#cursor-source).
 When iterated, the [cursor](#cursor) should yield all records, including duplicates, in
 monotonically decreasing order of keys.

\"[`prevunique`](#dom-idbcursordirection-prevunique)\"

: This direction causes the cursor to be opened at the end of the
 [source](#cursor-source).
 When iterated, the [cursor](#cursor) should not yield records with the same key, but
 otherwise yield all records, in monotonically decreasing order of
 keys. For every key with duplicate values, only the first record is
 yielded. When the [source](#cursor-source) is an [object
 store](#object-store) or an
 [index](#index-concept)
 with its [unique
 flag](#index-unique-flag) set to true, this direction has exactly the same
 behavior as
 \"[`prev`](#dom-idbcursordirection-prev)\".

A [cursor](#cursor) has a
[position] within its range. It is possible for the
list of records which the cursor is iterating over to change before the
full [range](#cursor-range) of
the cursor has been iterated. In order to handle this, cursors maintain
their [position](#cursor-position) not as an index, but rather as a
[key](#key) of the previously returned
record. For a forward iterating cursor, the next time the cursor is
asked to iterate to the next record it returns the record with the
lowest [key](#key) [greater
than](#greater-than) the one
previously returned. For a backwards iterating cursor, the situation is
opposite and it returns the record with the highest
[key](#key) [less
than](#less-than) the one
previously returned.

For cursors iterating indexes the situation is a little bit more
complicated since multiple records can have the same key and are
therefore also sorted by [value](#value). When iterating indexes the
[cursor](#cursor) also has an [object
store position], which indicates the
[value](#value) of the previously found
[record](#object-store-record) in the index. Both
[position](#cursor-position)
and the [object store
position](#cursor-object-store-position) are used when finding the next appropriate record.

A [cursor](#cursor) has a
[key] and a [value] which represent the
[key](#key) and the
[value](#value) of the last iterated
[record](#object-store-record).

A [cursor](#cursor) has a [got value
flag]. When this flag is false, the cursor is
either in the process of loading the next value or it has reached the
end of its [range](#cursor-range). When it is true, it indicates that the cursor is
currently holding a value and that it is ready to iterate to the next
one.

If the [source](#cursor-source) of a cursor is an [object
store](#object-store), the
[effective object store] of the cursor
is that object store and the [effective key] of the cursor
is the cursor's [position](#cursor-position). If the
[source](#cursor-source) of a
cursor is an [index](#index-concept), the [effective object
store](#cursor-effective-object-store) of the cursor is that index's
[referenced](#index-referenced) object store and the [effective
key](#cursor-effective-key) is the cursor's [object store
position](#cursor-object-store-position).

A [cursor](#cursor) has a
[request], which is the
[request](#request) used to open the
cursor.

A [cursor](#cursor) also has a [key
only flag], that indicates whether the cursor's
[value](#cursor-value) is exposed
via the API.

### 2.11. Key generators

When a [object store](#object-store) is created it can be specified to use a [key
generator].
A key generator is used to generate keys for records inserted into an
object store if not otherwise specified.

A [key generator](#key-generator) has a [current number].
The [current
number](#key-generator-current-number) is always a positive integer less than or equal to
2^53^ (9007199254740992) + 1. The initial value of a [key
generator](#key-generator)'s
[current
number](#key-generator-current-number) is 1, set when the associated [object
store](#object-store) is
created. The [current
number](#key-generator-current-number) is incremented as keys are generated, and may be
updated to a specific value by using explicit keys.

[NOTE:] Every object store that uses key generators uses a
separate generator. That is, interacting with one object store never
affects the key generator of any other object store.

Modifying a key generator's [current
number](#key-generator-current-number) is considered part of a database operation. This means
that if the operation fails and the operation is reverted, the [current
number](#key-generator-current-number) is reverted to the value it had before the operation
started. This applies both to modifications that happen due to the
[current
number](#key-generator-current-number) getting increased by 1 when the key generator is used,
and to modifications that happen due to a
[record](#object-store-record) being stored with a key value specified in the call to
store the [record](#object-store-record).

Likewise, if a
[transaction](#transaction-concept) is aborted, the [current
number](#key-generator-current-number) of the key generator for each [object
store](#object-store) in the
transaction's [scope](#transaction-scope) is reverted to the value it had before the
[transaction](#transaction-concept) was started.

The [current
number](#key-generator-current-number) for a key generator never decreases, other than as a
result of database operations being reverted. Deleting a
[record](#object-store-record) from an [object
store](#object-store) never
affects the object store's key generator. Even clearing all records from
an object store, for example using the
[`clear()`](#dom-idbobjectstore-clear) method, does not affect the [current
number](#key-generator-current-number) of the object store's key generator.

When a [record](#object-store-record) is stored and a [key](#key) is not specified in the call to store the record, a key
is generated.

To [generate a key] for an [object
store](#object-store)
`store`, run these steps:

1. Let `generator` be `store`'s [key
 generator](#key-generator).

2. Let `key` be `generator`'s [current
 number](#key-generator-current-number).

3. If `key` is greater than 2^53^ (9007199254740992), then
 return failure.

4. Increase `generator`'s [current
 number](#key-generator-current-number) by 1.

5. Return `key`.

When a [record](#object-store-record) is stored and a [key](#key) is specified in the call to store the record, the
associated [key generator](#key-generator) may be updated.

To [possibly update the key
generator] for an [object
store](#object-store)
`store` with `key`, run these steps:

1. If the [type](#key-type) of
 `key` is not *number*, abort these steps.

2. Let `value` be the
 [value](#key-value) of
 `key`.

3. Set `value` to the minimum of `value` and
 2^53^ (9007199254740992).

4. Set `value` to the largest integer not greater than
 `value`.

5. Let `generator` be `store`'s [key
 generator](#key-generator).

6. If `value` is greater than or equal to
 `generator`'s [current
 number](#key-generator-current-number), then set `generator`'s [current
 number](#key-generator-current-number) to `value` + 1.

[NOTE:] A key can be specified both for object stores which use
[in-line
keys](#object-store-in-line-keys), by setting the property on the stored value which the
object store's [key
path](#object-store-key-path) points to, and for object stores which use [out-of-line
keys](#object-store-out-of-line-keys), by passing a key argument to the call to store the
[record](#object-store-record).

Only specified keys of [type](#key-type) *number* can affect the [current
number](#key-generator-current-number) of the key generator. Keys of
[type](#key-type) *date*, *array*
(regardless of the other keys they contain), *binary*, or *string*
(regardless of whether they could be parsed as numbers) have no effect
on the [current
number](#key-generator-current-number) of the key generator. Keys of
[type](#key-type) *number* with
[value](#key-value) less than 1 do
not affect the [current
number](#key-generator-current-number) since they are always lower than the [current
number](#key-generator-current-number).

When the [current
number](#key-generator-current-number) of a key generator reaches above the value 2^53^
(9007199254740992) any subsequent attempts to use the key generator to
generate a new [key](#key) will result
in a
\"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException). It is still possible to insert
[records](#object-store-record) into the object store by specifying an explicit key,
however the only way to use a key generator again for such records is to
delete the object store and create a new one.

[NOTE:] This limit arises because integers greater than
9007199254740992 cannot be uniquely represented as ECMAScript
[`Number`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-number-objects)s. As an example,
`9007199254740992 + 1 === 9007199254740992` in ECMAScript.

As long as key generators are used in a normal fashion this limit will
not be a problem. If you generate a new key 1000 times per second day
and night, you won't run into this limit for over 285000 years.

A practical result of this is that the first key generated for an object
store is always 1 (unless a higher numeric key is inserted first) and
the key generated for an object store is always a positive integer
higher than the highest numeric key in the store. The same key is never
generated twice for the same object store unless a transaction is rolled
back.

Each object store gets its own key generator:

```
store1 = db.createObjectStore("store1", { autoIncrement: true });
store1.put("a"); // Will get key 1
store2 = db.createObjectStore("store2", { autoIncrement: true });
store2.put("a"); // Will get key 1
store1.put("b"); // Will get key 2
store2.put("b"); // Will get key 2
```

If an insertion fails due to constraint violations or IO error, the key
generator is not updated.

```
transaction.onerror = function(e) { e.preventDefault() };
store = db.createObjectStore("store1", { autoIncrement: true });
index = store.createIndex("index1", "ix", { unique: true });
store.put({ ix: "a"}); // Will get key 1
store.put({ ix: "a"}); // Will fail
store.put({ ix: "b"}); // Will get key 2
```

Removing items from an objectStore never affects the key generator.
Including when
[`clear()`](#dom-idbobjectstore-clear) is called.

```
store = db.createObjectStore("store1", { autoIncrement: true });
store.put("a"); // Will get key 1
store.delete(1);
store.put("b"); // Will get key 2
store.clear();
store.put("c"); // Will get key 3
store.delete(IDBKeyRange.lowerBound(0));
store.put("d"); // Will get key 4
```

Inserting an item with an explicit key affects the key generator if, and
only if, the key is numeric and higher than the last generated key.

```
store = db.createObjectStore("store1", { autoIncrement: true });
store.put("a"); // Will get key 1
store.put("b", 3); // Will use key 3
store.put("c"); // Will get key 4
store.put("d", -10); // Will use key -10
store.put("e"); // Will get key 5
store.put("f", 6.00001); // Will use key 6.0001
store.put("g"); // Will get key 7
store.put("f", 8.9999); // Will use key 8.9999
store.put("g"); // Will get key 9
store.put("h", "foo"); // Will use key "foo"
store.put("i"); // Will get key 10
store.put("j", [1000]); // Will use key [1000]
store.put("k"); // Will get key 11
// All of these would behave the same if the objectStore used a
// keyPath and the explicit key was passed inline in the object
```

Aborting a transaction rolls back any increases to the key generator
which happened during the transaction. This is to make all rollbacks
consistent since rollbacks that happen due to crash never has a chance
to commit the increased key generator value.

```
db.createObjectStore("store", { autoIncrement: true });
trans1 = db.transaction(["store"], "readwrite");
store_t1 = trans1.objectStore("store");
store_t1.put("a"); // Will get key 1
store_t1.put("b"); // Will get key 2
trans1.abort();
trans2 = db.transaction(["store"], "readwrite");
store_t2 = trans2.objectStore("store");
store_t2.put("c"); // Will get key 1
store_t2.put("d"); // Will get key 2
```

The following examples illustrate the different behaviors when trying to
use in-line [keys](#key) and [key
generators](#key-generator) to
save an object to an [object
store](#object-store).

If the following conditions are true:

- The [object store](#object-store) has a [key
 generator](#key-generator).

- There is no in-line value for the [key
 path](#object-store-key-path) property.

Then the value provided by the [key
generator](#key-generator) is
used to populate the key value. In the example below the [key
path](#object-store-key-path) for the object store is \"`foo.bar`\". The actual
object has no value for the `bar` property, `{ foo: }`. When the
object is saved in the [object
store](#object-store) the `bar`
property is assigned a value of 1 because that is the next
[key](#key) generated by the [key
generator](#key-generator).

```
const store = db.createObjectStore("store", { keyPath: "foo.bar",
 autoIncrement: true });
store.put({ foo: }).onsuccess = function(e) {
 const key = e.target.result;
 console.assert(key === 1);
};
```

If the following conditions are true:

- The [object store](#object-store) has a [key
 generator](#key-generator).

- There is a value for the [key
 path](#object-store-key-path) property.

Then the value associated with the [key
path](#object-store-key-path) property is used. The auto-generated
[key](#key) is not used. In the example
below the [key
path](#object-store-key-path) for the [object
store](#object-store) is
\"`foo.bar`\". The actual object has a value of 10 for the `bar`
property, `{ foo: { bar: 10} }`. When the object is saved in the [object
store](#object-store) the `bar`
property keeps its value of 10, because that is the key value.

```
const store = db.createObjectStore("store", { keyPath: "foo.bar",
 autoIncrement: true });
store.put({ foo: { bar: 10 } }).onsuccess = function(e) {
 const key = e.target.result;
 console.assert(key === 10);
};
```

The following example illustrates the scenario when the specified
in-line [key](#key) is defined through a
[key path](#object-store-key-path) but there is no property matching it. The value
provided by the [key generator](#key-generator) is then used to populate the key value and the system
is responsible for creating as many properties as it requires to suffice
the property dependencies on the hierarchy chain. In the example below
the [key path](#object-store-key-path) for the [object
store](#object-store) is
\"`foo.bar.baz`\". The actual object has no value for the `foo`
property, `{ zip: }`. When the object is saved in the [object
store](#object-store) the
`foo`, `bar`, and `baz` properties are created each as a child of the
other until a value for `foo.bar.baz` can be assigned. The value for
`foo.bar.baz` is the next key generated by the object store.

```
const store = db.createObjectStore("store", { keyPath: "foo.bar.baz",
 autoIncrement: true });
store.put({ zip: }).onsuccess = function(e) {
 const key = e.target.result;
 console.assert(key === 1);
 store.get(key).onsuccess = function(e) {
 const value = e.target.result;
 // value will be: { zip: , foo: { bar: { baz: 1 } } }
 console.assert(value.foo.bar.baz === 1);
 };
};
```

Attempting to store a property on a primitive value will fail and throw
an error. In the first example below the [key
path](#object-store-key-path) for the object store is \"`foo`\". The actual object is
a primitive with the value, `4`. Trying to define a property on that
primitive value fails.

```
const store = db.createObjectStore("store", { keyPath: "foo", autoIncrement: true });

// The key generation will attempt to create and store the key path
// property on this primitive.
store.put(4); // will throw DataError
```

### 2.12. Record snapshot

A [record snapshot] contains keys and values copied from an [object store
record](#object-store-list-of-records) or an [index
record](#index-list-of-records).

A [record snapshot](#record-snapshot) has a [key] which is a
[key](#key).

A [record snapshot](#record-snapshot) has a [value] which is a
[value](#value).

[NOTE:] For an [index
record](#index-list-of-records), the snapshot's
[value](#record-snapshot-value) is a copy of the record's [referenced
value](#index-referenced-value). For an [object store
record](#object-store-list-of-records), the snapshot's
[value](#record-snapshot-value) is the [record's
value](#object-store-record).

A [record snapshot](#record-snapshot) also has a [primary key]
which is a [key](#key).

[NOTE:] For an [index
record](#index-list-of-records), the snapshot's [primary
key](#record-snapshot-primary-key) is the record's
[value](#index-values), which is
the key of the record in the index's [referenced object
store](#index-referenced).
For an [object store
record](#object-store-list-of-records), the snapshot's [primary
key](#record-snapshot-primary-key) and
[key](#record-snapshot-key) are the same [key](#key), which is the [record's
key](#object-store-record).

## 3. Exceptions

Each of the exceptions used in this document is a
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) or
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)-derived interface, as defined in
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard").

The table below lists the
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) names used in this document along with a description of
the exception's usage.

Type

Description

[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)

A request was aborted.

[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)

A mutation operation in the transaction failed because a constraint was
not satisfied.

[`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)

The data being stored could not be cloned by the internal structured
cloning algorithm.

[`DataError`](https://webidl.spec.whatwg.org/#dataerror)

Data provided to an operation does not meet requirements.

[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)

An invalid operation was performed on an object.

[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)

An operation was called on an object on which it is not allowed or at a
time when it is not allowed, or if a request is made on a source object
that has been deleted or removed.

[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)

The operation failed because the requested database object could not be
found.

[`NotReadableError`](https://webidl.spec.whatwg.org/#notreadableerror)

The operation failed because the underlying storage containing the
requested data could not be read.

[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)

The keyPath argument contains an invalid key path.

[`ReadOnlyError`](https://webidl.spec.whatwg.org/#readonlyerror)

The mutating operation was attempted in a read-only transaction.

[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)

A request was placed against a transaction which is currently not
active, or which is finished.

[`UnknownError`](https://webidl.spec.whatwg.org/#unknownerror)

The operation failed for transient reasons unrelated to the database
itself or not covered by any other error.

[`VersionError`](https://webidl.spec.whatwg.org/#versionerror)

An attempt was made to open a database using a lower version than the
existing version.

Apart from the above
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) names, the
[`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror) exception type is to be used if the operation failed
because there was not enough remaining storage space, or the storage
quota was reached and the user declined to give more space to the
database.

[NOTE:] Given that multiple Indexed DB operations can throw the
same type of error, and that even a single operation can throw the same
type of error for multiple reasons, implementations are encouraged to
provide more specific messages to enable developers to identify the
cause of errors.

## 4. API

The API methods return without blocking the calling thread. All
asynchronous operations immediately return an
[`IDBRequest`](#idbrequest)
instance. This object does not initially contain any information about
the result of the operation. Once information becomes available, an
event is fired on the request and the information becomes available
through the properties of the
[`IDBRequest`](#idbrequest)
instance.

The task source for these tasks is the [database access task
source].

To [queue a database task], perform [queue a
task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on the [database access task
source](#database-access-task-source).

### 4.1. The [`IDBRequest` interface]
The [`IDBRequest`](#idbrequest) interface provides the means to access results of
asynchronous requests to [databases](#database) and [database](#database) objects using [event handler IDL
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
[\[HTML\]](#biblio-html "HTML Standard").

Every method for making asynchronous requests returns an
[`IDBRequest`](#idbrequest)
object that communicates back to the requesting application through
events. This design means that any number of requests can be active on
any [database](#database) at a
time.

In the following example, we open a
[database](#database)
asynchronously. Various event handlers are registered for responding to
various situations.

```
const request = indexedDB.open('AddressBook', 15);
request.onsuccess = function(evt) ;
request.onerror = function(evt) ;
```

```
[Exposed=(Window,Worker)]
interface IDBRequest : EventTarget {
 readonly attribute any result;
 readonly attribute DOMException? error;
 readonly attribute (IDBObjectStore or IDBIndex or IDBCursor)? source;
 readonly attribute IDBTransaction? transaction;
 readonly attribute IDBRequestReadyState readyState;

 // Event handlers:
 attribute EventHandler onsuccess;
 attribute EventHandler onerror;
};

enum IDBRequestReadyState {
 "pending",
 "done"
};
```

`request` . [`result`](#dom-idbrequest-result)

: When a request is completed, returns the
 [result](#request-result),
 or `undefined` if the request failed. Throws a
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if the request is still pending.

`request` . [`error`](#dom-idbrequest-error)

: When a request is completed, returns the
 [error](#request-error) (a
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)), or null if the request succeeded. Throws a
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if the request is still pending.

`request` . [`source`](#dom-idbrequest-source)

: Returns the
 [`IDBObjectStore`](#idbobjectstore), [`IDBIndex`](#idbindex), or
 [`IDBCursor`](#idbcursor)
 the request was made against, or null if it was an [open
 request](#request-open-request).

`request` . [`transaction`](#dom-idbrequest-transaction)

: Returns the
 [`IDBTransaction`](#idbtransaction) the request was made within. If this as an [open
 request](#request-open-request), then it returns an [upgrade
 transaction](#upgrade-transaction) while it is
 [live](#transaction-live), or null otherwise.

`request` . [`readyState`](#dom-idbrequest-readystate)

: Returns
 \"[`pending`](#dom-idbrequestreadystate-pending)\" until a request is complete, then returns
 \"[`done`](#dom-idbrequestreadystate-done)\".

The [`result`] getter steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s [done
 flag](#request-done-flag) is false, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. Return [this](https://webidl.spec.whatwg.org/#this)'s
 [result](#request-result),
 or undefined if the request resulted in an error.

The [`error`] getter steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s [done
 flag](#request-done-flag) is false, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. Return [this](https://webidl.spec.whatwg.org/#this)'s [error](#request-error), or null if no error occurred.

The [`source`] getter steps are to
return [this](https://webidl.spec.whatwg.org/#this)'s [source](#request-source), or null if no
[source](#request-source) is
set.

The [`transaction`] getter
steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s
[transaction](#request-transaction).

[NOTE:] The
[`transaction`](#dom-idbrequest-transaction) getter can return null for certain requests, such as
for [requests](#request) returned
from [`open()`](#dom-idbfactory-open).

The [`readyState`] getter
steps are to return
\"[`pending`](#dom-idbrequestreadystate-pending)\" if
[this](https://webidl.spec.whatwg.org/#this)'s [done
flag](#request-done-flag)
is false, and
\"[`done`](#dom-idbrequestreadystate-done)\" otherwise.

The [`onsuccess`] attribute is an
[event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`success`](#eventdef-idbrequest-success).

The [`onerror`] attribute is an
[event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`error`](#eventdef-idbrequest-error) event.

Methods on [`IDBDatabase`](#idbdatabase) that return a [open
request](#request-open-request) use an extended interface to allow listening to the
[`blocked`](#eventdef-idbopendbrequest-blocked) and
[`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded) events.

```
[Exposed=(Window,Worker)]
interface IDBOpenDBRequest : IDBRequest {
 // Event handlers:
 attribute EventHandler onblocked;
 attribute EventHandler onupgradeneeded;
};
```

The [`onblocked`]
attribute is an [event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`blocked`](#eventdef-idbopendbrequest-blocked).

The [`onupgradeneeded`] attribute is an [event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded).

### 4.2. Event interfaces

This specification fires events with the following custom interfaces:

```
[Exposed=(Window,Worker)]
interface IDBVersionChangeEvent : Event {
 constructor(DOMString type, optional IDBVersionChangeEventInit eventInitDict = );
 readonly attribute unsigned long long oldVersion;
 readonly attribute unsigned long long? newVersion;
};

dictionary IDBVersionChangeEventInit : EventInit {
 unsigned long long oldVersion = 0;
 unsigned long long? newVersion = null;
};
```

The [`oldVersion`] getter steps are to return the value it
was initialized to. It represents the previous version of the database.

The [`newVersion`] getter steps are to return the value it
was initialized to. It represents the new version of the database, or
null if the database is being deleted. See the steps to [upgrade a
database](#upgrade-a-database).

Events are constructed as defined in [DOM § 2.5 Constructing
events](https://dom.spec.whatwg.org/#constructing-events).

To [fire a version change event] named `e` at
`target` given `oldVersion` and
`newVersion`, run these steps:

1. Let `event` be the result of [creating an
 event](https://dom.spec.whatwg.org/#concept-event-create) using
 [`IDBVersionChangeEvent`](#idbversionchangeevent).

2. Set `event`'s
 [`type`](https://dom.spec.whatwg.org/#dom-event-type) attribute to `e`.

3. Set `event`'s
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) and
 [`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable) attributes to false.

4. Set `event`'s
 [`oldVersion`](#dom-idbversionchangeevent-oldversion) attribute to `oldVersion`.

5. Set `event`'s
 [`newVersion`](#dom-idbversionchangeevent-newversion) attribute to `newVersion`.

6. Let `legacyOutputDidListenersThrowFlag` be false.

7. [Dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch) `event` at `target` with
 `legacyOutputDidListenersThrowFlag`.

8. Return `legacyOutputDidListenersThrowFlag`.

 [NOTE:] The return value of this algorithm is not always
 used.

### 4.3. The [`IDBFactory` interface]
[Database](#database) objects are
accessed through methods on the
[`IDBFactory`](#idbfactory)
interface. A single object implementing this interface is present in the
global scope of environments that support Indexed DB operations.

```
partial interface mixin WindowOrWorkerGlobalScope {
 [SameObject] readonly attribute IDBFactory indexedDB;
};
```

The [`indexedDB`] attribute provides applications a
mechanism for accessing capabilities of indexed databases.

```
[Exposed=(Window,Worker)]
interface IDBFactory {
 [NewObject] IDBOpenDBRequest open(DOMString name,
 optional [EnforceRange] unsigned long long version);
 [NewObject] IDBOpenDBRequest deleteDatabase(DOMString name);

 Promise<sequence<IDBDatabaseInfo>> databases();

 short cmp(any first, any second);
};

dictionary IDBDatabaseInfo {
 DOMString name;
 unsigned long long version;
};
```

`request` = indexedDB . [`open`](#dom-idbfactory-open)(`name`)

: Attempts to open a [connection](#connection) to the named
 [database](#database) with the
 current version, or 1 if it does not already exist. If the request
 is successful `request`'s
 [`result`](#dom-idbrequest-result) will be the
 [connection](#connection).

`request` = indexedDB . [`open`](#dom-idbfactory-open)(`name`, `version`)

: Attempts to open a [connection](#connection) to the named
 [database](#database) with the
 specified `version`. If the database already exists with
 a lower version and there are open
 [connections](#connection)
 that don't close in response to a
 [`versionchange`](#eventdef-idbdatabase-versionchange) event, the request will be blocked
 until they all close, then an upgrade will occur. If the database
 already exists with a higher version the request will fail. If the
 request is successful `request`'s
 [`result`](#dom-idbrequest-result) will be the
 [connection](#connection).

`request` = indexedDB . [`deleteDatabase`](#dom-idbfactory-deletedatabase)(`name`)

: Attempts to delete the named
 [database](#database). If the
 database already exists and there are open
 [connections](#connection)
 that don't close in response to a
 [`versionchange`](#eventdef-idbdatabase-versionchange) event, the request will be blocked
 until they all close. If the request is successful
 `request`'s
 [`result`](#dom-idbrequest-result) will be null.

`result` = await indexedDB . [`databases`](#dom-idbfactory-databases)()

: Returns a promise which resolves to a list of objects giving a
 snapshot of the names and versions of databases within the [storage
 key](https://storage.spec.whatwg.org/#storage-key).

 This API is intended for web applications to introspect the use of
 databases, for example to clean up from earlier versions of a site's
 code. Note that the result is a snapshot; there are no guarantees
 about the sequencing of the collection of the data or the delivery
 of the response with respect to requests to create, upgrade, or
 delete databases by this context or others.

[`open(``name``, ``version``)`] method steps are:

1. If `version` is 0 (zero),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Let `environment` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

3. Let `storageKey` be the result of running [obtain a
 storage
 key](https://storage.spec.whatwg.org/#obtain-a-storage-key) given `environment`. If failure is
 returned, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

4. Let `request` be a new [open
 request](#request-open-request).

5. Run these steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `result` be the result of [opening a database
 connection](#open-a-database-connection), with `storageKey`,
 `name`, `version` if given and undefined
 otherwise, and `request`.

 What happens if `version` is not given?

 If `version` is not given and a
 [database](#database) with
 that name already exists, a connection will be opened without
 changing the
 [version](#database-version). If `version` is not given and no
 [database](#database) with
 that name exists, a new
 [database](#database) will
 be created with
 [version](#database-version) equal to 1.

 2. Set `request`'s [processed
 flag](#request-processed-flag) to true.

 3. [Queue a database
 task](#queue-a-database-task) to run these steps:

 1. If `result` is an error, then:

 1. Set `request`'s
 [result](#request-result) to undefined.

 2. Set `request`'s
 [error](#request-error) to `result`.

 3. Set `request`'s [done
 flag](#request-done-flag) to true.

 4. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`error`](#eventdef-idbrequest-error) at `request`
 with its
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) and
 [`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable) attributes initialized to true.

 2. Otherwise:

 1. Set `request`'s
 [result](#request-result) to `result`.

 2. Set `request`'s [done
 flag](#request-done-flag) to true.

 3. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`success`](#eventdef-idbrequest-success) at `request`.

 [NOTE:] If the steps above resulted in an [upgrade
 transaction](#upgrade-transaction) being run, these steps will run after that
 transaction finishes. This ensures that in the case where
 another version upgrade is about to happen, the success
 event is fired on the connection first so that the script
 gets a chance to register a listener for the
 [`versionchange`](#eventdef-idbdatabase-versionchange) event.

 Why aren't the steps to [fire a success
 event](#fire-a-success-event) or [fire an error
 event](#fire-an-error-event) used?

 There is no transaction associated with the request (at this
 point), so those steps --- which activate an associated
 transaction before dispatch and deactivate the transaction
 after dispatch --- do not apply.

6. Return a new
 [`IDBOpenDBRequest`](#idbopendbrequest) object for `request`.

[`deleteDatabase(``name``)`] method steps are:

1. Let `environment` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

2. Let `storageKey` be the result of running [obtain a
 storage
 key](https://storage.spec.whatwg.org/#obtain-a-storage-key) given `environment`. If failure is
 returned, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

3. Let `request` be a new [open
 request](#request-open-request).

4. Run these steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `result` be the result of [deleting a
 database](#delete-a-database), with `storageKey`,
 `name`, and `request`.

 2. Set `request`'s [processed
 flag](#request-processed-flag) to true.

 3. [Queue a database
 task](#queue-a-database-task) to run these steps:

 1. If `result` is an error, set
 `request`'s
 [error](#request-error) to `result`, set
 `request`'s [done
 flag](#request-done-flag) to true, and [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`error`](#eventdef-idbrequest-error) at `request` with
 its
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) and
 [`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable) attributes initialized to true.

 2. Otherwise, set `request`'s
 [result](#request-result) to undefined, set `request`'s
 [done flag](#request-done-flag) to true, and [fire a version change
 event](#fire-a-version-change-event) named
 [`success`](#eventdef-idbrequest-success) at
 [request](#request) with
 `result` and null.

 Why aren't the steps to [fire a success
 event](#fire-a-success-event) or [fire an error
 event](#fire-an-error-event) used?

 There is no transaction associated with the request, so
 those steps --- which activate an associated transaction
 before dispatch and deactivate the transaction after
 dispatch --- do not apply.

 Also, the
 [`success`](#eventdef-idbrequest-success) event here is a
 [`IDBVersionChangeEvent`](#idbversionchangeevent) which includes the
 [`oldVersion`](#dom-idbversionchangeevent-oldversion) and
 [`newVersion`](#dom-idbversionchangeevent-newversion) details.

5. Return a new
 [`IDBOpenDBRequest`](#idbopendbrequest) object for `request`.

The [`databases()`] method steps
are:

1. Let `environment` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

2. Let `storageKey` be the result of running [obtain a
 storage
 key](https://storage.spec.whatwg.org/#obtain-a-storage-key) given `environment`. If failure is
 returned, then return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with) a
 \"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)

3. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

4. Run these steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `databases` be the
 [set](https://infra.spec.whatwg.org/#ordered-set) of [databases](#database) in `storageKey`. If this cannot be
 determined for any reason, then [queue a database
 task](#queue-a-database-task) to
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an appropriate error (e.g.
 an
 \"[`UnknownError`](https://webidl.spec.whatwg.org/#unknownerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)) and terminate these steps.

 2. Let `result` be a new
 [list](https://infra.spec.whatwg.org/#list).

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `db` of `databases`:

 1. If `db`'s
 [version](#database-version) is 0, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. Let `info` be a new
 [`IDBDatabaseInfo`](#dictdef-idbdatabaseinfo) dictionary.

 3. Set `info`'s
 [`name`](#dom-idbdatabaseinfo-name) dictionary member to `db`'s
 [name](#database-name).

 4. Set `info`'s
 [`version`](#dom-idbdatabaseinfo-version) dictionary member to `db`'s
 [version](#database-version).

 5. [Append](https://infra.spec.whatwg.org/#list-append) `info` to `result`.

 4. [Queue a database
 task](#queue-a-database-task) to
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with `result`.

5. Return `p`.

🚧 The
[`databases()`](#dom-idbfactory-databases) method is new in this edition. It is supported in
Chrome 71, Edge 79, Firefox 126, and Safari 14. 🚧

`result` = indexedDB . [`cmp`](#dom-idbfactory-cmp)(`key1`, `key2`)

: Compares two values as [keys](#key).
 Returns -1 if `key1` precedes `key2`, 1 if
 `key2` precedes `key1`, and 0 if the keys are
 equal.

 Throws a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if either input is not a valid
 [key](#key).

[`cmp(``first``, ``second``)`] method steps are:

1. Let `a` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `first`. Rethrow any exceptions.

2. If `a` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Let `b` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `second`. Rethrow any exceptions.

4. If `b` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Return the results of [comparing two
 keys](#compare-two-keys)
 with `a` and `b`.

### 4.4. The [`IDBDatabase` interface]
The [`IDBDatabase`](#idbdatabase) interface represents a
[connection](#connection) to a
[database](#database).

An [`IDBDatabase`](#idbdatabase) object must not be garbage collected if its associated
[connection](#connection)'s
[close pending
flag](#connection-close-pending-flag) is false and it has one or more event listeners
registers whose type is one of
[`abort`](#eventdef-idbtransaction-abort),
[`error`](#eventdef-idbrequest-error), or
[`versionchange`](#eventdef-idbdatabase-versionchange). If an
[`IDBDatabase`](#idbdatabase) object is garbage collected, the associated
[connection](#connection) must be
[closed](#connection-closed).

```
[Exposed=(Window,Worker)]
interface IDBDatabase : EventTarget {
 readonly attribute DOMString name;
 readonly attribute unsigned long long version;
 readonly attribute DOMStringList objectStoreNames;

 [NewObject] IDBTransaction transaction((DOMString or sequence<DOMString>) storeNames,
 optional IDBTransactionMode mode = "readonly",
 optional IDBTransactionOptions options = );
 undefined close();

 [NewObject] IDBObjectStore createObjectStore(
 DOMString name,
 optional IDBObjectStoreParameters options = );
 undefined deleteObjectStore(DOMString name);

 // Event handlers:
 attribute EventHandler onabort;
 attribute EventHandler onclose;
 attribute EventHandler onerror;
 attribute EventHandler onversionchange;
};

enum IDBTransactionDurability { "default", "strict", "relaxed" };

dictionary IDBTransactionOptions {
 IDBTransactionDurability durability = "default";
};

dictionary IDBObjectStoreParameters {
 (DOMString or sequence<DOMString>)? keyPath = null;
 boolean autoIncrement = false;
};
```

`connection` . [`name`](#dom-idbdatabase-name)

: Returns the [name](#database-name) of the database.

`connection` . [`version`](#dom-idbdatabase-version)

: Returns the [version](#database-version) of the database.

The [`name`] getter steps are
to return [this](https://webidl.spec.whatwg.org/#this)'s associated [database](#database)'s [name](#database-name).

[NOTE:] The
[`name`](#dom-idbdatabase-name) attribute returns this name even if
[this](https://webidl.spec.whatwg.org/#this)'s [close pending
flag](#connection-close-pending-flag) is true. In other words, the value of this attribute
stays constant for the lifetime of the
[`IDBDatabase`](#idbdatabase) instance.

The [`version`] getter steps are
to return [this](https://webidl.spec.whatwg.org/#this)'s
[version](#connection-version).

Is this the same as the [database](#database)'s
[version](#database-version)?

As long as the [connection](#connection) is open, this is the same as the connected
[database](#database)'s
[version](#database-version). But once the
[connection](#connection) has
[closed](#connection-closed), this attribute will not reflect changes made with a
later [upgrade
transaction](#upgrade-transaction).

`connection` . [`objectStoreNames`](#dom-idbdatabase-objectstorenames)

: Returns a list of the names of [object
 stores](#object-store) in
 the database.

`store` = `connection` . [`createObjectStore`](#dom-idbdatabase-createobjectstore)(`name` \[, `options`\])

: Creates a new [object store](#object-store) with the given `name` and
 `options` and returns a new
 [`IDBObjectStore`](#idbobjectstore).

 Throws a
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if not called within an [upgrade
 transaction](#upgrade-transaction).

`connection` . [`deleteObjectStore`](#dom-idbdatabase-deleteobjectstore)(`name`)

: Deletes the [object store](#object-store) with the given `name`.

 Throws a
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if not called within an [upgrade
 transaction](#upgrade-transaction).

The [`objectStoreNames`] getter steps are:

1. Let `names` be a
 [list](https://infra.spec.whatwg.org/#list) of the
 [names](#object-store-name) of the [object
 stores](#object-store) in
 [this](https://webidl.spec.whatwg.org/#this)'s [object store
 set](#connection-object-store-set).

2. Return the result (a
 [`DOMStringList`](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#domstringlist)) of [creating a sorted name
 list](#create-a-sorted-name-list) with `names`.

Is this the same as the [database](#database)'s [object store](#object-store) [names](#object-store-name)?

As long as the [connection](#connection) is open, this is the same as the connected
[database](#database)'s [object
store](#object-store)
[names](#object-store-name). But once the
[connection](#connection) has
[closed](#connection-closed), this attribute will not reflect changes made with a
later [upgrade
transaction](#upgrade-transaction).

[`createObjectStore(``name``, ``options``)`]
method steps are:

1. Let `database` be
 [this](https://webidl.spec.whatwg.org/#this)'s associated
 [database](#database).

2. Let `transaction` be `database`'s [upgrade
 transaction](#database-upgrade-transaction) if it is not null, or
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) otherwise.

3. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. Let `keyPath` be `options`'s
 [`keyPath`](#dom-idbobjectstoreparameters-keypath) member if it is not undefined or null, or null
 otherwise.

5. If `keyPath` is not null and is not a [valid key
 path](#valid-key-path),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. If an [object store](#object-store)
 [named](#object-store-name) `name` already exists in
 `database`
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

7. Let `autoIncrement` be `options`'s
 [`autoIncrement`](#dom-idbobjectstoreparameters-autoincrement) member.

8. If `autoIncrement` is true and `keyPath` is an
 empty string or any sequence (empty or otherwise),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

9. Let `store` be a new [object
 store](#object-store) in
 `database`. Set the created [object
 store](#object-store)'s
 [name](#object-store-name) to `name`. If `autoIncrement`
 is true, then the created [object
 store](#object-store) uses
 a [key generator](#key-generator). If `keyPath` is not null, set the
 created [object store](#object-store)'s [key
 path](#object-store-key-path) to `keyPath`.

10. Return a new [object store
 handle](#object-store-handle) associated with `store` and
 `transaction`.

This method creates and returns a new [object
store](#object-store) with the
given name in the [connected](#connection) [database](#database). Note that this method must only be called from within
an [upgrade
transaction](#upgrade-transaction).

This method synchronously modifies the
[`objectStoreNames`](#dom-idbdatabase-objectstorenames) property on the
[`IDBDatabase`](#idbdatabase) instance on which it was called.

In some implementations it is possible for the implementation to run
into problems after queuing a task to create the [object
store](#object-store) after the
[`createObjectStore()`](#dom-idbdatabase-createobjectstore) method has returned. For example in implementations
where metadata about the newly created [object
store](#object-store) is
inserted into the database asynchronously, or where the implementation
might need to ask the user for permission for quota reasons. Such
implementations must still create and return an
[`IDBObjectStore`](#idbobjectstore) object, and once the implementation determines that
creating the [object store](#object-store) has failed, it must abort the transaction using the
steps to [abort a
transaction](#abort-a-transaction) using the appropriate error. For example if creating
the [object store](#object-store) failed due to quota reasons, a
[`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror) must be used as error.

[`deleteObjectStore(``name``)`] method steps are:

1. Let `database` be
 [this](https://webidl.spec.whatwg.org/#this)'s associated
 [database](#database).

2. Let `transaction` be `database`'s [upgrade
 transaction](#database-upgrade-transaction) if it is not null, or
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) otherwise.

3. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. Let `store` be the [object
 store](#object-store)
 [named](#object-store-name) `name` in `database`, or
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if none.

5. Remove `store` from
 [this](https://webidl.spec.whatwg.org/#this)'s [object store
 set](#connection-object-store-set).

6. If there is an [object store
 handle](#object-store-handle) associated with `store` and
 `transaction`, remove all entries from its [index
 set](#object-store-handle-index-set).

7. Destroy `store`.

This method destroys the [object
store](#object-store) with the
given name in the [connected](#connection) [database](#database). Note that this method must only be called from within
an [upgrade
transaction](#upgrade-transaction).

This method synchronously modifies the
[`objectStoreNames`](#dom-idbdatabase-objectstorenames) property on the
[`IDBDatabase`](#idbdatabase) instance on which it was called.

`transaction` = `connection` . [`transaction`](#dom-idbdatabase-transaction)(`scope` \[, `mode` \[, `options` \] \])

: Returns a new
 [transaction](#transaction-concept) with the given `scope` (which can be a
 single [object store](#object-store)
 [name](#object-store-name) or an array of
 [names](#object-store-name)), `mode`
 (\"[`readonly`](#dom-idbtransactionmode-readonly)\" or
 \"[`readwrite`](#dom-idbtransactionmode-readwrite)\"), and additional `options` including
 [`durability`](#dom-idbtransactionoptions-durability)
 (\"[`default`](#dom-idbtransactiondurability-default)\",
 \"[`strict`](#dom-idbtransactiondurability-strict)\" or
 \"[`relaxed`](#dom-idbtransactiondurability-relaxed)\").

 The default `mode` is
 \"[`readonly`](#dom-idbtransactionmode-readonly)\" and the default
 [`durability`](#dom-idbtransactionoptions-durability) is
 \"[`default`](#dom-idbtransactiondurability-default)\".

`connection` . [`close`](#dom-idbdatabase-close)()

: Closes the [connection](#connection) once all running
 [transactions](#transaction-concept) have finished.

[`transaction(``storeNames``, ``mode``, ``options``)`]
method steps are:

1. If a [live](#transaction-live) [upgrade
 transaction](#upgrade-transaction) is associated with the
 [connection](#connection),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. If [this](https://webidl.spec.whatwg.org/#this)'s [close pending
 flag](#connection-close-pending-flag) is true, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Let `scope` be the set of unique strings in
 `storeNames` if it is a sequence, or a set containing one
 string equal to `storeNames` otherwise.

4. If any string in `scope` is not the name of an [object
 store](#object-store) in
 the [connected](#connection)
 [database](#database),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If `scope` is empty,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. If `mode` is not
 \"[`readonly`](#dom-idbtransactionmode-readonly)\" or
 \"[`readwrite`](#dom-idbtransactionmode-readwrite)\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

7. Let `transaction` be a newly
 [created](#transaction-created)
 [transaction](#transaction-concept) with this
 [connection](#connection),
 `mode`, `options`'
 [`durability`](#dom-idbtransactionoptions-durability) member, and the set of [object
 stores](#object-store)
 named in `scope`.

8. Set `transaction`'s [cleanup event
 loop](#transaction-cleanup-event-loop) to the current [event
 loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop).

9. Return an
 [`IDBTransaction`](#idbtransaction) object representing `transaction`.

🚧 The
[`durability`](#dom-idbtransactionoptions-durability) option is new in this edition. It is supported in
Chrome 82, Edge 82, Firefox 126, and Safari 15. 🚧

[NOTE:] The created `transaction` will follow the
[lifetime](#transaction-lifetime) rules.

The [`close()`] method steps are:

1. Run [close a database
 connection](#close-a-database-connection) with this
 [connection](#connection).

[NOTE:] The [connection](#connection) will not actually
[close](#connection-closed)
until all outstanding
[transactions](#transaction-concept) have completed. Subsequent calls to
[`close()`](#dom-idbdatabase-close) will have no effect.

The [`onabort`] attribute is an
[event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`abort`](#eventdef-idbtransaction-abort).

The [`onclose`] attribute is an
[event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`close`](#eventdef-idbdatabase-close).

The [`onerror`] attribute is an
[event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`error`](#eventdef-idbrequest-error).

The [`onversionchange`] attribute is an [event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`versionchange`](#eventdef-idbdatabase-versionchange).

### 4.5. The [`IDBObjectStore` interface]
The [`IDBObjectStore`](#idbobjectstore) interface represents an [object store
handle](#object-store-handle).

```
[Exposed=(Window,Worker)]
interface IDBObjectStore {
 attribute DOMString name;
 readonly attribute any keyPath;
 readonly attribute DOMStringList indexNames;
 [SameObject] readonly attribute IDBTransaction transaction;
 readonly attribute boolean autoIncrement;

 [NewObject] IDBRequest put(any value, optional any key);
 [NewObject] IDBRequest add(any value, optional any key);
 [NewObject] IDBRequest delete(any query);
 [NewObject] IDBRequest clear();
 [NewObject] IDBRequest get(any query);
 [NewObject] IDBRequest getKey(any query);
 [NewObject] IDBRequest getAll(optional any queryOrOptions,
 optional [EnforceRange] unsigned long count);
 [NewObject] IDBRequest getAllKeys(optional any queryOrOptions,
 optional [EnforceRange] unsigned long count);
 [NewObject] IDBRequest getAllRecords(optional IDBGetAllOptions options = );
 [NewObject] IDBRequest count(optional any query);

 [NewObject] IDBRequest openCursor(optional any query,
 optional IDBCursorDirection direction = "next");
 [NewObject] IDBRequest openKeyCursor(optional any query,
 optional IDBCursorDirection direction = "next");

 IDBIndex index(DOMString name);

 [NewObject] IDBIndex createIndex(DOMString name,
 (DOMString or sequence<DOMString>) keyPath,
 optional IDBIndexParameters options = );
 undefined deleteIndex(DOMString name);
};

dictionary IDBIndexParameters {
 boolean unique = false;
 boolean multiEntry = false;
};

dictionary IDBGetAllOptions {
 any query = null;
 [EnforceRange] unsigned long count;
 IDBCursorDirection direction = "next";
};
```

`store` . [`name`](#dom-idbobjectstore-name)

: Returns the [name](#object-store-name) of the store.

`store` . [`name`](#dom-idbobjectstore-name) = `newName`

: Updates the [name](#object-store-name) of the store to `newName`.

 Throws
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if not called within an [upgrade
 transaction](#upgrade-transaction).

`store` . [`keyPath`](#dom-idbobjectstore-keypath)

: Returns the [key
 path](#object-store-key-path) of the store, or null if none.

`store` . [`indexNames`](#dom-idbobjectstore-indexnames)

: Returns a list of the names of indexes in the store.

`store` . [`transaction`](#dom-idbobjectstore-transaction)

: Returns the associated
 [transaction](#transaction-concept).

`store` . [`autoIncrement`](#dom-idbobjectstore-autoincrement)

: Returns true if the store has a [key
 generator](#key-generator), and false otherwise.

The [`name`] getter steps
are to return
[this](https://webidl.spec.whatwg.org/#this)'s
[name](#object-store-name).

Is this the same as the [object
store](#object-store)'s
[name](#object-store-name)?

As long as the
[transaction](#transaction-concept) has not
[finished](#transaction-finished), this is the same as the associated [object
store](#object-store)'s
[name](#object-store-name). But once the
[transaction](#transaction-concept) has
[finished](#transaction-finished), this attribute will not reflect changes made with a
later [upgrade
transaction](#upgrade-transaction).

[`name`](#dom-idbobjectstore-name) setter steps are:

1. Let `name` be [the given
 value](https://webidl.spec.whatwg.org/#the-given-value).

2. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

3. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

4. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If `transaction` is not an [upgrade
 transaction](#upgrade-transaction),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

7. If `store`'s
 [name](#object-store-name) is equal to `name`, terminate these
 steps.

8. If an [object store](#object-store)
 [named](#object-store-name) `name` already exists in
 `store`'s [database](#database),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

9. Set `store`'s
 [name](#object-store-name) to `name`.

10. Set [this](https://webidl.spec.whatwg.org/#this)'s
 [name](#object-store-handle-name) to `name`.

The [`keyPath`] getter steps
are to return
[this](https://webidl.spec.whatwg.org/#this)'s [object
store](#object-store-handle-object-store)'s [key
path](#object-store-key-path), or null if none. The [key
path](#key-path) is converted as a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) (if a string) or a
[`sequence`](https://webidl.spec.whatwg.org/#idl-sequence)`<`[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)`>` (if a list of strings), per
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard").

[NOTE:] The returned value is not the same instance that was
used when the [object store](#object-store) was created. However, if this attribute returns an
object (specifically an
[`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects)), it returns the same object instance every time it is
inspected. Changing the properties of the object has no effect on the
[object store](#object-store).

The [`indexNames`]
getter steps are:

1. Let `names` be a
 [list](https://infra.spec.whatwg.org/#list) of the [names](#index-name) of the
 [indexes](#index-concept)
 in [this](https://webidl.spec.whatwg.org/#this)'s [index
 set](#object-store-handle-index-set).

2. Return the result (a
 [`DOMStringList`](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#domstringlist)) of [creating a sorted name
 list](#create-a-sorted-name-list) with `names`.

Is this the same as [object
store](#object-store)'s list of
[index](#index-concept)
[names](#index-name)?

As long as the
[transaction](#transaction-concept) has not
[finished](#transaction-finished), this is the same as the associated [object
store](#object-store)'s list of
[index](#index-concept)
[names](#index-name). But once the
[transaction](#transaction-concept) has
[finished](#transaction-finished), this attribute will not reflect changes made with a
later [upgrade
transaction](#upgrade-transaction).

The [`transaction`]
getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s
[transaction](#object-store-handle-transaction).

The [`autoIncrement`] getter steps are to return true if
[this](https://webidl.spec.whatwg.org/#this)'s [object
store](#object-store-handle-object-store) has a [key
generator](#key-generator),
and false otherwise.

The following methods throw a
\"[`ReadOnlyError`](https://webidl.spec.whatwg.org/#readonlyerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if called within a [read-only
transaction](#transaction-read-only-transaction), and a
\"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if called when the
[transaction](#transaction-concept) is not
[active](#transaction-active).

`request` = `store` . [`put`](#dom-idbobjectstore-put)(`value` \[, `key`\])\
`request` = `store` . [`add`](#dom-idbobjectstore-add)(`value` \[, `key`\])

: Adds or updates a
 [record](#object-store-record) in `store` with the given
 `value` and `key`.

 If the store uses [in-line
 keys](#object-store-in-line-keys) and `key` is specified a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) will be thrown.

 If
 [`put()`](#dom-idbobjectstore-put) is used, any existing
 [record](#object-store-record) with the [key](#key) will be replaced. If
 [`add()`](#dom-idbobjectstore-add) is used, and if a
 [record](#object-store-record) with the [key](#key) already exists the `request` will fail,
 with `request`'s
 [`error`](#dom-idbrequest-error) set to a
 \"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be the
 [record](#object-store-record)'s [key](#key).

`request` = `store` . [`delete`](#dom-idbobjectstore-delete)(`query`)

: Deletes
 [records](#object-store-record) in `store` with the given
 [key](#key) or in the given [key
 range](#key-range) in
 `query`.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be `undefined`.

`request` = `store` . [`clear`](#dom-idbobjectstore-clear)()

: Deletes all
 [records](#object-store-record) in `store`.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be `undefined`.

[`put(``value``, ``key``)`] method steps are to return
the result of running [add or put](#add-or-put) with
[this](https://webidl.spec.whatwg.org/#this), `value`, `key` and the
`no-overwrite flag` false.

The
[`add(``value``, ``key``)`] method steps are to return
the result of running [add or put](#add-or-put) with
[this](https://webidl.spec.whatwg.org/#this), `value`, `key` and the
`no-overwrite flag` true.

To [add or put] with `handle`, `value`,
`key`, and `no-overwrite flag`, run these steps:

1. Let `transaction` be `handle`'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be `handle`'s [object
 store](#object-store-handle-object-store).

3. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If `transaction` is a [read-only
 transaction](#transaction-read-only-transaction),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`ReadOnlyError`](https://webidl.spec.whatwg.org/#readonlyerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. If `store` uses [in-line
 keys](#object-store-in-line-keys) and `key` was given,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

7. If `store` uses [out-of-line
 keys](#object-store-out-of-line-keys) and has no [key
 generator](#key-generator)
 and `key` was not given,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

8. If `key` was given, then:

 1. Let `r` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `key`. Rethrow any exceptions.

 2. If `r` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3. Let `key` be `r`.

9. Let `targetRealm` be a user-agent defined
 [Realm](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm).

10. Let `clone` be a [clone](#clone) of `value` in `targetRealm`
 during `transaction`. Rethrow any exceptions.

 Why create a copy of the value?

 The value is serialized when stored. Treating it as a copy here
 allows other algorithms in this specification to treat it as an
 ECMAScript value, but implementations can optimize this if the
 difference in behavior is not observable.

11. If `store` uses [in-line
 keys](#object-store-in-line-keys), then:

 1. Let `kpk` be the result of [extracting a key from a
 value using a key
 path](#extract-a-key-from-a-value-using-a-key-path) with `clone` and
 `store`'s [key
 path](#object-store-key-path). Rethrow any exceptions.

 2. If `kpk` is invalid,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3. If `kpk` is not failure, let `key` be
 `kpk`.

 4. Otherwise (`kpk` is failure):

 1. If `store` does not have a [key
 generator](#key-generator),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. If [check that a key could be injected into a
 value](#check-that-a-key-could-be-injected-into-a-value) with `clone` and
 `store`'s [key
 path](#object-store-key-path) return false,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

12. Let `operation` be an algorithm to run [store a record
 into an object
 store](#store-a-record-into-an-object-store) with `store`, `clone`,
 `key`, and `no-overwrite flag`.

13. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with `handle` and
 `operation`.

The [`delete(``query``)`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

3. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If `transaction` is a [read-only
 transaction](#transaction-read-only-transaction),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`ReadOnlyError`](https://webidl.spec.whatwg.org/#readonlyerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query` and true. Rethrow any
 exceptions.

7. Let `operation` be an algorithm to run [delete records
 from an object
 store](#delete-records-from-an-object-store) with `store` and `range`.

8. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) identifying the
[records](#object-store-record) to be deleted.

[NOTE:] Unlike other methods which take keys or key ranges,
this method does **not** allow null to be given as key. This is to
reduce the risk that a small bug would clear a whole object store.

The [`clear()`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

3. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If `transaction` is a [read-only
 transaction](#transaction-read-only-transaction),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`ReadOnlyError`](https://webidl.spec.whatwg.org/#readonlyerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. Let `operation` be an algorithm to run [clear an object
 store](#clear-an-object-store) with `store`.

7. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

The following methods throw a
\"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if called when the
[transaction](#transaction-concept) is not
[active](#transaction-active).

`request` = `store` . [`get`](#dom-idbobjectstore-get)(`query`)

: Retrieves the [value](#value) of
 the first
 [record](#object-store-record) matching the given [key](#key) or [key range](#key-range) in `query`.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be the [value](#value), or `undefined` if there was no matching
 [record](#object-store-record).

`request` = `store` . [`getKey`](#dom-idbobjectstore-getkey)(`query`)

: Retrieves the [key](#key) of the
 first [record](#object-store-record) matching the given [key](#key) or [key range](#key-range) in `query`.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be the [key](#key), or `undefined` if there was no matching
 [record](#object-store-record).

`request` = `store` . [`getAll`](#dom-idbobjectstore-getall)(`query` \[, `count`\])\
`request` = `store` . [`getAll`](#dom-idbobjectstore-getall)({`query`, `count`, `direction`})

: Retrieves the [values](#value) of
 the [records](#object-store-record) matching the given [key](#key) or [key range](#key-range) in `query` (up to `count` if
 given). Set the `direction` option to
 \"[`next`](#dom-idbcursordirection-next)\" to retrieve the first `count` values,
 or
 \"[`prev`](#dom-idbcursordirection-prev)\" to return the last `count` values.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be an
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects) of the [values](#value).

`request` = `store` . [`getAllKeys`](#dom-idbobjectstore-getallkeys)(`query` \[, `count`\])\
`request` = `store` . [`getAllKeys`](#dom-idbobjectstore-getallkeys)({`query`, `count`, `direction`})

: Retrieves the [keys](#key) of
 [records](#object-store-record) matching the given [key](#key) or [key range](#key-range) in `query` (up to `count` if
 given). Set the `direction` option to
 \"[`next`](#dom-idbcursordirection-next)\" to retrieve the first `count` keys, or
 \"[`prev`](#dom-idbcursordirection-prev)\" to return the last `count` keys.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be an
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects) of the [keys](#key).

`request` = `store` . [`getAllRecords`](#dom-idbobjectstore-getallrecords)({`query`, `count`, `direction`})

: Retrieves the [keys](#key) and
 [values](#value) of
 [records](#object-store-record).

 The `query` option specifies a [key](#key) or [key range](#key-range) to match. The `count` option limits the
 number of records matched. Set the `direction` option to
 \"[`next`](#dom-idbcursordirection-next)\" to retrieve the first `count` records,
 or
 \"[`prev`](#dom-idbcursordirection-prev)\" to return the last `count` records.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be an
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects), with each member being an
 [`IDBRecord`](#idbrecord).

`request` = `store` . [`count`](#dom-idbobjectstore-count)(`query`)

: Retrieves the number of
 [records](#object-store-record) matching the given [key](#key) or [key range](#key-range) in `query`.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be the count.

The [`get(``query``)`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

3. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query` and true. Rethrow any
 exceptions.

6. Let `operation` be an algorithm to run [retrieve a value
 from an object
 store](#retrieve-a-value-from-an-object-store) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm), `store`, and `range`.

7. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) identifying the
[record](#object-store-record) value to be retrieved. If a range is specified, the
method retrieves the first existing value in that range.

[NOTE:] This method produces the same result if a record with
the given key doesn't exist as when a record exists, but has `undefined`
as value. If you need to tell the two situations apart, you can use
[`openCursor()`](#dom-idbobjectstore-opencursor) with the same key. This will return a cursor with
`undefined` as value if a record exists, or no cursor if no such record
exists.

The [`getKey(``query``)`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

3. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query` and true. Rethrow any
 exceptions.

6. Let `operation` be an algorithm to run [retrieve a key
 from an object
 store](#retrieve-a-key-from-an-object-store) with `store` and `range`.

7. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) identifying the
[record](#object-store-record) key to be retrieved. If a range is specified, the
method retrieves the first existing key in that range.

[`getAll(``queryOrOptions``, ``count``)`]
method steps are:

1. Return the result of [creating a request to retrieve multiple
 items](#create-a-request-to-retrieve-multiple-items) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm),
 [this](https://webidl.spec.whatwg.org/#this), \"value\", `queryOrOptions`, and
 `count` if given. Rethrow any exceptions.

🚧 The
[`IDBGetAllOptions`](#dictdef-idbgetalloptions) argument for
[`getAll()`](#dom-idbobjectstore-getall) is new in [this edition](#revision-history). It is
supported in Chrome 141, and Edge 141. 🚧

[`getAllKeys(``queryOrOptions``, ``count``)`]
method steps are:

1. Return the result of [creating a request to retrieve multiple
 items](#create-a-request-to-retrieve-multiple-items) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm),
 [this](https://webidl.spec.whatwg.org/#this), \"key\", `queryOrOptions`, and
 `count` if given. Rethrow any exceptions.

🚧 The
[`IDBGetAllOptions`](#dictdef-idbgetalloptions) argument for
[`getAllKeys()`](#dom-idbobjectstore-getallkeys) is new in [this edition](#revision-history). It is
supported in Chrome 141, and Edge 141. 🚧

[`getAllRecords(``options``)`] method steps are:

1. Return the result of [creating a request to retrieve multiple
 items](#create-a-request-to-retrieve-multiple-items) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm),
 [this](https://webidl.spec.whatwg.org/#this), \"record\", and `options`. Rethrow any
 exceptions.

🚧 The
[`getAllRecords()`](#dom-idbobjectstore-getallrecords) method is new in [this edition](#revision-history). It
is supported in Chrome 141, and Edge 141. 🚧

The [`count(``query``)`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

3. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query`. Rethrow any exceptions.

6. Let `operation` be an algorithm to run [count the records
 in a
 range](#count-the-records-in-a-range) with `store` and `range`.

7. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) identifying the
[records](#object-store-record) to be counted. If null or not given, an [unbounded key
range](#unbounded-key-range) is used.

The following methods throw a
\"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if called when the
[transaction](#transaction-concept) is not
[active](#transaction-active).

`request` = `store` . [`openCursor`](#dom-idbobjectstore-opencursor)(\[`query` \[, `direction` = \"next\"\]\])

: Opens a [cursor](#cursor) over
 the [records](#object-store-record) matching `query`, ordered by
 `direction`. If `query` is null, all
 [records](#object-store-record) in `store` are matched.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be an
 [`IDBCursorWithValue`](#idbcursorwithvalue) pointing at the first matching
 [record](#object-store-record), or null if there were no matching
 [records](#object-store-record).

`request` = `store` . [`openKeyCursor`](#dom-idbobjectstore-openkeycursor)(\[`query` \[, `direction` = \"next\"\]\])

: Opens a [cursor](#cursor) with
 [key only flag](#cursor-key-only-flag) set to true over the
 [records](#object-store-record) matching `query`, ordered by
 `direction`. If `query` is null, all
 [records](#object-store-record) in `store` are matched.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be an
 [`IDBCursor`](#idbcursor)
 pointing at the first matching
 [record](#object-store-record), or null if there were no matching
 [records](#object-store-record).

[`openCursor(``query``, ``direction``)`] method
steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

3. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query`. Rethrow any exceptions.

6. Let `cursor` be a new [cursor](#cursor) with its [source
 handle](#cursor-source-handle) set to
 [this](https://webidl.spec.whatwg.org/#this), undefined
 [position](#cursor-position),
 [direction](#cursor-direction) set to `direction`, [got value
 flag](#cursor-got-value-flag) set to false, undefined
 [key](#cursor-key) and
 [value](#cursor-value),
 [range](#cursor-range) set
 to `range`, and [key only
 flag](#cursor-key-only-flag) set to false.

7. Let `operation` be an algorithm to run [iterate a
 cursor](#iterate-a-cursor) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm) and `cursor`.

8. Let `request` be the result of running [asynchronously
 execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

9. Set `cursor`'s
 [request](#cursor-request)
 to `request`.

10. Return `request`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) to use as the [cursor](#cursor)'s [range](#cursor-range). If null or not given, an [unbounded key
range](#unbounded-key-range) is used.

[`openKeyCursor(``query``, ``direction``)`]
method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

3. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query`. Rethrow any exceptions.

6. Let `cursor` be a new [cursor](#cursor) with its [source
 handle](#cursor-source-handle) set to
 [this](https://webidl.spec.whatwg.org/#this), undefined
 [position](#cursor-position),
 [direction](#cursor-direction) set to `direction`, [got value
 flag](#cursor-got-value-flag) set to false, undefined
 [key](#cursor-key) and
 [value](#cursor-value),
 [range](#cursor-range) set
 to `range`, and [key only
 flag](#cursor-key-only-flag) set to true.

7. Let `operation` be an algorithm to run [iterate a
 cursor](#iterate-a-cursor) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm) and `cursor`.

8. Let `request` be the result of running [asynchronously
 execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

9. Set `cursor`'s
 [request](#cursor-request)
 to `request`.

10. Return `request`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) to use as the [cursor](#cursor)'s [range](#cursor-range). If null or not given, an [unbounded key
range](#unbounded-key-range) is used.

`index` = `store` . index(`name`)

: Returns an [`IDBIndex`](#idbindex) for the
 [index](#index-concept)
 named `name` in `store`.

`index` = `store` . [`createIndex`](#dom-idbobjectstore-createindex)(`name`, `keyPath` \[, `options`\])

: Creates a new [index](#index-concept) in `store` with the given
 `name`, `keyPath` and `options` and
 returns a new [`IDBIndex`](#idbindex). If the `keyPath` and
 `options` define constraints that cannot be satisfied
 with the data already in `store` the [upgrade
 transaction](#upgrade-transaction) will
 [abort](#transaction-abort) with a
 \"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 Throws an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if not called within an [upgrade
 transaction](#upgrade-transaction).

`store` . [`deleteIndex`](#dom-idbobjectstore-deleteindex)(`name`)

: Deletes the [index](#index-concept) in `store` with the given
 `name`.

 Throws an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if not called within an [upgrade
 transaction](#upgrade-transaction).

[`createIndex(``name``, ``keyPath``, ``options``)`]
method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

3. If `transaction` is not an [upgrade
 transaction](#upgrade-transaction),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. If an [index](#index-concept) [named](#index-name) `name` already exists in
 `store`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

7. If `keyPath` is not a [valid key
 path](#valid-key-path),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

8. Let `unique` be `options`'s
 [`unique`](#dom-idbindexparameters-unique) member.

9. Let `multiEntry` be `options`'s
 [`multiEntry`](#dom-idbindexparameters-multientry) member.

10. If `keyPath` is a sequence and `multiEntry` is
 true,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

11. Let `index` be a new
 [index](#index-concept) in
 `store`. Set `index`'s
 [name](#index-name) to
 `name`, [key
 path](#index-key-path) to
 `keyPath`, [unique
 flag](#index-unique-flag) to `unique`, and [multiEntry
 flag](#index-multientry-flag) to `multiEntry`.

12. Add `index` to
 [this](https://webidl.spec.whatwg.org/#this)'s [index
 set](#object-store-handle-index-set).

13. Return a new [index handle](#index-handle) associated with `index` and
 [this](https://webidl.spec.whatwg.org/#this).

This method creates and returns a new
[index](#index-concept) with
the given name in the [object
store](#object-store). Note
that this method must only be called from within an [upgrade
transaction](#upgrade-transaction).

The index that is requested to be created can contain constraints on the
data allowed in the index's
[referenced](#index-referenced) object store, such as requiring uniqueness of the
values referenced by the index's [key
path](#index-key-path). If the
[referenced](#index-referenced) object store already contains data which violates these
constraints, this must not cause the implementation of
[`createIndex()`](#dom-idbobjectstore-createindex) to throw an exception or affect what it returns. The
implementation must still create and return an
[`IDBIndex`](#idbindex)
object, and the implementation must [queue a database
task](#queue-a-database-task) to abort the [upgrade
transaction](#upgrade-transaction) which was used for the
[`createIndex()`](#dom-idbobjectstore-createindex) call.

This method synchronously modifies the
[`indexNames`](#dom-idbobjectstore-indexnames) property on the
[`IDBObjectStore`](#idbobjectstore) instance on which it was called. Although this method
does not return an
[`IDBRequest`](#idbrequest)
object, the index creation itself is processed as an asynchronous
request within the [upgrade
transaction](#upgrade-transaction).

In some implementations it is possible for the implementation to
asynchronously run into problems creating the index after the
createIndex method has returned. For example in implementations where
metadata about the newly created index is queued up to be inserted into
the database asynchronously, or where the implementation might need to
ask the user for permission for quota reasons. Such implementations must
still create and return an
[`IDBIndex`](#idbindex)
object, and once the implementation determines that creating the index
has failed, it must run the steps to [abort a
transaction](#abort-a-transaction) using an appropriate error. For example if creating the
[index](#index-concept) failed
due to quota reasons, a
[`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror) must be used as error and if the index can't be created
due to [unique flag](#index-unique-flag) constraints, a
\"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) must be used as error.

The asynchronous creation of indexes is observable in the following
example:

```
const request1 = objectStore.put({name: "betty"}, 1);
const request2 = objectStore.put({name: "betty"}, 2);
const index = objectStore.createIndex("by_name", "name", {unique: true});
```

At the point where
[`createIndex()`](#dom-idbobjectstore-createindex) called, neither of the
[requests](#request) have executed.
When the second request executes, a duplicate name is created. Since the
index creation is considered an asynchronous
[request](#request), the index's
[uniqueness constraint](#index-unique-flag) does not cause the second
[request](#request) to fail.
Instead, the
[transaction](#transaction-concept) will be
[aborted](#transaction-abort) when the index is created and the constraint fails.

The [`index(``name``)`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

3. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is
 [finished](#transaction-finished), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `index` be the
 [index](#index-concept)
 [named](#index-name)
 `name` in
 [this](https://webidl.spec.whatwg.org/#this)'s [index
 set](#object-store-handle-index-set) if one exists, or
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) otherwise.

6. Return an [index handle](#index-handle) associated with `index` and
 [this](https://webidl.spec.whatwg.org/#this).

[NOTE:] Each call to this method on the same
[`IDBObjectStore`](#idbobjectstore) instance with the same name returns the same
[`IDBIndex`](#idbindex)
instance.

[NOTE:] The returned
[`IDBIndex`](#idbindex)
instance is specific to this
[`IDBObjectStore`](#idbobjectstore) instance. If this method is called on a different
[`IDBObjectStore`](#idbobjectstore) instance with the same name, a different
[`IDBIndex`](#idbindex)
instance is returned.

The [`deleteIndex(``name``)`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#object-store-handle-transaction).

2. Let `store` be
 [this](https://webidl.spec.whatwg.org/#this)'s [object
 store](#object-store-handle-object-store).

3. If `transaction` is not an [upgrade
 transaction](#upgrade-transaction),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `store` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. Let `index` be the
 [index](#index-concept)
 [named](#index-name)
 `name` in `store` if one exists, or
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) otherwise.

7. Remove `index` from
 [this](https://webidl.spec.whatwg.org/#this)'s [index
 set](#object-store-handle-index-set).

8. Destroy `index`.

This method destroys the
[index](#index-concept) with
the given name in the [object
store](#object-store). Note
that this method must only be called from within an [upgrade
transaction](#upgrade-transaction).

This method synchronously modifies the
[`indexNames`](#dom-idbobjectstore-indexnames) property on the
[`IDBObjectStore`](#idbobjectstore) instance on which it was called. Although this method
does not return an
[`IDBRequest`](#idbrequest)
object, the index destruction itself is processed as an asynchronous
request within the [upgrade
transaction](#upgrade-transaction).

### 4.6. The [`IDBIndex` interface]
The [`IDBIndex`](#idbindex)
interface represents an [index
handle](#index-handle).

```
[Exposed=(Window,Worker)]
interface IDBIndex {
 attribute DOMString name;
 [SameObject] readonly attribute IDBObjectStore objectStore;
 readonly attribute any keyPath;
 readonly attribute boolean multiEntry;
 readonly attribute boolean unique;

 [NewObject] IDBRequest get(any query);
 [NewObject] IDBRequest getKey(any query);
 [NewObject] IDBRequest getAll(optional any queryOrOptions,
 optional [EnforceRange] unsigned long count);
 [NewObject] IDBRequest getAllKeys(optional any queryOrOptions,
 optional [EnforceRange] unsigned long count);
 [NewObject] IDBRequest getAllRecords(optional IDBGetAllOptions options = );
 [NewObject] IDBRequest count(optional any query);

 [NewObject] IDBRequest openCursor(optional any query,
 optional IDBCursorDirection direction = "next");
 [NewObject] IDBRequest openKeyCursor(optional any query,
 optional IDBCursorDirection direction = "next");
};
```

`index` . [`name`](#dom-idbindex-name)

: Returns the [name](#index-name) of the index.

`index` . [`name`](#dom-idbindex-name) = `newName`

: Updates the [name](#index-name) of the store to `newName`.

 Throws an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if not called within an [upgrade
 transaction](#upgrade-transaction).

`index` . [`objectStore`](#dom-idbindex-objectstore)

: Returns the
 [`IDBObjectStore`](#idbobjectstore) the index belongs to.

`index` . keyPath

: Returns the [key path](#key-path) of the index.

`index` . multiEntry

: Returns true if the index's [multiEntry
 flag](#index-multientry-flag) is true.

`index` . unique

: Returns true if the index's [unique
 flag](#index-unique-flag) is true.

The [`name`] getter steps are to
return [this](https://webidl.spec.whatwg.org/#this)'s [name](#index-name).

Is this the same as the [index](#index-concept)'s [name](#index-name)?

As long as the
[transaction](#transaction-concept) has not
[finished](#transaction-finished), this is the same as the associated
[index](#index-concept)'s
[name](#index-name). But once the
[transaction](#transaction-concept) has
[finished](#transaction-finished), this attribute will not reflect changes made with a
later [upgrade
transaction](#upgrade-transaction).

The [`name`](#dom-idbindex-name) setter steps are:

1. Let `name` be [the given
 value](https://webidl.spec.whatwg.org/#the-given-value).

2. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#index-handle-transaction).

3. Let `index` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [index](#index-handle-index).

4. If `transaction` is not an [upgrade
 transaction](#upgrade-transaction),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. If `index` or `index`'s [object
 store](#object-store) has
 been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

7. If `index`'s [name](#index-name) is equal to `name`, terminate these
 steps.

8. If an [index](#index-concept) [named](#index-name) `name` already exists in
 `index`'s [object
 store](#object-store),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

9. Set `index`'s [name](#index-name) to `name`.

10. Set [this](https://webidl.spec.whatwg.org/#this)'s
 [name](#index-handle-name) to `name`.

The [`objectStore`] getter
steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [object store
handle](#index-handle-object-store-handle).

The [`keyPath`] getter steps are to
return [this](https://webidl.spec.whatwg.org/#this)'s
[index](#index-handle-index)'s [key
path](#object-store-key-path). The [key path](#key-path) is converted as a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) (if a string) or a
[`sequence`](https://webidl.spec.whatwg.org/#idl-sequence)`<`[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)`>` (if a list of strings), per
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard").

[NOTE:] The returned value is not the same instance that was
used when the [index](#index-concept) was created. However, if this attribute returns an
object (specifically an
[`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects)), it returns the same object instance every time it is
inspected. Changing the properties of the object has no effect on the
[index](#index-concept).

The [`multiEntry`] getter steps are to
return [this](https://webidl.spec.whatwg.org/#this)'s
[index](#index-handle-index)'s [multiEntry
flag](#index-multientry-flag).

The [`unique`] getter steps are to
return [this](https://webidl.spec.whatwg.org/#this)'s
[index](#index-handle-index)'s [unique
flag](#index-unique-flag).

The following methods throw an
\"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if called when the
[transaction](#transaction-concept) is not
[active](#transaction-active).

`request` = `index` . [`get`](#dom-idbindex-get)(`query`)

: Retrieves the [value](#value) of
 the first
 [record](#object-store-record) matching the given [key](#key) or [key range](#key-range) in `query`.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be the [value](#value), or `undefined` if there was no matching
 [record](#object-store-record).

`request` = `index` . [`getKey`](#dom-idbindex-getkey)(`query`)

: Retrieves the [key](#key) of the
 first [record](#object-store-record) matching the given [key](#key) or [key range](#key-range) in `query`.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be the [key](#key), or `undefined` if there was no matching
 [record](#object-store-record).

`request` = `index` . [`getAll`](#dom-idbindex-getall)(`query` \[, `count`\])\
`request` = `index` . [`getAll`](#dom-idbindex-getall)({`query`, `count`, `direction`})

: Retrieves the [values](#value) of
 the [records](#object-store-record) matching the given [key](#key) or [key range](#key-range) in `query` (up to `count` if
 given). Set the `direction` option to
 \"[`next`](#dom-idbcursordirection-next)\" to retrieve the first `count` values,
 \"[`prev`](#dom-idbcursordirection-prev)\" to return the last `count` values. Set
 the `direction` option to
 \"[`nextunique`](#dom-idbcursordirection-nextunique)\" or
 \"[`prevunique`](#dom-idbcursordirection-prevunique)\" to exclude records with duplicate index keys
 after retrieving the first record with the duplicate index key.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be an
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects) of the [values](#value).

`request` = `index` . [`getAllKeys`](#dom-idbindex-getallkeys)(`query` \[, `count`\])\
`request` = `index` . [`getAllKeys`](#dom-idbindex-getallkeys)({`query`, `count`, `direction`})

: Retrieves the [keys](#key) of
 [records](#object-store-record) matching the given [key](#key) or [key range](#key-range) in `query` (up to `count` if
 given). Set the `direction` option to
 \"[`next`](#dom-idbcursordirection-next)\" to retrieve the first `count` keys,
 \"[`prev`](#dom-idbcursordirection-prev)\" to return the last `count` keys. Set
 the `direction` option to
 \"[`nextunique`](#dom-idbcursordirection-nextunique)\" or
 \"[`prevunique`](#dom-idbcursordirection-prevunique)\" to exclude records with duplicate index keys
 after retrieving the first record with the duplicate index key.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be an
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects) of the [keys](#key).

`request` = `index` . [`getAllRecords`](#dom-idbindex-getallrecords)({`query`, `count`, `direction`})

: Retrieves the [keys](#key),
 [values](#value), and index
 [keys](#key) of
 [records](#object-store-record).

 The `query` option specifies a [key](#key) or [key range](#key-range) to match. The `count` option limits the
 number of records matched. Set the `direction` option to
 \"[`next`](#dom-idbcursordirection-next)\" to retrieve the first `count` records,
 \"[`prev`](#dom-idbcursordirection-prev)\" to return the last `count` records.
 Set the `direction` option to
 \"[`nextunique`](#dom-idbcursordirection-nextunique)\" or
 \"[`prevunique`](#dom-idbcursordirection-prevunique)\" to exclude records with duplicate index keys
 after retrieving the first record with the duplicate index key.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be an
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects), with each member being an
 [`IDBRecord`](#idbrecord). Use the
 [`IDBRecord’s key`](#dom-idbrecord-key) to get the record's index
 [key](#key). Use the
 [`IDBRecord’s primaryKey`](#dom-idbrecord-primarykey) to get the record's [key](#key).

`request` = `index` . [`count`](#dom-idbindex-count)(`query`)

: Retrieves the number of
 [records](#object-store-record) matching the given [key](#key) or [key range](#key-range) in `query`.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be the count.

The [`get(``query``)`] method steps
are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#index-handle-transaction).

2. Let `index` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [index](#index-handle-index).

3. If `index` or `index`'s [object
 store](#object-store) has
 been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query` and true. Rethrow any
 exceptions.

6. Let `operation` be an algorithm to run [retrieve a
 referenced value from an
 index](#retrieve-a-referenced-value-from-an-index) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm), `index`, and `range`.

7. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) identifying the [referenced
value](#index-referenced-value) to be retrieved. If a range is specified, the method
retrieves the first existing record in that range.

[NOTE:] This method produces the same result if a record with
the given key doesn't exist as when a record exists, but has `undefined`
as value. If you need to tell the two situations apart, you can use
[`openCursor()`](#dom-idbindex-opencursor) with the same key. This will return a cursor with
`undefined` as value if a record exists, or no cursor if no such record
exists.

The [`getKey(``query``)`]
method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#index-handle-transaction).

2. Let `index` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [index](#index-handle-index).

3. If `index` or `index`'s [object
 store](#object-store) has
 been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query` and true. Rethrow any
 exceptions.

6. Let `operation` be an algorithm to run [retrieve a value
 from an
 index](#retrieve-a-value-from-an-index) with `index` and `range`.

7. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) identifying the
[record](#object-store-record) key to be retrieved. If a range is specified, the
method retrieves the first existing key in that range.

[`getAll(``queryOrOptions``, ``count``)`]
method steps are:

1. Return the result of [creating a request to retrieve multiple
 items](#create-a-request-to-retrieve-multiple-items) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm),
 [this](https://webidl.spec.whatwg.org/#this), \"value\", `queryOrOptions`, and
 `count` if given. Rethrow any exceptions.

🚧 The
[`IDBGetAllOptions`](#dictdef-idbgetalloptions) argument for
[`getAll()`](#dom-idbindex-getall) is new in [this edition](#revision-history). It is
supported in Chrome 141, and Edge 141. 🚧

[`getAllKeys(``queryOrOptions``, ``count``)`]
method steps are:

1. Return the result of [creating a request to retrieve multiple
 items](#create-a-request-to-retrieve-multiple-items) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm),
 [this](https://webidl.spec.whatwg.org/#this), \"key\", `queryOrOptions`, and
 `count` if given. Rethrow any exceptions.

🚧 The
[`IDBGetAllOptions`](#dictdef-idbgetalloptions) argument for
[`getAllKeys()`](#dom-idbindex-getallkeys) is new in [this edition](#revision-history). It is
supported in Chrome 141, and Edge 141. 🚧

[`getAllRecords(``options``)`] method steps are:

1. Return the result of [creating a request to retrieve multiple
 items](#create-a-request-to-retrieve-multiple-items) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm),
 [this](https://webidl.spec.whatwg.org/#this), \"record\", and `options`. Rethrow any
 exceptions.

🚧 The
[`getAllRecords()`](#dom-idbindex-getallrecords) method is new in [this edition](#revision-history). It
is supported in Chrome 141, and Edge 141. 🚧

The [`count(``query``)`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#index-handle-transaction).

2. Let `index` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [index](#index-handle-index).

3. If `index` or `index`'s [object
 store](#object-store) has
 been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query`. Rethrow any exceptions.

6. Let `operation` be an algorithm to run [count the records
 in a
 range](#count-the-records-in-a-range) with `index` and `range`.

7. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) identifying the
[records](#index-records) to be
counted. If null or not given, an [unbounded key
range](#unbounded-key-range) is used.

The following methods throw an
\"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if called when the
[transaction](#transaction-concept) is not
[active](#transaction-active).

`request` = `index` . [`openCursor`](#dom-idbindex-opencursor)(\[`query` \[, `direction` = \"next\"\]\])

: Opens a [cursor](#cursor) over
 the [records](#object-store-record) matching `query`, ordered by
 `direction`. If `query` is null, all
 [records](#object-store-record) in `index` are matched.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be an
 [`IDBCursorWithValue`](#idbcursorwithvalue), or null if there were no matching
 [records](#object-store-record).

`request` = `index` . [`openKeyCursor`](#dom-idbindex-openkeycursor)(\[`query` \[, `direction` = \"next\"\]\])

: Opens a [cursor](#cursor) with
 [key only
 flag](#cursor-key-only-flag) set to true over the
 [records](#object-store-record) matching `query`, ordered by
 `direction`. If `query` is null, all
 [records](#object-store-record) in `index` are matched.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be an
 [`IDBCursor`](#idbcursor), or null if there were no matching
 [records](#object-store-record).

[`openCursor(``query``, ``direction``)`] method
steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#index-handle-transaction).

2. Let `index` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [index](#index-handle-index).

3. If `index` or `index`'s [object
 store](#object-store) has
 been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query`. Rethrow any exceptions.

6. Let `cursor` be a new [cursor](#cursor) with its [source
 handle](#cursor-source-handle) set to
 [this](https://webidl.spec.whatwg.org/#this), undefined
 [position](#cursor-position),
 [direction](#cursor-direction) set to `direction`, [got value
 flag](#cursor-got-value-flag) set to false, undefined
 [key](#cursor-key) and
 [value](#cursor-value),
 [range](#cursor-range) set
 to `range`, and [key only
 flag](#cursor-key-only-flag) set to false.

7. Let `operation` be an algorithm to run [iterate a
 cursor](#iterate-a-cursor) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm) and `cursor`.

8. Let `request` be the result of running [asynchronously
 execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

9. Set `cursor`'s
 [request](#cursor-request)
 to `request`.

10. Return `request`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) to use as the [cursor](#cursor)'s [range](#cursor-range). If null or not given, an [unbounded key
range](#unbounded-key-range) is used.

[`openKeyCursor(``query``, ``direction``)`]
method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#index-handle-transaction).

2. Let `index` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [index](#index-handle-index).

3. If `index` or `index`'s [object
 store](#object-store) has
 been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. Let `range` be the result of [converting a value to a key
 range](#convert-a-value-to-a-key-range) with `query`. Rethrow any exceptions.

6. Let `cursor` be a new [cursor](#cursor) with its [source
 handle](#cursor-source-handle) set to
 [this](https://webidl.spec.whatwg.org/#this), undefined
 [position](#cursor-position),
 [direction](#cursor-direction) set to `direction`, [got value
 flag](#cursor-got-value-flag) set to false, undefined
 [key](#cursor-key) and
 [value](#cursor-value),
 [range](#cursor-range) set
 to `range`, and [key only
 flag](#cursor-key-only-flag) set to true.

7. Let `operation` be an algorithm to run [iterate a
 cursor](#iterate-a-cursor) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm) and `cursor`.

8. Let `request` be the result of running [asynchronously
 execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

9. Set `cursor`'s
 [request](#cursor-request)
 to `request`.

10. Return `request`.

[NOTE:] The `query` parameter can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) to use as the [cursor](#cursor)'s [range](#cursor-range). If null or not given, an [unbounded key
range](#unbounded-key-range) is used.

### 4.7. The [`IDBKeyRange` interface]
The [`IDBKeyRange`](#idbkeyrange) interface represents a [key
range](#key-range).

```
[Exposed=(Window,Worker)]
interface IDBKeyRange {
 readonly attribute any lower;
 readonly attribute any upper;
 readonly attribute boolean lowerOpen;
 readonly attribute boolean upperOpen;

 // Static construction methods:
 [NewObject] static IDBKeyRange only(any value);
 [NewObject] static IDBKeyRange lowerBound(any lower, optional boolean open = false);
 [NewObject] static IDBKeyRange upperBound(any upper, optional boolean open = false);
 [NewObject] static IDBKeyRange bound(any lower,
 any upper,
 optional boolean lowerOpen = false,
 optional boolean upperOpen = false);

 boolean includes(any key);
};
```

`range` . [`lower`](#dom-idbkeyrange-lower)

: Returns the range's [lower
 bound](#key-range-lower-bound), or `undefined` if none.

`range` . [`upper`](#dom-idbkeyrange-upper)

: Returns the range's [upper
 bound](#key-range-upper-bound), or `undefined` if none.

`range` . [`lowerOpen`](#dom-idbkeyrange-loweropen)

: Returns the range's [lower open
 flag](#key-range-lower-open-flag).

`range` . [`upperOpen`](#dom-idbkeyrange-upperopen)

: Returns the range's [upper open
 flag](#key-range-upper-open-flag).

The [`lower`] getter steps are
to return the result of [converting a key to a
value](#convert-a-key-to-a-value) with
[this](https://webidl.spec.whatwg.org/#this)'s [lower
bound](#key-range-lower-bound) if it is not null, or undefined otherwise.

The [`upper`] getter steps are
to return the result of [converting a key to a
value](#convert-a-key-to-a-value) with
[this](https://webidl.spec.whatwg.org/#this)'s [upper
bound](#key-range-upper-bound) if it is not null, or undefined otherwise.

The [`lowerOpen`] getter steps are
to return [this](https://webidl.spec.whatwg.org/#this)'s [lower open
flag](#key-range-lower-open-flag).

The [`upperOpen`] getter steps are
to return [this](https://webidl.spec.whatwg.org/#this)'s [upper open
flag](#key-range-upper-open-flag).

`range` = [`IDBKeyRange`](#idbkeyrange) . [`only`](#dom-idbkeyrange-only)(`key`)

: Returns a new
 [`IDBKeyRange`](#idbkeyrange) spanning only `key`.

`range` = [`IDBKeyRange`](#idbkeyrange) . [`lowerBound`](#dom-idbkeyrange-lowerbound)(`key` \[, `open` = false\])

: Returns a new
 [`IDBKeyRange`](#idbkeyrange) starting at `key` with no upper bound.
 If `open` is true, `key` is not included in
 the range.

`range` = [`IDBKeyRange`](#idbkeyrange) . [`upperBound`](#dom-idbkeyrange-upperbound)(`key` \[, `open` = false\])

: Returns a new
 [`IDBKeyRange`](#idbkeyrange) with no lower bound and ending at `key`.
 If `open` is true, `key` is not included in
 the range.

`range` = [`IDBKeyRange`](#idbkeyrange) . [`bound`](#dom-idbkeyrange-bound)(`lower`, `upper` \[, `lowerOpen` = false \[, `upperOpen` = false\]\])

: Returns a new
 [`IDBKeyRange`](#idbkeyrange) spanning from `lower` to
 `upper`. If `lowerOpen` is true,
 `lower` is not included in the range. If
 `upperOpen` is true, `upper` is not included
 in the range.

The [`only(``value``)`] method steps are:

1. Let `key` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `value`. Rethrow any exceptions.

2. If `key` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Create and return a new [key range](#key-range) [containing
 only](#containing-only)
 `key`.

[`lowerBound(``lower``, ``open``)`] method steps
are:

1. Let `lowerKey` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `lower`. Rethrow any exceptions.

2. If `lowerKey` is invalid,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Create and return a new [key range](#key-range) with [lower
 bound](#key-range-lower-bound) set to `lowerKey`, [lower open
 flag](#key-range-lower-open-flag) set to `open`, [upper
 bound](#key-range-upper-bound) set to null, and [upper open
 flag](#key-range-upper-open-flag) set to true.

[`upperBound(``upper``, ``open``)`] method steps
are:

1. Let `upperKey` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `upper`. Rethrow any exceptions.

2. If `upperKey` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Create and return a new [key range](#key-range) with [lower
 bound](#key-range-lower-bound) set to null, [lower open
 flag](#key-range-lower-open-flag) set to true, [upper
 bound](#key-range-upper-bound) set to `upperKey`, and [upper open
 flag](#key-range-upper-open-flag) set to `open`.

[`bound(``lower``, ``upper``, ``lowerOpen``, ``upperOpen``)`]
method steps are:

1. Let `lowerKey` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `lower`. Rethrow any exceptions.

2. If `lowerKey` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Let `upperKey` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `upper`. Rethrow any exceptions.

4. If `upperKey` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If `lowerKey` is [greater
 than](#greater-than)
 `upperKey`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. Create and return a new [key range](#key-range) with [lower
 bound](#key-range-lower-bound) set to `lowerKey`, [lower open
 flag](#key-range-lower-open-flag) set to `lowerOpen`, [upper
 bound](#key-range-upper-bound) set to `upperKey` and [upper open
 flag](#key-range-upper-open-flag) set to `upperOpen`.

`range` . [`includes`](#dom-idbkeyrange-includes)(`key`)

: Returns true if `key` is included in the range, and false
 otherwise.

The [`includes(``key``)`] method steps are:

1. Let `k` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `key`. Rethrow any exceptions.

2. If `k` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Return true if `k` is [in](#in) this range, and false otherwise.

### 4.8. The [`IDBRecord` interface]
The [`IDBRecord`](#idbrecord)
interface represents a [record
snapshot](#record-snapshot).

```
[Exposed=(Window,Worker)]
interface IDBRecord {
 readonly attribute any key;
 readonly attribute any primaryKey;
 readonly attribute any value;
};
```

`record` . [`key`](#dom-idbrecord-key)

: Returns the record's [key](#key).

`record` . [`primaryKey`](#dom-idbrecord-primarykey)

: If the record was retrieved from an
 [index](#index-concept),
 returns the key of the record in the index's [referenced object
 store](#index-referenced).

 If the record was retrieved from an [object
 store](#object-store),
 returns the record's [key](#key),
 which is the same key as
 `record`.[`key`](#dom-idbrecord-key).

`record` . [`value`](#dom-idbrecord-value)

: Returns the record's [value](#value).

The [`key`] getter steps are to
return the result of [converting a key to a
value](#convert-a-key-to-a-value) with
[this](https://webidl.spec.whatwg.org/#this)'s
[key](#record-snapshot-key).

The [`primaryKey`] getter steps are to
return the result of [converting a key to a
value](#convert-a-key-to-a-value) with
[this](https://webidl.spec.whatwg.org/#this)'s [primary
key](#record-snapshot-primary-key).

The [`value`] getter steps are to
return [this](https://webidl.spec.whatwg.org/#this)'s
[value](#record-snapshot-value).

### 4.9. The [`IDBCursor` interface]
[Cursor](#cursor) objects implement
the [`IDBCursor`](#idbcursor)
interface. There is only ever one
[`IDBCursor`](#idbcursor)
instance representing a given [cursor](#cursor). There is no limit on how many cursors can be used at
the same time.

```
[Exposed=(Window,Worker)]
interface IDBCursor {
 readonly attribute (IDBObjectStore or IDBIndex) source;
 readonly attribute IDBCursorDirection direction;
 readonly attribute any key;
 readonly attribute any primaryKey;
 [SameObject] readonly attribute IDBRequest request;

 undefined advance([EnforceRange] unsigned long count);
 undefined continue(optional any key);
 undefined continuePrimaryKey(any key, any primaryKey);

 [NewObject] IDBRequest update(any value);
 [NewObject] IDBRequest delete();
};

enum IDBCursorDirection {
 "next",
 "nextunique",
 "prev",
 "prevunique"
};
```

`cursor` . [`source`](#dom-idbcursor-source)

: Returns the
 [`IDBObjectStore`](#idbobjectstore) or
 [`IDBIndex`](#idbindex)
 the cursor was opened from.

`cursor` . [`direction`](#dom-idbcursor-direction)

: Returns the
 [direction](#cursor-direction)
 (\"[`next`](#dom-idbcursordirection-next)\",
 \"[`nextunique`](#dom-idbcursordirection-nextunique)\",
 \"[`prev`](#dom-idbcursordirection-prev)\" or
 \"[`prevunique`](#dom-idbcursordirection-prevunique)\") of the cursor.

`cursor` . [`key`](#dom-idbcursor-key)

: Returns the [key](#cursor-key)
 of the cursor. Throws a
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if the cursor is advancing or is finished.

`cursor` . [`primaryKey`](#dom-idbcursor-primarykey)

: Returns the [effective
 key](#cursor-effective-key) of the cursor. Throws a
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if the cursor is advancing or is finished.

`cursor` . [`request`](#dom-idbcursor-request)

: Returns the [request](#cursor-request) that was used to obtain this cursor.

The [`source`] getter steps are to
return [this](https://webidl.spec.whatwg.org/#this)'s [source
handle](#cursor-source-handle).

[NOTE:] The
[`source`](#dom-idbcursor-source) attribute never returns null or throws an exception,
even if the cursor is currently being iterated, has iterated past its
end, or its
[transaction](#transaction-concept) is not
[active](#transaction-active).

The [`direction`] getter steps are to
return [this](https://webidl.spec.whatwg.org/#this)'s
[direction](#cursor-direction).

The [`key`] getter steps are to
return the result of [converting a key to a
value](#convert-a-key-to-a-value) with the cursor's current
[key](#cursor-key).

[NOTE:] If
[`key`](#dom-idbcursor-key) returns an object (e.g. a
[`Date`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-date-objects) or
[`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects)), it returns the same object instance every time it is
inspected, until the cursor's [key](#cursor-key) is changed. This means that if the object is modified,
those modifications will be seen by anyone inspecting the value of the
cursor. However modifying such an object does not modify the contents of
the database.

The [`primaryKey`] getter steps are to
return the result of [converting a key to a
value](#convert-a-key-to-a-value) with the cursor's current [effective
key](#cursor-effective-key).

[NOTE:] If
[`primaryKey`](#dom-idbcursor-primarykey) returns an object (e.g. a
[`Date`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-date-objects) or
[`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects)), it returns the same object instance every time it is
inspected, until the cursor's [effective
key](#cursor-effective-key) is changed. This means that if the object is modified,
those modifications will be seen by anyone inspecting the value of the
cursor. However modifying such an object does not modify the contents of
the database.

The [`request`] getter steps are to
return [this](https://webidl.spec.whatwg.org/#this)'s [request](#cursor-request).

🚧 The
[`request`](#dom-idbcursor-request) attribute is new in this edition. It is supported in
Chrome 76, Edge 79, Firefox 77, and Safari 15. 🚧

The following methods advance a [cursor](#cursor). Once the cursor has advanced, a
[`success`](#eventdef-idbrequest-success) event will be fired at the same
[`IDBRequest`](#idbrequest)
returned when the cursor was opened. The
[`result`](#dom-idbrequest-result) will be the same cursor if a
[record](#object-store-record) was in range, or `undefined` otherwise.

If called while the cursor is already advancing, an
\"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) will be thrown.

The following methods throw a
\"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if called when the
[transaction](#transaction-concept) is not
[active](#transaction-active).

`cursor` . [`advance`](#dom-idbcursor-advance)(`count`)

: Advances the cursor through the next `count`
 [records](#object-store-record) in range.

`cursor` . [`continue`](#dom-idbcursor-continue)()

: Advances the cursor to the next
 [record](#object-store-record) in range.

`cursor` . [`continue`](#dom-idbcursor-continue)(`key`)

: Advances the cursor to the next
 [record](#object-store-record) in range matching or after `key`.

`cursor` . [`continuePrimaryKey`](#dom-idbcursor-continueprimarykey)(`key`, `primaryKey`)

: Advances the cursor to the next
 [record](#object-store-record) in range matching or after `key` and
 `primaryKey`. Throws an
 \"[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if the
 [source](#cursor-source)
 is not an [index](#index-concept).

The [`advance(``count``)`]
method steps are:

1. If `count` is 0 (zero),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#cursor-transaction).

3. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If [this](https://webidl.spec.whatwg.org/#this)'s [source](#cursor-source) or [effective object
 store](#cursor-effective-object-store) has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If [this](https://webidl.spec.whatwg.org/#this)'s [got value
 flag](#cursor-got-value-flag) is false, indicating that the cursor is being
 iterated or has iterated past its end,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. Set [this](https://webidl.spec.whatwg.org/#this)'s [got value
 flag](#cursor-got-value-flag) to false.

7. Let `request` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [request](#cursor-request).

8. Set `request`'s [processed
 flag](#request-processed-flag) to false.

9. Set `request`'s [done
 flag](#request-done-flag) to false.

10. Let `operation` be an algorithm to run [iterate a
 cursor](#iterate-a-cursor) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm),
 [this](https://webidl.spec.whatwg.org/#this), and `count`.

11. Run [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this)'s [source
 handle](#cursor-source-handle), `operation`, and `request`.

[NOTE:] Calling this method more than once before new cursor
data has been loaded - for example, calling
[`advance()`](#dom-idbcursor-advance) twice from the same onsuccess handler - results in an
\"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) being thrown on the second call because the cursor's
[got value flag](#cursor-got-value-flag) has been set to false.

The [`continue(``key``)`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#cursor-transaction).

2. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. If [this](https://webidl.spec.whatwg.org/#this)'s [source](#cursor-source) or [effective object
 store](#cursor-effective-object-store) has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If [this](https://webidl.spec.whatwg.org/#this)'s [got value
 flag](#cursor-got-value-flag) is false, indicating that the cursor is being
 iterated or has iterated past its end,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If `key` is given, then:

 1. Let `r` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `key`. Rethrow any exceptions.

 2. If `r` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3. Let `key` be `r`.

 4. If `key` is [less
 than](#less-than) or [equal
 to](#equal-to)
 [this](https://webidl.spec.whatwg.org/#this)'s
 [position](#cursor-position) and
 [this](https://webidl.spec.whatwg.org/#this)'s
 [direction](#cursor-direction) is
 \"[`next`](#dom-idbcursordirection-next)\" or
 \"[`nextunique`](#dom-idbcursordirection-nextunique)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 5. If `key` is [greater
 than](#greater-than) or
 [equal to](#equal-to)
 [this](https://webidl.spec.whatwg.org/#this)'s
 [position](#cursor-position) and
 [this](https://webidl.spec.whatwg.org/#this)'s
 [direction](#cursor-direction) is
 \"[`prev`](#dom-idbcursordirection-prev)\" or
 \"[`prevunique`](#dom-idbcursordirection-prevunique)\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. Set [this](https://webidl.spec.whatwg.org/#this)'s [got value
 flag](#cursor-got-value-flag) to false.

7. Let `request` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [request](#cursor-request).

8. Set `request`'s [processed
 flag](#request-processed-flag) to false.

9. Set `request`'s [done
 flag](#request-done-flag) to false.

10. Let `operation` be an algorithm to run [iterate a
 cursor](#iterate-a-cursor) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm),
 [this](https://webidl.spec.whatwg.org/#this), and `key` (if given).

11. Run [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this)'s [source
 handle](#cursor-source-handle), `operation`, and `request`.

[NOTE:] Calling this method more than once before new cursor
data has been loaded - for example, calling
[`continue()`](#dom-idbcursor-continue) twice from the same onsuccess handler - results in an
\"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) being thrown on the second call because the cursor's
[got value flag](#cursor-got-value-flag) has been set to false.

[`continuePrimaryKey(``key``, ``primaryKey``)`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#cursor-transaction).

2. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. If [this](https://webidl.spec.whatwg.org/#this)'s [source](#cursor-source) or [effective object
 store](#cursor-effective-object-store) has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If [this](https://webidl.spec.whatwg.org/#this)'s [source](#cursor-source) is not an
 [index](#index-concept)
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If [this](https://webidl.spec.whatwg.org/#this)'s
 [direction](#cursor-direction) is not
 \"[`next`](#dom-idbcursordirection-next)\" or
 \"[`prev`](#dom-idbcursordirection-prev)\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. If [this](https://webidl.spec.whatwg.org/#this)'s [got value
 flag](#cursor-got-value-flag) is false, indicating that the cursor is being
 iterated or has iterated past its end,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

7. Let `r` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `key`. Rethrow any exceptions.

8. If `r` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

9. Let `key` be `r`.

10. Let `r` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `primaryKey`. Rethrow any
 exceptions.

11. If `r` is \"invalid value\" or \"invalid type\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

12. Let `primaryKey` be `r`.

13. If `key` is [less than](#less-than)
 [this](https://webidl.spec.whatwg.org/#this)'s
 [position](#cursor-position) and
 [this](https://webidl.spec.whatwg.org/#this)'s
 [direction](#cursor-direction) is
 \"[`next`](#dom-idbcursordirection-next)\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

14. If `key` is [greater
 than](#greater-than)
 [this](https://webidl.spec.whatwg.org/#this)'s
 [position](#cursor-position) and
 [this](https://webidl.spec.whatwg.org/#this)'s
 [direction](#cursor-direction) is
 \"[`prev`](#dom-idbcursordirection-prev)\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

15. If `key` is [equal to](#equal-to)
 [this](https://webidl.spec.whatwg.org/#this)'s
 [position](#cursor-position) and `primaryKey` is [less
 than](#less-than) or [equal
 to](#equal-to)
 [this](https://webidl.spec.whatwg.org/#this)'s [object store
 position](#cursor-object-store-position) and
 [this](https://webidl.spec.whatwg.org/#this)'s
 [direction](#cursor-direction) is
 \"[`next`](#dom-idbcursordirection-next)\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

16. If `key` is [equal to](#equal-to)
 [this](https://webidl.spec.whatwg.org/#this)'s
 [position](#cursor-position) and `primaryKey` is [greater
 than](#greater-than) or
 [equal to](#equal-to)
 [this](https://webidl.spec.whatwg.org/#this)'s [object store
 position](#cursor-object-store-position) and
 [this](https://webidl.spec.whatwg.org/#this)'s
 [direction](#cursor-direction) is
 \"[`prev`](#dom-idbcursordirection-prev)\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

17. Set [this](https://webidl.spec.whatwg.org/#this)'s [got value
 flag](#cursor-got-value-flag) to false.

18. Let `request` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [request](#cursor-request).

19. Set `request`'s [processed
 flag](#request-processed-flag) to false.

20. Set `request`'s [done
 flag](#request-done-flag) to false.

21. Let `operation` be an algorithm to run [iterate a
 cursor](#iterate-a-cursor) with [the current Realm
 record](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#current-realm),
 [this](https://webidl.spec.whatwg.org/#this), `key`, and `primaryKey`.

22. Run [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this)'s [source
 handle](#cursor-source-handle), `operation`, and `request`.

[NOTE:] Calling this method more than once before new cursor
data has been loaded - for example, calling
[`continuePrimaryKey()`](#dom-idbcursor-continueprimarykey) twice from the same onsuccess handler - results in an
\"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) being thrown on the second call because the cursor's
[got value
flag](#cursor-got-value-flag) has been set to false.

The following methods throw a
\"[`ReadOnlyError`](https://webidl.spec.whatwg.org/#readonlyerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if called within a [read-only
transaction](#transaction-read-only-transaction), and a
\"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if called when the
[transaction](#transaction-concept) is not
[active](#transaction-active).

`request` = `cursor` . [`update`](#dom-idbcursor-update)(`value`)

: Updated the
 [record](#object-store-record) pointed at by the cursor with a new value.

 Throws a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if the [effective object
 store](#cursor-effective-object-store) uses [in-line
 keys](#object-store-in-line-keys) and the [key](#key)
 would have changed.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be the
 [record](#object-store-record)'s [key](#key).

`request` = `cursor` . [`delete`](#dom-idbcursor-delete)()

: Delete the
 [record](#object-store-record) pointed at by the cursor with a new value.

 If successful, `request`'s
 [`result`](#dom-idbrequest-result) will be `undefined`.

The [`update(``value``)`]
method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#cursor-transaction).

2. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. If `transaction` is a [read-only
 transaction](#transaction-read-only-transaction),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`ReadOnlyError`](https://webidl.spec.whatwg.org/#readonlyerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If [this](https://webidl.spec.whatwg.org/#this)'s [source](#cursor-source) or [effective object
 store](#cursor-effective-object-store) has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If [this](https://webidl.spec.whatwg.org/#this)'s [got value
 flag](#cursor-got-value-flag) is false, indicating that the cursor is being
 iterated or has iterated past its end,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. If [this](https://webidl.spec.whatwg.org/#this)'s [key only
 flag](#cursor-key-only-flag) is true,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

7. Let `targetRealm` be a user-agent defined
 [Realm](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm).

8. Let `clone` be a [clone](#clone) of `value` in `targetRealm`
 during `transaction`. Rethrow any exceptions.

 Why create a copy of the value?

 The value is serialized when stored. Treating it as a copy here
 allows other algorithms in this specification to treat it as an
 ECMAScript value, but implementations can optimize this if the
 difference in behavior is not observable.

9. If [this](https://webidl.spec.whatwg.org/#this)'s [effective object
 store](#cursor-effective-object-store) uses [in-line
 keys](#object-store-in-line-keys), then:

 1. Let `kpk` be the result of [extracting a key from a
 value using a key
 path](#extract-a-key-from-a-value-using-a-key-path) with `clone` and the [key
 path](#object-store-key-path) of
 [this](https://webidl.spec.whatwg.org/#this)'s [effective object
 store](#cursor-effective-object-store). Rethrow any exceptions.

 2. If `kpk` is failure, invalid, or not [equal
 to](#equal-to)
 [this](https://webidl.spec.whatwg.org/#this)'s [effective
 key](#cursor-effective-key),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`DataError`](https://webidl.spec.whatwg.org/#dataerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

10. Let `operation` be an algorithm to run [store a record
 into an object
 store](#store-a-record-into-an-object-store) with
 [this](https://webidl.spec.whatwg.org/#this)'s [effective object
 store](#cursor-effective-object-store), `clone`,
 [this](https://webidl.spec.whatwg.org/#this)'s [effective
 key](#cursor-effective-key), and false.

11. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

[NOTE:] A result of [storing a record into an object
store](#store-a-record-into-an-object-store) is that if the record has been deleted since the cursor
moved to it, a new record will be created.

The [`delete()`] method steps are:

1. Let `transaction` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [transaction](#cursor-transaction).

2. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. If `transaction` is a [read-only
 transaction](#transaction-read-only-transaction),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`ReadOnlyError`](https://webidl.spec.whatwg.org/#readonlyerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If [this](https://webidl.spec.whatwg.org/#this)'s [source](#cursor-source) or [effective object
 store](#cursor-effective-object-store) has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If [this](https://webidl.spec.whatwg.org/#this)'s [got value
 flag](#cursor-got-value-flag) is false, indicating that the cursor is being
 iterated or has iterated past its end,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. If [this](https://webidl.spec.whatwg.org/#this)'s [key only
 flag](#cursor-key-only-flag) is true,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

7. Let `operation` be an algorithm to run [delete records
 from an object
 store](#delete-records-from-an-object-store) with
 [this](https://webidl.spec.whatwg.org/#this)'s [effective object
 store](#cursor-effective-object-store) and
 [this](https://webidl.spec.whatwg.org/#this)'s [effective
 key](#cursor-effective-key).

8. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with
 [this](https://webidl.spec.whatwg.org/#this) and `operation`.

A [cursor](#cursor) that has its [key
only flag](#cursor-key-only-flag) set to false implements the
[`IDBCursorWithValue`](#idbcursorwithvalue) interface as well.

```
[Exposed=(Window,Worker)]
interface IDBCursorWithValue : IDBCursor {
 readonly attribute any value;
};
```

`cursor` . [`value`](#dom-idbcursorwithvalue-value)

: Returns the [cursor](#cursor)'s
 current [value](#cursor-value).

The [`value`] getter
steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s current [value](#cursor-value).

[NOTE:] If
[`value`](#dom-idbcursorwithvalue-value) returns an object, it returns the same object instance
every time it is inspected, until the cursor's
[value](#cursor-value) is
changed. This means that if the object is modified, those modifications
will be seen by anyone inspecting the value of the cursor. However
modifying such an object does not modify the contents of the database.

### 4.10. The [`IDBTransaction` interface]
[Transaction](#transaction-concept) objects implement the following interface:

```
[Exposed=(Window,Worker)]
interface IDBTransaction : EventTarget {
 readonly attribute DOMStringList objectStoreNames;
 readonly attribute IDBTransactionMode mode;
 readonly attribute IDBTransactionDurability durability;
 [SameObject] readonly attribute IDBDatabase db;
 readonly attribute DOMException? error;

 IDBObjectStore objectStore(DOMString name);
 undefined commit();
 undefined abort();

 // Event handlers:
 attribute EventHandler onabort;
 attribute EventHandler oncomplete;
 attribute EventHandler onerror;
};

enum IDBTransactionMode {
 "readonly",
 "readwrite",
 "versionchange"
};
```

`transaction` . [`objectStoreNames`](#dom-idbtransaction-objectstorenames)

: Returns a list of the names of [object
 stores](#object-store) in
 the transaction's
 [scope](#transaction-scope). For an [upgrade
 transaction](#upgrade-transaction) this is all object stores in the
 [database](#database).

`transaction` . [`mode`](#dom-idbtransaction-mode)

: Returns the [mode](#transaction-mode) the transaction was created with
 (\"[`readonly`](#dom-idbtransactionmode-readonly)\" or
 \"[`readwrite`](#dom-idbtransactionmode-readwrite)\"), or
 \"[`versionchange`](#dom-idbtransactionmode-versionchange)\" for an [upgrade
 transaction](#upgrade-transaction).

`transaction` . [`durability`](#dom-idbtransaction-durability)

: Returns the [durability
 hint](#transaction-durability-hint) the transaction was created with
 (\"[`strict`](#dom-idbtransactiondurability-strict)\",
 \"[`relaxed`](#dom-idbtransactiondurability-relaxed)\"), or
 \"[`default`](#dom-idbtransactiondurability-default)\").

`transaction` . [`db`](#dom-idbtransaction-db)

: Returns the transaction's
 [connection](#transaction-connection).

`transaction` . [`error`](#dom-idbtransaction-error)

: If the transaction was
 [aborted](#transaction-abort), returns the error (a
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)) providing the reason.

The [`objectStoreNames`] getter steps are:

1. Let `names` be a
 [list](https://infra.spec.whatwg.org/#list) of the
 [names](#object-store-name) of the [object
 stores](#object-store) in
 [this](https://webidl.spec.whatwg.org/#this)'s
 [scope](#transaction-scope).

2. Return the result (a
 [`DOMStringList`](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#domstringlist)) of [creating a sorted name
 list](#create-a-sorted-name-list) with `names`.

[NOTE:] The contents of each list returned by this attribute
does not change, but subsequent calls to this attribute during an
[upgrade
transaction](#upgrade-transaction) can return lists with different contents as [object
stores](#object-store) are
created and deleted.

The [`mode`] getter steps
are to return
[this](https://webidl.spec.whatwg.org/#this)'s [mode](#transaction-mode).

The [`durability`]
getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [durability
hint](#transaction-durability-hint).

🚧 The
[`durability`](#dom-idbtransaction-durability) attribute is new in this edition. It is supported in
Chrome 82, Edge 82, Firefox 126, and Safari 15. 🚧

The [`db`] getter steps
are to return
[this](https://webidl.spec.whatwg.org/#this)'s
[connection](#transaction-connection)'s associated [database](#database).

The [`error`] getter steps
are to return
[this](https://webidl.spec.whatwg.org/#this)'s
[error](#transaction-error),
or null if none.

[NOTE:] If this
[transaction](#transaction-concept) was aborted due to a failed
[request](#request), this will be
the same as the [request](#request)'s [error](#request-error). If this
[transaction](#transaction-concept) was aborted due to an uncaught exception in an event
handler, the error will be a
\"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException). If the
[transaction](#transaction-concept) was aborted due to an error while committing, it will
reflect the reason for the failure (e.g. a
[`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror), or a
\"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\" or
\"[`UnknownError`](https://webidl.spec.whatwg.org/#unknownerror)\"
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)).

`transaction` . [`objectStore`](#dom-idbtransaction-objectstore)(`name`)

: Returns an
 [`IDBObjectStore`](#idbobjectstore) in the
 [transaction](#transaction-concept)'s
 [scope](#transaction-scope).

`transaction` . [`abort()`](#dom-idbtransaction-abort)

: Aborts the transaction. All pending
 [requests](#request) will fail
 with a
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and all changes made to the database will be
 reverted.

`transaction` . [`commit()`](#dom-idbtransaction-commit)

: Attempts to commit the transaction. All pending
 [requests](#request) will be
 allowed to complete, but no new requests will be accepted. This can
 be used to force a transaction to quickly finish, without waiting
 for pending requests to fire
 [`success`](#eventdef-idbrequest-success) events before attempting to commit
 normally.

 The transaction will abort if a pending request fails, for example
 due to a constraint error. The
 [`success`](#eventdef-idbrequest-success) events for successful requests will
 still fire, but throwing an exception in an event handler will not
 abort the transaction. Similarly,
 [`error`](#eventdef-idbrequest-error) events for failed requests will still
 fire, but calling `preventDefault()` will not prevent the
 transaction from aborting.

The [`objectStore(``name``)`] method steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s
 [state](#transaction-state) is
 [finished](#transaction-finished), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. Let `store` be the [object
 store](#object-store)
 [named](#object-store-name) `name` in
 [this](https://webidl.spec.whatwg.org/#this)'s
 [scope](#transaction-scope), or
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if none.

3. Return an [object store
 handle](#object-store-handle) associated with `store` and
 [this](https://webidl.spec.whatwg.org/#this).

[NOTE:] Each call to this method on the same
[`IDBTransaction`](#idbtransaction) instance with the same name returns the same
[`IDBObjectStore`](#idbobjectstore) instance.

[NOTE:] The returned
[`IDBObjectStore`](#idbobjectstore) instance is specific to this
[`IDBTransaction`](#idbtransaction). If this method is called on a different
[`IDBTransaction`](#idbtransaction), a different
[`IDBObjectStore`](#idbobjectstore) instance is returned.

The [`abort()`] method steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s
 [state](#transaction-state) is
 [committing](#transaction-committing) or
 [finished](#transaction-finished), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. Run [abort a
 transaction](#abort-a-transaction) with
 [this](https://webidl.spec.whatwg.org/#this) and null.

The [`commit()`] method steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. Run [commit a
 transaction](#commit-a-transaction) with
 [this](https://webidl.spec.whatwg.org/#this).

🚧 The
[`commit()`](#dom-idbtransaction-commit) method is new in this edition. It is supported in
Chrome 76, Edge 79, Firefox 74, and Safari 15. 🚧

[NOTE:] It is not normally necessary to call
[`commit()`](#dom-idbtransaction-commit) on a
[transaction](#transaction-concept). A transaction will automatically commit when all
outstanding requests have been satisfied and no new requests have been
made. This call can be used to start the
[commit](#transaction-commit) process without waiting for events from outstanding
[requests](#request) to be
dispatched.

The [`onabort`] attribute is an
[event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`abort`](#eventdef-idbtransaction-abort).

The [`oncomplete`]
attribute is an [event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`complete`](#eventdef-idbtransaction-complete).

The [`onerror`] attribute is an
[event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
[`error`](#eventdef-idbrequest-error).

[NOTE:] To determine if a
[transaction](#transaction-concept) has completed successfully, listen to the
[transaction](#transaction-concept)'s
[`complete`](#eventdef-idbtransaction-complete) event rather than the
[`success`](#eventdef-idbrequest-success) event of a particular
[request](#request), because the
[transaction](#transaction-concept) can still fail after the
[`success`](#eventdef-idbrequest-success) event fires.

## 5. Algorithms

### 5.1. Opening a database connection

To [open a database connection] with `storageKey`
which requested the [database](#database) to be opened, a database `name`, a database
`version`, and a `request`, run these steps:

1. Let `queue` be the [connection
 queue](#connection-queue) for `storageKey` and `name`.

2. Add `request` to `queue`.

3. Wait until all previous requests in `queue` have been
 processed.

4. Let `db` be the [database](#database) [named](#database-name) `name` in `storageKey`, or
 null otherwise.

5. If `version` is undefined, let `version` be 1
 if `db` is null, or `db`'s
 [version](#database-version) otherwise.

6. If `db` is null, let `db` be a new
 [database](#database) with
 [name](#database-name)
 `name`,
 [version](#database-version) 0 (zero), and with no [object
 stores](#object-store). If
 this fails for any reason, return an appropriate error (e.g. a
 [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror), or an
 \"[`UnknownError`](https://webidl.spec.whatwg.org/#unknownerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)).

7. If `db`'s
 [version](#database-version) is greater than `version`, return a
 newly
 [created](https://webidl.spec.whatwg.org/#dfn-create-exception)
 \"[`VersionError`](https://webidl.spec.whatwg.org/#versionerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

8. Let `connection` be a new
 [connection](#connection) to
 `db`.

9. Set `connection`'s
 [version](#connection-version) to `version`.

10. If `db`'s
 [version](#database-version) is less than `version`, then:

 1. Let `openConnections` be the
 [set](https://infra.spec.whatwg.org/#ordered-set) of all
 [connections](#connection), except `connection`, associated
 with `db`.

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `entry` of
 `openConnections` that does not have its [close
 pending
 flag](#connection-close-pending-flag) set to true, [queue a database
 task](#queue-a-database-task) to [fire a version change
 event](#fire-a-version-change-event) named
 [`versionchange`](#eventdef-idbdatabase-versionchange) at `entry` with
 `db`'s
 [version](#database-version) and `version`.

 [NOTE:] Firing this event might cause one or more of
 the other objects in `openConnections` to be closed,
 in which case the
 [`versionchange`](#eventdef-idbdatabase-versionchange) event is not fired at those
 objects, even if that hasn't yet been done.

 3. Wait for all of the events to be fired.

 4. If any of the [connections](#connection) in `openConnections` are still not
 closed, [queue a database
 task](#queue-a-database-task) to [fire a version change
 event](#fire-a-version-change-event) named
 [`blocked`](#eventdef-idbopendbrequest-blocked) at `request` with
 `db`'s
 [version](#database-version) and `version`.

 5. [Wait] until all
 [connections](#connection) in `openConnections` are
 [closed](#connection-closed).

 6. Run [upgrade a
 database](#upgrade-a-database) using `connection`,
 `version` and `request`.

 7. If `connection` was
 [closed](#connection-closed), return a newly
 [created](https://webidl.spec.whatwg.org/#dfn-create-exception)
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

 8. If `request`'s
 [error](#request-error)
 is set, run the steps to [close a database
 connection](#close-a-database-connection) with `connection`, return a newly
 [created](https://webidl.spec.whatwg.org/#dfn-create-exception)
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

11. Return `connection`.

### 5.2. Closing a database connection

To [close a database connection] with a `connection`
object, and an optional `forced flag`, run these steps:

1. Set `connection`'s [close pending
 flag](#connection-close-pending-flag) to true.

2. If the `forced flag` is true, then for each
 `transaction`
 [created](#transaction-created) using `connection` run [abort a
 transaction](#abort-a-transaction) with `transaction` and newly
 [created](https://webidl.spec.whatwg.org/#dfn-create-exception)
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Wait for all transactions
 [created](#transaction-created) using `connection` to complete. Once
 they are complete, `connection` is
 [closed](#connection-closed).

4. If the `forced flag` is true, then [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`close`](#eventdef-idbdatabase-close) at `connection`.

 [NOTE:] The
 [`close`](#eventdef-idbdatabase-close) event only fires if the connection
 closes abnormally, e.g. if the [storage
 key](https://storage.spec.whatwg.org/#storage-key)'s storage is cleared, or there is corruption or an
 I/O error. If
 [`close()`](#dom-idbdatabase-close) is called explicitly the event *does not* fire.

[NOTE:] Once a [connection](#connection)'s [close pending
flag](#connection-close-pending-flag) has been set to true, no new transactions can be
[created](#transaction-created) using the
[connection](#connection). All
methods that
[create](#transaction-created) transactions first check the
[connection](#connection)'s
[close pending
flag](#connection-close-pending-flag) first and throw an exception if it is true.

[NOTE:] Once the
[connection](#connection) is
closed, this can unblock the steps to [upgrade a
database](#upgrade-a-database), and the steps to [delete a
database](#delete-a-database), which [both](#delete-close-block)
[wait](#version-change-close-block) for
[connections](#connection) to a
given [database](#database) to be
closed before continuing.

### 5.3. Deleting a database

To [delete a database] with the `storageKey` that
requested the [database](#database)
to be deleted, a database `name`, and a `request`,
run these steps:

1. Let `queue` be the [connection
 queue](#connection-queue) for `storageKey` and `name`.

2. Add `request` to `queue`.

3. Wait until all previous requests in `queue` have been
 processed.

4. Let `db` be the [database](#database) [named](#database-name) `name` in `storageKey`, if
 one exists. Otherwise, return 0 (zero).

5. Let `openConnections` be the
 [set](https://infra.spec.whatwg.org/#ordered-set) of all
 [connections](#connection)
 associated with `db`.

6. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `entry` of `openConnections`
 that does not have its [close pending
 flag](#connection-close-pending-flag) set to true, [queue a database
 task](#queue-a-database-task) to [fire a version change
 event](#fire-a-version-change-event) named
 [`versionchange`](#eventdef-idbdatabase-versionchange) at `entry` with
 `db`'s
 [version](#database-version) and null.

 [NOTE:] Firing this event might cause one or more of the
 other objects in `openConnections` to be closed, in which
 case the
 [`versionchange`](#eventdef-idbdatabase-versionchange) event is not fired at those objects,
 even if that hasn't yet been done.

7. Wait for all of the events to be fired.

8. If any of the [connections](#connection) in `openConnections` are still not
 closed, [queue a database
 task](#queue-a-database-task) to [fire a version change
 event](#fire-a-version-change-event) named
 [`blocked`](#eventdef-idbopendbrequest-blocked) at `request` with
 `db`'s
 [version](#database-version) and null.

9. [Wait] until all
 [connections](#connection) in
 `openConnections` are
 [closed](#connection-closed).

10. Let `version` be `db`'s
 [version](#database-version).

11. Delete `db`. If this fails for any reason, return an
 appropriate error (e.g. a
 [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror), or an
 \"[`UnknownError`](https://webidl.spec.whatwg.org/#unknownerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)).

12. Return `version`.

### 5.4. Committing a transaction

To [commit a transaction] with the `transaction` to commit,
run these steps:

1. Set `transaction`'s
 [state](#transaction-state) to
 [committing](#transaction-committing).

2. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Wait until every item in `transaction`'s [request
 list](#transaction-request-list) is
 [processed](#request-processed).

 2. If `transaction`'s
 [state](#transaction-state) is no longer
 [committing](#transaction-committing), then terminate these steps.

 3. Attempt to write any outstanding changes made by
 `transaction` to the
 [database](#database),
 considering `transaction`'s [durability
 hint](#transaction-durability-hint).

 4. If an error occurs while writing the changes to the
 [database](#database), then
 run [abort a
 transaction](#abort-a-transaction) with `transaction` and an
 appropriate type for the error, for example a
 [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror) or an
 \"[`UnknownError`](https://webidl.spec.whatwg.org/#unknownerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException), and terminate these steps.

 5. [Queue a database
 task](#queue-a-database-task) to run these steps:

 1. If `transaction` is an [upgrade
 transaction](#upgrade-transaction), then set `transaction`'s
 [connection](#transaction-connection)'s associated
 [database](#database)'s
 [upgrade
 transaction](#database-upgrade-transaction) to null.

 2. Set `transaction`'s
 [state](#transaction-state) to
 [finished](#transaction-finished).

 3. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`complete`](#eventdef-idbtransaction-complete) at `transaction`.

 [NOTE:] Even if an exception is thrown from one of
 the event handlers of this event, the transaction is still
 committed since writing the database changes happens before
 the event takes place. Only after the transaction has been
 successfully written is the
 [`complete`](#eventdef-idbtransaction-complete) event fired.

 4. If `transaction` is an [upgrade
 transaction](#upgrade-transaction), then let `request` be the
 [request](#request)
 associated with `transaction` and set
 `request`'s
 [transaction](#request-transaction) to null.

### 5.5. Aborting a transaction

To [abort a transaction] with the `transaction` to abort,
and `error`, run these steps:

1. If `transaction`'s
 [state](#transaction-state) is
 [finished](#transaction-finished), abort these steps.

2. All the changes made to the
 [database](#database) by the
 [transaction](#transaction-concept) are reverted. For [upgrade
 transactions](#upgrade-transaction) this includes changes to the set of [object
 stores](#object-store) and
 [indexes](#index-concept),
 as well as the change to the
 [version](#database-version). Any [object
 stores](#object-store) and
 [indexes](#index-concept)
 which were created during the transaction are now considered deleted
 for the purposes of other algorithms.

3. If `transaction` is an [upgrade
 transaction](#upgrade-transaction), run the steps to [abort an upgrade
 transaction](#abort-an-upgrade-transaction) with `transaction`.

 [NOTE:] This reverts changes to all
 [connection](#connection),
 [object store
 handle](#object-store-handle), and [index
 handle](#index-handle)
 instances associated with `transaction`.

4. Set `transaction`'s
 [state](#transaction-state) to
 [finished](#transaction-finished).

5. Set `transaction`'s
 [error](#transaction-error) to `error`.

6. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `request` of `transaction`'s
 [request
 list](#transaction-request-list), abort the steps to [asynchronously execute a
 request](#asynchronously-execute-a-request) for `request`, set
 `request`'s [processed
 flag](#request-processed-flag) to true, and [queue a database
 task](#queue-a-database-task) to run these steps:

 1. Set `request`'s [done
 flag](#request-done-flag) to true.

 2. Set `request`'s
 [result](#request-result) to undefined.

 3. Set `request`'s
 [error](#request-error)
 to a newly
 [created](https://webidl.spec.whatwg.org/#dfn-create-exception)
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 4. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`error`](#eventdef-idbrequest-error) at `request` with its
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) and
 [`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable) attributes initialized to true.

 [NOTE:] This does not always result in any
 [`error`](#eventdef-idbrequest-error) events being fired. For example if a
 transaction is aborted due to an error while
 [committing](#transaction-committing) the transaction, or if it was the last remaining
 request that failed.

7. [Queue a database
 task](#queue-a-database-task) to run these steps:

 1. If `transaction` is an [upgrade
 transaction](#upgrade-transaction), then set `transaction`'s
 [connection](#transaction-connection)'s associated
 [database](#database)'s
 [upgrade
 transaction](#database-upgrade-transaction) to null.

 2. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`abort`](#eventdef-idbtransaction-abort) at `transaction` with
 its
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) attribute initialized to true.

 3. If `transaction` is an [upgrade
 transaction](#upgrade-transaction), then:

 1. Let `request` be the [open
 request](#request-open-request) associated with `transaction`.

 2. Set `request`'s
 [transaction](#request-transaction) to null.

 3. Set `request`'s
 [result](#request-result) to undefined.

 4. Set `request`'s [processed
 flag](#request-processed-flag) to false.

 5. Set `request`'s [done
 flag](#request-done-flag) to false.

### 5.6. Asynchronously executing a [request]
To [asynchronously execute a request] with the
`source` object and an `operation` to perform on a
database, and an optional `request`, run these steps:

These steps can be aborted at any point if the
[transaction](#transaction-concept) the created [request](#request) belongs to is
[aborted](#transaction-abort) using the steps to [abort a
transaction](#abort-a-transaction).

1. Let `transaction` be the
 [transaction](#transaction-concept) associated with `source`.

2. [Assert](https://infra.spec.whatwg.org/#assert): `transaction`'s
 [state](#transaction-state) is
 [active](#transaction-active).

3. If `request` was not given, let `request` be a
 new [request](#request) with
 [source](#request-source)
 as `source`.

4. Add `request` to the end of `transaction`'s
 [request
 list](#transaction-request-list).

5. Run these steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Wait until `request` is the first item in
 `transaction`'s [request
 list](#transaction-request-list) that is not
 [processed](#request-processed).

 2. Let `result` be the result of performing
 `operation`.

 3. If `result` is an error and
 `transaction`'s
 [state](#transaction-state) is
 [committing](#transaction-committing), then run [abort a
 transaction](#abort-a-transaction) with `transaction` and
 `result`, and terminate these steps.

 4. If `result` is an error, then revert all changes made
 by `operation`.

 [NOTE:] This only reverts the changes done by this
 request, not any other changes made by the transaction.

 5. Set `request`'s [processed
 flag](#request-processed-flag) to true.

 6. [Queue a database
 task](#queue-a-database-task) to run these steps:

 1. Remove `request` from `transaction`'s
 [request
 list](#transaction-request-list).

 2. Set `request`'s [done
 flag](#request-done-flag) to true.

 3. If `result` is an error, then:

 1. Set `request`'s
 [result](#request-result) to undefined.

 2. Set `request`'s
 [error](#request-error) to `result`.

 3. [Fire an error
 event](#fire-an-error-event) at `request`.

 4. Otherwise:

 1. Set `request`'s
 [result](#request-result) to `result`.

 2. Set `request`'s
 [error](#request-error) to undefined.

 3. [Fire a success
 event](#fire-a-success-event) at `request`.

6. Return `request`.

### 5.7. Upgrading a database

To [upgrade a database] with `connection` (a
[connection](#connection)), a new
`version`, and a `request`, run these steps:

1. Let `db` be `connection`'s
 [database](#database).

2. Let `transaction` be a new [upgrade
 transaction](#upgrade-transaction) with `connection` used as
 [connection](#connection).

3. Set `transaction`'s
 [scope](#transaction-scope) to `connection`'s [object store
 set](#connection-object-store-set).

4. Set `db`'s [upgrade
 transaction](#database-upgrade-transaction) to `transaction`.

5. Set `transaction`'s
 [state](#transaction-state) to
 [inactive](#transaction-inactive).

6. Start `transaction`.

 [NOTE:] Note that until this
 [transaction](#transaction-concept) is finished, no other
 [connections](#connection)
 can be opened to the same [database](#database).

7. Let `old version` be `db`'s
 [version](#database-version).

8. Set `db`'s
 [version](#database-version) to `version`. This change is considered
 part of the
 [transaction](#transaction-concept), and so if the transaction is
 [aborted](#transaction-abort), this change is reverted.

9. Set `request`'s [processed
 flag](#request-processed-flag) to true.

10. [Queue a database
 task](#queue-a-database-task) to run these steps:

 1. Set `request`'s
 [result](#request-result) to `connection`.

 2. Set `request`'s
 [transaction](#request-transaction) to `transaction`.

 3. Set `request`'s [done
 flag](#request-done-flag) to true.

 4. Set `transaction`'s
 [state](#transaction-state) to
 [active](#transaction-active).

 5. Let `didThrow` be the result of [firing a version
 change
 event](#fire-a-version-change-event) named
 [`upgradeneeded`](#eventdef-idbopendbrequest-upgradeneeded) at `request` with
 `old version` and `version`.

 6. If `transaction`'s
 [state](#transaction-state) is
 [active](#transaction-active), then:

 1. Set `transaction`'s
 [state](#transaction-state) to
 [inactive](#transaction-inactive).

 2. If `didThrow` is true, run [abort a
 transaction](#abort-a-transaction) with `transaction` and a newly
 [created](https://webidl.spec.whatwg.org/#dfn-create-exception)
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

11. Wait for `transaction` to
 [finish](#transaction-finished).

 [NOTE:] Some of the algorithms invoked during the
 [transaction](#transaction-concept)'s
 [lifetime](#transaction-lifetime), such as the steps to [commit a
 transaction](#commit-a-transaction) and the steps to [abort a
 transaction](#abort-a-transaction), include steps specific to [upgrade
 transactions](#upgrade-transaction).

### 5.8. Aborting an upgrade transaction

To [abort an upgrade transaction] with `transaction`,
run these steps:

[NOTE:] These steps are run as needed by the steps to [abort a
transaction](#abort-a-transaction), which revert changes to the
[database](#database) including the
set of associated [object stores](#object-store) and [indexes](#index-concept), as well as the change to the
[version](#database-version).

1. Let `connection` be `transaction`'s
 [connection](#connection).

2. Let `database` be `connection`'s
 [database](#database).

3. Set `connection`'s
 [version](#connection-version) to `database`'s
 [version](#database-version) if `database` previously existed, or 0
 (zero) if `database` was newly created.

 [NOTE:] This reverts the value of
 [`version`](#dom-idbdatabase-version) returned by the
 [`IDBDatabase`](#idbdatabase) object.

4. Set `connection`'s [object store
 set](#connection-object-store-set) to the set of [object
 stores](#object-store) in
 `database` if `database` previously existed,
 or the empty set if `database` was newly created.

 [NOTE:] This reverts the value of
 [`objectStoreNames`](#dom-idbdatabase-objectstorenames) returned by the
 [`IDBDatabase`](#idbdatabase) object.

5. For each [object store
 handle](#object-store-handle) `handle` associated with
 `transaction`, including those for [object
 stores](#object-store) that
 were created or deleted during `transaction`:

 1. If `handle`'s [object
 store](#object-store-handle-object-store) was not newly created during
 `transaction`, set `handle`'s
 [name](#object-store-handle-name) to its [object
 store](#object-store-handle-object-store)'s
 [name](#object-store-name).

 2. Set `handle`'s [index
 set](#object-store-handle-index-set) to the set of
 [indexes](#index-concept) that reference its [object
 store](#object-store-handle-object-store).

 [NOTE:] This reverts the values of
 [`name`](#dom-idbobjectstore-name) and
 [`indexNames`](#dom-idbobjectstore-indexnames) returned by related
 [`IDBObjectStore`](#idbobjectstore) objects.

 How is this observable?

 Although script cannot access an [object
 store](#object-store) by
 using the
 [`objectStore()`](#dom-idbtransaction-objectstore) method on an
 [`IDBTransaction`](#idbtransaction) instance after the
 [transaction](#transaction-concept) is aborted, it can still have references to
 [`IDBObjectStore`](#idbobjectstore) instances where the
 [`name`](#dom-idbobjectstore-name) and
 [`indexNames`](#dom-idbobjectstore-indexnames) properties can be queried.

6. For each [index handle](#index-handle) `handle` associated with
 `transaction`, including those for
 [indexes](#index-concept)
 that were created or deleted during `transaction`:

 1. If `handle`'s
 [index](#index-handle-index) was not newly created during
 `transaction`, set `handle`'s
 [name](#index-handle-name) to its
 [index](#index-handle-index)'s [name](#index-name).

 [NOTE:] This reverts the value of
 [`name`](#dom-idbindex-name) returned by related
 [`IDBIndex`](#idbindex)
 objects.

 How is this observable?

 Although script cannot access an
 [index](#index-concept) by
 using the
 [`index()`](#dom-idbobjectstore-index) method on an
 [`IDBObjectStore`](#idbobjectstore) instance after the
 [transaction](#transaction-concept) is aborted, it can still have references to
 [`IDBIndex`](#idbindex)
 instances where the
 [`name`](#dom-idbindex-name) property can be queried.

[NOTE:] The
[`name`](#dom-idbdatabase-name) property of the
[`IDBDatabase`](#idbdatabase) instance is not modified, even if the aborted [upgrade
transaction](#upgrade-transaction) was creating a new
[database](#database).

### 5.9. Firing a success event

To [fire a success event] at a `request`, run these steps:

1. Let `event` be the result of [creating an
 event](https://dom.spec.whatwg.org/#concept-event-create) using
 [`Event`](https://dom.spec.whatwg.org/#event).

2. Set `event`'s
 [`type`](https://dom.spec.whatwg.org/#dom-event-type) attribute to \"`success`\".

3. Set `event`'s
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) and
 [`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable) attributes to false.

4. Let `transaction` be `request`'s
 [transaction](#transaction-concept).

5. Let `legacyOutputDidListenersThrowFlag` be initially
 false.

6. If `transaction`'s
 [state](#transaction-state) is
 [inactive](#transaction-inactive), then set `transaction`'s
 [state](#transaction-state) to
 [active](#transaction-active).

7. [Dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch) `event` at `request` with
 `legacyOutputDidListenersThrowFlag`.

8. If `transaction`'s
 [state](#transaction-state) is
 [active](#transaction-active), then:

 1. Set `transaction`'s
 [state](#transaction-state) to
 [inactive](#transaction-inactive).

 2. If `legacyOutputDidListenersThrowFlag` is true, then
 run [abort a
 transaction](#abort-a-transaction) with `transaction` and a newly
 [created](https://webidl.spec.whatwg.org/#dfn-create-exception)
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3. If `transaction`'s [request
 list](#transaction-request-list) is empty, then run [commit a
 transaction](#commit-a-transaction) with `transaction`.

### 5.10. Firing an error event

To [fire an error event] at a `request`, run these steps:

1. Let `event` be the result of [creating an
 event](https://dom.spec.whatwg.org/#concept-event-create) using
 [`Event`](https://dom.spec.whatwg.org/#event).

2. Set `event`'s
 [`type`](https://dom.spec.whatwg.org/#dom-event-type) attribute to \"`error`\".

3. Set `event`'s
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) and
 [`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable) attributes to true.

4. Let `transaction` be `request`'s
 [transaction](#transaction-concept).

5. Let `legacyOutputDidListenersThrowFlag` be initially
 false.

6. If `transaction`'s
 [state](#transaction-state) is
 [inactive](#transaction-inactive), then set `transaction`'s
 [state](#transaction-state) to
 [active](#transaction-active).

7. [Dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch) `event` at
 [request](#request) with
 `legacyOutputDidListenersThrowFlag`.

8. If `transaction`'s
 [state](#transaction-state) is
 [active](#transaction-active), then:

 1. Set `transaction`'s
 [state](#transaction-state) to
 [inactive](#transaction-inactive).

 2. If `legacyOutputDidListenersThrowFlag` is true, then
 run [abort a
 transaction](#abort-a-transaction) with `transaction` and a newly
 [created](https://webidl.spec.whatwg.org/#dfn-create-exception)
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and terminate these steps. This is done even if
 `event`'s [canceled
 flag](https://dom.spec.whatwg.org/#canceled-flag) is false.

 [NOTE:] This means that if an error event is fired and
 any of the event handlers throw an exception,
 `transaction`'s
 [`error`](#dom-idbtransaction-error) property is set to an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror) rather than `request`'s
 [error](#request-error), even if
 [`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) is never called.

 3. If `event`'s [canceled
 flag](https://dom.spec.whatwg.org/#canceled-flag) is false, then run [abort a
 transaction](#abort-a-transaction) using `transaction` and
 [request](#request)'s
 [error](#request-error), and terminate these steps.

 4. If `transaction`'s [request
 list](#transaction-request-list) is empty, then run [commit a
 transaction](#commit-a-transaction) with `transaction`.

### 5.11. Clone a value

To make a [clone]
of `value` in `targetRealm` during
`transaction`, run these steps:

1. [Assert](https://infra.spec.whatwg.org/#assert): `transaction`'s
 [state](#transaction-state) is
 [active](#transaction-active).

2. Set `transaction`'s
 [state](#transaction-state) to
 [inactive](#transaction-inactive).

 [NOTE:] The
 [transaction](#transaction-concept) is made
 [inactive](#transaction-inactive) so that getters or other side effects triggered by
 the cloning operation are unable to make additional requests against
 the transaction.

3. Let `serialized` be
 [?](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [StructuredSerializeForStorage](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeforstorage)(`value`).

4. Let `clone` be
 [?](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serialized`,
 `targetRealm`).

5. Set `transaction`'s
 [state](#transaction-state) to
 [active](#transaction-active).

6. Return `clone`.

### 5.12. Creating a request to retrieve multiple items

To [create a [request](#request) to
retrieve multiple items] from an [object
store](#object-store) or
[index](#index-concept) with
`targetRealm`, `sourceHandle`, `kind`,
`queryOrOptions`, and optional `count`, run these
steps:

1. Let `source` be an
 [index](#index-concept) or
 an [object store](#object-store) from `sourceHandle`. If
 `sourceHandle` is an [index
 handle](#index-handle),
 then `source` is [the index handle's associated
 index](#index-handle-index). Otherwise, `source` is [the object
 store handle's associated object
 store](#object-store-handle-object-store).

2. If `source` has been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. If `source` is an
 [index](#index-concept)
 and `source`'s [object
 store](#object-store) has
 been deleted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. Let `transaction` be `sourceHandle`'s
 [transaction](#transaction-concept).

5. If `transaction`'s
 [state](#transaction-state) is not
 [active](#transaction-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TransactionInactiveError`](https://webidl.spec.whatwg.org/#transactioninactiveerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. Let `range` be a [key
 range](#key-range).

7. Let `direction` be a [cursor
 direction](#cursor-direction).

8. If running [is a potentially valid key
 range](#is-a-potentially-valid-key-range) with `queryOrOptions` is true, then:

 1. Set `range` to the result of [converting a value to a
 key
 range](#convert-a-value-to-a-key-range) with `queryOrOptions`. Rethrow any
 exceptions.

 2. Set `direction` to
 \"[`next`](#dom-idbcursordirection-next)\".

9. Else:

 1. Set `range` to the result of [converting a value to a
 key
 range](#convert-a-value-to-a-key-range) with
 `queryOrOptions`\[\"[`query`](#dom-idbgetalloptions-query)\"\]. Rethrow any exceptions.

 2. Set `count` to
 `queryOrOptions`\[\"[`count`](#dom-idbgetalloptions-count)\"\].

 3. Set `direction` to
 `queryOrOptions`\[\"[`direction`](#dom-idbgetalloptions-direction)\"\].

10. Let `operation` be an algorithm to run.

11. If `source` is an
 [index](#index-concept),
 set `operation` to [retrieve multiple items from an
 index](#retrieve-multiple-items-from-an-index) with `targetRealm`, `source`,
 `range`, `kind`, `direction`, and
 `count` if given.

12. Else set `operation` to [retrieve multiple items from an
 object
 store](#retrieve-multiple-items-from-an-object-store) with `targetRealm`, `source`,
 `range`, `kind`, `direction`, and
 `count` if given.

13. Return the result (an
 [`IDBRequest`](#idbrequest)) of running [asynchronously execute a
 request](#asynchronously-execute-a-request) with `sourceHandle` and
 `operation`.

[NOTE:] The `range` can be a
[key](#key) or [key
range](#key-range) (an
[`IDBKeyRange`](#idbkeyrange)) identifying the
[record](#object-store-record) items to be retrieved. If null or not given, an
[unbounded key
range](#unbounded-key-range) is used. If `count` is specified and there
are more than `count` records in range, only the first
`count` will be retrieved.

## 6. Database operations

This section describes various operations done on the data in [object
stores](#object-store) and
[indexes](#index-concept) in a
[database](#database). These
operations are run by the steps to [asynchronously execute a
request](#asynchronously-execute-a-request).

[NOTE:] Invocations of
[StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)() in the operation steps below can be asserted
not to throw (as indicated by the
[!](https://tc39.github.io/ecma262/#sec-algorithm-conventions) prefix) because they operate
only on previous output of
[StructuredSerializeForStorage](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeforstorage)().

### 6.1. Object store storage operation

To [store a record into an object
store] with `store`, `value`,
an optional `key`, and a `no-overwrite flag`, run
these steps:

1. If `store` uses a [key
 generator](#key-generator), then:

 1. If `key` is undefined, then:

 1. Let `key` be the result of [generating a
 key](#generate-a-key) for `store`.

 2. If `key` is failure, then this operation failed
 with a
 \"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException). Abort this algorithm without taking any
 further steps.

 3. If `store` also uses [in-line
 keys](#object-store-in-line-keys), then run [inject a key into a value using
 a key
 path](#inject-a-key-into-a-value-using-a-key-path) with `value`, `key`
 and `store`'s [key
 path](#object-store-key-path).

 2. Otherwise, run [possibly update the key
 generator](#possibly-update-the-key-generator) for `store` with `key`.

2. If the `no-overwrite flag` was given to these steps and
 is true, and a
 [record](#object-store-record) already exists in `store` with its key
 [equal to](#equal-to)
 `key`, then this operation failed with a
 \"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException). Abort this algorithm without taking any further
 steps.

3. If a [record](#object-store-record) already exists in `store` with its key
 [equal to](#equal-to)
 `key`, then remove the
 [record](#object-store-record) from `store` using [delete records from
 an object
 store](#delete-records-from-an-object-store).

4. Store a record in `store` containing `key` as
 its key and
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [StructuredSerializeForStorage](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeforstorage)(`value`) as its value. The
 record is stored in the object store's [list of
 records](#object-store-list-of-records) such that the list is sorted according to the key
 of the records in [ascending](#greater-than) order.

5. For each `index` which
 [references](#index-referenced) `store`:

 1. Let `index key` be the result of [extracting a key
 from a value using a key
 path](#extract-a-key-from-a-value-using-a-key-path) with `value`, `index`'s
 [key path](#index-key-path), and `index`'s [multiEntry
 flag](#index-multientry-flag).

 2. If `index key` is an exception, or invalid, or
 failure, take no further actions for `index`, and
 continue these steps for the next index.

 [NOTE:] An exception thrown in this step is not
 rethrown.

 3. If `index`'s [multiEntry
 flag](#index-multientry-flag) is false, or if `index key` is not
 an [array key](#array-key),
 and if `index` already contains a
 [record](#object-store-record) with [key](#key) [equal to](#equal-to) `index key`, and
 `index`'s [unique
 flag](#index-unique-flag) is true, then this operation failed with a
 \"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException). Abort this algorithm without taking any
 further steps.

 4. If `index`'s [multiEntry
 flag](#index-multientry-flag) is true and `index key` is an [array
 key](#array-key), and if
 `index` already contains a
 [record](#object-store-record) with [key](#key) [equal to](#equal-to) any of the
 [subkeys](#subkeys) of
 `index key`, and `index`'s [unique
 flag](#index-unique-flag) is true, then this operation failed with a
 \"[`ConstraintError`](https://webidl.spec.whatwg.org/#constrainterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException). Abort this algorithm without taking any
 further steps.

 5. If `index`'s [multiEntry
 flag](#index-multientry-flag) is false, or if `index key` is not
 an [array key](#array-key)
 then store a record in `index` containing
 `index key` as its key and `key` as its
 value. The record is stored in `index`'s [list of
 records](#index-list-of-records) such that the list is sorted primarily on the
 records keys, and secondarily on the records values, in
 [ascending](#greater-than) order.

 6. If `index`'s [multiEntry
 flag](#index-multientry-flag) is true and `index key` is an [array
 key](#array-key), then for
 each `subkey` of the
 [subkeys](#subkeys) of
 `index key` store a record in `index`
 containing `subkey` as its key and `key`
 as its value. The records are stored in `index`'s
 [list of
 records](#index-list-of-records) such that the list is sorted primarily on the
 records keys, and secondarily on the records values, in
 [ascending](#greater-than) order.

 [NOTE:] It is valid for there to be no
 [subkeys](#subkeys). In this
 case no records are added to the index.

 [NOTE:] Even if any member of
 [subkeys](#subkeys) is itself
 an [array key](#array-key),
 the member is used directly as the key for the index record.
 Nested [array keys](#array-key) are not flattened or \"unpacked\" to produce
 multiple rows; only the outer-most [array
 key](#array-key) is.

6. Return `key`.

### 6.2. Object store retrieval operations

To [retrieve a value from an object
store] with `targetRealm`,
`store` and `range`, run these steps. They return
undefined, an ECMAScript value, or an error (a
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)):

1. Let `record` be the first
 [record](#object-store-record) in `store`'s [list of
 records](#object-store-list-of-records) whose [key](#key)
 is [in](#in) `range`, if
 any.

2. If `record` was not found, return undefined.

3. Let `serialized` be `record`'s
 [value](#value). If an error
 occurs while reading the value from the underlying storage, return a
 newly
 [created](https://webidl.spec.whatwg.org/#dfn-create-exception)
 \"[`NotReadableError`](https://webidl.spec.whatwg.org/#notreadableerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. Return
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serialized`,
 `targetRealm`).

To [retrieve a key from an object
store] with `store` and
`range`, run these steps:

1. Let `record` be the first
 [record](#object-store-record) in `store`'s [list of
 records](#object-store-list-of-records) whose [key](#key)
 is [in](#in) `range`, if
 any.

2. If `record` was not found, return undefined.

3. Return the result of [converting a key to a
 value](#convert-a-key-to-a-value) with `record`'s key.

To [retrieve multiple items from an object
store] with `targetRealm`,
`store`, `range`, `kind`,
`direction`, and optional `count`, run these
steps:

1. If `count` is not given or is 0 (zero), let
 `count` be infinity.

2. Let `records` be an empty
 [list](https://infra.spec.whatwg.org/#list) of
 [records](#object-store-record).

3. If `direction` is
 \"[`next`](#dom-idbcursordirection-next)\" or
 \"[`nextunique`](#dom-idbcursordirection-nextunique)\", set `records` to the first
 `count` of `store`'s [list of
 records](#object-store-list-of-records) whose [key](#key)
 is [in](#in) `range`.

4. If `direction` is
 \"[`prev`](#dom-idbcursordirection-prev)\" or
 \"[`prevunique`](#dom-idbcursordirection-prevunique)\", set `records` to the last
 `count` of `store`'s [list of
 records](#object-store-list-of-records) whose [key](#key)
 is [in](#in) `range`.

5. Let `list` be an empty
 [list](https://infra.spec.whatwg.org/#list).

6. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `record` of `records`,
 switching on `kind`:

 \"key\"

 : 1. Let `key` be the result of [converting a key to a
 value](#convert-a-key-to-a-value) with `record`'s key.

 2. [Append](https://infra.spec.whatwg.org/#list-append) `key` to `list`.

 \"value\"

 : 1. Let `serialized` be `record`'s
 [value](#value).

 2. Let `value` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serialized`,
 `targetRealm`).

 3. [Append](https://infra.spec.whatwg.org/#list-append) `value` to `list`.

 \"record\"

 : 1. Let `key` be the `record`'s key.

 2. Let `serialized` be `record`'s
 [value](#value).

 3. Let `value` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serialized`,
 `targetRealm`).

 4. Let `recordSnapshot` be a new [record
 snapshot](#record-snapshot) with its
 [key](#record-snapshot-key) set to `key`,
 [value](#record-snapshot-value) set to `value`, and [primary
 key](#record-snapshot-primary-key) set to `key`.

 5. [Append](https://infra.spec.whatwg.org/#list-append) `recordSnapshot` to
 `list`.

7. Return `list`.

### 6.3. Index retrieval operations

To [retrieve a referenced value from an
index] with `targetRealm`,
`index` and `range`, run these steps:

1. Let `record` be the first
 [record](#object-store-record) in `index`'s [list of
 records](#index-list-of-records) whose [key](#index-keys) is [in](#in)
 `range`, if any.

2. If `record` was not found, return undefined.

3. Let `serialized` be `record`'s [referenced
 value](#index-referenced-value).

4. Return
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serialized`,
 `targetRealm`).

To [retrieve a value from an index] with `index` and
`range`, run these steps:

1. Let `record` be the first
 [record](#index-records) in
 `index`'s [list of
 records](#index-list-of-records) whose [key](#index-keys) is [in](#in)
 `range`, if any.

2. If `record` was not found, return undefined.

3. Return the result of [converting a key to a
 value](#convert-a-key-to-a-value) with `record`'s
 [value](#value).

To [retrieve multiple items from an
index] with `targetRealm`,
`index`, `range`, `kind`,
`direction` and optional `count`, run these steps:

1. If `count` is not given or is 0 (zero), let
 `count` be infinity.

2. Let `records` be an empty
 [list](https://infra.spec.whatwg.org/#list) of
 [records](#object-store-record).

3. Switching on `direction`:

 \"next\"

 : 1. Set `records` to the first `count` of
 `index`'s [list of
 records](#index-list-of-records) whose
 [key](#index-keys) is
 [in](#in) `range`.

 \"nextunique\"

 : 1. Let `rangeRecords` be a list containing the
 `index`'s [list of
 records](#index-list-of-records) whose
 [key](#index-keys) is
 [in](#in) `range`.

 2. Let `rangeRecordsLength` be
 `rangeRecords`'s
 [size](https://infra.spec.whatwg.org/#list-size).

 3. Let `i` be 0.

 4. While `i` is less than
 `rangeRecordsLength`, then:

 1. Increase `i` by 1.

 2. if `record`'s
 [size](https://infra.spec.whatwg.org/#list-size) is equal to `count`, then
 [break](https://infra.spec.whatwg.org/#iteration-break).

 3. If the result of [comparing two
 keys](#compare-two-keys) using the keys from
 \|rangeRecords\[i\]\| and \|rangeRecords\[i-1\]\| is
 equal, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 4. Else
 [append](https://infra.spec.whatwg.org/#list-append) \|rangeRecords\[i\]\| to
 `records`.

 \"prev\"

 : 1. Set `records` to the last `count` of
 `index`'s [list of
 records](#index-list-of-records) whose
 [key](#index-keys) is
 [in](#in) `range`.

 \"prevunique\"

 : 1. Let `rangeRecords` be a list containing the
 `index`'s [list of
 records](#index-list-of-records) whose
 [key](#index-keys) is
 [in](#in) `range`.

 2. Let `rangeRecordsLength` be
 `rangeRecords`'s
 [size](https://infra.spec.whatwg.org/#list-size).

 3. Let `i` be 0.

 4. While `i` is less than
 `rangeRecordsLength`, then:

 1. Increase `i` by 1.

 2. if `record`'s
 [size](https://infra.spec.whatwg.org/#list-size) is equal to `count`, then
 [break](https://infra.spec.whatwg.org/#iteration-break).

 3. If the result of [comparing two
 keys](#compare-two-keys) using the keys from
 \|rangeRecords\[i\]\| and \|rangeRecords\[i-1\]\| is
 equal, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 4. Else
 [prepend](https://infra.spec.whatwg.org/#list-prepend) \|rangeRecords\[i\]\| to
 `records`.

4. Let `list` be an empty
 [list](https://infra.spec.whatwg.org/#list).

5. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `record` of `records`,
 switching on `kind`:

 \"key\"

 : 1. Let `key` be the result of [converting a key to a
 value](#convert-a-key-to-a-value) with `record`'s value.

 2. [Append](https://infra.spec.whatwg.org/#list-append) `key` to `list`.

 \"value\"

 : 1. Let `serialized` be `record`'s
 [referenced
 value](#index-referenced-value).

 2. Let `value` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serialized`,
 `targetRealm`).

 3. [Append](https://infra.spec.whatwg.org/#list-append) `value` to `list`.

 \"record\"

 : 1. Let `index key` be the `record`'s key.

 2. Let `key` be the `record`'s value.

 3. Let `serialized` be `record`'s
 [referenced
 value](#index-referenced-value).

 4. Let `value` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serialized`,
 `targetRealm`).

 5. Let `recordSnapshot` be a new [record
 snapshot](#record-snapshot) with its
 [key](#record-snapshot-key) set to `index key`,
 [value](#record-snapshot-value) set to `value`, and [primary
 key](#record-snapshot-primary-key) set to `key`.

 6. [Append](https://infra.spec.whatwg.org/#list-append) `recordSnapshot` to
 `list`.

6. Return `list`.

The [values](#index-values) of a
[record](#index-records) in an
index are the keys of
[records](#object-store-record) in the
[referenced](#index-referenced) object store.

### 6.4. Object store deletion operation

To [delete records from an object
store] with `store` and
`range`, run these steps:

1. Remove all records, if any, from `store`'s [list of
 records](#object-store-list-of-records) with key [in](#in)
 `range`.

2. For each `index` which
 [references](#index-referenced) `store`, remove every
 [record](#object-store-record) from `index`'s [list of
 records](#index-list-of-records) whose value is [in](#in) `range`, if any such records exist.

3. Return undefined.

### 6.5. Record counting operation

To [count the records in a range] with `source` and
`range`, run these steps:

1. Let `count` be the number of records, if any, in
 `source`'s list of records with key
 [in](#in) `range`.

2. Return `count`.

### 6.6. Object store clear operation

To [clear an object store] with `store`, run these steps:

1. Remove all records from `store`.

2. In all [indexes](#index-concept) which
 [reference](#index-referenced) `store`, remove all
 [records](#object-store-record).

3. Return undefined.

### 6.7. Cursor iteration operation

To [iterate a cursor] with `targetRealm`, `cursor`, an
optional `key` and `primaryKey` to iterate to, and
an optional `count`, run these steps:

1. Let `source` be `cursor`'s
 [source](#cursor-source).

2. Let `direction` be `cursor`'s
 [direction](#cursor-direction).

3. [Assert](https://infra.spec.whatwg.org/#assert): if `primaryKey` is given,
 `source` is an
 [index](#index-concept)
 and `direction` is
 \"[`next`](#dom-idbcursordirection-next)\" or
 \"[`prev`](#dom-idbcursordirection-prev)\".

4. Let `records` be the list of
 [records](#object-store-record) in `source`.

 [NOTE:] `records` is always sorted in
 [ascending](#greater-than)
 [key](#key) order. In the case of
 `source` being an
 [index](#index-concept),
 `records` is secondarily sorted in
 [ascending](#greater-than)
 [value](#value) order (where the
 value in an [index](#index-concept) is the [key](#key)
 of the [record](#object-store-record) in the referenced [object
 store](#object-store)).

5. Let `range` be `cursor`'s
 [range](#cursor-range).

6. Let `position` be `cursor`'s
 [position](#cursor-position).

7. Let `object store position` be `cursor`'s
 [object store
 position](#cursor-object-store-position).

8. If `count` is not given, let `count` be 1.

9. While `count` is greater than 0:

 1. Switch on `direction`:

 \"[`next`](#dom-idbcursordirection-next)\"

 : Let `found record` be the first record in
 `records` which satisfy all of the following
 requirements:

 - If `key` is defined:

 - The record's key is [greater
 than](#greater-than) or [equal
 to](#equal-to)
 `key`.

 - If `primaryKey` is defined:

 - The record's key is [equal
 to](#equal-to)
 `key` and the record's value is [greater
 than](#greater-than) or [equal
 to](#equal-to)
 `primaryKey`

 - The record's key is [greater
 than](#greater-than) `key`.

 - If `position` is defined and
 `source` is an [object
 store](#object-store):

 - The record's key is [greater
 than](#greater-than) `position`.

 - If `position` is defined and
 `source` is an
 [index](#index-concept):

 - The record's key is [equal
 to](#equal-to)
 `position` and the record's value is [greater
 than](#greater-than) `object store position`

 - The record's key is [greater
 than](#greater-than) `position`.

 - The record's key is [in](#in) `range`.

 \"[`nextunique`](#dom-idbcursordirection-nextunique)\"

 : Let `found record` be the first record in
 `records` which satisfy all of the following
 requirements:

 - If `key` is defined:

 - The record's key is [greater
 than](#greater-than) or [equal
 to](#equal-to)
 `key`.

 - If `position` is defined:

 - The record's key is [greater
 than](#greater-than) `position`.

 - The record's key is [in](#in) `range`.

 \"[`prev`](#dom-idbcursordirection-prev)\"

 : Let `found record` be the last record in
 `records` which satisfy all of the following
 requirements:

 - If `key` is defined:

 - The record's key is [less
 than](#less-than)
 or [equal to](#equal-to) `key`.

 - If `primaryKey` is defined:

 - The record's key is [equal
 to](#equal-to)
 `key` and the record's value is [less
 than](#less-than)
 or [equal to](#equal-to) `primaryKey`

 - The record's key is [less
 than](#less-than)
 `key`.

 - If `position` is defined and
 `source` is an [object
 store](#object-store):

 - The record's key is [less
 than](#less-than)
 `position`.

 - If `position` is defined and
 `source` is an
 [index](#index-concept):

 - The record's key is [equal
 to](#equal-to)
 `position` and the record's value is [less
 than](#less-than)
 `object store position`

 - The record's key is [less
 than](#less-than)
 `position`.

 - The record's key is [in](#in) `range`.

 \"[`prevunique`](#dom-idbcursordirection-prevunique)\"

 : Let `temp record` be the last record in
 `records` which satisfy all of the following
 requirements:

 - If `key` is defined:

 - The record's key is [less
 than](#less-than)
 or [equal to](#equal-to) `key`.

 - If `position` is defined:

 - The record's key is [less
 than](#less-than)
 `position`.

 - The record's key is [in](#in) `range`.

 If `temp record` is defined, let
 `found record` be the first record in
 `records` whose [key](#key) is [equal
 to](#equal-to)
 `temp record`'s [key](#key).

 [NOTE:] Iterating with
 \"[`prevunique`](#dom-idbcursordirection-prevunique)\" visits the same records that
 \"[`nextunique`](#dom-idbcursordirection-nextunique)\" visits, but in reverse order.

 2. If `found record` is not defined, then:

 1. Set `cursor`'s
 [key](#cursor-key) to
 undefined.

 2. If `source` is an
 [index](#index-concept), set `cursor`'s [object store
 position](#cursor-object-store-position) to undefined.

 3. If `cursor`'s [key only
 flag](#cursor-key-only-flag) is false, set `cursor`'s
 [value](#cursor-value) to undefined.

 4. Return null.

 3. Let `position` be `found record`'s key.

 4. If `source` is an
 [index](#index-concept), let `object store position` be
 `found record`'s value.

 5. Decrease `count` by 1.

10. Set `cursor`'s
 [position](#cursor-position) to `position`.

11. If `source` is an
 [index](#index-concept),
 set `cursor`'s [object store
 position](#cursor-object-store-position) to `object store position`.

12. Set `cursor`'s [key](#cursor-key) to `found record`'s key.

13. If `cursor`'s [key only
 flag](#cursor-key-only-flag) is false, then:

 1. Let `serialized` be `found record`'s
 [value](#value) if
 `source` is an [object
 store](#object-store),
 or `found record`'s [referenced
 value](#index-referenced-value) otherwise.

 2. Set `cursor`'s
 [value](#cursor-value)
 to
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serialized`,
 `targetRealm`)

14. Set `cursor`'s [got value
 flag](#cursor-got-value-flag) to true.

15. Return `cursor`.

## 7. ECMAScript binding

This section defines how [key](#key)
values defined in this specification are converted to and from
ECMAScript values, and how they may be extracted from and injected into
ECMAScript values using [key paths](#key-path). This section references types and algorithms and uses
some algorithm conventions from the ECMAScript Language Specification.
[\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification")
Conversions not detailed here are defined in
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard").

### 7.1. Extract a key from a value

To [extract a key from a value using a key
path] with `value`,
`keyPath` and an optional `multiEntry flag`, run
the following steps. The result of these steps is a
[key](#key), invalid, or failure, or
the steps may throw an exception.

1. Let `r` be the result of [evaluating a key path on a
 value](#evaluate-a-key-path-on-a-value) with `value` and `keyPath`.
 Rethrow any exceptions.

2. If `r` is failure, return failure.

3. Let `key` be the result of [converting a value to a
 key](#convert-a-value-to-a-key) with `r` if the
 `multiEntry flag` is false, and the result of [converting
 a value to a multiEntry
 key](#convert-a-value-to-a-multientry-key) with `r` otherwise. Rethrow any
 exceptions.

4. If `key` is \"invalid value\" or \"invalid type\", return
 invalid.

5. Return `key`.

To [evaluate a key path on a value] with `value` and
`keyPath`, run the following steps. The result of these steps
is an ECMAScript value or failure, or the steps may throw an exception.

1. If `keyPath` is a
 [list](https://infra.spec.whatwg.org/#list) of strings, then:

 1. Let `result` be a new
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects) object created as if by the expression ``.

 2. Let `i` be 0.

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `item` of `keyPath`:

 1. Let `key` be the result of recursively
 [evaluating a key path on a
 value](#evaluate-a-key-path-on-a-value) with `item` and
 `value`.

 2. [Assert](https://infra.spec.whatwg.org/#assert): `key` is not an [abrupt
 completion](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-completion-record-specification-type).

 3. If `key` is failure, abort the overall algorithm
 and return failure.

 4. Let `p` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tostring)(`i`).

 5. Let `status` be
 [CreateDataProperty](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdataproperty)(`result`,
 `p`, `key`).

 6. [Assert](https://infra.spec.whatwg.org/#assert): `status` is true.

 7. Increase `i` by 1.

 4. Return `result`.

 [NOTE:] This will only ever \"recurse\" one level since
 [key path](#key-path)
 sequences can't ever be nested.

2. If `keyPath` is the empty string, return
 `value` and skip the remaining steps.

3. Let `identifiers` be the result of [strictly
 splitting](https://infra.spec.whatwg.org/#strictly-split) `keyPath` on U+002E FULL STOP characters
 (.).

4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `identifier` of
 `identifiers`, jump to the appropriate step below:

 If [Type](https://tc39.github.io/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is String, and `identifier` is \"`length`\"

 : Let `value` be a Number equal to the number of
 elements in `value`.

 If `value` is an [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects) and `identifier` is \"`length`\"

 : Let `value` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToLength](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tolength)([!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`value`, \"`length`\")).

 If `value` is a [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob) and `identifier` is \"`size`\"

 : Let `value` be a Number equal to `value`'s
 [`size`](https://w3c.github.io/FileAPI/#dfn-size).

 If `value` is a [`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob) and `identifier` is \"`type`\"

 : Let `value` be a String equal to `value`'s
 [`type`](https://w3c.github.io/FileAPI/#dfn-type).

 If `value` is a [`File`](https://w3c.github.io/FileAPI/#dfn-file) and `identifier` is \"`name`\"

 : Let `value` be a String equal to `value`'s
 [`name`](https://w3c.github.io/FileAPI/#dfn-name).

 If `value` is a [`File`](https://w3c.github.io/FileAPI/#dfn-file) and `identifier` is \"`lastModified`\"

 : Let `value` be a Number equal to `value`'s
 [`lastModified`](https://w3c.github.io/FileAPI/#dfn-lastModified).

 Otherwise

 : 1. If
 [Type](https://tc39.github.io/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is not Object, return
 failure.

 2. Let `hop` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [HasOwnProperty](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-hasownproperty)(`value`,
 `identifier`).

 3. If `hop` is false, return failure.

 4. Let `value` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`value`,
 `identifier`).

 5. If `value` is undefined, return failure.

5. [Assert](https://infra.spec.whatwg.org/#assert): `value` is not an [abrupt
 completion](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-completion-record-specification-type).

6. Return `value`.

[NOTE:] Assertions can be made in the above steps because this
algorithm is only applied to values that are the output of
[StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize) and only access \"own\" properties.

### 7.2. Inject a key into a value

[NOTE:] The [key paths](#key-path) used in this section are always strings and never
sequences, since it is not possible to create a [object
store](#object-store) which
has a [key generator](#key-generator) and also has a [key
path](#object-store-key-path) that is a sequence.

To [check that a key could be injected into a
value] with `value` and a
`keyPath`, run the following steps. The result of these steps
is either true or false.

1. Let `identifiers` be the result of [strictly
 splitting](https://infra.spec.whatwg.org/#strictly-split) `keyPath` on U+002E FULL STOP characters
 (.).

2. [Assert](https://infra.spec.whatwg.org/#assert): `identifiers` is not empty.

3. Remove the last
 [item](https://infra.spec.whatwg.org/#list-item) of `identifiers`.

4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) remaining `identifier` of
 `identifiers`, if any:

 1. If `value` is not an
 [`Object`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-object-objects) or an
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects), return false.

 2. Let `hop` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [HasOwnProperty](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-hasownproperty)(`value`,
 `identifier`).

 3. If `hop` is false, return true.

 4. Let `value` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`value`,
 `identifier`).

5. Return true if `value` is an
 [`Object`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-object-objects) or an
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects), or false otherwise.

[NOTE:] Assertions can be made in the above steps because this
algorithm is only applied to values that are the output of
[StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize).

To [inject a key into a value using a key
path] with `value`, a `key`
and a `keyPath`, run these steps:

1. Let `identifiers` be the result of [strictly
 splitting](https://infra.spec.whatwg.org/#strictly-split) `keyPath` on U+002E FULL STOP characters
 (.).

2. [Assert](https://infra.spec.whatwg.org/#assert): `identifiers` is not empty.

3. Let `last` be the last
 [item](https://infra.spec.whatwg.org/#list-item) of `identifiers` and remove it from the
 list.

4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) remaining `identifier` of
 `identifiers`:

 1. [Assert](https://infra.spec.whatwg.org/#assert): `value` is an
 [`Object`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-object-objects) or an
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects).

 2. Let `hop` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [HasOwnProperty](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-hasownproperty)(`value`,
 `identifier`).

 3. If `hop` is false, then:

 1. Let `o` be a new
 [`Object`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-object-objects) created as if by the expression `()`.

 2. Let `status` be
 [CreateDataProperty](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdataproperty)(`value`,
 `identifier`, `o`).

 3. [Assert](https://infra.spec.whatwg.org/#assert): `status` is true.

 4. Let `value` be
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`value`,
 `identifier`).

5. [Assert](https://infra.spec.whatwg.org/#assert): `value` is an
 [`Object`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-object-objects) or an
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects).

6. Let `keyValue` be the result of [converting a key to a
 value](#convert-a-key-to-a-value) with `key`.

7. Let `status` be
 [CreateDataProperty](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdataproperty)(`value`, `last`,
 `keyValue`).

8. [Assert](https://infra.spec.whatwg.org/#assert): `status` is true.

[NOTE:] Assertions can be made in the above steps because this
algorithm is only applied to values that are the output of
[StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize), and the steps to [check that a key could be
injected into a
value](#check-that-a-key-could-be-injected-into-a-value) have been run.

### 7.3. Convert a key to a value

To [convert a key to a value] with `key`, run the
following steps. The steps return an ECMAScript value.

1. Let `type` be `key`'s
 [type](#key-type).

2. Let `value` be `key`'s
 [value](#key-value).

3. Switch on `type`:

 *number*

 : Return an ECMAScript Number value equal to `value`

 *string*

 : Return an ECMAScript String value equal to `value`

 *date*

 : 1. Let `date` be the result of executing the
 ECMAScript Date constructor with the single argument
 `value`.

 2. [Assert](https://infra.spec.whatwg.org/#assert): `date` is not an [abrupt
 completion](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-completion-record-specification-type).

 3. Return `date`.

 *binary*

 : 1. Let `len` be `value`'s
 [length](https://infra.spec.whatwg.org/#byte-sequence-length).

 2. Let `buffer` be the result of executing the
 ECMAScript ArrayBuffer constructor with `len`.

 3. [Assert](https://infra.spec.whatwg.org/#assert): `buffer` is not an [abrupt
 completion](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-completion-record-specification-type).

 4. Set the entries in `buffer`'s
 \[\[ArrayBufferData\]\] internal slot to the entries in
 `value`.

 5. Return `buffer`.

 *array*

 : 1. Let `array` be the result of executing the
 ECMAScript Array constructor with no arguments.

 2. [Assert](https://infra.spec.whatwg.org/#assert): `array` is not an [abrupt
 completion](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-completion-record-specification-type).

 3. Let `len` be `value`'s
 [size](https://infra.spec.whatwg.org/#list-size).

 4. Let `index` be 0.

 5. While `index` is less than `len`:

 1. Let `entry` be the result of [converting a
 key to a
 value](#convert-a-key-to-a-value) with
 `value`\[`index`\].

 2. Let `status` be
 [CreateDataProperty](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdataproperty)(`array`,
 `index`, `entry`).

 3. [Assert](https://infra.spec.whatwg.org/#assert): `status` is true.

 4. Increase `index` by 1.

 6. Return `array`.

### 7.4. Convert a value to a key

To [convert a value to a key] with an ECMAScript value
`input`, and an optional
[set](https://infra.spec.whatwg.org/#ordered-set) `seen`, run the following steps. The result
of these steps is a [key](#key), or
\"invalid value\", or \"invalid type\", or the steps may throw an
exception.

1. If `seen` was not given, then let `seen` be a
 new empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. If `seen`
 [contains](https://infra.spec.whatwg.org/#list-contain) `input`, then return \"invalid value\".

3. Jump to the appropriate step below:

 If [Type](https://tc39.github.io/ecma262/#sec-ecmascript-data-types-and-values)(`input`) is Number

 : 1. If `input` is NaN then return \"invalid value\".

 2. Otherwise, return a new [key](#key) with [type](#key-type) *number* and
 [value](#key-value)
 `input`.

 If `input` is a [`Date`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-date-objects) (has a \[\[DateValue\]\] internal slot)

 : 1. Let `ms` be the value of `input`'s
 \[\[DateValue\]\] internal slot.

 2. If `ms` is NaN then return \"invalid value\".

 3. Otherwise, return a new [key](#key) with [type](#key-type) *date* and
 [value](#key-value)
 `ms`.

 If [Type](https://tc39.github.io/ecma262/#sec-ecmascript-data-types-and-values)(`input`) is String

 : 1. Return a new [key](#key)
 with [type](#key-type)
 *string* and [value](#key-value) `input`.

 If `input` is a [buffer source type](https://webidl.spec.whatwg.org/#dfn-buffer-source-type)

 : 1. If `input` is
 [detached](https://webidl.spec.whatwg.org/#buffersource-detached) then return \"invalid value\".

 2. Let `bytes` be the result of [getting a copy of
 the bytes held by the buffer
 source](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) `input`.

 3. Return a new [key](#key)
 with [type](#key-type)
 *binary* and [value](#key-value) `bytes`.

 If `input` is an [Array exotic object](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#array-exotic-object)

 : 1. Let `len` be
 [?](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToLength](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tolength)(
 [?](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`input`, \"`length`\")).

 2. [Append](https://infra.spec.whatwg.org/#set-append) `input` to `seen`.

 3. Let `keys` be a new empty list.

 4. Let `index` be 0.

 5. While `index` is less than `len`:

 1. Let `hop` be
 [?](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [HasOwnProperty](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-hasownproperty)(`input`,
 `index`).

 2. If `hop` is false, return \"invalid value\".

 3. Let `entry` be
 [?](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`input`,
 `index`).

 4. Let `key` be the result of [converting a
 value to a
 key](#convert-a-value-to-a-key) with arguments `entry` and
 `seen`.

 5. [ReturnIfAbrupt](https://tc39.github.io/ecma262/#sec-returnifabrupt)(`key`).

 6. If `key` is \"invalid value\" or \"invalid
 type\" abort these steps and return \"invalid value\".

 7. [Append](https://infra.spec.whatwg.org/#list-append) `key` to `keys`.

 8. Increase `index` by 1.

 6. Return a new [array key](#array-key) with
 [value](#key-value)
 `keys`.

 Otherwise

 : Return \"invalid type\".

To [convert a value to a multiEntry
key] with an ECMAScript value `input`,
run the following steps. The result of these steps is a
[key](#key), or \"invalid value\", or
\"invalid type\", or the steps may throw an exception.

1. If `input` is an [Array exotic
 object](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#array-exotic-object), then:

 1. Let `len` be
 [?](https://tc39.github.io/ecma262/#sec-algorithm-conventions) ToLength(
 [?](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`input`, \"`length`\")).

 2. Let `seen` be a new
 [set](https://infra.spec.whatwg.org/#ordered-set) containing only `input`.

 3. Let `keys` be a new empty
 [list](https://infra.spec.whatwg.org/#list).

 4. Let `index` be 0.

 5. While `index` is less than `len`:

 1. Let `entry` be
 [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`input`,
 `index`).

 2. If `entry` is not an [abrupt
 completion](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-completion-record-specification-type), then:

 1. Let `key` be the result of [converting a
 value to a
 key](#convert-a-value-to-a-key) with arguments `entry` and
 `seen`.

 2. If `key` is not \"invalid value\" or
 \"invalid type\" or an [abrupt
 completion](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-completion-record-specification-type), and there is no
 [item](https://infra.spec.whatwg.org/#list-item) in `keys` [equal
 to](#equal-to)
 `key`, then
 [append](https://infra.spec.whatwg.org/#list-append) `key` to `keys`.

 3. Increase `index` by 1.

 6. Return a new [array key](#array-key) with [value](#key-value) set to `keys`.

2. Otherwise, return the result of [converting a value to a
 key](#convert-a-value-to-a-key) with argument `input`. Rethrow any
 exceptions.

[NOTE:] These steps are similar to those to [convert a value to
a key](#convert-a-value-to-a-key) but if the top-level value is an
[`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects) then members which can not be converted to keys are
ignored, and duplicates are removed.

For example, the value `[10, 20, null, 30, 20]` is converted to an
[array key](#array-key) with
[subkeys](#subkeys) 10, 20, 30.

## 8. Privacy considerations

*This section is non-normative.*

### 8.1. User tracking

A third-party host (or any object capable of getting content distributed
to multiple sites) could use a unique identifier stored in its
client-side database to track a user across multiple sessions, building
a profile of the user's activities. In conjunction with a site that is
aware of the user's real id object (for example an e-commerce site that
requires authenticated credentials), this could allow oppressive groups
to target individuals with greater accuracy than in a world with purely
anonymous Web usage.

There are a number of techniques that can be used to mitigate the risk
of user tracking:

Blocking third-party storage

: User agents may restrict access to the database objects to scripts
 originating at the domain of the top-level document of the browsing
 context, for instance denying access to the API for pages from other
 domains running in `iframe`s.

Expiring stored data

: User agents may automatically delete stored data after a period of
 time.

 This can restrict the ability of a site to track a user, as the site
 would then only be able to track the user across multiple sessions
 when she authenticates with the site itself (e.g. by making a
 purchase or logging in to a service).

 However, this also puts the user's data at risk.

Treating persistent storage as cookies

: User agents should present the database feature to the user in a way
 that associates them strongly with HTTP session cookies.
 [\[COOKIES\]](#biblio-cookies "HTTP State Management Mechanism")

 This might encourage users to view such storage with healthy
 suspicion.

Site-specific safe-listing of access to databases

: User agents may require the user to authorize access to databases
 before a site can use the feature.

Attribution of third-party storage

: User agents may record the
 [origins](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) of sites that contained content from third-party
 [origins](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) that caused data to be stored.

 If this information is then used to present the view of data
 currently in persistent storage, it would allow the user to make
 informed decisions about which parts of the persistent storage to
 prune. Combined with a blocklist (\"delete this data and prevent
 this domain from ever storing data again\"), the user can restrict
 the use of persistent storage to sites that she trusts.

Shared blocklists

: User agents may allow users to share their persistent storage domain
 blocklists.

 This would allow communities to act together to protect their
 privacy.

While these suggestions prevent trivial use of this API for user
tracking, they do not block it altogether. Within a single domain, a
site can continue to track the user during a session, and can then pass
all this information to the third party along with any identifying
information (names, credit card numbers, addresses) obtained by the
site. If a third party cooperates with multiple sites to obtain such
information, a profile can still be created.

However, user tracking is to some extent possible even with no
cooperation from the user agent whatsoever, for instance by using
session identifiers in URLs, a technique already commonly used for
innocuous purposes but easily repurposed for user tracking (even
retroactively). This information can then be shared with other sites,
using visitors\' IP addresses and other user-specific data (e.g.
user-agent headers and configuration settings) to combine separate
sessions into coherent user profiles.

### 8.2. Cookie resurrection

If the user interface for persistent storage presents data in the
persistent storage features described in this specification separately
from data in HTTP session cookies, then users are likely to delete data
in one and not the other. This would allow sites to use the two features
as redundant backup for each other, defeating a user's attempts to
protect his privacy.

### 8.3. Sensitivity of data

User agents should treat persistently stored data as potentially
sensitive; it is quite possible for e-mails, calendar appointments,
health records, or other confidential documents to be stored in this
mechanism.

To this end, user agents should ensure that when deleting data, it is
promptly deleted from the underlying storage.

## 9. Security considerations

### 9.1. DNS spoofing attacks

Because of the potential for DNS spoofing attacks, one cannot guarantee
that a host claiming to be in a certain domain really is from that
domain. To mitigate this, pages can use TLS. Pages using TLS can be sure
that only pages using TLS that have certificates identifying them as
being from the same domain can access their databases.

### 9.2. Cross-directory attacks

Different authors sharing one host name, for example users hosting
content on `geocities.com`, all share one set of databases.

There is no feature to restrict the access by pathname. Authors on
shared hosts are therefore recommended to avoid using these features, as
it would be trivial for other authors to read the data and overwrite it.

[NOTE:] Even if a path-restriction feature was made available,
the usual DOM scripting security model would make it trivial to bypass
this protection and access the data from any path.

### 9.3. Implementation risks

The two primary risks when implementing these persistent storage
features are letting hostile sites read information from other domains,
and letting hostile sites write information that is then read from other
domains.

Letting third-party sites read data that is not supposed to be read from
their domain causes *information leakage*, For example, a user's
shopping wish list on one domain could be used by another domain for
targeted advertising; or a user's work-in-progress confidential
documents stored by a word-processing site could be examined by the site
of a competing company.

Letting third-party sites write data to the persistent storage of other
domains can result in *information spoofing*, which is equally
dangerous. For example, a hostile site could add records to a user's
wish list; or a hostile site could set a user's session identifier to a
known ID that the hostile site can then use to track the user's actions
on the victim site.

Thus, strictly following the storage key partitioning model described in
this specification is important for user security.

If host names or database names are used to construct paths for
persistence to a file system they must be appropriately escaped to
prevent an adversary from accessing information from other [storage
keys](https://storage.spec.whatwg.org/#storage-key) using relative paths such as \"`../`\".

### 9.4. Persistence risks

Practical implementations will persist data to a non-volatile storage
medium. Data will be serialized when stored and deserialized when
retrieved, although the details of the serialization format will be
user-agent specific. User agents are likely to change their
serialization format over time. For example, the format may be updated
to handle new data types, or to improve performance. To satisfy the
operational requirements of this specification, implementations must
therefore handle older serialization formats in some way. Improper
handling of older data can result in security issues. In addition to
basic serialization concerns, serialized data could encode assumptions
which are not valid in newer versions of the user agent.

A practical example of this is the
[`RegExp`](https://tc39.es/ecma262/multipage/text-processing.html#sec-regexp-regular-expression-objects) type. The
[StructuredSerializeForStorage](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializeforstorage) operation allows serializing
[`RegExp`](https://tc39.es/ecma262/multipage/text-processing.html#sec-regexp-regular-expression-objects) objects. A typical user agent will compile a regular
expression into native machine instructions, with assumptions about how
the input data is passed and results returned. If this internal state
was serialized as part of the data stored to the database, various
problems could arise when the internal representation was later
deserialized. For example, the means by which data was passed into the
code could have changed. Security bugs in the compiler output could have
been identified and fixed in updates to the user agent, but remain in
the serialized internal state.

User agents must identify and handle older data appropriately. One
approach is to include version identifiers in the serialization format,
and to reconstruct any internal state from script-visible state when
older data is encountered.

## 10. Accessibility considerations

*This section is non-normative.*

The API described by this specification has limited accesibility
considerations:

- It does not provide for visual rendering of content, or control over
 color.

- It does not provide features to accept user input.

- It does not provide user interaction features.

- It does not define document semantics.

- It does not provide time-based visual media.

- It does not allow time limits.

- It does not directly provide content for end-users, either in textual,
 graphical or other or non-textual form.

- It does not define a transmission protocol.

The API does allow storage of structured content. Textual content can be
stored as strings. Support exists in the API for developers to store
alternative non-textual content such as images or audio as
[`Blob`](https://w3c.github.io/FileAPI/#dfn-Blob),
[`File`](https://w3c.github.io/FileAPI/#dfn-file), or
[`ImageData`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagedata) objects. Developers producing dynamic content
applications using the API should ensure that the content is accessible
to users with a variety of technologies and needs.

While the API itself does not define a specific mechanism for it,
storage of structured content also allows developers to store
internationalized content, using different records or structure within
records to hold language alternatives.

The API does not define or require any a user agent to generate a user
interface to enable interaction with the API. User agents may optionally
provide user interface elements to support the API. Examples include
prompts to users when additional storage quota is required,
functionality to observe storage used by particular web sites, or tools
specific to the API's storage such as inspecting, modifying, or deleting
records. Any such user interface elements must be designed with
accessibility tools in mind. For example, a user interface presenting
the fraction of storage quota used in graphical form must also provide
the same data to tools such as screen readers.

## 11. Revision history

*This section is non-normative.*

The following is an informative summary of the changes since the last
publication of this specification. A complete revision history can be
found [here](https://github.com/w3c/IndexedDB/). For the revision
history of the first edition, see [that document's Revision
History](https://www.w3.org/TR/2015/REC-IndexedDB-20150108/#revision-history).
For the revision history of the second edition, see [that document's
Revision History](https://www.w3.org/TR/IndexedDB-2/#revision-history).

- The [cleanup Indexed Database
 transactions](#cleanup-indexed-database-transactions) algorithm now returns a value for integration with
 other specs. ([PR #232](https://github.com/w3c/IndexedDB/pull/232))

- Updated [partial interface definition](#global-scope) since
 [`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope) is now a `mixin`. ([PR
 #238](https://github.com/w3c/IndexedDB/pull/238))

- Added
 [`databases()`](#dom-idbfactory-databases) method. ([issue
 #31](https://github.com/w3c/IndexedDB/issues/31))

- Added
 [`commit()`](#dom-idbtransaction-commit) method. ([issue
 #234](https://github.com/w3c/IndexedDB/issues/234))

- Added
 [`request`](#dom-idbcursor-request) attribute. ([issue
 #255](https://github.com/w3c/IndexedDB/issues/255))

- Removed handling for nonstandard `lastModifiedDate` property of
 [`File`](https://w3c.github.io/FileAPI/#dfn-file) objects. ([issue
 #215](https://github.com/w3c/IndexedDB/issues/215))

- Remove escaping
 [`includes()`](#dom-idbkeyrange-includes) method. ([issue
 #294](https://github.com/w3c/IndexedDB/issues/294))

- Restrict array keys to [Array exotic
 objects](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#array-exotic-object) (i.e. disallow proxies). ([issue
 #309](https://github.com/w3c/IndexedDB/issues/309))

- Transactions are now temporarily made inactive during clone
 operations. ([PR #310](https://github.com/w3c/IndexedDB/pull/310))

- Added
 [`durability`](#dom-idbtransactionoptions-durability) option and
 [`durability`](#dom-idbtransaction-durability) attribute. ([issue
 #50](https://github.com/w3c/IndexedDB/issues/50))

- Specified [§ 2.7.2 Transaction scheduling](#transaction-scheduling)
 more precisely and disallow starting read/write transactions while
 read-only transactions with overlapping scope are running. ([issue
 #253](https://github.com/w3c/IndexedDB/issues/253))

- Added [Accessibility considerations](#accessibility) section. ([issue
 #327](https://github.com/w3c/IndexedDB/issues/327))

- Used [\[infra\]](#biblio-infra "Infra Standard")'s
 list sorting definition. ([issue
 #346](https://github.com/w3c/IndexedDB/issues/346))

- Added a definition for
 [live](#transaction-live)
 transactions, and renamed \"run an upgrade transaction\" to [upgrade a
 database](#upgrade-a-database), to disambiguate \"running\". ([issue
 #408](https://github.com/w3c/IndexedDB/issues/408))

- Specified the
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) type for failures when reading a value from the
 underlying storage in [§ 6.2 Object store retrieval
 operations](#object-store-retrieval-operation). ([issue
 #423](https://github.com/w3c/IndexedDB/issues/423))

- Updated [convert a value to a
 key](#convert-a-value-to-a-key) to return invalid for detached array buffers. ([issue
 #417](https://github.com/w3c/IndexedDB/issues/417))

- Updated
 [`open()`](#dom-idbfactory-open) to set its request's [processed
 flag](#request-processed-flag) to true. ([issue
 #434](https://github.com/w3c/IndexedDB/issues/434))

- Don't include databases that aren't done being created in
 [`databases()`](#dom-idbfactory-databases). ([issue
 #442](https://github.com/w3c/IndexedDB/issues/442))

- Clarify that only
 [inactive](#transaction-inactive)
 [transactions](#transaction-concept) should attempt to auto-commit. ([issue
 #436](https://github.com/w3c/IndexedDB/issues/436))

- Correct [upgrade a
 database](#upgrade-a-database) steps to handle aborted transactions. ([issue
 #436](https://github.com/w3c/IndexedDB/issues/436))

- Update [iterate a
 cursor](#iterate-a-cursor)
 value serialization to use [value](#value) for [object
 stores](#object-store)
 instead of [referenced
 values](#index-referenced-value). ([issue
 #452](https://github.com/w3c/IndexedDB/issues/452))

- Add [source
 handle](#cursor-source-handle) to [cursor](#cursor) to avoid exposing internal indexes and object stores
 to script. ([issue #445](https://github.com/w3c/IndexedDB/issues/445))

- Define [Queue a database
 task](#queue-a-database-task) and replace [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) with it ([issue
 #421](https://github.com/w3c/IndexedDB/issues/421))

- Add missing parallel step to
 [`databases`](#dom-idbfactory-databases)() ([issue
 #421](https://github.com/w3c/IndexedDB/issues/421))

- Clarify cursor iteration predicates ([issue
 #450](https://github.com/w3c/IndexedDB/issues/450))

- Add
 [`getAllRecords(options)`](#dom-idbobjectstore-getallrecords) method to
 [`IDBObjectStore`](#idbobjectstore) and [`IDBIndex`](#idbindex). ([issue
 #206](https://github.com/w3c/IndexedDB/issues/206))

- Add direction option to
 [`getAll()`](#dom-idbobjectstore-getall) and
 [`getAllKeys()`](#dom-idbobjectstore-getallkeys) for
 [`IDBObjectStore`](#idbobjectstore) and [`IDBIndex`](#idbindex) ([issue
 #130](https://github.com/w3c/IndexedDB/issues/130))

- Use of
 [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror) has been updated to reflect that it is now a
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)-derived interface instead of an exception name.
 ([issue #463](https://github.com/w3c/IndexedDB/issues/463))

- Specify that null is valid for
 [error](#transaction-error), and allow it to be set in [abort a
 transaction](#abort-a-transaction) ([issue
 #433](https://github.com/w3c/IndexedDB/issues/433))

- Check the [request](#request)'s
 [error](#request-error)
 instead of the [upgrade
 transaction](#upgrade-transaction) in [open a database
 connection](#open-a-database-connection). ([issue
 #433](https://github.com/w3c/IndexedDB/issues/433))

- Remove redundant transaction state change in
 [`abort()`](#dom-idbtransaction-abort).

## 12. Acknowledgements

*This section is non-normative.*

Special thanks to Nikunj Mehta, the original author of the first
edition, and Jonas Sicking, Eliot Graff, Andrei Popescu, and Jeremy
Orlow, additional editors of the first edition.

Garret Swart was extremely influential in the design of this
specification.

Thanks to Tab Atkins, Jr. for creating and maintaining
[Bikeshed](https://github.com/tabatkins/bikeshed), the specification
authoring tool used to create this document, and for his general
authoring advice.

Special thanks to Abhishek Shanthkumar, Adam Klein, Addison Phillips,
Adrienne Walker, Alec Flett, Andrea Marchesini, Andreas Butler, Andrew
Sutherland, Anne van Kesteren, Anthony Ramine, Ari Chivukula, Arun
Ranganathan, Ben Dilts, Ben Turner, Bevis Tseng, Boris Zbarsky, Brett
Zamir, Chris Anderson, Dana Florescu, Danillo Paiva, David Grogan,
Domenic Denicola, Dominique Hazael-Massieux, Evan Stade, Glenn Maynard,
Hans Wennborg, Isiah Meadows, Israel Hilerio, Jake Archibald, Jake Drew,
Jerome Hode, Josh Matthews, João Eiras, Kagami Sascha Rosylight,
Kang-Hao Lu, Kris Zyp, Kristof Degrave, Kyaw Tun, Kyle Huey,
Laxminarayan G Kamath A, Maciej Stachowiak, Marcos Cáceres, Margo
Seltzer, Marijn Kruisselbrink, Ms2ger, Odin Omdal, Olli Pettay, Pablo
Castro, Philip Jägenstedt, Shawn Wilsher, Simon Pieters, Steffen
Larssen, Steve Becker, Tobie Langel, Victor Costan, Xiaoqian Wu, Yannic
Bonenberger, Yaron Tausky, Yonathan Randolph, and Zhiqiang Zhang, all of
whose feedback and suggestions have led to improvements to this
specification.
