//! Integration Test Runner with Mock Server Orchestration
//!
//! This runner:
//! 1. Starts the HTTP mock server in a background thread
//! 2. Waits for the server to be ready
//! 3. Runs integration test files via the REPL
//! 4. Stops the server and reports results
//!
//! Usage: integration_test_runner <repl-exe> <test-file-1> [test-file-2] ...

const std = @import("std");
const mock_server = @import("mock_server");
const HttpMockServer = @import("http_mock_server").HttpMockServer;

/// Shared server instance for communication between main and server thread
var shared_server: ?*HttpMockServer = null;
var server_ready: std.Thread.ResetEvent = .{};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} <repl-exe> <test-file-1> [test-file-2] ...\n", .{args[0]});
        return error.InvalidArgs;
    }

    const repl_exe = args[1];
    const test_files = args[2..];

    std.debug.print("Starting integration test runner with {d} test(s)\n", .{test_files.len});

    // Start mock server in background thread
    const server_thread = try std.Thread.spawn(.{}, runMockServer, .{allocator});

    // Wait for server to be ready
    try waitForServer(allocator);

    std.debug.print("\nMock server is ready. Running tests...\n\n", .{});

    // Run each test file
    var failed_count: usize = 0;
    var total_assertions_passed: usize = 0;
    var total_assertions: usize = 0;

    for (test_files) |test_file| {
        std.debug.print("Running: {s}\n", .{test_file});

        const result = try runTest(allocator, repl_exe, test_file);

        // Track assertion counts
        total_assertions_passed += result.assertions_passed;
        total_assertions += result.assertions_total;

        // Always display assertion results from stdout
        if (result.output) |output| {
            defer allocator.free(output);
            std.debug.print("{s}", .{output});
        }

        if (!result.success) {
            failed_count += 1;
            std.debug.print("❌ FAILED: {s}\n", .{test_file});
        } else {
            std.debug.print("✅ PASSED: {s}\n", .{test_file});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n", .{});
    std.debug.print("================================================\n", .{});
    std.debug.print("Integration Test Summary\n", .{});
    std.debug.print("================================================\n", .{});
    std.debug.print("Test files:   {d} passed, {d} failed\n", .{ test_files.len - failed_count, failed_count });
    std.debug.print("Assertions:   {d}/{d} passed\n", .{ total_assertions_passed, total_assertions });
    std.debug.print("================================================\n", .{});

    // Stop the mock server
    if (shared_server) |server| {
        server.stop();
    }

    // Wait for server thread to finish
    server_thread.join();

    if (failed_count > 0) {
        std.process.exit(1);
    }
}

fn runMockServer(allocator: std.mem.Allocator) void {
    const server = HttpMockServer.init(allocator) catch |err| {
        std.debug.print("Failed to initialize mock server: {}\n", .{err});
        return;
    };
    defer server.deinit();

    // Store server reference for main thread to stop it
    shared_server = server;

    // Signal that server is ready
    server_ready.set();

    server.start() catch |err| {
        std.debug.print("Mock server error: {}\n", .{err});
    };
}

fn waitForServer(_: std.mem.Allocator) !void {
    // Wait for the server thread to signal it's ready
    server_ready.wait();

    // Also verify we can connect
    const max_attempts = 50;
    const delay_ms = 100;

    var attempt: usize = 0;
    while (attempt < max_attempts) : (attempt += 1) {
        // Try to connect to the server
        const address = std.net.Address.parseIp("127.0.0.1", 8080) catch unreachable;
        const stream = std.net.tcpConnectToAddress(address) catch {
            std.Thread.sleep(delay_ms * std.time.ns_per_ms);
            continue;
        };

        stream.close();
        return; // Server is ready
    }

    std.debug.print("Timeout waiting for mock server to start\n", .{});
    return error.ServerTimeout;
}

const TestResult = struct {
    success: bool,
    output: ?[]const u8,
    assertions_passed: usize,
    assertions_total: usize,
};

fn runTest(allocator: std.mem.Allocator, repl_exe: []const u8, test_file: []const u8) !TestResult {
    // Run: repl_exe test_file
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ repl_exe, test_file },
        .max_output_bytes = 1024 * 1024, // 1MB
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const success = switch (result.term) {
        .Exited => |code| code == 0,
        .Signal => false,
        .Stopped => false,
        .Unknown => false,
    };

    // Always capture and return stdout - it contains individual assertion results
    const output = blk: {
        if (result.stdout.len > 0) {
            break :blk try allocator.dupe(u8, result.stdout);
        } else if (result.stderr.len > 0) {
            break :blk try allocator.dupe(u8, result.stderr);
        }
        break :blk null;
    };

    // Parse assertion counts from output
    // Format: "  N/M passed" where N is passed and M is total
    var assertions_passed: usize = 0;
    var assertions_total: usize = 0;
    if (output) |out| {
        const counts = parseAssertionCounts(out);
        assertions_passed = counts.passed;
        assertions_total = counts.total;
    }

    return .{
        .success = success,
        .output = output,
        .assertions_passed = assertions_passed,
        .assertions_total = assertions_total,
    };
}

/// Parse assertion counts from repl output
/// Looks for lines like "  N/M passed"
fn parseAssertionCounts(output: []const u8) struct { passed: usize, total: usize } {
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        // Look for "N/M passed" pattern
        if (std.mem.endsWith(u8, trimmed, "passed")) {
            // Find the "N/M" part before "passed"
            const without_passed = std.mem.trimRight(u8, trimmed[0 .. trimmed.len - 6], &std.ascii.whitespace);
            // Parse "N/M"
            if (std.mem.indexOf(u8, without_passed, "/")) |slash_pos| {
                const passed_str = without_passed[0..slash_pos];
                const total_str = without_passed[slash_pos + 1 ..];
                const passed = std.fmt.parseInt(usize, passed_str, 10) catch continue;
                const total = std.fmt.parseInt(usize, total_str, 10) catch continue;
                return .{ .passed = passed, .total = total };
            }
        }
    }
    return .{ .passed = 0, .total = 0 };
}
