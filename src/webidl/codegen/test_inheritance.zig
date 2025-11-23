const std = @import("std");
const testing = std.testing;
const generator = @import("generator.zig");
const parser = @import("parser.zig");

// Test single-level inheritance: HTMLElement extends Element
test "single level inheritance - HTMLElement : Element" {
    const allocator = testing.allocator;

    const idl =
        \\interface Element {
        \\  readonly attribute DOMString tagName;
        \\  undefined setAttribute(DOMString name, DOMString value);
        \\};
        \\
        \\interface HTMLElement : Element {
        \\  attribute DOMString title;
        \\  undefined click();
        \\};
    ;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Parse and generate
    const idl_path = try std.fs.path.join(allocator, &.{ tmp_path, "test.idl" });
    defer allocator.free(idl_path);

    const file = try std.fs.cwd().createFile(idl_path, .{});
    try file.writeAll(idl);
    file.close();

    try generator.generateFromFile(allocator, idl_path, tmp_path);

    // Read generated HTMLElement.zig
    const html_elem_path = try std.fs.path.join(allocator, &.{ tmp_path, "HTMLElement.zig" });
    defer allocator.free(html_elem_path);

    const html_elem_file = try std.fs.cwd().openFile(html_elem_path, .{});
    defer html_elem_file.close();

    const content = try html_elem_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Verify BaseType is Element
    try testing.expect(std.mem.indexOf(u8, content, "pub const BaseType = *Element;") != null);

    // Verify HTMLElement has its own members
    try testing.expect(std.mem.indexOf(u8, content, "get_title") != null);
    try testing.expect(std.mem.indexOf(u8, content, "call_click") != null);

    // Verify Element members are accessible through inheritance
    // (not duplicated in HTMLElement, but available via BaseType)
    try testing.expect(std.mem.indexOf(u8, content, "get_tagName") == null); // Should NOT be duplicated
}

// Test multi-level inheritance: HTMLDivElement : HTMLElement : Element
test "multi level inheritance - HTMLDivElement : HTMLElement : Element" {
    const allocator = testing.allocator;

    const idl =
        \\interface Element {
        \\  readonly attribute DOMString tagName;
        \\};
        \\
        \\interface HTMLElement : Element {
        \\  attribute DOMString title;
        \\};
        \\
        \\interface HTMLDivElement : HTMLElement {
        \\  attribute DOMString align;
        \\};
    ;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const idl_path = try std.fs.path.join(allocator, &.{ tmp_path, "test.idl" });
    defer allocator.free(idl_path);

    const file = try std.fs.cwd().createFile(idl_path, .{});
    try file.writeAll(idl);
    file.close();

    try generator.generateFromFile(allocator, idl_path, tmp_path);

    // Verify HTMLElement : Element
    const html_elem_path = try std.fs.path.join(allocator, &.{ tmp_path, "HTMLElement.zig" });
    defer allocator.free(html_elem_path);
    const html_elem = try std.fs.cwd().openFile(html_elem_path, .{});
    defer html_elem.close();
    const html_content = try html_elem.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(html_content);

    try testing.expect(std.mem.indexOf(u8, html_content, "pub const BaseType = *Element;") != null);

    // Verify HTMLDivElement : HTMLElement
    const div_path = try std.fs.path.join(allocator, &.{ tmp_path, "HTMLDivElement.zig" });
    defer allocator.free(div_path);
    const div_file = try std.fs.cwd().openFile(div_path, .{});
    defer div_file.close();
    const div_content = try div_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(div_content);

    try testing.expect(std.mem.indexOf(u8, div_content, "pub const BaseType = *HTMLElement;") != null);
}

// Test single mixin: Element includes GlobalEventHandlers
test "single mixin - Element includes GlobalEventHandlers" {
    const allocator = testing.allocator;

    const idl =
        \\interface mixin GlobalEventHandlers {
        \\  attribute EventHandler onclick;
        \\  attribute EventHandler onload;
        \\};
        \\
        \\interface Element {
        \\  readonly attribute DOMString tagName;
        \\};
        \\
        \\Element includes GlobalEventHandlers;
    ;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const idl_path = try std.fs.path.join(allocator, &.{ tmp_path, "test.idl" });
    defer allocator.free(idl_path);

    const file = try std.fs.cwd().createFile(idl_path, .{});
    try file.writeAll(idl);
    file.close();

    try generator.generateFromFile(allocator, idl_path, tmp_path);

    const elem_path = try std.fs.path.join(allocator, &.{ tmp_path, "Element.zig" });
    defer allocator.free(elem_path);
    const elem_file = try std.fs.cwd().openFile(elem_path, .{});
    defer elem_file.close();
    const content = try elem_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Verify mixin is listed
    try testing.expect(std.mem.indexOf(u8, content, "GlobalEventHandlers") != null);

    // Verify mixin members are included
    try testing.expect(std.mem.indexOf(u8, content, "get_onclick") != null);
    try testing.expect(std.mem.indexOf(u8, content, "set_onclick") != null);
    try testing.expect(std.mem.indexOf(u8, content, "get_onload") != null);
}

