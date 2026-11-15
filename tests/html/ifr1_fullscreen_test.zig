//! Lane ifr1: the Fullscreen API's DOM part (html.fullscreen) - the
//! fullscreen flag on a top-layer entry, the document's fullscreen element,
//! the pending fullscreen events fired at "update the rendering" step 12,
//! :fullscreen, fullscreenEnabled from the permissions policy - and the
//! lifetimes: an element in fullscreen removed, and a document torn down
//! with an element in fullscreen and events still pending, leave nothing
//! behind under std.testing.allocator.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const html = @import("html");
const dom = @import("dom");
const runtime = @import("runtime");

fn pumpUntil(page: helpers.Page, condition: []const u8, turns: usize) !void {
    var turn: usize = 0;
    while (turn < turns) : (turn += 1) {
        _ = try page.browser.runEventLoopBlocking(5);
        const value = try page.evaluate(condition);
        defer std.testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
    }
    const value = try page.evaluate(condition);
    defer std.testing.allocator.free(value);
    std.debug.print("condition never held: {s} -> {s}\n", .{ condition, value });
    return error.ConditionNeverHeld;
}

fn expectValue(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const value = try page.evaluate(source);
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualStrings(expected, value);
}

fn document(page: helpers.Page) *runtime.Instance {
    return page.browser.current_context.?.document_instance.?;
}

/// A trusted activation of the page, as a user's click is.
fn activate(page: helpers.Page) void {
    html.user_activation.notifyActivation(document(page));
}

fn enterAndExit() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try expectValue(page, "String(document.fullscreenEnabled)", "true");
    try page.run(
        \\globalThis.log = [];
        \\globalThis.div = document.body.appendChild(document.createElement('div'));
        \\document.onfullscreenchange = e => log.push('change:' + (e.target === div) + ':' + e.bubbles + ':' + e.composed + ':' + (document.fullscreenElement === div));
        \\globalThis.entered = false;
    );
    activate(page);
    try page.run(
        \\div.requestFullscreen().then(() => { log.push('resolved'); entered = true; });
        \\log.push('after:' + document.fullscreenElement);
    );
    try pumpUntil(page, "entered && log.length >= 3", 400);
    try expectValue(page, "log.join()", "after:null,resolved,change:true:true:true:true");
    try expectValue(page, "String(document.fullscreen)", "true");
    try expectValue(page, "String(div.matches(':fullscreen'))", "true");
    try expectValue(page, "String(document.body.matches(':fullscreen'))", "false");
    try expectValue(page, "getComputedStyle(div).position", "fixed");
    try page.run(
        \\log = [];
        \\globalThis.exited = false;
        \\document.exitFullscreen().then(() => { log.push('exit-resolved:' + document.fullscreenElement); exited = true; });
        \\log.push('exit-after:' + (document.fullscreenElement === div));
    );
    try pumpUntil(page, "exited && log.length >= 3", 400);
    try expectValue(page, "log.join()", "exit-after:true,exit-resolved:null,change:true:true:true:false");
    try expectValue(page, "String(div.matches(':fullscreen'))", "false");
}

test "requestFullscreen with transient activation makes the element fullscreen, and exitFullscreen ends it" {
    try helpers.onFreshThread(enterAndExit);
}

fn deniedWithoutActivation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.log = [];
        \\globalThis.div = document.body.appendChild(document.createElement('div'));
        \\document.onfullscreenerror = e => log.push('error:' + (e.target === div));
        \\div.requestFullscreen().catch(e => log.push('rejected:' + e.name));
        \\document.createElement('dialog').requestFullscreen().catch(e => log.push('detached:' + e.name));
        \\document.exitFullscreen().catch(e => log.push('exit:' + e.name));
    );
    try pumpUntil(page, "log.length >= 4", 400);
    try expectValue(page, "log.slice(0, 3).sort().join()", "detached:TypeError,exit:TypeError,rejected:TypeError");
    try expectValue(page, "log[3]", "error:true");
    try expectValue(page, "String(document.fullscreenElement)", "null");
}

test "requestFullscreen without transient activation rejects and fires fullscreenerror" {
    try helpers.onFreshThread(deniedWithoutActivation);
}

fn removedFullscreenElement() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.div = document.body.appendChild(document.createElement('div'));
        \\globalThis.entered = false;
    );
    activate(page);
    try page.run("div.requestFullscreen().then(() => { entered = true; })");
    try pumpUntil(page, "entered && document.fullscreenElement === div", 400);
    try page.run(
        \\globalThis.changes = [];
        \\document.onfullscreenchange = e => changes.push(e.target === document);
        \\div.remove();
    );
    // The removing steps exit fullscreen at once: the element is not in the
    // top layer, and the change event goes to the document.
    try expectValue(page, "String(document.fullscreenElement)", "null");
    try pumpUntil(page, "changes.length === 1", 400);
    try expectValue(page, "String(changes[0])", "true");
    const state = (try dom.top_layer.ofDocument(document(page), false)).?;
    try std.testing.expectEqual(@as(usize, 0), state.fullscreenCount());
    try std.testing.expectEqual(@as(usize, 0), state.fullscreen_events.items.len);
    // Nothing holds the removed element now: it can be collected.
    try page.run("globalThis.weak = new WeakRef(div); div = null;");
    try page.turn();
    try page.run("collectNow()");
    try page.turn();
    try page.run("if (weak.deref() !== undefined) throw new Error('the removed fullscreen element was kept')");
}

