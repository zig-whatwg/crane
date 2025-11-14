//! Basic AbortSignal implementation for Streams
//!
//! This is a simplified AbortSignal for internal use. Full implementation
//! would come from a DOM/Web API library.
//!
//! Spec: https://dom.spec.whatwg.org/#interface-AbortSignal

const std = @import("std");
const infra = @import("infra");

/// Abort event listener callback
pub const AbortListener = *const fn (context: ?*anyopaque) void;

/// Listener entry
const ListenerEntry = struct {
    callback: AbortListener,
    context: ?*anyopaque,
};

/// AbortSignal - signals that an operation should be aborted
///
/// Spec: https://dom.spec.whatwg.org/#interface-AbortSignal
pub const AbortSignal = struct {
    allocator: std.mem.Allocator,
    /// Whether the signal has been aborted
    aborted: bool,
    /// Registered event listeners
    listeners: infra.List(ListenerEntry),

    /// Initialize a new AbortSignal
    pub fn init(allocator: std.mem.Allocator) AbortSignal {
        return .{
            .allocator = allocator,
            .aborted = false,
            .listeners = infra.List(ListenerEntry).init(allocator),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *AbortSignal) void {
        self.listeners.deinit();
    }

    /// Add an abort event listener
    ///
    /// Spec: § 3.4 addEventListener("abort", callback)
    pub fn addEventListener(
        self: *AbortSignal,
        callback: AbortListener,
        context: ?*anyopaque,
    ) !void {
        // If already aborted, call listener immediately
        if (self.aborted) {
            callback(context);
            return;
        }

        try self.listeners.append(.{
            .callback = callback,
            .context = context,
        });
    }

    /// Remove an event listener
    pub fn removeEventListener(
        self: *AbortSignal,
        callback: AbortListener,
        context: ?*anyopaque,
    ) void {
        var i: usize = 0;
        while (i < self.listeners.len) {
            const entry = self.listeners.get(i).?;
            if (entry.callback == callback and entry.context == context) {
                _ = self.listeners.swapRemove(i) catch unreachable;
                return;
            }
            i += 1;
        }
    }

    /// Trigger the abort signal
    ///
    /// Spec: § 3.5 signal abort
    pub fn abort(self: *AbortSignal) void {
        if (self.aborted) return;

        self.aborted = true;

        // Call all listeners
        var i: usize = 0;
        while (i < self.listeners.len) : (i += 1) {
            const entry = self.listeners.get(i).?;
            entry.callback(entry.context);
        }

        // Clear listeners after calling them
        self.listeners.clear();
    }

    /// Check if signal is aborted
    pub fn isAborted(self: *const AbortSignal) bool {
        return self.aborted;
    }
};

/// AbortController - allows aborting an AbortSignal
///
/// Spec: https://dom.spec.whatwg.org/#interface-AbortController
pub const AbortController = struct {
    signal: *AbortSignal,
    allocator: std.mem.Allocator,

    /// Create a new AbortController with its signal
    pub fn init(allocator: std.mem.Allocator) !AbortController {
        const signal = try allocator.create(AbortSignal);
        signal.* = AbortSignal.init(allocator);
        return .{
            .signal = signal,
            .allocator = allocator,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *AbortController) void {
        self.signal.deinit();
        self.allocator.destroy(self.signal);
    }

    /// Abort the associated signal
    pub fn abort(self: *AbortController) void {
        self.signal.abort();
    }
};

// Tests

test "AbortSignal - basic abort" {
    const allocator = std.testing.allocator;

    var signal = AbortSignal.init(allocator);
    defer signal.deinit();

    try std.testing.expect(!signal.isAborted());

    signal.abort();

    try std.testing.expect(signal.isAborted());
}

test "AbortSignal - listener called on abort" {
    const allocator = std.testing.allocator;

    var signal = AbortSignal.init(allocator);
    defer signal.deinit();

    var called = false;

    const listener = struct {
        fn callback(ctx: ?*anyopaque) void {
            const flag: *bool = @ptrCast(@alignCast(ctx.?));
            flag.* = true;
        }
    }.callback;

    try signal.addEventListener(listener, &called);

    try std.testing.expect(!called);

    signal.abort();

    try std.testing.expect(called);
}

test "AbortSignal - listener called immediately if already aborted" {
    const allocator = std.testing.allocator;

    var signal = AbortSignal.init(allocator);
    defer signal.deinit();

    signal.abort();

    var called = false;

    const listener = struct {
        fn callback(ctx: ?*anyopaque) void {
            const flag: *bool = @ptrCast(@alignCast(ctx.?));
            flag.* = true;
        }
    }.callback;

    try signal.addEventListener(listener, &called);

    try std.testing.expect(called);
}

test "AbortSignal - removeEventListener" {
    const allocator = std.testing.allocator;

    var signal = AbortSignal.init(allocator);
    defer signal.deinit();

    var called = false;

    const listener = struct {
        fn callback(ctx: ?*anyopaque) void {
            const flag: *bool = @ptrCast(@alignCast(ctx.?));
            flag.* = true;
        }
    }.callback;

    try signal.addEventListener(listener, &called);
    signal.removeEventListener(listener, &called);

    signal.abort();

    try std.testing.expect(!called);
}

test "AbortController - creates and controls signal" {
    const allocator = std.testing.allocator;

    var controller = try AbortController.init(allocator);
    defer controller.deinit();

    try std.testing.expect(!controller.signal.isAborted());

    controller.abort();

    try std.testing.expect(controller.signal.isAborted());
}
