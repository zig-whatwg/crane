# XMLHttpRequest (XHR) Dependency Analysis

Generated: 2024-11-27

This document analyzes the WHATWG XMLHttpRequest specification and identifies all dependent specifications required for implementation.

---

## Specification Overview

The XHR spec defines three main interfaces:

1. **XMLHttpRequest** - The main API for fetching resources
2. **FormData** - Interface for key-value form data
3. **ProgressEvent** - Event interface for progress tracking

---

## Specification References

From the XHR spec (line 76-78):

> This specification uses terminology from DOM, DOM Parsing and Serialization, Encoding, Fetch, File API, HTML, URL, Web IDL, and XML.

| Reference | Full Name | Type |
|-----------|-----------|------|
| [INFRA] | Infra Standard | WHATWG |
| [DOM] | DOM Standard | WHATWG |
| [DOM-PARSING] | DOM Parsing and Serialization | W3C |
| [ENCODING] | Encoding Standard | WHATWG |
| [FETCH] | Fetch Standard | WHATWG |
| [FILEAPI] | File API | W3C |
| [HTML] | HTML Standard | WHATWG |
| [URL] | URL Standard | WHATWG |
| [WEBIDL] | Web IDL | WHATWG |
| [XML] | XML | W3C |
| [XML-NAMES] | Namespaces in XML | W3C |

---

## Already Implemented (in your codebase)

| Spec | Implementation | What XHR Uses |
|------|----------------|---------------|
| **Infra** | `src/infra/` | Lists, byte sequences, strings |
| **URL** | `src/url/` | URL parsing, serialization, credentials |
| **Encoding** | `src/encoding/` | `get an encoding`, decode, UTF-8 encode |
| **WebIDL** | `src/webidl/` | Types, DOMException, EventHandler |
| **File API** | `src/file/` | Blob, File (for FormData) |
| **DOM** | `src/dom/` | Document, Event, EventTarget |
| **MIME Sniff** | `src/mimesniff/` | MIME type parsing (for Content-Type) |

---

## Hard Blockers for XHR Implementation

### 1. Fetch Standard (WHATWG) - CRITICAL

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://fetch.spec.whatwg.org/ |
| **Reference** | [FETCH] |

**What XHR Uses from Fetch:**

XHR is essentially a **wrapper around Fetch**. The `send()` method creates a Fetch request:

- **Request creation** (line 509-542):
  - `concept-request` with method, URL, header list, body, client, mode, credentials
  - `unsafe-request` flag
  - `use-CORS-preflight` flag
  - `credentials mode` ("include" or "same-origin")
  - `initiator type` ("xmlhttprequest")

- **Fetch execution**:
  - `concept-fetch` - The actual fetch operation
  - `fetch controller` - For abort/terminate
  - `wait for a response`

- **Response handling**:
  - `concept-response`
  - `network error`
  - Response status, headers, body

- **Header operations**:
  - `concept-method`, `forbidden-method`
  - `header-name`, `header-value`
  - `forbidden-request-header`
  - `concept-header-list-combine`
  - `concept-header-list-get`
  - `concept-header-list-set`
  - `concept-header-value-normalize`

- **Body handling**:
  - `bodyinit-safely-extract`
  - `body-with-type`
  - Body source types

- **CORS**:
  - `cors-preflight-request`
  - Credentials handling

**Critical:** XHR cannot function without Fetch - it's the underlying implementation.

---

### 2. HTML Standard (WHATWG) - CRITICAL

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://html.spec.whatwg.org/ |
| **Reference** | [HTML] |

**What XHR Uses from HTML:**

- **Global Objects**:
  - `Window` - For synchronous XHR restrictions
  - `DedicatedWorker`, `SharedWorker` - Exposed contexts
  - `current-global-object`
  - `relevant-global-object`

- **Environment Settings Object**:
  - `relevant-settings-object` - Used as request client
  - Origin for requests

- **Document**:
  - `concept-document-window` (associated Document)
  - `fully-active` check
  - HTML/XML document creation for `responseXML`
  - HTML parser, XML parser

