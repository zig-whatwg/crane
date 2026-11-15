//! An EventSource's reconnection wait is freed however its timer ends (lane tl1).
//!
//! HTML 9.2.3 "reestablish the connection" step 2 waits the reconnection time before it connects again; the
//! implementation arms a native timer with a heap ticket (eventsource.Retry). The ticket is freed when the
//! timer fires, or by the source's end or close(), which cancels the timer. These tests end the Browser while
//! a source waits to reconnect.
//!
//! The server answers every request with one `retry: 600000` field and closes the connection, so the source
//! fires `error` with readyState CONNECTING and waits ten minutes.
//!
//! The Browser is made with std.testing.allocator, so a ticket nobody freed fails the test as a leak.

const std = @import("std");
const testing = std.testing;
const LoopbackListener = @import("loopback_listener").LoopbackListener;
const h = @import("tl1_pending_timer_helpers.zig");

const Server = struct {
    listener: LoopbackListener,
    thread: ?std.Thread = null,

    fn start() !*Server {
        const self = try testing.allocator.create(Server);
        errdefer testing.allocator.destroy(self);
        self.* = .{ .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    /// Stop the accept thread, then close the listener - in that order (tests/support/loopback_listener.zig).
    fn stop(self: *Server) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        testing.allocator.destroy(self);
    }

    fn serve(self: *Server) void {
        while (self.listener.accept()) |stream| {
            defer stream.close(testing.io);
            reply(stream) catch {};
        }
    }

    fn reply(stream: std.Io.net.Stream) !void {
        var input: [4096]u8 = undefined;
        var reader = stream.reader(testing.io, &input);
        while (true) {
            const line = try reader.interface.takeDelimiterInclusive('\n');
            if (std.mem.eql(u8, line, "\r\n")) break;
        }
        var output: [512]u8 = undefined;
        var writer = stream.writer(testing.io, &output);
        const body = "retry: 600000\n\n";
        try writer.interface.print("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n{s}", .{ body.len, body });
        try writer.interface.flush();
    }
};

const Where = enum {
    /// The page's own window.
    page,
    /// A same-origin frame's window.
    frame,
    /// A frame removed from its document while its source waits: its realm ended first.
    removed_frame,
    /// The same, with the event loop turned after the removal.
    removed_frame_then_turn,
    /// close() while the source waits, then the Browser's end.
    closed,
    /// A dedicated worker's global scope.
    worker,
};

fn exercise(comptime where: Where) !void {
    const server = try Server.start();
    defer server.stop();
    var url_buffer: [128]u8 = undefined;
    const base = try std.fmt.bufPrint(&url_buffer, "http://127.0.0.1:{d}/", .{server.listener.port()});
    const page = try h.Page.open("<!doctype html><body><iframe></iframe></body>", base);
    defer page.close();
    var script_buffer: [1024]u8 = undefined;
    switch (where) {
        .page, .closed => try page.run(
            \\globalThis.state = 'pending';
            \\globalThis.source = new EventSource('/events');
            \\source.onerror = () => { state = 'error ' + source.readyState; };
        ),
        .frame, .removed_frame, .removed_frame_then_turn => try page.run(h.frame_window ++
            \\globalThis.state = 'pending';
            \\globalThis.source = new frame.EventSource(location.origin + '/events');
            \\source.onerror = () => { state = 'error ' + source.readyState; };
        ),
        .worker => try page.run(try std.fmt.bufPrint(&script_buffer,
            \\globalThis.state = 'pending';
            \\const source = "self.source = new EventSource('{s}events'); source.onerror = () => postMessage('error ' + source.readyState);";
            \\globalThis.worker = new Worker(URL.createObjectURL(new Blob([source], {{ type: 'text/javascript' }})));
            \\worker.onmessage = e => {{ state = e.data; }};
            \\worker.onerror = () => {{ state = 'worker error'; }};
        , .{base})),
    }
    // CONNECTING (0) at the error event: the source waits to reconnect.
    try page.waitForState("error 0");
    switch (where) {
        .page, .frame, .worker => {},
        .closed => try page.run("source.close();"),
        .removed_frame, .removed_frame_then_turn => {
            try page.run("document.querySelector('iframe').remove();");
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

test "an EventSource waiting to reconnect at the Browser's end: the page's source" {
    try check(.page);
}

test "an EventSource waiting to reconnect at the Browser's end: a frame's source" {
    try check(.frame);
}

test "an EventSource waiting to reconnect when its frame is removed, then the Browser ends" {
    try check(.removed_frame);
}

test "an EventSource waiting to reconnect when its frame is removed, the loop turns, then the Browser ends" {
    try check(.removed_frame_then_turn);
}

test "an EventSource closed while it waits to reconnect, then the Browser ends" {
    try check(.closed);
}

test "an EventSource waiting to reconnect at the Browser's end: a dedicated worker's source" {
    try check(.worker);
}

test "an EventSource whose timer ends while it waits to reconnect: the timer's end frees its ticket" {
    // Shown with a timer that ends first: the plain form left the ticket to a source whose end frees it
    // only after a successful clear - and a timer that has ended clears nothing, so nobody freed it.
    try h.onFreshThread(struct {
        fn body() !void {
            const server = try Server.start();
            defer server.stop();
            var url_buffer: [128]u8 = undefined;
            const base = try std.fmt.bufPrint(&url_buffer, "http://127.0.0.1:{d}/", .{server.listener.port()});
            var timer: h.EndingTimer = .{};
            const page = try h.Page.open("<!doctype html><body></body>", base);
            {
                errdefer page.close();
                const realm = try page.realm();
                const saved = realm.timer;
                realm.timer = timer.interface();
                defer realm.timer = saved;
                try page.run(
                    \\globalThis.state = 'pending';
                    \\globalThis.source = new EventSource('/events');
                    \\source.onerror = () => { state = 'error ' + source.readyState; };
                );
                try page.waitForState("error 0");
            }
            try h.endTimerThenBrowser(page, &timer, 1);
        }
    }.body);
}
