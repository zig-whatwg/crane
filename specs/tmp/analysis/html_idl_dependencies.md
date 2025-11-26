# HTML IDL Type Dependencies Analysis

**Generated**: 2025-11-26  
**Source**: `specs/idl/html.idl`  
**Total Lines**: 3067

---

## Executive Summary

The HTML Standard IDL has **extensive type-level dependencies** on other WHATWG specifications. These dependencies are **TYPE-LEVEL BLOCKERS** - the HTML IDL cannot compile or function without these external type definitions.

### Critical Statistics

- **Total External Specs Referenced**: 20+
- **Total External Type References**: 150+ occurrences
- **Core Blocking Specs**: DOM, CSSOM, WebGL, Media Capture, Fetch, Trusted Types, File API, Geometry, WebIDL, CSP
- **Most Critical Dependencies**: DOM (Element, Document, Node, Event, ShadowRoot), File API (File, FileList, Blob), Fetch (FormData, AbortSignal)

---

## Type-Level Blockers (Critical Dependencies)

These specs provide types that HTML IDL **cannot compile without**:

### 1. **DOM Standard** (CRITICAL - Most Referenced)

**Spec**: https://dom.spec.whatwg.org/

**Types Used** (65+ references):
- **Core Node Types**: `Element`, `Node`, `Document`, `DocumentFragment`, `NodeList`, `Range`
- **Event System**: `Event`, `EventTarget`, `EventInit`, `EventHandler`, `AbortSignal`
- **Shadow DOM**: `ShadowRoot`
- **Collections**: `HTMLCollection` (used extensively for element collections)
- **Other**: `DOMTokenList`, `DOMStringMap`, `DocumentOrShadowRoot` (mixin)

**Usage Frequency**: **VERY HIGH** (100+ occurrences)

**Critical APIs Using DOM Types**:
- All HTML element interfaces extend `Element` or `HTMLElement : Element`
- Event handlers throughout (GlobalEventHandlers, WindowEventHandlers)
- Shadow DOM APIs (HTMLTemplateElement, HTMLSlotElement)
- Document tree navigation (Document partial, getElementsByName)
- Form elements return NodeList for labels
- Custom Elements registry

**Blocker Level**: **CRITICAL** - HTML cannot exist without DOM types

---

### 2. **File API** (CRITICAL - Forms & Input)

**Spec**: https://w3c.github.io/FileAPI/

**Types Used**:
- `File` - File input elements, drag-and-drop
- `FileList` - Multiple file inputs
- `Blob` - Canvas export, media provider, image bitmap source

**Usage Frequency**: **HIGH** (20+ occurrences)

**Critical APIs**:
- `HTMLInputElement.files` (FileList)
- `DataTransferItem.getAsFile()` (File)
- `DataTransfer.files` (FileList)
- `HTMLCanvasElement.toBlob()` (BlobCallback)
- `MediaProvider` typedef includes Blob
- `ImageBitmapSource` typedef includes Blob
- `ElementInternals.setFormValue()` accepts File

**Blocker Level**: **CRITICAL** - Forms, file uploads, drag-and-drop unusable without

---

### 3. **Fetch Standard** (CRITICAL - Forms & Navigation)

**Spec**: https://fetch.spec.whatwg.org/

**Types Used**:
- `FormData` - Form submission, element internals
- `AbortSignal` - Cancelable operations
- `RequestCredentials` - Worker credentials

**Usage Frequency**: **MEDIUM-HIGH** (15+ occurrences)

**Critical APIs**:
- `FormDataEvent.formData` (FormData)
- `FormDataEventInit.formData` (required FormData)
- `NavigateEvent.formData` (FormData?)
- `NavigateEventInit.formData` (FormData?)
- `ElementInternals.setFormValue()` accepts FormData
- `CloseWatcherOptions.signal` (AbortSignal)
- `NavigateEvent.signal` (AbortSignal)
- `WorkerOptions.credentials` (RequestCredentials)
- `WorkletOptions.credentials` (RequestCredentials)

**Blocker Level**: **CRITICAL** - Forms and navigation broken without

---

### 4. **CSSOM / CSSOM View** (CRITICAL - Styling)

**Spec**: https://drafts.csswg.org/cssom/ and https://drafts.csswg.org/cssom-view/

