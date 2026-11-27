//! Allocator hardening follow-up (lane hard-fix1, Item 1: §3.7, §7 B.1, §10.2):
//! Every worker thread attaches its own `AgentCache` via `engine.attachAgent()`
//! on startup and detaches it on exit, passing `worker_cache.allocator()` to the
//! worker's host, agent, and realm so worker allocations hit their own lock-free
//! thread-local cache instead of falling back to the window cache's locked path.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const platform = @import("platform");
const runtime = @import("runtime");

const page_html = "<!doctype html><body></body>";

fn open(browser: *browser_mod.Browser, script: []const u8) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_html, .{ .base_url = "about:blank" });
    try page.runScript(script);
    return page;
}

fn readNumber(page: *browser_mod.Context, source: []const u8) !u64 {
    const text = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(text);
    return std.fmt.parseInt(u64, text, 10);
}

test "item 1: dedicated worker attaches its own AgentCache, uses it lock-free, and flushes cleanly on exit" {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();

    const eng = browser.scope.existingHeapEngine() orelse return error.SkipZigTest;
    if (!browser.scope.general) return error.SkipZigTest;

    const window_thread = platform.currentThreadToken();
    const before = eng.attachedCacheSummary(window_thread);
    try testing.expectEqual(@as(usize, 1), before.total);
    try testing.expectEqual(@as(usize, 0), before.non_window);

    // Start a worker that performs string & object allocations (populating its
    // own AgentCache), signals 'ready', then waits until told 'stop' to close.
    const page = try open(browser,
        \\globalThis.ready = 0;
        \\globalThis.stopped = 0;
        \\(() => {
        \\  const src = `
        \\    onmessage = (e) => {
        \\      if (e.data === 'work') {
        \\        const items = [];
        \\        for (let i = 0; i < 200; i++) {
        \\          items.push(new URL('https://example.test/p/' + i + '?q=' + 'x'.repeat(32 + (i % 64))).href);
        \\        }
        \\        postMessage('ready:' + items.length);
        \\      } else if (e.data === 'stop') {
        \\        postMessage('bye');
        \\        close();
        \\      }
        \\    };
        \\  `;
        \\  const url = URL.createObjectURL(new Blob([src], { type: 'text/javascript' }));
        \\  globalThis.w = new Worker(url);
        \\  w.onmessage = (e) => {
        \\    if (String(e.data).startsWith('ready:')) globalThis.ready = 1;
        \\    if (e.data === 'bye') globalThis.stopped = 1;
        \\  };
        \\  w.postMessage('work');
        \\})();
    );

    var waited: usize = 0;
    while (try readNumber(page, "String(globalThis.ready)") == 0) : (waited += 20) {
        _ = try browser.runEventLoopBlocking(20);
        if (waited >= 30_000) return error.WorkerNeverReady;
    }

    // While the worker is alive and has allocated, it MUST have its own attached
    // AgentCache owned by the worker thread with cached entries held lock-free!
    const during = eng.attachedCacheSummary(window_thread);
    try testing.expectEqual(@as(usize, 2), during.total);
    try testing.expectEqual(@as(usize, 1), during.non_window);
    try testing.expect(during.non_window_held > 0);

    // Stop the worker and wait for it to close and detach its AgentCache.
    try page.runScript("w.postMessage('stop');");
    waited = 0;
    while (eng.attachedCacheSummary(window_thread).total > 1) : (waited += 20) {
        _ = try browser.runEventLoopBlocking(20);
        if (waited >= 30_000) return error.WorkerNeverDetached;
    }

    const after = eng.attachedCacheSummary(window_thread);
    try testing.expectEqual(@as(usize, 1), after.total);
    try testing.expectEqual(@as(usize, 0), after.non_window);
    try testing.expectEqual(@as(usize, 0), after.non_window_held);
}

test "item 1: concurrent and sequential worker AgentCache reuse is TSan-clean with 0 leaks" {
    var leaks: usize = 1;
    {
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
        defer browser.deinit();
        browser.scope.heap_leak_count_out = &leaks;

        const eng = browser.scope.existingHeapEngine() orelse return error.SkipZigTest;
        if (!browser.scope.general) return error.SkipZigTest;

        // Run two waves of 3 workers each so wave 2 reuses detached AgentCaches
        // from wave 1 while cross-thread postMessage payloads are freed on the
        // window thread (stressing attachAgent/detachAgent under TSan).
        const page = try open(browser,
            \\globalThis.doneWaves = 0;
            \\(() => {
            \\  const src = `
            \\    onmessage = (e) => {
            \\      for (let i = 0; i < 40; i++) {
            \\        postMessage(['msg-' + e.data + '-' + i, 'a'.repeat(48 + (i % 128))]);
            \\      }
            \\      postMessage('done');
            \\      close();
            \\    };
            \\  `;
            \\  const url = URL.createObjectURL(new Blob([src], { type: 'text/javascript' }));
            \\  function runWave(wave) {
            \\    let remaining = 3;
            \\    for (let w = 0; w < 3; w++) {
            \\      const worker = new Worker(url);
            \\      worker.onmessage = (e) => {
            \\        if (e.data === 'done') {
            \\          remaining--;
            \\          if (remaining === 0) {
            \\            globalThis.doneWaves++;
            \\            if (wave === 1) runWave(2);
            \\          }
            \\        }
            \\      };
            \\      worker.postMessage(wave * 10 + w);
            \\    }
            \\  }
            \\  runWave(1);
            \\})();
        );

        var waited: usize = 0;
        while (try readNumber(page, "String(globalThis.doneWaves)") < 2) : (waited += 20) {
            _ = try browser.runEventLoopBlocking(20);
            if (waited >= 60_000) return error.WorkerWavesTimedOut;
        }
        // Let all wave-2 worker threads finish exiting & detaching.
        const window_thread = platform.currentThreadToken();
        waited = 0;
        while (eng.attachedCacheSummary(window_thread).total > 1) : (waited += 20) {
            _ = try browser.runEventLoopBlocking(20);
            if (waited >= 30_000) return error.WorkerNeverDetached;
        }
    }
    try testing.expectEqual(@as(usize, 0), leaks);
}

test "item 2: Browser.defaultAllocObserver wires Darwin malloc_logger callouts iff -Dheap-alloc-log=true" {
    try testing.expect(browser_mod.Browser.defaultAllocObserver(false) == null);
    const obs = browser_mod.Browser.defaultAllocObserver(true) orelse return error.TestUnexpectedResult;

    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const eng = browser.scope.existingHeapEngine() orelse return error.SkipZigTest;

    // Default test build has -Dheap-alloc-log=false -> no observer auto-installed.
    if (!runtime.heap.heap_alloc_log_enabled) {
        try testing.expect(eng.alloc_observer == null);
    }
    // Installing the malloc_logger observer runs cleanly on alloc & free (no-op when no Darwin logger is attached).
    eng.setAllocObserver(obs);
    defer eng.setAllocObserver(null);
    const p = try eng.alloc(.{ .node = .element }, 96, 8, runtime.heap.Site.of(u64), @returnAddress());
    eng.free(p, 96, 8);
}
