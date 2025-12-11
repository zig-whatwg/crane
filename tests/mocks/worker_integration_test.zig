//! ⚠️ DEPRECATED: ScriptEvaluator Test Utility Tests
//!
//! This file contains tests for ScriptEvaluator, a test utility for
//! simulating script evaluation with configurable failures.
//!
//! For tests using real WebIDL worker implementations, see:
//!   tests/html/workers/webidl_integration_test.zig
//!
//! The previous mock tests (WorkerGlobalScope, WorkerLocation, etc.)
//! have been deprecated. Use real implementations from:
//! - src/webidl/interfaces/WorkerGlobalScope.zig
//! - src/webidl/interfaces/WorkerLocation.zig
//! - src/webidl/interfaces/WorkerNavigator.zig
//! - src/webidl/interfaces/MessagePort.zig
//!

const std = @import("std");
const mocks = @import("../../src/mocks/root.zig");

const ScriptEvaluator = mocks.ScriptEvaluator;
const EvaluationResult = mocks.EvaluationResult;

// =============================================================================
// ScriptEvaluator Tests (Test Utility)
// =============================================================================

test "ScriptEvaluator with configured failures" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    // Configure specific failures
    try evaluator.configureFetchFailure("https://example.com/404.js", "Not found");
    try evaluator.configureThrowError("https://example.com/error.js", "SyntaxError");

    // Good script succeeds
    const good_result = try evaluator.evaluateScript("https://example.com/good.js", .classic);
    try std.testing.expectEqual(EvaluationResult.success, good_result);

    // 404 script fails with fetch error
    const fetch_result = try evaluator.evaluateScript("https://example.com/404.js", .classic);
    switch (fetch_result) {
        .fetch_error => {},
        else => return error.ExpectedFetchError,
    }

    // Error script fails with thrown error
    const error_result = try evaluator.evaluateScript("https://example.com/error.js", .module);
    switch (error_result) {
        .error_thrown => {},
        else => return error.ExpectedErrorThrown,
    }
}

test "ScriptEvaluator tracks evaluated scripts" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    // Evaluate some scripts
    _ = try evaluator.evaluateScript("https://example.com/script1.js", .classic);
    _ = try evaluator.evaluateScript("https://example.com/script2.js", .module);

    // Verify tracking
    try std.testing.expect(evaluator.hasEvaluated("https://example.com/script1.js"));
    try std.testing.expect(evaluator.hasEvaluated("https://example.com/script2.js"));
    try std.testing.expect(!evaluator.hasEvaluated("https://example.com/script3.js"));
}

test "ScriptEvaluator reset clears state" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    // Configure and evaluate
    try evaluator.configureFetchFailure("https://example.com/404.js", "Not found");
    _ = try evaluator.evaluateScript("https://example.com/script.js", .classic);

    // Verify state exists
    try std.testing.expect(evaluator.hasEvaluated("https://example.com/script.js"));

    // Reset
    evaluator.reset();

    // Verify state cleared
    try std.testing.expect(!evaluator.hasEvaluated("https://example.com/script.js"));

    // Previously failing script should now succeed (failures cleared)
    const result = try evaluator.evaluateScript("https://example.com/404.js", .classic);
    try std.testing.expectEqual(EvaluationResult.success, result);
}
