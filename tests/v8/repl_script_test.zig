//! `engine.evaluateReplScript` [repl_mode] on V8: console input in REPL mode,
//! through the agent's own inspector session (protocol_repl.zig).
//!
//! What the operation promises, pinned here:
//! - the completion value reaches `fulfilled`, at a checkpoint of the agent,
//!   never inside the call (V8 answers from a promise job);
//! - REPL mode: a `let` declared again, top-level await;
//! - a completion value that is a promise is handed over as the promise,
//!   never adopted;
//! - what the input throws reaches `rejected` - a SyntaxError inside the
//!   call, anything else at a checkpoint;
//! - input that ends too soon answers `.incomplete` and runs no step - one
//!   case per V8 message the adapter matches ("Unexpected end of input",
//!   "Unterminated template literal");
//! - exactly one step: `dropped` when the realm ends first, once.
//!
//! The values are made as the binding makes them: the source is the UTF-8 a
//! console reads (non-ASCII included), the realms are page realms
//! (createWindowRealm / destroyWindowRealm) of an agent createAgent made (the
//! session is the agent's: test_process.TestAgent), and every value is read
//! back through the protocol's own conversions.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const window_agent_hooks: protocol.HostHooks = .{};

var test_isolate: ?*ffi.Isolate = null;
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
}

fn agent() !*ffi.Isolate {
    const i = try test_agent.open(.{ .hooks = &window_agent_hooks });
    if (test_isolate == null) {
        _ = try v8.context_manager.getOrCreate(test_agent.context.?, std.heap.page_allocator);
        test_isolate = i;
    }
    return test_isolate.?;
}

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

fn windowRealm() !runtime.Context {
    const isolate = try agent();
    return protocol.createWindowRealm(&.{
        .agent = @ptrCast(isolate),
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .global_this = .new_window_proxy,
        .parent = null,
        .create_global_object = WindowHost.createGlobalObject,
        .host = null,
    });
}

/// One evaluation's host data: which steps ran, and the value, kept.
const Outcome = struct {
    realm: runtime.Context,
    fulfilled: usize = 0,
    rejected: usize = 0,
    dropped: usize = 0,
    value: ?protocol.Owned = null,

    fn onFulfilled(data: ?*anyopaque, value: runtime.JSValue) void {
        const self: *Outcome = @ptrCast(@alignCast(data.?));
        self.fulfilled += 1;
        self.value = protocol.retainValue(self.realm, value) catch null;
    }

    fn onRejected(data: ?*anyopaque, reason: runtime.JSValue) void {
        const self: *Outcome = @ptrCast(@alignCast(data.?));
        self.rejected += 1;
        self.value = protocol.retainValue(self.realm, reason) catch null;
    }

    fn onDropped(data: ?*anyopaque) void {
        const self: *Outcome = @ptrCast(@alignCast(data.?));
        self.dropped += 1;
    }

    const steps: protocol.PromiseReactionSteps = .{ .fulfilled = onFulfilled, .rejected = onRejected, .dropped = onDropped };

    fn total(self: Outcome) usize {
        return self.fulfilled + self.rejected + self.dropped;
    }

    fn deinit(self: *Outcome) void {
        if (self.value) |v| v.release();
        self.value = null;
    }

    /// The kept value, ToString'd. OWNED by the testing allocator.
    fn text(self: *Outcome) ![]u8 {
        return protocol.convertToDOMString(self.realm, self.value.?.value, std.testing.allocator);
    }
};

/// Evaluate `source` in `w`, run the agent's checkpoint, and expect it to
/// have completed: its value, ToString'd.
fn completes(w: runtime.Context, source: []const u8) ![]u8 {
    var outcome: Outcome = .{ .realm = w };
    defer outcome.deinit();
    try std.testing.expectEqual(protocol.ReplInput.evaluating, try protocol.evaluateReplScript(w, source, &Outcome.steps, &outcome));
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 1), outcome.fulfilled);
    try std.testing.expectEqual(@as(usize, 1), outcome.total());
    return outcome.text();
}

