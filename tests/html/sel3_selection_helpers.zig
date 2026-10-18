const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const Page = @import("edges_node_holders_helpers.zig").Page;

/// Native callers still need the Browser lifecycle: internal clone/replace
/// operations release scratch nodes and retired subtrees through it (Q31).
pub const DocumentPage = struct {
    page: Page,
    document: *runtime.Instance,

    pub fn open() !DocumentPage {
        const page = try Page.open();
        errdefer page.close();
        const document = try interfaces.Document.init(std.testing.allocator, page.browser.getRealm().?);
        return .{ .page = page, .document = document };
    }

    pub fn close(self: DocumentPage) void {
        dom.node_creation.destroyUninserted(self.document);
        self.page.close();
    }
};

/// The production append path reads one scalar. Only tests scan the list
/// to check that it agrees with the actual per-option selectedness bits.
pub fn expectInvariant(select: *runtime.Instance) !void {
    var options: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer options.deinit(std.testing.allocator);
    try @import("html").forms.options.collect(select, std.testing.allocator, &options);
    var selected = false;
    for (options.items) |option| selected = (try interfaces.HTMLOptionElement.get_selected(option)) or selected;
    try std.testing.expectEqual(selected, dom.form_controls.hasSelectedOption(select));
    // Only the option owner can inspect the settled bit. Its diagnostic
    // callback is read-only, allocates nothing, and has no production caller.
    try std.testing.expect(dom.form_controls.selectionInvariant(select));
}
