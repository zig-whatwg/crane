//! The engine protocol's SourcePosition on V8: where a script's text starts
//! in its resource - an inline script's text in its document - and the
//! positions V8 reports from it. ScriptSource.embedded (runClassicScript and
//! the other classic-script operations), parseModule's `start` and
//! EventHandlerSource's lineno/colno become ScriptOrigin's
//! resource_line_offset and resource_column_offset: every line is offset by
//! `line - 1`, the first line's columns by `column - 1`. Blink keeps the
//! same TextPosition in ScriptSourceCode and compiles with it.
//!
//! What it fixes: an inline script reported its errors, and CSP its
//! violations, at lines counted from the script's own first line
//! (html/webappapis/scripting/processing-model-2/window-onerror-runtime-
//! error.html expected 36, got 8; content-security-policy/
//! securitypolicyviolation/blockeduri-eval.html 15, got 11;
//! html/semantics/scripting-1/the-script-element/module/evaluation-error-5.html
//! 16, got 1), and an event handler content attribute's runtime error had no
//! file name (processing-model-2/runtime-error-in-attribute.html).
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent), makes its own agents, and leaves no
//! isolate entered that it entered.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const page_url = "https://example.test/page.html";

/// What a run reported: the last report's position and file name.
const Reports = struct {
    count: usize = 0,
    lineno: u32 = 0,
    colno: u32 = 0,
    parse_error: bool = false,
    filename_buffer: [128]u8 = undefined,
    filename_len: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        self.lineno = info.lineno;
        self.colno = info.colno;
        self.parse_error = info.parse_error;
        self.filename_len = @min(info.filename.len, self.filename_buffer.len);
        @memcpy(self.filename_buffer[0..self.filename_len], info.filename[0..self.filename_len]);
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }

    fn filename(self: *const Reports) []const u8 {
        return self.filename_buffer[0..self.filename_len];
    }
};

/// The host of the agent whose code generation hook reads
/// runningScriptLocation - where a CSP violation for eval() reads it.
const Host = struct {
    agent: ?*protocol.Agent = null,
    found: bool = false,
    line: u32 = 0,
    column: u32 = 0,
    url_buffer: [128]u8 = undefined,
    url_len: usize = 0,

    const hooks: protocol.HostHooks = .{ .ensureCanCompileStrings = ensure };

    fn ensure(host: ?*anyopaque, realm: runtime.Context, compilation: *const protocol.StringCompilation) protocol.StringCompilationVerdict {
        _ = realm;
        _ = compilation;
        const self: *Host = @ptrCast(@alignCast(host.?));
        self.found = false;
        const location = (protocol.runningScriptLocation(self.agent.?, std.testing.allocator) catch null) orelse return .allowed;
        defer location.deinit(std.testing.allocator);
        self.found = true;
        self.line = location.line;
        self.column = location.column;
        self.url_len = @min(location.url.len, self.url_buffer.len);
        @memcpy(self.url_buffer[0..self.url_len], location.url[0..self.url_len]);
        return .allowed;
    }

    fn url(self: *const Host) []const u8 {
        return self.url_buffer[0..self.url_len];
    }
};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

fn windowRealm(agent: *protocol.Agent) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
}

/// An agent of its own, with `host`'s code generation hook, and a Window realm.
const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open(host: *Host) !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = host });
        errdefer protocol.destroyAgent(agent);
        host.agent = agent;
        return .{ .agent = agent, .realm = try windowRealm(agent) };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }
};

fn embedded(text: []const u8, line: u32, column: u32) protocol.ScriptSource {
    return .{ .embedded = .{ .utf8 = text, .start = .{ .line = line, .column = column } } };
}

