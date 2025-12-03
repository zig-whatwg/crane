//! Worker Error Handling
//!
//! Spec: HTML Standard § 10.2.5 step 11 (error handling)
//! https://html.spec.whatwg.org/#run-a-worker
//!
//! This module implements error handling for Web Workers:
//! - Uncaught error propagation from worker to main thread
//! - ErrorEvent creation with message, filename, lineno, colno
//! - onerror dispatch on Worker object
//! - Rejected promise handling (unhandledrejection)
//!
//! ## Error Flow
//!
//! 1. Error occurs in worker script
//! 2. Create ErrorEvent with error details
//! 3. Fire "error" event at Worker object (main thread)
//! 4. If not cancelled, report error to console
//! 5. If promise rejection, fire "unhandledrejection" in worker

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const WorkerError = types.WorkerError;

// ============================================================================
// Error Event Data
// ============================================================================

/// ErrorEvent-like data structure for worker errors
///
/// Spec: HTML Standard § 7.2.2 The ErrorEvent interface
/// https://html.spec.whatwg.org/#errorevent
pub const WorkerErrorEvent = struct {
    /// The error message
    message: []const u8,

    /// The filename where the error occurred
    filename: []const u8,

    /// Line number where the error occurred
    lineno: u32,

    /// Column number where the error occurred
    colno: u32,

    /// The actual error value (opaque V8 value)
    error_value: ?*anyopaque,

    /// Whether the error was handled (preventDefault called)
    default_prevented: bool,

    /// Allocator for cleanup
    allocator: Allocator,

    /// Create a new worker error event
    pub fn init(
        allocator: Allocator,
        message: []const u8,
        filename: []const u8,
        lineno: u32,
        colno: u32,
        error_value: ?*anyopaque,
    ) !*WorkerErrorEvent {
        const event = try allocator.create(WorkerErrorEvent);
        errdefer allocator.destroy(event);

        const msg_copy = try allocator.dupe(u8, message);
        errdefer allocator.free(msg_copy);

        const file_copy = try allocator.dupe(u8, filename);
        errdefer allocator.free(file_copy);

        event.* = .{
            .message = msg_copy,
            .filename = file_copy,
            .lineno = lineno,
            .colno = colno,
            .error_value = error_value,
            .default_prevented = false,
            .allocator = allocator,
        };

        return event;
    }

    /// Clean up resources
    pub fn deinit(self: *WorkerErrorEvent) void {
        self.allocator.free(self.message);
        self.allocator.free(self.filename);
        self.allocator.destroy(self);
    }

    /// Mark error as handled (preventDefault)
    pub fn preventDefault(self: *WorkerErrorEvent) void {
        self.default_prevented = true;
    }
};

// ============================================================================
// Promise Rejection Data
// ============================================================================