fn expectCompletes(w: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try completes(w, source);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

test "the completion value reaches fulfilled at the agent's next checkpoint, never inside the call" {
    if (comptime protocol.capabilities.repl_mode == .unsupported) return error.SkipZigTest;
    defer test_agent.close();
    const w = try windowRealm();
    defer protocol.destroyWindowRealm(w, .global_detached);
    var outcome: Outcome = .{ .realm = w };
    defer outcome.deinit();
    try std.testing.expectEqual(protocol.ReplInput.evaluating, try protocol.evaluateReplScript(w, "1 + 1", &Outcome.steps, &outcome));
    try std.testing.expectEqual(@as(usize, 0), outcome.total());
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 1), outcome.fulfilled);
    try std.testing.expectEqual(@as(f64, 2), try protocol.convertToUnrestrictedDouble(w, outcome.value.?.value));
    // Once.
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 1), outcome.total());
}

test "REPL mode: let declared again, and top-level await" {
    if (comptime protocol.capabilities.repl_mode == .unsupported) return error.SkipZigTest;
    defer test_agent.close();
    const w = try windowRealm();
    defer protocol.destroyWindowRealm(w, .global_detached);
    try expectCompletes(w, "let a = 1", "undefined");
    try expectCompletes(w, "let a = 2", "undefined");
    try expectCompletes(w, "a", "2");
    try expectCompletes(w, "await Promise.resolve(5)", "5");
    try expectCompletes(w, "const {b} = await Promise.resolve({b: 'x'}); b", "x");
    // A declaration is the realm's binding, not a property the console put
    // on the global object.
    try expectCompletes(w, "Object.hasOwn(globalThis, 'a') + ',' + Object.keys(globalThis).filter(k => k.startsWith('__')).length", "false,0");
}

test "values the console reads: UTF-8 source, a BigInt, -0 and NaN" {
    if (comptime protocol.capabilities.repl_mode == .unsupported) return error.SkipZigTest;
    defer test_agent.close();
    const w = try windowRealm();
    defer protocol.destroyWindowRealm(w, .global_detached);
    try expectCompletes(w, "'é😀\\u{1}'.length", "4");
    try expectCompletes(w, "'é😀'", "é😀");
    try expectCompletes(w, "12345678901234567890n", "12345678901234567890");
    try expectCompletes(w, "NaN", "NaN");
    try expectCompletes(w, "-Infinity", "-Infinity");
    try expectCompletes(w, "null", "null");
    var outcome: Outcome = .{ .realm = w };
    defer outcome.deinit();
    _ = try protocol.evaluateReplScript(w, "-0", &Outcome.steps, &outcome);
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    const zero = try protocol.convertToUnrestrictedDouble(w, outcome.value.?.value);
    try std.testing.expect(zero == 0 and std.math.signbit(zero));
    try std.testing.expectEqual(protocol.ValueType.bigint, blk: {
        var big: Outcome = .{ .realm = w };
        defer big.deinit();
        _ = try protocol.evaluateReplScript(w, "1n", &Outcome.steps, &big);
        try protocol.performMicrotaskCheckpoint(w.agent.?);
        break :blk protocol.typeOf(w, big.value.?.value);
    });
}

/// Steps that count a reaction to the completion value.
const Reacted = struct {
    count: usize = 0,
    fn onFulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Reacted = @ptrCast(@alignCast(data.?));
        self.count += 1;
    }
    const steps: protocol.PromiseReactionSteps = .{ .fulfilled = onFulfilled };
};

test "a completion value that is a promise is handed over as the promise, never adopted" {
    if (comptime protocol.capabilities.repl_mode == .unsupported) return error.SkipZigTest;
    defer test_agent.close();
    const w = try windowRealm();
    defer protocol.destroyWindowRealm(w, .global_detached);
    var outcome: Outcome = .{ .realm = w };
    defer outcome.deinit();
    _ = try protocol.evaluateReplScript(w, "Promise.resolve(1)", &Outcome.steps, &outcome);
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 1), outcome.fulfilled);
    // A promise: "react to" accepts it (it rejects anything else with a
    // TypeError).
    var reacted: Reacted = .{};
    try protocol.reactToPromise(w, outcome.value.?.value, &Reacted.steps, &reacted);
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 1), reacted.count);

    // A thenable is not called.
    try expectCompletes(w, "globalThis.called = false; ({ then() { globalThis.called = true; } })", "[object Object]");
    try expectCompletes(w, "called", "false");
}

