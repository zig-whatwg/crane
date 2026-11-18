//! Fetch's Request constructor reads whether RequestInit's `signal` EXISTS
//! apart from its value: "If init["signal"] exists, then set signal to it"
//! (step 29) - `{signal: null}` removes the input Request's signal - and a
//! present member makes init non-empty (step 13). Read as a plain `?T`, a
//! present null was "absent": `fetch(request, {signal: null})` kept an aborted
//! request's signal and rejected (fetch/api/abort/general.any.js "Signal
//! removed by setting to null"). So the member keeps its presence
//! (`webidl.Opt(?T)`), as ShadowRootInit.customElementRegistry does; another
//! dictionary's nullable member stays a plain optional.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn generated(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", allocator);
    defer allocator.free(root);
    var config = codegen.config.CodegenConfig{ .allocator = allocator, .dest_root = root };
    defer config.deinit();
    try codegen.processSources(allocator, &.{"tests/codegen/fixtures/net1_signal_presence"}, &config);
    const file = try std.fmt.allocPrint(allocator, "dictionaries/{s}.zig", .{name});
    defer allocator.free(file);
    const path = try std.fs.path.join(allocator, &.{ root, file });
    defer allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, allocator, .limited(65536));
}

test "net1 codegen: RequestInit's signal keeps its presence" {
    const output = try generated(testing.allocator, "RequestInit");
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "signal: webidl.Opt(?*runtime.Instance) = .notPassed()") != null);
    try testing.expect(std.mem.indexOf(u8, output, "const webidl = @import(\"webidl\");") != null);
}

test "net1 codegen: another dictionary's nullable signal stays a plain optional" {
    const output = try generated(testing.allocator, "OtherInit");
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "signal: ?*runtime.Instance = null") != null);
}
