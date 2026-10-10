## 1. Introduction

*This section is non-normative.*

Web applications often need to issue requests that report events, state
updates, and analytics to one or more servers. Such requests typically
do not require response processing on the client (e.g. result in 204, or
200 HTTP response codes with an empty response body), and should not
compete for network and compute resources with other high priority
operations such as fetching critical resources, reacting to input,
running animations, and so on. However, such one-way requests (beacons),
are also responsible for delivering critical application and measurement
data, forcing developers to use costly methods to ensure their delivery:

- Developers opt for immediate delivery of each beacon, instead of
 coalescing and deferring their delivery because this provides improved
 delivery rates. Deferring delivery may mean that the beacon request
 may not have sufficient time to complete successfully, which leads to
 loss of important application data.
- Developers opt for issuing blocking requests via synchronous
 XMLHttpRequest's, inserting no-op busy loops, or using other
 techniques that block the user agent from executing time-critical
 operations (e.g. click, unload, and other handlers) and hurt the user
 experience. The blocking behavior is used to provide improved delivery
 rate, as it prevents the user agent and the operating system from
 cancelling the request if the page is unloaded, suspended, or killed
 by the system.

The mismatch between above delivery and processing requirements leaves
most developers with a tough choice and widespread adoption of blocking
techniques that hurt the user experience. This specification defines an
interface that web developers can use to schedule asynchronous and
non-blocking delivery of data that minimizes resource contention with
other time-critical operations, while ensuring that such requests are
still processed and delivered to destination:

- Beacon requests are prioritized to avoid competing with time-critical
 operations and higher priority network requests.
- Beacon requests may be efficiently coalesced by the user agent to
 optimize energy use on mobile devices.
- Beacon requests are guaranteed to be initiated before page is unloaded
 and are allowed to run to completion without requiring blocking
 requests or other techniques that block processing of user interactive
 events.