**Types Used**:
- `LinkStyle` (mixin) - HTMLLinkElement, HTMLStyleElement
- `DOMMatrix`, `DOMMatrix2DInit` - Canvas transforms
- `DOMPointInit` - Canvas paths

**Usage Frequency**: **MEDIUM** (10+ occurrences)

**Critical APIs**:
- `HTMLLinkElement includes LinkStyle`
- `HTMLStyleElement includes LinkStyle`
- Canvas 2D transform methods (setTransform, getTransform)
- Path2D.addPath transform parameter
- CanvasPattern.setTransform

**Blocker Level**: **CRITICAL** - Styling and canvas transforms broken without

---

### 5. **WebGL Specifications** (HIGH - Canvas)

**Specs**: WebGL 1.0 and WebGL 2.0

**Types Used**:
- `WebGLRenderingContext` - Canvas 3D context
- `WebGL2RenderingContext` - Canvas 3D context v2
- `GPUCanvasContext` - WebGPU (separate spec)

**Usage Frequency**: **MEDIUM** (8+ occurrences)

**Critical APIs**:
- `RenderingContext` typedef (line 1290)
- `OffscreenRenderingContext` typedef (line 1570)
- `HTMLCanvasElement.getContext()` return type
- `OffscreenCanvas.getContext()` return type

**Blocker Level**: **HIGH** - Canvas 3D contexts broken without

---

### 6. **Media Capture and Streams** (HIGH - Media Elements)

**Spec**: https://w3c.github.io/mediacapture-main/

**Types Used**:
- `MediaStream` - Video/audio streaming

**Usage Frequency**: **LOW-MEDIUM** (3 occurrences)

**Critical APIs**:
- `MediaProvider` typedef (line 558): `(MediaStream or MediaSource or Blob)`
- `HTMLMediaElement.srcObject` attribute

**Blocker Level**: **HIGH** - Media streaming broken without

---

### 7. **Media Source Extensions** (HIGH - Media Elements)

**Spec**: https://w3c.github.io/media-source/

**Types Used**:
- `MediaSource` - Programmatic media streaming

**Usage Frequency**: **LOW-MEDIUM** (2 occurrences)

**Critical APIs**:
- `MediaProvider` typedef (line 558)
- `HTMLMediaElement.srcObject` attribute

**Blocker Level**: **HIGH** - Advanced media playback broken without

---

### 8. **Trusted Types** (HIGH - Security)

**Spec**: https://w3c.github.io/trusted-types/dist/spec/

**Types Used**:
- `TrustedHTML` - Sanitized HTML content
- `TrustedScript` - Sanitized script content
- `TrustedScriptURL` - Sanitized script URLs

**Usage Frequency**: **MEDIUM** (25+ occurrences)

**Critical APIs**:
- `Document.parseHTMLUnsafe()` accepts TrustedHTML
- `Document.write()`, `Document.writeln()` accept TrustedHTML
- `HTMLIFrameElement.srcdoc` accepts TrustedHTML
- `Element.innerHTML`, `Element.outerHTML` accept TrustedHTML
- `Element.setHTMLUnsafe()` accepts TrustedHTML
- `ShadowRoot.innerHTML` accepts TrustedHTML
- `DOMParser.parseFromString()` accepts TrustedHTML
- `Range.createContextualFragment()` accepts TrustedHTML
- `TimerHandler` typedef includes TrustedScript
- `WorkerGlobalScope.importScripts()` accepts TrustedScriptURL
- `Worker` constructor accepts TrustedScriptURL
- `SharedWorker` constructor accepts TrustedScriptURL

**Blocker Level**: **HIGH** - Security-critical innerHTML/script APIs broken without

---

### 9. **Service Workers** (MEDIUM - Messaging)

**Spec**: https://w3c.github.io/ServiceWorker/

**Types Used**:
- `ServiceWorker` - Service worker instance

**Usage Frequency**: **LOW** (1 occurrence)

**Critical APIs**:
- `MessageEventSource` typedef (line 2554): `(WindowProxy or MessagePort or ServiceWorker)`

**Blocker Level**: **MEDIUM** - postMessage from service workers broken without

---

### 10. **Geometry Interfaces** (MEDIUM - Canvas)

