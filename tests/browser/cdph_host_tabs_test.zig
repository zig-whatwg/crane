//! The host API's tabs (instances design 5.1; roadmap `instances` item
//! "Host API"; lane cdph): a host opens tabs beside its first page, each a
//! top-level traversable in a browsing context group of its own whose realm
//! is entered per call, so tabs close in any order; it lists, activates,
//! navigates, evaluates in and closes them, holds a tab's first navigation
//! until it releases it, and hears tabs come and go. Closing a tab - and the
//! page Browser.navigate replaces - runs HTML "close a top-level traversable":
//! pagehide and unload, beforeunload only when prompting.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const Context = browser_mod.Context;

/// The host tab Context `tab` names (a test reaches the page's loads
/// through it).
fn tabContext(browser: *Browser, tab: Browser.TabId) !*Context {
    for (browser.tabs.items) |ctx| {
        if (ctx.browsing_context) |bc| if (bc.id == tab) return ctx;
    }
    return error.NoSuchTab;
}

fn evaluateIn(ctx: *Context, script: []const u8) ![]u8 {
    return ctx.evaluateScriptToString(script, testing.allocator);
}

/// What an evaluation answered, recorded by its callback.
const Answer = struct {
    done: bool = false,
    kind: ?@FieldType(Browser.EvaluateResult, "kind") = null,
    json: ?[]u8 = null,
    err: ?anyerror = null,

    fn callback(self: *Answer) Browser.EvaluateCallback {
        return .{ .context = self, .done = record };
    }

    fn record(context: *anyopaque, result: anyerror!Browser.EvaluateResult) void {
        const self: *Answer = @ptrCast(@alignCast(context));
        self.done = true;
        if (result) |r| {
            self.kind = r.kind;
            self.json = testing.allocator.dupe(u8, r.json) catch null;
        } else |err| self.err = err;
    }

    fn deinit(self: *Answer) void {
        if (self.json) |json| testing.allocator.free(json);
    }

    fn met(context: *anyopaque) bool {
        const self: *Answer = @ptrCast(@alignCast(context));
        return self.done;
    }
};

/// Run the loop until tab `tab` has loaded a document other than its initial
/// about:blank one.
fn waitForLoad(browser: *Browser, tab: Browser.TabId) !void {
    const Goal = struct {
        browser: *Browser,
        tab: Browser.TabId,
        fn met(context: *anyopaque) bool {
            const self: *@This() = @ptrCast(@alignCast(context));
            const state = self.browser.traversableState(self.tab) orelse return true;
            return !state.navigating and state.loaded and !state.initial_about_blank;
        }
    };
    var goal: Goal = .{ .browser = browser, .tab = tab };
    try testing.expectEqual(Browser.SpinOutcome.met, try browser.spinEventLoopUntil(.{ .context = &goal, .met = Goal.met }, 10_000));
}

/// What the Browser's listener heard, in order.
const Heard = struct {
    events: std.ArrayListUnmanaged(u8) = .empty,
    tabs: std.ArrayListUnmanaged(Browser.TabId) = .empty,

    fn listener(self: *Heard) browser_mod.host_events.Listener {
        return .{ .context = self, .on_event = onEvent };
    }

    fn onEvent(context: *anyopaque, event: *const browser_mod.host_events.Event) void {
        const self: *Heard = @ptrCast(@alignCast(context));
        switch (event.*) {
            .tab_created => |created| {
                self.events.append(testing.allocator, 'c') catch {};
                self.tabs.append(testing.allocator, created.tab) catch {};
            },
            .tab_destroyed => |destroyed| {
                self.events.append(testing.allocator, 'd') catch {};
                self.tabs.append(testing.allocator, destroyed.tab) catch {};
            },
            else => {},
        }
    }

    fn deinit(self: *Heard) void {
        self.events.deinit(testing.allocator);
        self.tabs.deinit(testing.allocator);
    }
};

test "a host-opened tab is a top-level traversable of its own beside the first page, listed as the host's" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const first = browser.hostTraversableId().?;

    const tab = try browser.createTab(.{ .url = "data:text/html,<title>second</title>" });
    try testing.expect(tab != first);
    try waitForLoad(browser, tab);

    const tabs = try browser.listTabs(testing.allocator);
    defer Browser.freeTabs(testing.allocator, tabs);
    try testing.expectEqual(@as(usize, 2), tabs.len);
    try testing.expectEqual(first, tabs[0].id);
    try testing.expectEqual(tab, tabs[1].id);
    try testing.expectEqual(browser_mod.host_events.MadeBy.host, tabs[1].made_by);
    try testing.expectEqualStrings("second", tabs[1].title);
    try testing.expectEqual(@as(?u64, null), tabs[1].opener);
    // A new tab is the active one unless opened in the background.
    try testing.expectEqual(@as(?Browser.TabId, tab), browser.activeTab());

    // Its own browsing context group: no opener, a top-level window of its
    // own, and the first page's realm is not its realm.
    const ctx = try tabContext(browser, tab);
    const shape = try evaluateIn(ctx, "[window.opener === null, window.top === window, document.title, history.length].join('|')");
    defer testing.allocator.free(shape);
    try testing.expectEqualStrings("true|true|second|1", shape);
    try testing.expect(browser.tabRealm(tab).? != browser.tabRealm(first).?);
}

