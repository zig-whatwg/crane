## 1. Introduction

This document builds off of the WebAssembly specification
[\[WEBASSEMBLY\]](#biblio-webassembly "WebAssembly Core Specification")
and the WebAssembly JavaScript embedding
[\[WASMJS\]](#biblio-wasmjs "WebAssembly JS Integration Specification").
It describes the integration of WebAssembly into the broader Web
platform, for example with additional APIs that are implemented by Web
user agents but are outside the scope of JavaScript
[\[ECMASCRIPT\]](#biblio-ecmascript "ECMAScript Language Specification")
itself.

## 2. Streaming Module Compilation and Instantiation

```
[Exposed=(Window,Worker)]
partial namespace WebAssembly {
 Promise<Module> compileStreaming(Promise<Response> source, optional WebAssemblyCompileOptions options = );
 Promise<WebAssemblyInstantiatedSource> instantiateStreaming(
 Promise<Response> source, optional object importObject, optional WebAssemblyCompileOptions options = );
};
```

[`compileStreaming(``source``, ``options``)`] method,
when invoked, returns the result of [compiling a potential WebAssembly
response](#compile-a-potential-webassembly-response) with `source` using `options`.

[`instantiateStreaming(``source``, ``importObject``, ``options``)`]
method, when invoked, performs the following steps:

1. Let `promiseOfModule` be the result of [compiling a
 potential WebAssembly
 response](#compile-a-potential-webassembly-response) with `source` using
 `options`.

2. Return the result of [instantiating the promise of a
 module](https://webassembly.github.io/spec/js-api/#instantiate-a-promise-of-a-module) `promiseOfModule` with imports
 `importObject`.

To [compile a potential WebAssembly
response] with a promise of a
[`Response`](https://fetch.spec.whatwg.org/#response) `source` and
[`WebAssemblyCompileOptions`](https://webassembly.github.io/spec/js-api/#dictdef-webassemblycompileoptions) `options`, perform the following steps:

 This algorithm accepts a
[`Response`](https://fetch.spec.whatwg.org/#response) object, or a promise for one, and compiles and
instantiates the resulting bytes of the response. This compilation can
be performed in the background and in a streaming manner. If the
[`Response`](https://fetch.spec.whatwg.org/#response) is not
[CORS-same-origin](https://html.spec.whatwg.org/#cors-same-origin), does not represent an [ok
status](https://fetch.spec.whatwg.org/#ok-status), or does not match the `` `application/wasm` `` MIME
type, the returned promise will be rejected with a
[`TypeError`](https://tc39.es/ecma262/#sec-native-error-types-used-in-this-standard-typeerror); if compilation or instantiation fails, the returned
promise will be rejected with a
[`CompileError`](https://webassembly.github.io/spec/js-api/#exceptiondef-compileerror) or other relevant error type, depending on the cause of
failure.

1. Let `returnValue` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

2. [React](https://webidl.spec.whatwg.org/#dfn-perform-steps-once-promise-is-settled) to `source`:

 - If `source` was fulfilled with value
 `unwrappedSource`:

 1. Let `response` be `unwrappedSource`'s
 [response](https://fetch.spec.whatwg.org/#concept-response-response).

 2. Let `mimeType` be the result of
 [getting](https://fetch.spec.whatwg.org/#concept-header-list-get) `` `Content-Type` `` from
 `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list).

 3. If `mimeType` is null, reject
 `returnValue` with a
 [`TypeError`](https://tc39.es/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) and abort these substeps.

 4. Remove all [HTTP tab or space
 byte](https://fetch.spec.whatwg.org/#http-tab-or-space-byte) from the start and end of
 `mimeType`.

 5. If `mimeType` is not a
 [byte-case-insensitive](https://infra.spec.whatwg.org/#byte-case-insensitive) match for `` `application/wasm` ``, reject
 `returnValue` with a
 [`TypeError`](https://tc39.es/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) and abort these substeps.

 extra parameters are not allowed, including
 the empty `` `application/wasm;` ``.

 6. If `response` is not
 [CORS-same-origin](https://html.spec.whatwg.org/#cors-same-origin),
 [reject](https://webidl.spec.whatwg.org/#reject) `returnValue` with a
 [`TypeError`](https://tc39.es/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) and abort these substeps.

 7. If `response`'s
 [status](https://fetch.spec.whatwg.org/#concept-response-status) is not an [ok
 status](https://fetch.spec.whatwg.org/#ok-status),
 [reject](https://webidl.spec.whatwg.org/#reject) `returnValue` with a
 [`TypeError`](https://tc39.es/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) and abort these substeps.

 8. [Consume](https://fetch.spec.whatwg.org/#concept-body-consume-body) `response`'s body as an
 [`ArrayBuffer`](https://tc39.es/ecma262/#sec-arraybuffer-objects), and let `bodyPromise` be the
 result.

 Although it is specified here that the
 response is consumed entirely before compilation proceeds,
 that is purely for ease of specification; implementations are
 likely to instead perform processing in a streaming fashion.
 The difference is unobservable, and thus the simpler model is
 specified.

 9. [React](https://webidl.spec.whatwg.org/#dfn-perform-steps-once-promise-is-settled) to `bodyPromise`:

 - If `bodyPromise` was fulfilled with value
 `bodyArrayBuffer`:

 1. Let `stableBytes` be a [copy of the bytes
 held by the
 buffer](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) `bodyArrayBuffer`.

 2. [Asynchronously compile the WebAssembly
 module](https://webassembly.github.io/spec/js-api/#asynchronously-compile-a-webassembly-module) `stableBytes` using the
 [networking task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#networking-task-source) and `options` and
 [resolve](https://webidl.spec.whatwg.org/#resolve) `returnValue` with the
 result.

 - If `bodyPromise` was rejected with reason
 `reason`:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `returnValue` with
 `reason`.

 - If `source` was rejected with reason
 `reason`:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `returnValue` with
 `reason`.

3. Return `returnValue`.

## 3. Serialization

Web user agents must augment the
[`Module`](https://webassembly.github.io/spec/js-api/#module) interface with the
`[`[`Serializable`](https://html.spec.whatwg.org/multipage/structured-data.html#serializable)`]` extended attribute.

The [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps), given `value`, `serialized`, and
`forStorage`, are:

1. If `forStorage` is true, throw a
 \"[DataCloneError](https://webidl.spec.whatwg.org/#datacloneerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. Set `serialized`.\[\[Bytes\]\] to the
 [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization) of `value`.\[\[Bytes\]\].

3. Set `serialized`.\[\[AgentCluster\]\] to the [current
 Realm](https://tc39.es/ecma262/#current-realm)'s corresponding [agent
 cluster](https://tc39.es/ecma262/#sec-agent-clusters).

The [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps), given `serialized`, `value`, and
`targetRealm` are:

1. Let `bytes` be the
 [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization) of `serialized`.\[\[Bytes\]\].

2. Set `value`.\[\[Bytes\]\] to `bytes`.

3. If `targetRealm`'s corresponding [agent
 cluster](https://tc39.es/ecma262/#sec-agent-clusters) is not
 `serialized`.\[\[AgentCluster\]\], then throw a
 \"[DataCloneError](https://webidl.spec.whatwg.org/#datacloneerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. [Compile a WebAssembly
 module](https://webassembly.github.io/spec/js-api/#compile-a-webassembly-module) from `bytes` and set
 `value`.\[\[Module\]\] to the result.

Engines should attempt to share/reuse internal compiled code when
performing a structured serialization, although in corner cases like CPU
upgrade or browser update, this might not be possible and full
recompilation may be necessary.

 The semantics of a structured serialization is as-if
the binary source, from which the
[`Module`](https://webassembly.github.io/spec/js-api/#module) was compiled, is serialized, then deserialized, and
recompiled into the target realm. Given the above engine optimizations,
structured serialization provides developers explicit control over both
compiled-code caching and cross-window/worker code sharing.

## 4. Developer-Facing Display Conventions

*This section is non-normative.*

Browsers, JavaScript engines, and offline tools have common ways of
referring to JavaScript artifacts and language constructs. For example,
locations in JavaScript source code are printed in stack traces or error
messages, and are represented naturally as decimal-format lines and
columns in text files. Names of functions and variables are taken
directly from the sources. Therefore (for example) even though the exact
format of implementation-dependent stack trace strings does not always
match, the locations are easily understandable and the same across
browsers.

To achieve the same goal of a common representation for WebAssembly
constructs, the following conventions are adopted.

A WebAssembly location is a reference to a particular instruction in the
binary, and may be displayed by a browser or engine in similar contexts
as JavaScript source locations. It has the following format:

`${url}:wasm-function[${funcIndex}]:${pcOffset}`

Where

- `${url}` is the URL associated with the module, if applicable (see
 notes).

- `${funcIndex}` is the [function
 index](https://webassembly.github.io/spec/core/syntax/modules.html#syntax-funcidx) relative to the module.

- `${pcOffset}` is the offset in the module binary of the first byte of
 the instruction, printed in hexadecimal with lower-case digits, with a
 leading `0x` prefix.

Notes:

- The URL field may be interpreted differently depending on the context.
 When the response-based instantiation [API](#streaming-modules) is
 used in a browser, the associated URL should be used; or when the
 [`ArrayBuffer`](https://tc39.es/ecma262/#sec-arraybuffer-objects)-based instantiation
 [API](https://webassembly.github.io/spec/js-api/#dom-webassembly-instantiate) is used, the browser should represent the location of
 the API call. This kind of instantiation is analogous to executing
 JavaScript using `eval`; therefore if the browser has an existing
 method to represent the location of the `eval` call it can use a
 similar one for `WebAssembly.instantiate`. For example if the browser
 uses `foo.js line 10 > eval` or `eval at bar (foo.js:10:3)` for
 `eval`, it could use `foo.js line 10 > WebAssembly.instantiate` or
 `WebAssembly.instantiate at bar (foo.js:10:3)`, respectively. Offline
 tools may use a filename instead.

- Using hexadecimal for module offsets matches common conventions in
 native tools such as `objdump` (where addresses are printed in hex)
 and makes them visually distinct from JavaScript line numbers. Other
 numbers are represented in decimal.

While the \"name\" property of an [Exported
Function](https://webassembly.github.io/spec/js-api/#exported-function) instance is specified by the [JS
API](#biblio-wasmjs "WebAssembly JS Integration Specification"),
synthesized function names are also displayed in other contexts like
call stacks in debuggers and string representations of stack traces. If
a WebAssembly module contains a [name
section](https://webassembly.github.io/spec/core/appendix/custom.html?highlight=name%20section#binary-namesec), these names should be used to synthesize a function
name as follows:

- If a function name subsection is present, the displayed name should be
 `${module_name}.${function_name}` or `${function_name}`, depending on
 whether the module name is present.

- Otherwise, the output can be context-dependent:

 - If the function name is shown alongside its location in a stack
 trace, then just the module name (if present) or an empty string can
 be used (because the function index is already in the location).

 - Otherwise, `${module_name}.wasm-function[${funcIndex}]` or
 `wasm-function[${funcIndex}]` should be used to convey the function
 index.

Note that this document does not specify the full format of strings such
as stack frame representations; this allows engines to continue using
their existing formats for JavaScript (which existing code may already
be depending on) while still printing WebAssembly frames in a format
consistent with JavaScript.

## 5. Media-type Registration

The media type `application/wasm` has been registered with the IANA
media type database
[\[IANA-MEDIA-TYPES\]](#biblio-iana-media-types "Media Types"),
with the following [registration
template](https://www.iana.org/assignments/media-types/application/wasm):

application/wasm

Type Name:
: application

Subtype Name:
: wasm

Required Parameters:
: None

Optional Parameters:
: None

Encoding Considerations:
: binary

Security Considerations:

: WebAssembly is a standard, a safe, portable, low-level code format.
 The security considerations associated with executing WebAssembly
 code are described in
 https://www.w3.org/TR/wasm-core/#security-considerations.

 The WebAssembly format includes no integrity or privacy protection.
 If such protection is needed it must be provided externally, e.g.,
 through the use of HTTPS.

Interoperability Considerations:
: See WebAssembly Core Conformance\
 https://www.w3.org/TR/wasm-core/#conformance

Published specification:
: https://www.w3.org/TR/wasm-core-1/
 https://www.w3.org/TR/wasm-js-api-1/
 https://www.w3.org/TR/wasm-web-api-1/

Application Usage:
: The application/wasm media type is intended for use as the type used
 to describe WebAssembly files when sent over HTTP to be executed by
 browsers, which is a common scenario. Additionally, the type is used
 by several WebAssembly runtimes that take advantage of the safety
 and portability while targeting efficient execution and compact
 representation.

Fragment Identifier Considerations:
: None

Restrictions on usage:
: None

Provisional Registrations:
: N/A

Additional information:

:

 Deprecated alias names for this type:
 : None

 Magic number(s):
 : 0x00 0x61 0x73 0x6D

 File extension(s):
 : .wasm

 Macintosh file type code(s):
 : None

 Object Identifier(s) or OID(s):
 : None

Intended usage:
: Common

Other Information & Comments:
: Common

Contact Person:

:

 Contact Name:
 : Eric Prud'hommeaux

 Contact Email Address:
 : eric@w3.org

 Author/Change Controller:
 : W3C

## 6. Security and Privacy Considerations

*This section is non-normative.*

WebAssembly provides no access to the surrounding environment other than
via the JavaScript API described in the [JS
API](#biblio-wasmjs "WebAssembly JS Integration Specification")
specification. Therefore, WebAssembly cannot collect or expose any
information (personal, sensitive or otherwise) to Web sites or other
parties beyond what can be collected, exposed or processed with
JavaScript. WebAssembly memory has the same lifetime as the objects in
the surrounding JavaScript environment and is not persisted or
serialized (other than by copying it out to JavaScript and using
existing serialization APIs). No access is provided to the underlying
platform or hardware, or to other devices, or to the user agent's native
UI.

WebAssembly is an additional program execution mechanism, and can be
executed wherever JavaScript can be executed. Therefore the threat model
is essentially the same as for JavaScript code, and has similar
considerations for delivery (e.g. WebAssembly code should be protected
in transit from active and passive network attackers) and policy (e.g.
some loading mechanisms or execution are restricted via mechanisms such
as the same-origin policy or Content Security Policy).

## 7. Change History

*This section is non-normative.*

Since the original release 1.0 of the WebAssembly specification, a
number of proposals for extensions have been integrated. The following
sections provide an overview of what has changed.

### 7.1. Release 2.0

#### Media-type Registraton Completed
The registration for the `application/wasm` media type has been
successfully completed.
