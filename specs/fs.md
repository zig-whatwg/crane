# Introduction

*This section is non-normative.*

This document defines fundamental infrastructure for file system APIs. In addition, it defines an API that makes it possible for websites to get access to a file system directory without having to first prompt the user for access. This enables use cases where a website wants to save data to disk before a user has picked a location to save to, without forcing the website to use a completely different storage mechanism with a different API for such files. The entry point for this is the `navigator.storage.getDirectory()` method.


## Files and Directories


### Concepts

A **file system entry** is either a **file entry** or a **directory entry**.

Each **file system entry** has an associated **query access** algorithm, which takes "`read`" or "`readwrite`" `mode` and returns a **file system access result**. Unless specified otherwise it returns a **file system access result** with a **permission state** of "`denied`" and with an **error name** of the empty string.

Each **file system entry** has an associated **request access** algorithm, which takes "`read`" or "`readwrite`" `mode` and returns a **file system access result**. Unless specified otherwise it returns a **file system access result** with a **permission state** of "`denied`" and with an **error name** of the empty string.

A **file system access result** is a struct encapsulating the result of querying or requesting access to the file system. It has the following items:

**permission state**
: A `PermissionState`

**error name**
: A string which must be the empty string if **permission state** is "`granted`"; otherwise an name listed in the `DOMException` names table. It is expected that in most cases when **permission state** is not "`granted`", this should be "`NotAllowedError`".

Dependent specifications may consider this API a powerful feature. However, unlike other powerful features whose permission request algorithm may throw, **file system entry**'s **query access** and **request access** algorithms must run in parallel on the **file system queue** and are therefore not allowed to throw. Instead, the caller is expected to queue a storage task to reject, as appropriate, should these algorithms return an **error name** other than the empty string.

Note: Implementations that only implement this specification and not dependent specifications do not need to bother implementing **file system entry**'s **query access** and **request access**.

Each **file system entry** has an associated **name** (a string).

A **valid file name** is a string that is not an empty string, is not equal to "." or "..", and does not contain '/' or any other character used as path separator on the underlying platform.

Note: This means that '\\' is not allowed in names on Windows, but might be allowed on other operating systems. Additionally underlying file systems might have further restrictions on what names are or aren't allowed, so a string merely being a **valid file name** is not a guarantee that creating a file or directory with that name will succeed.

A **file entry** additionally consists of **binary data** (a byte sequence), a **modification timestamp** (a number representing the number of milliseconds since the Unix Epoch), a **lock** (a string that may exclusively be "`open`", "`taken-exclusive`" or "`taken-shared`") and a **shared lock count** (a number representing the number shared locks that are taken at a given point in time).

A user agent has an associated **file system queue** which is the result of starting a new parallel queue. This queue is to be used for all file system operations.

To **take** a **lock** with a `value` of "`exclusive`" or "`shared`" on a given **file entry** `file`:

1. Let `lock` be the `file`'s **lock**.
2. Let `count` be the `file`'s **shared lock count**.
3. If `value` is "`exclusive`":
   1. If `lock` is "`open`":
      1. Set lock to "`taken-exclusive`".
      2. Return "`success`".
4. If `value` is "`shared`":
   1. If `lock` is "`open`":
      1. Set `lock` to "`taken-shared`".
      2. Set `count` to 1.
      3. Return "`success`".
   2. Otherwise, if `lock` is "`taken-shared`":
      1. Increase `count` by 1.
      2. Return "`success`".
5. Return "`failure`".

Note: These steps have to be run on the **file system queue**.

To **release** a **lock** on a given **file entry** `file`:

1. Let `lock` be the `file`'s associated **lock**.
2. Let `count` be the `file`'s **shared lock count**.
3. If `lock` is "`taken-shared`":
   1. Decrease `count` by 1.
   2. If `count` is 0, set `lock` to "`open`".
4. Otherwise, set `lock` to "`open`".

Note: These steps have to be run on the **file system queue**.

Note: Locks help prevent concurrent modifications to a file. A `FileSystemWritableFileStream` requires a shared lock, while a `FileSystemSyncAccessHandle` requires an exclusive one.

A **directory entry** additionally consists of a set of **children**, which are themselves **file system entries**. Each member is either a **file entry** or a **directory entry**.

A **file system entry** `entry` should be contained in the **children** of at most one **directory entry**, and that directory entry is also known as `entry`'s **parent**. A **file system entry**'s **parent** is null if no such directory entry exists.

Note: Two different **file system entries** can represent the same file or directory on disk, in which case it is possible for both entries to have a different parent, or for one entry to have a parent while the other entry does not have a parent.

