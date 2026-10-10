//! The net under "a node keeps its node document" (Node.zig,
//! `owner_document_generation`): a node whose document was freed under it -
//! a hole in that rule - reads InvalidStateError and logs a warning, never
//! the freed object or whatever took its slot.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const od = @import("od_test_helpers.zig");

fn aFreedDocumentIsNeverHandedOut() !void {
    const page = try od.open();
    defer page.close();
    const context = page.browser.current_context orelse return error.NoPage;
    const realm = context.realm orelse return error.NoRealm;
    // A document and a node of it that no script has seen; the document is
    // then freed natively while the node lives on.
    const doc = try interfaces.Document.call_constructor(realm);
    const text = try interfaces.Document.call_createTextNode(doc, runtime.DOMString.initInterned("orphan"));
    defer dom.node_creation.destroyUninserted(text);
    try testing.expectEqual(@as(?*runtime.Instance, doc), try interfaces.Node.get_ownerDocument(text));
    const generation = runtime.SlabAllocator.generationOf(doc);
    dom.node_creation.destroyUninserted(doc);
    try testing.expect(runtime.SlabAllocator.generationOf(doc) != generation);
    // The slot is reissued, as a collection's churn would.
    const other = try interfaces.Document.call_constructor(realm);
    defer dom.node_creation.destroyUninserted(other);
    try testing.expectError(error.InvalidStateError, interfaces.Node.get_ownerDocument(text));
}

test "a node whose document was freed under it reads InvalidStateError, not the freed object" {
    try od.onFreshThread(aFreedDocumentIsNeverHandedOut);
}
