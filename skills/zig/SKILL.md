# Zig Programming Skill

## Purpose

This skill ensures you write **highest quality, well-tested, highly performant, and properly documented Zig code** for any project.

---

## When to Use This Skill

Load this skill automatically when:
- Writing or refactoring Zig code
- Implementing algorithms and data structures
- Designing types and APIs
- Managing memory and performance
- Writing tests
- Documenting public APIs

---

## Core Philosophy

**Modern Zig emphasizes:**
1. **Explicitness** - Make behavior visible in code
2. **Safety** - Memory safety, no undefined behavior
3. **Performance** - Zero-cost abstractions, no hidden allocations
4. **Simplicity** - Simple, readable code over clever tricks

---

# Part 1: Code Quality

## Naming Conventions

```zig
// Types: PascalCase
pub const URL = struct { ... };
pub const Host = union(enum) { ... };
pub const ParseError = error { ... };

// Functions and variables: snake_case
pub fn parse(allocator: Allocator, input: []const u8) !URL { ... }
pub fn percent_encode(input: []const u8) ![]u8 { ... }
const my_variable: i32 = 42;
const port: ?u16 = null;

// Constants: SCREAMING_SNAKE_CASE
pub const MAX_URL_LENGTH: usize = 1_000_000;
pub const DEFAULT_HTTP_PORT: u16 = 80;

// Private: No special prefix needed (use 'fn' without 'pub')
fn internal_helper() void { ... }
```

---

## Error Handling

### Domain-Specific Error Sets

```zig
// Define clear, specific errors
pub const ParseError = error{
    InvalidURL,
    InvalidScheme,
    InvalidHost,
    InvalidPort,
    InvalidIPv4,
    InvalidIPv6,
};

// Combine with Allocator.Error for functions that allocate
pub fn parse(
    allocator: Allocator,
    input: []const u8,
) (Allocator.Error || ParseError)!URL {
    // Can fail with OutOfMemory OR parsing errors
}
```

### defer and errdefer

```zig
// defer: ALWAYS runs when scope exits
pub fn process(allocator: Allocator) !Result {
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit(); // Runs even on error
    
    try list.append(42);
    return computeResult(list);
}

// errdefer: ONLY runs on error
pub fn create(allocator: Allocator) !Resource {
    var resource = try Resource.init(allocator);
    errdefer resource.deinit(); // Only if we return error
    
    try resource.setup();
    return resource; // Success - errdefer doesn't run
}
```

---

## Memory Management

### The Golden Rule: Explicit Ownership

```zig
// Caller provides allocator, caller owns result
pub fn operation(allocator: Allocator, input: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, input.len);
    errdefer allocator.free(result);
    
    // Process...
    return result; // Caller must free
}

// Usage
const result = try operation(allocator, input);
defer allocator.free(result); // Caller frees
```

### defer Immediately After Allocation

```zig
// ✅ GOOD: defer right after allocation
pub fn example(allocator: Allocator) !void {
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit(); // Declare cleanup immediately
    
    try list.append(42);
    // list automatically cleaned up
}

// ❌ BAD: Forgetting defer
pub fn example(allocator: Allocator) !void {
    var list = std.ArrayList(u8).init(allocator);
    try list.append(42);
    // Memory leak! list.deinit() never called
}
```

### Arena for Temporary Allocations

```zig
// Use arena when you have many temporary allocations
pub fn algorithm(allocator: Allocator, input: []const u8) !Result {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit(); // Free all at once
    
    const temp_allocator = arena.allocator();
    
    // All temporary allocations
    const temp1 = try temp_allocator.alloc(u8, 1024);
    const temp2 = try temp_allocator.alloc(u8, 2048);
    // No need to free individually
    
    // Final result uses original allocator (outlives arena)
    const result = try allocator.dupe(Result, computed);
    return result;
}
```

---

## Type Safety

### Const Correctness

```zig
// Immutable data: []const u8
pub fn read_only(string: []const u8) usize {
    return string.len; // Cannot modify
}

// Mutable data: []u8 or *T
pub fn modify(list: *std.ArrayList(u8)) !void {
    try list.append(42); // Can modify
}
```

### Explicit Types

```zig
// ✅ GOOD: Explicit types prevent errors
const count: usize = list.items.len;
const byte: u8 = data[index];
const code_point: u21 = 0x1F600;

// Use type casts when needed
try std.testing.expectEqual(@as(usize, 10), list.items.len);
```

### Tagged Unions for Sum Types

