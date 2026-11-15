//! A worker's setTimeout and setInterval records are freed however their timers end (lane tl1).
//!
//! HTML "timer initialization steps" in a worker arm a native timer of the worker's own event loop with a
//! heap record (the handler, its arguments, the worker's host). The record is in the host's map of active
//! timers: it is freed when a one-shot has run, by clearTimeout, and by the worker's end (close(),
//! terminate(), the Browser's end), which clears the map before the worker's loop and its timers go. These
//! tests end a worker each way with timers still pending.
//!
//! The Browser is made with std.testing.allocator, so a record nobody freed fails the test as a leak.

const std = @import("std");
const h = @import("tl1_pending_timer_helpers.zig");

const Ending = enum {
    /// The Browser ends with the worker running.
    browser_end,
    /// The owner terminates the worker, the loop turns, the Browser ends.
    terminated,
    /// The worker closes itself from a timer's callback while others are pending.
    closed_from_timer,
    /// An interval that has repeated (its record armed again) is pending at the Browser's end.
    repeated_interval,
};

fn exercise(comptime ending: Ending) !void {
    const page = try h.Page.open("<!doctype html><body></body>", "http://127.0.0.1:65533/start");
    defer page.close();
    const worker_source = switch (ending) {
        .browser_end, .terminated =>
        \\"setTimeout(() => {}, 600000, 'an argument', { another: 1 }); setInterval(() => {}, 600000); setTimeout('1 + 1', 600000); postMessage('armed');"
        ,
        .closed_from_timer =>
        \\"setTimeout(() => {}, 600000, 'an argument'); setInterval(() => {}, 600000); setTimeout(() => { postMessage('armed'); close(); }, 1);"
        ,
        .repeated_interval =>
        \\"let runs = 0; setInterval((label) => { runs += 1; if (runs === 3) postMessage('armed'); }, 1, 'an argument'); setTimeout(() => {}, 600000);"
        ,
    };
    try page.run("globalThis.state = 'pending';\n" ++
        "globalThis.worker = new Worker(URL.createObjectURL(new Blob([" ++ worker_source ++ "], { type: 'text/javascript' })));\n" ++
        \\worker.onmessage = e => { state = e.data; };
        \\worker.onerror = () => { state = 'worker error'; };
    );
    try page.waitForState("armed");
    switch (ending) {
        .browser_end, .repeated_interval => {},
        .terminated => {
            try page.run("worker.terminate();");
            try page.turn(30);
        },
        .closed_from_timer => try page.turn(30),
    }
}

fn check(comptime ending: Ending) !void {
    try h.onFreshThread(struct {
        fn body() !void {
            try exercise(ending);
        }
    }.body);
}

test "a worker's timers pending at the Browser's end" {
    try check(.browser_end);
}

test "a worker's timers pending when its owner terminates it" {
    try check(.terminated);
}

test "a worker's timers pending when it closes itself from a timer's callback" {
    try check(.closed_from_timer);
}

test "a worker's interval that has repeated, pending at the Browser's end" {
    try check(.repeated_interval);
}
