//! Explicit document cancellation stops transport and delivers XHR errors in a
//! document-associated task. Browser teardown must drop that task's owner.
const std = @import("std");
const browser_mod = @import("browser");
const async_fetch = @import("fetch").algorithms.async_fetch;
const network = @import("fetch").network;
const document_fetches = @import("dom").document_fetches;

const Scenario = enum { replacement, discarded, removed_during_state, removed_during_abort };

fn check(scenario: Scenario) !void {
    const Run = struct {
        scenario: Scenario,
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
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/start" });
            const before = async_fetch.inFlight();
            const scheduler = network.scheduler.threadScheduler();
            const transfers_before = scheduler.inFlight();
            try page.runScript(
                \\globalThis.abortEvents = [];
                \\globalThis.frame = document.body.appendChild(document.createElement('iframe'));
                \\globalThis.request = new frame.contentWindow.XMLHttpRequest();
                \\request.open('GET', 'http://127.0.0.1:65533/pending');
                \\request.onreadystatechange = () => abortEvents.push('state:' + request.readyState);
                \\request.onabort = () => abortEvents.push('abort');
                \\request.onloadend = () => abortEvents.push('loadend');
                \\request.send();
            );
            try std.testing.expectEqual(before + 1, async_fetch.inFlight());
            try std.testing.expectEqual(transfers_before + 1, scheduler.inFlight());
            try page.runScript(
                \\frame.contentWindow.stop();
                \\if (request.readyState !== 1 || abortEvents.length !== 0)
                \\  throw new Error('document abort delivered synchronously');
            );
            try std.testing.expectEqual(before, async_fetch.inFlight());
            try std.testing.expectEqual(transfers_before, scheduler.inFlight());
            switch (self.scenario) {
                .replacement => {
                    try page.runScript("request.open('GET', 'http://127.0.0.1:65533/replacement')");
                    _ = try browser.runEventLoopBlocking(10);
                    try page.runScript("if (request.readyState !== 1 || abortEvents.length !== 0) throw new Error('old abort reached replacement')");
                },
                // Keep the queued task for Browser.deinit's drop path.
                .discarded => {},
                .removed_during_state, .removed_during_abort => {
                    const handler = if (self.scenario == .removed_during_state) "onreadystatechange" else "onabort";
                    const script = try std.fmt.allocPrint(allocator, "request.{s} = () => {{ frame.remove(); if (typeof gc === 'function') gc(); }}", .{handler});
                    defer allocator.free(script);
                    try page.runScript(script);
                    _ = try browser.runEventLoopBlocking(10);
                    try page.runScript("if (frame.isConnected) throw new Error('queued abort did not remove frame')");
                },
            }
        }
    };
    var run: Run = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "queued document abort is canceled by open while transport ends immediately" {
    try check(.replacement);
}

test "realm teardown drops queued XHR abort without leaking its owner" {
    try check(.discarded);
}

test "queued XHR abort can lose its realm during readystatechange" {
    try check(.removed_during_state);
}

test "queued XHR abort can lose its realm during abort" {
    try check(.removed_during_abort);
}

const NavigationScenario = enum { active, queued_stop, replacement_before_abort, open_after_navigation_abort, abandoned };

