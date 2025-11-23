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

- **`bindings_test.js`** - Main test suite (36 tests)
  - Tests interface constructors
  - Tests prototype chains
  - Tests namespaces and LegacyNamespace pattern
  - Tests non-constructible enforcement
  - Tests property descriptors

- **`bindings_test_verbose.js`** - Full test suite with console.log output
  - Designed for future use when console.log is implemented
  - Contains descriptive test names and detailed assertions

## Current Results

- **Total Tests**: 36
- **Passing**: 36 (100%) ✅
- **Failing**: 0

🎉 **All tests passing!** The V8 WebIDL bindings are 100% spec-compliant for all tested behaviors.

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
