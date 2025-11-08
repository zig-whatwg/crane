# Introduction

Testing browsers often requires use of specialised API surface that is not suitable for exposing to web authors, for example because it could undermine platform invariants, or allow behavior that could put users at risk. This can make writing cross-browser tests difficult because each implementation of the web platform will have its own approach to defining such test APIs. The WebDriver standard provides some of these APIs, with a focus on automated testing of web applications. However for testing of browser implementations themselves, there are some additional APIs that don't fit into the WebDriver framework, but are nevertheless important to testing.

This specification defines additional in-browser APIs for use in tests, but which are not suitable to enable for end users. The primary client of these APIs is the web-platform-tests testsuite.


## Infrastructure

This specification depends on the Infra Standard. [INFRA]

This specification uses terminology from the Web IDL standard. [WEBIDL]


## Availability

The interfaces defined in this specification must not be enabled in the default shipping configuration of user agents. They must only be enabled in testing configurations for example with special build flags, or when a specific non-default preference is set.


## The TestUtils Namespace

```idl
[Exposed=(Window,Worker)]
namespace TestUtils {
  [NewObject] Promise<undefined> gc();
};
```

The `gc()` method must run these steps:

1. Let `p` be a new promise.

2. Run the following [in parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

   2.1 Run [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) steps to perform a garbage collection covering at least the [entry Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-entry-realm).

   2.2 Resolve `p`.