//! WHATWG Fetch Standard - Fetch Controller
//!
//! Fetch controller enables callers to perform operations on a fetch after it starts.
//!
//! Spec: https://fetch.spec.whatwg.org/#fetch-controller

const std = @import("std");
const Allocator = std.mem.Allocator;
const fetch_timing = @import("fetch_timing.zig");
const FetchTimingInfo = fetch_timing.FetchTimingInfo;

// =============================================================================
// Fetch Controller
// =============================================================================

/// Fetch controller enables callers to perform operations on a fetch after it starts.
///
/// Spec: https://fetch.spec.whatwg.org/#fetch-controller
pub const FetchController = struct {
    allocator: Allocator,

    /// Controller state.
    /// Spec: "A fetch controller has an associated state (default 'ongoing')."
    state: State = .ongoing,

    /// Full timing info (set when fetch completes).
    /// Spec: "A fetch controller has an associated full timing info (default null)."
    full_timing_info: ?*FetchTimingInfo = null,

    /// Report timing steps callback.
    /// Spec: "A fetch controller has an associated report timing steps
    /// which is an algorithm accepting a global object."
    report_timing_steps: ?ReportTimingStepsFn = null,
    report_timing_context: ?*anyopaque = null,

    /// Serialized abort reason.
    /// Spec: "A fetch controller has an associated serialized abort reason,
    /// which is the result of StructuredSerialize, or null (default null)."
    serialized_abort_reason: ?[]const u8 = null,
    owns_abort_reason: bool = false,

    /// Next manual redirect steps callback.
    /// Spec: "A fetch controller has an associated next manual redirect steps,
    /// which is an algorithm returning nothing."
    next_manual_redirect_steps: ?NextManualRedirectStepsFn = null,

    const Self = @This();

    /// Controller state enum.
    pub const State = enum {
        /// Fetch is in progress.
        ongoing,
        /// Fetch was terminated (e.g., navigation away).
        terminated,
        /// Fetch was aborted (e.g., AbortController.abort()).
        aborted,
    };

    /// Report timing steps callback type.
    pub const ReportTimingStepsFn = *const fn (global: *anyopaque, context: ?*anyopaque) void;

    /// Next manual redirect steps callback type.
    pub const NextManualRedirectStepsFn = *const fn () void;

    /// Initialize a new fetch controller.
    pub fn init(allocator: Allocator) !*Self {
        const controller = try allocator.create(Self);
        controller.* = .{
            .allocator = allocator,
        };
        return controller;
    }

    /// Deinitialize the fetch controller.
    pub fn deinit(self: *Self) void {
        // Free owned abort reason
        if (self.owns_abort_reason) {
            if (self.serialized_abort_reason) |reason| {
                self.allocator.free(reason);
            }
        }
        self.allocator.destroy(self);
    }

    /// Report timing for this fetch controller given a global object.
    ///
    /// Spec: "To report timing for a fetch controller controller given a global object global:
    /// 1. Assert: controller's report timing steps is not null.
    /// 2. Call controller's report timing steps with global."
    pub fn reportTiming(self: *Self, global: *anyopaque) void {
        std.debug.assert(self.report_timing_steps != null);
        if (self.report_timing_steps) |steps| {
            steps(global, self.report_timing_context);
        }
    }

    /// Process the next manual redirect for this fetch controller.
    ///
    /// Spec: "To process the next manual redirect for a fetch controller controller:
    /// 1. Assert: controller's next manual redirect steps is not null.
    /// 2. Call controller's next manual redirect steps."
    pub fn processNextManualRedirect(self: *Self) void {
        std.debug.assert(self.next_manual_redirect_steps != null);
        if (self.next_manual_redirect_steps) |steps| {
            steps();
        }
    }

    /// Extract full timing info from this fetch controller.
    ///
    /// Spec: "To extract full timing info given a fetch controller controller:
    /// 1. Assert: controller's full timing info is not null.
    /// 2. Return controller's full timing info."
    pub fn extractFullTimingInfo(self: *Self) *FetchTimingInfo {
        std.debug.assert(self.full_timing_info != null);
        return self.full_timing_info.?;
    }

    /// Abort the fetch controller.
    ///
    /// Spec: "To abort a fetch controller controller with an optional error:
    /// 1. Set controller's state to 'aborted'.
    /// 2. Let fallbackError be an 'AbortError' DOMException.
    /// 3. Set error to fallbackError if it is not given.
    /// 4. Let serializedError be StructuredSerialize(error). If that threw an
    ///    exception, catch it, and set serializedError to StructuredSerialize(fallbackError).
    /// 5. Set controller's serialized abort reason to serializedError."
    ///
    /// Note: We simplify serialization since Zig doesn't have StructuredSerialize.
    /// The abort_reason is stored as-is for now.
    pub fn abort(self: *Self, abort_reason: ?[]const u8) !void {
        // 1. Set state to aborted
        self.state = .aborted;

        // 2-5. Serialize the abort reason
        // For now, we store a copy of the reason or a default
        if (abort_reason) |reason| {
            const owned = try self.allocator.dupe(u8, reason);
            if (self.owns_abort_reason) {
                if (self.serialized_abort_reason) |old| {
                    self.allocator.free(old);
                }
            }
            self.serialized_abort_reason = owned;
            self.owns_abort_reason = true;
        } else {
            // Default: AbortError message
            const default_reason = "The operation was aborted.";
            const owned = try self.allocator.dupe(u8, default_reason);
            if (self.owns_abort_reason) {
                if (self.serialized_abort_reason) |old| {
                    self.allocator.free(old);
                }
            }
            self.serialized_abort_reason = owned;
            self.owns_abort_reason = true;
        }
    }

    /// Terminate the fetch controller.
    ///
    /// Spec: "To terminate a fetch controller controller, set controller's state to 'terminated'."
    pub fn terminate(self: *Self) void {
        self.state = .terminated;
    }

    /// Check if the controller is aborted.
    pub fn isAborted(self: *const Self) bool {
        return self.state == .aborted;
    }

    /// Check if the controller is canceled (aborted or terminated).
    pub fn isCanceled(self: *const Self) bool {
        return self.state == .aborted or self.state == .terminated;
    }
};

