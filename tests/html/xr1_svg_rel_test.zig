//! SVG anchor rel reflection uses the generated HTML reflection algorithm.
const std = @import("std");
const interfaces = @import("interfaces");
const fixture = @import("rf_fixture.zig");
const str = fixture.str;

test "SVG anchor rel reflects the null-namespace attribute" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const anchor = try interfaces.Document.call_createElementNS(page.document, str("http://www.w3.org/2000/svg"), str("a"), .notPassed());
    _ = try interfaces.Node.call_appendChild(page.element, anchor);

    var absent = try interfaces.SVGAElement.get_rel(anchor);
    defer absent.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("", absent.asSlice());

    try interfaces.SVGAElement.set_rel(anchor, str("noopener external"));
    var attribute = (try interfaces.Element.call_getAttribute(anchor, str("rel"))).?;
    defer attribute.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("noopener external", attribute.asSlice());

    try interfaces.Element.call_setAttribute(anchor, str("rel"), .{ .domstring = str("next") });
    var reflected = try interfaces.SVGAElement.get_rel(anchor);
    defer reflected.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("next", reflected.asSlice());
    try interfaces.Element.call_removeAttribute(anchor, str("rel"));
    var removed = try interfaces.SVGAElement.get_rel(anchor);
    defer removed.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("", removed.asSlice());
}