// Test multiple mixins: HTMLElement includes GlobalEventHandlers + DocumentAndElementEventHandlers
test "multiple mixins - HTMLElement includes two mixins" {
    const allocator = testing.allocator;

    const idl =
        \\interface mixin GlobalEventHandlers {
        \\  attribute EventHandler onclick;
        \\};
        \\
        \\interface mixin DocumentAndElementEventHandlers {
        \\  attribute EventHandler oncopy;
        \\};
        \\
        \\interface Element {
        \\  readonly attribute DOMString tagName;
        \\};
        \\
        \\interface HTMLElement : Element {
        \\  attribute DOMString title;
        \\};
        \\
        \\HTMLElement includes GlobalEventHandlers;
        \\HTMLElement includes DocumentAndElementEventHandlers;
    ;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const idl_path = try std.fs.path.join(allocator, &.{ tmp_path, "test.idl" });
    defer allocator.free(idl_path);

    const file = try std.fs.cwd().createFile(idl_path, .{});
    try file.writeAll(idl);
    file.close();

    try generator.generateFromFile(allocator, idl_path, tmp_path);

    const html_path = try std.fs.path.join(allocator, &.{ tmp_path, "HTMLElement.zig" });
    defer allocator.free(html_path);
    const html_file = try std.fs.cwd().openFile(html_path, .{});
    defer html_file.close();
    const content = try html_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Verify inheritance
    try testing.expect(std.mem.indexOf(u8, content, "pub const BaseType = *Element;") != null);

    // Verify both mixins are listed
    try testing.expect(std.mem.indexOf(u8, content, "GlobalEventHandlers") != null);
    try testing.expect(std.mem.indexOf(u8, content, "DocumentAndElementEventHandlers") != null);

    // Verify members from both mixins
    try testing.expect(std.mem.indexOf(u8, content, "get_onclick") != null);
    try testing.expect(std.mem.indexOf(u8, content, "get_oncopy") != null);
}

// Test static methods are inherited
test "static methods inheritance" {
    const allocator = testing.allocator;

    const idl =
        \\interface Element {
        \\  static Element createElement(DOMString tagName);
        \\};
        \\
        \\interface HTMLElement : Element {
        \\  attribute DOMString title;
        \\};
    ;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const idl_path = try std.fs.path.join(allocator, &.{ tmp_path, "test.idl" });
    defer allocator.free(idl_path);

    const file = try std.fs.cwd().createFile(idl_path, .{});
    try file.writeAll(idl);
    file.close();

    try generator.generateFromFile(allocator, idl_path, tmp_path);

    // Check Element has static method
    const elem_path = try std.fs.path.join(allocator, &.{ tmp_path, "Element.zig" });
    defer allocator.free(elem_path);
    const elem_file = try std.fs.cwd().openFile(elem_path, .{});
    defer elem_file.close();
    const elem_content = try elem_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(elem_content);

    try testing.expect(std.mem.indexOf(u8, elem_content, "call_createElement") != null);

    // HTMLElement should have BaseType pointing to Element
    const html_path = try std.fs.path.join(allocator, &.{ tmp_path, "HTMLElement.zig" });
    defer allocator.free(html_path);
    const html_file = try std.fs.cwd().openFile(html_path, .{});
    defer html_file.close();
    const html_content = try html_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(html_content);

    try testing.expect(std.mem.indexOf(u8, html_content, "pub const BaseType = *Element;") != null);
}

// Test readonly and writable attributes inheritance
test "attribute types inheritance" {
    const allocator = testing.allocator;

    const idl =
        \\interface Element {
        \\  readonly attribute DOMString tagName;
        \\  attribute DOMString id;
        \\};
        \\
        \\interface HTMLElement : Element {
        \\  readonly attribute DOMString localName;
        \\  attribute DOMString title;
        \\};
    ;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const idl_path = try std.fs.path.join(allocator, &.{ tmp_path, "test.idl" });
    defer allocator.free(idl_path);

    const file = try std.fs.cwd().createFile(idl_path, .{});
    try file.writeAll(idl);
    file.close();

    try generator.generateFromFile(allocator, idl_path, tmp_path);

    const elem_path = try std.fs.path.join(allocator, &.{ tmp_path, "Element.zig" });
    defer allocator.free(elem_path);
    const elem_file = try std.fs.cwd().openFile(elem_path, .{});
    defer elem_file.close();
    const elem_content = try elem_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(elem_content);

    // Readonly: only getter
    try testing.expect(std.mem.indexOf(u8, elem_content, "get_tagName") != null);
    try testing.expect(std.mem.indexOf(u8, elem_content, "set_tagName") == null);

    // Writable: getter and setter
    try testing.expect(std.mem.indexOf(u8, elem_content, "get_id") != null);
    try testing.expect(std.mem.indexOf(u8, elem_content, "set_id") != null);

    const html_path = try std.fs.path.join(allocator, &.{ tmp_path, "HTMLElement.zig" });
    defer allocator.free(html_path);
    const html_file = try std.fs.cwd().openFile(html_path, .{});
    defer html_file.close();
    const html_content = try html_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(html_content);

    try testing.expect(std.mem.indexOf(u8, html_content, "pub const BaseType = *Element;") != null);
    try testing.expect(std.mem.indexOf(u8, html_content, "get_localName") != null);
    try testing.expect(std.mem.indexOf(u8, html_content, "get_title") != null);
    try testing.expect(std.mem.indexOf(u8, html_content, "set_title") != null);
}

