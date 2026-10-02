
## 1. Introduction

*This section is non-normative.*

Accurately measuring performance characteristics of web applications is
an important aspect of making web applications faster. This
specification defines the necessary [Performance
Timeline](#performance-timeline) primitives that enable web developers to access,
instrument, and retrieve various performance metrics from the full
lifecycle of a web application.

[\[NAVIGATION-TIMING-2\]](#biblio-navigation-timing-2 "Navigation Timing Level 2"),
[\[RESOURCE-TIMING-2\]](#biblio-resource-timing-2 "Resource Timing"),
and
[\[USER-TIMING-2\]](#biblio-user-timing-2 "User Timing Level 2")
are examples of specifications that define timing information related to
the navigation of the document, resources on the page, and developer
scripts, respectively. Together these and other performance interfaces
define performance metrics that describe the [Performance
Timeline](#performance-timeline) of a web application. For example, the following script
shows how a developer can access the [Performance
Timeline](#performance-timeline) to obtain performance metrics related to the navigation
of the document, resources on the page, and developer scripts:

```
<!doctype html>
<html>
<head></head>
<body onload="init()">
 <img id="image0" src="https://www.w3.org/Icons/w3c_main.png" />
 <script>
 function init() {
 // see [[USER-TIMING-2]]
 performance.mark("startWork");
 doWork(); // Some developer code
 performance.mark("endWork");
 measurePerf();
 }
 function measurePerf() {
 performance
 .getEntries()
 .map(entry => JSON.stringify(entry, null, 2))
 .forEach(json => console.log(json));
 }
 </script>
 </body>
</html>
```

Alternatively, the developer can observe the [Performance
Timeline](#performance-timeline) and be notified of new performance metrics and,
optionally, previously buffered performance metrics of specified type,
via the
[`PerformanceObserver`](#performanceobserver) interface.

The
[`PerformanceObserver`](#performanceobserver) interface was added and is designed to address
limitations of the buffer-based approach shown in the first example. By
using the PerformanceObserver interface, the application can:

- Avoid polling the timeline to detect new metrics
- Eliminate costly deduplication logic to identify new metrics
- [Eliminate race conditions with other consumers that may want to
 manipulate the buffer]

[The developer is encouraged to use
[`PerformanceObserver`](#performanceobserver) where possible. Further, new performance API's and
metrics may only be available through the
[`PerformanceObserver`](#performanceobserver) interface.] The observer works by
specifying a callback in the constructor and specifying the performance
entries it's interested in via the
[`observe()`](#dom-performanceobserver-observe) method. The user agent chooses when to execute the
callback, which receives performance entries that have been queued.

[There are special considerations regarding initial page load when using
the
[`PerformanceObserver`](#performanceobserver) interface: a registration must be active to receive
events but the registration script may not be available or may not be
desired in the critical path.] To address this, user agents
buffer some number of events while the page is being constructed, and
these buffered events can be accessed via the
[`buffered`](#dom-performanceobserverinit-buffered) flag when registering the observer. When this flag is
set, the user agent retrieves and dispatches events that it has
buffered, for the specified entry type, and delivers them in the first
callback after the
[`observe()`](#dom-performanceobserver-observe) call occurs.

The number of buffered events is determined by the specification that
defines the metric and buffering is intended to used for first-N events
only; buffering is not unbounded or continuous.

```
<!doctype html>
<html>
<head></head>
<body>
<img id="image0" src="https://www.w3.org/Icons/w3c_main.png" />
<script>
// Know when the entry types we would like to use are not supported.
function detectSupport(entryTypes) {
 for (const entryType of entryTypes) {
 if (!PerformanceObserver.supportedEntryTypes.includes(entryType)) {
 // Indicate to client-side analytics that |entryType| is not supported.
 }
 }
}
detectSupport(["resource", "mark", "measure"]);
const userTimingObserver = new PerformanceObserver(list => {
 list
 .getEntries()
 // Get the values we are interested in
 .map(({ name, entryType, startTime, duration }) => {
 const obj = {
 "Duration": duration,
 "Entry Type": entryType,
 "Name": name,
 "Start Time": startTime,
 };
 return JSON.stringify(obj, null, 2);
 })
 // Display them to the console.
 .forEach(console.log);
 // Disconnect after processing the events.
 userTimingObserver.disconnect();
});
// Subscribe to new events for User-Timing.
userTimingObserver.observe({entryTypes: ["mark", "measure"]});
const resourceObserver = new PerformanceObserver(list => {
 list
 .getEntries()
 // Get the values we are interested in
 .map(({ name, startTime, fetchStart, responseStart, responseEnd }) => {
 const obj = {
 "Name": name,
 "Start Time": startTime,
 "Fetch Start": fetchStart,
 "Response Start": responseStart,
 "Response End": responseEnd,
 };
 return JSON.stringify(obj, null, 2);
 })
 // Display them to the console.
 .forEach(console.log);
 // Disconnect after processing the events.
 resourceObserver.disconnect();
});
// Retrieve buffered events and subscribe to newer events for Resource Timing.
resourceObserver.observe({type: "resource", buffered: true});
</script>
</body>
</html>
```

## [2. ][ [Performance Timeline] ]
Each [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) has:

- a [performance observer task queued
 flag]
- a [list of registered performance observer
 objects] that is initially empty
- a [performance entry buffer map] [ordered
 map](https://infra.spec.whatwg.org/#ordered-map),
 [keyed](https://infra.spec.whatwg.org/#map-key) on a `DOMString`, representing the entry type to
 which the buffer belongs. The [ordered
 map](https://infra.spec.whatwg.org/#ordered-map)'s
 [value](https://infra.spec.whatwg.org/#map-value) is the following tuple:
 - A [performance entry
 buffer] to store
 [`PerformanceEntry`](#performanceentry) objects, that is initially empty.
 - An integer [maxBufferSize], initialized to the
 [registry](https://w3c.github.io/timing-entrytypes-registry/#registry) value for this entry type.
 - A `boolean` [availableFromTimeline], initialized to the
 [registry](https://w3c.github.io/timing-entrytypes-registry/#registry) value for this entry type.
 - An integer [dropped entries count] that is initially 0.
- An integer [last performance entry id] that is initially set to a
 random integer between 100 and 10000.

Each
[`Document`](https://dom.spec.whatwg.org/#document) has:

- A [most recent navigation], which is a
 [`PerformanceEntry`](#performanceentry), initially unset.

In order to get the [relevant performance entry
tuple], given `entryType` and
`globalObject` as input, run the following steps:

1. Let `map` be the [performance entry buffer
 map](#performance-entry-buffer-map) associated with `globalObject`.
2. Return the result of [getting the value of an
 entry](https://infra.spec.whatwg.org/#map-get) from ` map`, given
 `entryType` as the
 [key](https://infra.spec.whatwg.org/#map-key).

### [2.1. ][Extensions to the [`Performance`](https://w3c.github.io/hr-time/#performance) interface]
This extends the
[`Performance`](https://w3c.github.io/hr-time/#performance) interface from
[\[HR-TIME-3\]](#biblio-hr-time-3 "High Resolution Time")
and hosts performance related attributes and methods used to retrieve
the performance metric data from the [Performance
Timeline](#performance-timeline).

```
partial interface Performance {
 PerformanceEntryList getEntries ();
 PerformanceEntryList getEntriesByType (DOMString type);
 PerformanceEntryList getEntriesByName (DOMString name, optional DOMString type);
};
typedef sequence<PerformanceEntry> PerformanceEntryList;
```

The [PerformanceEntryList] represents a sequence of
[`PerformanceEntry`](#performanceentry), providing developers with all the convenience methods
found on JavaScript arrays.

#### 2.1.1. [`getEntries()` method]
Returns a
[`PerformanceEntryList`](#typedefdef-performanceentrylist) object returned by the [filter buffer map by name and
type](#dfn-filter-buffer-map-by-name-and-type) algorithm with `name` and `type`
set to `null`.

#### 2.1.2. [`getEntriesByType()` method]
Returns a
[`PerformanceEntryList`](#typedefdef-performanceentrylist) object returned by [filter buffer map by name and
type](#dfn-filter-buffer-map-by-name-and-type) algorithm with `name` set to `null`, and
`type` set to the method's input `type` parameter.

#### 2.1.3. [`getEntriesByName()` method]
Returns a
[`PerformanceEntryList`](#typedefdef-performanceentrylist) object returned by [filter buffer map by name and
type](#dfn-filter-buffer-map-by-name-and-type) algorithm with `name` set to the method
input `name` parameter, and `type` set to `null` if optional
`entryType` is omitted, or set to the method's input `type` parameter
otherwise.

## 3. The [`PerformanceEntry` interface]
The
[`PerformanceEntry`](#performanceentry) interface hosts the performance data of various
metrics.

```
[Exposed=(Window,Worker)]
interface PerformanceEntry {
 readonly attribute unsigned long long id;
 readonly attribute DOMString name;
 readonly attribute DOMString entryType;
 readonly attribute DOMHighResTimeStamp startTime;
 readonly attribute DOMHighResTimeStamp duration;
 readonly attribute unsigned long long navigationId;
 [Default] object toJSON();
};
```

[`name`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly
: This attribute must return the value it is initialized to. It
 represents an identifier for this
 [`PerformanceEntry`](#performanceentry) object. This identifier does not have to be unique.

[`entryType`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: This attribute must return the value it is initialized to.

 All `entryType` values are defined in the relevant
 [registry](https://w3c.github.io/timing-entrytypes-registry/#registry). Examples include: `"mark"` and `"measure"`
 [\[USER-TIMING-2\]](#biblio-user-timing-2 "User Timing Level 2"),
 `"navigation"`
 [\[NAVIGATION-TIMING-2\]](#biblio-navigation-timing-2 "Navigation Timing Level 2"),
 and `"resource"`
 [\[RESOURCE-TIMING-2\]](#biblio-resource-timing-2 "Resource Timing").

[`startTime`], of type [DOMHighResTimeStamp](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp), readonly
: This attribute must return the value it is initialized to. It
 represents the time value of the first recorded timestamp of this
 performance metric.

[`duration`], of type [DOMHighResTimeStamp](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp), readonly
: The getter steps for the
 [`duration`](#dom-performanceentry-duration) attribute are to return 0 if
 [this](https://webidl.spec.whatwg.org/#this)'s [end time](#end-time) is 0; otherwise
 [this](https://webidl.spec.whatwg.org/#this)'s [end time](#end-time) -
 [this](https://webidl.spec.whatwg.org/#this)'s
 [`startTime`](#dom-performanceentry-starttime).

[`navigationId`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly
: This attribute MUST return the value it is initialized to.

When [toJSON] is called, run
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard")'s
[default toJSON
steps](https://webidl.spec.whatwg.org/#default-tojson-steps).

A
[`PerformanceEntry`](#performanceentry) has a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) [end time], initially 0.

To [initialize a
PerformanceEntry] `entry` given a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) `startTime`, a `DOMString`
`entryType`, a `DOMString` `name`, and an optional
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) `endTime` (default `0`):

1. Assert: `entryType` is defined in the [entry type
 registry](https://w3c.github.io/timing-entrytypes-registry/#registry).
2. Initialize `entry`'s
 [`startTime`](#dom-performanceentry-starttime) to `startTime`.
3. Initialize `entry`'s
 [`entryType`](#dom-performanceentry-entrytype) to `entryType`.
4. Initialize `entry`'s
 [`name`](#dom-performanceentry-name) to `name`.
5. Initialize `entry`'s [end
 time](#end-time) to
 `endTime`.

## 4. The [`PerformanceObserver` interface]
The
[`PerformanceObserver`](#performanceobserver) interface can be used to observe the [Performance
Timeline](#performance-timeline) to be notified of new performance metrics as they are
recorded, and optionally buffered performance metrics.

Each
[`PerformanceObserver`](#performanceobserver) has these associated concepts:

- A
 [`PerformanceObserverCallback`](#callbackdef-performanceobservercallback) [observer callback] set on creation.
- A
 [`PerformanceEntryList`](#typedefdef-performanceentrylist) object called the [observer buffer] that is initially
 empty.
- A `DOMString` [observer type] which is initially `"undefined"`.
- A boolean [requires dropped entries] which is initially set to
 false.

The `PerformanceObserver(callback)` constructor must create a new
[`PerformanceObserver`](#performanceobserver) object with its [observer
callback](#observer-callback) set to `callback` and then return it.

A [registered performance observer] is a
[struct](https://infra.spec.whatwg.org/#struct) consisting of an [observer] member (a
[`PerformanceObserver`](#performanceobserver) object) and an [options
list] member
(a list of
[`PerformanceObserverInit`](#dictdef-performanceobserverinit) dictionaries).

```
callback PerformanceObserverCallback = undefined (PerformanceObserverEntryList entries,
 PerformanceObserver observer,
 optional PerformanceObserverCallbackOptions options = );
[Exposed=(Window,Worker)]
interface PerformanceObserver {
 constructor(PerformanceObserverCallback callback);
 undefined observe (optional PerformanceObserverInit options = );
 undefined disconnect ();
 PerformanceEntryList takeRecords();
 [SameObject] static readonly attribute FrozenArray<DOMString> supportedEntryTypes;
};
```

To keep the performance overhead to minimum the application ought to
only subscribe to event types that it is interested in, and disconnect
the observer once it no longer needs to observe the performance data.
Filtering by name is not supported, as it would implicitly require a
subscription for all event types --- this is possible, but discouraged,
as it will generate a significant volume of events.

### 4.1. [`PerformanceObserverCallbackOptions` dictionary]
```
dictionary PerformanceObserverCallbackOptions {
 unsigned long long droppedEntriesCount;
};
```

[droppedEntriesCount]
: An integer representing the dropped entries count for the entry
 types that the observer is observing when the
 [`PerformanceObserver`](#performanceobserver)'s [requires dropped
 entries](#requires-dropped-entries) is set.

### 4.2. [`observe()` method]
The
[`observe()`](#dom-performanceobserver-observe) method instructs the user agent to register the
observer and must run these steps:

1. Let `relevantGlobal` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).
2. If `options`'s
 [`entryTypes`](#dom-performanceobserverinit-entrytypes) and
 [`type`](#dom-performanceobserverinit-type) members are both omitted, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`"TypeError"`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
3. If `options`'s
 [`entryTypes`](#dom-performanceobserverinit-entrytypes) is present and any other member is also present,
 then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`"TypeError"`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
4. Update or check
 [this](https://webidl.spec.whatwg.org/#this)'s [observer
 type](#observer-type) by
 running these steps:
 1. If [this](https://webidl.spec.whatwg.org/#this)'s [observer
 type](#observer-type)
 is `"undefined"`:
 1. If `options`'s
 [`entryTypes`](#dom-performanceobserverinit-entrytypes) member is present, then set
 [this](https://webidl.spec.whatwg.org/#this)'s [observer
 type](#observer-type) to `"multiple"`.
 2. If `options`'s
 [`type`](#dom-performanceobserverinit-type) member is present, then set
 [this](https://webidl.spec.whatwg.org/#this)'s [observer
 type](#observer-type) to `"single"`.
 2. If [this](https://webidl.spec.whatwg.org/#this)'s [observer
 type](#observer-type)
 is `"single"` and `options`'s
 [`entryTypes`](#dom-performanceobserverinit-entrytypes) member is present, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 [`"InvalidModificationError"`](https://webidl.spec.whatwg.org/#invalidmodificationerror).
 3. If [this](https://webidl.spec.whatwg.org/#this)'s [observer
 type](#observer-type)
 is `"multiple"` and `options`'s
 [`type`](#dom-performanceobserverinit-type) member is present, then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 [`"InvalidModificationError"`](https://webidl.spec.whatwg.org/#invalidmodificationerror).
5. Set [this](https://webidl.spec.whatwg.org/#this)'s [requires dropped
 entries](#requires-dropped-entries) to true.
6. If [this](https://webidl.spec.whatwg.org/#this)'s [observer
 type](#observer-type) is
 `"multiple"`, run the following steps:
 1. Let `entry types` be `options`'s
 [`entryTypes`](#dom-performanceobserverinit-entrytypes) sequence.
 2. Remove all types from `entry types` that are not
 contained in `relevantGlobal`'s [frozen array of
 supported entry
 types](#frozen-array-of-supported-entry-types). The user agent SHOULD notify developers if
 `entry types` is modified. For example, a console
 warning listing removed types might be appropriate.
 3. If the resulting `entry types` sequence is an empty
 sequence, abort these steps. The user agent SHOULD notify
 developers when the steps are aborted to notify that
 registration has been aborted. For example, a console warning
 might be appropriate.
 4. If the [list of registered performance observer
 objects](#list-of-registered-performance-observer-objects) of `relevantGlobal` contains a
 [registered performance
 observer](#registered-performance-observer) whose [observer](#observer) is
 [this](https://webidl.spec.whatwg.org/#this), replace its [options
 list](#options-list) with
 a list containing `options` as its only item.
 5. Otherwise, create and append a [registered performance
 observer](#registered-performance-observer) object to the [list of registered performance
 observer
 objects](#list-of-registered-performance-observer-objects) of `relevantGlobal`, with
 [observer](#observer) set to
 [this](https://webidl.spec.whatwg.org/#this) and [options
 list](#options-list) set
 to a list containing `options` as its only item.
7. Otherwise, run the following steps:
 1. Assert that
 [this](https://webidl.spec.whatwg.org/#this)'s [observer
 type](#observer-type)
 is `"single"`.
 2. If `options`'s
 [`type`](#dom-performanceobserverinit-type) is not contained in the
 `relevantGlobal`'s [frozen array of supported entry
 types](#frozen-array-of-supported-entry-types), abort these steps. The user agent SHOULD
 notify developers when this happens, for instance via a console
 warning.
 3. If the [list of registered performance observer
 objects](#list-of-registered-performance-observer-objects) of `relevantGlobal` contains a
 [registered performance
 observer](#registered-performance-observer) `obs` whose
 [observer](#observer) is
 [this](https://webidl.spec.whatwg.org/#this):
 1. If `obs`'s [options
 list](#options-list)
 contains a
 [`PerformanceObserverInit`](#dictdef-performanceobserverinit) item `currentOptions` whose
 [`type`](#dom-performanceobserverinit-type) is equal to `options`'s
 [`type`](#dom-performanceobserverinit-type), replace `currentOptions` with
 `options` in `obs`'s [options
 list](#options-list).
 2. Otherwise, append `options` to `obs`'s
 [options list](#options-list).
 4. Otherwise, create and append a [registered performance
 observer](#registered-performance-observer) object to the [list of registered performance
 observer
 objects](#list-of-registered-performance-observer-objects) of `relevantGlobal`, with
 [observer](#observer) set to
 [this](https://webidl.spec.whatwg.org/#this) and [options
 list](#options-list) set
 to a list containing `options` as its only item.
 5. If `options`'s
 [`buffered`](#dom-performanceobserverinit-buffered) flag is set:
 1. Let `tuple` be the [relevant performance entry
 tuple](#relevant-performance-entry-tuple) of `options`'s
 [`type`](#dom-performanceobserverinit-type) and `relevantGlobal`.

 2. For each `entry` in `tuple`'s
 [performance entry
 buffer](#performance-entry-buffer):

 1. If [should add
 entry](https://w3c.github.io/timing-entrytypes-registry/#dfn-should-add-entry) with `entry` and
 `options` as parameters returns true,
 [append](https://infra.spec.whatwg.org/#list-append) `entry` to the [observer
 buffer](#observer-buffer).

 3. [Queue the PerformanceObserver
 task](#dfn-queue-the-performanceobserver-task) with `relevantGlobal` as input.

[A
[`PerformanceObserver`](#performanceobserver) object needs to always call
[`observe()`](#dom-performanceobserver-observe) with `options`'s
[`entryTypes`](#dom-performanceobserverinit-entrytypes) set OR always call
[`observe()`](#dom-performanceobserver-observe) with `options`'s
[`type`](#dom-performanceobserverinit-type) set. If one
[`PerformanceObserver`](#performanceobserver) calls
[`observe()`](#dom-performanceobserver-observe) with
[`entryTypes`](#dom-performanceobserverinit-entrytypes) and also calls observe with
[`type`](#dom-performanceobserverinit-type), then an exception is thrown. This is meant to avoid
confusion with how calls would stack. When using
[`entryTypes`](#dom-performanceobserverinit-entrytypes), no other parameters in
[`PerformanceObserverInit`](#dictdef-performanceobserverinit) can be used. In addition, multiple
[`observe()`](#dom-performanceobserver-observe) calls will override for backwards compatibility and
because a single call should suffice in this case. On the other hand,
when using
[`type`](#dom-performanceobserverinit-type), calls will stack because a single call can only
specify one type. Calling
[`observe()`](#dom-performanceobserver-observe) with a repeated
[`type`](#dom-performanceobserverinit-type) will also override.]

#### 4.2.1. [`PerformanceObserverInit` dictionary]
```
dictionary PerformanceObserverInit {
 sequence<DOMString> entryTypes;
 DOMString type;
 boolean buffered;
};
```

[entryTypes]
: A list of entry types to be observed. If present, the list MUST NOT
 be empty and all other members MUST NOT be present. Types not
 recognized by the user agent MUST be ignored.

[type]
: A single entry type to be observed. A type that is not recognized by
 the user agent MUST be ignored. Other members may be present.

[buffered]
: A flag to indicate whether buffered entries should be queued into
 observer's buffer.

#### 4.2.2. [`PerformanceObserverEntryList` interface]
```
[Exposed=(Window,Worker)]
interface PerformanceObserverEntryList {
 PerformanceEntryList getEntries();
 PerformanceEntryList getEntriesByType (DOMString type);
 PerformanceEntryList getEntriesByName (DOMString name, optional DOMString type);
};
```

Each
[`PerformanceObserverEntryList`](#performanceobserverentrylist) object has an associated [entry list], which consists of a
[`PerformanceEntryList`](#typedefdef-performanceentrylist) and is initialized upon construction.

##### 4.2.2.1. [`getEntries()` method]
Returns a
[`PerformanceEntryList`](#typedefdef-performanceentrylist) object returned by [filter buffer by name and
type](#dfn-filter-buffer-by-name-and-type) algorithm with
[this](https://webidl.spec.whatwg.org/#this)'s [entry list](#entry-list), `name` and `type` set to `null`.

##### 4.2.2.2. [`getEntriesByType()` method]
Returns a
[`PerformanceEntryList`](#typedefdef-performanceentrylist) object returned by [filter buffer by name and
type](#dfn-filter-buffer-by-name-and-type) algorithm with
[this](https://webidl.spec.whatwg.org/#this)'s [entry list](#entry-list), `name` set to `null`, and `type`
set to the method's input `type` parameter.

##### 4.2.2.3. [`getEntriesByName()` method]
Returns a
[`PerformanceEntryList`](#typedefdef-performanceentrylist) object returned by [filter buffer by name and
type](#dfn-filter-buffer-by-name-and-type) algorithm with
[this](https://webidl.spec.whatwg.org/#this)'s [entry list](#entry-list), `name` set to the method input `name`
parameter, and `type` set to `null` if optional `entryType`
is omitted, or set to the method's input `type` parameter otherwise.

### 4.3. [`takeRecords()` method]
The
[`takeRecords()`](#dom-performanceobserver-takerecords) method must return a copy of
[this](https://webidl.spec.whatwg.org/#this)'s [observer
buffer](#observer-buffer),
and also empty
[this](https://webidl.spec.whatwg.org/#this)'s [observer
buffer](#observer-buffer).

### 4.4. [`disconnect()` method]
The
[`disconnect()`](#dom-performanceobserver-disconnect) method must do the following:

1. Remove [this](https://webidl.spec.whatwg.org/#this) from the [list of registered performance observer
 objects](#list-of-registered-performance-observer-objects) of [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).
2. Empty [this](https://webidl.spec.whatwg.org/#this)'s [observer
 buffer](#observer-buffer).
3. Empty [this](https://webidl.spec.whatwg.org/#this)'s [options
 list](#options-list).

### 4.5. [`supportedEntryTypes` attribute]
Each [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) has an associated [frozen array of supported entry
types],
which is initialized to the
[FrozenArray](https://webidl.spec.whatwg.org/#es-frozen-array)
[created](https://webidl.spec.whatwg.org/#dfn-create-frozen-array) from
the sequence of strings among the
[registry](https://w3c.github.io/timing-entrytypes-registry/#registry) that are supported for the global object, in
alphabetical order.

When
[`supportedEntryTypes`](#dom-performanceobserver-supportedentrytypes)'s attribute getter is called, run the following steps:

1. Let `globalObject` be the [environment settings object's
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global).
2. Return `globalObject`'s [frozen array of supported entry
 types](#frozen-array-of-supported-entry-types).

This attribute allows web developers to easily know which entry types
are supported by the user agent.

## 5. Processing

### 5.1. Queue a `PerformanceEntry`

To [queue a PerformanceEntry] (`newEntry`), run
these steps:

1. If `newEntry`'s
 [`id`](#dom-performanceentry-id) is unset:
 1. Let `id` be the result of running [generate an
 id](#generate-an-id)
 for `newEntry`.
 2. Set `newEntry`'s
 [`id`](#dom-performanceentry-id) to `id`.
2. Let `interested observers` be an initially empty set of
 [`PerformanceObserver`](#performanceobserver) objects.
3. Let `entryType` be `newEntry`'s
 [`entryType`](#dom-performanceentry-entrytype) value.
4. Let `relevantGlobal` be `newEntry`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).
5. If `relevantGlobal` has an [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window):
 1. Set `newEntry`'s
 [`navigationId`](#dom-performanceentry-navigationid) to the value of `relevantGlobal`'s
 [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s [most recent
 navigation](#most-recent-navigation)'s
 [`id`](#dom-performanceentry-id).
6. Otherwise, set `newEntry`'s
 [`navigationId`](#dom-performanceentry-navigationid) to null.
7. For each [registered performance
 observer](#registered-performance-observer) `regObs` in
 `relevantGlobal`'s [list of registered performance
 observer
 objects](#list-of-registered-performance-observer-objects):
 1. If `regObs`'s [options
 list](#options-list)
 contains a
 [`PerformanceObserverInit`](#dictdef-performanceobserverinit) `options` whose
 [`entryTypes`](#dom-performanceobserverinit-entrytypes) member includes `entryType` or whose
 [`type`](#dom-performanceobserverinit-type) member equals to `entryType`:

 1. If [should add
 entry](https://w3c.github.io/timing-entrytypes-registry/#dfn-should-add-entry) with `newEntry` and
 `options` returns true, append
 `regObs`'s
 [observer](#observer) to
 `interested observers`.
8. For each `observer` in `interested observers`:
 1. Append `newEntry` to `observer`'s
 [observer buffer](#observer-buffer).
9. Let `tuple` be the [relevant performance entry
 tuple](#relevant-performance-entry-tuple) of `entryType` and
 `relevantGlobal`.
10. Let `isBufferFull` be the return value of the [determine
 if a performance entry buffer is
 full](#dfn-determine-if-a-performance-entry-buffer-is-full) algorithm with `tuple` as input.
11. Let `shouldAdd` be the result of [should add
 entry](https://w3c.github.io/timing-entrytypes-registry/#dfn-should-add-entry) with `newEntry` as input.
12. If `isBufferFull` is false and `shouldAdd` is
 true,
 [append](https://infra.spec.whatwg.org/#list-append) `newEntry` to `tuple`'s
 [performance entry
 buffer](#performance-entry-buffer).
13. [Queue the PerformanceObserver
 task](#dfn-queue-the-performanceobserver-task) with `relevantGlobal` as input.

### 5.2. Queue a navigation `PerformanceEntry`

To [queue a navigation
PerformanceEntry] (`newEntry`), run
these steps:

1. Let `id` be the result of running [generate an
 id](#generate-an-id) for
 `newEntry`.
2. Let `relevantGlobal` be `newEntry`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).
3. Set `newEntry`'s
 [`id`](#dom-performanceentry-id) to `id`.
4. Set `newEntry`'s
 [`navigationId`](#dom-performanceentry-navigationid) to `id`.
5. If `relevantGlobal` has an [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window):
 1. Set `relevantGlobal`'s [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s [most recent
 navigation](#most-recent-navigation) to `newEntry`.
6. [Queue a
 PerformanceEntry](#dfn-queue-a-performanceentry) with `newEntry` as input.

### 5.3. Queue the PerformanceObserver task

When asked to [queue the PerformanceObserver
task], given `relevantGlobal` as input,
run the following steps:

1. If `relevantGlobal`'s [performance observer task queued
 flag](#performance-observer-task-queued-flag) is set, terminate these steps.
2. Set `relevantGlobal`'s [performance observer task queued
 flag](#performance-observer-task-queued-flag).
3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) that consists of running the following substeps.
 The [task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source) for the queued task is the [performance timeline
 task source].
 1. Unset [performance observer task queued
 flag](#performance-observer-task-queued-flag) of `relevantGlobal`.
 2. Let `notifyList` be a copy of
 `relevantGlobal`'s [list of registered performance
 observer
 objects](#list-of-registered-performance-observer-objects).
 3. For each [registered performance
 observer](#registered-performance-observer) object `registeredObserver` in
 `notifyList`, run these steps:
 1. Let `po` be `registeredObserver`'s
 [observer](#observer).
 2. Let `entries` be a copy of `po`'s
 [observer
 buffer](#observer-buffer).
 3. If `entries` is empty, return.
 4. Empty `po`'s [observer
 buffer](#observer-buffer).
 5. Let `observerEntryList` be a new
 [`PerformanceObserverEntryList`](#performanceobserverentrylist), with its [entry
 list](#entry-list) set
 to `entries`.
 6. Let `droppedEntriesCount` be null.
 7. If `po`'s [requires dropped
 entries](#requires-dropped-entries) is set, perform the following steps:
 1. Set `droppedEntriesCount` to 0.
 2. For each
 [`PerformanceObserverInit`](#dictdef-performanceobserverinit) `item` in
 `registeredObserver`'s [options
 list](#options-list):
 1. For each
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) `entryType` that appears
 either as `item`'s
 [`type`](#dom-performanceobserverinit-type) or in `item`'s
 [`entryTypes`](#dom-performanceobserverinit-entrytypes):
 1. Let `map` be
 `relevantGlobal`'s [performance entry
 buffer
 map](#performance-entry-buffer-map).
 2. Let `tuple` be the result of [getting
 the value of
 entry](https://infra.spec.whatwg.org/#map-get) on `map` given
 `entryType` as
 [key](https://infra.spec.whatwg.org/#map-key).
 3. Increase `droppedEntriesCount` by
 `tuple`'s [dropped entries
 count](#dropped-entries-count).
 3. Set `po`'s [requires dropped
 entries](#requires-dropped-entries) to false.
 8. Let `callbackOptions` be a
 [`PerformanceObserverCallbackOptions`](#dictdef-performanceobservercallbackoptions) with its
 [`droppedEntriesCount`](#dom-performanceobservercallbackoptions-droppedentriescount) set to `droppedEntriesCount` if
 `droppedEntriesCount` is not null, otherwise
 unset.
 9. [Invoke](https://webidl.spec.whatwg.org/#invoke-a-callback-function)
 `po`'s [observer
 callback](#observer-callback) with « `observerEntryList`,
 `po`, `callbackOptions` »,
 \"\`report\`\", and `po`.

The *performance timeline* [task
queue](https://html.spec.whatwg.org/multipage/webappapis.html#task-source) is a low priority queue that, if possible, should be
processed by the user agent during idle periods to minimize impact of
performance monitoring code.

### 5.4. Filter buffer map by name and type

When asked to run the [filter buffer map by name and
type] algorithm with optional `name`
and `type`, run the following steps:

1. Let `result` be an initially empty
 [list](https://infra.spec.whatwg.org/#list).
2. Let `map` be the [performance entry buffer
 map](#performance-entry-buffer-map) associated with the [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) of
 [this](https://webidl.spec.whatwg.org/#this).
3. Let `tuple list` be an empty
 [list](https://infra.spec.whatwg.org/#list).
4. If `type` is not null, append the result of [getting the
 value of
 entry](https://infra.spec.whatwg.org/#map-get) on `map` given `type` as
 [key](https://infra.spec.whatwg.org/#map-key) to `tuple list`. Otherwise, assign the
 result of [get the
 values](https://infra.spec.whatwg.org/#map-getting-the-values) on `map` to `tuple list`.
5. For each `tuple` in `tuple list`, run the
 following steps:
 1. Let `buffer` be `tuple`'s [performance
 entry
 buffer](#performance-entry-buffer).
 2. If `tuple`'s
 [availableFromTimeline](#availablefromtimeline) is false, continue to the next
 `tuple`.
 3. Let `entries` be the result of running [filter buffer
 by name and
 type](#dfn-filter-buffer-by-name-and-type) with `buffer`, `name` and
 `type` as inputs.
 4. For each `entry` in `entries`,
 [append](https://infra.spec.whatwg.org/#list-append) `entry` to `result`.
6. Sort `results`'s entries in chronological order with
 respect to
 [`startTime`](#dom-performanceentry-starttime)
7. Return `result`.

### 5.5. Filter buffer by name and type

When asked to run the [filter buffer by name and
type] algorithm, with `buffer`,
`name`, and `type` as inputs, run the following
steps:

1. Let `result` be an initially empty
 [list](https://infra.spec.whatwg.org/#list).
2. For each
 [`PerformanceEntry`](#performanceentry) `entry` in `buffer`, run the
 following steps:
 1. If `type` is not null and if `type` is not
 [identical
 to](https://infra.spec.whatwg.org/#string-is) `entry`'s `entryType` attribute,
 continue to next `entry`.
 2. If `name` is not null and if `name` is not
 [identical
 to](https://infra.spec.whatwg.org/#string-is) `entry`'s `name` attribute, continue
 to next `entry`.
 3. [append](https://infra.spec.whatwg.org/#list-append) `entry` to `result`.
3. Sort `results`'s entries in chronological order with
 respect to
 [`startTime`](#dom-performanceentry-starttime)
4. Return `result`.

### 5.6. Determine if a performance entry buffer is full

To [determine if a performance entry buffer is
full], with `tuple` as
input, run the following steps:

1. Let `num current entries` be the size of
 `tuple`'s [performance entry
 buffer](#performance-entry-buffer).
2. If `num current entries` is less than
 `tuple`'s
 [maxBufferSize](#maxbuffersize), return false.
3. Increase `tuple`'s [dropped entries
 count](#dropped-entries-count) by 1.
4. Return true.

### 5.7. Generate a Performance Entry id

When asked to [generate an id] for a
[`PerformanceEntry`](#performanceentry) `entry`, run the following steps:

1. Let `relevantGlobal` be `entry`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).
2. Increase `relevantGlobal`'s [last performance entry
 id](#last-performance-entry-id) by a small number chosen by the user agent.
3. Return `relevantGlobal`'s [last performance entry
 id](#last-performance-entry-id).

A user agent may choose to increase the [last performance entry
id](#last-performance-entry-id) by a small random integer every time. A user agent must
not pick a single global random integer and increase the [last
performance entry
id](#last-performance-entry-id) of all global objects by that amount because this could
introduce cross origin leaks.

The [last performance entry
id](#last-performance-entry-id) has an initial random value, and is increased by a
small number chosen by the user agent instead of 1 to discourage
developers from considering it as a counter of the number of entries
that have been generated in the web application.

## 6. Privacy Considerations

*This section is non-normative.*

This specification extends the
[`Performance`](https://w3c.github.io/hr-time/#performance) interface defined by
[\[HR-TIME-3\]](#biblio-hr-time-3 "High Resolution Time")
and provides methods to queue and retrieve entries from the [performance
timeline](#performance-timeline). [Please refer to
[\[HR-TIME-3\]](#biblio-hr-time-3 "High Resolution Time")
for privacy considerations of exposing high-resoluting timing
information. Each new specification introducing new performance entries
should have its own privacy considerations as well.]

The [last performance entry
id](#last-performance-entry-id) is deliberately initialized to a random value, and is
incremented by another small value every time a new
[`PerformanceEntry`](#performanceentry) is queued. [User agents may choose to use a consistent
increment for all users, or may pick a different increment for each
[global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object), or may choose a new random increment for each
[`PerformanceEntry`](#performanceentry). However, in order to prevent cross-origin leaks, and
ensure that this does not enable fingerprinting, user agents must not
just pick a unique random integer, and use it as a consistent increment
for all
[`PerformanceEntry`](#performanceentry) objects across all [global
objects](https://html.spec.whatwg.org/multipage/webappapis.html#global-object).]

## 7. Security Considerations

*This section is non-normative.*

This specification extends the
[`Performance`](https://w3c.github.io/hr-time/#performance) interface defined by
[\[HR-TIME-3\]](#biblio-hr-time-3 "High Resolution Time")
and provides methods to queue and retrieve entries from the [performance
timeline](#performance-timeline). [Please refer to
[\[HR-TIME-3\]](#biblio-hr-time-3 "High Resolution Time")
for security considerations of exposing high-resoluting timing
information. Each new specification introducing new performance entries
should have its own security considerations as well.]

## [Acknowledgments]
Thanks to Arvind Jain, Boris Zbarsky, Jatinder Mann, Nat Duca, Philippe
Le Hegaret, Ryosuke Niwa, Shubhie Panicker, Todd Reifsteck, Yoav Weiss,
and Zhiheng Wang, for their contributions to this work.
