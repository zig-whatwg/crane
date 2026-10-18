//! engine.runClassicScriptRethrowingErrors on V8: HTML "run a classic
//! script" with rethrow errors true - what importScripts() runs its scripts
//! with ("import scripts into worker global scope" step 6.2).
//!
//! "If evaluationStatus is an abrupt completion: If rethrow errors is true
//! and script's muted errors is false: Clean up after running script with
//! settings. Rethrow evaluationStatus.[[Value]]." The exception goes on as
//! it was thrown: when the calling script leaves it uncaught, "report an
//! exception" describes it where it was thrown - in the imported script.
//! Throwing the value again (Isolate::ThrowException) made V8 compute a new
//! message at the caller's frame, so every such error was reported at the
//! importScripts() call (workers/Worker-nested-importScripts-error.html).
//! Blink's V8ScriptRunner rethrows with TryCatch::ReThrow, which keeps the
//! message; so does the adapter.
//!
//! The imported scripts are run from a built-in function, as importScripts()
//! runs them from its binding: inside a call from script, the exception left
//! pending for the binding's return.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");

/// The hooks of the file's agent: none.
const window_agent_hooks: protocol.HostHooks = .{};
const interfaces = @import("interfaces");

var isolate_once: ?*ffi.Isolate = null;
var pools_ready = false;

fn agent() !*ffi.Isolate {
    if (isolate_once) |i| return i;
    try protocol.initializeEngine(.{});
    // An agent createAgent made: it keeps its Window realms on its record
    // (protocol_realms.WindowRealms), which a bare isolate has none of.
    const i: *ffi.Isolate = @ptrCast(@alignCast(try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &window_agent_hooks, .host = null })));
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    _ = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    if (!pools_ready) {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(std.heap.page_allocator);
        pools_ready = true;
    }
    isolate_once = i;
    return i;
}

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

fn windowRealm() !runtime.Context {
    const isolate = try agent();
    return protocol.createWindowRealm(&.{
        .agent = @ptrCast(isolate),
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .global_this = .new_window_proxy,
        .parent = null,
        .create_global_object = WindowHost.createGlobalObject,
        .host = null,
    });
}

/// The imported scripts, by the name the built-in is called with.
const Imported = struct {
    name: []const u8,
    url: []const u8,
    source: []const u8,
    muted: bool = false,
};

const imported = [_]Imported{
    // Line 2 does not parse.
    .{ .name = "parse", .url = "https://example.test/parse.js", .source = "var before = 1;\nSELECT * FROM TABLE;\n" },
    // Line 3 throws.
    .{ .name = "throws", .url = "https://example.test/throws.js", .source = "// one\n// two\nthrow new Error('inner failure');\n" },
    // An import of an import, whose innermost script throws on line 2.
    .{ .name = "outer", .url = "https://example.test/outer-import.js", .source = "\nimportScript('throws');\n" },
    // A cross-origin script: its errors are muted.
    .{ .name = "muted", .url = "https://other.test/muted.js", .source = "throw new Error('secret');\n", .muted = true },
    // Runs to completion.
    .{ .name = "fine", .url = "https://example.test/fine.js", .source = "globalThis.ran = (globalThis.ran || 0) + 1;\n" },
};

/// What the built-in did, for the muted case.
const Importer = struct {
    realm: runtime.Context = undefined,
    muted_failures: usize = 0,

    fn steps(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Importer = @ptrCast(@alignCast(data.?));
        const name = if (args.len > 0) switch (args[0]) {
            .string => |s| s.data,
            else => return error.TypeError,
        } else return error.TypeError;
        for (imported) |script| {
            if (!std.mem.eql(u8, script.name, name)) continue;
            protocol.runClassicScriptRethrowingErrors(self.realm, .{ .utf8 = script.source }, script.url, null, script.muted) catch |err| switch (err) {
                // The original exception is pending: the call returns into it.
                error.ExceptionPending => return error.ExceptionPending,
                // Nothing is pending; the host throws a NetworkError. Here
                // the call returns a mark the calling script checks.
                error.MutedScriptError => {
                    self.muted_failures += 1;
                    return runtime.JSValue.fromNumber(-1);
                },
                else => return error.OperationFailed,
            };
            return runtime.JSValue.fromNumber(1);
        }
        return error.TypeError;
    }
};

