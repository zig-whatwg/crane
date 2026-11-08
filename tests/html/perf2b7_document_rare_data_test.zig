//! Lane perf2 batch 7: a Document's rare data (dom.document_rare_data) - the
//! state few Documents set (its import map, speculation rules' prefetch
//! hints, its frozen base URL and pragma-set language, its target element
//! and the elements :hover and :active rest on, its template contents owner
//! document, the parser's form associations, the fullscreen, pointer lock
//! and picture-in-picture elements) is made on first use, never for a
//! Document that sets none of it, counted in its Browser's DOM memory while
//! it lives (what V8 schedules DOM-driven collections by), and freed and
//! uncounted with the Document.
const std = @import("std");
const h = @import("refcount_holders_helpers.zig");
const testing = h.testing;
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const onFreshThread = h.onFreshThread;

/// The Document `name` (a global of the page's realm) names.
fn documentOf(page: h.Page, name: []const u8) !*runtime.Instance {
    var buf: [64]u8 = undefined;
    const held = try page.browser.evaluateScript(try std.fmt.bufPrint(&buf, "globalThis.{s}", .{name}));
    defer held.release();
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

fn rareDataOf(document: *runtime.Instance) !?*dom.document_rare_data.DocumentRareData {
    const internal = dom.document_internals.getInternal(document) orelse return error.NoDocumentState;
    return internal.rareData();
}

fn reported(page: h.Page) usize {
    return page.browser.scope.dom_memory.live;
}

fn noRareDataForPlainDocuments() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.made = document.implementation.createHTMLDocument('made');
        \\globalThis.parsed = new DOMParser().parseFromString('<p>a</p>', 'text/html');
        \\globalThis.xml = document.implementation.createDocument(null, 'root', null);
        \\globalThis.own = document;
        \\0;
    );
    inline for (.{ "made", "parsed", "xml", "own" }) |name| {
        const document = try documentOf(page, name);
        if (try rareDataOf(document) != null) {
            std.debug.print("the Document `{s}` made rare data\n", .{name});
            return error.RareDataMade;
        }
    }
}

test "a Document that sets none of the rare fields makes no rare data: createHTMLDocument's, DOMParser's, createDocument's and the page's own" {
    try onFreshThread(noRareDataForPlainDocuments);
}

fn importMapMakesCountedRareData() !void {
    const page = try h.Page.open();
    defer page.close();
    for (0..2) |_| try page.collect();
    const before = reported(page);
    try page.run("globalThis.made = document.implementation.createHTMLDocument('made'); 0;");
    const document = try documentOf(page, "made");
    try testing.expect(try rareDataOf(document) == null);
    const with_document = reported(page);

    // HTML "merge existing and new import maps": the first mapping makes the
    // rare data that keeps the map, once; the second reuses it.
    try dom.document_modules.addImportMapping(document, "lib", "https://example.test/lib.js");
    const rare = (try rareDataOf(document)) orelse return error.NoRareData;
    try dom.document_modules.addScopedImportMapping(document, "https://example.test/scoped/", "lib", "https://example.test/scoped-lib.js");
    try dom.document_modules.addImportMapping(document, "lib", "https://example.test/lib2.js");
    try testing.expectEqual(rare, (try rareDataOf(document)).?);
    try testing.expectEqualStrings("https://example.test/lib2.js", dom.document_modules.resolveImportSpecifier(document, "lib", "https://example.test/app.js").?);
    try testing.expectEqualStrings("https://example.test/scoped-lib.js", dom.document_modules.resolveImportSpecifier(document, "lib", "https://example.test/scoped/app.js").?);
    try testing.expectEqual(with_document + @sizeOf(dom.document_rare_data.DocumentRareData), reported(page));

    // The Document goes, and its rare data with it: the reported total is
    // where it was before the Document was made (std.testing.allocator
    // checks the block and the map's strings were freed).
    try page.run("globalThis.made = null; 0;");
    for (0..4) |_| try page.collect();
    const after = reported(page);
    if (after != before) {
        std.debug.print("reported {d} B before the Document, {d} B with it, {d} B after its teardown\n", .{ before, with_document, after });
        return error.ReportedTotalDidNotReturn;
    }
}

test "a Document's first import mapping makes its rare data, counted in the DOM memory until the Document's teardown frees it" {
    try onFreshThread(importMapMakesCountedRareData);
}
