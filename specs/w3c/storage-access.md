
## 1. Introduction

*This section is non-normative.*

User Agents sometimes prevent content inside certain
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)s from accessing data stored in client-side storage
mechanisms like cookies. This can break embedded content which relies on
having access to client-side storage.

The Storage Access API enables content inside
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)s to request and be granted access to their
client-side storage, so that embedded content which relies on having
access to client-side storage can work in such User Agents.
[\[STORAGE-ACCESS-INTRO\]](#biblio-storage-access-intro "Introducing Storage Access API")

## 2. Infrastructure

This specification depends on the Infra standard.
[\[INFRA\]](#biblio-infra "Infra Standard")

## 3. The Storage Access API

This specification defines a method to query whether or not a
[`Document`](https://dom.spec.whatwg.org/#document) currently has access to its [unpartitioned
data](#unpartitioned-data)
([`hasStorageAccess()`](#dom-document-hasstorageaccess)), and a method that can be used to request access to
its [unpartitioned
data](#unpartitioned-data)
([`requestStorageAccess()`](#dom-document-requeststorageaccess)).

Alex visits `https://social.example/`. The page sets a cookie. This
cookie has been set in a [first-party-site
context](#first-party-site-context).

Later on, Alex visits `https://video.example/`, which has an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) on it which loads
`https://social.example/heart-button`. In this case, the
`social.example`
[`Document`](https://dom.spec.whatwg.org/#document) `doc` is in a [third party
context](#third-party-context), and the cookie set previously might or might not be
visible from
`doc``.`[`cookie`](https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie), depending on User Agent storage access policies.

Script in the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) can call
`doc``.`[`hasStorageAccess()`](#dom-document-hasstorageaccess) to determine if it has access to the cookie. If it does
not have access, it can request access by calling
`doc``.`[`requestStorageAccess()`](#dom-document-requeststorageaccess).

[Unpartitioned data] is client-side storage that would be
available to a
[site](https://html.spec.whatwg.org/multipage/browsers.html#site) were it loaded in a [first-party-site
context](#first-party-site-context).

A
[`Document`](https://dom.spec.whatwg.org/#document) is in a [first-party-site
context] if it is the [active
document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) of a [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context). Otherwise, it is in a [first-party-site
context](#first-party-site-context) if it is an [active
document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) and the
[origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin) and [top-level
origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin) of its [relevant settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object) are [same
site](https://html.spec.whatwg.org/multipage/browsers.html#same-site) with one another.

A
[`Document`](https://dom.spec.whatwg.org/#document) is in a [third party context] if it is not in a
[first-party-site
context](#first-party-site-context).

To [determine whether the user agent explicitly allows unpartitioned
cookie
access], given a
[tuple](https://infra.spec.whatwg.org/#tuple) `tuple` consisting of two
[sites](https://html.spec.whatwg.org/multipage/browsers.html#site), run the following steps. This algorithm returns
\"`none`\", \"`allow`\" or \"`disallow`\".

 A user agent's settings might explicitly allow or
disallow unpartitioned cookie access through per-site allow-lists, the
user changing global browser settings, or similar custom overrides.

1. If the user agent does not have explicit settings for unpartitioned
 cookie access for `tuple`, return \"`none`\".

2. If the user agent's settings explicitly allow unpartitioned cookie
 access for `tuple`, return \"`allow`\".

3. [Assert](https://infra.spec.whatwg.org/#assert): the user agent's settings explicitly disallow
 unpartitioned cookie access for `tuple`.

4. Return \"`disallow`\".

To [determine the FedCM site connection
status] given a
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) `embedder` and
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) `identityProvider`, run the following steps.
This algorithm returns a
[boolean](https://infra.spec.whatwg.org/#boolean).

1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `item` of [connected accounts
 set](https://w3c-fedid.github.io/FedCM/#browser-connected-accounts-set):

 1. Let (`rp`, `idp`, `account`) be
 `item`.

 2. If `rp` and `embedder` are [same
 site](https://html.spec.whatwg.org/multipage/browsers.html#same-site), and `idp` and
 `identityProvider` are [same
 site](https://html.spec.whatwg.org/multipage/browsers.html#same-site), return true.

2. Return false.

To [determine the effective FedCM connection
status] given a
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) `embedder`, a
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) `identityProvider`, a
[`Document`](https://dom.spec.whatwg.org/#document) `doc`, run the following steps. This
algorithm returns a
[boolean](https://infra.spec.whatwg.org/#boolean).

1. Let `policyStatus` be whether `doc` is
 [allowed to
 use](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use) \"`identity-credentials-get`\".

2. If `policyStatus` is \"Disabled\", return false.

3. Let `connected` be the result of [determining the site
 connection
 status](#determine-the-fedcm-site-connection-status) given `embedder` and
 `identityProvider`.

4. If `connected` is false, return false.

5. Let `preventSilentAccess` be [user
 agent](https://infra.spec.whatwg.org/#user-agent)'s [credential
 store](https://w3c.github.io/webappsec-credential-management/#concept-credential-store)'s [prevent silent access
 flag](https://w3c.github.io/webappsec-credential-management/#origin-prevent-silent-access-flag) for `embedder`.

6. If `preventSilentAccess`, return false.

7. Return true.

### 3.1. Changes to user agent state related to storage access

Modify the definition of
[environment](https://html.spec.whatwg.org/multipage/#environment) in the following manner:

1. Add a new member called [has storage
 access] of type
 [boolean](https://infra.spec.whatwg.org/#boolean).

Modify the definition of [source snapshot
params](https://html.spec.whatwg.org/multipage/browsing-the-web.html#source-snapshot-params) in the following manner:

1. Add a new member called [has storage
 access] of type
 [boolean](https://infra.spec.whatwg.org/#boolean).

2. Add a new member called [environment
 id] of type
 opaque
 [string](https://infra.spec.whatwg.org/#string).

A [storage access eligibility] is one of
\"[unset]\",
\"[ineligible]\", or
\"[eligible]\".

A
[request](https://fetch.spec.whatwg.org/#concept-request) has a [storage access
eligibility](#storage-access-eligibility) [eligible for
storage-access]. It is initially
\"[`unset`](#storage-access-eligibility-unset)\".

 a
[request](https://fetch.spec.whatwg.org/#concept-request)'s [storage access
eligibility](#storage-access-eligibility) indicates whether previously-granted
\"[`storage-access`](#permissiondef-storage-access)\" permissions ought to be considered
when evaluating which cookies to include on the
[request](https://fetch.spec.whatwg.org/#concept-request). In particular, note that after
[`requestStorageAccess`](#dom-document-requeststorageaccess) has resolved and the
[environment](https://html.spec.whatwg.org/multipage/#environment)'s [has storage
access](#environment-has-storage-access) is set to true, not all of the
[request](https://fetch.spec.whatwg.org/#concept-request)s issued by that
[environment](https://html.spec.whatwg.org/multipage/#environment) ought to carry unpartitioned cookies.\
\
For example, suppose the user is visiting a page on https://top.com
which embeds an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) served from https://embed.com, and a script in that
iframe has called
[`requestStorageAccess`](#dom-document-requeststorageaccess) and the promise resolved. If the iframe subsequently
fetches a resource from https://3p.com, that request will not include
cookies via the Storage Access API.

To [determine the initial storage-access
eligibility], given a
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, run the following steps:

1. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is null, return
 \"[`unset`](#storage-access-eligibility-unset)\".

2. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client)'s
 [ancestry](https://html.spec.whatwg.org/multipage/#TODO) is not \"`cross-site`\", return
 \"[`unset`](#storage-access-eligibility-unset)\"

The concept of \"ancestry\" is being
added to HTML in <https://github.com/whatwg/html/pull/11133>

1. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client)'s [has storage
 access](#environment-has-storage-access) is false, return
 \"[`ineligible`](#storage-access-eligibility-ineligible)\".

2. If `request`'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin) is not [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with `request`'s
 [url](https://fetch.spec.whatwg.org/#concept-request-url)'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin), return
 \"[`ineligible`](#storage-access-eligibility-ineligible)\".

3. Let `allowed` be the result of running [Should request be
 allowed to use
 feature?](https://w3c.github.io/webappsec-permissions-policy/#should-request-be-allowed-to-use-feature) given
 \"[`storage-access`](#permissiondef-storage-access)\" and `request`.

4. If `allowed` is false, return
 \"[`ineligible`](#storage-access-eligibility-ineligible)\".

5. Return
 \"[`eligible`](#storage-access-eligibility-eligible)\".

### [3.2. ][Changes to [`Document`](https://dom.spec.whatwg.org/#document)]
```
partial interface Document {
 Promise<boolean> hasStorageAccess();
 Promise<undefined> requestStorageAccess();
};
```

When invoked on
[`Document`](https://dom.spec.whatwg.org/#document) `doc`, the
[`hasStorageAccess()`] method must
run these steps:

1. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

2. If `doc` is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), then
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and return `p`.

3. If `doc`'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) is an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque),
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with false and return
 `p`.

4. Let `global` be `doc`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

5. If `global` is not a [secure
 context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), then
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with false and return
 `p`.

6. If the [top-level
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin) of `doc`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object) is an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque),
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with false and return
 `p`.

7. Let `browsingContext` be `doc`'s [browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#concept-document-bc).

8. Let `topLevelSite` be the result of [obtaining a
 site](https://html.spec.whatwg.org/multipage/browsers.html#obtain-a-site) from the [top-level
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin) of `doc`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

9. Let `embeddedSite` be the result of [obtaining a
 site](https://html.spec.whatwg.org/multipage/browsers.html#obtain-a-site) from `doc`'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin).

10. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `explicitSetting` be the result of [determining
 whether the user agent explicitly allows unpartitioned cookie
 access](#determine-whether-the-user-agent-explicitly-allows-unpartitioned-cookie-access) with (`topLevelSite`,
 `embeddedSite`).

 2. Let `permissionState` be the result of [getting the
 current permission
 state](https://w3c.github.io/permissions/#dfn-getting-the-current-permission-state) given
 \"[`storage-access`](#permissiondef-storage-access)\" and `global`.

 3. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [networking task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#networking-task-source) given `global` to:

 1. If `explicitSetting` is \"`disallow`\",
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with false and abort these
 steps.

 2. If `explicitSetting` is \"`allow`\",
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with true and abort these
 steps.

 3. [Assert](https://infra.spec.whatwg.org/#assert): `explicitSetting` is
 \"`none`\".

 4. If `browsingContext` is a [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context),
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with true and abort these
 steps.

 5. If `browsingContext` is same authority with
 `browsingContext`'s [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context)'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document),
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with true and abort these
 steps.

 (#issue-396d9a1a) \"same authority\" here is a
 placeholder for a future concept that allows user agents to
 perform [same
 site](https://html.spec.whatwg.org/multipage/browsers.html#same-site) checks while adhering to additional
 security aspects such as the presence of a cross-site parent
 document, see
 [whatwg/storage#142](https://github.com/whatwg/storage/issues/142#issuecomment-1122147159).
 In practice, this might involve comparing the [site for
 cookies](https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-11#section-5.2.1) or performing a [same
 site](https://html.spec.whatwg.org/multipage/browsers.html#same-site) check with the top-level document.

 6. If `embeddedSite` is [same
 site](https://html.spec.whatwg.org/multipage/browsers.html#concept-site-same-site) with `topLevelSite`,
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with `global`'s
 [has storage
 access](#environment-has-storage-access) and abort these steps.

 7. If `permissionState` is
 [granted](https://w3c.github.io/permissions/#dfn-granted),
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with `global`'s
 [has storage
 access](#environment-has-storage-access) and abort these steps.

 The global storage access permission state
 takes precedence over the local [has storage
 access](#environment-has-storage-access) flag here, in order to immediately reflect
 a possible user choice to revoke the permission in their
 settings.

 8. [Resolve](https://webidl.spec.whatwg.org/#resolve) `p` with false.

11. Return `p`.

When invoked on
[`Document`](https://dom.spec.whatwg.org/#document) `doc`, the
[`requestStorageAccess()`]
method must run these steps:

1. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

2. If `doc` is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), then
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and return `p`.

3. Let `global` be `doc`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

4. Let `settings` be `doc`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

5. If `global` is not a [secure
 context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context), then
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with a
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and return `p`.

6. If `doc` is not [allowed to
 use](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use) \"`storage-access`\",
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with a
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and return `p`.

7. If `doc`'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) is an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque),
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with a
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and return `p`.

8. If `settings`'s [top-level
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin) is an [opaque
 origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque),
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with a
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and return `p`.

9. If `doc`'s [active sandboxing flag
 set](https://html.spec.whatwg.org/multipage/browsers.html#active-sandboxing-flag-set) has its [sandbox storage access by user activation
 flag](#sandbox-storage-access-by-user-activation-flag) set,
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with a
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and return `p`.

10. Let `browsingContext` be `doc`'s [browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#concept-document-bc).

11. Let `topLevelOrigin` be the [top-level
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin) of `doc`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

12. Let `topLevelSite` be the result of [obtaining a
 site](https://html.spec.whatwg.org/multipage/browsers.html#obtain-a-site) from `topLevelOrigin`.

13. Let `embeddedOrigin` be `doc`'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin).

14. Let `embeddedSite` be the result of [obtaining a
 site](https://html.spec.whatwg.org/multipage/browsers.html#obtain-a-site) from `embeddedOrigin`.

15. Let `has transient activation` be whether
 `doc`'s
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object has [transient
 activation](https://html.spec.whatwg.org/multipage/interaction.html#transient-activation).

16. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Let `process permission state` be an algorithm that,
 given a [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state) `state`, runs the following steps:

 1. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [networking task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#networking-task-source) given `global` to:

 1. If `state` is
 [granted](https://w3c.github.io/permissions/#dfn-granted):

 1. Set `global`'s [has storage
 access](#environment-has-storage-access) to true.

 2. [Resolve](https://webidl.spec.whatwg.org/#resolve) `p` with
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined).

 2. Else:

 1. [Consume user
 activation](https://html.spec.whatwg.org/multipage/interaction.html#consume-user-activation) given `global`.

 2. [Reject](https://webidl.spec.whatwg.org/#reject) `p` with a
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `explicitSetting` be the result of [determining
 whether the user agent explicitly allows unpartitioned cookie
 access](#determine-whether-the-user-agent-explicitly-allows-unpartitioned-cookie-access) with (`topLevelSite`,
 `embeddedSite`).

 3. If `explicitSetting` is \"`disallow`\":

 1. Run `process permission state` with
 [denied](https://w3c.github.io/permissions/#dfn-denied).

 2. Abort these steps.

 4. If `explicitSetting` is \"`allow`\":

 1. Run `process permission state` with
 [granted](https://w3c.github.io/permissions/#dfn-granted).

 2. Abort these steps.

 5. [Assert](https://infra.spec.whatwg.org/#assert): `explicitSetting` is \"`none`\".

 6. If `browsingContext` is a [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context):

 1. Run `process permission state` with
 [granted](https://w3c.github.io/permissions/#dfn-granted).

 2. Abort these steps.

 7. If `embeddedSite` is [same
 site](https://html.spec.whatwg.org/multipage/browsers.html#concept-site-same-site) with `topLevelSite`:

 [NOTE:] This check is [same
 site](https://html.spec.whatwg.org/multipage/browsers.html#concept-site-same-site) on purpose, to allow embedded sites to use
 `requestStorageAccess()` to opt into storage access without
 involvement from the end user in scenarios where storage access
 is restricted for security and not privacy purposes.

 1. Run `process permission state` with
 [granted](https://w3c.github.io/permissions/#dfn-granted).

 2. Abort these steps.

 8. Let `previous permission state` be the result of
 [getting the current permission
 state](https://w3c.github.io/permissions/#dfn-getting-the-current-permission-state) given
 \"[`storage-access`](#permissiondef-storage-access)\" and `global`.

 9. If `previous permission state` is not
 [prompt](https://w3c.github.io/permissions/#dfn-prompt):

 1. Run `process permission state` with
 `previous permission state`.

 2. Abort these steps.

 10. Let `connected` be the result of [determining the
 effective FedCM connection
 status](#determine-the-effective-fedcm-connection-status) given `topLevelOrigin`,
 `embeddedOrigin`, `doc`.

 11. If `connected`:

 [NOTE:] User agents are encouraged to keep track of
 which (site, site) tuples have been allowed to access storage
 due to existing FedCM connections, and double-check that list
 when accessing cookies to catch malicious attackers that have
 tricked an
 [environment](https://html.spec.whatwg.org/multipage/#environment) into using an incorrect [has storage
 access](#environment-has-storage-access) bit.

 1. Run `process permission state` with
 [granted](https://w3c.github.io/permissions/#dfn-granted).

 2. Abort these steps.

 12. If `has transient activation` is false:

 1. Run `process permission state` with
 [denied](https://w3c.github.io/permissions/#dfn-denied).

 2. Abort these steps.

 13. Let `permissionState` be the result of [requesting
 permission to
 use](https://w3c.github.io/permissions/#dfn-request-permission-to-use)
 \"[`storage-access`](#permissiondef-storage-access)\".

 [NOTE:] Note that when requesting permissions and
 deciding whether to show a prompt, user agents apply
 implementation-defined behavior to shape the end user
 experience. Particularly for `storage-access`, user agents are
 known to apply custom rules that will grant or deny a permission
 without showing a prompt.

 14. Run `process permission state` with
 `permissionState`.

17. Return `p`.

[NOTE:] The intent of this algorithm is to always require user
activation before a storage-access permission will be set. Though it is
within the means of user agents to set storage-access permissions based
on custom heuristics without prior user activation, this specification
strongly discourages such behavior, as it could lead to interoperability
issues.

### 3.3. Changes to navigation

When [snapshotting source snapshot
params](https://html.spec.whatwg.org/multipage/browsing-the-web.html#snapshotting-source-snapshot-params):

1. Set [has storage
 access](#source-snapshot-params-has-storage-access) to `sourceDocument`'s [has storage
 access](#source-snapshot-params-has-storage-access).

2. Set [environment
 id](#source-snapshot-params-environment-id) to `sourceDocument`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s
 [id](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-id).

To the [create navigation params by
fetching](https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-by-fetching) algorithm, insert the following step as step 3:

1. Let `originalURL` be `entry`'s URL.

When creating `request`'s [reserved
client](https://fetch.spec.whatwg.org/#concept-request-reserved-client) in [create navigation params by
fetching](https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-by-fetching):

1. Set [reserved
 client](https://fetch.spec.whatwg.org/#concept-request-reserved-client)'s [has storage
 access](#environment-has-storage-access) to `sourceSnapshotParams`'s [has storage
 access](#source-snapshot-params-has-storage-access) if all of the following hold:

 1. `sourceSnapshotParams`'s [environment
 id](#source-snapshot-params-environment-id) equals `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document)'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s
 [id](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-id).

 2. `originalURL`'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin) is [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with `currentURL`'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin).

 3. `response` is null or `response`'s
 [has-cross-origin-redirects](https://fetch.spec.whatwg.org/#response-has-cross-origin-redirects) is false.

2. Otherwise, set `request`'s [reserved
 client](https://fetch.spec.whatwg.org/#concept-request-reserved-client)'s [has storage
 access](#environment-has-storage-access) to false.

When [setting up a window environment settings
object](https://html.spec.whatwg.org/multipage/nav-history-apis.html#set-up-a-window-environment-settings-object):

1. Set `settings object`'s [has storage
 access](#environment-has-storage-access) to `reserved environment`'s [has storage
 access](#environment-has-storage-access).

### 3.4. Integration with Fetch

#### 3.4.1. Fetching

Insert a new step after step 14 of
[fetch](https://fetch.spec.whatwg.org/#concept-fetch):

15. Set `request`'s [eligible for
 storage-access](#request-eligible-for-storage-access) to the result of [determining the initial
 storage-access
 eligibility](#determine-the-initial-storage-access-eligibility) given `request`.

#### 3.4.2. HTTP-redirect-fetch

Insert a new step after step 17 of [HTTP-redirect
fetch](https://fetch.spec.whatwg.org/#concept-http-redirect-fetch):

18. If `request`'s [eligible for
 storage-access](#request-eligible-for-storage-access) is not
 \"[`unset`](#storage-access-eligibility-unset)\" and `locationURL`'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin) is not [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with `request`'s [current
 URL](https://fetch.spec.whatwg.org/#concept-request-current-url)'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin), set `request`'s [eligible for
 storage-access](#request-eligible-for-storage-access) to
 \"[`ineligible`](#storage-access-eligibility-ineligible)\".

### 3.5. Changes to various client-side storage mechanisms

This API only impacts HTTP cookies. A future revision of this API might
impact other client-side state.
[\[RFC6265\]](#biblio-rfc6265 "HTTP State Management Mechanism")

#### 3.5.1. Cookies

This API is intended to be used with environments and user agent
configurations that block access to unpartitioned cookies in a [third
party context](#third-party-context). At the time of this writing, this concept has not yet
been integrated into the [HTTP-network-or-cache
fetch](https://fetch.spec.whatwg.org/#concept-http-network-or-cache-fetch) and
[`cookie`](https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie) algorithms. To allow for such an integration, the
[cookie
store](https://tools.ietf.org/html/rfc6265#section-5.3) will need to be modified to receive information about
the top-level and embedded site of the request (to determine whether to
attach cross-site, partitioned, or no cookies) as well as whether the
[request](https://fetch.spec.whatwg.org/#concept-request) was made for a document that has storage access,
through accessing the
[request](https://fetch.spec.whatwg.org/#concept-request)'s [eligible for
storage-access](#request-eligible-for-storage-access) that is defined in this specification.

Once the cookie store allows for receiving information about storage
access, we would update [HTTP-network-or-cache
fetch](https://fetch.spec.whatwg.org/#concept-http-network-or-cache-fetch) and
[`cookie`](https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie) to pass the
[request](https://fetch.spec.whatwg.org/#concept-request)'s [eligible for
storage-access](#request-eligible-for-storage-access) to the [cookie
store](https://tools.ietf.org/html/rfc6265#section-5.3) when retrieving cookies.

When getting unpartitioned cookies from the [cookie
store](https://tools.ietf.org/html/rfc6265#section-5.3) with storage access, user agents will still follow
applicable `SameSite` restrictions (i.e., not attach cookies marked
`SameSite=Strict` or `SameSite=Lax` in [third party
contexts](#third-party-context)).

 User agents could apply different default values for
the `SameSite` cookie attribute. This could lead to unpartitioned
cookies without a `SameSite` attribute being attached to requests in
some user agents (where `SameSite=None` is the default), but not in
others (where `SameSite=Lax` is the default). Web developers are
encouraged to set the `SameSite` attribute on their cookies to not run
into issues.

### 3.6. Sandboxing storage access

A [sandboxing flag
set](https://html.spec.whatwg.org/multipage/browsers.html#sandboxing-flag-set) has a [sandbox storage access by user activation
flag]. This flag prevents content from requesting
storage access.

To the [parse a sandboxing
directive](https://html.spec.whatwg.org/multipage/browsers.html#parse-a-sandboxing-directive) algorithm, add the following under step 3:

- The [sandbox storage access by user activation
 flag](#sandbox-storage-access-by-user-activation-flag), unless `tokens` contains the
 [`allow-storage-access-by-user-activation`] keyword.

## 4. Permissions Integration

The Storage Access API defines a [powerful
feature](https://w3c.github.io/permissions/#dfn-powerful-feature) identified by the
[name](https://w3c.github.io/permissions/#dfn-name) \"[`storage-access`]\". It defines
the following permission-related algorithms:

[permission query algorithm](https://w3c.github.io/permissions/#dfn-permission-query-algorithm)
: To query the
 \"[`storage-access`](#permissiondef-storage-access)\" permission, given a
 [`PermissionDescriptor`](https://w3c.github.io/permissions/#dom-permissiondescriptor) `permissionDesc` and a
 [`PermissionStatus`](https://w3c.github.io/permissions/#dom-permissionstatus) `status`:
 1. Set `status`'s
 [`state`](https://w3c.github.io/permissions/#dom-permissionstatus-state) to `permissionDesc`'s [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state).

 2. If `status`'s
 [`state`](https://w3c.github.io/permissions/#dom-permissionstatus-state) is
 [denied](https://w3c.github.io/permissions/#dfn-denied), set `status`'s
 [`state`](https://w3c.github.io/permissions/#dom-permissionstatus-state) to
 [prompt](https://w3c.github.io/permissions/#dfn-prompt).

 The \"denied\" permission state is not revealed
 to avoid exposing the user's decision to developers. This is
 done to prevent retaliation against the user and repeated
 prompting to the detriment of the user experience.

[permission key type](https://w3c.github.io/permissions/#dfn-permission-key-type)
: A [permission
 key](https://w3c.github.io/permissions/#dfn-permission-key) of the
 \"[`storage-access`](#permissiondef-storage-access)\" feature is a
 [tuple](https://infra.spec.whatwg.org/#tuple) consisting of a
 [site](https://html.spec.whatwg.org/multipage/browsers.html#site) [top-level]
 and a
 [site](https://html.spec.whatwg.org/multipage/browsers.html#site) [requester].
 :::
 (#example-82f4f666)
 `(("https", "news.example"), ("https", "social.example"))` is a
 [permission
 key](https://w3c.github.io/permissions/#dfn-permission-key) for
 \"[`storage-access`](#permissiondef-storage-access)\" whose
 [top-level](#permission-key-top-level) is `("https", "news.example")` and whose
 [requester](#permission-key-requester) is `("https", "social.example")`.
 :::

[permission key generation algorithm](https://w3c.github.io/permissions/#dfn-permission-key-generation-algorithm)
: To generate a new [permission
 key](https://w3c.github.io/permissions/#dfn-permission-key) for the
 \"[`storage-access`](#permissiondef-storage-access)\" feature, given an
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) `origin` and
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) `embeddedOrigin`:
 1. Let `topLevelSite` be the result of [obtaining a
 site](https://html.spec.whatwg.org/multipage/browsers.html#obtain-a-site) from `origin`.

 2. Let `embeddedSite` be the result of [obtaining a
 site](https://html.spec.whatwg.org/multipage/browsers.html#obtain-a-site) from `embeddedOrigin`.

 3. Return (`topLevelSite`, `embeddedSite`).

[permission key comparison algorithm](https://w3c.github.io/permissions/#dfn-permission-key-comparison-algorithm)
: To compare the [permission
 keys](https://w3c.github.io/permissions/#dfn-permission-key) `key1` and `key2` for the
 \"[`storage-access`](#permissiondef-storage-access)\" feature, run the following
 steps:
 1. If `key1`'s
 [top-level](#permission-key-top-level) is not [same
 site](https://html.spec.whatwg.org/multipage/browsers.html#concept-site-same-site) with `key2`'s
 [top-level](#permission-key-top-level), return false.

 2. If `key1`'s
 [requester](#permission-key-requester) is not [same
 site](https://html.spec.whatwg.org/multipage/browsers.html#concept-site-same-site) with `key2`'s
 [requester](#permission-key-requester), return false.

 3. Return true.

## 5. Permissions Policy Integration

The Storage Access API defines a [policy-controlled
feature](https://w3c.github.io/webappsec-permissions-policy/#policy-controlled-feature) identified by the string `"storage-access"`. Its
[default
allowlist](https://w3c.github.io/webappsec-permissions-policy/#policy-controlled-feature-default-allowlist) is `"*"`.

 A
[`Document`](https://dom.spec.whatwg.org/#document)'s [permissions
policy](https://html.spec.whatwg.org/multipage/dom.html#concept-document-permissions-policy) determines whether any content in that document is
allowed to request storage access using
[`requestStorageAccess()`](#dom-document-requeststorageaccess). If disabled in any document, calling
[`requestStorageAccess()`](#dom-document-requeststorageaccess) in that document will reject.

## 6. Privacy considerations

The Storage Access API enables the removal of cross-site cookies.
Specifically, it allows the authenticated embeds use case to continue to
work. As such, the API provides a way for developers to re-gain access
to cross-site cookies, albeit under further constraints.

A nested
[`Document`](https://dom.spec.whatwg.org/#document) gains access to the same cookies it has as the [active
document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) of a [top-level browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) when it calls
[`requestStorageAccess()`](#dom-document-requeststorageaccess) and is returned a resolving
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise). With these cookies it can authenticate itself to the
server and load user-specific information.

While this functionality comes with a risk of abuse by third parties for
tracking purposes, it is an explicit goal of the API and a key to its
design to not undermine the gains of cross-site cookie deprecation.
Importantly, we do not degrade privacy properties when compared to
pre-removal of cross-site cookies. This follows from a lack of
platform-specific information used in the spec to prevent stateless
tracking and the only state added being a permission scoped to the
[sites](https://html.spec.whatwg.org/multipage/browsers.html#site) of the embedding and embedded
[`Document`](https://dom.spec.whatwg.org/#document).

Our privacy considerations are more challenging where default cross-site
cookies are already deprecated. The challenge is to decide when and how
to permit the Storage Access API to be used to revert a cookie-less (or
cookie-partitioned) nested
[`Document`](https://dom.spec.whatwg.org/#document) to a pre-deprecation state, giving it access to its
[unpartitioned data](#unpartitioned-data).

In an ideal case, a nested
[`Document`](https://dom.spec.whatwg.org/#document) would only be able to gain access to its [unpartitioned
data](#unpartitioned-data)
if:

1. the user interacts with the nested
 [`Document`](https://dom.spec.whatwg.org/#document)

2. the nested
 [`Document`](https://dom.spec.whatwg.org/#document) is permitted by the embedder to use the API

3. the nested
 [`Document`](https://dom.spec.whatwg.org/#document) is a [secure
 context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context)

4. the user grants express, pairwise permission to the embeddee to use
 its cookies in the embedder

5. the user is not inundated by requests for the \"`storage-access`\"
 permission so their express permission is not undermined by fatigue

This specification requires the first three of implementers. This
provides guarantees that the user is aware of the content of the nested
[`Document`](https://dom.spec.whatwg.org/#document), the embedder has not opted out of the nested
[`Document`](https://dom.spec.whatwg.org/#document)'s authentication, and the cross-site cookies are not
disclosed to network attackers, respectively.

The last two points are in tension. In an ideal world, we would show a
prompt to the user in every call to
[`requestStorageAccess()`](#dom-document-requeststorageaccess). But, this would allow pages to prompt the user so
frequently as to put the last point at the discretion of the page-- a
state we find unacceptable. User agents should prevent over-prompting of
the user.

![An example prompt which could be shown to the user when a site calls
`document.`[`requestStorageAccess()`](#dom-document-requeststorageaccess).](images/storage-access-prompt.png)

Thus, the last two points represent a key point of compromise. We permit
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) behavior on when to grant or deny requests for
[unpartitioned data](#unpartitioned-data) without requiring user choice so long as they meet all
other requirements. This compromise weakens the privacy guarantees of
this proposal, specifically point 4, to a degree under the control of
the implementer and gives the implementer the power to render it
impossible to get storage access with this API. However, this has proven
necessary to enable condition 5 to be possible given our implementers\'
differing stances on the compromise between these two points.

Developer experience suffers where user agents differ greatly in their
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) behavior, and therefore user agents should aim to
minimize or standardize silent grants and denies.

### 6.1. Permission scope

Another tension in the design of the API is what to use to key the
\"`storage-access`\" permission:
[origins](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) or
[sites](https://html.spec.whatwg.org/multipage/browsers.html#site). We chose
[sites](https://html.spec.whatwg.org/multipage/browsers.html#site) because we believe them to be acceptable boundaries for
privacy while enabling existing uses of [same
site](https://html.spec.whatwg.org/multipage/browsers.html#concept-site-same-site) and cross-origin nested
[`Documents`](https://dom.spec.whatwg.org/#document) on the same page with only one user prompt.

## 7. Security considerations

It is important that this spec not degrade security properties of the
web platform, even when compared to post-removal of cross-site cookies.
Third-party cookie removal has potential benefits for security,
specifically in mitigating attacks that rely upon authenticated
requests, e.g. CSRF. We do not wish the Storage Access API to be a
foothold for such attacks to leverage.

To this end, we limit the impact of a \"`storage-access`\" permission
grant to only give access to [unpartitioned
data](#unpartitioned-data)
to the nested
[`Document`](https://dom.spec.whatwg.org/#document) that called
[`requestStorageAccess()`](#dom-document-requeststorageaccess) and only until the nested
[`Document`](https://dom.spec.whatwg.org/#document) navigates across an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) boundary. This ensures that only
[origins](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) with a page that call
[`requestStorageAccess()`](#dom-document-requeststorageaccess) will be making credentialed requests, and moreover the
embedee page can control which embedder it permits via the Content
Security Policy \"`frame-ancestors`\" directive. This retains an
[origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)-scoped control for security purposes by the embedee.

### 7.1. Reputational attacks

This also is effective at preventing another attack: one on the
embedee's reputation. We consider any cross-site authenticated request
to have potential reputational harm as consumers become more privacy
conscious. Therefore a first-party or sibling cross-site causing an
embedded resource to be requested with the user's authentication cookies
would constitute an attack on the reputation of that cross-site's owner.
This is also a reason we require this API to be used in a [secure
context](https://html.spec.whatwg.org/multipage/webappapis.html#secure-context): so a network adversary cannot induce an embedee to use
this API.

The embedder has control over which nested
[`Documents`](https://dom.spec.whatwg.org/#document) have the ability to become authenticated, or even
display a permission request to the user via the Permission Policy and
nested
[`Document`](https://dom.spec.whatwg.org/#document) sandboxing.

### 7.2. Notification abuse

Notification abuse was also considered while specifying the Storage
Access API. Specifically, we require user interaction in the nested
[`Document`](https://dom.spec.whatwg.org/#document) and consume that rejection on a denial to restrict the
conditions a permission prompt will be shown to the user. This mitigates
attacks such as re-requesting a permission immediately after the user
denies it.

## 8. Automation

For the purposes of user-agent automation and application testing, this
document defines the following [extension
command](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-extension-commands) for the
[\[WebDriver\]](#biblio-webdriver "WebDriver")
specification.

### 8.1. Set Storage Access

HTTP Method

URI Template

POST

/session/{session id}/storageaccess

The [Set Storage Access] [extension
command](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-extension-commands) modifies the storage access policy for the [current
browsing
context](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-current-browsing-context).

The [remote end
steps](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-remote-end-steps) are:

1. Let `blocked` be the result of [getting a
 property](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-getting-properties) from `parameters` named `blocked`.

2. If `blocked` is not a
 [boolean](https://infra.spec.whatwg.org/#boolean) return a [WebDriver
 error](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-invalid-argument).

3. Let `embedded origin` be the result of [getting a
 property](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-getting-properties) from `parameters` named `origin`.

4. If `embedded origin` is not a single U+002A ASTERISK
 character (\*), then:

 1. Let `parsedURL` be the the result of running the [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) on `embedded origin`.

 2. If `parsedURL` is failure, then return a [WebDriver
 error](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-invalid-argument).

 3. Set `embedded origin` to `parsedURL`'s
 [origin](https://url.spec.whatwg.org/#concept-url-origin).

5. If the [current browsing
 context](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-current-browsing-context) is not a [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context) return a [WebDriver
 error](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-unsupported-operation).

6. Let `doc` be the [current browsing
 context](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-current-browsing-context)'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

7. Let `settings` be `doc`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

8. Let `top-level site` be the result of [obtaining a
 site](https://html.spec.whatwg.org/multipage/browsers.html#obtain-a-site) from `settings`'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin).

9. If `embedded origin` is a single U+002A ASTERISK
 character (\*), then:

 1. If `blocked` is `true`, then:

 1. Run an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) set of steps to ensure that no site has
 access to its [unpartitioned
 data](#unpartitioned-data) when loaded in a [third party
 context](#third-party-context) on `top-level site`.

 2. Otherwise, if `blocked` is `false`, then:

 1. Run an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) set of steps to ensure that any site has
 access to its [unpartitioned
 data](#unpartitioned-data) when loaded in a [third party
 context](#third-party-context) on `top-level site`.

10. Otherwise:

 1. If `embedded origin` is [same
 site](https://html.spec.whatwg.org/multipage/browsers.html#same-site) with `settings`'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin) return a [WebDriver
 error](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-unsupported-operation).

 2. If `blocked` is `true`, then:

 1. Run an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) set of steps to ensure that
 `embedded origin` does not have access to its
 [unpartitioned
 data](#unpartitioned-data) when loaded in a [third party
 context](#third-party-context) on `top-level site`.

 3. Otherwise, if `blocked` is `false`, then:

 1. Run an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) set of steps to ensure that
 `embedded origin` has access to its
 [unpartitioned
 data](#unpartitioned-data) when loaded in a [third party
 context](#third-party-context) on `top-level site`.

11. If the above
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) step of steps resulted in failure, return a
 [WebDriver
 error](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-error-code) [unknown
 error](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-unknown-error).

12. Return
 [success](https://w3c.github.io/webdriver/webdriver-spec.html#dfn-success) with data `null`.

## [Acknowledgements]
This specification builds on the foundations created by former editors
John Wilander, who invented the Storage Access API, and Theresa
O'Connor, who wrote significant portions of the initial text. We are
grateful for their ideas and contributions.

Many thanks to Anne van Kesteren, Ben Kelly, Brad Girardeau, Brad Hill,
Brady Eidson, Brandon Maslen, Chris Mills, Dave Longley, Domenic
Denicola, Ehsan Akhgari, Geoffrey Garen, Jack Frankland, James Coleman,
James Hartig, Jeffrey Yasskin, Kushal Dave, Luís Rudge, Maciej
Stachowiak, Matias Woloski, Mike O'Neill, Mike West, Pete Snyder, Rob
Stone, Stefan Leyhane, Steven Englehardt, Travis Leithead, Yan Zhu, Zach
Edwards, and everyone who commented on
[whatwg/html#3338](https://github.com/whatwg/html/issues/3338),
[privacycg/proposals#2](https://github.com/privacycg/proposals/issues/2),
and
[privacycg/storage-access/issues](https://github.com/privacycg/storage-access/issues)
for their feedback on this proposal.

Thanks to the [WebKit Open Source Project](https://webkit.org/) for
allowing us to use the [Storage Access API Prompt](#example-prompt)
image, which was [originally published on
webkit.org](https://webkit.org/blog/8311/intelligent-tracking-prevention-2-0/).
