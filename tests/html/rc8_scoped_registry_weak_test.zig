//! Lane refcount8 (H-RC8-CER-WEAK): a hole the zombie audit's resurrection
//! reports found after refcount step 7's prerequisites (b)/(b2). A scoped
//! CustomElementRegistry's weak document set (Blink's AssociatedDocumentSet)
//! handed a define()'s candidate walk a document whose tree the counts called
//! garbage (crane/rc5-scoped-define-collected-document.html, 2 reports): the
//! set is a weak link, and reads such a document as gone
//! (dom.refcount.weakLinkLive) once weak references see garbage.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const dom = h.dom;

fn scopedRegistrySkipsAGarbageDocument() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.registry = new CustomElementRegistry();
        \\globalThis.doc = document.implementation.createHTMLDocument('');
        \\doc.body.innerHTML = '<rc8-weak></rc8-weak>';
        \\registry.initialize(doc);
        \\globalThis.upgraded = 0;
        \\0;
    );
    const doc = try page.node("doc");
    // The document is the root of its tree: flag it garbage, as step 7 will
    // once nothing holds it. A walk that takes it on again reports a
    // violation ("took a reference on ... the root of a garbage tree"),
    // which fails this test.
    doc.rc_flags.garbage = true;
    const defined = page.run(
        \\registry.define('rc8-weak', class extends HTMLElement { constructor() { super(); globalThis.upgraded += 1; } });
        \\0;
    );
    doc.rc_flags.garbage = false;
    try defined;
    const context = page.browser.current_context orelse return error.NoPage;
    const answer = try context.evaluateScriptToString("String(globalThis.upgraded)", testing.allocator);
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings("0", answer);
}

test "a scoped registry's weak document set skips a document whose tree is garbage" {
    try h.onFreshThread(scopedRegistrySkipsAGarbageDocument);
}