The following example shows use of the
[`sendBeacon()`](#dom-navigator-sendbeacon) method to deliver event, click, and analytics data:

```
<html>
<script>
 // emit non-blocking beacon to record client-side event
 function reportEvent(event) {
 var data = JSON.stringify({
 event: event,
 time: performance.now()
 });
 navigator.sendBeacon('/collector', data);
 }

 // emit non-blocking beacon with session analytics as the page
 // transitions to background state (Page Visibility API)
 document.addEventListener('visibilitychange', function() {
 if (document.visibilityState === 'hidden') {
 var sessionData = buildSessionReport();
 navigator.sendBeacon('/collector', sessionData);
 }
 });
</script>

<body>
 <a href='http://www.w3.org/' onclick='reportEvent(this)'>
 <button onclick="reportEvent('some event')">Click me</button>
</body>
</html>
```

[Above example uses the
[visibilitychange](https://html.spec.whatwg.org/multipage/interaction.html#page-visibility-change-steps)
event defined in
[\[PAGE-VISIBILITY\]](#biblio-page-visibility "Page Visibility (Second Edition)")
to trigger delivery of session data. This event is the only event that
is guaranteed to fire on mobile devices when the page transitions to
background state (e.g. when user switches to a different application,
goes to homescreen, etc), or is being unloaded. Developers should avoid
relying on
[unload](https://html.spec.whatwg.org/multipage/indices.html#event-unload)
event because it will not fire whenever a page is in a background state
(i.e.
[`visibilityState`](https://html.spec.whatwg.org/multipage/interaction.html#dom-document-visibilitystate) equal to
[`hidden`](https://html.spec.whatwg.org/multipage/interaction.html#dom-document-hidden)) and the process is terminated by the mobile
OS.]

The requests initiated via the
[`sendBeacon()`](#dom-navigator-sendbeacon) method do not block or compete with time-critical work,
may be prioritized by the user agent to improve network efficiency, and
eliminate the need to use blocking operations to ensure delivery of
beacon data.

What
[`sendBeacon()`](#dom-navigator-sendbeacon) does not do and is not intended to solve:

- The
 [`sendBeacon()`](#dom-navigator-sendbeacon) method does not provide special handling for offline
 storage or delivery. A beacon request is like any other request and
 may be combined with
 [\[SERVICE-WORKERS\]](#biblio-service-workers "Service Workers Nightly")
 to provide offline functionality where necessary.
- The
 [`sendBeacon()`](#dom-navigator-sendbeacon) method is not intended to provide background
 synchronization or transfer capabilities. The user agent restricts the
 maximum accepted payload size to ensure that beacon requests are able
 to complete quickly and in a timely manner.
- The
 [`sendBeacon()`](#dom-navigator-sendbeacon) method does not provide ability to customize the
 request method, provide custom request headers, or change other
 [processing properties](#sec-processing-model) of the request and
 response. Applications that require non-default settings for such
 requests should use the
 [\[FETCH\]](#biblio-fetch "Fetch Standard") API
 with
 [keepalive](https://fetch.spec.whatwg.org/#request-keepalive-flag) set to `true`.

## 2. Beacon

### [2.1. ][[`sendBeacon()`] Method]
```
partial interface Navigator {
 boolean sendBeacon(USVString url, optional BodyInit? data = null);
};
```

The
[`sendBeacon()`](#dom-navigator-sendbeacon) method transmits data provided by the
[`data`](#dom-navigator-sendbeacon-url-data-data)
parameter to the URL provided by the
[`url`](#url-parameter) parameter:

- The user agent MUST initiate a
 [fetch](https://fetch.spec.whatwg.org/#concept-fetch) with
 [keepalive](https://fetch.spec.whatwg.org/#request-keepalive-flag) flag set, which restricts the amount of data that can
 be queued by such requests to ensure that beacon requests are able to
 complete quickly and in a timely manner.
- The user agent MUST schedule immediate transmission of all beacon
 requests when the document
 [`visibilityState`](https://html.spec.whatwg.org/multipage/interaction.html#dom-document-visibilitystate) transitions to
 [`hidden`](https://html.spec.whatwg.org/multipage/interaction.html#dom-document-hidden), and must allow all such requests to run to
 completion without blocking other time-critical and high-priority
 work.
- The user agent SHOULD schedule transmission of provided data to
 minimize resource (CPU and network) contention with other
 time-critical and high priority work.
- The user agent MAY delay transmission of provided data to optimize
 network and energy efficiency - e.g. deliver immediately if the
 network is active, or wait until network interface is active. However,
 the user agent SHOULD NOT delay transmission indefinitely and ensure
 that pending transmissions are periodically flushed even if there is
 no other network activity.

Beacon API does not provide a response callback. The server is
encouraged to omit returning a response body for such requests (e.g.
respond with `204 No Content`).

#### 2.1.1. Parameters

#### [2.1.2. ][[`url`]]
The [`url`](#url-parameter) parameter indicates
the URL where the data is to be transmitted.

#### [2.1.3. ][[`data`]]
The
[`data`](#dom-navigator-sendbeacon-url-data-data)
parameter is the
[`BodyInit`](https://fetch.spec.whatwg.org/#bodyinit) data that is to be transmitted.

#### 2.1.4. Return Value

The
[`sendBeacon()`](#dom-navigator-sendbeacon) method returns true if the user agent is able to
successfully queue the data for transfer. Otherwise it returns false.

The user agent imposes limits on the amount of data that can be sent via
this API: this helps ensure that such requests are delivered
successfully and with minimal impact on other user and browser activity.
If the amount of `data` to be queued exceeds the user agent
limit (as defined in [HTTP-network-or-cache
fetch](https://fetch.spec.whatwg.org/#concept-http-network-or-cache-fetch)), this method returns `false`; a return value of `true`
implies the browser has queued the data for transfer. However, since the
actual data transfer happens asynchronously, this method does not
provide any information whether the data transfer has succeeded or not.

## 3. Processing Model

On calling the
[`sendBeacon()`](#dom-navigator-sendbeacon) method with `url` and optional
`data`, the following steps must be run:

1. Set `base` to
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s [API base
 URL](https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url).

2. Set `origin` to
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin).

3. Set `parsedUrl` to the result of the [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) steps with `url` and `base`.
 If the algorithm returns an error, or if `parsedUrl`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is not \"http\" or \"https\",
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 \"[`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror)\" exception and terminate these steps.

4. Let `headerList` be an empty list.

5. Let `corsMode` be \"`no-cors`\".

6. If `data` is not `null`:

 1. Set `transmittedData` and `contentType` to
 the result of
 [extracting](https://fetch.spec.whatwg.org/#concept-bodyinit-extract) `data`'s byte stream with the
 `keepalive flag` set.

 2. If the amount of data that can be queued to be sent by
 [keepalive](https://fetch.spec.whatwg.org/#request-keepalive-flag) enabled requests is exceeded by the size of
 `transmittedData` (as defined in
 [HTTP-network-or-cache
 fetch](https://fetch.spec.whatwg.org/#concept-http-network-or-cache-fetch)), set the return value to `false` and terminate
 these steps.

 [Requests initiated via the Beacon API automatically set the
 [keepalive](https://fetch.spec.whatwg.org/#request-keepalive-flag) flag, and developers can similarly set the same
 flag manually when using the Fetch API. All requests with this
 flag set share the same in-flight quota restrictions that is
 enforced within the Fetch API.]

 3. If `contentType` is not null:
 - Set `corsMode` to \"`cors`\".
 - If `contentType` value is a [CORS-safelisted
 request-header](https://fetch.spec.whatwg.org/#cors-safelisted-request-header) value for the `Content-Type` header, set
 `corsMode` to \"`no-cors`\".
 - Append a `Content-Type` header with value
 `contentType` to `headerList`.

7. Set the return value to `true`, return the
 [`sendBeacon()`](#dom-navigator-sendbeacon) call, and continue to run the following steps in
 parallel:
 1. Let `req` be a new
 [request](https://fetch.spec.whatwg.org/#concept-request), initialized as follows:

 [method](https://fetch.spec.whatwg.org/#concept-request-method)
 : `POST`

 [client](https://fetch.spec.whatwg.org/#concept-request-client)
 : [this](https://webidl.spec.whatwg.org/#this)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)

 [url](https://fetch.spec.whatwg.org/#concept-request-url)
 : `parsedUrl`

 [header list](https://fetch.spec.whatwg.org/#concept-request-header-list)
 : `headerList`

 [origin](https://fetch.spec.whatwg.org/#concept-request-origin)
 : `origin`

 [keepalive](https://fetch.spec.whatwg.org/#request-keepalive-flag)
 : `true`

 [body](https://fetch.spec.whatwg.org/#concept-request-body)
 : `transmittedData`

 [mode](https://fetch.spec.whatwg.org/#concept-request-mode)
 : `corsMode`

 [credentials mode](https://fetch.spec.whatwg.org/#concept-request-credentials-mode)
 : `include`

 [initiator type](https://fetch.spec.whatwg.org/#request-initiator-type)
 : \"`beacon`\"

 2. [Fetch](https://fetch.spec.whatwg.org/#concept-fetch) `req`.

## 4. Privacy and Security

*This section is non-normative.*

The
[`sendBeacon()`](#dom-navigator-sendbeacon) interface provides an asynchronous and non-blocking
mechanism for delivery of data. This API can be used to:

- Report client-side events to the server. The delivery is prioritized
 and scheduled by the user agent such that it does not block other
 interactive work and makes efficient use of system resources.
- Report session data when the page transitions to background state or
 is being unloaded, without blocking the user agent.
- Other use cases that require delivery of small payloads and do not
 expect a response callback.

The delivered data might contain potentially sensitive information, for
example, data about a user's activity on a web page, to a server. While
this can have privacy implications for the user, existing methods, such
as scripted form-submit, image beacons, and XHR/fetch requests provide
similar capabilities, but come with various and costly performance
tradeoffs: the requests can be aborted by the user agent unless the
developer blocks the user agent from processing other events (e.g. by
invoking a synchronous request, or spinning in an empty loop), and the
user agent is unable to prioritize and coalesce such requests to
optimize use of system resources.

A request initiated by
[`sendBeacon()`](#dom-navigator-sendbeacon) is subject to following properties:

- If the request does not contain a payload, or the request
 `Content-Type` is a [CORS-safelisted
 request-header](https://fetch.spec.whatwg.org/#cors-safelisted-request-header), then the request mode is \`no-cors\`---similar to an
 image beacon or form-post respectively.
- Otherwise, a CORS preflight is made and the server needs to first
 allow such requests by returning the appropriate set of CORS headers:
 [Access-Control-Allow-Credentials](https://fetch.spec.whatwg.org/#http-access-control-allow-credentials),
 [Access-Control-Allow-Origin](https://fetch.spec.whatwg.org/#http-access-control-allow-origin),
 [Access-Control-Allow-Headers](https://fetch.spec.whatwg.org/#http-access-control-allow-headers).

As such, from the security perspective, the Beacon API is subject to
same security policies as the current methods in use by developers.
Similarly, from the privacy perspective, the resulting requests are
initiated immediately when the API is called, or upon a page visibility
change, which restricts the exposed information (e.g. user's IP address)
to existing lifecycle events accessible to the developers. However, user
agents might consider alternative methods to surface such requests to
provide transparency to users.

Compared to the alternatives, the
[`sendBeacon()`](#dom-navigator-sendbeacon) API does apply two restrictions: there is no callback
method, and the payload size can be restricted by the user agent.
Otherwise, the
[`sendBeacon()`](#dom-navigator-sendbeacon) API is not subject to any additional restrictions. The
user agent ought not skip or throttle processing of
[`sendBeacon()`](#dom-navigator-sendbeacon) calls, as they can contain critical application state,
events, and analytics data. Similarly, the user agent ought not disable
[`sendBeacon()`](#dom-navigator-sendbeacon) when in \"private browsing\" or equivalent mode, both
to avoid breaking the application and to avoid leaking that the user is
in such mode.

## 5. Acknowledgments

Thanks to Alois Reitbauer, Arvind Jain, Anne van Kesteren, Boris
Zbarsky, Chase Douglas, Daniel Austin, Jatinder Mann, James Simonsen,
Jason Weber, Jonas Sicking, Nick Doty, Philippe Le Hegaret, Todd
Reifsteck, Tony Gentilcore, William Chan, and Yoav Weiss for their
contributions to this work.