/// PromiseRejectionEvent-like data for unhandled rejections
///
/// Spec: HTML Standard § 8.1.4.7 Unhandled promise rejections
/// https://html.spec.whatwg.org/#unhandled-promise-rejections
pub const WorkerPromiseRejection = struct {
    /// The rejected promise (opaque V8 value)
    promise: *anyopaque,

    /// The rejection reason (opaque V8 value)
    reason: ?*anyopaque,

    /// Whether this is a "rejectionhandled" (as opposed to "unhandledrejection")
    is_handled: bool,

    /// Allocator for cleanup
    allocator: Allocator,

    /// Create a new promise rejection event
    pub fn init(
        allocator: Allocator,
        promise: *anyopaque,
        reason: ?*anyopaque,
        is_handled: bool,
    ) !*WorkerPromiseRejection {
        const rejection = try allocator.create(WorkerPromiseRejection);
        rejection.* = .{
            .promise = promise,
            .reason = reason,
            .is_handled = is_handled,
            .allocator = allocator,
        };
        return rejection;
    }

    /// Clean up resources
    pub fn deinit(self: *WorkerPromiseRejection) void {
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Error Handler Interface
// ============================================================================

/// Callback for handling worker errors
pub const ErrorHandlerFn = *const fn (event: *WorkerErrorEvent) void;

/// Callback for handling promise rejections
pub const RejectionHandlerFn = *const fn (rejection: *WorkerPromiseRejection) void;

/// Worker error handler configuration
///
/// Set by the Worker object to receive error events from the worker.
pub const WorkerErrorHandler = struct {
    /// Handler for uncaught errors
    on_error: ?ErrorHandlerFn = null,

    /// Handler for unhandled promise rejections
    on_rejection: ?RejectionHandlerFn = null,

    /// Context pointer for the handler (e.g., Worker object)
    context: ?*anyopaque = null,

    /// Fire an error event
    ///
    /// Spec: HTML Standard § 10.2.5 step 11.1
    /// "Queue a task to fire an event named error at worker."
    pub fn fireError(self: *const WorkerErrorHandler, event: *WorkerErrorEvent) void {
        if (self.on_error) |handler| {
            handler(event);
        }
    }

    /// Fire a promise rejection event
    ///
    /// Spec: HTML Standard § 8.1.4.7.1
    /// "Fire an event named unhandledrejection at script's settings object's global object."
    pub fn fireRejection(self: *const WorkerErrorHandler, rejection: *WorkerPromiseRejection) void {
        if (self.on_rejection) |handler| {
            handler(rejection);
        }
    }
};

// ============================================================================
// Error Reporting
// ============================================================================

/// Report an error to the console
///
/// Spec: HTML Standard § 8.1.4.7
/// "Report the error for script."
pub fn reportErrorToConsole(event: *const WorkerErrorEvent) void {
    // In a real implementation, this would call console.error
    // For now, we just log to stderr
    std.debug.print(
        "Uncaught Error in worker {s}:{d}:{d}: {s}\n",
        .{ event.filename, event.lineno, event.colno, event.message },
    );
}

/// Create an error event from an exception
///
/// Parses error information from a JavaScript exception.
pub fn createErrorEventFromException(
    allocator: Allocator,
    message: []const u8,
    source_url: []const u8,
    line: u32,
    column: u32,
    error_obj: ?*anyopaque,
) !*WorkerErrorEvent {
    return WorkerErrorEvent.init(
        allocator,
        message,
        source_url,
        line,
        column,
        error_obj,
    );
}

// ============================================================================
// Termination Cleanup
// ============================================================================

/// Resource cleanup callback
pub const CleanupFn = *const fn (resource: *anyopaque) void;

/// Resource entry for cleanup tracking
pub const CleanupResource = struct {
    resource: *anyopaque,
    cleanup_fn: CleanupFn,
};

/// Termination cleanup manager
///
/// Tracks resources that need cleanup when a worker terminates.
/// Resources are cleaned up in LIFO order.
pub const TerminationCleanup = struct {
    /// Resources to clean up
    resources: std.ArrayListUnmanaged(CleanupResource),

    /// Allocator
    allocator: Allocator,

    /// Initialize cleanup manager
    pub fn init(allocator: Allocator) TerminationCleanup {
        return .{
            .resources = .{},
            .allocator = allocator,
        };
    }

    /// Free all resources and the manager
    pub fn deinit(self: *TerminationCleanup) void {
        // Don't run cleanup here - that's done in performCleanup
        self.resources.deinit(self.allocator);
    }

    /// Register a resource for cleanup on termination
    pub fn register(
        self: *TerminationCleanup,
        resource: *anyopaque,
        cleanup_fn: CleanupFn,
    ) !void {
        try self.resources.append(self.allocator, .{
            .resource = resource,
            .cleanup_fn = cleanup_fn,
        });
    }

    /// Unregister a resource (if it was cleaned up early)
    pub fn unregister(self: *TerminationCleanup, resource: *anyopaque) void {
        var i: usize = 0;
        while (i < self.resources.items.len) {
            if (self.resources.items[i].resource == resource) {
                _ = self.resources.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Perform all cleanup (called on termination)
    ///
    /// Cleans up resources in LIFO order to handle dependencies.
    pub fn performCleanup(self: *TerminationCleanup) void {
        // Clean up in reverse order (LIFO)
        while (self.resources.items.len > 0) {
            const entry = self.resources.pop();
            if (entry) |e| {
                e.cleanup_fn(e.resource);
            }
        }
    }

    /// Number of registered resources
    pub fn count(self: *const TerminationCleanup) usize {
        return self.resources.items.len;
    }
};

// ============================================================================
// Worker Termination State
// ============================================================================

/// Termination state for a worker
pub const TerminationState = enum {
    /// Worker is running normally
    running,

    /// Worker is closing gracefully (close() called)
    /// Current task will complete, then worker stops
    closing,

    /// Worker is being terminated (terminate() called)
    /// Abort current script execution immediately
    terminating,

    /// Worker has been terminated
    terminated,
};

/// Check if a termination state allows new tasks
pub fn canAcceptTasks(state: TerminationState) bool {
    return state == .running;
}

/// Check if a termination state allows current task to continue
pub fn canContinueExecution(state: TerminationState) bool {
    return state == .running or state == .closing;
}

// ============================================================================
// Tests
// ============================================================================

test "WorkerErrorEvent - creation and cleanup" {
    const allocator = std.testing.allocator;

    const event = try WorkerErrorEvent.init(
        allocator,
        "Test error message",
        "worker.js",
        42,
        10,
        null,
    );
    defer event.deinit();

    try std.testing.expectEqualStrings("Test error message", event.message);
    try std.testing.expectEqualStrings("worker.js", event.filename);
    try std.testing.expectEqual(@as(u32, 42), event.lineno);
    try std.testing.expectEqual(@as(u32, 10), event.colno);
    try std.testing.expect(!event.default_prevented);
}

test "WorkerErrorEvent - preventDefault" {
    const allocator = std.testing.allocator;

    const event = try WorkerErrorEvent.init(
        allocator,
        "Error",
        "test.js",
        1,
        1,
        null,
    );
    defer event.deinit();

    try std.testing.expect(!event.default_prevented);
    event.preventDefault();
    try std.testing.expect(event.default_prevented);
}

test "TerminationCleanup - register and cleanup" {
    const allocator = std.testing.allocator;

    var term_cleanup = TerminationCleanup.init(allocator);
    defer term_cleanup.deinit();

    // Track cleanup calls
    var cleanup_count: usize = 0;
    const CountingCleanup = struct {
        fn doCleanup(resource: *anyopaque) void {
            const count_ptr: *usize = @ptrCast(@alignCast(resource));
            count_ptr.* += 1;
        }
    };

    try term_cleanup.register(@ptrCast(&cleanup_count), CountingCleanup.doCleanup);
    try std.testing.expectEqual(@as(usize, 1), term_cleanup.count());

    term_cleanup.performCleanup();
    try std.testing.expectEqual(@as(usize, 1), cleanup_count);
    try std.testing.expectEqual(@as(usize, 0), term_cleanup.count());
}

test "TerminationCleanup - LIFO order" {
    const allocator = std.testing.allocator;

    var term_cleanup = TerminationCleanup.init(allocator);
    defer term_cleanup.deinit();

    var order = std.ArrayList(usize).init(allocator);
    defer order.deinit();

    const OrderTracker = struct {
        fn makeCleanup(index: usize) CleanupFn {
            return switch (index) {
                0 => struct {
                    fn doCleanup(resource: *anyopaque) void {
                        const list: *std.ArrayList(usize) = @ptrCast(@alignCast(resource));
                        list.append(0) catch {};
                    }
                }.doCleanup,
                1 => struct {
                    fn doCleanup(resource: *anyopaque) void {
                        const list: *std.ArrayList(usize) = @ptrCast(@alignCast(resource));
                        list.append(1) catch {};
                    }
                }.doCleanup,
                else => struct {
                    fn doCleanup(resource: *anyopaque) void {
                        const list: *std.ArrayList(usize) = @ptrCast(@alignCast(resource));
                        list.append(2) catch {};
                    }
                }.doCleanup,
            };
        }
    };

    try term_cleanup.register(@ptrCast(&order), OrderTracker.makeCleanup(0));
    try term_cleanup.register(@ptrCast(&order), OrderTracker.makeCleanup(1));
    try term_cleanup.register(@ptrCast(&order), OrderTracker.makeCleanup(2));

    term_cleanup.performCleanup();

    // Should be cleaned up in reverse order: 2, 1, 0
    try std.testing.expectEqual(@as(usize, 3), order.items.len);
    try std.testing.expectEqual(@as(usize, 2), order.items[0]);
    try std.testing.expectEqual(@as(usize, 1), order.items[1]);
    try std.testing.expectEqual(@as(usize, 0), order.items[2]);
}

test "TerminationState - task acceptance" {
    try std.testing.expect(canAcceptTasks(.running));
    try std.testing.expect(!canAcceptTasks(.closing));
    try std.testing.expect(!canAcceptTasks(.terminating));
    try std.testing.expect(!canAcceptTasks(.terminated));
}

test "TerminationState - execution continuation" {
    try std.testing.expect(canContinueExecution(.running));
    try std.testing.expect(canContinueExecution(.closing));
    try std.testing.expect(!canContinueExecution(.terminating));
    try std.testing.expect(!canContinueExecution(.terminated));
}
