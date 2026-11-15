//! A declarative refresh's timer data is freed however its timer ends (lane tl1).
//!
//! HTML "shared declarative refresh steps" step 13 waits `time` seconds and then navigates; the
//! implementation arms a native timer with the document's refresh record (the document, the URL, the timer).
//! The record is freed when the timer fires, or by the document's end, which cancels the timer. These tests
//! end the Browser with the wait still pending.
//!
//! The Browser is made with std.testing.allocator, so a record nobody freed fails the test as a leak.

const std = @import("std");
const h = @import("tl1_pending_timer_helpers.zig");

const Where = enum {
    /// The page's own document, parsed with the pragma; the loop turns so the document completely loads.
    page,
    /// The page's document, the pragma inserted by script after it loaded.
    page_inserted,
    /// A frame's document (srcdoc), parsed with the pragma.
    frame,
    /// The frame removed from its document while its refresh waits: its document ended first.
    removed_frame,
    /// The same, with the event loop turned after the removal.
    removed_frame_then_turn,
    /// The frame removed while script keeps its document: the document outlives its realm and the event loop.
    removed_frame_document_kept,
    /// The pragma in a document with no browsing context (DOMParser's): never armed, freed with the document.
    parsed_document,
};

const refresh_frame = "<!doctype html><body><iframe srcdoc=\"<meta http-equiv=refresh content='600; url=about:blank'>\"></iframe></body>";

fn exercise(comptime where: Where) !void {
    const html = switch (where) {
        .page => "<!doctype html><meta http-equiv=\"refresh\" content=\"600; url=about:blank\"><body></body>",
        .page_inserted, .parsed_document => "<!doctype html><body></body>",
        .frame, .removed_frame, .removed_frame_then_turn, .removed_frame_document_kept => refresh_frame,
    };
    const page = try h.Page.open(html, "http://127.0.0.1:65533/start");
    defer page.close();
    // The document completely loads: the refresh's wait starts then.
    try page.turn(50);
    switch (where) {
        .page, .frame => {},
        .page_inserted => {
            try page.run(
                \\const meta = document.createElement('meta');
                \\meta.httpEquiv = 'refresh';
                \\meta.content = '600; url=about:blank';
                \\document.head.appendChild(meta);
            );
            try page.turn(30);
        },
        .parsed_document => try page.run(
            \\globalThis.parsed = new DOMParser().parseFromString("<meta http-equiv=refresh content='600; url=about:blank'>", 'text/html');
            \\new DOMParser().parseFromString("<meta http-equiv=refresh content='600; url=about:blank'>", 'text/html');
        ),
        .removed_frame, .removed_frame_then_turn => {
            try page.run("document.querySelector('iframe').remove();");
            if (where == .removed_frame_then_turn) try page.turn(30);
        },
        .removed_frame_document_kept => {
            try page.run(
                \\globalThis.kept = document.querySelector('iframe').contentDocument;
                \\if (!kept.querySelector('meta')) throw new Error('the frame document has no pragma');
                \\document.querySelector('iframe').remove();
            );
            try page.turn(30);
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

test "a declarative refresh waiting at the Browser's end: the page's document" {
    try check(.page);
}

test "a declarative refresh waiting at the Browser's end: a pragma inserted after the load" {
    try check(.page_inserted);
}

test "a declarative refresh waiting at the Browser's end: a frame's document" {
    try check(.frame);
}

test "a declarative refresh waiting when its frame is removed, then the Browser ends" {
    try check(.removed_frame);
}

test "a declarative refresh waiting when its frame is removed, the loop turns, then the Browser ends" {
    try check(.removed_frame_then_turn);
}

test "a declarative refresh waiting when its frame is removed and script keeps its document" {
    try check(.removed_frame_document_kept);
}

test "a refresh pragma in a document with no browsing context is freed with the document" {
    try check(.parsed_document);
}

test "a declarative refresh that comes due navigates its frame" {
    try h.onFreshThread(struct {
        fn body() !void {
            const page = try h.Page.open(
                "<!doctype html><body><iframe srcdoc=\"<meta http-equiv=refresh content='0; url=about:blank#refreshed'>\"></iframe></body>",
                "http://127.0.0.1:65533/start",
            );
            defer page.close();
            try page.run(
                \\globalThis.state = 'pending';
                \\globalThis.poll = setInterval(() => {
                \\  const href = document.querySelector('iframe').contentWindow.location.href;
                \\  if (href === 'about:blank#refreshed') { state = 'refreshed'; clearInterval(poll); }
                \\}, 5);
            );
            try page.waitForState("refreshed");
        }
    }.body);
}

test "a declarative refresh whose timer ends before its document: the timer's end frees its data" {
    // Shown with a timer that ends first - what a document script still holds meets at the Browser's end,
    // where the trees only wrappers held are freed after the event loop: the plain form left the record to
    // a document whose end then cleared a timer that was gone - on a real timer manager, a call into freed
    // memory.
    try h.onFreshThread(struct {
        fn body() !void {
            var timer: h.EndingTimer = .{};
            const page = try h.Page.open("<!doctype html><body></body>", "http://127.0.0.1:65533/start");
            {
                errdefer page.close();
                // The document completely loads: a pragma inserted now starts its wait at once.
                try page.turn(50);
                const realm = try page.realm();
                const saved = realm.timer;
                realm.timer = timer.interface();
                defer realm.timer = saved;
                try page.run(
                    \\const meta = document.createElement('meta');
                    \\meta.httpEquiv = 'refresh';
                    \\meta.content = '600; url=about:blank';
                    \\document.head.appendChild(meta);
                );
            }
            try h.endTimerThenBrowser(page, &timer, 1);
        }
    }.body);
}
