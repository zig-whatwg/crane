//! Custom-element upgrade invalidation required by codex-lpo Q14.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn names(form: *runtime.Instance, expected: []const []const u8) !void {
    const result = try interfaces.HTMLFormElement.getSupportedPropertyNames(form, testing.allocator);
    defer {
        for (result) |*name| name.deinit(testing.allocator);
        testing.allocator.free(result);
    }
    try testing.expectEqual(expected.len, result.len);
    for (expected, result) |want, actual| try testing.expectEqualStrings(want, actual.asSlice());
}

fn upgrade() !void {
    const browser = try @import("browser").Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><form id=f><lpo-cache-face name=face></lpo-cache-face></form>", .{ .base_url = "http://example.test/lpo-cache-upgrade" });
    const document = page.document_instance orelse return error.NoDocument;
    const form = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("f"))).?;
    try names(form, &.{});
    const version = dom.live_collections.treeVersion(document).?;
    const result = try page.evaluateScriptToString(
        \\customElements.define('lpo-cache-face', class extends HTMLElement {
        \\  static formAssociated = true;
        \\});
        \\'defined';
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("defined", result);
    try names(form, &.{"face"});
    try testing.expectEqual(@as(u32, 1), try interfaces.HTMLFormElement.get_length(form));
    // Q14, closed by formnamed: the upgrade made a listed element, which
    // moves the tree version (refcount.formAssociationChanged), so every
    // cache of form membership keyed on it reads again.
    try testing.expectEqual(false, dom.live_collections.treeVersion(document).? == version);
}

test "a form-associated custom-element upgrade advances the collection version" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            upgrade() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
