//! The document-start host script hook (src/html/navigation/document_start.zig,
//! lane life1, for CDP Page.addScriptToEvaluateOnNewDocument): run as each new
//! document's Window realm is set up, before the document's parser runs any
//! of its scripts - Blink's probe::DidCreateMainWorldContext point - with the
//! navigable, the navigation and the realm; script the host runs there is in
//! effect when the page's first inline script runs, in every new document: a
//! navigated page, a frame's initial about:blank and its later document.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
const engine = @import("engine");
const runtime = @import("runtime");
const html = @import("html");

const document_start = html.navigation.document_start;

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

fn until(browser: *browser_mod.Browser, condition: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const page = browser.current_context orelse return error.NoPage;
        const result = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(result);
        if (std.mem.eql(u8, result, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

fn ignoreReport(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

/// A host that injects a script into every new document, counting them.
const Injector = struct {
    runs: u32 = 0,
    last_navigation: u64 = 0,

    fn run(context: *anyopaque, start: *const document_start.Start) void {
        const self: *Injector = @ptrCast(@alignCast(context));
        self.runs += 1;
        self.last_navigation = start.navigation_id;
        const realm: runtime.Context = @ptrCast(@alignCast(start.realm));
        engine.runClassicScript(realm, .{ .utf8 = "globalThis.injected = 'yes'; globalThis.scriptsBefore = document.scripts.length;" }, "injected.js", null, .{ .report = ignoreReport }) catch {};
    }
};

fn injectedBeforeThePagesScripts() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    var injector: Injector = .{};
    const navigables = dom.browser_state.existingNavigablesIn(browser.scope) orelse return error.NoNavigables;
    navigables.document_start = .{ .context = &injector, .run = Injector.run };

    try page.loadHTML("<!doctype html><script>globalThis.seenByPage = globalThis.injected;</script><body>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    // The page's first inline script saw the injected global, and nothing of
    // the page's had run when the host's script did.
    try expectEval(page, "[seenByPage, scriptsBefore].join()", "yes,0");
    try testing.expect(injector.last_navigation != 0);

    // A frame: its initial about:blank document (navigation 0) and the
    // document its navigation makes each get the scripts.
    const before = injector.runs;
    try page.runScript(
        \\globalThis.f = document.createElement('iframe');
        \\f.srcdoc = "<script>parent.frameSaw = globalThis.injected;</script>";
        \\document.body.append(f);
        \\globalThis.blankSaw = f.contentWindow.injected;
    );
    try until(browser, "globalThis.frameSaw !== undefined");
    try expectEval(page, "[blankSaw, frameSaw].join()", "yes,yes");
    try testing.expect(injector.runs >= before + 2);
}

test "a host's document-start script runs in every new document before the page's own scripts" {
    try onFreshThread(injectedBeforeThePagesScripts);
}
