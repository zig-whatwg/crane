
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# Permissions

## Interacting with Permissions for Powerful Features

[W3C Working Draft](https://www.w3.org/standards/types#WD) 06 October
2025

More details about this document

This version:
: [https://www.w3.org/TR/2025/WD-permissions-20251006/](https://www.w3.org/TR/2025/WD-permissions-20251006/)

Latest published version:
: <https://www.w3.org/TR/permissions/>

Latest editor\'s draft:
: <https://w3c.github.io/permissions/>

History:
: <https://www.w3.org/standards/history/permissions/>
: [Commit history](https://github.com/w3c/permissions/commits/main)

Editors:
: [Marcos Cáceres](https://marcosc.com)
 ([Apple Inc.](https://www.apple.com/))
: [Mike Taylor](https://miketaylr.com/posts/)
 ([Google LLC](https://google.com/))

Former editors:
: [Mounir Lamouri] ([Google
 LLC](https://google.com/))
: [Jeffrey Yasskin] ([Google
 LLC](https://google.com/))

Feedback:
: [GitHub w3c/permissions](https://github.com/w3c/permissions/) ([pull
 requests](https://github.com/w3c/permissions/pulls/), [new
 issue](https://github.com/w3c/permissions/issues/new/choose), [open
 issues](https://github.com/w3c/permissions/issues/))

Browser support:

: ::::::::: caniuse-group
 ::::::: caniuse-browsers
 :::
 ![Chrome
 logo](https://www.w3.org/assets/logos/browser-logos/chrome/chrome.svg)[43]
 :::

 :::
 ![Edge
 logo](https://www.w3.org/assets/logos/browser-logos/edge/edge.svg)[79]
 :::

 :::
 ![Firefox
 logo](https://www.w3.org/assets/logos/browser-logos/firefox/firefox.svg)[46]
 :::

 :::
 ![Safari
 logo](https://www.w3.org/assets/logos/browser-logos/safari/safari.svg)[16.0]
 :::
 :::::::

 ::: caniuse-type
 desktop
 :::
 :::::::::

 :::::::::: caniuse-group
 :::::::: caniuse-browsers
 :::
 ![Android Chrome
 logo](https://www.w3.org/assets/logos/browser-logos/chrome/chrome.svg)[141]
 :::

 :::
 ![Android Firefox
 logo](https://www.w3.org/assets/logos/browser-logos/firefox/firefox.svg)[143]
 :::

 :::
 ![Android UC
 logo](https://www.w3.org/assets/logos/browser-logos/uc/uc.svg)[15.5]
 :::

 :::
 ![iOS Safari
 logo](https://www.w3.org/assets/logos/browser-logos/safari-ios/safari-ios.svg)[16.0]
 :::

 :::
 ![Samsung Internet
 logo](https://www.w3.org/assets/logos/browser-logos/samsung-internet/samsung-internet.svg)[4]
 :::
 ::::::::

 ::: caniuse-type
 mobile
 :::
 ::::::::::

 [More info](https://caniuse.com/permissions-api)

[Copyright](https://www.w3.org/policies/#copyright) © 2025 [World Wide
Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

This specification defines common infrastructure that other
specifications can use to interact with browser permissions. These
permissions represent a user\'s choice to allow or deny access to
\"powerful features\" of the platform. For developers, the specification
standardizes an API to query the permission state of a powerful feature,
and be notified if a permission to use a powerful feature changes state.

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

This is a work in progress.

This document was published by the [Web Application Security Working
Group](https://www.w3.org/groups/wg/webappsec) as a Working Draft using
the [Recommendation
track](https://www.w3.org/policies/process/20250818/#recs-and-notes).

Publication as a Working Draft does not imply endorsement by [W3C] and its Members.

This is a draft document and may be updated, replaced, or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than a work in progress.

This document was produced by a group operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/webappsec/ipr){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
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
3. [1. Introduction](#intro)
4. [2. Examples of usage](#examples)
5. [3. Model](#model)
 1. [3.1 Permissions](#permissions)
 2. [3.2 Permission Store](#permission-store)
 3. [3.3 Powerful features](#powerful-features)
 1. [3.3.1 Aspects](#aspects)
 4. [3.4 Permissions task
 source](#permissions-task-source)
6. [4. Specifying a powerful
 feature](#specifying-a-powerful-feature)
7. [5. Algorithms to interface with
 permissions](#algorithms-to-interface-with-permissions)
 1. [5.1 Reading the current permission
 state](#reading-current-states)
 2. [5.2 Requesting permission to use a powerful
 feature](#requesting-more-permission)
 3. [5.3 Prompt the user to
 choose](#prompt-the-user-to-choose)
 4. [5.4 Reacting to users revoking
 permission](#reacting-to-revocation)
8. [6. Permissions API](#permissions-api)
 1. [6.1 Extensions to the `Navigator` and `WorkerNavigator`
 interfaces](#navigator-and-workernavigator-extension)
 2. [6.2 `Permissions` interface](#permissions-interface)
 1. [6.2.1 `query()` method](#query-method)
 3. [6.3 `PermissionStatus`
 interface](#permissionstatus-interface)
 1. [6.3.1 Creating instances](#creating-instances)
 2. [6.3.2 `name` attribute](#name-attribute)
 3. [6.3.3 `state` attribute](#state-attribute)
 4. [6.3.4 `onchange` attribute](#onchange-attribute)
 5. [6.3.5 Garbage collection](#permissionstatus-gc)
9. [7. Conformance](#conformance)
10. [A. Relationship to the Permissions Policy
 specification](#relationship-to-permissions-policy)
11. [B. Automated testing](#automation)
 1. [B.1 Automated testing with \[[WebDriver]\]](#automation-webdriver)
 1. [B.1.1 Set
 Permission](#webdriver-command-set-permission)
 2. [B.2 Automated testing with \[[WebDriver-BiDi]\]](#automation-webdriver-bidi)
 1. [B.2.1 The permissions
 Module](#webdriver-bidi-module-permissions)
 1. [B.2.1.1
 Definition](#webdriver-bidi-module-permissions-definition)
 2. [B.2.1.2
 Types](#webdriver-bidi-module-permissions-types)
 1. [B.2.1.2.1 The permissions.PermissionDescriptor
 Type](#webdriver-bidi-type-permissions-PermissionDescriptor)
 2. [B.2.1.2.2 The permissions.PermissionState
 Type](#webdriver-bidi-type-permissions-PermissionState)
 3. [B.2.1.3
 Commands](#webdriver-bidi-module-permissions-commands)
 1. [B.2.1.3.1 The permissions.setPermission
 Command](#webdriver-bidi-command-permissions-setPermission)
12. [C. Permissions Registry](#permissions-registry)
 1. [C.1 Purpose](#purpose)
 2. [C.2 Change Process](#change-process)
 3. [C.3 Registry table of standardized
 permissions](#registry-table-of-standardized-permissions)
 4. [C.4 Registry table of provisional
 permissions](#registry-table-of-provisional-permissions)
13. [D. Privacy considerations](#privacy-considerations)
14. [E. Security considerations](#security-considerations)
15. [F. IDL Index](#idl-index)
16. [G. Acknowledgments](#acknowledgments)
17. [H. References](#references)
 1. [H.1 Normative references](#normative-references)
 2. [H.2 Informative references](#informative-references)

::: header-wrapper
## 1. Introduction

*This section is non-normative.*

Specifications can define features that are explicitly identified as a
[powerful
feature](#dfn-powerful-feature). These features are said to be
\"powerful\" in that they can have significant privacy, security, and
performance implications. As such, users rely on user agents to deny
sites the ability to use these features until they have given express
permission, and usually only granting this ability for a limited amount
of time. Express permission to allow a site to use a powerful feature is
generally given and controlled through browser UI, as illustrated below.

![[Figure
1](#fig-sketches-of-possible-permission-prompt-types) [
Sketches of possible permission prompt types
]](docs/assets/images/sample-prompts.png)

In this sense, a permission represents the current state of user consent
for certain types of features, and particularly \"powerful features\".
Ultimately the user retains control of these permissions and have the
ability to manually grant or deny permissions through user preferences.
Further, user agents assist users in managing permissions by, for
example, hiding and automatically denying certain permission prompts
that would otherwise be a nuisance, and automatically expiring granted
permissions if a user doesn\'t visit a website for some time.

![[Figure
2](#fig-a-sketch-of-a-possible-site-specific-permissions-controls-ui)
[ A sketch of a possible site-specific permissions controls UI
]](docs/assets/images/permission-settings.png)

::: header-wrapper
## 2. Examples of usage

*This section is non-normative.*

This example uses the Permissions API to decide whether local news
should be shown using the Geolocation API or with a button offering to
add the feature.

[Example 1](#example-using-state-attribute)[: Using .state
attribute]

``` {aria-busy="false"}
const { state } = await navigator.permissions.query({
 name: "geolocation"
});
switch (state) {
 case "granted":
 showLocalNewsWithGeolocation();
 break;
 case "prompt":
 showButtonToEnableLocalNews();
 break;
 case "denied":
 showNationalNews();
 break;
}
```

This example simultaneously checks the state of the `"geolocation"` and
`"notifications"` [powerful
features](#dfn-powerful-feature):

[Example
2](#example-checking-the-state-of-multiple-permissions)[:
Checking the state of multiple permissions]

``` {aria-busy="false"}
const queryPromises = ["geolocation", "notifications"].map(
 name => navigator.permissions.query({ name })
);
for await (const status of queryPromises) {
 console.log(`${status.name}: ${status.state}`);
}
```

This example is checking the permission state of the available cameras.

[Example
3](#example-checking-permission-state-of-multiple-cameras)[:
Checking permission state of multiple cameras]

``` {aria-busy="false"}
const devices = await navigator.mediaDevices.enumerateDevices();

// filter on video inputs, and map to query object
const queries = devices
 .filter(({ kind }) => kind === "videoinput")
 .map(({ deviceId }) => ({ name: "camera", deviceId }));

const promises = queries.map((queryObj) =>
 navigator.permissions.query(queryObj)
);

try {
 const results = await Promise.all(promises);
 // log the state of each camera
 results.forEach(({ state }, i) => console.log("Camera", i, state));
} catch (error) {
 console.error(error);
}
```

::: header-wrapper
## 3. Model

This section specifies a model for
[permissions](#dfn-permissions) to use [powerful
features](#dfn-powerful-feature) on the Web platform.

::: header-wrapper
### 3.1 Permissions

A [permission] represents a user\'s decision to
allow a web application to use a [powerful
feature](#dfn-powerful-feature). This decision is represented
as a permission [state](#dfn-states).

[Express permission] refers to the user
[granting](#dfn-granted) the web application the ability
to use a [powerful
feature](#dfn-powerful-feature).

Note[: Limitations and extensibility]

Current Web APIs have different ways to deal with permissions. For
example, the [Notifications API
Standard](https://notifications.spec.whatwg.org/){matched-text="[[[notifications]]]"}
allows developers to request a permission and check the permission
status explicitly. Others expose the status to web pages only when they
try to use the API, e.g., the
[Geolocation](https://www.w3.org/TR/geolocation/){matched-text="[[[Geolocation]]]"}
which fails if the permission was not granted without allowing the
developer to check beforehand.

The solution described in this document is meant to be extensible, but
isn\'t expected to be applicable to all the current and future
permissions available in the web platform. Working Groups that are
creating specifications whose permission model doesn\'t fit in the model
described in this document should contact the editors by [filing an
issue](https://github.com/w3c/permissions/issues).

Conceptually, a [permission](#dfn-permission) for a [powerful
feature](#dfn-powerful-feature) can be in one of the following
[states]:

[\"denied\"]:
: The user, or the user agent on the user\'s behalf, has denied access
 to this [powerful
 feature](#dfn-powerful-feature). The caller won\'t be able
 to use the feature.

[\"granted\"]:
: The user, or the user agent on the user\'s behalf, has given
 [express
 permission](#dfn-express-permission) to use a [powerful
 feature](#dfn-powerful-feature). The caller will be able
 to use the feature possibly without having the [user
 agent](https://infra.spec.whatwg.org/#user-agent)
 asking the user\'s permission.

[\"prompt\"]:
: The user has not given [express
 permission](#dfn-express-permission) to use the feature (i.e.,
 it\'s the same as [\"denied\"](#dfn-denied)). It also means that if a
 caller attempts to use the feature, the [user
 agent](https://infra.spec.whatwg.org/#user-agent)
 will either be prompting the user for permission or access to the
 feature will be [\"denied\"](#dfn-denied).

To ascertain [new information about the user\'s
intent], a user
agent *MAY* collect and interpret information about a user\'s
intentions. This information can come from explicit user action,
aggregate behavior of both the relevant user and other users, or
[implicit signals] this specification hasn\'t
anticipated.

Note[: What constitutes an implicit signal?]

The [implicit
signals](#dfn-implicit-signals) could be, for example, the
[installation](https://www.w3.org/TR/appmanifest/#dfn-installed-web-application) status of a web application or frequency
and recency of visits. A user that has installed a web application and
used it frequently and recently is more likely to trust it.
Implementations are advised to exercise caution when relying on implicit
signals.

Every [permission](#dfn-permission) has a [lifetime], which is the
duration for which a particular permission remains
[\"granted\"](#dfn-granted) before it reverts back to its [default
state](#dfn-default-state). A
[lifetime](#dfn-lifetime) could be until a particular
[Realm](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm)
is destroyed, until a particular [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context)
is destroyed, a particular amount of time, or be infinite. The lifetime
is negotiated between the end-user and the [user
agent](https://infra.spec.whatwg.org/#user-agent) when
the user gives [express
permission](#dfn-express-permission) to use a
[feature](#dfn-powerful-feature)---usually via some permission
UI or user-agent defined policy.

Every permission has a [default state] (usually [\"prompt\"](#dfn-prompt)), which is the
[state](#dfn-states) that the permission is in when the user has
not yet given [express
permission](#dfn-express-permission) to use the
[feature](#dfn-powerful-feature) or it has been reset because
its [lifetime](#dfn-lifetime) has expired.

::: header-wrapper
### 3.2 Permission Store

The user agent maintains a single [permission
store] which is a
[list](https://infra.spec.whatwg.org/#list) of
[permission store
entries](#dfn-permission-store-entry). Each particular
[entry](#dfn-permission-store-entry) denoted by its
[descriptor](#dfn-descriptor) and [key](#dfn-key) can only appear at most once
in this list.

The user agent *MAY* remove
[entries](#dfn-permission-store-entry) from the [permission
store](#dfn-permission-store) when their respective
[permission](#dfn-permission)\'s
[lifetime](#dfn-lifetime) has expired.

A [permission store entry] is a
[tuple](https://infra.spec.whatwg.org/#tuple) of
[`PermissionDescriptor`](#dom-permissiondescriptor)
[descriptor], [permission
key](#dfn-permission-key) [key], and
[state](#dfn-states) [state].

To [get a permission store entry]
given a
[`PermissionDescriptor`](#dom-permissiondescriptor)
`descriptor` and [permission
key](#dfn-permission-key) `key`:

1. If the user agent\'s [permission
 store](#dfn-permission-store)
 [contains](https://infra.spec.whatwg.org/#list-contain)
 an
 [entry](#dfn-permission-store-entry) whose
 [descriptor](#dfn-descriptor) is `descriptor`, and whose
 [key](#dfn-key) [is equal
 to](#dfn-is-equal-to) `key` given
 `descriptor`, return
 that entry.
2. Return null.

To [set a permission store entry]
given a
[`PermissionDescriptor`](#dom-permissiondescriptor)
`descriptor`, a [permission
key](#dfn-permission-key) `key`, and a
[state](#dfn-states) `state`, run these steps:

1. Let `newEntry` be a new [permission store
 entry](#dfn-permission-store-entry) whose
 [descriptor](#dfn-descriptor) is `descriptor`, and whose
 [key](#dfn-key) is `key`, and whose
 [state](#dfn-state) is `state`.
2. If the user agent\'s [permission
 store](#dfn-permission-store)
 [contains](https://infra.spec.whatwg.org/#list-contain)
 an
 [entry](#dfn-permission-store-entry) whose
 [descriptor](#dfn-descriptor) is `descriptor`, and whose
 [key](#dfn-key) [is equal
 to](#dfn-is-equal-to) `key` given
 `descriptor`,
 [replace](https://infra.spec.whatwg.org/#list-replace)
 that entry with `newEntry` and abort these steps.
3. [Append](https://infra.spec.whatwg.org/#list-append)
 `newEntry` to the user agent\'s [permission
 store](#dfn-permission-store).

To [remove a permission store
entry] given a
[`PermissionDescriptor`](#dom-permissiondescriptor)
`descriptor` and [permission
key](#dfn-permission-key) `key`, run these steps:

1. [Remove](https://infra.spec.whatwg.org/#list-remove)
 the
 [entry](#dfn-permission-store-entry) whose
 [descriptor](#dfn-descriptor) is `descriptor`, and whose
 [key](#dfn-key) [is equal
 to](#dfn-is-equal-to) `key` given
 `descriptor`, from the
 user agent\'s [permission
 store](#dfn-permission-store).

A [permission key] has its type defined by a feature\'s [permission key
type](#dfn-permission-key-type).

The permission key defines the scope of a permission grant, which is
usually per-origin. Powerful features may override the [permission key
type](#dfn-permission-key-type) to specify a custom permission
key. This is useful for features that want to change the granularity of
permissions based on additional context, such as double-keying on both
an embedded origin and a top-level origin.

To determine whether a [permission
key](#dfn-permission-key) `key1` [is equal
to] a [permission
key](#dfn-permission-key) `key2`, given a
[`PermissionDescriptor`](#dom-permissiondescriptor)
`descriptor`, run the
following steps:

1. If `key1` is not of `descriptor`\'s [permission key
 type](#dfn-permission-key-type) or `key2` is
 not of `descriptor`\'s
 [permission key
 type](#dfn-permission-key-type), return false.
2. Return the result of running the [permission key comparison
 algorithm](#dfn-permission-key-comparison-algorithm) for the feature named by
 `descriptor`\'s
 [`name`](#dom-permissiondescriptor-name), passing `key1` and
 `key2`.

::: header-wrapper
### 3.3 Powerful features

A [powerful feature] is a web platform
feature (usually an API) for which a user gives [express
permission](#dfn-express-permission) before the feature can be
used. Except for a few notable exceptions (e.g., the [Notifications API
Standard](https://notifications.spec.whatwg.org/){matched-text="[[[Notifications]]]"}),
most powerful features are also [policy-controlled
features](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature).
For powerful features that are also [policy-controlled
features](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature),
\[[Permissions-Policy](#bib-permissions-policy "Permissions Policy")\] controls whether a
[document](https://dom.spec.whatwg.org/#concept-document)
is [allowed to
use](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use)
a given feature. That is, a powerful feature can only request [express
permission](#dfn-express-permission) from a user if the
[document](https://dom.spec.whatwg.org/#concept-document)
has permission delegated to it via the corresponding [policy-controlled
feature](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature)
(see example below). Subsequent access to the feature is determined by
the user having [\"granted\"](#dfn-granted) permission, or by satisfying
some criteria that is equivalent to a permission
[grant](#dfn-granted).

[Example
4](#example-powerful-features-are-policy-controlled-features)[:
Powerful features are policy-controlled features]

This example shows how the permissions policy set through the
[`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow)
attribute controls whether the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)
is [allowed to
use](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use)
a powerful feature. Because `"geolocation"` is allowed, the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)\'s
document can request permission from the user to use the
[Geolocation](https://www.w3.org/TR/geolocation/){matched-text="[[[Geolocation]]]"}
(i.e., it will prompt the user for express permission to access their
location information). However, requesting permission to use any other
feature will be automatically denied, because they are not listed in the
[`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow)
attribute.

``` {aria-busy="false"}
<iframe src="https://example.com/" allow="geolocation">
</iframe>
```

See [A. Relationship to the Permissions Policy
specification](#relationship-to-permissions-policy) for more
information.

A [powerful
feature](#dfn-powerful-feature) is identified by its
[name], which is a string
literal (e.g., \"geolocation\").

The user agent tracks which [powerful
features](#dfn-powerful-feature) the user has
[permission](#dfn-permission) to use via the [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object).

::: header-wrapper
#### 3.3.1 Aspects

Each [powerful
feature](#dfn-powerful-feature) can define zero or more
additional [aspects]. An aspect is
defined as WebIDL
[dictionary](https://webidl.spec.whatwg.org/#dfn-dictionary)
that
[inherits](https://webidl.spec.whatwg.org/#dfn-inherit-dictionary)
from
[`PermissionDescriptor`](#dom-permissiondescriptor) and serves as a
WebIDL interface\'s [permission descriptor
type](#dfn-permission-descriptor-type).

[Example
5](#example-defining-your-own-permission-descriptor-type)[:
Defining your own permission descriptor type]

A hypothetical [powerful
feature](#dfn-powerful-feature) \"food detector API\" has two
[aspects](#dfn-aspects) that allow sensing taste and smell. So, a
specification would define a new WebIDL interface that
[inherits](https://webidl.spec.whatwg.org/#dfn-inherit-dictionary)
[`PermissionDescriptor`](#dom-permissiondescriptor):

``` {aria-busy="false"}
dictionary SensesPermissionDescriptor : PermissionDescriptor {
 boolean canSmell = false;
 boolean canTaste = false;
};
```

Which would then be queried via the API in the following way:

``` {aria-busy="false"}
// Check if the "senses" powerful feature is allowed to smell things
const status = await navigator.permissions.query({
 name: "senses",
 canSmell: true,
});
// Do something interesting with the status.
```

A user can restrict the \"senses\" powerful feature to only \"taste\",
in which case the
[`PermissionStatus`](#dom-permissionstatus)\'s
[`state`](#dom-permissionstatus-state) above would be
\"[`denied`](#dom-permissionstate-denied)\" .

::: header-wrapper
### 3.4 Permissions task source

The [permissions task source] is a [task
source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source)
used to perform permissions-related
[tasks](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task)
in this specification.

::: header-wrapper
## 4. Specifying a powerful feature

When a conforming
[specification](#dfn-specifications) [specifies a powerful
feature] it:

1. *MUST* give the [powerful
 feature](#dfn-powerful-feature) a
 [name](#dfn-name) in the form of a [ascii
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase)
 string.
2. *MAY* define a [permission descriptor
 type](#dfn-permission-descriptor-type) that inherits from
 [`PermissionDescriptor`](#dom-permissiondescriptor).
3. *MAY* define zero or more
 [aspects](#dfn-aspects).
4. *MAY* override the algorithms and types given below if the defaults
 are not suitable for a particular [powerful
 feature](#dfn-powerful-feature).
5. *MUST* register the [powerful
 feature](#dfn-powerful-feature) in the [Permissions
 Registry](https://w3c.github.io/permissions-registry/){matched-text="[[[permissions-registry]]]"}.

Registering the newly specified [powerful
features](#dfn-powerful-feature) in the [Permissions
Registry](https://w3c.github.io/permissions-registry/){matched-text="[[[permissions-registry]]]"}
gives this Working Group an opportunity to provide feedback and check
that integration with this specification is done effectively.

A [permission descriptor type]:

: [`PermissionDescriptor`](#dom-permissiondescriptor) or one of
 its subtypes. If unspecified, this defaults to
 [`PermissionDescriptor`](#dom-permissiondescriptor).

 The feature can define a [partial
 order](https://en.wikipedia.org/wiki/Partially_ordered_set) on
 descriptor instances. If `descriptorA` is [stronger
 than]
 `descriptorB`, then if `descriptorA`\'s
 [permission
 state](#dfn-permission-state) is
 \"[`granted`](#dom-permissionstate-granted)\", `descriptorB`\'s
 [permission
 state](#dfn-permission-state) must also be
 \"[`granted`](#dom-permissionstate-granted)\", and if `descriptorB`\'s
 [permission
 state](#dfn-permission-state) is
 \"[`denied`](#dom-permissionstate-denied)\", `descriptorA`\'s
 [permission
 state](#dfn-permission-state) must also be
 \"[`denied`](#dom-permissionstate-denied)\".

 ::: marker
 [Example 6](#example-stronger-than)[: A permission
 descriptor that defines a partial order]
 :::

 `{name: "midi", sysex: true}` (\"midi-with-sysex\") is [stronger
 than](#dfn-stronger-than) `{name: "midi", sysex: false}`
 (\"midi-without-sysex\"), so if the user denies access to
 midi-without-sysex, the UA must also deny access to midi-with-sysex,
 and similarly if the user grants access to midi-with-sysex, the user
 agent must also grant access to midi-without-sysex.

[permission state constraints]:
: Constraints on the values that the user agent can return as a
 descriptor\'s [permission
 state](#dfn-permission-state). Defaults to no
 constraints beyond the user\'s intent.

[extra permission data type]:

: Some [powerful
 features](#dfn-powerful-feature) have more information
 associated with them than just a
 [`PermissionState`](#dom-permissionstate). Each of these
 features defines an [extra permission data
 type](#dfn-extra-permission-data-type).

 ::::
 :::
 Note
 :::

 For example,
 [`getUserMedia`](https://www.w3.org/TR/mediacapture-streams/#dom-mediadevices-getusermedia)`()` needs to determine *which* cameras the user
 has granted permission to access.
 ::::

 ::: algorithm
 If a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) `name` names one of these features, then
 `name`\'s [extra permission
 data] for an optional [environment
 settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)
 `settings` is the result of the following algorithm:

 1. If `settings` wasn\'t passed, set it to the [current
 settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object).
 2. If there was a previous invocation of this algorithm with the
 same `name` and `settings`, returning
 `previousResult`, and the user agent has not received
 [new information about the user\'s
 intent](#dfn-new-information-about-the-user-s-intent) since that invocation, return
 `previousResult`.
 3. Return the instance of `name`\'s [extra permission
 data
 type](#dfn-extra-permission-data-type) that matches the UA\'s
 impression of the user\'s intent, taking into account any [extra
 permission data
 constraints](#dfn-extra-permission-data-constraints) for `name`.
 :::

 If specified, the [extra permission
 data](#dfn-extra-permission-data) algorithm is usable for
 this feature.

Optional [extra permission data constraints]:
: Constraints on the values that the user agent can return as a
 [powerful
 feature](#dfn-powerful-feature)\'s [extra permission
 data](#dfn-extra-permission-data). Defaults to no
 constraints beyond the user\'s intent.

A [permission result type]:
: [`PermissionStatus`](#dom-permissionstatus) or one of its
 subtypes. If unspecified, this defaults to
 [`PermissionStatus`](#dom-permissionstatus).

A [permission query algorithm]:

: Takes an instance of the [permission descriptor
 type](#dfn-permission-descriptor-type) and a new or existing
 instance of the [permission result
 type](#dfn-permission-result-type), and updates the
 [permission result
 type](#dfn-permission-result-type) instance with the query
 result. Used by
 [`Permissions`](#dom-permissions)\'
 [`query`](#dom-permissions-query)`(``permissionDesc``)` method
 and the [`PermissionStatus` update
 steps](#dfn-permissionstatus-update-steps). If unspecified, this
 defaults to the [default permission query
 algorithm](#dfn-default-permission-query-algorithm).

 ::: algorithm
 The [default permission query
 algorithm], given a
 [`PermissionDescriptor`](#dom-permissiondescriptor)
 `permissionDesc` and a
 [`PermissionStatus`](#dom-permissionstatus)
 `status`, runs the following steps:

 1. Set `status`\'s
 [`state`](#dom-permissionstatus-state) to `permissionDesc`\'s
 [permission
 state](#dfn-permission-state).
 :::

A [permission key type]:

: The type of [permission
 key](#dfn-permission-key) used by the feature. Defaults to
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin).
 A feature that specifies a custom [permission key
 type](#dfn-permission-key-type) *MUST* also specify a
 [permission key generation
 algorithm](#dfn-permission-key-generation-algorithm).

A [permission key generation algorithm]:

: Takes an
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
 `origin` and an
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
 `embedded origin`, and returns a new [permission
 key](#dfn-permission-key). If unspecified, this defaults to the
 [default permission key generation
 algorithm](#dfn-default-permission-key-generation-algorithm). A feature that specifies
 a custom [permission key generation
 algorithm](#dfn-permission-key-generation-algorithm) *MUST* also specify a
 [permission key comparison
 algorithm](#dfn-permission-key-comparison-algorithm).

 ::: algorithm
 The [default permission key generation
 algorithm], given an
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
 `origin` and an
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
 `embedded origin`, runs the following steps:

 1. Return `origin`.
 :::

 ::::
 :::
 Note[: Permission Delegation]
 :::

 Most powerful features grant permission to the top-level origin and
 delegate access to the requesting document via [Permissions
 Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[Permissions-Policy]]]"}.
 This is known as permission delegation.
 ::::

A [permission key comparison algorithm]:

: Takes two [permission
 keys](#dfn-permission-key) and returns a
 [boolean](https://infra.spec.whatwg.org/#boolean)
 that shows whether the two keys are equal. If unspecified, this
 defaults to the [default permission key comparison
 algorithm](#dfn-default-permission-key-comparison-algorithm).

 ::: algorithm
 The [default permission key comparison
 algorithm], given [permission
 keys](#dfn-permission-key) `key1` and
 `key2`, runs the following steps:

 1. Return `key1` is [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin)
 with `key2`.
 :::

A [permission revocation algorithm]:

: Takes no arguments. Updates any other parts of the implementation
 that need to be kept in sync with changes in the results of
 [permission
 states](#dfn-permission-state) or [extra permission
 data](#dfn-extra-permission-data).

 If unspecified, this defaults to running [react to the user revoking
 permission](#dfn-react-to-the-user-revoking-permission).

A permission [lifetime](#dfn-lifetime):

: Specifications that define one or more [powerful
 features](#dfn-powerful-feature) *SHOULD* suggest a
 [permission](#dfn-permission)
 [lifetime](#dfn-lifetime) that is best suited for the particular
 feature. Some guidance on determining the lifetime of a permission
 is noted below, with a strong emphasis on user privacy. If no
 [lifetime](#dfn-lifetime) is specified, the user agent provides
 one.

 When the permission
 [lifetime](#dfn-lifetime) expires for an origin:

 1. Set the permission back to its default [permission
 state](#dfn-permission-state) (e.g., by setting it
 back to [\"prompt\"](#dfn-prompt)).
 2. For each `browsing context` associated with the
 origin (if any), [queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [permissions task
 source](#dfn-permissions-task-source) with the
 `browsing context`\'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object)
 to run the [permission revocation
 algorithm](#dfn-permission-revocation-algorithm).

 ::::
 :::
 Note[: Determining the lifetime of a permission]
 :::

 For particularly privacy-sensitive
 [features](#dfn-powerful-feature), such as [Media Capture
 and
 Streams](https://www.w3.org/TR/mediacapture-streams/){matched-text="[[[GETUSERMEDIA]]]"},
 which can provide a web application access to a user\'s camera and
 microphone, some user agents expire a permission
 [grant](#dfn-granted) as soon as a browser tab is closed or
 [navigated](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate).
 For other features, like the
 [Geolocation](https://www.w3.org/TR/geolocation/){matched-text="[[[Geolocation]]]"},
 user agents are known to offer a choice of only granting the
 permission for the session, or for one day. Others, like the
 [Notifications API
 Standard](https://notifications.spec.whatwg.org/){matched-text="[[[Notifications]]]"}
 and [Push
 API](https://www.w3.org/TR/push-api/){matched-text="[[[push-api]]]"}
 APIs, remember a user\'s decision indefinitely or until the user
 manually revokes the permission. Note that permission
 [lifetimes](#dfn-lifetime) can vary significantly between user
 agents.

 Finding the right balance for the lifetime of a permission requires
 a lot of thought and experimentation, and often evolves over a
 period of years. Implementers are encouraged to work with their UX
 security teams to find the right balance between ease of access to a
 [powerful
 feature](#dfn-powerful-feature) (i.e., reducing the number
 of permission prompts), respecting a user\'s privacy, and making
 users aware when a web application is making use of a particular
 powerful feature (e.g., via some visual or auditory UI indicator).

 If you are unsure about what
 [lifetime](#dfn-lifetime) to suggest for a [powerful
 feature](#dfn-powerful-feature), please contact the
 [Privacy Interest Group](https://www.w3.org/Privacy/IG/) for
 guidance.
 ::::

[Default permission state]:

: An
 [`PermissionState`](#dom-permissionstate) value that serves
 as a [permission](#dfn-permission)\'s [default
 state](#dfn-default-state) of a [powerful
 feature](#dfn-powerful-feature).

 If not specified, the
 [permission](#dfn-permission)\'s [default
 state](#dfn-default-state) is
 \"[`prompt`](#dom-permissionstate-prompt)\".

A [default powerful feature] is a
[powerful
feature](#dfn-powerful-feature) with all of the above types
and algorithms defaulted.

::: header-wrapper
## 5. Algorithms to interface with permissions

::: header-wrapper
### 5.1 Reading the current permission state

To [get the current permission
state], given a
[name](#dfn-name) `name` and an optional
[environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)
`settings`, run the following steps. This algorithm returns a
[`PermissionState`](#dom-permissionstate) enum value.

1. Let `descriptor` be a
 newly-created
 [`PermissionDescriptor`](#dom-permissiondescriptor) with
 [`name`](#dom-permissiondescriptor-name) initialized to `name`.
2. Return the [permission
 state](#dfn-permission-state) of `descriptor` with `settings`.

A `descriptor`\'s
[permission state], given an optional [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)
`settings` is the result of the following algorithm. It
returns a
[`PermissionState`](#dom-permissionstate) enum value:

1. If `settings` wasn\'t passed, set it to the [current
 settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object).
2. If `settings` is a [non-secure
 context](https://html.spec.whatwg.org/multipage/webappapis.html#non-secure-context),
 return
 \"[`denied`](#dom-permissionstate-denied)\".
3. Let `feature` be `descriptor`\'s
 [`name`](#dom-permissiondescriptor-name).
4. If there exists a [policy-controlled
 feature](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature)
 for `feature` and `settings`\' [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)
 has an [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)
 run the following step:
 1. Let `document` be `settings`\' [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)\'s
 [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).
 2. If `document` is not [allowed to
 use](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use)
 `feature`, return
 \"[`denied`](#dom-permissionstate-denied)\".
5. Let `key` be the result of [generating a permission
 key](#dfn-permission-key-generation-algorithm) for `descriptor` with `settings`\'s
 [top-level
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin)
 and `settings`\'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin).
6. Let `entry` be the result of [getting a permission store
 entry](#dfn-get-a-permission-store-entry) with `descriptor` and `key`.
7. If `entry` is not null, return a
 [`PermissionState`](#dom-permissionstate) enum value from
 `entry`\'s [state](#dfn-state).
8. Return the
 [`PermissionState`](#dom-permissionstate) enum value that
 represents the permission state of `feature`, taking into
 account any [permission state
 constraints](#dfn-permission-state-constraints) for `descriptor`\'s
 [`name`](#dom-permissiondescriptor-name).

As a shorthand, a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) `name`\'s [permission
state](#dfn-permission-state) is the [permission
state](#dfn-permission-state) of a
[`PermissionDescriptor`](#dom-permissiondescriptor) with its
[`name`](#dom-permissiondescriptor-name) member set to `name`.

::: header-wrapper
### 5.2 Requesting permission to use a powerful feature

To [request permission to use] a
`descriptor`, the user agent
must perform the following steps. This algorithm returns either
\"[`granted`](#dom-permissionstate-granted)\" or
\"[`denied`](#dom-permissionstate-denied)\".

1. Let `current state` be the `descriptor`\'s [permission
 state](#dfn-permission-state).
2. If `current state` is not
 \"[`prompt`](#dom-permissionstate-prompt)\", return `current state`
 and abort these steps.
3. Ask the user for [express
 permission](#dfn-express-permission) for the calling algorithm to use the
 [powerful
 feature](#dfn-powerful-feature) described by `descriptor`.
4. If the user gives [express
 permission](#dfn-express-permission) to use the powerful
 feature, set `current state` to
 \"[`granted`](#dom-permissionstate-granted)\"; otherwise to
 \"[`denied`](#dom-permissionstate-denied)\". The user\'s interaction may provide
 [new information about the user\'s
 intent](#dfn-new-information-about-the-user-s-intent) for the
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin).

 ::::
 :::
 Note
 :::

 This is intentionally vague about the details of the permission UI
 and how the user agent infers user intent. User agents should be
 able to explore lots of UI within this framework.
 ::::
5. Let `settings` be the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object).
6. Let `key` be the result of [generating a permission
 key](#dfn-permission-key-generation-algorithm) for `descriptor` with `settings`\'s
 [top-level
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin)
 and `settings`\'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin).
7. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 on the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object)\'s
 [responsible event
 loop](https://html.spec.whatwg.org/multipage/webappapis.html#responsible-event-loop)
 to [set a permission store
 entry](#dfn-set-a-permission-store-entry) with
 `descriptor`,
 `key`, and `current state`.
8. Return `current state`.

As a shorthand, [requesting permission to
use](#dfn-request-permission-to-use) a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) `name`, is the same as [requesting permission
to
use](#dfn-request-permission-to-use) a
[`PermissionDescriptor`](#dom-permissiondescriptor) with its
[`name`](#dom-permissiondescriptor-name) member set to `name`.

::: header-wrapper
### 5.3 Prompt the user to choose

To [prompt the user to choose] one or
more `options` associated with a given `descriptor` and an optional
[boolean](https://infra.spec.whatwg.org/#boolean)
`allowMultiple` (default false), the user
agent must perform the following steps. This algorithm returns either
\"[`denied`](#dom-permissionstate-denied)\" or the user\'s selection.

1. If `descriptor`\'s
 [permission
 state](#dfn-permission-state) is
 \"[`denied`](#dom-permissionstate-denied)\", return
 \"[`denied`](#dom-permissionstate-denied)\" and abort these steps.
2. If `descriptor`\'s
 [permission
 state](#dfn-permission-state) is
 \"[`granted`](#dom-permissionstate-granted)\", the user agent may return one (or
 more if `allowMultiple` is true) of
 `options` chosen by the user and abort these steps. If
 the user agent returns without prompting, then subsequent [prompts
 for the user to
 choose](#dfn-prompt-the-user-to-choose) from
 the same set of options with the same `descriptor` must return the same option(s),
 unless the user agent receives [new information about the user\'s
 intent](#dfn-new-information-about-the-user-s-intent).
3. Ask the user to choose one or more `options` or deny
 permission, and wait for them to choose:
 1. If the calling algorithm specified extra information to include
 in the prompt, include it.
 2. If `allowMultiple` is false,
 restrict selection to a single item from `options`;
 otherwise, any number may be selected by the user.
4. If the user chose one or more options, return them; otherwise return
 \"[`denied`](#dom-permissionstate-denied)\".

 ::::
 :::
 Note
 :::

 This is intentionally vague about the details of the permission UI
 and how the user agent infers user intent. User agents should be
 able to explore lots of UI within this framework (e.g., a permission
 prompt could time out and automatically return \"denied\" without
 the user making an explicit selection).
 ::::

As a shorthand, [prompting the user to
choose](#dfn-prompt-the-user-to-choose) from options associated with a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) `name`, is the same as [prompting the user to
choose](#dfn-prompt-the-user-to-choose) from those options associated
with a
[`PermissionDescriptor`](#dom-permissiondescriptor) with its
[`name`](#dom-permissiondescriptor-name) member set to `name`.

::: header-wrapper
### 5.4 Reacting to users revoking permission

When the user agent learns that the user no longer intends to grant
permission to use a feature described by the
[`PermissionDescriptor`](#dom-permissiondescriptor)
`descriptor` in the context described by the [permission
key](#dfn-permission-key) `key`, [react to the user
revoking permission] by running these
steps:

1. Run `descriptor`\'s
 [`name`](#dom-permissiondescriptor-name)\'s [permission revocation
 algorithm](#dfn-permission-revocation-algorithm).
2. [Remove a permission store
 entry](#dfn-remove-a-permission-store-entry) with
 `descriptor` and `key`.

::: header-wrapper
## 6. Permissions API

MDN[✅]{title="This feature is in all major engines."}

[Navigator/permissions](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/permissions "The Navigator.permissions read-only property returns a Permissions object that can be used to query and update permission status of APIs covered by the Permissions API.")

This feature is in all major engines.

 ------------------ -----
 Chrome 43+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 46+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 16+
 Safari iOS ?
 Samsung Internet ?
 WebView Android No
 ------------------ -----

MDN 

[WorkerNavigator/permissions](https://developer.mozilla.org/en-US/docs/Web/API/WorkerNavigator/permissions "The WorkerNavigator.permissions read-only property returns a Permissions object that can be used to query and update permission status of APIs covered by the Permissions API.")

 ------------------ -------
 Chrome 43+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox No
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 16.4+
 Safari iOS ?
 Samsung Internet ?
 WebView Android No
 ------------------ -------

::: header-wrapper
### 6.1 Extensions to the `Navigator` and `WorkerNavigator` interfaces

```
WebIDL[Exposed=(Window)]
partial interface Navigator {
 [SameObject] readonly attribute Permissions permissions;
};

[Exposed=(Worker)]
partial interface WorkerNavigator {
 [SameObject] readonly attribute Permissions permissions;
};
```

MDN[✅]{title="This feature is in all major engines."}

[Permissions](https://developer.mozilla.org/en-US/docs/Web/API/Permissions "The Permissions interface of the Permissions API provides the core Permission API functionality, such as methods for querying and revoking permissions")

This feature is in all major engines.

 ------------------ -----
 Chrome 43+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 46+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 16+
 Safari iOS ?
 Samsung Internet ?
 WebView Android No
 ------------------ -----

::: header-wrapper
### 6.2 `Permissions` interface

```
WebIDL[Exposed=(Window,Worker)]
interface Permissions {
 Promise<PermissionStatus> query(object permissionDesc);
};

dictionary PermissionDescriptor {
 required DOMString name;
};
```

MDN[✅]{title="This feature is in all major engines."}

[Permissions/query](https://developer.mozilla.org/en-US/docs/Web/API/Permissions/query "The Permissions.query() method of the Permissions interface returns the state of a user permission on the global scope.")

This feature is in all major engines.

 ------------------ -----
 Chrome 43+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 46+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 16+
 Safari iOS ?
 Samsung Internet ?
 WebView Android No
 ------------------ -----

::: header-wrapper
#### 6.2.1 `query()` method

When the [`query()`] method is invoked, the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* run the following [query a permission] algorithm, passing the parameter
`permissionDesc`:

1. If [this](https://webidl.spec.whatwg.org/#this)\'s
 [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)
 is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, then:
 1. If the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object)\'s
 [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)
 is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active),
 return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
2. Let `rootDesc` be the object `permissionDesc`
 refers to, [converted to an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value)
 of type
 [`PermissionDescriptor`](#dom-permissiondescriptor).
3. If the conversion
 [throws](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [exception](https://webidl.spec.whatwg.org/#dfn-exception),
 return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 that exception.
4. If
 `rootDesc`\[\"[`name`](#dom-permissiondescriptor-name)\"\] is not supported, return [a
 promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 ::::
 :::
 Note[: Why is this not an enum?]
 :::

 This is deliberately designed to work the same as WebIDL\'s
 [enumeration](https://webidl.spec.whatwg.org/#dfn-enumeration)
 (`enum`) and implementers are encouraged to use their own custom
 `enum` here. The reason this is not an enum in the specification is
 that browsers vary greatly in the powerful features they support.
 Using a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) to identify a powerful feature gives implementers
 the freedom to pick and choose which of the powerful features from
 the [Permissions
 Registry](https://w3c.github.io/permissions-registry/){matched-text="[[[permissions-registry]]]"}
 they wish to support.
 ::::
5. Let `typedDescriptor` be the object
 `permissionDesc` refers to, [converted to an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value)
 of `rootDesc`\'s
 [`name`](#dom-permissiondescriptor-name)\'s [permission descriptor
 type](#dfn-permission-descriptor-type).
6. If the conversion
 [throws](https://webidl.spec.whatwg.org/#dfn-throw)
 an
 [exception](https://webidl.spec.whatwg.org/#dfn-exception),
 return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 that exception.
7. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).
8. Return `promise` and continue [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):
 1. Let `status` be [create a
 `PermissionStatus`](#dfn-create-a-permissionstatus) with `typedDescriptor`.
 2. Let `query` be `status`\'s
 [`[[query]]`](#dfn-query) internal slot.
 3. Run `query`\'s
 [`name`](#dom-permissiondescriptor-name)\'s [permission query
 algorithm](#dfn-permission-query-algorithm), passing
 `query` and `status`.
 4. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task)
 on the [permissions task
 source](#dfn-permissions-task-source) with
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)
 to
 [resolve](https://webidl.spec.whatwg.org/#resolve)
 `promise` with
 `status`.

MDN[✅]{title="This feature is in all major engines."}

[PermissionStatus](https://developer.mozilla.org/en-US/docs/Web/API/PermissionStatus "The PermissionStatus interface of the Permissions API provides the state of an object and an event handler for monitoring changes to said state.")

This feature is in all major engines.

 ------------------ -----
 Chrome 43+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 46+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 16+
 Safari iOS ?
 Samsung Internet ?
 WebView Android No
 ------------------ -----

::: header-wrapper
### 6.3 `PermissionStatus` interface

```
WebIDL[Exposed=(Window,Worker)]
interface PermissionStatus : EventTarget {
 readonly attribute PermissionState state;
 readonly attribute DOMString name;
 attribute EventHandler onchange;
};

enum PermissionState {
 "granted",
 "denied",
 "prompt",
};
```

[`PermissionStatus`](#dom-permissionstatus) instances are
created with a [\[\[query\]\]] internal slot, which is an instance of a
feature\'s [permission descriptor
type](#dfn-permission-descriptor-type).

The \"[`granted`]\",
\"[`denied`]\", and
\"[`prompt`]\" enum
values represent the concepts of
[\"granted\"](#dfn-granted),
[\"denied\"](#dfn-denied), and
[\"prompt\"](#dfn-prompt) respectively.

::: header-wrapper
#### 6.3.1 Creating instances

To [create a `PermissionStatus`]
for a given
[`PermissionDescriptor`](#dom-permissiondescriptor)
`permissionDesc`:

1. Let `name` be
 `permissionDesc`\'s
 [`name`](#dom-permissiondescriptor-name).
2. Assert: The
 [feature](#dfn-powerful-feature) identified by
 `name` is supported by the user
 agent.
3. Let `status` be a new
 instance of the [permission result
 type](#dfn-permission-result-type) identified by
 `name`:
 1. Initialize `status`\'s
 [`[[query]]`](#dfn-query) internal slot to
 `permissionDesc`.
 2. Initialize `status`\'s
 [`name`](#dom-permissionstatus-name) to `name`.
4. Return `status`.

MDN[✅]{title="This feature is in all major engines."}

[PermissionStatus/name](https://developer.mozilla.org/en-US/docs/Web/API/PermissionStatus/name "The name read-only property of the PermissionStatus interface returns the name of a requested permission.")

This feature is in all major engines.

 ------------------ -----
 Chrome 97+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 93+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 16+
 Safari iOS ?
 Samsung Internet ?
 WebView Android No
 ------------------ -----

::: header-wrapper
#### 6.3.2 `name` attribute

The [`name`]
attribute returns the value it was initialized to.

MDN[✅]{title="This feature is in all major engines."}

[PermissionStatus/state](https://developer.mozilla.org/en-US/docs/Web/API/PermissionStatus/state "The state read-only property of the PermissionStatus interface returns the state of a requested permission. This property returns one of 'granted', 'denied', or 'prompt'.")

This feature is in all major engines.

 ------------------ -----
 Chrome ?
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 46+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 16+
 Safari iOS ?
 Samsung Internet ?
 WebView Android No
 ------------------ -----

::: header-wrapper
#### 6.3.3 `state` attribute

The [`state`]
attribute returns the latest value that was set on the current instance.

MDN[✅]{title="This feature is in all major engines."}

[PermissionStatus/change_event](https://developer.mozilla.org/en-US/docs/Web/API/PermissionStatus/change_event "The change event of the PermissionStatus interface fires whenever the PermissionStatus.state property changes.")

This feature is in all major engines.

 ------------------ -------
 Chrome 43+
 Chrome Android ?
 Edge ?
 Edge Mobile ?
 Firefox 46+
 Firefox Android ?
 Opera ?
 Opera Android ?
 Safari 16.4+
 Safari iOS ?
 Samsung Internet ?
 WebView Android No
 ------------------ -------

::: header-wrapper
#### 6.3.4 `onchange` attribute

The [`onchange`] attribute is an [event
handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers)
whose corresponding [event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)
is `change`.

Whenever the [user
agent](https://infra.spec.whatwg.org/#user-agent) is
aware that the state of a
[`PermissionStatus`](#dom-permissionstatus) instance
`status` has changed, it asynchronously runs the
[`PermissionStatus` update steps]:

1. If [this](https://webidl.spec.whatwg.org/#this)\'s
 [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)
 is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, then:
 1. Let `document` be `status`\'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)\'s
 [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).
 2. If `document` is null or `document` is not
 [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active),
 terminate this algorithm.
2. Let `query` be `status`\'s
 [`[[query]]`](#dfn-query) internal slot.
3. Run `query`\'s
 [`name`](#dom-permissiondescriptor-name)\'s [permission query
 algorithm](#dfn-permission-query-algorithm), passing
 `query` and `status`.
4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 on the [permissions task
 source](#dfn-permissions-task-source) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named `change` at `status`.

::: header-wrapper
#### 6.3.5 Garbage collection

[`PermissionStatus`](#dom-permissionstatus) object *MUST NOT* be
garbage collected if it has an [event
listener](https://dom.spec.whatwg.org/#concept-event-listener)
whose type is `change`.

::: header-wrapper
## 7. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

The key words *MAY*, *MUST*, *MUST NOT*, *OPTIONAL*, and *SHOULD* in
this document are to be interpreted as described in [BCP
14](https://www.rfc-editor.org/info/bcp14)
\[[RFC2119](#bib-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels")\]
\[[RFC8174](#bib-rfc8174 "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words")\] when, and only when, they appear in all capitals,
as shown here.

Two classes of product can claim conformance to this specification:
[user
agents](https://infra.spec.whatwg.org/#user-agent) and
other [specifications] (i.e., a technical
report that [specifies a powerful
feature](#dfn-specifies-a-powerful-feature) in a manner that conforms to
the requirements of this specification).

::: header-wrapper
## A. Relationship to the Permissions Policy specification

*This section is non-normative.*

Although both this specification and the [Permissions
Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[Permissions-Policy]]]"}
specification deal with \"permissions\", each specification serves a
distinct purpose in the platform. Nevertheless, the two specifications
do explicitly overlap.

On the one hand, this specification exclusively concerns itself with
[powerful
features](#dfn-powerful-feature) whose access is managed
through a user-agent mediated permissions UI (i.e., permissions where
the user gives express consent before that feature can be used, and
where the user retains the ability to deny that permission at any time
for any reason). These powerful features are registered in the
[Permissions
Registry](https://w3c.github.io/permissions-registry/){matched-text="[[[permissions-registry]]]"}.

On the other hand, the [Permissions
Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[Permissions-Policy]]]"}
specification allows developers to selectively enable and disable
policy-controlled features through a \"[permissions
policy](https://html.spec.whatwg.org/multipage/dom.html#concept-document-permissions-policy)\"
(be it a HTTP header or the
[`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow)
attribute). In that sense, the Permissions Policy subsumes this
specification in that [Permissions
Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[Permissions-Policy]]]"}
governs whether a feature is available at all, independently of this
specification. These policy-controlled features are also registered in
the [Permissions
Registry](https://w3c.github.io/permissions-registry/){matched-text="[[[permissions-registry]]]"}.

A powerful feature that has been disabled by the [Permissions
Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[Permissions-Policy]]]"}
specification always has its [permission
state](#dfn-permission-state) reflected as \"denied\" by
this specification. This occurs because [reading the current
permission](#dfn-getting-the-current-permission-state) relies on
\[[HTML](#bib-html "HTML Standard")\]\'s
\"[allowed to
use](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use)\"
check, which itself calls into the [Permissions
Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[Permissions-Policy]]]"}
specification. Important to note here is the sharing of permission names
across both specifications. Both this specification and the [Permissions
Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[Permissions-Policy]]]"}
specification rely on other specifications defining the names of the
permission and [name](#dfn-name), and they are usually named the same thing
(e.g., \"geolocation\" of the
[Geolocation](https://www.w3.org/TR/geolocation/){matched-text="[[[Geolocation]]]"},
and so on).

Finally, it\'s not possible for a powerful feature to ever become
\"granted\" through any means provided by the [Permissions
Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[Permissions-Policy]]]"}
specification. The only way that a [powerful
feature](#dfn-powerful-feature) can be
[\"granted\"](#dfn-granted) is by the user giving [express
permission](#dfn-express-permission) or by some user agent policy.

::: header-wrapper
## B. Automated testing

For the purposes of user-agent automation and application testing, this
document defines extensions to the
\[[WebDriver](#bib-webdriver "WebDriver")\]
and \[[WebDriver-BiDi](#bib-webdriver-bidi "WebDriver BiDi")\] specifications. It is *OPTIONAL* for a user agent
to support them.

```
WebIDLdictionary PermissionSetParameters {
 required object descriptor;
 required PermissionState state;
};
```

To [set a permission] given a
[`PermissionDescriptor`](#dom-permissiondescriptor)
`descriptor`, a
[`PermissionState`](#dom-permissionstate) `state`, an optional [permission
key](#dfn-permission-key) `key`, and an optional
`user agent`:

1. Let `target key` be the result of [generating a
 permission
 key](#dfn-permission-key-generation-algorithm) for `descriptor` with [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object)\'s
 [top-level
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin)
 and [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object)\'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin)
 if `key` is null, or `key` otherwise.
2. Let `settings list` be a
 [list](https://infra.spec.whatwg.org/#list)
 containing all [environment settings
 objects](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)
 which belong to the `user agent` if provided, or all user
 agents otherwise.
3. Let `targets` be an empty
 [list](https://infra.spec.whatwg.org/#list).
4. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)
 `settings` in `settings list`:
 1. Let `settings key` be be the result of [generating a
 permission
 key](#dfn-permission-key-generation-algorithm) for
 `descriptor` with
 `settings`\'s [top-level
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin)
 and `settings`\'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin).
 2. Let `matches` be the result of running the
 [permission key comparison
 algorithm](#dfn-permission-key-comparison-algorithm) for
 `descriptor`, given
 `settings key` and `key`.
 3. If `matches`, then
 [append](https://infra.spec.whatwg.org/#list-append)
 `settings` to `targets`.
5. Let `tasks` be an empty
 [list](https://infra.spec.whatwg.org/#list).
6. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object)
 `target` in `targets`:
 1. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 `task` on the [permissions task
 source](#dfn-permissions-task-source) of
 `target`\'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)\'s
 [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global)\'s
 [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc)
 to perform the following step:
 1. Interpret `state` as
 if it were the result of an invocation of [permission
 state](#dfn-permission-state) for
 `descriptor`
 with the argument `target` made at this moment.
 2. [Append](https://infra.spec.whatwg.org/#list-append)
 `task` to `tasks`.
7. Wait for all
 [tasks](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task)
 in `tasks` to have executed and return.

::: header-wrapper
### B.1 Automated testing with \[[WebDriver](#bib-webdriver "WebDriver")\]

This document defines the following [extension
commands](https://www.w3.org/TR/webdriver1/#dfn-extension-commands)
for the \[[WebDriver](#bib-webdriver "WebDriver")\] specification.

::: header-wrapper
#### B.1.1 Set Permission

------------- -------------------------------------------------------------------------------------------------------------------------------------------
 HTTP Method [URI Template](https://www.w3.org/TR/webdriver1/#dfn-extension-command-uri-template)
 POST /session/{session id}/permissions
 ------------- -------------------------------------------------------------------------------------------------------------------------------------------

The [Set Permission] [extension
command](https://www.w3.org/TR/webdriver1/#dfn-extension-commands)
simulates user modification of a
[`PermissionDescriptor`](#dom-permissiondescriptor)\'s [permission
state](#dfn-permission-state).

The [remote end
steps](https://www.w3.org/TR/webdriver1/#dfn-remote-end-steps)
are:

1. Let `parametersDict` be the `parameters`
 argument, [converted to an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value)
 of type
 [`PermissionSetParameters`](#dom-permissionsetparameters). If this
 throws an exception, return an [invalid
 argument](https://www.w3.org/TR/webdriver1/#dfn-invalid-argument)
 [error](https://www.w3.org/TR/webdriver1/#dfn-error).
2. If
 `parametersDict`.[`state`](#dom-permissionsetparameters-state) is an inappropriate [permission
 state](#dfn-permission-state) for any
 implementation-defined reason, return an [invalid
 argument](https://www.w3.org/TR/webdriver1/#dfn-invalid-argument)
 [error](https://www.w3.org/TR/webdriver1/#dfn-error).

 ::::
 :::
 Note
 :::

 For example, [user
 agents](https://infra.spec.whatwg.org/#user-agent)
 that define the \"midi\" [powerful
 feature](#dfn-powerful-feature) as \"always on\" can choose to reject
 a command to set the [permission
 state](#dfn-permission-state) to
 \"[`denied`](#dom-permissionstate-denied)\" at this step.
 ::::
3. Let `rootDesc` be
 `parametersDict`.[`descriptor`](#dom-permissionsetparameters-descriptor).
4. Let `typedDescriptor` be the object `rootDesc`
 refers to, [converted to an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value)
 of [permission descriptor
 type](#dfn-permission-descriptor-type) matching the result of
 [Get](https://tc39.es/ecma262/multipage/#sec-get-o-p)(`rootDesc`,
 \"`name`\"). If this throws an exception, return a [invalid
 argument](https://www.w3.org/TR/webdriver1/#dfn-invalid-argument)
 [error](https://www.w3.org/TR/webdriver1/#dfn-error).
5. [Set a
 permission](#dfn-set-a-permission) with
 `typedDescriptor` and
 `parametersDict`.[`state`](#dom-permissionsetparameters-state).
6. Return
 [success](https://www.w3.org/TR/webdriver1/#dfn-success)
 with data `null`.

[Example 7](#example-setting-a-permission-via-webdriver)[:
Setting a permission via WebDriver]

To [set permission](#dfn-set-permission) for
`{name: "midi", sysex: true}` of the [current settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object)
of the
[session](https://www.w3.org/TR/webdriver-bidi/#modules-session)
with ID 23 to \"`granted`\", the local end would POST to
`/session/23/permissions` with the body:

``` {aria-busy="false"}
{
 "descriptor": {
 "name": "midi",
 "sysex": true
 },
 "state": "granted"
}
```

::: header-wrapper
### B.2 Automated testing with \[[WebDriver-BiDi](#bib-webdriver-bidi "WebDriver BiDi")\]

This document defines the following [extension
modules](https://www.w3.org/TR/webdriver-bidi/#extension-modules)
for the \[[WebDriver-BiDi](#bib-webdriver-bidi "WebDriver BiDi")\] specification.

::: header-wrapper
#### B.2.1 The permissions Module

The [permissions] module contains commands for
managing the remote end browser permissions.

::: header-wrapper
##### B.2.1.1 Definition

{\^remote end definition\^}

```
PermissionsCommand = (
 permissions.setPermission
)
```

::: header-wrapper
##### B.2.1.2 Types

::: header-wrapper
###### B.2.1.2.1 The permissions.PermissionDescriptor Type

```
permissions.PermissionDescriptor = {
 name: text,
}
```

The `permissions.PermissionDescriptor` type represents a
[`PermissionDescriptor`](#dom-permissiondescriptor).

::: header-wrapper
###### B.2.1.2.2 The permissions.PermissionState Type

```
permissions.PermissionState = "granted" / "denied" / "prompt"
```

The `permissions.PermissionState` type represents a
[`PermissionState`](#dom-permissionstate).

::: header-wrapper
##### B.2.1.3 Commands

::: header-wrapper
###### B.2.1.3.1 The permissions.setPermission Command

The [Set Permission]
[command](https://www.w3.org/TR/webdriver-bidi/#command)
simulates user modification of a
[`PermissionDescriptor`](#dom-permissiondescriptor)\'s [permission
state](#dfn-permission-state).

Command Type

: ```
 permissions.setPermission = (
 method: "permissions.setPermission",
 params: permissions.SetPermissionParameters
 )

 permissions.SetPermissionParameters = {
 descriptor: permissions.PermissionDescriptor,
 state: permissions.PermissionState,
 origin: text,
 ? embeddedOrigin: text,
 ? userContext: text,
 }
 ```

Result Type
: `EmptyResult`

The [remote end
steps](https://www.w3.org/TR/webdriver2/#dfn-remote-end-steps)
with `session` and `command parameters` are:

1. Let `descriptor` be the value of the `descriptor` field
 of `command parameters`.
2. Let `permission name` be the value of the `name` field of
 `descriptor` representing
 [`name`](#dom-permissiondescriptor-name).
3. Let `state` be the value of the `state` field of
 `command parameters`.
4. Let `user context id` be the value of the `userContext`
 field of `command parameters`, if present, and `default`
 otherwise.
5. If `state` is an inappropriate [permission
 state](#dfn-permission-state) for any
 implementation-defined reason, return
 [error](https://www.w3.org/TR/webdriver2/#dfn-error)
 with [error
 code](https://www.w3.org/TR/webdriver2/#dfn-error-code)
 [invalid
 argument](https://www.w3.org/TR/webdriver2/#dfn-invalid-argument).
6. Let `typedDescriptor` be the object
 `descriptor` refers to, [converted to an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value)
 (`descriptor`, `state`) of
 [`PermissionSetParameters`](#dom-permissionsetparameters)
 `permission name`\'s [permission descriptor
 type](#dfn-permission-descriptor-type). If this conversion throws
 an exception, return
 [error](https://www.w3.org/TR/webdriver2/#dfn-error)
 with [error
 code](https://www.w3.org/TR/webdriver2/#dfn-error-code)
 [invalid
 argument](https://www.w3.org/TR/webdriver2/#dfn-invalid-argument).
7. Let `origin` be the value of the `origin` field of
 `command parameters`.
8. Let `embedded origin` be the value of the
 `embeddedOrigin` field of `command parameters`, if
 present, and `origin` otherwise.
9. Let `key` be the result of [generating a permission
 key](#dfn-permission-key-generation-algorithm) for
 `descriptor` with `origin` and
 `embedded origin`.
10. Let `user agent` be the [user
 agent](https://infra.spec.whatwg.org/#user-agent)
 that represents the [user
 context](https://www.w3.org/TR/webdriver-bidi/#user-context)
 with the id `user context id`.
11. [Set a
 permission](#dfn-set-a-permission) with
 `typedDescriptor`, `state`, `key`,
 and `user agent`.
12. Return
 [success](https://www.w3.org/TR/webdriver2/#dfn-success)
 with data `null`.

::: header-wrapper
## C. Permissions Registry

*This section is non-normative.*

::: header-wrapper
### C.1 Purpose

This [W3C
Registry](https://www.w3.org/policies/process/#w3c-registry)
provides a centralized place to find the [policy-controlled
features](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature)
and/or [powerful
features](#dfn-powerful-feature) of the web platform. Through
the [change process](#dfn-change-process) it also helps assure
permissions in the platform are consistently specified across various
specifications.

By splitting the registry into standardized permissions and provisional
permissions, the registry also provides a way to track the status of
these features.

::: header-wrapper
### C.2 Change Process

The [change process] for adding and/or updating this
registry is as follows:

1. If necessary, add a \"Permissions Policy\" section to your
 specification which includes the following:
 1. The string that identifies the policy controlled feature (e.g.,
 `"super-awesome"`). Make sure the string is linkable by wrapping
 it a
 [`dfn`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-dfn-element)
 element.

 2. The [default
 allowlist](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature-default-allowlist)
 value (e.g. `'self'`).

 ::: marker
 [Example
 8](#example-specifying-a-permissions-policy)[:
 Specifying a Permissions Policy]
 :::

 An typical example that would meet this criteria:

 > The Super Awesome API defines a [policy-controlled
 > feature](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature)
 > identified by the string \"super-awesome\". Its [default
 > allowlist](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature-default-allowlist)
 > is `'self'`.
2. Determine if your feature meets the definition of a [powerful
 feature](#dfn-powerful-feature) (i.e., requires [express
 permission](#dfn-express-permission) to be used). If it does:
 1. [Specify a powerful
 feature](#dfn-specifies-a-powerful-feature) in your specification in
 conformance with the
 [Permissions](https://www.w3.org/TR/permissions/){matched-text="[[[Permissions]]]"}
 specification.
3. Modify either the [table of standardized
 permissions](#dfn-table-of-standardized-permissions-of-the-web-platform) or the [table of
 provisional
 permissions](#dfn-table-of-provisional-permissions) filling out each column
 with the required information.
4. Submit a pull request to the [Powerful Features Registry
 Repository](https://github.com/w3c/permissions/) on GitHub with your
 changes. The maintainers of the repository will review your pull
 request and check that everything integrates properly.

::: header-wrapper
### C.3 Registry table of standardized permissions

For a permission to appear in the table of standardized permissions, and
thus be considered a [standardized
permission], it needs to meet the following
criteria:

- Implemented and demonstrably interoperable in at least two browser
 engines (e.g., has accompanying [Web Platform
 Tests](https://web-platform-tests.org)).
- Is specified in published as [technical
 report](https://www.w3.org/policies/process/#technical-report)
 by a [W3C] [Working
 Group](https://www.w3.org/policies/process/#GroupsWG)
 with maturity of [first public working
 draft](https://www.w3.org/policies/process/#fpwd) or
 above, or is published by the [WHATWG](https://whatwg.org) as a
 standard.

Each [permission](#dfn-permission) is identified by a unique
literal string. In the case of [Permissions
Policy](https://www.w3.org/TR/permissions-policy-1/){matched-text="[[[Permissions-Policy]]]"},
the string identifies a [policy-controlled
features](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature).
Similarly, in the
[Permissions](https://www.w3.org/TR/permissions/){matched-text="[[[Permissions]]]"}
specification the string identifies a [powerful
feature](#dfn-powerful-feature).

Note[: Permissions and Permissions Policy]

Not every [policy-controlled
feature](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature)
is [powerful
features](#dfn-powerful-feature). For example, \"web-share\" is
a [policy-controlled
feature](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature)
that is not classified as a [powerful
feature](#dfn-powerful-feature) because it doesn\'t require
[express
permission](#dfn-express-permission) to be used. However, with very
few exceptions, most [powerful
features](#dfn-powerful-feature) are also [policy-controlled
features](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature).
For example, \"geolocation\" is both a [policy-controlled
feature](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature)
and a [powerful
feature](#dfn-powerful-feature), as it requires [express
permission](#dfn-express-permission) to be used. Please refer to
the
[Permissions](https://www.w3.org/TR/permissions/){matched-text="[[[Permissions]]]"}
specification for guidance on how to [specify a powerful
feature](#dfn-specifies-a-powerful-feature).

+-----------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+---------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| Identifying string | Is [policy-controlled | Is [powerful | Specification | Implementations |
| | feature](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature)? | feature](#dfn-powerful-feature)? | | |
| | | | +--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| | | | | [Chromium](https://www.chromium.org/Home/) | [Gecko](https://developer.mozilla.org/en-US/docs/Glossary/Gecko) | [WebKit](https://webkit.org/) |
+-----------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+---------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| [\"geolocation\"](https://www.w3.org/TR/geolocation/#dfn-geolocation) | YES | YES | [Geolocation](https://www.w3.org/TR/geolocation/){matched-text="[[[geolocation]]]"} | YES | YES | YES |
+-----------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+---------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| \"[notifications](https://notifications.spec.whatwg.org/#permissiondef-notifications)\" | NO | YES | [Notifications API | YES | YES | YES |
| | | | Standard](https://notifications.spec.whatwg.org/){matched-text="[[[NOTIFICATIONS]]]"} | | | |
+-----------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+---------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| [\"push\"](https://www.w3.org/TR/push-api/#dfn-push) | NO | YES | [Push API](https://www.w3.org/TR/push-api/){matched-text="[[[push-api]]]"} | YES | YES | YES |
+-----------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+---------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| [\"web-share\"](https://www.w3.org/TR/web-share/#dfn-web-share) | YES | NO | [Web Share API](https://www.w3.org/TR/web-share/){matched-text="[[[Web-Share]]]"} | YES | YES | YES |
+-----------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+---------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+

: [Table of standardized permissions of the web
platform]

::: header-wrapper
### C.4 Registry table of provisional permissions

Provisional permissions are permissions that are not yet
[standardized](#dfn-standardized-permission)
(i.e., they are either experimental, still in the incubation phase, or
are only implemented in a single browser engine).

+---------------------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+-----------------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| Identifying string | Is [policy-controlled | Is [powerful | Specification | Implementations |
| | feature](https://www.w3.org/TR/permissions-policy-1/#policy-controlled-feature)? | feature](#dfn-powerful-feature)? | | |
| | | | +--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| | | | | [Chromium](https://www.chromium.org/Home/) | [Gecko](https://developer.mozilla.org/en-US/docs/Glossary/Gecko) | [WebKit](https://webkit.org/) |
+---------------------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+-----------------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| [\"accelerometer\"](https://www.w3.org/TR/orientation-event/#permissiondef-accelerometer) | YES | YES | [Device Orientation and | YES | NO | NO |
| | | | Motion](https://www.w3.org/TR/orientation-event/){matched-text="[[[orientation-event]]]"} | | | |
+---------------------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+-----------------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| \"[window-management](https://www.w3.org/TR/window-management/#permissiondef-window-management)\" | YES | YES | [Window | YES | NO | NO |
| | | | Management](https://www.w3.org/TR/window-management/){matched-text="[[[window-management]]]"} | | | |
+---------------------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+-----------------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+
| \"[local-fonts](https://wicg.github.io/local-font-access/#permissiondef-local-fonts)\" | YES | YES | [Local Font Access | YES | NO | NO |
| | | | API](https://wicg.github.io/local-font-access/){matched-text="[[[local-font-access]]]"} | | | |
+---------------------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+------------------------------------------------------------------+-----------------------------------------------------------------------------------------------+--------------------------------------------+------------------------------------------------------------------+-------------------------------+

: [Table of provisional
permissions]

::: header-wrapper
## D. Privacy considerations

An adversary could use a [permission
state](#dfn-permission-state) as an element in creating a
\"fingerprint\" corresponding to an end-user. Although an adversary can
already determine the state of a permission by actually using the API,
that often leads to a UI prompt being presented to the end-user (if the
permission was not already
[\"granted\"](#dfn-granted)). Even though this API doesn\'t expose new
fingerprinting information to websites, it makes it easier for an
adversary to have discreet access to this information.

A user agent *SHOULD* provide a means for the user to review, update,
and reset the [permission](#dfn-permission)
[state](#dfn-states) of [powerful
features](#dfn-powerful-feature) associated with an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin).

::: header-wrapper
## E. Security considerations

There are no documented security considerations at this time. Readers
are instead encouraged to read section [D. Privacy
considerations](#privacy-considerations).

::: header-wrapper
## F. IDL Index

```
WebIDL[Exposed=(Window)]
partial interface Navigator {
 [SameObject] readonly attribute Permissions permissions;
};

[Exposed=(Worker)]
partial interface WorkerNavigator {
 [SameObject] readonly attribute Permissions permissions;
};

[Exposed=(Window,Worker)]
interface Permissions {
 Promise<PermissionStatus> query(object permissionDesc);
};

dictionary PermissionDescriptor {
 required DOMString name;
};

[Exposed=(Window,Worker)]
interface PermissionStatus : EventTarget {
 readonly attribute PermissionState state;
 readonly attribute DOMString name;
 attribute EventHandler onchange;
};

enum PermissionState {
 "granted",
 "denied",
 "prompt",
};

dictionary PermissionSetParameters {
 required object descriptor;
 required PermissionState state;
};
```

::: header-wrapper
## G. Acknowledgments

*This section is non-normative.*

The editors would like to thank Adrienne Porter Felt, Anne van Kesteren,
Domenic Denicola, Jake Archibald and Wendy Seltzer for their help with
the API design and editorial work.

::: header-wrapper
## H. References

::: header-wrapper
### H.1 Normative references

\[dom\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[ecma-262\]
: [ECMAScript Language
 Specification](https://tc39.es/ecma262/multipage/). Ecma
 International. URL: <https://tc39.es/ecma262/multipage/>

\[HTML\]
: [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
 Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
 Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
 <https://html.spec.whatwg.org/multipage/>

\[infra\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[Notifications\]
: [Notifications API
 Standard](https://notifications.spec.whatwg.org/). Anne van
 Kesteren. WHATWG. Living Standard. URL:
 <https://notifications.spec.whatwg.org/>

\[Permissions-Policy\]
: [Permissions Policy](https://www.w3.org/TR/permissions-policy-1/).
 Ian Clelland. W3C. 6 August 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/permissions-policy-1/>

\[permissions-registry\]
: [Permissions Registry](https://w3c.github.io/permissions-registry/).
 W3C. Draft Registry. URL:
 <https://w3c.github.io/permissions-registry/>

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

\[WebDriver\]
: [WebDriver](https://www.w3.org/TR/webdriver1/). Simon Stewart; David
 Burns. W3C. 5 June 2018. W3C Recommendation. URL:
 <https://www.w3.org/TR/webdriver1/>

\[WebDriver-BiDi\]
: [WebDriver BiDi](https://www.w3.org/TR/webdriver-bidi/). James
 Graham; Alex Rudenko; Maksim Sadym. W3C. 1 October 2025. W3C Working
 Draft. URL: <https://www.w3.org/TR/webdriver-bidi/>

\[webdriver2\]
: [WebDriver](https://www.w3.org/TR/webdriver2/). Simon Stewart; David
 Burns. W3C. 8 September 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/webdriver2/>

\[WEBIDL\]
: [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
 Timothy Gu. WHATWG. Living Standard. URL:
 <https://webidl.spec.whatwg.org/>

::: header-wrapper
### H.2 Informative references

\[appmanifest\]
: [Web Application Manifest](https://www.w3.org/TR/appmanifest/).
 Marcos Caceres; Kenneth Christiansen; Diego Gonzalez-Zuniga; Daniel
 Murphy; Christian Liebel. W3C. 3 September 2025. W3C Working Draft.
 URL: <https://www.w3.org/TR/appmanifest/>

\[Geolocation\]
: [Geolocation](https://www.w3.org/TR/geolocation/). Marcos Caceres;
 Reilly Grant. W3C. 23 September 2025. W3C Recommendation. URL:
 <https://www.w3.org/TR/geolocation/>

\[GETUSERMEDIA\]
: [Media Capture and
 Streams](https://www.w3.org/TR/mediacapture-streams/). Cullen
 Jennings; Jan-Ivar Bruaroey; Henrik Boström; youenn fablet. W3C. 25
 September 2025. CRD. URL:
 <https://www.w3.org/TR/mediacapture-streams/>

\[local-font-access\]
: [Local Font Access API](https://wicg.github.io/local-font-access/).
 W3C. Draft Community Group Report. URL:
 <https://wicg.github.io/local-font-access/>

\[orientation-event\]
: [Device Orientation and
 Motion](https://www.w3.org/TR/orientation-event/). Reilly Grant;
 Marcos Caceres. W3C. 12 February 2025. CRD. URL:
 <https://www.w3.org/TR/orientation-event/>

\[Permissions\]
: [Permissions](https://www.w3.org/TR/permissions/). Marcos Caceres;
 Mike Taylor. W3C. 26 September 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/permissions/>

\[push-api\]
: [Push API](https://www.w3.org/TR/push-api/). Marcos Caceres; Kagami
 Rosylight. W3C. 25 September 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/push-api/>

\[w3c-process\]
: [W3C Process Document](https://www.w3.org/policies/process/).
 Elika J. Etemad (fantasai); Florian Rivoal. W3C. 18 August 2025.
 URL: <https://www.w3.org/policies/process/>

\[Web-Share\]
: [Web Share API](https://www.w3.org/TR/web-share/). Marcos Caceres;
 Eric Willigers; Matt Giuca. W3C. 30 May 2023. W3C Recommendation.
 URL: <https://www.w3.org/TR/web-share/>

\[window-management\]
: [Window Management](https://www.w3.org/TR/window-management/).
 Joshua Bell; Mike Wasserman. W3C. 7 June 2024. W3C Working Draft.
 URL: <https://www.w3.org/TR/window-management/>

[[↑]](#title)

[Permalink](#dfn-permission)
[exported]

**Referenced in:**

- [§ 3.1 Permissions](#ref-for-dfn-permission-1 "§ 3.1 Permissions")
 [(2)](#ref-for-dfn-permission-2 "Reference 2")
- [§ 3.2 Permission
 Store](#ref-for-dfn-permission-3 "§ 3.2 Permission Store")
- [§ 3.3 Powerful
 features](#ref-for-dfn-permission-4 "§ 3.3 Powerful features")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permission-5 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-permission-6 "Reference 2")
 [(3)](#ref-for-dfn-permission-7 "Reference 3")
- [§ C.3 Registry table of standardized
 permissions](#ref-for-dfn-permission-8 "§ C.3 Registry table of standardized permissions")
- [§ D. Privacy
 considerations](#ref-for-dfn-permission-9 "§ D. Privacy considerations")

[Permalink](#dfn-express-permission)
[exported]

**Referenced in:**

- [§ 3.1
 Permissions](#ref-for-dfn-express-permission-1 "§ 3.1 Permissions")
 [(2)](#ref-for-dfn-express-permission-2 "Reference 2")
 [(3)](#ref-for-dfn-express-permission-3 "Reference 3")
 [(4)](#ref-for-dfn-express-permission-4 "Reference 4")
- [§ 3.3 Powerful
 features](#ref-for-dfn-express-permission-5 "§ 3.3 Powerful features")
 [(2)](#ref-for-dfn-express-permission-6 "Reference 2")
- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dfn-express-permission-7 "§ 5.2 Requesting permission to use a powerful feature")
 [(2)](#ref-for-dfn-express-permission-8 "Reference 2")
- [§ A. Relationship to the Permissions Policy
 specification](#ref-for-dfn-express-permission-9 "§ A. Relationship to the Permissions Policy specification")
- [§ C.2 Change
 Process](#ref-for-dfn-express-permission-10 "§ C.2 Change Process")
- [§ C.3 Registry table of standardized
 permissions](#ref-for-dfn-express-permission-11 "§ C.3 Registry table of standardized permissions")
 [(2)](#ref-for-dfn-express-permission-12 "Reference 2")

[Permalink](#dfn-states)

**Referenced in:**

- [§ 3.1 Permissions](#ref-for-dfn-states-1 "§ 3.1 Permissions")
 [(2)](#ref-for-dfn-states-2 "Reference 2")
- [§ 3.2 Permission
 Store](#ref-for-dfn-states-3 "§ 3.2 Permission Store")
 [(2)](#ref-for-dfn-states-4 "Reference 2")
- [§ D. Privacy
 considerations](#ref-for-dfn-states-5 "§ D. Privacy considerations")

[Permalink](#dfn-denied)
[exported]

**Referenced in:**

- [§ 3.1 Permissions](#ref-for-dfn-denied-1 "§ 3.1 Permissions")
 [(2)](#ref-for-dfn-denied-2 "Reference 2")
- [§ 6.3 PermissionStatus
 interface](#ref-for-dfn-denied-3 "§ 6.3 PermissionStatus interface")

[Permalink](#dfn-granted)
[exported]

**Referenced in:**

- [§ 3.1 Permissions](#ref-for-dfn-granted-1 "§ 3.1 Permissions")
 [(2)](#ref-for-dfn-granted-2 "Reference 2")
- [§ 3.3 Powerful
 features](#ref-for-dfn-granted-3 "§ 3.3 Powerful features")
 [(2)](#ref-for-dfn-granted-4 "Reference 2")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-granted-5 "§ 4. Specifying a powerful feature")
- [§ 6.3 PermissionStatus
 interface](#ref-for-dfn-granted-6 "§ 6.3 PermissionStatus interface")
- [§ A. Relationship to the Permissions Policy
 specification](#ref-for-dfn-granted-7 "§ A. Relationship to the Permissions Policy specification")
- [§ D. Privacy
 considerations](#ref-for-dfn-granted-8 "§ D. Privacy considerations")

[Permalink](#dfn-prompt)
[exported]

**Referenced in:**

- [§ 3.1 Permissions](#ref-for-dfn-prompt-1 "§ 3.1 Permissions")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-prompt-2 "§ 4. Specifying a powerful feature")
- [§ 6.3 PermissionStatus
 interface](#ref-for-dfn-prompt-3 "§ 6.3 PermissionStatus interface")

[Permalink](#dfn-new-information-about-the-user-s-intent)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-new-information-about-the-user-s-intent-1 "§ 4. Specifying a powerful feature")
- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dfn-new-information-about-the-user-s-intent-2 "§ 5.2 Requesting permission to use a powerful feature")
- [§ 5.3 Prompt the user to
 choose](#ref-for-dfn-new-information-about-the-user-s-intent-3 "§ 5.3 Prompt the user to choose")

[Permalink](#dfn-implicit-signals)

**Referenced in:**

- [§ 3.1
 Permissions](#ref-for-dfn-implicit-signals-1 "§ 3.1 Permissions")

[Permalink](#dfn-lifetime)
[exported]

**Referenced in:**

- [§ 3.1 Permissions](#ref-for-dfn-lifetime-1 "§ 3.1 Permissions")
 [(2)](#ref-for-dfn-lifetime-2 "Reference 2")
- [§ 3.2 Permission
 Store](#ref-for-dfn-lifetime-3 "§ 3.2 Permission Store")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-lifetime-4 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-lifetime-5 "Reference 2")
 [(3)](#ref-for-dfn-lifetime-6 "Reference 3")
 [(4)](#ref-for-dfn-lifetime-7 "Reference 4")
 [(5)](#ref-for-dfn-lifetime-8 "Reference 5")
 [(6)](#ref-for-dfn-lifetime-9 "Reference 6")

[Permalink](#dfn-default-state)

**Referenced in:**

- [§ 3.1 Permissions](#ref-for-dfn-default-state-1 "§ 3.1 Permissions")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-default-state-2 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-default-state-3 "Reference 2")

[Permalink](#dfn-permission-store)
[exported]

**Referenced in:**

- [§ 3.2 Permission
 Store](#ref-for-dfn-permission-store-1 "§ 3.2 Permission Store")
 [(2)](#ref-for-dfn-permission-store-2 "Reference 2")
 [(3)](#ref-for-dfn-permission-store-3 "Reference 3")
 [(4)](#ref-for-dfn-permission-store-4 "Reference 4")
 [(5)](#ref-for-dfn-permission-store-5 "Reference 5")

[Permalink](#dfn-permission-store-entry)
[exported]

**Referenced in:**

- [§ 3.2 Permission
 Store](#ref-for-dfn-permission-store-entry-1 "§ 3.2 Permission Store")
 [(2)](#ref-for-dfn-permission-store-entry-2 "Reference 2")
 [(3)](#ref-for-dfn-permission-store-entry-3 "Reference 3")
 [(4)](#ref-for-dfn-permission-store-entry-4 "Reference 4")
 [(5)](#ref-for-dfn-permission-store-entry-5 "Reference 5")
 [(6)](#ref-for-dfn-permission-store-entry-6 "Reference 6")
 [(7)](#ref-for-dfn-permission-store-entry-7 "Reference 7")

[Permalink](#dfn-descriptor)
[exported]

**Referenced in:**

- [§ 3.2 Permission
 Store](#ref-for-dfn-descriptor-1 "§ 3.2 Permission Store")
 [(2)](#ref-for-dfn-descriptor-2 "Reference 2")
 [(3)](#ref-for-dfn-descriptor-3 "Reference 3")
 [(4)](#ref-for-dfn-descriptor-4 "Reference 4")
 [(5)](#ref-for-dfn-descriptor-5 "Reference 5")

[Permalink](#dfn-key)
[exported]

**Referenced in:**

- [§ 3.2 Permission Store](#ref-for-dfn-key-1 "§ 3.2 Permission Store")
 [(2)](#ref-for-dfn-key-2 "Reference 2")
 [(3)](#ref-for-dfn-key-3 "Reference 3")
 [(4)](#ref-for-dfn-key-4 "Reference 4")
 [(5)](#ref-for-dfn-key-5 "Reference 5")

[Permalink](#dfn-state)
[exported]

**Referenced in:**

- [§ 3.2 Permission
 Store](#ref-for-dfn-state-1 "§ 3.2 Permission Store")
- [§ 5.1 Reading the current permission
 state](#ref-for-dfn-state-2 "§ 5.1 Reading the current permission state")

[Permalink](#dfn-get-a-permission-store-entry)
[exported]

**Referenced in:**

- [§ 5.1 Reading the current permission
 state](#ref-for-dfn-get-a-permission-store-entry-1 "§ 5.1 Reading the current permission state")

[Permalink](#dfn-set-a-permission-store-entry)
[exported]

**Referenced in:**

- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dfn-set-a-permission-store-entry-1 "§ 5.2 Requesting permission to use a powerful feature")

[Permalink](#dfn-remove-a-permission-store-entry)
[exported]

**Referenced in:**

- [§ 5.4 Reacting to users revoking
 permission](#ref-for-dfn-remove-a-permission-store-entry-1 "§ 5.4 Reacting to users revoking permission")

[Permalink](#dfn-permission-key)
[exported]

**Referenced in:**

- [§ 3.2 Permission
 Store](#ref-for-dfn-permission-key-1 "§ 3.2 Permission Store")
 [(2)](#ref-for-dfn-permission-key-2 "Reference 2")
 [(3)](#ref-for-dfn-permission-key-3 "Reference 3")
 [(4)](#ref-for-dfn-permission-key-4 "Reference 4")
 [(5)](#ref-for-dfn-permission-key-5 "Reference 5")
 [(6)](#ref-for-dfn-permission-key-6 "Reference 6")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permission-key-7 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-permission-key-8 "Reference 2")
 [(3)](#ref-for-dfn-permission-key-9 "Reference 3")
 [(4)](#ref-for-dfn-permission-key-10 "Reference 4")
- [§ 5.4 Reacting to users revoking
 permission](#ref-for-dfn-permission-key-11 "§ 5.4 Reacting to users revoking permission")
- [§ B. Automated
 testing](#ref-for-dfn-permission-key-12 "§ B. Automated testing")

[Permalink](#dfn-is-equal-to)
[exported]

**Referenced in:**

- [§ 3.2 Permission
 Store](#ref-for-dfn-is-equal-to-1 "§ 3.2 Permission Store")
 [(2)](#ref-for-dfn-is-equal-to-2 "Reference 2")
 [(3)](#ref-for-dfn-is-equal-to-3 "Reference 3")

[Permalink](#dfn-powerful-feature)
[exported]

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dfn-powerful-feature-1 "§ 1. Introduction")
- [§ 2. Examples of
 usage](#ref-for-dfn-powerful-feature-2 "§ 2. Examples of usage")
- [§ 3. Model](#ref-for-dfn-powerful-feature-3 "§ 3. Model")
- [§ 3.1
 Permissions](#ref-for-dfn-powerful-feature-4 "§ 3.1 Permissions")
 [(2)](#ref-for-dfn-powerful-feature-5 "Reference 2")
 [(3)](#ref-for-dfn-powerful-feature-6 "Reference 3")
 [(4)](#ref-for-dfn-powerful-feature-7 "Reference 4")
 [(5)](#ref-for-dfn-powerful-feature-8 "Reference 5")
 [(6)](#ref-for-dfn-powerful-feature-9 "Reference 6")
 [(7)](#ref-for-dfn-powerful-feature-10 "Reference 7")
- [§ 3.3 Powerful
 features](#ref-for-dfn-powerful-feature-11 "§ 3.3 Powerful features")
 [(2)](#ref-for-dfn-powerful-feature-12 "Reference 2")
- [§ 3.3.1 Aspects](#ref-for-dfn-powerful-feature-13 "§ 3.3.1 Aspects")
 [(2)](#ref-for-dfn-powerful-feature-14 "Reference 2")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-powerful-feature-15 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-powerful-feature-16 "Reference 2")
 [(3)](#ref-for-dfn-powerful-feature-17 "Reference 3")
 [(4)](#ref-for-dfn-powerful-feature-18 "Reference 4")
 [(5)](#ref-for-dfn-powerful-feature-19 "Reference 5")
 [(6)](#ref-for-dfn-powerful-feature-20 "Reference 6")
 [(7)](#ref-for-dfn-powerful-feature-21 "Reference 7")
 [(8)](#ref-for-dfn-powerful-feature-22 "Reference 8")
 [(9)](#ref-for-dfn-powerful-feature-23 "Reference 9")
 [(10)](#ref-for-dfn-powerful-feature-24 "Reference 10")
 [(11)](#ref-for-dfn-powerful-feature-25 "Reference 11")
 [(12)](#ref-for-dfn-powerful-feature-26 "Reference 12")
- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dfn-powerful-feature-27 "§ 5.2 Requesting permission to use a powerful feature")
- [§ 6.3.1 Creating
 instances](#ref-for-dfn-powerful-feature-28 "§ 6.3.1 Creating instances")
- [§ A. Relationship to the Permissions Policy
 specification](#ref-for-dfn-powerful-feature-29 "§ A. Relationship to the Permissions Policy specification")
 [(2)](#ref-for-dfn-powerful-feature-30 "Reference 2")
- [§ B.1.1 Set
 Permission](#ref-for-dfn-powerful-feature-31 "§ B.1.1 Set Permission")
- [§ C.1 Purpose](#ref-for-dfn-powerful-feature-32 "§ C.1 Purpose")
- [§ C.2 Change
 Process](#ref-for-dfn-powerful-feature-33 "§ C.2 Change Process")
- [§ C.3 Registry table of standardized
 permissions](#ref-for-dfn-powerful-feature-34 "§ C.3 Registry table of standardized permissions")
 [(2)](#ref-for-dfn-powerful-feature-35 "Reference 2")
 [(3)](#ref-for-dfn-powerful-feature-36 "Reference 3")
 [(4)](#ref-for-dfn-powerful-feature-37 "Reference 4")
 [(5)](#ref-for-dfn-powerful-feature-38 "Reference 5")
 [(6)](#ref-for-dfn-powerful-feature-39 "Reference 6")
- [§ C.4 Registry table of provisional
 permissions](#ref-for-dfn-powerful-feature-40 "§ C.4 Registry table of provisional permissions")
- [§ D. Privacy
 considerations](#ref-for-dfn-powerful-feature-41 "§ D. Privacy considerations")

[Permalink](#dfn-name)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-name-1 "§ 4. Specifying a powerful feature")
- [§ 5.1 Reading the current permission
 state](#ref-for-dfn-name-2 "§ 5.1 Reading the current permission state")
- [§ A. Relationship to the Permissions Policy
 specification](#ref-for-dfn-name-3 "§ A. Relationship to the Permissions Policy specification")

[Permalink](#dfn-aspects)

**Referenced in:**

- [§ 3.3.1 Aspects](#ref-for-dfn-aspects-1 "§ 3.3.1 Aspects")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-aspects-2 "§ 4. Specifying a powerful feature")

[Permalink](#dfn-permissions-task-source)

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permissions-task-source-1 "§ 4. Specifying a powerful feature")
- [§ 6.2.1 query()
 method](#ref-for-dfn-permissions-task-source-2 "§ 6.2.1 query() method")
- [§ 6.3.4 onchange
 attribute](#ref-for-dfn-permissions-task-source-3 "§ 6.3.4 onchange attribute")
- [§ B. Automated
 testing](#ref-for-dfn-permissions-task-source-4 "§ B. Automated testing")

[Permalink](#dfn-specifies-a-powerful-feature)
[exported]

**Referenced in:**

- [§ 7.
 Conformance](#ref-for-dfn-specifies-a-powerful-feature-1 "§ 7. Conformance")
- [§ C.2 Change
 Process](#ref-for-dfn-specifies-a-powerful-feature-2 "§ C.2 Change Process")
- [§ C.3 Registry table of standardized
 permissions](#ref-for-dfn-specifies-a-powerful-feature-3 "§ C.3 Registry table of standardized permissions")

[Permalink](#dfn-permission-descriptor-type)
[exported]

**Referenced in:**

- [§ 3.3.1
 Aspects](#ref-for-dfn-permission-descriptor-type-1 "§ 3.3.1 Aspects")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permission-descriptor-type-2 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-permission-descriptor-type-3 "Reference 2")
- [§ 6.2.1 query()
 method](#ref-for-dfn-permission-descriptor-type-4 "§ 6.2.1 query() method")
- [§ 6.3 PermissionStatus
 interface](#ref-for-dfn-permission-descriptor-type-5 "§ 6.3 PermissionStatus interface")
- [§ B.1.1 Set
 Permission](#ref-for-dfn-permission-descriptor-type-6 "§ B.1.1 Set Permission")
- [§ B.2.1.3.1 The permissions.setPermission
 Command](#ref-for-dfn-permission-descriptor-type-7 "§ B.2.1.3.1 The permissions.setPermission Command")

[Permalink](#dfn-stronger-than)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-stronger-than-1 "§ 4. Specifying a powerful feature")

[Permalink](#dfn-permission-state-constraints)
[exported]

**Referenced in:**

- [§ 5.1 Reading the current permission
 state](#ref-for-dfn-permission-state-constraints-1 "§ 5.1 Reading the current permission state")

[Permalink](#dfn-extra-permission-data-type)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-extra-permission-data-type-1 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-extra-permission-data-type-2 "Reference 2")

[Permalink](#dfn-extra-permission-data)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-extra-permission-data-1 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-extra-permission-data-2 "Reference 2")
 [(3)](#ref-for-dfn-extra-permission-data-3 "Reference 3")

[Permalink](#dfn-extra-permission-data-constraints)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-extra-permission-data-constraints-1 "§ 4. Specifying a powerful feature")

[Permalink](#dfn-permission-result-type)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permission-result-type-1 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-permission-result-type-2 "Reference 2")
- [§ 6.3.1 Creating
 instances](#ref-for-dfn-permission-result-type-3 "§ 6.3.1 Creating instances")

[Permalink](#dfn-permission-query-algorithm)
[exported]

**Referenced in:**

- [§ 6.2.1 query()
 method](#ref-for-dfn-permission-query-algorithm-1 "§ 6.2.1 query() method")
- [§ 6.3.4 onchange
 attribute](#ref-for-dfn-permission-query-algorithm-2 "§ 6.3.4 onchange attribute")

[Permalink](#dfn-default-permission-query-algorithm)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-default-permission-query-algorithm-1 "§ 4. Specifying a powerful feature")

[Permalink](#dfn-permission-key-type)
[exported]

**Referenced in:**

- [§ 3.2 Permission
 Store](#ref-for-dfn-permission-key-type-1 "§ 3.2 Permission Store")
 [(2)](#ref-for-dfn-permission-key-type-2 "Reference 2")
 [(3)](#ref-for-dfn-permission-key-type-3 "Reference 3")
 [(4)](#ref-for-dfn-permission-key-type-4 "Reference 4")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permission-key-type-5 "§ 4. Specifying a powerful feature")

[Permalink](#dfn-permission-key-generation-algorithm)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permission-key-generation-algorithm-1 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-permission-key-generation-algorithm-2 "Reference 2")
- [§ 5.1 Reading the current permission
 state](#ref-for-dfn-permission-key-generation-algorithm-3 "§ 5.1 Reading the current permission state")
- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dfn-permission-key-generation-algorithm-4 "§ 5.2 Requesting permission to use a powerful feature")
- [§ B. Automated
 testing](#ref-for-dfn-permission-key-generation-algorithm-5 "§ B. Automated testing")
 [(2)](#ref-for-dfn-permission-key-generation-algorithm-6 "Reference 2")
- [§ B.2.1.3.1 The permissions.setPermission
 Command](#ref-for-dfn-permission-key-generation-algorithm-7 "§ B.2.1.3.1 The permissions.setPermission Command")

[Permalink](#dfn-default-permission-key-generation-algorithm)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-default-permission-key-generation-algorithm-1 "§ 4. Specifying a powerful feature")

[Permalink](#dfn-permission-key-comparison-algorithm)
[exported]

**Referenced in:**

- [§ 3.2 Permission
 Store](#ref-for-dfn-permission-key-comparison-algorithm-1 "§ 3.2 Permission Store")
- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permission-key-comparison-algorithm-2 "§ 4. Specifying a powerful feature")
- [§ B. Automated
 testing](#ref-for-dfn-permission-key-comparison-algorithm-3 "§ B. Automated testing")

[Permalink](#dfn-default-permission-key-comparison-algorithm)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-default-permission-key-comparison-algorithm-1 "§ 4. Specifying a powerful feature")

[Permalink](#dfn-permission-revocation-algorithm)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permission-revocation-algorithm-1 "§ 4. Specifying a powerful feature")
- [§ 5.4 Reacting to users revoking
 permission](#ref-for-dfn-permission-revocation-algorithm-2 "§ 5.4 Reacting to users revoking permission")

[Permalink](#dfn-default-permission-state)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-default-powerful-feature)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-getting-the-current-permission-state)
[exported]

**Referenced in:**

- [§ A. Relationship to the Permissions Policy
 specification](#ref-for-dfn-getting-the-current-permission-state-1 "§ A. Relationship to the Permissions Policy specification")

[Permalink](#dfn-permission-state)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permission-state-1 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dfn-permission-state-2 "Reference 2")
 [(3)](#ref-for-dfn-permission-state-3 "Reference 3")
 [(4)](#ref-for-dfn-permission-state-4 "Reference 4")
 [(5)](#ref-for-dfn-permission-state-5 "Reference 5")
 [(6)](#ref-for-dfn-permission-state-6 "Reference 6")
 [(7)](#ref-for-dfn-permission-state-7 "Reference 7")
 [(8)](#ref-for-dfn-permission-state-8 "Reference 8")
- [§ 5.1 Reading the current permission
 state](#ref-for-dfn-permission-state-9 "§ 5.1 Reading the current permission state")
 [(2)](#ref-for-dfn-permission-state-10 "Reference 2")
 [(3)](#ref-for-dfn-permission-state-11 "Reference 3")
- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dfn-permission-state-12 "§ 5.2 Requesting permission to use a powerful feature")
- [§ 5.3 Prompt the user to
 choose](#ref-for-dfn-permission-state-13 "§ 5.3 Prompt the user to choose")
 [(2)](#ref-for-dfn-permission-state-14 "Reference 2")
- [§ A. Relationship to the Permissions Policy
 specification](#ref-for-dfn-permission-state-15 "§ A. Relationship to the Permissions Policy specification")
- [§ B. Automated
 testing](#ref-for-dfn-permission-state-16 "§ B. Automated testing")
- [§ B.1.1 Set
 Permission](#ref-for-dfn-permission-state-17 "§ B.1.1 Set Permission")
 [(2)](#ref-for-dfn-permission-state-18 "Reference 2")
 [(3)](#ref-for-dfn-permission-state-19 "Reference 3")
- [§ B.2.1.3.1 The permissions.setPermission
 Command](#ref-for-dfn-permission-state-20 "§ B.2.1.3.1 The permissions.setPermission Command")
 [(2)](#ref-for-dfn-permission-state-21 "Reference 2")
- [§ D. Privacy
 considerations](#ref-for-dfn-permission-state-22 "§ D. Privacy considerations")

[Permalink](#dfn-request-permission-to-use)
[exported]

**Referenced in:**

- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dfn-request-permission-to-use-1 "§ 5.2 Requesting permission to use a powerful feature")
 [(2)](#ref-for-dfn-request-permission-to-use-2 "Reference 2")

[Permalink](#dfn-prompt-the-user-to-choose)
[exported]

**Referenced in:**

- [§ 5.3 Prompt the user to
 choose](#ref-for-dfn-prompt-the-user-to-choose-1 "§ 5.3 Prompt the user to choose")
 [(2)](#ref-for-dfn-prompt-the-user-to-choose-2 "Reference 2")
 [(3)](#ref-for-dfn-prompt-the-user-to-choose-3 "Reference 3")

[Permalink](#dfn-react-to-the-user-revoking-permission)

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-react-to-the-user-revoking-permission-1 "§ 4. Specifying a powerful feature")

[Permalink](#dom-navigator-permissions)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-workernavigator-permissions)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-permissions)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dom-permissions-1 "§ 4. Specifying a powerful feature")
- [§ 6.1 Extensions to the Navigator and WorkerNavigator
 interfaces](#ref-for-dom-permissions-2 "§ 6.1 Extensions to the Navigator and WorkerNavigator interfaces")
 [(2)](#ref-for-dom-permissions-3 "Reference 2")
- [§ F. IDL Index](#ref-for-dom-permissions-4 "§ F. IDL Index")
 [(2)](#ref-for-dom-permissions-5 "Reference 2")

[Permalink](#dom-permissiondescriptor)
[exported]

**Referenced in:**

- [§ 3.2 Permission
 Store](#ref-for-dom-permissiondescriptor-1 "§ 3.2 Permission Store")
 [(2)](#ref-for-dom-permissiondescriptor-2 "Reference 2")
 [(3)](#ref-for-dom-permissiondescriptor-3 "Reference 3")
 [(4)](#ref-for-dom-permissiondescriptor-4 "Reference 4")
 [(5)](#ref-for-dom-permissiondescriptor-5 "Reference 5")
- [§ 3.3.1
 Aspects](#ref-for-dom-permissiondescriptor-6 "§ 3.3.1 Aspects")
 [(2)](#ref-for-dom-permissiondescriptor-7 "Reference 2")
- [§ 4. Specifying a powerful
 feature](#ref-for-dom-permissiondescriptor-8 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dom-permissiondescriptor-9 "Reference 2")
 [(3)](#ref-for-dom-permissiondescriptor-10 "Reference 3")
 [(4)](#ref-for-dom-permissiondescriptor-11 "Reference 4")
- [§ 5.1 Reading the current permission
 state](#ref-for-dom-permissiondescriptor-12 "§ 5.1 Reading the current permission state")
 [(2)](#ref-for-dom-permissiondescriptor-13 "Reference 2")
- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dom-permissiondescriptor-14 "§ 5.2 Requesting permission to use a powerful feature")
- [§ 5.3 Prompt the user to
 choose](#ref-for-dom-permissiondescriptor-15 "§ 5.3 Prompt the user to choose")
- [§ 5.4 Reacting to users revoking
 permission](#ref-for-dom-permissiondescriptor-16 "§ 5.4 Reacting to users revoking permission")
- [§ 6.2.1 query()
 method](#ref-for-dom-permissiondescriptor-17 "§ 6.2.1 query() method")
- [§ 6.3.1 Creating
 instances](#ref-for-dom-permissiondescriptor-18 "§ 6.3.1 Creating instances")
- [§ B. Automated
 testing](#ref-for-dom-permissiondescriptor-19 "§ B. Automated testing")
- [§ B.1.1 Set
 Permission](#ref-for-dom-permissiondescriptor-20 "§ B.1.1 Set Permission")
- [§ B.2.1.2.1 The permissions.PermissionDescriptor
 Type](#ref-for-dom-permissiondescriptor-21 "§ B.2.1.2.1 The permissions.PermissionDescriptor Type")
- [§ B.2.1.3.1 The permissions.setPermission
 Command](#ref-for-dom-permissiondescriptor-22 "§ B.2.1.3.1 The permissions.setPermission Command")

[Permalink](#dom-permissiondescriptor-name)
[exported]

**Referenced in:**

- [§ 3.2 Permission
 Store](#ref-for-dom-permissiondescriptor-name-1 "§ 3.2 Permission Store")
- [§ 5.1 Reading the current permission
 state](#ref-for-dom-permissiondescriptor-name-2 "§ 5.1 Reading the current permission state")
 [(2)](#ref-for-dom-permissiondescriptor-name-3 "Reference 2")
 [(3)](#ref-for-dom-permissiondescriptor-name-4 "Reference 3")
 [(4)](#ref-for-dom-permissiondescriptor-name-5 "Reference 4")
- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dom-permissiondescriptor-name-6 "§ 5.2 Requesting permission to use a powerful feature")
- [§ 5.3 Prompt the user to
 choose](#ref-for-dom-permissiondescriptor-name-7 "§ 5.3 Prompt the user to choose")
- [§ 5.4 Reacting to users revoking
 permission](#ref-for-dom-permissiondescriptor-name-8 "§ 5.4 Reacting to users revoking permission")
- [§ 6.2.1 query()
 method](#ref-for-dom-permissiondescriptor-name-9 "§ 6.2.1 query() method")
 [(2)](#ref-for-dom-permissiondescriptor-name-10 "Reference 2")
 [(3)](#ref-for-dom-permissiondescriptor-name-11 "Reference 3")
- [§ 6.3.1 Creating
 instances](#ref-for-dom-permissiondescriptor-name-12 "§ 6.3.1 Creating instances")
- [§ 6.3.4 onchange
 attribute](#ref-for-dom-permissiondescriptor-name-13 "§ 6.3.4 onchange attribute")
- [§ B.2.1.3.1 The permissions.setPermission
 Command](#ref-for-dom-permissiondescriptor-name-14 "§ B.2.1.3.1 The permissions.setPermission Command")

[Permalink](#dom-permissions-query)
[exported]
[IDL](#webidl-285612776 "Jump to IDL declaration")

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dom-permissions-query-1 "§ 4. Specifying a powerful feature")
- [§ 6.2 Permissions
 interface](#ref-for-dom-permissions-query-2 "§ 6.2 Permissions interface")
- [§ F. IDL Index](#ref-for-dom-permissions-query-3 "§ F. IDL Index")

[Permalink](#dfn-query-a-permission)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-permissionstatus)
[exported]

**Referenced in:**

- [§ 3.3.1 Aspects](#ref-for-dom-permissionstatus-1 "§ 3.3.1 Aspects")
- [§ 4. Specifying a powerful
 feature](#ref-for-dom-permissionstatus-2 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dom-permissionstatus-3 "Reference 2")
 [(3)](#ref-for-dom-permissionstatus-4 "Reference 3")
- [§ 6.2 Permissions
 interface](#ref-for-dom-permissionstatus-5 "§ 6.2 Permissions interface")
- [§ 6.3 PermissionStatus
 interface](#ref-for-dom-permissionstatus-6 "§ 6.3 PermissionStatus interface")
- [§ 6.3.4 onchange
 attribute](#ref-for-dom-permissionstatus-7 "§ 6.3.4 onchange attribute")
- [§ 6.3.5 Garbage
 collection](#ref-for-dom-permissionstatus-8 "§ 6.3.5 Garbage collection")
- [§ F. IDL Index](#ref-for-dom-permissionstatus-9 "§ F. IDL Index")

[Permalink](#dom-permissionstate)
[exported]

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dom-permissionstate-1 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dom-permissionstate-2 "Reference 2")
- [§ 5.1 Reading the current permission
 state](#ref-for-dom-permissionstate-3 "§ 5.1 Reading the current permission state")
 [(2)](#ref-for-dom-permissionstate-4 "Reference 2")
 [(3)](#ref-for-dom-permissionstate-5 "Reference 3")
 [(4)](#ref-for-dom-permissionstate-6 "Reference 4")
- [§ 6.3 PermissionStatus
 interface](#ref-for-dom-permissionstate-7 "§ 6.3 PermissionStatus interface")
- [§ B. Automated
 testing](#ref-for-dom-permissionstate-8 "§ B. Automated testing")
 [(2)](#ref-for-dom-permissionstate-9 "Reference 2")
- [§ B.2.1.2.2 The permissions.PermissionState
 Type](#ref-for-dom-permissionstate-10 "§ B.2.1.2.2 The permissions.PermissionState Type")
- [§ F. IDL Index](#ref-for-dom-permissionstate-11 "§ F. IDL Index")
 [(2)](#ref-for-dom-permissionstate-12 "Reference 2")

[Permalink](#dfn-query)

**Referenced in:**

- [§ 6.2.1 query()
 method](#ref-for-dfn-query-1 "§ 6.2.1 query() method")
- [§ 6.3.1 Creating
 instances](#ref-for-dfn-query-2 "§ 6.3.1 Creating instances")
- [§ 6.3.4 onchange
 attribute](#ref-for-dfn-query-3 "§ 6.3.4 onchange attribute")

[Permalink](#dom-permissionstate-granted)
[exported]
[IDL](#webidl-1212188233 "Jump to IDL declaration")

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dom-permissionstate-granted-1 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dom-permissionstate-granted-2 "Reference 2")
- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dom-permissionstate-granted-3 "§ 5.2 Requesting permission to use a powerful feature")
 [(2)](#ref-for-dom-permissionstate-granted-4 "Reference 2")
- [§ 5.3 Prompt the user to
 choose](#ref-for-dom-permissionstate-granted-5 "§ 5.3 Prompt the user to choose")
- [§ 6.3 PermissionStatus
 interface](#ref-for-dom-permissionstate-granted-6 "§ 6.3 PermissionStatus interface")
- [§ F. IDL
 Index](#ref-for-dom-permissionstate-granted-7 "§ F. IDL Index")

[Permalink](#dom-permissionstate-denied)
[exported]
[IDL](#webidl-1212188233 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.3.1
 Aspects](#ref-for-dom-permissionstate-denied-1 "§ 3.3.1 Aspects")
- [§ 4. Specifying a powerful
 feature](#ref-for-dom-permissionstate-denied-2 "§ 4. Specifying a powerful feature")
 [(2)](#ref-for-dom-permissionstate-denied-3 "Reference 2")
- [§ 5.1 Reading the current permission
 state](#ref-for-dom-permissionstate-denied-4 "§ 5.1 Reading the current permission state")
 [(2)](#ref-for-dom-permissionstate-denied-5 "Reference 2")
- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dom-permissionstate-denied-6 "§ 5.2 Requesting permission to use a powerful feature")
 [(2)](#ref-for-dom-permissionstate-denied-7 "Reference 2")
- [§ 5.3 Prompt the user to
 choose](#ref-for-dom-permissionstate-denied-8 "§ 5.3 Prompt the user to choose")
 [(2)](#ref-for-dom-permissionstate-denied-9 "Reference 2")
 [(3)](#ref-for-dom-permissionstate-denied-10 "Reference 3")
 [(4)](#ref-for-dom-permissionstate-denied-11 "Reference 4")
- [§ 6.3 PermissionStatus
 interface](#ref-for-dom-permissionstate-denied-12 "§ 6.3 PermissionStatus interface")
- [§ B.1.1 Set
 Permission](#ref-for-dom-permissionstate-denied-13 "§ B.1.1 Set Permission")
- [§ F. IDL
 Index](#ref-for-dom-permissionstate-denied-14 "§ F. IDL Index")

[Permalink](#dom-permissionstate-prompt)
[exported]
[IDL](#webidl-1212188233 "Jump to IDL declaration")

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dom-permissionstate-prompt-1 "§ 4. Specifying a powerful feature")
- [§ 5.2 Requesting permission to use a powerful
 feature](#ref-for-dom-permissionstate-prompt-2 "§ 5.2 Requesting permission to use a powerful feature")
- [§ 6.3 PermissionStatus
 interface](#ref-for-dom-permissionstate-prompt-3 "§ 6.3 PermissionStatus interface")
- [§ F. IDL
 Index](#ref-for-dom-permissionstate-prompt-4 "§ F. IDL Index")

[Permalink](#dfn-create-a-permissionstatus)
[exported]

**Referenced in:**

- [§ 6.2.1 query()
 method](#ref-for-dfn-create-a-permissionstatus-1 "§ 6.2.1 query() method")

[Permalink](#dom-permissionstatus-name)
[exported]
[IDL](#webidl-1212188233 "Jump to IDL declaration")

**Referenced in:**

- [§ 6.3 PermissionStatus
 interface](#ref-for-dom-permissionstatus-name-1 "§ 6.3 PermissionStatus interface")
- [§ 6.3.1 Creating
 instances](#ref-for-dom-permissionstatus-name-2 "§ 6.3.1 Creating instances")
- [§ F. IDL
 Index](#ref-for-dom-permissionstatus-name-3 "§ F. IDL Index")

[Permalink](#dom-permissionstatus-state)
[exported]
[IDL](#webidl-1212188233 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.3.1
 Aspects](#ref-for-dom-permissionstatus-state-1 "§ 3.3.1 Aspects")
- [§ 4. Specifying a powerful
 feature](#ref-for-dom-permissionstatus-state-2 "§ 4. Specifying a powerful feature")
- [§ 6.3 PermissionStatus
 interface](#ref-for-dom-permissionstatus-state-3 "§ 6.3 PermissionStatus interface")
- [§ F. IDL
 Index](#ref-for-dom-permissionstatus-state-4 "§ F. IDL Index")

[Permalink](#dom-permissionstatus-onchange)
[exported]
[IDL](#webidl-1212188233 "Jump to IDL declaration")

**Referenced in:**

- [§ 6.3 PermissionStatus
 interface](#ref-for-dom-permissionstatus-onchange-1 "§ 6.3 PermissionStatus interface")
- [§ F. IDL
 Index](#ref-for-dom-permissionstatus-onchange-2 "§ F. IDL Index")

[Permalink](#dfn-permissionstatus-update-steps)

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-permissionstatus-update-steps-1 "§ 4. Specifying a powerful feature")

[Permalink](#dfn-specifications)

**Referenced in:**

- [§ 4. Specifying a powerful
 feature](#ref-for-dfn-specifications-1 "§ 4. Specifying a powerful feature")

[Permalink](#dom-permissionsetparameters)
[exported]

**Referenced in:**

- [§ B.1.1 Set
 Permission](#ref-for-dom-permissionsetparameters-1 "§ B.1.1 Set Permission")
- [§ B.2.1.3.1 The permissions.setPermission
 Command](#ref-for-dom-permissionsetparameters-2 "§ B.2.1.3.1 The permissions.setPermission Command")

[Permalink](#dom-permissionsetparameters-descriptor)
[exported]

**Referenced in:**

- [§ B.1.1 Set
 Permission](#ref-for-dom-permissionsetparameters-descriptor-1 "§ B.1.1 Set Permission")

[Permalink](#dom-permissionsetparameters-state)
[exported]

**Referenced in:**

- [§ B.1.1 Set
 Permission](#ref-for-dom-permissionsetparameters-state-1 "§ B.1.1 Set Permission")
 [(2)](#ref-for-dom-permissionsetparameters-state-2 "Reference 2")

[Permalink](#dfn-set-a-permission)

**Referenced in:**

- [§ B.1.1 Set
 Permission](#ref-for-dfn-set-a-permission-1 "§ B.1.1 Set Permission")
- [§ B.2.1.3.1 The permissions.setPermission
 Command](#ref-for-dfn-set-a-permission-2 "§ B.2.1.3.1 The permissions.setPermission Command")

[Permalink](#dfn-set-permission)
[exported]

**Referenced in:**

- [§ B.1.1 Set
 Permission](#ref-for-dfn-set-permission-1 "§ B.1.1 Set Permission")

[Permalink](#dfn-permissions)

**Referenced in:**

- [§ 3. Model](#ref-for-dfn-permissions-1 "§ 3. Model")

[Permalink](#dfn-set-permission-0)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-change-process)

**Referenced in:**

- [§ C.1 Purpose](#ref-for-dfn-change-process-1 "§ C.1 Purpose")

[Permalink](#dfn-standardized-permission)

**Referenced in:**

- [§ C.4 Registry table of provisional
 permissions](#ref-for-dfn-standardized-permission-1 "§ C.4 Registry table of provisional permissions")

[Permalink](#dfn-table-of-standardized-permissions-of-the-web-platform)

**Referenced in:**

- [§ C.2 Change
 Process](#ref-for-dfn-table-of-standardized-permissions-of-the-web-platform-1 "§ C.2 Change Process")

[Permalink](#dfn-table-of-provisional-permissions)

**Referenced in:**

- [§ C.2 Change
 Process](#ref-for-dfn-table-of-provisional-permissions-1 "§ C.2 Change Process")
