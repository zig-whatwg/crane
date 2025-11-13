//! AbortSignal interface per WHATWG DOM Standard

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");
const EventTarget = @import("event_target").EventTarget;
const EventListener = @import("event_target").EventListener;

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
    event_listener_removals: infra.List(EventListenerRemovalContext),
    /// Source signals: weak set of AbortSignals this signal depends on
    /// Spec: https://dom.spec.whatwg.org/#abortsignal-source-signals
    source_signals: infra.List(*AbortSignal),
    /// Dependent signals: weak set of AbortSignals that depend on this signal
    /// Spec: https://dom.spec.whatwg.org/#abortsignal-dependent-signals
    dependent_signals: infra.List(*AbortSignal),

    pub fn init(allocator: std.mem.Allocator) !AbortSignal {
        return .{
            .allocator = allocator,
            .aborted = false,
            .reason = null,
            .abort_algorithms = infra.List(AbortAlgorithm).init(allocator),
            .event_listener_removals = infra.List(EventListenerRemovalContext).init(allocator),
            .source_signals = infra.List(*AbortSignal).init(allocator),
            .dependent_signals = infra.List(*AbortSignal).init(allocator),
        };
    }

    pub fn deinit(self: *AbortSignal) void {
        self.abort_algorithms.deinit();
        self.event_listener_removals.deinit();
        self.source_signals.deinit();
        self.dependent_signals.deinit();
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

    /// AbortSignal.any(signals) - static method
    /// Spec: https://dom.spec.whatwg.org/#dom-abortsignal-any
    /// Returns an AbortSignal that will be aborted when any of the signals are aborted
    pub fn call_any(allocator: std.mem.Allocator, signals: []const *AbortSignal) !*AbortSignal {
        // This calls "create a dependent abort signal" algorithm
        return createDependentAbortSignal(allocator, signals);
    }

    /// Create a dependent abort signal
    /// Spec: https://dom.spec.whatwg.org/#abortsignal-create-a-dependent-abort-signal
    ///
    /// Steps:
    /// 1. Let resultSignal be a new object implementing signalInterface using realm
    /// 2. For each signal of signals:
    ///    - If signal is aborted, then set resultSignal's abort reason to signal's abort reason
    ///    - Otherwise:
    ///      - Append signal to resultSignal's source signals
    ///      - Append resultSignal to signal's dependent signals
    /// 3. Return resultSignal
    fn createDependentAbortSignal(allocator: std.mem.Allocator, signals: []const *AbortSignal) !*AbortSignal {
        // Step 1: Let resultSignal be a new object implementing AbortSignal
        const result_signal = try allocator.create(AbortSignal);
        errdefer allocator.destroy(result_signal);
        result_signal.* = try AbortSignal.init(allocator);

        // Step 2: For each signal of signals
        for (signals) |signal| {
            // If signal is aborted, then set resultSignal's abort reason to signal's abort reason
            if (signal.aborted) {
                result_signal.reason = signal.reason;
                result_signal.aborted = true;
            } else {
                // Otherwise:
                // Append signal to resultSignal's source signals
                try result_signal.source_signals.append(signal);
                // Append resultSignal to signal's dependent signals
                try signal.dependent_signals.append(result_signal);
            }
        }

        // Step 3: Return resultSignal
        return result_signal;
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
    /// Steps:
    /// 1. If signal is aborted, then return
    /// 2. Set signal's abort reason to reason if given, otherwise to new "AbortError" DOMException
    /// 3. Let dependentSignalsToAbort be a new list
    /// 4. For each dependentSignal of signal's dependent signals:
    ///    - If dependentSignal is not aborted:
    ///      - Set dependentSignal's abort reason to signal's abort reason
    ///      - Append dependentSignal to dependentSignalsToAbort
    /// 5. Run the abort steps for signal
    /// 6. For each dependentSignal of dependentSignalsToAbort, run the abort steps for dependentSignal
    ///
    /// TODO: Fire 'abort' event (requires full event loop integration)
    pub fn signalAbort(self: *AbortSignal, opt_reason: ?webidl.Exception) void {
        // Spec step 1: If signal is aborted, then return
        if (self.aborted) return;

        // Spec step 2: Set signal's abort reason
        self.reason = opt_reason orelse webidl.Exception{ .simple = .{ .type = .TypeError, .message = "AbortError" } };

        // Mark as aborted
        self.aborted = true;

        // Spec step 3: Let dependentSignalsToAbort be a new list
        var dependent_signals_to_abort = infra.List(*AbortSignal).init(self.allocator);
        defer dependent_signals_to_abort.deinit();

        // Spec step 4: For each dependentSignal of signal's dependent signals
        for (self.dependent_signals.items()) |dependent_signal| {
            // If dependentSignal is not aborted
            if (!dependent_signal.aborted) {
                // Set dependentSignal's abort reason to signal's abort reason
                dependent_signal.reason = self.reason;
                dependent_signal.aborted = true;
                // Append dependentSignal to dependentSignalsToAbort
                dependent_signals_to_abort.append(dependent_signal) catch continue;
            }
        }

        // Spec step 5: Run the abort steps for signal
        self.runAbortSteps();

        // Spec step 6: For each dependentSignal of dependentSignalsToAbort, run the abort steps
        for (dependent_signals_to_abort.items()) |dependent_signal| {
            dependent_signal.runAbortSteps();
        }
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
        for (self.event_listener_removals.items()) |removal| {
            const listener = EventListener{
                .type = removal.listener_type,
                .callback = removal.listener_callback,
                .capture = removal.listener_capture,
            };
            removal.target.call_removeEventListener(listener.type, listener.callback, listener.capture);
        }
        self.event_listener_removals.clear();

        // Spec step 3: Fire an event named 'abort' at signal
        // TODO: Implement when event firing infrastructure is available
    }
}, .{
    .exposed = &.{.global},
});
