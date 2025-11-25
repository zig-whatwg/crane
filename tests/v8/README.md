# V8 WebIDL Bindings Tests

This directory contains JavaScript tests that validate the V8 WebIDL bindings implementation.

## Running Tests

```bash
# Via zig build (recommended)
zig build test-v8

# Or directly
./tests/v8/run_tests.sh
```

## Test Files

- **`dom_test.js`** - Comprehensive DOM Standard tests (400+ tests)
  - Tests all DOM interfaces (Document, Node, Element, Text, etc.)
  - Tests prototype chains and inheritance
  - Tests interface methods and properties
  - Tests constructible vs non-constructible interfaces
  - Tests property descriptors
  - Tests method identity through inheritance
  - Consolidates all previously skipped Zig DOM tests

- **`bindings_test.js`** - Main WebIDL bindings test suite (36 tests)
  - Tests interface constructors
  - Tests prototype chains
  - Tests namespaces and LegacyNamespace pattern
  - Tests non-constructible enforcement
  - Tests property descriptors

- **`bindings_advanced_test.js`** - Advanced bindings tests
  - Tests advanced WebIDL features
  - Tests complex prototype scenarios

- **`prototype_chain_test.js`** - Prototype chain validation
  - Tests inheritance relationships
  - Tests prototype linkage

- **`streams_async_iteration_test.js`** - ReadableStream async iteration (40+ tests)
  - Tests `ReadableStream.values()` and `[Symbol.asyncIterator]()`
  - Tests async iteration with for-await-of loops
  - Tests promise chaining and transformation
  - Tests preventCancel option behavior
  - Tests error propagation through iterators
  - Tests early return and reader release
  - Tests complex async scenarios

- **`bindings_test_verbose.js`** - Full test suite with console.log output
  - Designed for future use when console.log is implemented
  - Contains descriptive test names and detailed assertions

## Current Results

- **Total Tests**: 500+
- **Passing**: Expected when V8 integration complete
- **Status**: ✅ Test infrastructure ready

**Note**: Async iteration tests require full ReadableStream implementation with V8 integration.

## DOM Tests Coverage

The `dom_test.js` file provides comprehensive coverage of the DOM Standard:

- **Document** (Section 4.6) - Creation methods, query methods, import/adopt
- **Node** (Section 4.5) - Type constants, traversal, manipulation
- **Element** (Section 4.10) - Attributes, queries, insertion
- **Text/CharacterData** (Section 4.11-4.12) - Text manipulation
- **Comment/CDATASection/ProcessingInstruction** (Section 4.13-4.15)
- **DocumentFragment/DocumentType** (Section 4.7-4.8)
- **Attr** (Section 4.10.2) - Attribute nodes
- **NodeList/HTMLCollection/NamedNodeMap** (Section 4.3.6-4.10.3)
- **DOMTokenList** (Section 7.1) - classList support
- **Event/CustomEvent** (Section 2) - Event system
- **EventTarget** (Section 2.8) - Event handling
- **AbortSignal/AbortController** (Section 3) - Abort handling
- **Range** (Section 5) - Range selection
- **NodeIterator/TreeWalker** (Section 6) - Tree traversal
- **NodeFilter** (Section 6.1) - Filtering constants
- **MutationObserver/MutationRecord** (Section 4.4) - DOM mutations
- **ShadowRoot/HTMLSlotElement** - Shadow DOM
- **DOMImplementation** (Section 4.6.2)
- **Mixins** - ParentNode, ChildNode, NonDocumentTypeChildNode, Slottable
- **HTMLElement** - HTML-specific features
- **XPath** - XPath evaluation

## What These Tests Validate

### ✅ All Working Correctly

- **Interface Constructors**: All major interfaces exist (Element, Node, EventTarget, etc.)
- **Prototype Chain**: Inheritance works (Element → Node → EventTarget)
- **Constructor Properties**: Circular references are correct
- **Namespaces**: WebAssembly namespace is an object (not a function)
- **Namespace Members**: WebAssembly.Module, Instance, Memory, Table all exist
- **LegacyNamespace**: WebAssembly members don't pollute global scope
- **Non-Constructible**: Interfaces without constructors throw correct errors
- **instanceof Checks**: All constructors are Functions
- **Global Properties**: Interfaces are properly registered on globalThis
- **Property Descriptors**: Constructor.prototype is non-writable, non-enumerable, non-configurable

## Adding New Tests

To add new tests, add lines to `bindings_test.js`. Each line should be a JavaScript expression that evaluates to `true` (pass) or `false` (fail).

Example:
```javascript
// Test that HTMLDivElement exists
typeof HTMLDivElement === "function"

// Test inheritance
HTMLDivElement.prototype.__proto__ === HTMLElement.prototype
```

The test runner will automatically count and report results.
