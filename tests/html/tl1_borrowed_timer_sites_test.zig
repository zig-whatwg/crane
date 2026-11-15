//! The plain timers whose data is NOT a task the timer could own: each is freed by its owner on every path
//! (lane tl1).
//!
//! The leak class (docs/lessons/architecture-a-task-queued-on-a-loop-that-never-runs-again-leaks-its-data.md)
//! is heap data handed to a plain timer and freed only by its callback. These sites arm a plain timer too,
//! and are not of the class - the data is a record its owner keeps in a list of its own, or the owner itself:
//! - a window's setTimeout / setInterval record (src/browser/Context.zig scheduleTimer, the interval's
//!   re-arm, resumeWindowTimers): in the realm's map of active timers; the window's end frees every record
//!   whatever the timer's clear answers (endWindowTimers, clearWindowState for a frame);
//! - the animation frame timer (src/browser/rendering.zig schedule, frameTimerFired): its data is the
//!   Browser's Frames, which the Browser owns;
//! - a worker's animation frame timer (src/html/worker_host.zig armAnimationFrame): its data is the worker's
//!   host; the callbacks are in the host's list, freed by discardAnimationFrames at the realm's end.
//! (An XMLHttpRequest's timeout timer names its pending fetch record, on the realm's list of such records and
//! freed by the fetch's own end: tests/html/xhr_document_abort_timer_test.zig. The back/forward cache's
//! ageing timer names the cache itself.)
//!
//! Each case leaves such timers pending and ends their owner one way. The Browser is made with
//! std.testing.allocator, so a record nobody freed fails the test as a leak.

const std = @import("std");
const h = @import("tl1_pending_timer_helpers.zig");

const Case = enum {
    /// Timeouts, an interval that has repeated and an animation frame callback, pending at the Browser's end.
    page,
    /// The same in a frame that is then removed; the Browser ends later.
    removed_frame,
    /// The same in a frame that then navigates; the Browser ends later.
    navigated_frame,
    /// A dedicated worker's animation frame callback, pending at the Browser's end.
    worker_frame,
};

const arm =
    \\w.setTimeout(() => {}, 600000, 'an argument', { another: 1 });
    \\w.setTimeout('1 + 1', 600000);
    \\w.runs = 0;
    \\w.setInterval(() => { w.runs += 1; if (w.runs === 3) state = 'armed'; }, 1);
    \\w.requestAnimationFrame(function again() { w.requestAnimationFrame(again); });
    \\
;

fn exercise(comptime case: Case) !void {
    const page = try h.Page.open("<!doctype html><body><iframe id=frame></iframe></body>", "http://127.0.0.1:65533/start");
    defer page.close();
    switch (case) {
        .page => {
            try page.run("globalThis.state = 'pending'; const w = window;\n" ++ arm);
            try page.waitForState("armed");
        },
        .removed_frame, .navigated_frame => {
            try page.run("globalThis.state = 'pending'; const w = document.getElementById('frame').contentWindow;\n" ++ arm);
            try page.waitForState("armed");
            if (case == .removed_frame) {
                try page.run("document.getElementById('frame').remove();");
            } else {
                try page.run(
                    \\state = 'pending';
                    \\{
                    \\  const frame = document.getElementById('frame');
                    \\  frame.onload = () => { state = 'navigated'; };
                    \\  frame.srcdoc = '<!doctype html><body>next</body>';
                    \\}
                );
                try page.waitForState("navigated");
            }
            try page.turn(20);
        },
        .worker_frame => {
            try page.run("globalThis.state = 'pending';\n" ++
                "globalThis.worker = new Worker(URL.createObjectURL(new Blob([" ++
                \\"let frames = 0; requestAnimationFrame(function again() { frames += 1; if (frames === 2) postMessage('armed'); requestAnimationFrame(again); });"
            ++ "], { type: 'text/javascript' })));\n" ++
                \\worker.onmessage = e => { state = e.data; };
                \\worker.onerror = () => { state = 'worker error'; };
            );
            try page.waitForState("armed");
        },
    }
}

fn check(comptime case: Case) !void {
    try h.onFreshThread(struct {
        fn body() !void {
            try exercise(case);
        }
    }.body);
}

test "a page's timers and animation frame callback pending at the Browser's end are freed" {
    try check(.page);
}

test "a removed frame's pending timers and animation frame callback are freed" {
    try check(.removed_frame);
}

test "a navigated frame's old window's pending timers and animation frame callback are freed" {
    try check(.navigated_frame);
}

test "a worker's animation frame callback pending at the Browser's end is freed" {
    try check(.worker_frame);
}
