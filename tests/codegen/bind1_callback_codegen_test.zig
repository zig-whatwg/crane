//! Generated callback invocation, callback-interface typed call helpers, and
//! nullable sequence element typing (lane bind1 batch B6).
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

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
        try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/bind1_callback_codegen"}, &config);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    fn fileIn(self: *Generated, dir: []const u8, name: []const u8) ![]u8 {
        const path = try std.fmt.allocPrint(testing.allocator, "{s}/{s}/{s}.zig", .{ self.root, dir, name });
        defer testing.allocator.free(path);
        return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
    }
};

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "generated non-promise callbacks emit Return, return_options, typed Args, invoke and construct" {
    var out = try Generated.init();
    defer out.deinit();

    // Variadic nullable DOMString return
    {
        const file = try out.fileIn("callbacks", "SampleCreateHTML");
        defer testing.allocator.free(file);
        try testing.expect(contains(file, "pub const SampleCreateHTML = runtime.BorrowedCallbackFunction;"));
        try testing.expect(contains(file, "pub const Return = ?runtime.DOMString;"));
        try testing.expect(contains(file, "pub const Args = struct {"));
        try testing.expect(contains(file, "input: runtime.DOMString,"));
        try testing.expect(contains(file, "arguments: []const runtime.JSValue = &.{},"));
        try testing.expect(contains(file, "pub fn invoke("));
        try testing.expect(contains(file, "engine.invokeCallbackFunctionAs(Return, return_options, realm, callback, this_arg, args, behavior, allocator)"));
        try testing.expect(contains(file, "pub fn construct("));
    }

    // Dictionary return + optional primitive parameter
    {
        const file = try out.fileIn("callbacks", "SampleCreateOptions");
        defer testing.allocator.free(file);
        try testing.expect(contains(file, "pub const Return = ?dictionaries.SampleOptions;"));
        try testing.expect(contains(file, "options: dictionaries.SampleOptions,"));
        try testing.expect(contains(file, "count: webidl.Opt(i32) = .notPassed(),"));
    }

    // Unrestricted double vs restricted double vs ByteString
    {
        const unrestricted = try out.fileIn("callbacks", "SampleSize");
        defer testing.allocator.free(unrestricted);
        try testing.expect(contains(unrestricted, "pub const Return = f64;"));
        try testing.expect(contains(unrestricted, "pub const return_options: engine.ReturnOptions = .{};"));

        const restricted = try out.fileIn("callbacks", "SampleRestricted");
        defer testing.allocator.free(restricted);
        try testing.expect(contains(restricted, "pub const Return = f64;"));
        try testing.expect(contains(restricted, ".restricted_float = true"));

        const byte_str = try out.fileIn("callbacks", "SampleByteString");
        defer testing.allocator.free(byte_str);
        try testing.expect(contains(byte_str, "pub const Return = runtime.ByteString;"));
        try testing.expect(contains(byte_str, ".byte_string = true"));
    }

    // Interface-returning constructor callback carries ReturnOptions.interface
    {
        const ctor = try out.fileIn("callbacks", "SampleConstructor");
        defer testing.allocator.free(ctor);
        try testing.expect(contains(ctor, "pub const Return = *runtime.Instance;"));
        try testing.expect(contains(ctor, ".interface = interfaces.HTMLElement"));
        try testing.expect(contains(ctor, "engine.constructCallbackFunctionAs(Return, return_options, realm, callback, args, allocator)"));
    }
}

test "generated promise callbacks emit invokeCallbackFunctionToPromise and callbacks/root.zig exports call namespace" {
    var out = try Generated.init();
    defer out.deinit();

    const file = try out.fileIn("callbacks", "SamplePromise");
    defer testing.allocator.free(file);
    try testing.expect(contains(file, "pub const is_promise = true;"));
    try testing.expect(contains(file, "node: *runtime.Instance,"));
    try testing.expect(contains(file, "engine.invokeCallbackFunctionToPromise(.webidl, realm, callback, this_arg, args)"));
    try testing.expect(contains(file, "pub fn invokePromiseResolve("));
    try testing.expect(contains(file, "engine.invokeCallbackFunctionToPromise(.promise_resolve, realm, callback, this_arg, args)"));

    const root = try out.fileIn("callbacks", "root");
    defer testing.allocator.free(root);
    try testing.expect(contains(root, "pub const SamplePromise = @import(\"SamplePromise.zig\").SamplePromise;"));
    try testing.expect(contains(root, "pub const call = struct {"));
    try testing.expect(contains(root, "pub const SamplePromise = @import(\"SamplePromise.zig\");"));
}

test "generated callback interfaces emit typed invoke_<op> calling callUserObjectOperationAs" {
    var out = try Generated.init();
    defer out.deinit();

    const filter = try out.fileIn("interfaces", "SampleFilter");
    defer testing.allocator.free(filter);
    try testing.expect(contains(filter, "pub fn invoke_acceptNode("));
    try testing.expect(contains(filter, "engine.callUserObjectOperationAs(u16, .{}, realm, callback, \"acceptNode\", this_arg, .{node}, behavior, allocator)"));

    const resolver = try out.fileIn("interfaces", "SampleResolver");
    defer testing.allocator.free(resolver);
    try testing.expect(contains(resolver, "pub fn invoke_lookupNamespaceURI("));
    try testing.expect(contains(resolver, "engine.callUserObjectOperationAs(?runtime.DOMString, .{}, realm, callback, \"lookupNamespaceURI\", this_arg, .{prefix}, behavior, allocator)"));
}

test "sequence<double?> in a union typedef emits []const ?f64 and appears in restricted_arms" {
    var out = try Generated.init();
    defer out.deinit();

    const offset = try out.fileIn("typedefs", "SampleOffset");
    defer testing.allocator.free(offset);
    try testing.expect(contains(offset, "double_sequence: []const ?f64,"));
    try testing.expect(contains(offset, "pub const restricted_arms = .{ \"double\", \"double_sequence\" };"));
}
