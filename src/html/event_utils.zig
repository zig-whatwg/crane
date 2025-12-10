//! Event Utility Functions for HTML
//!
//! Spec References:
//! - DOM §2.9.4: https://dom.spec.whatwg.org/#concept-event-fire
//! - HTML §8.1.6.1: https://html.spec.whatwg.org/multipage/webappapis.html#runtime-script-errors
//!
//! This module provides utilities for:
//! - Firing events (DOM "fire an event" algorithm)
//! - Reporting script errors (HTML "report an exception" algorithm)
//! - Creating error events for script failures

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");

// Access to impls module for setting internal state
const impls = @import("impls");

// =============================================================================
// Error Information
// =============================================================================

/// Error information extracted from a JavaScript exception
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#extract-error-information
pub const ErrorInfo = struct {
    /// The error message
    message: []const u8,
    /// The URL of the script where the error occurred
    filename: []const u8,
    /// The line number where the error occurred
    lineno: u32,
    /// The column number where the error occurred
    colno: u32,
    /// The error object as a type-safe JSValue (may be null/undefined)
    /// Using runtime.JSValue provides type safety and lifecycle clarity
    /// for V8 error objects that need to survive HandleScope boundaries.
    @"error": runtime.JSValue,
};

/// Extract error information from a JavaScript value
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#extract-error-information
///
/// To extract error information from a JavaScript value exception:
/// 1. Let attributes be an empty map keyed by IDL attributes.
/// 2. Set attributes[error] to exception.
/// 3. Set attributes[message], attributes[filename], attributes[lineno], and
///    attributes[colno] to implementation-defined values derived from exception.
/// 4. Return attributes.
pub fn extractErrorInfo(
    exception: runtime.JSValue,
    message: ?[]const u8,
    filename: ?[]const u8,
    lineno: ?u32,
    colno: ?u32,
) ErrorInfo {
    return .{
        .message = message orelse "Script error.",
        .filename = filename orelse "",
        .lineno = lineno orelse 0,
        .colno = colno orelse 0,
        .@"error" = exception,
    };
}

/// Legacy helper to extract error info from raw anyopaque pointer
/// Used for gradual migration from *anyopaque to JSValue
pub fn extractErrorInfoFromAnyopaque(
    exception: ?*const anyopaque,
    message: ?[]const u8,
    filename: ?[]const u8,
    lineno: ?u32,
    colno: ?u32,
) ErrorInfo {
    return extractErrorInfo(
        runtime.JSValue.fromAnyopaque(exception),
        message,
        filename,
        lineno,
        colno,
    );
}

// =============================================================================
// Fire an Event
// =============================================================================

/// Fire an event at a target
/// Spec: https://dom.spec.whatwg.org/#concept-event-fire
///
/// To fire an event named e at target, optionally using an eventConstructor,
/// with a description of how IDL attributes are to be initialized, and a
/// legacy target override flag:
///
/// 1. If eventConstructor is not given, then let eventConstructor be Event.
/// 2. Let event be the result of creating an event given eventConstructor,
///    in the relevant realm of target.
/// 3. Initialize event's type attribute to e.
/// 4. Initialize any other IDL attributes of event as described in the
///    invocation of this algorithm.
/// 5. Return the result of dispatching event at target, with legacy target
///    override flag set if set.
///
/// Returns true if the event was NOT cancelled (default action should run).
/// Returns false if the event was cancelled via preventDefault().
pub fn fireEvent(
    allocator: std.mem.Allocator,
    ctx: ?runtime.Context,
    target: *runtime.Instance,
    event_type: []const u8,
    bubbles: bool,
    cancelable: bool,
) !bool {
    // If no context, create a null context for testing
    var ctx_data: runtime.ContextData = undefined;
    const actual_ctx = if (ctx) |c| c else blk: {
        ctx_data = try @import("runtime").createNullContext(allocator);
        break :blk &ctx_data;
    };
    defer if (ctx == null) ctx_data.deinit();

    // Create a basic Event
    const event_init = dictionaries.EventInit{
        .bubbles = bubbles,
        .cancelable = cancelable,
        .composed = false,
    };

    const event = try interfaces.Event.call_constructor(
        actual_ctx,
        runtime.DOMString.initInterned(event_type),
        .{ .was_passed = true, .value = event_init },
    );
    // Ensure event is cleaned up after dispatch
    defer interfaces.Event.deinit(event);

    // Set isTrusted to true (fired by UA, not script)
    impls.Event.setIsTrusted(event, true);

    // Dispatch the event
    return dispatchEvent(allocator, target, event);
}