test "an embedded classic script reports what it throws in its document's lines" {
    var host: Host = .{};
    const page = try Page.open(&host);
    defer page.close();

    // Thrown on the script's second line: the document's line 10 + 1; the
    // column offset is the first line's only.
    var reports: Reports = .{};
    try std.testing.expectError(error.ExceptionReported, protocol.runClassicScript(page.realm, embedded("var a = 1;\n  throw new Error('second');", 10, 9), page_url, null, reports.reporter()));
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqual(@as(u32, 11), reports.lineno);
    try std.testing.expectEqual(@as(u32, 3), reports.colno);
    try std.testing.expectEqualStrings(page_url, reports.filename());
    try std.testing.expect(!reports.parse_error);

    // Thrown on its first line: the first line's columns start at the
    // document's column 9 (`<script>` is 8 characters).
    reports = .{};
    try std.testing.expectError(error.ExceptionReported, protocol.runClassicScript(page.realm, embedded("throw new Error('first');", 15, 9), page_url, null, reports.reporter()));
    try std.testing.expectEqual(@as(u32, 15), reports.lineno);
    try std.testing.expectEqual(@as(u32, 9), reports.colno);

    // A parse error, the same way (window-onerror-parse-error.html: 34).
    reports = .{};
    try std.testing.expectError(error.ExceptionReported, protocol.runClassicScript(page.realm, embedded("This script does not parse correctly.", 34, 11), page_url, null, reports.reporter()));
    try std.testing.expectEqual(@as(u32, 34), reports.lineno);
    try std.testing.expect(reports.parse_error);

    // A script of its own (`.utf8`) is not offset.
    reports = .{};
    try std.testing.expectError(error.ExceptionReported, protocol.runClassicScript(page.realm, .{ .utf8 = "\nthrow new Error('own');" }, "https://example.test/own.js", null, reports.reporter()));
    try std.testing.expectEqual(@as(u32, 2), reports.lineno);
    try std.testing.expectEqual(@as(u32, 1), reports.colno);
}

test "runningScriptLocation inside an embedded script is in its document's lines" {
    var host: Host = .{};
    const page = try Page.open(&host);
    defer page.close();

    // blockeduri-eval.html: the eval() call on the document's line 15,
    // column 13, in a script whose text starts at line 5, column 9.
    var reports: Reports = .{};
    // The text's line 1 is the rest of the document's line 5 (empty), and
    // its line 11 the document's line 15.
    const source = "\n" ++ "//\n" ** 9 ++ "            eval('1');\n";
    try protocol.runClassicScript(page.realm, embedded(source, 5, 9), page_url, null, reports.reporter());
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expect(host.found);
    try std.testing.expectEqualStrings(page_url, host.url());
    try std.testing.expectEqual(@as(u32, 15), host.line);
    try std.testing.expectEqual(@as(u32, 13), host.column);

    // evaluateClassicScript takes the same source.
    host.found = false;
    const completion = try protocol.evaluateClassicScript(page.realm, embedded("eval('2')", 40, 21), page_url, null, reports.reporter());
    completion.release();
    try std.testing.expect(host.found);
    try std.testing.expectEqual(@as(u32, 40), host.line);
    try std.testing.expectEqual(@as(u32, 21), host.column);
}

test "an inline module script's evaluation error is reported at its document line" {
    var host: Host = .{};
    const page = try Page.open(&host);
    defer page.close();

    // evaluation-error-5.html: `<script type="module">a</script>` on line 16.
    const parsed = try protocol.parseModule(page.realm, "a", .{ .line = 16, .column = 23 }, page_url, null);
    const record = switch (parsed) {
        .record => |r| r,
        .parse_error => |e| {
            e.release();
            return error.DidNotParse;
        },
    };
    defer protocol.releaseModuleRecord(record);
    const None = struct {
        fn resolve(_: ?*anyopaque, _: *protocol.ModuleRecord, _: protocol.ModuleRequest) ?*protocol.ModuleRecord {
            return null;
        }
    };
    try std.testing.expect(try protocol.linkModule(page.realm, record, None.resolve, null) == null);
    const scope = try protocol.prepareToRunScript(page.realm);
    const evaluation = try protocol.evaluateModule(page.realm, record);
    protocol.cleanUpAfterRunningScript(scope);
    // Thrown synchronously: the evaluation is rejected with the ReferenceError.
    try std.testing.expect(evaluation == .rejected);
    const reason = evaluation.rejected;
    defer reason.release();
    const info = try protocol.extractErrorInformation(page.realm, reason.value, std.testing.allocator);
    defer std.testing.allocator.free(info.message);
    defer std.testing.allocator.free(info.filename);
    try std.testing.expectEqual(@as(u32, 16), info.lineno);
    try std.testing.expectEqual(@as(u32, 23), info.colno);
    try std.testing.expectEqualStrings(page_url, info.filename);
}

