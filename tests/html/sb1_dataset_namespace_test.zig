//! Dataset writes use DOM's namespace/local-name attribute operation.
const std = @import("std");
const browser_mod = @import("browser");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const element = document.createElement('div');
        \\  element.setAttributeNS('urn:first', 'data-foo', 'first');
        \\  element.setAttributeNS('urn:second', 'data-foo', 'second');
        \\  const observer = new MutationObserver(() => {});
        \\  observer.observe(element, {attributes: true, attributeOldValue: true});
        \\  element.dataset.foo = 'new';
        \\  element.dataset.foo = 'updated';
        \\  return JSON.stringify({
        \\    length: element.attributes.length,
        \\    values: [element.getAttributeNS('urn:first', 'data-foo'),
        \\             element.getAttributeNS('urn:second', 'data-foo'),
        \\             element.getAttributeNS(null, 'data-foo')],
        \\    records: observer.takeRecords().map(record =>
        \\      [record.attributeName, record.attributeNamespace, record.oldValue])
        \\  });
        \\})()
    ,
        std.testing.allocator,
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        \\{"length":3,"values":["first","second","updated"],"records":[["data-foo",null,null],["data-foo",null,"new"]]}
    ,
        result,
    );
}

test "dataset writes preserve namespaced attributes and report null namespace mutations" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                std.debug.print("dataset regression: {s}\n", .{@errorName(err)});
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
