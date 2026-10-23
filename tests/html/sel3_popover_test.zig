//! Popover stack removal, document teardown and independent Browser state.
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const dom = @import("dom");
const onFreshThread = @import("edges_node_holders_helpers.zig").onFreshThread;

fn syntheticOwnButton() !void {
    const page = try @import("edges_node_holders_helpers.zig").Page.open();
    defer page.close();
    try page.run(
        \\const style = document.createElement('style');
        \\style.textContent = 'select, select::picker(select) { appearance: base-select }';
        \\document.head.append(style);
        \\const select = document.createElement('select');
        \\const button = document.createElement('button');
        \\select.append(button, document.createElement('option'));
        \\document.body.append(select);
        \\button.click();
        \\if (select.matches(':open')) throw new Error('synthetic own-button click opened the picker');
    );
}

test "synthetic click on a select's first button does not open its picker" {
    try onFreshThread(syntheticOwnButton);
}

fn openPage(allocator: std.mem.Allocator) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigateWithOptions("http://sel3.test/popovers", .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div id=root><div id=popover popover><span id=nested popover></span></div></div><div id=other popover></div>", .{ .base_url = "http://sel3.test/popovers" });
    return browser;
}

fn expectScript(browser: *browser_mod.Browser, source: []const u8) !void {
    const value = try browser.evaluateScript(source);
    defer value.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    try std.testing.expect(engine.toBoolean(realm, value.borrow()));
}

fn removal() !void {
    const browser = try openPage(std.testing.allocator);
    defer browser.deinit();
    try expectScript(browser,
        \\(() => {
        \\ const p = document.getElementById('popover');
        \\ p.showPopover(); p.remove();
        \\ return !p.matches(':popover-open');
        \\})()
    );
}

fn ancestorRemoval() !void {
    const browser = try openPage(std.testing.allocator);
    defer browser.deinit();
    try expectScript(browser,
        \\(() => {
        \\ const p = document.getElementById('popover');
        \\ const n = document.getElementById('nested');
        \\ p.showPopover(); n.showPopover();
        \\ document.getElementById('root').remove();
        \\ return !p.matches(':popover-open') && !n.matches(':popover-open');
        \\})()
    );
}

fn openAtTeardown() !void {
    const browser = try openPage(std.testing.allocator);
    defer browser.deinit();
    try expectScript(browser,
        \\(() => {
        \\ document.getElementById('popover').showPopover();
        \\ document.getElementById('nested').showPopover();
        \\ TestUtils.gc(); TestUtils.gc();
        \\ return document.getElementById('nested').matches(':popover-open');
        \\})()
    );
}

test "removing a popover closes it and releases its top-layer entry" {
    try onFreshThread(removal);
}

test "removing an ancestor closes all descendant popovers" {
    try onFreshThread(ancestorRemoval);
}

test "document teardown releases open popovers under the testing allocator" {
    try onFreshThread(openAtTeardown);
}

fn repeatedOpenClose() !void {
    const browser = try openPage(std.testing.allocator);
    defer browser.deinit();
    try expectScript(browser,
        \\(() => {
        \\ const p = document.getElementById('popover');
        \\ for (let i = 0; i < 10000; ++i) { p.showPopover(); p.hidePopover(); }
        \\ TestUtils.gc(); TestUtils.gc();
        \\ return !p.matches(':popover-open');
        \\})()
    );
    // Each show and hide queues a popover toggle event task that keeps the
    // element until it runs (HTML 6.12; node_holds.ElementTask): coalesced,
    // one is left holding it, behind the 19,999 cancelled ones. Let them
    // run (the loop returns once it is idle), then nothing may hold it.
    _ = try browser.runEventLoopBlocking(10_000);
    const document = browser.current_context.?.document_instance.?;
    const popover = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("popover"))).?;
    const base = dom.instance_bridge.getNodeBase(popover).?;
    try std.testing.expect(base.holds == null);
    const tasks = dom.node_holds.ElementTasks.existingOf(browser.getRealm().?).?;
    try std.testing.expectEqual(tasks.holds_taken, tasks.holds_released);
    try std.testing.expectEqual(tasks.queued, tasks.ended);
    const state = (try dom.top_layer.ofDocument(document, false)).?;
    try std.testing.expectEqual(@as(usize, 0), state.entries.items.len);
    try std.testing.expect(state.pointerdown_target.get() == null);
    try std.testing.expect(state.hint_parent.get() == null);
    // IDs are reused; inspect every slot used by this single-popover path.
    for ([_][]const u8{ "top_layer:0:node", "top_layer:0:source", "top_layer:0:focus", "top_layer:1:node", "top_layer:1:source", "top_layer:1:focus", "top_layer:2:node", "top_layer:2:source", "top_layer:2:focus", "top_layer:pointerdown", "top_layer:hint_parent" }) |slot| {
        if (engine.tracedValue(document, .{ .name = slot })) |value| {
            var owned = value;
            owned.release();
            return error.TracedPopoverSlotLeaked;
        }
    }
}

