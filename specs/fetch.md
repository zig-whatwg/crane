## Goals

The goal is to unify fetching across the web platform and provide consistent handling of everything that involves, including:

- URL schemes
- Redirects
- Cross-origin semantics
- CSP [CSP](#biblio-csp "Content Security Policy Level 3")
- Fetch Metadata [FETCH-METADATA](#biblio-fetch-metadata "Fetch Metadata Request Headers")
- Service workers [SW](#biblio-sw "Service Workers")
- Mixed Content [MIX](#biblio-mix "Mixed Content")
- Upgrade Insecure Requests [UPGRADE-INSECURE-REQUESTS](#biblio-upgrade-insecure-requests "Upgrade Insecure Requests")
- `Referer` [REFERRER](#biblio-referrer "Referrer Policy")

To do so it also supersedes the HTTP `Origin` header semantics originally defined in The Web Origin Concept. [ORIGIN](#biblio-origin "The Web Origin Concept")


## Preface

At a high level, fetching a resource is a fairly simple operation. A request goes in, a response comes out. The details of that operation are however quite involved and used to not be written down carefully and differ from one API to the next.

Numerous APIs provide the ability to fetch a resource, e.g. HTML's `img` and `script` element, CSS' `cursor` and `list-style-image`, the `navigator.sendBeacon()` and `self.importScripts()` JavaScript APIs. The Fetch Standard provides a unified architecture for these features so they are all consistent when it comes to various aspects of fetching, such as redirects and the CORS protocol.

The Fetch Standard also defines the `fetch()` JavaScript API, which exposes most of the networking functionality at a fairly low level of abstraction.


## Infrastructure

This specification depends on the Infra Standard. [INFRA]

This specification uses terminology from ABNF, Encoding, HTML, HTTP, MIME Sniffing, Streams, URL, Web IDL, and WebSockets. [ABNF] [ENCODING] [HTML] [HTTP] [MIMESNIFF] [STREAMS] [URL] [WEBIDL] [WEBSOCKETS]

ABNF means ABNF as augmented by HTTP (in particular the addition of `#`) and RFC 7405. [RFC7405]


Credentials are HTTP cookies, TLS client certificates, and authentication entries (for HTTP authentication). [COOKIES] [TLS] [HTTP]


A fetch params is a struct used as a bookkeeping detail by the fetch algorithm. It has the following items:

request
: A request.

process request body chunk length (default null)
process request end-of-body (default null)
process early hints response (default null)
process response (default null)
process response end-of-body (default null)
process response consume body (default null)
: Null or an algorithm.

task destination (default null)
: Null, a global object, or a parallel queue.

cross-origin isolated capability (default false)
: A boolean.

controller (default a new fetch controller)
: A fetch controller.

timing info
: A fetch timing info.

preloaded response candidate (default null)
: Null, "`pending`", or a response.

A fetch controller is a struct used to enable callers of fetch to perform certain operations on it after it has started. It has the following items:

state (default "`ongoing`")
: "`ongoing`", "`terminated`", or "`aborted`"

full timing info (default null)
: Null or a fetch timing info.

report timing steps (default null)
: Null or an algorithm accepting a global object.

serialized abort reason (default null)
: Null or a Record (result of StructuredSerialize).

next manual redirect steps (default null)
: Null or an algorithm accepting nothing.

To report timing for a fetch controller `controller` given a global object `global`:

1. Assert: `controller`'s report timing steps is non-null.

2. Call `controller`'s report timing steps with `global`.

To process the next manual redirect for a fetch controller `controller`:

1. Assert: `controller`'s next manual redirect steps is non-null.

2. Call `controller`'s next manual redirect steps.

To extract full timing info given a fetch controller `controller`:

1. Assert: `controller`'s full timing info is non-null.

2. Return `controller`'s full timing info.

To abort a fetch controller `controller` with an optional `error`:

1. Set `controller`'s state to "`aborted`".

2. Let `fallbackError` be an "`AbortError`" `DOMException`.

3. Set `error` to `fallbackError` if it is not given.

4. Let `serializedError` be StructuredSerialize(`error`). If that threw an exception, catch it, and let `serializedError` be StructuredSerialize(`fallbackError`).

5. Set `controller`'s serialized abort reason to `serializedError`.

To deserialize a serialized abort reason, given null or a Record `abortReason` and a realm `realm`:

1. Let `fallbackError` be an "`AbortError`" `DOMException`.

2. Let `deserializedError` be `fallbackError`.

3. If `abortReason` is non-null, then set `deserializedError` to StructuredDeserialize(`abortReason`, `realm`). If that threw an exception or returned undefined, then set `deserializedError` to `fallbackError`.

4. Return `deserializedError`.

To terminate a fetch controller `controller`, set `controller`'s state to "`terminated`".

A fetch params `fetchParams` is aborted if its controller's state is "`aborted`".

A fetch params `fetchParams` is canceled if its controller's state is "`aborted`" or "`terminated`".

A fetch timing info is a struct used to maintain timing information needed by Resource Timing and Navigation Timing. It has the following items: [RESOURCE-TIMING] [NAVIGATION-TIMING]

start time (default 0)
redirect start time (default 0)
redirect end time (default 0)
post-redirect start time (default 0)
final service worker start time (default 0)
final network-request start time (default 0)
first interim network-response start time (default 0)
final network-response start time (default 0)
end time (default 0)
: A `DOMHighResTimeStamp`.

final connection timing info (default null)
: Null or a connection timing info.

server-timing headers (default « »)
: A list of strings.

render-blocking (default false)
: A boolean.

A response body info is a struct used to maintain information needed by Resource Timing and Navigation Timing. It has the following items: [RESOURCE-TIMING] [NAVIGATION-TIMING]

encoded size (default 0)
decoded size (default 0)
: A number.

content type (default the empty string)
: An ASCII string.

content encoding (default the empty string)
: An ASCII string.

To create an opaque timing info, given a fetch timing info `timingInfo`, return a new fetch timing info whose start time and post-redirect start time are `timingInfo`'s start time.

To queue a fetch task, given an algorithm `algorithm`, a global object or a parallel queue `taskDestination`, run these steps:

1. If `taskDestination` is a parallel queue, then enqueue `algorithm` to `taskDestination`.

2. Otherwise, queue a global task on the networking task source with `taskDestination` and `algorithm`.

To check if the environment settings object `environment` is offline:

- If the user agent assumes it does not have internet connectivity, then return true.

- Return `environment`'s WebDriver BiDi network is offline.


To serialize an integer, represent it as a string of the shortest possible decimal number.

This will be replaced by a more descriptive algorithm in Infra. See infra/201.


### URL

A local scheme is "`about`", "`blob`", or "`data`".

A URL is local if its scheme is a local scheme.

This definition is also used by Referrer Policy. [REFERRER]

An HTTP(S) scheme is "`http`" or "`https`".

A fetch scheme is "`about`", "`blob`", "`data`", "`file`", or an HTTP(S) scheme.

HTTP(S) scheme and fetch scheme are also used by HTML. [HTML]


### HTTP

While fetching encompasses more than just HTTP, it borrows a number of concepts from HTTP and applies these to resources obtained via other means (e.g., `data` URLs).

An HTTP tab or space is U+0009 TAB or U+0020 SPACE.

HTTP whitespace is U+000A LF, U+000D CR, or an HTTP tab or space.

HTTP whitespace is only useful for specific constructs that are reused outside the context of HTTP headers (e.g., MIME types). For HTTP header values, using HTTP tab or space is preferred, and outside that context ASCII whitespace is preferred. Unlike ASCII whitespace this excludes U+000C FF.

An HTTP newline byte is 0x0A (LF) or 0x0D (CR).

An HTTP tab or space byte is 0x09 (HT) or 0x20 (SP).

An HTTP whitespace byte is an HTTP newline byte or HTTP tab or space byte.

To collect an HTTP quoted string from a string `input`, given a position variable `position` and an optional boolean `extract-value` (default false):

1. Let `positionStart` be `position`.

2. Let `value` be the empty string.

3. Assert: the code point at `position` within `input` is U+0022 (").

4. Advance `position` by 1.

5. While true:

   1. Append the result of collecting a sequence of code points that are not U+0022 (") or U+005C (\\) from `input`, given `position`, to `value`.

   2. If `position` is past the end of `input`, then break.

   3. Let `quoteOrBackslash` be the code point at `position` within `input`.

   4. Advance `position` by 1.

   5. If `quoteOrBackslash` is U+005C (\\), then:

      1. If `position` is past the end of `input`, then append U+005C (\\) to `value` and break.

      2. Append the code point at `position` within `input` to `value`.

      3. Advance `position` by 1.

   6. Otherwise:

      1. Assert: `quoteOrBackslash` is U+0022 (").

      2. Break.

6. If `extract-value` is true, then return `value`.

7. Return the code points from `positionStart` to `position`, inclusive, within `input`.

Input | Output | Output with `extract-value` set to true | Final position variable value
---|---|---|---
"`"`" | "`"`" | "``" | 2
"`"Hello"` World`" | "`"Hello"`" | "`Hello`" | 7
"`"Hello \\ World\""`" | "`"Hello \\ World\""`" | "`Hello \ World"`" | 18

The position variable always starts at 0 in these examples.


#### Methods

A method is a byte sequence that matches the method token production.

A CORS-safelisted method is a method that is \``GET`\`, \``HEAD`\`, or \``POST`\`.

A forbidden method is a method that is a byte-case-insensitive match for \``CONNECT`\`, \``TRACE`\`, or \``TRACK`\`. [HTTPVERBSEC1], [HTTPVERBSEC2], [HTTPVERBSEC3]

To normalize a method, if it is a byte-case-insensitive match for \``DELETE`\`, \``GET`\`, \``HEAD`\`, \``OPTIONS`\`, \``POST`\`, or \``PUT`\`, byte-uppercase it.

Normalization is done for backwards compatibility and consistency across APIs as methods are actually "case-sensitive".

Using \``patch`\` is highly likely to result in a \``405 Method Not Allowed`\`. \``PATCH`\` is much more likely to succeed.

There are no restrictions on methods. \``CHICKEN`\` is perfectly acceptable (and not a misspelling of \``CHECKIN`\`). Other than those that are normalized there are no casing restrictions either. \``Egg`\` or \``eGg`\` would be fine, though uppercase is encouraged for consistency.


#### Headers

HTTP generally refers to a header as a "field" or "header field". The web platform uses the more colloquial term "header". [HTTP]

A header list is a list of zero or more headers. It is initially « ».

A header list is essentially a specialized multimap: an ordered list of key-value pairs with potentially duplicate keys. Since headers other than \``Set-Cookie`\` are always combined when exposed to client-side JavaScript, implementations could choose a more efficient representation, as long as they also support an associated data structure for \``Set-Cookie`\` headers.

To get a structured field value given a header name `name` and a string `type` from a header list `list`, run these steps. They return null or a structured field value.

1. Assert: `type` is one of "`dictionary`", "`list`", or "`item`".

2. Let `value` be the result of getting `name` from `list`.

3. If `value` is null, then return null.

4. Let `result` be the result of parsing structured fields with `input_string` set to `value` and `header_type` set to `type`.

5. If parsing failed, then return null.

6. Return `result`.

Get a structured field value intentionally does not distinguish between a header not being present and its value failing to parse as a structured field value. This ensures uniform processing across the web platform.

To set a structured field value given a tuple (header name `name`, structured field value `structuredValue`), in a header list `list`:

1. Let `serializedValue` be the result of executing the serializing structured fields algorithm on `structuredValue`.

2. Set (`name`, `serializedValue`) in `list`.

Structured field values are defined as objects which HTTP can (eventually) serialize in interesting and efficient ways. For the moment, Fetch only supports header values as byte sequences, which means that these objects can be set in header lists only via serialization, and they can be obtained from header lists only by parsing. In the future the fact that they are objects might be preserved end-to-end. [RFC9651]


A header list `list` contains a header name `name` if `list` contains a header whose name is a byte-case-insensitive match for `name`.

To get a header name `name` from a header list `list`, run these steps. They return null or a header value.

1. If `list` does not contain `name`, then return null.

2. Return the values of all headers in `list` whose name is a byte-case-insensitive match for `name`, separated from each other by 0x2C 0x20, in order.

To get, decode, and split a header name `name` from header list `list`, run these steps. They return null or a list of strings.

1. Let `value` be the result of getting `name` from `list`.

2. If `value` is null, then return null.

3. Return the result of getting, decoding, and splitting `value`.

This is how get, decode, and split functions in practice with \``A`\` as the `name` argument:

Headers (as on the network) | Output
---|---
`A: nosniff,` | « "`nosniff`", "" »
`A: nosniff` `B: sniff` `A:` | « "`nosniff`", "", "" »
`A:` `B: sniff` | « "" »
`B: sniff` | null
`A: text/html;", x/x` | « "`text/html;", x/x`" »
`A: text/html;"` `A: x/x` | « "`text/html;"`, x/x`" »
`A: x/x;test="hi",y/y` | « "`x/x;test="hi"`", "`y/y`" »
`A: x/x;test="hi"` `C: **bingo**` `A: y/y` | « "`x/x;test="hi"`", "`y/y`" »
`A: x / x,,,1` | « "`x / x`", "", "", "`1`" »
`A: x / x` `A: ,` `A: 1` | « "`x / x`", "", "", "`1`" »
`A: "1,2", 3` | « "`"1,2"`", "`3`" »
`A: "1,2"` `D: 4` `A: 3` | « "`"1,2"`", "`3`" »

To get, decode, and split a header value `value`, run these steps. They return a list of strings.

1. Let `input` be the result of isomorphic decoding `value`.

2. Let `position` be a position variable for `input`, initially pointing at the start of `input`.

3. Let `values` be a list of strings, initially « ».

4. Let `temporaryValue` be the empty string.

5. While true:

   1. Append the result of collecting a sequence of code points that are not U+0022 (") or U+002C (,) from `input`, given `position`, to `temporaryValue`.

      The result might be the empty string.

   2. If `position` is not past the end of `input` and the code point at `position` within `input` is U+0022 ("):

      1. Append the result of collecting an HTTP quoted string from `input`, given `position`, to `temporaryValue`.

      2. If `position` is not past the end of `input`, then continue.

   3. Remove all HTTP tab or space from the start and end of `temporaryValue`.

   4. Append `temporaryValue` to `values`.

   5. Set `temporaryValue` to the empty string.

   6. If `position` is past the end of `input`, then return `values`.

   7. Assert: the code point at `position` within `input` is U+002C (,).

   8. Advance `position` by 1.

Except for blessed call sites, the algorithm directly above is not to be invoked directly. Use get, decode, and split instead.

To append a header (`name`, `value`) to a header list `list`:

1. If `list` contains `name`, then set `name` to the first such header's name.

   This reuses the casing of the name of the header already in `list`, if any. If there are multiple matched headers their names will all be identical.

2. Append (`name`, `value`) to `list`.

To delete a header name `name` from a header list `list`, remove all headers whose name is a byte-case-insensitive match for `name` from `list`.

To set a header (`name`, `value`) in a header list `list`:

1. If `list` contains `name`, then set the value of the first such header to `value` and remove the others.

2. Otherwise, append (`name`, `value`) to `list`.

To combine a header (`name`, `value`) in a header list `list`:

1. If `list` contains `name`, then set the value of the first such header to its value, followed by 0x2C 0x20, followed by `value`.

2. Otherwise, append (`name`, `value`) to `list`.

Combine is used by `XMLHttpRequest` and the WebSocket protocol handshake.

To convert header names to a sorted-lowercase set, given a list of names `headerNames`, run these steps. They return an ordered set of header names.

1. Let `headerNamesSet` be a new ordered set.

2. For each `name` of `headerNames`, append the result of byte-lowercasing `name` to `headerNamesSet`.

3. Return the result of sorting `headerNamesSet` in ascending order with byte less than.

To sort and combine a header list `list`, run these steps. They return a header list.

1. Let `headers` be a header list.

2. Let `names` be the result of convert header names to a sorted-lowercase set with all the names of the headers in `list`.

3. For each `name` of `names`:

   1. If `name` is \``set-cookie`\`, then:

      1. Let `values` be a list of all values of headers in `list` whose name is a byte-case-insensitive match for `name`, in order.

      2. For each `value` of `values`:

         1. Append (`name`, `value`) to `headers`.

   2. Otherwise:

      1. Let `value` be the result of getting `name` from `list`.

      2. Assert: `value` is non-null.

      3. Append (`name`, `value`) to `headers`.

4. Return `headers`.


A header is a tuple that consists of a name (a header name) and value (a header value).

A header name is a byte sequence that matches the field-name token production.

A header value is a byte sequence that matches the following conditions:

- Has no leading or trailing HTTP tab or space bytes.

- Contains no 0x00 (NUL) or HTTP newline bytes.

The definition of header value is not defined in terms of the field-value token production as it is not compatible with deployed content.

To normalize a byte sequence `potentialValue`, remove any leading and trailing HTTP whitespace bytes from `potentialValue`.


To determine whether a header (`name`, `value`) is a CORS-safelisted request-header, run these steps:

1. If `value`'s length is greater than 128, then return false.

2. Byte-lowercase `name` and switch on the result:

   \``accept`\`
   : If `value` contains a CORS-unsafe request-header byte, then return false.

   \``accept-language`\`
   \``content-language`\`
   : If `value` contains a byte that is not in the range 0x30 (0) to 0x39 (9), inclusive, is not in the range 0x41 (A) to 0x5A (Z), inclusive, is not in the range 0x61 (a) to 0x7A (z), inclusive, and is not 0x20 (SP), 0x2A (\*), 0x2C (,), 0x2D (-), 0x2E (.), 0x3B (;), or 0x3D (=), then return false.

   \``content-type`\`
   : 1. If `value` contains a CORS-unsafe request-header byte, then return false.

     2. Let `mimeType` be the result of parsing the result of isomorphic decoding `value`.

     3. If `mimeType` is failure, then return false.

     4. If `mimeType`'s essence is not "`application/x-www-form-urlencoded`", "`multipart/form-data`", or "`text/plain`", then return false.

     This intentionally does not use extract a MIME type as that algorithm is rather forgiving and servers are not expected to implement it.

     If extract a MIME type were used the following request would not result in a CORS preflight and a naïve parser on the server might treat the request body as JSON:

     ```javascript
     fetch("https://victim.example/naïve-endpoint", {
       method: "POST",
       headers: [
         ["Content-Type", "application/json"],
         ["Content-Type", "text/plain"]
       ],
       credentials: "include",
       body: JSON.stringify(exerciseForTheReader)
     });
     ```

   \``range`\`
   : 1. Let `rangeValue` be the result of parsing a single range header value given `value` and false.

     2. If `rangeValue` is failure, then return false.

     3. If `rangeValue`[0] is null, then return false.

        As web browsers have historically not emitted ranges such as \``bytes=-500`\` this algorithm does not safelist them.

   Otherwise
   : Return false.

3. Return true.

There are limited exceptions to the \``Content-Type`\` header safelist, as documented in CORS protocol exceptions.

A CORS-unsafe request-header byte is a byte `byte` for which one of the following is true:

- `byte` is less than 0x20 and is not 0x09 HT

- `byte` is 0x22 ("), 0x28 (left parenthesis), 0x29 (right parenthesis), 0x3A (:), 0x3C (\<), 0x3E (\>), 0x3F (?), 0x40 (@), 0x5B (\[), 0x5C (\\), 0x5D (\]), 0x7B ({), 0x7D (}), or 0x7F DEL.

The CORS-unsafe request-header names, given a header list `headers`, are determined as follows:

1. Let `unsafeNames` be a new list.

2. Let `potentiallyUnsafeNames` be a new list.

3. Let `safelistValueSize` be 0.

4. For each `header` of `headers`:

   1. If `header` is not a CORS-safelisted request-header, then append `header`'s name to `unsafeNames`.

   2. Otherwise, append `header`'s name to `potentiallyUnsafeNames` and increase `safelistValueSize` by `header`'s value's length.

5. If `safelistValueSize` is greater than 1024, then for each `name` of `potentiallyUnsafeNames`, append `name` to `unsafeNames`.

6. Return the result of convert header names to a sorted-lowercase set with `unsafeNames`.

A CORS non-wildcard request-header name is a header name that is a byte-case-insensitive match for \``Authorization`\`.

A privileged no-CORS request-header name is a header name that is a byte-case-insensitive match for one of

- \``Range`\`.

These are headers that can be set by privileged APIs, and will be preserved if their associated request object is copied, but will be removed if the request is modified by unprivileged APIs.

\``Range`\` headers are commonly used by downloads and media fetches.

A helper is provided to add a range header to a particular request.

A CORS-safelisted response-header name, given a list of header names `list`, is a header name that is a byte-case-insensitive match for one of

- \``Cache-Control`\`
- \``Content-Language`\`
- \``Content-Length`\`
- \``Content-Type`\`
- \``Expires`\`
- \``Last-Modified`\`
- \``Pragma`\`
- Any item in `list` that is not a forbidden response-header name.

A no-CORS-safelisted request-header name is a header name that is a byte-case-insensitive match for one of

- \``Accept`\`
- \``Accept-Language`\`
- \``Content-Language`\`
- \``Content-Type`\`

To determine whether a header (`name`, `value`) is a no-CORS-safelisted request-header, run these steps:

1. If `name` is not a no-CORS-safelisted request-header name, then return false.

2. Return whether (`name`, `value`) is a CORS-safelisted request-header.

A header (`name`, `value`) is forbidden request-header if these steps return true:

1. If `name` is a byte-case-insensitive match for one of:

   - \``Accept-Charset`\`
   - \``Accept-Encoding`\`
   - \``Access-Control-Request-Headers`\`
   - \``Access-Control-Request-Method`\`
   - \``Connection`\`
   - \``Content-Length`\`
   - \``Cookie`\`
   - \``Cookie2`\`
   - \``Date`\`
   - \``DNT`\`
   - \``Expect`\`
   - \``Host`\`
   - \``Keep-Alive`\`
   - \``Origin`\`
   - \``Referer`\`
   - \``Set-Cookie`\`
   - \``TE`\`
   - \``Trailer`\`
   - \``Transfer-Encoding`\`
   - \``Upgrade`\`
   - \``Via`\`

   then return true.

2. If `name` when byte-lowercased starts with \``proxy-`\` or \``sec-`\`, then return true.

3. If `name` is a byte-case-insensitive match for one of:

   - \``X-HTTP-Method`\`
   - \``X-HTTP-Method-Override`\`
   - \``X-Method-Override`\`

   then:

   1. Let `parsedValues` be the result of getting, decoding, and splitting `value`.

   2. For each `method` of `parsedValues`: if the isomorphic encoding of `method` is a forbidden method, then return true.

4. Return false.

These are forbidden so the user agent remains in full control over them.

Header names starting with \``Sec-`\` are reserved to allow new headers to be minted that are safe from APIs using fetch that allow control over headers by developers, such as `XMLHttpRequest`. [XHR]

The \``Set-Cookie`\` header is semantically a response header, so it is not useful on requests. Because \``Set-Cookie`\` headers cannot be combined, they require more complex handling in the `Headers` object. It is forbidden here to avoid leaking this complexity into requests.

A forbidden response-header name is a header name that is a byte-case-insensitive match for one of:

- \``Set-Cookie`\`
- \``Set-Cookie2`\`

A request-body-header name is a header name that is a byte-case-insensitive match for one of:

- \``Content-Encoding`\`
- \``Content-Language`\`
- \``Content-Location`\`
- \``Content-Type`\`


To extract header values given a header `header`, run these steps:

1. If parsing `header`'s value, per the ABNF for `header`'s name, fails, then return failure.

2. Return one or more values resulting from parsing `header`'s value, per the ABNF for `header`'s name.

To extract header list values given a header name `name` and a header list `list`, run these steps:

1. If `list` does not contain `name`, then return null.

2. If the ABNF for `name` allows a single header and `list` contains more than one, then return failure.

   If different error handling is needed, extract the desired header first.

3. Let `values` be an empty list.

4. For each header `header` `list` contains whose name is `name`:

   1. Let `extract` be the result of extracting header values from `header`.

   2. If `extract` is failure, then return failure.

   3. Append each value in `extract`, in order, to `values`.

5. Return `values`.

To build a content range given an integer `rangeStart`, an integer `rangeEnd`, and an integer `fullLength`, run these steps:

1. Let `contentRange` be \``bytes `\`.

2. Append `rangeStart`, serialized and isomorphic encoded, to `contentRange`.

3. Append 0x2D (-) to `contentRange`.

4. Append `rangeEnd`, serialized and isomorphic encoded to `contentRange`.

5. Append 0x2F (/) to `contentRange`.

6. Append `fullLength`, serialized and isomorphic encoded to `contentRange`.

7. Return `contentRange`.

To parse a single range header value from a byte sequence `value` and a boolean `allowWhitespace`, run these steps:

1. Let `data` be the isomorphic decoding of `value`.

2. If `data` does not start with "`bytes`", then return failure.

3. Let `position` be a position variable for `data`, initially pointing at the 5th code point of `data`.

4. If `allowWhitespace` is true, collect a sequence of code points that are HTTP tab or space, from `data` given `position`.

5. If the code point at `position` within `data` is not U+003D (=), then return failure.

6. Advance `position` by 1.

7. If `allowWhitespace` is true, collect a sequence of code points that are HTTP tab or space, from `data` given `position`.

8. Let `rangeStart` be the result of collecting a sequence of code points that are ASCII digits, from `data` given `position`.

9. Let `rangeStartValue` be `rangeStart`, interpreted as decimal number, if `rangeStart` is not the empty string; otherwise null.

10. If `allowWhitespace` is true, collect a sequence of code points that are HTTP tab or space, from `data` given `position`.

11. If the code point at `position` within `data` is not U+002D (-), then return failure.

12. Advance `position` by 1.

13. If `allowWhitespace` is true, collect a sequence of code points that are HTTP tab or space, from `data` given `position`.

14. Let `rangeEnd` be the result of collecting a sequence of code points that are ASCII digits, from `data` given `position`.

15. Let `rangeEndValue` be `rangeEnd`, interpreted as decimal number, if `rangeEnd` is not the empty string; otherwise null.

16. If `position` is not past the end of `data`, then return failure.

17. If `rangeEndValue` and `rangeStartValue` are null, then return failure.

18. If `rangeStartValue` and `rangeEndValue` are numbers, and `rangeStartValue` is greater than `rangeEndValue`, then return failure.

19. Return (`rangeStartValue`, `rangeEndValue`).

    The range end or start can be omitted, e.g., \``bytes=0-`\` or \``bytes=-500`\` are valid ranges.

Parse a single range header value succeeds for a subset of allowed range header values, but it is the most common form used by user agents when requesting media or resuming downloads. This format of range header value can be set using add a range header.


A default \``User-Agent`\` value is an implementation-defined header value for the \``User-Agent`\` header.

For unfortunate web compatibility reasons, web browsers are strongly encouraged to have this value start with \``Mozilla/5.0 (`\` and be generally modeled after other web browsers.

To get the environment settings object `environment`'s environment default \``User-Agent`\` value:

1. Let `userAgent` be the WebDriver BiDi emulated User-Agent for `environment`.

2. If `userAgent` is non-null, then return `userAgent`, isomorphic encoded.

3. Return the default \``User-Agent`\` value.

The document \``Accept`\` header value is \``text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8`\`.


#### Statuses

A status is an integer in the range 0 to 999, inclusive.

Various edge cases in mapping HTTP/1's `status-code` to this concept are worked on in issue #1156.

A null body status is a status that is 101, 103, 204, 205, or 304.

An ok status is a status in the range 200 to 299, inclusive.

A redirect status is a status that is 301, 302, 303, 307, or 308.


#### Bodies

A body consists of:

- A stream (a `ReadableStream` object).

- A source (null, a byte sequence, a `Blob` object, or a `FormData` object), initially null.

- A length (null or an integer), initially null.

To clone a body `body`, run these steps:

1. Let « `out1`, `out2` » be the result of teeing `body`'s stream.

2. Set `body`'s stream to `out1`.

3. Return a body whose stream is `out2` and other members are copied from `body`.

To get a byte sequence `bytes` as a body, return the body of the result of safely extracting `bytes`.


To incrementally read a body `body`, given an algorithm `processBodyChunk`, an algorithm `processEndOfBody`, an algorithm `processBodyError`, and an optional null, parallel queue, or global object `taskDestination` (default null), run these steps. `processBodyChunk` must be an algorithm accepting a byte sequence. `processEndOfBody` must be an algorithm accepting no arguments. `processBodyError` must be an algorithm accepting an exception.

1. If `taskDestination` is null, then set `taskDestination` to the result of starting a new parallel queue.

2. Let `reader` be the result of getting a reader for `body`'s stream.

   This operation will not throw an exception.

3. Perform the incrementally-read loop given `reader`, `taskDestination`, `processBodyChunk`, `processEndOfBody`, and `processBodyError`.

To perform the incrementally-read loop, given a `ReadableStreamDefaultReader` object `reader`, parallel queue or global object `taskDestination`, algorithm `processBodyChunk`, algorithm `processEndOfBody`, and algorithm `processBodyError`:

1. Let `readRequest` be the following read request:

   chunk steps, given `chunk`
   : 1. Let `continueAlgorithm` be null.

     2. If `chunk` is not a `Uint8Array` object, then set `continueAlgorithm` to this step: run `processBodyError` given a `TypeError`.

     3. Otherwise:

        1. Let `bytes` be a copy of `chunk`.

           Implementations are strongly encouraged to use an implementation strategy that avoids this copy where possible.

        2. Set `continueAlgorithm` to these steps:

           1. Run `processBodyChunk` given `bytes`.

           2. Perform the incrementally-read loop given `reader`, `taskDestination`, `processBodyChunk`, `processEndOfBody`, and `processBodyError`.

     4. Queue a fetch task given `continueAlgorithm` and `taskDestination`.

   close steps
   : 1. Queue a fetch task given `processEndOfBody` and `taskDestination`.

   error steps, given `e`
   : 1. Queue a fetch task to run `processBodyError` given `e`, with `taskDestination`.

2. Read a chunk from `reader` given `readRequest`.

To fully read a body `body`, given an algorithm `processBody`, an algorithm `processBodyError`, and an optional null, parallel queue, or global object `taskDestination` (default null), run these steps. `processBody` must be an algorithm accepting a byte sequence. `processBodyError` must be an algorithm optionally accepting an exception.

1. If `taskDestination` is null, then set `taskDestination` to the result of starting a new parallel queue.

2. Let `successSteps` given a byte sequence `bytes` be to queue a fetch task to run `processBody` given `bytes`, with `taskDestination`.

3. Let `errorSteps` optionally given an exception `exception` be to queue a fetch task to run `processBodyError` given `exception`, with `taskDestination`.

4. Let `reader` be the result of getting a reader for `body`'s stream. If that threw an exception, then run `errorSteps` with that exception and return.

5. Read all bytes from `reader`, given `successSteps` and `errorSteps`.


A body with type is a tuple that consists of a body (a body) and a type (a header value or null).


To handle content codings given `codings` and `bytes`, run these steps:

1. If `codings` are not supported, then return `bytes`.

2. Return the result of decoding `bytes` with `codings` as explained in HTTP, if decoding does not result in an error, and failure otherwise. [HTTP]


#### Requests

This section documents how requests work in detail. To get started, see Setting up a request.

The input to fetch is a request.

A request has an associated method (a method). Unless stated otherwise it is \``GET`\`.

This can be updated during redirects to \``GET`\` as described in HTTP fetch.

A request has an associated URL (a URL).

Implementations are encouraged to make this a pointer to the first URL in request's URL list. It is provided as a distinct field solely for the convenience of other standards hooking into Fetch.

A request has an associated local-URLs-only flag. Unless stated otherwise it is unset.

A request has an associated header list (a header list). Unless stated otherwise it is « ».

A request has an associated unsafe-request flag. Unless stated otherwise it is unset.

The unsafe-request flag is set by APIs such as `fetch()` and `XMLHttpRequest` to ensure a CORS-preflight fetch is done based on the supplied method and header list. It does not free an API from outlawing forbidden methods and forbidden request-headers.

A request has an associated body (null, a byte sequence, or a body). Unless stated otherwise it is null.

A byte sequence will be safely extracted into a body early on in fetch. As part of HTTP fetch it is possible for this field to be set to null due to certain redirects.


A request has an associated client (null or an environment settings object).

A request has an associated reserved client (null, an environment, or an environment settings object). Unless stated otherwise it is null.

This is only used by navigation requests and worker requests, but not service worker requests. It references an environment for a navigation request and an environment settings object for a worker request.

A request has an associated replaces client id (a string). Unless stated otherwise it is the empty string.

This is only used by navigation requests. It is the id of the target browsing context's active document's environment settings object.

A request has an associated traversable for user prompts, that is "`no-traversable`", "`client`", or a traversable navigable. Unless stated otherwise it is "`client`".

This is used to determine whether and where to show necessary UI for the request, such as authentication prompts or client certificate dialogs.

"`no-traversable`"
: No UI is shown; usually the request fails with a network error.

"`client`"
: This value will automatically be changed to either "`no-traversable`" or to a traversable navigable derived from the request's client during fetching. This provides a convenient way for standards to not have to explicitly set a request's traversable for user prompts.

a traversable navigable
: The UI shown will be associated with the browser interface elements that are displaying that traversable navigable.

When displaying a user interface associated with a request in that request's traversable for user prompts, the user agent should update the address bar to display something derived from the request's current URL (and not, e.g., leave it at its previous value, derived from the URL of the request's initiator). Additionally, the user agent should avoid displaying content from the request's initiator in the traversable for user prompts, especially in the case of cross-origin requests. Displaying a blank page behind such prompts is a good way to fulfill these requirements. Failing to follow these guidelines can confuse users as to which origin is responsible for the prompt.

A request has an associated boolean keepalive. Unless stated otherwise it is false.

This can be used to allow the request to outlive the environment settings object, e.g., `navigator.sendBeacon()` and the HTML `img` element use this. Requests with this set to true are subject to additional processing requirements.

A request has an associated initiator type, which is null, "`audio`", "`beacon`", "`body`", "`css`", "`early-hints`", "`embed`", "`fetch`", "`font`", "`frame`", "`iframe`", "`image`", "`img`", "`input`", "`link`", "`object`", "`ping`", "`script`", "`track`", "`video`", "`xmlhttprequest`", or "`other`". Unless stated otherwise it is null. [RESOURCE-TIMING]

A request has an associated service-workers mode, that is "`all`" or "`none`". Unless stated otherwise it is "`all`".

This determines which service workers will receive a `fetch` event for this fetch.

"`all`"
: Relevant service workers will get a `fetch` event for this fetch.

"`none`"
: No service workers will get events for this fetch.

A request has an associated initiator, which is the empty string, "`download`", "`imageset`", "`manifest`", "`prefetch`", "`prerender`", or "`xslt`". Unless stated otherwise it is the empty string.

A request's initiator is not particularly granular for the time being as other specifications do not require it to be. It is primarily a specification device to assist defining CSP and Mixed Content. It is not exposed to JavaScript. [CSP] [MIX]

A destination type is one of: the empty string, "`audio`", "`audioworklet`", "`document`", "`embed`", "`font`", "`frame`", "`iframe`", "`image`", "`json`", "`manifest`", "`object`", "`paintworklet`", "`report`", "`script`", "`serviceworker`", "`sharedworker`", "`style`", "`track`", "`video`", "`webidentity`", "`worker`", or "`xslt`".

A request has an associated destination, which is destination type. Unless stated otherwise it is the empty string.

These are reflected on `RequestDestination` except for "`serviceworker`" and "`webidentity`" as fetches with those destinations skip service workers.

A request's destination is script-like if it is "`audioworklet`", "`paintworklet`", "`script`", "`serviceworker`", "`sharedworker`", or "`worker`".

Algorithms that use script-like should also consider "`xslt`" as that too can cause script execution. It is not included in the list as it is not always relevant and might require different behavior.

The following table illustrates the relationship between a request's initiator, destination, CSP directives, and features. It is not exhaustive with respect to features. Features need to have the relevant values defined in their respective standards.

Initiator | Destination | CSP directive | Features
---|---|---|---
"" | "`report`" | --- | CSP, NEL reports.
"" | "`document`" | --- | HTML's navigate algorithm (top-level only).
"" | "`frame`" | `child-src` | HTML's `<frame>`
"" | "`iframe`" | `child-src` | HTML's `<iframe>`
"" | "" | `connect-src` | `navigator.sendBeacon()`, `EventSource`, HTML's `<a ping="">` and `<area ping="">`, `fetch()`, `fetchLater()`, `XMLHttpRequest`, `WebSocket`, Cache API
"" | "`object`" | `object-src` | HTML's `<object>`
"" | "`embed`" | `object-src` | HTML's `<embed>`
"" | "`audio`" | `media-src` | HTML's `<audio>`
"" | "`font`" | `font-src` | CSS' `@font-face`
"" | "`image`" | `img-src` | HTML's `<img src>`, `/favicon.ico` resource, SVG's `<image>`, CSS' `background-image`, CSS' `cursor`, CSS' `list-style-image`, ...
"" | "`audioworklet`" | `script-src` | `audioWorklet.addModule()`
"" | "`paintworklet`" | `script-src` | `CSS.paintWorklet.addModule()`
"" | "`script`" | `script-src` | HTML's `<script>`, `importScripts()`
"" | "`serviceworker`" | `child-src`, `script-src`, `worker-src` | `navigator.serviceWorker.register()`
"" | "`sharedworker`" | `child-src`, `script-src`, `worker-src` | `SharedWorker`
"" | "`webidentity`" | `connect-src` | `Federated Credential Management requests`
"" | "`worker`" | `child-src`, `script-src`, `worker-src` | `Worker`
"" | "`json`" | `connect-src` | `import "..." with { type: "json" }`
"" | "`style`" | `style-src` | HTML's `<link rel=stylesheet>`, CSS' `@import`, `import "..." with { type: "css" }`
"" | "`track`" | `media-src` | HTML's `<track>`
"" | "`video`" | `media-src` | HTML's `<video>` element
"`download`" | "" | --- | HTML's `download=""`, "Save Link As..." UI
"`imageset`" | "`image`" | `img-src` | HTML's `<img srcset>` and `<picture>`
"`manifest`" | "`manifest`" | `manifest-src` | HTML's `<link rel=manifest>`
"`prefetch`" | "" | `default-src` (no specific directive) | HTML's `<link rel=prefetch>`
"`prerender`" | "" | `default-src` (no specific directive) | HTML's `<link rel=prerender>`
"`xslt`" | "`xslt`" | `script-src` | `<?xml-stylesheet>`

CSP's `form-action` needs to be a hook directly in HTML's navigate or form submission algorithm.

CSP will also need to check request's client's global object's associated `Document`'s ancestor navigables for various CSP directives.


A request has an associated priority, which is "`high`", "`low`", or "`auto`". Unless stated otherwise it is "`auto`".

A request has an associated internal priority (null or an implementation-defined object). Unless otherwise stated it is null.

A request has an associated origin, which is "`client`" or an origin. Unless stated otherwise it is "`client`".

"`client`" is changed to an origin during fetching. It provides a convenient way for standards to not have to set request's origin.

A request has an associated top-level navigation initiator origin, which is an origin or null. Unless stated otherwise it is null.

A request has an associated policy container, which is "`client`" or a policy container. Unless stated otherwise it is "`client`".

"`client`" is changed to a policy container during fetching. It provides a convenient way for standards to not have to set request's policy container.

A request has an associated referrer, which is "`no-referrer`", "`client`", or a URL. Unless stated otherwise it is "`client`".

"`client`" is changed to "`no-referrer`" or a URL during fetching. It provides a convenient way for standards to not have to set request's referrer.

A request has an associated referrer policy, which is a referrer policy. Unless stated otherwise it is the empty string. [REFERRER]

This can be used to override the referrer policy to be used for this request.

A request has an associated mode, which is "`same-origin`", "`cors`", "`no-cors`", "`navigate`", or "`websocket`". Unless stated otherwise, it is "`no-cors`".

"`same-origin`"
: Used to ensure requests are made to same-origin URLs. Fetch will return a network error if the request is not made to a same-origin URL.

"`cors`"
: For requests whose response tainting gets set to "`cors`", makes the request a CORS request --- in which case, fetch will return a network error if the requested resource does not understand the CORS protocol, or if the requested resource is one that intentionally does not participate in the CORS protocol.

"`no-cors`"
: Restricts requests to using CORS-safelisted methods and CORS-safelisted request-headers. Upon success, fetch will return an opaque filtered response.

"`navigate`"
: This is a special mode used only when navigating between documents.

"`websocket`"
: This is a special mode used only when establishing a WebSocket connection.

Even though the default request mode is "`no-cors`", standards are highly discouraged from using it for new features. It is rather unsafe.

A request has an associated use-CORS-preflight flag. Unless stated otherwise, it is unset.

The use-CORS-preflight flag being set is one of several conditions that results in a CORS-preflight request. The use-CORS-preflight flag is set if either one or more event listeners are registered on an `XMLHttpRequestUpload` object or if a `ReadableStream` object is used in a request.

A request has an associated credentials mode, which is "`omit`", "`same-origin`", or "`include`". Unless stated otherwise, it is "`same-origin`".

"`omit`"
: Excludes credentials from this request, and causes any credentials sent back in the response to be ignored.

"`same-origin`"
: Include credentials with requests made to same-origin URLs, and use any credentials sent back in responses from same-origin URLs.

"`include`"
: Always includes credentials with this request, and always use any credentials sent back in the response.

Request's credentials mode controls the flow of credentials during a fetch. When request's mode is "`navigate`", its credentials mode is assumed to be "`include`" and fetch does not currently account for other values. If HTML changes here, this standard will need corresponding changes.

A request has an associated use-URL-credentials flag. Unless stated otherwise, it is unset.

When this flag is set, when a request's URL has a username and password, and there is an available authentication entry for the request, then the URL's credentials are preferred over that of the authentication entry. Modern specifications avoid setting this flag, since putting credentials in URLs is discouraged, but some older features set it for compatibility reasons.

A request has an associated cache mode, which is "`default`", "`no-store`", "`reload`", "`no-cache`", "`force-cache`", or "`only-if-cached`". Unless stated otherwise, it is "`default`".

"`default`"
: Fetch will inspect the HTTP cache on the way to the network. If the HTTP cache contains a matching fresh response it will be returned. If the HTTP cache contains a matching stale-while-revalidate response it will be returned, and a conditional network fetch will be made to update the entry in the HTTP cache. If the HTTP cache contains a matching stale response, a conditional network fetch will be returned to update the entry in the HTTP cache. Otherwise, a non-conditional network fetch will be returned to update the entry in the HTTP cache. [HTTP] [HTTP-CACHING] [STALE-WHILE-REVALIDATE]

"`no-store`"
: Fetch behaves as if there is no HTTP cache at all.

"`reload`"
: Fetch behaves as if there is no HTTP cache on the way to the network. Ergo, it creates a normal request and updates the HTTP cache with the response.

"`no-cache`"
: Fetch creates a conditional request if there is a response in the HTTP cache and a normal request otherwise. It then updates the HTTP cache with the response.

"`force-cache`"
: Fetch uses any response in the HTTP cache matching the request, not paying attention to staleness. If there was no response, it creates a normal request and updates the HTTP cache with the response.

"`only-if-cached`"
: Fetch uses any response in the HTTP cache matching the request, not paying attention to staleness. If there was no response, it returns a network error. (Can only be used when request's mode is "`same-origin`". Any cached redirects will be followed assuming request's redirect mode is "`follow`" and the redirects do not violate request's mode.)

If header list contains \``If-Modified-Since`\`, \``If-None-Match`\`, \``If-Unmodified-Since`\`, \``If-Match`\`, or \``If-Range`\`, fetch will set cache mode to "`no-store`" if it is "`default`".

A request has an associated redirect mode, which is "`follow`", "`error`", or "`manual`". Unless stated otherwise, it is "`follow`".

"`follow`"
: Follow all redirects incurred when fetching a resource.

"`error`"
: Return a network error when a request is met with a redirect.

"`manual`"
: Retrieves an opaque-redirect filtered response when a request is met with a redirect, to allow a service worker to replay the redirect offline. The response is otherwise indistinguishable from a network error, to not violate atomic HTTP redirect handling.

A request has associated integrity metadata (a string). Unless stated otherwise, it is the empty string.

A request has associated cryptographic nonce metadata (a string). Unless stated otherwise, it is the empty string.

A request has associated parser metadata which is the empty string, "`parser-inserted`", or "`not-parser-inserted`". Unless otherwise stated, it is the empty string.

A request's cryptographic nonce metadata and parser metadata are generally populated from attributes and flags on the HTML element responsible for creating a request. They are used by various algorithms in Content Security Policy to determine whether requests or responses are to be blocked in a given context. [CSP]

A request has an associated reload-navigation flag. Unless stated otherwise, it is unset.

This flag is for exclusive use by HTML's navigate algorithm. [HTML]

A request has an associated history-navigation flag. Unless stated otherwise, it is unset.

This flag is for exclusive use by HTML's navigate algorithm. [HTML]

A request has an associated boolean user-activation. Unless stated otherwise, it is false.

This is for exclusive use by HTML's navigate algorithm. [HTML]

A request has an associated boolean render-blocking. Unless stated otherwise, it is false.

This flag is for exclusive use by HTML's render-blocking mechanism. [HTML]


A request has an associated URL list (a list of one or more URLs). Unless stated otherwise, it is a list containing a copy of request's URL.

A request has an associated current URL. It is a pointer to the last URL in request's URL list.

A request has an associated redirect count. Unless stated otherwise, it is zero.

A request has an associated response tainting, which is "`basic`", "`cors`", or "`opaque`". Unless stated otherwise, it is "`basic`".

A request has an associated prevent no-cache cache-control header modification flag. Unless stated otherwise, it is unset.

A request has an associated done flag. Unless stated otherwise, it is unset.

A request has an associated timing allow failed flag. Unless stated otherwise, it is unset.

A request's URL list, current URL, redirect count, response tainting, done flag, and timing allow failed flag are used as bookkeeping details by the fetch algorithm.


A subresource request is a request whose destination is "`audio`", "`audioworklet`", "`font`", "`image`", "`json`", "`manifest`", "`paintworklet`", "`script`", "`style`", "`track`", "`video`", "`xslt`", or the empty string.

A non-subresource request is a request whose destination is "`document`", "`embed`", "`frame`", "`iframe`", "`object`", "`report`", "`serviceworker`", "`sharedworker`", or "`worker`".

A navigation request is a request whose destination is "`document`", "`embed`", "`frame`", "`iframe`", or "`object`".

See handle fetch for usage of these terms. [SW]


To compute the redirect-taint of a request `request`, perform the following steps. They return "`same-origin`", "`same-site`", or "`cross-site`".

1. Assert: `request`'s origin is not "`client`".

2. Let `lastURL` be null.

3. Let `taint` be "`same-origin`".

4. For each `url` of `request`'s URL list:

   1. If `lastURL` is null, then set `lastURL` to `url` and continue.

   2. If `url`'s origin is not same site with `lastURL`'s origin and `request`'s origin is not same site with `lastURL`'s origin, then return "`cross-site`".

   3. If `url`'s origin is not same origin with `lastURL`'s origin and `request`'s origin is not same origin with `lastURL`'s origin, then set `taint` to "`same-site`".

   4. Set `lastURL` to `url`.

5. Return `taint`.

Serializing a request origin, given a request `request`, is to run these steps:

1. Assert: `request`'s origin is not "`client`".

2. If `request`'s redirect-taint is not "`same-origin`", then return "`null`".

3. Return `request`'s origin, serialized.

Byte-serializing a request origin, given a request `request`, is to return the result of serializing a request origin with `request`, isomorphic encoded.


To clone a request `request`, run these steps:

1. Let `newRequest` be a copy of `request`, except for its body.

2. If `request`'s body is non-null, set `newRequest`'s body to the result of cloning `request`'s body.

3. Return `newRequest`.


To add a range header to a request `request`, with an integer `first`, and an optional integer `last`, run these steps:

1. Assert: `last` is not given, or `first` is less than or equal to `last`.

2. Let `rangeValue` be \``bytes=`\`.

3. Serialize and isomorphic encode `first`, and append the result to `rangeValue`.

4. Append 0x2D (-) to `rangeValue`.

5. If `last` is given, then serialize and isomorphic encode it, and append the result to `rangeValue`.

6. Append (\``Range`\`, `rangeValue`) to `request`'s header list.

A range header denotes an inclusive byte range. There a range header where `first` is 0 and `last` is 500, is a range of 501 bytes.

Features that combine multiple responses into one logical resource are historically a source of security bugs. Please seek security review for features that deal with partial responses.


To serialize a response URL for reporting, given a response `response`, run these steps:

1. Assert: `response`'s URL list is not empty.

2. Let `url` be a copy of `response`'s URL list[0].

   This is not `response`'s URL in order to avoid leaking information about redirect targets (see similar considerations for CSP reporting too). [CSP]

3. Set the username given `url` and the empty string.

4. Set the password given `url` and the empty string.

5. Return the serialization of `url` with *exclude fragment* set to true.

To check if Cross-Origin-Embedder-Policy allows credentials, given a request `request`, run these steps:

1. Assert: `request`'s origin is not "`client`".

2. If `request`'s mode is not "`no-cors`", then return true.

3. If `request`'s client is null, then return true.

4. If `request`'s client's policy container's embedder policy's value is not "`credentialless`", then return true.

5. If `request`'s origin is same origin with `request`'s current URL's origin and `request`'s redirect-taint is not "`same-origin`", then return true.

6. Return false.


#### Responses

The result of fetch is a response. A response evolves over time. That is, not all its fields are available straight away.

A response has an associated type which is "`basic`", "`cors`", "`default`", "`error`", "`opaque`", or "`opaqueredirect`". Unless stated otherwise, it is "`default`".

A response can have an associated aborted flag, which is initially unset.

This indicates that the request was intentionally aborted by the developer or end-user.

A response has an associated URL. It is a pointer to the last URL in response's URL list and null if response's URL list is empty.

A response has an associated URL list (a list of zero or more URLs). Unless stated otherwise, it is « ».

Except for the first and last URL, if any, a response's URL list is not directly exposed to script as that would violate atomic HTTP redirect handling.

A response has an associated status, which is a status. Unless stated otherwise it is 200.

A response has an associated status message. Unless stated otherwise it is the empty byte sequence.

Responses over an HTTP/2 connection will always have the empty byte sequence as status message as HTTP/2 does not support them.

A response has an associated header list (a header list). Unless stated otherwise it is « ».

A response has an associated body (null or a body). Unless stated otherwise it is null.

The source and length concepts of a network's response's body are always null.

A response has an associated cache state (the empty string, "`local`", or "`validated`"). Unless stated otherwise, it is the empty string.

This is intended for usage by Service Workers and Resource Timing. [SW] [RESOURCE-TIMING]

A response has an associated CORS-exposed header-name list (a list of zero or more header names). The list is empty unless otherwise specified.

A response will typically get its CORS-exposed header-name list set by extracting header values from the \``Access-Control-Expose-Headers`\` header. This list is used by a CORS filtered response to determine which headers to expose.

A response has an associated range-requested flag, which is initially unset.

This is used to prevent a partial response from an earlier ranged request being provided to an API that didn't make a range request. See the flag's usage for a detailed description of the attack.

A response has an associated request-includes-credentials (a boolean), which is initially true.

A response has an associated timing allow passed flag, which is initially unset.

This is used so that the caller to a fetch can determine if sensitive timing data is allowed on the resource fetched by looking at the flag of the response returned. Because the flag on the response of a redirect has to be set if it was set for previous responses in the redirect chain, this is also tracked internally using the request's timing allow failed flag.

A response has an associated body info (a response body info). Unless stated otherwise, it is a new response body info.

A response has an associated service worker timing info (null or a service worker timing info), which is initially null.

A response has an associated redirect taint ("`same-origin`", "`same-site`", or "`cross-site`"), which is initially "`same-origin`".


A network error is a response whose type is "`error`", status is 0, status message is the empty byte sequence, header list is « », body is null, and body info is a new response body info.

An aborted network error is a network error whose aborted flag is set.

To create the appropriate network error given fetch params `fetchParams`:

1. Assert: `fetchParams` is canceled.

2. Return an aborted network error if `fetchParams` is aborted; otherwise return a network error.


A filtered response is a response that offers a limited view on an associated response. This associated response can be accessed through filtered response's internal response (a response that is neither a network error nor a filtered response).

Unless stated otherwise a filtered response's associated concepts (such as its body) refer to the associated concepts of its internal response. (The exceptions to this are listed below as part of defining the concrete types of filtered responses.)

The fetch algorithm by way of *processResponse* and equivalent parameters exposes filtered responses to callers to ensure they do not accidentally leak information. If the information needs to be revealed for legacy reasons, e.g., to feed image data to a decoder, the associated internal response can be used by specification algorithms.

New specifications ought not to build further on opaque filtered responses or opaque-redirect filtered responses. Those are legacy constructs and cannot always be adequately protected given contemporary computer architecture.

A basic filtered response is a filtered response whose type is "`basic`" and header list excludes any headers in internal response's header list whose name is a forbidden response-header name.

A CORS filtered response is a filtered response whose type is "`cors`" and header list excludes any headers in internal response's header list whose name is *not* a CORS-safelisted response-header name, given internal response's CORS-exposed header-name list.

An opaque filtered response is a filtered response whose type is "`opaque`", URL list is « », status is 0, status message is the empty byte sequence, header list is « », body is null, and body info is a new response body info.

An opaque-redirect filtered response is a filtered response whose type is "`opaqueredirect`", status is 0, status message is the empty byte sequence, header list is « », body is null, and body info is a new response body info.

Exposing the URL list for opaque-redirect filtered responses is harmless since no redirects are followed.

In other words, an opaque filtered response and an opaque-redirect filtered response are nearly indistinguishable from a network error. When introducing new APIs, do not use the internal response for internal specification algorithms as that will leak information.

This also means that JavaScript APIs, such as `response.ok`, will return rather useless results.

The type of a response is exposed to script through the `type` getter:

```javascript
console.log(new Response().type); // "default"

console.log((await fetch("/")).type); // "basic"

console.log((await fetch("https://api.example/status")).type); // "cors"

console.log((await fetch("https://crossorigin.example/image", { mode: "no-cors" })).type); // "opaque"

console.log((await fetch("/surprise-me", { redirect: "manual" })).type); // "opaqueredirect"
```

(This assumes that the various resources exist, `https://api.example/status` has the appropriate CORS headers, and `/surprise-me` uses a redirect status.)


To clone a response `response`, run these steps:

1. If `response` is a filtered response, then return a new identical filtered response whose internal response is a clone of `response`'s internal response.

2. Let `newResponse` be a copy of `response`, except for its body.

3. If `response`'s body is non-null, then set `newResponse`'s body to the result of cloning `response`'s body.

4. Return `newResponse`.


A fresh response is a response whose current age is within its freshness lifetime.

A stale-while-revalidate response is a response that is not a fresh response and whose current age is within the stale-while-revalidate lifetime. [HTTP-CACHING] [STALE-WHILE-REVALIDATE]

A stale response is a response that is not a fresh response or a stale-while-revalidate response.


The location URL of a response `response`, given null or an ASCII string `requestFragment`, is the value returned by the following steps. They return null, failure, or a URL.

1. If `response`'s status is not a redirect status, then return null.

2. Let `location` be the result of extracting header list values given \``Location`\` and `response`'s header list.

3. If `location` is a header value, then set `location` to the result of parsing `location` with `response`'s URL.

   If `response` was constructed through the `Response` constructor, `response`'s URL will be null, meaning that `location` will only parse successfully if it is an absolute-URL-with-fragment string.

4. If `location` is a URL whose fragment is null, then set `location`'s fragment to `requestFragment`.

   This ensures that synthetic (indeed, all) responses follow the processing model for redirects defined by HTTP. [HTTP]

5. Return `location`.

The location URL algorithm is exclusively used for redirect handling in this standard and in HTML's navigate algorithm which handles redirects manually. [HTML]


#### Miscellaneous

A potential destination is "`fetch`" or a destination which is not the empty string.

To translate a potential destination `potentialDestination`, run these steps:

1. If `potentialDestination` is "`fetch`", then return the empty string.

2. Assert: `potentialDestination` is a destination.

3. Return `potentialDestination`.


### Authentication entries

An authentication entry and a proxy-authentication entry are tuples of username, password, and realm, used for HTTP authentication and HTTP proxy authentication, and associated with one or more requests.

User agents should allow both to be cleared together with HTTP cookies and similar tracking functionality.

Further details are defined by HTTP. [HTTP] [HTTP-CACHING]


### Fetch groups

Each environment settings object has an associated fetch group, which holds a fetch group.

A fetch group holds information about fetches.

A fetch group has associated:

fetch records
: A list of fetch records.

deferred fetch records
: A list of deferred fetch records.

A fetch record is a struct with the following items:

request
: A request.

controller
: A fetch controller or null.


A deferred fetch record is a struct used to maintain state needed to invoke a fetch at a later time, e.g., when a document is unloaded or becomes not fully active. It has the following items:

request
: A request.

notify invoked
: An algorithm accepting no arguments.

invoke state (default "`pending`")
: "`pending`", "`sent`", or "`aborted`".


When a fetch group `fetchGroup` is terminated:

1. For each fetch record `record` of `fetchGroup`'s fetch records, if `record`'s controller is non-null and `record`'s request's done flag is unset and keepalive is false, terminate `record`'s controller.

2. Process deferred fetches for `fetchGroup`.


### Resolving domains

[![(This is a tracking vector.)](https://resources.whatwg.org/tracking-vector.svg)](https://infra.spec.whatwg.org/#tracking-vector) To resolve an origin, given a network partition key `key` and an origin `origin`:

1. If `origin`'s host is an IP address, then return « `origin`'s host ».

2. If `origin`'s host's public suffix is "`localhost`" or "`localhost.`", then return « `::1`, `127.0.0.1` ».

3. Perform an implementation-defined operation to turn `origin` into a set of one or more IP addresses.

   It is also implementation-defined whether other operations might be performed to get connection information beyond just IP addresses. For example, if `origin`'s scheme is an HTTP(S) scheme, the implementation might perform a DNS query for HTTPS RRs. [SVCB]

   If this operation succeeds, return the set of IP addresses and any additional implementation-defined information.

4. Return failure.

The results of resolve an origin may be cached. If they are cached, `key` should be used as part of the cache key.

Typically this operation would involve DNS and as such caching can happen on DNS servers without `key` being taken into account. Depending on the implementation it might also not be possible to take `key` into account locally. [RFC1035]

The order of the IP addresses that the resolve an origin algorithm can return can differ between invocations.

The particulars (apart from the cache key) are not tied down as they are not pertinent to the system the Fetch Standard establishes. Other documents ought not to build on this primitive without having a considered discussion with the Fetch Standard community first.


### Connections

A user agent has an associated connection pool. A connection pool is an ordered set of zero or more connections. Each connection is identified by an associated key (a network partition key), origin (an origin), and credentials (a boolean).

Each connection has an associated timing info (a connection timing info).

A connection timing info is a struct used to maintain timing information pertaining to the process of obtaining a connection. It has the following items:

domain lookup start time (default 0)
domain lookup end time (default 0)
connection start time (default 0)
connection end time (default 0)
secure connection start time (default 0)
: A `DOMHighResTimeStamp`.

ALPN negotiated protocol (default the empty byte sequence)
: A byte sequence.

To clamp and coarsen connection timing info, given a connection timing info `timingInfo`, a `DOMHighResTimeStamp` `defaultStartTime`, and a boolean `crossOriginIsolatedCapability`, run these steps:

1. If `timingInfo`'s connection start time is less than `defaultStartTime`, then return a new connection timing info whose domain lookup start time is `defaultStartTime`, domain lookup end time is `defaultStartTime`, connection start time is `defaultStartTime`, connection end time is `defaultStartTime`, secure connection start time is `defaultStartTime`, and ALPN negotiated protocol is `timingInfo`'s ALPN negotiated protocol.

2. Return a new connection timing info whose domain lookup start time is the result of coarsen time given `timingInfo`'s domain lookup start time and `crossOriginIsolatedCapability`, domain lookup end time is the result of coarsen time given `timingInfo`'s domain lookup end time and `crossOriginIsolatedCapability`, connection start time is the result of coarsen time given `timingInfo`'s connection start time and `crossOriginIsolatedCapability`, connection end time is the result of coarsen time given `timingInfo`'s connection end time and `crossOriginIsolatedCapability`, secure connection start time is the result of coarsen time given `timingInfo`'s connection end time and `crossOriginIsolatedCapability`, and ALPN negotiated protocol is `timingInfo`'s ALPN negotiated protocol.


A new connection setting is "`no`", "`yes`", or "`yes-and-dedicated`".

To obtain a connection, given a network partition key `key`, URL `url`, boolean `credentials`, an optional new connection setting `new` (default "`no`"), and an optional boolean `requireUnreliable` (default false), run these steps:

1. If `new` is "`no`", then:

   1. Let `connections` be a set of connections in the user agent's connection pool whose key is `key`, origin is `url`'s origin, and credentials is `credentials`.

   2. If `connections` is not empty and `requireUnreliable` is false, then return one of `connections`.

   3. If there is a connection capable of supporting unreliable transport in `connections`, e.g., HTTP/3, then return that connection.

2. Let `proxies` be the result of finding proxies for `url` in an implementation-defined manner. If there are no proxies, let `proxies` be « "`DIRECT`" ».

   This is where non-standard technology such as Web Proxy Auto-Discovery Protocol (WPAD) and proxy auto-config (PAC) come into play. The "`DIRECT`" value means to not use a proxy for this particular `url`.

3. Let `timingInfo` be a new connection timing info.

4. For each `proxy` of `proxies`:

   1. Set `timingInfo`'s domain lookup start time to the unsafe shared current time.

   2. Let `hosts` be « `url`'s origin's host ».

   3. If `proxy` is "`DIRECT`", then set `hosts` to the result of running resolve an origin given `key` and `url`'s origin.

   4. If `hosts` is failure, then continue.

   5. Set `timingInfo`'s domain lookup end time to the unsafe shared current time.

   6. Let `connection` be the result of running this step: run create a connection given `key`, `url`'s origin, `credentials`, `proxy`, an implementation-defined host from `hosts`, `timingInfo`, and `requireUnreliable` an implementation-defined number of times, in parallel from each other, and wait for at least 1 to return a value. In an implementation-defined manner, select a value to return from the returned values and return it. Any other returned values that are connections may be closed.

      Essentially this allows an implementation to pick one or more IP addresses from the return value of resolve an origin (assuming `proxy` is "`DIRECT`") and race them against each other, favor IPv6 addresses, retry in case of a timeout, etc.

   7. If `connection` is failure, then continue.

   8. If `new` is not "`yes-and-dedicated`", then append `connection` to the user agent's connection pool.

   9. Return `connection`.

5. Return failure.

This is intentionally a little vague as there are a lot of nuances to connection management that are best left to the discretion of implementers. Describing this helps explain the `<link rel=preconnect>` feature and clearly stipulates that connections are keyed on credentials. The latter clarifies that, e.g., TLS session identifiers are not reused across connections whose credentials are false with connections whose credentials are true.


To create a connection, given a network partition key `key`, origin `origin`, boolean `credentials`, string `proxy`, host `host`, connection timing info `timingInfo`, and boolean `requireUnreliable`, run these steps:

1. Set `timingInfo`'s connection start time to the unsafe shared current time.

2. Let `connection` be a new connection whose key is `key`, origin is `origin`, credentials is `credentials`, and timing info is `timingInfo`. Record connection timing info given `connection` and use `connection` to establish an HTTP connection to `host`, taking `proxy` and `origin` into account, with the following caveats: [HTTP] [HTTP1] [TLS]

   - If `requireUnreliable` is true, then establish a connection capable of unreliable transport, e.g., an HTTP/3 connection. [HTTP3]

   - When establishing a connection capable of unreliable transport, enable options that are necessary for WebTransport. For HTTP/3, this means including `SETTINGS_ENABLE_WEBTRANSPORT` with a value of `1` and `H3_DATAGRAM` with a value of `1` in the initial `SETTINGS` frame. [WEBTRANSPORT-HTTP3] [HTTP3-DATAGRAM]

   - If `credentials` is false, then do not send a TLS client certificate.

   - If establishing a connection does not succeed (e.g., a UDP, TCP, or TLS error), then return failure.

3. Set `timingInfo`'s ALPN negotiated protocol to `connection`'s ALPN Protocol ID, with the following caveats: [RFC7301]

   - When a proxy is configured, if a tunnel connection is established then this must be the ALPN Protocol ID of the tunneled protocol, otherwise it must be the ALPN Protocol ID of the first hop to the proxy.

   - In case the user agent is using an experimental, non-registered protocol, the user agent must use the used ALPN Protocol ID, if any. If ALPN was not used for protocol negotiations, the user agent may use another descriptive string.

     `timingInfo`'s ALPN negotiated protocol is intended to identify the network protocol in use regardless of how it was actually negotiated; that is, even if ALPN is not used to negotiate the network protocol, this is the ALPN Protocol IDs that indicates the protocol in use.

   IANA maintains a list of ALPN Protocol IDs.

4. Return `connection`.


To record connection timing info given a connection `connection`, let `timingInfo` be `connection`'s timing info and observe these requirements:

- `timingInfo`'s connection end time should be the unsafe shared current time immediately after establishing the connection to the server or proxy, as follows:

  - The returned time must include the time interval to establish the transport connection, as well as other time intervals such as SOCKS authentication. It must include the time interval to complete enough of the TLS handshake to request the resource.

  - If the user agent used TLS False Start for this connection, this interval must not include the time needed to receive the server's Finished message. [RFC7918]

  - If the user agent sends the request with early data without waiting for the full handshake to complete, this interval must not include the time needed to receive the server's ServerHello message. [RFC8470]

  - If the user agent waits for full handshake completion to send the request, this interval includes the full TLS handshake even if other requests were sent using early data on `connection`.

  Suppose the user agent establishes an HTTP/2 connection over TLS 1.3 to send a `GET` request and a `POST` request. It sends the ClientHello at time `t1` and then sends the `GET` request with early data. The `POST` request is not safe ([HTTP], section 9.2.1), so the user agent waits to complete the handshake at time `t2` before sending it. Although both requests used the same connection, the `GET` request reports a connection end time of `t1`, while the `POST` request reports `t2`.

- If a secure transport is used, `timingInfo`'s secure connection start time should be the result of calling unsafe shared current time immediately before starting the handshake process to secure `connection`. [TLS]

- If `connection` is an HTTP/3 connection, `timingInfo`'s connection start time and `timingInfo`'s secure connection start time must be equal. (In HTTP/3 the secure transport handshake process is performed as part of the initial connection setup.) [HTTP3]

The clamp and coarsen connection timing info algorithm ensures that details of reused connections are not exposed and time values are coarsened.


### Network partition keys

A network partition key is a tuple consisting of a site and null or an implementation-defined value.

To determine the network partition key, given an environment `environment`:

1. Let `topLevelOrigin` be `environment`'s top-level origin.

2. If `topLevelOrigin` is null, then set `topLevelOrigin` to `environment`'s top-level creation URL's origin.

3. Assert: `topLevelOrigin` is an origin.

4. Let `topLevelSite` be the result of obtaining a site, given `topLevelOrigin`.

5. Let `secondKey` be null or an implementation-defined value.

   The second key is intentionally a little vague as the finer points are still evolving. See issue #1035.

6. Return (`topLevelSite`, `secondKey`).

To determine the network partition key, given a request `request`:

1. If `request`'s reserved client is non-null, then return the result of determining the network partition key given `request`'s reserved client.

2. If `request`'s client is non-null, then return the result of determining the network partition key given `request`'s client.

3. Return null.


### HTTP cache partitions

To determine the HTTP cache partition, given a request `request`:

1. Let `key` be the result of determining the network partition key given `request`.

2. If `key` is null, then return null.

3. Return the unique HTTP cache associated with `key`. [HTTP-CACHING]


### Port blocking

New protocols can avoid the need for blocking ports by negotiating the protocol through TLS using ALPN. The protocol cannot be spoofed through HTTP requests in that case. [RFC7301]

To determine whether fetching a request `request` should be blocked due to a bad port:

1. Let `url` be `request`'s current URL.

2. If `url`'s scheme is an HTTP(S) scheme and `url`'s port is a bad port, then return **blocked**.

3. Return **allowed**.

A port is a bad port if it is listed in the first column of the following table.

Port | Typical service
---|---
0 | ---​
1 | tcpmux
7 | echo
9 | discard
11 | systat
13 | daytime
15 | netstat
17 | qotd
19 | chargen
20 | ftp-data
21 | ftp
22 | ssh
23 | telnet
25 | smtp
37 | time
42 | name
43 | nicname
53 | domain
69 | tftp
77 | ---​
79 | finger
87 | ---​
95 | supdup
101 | hostname
102 | iso-tsap
103 | gppitnp
104 | acr-nema
109 | pop2
110 | pop3
111 | sunrpc
113 | auth
115 | sftp
117 | uucp-path
119 | nntp
123 | ntp
135 | epmap
137 | netbios-ns
139 | netbios-ssn
143 | imap
161 | snmp
179 | bgp
389 | ldap
427 | svrloc
465 | submissions
512 | exec
513 | login
514 | shell
515 | printer
526 | tempo
530 | courier
531 | chat
532 | netnews
540 | uucp
548 | afp
554 | rtsp
556 | remotefs
563 | nntps
587 | submission
601 | syslog-conn
636 | ldaps
989 | ftps-data
990 | ftps
993 | imaps
995 | pop3s
1719 | h323gatestat
1720 | h323hostcall
1723 | pptp
2049 | nfs
3659 | apple-sasl
4045 | npp
4190 | sieve
5060 | sip
5061 | sips
6000 | x11
6566 | sane-port
6665 | ircu
6666 | ircu
6667 | ircu
6668 | ircu
6669 | ircu
6679 | osaut
6697 | ircs-u
10080 | amanda


### Should `response` to `request` be blocked due to its MIME type?

Run these steps:

1. Let `mimeType` be the result of extracting a MIME type from `response`'s header list.

2. If `mimeType` is failure, then return **allowed**.

3. Let `destination` be `request`'s destination.

4. If `destination` is script-like and one of the following is true, then return **blocked**:

   - `mimeType`'s essence starts with "`audio/`", "`image/`", or "`video/`".
   - `mimeType`'s essence is "`text/csv`".

5. Return **allowed**.


## HTTP extensions


### Cookies

The \``Cookie`\` request header and \``Set-Cookie`\` response headers are largely defined in their own specifications. We define additional infrastructure to be able to use them conveniently here. [\[COOKIES\]](#biblio-cookies)


#### \``Cookie`\` header

To **append a request \``Cookie`\` header**, given a request `request`:

1. If the user agent is configured to disable cookies for `request`, then it should return.

2. Let `sameSite` be the result of determining the same-site mode for `request`.

3. Let `isSecure` be true if `request`'s current URL's scheme is \"`https`\"; otherwise false.

4. Let `httpOnlyAllowed` be true.

   True follows from this being invoked from fetch, as opposed to the `document.cookie` getter steps for instance.

5. Let `cookies` be the result of running retrieve cookies given `isSecure`, `request`'s current URL's host, `request`'s current URL's path, `httpOnlyAllowed`, and `sameSite`.

   The cookie store returns an ordered list of cookies

6. If `cookies` is empty, then return.

7. Let `value` be the result of running serialize cookies given `cookies`.

8. Append (\``Cookie`\`, `value`) to `request`'s header list.


#### \``Set-Cookie`\` header

To **parse and store response \``Set-Cookie`\` headers**, given a request `request` and a response `response`:

1. If the user agent is configured to disable cookies for `request`, then it should return.

2. Let `allowNonHostOnlyCookieForPublicSuffix` be false.

3. Let `isSecure` be true if `request`'s current URL's scheme is \"`https`\"; otherwise false.

4. Let `httpOnlyAllowed` be true.

   True follows from this being invoked from fetch, as opposed to the `document.cookie` getter steps for instance.

5. Let `sameSiteStrictOrLaxAllowed` be true if the result of determine the same-site mode for `request` is \"`strict-or-less`\"; otherwise false.

6. For each `header` of `response`'s header list:

   1. If `header`'s name is not a byte-case-insensitive match for \``Set-Cookie`\`, then continue.

   2. Parse and store a cookie given `header`'s value, `isSecure`, `request`'s current URL's host, `request`'s current URL's path, `httpOnlyAllowed`, `allowNonHostOnlyCookieForPublicSuffix`, and `sameSiteStrictOrLaxAllowed`.

   3. Garbage collect cookies given `request`'s current URL's host.

   As noted elsewhere the \``Set-Cookie`\` header cannot be combined and therefore each occurrence is processed independently. This is not allowed for any other header.


#### Cookie infrastructure

To **determine the same-site mode** for a given request `request`:

1. Assert: `request`'s method is \"`GET`\" or \"`POST`\".

2. If `request`'s top-level navigation initiator origin is not null and is not same site with `request`'s URL's origin, then return \"`unset-or-less`\".

3. If `request`'s method is \"`GET`\" and `request`'s destination is \"document\", then return \"`lax-or-less`\".

4. If `request`'s client's has cross-site ancestor is true, then return \"`unset-or-less`\".

5. If `request`'s redirect-taint is \"`cross-site`\", then return \"`unset-or-less`\".

6. Return \"`strict-or-less`\".

To obtain a **serialized cookie default path** given a URL `url`:

1. Let `cloneURL` be a clone of `url`.

2. Set `cloneURL`'s path to the cookie default path of `cloneURL`'s path.

3. Return the URL path serialization of `cloneURL`.


### \``Origin`\` header

The \`**`Origin`**\` request header indicates where a fetch originates from.

The \``Origin`\` header is a version of the \``Referer`\` \[sic\] header that does not reveal a path. It is used for all HTTP fetches whose request's response tainting is \"`cors`\", as well as those where request's method is neither \``GET`\` nor \``HEAD`\`. Due to compatibility constraints it is not included in all fetches.

Its possible values are all the return values of byte-serializing a request origin, given a request.

This supplants the definition in The Web Origin Concept. [\[ORIGIN\]](#biblio-origin)

To **append a request \``Origin`\` header**, given a request `request`, run these steps:

1. Assert: `request`'s origin is not \"`client`\".

2. Let `serializedOrigin` be the result of byte-serializing a request origin with `request`.

3. If `request`'s response tainting is \"`cors`\" or `request`'s mode is \"`websocket`\", then append (\``Origin`\`, `serializedOrigin`) to `request`'s header list.

4. Otherwise, if `request`'s method is neither \``GET`\` nor \``HEAD`\`, then:

   1. If `request`'s mode is not \"`cors`\", then switch on `request`'s referrer policy:

      \"`no-referrer`\"
      : Set `serializedOrigin` to \``null`\`.

      \"`no-referrer-when-downgrade`\"\
      \"`strict-origin`\"\
      \"`strict-origin-when-cross-origin`\"
      : If `request`'s origin is a tuple origin, its `scheme` is \"`https`\", and `request`'s current URL's `scheme` is not \"`https`\", then set `serializedOrigin` to \``null`\`.

      \"`same-origin`\"
      : If `request`'s origin is not same origin with `request`'s current URL's origin, then set `serializedOrigin` to \``null`\`.

      Otherwise
      : Do nothing.

   2. Append (\``Origin`\`, `serializedOrigin`) to `request`'s header list.

A request's referrer policy is taken into account for all fetches where the fetcher did not explicitly opt into sharing their origin with the server, e.g., via using the CORS protocol.


### CORS protocol

To allow sharing responses cross-origin and allow for more versatile fetches than possible with HTML's `form` element, the **CORS protocol** exists. It is layered on top of HTTP and allows responses to declare they can be shared with other origins.

It needs to be an opt-in mechanism to prevent leaking data from responses behind a firewall (intranets). Additionally, for requests including credentials it needs to be opt-in to prevent leaking potentially-sensitive data.

This section explains the CORS protocol as it pertains to server developers. Requirements for user agents are part of the fetch algorithm, except for the new HTTP header syntax.


#### General

The CORS protocol consists of a set of headers that indicates whether a response can be shared cross-origin.

For requests that are more involved than what is possible with HTML's `form` element, a CORS-preflight request is performed, to ensure request's current URL supports the CORS protocol.


#### HTTP requests

A **CORS request** is an HTTP request that includes an \``Origin`\` header. It cannot be reliably identified as participating in the CORS protocol as the \``Origin`\` header is also included for all requests whose method is neither \``GET`\` nor \``HEAD`\`.

A **CORS-preflight request** is a CORS request that checks to see if the CORS protocol is understood. It uses \``OPTIONS`\` as method and includes the following header:

\`**`Access-Control-Request-Method`**\`
: Indicates which method a future CORS request to the same resource might use.

A CORS-preflight request can also include the following header:

\`**`Access-Control-Request-Headers`**\`
: Indicates which headers a future CORS request to the same resource might use.


#### HTTP responses

An HTTP response to a CORS request can include the following headers:

\`**`Access-Control-Allow-Origin`**\`
: Indicates whether the response can be shared, via returning the literal value of the \``Origin`\` request header (which can be \``null`\`) or \``*`\` in a response.

\`**`Access-Control-Allow-Credentials`**\`
: Indicates whether the response can be shared when request's credentials mode is \"`include`\".

  For a CORS-preflight request, request's credentials mode is always \"`same-origin`\", i.e., it excludes credentials, but for any subsequent CORS requests it might not be. Support therefore needs to be indicated as part of the HTTP response to the CORS-preflight request as well.

An HTTP response to a CORS-preflight request can include the following headers:

\`**`Access-Control-Allow-Methods`**\`
: Indicates which methods are supported by the response's URL for the purposes of the CORS protocol.

  The \``Allow`\` header is not relevant for the purposes of the CORS protocol.

\`**`Access-Control-Allow-Headers`**\`
: Indicates which headers are supported by the response's URL for the purposes of the CORS protocol.

\`**`Access-Control-Max-Age`**\`
: Indicates the number of seconds (5 by default) the information provided by the \``Access-Control-Allow-Methods`\` and \``Access-Control-Allow-Headers`\` headers can be cached.

An HTTP response to a CORS request that is not a CORS-preflight request can also include the following header:

\`**`Access-Control-Expose-Headers`**\`
: Indicates which headers can be exposed as part of the response by listing their names.

A successful HTTP response, i.e., one where the server developer intends to share it, to a CORS request can use any status, as long as it includes the headers stated above with values matching up with the request.

A successful HTTP response to a CORS-preflight request is similar, except it is restricted to an ok status, e.g., 200 or 204.

Any other kind of HTTP response is not successful and will either end up not being shared or fail the CORS-preflight request. Be aware that any work the server performs might nonetheless leak through side channels, such as timing. If server developers wish to denote this explicitly, the 403 status can be used, coupled with omitting the relevant headers.

If desired, "failure" could also be shared, but that would make it a successful HTTP response. That is why for a successful HTTP response to a CORS request that is not a CORS-preflight request the status can be anything, including 403.

Ultimately server developers have a lot of freedom in how they handle HTTP responses and these tactics can differ between the response to the CORS-preflight request and the CORS request that follows it:

- They can provide a static response. This can be helpful when working with caching intermediaries. A static response can both be successful and not successful depending on the CORS request. This is okay.

- They can provide a dynamic response, tuned to CORS request. This can be helpful when the response body is to be tailored to a specific origin or a response needs to have credentials and be successful for a set of origins.


#### HTTP new-header syntax

ABNF for the values of the headers used by the CORS protocol:

```abnf
Access-Control-Request-Method    = method
Access-Control-Request-Headers   = 1#field-name

wildcard                         = "*"
Access-Control-Allow-Origin      = origin-or-null / wildcard
Access-Control-Allow-Credentials = %s"true" ; case-sensitive
Access-Control-Expose-Headers    = #field-name
Access-Control-Max-Age           = delta-seconds
Access-Control-Allow-Methods     = #method
Access-Control-Allow-Headers     = #field-name
```

For \``Access-Control-Expose-Headers`\`, \``Access-Control-Allow-Methods`\`, and \``Access-Control-Allow-Headers`\` response headers, the value \``*`\` counts as a wildcard for requests without credentials. For such requests there is no way to solely match a header name or method that is \``*`\`.


#### CORS protocol and credentials

When request's credentials mode is \"`include`\" it has an impact on the functioning of the CORS protocol other than including credentials in the fetch.

In the old days, `XMLHttpRequest` could be used to set request's credentials mode to \"`include`\":

```javascript
var client = new XMLHttpRequest()
client.open("GET", "./")
client.withCredentials = true
/* … */
```

Nowadays, `fetch("./", { credentials:"include" }).then(/* … */)` suffices.

A request's credentials mode is not necessarily observable on the server; only when credentials exist for a request can it be observed by virtue of the credentials being included. Note that even so, a CORS-preflight request never includes credentials.

The server developer therefore needs to decide whether or not responses "tainted" with credentials can be shared. And also needs to decide if requests necessitating a CORS-preflight request can include credentials. Generally speaking, both sharing responses and allowing requests with credentials is rather unsafe, and extreme care has to be taken to avoid the confused deputy problem.

To share responses with credentials, the \``Access-Control-Allow-Origin`\` and \``Access-Control-Allow-Credentials`\` headers are important. The following table serves to illustrate the various legal and illegal combinations for a request to `https://rabbit.invalid/`:

| Request's credentials mode | \``Access-Control-Allow-Origin`\` | \``Access-Control-Allow-Credentials`\` | Shared? | Notes |
|---|---|---|---|---|
| \"`omit`\" | \``*`\` | Omitted | ✅ | ---​ |
| \"`omit`\" | \``*`\` | \``true`\` | ✅ | If credentials mode is not \"`include`\", then \``Access-Control-Allow-Credentials`\` is ignored. |
| \"`omit`\" | \``https://rabbit.invalid/`\` | Omitted | ❌ | A serialized origin has no trailing slash. |
| \"`omit`\" | \``https://rabbit.invalid`\` | Omitted | ✅ | ---​ |
| \"`include`\" | \``*`\` | \``true`\` | ❌ | If credentials mode is \"`include`\", then \``Access-Control-Allow-Origin`\` cannot be \``*`\`. |
| \"`include`\" | \``https://rabbit.invalid`\` | \``true`\` | ✅ | ---​ |
| \"`include`\" | \``https://rabbit.invalid`\` | \``True`\` | ❌ | \``true`\` is (byte) case-sensitive. |

Similarly, \``Access-Control-Expose-Headers`\`, \``Access-Control-Allow-Methods`\`, and \``Access-Control-Allow-Headers`\` response headers can only use \``*`\` as value when request's credentials mode is not \"`include`\".


#### Examples

A script at `https://foo.invalid/` wants to fetch some data from `https://bar.invalid/`. (Neither credentials nor response header access is important.)

```javascript
var url = "https://bar.invalid/api?key=730d67a37d7f3d802e96396d00280768773813fbe726d116944d814422fc1a45&data=about:unicorn";
fetch(url).then(success, failure)
```

This will use the CORS protocol, though this is entirely transparent to the developer from `foo.invalid`. As part of the CORS protocol, the user agent will include the \``Origin`\` header in the request:

```http
Origin: https://foo.invalid
```

Upon receiving a response from `bar.invalid`, the user agent will verify the \``Access-Control-Allow-Origin`\` response header. If its value is either \``https://foo.invalid`\` or \``*`\`, the user agent will invoke the `success` callback. If it has any other value, or is missing, the user agent will invoke the `failure` callback.

The developer of `foo.invalid` is back, and now wants to fetch some data from `bar.invalid` while also accessing a response header.

```javascript
fetch(url).then(response => {
  var hsts = response.headers.get("strict-transport-security"),
      csp = response.headers.get("content-security-policy")
  log(hsts, csp)
})
```

`bar.invalid` provides a correct \``Access-Control-Allow-Origin`\` response header per the earlier example. The values of `hsts` and `csp` will depend on the \``Access-Control-Expose-Headers`\` response header. For example, if the response included the following headers

```http
Content-Security-Policy: default-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubdomains; preload
Access-Control-Expose-Headers: Content-Security-Policy
```

then `hsts` would be null and `csp` would be \"`default-src 'self'`\", even though the response did include both headers. This is because `bar.invalid` needs to explicitly share each header by listing their names in the \``Access-Control-Expose-Headers`\` response header.

Alternatively, if `bar.invalid` wanted to share all its response headers, for requests that do not include credentials, it could use \``*`\` as value for the \``Access-Control-Expose-Headers`\` response header. If the request would have included credentials, the response header names would have to be listed explicitly and \``*`\` could not be used.

The developer of `foo.invalid` returns, now fetching some data from `bar.invalid` while including credentials. This time around the CORS protocol is no longer transparent to the developer as credentials require an explicit opt-in:

```javascript
fetch(url, { credentials:"include" }).then(success, failure)
```

This also makes any \``Set-Cookie`\` response headers `bar.invalid` includes fully functional (they are ignored otherwise).

The user agent will make sure to include any relevant credentials in the request. It will also put stricter requirements on the response. Not only will `bar.invalid` need to list \``https://foo.invalid`\` as value for the \``Access-Control-Allow-Origin`\` header (\``*`\` is not allowed when credentials are involved), the \``Access-Control-Allow-Credentials`\` header has to be present too:

```http
Access-Control-Allow-Origin: https://foo.invalid
Access-Control-Allow-Credentials: true
```

If the response does not include those two headers with those values, the `failure` callback will be invoked. However, any \``Set-Cookie`\` response headers will be respected.


#### CORS protocol exceptions

Specifications have allowed limited exceptions to the CORS safelist for non-safelisted \``Content-Type`\` header values. These exceptions are made for requests that can be triggered by web content but whose headers and bodies can be only minimally controlled by the web content. Therefore, servers should expect cross-origin web content to be allowed to trigger non-preflighted requests with the following non-safelisted \``Content-Type`\` header values:

- \``application/csp-report`\` [\[CSP\]](#biblio-csp)
- \``application/expect-ct-report+json`\` [\[RFC9163\]](#biblio-rfc9163)
- \``application/xss-auditor-report`\`
- \``application/ocsp-request`\` [\[RFC6960\]](#biblio-rfc6960)

Specifications should avoid introducing new exceptions and should only do so with careful consideration for the security consequences. New exceptions can be proposed by filing an issue.


### \``Content-Length`\` header

The \``Content-Length`\` header is largely defined in HTTP. Its processing model is defined here as the model defined in HTTP is not compatible with web content. [\[HTTP\]](#biblio-http)

To **extract a length** from a header list `headers`, run these steps:

1. Let `values` be the result of getting, decoding, and splitting \``Content-Length`\` from `headers`.

2. If `values` is null, then return null.

3. Let `candidateValue` be null.

4. For each `value` of `values`:

   1. If `candidateValue` is null, then set `candidateValue` to `value`.

   2. Otherwise, if `value` is not `candidateValue`, return failure.

5. If `candidateValue` is the empty string or has a code point that is not an ASCII digit, then return null.

6. Return `candidateValue`, interpreted as decimal number.


### \``Content-Type`\` header

The \``Content-Type`\` header is largely defined in HTTP. Its processing model is defined here as the model defined in HTTP is not compatible with web content. [\[HTTP\]](#biblio-http)

To **extract a MIME type** from a header list `headers`, run these steps. They return failure or a MIME type.

1. Let `charset` be null.

2. Let `essence` be null.

3. Let `mimeType` be null.

4. Let `values` be the result of getting, decoding, and splitting \``Content-Type`\` from `headers`.

5. If `values` is null, then return failure.

6. For each `value` of `values`:

   1. Let `temporaryMimeType` be the result of parsing `value`.

   2. If `temporaryMimeType` is failure or its essence is \"`*/*`\", then continue.

   3. Set `mimeType` to `temporaryMimeType`.

   4. If `mimeType`'s essence is not `essence`, then:

      1. Set `charset` to null.

      2. If `mimeType`'s parameters\[\"`charset`\"\] exists, then set `charset` to `mimeType`'s parameters\[\"`charset`\"\].

      3. Set `essence` to `mimeType`'s essence.

   5. Otherwise, if `mimeType`'s parameters\[\"`charset`\"\] does not exist, and `charset` is non-null, set `mimeType`'s parameters\[\"`charset`\"\] to `charset`.

7. If `mimeType` is null, then return failure.

8. Return `mimeType`.

When extract a MIME type returns failure or a MIME type whose essence is incorrect for a given format, treat this as a fatal error. Existing web platform features have not always followed this pattern, which has been a major source of security vulnerabilities in those features over the years. In contrast, a MIME type's parameters can typically be safely ignored.

This is how extract a MIME type functions in practice:

| Headers (as on the network) | Output (serialized) |
|---|---|
| `Content-Type: text/plain;charset=gbk, text/html` | `text/html` |
| `Content-Type: text/html;charset=gbk;a=b, text/html;x=y` | `text/html;x=y;charset=gbk` |
| `Content-Type: text/html;charset=gbk;a=b`<br>`Content-Type: text/html;x=y` | `text/html;x=y;charset=gbk` |
| `Content-Type: text/html;charset=gbk`<br>`Content-Type: x/x`<br>`Content-Type: text/html;x=y` | `text/html;x=y` |
| `Content-Type: text/html`<br>`Content-Type: cannot-parse` | `text/html` |
| `Content-Type: text/html`<br>`Content-Type: */*` | `text/html` |
| `Content-Type: text/html`<br>`Content-Type:` | `text/html` |

To **legacy extract an encoding** given failure or a MIME type `mimeType` and an encoding `fallbackEncoding`, run these steps:

1. If `mimeType` is failure, then return `fallbackEncoding`.

2. If `mimeType`\[\"`charset`\"\] does not exist, then return `fallbackEncoding`.

3. Let `tentativeEncoding` be the result of getting an encoding from `mimeType`\[\"`charset`\"\].

4. If `tentativeEncoding` is failure, then return `fallbackEncoding`.

5. Return `tentativeEncoding`.

This algorithm allows `mimeType` to be failure so it can be more easily combined with extract a MIME type.

It is denoted as legacy as modern formats are to exclusively use UTF-8.


### \``X-Content-Type-Options`\` header

The \`**`X-Content-Type-Options`**\` response header can be used to require checking of a response's \``Content-Type`\` header against the destination of a request.

To **determine nosniff**, given a header list `list`, run these steps:

1. Let `values` be the result of getting, decoding, and splitting \``X-Content-Type-Options`\` from `list`.

2. If `values` is null, then return false.

3. If `values`\[0\] is an ASCII case-insensitive match for \"`nosniff`\", then return true.

4. Return false.

Web developers and conformance checkers must use the following value ABNF for \``X-Content-Type-Options`\`:

```abnf
X-Content-Type-Options           = "nosniff" ; case-insensitive
```


#### Should `response` to `request` be blocked due to nosniff?

Run these steps:

1. If determine nosniff with `response`'s header list is false, then return **allowed**.

2. Let `mimeType` be the result of extracting a MIME type from `response`'s header list.

3. Let `destination` be `request`'s destination.

4. If `destination` is script-like and `mimeType` is failure or is not a JavaScript MIME type, then return **blocked**.

5. If `destination` is \"`style`\" and `mimeType` is failure or its essence is not \"`text/css`\", then return **blocked**.

6. Return **allowed**.

Only request destinations that are script-like or \"`style`\" are considered as any exploits pertain to them. Also, considering \"`image`\" was not compatible with deployed content.


### \``Cross-Origin-Resource-Policy`\` header

The \`**`Cross-Origin-Resource-Policy`**\` response header can be used to require checking a request's current URL's origin against a request's origin when request's mode is \"`no-cors`\".

Its value ABNF:

```abnf
Cross-Origin-Resource-Policy     = %s"same-origin" / %s"same-site" / %s"cross-origin" ; case-sensitive
```

To perform a **cross-origin resource policy check**, given an origin `origin`, an environment settings object `settingsObject`, a string `destination`, a response `response`, and an optional boolean `forNavigation`, run these steps:

1. Set `forNavigation` to false if it is not given.

2. Let `embedderPolicy` be `settingsObject`'s policy container's embedder policy.

3. If the cross-origin resource policy internal check with `origin`, \"`unsafe-none`\", `response`, and `forNavigation` returns **blocked**, then return **blocked**.

   This step is needed because we don't want to report violations not related to Cross-Origin Embedder Policy below.

4. If the cross-origin resource policy internal check with `origin`, `embedderPolicy`'s report only value, `response`, and `forNavigation` returns **blocked**, then queue a cross-origin embedder policy CORP violation report with `response`, `settingsObject`, `destination`, and true.

5. If the cross-origin resource policy internal check with `origin`, `embedderPolicy`'s value, `response`, and `forNavigation` returns **allowed**, then return **allowed**.

6. Queue a cross-origin embedder policy CORP violation report with `response`, `settingsObject`, `destination`, and false.

7. Return **blocked**.

Only HTML's navigate algorithm uses this check with `forNavigation` set to true, and it's always for nested navigations. Otherwise, `response` is either the internal response of an opaque filtered response or a response which will be the internal response of an opaque filtered response. [\[HTML\]](#biblio-html)

To perform a **cross-origin resource policy internal check**, given an origin `origin`, an embedder policy value `embedderPolicyValue`, a response `response`, and a boolean `forNavigation`, run these steps:

1. If `forNavigation` is true and `embedderPolicyValue` is \"`unsafe-none`\", then return **allowed**.

2. Let `policy` be the result of getting \``Cross-Origin-Resource-Policy`\` from `response`'s header list.

   This means that \``Cross-Origin-Resource-Policy: same-site, same-origin`\` ends up as **allowed** below as it will never match anything, as long as `embedderPolicyValue` is \"`unsafe-none`\". Two or more \``Cross-Origin-Resource-Policy`\` headers will have the same effect.

3. If `policy` is neither \``same-origin`\`, \``same-site`\`, nor \``cross-origin`\`, then set `policy` to null.

4. If `policy` is null, then switch on `embedderPolicyValue`:

   \"`unsafe-none`\"
   : Do nothing.

   \"`credentialless`\"
   : Set `policy` to \``same-origin`\` if:
     - `response`'s request-includes-credentials is true, or
     - `forNavigation` is true.

   \"`require-corp`\"
   : Set `policy` to \``same-origin`\`.

5. Switch on `policy`:

   null\
   \``cross-origin`\`
   : Return **allowed**.

   \``same-origin`\`
   : If `origin` is same origin with `response`'s URL's origin, then return **allowed**.

     Otherwise, return **blocked**.

   \``same-site`\`
   : If all of the following are true
     - `origin` is schemelessly same site with `response`'s URL's origin
     - `origin`'s scheme is \"`https`\" or `response`'s URL's scheme is not \"`https`\"

     then return **allowed**.

     Otherwise, return **blocked**.

     \``Cross-Origin-Resource-Policy: same-site`\` does not consider a response delivered via a secure transport to match a non-secure requesting origin, even if their hosts are otherwise same site. Securely-transported responses will only match a securely-transported initiator.

To **queue a cross-origin embedder policy CORP violation report**, given a response `response`, an environment settings object `settingsObject`, a string `destination`, and a boolean `reportOnly`, run these steps:

1. Let `endpoint` be `settingsObject`'s policy container's embedder policy's report only reporting endpoint if `reportOnly` is true and `settingsObject`'s policy container's embedder policy's reporting endpoint otherwise.

2. Let `serializedURL` be the result of serializing a response URL for reporting with `response`.

3. Let `disposition` be \"`reporting`\" if `reportOnly` is true; otherwise \"`enforce`\".

4. Let `body` be a new object containing the following properties:

   | key | value |
   |---|---|
   | \"`type`\" | \"`corp`\" |
   | \"`blockedURL`\" | `serializedURL` |
   | \"`destination`\" | `destination` |
   | \"`disposition`\" | `disposition` |

5. Generate and queue a report for `settingsObject`'s global object given the \"`coep`\" report type, `endpoint`, and `body`. [\[REPORTING\]](#biblio-reporting)


### \``Sec-Purpose`\` header

The \`**`Sec-Purpose`**\` HTTP request header specifies that the request serves one or more purposes other than requesting the resource for immediate use by the user.

The \``Sec-Purpose`\` header field is a structured header whose value must be a token.

The sole token defined is `prefetch`. It indicates the request's purpose is to fetch a resource that is anticipated to be needed shortly.

The server can use this to adjust the caching expiry for prefetches, to disallow the prefetch, or to treat it differently when counting page visits.


## Fetching

The algorithm below defines fetching. In broad strokes, it takes a request and one or more algorithms to run at various points during the operation. A response is passed to the last two algorithms listed below. The first two algorithms can be used to capture uploads.

To **fetch**, given a request `request`, an optional algorithm `processRequestBodyChunkLength`, an optional algorithm `processRequestEndOfBody`, an optional algorithm `processEarlyHintsResponse`, an optional algorithm `processResponse`, an optional algorithm `processResponseEndOfBody`, an optional algorithm `processResponseConsumeBody`, and an optional boolean `useParallelQueue` (default false), run the steps below. If given, `processRequestBodyChunkLength` must be an algorithm accepting an integer representing the number of bytes transmitted. If given, `processRequestEndOfBody` must be an algorithm accepting no arguments. If given, `processEarlyHintsResponse` must be an algorithm accepting a response. If given, `processResponse` must be an algorithm accepting a response. If given, `processResponseEndOfBody` must be an algorithm accepting a response. If given, `processResponseConsumeBody` must be an algorithm accepting a response and null, failure, or a byte sequence.

The user agent may be asked to **suspend** the ongoing fetch. The user agent may either accept or ignore the suspension request. The suspended fetch can be **resumed**. The user agent should ignore the suspension request if the ongoing fetch is updating the response in the HTTP cache for the request.

The user agent does not update the entry in the HTTP cache for a request if request's cache mode is "no-store" or a `Cache-Control: no-store` header appears in the response. [HTTP-CACHING]

1. Assert: `request`'s mode is "navigate" or `processEarlyHintsResponse` is null.

   Processing of early hints (responses whose status is 103) is only vetted for navigations.

2. Let `taskDestination` be null.

3. Let `crossOriginIsolatedCapability` be false.

4. Populate request from client given `request`.

5. If `request`'s client is non-null, then:

   1. Set `taskDestination` to `request`'s client's global object.

   2. Set `crossOriginIsolatedCapability` to `request`'s client's cross-origin isolated capability.

6. If `useParallelQueue` is true, then set `taskDestination` to the result of starting a new parallel queue.

7. Let `timingInfo` be a new fetch timing info whose start time and post-redirect start time are the coarsened shared current time given `crossOriginIsolatedCapability`, and render-blocking is set to `request`'s render-blocking.

8. Let `fetchParams` be a new fetch params whose request is `request`, timing info is `timingInfo`, process request body chunk length is `processRequestBodyChunkLength`, process request end-of-body is `processRequestEndOfBody`, process early hints response is `processEarlyHintsResponse`, process response is `processResponse`, process response consume body is `processResponseConsumeBody`, process response end-of-body is `processResponseEndOfBody`, task destination is `taskDestination`, and cross-origin isolated capability is `crossOriginIsolatedCapability`.

9. If `request`'s body is a byte sequence, then set `request`'s body to `request`'s body as a body.

10. If all of the following conditions are true:

    - `request`'s URL's scheme is an HTTP(S) scheme

    - `request`'s mode is "same-origin", "cors", or "no-cors"

    - `request`'s client is not null, and `request`'s client's global object is a `Window` object

    - `request`'s method is `GET`

    - `request`'s unsafe-request flag is not set or `request`'s header list is empty

    then:

    1. Assert: `request`'s origin is same origin with `request`'s client's origin.

    2. Let `onPreloadedResponseAvailable` be an algorithm that runs the following step given a response `response`: set `fetchParams`'s preloaded response candidate to `response`.

    3. Let `foundPreloadedResource` be the result of invoking consume a preloaded resource for `request`'s client, given `request`'s URL, `request`'s destination, `request`'s mode, `request`'s credentials mode, `request`'s integrity metadata, and `onPreloadedResponseAvailable`.

    4. If `foundPreloadedResource` is true and `fetchParams`'s preloaded response candidate is null, then set `fetchParams`'s preloaded response candidate to "pending".

11. If `request`'s header list does not contain `Accept`, then:

    1. Let `value` be `*/*`.

    2. If `request`'s initiator is "prefetch", then set `value` to the document `Accept` header value.

    3. Otherwise, the user agent should set `value` to the first matching statement, if any, switching on `request`'s destination:

       "document"  
       "frame"  
       "iframe"
       : the document `Accept` header value

       "image"
       : `image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5`

       "json"
       : `application/json,*/*;q=0.5`

       "style"
       : `text/css,*/*;q=0.1`

    4. Append (`Accept`, `value`) to `request`'s header list.

12. If `request`'s header list does not contain `Accept-Language`, then user agents should append (`Accept-Language`, an appropriate header value) to `request`'s header list.

13. If `request`'s internal priority is null, then use `request`'s priority, initiator, destination, and render-blocking in an implementation-defined manner to set `request`'s internal priority to an implementation-defined object.

    The implementation-defined object could encompass stream weight and dependency for HTTP/2, priorities used in Extensible Prioritization Scheme for HTTP for transports where it applies (including HTTP/3), and equivalent information used to prioritize dispatch and processing of HTTP/1 fetches. [RFC9218]

14. If `request` is a subresource request:

    1. Let `record` be a new fetch record whose request is `request` and controller is `fetchParams`'s controller.

    2. Append `record` to `request`'s client's fetch group's fetch records.

15. Run main fetch given `fetchParams`.

16. Return `fetchParams`'s controller.

To **populate request from client** given a request `request`:

1. If `request`'s traversable for user prompts is "client":

   1. Set `request`'s traversable for user prompts to "no-traversable".

   2. If `request`'s client is non-null:

      1. Let `global` be `request`'s client's global object.

      2. If `global` is a `Window` object and `global`'s navigable is not null, then set `request`'s traversable for user prompts to `global`'s navigable's traversable navigable.

2. If `request`'s origin is "client":

   1. Assert: `request`'s client is non-null.

   2. Set `request`'s origin to `request`'s client's origin.

3. If `request`'s policy container is "client":

   1. If `request`'s client is non-null, then set `request`'s policy container to a clone of `request`'s client's policy container. [HTML]

   2. Otherwise, set `request`'s policy container to a new policy container.


### Main fetch

To **main fetch**, given a fetch params `fetchParams` and an optional boolean `recursive` (default false), run these steps:

1. Let `request` be `fetchParams`' request.

2. Let `response` be null.

3. If `request`'s local-URLs-only flag is set and `request`'s current URL is not local, then set `response` to a network error.

4. Run report Content Security Policy violations for `request`.

5. Upgrade `request` to a potentially trustworthy URL, if appropriate.

6. Upgrade a mixed content `request` to a potentially trustworthy URL, if appropriate.

7. If should `request` be blocked due to a bad port, should fetching `request` be blocked as mixed content, should `request` be blocked by Content Security Policy, or should `request` be blocked by Integrity Policy Policy returns **blocked**, then set `response` to a network error.

8. If `request`'s referrer policy is the empty string, then set `request`'s referrer policy to `request`'s policy container's referrer policy.

9. If `request`'s referrer is not "no-referrer", then set `request`'s referrer to the result of invoking determine `request`'s referrer. [REFERRER]

   As stated in Referrer Policy, user agents can provide the end user with options to override `request`'s referrer to "no-referrer" or have it expose less sensitive information.

10. Set `request`'s current URL's scheme to "https" if all of the following conditions are true:

    - `request`'s current URL's scheme is "http"
    - `request`'s current URL's host is a domain
    - `request`'s current URL's host's public suffix is not "localhost" or "localhost."
    - Matching `request`'s current URL's host per Known HSTS Host Domain Name Matching results in either a superdomain match with an asserted `includeSubDomains` directive or a congruent match (with or without an asserted `includeSubDomains` directive) [HSTS]; or DNS resolution for the request finds a matching HTTPS RR per section 9.5 of [SVCB]. [HSTS] [SVCB]

    As all DNS operations are generally implementation-defined, how it is determined that DNS resolution contains an HTTPS RR is also implementation-defined. As DNS operations are not traditionally performed until attempting to obtain a connection, user agents might need to perform DNS operations earlier, consult local DNS caches, or wait until later in the fetch algorithm and potentially unwind logic on discovering the need to change `request`'s current URL's scheme.

11. If `recursive` is false, then run the remaining steps in parallel.

12. If `response` is null, then set `response` to the result of running the steps corresponding to the first matching statement:

    `fetchParams`'s preloaded response candidate is non-null

    : 1. Wait until `fetchParams`'s preloaded response candidate is not "pending".

      2. Assert: `fetchParams`'s preloaded response candidate is a response.

      3. Return `fetchParams`'s preloaded response candidate.

    `request`'s current URL's origin is same origin with `request`'s origin, and `request`'s response tainting is "basic"  
    `request`'s current URL's scheme is "data"  
    `request`'s mode is "navigate" or "websocket"

    : 1. Set `request`'s response tainting to "basic".

      2. Return the result of running override fetch given "scheme-fetch" and `fetchParams`.

      HTML assigns any documents and workers created from URLs whose scheme is "data" a unique opaque origin. Service workers can only be created from URLs whose scheme is an HTTP(S) scheme. [HTML] [SW]

    `request`'s mode is "same-origin"

    : Return a network error.

    `request`'s mode is "no-cors"

    : 1. If `request`'s redirect mode is not "follow", then return a network error.

      2. Set `request`'s response tainting to "opaque".

      3. Return the result of running override fetch given "scheme-fetch" and `fetchParams`.

    `request`'s current URL's scheme is not an HTTP(S) scheme

    : Return a network error.

    `request`'s use-CORS-preflight flag is set  
    `request`'s unsafe-request flag is set and either `request`'s method is not a CORS-safelisted method or CORS-unsafe request-header names with `request`'s header list is not empty

    : 1. Set `request`'s response tainting to "cors".

      2. Let `corsWithPreflightResponse` be the result of running override fetch given "http-fetch", `fetchParams`, and true.

      3. If `corsWithPreflightResponse` is a network error, then clear cache entries using `request`.

      4. Return `corsWithPreflightResponse`.

    Otherwise

    : 1. Set `request`'s response tainting to "cors".

      2. Return the result of running override fetch given "http-fetch" and `fetchParams`.

13. If `recursive` is true, then return `response`.

14. If `response` is not a network error and `response` is not a filtered response, then:

    1. If `request`'s response tainting is "cors", then:

       1. Let `headerNames` be the result of extracting header list values given `Access-Control-Expose-Headers` and `response`'s header list.

       2. If `request`'s credentials mode is not "include" and `headerNames` contains `*`, then set `response`'s CORS-exposed header-name list to all unique header names in `response`'s header list.

       3. Otherwise, if `headerNames` is non-null or failure, then set `response`'s CORS-exposed header-name list to `headerNames`.

          One of the `headerNames` can still be `*` at this point, but will only match a header whose name is `*`.

    2. Set `response` to the following filtered response with `response` as its internal response, depending on `request`'s response tainting:

       "basic"
       : basic filtered response

       "cors"
       : CORS filtered response

       "opaque"
       : opaque filtered response

15. Let `internalResponse` be `response`, if `response` is a network error; otherwise `response`'s internal response.

16. If `internalResponse`'s URL list is empty, then set it to a clone of `request`'s URL list.

    A response's URL list can be empty, e.g., when fetching an `about:` URL.

17. Set `internalResponse`'s redirect taint to `request`'s redirect-taint.

18. If `request`'s timing allow failed flag is unset, then set `internalResponse`'s timing allow passed flag.

19. If `response` is not a network error and any of the following returns **blocked**

    - should `internalResponse` to `request` be blocked as mixed content

    - should `internalResponse` to `request` be blocked by Content Security Policy

    - should `internalResponse` to `request` be blocked due to its MIME type

    - should `internalResponse` to `request` be blocked due to nosniff

    then set `response` and `internalResponse` to a network error.

20. If `response`'s type is "opaque", `internalResponse`'s status is 206, `internalResponse`'s range-requested flag is set, and `request`'s header list does not contain `Range`, then set `response` and `internalResponse` to a network error.

    Traditionally, APIs accept a ranged response even if a range was not requested. This prevents a partial response from an earlier ranged request being provided to an API that did not make a range request.

    **Further details**

    The above steps prevent the following attack:

    A media element is used to request a range of a cross-origin HTML resource. Although this is invalid media, a reference to a clone of the response can be retained in a service worker. This can later be used as the response to a script element's fetch. If the partial response is valid JavaScript (even though the whole resource is not), executing it would leak private data.

21. If `response` is not a network error and either `request`'s method is `HEAD` or `CONNECT`, or `internalResponse`'s status is a null body status, set `internalResponse`'s body to null and disregard any enqueuing toward it (if any).

    This standardizes the error handling for servers that violate HTTP.

22. If `request`'s integrity metadata is not the empty string, then:

    1. Let `processBodyError` be this step: run fetch response handover given `fetchParams` and a network error.

    2. If `response`'s body is null, then run `processBodyError` and abort these steps.

    3. Let `processBody` given `bytes` be these steps:

       1. If `bytes` do not match `request`'s integrity metadata, then run `processBodyError` and abort these steps. [SRI]

       2. Set `response`'s body to `bytes` as a body.

       3. Run fetch response handover given `fetchParams` and `response`.

    4. Fully read `response`'s body given `processBody` and `processBodyError`.

23. Otherwise, run fetch response handover given `fetchParams` and `response`.

---

The **fetch response handover**, given a fetch params `fetchParams` and a response `response`, run these steps:

1. Let `timingInfo` be `fetchParams`'s timing info.

2. If `response` is not a network error and `fetchParams`'s request's client is a secure context, then set `timingInfo`'s server-timing headers to the result of getting, decoding, and splitting `Server-Timing` from `response`'s internal response's header list.

   Using _response_'s internal response is safe as exposing `Server-Timing` header data is guarded through the `Timing-Allow-Origin` header.

   The user agent may decide to expose `Server-Timing` headers to non-secure contexts requests as well.

3. If `fetchParams`'s request's destination is "document", then set `fetchParams`'s controller's full timing info to `fetchParams`'s timing info.

4. Let `processResponseEndOfBody` be the following steps:

   1. Let `unsafeEndTime` be the unsafe shared current time.

   2. Set `fetchParams`'s controller's report timing steps to the following steps given a global object `global`:

      1. If `fetchParams`'s request's URL's scheme is not an HTTP(S) scheme, then return.

      2. Set `timingInfo`'s end time to the relative high resolution time given `unsafeEndTime` and `global`.

      3. Let `cacheState` be `response`'s cache state.

      4. Let `bodyInfo` be `response`'s body info.

      5. If `response`'s timing allow passed flag is not set, then set `timingInfo` to the result of creating an opaque timing info for `timingInfo` and set `cacheState` to the empty string.

         This covers the case of `response` being a network error.

      6. Let `responseStatus` be 0.

      7. If `fetchParams`'s request's mode is not "navigate" or `response`'s redirect taint is "same-origin":

         1. Set `responseStatus` to `response`'s status.

         2. Let `mimeType` be the result of extracting a MIME type from `response`'s header list.

         3. If `mimeType` is not failure, then set `bodyInfo`'s content type to the result of minimizing a supported MIME type given `mimeType`.

      8. If `fetchParams`'s request's initiator type is non-null, then mark resource timing given `timingInfo`, `fetchParams`'s request's URL, `fetchParams`'s request's initiator type, `global`, `cacheState`, `bodyInfo`, and `responseStatus`.

   3. Let `processResponseEndOfBodyTask` be the following steps:

      1. Set `fetchParams`'s request's done flag.

      2. If `fetchParams`'s process response end-of-body is non-null, then run `fetchParams`'s process response end-of-body given `response`.

      3. If `fetchParams`'s request's initiator type is non-null and `fetchParams`'s request's client's global object is `fetchParams`'s task destination, then run `fetchParams`'s controller's report timing steps given `fetchParams`'s request's client's global object.

   4. Queue a fetch task to run `processResponseEndOfBodyTask` with `fetchParams`'s task destination.

5. If `fetchParams`'s process response is non-null, then queue a fetch task to run `fetchParams`'s process response given `response`, with `fetchParams`'s task destination.

6. Let `internalResponse` be `response`, if `response` is a network error; otherwise `response`'s internal response.

7. If `internalResponse`'s body is null, then run `processResponseEndOfBody`.

8. Otherwise:

   1. Let `transformStream` be a new `TransformStream`.

   2. Let `identityTransformAlgorithm` be an algorithm which, given `chunk`, enqueues `chunk` in `transformStream`.

   3. Set up `transformStream` with *transformAlgorithm* set to `identityTransformAlgorithm` and *flushAlgorithm* set to `processResponseEndOfBody`.

   4. Set `internalResponse`'s body's stream to the result of `internalResponse`'s body's stream piped through `transformStream`.

   This `TransformStream` is needed for the purpose of receiving a notification when the stream reaches its end, and is otherwise an identity transform stream.

9. If `fetchParams`'s process response consume body is non-null, then:

   1. Let `processBody` given `nullOrBytes` be this step: run `fetchParams`'s process response consume body given `response` and `nullOrBytes`.

   2. Let `processBodyError` be this step: run `fetchParams`'s process response consume body given `response` and failure.

   3. If `internalResponse`'s body is null, then queue a fetch task to run `processBody` given null, with `fetchParams`'s task destination.

   4. Otherwise, fully read `internalResponse`'s body given `processBody`, `processBodyError`, and `fetchParams`'s task destination.


### Override fetch

To **override fetch**, given "scheme-fetch" or "http-fetch" `type`, a fetch params `fetchParams`, and an optional boolean `makeCORSPreflight` (default false):

1. Let `request` be `fetchParams`' request.

2. Let `response` be the result of executing potentially override response for a request on `request`.

3. If `response` is non-null, then return `response`.

4. Switch on `type` and run the associated step:

   "scheme fetch"

   : Set `response` be the result of running scheme fetch given `fetchParams`.

   "HTTP fetch"

   : Set `response` be the result of running HTTP fetch given `fetchParams` and `makeCORSPreflight`.

5. Return `response`.

The **potentially override response for a request** algorithm takes a request `request`, and returns either a response or null. Its behavior is implementation-defined, allowing user agents to intervene on the request by returning a response directly, or allowing the request to proceed by returning null.

By default, the algorithm has the following trivial implementation:

1. Return null.

User agents will generally override this default implementation with a somewhat more complex set of behaviors. For example, a user agent might decide that its users' safety is best preserved by generally blocking requests to `https://unsafe.example/`, while synthesizing a shim for the widely-used resource `https://unsafe.example/widget.js` to avoid breakage. That implementation might look like the following:

1. If `request`'s current url's host's registrable domain is "unsafe.example":

   1. If `request`'s current url's path is « "widget.js" »:

      1. Let `body` be [*insert a byte sequence representing the shimmed content here*].

      2. Return a new response with the following properties:

         type
         : "cors"

         status
         : 200

         ...
         : ...

         body
         : The result of getting `body` as a body.

   2. Return a network error.

2. Return null.


### Scheme fetch

To **scheme fetch**, given a fetch params `fetchParams`:

1. If `fetchParams` is canceled, then return the appropriate network error for `fetchParams`.

2. Let `request` be `fetchParams`'s request.

3. Switch on `request`'s current URL's scheme and run the associated steps:

   "about"

   : If `request`'s current URL's path is the string "blank", then return a new response whose status message is `OK`, header list is « (`Content-Type`, `text/html;charset=utf-8`) », and body is the empty byte sequence as a body.

     URLs such as "about:config" are handled during navigation and result in a network error in the context of fetching.

   "blob"

   : 1. Let `blobURLEntry` be `request`'s current URL's blob URL entry.

     2. If `request`'s method is not `GET` or `blobURLEntry` is null, then return a network error. [FILEAPI]

        The `GET` method restriction serves no useful purpose other than being interoperable.

     3. Let `requestEnvironment` be the result of determining the environment given `request`.

     4. Let `isTopLevelNavigation` be true if `request`'s destination is "document"; otherwise, false.

     5. If `isTopLevelNavigation` is false and `requestEnvironment` is null, then return a network error.

     6. Let `navigationOrEnvironment` be the string "navigation" if `isTopLevelNavigation` is true; otherwise, `requestEnvironment`.

     7. Let `blob` be the result of obtaining a blob object given `blobURLEntry` and `navigationOrEnvironment`.

     8. If `blob` is not a `Blob` object, then return a network error.

     9. Let `response` be a new response.

     10. Let `fullLength` be `blob`'s `size`.

     11. Let `serializedFullLength` be `fullLength`, serialized and isomorphic encoded.

     12. Let `type` be `blob`'s `type`.

     13. If `request`'s header list does not contain `Range`:

         1. Let `bodyWithType` be the result of safely extracting `blob`.

         2. Set `response`'s status message to `OK`.

         3. Set `response`'s body to `bodyWithType`'s body.

         4. Set `response`'s header list to « (`Content-Length`, `serializedFullLength`), (`Content-Type`, `type`) ».

     14. Otherwise:

         1. Set `response`'s range-requested flag.

         2. Let `rangeHeader` be the result of getting `Range` from `request`'s header list.

         3. Let `rangeValue` be the result of parsing a single range header value given `rangeHeader` and true.

         4. If `rangeValue` is failure, then return a network error.

         5. Let (`rangeStart`, `rangeEnd`) be `rangeValue`.

         6. If `rangeStart` is null:

             1. Set `rangeStart` to `fullLength` − `rangeEnd`.

             2. Set `rangeEnd` to `rangeStart` + `rangeEnd` − 1.

         7. Otherwise:

             1. If `rangeStart` is greater than or equal to `fullLength`, then return a network error.

             2. If `rangeEnd` is null or `rangeEnd` is greater than or equal to `fullLength`, then set `rangeEnd` to `fullLength` − 1.

         8. Let `slicedBlob` be the result of invoking slice blob given `blob`, `rangeStart`, `rangeEnd` + 1, and `type`.

            A range header denotes an inclusive byte range, while the slice blob algorithm input range does not. To use the slice blob algorithm, we have to increment `rangeEnd`.

         9. Let `slicedBodyWithType` be the result of safely extracting `slicedBlob`.

         10. Set `response`'s body to `slicedBodyWithType`'s body.

         11. Let `serializedSlicedLength` be `slicedBlob`'s `size`, serialized and isomorphic encoded.

         12. Let `contentRange` be the result of invoking build a content range given `rangeStart`, `rangeEnd`, and `fullLength`.

         13. Set `response`'s status to 206.

         14. Set `response`'s status message to `Partial Content`.

         15. Set `response`'s header list to « (`Content-Length`, `serializedSlicedLength`), (`Content-Type`, `type`), (`Content-Range`, `contentRange`) ».

     15. Return `response`.

   "data"

   : 1. Let `dataURLStruct` be the result of running the `data:` URL processor on `request`'s current URL.

     2. If `dataURLStruct` is failure, then return a network error.

     3. Let `mimeType` be `dataURLStruct`'s MIME type, serialized.

     4. Return a new response whose status message is `OK`, header list is « (`Content-Type`, `mimeType`) », and body is `dataURLStruct`'s body as a body.

   "file"

   : For now, unfortunate as it is, `file:` URLs are left as an exercise for the reader.

     When in doubt, return a network error.

   HTTP(S) scheme

   : Return the result of running HTTP fetch given `fetchParams`.

4. Return a network error.

To **determine the environment**, given a request `request`:

1. If `request`'s reserved client is non-null, then return `request`'s reserved client.

2. If `request`'s client is non-null, then return `request`'s client.

3. Return null.


### HTTP fetch

To **HTTP fetch**, given a fetch params `fetchParams` and an optional boolean `makeCORSPreflight` (default false), run these steps:

1. Let `request` be `fetchParams`'s request.

2. Let `response` and `internalResponse` be null.

3. If `request`'s service-workers mode is "all", then:

   1. Let `requestForServiceWorker` be a clone of `request`.

   2. If `requestForServiceWorker`'s body is non-null, then:

      1. Let `transformStream` be a new `TransformStream`.

      2. Let `transformAlgorithm` given `chunk` be these steps:

         1. If `fetchParams` is canceled, then abort these steps.

         2. If `chunk` is not a `Uint8Array` object, then terminate `fetchParams`'s controller.

         3. Otherwise, enqueue `chunk` in `transformStream`. The user agent may split the chunk into implementation-defined practical sizes and enqueue each of them. The user agent also may concatenate the chunks into an implementation-defined practical size and enqueue it.

      3. Set up `transformStream` with *transformAlgorithm* set to `transformAlgorithm`.

      4. Set `requestForServiceWorker`'s body's stream to the result of `requestForServiceWorker`'s body's stream piped through `transformStream`.

   3. Let `serviceWorkerStartTime` be the coarsened shared current time given `fetchParams`'s cross-origin isolated capability.

   4. Set `response` to the result of invoking handle fetch for `requestForServiceWorker`, with `fetchParams`'s controller and `fetchParams`'s cross-origin isolated capability. [HTML] [SW]

   5. If `response` is non-null, then:

      1. Set `fetchParams`'s timing info's final service worker start time to `serviceWorkerStartTime`.

      2. If `request`'s body is non-null, then cancel `request`'s body with undefined.

      3. Set `internalResponse` to `response`, if `response` is not a filtered response; otherwise to `response`'s internal response.

      4. If one of the following is true

         - `response`'s type is "error"

         - `request`'s mode is "same-origin" and `response`'s type is "cors"

         - `request`'s mode is not "no-cors" and `response`'s type is "opaque"

         - `request`'s redirect mode is not "manual" and `response`'s type is "opaqueredirect"

         - `request`'s redirect mode is not "follow" and `response`'s URL list has more than one item.

         then return a network error.

4. If `response` is null, then:

   1. If `makeCORSPreflight` is true and one of these conditions is true:

      - There is no method cache entry match for `request`'s method using `request`, and either `request`'s method is not a CORS-safelisted method or `request`'s use-CORS-preflight flag is set.

      - There is at least one item in the CORS-unsafe request-header names with `request`'s header list for which there is no header-name cache entry match using `request`.

      Then:

      1. Let `preflightResponse` be the result of running CORS-preflight fetch given `request`.

      2. If `preflightResponse` is a network error, then return `preflightResponse`.

      This step checks the CORS-preflight cache and if there is no suitable entry it performs a CORS-preflight fetch which, if successful, populates the cache. The purpose of the CORS-preflight fetch is to ensure the fetched resource is familiar with the CORS protocol. The cache is there to minimize the number of CORS-preflight fetches.

   2. If `request`'s redirect mode is "follow", then set `request`'s service-workers mode to "none".

      Redirects coming from the network (as opposed to from a service worker) are not to be exposed to a service worker.

   3. Set `response` and `internalResponse` to the result of running HTTP-network-or-cache fetch given `fetchParams`.

   4. If `request`'s response tainting is "cors" and a CORS check for `request` and `response` returns failure, then return a network error.

      As the CORS check is not to be applied to responses whose status is 304 or 407, or responses from a service worker for that matter, it is applied here.

   5. If the TAO check for `request` and `response` returns failure, then set `request`'s timing allow failed flag.

5. If either `request`'s response tainting or `response`'s type is "opaque", and the cross-origin resource policy check with `request`'s origin, `request`'s client, `request`'s destination, and `internalResponse` returns **blocked**, then return a network error.

   The cross-origin resource policy check runs for responses coming from the network and responses coming from the service worker. This is different from the CORS check, as `request`'s client and the service worker can have different embedder policies.

6. If `internalResponse`'s status is a redirect status:

   1. If `internalResponse`'s status is not 303, `request`'s body is non-null, and the connection uses HTTP/2, then user agents may, and are even encouraged to, transmit an `RST_STREAM` frame.

      303 is excluded as certain communities ascribe special status to it.

   2. Switch on `request`'s redirect mode:

      "error"

      : 1. Set `response` to a network error.

      "manual"

      : 1. If `request`'s mode is "navigate", then set `fetchParams`'s controller's next manual redirect steps to run HTTP-redirect fetch given `fetchParams` and `response`.

        2. Otherwise, set `response` to an opaque-redirect filtered response whose internal response is `internalResponse`.

      "follow"

      : 1. Set `response` to the result of running HTTP-redirect fetch given `fetchParams` and `response`.

7. Return `response`. [Typically `internalResponse`'s body's stream is still being enqueued to after returning.]


### HTTP-redirect fetch

To **HTTP-redirect fetch**, given a fetch params `fetchParams` and a response `response`, run these steps:

1. Let `request` be `fetchParams`'s request.

2. Let `internalResponse` be `response`, if `response` is not a filtered response; otherwise `response`'s internal response.

3. Let `locationURL` be `internalResponse`'s location URL given `request`'s current URL's fragment.

4. If `locationURL` is null, then return `response`.

5. If `locationURL` is failure, then return a network error.

6. If `locationURL`'s scheme is not an HTTP(S) scheme, then return a network error.

7. If `request`'s redirect count is 20, then return a network error.

8. Increase `request`'s redirect count by 1.

9. If `request`'s mode is "cors", `locationURL` includes credentials, and `request`'s origin is not same origin with `locationURL`'s origin, then return a network error.

10. If `request`'s response tainting is "cors" and `locationURL` includes credentials, then return a network error.

    This catches a cross-origin resource redirecting to a same-origin URL.

11. If `internalResponse`'s status is not 303, `request`'s body is non-null, and `request`'s body's source is null, then return a network error.

12. If one of the following is true

    - `internalResponse`'s status is 301 or 302 and `request`'s method is `POST`

    - `internalResponse`'s status is 303 and `request`'s method is not `GET` or `HEAD`

    then:

    1. Set `request`'s method to `GET` and `request`'s body to null.

    2. For each `headerName` of request-body-header name, delete `headerName` from `request`'s header list.

13. If `request`'s current URL's origin is not same origin with `locationURL`'s origin, then for each `headerName` of CORS non-wildcard request-header name, delete `headerName` from `request`'s header list.

    I.e., the moment another origin is seen after the initial request, the `Authorization` header is removed.

14. If `request`'s body is non-null, then set `request`'s body to the body of the result of safely extracting `request`'s body's source.

    `request`'s body's source's nullity has already been checked.

15. Let `timingInfo` be `fetchParams`'s timing info.

16. Set `timingInfo`'s redirect end time and post-redirect start time to the coarsened shared current time given `fetchParams`'s cross-origin isolated capability.

17. If `timingInfo`'s redirect start time is 0, then set `timingInfo`'s redirect start time to `timingInfo`'s start time.

18. Append `locationURL` to `request`'s URL list.

19. Invoke set `request`'s referrer policy on redirect on `request` and `internalResponse`. [REFERRER]

20. Let `recursive` be true.

21. If `request`'s redirect mode is "manual", then:

    1. Assert: `request`'s mode is "navigate".

    2. Set `recursive` to false.

22. Return the result of running main fetch given `fetchParams` and `recursive`.

    This has to invoke main fetch to get `request`'s response tainting correct.


### HTTP-network-or-cache fetch

To **HTTP-network-or-cache fetch**, given a fetch params `fetchParams`, an optional boolean `isAuthenticationFetch` (default false), and an optional boolean `isNewConnectionFetch` (default false), run these steps:

Some implementations might support caching of partial content, as per HTTP Caching. However, this is not widely supported by browser caches. [HTTP-CACHING]

1. Let `request` be `fetchParams`'s request.

2. Let `httpFetchParams` be null.

3. Let `httpRequest` be null.

4. Let `response` be null.

5. Let `storedResponse` be null.

6. Let `httpCache` be null.

7. Let the `revalidatingFlag` be unset.

8. Run these steps, but abort when `fetchParams` is canceled:

   1. If `request`'s traversable for user prompts is "no-traversable" and `request`'s redirect mode is "error", then set `httpFetchParams` to `fetchParams` and `httpRequest` to `request`.

   2. Otherwise:

      1. Set `httpRequest` to a clone of `request`.

         Implementations are encouraged to avoid teeing `request`'s body's stream when `request`'s body's source is null as only a single body is needed in that case. E.g., when `request`'s body's source is null, redirects and authentication will end up failing the fetch.

      2. Set `httpFetchParams` to a copy of `fetchParams`.

      3. Set `httpFetchParams`'s request to `httpRequest`.

      If user prompts or redirects are possible, then the user agent might need to re-send the request with a new set of headers after the user answers the prompt or the redirect location is determined. At that time, the original request body might have been partially sent already, so we need to clone the request (including the body) beforehand so that we have a spare copy available.

   3. Let `includeCredentials` be true if one of

      - `request`'s credentials mode is "include"
      - `request`'s credentials mode is "same-origin" and `request`'s response tainting is "basic"

      is true; otherwise false.

   4. If Cross-Origin-Embedder-Policy allows credentials with `request` returns false, then set `includeCredentials` to false.

   5. Let `contentLength` be `httpRequest`'s body's length, if `httpRequest`'s body is non-null; otherwise null.

   6. Let `contentLengthHeaderValue` be null.

   7. If `httpRequest`'s body is null and `httpRequest`'s method is `POST` or `PUT`, then set `contentLengthHeaderValue` to `0`.

   8. If `contentLength` is non-null, then set `contentLengthHeaderValue` to `contentLength`, serialized and isomorphic encoded.

   9. If `contentLengthHeaderValue` is non-null, then append (`Content-Length`, `contentLengthHeaderValue`) to `httpRequest`'s header list.

   10. If `contentLength` is non-null and `httpRequest`'s keepalive is true, then:

       1. Let `inflightKeepaliveBytes` be 0.

       2. Let `group` be `httpRequest`'s client's fetch group.

       3. Let `inflightRecords` be the set of fetch records in `group` whose request's keepalive is true and done flag is unset.

       4. For each `fetchRecord` of `inflightRecords`:

          1. Let `inflightRequest` be `fetchRecord`'s request.

          2. Increment `inflightKeepaliveBytes` by `inflightRequest`'s body's length.

       5. If the sum of `contentLength` and `inflightKeepaliveBytes` is greater than 64 kibibytes, then return a network error.

       The above limit ensures that requests that are allowed to outlive the environment settings object and contain a body, have a bounded size and are not allowed to stay alive indefinitely.

   11. If `httpRequest`'s referrer is a URL, then:

       1. Let `referrerValue` be `httpRequest`'s referrer, serialized and isomorphic encoded.

       2. Append (`Referer`, `referrerValue`) to `httpRequest`'s header list.

   12. Append a request `Origin` header for `httpRequest`.

   13. Append the Fetch metadata headers for `httpRequest`. [FETCH-METADATA]

   14. If `httpRequest`'s initiator is "prefetch", then set a structured field value given (`Sec-Purpose`, the token `prefetch`) in `httpRequest`'s header list.

   15. If `httpRequest`'s header list does not contain `User-Agent`, then user agents should:

       1. Let `userAgent` be `httpRequest`'s client's environment default `User-Agent` value.

       2. Append (`User-Agent`, `userAgent`) to `httpRequest`'s header list.

   16. If `httpRequest`'s cache mode is "default" and `httpRequest`'s header list contains `If-Modified-Since`, `If-None-Match`, `If-Unmodified-Since`, `If-Match`, or `If-Range`, then set `httpRequest`'s cache mode to "no-store".

   17. If `httpRequest`'s cache mode is "no-cache", `httpRequest`'s prevent no-cache cache-control header modification flag is unset, and `httpRequest`'s header list does not contain `Cache-Control`, then append (`Cache-Control`, `max-age=0`) to `httpRequest`'s header list.

   18. If `httpRequest`'s cache mode is "no-store" or "reload", then:

       1. If `httpRequest`'s header list does not contain `Pragma`, then append (`Pragma`, `no-cache`) to `httpRequest`'s header list.

       2. If `httpRequest`'s header list does not contain `Cache-Control`, then append (`Cache-Control`, `no-cache`) to `httpRequest`'s header list.

   19. If `httpRequest`'s header list contains `Range`, then append (`Accept-Encoding`, `identity`) to `httpRequest`'s header list.

       This avoids a failure when handling content codings with a part of an encoded response.

       Additionally, many servers mistakenly ignore `Range` headers if a non-identity encoding is accepted.

   20. Modify `httpRequest`'s header list per HTTP. Do not append a given header if `httpRequest`'s header list contains that header's name.

       It would be great if we could make this more normative somehow. At this point headers such as `Accept-Encoding`, `Connection`, `DNT`, and `Host`, are to be appended if necessary.

       `Accept`, `Accept-Charset`, and `Accept-Language` must not be included at this point.

       `Accept` and `Accept-Language` are already included (unless `fetch()` is used, which does not include the latter by default), and `Accept-Charset` is a waste of bytes. See HTTP header layer division for more details.

   21. If `includeCredentials` is true, then:

       1. Append a request `Cookie` header for `httpRequest`.

       2. If `httpRequest`'s header list does not contain `Authorization`, then:

          1. Let `authorizationValue` be null.

          2. If there's an authentication entry for `httpRequest` and either `httpRequest`'s use-URL-credentials flag is unset or `httpRequest`'s current URL does not include credentials, then set `authorizationValue` to authentication entry.

          3. Otherwise, if `httpRequest`'s current URL does include credentials and `isAuthenticationFetch` is true, set `authorizationValue` to `httpRequest`'s current URL, [converted to an `Authorization` value].

          4. If `authorizationValue` is non-null, then append (`Authorization`, `authorizationValue`) to `httpRequest`'s header list.

   22. If there's a proxy-authentication entry, use it as appropriate.

       This intentionally does not depend on `httpRequest`'s credentials mode.

   23. Set `httpCache` to the result of determining the HTTP cache partition, given `httpRequest`.

   24. If `httpCache` is null, then set `httpRequest`'s cache mode to "no-store".

   25. If `httpRequest`'s cache mode is neither "no-store" nor "reload", then:

       1. Set `storedResponse` to the result of selecting a response from the `httpCache`, possibly needing validation, as per the "Constructing Responses from Caches" chapter of HTTP Caching, if any. [HTTP-CACHING]

          As mandated by HTTP, this still takes the `Vary` header into account.

       2. If `storedResponse` is non-null, then:

          1. If cache mode is "default", `storedResponse` is a stale-while-revalidate response, and `httpRequest`'s client is non-null, then:

             1. Set `response` to `storedResponse`.

             2. Set `response`'s cache state to "local".

             3. Let `revalidateRequest` be a clone of `request`.

             4. Set `revalidateRequest`'s cache mode set to "no-cache".

             5. Set `revalidateRequest`'s prevent no-cache cache-control header modification flag.

             6. Set `revalidateRequest`'s service-workers mode set to "none".

             7. In parallel, run main fetch given a new fetch params whose request is `revalidateRequest`.

                This fetch is only meant to update the state of `httpCache` and the response will be unused until another cache access. The stale response will be used as the response to current request. This fetch is issued in the context of a client so if it goes away the request will be terminated.

          2. Otherwise:

             1. If `storedResponse` is a stale response, then set the `revalidatingFlag`.

             2. If the `revalidatingFlag` is set and `httpRequest`'s cache mode is neither "force-cache" nor "only-if-cached", then:

                1. If `storedResponse`'s header list contains `ETag`, then append (`If-None-Match`, `ETag`'s value) to `httpRequest`'s header list.

                2. If `storedResponse`'s header list contains `Last-Modified`, then append (`If-Modified-Since`, `Last-Modified`'s value) to `httpRequest`'s header list.

                See also the "Sending a Validation Request" chapter of HTTP Caching. [HTTP-CACHING]

             3. Otherwise, set `response` to `storedResponse` and set `response`'s cache state to "local".

9. If aborted, then return the appropriate network error for `fetchParams`.

10. If `response` is null, then:

    1. If `httpRequest`'s cache mode is "only-if-cached", then return a network error.

    2. Let `forwardResponse` be the result of running HTTP-network fetch given `httpFetchParams`, `includeCredentials`, and `isNewConnectionFetch`.

    3. If `httpRequest`'s method is unsafe and `forwardResponse`'s status is in the range 200 to 399, inclusive, invalidate appropriate stored responses in `httpCache`, as per the "Invalidating Stored Responses" chapter of HTTP Caching, and set `storedResponse` to null. [HTTP-CACHING]

    4. If the `revalidatingFlag` is set and `forwardResponse`'s status is 304, then:

       1. Update `storedResponse`'s header list using `forwardResponse`'s header list, as per the "Freshening Stored Responses upon Validation" chapter of HTTP Caching. [HTTP-CACHING]

          This updates the stored response in cache as well.

       2. Set `response` to `storedResponse`.

       3. Set `response`'s cache state to "validated".

    5. If `response` is null, then:

       1. Set `response` to `forwardResponse`.

       2. Store `httpRequest` and `forwardResponse` in `httpCache`, as per the "Storing Responses in Caches" chapter of HTTP Caching. [HTTP-CACHING]

          If `forwardResponse` is a network error, this effectively caches the network error, which is sometimes known as "negative caching".

          The associated body info is stored in the cache alongside the response.

11. Set `response`'s URL list to a clone of `httpRequest`'s URL list.

12. If `httpRequest`'s header list contains `Range`, then set `response`'s range-requested flag.

13. Set `response`'s request-includes-credentials to `includeCredentials`.

14. If `response`'s status is 401, `httpRequest`'s response tainting is not "cors", `includeCredentials` is true, and `request`'s traversable for user prompts is a traversable navigable:

    1. Needs testing: multiple `WWW-Authenticate` headers, missing, parsing issues.

    2. If `request`'s body is non-null, then:

       1. If `request`'s body's source is null, then return a network error.

       2. Set `request`'s body to the body of the result of safely extracting `request`'s body's source.

    3. If `request`'s use-URL-credentials flag is unset or `isAuthenticationFetch` is true, then:

       1. If `fetchParams` is canceled, then return the appropriate network error for `fetchParams`.

       2. Let `username` and `password` be the result of prompting the end user for a username and password, respectively, in `request`'s traversable for user prompts.

       3. Set the username given `request`'s current URL and `username`.

       4. Set the password given `request`'s current URL and `password`.

    4. Set `response` to the result of running HTTP-network-or-cache fetch given `fetchParams` and true.

15. If `response`'s status is 407, then:

    1. If `request`'s traversable for user prompts is "no-traversable", then return a network error.

    2. Needs testing: multiple `Proxy-Authenticate` headers, missing, parsing issues.

    3. If `fetchParams` is canceled, then return the appropriate network error for `fetchParams`.

    4. Prompt the end user as appropriate in `request`'s traversable for user prompts and store the result as a proxy-authentication entry. [HTTP]

       Remaining details surrounding proxy authentication are defined by HTTP.

    5. Set `response` to the result of running HTTP-network-or-cache fetch given `fetchParams`.

16. If all of the following are true

    - `response`'s status is 421

    - `isNewConnectionFetch` is false

    - `request`'s body is null, or `request`'s body is non-null and `request`'s body's source is non-null

    then:

    1. If `fetchParams` is canceled, then return the appropriate network error for `fetchParams`.

    2. Set `response` to the result of running HTTP-network-or-cache fetch given `fetchParams`, `isAuthenticationFetch`, and true.

17. If `isAuthenticationFetch` is true, then create an authentication entry for `request` and the given realm.

18. Return `response`. [Typically `response`'s body's stream is still being enqueued to after returning.]


### HTTP-network fetch

To **HTTP-network fetch**, given a fetch params `fetchParams`, an optional boolean `includeCredentials` (default false), and an optional boolean `forceNewConnection` (default false), run these steps:

1. Let `request` be `fetchParams`'s request.

2. If `request`'s client is offline, then return a network error.

3. Let `response` be null.

4. Let `timingInfo` be `fetchParams`'s timing info.

5. Let `networkPartitionKey` be the result of determining the network partition key given `request`.

6. Let `newConnection` be "yes" if `forceNewConnection` is true; otherwise "no".

7. Switch on `request`'s mode:

   "websocket"

   : Let `connection` be the result of obtaining a WebSocket connection, given `request`'s current URL.

   Otherwise

   : Let `connection` be the result of obtaining a connection, given `networkPartitionKey`, `request`'s current URL, `includeCredentials`, and `newConnection`.

8. Run these steps, but abort when `fetchParams` is canceled:

   1. If `connection` is failure, then return a network error.

   2. Set `timingInfo`'s final connection timing info to the result of calling clamp and coarsen connection timing info with `connection`'s timing info, `timingInfo`'s post-redirect start time, and `fetchParams`'s cross-origin isolated capability.

   3. If `connection` is an HTTP/1.x connection, `request`'s body is non-null, and `request`'s body's source is null, then return a network error.

   4. Set `timingInfo`'s final network-request start time to the coarsened shared current time given `fetchParams`'s cross-origin isolated capability.

   5. Set `response` to the result of making an HTTP request over `connection` using `request` with the following caveats:

      - Follow the relevant requirements from HTTP. [HTTP] [HTTP-CACHING]

      - If `request`'s body is non-null, and `request`'s body's source is null, then the user agent may have a buffer of up to 64 kibibytes and store a part of `request`'s body in that buffer. If the user agent reads from `request`'s body beyond that buffer's size and the user agent needs to resend `request`, then instead return a network error.

        The resending is needed when the connection is timed out, for example.

        The buffer is not needed when `request`'s body's source is non-null, because `request`'s body can be recreated from it.

        When `request`'s body's source is null, it means body is created from a `ReadableStream` object, which means body cannot be recreated and that is why the buffer is needed.

      - While true:

        1. Set `timingInfo`'s final network-response start time to the coarsened shared current time given `fetchParams`'s cross-origin isolated capability, immediately after the user agent's HTTP parser receives the first byte of the response (e.g., frame header bytes for HTTP/2 or response status line for HTTP/1.x).

        2. Wait until all the HTTP response headers are transmitted.

        3. Let `status` be the HTTP response's status code.

        4. If `status` is in the range 100 to 199, inclusive:

           1. If `timingInfo`'s first interim network-response start time is 0, then set `timingInfo`'s first interim network-response start time to `timingInfo`'s final network-response start time.

           2. If `request`'s mode is "websocket" and `status` is 101, then break.

           3. If `status` is 103 and `fetchParams`'s process early hints response is non-null, then queue a fetch task to run `fetchParams`'s process early hints response, with response.

           4. Continue.

           These kind of HTTP responses are eventually followed by a "final" HTTP response.

        5. Break.

      The exact layering between Fetch and HTTP still needs to be sorted through and therefore `response` represents both a response and an HTTP response here.

      If the HTTP request results in a TLS client certificate dialog, then:

      1. If `request`'s traversable for user prompts is a traversable navigable, then make the dialog available in `request`'s traversable for user prompts.

      2. Otherwise, return a network error.

      To transmit `request`'s body `body`, run these steps:

      1. If `body` is null and `fetchParams`'s process request end-of-body is non-null, then queue a fetch task given `fetchParams`'s process request end-of-body and `fetchParams`'s task destination.

      2. Otherwise, if `body` is non-null:

         1. Let `processBodyChunk` given `bytes` be these steps:

            1. If `fetchParams` is canceled, then abort these steps.

            2. Run this step in parallel: transmit `bytes`.

            3. If `fetchParams`'s process request body chunk length is non-null, then run `fetchParams`'s process request body chunk length given `bytes`'s length.

         2. Let `processEndOfBody` be these steps:

            1. If `fetchParams` is canceled, then abort these steps.

            2. If `fetchParams`'s process request end-of-body is non-null, then run `fetchParams`'s process request end-of-body.

         3. Let `processBodyError` given `e` be these steps:

            1. If `fetchParams` is canceled, then abort these steps.

            2. If `e` is an "`AbortError`" `DOMException`, then abort `fetchParams`'s controller.

            3. Otherwise, terminate `fetchParams`'s controller.

         4. Incrementally read `request`'s body given `processBodyChunk`, `processEndOfBody`, `processBodyError`, and `fetchParams`'s task destination.

9. If aborted, then:

   1. If `connection` uses HTTP/2, then transmit an `RST_STREAM` frame.

   2. Return the appropriate network error for `fetchParams`.

10. Let `buffer` be an empty byte sequence.

    This represents an internal buffer inside the network layer of the user agent.

11. Let `stream` be a new `ReadableStream`.

12. Let `pullAlgorithm` be the following steps:

    1. Let `promise` be a new promise.

    2. Run the following steps in parallel:

       1. If the size of `buffer` is smaller than a lower limit chosen by the user agent and the ongoing fetch is suspended, resume the fetch.

       2. Wait until `buffer` is not empty.

       3. Queue a fetch task to run the following steps, with `fetchParams`'s task destination.

          1. Pull from bytes `buffer` into `stream`.

          2. If `stream` is errored, then terminate `fetchParams`'s controller.

          3. Resolve `promise` with undefined.

    3. Return `promise`.

13. Let `cancelAlgorithm` be an algorithm that aborts `fetchParams`'s controller with `reason`, given `reason`.

14. Set up `stream` with byte reading support with `pullAlgorithm` set to `pullAlgorithm`, `cancelAlgorithm` set to `cancelAlgorithm`.

15. Set `response`'s body to a new body whose stream is `stream`.

16. If `includeCredentials` is true, then the user agent should parse and store response `Set-Cookie` headers given `request` and `response`.

17. Run these steps in parallel:

    1. Run these steps, but abort when `fetchParams` is canceled:

       1. While true:

          1. If one or more bytes have been transmitted from `response`'s message body, then:

             1. Let `bytes` be the transmitted bytes.

             2. Let `codings` be the result of extracting header list values given `Content-Encoding` and `response`'s header list.

             3. Let `filteredCoding` be "@unknown".

             4. If `codings` is null or failure, then set `filteredCoding` to the empty string.

             5. Otherwise, if `codings`'s size is greater than 1, then set `filteredCoding` to "multiple".

             6. Otherwise, if `codings`[0] is the empty string, or it is supported by the user agent, and is a byte-case-insensitive match for an entry listed in the HTTP Content Coding Registry, then set `filteredCoding` to the result of byte-lowercasing `codings`[0]. [IANA-HTTP-PARAMS]

             7. Set `response`'s body info's content encoding to `filteredCoding`.

             8. Increase `response`'s body info's encoded size by `bytes`'s length.

             9. Set `bytes` to the result of handling content codings given `codings` and `bytes`.

                This makes the `Content-Length` header unreliable to the extent that it was reliable to begin with.

             10. Increase `response`'s body info's decoded size by `bytes`'s length.

             11. If `bytes` is failure, then terminate `fetchParams`'s controller.

             12. Append `bytes` to `buffer`.

             13. If the size of `buffer` is larger than an upper limit chosen by the user agent, ask the user agent to suspend the ongoing fetch.

          2. Otherwise, if the bytes transmission for `response`'s message body is done normally and `stream` is readable, then close `stream`, and abort these in-parallel steps.

    2. If aborted, then:

       1. If `fetchParams` is aborted, then:

          1. Set `response`'s aborted flag.

          2. If `stream` is readable, then error `stream` with the result of deserialize a serialized abort reason given `fetchParams`'s controller's serialized abort reason and an implementation-defined realm.

       2. Otherwise, if `stream` is readable, error `stream` with a `TypeError`.

       3. If `connection` uses HTTP/2, then transmit an `RST_STREAM` frame.

       4. Otherwise, the user agent should close `connection` unless it would be bad for performance to do so.

          For instance, the user agent could keep the connection open if it knows there's only a few bytes of transfer remaining on a reusable connection. In this case it could be worse to close the connection and go through the handshake process again for the next fetch.

    These are run in parallel as at this point it is unclear whether `response`'s body is relevant (`response` might be a redirect).

18. Return `response`. [Typically `response`'s body's stream is still being enqueued to after returning.]


### CORS-preflight fetch

This is effectively the user agent implementation of the check to see if the CORS protocol is understood. The so-called CORS-preflight request. If successful it populates the CORS-preflight cache to minimize the number of these fetches.

To **CORS-preflight fetch**, given a request `request`, run these steps:

1. Let `preflight` be a new request whose method is `OPTIONS`, URL list is a clone of `request`'s URL list, initiator is `request`'s initiator, destination is `request`'s destination, origin is `request`'s origin, referrer is `request`'s referrer, referrer policy is `request`'s referrer policy, mode is "cors", and response tainting is "cors".

   The service-workers mode of `preflight` does not matter as this algorithm uses HTTP-network-or-cache fetch rather than HTTP fetch.

2. Append (`Accept`, `*/*`) to `preflight`'s header list.

3. Append (`Access-Control-Request-Method`, `request`'s method) to `preflight`'s header list.

4. Let `headers` be the CORS-unsafe request-header names with `request`'s header list.

5. If `headers` is not empty, then:

   1. Let `value` be the items in `headers` separated from each other by `,`.

   2. Append (`Access-Control-Request-Headers`, `value`) to `preflight`'s header list.

   This intentionally does not use combine, as 0x20 following 0x2C is not the way this was implemented, for better or worse.

6. Let `response` be the result of running HTTP-network-or-cache fetch given a new fetch params whose request is `preflight`.

7. If a CORS check for `request` and `response` returns success and `response`'s status is an ok status, then:

   The CORS check is done on `request` rather than `preflight` to ensure the correct credentials mode is used.

   1. Let `methods` be the result of extracting header list values given `Access-Control-Allow-Methods` and `response`'s header list.

   2. Let `headerNames` be the result of extracting header list values given `Access-Control-Allow-Headers` and `response`'s header list.

   3. If either `methods` or `headerNames` is failure, return a network error.

   4. If `methods` is null and `request`'s use-CORS-preflight flag is set, then set `methods` to a new list containing `request`'s method.

      This ensures that a CORS-preflight fetch that happened due to `request`'s use-CORS-preflight flag being set is cached.

   5. If `request`'s method is not in `methods`, `request`'s method is not a CORS-safelisted method, and `request`'s credentials mode is "include" or `methods` does not contain `*`, then return a network error.

   6. If one of `request`'s header list's names is a CORS non-wildcard request-header name and is not a byte-case-insensitive match for an item in `headerNames`, then return a network error.

   7. For each `unsafeName` of the CORS-unsafe request-header names with `request`'s header list, if `unsafeName` is not a byte-case-insensitive match for an item in `headerNames` and `request`'s credentials mode is "include" or `headerNames` does not contain `*`, return a network error.

   8. Let `max-age` be the result of extracting header list values given `Access-Control-Max-Age` and `response`'s header list.

   9. If `max-age` is failure or null, then set `max-age` to 5.

   10. If `max-age` is greater than an imposed limit on max-age, then set `max-age` to the imposed limit.

   11. If the user agent does not provide for a cache, then return `response`.

   12. For each `method` in `methods` for which there is a method cache entry match using `request`, set matching entry's max-age to `max-age`.

   13. For each `method` in `methods` for which there is no method cache entry match using `request`, create a new cache entry with `request`, `max-age`, `method`, and null.

   14. For each `headerName` in `headerNames` for which there is a header-name cache entry match using `request`, set matching entry's max-age to `max-age`.

   15. For each `headerName` in `headerNames` for which there is no header-name cache entry match using `request`, create a new cache entry with `request`, `max-age`, null, and `headerName`.

   16. Return `response`.

8. Otherwise, return a network error.


### CORS-preflight cache

A user agent has an associated **CORS-preflight cache**. A **CORS-preflight cache** is a list of cache entries.

A **cache entry** consists of:

- **key** (a network partition key)
- **byte-serialized origin** (a byte sequence)
- **URL** (a URL)
- **max-age** (a number of seconds)
- **credentials** (a boolean)
- **method** (null, `*`, or a method)
- **header name** (null, `*`, or a header name)

Cache entries must be removed after the seconds specified in their max-age field have passed since storing the entry. Cache entries may be removed before that moment arrives.

To **create a new cache entry**, given `request`, `max-age`, `method`, and `headerName`, run these steps:

1. Let `entry` be a cache entry, initialized as follows:

   key

   : The result of determining the network partition key given `request`

   byte-serialized origin

   : The result of byte-serializing a request origin with `request`

   URL

   : `request`'s current URL

   max-age

   : `max-age`

   credentials

   : True if `request`'s credentials mode is "include", and false otherwise

   method

   : `method`

   header name

   : `headerName`

2. Append `entry` to the user agent's CORS-preflight cache.

To **clear cache entries**, given a `request`, remove any cache entries in the user agent's CORS-preflight cache whose key is the result of determining the network partition key given `request`, byte-serialized origin is the result of byte-serializing a request origin with `request`, and URL is `request`'s current URL.

There is a **cache entry match** for a cache entry `entry` with `request` if `entry`'s key is the result of determining the network partition key given `request`, `entry`'s byte-serialized origin is the result of byte-serializing a request origin with `request`, `entry`'s URL is `request`'s current URL, and one of

- `entry`'s credentials is true
- `entry`'s credentials is false and `request`'s credentials mode is not "include".

is true.

There is a **method cache entry match** for `method` using `request` when there is a cache entry in the user agent's CORS-preflight cache for which there is a cache entry match with `request` and its method is `method` or `*`.

There is a **header-name cache entry match** for `headerName` using `request` when there is a cache entry in the user agent's CORS-preflight cache for which there is a cache entry match with `request` and one of

- its header name is a byte-case-insensitive match for `headerName`
- its header name is `*` and `headerName` is not a CORS non-wildcard request-header name

is true.


### CORS check

To perform a **CORS check** for a `request` and `response`, run these steps:

1. Let `origin` be the result of getting `Access-Control-Allow-Origin` from `response`'s header list.

2. If `origin` is null, then return failure.

   Null is not `null`.

3. If `request`'s credentials mode is not "include" and `origin` is `*`, then return success.

4. If the result of byte-serializing a request origin with `request` is not `origin`, then return failure.

5. If `request`'s credentials mode is not "include", then return success.

6. Let `credentials` be the result of getting `Access-Control-Allow-Credentials` from `response`'s header list.

7. If `credentials` is `true`, then return success.

8. Return failure.


### TAO check

To perform a **TAO check** for a `request` and `response`, run these steps:

1. Assert: `request`'s origin is not "client".

2. If `request`'s timing allow failed flag is set, then return failure.

3. Let `values` be the result of getting, decoding, and splitting `Timing-Allow-Origin` from `response`'s header list.

4. If `values` contains "*", then return success.

5. If `values` contains the result of serializing a request origin with `request`, then return success.

6. If `request`'s mode is "navigate" and `request`'s current URL's origin is not same origin with `request`'s origin, then return failure.

   This is necessary for navigations of a nested navigable. There, `request`'s origin would be the container document's origin and the TAO check would return failure. Since navigation timing never validates the results of the TAO check, the nested document would still have access to the full timing information, but the container document would not.

7. If `request`'s response tainting is "basic", then return success.

8. Return failure.


### Deferred fetching

Deferred fetching allows callers to request that a fetch is invoked at the latest possible moment, i.e., when a fetch group is terminated, or after a timeout.

The **deferred fetch task source** is a task source used to update the result of a deferred fetch. User agents must prioritize tasks in this task source before other task sources, specifically task sources that can result in running scripts such as the DOM manipulation task source, to reflect the most recent state of a `fetchLater()` call before running any scripts that might depend on it.

To **queue a deferred fetch** given a request `request`, a null or `DOMHighResTimeStamp` `activateAfter`, and `onActivatedWithoutTermination`, which is an algorithm that takes no arguments:

1. Populate request from client given `request`.

2. Set `request`'s service-workers mode to "none".

3. Set `request`'s keepalive to true.

4. Let `deferredRecord` be a new deferred fetch record whose request is `request`, and whose notify invoked is `onActivatedWithoutTermination`.

5. Append `deferredRecord` to `request`'s client's fetch group's deferred fetch records.

6. If `activateAfter` is non-null, then run the following steps in parallel:

   1. The user agent should wait until any of the following conditions is met:

      - At least `activateAfter` milliseconds have passed.

      - The user agent has a reason to believe that it is about to lose the opportunity to execute scripts, e.g., when the browser is moved to the background, or when `request`'s client's global object is a `Window` object whose associated document had a "hidden" visibility state for a long period of time.

   2. Process `deferredRecord`.

7. Return `deferredRecord`.

To compute the **total request length** of a request `request`:

1. Let `totalRequestLength` be the length of `request`'s URL, serialized with *exclude fragment* set to true.

2. Increment `totalRequestLength` by the length of `request`'s referrer, serialized.

3. For each (`name`, `value`) of `request`'s header list, increment `totalRequestLength` by `name`'s length + `value`'s length.

4. Increment `totalRequestLength` by `request`'s body's length.

5. Return `totalRequestLength`.

To **process deferred fetches** given a fetch group `fetchGroup`:

1. For each deferred fetch record `deferredRecord` of `fetchGroup`'s deferred fetch records, process a deferred fetch `deferredRecord`.

To **process a deferred fetch** `deferredRecord`:

1. If `deferredRecord`'s invoke state is not "pending", then return.

2. Set `deferredRecord`'s invoke state to "sent".

3. Fetch `deferredRecord`'s request.

4. Queue a global task on the deferred fetch task source with `deferredRecord`'s request's client's global object to run `deferredRecord`'s notify invoked.


#### Deferred fetching quota

*This section is non-normative.*

The deferred-fetch quota is allocated to a top-level traversable (a "tab"), amounting to 640 kibibytes. The top-level document and its same-origin directly nested documents can use this quota to queue deferred fetches, or delegate some of it to cross-origin nested documents, using permissions policy.

By default, 128 kibibytes out of these 640 kibibytes are allocated to delegating the quota to cross-origin nested documents, each reserving 8 kibibytes.

The top-level document, and subsequently its nested documents, can control how much of their quota is delegates to cross-origin child documents, using permissions policy. By default, the "`deferred-fetch-minimal`" policy is enabled for any origin, while "`deferred-fetch`" is enabled for the top-level document's origin only. By relaxing the "`deferred-fetch`" policy for particular origins and nested documents, the top-level document can allocate 64 kibibytes to those nested documents. Similarly, by restricting the "`deferred-fetch-minimal`" policy for a particular origin or nested document, the document can prevent the document from reserving the 8 kibibytes it would receive by default. By disabling the "`deferred-fetch-minimal`" policy for the top-level document itself, the entire 128 kibibytes delegated quota is collected back into the main pool of 640 kibibytes.

Out of the allocated quota for a document, only 64 kibibytes can be used concurrently for the same reporting origin (the request's URL's origin). This prevents a situation where particular third-party libraries would reserve quota opportunistically, before they have data to send.

Any of the following calls to `fetchLater()` would throw due to the request itself exceeding the 64 kibibytes quota allocated to a reporting origin. Note that the size of the request includes the URL itself, the body, the header list, and the referrer.

```javascript
fetchLater(a_72_kb_url);
fetchLater("https://origin.example.com", {headers: headers_exceeding_64kb});
fetchLater(a_32_kb_url, {headers: headers_exceeding_32kb});
fetchLater("https://origin.example.com", {method: "POST", body: body_exceeding_64_kb});
fetchLater(a_62_kb_url /* with a 3kb referrer */);
```

In the following sequence, the first two requests would succeed, but the third one would throw. That's because the overall 640 kibibytes quota was not exceeded in the first two calls, however the 3rd request exceeds the reporting-origin quota for `https://a.example.com`, and would throw.

```javascript
fetchLater("https://a.example.com", {method: "POST", body: a_64kb_body});
fetchLater("https://b.example.com", {method: "POST", body: a_64kb_body});
fetchLater("https://a.example.com");
```

Same-origin nested documents share the quota of their parent. However, cross-origin or cross-agent iframes only receive 8kb of quota by default. So in the following example, the first three calls would succeed and the last one would throw.

```javascript
// In main page
fetchLater("https://a.example.com", {method: "POST", body: a_64kb_body});

// In same-origin nested document
fetchLater("https://b.example.com", {method: "POST", body: a_64kb_body});

// In cross-origin nested document at https://fratop.example.com
fetchLater("https://a.example.com", {body: a_5kb_body});
fetchLater("https://a.example.com", {body: a_12kb_body});
```

To make the previous example not throw, the top-level document can delegate some of its quota to `https://fratop.example.com`, for example by serving the following header:

```http
Permissions-Policy: deferred-fetch=(self "https://fratop.example.com")
```

Each nested document reserves its own quota. So the following would work, because each frame reserve 8 kibibytes:

```javascript
// In cross-origin nested document at https://fratop.example.com/frame-1
fetchLater("https://a.example.com", {body: a_6kb_body});

// In cross-origin nested document at https://fratop.example.com/frame-2
fetchLater("https://a.example.com", {body: a_6kb_body});
```

The following tree illustrates how quota is distributed to different nested documents in a tree:

- `https://top.example.com`, with permissions policy set to `Permissions-policy: deferred-fetch=(self "https://ok.example.com")`

  - `https://top.example.com/frame`: shares quota with the top-level traversable, as they are same origin.

    - `https://x.example.com`: receives 8 kibibytes.

  - `https://x.example.com`: receives 8 kibibytes.

    - `https://top.example.com`: 0. Even though it's same origin with the top-level traversable, it does not automatically share its quota as they are separated by a cross-origin intermediary.

  - `https://ok.example.com/good`: receives 64 kibibytes, granted via the "`deferred-fetch`" policy.

    - `https://x.example.com`: receives no quota. Only documents with the same origin as the top-level traversable can grant the 8 kibibytes based on the "`deferred-fetch-minimal`" policy.

  - `https://ok.example.com/redirect`, navigated to `https://x.example.com`: receives no quota. The reserved 64 kibibytes for `https://ok.example.com` are not available for `https://x.example.com`.

  - `https://ok.example.com/back`, navigated to `https://top.example.com`: shares quota with the top-level traversable, as they're same origin.

In the above example, the top-level traversable and its same origin descendants share a quota of 384 kibibytes. That value is computed as such:

- 640 kibibytes are initially granted to the top-level traversable.

- 128 kibibytes are reserved for the "`deferred-fetch-minimal`" policy.

- 64 kibibytes are reserved for the container navigating to `https://ok.example/good`.

- 64 kibibytes are reserved for the container navigating to `https://ok.example/redirect`, and lost when it navigates away.

- `https://ok.example.com/back` did not reserve 64 kibibytes, because it navigated back to top-level traversable's origin.

- 640 − 128 − 64 − 64 = 384 kibibytes.

This specification defines a policy-controlled feature identified by the string "**`deferred-fetch`**". Its default allowlist is "`self`".

This specification defines a policy-controlled feature identified by the string "**`deferred-fetch-minimal`**". Its default allowlist is "`*`".

The **quota reserved for `deferred-fetch-minimal`** is 128 kibibytes.

Each navigable container has an associated number **reserved deferred-fetch quota**. Its possible values are **minimal quota**, which is 8 kibibytes, and **normal quota**, which is 0 or 64 kibibytes. Unless stated otherwise, it is 0.

To get the **available deferred-fetch quota** given a document `document` and an origin-or-null `origin`:

1. Let `controlDocument` be `document`'s deferred-fetch control document.

2. Let `navigable` be `controlDocument`'s node navigable.

3. Let `isTopLevel` be true if `controlDocument`'s node navigable is a top-level traversable; otherwise false.

4. Let `deferredFetchAllowed` be true if `controlDocument` is allowed to use the policy-controlled feature "`deferred-fetch`"; otherwise false.

5. Let `deferredFetchMinimalAllowed` be true if `controlDocument` is allowed to use the policy-controlled feature "`deferred-fetch-minimal`"; otherwise false.

6. Let `quota` be the result of the first matching statement:

   `isTopLevel` is true and `deferredFetchAllowed` is false
   : 0

   `isTopLevel` is true and `deferredFetchMinimalAllowed` is false

   : 640 kibibytes

     640kb should be enough for everyone.

   `isTopLevel` is true

   : 512 kibibytes

     The default of 640 kibibytes, decremented By quota reserved for `deferred-fetch-minimal`)

   `deferredFetchAllowed` is true, and `navigable`'s navigable container's reserved deferred-fetch quota is normal quota
   : normal quota

   `deferredFetchMinimalAllowed` is true, and `navigable`'s navigable container's reserved deferred-fetch quota is minimal quota
   : minimal quota

   Otherwise
   : 0

7. Let `quotaForRequestOrigin` be 64 kibibytes.

8. For each `navigable` in `controlDocument`'s node navigable's inclusive descendant navigables whose active document's deferred-fetch control document is `controlDocument`:

   1. For each `container` in `navigable`'s active document's shadow-including inclusive descendants which is a navigable container, decrement `quota` by `container`'s reserved deferred-fetch quota.

   2. For each deferred fetch record `deferredRecord` of `navigable`'s active document's relevant settings object's fetch group's deferred fetch records:

      1. Let `requestLength` be the total request length of `deferredRecord`'s request.

      2. Decrement `quota` by `requestLength`.

      3. If `deferredRecord`'s request's URL's origin is same origin with `origin`, then decrement `quotaForRequestOrigin` by `requestLength`.

9. If `quota` is equal or less than 0, then return 0.

10. If `quota` is less than `quotaForRequestOrigin`, then return `quota`.

11. Return `quotaForRequestOrigin`.

To **reserve deferred-fetch quota** for a navigable container `container` given an origin `originToNavigateTo`:

This is called on navigation, when the source document of the navigation is the navigable's parent document. It potentially reserves either 64kb or 8kb of quota for the container and its navigable, if allowed by permissions policy. It is not observable to the cotnainer document whether the reserved quota was used in practice. This algorithm assumes that the container's document might delegate quota to the navigated container, and the reserved quota would only apply in that case, and would be ignored if it ends up being shared. If quota was reserved and the document ends up being same origin with its parent, the quota would be freed.

1. Set `container`'s reserved deferred-fetch quota to 0.

2. Let `controlDocument` be `container`'s node document's deferred-fetch control document.

3. If the inherited policy for "`deferred-fetch`", `container` and `originToNavigateTo` is `"Enabled"`, and the available deferred-fetch quota for `controlDocument` is equal or greater than normal quota, then set `container`'s reserved deferred-fetch quota to normal quota and return.

4. If all of the following conditions are true:

   - `controlDocument`'s node navigable is a top-level traversable;

   - the inherited policy for "`deferred-fetch-minimal`", `container` and `originToNavigateTo` is `"Enabled"`; and

   - the size of `controlDocument`'s node navigable's descendant navigables, removing any navigable whose navigable container's reserved deferred-fetch quota is not minimal quota, is less than quota reserved for `deferred-fetch-minimal` / minimal quota,

   then set `container`'s reserved deferred-fetch quota to minimal quota.

To **potentially free deferred-fetch quota** for a document `document`, if `document`'s node navigable's container document is not null, and its origin is same origin with `document`, then set `document`'s node navigable's navigable container's reserved deferred-fetch quota to 0.

This is called when a document is created. It ensures that same-origin nested documents don't reserve quota, as they anyway share their parent quota. It can only be called upon document creation, as the origin of the document is only known after redirects are handled.

To get the **deferred-fetch control document** of a document `document`:

1. If `document`' node navigable's container document is null or a document whose origin is not same origin with `document`, then return `document`; otherwise, return the deferred-fetch control document given `document`'s node navigable's container document.


## Fetch API

The `fetch()` method is relatively low-level API for fetching resources. It covers slightly more ground than `XMLHttpRequest`, although it is currently lacking when it comes to request progression (not response progression).

The `fetch()` method makes it quite straightforward to fetch a resource and extract its contents as a `Blob`:

```javascript
fetch("/music/pk/altes-kamuffel.flac")
  .then(res => res.blob()).then(playBlob)
```

If you just care to log a particular response header:

```javascript
fetch("/", {method:"HEAD"})
  .then(res => log(res.headers.get("strict-transport-security")))
```

If you want to check a particular response header and then process the response of a cross-origin resource:

```javascript
fetch("https://pk.example/berlin-calling.json", {mode:"cors"})
  .then(res => {
    if(res.headers.get("content-type") &&
       res.headers.get("content-type").toLowerCase().indexOf("application/json") >= 0) {
      return res.json()
    } else {
      throw new TypeError()
    }
  }).then(processJSON)
```

If you want to work with URL query parameters:

```javascript
var url = new URL("https://geo.example.org/api"),
    params = {lat:35.696233, long:139.570431}
Object.keys(params).forEach(key => url.searchParams.append(key, params[key]))
fetch(url).then(/* … */)
```

If you want to receive the body data progressively:

```javascript
function consume(reader) {
  var total = 0
  return pump()
  function pump() {
    return reader.read().then(({done, value}) => {
      if (done) {
        return
      }
      total += value.byteLength
      log(`received ${value.byteLength} bytes (${total} bytes in total)`)
      return pump()
    })
  }
}

fetch("/music/pk/altes-kamuffel.flac")
  .then(res => consume(res.body.getReader()))
  .then(() => log("consumed the entire body without keeping the whole thing in memory!"))
  .catch(e => log("something went wrong: " + e))
```


### Headers class

```idl
typedef (sequence<sequence<ByteString>> or record<ByteString, ByteString>) HeadersInit;

[Exposed=(Window,Worker)]
interface Headers {
  constructor(optional HeadersInit init);

  undefined append(ByteString name, ByteString value);
  undefined delete(ByteString name);
  ByteString? get(ByteString name);
  sequence<ByteString> getSetCookie();
  boolean has(ByteString name);
  undefined set(ByteString name, ByteString value);
  iterable<ByteString, ByteString>;
};
```

A `Headers` object has an associated **header list** (a header list), which is initially empty. This can be a pointer to the header list of something else, e.g., of a request as demonstrated by `Request` objects.

A `Headers` object also has an associated **guard**, which is a **headers guard**. A headers guard is "`immutable`", "`request`", "`request-no-cors`", "`response`" or "`none`".

`headers = new Headers([init])`

Creates a new `Headers` object. `init` can be used to fill its internal header list, as per the example below.

```javascript
const meta = { "Content-Type": "text/xml", "Breaking-Bad": "<3" };
new Headers(meta);

// The above is equivalent to
const meta2 = [
  [ "Content-Type", "text/xml" ],
  [ "Breaking-Bad", "<3" ]
];
new Headers(meta2);
```

`headers . append(name, value)`

Appends a header to `headers`.

`headers . delete(name)`

Removes a header from `headers`.

`headers . get(name)`

Returns as a string the values of all headers whose name is `name`, separated by a comma and a space.

`headers . getSetCookie()`

Returns a list of the values for all headers whose name is ``Set-Cookie``.

`headers . has(name)`

Returns whether there is a header whose name is `name`.

`headers . set(name, value)`

Replaces the value of the first header whose name is `name` with `value` and removes any remaining headers whose name is `name`.

`for(const [name, value] of headers)`

`headers` can be iterated over.

To **validate** a header (`name`, `value`) for a `Headers` object `headers`:

1. If `name` is not a header name or `value` is not a header value, then throw a `TypeError`.

2. If `headers`'s guard is "`immutable`", then throw a `TypeError`.

3. If `headers`'s guard is "`request`" and (`name`, `value`) is a forbidden request-header, then return false.

4. If `headers`'s guard is "`response`" and `name` is a forbidden response-header name, then return false.

5. Return true.

Steps for "`request-no-cors`" are not shared as you cannot have a fake value (for `delete()`) that always succeeds in CORS-safelisted request-header.

To **append** a header (`name`, `value`) to a `Headers` object `headers`, run these steps:

1. Normalize `value`.

2. If validating (`name`, `value`) for `headers` returns false, then return.

3. If `headers`'s guard is "`request-no-cors`":

    1. Let `temporaryValue` be the result of getting `name` from `headers`'s header list.

    2. If `temporaryValue` is null, then set `temporaryValue` to `value`.

    3. Otherwise, set `temporaryValue` to `temporaryValue`, followed by 0x2C 0x20, followed by `value`.

    4. If (`name`, `temporaryValue`) is not a no-CORS-safelisted request-header, then return.

4. Append (`name`, `value`) to `headers`'s header list.

5. If `headers`'s guard is "`request-no-cors`", then remove privileged no-CORS request-headers from `headers`.

To **fill** a `Headers` object `headers` with a given object `object`, run these steps:

1. If `object` is a sequence, then for each `header` of `object`:

    1. If `header`'s size is not 2, then throw a `TypeError`.

    2. Append (`header`[0], `header`[1]) to `headers`.

2. Otherwise, `object` is a record, then for each `key` → `value` of `object`, append (`key`, `value`) to `headers`.

To **remove privileged no-CORS request-headers** from a `Headers` object (`headers`), run these steps:

1. For each `headerName` of privileged no-CORS request-header names:

    1. Delete `headerName` from `headers`'s header list.

This is called when headers are modified by unprivileged code.

The `new Headers(init)` constructor steps are:

1. Set this's guard to "`none`".

2. If `init` is given, then fill this with `init`.

The `append(name, value)` method steps are to append (`name`, `value`) to this.

The `delete(name)` method steps are:

1. If validating (`name`, \`\`) for this returns false, then return.

    Passing a dummy header value ought not to have any negative repercussions.

2. If this's guard is "`request-no-cors`", `name` is not a no-CORS-safelisted request-header name, and `name` is not a privileged no-CORS request-header name, then return.

3. If this's header list does not contain `name`, then return.

4. Delete `name` from this's header list.

5. If this's guard is "`request-no-cors`", then remove privileged no-CORS request-headers from this.

The `get(name)` method steps are:

1. If `name` is not a header name, then throw a `TypeError`.

2. Return the result of getting `name` from this's header list.

The `getSetCookie()` method steps are:

1. If this's header list does not contain ``Set-Cookie``, then return « ».

2. Return the values of all headers in this's header list whose name is a byte-case-insensitive match for ``Set-Cookie``, in order.

The `has(name)` method steps are:

1. If `name` is not a header name, then throw a `TypeError`.

2. Return true if this's header list contains `name`; otherwise false.

The `set(name, value)` method steps are:

1. Normalize `value`.

2. If validating (`name`, `value`) for this returns false, then return.

3. If this's guard is "`request-no-cors`" and (`name`, `value`) is not a no-CORS-safelisted request-header, then return.

4. Set (`name`, `value`) in this's header list.

5. If this's guard is "`request-no-cors`", then remove privileged no-CORS request-headers from this.

The value pairs to iterate over are the return value of running sort and combine with this's header list.


### BodyInit unions

```idl
typedef (Blob or BufferSource or FormData or URLSearchParams or USVString) XMLHttpRequestBodyInit;

typedef (ReadableStream or XMLHttpRequestBodyInit) BodyInit;
```

To **safely extract** a body with type from a byte sequence or `BodyInit` object `object`, run these steps:

1. If `object` is a `ReadableStream` object, then:

    1. Assert: `object` is neither disturbed nor locked.

2. Return the result of extracting `object`.

The safely extract operation is a subset of the extract operation that is guaranteed to not throw an exception.

To **extract** a body with type from a byte sequence or `BodyInit` object `object`, with an optional boolean **keepalive** (default false), run these steps:

1. Let `stream` be null.

2. If `object` is a `ReadableStream` object, then set `stream` to `object`.

3. Otherwise, if `object` is a `Blob` object, set `stream` to the result of running `object`'s get stream.

4. Otherwise, set `stream` to a new `ReadableStream` object, and set up `stream` with byte reading support.

5. Assert: `stream` is a `ReadableStream` object.

6. Let `action` be null.

7. Let `source` be null.

8. Let `length` be null.

9. Let `type` be null.

10. Switch on `object`:

    `Blob`
    
    Set `source` to `object`.
    
    Set `length` to `object`'s `size`.
    
    If `object`'s `type` attribute is not the empty byte sequence, set `type` to its value.

    byte sequence
    
    Set `source` to `object`.

    `BufferSource`
    
    Set `source` to a copy of the bytes held by `object`.

    `FormData`
    
    Set `action` to this step: run the `multipart/form-data` encoding algorithm, with `object`'s entry list and UTF-8.
    
    Set `source` to `object`.
    
    Set `length` to [unclear, see html/6424 for improving this].
    
    Set `type` to ``multipart/form-data; boundary=``, followed by the `multipart/form-data` boundary string generated by the `multipart/form-data` encoding algorithm.

    `URLSearchParams`
    
    Set `source` to the result of running the `application/x-www-form-urlencoded` serializer with `object`'s list.
    
    Set `type` to ``application/x-www-form-urlencoded;charset=UTF-8``.

    scalar value string
    
    Set `source` to the UTF-8 encoding of `object`.
    
    Set `type` to ``text/plain;charset=UTF-8``.

    `ReadableStream`
    
    If `keepalive` is true, then throw a `TypeError`.
    
    If `object` is disturbed or locked, then throw a `TypeError`.

11. If `source` is a byte sequence, then set `action` to a step that returns `source` and `length` to `source`'s length.

12. If `action` is non-null, then run these steps in parallel:

    1. Run `action`.
    
        Whenever one or more bytes are available and `stream` is not errored, enqueue the result of creating a `Uint8Array` from the available bytes into `stream`.
    
        When running `action` is done, close `stream`.

13. Let `body` be a body whose stream is `stream`, source is `source`, and length is `length`.

14. Return (`body`, `type`).


### Body mixin

```idl
interface mixin Body {
  readonly attribute ReadableStream? body;
  readonly attribute boolean bodyUsed;
  [NewObject] Promise<ArrayBuffer> arrayBuffer();
  [NewObject] Promise<Blob> blob();
  [NewObject] Promise<Uint8Array> bytes();
  [NewObject] Promise<FormData> formData();
  [NewObject] Promise<any> json();
  [NewObject] Promise<USVString> text();
};
```

Formats you would not want a network layer to be dependent upon, such as HTML, will likely not be exposed here. Rather, an HTML parser API might accept a stream in due course.

Objects including the `Body` interface mixin have an associated **body** (null or a body).

An object including the `Body` interface mixin is said to be **unusable** if its body is non-null and its body's stream is disturbed or locked.

`requestOrResponse . body`

Returns `requestOrResponse`'s body as `ReadableStream`.

`requestOrResponse . bodyUsed`

Returns whether `requestOrResponse`'s body has been read from.

`requestOrResponse . arrayBuffer()`

Returns a promise fulfilled with `requestOrResponse`'s body as `ArrayBuffer`.

`requestOrResponse . blob()`

Returns a promise fulfilled with `requestOrResponse`'s body as `Blob`.

`requestOrResponse . bytes()`

Returns a promise fulfilled with `requestOrResponse`'s body as `Uint8Array`.

`requestOrResponse . formData()`

Returns a promise fulfilled with `requestOrResponse`'s body as `FormData`.

`requestOrResponse . json()`

Returns a promise fulfilled with `requestOrResponse`'s body parsed as JSON.

`requestOrResponse . text()`

Returns a promise fulfilled with `requestOrResponse`'s body as string.

To **get the MIME type**, given a `Request` or `Response` object `requestOrResponse`:

1. Let `headers` be null.

2. If `requestOrResponse` is a `Request` object, then set `headers` to `requestOrResponse`'s request's header list.

3. Otherwise, set `headers` to `requestOrResponse`'s response's header list.

4. Let `mimeType` be the result of extracting a MIME type from `headers`.

5. If `mimeType` is failure, then return null.

6. Return `mimeType`.

The `body` getter steps are to return null if this's body is null; otherwise this's body's stream.

The `bodyUsed` getter steps are to return true if this's body is non-null and this's body's stream is disturbed; otherwise false.

The **consume body** algorithm, given an object that includes `Body` `object` and an algorithm that takes a byte sequence and returns a JavaScript value or throws an exception `convertBytesToJSValue`, runs these steps:

1. If `object` is unusable, then return a promise rejected with a `TypeError`.

2. Let `promise` be a new promise.

3. Let `errorSteps` given `error` be to reject `promise` with `error`.

4. Let `successSteps` given a byte sequence `data` be to resolve `promise` with the result of running `convertBytesToJSValue` with `data`. If that threw an exception, then run `errorSteps` with that exception.

5. If `object`'s body is null, then run `successSteps` with an empty byte sequence.

6. Otherwise, fully read `object`'s body given `successSteps`, `errorSteps`, and `object`'s relevant global object.

7. Return `promise`.

The `arrayBuffer()` method steps are to return the result of running consume body with this and the following step given a byte sequence `bytes`: return the result of creating an `ArrayBuffer` from `bytes` in this's relevant realm.

The above method can reject with a `RangeError`.

The `blob()` method steps are to return the result of running consume body with this and the following step given a byte sequence `bytes`: return a `Blob` whose contents are `bytes` and whose `type` attribute is the result of get the MIME type with this.

The `bytes()` method steps are to return the result of running consume body with this and the following step given a byte sequence `bytes`: return the result of creating a `Uint8Array` from `bytes` in this's relevant realm.

The above method can reject with a `RangeError`.

The `formData()` method steps are to return the result of running consume body with this and the following steps given a byte sequence `bytes`:

1. Let `mimeType` be the result of get the MIME type with this.

2. If `mimeType` is non-null, then switch on `mimeType`'s essence and run the corresponding steps:

    "`multipart/form-data`"
    
    1. Parse `bytes`, using the value of the ``boundary`` parameter from `mimeType`, per the rules set forth in Returning Values from Forms: multipart/form-data.
    
        Each part whose ``Content-Disposition`` header contains a ``filename`` parameter must be parsed into an entry whose value is a `File` object whose contents are the contents of the part. The `name` attribute of the `File` object must have the value of the ``filename`` parameter of the part. The `type` attribute of the `File` object must have the value of the ``Content-Type`` header of the part if the part has such header, and ``text/plain`` (the default defined by [RFC7578] section 4.4) otherwise.
    
        Each part whose ``Content-Disposition`` header does not contain a ``filename`` parameter must be parsed into an entry whose value is the UTF-8 decoded without BOM content of the part. This is done regardless of the presence or the value of a ``Content-Type`` header and regardless of the presence or the value of a ``charset`` parameter.
    
        A part whose ``Content-Disposition`` header contains a ``name`` parameter whose value is ``_charset_`` is parsed like any other part. It does not change the encoding.
    
    2. If that fails for some reason, then throw a `TypeError`.
    
    3. Return a new `FormData` object, appending each entry, resulting from the parsing operation, to its entry list.
    
    The above is a rough approximation of what is needed for ``multipart/form-data``, a more detailed parsing specification is to be written. Volunteers welcome.

    "`application/x-www-form-urlencoded`"
    
    1. Let `entries` be the result of parsing `bytes`.
    
    2. Return a new `FormData` object whose entry list is `entries`.

3. Throw a `TypeError`.

The `json()` method steps are to return the result of running consume body with this and parse JSON from bytes.

The above method can reject with a `SyntaxError`.

The `text()` method steps are to return the result of running consume body with this and UTF-8 decode.


### Request class

```idl
typedef (Request or USVString) RequestInfo;

[Exposed=(Window,Worker)]
interface Request {
  constructor(RequestInfo input, optional RequestInit init = {});

  readonly attribute ByteString method;
  readonly attribute USVString url;
  [SameObject] readonly attribute Headers headers;

  readonly attribute RequestDestination destination;
  readonly attribute USVString referrer;
  readonly attribute ReferrerPolicy referrerPolicy;
  readonly attribute RequestMode mode;
  readonly attribute RequestCredentials credentials;
  readonly attribute RequestCache cache;
  readonly attribute RequestRedirect redirect;
  readonly attribute DOMString integrity;
  readonly attribute boolean keepalive;
  readonly attribute boolean isReloadNavigation;
  readonly attribute boolean isHistoryNavigation;
  readonly attribute AbortSignal signal;
  readonly attribute RequestDuplex duplex;

  [NewObject] Request clone();
};
Request includes Body;

dictionary RequestInit {
  ByteString method;
  HeadersInit headers;
  BodyInit? body;
  USVString referrer;
  ReferrerPolicy referrerPolicy;
  RequestMode mode;
  RequestCredentials credentials;
  RequestCache cache;
  RequestRedirect redirect;
  DOMString integrity;
  boolean keepalive;
  AbortSignal? signal;
  RequestDuplex duplex;
  RequestPriority priority;
  any window; // can only be set to null
};

enum RequestDestination { "", "audio", "audioworklet", "document", "embed", "font", "frame", "iframe", "image", "json", "manifest", "object", "paintworklet", "report", "script", "sharedworker", "style",  "track", "video", "worker", "xslt" };
enum RequestMode { "navigate", "same-origin", "no-cors", "cors" };
enum RequestCredentials { "omit", "same-origin", "include" };
enum RequestCache { "default", "no-store", "reload", "no-cache", "force-cache", "only-if-cached" };
enum RequestRedirect { "follow", "error", "manual" };
enum RequestDuplex { "half" };
enum RequestPriority { "high", "low", "auto" };
```

"`serviceworker`" is omitted from `RequestDestination` as it cannot be observed from JavaScript. Implementations will still need to support it as a destination. "`websocket`" is omitted from `RequestMode` as it cannot be used nor observed from JavaScript.

A `Request` object has an associated **request** (a request).

A `Request` object also has an associated **headers** (null or a `Headers` object), initially null.

A `Request` object has an associated **signal** (null or an `AbortSignal` object), initially null.

A `Request` object's body is its request's body.

`request = new Request(input [, init])`

Returns a new `request` whose `url` property is `input` if `input` is a string, and `input`'s `url` if `input` is a `Request` object.

The `init` argument is an object whose properties can be set as follows:

`method`

A string to set `request`'s `method`.

`headers`

A `Headers` object, an object literal, or an array of two-item arrays to set `request`'s `headers`.

`body`

A `BodyInit` object or null to set `request`'s body.

`referrer`

A string whose value is a same-origin URL, "`about:client`", or the empty string, to set `request`'s referrer.

`referrerPolicy`

A referrer policy to set `request`'s `referrerPolicy`.

`mode`

A string to indicate whether the request will use CORS, or will be restricted to same-origin URLs. Sets `request`'s `mode`. If `input` is a string, it defaults to "`cors`".

`credentials`

A string indicating whether credentials will be sent with the request always, never, or only when sent to a same-origin URL --- as well as whether any credentials sent back in the response will be used always, never, or only when received from a same-origin URL. Sets `request`'s `credentials`. If `input` is a string, it defaults to "`same-origin`".

`cache`

A string indicating how the request will interact with the browser's cache to set `request`'s `cache`.

`redirect`

A string indicating whether `request` follows redirects, results in an error upon encountering a redirect, or returns the redirect (in an opaque fashion). Sets `request`'s `redirect`.

`integrity`

A cryptographic hash of the resource to be fetched by `request`. Sets `request`'s `integrity`.

`keepalive`

A boolean to set `request`'s `keepalive`.

`signal`

An `AbortSignal` to set `request`'s `signal`.

`window`

Can only be null. Used to disassociate `request` from any `Window`.

`duplex`

"`half`" is the only valid value and it is for initiating a half-duplex fetch (i.e., the user agent sends the entire request before processing the response). "`full`" is reserved for future use, for initiating a full-duplex fetch (i.e., the user agent can process the response before sending the entire request). This member needs to be set when `body` is a `ReadableStream` object. See issue #1254 for defining "`full`".

`priority`

A string to set `request`'s priority.

`request . method`

Returns `request`'s HTTP method, which is "`GET`" by default.

`request . url`

Returns the URL of `request` as a string.

`request . headers`

Returns a `Headers` object consisting of the headers associated with `request`. Note that headers added in the network layer by the user agent will not be accounted for in this object, e.g., the "`Host`" header.

`request . destination`

Returns the kind of resource requested by `request`, e.g., "`document`" or "`script`".

`request . referrer`

Returns the referrer of `request`. Its value can be a same-origin URL if explicitly set in `init`, the empty string to indicate no referrer, and "`about:client`" when defaulting to the global's default. This is used during fetching to determine the value of the ``Referer`` header of the request being made.

`request . referrerPolicy`

Returns the referrer policy associated with `request`. This is used during fetching to compute the value of the `request`'s referrer.

`request . mode`

Returns the mode associated with `request`, which is a string indicating whether the request will use CORS, or will be restricted to same-origin URLs.

`request . credentials`

Returns the credentials mode associated with `request`, which is a string indicating whether credentials will be sent with the request always, never, or only when sent to a same-origin URL.

`request . cache`

Returns the cache mode associated with `request`, which is a string indicating how the request will interact with the browser's cache when fetching.

`request . redirect`

Returns the redirect mode associated with `request`, which is a string indicating how redirects for the request will be handled during fetching. A request will follow redirects by default.

`request . integrity`

Returns `request`'s subresource integrity metadata, which is a cryptographic hash of the resource being fetched. Its value consists of multiple hashes separated by whitespace. [SRI]

`request . keepalive`

Returns a boolean indicating whether or not `request` can outlive the global in which it was created.

`request . isReloadNavigation`

Returns a boolean indicating whether or not `request` is for a reload navigation.

`request . isHistoryNavigation`

Returns a boolean indicating whether or not `request` is for a history navigation (a.k.a. back-foward navigation).

`request . signal`

Returns the signal associated with `request`, which is an `AbortSignal` object indicating whether or not `request` has been aborted, and its abort event handler.

`request . duplex`

Returns "`half`", meaning the fetch will be half-duplex (i.e., the user agent sends the entire request before processing the response). In future, it could also return "`full`", meaning the fetch will be full-duplex (i.e., the user agent can process the response before sending the entire request) to indicate that the fetch will be full-duplex. See issue #1254 for defining "`full`".

`request . clone()`

Returns a clone of `request`.

To **create** a `Request` object, given a request `request`, headers guard `guard`, `AbortSignal` object `signal`, and realm `realm`:

1. Let `requestObject` be a new `Request` object with `realm`.

2. Set `requestObject`'s request to `request`.

3. Set `requestObject`'s headers to a new `Headers` object with `realm`, whose headers list is `request`'s headers list and guard is `guard`.

4. Set `requestObject`'s signal to `signal`.

5. Return `requestObject`.

The `new Request(input, init)` constructor steps are:

1. Let `request` be null.

2. Let `fallbackMode` be null.

3. Let `baseURL` be this's relevant settings object's API base URL.

4. Let `signal` be null.

5. If `input` is a string, then:

    1. Let `parsedURL` be the result of parsing `input` with `baseURL`.

    2. If `parsedURL` is failure, then throw a `TypeError`.

    3. If `parsedURL` includes credentials, then throw a `TypeError`.

    4. Set `request` to a new request whose URL is `parsedURL`.

    5. Set `fallbackMode` to "`cors`".

6. Otherwise:

    1. Assert: `input` is a `Request` object.

    2. Set `request` to `input`'s request.

    3. Set `signal` to `input`'s signal.

7. Let `origin` be this's relevant settings object's origin.

8. Let `traversableForUserPrompts` be "`client`".

9. If `request`'s traversable for user prompts is an environment settings object and its origin is same origin with `origin`, then set `traversableForUserPrompts` to `request`'s traversable for user prompts.

10. If `init`["`window`"] exists and is non-null, then throw a `TypeError`.

11. If `init`["`window`"] exists, then set `traversableForUserPrompts` to "`no-traversable`".

12. Set `request` to a new request with the following properties:

    URL
    
    `request`'s URL.

    method
    
    `request`'s method.

    header list
    
    A copy of `request`'s header list.

    unsafe-request flag
    
    Set.

    client
    
    This's relevant settings object.

    traversable for user prompts
    
    `traversableForUserPrompts`.

    internal priority
    
    `request`'s internal priority.

    origin
    
    `request`'s origin. The propagation of the origin is only significant for navigation requests being handled by a service worker. In this scenario a request can have an origin that is different from the current client.

    referrer
    
    `request`'s referrer.

    referrer policy
    
    `request`'s referrer policy.

    mode
    
    `request`'s mode.

    credentials mode
    
    `request`'s credentials mode.

    cache mode
    
    `request`'s cache mode.

    redirect mode
    
    `request`'s redirect mode.

    integrity metadata
    
    `request`'s integrity metadata.

    keepalive
    
    `request`'s keepalive.

    reload-navigation flag
    
    `request`'s reload-navigation flag.

    history-navigation flag
    
    `request`'s history-navigation flag.

    URL list
    
    A clone of `request`'s URL list.

    initiator type
    
    "`fetch`".

13. If `init` is not empty, then:

    1. If `request`'s mode is "`navigate`", then set it to "`same-origin`".

    2. Unset `request`'s reload-navigation flag.

    3. Unset `request`'s history-navigation flag.

    4. Set `request`'s origin to "`client`".

    5. Set `request`'s referrer to "`client`".

    6. Set `request`'s referrer policy to the empty string.

    7. Set `request`'s URL to `request`'s current URL.

    8. Set `request`'s URL list to « `request`'s URL ».

    This is done to ensure that when a service worker "redirects" a request, e.g., from an image in a cross-origin style sheet, and makes modifications, it no longer appears to come from the original source (i.e., the cross-origin style sheet), but instead from the service worker that "redirected" the request. This is important as the original source might not even be able to generate the same kind of requests as the service worker. Services that trust the original source could therefore be exploited were this not done, although that is somewhat farfetched.

14. If `init`["`referrer`"] exists, then:

    1. Let `referrer` be `init`["`referrer`"].

    2. If `referrer` is the empty string, then set `request`'s referrer to "`no-referrer`".

    3. Otherwise:

        1. Let `parsedReferrer` be the result of parsing `referrer` with `baseURL`.

        2. If `parsedReferrer` is failure, then throw a `TypeError`.

        3. If one of the following is true

            - `parsedReferrer`'s scheme is "`about`" and path is the string "`client`"

            - `parsedReferrer`'s origin is not same origin with `origin`

            then set `request`'s referrer to "`client`".

        4. Otherwise, set `request`'s referrer to `parsedReferrer`.

15. If `init`["`referrerPolicy`"] exists, then set `request`'s referrer policy to it.

16. Let `mode` be `init`["`mode`"] if it exists, and `fallbackMode` otherwise.

17. If `mode` is "`navigate`", then throw a `TypeError`.

18. If `mode` is non-null, set `request`'s mode to `mode`.

19. If `init`["`credentials`"] exists, then set `request`'s credentials mode to it.

20. If `init`["`cache`"] exists, then set `request`'s cache mode to it.

21. If `request`'s cache mode is "`only-if-cached`" and `request`'s mode is *not* "`same-origin`", then throw a `TypeError`.

22. If `init`["`redirect`"] exists, then set `request`'s redirect mode to it.

23. If `init`["`integrity`"] exists, then set `request`'s integrity metadata to it.

24. If `init`["`keepalive`"] exists, then set `request`'s keepalive to it.

25. If `init`["`method`"] exists, then:

    1. Let `method` be `init`["`method`"].

    2. If `method` is not a method or `method` is a forbidden method, then throw a `TypeError`.

    3. Normalize `method`.

    4. Set `request`'s method to `method`.

26. If `init`["`signal`"] exists, then set `signal` to it.

27. If `init`["`priority`"] exists, then:

    1. If `request`'s internal priority is not null, then update `request`'s internal priority in an implementation-defined manner.

    2. Otherwise, set `request`'s priority to `init`["`priority`"].

28. Set this's request to `request`.

29. Let `signals` be « `signal` » if `signal` is non-null; otherwise « ».

30. Set this's signal to the result of creating a dependent abort signal from `signals`, using `AbortSignal` and this's relevant realm.

31. Set this's headers to a new `Headers` object with this's relevant realm, whose header list is `request`'s header list and guard is "`request`".

32. If this's request's mode is "`no-cors`", then:

    1. If this's request's method is not a CORS-safelisted method, then throw a `TypeError`.

    2. Set this's headers's guard to "`request-no-cors`".

33. If `init` is not empty, then:

    The headers are sanitized as they might contain headers that are not allowed by this mode. Otherwise, they were previously sanitized or are unmodified since they were set by a privileged API.

    1. Let `headers` be a copy of this's headers and its associated header list.

    2. If `init`["`headers`"] exists, then set `headers` to `init`["`headers`"].

    3. Empty this's headers's header list.

    4. If `headers` is a `Headers` object, then for each `header` of its header list, append `header` to this's headers.

    5. Otherwise, fill this's headers with `headers`.

34. Let `inputBody` be `input`'s request's body if `input` is a `Request` object; otherwise null.

35. If either `init`["`body`"] exists and is non-null or `inputBody` is non-null, and `request`'s method is ``GET`` or ``HEAD``, then throw a `TypeError`.

36. Let `initBody` be null.

37. If `init`["`body`"] exists and is non-null, then:

    1. Let `bodyWithType` be the result of extracting `init`["`body`"], with *keepalive* set to `request`'s keepalive.

    2. Set `initBody` to `bodyWithType`'s body.

    3. Let `type` be `bodyWithType`'s type.

    4. If `type` is non-null and this's headers's header list does not contain ``Content-Type``, then append (``Content-Type``, `type`) to this's headers.

38. Let `inputOrInitBody` be `initBody` if it is non-null; otherwise `inputBody`.

39. If `inputOrInitBody` is non-null and `inputOrInitBody`'s source is null, then:

    1. If `initBody` is non-null and `init`["`duplex`"] does not exist, then throw a `TypeError`.

    2. If this's request's mode is neither "`same-origin`" nor "`cors`", then throw a `TypeError`.

    3. Set this's request's use-CORS-preflight flag.

40. Let `finalBody` be `inputOrInitBody`.

41. If `initBody` is null and `inputBody` is non-null, then:

    1. If `inputBody` is unusable, then throw a `TypeError`.

    2. Set `finalBody` to the result of creating a proxy for `inputBody`.

42. Set this's request's body to `finalBody`.

The `method` getter steps are to return this's request's method.

The `url` getter steps are to return this's request's URL, serialized.

The `headers` getter steps are to return this's headers.

The `destination` getter are to return this's request's destination.

The `referrer` getter steps are:

1. If this's request's referrer is "`no-referrer`", then return the empty string.

2. If this's request's referrer is "`client`", then return "`about:client`".

3. Return this's request's referrer, serialized.

The `referrerPolicy` getter steps are to return this's request's referrer policy.

The `mode` getter steps are to return this's request's mode.

The `credentials` getter steps are to return this's request's credentials mode.

The `cache` getter steps are to return this's request's cache mode.

The `redirect` getter steps are to return this's request's redirect mode.

The `integrity` getter steps are to return this's request's integrity metadata.

The `keepalive` getter steps are to return this's request's keepalive.

The `isReloadNavigation` getter steps are to return true if this's request's reload-navigation flag is set; otherwise false.

The `isHistoryNavigation` getter steps are to return true if this's request's history-navigation flag is set; otherwise false.

The `signal` getter steps are to return this's signal.

This's signal is always initialized in the constructor and when cloning.

The `duplex` getter steps are to return "`half`".

The `clone()` method steps are:

1. If this is unusable, then throw a `TypeError`.

2. Let `clonedRequest` be the result of cloning this's request.

3. Assert: this's signal is non-null.

4. Let `clonedSignal` be the result of creating a dependent abort signal from « this's signal », using `AbortSignal` and this's relevant realm.

5. Let `clonedRequestObject` be the result of creating a `Request` object, given `clonedRequest`, this's headers's guard, `clonedSignal` and this's relevant realm.

6. Return `clonedRequestObject`.


### Response class

```idl
[Exposed=(Window,Worker)]
interface Response {
  constructor(optional BodyInit? body = null, optional ResponseInit init = {});

  [NewObject] static Response error();
  [NewObject] static Response redirect(USVString url, optional unsigned short status = 302);
  [NewObject] static Response json(any data, optional ResponseInit init = {});

  readonly attribute ResponseType type;

  readonly attribute USVString url;
  readonly attribute boolean redirected;
  readonly attribute unsigned short status;
  readonly attribute boolean ok;
  readonly attribute ByteString statusText;
  [SameObject] readonly attribute Headers headers;

  [NewObject] Response clone();
};
Response includes Body;

dictionary ResponseInit {
  unsigned short status = 200;
  ByteString statusText = "";
  HeadersInit headers;
};

enum ResponseType { "basic", "cors", "default", "error", "opaque", "opaqueredirect" };
```

A `Response` object has an associated **response** (a response).

A `Response` object also has an associated **headers** (null or a `Headers` object), initially null.

A `Response` object's body is its response's body.

`response = new Response(body = null [, init])`

Creates a `Response` whose body is `body`, and status, status message, and headers are provided by `init`.

`response = Response . error()`

Creates network error `Response`.

`response = Response . redirect(url, status = 302)`

Creates a redirect `Response` that redirects to `url` with status `status`.

`response = Response . json(data [, init])`

Creates a `Response` whose body is the JSON-encoded `data`, and status, status message, and headers are provided by `init`.

`response . type`

Returns `response`'s type, e.g., "`cors`".

`response . url`

Returns `response`'s URL, if it has one; otherwise the empty string.

`response . redirected`

Returns whether `response` was obtained through a redirect.

`response . status`

Returns `response`'s status.

`response . ok`

Returns whether `response`'s status is an ok status.

`response . statusText`

Returns `response`'s status message.

`response . headers`

Returns `response`'s headers as `Headers`.

`response . clone()`

Returns a clone of `response`.

To **create** a `Response` object, given a response `response`, headers guard `guard`, and realm `realm`, run these steps:

1. Let `responseObject` be a new `Response` object with `realm`.

2. Set `responseObject`'s response to `response`.

3. Set `responseObject`'s headers to a new `Headers` object with `realm`, whose headers list is `response`'s headers list and guard is `guard`.

4. Return `responseObject`.

To **initialize a response**, given a `Response` object `response`, `ResponseInit` `init`, and null or a body with type `body`:

1. If `init`["`status`"] is not in the range 200 to 599, inclusive, then throw a `RangeError`.

2. If `init`["`statusText`"] is not the empty string and does not match the reason-phrase token production, then throw a `TypeError`.

3. Set `response`'s response's status to `init`["`status`"].

4. Set `response`'s response's status message to `init`["`statusText`"].

5. If `init`["`headers`"] exists, then fill `response`'s headers with `init`["`headers`"].

6. If `body` is non-null, then:

    1. If `response`'s status is a null body status, then throw a `TypeError`.

        101 and 103 are included in null body status due to their use elsewhere. They do not affect this step.

    2. Set `response`'s body to `body`'s body.

    3. If `body`'s type is non-null and `response`'s header list does not contain ``Content-Type``, then append (``Content-Type``, `body`'s type) to `response`'s header list.

The `new Response(body, init)` constructor steps are:

1. Set this's response to a new response.

2. Set this's headers to a new `Headers` object with this's relevant realm, whose header list is this's response's header list and guard is "`response`".

3. Let `bodyWithType` be null.

4. If `body` is non-null, then set `bodyWithType` to the result of extracting `body`.

5. Perform initialize a response given this, `init`, and `bodyWithType`.

The static `error()` method steps are to return the result of creating a `Response` object, given a new network error, "`immutable`", and the current realm.

The static `redirect(url, status)` method steps are:

1. Let `parsedURL` be the result of parsing `url` with current settings object's API base URL.

2. If `parsedURL` is failure, then throw a `TypeError`.

3. If `status` is not a redirect status, then throw a `RangeError`.

4. Let `responseObject` be the result of creating a `Response` object, given a new response, "`immutable`", and the current realm.

5. Set `responseObject`'s response's status to `status`.

6. Let `value` be `parsedURL`, serialized and isomorphic encoded.

7. Append (``Location``, `value`) to `responseObject`'s response's header list.

8. Return `responseObject`.

The static `json(data, init)` method steps are:

1. Let `bytes` the result of running serialize a JavaScript value to JSON bytes on `data`.

2. Let `body` be the result of extracting `bytes`.

3. Let `responseObject` be the result of creating a `Response` object, given a new response, "`response`", and the current realm.

4. Perform initialize a response given `responseObject`, `init`, and (`body`, "`application/json`").

5. Return `responseObject`.

The `type` getter steps are to return this's response's type.

The `url` getter steps are to return the empty string if this's response's URL is null; otherwise this's response's URL, serialized with *exclude fragment* set to true.

The `redirected` getter steps are to return true if this's response's URL list's size is greater than 1; otherwise false.

To filter out responses that are the result of a redirect, do this directly through the API, e.g., `fetch(url, { redirect:"error" })`. This way a potentially unsafe response cannot accidentally leak.

The `status` getter steps are to return this's response's status.

The `ok` getter steps are to return true if this's response's status is an ok status; otherwise false.

The `statusText` getter steps are to return this's response's status message.

The `headers` getter steps are to return this's headers.

The `clone()` method steps are:

1. If this is unusable, then throw a `TypeError`.

2. Let `clonedResponse` be the result of cloning this's response.

3. Return the result of creating a `Response` object, given `clonedResponse`, this's headers's guard, and this's relevant realm.


### Fetch methods

```idl
partial interface mixin WindowOrWorkerGlobalScope {
  [NewObject] Promise<Response> fetch(RequestInfo input, optional RequestInit init = {});
};

dictionary DeferredRequestInit : RequestInit {
  DOMHighResTimeStamp activateAfter;
};

[Exposed=Window]
interface FetchLaterResult {
  readonly attribute boolean activated;
};

partial interface Window {
  [NewObject, SecureContext] FetchLaterResult fetchLater(RequestInfo input, optional DeferredRequestInit init = {});
};
```

The `fetch(input, init)` method steps are:

1. Let `p` be a new promise.

2. Let `requestObject` be the result of invoking the initial value of `Request` as constructor with `input` and `init` as arguments. If this throws an exception, reject `p` with it and return `p`.

3. Let `request` be `requestObject`'s request.

4. If `requestObject`'s signal is aborted, then:

    1. Abort the `fetch()` call with `p`, `request`, null, and `requestObject`'s signal's abort reason.

    2. Return `p`.

5. Let `globalObject` be `request`'s client's global object.

6. If `globalObject` is a `ServiceWorkerGlobalScope` object, then set `request`'s service-workers mode to "`none`".

7. Let `responseObject` be null.

8. Let `relevantRealm` be this's relevant realm.

9. Let `locallyAborted` be false.

    This lets us reject promises with predictable timing, when the request to abort comes from the same thread as the call to fetch.

10. Let `controller` be null.

11. Add the following abort steps to `requestObject`'s signal:

    1. Set `locallyAborted` to true.

    2. Assert: `controller` is non-null.

    3. Abort `controller` with `requestObject`'s signal's abort reason.

    4. Abort the `fetch()` call with `p`, `request`, `responseObject`, and `requestObject`'s signal's abort reason.

12. Set `controller` to the result of calling fetch given `request` and *processResponse* given `response` being these steps:

    1. If `locallyAborted` is true, then abort these steps.

    2. If `response`'s aborted flag is set, then:

        1. Let `deserializedError` be the result of deserialize a serialized abort reason given `controller`'s serialized abort reason and `relevantRealm`.

        2. Abort the `fetch()` call with `p`, `request`, `responseObject`, and `deserializedError`.

        3. Abort these steps.

    3. If `response` is a network error, then reject `p` with a `TypeError` and abort these steps.

    4. Set `responseObject` to the result of creating a `Response` object, given `response`, "`immutable`", and `relevantRealm`.

    5. Resolve `p` with `responseObject`.

13. Return `p`.

To **abort a `fetch()` call** with a `promise`, `request`, `responseObject`, and an `error`:

1. Reject `promise` with `error`.

    This is a no-op if `promise` has already fulfilled.

2. If `request`'s body is non-null and is readable, then cancel `request`'s body with `error`.

3. If `responseObject` is null, then return.

4. Let `response` be `responseObject`'s response.

5. If `response`'s body is non-null and is readable, then error `response`'s body with `error`.

A `FetchLaterResult` has an associated **activated getter steps**, which is an algorithm returning a boolean.

The `activated` getter steps are to return the result of running this's activated getter steps.

The `fetchLater(input, init)` method steps are:

1. Let `requestObject` be the result of invoking the initial value of `Request` as constructor with `input` and `init` as arguments.

2. If `requestObject`'s signal is aborted, then throw signal's abort reason.

3. Let `request` be `requestObject`'s request.

4. Let `activateAfter` be null.

5. If `init` is given and `init`["`activateAfter`"] exists, then set `activateAfter` to `init`["`activateAfter`"].

6. If `activateAfter` is less than 0, then throw a `RangeError`.

7. If this's relevant global object's associated document is not fully active, then throw a `TypeError`.

8. If `request`'s URL's scheme is not an HTTP(S) scheme, then throw a `TypeError`.

9. If `request`'s URL is not a potentially trustworthy URL, then throw a `TypeError`.

10. If `request`'s body is not null, and `request`'s body length is null, then throw a `TypeError`.

    Requests whose body is a `ReadableStream` object cannot be deferred.

11. If the available deferred-fetch quota given `request`'s client and `request`'s URL's origin is less than `request`'s total request length, then throw a "`QuotaExceededError`" `DOMException`.

12. Let `activated` be false.

13. Let `deferredRecord` be the result of calling queue a deferred fetch given `request`, `activateAfter`, and the following step: set `activated` to true.

14. Add the following abort steps to `requestObject`'s signal: Set `deferredRecord`'s invoke state to "`aborted`".

15. Return a new `FetchLaterResult` whose activated getter steps are to return `activated`.

The following call would queue a request to be fetched when the document is terminated:

```javascript
fetchLater("https://report.example.com", {
  method: "POST",
  body: JSON.stringify(myReport),
  headers: { "Content-Type": "application/json" }
})
```

The following call would also queue this request after 5 seconds, and the returned value would allow callers to observe if it was indeed activated. Note that the request is guaranteed to be invoked, even in cases where the user agent throttles timers.

```javascript
const result = fetchLater("https://report.example.com", {
  method: "POST",
  body: JSON.stringify(myReport),
  headers: { "Content-Type": "application/json" },
  activateAfter: 5000
});

function check_if_fetched() {
  return result.activated;
}
```

The `FetchLaterResult` object can be used together with an `AbortSignal`. For example:

```javascript
let accumulated_events = [];
let previous_result = null;
const abort_signal = new AbortSignal();
function accumulate_event(event) {
  if (previous_result) {
    if (previous_result.activated) {
      // The request is already activated, we can start from scratch.
      accumulated_events = [];
    } else {
      // Abort this request, and start a new one with all the events.
      signal.abort();
    }
  }

  accumulated_events.push(event);
  result = fetchLater("https://report.example.com", {
    method: "POST",
    body: JSON.stringify(accumulated_events),
    headers: { "Content-Type": "application/json" },
    activateAfter: 5000,
    abort_signal
  });
}
```

Any of the following calls to `fetchLater()` would throw:

```javascript
// Only potentially trustworthy URLs are supported.
fetchLater("http://untrusted.example.com");

// The length of the deferred request has to be known when.
fetchLater("https://origin.example.com", {body: someDynamicStream});

// Deferred fetching only works on active windows.
const detachedWindow = iframe.contentWindow;
iframe.remove();
detachedWindow.fetchLater("https://origin.example.com");
```

See deferred fetch quota examples for examples portraying how the deferred-fetch quota works.


### Garbage collection

The user agent may terminate an ongoing fetch if that termination is not observable through script.

"Observable through script" means observable through `fetch()`'s arguments and return value. Other ways, such as communicating with the server through a side-channel are not included.

The server being able to observe garbage collection has precedent, e.g., with `WebSocket` and `XMLHttpRequest` objects.

The user agent can terminate the fetch because the termination cannot be observed.

```javascript
fetch("https://www.example.com/")
```

The user agent cannot terminate the fetch because the termination can be observed through the promise.

```javascript
window.promise = fetch("https://www.example.com/")
```

The user agent can terminate the fetch because the associated body is not observable.

```javascript
window.promise = fetch("https://www.example.com/").then(res => res.headers)
```

The user agent can terminate the fetch because the termination cannot be observed.

```javascript
fetch("https://www.example.com/").then(res => res.body.getReader().closed)
```

The user agent cannot terminate the fetch because one can observe the termination by registering a handler for the promise object.

```javascript
window.promise = fetch("https://www.example.com/")
  .then(res => res.body.getReader().closed)
```

The user agent cannot terminate the fetch as termination would be observable via the registered handler.

```javascript
fetch("https://www.example.com/")
  .then(res => {
    res.body.getReader().closed.then(() => console.log("stream closed!"))
  })
```

(The above examples of non-observability assume that built-in properties and functions, such as `body.getReader()`, have not been overwritten.)


## `data:` URLs

For an informative description of `data:` URLs, see RFC 2397. This section replaces that RFC's normative processing requirements to be compatible with deployed content. [[RFC2397]]

A **`data:` URL struct** is a [struct](https://infra.spec.whatwg.org/#struct) that consists of a **MIME type** (a [MIME type](https://mimesniff.spec.whatwg.org/#mime-type)) and a **body** (a [byte sequence](https://infra.spec.whatwg.org/#byte-sequence)).

The **`data:` URL processor** takes a [URL](https://url.spec.whatwg.org/#concept-url) `dataURL` and then runs these steps:

1.  [Assert](https://infra.spec.whatwg.org/#assert): `dataURL`'s [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is "`data`".

2.  Let `input` be the result of running the [URL serializer](https://url.spec.whatwg.org/#concept-url-serializer) on `dataURL` with [*exclude fragment*](https://url.spec.whatwg.org/#url-serializer-exclude-fragment) set to true.

3.  Remove the leading "`data:`" from `input`.

4.  Let `position` point at the start of `input`.

5.  Let `mimeType` be the result of [collecting a sequence of code points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points) that are not equal to U+002C (,), given `position`.

6.  [Strip leading and trailing ASCII whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace) from `mimeType`.

    This will only remove U+0020 SPACE [code points](https://infra.spec.whatwg.org/#code-point), if any.

7.  If `position` is past the end of `input`, then return failure.

8.  Advance `position` by 1.

9.  Let `encodedBody` be the remainder of `input`.

10. Let `body` be the [percent-decoding](https://url.spec.whatwg.org/#string-percent-decode) of `encodedBody`.

11. If `mimeType` ends with U+003B (;), followed by zero or more U+0020 SPACE, followed by an [ASCII case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for "`base64`", then:

    1.  Let `stringBody` be the [isomorphic decode](https://infra.spec.whatwg.org/#isomorphic-decode) of `body`.

    2.  Set `body` to the [forgiving-base64 decode](https://infra.spec.whatwg.org/#forgiving-base64-decode) of `stringBody`.

    3.  If `body` is failure, then return failure.

    4.  Remove the last 6 [code points](https://infra.spec.whatwg.org/#code-point) from `mimeType`.

    5.  Remove trailing U+0020 SPACE [code points](https://infra.spec.whatwg.org/#code-point) from `mimeType`, if any.

    6.  Remove the last U+003B (;) from `mimeType`.

12. If `mimeType` [starts with](https://infra.spec.whatwg.org/#string-starts-with) "`;`", then prepend "`text/plain`" to `mimeType`.

13. Let `mimeTypeRecord` be the result of [parsing](https://mimesniff.spec.whatwg.org/#parse-a-mime-type) `mimeType`.

14. If `mimeTypeRecord` is failure, then set `mimeTypeRecord` to `text/plain;charset=US-ASCII`.

15. Return a new `data:` URL struct whose MIME type is `mimeTypeRecord` and body is `body`.


## Background reading

*This section and its subsections are informative only.*


### HTTP header layer division

For the purposes of fetching, there is an API layer (HTML's `img`, CSS's `background-image`), early fetch layer, service worker layer, and network & cache layer. \``Accept`\` and \``Accept-Language`\` are set in the early fetch layer (typically by the user agent). Most other headers controlled by the user agent, such as \``Accept-Encoding`\`, \``Host`\`, and \``Referer`\`, are set in the network & cache layer. Developers can set headers either at the API layer or in the service worker layer (typically through a [`Request`](#request) object). Developers have almost no control over [forbidden request-headers](#forbidden-request-header), but can control \``Accept`\` and have the means to constrain and omit \``Referer`\` for instance.


### Atomic HTTP redirect handling

Redirects (a [response](#concept-response) whose [status](#concept-response-status) or [internal response](#concept-internal-response)'s (if any) [status](#concept-response-status) is a [redirect status](#redirect-status)) are not exposed to APIs. Exposing redirects might leak information not otherwise available through a cross-site scripting attack.

A fetch to `https://example.org/auth` that includes a `Cookie` marked `HttpOnly` could result in a redirect to `https://other-origin.invalid/4af955781ea1c84a3b11`. This new URL contains a secret. If we expose redirects that secret would be available through a cross-site scripting attack.


### Basic safe CORS protocol setup

For resources where data is protected through IP authentication or a firewall (unfortunately relatively common still), using the [CORS protocol](#cors-protocol) is **unsafe**. (This is the reason why the [CORS protocol](#cors-protocol) had to be invented.)

However, otherwise using the following [header](#concept-header) is **safe**:

```http
Access-Control-Allow-Origin: *
```

Even if a resource exposes additional information based on cookie or HTTP authentication, using the above [header](#concept-header) will not reveal it. It will share the resource with APIs such as [`XMLHttpRequest`](https://xhr.spec.whatwg.org/#xmlhttprequest), much like it is already shared with `curl` and `wget`.

Thus in other words, if a resource cannot be accessed from a random device connected to the web using `curl` and `wget` the aforementioned [header](#concept-header) is not to be included. If it can be accessed however, it is perfectly fine to do so.


### CORS protocol and HTTP caches

If [CORS protocol](#cors-protocol) requirements are more complicated than setting \`[`Access-Control-Allow-Origin`](#http-access-control-allow-origin)\` to `*` or a static [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin), \``Vary`\` is to be used. [\[HTML\]](#biblio-html) [\[HTTP\]](#biblio-http) [\[HTTP-CACHING\]](#biblio-http-caching)

```
Vary: Origin
```

In particular, consider what happens if \``Vary`\` is *not* used and a server is configured to send \`[`Access-Control-Allow-Origin`](#http-access-control-allow-origin)\` for a certain resource only in response to a [CORS request](#cors-request). When a user agent receives a response to a non-[CORS request](#cors-request) for that resource (for example, as the result of a [navigation request](#navigation-request)), the response will lack \`[`Access-Control-Allow-Origin`](#http-access-control-allow-origin)\` and the user agent will cache that response. Then, if the user agent subsequently encounters a [CORS request](#cors-request) for the resource, it will use that cached response from the previous non-[CORS request](#cors-request), without \`[`Access-Control-Allow-Origin`](#http-access-control-allow-origin)\`.

But if \``Vary: Origin`\` is used in the same scenario described above, it will cause the user agent to [fetch](#concept-fetch) a response that includes \`[`Access-Control-Allow-Origin`](#http-access-control-allow-origin)\`, rather than using the cached response from the previous non-[CORS request](#cors-request) that lacks \`[`Access-Control-Allow-Origin`](#http-access-control-allow-origin)\`.

However, if \`[`Access-Control-Allow-Origin`](#http-access-control-allow-origin)\` is set to `*` or a static [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) for a particular resource, then configure the server to always send \`[`Access-Control-Allow-Origin`](#http-access-control-allow-origin)\` in responses for the resource --- for non-[CORS requests](#cors-request) as well as [CORS requests](#cors-request) --- and do not use \``Vary`\`.


### WebSockets

As part of establishing a connection, the [`WebSocket`](https://websockets.spec.whatwg.org/#websocket) object initiates a special kind of [fetch](#concept-fetch) (using a [request](#concept-request) whose [mode](#concept-request-mode) is \"`websocket`\") which allows it to share in many fetch policy decisions, such HTTP Strict Transport Security (HSTS). Ultimately this results in fetch calling into WebSockets to obtain a dedicated connection. [\[WEBSOCKETS\]](#biblio-websockets) [\[HSTS\]](#biblio-hsts)

Fetch used to define [obtain a WebSocket connection](https://websockets.spec.whatwg.org/#concept-websocket-connection-obtain) and [establish a WebSocket connection](https://websockets.spec.whatwg.org/#concept-websocket-establish) directly, but both are now defined in WebSockets. [\[WEBSOCKETS\]](#biblio-websockets)


## Using fetch in other standards

In its essence fetching is an exchange of a request for a response. In reality it is rather complex mechanism for standards to adopt and use correctly. This section aims to give some advice.

Always ask domain experts for review.

This is a work in progress.


### Setting up a request

The first step in fetching is to create a request, and populate its items.

Start by setting the request's URL and method, as defined by HTTP. If your \``POST`\` or \``PUT`\` request needs a body, you set request's body to a byte sequence, or to a new body whose stream is a `ReadableStream` you created.

Choose your request's destination using the guidance in the destination table. Destinations affect Content Security Policy and have other implications such as the \``Sec-Fetch-Dest`\` header, so they are much more than informative metadata. If a new feature requires a destination that's not in the destination table, please [file an issue](https://github.com/whatwg/fetch/issues/new?title=What%20destination%20should%20my%20feature%20use) to discuss.

Set your request's client to the environment settings object you're operating in. Web-exposed APIs are generally defined with Web IDL, for which every object that implements an interface has a relevant settings object you can use. For example, a request associated with an element would set the request's client to the element's node document's relevant settings object. All features that are directly web-exposed by JavaScript, HTML, CSS, or other `Document` subresources should have a client.

If your fetching is not directly web-exposed, e.g., it is sent in the background without relying on a current `Window` or `Worker`, leave request's client as null and set the request's origin, policy container, service-workers mode, and referrer to appropriate values instead, e.g., by copying them from the environment settings object ahead of time. In these more advanced cases, make sure the details of how your fetch handles Content Security Policy and referrer policy are fleshed out. Also make sure you handle concurrency, as callbacks (see Invoking fetch and processing responses) would be posted on a parallel queue.

Think through the way you intend to handle cross-origin resources. Some features may only work in the same origin, in which case set your request's mode to \"`same-origin`\". Otherwise, new web-exposed features should almost always set their mode to \"`cors`\". If your feature is not web-exposed, or you think there is another reason for it to fetch cross-origin resources without CORS, please [file an issue](https://github.com/whatwg/fetch/issues/new?title=Does%20my%20request%20require%20CORS) to discuss.

For cross-origin requests, also determines if credentials are to be included with the requests, in which case set your request's credentials mode to \"`include`\".

Figure out if your fetch needs to be reported to Resource Timing, and with which initiator type. By passing an initiator type to the request, reporting to Resource Timing will be done automatically once the fetch is done and the response is fully downloaded.

If your request requires additional HTTP headers, set its header list to a header list that contains those headers, e.g., « (\``My-Header-Name`\`, \``My-Header-Value`\`) ». Sending custom headers may have implications, such as requiring a CORS-preflight fetch, so handle with care.

If you want to override the default caching mechanism, e.g., disable caching for this request, set the request's cache mode to a value other than \"`default`\".

Determine whether you want your request to support redirects. If you don't, set its redirect mode to \"`error`\".

Browse through the rest of the parameters for request to see if something else is relevant to you. The rest of the parameters are used less frequently, often for special purposes, and they are documented in detail in the § 2.2.5 Requests section of this standard.


### Invoking fetch and processing responses

Aside from a request the fetch operation takes several optional arguments. For those arguments that take an algorithm: the algorithm will be called from a task (or in a parallel queue if *useParallelQueue* is true).

Once the request is set up, to determine which algorithms to pass to fetch, determine how you would like to process the response, and in particular at what stage you would like to receive a callback:

Upon completion

:   This is how most callers handle a response, for example scripts and style resources. The response's body is read in its entirety into a byte sequence, and then processed by the caller.

    To process a response upon completion, pass an algorithm as the *processResponseConsumeBody* argument of fetch. The given algorithm is passed a response and an argument representing the fully read body (of the response's internal response). The second argument's values have the following meaning:

    null
    :   The response's body is null, due to the response being a network error or having a null body status.

    failure
    :   Attempting to fully read the contents of the response's body failed, e.g., due to an I/O error.

    a byte sequence

    :   Fully reading the contents of the response's internal response's body succeeded.

        A byte sequence containing the full contents will be passed also for a request whose mode is \"`no-cors`\". Callers have to be careful when handling such content, as it should not be accessible to the requesting origin. For example, the caller may use contents of a \"`no-cors`\" response to display image contents directly to the user, but those image contents should not be directly exposed to scripts in the embedding document.

    1.  Let `request` be a request whose URL is `https://stuff.example.com/` and client is this's relevant settings object.

    2.  Fetch `request`, with *processResponseConsumeBody* set to the following steps given a response `response` and null, failure, or a byte sequence `contents`:

        1.  If `contents` is null or failure, then present an error to the user.

        2.  Otherwise, parse `contents` considering the metadata from `response`, and perform your own operations on it.

Headers first, then chunk-by-chunk

:   In some cases, for example when playing video or progressively loading images, callers might want to stream the response, and process it one chunk at a time. The response is handed over to the fetch caller once the headers are processed, and the caller continues from there.

    To process a response chunk-by-chunk, pass an algorithm to the *processResponse* argument of fetch. The given algorithm is passed a response when the response's headers have been received and is responsible for reading the response's body's stream in order to download the rest of the response. For convenience, you may also pass an algorithm to the *processResponseEndOfBody* argument, which is called once you have finished fully reading the response and its body. Note that unlike *processResponseConsumeBody*, passing the *processResponse* or *processResponseEndOfBody* arguments does not guarantee that the response will be fully read, and callers are responsible to read it themselves.

    The *processResponse* argument is also useful for handling the response's header list and status without handling the body at all. This is used, for example, when handling responses that do not have an ok status.

    1.  Let `request` be a request whose URL is `https://stream.example.com/` and client is this's relevant settings object.

    2.  Fetch `request`, with *processResponse* set to the following steps given a response `response`:

        1.  If `response` is a network error, then present an error to the user.

        2.  Otherwise, if `response`'s status is not an ok status, present some fallback value to the user.

        3.  Otherwise, get a reader for response's body's stream, and process in an appropriate way for the MIME type identified by extracting a MIME type from `response`'s headers list.

Ignore the response

:   In some cases, there is no need for a response at all, e.g., in the case of `navigator.sendBeacon()`. Processing a response and passing callbacks to fetch is optional, so omitting the callback would fetch without expecting a response. In such cases, the response's body's stream will be discarded, and the caller does not have to worry about downloading the contents unnecessarily.

    Fetch a request whose URL is `https://fire-and-forget.example.com/`, method is \``POST`\`, and client is this's relevant settings object.

Apart from the callbacks to handle responses, fetch accepts additional callbacks for advanced cases. *processEarlyHintsResponse* is intended specifically for responses whose status is 103, and is currently handled only by navigations. *processRequestBodyChunkLength* and *processRequestEndOfBody* notify the caller of request body uploading progress.

Note that the fetch operation starts in the same thread from which it was called, and then breaks off to run its internal operations in parallel. The aforementioned callbacks are posted to a given event loop which is, by default, the client's global object. To process responses in parallel and handle interactions with the main thread by yourself, fetch with *useParallelQueue* set to true.


### Manipulating an ongoing fetch

To manipulate a fetch operation that has already started, use the fetch controller returned by calling fetch. For example, you may abort the fetch controller due the user or page logic, or terminate it due to browser-internal circumstances.

In addition to terminating and aborting, callers may report timing if this was not done automatically by passing the initiator type, or extract full timing info and handle it on the caller side (this is done only by navigations). The fetch controller is also used to process the next manual redirect for requests with redirect mode set to \"`manual`\".