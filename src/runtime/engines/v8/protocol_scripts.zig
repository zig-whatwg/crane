//! The engine protocol's running of script on V8 (design 4.3, classic
//! scripts): HTML 8.1.4 "calling scripts" - prepare to run script, run a
//! classic script, clean up after running script - and what the host needs
//! around it: a host script's completion value, an event handler content
//! attribute's function, and "extract error information".
//!
//! protocol.zig forwards these operations here. "Check if we can run script"
//! (a Window whose Document is not fully active; scripting disabled) is the
//! host's, before it calls: the engine knows neither.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const realm_entry = @import("realm_entry.zig");
const context_manager = @import("context_manager.zig");
const conversions = @import("conversions.zig");
const support = @import("protocol_support.zig");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Owned = engine.Owned;
const Error = engine.Error;
const Allocator = std.mem.Allocator;

/// The protocol's "prepare to run script" state: the realm entered.
pub const ScriptScope = realm_entry.Entered;

/// How many "prepare to run script"s are open on this thread without their
/// "clean up": each is a realm execution context on HTML's JavaScript
/// execution context stack, whether or not a JavaScript frame runs above it.
threadlocal var prepared_depth: u32 = 0;

/// Whether a "prepare to run script" is open on this thread without its
/// "clean up": a realm execution context on the JavaScript execution context
/// stack (engine.hasRunningScript).
pub fn hasPreparedScript() bool {
    return prepared_depth > 0;
}

// ============================================================================
// Prepare to run script / clean up after running script (HTML 8.1.4.3)
// ============================================================================

/// HTML "prepare to run script" with `realm`'s settings object.
pub fn prepareToRunScript(realm: Context) Error!ScriptScope {
    // 1. Push the realm execution context onto the JavaScript execution
    // context stack: the realm entered - V8's entered context, which is what
    // entryRealm() reads.
    const scope = try support.enter(realm);
    // 2. (The currently running task's script evaluation environment settings
    // object set is the host event loop's; Crane's records none.)
    //
    // The Window whose realm this is is the accessor the impls' cross-origin
    // checks read while its script runs (context_manager's accessor stack).
    if (context_manager.getWindowForContext(scope.context())) |window| context_manager.pushAccessorWindow(window);
    prepared_depth += 1;
    return scope;
}

/// HTML "clean up after running script" with the settings object `scope`
/// prepared.
pub fn cleanUpAfterRunningScript(scope: ScriptScope) void {
    // 1-2. Remove the realm execution context from the stack.
    if (context_manager.getWindowForContext(scope.context()) != null) context_manager.popAccessorWindow();
    prepared_depth -|= 1;
    const isolate = scope.isolate;
    ffi.v8_Context_Exit(scope.scope.context);
    // 3. If the JavaScript execution context stack is now empty - no realm
    // execution context the host pushed, no JavaScript frame - perform a
    // microtask checkpoint. The agent stays entered for it, and the scope's
    // handle scope stays open: an agent the host entered only for this has
    // no other, and the checkpoint's callbacks make handles.
    if (prepared_depth == 0 and !ffi.v8_Isolate_HasJavaScriptOnStack(isolate)) {
        ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    }
    ffi.v8_HandleScope_Dispose(scope.scope.handle_scope);
    if (scope.entered_isolate) ffi.v8_Isolate_Exit(isolate);
}

// ============================================================================
// Reporting
// ============================================================================

/// `info` - what V8 caught - as HTML "extract error information" gives it.
/// Every field is BORROWED from `info`.
fn protocolErrorInfo(info: *const ffi.V8ErrorInfo, realm: ?Context) engine.ErrorInfo {
    return .{
        .message = info.getMessage() orelse "Uncaught exception",
        .filename = info.getResourceName() orelse "",
        .lineno = if (info.line_number > 0) @intCast(info.line_number) else 0,
        // V8 counts columns from 0; ErrorEvent.colno counts from 1.
        .colno = if (info.column_number >= 0) @intCast(info.column_number + 1) else 0,
        .error_value = if (info.exception) |exception| .{ .handle = .{ .ptr = exception } } else JSValue.jsUndefined,
        .realm = realm,
    };
}

const PendingReport = struct {
    info: engine.ErrorInfo,
    reporter: engine.Reporter,

    fn run(data: ?*anyopaque) callconv(.c) void {
        const self: *PendingReport = @ptrCast(@alignCast(data orelse return));
        self.reporter.report(self.reporter.host, &self.info);
    }
};

