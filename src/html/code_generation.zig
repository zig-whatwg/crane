//! HTML 8.1.6.2 HostEnsureCanCompileStrings and 8.1.6.3 HostGetCodeForEval,
//! and the WebAssembly JS API's HostEnsureCanCompileWasmBytes: the host's
//! side of the engine's code generation checks (engine.HostHooks,
//! [code_generation_checks]), over the realm's global's CSP list - a
//! Window's (its document's policy container) or a WorkerGlobalScope's.
//!
//! HostEnsureCanCompileStrings is CSP 4.4.1 EnsureCSPDoesNotBlockStringCompilation:
//! its steps 1-2 - Trusted Types' default policy over the source, which
//! runs script - are here; steps 3-6, the policies, are
//! csp.code_generation's. HostEnsureCanCompileWasmBytes is CSP 4.5.1. A
//! timer's string handler is compiled by the host, not the engine, and runs
//! the same check with compilationType "TIMER" (`ensureCSPDoesNotBlockStringCompilation`).
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#hostensurecancompilestrings(realm,-parameterstrings,-bodystring,-codestring,-compilationtype,-parameterargs,-bodyarg)
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#hostgetcodeforeval(argument)
//! Spec: https://w3c.github.io/webappsec-csp/#can-compile-strings
//! Spec: https://w3c.github.io/webappsec-csp/#can-compile-wasm-bytes

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const csp = @import("csp");
const dom = @import("dom");
const report_exception = @import("report_exception.zig");

const trusted_types = dom.trusted_types;

/// The host hooks of an agent whose realms have CSP lists - a similar-origin
/// window agent's, a worker agent's.
pub const hooks: engine.HostHooks = .{
    .ensureCanCompileStrings = ensureCanCompileStrings,
    .getCodeForEval = getCodeForEval,
    .ensureCanCompileWasmBytes = ensureCanCompileWasmBytes,
};

/// CSP 4.4.1's compilationType: the engine's two, and a timer's.
pub const CompilationType = enum { eval, function, timer };

pub const Result = csp.code_generation.Result;

/// HostEnsureCanCompileStrings: "Perform ?
/// EnsureCSPDoesNotBlockStringCompilation(realm, parameterStrings,
/// bodyString, codeString, compilationType, parameterArgs, bodyArg)."
pub fn ensureCanCompileStrings(host: ?*anyopaque, realm: runtime.Context, compilation: *const engine.StringCompilation) engine.StringCompilationVerdict {
    _ = host;
    const global = trusted_types.globalOf(realm) orelse return .allowed;
    const compilation_type: CompilationType = switch (compilation.compilation_type) {
        .eval => .eval,
        .function => .function,
    };
    return switch (ensureCSPDoesNotBlockStringCompilation(global, compilation.code_string, compilation_type, compilation.arguments_are_code_like)) {
        .allowed => .allowed,
        .blocked => .blocked,
    };
}

/// HostGetCodeForEval(argument): "1. If argument is a TrustedScript object,
/// then return argument's data. 2. Otherwise, return no-code." OWNED by
/// `allocator`; null is no-code.
pub fn getCodeForEval(host: ?*anyopaque, realm: runtime.Context, argument: engine.JSValue, allocator: std.mem.Allocator) ?[]u8 {
    _ = host;
    const instance = engine.convertToPlatformObject(realm, argument) orelse return null;
    const data = trusted_types.dataOf(instance, .script) orelse return null;
    return allocator.dupe(u8, data) catch null;
}

/// HostEnsureCanCompileWasmBytes: CSP 4.5.1
/// EnsureCSPDoesNotBlockWasmByteCompilation(realm). False is the
/// WebAssembly.CompileError the engine throws.
pub fn ensureCanCompileWasmBytes(host: ?*anyopaque, realm: runtime.Context) bool {
    _ = host;
    // 1. "Let global be realm's global object."
    const global = trusted_types.globalOf(realm) orelse return true;
    const list = trusted_types.cspListOf(global) orelse return true;
    // 2-4. The policies' part.
    return csp.code_generation.ensureDoesNotBlockWasmByteCompilation(list, dom.csp_violations.reporterFor(global)) == .allowed;
}