test "ten thousand popover transitions leave no marked holds" {
    try onFreshThread(repeatedOpenClose);
}

test "two Browsers on two threads keep independent popover stacks" {
    const Shared = struct {
        arrived: std.atomic.Value(u32) = .init(0),
        failed: std.atomic.Value(bool) = .init(false),
    };
    const Side = struct {
        shared: *Shared,
        failure: ?anyerror = null,

        fn run(self: *@This()) void {
            self.exercise() catch |err| {
                self.failure = err;
                self.shared.failed.store(true, .release);
            };
        }

        fn exercise(self: *@This()) !void {
            // Independent allocators avoid serializing the two Browsers on
            // std.testing.allocator's lock and allocation stack capture.
            var allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
            defer std.debug.assert(allocator.deinit() == .ok);
            const browser = try openPage(allocator.allocator());
            defer browser.deinit();
            try expectScript(browser, "document.getElementById('popover').showPopover(); document.getElementById('popover').matches(':popover-open')");
            _ = self.shared.arrived.fetchAdd(1, .acq_rel);
            var spins: usize = 0;
            while (self.shared.arrived.load(.acquire) < 2) : (spins += 1) {
                if (self.shared.failed.load(.acquire)) return error.OtherBrowserFailed;
                if (spins == 20_000_000) return error.OtherBrowserTimedOut;
                std.Thread.yield() catch {};
            }
            try expectScript(browser,
                \\(() => {
                \\ const first = document.getElementById('popover');
                \\ const other = document.getElementById('other');
                \\ other.showPopover();
                \\ return !first.matches(':popover-open') && other.matches(':popover-open');
                \\})()
            );
        }
    };
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .shared = &shared }, .{ .shared = &shared } };
    const first = try std.Thread.spawn(.{}, Side.run, .{&sides[0]});
    const second = std.Thread.spawn(.{}, Side.run, .{&sides[1]}) catch |err| {
        shared.failed.store(true, .release);
        first.join();
        return err;
    };
    first.join();
    second.join();
    for (sides) |side| if (side.failure) |err| return err;
}

fn orphanAfterRealmEnd() !void {
    const browser = try openPage(std.testing.allocator);
    defer browser.deinit();
    const document = browser.current_context.?.document_instance.?;
    const popover = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("popover"))).?;
    // The orphan registry can outlive its owner and realm. Exercise that
    // exit independently of Document.deinitOwn's primary cleanup path.
    var orphan = dom.top_layer.State.init(std.testing.allocator, document);
    defer orphan.releaseAfterRealmEnded();
    const entry = try orphan.pin(popover);
    entry.showing = true;
    entry.keepSource(document, popover);
    entry.keepPreviousFocus(document, popover);
    orphan.setPointerdownTarget(popover);
    orphan.setHintParent(popover);
    // Retire the page's realm while the Browser's slab still exists. A
    // generation guard is not valid after Browser.deinit frees that slab.
    try browser.navigateWithOptions("http://sel3.test/next", .window, .{ .skip_load = true });
    try std.testing.expect(orphan.owner_at_creation.get() == null);
    // The defer must unlink emptied native holds and free the state without
    // reading the ended Document/realm or calling element behavior hooks.
}

test "orphan top-layer state can be swept after its owner realm ends" {
    try onFreshThread(orphanAfterRealmEnd);
}
