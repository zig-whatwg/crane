## 1. Introduction

\[INTRODUCTION GOES HERE\]

### 1.1. Examples

Unstable, Inc. wants to understand
better how often its website is crashing in the wild. It can do this by
delivering the following header to define a default reporting endpoint,
which will direct crash reports there:

 Reporting-Endpoints: defau

## 2. Concepts

### 2.1. Crash

### 2.2. Out-of-Memory

### 2.3. Unresponsive

## 3. Crash Reports

[Crash reports] indicate that the user was unable to continue using the
page because the browser (or one of its processes necessary for the
page) crashed. For security reasons, no details of the crash are
communicated except for a unique identifier (which can be interpreted by
the browser vendor), and optionally the reason for the crash (such as
\"oom\").

[Crash reports](#crash-reports)
are a type of
[report](https://w3c.github.io/reporting/#report).

[Crash reports](#crash-reports)
have the [report
type](https://w3c.github.io/reporting/#report-type) \"crash\".

```
dictionary CrashReportBody : ReportBody {
 DOMString reason;
 DOMString stack;
 boolean is_top_level;
 DocumentVisibilityState visibility_state;
 object crash_report_api;
};
```

A [crash report](#crash-reports)'s
[body](https://w3c.github.io/reporting/#report-body), represented in JavaScript by
[`CrashReportBody`](#dictdef-crashreportbody), contains the following fields:

- [reason]: A more specific
 classification of the type of crash that occured, if known, or omitted
 otherwise. The valid
 [reason](#crashreportbody-reason) strings are shown below.

[Reason](#crashreportbody-reason)

Description

oom

The page ran out of memory.

unresponsive

The page was killed due to being unresponsive.

- [stack]: The string
 representation of the JavaScript call stack at the time of the crash,
 if all of the following are true, or omitted otherwise:

 - The crash
 [reason](#crashreportbody-reason) is \"unresponsive\".

 - The policy value for `include-js-call-stacks-in-crash-reports` in
 the
 [Document](https://dom.spec.whatwg.org/#concept-document) which crashed is `true`.

 - The call stack can be recovered from the crashed document.

 The string representation used for
 [stack](#crashreportbody-stack) is the same as that used by the
 [Error.prototype.stack](https://tc39.es/proposal-error-stacks/#sec-get-error.prototype-stack) property.

- [is_top_level]: A boolean
 representing whether the
 [`Document`](https://dom.spec.whatwg.org/#document) that crashed belonged to a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), or not.

- [visibility_state]: The string
 value \"`visible`\" or \"`hidden`\", matching the
 [`DocumentVisibilityState`](https://html.spec.whatwg.org/multipage/dom.html#documentvisibilitystate) enum that is exposed to the web platform, via
 [`Document`](https://dom.spec.whatwg.org/#document).[`visibilityState`](https://html.spec.whatwg.org/multipage/interaction.html#dom-document-visibilitystate). It represents whether the visual viewport that the
 crashed
 [`Document`](https://dom.spec.whatwg.org/#document) was hosted in was visible at all, or fully occluded.

- [crash_report_api]: A JSON
 dictionary of arbitrary key/value data obtained by deserializing the
 memory buffer in [user
 agent](https://infra.spec.whatwg.org/#user-agent)'s [crash report
 buffers](#user-agent-crash-report-buffers) map, identified by a crashing
 [`Document`](https://dom.spec.whatwg.org/#document)'s
 [`CrashReportContext`](#crashreportcontext)'s [backing buffer
 ID](#crashreportcontext-backing-buffer-id) member. This buffer is deserialized as a
 JSON-formatted string, and its keys and values are appended to this
 [`any`](https://webidl.spec.whatwg.org/#idl-any) object member of the
 [`CrashReportBody`](#dictdef-crashreportbody).

 Crash reports are not observable to JavaScript, as the
page which would receive them is, by definition, not able to. The IDL
description of CrashReportBody exists in this spec to provide a
JSON-seriaizable interface whose serialization can be embedded in the
out-of-band reports.

### 3.1. [Crash Reports Delivery Priority]
If a `crash-reporting`
[endpoint](https://w3c.github.io/reporting/#endpoint) is specified, [crash
reports](#crash-reports) are
delivered to it.

Otherwise, if a `default`
[endpoint](https://w3c.github.io/reporting/#endpoint) is specified, [crash
reports](#crash-reports) are
delivered to it.

If neither
[endpoint](https://w3c.github.io/reporting/#endpoint) is specified, [crash
reports](#crash-reports) are
not delivered.

Reporting-Endpoints: crash-reporting="https://example.com/reports"

## 4. The [`CrashReportContext` interface]
```
partial interface Window {
 readonly attribute CrashReportContext crashReport;
};
```

Each
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object has an associated
[crashReport], which is a
[`CrashReportContext`](#crashreportcontext) instance created alongside the
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window).

The [`crashReport`] getter steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), then return null.

2. Return [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s
 [crashReport](#window-crashreport) object.

```
[Exposed=Window]
interface CrashReportContext {
 Promise<undefined> initialize(unsigned long long length);
 undefined set(DOMString key, DOMString value);
 undefined delete(DOMString key);
};
```

Each
[`CrashReportContext`](#crashreportcontext) object has an associated [internal
map], which is a
[map](https://infra.spec.whatwg.org/#ordered-map) whose
[keys](https://infra.spec.whatwg.org/#map-getting-the-keys) and
[values](https://infra.spec.whatwg.org/#map-getting-the-values) are both
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)s.

The [user
agent](https://infra.spec.whatwg.org/#user-agent) has an associated [crash report
buffers], which is a
[map](https://infra.spec.whatwg.org/#ordered-map) whose
[keys](https://infra.spec.whatwg.org/#map-getting-the-keys) are [unique internal
values](https://html.spec.whatwg.org/C#unique-internal-value) and whose
[values](https://infra.spec.whatwg.org/#map-getting-the-values) are
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) values.

 The [internal
map](#crashreportcontext-internal-map) is a map-representation of the data that will
eventually appear in a crash report, and it exists to ergonomically
interact with this data via
[map](https://infra.spec.whatwg.org/#ordered-map) semantics. But implementations of this specification,
especially those supporting site isolation, will likely ultimately
serialize its entire contents to a backing shared memory buffer tracked
by the [user
agent](https://infra.spec.whatwg.org/#user-agent)'s [crash report
buffers](#user-agent-crash-report-buffers) map. The
[values](https://infra.spec.whatwg.org/#map-getting-the-values) of that map are expected to be those memory buffers
that span the web process and whatever OS process is responsible for
sending crash reports when a web process crashes, and its [internal
map](#crashreportcontext-internal-map) is no longer available to read from.

Each
[`CrashReportContext`](#crashreportcontext) object has an associated [backing buffer
ID], which is a null-or-[unique internal
value](https://html.spec.whatwg.org/C#unique-internal-value); it is initially null.

Each
[`CrashReportContext`](#crashreportcontext) object has an associated [is buffer
initialized]
[boolean](https://infra.spec.whatwg.org/#boolean), which is initially false.

 This member is asynchronously set to true when the
backing memory buffer associated with
[this](https://webidl.spec.whatwg.org/#this)'s [backing buffer
ID](#crashreportcontext-backing-buffer-id) is initialized.

Each
[`CrashReportContext`](#crashreportcontext) object has an associated
[`unsigned long long`](https://webidl.spec.whatwg.org/#idl-unsigned-long-long) [buffer length],
which is initially 0.

 This gets assigned once in
[`initialize()`](#dom-crashreportcontext-initialize), and tracks the maximum number of bytes that any call
to
[`set()`](#dom-crashreportcontext-set) can write to the memory backing [internal
map](#crashreportcontext-internal-map).

The [internal
map](#crashreportcontext-internal-map) is used to hold all keys/values that will be supplied
to the developer via
[`CrashReportBody`](#dictdef-crashreportbody)s. In browsers with site isolation, the physical process
that writes to this data is different from the one that reads from it
and sends the [crash reports](#crash-reports). Therefore, it is expected that implementations
maintain this map as a shared memory buffer spanning the two processes.
This is what the Chromium implementation of this API does.

[`initialize(``length``)`] method steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [new](https://webidl.spec.whatwg.org/#new)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 This will be surfaced to the user via a rejected
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise).

2. If [this](https://webidl.spec.whatwg.org/#this)'s [backing buffer
 ID](#crashreportcontext-backing-buffer-id) is non-null, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [new](https://webidl.spec.whatwg.org/#new)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. If `length` is \> than 5 \* 1024 \* 1024, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [new](https://webidl.spec.whatwg.org/#new)
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 The limit for the crash report memory buffer is 5
 megabytes.

4. Set [this](https://webidl.spec.whatwg.org/#this)'s [buffer
 length](#crashreportcontext-buffer-length) to `length`.

5. Set [this](https://webidl.spec.whatwg.org/#this)'s [backing buffer
 ID](#crashreportcontext-backing-buffer-id) to the result of [creating a new unique internal
 value](https://html.spec.whatwg.org/C#new-unique-internal-value).

6. Let `cachedThis` be
 [this](https://webidl.spec.whatwg.org/#this).

7. Let `promise` be a [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

8. Run these steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `backing buffer ID` be `cachedThis`'s
 [backing buffer
 ID](#crashreportcontext-backing-buffer-id).

 2. Run
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) steps to create and initialize a backing memory
 store of `length` bytes.

 3. If such a buffer was created, then:

 1. Set the [user
 agent](https://infra.spec.whatwg.org/#user-agent)'s [crash report
 buffers](#user-agent-crash-report-buffers)\[`backing buffer ID`\] to the
 buffer.

 2. Set `cachedThis`'s [is buffer
 initialized](#crashreportcontext-is-buffer-initialized) to true.

 4. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [DOM manipulation task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#dom-manipulation-task-source) given `cachedThis`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global), to
 [resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined).

9. Return `promise`.

[`set(``key``, ``value``)`] method steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [new](https://webidl.spec.whatwg.org/#new)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. If [this](https://webidl.spec.whatwg.org/#this)'s [is buffer
 initialized](#crashreportcontext-is-buffer-initialized) is false, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [new](https://webidl.spec.whatwg.org/#new)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 This will be false both before
 [`initialize()`](#dom-crashreportcontext-initialize) is called, and *after* it is called but before its
 returned
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) resolves. It ensures that
 [`set()`](#dom-crashreportcontext-set) only works when the backing buffer identified by
 the [backing buffer
 ID](#crashreportcontext-backing-buffer-id) is fully initialized.

3. [Set](https://infra.spec.whatwg.org/#map-set)
 [this](https://webidl.spec.whatwg.org/#this)'s [internal
 map](#crashreportcontext-internal-map)\[`key`\] to `value`.

4. Let `serialization` be the result of [serializing a
 JavaScript value to JSON
 bytes](https://infra.spec.whatwg.org/#serialize-a-javascript-value-to-json-bytes), given
 [this](https://webidl.spec.whatwg.org/#this)'s [internal
 map](#crashreportcontext-internal-map).

5. If `serialization`'s
 [size](https://infra.spec.whatwg.org/#list-size) is \>
 [this](https://webidl.spec.whatwg.org/#this)'s [buffer
 length](#crashreportcontext-buffer-length), then:

 1. [Remove](https://infra.spec.whatwg.org/#map-remove)
 [this](https://webidl.spec.whatwg.org/#this)'s [internal
 map](#crashreportcontext-internal-map)\[`key`\].

 2. [Throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [new](https://webidl.spec.whatwg.org/#new)
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. Let `backing buffer ID` be
 [this](https://webidl.spec.whatwg.org/#this)'s [backing buffer
 ID](#crashreportcontext-backing-buffer-id).

7. Write `serialization` to the [user
 agent](https://infra.spec.whatwg.org/#user-agent)'s [crash report
 buffers](#user-agent-crash-report-buffers)\[`backing buffer ID`\].

The [`delete(``key``)`] method steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [new](https://webidl.spec.whatwg.org/#new)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. If [this](https://webidl.spec.whatwg.org/#this)'s [is buffer
 initialized](#crashreportcontext-is-buffer-initialized) is false, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [new](https://webidl.spec.whatwg.org/#new)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. [Remove](https://infra.spec.whatwg.org/#map-remove)
 [this](https://webidl.spec.whatwg.org/#this)'s [internal
 map](#crashreportcontext-internal-map)\[`key`\].

4. Let `serialization` be the result of [serializing a
 JavaScript value to JSON
 bytes](https://infra.spec.whatwg.org/#serialize-a-javascript-value-to-json-bytes), given
 [this](https://webidl.spec.whatwg.org/#this)'s [internal
 map](#crashreportcontext-internal-map).

5. Let `backing buffer ID` be
 [this](https://webidl.spec.whatwg.org/#this)'s [backing buffer
 ID](#crashreportcontext-backing-buffer-id).

6. Write `serialization` to the [user
 agent](https://infra.spec.whatwg.org/#user-agent)'s [crash report
 buffers](#user-agent-crash-report-buffers)\[`backing buffer ID`\].

## 5. Document Policy Integration

Site authors may opt in to recording the JavaScript call stack with some
reports.

This spec defines a [configuration
point](https://wicg.github.io/document-policy/#configuration-point) with the name
`include-js-call-stacks-in-crash-reports`. Its type is boolean, and its
default value is `false`. When configured as `true` in a
[Document](https://dom.spec.whatwg.org/#concept-document) for which crash reporting is enabled, this will cause a
string representation of the JavaScript call stack, at the time of the
crash, to be included in a crash report.

``` http
Document-Policy: include-js-call-stacks-in-crash-reports
```

## 6. Implementation Considerations

### 6.1. Delivery

[\[REPORTING\]](#biblio-reporting "Reporting API"),
which defines the framework on which this specification depends,
provides at most a best-efforts delivery mechanism. This is especially
true when it comes to reporting crashes. There are probably always going
to be certain crash conditions which simply cannot be reported on (for
instance, if the crash occurs within the crash-monitoring code of the
user agent, or if the computer hosting the user agent were to suddenly
cease to exist). However, many crashes *can* be observed by modern
browsers, and their immediate causes can be deduced.

A user agent implementing crash reports SHOULD attempt to monitor
documents for crashes in a way that will continue to function even when
the process which is responsible for that document crashes, or is
terminated by the operating system.

There are multiple ways to implement such a monitor, with varying levels
of reliability and robustness to specific crash causes, and this
specification does not attempt to prescribe any particular such method.

## 7. Sample Reports

POST /reports HTTP/1.1
 Host: example.com
 ...
 Content-Type: application/reports+json

 [{
 "type": "crash",
 "age": 42,
 "url": "https://example.com/",
 "user_agent": "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0",
 "body": {
 "reason": "oom"
 }
 }]

## 8. Security Considerations

For a discussion of security considerations surrounding out-of-band
reporting in general, see [Reporting API § 8 Security
Considerations](https://w3c.github.io/reporting/#security).

The remainder of this section discusses security considerations for
crash reporting specifically.

## 9. Privacy Considerations

For a discussion of privacy considerations surrounding out-of-band
reporting in general, see [Reporting API § 9 Privacy
Considerations](https://w3c.github.io/reporting/#privacy).

The remainder of this section discusses privacy considerations for crash
reporting specifically.

### 9.1. Cross-Process Contamination
