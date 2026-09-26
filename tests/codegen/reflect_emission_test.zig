//! [Reflect*] attributes are implemented by the generated interface.
//!
//! HTML 2.6.2 "Using reflect via IDL extended attributes": [Reflect],
//! [ReflectSetter], [ReflectURL], [ReflectNonNegative], [ReflectPositive] and
//! [ReflectPositiveWithFallback] make an attribute reflect a content attribute,
//! and HTML 2.6.1 gives the getter and setter steps for its IDL type. So the
//! generated getter and setter reflect by themselves - through
//! `src/webidl/impls/reflection.zig` - unless the impl declares its own
//! function, which then wins: `if (comptime @hasDecl(Impl, "get_x"))`.
//! [ReflectSetter] reflects on setting only; its getter is the attribute's own
//! prose, so it is always the impl's.
//!
//! Reflection runs only where the reflected target is an element: an
//! interface that is or inherits from Element, or a mixin every includer of
//! which does. ARIAMixin is also on ElementInternals, whose reflected target is
//! its internal content attribute map, not an element's attributes.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const reflect = codegen.reflect;
const testing = std.testing;

const on_element: writer.DelegateOptions = .{ .reflect_on_element = true };

fn render(attrs: []const types.Attribute, options: writer.DelegateOptions) !std.Io.Writer.Allocating {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    errdefer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CellImpl", null, attrs, &.{}, &.{}, options);
    return buffer;
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn ext(comptime name: []const u8) types.ExtendedAttribute {
    return .{ .name = name };
}

fn extId(comptime name: []const u8, comptime value: []const u8) types.ExtendedAttribute {
    return .{ .name = name, .rhs = .{ .identifier = value } };
}

test "a [Reflect] DOMString falls back to reflecting its lowercased name when the impl has no function" {
    var extattrs = [_]types.ExtendedAttribute{ ext("CEReactions"), ext("Reflect") };
    const attrs = [_]types.Attribute{.{ .name = "vAlign", .idlType = .{ .type = "DOMString" }, .extAttrs = &extattrs }};
    var buffer = try render(&attrs, on_element);
    defer buffer.deinit();
    const out = buffer.written();

    try testing.expect(contains(out, "const reflection = @import(\"impls\").reflection;"));
    // Declared ahead of the accessor's doc comment, which stays the getter's.
    try testing.expect(contains(out, "/// Extended attributes: [CEReactions], [Reflect]\n    pub fn get_vAlign("));
    try testing.expect(std.mem.indexOf(u8, out, "const reflection").? < std.mem.indexOf(u8, out, "/// Extended attributes").?);
    try testing.expect(contains(out, "if (comptime @hasDecl(CellImpl, \"get_vAlign\")) return try CellImpl.get_vAlign(instance);"));
    try testing.expect(contains(out, "return try reflection.get(runtime.DOMString, instance, .{ .name = \"valign\" });"));
    try testing.expect(contains(out, "if (comptime @hasDecl(CellImpl, \"set_vAlign\")) return try CellImpl.set_vAlign(instance, value);"));
    try testing.expect(contains(out, "try reflection.set(runtime.DOMString, instance, .{ .name = \"valign\" }, value);"));
    // The setter still runs its custom element reactions around all of it.
    try testing.expect(contains(out, "runtime.CEReactions.begin();"));
}

test "a [Reflect=\"name\"] string reflects the named content attribute" {
    var extattrs = [_]types.ExtendedAttribute{ ext("CEReactions"), extId("Reflect", "\"accept-charset\"") };
    const attrs = [_]types.Attribute{.{ .name = "acceptCharset", .idlType = .{ .type = "DOMString" }, .extAttrs = &extattrs }};
    var buffer = try render(&attrs, on_element);
    defer buffer.deinit();
    try testing.expect(contains(buffer.written(), ".{ .name = \"accept-charset\" }"));
}

test "[ReflectURL] USVString is treated as a URL" {
    var extattrs = [_]types.ExtendedAttribute{ ext("CEReactions"), ext("ReflectURL") };
    const attrs = [_]types.Attribute{.{ .name = "cite", .idlType = .{ .type = "USVString" }, .extAttrs = &extattrs }};
    var buffer = try render(&attrs, on_element);
    defer buffer.deinit();
    const out = buffer.written();
    try testing.expect(contains(out, "return try reflection.get(runtime.USVString, instance, .{ .name = \"cite\", .url = true });"));
    try testing.expect(contains(out, "try reflection.set(runtime.USVString, instance, .{ .name = \"cite\", .url = true }, value);"));
}

test "a boolean and a nullable DOMString reflect with their own types" {
    var bool_ext = [_]types.ExtendedAttribute{ ext("CEReactions"), ext("Reflect") };
    var null_ext = [_]types.ExtendedAttribute{ ext("CEReactions"), extId("Reflect", "\"aria-label\"") };
    const attrs = [_]types.Attribute{
        .{ .name = "noWrap", .idlType = .{ .type = "boolean" }, .extAttrs = &bool_ext },
        .{ .name = "ariaLabel", .idlType = .{ .type = "DOMString", .nullable = true }, .extAttrs = &null_ext },
    };
    var buffer = try render(&attrs, on_element);
    defer buffer.deinit();
    const out = buffer.written();
    try testing.expect(contains(out, "return try reflection.get(bool, instance, .{ .name = \"nowrap\" });"));
    try testing.expect(contains(out, "try reflection.set(bool, instance, .{ .name = \"nowrap\" }, value);"));
    try testing.expect(contains(out, "return try reflection.get(?runtime.DOMString, instance, .{ .name = \"aria-label\" });"));
    try testing.expect(contains(out, "try reflection.set(?runtime.DOMString, instance, .{ .name = \"aria-label\" }, value);"));
}

test "[ReflectSetter] reflects on setting only: the getter stays the impl's" {
    var extattrs = [_]types.ExtendedAttribute{ ext("CEReactions"), ext("ReflectSetter") };
    const attrs = [_]types.Attribute{.{ .name = "href", .idlType = .{ .type = "USVString" }, .extAttrs = &extattrs }};
    var buffer = try render(&attrs, on_element);
    defer buffer.deinit();
    const out = buffer.written();
    try testing.expect(contains(out, "return try CellImpl.get_href(instance);"));
    try testing.expect(!contains(out, "reflection.get("));
    try testing.expect(!contains(out, "@hasDecl(CellImpl, \"get_href\")"));
    try testing.expect(contains(out, "try reflection.set(runtime.USVString, instance, .{ .name = \"href\" }, value);"));
}

test "numeric reflections carry their limit, default and range" {
    var span_ext = [_]types.ExtendedAttribute{
        ext("CEReactions"),
        ext("Reflect"),
        extId("ReflectDefault", "1"),
        .{ .name = "ReflectRange", .rhs = .{ .identifierList = @constCast(&[_][]const u8{ "1", "1000" }) } },
    };
    var max_ext = [_]types.ExtendedAttribute{ ext("CEReactions"), ext("ReflectPositive"), extId("ReflectDefault", "1.0") };
    var len_ext = [_]types.ExtendedAttribute{ ext("CEReactions"), ext("ReflectNonNegative") };
    var cols_ext = [_]types.ExtendedAttribute{ ext("CEReactions"), ext("ReflectPositiveWithFallback"), extId("ReflectDefault", "20") };
    const attrs = [_]types.Attribute{
        .{ .name = "colSpan", .idlType = .{ .type = "unsigned long" }, .extAttrs = &span_ext },
        .{ .name = "max", .idlType = .{ .type = "double" }, .extAttrs = &max_ext },
        .{ .name = "maxLength", .idlType = .{ .type = "long" }, .extAttrs = &len_ext },
        .{ .name = "cols", .idlType = .{ .type = "unsigned long" }, .extAttrs = &cols_ext },
    };
    var buffer = try render(&attrs, on_element);
    defer buffer.deinit();
    const out = buffer.written();
    try testing.expect(contains(out, "reflection.get(u32, instance, .{ .name = \"colspan\", .default = 1, .range = .{ 1, 1000 } });"));
    try testing.expect(contains(out, "reflection.get(f64, instance, .{ .name = \"max\", .limit = .positive, .default = 1.0 });"));
    try testing.expect(contains(out, "reflection.get(i32, instance, .{ .name = \"maxlength\", .limit = .non_negative });"));
    try testing.expect(contains(out, "reflection.set(u32, instance, .{ .name = \"cols\", .limit = .positive_with_fallback, .default = 20 }, value);"));
}

test "a type codegen does not reflect keeps the plain delegate" {
    var extattrs = [_]types.ExtendedAttribute{ ext("CEReactions"), extId("Reflect", "\"aria-activedescendant\"") };
    const attrs = [_]types.Attribute{.{ .name = "ariaActiveDescendantElement", .idlType = .{ .type = "Element", .nullable = true }, .extAttrs = &extattrs }};
    var buffer = try render(&attrs, on_element);
    defer buffer.deinit();
    const out = buffer.written();
    try testing.expect(!contains(out, "reflection."));
    try testing.expect(contains(out, "CellImpl.get_ariaActiveDescendantElement(instance)"));
}

test "nothing reflects where the reflected target is not an element" {
    var extattrs = [_]types.ExtendedAttribute{ ext("CEReactions"), ext("Reflect") };
    const attrs = [_]types.Attribute{.{ .name = "role", .idlType = .{ .type = "DOMString", .nullable = true }, .extAttrs = &extattrs }};
    var buffer = try render(&attrs, .{});
    defer buffer.deinit();
    const out = buffer.written();
    try testing.expect(!contains(out, "reflection"));
    try testing.expect(contains(out, "return try CellImpl.get_role(instance);"));
    try testing.expect(contains(out, "try CellImpl.set_role(instance, value);"));
}

test "an attribute without a reflection extended attribute is untouched" {
    var extattrs = [_]types.ExtendedAttribute{ext("CEReactions")};
    const attrs = [_]types.Attribute{.{ .name = "scope", .idlType = .{ .type = "DOMString" }, .extAttrs = &extattrs }};
    var buffer = try render(&attrs, on_element);
    defer buffer.deinit();
    const out = buffer.written();
    try testing.expect(!contains(out, "reflection"));
    try testing.expect(contains(out, "return try CellImpl.get_scope(instance);"));
}

test "the reflected content attribute name is the given string, else the lowercased IDL name" {
    var named = [_]types.ExtendedAttribute{extId("Reflect", "\"http-equiv\"")};
    var plain = [_]types.ExtendedAttribute{ext("ReflectURL")};
    const a: types.Attribute = .{ .name = "httpEquiv", .idlType = .{ .type = "DOMString" }, .extAttrs = &named };
    const b: types.Attribute = .{ .name = "longDesc", .idlType = .{ .type = "USVString" }, .extAttrs = &plain };
    const ra = (try reflect.of(testing.allocator, a)).?;
    defer ra.deinit(testing.allocator);
    const rb = (try reflect.of(testing.allocator, b)).?;
    defer rb.deinit(testing.allocator);
    try testing.expectEqualStrings("http-equiv", ra.name);
    try testing.expectEqualStrings("longdesc", rb.name);
    try testing.expect(rb.url);
    try testing.expectEqual(reflect.Kind.usv_string, rb.kind);
}

test "an element is the reflected target of Element, its descendants, and a mixin only elements include" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const idl =
        \\interface EventTarget {};
        \\interface Node : EventTarget {};
        \\interface Element : Node {};
        \\interface HTMLElement : Element {};
        \\interface HTMLTableCellElement : HTMLElement {};
        \\interface ElementInternals {};
        \\interface mixin HTMLOrSVGElement { [Reflect] attribute boolean autofocus; };
        \\interface mixin ARIAMixin { [Reflect] attribute DOMString? role; };
        \\HTMLElement includes HTMLOrSVGElement;
        \\Element includes ARIAMixin;
        \\ElementInternals includes ARIAMixin;
    ;
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(), idl);
    var model = try codegen.ir.IR.init(arena.allocator());
    for (file.interfaces) |iface| try model.addInterface(iface, "test.idl");
    try model.processIncludes(file.includes);

    try testing.expect(codegen.generator.reflectsOnElement(&model, "Element"));
    try testing.expect(codegen.generator.reflectsOnElement(&model, "HTMLTableCellElement"));
    try testing.expect(!codegen.generator.reflectsOnElement(&model, "Node"));
    try testing.expect(!codegen.generator.reflectsOnElement(&model, "ElementInternals"));
    try testing.expect(codegen.generator.reflectsOnElement(&model, "HTMLOrSVGElement"));
    try testing.expect(!codegen.generator.reflectsOnElement(&model, "ARIAMixin"));
    try testing.expect(!codegen.generator.reflectsOnElement(&model, "NoSuchInterface"));
}
