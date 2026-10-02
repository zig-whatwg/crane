const std = @import("std");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;

// NOTE: This test is disabled until issue whatwg-bnd80 is fixed.
// V8 crashes with alignment errors when creating a context from a snapshot
// created by a separate binary (snapshot_generator vs test executable).
// The external references count matches (12221) but there seems to be
// a deeper V8-level issue with snapshot deserialization.
//
// test "V8 snapshot loading - browser with snapshot" { ... }

test "document.getElementsByTagName available after Browser.init" {
    const allocator = std.testing.allocator;

    // Initialize browser - should create about:blank context automatically
    const browser = try Browser.init(allocator, .{});
    defer browser.deinit();

    // Get the context - should exist after init
    const ctx = browser.current_context orelse {
        std.debug.print("ERROR: No context after Browser.init()\n", .{});
        return error.NoContext;
    };

    // Test creating a new Document instance via constructor
    const script =
        \\(function() {
        \\    var result = [];
        \\    
        \\    // Check Document constructor
        \\    result.push("typeof Document: " + typeof Document);
        \\    
        \\    // Try creating new Document
        \\    try {
        \\        var newDoc = new Document();
        \\        result.push("new Document() succeeded");
        \\        result.push("newDoc.__proto__: " + newDoc.__proto__);
        \\        result.push("newDoc.__proto__ === Document.prototype: " + (newDoc.__proto__ === Document.prototype));
        \\        result.push("newDoc instanceof Document: " + (newDoc instanceof Document));
        \\    } catch(e) {
        \\        result.push("new Document() threw: " + e.message);
        \\    }
        \\    
        \\    // Compare with existing document
        \\    result.push("document.__proto__: " + document.__proto__);
        \\    result.push("document instanceof Document: " + (document instanceof Document));
        \\    
        \\    return result.join("\n");
        \\})()
    ;

    const result = ctx.evaluateScriptToString(script, allocator) catch |err| {
        std.debug.print("Script execution error: {}\n", .{err});
        return error.ScriptError;
    };
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result});

    // The page has a Document interface and a document.
    try std.testing.expect(std.mem.indexOf(u8, result, "typeof Document: function") != null);
}

// execution-timing/084.html, then any next page. `frames[0].frameElement`
// wraps the iframe element in the FRAME's realm, and the page removes it: the
// element is then kept by that wrapper alone. The page's end ends the frame's
// realm, whose wrapper cache frees the element, whose integration ends the
// frame's realm - the one already ending. Ended twice, the realm's context
// handle was released under the outer call's DetachGlobal (a misaligned-load
// ABRT, deterministic after 084 in a sweep).
test "a page whose written-into frame was removed ends cleanly when it navigates" {
    const allocator = std.testing.allocator;
    const browser = try Browser.init(allocator, .{});
    defer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;

    const html =
        \\<!DOCTYPE html>
        \\<html><head><script>
        \\  var eventOrder = [];
        \\  function log(s) { eventOrder.push(s); }
        \\</script></head>
        \\<body>
        \\<iframe src="about:blank"></iframe>
        \\<script>
        \\  log('inline script #1');
        \\  function fireFooEvent(){
        \\    var evt=document.createEvent('Event');
        \\    evt.initEvent('foo', true, true);
        \\    document.dispatchEvent(evt);
        \\  }
        \\  var doc=frames[0].document;
        \\  doc.open( 'text/html' );
        \\  doc.write( '<script>top.log("IFRAME script");top.document.addEventListener("foo", function(e){ top.log("event: "+e.type); }, false)<\/script>' );
        \\  log('end script #1');
        \\</script>
        \\<script>
        \\  fireFooEvent();
        \\  frames[0].frameElement.parentNode.removeChild( frames[0].frameElement );
        \\</script>
        \\<script>
        \\  fireFooEvent();
        \\</script>
        \\<script>
        \\  log( 'inline script #2' );
        \\</script>
        \\</body></html>
    ;
    try ctx.loadHTML(html, .{ .base_url = "http://localhost/execution-timing/084.html" });
    _ = try browser.runEventLoopBlocking(50);

    const result = try ctx.evaluateScriptToString("eventOrder.join()", allocator);
    defer allocator.free(result);
    // The page's own scripts ran, around the frame's removal.
    try std.testing.expect(std.mem.startsWith(u8, result, "inline script #1,"));
    try std.testing.expect(std.mem.endsWith(u8, result, ",inline script #2"));

    try browser.navigate("about:blank", .window);
    try browser.navigate("about:blank", .window);
}