test "a tab opened in the background does not become the active tab" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const first = browser.hostTraversableId().?;
    _ = try browser.createTab(.{ .background = true });
    try testing.expectEqual(@as(?Browser.TabId, first), browser.activeTab());
}

test "two host tabs close in creation order, the first while the second lives, and the second navigates after" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const one = try browser.createTab(.{ .url = "data:text/html,<title>one</title>" });
    const two = try browser.createTab(.{ .url = "data:text/html,<title>two</title>" });
    try waitForLoad(browser, one);
    try waitForLoad(browser, two);

    try browser.closeTab(one, .{});
    try testing.expectError(error.NoSuchTab, browser.closeTab(one, .{}));
    try testing.expect(browser.tabRealm(one) == null);

    try browser.navigateTraversable(two, "data:text/html,<title>three</title>");
    try waitForLoad(browser, two);
    const title = try evaluateIn(try tabContext(browser, two), "document.title");
    defer testing.allocator.free(title);
    try testing.expectEqualStrings("three", title);

    try browser.closeTab(two, .{});
    try testing.expectEqual(@as(usize, 1), browser.traversableCount());
}

test "closing a tab unloads it: pagehide and unload fire, beforeunload only when prompting" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.loadHTML("<!doctype html><title>reader</title>", .{ .base_url = "http://example.test/reader.html" });

    const markup =
        \\<!doctype html><script>
        \\for (const type of ['beforeunload', 'pagehide', 'unload'])
        \\  addEventListener(type, () => { localStorage.log = (localStorage.log || '') + type + ','; });
        \\</script>
    ;
    // Closed without prompting (CDP Target.closeTarget, BiDi's default).
    const quiet = try browser.createTab(.{});
    try (try tabContext(browser, quiet)).loadHTML(markup, .{ .base_url = "http://example.test/quiet.html" });
    try browser.closeTab(quiet, .{});
    const quiet_log = try evaluateIn(page, "localStorage.log");
    defer testing.allocator.free(quiet_log);
    try testing.expectEqualStrings("pagehide,unload,", quiet_log);

    // Closed prompting to unload (CDP Page.close, promptUnload true).
    try page.runScript("localStorage.log = '';");
    const prompted = try browser.createTab(.{});
    try (try tabContext(browser, prompted)).loadHTML(markup, .{ .base_url = "http://example.test/prompted.html" });
    try browser.closeTab(prompted, .{ .prompt_unload = true });
    const prompted_log = try evaluateIn(page, "localStorage.log");
    defer testing.allocator.free(prompted_log);
    try testing.expectEqualStrings("beforeunload,pagehide,unload,", prompted_log);
}

test "Browser.navigate closes the page it replaces: beforeunload, pagehide and unload fire before the fresh page (N7)" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML(
        \\<!doctype html><script>
        \\localStorage.log = '';
        \\for (const type of ['beforeunload', 'pagehide', 'unload'])
        \\  addEventListener(type, () => { localStorage.log += type + ','; });
        \\</script>
    , .{ .base_url = "http://example.test/old.html" });

    try browser.navigateWithOptions("about:blank", .window, .{ .skip_load = true });
    const fresh = browser.current_context.?;
    try fresh.loadHTML("<!doctype html>", .{ .base_url = "http://example.test/new.html" });
    const log_text = try evaluateIn(fresh, "localStorage.log");
    defer testing.allocator.free(log_text);
    try testing.expectEqualStrings("beforeunload,pagehide,unload,", log_text);
}

test "a held tab stays on its initial about:blank until the host releases it" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const tab = try browser.createTab(.{ .url = "data:text/html,<title>released</title>", .hold_first_navigation = true });
    try testing.expect(browser.isTabHeld(tab));
    try browser.runEventLoop(50);
    // Parked at the navigation observer's hold point, before its fetch: the
    // tab still shows its initial about:blank document.
    const state = browser.traversableState(tab).?;
    try testing.expect(state.initial_about_blank);

    browser.releaseTab(tab);
    try testing.expect(!browser.isTabHeld(tab));
    try waitForLoad(browser, tab);
    const title = try evaluateIn(try tabContext(browser, tab), "document.title");
    defer testing.allocator.free(title);
    try testing.expectEqualStrings("released", title);
}

test "the host hears a tab created before its first navigation and destroyed after it closed" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    var heard: Heard = .{};
    defer heard.deinit();
    try browser.addListener(heard.listener());
    defer browser.removeListener(heard.listener());

    const tab = try browser.createTab(.{ .url = "data:text/html,x" });
    try browser.closeTab(tab, .{});
    try testing.expectEqualStrings("cd", heard.events.items);
    try testing.expectEqualSlices(Browser.TabId, &.{ tab, tab }, heard.tabs.items);
}

