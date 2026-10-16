//! [SecureContext] on a partial interface or an interface mixin applies to
//! the members it declares, not to the interface (WebIDL 3.3.13).
//!
//! The IR merged a partial's extended attributes into the interface's own,
//! so webhid.idl's `[SecureContext] partial interface Navigator { ... }` made
//! Navigator itself [SecureContext] - and Window too, by its partials. And
//! `[SecureContext] interface mixin NavigatorLocks` never reached `locks` on
//! Navigator. Each interface now lists the members a non-secure realm hides
//! (`Meta.secure_context_members`).

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const ir_mod = codegen.ir;
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn hasExtAttr(ext_attrs: []const types.ExtendedAttribute, name: []const u8) bool {
    for (ext_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, name)) return true;
    }
    return false;
}

var exposed_window = [_]types.ExtendedAttribute{.{ .name = "Exposed", .rhs = .{ .identifier = "Window" } }};
var secure = [_]types.ExtendedAttribute{.{ .name = "SecureContext" }};

var base_members = [_]types.Member{
    .{ .type = .attribute, .attribute = .{ .name = "userAgent", .idlType = .{ .type = "DOMString" }, .readonly = true } },
};
var partial_members = [_]types.Member{
    .{ .type = .attribute, .attribute = .{ .name = "hid", .idlType = .{ .type = "HID" }, .readonly = true } },
};
var mixin_members = [_]types.Member{
    .{ .type = .attribute, .attribute = .{ .name = "locks", .idlType = .{ .type = "LockManager" }, .readonly = true } },
};

fn memberNamed(members: []const types.Member, name: []const u8) ?types.Member {
    for (members) |member| {
        if (member.attribute) |attr| {
            if (std.mem.eql(u8, attr.name, name)) return member;
        }
    }
    return null;
}

test "a partial's [SecureContext] is its members', not the interface's; a mixin's reaches the includer's copies" {
    var model = try ir_mod.IR.init(testing.allocator);
    defer model.deinit();
    try model.addInterface(.{ .name = "Navigator", .members = &base_members, .extAttrs = &exposed_window }, "html.idl");
    try model.addInterface(.{ .name = "Navigator", .members = &partial_members, .extAttrs = &secure, .partial = true }, "webhid.idl");
    try model.addInterface(.{ .name = "NavigatorLocks", .members = &mixin_members, .extAttrs = &secure, .mixin = true }, "web-locks.idl");
    try model.finish();
    try model.processIncludes(&.{.{ .target = "Navigator", .mixin = "NavigatorLocks" }});

    const navigator = model.interfaces.get("Navigator").?;
    try testing.expect(!hasExtAttr(navigator.extAttrs.items, "SecureContext"));
    try testing.expect(hasExtAttr(navigator.extAttrs.items, "Exposed"));

    const user_agent = memberNamed(navigator.members.items, "userAgent").?;
    try testing.expect(!hasExtAttr(user_agent.attribute.?.extAttrs, "SecureContext"));
    const hid = memberNamed(navigator.members.items, "hid").?;
    try testing.expect(hasExtAttr(hid.attribute.?.extAttrs, "SecureContext"));
    const locks = memberNamed(navigator.members.items, "locks").?;
    try testing.expect(hasExtAttr(locks.attribute.?.extAttrs, "SecureContext"));
    try testing.expectEqualStrings("NavigatorLocks", locks.attribute.?.mixin.?);
}

test "the [SecureContext] members are listed, instance and static apart" {
    const attrs = [_]types.Attribute{
        .{ .name = "userAgent", .idlType = .{ .type = "DOMString" }, .readonly = true },
        .{ .name = "locks", .idlType = .{ .type = "LockManager" }, .readonly = true, .extAttrs = &secure },
    };
    const ops = [_]types.Operation{
        .{ .name = "share", .idlType = .{ .type = "undefined" }, .extAttrs = &secure },
        .{ .name = "share", .idlType = .{ .type = "undefined" }, .extAttrs = &secure },
        .{ .name = "vibrate", .idlType = .{ .type = "boolean" } },
        .{ .name = "parse", .idlType = .{ .type = "undefined" }, .static = true, .extAttrs = &secure },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeSecureContextMembers(&buffer.writer, &attrs, &ops);
    const out = buffer.written();
    try testing.expect(contains(out, "pub const secure_context_members = .{\n            \"locks\",\n            \"share\",\n        };"));
    try testing.expect(contains(out, "pub const secure_context_static_members = .{\n            \"parse\",\n        };"));
    try testing.expect(!contains(out, "userAgent"));
    try testing.expect(!contains(out, "vibrate"));
}

test "no [SecureContext] member, no table" {
    const attrs = [_]types.Attribute{.{ .name = "userAgent", .idlType = .{ .type = "DOMString" }, .readonly = true }};
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeSecureContextMembers(&buffer.writer, &attrs, &.{});
    try testing.expectEqualStrings("", buffer.written());
}
