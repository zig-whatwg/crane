//! A Document's [SameObject] children - styleSheets, getSelection()'s
//! Selection, fonts and all - and a ShadowRoot's styleSheets are each kept
//! ONCE (lane perf2, batch 8): in the owner's `same_object.KeptChild`, whose
//! link already holds the child. A second `?*Instance` beside each held the same
//! pointer again (8 bytes a child: 32 a Document, 8 a ShadowRoot).
//!
//! The tests name the dom-level Document state type and generated States only.

const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

fn Embedded(comptime State: type) type {
    return @FieldType(State, "_embedded");
}

fn expectNoField(comptime T: type, comptime names: anytype) !void {
    var kept: usize = 0;
    inline for (names) |name| {
        if (@hasField(T, name)) {
            std.debug.print("{s} still has `{s}`\n", .{ @typeName(T), name });
            kept += 1;
        }
    }
    try testing.expectEqual(@as(usize, 0), kept);
}

test "Document's state keeps each [SameObject] child once, in its KeptChild" {
    const T = dom.document_state.InternalState;
    try expectNoField(T, .{ "style_sheets", "selection", "fonts", "all_collection" });
    inline for (.{ "style_sheets_kept", "selection_kept", "fonts_kept", "all_collection_kept" }) |name| {
        try testing.expect(@hasField(T, name));
    }
}

test "ShadowRoot's state keeps its styleSheets once, in its KeptChild" {
    const S = Embedded(interfaces.ShadowRoot.State);
    try expectNoField(S, .{"style_sheets"});
    try testing.expect(@hasField(S, "style_sheets_kept"));
}

const Fixture = struct {
    ctx: runtime.ContextData,
    document: ?*runtime.Instance = null,
    shadow: ?*runtime.Instance = null,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        self.* = .{ .ctx = runtime.ContextData.init(testing.allocator, .{}) catch |err| {
            runtime.deinitializeRuntime();
            return err;
        } };
        errdefer self.deinit();
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
    }

    fn deinit(self: *Fixture) void {
        if (self.document) |document| interfaces.Document.deinit(document);
        if (self.shadow) |shadow| interfaces.ShadowRoot.deinit(shadow);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }
};

test "a Document hands out the same styleSheets, Selection, fonts and all every time" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const document = f.document.?;
    const sheets = try interfaces.Document.get_styleSheets(document);
    try testing.expectEqual(sheets, try interfaces.Document.get_styleSheets(document));
    const selection = (try interfaces.Document.call_getSelection(document)) orelse return error.NoSelection;
    try testing.expectEqual(@as(?*runtime.Instance, selection), try interfaces.Document.call_getSelection(document));
    const fonts = try interfaces.Document.get_fonts(document);
    try testing.expectEqual(fonts, try interfaces.Document.get_fonts(document));
    const all = try interfaces.Document.get_all(document);
    try testing.expectEqual(all, try interfaces.Document.get_all(document));
    // Four different objects.
    try testing.expect(sheets != selection and sheets != fonts and sheets != all and selection != fonts and selection != all and fonts != all);
}

/// A div appended to `document`: its document element.
fn documentElement(document: *runtime.Instance) !*runtime.Instance {
    const result = try interfaces.Document.call_createElementNS(document, .initInterned("http://www.w3.org/1999/xhtml"), .initInterned("div"), .notPassed());
    errdefer dom.node_creation.destroyUninserted(result);
    _ = try interfaces.Node.call_appendChild(document, result);
    return result;
}

test "a ShadowRoot hands out the same styleSheets every time, not its document's" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const document = f.document.?;
    const host = try documentElement(document);
    f.shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    const sheets = try interfaces.ShadowRoot.get_styleSheets(f.shadow.?);
    try testing.expectEqual(sheets, try interfaces.ShadowRoot.get_styleSheets(f.shadow.?));
    try testing.expect(sheets != try interfaces.Document.get_styleSheets(document));
}
