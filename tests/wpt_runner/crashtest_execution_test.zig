//! Real-browser execution tests for WPT crashtests (`WptBrowser.runCrashtest`).
//!
//! Exercises the real Browser + V8 + WPT's upstream `executors/test-wait.js`:
//! - plain load -> OK (wptreport PASS, no subtests)
//! - `<html class="test-wait">` waits for `TestRendered` and class removal -> OK
//! - `<html class="test-wait">` removed asynchronously -> OK
//! - `<html class="test-wait">` never removed -> TIMEOUT
//! - permission overrides from an earlier test are reset before a crashtest
//! - an already-expired deadline after load returns TIMEOUT without injecting `test-wait.js`

const std = @import("std");
const testing = std.testing;

const WptBrowser = @import("wpt_browser.zig").WptBrowser;
const permissions = @import("permissions");

const wpt_root = "tests/wpt";
const test_wait_rel = "tests/wpt/tools/wptrunner/wptrunner/executors/test-wait.js";

fn requireWptTestWait() !void {
    std.Io.Dir.cwd().access(std.testing.io, test_wait_rel, .{}) catch return error.SkipZigTest;
}

test "runCrashtest: plain HTML page finishes OK with crashtest=true and no subtests" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "crashtests/plain-crash.html",
        "data:text/html,<!doctype html><html><body><p>ok</p></body></html>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);
    try testing.expectEqual(@as(usize, 0), result.subtests.items.len);
}

test "runCrashtest: test-wait class waits for TestRendered and removal before finishing OK" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "crashtests/test-rendered-crash.html",
        "data:text/html,<!doctype html><html class=\"test-wait\"><script>" ++
            "window.__seen_test_rendered = false;" ++
            "document.documentElement.addEventListener('TestRendered', function() {" ++
            "  window.__seen_test_rendered = true;" ++
            "  document.documentElement.classList.remove('test-wait');" ++
            "});" ++
            "</script><body></body></html>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);
    try testing.expectEqual(@as(usize, 0), result.subtests.items.len);

    const ctx = wb.browser.current_context orelse return error.NoContext;
    const seen = try ctx.evaluateScriptToString("window.__seen_test_rendered === true", allocator);
    defer allocator.free(seen);
    try testing.expectEqualStrings("true", seen);
}

test "runCrashtest: test-wait class removed asynchronously finishes OK" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "crashtests/async-wait-crash.html",
        "data:text/html,<!doctype html><html class=\"test-wait\"><script>" ++
            "setTimeout(function() {" ++
            "  window.__async_done = true;" ++
            "  document.documentElement.classList.remove('test-wait');" ++
            "}, 30);" ++
            "</script><body></body></html>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);

    const ctx = wb.browser.current_context orelse return error.NoContext;
    const done = try ctx.evaluateScriptToString("window.__async_done === true", allocator);
    defer allocator.free(done);
    try testing.expectEqualStrings("true", done);
}

test "runCrashtest: test-wait class never removed returns TIMEOUT" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "crashtests/hang-crash.html",
        "data:text/html,<!doctype html><html class=\"test-wait\"><body>stuck</body></html>",
        250,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.timeout, result.status);
    try testing.expect(result.crashtest);
    try testing.expect(result.message != null);
}

test "runCrashtest: resets permission overrides left by a previous test" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    const store = try wb.browser.scope.of(permissions.BrowserStore);
    const batch = try store.set("https://example.test", .{ .name = .geolocation }, .granted);
    batch.release();
    try testing.expectEqual(
        @as(?permissions.PermissionState, .granted),
        store.overrides.get("https://example.test", .{ .name = .geolocation }),
    );

    var result = try wb.runCrashtest(
        "crashtests/perm-reset-crash.html",
        "data:text/html,<!doctype html><html><body>ok</body></html>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expectEqual(
        @as(?permissions.PermissionState, null),
        store.overrides.get("https://example.test", .{ .name = .geolocation }),
    );
}

test "runCrashtest: expired deadline after load returns TIMEOUT without injecting test-wait.js" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "crashtests/expired-deadline-crash.html",
        "data:text/html,<!doctype html><html><body>slow</body></html>",
        0,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.timeout, result.status);
    try testing.expect(result.crashtest);

    const ctx = wb.browser.current_context orelse return error.NoContext;
    const injected = try ctx.evaluateScriptToString("typeof window.__wptrunner_url", allocator);
    defer allocator.free(injected);
    try testing.expectEqualStrings("undefined", injected);
}

test "runCrashtest: insertImage with selection in Comment does not leak uninserted img" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "editing/crashtests/insert-rich-content-in-comment.html",
        "data:text/html,<!DOCTYPE html><div id=\"div\" contenteditable=\"true\"><!-- This is a comment. --></div>" ++
            "<script>document.getSelection().setPosition(div.firstChild);" ++
            "document.execCommand(\"insertImage\", false, \"foo\");</script>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);
}

test "runCrashtest: insertImage with selection in ProcessingInstruction does not leak uninserted img" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "editing/crashtests/insert-rich-content-in-processing-instruction.html",
        "data:text/html,<!DOCTYPE html><div id=\"div\" contenteditable=\"true\"></div>" ++
            "<script>div.appendChild(document.createProcessingInstruction(\"foo\", \"bar\"));" ++
            "document.getSelection().setPosition(div.firstChild);" ++
            "document.execCommand(\"insertImage\", false, \"foo\");</script>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);
}

