## 1. Introduction

*This section is informative.*

Web applications should have the ability to manipulate as wide as
possible a range of user input, including files that a user may wish to
upload to a remote server or manipulate inside a rich web application.
This specification defines the basic representations for files, lists of
files, errors raised by access to files, and programmatic ways to read
files. Additionally, this specification also defines an interface that
represents \"raw data\" which can be asynchronously processed on the
main thread of conforming user agents. The interfaces and API defined in
this specification can be used with other interfaces and APIs exposed to
the web platform.

The [`File`](#dfn-file)
interface represents file data typically obtained from the underlying
file system, and the [`Blob`](#dfn-Blob) interface (\"Binary Large Object\" - a name originally
introduced to web APIs in [Google
Gears](https://developers.google.com/gears/?csw=1)) represents immutable
raw data. [`File`](#dfn-file)
or [`Blob`](#dfn-Blob) reads
should happen asynchronously on the main thread, with an optional
synchronous API used within threaded web applications. An asynchronous
API for reading files prevents blocking and UI \"freezing\" on a user
agent's main thread. This specification defines an asynchronous API
based on an *event model* to read and access a
[`File`](#dfn-file) or
[`Blob`](#dfn-Blob)'s data. A
[`FileReader`](#dfn-filereader) object provides asynchronous read methods to access
that file's data through event handler content attributes and the firing
of events. The use of events and event handlers allows separate code
blocks the ability to monitor the *progress of the read* (which is
particularly useful for remote drives or mounted drives, where file
access performance may vary from local drives) and error conditions that
may arise during reading of a file. An example will be illustrative.

In the example below, different code
blocks handle progress, error, and success conditions.

``` highlight
function startRead() {
 // obtain input element through DOM

 var file = document.getElementById('file').files[0];
 if(file){
 getAsText(file);
 }
}

function getAsText(readFile) {

 var reader = new FileReader();

 // Read file into memory as UTF-16
 reader.readAsText(readFile, "UTF-16");

 // Handle progress, success, and errors
 reader.onprogress = updateProgress;
 reader.onload = loaded;
 reader.onerror = errorHandler;
}

function updateProgress(evt) {
 if (evt.lengthComputable) {
 // evt.loaded and evt.total are ProgressEvent properties
 var loaded = (evt.loaded / evt.total);
 if (loaded < 1) {
 // Increase the prog bar length
 // style.width = (loaded * 200) + "px";
 }
 }
}

function loaded(evt) {
 // Obtain the read file data
 var fileString = evt.target.result;
 // Handle UTF-16 file dump
 if(utils.regexp.isChinese(fileString)) {
 //Chinese Characters + Name validation
 }
 else {
 // run other charset test
 }
 // xhr.send(fileString)
}

function errorHandler(evt) {
 if(evt.target.error.name == "NotReadableError") {
 // The file could not be read
 }
}
```

## 2. Terminology and Algorithms

When this specification says to [terminate an
algorithm] the
user agent must terminate the algorithm after finishing the step it is
on. Asynchronous [read methods](#read-method) defined in this specification may return before the
algorithm in question is terminated, and can be terminated by an
[`abort()`](#dfn-abort) call.

The algorithms and steps in this specification use the following
mathematical operations:

- max(a,b) returns the maximum of a and b, and is always performed on
 integers as they are defined in WebIDL
 [\[WebIDL\]](#biblio-webidl "Web IDL Standard");
 in the case of max(6,4) the result is 6. This operation is also
 defined in ECMAScript
 [\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification").

- min(a,b) returns the minimum of a and b, and is always performed on
 integers as they are defined in WebIDL
 [\[WebIDL\]](#biblio-webidl "Web IDL Standard");
 in the case of min(6,4) the result is 4. This operation is also
 defined in ECMAScript
 [\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification").

- Mathematical comparisons such as \< (less than), ≤ (less than or equal
 to), and \> (greater than) are as in ECMAScript
 [\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification").

The term [Unix Epoch] is used in this specification to refer to the time 00:00:00
UTC on January 1 1970 (or 1970-01-01T00:00:00Z ISO 8601); this is the
same time that is conceptually \"`0`\" in ECMA-262
[\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification").

The [slice blob]
algorithm given a [`Blob`](#dfn-Blob) `blob`, `start`,
`end`, and `contentType` is used to refer to the
following steps and returns a new
[`Blob`](#dfn-Blob) containing
the bytes ranging from the `start` parameter up to but not
including the `end` parameter. It must act as follows:

1. Let `originalSize` be `blob`'s
 [`size`](#dfn-size).

2. The `start` parameter, if non-null, is a value for the
 start point of a [slice blob](#slice-blob) call, and must be treated as a byte-order position,
 with the zeroth position representing the first byte. User agents
 must normalize `start` according to the following:

 a. If `start` is null, let `relativeStart` be
 0.
 b. If `start` is negative, let
 `relativeStart` be
 `max((``originalSize`` + ``start``), 0)`.
 c. Otherwise, let `relativeStart` be
 `min(``start``, ``originalSize``)`.

3. The `end` parameter, if non-null. is a value for the end
 point of a [slice blob](#slice-blob) call. User agents must normalize `end`
 according to the following:

 a. If `end` is null, let `relativeEnd` be
 `originalSize`.
 b. If `end` is negative, let `relativeEnd` be
 `max((``originalSize`` + ``end``), 0)`.
 c. Otherwise, let `relativeEnd` be
 `min(``end``, ``originalSize``)`.

4. The `contentType` parameter, if non-null, is used to set
 the ASCII-encoded string in lower case representing the media type
 of the [`Blob`](#dfn-Blob). User agents must normalize
 `contentType` according to the following:

 a. If `contentType` is null, let
 `relativeContentType` be set to the empty string.
 b. Otherwise, let `relativeContentType` be set to
 `contentType` and run the substeps below:
 1. If `relativeContentType` contains any characters
 outside the range of U+0020 to U+007E, then set
 `relativeContentType` to the empty string and
 return from these substeps.

 2. Convert every character in `relativeContentType`
 to [ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase).

5. Let `span` be
 `max((``relativeEnd`` - ``relativeStart``), 0)`.

6. Return a new [`Blob`](#dfn-Blob) object `S` with the following
 characteristics:

 a. `S` refers to `span` consecutive
 [byte](https://infra.spec.whatwg.org/#byte)s from `blob`'s associated
 [byte](https://infra.spec.whatwg.org/#byte) sequence, beginning with the
 [byte](https://infra.spec.whatwg.org/#byte) at byte-order position
 `relativeStart`.
 b. `S`.[`size`](#dfn-size) = `span`.
 c. `S`.[`type`](#dfn-type) = `relativeContentType`.

## 3. The Blob Interface and Binary Data

A [`Blob`](#dfn-Blob) object
refers to a [byte](https://infra.spec.whatwg.org/#byte) sequence, and has a
[`size`](#dfn-size) attribute
which is the total number of bytes in the byte sequence, and a
[`type`](#dfn-type) attribute,
which is an ASCII-encoded string in lower case representing the media
type of the [byte](https://infra.spec.whatwg.org/#byte) sequence.

Each [`Blob`](#dfn-Blob) must
have an internal [snapshot state], which must be initially set
to the state of the underlying storage, if any such underlying storage
exists. Further normative definition of [snapshot
state](#snapshot-state) can be
found for [`File`](#dfn-file)s.

```
[Exposed=(Window,Worker), Serializable]
interface Blob {
 constructor(optional sequence<BlobPart> blobParts,
 optional BlobPropertyBag options = );

 readonly attribute unsigned long long size;
 readonly attribute DOMString type;

 // slice Blob into byte-ranged chunks
 Blob slice(optional [Clamp] long long start,
 optional [Clamp] long long end,
 optional DOMString contentType);

 // read from the Blob.
 [NewObject] ReadableStream stream();
 [NewObject] Promise<USVString> text();
 [NewObject] Promise<ArrayBuffer> arrayBuffer();
 [NewObject] ReadableStream textStream();
 [NewObject] Promise<Uint8Array> bytes();
};

enum EndingType { "transparent", "native" };

dictionary BlobPropertyBag {
 DOMString type = "";
 EndingType endings = "transparent";
};

typedef (BufferSource or Blob or USVString) BlobPart;
```

[`Blob`](#dfn-Blob) objects
are [serializable
objects](https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects). Their [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps), given `value` and `serialized`,
are:

1. Set `serialized`.\[\[SnapshotState\]\] to
 `value`'s [snapshot
 state](#snapshot-state).

2. Set `serialized`.\[\[ByteSequence\]\] to
 `value`'s underlying byte sequence.

Their [deserialization
step](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps), given `serialized` and `value`,
are:

1. Set `value`'s [snapshot
 state](#snapshot-state) to
 `serialized`.\[\[SnapshotState\]\].

2. Set `value`'s underlying byte sequence to
 `serialized`.\[\[ByteSequence\]\].

A [`Blob`](#dfn-Blob)
`blob` has an associated [get stream] algorithm, which
runs these steps:

1. Let `stream` be a
 [new](https://webidl.spec.whatwg.org/#new)
 [`ReadableStream`](https://streams.spec.whatwg.org/#readablestream) created in `blob`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

2. [Set
 up](https://streams.spec.whatwg.org/#readablestream-set-up-with-byte-reading-support) `stream` with byte reading support.

3. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. While not all bytes of `blob` have been read:

 1. Let `bytes` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence) that results from reading a
 [chunk](https://streams.spec.whatwg.org/#chunk) from `blob`, or failure if a
 chunk cannot be read.

 2. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [file reading task
 source](#fileReadingTaskSource) given `blob`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) to perform the following steps:

 1. If `bytes` is failure, then
 [error](https://streams.spec.whatwg.org/#readablestream-error) `stream` with a [failure
 reason](#failureReason) and abort these steps.

 2. Let `chunk` be a new
 [`Uint8Array`](https://webidl.spec.whatwg.org/#idl-Uint8Array) wrapping an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) containing `bytes`. If
 creating the
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) throws an exception, then
 [error](https://streams.spec.whatwg.org/#readablestream-error) `stream` with that exception
 and abort these steps.

 3. [Enqueue](https://streams.spec.whatwg.org/#readablestream-enqueue) `chunk` in
 `stream`.

 (#issue-27e70e89) We need to specify more
 concretely what reading from a Blob actually does, what possible
 errors can happen, perhaps something about chunk sizes, etc.

4. Return `stream`.

### 3.1. Constructors

The [`Blob()`](#dom-blob-blob) constructor can be invoked with zero or more
parameters. When the
[`Blob()`](#dom-blob-blob) constructor is invoked, user agents must run the
following steps:

1. If invoked with zero parameters, return a new
 [`Blob`](#dfn-Blob)
 object consisting of 0 bytes, with
 [`size`](#dfn-size) set to
 0, and with [`type`](#dfn-type) set to the empty string.

2. Let `bytes` be the result of [processing blob
 parts](#process-blob-parts) given
 [`blobParts`](#dfn-blobParts) and
 [`options`](#dom-blob-blob-blobparts-options-options).

3. If the [`type`](#dfn-BPtype) member of the
 [`options`](#dom-blob-blob-blobparts-options-options) argument is not the empty string, run the following
 sub-steps:

 1. Let `t` be the
 [`type`](#dfn-BPtype) dictionary member. If `t` contains
 any characters outside the range U+0020 to U+007E, then set
 `t` to the empty string and return from these
 substeps.

 2. Convert every character in `t` to [ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase).

4. Return a [`Blob`](#dfn-Blob) object referring to `bytes` as its
 associated
 [byte](https://infra.spec.whatwg.org/#byte) sequence, with its
 [`size`](#dfn-size) set to
 the length of `bytes`, and its
 [`type`](#dfn-type) set to
 the value of `t` from the substeps above.

#### 3.1.1. Constructor Parameters

The [`Blob()`](#dom-blob-blob) constructor can be invoked with the parameters below:

A [`blobParts`] `sequence`
: which takes any number of the following types of elements, and in
 any order:
 - [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource) elements.

 - [`Blob`](#dfn-Blob)
 elements.

 - [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString) elements.

An *optional* [`BlobPropertyBag`](#dfn-BlobPropertyBag)
: which takes these optional members:
 - [`type`], the
 ASCII-encoded string in lower case representing the media type of
 the [`Blob`](#dfn-Blob). Normative conditions for this member are
 provided in the [§ 3.1 Constructors](#constructorBlob).

 - [`endings`], an enum which can take the values
 [`"transparent"`](#dom-endingtype-transparent) or
 [`"native"`](#dom-endingtype-native). By default this is set to
 [`"transparent"`](#dom-endingtype-transparent). If set to
 [`"native"`](#dom-endingtype-native), [line endings will be converted to
 native](#convert-line-endings-to-native) in any
 [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString) elements in
 [`blobParts`](#dfn-blobParts).

To [process blob parts] given a sequence of
[`BlobPart`](#typedefdef-blobpart)'s `parts` and
[`BlobPropertyBag`](#dfn-BlobPropertyBag) `options`, run the following steps:

1. Let `bytes` be an empty sequence of bytes.

2. For each `element` in `parts`:

 1. If `element` is a
 [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString), run the following substeps:

 1. Let `s` be `element`.

 2. If the
 [`endings`](#dom-blobpropertybag-endings) member of `options` is
 [`"native"`](#dom-endingtype-native), set `s` to the result of
 [converting line endings to
 native](#convert-line-endings-to-native) of `element`.

 3. Append the result of [UTF-8
 encoding](https://encoding.spec.whatwg.org/#utf-8-encode) `s` to `bytes`.

 The algorithm from WebIDL
 [\[WebIDL\]](#biblio-webidl "Web IDL Standard")
 replaces unmatched surrogates in an invalid utf-16 string
 with U+FFFD replacement characters. Scenarios exist when the
 [`Blob`](#dfn-Blob) constructor may result in some data loss
 due to lost or scrambled character sequences.

 2. If `element` is a
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource), [get a copy of the bytes held by the buffer
 source](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy), and append those bytes to `bytes`.

 3. If `element` is a
 [`Blob`](#dfn-Blob),
 append the bytes it represents to `bytes`.

 The
 [`type`](#dfn-type) of
 the [`Blob`](#dfn-Blob) array element is ignored and will not affect
 [`type`](#dfn-type) of
 returned [`Blob`](#dfn-Blob) object.

3. Return `bytes`.

To [ convert line endings to native] in a
[string](https://infra.spec.whatwg.org/#string) `s`, run the following steps:

1. Let `native line ending` be the [code
 point](https://infra.spec.whatwg.org/#code-point) U+000A LF.

2. If the underlying platform's conventions are to represent newlines
 as a carriage return and line feed sequence, set
 `native line ending` to the [code
 point](https://infra.spec.whatwg.org/#code-point) U+000D CR followed by the [code
 point](https://infra.spec.whatwg.org/#code-point) U+000A LF.

3. Set `result` to the empty
 [string](https://infra.spec.whatwg.org/#string).

4. Let `position` be a [position
 variable](https://infra.spec.whatwg.org/#string-position-variable) for `s`, initially pointing at the start
 of `s`.

5. Let `token` be the result of [collecting a sequence of
 code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) that are not equal to U+000A LF or U+000D CR from
 `s` given `position`.

6. Append `token` to `result`.

7. While `position` is not past the end of `s`:

 1. If the [code
 point](https://infra.spec.whatwg.org/#code-point) at `position` within `s`
 equals U+000D CR:

 1. Append `native line ending` to
 `result`.

 2. Advance `position` by 1.

 3. If `position` is not past the end of
 `s` and the [code
 point](https://infra.spec.whatwg.org/#code-point) at `position` within
 `s` equals U+000A LF advance
 `position` by 1.

 2. Otherwise if the [code
 point](https://infra.spec.whatwg.org/#code-point) at `position` within `s`
 equals U+000A LF, advance `position` by 1 and append
 `native line ending` to `result`.

 3. Let `token` be the result of [collecting a sequence
 of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) that are not equal to U+000A LF or U+000D CR
 from `s` given `position`.

 4. Append `token` to `result`.

8. Return `result`.

Examples of constructor usage follow.

```
// Create a new Blob object

var a = new Blob();

// Create a 1024-byte ArrayBuffer
// buffer could also come from reading a File

var buffer = new ArrayBuffer(1024);

// Create ArrayBufferView objects based on buffer

var shorts = new Uint16Array(buffer, 512, 128);
var bytes = new Uint8Array(buffer, shorts.byteOffset + shorts.byteLength);

var b = new Blob(["foobarbazetcetc" + "birdiebirdieboo"], {type: "text/plain;charset=utf-8"});

var c = new Blob([b, shorts]);

var a = new Blob([b, c, bytes]);

var d = new Blob([buffer, b, c, bytes]);
```

### 3.2. Attributes

[`size`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly
: Returns the size of the
 [byte](https://infra.spec.whatwg.org/#byte) sequence in number of bytes. On getting, conforming
 user agents must return the total number of bytes that can be read
 by a [`FileReader`](#dfn-filereader) or
 [`FileReaderSync`](#dfn-FileReaderSync) object, or 0 if the
 [`Blob`](#dfn-Blob) has
 no bytes to be read.

[`type`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: The ASCII-encoded string in lower case representing the media type
 of the [`Blob`](#dfn-Blob). On getting, user agents must return the type of a
 [`Blob`](#dfn-Blob) as an
 ASCII-encoded string in lower case, such that when it is converted
 to a [byte](https://infra.spec.whatwg.org/#byte) sequence, it is a [parsable MIME
 type](https://mimesniff.spec.whatwg.org/#parsable-mime-type), or the empty string -- 0 bytes -- if the type
 cannot be determined.

 The [`type`](#dfn-type)
 attribute can be set by the web application itself through
 constructor invocation and through the
 [`slice()`](#dfn-slice)
 call; in these cases, further normative conditions for this
 attribute are in [§ 3.1 Constructors](#constructorBlob), [§ 4.1
 Constructor](#file-constructor), and [§ 3.3.1 The slice()
 method](#slice-method-algo) respectively. User agents can also
 determine the [`type`](#dfn-type) of a [`Blob`](#dfn-Blob), especially if the
 [byte](https://infra.spec.whatwg.org/#byte) sequence is from an on-disk file; in this case,
 further normative conditions are in the [file type
 guidelines](#file-type-guidelines).

 The type `t` of a
 [`Blob`](#dfn-Blob) is
 considered a [parsable MIME
 type](https://mimesniff.spec.whatwg.org/#parsable-mime-type), if performing the [parse a MIME
 type](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) algorithm to a byte sequence converted from the
 ASCII-encoded string representing the Blob object's type does not
 return failure.

 Use of the
 [`type`](#dfn-type)
 attribute informs the [package
 data](#blob-package-data) algorithm and determines the `Content-Type` header
 when
 [fetching](https://fetch.spec.whatwg.org/#concept-fetch) [blob URLs](#blob-url).

### 3.3. Methods and Parameters

#### 3.3.1. The [`slice()` method]
The [`slice()`]
method returns a new [`Blob`](#dfn-Blob) object with bytes ranging from the optional
`start` parameter up to but not including the optional
`end` parameter, and with a
[`type`](#dfn-type) attribute
that is the value of the optional `contentType` parameter. It
must act as follows:

1. Let `sliceStart`, `sliceEnd`, and
 `sliceContentType` be null.

2. If `start` is given, set `sliceStart` to
 `start`.

3. If `end` is given, set `sliceEnd` to
 `end`.

4. If `contentType` is given, set
 `sliceContentType` to `contentType`.

5. Return the result of [slice blob](#slice-blob) given
 [this](https://webidl.spec.whatwg.org/#this), `sliceStart`, `sliceEnd`,
 and `sliceContentType`.

The examples below illustrate the
different types of [`slice()`](#dfn-slice) calls possible. Since the
[`File`](#dfn-file) interface
inherits from the [`Blob`](#dfn-Blob) interface, examples are based on the use of the
[`File`](#dfn-file) interface.

```
// obtain input element through DOM

var file = document.getElementById('file').files[0];
if(file)
{
 // create an identical copy of file
 // the two calls below are equivalent

 var fileClone = file.slice();
 var fileClone2 = file.slice(0, file.size);

 // slice file into 1/2 chunk starting at middle of file
 // Note the use of negative number

 var fileChunkFromEnd = file.slice(-(Math.round(file.size/2)));

 // slice file into 1/2 chunk starting at beginning of file

 var fileChunkFromStart = file.slice(0, Math.round(file.size/2));

 // slice file from beginning till 150 bytes before end

 var fileNoMetadata = file.slice(0, -150, "application/experimental");
}
```

#### 3.3.2. The [`stream()` method]
The [`stream()`] method, when invoked, must
return the result of calling [get
stream](#blob-get-stream) on
[this](https://webidl.spec.whatwg.org/#this).

#### 3.3.3. The [`text()` method]
The [`text()`] method, when invoked, must run these steps:

1. Let `stream` be the result of calling [get
 stream](#blob-get-stream)
 on [this](https://webidl.spec.whatwg.org/#this).

2. Let `reader` be the result of [getting a
 reader](https://streams.spec.whatwg.org/#readablestream-get-a-reader) from `stream`. If that threw an
 exception, return a new promise rejected with that exception.

3. Let `promise` be the result of [reading all
 bytes](https://streams.spec.whatwg.org/#readablestreamdefaultreader-read-all-bytes) from `stream` with `reader`.

4. Return the result of transforming `promise` by a
 fulfillment handler that returns the result of running [UTF-8
 decode](https://encoding.spec.whatwg.org/#utf-8-decode) on its first argument.

 This is different from the behavior of
[`readAsText()`](#dfn-readAsText) to align better with the behavior of
[`Fetch’s text()`](https://fetch.spec.whatwg.org/#dom-body-text). Specifically this method will always use UTF-8 as
encoding, while
[`FileReader`](#dfn-filereader) can use a different encoding depending on the blob's
type and passed in encoding name.

#### 3.3.4. The [`arrayBuffer()` method]
The [`arrayBuffer()`] method, when invoked, must
run these steps:

1. Let `stream` be the result of calling [get
 stream](#blob-get-stream)
 on [this](https://webidl.spec.whatwg.org/#this).

2. Let `reader` be the result of [getting a
 reader](https://streams.spec.whatwg.org/#readablestream-get-a-reader) from `stream`. If that threw an
 exception, return a new promise rejected with that exception.

3. Let `promise` be the result of [reading all
 bytes](https://streams.spec.whatwg.org/#readablestreamdefaultreader-read-all-bytes) from `stream` with `reader`.

4. Return the result of transforming `promise` by a
 fulfillment handler that returns a new
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) whose contents are its first argument.

#### 3.3.5. The [`bytes()` method]
The [`bytes()`] method, when invoked, must
run these steps:

1. Let `stream` be the result of calling [get
 stream](#blob-get-stream)
 on [this](https://webidl.spec.whatwg.org/#this).

2. Let `reader` be the result of [getting a
 reader](https://streams.spec.whatwg.org/#readablestream-get-a-reader) from `stream`. If that threw an
 exception, return a new promise rejected with that exception.

3. Let `promise` be the result of [reading all
 bytes](https://streams.spec.whatwg.org/#readablestreamdefaultreader-read-all-bytes) from `stream` with `reader`.

4. Return the result of transforming `promise` by a
 fulfillment handler that returns a new
 [`Uint8Array`](https://webidl.spec.whatwg.org/#idl-Uint8Array) wrapping an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) containing its first argument.

#### 3.3.6. The [`textStream()` method]
The [`textStream()`] method steps are:

1. Let `stream` be the result of calling [get
 stream](#blob-get-stream)
 on [this](https://webidl.spec.whatwg.org/#this).

2. Let `decoder` be a new
 [`TextDecoderStream`](https://encoding.spec.whatwg.org/#textdecoderstream) in
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

3. [Set
 up](https://encoding.spec.whatwg.org/#set-up-a-text-decoder-stream) `decoder` with
 [UTF-8](https://encoding.spec.whatwg.org/#utf-8).

4. Return the result of calling `stream`, [piped
 through](https://streams.spec.whatwg.org/#readablestream-pipe-through) `decoder`.

 This differs from
[`readAsText()`](#dfn-readAsText) in that it always uses the
[UTF-8](https://encoding.spec.whatwg.org/#utf-8) encoding.

## 4. The File Interface

A [`File`](#dfn-file) object
is a [`Blob`](#dfn-Blob)
object with a [`name`](#dfn-name) attribute, which is a string; it can be created within
the web application via a constructor, or is a reference to a
[byte](https://infra.spec.whatwg.org/#byte) sequence from a file from the underlying (OS) file
system.

If a [`File`](#dfn-file)
object is a reference to a
[byte](https://infra.spec.whatwg.org/#byte) sequence originating from a file on disk, then its
[snapshot state](#snapshot-state) should be set to the state of the file on disk at the
time the [`File`](#dfn-file)
object is created.

 This is a non-trivial requirement to implement for user
agents, and is thus not a *must* but a *should*
[\[RFC2119\]](#biblio-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels").
User agents should endeavor to have a
[`File`](#dfn-file) object's
[snapshot state](#snapshot-state) set to the state of the underlying storage on disk at
the time the reference is taken. If the file is modified on disk
following the time a reference has been taken, the
[`File`](#dfn-file)'s
[snapshot state](#snapshot-state) will differ from the state of the underlying storage.
User agents may use modification time stamps and other mechanisms to
maintain [snapshot state](#snapshot-state), but this is left as an implementation detail.

When a [`File`](#dfn-file)
object refers to a file on disk, user agents must return the
[`type`](#dfn-type) of that
file, and must follow the [file type guidelines] below:

- User agents must return the
 [`type`](#dfn-type) as an
 ASCII-encoded string in lower case, such that when it is converted to
 a corresponding byte sequence, it is a [parsable MIME
 type](https://mimesniff.spec.whatwg.org/#parsable-mime-type), or the empty string -- 0 bytes -- if the type cannot
 be determined.

- When the file is of type `text/plain` user agents must NOT append a
 charset parameter to the *dictionary of parameters* portion of the
 media type
 [\[MIMESNIFF\]](#biblio-mimesniff "MIME Sniffing Standard").

- User agents must not attempt heuristic determination of encoding,
 including statistical methods.

```
[Exposed=(Window,Worker), Serializable]
interface File : Blob {
 constructor(sequence<BlobPart> fileBits,
 USVString fileName,
 optional FilePropertyBag options = );
 readonly attribute DOMString name;
 readonly attribute long long lastModified;
};

dictionary FilePropertyBag : BlobPropertyBag {
 long long lastModified;
};
```

[`File`](#dfn-file) objects
are [serializable
objects](https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects). Their [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps), given `value` and `serialized`,
are:

1. Set `serialized`.\[\[SnapshotState\]\] to
 `value`'s [snapshot
 state](#snapshot-state).

2. Set `serialized`.\[\[ByteSequence\]\] to
 `value`'s underlying byte sequence.

3. Set `serialized`.\[\[Name\]\] to the value of
 `value`'s [`name`](#dfn-name) attribute.

4. Set `serialized`.\[\[LastModified\]\] to the value of
 `value`'s
 [`lastModified`](#dfn-lastModified) attribute.

Their [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps), given `value` and `serialized`,
are:

1. Set `value`'s [snapshot
 state](#snapshot-state) to
 `serialized`.\[\[SnapshotState\]\].

2. Set `value`'s underlying byte sequence to
 `serialized`.\[\[ByteSequence\]\].

3. Initialize the value of `value`'s
 [`name`](#dfn-name)
 attribute to `serialized`.\[\[Name\]\].

4. Initialize the value of `value`'s
 [`lastModified`](#dfn-lastModified) attribute to
 `serialized`.\[\[LastModified\]\].

### 4.1. Constructor

The [`File`](#dfn-file)
constructor is invoked with two or three parameters, depending on
whether the optional dictionary parameter is used. When the
[`File()`](#dom-file-file)
constructor is invoked, user agents must run the following steps:

1. Let `bytes` be the result of [processing blob
 parts](#process-blob-parts) given
 [`fileBits`](#dfn-fileBits) and
 [`options`](#dom-file-file-filebits-filename-options-options).

2. Let `n` be the
 [`fileName`](#dfn-fileName) argument to the constructor.

 Underlying OS filesystems use differing conventions
 for file name; with constructed files, mandating UTF-16 lessens
 ambiquity when file names are converted to
 [byte](https://infra.spec.whatwg.org/#byte) sequences.

3. Process
 [`FilePropertyBag`](#dfn-FilePropertyBag) dictionary argument by running the following
 substeps:

 1. If the [`type`](#dfn-BPtype) member is provided and is not the empty string,
 let `t` be set to the
 [`type`](#dfn-BPtype) dictionary member. If `t` contains
 any characters outside the range U+0020 to U+007E, then set
 `t` to the empty string and return from these
 substeps.

 2. Convert every character in `t` to [ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase).

 3. If the [`lastModified`](#dfn-FPdate) member is provided, let `d` be set
 to the [`lastModified`](#dfn-FPdate) dictionary member. If it is not provided, set
 `d` to the current date and time represented as the
 number of milliseconds since the [Unix
 Epoch](#UnixEpoch) (which is
 the equivalent of `Date.now()`
 [\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification")).

 Since ECMA-262
 [`Date`](http://tc39.github.io/ecma262/#sec-date-constructor) objects convert to `long long` values
 representing the number of milliseconds since the [Unix
 Epoch](#UnixEpoch), the
 [`lastModified`](#dfn-FPdate) member could be a
 [`Date`](http://tc39.github.io/ecma262/#sec-date-constructor) object
 [\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification").

4. Return a new [`File`](#dfn-file) object `F` such that:

 2. `F` refers to the `bytes`
 [byte](https://infra.spec.whatwg.org/#byte) sequence.

 3. `F`.[`size`](#dfn-size) is set to the number of total bytes in
 `bytes`.

 4. `F`.[`name`](#dfn-name) is set to `n`.

 5. `F`.[`type`](#dfn-type) is set to `t`.

 6. `F`.[`lastModified`](#dfn-lastModified) is set to `d`.

#### 4.1.1. Constructor Parameters

The [`File()`](#dom-file-file) constructor can be invoked with the parameters below:

A [`fileBits`] `sequence`
: which takes any number of the following elements, and in any order:
 - [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource) elements.

 - [`Blob`](#dfn-Blob)
 elements, which includes
 [`File`](#dfn-file)
 elements.

 - [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString) elements.

A [`fileName`] parameter
: A
 [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString) parameter representing the name of the file;
 normative conditions for this constructor parameter can be found in
 [§ 4.1 Constructor](#file-constructor).

An optional [`FilePropertyBag`](#dfn-FilePropertyBag) dictionary
: which in addition to the [members](#dfn-BlobPropertyBagMembers) of
 [`BlobPropertyBag`](#dfn-BlobPropertyBag) takes one member:
 - An optional [`lastModified`] member, which must be a `long long`; normative
 conditions for this member are provided in [§ 4.1
 Constructor](#file-constructor).

### 4.2. Attributes

[`name`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly
: The name of the file. On getting, this must return the name of the
 file as a string. There are numerous file name variations and
 conventions used by different underlying OS file systems; this is
 merely the name of the file, without path information. On getting,
 if user agents cannot make this information available, they must
 return the empty string. If a
 [`File`](#dfn-file)
 object is created using a constructor, further normative conditions
 for this attribute are found in [§ 4.1
 Constructor](#file-constructor).

[`lastModified`], of type [long long](https://webidl.spec.whatwg.org/#idl-long-long), readonly
: The last modified date of the file. On getting, if user agents can
 make this information available, this must return a `long long` set
 to the time the file was last modified as the number of milliseconds
 since the [Unix Epoch](#UnixEpoch). If the last modification date and time are not
 known, the attribute must return the current date and time as a
 `long long` representing the number of milliseconds since the [Unix
 Epoch](#UnixEpoch); this is
 equivalent to `Date.now()`
 [\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification").
 If a [`File`](#dfn-file)
 object is created using a constructor, further normative conditions
 for this attribute are found in [§ 4.1
 Constructor](#file-constructor).

The [`File`](#dfn-file)
interface is available on objects that expose an attribute of type
[`FileList`](#dfn-filelist); these objects are defined in HTML
[\[HTML\]](#biblio-html "HTML Standard"). The
[`File`](#dfn-file)
interface, which inherits from
[`Blob`](#dfn-Blob), is
immutable, and thus represents file data that can be read into memory at
the time a [read operation](#readOperation) is initiated. User agents must process reads on files
that no longer exist at the time of read as
[errors](#file-error-read),
throwing a
[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror) exception if using a
[`FileReaderSync`](#dfn-FileReaderSync) on a Web Worker
[\[Workers\]](#biblio-workers "Web Workers") or
firing an [`error`] event with the
[`error`](#dom-filereader-error) attribute returning a
[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror).

In the examples below, metadata from a
file object is displayed meaningfully, and a file object is created with
a name and a last modified date.

```
var file = document.getElementById("filePicker").files[0];
var date = new Date(file.lastModified);
println("You selected the file " + file.name + " which was modified on " + date.toDateString() + ".");

...

// Generate a file with a specific last modified date

var d = new Date(2013, 12, 5, 16, 23, 45, 600);
var generatedFile = new File(["Rough Draft ...."], "Draft1.txt", {type: "text/plain", lastModified: d})

...
```

## 5. The FileList Interface

 The
[`FileList`](#dfn-filelist) interface should be considered \"at risk\" since the
general trend on the Web Platform is to replace such interfaces with the
[`Array`](http://tc39.github.io/ecma262/#sec-array-constructor) platform object in ECMAScript
[\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification").
In particular, this means syntax of the sort
`filelist.item(0)` is at risk; most other
programmatic use of
[`FileList`](#dfn-filelist) is unlikely to be affected by the eventual migration to
an
[`Array`](http://tc39.github.io/ecma262/#sec-array-constructor) type.

This interface is a list of
[`File`](#dfn-file) objects.

```
[Exposed=(Window,Worker), Serializable]
interface FileList {
 getter File? item(unsigned long index);
 readonly attribute unsigned long length;
};
```

[`FileList`](#dfn-filelist) objects are [serializable
objects](https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects). Their [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps), given `value` and `serialized`,
are:

1. Set `serialized`.\[\[Files\]\] to an empty
 [list](https://infra.spec.whatwg.org/#list).

2. For each `file` in `value`, append the
 [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization) of `file` to
 `serialized`.\[\[Files\]\].

Their [deserialization
step](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps), given `serialized` and `value`,
are:

1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `file` of
 `serialized`.\[\[Files\]\], add the
 [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization) of `file` to `value`.

Sample usage typically involves DOM
access to the `<input type="file">` element within a form, and then
accessing selected files.

```
// uploadData is a form element
// fileChooser is input element of type 'file'
var file = document.forms['uploadData']['fileChooser'].files[0];

// alternative syntax can be
// var file = document.forms['uploadData']['fileChooser'].files.item(0);

if(file)
{
 // Perform file ops
}
```

### 5.1. Attributes

[`length`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly
: must return the number of files in the
 [`FileList`](#dfn-filelist) object. If there are no files, this attribute must
 return 0.

### 5.2. Methods and Parameters

[`item(index)`]

: must return the `index`th
 [`File`](#dfn-file)
 object in the
 [`FileList`](#dfn-filelist). If there is no `index`th
 [`File`](#dfn-file)
 object in the
 [`FileList`](#dfn-filelist), then this method must return `null`.

 [`index`] must
 be treated by user agents as value for the position of a
 [`File`](#dfn-file)
 object in the
 [`FileList`](#dfn-filelist), with 0 representing the first file. [Supported
 property
 indices](https://webidl.spec.whatwg.org/#dfn-supported-property-indices) are the numbers in the range zero to one less than
 the number of [`File`](#dfn-file) objects represented by the
 [`FileList`](#dfn-filelist) object. If there are no such
 [`File`](#dfn-file)
 objects, then there are no supported property indices.

 The
[`HTMLInputElement`](https://html.spec.whatwg.org/multipage/input.html#htmlinputelement) interface has a readonly attribute of type
[`FileList`](#dfn-filelist), which is what is being accessed in the above example.
Other interfaces with a readonly attribute of type
[`FileList`](#dfn-filelist) include the
[`DataTransfer`](https://html.spec.whatwg.org/multipage/dnd.html#datatransfer) interface.

## 6. Reading Data

### 6.1. The File Reading Task Source

This specification defines a new generic [task
source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source) called the [file reading task
source], which is used for all [tasks that are
queued](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) in this specification to read byte sequences associated
with [`Blob`](#dfn-Blob) and
[`File`](#dfn-file) objects.
It is to be used for features that trigger in response to asynchronously
reading binary data.

### 6.2. The [`FileReader` API]
```
[Exposed=(Window,Worker)]
interface FileReader: EventTarget {
 constructor();
 // async read methods
 undefined readAsArrayBuffer(Blob blob);
 undefined readAsBinaryString(Blob blob);
 undefined readAsText(Blob blob, optional DOMString encoding);
 undefined readAsDataURL(Blob blob);

 undefined abort();

 // states
 const unsigned short EMPTY = 0;
 const unsigned short LOADING = 1;
 const unsigned short DONE = 2;

 readonly attribute unsigned short readyState;

 // File or Blob data
 readonly attribute (DOMString or ArrayBuffer)? result;

 readonly attribute DOMException? error;

 // event handler content attributes
 attribute EventHandler onloadstart;
 attribute EventHandler onprogress;
 attribute EventHandler onload;
 attribute EventHandler onabort;
 attribute EventHandler onerror;
 attribute EventHandler onloadend;
};
```

A [`FileReader`](#dfn-filereader) has an associated [state], that is
`"empty"`, `"loading"`, or `"done"`. It is initially `"empty"`.

A [`FileReader`](#dfn-filereader) has an associated [result] (`null`, a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) or an
[`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)). It is initially `null`.

A [`FileReader`](#dfn-filereader) has an associated [error] (`null` or
a
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)). It is initially `null`.

The [`FileReader()`] constructor, when invoked, must return
a new [`FileReader`](#dfn-filereader) object.

The [`readyState`]
attribute's getter, when invoked, switches on
[this](https://webidl.spec.whatwg.org/#this)'s [state](#filereader-state) and runs the associated step:

`"empty"`

: Return
 [`EMPTY`](#dom-filereader-empty)

`"loading"`

: Return
 [`LOADING`](#dom-filereader-loading)

`"done"`

: Return
 [`DONE`](#dom-filereader-done)

The [`result`] attribute's getter,
when invoked, must return
[this](https://webidl.spec.whatwg.org/#this)'s
[result](#filereader-result).

The [`error`] attribute's getter,
when invoked, must return
[this](https://webidl.spec.whatwg.org/#this)'s [error](#filereader-error).

A [`FileReader`](#dfn-filereader) `fr` has an associated [read
operation]
algorithm, which given `blob`, a `type` and an
optional `encodingLabel`, runs the following steps:

1. If `fr`'s
 [state](#filereader-state) is `"loading"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. Set `fr`'s
 [state](#filereader-state) to `"loading"`.

3. Set `fr`'s
 [result](#filereader-result) to `null`.

4. Set `fr`'s
 [error](#filereader-error) to `null`.

5. Let `stream` be the result of calling [get
 stream](#blob-get-stream)
 on `blob`.

6. Let `reader` be the result of [getting a
 reader](https://streams.spec.whatwg.org/#readablestream-get-a-reader) from `stream`.

7. Let `bytes` be an empty [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence).

8. Let `chunkPromise` be the result of [reading a
 chunk](https://streams.spec.whatwg.org/#readablestreamdefaultreader-read-a-chunk) from `stream` with `reader`.

9. Let `isFirstChunk` be true.

10. [In
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel), while true:

 1. Wait for `chunkPromise` to be fulfilled or rejected.

 2. If `chunkPromise` is fulfilled, and
 `isFirstChunk` is true, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [fire a progress
 event](#fire-a-progress-event) called
 [`loadstart`](#dfn-loadstart-event) at `fr`.

 (#issue-0504580b) We might change
 [`loadstart`](#dfn-loadstart-event) to be dispatched synchronously, to align with
 XMLHttpRequest behavior. [\[Issue
 #119\]](https://github.com/w3c/FileAPI/issues/119)

 3. Set `isFirstChunk` to false.

 4. If `chunkPromise` is fulfilled with an object whose
 `done` property is false and whose `value` property is a
 `Uint8Array` object, run these steps:

 1. Let `bs` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence) represented by the `Uint8Array` object.

 2. Append `bs` to `bytes`.

 3. If roughly 50ms have passed since these steps were last
 invoked, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [fire a progress
 event](#fire-a-progress-event) called
 [`progress`](#dfn-progress-event) at `fr`.

 4. Set `chunkPromise` to the result of [reading a
 chunk](https://streams.spec.whatwg.org/#readablestreamdefaultreader-read-a-chunk) from `stream` with
 `reader`.

 5. Otherwise, if `chunkPromise` is fulfilled with an
 object whose `done` property is true, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps and abort this
 algorithm:

 1. Set `fr`'s
 [state](#filereader-state) to `"done"`.

 2. Let `result` be the result of [package
 data](#blob-package-data) given `bytes`,
 `type`, `blob`'s
 [`type`](#dfn-type), and `encodingLabel`.

 3. If [package
 data](#blob-package-data) threw an exception `error`:

 1. Set `fr`'s
 [error](#filereader-error) to `error`.

 2. [Fire a progress
 event](#fire-a-progress-event) called [`error`] at
 `fr`.

 4. Else:

 1. Set `fr`'s
 [result](#filereader-result) to `result`.

 2. [Fire a progress
 event](#fire-a-progress-event) called
 [`load`](#dfn-load-event) at the `fr`.

 5. If `fr`'s
 [state](#filereader-state) is not `"loading"`, [fire a progress
 event](#fire-a-progress-event) called
 [`loadend`](#dfn-loadend-event) at the `fr`.

 Event handler for the
 [`load`](#dfn-load-event) or [`error`] events could
 have started another load, if that happens the
 [`loadend`](#dfn-loadend-event) event for this load is not fired.

 6. Otherwise, if `chunkPromise` is rejected with an
 error `error`, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps and abort this
 algorithm:

 1. Set `fr`'s
 [state](#filereader-state) to `"done"`.

 2. Set `fr`'s
 [error](#filereader-error) to `error`.

 3. [Fire a progress
 event](#fire-a-progress-event) called [`error`] at
 `fr`.

 4. If `fr`'s
 [state](#filereader-state) is not `"loading"`, [fire a progress
 event](#fire-a-progress-event) called
 [`loadend`](#dfn-loadend-event) at `fr`.

 Event handler for the
 [`error`] event could have started another
 load, if that happens the
 [`loadend`](#dfn-loadend-event) event for this load is not fired.

Use the [file reading task
source](#fileReadingTaskSource) for all these tasks.

#### 6.2.1. Event Handler Content Attributes

The following are the [event handler content
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-content-attributes) (and their corresponding [event handler event
types](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)) that user agents must support on
[`FileReader`](#dfn-filereader) as DOM attributes:

[event handler content
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-content-attributes)

[event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)

[`onloadstart`]

[`loadstart`](#dfn-loadstart-event)

[`onprogress`]

[`progress`](#dfn-progress-event)

[`onabort`]

[`abort`]

[`onerror`]

[`error`]

[`onload`]

[`load`](#dfn-load-event)

[`onloadend`]

[`loadend`](#dfn-loadend-event)

#### 6.2.2. FileReader States

The [`FileReader`](#dfn-filereader) object can be in one of 3 states. The
[`readyState`](#dom-filereader-readystate) attribute tells you in which state the object is:

[`EMPTY`](#dom-filereader-empty) (numeric value 0)

: The [`FileReader`](#dfn-filereader) object has been constructed, and there are no
 pending reads. None of the [read
 methods](#read-method) have
 been called. This is the default state of a newly minted
 [`FileReader`](#dfn-filereader) object, until one of the [read
 methods](#read-method) have
 been called on it.

[`LOADING`](#dom-filereader-loading) (numeric value 1)

: A [`File`](#dfn-file) or
 [`Blob`](#dfn-Blob) is
 being read. One of the [read
 methods](#read-method) is
 being processed, and no error has occurred during the read.

[`DONE`](#dom-filereader-done) (numeric value 2)

: The entire [`File`](#dfn-file) or [`Blob`](#dfn-Blob) has been read into memory, OR a [file read
 error](#file-error-read)
 occurred, OR the read was aborted using
 [`abort()`](#dfn-abort).
 The [`FileReader`](#dfn-filereader) is no longer reading a
 [`File`](#dfn-file) or
 [`Blob`](#dfn-Blob). If
 [`readyState`](#dom-filereader-readystate) is set to
 [`DONE`](#dom-filereader-done) it means at least one of the [read
 methods](#read-method) have
 been called on this
 [`FileReader`](#dfn-filereader).

#### 6.2.3. Reading a File or Blob

The [`FileReader`](#dfn-filereader) interface makes available several [asynchronous read
methods]---​[`readAsArrayBuffer()`](#dfn-readAsArrayBuffer),
[`readAsBinaryString()`](#dfn-readAsBinaryString),
[`readAsText()`](#dfn-readAsText) and
[`readAsDataURL()`](#dfn-readAsDataURL), which read files into memory.

 If multiple concurrent read methods are called on the
same [`FileReader`](#dfn-filereader) object, user agents throw an
[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) on any of the read methods that occur when
[`readyState`](#dom-filereader-readystate) =
[`LOADING`](#dom-filereader-loading).

([`FileReaderSync`](#dfn-FileReaderSync) makes available several [synchronous read
methods](#read-method-sync).
Collectively, the sync and async read methods of
[`FileReader`](#dfn-filereader) and
[`FileReaderSync`](#dfn-FileReaderSync) are referred to as just [read methods].)

##### 6.2.3.1. The [`readAsDataURL()` method]
The [`readAsDataURL(``blob``)`]
method, when invoked, must initiate a [read
operation](#readOperation) for
`blob` with *DataURL*.

##### 6.2.3.2. The [`readAsText()` method]
The
[`readAsText(``blob``, ``encoding``)`] method, when
invoked, must initiate a [read
operation](#readOperation) for
`blob` with *Text* and `encoding`.

##### 6.2.3.3. The [`readAsArrayBuffer()`]
The [`readAsArrayBuffer(``blob``)`] method, when invoked, must initiate a [read
operation](#readOperation) for
`blob` with *ArrayBuffer*.

##### 6.2.3.4. The [`readAsBinaryString()` method]
The [`readAsBinaryString(``blob``)`] method, when invoked, must initiate a [read
operation](#readOperation) for
`blob` with *BinaryString*.

 The use of
[`readAsArrayBuffer()`](#dfn-readAsArrayBuffer) is preferred over
[`readAsBinaryString()`](#dfn-readAsBinaryString), which is provided for backwards compatibility.

##### 6.2.3.5. The [`abort()` method]
When the [`abort()`] method is called, the
user agent must run the steps below:

1. If [this](https://webidl.spec.whatwg.org/#this)'s
 [state](#filereader-state) is `"empty"` or if
 [this](https://webidl.spec.whatwg.org/#this)'s
 [state](#filereader-state) is `"done"` set
 [this](https://webidl.spec.whatwg.org/#this)'s
 [result](#filereader-result) to `null` and [terminate this
 algorithm](#terminate-an-algorithm).

2. If [this](https://webidl.spec.whatwg.org/#this)'s
 [state](#filereader-state) is `"loading"` set
 [this](https://webidl.spec.whatwg.org/#this)'s
 [state](#filereader-state) to `"done"` and set
 [this](https://webidl.spec.whatwg.org/#this)'s
 [result](#filereader-result) to `null`.

3. If there are any
 [tasks](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task) from
 [this](https://webidl.spec.whatwg.org/#this) on the [file reading task
 source](#fileReadingTaskSource) in an affiliated [task
 queue](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task), then remove those
 [tasks](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task) from that task queue.

4. [Terminate the
 algorithm](#terminate-an-algorithm) for the [read
 method](#read-method) being
 processed.

5. [Fire a progress
 event](#fire-a-progress-event) called [`abort`] at
 [this](https://webidl.spec.whatwg.org/#this).

6. If [this](https://webidl.spec.whatwg.org/#this)'s
 [state](#filereader-state) is not `"loading"`, [fire a progress
 event](#fire-a-progress-event) called
 [`loadend`](#dfn-loadend-event) at
 [this](https://webidl.spec.whatwg.org/#this).

### 6.3. Packaging data

A [`Blob`](#dfn-Blob) has an
associated [package data] algorithm, given
`bytes`, a `type`, a `mimeType`, and an
optional `encodingLabel`, which switches on `type`
and runs the associated steps:

DataURL

: Return `bytes` as a DataURL
 [\[RFC2397\]](#biblio-rfc2397 "The "data" URL scheme")
 subject to the considerations below:

 - Use `mimeType` as part of the Data URL if it is not the
 empty string in keeping with the Data URL specification
 [\[RFC2397\]](#biblio-rfc2397 "The "data" URL scheme").

 - Otherwise, return a Data URL without a media-type.
 [\[RFC2397\]](#biblio-rfc2397 "The "data" URL scheme").

 (#issue-f80bda5b) Better specify how the DataURL is
 generated. [\[Issue
 #104\]](https://github.com/w3c/FileAPI/issues/104)

Text

: 1. Let `encoding` be failure.

 2. If the `encodingLabel` is present, set
 `encoding` to the result of [getting an
 encoding](https://encoding.spec.whatwg.org/#concept-encoding-get) from `encodingLabel`.

 3. If `encoding` is failure:

 1. Let `type` be the result of [parse a MIME
 type](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) given `mimeType`.

 2. If `type` is not failure, set
 `encoding` to the result of [getting an
 encoding](https://encoding.spec.whatwg.org/#concept-encoding-get) from `type`'s
 [parameters](https://mimesniff.spec.whatwg.org/#parameters)\[`"charset"`\].

 :::
 (#example-161c55fc) If `blob` has a
 [`type`](#dfn-type) attribute of `text/plain;charset=utf-8`
 then [getting an
 encoding](https://encoding.spec.whatwg.org/#concept-encoding-get) is run using `"utf-8"` as the label. Note
 that user agents must parse and extract the portion of the
 Charset Parameter that constitutes a *label* of an encoding.
 :::

 4. If `encoding` is failure, then set
 `encoding` to
 [UTF-8](https://encoding.spec.whatwg.org/#utf-8).

 5. [Decode](https://encoding.spec.whatwg.org/#decode) `bytes` using fallback encoding
 `encoding`, and return the result.

ArrayBuffer

: Return a new `ArrayBuffer` whose contents are `bytes`.

BinaryString

: Return `bytes` as a binary string, in which every byte is
 represented by a code unit of equal value \[0..255\].

### 6.4. Events

The [`FileReader`](#dfn-filereader) object must be the event target for all events in this
specification.

When this specification says to [fire a progress
event] *called e* (for some
[`ProgressEvent`](https://xhr.spec.whatwg.org/#progressevent) `e` at a given
[`FileReader`](#dfn-filereader) `reader`), the following are normative:

- The progress event `e` does not bubble. `e.bubbles` must be false
 [\[DOM\]](#biblio-dom "DOM Standard")

- The progress event `e` is NOT cancelable. `e.cancelable` must be false
 [\[DOM\]](#biblio-dom "DOM Standard")

#### 6.4.1. Event Summary

The following are the events that are
[fired](https://dom.spec.whatwg.org/#concept-event-fire) at
[`FileReader`](#dfn-filereader) objects.

Event name

Interface

Fired when...

[`loadstart`]

[`ProgressEvent`](https://xhr.spec.whatwg.org/#progressevent)

When the read starts.

[`progress`]

[`ProgressEvent`](https://xhr.spec.whatwg.org/#progressevent)

While reading (and decoding) `blob`

[`abort`]

[`ProgressEvent`](https://xhr.spec.whatwg.org/#progressevent)

When the read has been aborted. For instance, by invoking the
[`abort()`](#dfn-abort)
method.

[`error`]

[`ProgressEvent`](https://xhr.spec.whatwg.org/#progressevent)

When the read has failed (see [file read
errors](#file-error-read)).

[`load`]

[`ProgressEvent`](https://xhr.spec.whatwg.org/#progressevent)

When the read has successfully completed.

[`loadend`]

[`ProgressEvent`](https://xhr.spec.whatwg.org/#progressevent)

When the request has completed (either in success or failure).

#### 6.4.2. Summary of Event Invariants

*This section is informative.*

The following are invariants applicable to [event
firing](https://dom.spec.whatwg.org/#concept-event-fire) for a given asynchronous [read
method](#read-method) in this
specification:

1. Once a
 [`loadstart`](#dfn-loadstart-event) has been fired, a corresponding
 [`loadend`](#dfn-loadend-event) fires at completion of the read, UNLESS any of the
 following are true:

 - the [read method](#read-method) has been cancelled using
 [`abort()`](#dfn-abort)
 and a new [read method](#read-method) has been invoked

 - the event handler function for a
 [`load`](#dfn-load-event) event initiates a new read

 - the event handler function for a [`error`] event
 initiates a new read.

 The events
 [`loadstart`](#dfn-loadstart-event) and
 [`loadend`](#dfn-loadend-event) are not coupled in a one-to-one manner.

 :::
 (#example-4eee468a) This example showcases
 \"read-chaining\": initiating another read from within an event
 handler while the \"first\" read continues processing.
 ```
 // In code of the sort...
 reader.readAsText(file);
 reader.onload = function(){reader.readAsText(alternateFile);}

 .....

 //... the loadend event must not fire for the first read

 reader.readAsText(file);
 reader.abort();
 reader.onabort = function(){reader.readAsText(updatedFile);}

 //... the loadend event must not fire for the first read
 ```
 :::

2. One
 [`progress`](#dfn-progress-event) event will fire when `blob` has been completely
 read into memory.

3. No
 [`progress`](#dfn-progress-event) event fires before
 [`loadstart`](#dfn-loadstart-event).

4. No
 [`progress`](#dfn-progress-event) event fires after any one of
 [`abort`],
 [`load`](#dfn-load-event), and [`error`] have fired. At
 most one of [`abort`],
 [`load`](#dfn-load-event), and [`error`] fire for a given
 read.

5. No [`abort`],
 [`load`](#dfn-load-event), or [`error`] event fires after
 [`loadend`](#dfn-loadend-event).

### 6.5. Reading on Threads

Web Workers allow for the use of synchronous
[`File`](#dfn-file) or
[`Blob`](#dfn-Blob) read
APIs, since such reads on threads do not block the main thread. This
section defines a synchronous API, which can be used within Workers
[\[Workers\]](#biblio-workers "Web Workers").
Workers can avail of both the asynchronous API (the
[`FileReader`](#dfn-filereader) object) *and* the synchronous API (the
[`FileReaderSync`](#dfn-FileReaderSync) object).

#### 6.5.1. The [`FileReaderSync` API]
This interface provides methods to [synchronously
read]
[`File`](#dfn-file) or
[`Blob`](#dfn-Blob) objects
into memory.

```
[Exposed=(DedicatedWorker,SharedWorker)]
interface FileReaderSync {
 constructor();
 // Synchronously return strings

 ArrayBuffer readAsArrayBuffer(Blob blob);
 DOMString readAsBinaryString(Blob blob);
 DOMString readAsText(Blob blob, optional DOMString encoding);
 DOMString readAsDataURL(Blob blob);
};
```

##### 6.5.1.1. Constructors

When the
[`FileReaderSync()`](#dom-filereadersync-filereadersync) constructor is invoked, the user agent must return a
new
[`FileReaderSync`](#dfn-FileReaderSync) object.

##### 6.5.1.2. The [`readAsText()`]
The
[`readAsText(``blob``, ``encoding``)`] method, when
invoked, must run these steps:

1. Let `stream` be the result of calling [get
 stream](#blob-get-stream)
 on `blob`.

2. Let `reader` be the result of [getting a
 reader](https://streams.spec.whatwg.org/#readablestream-get-a-reader) from `stream`.

3. Let `promise` be the result of [reading all
 bytes](https://streams.spec.whatwg.org/#readablestreamdefaultreader-read-all-bytes) from `stream` with `reader`.

4. Wait for `promise` to be fulfilled or rejected.

5. If `promise` fulfilled with a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence) `bytes`:

 1. Return the result of [package
 data](#blob-package-data) given `bytes`, *Text*,
 `blob`'s
 [`type`](#dfn-type),
 and `encoding`.

6. Throw `promise`'s rejection reason.

##### 6.5.1.3. The [`readAsDataURL()` method]
The [`readAsDataURL(``blob``)`] method, when invoked, must run these steps:

1. Let `stream` be the result of calling [get
 stream](#blob-get-stream)
 on `blob`.

2. Let `reader` be the result of [getting a
 reader](https://streams.spec.whatwg.org/#readablestream-get-a-reader) from `stream`.

3. Let `promise` be the result of [reading all
 bytes](https://streams.spec.whatwg.org/#readablestreamdefaultreader-read-all-bytes) from `stream` with `reader`.

4. Wait for `promise` to be fulfilled or rejected.

5. If `promise` fulfilled with a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence) `bytes`:

 1. Return the result of [package
 data](#blob-package-data) given `bytes`, *DataURL*, and
 `blob`'s
 [`type`](#dfn-type).

6. Throw `promise`'s rejection reason.

##### 6.5.1.4. The [`readAsArrayBuffer()` method]
The
[`readAsArrayBuffer(``blob``)`] method, when invoked, must run these steps:

1. Let `stream` be the result of calling [get
 stream](#blob-get-stream)
 on `blob`.

2. Let `reader` be the result of [getting a
 reader](https://streams.spec.whatwg.org/#readablestream-get-a-reader) from `stream`.

3. Let `promise` be the result of [reading all
 bytes](https://streams.spec.whatwg.org/#readablestreamdefaultreader-read-all-bytes) from `stream` with `reader`.

4. Wait for `promise` to be fulfilled or rejected.

5. If `promise` fulfilled with a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence) `bytes`:

 1. Return the result of [package
 data](#blob-package-data) given `bytes`, *ArrayBuffer*, and
 `blob`'s
 [`type`](#dfn-type).

6. Throw `promise`'s rejection reason.

##### 6.5.1.5. The [`readAsBinaryString()` method]
The
[`readAsBinaryString(``blob``)`] method, when invoked, must run these steps:

1. Let `stream` be the result of calling [get
 stream](#blob-get-stream)
 on `blob`.

2. Let `reader` be the result of [getting a
 reader](https://streams.spec.whatwg.org/#readablestream-get-a-reader) from `stream`.

3. Let `promise` be the result of [reading all
 bytes](https://streams.spec.whatwg.org/#readablestreamdefaultreader-read-all-bytes) from `stream` with `reader`.

4. Wait for `promise` to be fulfilled or rejected.

5. If `promise` fulfilled with a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence) `bytes`:

 1. Return the result of [package
 data](#blob-package-data) given `bytes`, *BinaryString*, and
 `blob`'s
 [`type`](#dfn-type).

6. Throw `promise`'s rejection reason.

 The use of
[`readAsArrayBuffer()`](#dfn-readAsArrayBufferSync) is preferred over
[`readAsBinaryString()`](#dfn-readAsBinaryStringSync), which is provided for backwards compatibility.

## 7. Errors and Exceptions

[File read errors] can occur when reading files from the
underlying filesystem. The list below of potential error conditions is
*informative*.

- The [`File`](#dfn-file) or
 [`Blob`](#dfn-Blob) being
 accessed may not exist at the time one of the [asynchronous read
 methods](#asynchronous-read-methods) or [synchronous read
 methods](#read-method-sync) are called. This may be due to it having been moved
 or deleted after a reference to it was acquired (e.g. concurrent
 modification with another application). See
 [`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror).

- A [`File`](#dfn-file) or
 [`Blob`](#dfn-Blob) may be
 unreadable. This may be due to permission problems that occur after a
 reference to a [`File`](#dfn-file) or [`Blob`](#dfn-Blob) has been acquired (e.g. concurrent lock with another
 application). Additionally, the [snapshot
 state](#snapshot-state) may
 have changed. See
 [`NotReadableError`](https://webidl.spec.whatwg.org/#notreadableerror).

- User agents MAY determine that some files are unsafe for use within
 Web applications. A file may change on disk since the original file
 selection, thus resulting in an invalid read. Additionally, some file
 and directory structures may be considered restricted by the
 underlying filesystem; attempts to read from them may be considered a
 security violation. See [§ 9 Security and Privacy
 Considerations](#security-discussion) and
 [`SecurityError`](https://webidl.spec.whatwg.org/#securityerror).

### 7.1. Throwing an Exception or Returning an Error

*This section is normative.*

Error conditions can arise when reading a
[`File`](#dfn-file) or a
[`Blob`](#dfn-Blob).

The [read operation](#readOperation) can terminate due to error conditions when reading a
[`File`](#dfn-file) or a
[`Blob`](#dfn-Blob); the
particular error condition that causes the [get
stream](#blob-get-stream)
algorithm to fail is called a [failure reason]. A [failure
reason](#failureReason) is one
of [NotFound](#NotFoundFR),
[UnsafeFile](#UnsafeFileFR),
[TooManyReads](#TooManyReadsFR),
[SnapshotState](#SnapshotStateFR), or [FileLock](#FileLockFR).

Synchronous read methods
[throw](https://webidl.spec.whatwg.org/#dfn-throw) exceptions of the type in the table below if there has
been an error owing to a particular [failure
reason](#failureReason).

Asynchronous read methods use the
[`error`](#dom-filereader-error) attribute of the
[`FileReader`](#dfn-filereader) object, which must return a
[`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) object of the most appropriate type from the table
below if there has been an error owing to a particular [failure
reason](#failureReason), or
otherwise return null.

Type

Description and Failure Reason

[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror)

If the [`File`](#dfn-file) or
[`Blob`](#dfn-Blob) resource
could not be found at the time the read was processed, this is the
[NotFound]
[failure reason](#failureReason).

For asynchronous read methods the
[`error`](#dom-filereader-error) attribute must return a
[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror) exception and synchronous read methods must
[throw](https://webidl.spec.whatwg.org/#dfn-throw) a
[`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror) exception.

[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)

If:

- it is determined that certain files are unsafe for access within a Web
 application, this is the [UnsafeFile] [failure
 reason](#failureReason).

- it is determined that too many read calls are being made on
 [`File`](#dfn-file) or
 [`Blob`](#dfn-Blob)
 resources, this is the [TooManyReads] [failure
 reason](#failureReason).

For asynchronous read methods the
[`error`](#dom-filereader-error) attribute may return a
[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror) exception and synchronous read methods may
[throw](https://webidl.spec.whatwg.org/#dfn-throw) a
[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror) exception.

This is a security error to be used in situations not covered by any
other [failure reason](#failureReason).

[`NotReadableError`](https://webidl.spec.whatwg.org/#notreadableerror)

If:

- the [snapshot state](#snapshot-state) of a [`File`](#dfn-file) or a [`Blob`](#dfn-Blob) does not match the state of the underlying storage,
 this is the [SnapshotState] [failure
 reason](#failureReason).

- the [`File`](#dfn-file) or
 [`Blob`](#dfn-Blob) cannot
 be read, typically due due to permission problems that occur after a
 [snapshot state](#snapshot-state) has been established (e.g. concurrent lock on the
 underlying storage with another application) then this is the
 [FileLock]
 [failure reason](#failureReason).

For asynchronous read methods the
[`error`](#dom-filereader-error) attribute must return a
[`NotReadableError`](https://webidl.spec.whatwg.org/#notreadableerror) exception and synchronous read methods must
[throw](https://webidl.spec.whatwg.org/#dfn-throw) a
[`NotReadableError`](https://webidl.spec.whatwg.org/#notreadableerror) exception.

## 8. A URL for Blob and MediaSource reference

This section defines a
[scheme](https://url.spec.whatwg.org/#concept-url-scheme) for a
[URL](https://url.spec.whatwg.org/#concept-url) used to refer to
[`Blob`](#dfn-Blob) and
[`MediaSource`](http://w3c.github.io/media-source/#mediasource) objects.

### 8.1. Introduction

*This section is informative.*

[Blob (or object) URLs](#blob-url)
are URLs like
`blob:http://example.com/550e8400-e29b-41d4-a716-446655440000`. This
enables integration of [`Blob`](#dfn-Blob)s and
[`MediaSource`](http://w3c.github.io/media-source/#mediasource)s with other APIs that are only designed to be used with
URLs, such as the
[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) element. [Blob URLs](#blob-url) can also be used to navigate to as well as to trigger
downloads of locally generated data.

For this purpose two static methods are exposed on the
[`URL`](https://url.spec.whatwg.org/#url) interface,
[`createObjectURL(obj)`](#dfn-createObjectURL) and
[`revokeObjectURL(url)`](#dfn-revokeObjectURL). The first method creates a mapping from a
[URL](https://url.spec.whatwg.org/#concept-url) to a [`Blob`](#dfn-Blob), and the second method revokes said mapping. As long as
the mapping exist the [`Blob`](#dfn-Blob) can't be garbage collected, so some care must be taken
to revoke the URL as soon as the reference is no longer needed. All URLs
are revoked when the global that created the URL itself goes away.

### 8.2. Model

Each user agent must maintain a [blob URL store]. A [blob URL
store](#BlobURLStore) is a
[map](https://infra.spec.whatwg.org/#ordered-map) where
[keys](https://infra.spec.whatwg.org/#map-getting-the-keys) are [valid URL
strings](https://url.spec.whatwg.org/#valid-url-string) and
[values](https://infra.spec.whatwg.org/#map-getting-the-values) are [blob URL
Entries](#blob-url-entry).

A [blob URL entry] consists of an [object] (of
type [`Blob`](#dfn-Blob) or
[`MediaSource`](http://w3c.github.io/media-source/#mediasource)), and an [environment] (an
[environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)).

 Specifications have to use the [obtain a blob
object](#blob-url-obtain-object) algorithm to access a [blob URL
entry](#blob-url-entry)'s
[object](#blob-url-entry-object).

[Keys](https://infra.spec.whatwg.org/#map-getting-the-keys) in the [blob URL
store](#BlobURLStore) (also
known as [blob URLs]) are [valid URL
strings](https://url.spec.whatwg.org/#valid-url-string) that when
[parsed](https://url.spec.whatwg.org/#concept-url-parser) result in a
[URL](https://url.spec.whatwg.org/#concept-url) with a
[scheme](https://url.spec.whatwg.org/#concept-url-scheme) equal to \"`blob`\", an [empty
host](https://url.spec.whatwg.org/#empty-host), and a
[path](https://url.spec.whatwg.org/#concept-url-path) consisting of one element itself also a [valid URL
string](https://url.spec.whatwg.org/#valid-url-string).

To [obtain a blob object] given a [blob URL
entry](#blob-url-entry)
`blobUrlEntry` and an
[environment](https://html.spec.whatwg.org/multipage/webappapis.html#environment), \"`top-level-navigation`\", or
\"`top-level-self-fetch`\" `environment`, perform the
following steps. They return an
[object](#blob-url-entry-object).

1. Let `isAuthorized` be true.

2. If `environment` is an
 [environment](https://html.spec.whatwg.org/multipage/webappapis.html#environment), then set `isAuthorized` to the result
 of [checking for same-partition blob URL
 usage](#check-for-same-partition-blob-url-usage) with `blobUrlEntry` and
 `environment`.

3. If `isAuthorized` is false, then return failure.

4. Return `blobUrlEntry`'s
 [object](#blob-url-entry-object).

To [ generate a new blob URL], run the following steps:

1. Let `result` be the empty string.

2. Append the string \"`blob:`\" to `result`.

3. Let `settings` be the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object)

4. Let `origin` be `settings`'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin).

5. Let `serialized` be the [ASCII
 serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of `origin`.

6. If `serialized` is \"`null`\", set it to an
 implementation-defined value.

7. Append `serialized` to `result`.

8. Append U+0024 SOLIDUS (`/`) to `result`.

9. Generate a UUID
 [\[RFC4122\]](#biblio-rfc4122 "Universally Unique IDentifiers (UUIDs)")
 as a string and append it to `result`.

10. Return `result`.

An example of a blob URL that can be
generated by this algorithm is
`blob:https://example.org/40a5fb5a-d56d-4a33-b4e2-0acf6a8e5f64`.

To [ add an entry to the blob URL store] for a given `object`, run the following steps:

1. Let `store` be the user agent's [blob URL
 store](#BlobURLStore).

2. Let `url` be the result of [generating a new blob
 URL](#unicodeBlobURL).

3. Let `entry` be a new [blob URL
 entry](#blob-url-entry)
 consisting of `object` and the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object).

4. [Set](https://infra.spec.whatwg.org/#map-set) `store`\[`url`\] to
 `entry`.

5. Return `url`.

To [ remove an entry from the blob URL store] for a given `url`, run the following steps:

1. Let `store` be the user agent's [blob URL
 store](#BlobURLStore);

2. Let `url string` be the result of
 [serializing](https://url.spec.whatwg.org/#concept-url-serializer) `url`.

3. [Remove](https://infra.spec.whatwg.org/#map-remove) `store`\[`url string`\].

### 8.3. Dereferencing Model for blob URLs

To [resolve a blob URL] given a
[URL](https://url.spec.whatwg.org/#concept-url) `url`:

1. [Assert](https://infra.spec.whatwg.org/#assert): `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"`blob`\".

2. Let `store` be the user agent's [blob URL
 store](#BlobURLStore).

3. Let `url string` be the result of
 [serializing](https://url.spec.whatwg.org/#concept-url-serializer) `url` with the *exclude fragment flag*
 set.

4. If `store`\[`url string`\]
 [exists](https://infra.spec.whatwg.org/#map-exists), return
 `store`\[`url string`\]; otherwise return
 failure.

Futher requirements for the parsing and fetching model for [blob
URLs](#blob-url) are defined in the
[\[URL\]](#biblio-url "URL Standard") and
[\[Fetch\]](#biblio-fetch "Fetch Standard")
specifications.

#### 8.3.1. Origin of blob URLs

*This section is informative.*

The origin of a blob URL is always the same as that of the environment
that created the URL, as long as the URL hasn't been revoked yet. This
is achieved by the
[\[URL\]](#biblio-url "URL Standard") spec looking
up the URL in the [blob URL store](#BlobURLStore) when parsing a URL, and using that entry to return the
correct origin.

If the URL was revoked the serialization of the origin will still remain
the same as the serialization of the origin of the environment that
created the blob URL, but for opaque origins the origin itself might be
distinct. This difference isn't observable though, since a revoked blob
URL can't be resolved/fetched anymore anyway.

#### 8.3.2. Access restrictions on blob URLs

[Blob URLs](#blob-url) can only be
fetched from environments where the [storage
key](https://storage.spec.whatwg.org/#storage-key) matches that of the environment where the [blob
URL](#blob-url) was created.
Top-level [blob URL](#blob-url)
navigations are not subject to this restriction.

To [check for same-partition blob URL
usage] given a [blob URL
entry](#blob-url-entry)
`blobUrlEntry` and an
[environment](https://html.spec.whatwg.org/multipage/webappapis.html#environment) `environment`, perform the following steps.
They return a boolean.

1. Let `blobStorageKey` be the result of [obtaining a
 storage key for non-storage
 purposes](https://storage.spec.whatwg.org/#obtain-a-storage-key-for-non-storage-purposes) with `blobUrlEntry`'s
 [environment](#blob-url-entry-environment).

2. Let `environmentStorageKey` be the result of [obtaining a
 storage key for non-storage
 purposes](https://storage.spec.whatwg.org/#obtain-a-storage-key-for-non-storage-purposes) with `environment`.

3. If `blobStorageKey` is not
 [equal](https://storage.spec.whatwg.org/#storage-key-equal) to `environmentStorageKey`, then return
 false.

4. Return true.

#### 8.3.3. Lifetime of blob URLs

This specification extends the [unloading document cleanup
steps](https://html.spec.whatwg.org/multipage/document-lifecycle.html#unloading-document-cleanup-steps) with the following steps:

1. Let `environment` be the
 [`Document`](https://dom.spec.whatwg.org/#document)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

2. Let `store` be the user agent's [blob URL
 store](#BlobURLStore);

3. Remove from `store` any entries for which the
 [value](https://infra.spec.whatwg.org/#map-value)'s
 [environment](#blob-url-entry-environment) is equal to `environment`.

This needs a similar hook when a worker
is unloaded.

### 8.4. Creating and Revoking a blob URL

[Blob URLs](#blob-url) are created
and revoked using static methods exposed on the
[`URL`](https://url.spec.whatwg.org/#url) object. Revocation of a [blob
URL](#blob-url) decouples the [blob
URL](#blob-url) from the resource it
refers to, and if it is dereferenced after it is revoked, user agents
must act as if a [network
error](https://fetch.spec.whatwg.org/#concept-network-error) has occurred. This section describes a supplemental
interface to the URL specification
[\[URL\]](#biblio-url "URL Standard") and presents
methods for [blob URL](#blob-url)
creation and revocation.

```
[Exposed=(Window,DedicatedWorker,SharedWorker)]
partial interface URL {
 static DOMString createObjectURL((Blob or MediaSource) obj);
 static undefined revokeObjectURL(DOMString url);
};
```

The [`createObjectURL(``obj``)`] static
method must return the result of [adding an entry to the blob URL
store](#add-an-entry) for
`obj`.

The [`revokeObjectURL(``url``)`] static
method must run these steps:

1. Let `urlRecord` be the result of
 [parsing](https://url.spec.whatwg.org/#concept-url-parser) `url`.

2. If `urlRecord`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is not \"`blob`\", return.

3. Let `entry` be `urlRecord`'s [blob URL
 entry](#blob-url-entry).

4. If `entry` is null, then return.

5. Let `isAuthorized` be the result of [checking for
 same-partition blob URL
 usage](#check-for-same-partition-blob-url-usage) with `entry` and the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object).

6. If `isAuthorized` is false, then return.

7. [Remove an entry from the Blob URL
 Store](#removeTheEntry) for
 `url`.

 This means that rather than throwing some kind of
error, attempting to revoke a URL that isn't registered or that was
registered from an environment in a different storage partition will
silently fail. User agents might display a message on the error console
if this happens.

 Attempts to dereference `url` after it has
been revoked will result in a [network
error](https://fetch.spec.whatwg.org/#concept-network-error). Requests that were started before the `url`
was revoked should still succeed.

In the example below, `window1` and
`window2` are separate, but in the [same
origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin); `window2` could be an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) inside `window1`.

```
myurl = window1.URL.createObjectURL(myblob);
window2.URL.revokeObjectURL(myurl);
```

Since a user agent has one global [blob URL
store](#BlobURLStore), it is
possible to revoke an object URL from a different window than from which
it was created. The
`URL.`[`revokeObjectURL()`](#dfn-revokeObjectURL) call ensures that subsequent dereferencing of `myurl`
results in a the user agent acting as if a [network
error](https://fetch.spec.whatwg.org/#concept-network-error) has occurred.

#### 8.4.1. Examples of blob URL Creation and Revocation

[Blob URL](#blob-url)s are strings
that are used to
[fetch](https://fetch.spec.whatwg.org/#concept-fetch) [`Blob`](#dfn-Blob) objects, and can persist for as long as the `document`
from which they were minted using
`URL.`[`createObjectURL()`](#dfn-createObjectURL)---​see [§ 8.3.3 Lifetime of blob
URLs](#lifeTime).

This section gives sample usage of creation and revocation of [blob
URL](#blob-url)s with explanations.

In the example below, two
[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) elements
[\[HTML\]](#biblio-html "HTML Standard") refer to
the same [blob URL](#blob-url):

```
url = URL.createObjectURL(blob);
img1.src = url;
img2.src = url;
```

In the example below,
`URL.`[`revokeObjectURL()`](#dfn-revokeObjectURL) is explicitly called.

```
var blobURLref = URL.createObjectURL(file);
img1 = new Image();
img2 = new Image();

// Both assignments below work as expected
img1.src = blobURLref;
img2.src = blobURLref;

// ... Following body load
// Check if both images have loaded
if(img1.complete && img2.complete) {
 // Ensure that subsequent refs throw an exception
 URL.revokeObjectURL(blobURLref);
} else {
 msg("Images cannot be previewed!");
 // revoke the string-based reference
 URL.revokeObjectURL(blobURLref);
}
```

The example above allows multiple references to a single [blob
URL](#blob-url), and the web
developer then revokes the [blob URL](#blob-url) string after both image objects have been loaded. While
not restricting number of uses of the [blob
URL](#blob-url) offers more
flexibility, it increases the likelihood of leaks; developers should
pair it with a corresponding call to
`URL.`[`revokeObjectURL()`](#dfn-revokeObjectURL).

## 9. Security and Privacy Considerations

*This section is informative.*

This specification allows web content to read files from the underlying
file system, as well as provides a means for files to be accessed by
unique identifiers, and as such is subject to some security
considerations. This specification also assumes that the primary user
interaction is with the `<input type="file"/>` element of HTML forms
[\[HTML\]](#biblio-html "HTML Standard"), and that
all files that are being read by
[`FileReader`](#dfn-filereader) objects have first been selected by the user. Important
security considerations include preventing malicious file selection
attacks (selection looping), preventing access to system-sensitive
files, and guarding against modifications of files on disk after a
selection has taken place.

Preventing selection looping

: During file selection, a user may be bombarded with the file picker
 associated with `<input type="file"/>` (in a \"must choose\" loop
 that forces selection before the file picker is dismissed) and a
 user agent may prevent file access to any selections by making the
 [`FileList`](#dfn-filelist) object returned be of size 0.

System-sensitive files

: (e.g. files in /usr/bin, password files, and other native operating
 system executables) typically should not be exposed to web content,
 and should not be accessed via [blob
 URLs](#blob-url). User agents
 may
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SecurityError`](https://webidl.spec.whatwg.org/#securityerror) exception for synchronous read methods, or return a
 [`SecurityError`](https://webidl.spec.whatwg.org/#securityerror) exception for asynchronous reads.

This section is provisional; more
security data may supplement this in subsequent drafts.

## 10. Requirements and Use Cases

This section covers what the requirements are for this API, as well as
illustrates some use cases. This version of the API does not satisfy all
use cases; subsequent versions may elect to address these.

- Once a user has given permission, user agents should provide the
 ability to read and parse data directly from a local file
 programmatically.

 :::
 (#example-d8c3c684) A lyrics viewer. User wants to read
 song lyrics from songs in his plist file. User browses for plist file.
 File is opened, read, parsed, and presented to the user as a sortable,
 actionable list within a web application. User can select songs to
 fetch lyrics. User uses the \"browse for file\" dialog.
 :::

- Data should be able to be stored locally so that it is available for
 later use, which is useful for offline data access for web
 applications.

 :::
 (#example-950bb00a) A Calendar App. User's company has a
 calendar. User wants to sync local events to company calendar, marked
 as \"busy\" slots (without leaking personal info). User browses for
 file and selects it. The `text/calendar` file is parsed in the
 browser, allowing the user to merge the files to one calendar view.
 The user wants to then save the file back to his local calendar file
 (using \"Save As\"?). The user can also send the integrated calendar
 file back to the server calendar store asynchronously.
 :::

- User agents should provide the ability to save a local file
 programmatically given an amount of data and a file name.

 While this specification doesn't provide an explicit
 API call to trigger downloads, the HTML5 specification has addressed
 this. The
 [`download`](https://html.spec.whatwg.org/multipage/links.html#attr-hyperlink-download) attribute of the
 [`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) element initiates a download, saving a
 [`File`](#dfn-file) with
 the name specified. The combination of this API and the
 [`download`](https://html.spec.whatwg.org/multipage/links.html#attr-hyperlink-download) attribute on
 [`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) elements allows for the creation of files within
 web applications, and the ability to save them locally.

 :::
 (#example-eb79e741) A Spreadsheet App. User interacts
 with a form, and generates some input. The form then generates a CSV
 (Comma Separated Variables) output for the user to import into a
 spreadsheet, and uses \"Save\...\". The generated output can also be
 directly integrated into a web-based spreadsheet, and uploaded
 asynchronously.
 :::

- User agents should provide a streamlined programmatic ability to send
 data from a file to a remote server that works more efficiently than
 form-based uploads today.

 :::
 (#example-5f8d4bd7) A Video/Photo Upload App. User is
 able to select large files for upload, which can then be
 \"chunk-transfered\" to the server.
 :::

- User agents should provide an API exposed to script that exposes the
 features above. The user is notified by UI anytime interaction with
 the file system takes place, giving the user full ability to cancel or
 abort the transaction. The user is notified of any file selections,
 and can cancel these. No invocations to these APIs occur silently
 without user intervention.

## [ Acknowledgements]
This specification was originally developed by the SVG Working Group.
Many thanks to Mark Baker and Anne van Kesteren for their feedback.

Thanks to Robin Berjon, Jonas Sicking and Vsevolod Shmyroff for editing
the original specification.

Special thanks to Olli Pettay, Nikunj Mehta, Garrett Smith, Aaron
Boodman, Michael Nordman, Jian Li, Dmitry Titov, Ian Hickson, Darin
Fisher, Sam Weinig, Adrian Bateman and Julian Reschke.

Thanks to the W3C WebApps WG, and to participants on the
public-webapps@w3.org listserv