// Test inheritance with partial interfaces
test "partial interface merging with inheritance" {
    const allocator = testing.allocator;

    const idl =
        \\interface Element {
        \\  readonly attribute DOMString tagName;
        \\};
        \\
        \\interface HTMLElement : Element {
        \\  attribute DOMString title;
        \\};
        \\
        \\partial interface HTMLElement {
        \\  attribute DOMString lang;
        \\};
    ;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const idl_path = try std.fs.path.join(allocator, &.{ tmp_path, "test.idl" });
    defer allocator.free(idl_path);

    const file = try std.fs.cwd().createFile(idl_path, .{});
    try file.writeAll(idl);
    file.close();

    try generator.generateFromFile(allocator, idl_path, tmp_path);

    const html_path = try std.fs.path.join(allocator, &.{ tmp_path, "HTMLElement.zig" });
    defer allocator.free(html_path);
    const html_file = try std.fs.cwd().openFile(html_path, .{});
    defer html_file.close();
    const content = try html_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Verify inheritance is preserved
    try testing.expect(std.mem.indexOf(u8, content, "pub const BaseType = *Element;") != null);

    // Verify both base and partial members are present
    try testing.expect(std.mem.indexOf(u8, content, "get_title") != null);
    try testing.expect(std.mem.indexOf(u8, content, "get_lang") != null);
}

// Test that IR tracks which source file contains the base (non-partial) definition
test "IR tracks base source file correctly" {
    const allocator = testing.allocator;
    const ir_mod = @import("ir.zig");
    const types = @import("types.zig");

    var ir = ir_mod.IR.init(allocator);
    defer ir.deinit();

    // Add partial interface first (from file A)
    const partial_iface = types.Interface{
        .name = "TestInterface",
        .inheritance = null,
        .members = &.{},
        .extAttrs = &.{},
        .includes = &.{},
        .partial = true,
        .mixin = false,
    };
    try ir.addInterface(partial_iface, "fileA.idl");

    // Add base interface second (from file B)
    const base_iface = types.Interface{
        .name = "TestInterface",
        .inheritance = "Element",
        .members = &.{},
        .extAttrs = &.{},
        .includes = &.{},
        .partial = false,
        .mixin = false,
    };
    try ir.addInterface(base_iface, "fileB.idl");

    // Verify the base_source_index points to fileB
    const iface = ir.interfaces.get("TestInterface").?;
    const sources = ir.source_map.get("TestInterface").?;

    try testing.expectEqual(@as(usize, 1), iface.base_source_index);
    try testing.expectEqualStrings("fileB.idl", sources.items[iface.base_source_index]);
    try testing.expect(iface.has_base);
}

// Test that when base comes first, it's tracked correctly
test "IR tracks base source when base comes before partials" {
    const allocator = testing.allocator;
    const ir_mod = @import("ir.zig");
    const types = @import("types.zig");

    var ir = ir_mod.IR.init(allocator);
    defer ir.deinit();

    // Add base interface first (from html.idl)
    const base_iface = types.Interface{
        .name = "HTMLElement",
        .inheritance = "Element",
        .members = &.{},
        .extAttrs = &.{},
        .includes = &.{},
        .partial = false,
        .mixin = false,
    };
    try ir.addInterface(base_iface, "html.idl");

    // Add partial interface second (from edit-context.idl)
    const partial_iface = types.Interface{
        .name = "HTMLElement",
        .inheritance = null,
        .members = &.{},
        .extAttrs = &.{},
        .includes = &.{},
        .partial = true,
        .mixin = false,
    };
    try ir.addInterface(partial_iface, "edit-context.idl");

    // Verify the base_source_index points to html.idl
    const iface = ir.interfaces.get("HTMLElement").?;
    const sources = ir.source_map.get("HTMLElement").?;

    try testing.expectEqual(@as(usize, 0), iface.base_source_index);
    try testing.expectEqualStrings("html.idl", sources.items[iface.base_source_index]);
    try testing.expect(iface.has_base);
}
