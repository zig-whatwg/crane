//! Mock Runtime for Testing
//!
//! This provides a simple mock implementation of RuntimeInterface for testing
//! console functionality without a real JavaScript engine.

const std = @import("std");
const console = @import("console");
const webidl = @import("webidl");

const Allocator = std.mem.Allocator;
const RuntimeInterface = console.types.RuntimeInterface;
const VTable = console.types.VTable;
const StackFrame = console.types.StackFrame;

/// Mock runtime context for testing.
pub const MockRuntimeContext = struct {
    allocator: Allocator,

    /// Optional captured stack trace for testing
    test_stack: ?[]StackFrame = null,

    /// Optional test data for object introspection
    test_object_keys: ?[][]const u8 = null,
    test_array_length: ?u32 = null,

    /// Optional test data for DOM operations
    test_is_dom_node: bool = false,
    test_dom_html: ?[]const u8 = null,
};

/// Create a mock runtime interface for testing.
pub fn createMockRuntime(allocator: Allocator) !*RuntimeInterface {
    const context = try allocator.create(MockRuntimeContext);
    context.* = .{
        .allocator = allocator,
    };

    const runtime = try allocator.create(RuntimeInterface);
    runtime.* = .{
        .vtable = &mock_vtable,
        .context = @ptrCast(context),
    };

    return runtime;
}

/// Destroy mock runtime and free resources.
pub fn destroyMockRuntime(runtime: *RuntimeInterface, allocator: Allocator) void {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(runtime.context));

    // Free test stack if it was set
    if (context.test_stack) |stack| {
        for (stack) |frame| {
            if (frame.function_name) |name| allocator.free(name);
            if (frame.file_name) |file| allocator.free(file);
        }
        allocator.free(stack);
    }

    allocator.destroy(context);
    allocator.destroy(runtime);
}

// ============================================================================
// VTable Implementation
// ============================================================================

const mock_vtable = VTable{
    .isArray = mockIsArray,
    .isObject = mockIsObject,
    .isSymbol = mockIsSymbol,
    .toString = mockToString,
    .toInteger = mockToInteger,
    .toFloat = mockToFloat,
    .getProperty = mockGetProperty,
    .getKeys = mockGetKeys,
    .getLength = mockGetLength,
    .captureStackTrace = mockCaptureStackTrace,
    .isDOMNode = mockIsDOMNode,
    .toDOMString = mockToDOMString,
};

// ============================================================================
// Type Checking
// ============================================================================

fn mockIsArray(_: *anyopaque, value: webidl.JSValue) bool {
    // Simple mock: arrays are not supported in basic JSValue
    _ = value;
    return false;
}

fn mockIsObject(_: *anyopaque, value: webidl.JSValue) bool {
    // For mock purposes, null and undefined are not objects
    return switch (value) {
        .null, .undefined => false,
        else => false, // Simple JSValue doesn't have object type
    };
}

fn mockIsSymbol(_: *anyopaque, value: webidl.JSValue) bool {
    // Simple mock: symbols are not supported in basic JSValue
    _ = value;
    return false;
}

// ============================================================================
// Type Conversion
// ============================================================================

fn mockToString(
    ctx: *anyopaque,
    value: webidl.JSValue,
    allocator: Allocator,
) anyerror![]const u8 {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(ctx));
    _ = context;

    return switch (value) {
        .string => |s| try allocator.dupe(u8, s),
        .number => |n| try std.fmt.allocPrint(allocator, "{d}", .{n}),
        .boolean => |b| try allocator.dupe(u8, if (b) "true" else "false"),
        .null => try allocator.dupe(u8, "null"),
        .undefined => try allocator.dupe(u8, "undefined"),
        .object => try allocator.dupe(u8, "[object Object]"),
    };
}

fn mockToInteger(
    _: *anyopaque,
    value: webidl.JSValue,
) anyerror!i32 {
    return switch (value) {
        .string => |s| std.fmt.parseInt(i32, s, 10) catch 0,
        .number => |n| @intFromFloat(n),
        .boolean => |b| if (b) @as(i32, 1) else @as(i32, 0),
        .null => 0,
        .undefined => 0,
        .object => 0,
    };
}

fn mockToFloat(
    _: *anyopaque,
    value: webidl.JSValue,
) anyerror!f64 {
    return switch (value) {
        .string => |s| std.fmt.parseFloat(f64, s) catch std.math.nan(f64),
        .number => |n| n,
        .boolean => |b| if (b) 1.0 else 0.0,
        .null => 0.0,
        .undefined => std.math.nan(f64),
        .object => std.math.nan(f64),
    };
}

