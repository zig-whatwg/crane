## Introduction

*This section is non-normative.*

The `XMLHttpRequest` object is an API for fetching resources.

The name `XMLHttpRequest` is historical and has no bearing on its functionality.

Some simple code to do something with data from an XML document fetched over the network:

```javascript
function processData(data) {
  // taking care of data
}

function handler() {
  if(this.status == 200 &&
    this.responseXML != null &&
    this.responseXML.getElementById('test').textContent) {
    // success!
    processData(this.responseXML.getElementById('test').textContent);
  } else {
    // something went wrong
    …
  }
}

var client = new XMLHttpRequest();
client.onload = handler;
client.open("GET", "unicorn.xml");
client.send();
```

If you just want to log a message to the server:

```javascript
function log(message) {
  var client = new XMLHttpRequest();
  client.open("POST", "/log");
  client.setRequestHeader("Content-Type", "text/plain;charset=UTF-8");
  client.send(message);
}
```

Or if you want to check the status of a document on the server:

```javascript
function fetchStatus(address) {
  var client = new XMLHttpRequest();
  client.onload = function() {
    // in case of network errors this might not give reliable results
    returnStatus(this.status);
  }
  client.open("HEAD", address);
  client.send();
}
```


## Specification history

The `XMLHttpRequest` object was initially defined as part of the WHATWG's HTML effort. (Based on Microsoft's implementation many years prior.) It moved to the W3C in 2006. Extensions (e.g., progress events and cross-origin requests) to `XMLHttpRequest` were developed in a separate draft (XMLHttpRequest Level 2) until end of 2011, at which point the two drafts were merged and `XMLHttpRequest` became a single entity again from a standards perspective. End of 2012 it moved back to the WHATWG.

Discussion that led to the current draft can be found in the following mailing list archives:

