
## 1. Introduction

User latency is an important quality benchmark for Web Applications.
While JavaScript-based mechanisms can provide comprehensive
instrumentation for user latency measurements within an application, in
many cases, they are unable to provide a complete end-to-end latency
picture. This document introduces the
[`PerformanceResourceTiming`](#performanceresourcetiming) interface to allow JavaScript mechanisms to collect
complete timing information related to resources on a document.
Navigation Timing 2
[\[NAVIGATION-TIMING-2\]](#biblio-navigation-timing-2 "Navigation Timing Level 2")
extends this specification to provide additional timing information
associated with a navigation.

For example, the following JavaScript shows a simple attempt to measure
the time it takes to fetch a resource:

```
<!doctype html>
<html>
 <head>
 </head>
 <body onload="loadResources()">
 <script>
 function loadResources()
 {
 var start = new Date().getTime();
 var image1 = new Image();
 var resourceTiming = function() {
 var now = new Date().getTime();
 var latency = now - start;
 alert("End to end resource fetch: " + latency);
 };

 image1.onload = resourceTiming;
 image1.src = 'https://www.w3.org/Icons/w3c_main.png';
 }
 </script>
 <img src="https://www.w3.org/Icons/w3c_home.png">
 </body>
</html>
```

Though this script can measure the time it takes to fetch a resource, it
cannot break down the time spent in various phases. Further, the script
cannot easily measure the time it takes to fetch resources described in
markup.

To address the need for complete information on user experience, this
document introduces the
[`PerformanceResourceTiming`](#performanceresourcetiming) interface. This interface allows JavaScript mechanisms
to provide complete client-side latency measurements within
applications. With this interface, the previous example can be modified
to measure a user's perceived load time of a resource.

The following script calculates the amount of time it takes to fetch
every resource in the page, even those defined in markup. This example
assumes that this page is hosted on https://www.w3.org. One could
further measure the amount of time it takes in every phase of fetching a
resource with the
[`PerformanceResourceTiming`](#performanceresourcetiming) interface.

```
<!doctype html>
<html>
 <head>
 </head>
 <body onload="loadResources()">
 <script>
 function loadResources()
 {
 var image1 = new Image();
 image1.onload = resourceTiming;
 image1.src = 'https://www.w3.org/Icons/w3c_main.png';
 }

 function resourceTiming()
 {
 var resourceList = window.performance.getEntriesByType("resource");
 for (i = 0; i < resourceList.length; i++)
 {
 if (resourceList[i].initiatorType == "img")
 {
 alert("End to end resource fetch: " + (resourceList[i].responseEnd - resourceList[i].startTime));
 }
 }
 }
 </script>
 <img id="image0" src="https://www.w3.org/Icons/w3c_home.png">
 </body>
</html>
```

## 2. Terminology

The construction \"a `Foo` object\", where `Foo` is actually an
interface, is sometimes used instead of the more accurate \"an object
implementing the interface `Foo`.

Throughout this work, all time values are measured in milliseconds since
the start of navigation of the document
[\[HR-TIME\]](#biblio-hr-time "High Resolution Time").
For example, the [start of navigation of the
document](https://www.w3.org/TR/navigation-timing-2/#performanceentry)
occurs at time 0.

This definition of time is based on the High Resolution Time
specification
[\[HR-TIME\]](#biblio-hr-time "High Resolution Time")
and is different from the definition of time used in the Navigation
Timing specification
[\[NAVIGATION-TIMING-2\]](#biblio-navigation-timing-2 "Navigation Timing Level 2"),
where time is measured in milliseconds since midnight of January 1, 1970
(UTC).

## 3. Resource Timing

### 3.1. Introduction

The
[`PerformanceResourceTiming`](#performanceresourcetiming) interface facilitates timing measurement of
[fetched](https://fetch.spec.whatwg.org/#concept-fetch)
[http(s)](https://fetch.spec.whatwg.org/#http-scheme) resources. For example, this interface is available for
[`XMLHttpRequest`](https://xhr.spec.whatwg.org/#xmlhttprequest) objects
[\[XHR\]](#biblio-xhr "XMLHttpRequest Standard"),
HTML elements
[\[HTML\]](#biblio-html "HTML Standard") such as
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element),
[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element),
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script),
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element),
[`embed`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-embed-element) and
[`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element) with the link type of
[stylesheet](https://html.spec.whatwg.org/multipage/semantics.html#link-type-stylesheet),
SVG elements
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)")
such as [svg](https://www.w3.org/TR/SVG11/struct.html#SVGElement), and
[`EventSource`](https://html.spec.whatwg.org/multipage/server-sent-events.html#eventsource).

### 3.2. Resources Included in the [`PerformanceResourceTiming` Interface ]
This section is non-normative.

Resource
[Request](https://fetch.spec.whatwg.org/#concept-request)s
[fetch](https://fetch.spec.whatwg.org/#concept-fetch)ed by a non-null
[client](https://fetch.spec.whatwg.org/#concept-request-client) are included as
[`PerformanceResourceTiming`](#performanceresourcetiming) objects in the
[client](https://fetch.spec.whatwg.org/#concept-request-client)'s [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global)'s [Performance
Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline), unless excluded from the timeline as part of the
[fetching
process](https://fetch.spec.whatwg.org/#concept-fetch). Resources that are retrieved from HTTP cache are
included as
[`PerformanceResourceTiming`](#performanceresourcetiming) objects in the [Performance
Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline). Resources for which the
[fetch](https://fetch.spec.whatwg.org/#concept-fetch) was initiated, but was later aborted (e.g. due to a
network error) are included as
[`PerformanceResourceTiming`](#performanceresourcetiming) objects in the [Performance
Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline), with their start and end timing.

Examples:

- If the same canonical URL is used as the `src` attribute of two HTML
 `IMG` elements, the
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) of the resource initiated by the first HTML `IMG`
 element would be included as a
 [`PerformanceResourceTiming`](#performanceresourcetiming) object in the [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline). The user agent might not re-request the URL for the
 second HTML `IMG` element, instead using the existing download it
 initiated for the first HTML `IMG` element. In this case, the
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) of the resource by the first `IMG` element would be
 the only occurrence in the [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline).
- If the `src` attribute of a HTML `IMG` element is changed via script,
 both the
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) of the original resource as well as the
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) of the new URL would be included as
 [`PerformanceResourceTiming`](#performanceresourcetiming) objects in the [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline).
- If an HTML `IFRAME` element is added via markup without specifying a
 `src` attribute, the user agent may load the `about:blank` document
 for the `IFRAME`. If at a later time the `src` attribute is changed
 dynamically via script, the user agent may
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) the new URL resource for the `IFRAME`. In this case,
 only the
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) of the new URL would be included as a
 [`PerformanceResourceTiming`](#performanceresourcetiming) object in the [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline).
- If an `XMLHttpRequest` is generated twice for the same canonical URL,
 both
 [fetches](https://fetch.spec.whatwg.org/#concept-fetch) of the resource would be included as a
 [`PerformanceResourceTiming`](#performanceresourcetiming) object in the [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline). This is because the
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) of the resource for the second `XMLHttpRequest`
 cannot reuse the download issued for the first `XMLHttpRequest`.
- If an HTML `IFRAME` element is included on the page, then only the
 resource requested by `IFRAME` `src` attribute is included as a
 [`PerformanceResourceTiming`](#performanceresourcetiming) object in the [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline). Sub-resources requested by the `IFRAME` document
 will be included in the `IFRAME` document's [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline) and not the parent document's [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline).
- If an HTML `IMG` element has a
 [`data: URI`](https://tools.ietf.org/html/rfc2397) as its source
 [\[RFC2397\]](#biblio-rfc2397 "The "data" URL scheme"),
 then this resource will not be included as a
 [`PerformanceResourceTiming`](#performanceresourcetiming) object in the [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline).
 [`PerformanceResourceTiming`](#performanceresourcetiming) entries are only reported for
 [http(s)](https://fetch.spec.whatwg.org/#http-scheme) resources.
- If a resource
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) was aborted due to a networking error (e.g. DNS, TCP,
 or TLS error), then the fetch will be included as a
 [`PerformanceResourceTiming`](#performanceresourcetiming) object in the [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline) with only the `startTime`, `fetchStart`, `duration`
 and `responseEnd` set.
- If a resource
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) is aborted because it failed a fetch precondition
 (e.g. mixed content, CORS restriction, CSP policy, etc), then this
 resource will not be included as a
 [`PerformanceResourceTiming`](#performanceresourcetiming) object in the [Performance
 Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline).

### 3.3. The PerformanceResourceTiming Interface

```
[Exposed=(Window,Worker)]
interface PerformanceResourceTiming : PerformanceEntry {
 readonly attribute DOMString initiatorType;
 readonly attribute DOMString deliveryType;
 readonly attribute ByteString nextHopProtocol;
 readonly attribute DOMHighResTimeStamp workerStart;
 readonly attribute DOMHighResTimeStamp redirectStart;
 readonly attribute DOMHighResTimeStamp redirectEnd;
 readonly attribute DOMHighResTimeStamp fetchStart;
 readonly attribute DOMHighResTimeStamp domainLookupStart;
 readonly attribute DOMHighResTimeStamp domainLookupEnd;
 readonly attribute DOMHighResTimeStamp connectStart;
 readonly attribute DOMHighResTimeStamp connectEnd;
 readonly attribute DOMHighResTimeStamp secureConnectionStart;
 readonly attribute DOMHighResTimeStamp requestStart;
 readonly attribute DOMHighResTimeStamp finalResponseHeadersStart;
 readonly attribute DOMHighResTimeStamp firstInterimResponseStart;
 readonly attribute DOMHighResTimeStamp responseStart;
 readonly attribute DOMHighResTimeStamp responseEnd;
 readonly attribute DOMHighResTimeStamp workerRouterEvaluationStart;
 readonly attribute DOMHighResTimeStamp workerCacheLookupStart;
 readonly attribute DOMString workerMatchedRouterSource;
 readonly attribute DOMString workerFinalRouterSource;
 readonly attribute unsigned long long transferSize;
 readonly attribute unsigned long long encodedBodySize;
 readonly attribute unsigned long long decodedBodySize;
 readonly attribute unsigned short responseStatus;
 readonly attribute RenderBlockingStatusType renderBlockingStatus;
 readonly attribute DOMString contentType;
 readonly attribute DOMString contentEncoding;
 [Default] object toJSON();
};
```

A
[`PerformanceResourceTiming`](#performanceresourcetiming) has an associated DOMString [initiator
type].

A
[`PerformanceResourceTiming`](#performanceresourcetiming) has an associated DOMString [delivery
type].

A
[`PerformanceResourceTiming`](#performanceresourcetiming) has an associated DOMString [requested
URL].

A
[`PerformanceResourceTiming`](#performanceresourcetiming) has an associated DOMString [cache
mode] (the
empty string, \"`local`\", or \"`validated`\").

A
[`PerformanceResourceTiming`](#performanceresourcetiming) has an associated [fetch timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info) [timing info].

A
[`PerformanceResourceTiming`](#performanceresourcetiming) has an associated [response body
info](https://fetch.spec.whatwg.org/#response-body-info) [resource
info].

A
[`PerformanceResourceTiming`](#performanceresourcetiming) has an associated
[status](https://fetch.spec.whatwg.org/#concept-status) [response
status].

A
[`PerformanceResourceTiming`](#performanceresourcetiming) has an associated
[`RenderBlockingStatusType`](#enumdef-renderblockingstatustype) [render-blocking
status].

When [toJSON] is called,
run the [default toJSON
steps](https://webidl.spec.whatwg.org/#default-tojson-steps) for
[`PerformanceResourceTiming`](#performanceresourcetiming).

[`initiatorType`] getter steps are to return the
[initiator
type](#performanceresourcetiming-initiator-type) for
[this](https://webidl.spec.whatwg.org/#this).

`initiatorType` returns one of the following values:

- `"navigation"`, if the request is a [navigation
 request](https://fetch.spec.whatwg.org/#navigation-request);

- `"body"`, if the request is a result of processing the
 [`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element's `background` attribute that's already
 obsolete.

- `"css"`, if the request is a result of processing a CSS
 [url()](https://www.w3.org/TR/css-values-4/#funcdef-url) directive
 such as `@import url()` or `background: url()`;
 [\[CSS-VALUES\]](#biblio-css-values "CSS Values and Units Module Level 4")

 Note: the request for a font resource specified with `@font-face` in
 CSS is a result of processing a CSS directive. Therefore, the
 `initiatorType` for this font resource is `"css"`.

- `"script"`, if the request is a result of loading any
 [script](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script)
 (a classic
 [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script), a [module
 script](https://html.spec.whatwg.org/multipage/webappapis.html#module-script), or a
 [`Worker`](https://html.spec.whatwg.org/multipage/workers.html#worker)).

- `"xmlhttprequest"`, if the request is a result of processing an
 [`XMLHttpRequest`](https://xhr.spec.whatwg.org/#xmlhttprequest);

- `"font"`, if the request is the result of processing fonts. This can
 happen when fonts request subsequent resources, e.g, when Incremental
 Font Transfer
 [\[INCREMENTAL_FONT_TRANSFER\]](#biblio-incremental_font_transfer "Incremental Font Transfer")
 is used.

- `"fetch"`, if the request is the result of processing the
 [`fetch()`](https://fetch.spec.whatwg.org/#dom-global-fetch) method;

- `"beacon"`, if the request is the result of processing the
 [`sendBeacon()`](https://www.w3.org/TR/beacon/#dom-navigator-sendbeacon) method;
 [\[BEACON\]](#biblio-beacon "Beacon")

- `"video"`, if the request is the result of processing the
 [`video`](https://html.spec.whatwg.org/multipage/media.html#video) element's
 [`poster`](https://html.spec.whatwg.org/multipage/media.html#attr-video-poster) or
 [`src`](https://html.spec.whatwg.org/multipage/media.html#attr-media-src).

- `"audio"`, if the request is the result of processing the
 [`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) element's
 [`src`](https://html.spec.whatwg.org/multipage/media.html#attr-media-src).

- `"track"`, if the request is the result of processing the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#the-track-element) element's
 [`src`](https://html.spec.whatwg.org/multipage/media.html#attr-track-src).

- `"img"`, if the request is the result of processing the
 [`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) element's
 [`src`](https://html.spec.whatwg.org/multipage/embedded-content.html#attr-img-src) or
 [`srcset`](https://html.spec.whatwg.org/multipage/embedded-content.html#attr-img-srcset).

- `"image"`, if the request is the result of processing the
 [image](https://www.w3.org/TR/SVG2/embedded.html#ImageElement)
 element.
 [\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2")

- `"input"`, if the request is the result of processing an
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) element of
 [`type`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type)
 [image](https://html.spec.whatwg.org/multipage/input.html#image-button-state-(type=image)).

- `"ping"`, if the request is the result of processing an
 [`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) element's
 [`ping`](https://html.spec.whatwg.org/multipage/links.html#ping).

- `"iframe"`, if the request is the result of processing an
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)'s
 [`src`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-src).

- `"frame"`, if the request is the result of loading a
 [`frame`](https://html.spec.whatwg.org/multipage/obsolete.html#frame).

- `"embed"`, if the request is the result of processing an
 [`embed`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-embed-element) element's
 [`src`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-embed-src).

- `"link"`, if the request is the result of processing an
 [`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element) element.

- `"object"`, if the request is the result of processing an
 [`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element) element.

- `"early-hints"`, if the request is the result of processing an Early
 Hints
 [\[EARLY_HINTS\]](#biblio-early_hints "Early hints")
 response.

- `"other"`, if none of the above conditions match.

The setting of `initiatorType` is done at the different places where a
resource timing entry is reported, such as the
[fetch](https://fetch.spec.whatwg.org/#concept-fetch) standard.

[`deliveryType`] getter steps are to return the [delivery
type](#performanceresourcetiming-delivery-type) for
[this](https://webidl.spec.whatwg.org/#this).

`deliveryType` returns one of the following values:

- `"cache"`, if the [cache
 mode](#performanceresourcetiming-cache-mode) is not the empty string.
- the empty string `""`, if none of the above conditions match.

This is expected to be expanded by future updates to this specification,
e.g. to describe consuming preloaded resources and prefetched navigation
requests.

The [`workerStart`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [final service worker start
time](https://fetch.spec.whatwg.org/#fetch-timing-info-final-service-worker-start-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [HTTP
fetch](https://fetch.spec.whatwg.org/#concept-http-fetch) for more info.

The [`redirectStart`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [redirect start
time](https://fetch.spec.whatwg.org/#fetch-timing-info-redirect-start-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [HTTP-redirect
fetch](https://fetch.spec.whatwg.org/#concept-http-redirect-fetch) for more info.

The [`redirectEnd`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [redirect end
time](https://fetch.spec.whatwg.org/#fetch-timing-info-redirect-end-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [HTTP-redirect
fetch](https://fetch.spec.whatwg.org/#concept-http-redirect-fetch) for more info.

The [`fetchStart`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [post-redirect start
time](https://fetch.spec.whatwg.org/#fetch-timing-info-post-redirect-start-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [HTTP
fetch](https://fetch.spec.whatwg.org/#concept-http-fetch) for more info.

The
[`domainLookupStart`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [final connection timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info-final-connection-timing-info)'s [domain lookup start
time](https://fetch.spec.whatwg.org/#connection-timing-info-domain-lookup-start-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [Recording connection timing
info](https://fetch.spec.whatwg.org/#record-connection-timing-info) for more info.

The [`domainLookupEnd`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [final connection timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info-final-connection-timing-info)'s [domain lookup end
time](https://fetch.spec.whatwg.org/#connection-timing-info-domain-lookup-end-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [Recording connection timing
info](https://fetch.spec.whatwg.org/#record-connection-timing-info) for more info.

The [`connectStart`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [final connection timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info-final-connection-timing-info)'s [connection start
time](https://fetch.spec.whatwg.org/#connection-timing-info-connection-start-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [Recording connection timing
info](https://fetch.spec.whatwg.org/#record-connection-timing-info) for more info.

The [`connectEnd`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [final connection timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info-final-connection-timing-info)'s [connection end
time](https://fetch.spec.whatwg.org/#connection-timing-info-connection-end-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [Recording connection timing
info](https://fetch.spec.whatwg.org/#record-connection-timing-info) for more info.

The
[`secureConnectionStart`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [final connection timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info-final-connection-timing-info)'s [secure connection start
time](https://fetch.spec.whatwg.org/#connection-timing-info-secure-connection-start-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [Recording connection timing
info](https://fetch.spec.whatwg.org/#record-connection-timing-info) for more info.

The [`nextHopProtocol`] getter steps are to [isomorphic
decode](https://infra.spec.whatwg.org/#isomorphic-decode)
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [final connection timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info-final-connection-timing-info)'s [ALPN negotiated
protocol](https://fetch.spec.whatwg.org/#connection-timing-info-alpn-negotiated-protocol). See [Recording connection timing
info](https://fetch.spec.whatwg.org/#record-connection-timing-info) for more info.

Issue [221](https://github.com/w3c/resource-timing/issues/221) suggests
to remove support for nextHopProtocol, as it can reveal details about
the user's network configuration.

The [`requestStart`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [final network-request start
time](https://fetch.spec.whatwg.org/#fetch-timing-info-final-network-request-start-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [HTTP
fetch](https://fetch.spec.whatwg.org/#concept-http-fetch) for more info.

The
[`firstInterimResponseStart`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [first interim network-response start
time](https://fetch.spec.whatwg.org/#fetch-timing-info-first-interim-network-response-start-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [HTTP
fetch](https://fetch.spec.whatwg.org/#concept-http-fetch) for more info.

The
[`finalResponseHeadersStart`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [final network-response start
time](https://fetch.spec.whatwg.org/#fetch-timing-info-final-network-response-start-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See [HTTP
fetch](https://fetch.spec.whatwg.org/#concept-http-fetch) for more info.

The [`responseStart`] getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s
[`firstInterimResponseStart`](#dom-performanceresourcetiming-firstinterimresponsestart) if it is not 0; Otherwise
[this](https://webidl.spec.whatwg.org/#this)'s
[`finalResponseHeadersStart`](#dom-performanceresourcetiming-finalresponseheadersstart).

The [`responseEnd`] getter steps are to [convert fetch
timestamp](#dfn-convert-fetch-timestamp) for
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [end
time](https://fetch.spec.whatwg.org/#fetch-timing-info-end-time) and the [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) for
[this](https://webidl.spec.whatwg.org/#this). See
[fetch](https://fetch.spec.whatwg.org/#concept-fetch) for more info.

The [`encodedBodySize`] getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [resource
info](#performanceresourcetiming-resource-info)'s [encoded
size](https://fetch.spec.whatwg.org/#fetch-timing-info-encoded-body-size).

The [`decodedBodySize`] getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [resource
info](#performanceresourcetiming-resource-info)'s [decoded
size](https://fetch.spec.whatwg.org/#fetch-timing-info-decoded-body-size).

The [`transferSize`] getter steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s [cache
 mode](#performanceresourcetiming-cache-mode) is \"`local`\", then return 0.

2. If [this](https://webidl.spec.whatwg.org/#this)'s [cache
 mode](#performanceresourcetiming-cache-mode) is \"`validated`\", then return 300.

3. Return [this](https://webidl.spec.whatwg.org/#this)'s [resource
 info](#performanceresourcetiming-resource-info)'s [encoded
 size](https://fetch.spec.whatwg.org/#fetch-timing-info-encoded-body-size) plus 300.

 The constant number added to `transferSize` replaces exposing the
 total byte size of the HTTP headers, as that might expose the
 presence of certain cookies. See [this
 issue](https://github.com/w3c/resource-timing/issues/238).

The [`responseStatus`] getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [response
status](#performanceresourcetiming-response-status).

`responseStatus` is determined in
[Fetch](https://fetch.spec.whatwg.org/#concept-fetch). For a cross-origin
[no-cors](https://fetch.spec.whatwg.org/#dom-requestmode-no-cors)
request it would be 0 because the response would be an [opaque filtered
response](https://fetch.spec.whatwg.org/#concept-filtered-response-opaque).

The [`contentType`] getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [resource
info](#performanceresourcetiming-resource-info)'s [content
type](https://fetch.spec.whatwg.org/#response-body-info-content-type).

The [`contentEncoding`] getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [resource
info](#performanceresourcetiming-resource-info)'s [content
encoding](https://fetch.spec.whatwg.org/#response-body-info-content-encoding).

The
[`renderBlockingStatus`] getter steps are to return
[blocking](#renderblockingstatustype-blocking) if
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s
[render-blocking](https://fetch.spec.whatwg.org/#fetch-timing-info-render-blocking) is true; otherwise
[non-blocking](#renderblockingstatustype-non-blocking).

The
[`workerRouterEvaluationStart`] getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [service worker timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info-service-worker-timing-info)'s [worker router evaluation
start](https://w3c.github.io/ServiceWorker/#service-worker-timing-info-worker-router-evaluation-start).

The
[`workerCacheLookupStart`] getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [service worker timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info-service-worker-timing-info)'s [worker cache lookup
start](https://w3c.github.io/ServiceWorker/#service-worker-timing-info-worker-cache-lookup-start).

The
[`workerMatchedRouterSource`] getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [service worker timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info-service-worker-timing-info)'s [worker matched router
source](https://w3c.github.io/ServiceWorker/#service-worker-timing-info-worker-matched-router-source).

The
[`workerFinalRouterSource`] getter steps are to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performanceresourcetiming-timing-info)'s [service worker timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info-service-worker-timing-info)'s [worker final router
source](https://w3c.github.io/ServiceWorker/#service-worker-timing-info-worker-final-router-source).

A user agent implementing
[`PerformanceResourceTiming`](#performanceresourcetiming) would need to include `"resource"` in
[`supportedEntryTypes`](https://w3c.github.io/performance-timeline/#dom-performanceobserver-supportedentrytypes). This allows developers to detect support for Resource
Timing.

#### 3.3.1. RenderBlockingStatusType enum

```
enum RenderBlockingStatusType {
 "blocking",
 "non-blocking"
};
```

The values are defined as follows:

[blocking]
: The resource can potentially block rendering.

[non-blocking]
: The resource will not block rendering.

### 3.4. Extensions to the `Performance` Interface

The user agent MAY choose to limit how many resources are included as
[`PerformanceResourceTiming`](#performanceresourcetiming) objects in the [Performance
Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline)
[\[PERFORMANCE-TIMELINE-2\]](#biblio-performance-timeline-2 "Performance Timeline").
This section extends the
[`Performance`](https://www.w3.org/TR/hr-time-3/#dom-performance)
interface to allow controls over the number of
[`PerformanceResourceTiming`](#performanceresourcetiming) objects stored.

The recommended minimum number of
[`PerformanceResourceTiming`](#performanceresourcetiming) objects is 250, though this may be changed by the user
agent.
[setResourceTimingBufferSize](#performance-setresourcetimingbuffersize) can be called to request a change to this limit.

Each [ECMAScript global
environment](https://webidl.spec.whatwg.org/#es-environment) has:

- A [resource timing buffer size
 limit] which
 should initially be 250 or greater.
- A [resource timing buffer current
 size] which
 is initially 0.
- A [resource timing buffer full event pending
 flag] which
 is initially false.
- A [resource timing secondary buffer current
 size] which
 is initially 0.
- A [resource timing secondary
 buffer] to
 store
 [`PerformanceResourceTiming`](#performanceresourcetiming) objects that is initially empty.

```
partial interface Performance {
 undefined clearResourceTimings ();
 undefined setResourceTimingBufferSize (unsigned long maxSize);
 attribute EventHandler onresourcetimingbufferfull;
 };
```

The [Performance] interface is defined in
[\[HR-TIME\]](#biblio-hr-time "High Resolution Time").

The method [clearResourceTimings] runs the
following steps:

1. Remove all
 [`PerformanceResourceTiming`](#performanceresourcetiming) objects in the [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer).
2. Set [resource timing buffer current
 size](#performance-resource-timing-buffer-current-size) to 0.

The
[setResourceTimingBufferSize]
method runs the following steps:

1. Set [resource timing buffer size
 limit](#performance-resource-timing-buffer-size-limit) to the *maxSize* parameter. If the *maxSize*
 parameter is less than [resource timing buffer current
 size](#performance-resource-timing-buffer-current-size), no
 [`PerformanceResourceTiming`](#performanceresourcetiming) objects are to be removed from the [performance
 entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer).

The attribute
[onresourcetimingbufferfull] is the
event handler for the `resourcetimingbufferfull` event described below.

To check if [can add resource timing
entry], run the following
steps:

1. If [resource timing buffer current
 size](#performance-resource-timing-buffer-current-size) is smaller than [resource timing buffer size
 limit](#performance-resource-timing-buffer-size-limit), return true.
2. Return false.

To [add a PerformanceResourceTiming
entry] *new entry* into the
[performance entry
buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer), run the following steps:

1. If [can add resource timing
 entry](#dfn-can-add-resource-timing-entry) returns true and [resource timing buffer full event
 pending
 flag](#performance-resource-timing-buffer-full-event-pending-flag) is false, run the following substeps:
 1. Add *new entry* to the [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer).
 2. Increase [resource timing buffer current
 size](#performance-resource-timing-buffer-current-size) by 1.
 3. Return.
2. If [resource timing buffer full event pending
 flag](#performance-resource-timing-buffer-full-event-pending-flag) is false, run the following substeps:
 1. Set [resource timing buffer full event pending
 flag](#performance-resource-timing-buffer-full-event-pending-flag) to true.
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on the [performance timeline task
 source](https://www.w3.org/TR/performance-timeline/#dfn-performance-timeline-task-source) to run [fire a buffer full
 event](#dfn-fire-a-buffer-full-event).
3. Add *new entry* to the [resource timing secondary
 buffer](#performance-resource-timing-secondary-buffer).
4. Increase [resource timing secondary buffer current
 size](#performance-resource-timing-secondary-buffer-current-size) by 1.

To [copy secondary buffer], run the following
steps:

1. While [resource timing secondary
 buffer](#performance-resource-timing-secondary-buffer) is not empty and [can add resource timing
 entry](#dfn-can-add-resource-timing-entry) returns true, run the following substeps:
 1. Let *entry* be the oldest
 [`PerformanceResourceTiming`](#performanceresourcetiming) in [resource timing secondary
 buffer](#performance-resource-timing-secondary-buffer).
 2. Add *entry* to the end of [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer).
 3. Increment [resource timing buffer current
 size](#performance-resource-timing-buffer-current-size) by 1.
 4. Remove *entry* from [resource timing secondary
 buffer](#performance-resource-timing-secondary-buffer).
 5. Decrement [resource timing secondary buffer current
 size](#performance-resource-timing-secondary-buffer-current-size) by 1.

To [fire a buffer full event], run the
following steps:

1. While [resource timing secondary
 buffer](#performance-resource-timing-secondary-buffer) is not empty, run the following substeps:
 1. Let *number of excess entries before* be [resource timing
 secondary buffer current
 size](#performance-resource-timing-secondary-buffer-current-size).
 2. If [can add resource timing
 entry](#dfn-can-add-resource-timing-entry) returns false, then [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named `resourcetimingbufferfull` at the
 [`Performance`](https://w3c.github.io/hr-time/#performance) object.
 3. Run [copy secondary
 buffer](#dfn-copy-secondary-buffer).
 4. Let *number of excess entries after* be [resource timing
 secondary buffer current
 size](#performance-resource-timing-secondary-buffer-current-size).
 5. If *number of excess entries before* is lower than or equals
 *number of excess entries after*, then remove all entries from
 [resource timing secondary
 buffer](#performance-resource-timing-secondary-buffer), set [resource timing secondary buffer current
 size](#performance-resource-timing-secondary-buffer-current-size) to 0, and abort these steps.

2. Set [resource timing buffer full event pending
 flag](#performance-resource-timing-buffer-full-event-pending-flag) to false.

 This means that if the `resourcetimingbufferfull` event handler does
 not add more room in the buffer than it adds resources to it, excess
 entries will be dropped from the buffer. Developers need to make
 sure that `resourcetimingbufferfull` event handlers call
 `clearResourceTimings` or extend the buffer sufficiently (by calling
 `setResourceTimingBufferSize`).

### 3.5. Cross-origin Resources

#### 3.5.1. Introduction

As detailed in
[Fetch](https://fetch.spec.whatwg.org/#concept-fetch), requests for cross-origin resources are included as
[`PerformanceResourceTiming`](#performanceresourcetiming) objects in the [Performance
Timeline](https://www.w3.org/TR/performance-timeline/#performance-timeline).

If the [timing allow
check](https://fetch.spec.whatwg.org/#concept-tao-check) algorithm fails
for a cross-origin resource, the entry will be an [opaque
entry](https://fetch.spec.whatwg.org/#create-an-opaque-timing-info). Such entries have most of their attributes masked in
order to prevent leaking cross-origin data that isn't otherwise exposed.
So, for an [opaque
entry](https://fetch.spec.whatwg.org/#create-an-opaque-timing-info), the following attributes will always return zero or
the empty string:
[`redirectStart`](#dom-performanceresourcetiming-redirectstart),
[`redirectEnd`](#dom-performanceresourcetiming-redirectend),
[`workerStart`](#dom-performanceresourcetiming-workerstart),
[`domainLookupStart`](#dom-performanceresourcetiming-domainlookupstart),
[`domainLookupEnd`](#dom-performanceresourcetiming-domainlookupend),
[`connectStart`](#dom-performanceresourcetiming-connectstart),
[`connectEnd`](#dom-performanceresourcetiming-connectend),
[`requestStart`](#dom-performanceresourcetiming-requeststart),
[`firstInterimResponseStart`](#dom-performanceresourcetiming-firstinterimresponsestart),
[`finalResponseHeadersStart`](#dom-performanceresourcetiming-finalresponseheadersstart),
[`responseStart`](#dom-performanceresourcetiming-responsestart),
[`secureConnectionStart`](#dom-performanceresourcetiming-secureconnectionstart), and
[`nextHopProtocol`](#dom-performanceresourcetiming-nexthopprotocol).

Some of the properties, like
[`contentType`](#dom-performanceresourcetiming-contenttype),
[`encodedBodySize`](#dom-performanceresourcetiming-encodedbodysize), and
[`decodedBodySize`](#dom-performanceresourcetiming-decodedbodysize) are set to zero (or the empty string in the case of
[`contentType`](#dom-performanceresourcetiming-contenttype)) when the response is
[CORS-cross-origin](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-cross-origin).

[`transferSize`](#dom-performanceresourcetiming-transfersize) is affected both by the [timing allow
check](https://fetch.spec.whatwg.org/#concept-tao-check) and by the
[CORS-cross-origin](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-cross-origin)
status.

For requests handled by a [service
worker](https://w3c.github.io/ServiceWorker/#dfn-service-worker) using
[`respondWith()`](https://w3c.github.io/ServiceWorker/#dom-fetchevent-respondwith), the reported timing data reflects the interaction
between the client and the service worker, rather than the service
worker's own internal network activity. For example, the service worker
might respond to a same-origin request with a cross-origin response or
vice versa, or return a cached or synthetic response to either. Given
that, resources forwarded from a service worker do not tell the whole
story of fetching the resource, and do not go through the [timing allow
check](https://fetch.spec.whatwg.org/#concept-tao-check). To get the
full information about those fetches, the service worker's own
performance timeline can be inspected.
[\[SERVICE-WORKERS\]](#biblio-service-workers "Service Workers Nightly")

For more details, see [HTTP
Fetch](https://fetch.spec.whatwg.org/#concept-http-fetch)
#4 - the [timing allow
check](https://fetch.spec.whatwg.org/#concept-tao-check) is only
performed when there is no response from the service worker. In
addition, the
[response](https://fetch.spec.whatwg.org/#concept-response) cloned in the
[`respondWith()`](https://w3c.github.io/ServiceWorker/#dom-fetchevent-respondwith) algorithm does not carry the [fetch timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info) of the internal fetch, as that information is attached
to a fetch rather than to a
[response](https://fetch.spec.whatwg.org/#concept-response).

#### 3.5.2. `Timing-Allow-Origin` Response Header

Server-side applications may return the
[Timing-Allow-Origin](#timing-allow-origin) HTTP response header to allow the User Agent to fully
expose, to the document origin(s) specified, the values of attributes
that would have been zero due to those cross-origin restrictions.

The [Timing-Allow-Origin] HTTP response header field can be used to
communicate a policy indicating origin(s) that may be allowed to see
values of attributes that would have been zero due to the cross-origin
restrictions. The header's value is represented by the following ABNF
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF")
(using [List
Extension](https://httpwg.org/specs/rfc9110.html#rfc.section.5.6.1),
[\[RFC9110\]](#biblio-rfc9110 "HTTP Semantics")):

`Timing-Allow-Origin = 1#( `[`origin-or-null`](https://fetch.spec.whatwg.org/#origin-header)` / `[`wildcard`](https://fetch.spec.whatwg.org/#http-new-header-syntax)` )`

The sender MAY generate multiple
[Timing-Allow-Origin](#timing-allow-origin) header fields. The recipient MAY combine multiple
[Timing-Allow-Origin](#timing-allow-origin) header fields by appending each subsequent field value
to the combined field value in order, separated by a comma.

The user agent MAY still enforce cross-origin restrictions and set
transferSize, encodedBodySize, and decodedBodySize attributes to zero,
even with Timing-Allow-Origin HTTP response header fields. If it does,
it MAY also set deliveryType to \"\".

The
[Timing-Allow-Origin](#timing-allow-origin) headers are processed in
[FETCH](https://fetch.spec.whatwg.org/#tao-check) to compute the
attributes accordingly.

The Timing-Allow-Origin header might arrive as part of a cached
response. In case of cache revalidation, according to [RFC
7234](https://tools.ietf.org/html/rfc7234#section-4.3.4), the header's
value might come from the revalidation response, or if not present
there, from the original cached resource.

Issues [222](https://github.com/w3c/resource-timing/issues/222) and
[223](https://github.com/w3c/resource-timing/issues/223) suggest to
remove wildcard support from Timing-Allow-Origin in order to restrict
its use.

#### 3.5.3. IANA Considerations

This section registers
[Timing-Allow-Origin](#timing-allow-origin) as a [Provisional Message
Header](https://tools.ietf.org/html/rfc3864#section-4.2.2).

Header field name:

: ``` abnf
 Timing-Allow-Origin
 ```

Applicable protocol:
: http

Status:
: provisional

Author/Change controller:
: [W3C](https://www.w3.org/)

Specification document:
: [§ 3.5.2 Timing-Allow-Origin Response
 Header](#sec-timing-allow-origin)

### 3.6. Resource Timing Attributes

This section is non-normative.

The following graph illustrates the timing attributes defined by the
PerformanceResourceTiming interface. Attributes in parenthesis may not
be available when
[fetching](https://fetch.spec.whatwg.org/#concept-fetch) cross-origin resources. User agents may perform
internal processing in between timings, which allow for non-normative
intervals between timings.

<figure data->
<img src="timestamp-diagram.svg" style="margin-top: 1em" width="1000"
a />
<figcaption>This figure illustrates the timing attributes defined by the
<a href="#performanceresourcetiming"
id="ref-for-performanceresourcetiming③⑤" data-><code
class="idl">PerformanceResourceTiming</code></a> interface. Attributes
in parenthesis indicate that they may not be available if the resource
fails the <a
href="https://fetch.spec.whatwg.org/#concept-tao-check">timing allow
check</a> algorithm.</figcaption>
</figure>

## 4. Creating a resource timing entry

To [mark resource
timing] given a [fetch timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info) `timingInfo`, a DOMString
`requestedURL`, a DOMString `initiatorType` a
[global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) `global`, a string `cacheMode`, a
[response body
info](https://fetch.spec.whatwg.org/#response-body-info) `bodyInfo`, a
[status](https://fetch.spec.whatwg.org/#concept-status)
`responseStatus`, and an optional
[string](https://infra.spec.whatwg.org/#string) `deliveryType` (by default, the empty
string), perform the following steps:

1. Create a
 [`PerformanceResourceTiming`](#performanceresourcetiming) object `entry` in `global`'s
 [realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-global-object-realm).
2. [Setup the resource timing
 entry](#setup-the-resource-timing-entry) for `entry`, given
 `initiatorType`, `requestedURL`,
 `timingInfo`, `cacheMode`,
 `bodyInfo`, `responseStatus`, and
 `deliveryType`.
3. [Queue a
 PerformanceEntry](https://www.w3.org/TR/performance-timeline/#dfn-queue-a-performanceentry) `entry`.
4. [Add](#dfn-add-a-PerformanceResourceTiming-entry) `entry` to `global`'s
 [performance entry
 buffer](https://www.w3.org/TR/performance-timeline/#dfn-performance-entry-buffer).

To [setup the
resource timing entry] for
[`PerformanceResourceTiming`](#performanceresourcetiming) `entry` given DOMString
`initiatorType`, DOMString `requestedURL`, [fetch
timing
info](https://fetch.spec.whatwg.org/#fetch-timing-info) `timingInfo`, a DOMString
`cacheMode`, a [response body
info](https://fetch.spec.whatwg.org/#response-body-info) `bodyInfo`, a
[status](https://fetch.spec.whatwg.org/#concept-status)
`responseStatus`, and an optional DOMString
`deliveryType` (by default, the empty string), perform the
following steps:

1. Assert that `cacheMode` is the empty string, \"`local`\",
 or \"`validated`\".
2. Let `global` be `entry`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).
3. [Initialize](https://www.w3.org/TR/performance-timeline/#dfn-initialize-a-performanceentry) `entry` given the result of
 [converting](#dfn-convert-fetch-timestamp) `timingInfo`'s [start
 time](https://fetch.spec.whatwg.org/#fetch-timing-info-start-time) given `global`, \"`resource`\",
 `requestedURL`, and the result of
 [converting](#dfn-convert-fetch-timestamp) `timingInfo`'s [end
 time](https://fetch.spec.whatwg.org/#fetch-timing-info-end-time) given `global`.
4. Set `entry`'s [initiator
 type](#performanceresourcetiming-initiator-type) to `initiatorType`.
5. Set `entry`'s [requested
 URL](#performanceresourcetiming-requested-url) to `requestedURL`.
6. Set `entry`'s [timing
 info](#performanceresourcetiming-timing-info) to `timingInfo`.
7. Set `entry`'s [resource
 info](#performanceresourcetiming-resource-info) to `bodyInfo`.
8. Set `entry`'s [cache
 mode](#performanceresourcetiming-cache-mode) to `cacheMode`.
9. Set `entry`'s [response
 status](#performanceresourcetiming-response-status) to `responseStatus`.
10. If `deliveryType` is the empty string and
 `cacheMode` is not, then set `deliveryType` to
 \"`cache`\".
11. Set `entry`'s [delivery
 type](#performanceresourcetiming-delivery-type) to `deliveryType`.

To [convert fetch timestamp] given
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) `ts` and [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object) `global`, do the following:

1. If `ts` is zero, return zero.
2. Otherwise, return the [relative high resolution coarse
 time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-coarse-time) given `ts` and `global`.

## 5. Security Considerations

The
[`PerformanceResourceTiming`](#performanceresourcetiming) interface exposes timing information for a resource to
any web page or worker that has requested that resource. To limit the
access to the
[`PerformanceResourceTiming`](#performanceresourcetiming) interface, the [same
origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin)
policy is enforced by default and certain attributes are set to zero, as
described in [HTTP
fetch](https://fetch.spec.whatwg.org/#concept-http-fetch). Resource providers can explicitly allow all timing
information to be collected for a resource by adding the
[Timing-Allow-Origin](#timing-allow-origin) HTTP response header, which specifies the domains that
are allowed to access the timing information.

## 6. Privacy Considerations

Statistical fingerprinting is a privacy concern where a malicious web
site might determine whether a user has visited a third-party web site
by measuring the timing of cache hits and misses of resources in the
third-party web site. Though the
[`PerformanceResourceTiming`](#performanceresourcetiming) interface gives timing information for resources in a
document, the load event on resources can already measure timing to
determine cache hits and misses in a limited fashion, and the
cross-origin restrictions in [HTTP
Fetch](https://fetch.spec.whatwg.org/#concept-http-fetch) prevent the leakage of any additional information.

## 7. Acknowledgments

Thanks to Anne Van Kesteren, Annie Sullivan, Arvind Jain, Boris Zbarsky,
Darin Fisher, Jason Weber, Jonas Sicking, James Simonsen, Karen
Anderson, Kyle Scholz, Nic Jansma, Philippe Le Hegaret, Sigbjørn Vik,
Steve Souders, Todd Reifsteck, Tony Gentilcore, William Chan, and Alex
Christensen for their contributions to this work.