```zig
pub const Host = union(enum) {
    domain: []const u8,
    ipv4: u32,
    ipv6: [8]u16,
    opaque: []const u8,
    
    pub fn deinit(self: Host, allocator: Allocator) void {
        switch (self) {
            .domain, .opaque => |s| allocator.free(s),
            .ipv4, .ipv6 => {}, // No allocation
        }
    }
    
    pub fn serialize(self: Host, allocator: Allocator) ![]u8 {
        return switch (self) {
            .domain => |d| try allocator.dupe(u8, d),
            .ipv4 => |ip| try serializeIPv4(allocator, ip),
            .ipv6 => |ip| try serializeIPv6(allocator, ip),
            .opaque => |o| try allocator.dupe(u8, o),
        };
    }
};
```

---

## Struct Patterns

### Init/Deinit Convention

```zig
pub const URL = struct {
    scheme: []const u8,
    host: ?Host,
    port: ?u16,
    path: []const u8,
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) URL {
        return .{
            .scheme = "",
            .host = null,
            .port = null,
            .path = "",
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *URL) void {
        self.allocator.free(self.scheme);
        if (self.host) |host| host.deinit(self.allocator);
        self.allocator.free(self.path);
    }
    
    // Methods
    pub fn serialize(self: *const URL, allocator: Allocator) ![]u8 {
        // Implementation...
    }
};
```

### Method Naming

```zig
// self: *const Type - Read-only methods
pub fn serialize(self: *const URL) ![]u8 { }
pub fn get_scheme(self: *const URL) []const u8 { }

// self: *Type - Mutating methods
pub fn set_host(self: *URL, host: Host) void { }
pub fn update_path(self: *URL, path: []const u8) !void { }

// No self: Static/factory functions
pub fn parse(allocator: Allocator, input: []const u8) !URL { }
```

---

# Part 2: Performance

## Inline Small Functions

```zig
// Inline small, frequently called functions
pub inline fn is_ascii(byte: u8) bool {
    return byte < 0x80;
}

pub inline fn is_ascii_alpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

// Don't inline large functions - let compiler decide
pub fn complex_parse(input: []const u8) !Result {
    // Large function body...
}
```

## Preallocate When Size Known

```zig
// ✅ GOOD: Preallocate capacity
pub fn process_items(allocator: Allocator, items: []Item) ![]Result {
    var results = try std.ArrayList(Result).initCapacity(
        allocator,
        items.len
    );
    errdefer results.deinit();
    
    for (items) |item| {
        results.appendAssumeCapacity(process(item)); // No reallocation!
    }
    
    return results.toOwnedSlice();
}

// ❌ BAD: Let ArrayList grow incrementally (multiple reallocations)
pub fn process_items(allocator: Allocator, items: []Item) ![]Result {
    var results = std.ArrayList(Result).init(allocator);
    errdefer results.deinit();
    
    for (items) |item| {
        try results.append(process(item)); // May reallocate each time
    }
    
    return results.toOwnedSlice();
}
```

## Fast Paths for Common Cases

```zig
// Fast path for ASCII (most common)
pub fn to_lowercase(allocator: Allocator, input: []const u8) ![]u8 {
    // Fast path: Check if ASCII-only
    var is_ascii_only = true;
    for (input) |byte| {
        if (byte >= 0x80) {
            is_ascii_only = false;
            break;
        }
    }
    
    if (is_ascii_only) {
        // Fast ASCII path
        const result = try allocator.alloc(u8, input.len);
        for (input, 0..) |byte, i| {
            result[i] = if (byte >= 'A' and byte <= 'Z')
                byte + ('a' - 'A')
            else
                byte;
        }
        return result;
    }
    
    // Slow path: Unicode handling
    return unicode_to_lowercase(allocator, input);
}
```

## Minimize Allocations

```zig
// ✅ GOOD: Reuse buffer
pub fn transform_multiple(allocator: Allocator, items: [][]const u8) ![][]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    var results = std.ArrayList([]u8).init(allocator);
    errdefer {
        for (results.items) |item| allocator.free(item);
        results.deinit();
    }
    
    for (items) |item| {
        buffer.clearRetainingCapacity(); // Reuse allocation!
        try process_into(item, &buffer);
        try results.append(try buffer.toOwnedSlice());
    }
    
    return results.toOwnedSlice();
}
```

## Early Exit

```zig
// Check cheapest conditions first
pub fn validate(input: []const u8) !void {
    // 1. Check length (cheapest)
    if (input.len == 0) return error.EmptyInput;
    if (input.len > MAX_LENGTH) return error.TooLong;
    
    // 2. Check for invalid bytes (moderate cost)
    for (input) |byte| {
        if (byte < 0x20 and byte != '\t' and byte != '\n') {
            return error.InvalidControlCharacter;
        }
    }
    
    // 3. Full validation (most expensive)
    try validate_utf8(input);
}
```

---

# Part 3: Testing

## Test Coverage Requirements