**File system entries** can (but don't have to) be backed by files on the host operating system's local file system, so it is possible for the **binary data**, **modification timestamp**, and **children** of entries to be modified by applications outside of this specification. Exactly how external changes are reflected in the data structures defined by this specification, as well as how changes made to the data structures defined here are reflected externally is left up to individual user-agent implementations.

A **file system entry** `a` is **the same entry as** a **file system entry** `b` if `a` is equal to `b`, or if `a` and `b` are backed by the same file or directory on the local file system.

To **resolve** a **file system locator** `child` relative to a **directory locator** `root`:

1. Let `result` be a new promise.
2. Enqueue the following steps to the **file system queue**:
   1. If `child`'s **locator**'s **root** is not `root`'s **locator**'s **root**, resolve `result` with null, and abort these steps.
   2. Let `childPath` be `child`'s **locator**'s **path**.
   3. Let `rootPath` be `root`'s **locator**'s **path**.
   4. If `childPath` is **the same path as** `rootPath`, resolve `result` with « », and abort these steps.
   5. If `rootPath`'s size is greater than `childPath`'s size, resolve `result` with null, and abort these steps.
   6. For each `index` of `rootPath`'s indices:
      1. If `rootPath`[[`index`]] is not `childPath`[[`index`]], then resolve `result` with null, and abort these steps.
   7. Let `relativePath` be « ».
   8. For each `index` of the range from `rootPath`'s size to `rootPath`'s size, exclusive, append `childPath`[[`index`]] to `relativePath`.
   9. Resolve `result` with `relativePath`.
3. Return `result`.

A **file system locator** represents a potential location of a **file system entry**. A **file system locator** is either a **file locator** or a **directory locator**.

Each **file system locator** has an associated **path** (a **file system path**), a **kind** (a `FileSystemHandleKind`), and a **root** (a **file system root**).

A **file locator** is a **file system locator** whose **kind** is "`file`". A **directory locator** is a **file system locator** whose **kind** is "`directory`".

A **file system root** is an opaque string whose value is implementation-defined.

For a **file system locator** `locator` whichs locates to a **file entry** `entry` that conceptually exists at the path `data/drafts/example.txt` relative to the root directory of a bucket file system, `locator`'s **kind** has to be "`file`", `locator`'s **path** has to be « "`data`", "`drafts`", "`example.txt`" », and `locator`'s **root** might include relevant identifying information such as the storage bucket and the disk drive.

A **file system locator** `a` is **the same locator as** a **file system locator** `b` if `a`'s **kind** is `b`'s **kind**, `a`'s **root** is `b`'s **root**, and `a`'s **path** is **the same path as** `b`'s **path**.

The **locate an entry** algorithm given a **file system locator** `locator` runs an implementation-defined series of steps adhering to these constraints:

- If `locator` is a **file locator**, they return a **file entry** or null.
- If `locator` is a **directory locator**, they return a **directory entry** or null.
- If these steps return a non-null `entry`, then:
  - **Getting the locator** with `entry` returns `locator`, provided no intermediate file system operations were run.
  - `entry`'s **name** is the last item of `locator`'s **path**.

The **get the locator** algorithm given **file system entry** `entry` runs an implementation-defined series of steps adhering to these constraints:

- If `entry` is a **file entry**, they return a **file locator**.
- If `entry` is a **directory entry**, they return a **directory locator**.
- If these steps return `locator`, then:
  - **Locating an entry** with `locator` returns `entry`, provided no intermediate file system operations were run.
  - `entry`'s **name** is the last item of `locator`'s **path**.

A **file system path** is a list of one or more strings. This may be a virtual path that is mapped to real location on disk or in memory, may correspond directly to a path on the local file system, or may not correspond to any file on disk at all. The actual physical location of the corresponding **file system entry** is implementation-defined.

Let `path` be the list « "`data`", "`drafts`", "`example.txt`" ». There is no expectation that a file named `example.txt` exists anywhere on disk.

A **file system path** `a` is **the same path as** a **file system path** `b` if `a`'s size is the same as `b`'s size and for each `index` of `a`'s indices `a`[[`index`]] is `b`[[`index`]].

The contents of a **file system locator**, including its **path**, are not expected to be shared in their entirety with the website process. The **file system path** might contain components which are not known to the website unless the **file system locator** is later resolved relative to a parent **directory locator**.


### The `FileSystemHandle` interface

```idl
enum FileSystemHandleKind {
  "file",
  "directory",
};

[Exposed=(Window,Worker), SecureContext, Serializable]
interface FileSystemHandle {
  readonly attribute FileSystemHandleKind kind;
  readonly attribute USVString name;

  Promise<boolean> isSameEntry(FileSystemHandle other);
};
```

A `FileSystemHandle` object is associated with a **locator** (a **file system locator**).

Note: Multiple `FileSystemHandle` objects can have the same **file system locator**.

A `FileSystemHandle` **is in a bucket file system** if the first item of its **locator**'s **path** is the empty string.

Note: This is a bit magical, but it works since only the root directory of a bucket file system can have a **path** which contains an empty string. See `getDirectory()`. All other item of a **path** will be a **valid file name**.

`FileSystemHandle` objects are serializable objects.

Their serialization steps, given `value`, `serialized` and `forStorage` are:

1. Set `serialized`.[[Origin]] to `value`'s relevant settings object's origin.
2. Set `serialized`.[[Locator]] to `value`'s **locator**.

Their deserialization steps, given `serialized` and `value` are:

1. If `serialized`.[[Origin]] is not same origin with `value`'s relevant settings object's origin, then throw a "`DataCloneError`" `DOMException`.
2. Set `value`'s **locator** to `serialized`.[[Locator]].

`handle` . `kind`

: Returns "`file`" if `handle` is a `FileSystemFileHandle`, or "`directory`" if `handle` is a `FileSystemDirectoryHandle`.

  This can be used to distinguish files from directories when iterating over the contents of a directory.

`handle` . `name`

: Returns the last path component of `handle`'s **locator**'s **path**.

The `kind` getter steps are to return this's **locator**'s **kind**.

The `name` getter steps are to return the last item (a string) of this's **locator**'s **path**.


#### The `isSameEntry()` method

`same` = await `handle1` . `isSameEntry`( `handle2` )

: Returns true if `handle1` and `handle2` represent the same file or directory.

The `isSameEntry(other)` method steps are:

1. Let `realm` be this's relevant Realm.
2. Let `p` be a new promise in `realm`.
3. Enqueue the following steps to the **file system queue**:
   1. If this's **locator** is **the same locator as** `other`'s **locator**, resolve `p` with true.
   2. Otherwise resolve `p` with false.
4. Return `p`.


### The `FileSystemFileHandle` interface

```idl
dictionary FileSystemCreateWritableOptions {
  boolean keepExistingData = false;
};

[Exposed=(Window,Worker), SecureContext, Serializable]
interface FileSystemFileHandle : FileSystemHandle {
  Promise<File> getFile();
  Promise<FileSystemWritableFileStream> createWritable(optional FileSystemCreateWritableOptions options = {});
  [Exposed=DedicatedWorker]
  Promise<FileSystemSyncAccessHandle> createSyncAccessHandle();
};
```

Note: A `FileSystemFileHandle`'s associated **locator**'s **kind** is "`file`".

To **create a child `FileSystemFileHandle`** given a **directory locator** `parentLocator` and a string `name` in a Realm `realm`:

1. Let `handle` be a new `FileSystemFileHandle` in `realm`.
2. Let `childType` be "`file`".
3. Let `childRoot` be a copy of `parentLocator`'s **root**.
4. Let `childPath` be the result of cloning `parentLocator`'s **path** and appending `name`.
5. Set `handle`'s **locator** to a **file system locator** whose **kind** is `childType`, **root** is `childRoot`, and **path** is `childPath`.
6. Return `handle`.

To **create a new `FileSystemFileHandle`** given a **file system root** `root` and a **file system path** `path` in a Realm `realm`:

1. Let `handle` be a new `FileSystemFileHandle` in `realm`.
2. Set `handle`'s **locator** to a **file system locator** whose **kind** is "`file`", **root** is `root`, and **path** is `path`.
3. Return `handle`.

`FileSystemFileHandle` objects are serializable objects. Their serialization steps and deserialization steps are the same as those for `FileSystemHandle`.


#### The `getFile()` method

`file` = await `fileHandle` . `getFile()`

: Returns a `File` representing the state on disk of the **file entry** locatable by `handle`'s **locator**. If the file on disk changes or is removed after this method is called, the returned `File` object will likely be no longer readable.

The `getFile()` method steps are:

1. Let `result` be a new promise.
2. Let `locator` be this's **locator**.
3. Let `global` be this's relevant global object.
4. Enqueue the following steps to the **file system queue**:
   1. Let `entry` be the result of **locating an entry** given `locator`.
   2. Let `accessResult` be the result of running `entry`'s **query access** given "`read`".
   3. Queue a storage task with `global` to run these steps:
      1. If `accessResult`'s **permission state** is not "`granted`", reject `result` with a `DOMException` of `accessResult`'s **error name** and abort these steps.
      2. If `entry` is null, reject `result` with a "`NotFoundError`" `DOMException` and abort these steps.
      3. Assert: `entry` is a **file entry**.
      4. Let `f` be a new `File`.
      5. Set `f`'s snapshot state to the current state of `entry`.
      6. Set `f`'s underlying byte sequence to a copy of `entry`'s **binary data**.
      7. Set `f`'s `name` to `entry`'s **name**.
      8. Set `f`'s `lastModified` to `entry`'s **modification timestamp**.
      9. Set `f`'s `type` to an implementation-defined value, based on for example `entry`'s **name** or its file extension.
      10. Resolve `result` with `f`.
5. Return `result`.


#### The `createWritable()` method

`stream` = await `fileHandle` . `createWritable()`
`stream` = await `fileHandle` . `createWritable`({ `keepExistingData`: true/false })

: Returns a `FileSystemWritableFileStream` that can be used to write to the file. Any changes made through `stream` won't be reflected in the **file entry** locatable by `fileHandle`'s **locator** until the stream has been closed. User agents try to ensure that no partial writes happen, i.e. the file will either contain its old contents or it will contain whatever data was written through `stream` up until the stream has been closed.

  This is typically implemented by writing data to a temporary file, and only replacing the **file entry** locatable by `fileHandle`'s **locator** with the temporary file when the writable filestream is closed.

  If `keepExistingData` is false or not specified, the temporary file starts out empty, otherwise the existing file is first copied to this temporary file.

  Creating a `FileSystemWritableFileStream` **takes a shared lock** on the **file entry** locatable with `fileHandle`'s **locator**. This prevents the creation of `FileSystemSyncAccessHandles` for the entry, until the stream is closed.

The `createWritable(options)` method steps are:

1. Let `result` be a new promise.
2. Let `locator` be this's **locator**.
3. Let `realm` be this's relevant Realm.
4. Let `global` be this's relevant global object.
5. Enqueue the following steps to the **file system queue**:
   1. Let `entry` be the result of **locating an entry** given `locator`.
   2. Let `accessResult` be the result of running `entry`'s **request access** given "`readwrite`".
   3. If `accessResult`'s **permission state** is not "`granted`", queue a storage task with `global` to reject `result` with a `DOMException` of `accessResult`'s **error name** and abort these steps.
   4. If `entry` is `null`, queue a storage task with `global` to reject `result` with a "`NotFoundError`" `DOMException` and abort these steps.
   5. Assert: `entry` is a **file entry**.
   6. Let `lockResult` be the result of **taking a lock** with "`shared`" on `entry`.
   7. Queue a storage task with `global` to run these steps:
      1. If `lockResult` is "`failure`", reject `result` with a "`NoModificationAllowedError`" `DOMException` and abort these steps.
      2. Let `stream` be the result of **creating a new `FileSystemWritableFileStream`** for `entry` in `realm`.
      3. If `options`["`keepExistingData`"] is true:
         1. Set `stream`'s [[buffer]] to a copy of `entry`'s **binary data**.
      4. Resolve `result` with `stream`.
6. Return `result`.


#### The `createSyncAccessHandle()` method

`handle` = await `fileHandle` . `createSyncAccessHandle`()

: Returns a `FileSystemSyncAccessHandle` that can be used to read from/write to the file. Changes made through `handle` might be immediately reflected in the **file entry** locatable by `fileHandle`'s **locator**. To ensure the changes are reflected in this file, the handle can be flushed.

  Creating a `FileSystemSyncAccessHandle` **takes an exclusive lock** on the **file entry** locatable with `fileHandle`'s **locator**. This prevents the creation of further `FileSystemSyncAccessHandles` or `FileSystemWritableFileStreams` for the entry, until the access handle is closed.

  The returned `FileSystemSyncAccessHandle` offers synchronous methods. This allows for higher performance on contexts where asynchronous operations come with high overhead, e.g., WebAssembly.

  For the time being, this method will only succeed when the `fileHandle` **is in a bucket file system**.

The `createSyncAccessHandle()` method steps are:

1. Let `result` be a new promise.
2. Let `locator` be this's **locator**.
3. Let `realm` be this's relevant Realm.
4. Let `global` be this's relevant global object.
5. Let `isInABucketFileSystem` be true if this **is in a bucket file system**; otherwise false.
6. Enqueue the following steps to the **file system queue**:
   1. Let `entry` be the result of **locating an entry** given `locator`.
   2. Let `accessResult` be the result of running `entry`'s **request access** given "`readwrite`".
   3. If `accessResult`'s **permission state** is not "`granted`", queue a storage task with `global` to reject `result` with a `DOMException` of `accessResult`'s **error name** and abort these steps.
   4. If `isInABucketFileSystem` is false, queue a storage task with `global` to reject `result` with an "`InvalidStateError`" `DOMException` and abort these steps.
   5. If `entry` is `null`, queue a storage task with `global` to reject `result` with a "`NotFoundError`" `DOMException` and abort these steps.
   6. Assert: `entry` is a **file entry**.
   7. Let `lockResult` be the result of **taking a lock** with "`exclusive`" on `entry`.
   8. Queue a storage task with `global` to run these steps:
      1. If `lockResult` is "`failure`", reject `result` with a "`NoModificationAllowedError`" `DOMException` and abort these steps.
      2. Let `handle` be the result of **creating a new `FileSystemSyncAccessHandle`** for `entry` in `realm`.
      3. Resolve `result` with `handle`.
7. Return `result`.


### The `FileSystemDirectoryHandle` interface

```idl
dictionary FileSystemGetFileOptions {
  boolean create = false;
};

dictionary FileSystemGetDirectoryOptions {
  boolean create = false;
};

dictionary FileSystemRemoveOptions {
  boolean recursive = false;
};

[Exposed=(Window,Worker), SecureContext, Serializable]
interface FileSystemDirectoryHandle : FileSystemHandle {
  async_iterable<USVString, FileSystemHandle>;

  Promise<FileSystemFileHandle> getFileHandle(USVString name, optional FileSystemGetFileOptions options = {});
  Promise<FileSystemDirectoryHandle> getDirectoryHandle(USVString name, optional FileSystemGetDirectoryOptions options = {});

  Promise<undefined> removeEntry(USVString name, optional FileSystemRemoveOptions options = {});

  Promise<sequence<USVString>?> resolve(FileSystemHandle possibleDescendant);
};
```

Note: A `FileSystemDirectoryHandle`'s associated **locator**'s **kind** is "`directory`".

To **create a child `FileSystemDirectoryHandle`** given a **directory locator** `parentLocator` and a string `name` in a Realm `realm`:

1. Let `handle` be a new `FileSystemDirectoryHandle` in `realm`.
2. Let `childType` be "`directory`".
3. Let `childRoot` be a copy of `parentLocator`'s **root**.
4. Let `childPath` be the result of cloning `parentLocator`'s **path** and appending `name`.
5. Set `handle`'s **locator** to a **file system locator** whose **kind** is `childType`, **root** is `childRoot`, and **path** is `childPath`.
6. Return `handle`.

To **create a new `FileSystemDirectoryHandle`** given a **file system root** `root` and a **file system path** `path` in a Realm `realm`:

1. Let `handle` be a new `FileSystemDirectoryHandle` in `realm`.
2. Set `handle`'s **locator** to a **file system locator** whose **kind** is "`directory`", **root** is `root`, and **path** is `path`.
3. Return `handle`.

`FileSystemDirectoryHandle` objects are serializable objects. Their serialization steps and deserialization steps are the same as those for `FileSystemHandle`.


#### Directory iteration

for await (let [`name`, `handle`] of `directoryHandle`) {}
for await (let [`name`, `handle`] of `directoryHandle` . entries()) {}
for await (let `handle` of `directoryHandle` . values()) {}
for await (let `name` of `directoryHandle` . keys()) {}

: Iterates over all entries whose parent is the **directory entry** locatable by `directoryHandle`'s **locator**. Entries that are created or deleted while the iteration is in progress might or might not be included. No guarantees are given either way.

The asynchronous iterator initialization steps for a `FileSystemDirectoryHandle` `handle` and its async iterator `iterator` are:

1. Set `iterator`'s **past results** to an empty set.

To get the next iteration result for a `FileSystemDirectoryHandle` `handle` and its async iterator `iterator`:

1. Let `promise` be a new promise.
2. Enqueue the following steps to the **file system queue**:
   1. Let `directory` be the result of **locating an entry** given `handle`'s **locator**.
   2. Let `accessResult` be the result of running `directory`'s **query access** given "`read`".
   3. Queue a storage task with `handle`'s relevant global object to run these steps:
      1. If `accessResult`'s **permission state** is not "`granted`", reject `promise` with a `DOMException` of `accessResult`'s **error name** and abort these steps.:
      2. If `directory` is `null`, reject `result` with a "`NotFoundError`" `DOMException` and abort these steps.
         1. Assert: `directory` is a **directory entry**.
      3. Let `child` be a **file system entry** in `directory`'s **children**, such that `child`'s **name** is not contained in `iterator`'s **past results**, or `null` if no such entry exists.
         
         Note: This is intentionally very vague about the iteration order. Different platforms and file systems provide different guarantees about iteration order, and we want it to be possible to efficiently implement this on all platforms. As such no guarantees are given about the exact order in which elements are returned.
      4. If `child` is `null`, resolve `promise` with `undefined` and abort these steps.
      5. Append `child`'s **name** to `iterator`'s **past results**.
      6. If `child` is a **file entry**:
         1. Let `result` be the result of **creating a child `FileSystemFileHandle`** with `handle`'s **locator** and `child`'s **name** in `handle`'s relevant Realm.
      7. Otherwise:
         1. Let `result` be the result of **creating a child `FileSystemDirectoryHandle`** with `handle`'s **locator** and `child`'s **name** in `handle`'s relevant Realm.
      8. Resolve `promise` with (`child`'s **name**, `result`).
3. Return `promise`.


#### The `getFileHandle()` method

`fileHandle` = await `directoryHandle` . `getFileHandle`(`name`)
`fileHandle` = await `directoryHandle` . `getFileHandle`(`name`, { `create`: false })

: Returns a handle for a file named `name` in the **directory entry** locatable by `directoryHandle`'s **locator**. If no such file exists, this rejects.

`fileHandle` = await `directoryHandle` . `getFileHandle`(`name`, { `create`: true })

: Returns a handle for a file named `name` in the **directory entry** locatable by `directoryHandle`'s **locator**. If no such file exists, this creates a new file. If no file with named `name` can be created this rejects. Creation can fail because there already is a directory with the same name, because the name uses characters that aren't supported in file names on the underlying file system, or because the user agent for security reasons decided not to allow creation of the file.

  This operation requires write permission, even if the file being returned already exists. If this handle doesn't already have write permission, this could result in a prompt being shown to the user. To get an existing file without needing write permission, call this method with `{ `create`: false }`.

The `getFileHandle(name, options)` method steps are:

1. Let `result` be a new promise.
2. Let `realm` be this's relevant Realm.
3. Let `locator` be this's **locator**.
4. Let `global` be this's relevant global object.
5. Enqueue the following steps to the **file system queue**:
   1. If `name` is not a **valid file name**, queue a storage task with `global` to reject `result` with a `TypeError` and abort these steps.
   2. Let `entry` be the result of **locating an entry** given `locator`.
   3. If `options`["`create`"] is true:
      1. Let `accessResult` be the result of running `entry`'s **request access** given "`readwrite`".
   4. Otherwise:
      1. Let `accessResult` be the result of running `entry`'s **query access** given "`read`".
   5. Queue a storage task with `global` to run these steps:
      1. If `accessResult`'s **permission state** is not "`granted`", reject `result` with a `DOMException` of `accessResult`'s **error name** and abort these steps.
      2. If `entry` is `null`, reject `result` with a "`NotFoundError`" `DOMException` and abort these steps.
      3. Assert: `entry` is a **directory entry**.
      4. For each `child` of `entry`'s **children**:
         1. If `child`'s **name** equals `name`:
            1. If `child` is a **directory entry**:
               1. Reject `result` with a "`TypeMismatchError`" `DOMException` and abort these steps.
            2. Resolve `result` with the result of **creating a child `FileSystemFileHandle`** with `locator` and `child`'s **name** in `realm` and abort these steps.
      5. If `options`["`create`"] is false:
         1. Reject `result` with a "`NotFoundError`" `DOMException` and abort these steps.
      6. Let `child` be a new **file entry** whose **query access** and **request access** algorithms are those of `entry`.
      7. Set `child`'s **name** to `name`.
      8. Set `child`'s **binary data** to an empty byte sequence.
      9. Set `child`'s **modification timestamp** to the current time.
      10. Append `child` to `entry`'s **children**.
      11. If creating `child` in the underlying file system throws an exception, reject `result` with that exception and abort these steps.
      12. Resolve `result` with the result of **creating a child `FileSystemFileHandle`** with `locator` and `child`'s **name** in `realm`.
6. Return `result`.


#### The `getDirectoryHandle()` method

`subdirHandle` = await `directoryHandle` . `getDirectoryHandle`(`name`)
`subdirHandle` = await `directoryHandle` . `getDirectoryHandle`(`name`, { `create`: false })

: Returns a handle for a directory named `name` in the **directory entry** locatable by `directoryHandle`'s **locator**. If no such directory exists, this rejects.

`subdirHandle` = await `directoryHandle` . `getDirectoryHandle`(`name`, { `create`: true })

: Returns a handle for a directory named `name` in the **directory entry** locatable by `directoryHandle`'s **locator** . If no such directory exists, this creates a new directory. If creating the directory failed, this rejects. Creation can fail because there already is a file with the same name, or because the name uses characters that aren't supported in file names on the underlying file system.

  This operation requires write permission, even if the directory being returned already exists. If this handle doesn't already have write permission, this could result in a prompt being shown to the user. To get an existing directory without needing write permission, call this method with `{ `create`: false }`.

The `getDirectoryHandle(name, options)` method steps are:

1. Let `result` be a new promise.
2. Let `realm` be this's relevant Realm.
3. Let `locator` be this's **locator**.
4. Let `global` be this's relevant global object.
5. Enqueue the following steps to the **file system queue**:
   1. If `name` is not a **valid file name**, queue a storage task with `global` to reject `result` with a `TypeError` and abort these steps.
   2. Let `entry` be the result of **locating an entry** given `locator`.
   3. If `options`["`create`"] is true:
      1. Let `accessResult` be the result of running `entry`'s **request access** given "`readwrite`".
   4. Otherwise:
      1. Let `accessResult` be the result of running `entry`'s **query access** given "`read`".
   5. Queue a storage task with `global` to run these steps:
      1. If `accessResult`'s **permission state** is not "`granted`", reject `result` with a `DOMException` of `accessResult`'s **error name** and abort these steps.
      2. If `entry` is `null`, reject `result` with a "`NotFoundError`" `DOMException` and abort these steps.
      3. Assert: `entry` is a **directory entry**.
      4. For each `child` of `entry`'s **children**:
         1. If `child`'s **name** equals `name`:
            1. If `child` is a **file entry**:
               1. Reject `result` with a "`TypeMismatchError`" `DOMException` and abort these steps.
            2. Resolve `result` with the result of **creating a child `FileSystemDirectoryHandle`** with `locator` and `child`'s **name** in `realm` and abort these steps.
      5. If `options`["`create`"] is false:
         1. Reject `result` with a "`NotFoundError`" `DOMException` and abort these steps.
      6. Let `child` be a new **directory entry** whose **query access** and **request access** algorithms are those of `entry`.
      7. Set `child`'s **name** to `name`.
      8. Set `child`'s **children** to an empty set.
      9. Append `child` to `entry`'s **children**.
      10. If creating `child` in the underlying file system throws an exception, reject `result` with that exception and abort these steps.
      11. Resolve `result` with the result of **creating a child `FileSystemDirectoryHandle`** with `locator` and `child`'s **name** in `realm`.
6. Return `result`.


#### The `removeEntry()` method

await `directoryHandle` . `removeEntry`(`name`)
await `directoryHandle` . `removeEntry`(`name`, { `recursive`: false })

: If the **directory entry** locatable by `directoryHandle`'s **locator** contains a file named `name`, or an empty directory named `name`, this will attempt to delete that file or directory.

  Attempting to delete a file or directory that does not exist is considered success, while attempting to delete a non-empty directory will result in a promise rejection.

await `directoryHandle` . `removeEntry`(`name`, { `recursive`: true })

: Removes the **file system entry** named `name` in the **directory entry** locatable by `directoryHandle`'s **locator**. If that entry is a directory, its contents will also be deleted recursively.

  Attempting to delete a file or directory that does not exist is considered success.

The `removeEntry(name, options)` method steps are:

1. Let `result` be a new promise.
2. Let `locator` be this's **locator**.
3. Let `global` be this's relevant global object.
4. Enqueue the following steps to the **file system queue**:
   1. If `name` is not a **valid file name**, queue a storage task with `global` to reject `result` with a `TypeError` and abort these steps.
   2. Let `entry` be the result of **locating an entry** given `locator`.
   3. Let `accessResult` be the result of running `entry`'s **request access** given "`readwrite`".
   4. Queue a storage task with `global` to run these steps:
      1. If `accessResult`'s **permission state** is not "`granted`", reject `result` with a `DOMException` of `accessResult`'s **error name** and abort these steps.
      2. If `entry` is `null`, reject `result` with a "`NotFoundError`" `DOMException` and abort these steps.
      3. Assert: `entry` is a **directory entry**.
      4. For each `child` of `entry`'s **children**:
         1. If `child`'s **name** equals `name`:
            1. If `child` is a **directory entry**:
               1. If `child`'s **children** is not empty and `options`["`recursive`"] is false:
                  1. Reject `result` with an "`InvalidModificationError`" `DOMException` and abort these steps.
            2. Remove `child` from `entry`'s **children**.
            3. If removing `child` in the underlying file system throws an exception, reject `result` with that exception and abort these steps.
               
               Note: If `recursive` is true, the removal can fail non-atomically. Some files or directories might have been removed while other files or directories still exist.
            4. Resolve `result` with `undefined`.
      5. Reject `result` with a "`NotFoundError`" `DOMException`.
5. Return `result`.


#### The `resolve()` method

`path` = await `directory` . `resolve`( `child` )

: If `child` is equal to `directory`, `path` will be an empty array.

: If `child` is a direct child of `directory`, `path` will be an array containing `child`'s name.

: If `child` is a descendant of `directory`, `path` will be an array containing the names of all the intermediate directories and `child`'s name as last element. For example if `directory` represents `/home/user/project` and `child` represents `/home/user/project/foo/bar`, this will return `['foo', 'bar']`.

: Otherwise (`directory` and `child` are not related), `path` will be null.

```javascript
// Assume we at some point got a valid directory handle.
const dir_ref = current_project_dir;
if (!dir_ref) return;

// Now get a file reference:
const file_ref = await dir_ref.getFileHandle(filename, { create: true });

// Check if file_ref exists inside dir_ref:
const relative_path = await dir_ref.resolve(file_ref);
if (relative_path === null) {
    // Not inside dir_ref.
} else {
    // relative_path is an array of names, giving the relative path
    // from dir_ref to the file that is represented by file_ref:
    assert relative_path.pop() === file_ref.name;

    let entry = dir_ref;
    for (const name of relative_path) {
        entry = await entry.getDirectory(name);
    }
    entry = await entry.getFile(file_ref.name);

    // Now |entry| will represent the same file on disk as |file_ref|.
    assert await entry.isSameEntry(file_ref) === true;
}
```

The `resolve(possibleDescendant)` method steps are to return the result of **resolving** `possibleDescendant`'s **locator** relative to this's **locator**.


### The `FileSystemWritableFileStream` interface

```idl
enum WriteCommandType {
  "write",
  "seek",
  "truncate",
};

dictionary WriteParams {
  required WriteCommandType type;
  unsigned long long? size;
  unsigned long long? position;
  (BufferSource or Blob or USVString)? data;
};

typedef (BufferSource or Blob or USVString or WriteParams) FileSystemWriteChunkType;

[Exposed=(Window,Worker), SecureContext]
interface FileSystemWritableFileStream : WritableStream {
  Promise<undefined> write(FileSystemWriteChunkType data);
  Promise<undefined> seek(unsigned long long position);
  Promise<undefined> truncate(unsigned long long size);
};
```

A `FileSystemWritableFileStream` has an associated **[[file]]** (a **file entry**).

A `FileSystemWritableFileStream` has an associated **[[buffer]]** (a byte sequence). It is initially empty.

Note: This buffer can get arbitrarily large, so it is expected that implementations will not keep this in memory, but instead use a temporary file for this. All access to [[buffer]] is done in promise returning methods and algorithms, so even though operations on it seem sync, implementations can implement them async.

A `FileSystemWritableFileStream` has an associated **[[seekOffset]]** (a number). It is initially 0.

A `FileSystemWritableFileStream` object is a `WritableStream` object with additional convenience methods, which operates on a single file on disk.

Upon creation, an underlying sink will have been created and the stream will be usable. All operations executed on the stream are queuable and producers will be able to respond to backpressure.

The underlying sink's write method, and therefore `WritableStreamDefaultWriter's write()` method, will accept byte-like data or `WriteParams` as input.

The `FileSystemWritableFileStream` has a file position cursor initialized at byte offset 0 from the top of the file. When using `write()` or by using WritableStream capabilities through the `WritableStreamDefaultWriter's write()` method, this position will be advanced based on the number of bytes written through the stream object.

Similarly, when piping a `ReadableStream` into a `FileSystemWritableFileStream` object, this position is updated with the number of bytes that passed through the stream.

`getWriter()` returns an instance of `WritableStreamDefaultWriter`.

To **create a new `FileSystemWritableFileStream`** given a **file entry** `file` in a Realm `realm`:

1. Let `stream` be a new `FileSystemWritableFileStream` in `realm`.
2. Set `stream`'s **[[file]]** to `file`.
3. Let `writeAlgorithm` be an algorithm which takes a `chunk` argument and returns the result of running the **write a chunk** algorithm with `stream` and `chunk`.
4. Let `closeAlgorithm` be these steps:
   1. Let `closeResult` be a new promise.
   2. Enqueue the following steps to the **file system queue**:
      1. Let `accessResult` be the result of running `file`'s **query access** given "`readwrite`".
      2. Queue a storage task with `file`'s relevant global object to run these steps:
         1. If `accessResult`'s **permission state** is not "`granted`", reject `closeResult` with a `DOMException` of `accessResult`'s **error name** and abort these steps.
         2. Run implementation-defined malware scans and safe browsing checks. If these checks fail, reject `closeResult` with an "`AbortError`" `DOMException` and abort these steps.
         3. Set `stream`'s **[[file]]**'s **binary data** to `stream`'s **[[buffer]]**. If that throws an exception, reject `closeResult` with that exception and abort these steps.
            
            Note: It is expected that this atomically updates the contents of the file on disk being written to.
         4. Enqueue the following steps to the **file system queue**:
            1. **Release the lock** on `stream`'s **[[file]]**.
            2. Queue a storage task with `file`'s relevant global object to resolve `closeResult` with `undefined`.
   3. Return `closeResult`.
5. Let `abortAlgorithm` be these steps:
   1. Enqueue this step to the **file system queue**:
      1. **Release the lock** on `stream`'s **[[file]]**.
6. Let `highWaterMark` be 1.
7. Let `sizeAlgorithm` be an algorithm that returns `1`.
8. Set up `stream` with `writeAlgorithm` set to `writeAlgorithm`, `closeAlgorithm` set to `closeAlgorithm`, `abortAlgorithm` set to `abortAlgorithm`, `highWaterMark` set to `highWaterMark`, and `sizeAlgorithm` set to `sizeAlgorithm`.
9. Return `stream`.

The **write a chunk** algorithm, given a `FileSystemWritableFileStream` `stream` and `chunk`, runs these steps:

1. Let `input` be the result of converting `chunk` to a `FileSystemWriteChunkType`. If this throws an exception, then return a promise rejected with that exception.
2. Let `p` be a new promise.
3. Enqueue the following steps to the **file system queue**:
   1. Let `accessResult` be the result of running `stream`'s **[[file]]**'s **query access** given "`readwrite`".
   2. Queue a storage task with `stream`'s relevant global object to run these steps:
      1. If `accessResult`'s **permission state** is not "`granted`", reject `p` with a `DOMException` of `accessResult`'s **error name** and abort these steps.
      2. Let `command` be `input`["`type`"] if `input` is a dictionary; otherwise "`write`".
      3. If `command` is "`write`":
         1. If `input` is `undefined` or `input` is a dictionary and `input`["`data`"] does not exist, reject `p` with a `TypeError` and abort these steps.
         2. Let `data` be `input`["`data`"] if `input` is a dictionary; otherwise `input`.
         3. Let `writePosition` be `stream`'s **[[seekOffset]]**.
         4. If `input` is a dictionary and `input`["`position`"] exists, set `writePosition` to `input`["`position`"].
         5. Let `oldSize` be `stream`'s **[[buffer]]**'s length.
         6. If `data` is a `BufferSource`, let `dataBytes` be a copy of `data`.
         7. Otherwise, if `data` is a `Blob`:
            1. Let `dataBytes` be the result of performing the read operation on `data`. If this throws an exception, reject `p` with that exception and abort these steps.
         8. Otherwise:
            1. Assert: `data` is a `USVString`.
            2. Let `dataBytes` be the result of UTF-8 encoding `data`.
         9. If `writePosition` is larger than `oldSize`, append `writePosition` - `oldSize` 0x00 (NUL) bytes to the end of `stream`'s **[[buffer]]**.
            
            Note: Implementations are expected to behave as if the skipped over file contents are indeed filled with NUL bytes. That doesn't mean these bytes have to actually be written to disk and take up disk space. Instead most file systems support so called sparse files, where these NUL bytes don't take up actual disk space.
         10. Let `head` be a byte sequence containing the first `writePosition` bytes of `stream`'s**[[buffer]]**.
         11. Let `tail` be an empty byte sequence.
         12. If `writePosition` + `data`'s length is smaller than `oldSize`:
             1. Let `tail` be a byte sequence containing the last `oldSize` - (`writePosition` + `data`'s length) bytes of `stream`'s **[[buffer]]**.
         13. Set `stream`'s **[[buffer]]** to the concatenation of `head`, `data` and `tail`.
         14. If the operations modifying `stream`'s **[[buffer]]** in the previous steps failed due to exceeding the storage quota, reject `p` with a `QuotaExceededError` and abort these steps, leaving `stream`'s **[[buffer]]** unmodified.
             
             Note: Storage quota only applies to files stored in a bucket file system. However this operation could still fail for other files, for example if the disk being written to runs out of disk space.
         15. Set `stream`'s **[[seekOffset]]** to `writePosition` + `data`'s length.
         16. Resolve `p`.
      4. Otherwise, if `command` is "`seek`":
         1. Assert: `chunk` is a dictionary.
         2. If `chunk`["`position`"] does not exist, reject `p` with a `TypeError` and abort these steps.
         3. Set `stream`'s **[[seekOffset]]** to `chunk`["`position`"].
         4. Resolve `p`.
      5. Otherwise, if `command` is "`truncate`":
         1. Assert: `chunk` is a dictionary.
         2. If `chunk`["`size`"] does not exist, reject `p` with a `TypeError` and abort these steps.
         3. Let `newSize` be `chunk`["`size`"].
         4. Let `oldSize` be `stream`'s **[[buffer]]**'s length.
         5. If `newSize` is larger than `oldSize`:
            1. Set `stream`'s **[[buffer]]** to a byte sequence formed by concating `stream`'s **[[buffer]]** with a byte sequence containing `newSize`-`oldSize` `0x00` bytes.
            2. If the operation in the previous step failed due to exceeding the storage quota, reject `p` with a `QuotaExceededError` and abort these steps, leaving `stream`'s **[[buffer]]** unmodified.
               
               Note: Storage quota only applies to files stored in a bucket file system. However this operation could still fail for other files, for example if the disk being written to runs out of disk space.
         6. Otherwise, if `newSize` is smaller than `oldSize`:
            1. Set `stream`'s **[[buffer]]** to a byte sequence containing the first `newSize` bytes in `stream`'s **[[buffer]]**.
         7. If `stream`'s **[[seekOffset]]** is bigger than `newSize`, set `stream`'s **[[seekOffset]]** to `newSize`.
         8. Resolve `p`.
4. Return `p`.


#### The `write()` method

await `stream` . `write`(`data`)
await `stream` . `write`({ `type`: "`write`", `data`: `data` })

: Writes the content of `data` into the file associated with `stream` at the current file cursor offset.

  No changes are written to the actual file on disk until the stream has been closed. Changes are typically written to a temporary file instead.

await `stream` . `write`({ `type`: "`write`", `position`: `position`, `data`: `data` })

: Writes the content of `data` into the file associated with `stream` at `position` bytes from the top of the file. Also updates the current file cursor offset to the end of the written data.

  No changes are written to the actual file on disk until the stream has been closed. Changes are typically written to a temporary file instead.

await `stream` . `write`({ `type`: "`seek`", `position`: `position` })

: Updates the current file cursor offset the `position` bytes from the top of the file.

await `stream` . `write`({ `type`: "`truncate`", `size`: `size` })

: Resizes the file associated with `stream` to be `size` bytes long. If `size` is larger than the current file size this pads the file with null bytes, otherwise it truncates the file.

  The file cursor is updated when `truncate` is called. If the cursor is smaller than `size`, it remains unchanged. If the cursor is larger than `size`, it is set to `size` to ensure that subsequent writes do not error.

  No changes are written to the actual file until on disk until the stream has been closed. Changes are typically written to a temporary file instead.

The `write(data)` method steps are:

1. Let `writer` be the result of getting a writer for this.
2. Let `result` be the result of writing a chunk to `writer` given `data`.
3. Release `writer`.
4. Return `result`.


#### The `seek()` method

await `stream` . `seek`(`position`)

: Updates the current file cursor offset the `position` bytes from the top of the file.

The `seek(position)` method steps are:

1. Let `writer` be the result of getting a writer for this.
2. Let `result` be the result of writing a chunk to `writer` given «[ "`type`" → "`seek`", "`position`" → `position` ]».
3. Release `writer`.
4. Return `result`.


#### The `truncate()` method

await `stream` . `truncate`(`size`)

: Resizes the file associated with `stream` to be `size` bytes long. If `size` is larger than the current file size this pads the file with null bytes, otherwise it truncates the file.

  The file cursor is updated when `truncate` is called. If the cursor is smaller than `size`, it remains unchanged. If the cursor is larger than `size`, it is set to `size` to ensure that subsequent writes do not error.

  No changes are written to the actual file until on disk until the stream has been closed. Changes are typically written to a temporary file instead.

The `truncate(size)` method steps are:

1. Let `writer` be the result of getting a writer for this.
2. Let `result` be the result of writing a chunk to `writer` given «[ "`type`" → "`truncate`", "`size`" → `size` ]».
3. Release `writer`.
4. Return `result`.


### The `FileSystemSyncAccessHandle` interface

```idl
dictionary FileSystemReadWriteOptions {
  [EnforceRange] unsigned long long at;
};

[Exposed=DedicatedWorker, SecureContext]
interface FileSystemSyncAccessHandle {
  unsigned long long read(AllowSharedBufferSource buffer,
                          optional FileSystemReadWriteOptions options = {});
  unsigned long long write(AllowSharedBufferSource buffer,
                           optional FileSystemReadWriteOptions options = {});

  undefined truncate([EnforceRange] unsigned long long newSize);
  unsigned long long getSize();
  undefined flush();
  undefined close();
};
```

A `FileSystemSyncAccessHandle` has an associated **[[file]]** (a **file entry**).

A `FileSystemSyncAccessHandle` has an associated **[[state]]**, a string that may exclusively be "`open`" or "`closed`".

A `FileSystemSyncAccessHandle` is an object that is capable of reading from/writing to, as well as obtaining and changing the size of, a single file.

A `FileSystemSyncAccessHandle` offers synchronous methods. This allows for higher performance on contexts where asynchronous operations come with high overhead, e.g., WebAssembly.

A `FileSystemSyncAccessHandle` has a **file position cursor** initialized at byte offset 0 from the top of the file.

To **create a new `FileSystemSyncAccessHandle`** given a **file entry** `file` in a Realm `realm`:

1. Let `handle` be a new `FileSystemSyncAccessHandle` in `realm`.
2. Set `handle`'s **[[file]]** to `file`.
3. Set `handle`'s **[[state]]** to "`open`".
4. Return `handle`.


#### The `read()` method

`handle` . `read`(`buffer`)
`handle` . `read`(`buffer`, { `at` })

: Reads the contents of the file associated with `handle` into `buffer`, optionally at a given offset.

: The file cursor is updated when `read()` is called to point to the byte after the last byte read.

The `read(buffer, FileSystemReadWriteOptions: options)` method steps are:

1. If this's **[[state]]** is "`closed`", throw an "`InvalidStateError`" `DOMException`.
2. Let `bufferSize` be `buffer`'s byte length.
3. Let `fileContents` be this's **[[file]]**'s **binary data**.
4. Let `fileSize` be `fileContents`'s length.
5. Let `readStart` be `options`["`at`"] if `options`["`at`"] exists; otherwise this's **file position cursor**.
6. If the underlying file system does not support reading from a file offset of `readStart`, throw a `TypeError`.
7. If `readStart` is larger than `fileSize`:
   1. Set this's **file position cursor** to `fileSize`.
   2. Return 0.
8. Let `readEnd` be `readStart` + (`bufferSize` − 1).
9. If `readEnd` is larger than `fileSize`, set `readEnd` to `fileSize`.
10. Let `bytes` be a byte sequence containing the bytes from `readStart` to `readEnd` of `fileContents`.
11. Let `result` be `bytes`'s length.
12. If the operations reading from `fileContents` in the previous steps failed:
    1. If there were partial reads and the number of bytes that were read into `bytes` is known, set `result` to the number of read bytes.
    2. Otherwise set `result` to 0.
13. Let `arrayBuffer` be `buffer`'s underlying buffer.
14. Write `bytes` into `arrayBuffer`.
15. Set this's **file position cursor** to `readStart` + `result`.
16. Return `result`.


#### The `write()` method

`handle` . `write`(`buffer`)
`handle` . `write`(`buffer`, { `at` })

: Writes the content of `buffer` into the file associated with `handle`, optionally at a given offset, and returns the number of written bytes. Checking the returned number of written bytes allows callers to detect and handle errors and partial writes.

: The file cursor is updated when `write` is called to point to the byte after the last byte written.

The `write(buffer, FileSystemReadWriteOptions: options)` method steps are:

1. If this's **[[state]]** is "`closed`", throw an "`InvalidStateError`" `DOMException`.
2. Let `writePosition` be `options`["`at`"] if `options`["`at`"] exists; otherwise this's **file position cursor**.
3. If the underlying file system does not support writing to a file offset of `writePosition`, throw a `TypeError`.
4. Let `fileContents` be a copy of this's **[[file]]**'s **binary data**.
5. Let `oldSize` be `fileContents`'s length.
6. Let `bufferSize` be `buffer`'s byte length.
7. If `writePosition` is larger than `oldSize`, append `writePosition` − `oldSize` 0x00 (NUL) bytes to the end of `fileContents`.
   
   Note: Implementations are expected to behave as if the skipped over file contents are indeed filled with NUL bytes. That doesn't mean these bytes have to actually be written to disk and take up disk space. Instead most file systems support so called sparse files, where these NUL bytes don't take up actual disk space.
8. Let `head` be a byte sequence containing the first `writePosition` bytes of `fileContents`.
9. Let `tail` be an empty byte sequence.
10. If `writePosition` + `bufferSize` is smaller than `oldSize`:
    1. Set `tail` to a byte sequence containing the last `oldSize` − (`writePosition` + `bufferSize`) bytes of `fileContents`.
11. Let `newSize` be `head`'s length + `bufferSize` + `tail`'s length.
12. If `newSize` − `oldSize` exceeds the available storage quota, throw a `QuotaExceededError`.
13. Set this's **[[file]]**'s **binary data** to the concatenation of `head`, the contents of `buffer` and `tail`.
    
    Note: The mechanism used to access buffer's contents is left purposely vague. It is likely that implementations will choose to focus on performance by issuing direct write calls to the host operating system (instead of creating a copy of buffer), which prevents a detailed specification of the write order and the results of partial writes.
14. If the operations modifying the this's**[[file]]**'s **binary data** in the previous steps failed:
    1. If there were partial writes and the number of bytes that were written from `buffer` is known:
       1. Let `bytesWritten` be the number of bytes that were written from `buffer`.
       2. Set this's **file position cursor** to `writePosition` + `bytesWritten`.
       3. Return `bytesWritten`.
    2. Otherwise throw an "`InvalidStateError`" `DOMException`.
15. Set this's **file position cursor** to `writePosition` + `bufferSize`.
16. Return `bufferSize`.


#### The `truncate()` method

`handle` . `truncate`(`newSize`)

: Resizes the file associated with `handle` to be `newSize` bytes long. If `newSize` is larger than the current file size this pads the file with null bytes; otherwise it truncates the file.

: The file cursor is updated when `truncate` is called. If the cursor is smaller than `newSize`, it remains unchanged. If the cursor is larger than `newSize`, it is set to `newSize`.

The `truncate(newSize)` method steps are:

1. If this's **[[state]]** is "`closed`", throw an "`InvalidStateError`" `DOMException`.
2. Let `fileContents` be a copy of this's **[[file]]**'s **binary data**.
3. Let `oldSize` be the length of this's **[[file]]**'s **binary data**.
4. If the underlying file system does not support setting a file's size to `newSize`, throw a `TypeError`.
5. If `newSize` is larger than `oldSize`:
   1. If `newSize` − `oldSize` exceeds the available storage quota, throw a `QuotaExceededError`.
   2. Set this's **[[file]]**'s to a byte sequence formed by concatenating `fileContents` with a byte sequence containing `newSize` − `oldSize` 0x00 bytes.
   3. If the operations modifying the this's **[[file]]**'s **binary data** in the previous steps failed, throw an "`InvalidStateError`" `DOMException`.
6. Otherwise, if `newSize` is smaller than `oldSize`:
   1. Set this's **[[file]]**'s to a byte sequence containing the first `newSize` bytes in `fileContents`.
   2. If the operations modifying the this's **[[file]]**'s **binary data** in the previous steps failed, throw an "`InvalidStateError`" `DOMException`.
7. If this's **file position cursor** is greater than `newSize`, then set **file position cursor** to `newSize`.


#### The `getSize()` method

`handle` . `getSize()`

: Returns the size of the file associated with `handle` in bytes.

The `getSize()` method steps are:

1. If this's **[[state]]** is "`closed`", throw an "`InvalidStateError`" `DOMException`.
2. Return this's **[[file]]**'s **binary data**'s length.


#### The `flush()` method

`handle` . `flush()`

: Ensures that the contents of the file associated with `handle` contain all the modifications done through `write()`.

The `flush()` method steps are:

1. If this's **[[state]]** is "`closed`", throw an "`InvalidStateError`" `DOMException`.
2. Attempt to transfer all cached modifications of the file's content to the file system's underlying storage device.
   
   Note: This is also known as flushing. This can be a no-op on some file systems, such as in-memory file systems, which do not have a "disk" to flush to.


#### The `close()` method

`handle` . `close()`

: Closes the access handle or no-ops if the access handle is already closed. This disables any further operations on it and **releases the lock** on the **[[file]]** associated with `handle`.

The `close()` method steps are:

1. If this's **[[state]]** is "`closed`", return.
2. Set this's **[[state]]** to "`closed`".
3. Set `lockReleased` to false.
4. Let `file` be this's **[[file]]**.
5. Enqueue the following steps to the **file system queue**:
   1. **Release the lock** on `file`.
   2. Set `lockReleased` to true.
6. Pause until `lockReleased` is true.

Note: This method does not guarantee that all file modifications will be immediately reflected in the underlying storage device. Call the `flush()` method first if you require this guarantee.


## Accessing the Bucket File System

The **bucket file system** is a [storage endpoint](https://storage.spec.whatwg.org/#storage-endpoint) whose [identifier](https://storage.spec.whatwg.org/#storage-endpoint-identifier) is `"fileSystem"`, [types](https://storage.spec.whatwg.org/#storage-endpoint-types) are `« "local" »`, and [quota](https://storage.spec.whatwg.org/#storage-endpoint-quota) is null.

Storage endpoints should be defined in [STORAGE] itself, rather than being defined here. So merge this into the table there.

Note: While user agents will typically implement this by persisting the contents of a bucket file system to disk, it is not intended that the contents are easily user accessible. Similarly there is no expectation that files or directories with names matching the names of children of a bucket file system exist.

```idl
[SecureContext]
partial interface StorageManager {
  Promise<FileSystemDirectoryHandle> getDirectory();
};
```

`directoryHandle` = await navigator . storage . `getDirectory()`

Returns the root directory of the bucket file system.

The `getDirectory()` method steps are:

1. Let `environment` be the [current settings object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object).

2. Let `map` be the result of running [obtain a local storage bottle map](https://storage.spec.whatwg.org/#obtain-a-local-storage-bottle-map) with `environment` and `"fileSystem"`. If this returns failure, return [a promise rejected with](https://webidl.spec.whatwg.org/#a-promise-rejected-with) a "`SecurityError`" `DOMException`.

3. If `map`["root"] does not [exist](https://infra.spec.whatwg.org/#map-exists):

    1. Let `dir` be a new directory entry whose query access and request access algorithms always return a file system access result with a permission state of "`granted`" and with an error name of the empty string.

    2. Set `dir`'s name to the empty string.

    3. Set `dir`'s children to an empty [set](https://infra.spec.whatwg.org/#ordered-set).

    4. Set `map`["root"] to `dir`.

4. Let `root` be an [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) opaque [string](https://infra.spec.whatwg.org/#string).

5. Let `path` be « the empty string ».

6. Let `handle` be the result of creating a new `FileSystemDirectoryHandle` given `root` and `path` in the [current realm](https://tc39.es/ecma262/#current-realm).

    Note: `root` might include relevant identifying information such as the [storage bucket](https://storage.spec.whatwg.org/#storage-bucket).

7. Assert: locating an entry given `handle`'s locator returns a directory entry that is the same entry as `map`["root"].

8. Return [a promise resolved with](https://webidl.spec.whatwg.org/#a-promise-resolved-with) `handle`.

<!-- This section contains only acknowledgments of contributors, which should be removed per the instructions. -->