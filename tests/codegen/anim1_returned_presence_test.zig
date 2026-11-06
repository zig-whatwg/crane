//! getComputedTiming() sets ComputedEffectTiming's progress, currentIteration
//! and localTime explicitly, null included (Web Animations 1 6.5.5): the
//! returned object must carry a present null as a null property (WebIDL
//! 3.2.18, dictionary to an ECMAScript value), so those members keep their
//! presence (`webidl.Opt(?T)`) apart from their value. A nullable member of
//! any other dictionary keeps the plain `?T` (TODO(anim1): the general rule,
//! queued in tmp/plans/lane-anim1-handoff.md).
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
    try codegen.processSources(allocator, &.{"tests/codegen/fixtures/anim1_presence"}, &config);
    const file = try std.fmt.allocPrint(allocator, "dictionaries/{s}.zig", .{name});
    defer allocator.free(file);
    const path = try std.fs.path.join(allocator, &.{ root, file });
    defer allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, allocator, .limited(65536));
}

test "anim1 codegen: ComputedEffectTiming's nullable members keep their presence" {
    const output = try generated(testing.allocator, "ComputedEffectTiming");
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "progress: webidl.Opt(?f64) = .notPassed()") != null);
    try testing.expect(std.mem.indexOf(u8, output, "currentIteration: webidl.Opt(?f64) = .notPassed()") != null);
    try testing.expect(std.mem.indexOf(u8, output, "localTime: webidl.Opt(?f64) = .notPassed()") != null);
}

test "anim1 codegen: another dictionary's nullable member stays a plain optional" {
    const output = try generated(testing.allocator, "OtherNullable");
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "value: ?f64 = null") != null);
}
