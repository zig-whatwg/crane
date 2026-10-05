## 1. Introduction

*This section is non-normative.*

Accurately measuring performance characteristics of web applications is
an important aspect of making web applications faster. While
JavaScript-based mechanisms, such as the one described in
[\[JSMEASURE\]](#biblio-jsmeasure "Measuring Client-Perceived Response Times on the WWW"),
can provide comprehensive instrumentation for user latency measurements
within an application, in many cases, they are unable to provide a
complete or detailed end-to-end latency picture. For example, the
following JavaScript shows a naive attempt to measure the time it takes
to fully load a page:

```
<html>
<head>
<script type="text/javascript">
var start = new Date().getTime();
function onLoad() {
 var now = new Date().getTime();
 var latency = now - start;
 alert("page loading time: " + latency);
}
</script>
</head>
<body onload="onLoad()">
<!- Main page body goes from here. -->
</body>
</html>
```

The above script calculates the time it takes to load the page **after**
the first bit of JavaScript in the head is executed, but it does not
give any information about the time it takes to get the page from the
server, or the initialization lifecycle of the page.

This specification defines the
[`PerformanceNavigationTiming`](#performancenavigationtiming) interface which participates in the
[\[PERFORMANCE-TIMELINE-2\]](#biblio-performance-timeline-2 "Performance Timeline")
to store and retrieve high resolution performance metric data related to
the navigation of a document. As the
[`PerformanceNavigationTiming`](#performancenavigationtiming) interface uses
[\[HR-TIME\]](#biblio-hr-time "High Resolution Time"),
all time values are measured with respect to the [time
origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-time-origin) of the entry's [relevant settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

For example, if we know that the response end occurs 100ms after the
start of navigation, the
[`PerformanceNavigationTiming`](#performancenavigationtiming) data could look like so:

```
startTime: 0.000 // start time of the navigation request
responseEnd: 100.000 // high resolution time of last received byte
```

The following script shows how a developer can use the
[`PerformanceNavigationTiming`](#performancenavigationtiming) interface to obtain accurate timing data related to the
navigation of the document:

```
<script>
function showNavigationDetails() {
 // Get the first entry
 const [entry] = performance.getEntriesByType("navigation");
 // Show it in a nice table in the developer console
 console.table(entry.toJSON());
}
</script>
<body onload="showNavigationDetails()">
```

## 2. Terminology

The construction \"a `Foo` object\", where `Foo` is actually an
interface, is sometimes used instead of the more accurate \"an object
implementing the interface `Foo`\".

The term [current document] refers to the document associated with the
[Window object's newest Document
object](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

Throughout this work, all time values are measured in milliseconds since
the start of navigation of the document. For example, the start of
navigation of the document occurs at time 0. The term *current time*
refers to the number of milliseconds since the start of navigation of
the document until the current moment in time. This definition of time
is based on
[\[HR-TIME\]](#biblio-hr-time "High Resolution Time")
specification.

## 3. Navigation Timing

### [3.1. ][Relation to the [`PerformanceEntry`](https://w3c.github.io/performance-timeline/#performanceentry) interface]
[`PerformanceNavigationTiming`](#performancenavigationtiming) interface extends the following attributes of
[`PerformanceEntry`](https://w3c.github.io/performance-timeline/#performanceentry) interface:

- The `entryType` getter step is to return the
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) \"`navigation`\".
- The
 [`startTime`](https://w3c.github.io/performance-timeline/#dom-performanceentry-starttime) getter step is to return a
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) with a time value of 0.
- The
 [`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration) getter step is to return a
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) equal to the difference between
 [`loadEventEnd`](#dom-performancenavigationtiming-loadeventend) and
 [this](https://webidl.spec.whatwg.org/#this)'s
 [`startTime`](https://w3c.github.io/performance-timeline/#dom-performanceentry-starttime).

A user agent implementing
[`PerformanceNavigationTiming`](#performancenavigationtiming) would need to include `"navigation"` in
[`supportedEntryTypes`](https://www.w3.org/TR/performance-timeline/#supportedentrytypes-attribute) for
[Window](https://html.spec.whatwg.org/multipage/window-object.html#window) contexts. This allows developers to detect support for
Navigation Timing.

### 3.2. Relation to the `PerformanceResourceTiming` interface

[`PerformanceNavigationTiming`](#performancenavigationtiming) interface extends the following attributes of the
[`PerformanceResourceTiming`](https://w3c.github.io/resource-timing/#performanceresourcetiming) interface:

- The
 [`redirectStart`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-redirectstart) getter steps are to perform the following steps:
 1. If `this`'s [redirect
 count](#performancenavigationtiming-redirect-count) is 0, return 0.
 2. Otherwise return `this`'s
 [`redirectStart`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-redirectstart).

- The
 [`redirectEnd`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-redirectend) getter steps are to perform the following steps:

 1. If `this`'s [redirect
 count](#performancenavigationtiming-redirect-count) is 0, return 0.
 2. Otherwise return `this`'s
 [`redirectEnd`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-redirectend).

 Though \`redirectStart\` and \`redirectEnd\` are exposed in
 [`PerformanceResourceTiming`](https://w3c.github.io/resource-timing/#performanceresourcetiming), they have a different meaning in Navigation Timing,
 where they return zero for navigations with cross-origin redirects.

- The
 [`workerStart`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-workerstart) getter steps are to perform the following steps:

 1. Let `workerTiming` be `this`'s [service
 worker
 timing](#performancenavigationtiming-service-worker-timing).
 2. If `workerTiming` is null, then return
 `this`'s prototype's \`workerStart\`.
 3. Return `workerTiming`'s [start
 time](https://w3c.github.io/ServiceWorker/#service-worker-timing-info-start-time).

 Though \`workerStart\` is exposed in
 [`PerformanceResourceTiming`](https://w3c.github.io/resource-timing/#performanceresourcetiming), it has a different meaning in Navigation Timing, as
 unlike subresources, a navigation [may] trigger the
 activation or running of a service worker. In the context of
 Navigation Timing, \`workerStart\` returns the timestamp measured just
 before the worker has been activated or started. See
 [\[service-workers\]](#biblio-service-workers "Service Workers Nightly")
 for a precise definition.

- The
 [`fetchStart`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-fetchstart) getter steps are to perform the following steps:

 1. Let `workerTiming` be `this`'s [service
 worker
 timing](#performancenavigationtiming-service-worker-timing).
 2. If `workerTiming` is null, then return
 `this`'s prototype's \`fetchStart\`.
 3. Return `workerTiming`'s [fetch event dispatch
 time](https://w3c.github.io/ServiceWorker/#service-worker-timing-info-fetch-event-dispatch-time).

 When a [service
 worker](https://w3c.github.io/ServiceWorker/#dfn-service-worker) is used as part of the navigation, The \`fetchStart\`
 overload holds a different meaning than the meaning in
 [`PerformanceResourceTiming`](https://w3c.github.io/resource-timing/#performanceresourcetiming). It returns the timestamp measured right before the
 [`FetchEvent`](https://w3c.github.io/ServiceWorker/#fetchevent) is dispatched for the [service
 worker](https://w3c.github.io/ServiceWorker/#dfn-service-worker). The time difference between \`workerStart\` and
 \`fetchStart\` in the document's navigation timing entry can be used
 to determine roughly how long it took for the worker to be initialized
 or activated. See
 [\[service-workers\]](#biblio-service-workers "Service Workers Nightly")
 for a precise definition.

Only the [current document](#current-document) resource is included in the performance timeline; there
is only one
[`PerformanceNavigationTiming`](#performancenavigationtiming) object in the performance timeline.

### [3.3. ][ The [PerformanceNavigationTiming] interface ]
Checking and retrieving contents from the [HTTP
cache](https://httpwg.org/specs/rfc9111.html){biblio-display="inline"
}
[\[RFC9111\]](#biblio-rfc9111 "HTTP Caching") is
part of the [fetching
process](https://fetch.spec.whatwg.org/#concept-fetch). It's covered by the
[`requestStart`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-requeststart),
[`responseStart`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-responsestart) and
[`responseEnd`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-responseend) attributes.

```
[Exposed=Window]
interface PerformanceNavigationTiming : PerformanceResourceTiming {
 readonly attribute DOMHighResTimeStamp unloadEventStart;
 readonly attribute DOMHighResTimeStamp unloadEventEnd;
 readonly attribute DOMHighResTimeStamp domInteractive;
 readonly attribute DOMHighResTimeStamp domContentLoadedEventStart;
 readonly attribute DOMHighResTimeStamp domContentLoadedEventEnd;
 readonly attribute DOMHighResTimeStamp domComplete;
 readonly attribute DOMHighResTimeStamp loadEventStart;
 readonly attribute DOMHighResTimeStamp loadEventEnd;
 readonly attribute NavigationTimingType type;
 readonly attribute unsigned short redirectCount;
 readonly attribute DOMHighResTimeStamp criticalCHRestart;
 readonly attribute NotRestoredReasons? notRestoredReasons;
 readonly attribute PerformanceTimingConfidence confidence;
 [Default] object toJSON();
};
```

A
[`PerformanceNavigationTiming`](#performancenavigationtiming) has an associated [document load timing
info](https://html.spec.whatwg.org/multipage/dom.html#document-load-timing-info) [document load
timing].

A
[`PerformanceNavigationTiming`](#performancenavigationtiming) has an associated [document unload timing
info](https://html.spec.whatwg.org/multipage/dom.html#document-unload-timing-info) [previous document unload
timing].

A
[`PerformanceNavigationTiming`](#performancenavigationtiming) has an associated number [redirect
count].

A
[`PerformanceNavigationTiming`](#performancenavigationtiming) has an associated
[`NavigationTimingType`](#enumdef-navigationtimingtype) [navigation
type].

A
[`PerformanceNavigationTiming`](#performancenavigationtiming) has an associated
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) [\`Critical-CH\` restart
time].

A
[`PerformanceNavigationTiming`](#performancenavigationtiming) has an associated
[`NotRestoredReasons`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#notrestoredreasons) [not restored
reasons].

A
[`PerformanceNavigationTiming`](#performancenavigationtiming) has an associated
[`PerformanceTimingConfidence`](#performancetimingconfidence) [confidence
value].

A
[`PerformanceNavigationTiming`](#performancenavigationtiming) has an associated real number [randomized trigger
rate] which is
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined).

A
[`PerformanceNavigationTiming`](#performancenavigationtiming) has an associated
[`PerformanceTimingConfidenceValue`](#enumdef-performancetimingconfidencevalue) [underlying confidence
value] which is
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined).

A
[`PerformanceNavigationTiming`](#performancenavigationtiming) has an associated null or [service worker timing
info](https://w3c.github.io/ServiceWorker/#service-worker-timing-info) [service worker
timing].

The
[`unloadEventStart`] getter steps are to return
`this`'s [previous document unload
timing](#performancenavigationtiming-previous-document-unload-timing)'s [unload event start
time](https://html.spec.whatwg.org/multipage/dom.html#unload-event-start-time).

If the previous document and the current document have the same
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin),
this timestamp is measured immediately before the user agent starts the
[unload](https://html.spec.whatwg.org/multipage/browsing-the-web.html#unloading-documents) event of the previous document. If there is no previous
document or the previous document has a different
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
than the current document, this attribute will return zero.

The [`unloadEventEnd`] getter steps are to return
`this`'s [previous document unload
timing](#performancenavigationtiming-previous-document-unload-timing)'s [unload event end
time](https://html.spec.whatwg.org/multipage/dom.html#unload-event-end-time).

If the previous document and the current document have the same
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin),
this timestamp is measured immediately after the user agent handles the
[unload](https://html.spec.whatwg.org/multipage/browsing-the-web.html#unloading-documents) event of the previous document. If there is no previous
document or the previous document has a different
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
than the current document, this attribute will return zero.

The [`domInteractive`] getter steps are to return
`this`'s [document load
timing](#performancenavigationtiming-document-load-timing)'s [DOM interactive
time](https://html.spec.whatwg.org/multipage/dom.html#dom-interactive-time).

This timestamp is measured before the user agent sets the [current
document
readiness](https://html.spec.whatwg.org/multipage/dom.html#current-document-readiness) to
[\"interactive\"](https://html.spec.whatwg.org/multipage/parsing.html#the-end).

The
[`domContentLoadedEventStart`] getter steps are to return
`this`'s [document load
timing](#performancenavigationtiming-document-load-timing)'s [DOM content loaded event start
time](https://html.spec.whatwg.org/multipage/dom.html#dom-content-loaded-event-start-time).

This timestamp is measured before the user agent dispatches the
[DOMContentLoaded](https://html.spec.whatwg.org/multipage/parsing.html#the-end:event-domcontentloaded) event.

The
[`domContentLoadedEventEnd`] getter steps are to return
`this`'s [document load
timing](#performancenavigationtiming-document-load-timing)'s [DOM content loaded event end
time](https://html.spec.whatwg.org/multipage/dom.html#dom-content-loaded-event-end-time).

This timestamp is measured after the user agent completes handling of
the
[DOMContentLoaded](https://html.spec.whatwg.org/multipage/parsing.html#the-end:event-domcontentloaded) event.

The [`domComplete`] getter steps are to return
`this`'s [document load
timing](#performancenavigationtiming-document-load-timing)'s [DOM complete
time](https://html.spec.whatwg.org/multipage/dom.html#dom-complete-time).

This timestamp is measured before the user agent sets the [current
document
readiness](https://html.spec.whatwg.org/multipage/dom.html#current-document-readiness) to
[\"complete\"](https://html.spec.whatwg.org/multipage/parsing.html#the-end). See [document
readiness](https://html.spec.whatwg.org/multipage/dom.html#current-document-readiness) for a precise definition.

The [`loadEventStart`] getter steps are to return
`this`'s [document load
timing](#performancenavigationtiming-document-load-timing)'s [load event start
time](https://html.spec.whatwg.org/multipage/dom.html#load-event-start-time).

This timestamp is measured before the user agent dispatches the
[load](https://html.spec.whatwg.org/multipage/indices.html#event-load)
event for the document.

The [`loadEventEnd`] getter steps are to return
`this`'s [document load
timing](#performancenavigationtiming-document-load-timing)'s [load event end
time](https://html.spec.whatwg.org/multipage/dom.html#load-event-end-time).

This timestamp is measured after the user agent completes handling the
[load](https://html.spec.whatwg.org/multipage/indices.html#event-load)
event for the document.

The [`type`] getter steps are to run the `this`'s [navigation
type](#performancenavigationtiming-navigation-type).

Client-side redirects, such as those using the [Refresh pragma
directive](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-http-equiv-refresh), are not considered [HTTP
redirects](https://fetch.spec.whatwg.org/#redirect-status) by this spec. In those cases, the
[`type`](#dom-performancenavigationtiming-type) attribute SHOULD return appropriate value, such as
[reload](#navigationtimingtype-reload) if reloading the current page, or
[navigate](#navigationtimingtype-navigate) if navigating to a new URL.

The [`redirectCount`] getter steps are to return
`this`'s redirect count.

The
[`criticalCHRestart`] getter steps are to return
`this`'s \`Critical-CH\` restart time.

If `criticalCHRestart` is not 0 it will be before all other
timestamps except for `navigationStart`,
`unloadEventStart`, and `unloadEventEnd`. This is
because it marks the moment the redirection part of the navigation was
restarted.

[`notRestoredReasons`] getter steps are to return
`this`'s not restored reasons.

The [`confidence`] getter steps are to run these steps:

1. If `this`'s [document load
 timing](#performancenavigationtiming-document-load-timing)'s [DOM interactive
 time](https://html.spec.whatwg.org/multipage/dom.html#dom-interactive-time) is 0, return null.
2. If `this`'s [confidence
 value](#performancenavigationtiming-confidence-value) is not null, return it.
3. Let `confidence` be a new
 [`PerformanceTimingConfidence`](#performancetimingconfidence) object created in
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).
4. Set `confidence`'s
 [`randomizedTriggerRate`](#dom-performancetimingconfidence-randomizedtriggerrate) to `this`'s [randomized trigger
 rate](#performancenavigationtiming-randomized-trigger-rate).
5. Set `confidence`'s
 [`value`](#dom-performancetimingconfidence-value) as determined by the following algorithm:
 1. Let `p` be `confidence`'s
 [`randomizedTriggerRate`](#dom-performancetimingconfidence-randomizedtriggerrate).
 2. Let `underlying` be
 [this](https://webidl.spec.whatwg.org/#this)'s [underlying confidence
 value](#performancenavigationtiming-underlying-confidence-value), a
 [`PerformanceTimingConfidenceValue`](#enumdef-performancetimingconfidencevalue).
 3. Let `r` be a real number drawn uniformly at random
 from the interval \[0, 1).
 4. If `r` \> or equal `p`, return
 `underlying`.
 5. Otherwise:
 1. Let `s` be an integer drawn uniformly at random
 from the set {0, 1}.
 2. If `s` equals 0, return
 [`high`](#dom-performancetimingconfidencevalue-high).
 3. Otherwise, return
 [`low`](#dom-performancetimingconfidencevalue-low).
6. Return `confidence`.

These values [should] be set once, and not change for the
lifetime of [this](https://webidl.spec.whatwg.org/#this).

This section is intended to help RUM providers and developers interpret
`confidence`. Since the [randomized trigger
rate](#performancenavigationtiming-randomized-trigger-rate) can vary across records, per-record weighting is needed
to recover unbiased aggregates. The procedure below illustrates how
weighting based on
[`value`](#dom-performancetimingconfidence-value) can be applied before computing summary statistics.

To compute debiased means for both
[`high`](#dom-performancetimingconfidencevalue-high) and
[`low`](#dom-performancetimingconfidencevalue-low):

1. For each record:
 - Let `p` be the record's
 [`randomizedTriggerRate`](#dom-performancetimingconfidence-randomizedtriggerrate).
 - Let `c` be the record's
 [`value`](#dom-performancetimingconfidence-value).
 - Let `R` be 1 when `c` is
 [`high`](#dom-performancetimingconfidencevalue-high), otherwise 0.
 - Compute per-record weight `w` based on `c`:
 - For estimating the high mean:
 `w`` = (R - (p / 2)) / (1 - p)`.
 - For estimating the low mean:
 `w`` = ((1 - R) - (p / 2)) / (1 - p)`.

 Note that `w` [may] be negative for some
 records; keep every record.
 - Let `weighted_duration` =
 [`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration) \* `w`.
2. Let `total_weighted_duration` be the sum of
 `weighted_duration` values across all records.
3. Let `sum_weights` be the sum of `w` values
 across all records.
4. Let `debiased_mean` =
 `total_weighted_duration` / `sum_weights`,
 provided `sum_weights` is not near zero.

To compute debiased percentiles for both
[`high`](#dom-performancetimingconfidencevalue-high) and
[`low`](#dom-performancetimingconfidencevalue-low):

1. Follow the same steps as computing the debiased mean to compute a
 per-record weight `w`.
2. Let `sum_weights` be the sum of `w` values
 across all records.
3. Let `sorted_records` be all records sorted by
 [`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration) in ascending order.
4. For a desired `percentile` (0-100), compute
 `q`` = ``percentile`` / 100.0`
5. Walk `sorted_records` and for each record:
 - Compute cumulative weight `cw` per-record:
 `cw`` = sum_{i: duration_i <= duration_j} w_i`.
 - Compute debiased cumulative distribution function per-record:
 `cdf`` = ``cw`` / ``sum_weights`
6. Find the first index `idx` with `cdf` \>=
 `q`.
 - If `idx` is 0, return
 [`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration) for `sorted_records`\[0\].
 - If no such `idx` exists, return
 [`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration) for `sorted_records`\[n\].
7. Compute interpolation fraction:
 - Let `lower_cdf` be `cdf` for
 `sorted_records`\[idx-1\]
 - Let `upper_cdf` be `cdf` for
 `sorted_records`\[idx\]
 - if `lower_cdf` = `upper_cdf`, return
 [`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration) for `sorted_records`\[idx\].
 - Otherwise:
 - Let
 `ifrac`` = (``q`` - ``lower_cdf``) / (``upper_cdf`` - ``lower_cdf``)`
 - Let `lower_duration` be
 [`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration) for `sorted_records`\[idx-1\]
 - Let `upper_duration` be
 [`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration) for `sorted_records`\[idx\]
 - return lower_duration + (upper_duration - lower_duration) \*
 ifrac

The [toJSON()] method
runs the [default toJSON
steps](https://webidl.spec.whatwg.org/#default-tojson-steps) for
[this](https://webidl.spec.whatwg.org/#this).

#### 3.3.1. The [`NavigationTimingType` enum]
```
enum NavigationTimingType {
 "navigate",
 "reload",
 "back_forward"
};
```

The values are defined as follows:

[navigate]
: Navigation where the [history handling
 behavior](https://html.spec.whatwg.org/multipage/browsing-the-web.html#history-handling-behavior) is set to
 [\"default\"](https://html.spec.whatwg.org/multipage/browsing-the-web.html#hh-default) or
 [\"replace\"](https://html.spec.whatwg.org/multipage/browsing-the-web.html#hh-replace).

[reload]
: Navigation where the
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable)
 was
 [reloaded](https://html.spec.whatwg.org/multipage/browsing-the-web.html#reload).

[back_forward]
: Navigation that's [applied from
 history](https://html.spec.whatwg.org/multipage/browsing-the-web.html#apply-the-history-step).

The format of the above enumeration value is inconsistent with the
[WebIDL recommendation for formatting of enumeration
values](https://webidl.spec.whatwg.org/#dfn-enumeration). Unfortunately, we are unable to change it due to
backwards compatibility issues with shipped implementations.
[\[WebIDL\]](#biblio-webidl "Web IDL Standard")

#### 3.3.2. The [`PerformanceTimingConfidence` interface]
```
[Exposed=Window]
interface PerformanceTimingConfidence {
 readonly attribute double randomizedTriggerRate;
 readonly attribute PerformanceTimingConfidenceValue value;
 object toJSON();
};
```

[`randomizedTriggerRate`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: This attribute must return a real number the interval \[0, 1),
 indicating how often noise is applied when exposing the confidence
 [`value`](#dom-performancetimingconfidence-value).

[`value`], of type [PerformanceTimingConfidenceValue](#enumdef-performancetimingconfidencevalue), readonly

: This attribute must return a
 [`PerformanceTimingConfidenceValue`](#enumdef-performancetimingconfidencevalue).

[toJSON()]

: This method runs the [default toJSON
 steps](https://webidl.spec.whatwg.org/#default-tojson-steps) for
 [this](https://webidl.spec.whatwg.org/#this).

#### 3.3.3. The [`PerformanceTimingConfidenceValue` enum]
```
enum PerformanceTimingConfidenceValue {
 "high",
 "low"
};
```

The values are defined as follows:

[high]
: The user agent considers the navigation metrics to be representative
 on the current user's device.

[low]
: The navigation metrics may not be representative of the current
 user's device. The user agent may consider the state of the machine,
 or user configuration.

When determining the [underlying confidence
value](#performancenavigationtiming-underlying-confidence-value), user agents MUST only base their decision on
*transient runtime conditions*, such as user agent startup, temporarily
high CPU usage, temporary memory pressure, or other short-lived
considerations.

User agents MUST NOT base the [underlying confidence
value](#performancenavigationtiming-underlying-confidence-value) on permanent device or profile characteristics.
Examples of prohibited factors include the amount of physical RAM on the
device, the number of CPU cores, the number of installed extensions, or
other static environment settings.

Confidence is intended to reflect runtime variability rather than system
capabilities.

## 4. Process

### 4.1. Processing Model

![This figure illustrates the timing attributes defined by the
[`PerformanceNavigationTiming`](#performancenavigationtiming) interface. Attributes in parenthesis indicate that they
may not be available for navigations involving documents from different
[origins](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin).](timestamp-diagram.svg){a
height="440" style="width: 100%" width="1152"}

## 5. Creating a navigation timing entry

Each
[document](https://dom.spec.whatwg.org/#concept-document) has an associated [navigation timing
entry], initially unset.

To [create the navigation timing
entry] for
[`Document`](https://dom.spec.whatwg.org/#document) `document`, given a [fetch timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info) `fetchTiming`, a number
`redirectCount`, a
[`NavigationTimingType`](#enumdef-navigationtimingtype) `navigationType`, a null or [service worker
timing
info](https://w3c.github.io/ServiceWorker/#service-worker-timing-info) `serviceWorkerTiming`, a DOMString
`cacheMode`, a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) `criticalCHRestart`, and a [response body
info](https://fetch.spec.whatwg.org/#response-body-info) `bodyInfo`, do the following:

1. Let `global` be `document`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).
2. Let `navigationTimingEntry` be a new
 [`PerformanceNavigationTiming`](#performancenavigationtiming) object in `global`'s
 [realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-global-object-realm).
3. [Setup the resource timing
 entry](https://www.w3.org/TR/resource-timing/#dfn-setup-the-resource-timing-entry) for `navigationTimingEntry` given
 \"`navigation`\", `document`'s
 [`URL`](https://dom.spec.whatwg.org/#dom-document-url), `fetchTiming`, `cacheMode`,
 and `bodyInfo`.
4. Set `navigationTimingEntry`'s [document load
 timing](#performancenavigationtiming-document-load-timing) to `document`'s [load timing
 info](https://html.spec.whatwg.org/multipage/dom.html#load-timing-info)
5. Set `navigationTimingEntry`'s [previous document unload
 timing](#performancenavigationtiming-previous-document-unload-timing) to `document`'s [previous document
 unload
 timing](https://html.spec.whatwg.org/multipage/dom.html#previous-document-unload-timing).
6. Set `navigationTimingEntry`'s [redirect
 count](#performancenavigationtiming-redirect-count) to `redirectCount`.
7. Set `navigationTimingEntry`'s [navigation
 type](#performancenavigationtiming-navigation-type) to `navigationType`.
8. Set `navigationTimingEntry`'s [service worker
 timing](#performancenavigationtiming-service-worker-timing) to `serviceWorkerTiming`.
9. Set `document`'s navigation timing entry to
 `navigationTimingEntry`.
10. Set `navigationTimingEntry`'s [\`Critical-CH\` restart
 time](#performancenavigationtiming-critical-ch-restart-time) to `criticalCHRestart`.
11. Set `navigationTimingEntry`'s [not restored
 reasons](#performancenavigationtiming-not-restored-reasons) to the result of [creating a NotRestoredReasons
 object](https://html.spec.whatwg.org/multipage/nav-history-apis.html#create-a-notrestoredreasons-object) given `document`'s [not restored
 reasons](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-nrr).
12. add `navigationTimingEntry` to `global`'s
 [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer).

To [queue the navigation timing
entry] for
[`Document`](https://dom.spec.whatwg.org/#document) `document`,
[queue](https://html.spec.whatwg.org/multipage/nav-history-apis.html#queue-a-navigation-performanceentry) `document`'s [navigation timing
entry](#document-navigation-timing-entry).

## 6. Privacy Considerations

*This section is non-normative.*

### 6.1. Information disclosure

There is the potential for disclosing an end-user's browsing and
activity history by using carefully crafted timing attacks. For
instance, the unloading time reveals how long the previous page takes to
execute its unload handler, which could be used to infer the user's
login status. These attacks have been mitigated by enforcing the [same
origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin)
check algorithm when unloading a document, as detailed in [the HTML
spec](https://html.spec.whatwg.org/multipage/#update-the-session-history-with-the-new-page).

The [relaxed same origin
policy](https://html.spec.whatwg.org/multipage/origin.html#relaxing-the-same-origin-restriction) doesn't provide sufficient protection against
unauthorized visits across documents. In shared hosting, an untrusted
third party is able to host an HTTP server at the same IP address but on
a different port.

### 6.2. Cross-directory access

Different pages sharing one host name, for example contents from
different authors hosted on sites with user generated content are
considered from the same origin because there is no feature to restrict
the access by pathname. Navigating between these pages allows a latter
page to access timing information of the previous one, such as timing
regarding redirection and unload event.

## 7. Security Considerations

*This section is non-normative.*

The
[`PerformanceNavigationTiming`](#performancenavigationtiming) interface exposes timing information about the previous
document to the [current
document](#current-document). To limit the access to
[`PerformanceNavigationTiming`](#performancenavigationtiming) attributes which include information on the previous
document, the [previous document
unloading](https://html.spec.whatwg.org/multipage/#update-the-session-history-with-the-new-page) algorithm enforces the [same origin
policy](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
and attributes related to the previous document are set to zero.

### 7.1. Detecting proxy servers

In case a proxy is deployed between the user agent and the web server,
the time interval between the
[`connectStart`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-connectstart) and the
[`connectEnd`](https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-connectend) attributes indicates the delay between the user agent
and the proxy instead of the web server. With that, web server can
potentially infer the existence of the proxy. For SOCKS proxy, this time
interval includes the proxy authentication time and time the proxy takes
to connect to the web server, which obfuscate the proxy detection. In
case of an HTTP proxy, the user agent might not have any knowledge about
the proxy server at all so it's not always feasible to mitigate this
attack.

## 8. Obsolete

This section defines attributes and interfaces previously introduced in
[\[NAVIGATION-TIMING\]](#biblio-navigation-timing "Navigation Timing")
Level 1 and are kept here for backwards compatibility. Authors should
not use the following interfaces and are **strongly advised** to use the
new
[`PerformanceNavigationTiming`](#performancenavigationtiming) interface---see [summary of changes and
improvements](#sotd).

### [8.1. ][ The [PerformanceTiming] interface ]
```
[Exposed=Window]
interface PerformanceTiming {
 readonly attribute unsigned long long navigationStart;
 readonly attribute unsigned long long unloadEventStart;
 readonly attribute unsigned long long unloadEventEnd;
 readonly attribute unsigned long long redirectStart;
 readonly attribute unsigned long long redirectEnd;
 readonly attribute unsigned long long fetchStart;
 readonly attribute unsigned long long domainLookupStart;
 readonly attribute unsigned long long domainLookupEnd;
 readonly attribute unsigned long long connectStart;
 readonly attribute unsigned long long connectEnd;
 readonly attribute unsigned long long secureConnectionStart;
 readonly attribute unsigned long long requestStart;
 readonly attribute unsigned long long responseStart;
 readonly attribute unsigned long long responseEnd;
 readonly attribute unsigned long long domLoading;
 readonly attribute unsigned long long domInteractive;
 readonly attribute unsigned long long domContentLoadedEventStart;
 readonly attribute unsigned long long domContentLoadedEventEnd;
 readonly attribute unsigned long long domComplete;
 readonly attribute unsigned long long loadEventStart;
 readonly attribute unsigned long long loadEventEnd;
 [Default] object toJSON();
};
```

All time values defined in this section are measured in milliseconds
since midnight of January 1, 1970 (UTC).

[navigationStart]

: This attribute must return the time immediately after the user agent
 finishes [prompting to
 unload](https://html.spec.whatwg.org/multipage/browsing-the-web.html#prompt-to-unload-a-document) the previous document. If there is no previous
 document, this attribute must return the time the current document
 is created.

 This attribute is not defined for
 [`PerformanceNavigationTiming`](#performancenavigationtiming). Instead, authors can use
 [`timeOrigin`](https://w3c.github.io/hr-time/#dom-performance-timeorigin) to obtain an equivalent timestamp.

[unloadEventStart]

: If the previous document and the current document have the same
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin),
 this attribute must return the time immediately before the user
 agent starts the
 [unload](https://html.spec.whatwg.org/multipage/browsing-the-web.html#unloading-documents) event of the previous document. If there is no
 previous document or the previous document has a different
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
 than the current document, this attribute must return zero.

[unloadEventEnd]

: If the previous document and the current document have the same
 [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin),
 this attribute must return the time immediately after the user agent
 finishes the
 [unload](https://html.spec.whatwg.org/multipage/browsing-the-web.html#unload-a-document) event of the previous document. If there is no
 previous document or the previous document has a different
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
 than the current document or the unload is not yet completed, this
 attribute must return zero.

 If there are [HTTP
 redirects](https://fetch.spec.whatwg.org/#redirect-status) when navigating and not all the redirects are from
 the same
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin),
 both
 [`unloadEventStart`](#dom-performancetiming-unloadeventstart) and
 [`unloadEventEnd`](#dom-performancetiming-unloadeventend) must return zero.

[redirectStart]

: If there are [HTTP
 redirects](https://fetch.spec.whatwg.org/#redirect-status) when navigating and if all the redirects are from
 the same
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin),
 this attribute must return the
 [`starting time of the fetch`](#dom-performancetiming-fetchstart) that initiates the redirect. Otherwise, this
 attribute must return zero.

[redirectEnd]

: If there are [HTTP
 redirects](https://fetch.spec.whatwg.org/#redirect-status) when navigating and all redirects are from the same
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin),
 this attribute must return the time immediately after receiving the
 last byte of the response of the last redirect. Otherwise, this
 attribute must return zero.

[fetchStart]

: If the new resource is to be
 [fetched](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#fetching-resources) using a \"GET\" [request
 method](https://fetch.spec.whatwg.org/#concept-request-method), fetchStart must return the time immediately before
 the user agent starts checking the [HTTP
 cache](https://httpwg.org/specs/rfc9111.html){biblio-display="inline"
 }
 [\[RFC9111\]](#biblio-rfc9111 "HTTP Caching").
 Otherwise, it must return the time when the user agent starts
 [fetching](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#fetching-resources) the resource.

[domainLookupStart]

: This attribute must return the time immediately before the user
 agent starts the domain name lookup for the current document. If a
 [persistent
 connection](https://httpwg.org/specs/rfc9112.html#persistent.connections)
 [\[RFC9112\]](#biblio-rfc9112 "HTTP/1.1") is
 used or the current document is retrieved from the [HTTP
 cache](https://httpwg.org/specs/rfc9111.html){biblio-display="inline"
 }
 [\[RFC9111\]](#biblio-rfc9111 "HTTP Caching") or
 local resources, this attribute must return the same value as
 [`fetchStart`](#dom-performancetiming-fetchstart).

[domainLookupEnd]

: This attribute must return the time immediately after the user agent
 finishes the domain name lookup for the current document. If a
 [persistent
 connection](https://httpwg.org/specs/rfc9112.html#persistent.connections)
 [\[RFC9112\]](#biblio-rfc9112 "HTTP/1.1") is
 used or the current document is retrieved from the [HTTP
 cache](https://httpwg.org/specs/rfc9111.html){biblio-display="inline"
 }
 [\[RFC9111\]](#biblio-rfc9111 "HTTP Caching") or
 local resources, this attribute must return the same value as
 [`fetchStart`](#dom-performancetiming-fetchstart).

 :::
 Checking and retrieving contents from the [HTTP
 cache](https://httpwg.org/specs/rfc9111.html){biblio-display="inline"
 }
 [\[RFC9111\]](#biblio-rfc9111 "HTTP Caching") is
 part of the [fetching
 process](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#fetching-resources). It's covered by the
 [`requestStart`](#dom-performancetiming-requeststart),
 [`responseStart`](#dom-performancetiming-responsestart) and
 [`responseEnd`](#dom-performancetiming-responseend) attributes.
 :::

 In case where the user agent already has the domain information in
 cache, domainLookupStart and domainLookupEnd represent the times
 when the user agent starts and ends the domain data retrieval from
 the cache.

[connectStart]

: This attribute must return the time immediately before the user
 agent start establishing the connection to the server to retrieve
 the document. If a [persistent
 connection](https://httpwg.org/specs/rfc9112.html#persistent.connections)
 [\[RFC9112\]](#biblio-rfc9112 "HTTP/1.1") is
 used or the current document is retrieved from the [HTTP
 cache](https://httpwg.org/specs/rfc9111.html){biblio-display="inline"
 }
 [\[RFC9111\]](#biblio-rfc9111 "HTTP Caching") or
 local resources, this attribute must return value of
 [`domainLookupEnd`](#dom-performancetiming-domainlookupend).

[connectEnd]

: This attribute must return the time immediately after the user agent
 finishes establishing the connection to the server to retrieve the
 current document. If a [persistent
 connection](https://httpwg.org/specs/rfc9112.html#persistent.connections)
 [\[RFC9112\]](#biblio-rfc9112 "HTTP/1.1") is
 used or the current document is retrieved from the [HTTP
 cache](https://httpwg.org/specs/rfc9111.html){biblio-display="inline"
 }
 [\[RFC9111\]](#biblio-rfc9111 "HTTP Caching") or
 local resources, this attribute must return the value of
 [`domainLookupEnd`](#dom-performancetiming-domainlookupend).

 If the transport connection fails and the user agent reopens a
 connection,
 [`connectStart`](#dom-performancetiming-connectstart) and
 [`connectEnd`](#dom-performancetiming-connectend) should return the corresponding values of the new
 connection.

 [`connectEnd`](#dom-performancetiming-connectend) must include the time interval to establish the
 transport connection as well as other time interval such as SSL
 handshake and SOCKS authentication.

[secureConnectionStart]

: This attribute is optional. User agents that don't have this
 attribute available must set it as undefined. When this attribute is
 available, if the
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme)
 [\[URL\]](#biblio-url "URL Standard") of the
 current page is \"https\", this attribute must return the time
 immediately before the user agent starts the handshake process to
 secure the current connection. If this attribute is available but
 HTTPS is not used, this attribute must return zero.

[requestStart]

: This attribute must return the time immediately before the user
 agent starts requesting the current document from the server, or
 [HTTP
 cache](https://httpwg.org/specs/rfc9111.html){biblio-display="inline"
 }
 [\[RFC9111\]](#biblio-rfc9111 "HTTP Caching") or
 from local resources.

 If the transport connection fails after a request is sent and the
 user agent reopens a connection and resend the request,
 [`requestStart`](#dom-performancetiming-requeststart) should return the corresponding values of the new
 request.

 :::
 This interface does not include an attribute to represent the
 completion of sending the request, e.g., requestEnd.

 - Completion of sending the request from the user agent does not
 always indicate the corresponding completion time in the network
 transport, which brings most of the benefit of having such an
 attribute.
 - Some user agents have high cost to determine the actual completion
 time of sending the request due to the HTTP layer encapsulation.
 :::

[responseStart]

: This attribute must return the time immediately after the user agent
 receives the first byte of the response from the server, or [HTTP
 cache](https://httpwg.org/specs/rfc9111.html){biblio-display="inline"
 }
 [\[RFC9111\]](#biblio-rfc9111 "HTTP Caching") or
 from local resources.

[responseEnd]

: This attribute must return the time immediately after the user agent
 receives the last byte of the current document or immediately before
 the transport connection is closed, whichever comes first. The
 document here can be received either from the server, the [HTTP
 cache](https://httpwg.org/specs/rfc9111.html){biblio-display="inline"
 }
 [\[RFC9111\]](#biblio-rfc9111 "HTTP Caching") or
 from local resources.

[domLoading]

: This attribute must return the time immediately before the user
 agent sets the [current document
 readiness](https://html.spec.whatwg.org/multipage/dom.html#current-document-readiness) to
 [\"loading\"](https://html.spec.whatwg.org/multipage/dom.html#current-document-readiness).

 Due to differences in when a Document object is created in existing
 user agents, the value returned by the `domLoading` is
 implementation specific and should not be used in meaningful
 metrics.

[domInteractive]

: This attribute must return the time immediately before the user
 agent sets the [current document
 readiness](https://html.spec.whatwg.org/multipage/dom.html#current-document-readiness) to
 [\"interactive\"](https://html.spec.whatwg.org/multipage/parsing.html#the-end).

[domContentLoadedEventStart]

: This attribute must return the time immediately before the user
 agent fires [the DOMContentLoaded
 event](https://html.spec.whatwg.org/multipage/parsing.html#the-end) at the
 [`Document`](https://dom.spec.whatwg.org/#document).

[domContentLoadedEventEnd]

: This attribute must return the time immediately after the document's
 [DOMContentLoaded
 event](https://html.spec.whatwg.org/multipage/parsing.html#the-end) completes.

[domComplete]

: This attribute must return the time immediately before the user
 agent sets the [current document
 readiness](https://html.spec.whatwg.org/multipage/dom.html#current-document-readiness) to
 [\"complete\"](https://html.spec.whatwg.org/multipage/parsing.html#the-end).

 If the [current document
 readiness](https://html.spec.whatwg.org/multipage/dom.html#current-document-readiness) changes to the same state multiple times,
 [`domLoading`](#dom-performancetiming-domloading),
 [`domInteractive`](#dom-performancetiming-dominteractive),
 [`domContentLoadedEventStart`](#dom-performancetiming-domcontentloadedeventstart),
 [`domContentLoadedEventEnd`](#dom-performancetiming-domcontentloadedeventend) and
 [`domComplete`](#dom-performancetiming-domcomplete) must return the time of the first occurrence of the
 corresponding [document
 readiness](https://html.spec.whatwg.org/multipage/dom.html#current-document-readiness) change.

[loadEventStart]

: This attribute must return the time immediately before the load
 event of the current document is fired. It must return zero when the
 load event is not fired yet.

[loadEventEnd]

: This attribute must return the time when the load event of the
 current document is completed. It must return zero when the load
 event is not fired or is not completed.

[toJSON()]
: Runs the [default toJSON
 steps](https://webidl.spec.whatwg.org/#default-tojson-steps) for
 [this](https://webidl.spec.whatwg.org/#this).

### [8.2. ][ The [PerformanceNavigation] interface ]
```
[Exposed=Window]
interface PerformanceNavigation {
 const unsigned short TYPE_NAVIGATE = 0;
 const unsigned short TYPE_RELOAD = 1;
 const unsigned short TYPE_BACK_FORWARD = 2;
 const unsigned short TYPE_RESERVED = 255;
 readonly attribute unsigned short type;
 readonly attribute unsigned short redirectCount;
 [Default] object toJSON();
};
```

[TYPE_NAVIGATE]

: Navigation where the [history handling
 behavior](https://html.spec.whatwg.org/multipage/browsing-the-web.html#history-handling-behavior) is set to
 [\"default\"](https://html.spec.whatwg.org/multipage/browsing-the-web.html#hh-default) or
 [\"replace\"](https://html.spec.whatwg.org/multipage/browsing-the-web.html#hh-replace).

[TYPE_RELOAD]

: Navigation where the [history handling
 behavior](https://html.spec.whatwg.org/multipage/browsing-the-web.html#history-handling-behavior) is set to
 [\"reload\"](https://html.spec.whatwg.org/multipage/browsing-the-web.html#hh-reload).

[TYPE_BACK_FORWARD]

: Navigation where the [history handling
 behavior](https://html.spec.whatwg.org/multipage/browsing-the-web.html#history-handling-behavior) is set to [\"entry
 update\"](https://html.spec.whatwg.org/multipage/browsing-the-web.html#hh-entry-update).

[TYPE_RESERVED]

: Any navigation types not defined by values above.

[type]

: This attribute must return the type of the last non-redirect
 [navigation](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate).
 It must have one of the following
 [`navigation type`](#dom-performancenavigationtiming-type) values.

 Client-side redirects, such as those using [the Refresh pragma
 directive](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-http-equiv-refresh), are not considered [HTTP
 redirects](https://fetch.spec.whatwg.org/#redirect-status) by this spec. In those cases, the
 [`type`](#dom-performancenavigationtiming-type) attribute [should] return appropriate
 value, such as `TYPE_RELOAD` if reloading the current page, or
 `TYPE_NAVIGATE` if navigating to a new URL.

[redirectCount]

: This attribute must return the number of redirects since the last
 non-redirect navigation. If there is no redirect or there is any
 redirect that is not from the [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin)
 as the destination document, this attribute must return zero.

[toJSON()]
: Runs the [default toJSON
 steps](https://webidl.spec.whatwg.org/#default-tojson-steps) for
 [this](https://webidl.spec.whatwg.org/#this).

### 8.3. Extensions to the `Performance` interface

```
[Exposed=Window]
partial interface Performance {
 [SameObject]
 readonly attribute PerformanceTiming timing;
 [SameObject]
 readonly attribute PerformanceNavigation navigation;
};
```

The [Performance] interface is defined in
[\[PERFORMANCE-TIMELINE-2\]](#biblio-performance-timeline-2 "Performance Timeline").

[timing]

: The `timing` attribute represents the timing information since the
 last non-redirect navigation. This attribute is defined by the
 `PerformanceTiming` interface.

[navigation]

: The `navigation` attribute is defined by the `PerformanceNavigation`
 interface.

## 9. Acknowledgments

Thanks to Anne Van Kesteren, Arvind Jain, Boris Zbarsky, Jason Weber,
Jonas Sicking, James Simonsen, Karen Anderson, Nic Jansma, Philippe Le
Hegaret, Steve Souders, Todd Reifsteck, Tony Gentilcore, William Chan
and Zhiheng Wang for their contributions to this work.
