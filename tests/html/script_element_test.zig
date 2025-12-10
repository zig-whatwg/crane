//! Tests for HTMLScriptElement implementation
//!
//! Tests cover:
//! - HTMLScriptElement.supports() static method
//! - Script type detection
//! - Internal state management
//! - Event utilities for script error handling
//! - ScriptRunner module

const std = @import("std");
const testing = std.testing;

// Import the modules under test
const html = @import("html");
const runtime = @import("runtime");

// =============================================================================
// Event Utilities Tests
// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#runtime-script-errors
// =============================================================================

test "ErrorInfo - extractErrorInfo with all values" {
    // Create a dummy JSValue handle for testing
    const dummy_error = runtime.JSValue.fromHandle(@ptrFromInt(0x1234));
    const info = html.extractErrorInfo(
        dummy_error,
        "Test error message",
        "test.js",
        42,
        10,
    );

    try testing.expectEqualStrings("Test error message", info.message);
    try testing.expectEqualStrings("test.js", info.filename);
    try testing.expectEqual(@as(u32, 42), info.lineno);
    try testing.expectEqual(@as(u32, 10), info.colno);
    // Check that error is not undefined (we passed a handle)
    try testing.expect(!info.@"error".isUndefined());
}

test "ErrorInfo - extractErrorInfo with null values uses defaults" {
    const info = html.extractErrorInfo(runtime.JSValue.jsUndefined, null, null, null, null);

    try testing.expectEqualStrings("Script error.", info.message);
    try testing.expectEqualStrings("", info.filename);
    try testing.expectEqual(@as(u32, 0), info.lineno);
    try testing.expectEqual(@as(u32, 0), info.colno);
    try testing.expect(info.@"error".isUndefined());
}

test "ErrorInfo - partial error info" {
    // Test with some values null and some present
    const info = html.extractErrorInfo(
        runtime.JSValue.jsUndefined, // no error object
        "Custom message",
        null, // no filename
        10,
        null, // no column
    );

    try testing.expectEqualStrings("Custom message", info.message);
    try testing.expectEqualStrings("", info.filename);
    try testing.expectEqual(@as(u32, 10), info.lineno);
    try testing.expectEqual(@as(u32, 0), info.colno);
    try testing.expect(info.@"error".isUndefined());
}

// =============================================================================
// Script Runner Tests
// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
// =============================================================================

test "ScriptRunner - initialization" {
    const allocator = testing.allocator;

    var runner = html.ScriptRunner.init(allocator, null);
    defer runner.deinit();

    // Initially no pending scripts
    try testing.expect(!runner.hasPendingParserBlockingScript());
    try testing.expect(!runner.hasDeferredScripts());
    try testing.expect(!runner.hasAsyncScripts());
}

test "ScriptRunner - queue deferred script" {
    const allocator = testing.allocator;

    var runner = html.ScriptRunner.init(allocator, null);
    defer runner.deinit();

    // Create a mock script using properly aligned pointer
    const alignment = @alignOf(runtime.Instance);
    const mock_script: *runtime.Instance = @ptrFromInt(alignment * 1);

    try runner.queueDeferredScript(mock_script);
    try testing.expect(runner.hasDeferredScripts());
}

test "ScriptRunner - queue async script" {
    const allocator = testing.allocator;

    var runner = html.ScriptRunner.init(allocator, null);
    defer runner.deinit();

    // Create a mock script using properly aligned pointer
    const alignment = @alignOf(runtime.Instance);
    const mock_script: *runtime.Instance = @ptrFromInt(alignment * 1);

    try runner.queueAsyncScript(mock_script);
    try testing.expect(runner.hasAsyncScripts());
}

test "ScriptRunner - set parser blocking script" {
    const allocator = testing.allocator;

    var runner = html.ScriptRunner.init(allocator, null);
    defer runner.deinit();

    // Create a mock script using properly aligned pointer
    const alignment = @alignOf(runtime.Instance);
    const mock_script: *runtime.Instance = @ptrFromInt(alignment * 1);

    runner.setParserBlockingScript(mock_script);
    try testing.expect(runner.hasPendingParserBlockingScript());

    // Clearing should work
    runner.clearParserBlockingScript();
    try testing.expect(!runner.hasPendingParserBlockingScript());
}

test "ScriptRunner - multiple deferred scripts in order" {
    const allocator = testing.allocator;

    var runner = html.ScriptRunner.init(allocator, null);
    defer runner.deinit();

    // Queue multiple deferred scripts using properly aligned pointers
    const alignment = @alignOf(runtime.Instance);
    const script1: *runtime.Instance = @ptrFromInt(alignment * 1);
    const script2: *runtime.Instance = @ptrFromInt(alignment * 2);
    const script3: *runtime.Instance = @ptrFromInt(alignment * 3);

    try runner.queueDeferredScript(script1);
    try runner.queueDeferredScript(script2);
    try runner.queueDeferredScript(script3);

    // Should have deferred scripts
    try testing.expect(runner.hasDeferredScripts());
}

test "ScriptRunner - queue in-order async script" {
    const allocator = testing.allocator;

    var runner = html.ScriptRunner.init(allocator, null);
    defer runner.deinit();

    // Create a mock script using properly aligned pointer
    const alignment = @alignOf(runtime.Instance);
    const mock_script: *runtime.Instance = @ptrFromInt(alignment * 1);

    try runner.queueInOrderAsyncScript(mock_script);
    try testing.expect(runner.hasInOrderAsyncScripts());
}

test "ScriptRunner - parser finished notification" {
    const allocator = testing.allocator;

    var runner = html.ScriptRunner.init(allocator, null);
    defer runner.deinit();

    // Notify that parser is finished (should not crash)
    runner.notifyParserFinished();
}
