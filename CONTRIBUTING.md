# Contributing to WHATWG URL for Zig

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)
- [Spec Compliance](#spec-compliance)

## Code of Conduct

This project follows the Zig Community Code of Conduct. Please be respectful and constructive in all interactions.

## Getting Started

### Prerequisites

- Zig 0.15.1 or later
- Git
- Basic understanding of URLs and web standards

### Setup

```bash
# Clone the repository
git clone https://github.com/zig-whatwg/url.git
cd url

# No external dependencies needed
# webidl-codegen is built-in at src/webidl/codegen/

# Run code generation
zig build codegen

# Run tests
zig build test

# Run benchmarks (if available)
zig build bench
```

## Development Workflow

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Create a branch** for your feature/fix: `git checkout -b feature/my-feature`
4. **Make changes** following our coding standards
5. **Write tests** for new functionality
6. **Run tests** to ensure nothing breaks: `zig build test`
7. **Format code**: `zig fmt src/ tests/`
8. **Commit** with descriptive messages
9. **Push** to your fork
10. **Submit a Pull Request**

## Coding Standards

### Zig Style

- Follow official Zig style guide
- Use `zig fmt` to format all code
- Maximum line length: 100 characters
- Use meaningful variable names (no single-letter except loop counters)

### Naming Conventions

```zig
// Functions: camelCase
pub fn parseURL(allocator: Allocator, input: []const u8) !URL

// Types: PascalCase
pub const URL = struct { ... };
pub const Host = union(enum) { ... };

// Constants: SCREAMING_SNAKE_CASE
pub const SPECIAL_SCHEMES = &[_][]const u8{"http", "https", "ws", "wss", "ftp", "file"};

// Private functions: camelCase with underscore prefix (if truly private)
fn _helperFunction() void
```

### Documentation

- **Module-level docs** (`//!`) at top of every file
- **Function docs** (`///`) for all public functions
- **Spec references** in comments for algorithm implementations
- **Examples** in documentation where helpful

Example:

```zig
//! URL Parser
//!
//! WHATWG URL Standard § 4
//! https://url.spec.whatwg.org/#url-parsing

/// Parse a URL string into a URL record
///
/// Spec: https://url.spec.whatwg.org/#concept-url-parser
///
/// Example:
/// ```zig
/// const url = try parseURL(allocator, "https://example.com/path");
/// defer url.deinit();
/// ```
pub fn parseURL(allocator: Allocator, input: []const u8) !URL {
    // Step 1: Let url be a new URL
    // ...
}
```

### Error Handling

- Use Zig error unions: `!T`
- Always handle allocator errors
- Use `std.testing.allocator` in tests to detect leaks
- Provide meaningful error messages

### Memory Management

- **Always** use `defer` for cleanup
- **Never** leak memory - verify with `std.testing.allocator`
- **Prefer** stack allocation for small buffers
- **Use** arena allocators for temporary work

## Testing

### Test Requirements

All new features must include tests covering:

1. **Happy path** - Normal successful operation
2. **Edge cases** - Boundary conditions, empty input, max values
3. **Error cases** - Invalid input, allocation failures
4. **Memory safety** - No leaks (verified by testing allocator)

### Writing Tests

```zig
test "URL parsing - parses HTTPS URL with port" {
    const allocator = std.testing.allocator;
    
    // Setup
    const input = "https://example.com:8080/path";
    
    // Execute
    const url = try parseURL(allocator, input);
    defer url.deinit();
    
    // Assert
    try std.testing.expectEqualStrings("https", url.scheme);
    try std.testing.expectEqualStrings("example.com", url.host);
    try std.testing.expectEqual(@as(u16, 8080), url.port.?);
}
```

### Running Tests

```bash
# Run all tests
zig build test

# Run with summary
zig build test --summary all

# Run specific test
zig test src/io_queue.zig
```

## Documentation

### Inline Documentation

- **Every public function** must have doc comments
- **Every module** must have module-level documentation
- **Complex algorithms** should have step-by-step comments matching spec

### Spec References

When implementing WHATWG algorithms, include spec references:

```zig
// WHATWG URL Standard § 4.4 Host parsing
// https://url.spec.whatwg.org/#concept-host-parser

// Step 1: If input starts with U+005B ([), then...
if (input.len > 0 and input[0] == '[') {
    // IPv6 address parsing
    // ...
}
```

### README Updates

Update README.md when adding:
- New features
- New URL parsing capabilities
- API changes
- Breaking changes

## Submitting Changes

### Commit Messages

Follow conventional commit format:

```
type(scope): brief description

Longer description if needed.

- Bullet points for details
- Reference issues: Fixes #123
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `test`: Adding tests
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `ci`: CI/CD changes

**Examples:**

```
feat(url): add IPv6 host parsing

Implement WHATWG spec-compliant IPv6 address parsing.
Supports compressed notation and validates address structure.

- Add parseIPv6() function with full validation
- Update host parser to handle IPv6 addresses
- Add 12 tests covering IPv6 edge cases

Spec: https://url.spec.whatwg.org/#concept-ipv6-parser
```

```
fix(percent-encode): correct encoding of space in query

The query encoder was not properly encoding spaces as '+'.
Now follows spec for application/x-www-form-urlencoded encoding.

Fixes #42
```

### Pull Request Process

1. **Update CHANGELOG.md** with your changes
2. **Ensure all tests pass** (`zig build test`)
3. **Format all code** (`zig fmt src/ tests/`)
4. **Write clear PR description** using the template
5. **Reference issues** if applicable
6. **Wait for CI** to pass
7. **Address review feedback** promptly

### Review Criteria

PRs will be reviewed for:

- ✅ Spec compliance
- ✅ Test coverage
- ✅ Code quality
- ✅ Documentation
- ✅ Memory safety
- ✅ No breaking changes (or justified)

## Spec Compliance

This library aims for 100% WHATWG URL Standard compliance.

### Understanding the Spec

1. **Read the relevant spec section** completely
2. **Understand the algorithm** step-by-step
3. **Check cross-references** to other sections
4. **Implement precisely** - don't skip steps or optimize prematurely

### Spec Algorithm Pattern

Match spec algorithms step-by-step:

```zig
// WHATWG URL Standard § 4.3 URL parsing
// https://url.spec.whatwg.org/#concept-url-parser

pub fn parseURL(allocator: Allocator, input: []const u8, base: ?*const URL) !URL {
    // Step 1: Let url be a new URL.
    var url = URL.init(allocator);
    errdefer url.deinit();
    
    // Step 2: Let state be state override if given, or scheme start state otherwise.
    var state: ParserState = .scheme_start;
    
    // Step 3: Let buffer be the empty string.
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    // Step 4: Let pointer be a pointer for input.
    var pointer: usize = 0;
    
    // Step 5: While pointer does not point past the end of input...
    while (pointer <= input.len) {
        const c = if (pointer < input.len) input[pointer] else null;
        
        // Step 6: Run the state machine for the current state
        switch (state) {
            .scheme_start => {
                // Step 6.1: If c is an ASCII alpha...
                if (c != null and isASCIIAlpha(c.?)) {
                    try buffer.append(toLowercase(c.?));
                    state = .scheme;
                } else {
                    // Validation error: missing scheme
                    state = .no_scheme;
                    pointer -= 1;
                }
            },
            // ... other states
            else => {},
        }
        
        pointer += 1;
    }
    
    return url;
}
```

### Spec Deviations

Any deviation from the spec must be:

1. **Documented** with clear rationale
2. **Justified** (performance, API design, etc.)
3. **Approved** by maintainers
4. **Noted** in code comments and documentation

Acceptable deviations:
- ✅ Zig-idiomatic API instead of WebIDL interfaces
- ✅ Different error handling for native library vs JavaScript API
- ✅ More efficient data structures with same behavior

Unacceptable deviations:
- ❌ Incorrect parsing output
- ❌ Missing validation steps
- ❌ Incompatible URL behavior with browsers

## V8 Isolate Lifecycle Management

When working with V8-dependent code (JavaScript bindings, templates, contexts), you must properly manage state tied to V8 isolate lifetime.

### The Problem

V8 isolates are independent JavaScript execution environments. When an isolate is disposed, all V8 objects (templates, contexts, values) become invalid. If your code caches V8 objects in static or global variables, those caches become stale after isolate disposal.

### The Solution: Cleanup Registry

Use the `isolate_lifecycle` module to register cleanup handlers:

```zig
const lifecycle = @import("runtime/engines/v8/isolate_lifecycle.zig");

// Register your cleanup handler during module initialization
try lifecycle.registerCleanup(
    "my_module",           // Module name for debugging
    myCleanupFn,           // Cleanup function
    myValidatorFn,         // Optional debug validator (null if none)
    lifecycle.Priority.default,  // Priority (lower = earlier)
);
```

### Cleanup Function Signature

```zig
fn myCleanupFn(isolate: ?*v8.Isolate, allocator: std.mem.Allocator) void {
    // Clear any cached V8 objects
    my_cached_template = null;
    my_cached_context = null;
    
    // Free any allocated memory
    if (my_state) |state| {
        allocator.destroy(state);
        my_state = null;
    }
}
```

### Priority Levels

Use appropriate priority to ensure cleanup happens in the correct order:

| Priority | Use Case | Value |
|----------|----------|-------|
| `dom_state` | DOM-related thread-local state | 10 |
| `wrapper_cache` | Object wrapper caches | 20 |
| `templates` | V8 template caches | 30 |
| `engine` | Engine-level state | 40 |
| `namespace` | Namespace contexts | 50 |
| `default` | General cleanup | 100 |

Lower numbers run first (clean up dependent state before cleaning up what it depends on).

### Debug Validators

In debug mode, validators check that cleanup was complete:

```zig
fn myValidatorFn() bool {
    // Return true if state is clean
    return my_cached_template == null and my_state == null;
}
```

### Best Practices

1. **Prefer isolate-local storage** over static variables for V8 objects
2. **Always register cleanup handlers** for any module-level V8 state
3. **Use appropriate priority** to respect dependency order
4. **Add debug validators** to catch incomplete cleanup early
5. **Test with multiple isolate lifecycles** (WPT runner creates/destroys isolates)

### Example: Complete Module

```zig
//! My V8-dependent module

const v8 = @import("ffi.zig");
const lifecycle = @import("isolate_lifecycle.zig");

// Module-level state (will be cleaned up)
var cached_template: ?*v8.FunctionTemplate = null;
var initialized: bool = false;

pub fn init() !void {
    try lifecycle.registerCleanup(
        "my_module",
        cleanup,
        validate,
        lifecycle.Priority.templates,
    );
    initialized = true;
}

fn cleanup(_: ?*v8.Isolate, _: std.mem.Allocator) void {
    cached_template = null;
    initialized = false;
}

fn validate() bool {
    return cached_template == null;
}
```

## Questions?

- Open an issue for questions
- Check existing issues and PRs
- Read the WHATWG URL Standard
- Review existing code for patterns
- Check Web Platform Tests (WPT) for expected behavior

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
