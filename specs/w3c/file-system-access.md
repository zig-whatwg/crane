## 1. Introduction

*This section is non-normative.*

This API enables developers to build powerful apps that interact with
other (non-Web) apps on the user's device via the device's file system.
Prominent examples of applications where users expect this functionality
are IDEs, photo and video editors, text editors, and more. After a user
grants a web app access, this API allows the app to read or save changes
directly to files and folders on the user's device. Beyond reading and
writing files, this API provides the ability to open a directory and
enumerate its contents. Additionally, web apps can use this API to store
references to files and directories they've been given access to,
allowing the web apps to later regain access to the same content without
requiring the user to select the same file again.

This API is similar to
[`<input type=file>`](https://html.spec.whatwg.org/multipage/input.html#file-upload-state-(type=file))
and
[`<input type=file webkitdirectory>`](https://wicg.github.io/entries-api/#html-forms)
[\[entries-api\]](#biblio-entries-api "File and Directory Entries API")
in that user interaction happens through file and directory picker
dialogs. Unlike those APIs, this API is currently purely a javascript
API, and does not integrate with forms and/or input elements.

This API extends the API in
[\[FS\]](#biblio-fs "File System Standard"), which
specifies a [bucket file
system](https://fs.spec.whatwg.org/#origin-private-file-system) which websites can get access to without having to
first prompt the user for access.

## 2. Files and Directories

### 2.1. Concepts

A [valid suffix code point] is a [code
point](https://infra.spec.whatwg.org/#code-point) that is [ASCII
alphanumeric](https://infra.spec.whatwg.org/#ascii-alphanumeric), U+002B (+), or U+002E (.).

 These code points were chosen to support most
pre-existing file formats. The vast majority of file extensions are
purely alphanumeric, but compound extensions (such as `.tar.gz`) and
extensions such as `.c++` for C++ source code are also fairly common,
hence the inclusion of + and . as allowed code points.

### 2.2. Permissions

The [`"file-system"`]
[powerful
feature](https://w3c.github.io/permissions/#dfn-powerful-feature)'s permission-related algorithms and types are defined
as follows:

[permission descriptor type](https://w3c.github.io/permissions/#dfn-permission-descriptor-type)

: [`FileSystemPermissionDescriptor`](#dictdef-filesystempermissiondescriptor), defined as:

 ```
 enum FileSystemPermissionMode {
 "read",
 "readwrite"
 };

 dictionary FileSystemPermissionDescriptor : PermissionDescriptor {
 required FileSystemHandle handle;
 FileSystemPermissionMode mode = "read";
 };
 ```

[permission state constraints](https://w3c.github.io/permissions/#dfn-permission-state-constraints)

: :::
 To determine [permission state
 constraints](https://w3c.github.io/permissions/#dfn-permission-state-constraints) for a
 [`FileSystemPermissionDescriptor`](#dictdef-filesystempermissiondescriptor) `desc`, run these steps:
 1. Let `entry` be
 `desc`\[\"[`handle`](#dom-filesystempermissiondescriptor-handle)\"\]\'s [entry].

 2. If `entry` represents a [file system
 entry](https://fs.spec.whatwg.org/#entry) in a [bucket file
 system](https://fs.spec.whatwg.org/#origin-private-file-system), this descriptor's [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state) must always be
 \"[`granted`](https://w3c.github.io/permissions/#dom-permissionstate-granted)\".

 3. Otherwise, if `entry`'s
 [parent](https://fs.spec.whatwg.org/#entry-parent) is not null, this descriptor's [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state) must be equal to the [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state) for a descriptor with the same
 [`mode`](#dom-filesystempermissiondescriptor-mode), and a
 [`handle`](#dom-filesystempermissiondescriptor-handle) representing `entry`'s
 [parent](https://fs.spec.whatwg.org/#entry-parent).

 4. Otherwise, if
 `desc`\[\"[`mode`](#dom-filesystempermissiondescriptor-mode)\"\] is
 \"[`readwrite`](#dom-filesystempermissionmode-readwrite)\":

 1. Let `read state` be the [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state) for a descriptor with the same
 [`handle`](#dom-filesystempermissiondescriptor-handle), but whose
 [`mode`](#dom-filesystempermissiondescriptor-mode) is
 \"[`read`](#dom-filesystempermissionmode-read)\".

 2. If `read state` is not
 \"[`granted`](https://w3c.github.io/permissions/#dom-permissionstate-granted)\", this descriptor's [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state) must be equal to `read state`.
 :::

Make these checks no longer associated
with an entry. [\[whatwg/fs Issue
#101\]](https://github.com/whatwg/fs/issues/101)

[permission request algorithm](https://wicg.github.io/permissions-request/#permission-request-algorithm)

: :::
 Given a
 [`FileSystemPermissionDescriptor`](#dictdef-filesystempermissiondescriptor) `desc` and a
 [`PermissionStatus`](https://w3c.github.io/permissions/#dom-permissionstatus) `status`, run these steps:
 1. Run the [default permission query
 algorithm](https://w3c.github.io/permissions/#dfn-default-permission-query-algorithm) on `desc` and `status`.

 2. If `status`'s
 [`state`](https://w3c.github.io/permissions/#dom-permissionstatus-state) is not
 \"[`prompt`](https://w3c.github.io/permissions/#dom-permissionstate-prompt)\", then abort these steps.

 3. Let `settings` be
 `desc`\[\"[`handle`](#dom-filesystempermissiondescriptor-handle)\"\]\'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

 4. Let `global` be `settings`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global).

 5. If `global` is not a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 6. If `global` does not have [transient
 activation](https://html.spec.whatwg.org/multipage/interaction.html#transient-activation), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 7. If `settings`'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin) is not [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with `settings`'s [top-level
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 8. [Request permission to
 use](https://w3c.github.io/permissions/#dfn-request-permission-to-use) `desc`.

 9. Run the [default permission query
 algorithm](https://w3c.github.io/permissions/#dfn-default-permission-query-algorithm) on `desc` and `status`.

 (#issue-88417955) Ideally this user activation
 requirement would be defined upstream. [\[WICG/permissions-request
 Issue #2\]](https://github.com/WICG/permissions-request/issues/2)
 :::

To [query file system permission] given a
[`FileSystemHandle`](https://fs.spec.whatwg.org/#filesystemhandle) `handle` and a
[`FileSystemPermissionMode`](#enumdef-filesystempermissionmode) `mode`, run these steps:

1. Let `desc` be a
 [`FileSystemPermissionDescriptor`](#dictdef-filesystempermissiondescriptor).

2. Set
 `desc`\[\"[`name`](https://w3c.github.io/permissions/#dom-permissiondescriptor-name)\"\] to
 \"[`file-system`](#dom-permissionname-file-system)\".

3. Set
 `desc`\[\"[`handle`](#dom-filesystempermissiondescriptor-handle)\"\] to `handle`.

4. Set
 `desc`\[\"[`mode`](#dom-filesystempermissiondescriptor-mode)\"\] to `mode`.

5. Return `desc`'s [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state).

To [request file system permission] given a
[`FileSystemHandle`](https://fs.spec.whatwg.org/#filesystemhandle) `handle` and a
[`FileSystemPermissionMode`](#enumdef-filesystempermissionmode) `mode`, run these steps:

1. Let `desc` be a
 [`FileSystemPermissionDescriptor`](#dictdef-filesystempermissiondescriptor).

2. Set
 `desc`\[\"[`name`](https://w3c.github.io/permissions/#dom-permissiondescriptor-name)\"\] to
 \"[`file-system`](#dom-permissionname-file-system)\".

3. Set
 `desc`\[\"[`handle`](#dom-filesystempermissiondescriptor-handle)\"\] to `handle`.

4. Set
 `desc`\[\"[`mode`](#dom-filesystempermissiondescriptor-mode)\"\] to `mode`.

5. Let `status` be the result of running [create a
 PermissionStatus](https://w3c.github.io/permissions/#dfn-create-a-permissionstatus) for `desc`.

6. Run the [permission request
 algorithm](https://wicg.github.io/permissions-request/#permission-request-algorithm) for the
 \"[`file-system`](#dom-permissionname-file-system)\" feature, given `desc` and
 `status`.

7. Return `desc`'s [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state).

Currently
[`FileSystemPermissionMode`](#enumdef-filesystempermissionmode) can only be
\"[`read`](#dom-filesystempermissionmode-read)\" or
\"[`readwrite`](#dom-filesystempermissionmode-readwrite)\". In the future we might want to add a \"write\" mode
as well to support write-only handles. [\[Issue
#119\]](https://github.com/wicg/file-system-access/issues/119)

### [2.3. ][The [`FileSystemHandle`](https://fs.spec.whatwg.org/#filesystemhandle) interface]
```
dictionary FileSystemHandlePermissionDescriptor {
 FileSystemPermissionMode mode = "read";
};

[Exposed=(Window,Worker), SecureContext, Serializable]
partial interface FileSystemHandle {
 Promise<PermissionState> queryPermission(optional FileSystemHandlePermissionDescriptor descriptor = );
 Promise<PermissionState> requestPermission(optional FileSystemHandlePermissionDescriptor descriptor = );
};
```

#### 2.3.1. The [`queryPermission()` method]
`status` = await `handle` . [`queryPermission`](#dom-filesystemhandle-querypermission)({ [`mode`](#dom-filesystemhandlepermissiondescriptor-mode) : \"[`read`](#dom-filesystempermissionmode-read)\" })\
`status` = await `handle` . [`queryPermission()`](#dom-filesystemhandle-querypermission)\
`status` = (await navigator.[`permissions`](https://w3c.github.io/permissions/#dom-navigator-permissions).[`query`](https://w3c.github.io/permissions/#dom-permissions-query)({ [`name`](https://w3c.github.io/permissions/#dom-permissiondescriptor-name) : \"[`file-system`](#dom-permissionname-file-system)\", [`handle`](#dom-filesystempermissiondescriptor-handle) : `handle` })).[`state`](https://w3c.github.io/permissions/#dom-permissionstatus-state)

: Queries the current state of the read permission of this handle. If
 this returns
 \"[`prompt`](https://w3c.github.io/permissions/#dom-permissionstate-prompt)\" the website will have to call
 [`requestPermission()`](#dom-filesystemhandle-requestpermission) before any operations on the handle can be done. If
 this returns
 \"[`denied`](https://w3c.github.io/permissions/#dom-permissionstate-denied)\" any operations will reject.

 Usually handles returned by the [local file system handle
 factories](#local-file-system-handle-factories) will initially return
 \"[`granted`](https://w3c.github.io/permissions/#dom-permissionstate-granted)\" for their read permission state, however other
 than through the user revoking permission, a handle retrieved from
 IndexedDB is also likely to return
 \"[`prompt`](https://w3c.github.io/permissions/#dom-permissionstate-prompt)\".

`status` = await `handle` . [`queryPermission`](#dom-filesystemhandle-querypermission)({ [`mode`](#dom-filesystemhandlepermissiondescriptor-mode) : \"[`readwrite`](#dom-filesystempermissionmode-readwrite)\" })\
`status` = (await navigator.[`permissions`](https://w3c.github.io/permissions/#dom-navigator-permissions).[`query`](https://w3c.github.io/permissions/#dom-permissions-query)({ [`name`](https://w3c.github.io/permissions/#dom-permissiondescriptor-name) : \"[`file-system`](#dom-permissionname-file-system)\", [`handle`](#dom-filesystempermissiondescriptor-handle) : `handle`, [`mode`](#dom-filesystempermissiondescriptor-mode) : \"[`readwrite`](#dom-filesystempermissionmode-readwrite)\" }).[`state`](https://w3c.github.io/permissions/#dom-permissionstatus-state)

: Queries the current state of the write permission of this handle. If
 this returns
 \"[`prompt`](https://w3c.github.io/permissions/#dom-permissionstate-prompt)\", attempting to modify the file or directory this
 handle represents will require user activation and will result in a
 confirmation prompt being shown to the user. However if the state of
 the read permission of this handle is also
 \"[`prompt`](https://w3c.github.io/permissions/#dom-permissionstate-prompt)\" the website will need to call
 [`requestPermission()`](#dom-filesystemhandle-requestpermission). There is no automatic prompting for read access
 when attempting to read from a file or directory.

**The integration with the permissions API's
[`query()`](https://w3c.github.io/permissions/#dom-permissions-query) method is not yet implemented in Chrome.**

[`queryPermission(``descriptor``)`] method,
when invoked, must run these steps:

1. Let `result` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

2. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `state` be the result of [querying file system
 permission](#querying-file-system-permission) given
 **[this](https://webidl.spec.whatwg.org/#this)** and
 `descriptor`\[\"[`mode`](#dom-filesystemhandlepermissiondescriptor-mode)\"\].

 2. [Resolve](https://webidl.spec.whatwg.org/#resolve) `result` with `state`.

3. Return `result`.

#### 2.3.2. The [`requestPermission()` method]
`status` = await `handle` . [`requestPermission`](#dom-filesystemhandle-requestpermission)({ [`mode`](#dom-filesystemhandlepermissiondescriptor-mode) : \"[`read`](#dom-filesystempermissionmode-read)\" })\
`status` = await `handle` . [`requestPermission()`](#dom-filesystemhandle-requestpermission)

: If the state of the read permission of this handle is anything other
 than
 \"[`prompt`](https://w3c.github.io/permissions/#dom-permissionstate-prompt)\", this will return that state directly. If it is
 \"[`prompt`](https://w3c.github.io/permissions/#dom-permissionstate-prompt)\" however, user activation is needed and this will
 show a confirmation prompt to the user. The new read permission
 state is then returned, depending on the user's response to the
 prompt.

`status` = await `handle` . [`requestPermission`](#dom-filesystemhandle-requestpermission)({ [`mode`](#dom-filesystemhandlepermissiondescriptor-mode) : \"[`readwrite`](#dom-filesystempermissionmode-readwrite)\" })

: If the state of the write permission of this handle is anything
 other than
 \"[`prompt`](https://w3c.github.io/permissions/#dom-permissionstate-prompt)\", this will return that state directly. If the
 status of the read permission of this handle is
 \"[`denied`](https://w3c.github.io/permissions/#dom-permissionstate-denied)\" this will return that.

 Otherwise the state of the write permission is
 \"[`prompt`](https://w3c.github.io/permissions/#dom-permissionstate-prompt)\" and this will show a confirmation prompt to the
 user. The new write permission state is then returned, depending on
 what the user selected.

[`requestPermission(``descriptor``)`]
method, when invoked, must run these steps:

1. Let `result` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

2. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `state` be the result of [requesting file system
 permission](#requesting-file-system-permission) given
 **[this](https://webidl.spec.whatwg.org/#this)** and
 `descriptor`\[\"[`mode`](#dom-filesystemhandlepermissiondescriptor-mode)\"\]. If that throws an exception,
 [reject](https://webidl.spec.whatwg.org/#reject) `result` with that exception and
 abort.

 2. [Resolve](https://webidl.spec.whatwg.org/#resolve) `result` with `state`.

3. Return `result`.

## 3. Accessing Local File System

```
enum WellKnownDirectory {
 "desktop",
 "documents",
 "downloads",
 "music",
 "pictures",
 "videos",
};

typedef (WellKnownDirectory or FileSystemHandle) StartInDirectory;

dictionary FilePickerAcceptType {
 USVString description = "";
 record<USVString, (USVString or sequence<USVString>)> accept;
};

dictionary FilePickerOptions {
 sequence<FilePickerAcceptType> types;
 boolean excludeAcceptAllOption = false;
 DOMString id;
 StartInDirectory startIn;
};

dictionary OpenFilePickerOptions : FilePickerOptions {
 boolean multiple = false;
};

dictionary SaveFilePickerOptions : FilePickerOptions {
 USVString? suggestedName;
};

dictionary DirectoryPickerOptions {
 DOMString id;
 StartInDirectory startIn;
 FileSystemPermissionMode mode = "read";
};

[SecureContext]
partial interface Window {
 Promise<sequence<FileSystemFileHandle>> showOpenFilePicker(optional OpenFilePickerOptions options = );
 Promise<FileSystemFileHandle> showSaveFilePicker(optional SaveFilePickerOptions options = );
 Promise<FileSystemDirectoryHandle> showDirectoryPicker(optional DirectoryPickerOptions options = );
};
```

The
[`showOpenFilePicker()`](#dom-window-showopenfilepicker),
[`showSaveFilePicker()`](#dom-window-showsavefilepicker) and
[`showDirectoryPicker()`](#dom-window-showdirectorypicker) methods are together known as the [local file system
handle factories].

 What is referred to as the \"local file system\" in
this spec, does not have to strictly refer to the file system on the
local device. What we call the local file system could just as well be
backed by a cloud provider. For example on Chrome OS these file pickers
will also let you pick files and directories on Google Drive.

**In Chrome versions earlier than 85, this was implemented as a generic
`chooseFileSystemEntries` method.**

### 3.1. Local File System Permissions

The fact that the user picked the specific files returned by the [local
file system handle
factories](#local-file-system-handle-factories) in a prompt should be treated by the user agent as the
user intending to grant read access to the website for the returned
files. As such, at the time the promise returned by one of the [local
file system handle
factories](#local-file-system-handle-factories) resolves, [permission
state](https://w3c.github.io/permissions/#dfn-permission-state) for a descriptor with
[`handle`](#dom-filesystempermissiondescriptor-handle) set to the returned handle, and
[`mode`](#dom-filesystempermissiondescriptor-mode) set to
\"[`read`](#dom-filesystempermissionmode-read)\" should be
\"[`granted`](https://w3c.github.io/permissions/#dom-permissionstate-granted)\".

Additionally for calls to
[`showSaveFilePicker`](#dom-window-showsavefilepicker) the [permission
state](https://w3c.github.io/permissions/#dfn-permission-state) for a descriptor with
[`handle`](#dom-filesystempermissiondescriptor-handle) set to the returned handle, and
[`mode`](#dom-filesystempermissiondescriptor-mode) set to
\"[`readwrite`](#dom-filesystempermissionmode-readwrite)\" should be
\"[`granted`](https://w3c.github.io/permissions/#dom-permissionstate-granted)\".

To verify that an `environment` [is allowed to show a file
picker], run these steps:

1. If `environment`'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin) is an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque), return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with) a
 \"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. If `environment`'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin) is not [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with `environment`'s [top-level
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin), return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with) a
 \"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Let `global` be `environment`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global).

4. If `global` does not have [transient
 activation](https://html.spec.whatwg.org/multipage/interaction.html#transient-activation), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

### 3.2. File picker options

#### 3.2.1. Accepted file types

[`showOpenFilePicker(options)`](#dom-window-showopenfilepicker) and
[`showSaveFilePicker(options)`](#dom-window-showsavefilepicker) methods accept a
[`FilePickerOptions`](#dictdef-filepickeroptions) argument, which lets the website specify the types of
files the file picker will let the user select.

Each entry in
[`types`](#dom-filepickeroptions-types) specifies a single user selectable option for filtering
the files displayed in the file picker.

Each option consists of an [optional]
[`description`](#dom-filepickeraccepttype-description) and a number of MIME types and extensions (specified as
a mapping of MIME type to a list of extensions). If no description is
provided one will be generated. Extensions have to be strings that start
with a \".\" and only contain [valid suffix code
points](#valid-suffix-code-point). Additionally extensions are limited to a length of 16
code points.

In addition to complete MIME types, \"\*\" can be used as the subtype of
a MIME type to match for example all image formats with \"image/\*\".

Websites [should] always provide both MIME types and file
extensions for each option. On platforms that only use file extensions
to describe file types user agents can match on the extensions, while on
platforms that don't use extensions, user agents can match on MIME type.

By default the file picker will also include an option to not apply any
filter, letting the user select any file. Set
[`excludeAcceptAllOption`](#dom-filepickeroptions-excludeacceptalloption) to `true` to not include this option in the file
picker.

For example , the following options will let the user pick one of three
different filters. One for text files (either plain text or HTML), one
for images, and a third one that doesn't apply any filter and lets the
user select any file.

```
const options = {
 types: [
 {
 description: 'Text Files',
 accept: {
 'text/plain': ['.txt', '.text'],
 'text/html': ['.html', '.htm']
 }
 },
 {
 description: 'Images',
 accept: {
 'image/*': ['.png', '.gif', '.jpeg', '.jpg']
 }
 }
 ],
};
```

On the other hand, the following example will only let the user select
SVG files. The dialog will not show an option to not apply any filters.

```
const options = {
 types: [
 {
 accept: {
 'image/svg+xml': '.svg'
 }
 },
 ],
 excludeAcceptAllOption: true
};
```

To [process accept types], given
[`FilePickerOptions`](#dictdef-filepickeroptions) `options`, run these steps:

1. Let `accepts options` be a empty
 [list](https://infra.spec.whatwg.org/#list) of
 [tuples](https://infra.spec.whatwg.org/#tuple) consisting of a description and a filter.

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `type` of
 `options`\[\"[`types`](#dom-filepickeroptions-types)\"\]:

 1. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `typeString` → `suffixes`
 of
 `type`\[\"[`accept`](#dom-filepickeraccepttype-accept)\"\]:

 1. Let `parsedType` be the result of [parse a MIME
 type](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) with `typeString`.

 2. If `parsedType` is failure, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 3. If `parsedType`'s
 [parameters](https://mimesniff.spec.whatwg.org/#parameters) are not empty, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 4. If `suffixes` is a string:

 1. [Validate a
 suffix](#validate-a-suffix) given `suffixes`.

 5. Otherwise, [for
 each](https://infra.spec.whatwg.org/#list-iterate) `suffix` of
 `suffixes`:

 1. [Validate a
 suffix](#validate-a-suffix) given `suffix`.

 2. Let `filter` be these steps, given a
 `filename` (a
 [string](https://infra.spec.whatwg.org/#string)) and a `type` (a [MIME
 type](https://mimesniff.spec.whatwg.org/#mime-type)):

 1. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `typeString` →
 `suffixes` of
 `type`\[\"[`accept`](#dom-filepickeraccepttype-accept)\"\]:

 2. Let `parsedType` be the result of [parse a MIME
 type](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) with `typeString`.

 1. If `parsedType`'s
 [subtype](https://mimesniff.spec.whatwg.org/#subtype) is \"\*\":

 1. If `parsedType`'s
 [type](https://mimesniff.spec.whatwg.org/#type) is \"\*\", return `true`.

 2. If `parsedType`'s
 [type](https://mimesniff.spec.whatwg.org/#type) is `type`'s
 [type](https://mimesniff.spec.whatwg.org/#type), return `true`.

 2. `parsedType`'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) is `type`'s
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence), return `true`.

 3. If `suffixes` is a string, set
 `suffixes` to « `suffixes` ».

 4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `suffix` of
 `suffixes`:

 1. If `filename` ends with
 `suffix`, return `true`.

 3. Return `false`.

 3. Let `description` be
 `type`\[\"[`description`](#dom-filepickeraccepttype-description)\"\].

 4. If `description` is an empty string, set
 `description` to some user understandable string
 describing `filter`.

 5. [Append](https://infra.spec.whatwg.org/#list-append) (`description`, `filter`)
 to `accepts options`.

3. If either `accepts options` is
 [empty](https://infra.spec.whatwg.org/#list-empty), or
 `options`\[\"[`excludeAcceptAllOption`](#dom-filepickeroptions-excludeacceptalloption)\"\] is `false`:

 1. Let `description` be a user understandable string
 describing \"all files\".

 1. Let `filter` be an algorithm that returns `true`.

 2. [Append](https://infra.spec.whatwg.org/#list-append) (`description`,
 `filter`) to `accepts options`.

4. If `accepts options` is empty, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

5. Return `accepts options`.

To [validate a suffix] `suffix`, run the following
steps:

1. If `suffix` does not [start
 with](https://infra.spec.whatwg.org/#string-starts-with) \".\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. If `suffix` contains any [code
 points](https://infra.spec.whatwg.org/#code-point) that are not [valid suffix code
 points](#valid-suffix-code-point), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. If `suffix` ends with \".\", then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

4. If `suffix`'s
 [length](https://infra.spec.whatwg.org/#string-length) is more than 16, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

#### 3.2.2. Starting Directory

[`id`](#dom-filepickeroptions-id) and
[`startIn`](#dom-filepickeroptions-startin) fields can be specified to suggest the directory in
which the file picker opens.

If neither of these options are specified, the user agent remembers the
last directory a file or directory was picked from, and new pickers will
start out in that directory. By specifying an
[`id`](#dom-filepickeroptions-id) the user agent can remember different directories for
different IDs (user agents will only remember directories for a limited
number of IDs).

```
// If a mapping exists from this ID to a previousy picked directory, start in
// this directory. Otherwise, a mapping will be created from this ID to the
// directory of the resulting file picker invocation.
const options = {
 id: 'foo',
};
```

Specifying
[`startIn`](#dom-filepickeroptions-startin) as a
[`FileSystemFileHandle`](https://fs.spec.whatwg.org/#filesystemfilehandle) will result in the dialog starting in the parent
directory of that file, while passing in a
[`FileSystemDirectoryHandle`](https://fs.spec.whatwg.org/#filesystemdirectoryhandle) will result in the dialog to start in the passed in
directory. These take precedence even if an explicit
[`id`](#dom-filepickeroptions-id) is also passed in.

For example, given a
[`FileSystemDirectoryHandle`](https://fs.spec.whatwg.org/#filesystemdirectoryhandle) `project_dir`, the following will show a
file picker that starts out in that directory:

```
// The picker will open to the directory of |project_dir| regardless of whether
// 'foo' has a valid mapping.
const options = {
 id: 'foo',
 startIn: |project_dir|,
};
```

The
[`id`](#dom-filepickeroptions-id) and
[`startIn`](#dom-filepickeroptions-startin) fields control only the directory the picker opens to.
In the above example, it cannot be assumed that the
[`id`](#dom-filepickeroptions-id) \'foo\' will map to the same directory as
`project_dir` once the file picker operation has completed.

Specifying
[`startIn`](#dom-filepickeroptions-startin) as a
[`WellKnownDirectory`](#enumdef-wellknowndirectory) will result in the dialog starting in that directory,
unless an explicit
[`id`](#dom-filepickeroptions-id) was also passed in which has a mapping to a valid
directory.

Below is an example of specifying both an
[`id`](#dom-filepickeroptions-id) and
[`startIn`](#dom-filepickeroptions-startin) as a
[`WellKnownDirectory`](#enumdef-wellknowndirectory). If there is an existing mapping from the given ID to a
path, this mapping is used. Otherwise, the path suggested via the
[`WellKnownDirectory`](#enumdef-wellknowndirectory) is used.

```
// First time specifying the ID 'foo'. It is not mapped to a directory.
// The file picker will fall back to opening to the Downloads directory. TODO: link this.
const options = {
 id: 'foo', // Unmapped.
 startIn: "downloads", // Start here.
};

// Later...

// The ID 'foo' might or might not be mapped. For example, the mapping for this ID
// might have been evicted.
const options = {
 id: 'foo', // Maybe mapped. If so, start here.
 startIn: "downloads", // Otherwise, start here.
};
```

**The
[`startIn`](#dom-filepickeroptions-startin) and
[`id`](#dom-filepickeroptions-id) options were first introduced in Chrome 91.**

A user agent holds a [recently picked directory
map], which is a
[map](https://infra.spec.whatwg.org/#ordered-map) of
[origins](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) to [path id maps](#path-id-map).

A [path id map] is a
[map](https://infra.spec.whatwg.org/#ordered-map) of [valid path
ids](#valid-path-id) to paths.

A [valid path id] is a
[string](https://infra.spec.whatwg.org/#string) where each character is [ASCII
alphanumeric](https://infra.spec.whatwg.org/#ascii-alphanumeric) or \"\_\" or \"-\".

To prevent a [path id map](#path-id-map) from growing without a bound, user agents should
implement some mechanism to limit how many recently picked directories
will be remembered. This can for example be done by evicting least
recently used entries. User agents should allow at least 16 entries to
be stored in a [path id map](#path-id-map).

The [`WellKnownDirectory`] enum lets a website pick one of
several well-known directories. The exact paths the various values of
this enum map to is
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) (and in some cases these might not even represent
actual paths on disk). The following list describes the meaning of each
of the values, and gives possible example paths on different operating
systems:

[`"desktop"`]

: The user's Desktop directory, if such a thing exists. For example
 this could be `C:\Documents and Settings\username\Desktop`,
 `/Users/username/Desktop`, or `/home/username/Desktop`.

[`"documents"`]

: Directory in which documents created by the user would typically be
 stored. For example
 `C:\Documents and Settings\username\My Documents`,
 `/Users/username/Documents`, or `/home/username/Documents`.

[`"downloads"`]

: Directory where downloaded files would typically be stored. For
 example `C:\Documents and Settings\username\Downloads`,
 `/Users/username/Downloads`, or `/home/username/Downloads`.

[`"music"`]

: Directory where audio files would typically be stored. For example
 `C:\Documents and Settings\username\My Documents\My Music`,
 `/Users/username/Music`, or `/home/username/Music`.

[`"pictures"`]

: Directory where photos and other still images would typically be
 stored. For example
 `C:\Documents and Settings\username\My Documents\My Pictures`,
 `/Users/username/Pictures`, or `/home/username/Pictures`.

[`"videos"`]

: Directory where videos/movies would typically be stored. For example
 `C:\Documents and Settings\username\My Documents\My Videos`,
 `/Users/username/Movies`, or `/home/username/Videos`.

\[ `handle` \] = await window . [`showOpenFilePicker()`](#dom-window-showopenfilepicker)\
\[ `handle` \] = await window . [`showOpenFilePicker`](#dom-window-showopenfilepicker)({ [`multiple`](#dom-openfilepickeroptions-multiple): false })

: Shows a file picker that lets a user select a single existing file,
 returning a handle for the selected file.

handles = await window . [`showOpenFilePicker`](#dom-window-showopenfilepicker)({ [`multiple`](#dom-openfilepickeroptions-multiple): true })

: Shows a file picker that lets a user select multiple existing files,
 returning handles for the selected files.

 Additional options can be passed to
 [`showOpenFilePicker()`](#dom-window-showopenfilepicker) to indicate the types of files the website wants
 the user to select and the directory in which the file picker will
 open. See [§ 3.2 File picker options](#api-filepickeroptions) for
 details.

 :::
 The
 [`showOpenFilePicker(``options``)`]
 method, when invoked, must run these steps:
 1. Let `environment` be
 **[this](https://webidl.spec.whatwg.org/#this)**'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

 2. Let `accepts options` be the result of [processing
 accept
 types](#process-accept-types) given `options`.

 3. Let `starting directory` be the result of
 [determining the directory the picker will start
 in](#wellknowndirectory-determine-the-directory-the-picker-will-start-in) given
 `options`\[\"[`id`](#dom-filepickeroptions-id)\"\],
 `options`\[\"[`startIn`](#dom-filepickeroptions-startin)\"\], and `environment`.

 4. Let `global` be `environment`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global).

 5. Verify that `environment` [is allowed to show a file
 picker](#is-allowed-to-show-a-file-picker).

 6. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 7. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Optionally, wait until any prior execution of this algorithm
 has terminated.

 2. Let `filePickerOptions` be an empty
 [map](https://infra.spec.whatwg.org/#ordered-map).

 3. Set `filePickerOptions`\[\"multiple\"\] to
 `options`\[\"[`multiple`](#dom-openfilepickeroptions-multiple)\"\].

 4. Let `dismissed` be the result of [WebDriver BiDi
 file dialog
 opened](https://www.w3.org/TR/webdriver-bidi/#webdriver-bidi-file-dialog-opened) with null and
 `filePickerOptions`.

 5. If `dismissed` is false:

 1. Display a prompt to the user requesting that the user
 pick some files. If
 `filePickerOptions`\[\"multiple\"\] is false,
 there must be no more than one file selected; otherwise
 any number may be selected.

 The displayed prompt should let the user pick one of the
 `accepts options` to filter the list of
 displayed files. Exactly how this is implemented, and
 what this prompt looks like is
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined).

 When possible, this prompt should start out showing
 `starting directory`.

 2. Wait for the user to have made their selection.

 6. If `dismissed` is true or if the user dismissed
 the prompt without making a selection,
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort.

 7. Let `entries` be a
 [list](https://infra.spec.whatwg.org/#list) of [file
 entries](https://fs.spec.whatwg.org/#file) representing the selected files or
 directories.

 8. Let `result` be a empty
 [list](https://infra.spec.whatwg.org/#list).

 9. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `entry` of `entries`:

 1. If `entry` is deemed [too sensitive or
 dangerous](#wellknowndirectory-too-sensitive-or-dangerous) to be exposed to this website by the
 user agent:

 1. Inform the user that the selected files or
 directories can't be exposed to this website.

 2. At the discretion of the user agent, either go back
 to the beginning of these [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel) steps, or
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort.

 2. Add a new
 [`FileSystemFileHandle`](https://fs.spec.whatwg.org/#filesystemfilehandle) associated with `entry` to
 `result`.

 10. [Remember a picked
 directory](#wellknowndirectory-remember-a-picked-directory) given
 `options`\[\"[`id`](#dom-filepickeroptions-id)\"\], `entries`\[0\] and
 `environment`.

 11. Perform the [activation
 notification](https://html.spec.whatwg.org/multipage/interaction.html#activation-notification) steps in `global`'s [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc).

 This lets a website immediately perform
 operations on the returned handles that might require user
 activation, such as requesting more permissions.

 12. [Resolve](https://webidl.spec.whatwg.org/#resolve) `p` with `result`.

 8. Return `p`.
 :::

 ### [3.4. ][The [`showSaveFilePicker()`](#dom-window-showsavefilepicker) method](#api-showsavefilepicker)

 :::
 `handle` = await window .
 [`showSaveFilePicker`](#dom-window-showsavefilepicker)( `options` )
 Shows a file picker that lets a user select a single file, returning
 a handle for the selected file. The selected file does not have to
 exist already. If the selected file does not exist a new empty file
 is created before this method returns, otherwise the existing file
 is cleared before this method returned.

 `handle` = await window .
 [`showSaveFilePicker`](#dom-window-showsavefilepicker)({
 [`suggestedName`](#dom-savefilepickeroptions-suggestedname): \"README.md\" })
 Shows a file picker with the suggested \"README.md\" file name
 pre-filled as the default file name to save as.

 Additional `options` can be passed to
 [`showSaveFilePicker()`](#dom-window-showsavefilepicker) to indicate the types of files the website wants
 the user to select and the directory in which the file picker will
 open. See [§ 3.2 File picker options](#api-filepickeroptions) for
 details.
 :::

 **The
 [`suggestedName`](#dom-savefilepickeroptions-suggestedname) option was first introduced in Chrome 91.**

 :::
 The
 [`showSaveFilePicker(``options``)`]
 method, when invoked, must run these steps:
 1. Let `environment` be
 **[this](https://webidl.spec.whatwg.org/#this)**'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

 2. Let `accepts options` be the result of [processing
 accept
 types](#process-accept-types) given `options`.

 3. Let `starting directory` be the result of
 [determining the directory the picker will start
 in](#wellknowndirectory-determine-the-directory-the-picker-will-start-in) given
 `options`\[\"[`id`](#dom-filepickeroptions-id)\"\],
 `options`\[\"[`startIn`](#dom-filepickeroptions-startin)\"\] and `environment`.

 4. Let `global` be `environment`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global).

 5. Verify that `environment` [is allowed to show a file
 picker](#is-allowed-to-show-a-file-picker).

 6. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 7. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Optionally, wait until any prior execution of this algorithm
 has terminated.

 2. Display a prompt to the user requesting that the user pick
 exactly one file. The displayed prompt should let the user
 pick one of the `accepts options` to filter the
 list of displayed files. Exactly how this is implemented,
 and what this prompt looks like is
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined). If `accepts options` are
 displayed in the UI, the selected option should also be used
 to suggest an extension to append to a user provided file
 name, but this is not required. In particular user agents
 are free to ignore potentially dangerous suffixes such as
 those ending in `".lnk"` or `".local"`.

 When possible, this prompt should start out showing
 `starting directory`.

 If
 `options`\[\"[`suggestedName`](#dom-savefilepickeroptions-suggestedname)\"\]
 [exists](https://infra.spec.whatwg.org/#map-exists) and is not null, the file picker prompt
 will be pre-filled with the
 `options`\[\"[`suggestedName`](#dom-savefilepickeroptions-suggestedname)\"\] as the default name to save as. The
 interaction between the
 [`suggestedName`](#dom-savefilepickeroptions-suggestedname) and `accepts options` is
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined). If the
 [`suggestedName`](#dom-savefilepickeroptions-suggestedname) is deemed too dangerous, user agents should
 ignore or sanitize the suggested file name, similar to the
 sanitization done when fetching something [as a
 download].

 A user agent could for example pick
 whichever option in `accepts options` that
 matches
 [`suggestedName`](#dom-savefilepickeroptions-suggestedname) as the default filter.

 3. Wait for the user to have made their selection.

 4. If the user dismissed the prompt without making a selection,
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort.

 5. Let `entry` be a [file
 entry](https://fs.spec.whatwg.org/#file) representing the selected file.

 6. If `entry` is deemed [too sensitive or
 dangerous](#wellknowndirectory-too-sensitive-or-dangerous) to be exposed to this website by the user
 agent:

 1. Inform the user that the selected files or directories
 can't be exposed to this website.

 2. At the discretion of the user agent, either go back to
 the beginning of these [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel) steps, or
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort.

 7. Set `entry`'s [binary
 data](https://fs.spec.whatwg.org/#file-entry-binary-data) to an empty [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence).

 8. Set `result` to a new
 [`FileSystemFileHandle`](https://fs.spec.whatwg.org/#filesystemfilehandle) associated with `entry`.

 9. [Remember a picked
 directory](#wellknowndirectory-remember-a-picked-directory) given
 `options`\[\"[`id`](#dom-filepickeroptions-id)\"\], `entry` and
 `environment`.

 10. Perform the [activation
 notification](https://html.spec.whatwg.org/multipage/interaction.html#activation-notification) steps in `global`'s [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc).

 This lets a website immediately perform
 operations on the returned handles that might require user
 activation, such as requesting more permissions.

 11. [Resolve](https://webidl.spec.whatwg.org/#resolve) `p` with `result`.

 8. Return `p`.
 :::

 ### [3.5. ][The [`showDirectoryPicker()`](#dom-window-showdirectorypicker) method](#api-showdirectorypicker)

 :::
 `handle` = await window .
 [`showDirectoryPicker()`](#dom-window-showdirectorypicker)
 `handle` = await window .
 [`showDirectoryPicker()`](#dom-window-showdirectorypicker)({
 [`mode`](#dom-directorypickeroptions-mode): \'read\' })
 Shows a directory picker that lets the user select a single
 directory, returning a handle for the selected directory if the user
 grants read permission.

 `handle` = await window .
 [`showDirectoryPicker()`](#dom-window-showdirectorypicker)({
 [`mode`](#dom-directorypickeroptions-mode): \'readwrite\' })
 Shows a directory picker that lets the user select a single
 directory, returning a handle for the selected directory. The user
 agent can combine read and write permission requests on this handle
 into one subsequent prompt.

 The
 [`id`](#dom-directorypickeroptions-id) and
 [`startIn`](#dom-directorypickeroptions-startin) fields behave identically to the
 [`id`](#dom-filepickeroptions-id) and
 [`startIn`](#dom-filepickeroptions-startin) fields, respectively. See [§ 3.2.2 Starting
 Directory](#api-filepickeroptions-starting-directory) for details on
 how to use these fields.
 :::

 :::
 The
 [`showDirectoryPicker(``options``)`]
 method, when invoked, must run these steps:
 1. Let `environment` be
 **[this](https://webidl.spec.whatwg.org/#this)**'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

 2. Let `starting directory` be the result of
 [determining the directory the picker will start
 in](#wellknowndirectory-determine-the-directory-the-picker-will-start-in) given
 `options`\[\"[`id`](#dom-directorypickeroptions-id)\"\],
 `options`\[\"[`startIn`](#dom-directorypickeroptions-startin)\"\] and `environment`.

 3. Let `global` be `environment`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global).

 4. Verify that `environment` [is allowed to show a file
 picker](#is-allowed-to-show-a-file-picker).

 5. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 6. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Optionally, wait until any prior execution of this algorithm
 has terminated.

 2. Let `filePickerOptions` be an empty
 [map](https://infra.spec.whatwg.org/#ordered-map).

 3. Set `filePickerOptions`\[\"multiple\"\] to false.

 4. Let `dismissed` be the result of [WebDriver BiDi
 file dialog
 opened](https://www.w3.org/TR/webdriver-bidi/#webdriver-bidi-file-dialog-opened) with null and
 `filePickerOptions`.

 5. If `dismissed` is false:

 1. Display a prompt to the user requesting that the user
 pick a directory.

 When possible, this prompt should start out showing
 `starting directory`.

 2. Wait for the user to have made their selection.

 6. If `dismissed` is true or if the user dismissed
 the prompt without making a selection,
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort.

 7. Let `entry` be a [directory
 entry](https://fs.spec.whatwg.org/#directory) representing the selected directory.

 8. If `entry` is deemed [too sensitive or
 dangerous](#wellknowndirectory-too-sensitive-or-dangerous) to be exposed to this website by the user
 agent:

 1. Inform the user that the selected files or directories
 can't be exposed to this website.

 2. At the discretion of the user agent, either go back to
 the beginning of these [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel) steps, or
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort.

 9. Set `result` to a new
 [`FileSystemDirectoryHandle`](https://fs.spec.whatwg.org/#filesystemdirectoryhandle) associated with `entry`.

 10. [Remember a picked
 directory](#wellknowndirectory-remember-a-picked-directory) given
 `options`\[\"[`id`](#dom-directorypickeroptions-id)\"\], `entry` and
 `environment`.

 11. Let `desc` be a
 [`FileSystemPermissionDescriptor`](#dictdef-filesystempermissiondescriptor).

 12. Set
 `desc`\[\"[`name`](https://w3c.github.io/permissions/#dom-permissiondescriptor-name)\"\] to
 \"[`file-system`](#dom-permissionname-file-system)\".

 13. Set
 `desc`\[\"[`handle`](#dom-filesystempermissiondescriptor-handle)\"\] to `result`.

 14. Set
 `desc`\[\"[`mode`](#dom-filesystempermissiondescriptor-mode)\"\] to
 `options`\[\"[`mode`](#dom-directorypickeroptions-mode)\"\].

 15. Let `status` be the result of running [create a
 PermissionStatus](https://w3c.github.io/permissions/#dfn-create-a-permissionstatus) for `desc`.

 16. Perform the [activation
 notification](https://html.spec.whatwg.org/multipage/interaction.html#activation-notification) steps in `global`'s [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc).

 17. [Request permission to
 use](https://w3c.github.io/permissions/#dfn-request-permission-to-use) `desc`.

 18. Run the [default permission query
 algorithm](https://w3c.github.io/permissions/#dfn-default-permission-query-algorithm) on `desc` and
 `status`.

 19. If `status` is not
 \"[`granted`](https://w3c.github.io/permissions/#dom-permissionstate-granted)\",
 [reject](https://webidl.spec.whatwg.org/#reject) `result` with a
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort.

 20. Perform the [activation
 notification](https://html.spec.whatwg.org/multipage/interaction.html#activation-notification) steps in `global`'s [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc).

 21. [Resolve](https://webidl.spec.whatwg.org/#resolve) `p` with `result`.

 7. Return `p`.
 :::

 ### [3.6. ][Drag and Drop](#drag-and-drop)

 ```
 partial interface DataTransferItem {
 Promise<FileSystemHandle?> getAsFileSystemHandle();
 };
 ```

 During a *drag-and-drop operation*, dragged file and directory items
 are associated with [file
 entries](https://fs.spec.whatwg.org/#file) and [directory
 entries](https://fs.spec.whatwg.org/#directory) respectively.

 :::
 `handle` = await item .
 [`getAsFileSystemHandle()`](#dom-datatransferitem-getasfilesystemhandle)
 Returns a
 [`FileSystemFileHandle`](https://fs.spec.whatwg.org/#filesystemfilehandle) object if the dragged item is a file and a
 [`FileSystemDirectoryHandle`](https://fs.spec.whatwg.org/#filesystemdirectoryhandle) object if the dragged item is a directory.
 :::

 :::
 The
 [`getAsFileSystemHandle()`] method steps are:

 1. If the
 [`DataTransferItem`](https://html.spec.whatwg.org/multipage/dnd.html#datatransferitem) object is not in the [read/write
 mode](https://html.spec.whatwg.org/multipage/dnd.html#concept-dnd-rw) or the [read-only
 mode](https://html.spec.whatwg.org/multipage/dnd.html#concept-dnd-ro), return [a promise resolved
 with](https://webidl.spec.whatwg.org/#a-promise-resolved-with) `null`.

 2. If the [the drag data item
 kind](https://html.spec.whatwg.org/multipage/dnd.html#the-drag-data-item-kind) is not *File*, then return [a promise resolved
 with](https://webidl.spec.whatwg.org/#a-promise-resolved-with) `null`.

 3. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 4. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `entry` be the [file system
 entry](https://fs.spec.whatwg.org/#entry) representing the dragged file or directory.

 2. If `entry` is a [file
 entry](https://fs.spec.whatwg.org/#file):

 1. Let `handle` be a
 [`FileSystemFileHandle`](https://fs.spec.whatwg.org/#filesystemfilehandle) associated with `entry`.

 3. Else if `entry` is a [directory
 entry](https://fs.spec.whatwg.org/#directory):

 1. Let `handle` be a
 [`FileSystemDirectoryHandle`](https://fs.spec.whatwg.org/#filesystemdirectoryhandle) associated with `entry`.

 4. [Resolve](https://webidl.spec.whatwg.org/#resolve) `p` with `entry`.

 5. Return `p`.
 :::

 :::
 (#draganddrop-example) Handling drag and drop of files
 and directories:
 ``` highlight
 elem.addEventListener('dragover', (e) => {
 // Prevent navigation.
 e.preventDefault();
 });

 elem.addEventListener('drop', async (e) => {
 e.preventDefault();

 const fileHandlesPromises = [...e.dataTransfer.items]
 .filter(item => item.kind === 'file')
 .map(item => item.getAsFileSystemHandle());

 for await (const handle of fileHandlesPromises) {
 if (handle.kind === 'directory') {
 console.log(`Directory: ${handle.name}`);
 } else {
 console.log(`File: ${handle.name}`);
 }
 }
 });
 ```
 :::

 (#issue-8306b646) This currently does not block access
 to [too sensitive or
 dangerous](#wellknowndirectory-too-sensitive-or-dangerous) directories, to be consistent with other APIs that
 give access to dropped files and directories. This is inconsistent
 with the [local file system handle
 factories](#local-file-system-handle-factories) though, so we might want to reconsider this.

 ## [4. ][Accessibility Considerations](#accessibility-considerations)

 *This section is non-normative.*

 When this specification is used to present information in the user
 interface, implementors will want to follow the OS level
 accessibility guidelines for the platform.

 ## [5. ][Privacy Considerations](#privacy-considerations)

 *This section is non-normative.*

 This API does not give websites any more read access to data than
 the existing `<input type=file>` and
 `<input type=file webkitdirectory>` APIs already do. Furthermore
 similarly to those APIs, all access to files and directories is
 explicitly gated behind a file or directory picker.

 There are however several major privacy risks with this new API:

 ### [5.1. ][Users giving access to more, or more sensitive files than they intended.](#privacy-wide-access)

 This isn't a new risk with this API, but user agents should try to
 make sure that users are aware of what exactly they're giving
 websites access to. This is particularly important when giving
 access to a directory, where it might not be immediately clear to a
 user just how many files actually exist in that directory.

 A related risk is having a user give access to particularly
 sensitive data. This could include some of a user agent's
 configuration data, network cache or cookie store, or operating
 system configuration data such as password files. To protect against
 this, user agents are encouraged to restrict which directories a
 user is allowed to select in a directory picker, and potentially
 even restrict which files the user is allowed to select. This will
 make it much harder to accidentally give access to a directory that
 contains particularly sensitive data. Care must be taken to strike
 the right balance between restricting what the API can access while
 still having the API be useful. After all, this API intentionally
 lets the user use websites to interact with some of their most
 private personal data.

 Examples of directories that user agents might want to restrict as
 being [too sensitive or
 dangerous] include:

 - The directory or directories containing the user agent itself.

 - Directories where the user agent stores [website
 storage](https://storage.spec.whatwg.org/#site-storage).

 - Directories containing system files (such as `C:\Windows` on
 Windows).

 - Directories such as `/dev/`, `/sys`, and `/proc` on Linux that
 would give access to low-level devices.

 - A user's entire \"home\" directory. Individual files and
 directories inside the home directory should still be allowed, but
 user agents should not generally let users give blanket access to
 the entire directory.

 - The default directory for downloads, if the user agent has such a
 thing. Individual files inside the directory again should be
 allowed, but the whole directory would risk leaking more data than
 a user realizes.

 - Files with names that end in `.lnk`, when selecting a file to
 write to. Writing to these files on Windows is similar to creating
 symlinks on other operating systems, and as such can be used to
 attempt to trick users into giving access to files they didn't
 intend to expose.

 - Files with names that end in `.local`, when selecting a file to
 write to. Windows uses these files to decide what DLLs to load,
 and as such writing to these files could be used to cause code to
 be executed.

 ### [5.2. ][Websites trying to use this API for tracking.](#privacy-tracking)

 This API could be used by websites to track the user across clearing
 browsing data. This is because, in contrast with existing file
 access APIs, user agents are able to grant persistent access to
 files or directories and can re-prompt. In combination with the
 ability to write to files, websites will be able to persist an
 identifier on the users\' disk. Clearing browsing data will not
 affect those files in any way, making these identifiers persist
 through those actions.

 This risk is somewhat mitigated by the fact that clearing browsing
 data will clear all handles that a website had persisted (for
 example in IndexedDB), so websites won't have any handles to
 re-prompt for permission after browsing data was cleared.
 Furthermore user agents are encouraged to make it clear what files
 and directories a website has access to, and to automatically expire
 permission grants except for particularly well trusted origins (for
 example persistent permissions could be limited to \"installed\" web
 applications).

 User agents also are encouraged to provide a way for users to revoke
 permissions granted. Clearing browsing data is expected to revoke
 all permissions as well.

 ### [5.3. ][First-party vs third-party contexts.](#privacy-third-party)

 In third-party contexts (e.g. an iframe whose origin does not match
 that of the top-level frame) websites can't gain access to data they
 don't already have access to. This includes both getting access to
 new files or directories via the [local file system handle
 factories](#local-file-system-handle-factories), as well as requesting more permissions to existing
 handles via the
 [`requestPermission`](#dom-filesystemhandle-requestpermission) API.

 Handles can also only be post-messaged to same-origin destinations.
 Attempts to send a handle to a cross-origin destination will result
 in a
 [`messageerror`](https://html.spec.whatwg.org/multipage/indices.html#event-messageerror) event.

 ## [6. ][Security Considerations](#security-considerations)

 *This section is non-normative.*

 This API gives websites the ability to modify existing files on
 disk, as well as write to new files. This has a couple of important
 security considerations:

 ### [6.1. ][Malware](#security-malware)

 This API could be used by websites to try to store and/or execute
 malware on the users system. To mitigate this risk, this API does
 not provide any way to mark files as executable (on the other hand
 files that are already executable likely remain that way, even after
 the files are modified through this API). Furthermore user agents
 are encouraged to apply things like Mark-of-the-Web to files created
 or modified by this API.

 Finally, user agents are encouraged to verify the contents of files
 modified by this API via malware scans and safe browsing checks,
 unless some kind of external strong trust relation already exists.
 This of course has effects on the performance characteristics of
 this API.

 ### [6.2. ][Ransomware attacks](#security-ransomware)

 Another risk factor is that of ransomware attacks. The limitations
 described above regarding blocking access to certain sensitive
 directories helps limit the damage such an attack can do.
 Additionally user agents can grant write access to files at whatever
 granularity they deem appropriate.

 ### [6.3. ][Filling up a users disk](#filling-up-disk)

 Other than files in a [bucket file
 system](https://fs.spec.whatwg.org/#origin-private-file-system), files written by this API are not subject to
 [storage
 quota](https://storage.spec.whatwg.org/#storage-quota). As such websites can fill up a users disk without
 being limited by quota, which could leave a users device in a bad
 state (do note that even with storage that is subject to [storage
 quota](https://storage.spec.whatwg.org/#storage-quota) it is still possible to fill up, or come close to
 filling up, a users disk, since [storage
 quota](https://storage.spec.whatwg.org/#storage-quota) in general is not dependent on the amount of
 available disk space).

 Without this API websites can write data to disk not subject to
 quota limitations already by triggering downloads of large files
 (potentially created client side, to not incur any network
 overhead). While the presence of
 [`truncate()`](https://fs.spec.whatwg.org/#dom-filesystemwritablefilestream-truncate) and writing at a potentially really large offset
 past the end of a file makes it much easier and lower cost to create
 large files, on most file systems such files should not actually
 take up as much disk space as most commonly used file systems
 support sparse files (and thus wouldn't actually store the NUL bytes
 generated by resizing a file or seeking past the end of it).

 Whatever mitigations user agents use to guard against websites
 filling up a disk via either quota managed storage or the existing
 downloads mechanism should also be employed when websites use this
 API to write to disk.
