# Dependency Mocking Skill

## Purpose

This skill provides guidance on creating temporary mocks for unimplemented WHATWG spec dependencies, enabling development to continue while waiting for full implementations.

---

## When to Use This Skill

Load this skill automatically when:
- A required spec dependency isn't implemented yet
- Need to unblock development while waiting for dependency
- Creating stub implementations for testing
- Prototyping cross-spec interactions
- Building minimal viable implementations

---

## Core Principle: Temporary and Clearly Marked

**ALL mocks MUST be clearly marked as temporary** with:
1. **TEMPORARY MOCK** marker in documentation
2. **TODO** with replacement instructions
3. **Scope limitation** - what the mock does and doesn't do
4. **bd issue** tracking when the real implementation should replace the mock

❌ **NEVER** create unmarked mocks that could be mistaken for real implementations.

---

## Mock Documentation Template

**Every mock MUST use this documentation pattern:**

```zig
/// TEMPORARY MOCK: This is a mock implementation of [SpecName].
/// TODO: Replace with actual implementation from src/[spec_name]/ when available.
/// Issue: bd-[N] tracks implementation of real [SpecName].
/// 
/// This mock implements just enough of [SpecName] to unblock [CurrentSpec].
/// It does NOT fully implement the WHATWG [SpecName] specification.
///
/// ## What This Mock Provides
/// - [Feature 1]: [Minimal description]
/// - [Feature 2]: [Minimal description]
///
/// ## What This Mock Does NOT Provide
/// - [Missing feature 1]
/// - [Missing feature 2]
/// - Full spec compliance
///
/// ## When to Replace
/// Replace this mock when src/[spec_name]/ is implemented.
pub const Mock[SpecName] = struct {
    // Minimal implementation
};
```

---

## Mock Creation Workflow

### Step 1: Identify the Need

**You need a mock when:**
- Spec algorithm references another spec: "Let url be the result of parsing..."
- Import fails: `@import("fetch")` → compile error
- Feature depends on unimplemented spec

### Step 2: Determine Scope

**Ask:**
1. What specific functionality do I need from the dependency?
2. What's the minimum I can implement to unblock my work?
3. What can I defer until the real implementation?

**Example:**
- Need: Parse basic URLs for testing Fetch
- Minimum: Parse scheme and host only
- Defer: Full URL parsing with all edge cases

### Step 3: Create the Mock

**Location:** In the same file or in a `mocks/` subdirectory

**Pattern:**
```zig
// At the top of your file
/// TEMPORARY MOCK: [Full documentation as shown above]
const MockDependency = struct {
    // Minimal implementation
};

// Use the mock
const dep = MockDependency{};
const result = dep.someFunction();
```

### Step 4: Track Replacement

**Create bd issue:**
```bash
bd create "Implement [SpecName] to replace mock in [CurrentSpec]" \
  -t feature \
  -p 2 \
  --deps discovered-from:bd-[current-issue] \
  --json
```

---

## Mock Patterns

### Pattern 1: Minimal Type Mock

**Use when:** You need a type to exist but don't need much functionality.

```zig
/// TEMPORARY MOCK: Minimal URL type.
/// TODO: Replace with actual src/url/URL when available.
/// 
/// This mock provides just enough to store a URL string.
/// It does NOT implement URL parsing, serialization, or validation.
pub const MockURL = struct {
    raw: []const u8,
    
    pub fn init(raw: []const u8) MockURL {
        return .{ .raw = raw };
    }
    
    /// Mock parse - just stores the input string.
    /// Real implementation would parse into components.
    pub fn parse(allocator: Allocator, input: []const u8) !MockURL {
        const owned = try allocator.dupe(u8, input);
        return .{ .raw = owned };
    }
    
    pub fn deinit(self: *MockURL, allocator: Allocator) void {
        allocator.free(self.raw);
    }
};
```

### Pattern 2: Stub Function Mock

**Use when:** You need a function to exist but can return dummy data.