/// HTML "report an exception" through the host's reporter, with V8's
/// automatic microtask checkpoints held off until it returns: the algorithms
/// here report before "clean up after running script" performs the
/// checkpoint, so an error handler's promise reactions wait for that one.
fn report(isolate: *ffi.Isolate, info: engine.ErrorInfo, reporter: engine.Reporter) void {
    var pending = PendingReport{ .info = info, .reporter = reporter };
    ffi.v8_RunWithMicrotasksSuppressed(isolate, PendingReport.run, &pending);
}

// ============================================================================
// Classic scripts (HTML 8.1.4.4)
// ============================================================================

/// "Create a classic script" (its parse) and ScriptEvaluation, in an entered
/// realm: the V8 results, freed together once the caller has read them.
const Evaluation = struct {
    compiled: *ffi.V8ScriptCompileResult,
    run: ?*ffi.V8ScriptRunResult = null,

    /// Whether the script failed to compile: its parse error is what it
    /// "threw" (HTML "create a classic script": parse error and error to
    /// rethrow).
    fn parseFailed(self: Evaluation) bool {
        return self.compiled.script == null;
    }

    /// What the evaluation threw - a parse error, or an exception - as V8
    /// caught it; null for a normal completion.
    fn thrown(self: Evaluation) ?*const ffi.V8ErrorInfo {
        if (self.compiled.script == null) return self.compiled.error_info;
        const run = self.run orelse return null;
        return run.error_info;
    }

    /// The normal completion's value, OWNED by the caller from here.
    fn takeValue(self: *Evaluation) ?*ffi.Value {
        const run = self.run orelse return null;
        const value = run.value;
        run.value = null;
        return value;
    }

    fn free(self: Evaluation) void {
        if (self.run) |run| {
            if (run.value) |value| ffi.v8_Global_Dispose(value);
            ffi.v8_FreeScriptRunResult(run);
        }
        if (self.compiled.script) |script| ffi.v8_Script_Dispose(script);
        ffi.v8_FreeScriptCompileResult(self.compiled);
    }
};

/// A classic script's source text as a V8 string, and where it starts in its
/// resource. `made` is the string this made, OWNED (`free`); a string value
/// source is borrowed.
const SourceText = struct {
    text: *ffi.String,
    made: ?*ffi.String = null,
    /// ScriptOrigin's resource_line_offset and resource_column_offset: the
    /// protocol's 1-based SourcePosition less one.
    line_offset: c_int = 0,
    column_offset: c_int = 0,

    fn of(isolate: *ffi.Isolate, source: engine.ScriptSource) Error!SourceText {
        return switch (source) {
            // UTF-8, a resource of its own.
            .utf8 => |bytes| blk: {
                const made = try support.newString(isolate, bytes);
                break :blk .{ .text = made, .made = made };
            },
            // UTF-8 inside its document: offset to where it starts there.
            .embedded => |embedded| blk: {
                const made = try support.newString(isolate, embedded.utf8);
                const offsets = originOffsets(embedded.start);
                break :blk .{ .text = made, .made = made, .line_offset = offsets.line, .column_offset = offsets.column };
            },
            // A string value, kept with every code unit.
            .string => |value| blk: {
                const handle = support.handleOf(value) orelse return error.TypeError;
                if (!ffi.v8_Value_IsString(handle)) return error.TypeError;
                break :blk .{ .text = @ptrCast(handle) };
            },
        };
    }

    fn free(self: SourceText) void {
        if (self.made) |t| ffi.v8_String_Dispose(t);
    }
};

/// The protocol's SourcePosition (1-based) as ScriptOrigin's offsets
/// (0-based). A position of 0 - unknown - is no offset.
pub fn originOffsets(start: engine.SourcePosition) struct { line: c_int, column: c_int } {
    const max: u32 = std.math.maxInt(c_int);
    return .{
        .line = @intCast(@min(start.line -| 1, max)),
        .column = @intCast(@min(start.column -| 1, max)),
    };
}