/// Fire an error event at a target
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception (step 6.2)
///
/// Fire an event named error at global, using ErrorEvent, with the cancelable
/// attribute initialized to true, and additional attributes initialized
/// according to errorInfo.
pub fn fireErrorEvent(
    allocator: std.mem.Allocator,
    ctx: ?runtime.Context,
    target: *runtime.Instance,
    error_info: ErrorInfo,
) !bool {
    // If no context, create a null context for testing
    var ctx_data: runtime.ContextData = undefined;
    const actual_ctx = if (ctx) |c| c else blk: {
        ctx_data = try @import("runtime").createNullContext(allocator);
        break :blk &ctx_data;
    };
    defer if (ctx == null) ctx_data.deinit();

    // Create ErrorEvent with the error information
    // Convert JSValue to raw pointer for the error field
    // The ErrorEvent impl expects ?*const anyopaque for backward compatibility
    const error_ptr: ?*const anyopaque = error_info.@"error".toAnyopaque();

    const event = try impls.ErrorEvent.createErrorEvent(
        allocator,
        actual_ctx,
        error_info.message,
        error_info.filename,
        error_info.lineno,
        error_info.colno,
        error_ptr,
        true, // cancelable = true per spec
    );
    // Ensure event is cleaned up after dispatch
    defer interfaces.ErrorEvent.deinit(event);

    // Set isTrusted to true (fired by UA, not script)
    impls.ErrorEvent.setIsTrusted(event, true);

    // Dispatch the event
    // Per spec: "Returning true in an event handler cancels the event"
    // So we return true if NOT cancelled (event handler returned false or was absent)
    return dispatchEvent(allocator, target, event);
}

/// Fire a simple event (no special attributes)
/// This is a convenience wrapper for common events like "load"
pub fn fireSimpleEvent(
    allocator: std.mem.Allocator,
    ctx: ?runtime.Context,
    target: *runtime.Instance,
    event_type: []const u8,
) !void {
    _ = try fireEvent(allocator, ctx, target, event_type, false, false);
}

// =============================================================================
// Event Dispatch
// =============================================================================

/// Dispatch an event to a target
/// This is a simplified dispatch that doesn't handle full event path propagation.
/// For full implementation, see src/dom/event_dispatch.zig
fn dispatchEvent(
    allocator: std.mem.Allocator,
    target: *runtime.Instance,
    event: *runtime.Instance,
) !bool {
    _ = allocator;

    // Set event's target
    impls.Event.setTarget(event, target);
    impls.Event.setCurrentTarget(event, target);

    // Set dispatch flag
    impls.Event.setDispatchFlag(event, true);

    // Set event phase to AT_TARGET
    impls.Event.setEventPhase(event, interfaces.Event.get_AT_TARGET());

    // TODO: Full event dispatch with event path propagation
    // For now, we're just invoking event listeners on the target directly
    // This is sufficient for script error handling where we fire at the global

    // Invoke event listeners on target
    // This requires integration with EventTarget's listener storage
    // For now, we'll just check if the event was cancelled

    // Unset dispatch flag
    impls.Event.setDispatchFlag(event, false);

    // Reset event phase
    impls.Event.setEventPhase(event, interfaces.Event.get_NONE());

    // Return true if event was NOT cancelled
    return !impls.Event.getCanceledFlag(event);
}

// =============================================================================
// Report Exception
// =============================================================================

