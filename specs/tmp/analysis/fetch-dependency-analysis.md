# Fetch Specification Dependency Analysis

Generated: 2024-11-27

This document analyzes the WHATWG Fetch specification and identifies all dependent specifications required for implementation.

---

## Already Implemented

| Spec | Reference | Implementation |
|------|-----------|----------------|
| Infra Standard | [INFRA] | `src/infra/` |
| Encoding Standard | [ENCODING] | `src/encoding/` |
| URL Standard | [URL] | `src/url/` (includes Origin, same-origin check) |
| MIME Sniffing | [MIMESNIFF] | `src/mimesniff/` |
| Streams Standard | [STREAMS] | `src/streams/` |
| Web IDL | [WEBIDL] | `src/webidl/` |
| File API | [FILEAPI] | `src/file/` (Blob, File, BlobURLStore) |
| DOM (AbortSignal/Controller) | [DOM] | `src/webidl/impls/AbortSignal.zig`, `AbortController.zig` |

---

## Required Specs - Not Yet Implemented

### Hard Blockers

These specs must be implemented (at least partially) before Fetch can work:

#### 1. HTML Standard (WHATWG)

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://html.spec.whatwg.org/ |
| **Reference in Fetch** | [HTML] |

**What Fetch Uses:**

- **Environment settings object** - Every fetch has a `client` field which is an environment settings object
  - `origin` - For CORS checks
  - `API base URL` - For resolving relative URLs
  - `policy container` - CSP, referrer policy, embedder policy
  - `cross-origin isolated capability` - For certain security features

- **Global objects** - `Window`, `WorkerGlobalScope`
  - Used for task queuing destination
  - Used for determining secure context

- **Task queuing**
  - `queue a global task` algorithm
  - `networking task source` - All fetch completions use this
  - `parallel queue` concept

- **StructuredSerialize / StructuredDeserialize**
  - Used for abort reason serialization
  - Used for cross-realm data transfer

- **Secure context**
  - `is secure context` algorithm
  - Affects mixed content, some API availability

- **Policy container**
  - Contains CSP list, embedder policy, referrer policy

**Specific HTML Sections Needed:**
- Infrastructure (Section 2)
- Web application APIs (Section 8) - especially 8.1 (scripting), 8.3 (agents), 8.4 (realms/settings objects), 8.6 (timers/task queuing)
- Origin (Section 7.5)

---

#### 2. Referrer Policy (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/referrer-policy/ |
| **Reference in Fetch** | [REFERRER] |

**What Fetch Uses:**

- **Referrer policy enum values:**
  - `"no-referrer"`
  - `"no-referrer-when-downgrade"`
  - `"same-origin"`
  - `"origin"`
  - `"strict-origin"`
  - `"origin-when-cross-origin"`
  - `"strict-origin-when-cross-origin"`
  - `"unsafe-url"`
  - `""` (empty string)

- **Algorithms:**
  - `determine request's referrer` - Calculates the Referer header value
  - `set request's referrer policy on redirect` - Updates policy after redirect

**Fetch Spec References:**
- Line 969: Request has associated referrer policy
- Line 2395: Invoke determine request's referrer
- Line 2976: Invoke set request's referrer policy on redirect

---

#### 3. XMLHttpRequest Standard - FormData Only (WHATWG)

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://xhr.spec.whatwg.org/ |
| **Reference in Fetch** | [XHR] |

**What Fetch Uses:**

