# Web Platform Tests (WPT) Integration

This document describes how to set up, run, and interpret Web Platform Tests in Crane.

## Overview

### What is WPT?

[Web Platform Tests (WPT)](https://web-platform-tests.org/) is the official test suite used by all major browsers to ensure interoperability. It contains over 1.7 million tests covering virtually every web platform API.

Crane integrates with WPT to:
- **Measure spec compliance** against the same tests browsers use
- **Track implementation progress** over time
- **Identify API gaps** through test failures
- **Ensure browser compatibility** for all implemented specs

### Why WPT?

Using WPT ensures that Crane's implementations behave identically to Chrome, Firefox, and Safari. When a WPT test passes, you can be confident that:
1. The implementation matches the WHATWG specification
2. The behavior is consistent with major browsers
3. Web content will work correctly

### What We Test

Crane runs WPT tests for all implemented WHATWG specifications:

| Category | Standard | Description |
|----------|----------|-------------|
| `url/` | URL Standard | URL parsing, serialization, URLSearchParams |
| `encoding/` | Encoding Standard | TextEncoder, TextDecoder, legacy encodings |
| `console/` | Console Standard | Console logging APIs |
| `mimesniff/` | MIME Sniffing | MIME type parsing and detection |
| `streams/` | Streams Standard | ReadableStream, WritableStream, TransformStream |
| `fetch/` | Fetch Standard | Request, Response, Headers, Body |
| `xhr/` | XMLHttpRequest | XMLHttpRequest API |
| `dom/` | DOM Standard | EventTarget, Node, Element, Events |
| `html/` | HTML Standard | Non-rendering HTML APIs |

## Setup

### Prerequisites

1. **V8 JavaScript Engine**
   ```bash
   # macOS (Homebrew)
   brew install v8

   # Ubuntu/Debian
   # Build from source or use prebuilt binaries
   # See https://v8.dev/docs/build
   ```

2. **libuv** (for async operations)
   ```bash
   # macOS (Homebrew)
   brew install libuv

   # Ubuntu/Debian
   apt install libuv1-dev
   ```

3. **Zig 0.15.1+**
   ```bash
   # Download from https://ziglang.org/download/
   ```

### Getting the WPT Submodule

The WPT test suite is included as a git submodule. There are two ways to get it:

**Option 1: Clone with submodules** (recommended for new clones)
```bash
git clone --recursive https://github.com/bcardarella/crane.git
cd crane
```

**Option 2: Initialize submodule in existing clone**
```bash
cd crane
git submodule update --init
```

The WPT tests will be located at `tests/wpt/`.

## Running Tests

### Basic Usage

Run all in-scope WPT tests:
```bash
zig build wpt
```

### Filtered Tests

Run tests for a specific category:
```bash
# URL tests only
zig build wpt -- url/

# Encoding tests only
zig build wpt -- encoding/

# Multiple categories
zig build wpt -- url/ encoding/ streams/
```

### Command-Line Arguments

Arguments after `--` are passed to the WPT runner:

```bash
# Run specific test file
zig build wpt -- url/url-constructor.any.js

# Run tests matching a pattern
zig build wpt -- streams/readable-streams/
```

## Understanding Results

### Output Location

Test results are written to:
- **Console**: Summary statistics
- **File**: `wpt-results/wptreport.json` (wpt.fyi compatible format)

### Console Output

After running tests, you'll see a summary like:
```
================================
WPT Test Results
================================
Tests:     156
Subtests:  4832
  Passed:  4521 (93.6%)
  Failed:  287
  Timeout: 12
  NotRun:  12
================================
```

### wptreport.json Format

The JSON report follows the [wpt.fyi format](https://github.com/nicferrier/wpt-webdriver-results-schema):

```json
{
  "run_info": {
    "product": "whatwg-zig",
    "browser_version": "0.1.0",
    "os": "darwin",
    "processor": "aarch64",
    "revision": "abc123"
  },
  "time_start": 1699000000000,
  "time_end": 1699000100000,
  "results": [
    {
      "test": "/url/url-constructor.any.js",
      "status": "OK",
      "message": null,
      "duration": 1234,
      "subtests": [
        {
          "name": "URL constructor, empty string",
          "status": "PASS",
          "message": null
        }
      ]
    }
  ]
}
```

### Status Meanings

**Test-level status** (overall test file):
| Status | Meaning |
|--------|---------|
| `OK` | Test file executed successfully |
| `ERROR` | Test file failed to execute (syntax error, missing dependency) |
| `TIMEOUT` | Test file exceeded time limit |

**Subtest-level status** (individual assertions):
| Status | Meaning |
|--------|---------|
| `PASS` | Assertion passed |
| `FAIL` | Assertion failed |
| `TIMEOUT` | Subtest timed out |
| `NOTRUN` | Subtest was skipped (precondition failed) |
| `PRECONDITION_FAILED` | Test prerequisites not met |

### Timeouts

- **Normal timeout**: 10 seconds per test
- **Long timeout**: 60 seconds (for complex async tests)

Tests marked with `<meta name="timeout" content="long">` use the extended timeout.

## In-Scope Categories

These WPT directories are tested because they correspond to implemented WHATWG specs:

| Directory | Status | Notes |
|-----------|--------|-------|
| `url/` | Active | Full URL Standard coverage |
| `encoding/` | Active | TextEncoder/Decoder, legacy encodings |
| `console/` | Active | Console API |
| `mimesniff/` | Active | MIME type sniffing |
| `streams/` | Active | Streams Standard |
| `fetch/` | Active | Fetch API (Request, Response, Headers) |
| `xhr/` | Active | XMLHttpRequest |
| `dom/` | Active | DOM events, nodes, elements |
| `html/` | Partial | Non-rendering tests only |

### HTML Category Exclusions

Within `html/`, some subdirectories are excluded because they require rendering:
- `html/rendering/` - Layout and painting
- `html/canvas/` - Canvas 2D API
- `html/semantics/embedded-content/media-elements/` - Video/audio playback
- `html/webappapis/animation-frames/` - requestAnimationFrame

## Out-of-Scope Categories

These categories require rendering engines, graphics APIs, or browser-specific features that Crane doesn't implement:

| Category | Reason |
|----------|--------|
| `css/` | Requires layout engine |
| `2dcontext/` | Requires Canvas rendering |
| `webgl/`, `webgl2/` | Requires GPU/graphics |
| `webgpu/` | Requires GPU/graphics |
| `visual/` | Visual regression tests |
| `intersection-observer/` | Requires layout |
| `resize-observer/` | Requires layout |
| `scroll-animations/` | Requires layout/rendering |
| `paint-timing/` | Requires rendering |

### Additional Exclusions

These paths are excluded regardless of category:
- `*/support/` - Helper files, not tests
- `*/resources/` - Test resources
- `*-manual.html` - Manual (human) tests
- `*-ref.html` - Reference images for visual tests
- `/infrastructure/` - WPT infrastructure tests
- `/tentative/` - Experimental/unstable tests

## Troubleshooting

### V8 Linking Errors

**Problem**: `error: unable to find v8` or linker errors

**Solution**: Ensure V8 is installed and library paths are configured:
```bash
# macOS: Check Homebrew paths
ls /opt/homebrew/opt/v8/lib/

# If missing, reinstall V8
brew reinstall v8
```

### Submodule Issues

**Problem**: `tests/wpt/` is empty

**Solution**:
```bash
git submodule update --init --recursive

# If that fails, try:
git submodule deinit -f tests/wpt
git submodule update --init tests/wpt
```

### Test Timeouts

**Problem**: Many tests timing out

**Possible causes**:
1. **V8 initialization slow**: First run may be slower
2. **System load**: Close other applications
3. **Infinite loops**: Check for implementation bugs

**Solution**: Run a smaller subset first:
```bash
zig build wpt -- url/url-constructor.any.js
```

### Missing Browser Globals

**Problem**: `ReferenceError: window is not defined`

**Solution**: This indicates a WPT test requires browser globals that aren't implemented. Check if the test is in the exclusion list or if a new global needs to be added.

### Build Failures

**Problem**: Build fails before tests run

**Solution**:
```bash
# Clean and rebuild
rm -rf zig-cache zig-out
zig build wpt
```

### Interpreting Failures

When tests fail, check:

1. **Is it a known gap?** - Some features are intentionally unimplemented
2. **Is it a spec change?** - WPT may have updated for new spec versions
3. **Is it a bug?** - Create an issue with the failing test path

To investigate a failure:
```bash
# Run just the failing test
zig build wpt -- url/url-constructor.any.js

# Check the wptreport.json for details
cat wpt-results/wptreport.json | jq '.results[] | select(.test == "/url/url-constructor.any.js")'
```

## Test File Types

WPT uses different file extensions to indicate how tests should run:

| Extension | Context | Description |
|-----------|---------|-------------|
| `.html` | Document | HTML document test |
| `.any.js` | Multiple | Runs in window, worker, and service worker |
| `.window.js` | Window | Window/document context only |
| `.worker.js` | Worker | Web Worker context only |

## Further Reading

- [WPT Documentation](https://web-platform-tests.org/writing-tests/)
- [wpt.fyi Dashboard](https://wpt.fyi/) - Browser results comparison
- [testharness.js API](https://web-platform-tests.org/writing-tests/testharness-api.html)
- [WHATWG Standards](https://spec.whatwg.org/)
