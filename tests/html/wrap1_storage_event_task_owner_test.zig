//! A `storage` event's task owns its data until it runs - and when its window's loop never turns again, the
//! timer's end frees it (lane wrap1 b2).
//!
//! A change to a storage area queues one task per other document that shares the area (HTML "broadcast": "queue
//! a global task on the DOM manipulation task source given remoteStorage's relevant global object to fire an
//! event named storage"). The task carries owned copies of the key, the old or new value and the URL. It was
//! armed with the plain form of the timer, whose data nobody frees when the timer never fires: a loop that ends
//! drops its pending entries without running them (docs/lessons,
//! architecture-a-task-queued-on-a-loop-that-never-runs-again-leaks-its-data.md).
//!
//! Found as 12 leaked allocations at the exit of one WPT runner child (lane wrap1 b2's bug-finding sweep of
//! 2026-11-13, 20:34 UTC): three tasks of four allocations each, from the cleanup of
//! html/browsers/windows/auxiliary-browsing-contexts/opener-noopener.html, the child's last file - its three
//! storage changes were queued for a popup whose loop did not turn again before the child ended.
//!
//! The Browser is made with std.testing.allocator, so a task that is not freed fails the test as a leak.

const std = @import("std");
const browser_mod = @import("browser");

const Ending = enum {
    /// The Browser ends with the tasks pending: no loop turn after the changes.
    no_loop_turn,
    /// The loop turns: the frame's window hears the three events.
    delivered,
};

fn check(ending: Ending) !void {
    const Run = struct {
        ending: Ending,
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(self: *@This()) !void {
            const allocator = std.testing.allocator;
            var browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            // A page and a same-origin frame (an iframe with no src: about:blank, the page's origin): two
            // documents with one local storage area.
            try page.loadHTML("<!doctype html><body><iframe></iframe></body>", .{ .base_url = "http://127.0.0.1:65533/start" });
            try page.runScript(
                \\const frame = document.querySelector('iframe').contentWindow;
                \\if (!frame || frame === window) throw new Error('the page has no second window');
                \\if (frame.localStorage.length !== 0) throw new Error('the storage area is not empty');
                \\globalThis.heard = [];
                \\frame.addEventListener('storage', (e) => heard.push(e.key + '=' + e.newValue));
                \\// Three changes, as the cleanup of the WPT file that leaked makes: each queues one task for
                \\// the frame's window, and none fires its event inline.
                \\localStorage.setItem('closeAll', 'true');
                \\localStorage.removeItem('closeAll');
                \\localStorage.setItem('openerIsNull', 'false');
                \\if (heard.length !== 0) throw new Error('a storage event was fired inline: ' + heard.join());
            );
            switch (self.ending) {
                .no_loop_turn => {},
                .delivered => {
                    _ = try browser.runEventLoopBlocking(60_000);
                    try page.runScript(
                        \\if (heard.join() !== 'closeAll=true,closeAll=null,openerIsNull=false') throw new Error('the frame heard: ' + heard.join());
                    );
                },
            }
        }
    };
    var run: Run = .{ .ending = ending };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "storage event tasks whose window's loop never turns again are freed at the Browser's end" {
    try check(.no_loop_turn);
}

test "storage event tasks that run deliver their events and free their data" {
    try check(.delivered);
}