test "what the input throws reaches rejected: a SyntaxError inside the call, a throw at the checkpoint" {
    if (comptime protocol.capabilities.repl_mode == .unsupported) return error.SkipZigTest;
    defer test_agent.close();
    const w = try windowRealm();
    defer protocol.destroyWindowRealm(w, .global_detached);

    var syntax: Outcome = .{ .realm = w };
    defer syntax.deinit();
    try std.testing.expectEqual(protocol.ReplInput.evaluating, try protocol.evaluateReplScript(w, "1 +* 2", &Outcome.steps, &syntax));
    try std.testing.expectEqual(@as(usize, 1), syntax.rejected);
    const syntax_text = try syntax.text();
    defer std.testing.allocator.free(syntax_text);
    try std.testing.expect(std.mem.startsWith(u8, syntax_text, "SyntaxError: "));

    var thrown: Outcome = .{ .realm = w };
    defer thrown.deinit();
    _ = try protocol.evaluateReplScript(w, "throw new TypeError('t')", &Outcome.steps, &thrown);
    try std.testing.expectEqual(@as(usize, 0), thrown.total());
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 1), thrown.rejected);
    const thrown_text = try thrown.text();
    defer std.testing.allocator.free(thrown_text);
    try std.testing.expectEqualStrings("TypeError: t", thrown_text);

    var rejected: Outcome = .{ .realm = w };
    defer rejected.deinit();
    _ = try protocol.evaluateReplScript(w, "await Promise.reject(7)", &Outcome.steps, &rejected);
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 1), rejected.rejected);
    try std.testing.expectEqual(@as(f64, 7), try protocol.convertToUnrestrictedDouble(w, rejected.value.?.value));
}

test "input that ends too soon is incomplete - one case per V8 message matched - and runs no step" {
    if (comptime protocol.capabilities.repl_mode == .unsupported) return error.SkipZigTest;
    defer test_agent.close();
    const w = try windowRealm();
    defer protocol.destroyWindowRealm(w, .global_detached);
    // "Unexpected end of input".
    const unexpected_end = [_][]const u8{ "function f() {", "[1, 2", "foo(1,", "if (x)", "let s = 1 +" };
    // "Unterminated template literal".
    const unterminated_template = [_][]const u8{ "`a", "`a\n${1}" };
    inline for (.{ &unexpected_end, &unterminated_template }) |inputs| {
        for (inputs) |input| {
            var outcome: Outcome = .{ .realm = w };
            defer outcome.deinit();
            try std.testing.expectEqual(protocol.ReplInput.incomplete, try protocol.evaluateReplScript(w, input, &Outcome.steps, &outcome));
            try protocol.performMicrotaskCheckpoint(w.agent.?);
            try std.testing.expectEqual(@as(usize, 0), outcome.total());
        }
    }
    // A SyntaxError of another kind is not "read another line".
    var other: Outcome = .{ .realm = w };
    defer other.deinit();
    try std.testing.expectEqual(protocol.ReplInput.evaluating, try protocol.evaluateReplScript(w, "'unterminated", &Outcome.steps, &other));
    try std.testing.expectEqual(@as(usize, 1), other.rejected);
    // The completed input runs whole.
    try expectCompletes(w, "function f() {\nreturn 41 + 1 }\nf()", "42");
}

test "an evaluation waiting when its realm ends is dropped, exactly once" {
    if (comptime protocol.capabilities.repl_mode == .unsupported) return error.SkipZigTest;
    defer test_agent.close();
    const w = try windowRealm();
    var outcome: Outcome = .{ .realm = w };
    defer outcome.deinit();
    try std.testing.expectEqual(protocol.ReplInput.evaluating, try protocol.evaluateReplScript(w, "await new Promise(() => {})", &Outcome.steps, &outcome));
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 0), outcome.total());
    protocol.destroyWindowRealm(w, .global_detached);
    try std.testing.expectEqual(@as(usize, 1), outcome.dropped);
    try std.testing.expectEqual(@as(usize, 1), outcome.total());
    const isolate = try agent();
    ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    try std.testing.expectEqual(@as(usize, 1), outcome.total());
}

test "two realms of one agent share its session, each its own bindings" {
    if (comptime protocol.capabilities.repl_mode == .unsupported) return error.SkipZigTest;
    defer test_agent.close();
    const first = try windowRealm();
    defer protocol.destroyWindowRealm(first, .global_detached);
    const second = try windowRealm();
    defer protocol.destroyWindowRealm(second, .global_detached);
    try expectCompletes(first, "let where = 'first'", "undefined");
    try expectCompletes(second, "let where = 'second'", "undefined");
    try expectCompletes(first, "where", "first");
    try expectCompletes(second, "where", "second");
}
