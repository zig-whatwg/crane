//! WebIDL [Exposed]: a partial or mixin narrows its own members only.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;
const types = codegen.types;

fn exposure(attrs: []const types.ExtendedAttribute) ?types.ExtendedAttribute {
    for (attrs) |attr| if (std.mem.eql(u8, attr.name, "Exposed")) return attr;
    return null;
}

fn member(iface: codegen.ir.Interface, name: []const u8) types.Attribute {
    for (iface.members.items) |m| if (m.attribute) |a| {
        if (std.mem.eql(u8, a.name, name)) return a;
    };
    unreachable;
}

test "xw1 a partial and a mixin carry their exposure to members, with the interface as default" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const file = try codegen.idl_parser.Parser.parse(a,
        \\[Exposed=(Window,Worker)] interface Scope { readonly attribute long everywhere; };
        \\[Exposed=Window] partial interface Scope { readonly attribute long windowOnly; };
        \\[Exposed=Worker] interface mixin WorkerMembers {
        \\  readonly attribute long workerOnly;
        \\  [Exposed=DedicatedWorker] readonly attribute long dedicatedOnly;
        \\};
    );
    var model = try codegen.ir.IR.init(a);
    for (file.interfaces) |iface| try model.addInterface(iface, "test.idl");
    try model.finish();
    try model.processIncludes(&.{.{ .target = "Scope", .mixin = "WorkerMembers" }});
    const iface = model.interfaces.get("Scope").?;
    try testing.expect(exposure(member(iface, "everywhere").extAttrs) == null);
    try testing.expectEqual(@as(usize, 2), exposure(iface.extAttrs.items).?.rhs.?.identifierList.len);
    const window = exposure(member(iface, "windowOnly").extAttrs) orelse return error.PartialExposureMissing;
    try testing.expectEqualStrings("Window", window.rhs.?.identifier);
    const worker = exposure(member(iface, "workerOnly").extAttrs) orelse return error.MixinExposureMissing;
    try testing.expectEqualStrings("Worker", worker.rhs.?.identifier);
    try testing.expectEqualStrings("DedicatedWorker", exposure(member(iface, "dedicatedOnly").extAttrs).?.rhs.?.identifier);
}

test "xw1 member metadata distinguishes instance and static exposure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const file = try codegen.idl_parser.Parser.parse(a,
        \\[Exposed=*] interface Scope {
        \\  readonly attribute long everywhere;
        \\  [Exposed=Window] readonly attribute long windowOnly;
        \\  [Exposed=(Window,DedicatedWorker,SharedWorker)] static undefined createObjectURL();
        \\};
    );
    const iface = file.interfaces[0];
    var attrs: std.ArrayList(types.Attribute) = .empty;
    var ops: std.ArrayList(types.Operation) = .empty;
    for (iface.members) |m| {
        if (m.attribute) |v| try attrs.append(a, v);
        if (m.operation) |v| try ops.append(a, v);
    }
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try codegen.writer.writeMetadata(&out.writer, "Scope", null, null, true, &.{}, iface.extAttrs, attrs.items, ops.items, ops.items, &.{}, false, false, false, null, attrs.items, null, ops.items, null, null);
    try testing.expect(std.mem.indexOf(u8, out.written(), "pub const exposed_members = .{") != null);
    try testing.expect(std.mem.indexOf(u8, out.written(), "pub const exposed_static_members = .{") != null);
}

test "xw1 partial namespace exposure stays on its members" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const file = try codegen.idl_parser.Parser.parse(a,
        \\[Exposed=(Window,Worker)] namespace ScopeNS { readonly attribute long everywhere; };
        \\[Exposed=Window] partial namespace ScopeNS { readonly attribute long windowOnly; };
    );
    var model = try codegen.ir.IR.init(a);
    for (file.namespaces) |ns| try model.addNamespace(ns, "test.idl");
    try model.finish();
    const ns = model.namespaces.get("ScopeNS").?;
    try testing.expectEqual(@as(usize, 2), exposure(ns.extAttrs).?.rhs.?.identifierList.len);
    try testing.expect(exposure(ns.members[0].attribute.?.extAttrs) == null);
    const attr = exposure(ns.members[1].attribute.?.extAttrs) orelse return error.PartialNamespaceExposureMissing;
    try testing.expectEqualStrings("Window", attr.rhs.?.identifier);
}