- **FormData interface:**
  ```webidl
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

- **Entry list concept** - Ordered list of (name, value) entries
- **multipart/form-data serialization** - For request body encoding

**Current Status:** Stub exists at `src/webidl/impls/FormData.zig` - all methods return `NotImplemented`

**Fetch Spec References:**
- Line 753: Body source can be FormData
- Line 4137: XMLHttpRequestBodyInit typedef includes FormData
- Line 4190: Extract algorithm handles FormData
- Line 4348: formData() method returns FormData

---

### Security Specs (Can stub initially)

These are needed for full spec compliance but can be stubbed/skipped for initial implementation:

#### 4. Content Security Policy Level 3 (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/CSP3/ |
| **Reference in Fetch** | [CSP] |

**What Fetch Uses:**
- `should request be blocked by Content Security Policy` algorithm
- `should response be blocked by Content Security Policy` algorithm
- CSP directive checking (script-src, style-src, connect-src, etc.)

**Fetch Spec References:**
- Line 8: Listed in goals
- Line 902: Initiator used for CSP
- Line 1052: Cryptographic nonce metadata for CSP

---

#### 5. Subresource Integrity (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/SRI/ |
| **Reference in Fetch** | [SRI] |

**What Fetch Uses:**
- `do bytes match integrity metadata` algorithm
- Integrity metadata string format (hash algorithm + base64 value)

**Fetch Spec References:**
- Line 2532: Check if bytes match request's integrity metadata
- Line 4543: Request's integrity attribute

---

#### 6. Mixed Content (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/mixed-content/ |
| **Reference in Fetch** | [MIX] |

**What Fetch Uses:**
- `should fetching request be blocked as mixed content` algorithm
- `should response be blocked as mixed content` algorithm

**Fetch Spec References:**
- Line 11: Listed in goals
- Line 902: Initiator used for Mixed Content

---

#### 7. Fetch Metadata Request Headers (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/fetch-metadata/ |
| **Reference in Fetch** | [FETCH-METADATA] |

**What Fetch Uses:**
- `append the Fetch metadata headers` algorithm
- Headers: `Sec-Fetch-Dest`, `Sec-Fetch-Mode`, `Sec-Fetch-Site`, `Sec-Fetch-User`

**Fetch Spec References:**
- Line 9: Listed in goals
- Line 3072: Append Fetch metadata headers for httpRequest

---

#### 8. Upgrade Insecure Requests (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/upgrade-insecure-requests/ |
| **Reference in Fetch** | [UPGRADE-INSECURE-REQUESTS] |

**What Fetch Uses:**
- `upgrade a mixed content request to a potentially trustworthy URL` algorithm

**Fetch Spec References:**
- Line 12: Listed in goals

---

### Optional Specs (Feature-specific)

These are only needed if implementing specific features:

#### 9. Service Workers (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/service-workers/ |
| **Reference in Fetch** | [SW] |

**What Fetch Uses:**
- `handle fetch` algorithm - Service worker fetch event interception
- Service worker registration
- Service worker timing info

**When Needed:** Only if implementing service worker fetch interception

---

#### 10. WebSockets Standard (WHATWG)

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://websockets.spec.whatwg.org/ |
| **Reference in Fetch** | [WEBSOCKETS] |

**What Fetch Uses:**
- `"websocket"` request mode
- `obtain a WebSocket connection` algorithm
- `establish a WebSocket connection` algorithm

**When Needed:** Only if implementing WebSocket mode in fetch

---

#### 11. Resource Timing (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/resource-timing/ |
| **Reference in Fetch** | [RESOURCE-TIMING] |

**What Fetch Uses:**
- `mark resource timing` algorithm
- Timing allow passed flag
- Fetch timing info structure

**When Needed:** Only if implementing performance timing APIs

---

#### 12. Navigation Timing (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/navigation-timing-2/ |
| **Reference in Fetch** | [NAVIGATION-TIMING] |

**What Fetch Uses:**
- Navigation timing info structure

**When Needed:** Only if implementing navigation performance timing

---

#### 13. High Resolution Time (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/hr-time/ |
| **Reference in Fetch** | Implicit via [HTML] |

**What Fetch Uses:**
- `DOMHighResTimeStamp` type
- `coarsened shared current time`
- `relative high resolution time`

**When Needed:** For timing info in fetch params

---

### Protocol Specs (Handled by libcurl)

These define the underlying HTTP protocol. With libcurl, these are handled automatically:

| Spec | Reference | What It Defines |
|------|-----------|-----------------|
| HTTP Semantics (RFC 9110) | [HTTP] | Methods, headers, status codes, message format |
| HTTP/1.1 (RFC 9112) | [HTTP1] | HTTP/1.1 message syntax |
| HTTP/2 (RFC 9113) | Implicit | HTTP/2 protocol |
| HTTP/3 (RFC 9114) | [HTTP3] | HTTP/3 protocol |
| HTTP Caching (RFC 9111) | [HTTP-CACHING] | Cache-Control, stale-while-revalidate |
| HTTP Cookies (RFC 6265bis) | [COOKIES] | Cookie/Set-Cookie headers, cookie storage |
| TLS | [TLS] | HTTPS/secure connections |
| HSTS (RFC 6797) | [HSTS] | HTTP Strict Transport Security |
| Structured Field Values (RFC 9651) | [RFC9651] | Parsing structured headers |

**Note:** The Cookie Store API (`specs/whatwg/cookiestore.md`) is NOT required. Fetch uses RFC 6265bis cookie handling, which libcurl implements.

---

## Implementation Priority

### Phase 1: Minimum Viable Fetch

1. **HTML Standard (subset)**
   - Environment settings object (minimal struct)
   - Origin (already in `src/url/origin.zig`)
   - Task queuing (networking task source)

2. **FormData** (complete the stub)
   - Entry list storage
   - All methods: append, delete, get, getAll, has, set
   - Iterator support

3. **Referrer Policy**
   - Enum values
   - `determine request's referrer` algorithm