Every function MUST have tests for:
1. **Happy path** - Normal, expected usage
2. **Edge cases** - Empty input, boundary conditions
3. **Error cases** - Invalid input, error conditions
4. **Memory safety** - No leaks (use std.testing.allocator)
5. **Spec compliance** - Matches WHATWG specification

## Test Naming

```zig
// Pattern: "type.function - specific behavior"
test "URL.parse - parses simple HTTP URL" { }
test "URL.parse - handles IPv6 address" { }
test "URL.parse - rejects invalid scheme" { }

test "percent_encode - encodes special characters" { }
test "percent_encode - preserves unreserved characters" { }

test "Host.deinit - frees domain name" { }
test "Host.deinit - handles IPv4 without allocation" { }
```

## Test Structure (Arrange-Act-Assert)

```zig
test "URL.parse - parses complete URL" {
    // Arrange
    const allocator = std.testing.allocator;
    const input = "https://example.com:8080/path?query#fragment";
    
    // Act
    const url = try URL.parse(allocator, input);
    defer url.deinit();
    
    // Assert
    try std.testing.expectEqualStrings("https", url.scheme);
    try std.testing.expectEqualStrings("example.com", url.host.?.domain);
    try std.testing.expectEqual(@as(?u16, 8080), url.port);
    try std.testing.expectEqualStrings("/path", url.path);
}
```

## Memory Leak Detection (CRITICAL)

```zig
// ALWAYS use std.testing.allocator
test "no memory leaks" {
    const allocator = std.testing.allocator; // Detects leaks!
    
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit(); // Must clean up
    
    try list.append(42);
    
    // Test passes only if all allocations freed
}

// Test cleanup on error
test "no leaks on error" {
    const allocator = std.testing.allocator;
    
    _ = parse(allocator, "invalid") catch |err| {
        try std.testing.expectEqual(error.InvalidInput, err);
        // Even on error, no leaks allowed
    };
}
```

## TDD Workflow

1. **Read spec completely** - Understand algorithm
2. **Write failing test** - Test what you want to implement
3. **Minimal implementation** - Make it compile
4. **Make test pass** - Implement algorithm
5. **Add edge case tests** - Cover all cases
6. **Refactor** - Never modify existing tests!

---

# Part 4: Documentation

## Documentation Requirements

**Public API MUST be documented.**
**Private/temporary code MAY skip documentation.**

### What to Document

✅ **MUST document:**
- Public functions (`pub fn`)
- Public types (`pub const`)
- Public constants
- Module-level documentation (`//!`)

❌ **MAY skip documentation:**
- Private functions (`fn` without `pub`)
- Temporary/mock implementations
- Internal helper functions
- Test code

### Module Documentation (`//!`)

```zig
//! URL Parsing - WHATWG URL Standard
//!
//! Implements URL parsing, serialization, and manipulation from the
//! WHATWG URL Standard. URLs are parsed into structured components.
//!
//! ## WHATWG Specification
//!
//! - §4 URL parsing: https://url.spec.whatwg.org/#url-parsing
//! - §5 URL serialization: https://url.spec.whatwg.org/#url-serializing
//!
//! ## Examples
//!
//! ```zig
//! const url = try URL.parse(allocator, "https://example.com/path");
//! defer url.deinit();
//!
//! const serialized = try url.serialize(allocator);
//! defer allocator.free(serialized);
//! ```

const std = @import("std");
```

### Function Documentation (`///`)

```zig
/// Parse a URL string into a URL record.
///
/// Implements WHATWG URL "basic URL parser" per §4.1.
///
/// ## Spec Reference
/// https://url.spec.whatwg.org/#concept-basic-url-parser
///
/// ## Algorithm (URL §4.1)
/// 1. Let url be a new URL.
/// 2. Let state be scheme start state.
/// 3. Parse each code point according to state machine.
/// 4. Return url or failure.
///
/// ## Parameters
/// - `allocator`: Memory allocator for URL components
/// - `input`: URL string to parse
/// - `base`: Optional base URL for relative resolution
///
/// ## Returns
/// Parsed URL record, or error if invalid.
///
/// ## Errors
/// - `error.InvalidScheme`: Scheme is invalid
/// - `error.InvalidHost`: Host parsing failed
/// - `error.OutOfMemory`: Allocation failed
///
/// ## Example
/// ```zig
/// const url = try URL.parse(allocator, "https://example.com");
/// defer url.deinit();
/// ```
pub fn parse(
    allocator: Allocator,
    input: []const u8,
    base: ?*const URL,
) !URL {
    // Implementation with numbered comments matching spec
}
```

### Type Documentation

```zig
/// Host from URL Standard §4.2.
///
/// Represents the host component of a URL, which can be:
/// - Domain: DNS domain name (e.g., "example.com")
/// - IPv4: 32-bit address (e.g., 192.168.1.1)
/// - IPv6: 128-bit address (e.g., [2001:db8::1])
/// - Opaque: Non-parseable host string
pub const Host = union(enum) {
    domain: []const u8,
    ipv4: u32,
    ipv6: [8]u16,
    opaque: []const u8,
    
    /// Free host resources.
    pub fn deinit(self: Host, allocator: Allocator) void {
        switch (self) {
            .domain, .opaque => |s| allocator.free(s),
            .ipv4, .ipv6 => {},
        }
    }
};
```

### Private/Temporary Code (Skip Documentation)

```zig
// Private helper - no documentation needed
fn internal_validate(input: []const u8) bool {
    return input.len > 0;
}

