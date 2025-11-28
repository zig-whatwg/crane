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
    for (test_files) |test_file| {
        std.debug.print("Running: {s}\n", .{test_file});

        const result = try runTest(allocator, repl_exe, test_file);

        if (!result.success) {
            failed_count += 1;
            std.debug.print("❌ FAILED: {s}\n", .{test_file});
            if (result.output) |output| {
                std.debug.print("{s}\n", .{output});
            }
        } else {
            std.debug.print("✅ PASSED: {s}\n", .{test_file});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n", .{});
    std.debug.print("================================================\n", .{});
    std.debug.print("Integration Test Summary\n", .{});
    std.debug.print("================================================\n", .{});
    std.debug.print("Total tests:  {d}\n", .{test_files.len});
    std.debug.print("Passed:       {d}\n", .{test_files.len - failed_count});
    std.debug.print("Failed:       {d}\n", .{failed_count});
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

    const output = if (!success) blk: {
        if (result.stderr.len > 0) {
            break :blk try allocator.dupe(u8, result.stderr);
        } else if (result.stdout.len > 0) {
            break :blk try allocator.dupe(u8, result.stdout);
        }
        break :blk null;
    } else null;

    return .{
        .success = success,
        .output = output,
    };
}