test "an event handler content attribute compiles at its position in the document, named by its URL" {
    var host: Host = .{};
    const page = try Page.open(&host);
    defer page.close();

    // runtime-error-in-attribute.html: `<p onclick="undefined_variable;">` -
    // what the handler throws when it runs names the document.
    var reports: Reports = .{};
    const source: protocol.EventHandlerSource = .{
        .body = "\nundefined_variable;",
        .name = "onclick",
        .url = page_url,
        .lineno = 24,
        .colno = 3,
        .parameters = .event,
        .document = null,
        .form_owner = null,
        .element = null,
    };
    const function = (try protocol.compileEventHandler(page.realm, &source, reports.reporter())) orelse return error.DidNotCompile;
    defer function.release();
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    const callback: protocol.CallbackFunction = .{ .function = function, .context = page.realm };
    const completion = try protocol.invokeCallbackFunction(page.realm, &callback, .undefined, &.{}, .{ .report = reports.reporter() });
    switch (completion) {
        .normal => |value| value.release(),
        .throw => |value| value.release(),
    }
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqualStrings(page_url, reports.filename());
    try std.testing.expectEqual(@as(u32, 25), reports.lineno);

    // A body that does not parse reports its SyntaxError at the handler's
    // line (compile-error-in-attribute.html), counted by V8 from the offset.
    reports = .{};
    const broken: protocol.EventHandlerSource = .{
        .body = "{",
        .name = "onclick",
        .url = page_url,
        .lineno = 24,
        .colno = 3,
        .parameters = .event,
        .document = null,
        .form_owner = null,
        .element = null,
    };
    try std.testing.expectEqual(@as(?protocol.Owned, null), try protocol.compileEventHandler(page.realm, &broken, reports.reporter()));
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqual(@as(u32, 24), reports.lineno);
    try std.testing.expectEqualStrings(page_url, reports.filename());
}

test "running embedded scripts and compiling positioned handlers leaves no Global behind" {
    var host: Host = .{};
    const page = try Page.open(&host);
    defer page.close();
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(page.agent));

    var reports: Reports = .{};
    // Warm up: the first runs make the realm's lazily made state.
    for (0..4) |_| {
        protocol.runClassicScript(page.realm, embedded("throw new Error('x');", 7, 9), page_url, null, reports.reporter()) catch {};
        const warm = (try protocol.compileEventHandler(page.realm, &.{ .body = "1;", .name = "onclick", .url = page_url, .lineno = 3, .colno = 5, .parameters = .event, .document = null, .form_owner = null, .element = null }, reports.reporter())).?;
        warm.release();
    }
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..32) |_| {
        protocol.runClassicScript(page.realm, embedded("throw new Error('x');", 7, 9), page_url, null, reports.reporter()) catch {};
        const function = (try protocol.compileEventHandler(page.realm, &.{ .body = "1;", .name = "onclick", .url = page_url, .lineno = 3, .colno = 5, .parameters = .event, .document = null, .form_owner = null, .element = null }, reports.reporter())).?;
        function.release();
    }
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    try std.testing.expect(after <= before);
}
