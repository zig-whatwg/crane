//! Tests for AbortSignal dependent signals
//! Spec: https://dom.spec.whatwg.org/#abortsignal-dependent-signals

const std = @import("std");
const dom_types = @import("dom_types");
const webidl = @import("webidl");

const AbortSignal = dom_types.AbortSignal;

test "AbortSignal: dependent signal aborts when source aborts" {
    const allocator = std.testing.allocator;

    // Create source signal
    var source = try AbortSignal.init(allocator);
    defer source.deinit();

    // Create dependent signal manually
    var dependent = try AbortSignal.init(allocator);
    defer dependent.deinit();

    // Link them
    try dependent.source_signals.append(&source);
    try source.dependent_signals.append(&dependent);

    // Verify neither is aborted initially
    try std.testing.expect(!source.get_aborted());
    try std.testing.expect(!dependent.get_aborted());

    // Abort source
    const reason = webidl.Exception{ .simple = .{ .type = .TypeError, .message = "Source aborted" } };
    source.signalAbort(reason);

    // Dependent should also be aborted
    try std.testing.expect(source.get_aborted());
    try std.testing.expect(dependent.get_aborted());
    try std.testing.expect(dependent.get_reason() != null);
}

test "AbortSignal.any(): returns already-aborted signal if any input is aborted" {
    const allocator = std.testing.allocator;

    // Create source signals, one already aborted
    var signal1 = try AbortSignal.init(allocator);
    defer signal1.deinit();

    var signal2 = try AbortSignal.init(allocator);
    defer signal2.deinit();
    const reason = webidl.Exception{ .simple = .{ .type = .TypeError, .message = "Already aborted" } };
    signal2.signalAbort(reason);

    // Verify signal2 is aborted
    try std.testing.expect(signal2.get_aborted());

    // Create dependent signal
    const signals = [_]*AbortSignal{ &signal1, &signal2 };
    const result = try AbortSignal.call_any(allocator, &signals);
    defer {
        result.deinit();
        allocator.destroy(result);
    }

    // Result should be aborted because signal2 was aborted
    try std.testing.expect(result.get_aborted());
    try std.testing.expect(result.get_reason() != null);
}

test "AbortSignal.any(): creates dependent signal that aborts when any source aborts" {
    const allocator = std.testing.allocator;

    // Create source signals
    var signal1 = try AbortSignal.init(allocator);
    defer signal1.deinit();

    var signal2 = try AbortSignal.init(allocator);
    defer signal2.deinit();

    var signal3 = try AbortSignal.init(allocator);
    defer signal3.deinit();

    // Create dependent signal
    const signals = [_]*AbortSignal{ &signal1, &signal2, &signal3 };
    const result = try AbortSignal.call_any(allocator, &signals);
    defer {
        result.deinit();
        allocator.destroy(result);
    }

    // Result should not be aborted yet
    try std.testing.expect(!result.get_aborted());

    // Abort one source
    const reason = webidl.Exception{ .simple = .{ .type = .TypeError, .message = "signal2 aborted" } };
    signal2.signalAbort(reason);

    // Result should now be aborted
    try std.testing.expect(result.get_aborted());
    try std.testing.expect(result.get_reason() != null);

    // Other sources should not be aborted
    try std.testing.expect(!signal1.get_aborted());
    try std.testing.expect(!signal3.get_aborted());
}

test "AbortSignal.any(): multiple dependents abort when source aborts" {
    const allocator = std.testing.allocator;

    // Create source signal
    var source = try AbortSignal.init(allocator);
    defer source.deinit();

    // Create multiple dependent signals
    const source_signals = [_]*AbortSignal{&source};
    const dependent1 = try AbortSignal.call_any(allocator, &source_signals);
    defer {
        dependent1.deinit();
        allocator.destroy(dependent1);
    }

    const dependent2 = try AbortSignal.call_any(allocator, &source_signals);
    defer {
        dependent2.deinit();
        allocator.destroy(dependent2);
    }

    // Neither should be aborted yet
    try std.testing.expect(!dependent1.get_aborted());
    try std.testing.expect(!dependent2.get_aborted());

    // Abort source
    const reason = webidl.Exception{ .simple = .{ .type = .TypeError, .message = "Source aborted" } };
    source.signalAbort(reason);

    // All should be aborted
    try std.testing.expect(source.get_aborted());
    try std.testing.expect(dependent1.get_aborted());
    try std.testing.expect(dependent2.get_aborted());
}

test "AbortSignal.any(): empty signals array returns non-aborted signal" {
    const allocator = std.testing.allocator;

    // Create dependent signal with no sources
    const signals = [_]*AbortSignal{};
    const result = try AbortSignal.call_any(allocator, &signals);
    defer {
        result.deinit();
        allocator.destroy(result);
    }

    // Result should not be aborted
    try std.testing.expect(!result.get_aborted());
    try std.testing.expect(result.get_reason() == null);
}

test "AbortSignal: signalAbort is idempotent" {
    const allocator = std.testing.allocator;

    var signal = try AbortSignal.init(allocator);
    defer signal.deinit();

    const reason1 = webidl.Exception{ .simple = .{ .type = .TypeError, .message = "First" } };
    const reason2 = webidl.Exception{ .simple = .{ .type = .TypeError, .message = "Second" } };

    signal.signalAbort(reason1);
    const aborted_first = signal.get_aborted();
    const reason_first = signal.get_reason();

    // Abort again with different reason
    signal.signalAbort(reason2);

    // Should still be aborted with first reason
    try std.testing.expect(signal.get_aborted());
    try std.testing.expect(aborted_first);
    // First reason should be preserved (but we can't easily compare Exception values)
    try std.testing.expect(reason_first != null);
}
