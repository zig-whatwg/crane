const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const v8 = @import("v8");

// Helper to evaluate script and expect true
fn expectScriptTrue(ctx: *browser_mod.Context, script: []const u8) !void {
    const result = try ctx.evaluateScript(script);
    const result_value = result orelse return error.ScriptReturnedNull;

    // Check if result is true
    const isolate = ctx.isolate;
    const is_true = v8.ffi.v8_Value_BooleanValue(result_value, isolate);

    if (!is_true) {

        // Try to get string representation for debugging
        const v8_ctx = ctx.v8_context orelse return error.NoContext;
        if (v8.ffi.v8_Value_ToString(result_value, v8_ctx)) |str_value| {
            var buf: [1024]u8 = undefined;
            const len = v8.ffi.v8_String_WriteUtf8(str_value, &buf, @intCast(buf.len));
            const actual_len: usize = @intCast(len);
            std.debug.print("Script returned: {s}\n", .{buf[0..actual_len]});
        }
        return error.ScriptAssertionFailed;
    }
}

test "MessageEvent.data accessor is installed" {
    const allocator = testing.allocator;

    // Initialize browser (creates about:blank window context)
    var browser = try Browser.init(allocator, .{
        .persist_storage = false,
    });
    defer browser.deinit();

    const ctx = browser.current_context orelse return error.NoContext;

    // Verify MessageEvent.prototype.data accessor exists
    try expectScriptTrue(ctx,
        \\var descriptor = Object.getOwnPropertyDescriptor(MessageEvent.prototype, "data");
        \\descriptor && typeof descriptor.get === "function"
    );
}

test "Worker postMessage delivers MessageEvent with data" {
    if (true) return error.SkipZigTest; // TODO: Enable when Worker prototype chain is fixed
    const allocator = testing.allocator;

    var browser = try Browser.init(allocator, .{
        .persist_storage = false,
    });
    defer browser.deinit();

    const ctx = browser.current_context orelse return error.NoContext;

    // This test creates a worker that posts a message back to main thread
    // The main thread waits for the message and verifies the data
    const script =
        \\new Promise((resolve, reject) => {
        \\    const worker = new Worker("data:text/javascript,postMessage({type:'test',value:42})");
        \\    worker.onmessage = (e) => {
        \\        try {
        \\            if (e.data && e.data.type === 'test' && e.data.value === 42) {
        \\                resolve(true);
        \\            } else {
        \\                reject(new Error("Unexpected data: " + JSON.stringify(e.data)));
        \\            }
        \\        } catch (err) {
        \\            reject(err);
        \\        }
        \\    };
        \\    worker.onerror = (e) => reject(new Error("Worker error: " + e.message));
        \\    setTimeout(() => reject(new Error("timeout")), 5000);
        \\});
    ;

    // We need to run the event loop for the promise to resolve
    _ = (try ctx.evaluateScript(script)) orelse return error.ScriptReturnedNull;

    // Wait for promise resolution

    // Note: In a real browser test runner, we'd handle the promise.
    // Here we rely on runEventLoop to process the worker message.
    // Ideally we'd check promise state, but basic runEventLoop should drive it.

    try browser.runEventLoop(1000);

    // Check if promise resolved to true
    // This is a bit tricky without a proper async test runner helper
    // For now, let's assume if it didn't throw and we processed events, it worked.
    // Better: attach a global variable

    const script_with_global =
        \\(function() {
        \\    globalThis.testPassed = false;
        \\    globalThis.testError = null;
        \\    const worker = new Worker("data:text/javascript,postMessage({type:'test',value:42}, [])");
        \\    worker.onmessage = (e) => {
        \\        if (e.data && e.data.type === 'test' && e.data.value === 42) {
        \\            globalThis.testPassed = true;
        \\        } else {
        \\            globalThis.testError = "Unexpected data: " + JSON.stringify(e.data);
        \\        }
        \\    };
        \\})();
    ;

    _ = try ctx.evaluateScript(script_with_global);
    try browser.runEventLoop(1000);

    try expectScriptTrue(ctx, "globalThis.testPassed === true");
}

test "Main thread postMessage to worker delivers data" {
    if (true) return error.SkipZigTest; // TODO: Enable when Worker prototype chain is fixed
    const allocator = testing.allocator;

    var browser = try Browser.init(allocator, .{
        .persist_storage = false,
    });
    defer browser.deinit();

    const ctx = browser.current_context orelse return error.NoContext;

    const script =
        \\(function() {
        \\    globalThis.testPassed = false;
        \\    const code = `
        \\        onmessage = (e) => {
        \\            if (e.data && e.data.ping === 'pong') {
        \\                postMessage({received: true}, []);
        \\            }
        \\        };
        \\    `;
        \\    const worker = new Worker("data:text/javascript," + encodeURIComponent(code));
        \\    worker.onmessage = (e) => {
        \\        if (e.data && e.data.received) {
        \\            globalThis.testPassed = true;
        \\        }
        \\    };
        \\    worker.postMessage({ping: 'pong'}, []);
        \\})();
    ;

    _ = try ctx.evaluateScript(script);
    try browser.runEventLoop(1000);

    try expectScriptTrue(ctx, "globalThis.testPassed === true");
}

test "Worker context has properly hydrated interfaces after snapshot load" {
    if (true) return error.SkipZigTest; // TODO: Enable when Worker prototype chain is fixed
    const allocator = testing.allocator;

    var browser = try Browser.init(allocator, .{
        .persist_storage = false,
    });
    defer browser.deinit();

    // Switch to a worker context
    try browser.navigate("about:blank", .worker);
    const ctx = browser.current_context orelse return error.NoContext;

    // Verify worker context globals
    _ = try ctx.evaluateScript("console.log('Global keys:', Object.getOwnPropertyNames(globalThis));");
    _ = try ctx.evaluateScript("console.log('Global prototype:', Object.getPrototypeOf(globalThis));");
    _ = try ctx.evaluateScript("console.log('DedicatedWorkerGlobalScope:', typeof DedicatedWorkerGlobalScope);");
    _ = try ctx.evaluateScript("console.log('importScripts:', typeof importScripts);");

    try expectScriptTrue(ctx, "typeof self === 'object'");
    try expectScriptTrue(ctx, "typeof postMessage === 'function'");
    try expectScriptTrue(ctx, "typeof importScripts === 'function'");
    try expectScriptTrue(ctx, "typeof WorkerNavigator !== 'undefined'");
    try expectScriptTrue(ctx, "typeof navigator === 'object'");

    // Verify MessageEvent is available and has data accessor
    try expectScriptTrue(ctx,
        \\typeof MessageEvent !== "undefined" && 
        \\typeof Object.getOwnPropertyDescriptor(MessageEvent.prototype, "data").get === "function"
    );
}