/// Report an exception to the global object
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception
///
/// To report an exception exception which is a JavaScript value, for a
/// particular global object global and optional boolean omitError (default false):
///
/// 1. Let notHandled be true.
/// 2. Let errorInfo be the result of extracting error information from exception.
/// 3. Let script be a script found in an implementation-defined way, or null.
/// 4. If script is a classic script and script's muted errors is true, then set
///    errorInfo[error] to null, errorInfo[message] to "Script error.",
///    errorInfo[filename] to the empty string, errorInfo[lineno] to 0, and
///    errorInfo[colno] to 0.
/// 5. If omitError is true, then set errorInfo[error] to null.
/// 6. If global is not in error reporting mode, then:
///    6.1. Set global's in error reporting mode to true.
///    6.2. Fire an event named error at global, using ErrorEvent, with cancelable
///         attribute initialized to true, and additional attributes initialized
///         according to errorInfo.
///    6.3. Set global's in error reporting mode to false.
/// 7. If notHandled is true, report to developer console.
pub fn reportException(
    allocator: std.mem.Allocator,
    ctx: ?runtime.Context,
    global: *runtime.Instance,
    exception: runtime.JSValue,
    message: ?[]const u8,
    filename: ?[]const u8,
    lineno: ?u32,
    colno: ?u32,
    muted_errors: bool,
    omit_error: bool,
) !bool {
    // Step 1: Let notHandled be true
    var not_handled = true;

    // Step 2: Extract error information
    var error_info = extractErrorInfo(exception, message, filename, lineno, colno);

    // Step 4: Handle muted errors (CORS script from different origin)
    if (muted_errors) {
        error_info.@"error" = runtime.JSValue.jsNull;
        error_info.message = "Script error.";
        error_info.filename = "";
        error_info.lineno = 0;
        error_info.colno = 0;
    }

    // Step 5: If omitError is true, set error to null
    if (omit_error) {
        error_info.@"error" = runtime.JSValue.jsNull;
    }

    // Step 6: Fire error event at global (if not in error reporting mode)
    // TODO: Check global's "in error reporting mode" flag
    // For now, assume we're not in error reporting mode

    // Step 6.2: Fire error event
    not_handled = try fireErrorEvent(allocator, ctx, global, error_info);

    // Step 7: If notHandled is true, report to developer console
    if (not_handled) {
        // Log to debug output (developer console equivalent)
        std.debug.print("Uncaught error: {s}\n", .{error_info.message});
        if (error_info.filename.len > 0) {
            std.debug.print("  at {s}:{d}:{d}\n", .{
                error_info.filename,
                error_info.lineno,
                error_info.colno,
            });
        }
    }

    return not_handled;
}

/// Legacy version that accepts raw anyopaque pointer for gradual migration
pub fn reportExceptionFromAnyopaque(
    allocator: std.mem.Allocator,
    ctx: ?runtime.Context,
    global: *runtime.Instance,
    exception: ?*const anyopaque,
    message: ?[]const u8,
    filename: ?[]const u8,
    lineno: ?u32,
    colno: ?u32,
    muted_errors: bool,
    omit_error: bool,
) !bool {
    return reportException(
        allocator,
        ctx,
        global,
        runtime.JSValue.fromAnyopaque(exception),
        message,
        filename,
        lineno,
        colno,
        muted_errors,
        omit_error,
    );
}

// =============================================================================
// Tests
// =============================================================================

test "extractErrorInfo - with all values" {
    var dummy: u8 = 0;
    const dummy_error = runtime.JSValue.fromHandle(&dummy);
    const info = extractErrorInfo(
        dummy_error,
        "Test error message",
        "test.js",
        42,
        10,
    );

    try std.testing.expectEqualStrings("Test error message", info.message);
    try std.testing.expectEqualStrings("test.js", info.filename);
    try std.testing.expectEqual(@as(u32, 42), info.lineno);
    try std.testing.expectEqual(@as(u32, 10), info.colno);
    try std.testing.expect(info.@"error".isHandle());
}

test "extractErrorInfo - with null/undefined values uses defaults" {
    const info = extractErrorInfo(runtime.JSValue.jsNull, null, null, null, null);

    try std.testing.expectEqualStrings("Script error.", info.message);
    try std.testing.expectEqualStrings("", info.filename);
    try std.testing.expectEqual(@as(u32, 0), info.lineno);
    try std.testing.expectEqual(@as(u32, 0), info.colno);
    try std.testing.expect(info.@"error".isNull());
}

test "extractErrorInfoFromAnyopaque - legacy compatibility" {
    const info = extractErrorInfoFromAnyopaque(null, "Legacy error", null, null, null);
    try std.testing.expectEqualStrings("Legacy error", info.message);
    try std.testing.expect(info.@"error".isNull());
}