- **Event Handlers**:
  - `event-handlers` concept
  - `event-handler-event-type`
  - `EventHandler` callback type

- **URL Parsing**:
  - `encoding-parsing-a-url` - Relative URL resolution

- **Forms** (for FormData constructor):
  - `HTMLFormElement`
  - `HTMLElement` (submitter)
  - `constructing the entry list`
  - `create an entry`
  - Submit button concept

- **Serialization**:
  - `fragment-serializing-algorithm-steps` - For Document body

---

### 3. DOM Standard (WHATWG) - REQUIRED

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://dom.spec.whatwg.org/ |
| **Reference** | [DOM] |

**What XHR Uses from DOM:**

- **EventTarget** - XMLHttpRequest inherits from XMLHttpRequestEventTarget which inherits from EventTarget
- **Event** - For readystatechange event
- **Document** - For request/response body, responseXML
- **concept-event-fire** - Firing events
- **concept-event-dispatch** - Event dispatching

---

### 4. File API (W3C) - REQUIRED

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/FileAPI/ |
| **Reference** | [FILEAPI] |

**What XHR Uses from File API:**

- **Blob** - For FormData values, request body
- **File** - For FormData values (extends Blob)
- `FormDataEntryValue` typedef: `(File or USVString)`

**Status:** Already implemented in `src/file/`

---

## Soft Blockers (Can stub or defer)

### 5. DOM Parsing and Serialization (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/DOM-Parsing/ |
| **Reference** | [DOM-PARSING] |

**What XHR Uses:**
- Serialization for Document body in `send()`

**Can defer:** Only needed for `send(document)` - can support other body types first.

---

### 6. XML / XML Namespaces (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/xml/ |
| **Reference** | [XML], [XML-NAMES] |

**What XHR Uses:**
- XML parser for `responseXML`
- XML encoding detection
- XML MIME type handling

**Can defer:** Only needed for `responseType = "document"` with XML content.

---

## Dependency Graph

```
XMLHttpRequest
│
├── [CRITICAL - Must implement]
│   │
│   ├── Fetch Standard ⭐⭐⭐
│   │   ├── Request/Response types
│   │   ├── Fetch algorithm
│   │   ├── Header operations
│   │   ├── Body extraction
│   │   ├── CORS handling
│   │   └── Fetch controller (abort)
│   │
│   ├── HTML Standard ⭐⭐⭐
│   │   ├── Window, Worker global objects
│   │   ├── Environment settings object
│   │   ├── Event handlers
│   │   ├── Document (for responseXML)
│   │   ├── URL parsing (encoding-parsing-a-url)
│   │   └── Form entry list (for FormData)
│   │
│   └── DOM Standard ⭐⭐
│       ├── EventTarget (inheritance)
│       ├── Event interface
│       ├── Document interface
│       └── Event firing/dispatch
│
├── [ALREADY IMPLEMENTED]
│   │
│   ├── Infra ✅
│   ├── URL ✅
│   ├── Encoding ✅
│   ├── WebIDL ✅
│   ├── File API ✅
│   ├── MIME Sniff ✅
│   └── DOM (partial) ✅
│
└── [CAN DEFER]
    │
    ├── DOM Parsing and Serialization
    │   └── Document serialization for send()
    │
    └── XML / XML Namespaces
        └── XML parsing for responseXML
```

---

## XHR Components Analysis

### XMLHttpRequest Interface

| Feature | Dependencies |
|---------|-------------|
| Constructor | WebIDL, XMLHttpRequestUpload |
| `open()` | URL parsing (HTML), Fetch method validation |
| `setRequestHeader()` | Fetch header validation |
| `send()` | **Fetch** (entire algorithm), HTML settings object |
| `abort()` | Fetch controller terminate |
| `readyState` | Internal state machine |
| `status`, `statusText` | Fetch response |
| `getResponseHeader()` | Fetch response headers |
| `getAllResponseHeaders()` | Fetch response headers |
| `responseType` | Internal state |
| `response` | Fetch response body, Encoding, (optionally) HTML/XML parsing |
| `responseText` | Encoding decode |
| `responseXML` | HTML parser, XML parser, DOM Document |
| Events | DOM EventTarget, ProgressEvent |