**Spec**: https://drafts.fxtf.org/geometry/

**Types Used**:
- `DOMMatrix` - 2D/3D transformation matrices
- `DOMMatrix2DInit` - 2D matrix initialization
- `DOMPointInit` - Point initialization

**Usage Frequency**: **MEDIUM** (8+ occurrences)

**Critical APIs**:
- Canvas transform methods (already covered in CSSOM section)
- CanvasPath.roundRect radii parameter

**Blocker Level**: **MEDIUM** - Advanced canvas operations broken without

---

### 11. **WebCodecs** (MEDIUM - Media)

**Spec**: https://w3c.github.io/webcodecs/

**Types Used**:
- `VideoFrame` - Raw video frame data

**Usage Frequency**: **LOW** (1 occurrence)

**Critical APIs**:
- `CanvasImageSource` typedef (line 1308-1316) includes VideoFrame

**Blocker Level**: **MEDIUM** - Advanced video canvas operations broken without

---

### 12. **ARIA (Accessibility)** (HIGH - Accessibility)

**Spec**: https://w3c.github.io/aria/

**Types Used**:
- `ARIAMixin` - ARIA attributes for accessibility

**Usage Frequency**: **LOW** (1 occurrence)

**Critical APIs**:
- `ElementInternals includes ARIAMixin` (line 1663)

**Blocker Level**: **HIGH** - Custom element accessibility broken without

---

### 13. **SVG** (MEDIUM - Mixed Content)

**Spec**: https://svgwg.org/svg2-draft/

**Types Used**:
- `SVGScriptElement` - SVG script elements
- `SVGImageElement` - SVG image elements

**Usage Frequency**: **LOW-MEDIUM** (3 occurrences)

**Critical APIs**:
- `HTMLOrSVGScriptElement` typedef (line 47)
- `Document.currentScript` return type
- `HTMLOrSVGImageElement` typedef (line 1308)
- `CanvasImageSource` typedef includes SVGImageElement

**Blocker Level**: **MEDIUM** - SVG/HTML interop broken without

---

### 14. **WebIDL** (CRITICAL - Type System)

**Spec**: https://webidl.spec.whatwg.org/

**Types Used**:
- `DOMString`, `USVString`, `ByteString` - String types
- `DOMHighResTimeStamp` - High-resolution timestamps
- `VoidFunction` - Callback type
- `FrozenArray` - Immutable arrays
- Extended attributes: `[Exposed]`, `[CEReactions]`, `[LegacyNullToEmptyString]`, etc.

**Usage Frequency**: **UBIQUITOUS** (1000+ occurrences)

**Blocker Level**: **CRITICAL** - Entire IDL unusable without WebIDL primitives

---

### 15. **Performance Timeline** (MEDIUM - Performance)

**Spec**: https://w3c.github.io/performance-timeline/

**Types Used**:
- `PerformanceEntry` - Base performance entry type

**Usage Frequency**: **LOW** (1 occurrence)

**Critical APIs**:
- `VisibilityStateEntry : PerformanceEntry` (line 1684)

**Blocker Level**: **MEDIUM** - Page visibility timing broken without

---

### 16. **HR Time** (HIGH - Timing)

**Spec**: https://w3c.github.io/hr-time/

**Types Used**:
- `DOMHighResTimeStamp` - High-resolution timestamp type

**Usage Frequency**: **MEDIUM** (5+ occurrences)

**Critical APIs**:
- `FrameRequestCallback` parameter (line 2524)
- `VisibilityStateEntry.startTime` (line 1687)
- Animation frame timing

**Blocker Level**: **HIGH** - Animation timing broken without

---

### 17. **CSS View Transitions** (LOW - Visual Transitions)

**Spec**: https://drafts.csswg.org/css-view-transitions-1/

**Types Used**:
- `ViewTransition` - View transition instance

**Usage Frequency**: **LOW** (3 occurrences)

**Critical APIs**:
- `PageSwapEvent.viewTransition` (line 2113)
- `PageRevealEvent.viewTransition` (line 2124)

**Blocker Level**: **LOW** - Only affects page transitions (new API)

---

### 18. **Content Security Policy** (MEDIUM - Security)

**Spec**: https://w3c.github.io/webappsec-csp/