// =============================================================================
// Deserialize Abort Reason
// =============================================================================

/// Deserialize a serialized abort reason in a given realm.
///
/// Spec: "To deserialize a serialized abort reason, given a serialized abort reason
/// abortReason and a realm realm:
/// 1. Let fallbackError be an 'AbortError' DOMException.
/// 2. Let deserializedError be fallbackError.
/// 3. If abortReason is non-null, then set deserializedError to
///    StructuredDeserialize(abortReason, realm). If that threw an exception,
///    catch it, and set deserializedError to fallbackError.
/// 4. Return deserializedError."
///
/// Note: In Zig, we return the abort reason bytes or a default.
/// The realm parameter is unused in this simplified implementation.
pub fn deserializeAbortReason(abort_reason: ?[]const u8, _: *anyopaque) []const u8 {
    const fallback = "The operation was aborted.";
    return abort_reason orelse fallback;
}

// =============================================================================
// Tests
// =============================================================================

test "FetchController.init creates ongoing controller" {
    const allocator = std.testing.allocator;

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    try std.testing.expectEqual(FetchController.State.ongoing, controller.state);
    try std.testing.expect(controller.full_timing_info == null);
    try std.testing.expect(controller.serialized_abort_reason == null);
}

test "FetchController.terminate sets state" {
    const allocator = std.testing.allocator;

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    controller.terminate();

    try std.testing.expectEqual(FetchController.State.terminated, controller.state);
    try std.testing.expect(controller.isCanceled());
    try std.testing.expect(!controller.isAborted());
}

test "FetchController.abort sets state and reason" {
    const allocator = std.testing.allocator;

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    try controller.abort("Custom abort reason");

    try std.testing.expectEqual(FetchController.State.aborted, controller.state);
    try std.testing.expect(controller.isAborted());
    try std.testing.expect(controller.isCanceled());
    try std.testing.expectEqualStrings("Custom abort reason", controller.serialized_abort_reason.?);
}

test "FetchController.abort with null uses default reason" {
    const allocator = std.testing.allocator;

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    try controller.abort(null);

    try std.testing.expectEqual(FetchController.State.aborted, controller.state);
    try std.testing.expectEqualStrings("The operation was aborted.", controller.serialized_abort_reason.?);
}

test "FetchController.extractFullTimingInfo" {
    const allocator = std.testing.allocator;

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();

    controller.full_timing_info = &timing;

    const extracted = controller.extractFullTimingInfo();
    try std.testing.expectEqual(&timing, extracted);
}

var report_timing_called = false;

fn testReportTimingSteps(_: *anyopaque, _: ?*anyopaque) void {
    report_timing_called = true;
}

test "FetchController.reportTiming calls callback" {
    const allocator = std.testing.allocator;

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    report_timing_called = false;
    controller.report_timing_steps = testReportTimingSteps;

    var dummy_global: u8 = 0;
    controller.reportTiming(&dummy_global);

    try std.testing.expect(report_timing_called);
}

var manual_redirect_called = false;

fn testManualRedirectSteps() void {
    manual_redirect_called = true;
}

test "FetchController.processNextManualRedirect calls callback" {
    const allocator = std.testing.allocator;

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    manual_redirect_called = false;
    controller.next_manual_redirect_steps = testManualRedirectSteps;

    controller.processNextManualRedirect();

    try std.testing.expect(manual_redirect_called);
}

test "deserializeAbortReason with reason" {
    var dummy_realm: u8 = 0;
    const result = deserializeAbortReason("Custom reason", &dummy_realm);
    try std.testing.expectEqualStrings("Custom reason", result);
}

test "deserializeAbortReason with null returns fallback" {
    var dummy_realm: u8 = 0;
    const result = deserializeAbortReason(null, &dummy_realm);
    try std.testing.expectEqualStrings("The operation was aborted.", result);
}