// ============================================================================
// Object Introspection (Not Implemented - Return Defaults)
// ============================================================================

fn mockGetProperty(
    _: *anyopaque,
    _: webidl.JSValue,
    _: []const u8,
    _: std.mem.Allocator,
) anyerror!?webidl.JSValue {
    // Not implemented in mock - return null
    return null;
}

fn mockGetKeys(
    ctx: *anyopaque,
    value: webidl.JSValue,
    allocator: Allocator,
) anyerror![][]const u8 {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(ctx));

    // If test keys were set, return a copy of them
    if (context.test_object_keys) |test_keys| {
        const keys = try allocator.alloc([]const u8, test_keys.len);
        for (test_keys, 0..) |key, i| {
            keys[i] = try allocator.dupe(u8, key);
        }
        return keys;
    }

    // Otherwise return empty for non-objects
    _ = value;
    return try allocator.alloc([]const u8, 0);
}

fn mockGetLength(
    ctx: *anyopaque,
    _: webidl.JSValue,
) anyerror!u32 {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(ctx));

    // If test length was set, return it
    if (context.test_array_length) |length| {
        return length;
    }

    // Otherwise return 0
    return 0;
}

// ============================================================================
// Stack Traces
// ============================================================================

fn mockCaptureStackTrace(
    ctx: *anyopaque,
    allocator: Allocator,
) anyerror![]StackFrame {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(ctx));

    // If test stack was set, return a copy of it
    if (context.test_stack) |test_stack| {
        const frames = try allocator.alloc(StackFrame, test_stack.len);
        for (test_stack, 0..) |frame, i| {
            frames[i] = .{
                .function_name = if (frame.function_name) |name|
                    try allocator.dupe(u8, name)
                else
                    null,
                .file_name = if (frame.file_name) |file|
                    try allocator.dupe(u8, file)
                else
                    null,
                .line_number = frame.line_number,
                .column_number = frame.column_number,
            };
        }
        return frames;
    }

    // Otherwise return a default test stack
    const frames = try allocator.alloc(StackFrame, 2);
    frames[0] = .{
        .function_name = try allocator.dupe(u8, "testFunction"),
        .file_name = try allocator.dupe(u8, "test.js"),
        .line_number = 42,
        .column_number = 10,
    };
    frames[1] = .{
        .function_name = try allocator.dupe(u8, "main"),
        .file_name = try allocator.dupe(u8, "main.js"),
        .line_number = 15,
        .column_number = 5,
    };

    return frames;
}

// ============================================================================
// DOM Operations (Optional - for console.dirxml)
// ============================================================================

fn mockIsDOMNode(
    ctx: *anyopaque,
    value: webidl.JSValue,
) bool {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(ctx));

    // For mock purposes, check if test_is_dom_node flag is set
    // In real implementation, this would check the actual DOM node type
    _ = value;
    return context.test_is_dom_node;
}

fn mockToDOMString(
    ctx: *anyopaque,
    node: webidl.JSValue,
    allocator: Allocator,
) anyerror![]const u8 {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(ctx));

    // If test DOM HTML was set, return a copy of it
    if (context.test_dom_html) |html| {
        return try allocator.dupe(u8, html);
    }

    // Otherwise, return a simple HTML representation based on the value
    return switch (node) {
        .string => |s| try std.fmt.allocPrint(allocator, "<div>{s}</div>", .{s}),
        else => try allocator.dupe(u8, "<unknown />"),
    };
}

// ============================================================================
// Helper Functions for Tests
// ============================================================================

/// Set a custom stack trace for testing console.trace().
pub fn setTestStack(runtime: *RuntimeInterface, stack: []StackFrame) void {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(runtime.context));
    context.test_stack = stack;
}

/// Set test object keys for testing console.table().
pub fn setTestObjectKeys(runtime: *RuntimeInterface, keys: [][]const u8) void {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(runtime.context));
    context.test_object_keys = keys;
}

/// Set test array length for testing console.table().
pub fn setTestArrayLength(runtime: *RuntimeInterface, length: u32) void {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(runtime.context));
    context.test_array_length = length;
}

/// Set test DOM node flag for testing console.dirxml().
pub fn setTestDOMNode(runtime: *RuntimeInterface, is_dom_node: bool) void {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(runtime.context));
    context.test_is_dom_node = is_dom_node;
}