**Types Used**:
- Event handler for `onsecuritypolicyviolation`

**Usage Frequency**: **LOW** (1 occurrence)

**Critical APIs**:
- `GlobalEventHandlers.onsecuritypolicyviolation` (line 2268)

**Blocker Level**: **MEDIUM** - CSP violation reporting broken without

---

### 19. **WebGPU** (MEDIUM - GPU Rendering)

**Spec**: https://gpuweb.github.io/gpuweb/

**Types Used**:
- `GPUCanvasContext` - WebGPU rendering context

**Usage Frequency**: **LOW-MEDIUM** (2 occurrences)

**Critical APIs**:
- `RenderingContext` typedef (line 1290)
- `OffscreenRenderingContext` typedef (line 1570)

**Blocker Level**: **MEDIUM** - GPU rendering broken without

---

### 20. **WebIDL Extended Attributes** (CRITICAL - Spec Semantics)

These are not "types" but are required for correct IDL processing:

**Extended Attributes Used**:
- `[Exposed=(Window,Worker)]` - Context exposure
- `[CEReactions]` - Custom element reactions
- `[LegacyNullToEmptyString]` - Null handling
- `[Reflect]`, `[ReflectURL]`, `[ReflectSetter]` - Attribute reflection
- `[HTMLConstructor]` - HTML element construction
- `[SameObject]` - Object identity
- `[NewObject]` - Object creation
- `[PutForwards]` - Attribute forwarding
- `[LegacyUnenumerableNamedProperties]` - Property enumeration
- `[LegacyOverrideBuiltIns]` - Built-in overriding
- `[LegacyUnforgeable]` - Property protection
- `[LegacyFactoryFunction]` - Legacy constructors
- `[EnforceRange]`, `[Clamp]` - Number coercion
- `[SecureContext]` - Security requirements
- `[Transferable]`, `[Serializable]` - Structured clone
- `[Global]` - Global scope
- Many more...

**Blocker Level**: **CRITICAL** - Correct behavior impossible without

---

## Dependency Frequency Analysis

### Very High Frequency (50+ references)
1. **DOM Standard** (Element, Node, Document, Event, EventTarget) - 100+ occurrences

### High Frequency (20-50 references)
2. **Trusted Types** (TrustedHTML, TrustedScript, TrustedScriptURL) - 25+ occurrences
3. **File API** (File, FileList, Blob) - 20+ occurrences

### Medium Frequency (10-20 references)
4. **Fetch** (FormData, AbortSignal) - 15+ occurrences
5. **CSSOM** (LinkStyle, DOMMatrix, DOMMatrix2DInit) - 10+ occurrences
6. **WebGL** (WebGLRenderingContext, WebGL2RenderingContext) - 8+ occurrences
7. **Geometry** (DOMMatrix, DOMMatrix2DInit, DOMPointInit) - 8+ occurrences

### Low-Medium Frequency (3-10 references)
8. **HR Time** (DOMHighResTimeStamp) - 5+ occurrences
9. **Media Capture** (MediaStream) - 3 occurrences
10. **SVG** (SVGScriptElement, SVGImageElement) - 3 occurrences
11. **CSS View Transitions** (ViewTransition) - 3 occurrences

### Low Frequency (1-2 references)
12. **Media Source** (MediaSource) - 2 occurrences
13. **WebGPU** (GPUCanvasContext) - 2 occurrences
14. **Service Workers** (ServiceWorker) - 1 occurrence
15. **WebCodecs** (VideoFrame) - 1 occurrence
16. **Performance Timeline** (PerformanceEntry) - 1 occurrence
17. **ARIA** (ARIAMixin) - 1 occurrence

---

## Critical Types vs Optional Types

### Critical Types (MUST HAVE for core HTML functionality)

**DOM Core**:
- Element, Node, Document, DocumentFragment - **All HTML elements depend on these**
- EventTarget, Event, EventInit - **All event handling depends on these**
- NodeList, HTMLCollection - **Element collections throughout HTML**
- ShadowRoot - **Web Components**
- DOMTokenList - **Class lists, rel lists**

**File API**:
- File, FileList - **File inputs, drag-and-drop**
- Blob - **Canvas export, media, image processing**