/// CSP 4.4.1 EnsureCSPDoesNotBlockStringCompilation(realm, «»-or-
/// parameterStrings, bodyString, `code_string`, `compilation_type`,
/// parameterArgs, bodyArg) for `global`, its realm's global object.
/// `is_trusted` is steps 2.2-2.3's isTrusted: bodyArg and every parameterArg
/// implement TrustedScript. Blocked is the EvalError the caller throws (the
/// engine's, or a timer's report).
pub fn ensureCSPDoesNotBlockStringCompilation(global: *runtime.Instance, code_string: []const u8, compilation_type: CompilationType, is_trusted: bool) Result {
    // A global with no CSP list compiles everything: the fast path every
    // eval takes on a page without policies.
    const list = trusted_types.cspListOf(global) orelse return .allowed;
    if (list.policies.items.len == 0) return .allowed;
    // 1. "Let sourceString be codeString."
    // 2. "If compilationType is not "TIMER"":
    if (compilation_type != .timer and !is_trusted) {
        // 2.1. "Let compilationSink be "Function" if compilationType is
        // "FUNCTION", and "eval" otherwise."
        const sink: []const u8 = if (compilation_type == .function) "Function" else "eval";
        // 2.4. isTrusted is false: 2.4.1-2.4.3.
        if (!defaultPolicyKeepsSource(global, code_string, sink)) return .blocked;
    }
    // 3-6. The policies, read again: the default policy ran script.
    const policies = trusted_types.cspListOf(global) orelse return .allowed;
    return csp.code_generation.ensureDoesNotBlockStringCompilation(policies, code_string, dom.csp_violations.reporterFor(global));
}

/// HTML timer initialization step 10.8.2, for a timer whose handler is the
/// string `handler`, run in `realm`, whose global is `global`: "Perform
/// EnsureCSPDoesNotBlockStringCompilation(realm, « », handler, handler,
/// timer, « », handler). If this throws an exception, catch it, report it
/// for global, and abort these steps." True when the handler may be
/// compiled; false when it is blocked, after its EvalError is reported for
/// `global` (or when the EvalError cannot be made, and nothing is).
///
/// The check runs when the timer fires, as the spec says. Chrome, Firefox
/// and Safari check when setTimeout() is called instead, return 0 and
/// report nothing to script (unsafe-eval/eval-scripts-setTimeout-blocked
/// asserts that 0).
pub fn ensureTimerHandlerMayCompile(realm: runtime.Context, global: *runtime.Instance, handler: []const u8) bool {
    if (ensureCSPDoesNotBlockStringCompilation(global, handler, .timer, false) == .allowed) return true;
    // CSP 4.4.1 step 6: "If result is "Blocked", throw an EvalError
    // exception" - caught by the timer's task and reported for the global.
    // An engine that cannot make one (V8's API has no Exception::EvalError:
    // its adapter answers NotSupported) still has it reported, as the
    // message alone - the ErrorEvent's error is null.
    const exception = engine.createSimpleException(realm, .EvalError, eval_blocked_message) catch |err| switch (err) {
        error.NotSupported => {
            const message_only: runtime.ErrorInfo = .{
                .message = "Uncaught EvalError: " ++ eval_blocked_message,
                .filename = "",
                .lineno = 0,
                .colno = 0,
                .error_value = null,
            };
            _ = report_exception.reportErrorInfo(global, &message_only, .{});
            return false;
        },
        else => return false,
    };
    defer exception.release();
    const allocator = global.ctx.allocator;
    // "Report an exception" step 2: extract error information.
    const info = engine.extractErrorInformation(realm, exception.borrow(), allocator) catch return false;
    defer allocator.free(info.message);
    defer allocator.free(info.filename);
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = info.error_value,
    };
    _ = report_exception.reportErrorInfo(global, &extracted, .{});
    return false;
}

/// The message of the EvalError a blocked string compilation throws - V8's
/// own for eval.
const eval_blocked_message = "Code generation from strings disallowed for this context";

/// CSP 4.4.1 steps 2.4.1-2.4.3: "Set sourceString to the result of executing
/// the get trusted type compliant string algorithm, with TrustedScript,
/// realm, codeString, compilationSink, and 'script'. If the algorithm throws
/// an error, throw an EvalError. If sourceString is not equal to
/// codeString, throw an EvalError." True when neither throws. The default
/// policy's own exception is caught here, so none is left pending.
fn defaultPolicyKeepsSource(global: *runtime.Instance, code_string: []const u8, sink: []const u8) bool {
    // Trusted Types not required: the compliant string is codeString itself
    // (3.4 steps 2-3), with nothing run and nothing reported.
    if (!trusted_types.doesSinkTypeRequireTrustedTypes(global, trusted_types.script_sink_group, true)) return true;
    const Steps = struct {
        global: *runtime.Instance,
        code_string: []const u8,
        sink: []const u8,
        same: bool = false,

        fn run(data: ?*anyopaque) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const allocator = self.global.ctx.allocator;
            const compliant = trusted_types.getCompliantString(allocator, .script, self.global, .{ .string = self.code_string }, self.sink, trusted_types.script_sink_group) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.ExceptionPending => return error.ExceptionPending,
                // "Throw a TypeError" (3.4 step 6.3): a throw, which 2.4.2
                // turns into the EvalError.
                else => return,
            };
            defer allocator.free(compliant);
            self.same = std.mem.eql(u8, compliant, self.code_string);
        }
    };
    var steps: Steps = .{ .global = global, .code_string = code_string, .sink = sink };
    if (!global.ctx.hasEngine()) return true;
    const thrown = engine.completionOf(global.ctx, Steps.run, &steps) catch return false;
    if (thrown) |exception| {
        exception.release();
        return false;
    }
    return steps.same;
}