fn evaluate(scope: ScriptScope, source: engine.ScriptSource, url: []const u8, host_defined: ?*anyopaque) Error!Evaluation {
    const isolate = scope.isolate;
    const context = scope.context();

    // The source text: UTF-8, or a string value kept with every code unit.
    const text = try SourceText.of(isolate, source);
    defer text.free();

    // The script's URL is its ScriptOrigin's resource name - the filename of
    // what it throws, and the referrer of its import() calls, with the host's
    // script as the host-defined options.
    var name: ?*ffi.String = null;
    defer if (name) |n| ffi.v8_String_Dispose(n);
    if (url.len > 0) name = try support.newString(isolate, url);

    var evaluation = Evaluation{ .compiled = ffi.v8_Script_CompileWithHostDefined_Safe(context, text.text, name, text.line_offset, text.column_offset, host_defined) };
    // "Create a classic script": a script that does not parse has a parse
    // error, which run a classic script step 6 turns into the evaluation
    // status - thrown, like anything evaluation throws.
    if (evaluation.compiled.script) |script| {
        // Step 7: ScriptEvaluation.
        evaluation.run = ffi.v8_Script_Run_Safe(context, script);
    }
    return evaluation;
}

/// Steps 5-8.3.1 of "run a classic script" - the evaluation, and the report
/// of what it threw - as a body v8_RunWithMicrotasksSuppressed runs. V8's
/// kAuto policy performs a microtask checkpoint whenever its call depth
/// returns to zero, which is at the end of Script::Run; the suppression scope
/// holds the depth above zero, so the checkpoint is the one "clean up after
/// running script" performs, after the report (8.3.1 before 8.3.2) - the
/// order Blink gets from the MicrotasksScope around its script run.
const EvaluateAndReport = struct {
    scope: ScriptScope,
    realm: Context,
    source: engine.ScriptSource,
    url: []const u8,
    host_defined: ?*anyopaque,
    reporter: engine.Reporter,
    /// Keep the normal completion's value.
    keep_value: bool,
    /// Out: an error before evaluation (the source was no string).
    failure: ?Error = null,
    /// Out: the evaluation threw, and it was reported.
    threw: bool = false,
    /// Out: the normal completion's value, OWNED, when kept.
    value: ?*ffi.Value = null,

    fn run(data: ?*anyopaque) callconv(.c) void {
        const self: *EvaluateAndReport = @ptrCast(@alignCast(data orelse return));
        // 5-7. The evaluation status: the parse error, or ScriptEvaluation.
        var evaluation = evaluate(self.scope, self.source, self.url, self.host_defined) catch |err| {
            self.failure = err;
            return;
        };
        defer evaluation.free();
        // 8. An abrupt completion, rethrow errors false (8.3): 1. report an
        // exception for the global.
        if (evaluation.thrown()) |info| {
            var error_info = protocolErrorInfo(info, self.realm);
            // The parse error, as opposed to what evaluation threw.
            error_info.parse_error = evaluation.parseFailed();
            self.reporter.report(self.reporter.host, &error_info);
            self.threw = true;
            return;
        }
        if (self.keep_value) self.value = evaluation.takeValue();
    }

    /// Run the evaluation in the prepared realm, then "clean up after running
    /// script" - 8.3.2 for an abrupt completion, 9 for a normal one.
    fn runThenCleanUp(self: *EvaluateAndReport) Error!void {
        ffi.v8_RunWithMicrotasksSuppressed(self.scope.isolate, run, self);
        cleanUpAfterRunningScript(self.scope);
        if (self.failure) |err| return err;
        // 8.3.3: return the evaluation status - reported, nothing pending.
        if (self.threw) return error.ExceptionReported;
    }
};

/// HTML "run a classic script" with rethrow errors false.
pub fn runClassicScript(realm: Context, source: engine.ScriptSource, url: []const u8, host_defined: ?*anyopaque, reporter: engine.Reporter) Error!void {
    // 1-3. The settings object is the realm's; "check if we can run script"
    // and the long-animation-frame timing are the host's.
    // 4. Prepare to run script.
    var call = EvaluateAndReport{
        .scope = try prepareToRunScript(realm),
        .realm = realm,
        .source = source,
        .url = url,
        .host_defined = host_defined,
        .reporter = reporter,
        .keep_value = false,
    };
    // 5-9, and 10: a normal completion.
    try call.runThenCleanUp();
}

