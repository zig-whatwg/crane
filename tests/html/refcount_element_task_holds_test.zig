//! Lane refcount6 (refcount step 5d): what element tasks hold of the
//! elements they will fire at - image, media, script, style sheet and
//! embedded content fetch completions, the details toggle task.
//!
//! Each holds its element with refcount design 2.4's GCReachableRef in
//! shadow mode: the pending-activity keep it always had (or a TaskHold's, for
//! a task that had none) plus ONE counted reference, from the moment the work
//! begins to its end - it runs, is cancelled, or is dropped. WebKit:
//! ImageLoader's `RefPtr<Element> m_protectedElement` while an event is
//! pending (loader/ImageLoader.h), ScriptElement's
//! queueTaskKeepingObjectAlive (dom/ScriptElement.cpp), PendingScript's
//! `Ref<ScriptElement>`, ToggleEventTask's queueTaskKeepingThisNodeAlive.
//!
//! Counts through dom.refcount.count: born (1: script made these elements,
//! and createElement keeps its born reference until step 6) + the wrapper's
//! (1, a global keeps it) + the task's.
const std = @import("std");
const testing = std.testing;
const h = @import("refcount_holders_helpers.zig");
const dom = h.dom;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

const gif = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";

/// Turn the page's event loop until `done` (a script expression) is true,
/// then collect: the event a listener was handed (a wrapper) holds its target
/// counted until it is freed (refcount step 5g), which says nothing of the
/// task's hold.
fn runUntil(page: h.Page, comptime done: []const u8) !void {
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        page.run("if (!(" ++ done ++ ")) throw new Error('not yet');") catch {
            _ = try page.browser.runEventLoopBlocking(10);
            continue;
        };
        try page.collect();
        return;
    }
    return error.NeverDone;
}

fn imageUpdateCountsItsElement() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.loaded = 0; globalThis.img = new Image(); img.onload = () => { loaded += 1; }; 0;");
    const img = try page.node("img");
    try expectCount(2, img, "an img no update has started for");
    try page.run("img.src = '" ++ gif ++ "'; 0;");
    try expectCount(3, img, "its update of the image data runs: the update's counted reference");
    try runUntil(page, "loaded === 1");
    try expectCount(2, img, "the load event's task ran: the update let go");
}

test "an img's update of the image data holds its element with one counted reference until its event task ran" {
    try onFreshThread(imageUpdateCountsItsElement);
}

fn queuedScriptErrorCountsItsElement() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.errors = 0;
        \\globalThis.s = document.createElement('script');
        \\s.onerror = () => { errors += 1; };
        \\s.setAttribute('src', '');
        \\0;
    );
    const s = try page.node("s");
    try expectCount(2, s, "a script element not yet prepared");
    try page.run("document.body.appendChild(s); s.remove(); 0;");
    try expectCount(3, s, "its error event is queued (prepare step 33.3): the task's TaskHold");
    try runUntil(page, "errors === 1");
    try expectCount(2, s, "the task ran: its hold ended");
}

test "a script's queued error event task holds its element until it ran" {
    try onFreshThread(queuedScriptErrorCountsItsElement);
}

fn externalScriptCountsItsElement() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.ran = 0;
        \\globalThis.s = document.createElement('script');
        \\s.src = 'data:text/javascript,ran%20%2B%3D%201';
        \\0;
    );
    const s = try page.node("s");
    try expectCount(2, s, "not yet prepared");
    try page.run("document.body.appendChild(s); 0;");
    // The fetch's GCReachableRef and the document queue's execution hold.
    try expectCount(4, s, "fetching, and in its document's as-soon-as-possible set");
    try runUntil(page, "ran === 1");
    try expectCount(2, s, "fetched, delivered and executed: every hold let go");
}

test "an external script's fetch and its document queue each hold the element counted until it executed" {
    try onFreshThread(externalScriptCountsItsElement);
}

fn styleSheetEventCountsItsElement() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.events = 0;
        \\globalThis.link = document.createElement('link');
        \\link.rel = 'stylesheet';
        \\link.onload = () => { events += 1; };
        \\link.onerror = () => { events += 1; };
        \\link.href = 'data:text/css,p%7Bcolor:red%7D';
        \\document.head.appendChild(link);
        \\0;
    );
    const link = try page.node("link");
    try runUntil(page, "events === 1");
    try expectCount(2, link, "its load event's task ran: the task's counted reference ended");
}

test "a style sheet's event task lets go of its element's counted reference when it ran" {
    try onFreshThread(styleSheetEventCountsItsElement);
}

fn queuedTasksAtThePagesEnd() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.img = new Image(); img.src = '
    ++ gif ++
        \\';
        \\globalThis.s = document.createElement('script'); s.setAttribute('src', ''); document.body.appendChild(s);
        \\0;
    );
    try expectCount(3, try page.node("img"), "update pending");
    try expectCount(3, try page.node("s"), "error event pending");
    // The page ends with every task still queued: each lets go once (an
    // underflow is an error log, which fails the test).
}

test "element tasks still queued at the page's end let go of their elements once" {
    try onFreshThread(queuedTasksAtThePagesEnd);
}
