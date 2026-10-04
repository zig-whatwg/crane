## 1. Introduction

*This section is non-normative.*

Web developers need the ability to assess and understand the performance
characteristics of their applications. While JavaScript
[\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification")
provides a mechanism to measure application latency (retrieving the
current timestamp from the `Date.now()` method), the precision of this
timestamp varies between user agents.

This document defines the
[PerformanceMark](#performancemark-performancemark) and
[PerformanceMeasure](#performancemeasure-performancemeasure) interfaces, and extensions to the
[`Performance`](#extensions-performance-interface) interface, which
expose a high precision, monotonically increasing timestamp so that
developers can better measure the performance characteristics of their
applications.

The following script shows how a developer can use the interfaces
defined in this document to obtain timing data related to developer
scripts.

```
async function run() {
 performance.mark("startTask1");
 await doTask1(); // Some developer code
 performance.mark("endTask1");

 performance.mark("startTask2");
 await doTask2(); // Some developer code
 performance.mark("endTask2");

 // Log them out
 const entries = performance.getEntriesByType("mark");
 for (const entry of entries) {
 console.table(entry.toJSON());
 }
}
run();
```

[\[PERFORMANCE-TIMELINE-2\]](#biblio-performance-timeline-2 "Performance Timeline")
defines two mechanisms that can be used to retrieve recorded metrics:
`getEntries()` and `getEntriesByType()` methods, and the
`PerformanceObserver` interface. The former is best suited for cases
where you want to retrieve a particular metric by name at a single point
in time, and the latter is optimized for cases where you
[may] want to receive notifications of new metrics as they
become available.

As another example, suppose that there is an element which, when
clicked, fetches some new content and indicates that it has been
fetched. We'd like to report the time from when the user clicked to when
the fetch was complete. We can't mark the time the click handler
executes since that will miss latency to process the event, so instead
we use the event hardware timestamp. We also want to know the name of
the component to have more detailed analytics.

```
element.addEventListener("click", e => {
 const component = getComponent(element);
 fetch(component.url).then(() => {
 element.textContent = "Updated";
 const updateMark = performance.mark("update_component", {
 detail: {component: component.name},
 });
 performance.measure("click_to_update_component", {
 detail: {component: component.name},
 start: e.timeStamp,
 end: updateMark.startTime,
 });
 });
});
```

## 2. User Timing

### [2.1. ][Extensions to the [`Performance`](https://w3c.github.io/hr-time/#the-performance-attr) interface]
The
[Performance](https://w3c.github.io/hr-time/#the-performance-attr) interface and
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) are defined in
[\[HR-TIME-2\]](#biblio-hr-time-2 "High Resolution Time Level 2").
The
[`PerformanceEntry`](https://w3c.github.io/performance-timeline/#performanceentry) interface is defined in
[\[PERFORMANCE-TIMELINE-2\]](#biblio-performance-timeline-2 "Performance Timeline").

```
dictionary PerformanceMarkOptions {
 any detail;
 DOMHighResTimeStamp startTime;
};

dictionary PerformanceMeasureOptions {
 any detail;
 (DOMString or DOMHighResTimeStamp) start;
 DOMHighResTimeStamp duration;
 (DOMString or DOMHighResTimeStamp) end;
};

partial interface Performance {
 PerformanceMark mark(DOMString markName, optional PerformanceMarkOptions markOptions = );
 undefined clearMarks(optional DOMString markName);
 PerformanceMeasure measure(DOMString measureName, optional (DOMString or PerformanceMeasureOptions) startOrMeasureOptions = , optional DOMString endMark);
 undefined clearMeasures(optional DOMString measureName);
};
```

#### [2.1.1. ][[mark()] method]
Stores a timestamp with the associated name (a \"mark\"). It MUST run
these steps:

1. Run the [PerformanceMark
 constructor](#dom-performancemark-constructor) and let `entry` be the newly created
 object.
2. [Queue a
 PerformanceEntry](https://www.w3.org/TR/performance-timeline/#dfn-queue-a-performanceentry) `entry`.
3. [(#stored_mark)Add `entry` to the
 [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer).]
4. Return `entry`.

##### [2.1.1.1. ][[PerformanceMarkOptions] dictionary]
[detail]
: Metadata to be included in the mark.

[startTime]
: Timestamp to be used as the mark time.

#### [2.1.2. ][[clearMarks()] method]
Removes the stored timestamp with the associated name. It MUST run these
steps:

1. If `markName` is omitted, remove all
 [PerformanceMark](#performancemark-performancemark) objects from the [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer).
2. Otherwise, remove all
 [PerformanceMark](#performancemark-performancemark) objects listed in the [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer) whose `name`
 [is](https://infra.spec.whatwg.org/#string-is) `markName`.
3. Return **undefined**.

#### [2.1.3. ][[measure()] method]
Stores the
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) duration between two marks along with the associated
name (a \"measure\"). It MUST run these steps:

1. If `startOrMeasureOptions` is a
 [PerformanceMeasureOptions](#performancemeasureoptions-performancemeasureoptions) object and at least one of
 [start](#performancemeasureoptions-start),
 [end](#performancemeasureoptions-end),
 [duration](#performancemeasureoptions-duration), and
 [detail](#performancemeasureoptions-detail)
 [exist](https://infra.spec.whatwg.org/#map-exists), run the following checks:
 1. If `endMark` is given,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
 2. If `startOrMeasureOptions`'s
 [start](#performancemeasureoptions-start) and
 [end](#performancemeasureoptions-end) members are both omitted,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
 3. If `startOrMeasureOptions`'s
 [start](#performancemeasureoptions-start),
 [duration](#performancemeasureoptions-duration), and
 [end](#performancemeasureoptions-end) members all
 [exist](https://infra.spec.whatwg.org/#map-exists),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
2. Compute `end time` as follows:
 1. If `endMark` is given, let `end time` be
 the value returned by running the [convert a mark to a
 timestamp](#convert-a-mark-to-a-timestamp) algorithm passing in `endMark`.
 2. Otherwise, if `startOrMeasureOptions` is a
 [PerformanceMeasureOptions](#performancemeasureoptions-performancemeasureoptions) object, and if its
 [end](#performancemeasureoptions-end) member
 [exists](https://infra.spec.whatwg.org/#map-exists), let `end time` be the value
 returned by running the [convert a mark to a
 timestamp](#convert-a-mark-to-a-timestamp) algorithm passing in
 `startOrMeasureOptions`'s
 [end](#performancemeasureoptions-end).
 3. Otherwise, if `startOrMeasureOptions` is a
 [PerformanceMeasureOptions](#performancemeasureoptions-performancemeasureoptions) object, and if its
 [start](#performancemeasureoptions-start) and
 [duration](#performancemeasureoptions-duration) members both
 [exist](https://infra.spec.whatwg.org/#map-exists):
 1. Let `start` be the value returned by running the
 [convert a mark to a
 timestamp](#convert-a-mark-to-a-timestamp) algorithm passing in
 [start](#performancemeasureoptions-start).
 2. Let `duration` be the value returned by running
 the [convert a mark to a
 timestamp](#convert-a-mark-to-a-timestamp) algorithm passing in
 [duration](#performancemeasureoptions-duration).
 3. Let `end time` be `start` plus
 `duration`.
 4. Otherwise, let `end time` be the value that would be
 returned by the `Performance` object's
 [`now()`](https://www.w3.org/TR/hr-time-2/#dom-performance-now)
 method.
3. Compute `start time` as follows:
 1. If `startOrMeasureOptions` is a
 [PerformanceMeasureOptions](#performancemeasureoptions-performancemeasureoptions) object, and if its
 [start](#performancemeasureoptions-start) member
 [exists](https://infra.spec.whatwg.org/#map-exists), let `start time` be the value
 returned by running the [convert a mark to a
 timestamp](#convert-a-mark-to-a-timestamp) algorithm passing in
 `startOrMeasureOptions`'s
 [start](#performancemeasureoptions-start).
 2. Otherwise, if `startOrMeasureOptions` is a
 [PerformanceMeasureOptions](#performancemeasureoptions-performancemeasureoptions) object, and if its
 [duration](#performancemeasureoptions-duration) and
 [end](#performancemeasureoptions-end) members both
 [exist](https://infra.spec.whatwg.org/#map-exists):
 1. Let `duration` be the value returned by running
 the [convert a mark to a
 timestamp](#convert-a-mark-to-a-timestamp) algorithm passing in
 [duration](#performancemeasureoptions-duration).
 2. Let `end` be the value returned by running the
 [convert a mark to a
 timestamp](#convert-a-mark-to-a-timestamp) algorithm passing in
 [end](#performancemeasureoptions-end).
 3. Let `start time` be `end` minus
 `duration`.
 3. Otherwise, if `startOrMeasureOptions` is a
 `DOMString`, let `start time` be the value returned
 by running the [convert a mark to a
 timestamp](#convert-a-mark-to-a-timestamp) algorithm passing in
 `startOrMeasureOptions`.
 4. Otherwise, let `start time` be `0`.
4. Create a new
 [PerformanceMeasure](#performancemeasure-performancemeasure) object (`entry`) with
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).
5. Set `entry`'s `name` attribute to
 `measureName`.
6. Set `entry`'s `entryType` attribute to
 `DOMString "measure"`.
7. Set `entry`'s `startTime` attribute to
 `start time`.
8. Set `entry`'s `duration` attribute to the duration from
 `start time` to `end time`. The resulting
 duration value MAY be negative.
9. Set `entry`'s `detail` attribute as follows:
 1. If `startOrMeasureOptions` is a
 [PerformanceMeasureOptions](#performancemeasureoptions-performancemeasureoptions) object and `startOrMeasureOptions`'s
 [detail](#performancemeasureoptions-detail) member
 [exists](https://infra.spec.whatwg.org/#map-exists):
 1. Let `record` be the result of calling the
 [StructuredSerialize](https://html.spec.whatwg.org/multipage/infrastructure.html#structuredserialize) algorithm on
 `startOrMeasureOptions`'s
 [detail](#performancemeasureoptions-detail).
 2. Set `entry`'s
 [detail](#dom-performancemeasure-detail)
 to the result of calling the
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/infrastructure.html#structureddeserialize) algorithm on `record` and the
 [current
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-current-everything).
 2. Otherwise, set it to `null`.
10. [Queue a
 PerformanceEntry](https://www.w3.org/TR/performance-timeline/#dfn-queue-a-performanceentry) `entry`.
11. [(#stored_measure)Add `entry` to the
 [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer).]
12. Return `entry`.

##### [2.1.3.1. ][[PerformanceMeasureOptions] dictionary]
[detail]
: Metadata to be included in the measure.

[start]
: Timestamp to be used as the start time or string to be used as start
 mark.

[duration]
: Duration between the start and end times.

[end]
: Timestamp to be used as the end time or string to be used as end
 mark.

#### [2.1.4. ][[clearMeasures()] method]
Removes stored timestamp with the associated name. It MUST run these
steps:

1. If `measureName` is omitted, remove all
 [PerformanceMeasure](#performancemeasure-performancemeasure) objects in the [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer).
2. Otherwise remove all
 [PerformanceMeasure](#performancemeasure-performancemeasure) objects listed in the [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer) whose `name`
 [is](https://infra.spec.whatwg.org/#string-is) `measureName`.
3. Return **undefined**.

### [2.2. ][The [PerformanceMark] Interface]
The
[PerformanceMark](#performancemark-performancemark) interface also exposes marks created via the
[Performance](https://w3c.github.io/hr-time/#the-performance-attr) interface's
[`mark()`](#dom-performance-mark) method to the [Performance
Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline).

```
[Exposed=(Window,Worker)]
interface PerformanceMark : PerformanceEntry {
 constructor(DOMString markName, optional PerformanceMarkOptions markOptions = );
 readonly attribute any detail;
};
```

The
[PerformanceMark](#performancemark-performancemark) interface extends the following attributes of the
[`PerformanceEntry`](https://w3c.github.io/performance-timeline/#performanceentry) interface:

The `name` attribute must return the mark's name.

The `entryType` attribute must return the
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) `"mark"`.

The `startTime` attribute must return a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) with the mark's time value.

The `duration` attribute must return a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) of value `0`.

The
[PerformanceMark](#performancemark-performancemark) interface contains the following additional attribute:

The [`detail`] attribute must
return the value it is set to (it's copied from the
[PerformanceMarkOptions](#performancemarkoptions-performancemarkoptions) dictionary).

#### 2.2.1. The [[PerformanceMark Constructor]]
The [PerformanceMark
constructor](#dom-performancemark-constructor) must run the following steps:

1. If the [current global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object) is a `Window` object and `markName` uses
 the same name as a [read only
 attribute](https://webidl.spec.whatwg.org/#dfn-read-only) in the
 [`PerformanceTiming`](https://w3c.github.io/navigation-timing/#performancetiming-performancetiming) interface,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).
2. Create a new
 [PerformanceMark](#performancemark-performancemark) object (`entry`) with the [current
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object)'s
 [realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-global-object-realm).
3. Set `entry`'s `name` attribute to `markName`.
4. Set `entry`'s `entryType` attribute to
 `DOMString "mark"`.
5. Set `entry`'s `startTime` attribute as follows:
 1. If `markOptions`'s
 [startTime](#performancemarkoptions-starttime) member
 [exists](https://infra.spec.whatwg.org/#map-exists), then:
 1. If `markOptions`'s
 [startTime](#performancemarkoptions-starttime) is negative, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
 2. Otherwise, set `entry`'s `startTime` to the value
 of `markOptions`'s
 [startTime](#performancemarkoptions-starttime).
 2. Otherwise, set it to the value that would be returned by the
 `Performance` object's
 [`now()`](https://www.w3.org/TR/hr-time-2/#dom-performance-now)
 method.
6. Set `entry`'s `duration` attribute to `0`.
7. If `markOptions`'s
 [detail](#performancemarkoptions-detail) is null, set `entry`'s
 [detail](#dom-performancemark-detail)
 to null.
8. Otherwise:
 1. Let `record` be the result of calling the
 [StructuredSerialize](https://html.spec.whatwg.org/multipage/infrastructure.html#structuredserialize) algorithm on `markOptions`'s
 [detail](#performancemarkoptions-detail).
 2. Set `entry`'s
 [detail](#dom-performancemark-detail)
 to the result of calling the
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/infrastructure.html#structureddeserialize) algorithm on `record` and the
 [current
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-current-everything).

### [2.3. ][The [PerformanceMeasure] Interface]
The
[PerformanceMeasure](#performancemeasure-performancemeasure) interface also exposes measures created via the
[Performance](https://w3c.github.io/hr-time/#the-performance-attr) interface's
[`measure()`](#dom-performance-measure) method to the [Performance
Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline).

```
[Exposed=(Window,Worker)]
interface PerformanceMeasure : PerformanceEntry {
 readonly attribute any detail;
};
```

The
[PerformanceMeasure](#performancemeasure-performancemeasure) interface extends the following attributes of the
[`PerformanceEntry`](https://w3c.github.io/performance-timeline/#performanceentry) interface:

The `name` attribute must return the measure's name.

The `entryType` attribute must return the
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) `"measure"`.

The `startTime` attribute must return a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) with the measure's start mark.

The `duration` attribute must return a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) with the duration of the measure.

The
[PerformanceMeasure](#performancemeasure-performancemeasure) interface contains the following additional attribute:

The [`detail`]
attribute must return the value it is set to (it's copied from the
[PerformanceMeasureOptions](#performancemeasureoptions-performancemeasureoptions) dictionary).

## 3. Processing

A user agent implementing the User Timing API would need to include
`"mark"` and `"measure"` in
[supportedEntryTypes](https://www.w3.org/TR/performance-timeline/#supportedentrytypes-attribute). This allows developers to detect support for User
Timing.

### 3.1. Convert a `mark` to a `timestamp`

To [convert a mark to a timestamp], given a `mark` that
is a `DOMString` or
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) run these steps:

1. If `mark` is a `DOMString` and it has the same name as a
 [read only attribute](https://webidl.spec.whatwg.org/#dfn-read-only)
 in the
 [`PerformanceTiming`](https://w3c.github.io/navigation-timing/#performancetiming-performancetiming) interface, let `end time` be the value
 returned by running the [convert a name to a
 timestamp](#convert-a-name-to-a-timestamp) algorithm with `name` set to the value
 of `mark`.
2. Otherwise, if `mark` is a `DOMString`, let
 `end time` be the value of the `startTime` attribute from
 the most recent occurrence of a
 [PerformanceMark](#performancemark-performancemark) object in the [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer) whose `name`
 [is](https://infra.spec.whatwg.org/#string-is) `mark`. If no matching entry is found,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).
3. Otherwise, if `mark` is a
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp):
 1. If `mark` is negative, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
 2. Otherwise, let `end time` be `mark`.

### 3.2. Convert a `name` to a `timestamp`

To [convert a name to a timestamp] given a `name` that
is a [read only
attribute](https://webidl.spec.whatwg.org/#dfn-read-only) in the
[`PerformanceTiming`](https://w3c.github.io/navigation-timing/#performancetiming-performancetiming) interface, run these steps:

1. If the [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) is not a `Window` object,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
2. If `name` is `navigationStart`, return `0`.
3. Let `startTime` be the value of `navigationStart` in the
 [`PerformanceTiming`](https://w3c.github.io/navigation-timing/#performancetiming-performancetiming) interface.
4. Let `endTime` be the value of `name` in the
 [`PerformanceTiming`](https://w3c.github.io/navigation-timing/#performancetiming-performancetiming) interface.
5. If `endTime` is `0`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror).
6. Return result of subtracting `startTime` from
 `endTime`.

The
[PerformanceTiming](https://w3c.github.io/navigation-timing/#performancetiming-performancetiming) interface was defined in
[\[NAVIGATION-TIMING\]](#biblio-navigation-timing "Navigation Timing")
and is now considered obsolete. The use of names from the
[PerformanceTiming](https://w3c.github.io/navigation-timing/#performancetiming-performancetiming) interface is supported to remain backwards compatible,
but there are no plans to extend this functionality to names in the
[PerformanceNavigationTiming](https://w3c.github.io/navigation-timing/#performancenavigationtiming-performancenavigationtiming) interface defined in
[\[NAVIGATION-TIMING-2\]](#biblio-navigation-timing-2 "Navigation Timing Level 2")
(or other interfaces) in the future.

## 4. Recommended mark names

Developers are encouraged to use the following recommended mark names to
mark common timings. The [user
agent](https://infra.spec.whatwg.org/#user-agent) does not validate that the usage of these names is
appropriate or consistent with its description.

Adding such [recommended] mark names [can]
help performance tools tailor guidance to a site. These mark names
[can] also help real user monitoring providers and user
agents collect web developer signals regarding their application's
performance at scale, and surface this information to developers without
requiring any site-specific work.

\"[mark_fully_loaded]\"
: The time when the page is considered fully loaded as marked by the
 developer in their application.
 :::
 In this example, the page asynchonously initializes a chat widget, a
 searchbox, and a newsfeed upon loading. When finished, the
 \"[mark_fully_loaded](#mark_fully_loaded)\" mark name enables lab tools and analytics
 providers to automatically show the timing.

 ```
 window.addEventListener("load", (event) => {
 Promise.all([
 loadChatWidget(),
 initializeSearchAutocomplete(),
 initializeNewsfeed()]).then(() => {
 performance.mark('mark_fully_loaded');
 });
 });
 ```
 :::

\"[mark_fully_visible]\"
: The time when the page is considered fully visible to an end-user as
 marked by the developer in their application.

\"[mark_interactive]\"
: The time when the page is considered interactive to an end-user as
 marked by the developer in their application.

\"[mark_feature_usage]\"
: Mark the usage of a feature which may impact performance so that
 tooling and analytics can take it into account. The
 [detail](#dom-performancemark-detail)
 metadata can contain any useful information about the feature,
 including:

 [feature]
 : The name of the feature used.

 [framework]
 : If applicable, the underlying framework the feature is intended
 for, such as a JavaScript framework, content management system,
 or e-commerce platform.

 :::
 In this example, the ImageOptimizationComponent for
 FancyJavaScriptFramework is used to size images for optimal
 performance. The code notes this feature's usage so that lab tools
 and analytics can measure whether it helped improve performance.

 ```
 performance.mark('mark_feature_usage', {
 'detail': {
 'feature': 'ImageOptimizationComponent',
 'framework': 'FancyJavaScriptFramework'
 }
 })
 ```
 :::

## 5. Privacy and Security

*This section is non-normative.*

The interfaces defined in this specification expose potentially
sensitive timing information on specific JavaScript activity of a page.
Please refer to
[\[HR-TIME-2\]](#biblio-hr-time-2 "High Resolution Time Level 2")
for privacy and security considerations of exposing high-resolution
timing information.

Because the web platform has been designed with the invariant that any
script included on a page has the same access as any other script
included on the same page, regardless of the origin of either scripts,
the interfaces defined by this specification do not place any
restrictions on recording or retrieval of recorded timing information -
i.e. a user timing mark or measure recorded by any script included on
the page can be read by any other script running on the same page,
regardless of origin.

## [Acknowledgments]
Thanks to James Simonsen, Jason Weber, Nic Jansma, Philippe Le Hegaret,
Karen Anderson, Steve Souders, Sigbjorn Vik, Todd Reifsteck, and Tony
Gentilcore for their contributions to this work.