**Fetch**:
- FormData - **Form submission**
- AbortSignal - **Cancelable operations**

**CSSOM**:
- LinkStyle - **<link> and <style> elements**
- DOMMatrix, DOMMatrix2DInit - **Canvas transforms**

**WebIDL**:
- DOMString, USVString, ByteString - **All string handling**
- DOMHighResTimeStamp - **Timing APIs**

### Optional Types (Can be stubbed/mocked initially)

**Media Extensions**:
- MediaStream, MediaSource - Only needed for advanced media APIs
- VideoFrame - Only for WebCodecs integration

**Graphics Extensions**:
- WebGLRenderingContext, WebGL2RenderingContext - Only for 3D canvas
- GPUCanvasContext - Only for WebGPU

**Security Extensions**:
- TrustedHTML, TrustedScript, TrustedScriptURL - Can fall back to plain strings

**Visual Effects**:
- ViewTransition - Only for page transition effects

**Messaging Extensions**:
- ServiceWorker (in MessageEventSource) - Only for SW messaging

---

## Core HTML APIs vs Edge Case APIs

### Core HTML APIs (High Priority - Need all dependencies)

**Document Tree Manipulation**:
- Depends on: DOM (Element, Node, Document, DocumentFragment)

**Forms**:
- Depends on: File API (File, FileList), Fetch (FormData), DOM (NodeList, ValidityState)

**Canvas 2D**:
- Depends on: Geometry (DOMMatrix), File API (Blob), DOM (Element)

**Scripting**:
- Depends on: Trusted Types (TrustedScript, TrustedScriptURL), DOM (Document)

**Custom Elements**:
- Depends on: DOM (ShadowRoot, Element), ARIA (ARIAMixin)

**Event Handling**:
- Depends on: DOM (Event, EventTarget, EventInit)

**Workers**:
- Depends on: Fetch (RequestCredentials), Trusted Types (TrustedScriptURL)

### Edge Case APIs (Lower Priority)

**3D Canvas**:
- Depends on: WebGL (WebGLRenderingContext, WebGL2RenderingContext, GPUCanvasContext)

**Advanced Media**:
- Depends on: Media Capture (MediaStream), Media Source (MediaSource), WebCodecs (VideoFrame)

**Page Transitions**:
- Depends on: CSS View Transitions (ViewTransition)

**Legacy/Obsolete APIs**:
- HTMLMarqueeElement, HTMLFrameSetElement, HTMLFrameElement, etc. - Lower priority

---

## Implementation Recommendations

### Phase 1: Core Foundation (CRITICAL - Must implement first)

1. **DOM Standard** - Element, Node, Document, Event, EventTarget, ShadowRoot, NodeList, HTMLCollection, DOMTokenList
2. **WebIDL Types** - DOMString, USVString, ByteString, DOMHighResTimeStamp, VoidFunction
3. **File API** - File, FileList, Blob
4. **Fetch** - FormData, AbortSignal, RequestCredentials
5. **CSSOM** - LinkStyle mixin, DOMMatrix, DOMMatrix2DInit
6. **Geometry** - DOMPointInit

**Rationale**: These types are used throughout the HTML IDL. Without them, most HTML elements and APIs cannot function.

### Phase 2: Forms and Media (HIGH Priority)

1. **Media Capture** - MediaStream
2. **Media Source** - MediaSource
3. **Trusted Types** - TrustedHTML, TrustedScript, TrustedScriptURL (can initially stub with plain string fallback)
4. **ARIA** - ARIAMixin
5. **HR Time** - DOMHighResTimeStamp (if not in WebIDL)
6. **Performance Timeline** - PerformanceEntry

**Rationale**: Forms, media elements, and security features are widely used.

### Phase 3: Advanced Graphics (MEDIUM Priority)

1. **WebGL** - WebGLRenderingContext, WebGL2RenderingContext
2. **WebGPU** - GPUCanvasContext
3. **WebCodecs** - VideoFrame

**Rationale**: 3D canvas and advanced media processing are less common but still important.

### Phase 4: Edge Cases (LOW Priority)

1. **Service Workers** - ServiceWorker (for MessageEventSource)
2. **CSS View Transitions** - ViewTransition
3. **SVG** - SVGScriptElement, SVGImageElement (if HTML/SVG interop needed)

