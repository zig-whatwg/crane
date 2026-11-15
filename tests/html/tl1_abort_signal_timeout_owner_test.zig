//! AbortSignal.timeout()'s timer data is freed however its timer ends (lane tl1).
//!
//! DOM "AbortSignal.timeout(milliseconds)" step 3 runs steps after a timeout; the implementation arms a
//! native timer with a heap record (the signal, the allocator, the timer). The record is freed when the timer
//! fires, or by the signal's own end, which cancels the timer. These tests end the Browser with the timer
//! still pending, from each kind of realm a signal can be made in, and after the realm that made it has gone.
//!
//! The Browser is made with std.testing.allocator, so a record nobody freed fails the test as a leak.

const std = @import("std");
const h = @import("tl1_pending_timer_helpers.zig");

const Where = enum {
    /// The page's own window.
    page,
    /// A same-origin frame's window.
    frame,
    /// A frame removed from its document after the signal was made: its realm ended first.
    removed_frame,
    /// The same, with the event loop turned after the removal.
    removed_frame_then_turn,
    /// A dedicated worker's global scope.
    worker,
    /// A dedicated worker terminated by its owner after the signal was made.
    terminated_worker,
};

const worker_source =
    \\"self.kept = AbortSignal.timeout(600000); AbortSignal.timeout(600000); postMessage('armed');"
;

fn exercise(comptime where: Where) !void {
    const page = try h.Page.open("<!doctype html><body><iframe></iframe></body>", "http://127.0.0.1:65533/start");
    defer page.close();
    switch (where) {
        .page => try page.run(
            \\globalThis.kept = AbortSignal.timeout(600000);
            \\AbortSignal.timeout(600000);
        ),
        .frame, .removed_frame, .removed_frame_then_turn => {
            try page.run(h.frame_window ++
                \\globalThis.kept = frame.AbortSignal.timeout(600000);
                \\frame.AbortSignal.timeout(600000);
            );
            if (where != .frame) try page.run("document.querySelector('iframe').remove();");
            if (where == .removed_frame_then_turn) try page.turn(30);
        },
        .worker, .terminated_worker => {
            try page.run("globalThis.state = 'pending';\n" ++
                "globalThis.worker = new Worker(URL.createObjectURL(new Blob([" ++ worker_source ++ "], { type: 'text/javascript' })));\n" ++
                \\worker.onmessage = e => { state = e.data; };
                \\worker.onerror = () => { state = 'worker error'; };
            );
            try page.waitForState("armed");
            if (where == .terminated_worker) {
                try page.run("worker.terminate();");
                try page.turn(30);
            }
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

test "AbortSignal.timeout pending at the Browser's end: the page's signals" {
    try check(.page);
}

test "AbortSignal.timeout pending at the Browser's end: a frame's signals" {
    try check(.frame);
}

test "AbortSignal.timeout pending when its frame is removed, then the Browser ends" {
    try check(.removed_frame);
}

test "AbortSignal.timeout pending when its frame is removed, the loop turns, then the Browser ends" {
    try check(.removed_frame_then_turn);
}

test "AbortSignal.timeout pending at the Browser's end: a dedicated worker's signals" {
    try check(.worker);
}

test "AbortSignal.timeout pending when its worker is terminated, then the Browser ends" {
    try check(.terminated_worker);
}

test "AbortSignal.timeout that comes due aborts its signal with a TimeoutError" {
    try h.onFreshThread(struct {
        fn body() !void {
            const page = try h.Page.open("<!doctype html><body></body>", "http://127.0.0.1:65533/start");
            defer page.close();
            try page.run(
                \\globalThis.state = 'pending';
                \\const signal = AbortSignal.timeout(1);
                \\signal.onabort = () => { state = signal.reason.name; };
                \\// One nobody keeps aborts all the same, and frees its record when it does.
                \\AbortSignal.timeout(1);
            );
            try page.waitForState("TimeoutError");
        }
    }.body);
}

test "AbortSignal.timeout whose timer ends before its signal: the timer's end frees its data" {
    // The path no real Browser teardown takes today (a realm ends before its loop's timers), shown with a
    // timer that ends first: the plain form left the record to a signal whose teardown then cleared a
    // timer that was gone - on a real timer manager, a call into freed memory.
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
                    \\globalThis.kept = AbortSignal.timeout(600000);
                    \\AbortSignal.timeout(600000);
                );
            }
            try h.endTimerThenBrowser(page, &timer, 2);
        }
    }.body);
}