```zig
/// TEMPORARY MOCK: Fetch API stub.
/// TODO: Replace with actual src/fetch/ implementation when available.
/// 
/// This mock always returns a 200 OK response with empty body.
/// It does NOT perform actual network requests or handle errors.
pub const MockFetch = struct {
    /// Mock fetch - always returns 200 OK.
    /// Real implementation would perform HTTP request.
    pub fn fetch(allocator: Allocator, url: []const u8) !Response {
        _ = allocator;
        _ = url;
        
        return Response{
            .status = 200,
            .body = &[_]u8{},
        };
    }
};
```

### Pattern 3: Pass-Through Mock

**Use when:** You need to satisfy an interface but can just pass data through.

```zig
/// TEMPORARY MOCK: Transform stream mock.
/// TODO: Replace with actual src/streams/TransformStream when available.
/// 
/// This mock implements identity transform (input = output).
/// It does NOT implement queuing, backpressure, or error handling.
pub const MockTransformStream = struct {
    pub fn transform(input: []const u8) ![]const u8 {
        // Identity transform - just return input unchanged
        return input;
    }
};
```

### Pattern 4: Simplified Algorithm Mock

**Use when:** You need basic algorithm behavior without full spec compliance.

```zig
/// TEMPORARY MOCK: Simplified host parser.
/// TODO: Replace with actual src/url/host_parser.zig when available.
/// 
/// This mock handles only simple domain names.
/// It does NOT handle IPv4, IPv6, or international domain names.
pub const MockHostParser = struct {
    pub fn parse(allocator: Allocator, input: []const u8) !Host {
        // Simplified: just treat everything as a domain
        const domain = try allocator.dupe(u8, input);
        return Host{ .domain = domain };
    }
};

pub const Host = union(enum) {
    domain: []const u8,
    // Real implementation would also have:
    // ipv4: u32,
    // ipv6: [8]u16,
    // opaque: []const u8,
};
```

---

## Mock Testing

**Mocks should have minimal tests** to verify basic functionality:

```zig
test "MockURL - basic usage" {
    const allocator = std.testing.allocator;
    
    var url = try MockURL.parse(allocator, "https://example.com");
    defer url.deinit(allocator);
    
    // Test that mock stores the input
    try std.testing.expectEqualStrings("https://example.com", url.raw);
    
    // NOTE: Real URL implementation would test parsing into components
}
```

**Don't write extensive tests for mocks** - they'll be replaced anyway.

---

## Mock Replacement Workflow

### When Real Implementation Becomes Available

1. **Find all mock usages:**
```bash
rg "MockURL" src/
rg "TEMPORARY MOCK" src/
```

2. **Replace imports:**
```zig
// Before
const MockURL = @import("mocks.zig").MockURL;

// After
const URL = @import("url").URL;
```

3. **Update usage:**
```zig
// Before
const url = try MockURL.parse(allocator, input);

// After
const url = try URL.parse(allocator, input);
```

4. **Remove mock:**
```zig
// Delete mock definition
// Delete mock tests
```

5. **Run tests:**
```bash
zig build test
```

6. **Close bd issue:**
```bash
bd close bd-[N] --reason "Replaced with real implementation" --json
```

---

## Examples by Spec

### Example 1: Mocking Fetch for Streams

**Context:** Implementing Streams, need Fetch for testing pipe operations.

```zig
/// TEMPORARY MOCK: Fetch Response for Streams testing.
/// TODO: Replace with actual src/fetch/Response.zig when available.
/// Issue: bd-42 tracks implementation of Fetch Standard.
/// 
/// This mock provides a Response with a ReadableStream body.
/// It does NOT implement headers, status codes, or network I/O.
///
/// ## What This Mock Provides
/// - Response type with body field
/// - Basic construction
///
/// ## What This Mock Does NOT Provide
/// - HTTP headers
/// - Status code handling
/// - Actual network requests
/// - Response metadata
pub const MockResponse = struct {
    body: *ReadableStream,
    
    pub fn init(body: *ReadableStream) MockResponse {
        return .{ .body = body };
    }
};
```

### Example 2: Mocking DOM for Fetch

