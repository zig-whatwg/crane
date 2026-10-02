
## 1. Introduction

This document provides three pieces of infrastructure for generic
reporting, which may be used or extended by other specifications:

1. A generic framework for defining report types and reporting
 endpoints, and a document format for sending reports to endpoints
 over HTTP.

2. A specific mechanism for configuring reporting endpoints in a
 document or worker, and for delivering reports whose lifetime is
 tied to that document or worker.

3. A JavaScript interface for observing reports generated within a
 document or worker.

Other specifications may extend or make use of these pieces, for
instance by defining concrete report types, or alternative configuration
or delivery mechanisms for non-document-based reports.

### 1.1. Guarantees

This specification aims to provide a best-effort report delivery system
that executes out-of-band with website activity. The user agent will be
able to do a better job prioritizing and scheduling delivery of reports,
as it has an overview of cross-origin activity that individual websites
do not, and can deliver reports based on error conditions that would
prevent a website from loading in the first place.

The delivery is not, however, guaranteed in any way, and reporting is
not intended to be used as a reliable communications channel. Network
conditions may prevent reports from reaching their destination at all,
and user agents are permitted to reject and not deliver a report for any
reason.

### 1.2. Examples

MegaCorp Inc. wants to collect Content
Security Policy and Key Pinning violation reports. It can do so by
delivering the following header to define a set of reporting endpoints
named \"`endpoint-1`\":

 Reporting-Endpoints: endpoint-1="https://example.com/reports"

And the following headers, which direct CSP and HPKP reports to that
endpoint:

 Content-Security-Policy: ...; report-to endpoint-1
 Public-Key-Pins: ...; report-to=endpoint-1

After processing reports for a little
while, MegaCorp Inc. decides to split the processing of these two types
of reports out into two distinct endpoints in order to make the
processing scripts simpler. It can do so by delivering the following
header to define two reporting endpoints:

 Reporting-Endpoints: csp-endpoint="https://example.com/csp-reports",
 hpkp-endpoint="https://example.com/hpkp-reports"

And the following headers, which direct CSP and HPKP reports to those
named endpoints:

 Content-Security-Policy: ...; report-to csp-endpoint
 Public-Key-Pins: ...; report-to=hpkp-endpoint

## 2. Generic Reporting Framework