test "evaluateInTab answers BiDi RemoteValues, exception details, and an awaited promise's value" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const tab = try browser.createTab(.{});

    var sum: Answer = .{};
    defer sum.deinit();
    browser.evaluateInTab(tab, "1 + 1", .{}, sum.callback());
    try testing.expect(sum.done);
    try testing.expectEqualStrings("{\"type\":\"number\",\"value\":2}", sum.json.?);

    var array: Answer = .{};
    defer array.deinit();
    browser.evaluateInTab(tab, "['a', true, null]", .{}, array.callback());
    try testing.expectEqualStrings("{\"type\":\"array\",\"value\":[{\"type\":\"string\",\"value\":\"a\"},{\"type\":\"boolean\",\"value\":true},{\"type\":\"null\"}]}", array.json.?);

    var thrown: Answer = .{};
    defer thrown.deinit();
    browser.evaluateInTab(tab, "throw new TypeError('nope')", .{}, thrown.callback());
    try testing.expect(thrown.kind.? == .exception);
    try testing.expect(std.mem.indexOf(u8, thrown.json.?, "nope") != null);

    var awaited: Answer = .{};
    defer awaited.deinit();
    browser.evaluateInTab(tab, "new Promise((resolve) => setTimeout(() => resolve('later'), 0))", .{ .await_promise = true }, awaited.callback());
    try testing.expect(!awaited.done);
    try testing.expectEqual(Browser.SpinOutcome.met, try browser.spinEventLoopUntil(.{ .context = &awaited, .met = Answer.met }, 5_000));
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"later\"}", awaited.json.?);

    var missing: Answer = .{};
    defer missing.deinit();
    browser.evaluateInTab(tab + 1_000_000, "1", .{}, missing.callback());
    try testing.expectEqual(@as(?anyerror, error.NoSuchTab), missing.err);
}

test "an awaited evaluation whose tab closes first is told its realm ended" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const tab = try browser.createTab(.{});
    var pending: Answer = .{};
    defer pending.deinit();
    browser.evaluateInTab(tab, "new Promise(() => {})", .{ .await_promise = true }, pending.callback());
    try testing.expect(!pending.done);
    try browser.closeTab(tab, .{});
    // The realm's end drops the reaction (now, or at the agent's end).
    try browser.runEventLoop(20);
    try testing.expect(pending.done);
    try testing.expectEqual(@as(?anyerror, error.RealmEnded), pending.err);
}

test "navigableTree lists every tab with its frames, and a root's subtree to a depth" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const tab = try browser.createTab(.{});
    try (try tabContext(browser, tab)).loadHTML("<!doctype html><iframe srcdoc='<iframe></iframe>'></iframe>", .{ .base_url = "http://example.test/frames.html" });
    try browser.runEventLoop(100);

    const tree = try browser.navigableTree(testing.allocator, null, null);
    defer Browser.freeNavigableTree(testing.allocator, tree);
    try testing.expectEqual(@as(usize, 2), tree.len);
    try testing.expectEqual(tab, tree[1].id);
    try testing.expectEqual(@as(usize, 1), tree[1].children.len);
    try testing.expectEqual(@as(?u64, tab), tree[1].children[0].parent);
    try testing.expectEqual(@as(usize, 1), tree[1].children[0].children.len);

    const shallow = try browser.navigableTree(testing.allocator, tab, 0);
    defer Browser.freeNavigableTree(testing.allocator, shallow);
    try testing.expectEqual(@as(usize, 1), shallow.len);
    try testing.expectEqual(@as(usize, 0), shallow[0].children.len);
    try testing.expectError(error.NoSuchTab, browser.navigableTree(testing.allocator, tab + 1_000_000, null));
}

test "the first page closes like any tab, and the Browser lives on with the others" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const first = browser.hostTraversableId().?;
    const tab = try browser.createTab(.{ .url = "data:text/html,<title>kept</title>" });
    try waitForLoad(browser, tab);
    try browser.closeTab(first, .{});
    try testing.expect(browser.current_context == null);
    try testing.expectEqual(@as(?Browser.TabId, tab), browser.activeTab());
    const title = try evaluateIn(try tabContext(browser, tab), "document.title");
    defer testing.allocator.free(title);
    try testing.expectEqualStrings("kept", title);
}

test "with the first page closed, a host tab navigates and closes - its realms end with no page entered for its life (lane tpg)" {
    // No realm is entered for its life once the first page closes: the
    // navigation's task detaches the tab's old realm, and closeTab ends the
    // new one, each with no isolate current (protocol_realms enterForEnd).
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const first = browser.hostTraversableId().?;
    const tab = try browser.createTab(.{ .url = "data:text/html,<title>one</title>" });
    try waitForLoad(browser, tab);
    try browser.closeTab(first, .{});

    try browser.navigateTraversable(tab, "data:text/html,<title>two</title>");
    try waitForLoad(browser, tab);
    const title = try evaluateIn(try tabContext(browser, tab), "document.title");
    defer testing.allocator.free(title);
    try testing.expectEqualStrings("two", title);

    try browser.closeTab(tab, .{});
    try testing.expectEqual(@as(usize, 0), browser.traversableCount());
}
