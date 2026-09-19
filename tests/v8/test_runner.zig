const std = @import("std");

// Zig 0.16 removed std.process.argsAlloc; command-line arguments are no longer
// process-global. They arrive through std.process.Init, which also supplies the
// gpa, a process-lifetime arena and an Io - so taking Init replaces the hand-rolled
// allocator setup as well.
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 3) {
        std.debug.print("Usage: test_runner <repl_path> <test_file>\n", .{});
        std.process.exit(1);
    }

    const repl_path = args[1];
    const test_file = args[2];

    // Read test file
    const file = try std.Io.Dir.cwd().openFile(init.io, test_file, .{});
    defer file.close(init.io);

    var file_reader = file.reader(init.io, &.{});
    const content = try file_reader.interface.allocRemaining(allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(content);

    // Run REPL with test file as stdin
    var child = std.process.Child.init(&.{repl_path}, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Write test file to stdin
    try child.stdin.?.writeStreamingAll(init.io, content);
    child.stdin.?.close(init.io);
    child.stdin = null;

    // Read output
    var stdout_reader = child.stdout.?.readerStreaming(init.io, &.{});
    const stdout = try stdout_reader.interface.allocRemaining(allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(stdout);

    var stderr_reader = child.stderr.?.readerStreaming(init.io, &.{});
    const stderr = try stderr_reader.interface.allocRemaining(allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(stderr);

    _ = try child.wait(init.io);

    // Count results
    var total: usize = 0;
    var passed: usize = 0;
    var failed: usize = 0;

    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (std.mem.eql(u8, trimmed, "true")) {
            total += 1;
            passed += 1;
        } else if (std.mem.eql(u8, trimmed, "false")) {
            total += 1;
            failed += 1;
        }
    }

    // Print results
    const test_name = std.fs.path.basename(test_file);
    std.debug.print("\n=== {s} ===\n", .{test_name});
    std.debug.print("Total:  {d}\n", .{total});
    std.debug.print("Passed: {d}\n", .{passed});
    std.debug.print("Failed: {d}\n", .{failed});

    if (total > 0) {
        const percentage = @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total)) * 100.0;
        std.debug.print("Success Rate: {d:.1}%\n", .{percentage});
    }

    std.debug.print("\n", .{});

    // Exit with error if any tests failed
    if (failed > 0) {
        std.debug.print("❌ {d} test(s) failed\n", .{failed});
        std.process.exit(1);
    } else if (total == 0) {
        std.debug.print("⚠️  No tests found\n", .{});
        std.process.exit(1);
    } else {
        std.debug.print("✅ All tests passed!\n", .{});
    }
}
