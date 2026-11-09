//! The embedder's parser script loader serves only the script the parser is
//! preparing (html.script_execution.ParserScriptLoader): a script that a
//! parser-inserted inline script inserts while it runs is fetched as any
//! script-inserted script is, never through the loader - for HTML, as
//! xm1_xml_script_loader_test.zig pins it for SVG - and the parser's later
//! scripts still are. The loader was a thread-local set around prepare, kept
//! from the inserted scripts by an element check; it is prepare's parameter
//! now (docs/lessons/architecture-state-set-around-a-call-is-seen-by-
//! everything-it-runs.md).
//! The loader is the Browser's registration (html.embedder_scripts), which
//! answers for every document the Browser parses (lane wptcfg: the
//! navigation's own loader is gone, the user, 2026-11-09).
const std = @import("std");
const browser_mod = @import("browser");
const html = @import("html");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const Loader = struct {
    calls: usize = 0,
    nested_calls: usize = 0,

    /// The loader in use: the test's (it runs on the test's own thread,
    /// helpers.onFreshThread), set for the test's length.
    var current: ?*Loader = null;

    fn load(realm: runtime.Context, url: []const u8) ?[]const u8 {
        const self = current orelse return null;
        if (std.mem.indexOf(u8, url, "gs2-nested") != null) self.nested_calls += 1;
        if (!std.mem.startsWith(u8, url, "https://gs2.invalid/")) return null;
        self.calls += 1;
        // embedder_scripts.Loader: allocated with the realm's allocator.
        return realm.allocator.dupe(u8, "globalThis.gs2Loaded = (globalThis.gs2Loaded || 0) + 1;") catch null;
    }
};

fn loadMarkup(browser: *browser_mod.Browser, loader: *Loader, source: []const u8) !void {
    const encoder = std.base64.standard.Encoder;
    const encoded = try std.testing.allocator.alloc(u8, encoder.calcSize(source.len));
    defer std.testing.allocator.free(encoded);
    _ = encoder.encode(encoded, source);
    const url = try std.fmt.allocPrint(std.testing.allocator, "data:text/html;base64,{s}", .{encoded});
    defer std.testing.allocator.free(url);
    _ = loader;
    try browser.navigate(url, .window);
}

fn parserLoaderServesOnlyItsScript() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    var loader: Loader = .{};
    Loader.current = &loader;
    defer Loader.current = null;
    try html.embedder_scripts.register(browser.scope, &Loader.load);
    defer html.embedder_scripts.unregister(browser.scope);
    try loadMarkup(browser, &loader,
        \\<!doctype html><script src="https://gs2.invalid/parsed.js"></script>
        \\<script>
        \\const inserted = document.createElement('script');
        \\inserted.src = 'https://gs2.invalid/gs2-nested.js';
        \\document.head.appendChild(inserted);
        \\globalThis.gs2Inserted = 1;
        \\</script>
        \\<script src="https://gs2.invalid/after.js"></script>
    );
    _ = try browser.runEventLoopBlocking(200);
    // The parser's two external scripts, and never the one script inserted.
    try std.testing.expectEqual(@as(usize, 2), loader.calls);
    try std.testing.expectEqual(@as(usize, 0), loader.nested_calls);
    const result = try browser.current_context.?.evaluateScriptToString("gs2Inserted + ':' + gs2Loaded", std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("1:2", result);
}

test "an HTML parser's script loader serves the scripts it prepares, not a script an inline script inserts" {
    try helpers.onFreshThread(parserLoaderServesOnlyItsScript);
}