/// TEMPORARY MOCK: Fetch Response mock.
/// TODO: Replace with actual src/fetch/ when available.
///
/// This is temporary - detailed documentation not needed.
const MockResponse = struct {
    status: u16,
};
```

---

# Part 5: Common Patterns

## Optional Unwrapping

```zig
// orelse for default values
const value = optional orelse default_value;

// orelse with early return
const value = optional orelse return error.NotFound;

// if with unwrap
if (optional) |value| {
    // Use value
} else {
    // Handle null
}
```

## For Loops

```zig
// Iterate over slice
for (slice) |item| {
    // Process item
}

// Iterate with index
for (slice, 0..) |item, i| {
    // Use item and index
}

// While loop for manual iteration
var i: usize = 0;
while (i < slice.len) : (i += 1) {
    // Use slice[i]
}
```

## Switch Expressions

```zig
const result = switch (value) {
    .variant1 => 10,
    .variant2 => 20,
    .variant3 => 30,
};

// With capture
const string = switch (host) {
    .domain => |d| d,
    .opaque => |o| o,
    else => return error.NotAString,
};
```

## Comptime Generics

```zig
// Generic function
pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        keys: std.ArrayList(K),
        values: std.ArrayList(V),
        allocator: Allocator,
        
        const Self = @This();
        
        pub fn init(allocator: Allocator) Self {
            return .{
                .keys = std.ArrayList(K).init(allocator),
                .values = std.ArrayList(V).init(allocator),
                .allocator = allocator,
            };
        }
    };
}

// Usage
var map = OrderedMap([]const u8, u32).init(allocator);
```

---

# Part 6: Code Organization

## Module Structure

```zig
//! Module-level documentation

// Standard library imports
const std = @import("std");
const Allocator = std.mem.Allocator;

// Cross-spec imports
const infra = @import("infra");
const webidl = @import("webidl");

// Local imports
const parser = @import("parser.zig");
const types = @import("types.zig");

// Public types
pub const URL = struct { ... };
pub const Host = union(enum) { ... };

// Public constants
pub const MAX_LENGTH: usize = 1_000_000;

// Public functions
pub fn parse(...) !URL { ... }

// Private functions
fn helper(...) void { ... }

// Tests (in separate test files, not here)
```

---

# Part 7: Common Mistakes to Avoid

## ❌ Forgetting defer

```zig
// WRONG: Memory leak
var list = std.ArrayList(u8).init(allocator);
try list.append(42);
// Forgot list.deinit()!

// RIGHT:
var list = std.ArrayList(u8).init(allocator);
defer list.deinit();
try list.append(42);
```

## ❌ Wrong Optional Handling

```zig
// WRONG: Crashes if null
const value = optional.?; // Panics if null!

// RIGHT: Handle null case
const value = optional orelse return error.NotFound;
```

## ❌ Not Using Testing Allocator

```zig
// WRONG: Can't detect leaks
test "example" {
    const allocator = std.heap.page_allocator;
    // ...
}

// RIGHT: Detects leaks
test "example" {
    const allocator = std.testing.allocator;
    // ...
}
```

---

# Quick Reference

## Checklist for Every Function

- [ ] Correct naming (snake_case for functions)
- [ ] Allocator parameter if allocates
- [ ] Error union return type
- [ ] defer for cleanup
- [ ] Documentation (if public)
- [ ] Tests (happy path, edge cases, errors, memory)

## Checklist for Every Struct

- [ ] Correct naming (PascalCase)
- [ ] `init` function
- [ ] `deinit` function with proper cleanup
- [ ] Methods use `self: *const` or `self: *`
- [ ] Documentation (if public)
- [ ] Tests for all methods

## Performance Checklist

- [ ] Inline small, hot functions
- [ ] Preallocate when size known
- [ ] Fast path for common cases
- [ ] Minimize allocations
- [ ] Early exit for cheap checks

---

**Remember**: Quality over cleverness. Write explicit, safe, well-tested code. Document public APIs. Performance matters, but correctness comes first.
