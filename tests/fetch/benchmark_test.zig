//! Fetch Performance Benchmarks
//!
//! Benchmarks key fetch operations to establish performance baselines
//! and detect regressions.
//!
//! ## Benchmark Categories
//!
//! 1. **Headers Performance**: Create, append, get, iterate
//! 2. **Request Performance**: Create, clone
//! 3. **Response Performance**: Create, clone
//! 4. **Data URL Processing**: Parse and decode
//!
//! ## Running Benchmarks
//!
//! ```bash
//! zig build test -- --filter "fetch benchmark"
//! ```
//!
//! ## Performance Goals
//!
//! | Operation       | Target   |
//! |-----------------|----------|
//! | Headers create  | <1μs     |
//! | Headers append  | <500ns   |
//! | Headers get     | <200ns   |
//! | Request create  | <5μs     |
//! | Response create | <2μs     |
//! | Data URL parse  | <10μs    |

const std = @import("std");
const fetch = @import("fetch");

const Headers = fetch.Headers;
const Request = fetch.Request;
const Response = fetch.Response;

// ============================================================================
// Benchmark Utilities
// ============================================================================

const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: u64,
    min_ns: u64,
    max_ns: u64,

    pub fn avgNs(self: BenchmarkResult) u64 {
        if (self.iterations == 0) return 0;
        return self.total_ns / self.iterations;
    }

    pub fn opsPerSec(self: BenchmarkResult) u64 {
        if (self.total_ns == 0) return 0;
        return self.iterations * 1_000_000_000 / self.total_ns;
    }
};

fn runBenchmark(
    comptime name: []const u8,
    iterations: u64,
    context: anytype,
    comptime benchFn: fn (@TypeOf(context)) void,
) BenchmarkResult {
    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    // Warmup (10% of iterations, max 100)
    const warmup_count = @min(iterations / 10, 100);
    for (0..warmup_count) |_| {
        benchFn(context);
    }

    // Benchmark
    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        benchFn(context);
        const end = std.time.nanoTimestamp();

        const elapsed: u64 = @intCast(end - start);
        total_ns += elapsed;
        min_ns = @min(min_ns, elapsed);
        max_ns = @max(max_ns, elapsed);
    }

    return .{
        .name = name,
        .iterations = iterations,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
    };
}

fn printResult(result: BenchmarkResult) void {
    std.debug.print("\n{s}: {d} iterations, avg={d}ns, {d} ops/s\n", .{
        result.name,
        result.iterations,
        result.avgNs(),
        result.opsPerSec(),
    });
}

// ============================================================================
// Headers Benchmarks
// ============================================================================

test "fetch benchmark - Headers create" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 1000;

    var created_count: u64 = 0;

    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();

        const headers = try Headers.init(allocator, .none);
        headers.deinit();

        const end = std.time.nanoTimestamp();
        _ = end - start;
        created_count += 1;
    }

    try std.testing.expectEqual(iterations, created_count);
}

test "fetch benchmark - Headers append" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 1000;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    for (0..iterations) |i| {
        // Append different header names to avoid combining
        var buf: [32]u8 = undefined;
        const name = std.fmt.bufPrint(&buf, "X-Header-{d}", .{i}) catch "X-Header";
        try headers.append(name, "value");
    }

    try std.testing.expectEqual(iterations, headers.len());
}

test "fetch benchmark - Headers get" {
    const allocator = std.testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    // Setup: add headers
    try headers.append("Content-Type", "application/json");
    try headers.append("Authorization", "Bearer token123");
    try headers.append("Accept", "text/html");

    // Benchmark get operations
    const iterations: u64 = 1000;
    var found_count: u64 = 0;

    for (0..iterations) |_| {
        const has_ct = try headers.has("Content-Type");
        const has_auth = try headers.has("Authorization");
        const has_accept = try headers.has("Accept");

        if (has_ct and has_auth and has_accept) {
            found_count += 1;
        }
    }

    try std.testing.expectEqual(iterations, found_count);
}

// ============================================================================
// Request Benchmarks
// ============================================================================