### FormData Interface

| Feature | Dependencies |
|---------|-------------|
| Constructor (no args) | None |
| Constructor (form) | **HTML** (HTMLFormElement, entry list construction) |
| `append()` | File API (Blob, File), HTML entry creation |
| `delete()` | Internal list |
| `get()`, `getAll()` | Internal list |
| `has()` | Internal list |
| `set()` | File API (Blob, File), HTML entry creation |
| Iterator | WebIDL iterable |

### ProgressEvent Interface

| Feature | Dependencies |
|---------|-------------|
| Constructor | DOM Event |
| `lengthComputable`, `loaded`, `total` | None (simple attributes) |

---

## Implementation Strategy

### Option 1: Full XHR (requires Fetch + HTML)

If Fetch and HTML subset are implemented:

1. Implement XMLHttpRequestEventTarget (extends EventTarget)
2. Implement XMLHttpRequestUpload (extends XMLHttpRequestEventTarget)
3. Implement XMLHttpRequest state machine
4. Implement `open()`, `setRequestHeader()`, `send()`, `abort()`
5. Implement response getters
6. Implement FormData
7. Implement ProgressEvent

### Option 2: Minimal XHR (skip some features)

Implement core XHR without:
- `responseXML` (skip HTML/XML parsing)
- `send(document)` (skip DOM serialization)
- `FormData(form)` constructor (skip form entry list)

This still requires Fetch + HTML subset but avoids XML/DOM-Parsing specs.

### Option 3: FormData Only (for Fetch body support)

If you only need FormData for Fetch request bodies:

1. Implement FormData with no-argument constructor only
2. Implement `append()`, `delete()`, `get()`, `getAll()`, `has()`, `set()`
3. Skip `FormData(form)` constructor (requires HTML forms)

This requires:
- File API (Blob, File) ✅ Already implemented
- WebIDL ✅ Already implemented
- HTML entry creation (can stub as simple name/value pairs)

---

## Summary: XHR Blockers

| Priority | Spec | Why Blocking | Status |
|----------|------|--------------|--------|
| **1** | **Fetch Standard** | XHR's `send()` is a wrapper around Fetch | Not implemented |
| **2** | **HTML Standard** | Global objects, settings object, Document, forms | Not implemented |
| **3** | **DOM Standard** | EventTarget, Event, Document | Partial |
| **4** | File API | Blob, File for FormData | ✅ Implemented |
| **5** | Encoding | Text decoding for response | ✅ Implemented |
| **6** | URL | URL parsing | ✅ Implemented |
| **7** | DOM Parsing | Document serialization | Can defer |
| **8** | XML | XML parsing | Can defer |

---

## Key Insight

**XHR is a higher-level API built on top of Fetch.**

The XHR spec explicitly states that `send()` creates a Fetch request and processes the Fetch response. This means:

1. **You must implement Fetch before XHR** - There's no way around this
2. **XHR adds state machine + events on top of Fetch** - The added value is the state tracking and progress events
3. **FormData can be partially implemented independently** - For basic use cases without HTML form integration

### Recommended Implementation Order

```
1. Fetch (with HTML subset)     ← Foundation
   ↓
2. FormData (basic)             ← For Fetch body support
   ↓
3. ProgressEvent                ← Simple, standalone
   ↓
4. XMLHttpRequest               ← Wrapper around Fetch
   ↓
5. FormData (full)              ← Add HTMLFormElement support
   ↓
6. responseXML support          ← Add HTML/XML parsing
```

---

## Conclusion

**XHR has the same core blockers as Fetch:**
- Fetch Standard (XHR wraps Fetch)
- HTML Standard (global objects, settings, forms)

If you're implementing Fetch anyway, XHR becomes relatively straightforward - it's mainly:
- A state machine (UNSENT → OPENED → HEADERS_RECEIVED → LOADING → DONE)
- Event dispatching (readystatechange, progress events)
- Response type handling (text, json, blob, arraybuffer, document)

The complex parts (CORS, headers, body handling, network layer) are all in Fetch.