### Phase 2: Security Compliance

4. **CSP** - Request/response blocking
5. **SRI** - Integrity checking
6. **Mixed Content** - Blocking insecure requests
7. **Fetch Metadata** - Sec-Fetch-* headers
8. **Upgrade Insecure Requests** - HTTP to HTTPS upgrade

### Phase 3: Optional Features

9. **Service Workers** - Fetch interception
10. **WebSockets** - WebSocket mode
11. **Resource Timing** - Performance measurement
12. **Navigation Timing** - Navigation performance

---

## Dependency Graph

```
Fetch
├── [IMPLEMENTED]
│   ├── Infra
│   ├── Encoding
│   ├── URL (includes Origin)
│   ├── MIME Sniff
│   ├── Streams
│   ├── WebIDL
│   ├── File API (Blob, File)
│   └── DOM (AbortSignal, AbortController)
│
├── [REQUIRED - NOT IMPLEMENTED]
│   ├── HTML (subset)
│   │   ├── Environment settings object
│   │   ├── Task queuing
│   │   ├── Policy container
│   │   └── StructuredSerialize/Deserialize
│   ├── Referrer Policy
│   └── XHR (FormData only)
│
├── [SECURITY - CAN STUB]
│   ├── CSP
│   ├── SRI
│   ├── Mixed Content
│   ├── Fetch Metadata
│   └── Upgrade Insecure Requests
│
├── [OPTIONAL]
│   ├── Service Workers
│   ├── WebSockets
│   ├── Resource Timing
│   └── Navigation Timing
│
└── [LIBCURL HANDLES]
    ├── HTTP (RFC 9110)
    ├── HTTP Caching (RFC 9111)
    ├── Cookies (RFC 6265bis)
    └── TLS
```

---

## Summary Table

| Spec | Org | Required | Implemented | Notes |
|------|-----|----------|-------------|-------|
| Infra | WHATWG | Yes | Yes | `src/infra/` |
| Encoding | WHATWG | Yes | Yes | `src/encoding/` |
| URL | WHATWG | Yes | Yes | `src/url/` |
| MIME Sniff | WHATWG | Yes | Yes | `src/mimesniff/` |
| Streams | WHATWG | Yes | Yes | `src/streams/` |
| WebIDL | WHATWG | Yes | Yes | `src/webidl/` |
| File API | W3C | Yes | Yes | `src/file/` |
| DOM (abort) | WHATWG | Yes | Yes | AbortSignal/Controller |
| **HTML** | WHATWG | **Yes** | **No** | Environment, tasks, policy |
| **Referrer Policy** | W3C | **Yes** | **No** | Referrer algorithms |
| **XHR (FormData)** | WHATWG | **Yes** | **Stub** | Entry list, methods |
| CSP | W3C | Partial | No | Can stub |
| SRI | W3C | Partial | No | Can stub |
| Mixed Content | W3C | Partial | No | Can stub |
| Fetch Metadata | W3C | Partial | No | Can stub |
| Upgrade Insecure | W3C | Partial | No | Can stub |
| Service Workers | W3C | No | No | Optional |
| WebSockets | WHATWG | No | No | Optional |
| Resource Timing | W3C | No | No | Optional |
| Navigation Timing | W3C | No | No | Optional |
| HTTP/Cookies/TLS | IETF | Yes | N/A | libcurl handles |
