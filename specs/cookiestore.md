# Introduction

*This section is non-normative.*

This standard defines an asynchronous cookie API for scripts running in HTML documents and service workers.

HTTP cookies have, since their origins at Netscape [(documentation preserved by archive.org)](https://web.archive.org/web/0/http://wp.netscape.com/newsref/std/cookie_spec.html), provided a [valuable state-management mechanism](https://montulli.blogspot.com/2013/05/the-reasoning-behind-web-cookies.html) for the web.

The synchronous single-threaded script-level `document.cookie` interface to cookies has been a source of [complexity and performance woes](https://lists.w3.org/Archives/Public/public-whatwg-archive/2009Sep/0083.html) further exacerbated by the move in many browsers from:

- a single browser process,

- a single-threaded event loop model, and

- no general expectation of responsiveness for scripted event handling while processing cookie operations

... to the modern web which strives for smoothly responsive high performance:

- in multiple browser processes,

- with a multithreaded, multiple-event loop model, and

- with an expectation of responsiveness on human-reflex time scales.

On the modern web a cookie operation in one part of a web application cannot block:

- the rest of the web application,

- the rest of the web origin, or

- the browser as a whole.

Newer parts of the web built in service workers [need access to cookies too](https://github.com/w3c/ServiceWorker/issues/707) but cannot use the synchronous, blocking `document.cookie` interface at all as they both have no document and also cannot block the event loop as that would interfere with handling of unrelated events.


## Alternative to `document.cookie`

Today writing a cookie means blocking your event loop while waiting for the browser to synchronously update the cookie jar with a carefully-crafted cookie string in `Set-Cookie` format:

``` js
document.cookie =
  '__Secure-COOKIENAME=cookie-value' +
  '; Path=/' +
  '; expires=Fri, 12 Aug 2016 23:05:17 GMT' +
  '; Secure' +
  '; Domain=example.org';
// now we could assume the write succeeded, but since
// failure is silent it is difficult to tell, so we
// read to see whether the write succeeded
var successRegExp =
  /(^|; ?)__Secure-COOKIENAME=cookie-value(;|$)/;
if (String(document.cookie).match(successRegExp)) {
  console.log('It worked!');
} else {
  console.error('It did not work, and we do not know why');
}
```

What if you could instead write:

``` js
const one_day_ms = 24 * 60 * 60 * 1000;
cookieStore.set(
  {
    name: '__Secure-COOKIENAME',
    value: 'cookie-value',
    expires: Date.now() + one_day_ms,
    domain: 'example.org'
  }).then(function() {
    console.log('It worked!');
  }, function(reason) {
    console.error(
      'It did not work, and this is why:',
      reason);
  });
// Meanwhile we can do other things while waiting for
// the cookie store to process the write...
```

This also has the advantage of not relying on document and not blocking, which together make it usable from service workers, which otherwise do not have cookie access from script.

This standard also includes a power-efficient monitoring API to replace `setTimeout`-based polling cookie monitors with cookie change observers.


## Summary

In short, this API offers the following functionality:

- write (or "set") and delete (or "expire") cookies

- read (or "get") script-visible cookies

  - ... including for specified in-scope request paths in service worker contexts

- monitor script-visible cookies for changes using `CookieChangeEvent`

  - ... in long-running script contexts (e.g. `document`)

  - ... for script-supplied in-scope request paths in service worker contexts


## Querying cookies

Both documents and service workers access the same query API, via the `cookieStore` property on the global object.

The `get()` and `getAll()` methods on `CookieStore` are used to query cookies. Both methods return `Promise`s. Both methods take the same arguments, which can be either:

- a name, or

- a dictionary of options (optional for `getAll()`)

The `get()` method is essentially a form of `getAll()` that only returns the first result.

Reading a cookie:

``` js
try {
  const cookie = await cookieStore.get('session_id');
  if (cookie) {
    console.log(`Found ${cookie.name} cookie: ${cookie.value}`);
  } else {
    console.log('Cookie not found');
  }
} catch (e) {
  console.error(`Cookie store error: ${e}`);
}
```

Reading multiple cookies:

``` js
try {
  const cookies = await cookieStore.getAll('session_id'});
  for (const cookie of cookies)
    console.log(`Result: ${cookie.name} = ${cookie.value}`);
} catch (e) {
  console.error(`Cookie store error: ${e}`);
}
```

Service workers can obtain the list of cookies that would be sent by a fetch to any URL under their scope.

Read the cookies for a specific URL (in a service worker):

``` js
await cookieStore.getAll({url: '/admin'});
```

Documents can only obtain the cookies at their current URL. In other words, the only valid `url` value in Document contexts is the document's URL.

The objects returned by `get()` and `getAll()` contain all the relevant information in the cookie store, not just the name and the value as in the older `document.cookie` API.

Accessing all the cookie data:

``` js
await cookie = cookieStore.get('session_id');
console.log(`Cookie scope - Domain: ${cookie.domain} Path: ${cookie.path}`);
if (cookie.expires === null) {
  console.log('Cookie expires at the end of the session');
} else {
  console.log(`Cookie expires at: ${cookie.expires}`);
}
if (cookie.secure)
  console.log('The cookie is restricted to secure origins');
```


## Modifying cookies

Both documents and service workers access the same modification API, via the `cookieStore` property on the global object.

Cookies are created or modified (written) using the `set()` method.

Write a cookie:

``` js
try {
  await cookieStore.set('opted_out', '1');
} catch (e) {
  console.error(`Failed to set cookie: ${e}`);
}
```

The `set()` call above is shorthand for using an options dictionary, as follows:

``` js
await cookieStore.set({
  name: 'opted_out',
  value: '1',
  expires: null,  // session cookie

  // By default, domain is set to null which means the scope is locked at the current domain.
  domain: null,
  path: '/'
});
```

Cookies are deleted (expired) using the `delete()` method.

Delete a cookie:

``` js
try {
  await cookieStore.delete('session_id');
} catch (e) {
  console.error(`Failed to delete cookie: ${e}`);
}
```

Under the hood, deleting a cookie is done by changing the cookie's expiration date to the past, which still works.

Deleting a cookie by changing the expiry date:

``` js
try {
  const one_day_ms = 24 * 60 * 60 * 1000;
  await cookieStore.set({
    name: 'session_id',
    value: 'value will be ignored',
    expires: Date.now() - one_day_ms });
} catch (e) {
  console.error(`Failed to delete cookie: ${e}`);
}
```


## Monitoring cookies

To avoid polling, it is possible to observe changes to cookies.

In documents, `change` events are fired for all relevant cookie changes.

Register for `change` events in documents:

``` js
cookieStore.addEventListener('change', event => {
  console.log(`${event.changed.length} changed cookies`);
  for (const cookie in event.changed)
    console.log(`Cookie ${cookie.name} changed to ${cookie.value}`);

  console.log(`${event.deleted.length} deleted cookies`);
  for (const cookie in event.deleted)
    console.log(`Cookie ${cookie.name} deleted`);
});
```

In service workers, `cookiechange` events are fired against the global scope, but an explicit subscription is required, associated with the service worker's registration.

Register for `cookiechange` events in a service worker:

``` js
self.addEventListener('activate', (event) => {
  event.waitUntil(async () => {
    // Snapshot current state of subscriptions.
    const subscriptions = await self.registration.cookies.getSubscriptions();

    // Clear any existing subscriptions.
    await self.registration.cookies.unsubscribe(subscriptions);

    await self.registration.cookies.subscribe([
      {
        name: 'session_id',  // Get change events for cookies named session_id.
      }
    ]);
  });
});

self.addEventListener('cookiechange', event => {
  // The event has |changed| and |deleted| properties with
  // the same semantics as the Document events.
  console.log(`${event.changed.length} changed cookies`);
  console.log(`${event.deleted.length} deleted cookies`);
});
```

Calls to `subscribe()` are cumulative, so that independently maintained modules or libraries can set up their own subscriptions. As expected, a service worker's subscriptions are persisted for with the service worker registration.

Subscriptions can use the same options as `get()` and `getAll()`. The complexity of fine-grained subscriptions is justified by the cost of dispatching an irrelevant cookie change event to a service worker, which is much higher than the cost of dispatching an equivalent event to a `Window`. Specifically, dispatching an event to a service worker might require waking up the worker, which has a significant impact on battery life.

The `getSubscriptions()` allows a service worker to introspect the subscriptions that have been made.

Checking change subscriptions:

``` js
const subscriptions = await self.registration.cookies.getSubscriptions();
for (const sub of subscriptions) {
  console.log(sub.name, sub.url);
}
```


## Concepts


### Cookie

A cookie is normatively defined for user agents by [Cookies § User Agent Requirements](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-14#name-user-agent-requirements).

Per [Cookies § Storage Model](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-14#name-storage-model), a cookie has the following fields: name, value, domain, path, http-only-flag.

To normalize a cookie name or value given a string `input`: remove all U+0009 TAB and U+0020 SPACE that are at the start or end of `input`.

A cookie is script-visible when it is in-scope and its http-only-flag is unset. This is more formally enforced in the processing model, which consults [Cookies § Retrieval Model](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-14#name-retrieval-model) at appropriate points.

A cookie is also subject to certain size limits. Per [Cookies § Storage Model](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-14#name-storage-model):

- The combined lengths of the name and value fields must not be greater than 4096 bytes (the maximum name/value pair size).

- The length of every field except the name and value fields must not be greater than 1024 bytes (the maximum attribute value size).

Cookie attribute-values are stored as byte sequences, not strings.


### Cookie store

A cookie store is normatively defined for user agents by [Cookies § User Agent Requirements](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-14#name-user-agent-requirements).

When any of the following conditions occur for a cookie store, perform the steps to process cookie changes.

- A newly-created cookie is inserted into the cookie store.

- A user agent evicts expired cookies from the cookie store.

- A user agent removes excess cookies from the cookie store.


### Extensions to Service Workers

[Service-Workers] defines service worker registration, which this specification extends.

A service worker registration has an associated cookie change subscription list which is a list; each member is a cookie change subscription. A cookie change subscription is a tuple of name and url.


## The `CookieStore` interface

```idl
[Exposed=(ServiceWorker,Window),
 SecureContext]
interface CookieStore : EventTarget {
  Promise<CookieListItem?> get(USVString name);
  Promise<CookieListItem?> get(optional CookieStoreGetOptions options = {});

  Promise<CookieList> getAll(USVString name);
  Promise<CookieList> getAll(optional CookieStoreGetOptions options = {});

  Promise<undefined> set(USVString name, USVString value);
  Promise<undefined> set(CookieInit options);

  Promise<undefined> delete(USVString name);
  Promise<undefined> delete(CookieStoreDeleteOptions options);

  [Exposed=Window]
  attribute EventHandler onchange;
};

dictionary CookieStoreGetOptions {
  USVString name;
  USVString url;
};

enum CookieSameSite {
  "strict",
  "lax",
  "none"
};

dictionary CookieInit {
  required USVString name;
  required USVString value;
  DOMHighResTimeStamp? expires = null;
  USVString? domain = null;
  USVString path = "/";
  CookieSameSite sameSite = "strict";
  boolean partitioned = false;
};

dictionary CookieStoreDeleteOptions {
  required USVString name;
  USVString? domain = null;
  USVString path = "/";
  boolean partitioned = false;
};

dictionary CookieListItem {
  USVString name;
  USVString value;
};

typedef sequence<CookieListItem> CookieList;
```


### The `get()` method

`cookie` = await cookieStore . `get`(`name`)
`cookie` = await cookieStore . `get`(`options`)

:   Returns a promise resolving to the first in-scope script-visible value for a given cookie name (or other options). In a service worker context this defaults to the path of the service worker's registered scope. In a document it defaults to the path of the current document and does not respect changes from `replaceState()` or `document.domain`.

The `get(name)` method steps are:

1.  Let `settings` be this's relevant settings object.

2.  Let `origin` be `settings`'s origin.

3.  If `origin` is an opaque origin, then return a promise rejected with a "`SecurityError`" `DOMException`.

4.  Let `url` be `settings`'s creation URL.

5.  Let `p` be a new promise.

6.  Run the following steps in parallel:

    1.  Let `list` be the results of running query cookies with `url` and `name`.

    2.  If `list` is failure, then reject `p` with a `TypeError` and abort these steps.

    3.  If `list` is empty, then resolve `p` with null.

    4.  Otherwise, resolve `p` with the first item of `list`.

7.  Return `p`.

The `get(options)` method steps are:

1.  Let `settings` be this's relevant settings object.

2.  Let `origin` be `settings`'s origin.

3.  If `origin` is an opaque origin, then return a promise rejected with a "`SecurityError`" `DOMException`.

4.  Let `url` be `settings`'s creation URL.

5.  If `options` is empty, then return a promise rejected with a `TypeError`.

6.  If `options`["`url`"] exists:

    1.  Let `parsed` be the result of parsing `options`["`url`"] with `settings`'s API base URL.

    2.  If this's relevant global object is a `Window` object and `parsed` does not equal `url` with exclude fragments set to true, then return a promise rejected with a `TypeError`.

    3.  If `parsed`'s origin and `url`'s origin are not the same origin, then return a promise rejected with a `TypeError`.

    4.  Set `url` to `parsed`.

7.  Let `p` be a new promise.

8.  Run the following steps in parallel:

    1.  Let `list` be the results of running query cookies with `url` and `options`["`name`"] with default null.

    2.  If `list` is failure, then reject `p` with a `TypeError` and abort these steps.

    3.  If `list` is empty, then resolve `p` with null.

    4.  Otherwise, resolve `p` with the first item of `list`.

9.  Return `p`.


### The `getAll()` method

`cookies` = await cookieStore . `getAll`(`name`)
`cookies` = await cookieStore . `getAll`(`options`)

:   Returns a promise resolving to the all in-scope script-visible value for a given cookie name (or other options). In a service worker context this defaults to the path of the service worker's registered scope. In a document it defaults to the path of the current document and does not respect changes from `replaceState()` or `document.domain`.

The `getAll(name)` method steps are:

1.  Let `settings` be this's relevant settings object.

2.  Let `origin` be `settings`'s origin.

3.  If `origin` is an opaque origin, then return a promise rejected with a "`SecurityError`" `DOMException`.

4.  Let `url` be `settings`'s creation URL.

5.  Let `p` be a new promise.

6.  Run the following steps in parallel:

    1.  Let `list` be the results of running query cookies with `url` and `name`.

    2.  If `list` is failure, then reject `p` with a `TypeError`.

    3.  Otherwise, resolve `p` with `list`.

7.  Return `p`.

The `getAll(options)` method steps are:

1.  Let `settings` be this's relevant settings object.

2.  Let `origin` be `settings`'s origin.

3.  If `origin` is an opaque origin, then return a promise rejected with a "`SecurityError`" `DOMException`.

4.  Let `url` be `settings`'s creation URL.

5.  If `options`["`url`"] exists:

    1.  Let `parsed` be the result of parsing `options`["`url`"] with `settings`'s API base URL.

    2.  If this's relevant global object is a `Window` object and `parsed` does not equal `url` with exclude fragments set to true, then return a promise rejected with a `TypeError`.

    3.  If `parsed`'s origin and `url`'s origin are not the same origin, then return a promise rejected with a `TypeError`.

    4.  Set `url` to `parsed`.

6.  Let `p` be a new promise.

7.  Run the following steps in parallel:

    1.  Let `list` be the results of running query cookies with `url` and `options`["`name`"] with default null.

    2.  If `list` is failure, then reject `p` with a `TypeError`.

    3.  Otherwise, resolve `p` with `list`.

8.  Return `p`.


### The `set()` method

await cookieStore . `set`(`name`, `value`)
await cookieStore . `set`(`options`)

:   Writes (creates or modifies) a cookie.

    The options default to:

    - Path: `/`

    - Domain: same as the domain of the current document or service worker's location

    - No expiry date

    - SameSite: strict

The `set(name, value)` method steps are:

1.  Let `settings` be this's relevant settings object.

2.  Let `origin` be `settings`'s origin.

3.  If `origin` is an opaque origin, then return a promise rejected with a "`SecurityError`" `DOMException`.

4.  Let `url` be `settings`'s creation URL.

5.  Let `p` be a new promise.

6.  Run the following steps in parallel:

    1.  Let `r` be the result of running set a cookie with `url`, `name`, `value`, null, null, "`/`", "`strict`", and false.

    2.  If `r` is failure, then reject `p` with a `TypeError` and abort these steps.

    3.  Resolve `p` with undefined.

7.  Return `p`.

The `set(options)` method steps are:

1.  Let `settings` be this's relevant settings object.

2.  Let `origin` be `settings`'s origin.

3.  If `origin` is an opaque origin, then return a promise rejected with a "`SecurityError`" `DOMException`.

4.  Let `url` be `settings`'s creation URL.

5.  Let `p` be a new promise.

6.  Run the following steps in parallel:

    1.  Let `r` be the result of running set a cookie with `url`, `options`["`name`"], `options`["`value`"], `options`["`expires`"], `options`["`domain`"], `options`["`path`"], `options`["`sameSite`"], and `options`["`partitioned`"].

    2.  If `r` is failure, then reject `p` with a `TypeError` and abort these steps.

    3.  Resolve `p` with undefined.

7.  Return `p`.


### The `delete()` method

await cookieStore . `delete`(`name`)
await cookieStore . `delete`(`options`)

:   Deletes (expires) a cookie with the given name or name and optional domain and path.

The `delete(name)` method steps are:

1.  Let `settings` be this's relevant settings object.

2.  Let `origin` be `settings`'s origin.

3.  If `origin` is an opaque origin, then return a promise rejected with a "`SecurityError`" `DOMException`.

4.  Let `url` be `settings`'s creation URL.

5.  Let `p` be a new promise.

6.  Run the following steps in parallel:

    1.  Let `r` be the result of running delete a cookie with `url`, `name`, null, "`/`", and true.

    2.  If `r` is failure, then reject `p` with a `TypeError` and abort these steps.

    3.  Resolve `p` with undefined.

7.  Return `p`.

The `delete(options)` method steps are:

1.  Let `settings` be this's relevant settings object.

2.  Let `origin` be `settings`'s origin.

3.  If `origin` is an opaque origin, then return a promise rejected with a "`SecurityError`" `DOMException`.

4.  Let `url` be `settings`'s creation URL.

5.  Let `p` be a new promise.

6.  Run the following steps in parallel:

    1.  Let `r` be the result of running delete a cookie with `url`, `options`["`name`"], `options`["`domain`"], `options`["`path`"], and `options`["`partitioned`"].

    2.  If `r` is failure, then reject `p` with a `TypeError` and abort these steps.

    3.  Resolve `p` with undefined.

7.  Return `p`.


## The `CookieStoreManager` interface

A `CookieStoreManager` has an associated [registration](#cookiestoremanager-registration) which is a [service worker registration](https://w3c.github.io/ServiceWorker/#dfn-service-worker-registration).

The `CookieStoreManager` interface allows [Service Workers](https://w3c.github.io/ServiceWorker/#dfn-service-worker) to subscribe to events for cookie changes. Using the `subscribe()` method is necessary to indicate that a particular [service worker registration](https://w3c.github.io/ServiceWorker/#dfn-service-worker-registration) is interested in change events.

```idl
[Exposed=(ServiceWorker,Window),
 SecureContext]
interface CookieStoreManager {
  Promise<undefined> subscribe(sequence<CookieStoreGetOptions> subscriptions);
  Promise<sequence<CookieStoreGetOptions>> getSubscriptions();
  Promise<undefined> unsubscribe(sequence<CookieStoreGetOptions> subscriptions);
};
```


### The `subscribe()` method

await `registration` . cookies . `subscribe`(`subscriptions`)

:   Subscribe to changes to cookies. Subscriptions can use the same options as `get()` and `getAll()`, with optional `name` and `url` properties.

    Once subscribed, notifications are delivered as "`cookiechange`" events fired against the [Service Worker](https://w3c.github.io/ServiceWorker/#dfn-service-worker)'s global scope:

The `subscribe(subscriptions)` method steps are:

1.  Let `settings` be [this](https://webidl.spec.whatwg.org/#this)'s [relevant settings object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

2.  Let `registration` be [this](https://webidl.spec.whatwg.org/#this)'s [registration](#cookiestoremanager-registration).

3.  Let `p` be [a new promise](https://webidl.spec.whatwg.org/#a-new-promise).

4.  Run the following steps [in parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

    1.  Let `subscription list` be `registration`'s associated [cookie change subscription list](#cookie-change-subscription-list).

    2.  [For each](https://infra.spec.whatwg.org/#list-iterate) `entry` in `subscriptions`, run these steps:

        1.  Let `name` be `entry`["`name`"].

        2.  [Normalize](#normalize-a-cookie-name-or-value) `name`.

        3.  Let `url` be the result of [parsing](https://url.spec.whatwg.org/#concept-basic-url-parser) `entry`["`url`"] with `settings`'s [API base URL](https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url).

        4.  If `url` does not start with `registration`'s [scope url](https://w3c.github.io/ServiceWorker/#dfn-scope-url), then [reject](https://webidl.spec.whatwg.org/#reject) `p` with a `TypeError` and abort these steps.

        5.  Let `subscription` be the [cookie change subscription](#cookie-change-subscription) (`name`, `url`).

        6.  If `subscription list` does not already [contain](https://infra.spec.whatwg.org/#list-contain) `subscription`, then [append](https://infra.spec.whatwg.org/#list-append) `subscription` to `subscription list`.

    3.  [Resolve](https://webidl.spec.whatwg.org/#resolve) `p` with undefined.

5.  Return `p`.


### The `getSubscriptions()` method

`subscriptions` = await `registration` . cookies . `getSubscriptions()`

:   This method returns a promise which resolves to a list of the cookie change subscriptions made for this Service Worker registration.

The `getSubscriptions()` method steps are:

1.  Let `registration` be [this](https://webidl.spec.whatwg.org/#this)'s [registration](#cookiestoremanager-registration).

2.  Let `p` be [a new promise](https://webidl.spec.whatwg.org/#a-new-promise).

3.  Run the following steps [in parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

    1.  Let `subscriptions` be `registration`'s associated [cookie change subscription list](#cookie-change-subscription-list).

    2.  Let `result` be « ».

    3.  [For each](https://infra.spec.whatwg.org/#list-iterate) `subscription` in `subscriptions`, run these steps:

        1.  [Append](https://infra.spec.whatwg.org/#list-append) «[ "name" → `subscription`'s [name](#cookie-change-subscription-name), "url" → `subscription`'s [url](#cookie-change-subscription-url)]» to `result`.

    4.  [Resolve](https://webidl.spec.whatwg.org/#resolve) `p` with `result`.

4.  Return `p`.


### The `unsubscribe()` method

await `registration` . cookies . `unsubscribe`(`subscriptions`)

:   Calling this method will stop the registered service worker from receiving previously subscribed events. The `subscriptions` argument ought to list subscriptions in the same form passed to `subscribe()` or returned from `getSubscriptions()`.

The `unsubscribe(subscriptions)` method steps are:

1.  Let `settings` be [this](https://webidl.spec.whatwg.org/#this)'s [relevant settings object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

2.  Let `registration` be [this](https://webidl.spec.whatwg.org/#this)'s [registration](#cookiestoremanager-registration).

3.  Let `p` be [a new promise](https://webidl.spec.whatwg.org/#a-new-promise).

4.  Run the following steps [in parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

    1.  Let `subscription list` be `registration`'s associated [cookie change subscription list](#cookie-change-subscription-list).

    2.  [For each](https://infra.spec.whatwg.org/#list-iterate) `entry` in `subscriptions`, run these steps:

        1.  Let `name` be `entry`["`name`"].

        2.  [Normalize](#normalize-a-cookie-name-or-value) `name`.

        3.  Let `url` be the result of [parsing](https://url.spec.whatwg.org/#concept-basic-url-parser) `entry`["`url`"] with `settings`'s [API base URL](https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url).

        4.  If `url` does not start with `registration`'s [scope url](https://w3c.github.io/ServiceWorker/#dfn-scope-url), then [reject](https://webidl.spec.whatwg.org/#reject) `p` with a `TypeError` and abort these steps.

        5.  Let `subscription` be the [cookie change subscription](#cookie-change-subscription) (`name`, `url`).

        6.  [Remove](https://infra.spec.whatwg.org/#list-remove) any [item](https://infra.spec.whatwg.org/#list-item) from `subscription list` equal to `subscription`.

    3.  [Resolve](https://webidl.spec.whatwg.org/#resolve) `p` with undefined.

5.  Return `p`.


### The `ServiceWorkerRegistration` interface

The `ServiceWorkerRegistration` interface is extended to give access to a `CookieStoreManager` via `cookies` which provides the interface for subscribing to cookie changes.

```idl
[Exposed=(ServiceWorker,Window)]
partial interface ServiceWorkerRegistration {
  [SameObject] readonly attribute CookieStoreManager cookies;
};
```

Each `ServiceWorkerRegistration` has an associated `CookieStoreManager` object. The `CookieStoreManager`'s [registration](#cookiestoremanager-registration) is equal to the `ServiceWorkerRegistration`'s [service worker registration](https://w3c.github.io/ServiceWorker/#dfn-service-worker-registration).

The `cookies` getter steps are to return [this](https://webidl.spec.whatwg.org/#this)'s associated `CookieStoreManager` object.

Subscribing to cookie changes from a Service Worker script:

```js
self.registration.cookies.subscribe([{name:'session-id'}]);
```

Subscribing to cookie changes from a script in a window context:

```js
navigator.serviceWorker.register('sw.js').then(registration => {
  registration.cookies.subscribe([{name:'session-id'}]);
});
```


## Event interfaces


### The `CookieChangeEvent` interface

A `CookieChangeEvent` is [dispatched](https://dom.spec.whatwg.org/#concept-event-dispatch) against `CookieStore` objects in `Window` contexts when any script-visible cookie changes have occurred.

```idl
[Exposed=Window,
 SecureContext]
interface CookieChangeEvent : Event {
  constructor(DOMString type, optional CookieChangeEventInit eventInitDict = {});
  [SameObject] readonly attribute FrozenArray<CookieListItem> changed;
  [SameObject] readonly attribute FrozenArray<CookieListItem> deleted;
};

dictionary CookieChangeEventInit : EventInit {
  CookieList changed;
  CookieList deleted;
};
```

The `changed` and `deleted` attributes must return the value they were initialized to.


### The `ExtendableCookieChangeEvent` interface

An `ExtendableCookieChangeEvent` is [dispatched](https://dom.spec.whatwg.org/#concept-event-dispatch) against `ServiceWorkerGlobalScope` objects when any script-visible cookie changes have occurred which match the Service Worker's cookie change subscription list.

Note: `ExtendableEvent` is used as the ancestor interface for all events in Service Workers so that the worker itself can be kept alive while the async operations are performed.

```idl
[Exposed=ServiceWorker]
interface ExtendableCookieChangeEvent : ExtendableEvent {
  constructor(DOMString type, optional ExtendableCookieChangeEventInit eventInitDict = {});
  [SameObject] readonly attribute FrozenArray<CookieListItem> changed;
  [SameObject] readonly attribute FrozenArray<CookieListItem> deleted;
};

dictionary ExtendableCookieChangeEventInit : ExtendableEventInit {
  CookieList changed;
  CookieList deleted;
};
```

The `changed` and `deleted` attributes must return the value they were initialized to.


## Global interfaces

A `CookieStore` is accessed by script using an attribute in the global scope in a `Window` or `ServiceWorkerGlobalScope` context.


### The `Window` interface

```idl
[SecureContext]
partial interface Window {
  [SameObject] readonly attribute CookieStore cookieStore;
};
```

A `Window` has an **associated CookieStore**, which is a `CookieStore`.

The `cookieStore` getter steps are to return this's associated CookieStore.


### The `ServiceWorkerGlobalScope` interface

```idl
partial interface ServiceWorkerGlobalScope {
  [SameObject] readonly attribute CookieStore cookieStore;

  attribute EventHandler oncookiechange;
};
```

A `ServiceWorkerGlobalScope` has an **associated CookieStore**, which is a `CookieStore`.

The `cookieStore` getter steps are to return this's associated CookieStore.


## Algorithms

To represent a date and time `dateTime` **as a timestamp**, return the number of milliseconds from 00:00:00 UTC, 1 January 1970 to `dateTime` (assuming that there are exactly 86,400,000 milliseconds per day).

Note: This is the same representation used for [time values](https://tc39.github.io/ecma262/#sec-time-values-and-time-range) in [ECMAScript].

To **date serialize** a [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#dom-domhighrestimestamp) `millis`, let `dateTime` be the date and time `millis` milliseconds after 00:00:00 UTC, 1 January 1970 (assuming that there are exactly 86,400,000 milliseconds per day), and return a [byte sequence](https://infra.spec.whatwg.org/#byte-sequence) corresponding to the closest `cookie-date` representation of `dateTime` according to [Cookies § Dates](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-14#name-dates).


### Query cookies

To **query cookies** given a [URL](https://url.spec.whatwg.org/#concept-url) `url` and [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string)-or-null `name`:

1.  Perform the steps defined in [Cookies § Retrieval Model](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-14#name-retrieval-model) to compute the "cookie-string from a given cookie store" with `url` as `request-uri`. The `cookie-string` itself is ignored, but the intermediate `cookie-list` is used in subsequent steps.

    For the purposes of the steps, the `cookie-string` is being generated for a "non-HTTP" API.

2.  Let `list` be « ».

3.  [For each](https://infra.spec.whatwg.org/#list-iterate) `cookie` of `cookie-list`:

    1.  Assert: `cookie`'s http-only-flag is false.

    2.  If `name` is non-null:

        1.  Normalize `name`.

        2.  Let `cookieName` be the result of running [UTF-8 decode without BOM](https://encoding.spec.whatwg.org/#utf-8-decode-without-bom) on `cookie`'s name.

        3.  If `cookieName` does not equal `name`, then [continue](https://infra.spec.whatwg.org/#iteration-continue).

    3.  Let `item` be the result of running create a CookieListItem from `cookie`.

    4.  [Append](https://infra.spec.whatwg.org/#list-append) `item` to `list`.

4.  Return `list`.

To **create a [`CookieListItem`](#dictdef-cookielistitem)** from a cookie `cookie`:

1.  Let `name` be the result of running [UTF-8 decode without BOM](https://encoding.spec.whatwg.org/#utf-8-decode-without-bom) on `cookie`'s name.

2.  Let `value` be the result of running [UTF-8 decode without BOM](https://encoding.spec.whatwg.org/#utf-8-decode-without-bom) on `cookie`'s value.

3.  Return «[ "`name`" → `name`, "`value`" → `value` ]».

Note: One implementation is known to expose information beyond _name_ and _value_.


### Set a cookie

To **set a cookie** given a [URL](https://url.spec.whatwg.org/#concept-url) `url`, [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string) `name`, [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string) `value`, [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#dom-domhighrestimestamp)-or-null `expires`, [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string)-or-null `domain`, [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string) `path`, [string](https://infra.spec.whatwg.org/#string) `sameSite`, and [boolean](https://infra.spec.whatwg.org/#boolean) `partitioned`:

1.  Normalize `name`.

2.  Normalize `value`.

3.  If `name` or `value` contain U+003B (;), any [C0 control](https://infra.spec.whatwg.org/#c0-control) character except U+0009 TAB, or U+007F DELETE, then return failure.

    Note that it's up for discussion whether these character restrictions should also apply to `expires`, `domain`, `path`, and `sameSite` as well. [httpwg/http-extensions Issue #1593](https://github.com/httpwg/http-extensions/issues/1593)

4.  If `name` contains U+003D (=), then return failure.

5.  If `name`'s [length](https://infra.spec.whatwg.org/#string-length) is 0:

    1.  If `value` contains U+003D (=), then return failure.

    2.  If `value`'s [length](https://infra.spec.whatwg.org/#string-length) is 0, then return failure.

    3.  If `value`, [byte-lowercased](https://infra.spec.whatwg.org/#byte-lowercase), [starts with](https://infra.spec.whatwg.org/#byte-sequence-starts-with) `__host-`, `__host-http-`, `__http-`, or `__secure-`, then return failure.

6.  If `name`, [byte-lowercased](https://infra.spec.whatwg.org/#byte-lowercase), [starts with](https://infra.spec.whatwg.org/#byte-sequence-starts-with) `__host-http-` or `__http-`, then return failure.

7.  Let `encodedName` be the result of [UTF-8 encoding](https://encoding.spec.whatwg.org/#utf-8-encode) `name`.

8.  Let `encodedValue` be the result of [UTF-8 encoding](https://encoding.spec.whatwg.org/#utf-8-encode) `value`.

9.  If the [byte sequence](https://infra.spec.whatwg.org/#byte-sequence) [length](https://infra.spec.whatwg.org/#byte-sequence-length) of `encodedName` plus the [byte sequence](https://infra.spec.whatwg.org/#byte-sequence) [length](https://infra.spec.whatwg.org/#byte-sequence-length) of `encodedValue` is greater than the maximum name/value pair size, then return failure.

10. Let `host` be `url`'s [host](https://url.spec.whatwg.org/#concept-url-host)

11. Let `attributes` be « ».

12. If `domain` is non-null:

    1.  If `domain` starts with U+002E (.), then return failure.

    2.  If `name`, [byte-lowercased](https://infra.spec.whatwg.org/#byte-lowercase), [starts with](https://infra.spec.whatwg.org/#byte-sequence-starts-with) `__host-`, then return failure.

    3.  If `domain` [is not a registrable domain suffix of and is not equal to](https://html.spec.whatwg.org/multipage/browsers.html#is-a-registrable-domain-suffix-of-or-is-equal-to) `host`, then return failure.

    4.  Let `parsedDomain` be the result of [host parsing](https://url.spec.whatwg.org/#concept-host-parser) `domain`.

    5.  Assert: `parsedDomain` is not failure.

    6.  Let `encodedDomain` be the result of [UTF-8 encoding](https://encoding.spec.whatwg.org/#utf-8-encode) `parsedDomain`.

    7.  If the [byte sequence](https://infra.spec.whatwg.org/#byte-sequence) [length](https://infra.spec.whatwg.org/#byte-sequence-length) of `encodedDomain` is greater than the maximum attribute value size, then return failure.

    8.  [Append](https://infra.spec.whatwg.org/#list-append) (`Domain`, `encodedDomain`) to `attributes`.

13. If `expires` is non-null, then [append](https://infra.spec.whatwg.org/#list-append) (`Expires`, `expires` (date serialized)) to `attributes`.

14. If `path` is the empty string, then set `path` to the [serialized cookie default path](https://fetch.spec.whatwg.org/#serialized-cookie-default-path) of `url`.

15. If `path` does not start with U+002F (/), then return failure.

16. If `path` is not U+002F (/), and `name`, [byte-lowercased](https://infra.spec.whatwg.org/#byte-lowercase), [starts with](https://infra.spec.whatwg.org/#byte-sequence-starts-with) `__host-`, then return failure.

17. Let `encodedPath` be the result of [UTF-8 encoding](https://encoding.spec.whatwg.org/#utf-8-encode) `path`.

18. If the [byte sequence](https://infra.spec.whatwg.org/#byte-sequence) [length](https://infra.spec.whatwg.org/#byte-sequence-length) of `encodedPath` is greater than the maximum attribute value size, then return failure.

19. [Append](https://infra.spec.whatwg.org/#list-append) (`Path`, `encodedPath`) to `attributes`.

20. [Append](https://infra.spec.whatwg.org/#list-append) (`Secure`, ``) to `attributes`.

21. Switch on `sameSite`:

    "`none`"

    :   [Append](https://infra.spec.whatwg.org/#list-append) (`SameSite`, `None`) to `attributes`.

    "`strict`"

    :   [Append](https://infra.spec.whatwg.org/#list-append) (`SameSite`, `Strict`) to `attributes`.

    "`lax`"

    :   [Append](https://infra.spec.whatwg.org/#list-append) (`SameSite`, `Lax`) to `attributes`.

22. If `partitioned` is true, [Append](https://infra.spec.whatwg.org/#list-append) (`Partitioned`, ``) to `attributes`.

23. Perform the steps defined in [Cookies § Storage Model](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-14#name-storage-model) for when the user agent "receives a cookie" with `url` as `request-uri`, `encodedName` as `cookie-name`, `encodedValue` as `cookie-value`, and `attributes` as `cookie-attribute-list`.

    For the purposes of the steps, the newly-created cookie was received from a "non-HTTP" API.

24. Return success.

    Note: Storing the cookie can still fail due to requirements in [RFC6265BIS-14], but these steps will be considered successful.


### Delete a cookie

To **delete a cookie** given a [URL](https://url.spec.whatwg.org/#concept-url) `url`, [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string) `name`, [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string)-or-null `domain`, [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string) `path`, and [boolean](https://infra.spec.whatwg.org/#boolean) `partitioned`:

1.  Let `expires` be the earliest representable date represented as a timestamp.

    Note: The exact value of `expires` is not important for the purposes of this algorithm, as long as it is in the past.

2.  Normalize `name`.

3.  Let `value` be the empty string.

4.  If `name`'s [length](https://infra.spec.whatwg.org/#string-length) is 0, then set `value` to any non-empty [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) string.

5.  Return the results of running set a cookie with `url`, `name`, `value`, `expires`, `domain`, `path`, "`strict`", and `partitioned`.


### Process changes

To **process cookie changes**, run the following steps:

1.  For every [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) `window`, run the following steps:

    1.  Let `url` be `window`'s [relevant settings object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s [creation URL](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-creation-url).

    2.  Let `changes` be the observable changes for `url`.

    3.  If `changes` [is empty](https://infra.spec.whatwg.org/#list-is-empty), then [continue](https://infra.spec.whatwg.org/#iteration-continue).

    4.  [Queue a global task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [DOM manipulation task source](https://html.spec.whatwg.org/multipage/webappapis.html#dom-manipulation-task-source) given `window` to fire a change event named "`change`" with `changes` at `window`'s [`CookieStore`](#cookiestore).

2.  For every [service worker registration](https://w3c.github.io/ServiceWorker/#dfn-service-worker-registration) `registration`, run the following steps:

    1.  Let `changes` be a new [set](https://infra.spec.whatwg.org/#ordered-set).

    2.  [For each](https://infra.spec.whatwg.org/#list-iterate) `change` in the observable changes for `registration`'s [scope url](https://w3c.github.io/ServiceWorker/#dfn-scope-url), run these steps:

        1.  Let `cookie` be `change`'s cookie.

        2.  [For each](https://infra.spec.whatwg.org/#list-iterate) `subscription` in `registration`'s cookie change subscription list, run these steps:

            1.  If `change` is not [in](https://infra.spec.whatwg.org/#list-contain) the observable changes for `subscription`'s url, then [continue](https://infra.spec.whatwg.org/#iteration-continue).

            2.  Let `cookieName` be the result of running [UTF-8 decode without BOM](https://encoding.spec.whatwg.org/#utf-8-decode-without-bom) on `cookie`'s name.

            3.  If `cookieName` equals `subscription`'s name, then [append](https://infra.spec.whatwg.org/#set-append) `change` to `changes` and [break](https://infra.spec.whatwg.org/#iteration-break).

    3.  If `changes` [is empty](https://infra.spec.whatwg.org/#list-is-empty), then [continue](https://infra.spec.whatwg.org/#iteration-continue).

    4.  Let `changedList` and `deletedList` be the result of running prepare lists from `changes`.

    5.  [Fire a functional event](https://w3c.github.io/ServiceWorker/#fire-functional-event) named "`cookiechange`" using [`ExtendableCookieChangeEvent`](#extendablecookiechangeevent) on `registration` with these properties:

        `changed`

        :   `changedList`

        `deleted`

        :   `deletedList`

The **observable changes** for `url` are the [set](https://infra.spec.whatwg.org/#ordered-set) of cookie changes to cookies in a cookie store which meet the requirements in step 1 of [Cookies § Retrieval Algorithm](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-14#name-retrieval-algorithm)'s steps to compute the "cookie-string from a given cookie store" with `url` as `request-uri`, for a "non-HTTP" API.

A **cookie change** is a cookie and a type (either *changed* or *deleted*):

- A cookie which is removed due to an insertion of another cookie with the same name, domain, and path is ignored.

- A newly-created cookie which is not immediately evicted is considered *changed*.

- A newly-created cookie which is immediately evicted is considered *deleted*.

- A cookie which is otherwise evicted or removed is considered *deleted*

To **fire a change event** named `type` with `changes` at `target`, run the following steps:

1.  Let `event` be the result of [creating an Event](https://dom.spec.whatwg.org/#concept-event-create) using [`CookieChangeEvent`](#cookiechangeevent).

2.  Set `event`'s [`type`](https://dom.spec.whatwg.org/#dom-event-type) attribute to `type`.

3.  Set `event`'s [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) and [`cancelable`](https://dom.spec.whatwg.org/#dom-event-cancelable) attributes to false.

4.  Let `changedList` and `deletedList` be the result of running prepare lists from `changes`.

5.  Set `event`'s `changed` attribute to `changedList`.

6.  Set `event`'s `deleted` attribute to `deletedList`.

7.  [Dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch) `event` at `target`.

To **prepare lists** from `changes`, run the following steps:

1.  Let `changedList` be « ».

2.  Let `deletedList` be « ».

3.  [For each](https://infra.spec.whatwg.org/#list-iterate) `change` in `changes`, run these steps:

    1.  Let `item` be the result of running create a CookieListItem from `change`'s cookie.

    2.  If `change`'s type is *changed*, then [append](https://infra.spec.whatwg.org/#list-append) `item` to `changedList`.

    3.  Otherwise, run these steps:

        1.  Set `item`["`value`"] to undefined.

        2.  [Append](https://infra.spec.whatwg.org/#list-append) `item` to `deletedList`.

4.  Return `changedList` and `deletedList`.


## Security considerations

Other than cookie access from service worker contexts, this API is not intended to expose any new capabilities to the web.


### Gotcha!

Although browser cookie implementations are now evolving in the direction of better security and fewer surprising and error-prone defaults, there are at present few guarantees about cookie data security.

- unsecured origins can typically overwrite cookies used on secure origins

- superdomains can typically overwrite cookies seen by subdomains

- cross-site scripting attacks and other script and header injection attacks can be used to forge cookies too

- cookie read operations (both from script and on web servers) don't give any indication of where the cookie came from

- browsers sometimes truncate, transform or evict cookie data in surprising and counterintuitive ways

  - \... due to reaching storage limits

  - \... due to character encoding differences

  - \... due to differing syntactic and semantic rules for cookies

For these reasons it is best to use caution when interpreting any cookie's value, and never execute a cookie's value as script, HTML, CSS, XML, PDF, or any other executable format.


### Restrict?

This API may have the unintended side-effect of making cookies easier to use and consequently encouraging their further use. If it causes their further use in [non-secure contexts](https://html.spec.whatwg.org/multipage/webappapis.html#non-secure-context) this could result in a web less safe for users. For that reason this API has been restricted to [secure contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context) only.


### Secure cookies

*This section is non-normative.*

This API only allows writes for `Secure` cookies to encourage better decisions around security. However the API will still allow reading non-`Secure` cookies in order to facilitate the migration to `Secure` cookies. As a side-effect, when fetching and modifying a non-`Secure` cookie with this API, the non-`Secure` cookie will automatically be modified to `Secure`.


### Surprises

Some existing cookie behavior (especially domain-rather-than-origin orientation, [non-secure contexts](https://html.spec.whatwg.org/multipage/webappapis.html#non-secure-context) being able to set cookies readable in [secure contexts](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), and script being able to set cookies unreadable from script contexts) may be quite surprising from a web security standpoint.

Other surprises are documented in [Cookies § Introduction](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-14#name-introduction) - for instance, a cookie may be set for a superdomain (e.g. app.example.com may set a cookie for the whole example.com domain), and a cookie may be readable across all port numbers on a given domain name.

Further complicating this are historical differences in cookie-handling across major browsers, although some of those (e.g. port number handling) are now handled with more consistency than they once were.


### Prefixes

Where feasible the examples use the `__Host-` and `__Secure-` name prefixes which causes some current browsers to disallow overwriting from [non-secure contexts](https://html.spec.whatwg.org/multipage/webappapis.html#non-secure-context), disallow overwriting with no `Secure` flag, and --- in the case of `__Host-` --- disallow overwriting with an explicit `Domain` or non-\'/\' `Path` attribute (effectively enforcing same-origin semantics.) These prefixes provide important security benefits in those browsers implementing Secure Cookies and degrade gracefully (i.e. the special semantics may not be enforced in other cookie APIs but the cookies work normally and the async cookies API enforces the secure semantics for write operations) in other browsers. A major goal of this API is interoperation with existing cookies, though, so a few examples have also been provided using cookie names lacking these prefixes.

Prefix rules are also enforced in write operations by this API, but may not be enforced in the same browser for other APIs. For this reason it is inadvisable to rely on their enforcement too heavily until and unless they are more broadly adopted.


### URL scoping

Although a service worker script cannot directly access cookies today, it can already use controlled rendering of in-scope HTML and script resources to inject cookie-monitoring code under the remote control of the service worker script. This means that cookie access inside the scope of the service worker is technically possible already, it's just not very convenient.

When the service worker is scoped more narrowly than `/` it may still be able to read path-scoped cookies from outside its scope's path space by successfully guessing/constructing a 404 page URL which allows IFRAME-ing and then running script inside it the same technique could expand to the whole origin, but a carefully constructed site (one where no out-of-scope pages are IFRAME-able) can actually deny this capability to a path-scoped service worker today and I was reluctant to remove that restriction without further discussion of the implications.


### Cookie aversion

To reduce complexity for developers and eliminate the need for ephemeral test cookies, this async cookies API will explicitly reject attempts to write or delete cookies when the operation would be ignored. Likewise it will explicitly reject attempts to read cookies when that operation would ignore actual cookie data and simulate an empty cookie jar. Attempts to observe cookie changes in these contexts will still \"work\", but won't invoke the callback until and unless read access becomes allowed (due e.g. to changed site permissions.)

Today writing to [`document.cookie`](https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie) in contexts where script-initiated cookie-writing is disallowed typically is a no-op. However, many cookie-writing scripts and frameworks always write a test cookie and then check for its existence to determine whether script-initiated cookie-writing is possible.

Likewise, today reading [`document.cookie`](https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie) in contexts where script-initiated cookie-reading is disallowed typically returns an empty string. However, a cooperating web server can verify that server-initiated cookie-writing and cookie-reading work and report this to the script (which still sees empty string) and the script can use this information to infer that script-initiated cookie-reading is disallowed.


## Privacy considerations


### Clear cookies

*This section is non-normative.*

When a user clears cookies for an origin, the user agent needs to wipe all storage for that origin; including service workers and DOM-accessible storage for that origin. This is to prevent websites from restoring any user identifiers in persistent storage after a user initiates the action.