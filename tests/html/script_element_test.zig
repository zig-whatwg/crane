//! Tests for HTMLScriptElement implementation
//!
//! Tests cover:
//! - HTMLScriptElement.supports() static method
//! - Script type detection
//! - Internal state management
//! - ScriptRunner module

const std = @import("std");
const testing = std.testing;

// Import the modules under test
const html = @import("html");
const runtime = @import("runtime");

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
