//! AbortSignal interface per WHATWG DOM Standard

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");
const EventTarget = @import("event_target").EventTarget;

/// Algorithm function type for abort handlers
/// Takes the abort reason as parameter
pub const AbortAlgorithm = *const fn (reason: webidl.Exception) void;

pub const AbortSignal = webidl.interface(struct {
    allocator: std.mem.Allocator,
    event_target: EventTarget,
    aborted: bool,
    reason: ?webidl.Exception,
    /// [[abortAlgorithms]]: List of algorithms to run when aborted
    /// Spec: https://dom.spec.whatwg.org/#abortsignal-abort-algorithms
    abort_algorithms: infra.List(AbortAlgorithm),

    pub fn init(allocator: std.mem.Allocator) !AbortSignal {
        return .{
            .allocator = allocator,
            .event_target = try EventTarget.init(allocator),
            .aborted = false,
            .reason = null,
            .abort_algorithms = infra.List(AbortAlgorithm).init(allocator),
        };
    }

    pub fn deinit(self: *AbortSignal) void {
        self.event_target.deinit();
        self.abort_algorithms.deinit();
    }

    pub fn get_aborted(self: *const AbortSignal) bool {
        return self.aborted;
    }

    pub fn get_reason(self: *const AbortSignal) ?webidl.Exception {
        return self.reason;
    }

    pub fn call_throwIfAborted(self: *const AbortSignal) !void {
        if (self.aborted) {
            return error.Aborted;
        }
    }

    /// Add an algorithm to be run when signal is aborted
    /// Spec: https://dom.spec.whatwg.org/#abortsignal-add
    pub fn addAlgorithm(self: *AbortSignal, algorithm: AbortAlgorithm) !void {
        try self.abort_algorithms.append(algorithm);
    }

    /// Remove an algorithm from abort algorithms
    /// Spec: https://dom.spec.whatwg.org/#abortsignal-remove
    pub fn removeAlgorithm(self: *AbortSignal, algorithm: AbortAlgorithm) void {
        var i: usize = 0;
        while (i < self.abort_algorithms.len) {
            if (self.abort_algorithms.get(i) == algorithm) {
                self.abort_algorithms.remove(i) catch return;
                return;
            }
            i += 1;
        }
    }

    /// Signal abort algorithm
    /// Spec: https://dom.spec.whatwg.org/#abortsignal-signal-abort
    ///
    /// Simplified implementation for Streams spec compliance.
    /// TODO: Full DOM compliance requires:
    /// - Dependent signals support
    /// - Event firing with proper event loop integration
    /// - Task queuing for cross-realm scenarios
    pub fn signalAbort(self: *AbortSignal, opt_reason: ?webidl.Exception) void {
        // Spec step 1: If signal is aborted, then return
        if (self.aborted) return;

        // Spec step 2: Set signal's abort reason
        self.reason = opt_reason orelse webidl.Exception{ .simple = .{ .type = .TypeError, .message = "AbortError" } };

        // Mark as aborted
        self.aborted = true;

        // Spec step 5: Run the abort steps for signal
        self.runAbortSteps();

        // TODO: Spec step 3-4, 6: Handle dependent signals (not needed for basic Streams support)
        // TODO: Fire 'abort' event (requires full event loop integration)
    }

    /// Run the abort steps for an AbortSignal
    /// Spec: https://dom.spec.whatwg.org/#abortsignal-run-abort-steps
    fn runAbortSteps(self: *AbortSignal) void {
        // Spec step 1: For each algorithm of signal's abort algorithms: run algorithm
        const reason = self.reason orelse webidl.Exception{ .simple = .{ .type = .TypeError, .message = "AbortError" } };
        for (0..self.abort_algorithms.len) |i| {
            const algorithm = self.abort_algorithms.get(i) orelse continue;
            algorithm(reason);
        }

        // Spec step 2: Empty signal's abort algorithms
        self.abort_algorithms.clear();

        // Spec step 3: Fire an event named 'abort' at signal
        // TODO: Implement when event firing infrastructure is available
    }
}, .{
    .exposed = &.{.global},
});
