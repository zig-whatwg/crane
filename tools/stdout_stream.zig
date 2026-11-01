//! stdout for Crane's tools, written as a stream.
//!
//! Zig 0.17's `File.writer` is positional: it writes at an offset it tracks
//! itself, starting at 0. When a tool's stdout is a log file the shell opened
//! and other processes also write to (the pool's `crane-measure.sh` and
//! `/usr/bin/time -l` share `> log 2>&1` with it), a positional writer
//! overwrites their lines and they overwrite the tool's: the damaged log looks
//! like a crash. `writerStreaming` writes at the file's current offset, as a
//! plain `write` does, so it appends (docs/lessons/
//! workflow-zig-017s-file-writer-is-positional-and-overwrites-a-shared-log.md).
//!
//! Imported by path from the tools/ roots that print to stdout:
//! `const stdout_stream = @import("stdout_stream.zig");`.

const std = @import("std");

/// A buffered writer on stdout that appends to whatever stdout already holds.
pub fn writer(io: std.Io, buffer: []u8) std.Io.File.Writer {
    return writerOn(std.Io.File.stdout(), io, buffer);
}

/// `writer` on any file: what the test drives, since a test cannot replace
/// its own stdout.
pub fn writerOn(file: std.Io.File, io: std.Io, buffer: []u8) std.Io.File.Writer {
    return file.writerStreaming(io, buffer);
}

test "a tool's output lands after what another writer of the same file wrote first, never over it" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile(io, "shared.log", .{ .read = true });
    defer file.close(io);
    // Another process sharing the shell's `> log` writes first: the file's
    // offset moves past its line.
    try file.writeStreamingAll(io, "holds 2 of 14\n");

    var buffer: [64]u8 = undefined;
    var tool = writerOn(file, io, &buffer);
    try tool.interface.writeAll("lint: 0 new references\n");
    try tool.interface.flush();
    // And the other writer again after the tool (time -l's report at exit).
    try file.writeStreamingAll(io, "real 1.0\n");

    const contents = try tmp.dir.readFileAlloc(io, "shared.log", std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(contents);
    try std.testing.expectEqualStrings("holds 2 of 14\nlint: 0 new references\nreal 1.0\n", contents);
}
