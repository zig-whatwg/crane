//! Trusted Types sinks: a union with a Trusted Type member becomes a named
//! union typedef in every position (argument_unions.nameTrustedTypeUnions),
//! so a sink sees which arm the binding took; and a supplementary partial may
//! replace a member only where member_overrides.zig names it.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

const Generated = struct {
    tmp: testing.TmpDir,
    root: [:0]u8,

    fn init(fixture: []const u8) !Generated {
        return initSources(&.{fixture});
    }

    /// The first source is webref's; every later one supplementary.
    fn initSources(sources: []const []const u8) !Generated {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
        errdefer testing.allocator.free(root);
        var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
        defer cfg.deinit();
        try codegen.processSources(testing.allocator, sources, &cfg);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    fn read(self: *const Generated, sub_path: []const u8) ![]u8 {
        const path = try std.fs.path.join(testing.allocator, &.{ self.root, sub_path });
        defer testing.allocator.free(path);
        return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
    }
};

fn expectIn(text: []const u8, what: []const u8, needle: []const u8) !void {
    if (!contains(text, needle)) {
        std.debug.print("{s} lacks `{s}`:\n{s}\n", .{ what, needle, text });
        return error.TestExpectedEqual;
    }
}

fn expectNotIn(text: []const u8, what: []const u8, needle: []const u8) !void {
    if (contains(text, needle)) {
        std.debug.print("{s} has `{s}`:\n{s}\n", .{ what, needle, text });
        return error.TestUnexpectedResult;
    }
}

test "a Trusted Types union is a named union with an interface arm per Trusted Type" {
    var out = try Generated.init("tests/codegen/fixtures/trusted_type_unions");
    defer out.deinit();
    const html = try out.read("typedefs/TrustedHTMLOrDOMString.zig");
    defer testing.allocator.free(html);
    try expectIn(html, "TrustedHTMLOrDOMString", "trusted_html: *runtime.Instance,");
    try expectIn(html, "TrustedHTMLOrDOMString", "domstring: runtime.DOMString,");
    // TrustedType is flattened: the binding's union conversion takes
    // interface and string arms, not a nested union.
    const any = try out.read("typedefs/TrustedTypeOrDOMString.zig");
    defer testing.allocator.free(any);
    try expectIn(any, "TrustedTypeOrDOMString", "trusted_html: *runtime.Instance,");
    try expectIn(any, "TrustedTypeOrDOMString", "trusted_script: *runtime.Instance,");
    try expectIn(any, "TrustedTypeOrDOMString", "trusted_script_url: *runtime.Instance,");
    try expectNotIn(any, "TrustedTypeOrDOMString", "typedefs.TrustedType");
    const url = try out.read("typedefs/TrustedScriptURLOrUSVString.zig");
    defer testing.allocator.free(url);
    try expectIn(url, "TrustedScriptURLOrUSVString", "trusted_script_url: *runtime.Instance,");
}

test "every argument position takes the named union: last, variadic, constructor, static" {
    var out = try Generated.init("tests/codegen/fixtures/trusted_type_unions");
    defer out.deinit();
    // The interface names a typedef by its import alias, the impl stub by
    // its module.
    for ([_]struct { []const u8, []const u8 }{ .{ "interfaces/Sink.zig", "" }, .{ "impls_tmp/Sink.zig", "typedefs." } }) |file| {
        const sub_path, const prefix = file;
        const text = try out.read(sub_path);
        defer testing.allocator.free(text);
        var buffer: [128]u8 = undefined;
        for ([_][2][]const u8{
            .{ "value: ", "TrustedTypeOrDOMString" },
            .{ "text: []const ", "TrustedHTMLOrDOMString" },
            .{ "string: ", "TrustedHTMLOrDOMString" },
            .{ "html: ", "TrustedHTMLOrDOMString" },
        }) |param| {
            try expectIn(text, sub_path, try std.fmt.bufPrint(&buffer, "{s}{s}{s}", .{ param[0], prefix, param[1] }));
        }
        try expectNotIn(text, sub_path, "value: runtime.DOMString)");
    }
    // The constructor's, in the interface (the stub has no constructor).
    const interface = try out.read("interfaces/Sink.zig");
    defer testing.allocator.free(interface);
    try expectIn(interface, "interfaces/Sink.zig", "scriptURL: TrustedScriptURLOrUSVString");
}

test "an attribute's getter keeps the string type and its setter takes the named union" {
    var out = try Generated.init("tests/codegen/fixtures/trusted_type_unions");
    defer out.deinit();
    const text = try out.read("interfaces/Sink.zig");
    defer testing.allocator.free(text);
    try expectIn(text, "interfaces/Sink.zig", "pub fn get_innerHTML(instance: *runtime.Instance) anyerror!DOMString");
    try expectIn(text, "interfaces/Sink.zig", "pub fn set_innerHTML(instance: *runtime.Instance, value: typedefs.TrustedHTMLOrDOMString) anyerror!void");
    try expectIn(text, "interfaces/Sink.zig", "pub fn set_baseVal(instance: *runtime.Instance, value: typedefs.DOMStringOrTrustedScriptURL) anyerror!void");
    try expectIn(text, "interfaces/Sink.zig", "pub fn set_textContent(instance: *runtime.Instance, value: ?typedefs.TrustedScriptOrDOMString) anyerror!void");
    // [LegacyNullToEmptyString] still reaches the binding, keyed by setter.
    try expectIn(text, "interfaces/Sink.zig", ".{ \"set_innerHTML\", 0b1 },");
    const stub = try out.read("impls_tmp/Sink.zig");
    defer testing.allocator.free(stub);
    try expectIn(stub, "impls_tmp/Sink.zig", "pub fn set_innerHTML(instance: *runtime.Instance, value: typedefs.TrustedHTMLOrDOMString)");
}

test "a member member_overrides.zig lists is replaced by the supplementary declaration, in place" {
    var out = try Generated.initSources(&.{ "tests/codegen/fixtures/member_overrides/webref", "tests/codegen/fixtures/member_overrides/supplementary" });
    defer out.deinit();
    const text = try out.read("interfaces/HTMLScriptElement.zig");
    defer testing.allocator.free(text);
    try expectIn(text, "interfaces/HTMLScriptElement.zig", "pub fn set_src(instance: *runtime.Instance, value: typedefs.TrustedScriptURLOrUSVString)");
    // Its getter returns the string member's type.
    try expectIn(text, "interfaces/HTMLScriptElement.zig", "pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString");
    try expectIn(text, "interfaces/HTMLScriptElement.zig", "pub fn set_text(instance: *runtime.Instance, value: typedefs.TrustedScriptOrDOMString)");
    try expectIn(text, "interfaces/HTMLScriptElement.zig", "pub fn set_textContent(instance: *runtime.Instance, value: ?typedefs.TrustedScriptOrDOMString)");
    // Declared once each.
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, text, "pub fn set_src("));
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, text, "pub fn set_text("));
    // In the replaced member's place: src before async, text after it.
    const src_at = std.mem.indexOf(u8, text, "pub fn get_src(").?;
    const async_at = std.mem.indexOf(u8, text, "pub fn get_async(").?;
    const text_at = std.mem.indexOf(u8, text, "pub fn get_text(").?;
    try testing.expect(src_at < async_at and async_at < text_at);
}

test "a supplementary file restating a member member_overrides.zig does not list stops codegen" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try testing.expectError(error.DuplicateMember, codegen.processSources(testing.allocator, &.{
        "tests/codegen/fixtures/member_override_unlisted/webref",
        "tests/codegen/fixtures/member_override_unlisted/supplementary",
    }, &cfg));
}

test "two webref files declaring one member: the first declaration is kept, as before" {
    // cssom-view.idl restates uievents.idl's MouseEvent.screenX as a double;
    // the writers have always kept the first (long).
    var out = try Generated.init("tests/codegen/fixtures/member_overlap_webref");
    defer out.deinit();
    const text = try out.read("interfaces/Thing.zig");
    defer testing.allocator.free(text);
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, text, "pub fn get_name("));
    try expectIn(text, "interfaces/Thing.zig", "pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString");
}