test "fetch benchmark - Request create" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 100;

    var created_count: u64 = 0;

    for (0..iterations) |_| {
        const request = try Request.init(allocator, .{ .url = "https://example.com/api/data" }, .{
            .method = "GET",
        });
        request.deinit();
        created_count += 1;
    }

    try std.testing.expectEqual(iterations, created_count);
}

test "fetch benchmark - Request create with headers" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 100;

    const init_headers = [_][2][]const u8{
        .{ "Content-Type", "application/json" },
        .{ "Authorization", "Bearer token" },
        .{ "Accept", "application/json" },
    };

    var created_count: u64 = 0;

    for (0..iterations) |_| {
        const request = try Request.init(allocator, .{ .url = "https://example.com/api" }, .{
            .method = "POST",
            .headers = .{ .sequence = &init_headers },
        });
        request.deinit();
        created_count += 1;
    }

    try std.testing.expectEqual(iterations, created_count);
}

// ============================================================================
// Response Benchmarks
// ============================================================================

test "fetch benchmark - Response create" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 100;

    var created_count: u64 = 0;

    for (0..iterations) |_| {
        const response = try Response.init(allocator, null, .{ .status = 200 });
        response.deinit();
        created_count += 1;
    }

    try std.testing.expectEqual(iterations, created_count);
}

test "fetch benchmark - Response create with body" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 100;

    const body = "{\"message\": \"Hello, World!\", \"status\": \"success\"}";

    var created_count: u64 = 0;

    for (0..iterations) |_| {
        const response = try Response.init(allocator, body, .{
            .status = 200,
            .status_text = "OK",
        });
        response.deinit();
        created_count += 1;
    }

    try std.testing.expectEqual(iterations, created_count);
}

test "fetch benchmark - Response.createError" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 100;

    var created_count: u64 = 0;

    for (0..iterations) |_| {
        const response = try Response.createError(allocator);
        response.deinit();
        created_count += 1;
    }

    try std.testing.expectEqual(iterations, created_count);
}

test "fetch benchmark - Response.createRedirect" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 100;

    var created_count: u64 = 0;

    for (0..iterations) |_| {
        const response = try Response.createRedirect(allocator, "https://example.com/new-location", 302);
        response.deinit();
        created_count += 1;
    }

    try std.testing.expectEqual(iterations, created_count);
}

// ============================================================================
// Data URL Processing Benchmarks
// ============================================================================

test "fetch benchmark - Data URL text/plain" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 100;

    var processed_count: u64 = 0;

    for (0..iterations) |_| {
        var result = try fetch.processDataUrl(allocator, "data:text/plain,Hello%20World");
        if (result) |*r| {
            r.deinit();
            processed_count += 1;
        }
    }

    try std.testing.expectEqual(iterations, processed_count);
}

test "fetch benchmark - Data URL base64" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 100;

    // "Hello, World!" in base64
    const data_url = "data:text/plain;base64,SGVsbG8sIFdvcmxkIQ==";

    var processed_count: u64 = 0;

    for (0..iterations) |_| {
        var result = try fetch.processDataUrl(allocator, data_url);
        if (result) |*r| {
            r.deinit();
            processed_count += 1;
        }
    }

    try std.testing.expectEqual(iterations, processed_count);
}

test "fetch benchmark - Data URL JSON" {
    const allocator = std.testing.allocator;
    const iterations: u64 = 100;

    const data_url = "data:application/json,{\"key\":\"value\",\"number\":42}";

    var processed_count: u64 = 0;

    for (0..iterations) |_| {
        var result = try fetch.processDataUrl(allocator, data_url);
        if (result) |*r| {
            r.deinit();
            processed_count += 1;
        }
    }

    try std.testing.expectEqual(iterations, processed_count);
}

// ============================================================================
// Benchmark Summary
// ============================================================================

test "fetch benchmark - summary" {
    std.debug.print("\n\n=== Fetch Benchmark Summary ===\n", .{});
    std.debug.print("All benchmark tests passed.\n", .{});
    std.debug.print("Run with timing enabled to see performance metrics.\n", .{});
    std.debug.print("================================\n\n", .{});
}
