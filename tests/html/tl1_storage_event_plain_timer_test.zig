//! A `storage` event's task is never armed on a plain timer (lane tl1).
//!
//! The task owns four allocations, and a plain timer's data is freed by nobody when the timer never fires
//! (docs/lessons/architecture-a-task-queued-on-a-loop-that-never-runs-again-leaks-its-data.md). Lane wrap1
//! armed it with the owned form (tests/html/wrap1_storage_event_task_owner_test.zig) and kept one fallback:
//! a timer that cannot promise the drop got the task on the plain form - the same leak, for such a timer.
//! Every real timer (NativeTimerManager) has the owned form; a timer without it now gets no task, as a
//! realm with no timer gets none.
//!
//! Since the storage event is a task of the remote window's event loop (tl1_storage_event_task_order_test.zig)
//! the timer is used only for a realm with no event loop.
//!
//! Here the remote window's realm has no event loop and a timer with the plain form only. The page changes
//! its storage three times; nothing may be armed on that timer.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const h = @import("tl1_pending_timer_helpers.zig");

fn exercise() !void {
    var timer: h.EndingTimer = .{};
    // A page and a same-origin frame (an iframe with no src: about:blank, the page's origin): two documents
    // with one local storage area.
    const page = try h.Page.open("<!doctype html><body><iframe id=frame></iframe></body>", "http://127.0.0.1:65533/start");
    defer page.close();
    const context = page.browser.current_context orelse return error.NoPage;
    const document = context.document_instance orelse return error.NoDocument;
    const frame = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("frame"))) orelse return error.NoFrame;
    const frame_document = (try interfaces.HTMLIFrameElement.get_contentDocument(frame)) orelse return error.NoFrameDocument;
    const frame_realm = frame_document.ctx;
    try page.run(h.frame_window ++
        \\if (frame.localStorage.length !== 0) throw new Error('the storage area is not empty');
    );
    {
        const saved = frame_realm.timer;
        frame_realm.timer = timer.plainOnly();
        defer frame_realm.timer = saved;
        // No event loop: the task falls back to the realm's timer.
        const saved_loop = frame_realm.event_loop;
        frame_realm.event_loop = null;
        defer frame_realm.event_loop = saved_loop;
        try page.run(
            \\localStorage.setItem('closeAll', 'true');
            \\localStorage.removeItem('closeAll');
            \\localStorage.setItem('openerIsNull', 'false');
        );
    }
    // Before the fix: 3, each a task with three copies that only its callback could free.
    const armed = timer.armed();
    timer.end();
    try testing.expectEqual(@as(usize, 0), armed);
    try testing.expectEqual(@as(usize, 0), timer.plain_left);
}

test "a storage event's task is not armed on a timer that has only the plain form" {
    try h.onFreshThread(exercise);
}