fn checkNavigation(scenario: NavigationScenario) !void {
    const Run = struct {
        scenario: NavigationScenario,
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(self: *@This()) !void {
            const allocator = std.testing.allocator;
            var browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
            var browser_ended = false;
            defer if (!browser_ended) browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/start" });
            const document = page.document_instance orelse return error.TestUnexpectedResult;
            const before = async_fetch.inFlight();
            const scheduler = network.scheduler.threadScheduler();
            const transfers_before = scheduler.inFlight();
            try page.runScript(
                \\globalThis.abortEvents = [];
                \\globalThis.request = new XMLHttpRequest();
                \\request.open('POST', 'http://127.0.0.1:65533/pending');
                \\request.onreadystatechange = () => abortEvents.push('state:' + request.readyState);
                \\request.onabort = () => abortEvents.push('abort');
                \\request.onloadend = () => abortEvents.push('loadend');
                \\request.upload.onabort = () => abortEvents.push('upload.abort');
                \\request.upload.onloadend = () => abortEvents.push('upload.loadend');
                \\request.send('pending upload');
                \\abortEvents.length = 0;
            );
            try std.testing.expectEqual(before + 1, async_fetch.inFlight());
            try std.testing.expectEqual(transfers_before + 1, scheduler.inFlight());
            if (self.scenario == .queued_stop) {
                try page.runScript("window.stop(); if (request.readyState !== 1 || abortEvents.length !== 0) throw new Error('stop delivered inline')");
                try std.testing.expectEqual(before, async_fetch.inFlight());
            }
            // On the regressed tree, prepare its old marker so RED reaches
            // the silent-detach bug rather than an absent-API assertion.
            if (comptime @hasDecl(document_fetches, "prepareNavigationAbort")) {
                document_fetches.prepareNavigationAbort(document);
            }
            if (self.scenario == .replacement_before_abort) {
                try page.runScript("request.open('POST', 'http://127.0.0.1:65533/replacement'); request.send('replacement upload'); abortEvents.length = 0");
                try std.testing.expectEqual(before + 1, async_fetch.inFlight());
            }
            // Provisional navigation preserves every XHR. The fallback
            // reaches the old production path for behavioral RED.
            const canceled = if (comptime @hasDecl(document_fetches, "abortForNavigation"))
                document_fetches.abortForNavigation(document)
            else
                document_fetches.abort(document);
            try std.testing.expect(!canceled);
            if (self.scenario != .queued_stop) {
                try std.testing.expectEqual(before + 1, async_fetch.inFlight());
                try std.testing.expectEqual(transfers_before + 1, scheduler.inFlight());
                try page.runScript("if (request.readyState !== 1 || abortEvents.length !== 0) throw new Error('provisional navigation ended request')");
                if (self.scenario == .abandoned) {
                    // No replacement and no later stop: teardown must end
                    // the ordinary owner without any parked hold or leak.
                    browser.deinit();
                    browser_ended = true;
                    try std.testing.expectEqual(before, async_fetch.inFlight());
                    // Browser.deinit may destroy the old scheduler. Only
                    // read the thread's current one if it still exists.
                    const remaining = if (network.scheduler.existingThreadScheduler()) |current| current.inFlight() else 0;
                    try std.testing.expectEqual(transfers_before, remaining);
                    return;
                }
                if (self.scenario == .active) {
                    // Actual replacement uses the existing silent discard.
                    document_fetches.abortAll(page.realm orelse return error.TestUnexpectedResult);
                } else {
                    // An explicit stop must still abort an existing or
                    // replacement send while navigation is provisional.
                    try page.runScript("window.stop()");
                }
            }
            try std.testing.expectEqual(before, async_fetch.inFlight());
            try std.testing.expectEqual(transfers_before, scheduler.inFlight());
            try page.runScript("if (request.readyState !== 1 || abortEvents.length !== 0) throw new Error('navigation delivered inline')");
            _ = try browser.runEventLoopBlocking(10);
            if (self.scenario == .replacement_before_abort or self.scenario == .open_after_navigation_abort or self.scenario == .queued_stop) {
                try page.runScript("if (request.readyState !== 4 || abortEvents.join(',') !== 'state:4,upload.abort,upload.loadend,abort,loadend') throw new Error('replacement inherited navigation suppression')");
            } else {
                try page.runScript("if (request.readyState !== 1 || abortEvents.length !== 0) throw new Error('navigation delivered request error events')");
            }
        }
    };
    var run: Run = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "provisional navigation preserves XHR until silent replacement teardown" {
    try checkNavigation(.active);
}

test "provisional navigation preserves independently queued XHR stop delivery" {
    try checkNavigation(.queued_stop);
}

test "replacement XHR send during provisional navigation retains ordinary abort events" {
    try checkNavigation(.replacement_before_abort);
}

test "ordinary stop after provisional navigation still aborts the existing XHR" {
    try checkNavigation(.open_after_navigation_abort);
}

test "provisional navigation without replacement releases XHR on browser teardown" {
    try checkNavigation(.abandoned);
}

const FrameNavigationScenario = enum { open, replacement, no_replacement, parent_abort };

fn checkFrameNavigation(scenario: FrameNavigationScenario) !void {
    const Run = struct {
        scenario: FrameNavigationScenario,
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(self: *@This()) !void {
            const allocator = std.testing.allocator;
            var browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
            var browser_ended = false;
            defer if (!browser_ended) browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/start" });
            const before = async_fetch.inFlight();
            const scheduler = network.scheduler.threadScheduler();
            const transfers_before = scheduler.inFlight();
            try page.runScript(
                \\globalThis.abortEvents = [];
                \\globalThis.frame = document.body.appendChild(document.createElement('iframe'));
                \\globalThis.request = new frame.contentWindow.XMLHttpRequest();
                \\request.open('GET', 'http://127.0.0.1:65533/pending');
                \\request.onreadystatechange = () => abortEvents.push('state:' + request.readyState);
                \\request.onabort = () => abortEvents.push('abort:' + request.readyState);
                \\request.onloadend = () => abortEvents.push('loadend:' + request.readyState);
                \\request.send();
                \\globalThis.oldDocument = frame.contentDocument;
            );
            if (self.scenario == .parent_abort) try page.runScript(
                \\globalThis.parentRequest = new XMLHttpRequest();
                \\parentRequest.open('GET', 'http://127.0.0.1:65533/parent');
                \\parentRequest.onabort = () => frame.contentWindow.stop();
                \\parentRequest.send();
            );
            if (self.scenario == .open) try page.runScript(
                \\frame.contentWindow.location.href = 'http://127.0.0.1:65533/navigation';
                \\frame.contentDocument.open();
                \\if (request.readyState !== 1 || abortEvents.length !== 0)
                \\  throw new Error('document open delivered inline');
            ) else if (self.scenario == .replacement) try page.runScript(
                \\frame.contentWindow.location.href = 'about:blank';
                \\if (request.readyState !== 1 || abortEvents.length !== 0)
                \\  throw new Error('provisional navigation ended XHR');
            ) else if (self.scenario == .no_replacement) try page.runScript(
                \\frame.contentWindow.location.href = 'data:application/octet-stream,external-handoff';
                \\if (request.readyState !== 1 || abortEvents.length !== 0)
                \\  throw new Error('provisional handoff ended XHR');
            ) else try page.runScript(
                \\frame.contentWindow.location.href = 'data:application/octet-stream,external-handoff';
                \\parentRequest.abort();
                \\if (request.readyState !== 1 || abortEvents.length !== 0)
                \\  throw new Error('nested stop delivered inline');
            );
            const still_pending: usize = if (self.scenario == .replacement or self.scenario == .no_replacement) 1 else 0;
            try std.testing.expectEqual(before + still_pending, async_fetch.inFlight());
            try std.testing.expectEqual(transfers_before + still_pending, scheduler.inFlight());
            if (self.scenario == .no_replacement) {
                // The navigation commits no document. One turn processes
                // that response; transport may queue an XHR outcome for
                // the next turn, but must not deliver a navigation abort.
                const loop = browser.event_loop orelse return error.TestUnexpectedResult;
                _ = loop.runOnceBlocking(0);
                try page.runScript("if (request.readyState !== 1 || abortEvents.length !== 0 || frame.contentDocument !== oldDocument) throw new Error('handoff ended the active XHR owner')");
                // No later stop/open is needed to free its normal live or
                // queued-response owner when the host ends.
                browser.deinit();
                browser_ended = true;
                try std.testing.expectEqual(before, async_fetch.inFlight());
                const remaining = if (network.scheduler.existingThreadScheduler()) |current| current.inFlight() else 0;
                try std.testing.expectEqual(transfers_before, remaining);
                return;
            }
            _ = try browser.runEventLoopBlocking(10);
            try std.testing.expectEqual(before, async_fetch.inFlight());
            try std.testing.expectEqual(transfers_before, scheduler.inFlight());
            if (self.scenario == .open or self.scenario == .parent_abort) {
                try page.runScript("if (request.readyState !== 4 || request.status !== 0 || abortEvents.join(',') !== 'state:4,abort:4,loadend:4') throw new Error('document open lost navigation abort')");
            } else {
                try page.runScript("if (request.readyState !== 1 || abortEvents.length !== 0 || frame.contentDocument === oldDocument) throw new Error('replacement did not silently end XHR')");
            }
        }
    };
    var run: Run = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "Location navigation followed by document open aborts the existing frame XHR" {
    try checkFrameNavigation(.open);
}

test "Location replacement silently ends XHR even when the initial Window is reused" {
    try checkFrameNavigation(.replacement);
}

test "Location navigation with no replacement needs no later stop to release its XHR owner" {
    try checkFrameNavigation(.no_replacement);
}

test "parent abort listener can stop a child XHR during provisional Location navigation" {
    try checkFrameNavigation(.parent_abort);
}