/// Set test DOM HTML string for testing console.dirxml().
pub fn setTestDOMHTML(runtime: *RuntimeInterface, html: []const u8) void {
    const context: *MockRuntimeContext = @ptrCast(@alignCast(runtime.context));
    context.test_dom_html = html;
}

// ============================================================================
// Tests
// ============================================================================

test "MockRuntime - create and destroy" {
    const allocator = std.testing.allocator;

    const runtime = try createMockRuntime(allocator);
    defer destroyMockRuntime(runtime, allocator);

    try std.testing.expect(runtime.vtable != null);
}

test "MockRuntime - toString conversions" {
    const allocator = std.testing.allocator;

    const runtime = try createMockRuntime(allocator);
    defer destroyMockRuntime(runtime, allocator);

    const test_cases = [_]struct {
        value: webidl.JSValue,
        expected: []const u8,
    }{
        .{ .value = .{ .string = "hello" }, .expected = "hello" },
        .{ .value = .{ .number = 42.5 }, .expected = "42.5" },
        .{ .value = .{ .boolean = true }, .expected = "true" },
        .{ .value = .{ .boolean = false }, .expected = "false" },
        .{ .value = .null, .expected = "null" },
        .{ .value = .undefined, .expected = "undefined" },
    };

    for (test_cases) |case| {
        const result = try runtime.vtable.toString(runtime.context, case.value, allocator);
        defer allocator.free(result);

        try std.testing.expectEqualStrings(case.expected, result);
    }
}

test "MockRuntime - toInteger conversions" {
    const allocator = std.testing.allocator;

    const runtime = try createMockRuntime(allocator);
    defer destroyMockRuntime(runtime, allocator);

    const test_cases = [_]struct {
        value: webidl.JSValue,
        expected: i32,
    }{
        .{ .value = .{ .string = "42" }, .expected = 42 },
        .{ .value = .{ .string = "-10" }, .expected = -10 },
        .{ .value = .{ .string = "not-a-number" }, .expected = 0 },
        .{ .value = .{ .number = 42.9 }, .expected = 42 },
        .{ .value = .{ .boolean = true }, .expected = 1 },
        .{ .value = .{ .boolean = false }, .expected = 0 },
        .{ .value = .null, .expected = 0 },
        .{ .value = .undefined, .expected = 0 },
    };

    for (test_cases) |case| {
        const result = try runtime.vtable.toInteger(runtime.context, case.value);
        try std.testing.expectEqual(case.expected, result);
    }
}

test "MockRuntime - toFloat conversions" {
    const allocator = std.testing.allocator;

    const runtime = try createMockRuntime(allocator);
    defer destroyMockRuntime(runtime, allocator);

    const test_cases = [_]struct {
        value: webidl.JSValue,
        expected: f64,
    }{
        .{ .value = .{ .string = "42.5" }, .expected = 42.5 },
        .{ .value = .{ .number = 3.14159 }, .expected = 3.14159 },
        .{ .value = .{ .boolean = true }, .expected = 1.0 },
        .{ .value = .{ .boolean = false }, .expected = 0.0 },
        .{ .value = .null, .expected = 0.0 },
    };

    for (test_cases) |case| {
        const result = try runtime.vtable.toFloat(runtime.context, case.value);
        try std.testing.expectApproxEqRel(case.expected, result, 0.0001);
    }

    // Test NaN cases separately
    const nan_cases = [_]webidl.JSValue{
        .{ .string = "not-a-number" },
        .undefined,
    };

    for (nan_cases) |value| {
        const result = try runtime.vtable.toFloat(runtime.context, value);
        try std.testing.expect(std.math.isNan(result));
    }
}

test "MockRuntime - captureStackTrace" {
    const allocator = std.testing.allocator;

    const runtime = try createMockRuntime(allocator);
    defer destroyMockRuntime(runtime, allocator);

    const frames = try runtime.vtable.captureStackTrace(runtime.context, allocator);
    defer {
        for (frames) |frame| {
            if (frame.function_name) |name| allocator.free(name);
            if (frame.file_name) |file| allocator.free(file);
        }
        allocator.free(frames);
    }

    try std.testing.expectEqual(@as(usize, 2), frames.len);
    try std.testing.expectEqualStrings("testFunction", frames[0].function_name.?);
    try std.testing.expectEqualStrings("test.js", frames[0].file_name.?);
    try std.testing.expectEqual(@as(u32, 42), frames[0].line_number);
}
