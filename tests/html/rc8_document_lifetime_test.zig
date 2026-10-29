//! Lane refcount8, refcount step 5i: a Window holds its associated Document
//! counted (Window.document_ref), and the window keeps the document's
//! wrapper with one counted keep from setDefaultView until "destroy a
//! document" clears the view (Document.window_kept) - beside the wrapper
//! cache's default-view rule, which keeps it the same way until step 9(d)
//! deletes that rule. SHADOW MODE: neither may change when a document is
//! freed. A document replaced in its Window, and a removed frame's document,
//! must still go once script lets them go.
const std = @import("std");
const h = @import("refcount_holders_helpers.zig");
const dom = h.dom;
const runtime = h.runtime;
const onFreshThread = h.onFreshThread;

/// The document `source` evaluates to, as its instance and its slab
/// generation now (nothing of script keeps it after this).
const Watched = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn freed(self: Watched) bool {
        return runtime.SlabAllocator.generationOf(self.instance) != self.generation;
    }
};

fn watch(page: h.Page, source: []const u8) !Watched {
    const base = try page.node(source);
    const instance: *runtime.Instance = @ptrCast(@alignCast(base.owner_instance.?));
    return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
}

/// Turn the loop and collect until `watched` is freed, or give up.
fn freedSoon(page: h.Page, watched: Watched) !bool {
    var turns: usize = 0;
    while (turns < 40) : (turns += 1) {
        if (watched.freed()) return true;
        _ = try page.browser.runEventLoopBlocking(10);
        try page.collect();
    }
    return watched.freed();
}

fn removedFrameDocumentIsFreed() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.frame = document.body.appendChild(document.createElement('iframe')); 0;");
    const document = try watch(page, "frame.contentDocument");
    try std.testing.expect(!document.freed());
    try page.run("frame.remove(); globalThis.frame = null; 0;");
    try std.testing.expect(try freedSoon(page, document));
}

test "a removed frame's document is still freed once script lets it go" {
    try onFreshThread(removedFrameDocumentIsFreed);
}

fn replacedDocumentIsFreed() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.frame = document.body.appendChild(document.createElement('iframe')); 0;");
    // The frame's initial about:blank document, which a same-origin
    // navigation replaces in the same Window (HTML "create and initialize a
    // Document object" step 6): the Window lets go of it, and "destroy a
    // document" ends the window's keep.
    const initial = try watch(page, "frame.contentDocument");
    try page.run("frame.srcdoc = '<p id=next>next</p>'; 0;");
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        page.run("if (!frame.contentDocument || !frame.contentDocument.getElementById('next')) throw new Error('not yet'); 0;") catch {
            _ = try page.browser.runEventLoopBlocking(10);
            continue;
        };
        break;
    }
    try page.run("if (!frame.contentDocument.getElementById('next')) throw new Error('never navigated'); 0;");
    try std.testing.expect(try freedSoon(page, initial));
}

test "a document its Window replaced is still freed once script lets it go" {
    try onFreshThread(replacedDocumentIsFreed);
}
