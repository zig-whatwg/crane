//! A document that runs an editing command frees its editor state when its
//! environment ends (lane leaks6, item 3).
//!
//! The first family a sweep's per-file leak attribution named: 1-2
//! allocations per document that ran editing - 120 B, and 160 B more for the
//! first in the process (trusted-types/Document-execCommand.html,
//! block-Document-execCommand.html, the selection/ files that type into an
//! input). html/editing/executor.zig keeps an EditorState per document in a
//! map keyed by the document's address, and nothing ever removed one:
//! `cleanupEditorState` had no caller, and the map's own buffer was never
//! freed.
//!
//! The state now lives on its Document (dom.document_internals.editorState)
//! and goes with it (dom.editor_states). The tests: frames run a command the
//! editing module handles and are removed, the page does too, and the
//! Browser ends - its own leak-checking allocator is the verdict; two
//! Browsers on two threads do the same at once (the map was unlocked and
//! process-global); a new document at a removed one's address starts with
//! no editor state; and Document stays in its allocation class.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const Browser = @import("browser").Browser;
const document_size_class = @import("document_size_class.zig");

const page_url = "https://leaks6.test/page.html";

fn ignoreReport(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn run() !void {
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    {
        const browser = try Browser.init(debug.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body contenteditable><p>text</p>", .{ .base_url = page_url });
        const realm = browser.getRealm() orelse return error.NoRealm;
        const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 =
            \\(() => {
            \\  for (let i = 0; i < 4; ++i) {
            \\    const f = document.body.appendChild(document.createElement('iframe'));
            \\    const d = f.contentDocument;
            \\    d.body.contentEditable = 'true';
            \\    for (const c of ['undo', 'redo', 'delete', 'selectAll']) d.execCommand(c);
            \\    f.remove();
            \\  }
            \\  for (const c of ['undo', 'redo', 'delete', 'selectAll']) document.execCommand(c);
            \\  return 'ran';
            \\})()
        }, "", null, std.testing.allocator, .{ .report = ignoreReport });
        defer std.testing.allocator.free(got);
        try std.testing.expectEqualStrings("ran", got);
        for (0..5) |_| _ = try browser.runEventLoopBlocking(10);
    }
    if (debug.deinit() == .leak) return error.Leaked;
}

test "leaks6 editing: a document's editor state is freed when its environment ends" {
    const Run = struct {
        fn main(failure: *?anyerror) void {
            run() catch |err| {
                std.debug.print("the editing run failed: {s}\n", .{@errorName(err)});
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.main, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "leaks6 editing: two Browsers on two threads run editing commands at once, and neither leaks" {
    const Side = struct {
        failure: ?anyerror = null,
        fn main(self: *@This()) void {
            run() catch |err| {
                std.debug.print("an editing side failed: {s}\n", .{@errorName(err)});
                self.failure = err;
            };
        }
    };
    var sides: [2]Side = .{ .{}, .{} };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*t, *side| t.* = try std.Thread.spawn(.{}, Side.main, .{side});
    for (threads) |t| t.join();
    for (sides) |side| if (side.failure) |err| return err;
}

fn frameDocument(page: anytype, realm: runtime.Context) !*runtime.Instance {
    const owned = try page.evaluateScript("window.f.contentDocument");
    defer owned.release();
    return engine.convertToPlatformObject(realm, owned.value) orelse error.NoDocument;
}

fn reusedAddress() !void {
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    {
        const browser = try Browser.init(debug.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
        const realm = browser.getRealm() orelse return error.NoRealm;
        try page.runScript("window.f = document.body.appendChild(document.createElement('iframe')); f.contentDocument.execCommand('undo');");
        const edited = try frameDocument(page, realm);
        try std.testing.expect(dom.document_internals.editorState(edited) != null);
        const edited_address = @intFromPtr(edited);
        try page.runScript("f.remove(); window.f = null;");
        var reused = false;
        for (0..64) |_| {
            _ = try browser.runEventLoopBlocking(5);
            try page.runScript("if (window.f) f.remove(); window.f = document.body.appendChild(document.createElement('iframe'));");
            const fresh = try frameDocument(page, realm);
            if (@intFromPtr(fresh) != edited_address) continue;
            reused = true;
            // The map kept the old document's state under this address.
            try std.testing.expect(dom.document_internals.editorState(fresh) == null);
            break;
        }
        if (!reused) std.debug.print("leaks6 editing: no new document took the removed one's address in 64 frames\n", .{});
    }
    if (debug.deinit() == .leak) return error.Leaked;
}

test "leaks6 editing: a new document at a removed one's address starts with no editor state" {
    const Run = struct {
        fn main(failure: *?anyerror) void {
            reusedAddress() catch |err| {
                std.debug.print("the reused-address run failed: {s}\n", .{@errorName(err)});
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.main, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "leaks6 editing: Document's state stays in its allocation class with the editor state pointer" {
    // Lane style4 left it at about 2,000 B, in the 2,048-B class; the
    // editor state is one pointer. Crane's own layout
    // (document_size_class.zig: under runtime safety, Zig 0.17's ArrayList
    // adds a SafetyLock word per list, which that file counts; the real
    // 2,160-B / 4,096-class cost in Debug and ReleaseSafe goes to the
    // post-port performance analysis).
    const State = dom.document_internals.InternalState;
    const size = document_size_class.ownLayoutBytes(State);
    if (size > document_size_class.class_bytes) std.debug.print("Document's InternalState is {d} B ({d} B with std's safety locks)\n", .{ size, @sizeOf(State) });
    try std.testing.expect(size <= document_size_class.class_bytes);
}
