
## 1. Introduction

*This section is non-normative.*

Accurately measuring performance characteristics of web applications is
an important aspect of making web applications faster.
[\[NAVIGATION-TIMING\]](#biblio-navigation-timing "Navigation Timing")
and
[\[RESOURCE-TIMING\]](#biblio-resource-timing "Resource Timing")
provide detailed request timing information for the document and its
resources, which include time when the request was initiated, and
various milestones to negotiate the connection and receive the response.
However, while the user agent can observe the timing data of the request
it has no insight into how or why certain stages of the request-response
cycle have taken as much time as they have - e.g., how the request was
routed, where the time was spent on the server, and so on.

This specification introduces
[`PerformanceServerTiming`](#performanceservertiming) interface, which enables the server to communicate
performance metrics about the request-response cycle to the user agent,
and a JavaScript interface to enable applications to collect, process,
and act on these metrics to optimize application delivery.

## 2. The `Server-Timing` Header Field

The [Server-Timing header field] is used to communicate one or
more metrics and descriptions for the given request-response cycle. The
ABNF (Augmented Backus-Naur Form)
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF")
syntax for the [Server-Timing header
field](#server-timing-header-field) is as follows:

 Server-Timing = #server-timing-metric
 server-timing-metric = metric-name *( OWS ";" OWS server-timing-param )
 metric-name = token
 server-timing-param = server-timing-param-name OWS "=" OWS server-timing-param-value
 server-timing-param-name = token
 server-timing-param-value = token / quoted-string

See
[\[RFC7230\]](#biblio-rfc7230 "Hypertext Transfer Protocol (HTTP/1.1): Message Syntax and Routing"){biblio-obsolete=""
} for definitions of `#`, `*`, `OWS`, `token`, and
`quoted-string`.

A response MAY have multiple server-timing-metric entries with the same
metric-name, and the user agent MUST process and expose all such
entries.

The user agent MAY surface provided metrics in any order - i.e. the
order of metrics in the HTTP header field is not significant.

This header field is defined with an extensible syntax to allow for
future parameters. A user agent that does not recognize particular
server-timing-param-name in the Server-Timing header field of a response
MUST ignore those tokens and continue processing instead of signaling an
error.

To avoid any possible ambiguity, individual `server-timing-param-name`s
SHOULD NOT appear multiple times within a `server-timing-metric`. If any
`server-timing-param-name` is specified more than once, only the first
instance is to be considered, even if the `server-timing-param` is
incomplete or invalid. All subsequent occurrences MUST be ignored
without signaling an error or otherwise altering the processing of the
`server-timing-metric`. This is the only case in which the ordering of
parameters within a `server-timing-metric` is considered to be
significant.

User agents MUST ignore extraneous characters found after a
`server-timing-param-value` but before the next `server-timing-param`
and before the end of the current `server-timing-metric`.

User agents MUST ignore extraneous characters found after a
`metric-name` but before the first `server-timing-param` and before the
next `server-timing-metric`.

This specification establishes the server-timing-params for
server-timing-param-names \"dur\" for
[`duration`](#dom-performanceservertiming-duration) and \"desc\" for
[`description`](#dom-performanceservertiming-description), both optional.

- [To minimize the HTTP overhead the provided names and descriptions
 should be kept as short as possible - e.g. use abbreviations and omit
 optional values where possible.]
- Because there can be no guarantee of clock synchronization between
 client, server, and intermediaries, it is impossible to map a
 meaningful `startTime` onto the clients timeline. For that reason, any
 `startTime` attribution is purposely omitted from this specification.
 If the developers want to establish a relationship between multiple
 entries, they can do so by communicating custom data via metric names
 and/or descriptions.
- [The server and/or any relevant intermediaries are in full control of
 which metrics are communicated to the user agent and when. For
 example, access to some metrics may be restricted due to privacy or
 security reasons - see [§ 4 Privacy and
 Security](#privacy-and-security) section.]

To [parse a server-timing header
field] given a string `field`:

1. Let `position` be a [position
 variable](https://infra.spec.whatwg.org/#string-position-variable), initially pointing at the start of
 `field`.

2. Let `name` be the result of [collecting a sequence of
 code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) from `field` that are not equal to
 U+003B (;), given `position`.

3. [Strip leading and trailing ASCII
 whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace) from `name`.

4. If `name` is an empty string, return null.

5. Let `metric` be a new
 [`PerformanceServerTiming`](#performanceservertiming) whose [metric
 name](#performanceservertiming-metric-name) is `name`.

6. Let `params` be an empty [ordered
 map](https://infra.spec.whatwg.org/#ordered-map).

7. While `position` is not at the end of `field`:

 1. Advance `position` by 1.

 2. Let `paramName` be the result of [collecting a
 sequence of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) from `field` that are not equal to
 U+003D (=), given `position`.

 3. [Strip leading and trailing ASCII
 whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace) from `paramName`.

 4. If `paramName` is an empty string or
 `params`\[`paramName`\]
 [exists](https://infra.spec.whatwg.org/#map-exists),
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 5. Advance `position` by 1.

 6. Let `paramValue` be an empty string.

 7. [Skip ASCII
 whitespace](https://infra.spec.whatwg.org/#skip-ascii-whitespace) within `field` given
 `position`.

 8. If the [code
 point](https://infra.spec.whatwg.org/#code-point) at `position` within
 `field` is U+0022 (\"), then:

 1. Set `paramValue` to the result of [collecting an
 HTTP quoted
 string](https://fetch.spec.whatwg.org/#collect-an-http-quoted-string) from `field` given
 `position` with the *extract-value flag* set.

 2. [Collect a sequence of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) from `field` that are not equal
 to U+003B (;), given `position`. The result is
 not used.

 9. Otherwise:

 1. Let `rawParamValue` be the result of [collecting
 a sequence of code
 points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) from `field` that are not equal
 to U+003B (;), given `position`.

 2. Let `paramValue` be the result of
 [stripping](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace) `rawParamValue`.

8. [Set](https://infra.spec.whatwg.org/#map-set) `metric`'s
 [params](#performanceservertiming-params) to `params`.

9. Return `metric`.

## 3. The [`PerformanceServerTiming` Interface]
```
[Exposed=(Window,Worker)]
interface PerformanceServerTiming {
 readonly attribute DOMString name;
 readonly attribute DOMHighResTimeStamp duration;
 readonly attribute DOMString description;
 [Default] object toJSON();
};
```

When [toJSON] is called,
run
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard")'s
[default toJSON
steps](https://webidl.spec.whatwg.org/#default-tojson-steps).

### [3.1. ][[`name`] attribute]
The
[`name`](#dom-performanceservertiming-name) getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [metric
name](#performanceservertiming-metric-name).

### [3.2. ][[`duration`] attribute]
The
[`duration`](#dom-performanceservertiming-duration) getter steps are to do the following:

1. If [this](https://webidl.spec.whatwg.org/#this)'s
 [params](#performanceservertiming-params)\[`"dur"`\] does not
 [exist](https://infra.spec.whatwg.org/#map-exists), return 0.

2. Let `dur` be the result of parsing
 [this](https://webidl.spec.whatwg.org/#this)'s
 [params](#performanceservertiming-params)\[`"dur"`\] using the [rules for parsing
 floating-point number
 values](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-floating-point-number-values).

3. If `dur` is an error, return 0; Otherwise return
 `dur`.

Since
[`duration`](#dom-performanceservertiming-duration) is a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp), it usually represents a
[duration](https://w3c.github.io/hr-time/#dfn-duration) in milliseconds. Since this is not enforceable in
practice,
[`duration`](#dom-performanceservertiming-duration) can represent any unit of time, and having it represent
a
[duration](https://w3c.github.io/hr-time/#dfn-duration) in milliseconds is a recommendation.

### [3.3. ][[`description`] attribute]
The
[`description`](#dom-performanceservertiming-description) getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s
[params](#performanceservertiming-params)\[`"desc"`\] if it
[exists](https://infra.spec.whatwg.org/#map-exists), otherwise the empty string.

A
[`PerformanceServerTiming`](#performanceservertiming) has an associated string [metric
name], initially
set to the empty string.

A
[`PerformanceServerTiming`](#performanceservertiming) has an associated [ordered
map](https://infra.spec.whatwg.org/#ordered-map) [params], initially empty.

### [3.4. ][Extension to the [`PerformanceResourceTiming`](https://w3c.github.io/resource-timing/#performanceresourcetiming) interface]
The
[`PerformanceResourceTiming`](https://w3c.github.io/resource-timing/#performanceresourcetiming) interface, which this specification partially extends,
is defined in
[\[RESOURCE-TIMING\]](#biblio-resource-timing "Resource Timing").

```
[Exposed=(Window,Worker)]
partial interface PerformanceResourceTiming {
 readonly attribute FrozenArray<PerformanceServerTiming> serverTiming;
};
```

### 3.5. `serverTiming` attribute

The [`serverTiming`] getter steps are the following:

1. Let `entries` be a new
 [list](https://infra.spec.whatwg.org/#list).

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `field` in
 [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](https://fetch.spec.whatwg.org/#fetch-timing-info)'s [server-timing
 headers](https://fetch.spec.whatwg.org/#fetch-timing-info-server-timing-headers):

 1. Let `metric` be the result of
 [parsing](#parse-a-server-timing-header-field) `field`.

 2. If `metric` is not null,
 [append](https://infra.spec.whatwg.org/#list-append) `metric` to `entries`.

3. Return `entries`.

## 4. Privacy and Security

*This section is non-normative.*

[The interfaces defined in this specification expose potentially
sensitive application and infrastructure information to any web page
that has included a resource that advertises server timing metrics. For
this reason the access to `PerformanceServerTiming` interface is
restricted by the [same
origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) policy by default. Resource providers can explicitly
allow server timing information to be available by adding the
`Timing-Allow-Origin` HTTP response header, as defined in
[\[RESOURCE-TIMING\]](#biblio-resource-timing "Resource Timing"),
that specifies the domains that may be allowed to access the server
metrics, but the user agent MAY keep the [same
origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) policy restriction.]

[In addition to using the `Timing-Allow-Origin` HTTP response header,
the server can also use relevant logic to control which metrics are
returned, when, and to whom - e.g. the server may only provide certain
metrics to correctly authenticated users and nothing at all to all
others.]

## 5. IANA Considerations

The permanent message header field registry should be updated with the
following registrations
([\[RFC3864\]](#biblio-rfc3864 "Registration Procedures for Message Header Fields")):

### 5.1. Server-Timing Header Field

Header field name
: Server-Timing

Applicable protocol
: http

Status
: standard

Author/Change controller
: W3C

Specification document
: This specification (See [Server-Timing Header
 Field](#server-timing-header-field))

## 6. Examples

*This section is non-normative.*

```
> GET /resource HTTP/1.1
> Host: example.com

< HTTP/1.1 200 OK
< Server-Timing: miss, db;dur=53, app;dur=47.2
< Server-Timing: customView, dc;desc=atl
< Server-Timing: cache;desc="Cache Read";dur=23.2
< Trailer: Server-Timing
< (... snip response body ...)
< Server-Timing: total;dur=123.4
```

Name

Duration

Description

miss

db

53

app

47.2

customView

dc

atl

cache

23.2

Cache Read

total

123.4

[The above header fields communicate six distinct metrics that
illustrate all the possible ways for the server to communicate data to
the user agent: metric name only, metric with value, metric with value
and description, and metric with description. For example, the above
metrics may indicate that for `example.com/resource.jpg`
fetch:]

1. There was a cache miss.
2. The request was routed through the \"atl\" datacenter (\"dc\").
3. The database (\"db\") time was 53 ms.
4. A cache read took 23.2 ms.
5. The application server (\"app\") took 47.2ms to process
 \"customView\" template or function.
6. The total time for the request-response cycle on the server was
 123.4ms, which is recorded at the end of the response and delivered
 via a trailer field.

The application can collect, process, and act on the provided metrics
via the provided JavaScript interface:

```
// serverTiming entries can live on 'navigation' and 'resource' entries
for (const entryType of ['navigation', 'resource']) {
 for (const {name: url, serverTiming} of performance.getEntriesByType(entryType)) {
 // iterate over the serverTiming array
 for (const {name, duration, description} of serverTiming) {
 // we only care about "slow" ones
 if (duration > 200) {
 console.info('Slow server-timing entry =',
 JSON.stringify({url, entryType, name, duration, description}, null, 2))
 }
 }
 }
}
```

## 7. Use cases

*This section is non-normative.*

### 7.1. Server timing in developer tools

[Server processing time can be a significant fraction of the total
request time. For example, a dynamic response may require one or more
database queries, cache lookups, API calls, time to process relevant
data and render the response, and so on. Similarly, even a static
response can be delayed due to overloaded servers, slow caches, or other
reasons.]

[Today, the user agent developer tools are able to show when the request
was initiated, and when the first and last bytes of the response were
received. However, there is no visibility into where or how the time was
spent on the server, which means that the developer is unable to quickly
diagnose if there is a performance bottleneck on the server, and if so,
in which component. Today, to answer this question, the developer is
required to use different techniques: check the server logs, embed
performance data within the response (if possible), use external tools,
and so on. This makes identifying and diagnosing performance bottlenecks
hard, and in many cases impractical.]

Server Timing defines a standard mechanism that enables the server to
communicate relevant performance metrics to the client and allows the
client to surface them directly in the developer tools - e.g. the
requests can be annotated with server sent metrics to provide insight
into where or how the time was spent while generating the response.

### 7.2. Server timing for automated analytics

In addition to surfacing server sent performance metrics in the
developer tools, a standard JavaScript interface enables analytics tools
to automatically collect, process, beacon, and aggregate these metrics
for operational and performance analysis.

### 7.3. Measuring request routing performance

[Server Timing enables origin servers to communicate performance metrics
about where or how time is spent while processing the request. However,
the same request and response may also be routed through one or more
multiple proxies (e.g. cache servers, load balancers, and so on), each
of which may introduce own delays and may want to provide performance
metrics into where or how the time is spent.]

[For example, a CDN edge node may want to report which data center was
being used, if the resource was available in cache, and how long it took
to retrieve the response from cache or from the origin server. Further,
the same process may be repeated by other proxies, thus allowing full
end-to-end visibility into how the request was routed and where the time
was spent.]

[Similarly, when a Service Worker is active, some or all of the
navigation and resource requests may be routed through it. Effectively,
an active Service Worker is a local proxy that is able to reroute
requests, serve cached responses, synthesize responses, and more. As a
result, Server Timing enables Service Worker to report custom
performance metrics about how the request was processed: whether it was
fetched from a server or served from local cache, duration of relevant
the processing steps, and so on.]

## 8. Acknowledgments

*This section is non-normative.*

This document reuses text from the
[\[NAVIGATION-TIMING\]](#biblio-navigation-timing "Navigation Timing"),
[\[RESOURCE-TIMING\]](#biblio-resource-timing "Resource Timing"),
[\[PERFORMANCE-TIMELINE-2\]](#biblio-performance-timeline-2 "Performance Timeline"),
and
[\[RFC6797\]](#biblio-rfc6797 "HTTP Strict Transport Security (HSTS)")
specifications as permitted by the licenses of those specifications.
