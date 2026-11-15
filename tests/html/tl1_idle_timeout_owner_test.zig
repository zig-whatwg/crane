//! A requestIdleCallback timeout's timer data is freed however its timer ends (lane tl1).
//!
//! requestIdleCallback(callback, { timeout }) steps 5-6 wait for the timeout on a native timer armed with a
//! heap record (the realm, the handle, the timer). The record is freed by the task the timer queues, or by
//! the callback's end - run in an idle period, cancelled, or its window ended - which cancels the timer.
//! These tests end the Browser with the timer still pending.
//!
//! The Browser is made with std.testing.allocator, so a record nobody freed fails the test as a leak.

const std = @import("std");
const h = @import("tl1_pending_timer_helpers.zig");

const Where = enum {
    /// The page's own window; no loop turn, so no idle period starts.
    page,
    /// A same-origin frame's window.
    frame,
    /// A frame removed from its document after the request: its window ended first.
    removed_frame,
    /// The same, with the event loop turned after the removal.
    removed_frame_then_turn,
    /// The request cancelled by script before the Browser ends.
    cancelled,
};

fn exercise(comptime where: Where) !void {
    const page = try h.Page.open("<!doctype html><body><iframe></iframe></body>", "http://127.0.0.1:65533/start");
    defer page.close();
    switch (where) {
        .page => try page.run(
            \\requestIdleCallback(() => {}, { timeout: 600000 });
            \\requestIdleCallback(() => {}, { timeout: 600001 });
        ),
        .cancelled => try page.run(
            \\const handle = requestIdleCallback(() => {}, { timeout: 600000 });
            \\requestIdleCallback(() => {}, { timeout: 600001 });
            \\cancelIdleCallback(handle);
        ),
        .frame, .removed_frame, .removed_frame_then_turn => {
            try page.run(h.frame_window ++
                \\frame.requestIdleCallback(() => {}, { timeout: 600000 });
                \\frame.requestIdleCallback(() => {}, { timeout: 600001 });
            );
            if (where != .frame) try page.run("document.querySelector('iframe').remove();");
            if (where == .removed_frame_then_turn) try page.turn(30);
        },
    }
}

fn check(comptime where: Where) !void {
    try h.onFreshThread(struct {
        fn body() !void {
            try exercise(where);
        }
    }.body);
}

test "an idle callback's timeout pending at the Browser's end: the page's requests" {
    try check(.page);
}

test "an idle callback's timeout pending at the Browser's end: a frame's requests" {
    try check(.frame);
}

test "an idle callback's timeout pending when its frame is removed, then the Browser ends" {
    try check(.removed_frame);
}

test "an idle callback's timeout pending when its frame is removed, the loop turns, then the Browser ends" {
    try check(.removed_frame_then_turn);
}

test "an idle callback cancelled with its timeout pending, then the Browser ends" {
    try check(.cancelled);
}

test "an idle callback runs once: in an idle period, its timeout cancelled" {
    try h.onFreshThread(struct {
        fn body() !void {
            const page = try h.Page.open("<!doctype html><body></body>", "http://127.0.0.1:65533/start");
            defer page.close();
            try page.run(
                \\globalThis.state = 'pending';
                \\globalThis.runs = 0;
                \\requestIdleCallback((deadline) => { runs += 1; state = 'ran ' + runs + ' timed out ' + deadline.didTimeout; }, { timeout: 600000 });
            );
            try page.waitForState("ran 1 timed out false");
        }
    }.body);
}

test "an idle callback's timeout whose timer ends before its window: the timer's end frees its data" {
    // Shown with a timer that ends first: the plain form left the record to a window whose end frees it
    // only after a successful clear - and a timer that has ended clears nothing, so nobody freed it.
    try h.onFreshThread(struct {
        fn body() !void {
            var timer: h.EndingTimer = .{};
            const page = try h.Page.open("<!doctype html><body></body>", "http://127.0.0.1:65533/start");
            {
                errdefer page.close();
                const realm = try page.realm();
                const saved = realm.timer;
                realm.timer = timer.interface();
                defer realm.timer = saved;
                try page.run(
                    \\requestIdleCallback(() => {}, { timeout: 600000 });
                    \\requestIdleCallback(() => {}, { timeout: 600001 });
                );
            }
            try h.endTimerThenBrowser(page, &timer, 2);
        }
    }.body);
}