- [whatwg@whatwg.org](https://lists.w3.org/Archives/Public/public-whatwg-archive/)
- [public-webapps@w3.org](https://lists.w3.org/Archives/Public/public-webapps/)
- [public-webapi@w3.org](https://lists.w3.org/Archives/Public/public-webapi/)
- [public-appformats@w3.org](https://lists.w3.org/Archives/Public/public-appformats/)


## Terminology

This specification depends on the Infra Standard. [INFRA]

This specification uses terminology from DOM, DOM Parsing and Serialization, Encoding, Fetch, File API, HTML, URL, Web IDL, and XML.

[DOM] [DOM-PARSING] [ENCODING] [FETCH] [FILEAPI] [HTML] [URL] [WEBIDL] [XML] [XML-NAMES]


## Interface `XMLHttpRequest`

```idl
[Exposed=(Window,DedicatedWorker,SharedWorker)]
interface XMLHttpRequestEventTarget : EventTarget {
  // event handlers
  attribute EventHandler onloadstart;
  attribute EventHandler onprogress;
  attribute EventHandler onabort;
  attribute EventHandler onerror;
  attribute EventHandler onload;
  attribute EventHandler ontimeout;
  attribute EventHandler onloadend;
};

[Exposed=(Window,DedicatedWorker,SharedWorker)]
interface XMLHttpRequestUpload : XMLHttpRequestEventTarget {
};

enum XMLHttpRequestResponseType {
  "",
  "arraybuffer",
  "blob",
  "document",
  "json",
  "text"
};

[Exposed=(Window,DedicatedWorker,SharedWorker)]
interface XMLHttpRequest : XMLHttpRequestEventTarget {
  constructor();

  // event handler
  attribute EventHandler onreadystatechange;

  // states
  const unsigned short UNSENT = 0;
  const unsigned short OPENED = 1;
  const unsigned short HEADERS_RECEIVED = 2;
  const unsigned short LOADING = 3;
  const unsigned short DONE = 4;
  readonly attribute unsigned short readyState;

  // request
  undefined open(ByteString method, USVString url);
  undefined open(ByteString method, USVString url, boolean async, optional USVString? username = null, optional USVString? password = null);
  undefined setRequestHeader(ByteString name, ByteString value);
           attribute unsigned long timeout;
           attribute boolean withCredentials;
  [SameObject] readonly attribute XMLHttpRequestUpload upload;
  undefined send(optional (Document or XMLHttpRequestBodyInit)? body = null);
  undefined abort();

  // response
  readonly attribute USVString responseURL;
  readonly attribute unsigned short status;
  readonly attribute ByteString statusText;
  ByteString? getResponseHeader(ByteString name);
  ByteString getAllResponseHeaders();
  undefined overrideMimeType(DOMString mime);
           attribute XMLHttpRequestResponseType responseType;
  readonly attribute any response;
  readonly attribute USVString responseText;
  [Exposed=Window] readonly attribute Document? responseXML;
};
```

An `XMLHttpRequest` object has an associated:

upload object
:   An `XMLHttpRequestUpload` object.

state
:   One of *unsent*, *opened*, *headers received*, *loading*, and *done*; initially *unsent*.

`send()` flag
:   A flag, initially unset.

timeout
:   An unsigned integer, initially 0.

cross-origin credentials
:   A boolean, initially false.

request method
:   A method.

request URL
:   A URL.

author request headers
:   A header list, initially empty.

request body
:   Initially null.

synchronous flag
:   A flag, initially unset.

upload complete flag
:   A flag, initially unset.

upload listener flag
:   A flag, initially unset.

timed out flag
:   A flag, initially unset.

response
:   A response, initially a network error.

received bytes
:   A byte sequence, initially the empty byte sequence.

response type
:   One of the empty string, "`arraybuffer`", "`blob`", "`document`", "`json`", and "`text`"; initially the empty string.

response object
:   An object, failure, or null, initially null.

fetch controller
:   A fetch controller, initially a new fetch controller. The `send()` method sets it to a useful fetch controller, but for simplicity it always holds a fetch controller.

override MIME type
:   A MIME type or null, initially null. Can get a value when `overrideMimeType()` is invoked.


### Constructors

`client = new XMLHttpRequest()`
:   Returns a new `XMLHttpRequest` object.

The `new XMLHttpRequest()` constructor steps are:

1.  Set [this](https://webidl.spec.whatwg.org/#this)'s upload object to a new `XMLHttpRequestUpload` object.


## Garbage collection

An `XMLHttpRequest` object must not be garbage collected if its state is either *opened* with the `send()` flag set, *headers received*, or *loading*, and it has one or more event listeners registered whose **type** is one of `readystatechange`, `progress`, `abort`, `error`, `load`, `timeout`, and `loadend`.

If an `XMLHttpRequest` object is garbage collected while its connection is still open, the user agent must terminate the `XMLHttpRequest` object's fetch controller.


### Event handlers

The following are the [event handlers](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers) (and their corresponding [event handler event types](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)) that must be supported on objects implementing an interface that inherits from `XMLHttpRequestEventTarget` as attributes:

event handler | event handler event type
--- | ---
`onloadstart` | `loadstart`
`onprogress` | `progress`
`onabort` | `abort`
`onerror` | `error`
`onload` | `load`
`ontimeout` | `timeout`
`onloadend` | `loadend`

The following is the [event handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers) (and its corresponding [event handler event type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)) that must be supported as attribute solely by the `XMLHttpRequest` object:

event handler | event handler event type
--- | ---
`onreadystatechange` | `readystatechange`


### States

`client . readyState`

:   Returns `client`'s [state](#concept-xmlhttprequest-state).

The `readyState` getter steps are to return the value from the table below in the cell of the second column, from the row where the value in the cell in the first column is [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state):

*unsent*

`UNSENT` (numeric value 0)

The object has been constructed.

*opened*

`OPENED` (numeric value 1)

The `open()` method has been successfully invoked. During this state request headers can be set using `setRequestHeader()` and the fetch can be initiated using the `send()` method.

*headers received*

`HEADERS_RECEIVED` (numeric value 2)

All redirects (if any) have been followed and all headers of a response have been received.

*loading*

`LOADING` (numeric value 3)

The response body is being received.

*done*

`DONE` (numeric value 4)

The data transfer has been completed or something went wrong during the transfer (e.g., infinite redirects).


### Request

Registering one or more event listeners on an [`XMLHttpRequestUpload`](#xmlhttprequestupload) object will result in a [CORS-preflight request](https://fetch.spec.whatwg.org/#cors-preflight-request). (That is because registering an event listener causes the [upload listener flag](#upload-listener-flag) to be set, which in turn causes the [use-CORS-preflight flag](https://fetch.spec.whatwg.org/#use-cors-preflight-flag) to be set.)


#### The `open()` method

`client . open(method, url [, async = true [, username = null [, password = null]]])`

:   Sets the [request method](#request-method), [request URL](#request-url), and [synchronous flag](#synchronous-flag).

    Throws a "[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if either `method` is not a valid method or `url` cannot be parsed.

    Throws a "[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if `method` is a case-insensitive match for `CONNECT`, `TRACE`, or `TRACK`.

    Throws an "[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if `async` is false, the [current global object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object) is a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, and the [`timeout`](#dom-xmlhttprequest-timeout) attribute is not zero or the [`responseType`](#dom-xmlhttprequest-responsetype) attribute is not the empty string.

Synchronous [`XMLHttpRequest`](#xmlhttprequest) outside of workers is in the process of being removed from the web platform as it has detrimental effects to the end user's experience. (This is a long process that takes many years.) Developers must not pass false for the `async` argument when the [current global object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object) is a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object. User agents are strongly encouraged to warn about such usage in developer tools and may experiment with [throwing](https://webidl.spec.whatwg.org/#dfn-throw) an "[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) when it occurs.

The `open(method, url)` and `open(method, url, async, username, password)` method steps are:

1.  If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) is a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object and its [associated `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), then [throw](https://webidl.spec.whatwg.org/#dfn-throw) an "[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2.  If `method` is not a [method](https://fetch.spec.whatwg.org/#concept-method), then [throw](https://webidl.spec.whatwg.org/#dfn-throw) a "[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3.  If `method` is a [forbidden method](https://fetch.spec.whatwg.org/#forbidden-method), then [throw](https://webidl.spec.whatwg.org/#dfn-throw) a "[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4.  [Normalize](https://fetch.spec.whatwg.org/#concept-method-normalize) `method`.

5.  Let `parsedURL` be the result of [encoding-parsing a URL](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#encoding-parsing-a-url) `url`, relative to [this](https://webidl.spec.whatwg.org/#this)'s [relevant settings object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

6.  If `parsedURL` is failure, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) a "[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

7.  If the `async` argument is omitted, set `async` to true, and set `username` and `password` to null.

    Unfortunately legacy content prevents treating the `async` argument being `undefined` identical from it being omitted.

8.  If `parsedURL`'s [host](https://url.spec.whatwg.org/#concept-url-host) is non-null, then:

    1.  If the `username` argument is not null, [set the username](https://url.spec.whatwg.org/#set-the-username) given `parsedURL` and `username`.

    2.  If the `password` argument is not null, [set the password](https://url.spec.whatwg.org/#set-the-password) given `parsedURL` and `password`.

9.  If `async` is false, the [current global object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object) is a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, and either [this](https://webidl.spec.whatwg.org/#this)'s [timeout](#timeout) is not 0 or [this](https://webidl.spec.whatwg.org/#this)'s [response type](#response-type) is not the empty string, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) an "[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

10. [Terminate](https://fetch.spec.whatwg.org/#fetch-controller-terminate) [this](https://webidl.spec.whatwg.org/#this)'s [fetch controller](#xmlhttprequest-fetch-controller).

    A [fetch](https://fetch.spec.whatwg.org/#concept-fetch) can be ongoing at this point.

11. Set variables associated with the object as follows:

    - Unset [this](https://webidl.spec.whatwg.org/#this)'s [`send()` flag](#send-flag).

    - Unset [this](https://webidl.spec.whatwg.org/#this)'s [upload listener flag](#upload-listener-flag).

    - Set [this](https://webidl.spec.whatwg.org/#this)'s [request method](#request-method) to `method`.

    - Set [this](https://webidl.spec.whatwg.org/#this)'s [request URL](#request-url) to `parsedURL`.

    - Set [this](https://webidl.spec.whatwg.org/#this)'s [synchronous flag](#synchronous-flag) if `async` is false; otherwise unset [this](https://webidl.spec.whatwg.org/#this)'s [synchronous flag](#synchronous-flag).

    - [Empty](https://infra.spec.whatwg.org/#list-empty) [this](https://webidl.spec.whatwg.org/#this)'s [author request headers](#author-request-headers).

    - Set [this](https://webidl.spec.whatwg.org/#this)'s [response](#response) to a [network error](https://fetch.spec.whatwg.org/#concept-network-error).

    - Set [this](https://webidl.spec.whatwg.org/#this)'s [received bytes](#received-bytes) to the empty byte sequence.

    - Set [this](https://webidl.spec.whatwg.org/#this)'s [response object](#response-object) to null.

    [Override MIME type](#override-mime-type) is not overridden here as the `overrideMimeType()` method can be invoked before the `open()` method.

12. If [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) is not *opened*, then:

    1.  Set [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) to *opened*.

    2.  [Fire an event](https://dom.spec.whatwg.org/#concept-event-fire) named [`readystatechange`](#event-xhr-readystatechange) at [this](https://webidl.spec.whatwg.org/#this).

The reason there are two `open()` methods defined is due to a limitation of the editing software used to write the XMLHttpRequest Standard.


#### The `setRequestHeader()` method

`client . setRequestHeader(name, value)`

:   Appends a value to an existing request header or adds a new request header.

    Throws an "[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if either [state](#concept-xmlhttprequest-state) is not *opened* or the [`send()` flag](#send-flag) is set.

    Throws a "[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if `name` is not a header name or if `value` is not a header value.

The `setRequestHeader(name, value)` method must run these steps:

1.  If [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) is not *opened*, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) an "[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2.  If [this](https://webidl.spec.whatwg.org/#this)'s [`send()` flag](#send-flag) is set, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) an "[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3.  [Normalize](https://fetch.spec.whatwg.org/#concept-header-value-normalize) `value`.

4.  If `name` is not a [header name](https://fetch.spec.whatwg.org/#header-name) or `value` is not a [header value](https://fetch.spec.whatwg.org/#header-value), then [throw](https://webidl.spec.whatwg.org/#dfn-throw) a "[`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

    An empty byte sequence represents an empty [header value](https://fetch.spec.whatwg.org/#header-value).

5.  If (`name`, `value`) is a [forbidden request-header](https://fetch.spec.whatwg.org/#forbidden-request-header), then return.

6.  [Combine](https://fetch.spec.whatwg.org/#concept-header-list-combine) (`name`, `value`) in [this](https://webidl.spec.whatwg.org/#this)'s [author request headers](#author-request-headers).

Some simple code demonstrating what happens when setting the same header twice:

```javascript
// The following script:
var client = new XMLHttpRequest();
client.open('GET', 'demo.cgi');
client.setRequestHeader('X-Test', 'one');
client.setRequestHeader('X-Test', 'two');
client.send();

// …results in the following header being sent:
// X-Test: one, two
```


#### The `timeout` getter and setter

`client . timeout`

:   Can be set to a time in milliseconds. When set to a non-zero value will cause [fetching](https://fetch.spec.whatwg.org/#concept-fetch) to terminate after the given time has passed. When the time has passed, the request has not yet completed, and [this](https://webidl.spec.whatwg.org/#this)'s [synchronous flag](#synchronous-flag) is unset, a [`timeout`](#event-xhr-timeout) event will then be [dispatched](https://dom.spec.whatwg.org/#concept-event-dispatch), or a "[`TimeoutError`](https://webidl.spec.whatwg.org/#timeouterror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) will be [thrown](https://webidl.spec.whatwg.org/#dfn-throw) otherwise (for the [`send()`](#dom-xmlhttprequest-send) method).

    When set: throws an "[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if the [synchronous flag](#synchronous-flag) is set and the [current global object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object) is a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object.

The `timeout` getter steps are to return [this](https://webidl.spec.whatwg.org/#this)'s [timeout](#timeout).

The `timeout` setter steps are:

1.  If the [current global object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object) is a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object and [this](https://webidl.spec.whatwg.org/#this)'s [synchronous flag](#synchronous-flag) is set, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) an "[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2.  Set [this](https://webidl.spec.whatwg.org/#this)'s [timeout](#timeout) to the given value.

This implies that the `timeout` attribute can be set while [fetching](https://fetch.spec.whatwg.org/#concept-fetch) is in progress. If that occurs it will still be measured relative to the start of [fetching](https://fetch.spec.whatwg.org/#concept-fetch).


#### The `withCredentials` getter and setter

`client . withCredentials`

:   True when [credentials](https://fetch.spec.whatwg.org/#credentials) are to be included in a cross-origin request. False when they are to be excluded in a cross-origin request and when cookies are to be ignored in its response. Initially false.

    When set: throws an "[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if [state](#concept-xmlhttprequest-state) is not *unsent* or *opened*, or if the [`send()` flag](#send-flag) is set.

The `withCredentials` getter steps are to return [this](https://webidl.spec.whatwg.org/#this)'s [cross-origin credentials](#cross-origin-credentials).

The `withCredentials` setter steps are:

1.  If [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) is not *unsent* or *opened*, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) an "[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2.  If [this](https://webidl.spec.whatwg.org/#this)'s [`send()` flag](#send-flag) is set, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) an "[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3.  Set [this](https://webidl.spec.whatwg.org/#this)'s [cross-origin credentials](#cross-origin-credentials) to the given value.


#### The `upload` getter

`client . upload`

:   Returns the associated [`XMLHttpRequestUpload`](#xmlhttprequestupload) object. It can be used to gather transmission information when data is transferred to a server.

The `upload` getter steps are to return [this](https://webidl.spec.whatwg.org/#this)'s [upload object](#upload-object).


#### The `send()` method

`client . send([body = null])`

:   Initiates the request. The `body` argument provides the [request body](#request-body), if any, and is ignored if the [request method](#request-method) is `GET` or `HEAD`.

    Throws an "[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) if either [state](#concept-xmlhttprequest-state) is not *opened* or the [`send()` flag](#send-flag) is set.

The `send(body)` method steps are:

1.  If [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) is not *opened*, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) an "[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2.  If [this](https://webidl.spec.whatwg.org/#this)'s [`send()` flag](#send-flag) is set, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) an "[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3.  If [this](https://webidl.spec.whatwg.org/#this)'s [request method](#request-method) is `GET` or `HEAD`, then set `body` to null.

4.  If `body` is not null, then:

    1.  Let `extractedContentType` be null.

    2.  If `body` is a [`Document`](https://dom.spec.whatwg.org/#document), then set [this](https://webidl.spec.whatwg.org/#this)'s [request body](#request-body) to `body`, [serialized](https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#fragment-serializing-algorithm-steps), [converted](https://infra.spec.whatwg.org/#javascript-string-convert), and [UTF-8 encoded](https://encoding.spec.whatwg.org/#utf-8-encode).

    3.  Otherwise:

        1.  Let `bodyWithType` be the result of [safely extracting](https://fetch.spec.whatwg.org/#bodyinit-safely-extract) `body`.

        2.  Set [this](https://webidl.spec.whatwg.org/#this)'s [request body](#request-body) to `bodyWithType`'s [body](https://fetch.spec.whatwg.org/#body-with-type-body).

        3.  Set `extractedContentType` to `bodyWithType`'s [type](https://fetch.spec.whatwg.org/#body-with-type-type).

    4.  Let `originalAuthorContentType` be the result of [getting](https://fetch.spec.whatwg.org/#concept-header-list-get) `Content-Type` from [this](https://webidl.spec.whatwg.org/#this)'s [author request headers](#author-request-headers).

    5.  If `originalAuthorContentType` is non-null, then:

        1.  If `body` is a [`Document`](https://dom.spec.whatwg.org/#document) or a [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString), then:

            1.  Let `contentTypeRecord` be the result of [parsing](https://mimesniff.spec.whatwg.org/#parse-a-mime-type-from-bytes) `originalAuthorContentType`.

            2.  If `contentTypeRecord` is not failure, `contentTypeRecord`'s [parameters](https://mimesniff.spec.whatwg.org/#parameters)["`charset`"] [exists](https://infra.spec.whatwg.org/#map-exists), and [parameters](https://mimesniff.spec.whatwg.org/#parameters)["`charset`"] is not an [ASCII case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for "`UTF-8`", then:

                1.  [Set](https://infra.spec.whatwg.org/#map-set) `contentTypeRecord`'s [parameters](https://mimesniff.spec.whatwg.org/#parameters)["`charset`"] to "`UTF-8`".

                2.  Let `newContentTypeSerialized` be the result of [serializing](https://mimesniff.spec.whatwg.org/#serialize-a-mime-type-to-bytes) `contentTypeRecord`.

                3.  [Set](https://fetch.spec.whatwg.org/#concept-header-list-set) (`Content-Type`, `newContentTypeSerialized`) in [this](https://webidl.spec.whatwg.org/#this)'s [author request headers](#author-request-headers).

    6.  Otherwise:

        1.  If `body` is an [HTML document](https://dom.spec.whatwg.org/#html-document), then [set](https://fetch.spec.whatwg.org/#concept-header-list-set) (`Content-Type`, `text/html;charset=UTF-8`) in [this](https://webidl.spec.whatwg.org/#this)'s [author request headers](#author-request-headers).

        2.  Otherwise, if `body` is an [XML document](https://dom.spec.whatwg.org/#xml-document), [set](https://fetch.spec.whatwg.org/#concept-header-list-set) (`Content-Type`, `application/xml;charset=UTF-8`) in [this](https://webidl.spec.whatwg.org/#this)'s [author request headers](#author-request-headers).

        3.  Otherwise, if `extractedContentType` is not null, [set](https://fetch.spec.whatwg.org/#concept-header-list-set) (`Content-Type`, `extractedContentType`) in [this](https://webidl.spec.whatwg.org/#this)'s [author request headers](#author-request-headers).

5.  If one or more event listeners are registered on [this](https://webidl.spec.whatwg.org/#this)'s [upload object](#upload-object), then set [this](https://webidl.spec.whatwg.org/#this)'s [upload listener flag](#upload-listener-flag).

6.  Let `req` be a new [request](https://fetch.spec.whatwg.org/#concept-request), initialized as follows:

    [method](https://fetch.spec.whatwg.org/#concept-request-method)
    :   [This](https://webidl.spec.whatwg.org/#this)'s [request method](#request-method).

    [URL](https://fetch.spec.whatwg.org/#concept-request-url)
    :   [This](https://webidl.spec.whatwg.org/#this)'s [request URL](#request-url).

    [header list](https://fetch.spec.whatwg.org/#concept-request-header-list)
    :   [This](https://webidl.spec.whatwg.org/#this)'s [author request headers](#author-request-headers).

    [unsafe-request flag](https://fetch.spec.whatwg.org/#unsafe-request-flag)
    :   Set.

    [body](https://fetch.spec.whatwg.org/#concept-request-body)
    :   [This](https://webidl.spec.whatwg.org/#this)'s [request body](#request-body).

    [client](https://fetch.spec.whatwg.org/#concept-request-client)
    :   [This](https://webidl.spec.whatwg.org/#this)'s [relevant settings object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

    [mode](https://fetch.spec.whatwg.org/#concept-request-mode)
    :   "`cors`".

    [use-CORS-preflight flag](https://fetch.spec.whatwg.org/#use-cors-preflight-flag)
    :   Set if [this](https://webidl.spec.whatwg.org/#this)'s [upload listener flag](#upload-listener-flag) is set.

    [credentials mode](https://fetch.spec.whatwg.org/#concept-request-credentials-mode)
    :   If [this](https://webidl.spec.whatwg.org/#this)'s [cross-origin credentials](#cross-origin-credentials) is true, then "`include`"; otherwise "`same-origin`".

    [use-URL-credentials flag](https://fetch.spec.whatwg.org/#concept-request-use-url-credentials-flag)
    :   Set if [this](https://webidl.spec.whatwg.org/#this)'s [request URL](#request-url) [includes credentials](https://url.spec.whatwg.org/#include-credentials).

    [initiator type](https://fetch.spec.whatwg.org/#request-initiator-type)
    :   "`xmlhttprequest`".

7.  Unset [this](https://webidl.spec.whatwg.org/#this)'s [upload complete flag](#upload-complete-flag).

8.  Unset [this](https://webidl.spec.whatwg.org/#this)'s [timed out flag](#timed-out-flag).

9.  If `req`'s [body](https://fetch.spec.whatwg.org/#concept-request-body) is null, then set [this](https://webidl.spec.whatwg.org/#this)'s [upload complete flag](#upload-complete-flag).

10. Set [this](https://webidl.spec.whatwg.org/#this)'s [`send()` flag](#send-flag).

11. If [this](https://webidl.spec.whatwg.org/#this)'s [synchronous flag](#synchronous-flag) is unset, then:

    1.  [Fire a progress event](#concept-event-fire-progress) named [`loadstart`](#event-xhr-loadstart) at [this](https://webidl.spec.whatwg.org/#this) with 0 and 0.

    2.  Let `requestBodyTransmitted` be 0.

    3.  Let `requestBodyLength` be `req`'s [body](https://fetch.spec.whatwg.org/#concept-request-body)'s [length](https://fetch.spec.whatwg.org/#concept-body-total-bytes), if `req`'s [body](https://fetch.spec.whatwg.org/#concept-request-body) is non-null; otherwise 0.

    4.  Assert: `requestBodyLength` is an integer.

    5.  If [this](https://webidl.spec.whatwg.org/#this)'s [upload complete flag](#upload-complete-flag) is unset and [this](https://webidl.spec.whatwg.org/#this)'s [upload listener flag](#upload-listener-flag) is set, then [fire a progress event](#concept-event-fire-progress) named [`loadstart`](#event-xhr-loadstart) at [this](https://webidl.spec.whatwg.org/#this)'s [upload object](#upload-object) with `requestBodyTransmitted` and `requestBodyLength`.

    6.  If [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) is not *opened* or [this](https://webidl.spec.whatwg.org/#this)'s [`send()` flag](#send-flag) is unset, then return.

    7.  Let `processRequestBodyChunkLength`, given a `bytesLength`, be these steps:

        1.  Increase `requestBodyTransmitted` by `bytesLength`.

        2.  If not roughly 50ms have passed since these steps were last invoked, then return.

        3.  If [this](https://webidl.spec.whatwg.org/#this)'s [upload listener flag](#upload-listener-flag) is set, then [fire a progress event](#concept-event-fire-progress) named [`progress`](#event-xhr-progress) at [this](https://webidl.spec.whatwg.org/#this)'s [upload object](#upload-object) with `requestBodyTransmitted` and `requestBodyLength`.

        These steps are only invoked when new bytes are transmitted.

    8.  Let `processRequestEndOfBody` be these steps:

        1.  Set [this](https://webidl.spec.whatwg.org/#this)'s [upload complete flag](#upload-complete-flag).

        2.  If [this](https://webidl.spec.whatwg.org/#this)'s [upload listener flag](#upload-listener-flag) is unset, then return.

        3.  [Fire a progress event](#concept-event-fire-progress) named [`progress`](#event-xhr-progress) at [this](https://webidl.spec.whatwg.org/#this)'s [upload object](#upload-object) with `requestBodyTransmitted` and `requestBodyLength`.

        4.  [Fire a progress event](#concept-event-fire-progress) named [`load`](#event-xhr-load) at [this](https://webidl.spec.whatwg.org/#this)'s [upload object](#upload-object) with `requestBodyTransmitted` and `requestBodyLength`.

        5.  [Fire a progress event](#concept-event-fire-progress) named [`loadend`](#event-xhr-loadend) at [this](https://webidl.spec.whatwg.org/#this)'s [upload object](#upload-object) with `requestBodyTransmitted` and `requestBodyLength`.

    9.  Let `processResponse`, given a `response`, be these steps:

        1.  Set [this](https://webidl.spec.whatwg.org/#this)'s [response](#response) to `response`.

        2.  [Handle errors](#handle-errors) for [this](https://webidl.spec.whatwg.org/#this).

        3.  If [this](https://webidl.spec.whatwg.org/#this)'s [response](#response) is a [network error](https://fetch.spec.whatwg.org/#concept-network-error), then return.

        4.  Set [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) to *headers received*.

        5.  [Fire an event](https://dom.spec.whatwg.org/#concept-event-fire) named [`readystatechange`](#event-xhr-readystatechange) at [this](https://webidl.spec.whatwg.org/#this).

        6.  If [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) is not *headers received*, then return.

        7.  If [this](https://webidl.spec.whatwg.org/#this)'s [response](#response)'s [body](https://fetch.spec.whatwg.org/#concept-response-body) is null, then run [handle response end-of-body](#handle-response-end-of-body) for [this](https://webidl.spec.whatwg.org/#this) and return.

        8.  Let `length` be the result of [extracting a length](https://fetch.spec.whatwg.org/#header-list-extract-a-length) from [this](https://webidl.spec.whatwg.org/#this)'s [response](#response)'s [header list](https://fetch.spec.whatwg.org/#concept-response-header-list).

        9.  If `length` is not an integer, then set it to 0.

        10. Let `processBodyChunk` given `bytes` be these steps:

            1.  Append `bytes` to [this](https://webidl.spec.whatwg.org/#this)'s [received bytes](#received-bytes).

            2.  If not roughly 50ms have passed since these steps were last invoked, then return.

            3.  If [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) is *headers received*, then set [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) to *loading*.

            4.  [Fire an event](https://dom.spec.whatwg.org/#concept-event-fire) named [`readystatechange`](#event-xhr-readystatechange) at [this](https://webidl.spec.whatwg.org/#this).

                Web compatibility is the reason [`readystatechange`](#event-xhr-readystatechange) fires more often than [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) changes.

            5.  [Fire a progress event](#concept-event-fire-progress) named [`progress`](#event-xhr-progress) at [this](https://webidl.spec.whatwg.org/#this) with [this](https://webidl.spec.whatwg.org/#this)'s [received bytes](#received-bytes)'s [length](https://infra.spec.whatwg.org/#byte-sequence-length) and `length`.

        11. Let `processEndOfBody` be this step: run [handle response end-of-body](#handle-response-end-of-body) for [this](https://webidl.spec.whatwg.org/#this).

        12. Let `processBodyError` be these steps:

            1.  Set [this](https://webidl.spec.whatwg.org/#this)'s [response](#response) to a [network error](https://fetch.spec.whatwg.org/#concept-network-error).

            2.  Run [handle errors](#handle-errors) for [this](https://webidl.spec.whatwg.org/#this).

        13. [Incrementally read](https://fetch.spec.whatwg.org/#body-incrementally-read) [this](https://webidl.spec.whatwg.org/#this)'s [response](#response)'s [body](https://fetch.spec.whatwg.org/#concept-response-body), given `processBodyChunk`, `processEndOfBody`, `processBodyError`, and [this](https://webidl.spec.whatwg.org/#this)'s [relevant global object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

    10. Set [this](https://webidl.spec.whatwg.org/#this)'s [fetch controller](#xmlhttprequest-fetch-controller) to the result of [fetching](https://fetch.spec.whatwg.org/#concept-fetch) `req` with [*processRequestBodyChunkLength*](https://fetch.spec.whatwg.org/#process-request-body) set to `processRequestBodyChunkLength`, [*processRequestEndOfBody*](https://fetch.spec.whatwg.org/#process-request-end-of-body) set to `processRequestEndOfBody`, and [*processResponse*](https://fetch.spec.whatwg.org/#process-response) set to `processResponse`.

    11. Let `now` be the present time.

    12. Run these steps [in parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

        1.  Wait until either `req`'s [done flag](https://fetch.spec.whatwg.org/#done-flag) is set or [this](https://webidl.spec.whatwg.org/#this)'s [timeout](#timeout) is not 0 and [this](https://webidl.spec.whatwg.org/#this)'s [timeout](#timeout) milliseconds have passed since `now`.

        2.  If `req`'s [done flag](https://fetch.spec.whatwg.org/#done-flag) is unset, then set [this](https://webidl.spec.whatwg.org/#this)'s [timed out flag](#timed-out-flag) and [terminate](https://fetch.spec.whatwg.org/#fetch-controller-terminate) [this](https://webidl.spec.whatwg.org/#this)'s [fetch controller](#xmlhttprequest-fetch-controller).

12. Otherwise, if [this](https://webidl.spec.whatwg.org/#this)'s [synchronous flag](#synchronous-flag) is set:

    1.  Let `processedResponse` be false.

    2.  Let `processResponseConsumeBody`, given a `response` and `nullOrFailureOrBytes`, be these steps:

        1.  If `nullOrFailureOrBytes` is not failure, then set [this](https://webidl.spec.whatwg.org/#this)'s [response](#response) to `response`.

        2.  If `nullOrFailureOrBytes` is a [byte sequence](https://infra.spec.whatwg.org/#byte-sequence), then append `nullOrFailureOrBytes` to [this](https://webidl.spec.whatwg.org/#this)'s [received bytes](#received-bytes).

        3.  Set `processedResponse` to true.

    3.  Set [this](https://webidl.spec.whatwg.org/#this)'s [fetch controller](#xmlhttprequest-fetch-controller) to the result of [fetching](https://fetch.spec.whatwg.org/#concept-fetch) `req` with [*processResponseConsumeBody*](https://fetch.spec.whatwg.org/#process-response-end-of-body) set to `processResponseConsumeBody` and [*useParallelQueue*](https://fetch.spec.whatwg.org/#fetch-useparallelqueue) set to true.

    4.  Let `now` be the present time.

    5.  [Pause](https://html.spec.whatwg.org/multipage/webappapis.html#pause) until either `processedResponse` is true or [this](https://webidl.spec.whatwg.org/#this)'s [timeout](#timeout) is not 0 and [this](https://webidl.spec.whatwg.org/#this)'s [timeout](#timeout) milliseconds have passed since `now`.

    6.  If `processedResponse` is false, then set [this](https://webidl.spec.whatwg.org/#this)'s [timed out flag](#timed-out-flag) and [terminate](https://fetch.spec.whatwg.org/#fetch-controller-terminate) [this](https://webidl.spec.whatwg.org/#this)'s [fetch controller](#xmlhttprequest-fetch-controller).

    7.  [Report timing](https://fetch.spec.whatwg.org/#finalize-and-report-timing) for [this](https://webidl.spec.whatwg.org/#this)'s [fetch controller](#xmlhttprequest-fetch-controller) given the [current global object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object).

    8.  Run [handle response end-of-body](#handle-response-end-of-body) for [this](https://webidl.spec.whatwg.org/#this).

To [handle response end-of-body](#handle-response-end-of-body) for an [`XMLHttpRequest`](#xmlhttprequest) object `xhr`, run these steps:

1.  [Handle errors](#handle-errors) for `xhr`.

2.  If `xhr`'s [response](#response) is a [network error](https://fetch.spec.whatwg.org/#concept-network-error), then return.

3.  Let `transmitted` be `xhr`'s [received bytes](#received-bytes)'s [length](https://infra.spec.whatwg.org/#byte-sequence-length).

4.  Let `length` be the result of [extracting a length](https://fetch.spec.whatwg.org/#header-list-extract-a-length) from [this](https://webidl.spec.whatwg.org/#this)'s [response](#response)'s [header list](https://fetch.spec.whatwg.org/#concept-response-header-list).

5.  If `length` is not an integer, then set it to 0.

6.  If `xhr`'s [synchronous flag](#synchronous-flag) is unset, then [fire a progress event](#concept-event-fire-progress) named [`progress`](#event-xhr-progress) at `xhr` with `transmitted` and `length`.

7.  Set `xhr`'s [state](#concept-xmlhttprequest-state) to *done*.

8.  Unset `xhr`'s [`send()` flag](#send-flag).

9.  [Fire an event](https://dom.spec.whatwg.org/#concept-event-fire) named [`readystatechange`](#event-xhr-readystatechange) at `xhr`.

10. [Fire a progress event](#concept-event-fire-progress) named [`load`](#event-xhr-load) at `xhr` with `transmitted` and `length`.

11. [Fire a progress event](#concept-event-fire-progress) named [`loadend`](#event-xhr-loadend) at `xhr` with `transmitted` and `length`.

To [handle errors](#handle-errors) for an [`XMLHttpRequest`](#xmlhttprequest) object `xhr`, run these steps:

1.  If `xhr`'s [`send()` flag](#send-flag) is unset, then return.

2.  If `xhr`'s [timed out flag](#timed-out-flag) is set, then run the [request error steps](#request-error-steps) for `xhr`, [`timeout`](#event-xhr-timeout), and "[`TimeoutError`](https://webidl.spec.whatwg.org/#timeouterror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3.  Otherwise, if `xhr`'s [response](#response)'s [aborted flag](https://fetch.spec.whatwg.org/#concept-response-aborted) is set, run the [request error steps](#request-error-steps) for `xhr`, [`abort`](#event-xhr-abort), and "[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4.  Otherwise, if `xhr`'s [response](#response) is a [network error](https://fetch.spec.whatwg.org/#concept-network-error), then run the [request error steps](#request-error-steps) for `xhr`, [`error`](#event-xhr-error), and "[`NetworkError`](https://webidl.spec.whatwg.org/#networkerror)" [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

The [request error steps](#request-error-steps) for an [`XMLHttpRequest`](#xmlhttprequest) object `xhr`, `event`, and optionally `exception` are:

1.  Set `xhr`'s [state](#concept-xmlhttprequest-state) to *done*.

2.  Unset `xhr`'s [`send()` flag](#send-flag).

3.  Set `xhr`'s [response](#response) to a [network error](https://fetch.spec.whatwg.org/#concept-network-error).

4.  If `xhr`'s [synchronous flag](#synchronous-flag) is set, then [throw](https://webidl.spec.whatwg.org/#dfn-throw) `exception`.

5.  [Fire an event](https://dom.spec.whatwg.org/#concept-event-fire) named [`readystatechange`](#event-xhr-readystatechange) at `xhr`.

    At this point it is clear that `xhr`'s [synchronous flag](#synchronous-flag) is unset.

6.  If `xhr`'s [upload complete flag](#upload-complete-flag) is unset, then:

    1.  Set `xhr`'s [upload complete flag](#upload-complete-flag).

    2.  If `xhr`'s [upload listener flag](#upload-listener-flag) is set, then:

        1.  [Fire a progress event](#concept-event-fire-progress) named `event` at `xhr`'s [upload object](#upload-object) with 0 and 0.

        2.  [Fire a progress event](#concept-event-fire-progress) named [`loadend`](#event-xhr-loadend) at `xhr`'s [upload object](#upload-object) with 0 and 0.

7.  [Fire a progress event](#concept-event-fire-progress) named `event` at `xhr` with 0 and 0.

8.  [Fire a progress event](#concept-event-fire-progress) named [`loadend`](#event-xhr-loadend) at `xhr` with 0 and 0.


#### The `abort()` method

`client . abort()`
:   Cancels any network activity.

The `abort()` method steps are:

1.  [Abort](https://fetch.spec.whatwg.org/#fetch-controller-abort) [this](https://webidl.spec.whatwg.org/#this)'s [fetch controller](#xmlhttprequest-fetch-controller).

2.  If [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) is *opened* with [this](https://webidl.spec.whatwg.org/#this)'s [`send()` flag](#send-flag) set, *headers received*, or *loading*, then run the [request error steps](#request-error-steps) for [this](https://webidl.spec.whatwg.org/#this) and [`abort`](#event-xhr-abort).

3.  If [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) is *done*, then set [this](https://webidl.spec.whatwg.org/#this)'s [state](#concept-xmlhttprequest-state) to *unsent* and [this](https://webidl.spec.whatwg.org/#this)'s [response](#response) to a [network error](https://fetch.spec.whatwg.org/#concept-network-error).

    No [`readystatechange`](#event-xhr-readystatechange) event is dispatched.


### Response


#### The `responseURL` getter

The `responseURL` getter steps are to return the empty string if this's response's URL is null; otherwise its serialization with the *exclude fragment flag* set.


#### The `status` getter

The `status` getter steps are to return this's response's status.


#### The `statusText` getter

The `statusText` getter steps are to return this's response's status message.


#### The `getResponseHeader()` method

The `getResponseHeader(name)` method steps are to return the result of getting `name` from this's response's header list.

The Fetch Standard filters this's response's header list. [\[FETCH\]](#biblio-fetch)

For the following script:

```javascript
var client = new XMLHttpRequest();
client.open("GET", "unicorns-are-awesome.txt", true);
client.send();
client.onreadystatechange = function() {
  if(this.readyState == this.HEADERS_RECEIVED) {
    print(client.getResponseHeader("Content-Type"));
  }
}
```

The `print()` function will get to process something like:

    text/plain; charset=UTF-8


#### The `getAllResponseHeaders()` method

A byte sequence `a` is **legacy-uppercased-byte less than** a byte sequence `b` if the following steps return true:

1. Let `A` be `a`, byte-uppercased.

2. Let `B` be `b`, byte-uppercased.

3. Return `A` is byte less than `B`.

The `getAllResponseHeaders()` method steps are:

1. Let `output` be an empty byte sequence.

2. Let `initialHeaders` be the result of running sort and combine with this's response's header list.

3. Let `headers` be the result of sorting `initialHeaders` in ascending order, with `a` being less than `b` if `a`'s name is legacy-uppercased-byte less than `b`'s name.

   Unfortunately, this is needed for compatibility with deployed content.

4. For each `header` in `headers`, append `header`'s name, followed by a 0x3A 0x20 byte pair, followed by `header`'s value, followed by a 0x0D 0x0A byte pair, to `output`.

5. Return `output`.

The Fetch Standard filters this's response's header list. [\[FETCH\]](#biblio-fetch)

For the following script:

```javascript
var client = new XMLHttpRequest();
client.open("GET", "narwhals-too.txt", true);
client.send();
client.onreadystatechange = function() {
  if(this.readyState == this.HEADERS_RECEIVED) {
    print(this.getAllResponseHeaders());
  }
}
```

The `print()` function will get to process something like:

    connection: Keep-Alive
    content-type: text/plain; charset=utf-8
    date: Sun, 24 Oct 2004 04:58:38 GMT
    keep-alive: timeout=15, max=99
    server: Apache/1.3.31 (Unix)
    transfer-encoding: chunked


#### Response body

To **get a response MIME type** for an `XMLHttpRequest` object `xhr`, run these steps:

1. Let `mimeType` be the result of extracting a MIME type from `xhr`'s response's header list.

2. If `mimeType` is failure, then set `mimeType` to `text/xml`.

3. Return `mimeType`.

To **get a final MIME type** for an `XMLHttpRequest` object `xhr`, run these steps:

1. If `xhr`'s override MIME type is null, return the result of get a response MIME type for `xhr`.

2. Return `xhr`'s override MIME type.

To **get a final encoding** for an `XMLHttpRequest` object `xhr`, run these steps:

1. Let `label` be null.

2. Let `responseMIME` be the result of get a response MIME type for `xhr`.

3. If `responseMIME`'s parameters\["`charset`"\] exists, then set `label` to it.

4. If `xhr`'s override MIME type's parameters\["`charset`"\] exists, then set `label` to it.

5. If `label` is null, then return null.

6. Let `encoding` be the result of getting an encoding from `label`.

7. If `encoding` is failure, then return null.

8. Return `encoding`.

The above steps intentionally do not use the get a final MIME type as it would not be web compatible.


To **set a document response** for an `XMLHttpRequest` object `xhr`, run these steps:

1. If `xhr`'s response's body is null, then return.

2. Let `finalMIME` be the result of get a final MIME type for `xhr`.

3. If `finalMIME` is not an HTML MIME type or an XML MIME type, then return.

4. If `xhr`'s response type is the empty string and `finalMIME` is an HTML MIME type, then return.

   This is restricted to `xhr`'s response type being "`document`" in order to prevent breaking legacy content.

5. If `finalMIME` is an HTML MIME type, then:

   1. Let `charset` be the result of get a final encoding for `xhr`.

   2. If `charset` is null, prescan the first 1024 bytes of `xhr`'s received bytes and if that does not terminate unsuccessfully then let `charset` be the return value.

   3. If `charset` is null, then set `charset` to UTF-8.

   4. Let `document` be a document that represents the result parsing `xhr`'s received bytes following the rules set forth in the HTML Standard for an HTML parser with scripting disabled and a known definite encoding `charset`. [\[HTML\]](#biblio-html)

   5. Flag `document` as an HTML document.

6. Otherwise, let `document` be a document that represents the result of running the XML parser with XML scripting support disabled on `xhr`'s received bytes. If that fails (unsupported character encoding, namespace well-formedness error, etc.), then return null. [\[HTML\]](#biblio-html)

   Resources referenced will not be loaded and no associated XSLT will be applied.

7. If `charset` is null, then set `charset` to UTF-8.

8. Set `document`'s encoding to `charset`.

9. Set `document`'s content type to `finalMIME`.

10. Set `document`'s URL to `xhr`'s response's URL.

11. Set `document`'s origin to `xhr`'s relevant settings object's origin.

12. Set `xhr`'s response object to `document`.

To **get a text response** for an `XMLHttpRequest` object `xhr`, run these steps:

1. If `xhr`'s response's body is null, then return the empty string.

2. Let `charset` be the result of get a final encoding for `xhr`.

3. If `xhr`'s response type is the empty string, `charset` is null, and the result of get a final MIME type for `xhr` is an XML MIME type, then use the rules set forth in the XML specifications to determine the encoding. Let `charset` be the determined encoding. [\[XML\]](#biblio-xml) [\[XML-NAMES\]](#biblio-xml-names)

   This is restricted to `xhr`'s response type being the empty string to keep the non-legacy response type value "`text`" simple.

4. If `charset` is null, then set `charset` to UTF-8.

5. Return the result of running decode on `xhr`'s received bytes using fallback encoding `charset`.

Authors are strongly encouraged to always encode their resources using UTF-8.


#### The `overrideMimeType()` method

`client . overrideMimeType(mime)`

:   Acts as if the \``Content-Type`\` header value for a response is `mime`. (It does not change the header.)

    Throws an "`InvalidStateError`" `DOMException` if state is *loading* or *done*.

The `overrideMimeType(mime)` method steps are:

1. If this's state is *loading* or *done*, then throw an "`InvalidStateError`" `DOMException`.

2. Set this's override MIME type to the result of parsing `mime`.

3. If this's override MIME type is failure, then set this's override MIME type to `application/octet-stream`.


#### The `responseType` getter and setter

`client . responseType [ = value ]`

:   Returns the response type.

    Can be set to change the response type. Values are: the empty string (default), "`arraybuffer`", "`blob`", "`document`", "`json`", and "`text`".

    When set: setting to "`document`" is ignored if the current global object is not a `Window` object.

    When set: throws an "`InvalidStateError`" `DOMException` if state is *loading* or *done*.

    When set: throws an "`InvalidAccessError`" `DOMException` if the synchronous flag is set and the current global object is a `Window` object.

The `responseType` getter steps are to return this's response type.

The `responseType` setter steps are:

1. If the current global object is not a `Window` object and the given value is "`document`", then return.

2. If this's state is *loading* or *done*, then throw an "`InvalidStateError`" `DOMException`.

3. If the current global object is a `Window` object and this's synchronous flag is set, then throw an "`InvalidAccessError`" `DOMException`.

4. Set this's response type to the given value.


#### The `response` getter

`client . response`

:   Returns the response body.

The `response` getter steps are:

1. If this's response type is the empty string or "`text`", then:

   1. If this's state is not *loading* or *done*, then return the empty string.

   2. Return the result of getting a text response for this.

2. If this's state is not *done*, then return null.

3. If this's response object is failure, then return null.

4. If this's response object is non-null, then return it.

5. If this's response type is "`arraybuffer`", then set this's response object to a new `ArrayBuffer` object representing this's received bytes. If this throws an exception, then set this's response object to failure and return null.

   Allocating an `ArrayBuffer` object is not guaranteed to succeed. [\[ECMASCRIPT\]](#biblio-ecmascript)

6. Otherwise, if this's response type is "`blob`", set this's response object to a new `Blob` object representing this's received bytes with `type` set to the result of get a final MIME type for this.

7. Otherwise, if this's response type is "`document`", set a document response for this.

8. Otherwise:

   1. Assert: this's response type is "`json`".

   2. If this's response's body is null, then return null.

   3. Let `jsonObject` be the result of running parse JSON from bytes on this's received bytes. If that threw an exception, then return null.

   4. Set this's response object to `jsonObject`.

9. Return this's response object.


#### The `responseText` getter

`client . responseText`

:   Returns response as text.

    Throws an "`InvalidStateError`" `DOMException` if `responseType` is not the empty string or "`text`".

The `responseText` getter steps are:

1. If this's response type is not the empty string or "`text`", then throw an "`InvalidStateError`" `DOMException`.

2. If this's state is not *loading* or *done*, then return the empty string.

3. Return the result of getting a text response for this.


#### The `responseXML` getter

`client . responseXML`

:   Returns the response as document.

    Throws an "`InvalidStateError`" `DOMException` if `responseType` is not the empty string or "`document`".

The `responseXML` getter steps are:

1. If this's response type is not the empty string or "`document`", then throw an "`InvalidStateError`" `DOMException`.

2. If this's state is not *done*, then return null.

3. Assert: this's response object is not failure.

4. If this's response object is non-null, then return it.

5. Set a document response for this.

6. Return this's response object.


### Events summary

*This section is non-normative.*

The following events are dispatched on `XMLHttpRequest` or `XMLHttpRequestUpload` objects:

Event name | Interface | Dispatched when...
-----------|-----------|-------------------
`readystatechange` | `Event` | The `readyState` attribute changes value, except when it changes to `UNSENT`.
`loadstart` | `ProgressEvent` | The fetch initiates.
`progress` | `ProgressEvent` | Transmitting data.
`abort` | `ProgressEvent` | When the fetch has been aborted. For instance, by invoking the `abort()` method.
`error` | `ProgressEvent` | The fetch failed.
`load` | `ProgressEvent` | The fetch succeeded.
`timeout` | `ProgressEvent` | The author specified timeout has passed before the fetch completed.
`loadend` | `ProgressEvent` | The fetch completed (success or failure).


## Interface `FormData`

```idl
typedef (File or USVString) FormDataEntryValue;

[Exposed=(Window,Worker)]
interface FormData {
  constructor(optional HTMLFormElement form, optional HTMLElement? submitter = null);

  undefined append(USVString name, USVString value);
  undefined append(USVString name, Blob blobValue, optional USVString filename);
  undefined delete(USVString name);
  FormDataEntryValue? get(USVString name);
  sequence<FormDataEntryValue> getAll(USVString name);
  boolean has(USVString name);
  undefined set(USVString name, USVString value);
  undefined set(USVString name, Blob blobValue, optional USVString filename);
  iterable<USVString, FormDataEntryValue>;
};
```

Each `FormData` object has an associated entry list (an entry list). It is initially empty.

This section used to define entry, an entry's name and value, and the create an entry algorithm. These definitions have been moved to the HTML Standard. [HTML]

The `new FormData(form, submitter)` constructor steps are:

1. If `form` is given, then:

    1. If `submitter` is non-null, then:

        1. If `submitter` is not a submit button, then throw a `TypeError`.

        2. If `submitter`'s form owner is not `form`, then throw a "`NotFoundError`" `DOMException`.

    2. Let `list` be the result of constructing the entry list for `form` and `submitter`.

    3. If `list` is null, then throw an "`InvalidStateError`" `DOMException`.

    4. Set this's entry list to `list`.

The `append(name, value)` and `append(name, blobValue, filename)` method steps are:

1. Let `value` be `value` if given; otherwise `blobValue`.

2. Let `entry` be the result of creating an entry with `name`, `value`, and `filename` if given.

3. Append `entry` to this's entry list.

The reason there is an argument named `value` as well as `blobValue` is due to a limitation of the editing software used to write the XMLHttpRequest Standard.

The `delete(name)` method steps are to remove all entries whose name is `name` from this's entry list.

The `get(name)` method steps are:

1. If there is no entry whose name is `name` in this's entry list, then return null.

2. Return the value of the first entry whose name is `name` from this's entry list.

The `getAll(name)` method steps are:

1. If there is no entry whose name is `name` in this's entry list, then return the empty list.

2. Return the values of all entries whose name is `name`, in order, from this's entry list.

The `has(name)` method steps are to return true if there is an entry whose name is `name` in this's entry list; otherwise false.

The `set(name, value)` and `set(name, blobValue, filename)` method steps are:

1. Let `value` be `value` if given; otherwise `blobValue`.

2. Let `entry` be the result of creating an entry with `name`, `value`, and `filename` if given.

3. If there are entries in this's entry list whose name is `name`, then replace the first such entry with `entry` and remove the others.

4. Otherwise, append `entry` to this's entry list.

The reason there is an argument named `value` as well as `blobValue` is due to a limitation of the editing software used to write the XMLHttpRequest Standard.

The value pairs to iterate over are this's entry list's entries with the key being the name and the value being the value.


## Interface `ProgressEvent`

```idl
[Exposed=(Window,Worker)]
interface ProgressEvent : Event {
  constructor(DOMString type, optional ProgressEventInit eventInitDict = {});

  readonly attribute boolean lengthComputable;
  readonly attribute double loaded;
  readonly attribute double total;
};

dictionary ProgressEventInit : EventInit {
  boolean lengthComputable = false;
  double loaded = 0;
  double total = 0;
};
```

Events using the `ProgressEvent` interface indicate some kind of progression.

The `lengthComputable`, `loaded`, and `total` getter steps are to return the value they were initialized to.


### Firing events using the `ProgressEvent` interface

To **fire a progress event** named `e` at `target`, given `transmitted` and `length`, means to [fire an event](https://dom.spec.whatwg.org/#concept-event-fire) named `e` at `target`, using `ProgressEvent`, with the `loaded` attribute initialized to `transmitted`, and if `length` is not 0, with the `lengthComputable` attribute initialized to true and the `total` attribute initialized to `length`.


### Suggested names for events using the `ProgressEvent` interface

*This section is non-normative.*

The suggested `type` attribute values for use with events using the `ProgressEvent` interface are summarized in the table below. Specification editors are free to tune the details to their specific scenarios, though are strongly encouraged to discuss their usage with the WHATWG community to ensure input from people familiar with the subject.

`type` attribute value | Description | Times | When
---|---|---|---
`loadstart` | Progress has begun. | Once. | First.
`progress` | In progress. | Once or more. | After `loadstart` has been dispatched.
`error` | Progression failed. | Zero or once (mutually exclusive). | After the last `progress` has been dispatched.
`abort` | Progression is terminated. | | 
`timeout` | Progression is terminated due to preset time expiring. | | 
`load` | Progression is successful. | | 
`loadend` | Progress has stopped. | Once. | After one of `error`, `abort`, `timeout` or `load` has been dispatched.

The `error`, `abort`, `timeout`, and `load` event types are mutually exclusive.

Throughout the web platform the `error`, `abort`, `timeout` and `load` event types have their `bubbles` and `cancelable` attributes initialized to false, so it is suggested that for consistency all events using the `ProgressEvent` interface do the same.


### Security considerations

For cross-origin requests some kind of opt-in, e.g., the [CORS protocol](https://fetch.spec.whatwg.org/#cors-protocol) defined in the Fetch Standard, has to be used before [events](https://w3c.github.io/webdriver-bidi/#event) using the `ProgressEvent` interface are [dispatched](https://dom.spec.whatwg.org/#concept-event-dispatch) as information (e.g., size) would be revealed that cannot be obtained otherwise. [FETCH]


### Example

In this example `XMLHttpRequest`, combined with concepts defined in the sections before, and the HTML `progress` element are used together to display the process of fetching a resource.

```html
<!DOCTYPE html>
<title>Waiting for Magical Unicorns</title>
<progress id=p></progress>
<script>
  var progressBar = document.getElementById("p"),
      client = new XMLHttpRequest()
  client.open("GET", "magical-unicorns")
  client.onprogress = function(pe) {
    if(pe.lengthComputable) {
      progressBar.max = pe.total
      progressBar.value = pe.loaded
    }
  }
  client.onloadend = function(pe) {
    progressBar.value = pe.loaded
  }
  client.send()
</script>
```

Fully working code would of course be more elaborate and deal with more scenarios, such as network errors or the end user terminating the request.