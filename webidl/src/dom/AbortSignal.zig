//! AbortSignal interface per WHATWG DOM Standard

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");
const EventTarget = @import("event_target").EventTarget;

/// Algorithm function type for abort handlers
/// Takes the abort reason as parameter
pub const AbortAlgorithm = *const fn (reason: webidl.Exception) void;

/// Event listener removal context for abort signal
/// Stores the target and listener to be removed when signal is aborted
pub const EventListenerRemovalContext = struct {
    target: *EventTarget,
    listener_type: []const u8,
    listener_callback: ?webidl.JSValue,
    listener_capture: bool,
};

/// DOM Spec: interface AbortSignal : EventTarget
pub const AbortSignal = webidl.interface(struct {
    pub const extends = EventTarget;

    allocator: std.mem.Allocator,
    aborted: bool,
    reason: ?webidl.Exception,
    /// [[abortAlgorithms]]: List of algorithms to run when aborted
    /// Spec: https://dom.spec.whatwg.org/#abortsignal-abort-algorithms
    abort_algorithms: infra.List(AbortAlgorithm),
    /// Event listeners to remove when signal is aborted
    /// Spec: Step 6 of "add an event listener" algorithm
    event_listener_removals: std.ArrayList(EventListenerRemovalContext),

    pub fn init(allocator: std.mem.Allocator) !AbortSignal {
        return .{
            .allocator = allocator,
            .aborted = false,
            .reason = null,
            .abort_algorithms = infra.List(AbortAlgorithm).init(allocator),
            .event_listener_removals = std.ArrayList(EventListenerRemovalContext).init(allocator),
        };
    }

    pub fn deinit(self: *AbortSignal) void {
        self.abort_algorithms.deinit();
        self.event_listener_removals.deinit();
        // NOTE: Parent EventTarget cleanup is handled by codegen
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

    /// Add an event listener removal to be performed when signal is aborted
    /// Spec: Step 6 of "add an event listener" - add abort steps to remove the listener
    /// https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener
    pub fn addEventListenerRemoval(self: *AbortSignal, context: EventListenerRemovalContext) !void {
        try self.event_listener_removals.append(context);
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

        // Remove all event listeners registered with this signal
        // Spec: Step 6 of "add an event listener" - remove listener when signal is aborted
        for (self.event_listener_removals.items) |removal| {
            const EventListener = @import("event_target").EventListener;
            const listener = EventListener{
                .type = removal.listener_type,
                .callback = removal.listener_callback,
                .capture = removal.listener_capture,
            };
            removal.target.removeAnEventListener(listener);
        }
        self.event_listener_removals.clearRetainingCapacity();

        // Spec step 3: Fire an event named 'abort' at signal
        // TODO: Implement when event firing infrastructure is available
    }
}, .{
    .exposed = &.{.global},
});
