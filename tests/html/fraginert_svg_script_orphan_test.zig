//! An SVG script removed from its tree while script holds no wrapper of it -
//! `innerHTML = ''` over `<svg><script>`, or a sanitizer's removal - is an
//! orphan: no tree teardown and no collector reaches it, and what its state
//! owns is freed only by its type's sweep at the Browser's end
//! (dom.teardown_sweeps). SVGScriptElement's state was a block of its own
//! with no sweep, so each orphaned SVG script leaked it - and, for one the
//! document parser made, its script text (crane/san-svg-detach-innerhtml and
//! -sethtmlunsafe: one `leaked:` line each on main; the removeChild control,
//! whose script is wrapped as an argument, none).
//!
//! The Browser runs on std.testing.allocator, so a block left at its end
//! fails the test. Each test runs on a thread of its own: tests/html is one
//! executable, and a Browser's agent belongs to the thread that made it.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn openPage(markup: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = "about:blank" });
    return browser;
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        std.debug.print("expected true: {s}\n", .{source});
        return error.TestExpectedTrue;
    }
}

fn fragmentParsedScriptOrphaned() !void {
    const browser = try openPage("<!doctype html><body></body>");
    defer browser.deinit();
    // The fragment parser makes the script; nothing ever wraps it or its svg.
    try expectTrue(browser,
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<svg><script>1<\/script></svg><svg><script>2<\/script></svg>';
        \\host.innerHTML = '';
        \\host.childNodes.length === 0
    );
}

test "an SVG script innerHTML parsed and dropped unwrapped leaves nothing at the Browser's end" {
    try onFreshThread(fragmentParsedScriptOrphaned);
}

fn documentParsedScriptOrphaned() !void {
    // The document parser sets the script's script text at its end tag
    // (Trusted Types 4.1.2.6): the orphan owns a copy of "void 0".
    const browser = try openPage("<!doctype html><body><div id=h><svg><script>void 0</script></svg></div></body>");
    defer browser.deinit();
    try expectTrue(browser,
        \\const host = document.getElementById('h');
        \\host.innerHTML = '';
        \\host.childNodes.length === 0
    );
}

test "a parsed SVG script with script text dropped unwrapped leaves nothing at the Browser's end" {
    try onFreshThread(documentParsedScriptOrphaned);
}
