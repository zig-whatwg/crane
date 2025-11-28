# CSP (Content Security Policy) Dependency Analysis

Generated: 2024-11-27

This document analyzes the W3C Content Security Policy Level 3 specification and identifies all dependent specifications required for implementation.

---

## Specification References in CSP

Based on the `[biblio-*]` references in the CSP spec:

| Reference | Full Name | Type |
|-----------|-----------|------|
| [INFRA] | Infra Standard | WHATWG |
| [HTML] | HTML Standard | WHATWG |
| [FETCH] | Fetch Standard | WHATWG |
| [DOM] | DOM Standard | WHATWG (implicit) |
| [URL] | URL Standard | WHATWG (implicit) |
| [ENCODING] | Encoding Standard | WHATWG (implicit) |
| [REPORTING] | Reporting API | W3C |
| [SRI] | Subresource Integrity | W3C |
| [MIX] | Mixed Content | W3C |
| [UPGRADE-INSECURE-REQUESTS] | Upgrade Insecure Requests | W3C |
| [XHR] | XMLHttpRequest Standard | WHATWG |
| [WEBSOCKETS] | WebSockets Standard | WHATWG |
| [EVENTSOURCE] | Server-Sent Events | WHATWG |
| [BEACON] | Beacon | W3C |
| [CSSOM] | CSS Object Model | W3C |
| [APPMANIFEST] | Web Application Manifest | W3C |
| [ECMA262] | ECMAScript | ECMA |
| [RFC5234] | ABNF | IETF |
| [RFC9110] | HTTP Semantics | IETF |

---

## Already Implemented (in your codebase)

| Spec | Implementation | What CSP Uses |
|------|----------------|---------------|
| **Infra** | `src/infra/` | Lists, ordered sets, strings, byte sequences, ASCII operations, iteration |
| **URL** | `src/url/` | URL parsing, origin, scheme checking |
| **Encoding** | `src/encoding/` | UTF-8 encode (for hash computation) |
| **DOM** | `src/dom/` | Document interface |
| **Fetch** | Not implemented | Request, Response, policy container (CSP integrates with Fetch) |

---

## Hard Blockers for CSP Implementation

### 1. HTML Standard (WHATWG)

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://html.spec.whatwg.org/ |
| **Reference** | [HTML] |

**What CSP Uses from HTML:**

- **Document** - CSP policies are applied to Documents
  - `Document` interface
  - Document's URL
  - Document's origin

- **Global Objects**
  - `Window` interface
  - `WorkerGlobalScope` interface
  - `WorkletGlobalScope` interface

- **Environment Settings Object**
  - Origin
  - Global object
  - Policy container (contains CSP list)

- **Policy Container**
  - CSP list storage
  - `policy-container-csp-list` concept

- **Script Elements**
  - `<script>` element processing
  - `parser-inserted` flag
  - `nonce` attribute
  - Inline script handling

- **Meta Element**
  - `<meta http-equiv="Content-Security-Policy">` processing
  - Content Security Policy state

- **Origin Concepts**
  - `concept-origin`
  - `concept-origin-opaque`
  - Same-origin checks
  - CORS-same-origin

- **Workers**
  - `Worker` interface
  - Worker script execution context

**Specific HTML Sections:**
- Section 2: Infrastructure (origin, policy container)
- Section 4.2.5: The meta element (CSP delivery)
- Section 4.12: Scripting (script execution, nonces)
- Section 8: Web application APIs (global objects, settings objects)
- Section 10: Workers

---

### 2. Fetch Standard (WHATWG)

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://fetch.spec.whatwg.org/ |
| **Reference** | [FETCH] |

**What CSP Uses from Fetch:**

- **Request**
  - `concept-request`
  - `concept-request-client`
  - `concept-request-destination`
  - `concept-request-policy-container`

- **Response**
  - `concept-response`
  - `concept-response-url`
  - `concept-response-header-list`
  - `concept-response-body`
  - `concept-network-error`

- **Header Operations**
  - `extract-header-list-values`

- **Scheme Concepts**
  - `http-scheme`
  - `local-scheme`

- **Integration Points**
  - CSP's `should request be blocked` is called from Main Fetch step 2.4
  - CSP's `should response be blocked` is called from Main Fetch step 11