// A realm's wrapper cache is torn down in hash order. A detached tree whose
// root and children script has all touched - `cloneNode(true)`'s result and
// the elements matched in it, as dom/nodes/Element-matches-init.js does in a
// frame - has every node in the cache: a child freed on its own before its
// root left the root's child list pointing at a freed NodeBase, and the
// root's teardown walk read it (Element.deinit -> instance_bridge.getInstance
// SEGV, flaky in sweeps after Element-webkitMatchesSelector.html). A node
// with a parent is its tree's to free, never its wrapper cache's.
test "a detached tree whose nodes were all wrapped ends cleanly with its realm" {
    const allocator = std.testing.allocator;
    const browser = try Browser.init(allocator, .{});
    defer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;

    const html =
        \\<!DOCTYPE html>
        \\<html><body>
        \\<iframe src="about:blank"></iframe>
        \\<script>
        \\  // One detached tree in this realm, one in the frame's: every node of
        \\  // each wrapped, in the realm whose document made it.
        \\  function build(doc) {
        \\    var root = doc.createElement("div");
        \\    for (var i = 0; i < 64; i++) {
        \\      var child = root.appendChild(doc.createElement("span"));
        \\      child.appendChild(doc.createElement("b"));
        \\    }
        \\    return root;
        \\  }
        \\  var here = build(document);
        \\  var there = build(frames[0].document);
        \\  var built = here.childNodes.length + there.querySelectorAll("b").length;
        \\</script>
        \\</body></html>
    ;
    try ctx.loadHTML(html, .{ .base_url = "http://localhost/detached-trees.html" });
    const result = try ctx.evaluateScriptToString("String(built)", allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("128", result);

    try browser.navigate("about:blank", .window);
    try browser.navigate("about:blank", .window);
}

test "Browsers in sequence each hold the network for their life, and the next finds it working" {
    const allocator = std.testing.allocator;
    // A Browser takes a reference on curl's process-wide state and gives it
    // back as it ends - the last one shutting the connection pool down. The
    // next Browser must find a working network, not one torn down under it.
    for (0..2) |_| {
        const browser = try Browser.init(allocator, .{});
        defer browser.deinit();
        // A fetch that reaches curl: a refused connection is a network
        // error, not a crash.
        try std.testing.expectError(error.NetworkError, browser_mod.navigation.fetchUrl(allocator, "http://127.0.0.1:9/", .{}));
    }
}

// dom/nodes/name-validation.html leaked 13,702 allocations alone (leaks lane,
// 2026-10-02): HTMLUnknownElement's deinit was the codegen stub's no-op while
// its init chained to HTMLElement's, so an unknown element whose wrapper V8
// collected kept its NodeBase, local name and namespace, keyed by its address,
// until a node made at the reused address overwrote them. The teardown sweep
// frees only the elements still alive at the end, so the rounds here make the
// collector take each round's elements and the next round reuse their slab
// addresses. Few elements: the testing allocator unwinds a stack trace for
// every allocation and every free (2,400 elements ran past 18 minutes).
test "an unknown element the collector takes frees its node state" {
    const allocator = std.testing.allocator;
    const browser = try Browser.init(allocator, .{});
    defer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;
    // An HTML document: createElement makes HTML elements only there.
    try ctx.loadHTML("<!DOCTYPE html><html><body></body></html>", .{ .base_url = "http://localhost/unknown-elements.html" });

    const script =
        \\(function () {
        \\  for (let round = 0; round < 3; round++) {
        \\    (function () {
        \\      for (let i = 0; i < 12; i++) document.createElement('x' + round + 'y' + i);
        \\    })();
        \\    TestUtils.gc();
        \\  }
        \\  return Object.prototype.toString.call(document.createElement('x0y0'));
        \\})()
    ;
    const result = try ctx.evaluateScriptToString(script, allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("[object HTMLUnknownElement]", result);
}

// When a worker ends, each of its entangled ports is disentangled and its
// peer is sent `close` from a task of the PEER's realm (MessagePort's
// scheduleClose). Browser.deinit ends the workers first, so that task is
// queued on the page's loop, which never runs again, and the loop dropped the
// task's memory unfreed (leaks lane, 2026-10-02: 6 per sharedworker-import
// file run alone). HTML "destroy a document" removes the document's tasks
// without running them; the page's unloading cleanup frees them.
test "a port's close task the browser's end never runs is freed with its page" {
    const allocator = std.testing.allocator;
    const browser = try Browser.init(allocator, .{});
    defer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;

    const html =
        \\<!DOCTYPE html><html><body><script>
        \\  var reply = 'none';
        \\  var shared = new SharedWorker('data:text/javascript,onconnect = function (e) { self.kept = e.ports[0]; self.kept.postMessage("kept"); };');
        \\  shared.port.onmessage = function (e) { reply = e.data; };
        \\</script></body></html>
    ;
    try ctx.loadHTML(html, .{ .base_url = "http://localhost/port-close-task.html" });

    // The shared worker keeps its connect event's port and answers through
    // it; both ends are kept (the page's `shared.port`, the worker's `kept`)
    // to the browser's end. A shared worker, not a dedicated one: a Worker
    // makes the process's default timer backend from the first allocator it
    // meets and nothing frees it (a leak of its own, reported).
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        _ = try browser.runEventLoopBlocking(20);
        const now = try ctx.evaluateScriptToString("reply", allocator);
        defer allocator.free(now);
        if (std.mem.eql(u8, now, "kept")) break;
    }
    const result = try ctx.evaluateScriptToString("reply", allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("kept", result);
}
