//! The codegen command line: several sources in one invocation, one model.

const std = @import("std");
const codegen = @import("codegen");
const cli = codegen.cli;
const testing = std.testing;

test "two sources in one invocation are both kept, in order" {
    var options = try cli.parseArgs(testing.allocator, &.{ "specs/idl", "specs/supplementary", "--dest-root", "src/webidl/" });
    defer options.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), options.sources.len);
    try testing.expectEqualStrings("specs/idl", options.sources[0]);
    try testing.expectEqualStrings("specs/supplementary", options.sources[1]);
    try testing.expectEqualStrings("src/webidl/", options.dest_root.?);
}

test "no source means the default sources" {
    var options = try cli.parseArgs(testing.allocator, &.{ "--dest-root", "src/webidl/" });
    defer options.deinit(testing.allocator);
    try testing.expectEqual(cli.default_sources.len, options.sources.len);
    for (cli.default_sources, options.sources) |expected, actual| try testing.expectEqualStrings(expected, actual);
}

test "an unknown flag is an error, not a source" {
    try testing.expectError(error.UnknownArgument, cli.parseArgs(testing.allocator, &.{ "specs/idl", "--bogus", "--dest-root", "src/webidl/" }));
    try testing.expectError(error.UnknownArgument, cli.parseArgs(testing.allocator, &.{ "--bogus", "--dest-root", "src/webidl/" }));
}

test "--dest-root is required and needs a value" {
    try testing.expectError(error.MissingDestRoot, cli.parseArgs(testing.allocator, &.{"specs/idl"}));
    try testing.expectError(error.MissingDestRoot, cli.parseArgs(testing.allocator, &.{ "specs/idl", "--dest-root" }));
}

test "--check compares a regeneration in --scratch against --dest-root" {
    var options = try cli.parseArgs(testing.allocator, &.{ "--check", "--dest-root", "src/webidl/", "--scratch", "/tmp/x" });
    defer options.deinit(testing.allocator);
    try testing.expect(options.check);
    try testing.expectEqualStrings("/tmp/x", options.scratch.?);
    try testing.expectError(error.MissingScratch, cli.parseArgs(testing.allocator, &.{ "--check", "--dest-root", "src/webidl/", "--scratch" }));
}
