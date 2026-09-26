//! Runtime script errors: "report an exception".
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception
//!
//! Every place a script's exception escapes to the host - running a classic
//! or module script, an event listener, an event handler, a timer callback -
//! ends here: an ErrorEvent is fired at the global, and `window.onerror`
//! (called with the event's five fields - see EventTarget's event handler
//! processing) can cancel it by returning true.
//!
//! Before this, none of those paths reported anything. Classic scripts fired a
//! fake error event at their own ELEMENT (wrong target, and through a dispatch
//! that invoked no listeners), and everything else dropped the exception on the
//! floor, so a page waiting on `window.onerror` or a window "error" listener
//! waited out the harness timeout.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");
const v8 = @import("v8");
const ffi = v8.ffi;

const log = std.log.scoped(.report_exception);

pub const Options = struct {
    /// The script's muted errors flag (report an exception step 4): a classic
    /// script whose response was CORS-cross-origin reports "Script error."
    /// and nothing else about the exception.
    muted: bool = false,
    /// omitError (step 5): report everything but the exception value.
    omit_error: bool = false,
    /// Error information already extracted by the TryCatch that caught the
    /// exception. For a compile error it carries the position of the syntax
    /// error itself, which re-deriving it from the SyntaxError object cannot
    /// always recover. When absent, it is extracted from `exception`.
    info: ?*const ffi.V8ErrorInfo = null,
};

/// The globals currently "in error reporting mode" (step 6.1). An `onerror`
/// that throws must not re-enter reporting for the same global, which would
/// recurse without end. The set is tiny - reporting only nests across
/// globals, and not deeply - so a fixed array is enough; a global that finds
/// the array full is simply not guarded (the spec's flag cannot overflow, but
/// neither can a real page nest reports eight globals deep).
var reporting: [8]?*runtime.Instance = .{null} ** 8;

fn inErrorReportingMode(global: *runtime.Instance) bool {
    for (reporting) |g| if (g == global) return true;
    return false;
}

fn enterErrorReportingMode(global: *runtime.Instance) ?usize {
    for (&reporting, 0..) |*slot, i| {
        if (slot.* == null) {
            slot.* = global;
            return i;
        }
    }
    return null;
}

/// Report an exception `exception` (a Global<Value>*, borrowed) for `global`.
///
/// Returns notHandled: false when an error handler canceled the event.
pub fn reportException(global: *runtime.Instance, exception: ?*ffi.Value, options: Options) bool {
    // Step 1: Let notHandled be true.
    var not_handled = true;

    const engine_ctx = global.ctx.getEngineContext() orelse return not_handled;
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return not_handled;
    const scope = ffi.v8_HandleScope_New(isolate) orelse return not_handled;
    defer ffi.v8_HandleScope_Dispose(scope);

    // Step 2: Let errorInfo be the result of extracting error information
    // from exception. The spec leaves message, filename, lineno and colno
    // implementation-defined.
    var extracted: ?*ffi.V8ErrorInfo = null;
    defer ffi.v8_FreeErrorInfo(extracted);
    const info: ?*const ffi.V8ErrorInfo = options.info orelse blk: {
        const value = exception orelse break :blk null;
        extracted = ffi.v8_Exception_GetErrorInfo(context, value);
        break :blk extracted;
    };

    var message: []const u8 = "Uncaught exception";
    var filename: []const u8 = "";
    var lineno: u32 = 0;
    var colno: u32 = 0;
    var error_value: ?*ffi.Value = exception;
    if (info) |i| {
        if (i.getMessage()) |m| message = m;
        if (i.getResourceName()) |r| filename = r;
        if (i.line_number > 0) lineno = @intCast(i.line_number);
        // V8 columns are 0-based; ErrorEvent.colno is 1-based in every
        // engine that reports one.
        if (i.column_number >= 0) colno = @intCast(i.column_number + 1);
    }

    // Step 4: muted errors.
    if (options.muted) {
        error_value = null;
        message = "Script error.";
        filename = "";
        lineno = 0;
        colno = 0;
    }

    // Step 5: omitError.
    if (options.omit_error) error_value = null;

    // Step 6: If global is not in error reporting mode, then:
    if (!inErrorReportingMode(global)) {
        // 6.1: Set global's in error reporting mode to true.
        const slot = enterErrorReportingMode(global);
        // 6.3: ...and back to false.
        defer if (slot) |s| {
            reporting[s] = null;
        };

        // 6.2: Set notHandled to the result of firing an event named error
        // at global, using ErrorEvent, cancelable, with errorInfo.
        not_handled = fireErrorEvent(global, message, filename, lineno, colno, error_value);
    }

    // Step 7: If notHandled is true, the user agent may report exception to a
    // developer console. (Dedicated workers forward to their Worker object
    // instead; that path lives with the worker.)
    if (not_handled) log.debug("Uncaught {s} ({s}:{d}:{d})", .{ message, filename, lineno, colno });

    return not_handled;
}

/// Fire an ErrorEvent named "error" at `global`. Returns false when canceled.
fn fireErrorEvent(
    global: *runtime.Instance,
    message: []const u8,
    filename: []const u8,
    lineno: u32,
    colno: u32,
    error_value: ?*ffi.Value,
) bool {
    const ctx = global.ctx;
    const init = dictionaries.ErrorEventInit{
        .base = .{ .bubbles = false, .cancelable = true, .composed = false },
        .message = runtime.DOMString.initInterned(message),
        .filename = filename,
        .lineno = lineno,
        .colno = colno,
        // The event takes its own Global of the value; ours stays the caller's.
        .@"error" = if (error_value) |e| runtime.JSValue.fromHandleNonOwning(e) else runtime.JSValue.jsNull,
    };
    const event = interfaces.ErrorEvent.call_constructor(
        ctx,
        runtime.DOMString.initInterned("error"),
        webidl.Opt(dictionaries.ErrorEventInit).passed(init),
    ) catch |err| {
        log.debug("could not create ErrorEvent: {}", .{err});
        return true;
    };

    const generation = runtime.SlabAllocator.generationOf(event);
    // Fired by the user agent, so trusted (DOM 2.10).
    const not_canceled = @import("dom").fire_event.dispatchTrusted(global, event) catch true;

    // An event no listener ever saw was never wrapped, so V8 holds no
    // reference to it and nothing else will ever free it - including the
    // Global of the exception it keeps. One that was wrapped belongs to the
    // wrapper cache from here on (a handler may have stored it).
    event.releaseIfUnwrapped(generation);
    return not_canceled;
}

/// The Window whose realm `context` (Global<Context>*) is, if any.
pub fn globalForContext(context: *ffi.Context) ?*runtime.Instance {
    return v8.context_manager.getWindowForContext(context);
}

/// Run `body(data)` with V8's automatic microtask checkpoints suppressed.
///
/// "Run a classic script" and "run a module script" report their exception
/// BEFORE "clean up after running script", while the script's realm is still
/// on the execution context stack - so the error handlers' own promise
/// reactions wait for the checkpoint that clean-up performs, instead of
/// running after each handler returns (which V8's auto policy would do, since
/// the handlers are called from native code with nothing else on the stack).
pub fn withMicrotasksSuppressed(body: *const fn (?*anyopaque) callconv(.c) void, data: ?*anyopaque) void {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return body(data);
    ffi.v8_RunWithMicrotasksSuppressed(isolate, body, data);
}