**Context:** Implementing Fetch, need minimal DOM types.

```zig
/// TEMPORARY MOCK: DOM Blob for Fetch testing.
/// TODO: Replace with actual src/dom/Blob.zig when available.
/// Issue: bd-87 tracks implementation of DOM Standard.
/// 
/// This mock provides a Blob that wraps a byte array.
/// It does NOT implement slicing, type, or size properties.
pub const MockBlob = struct {
    data: []const u8,
    
    pub fn init(data: []const u8) MockBlob {
        return .{ .data = data };
    }
    
    /// Mock: Returns the raw data.
    /// Real Blob would handle slicing, MIME type, etc.
    pub fn arrayBuffer(self: MockBlob) []const u8 {
        return self.data;
    }
};
```

### Example 3: Mocking Encoding for URL

**Context:** Implementing URL, need basic UTF-8 validation.

```zig
/// TEMPORARY MOCK: UTF-8 validation for URL parsing.
/// TODO: Replace with actual src/encoding/ when available.
/// Issue: bd-15 tracks implementation of Encoding Standard.
/// 
/// This mock uses std.unicode for UTF-8 validation.
/// It does NOT implement full Encoding Standard algorithms.
pub const MockEncoding = struct {
    /// Mock: Validate UTF-8.
    /// Real implementation would handle all encoding algorithms.
    pub fn validateUtf8(bytes: []const u8) bool {
        return std.unicode.utf8ValidateSlice(bytes);
    }
};
```

---

## Anti-Patterns (Avoid These)

### ❌ Unmarked Mock

```zig
// BAD: No indication this is a mock!
pub const URL = struct {
    raw: []const u8,
    
    pub fn parse(allocator: Allocator, input: []const u8) !URL {
        return .{ .raw = try allocator.dupe(u8, input) };
    }
};
```

**Problem:** Someone might think this is the real implementation.

### ❌ Over-Implemented Mock

```zig
// BAD: Mock is too complex!
pub const MockURL = struct {
    scheme: []const u8,
    host: Host,
    port: ?u16,
    path: [][]const u8,
    // ... (100 lines of parsing logic)
};
```

**Problem:** If you're implementing this much, just implement the real thing!

### ❌ Mock Without Scope

```zig
/// Mock URL type.
pub const MockURL = struct {
    // ...
};
```

**Problem:** No indication of what it does/doesn't do, when to replace it.

---

## Best Practices

1. **Mark clearly** - TEMPORARY MOCK in docs, always
2. **Minimize scope** - Only implement what you absolutely need
3. **Track replacement** - Create bd issue to replace mock
4. **Document limitations** - Be explicit about what's NOT implemented
5. **Test minimally** - Don't waste time testing temporary code
6. **Replace promptly** - When real implementation is available, replace immediately
7. **Never commit long-term mocks** - Mocks are always temporary

---

## Quick Reference

### Mock Documentation Template

```zig
/// TEMPORARY MOCK: This is a mock implementation of [SpecName].
/// TODO: Replace with actual implementation from src/[spec_name]/ when available.
/// Issue: bd-[N] tracks implementation of real [SpecName].
/// 
/// This mock implements just enough of [SpecName] to unblock [CurrentSpec].
/// It does NOT fully implement the WHATWG [SpecName] specification.
///
/// ## What This Mock Provides
/// - [Feature 1]
/// - [Feature 2]
///
/// ## What This Mock Does NOT Provide
/// - [Missing feature 1]
/// - [Missing feature 2]
///
/// ## When to Replace
/// Replace this mock when src/[spec_name]/ is implemented.
pub const Mock[Type] = struct {
    // Minimal implementation
};
```

### Finding Mocks to Replace

```bash
# Find all mocks in codebase
rg "TEMPORARY MOCK" src/

# Find specific mock
rg "MockURL" src/

# Check for bd issues tracking mock replacement
bd list --json | grep "replace mock"
```

---

**Remember**: Mocks are temporary. Mark them clearly, implement minimally, track replacement, and delete promptly when real implementation is available.