**Note:** CSP and Fetch have bidirectional dependencies:
- Fetch calls CSP algorithms to check requests/responses
- CSP reads request/response properties from Fetch

---

### 3. Reporting API (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/reporting-1/ |
| **Reference** | [REPORTING] |

**What CSP Uses:**

- **report-to directive** - Uses Reporting API infrastructure
- **CSP violation reports** - Sent via Reporting API
- **Report body structure** - CSPViolationReportBody

**CSP Specific:**
- `report-uri` directive (deprecated, legacy)
- `report-to` directive (modern, uses Reporting API)

---

## Soft Dependencies (Can Stub Initially)

### 4. Subresource Integrity (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/SRI/ |
| **Reference** | [SRI] |

**What CSP Uses:**
- Hash-based source expressions can match external scripts with integrity metadata
- `apply algorithm to response` for hash computation
- SHA-256, SHA-384, SHA-512 hash algorithms

**When Needed:** For `'sha256-...'`, `'sha384-...'`, `'sha512-...'` source expressions matching external scripts

---

### 5. CSSOM (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/cssom-1/ |
| **Reference** | [CSSOM] |

**What CSP Uses:**
- CSS style operations
- Style attribute handling

**When Needed:** For `style-src` directive enforcement

---

### 6. ECMAScript (ECMA-262)

| | |
|---|---|
| **Organization** | ECMA |
| **URL** | https://tc39.es/ecma262/ |
| **Reference** | [ECMA262] |

**What CSP Uses:**
- `eval()` function restriction
- `Function()` constructor restriction
- Dynamic code execution concepts

**When Needed:** For `'unsafe-eval'` source expression

---

## Optional/Feature-Specific Dependencies

### 7. XMLHttpRequest (WHATWG)

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://xhr.spec.whatwg.org/ |
| **Reference** | [XHR] |

**What CSP Uses:**
- `connect-src` directive affects XHR
- XHR requests are subject to CSP checks

**When Needed:** For `connect-src` directive with XHR

---

### 8. WebSockets (WHATWG)

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://websockets.spec.whatwg.org/ |
| **Reference** | [WEBSOCKETS] |

**What CSP Uses:**
- `connect-src` directive affects WebSocket connections

**When Needed:** For `connect-src` directive with WebSockets

---

### 9. Server-Sent Events (WHATWG)

| | |
|---|---|
| **Organization** | WHATWG |
| **URL** | https://html.spec.whatwg.org/multipage/server-sent-events.html |
| **Reference** | [EVENTSOURCE] |

**What CSP Uses:**
- `connect-src` directive affects EventSource

**When Needed:** For `connect-src` directive with EventSource

---

### 10. Beacon (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/beacon/ |
| **Reference** | [BEACON] |

**What CSP Uses:**
- `connect-src` directive affects `navigator.sendBeacon()`

**When Needed:** For `connect-src` directive with Beacon API

---

### 11. Web Application Manifest (W3C)

| | |
|---|---|
| **Organization** | W3C |
| **URL** | https://www.w3.org/TR/appmanifest/ |
| **Reference** | [APPMANIFEST] |

**What CSP Uses:**
- `manifest-src` directive controls manifest loading

**When Needed:** For `manifest-src` directive

---

## CSP Integration Points

CSP integrates with other specs at these points:

### With Fetch (bidirectional)

```
Fetch Main Algorithm
├── Step 2.4: Call "Should request be blocked by CSP?"
│   └── CSP checks request against policy
└── Step 11: Call "Should response be blocked by CSP?"
    └── CSP checks response against policy
```

### With HTML

```
HTML Document Loading
├── Parse Content-Security-Policy header
├── Parse Content-Security-Policy-Report-Only header
├── Parse <meta http-equiv="Content-Security-Policy">
└── Store policies in Document's policy container

HTML Script Execution
├── Check script-src directive
├── Check nonce attribute
├── Check hash of inline script
└── Check 'strict-dynamic' for dynamically added scripts

HTML Style Application
├── Check style-src directive
├── Check nonce attribute
└── Check hash of inline styles
```

### With Reporting API

```
CSP Violation
├── Create violation report body
├── If report-to directive present:
│   └── Queue report via Reporting API
└── If report-uri directive present (legacy):
    └── Send report via fetch (deprecated)
```

