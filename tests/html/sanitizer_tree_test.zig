//! Native tree filtering checks allocation cleanup without relying on the
//! dictionary-to-JavaScript result shape.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const model = @import("html").sanitizer;
const fixture = @import("rf_fixture.zig");
const str = fixture.str;

fn attribute(element: *runtime.Instance, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(element, str(name), .{ .domstring = str(value) });
}

test "Sanitizer replaces a container after filtering its descendants and navigation attributes" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const section = try page.append(page.element, "section");
    const link = try page.append(section, "a");
    try attribute(link, "href", " \tJaVa\nScRiPt:alert(1)");
    try attribute(link, "onclick", "alert(1)");
    try attribute(link, "title", "kept");
    _ = try page.append(section, "script");
    const comment = try interfaces.Document.call_createComment(page.document, str("removed"));
    _ = try interfaces.Node.call_appendChild(section, comment);
    var replaces = [_]model.Name{.{ .local = "section", .namespace = model.html_namespace }};
    var config = try model.Config.fromData(std.testing.allocator, .{ .replace_elements = &replaces, .comments = false }, true);
    defer config.deinit();
    try model.sanitize(page.element, &config, true);
    try std.testing.expectEqual(link, (try interfaces.Node.get_firstChild(page.element)).?);
    try std.testing.expect((try interfaces.Node.get_nextSibling(link)) == null);
    try std.testing.expect(!try interfaces.Element.call_hasAttribute(link, str("href")));
    try std.testing.expect(!try interfaces.Element.call_hasAttribute(link, str("onclick")));
    try std.testing.expect(try interfaces.Element.call_hasAttribute(link, str("title")));
    // Safe sanitization never changes the caller's permissive configuration.
    try std.testing.expectEqual(@as(?bool, true), config.data.javascript_urls);
    try std.testing.expectEqual(@as(usize, 0), config.data.remove_elements.?.len);
}

test "Sanitizer reaches template contents and closed shadow roots" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const template = try page.append(page.element, "template");
    const contents = dom.template_contents.contentOf(template).?;
    const host = try page.append(page.element, "div");
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._closed_ });
    // This engine-free fixture has no collector to release a parentless root.
    defer interfaces.ShadowRoot.deinit(shadow);
    _ = try page.append(contents, "script");
    _ = try page.append(shadow, "script");
    const template_p = try page.append(contents, "p");
    const shadow_p = try page.append(shadow, "p");
    try attribute(template_p, "onclick", "bad()");
    try attribute(shadow_p, "onclick", "bad()");
    var config = try model.Config.fromData(std.testing.allocator, .{}, true);
    defer config.deinit();
    try model.sanitize(page.element, &config, true);
    try std.testing.expectEqual(template_p, (try interfaces.Node.get_firstChild(contents)).?);
    try std.testing.expectEqual(shadow_p, (try interfaces.Node.get_firstChild(shadow)).?);
    try std.testing.expect(!try interfaces.Element.call_hasAttribute(template_p, str("onclick")));
    try std.testing.expect(!try interfaces.Element.call_hasAttribute(shadow_p, str("onclick")));
}

test "Sanitizer filters processing instructions independently of comments" {
    var keep_targets = [_][]const u8{"keep"};
    var drop_targets = [_][]const u8{"drop"};
    for ([_]model.Data{
        .{ .processing_instructions = &keep_targets, .comments = true },
        .{ .remove_processing_instructions = &drop_targets, .comments = true },
    }) |data| {
        var page: fixture.Page = undefined;
        try page.open();
        defer page.close();
        const keep = try interfaces.Document.call_createProcessingInstruction(page.document, str("keep"), str("data"));
        _ = try interfaces.Node.call_appendChild(page.element, keep);
        const drop = try interfaces.Document.call_createProcessingInstruction(page.document, str("drop"), str("data"));
        _ = try interfaces.Node.call_appendChild(page.element, drop);
        const comment = try interfaces.Document.call_createComment(page.document, str("keep"));
        _ = try interfaces.Node.call_appendChild(page.element, comment);
        var config = try model.Config.fromData(std.testing.allocator, data, true);
        defer config.deinit();
        try model.sanitize(page.element, &config, true);
        try std.testing.expectEqual(keep, (try interfaces.Node.get_firstChild(page.element)).?);
        try std.testing.expectEqual(comment, (try interfaces.Node.get_nextSibling(keep)).?);
        try std.testing.expect((try interfaces.Node.get_nextSibling(comment)) == null);
    }
}

test "Sanitizer removes arbitrary SVG href prefixes but retains trailing components" {
    for ([_][]const u8{ "animate", "animateTransform", "set" }) |tag| {
        for ([_][]const u8{ "ylink:href", "zlink:href", "a:b:href", "xlink:href:x" }) |target| {
            var page: fixture.Page = undefined;
            try page.open();
            defer page.close();
            const element = try interfaces.Document.call_createElementNS(page.document, str("http://www.w3.org/2000/svg"), str(tag), .notPassed());
            _ = try interfaces.Node.call_appendChild(page.element, element);
            try attribute(element, "attributeName", target);
            var config = try model.Config.fromData(std.testing.allocator, .{}, true);
            defer config.deinit();
            try model.sanitize(page.element, &config, true);
            try std.testing.expectEqual(std.mem.eql(u8, target, "xlink:href:x"), try interfaces.Element.call_hasAttribute(element, str("attributeName")));
        }
    }
}
