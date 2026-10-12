//! Event handler IDL attributes are implemented by the generated interface.
//!
//! HTML 8.1.8.1 gives one getter and one setter for every event handler IDL
//! attribute - every attribute of type EventHandler, OnErrorEventHandler or
//! OnBeforeUnloadEventHandler: determine the target of the event handler,
//! then get (or set) the current value of the event handler in the target's
//! event handler map. So the generated getter and setter run those steps by
//! themselves - through `dom.event_handlers.value` / `setValue`
//! (src/dom/event_handlers.zig) - unless the impl declares its own function,
//! which then wins:
//! `if (comptime @hasDecl(Impl, "get_onload"))`. WebKit's generator does the
//! same (CodeGeneratorJS.pm, the IsEventHandlerType branch of
//! GenerateAttributeGetterBodyDefinition: `eventHandlerAttribute(...)`), and
//! its implementation classes declare nothing per attribute.
//!
//! "Determining the target of an event handler" (a body element's
//! window-reflecting handlers) is HTML's and reads no impl's state, so it is
//! there too (tmp/plans/impls-boundary-design.md 3.4 e1; the user's decision
//! Q3, 2026-10-11).

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn count(haystack: []const u8, needle: []const u8) usize {
    return std.mem.count(u8, haystack, needle);
}

/// The fixture generated into a temporary tree.
const Generated = struct {
    tmp: testing.TmpDir,
    root: [:0]u8,

    fn init() !Generated {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
        errdefer testing.allocator.free(root);
        var config = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
        defer config.deinit();
        try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/event_handlers"}, &config);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    /// The generated file `name` in `dir` (interfaces, mixins, impls_tmp); the caller frees it.
    fn file(self: *Generated, dir: []const u8, name: []const u8) ![]u8 {
        const path = try std.fmt.allocPrint(testing.allocator, "{s}/{s}/{s}.zig", .{ self.root, dir, name });
        defer testing.allocator.free(path);
        return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
    }
};

fn render(impl_name: []const u8, attrs: []const types.Attribute, options: writer.DelegateOptions) !std.Io.Writer.Allocating {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    errdefer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, impl_name, null, attrs, &.{}, &.{}, options);
    return buffer;
}

test "an EventHandler attribute's getter and setter fall back to the event handler map when the impl has no function" {
    var generated = try Generated.init();
    defer generated.deinit();
    const out = try generated.file("interfaces", "Reader");
    defer testing.allocator.free(out);

    // The helper is declared once, ahead of the first accessor that uses it.
    try testing.expectEqual(@as(usize, 1), count(out, "const event_handlers = @import(\"dom\").event_handlers;"));
    try testing.expect(std.mem.indexOf(u8, out, "const event_handlers").? < std.mem.indexOf(u8, out, "pub fn get_onload(").?);

    try testing.expect(contains(out, "pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {\n" ++
        "        if (comptime @hasDecl(ReaderImpl, \"get_onload\")) return try ReaderImpl.get_onload(instance);\n" ++
        "        return event_handlers.value(EventHandler, instance, \"onload\");\n" ++
        "    }"));
    try testing.expect(contains(out, "pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {\n" ++
        "        if (comptime @hasDecl(ReaderImpl, \"set_onload\")) return try ReaderImpl.set_onload(instance, value);\n" ++
        "        try event_handlers.setValue(EventHandler, instance, \"onload\", value);\n" ++
        "    }"));
}

test "OnErrorEventHandler and OnBeforeUnloadEventHandler attributes are event handlers of their own types" {
    var generated = try Generated.init();
    defer generated.deinit();
    const out = try generated.file("interfaces", "Reader");
    defer testing.allocator.free(out);

    try testing.expect(contains(out, "return event_handlers.value(OnErrorEventHandler, instance, \"onerror\");"));
    try testing.expect(contains(out, "try event_handlers.setValue(OnErrorEventHandler, instance, \"onerror\", value);"));
    try testing.expect(contains(out, "return event_handlers.value(OnBeforeUnloadEventHandler, instance, \"onbeforeunload\");"));
    try testing.expect(contains(out, "try event_handlers.setValue(OnBeforeUnloadEventHandler, instance, \"onbeforeunload\", value);"));
}

test "an attribute of any other type keeps the plain delegate" {
    var generated = try Generated.init();
    defer generated.deinit();
    const out = try generated.file("interfaces", "Reader");
    defer testing.allocator.free(out);

    try testing.expect(contains(out, "return try ReaderImpl.get_label(instance);"));
    try testing.expect(contains(out, "try ReaderImpl.set_label(instance, value);"));
    try testing.expect(!contains(out, "instance, \"label\""));
}

test "an inherited mixin's event handler is the mixin module's, which supplies it" {
    var generated = try Generated.init();
    defer generated.deinit();

    const includer = try generated.file("interfaces", "Reader");
    defer testing.allocator.free(includer);
    try testing.expect(contains(includer, "pub const get_onclick = mixins.GlobalEventHandlers.get_onclick;"));
    try testing.expect(contains(includer, "pub const set_onclick = mixins.GlobalEventHandlers.set_onclick;"));
    try testing.expect(!contains(includer, "ReaderImpl.get_onclick"));

    const mixin = try generated.file("mixins", "GlobalEventHandlers");
    defer testing.allocator.free(mixin);
    try testing.expect(contains(mixin, "const event_handlers = @import(\"dom\").event_handlers;"));
    try testing.expect(contains(mixin, "if (comptime @hasDecl(GlobalEventHandlersImpl, \"get_onclick\")) return try GlobalEventHandlersImpl.get_onclick(instance);"));
    try testing.expect(contains(mixin, "return event_handlers.value(EventHandler, instance, \"onclick\");"));
    try testing.expect(contains(mixin, "try event_handlers.setValue(EventHandler, instance, \"onclick\", value);"));
}

test "the impl stub declares no event handler accessor: one would override the generated one" {
    var generated = try Generated.init();
    defer generated.deinit();
    const stub = try generated.file("impls_tmp", "Reader");
    defer testing.allocator.free(stub);

    try testing.expect(!contains(stub, "get_onload"));
    try testing.expect(!contains(stub, "set_onload"));
    try testing.expect(!contains(stub, "get_onerror"));
    try testing.expect(!contains(stub, "set_onbeforeunload"));
    // The impl's other accessors are still stubbed.
    try testing.expect(contains(stub, "pub fn get_label("));
    try testing.expect(contains(stub, "pub fn set_label("));
}

test "no helper is declared where no attribute is an event handler" {
    const attrs = [_]types.Attribute{.{ .name = "label", .idlType = .{ .type = "DOMString" } }};
    var buffer = try render("ReaderImpl", &attrs, .{});
    defer buffer.deinit();
    try testing.expect(!contains(buffer.written(), "event_handlers"));
}

test "a readonly or static attribute named like a handler is not one" {
    // Every event handler IDL attribute is a regular, writable attribute; a
    // readonly one is something else, and keeps its plain delegate.
    const attrs = [_]types.Attribute{
        .{ .name = "onwhat", .idlType = .{ .type = "EventHandler" }, .readonly = true },
        .{ .name = "onstatic", .idlType = .{ .type = "EventHandler" }, .static = true },
    };
    var buffer = try render("ReaderImpl", &attrs, .{});
    defer buffer.deinit();
    const out = buffer.written();
    try testing.expect(!contains(out, "event_handlers"));
    try testing.expect(contains(out, "return try ReaderImpl.get_onwhat(instance);"));
}