/// Steps 5-8 of "run a classic script" with rethrow errors true, as a body
/// v8_RunWithMicrotasksSuppressed runs: the wrapper compiles and runs the
/// script, and ReThrow()s what it threw (8.1) - or, muted, clears it (8.2).
const EvaluateRethrowing = struct {
    scope: ScriptScope,
    source: engine.ScriptSource,
    url: []const u8,
    host_defined: ?*anyopaque,
    muted_errors: bool,
    /// Out: an error before evaluation (the source was no string).
    failure: ?Error = null,
    /// Out: v8_Script_RunRethrowingErrors' answer.
    outcome: c_int = 0,

    fn run(data: ?*anyopaque) callconv(.c) void {
        const self: *EvaluateRethrowing = @ptrCast(@alignCast(data orelse return));
        const isolate = self.scope.isolate;
        const text = SourceText.of(isolate, self.source) catch |err| {
            self.failure = err;
            return;
        };
        defer text.free();
        var name: ?*ffi.String = null;
        defer if (name) |n| ffi.v8_String_Dispose(n);
        if (self.url.len > 0) name = support.newString(isolate, self.url) catch |err| {
            self.failure = err;
            return;
        };
        self.outcome = ffi.v8_Script_RunRethrowingErrors(self.scope.context(), text.text, name, text.line_offset, text.column_offset, self.host_defined, self.muted_errors);
    }
};

/// HTML "run a classic script" with rethrow errors true (see the
/// declaration): what the script throws stays pending as it was thrown, or
/// - muted - is cleared for the host's NetworkError. "Clean up after running
/// script" runs first either way: the exception stays pending through it,
/// and, called from script (importScripts()), the stack is not empty, so it
/// performs no checkpoint.
pub fn runClassicScriptRethrowingErrors(realm: Context, source: engine.ScriptSource, url: []const u8, host_defined: ?*anyopaque, muted_errors: bool) Error!void {
    // 4. Prepare to run script.
    var call = EvaluateRethrowing{
        .scope = try prepareToRunScript(realm),
        .source = source,
        .url = url,
        .host_defined = host_defined,
        .muted_errors = muted_errors,
    };
    // 5-7, and the wrapper's ReThrow or clear of 8.1-8.2.
    ffi.v8_RunWithMicrotasksSuppressed(call.scope.isolate, EvaluateRethrowing.run, &call);
    // 8.1.1, 8.2.1, 9: clean up after running script.
    cleanUpAfterRunningScript(call.scope);
    if (call.failure) |err| return err;
    return switch (call.outcome) {
        // 10: a normal completion.
        0 => {},
        // 8.2.2: muted - nothing pending; the host throws the NetworkError.
        2 => error.MutedScriptError,
        // 8.1.2: the original exception, pending; or a termination going on.
        else => error.ExceptionPending,
    };
}

/// A classic script's completion value (see the declaration): run a classic
/// script, with what it throws reported as step 8.3 does, and the normal
/// completion's value kept.
pub fn evaluateClassicScript(realm: Context, source: engine.ScriptSource, url: []const u8, host_defined: ?*anyopaque, reporter: engine.Reporter) Error!Owned {
    var call = EvaluateAndReport{
        .scope = try prepareToRunScript(realm),
        .realm = realm,
        .source = source,
        .url = url,
        .host_defined = host_defined,
        .reporter = reporter,
        .keep_value = true,
    };
    call.runThenCleanUp() catch |err| {
        if (call.value) |value| ffi.v8_Global_Dispose(value);
        return err;
    };
    const value = call.value orelse return .{ .value = JSValue.jsUndefined };
    return .{ .value = realm_entry.owned(value) };
}

/// ToString(value) as a body v8_RunCatching runs under its TryCatch.
const ToStringCall = struct {
    value: *ffi.Value,
    context: *ffi.Context,
    /// OWNED when set.
    result: ?*ffi.String = null,

    fn run(data: ?*anyopaque) callconv(.c) void {
        const call: *ToStringCall = @ptrCast(@alignCast(data orelse return));
        call.result = ffi.v8_Value_ToString(call.value, call.context);
    }
};