---

## Dependency Graph

```
CSP (Content Security Policy)
│
├── [HARD BLOCKERS]
│   │
│   ├── HTML Standard
│   │   ├── Document, Window, Worker interfaces
│   │   ├── Policy container (stores CSP list)
│   │   ├── Environment settings object
│   │   ├── Script/style element processing
│   │   ├── Meta element CSP delivery
│   │   └── Origin concepts
│   │
│   ├── Fetch Standard
│   │   ├── Request/Response types
│   │   ├── Integration hooks (Main Fetch steps 2.4, 11)
│   │   └── Header list operations
│   │
│   └── Reporting API
│       ├── report-to directive
│       └── Violation report delivery
│
├── [ALREADY IMPLEMENTED]
│   │
│   ├── Infra Standard ✅
│   │   ├── Lists, ordered sets
│   │   ├── String operations
│   │   └── ASCII whitespace, splitting
│   │
│   ├── URL Standard ✅
│   │   ├── URL parsing
│   │   ├── Origin
│   │   └── Scheme checking
│   │
│   └── Encoding Standard ✅
│       └── UTF-8 encode (for hash)
│
├── [SOFT DEPENDENCIES]
│   │
│   ├── Subresource Integrity
│   │   └── Hash matching for external scripts
│   │
│   ├── CSSOM
│   │   └── Style operations
│   │
│   └── ECMAScript
│       └── eval() restriction
│
└── [OPTIONAL - Feature specific]
    │
    ├── XHR → connect-src
    ├── WebSockets → connect-src
    ├── EventSource → connect-src
    ├── Beacon → connect-src
    └── App Manifest → manifest-src
```

---

## Implementation Priority

### Phase 1: Core CSP

**Required specs:**
1. **Infra** ✅ (already implemented)
2. **URL** ✅ (already implemented)
3. **Encoding** ✅ (already implemented)

**Need to implement:**
4. **HTML (subset)** - Policy container, Document/Window basics
5. **Fetch (subset)** - Request/Response types (CSP integrates at Fetch level)

**CSP core features:**
- Policy parsing (`parse a serialized CSP`)
- Directive parsing
- Source expression matching
- `default-src`, `script-src`, `style-src`, `img-src`, `connect-src`, `font-src`, `object-src`, `media-src`, `frame-src`

### Phase 2: Violation Reporting

**Need to implement:**
6. **Reporting API** - For `report-to` directive

**CSP features:**
- Violation report creation
- `report-to` directive
- `report-uri` directive (legacy)

### Phase 3: Advanced Features

**Need to implement:**
7. **SRI integration** - For hash-based external script matching

**CSP features:**
- `'strict-dynamic'`
- `'unsafe-hashes'`
- External script hash matching
- `frame-ancestors`
- `sandbox`
- `form-action`

---

## Summary: What's Blocking CSP

| Priority | Spec | Why Blocking |
|----------|------|--------------|
| **1** | **HTML Standard** | Policy container, Document, global objects, script/style processing |
| **2** | **Fetch Standard** | Request/Response types, CSP hooks in Main Fetch |
| **3** | **Reporting API** | Violation report delivery |

**Note:** CSP and Fetch are mutually dependent:
- CSP needs Fetch's Request/Response types
- Fetch calls CSP's blocking algorithms

This means they should be implemented together or CSP should be implemented as part of Fetch.

---

## Minimal CSP for Fetch

If implementing CSP only for Fetch integration (not full browser CSP), you need:

1. **Policy parsing** - Parse `Content-Security-Policy` header
2. **Request blocking** - `Should request be blocked by CSP?`
3. **Response blocking** - `Should response be blocked by CSP?`
4. **Source expression matching** - Match URLs against directive values

This requires:
- Policy data structure (directive set, disposition, source)
- Source expression grammar parsing
- URL matching algorithm
- Request/Response access (from Fetch)

You do NOT need for minimal implementation:
- Inline script/style handling (HTML-specific)
- Nonce/hash for inline content (HTML-specific)
- `report-to`/`report-uri` (can stub)
- `frame-ancestors` (HTML-specific)
- `sandbox` (HTML-specific)