test "runCrashtest: other execCommand insertions at Comment and plaintext-only insertHTML do not leak" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "editing/crashtests/insert-other-commands-in-comment.html",
        "data:text/html,<!DOCTYPE html><div id=\"d\" contenteditable=\"true\"><!-- c --></div>" ++
            "<div id=\"p\" contenteditable=\"plaintext-only\"></div>" ++
            "<script>" ++
            "for (const cmd of [\"insertLineBreak\",\"insertHorizontalRule\",\"insertParagraph\",\"insertText\",\"insertHTML\"]) {" ++
            "  document.getSelection().setPosition(d.firstChild);" ++
            "  document.execCommand(cmd, false, \"<b>x</b>\");" ++
            "}" ++
            "document.getSelection().setPosition(p, 0);" ++
            "document.execCommand(\"insertHTML\", false, \"<div><b>hello</b><span>world</span></div>\");" ++
            "</script>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);
}

test "runCrashtest: insertParagraph after long collapsible whitespace run finishes in O(N)" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    // Exact pattern of editing/crashtests/insertparagraph-in-listitem-in-svg-followed-by-collapsible-spaces.html
    // (100,000 spaces: O(N^2) took ~16s in Debug and >150s on 336M spaces; O(N) finishes in <100ms).
    var result = try wb.runCrashtest(
        "editing/crashtests/insertparagraph-collapsible-spaces-fast.html",
        "data:text/html,<!doctype html><html><head><meta charset=\"utf-8\"><script>" ++
            "addEventListener(\"load\", () => {" ++
            "  document.querySelector(\"svg\").insertAdjacentText(\"afterend\", \"\\n\" + \" \".repeat(100000));" ++
            "  document.designMode = \"on\";" ++
            "  getSelection().selectAllChildren(document.querySelector(\"input\"));" ++
            "  document.querySelector(\"li\").appendChild(document.querySelector(\"p\"));" ++
            "  document.execCommand(\"outdent\");" ++
            "  document.execCommand(\"insertOrderedList\");" ++
            "  document.execCommand(\"insertParagraph\");" ++
            "  window.__para_done = true;" ++
            "});" ++
            "</script></head><body><svg><foreignObject><li></li>/&gt;</foreignObject></svg><p><input></p></body></html>",
        1_500,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);

    const ctx = wb.browser.current_context orelse return error.NoContext;
    const done = try ctx.evaluateScriptToString("window.__para_done === true", allocator);
    defer allocator.free(done);
    try testing.expectEqualStrings("true", done);
}

test "runCrashtest: selectAll with style element and onselectionchange undo/subscript/delete reaches load" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    // Exact pattern of editing/crashtests/selectall-containing-textarea-and-subscript.html:
    // abandoning a disconnected <style> load must stop delaying the document's load event.
    var result = try wb.runCrashtest(
        "editing/crashtests/selectall-containing-textarea-and-subscript.html",
        "data:text/html,<!doctype html><html><head><meta charset=\"utf-8\"><script>" ++
            "\"use strict\";" ++
            "addEventListener(\"DOMContentLoaded\", () => {" ++
            "  document.designMode = \"on\";" ++
            "  document.onselectionchange = () => {" ++
            "    document.execCommand(\"undo\");" ++
            "    document.execCommand(\"subscript\");" ++
            "    document.execCommand(\"delete\");" ++
            "  };" ++
            "  document.execCommand(\"selectAll\", false);" ++
            "}, {once: true});" ++
            "</script></head><body>%0AAAAA%0A<tt>%0A<style>%0A*::selection { background-origin: border-box, border-box; }%0A</style>%0A</tt>%0A<textarea></textarea>%0A</body></html>",
        2_500,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);
}

test "runCrashtest: link onerror window.stop plus location.href=about:blank settles before test-wait" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    // Exact pattern of html/semantics/document-metadata/the-link-element/link-error-handler-triggers-abort-crash.html.
    var result = try wb.runCrashtest(
        "html/semantics/document-metadata/the-link-element/link-error-handler-triggers-abort-crash.html",
        "data:text/html,<!DOCTYPE html>" ++
            "<link id=\"link\" rel=\"stylesheet\" onerror=\"window.stop(); location.href='about:blank'\">" ++
            "<script>link.href = \"about:blank\";</script>",
        2_500,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);

    const ctx = wb.browser.current_context orelse return error.NoContext;
    const href = try ctx.evaluateScriptToString("location.href", allocator);
    defer allocator.free(href);
    try testing.expectEqualStrings("about:blank", href);
}

test "runCrashtest: append mutated in iframe unload does not crash or leak (one-shot)" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    // One-shot version of dom/nodes/crashtests/multiple-append-mutated-in-unload.https.html
    // (the upstream test without a one-shot guard loops infinitely per HTML spec + Firefox/Safari).
    var result = try wb.runCrashtest(
        "dom/nodes/crashtests/multiple-append-mutated-in-unload-oneshot.html",
        "data:text/html,<!DOCTYPE HTML><div id=\"target\"></div><div id=\"evilParent\"></div><div id=\"node1\">node1</div>" ++
            "<script>window.node1 = document.getElementById(\"node1\"); window.ran = false;" ++
            "function runTest() { if (window.ran) return; window.ran = true;" ++
            "  document.getElementById(\"target\").append(node1, document.getElementById(\"node2\")); }</script>" ++
            "<div id=\"node2\"><iframe allow=\"unload\" srcdoc=\"" ++
            "<!DOCTYPE HTML><script>" ++
            "window.addEventListener('load', function() { window.parent.runTest(); });" ++
            "window.addEventListener('unload', function() {" ++
            "  let p = window.parent; p.document.getElementById('evilParent').appendChild(p.node1);" ++
            "});</script>\"></iframe></div>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);

    const ctx = wb.browser.current_context orelse return error.NoContext;
    const parent_id = try ctx.evaluateScriptToString("document.getElementById('node1').parentNode.id", allocator);
    defer allocator.free(parent_id);
    try testing.expectEqualStrings("evilParent", parent_id);
}
