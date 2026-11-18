//! CSP 6.7.3.1 "Is element nonceable?" over elements HTML's parser made:
//! step 2's dangling-markup scan of a script's attributes, and step 3's
//! duplicate-attribute parse error, which the tokenizer records on its token
//! and the parser on the element (dom.csp_violations.markParsedDuplicateAttribute).
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const parseHTML = @import("html").dom_parser.parseHTML;

fn byId(document: *runtime.Instance, id: []const u8) !*runtime.Instance {
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.MissingElement;
}

test "a parsed element with a duplicate attribute or dangling markup is not nonceable; its nonce stays" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();

    const document = try parseHTML(allocator, &context,
        \\<!DOCTYPE html><body>
        \\<script id=clean nonce="abc"></script>
        \\<script id=duplicate attribute attribute nonce="abc"></script>
        \\<script id=duplicate-id id=other nonce="abc"></script>
        \\<script id=dangling data="<script" nonce="abc"></script>
        \\<script id=dangling-name <style nonce="abc"></script>
        \\<style id=style-duplicate media media nonce="abc"></style>
        \\<style id=style-clean nonce="abc"></style>
        \\<svg><script id=svg-duplicate attribute attribute nonce="abc"></script></svg>
        \\<div id=no-nonce title title></div>
    , .{});
    defer interfaces.Document.deinit(document);

    const clean = try byId(document, "clean");
    try std.testing.expect(dom.csp_violations.isNonceable(clean, true));
    try std.testing.expectEqualStrings("abc", dom.csp_violations.nonceableScriptNonce(clean, "abc"));

    // Step 3: the parser dropped the second attribute and remembered it.
    const duplicate = try byId(document, "duplicate");
    try std.testing.expect(!dom.csp_violations.isNonceable(duplicate, true));
    try std.testing.expectEqualStrings("", dom.csp_violations.nonceableScriptNonce(duplicate, "abc"));
    // Its [[CryptographicNonce]] is untouched: only nonce-source matching
    // refuses it.
    var nonce = try interfaces.HTMLElement.get_nonce(duplicate);
    defer nonce.deinit(allocator);
    try std.testing.expectEqualStrings("abc", nonce.asSlice());

    // The first id wins and the element is still found by it.
    try std.testing.expect(!dom.csp_violations.isNonceable(try byId(document, "duplicate-id"), true));

    // Step 2: dangling markup in a value or a name.
    try std.testing.expect(!dom.csp_violations.isNonceable(try byId(document, "dangling"), true));
    try std.testing.expect(!dom.csp_violations.isNonceable(try byId(document, "dangling-name"), true));

    // Step 3 holds for any element; step 2 for script elements only.
    try std.testing.expect(!dom.csp_violations.isNonceable(try byId(document, "style-duplicate"), false));
    try std.testing.expect(dom.csp_violations.isNonceable(try byId(document, "style-clean"), false));

    // A foreign element's token is the same token.
    try std.testing.expect(!dom.csp_violations.isNonceable(try byId(document, "svg-duplicate"), true));

    // An element with no nonce has no rare block to carry the record (step 1
    // already answers "Not Nonceable" for it), and none is made for it.
    const plain = try byId(document, "no-nonce");
    try std.testing.expect(dom.node_rare_data.of(plain).block == null);
}
