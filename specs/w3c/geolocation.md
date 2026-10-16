
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# Geolocation

[W3C Candidate Recommendation
Snapshot](https://www.w3.org/standards/types#CR) 26 March 2026

More details about this document

This version:
: [https://www.w3.org/TR/2026/CR-geolocation-20260326/](https://www.w3.org/TR/2026/CR-geolocation-20260326/)

Latest published version:
: <https://www.w3.org/TR/geolocation/>

Latest editor\'s draft:
: <https://w3c.github.io/geolocation/>

History:
: <https://www.w3.org/standards/history/geolocation/>
: [Commit history](https://github.com/w3c/geolocation/commits/)

Test suite:
: <https://wpt.live/geolocation/>

Implementation report:
: <https://w3c.github.io/geolocation/reports/implementation.html>

Editors:
: [Marcos Cáceres] ([Apple
 Inc.](https://apple.com))
: [Reilly Grant] ([Google](https://google.com))

Former editor:
: [Andrei Popescu] ([Google
 Inc.](https://google.com/))

Feedback:
: [GitHub w3c/geolocation](https://github.com/w3c/geolocation/) ([pull
 requests](https://github.com/w3c/geolocation/pulls/), [new
 issue](https://github.com/w3c/geolocation/issues/new/choose), [open
 issues](https://github.com/w3c/geolocation/issues/))

Errata:
: [Errata exists](https://w3c.github.io/geolocation/errata.html).

Browser support:
: [caniuse.com](https://caniuse.com/geolocation)

[Copyright](https://www.w3.org/policies/#copyright) © 2026 [World Wide
Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

Geolocation provides access to geographical location information
associated with the hosting device.

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

Geolocation was published as a [[W3C] Recommendation on 1 September
2022](https://www.w3.org/standards/history/geolocation/). In March 2026,
the specification returned to Candidate Recommendation to allow the
Working Groups to iterate more efficiently on substantive changes and to
continue adding new features.

At the time of the publication, the [Devices and Sensors Working
Group](https://www.w3.org/groups/wg/das) still operates under the [15
September 2020 version of the [W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/20200915/).

This document was published by the [Devices and Sensors Working
Group](https://www.w3.org/groups/wg/das) and the [Web Applications
Working Group](https://www.w3.org/groups/wg/webapps) as a Candidate
Recommendation Snapshot using the [Recommendation
track](https://www.w3.org/policies/process/20250818/#recs-and-notes).

Publication as a Candidate Recommendation does not imply endorsement by
[W3C] and its Members. A
Candidate Recommendation Snapshot has received [wide
review](https://www.w3.org/policies/process/20250818/#dfn-wide-review),
is intended to gather [implementation
experience](https://w3c.github.io/geolocation/reports/implementation.html),
and has commitments from Working Group members to [royalty-free
licensing](https://www.w3.org/policies/patent-policy/#sec-Requirements)
for implementations.

This Candidate Recommendation is not expected to advance to
Recommendation any earlier than 01 May 2026.

This document was produced by groups operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent disclosures (Devices and Sensors Working
Group)](https://www.w3.org/groups/wg/das/ipr){rel="disclosure"} and a
[public list of any patent disclosures (Web Applications Working
Group)](https://www.w3.org/groups/wg/webapps/ipr){rel="disclosure"} made
in connection with the deliverables of each group; these pages also
include instructions for disclosing a patent. An individual who has
actual knowledge of a patent that the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the
[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

This document is governed by the [18 August 2025 [W3C] Process
Document](https://www.w3.org/policies/process/20250818/).

## Table of Contents

1. [Abstract](#abstract)
2. [Status of This Document](#sotd)
3. [1. Introduction](#introduction)
 1. [1.1 Scope](#scope)
4. [2. Examples](#examples)
 1. [2.1 Get current position](#get-current-position)
 2. [2.2 Watch a position](#watch-a-position)
 3. [2.3 Stop watching a
 position](#stop-watching-a-position)
 4. [2.4 Handling errors](#handling-errors)
 5. [2.5 Using `maximumAge` as cache
 control](#using-maximumage-as-cache-control)
 6. [2.6 Using `timeout`](#using-timeout)
 7. [2.7 Enabling the API in third-party
 contexts](#enabling-the-api-in-third-party-contexts)
5. [3. Privacy considerations](#privacy)
 1. [3.1 User consent](#user-consent)
 2. [3.2 Privacy considerations for recipients of location
 information](#privacy_for_recipients)
 3. [3.3 Implementation
 considerations](#implementation_considerations)
 4. [3.4 Checking permission to use the
 API](#check-permission)
6. [4. Security considerations](#security)
7. [5. Extensions to the `Navigator`
 interface](#navigator_interface)
 1. [5.1 `navigator` attribute](#navigator-attribute)
8. [6. `Geolocation` interface and
 callbacks](#geolocation_interface)
 1. [6.1 Internal slots](#internal-slots)
 2. [6.2 `getCurrentPosition()`
 method](#getcurrentposition-method)
 3. [6.3 `watchPosition()` method](#watchposition-method)
 4. [6.4 `clearWatch()` method](#clearwatch-method)
 5. [6.5 Request a position](#request-a-position)
 6. [6.6 Acquire a position](#acquire-a-position)
 7. [6.7 Call back with error](#call-back-with-error)
9. [7. [`PositionOptions`]{
 idl="dictionary" }
 dictionary](#position_options_interface)
 1. [7.1 `enableHighAccuracy`
 member](#enablehighaccuracy-member)
 2. [7.2 `timeout` member](#timeout-member)
 3. [7.3 `maximumAge` member](#maximumage-member)
10. [8. `GeolocationPosition` interface](#position_interface)
 1. [8.1 `coords` attribute](#coords-attribute)
 2. [8.2 `timestamp` attribute](#timestamp-attribute)
 3. [8.3 `toJSON()` method](#tojson-method)
 4. [8.4 Internal slots](#internal-slots-0)
 5. [8.5 Task sources](#task-sources)
11. [9. [`GeolocationCoordinates`]{
 idl="interface" }
 interface](#coordinates_interface)
 1. [9.1 `latitude`, `longitude`, and `accuracy`
 attributes](#latitude-longitude-and-accuracy-attributes)
 2. [9.2 `altitude` and `altitudeAccuracy`
 attributes](#altitude-and-altitudeaccuracy-attributes)
 3. [9.3 `heading` attribute](#heading-attribute)
 4. [9.4 `speed` attribute](#speed-attribute)
 5. [9.5 `toJSON()` method](#tojson-method-0)
 6. [9.6 Constructing a
 `GeolocationPosition`](#constructing-a-geolocationposition)
12. [10. [`GeolocationPositionError`]{
 idl="interface" }
 interface](#position_error_interface)
 1. [10.1 Constants](#constants)
 2. [10.2 `code` attribute](#code-attribute)
 3. [10.3 `message` attribute](#message-attribute)
13. [11. Permissions policy](#permissions-policy)
14. [12. Emulation](#emulation)
15. [13. Conformance](#conformance)
16. [A. IDL Index](#idl-index)
17. [B. Index](#index)
 1. [B.1 Terms defined by this
 specification](#index-defined-here)
 2. [B.2 Terms defined by
 reference](#index-defined-elsewhere)
18. [C. Acknowledgments](#acknowledgments)
19. [D. Change log](#changelog)
20. [E. References](#references)
 1. [E.1 Normative references](#normative-references)

::: header-wrapper
## 1. Introduction

*This section is non-normative.*

Geolocation defines a high-level interface to location information
associated only with the device hosting the implementation. Common
sources of location information include Global Positioning System (GPS)
and location inferred from network signals such as IP address, RFID,
WiFi and Bluetooth MAC addresses, and GSM/CDMA cell IDs, as well as user
input. The API itself is agnostic of the underlying location information
sources, and no guarantee is given that the API returns the device\'s
actual location.

If an end user [grants
permission](#dfn-checking-permission),
Geolocation:

- Provides location data as latitude, longitude, altitude, speed, and
 heading, as well as the accuracy of the acquired location data, and
 the approximate time for when the position was acquired via the
 [`GeolocationPosition`](#dom-geolocationposition) interface.
- Supports \"one-shot\" position updates via the
 [`getCurrentPosition`](#dom-geolocation-getcurrentposition)`()` method and
 the ability to receive updates for when the position of the hosting
 device significantly changes via the
 [`watchPosition`](#dom-geolocation-watchposition)`()` method.
- Using the
 [`PositionOptions`](#dom-positionoptions)\'s
 [`maximumAge`](#dom-positionoptions-maximumage), allows an application to request a
 cached position whose age is no greater than a specified value (only
 the last position is cached).
- Provides a way for the application to receive updates about errors, as
 a
 [`GeolocationPositionError`](#dom-geolocationpositionerror), that have
 occurred while [acquiring a
 position](#dfn-acquire-a-position).
- And through
 [`enableHighAccuracy`](#dom-positionoptions-enablehighaccuracy), supports requesting \"high accuracy\"
 position data, though the request can be ignored by the user agent.

::: header-wrapper
### 1.1 Scope

*This section is non-normative.*

This specification is limited to providing a scripting API for
retrieving geographic position information associated with a hosting
device. The geographic position information is provided in terms of
World Geodetic System coordinates
\[[WGS84](#bib-wgs84 "World Geodetic System 1984 (WGS 84)")\]. It does not include providing a markup language
of any kind, nor does it include defining a new URL scheme for building
URLs that identify geographic locations.

::: header-wrapper
## 2. Examples

*This section is non-normative.*

The API is designed to enable both \"one-shot\" position requests and
repeated position updates. The following examples illustrate common use
cases.

::: header-wrapper
### 2.1 Get current position

*This section is non-normative.*

Request the user\'s current location. If the user allows it, you will
get back a position object.

[Example 1](#example-a-one-shot-position-request)[: A
one-shot position request]

``` {aria-busy="false"}
navigator.geolocation.getCurrentPosition(position => {
 const { latitude, longitude } = position.coords;
 // Show a map centered at latitude / longitude.
});
```

::: header-wrapper
### 2.2 Watch a position

*This section is non-normative.*

Request the ability to watch user\'s current location. If the user
allows it, you will get back continuous updates of the user\'s position.

[Example
2](#example-watching-a-position-for-repeated-updates)[:
Watching a position for repeated updates]

``` {aria-busy="false"}
const watchId = navigator.geolocation.watchPosition(position => {
 const { latitude, longitude } = position.coords;
 // Show a map centered at latitude / longitude.
});
```

::: header-wrapper
### 2.3 Stop watching a position

*This section is non-normative.*

Stop watching for position changes by calling the
[`clearWatch`](#dom-geolocation-clearwatch)`()` method.

[Example 3](#example-using-clearwatch)[: Using
clearWatch()]

``` {aria-busy="false"}
const watchId = navigator.geolocation.watchPosition(
 position => console.log(position)
);

function buttonClickHandler() {
 // Cancel the updates when the user clicks a button.
 navigator.geolocation.clearWatch(watchId);
}
```

And a HTML `button` that when pressed stops watching the position.

``` {aria-busy="false"}
<button onclick="buttonClickHandler()">
 Stop watching location
</button>
```

::: header-wrapper
### 2.4 Handling errors

*This section is non-normative.*

When an error occurs, the second argument of the
[`watchPosition`](#dom-geolocation-watchposition)`()` or
[`getCurrentPosition`](#dom-geolocation-getcurrentposition)`()` method gets
called with a
[`GeolocationPositionError`](#dom-geolocationpositionerror) error, which
can help you figure out what might have gone wrong.

[Example 4](#example-handling-errors)[: Handling
errors]

``` {aria-busy="false"}
// Request repeated updates.
const watchId = navigator.geolocation.watchPosition(
 scrollMap, handleError
);

function scrollMap(position) {
 const { latitude, longitude } = position.coords;
 // Scroll map to latitude / longitude.
}

function handleError(error) {
 // Display error based on the error code.
 const { code } = error;
 switch (code) {
 case GeolocationPositionError.TIMEOUT:
 // Handle timeout.
 break;
 case GeolocationPositionError.PERMISSION_DENIED:
 // User denied the request.
 break;
 case GeolocationPositionError.POSITION_UNAVAILABLE:
 // Position not available.
 break;
 }
}
```

::: header-wrapper
### 2.5 Using `maximumAge` as cache control

*This section is non-normative.*

By default, the API always attempts to return a cached position so long
as it has a previously acquired position. In this example, we accept a
position whose age is no greater than 10 minutes. If the user agent does
not have a fresh enough cached position object, it automatically
acquires a new position.

[Example 5](#example-getting-cached-position)[: Getting
cached position]

``` {aria-busy="false"}
navigator.geolocation.getCurrentPosition(
 successCallback,
 console.error,
 { maximumAge: 600_000 }
);

function successCallback(position) {
 // By using the 'maximumAge' member above, the position
 // object is guaranteed to be at most 10 minutes old.
}
```

::: header-wrapper
### 2.6 Using `timeout`

*This section is non-normative.*

If you require location information in a time sensitive manner, you can
use the
[`PositionOptions`](#dom-positionoptions)
[`timeout`](#dom-positionoptions-timeout) member to limit the amount of time you are
willing to wait to [acquire a
position](#dfn-acquire-a-position).

[Example 6](#example-timing-out-a-position-request)[: Timing
out a position request]

``` {aria-busy="false"}
// Request a position. We are only willing to wait 10
// seconds for it.
navigator.geolocation.getCurrentPosition(
 successCallback,
 errorCallback,
 { timeout: 10_000 }
);

function successCallback(position) {
 // Request finished in under 10 seconds...
}

function errorCallback(error) {
 switch (error.code) {
 case GeolocationPositionError.TIMEOUT:
 // We didn't get it in a timely fashion.
 doFallback();
 // Acquire a new position object,
 // as long as it takes.
 navigator.geolocation.getCurrentPosition(
 successCallback, errorCallback
 );
 break;
 case "...": // treat the other error cases.
 }
}

function doFallback()
```

::: header-wrapper
### 2.7 Enabling the API in third-party contexts

*This section is non-normative.*

The [default
allowlist](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature-default-allowlist) of `'self'` allows API usage in same-origin nested
frames but prevents third-party content from using the API.

Third-party usage can be selectively enabled by adding the
[`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow)`="geolocation"` attribute to an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element:

[Example 7](#example-enabling-geolocation-in-an-iframe)[:
Enabling Geolocation in an iframe]

``` {aria-busy="false"}
<iframe
 src="https://third-party.com"
 allow="geolocation">
</iframe>
```

Alternatively, the API can be disabled in a first-party context by
specifying an HTTP response header:

[Example 8](#example-permissions-policy-over-http)[:
Permissions Policy over HTTP]

``` {aria-busy="false"}
Permissions-Policy: geolocation=()
```

See [Permissions
Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[permissions-policy]]]"}
for more details about the `Permissions-Policy` HTTP header.

::: header-wrapper
## 3. Privacy considerations

*This section is non-normative.*

The API defined in this specification is used to retrieve the geographic
location of a hosting device. In almost all cases, this information also
discloses the location of the user of the device, thereby potentially
compromising the user\'s privacy.

::: header-wrapper
### 3.1 User consent

*This section is non-normative.*

Geolocation is a [powerful
feature](https://www.w3.org/TR/permissions/#dfn-powerful-feature) that requires [express
permission](https://www.w3.org/TR/permissions/#dfn-express-permission) from an end-user before any location data is shared
with a web application. This requirement is normatively enforced by the
[check
permission](#dfn-checking-permission) steps on which the
[`getCurrentPosition`](#dom-geolocation-getcurrentposition)`()` and
[`watchPosition`](#dom-geolocation-watchposition)`()` methods rely.

An end-user will generally give [express
permission](https://www.w3.org/TR/permissions/#dfn-express-permission) through a user interface, which usually presents a
range of permission
[lifetimes](https://www.w3.org/TR/permissions/#dfn-lifetime) that the end-user can choose from. The choice of
[lifetimes](https://www.w3.org/TR/permissions/#dfn-lifetime) vary across user agents, but they are typically
time-based (e.g., \"a day\"), or until browser is closed, or the user
might even be given the choice for the permission to be granted
indefinitely. The permission
[lifetimes](https://www.w3.org/TR/permissions/#dfn-lifetime) dictate how long a user agent
[grants](https://www.w3.org/TR/permissions/#dfn-granted) a permission before that permission is
automatically reverted back to its default [permission
state](https://www.w3.org/TR/permissions/#dfn-permission-state), prompting the end-user to make a new choice upon
subsequent use.

Although the granularity of the permission
[lifetime](https://www.w3.org/TR/permissions/#dfn-lifetime) varies across user-agents, this specification urges
user agents to limit the lifetime to a single browsing session by
default (see [3.4 Checking permission to use the
API](#check-permission)
for normative requirements).

::: header-wrapper
### 3.2 Privacy considerations for recipients of location information

*This section is non-normative.*

Note[: Developers\' responsibility with this sensitive
data]

This section applies to \"recipients\", which generally means developers
utilizing Geolocation. Although it\'s impossible for the user agent, or
this specification, to enforce these requirements, developers need to
read this section carefully and do their best to adhere to the
suggestions below. Developers need to be aware that there might be
privacy laws in their jurisdictions that can govern the usage and access
to users\' location data.

Recipients ought to only request position information when necessary,
and only use the location information for the task for which it was
provided to them. Recipients ought to dispose of location information
once that task is completed, unless expressly permitted to retain it by
the user. Recipients need to also take measures to protect this
information against unauthorized access. If location information is
stored, users need to be allowed to update and delete this information.

The recipients of location information need to refrain from
retransmitting the location information without the user's express
permission. Care needs to be taken when retransmitting and the use of
encryption is encouraged.

Recipients ought to clearly and conspicuously disclose the fact that
they are collecting location data, the purpose for the collection, how
long the data is retained, how the data is secured, how the data is
shared if it is shared, how users can access, update and delete the
data, and any other choices that users have with respect to the data.
This disclosure needs to include an explanation of any exceptions to the
guidelines listed above.

::: header-wrapper
### 3.3 Implementation considerations

*This section is non-normative.*

Implementers are advised to consider the following aspects that can
negatively affect the privacy of their users: in certain cases, users
can inadvertently grant permission to the user agent to disclose their
location to websites. In other cases, the content hosted at a certain
URL changes in such a way that the previously granted location
permissions no longer apply as far as the user is concerned. Or the
users might simply change their minds.

Predicting or preventing these situations is inherently difficult.
Mitigation and in-depth defensive measures are an implementation
responsibility and not prescribed by this specification. However, in
designing these measures, implementers are advised to enable user
awareness of location sharing, and to provide access to user interfaces
that enable revocation of permissions.

MDN[🚫]{title="This feature has limited support."}

[Headers/Feature-Policy/geolocation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Feature-Policy/geolocation "The HTTP Permissions-Policy header geolocation directive controls whether the current document is allowed to use the Geolocation Interface.")

This feature has limited support.

 ------------------ -----
 Chrome 60+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 74+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

::: header-wrapper
### 3.4 Checking permission to use the API

Geolocation is a [default powerful
feature](https://www.w3.org/TR/permissions/#dfn-default-powerful-feature) identified by the
[name](https://www.w3.org/TR/permissions/#dfn-name) [`"geolocation"`].

When [checking permission] to use the API, a user agent *MAY* suggest time-based
[permission](https://www.w3.org/TR/permissions/#dfn-permission)
[lifetimes](https://www.w3.org/TR/permissions/#dfn-lifetime), such as \"24 hours\", \"1 week\", or choose to
remember the permission
[grant](https://www.w3.org/TR/permissions/#dfn-granted) indefinitely. However, it is *RECOMMENDED* that a user
agent prioritize restricting the
[permission](https://www.w3.org/TR/permissions/#dfn-permission)
[lifetime](https://www.w3.org/TR/permissions/#dfn-lifetime) to a single session: This can be, for example, until
the
[realm](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object's-realm) is destroyed, the end-user
[navigates](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate) away from the
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin), or the relevant browser tab is closed.

::: header-wrapper
## 4. Security considerations

There are no security considerations associated with Geolocation at the
time of publication. However, readers are advised to read the [3.
Privacy considerations](#privacy).

::: header-wrapper
## 5. Extensions to the `Navigator` interface

```
WebIDLpartial interface Navigator {
 [SameObject] readonly attribute Geolocation geolocation;
};
```

MDN[✅]{title="This feature is in all major engines."}

[Navigator/geolocation](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/geolocation "The Navigator.geolocation read-only property returns a Geolocation object that gives Web content access to the location of the device. This allows a website or app to offer customized results based on the user's location.")

This feature is in all major engines.

 ------------------ -------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera 10.6+
 Opera Android 11+
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ -------

::: header-wrapper
### 5.1 `navigator` attribute

The [`geolocation`]
attribute provides the entry point for accessing the Geolocation API.

MDN[✅]{title="This feature is in all major engines."}

[Geolocation](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation "The Geolocation interface represents an object able to obtain the position of the device programmatically. It gives Web content access to the location of the device. This allows a website or app to offer customized results based on the user's location.")

This feature is in all major engines.

 ------------------ -------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android 4+
 Opera 10.6+
 Opera Android 11+
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ -------

::: header-wrapper
## 6. `Geolocation` interface and callbacks

```
WebIDL[Exposed=Window]
interface Geolocation {
 undefined getCurrentPosition (
 PositionCallback successCallback,
 optional PositionErrorCallback? errorCallback = null,
 optional PositionOptions options =
 );

 long watchPosition (
 PositionCallback successCallback,
 optional PositionErrorCallback? errorCallback = null,
 optional PositionOptions options =
 );

 undefined clearWatch (long watchId);
};

callback PositionCallback = undefined (
 GeolocationPosition position
);

callback PositionErrorCallback = undefined (
 GeolocationPositionError positionError
);
```

::: header-wrapper
### 6.1 Internal slots

Instances of
[`Geolocation`](#dom-geolocation) are created with the
internal slots in the following table:

 ------------------------------------------------------------------------------------------------------------------------------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Internal slot Description
 [\[\[cachedPosition\]\]] A [`GeolocationPosition`](#dom-geolocationposition), initialized to null. It\'s a reference to the last acquired position and serves as a cache. A user agent *MAY* evict [`[[cachedPosition]]`](#dfn-cachedposition) by resetting it to null at any time for any reason.
 [\[\[watchIDs\]\]] Initialized as an empty [list](https://infra.spec.whatwg.org/#list) of [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long) [items](https://infra.spec.whatwg.org/#list-item).
 ------------------------------------------------------------------------------------------------------------------------------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

MDN[✅]{title="This feature is in all major engines."}

[Geolocation/getCurrentPosition](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation/getCurrentPosition "The Geolocation.getCurrentPosition() method is used to get the current position of the device.")

This feature is in all major engines.

 ------------------ -------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera 10.6+
 Opera Android 11+
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ -------

::: header-wrapper
### 6.2 `getCurrentPosition()` method

The [`getCurrentPosition`](`successCallback`, `errorCallback`, `options`) method steps are:

1. If
 [this](https://webidl.spec.whatwg.org/#this)\'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)\'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active):
 1. [Call back with
 error](#dfn-call-back-with-error)
 `errorCallback`
 and
 [`POSITION_UNAVAILABLE`](#dom-geolocationpositionerror-position_unavailable).
 2. Terminate this algorithm.
2. [Request a
 position](#dfn-request-a-position) passing
 [this](https://webidl.spec.whatwg.org/#this), `successCallback`, `errorCallback`, and `options`.

MDN[✅]{title="This feature is in all major engines."}

[Geolocation/watchPosition](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation/watchPosition "The Geolocation method watchPosition() method is used to register a handler function that will be called automatically each time the position of the device changes. You can also, optionally, specify an error handling callback function.")

This feature is in all major engines.

 ------------------ -------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera 10.6+
 Opera Android 11+
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ -------

::: header-wrapper
### 6.3 `watchPosition()` method

The [`watchPosition`](`successCallback`, `errorCallback`, `options`) method steps are:

1. If
 [this](https://webidl.spec.whatwg.org/#this)\'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)\'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active):
 1. [Call back with
 error](#dfn-call-back-with-error) passing
 `errorCallback`
 and
 [`POSITION_UNAVAILABLE`](#dom-geolocationpositionerror-position_unavailable).
 2. Return 0.
2. Let `watchId` be an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined)
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long) that is greater than zero.
3. [Append](https://infra.spec.whatwg.org/#list-append) `watchId` to
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [`[[watchIDs]]`](#dfn-watchids).
4. [Request a
 position](#dfn-request-a-position) passing
 [this](https://webidl.spec.whatwg.org/#this), `successCallback`, `errorCallback`, `options`, and `watchId`.
5. Return `watchId`.

MDN[✅]{title="This feature is in all major engines."}

[Geolocation/clearWatch](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation/clearWatch "The Geolocation.clearWatch() method is used to unregister location/error monitoring handlers previously installed using Geolocation.watchPosition().")

This feature is in all major engines.

 ------------------ -------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera 10.6+
 Opera Android 11+
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ -------

::: header-wrapper
### 6.4 `clearWatch()` method

When [`clearWatch()`] is invoked, the user agent *MUST*:

1. [Remove](https://infra.spec.whatwg.org/#list-remove) `watchId` from
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [`[[watchIDs]]`](#dfn-watchids).

::: header-wrapper
### 6.5 Request a position

To [request a position], pass a
[`Geolocation`](#dom-geolocation) `geolocation`, a
[`PositionCallback`](#dom-positioncallback)
`successCallback`, a
[`PositionErrorCallback?`](#dom-positionerrorcallback)
`errorCallback`, a
[`PositionOptions`](#dom-positionoptions) `options`, and an optional `watchId`:

1. Let `watchIDs` be
 `geolocation`\'s
 [`[[watchIDs]]`](#dfn-watchids).
2. Let `document` be the
 `geolocation`\'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)\'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).
3. If `document` is not [allowed to
 use](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use) the \"geolocation\" feature:
 1. If `watchId` was passed,
 [remove](https://infra.spec.whatwg.org/#list-remove) `watchId`
 from `watchIDs`.
 2. [Call back with
 error](#dfn-call-back-with-error) passing
 `errorCallback`
 and
 [`PERMISSION_DENIED`](#dom-geolocationpositionerror-permission_denied).
 3. Terminate this algorithm.
4. If `geolocation`\'s [environment
 settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) is a [non-secure
 context](https://html.spec.whatwg.org/multipage/webappapis.html#non-secure-context):
 1. If `watchId` was passed,
 [remove](https://infra.spec.whatwg.org/#list-remove) `watchId`
 from `watchIDs`.
 2. [Call back with
 error](#dfn-call-back-with-error) passing
 `errorCallback`
 and
 [`PERMISSION_DENIED`](#dom-geolocationpositionerror-permission_denied).
 3. Terminate this algorithm.
5. If `document`\'s [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"hidden\", wait for the following [page
 visibility change
 steps](https://html.spec.whatwg.org/multipage/interaction.html#page-visibility-change-steps) to run:
 1. [Assert](https://infra.spec.whatwg.org/#assert):
 `document`\'s [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"visible\".
 2. Continue to the next steps below.
6. Let `descriptor` be a new
 [`PermissionDescriptor`](https://www.w3.org/TR/permissions/#dom-permissiondescriptor) whose
 [`name`](https://www.w3.org/TR/permissions/#dom-permissiondescriptor-name) is
 [`"geolocation"`](#dfn-geolocation).
7. [In
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):
 1. Set `permission` to [request permission to
 use](https://www.w3.org/TR/permissions/#dfn-request-permission-to-use) `descriptor`.
 2. If `permission` is \"denied\", then:
 1. If `watchId` was
 passed,
 [remove](https://infra.spec.whatwg.org/#list-remove) `watchId` from `watchIDs`.
 2. [Call back with
 error](#dfn-call-back-with-error) passing
 `errorCallback` and
 [`PERMISSION_DENIED`](#dom-geolocationpositionerror-permission_denied).
 3. Terminate this algorithm.
 3. Wait to [acquire a
 position](#dfn-acquire-a-position) passing
 `successCallback`,
 `errorCallback`,
 `options`, and
 `watchId`.
 4. If `watchId` was not
 passed, terminate this algorithm.
 5. While `watchIDs`
 [contains](https://infra.spec.whatwg.org/#list-contain) `watchId`:
 1. [Wait for a significant change of geographic
 position]. What constitutes a significant
 change of geographic position is left to the implementation.
 User agents *MAY* impose a rate limit on how frequently
 position changes are reported. User agents *MUST* consider
 invoking [set emulated position
 data](#dfn-set-emulated-position-data) as a significant
 change.
 2. If `document` is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) or [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is not \"visible\", go back to the previous
 step and again [wait for a significant change of geographic
 position](#wait-for-change).

 ::::
 :::
 Note[: Position updates are exclusively for fully-active
 visible documents]
 :::

 The desired effect here being that position updates are
 exclusively delivered to fully active documents that are
 visible; Otherwise the updates get silently \"dropped on the
 floor\". Only once a document again becomes fully active and
 visible (e.g., an
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) gets reattached to a parent document),
 do the position updates once again start getting delivered.
 ::::
 3. Wait to [acquire a
 position](#dfn-acquire-a-position) passing
 `successCallback`,
 `errorCallback`, `options`, and `watchId`.

::: header-wrapper
### 6.6 Acquire a position

To [acquire a position], passing
[`PositionCallback`](#dom-positioncallback)
`successCallback`, a
[`PositionErrorCallback?`](#dom-positionerrorcallback)
`errorCallback`,
[`PositionOptions`](#dom-positionoptions) `options`, and an optional `watchId`.

1. If `watchId` was passed and
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [`[[watchIDs]]`](#dfn-watchids) does not
 [contain](https://infra.spec.whatwg.org/#list-contain) `watchId`,
 terminate this algorithm.
2. Let `acquisitionTime` be a new
 [`EpochTimeStamp`](https://www.w3.org/TR/hr-time-3/#typedefdef-epochtimestamp) that represents now.
3. Let `timeoutTime` be the sum of
 `acquisitionTime` and
 `options`.[`timeout`](#dom-positionoptions-timeout).
4. Let `cachedPosition` be
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [`[[cachedPosition]]`](#dfn-cachedposition).
5. Create an implementation-specific `timeout` task that
 elapses at `timeoutTime`, during which it tries to
 acquire the device\'s position by running the following steps:
 1. Let `permission` be [get the current permission
 state](https://www.w3.org/TR/permissions/#dfn-getting-the-current-permission-state) of
 [`"geolocation"`](#dfn-geolocation).
 2. If `permission` is \"denied\":
 1. Stop `timeout`.
 2. Do the [user or system denied
 permission](#permission-denied) failure case step.
 3. If `permission` is \"granted\":
 1. Check if an emulated position should be used by running the
 following steps:
 1. Let `emulatedPositionData` be [get emulated
 position
 data](#dfn-get-emulated-position-data) passing
 [this](https://webidl.spec.whatwg.org/#this).
 2. If `emulatedPositionData` is not null:
 1. If `emulatedPositionData` is a
 [`GeolocationPositionError`](#dom-geolocationpositionerror):
 1. [Call back with
 error](#dfn-call-back-with-error)
 passing `errorCallback` and
 `emulatedPositionData`.[`code`](#dom-geolocationpositionerror-code).
 2. Terminate this algorithm.
 2. Let `position` be [a new
 `GeolocationPosition`](#dfn-a-new-geolocationposition) passing
 `emulatedPositionData`,
 `acquisitionTime` and `options`.[`enableHighAccuracy`](#dom-positionoptions-enablehighaccuracy).
 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on the [geolocation task
 source](#dfn-geolocation-task-source) with a
 step that
 [invokes](https://webidl.spec.whatwg.org/#invoke-a-callback-function) `successCallback` with «
 `position` » and \"`report`\".
 4. Terminate this algorithm.
 2. Let `position` be null.
 3. If `cachedPosition` is not null, and
 `options`.[`maximumAge`](#dom-positionoptions-maximumage) is greater than 0:
 1. Let `cacheTime` be
 `acquisitionTime`
 minus the value of the `options`.[`maximumAge`](#dom-positionoptions-maximumage) member.
 2. If `cachedPosition`\'s
 [`timestamp`](#dom-geolocationposition-timestamp)\'s value is greater than
 `cacheTime`, and
 `cachedPosition`.[`[[isHighAccuracy]]`](#dfn-ishighaccuracy) equals `options`.[`enableHighAccuracy`](#dom-positionoptions-enablehighaccuracy):
 1. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on the [geolocation task
 source](#dfn-geolocation-task-source) with a
 step that
 [invokes](https://webidl.spec.whatwg.org/#invoke-a-callback-function) `successCallback` with «
 `cachedPosition` » and \"`report`\".
 2. Terminate this algorithm.
 4. Otherwise, if `position` is not
 `cachedPosition`,
 try to acquire position data from the underlying system,
 optionally taking into consideration the value of
 `options`.[`enableHighAccuracy`](#dom-positionoptions-enablehighaccuracy) during acquisition.
 5. If the `timeout` elapses during acquisition, or
 acquiring the device\'s position results in failure:
 1. Stop the `timeout`.
 2. Go to [dealing with failures](#errors-reasons).
 3. Terminate this algorithm.
 6. If acquiring the position data from the system succeeds:
 1. Let `positionData` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) with the following name/value pairs
 based on the acquired position data:

 \"accuracy\"
 : A non-negative
 [`double`](https://webidl.spec.whatwg.org/#idl-double) that represents
 the accuracy value indicating the 95% confidence
 level in meters. Accuracy measures how close the
 measured coordinates are to the true position.

 \"altitude\"
 : A
 [`double?`](https://webidl.spec.whatwg.org/#idl-double) that represents
 the altitude in meters above the
 \[[WGS84](#bib-wgs84 "World Geodetic System 1984 (WGS 84)")\] ellipsoid, or `null` if not
 available. Altitude measures the height above sea
 level.

 \"altitudeAccuracy\"
 : A non-negative
 [`double?`](https://webidl.spec.whatwg.org/#idl-double) that represents
 the altitude accuracy, or `null` if not available,
 indicating the 95% confidence level in meters.
 Altitude accuracy measures how close the measured
 altitude is to the true altitude.

 \"heading\"
 : A
 [`double?`](https://webidl.spec.whatwg.org/#idl-double) that represents
 the heading in degrees, or `null` if not available
 or the device is stationary. Heading measures the
 direction in which the device is moving relative to
 true north.

 \"latitude\"
 : A
 [`double`](https://webidl.spec.whatwg.org/#idl-double) that represents
 the latitude coordinates on the Earth\'s surface in
 degrees, using the
 \[[WGS84](#bib-wgs84 "World Geodetic System 1984 (WGS 84)")\] coordinate system. Latitude
 measures how far north or south a point is from the
 Equator.

 \"longitude\"
 : A
 [`double`](https://webidl.spec.whatwg.org/#idl-double) that represents
 the longitude coordinates on the Earth\'s surface in
 degrees, using the
 \[[WGS84](#bib-wgs84 "World Geodetic System 1984 (WGS 84)")\] coordinate system. Longitude
 measures how far east or west a point is from the
 Prime Meridian.

 \"speed\"
 : A non-negative
 [`double?`](https://webidl.spec.whatwg.org/#idl-double) that represents
 the speed in meters per second, or `null` if not
 available. Speed measures how fast the device is
 moving.
 2. Set `position` to [a new
 `GeolocationPosition`](#dfn-a-new-geolocationposition) passing
 `positionData`, `acquisitionTime` and `options`.[`enableHighAccuracy`](#dom-positionoptions-enablehighaccuracy).
 3. Set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [`[[cachedPosition]]`](#dfn-cachedposition) to `position`.
 7. Stop the `timeout`.
 8. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on the [geolocation task
 source](#dfn-geolocation-task-source) with a step that
 [invokes](https://webidl.spec.whatwg.org/#invoke-a-callback-function) `successCallback` with « `position` »
 and \"`report`\".

 Dealing with failures:

 : - If acquiring a position fails, do one of the following based
 on the condition that matches the failure:

 User or system denied permission:

 : [Call back with
 error](#dfn-call-back-with-error) passing
 `errorCallback` and
 [`PERMISSION_DENIED`](#dom-geolocationpositionerror-permission_denied).

 ::::
 :::
 Note[: Browser permission VS OS permission]
 :::

 On certain platforms, there can be a circumstance where
 the user has
 [granted](https://www.w3.org/TR/permissions/#dfn-granted) the user agent permission to use
 Geolocation at the browser-level, but the permission to
 access location services has been denied at the OS level.
 ::::

 Timeout elapsed:
 : [Call back with
 error](#dfn-call-back-with-error) with
 `errorCallback` and
 [`TIMEOUT`](#dom-geolocationpositionerror-timeout).

 Data acquisition error or any other reason:
 : [Call back with
 error](#dfn-call-back-with-error) passing
 `errorCallback` and
 [`POSITION_UNAVAILABLE`](#dom-geolocationpositionerror-position_unavailable).

::: header-wrapper
### 6.7 Call back with error

When instructed to [call back with error], given an
[`PositionErrorCallback?`](#dom-positionerrorcallback)
`callback` and an
[`unsigned short`](https://webidl.spec.whatwg.org/#idl-unsigned-short) `code`:

1. If `callback` is null,
 return.
2. Let `error` be a
 newly created
 [`GeolocationPositionError`](#dom-geolocationpositionerror) instance
 whose
 [`code`](#dom-geolocationpositionerror-code) attribute is initialized to
 `code`.
3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on the [geolocation task
 source](#dfn-geolocation-task-source) with a step that
 [invokes](https://webidl.spec.whatwg.org/#invoke-a-callback-function) `callback` with « `error` » and \"`report`\".

::: header-wrapper
## 7. [`PositionOptions`] dictionary

```
WebIDLdictionary PositionOptions {
 boolean enableHighAccuracy = false;
 [Clamp] unsigned long timeout = 0xFFFFFFFF;
 [Clamp] unsigned long maximumAge = 0;
};
```

::: header-wrapper
### 7.1 `enableHighAccuracy` member

The [`enableHighAccuracy`] member provides
a hint that the application would like to receive the most accurate
location data. The intended purpose of this member is to allow
applications to inform the implementation that they do not require high
accuracy geolocation fixes and, therefore, the implementation *MAY*
avoid using geolocation providers that consume a significant amount of
power (e.g., GPS).

Note[: A word of warning about enableHighAccuracy]

The `enableHighAccuracy` member can result in slower response times or
increased power consumption. The user might also disable this
capability, or the device might not be able to provide more accurate
results than if the flag wasn\'t specified.

::: header-wrapper
### 7.2 `timeout` member

The [`timeout`] member denotes the maximum length of time,
expressed in milliseconds, before [acquiring a
position](#dfn-acquire-a-position) expires.

Note[: When is the timeout calculated?]

The time spent waiting for the document to become visible and for
[obtaining permission to use the
API](#dfn-checking-permission) is not
included in the period covered by the
[`timeout`](#dom-positionoptions-timeout) member. The
[`timeout`](#dom-positionoptions-timeout) member only applies when [acquiring a
position](#dfn-acquire-a-position) begins.

Note[: Immediate cancellation]

`options`.[`timeout`](#dom-positionoptions-timeout) value 0 can cause immediate failures.

::: header-wrapper
### 7.3 `maximumAge` member

The [`maximumAge`] member indicates that the web application is
willing to accept a cached position whose age is no greater than the
specified time in milliseconds.

MDN[✅]{title="This feature is in all major engines."}

[GeolocationPosition](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationPosition "The GeolocationPosition interface represents the position of the concerned device at a given time. The position, represented by a GeolocationCoordinates object, comprehends the 2D position of the device, on a spheroid representing the Earth, but also its altitude and its speed.")

This feature is in all major engines.

 ------------------ -----
 Chrome ?
 Chrome Android ?
 Edge No
 Edge Mobile ?
 Firefox ?
 Firefox Android ?
 Opera 16+
 Opera Android 16+
 Safari ?
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

::: header-wrapper
## 8. `GeolocationPosition` interface

```
WebIDL[Exposed=Window, SecureContext]
interface GeolocationPosition {
 readonly attribute GeolocationCoordinates coords;
 readonly attribute EpochTimeStamp timestamp;
 [Default] object toJSON();
};
```

MDN[✅]{title="This feature is in all major engines."}

[GeolocationPosition/coords](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationPosition/coords "The GeolocationPosition.coords read-only property returns a GeolocationCoordinates object representing a geographic position. It contains the location, that is longitude and latitude on the Earth, the altitude, and the speed of the object concerned, regrouped inside the returned value. It also contains accuracy information about these values.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera 16+
 Opera Android 16+
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

::: header-wrapper
### 8.1 `coords` attribute

The [`coords`] attribute contains geographic coordinates.

MDN[✅]{title="This feature is in all major engines."}

[GeolocationPosition/timestamp](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationPosition/timestamp "The GeolocationPosition.timestamp read-only property represents the date and time that the position was acquired by the device.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera 16+
 Opera Android 16+
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

::: header-wrapper
### 8.2 `timestamp` attribute

The [`timestamp`] attribute represents the time when the
geographic position of the device was acquired.

::: header-wrapper
### 8.3 `toJSON()` method

The [`toJSON()`] method returns a JSON
representation of the
[`GeolocationPosition`](#dom-geolocationposition) object.

::: header-wrapper
### 8.4 Internal slots

Instances of
[`GeolocationPosition`](#dom-geolocationposition) are created with
the internal slots in the following table:

 -------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Internal slot Description
 [\[\[isHighAccuracy\]\]] A [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean) that records the value of the [`enableHighAccuracy`](#dom-positionoptions-enablehighaccuracy) member when this [`GeolocationPosition`](#dom-geolocationposition) is [created](#dfn-a-new-geolocationposition).
 -------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
### 8.5 Task sources

The following [task
source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source) is defined by this specification.

The [geolocation task source]
: Used by this specification to queue up non-blocking
 [`PositionCallback`](#dom-positioncallback) and
 [`PositionErrorCallback`](#dom-positionerrorcallback) when
 performing [position
 requests](#dfn-request-a-position).

MDN[✅]{title="This feature is in all major engines."}

[GeolocationCoordinates](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationCoordinates "The GeolocationCoordinates interface represents the position and altitude of the device on Earth, as well as the accuracy with which these properties are calculated.")

This feature is in all major engines.

 ------------------ ------
 Chrome ?
 Chrome Android ?
 Edge No
 Edge Mobile ?
 Firefox ?
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari ?
 Safari iOS ?
 Samsung Internet 1.0+
 WebView Android ?
 ------------------ ------

::: header-wrapper
## 9. [`GeolocationCoordinates`] interface

```
WebIDL[Exposed=Window, SecureContext]
interface GeolocationCoordinates {
 readonly attribute double accuracy;
 readonly attribute double latitude;
 readonly attribute double longitude;
 readonly attribute double? altitude;
 readonly attribute double? altitudeAccuracy;
 readonly attribute double? heading;
 readonly attribute double? speed;
 [Default] object toJSON();
};
```

MDN[✅]{title="This feature is in all major engines."}

[GeolocationCoordinates/accuracy](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationCoordinates/accuracy "The GeolocationCoordinates.accuracy read-only property is a strictly positive double representing the accuracy, with a 95% confidence level, of the GeolocationCoordinates.latitude and GeolocationCoordinates.longitude properties expressed in meters.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

MDN[✅]{title="This feature is in all major engines."}

[GeolocationCoordinates/latitude](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationCoordinates/latitude "The GeolocationCoordinates.latitude read-only property is a double representing the latitude of the position in decimal degrees.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

MDN[✅]{title="This feature is in all major engines."}

[GeolocationCoordinates/longitude](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationCoordinates/longitude "The GeolocationCoordinates interface's read-only longitude property is a number which represents the longitude of a geographical position, specified in decimal degrees. Together with a timestamp, given as Unix time in milliseconds, indicating a time of measurement, the GeolocationCoordinates object is part of the GeolocationPosition interface, which is the object type returned by Geolocation API functions that obtain and return a geographical position.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

::: header-wrapper
### 9.1 `latitude`, `longitude`, and `accuracy` attributes

The [`latitude`] and
[`longitude`] attributes denote the position, specified as a
real number of degrees, in the
\[[WGS84](#bib-wgs84 "World Geodetic System 1984 (WGS 84)")\] coordinate system.

The [`accuracy`] attribute denotes the position accuracy radius
in meters.

MDN[✅]{title="This feature is in all major engines."}

[GeolocationCoordinates/altitude](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationCoordinates/altitude "The GeolocationCoordinates.altitude read-only property is a double representing the altitude of the position in meters above the WGS84 ellipsoid (which defines the nominal sea level surface). This value is null if the implementation cannot provide this data.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

MDN[✅]{title="This feature is in all major engines."}

[GeolocationCoordinates/altitudeAccuracy](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationCoordinates/altitudeAccuracy "The GeolocationCoordinates.altitudeAccuracy read-only property is a strictly positive double representing the accuracy, with a 95% confidence level, of the altitude expressed in meters. This value is null if the implementation doesn't support measuring altitude.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

::: header-wrapper
### 9.2 `altitude` and `altitudeAccuracy` attributes

The [`altitude`] attribute denotes the height of the position,
specified in meters above the
\[[WGS84](#bib-wgs84 "World Geodetic System 1984 (WGS 84)")\] ellipsoid.

The [`altitudeAccuracy`] attribute represents the altitude accuracy in
meters (e.g., `10` meters).

MDN[✅]{title="This feature is in all major engines."}

[GeolocationCoordinates/heading](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationCoordinates/heading "The GeolocationCoordinates.heading read-only property is a double representing the direction in which the device is traveling. This value, specified in degrees, indicates how far off from heading due north the device is. 0 degrees represents true north, and the direction is determined clockwise (which means that east is 90 degrees and west is 270 degrees). If GeolocationCoordinates.speed is 0, heading is NaN. If the device is not able to provide heading information, this value is null.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

::: header-wrapper
### 9.3 `heading` attribute

The [`heading`] attribute denotes the direction of travel of the
hosting device and is specified in degrees, where 0° ≤ heading \< 360°,
counting clockwise relative to the true north.

MDN[✅]{title="This feature is in all major engines."}

[GeolocationCoordinates/speed](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationCoordinates/speed "The GeolocationCoordinates.speed read-only property is a double representing the velocity of the device in meters per second. This value is null if the implementation is not able to measure it.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 5+
 Safari iOS 3+
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

::: header-wrapper
### 9.4 `speed` attribute

The [`speed`] attribute denotes the magnitude of the
horizontal component of the hosting device\'s current velocity in meters
per second.

::: header-wrapper
### 9.5 `toJSON()` method

The [`toJSON()`] method returns a JSON
representation of the
[`GeolocationCoordinates`](#dom-geolocationcoordinates) object.

::: header-wrapper
### 9.6 Constructing a `GeolocationPosition`

[A new `GeolocationPosition`] is constructed with
[map](https://infra.spec.whatwg.org/#ordered-map) `positionData`,
[`EpochTimeStamp`](https://www.w3.org/TR/hr-time-3/#typedefdef-epochtimestamp) `timestamp` and boolean `isHighAccuracy` by
performing the following steps:

1. Let `coords` be a
 newly created
 [`GeolocationCoordinates`](#dom-geolocationcoordinates) instance.
2. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `key` → `value` in
 `positionData`:
 1. Set `coords`\'s
 attribute named `key` to `value`.
3. Return a newly created
 [`GeolocationPosition`](#dom-geolocationposition) instance with
 its
 [`coords`](#dom-geolocationposition-coords) attribute initialized to
 `coords` and
 [`timestamp`](#dom-geolocationposition-timestamp) attribute initialized to
 `timestamp`, and its
 [`[[isHighAccuracy]]`](#dfn-ishighaccuracy) internal
 slot set to `isHighAccuracy`.

MDN[✅]{title="This feature is in all major engines."}

[GeolocationPositionError](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationPositionError "The GeolocationPositionError interface represents the reason of an error occurring when using the geolocating device.")

This feature is in all major engines.

 ------------------ -----
 Chrome ?
 Chrome Android ?
 Edge No
 Edge Mobile ?
 Firefox ?
 Firefox Android ?
 Opera 16+
 Opera Android 16+
 Safari ?
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

::: header-wrapper
## 10. [`GeolocationPositionError`] interface

```
WebIDL[Exposed=Window]
interface GeolocationPositionError {
 const unsigned short PERMISSION_DENIED = 1;
 const unsigned short POSITION_UNAVAILABLE = 2;
 const unsigned short TIMEOUT = 3;
 readonly attribute unsigned short code;
 readonly attribute DOMString message;
};
```

::: header-wrapper
### 10.1 Constants

[`PERMISSION_DENIED`] (numeric value 1)
: [Request a
 position](#dfn-request-a-position) failed because the user
 denied permission to use the API or the request was made from an
 [non-secure
 context](https://html.spec.whatwg.org/multipage/webappapis.html#non-secure-context).

[`POSITION_UNAVAILABLE`] (numeric value 2)
: [Acquire a
 position](#dfn-acquire-a-position) failed.

[`TIMEOUT`] (numeric value 3)
: The length of time specified by the
 [`timeout`](#dom-positionoptions-timeout) member has elapsed before the user
 agent could successfully [acquire a
 position](#dfn-acquire-a-position).

MDN[✅]{title="This feature is in all major engines."}

[GeolocationPositionError/code](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationPositionError/code "The GeolocationPositionError.code read-only property is an unsigned short representing the error code.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera 16+
 Opera Android 16+
 Safari 5+
 Safari iOS ?
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

::: header-wrapper
### 10.2 `code` attribute

The [`code`] attribute returns the value it was [initialized
to](#dfn-call-back-with-error) (see
[10.1 Constants](#constants)
for possible values).

MDN[✅]{title="This feature is in all major engines."}

[GeolocationPositionError/message](https://developer.mozilla.org/en-US/docs/Web/API/GeolocationPositionError/message "The GeolocationPositionError.message read-only property returns a human-readable string describing the details of the error.")

This feature is in all major engines.

 ------------------ ------
 Chrome 5+
 Chrome Android ?
 Edge 12+
 Edge Mobile ?
 Firefox 3.5+
 Firefox Android ?
 Opera 16+
 Opera Android 16+
 Safari 5+
 Safari iOS ?
 Samsung Internet ?
 WebView Android 37+
 ------------------ ------

::: header-wrapper
### 10.3 `message` attribute

The [`message`] attribute is a developer-friendly textual
description of the
[`code`](#dom-geolocationpositionerror-code) attribute.

Note[: Don\'t show .message to users!]

The purpose of
[`GeolocationPositionError`](#dom-geolocationpositionerror)\'s
[`message`](#dom-geolocationpositionerror-message) attribute is to assist developers with
debugging. For legacy reasons, this attribute does not supply language
or base direction metadata and is only localized into English.
Developers are advised to use
[`GeolocationPositionError`](#dom-geolocationpositionerror)\'s
[`code`](#dom-geolocationpositionerror-code) attribute to create a localized
experience.

MDN[🚫]{title="This feature has limited support."}

[Headers/Permissions-Policy/geolocation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Permissions-Policy/geolocation "The HTTP Permissions-Policy header geolocation directive controls whether the current document is allowed to use the Geolocation Interface.")

This feature has limited support.

 ------------------ -----
 Chrome ?
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 74+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari No
 Safari iOS ?
 Samsung Internet ?
 WebView Android ?
 ------------------ -----

::: header-wrapper
## 11. Permissions policy

This specification defines a [policy-controlled
feature](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature) identified by the token string
[`"geolocation"`](#dfn-geolocation). Its [default
allowlist](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature-default-allowlist) is
[\'self\'](https://www.w3.org/TR/permissions-policy-1/#default-allowlist-self).

::: header-wrapper
## 12. Emulation

For the purposes of user-agent automation and application testing, this
document defines geolocation emulations.

Each [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) has an associated [emulated position
data], which is data representing
[`GeolocationCoordinates`](#dom-geolocationcoordinates),
[`GeolocationPositionError`](#dom-geolocationpositionerror) or null,
initially null.

To [set emulated position data],
given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable) `navigable` and an
`emulatedPositionData`:

1. Assert `emulatedPositionData` is either null, a
 [`GeolocationCoordinates`](#dom-geolocationcoordinates), or a
 [`GeolocationPositionError`](#dom-geolocationpositionerror).
2. Let `traversable` be `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).
3. If `traversable` is not null:
 1. Set `traversable`\'s associated [emulated position
 data](#dfn-emulated-position-data) to
 `emulatedPositionData`.
 2. User agents *MUST* consider this as a \"significant change\" in
 the [wait for a significant change of geographic
 position](#wait-for-change) step.

To [get emulated position data], given
[`Geolocation`](#dom-geolocation) `geolocation`:

1. Let `navigable` be `geolocation`\'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)\'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)\'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).
2. If `navigable` is null, return null.
3. Let `traversable` be `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).
4. If `traversable` is null, return null.
5. Return `traversable`\'s associated [emulated position
 data](#dfn-emulated-position-data).

::: header-wrapper
## 13. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

The key words *MAY*, *MUST*, and *RECOMMENDED* in this document are to
be interpreted as described in [BCP
14](https://www.rfc-editor.org/info/bcp14)
\[[RFC2119](#bib-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels")\]
\[[RFC8174](#bib-rfc8174 "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words")\] when, and only when, they appear in all capitals,
as shown here.

::: header-wrapper
## A. IDL Index

```
WebIDLpartial interface Navigator {
 [SameObject] readonly attribute Geolocation geolocation;
};

[Exposed=Window]
interface Geolocation {
 undefined getCurrentPosition (
 PositionCallback successCallback,
 optional PositionErrorCallback? errorCallback = null,
 optional PositionOptions options =
 );

 long watchPosition (
 PositionCallback successCallback,
 optional PositionErrorCallback? errorCallback = null,
 optional PositionOptions options =
 );

 undefined clearWatch (long watchId);
};

callback PositionCallback = undefined (
 GeolocationPosition position
);

callback PositionErrorCallback = undefined (
 GeolocationPositionError positionError
);

dictionary PositionOptions {
 boolean enableHighAccuracy = false;
 [Clamp] unsigned long timeout = 0xFFFFFFFF;
 [Clamp] unsigned long maximumAge = 0;
};

[Exposed=Window, SecureContext]
interface GeolocationPosition {
 readonly attribute GeolocationCoordinates coords;
 readonly attribute EpochTimeStamp timestamp;
 [Default] object toJSON();
};

[Exposed=Window, SecureContext]
interface GeolocationCoordinates {
 readonly attribute double accuracy;
 readonly attribute double latitude;
 readonly attribute double longitude;
 readonly attribute double? altitude;
 readonly attribute double? altitudeAccuracy;
 readonly attribute double? heading;
 readonly attribute double? speed;
 [Default] object toJSON();
};

[Exposed=Window]
interface GeolocationPositionError {
 const unsigned short PERMISSION_DENIED = 1;
 const unsigned short POSITION_UNAVAILABLE = 2;
 const unsigned short TIMEOUT = 3;
 readonly attribute unsigned short code;
 readonly attribute DOMString message;
};
```

::: header-wrapper
## B. Index

::: header-wrapper
### B.1 Terms defined by this specification

- [A new
 GeolocationPosition](#dfn-a-new-geolocationposition)
 [§9.6]
- [`accuracy`](#dom-geolocationcoordinates-accuracy)
 attribute for `GeolocationCoordinates` [§9.1]
- [acquire a position](#dfn-acquire-a-position)
 [§6.6]
- [`altitude`](#dom-geolocationcoordinates-altitude)
 attribute for `GeolocationCoordinates` [§9.2]
- [`altitudeAccuracy`](#dom-geolocationcoordinates-altitudeaccuracy)
 attribute for `GeolocationCoordinates` [§9.2]
- [`[[cachedPosition]]`](#dfn-cachedposition) internal slot
 for `Geolocation` [§6.1]
- [call back with error](#dfn-call-back-with-error)
 [§6.7]
- [checking permission](#dfn-checking-permission)
 [§3.4]
- [`clearWatch()`](#dom-geolocation-clearwatch) method for
 `Geolocation` [§6.4]
- [`code`](#dom-geolocationpositionerror-code) attribute
 for `GeolocationPositionError` [§10.2]
- [`coords`](#dom-geolocationposition-coords) attribute for
 `GeolocationPosition` [§8.1]
- [emulated position data](#dfn-emulated-position-data)
 [§12.]
- [`enableHighAccuracy`](#dom-positionoptions-enablehighaccuracy)
 member for `PositionOptions` [§7.1]
- [`geolocation`](#dom-navigator-geolocation) attribute for
 `Navigator` [§5.1]
- [`Geolocation`](#dom-geolocation) interface
 [§6.]
- [geolocation task source](#dfn-geolocation-task-source)
 [§8.5]
- [`"geolocation"`](#dfn-geolocation) [§3.4]
- [`GeolocationCoordinates`](#dom-geolocationcoordinates)
 interface [§9.]
- [`GeolocationPosition`](#dom-geolocationposition)
 interface [§8.]
- [`GeolocationPositionError`](#dom-geolocationpositionerror)
 interface [§10.]
- [get emulated position
 data](#dfn-get-emulated-position-data)
 [§12.]
- [`getCurrentPosition`](#dom-geolocation-getcurrentposition)
 method for `Geolocation` [§6.2]
- [`heading`](#dom-geolocationcoordinates-heading)
 attribute for `GeolocationCoordinates` [§9.3]
- [`[[isHighAccuracy]]`](#dfn-ishighaccuracy) internal slot
 for `GeolocationPosition` [§8.4]
- [`latitude`](#dom-geolocationcoordinates-latitude)
 attribute for `GeolocationCoordinates` [§9.1]
- [`longitude`](#dom-geolocationcoordinates-longitude)
 attribute for `GeolocationCoordinates` [§9.1]
- [`maximumAge`](#dom-positionoptions-maximumage) member
 for `PositionOptions` [§7.3]
- [`message`](#dom-geolocationpositionerror-message)
 attribute for `GeolocationPositionError` [§10.3]
- [`PERMISSION_DENIED`](#dom-geolocationpositionerror-permission_denied)
 [§10.1]
- [`POSITION_UNAVAILABLE`](#dom-geolocationpositionerror-position_unavailable)
 [§10.1]
- [`PositionCallback`](#dom-positioncallback)
 [§6.]
- [`PositionErrorCallback`](#dom-positionerrorcallback)
 [§6.]
- [`PositionOptions`](#dom-positionoptions) dictionary
 [§7.]
- [request a position](#dfn-request-a-position)
 [§6.5]
- [set emulated position
 data](#dfn-set-emulated-position-data)
 [§12.]
- [`speed`](#dom-geolocationcoordinates-speed) attribute
 for `GeolocationCoordinates` [§9.4]
- [`timeout`](#dom-positionoptions-timeout) member for
 `PositionOptions` [§7.2]
- [`TIMEOUT`](#dom-geolocationpositionerror-timeout)
 [§10.1]
- [`timestamp`](#dom-geolocationposition-timestamp)
 attribute for `GeolocationPosition` [§8.2]
- toJSON()
 - [method for
 `GeolocationPosition`](#dom-geolocationposition-tojson)
 [§8.3]
 - [method for
 `GeolocationCoordinates`](#dom-geolocationcoordinates-tojson)
 [§9.5]
- [`[[watchIDs]]`](#dfn-watchids) internal slot for
 `Geolocation` [§6.1]
- [`watchPosition`](#dom-geolocation-watchposition) method
 for `Geolocation` [§6.3]

::: header-wrapper
### B.2 Terms defined by reference

- \[[HR-TIME](#bib-hr-time)\] defines the
 following:
 - [`EpochTimeStamp`]
- \[[HTML](#bib-html)\] defines the
 following:
 - [`allow` attribute (for `iframe`
 element)]
 - [allowed to use]
 - [associated Document]
 - [environment settings
 object]
 - [fully active (for
 `Document`)]
 - [`iframe` element]
 - [In parallel]
 - [navigable]
 - [navigates]
 - [`Navigator` interface]
 - [node navigable]
 - [non-secure context]
 - [origin]
 - [page visibility change
 steps]
 - [Queue a task]
 - [realm (for environment settings
 object)]
 - [relevant global object]
 - [task source]
 - [top-level traversable]
 - [top-level traversable (for
 `navigable`)]
 - [visibility state (for
 `Document`)]
- \[[INFRA](#bib-infra)\] defines the
 following:
 - [Append (for `list`)]
 - [contains (for `list`)]
 - [For each (for `map`)]
 - [implementation-defined]
 - [item (for `list`)]
 - [list]
 - [map]
 - [Remove (for `list`)]
- \[[PERMISSIONS](#bib-permissions)\]
 defines the following:
 - [default powerful feature]
 - [express permission]
 - [get the current permission
 state]
 - [granted (for `permission`)]
 - [lifetimes (for `permission`)]
 - [name (for powerful feature)]
 - [`name` (for
 `PermissionDescriptor`)]
 - [permission]
 - [permission state]
 - [`PermissionDescriptor`]
 - [powerful feature]
 - [request permission to use]
- \[[PERMISSIONS-POLICY](#bib-permissions-policy)\] defines the following:
 - [\'self\' (for default
 allowlist)]
 - [default allowlist (for policy-controlled
 feature)]
 - [policy-controlled feature]
- \[[WEBIDL](#bib-webidl)\] defines the
 following:
 - [`boolean` type]
 - [`[Clamp]` extended attribute]
 - [`[Default]` extended
 attribute]
 - [`DOMString` interface]
 - [`double` type]
 - [`[Exposed]` extended
 attribute]
 - [invokes]
 - [`long` type]
 - [`object` type]
 - [`[SameObject]` extended
 attribute]
 - [`[SecureContext]` extended
 attribute]
 - [this]
 - [`undefined` type]
 - [`unsigned long` type]
 - [`unsigned short` type]

::: header-wrapper
## C. Acknowledgments

*This section is non-normative.*

This specification builds upon earlier work in the industry, including
research by Aza Raskin, Google Gears Geolocation API, and
LocationAware.org.

Thanks also to Alec Berntson, Alissa Cooper, Steve Block, Greg Bolsinga,
Lars Erik Bolstad, Aaron Boodman, Dave Burke, Chris Butler, Max
Froumentin, Shyam Habarakada, Marcin Hanclik, Ian Hickson, Brad Lassey,
Angel Machin, Cameron McCormack, Daniel Park, Stuart Parmenter, Olli
Pettay, Chris Prince, Arun Ranganathan, Carl Reed, Thomas Roessler, Dirk
Segers, Allan Thomson, Martin Thomson, Doug Turner, Erik Wilde, Matt
Womer, and Mohamed Zergaoui.

::: header-wrapper
## D. Change log

*This section is non-normative.*

Since publication as a [W3C]
Recommendation in 2022, Geolocation has received the following normative
changes:

- [Add missing latitude
 definition](https://github.com/w3c/geolocation/commit/229574b)
 ([#208](https://github.com/w3c/geolocation/pull/208))
- [Correction: Clarify that only the emulated error code is
 used](https://github.com/w3c/geolocation/commit/0cc35fa)
 ([#187](https://github.com/w3c/geolocation/pull/187))
- [Addition: support geolocation
 emulation](https://github.com/w3c/geolocation/commit/69cc724)
 ([#183](https://github.com/w3c/geolocation/pull/183))
- [Correction: Use null instead of NaN when
 stationary](https://github.com/w3c/geolocation/commit/9d5829e)
 ([#173](https://github.com/w3c/geolocation/pull/173))
- [Correction: Update acquisition algorithm to define data types and
 han...](https://github.com/w3c/geolocation/commit/22ed7a4)
- [Addition: Define units for
 accuracy](https://github.com/w3c/geolocation/commit/a30d713)
 ([#162](https://github.com/w3c/geolocation/pull/162))
- [Correction: check for non-secure
 contexts](https://github.com/w3c/geolocation/commit/c2fdd74)
 ([#157](https://github.com/w3c/geolocation/pull/157))
- [Addition: expose .toJSON() on GeolocationCoordinates +
 GeolocationPos...](https://github.com/w3c/geolocation/commit/09b48e6)
- [Correction: Clarify units and reference geodetic system for latitude
 ...](https://github.com/w3c/geolocation/commit/74b1dd0)

Since First Public Working Draft in 2021, until it was published as a
[W3C] Recommendation in 2022,
Geolocation received the following normative changes:

[Permalink](#dfn-geolocation)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-dfn-geolocation-1 "§ 6.5 Request a position")
- [§ 6.6 Acquire a
 position](#ref-for-dfn-geolocation-2 "§ 6.6 Acquire a position")
- [§ 11. Permissions
 policy](#ref-for-dfn-geolocation-3 "§ 11. Permissions policy")

[Permalink](#dfn-checking-permission)

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dfn-checking-permission-1 "§ 1. Introduction")
- [§ 3.1 User
 consent](#ref-for-dfn-checking-permission-2 "§ 3.1 User consent")
- [§ 7.2 timeout
 member](#ref-for-dfn-checking-permission-3 "§ 7.2 timeout member")

[Permalink](#dom-navigator-geolocation)
[exported]
[IDL](#webidl-1776506972 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. Extensions to the Navigator
 interface](#ref-for-dom-navigator-geolocation-1 "§ 5. Extensions to the Navigator interface")
- [§ A. IDL
 Index](#ref-for-dom-navigator-geolocation-2 "§ A. IDL Index")

[Permalink](#dom-geolocation)
[exported]

**Referenced in:**

- [§ 5. Extensions to the Navigator
 interface](#ref-for-dom-geolocation-1 "§ 5. Extensions to the Navigator interface")
- [§ 6.1 Internal
 slots](#ref-for-dom-geolocation-2 "§ 6.1 Internal slots")
- [§ 6.5 Request a
 position](#ref-for-dom-geolocation-3 "§ 6.5 Request a position")
- [§ 12. Emulation](#ref-for-dom-geolocation-4 "§ 12. Emulation")
- [§ A. IDL Index](#ref-for-dom-geolocation-5 "§ A. IDL Index")

[Permalink](#dom-positioncallback)
[exported]

**Referenced in:**

- [§ 6. Geolocation interface and
 callbacks](#ref-for-dom-positioncallback-1 "§ 6. Geolocation interface and callbacks")
 [(2)](#ref-for-dom-positioncallback-2 "Reference 2")
- [§ 6.5 Request a
 position](#ref-for-dom-positioncallback-3 "§ 6.5 Request a position")
- [§ 6.6 Acquire a
 position](#ref-for-dom-positioncallback-4 "§ 6.6 Acquire a position")
- [§ 8.5 Task
 sources](#ref-for-dom-positioncallback-5 "§ 8.5 Task sources")
- [§ A. IDL Index](#ref-for-dom-positioncallback-6 "§ A. IDL Index")
 [(2)](#ref-for-dom-positioncallback-7 "Reference 2")

[Permalink](#dom-positionerrorcallback)
[exported]

**Referenced in:**

- [§ 6. Geolocation interface and
 callbacks](#ref-for-dom-positionerrorcallback-1 "§ 6. Geolocation interface and callbacks")
 [(2)](#ref-for-dom-positionerrorcallback-2 "Reference 2")
- [§ 6.5 Request a
 position](#ref-for-dom-positionerrorcallback-3 "§ 6.5 Request a position")
- [§ 6.6 Acquire a
 position](#ref-for-dom-positionerrorcallback-4 "§ 6.6 Acquire a position")
- [§ 6.7 Call back with
 error](#ref-for-dom-positionerrorcallback-5 "§ 6.7 Call back with error")
- [§ 8.5 Task
 sources](#ref-for-dom-positionerrorcallback-6 "§ 8.5 Task sources")
- [§ A. IDL
 Index](#ref-for-dom-positionerrorcallback-7 "§ A. IDL Index")
 [(2)](#ref-for-dom-positionerrorcallback-8 "Reference 2")

[Permalink](#dfn-cachedposition)

**Referenced in:**

- [§ 6.1 Internal
 slots](#ref-for-dfn-cachedposition-1 "§ 6.1 Internal slots")
- [§ 6.6 Acquire a
 position](#ref-for-dfn-cachedposition-2 "§ 6.6 Acquire a position")
 [(2)](#ref-for-dfn-cachedposition-3 "Reference 2")

[Permalink](#dfn-watchids)

**Referenced in:**

- [§ 6.3 watchPosition()
 method](#ref-for-dfn-watchids-1 "§ 6.3 watchPosition() method")
- [§ 6.4 clearWatch()
 method](#ref-for-dfn-watchids-2 "§ 6.4 clearWatch() method")
- [§ 6.5 Request a
 position](#ref-for-dfn-watchids-3 "§ 6.5 Request a position")
- [§ 6.6 Acquire a
 position](#ref-for-dfn-watchids-4 "§ 6.6 Acquire a position")

[Permalink](#dom-geolocation-getcurrentposition)
[exported]
[IDL](#webidl-212590439 "Jump to IDL declaration")

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dom-geolocation-getcurrentposition-1 "§ 1. Introduction")
- [§ 2.4 Handling
 errors](#ref-for-dom-geolocation-getcurrentposition-2 "§ 2.4 Handling errors")
- [§ 3.1 User
 consent](#ref-for-dom-geolocation-getcurrentposition-3 "§ 3.1 User consent")
- [§ 6. Geolocation interface and
 callbacks](#ref-for-dom-geolocation-getcurrentposition-4 "§ 6. Geolocation interface and callbacks")
- [§ A. IDL
 Index](#ref-for-dom-geolocation-getcurrentposition-5 "§ A. IDL Index")

[Permalink](#dom-geolocation-watchposition)
[exported]
[IDL](#webidl-212590439 "Jump to IDL declaration")

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dom-geolocation-watchposition-1 "§ 1. Introduction")
- [§ 2.4 Handling
 errors](#ref-for-dom-geolocation-watchposition-2 "§ 2.4 Handling errors")
- [§ 3.1 User
 consent](#ref-for-dom-geolocation-watchposition-3 "§ 3.1 User consent")
- [§ 6. Geolocation interface and
 callbacks](#ref-for-dom-geolocation-watchposition-4 "§ 6. Geolocation interface and callbacks")
- [§ A. IDL
 Index](#ref-for-dom-geolocation-watchposition-5 "§ A. IDL Index")

[Permalink](#dom-geolocation-clearwatch)
[exported]
[IDL](#webidl-212590439 "Jump to IDL declaration")

**Referenced in:**

- [§ 2.3 Stop watching a
 position](#ref-for-dom-geolocation-clearwatch-1 "§ 2.3 Stop watching a position")
- [§ 6. Geolocation interface and
 callbacks](#ref-for-dom-geolocation-clearwatch-2 "§ 6. Geolocation interface and callbacks")
- [§ A. IDL
 Index](#ref-for-dom-geolocation-clearwatch-3 "§ A. IDL Index")

[Permalink](#dfn-request-a-position)

**Referenced in:**

- [§ 6.2 getCurrentPosition()
 method](#ref-for-dfn-request-a-position-1 "§ 6.2 getCurrentPosition() method")
- [§ 6.3 watchPosition()
 method](#ref-for-dfn-request-a-position-2 "§ 6.3 watchPosition() method")
- [§ 8.5 Task
 sources](#ref-for-dfn-request-a-position-3 "§ 8.5 Task sources")
- [§ 10.1
 Constants](#ref-for-dfn-request-a-position-4 "§ 10.1 Constants")
- [§ D. Change log](#ref-for-dfn-request-a-position-5 "§ D. Change log")

[Permalink](#dfn-acquire-a-position)

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dfn-acquire-a-position-1 "§ 1. Introduction")
- [§ 2.6 Using
 timeout](#ref-for-dfn-acquire-a-position-2 "§ 2.6 Using timeout")
- [§ 6.5 Request a
 position](#ref-for-dfn-acquire-a-position-3 "§ 6.5 Request a position")
 [(2)](#ref-for-dfn-acquire-a-position-4 "Reference 2")
- [§ 7.2 timeout
 member](#ref-for-dfn-acquire-a-position-5 "§ 7.2 timeout member")
 [(2)](#ref-for-dfn-acquire-a-position-6 "Reference 2")
- [§ 10.1
 Constants](#ref-for-dfn-acquire-a-position-7 "§ 10.1 Constants")
 [(2)](#ref-for-dfn-acquire-a-position-8 "Reference 2")
- [§ D. Change log](#ref-for-dfn-acquire-a-position-9 "§ D. Change log")

[Permalink](#dfn-call-back-with-error)

**Referenced in:**

- [§ 6.2 getCurrentPosition()
 method](#ref-for-dfn-call-back-with-error-1 "§ 6.2 getCurrentPosition() method")
- [§ 6.3 watchPosition()
 method](#ref-for-dfn-call-back-with-error-2 "§ 6.3 watchPosition() method")
- [§ 6.5 Request a
 position](#ref-for-dfn-call-back-with-error-3 "§ 6.5 Request a position")
 [(2)](#ref-for-dfn-call-back-with-error-4 "Reference 2")
 [(3)](#ref-for-dfn-call-back-with-error-5 "Reference 3")
- [§ 6.6 Acquire a
 position](#ref-for-dfn-call-back-with-error-6 "§ 6.6 Acquire a position")
 [(2)](#ref-for-dfn-call-back-with-error-7 "Reference 2")
 [(3)](#ref-for-dfn-call-back-with-error-8 "Reference 3")
 [(4)](#ref-for-dfn-call-back-with-error-9 "Reference 4")
- [§ 10.2 code
 attribute](#ref-for-dfn-call-back-with-error-10 "§ 10.2 code attribute")

[Permalink](#dom-positionoptions)
[exported]
[IDL](#webidl-1341144555 "Jump to IDL declaration")

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dom-positionoptions-1 "§ 1. Introduction")
- [§ 2.6 Using
 timeout](#ref-for-dom-positionoptions-2 "§ 2.6 Using timeout")
- [§ 6. Geolocation interface and
 callbacks](#ref-for-dom-positionoptions-3 "§ 6. Geolocation interface and callbacks")
 [(2)](#ref-for-dom-positionoptions-4 "Reference 2")
- [§ 6.5 Request a
 position](#ref-for-dom-positionoptions-5 "§ 6.5 Request a position")
- [§ 6.6 Acquire a
 position](#ref-for-dom-positionoptions-6 "§ 6.6 Acquire a position")
- [§ 7. PositionOptions
 dictionary](#ref-for-dom-positionoptions-7 "§ 7. PositionOptions dictionary")
- [§ A. IDL Index](#ref-for-dom-positionoptions-8 "§ A. IDL Index")
 [(2)](#ref-for-dom-positionoptions-9 "Reference 2")
 [(3)](#ref-for-dom-positionoptions-10 "Reference 3")

[Permalink](#dom-positionoptions-enablehighaccuracy)
[exported]
[IDL](#webidl-1341144555 "Jump to IDL declaration")

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dom-positionoptions-enablehighaccuracy-1 "§ 1. Introduction")
- [§ 6.6 Acquire a
 position](#ref-for-dom-positionoptions-enablehighaccuracy-2 "§ 6.6 Acquire a position")
 [(2)](#ref-for-dom-positionoptions-enablehighaccuracy-3 "Reference 2")
 [(3)](#ref-for-dom-positionoptions-enablehighaccuracy-4 "Reference 3")
 [(4)](#ref-for-dom-positionoptions-enablehighaccuracy-5 "Reference 4")
- [§ 7. PositionOptions
 dictionary](#ref-for-dom-positionoptions-enablehighaccuracy-6 "§ 7. PositionOptions dictionary")
- [§ 8.4 Internal
 slots](#ref-for-dom-positionoptions-enablehighaccuracy-7 "§ 8.4 Internal slots")
- [§ A. IDL
 Index](#ref-for-dom-positionoptions-enablehighaccuracy-8 "§ A. IDL Index")

[Permalink](#dom-positionoptions-timeout)
[exported]
[IDL](#webidl-1341144555 "Jump to IDL declaration")

**Referenced in:**

- [§ 2.6 Using
 timeout](#ref-for-dom-positionoptions-timeout-1 "§ 2.6 Using timeout")
- [§ 6.6 Acquire a
 position](#ref-for-dom-positionoptions-timeout-2 "§ 6.6 Acquire a position")
- [§ 7. PositionOptions
 dictionary](#ref-for-dom-positionoptions-timeout-3 "§ 7. PositionOptions dictionary")
- [§ 7.2 timeout
 member](#ref-for-dom-positionoptions-timeout-4 "§ 7.2 timeout member")
 [(2)](#ref-for-dom-positionoptions-timeout-5 "Reference 2")
 [(3)](#ref-for-dom-positionoptions-timeout-6 "Reference 3")
- [§ 10.1
 Constants](#ref-for-dom-positionoptions-timeout-7 "§ 10.1 Constants")
- [§ A. IDL
 Index](#ref-for-dom-positionoptions-timeout-8 "§ A. IDL Index")

[Permalink](#dom-positionoptions-maximumage)
[exported]
[IDL](#webidl-1341144555 "Jump to IDL declaration")

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dom-positionoptions-maximumage-1 "§ 1. Introduction")
- [§ 6.6 Acquire a
 position](#ref-for-dom-positionoptions-maximumage-2 "§ 6.6 Acquire a position")
 [(2)](#ref-for-dom-positionoptions-maximumage-3 "Reference 2")
- [§ 7. PositionOptions
 dictionary](#ref-for-dom-positionoptions-maximumage-4 "§ 7. PositionOptions dictionary")
- [§ A. IDL
 Index](#ref-for-dom-positionoptions-maximumage-5 "§ A. IDL Index")

[Permalink](#dom-geolocationposition)
[exported]

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dom-geolocationposition-1 "§ 1. Introduction")
- [§ 6. Geolocation interface and
 callbacks](#ref-for-dom-geolocationposition-2 "§ 6. Geolocation interface and callbacks")
- [§ 6.1 Internal
 slots](#ref-for-dom-geolocationposition-3 "§ 6.1 Internal slots")
- [§ 8.3 toJSON()
 method](#ref-for-dom-geolocationposition-4 "§ 8.3 toJSON() method")
- [§ 8.4 Internal
 slots](#ref-for-dom-geolocationposition-5 "§ 8.4 Internal slots")
 [(2)](#ref-for-dom-geolocationposition-6 "Reference 2")
- [§ 9.6 Constructing a
 GeolocationPosition](#ref-for-dom-geolocationposition-7 "§ 9.6 Constructing a GeolocationPosition")
- [§ A. IDL Index](#ref-for-dom-geolocationposition-8 "§ A. IDL Index")

[Permalink](#dom-geolocationposition-coords)
[exported]
[IDL](#webidl-876485373 "Jump to IDL declaration")

**Referenced in:**

- [§ 8. GeolocationPosition
 interface](#ref-for-dom-geolocationposition-coords-1 "§ 8. GeolocationPosition interface")
- [§ 9.6 Constructing a
 GeolocationPosition](#ref-for-dom-geolocationposition-coords-2 "§ 9.6 Constructing a GeolocationPosition")
- [§ A. IDL
 Index](#ref-for-dom-geolocationposition-coords-3 "§ A. IDL Index")

[Permalink](#dom-geolocationposition-timestamp)
[exported]
[IDL](#webidl-876485373 "Jump to IDL declaration")

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-dom-geolocationposition-timestamp-1 "§ 6.6 Acquire a position")
- [§ 8. GeolocationPosition
 interface](#ref-for-dom-geolocationposition-timestamp-2 "§ 8. GeolocationPosition interface")
- [§ 9.6 Constructing a
 GeolocationPosition](#ref-for-dom-geolocationposition-timestamp-3 "§ 9.6 Constructing a GeolocationPosition")
- [§ A. IDL
 Index](#ref-for-dom-geolocationposition-timestamp-4 "§ A. IDL Index")

[Permalink](#dom-geolocationposition-tojson)
[exported]
[IDL](#webidl-876485373 "Jump to IDL declaration")

**Referenced in:**

- [§ 8. GeolocationPosition
 interface](#ref-for-dom-geolocationposition-tojson-1 "§ 8. GeolocationPosition interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationposition-tojson-2 "§ A. IDL Index")

[Permalink](#dfn-ishighaccuracy)

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-dfn-ishighaccuracy-1 "§ 6.6 Acquire a position")
- [§ 9.6 Constructing a
 GeolocationPosition](#ref-for-dfn-ishighaccuracy-2 "§ 9.6 Constructing a GeolocationPosition")

[Permalink](#dfn-geolocation-task-source)

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-dfn-geolocation-task-source-1 "§ 6.6 Acquire a position")
 [(2)](#ref-for-dfn-geolocation-task-source-2 "Reference 2")
 [(3)](#ref-for-dfn-geolocation-task-source-3 "Reference 3")
- [§ 6.7 Call back with
 error](#ref-for-dfn-geolocation-task-source-4 "§ 6.7 Call back with error")

[Permalink](#dom-geolocationcoordinates)
[exported]
[IDL](#webidl-412902343 "Jump to IDL declaration")

**Referenced in:**

- [§ 8. GeolocationPosition
 interface](#ref-for-dom-geolocationcoordinates-1 "§ 8. GeolocationPosition interface")
- [§ 9. GeolocationCoordinates
 interface](#ref-for-dom-geolocationcoordinates-2 "§ 9. GeolocationCoordinates interface")
- [§ 9.5 toJSON()
 method](#ref-for-dom-geolocationcoordinates-3 "§ 9.5 toJSON() method")
- [§ 9.6 Constructing a
 GeolocationPosition](#ref-for-dom-geolocationcoordinates-4 "§ 9.6 Constructing a GeolocationPosition")
- [§ 12.
 Emulation](#ref-for-dom-geolocationcoordinates-5 "§ 12. Emulation")
 [(2)](#ref-for-dom-geolocationcoordinates-6 "Reference 2")
- [§ A. IDL
 Index](#ref-for-dom-geolocationcoordinates-7 "§ A. IDL Index")
 [(2)](#ref-for-dom-geolocationcoordinates-8 "Reference 2")

[Permalink](#dom-geolocationcoordinates-latitude)
[exported]
[IDL](#webidl-412902343 "Jump to IDL declaration")

**Referenced in:**

- [§ 9. GeolocationCoordinates
 interface](#ref-for-dom-geolocationcoordinates-latitude-1 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationcoordinates-latitude-2 "§ A. IDL Index")

[Permalink](#dom-geolocationcoordinates-longitude)
[exported]
[IDL](#webidl-412902343 "Jump to IDL declaration")

**Referenced in:**

- [§ 9. GeolocationCoordinates
 interface](#ref-for-dom-geolocationcoordinates-longitude-1 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationcoordinates-longitude-2 "§ A. IDL Index")

[Permalink](#dom-geolocationcoordinates-accuracy)
[exported]
[IDL](#webidl-412902343 "Jump to IDL declaration")

**Referenced in:**

- [§ 9. GeolocationCoordinates
 interface](#ref-for-dom-geolocationcoordinates-accuracy-1 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationcoordinates-accuracy-2 "§ A. IDL Index")

[Permalink](#dom-geolocationcoordinates-altitude)
[exported]
[IDL](#webidl-412902343 "Jump to IDL declaration")

**Referenced in:**

- [§ 9. GeolocationCoordinates
 interface](#ref-for-dom-geolocationcoordinates-altitude-1 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationcoordinates-altitude-2 "§ A. IDL Index")

[Permalink](#dom-geolocationcoordinates-altitudeaccuracy)
[exported]
[IDL](#webidl-412902343 "Jump to IDL declaration")

**Referenced in:**

- [§ 9. GeolocationCoordinates
 interface](#ref-for-dom-geolocationcoordinates-altitudeaccuracy-1 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationcoordinates-altitudeaccuracy-2 "§ A. IDL Index")

[Permalink](#dom-geolocationcoordinates-heading)
[exported]
[IDL](#webidl-412902343 "Jump to IDL declaration")

**Referenced in:**

- [§ 9. GeolocationCoordinates
 interface](#ref-for-dom-geolocationcoordinates-heading-1 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationcoordinates-heading-2 "§ A. IDL Index")

[Permalink](#dom-geolocationcoordinates-speed)
[exported]
[IDL](#webidl-412902343 "Jump to IDL declaration")

**Referenced in:**

- [§ 9. GeolocationCoordinates
 interface](#ref-for-dom-geolocationcoordinates-speed-1 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationcoordinates-speed-2 "§ A. IDL Index")

[Permalink](#dom-geolocationcoordinates-tojson)
[exported]
[IDL](#webidl-412902343 "Jump to IDL declaration")

**Referenced in:**

- [§ 9. GeolocationCoordinates
 interface](#ref-for-dom-geolocationcoordinates-tojson-1 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationcoordinates-tojson-2 "§ A. IDL Index")

[Permalink](#dfn-a-new-geolocationposition)

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-dfn-a-new-geolocationposition-1 "§ 6.6 Acquire a position")
 [(2)](#ref-for-dfn-a-new-geolocationposition-2 "Reference 2")
- [§ 8.4 Internal
 slots](#ref-for-dfn-a-new-geolocationposition-3 "§ 8.4 Internal slots")

[Permalink](#dom-geolocationpositionerror)
[exported]
[IDL](#webidl-1281871320 "Jump to IDL declaration")

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dom-geolocationpositionerror-1 "§ 1. Introduction")
- [§ 2.4 Handling
 errors](#ref-for-dom-geolocationpositionerror-2 "§ 2.4 Handling errors")
- [§ 6. Geolocation interface and
 callbacks](#ref-for-dom-geolocationpositionerror-3 "§ 6. Geolocation interface and callbacks")
- [§ 6.6 Acquire a
 position](#ref-for-dom-geolocationpositionerror-4 "§ 6.6 Acquire a position")
- [§ 6.7 Call back with
 error](#ref-for-dom-geolocationpositionerror-5 "§ 6.7 Call back with error")
- [§ 10. GeolocationPositionError
 interface](#ref-for-dom-geolocationpositionerror-6 "§ 10. GeolocationPositionError interface")
- [§ 10.3 message
 attribute](#ref-for-dom-geolocationpositionerror-7 "§ 10.3 message attribute")
 [(2)](#ref-for-dom-geolocationpositionerror-8 "Reference 2")
- [§ 12.
 Emulation](#ref-for-dom-geolocationpositionerror-9 "§ 12. Emulation")
 [(2)](#ref-for-dom-geolocationpositionerror-10 "Reference 2")
- [§ A. IDL
 Index](#ref-for-dom-geolocationpositionerror-11 "§ A. IDL Index")
 [(2)](#ref-for-dom-geolocationpositionerror-12 "Reference 2")

[Permalink](#dom-geolocationpositionerror-permission_denied)
[exported]
[IDL](#webidl-1281871320 "Jump to IDL declaration")

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-dom-geolocationpositionerror-permission_denied-1 "§ 6.5 Request a position")
 [(2)](#ref-for-dom-geolocationpositionerror-permission_denied-2 "Reference 2")
 [(3)](#ref-for-dom-geolocationpositionerror-permission_denied-3 "Reference 3")
- [§ 6.6 Acquire a
 position](#ref-for-dom-geolocationpositionerror-permission_denied-4 "§ 6.6 Acquire a position")
- [§ 10. GeolocationPositionError
 interface](#ref-for-dom-geolocationpositionerror-permission_denied-5 "§ 10. GeolocationPositionError interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationpositionerror-permission_denied-6 "§ A. IDL Index")

[Permalink](#dom-geolocationpositionerror-position_unavailable)
[exported]
[IDL](#webidl-1281871320 "Jump to IDL declaration")

**Referenced in:**

- [§ 6.2 getCurrentPosition()
 method](#ref-for-dom-geolocationpositionerror-position_unavailable-1 "§ 6.2 getCurrentPosition() method")
- [§ 6.3 watchPosition()
 method](#ref-for-dom-geolocationpositionerror-position_unavailable-2 "§ 6.3 watchPosition() method")
- [§ 6.6 Acquire a
 position](#ref-for-dom-geolocationpositionerror-position_unavailable-3 "§ 6.6 Acquire a position")
- [§ 10. GeolocationPositionError
 interface](#ref-for-dom-geolocationpositionerror-position_unavailable-4 "§ 10. GeolocationPositionError interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationpositionerror-position_unavailable-5 "§ A. IDL Index")

[Permalink](#dom-geolocationpositionerror-timeout)
[exported]
[IDL](#webidl-1281871320 "Jump to IDL declaration")

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-dom-geolocationpositionerror-timeout-1 "§ 6.6 Acquire a position")
- [§ 10. GeolocationPositionError
 interface](#ref-for-dom-geolocationpositionerror-timeout-2 "§ 10. GeolocationPositionError interface")
- [§ A. IDL
 Index](#ref-for-dom-geolocationpositionerror-timeout-3 "§ A. IDL Index")

[Permalink](#dom-geolocationpositionerror-code)
[exported]
[IDL](#webidl-1281871320 "Jump to IDL declaration")

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-dom-geolocationpositionerror-code-1 "§ 6.6 Acquire a position")
- [§ 6.7 Call back with
 error](#ref-for-dom-geolocationpositionerror-code-2 "§ 6.7 Call back with error")
- [§ 10. GeolocationPositionError
 interface](#ref-for-dom-geolocationpositionerror-code-3 "§ 10. GeolocationPositionError interface")
- [§ 10.3 message
 attribute](#ref-for-dom-geolocationpositionerror-code-4 "§ 10.3 message attribute")
 [(2)](#ref-for-dom-geolocationpositionerror-code-5 "Reference 2")
- [§ A. IDL
 Index](#ref-for-dom-geolocationpositionerror-code-6 "§ A. IDL Index")

[Permalink](#dom-geolocationpositionerror-message)
[exported]
[IDL](#webidl-1281871320 "Jump to IDL declaration")

**Referenced in:**

- [§ 10. GeolocationPositionError
 interface](#ref-for-dom-geolocationpositionerror-message-1 "§ 10. GeolocationPositionError interface")
- [§ 10.3 message
 attribute](#ref-for-dom-geolocationpositionerror-message-2 "§ 10.3 message attribute")
- [§ A. IDL
 Index](#ref-for-dom-geolocationpositionerror-message-3 "§ A. IDL Index")

[Permalink](#dfn-emulated-position-data)

**Referenced in:**

- [§ 12.
 Emulation](#ref-for-dfn-emulated-position-data-1 "§ 12. Emulation")
 [(2)](#ref-for-dfn-emulated-position-data-2 "Reference 2")

[Permalink](#dfn-set-emulated-position-data)
[exported]

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-dfn-set-emulated-position-data-1 "§ 6.5 Request a position")

[Permalink](#dfn-get-emulated-position-data)

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-dfn-get-emulated-position-data-1 "§ 6.6 Acquire a position")

[Permalink](https://www.w3.org/TR/hr-time-3/#typedefdef-epochtimestamp)

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-index-term-epochtimestamp-1 "§ 6.6 Acquire a position")
- [§ 8. GeolocationPosition
 interface](#ref-for-index-term-epochtimestamp-2 "§ 8. GeolocationPosition interface")
- [§ 9.6 Constructing a
 GeolocationPosition](#ref-for-index-term-epochtimestamp-3 "§ 9.6 Constructing a GeolocationPosition")
- [§ A. IDL
 Index](#ref-for-index-term-epochtimestamp-4 "§ A. IDL Index")

[Permalink](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow)

**Referenced in:**

- [§ 2.7 Enabling the API in third-party
 contexts](#ref-for-index-term-allow-attribute-for-iframe-element-1 "§ 2.7 Enabling the API in third-party contexts")

[Permalink](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-index-term-allowed-to-use-1 "§ 6.5 Request a position")

[Permalink](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)

**Referenced in:**

- [§ 6.2 getCurrentPosition()
 method](#ref-for-index-term-associated-document-1 "§ 6.2 getCurrentPosition() method")
- [§ 6.3 watchPosition()
 method](#ref-for-index-term-associated-document-2 "§ 6.3 watchPosition() method")
- [§ 6.5 Request a
 position](#ref-for-index-term-associated-document-3 "§ 6.5 Request a position")
- [§ 12.
 Emulation](#ref-for-index-term-associated-document-4 "§ 12. Emulation")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-index-term-environment-settings-object-1 "§ 6.5 Request a position")

[Permalink](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active)

**Referenced in:**

- [§ 6.2 getCurrentPosition()
 method](#ref-for-index-term-fully-active-for-document-1 "§ 6.2 getCurrentPosition() method")
- [§ 6.3 watchPosition()
 method](#ref-for-index-term-fully-active-for-document-2 "§ 6.3 watchPosition() method")
- [§ 6.5 Request a
 position](#ref-for-index-term-fully-active-for-document-3 "§ 6.5 Request a position")

[Permalink](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)

**Referenced in:**

- [§ 2.7 Enabling the API in third-party
 contexts](#ref-for-index-term-iframe-element-1 "§ 2.7 Enabling the API in third-party contexts")
- [§ 6.5 Request a
 position](#ref-for-index-term-iframe-element-2 "§ 6.5 Request a position")

[Permalink](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-index-term-in-parallel-1 "§ 6.5 Request a position")

[Permalink](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable)

**Referenced in:**

- [§ 12. Emulation](#ref-for-index-term-navigable-1 "§ 12. Emulation")

[Permalink](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate)

**Referenced in:**

- [§ 3.4 Checking permission to use the
 API](#ref-for-index-term-navigates-1 "§ 3.4 Checking permission to use the API")

[Permalink](https://html.spec.whatwg.org/multipage/system-state.html#navigator)

**Referenced in:**

- [§ 5. Extensions to the Navigator
 interface](#ref-for-index-term-navigator-interface-1 "§ 5. Extensions to the Navigator interface")
- [§ A. IDL
 Index](#ref-for-index-term-navigator-interface-2 "§ A. IDL Index")

[Permalink](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable)

**Referenced in:**

- [§ 12.
 Emulation](#ref-for-index-term-node-navigable-1 "§ 12. Emulation")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#non-secure-context)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-index-term-non-secure-context-1 "§ 6.5 Request a position")
- [§ 10.1
 Constants](#ref-for-index-term-non-secure-context-2 "§ 10.1 Constants")

[Permalink](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)

**Referenced in:**

- [§ 3.4 Checking permission to use the
 API](#ref-for-index-term-origin-1 "§ 3.4 Checking permission to use the API")

[Permalink](https://html.spec.whatwg.org/multipage/interaction.html#page-visibility-change-steps)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-index-term-page-visibility-change-steps-1 "§ 6.5 Request a position")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-index-term-queue-a-task-1 "§ 6.6 Acquire a position")
 [(2)](#ref-for-index-term-queue-a-task-2 "Reference 2")
 [(3)](#ref-for-index-term-queue-a-task-3 "Reference 3")
- [§ 6.7 Call back with
 error](#ref-for-index-term-queue-a-task-4 "§ 6.7 Call back with error")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object's-realm)

**Referenced in:**

- [§ 3.4 Checking permission to use the
 API](#ref-for-index-term-realm-for-environment-settings-object-1 "§ 3.4 Checking permission to use the API")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)

**Referenced in:**

- [§ 6.2 getCurrentPosition()
 method](#ref-for-index-term-relevant-global-object-1 "§ 6.2 getCurrentPosition() method")
- [§ 6.3 watchPosition()
 method](#ref-for-index-term-relevant-global-object-2 "§ 6.3 watchPosition() method")
- [§ 6.5 Request a
 position](#ref-for-index-term-relevant-global-object-3 "§ 6.5 Request a position")
- [§ 12.
 Emulation](#ref-for-index-term-relevant-global-object-4 "§ 12. Emulation")

[Permalink](https://html.spec.whatwg.org/multipage/webappapis.html#task-source)

**Referenced in:**

- [§ 8.5 Task
 sources](#ref-for-index-term-task-source-1 "§ 8.5 Task sources")

[Permalink](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable)

**Referenced in:**

- [§ 12.
 Emulation](#ref-for-index-term-top-level-traversable-1 "§ 12. Emulation")

[Permalink](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top)

**Referenced in:**

- [§ 12.
 Emulation](#ref-for-index-term-top-level-traversable-for-navigable-1 "§ 12. Emulation")
 [(2)](#ref-for-index-term-top-level-traversable-for-navigable-2 "Reference 2")

[Permalink](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-index-term-visibility-state-for-document-1 "§ 6.5 Request a position")
 [(2)](#ref-for-index-term-visibility-state-for-document-2 "Reference 2")
 [(3)](#ref-for-index-term-visibility-state-for-document-3 "Reference 3")

[Permalink](https://infra.spec.whatwg.org/#list-append)

**Referenced in:**

- [§ 6.3 watchPosition()
 method](#ref-for-index-term-append-for-list-1 "§ 6.3 watchPosition() method")

[Permalink](https://infra.spec.whatwg.org/#list-contain)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-index-term-contains-for-list-1 "§ 6.5 Request a position")
- [§ 6.6 Acquire a
 position](#ref-for-index-term-contains-for-list-2 "§ 6.6 Acquire a position")

[Permalink](https://infra.spec.whatwg.org/#map-iterate)

**Referenced in:**

- [§ 9.6 Constructing a
 GeolocationPosition](#ref-for-index-term-for-each-for-map-1 "§ 9.6 Constructing a GeolocationPosition")

[Permalink](https://infra.spec.whatwg.org/#implementation-defined)

**Referenced in:**

- [§ 6.3 watchPosition()
 method](#ref-for-index-term-implementation-defined-1 "§ 6.3 watchPosition() method")

[Permalink](https://infra.spec.whatwg.org/#list-item)

**Referenced in:**

- [§ 6.1 Internal
 slots](#ref-for-index-term-item-for-list-1 "§ 6.1 Internal slots")

[Permalink](https://infra.spec.whatwg.org/#list)

**Referenced in:**

- [§ 6.1 Internal
 slots](#ref-for-index-term-list-1 "§ 6.1 Internal slots")

[Permalink](https://infra.spec.whatwg.org/#ordered-map)

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-index-term-map-1 "§ 6.6 Acquire a position")
- [§ 9.6 Constructing a
 GeolocationPosition](#ref-for-index-term-map-2 "§ 9.6 Constructing a GeolocationPosition")

[Permalink](https://infra.spec.whatwg.org/#list-remove)

**Referenced in:**

- [§ 6.4 clearWatch()
 method](#ref-for-index-term-remove-for-list-1 "§ 6.4 clearWatch() method")
- [§ 6.5 Request a
 position](#ref-for-index-term-remove-for-list-2 "§ 6.5 Request a position")
 [(2)](#ref-for-index-term-remove-for-list-3 "Reference 2")
 [(3)](#ref-for-index-term-remove-for-list-4 "Reference 3")

[Permalink](https://www.w3.org/TR/permissions/#dfn-default-powerful-feature)

**Referenced in:**

- [§ 3.4 Checking permission to use the
 API](#ref-for-index-term-default-powerful-feature-1 "§ 3.4 Checking permission to use the API")

[Permalink](https://www.w3.org/TR/permissions/#dfn-express-permission)

**Referenced in:**

- [§ 3.1 User
 consent](#ref-for-index-term-express-permission-1 "§ 3.1 User consent")
 [(2)](#ref-for-index-term-express-permission-2 "Reference 2")

[Permalink](https://www.w3.org/TR/permissions/#dfn-getting-the-current-permission-state)

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-index-term-get-the-current-permission-state-1 "§ 6.6 Acquire a position")

[Permalink](https://www.w3.org/TR/permissions/#dfn-granted)

**Referenced in:**

- [§ 3.1 User
 consent](#ref-for-index-term-granted-for-permission-1 "§ 3.1 User consent")
- [§ 3.4 Checking permission to use the
 API](#ref-for-index-term-granted-for-permission-2 "§ 3.4 Checking permission to use the API")
- [§ 6.6 Acquire a
 position](#ref-for-index-term-granted-for-permission-3 "§ 6.6 Acquire a position")

[Permalink](https://www.w3.org/TR/permissions/#dfn-lifetime)

**Referenced in:**

- [§ 3.1 User
 consent](#ref-for-index-term-lifetimes-for-permission-1 "§ 3.1 User consent")
 [(2)](#ref-for-index-term-lifetimes-for-permission-2 "Reference 2")
 [(3)](#ref-for-index-term-lifetimes-for-permission-3 "Reference 3")
 [(4)](#ref-for-index-term-lifetimes-for-permission-4 "Reference 4")
- [§ 3.4 Checking permission to use the
 API](#ref-for-index-term-lifetimes-for-permission-5 "§ 3.4 Checking permission to use the API")
 [(2)](#ref-for-index-term-lifetimes-for-permission-6 "Reference 2")

[Permalink](https://www.w3.org/TR/permissions/#dfn-name)

**Referenced in:**

- [§ 3.4 Checking permission to use the
 API](#ref-for-index-term-name-for-powerful-feature-1 "§ 3.4 Checking permission to use the API")

[Permalink](https://www.w3.org/TR/permissions/#dom-permissiondescriptor-name)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-index-term-name-for-permissiondescriptor-1 "§ 6.5 Request a position")

[Permalink](https://www.w3.org/TR/permissions/#dfn-permission)

**Referenced in:**

- [§ 3.4 Checking permission to use the
 API](#ref-for-index-term-permission-1 "§ 3.4 Checking permission to use the API")
 [(2)](#ref-for-index-term-permission-2 "Reference 2")

[Permalink](https://www.w3.org/TR/permissions/#dfn-permission-state)

**Referenced in:**

- [§ 3.1 User
 consent](#ref-for-index-term-permission-state-1 "§ 3.1 User consent")

[Permalink](https://www.w3.org/TR/permissions/#dom-permissiondescriptor)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-index-term-permissiondescriptor-1 "§ 6.5 Request a position")

[Permalink](https://www.w3.org/TR/permissions/#dfn-powerful-feature)

**Referenced in:**

- [§ 3.1 User
 consent](#ref-for-index-term-powerful-feature-1 "§ 3.1 User consent")

[Permalink](https://www.w3.org/TR/permissions/#dfn-request-permission-to-use)

**Referenced in:**

- [§ 6.5 Request a
 position](#ref-for-index-term-request-permission-to-use-1 "§ 6.5 Request a position")

[Permalink](https://www.w3.org/TR/permissions-policy-1/#default-allowlist-self)

**Referenced in:**

- [§ 11. Permissions
 policy](#ref-for-index-term-self-for-default-allowlist-1 "§ 11. Permissions policy")

[Permalink](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature-default-allowlist)

**Referenced in:**

- [§ 2.7 Enabling the API in third-party
 contexts](#ref-for-index-term-default-allowlist-for-policy-controlled-feature-1 "§ 2.7 Enabling the API in third-party contexts")
- [§ 11. Permissions
 policy](#ref-for-index-term-default-allowlist-for-policy-controlled-feature-2 "§ 11. Permissions policy")

[Permalink](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature)

**Referenced in:**

- [§ 11. Permissions
 policy](#ref-for-index-term-policy-controlled-feature-1 "§ 11. Permissions policy")

[Permalink](https://webidl.spec.whatwg.org/#idl-boolean)

**Referenced in:**

- [§ 7. PositionOptions
 dictionary](#ref-for-index-term-boolean-type-1 "§ 7. PositionOptions dictionary")
- [§ 8.4 Internal
 slots](#ref-for-index-term-boolean-type-2 "§ 8.4 Internal slots")
- [§ A. IDL Index](#ref-for-index-term-boolean-type-3 "§ A. IDL Index")

[Permalink](https://webidl.spec.whatwg.org/#Clamp)

**Referenced in:**

- [§ 7. PositionOptions
 dictionary](#ref-for-index-term-clamp-extended-attribute-1 "§ 7. PositionOptions dictionary")
 [(2)](#ref-for-index-term-clamp-extended-attribute-2 "Reference 2")
- [§ A. IDL
 Index](#ref-for-index-term-clamp-extended-attribute-3 "§ A. IDL Index")
 [(2)](#ref-for-index-term-clamp-extended-attribute-4 "Reference 2")

[Permalink](https://webidl.spec.whatwg.org/#Default)

**Referenced in:**

- [§ 8. GeolocationPosition
 interface](#ref-for-index-term-default-extended-attribute-1 "§ 8. GeolocationPosition interface")
- [§ 9. GeolocationCoordinates
 interface](#ref-for-index-term-default-extended-attribute-2 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL
 Index](#ref-for-index-term-default-extended-attribute-3 "§ A. IDL Index")
 [(2)](#ref-for-index-term-default-extended-attribute-4 "Reference 2")

[Permalink](https://webidl.spec.whatwg.org/#idl-DOMString)

**Referenced in:**

- [§ 10. GeolocationPositionError
 interface](#ref-for-index-term-domstring-interface-1 "§ 10. GeolocationPositionError interface")
- [§ A. IDL
 Index](#ref-for-index-term-domstring-interface-2 "§ A. IDL Index")

[Permalink](https://webidl.spec.whatwg.org/#idl-double)

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-index-term-double-type-1 "§ 6.6 Acquire a position")
 [(2)](#ref-for-index-term-double-type-2 "Reference 2")
 [(3)](#ref-for-index-term-double-type-3 "Reference 3")
 [(4)](#ref-for-index-term-double-type-4 "Reference 4")
 [(5)](#ref-for-index-term-double-type-5 "Reference 5")
 [(6)](#ref-for-index-term-double-type-6 "Reference 6")
 [(7)](#ref-for-index-term-double-type-7 "Reference 7")
- [§ 9. GeolocationCoordinates
 interface](#ref-for-index-term-double-type-8 "§ 9. GeolocationCoordinates interface")
 [(2)](#ref-for-index-term-double-type-9 "Reference 2")
 [(3)](#ref-for-index-term-double-type-10 "Reference 3")
 [(4)](#ref-for-index-term-double-type-11 "Reference 4")
 [(5)](#ref-for-index-term-double-type-12 "Reference 5")
 [(6)](#ref-for-index-term-double-type-13 "Reference 6")
 [(7)](#ref-for-index-term-double-type-14 "Reference 7")
- [§ A. IDL Index](#ref-for-index-term-double-type-15 "§ A. IDL Index")
 [(2)](#ref-for-index-term-double-type-16 "Reference 2")
 [(3)](#ref-for-index-term-double-type-17 "Reference 3")
 [(4)](#ref-for-index-term-double-type-18 "Reference 4")
 [(5)](#ref-for-index-term-double-type-19 "Reference 5")
 [(6)](#ref-for-index-term-double-type-20 "Reference 6")
 [(7)](#ref-for-index-term-double-type-21 "Reference 7")

[Permalink](https://webidl.spec.whatwg.org/#Exposed)

**Referenced in:**

- [§ 6. Geolocation interface and
 callbacks](#ref-for-index-term-exposed-extended-attribute-1 "§ 6. Geolocation interface and callbacks")
- [§ 8. GeolocationPosition
 interface](#ref-for-index-term-exposed-extended-attribute-2 "§ 8. GeolocationPosition interface")
- [§ 9. GeolocationCoordinates
 interface](#ref-for-index-term-exposed-extended-attribute-3 "§ 9. GeolocationCoordinates interface")
- [§ 10. GeolocationPositionError
 interface](#ref-for-index-term-exposed-extended-attribute-4 "§ 10. GeolocationPositionError interface")
- [§ A. IDL
 Index](#ref-for-index-term-exposed-extended-attribute-5 "§ A. IDL Index")
 [(2)](#ref-for-index-term-exposed-extended-attribute-6 "Reference 2")
 [(3)](#ref-for-index-term-exposed-extended-attribute-7 "Reference 3")
 [(4)](#ref-for-index-term-exposed-extended-attribute-8 "Reference 4")

[Permalink](https://webidl.spec.whatwg.org/#invoke-a-callback-function)

**Referenced in:**

- [§ 6.6 Acquire a
 position](#ref-for-index-term-invokes-1 "§ 6.6 Acquire a position")
 [(2)](#ref-for-index-term-invokes-2 "Reference 2")
 [(3)](#ref-for-index-term-invokes-3 "Reference 3")
- [§ 6.7 Call back with
 error](#ref-for-index-term-invokes-4 "§ 6.7 Call back with error")

[Permalink](https://webidl.spec.whatwg.org/#idl-long)

**Referenced in:**

- [§ 6. Geolocation interface and
 callbacks](#ref-for-index-term-long-type-1 "§ 6. Geolocation interface and callbacks")
 [(2)](#ref-for-index-term-long-type-2 "Reference 2")
- [§ A. IDL Index](#ref-for-index-term-long-type-3 "§ A. IDL Index")
 [(2)](#ref-for-index-term-long-type-4 "Reference 2")

[Permalink](https://webidl.spec.whatwg.org/#idl-object)

**Referenced in:**

- [§ 8. GeolocationPosition
 interface](#ref-for-index-term-object-type-1 "§ 8. GeolocationPosition interface")
- [§ 9. GeolocationCoordinates
 interface](#ref-for-index-term-object-type-2 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL Index](#ref-for-index-term-object-type-3 "§ A. IDL Index")
 [(2)](#ref-for-index-term-object-type-4 "Reference 2")

[Permalink](https://webidl.spec.whatwg.org/#SameObject)

**Referenced in:**

- [§ 5. Extensions to the Navigator
 interface](#ref-for-index-term-sameobject-extended-attribute-1 "§ 5. Extensions to the Navigator interface")
- [§ A. IDL
 Index](#ref-for-index-term-sameobject-extended-attribute-2 "§ A. IDL Index")

[Permalink](https://webidl.spec.whatwg.org/#SecureContext)

**Referenced in:**

- [§ 8. GeolocationPosition
 interface](#ref-for-index-term-securecontext-extended-attribute-1 "§ 8. GeolocationPosition interface")
- [§ 9. GeolocationCoordinates
 interface](#ref-for-index-term-securecontext-extended-attribute-2 "§ 9. GeolocationCoordinates interface")
- [§ A. IDL
 Index](#ref-for-index-term-securecontext-extended-attribute-3 "§ A. IDL Index")
 [(2)](#ref-for-index-term-securecontext-extended-attribute-4 "Reference 2")

[Permalink](https://webidl.spec.whatwg.org/#this)

**Referenced in:**

- [§ 6.2 getCurrentPosition()
 method](#ref-for-index-term-this-1 "§ 6.2 getCurrentPosition() method")
 [(2)](#ref-for-index-term-this-2 "Reference 2")
- [§ 6.3 watchPosition()
 method](#ref-for-index-term-this-3 "§ 6.3 watchPosition() method")
 [(2)](#ref-for-index-term-this-4 "Reference 2")
 [(3)](#ref-for-index-term-this-5 "Reference 3")
- [§ 6.4 clearWatch()
 method](#ref-for-index-term-this-6 "§ 6.4 clearWatch() method")
- [§ 6.6 Acquire a
 position](#ref-for-index-term-this-7 "§ 6.6 Acquire a position")
 [(2)](#ref-for-index-term-this-8 "Reference 2")
 [(3)](#ref-for-index-term-this-9 "Reference 3")
 [(4)](#ref-for-index-term-this-10 "Reference 4")

[Permalink](https://webidl.spec.whatwg.org/#idl-undefined)

**Referenced in:**

- [§ 6. Geolocation interface and
 callbacks](#ref-for-index-term-undefined-type-1 "§ 6. Geolocation interface and callbacks")
 [(2)](#ref-for-index-term-undefined-type-2 "Reference 2")
 [(3)](#ref-for-index-term-undefined-type-3 "Reference 3")
 [(4)](#ref-for-index-term-undefined-type-4 "Reference 4")
- [§ A. IDL
 Index](#ref-for-index-term-undefined-type-5 "§ A. IDL Index")
 [(2)](#ref-for-index-term-undefined-type-6 "Reference 2")
 [(3)](#ref-for-index-term-undefined-type-7 "Reference 3")
 [(4)](#ref-for-index-term-undefined-type-8 "Reference 4")

[Permalink](https://webidl.spec.whatwg.org/#idl-unsigned-long)

**Referenced in:**

- [§ 6.1 Internal
 slots](#ref-for-index-term-unsigned-long-type-1 "§ 6.1 Internal slots")
- [§ 6.3 watchPosition()
 method](#ref-for-index-term-unsigned-long-type-2 "§ 6.3 watchPosition() method")
- [§ 7. PositionOptions
 dictionary](#ref-for-index-term-unsigned-long-type-3 "§ 7. PositionOptions dictionary")
 [(2)](#ref-for-index-term-unsigned-long-type-4 "Reference 2")
- [§ A. IDL
 Index](#ref-for-index-term-unsigned-long-type-5 "§ A. IDL Index")
 [(2)](#ref-for-index-term-unsigned-long-type-6 "Reference 2")

[Permalink](https://webidl.spec.whatwg.org/#idl-unsigned-short)

**Referenced in:**

- [§ 6.7 Call back with
 error](#ref-for-index-term-unsigned-short-type-1 "§ 6.7 Call back with error")
- [§ 10. GeolocationPositionError
 interface](#ref-for-index-term-unsigned-short-type-2 "§ 10. GeolocationPositionError interface")
 [(2)](#ref-for-index-term-unsigned-short-type-3 "Reference 2")
 [(3)](#ref-for-index-term-unsigned-short-type-4 "Reference 3")
 [(4)](#ref-for-index-term-unsigned-short-type-5 "Reference 4")
- [§ A. IDL
 Index](#ref-for-index-term-unsigned-short-type-6 "§ A. IDL Index")
 [(2)](#ref-for-index-term-unsigned-short-type-7 "Reference 2")
 [(3)](#ref-for-index-term-unsigned-short-type-8 "Reference 3")
 [(4)](#ref-for-index-term-unsigned-short-type-9 "Reference 4")

- [fix \"Queue a task\" / \"in parallel\"
 usage](https://github.com/w3c/geolocation/commit/514f15b)
 ([#118](https://github.com/w3c/geolocation/pull/118))
- [Suggest permission
 lifetime](https://github.com/w3c/geolocation/commit/a1531cb)
 ([#108](https://github.com/w3c/geolocation/pull/108))
- [Handle OS-level permission
 change](https://github.com/w3c/geolocation/commit/0c378d9)
 ([#109](https://github.com/w3c/geolocation/pull/109))
- [Switch DOMTimeStamp to
 EpochTimeStamp](https://github.com/w3c/geolocation/commit/2a116d7)
 ([#104](https://github.com/w3c/geolocation/pull/104))
- [Return 0 when watchPosition()
 errors](https://github.com/w3c/geolocation/commit/2c0c516)
 ([#100](https://github.com/w3c/geolocation/pull/100))
- [Callback with error if doc is not fully
 active](https://github.com/w3c/geolocation/commit/de05002)
 ([#97](https://github.com/w3c/geolocation/pull/97))
- [Gracefully handle documents that are not fully
 active](https://github.com/w3c/geolocation/commit/f4605e5)
 ([#90](https://github.com/w3c/geolocation/pull/90))
- [Add \"geolocation task
 queue\"](https://github.com/w3c/geolocation/commit/41d7945)
 ([#87](https://github.com/w3c/geolocation/pull/87))

Since publication of the Second Edition in 2016, this specification
received the following substantive changes:

- [Request a
 position](#dfn-request-a-position) only proceeds when a
 document is visible, or the document becomes visible.
- Clarified how caching works as part of [acquiring a
 position](#dfn-acquire-a-position): only last position is
 cached, and can be evicted at any time.
- Now relies on the
 [Permissions](https://www.w3.org/TR/permissions/){matched-text="[[[Permissions]]]"}
 specification to handle permission grants, and user interface
 requirements.
- The `errorCallback` is now nullable.
- The API can be controlled by [Permissions
 Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[Permissions-Policy]]]"},
 which restricts how/where the API is exposed to web pages.
- The `callbacks` are no longer treated as \"EventHandler\" objects
 (i.e., objects that have a `.handleEvent()` method), but are now
 exclusively treated as IDL callback functions.
- The API is now only exposed in Secure Contexts (i.e., only available
 in HTTPS).
- The interfaces no longer use
 \[[WebIDL](#bib-webidl "Web IDL Standard")\]\'s legacy `[NoInterfaceObject]`, so
 `Geolocation` and other interface of this spec are now in the global
 scope. Also, the interfaces were renamed from `NavigatorGeolocation*`
 to just `Geolocation*`.

See the [commit
history](https://github.com/w3c/geolocation/commits/main) for a complete
list of changes.

::: header-wrapper
## E. References

::: header-wrapper
### E.1 Normative references

\[hr-time\]
: [High Resolution Time](https://www.w3.org/TR/hr-time-3/). Yoav
 Weiss. W3C. 2 March 2026. W3C Working Draft. URL:
 <https://www.w3.org/TR/hr-time-3/>

\[html\]
: [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
 Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
 Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
 <https://html.spec.whatwg.org/multipage/>

\[infra\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[Permissions\]
: [Permissions](https://www.w3.org/TR/permissions/). Marcos Caceres;
 Mike Taylor. W3C. 6 October 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/permissions/>

\[permissions-policy\]
: [Permissions Policy](https://www.w3.org/TR/permissions-policy-1/).
 Ian Clelland. W3C. 6 October 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/permissions-policy-1/>

\[RFC2119\]
: [Key words for use in RFCs to Indicate Requirement
 Levels](https://www.rfc-editor.org/rfc/rfc2119). S. Bradner. IETF.
 March 1997. Best Current Practice. URL:
 <https://www.rfc-editor.org/rfc/rfc2119>

\[RFC8174\]
: [Ambiguity of Uppercase vs Lowercase in RFC 2119 Key
 Words](https://www.rfc-editor.org/rfc/rfc8174). B. Leiba. IETF.
 May 2017. Best Current Practice. URL:
 <https://www.rfc-editor.org/rfc/rfc8174>

\[webidl\]
: [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
 Timothy Gu. WHATWG. Living Standard. URL:
 <https://webidl.spec.whatwg.org/>

\[WGS84\]
: [World Geodetic System 1984 (WGS
 84)](https://earth-info.nga.mil/index.php?dir=wgs84&action=wgs84).
 Office of Geomatics, National Geospatial Intelligence Agency. 2008.
 URL: <https://earth-info.nga.mil/index.php?dir=wgs84&action=wgs84>

[[↑]](#title)