/// evaluateClassicScript, then ECMAScript ToString of the completion value.
pub fn evaluateClassicScriptToString(realm: Context, source: engine.ScriptSource, url: []const u8, host_defined: ?*anyopaque, allocator: Allocator, reporter: engine.Reporter) Error![]u8 {
    const completion = try evaluateClassicScript(realm, source, url, host_defined, reporter);
    defer completion.release();

    const entered = try support.enter(realm);
    defer entered.leave();
    const value = realm_entry.EngineValue.of(entered.isolate, entered.context(), completion.value) catch |err| return support.protocolError(err);
    defer value.release();

    // ToString runs script - a toString method - which can throw: that is
    // reported like anything the script threw.
    var call = ToStringCall{ .value = value.ptr, .context = entered.context() };
    var thrown: ?*ffi.Value = null;
    if (ffi.v8_RunCatching(entered.isolate, ToStringCall.run, &call, &thrown)) {
        const exception = thrown orelse return error.ExceptionReported;
        defer ffi.v8_Global_Dispose(exception);
        const info = ffi.v8_Exception_GetErrorInfo(entered.context(), exception);
        defer ffi.v8_FreeErrorInfo(info);
        var error_info: engine.ErrorInfo = if (info) |i| protocolErrorInfo(i, realm) else .{
            .message = "Uncaught exception",
            .filename = "",
            .lineno = 0,
            .colno = 0,
            .error_value = JSValue.jsUndefined,
            .realm = realm,
        };
        error_info.error_value = .{ .handle = .{ .ptr = exception } };
        report(entered.isolate, error_info, reporter);
        return error.ExceptionReported;
    }
    // Null without a throw only for a terminating isolate.
    const string = call.result orelse return error.OperationFailed;
    defer ffi.v8_String_Dispose(string);
    const length = ffi.v8_String_Utf8Length(string);
    if (length <= 0) return allocator.alloc(u8, 0);
    const buffer = try allocator.alloc(u8, @intCast(length));
    const written = ffi.v8_String_WriteUtf8(string, buffer.ptr, length);
    if (written < length) return allocator.realloc(buffer, @intCast(@max(written, 0)));
    return buffer;
}

// ============================================================================
// Event handler content attributes (HTML 8.1.8.1)
// ============================================================================

/// HTML "get the current value of the event handler", step 3 from 3.7 on -
/// steps 3.1-3.6 (the element, its document, the sandboxing check, the body,
/// its location, the form owner, the settings object) are the host's, which
/// hands them over in `source` and `realm`.
pub fn compileEventHandler(realm: Context, source: *const engine.EventHandlerSource, reporter: engine.Reporter) Error!?Owned {
    // 8. Push the settings object's realm execution context, so that
    // OrdinaryFunctionCreate takes place in the right realm. (10: removed
    // when this returns.) No script runs, so there is no clean up to do.
    const entered = try support.enter(realm);
    defer entered.leave();
    const isolate = entered.isolate;
    const context = entered.context();

    // 9. The function's ParameterList: `event` - `evt` for an SVG element's
    // handler - or, for a Window's onerror, the five of the error handler.
    const event_parameters = [_][*:0]const u8{"event"};
    const svg_parameters = [_][*:0]const u8{"evt"};
    const onerror_parameters = [_][*:0]const u8{ "event", "source", "lineno", "colno", "error" };
    const parameters: []const [*:0]const u8 = switch (source.parameters) {
        .event => &event_parameters,
        .evt => &svg_parameters,
        .onerror => &onerror_parameters,
    };

    // 9, scope: the global environment, wrapped by object environments of
    // the document (for an element's handler), the form owner, and the
    // element - outermost first. Each is the platform object's wrapper; the
    // wrapper cache holds it WEAKLY, and the next one made can allocate and
    // collect it, so each is cloned as it is made (docs/lessons/
    // architecture-a-weakly-held-wrapper-dies-at-the-next-allocation.md).
    var scopes: [3]?*ffi.Object = .{ null, null, null };
    var scope_count: usize = 0;
    defer for (scopes[0..scope_count]) |scope| ffi.v8_Global_Dispose(@ptrCast(scope));
    for ([_]?*engine.Instance{ source.document, source.form_owner, source.element }) |maybe| {
        const instance = maybe orelse continue;
        const wrapper = conversions.instanceToV8(isolate, instance);
        scopes[scope_count] = @ptrCast(ffi.v8_Global_Clone(@ptrCast(wrapper)) orelse continue);
        scope_count += 1;
    }

    var parse_error: ?*ffi.V8ErrorInfo = null;
    defer ffi.v8_FreeErrorInfo(parse_error);
    // 4. `location`, where the body originated: the document's URL and the
    // body's position in it - the ScriptOrigin the body is compiled with, so
    // that what it throws, and a violation inside it, report them (Blink's
    // JSEventHandlerForContentAttribute compiles with its TextPosition).
    // 11. [[ScriptOrModule]] is null: no host-defined options, so an import()
    // in it names no referrer.
    const offsets = originOffsets(.{ .line = source.lineno, .column = source.colno });
    const function = ffi.v8_CompileEventHandlerWithParameters(
        context,
        source.name.ptr,
        @intCast(source.name.len),
        source.body.ptr,
        @intCast(source.body.len),
        parameters.ptr,
        @intCast(parameters.len),
        &scopes,
        @intCast(scope_count),
        source.url.ptr,
        @intCast(source.url.len),
        offsets.line,
        offsets.column,
        &parse_error,
    );
    if (function) |f| return .{ .value = realm_entry.owned(f) };

    // 7. The body does not parse: 2. a SyntaxError of the settings object's
    // realm, based on `location` - V8 counts its line from the body's
    // position - 3. reported for the global, 4. return null. (7.1, setting
    // the handler's value to null, is the host's.)
    const info = parse_error orelse return error.OperationFailed;
    var error_info = protocolErrorInfo(info, realm);
    error_info.filename = source.url;
    report(isolate, error_info, reporter);
    return null;
}

