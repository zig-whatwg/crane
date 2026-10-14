//! HTML upgrade step 11 resets form ownership before step 12 sets custom state.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><form id=target></form><ff-native-owner id=control form=target></ff-native-owner>", .{ .base_url = "http://example.test/ff-owner" });
    const result = try browser.evaluateScript(
        \\customElements.define('ff-native-owner', class extends HTMLElement {
        \\  static formAssociated = true;
        \\  constructor() { super(); this.internals = this.attachInternals(); }
        \\});
        \\0
    );
    result.release();
    const document = page.document_instance orelse return error.NoDocument;
    const control = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("control"))).?;
    const form = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("target"))).?;
    const internals = dom.custom_elements.attachedInternals(control) orelse return error.NoInternals;
    try testing.expectEqual(@as(?*runtime.Instance, form), try interfaces.ElementInternals.get_form(internals));
}

test "an upgraded form-associated custom element immediately resolves its explicit form owner" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