This section defines the generic concepts of reports and endpoints, and
how reports are serialized into the
[`application/reports+json`](#media-type) format.

### 2.1. Concepts

#### 2.1.1. Endpoints

An [endpoint] is
location to which
[reports](#windoworworkerglobalscope-reports) for a particular
[origin](https://html.spec.whatwg.org/multipage/browsers.html#origin) may be sent.

Each [endpoint](#endpoint) has a
[`name`], which is an ASCII
string.

Each [endpoint](#endpoint) has a
[`url`], which is a
[`URL`](https://url.spec.whatwg.org/#concept-url).

Each [endpoint](#endpoint) has a
[`failures`], which is a
non-negative integer representing the number of consecutive times this
endpoint has failed to respond to a request.

#### 2.1.2. Report Type

A [report type]
is a non-empty string that specifies the set of data that is contained
in the [body](#report-body) of a
[report](#report).

When a [report type](#report-type)
is defined (in this spec or others), it can be specified to be [visible
to `ReportingObserver`s], meaning that
[reports](#windoworworkerglobalscope-reports) of that type can be observed by a [reporting
observer](#reporting-observer). By default, [report
types](#report-type) are not
[visible to
`ReportingObserver`s](#visible-to-reportingobservers).

#### 2.1.3. Reports

A [report] is a
collection of arbitrary data which the user agent is expected to deliver
to a specified endpoint.

Each [report](#report) has a
[body], which is either `null` or an object which can be serialized
into a [JSON
text](https://tools.ietf.org/html/rfc8259#section-2). The fields contained in a
[report](#report)'s
[body](#report-body) are
determined by the [report](#report)'s
[type](#report-reporttype).

Each [report](#report) has a
[url], which is typically the address of the `Document` or `Worker`
from which the report was generated.

 We strip the username, password, and fragment from this
serialized URL. See [§ 8.1 Capability URLs](#capability-urls).

Each [report](#report) has a [user
agent], which is the value of the `User-Agent`
[header](https://fetch.spec.whatwg.org/#concept-header) of the
[request](https://fetch.spec.whatwg.org/#concept-request) from which the report was generated.

 The [user
agent](#report-user-agent)
of a [report](#report) represents the
`User-Agent` sent by the browser for the page which generated the
[report](#report). This is potentially
distinct from the `User-Agent` sent in the HTTP headers when uploading
the report to a collector --- for instance, where the browser has chosen
to use a non-default `User-Agent` string such as the \"request desktop
site\" feature.

Each [report](#report) has a
[destination], which is a string representing the
[`name`](#dom-endpoint-name) of the [endpoint](#endpoint) that the report will be sent to.

Each [report](#report) has a
[type], which is a [report
type](#report-type).

Each [report](#report) has a
[timestamp], which records the time at which the report
was generated, in milliseconds since the unix epoch.

Each [report](#report) has an
[attempts] counter, which is a non-negative integer
representing the number of times the user agent attempted to deliver the
report.

### 2.2. Media Type

The media type used when POSTing reports to a specified endpoint is
`application/reports+json`.

### 2.3. Queue `data` as `type` for `destination`

To [generate a report] given a serializable object
(`data`), a string (`type`), another string
(`destination`), and an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) (`settings`):

1. Let `report` be a new [report](#report) object with its values initialized as follows:

 [body](#report-body)

 : `data`

 [user agent](#report-user-agent)

 : The current value of
 [`navigator.userAgent`](https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-useragent)

 [destination](#report-destination)

 : `destination`

 [type](#report-reporttype)

 : `type`

 [timestamp](#report-timestamp)

 : The current timestamp.

 [attempts](#report-attempts)

 : 0

2. Let `url` be `settings`'s [creation
 URL](https://html.spec.whatwg.org/multipage/webappapis.html#creation-url).

3. Set `url`'s
 [`username`](https://url.spec.whatwg.org/#dom-url-username) to the empty string, and its
 [`password`](https://url.spec.whatwg.org/#dom-url-password) to `null`.

4. Set `report`'s [url](#report-url) to the result of [stripping URL for use in
 reports](#strip-url-for-use-in-reports), given `url`.

5. Return `report`.

 [reporting
observers](#reporting-observer) can only observe reports from the same [environment
settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object).

 We strip the username, password, and fragment from the
serialized URL in the report. See [§ 8.1 Capability
URLs](#capability-urls).

 The user agent MAY reject reports for any reason. This
API does not guarantee delivery of arbitrary amounts of data, for
instance.

 Non user agent clients (with no JavaScript engine)
should not interact with [reporting
observers](#reporting-observer), and thus should return in step 6.

### 2.4. Serialize Reports

To [serialize a list of `reports` to
JSON],

1. Let `collection` be an empty list.

2. For each `report` in `reports`:

 1. Let `data` be a map with the following key/value
 pairs:

 `age`

 : The number of milliseconds between `report`'s
 [timestamp](#report-timestamp) and the current time.

 `type`

 : `report`'s
 [type](#report-reporttype)

 `url`

 : `report`'s
 [url](#report-url)

 `user_agent`

 : `report`'s [user
 agent](#report-user-agent)

 `body`

 : `report`'s
 [body](#report-body)

 Client clocks are unreliable and subject to
 skew. We therefore deliver an `age` attribute rather than an
 absolute timestamp. See also [§ 9.2 Clock
 Skew](#fingerprinting-clock-skew)

 2. Increment `report`'s
 [attempts](#report-attempts).

 3. Append `data` to `collection`.

3. Return the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence) resulting from executing [serialize an Infra value
 to JSON
 bytes](https://infra.spec.whatwg.org/#serialize-an-infra-value-to-json-bytes) on `collection`.

## 3. Document Centered Reporting

This section defines the mechanism for configuring reporting endpoints
for reports generated by actions in a document (or in a worker script).
Such reports have a lifetime which is tied to that of the document or
worker where they were generated.

### 3.1. Document configuration

Each object implementing
[`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope) has an [endpoints] list, which is a list of
[endpoints](#endpoint), each of
which MUST have a distinct
[`name`](#dom-endpoint-name). (Uniqueness is guaranteed by the algorithm in [§ 3.3
Process reporting endpoints for response](#process-header).)

Each object implementing
[`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope) has an [reports] list, which is a list of [reports](#report).

To [initialize a global's endpoint
list], given a
[`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope) (`scope`) and a
[response](https://fetch.spec.whatwg.org/#concept-response) (`response`), set `scope`'s
[endpoints](#windoworworkerglobalscope-endpoints) to the result of executing [§ 3.3 Process reporting
endpoints for response](#process-header) given `response`.

### 3.2. The `Reporting-Endpoints` HTTP Response Header Field

A server MAY define a set of reporting endpoints for a document or a
worker script resource it returns, via the
[`Reporting-Endpoints`](#reporting-endpoints) HTTP response header field. This mechanism is defined
in [§ 3.2 The Reporting-Endpoints HTTP Response Header Field](#header),
and its processing in [§ 3.3 Process reporting endpoints for
response](#process-header).

The value of the [`Reporting-Endpoints`] HTTP response header field is
used to construct the reporting configuration for a resource.

[`Reporting-Endpoints`](#reporting-endpoints) is a Dictionary Structured Field
[\[STRUCTURED-FIELDS\]](#biblio-structured-fields "Structured Field Values for HTTP").
Each entry in the dictionary defines an
[endpoint](#endpoint) to which
reports may be delivered. The entry value MUST be a string.

Each [endpoint](#endpoint) is
defined by a String Item, which is interpreted as a URI-reference. If
its value is not a valid URI-reference, that
[endpoint](#endpoint) member MUST be
ignored.

Moreover, the URL that the member's value represents MUST be
[potentially
trustworthy](https://w3c.github.io/webappsec-secure-contexts/#is-origin-trustworthy)
[\[SECURE-CONTEXTS\]](#biblio-secure-contexts "Secure Contexts").
Non-secure endpoints will be ignored.

No parameters are defined for [endpoints](#endpoint), and any parameters which are specified will be
silently ignored.

The header is represented by the following ABNF grammar
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"):

``` abnf
Reporting-Endpoints = sf-dictionary
```

Specifications that define Structured Fields or parameters (such as
`report-to`) referencing an endpoint by its
[`name`](#dom-endpoint-name) SHOULD specify that the value is an
[sf-token](https://www.rfc-editor.org/rfc/rfc8941.html#section-3.3.4)
[\[STRUCTURED-FIELDS\]](#biblio-structured-fields "Structured Field Values for HTTP").

Because the Structured Fields ABNF for `member-key` is a subset of the
ABNF for `token`
[\[STRUCTURED-FIELDS\]](#biblio-structured-fields "Structured Field Values for HTTP"),
any endpoint named by a dictionary key in
[`Reporting-Endpoints`](#reporting-endpoints) can be referenced as an
[sf-token](https://www.rfc-editor.org/rfc/rfc8941.html#section-3.3.4).

### 3.3. Process reporting endpoints for `response`

Given a
[response](https://fetch.spec.whatwg.org/#concept-response) (`response`), this algorithm extracts and
returns a list of [endpoints](#endpoint).

1. Abort these steps if `response`'s [HTTPS
 state](https://fetch.spec.whatwg.org/#concept-response-https-state) is not \"`modern`\", and the
 [origin](https://url.spec.whatwg.org/#concept-url-origin) of `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url) is not [potentially
 trustworthy](https://w3c.github.io/webappsec-secure-contexts/#is-origin-trustworthy).

2. Let `parsed header` be the result of executing [get a
 structured field
 value](https://fetch.spec.whatwg.org/#concept-header-list-get-structured-header) given \"Reporting-Endpoints\" and \"dictionary\"
 from `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list).

3. If `parsed header` is null, abort these steps.

4. Let `endpoints` be an empty list.

5. For each `name` → `value_and_parameters` of
 `parsed header`:

 1. Let `endpoint url string` be the first element of the
 tuple `value_and_parameters`. If
 `endpoint url string` is not a string, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. Let `endpoint url` be the result of executing the
 [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) on `endpoint url string`, with [base
 URL](https://url.spec.whatwg.org/#concept-base-url) set to `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url). If `endpoint url`
 is failure, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. If `endpoint url`'s
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#origin) is not [potentially
 trustworthy](https://w3c.github.io/webappsec-secure-contexts/#is-origin-trustworthy), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 4. Let `endpoint` be a new
 [endpoint](#endpoint) whose
 properties are set as follows:

 [`name`](#dom-endpoint-name)

 : `name`

 [`url`](#dom-endpoint-url)

 : `endpoint url`

 [`failures`](#dom-endpoint-failures)

 : 0

 5. Add `endpoint` to `endpoints`.

6. Return `endpoints`.

### 3.4. Report Generation

#### 3.4.1. Generate report of `type` with `data`

When the user agent is to [generate and queue a
report] for a
[`Document`](https://dom.spec.whatwg.org/#document) or
[`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope) object
([`context`]), given a string
([`type`]), a
string
([`destination`]), and a serializable object
([`data`]), it
must run the following steps:

1. Let `settings` be `context`'s [relevant
 settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

2. Let `report` be the result of running [generate a
 report](#generate-a-report) with `data`, `type`,
 `destination` and `settings`.

3. If `settings` is given, then

 1. Let `scope` be `settings`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global).

 2. If `scope` is an object implementing
 [`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope), then execute [§ 4.2 Notify reporting observers
 on scope with report](#notify-observers) with `scope`
 and `report`.

4. Append `report` to `context`'s
 [reports](#windoworworkerglobalscope-reports).

### 3.5. Report Delivery

Over time, various features will queue up a list of
[reports](#windoworworkerglobalscope-reports) in documents and workers. The user agent will
periodically grab the list of currently queued reports, and deliver them
to the associated endpoints. This document does not define a schedule
for the user agent to follow, and assumes that the user agent will have
enough contextual information to deliver reports in a timely manner,
balanced against impacting a user's experience.

That said, a user agent SHOULD make an effort to deliver reports as soon
as possible after queuing, as a report's data might be significantly
more useful in the period directly after its generation than it would be
a day or a week later.

#### 3.5.1. Send reports

A user agent sends a list of
[reports](#windoworworkerglobalscope-reports) (`reports`) for
[`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope) object (`context`) by executing the
following steps:

1. Let `endpoint map` be an empty map of
 [endpoint](#endpoint) objects
 to lists of [report](#report)
 objects.

2. For each `report` in `reports`:

 1. If there exists an [endpoint](#endpoint) (`endpoint`) in
 `context`'s
 [endpoints](#windoworworkerglobalscope-endpoints) list whose
 [`name`](#dom-endpoint-name) is `report`'s
 [destination](#report-destination):

 1. Append `report` to `endpoint map`'s
 list of reports for `endpoint`.

 2. Otherwise, remove `report` from
 `reports`.

3. For each (`endpoint`, `report list`) pair in
 `endpoint map`:

 1. Let `origin map` be an empty map of
 [origins](https://html.spec.whatwg.org/multipage/browsers.html#origin) to lists of [report](#report) objects.

 2. For each `report` in `report list`:

 1. Let `origin` be the
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#origin) of `report`'s
 [url](#report-url).

 2. Append `report` to `origin map`'s list
 of reports for `origin`.

 3. For each (`origin`, `per-origin reports`)
 pair in `origin map`, execute the following steps
 asynchronously:

 1. Let `result` be the result of executing [§ 3.5.2
 Attempt to deliver reports to endpoint](#try-delivery) on
 `endpoint`, `origin`, and
 `per-origin reports`.

 2. If `result` is \"`Failure`\":

 1. Increment `endpoint`'s
 [`failures`](#dom-endpoint-failures).

 3. If `result` is \"`Remove Endpoint`\":

 1. Remove `endpoint` from `context`'s
 [endpoints](#windoworworkerglobalscope-endpoints) list.

 4. Remove each [report](#report) from `reports`.

 (#issue-7f6dd3bd) We don't specify any retry
 mechanism here for failed reports. We may want to add one here,
 or provide some indication that the delivery failed.

 User agents MAY decide to attempt delivery for only a
subset of the collected reports or endpoints (because, for example,
sending all the reports at once would consume an unreasonable amount of
bandwidth, etc). As reports are only removed from the cache after
delivery has been attempted, skipped reports will simply be delivered
later.

#### 3.5.2. Attempt to deliver `reports` to `endpoint`

Given an [endpoint](#endpoint)
(`endpoint`), an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#origin) (`origin`), and a list of
[reports](#windoworworkerglobalscope-reports) (`reports`), this algorithm will construct a
[request](https://fetch.spec.whatwg.org/#concept-request), and attempt to deliver it to `endpoint`. It
returns \"`Success`\" if that delivery succeeds, \"`Remove Endpoint`\"
if the endpoint explicitly removes itself as a reporting endpoint by
sending a 410 response, and \"`Failure`\" otherwise.

1. Let `body` be the result of executing [serialize a list
 of reports to
 JSON](#serialize-a-list-of-reports-to-json) on `reports`.

2. Let `request` be a new
 [request](https://fetch.spec.whatwg.org/#concept-request) with the following properties
 [\[FETCH\]](#biblio-fetch "Fetch Standard"):

 `method`

 : \"`POST`\"

 `url`

 : `endpoint`'s
 [`url`](#dom-endpoint-url)

 `origin`

 : `origin`

 `header list`

 : A new [header
 list](https://fetch.spec.whatwg.org/#concept-header-list) containing a
 [header](https://fetch.spec.whatwg.org/#concept-header) named \``Content-Type`\` whose value is
 \``application/reports+json`\`

 `client`

 : `null`

 `window`

 : \"`no-window`\"

 `service-workers mode`

 : \"`none`\"

 `initiator`

 : \"\"

 `destination`

 : \"`report`\"

 `mode`

 : \"`cors`\"

 `unsafe-request` flag

 : set

 `credentials`

 : \"`same-origin`\"

 `body`

 : A
 [body](https://fetch.spec.whatwg.org/#concept-body) whose
 [source](https://fetch.spec.whatwg.org/#concept-body-source) is `body`.

 Reports are sent with credentials set to
 `same-origin`. This allows reporting endpoints which are same-origin
 with the reporting page to get extra context about the nature of the
 report: for example, to understand whether a given user's account is
 triggering errors consistently, or if a certain sequence of actions
 taken on other pages is triggering a report on this page. This does
 not leak any new information to the reporting endpoint that it could
 not obtain in other ways. That is not the case for cross-origin
 reporting endpoints, so they do not receive credentials.

3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) `request`.

4. [Wait for a
 response](https://fetch.spec.whatwg.org/#wait-for-a-response) (`response`).

5. If `response`'s `status` is an [OK
 status](https://fetch.spec.whatwg.org/#ok-status) (200-299), return \"`Success`\".

6. If `response`'s `status` is `410 Gone`
 [\[RFC9110\]](#biblio-rfc9110 "HTTP Semantics"),
 return \"`Remove Endpoint`\".

7. Return \"`Failure`\".

### 3.6. Strip URL for use in reports

To [strip URL for use in reports] given a
[URL](https://url.spec.whatwg.org/#concept-url)
`url`, perform the following steps. They return a string
representing the URL for use in reports.

1. If `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is not an [HTTP(S)
 scheme](https://fetch.spec.whatwg.org/#http-scheme), then return `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme).

2. Set `url`'s
 [fragment](https://url.spec.whatwg.org/#concept-url-fragment) to the empty string.

3. Set `url`'s
 [username](https://url.spec.whatwg.org/#concept-url-username) to the empty string.

4. Set `url`'s
 [password](https://url.spec.whatwg.org/#concept-url-password) to the empty string.

5. Return the result of executing the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer) on `url`.

## 4. Reporting Observers

A [reporting observer] observes some types of
[reports](#windoworworkerglobalscope-reports) from JavaScript, and is represented in JavaScript by
the
[`ReportingObserver`](#reportingobserver) object.

Each object implementing
[`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope) has a [registered reporting observer
list], which is an [ordered
set](https://infra.spec.whatwg.org/#ordered-set) of [reporting
observers](#reporting-observer).

Any [reporting
observer](#reporting-observer) that is in a [registered reporting observer
list](#windoworworkerglobalscope-registered-reporting-observer-list) is considered [registered].

Each object implementing
[`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope) has a [report
buffer], which
is a [list](https://infra.spec.whatwg.org/#list) of
[reports](#windoworworkerglobalscope-reports) that have been generated in that
[`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope). This list is initially empty, and the reports are
stored in the same order in which they are generated.

 The purpose of the [report
buffer](#windoworworkerglobalscope-report-buffer) is to allow [reporting
observers](#reporting-observer) to observe reports that were generated earlier than
that observer could be created (via the
[`buffered`](#dom-reportingobserveroptions-buffered) option). For example, some reports might be generated
during an earlier stage of page loading than when an observer could
first be created, or before a JavaScript library is loaded that wishes
to observe these reports.

 [Reporting
observers](#reporting-observer) are only relevant for user agents with JavaScript
engines.

### 4.1. Interface [`ReportingObserver`]
```
dictionary ReportBody ;

dictionary Report {
 DOMString type;
 DOMString url;
 ReportBody? body;
};

[Exposed=(Window,Worker)]
interface ReportingObserver {
 constructor(ReportingObserverCallback callback, optional ReportingObserverOptions options = );
 undefined observe();
 undefined disconnect();
 ReportList takeRecords();
};

callback ReportingObserverCallback = undefined (sequence<Report> reports, ReportingObserver observer);

dictionary ReportingObserverOptions {
 sequence<DOMString> types;
 boolean buffered = false;
};

typedef sequence<Report> ReportList;
```

A [`Report`] is the application-exposed
representation of a [report](#report).

[`ReportBody`] is an abstract
[dictionary](https://webidl.spec.whatwg.org/#dfn-dictionary) type from which specific report types should
[inherit](https://webidl.spec.whatwg.org/#dfn-inherit-dictionary).

Each
[`ReportingObserver`](#reportingobserver) object has these associated concepts:

- A [callback] function set
 on creation.

- A
 [`ReportingObserverOptions`](#dictdef-reportingobserveroptions) dictionary called
 [options].

- A list of [`Report`](#dom-report) objects called the [report
 queue], which is initially empty.

A
[`ReportList`](#typedefdef-reportlist) represents a sequence of
[`Report`](#dom-report)s,
providing developers with all the convenience methods found on
JavaScript arrays.

The
[` ReportingObserver(``callback``, ``options``)`]
constructor, when invoked, must run these steps:

1. Create a new
 [`ReportingObserver`](#reportingobserver) object `observer`.

2. Set `observer`'s
 [callback](#reportingobserver-callback) to `callback`.

3. Set `observer`'s
 [options](#reportingobserver-options) to `options`.

4. Return `observer`.

The [`observe()`]
method, when invoked, must run these steps:

1. Let `global` be the be the [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) of
 [this](https://webidl.spec.whatwg.org/#this).

2. Append [this](https://webidl.spec.whatwg.org/#this) to the `global`'s [registered reporting
 observer
 list](#windoworworkerglobalscope-registered-reporting-observer-list).

3. If [this](https://webidl.spec.whatwg.org/#this)'s
 [`buffered`](#dom-reportingobserveroptions-buffered)
 [option](#reportingobserver-options) is false, return.

4. Set [this](https://webidl.spec.whatwg.org/#this)'s
 [`buffered`](#dom-reportingobserveroptions-buffered)
 [option](#reportingobserver-options) to false.

5. For each `report` in `global`'s [report
 buffer](#windoworworkerglobalscope-report-buffer), [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to execute [§ 4.3 Add report to
 observer](#add-report) with `report` and
 [this](https://webidl.spec.whatwg.org/#this).

The [`disconnect()`]
method, when invoked, must run these steps:

1. If [this](https://webidl.spec.whatwg.org/#this) is not
 [registered](#registered),
 return.

2. Let `global` be the [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) of
 [this](https://webidl.spec.whatwg.org/#this).

3. Remove [this](https://webidl.spec.whatwg.org/#this) from `global`'s [registered reporting
 observer
 list](#windoworworkerglobalscope-registered-reporting-observer-list).

The [`takeRecords()`] method, when invoked, must run these steps:

1. Let `reports` be a copy of
 [this](https://webidl.spec.whatwg.org/#this)'s [report
 queue](#reportingobserver-report-queue).

2. Empty [this](https://webidl.spec.whatwg.org/#this)'s [report
 queue](#reportingobserver-report-queue).

3. Return `reports`.

### 4.2. Notify reporting observers on `scope` with `report`

This algorithm makes `report`'s contents available to any
[registered](#registered)
[reporting observers](#reporting-observer) on the provided
[`WindowOrWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope).

1. For each
 [`ReportingObserver`](#reportingobserver) `observer`
 [registered](#registered) with
 `scope`, execute [§ 4.3 Add report to
 observer](#add-report) on `report` and
 `observer`.

2. Append `report` to `scope`'s [report
 buffer](#windoworworkerglobalscope-report-buffer).

3. Let `type` be `report`'s
 [type](#report-reporttype).

4. If `scope`'s [report
 buffer](#windoworworkerglobalscope-report-buffer) now contains more than 100 reports with
 [type](#report-reporttype) equal to `type`, remove the earliest
 item with [type](#report-reporttype) equal to `type` in the [report
 buffer](#windoworworkerglobalscope-report-buffer).

### 4.3. Add `report` to `observer`

Given a [report](#report)
`report` and a
[`ReportingObserver`](#reportingobserver) `observer`, this algorithm adds
`report` to `observer`'s [report
queue](#reportingobserver-report-queue), so long as `report`'s
[type](#report-reporttype)
is observable by `observer`.

1. If `report`'s
 [type](#report-reporttype) is not [visible to
 `ReportingObserver`s](#visible-to-reportingobservers), return.

2. If `observer`'s
 [options](#reportingobserver-options) has a non-empty
 [`types`](#dom-reportingobserveroptions-types) member which does not contain `report`'s
 [type](#report-reporttype), return.

3. Create a new [`Report`](#dom-report) `r` with
 [`type`](#dom-report-type) initialized to `report`'s
 [type](#report-reporttype),
 [`url`](#dom-report-url) initialized to `report`'s
 [url](#report-url), and
 [`body`](#dom-report-body) initialized to `report`'s
 [body](#report-body).

how to polymorphically initialize body?

3. Append `r` to `observer`'s [report
 queue](#reportingobserver-report-queue).

4. If the size of `observer`'s [report
 queue](#reportingobserver-report-queue) is 1:

 1. Let `global` be `observer`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [§ 4.4 Invoke reporting observers with
 notify list](#invoke-observers) with a copy of
 `global`'s [registered reporting observer
 list](#windoworworkerglobalscope-registered-reporting-observer-list).

### 4.4. Invoke reporting observers with `notify list`

This algorithm invokes observer callback functions for reports of
previously observed behavior.

1. For each
 [`ReportingObserver`](#reportingobserver) `observer` in `notify list`:

 1. If `observer`'s [report
 queue](#reportingobserver-report-queue) is empty, then continue.

 2. Let `reports` be a copy of `observer`'s
 [report
 queue](#reportingobserver-report-queue)

 3. Empty `observer`'s [report
 queue](#reportingobserver-report-queue)

 4. [Invoke](https://webidl.spec.whatwg.org/#invoke-a-callback-function) `observer`'s
 [callback](#reportingobserver-callback) with « `reports`,
 `observer` » and \"`report`\", and with
 `observer` as the [callback this
 value](https://webidl.spec.whatwg.org/#dfn-callback-this-value).

## 5. Implementation Considerations

### 5.1. Delivery

The user agent SHOULD attempt to deliver reports as soon as possible to
provide feedback to developers as quickly as possible. However, when
this desire is balanced against the impact on the user, the user wins.
With that in mind, the user agent MAY delay delivery of reports based on
its knowledge of the user's activities and context.

For instance, the user agent SHOULD prioritize the transmission of
reporting data lower than other network traffic. The user's explicit
activities on a website should preempt reporting traffic.

The user agent MAY choose to withhold report delivery entirely until the
user is on a fast, cheap network in order to prevent unnecessary data
cost.

The user agent MAY choose to prioritize reports from particular origins
over others (perhaps those that the user visits most often?)

### 5.2. Garbage Collection

Periodically, the user agent SHOULD walk through the cached
[reports](#report) and
[endpoints](#endpoint), and discard
those that are no longer relevant. These include:

- [endpoints](#endpoint) whose
 [`failures`](#dom-endpoint-failures) exceed some user-agent-defined threshold (\~5 seems
 reasonable)

- [reports](#report) which have not
 been delivered in some arbitrary period of time (perhaps \~2 days?)

For any [reports](#report) that are
discarded, these
[reports](#windoworworkerglobalscope-reports) should also be removed from the [report
buffer](#windoworworkerglobalscope-report-buffer) of any [reporting
observer](#reporting-observer).

## 6. Sample Reports

*This section is non-normative.*

This example shows the format in which reports are sent by the user
agent to the reporting endpoint. The sample submission contains three
reports which have been bundled together and sent in a single HTTP
request. (The report types and bodies themselves are not intended to be
representative of any actual feature, as those are outside of the scope
of this specification).

POST / HTTP/1.1
 Host: example.com
 ...
 Content-Type: application/reports+json

 [{
 "type": "security-violation",
 "age": 10,
 "url": "https://example.com/vulnerable-page/",
 "user_agent": "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0",
 "body": {
 "blocked": "https://evil.com/evil.js",
 "policy": "bad-behavior 'none'",
 "status": 200,
 "referrer": "https://evil.com/"
 }
 }, {
 "type": "certificate-issue",
 "age": 32,
 "url": "https://www.example.com/",
 "user_agent": "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0",
 "body": {
 "date-time": "2014-04-06T13:00:50Z",
 "hostname": "www.example.com",
 "port": 443,
 "effective-expiration-date": "2014-05-01T12:40:50Z",
 "served-certificate-chain": [
 "-----BEGIN CERTIFICATE-----\n
 MIIEBDCCAuygAwIBAgIDAjppMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVT\n
 ...
 HFa9llF7b1cq26KqltyMdMKVvvBulRP/F/A8rLIQjcxz++iPAsbw+zOzlTvjwsto\n
 WHPbqCRiOwY1nQ2pM714A5AuTHhdUDqB1O6gyHA43LL5Z/qHQF1hwFGPa4NrzQU6\n
 yuGnBXj8ytqU0CwIPX4WecigUCAkVDNx\n
 -----END CERTIFICATE-----",
 ...
 ]
 }
 }, {
 "type": "cpu-on-fire",
 "age": 29,
 "url": "https://example.com/thing.js",
 "user_agent": "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0",
 "body": {
 "temperature": 614.0
 }
 }]

## 7. Automation

For the purposes of user-agent automation and application testing, this
document defines a number of [extension
commands](https://w3c.github.io/webdriver/#dfn-extension-command) for the
[\[WebDriver\]](#biblio-webdriver "WebDriver")
specification.

### 7.1. Generate Test Report

The [Generate Test Report] [extension
command](https://w3c.github.io/webdriver/#dfn-extension-command) simulates the generation of a
[report](#report) for the purposes of
testing. This report will be observed by any
[registered](#registered)
[reporting observers](#reporting-observer).

The [extension
command](https://w3c.github.io/webdriver/#dfn-extension-command) is defined as follows:

```
dictionary GenerateTestReportParameters {
 required DOMString message;
 DOMString group = "default";
};
```

HTTP Method

[URI
Template](https://w3c.github.io/webdriver/#dfn-extension-command-uri-template)

`POST`

`/session/{session id}/reporting/generate_test_report`

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) are:

1. If `parameters` is not a JSON
 [Object](https://w3c.github.io/rdf-concepts/spec/#dfn-object), return a [WebDriver
 error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. Let `message` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to get `parameters`'s
 [`message`](#dom-generatetestreportparameters-message) property.

3. If `message` is not present, return a [WebDriver
 error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

4. If the [current browsing
 context](https://w3c.github.io/webdriver/#dfn-current-browsing-context) is no longer open, return a [WebDriver
 error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 window](https://w3c.github.io/webdriver/#dfn-no-such-window).

5. [Handle any user
 prompts](https://w3c.github.io/webdriver/#dfn-handle-any-user-prompts) and return its value if it is a [WebDriver
 error](https://w3c.github.io/webdriver/#dfn-error).

6. Let `group` be `parameters`'s
 [`group`](#dom-generatetestreportparameters-group) property.

7. Let `body` be a new object that can be serialized into a
 [JSON
 text](https://tools.ietf.org/html/rfc8259#section-2), containing a single string field,
 `body_message`.

8. Set `body_message` to `message`.

9. Let `settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) of the [current browsing
 context](https://w3c.github.io/webdriver/#dfn-current-browsing-context)'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

10. Execute [generate and queue a
 report](#generate-and-queue-a-report) with `body`, \"test\",
 `group`, and `settings`.

11. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

## 8. Security Considerations

### 8.1. Capability URLs

Some URLs are valuable in and of themselves. They may contain explicit
credentials in the username and password portion of the URL, or may
grant access to some resource to anyone with knowledge of the URL path.
Additionally, they may contain information which was never intended
leave the user's browser in the URL fragment. See
[\[CAPABILITY-URLS\]](#biblio-capability-urls "Good Practices for Capability URLs")
for more information.

To mitigate the possibility that such URLs will be leaked via this
reporting mechanism, the algorithms here strip out credential
information and fragment data from the URL sent as a
[report](#report)'s originator. It is
still possible, however, for sensitive information in the URL's path to
be leaked this way. Sites which use such URLs may need to operate their
own reporting endpoints.

Additionally, such URLs may be present in a report's
[body](#report-body).
Specifications which extend this API and which include any URLs in a
report's [body](#report-body)
SHOULD require that they be similarly stripped.

## 9. Privacy Considerations

### 9.1. Network Leakage

Because there is a delay between a page being loaded and a report being
generated and sent, it's entirely possible for a report generated while
a user is on one network to be sent while the user is on another
network.

This behaviour is limited to the lifetime of the document which
generated the reports, though, and such a document could be generating
traffic on the new network through other means in any case, even after
the document is closed, through mechanisms such as
`navigator.sendBeacon`.

Consider mitigations. For example, we
could drop reports if we change from one network to another.
[\[WICG/background-sync Issue
#107\]](https://github.com/WICG/background-sync/issues/107)

### 9.2. Clock Skew

Each report is delivered along with an `age` property, rather than the
timestamp at which it was generated. We do this because each user's
local clock will be skewed from the clock on the server by an arbitrary
amount. The difference between the time the report was generated and the
time it was sent will be stable, regardless of clock skew, and we can
avoid the fingerprinting risk of exposing the clock skew via this API.

### 9.3. Cross-origin correlation

If multiple origins all use the same reporting endpoint, that endpoint
may learn that a particular user has interacted with a certain set of
websites, as it will receive origin-tagged reports from each. This
doesn't seem worse than the status quo ability to track the same
information from cooperative origins, and doesn't grant any new tracking
ability above and beyond what's possible with `<img>` today.

### 9.4. Disabling Reporting

Reporting is, to some extent, a question of commons. In the aggregate,
it seems useful for everyone for reports to be delivered. There is
direct benefit to developers, as they can fix bugs, which means there's
indirect benefit to users, as the sites they enjoy will be more stable
and enjoyable. As a concrete example, Content Security Policy grants
something like herd immunity to cross-site scripting attacks by alerting
developers about potential holes in their sites\' defenses. Fixing those
bugs helps every user, even those whose user agents don't support
Content Security Policy.

The calculus, of course, depends on the nature of data that's being
delivered, and the relative maliciousness of the reporting endpoints,
but that's the value proposition in broad strokes.

That said, it can't be the case that this general benefit be allowed to
take priority over the ability of a user to individually opt-out of such
a system. Sending reports costs bandwidth, and potentially could reveal
some small amount of additional information above and beyond what a
website can obtain in-band
([\[NETWORK-ERROR-LOGGING\]](#biblio-network-error-logging "Network Error Logging"),
for instance). User agents MUST allow users to disable reporting with
some reasonable amount of granularity in order to maintain the priority
of constituencies espoused in
[\[HTML-DESIGN-PRINCIPLES\]](#biblio-html-design-principles "HTML Design Principles").

## 10. IANA Considerations

### 10.1. The `Reporting-Endpoints` Header

The permanent message header field registry should be updated with the
following registration:
[\[RFC3864\]](#biblio-rfc3864 "Registration Procedures for Message Header Fields")

Header field name

: `Reporting-Endpoints`

Applicable protocol

: http

Status

: standard

Author/Change controller

: W3C

Specification document

: This specification (see [§ 3.2 The Reporting-Endpoints HTTP Response
 Header Field](#header))

### 10.2. The `application/reports+json` Media Type

Type name

: application

Subtype name

: reports+json

Required parameters

: N/A

Optional parameters

: N/A

Encoding considerations

: Encoding considerations are identical to those specified for the
 \"application/json\" media type. See
 [\[RFC8259\]](#biblio-rfc8259 "The JavaScript Object Notation (JSON) Data Interchange Format").

Security considerations

: See [§ 8 Security Considerations](#security).

Interoperability considerations

: This document specifies the format of conforming messages and the
 interpretation thereof.

Published specification

: [§ 2.2 Media Type](#media-type)

Applications that use this media type\
Fragment identifier considerations\
Additional information

: N/A

Person and email address to contact for further information

: This document's editors.

Intended usage:

: COMMON

Restrictions on usage:

: N/A

Author

: This document's editors.

Change controller

: W3C

Provisional registration?

: Yes.