// ============================================================================
// Extract error information (HTML 8.1.4.6)
// ============================================================================

/// CSP 2.4.1 step 2's running script position, for `agent` (its isolate):
/// StackTrace::CurrentStackTrace's top frame - the topmost JavaScript frame,
/// a script's - read for its script name or sourceURL
/// (GetScriptNameOrSourceURL: a `//# sourceURL=` when the script has one -
/// V8's Script::GetNameOrSourceURL, whatever v8-debug.h's comment says -
/// else the name it was compiled with) and its 1-based line and column. Blink's
/// SourceLocation::Capture reads the same frame. Null when the isolate is not
/// this thread's current one (no script of it can be running here) or the
/// stack has no frame.
pub fn runningScriptLocation(agent: *engine.Agent, allocator: Allocator) Error!?engine.ScriptLocation {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    if (ffi.v8_Isolate_GetCurrent() != isolate) return null;
    var url: ?[*]u8 = null;
    var url_len: usize = 0;
    var line: c_int = 0;
    var column: c_int = 0;
    if (!ffi.v8_Isolate_RunningScriptLocation(isolate, &url, &url_len, &line, &column)) return null;
    defer if (url) |p| std.c.free(p);
    return .{
        .url = try allocator.dupe(u8, if (url) |p| p[0..url_len] else ""),
        // Message::kNoLineNumberInfo and kNoColumnInfo are 0: unknown.
        .line = if (line > 0) @intCast(line) else 0,
        .column = if (column > 0) @intCast(column) else 0,
    };
}

/// HTML "extract error information" from `value`. `message` and `filename`
/// are allocated with `allocator` (the caller frees both); `error_value` is
/// `value`, BORROWED.
pub fn extractErrorInformation(realm: Context, value: JSValue, allocator: Allocator) Error!engine.ErrorInfo {
    const entered = try support.enter(realm);
    defer entered.leave();
    const exception = realm_entry.EngineValue.of(entered.isolate, entered.context(), value) catch |err| return support.protocolError(err);
    defer exception.release();

    // 1-2. The attributes' `error` is the value itself.
    // 3. `message`, `filename`, `lineno` and `colno` are implementation-
    // defined, derived from the value: V8's message for it - the location it
    // was thrown at, for an Error it made.
    const info = ffi.v8_Exception_GetErrorInfo(entered.context(), exception.ptr);
    defer ffi.v8_FreeErrorInfo(info);
    const found: engine.ErrorInfo = if (info) |i| protocolErrorInfo(i, realm) else .{
        .message = "Uncaught exception",
        .filename = "",
        .lineno = 0,
        .colno = 0,
        .error_value = value,
        .realm = realm,
    };
    const message = try allocator.dupe(u8, found.message);
    errdefer allocator.free(message);
    const filename = try allocator.dupe(u8, found.filename);
    // 4. Return the attributes.
    return .{
        .message = message,
        .filename = filename,
        .lineno = found.lineno,
        .colno = found.colno,
        .error_value = value,
        .realm = realm,
    };
}