var importer: Importer = .{};
var importer_function: runtime.BuiltinFunction = .{ .steps = Importer.steps, .data = &importer };

/// The one exception the calling script's run reports, copied.
const Report = struct {
    count: usize = 0,
    filename: [128]u8 = undefined,
    filename_len: usize = 0,
    message: [256]u8 = undefined,
    message_len: usize = 0,
    lineno: u32 = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Report = @ptrCast(@alignCast(host.?));
        self.count += 1;
        self.filename_len = @min(info.filename.len, self.filename.len);
        @memcpy(self.filename[0..self.filename_len], info.filename[0..self.filename_len]);
        self.message_len = @min(info.message.len, self.message.len);
        @memcpy(self.message[0..self.message_len], info.message[0..self.message_len]);
        self.lineno = info.lineno;
    }

    fn filenameSlice(self: *const Report) []const u8 {
        return self.filename[0..self.filename_len];
    }

    fn messageSlice(self: *const Report) []const u8 {
        return self.message[0..self.message_len];
    }
};

var defined = false;

/// Run `source` as the worker's own script (rethrow errors false), at
/// worker.js, and return what it reported.
fn runCalling(source: []const u8) !Report {
    const realm = try windowRealm();
    importer.realm = realm;
    try protocol.defineBuiltinFunction(realm, "importScript", 1, &importer_function);
    var report: Report = .{};
    protocol.runClassicScript(realm, .{ .utf8 = source }, "https://example.test/worker.js", null, .{ .report = Report.report, .host = &report }) catch |err| switch (err) {
        error.ExceptionReported => {},
        else => return err,
    };
    return report;
}

test "a parse error in an imported script is reported where it is, not at importScripts()" {
    const report = try runCalling("\n\nimportScript('parse');\n");
    try std.testing.expectEqual(@as(usize, 1), report.count);
    try std.testing.expectEqualStrings("https://example.test/parse.js", report.filenameSlice());
    try std.testing.expectEqual(@as(u32, 2), report.lineno);
    try std.testing.expect(std.mem.indexOf(u8, report.messageSlice(), "SyntaxError") != null);
}

test "an error an imported script throws is reported at its throw" {
    const report = try runCalling("importScript('throws');\n");
    try std.testing.expectEqual(@as(usize, 1), report.count);
    try std.testing.expectEqualStrings("https://example.test/throws.js", report.filenameSlice());
    try std.testing.expectEqual(@as(u32, 3), report.lineno);
    try std.testing.expect(std.mem.indexOf(u8, report.messageSlice(), "inner failure") != null);
}

test "through two imports, the innermost throw is still where it is reported" {
    const report = try runCalling("importScript('outer');\n");
    try std.testing.expectEqual(@as(usize, 1), report.count);
    try std.testing.expectEqualStrings("https://example.test/throws.js", report.filenameSlice());
    try std.testing.expectEqual(@as(u32, 3), report.lineno);
}

test "the calling script can catch what an imported script threw" {
    const report = try runCalling(
        \\let caught = null;
        \\try { importScript('throws'); } catch (e) { caught = e; }
        \\if (!(caught instanceof Error) || caught.message !== 'inner failure') throw new Error('not caught: ' + caught);
    );
    try std.testing.expectEqual(@as(usize, 0), report.count);
}

test "a muted script's error is cleared, not pending: the host throws NetworkError" {
    const before = importer.muted_failures;
    const report = try runCalling("if (importScript('muted') !== -1) throw new Error('the muted error was pending');\n");
    try std.testing.expectEqual(@as(usize, 0), report.count);
    try std.testing.expectEqual(before + 1, importer.muted_failures);
}

test "a script that completes normally returns normally" {
    const report = try runCalling("if (importScript('fine') !== 1 || globalThis.ran !== 1) throw new Error('did not run');\n");
    try std.testing.expectEqual(@as(usize, 0), report.count);
}