**Rationale**: These enable specific advanced features but don't block core HTML functionality.

---

## Missing Type Definition Strategy

### Option 1: Create Stub Interfaces (Recommended for Initial Implementation)

```zig
// src/dom_stub.zig - Temporary until DOM is implemented
pub const Element = opaque {};
pub const Node = opaque {};
pub const Document = opaque {};
pub const Event = opaque {};
pub const EventTarget = opaque {};
// ... etc
```

**Pros**: 
- HTML IDL can compile immediately
- Clear TODOs for later implementation
- Type safety maintained

**Cons**:
- Stubs need replacing with real implementations
- Cannot call methods on stub types

### Option 2: Use External DOM Implementation

Check if any Zig DOM implementation exists:
- whatwg/dom in Zig
- Third-party libraries

**Pros**:
- Real implementation immediately
- Interoperability with other code

**Cons**:
- May not exist yet
- Dependency management complexity

### Option 3: Implement Core DOM Types First (Recommended Long-term)

Implement DOM Standard in parallel with HTML Standard.

**Pros**:
- Full type safety and functionality
- Correct cross-spec behavior

**Cons**:
- Significant upfront work
- Delays HTML implementation

---

## Spec Dependency Graph

```
HTML Standard
├─── DOM Standard (CRITICAL - blocking all)
│    ├─── Element, Node, Document
│    ├─── EventTarget, Event
│    ├─── ShadowRoot, NodeList, HTMLCollection
│    └─── DOMTokenList
│
├─── File API (CRITICAL - blocking forms/media)
│    ├─── File, FileList
│    └─── Blob
│
├─── Fetch (CRITICAL - blocking forms/navigation)
│    ├─── FormData
│    ├─── AbortSignal
│    └─── RequestCredentials
│
├─── CSSOM (CRITICAL - blocking styling)
│    ├─── LinkStyle (mixin)
│    └─── DOMMatrix, DOMMatrix2DInit
│
├─── Geometry (HIGH - blocking canvas)
│    └─── DOMPointInit
│
├─── WebGL (HIGH - blocking 3D canvas)
│    ├─── WebGLRenderingContext
│    └─── WebGL2RenderingContext
│
├─── Media Capture (HIGH - blocking media streaming)
│    └─── MediaStream
│
├─── Media Source (HIGH - blocking advanced media)
│    └─── MediaSource
│
├─── Trusted Types (HIGH - blocking secure APIs)
│    ├─── TrustedHTML
│    ├─── TrustedScript
│    └─── TrustedScriptURL
│
├─── HR Time (MEDIUM - blocking animation timing)
│    └─── DOMHighResTimeStamp
│
├─── ARIA (MEDIUM - blocking accessibility)
│    └─── ARIAMixin
│
├─── WebCodecs (MEDIUM - blocking advanced media)
│    └─── VideoFrame
│
├─── WebGPU (MEDIUM - blocking GPU rendering)
│    └─── GPUCanvasContext
│
├─── Service Workers (LOW - messaging only)
│    └─── ServiceWorker
│
├─── SVG (LOW - interop only)
│    ├─── SVGScriptElement
│    └─── SVGImageElement
│
└─── CSS View Transitions (LOW - visual effects only)
     └─── ViewTransition
```

---

## Summary

The HTML Standard has **20+ type-level dependencies** on other WHATWG and W3C specifications. The most critical are:

1. **DOM Standard** (100+ references) - Absolutely critical, blocks everything
2. **File API** (20+ references) - Critical for forms and media
3. **Fetch** (15+ references) - Critical for forms and navigation
4. **CSSOM** (10+ references) - Critical for styling and canvas
5. **Trusted Types** (25+ references) - High priority for security

**Recommendation**: Start with DOM Standard implementation (or stubs), then File API and Fetch. These three specs unblock most HTML functionality. WebGL, Media APIs, and visual effects can be added later as needed.

**Implementation Path**:
1. Create stubs for DOM types → HTML IDL compiles
2. Implement core DOM (Element, Node, Document, Event) → Basic HTML works
3. Implement File API and Fetch → Forms and navigation work
4. Implement CSSOM → Styling works
5. Add WebGL/Media/etc. → Advanced features work
