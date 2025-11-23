const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: test_runner <repl_path> <test_file>\n", .{});
        std.process.exit(1);
    }

    const repl_path = args[1];
    const test_file = args[2];

    // Read test file
    const file = try std.fs.cwd().openFile(test_file, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    // Run REPL with test file as stdin
    var child = std.process.Child.init(&.{repl_path}, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Write test file to stdin
    try child.stdin.?.writeAll(content);
    child.stdin.?.close();
    child.stdin = null;

    // Read output
    const stdout = try child.stdout.?.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(stdout);

    const stderr = try child.stderr.?.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(stderr);

    _ = try child.wait();

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
