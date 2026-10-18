const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;
const fixture = @import("fm3_fixture.zig");
const create = fixture.create;
const attribute = fixture.attribute;

fn exercise(document: *runtime.Instance) !void {
    const container = try create(document, "div");
    _ = try interfaces.Node.call_appendChild(document, container);
    const first = try create(document, "form");
    _ = try interfaces.Node.call_appendChild(container, first);
    const second = try create(document, "form");
    _ = try interfaces.Node.call_appendChild(container, second);
    try attribute(first, "id", "first");
    try attribute(second, "id", "second");
    const object = try create(document, "object");
    _ = try interfaces.Node.call_appendChild(first, object);
    try testing.expectEqual(@as(?*runtime.Instance, first), try interfaces.HTMLObjectElement.get_form(object));
    try attribute(object, "form", "second");
    try testing.expectEqual(@as(?*runtime.Instance, second), try interfaces.HTMLObjectElement.get_form(object));
    try attribute(second, "id", "changed");
    try testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.HTMLObjectElement.get_form(object));
    try interfaces.Element.call_removeAttribute(object, runtime.DOMString.initInterned("form"));
    try testing.expectEqual(@as(?*runtime.Instance, first), try interfaces.HTMLObjectElement.get_form(object));
    try attribute(second, "id", "second");
    try attribute(object, "form", "second");
    const duplicate = try create(document, "div");
    try attribute(duplicate, "id", "second");
    _ = try interfaces.Node.call_insertBefore(container, duplicate, second);
    try testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.HTMLObjectElement.get_form(object));
    _ = try interfaces.Node.call_removeChild(container, duplicate);
    defer dom.node_creation.destroyUninserted(duplicate);
    try testing.expectEqual(@as(?*runtime.Instance, second), try interfaces.HTMLObjectElement.get_form(object));
    try interfaces.Element.call_removeAttribute(object, runtime.DOMString.initInterned("form"));
    _ = try interfaces.Node.call_appendChild(second, object);
    try testing.expectEqual(@as(?*runtime.Instance, second), try interfaces.HTMLObjectElement.get_form(object));
    _ = try interfaces.Node.call_removeChild(container, second);
    defer dom.node_creation.destroyUninserted(second);
    try attribute(object, "form", "first");
    try testing.expectEqual(@as(?*runtime.Instance, second), try interfaces.HTMLObjectElement.get_form(object));
}

test "object form getter follows association changes" {
    try fixture.run(exercise);
}