test "a fullscreen element removed exits fullscreen and is let go" {
    try helpers.onFreshThread(removedFullscreenElement);
}

fn enterFullscreen(page: helpers.Page) !void {
    try page.run(
        \\globalThis.div = document.body.appendChild(document.createElement('div'));
        \\globalThis.changed = false;
        \\document.onfullscreenchange = () => { changed = true; };
    );
    activate(page);
    try page.run("div.requestFullscreen()");
    try pumpUntil(page, "changed && document.fullscreenElement === div", 400);
}

fn teardownInFullscreen() !void {
    // A document torn down with an element in fullscreen: its top-layer
    // entry is released with the document.
    const page = try helpers.Page.open();
    defer page.close();
    try enterFullscreen(page);
    const state = (try dom.top_layer.ofDocument(document(page), false)).?;
    try std.testing.expectEqual(@as(usize, 1), state.fullscreenCount());
}

fn teardownWhilePending() !void {
    // A document torn down with a fullscreenchange event pending and exit
    // fullscreen's task still queued: the list's hold, the task's hold and
    // its promise capability are released with the document and its loop.
    const page = try helpers.Page.open();
    defer page.close();
    try enterFullscreen(page);
    try page.run("div.remove()");
    const state = (try dom.top_layer.ofDocument(document(page), false)).?;
    try std.testing.expectEqual(@as(usize, 0), state.fullscreenCount());
    try std.testing.expectEqual(@as(usize, 1), state.fullscreen_events.items.len);
    // And a request whose task has not run yet.
    try page.run("globalThis.other = document.body.appendChild(document.createElement('p'))");
    activate(page);
    try page.run("other.requestFullscreen()");
}

test "a document torn down with an element in fullscreen leaves nothing" {
    try helpers.onFreshThread(teardownInFullscreen);
}

test "a document torn down with a fullscreen event pending and fullscreen tasks queued leaves nothing" {
    try helpers.onFreshThread(teardownWhilePending);
}

fn pendingEventsHoldAndRelease(allocator: std.mem.Allocator, owner: *runtime.Instance, first: *runtime.Instance, second: *runtime.Instance) !void {
    var state = dom.top_layer.State.init(allocator, owner);
    defer state.deinit();
    _ = try state.addFullscreen(first);
    _ = try state.addFullscreen(second);
    // "Fullscreen an element" again moves it to the top: the fullscreen
    // element is the topmost flagged one.
    try std.testing.expect(state.fullscreenElement() == second);
    _ = try state.addFullscreen(first);
    try std.testing.expect(state.fullscreenElement() == first);
    try std.testing.expectEqual(@as(usize, 2), state.fullscreenCount());
    // An ordered set: the same tuple is not added twice.
    try state.appendFullscreenEvent(.fullscreenchange, first);
    try state.appendFullscreenEvent(.fullscreenchange, first);
    try state.appendFullscreenEvent(.fullscreenerror, first);
    try state.appendFullscreenEvent(.fullscreenchange, second);
    try std.testing.expectEqual(@as(usize, 3), state.fullscreen_events.items.len);
    const taken = try state.takeFullscreenEvents(allocator);
    defer {
        for (taken) |*event| event.hold.release();
        allocator.free(taken);
    }
    try std.testing.expectEqual(@as(usize, 0), state.fullscreen_events.items.len);
    try std.testing.expect(taken[0].hold.get() == first and taken[0].type == .fullscreenchange);
    try std.testing.expect(taken[1].type == .fullscreenerror);
    try std.testing.expect(taken[2].hold.get() == second);
    try std.testing.expect(state.removeFullscreen(first));
    try std.testing.expect(!state.removeFullscreen(first));
    try std.testing.expect(state.fullscreenElement() == second);
    // Left in the list at deinit: released there.
    try state.appendFullscreenEvent(.fullscreenchange, second);
}

fn topLayerRecords() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<div id=a></div><div id=b></div>'");
    const a = (try dom.selector_matching.querySelector(document(page), "#a")).?;
    const b = (try dom.selector_matching.querySelector(document(page), "#b")).?;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, pendingEventsHoldAndRelease, .{ document(page), a, b });
}

test "fullscreen entries and pending events hold their elements and free every failed allocation" {
    try helpers.onFreshThread(topLayerRecords);
}
