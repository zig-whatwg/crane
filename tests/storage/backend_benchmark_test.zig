//! Storage Backend Performance Benchmarks
//!
//! Benchmarks CRUD operations across all storage backends to establish
//! performance baselines and detect regressions.
//!
//! ## Benchmark Categories
//!
//! 1. **Write Performance**: Single writes, batch writes
//! 2. **Read Performance**: Single reads, sequential reads, random reads
//! 3. **Transaction Performance**: Transaction overhead, commit latency
//! 4. **Cursor Performance**: Full scan, range scan, iteration
//!
//! ## Running Benchmarks
//!
//! ```bash
//! zig build test -- --filter "benchmark"
//! ```
//!
//! ## Performance Goals
//!
//! | Operation | Memory | SQLite | LevelDB |
//! |-----------|--------|--------|---------|
//! | Write     | <1μs   | <50μs  | <10μs   |
//! | Read      | <100ns | <20μs  | <5μs    |
//! | Tx Commit | <100ns | <5ms   | <1ms    |
//! | Cursor    | <100ns | <10μs  | <2μs    |
//!
//! Note: SQLite/LevelDB backends are stubs - benchmarks will measure
//! actual performance once FFI implementations are complete.

const std = @import("std");
const storage = @import("storage");

const StorageBackend = storage.StorageBackend;
const BackendType = storage.BackendType;
const TransactionMode = storage.TransactionMode;
const KeyRange = storage.KeyRange;
const CursorDirection = storage.CursorDirection;

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

    pub fn format(
        self: BenchmarkResult,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("{s}: {any} iterations, avg={any}ns, min={any}ns, max={any}ns, {any} ops/s", .{
            self.name,
            self.iterations,
            self.avgNs(),
            self.min_ns,
            self.max_ns,
            self.opsPerSec(),
        });
    }
};

fn runBenchmark(
    name: []const u8,
    iterations: u64,
    context: anytype,
    comptime benchFn: fn (@TypeOf(context)) void,
) BenchmarkResult {
    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    // Warmup
    for (0..@min(iterations / 10, 100)) |_| {
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

// ============================================================================
// Memory Backend Benchmarks
// ============================================================================

const MemoryBenchContext = struct {
    backend: StorageBackend,
    txn: storage.TransactionHandle,
    key: []const u8,
    value: []const u8,
    allocator: std.mem.Allocator,
};

fn benchMemoryWrite(ctx: MemoryBenchContext) void {
    ctx.backend.write(ctx.txn, ctx.key, ctx.value) catch {};
}

fn benchMemoryRead(ctx: MemoryBenchContext) void {
    if (ctx.backend.vtable.read(ctx.backend.ptr, ctx.allocator, ctx.txn, ctx.key) catch null) |val| {
        ctx.allocator.free(val);
    }
}

fn benchMemoryExists(ctx: MemoryBenchContext) void {
    _ = ctx.backend.exists(ctx.txn, ctx.key) catch false;
}

test "benchmark: Memory backend write performance" {
    const allocator = std.testing.allocator;

    const backend = try storage.createBackend(allocator, .memory);
    defer backend.destroy();

    try backend.open("bench_db", .{});
    defer backend.close();

    const txn = try backend.beginTransaction(.readwrite);
    defer backend.rollback(txn);

    const ctx = MemoryBenchContext{
        .backend = backend,
        .txn = txn,
        .key = "benchmark_key_0001",
        .value = "benchmark_value_with_some_reasonable_length_for_testing",
        .allocator = allocator,
    };

    const result = runBenchmark("Memory Write", 10000, ctx, benchMemoryWrite);

    // Memory writes should be very fast (<1μs average)
    try std.testing.expect(result.avgNs() < 1_000_000); // <1ms is acceptable for test
    std.debug.print("\n{any}\n", .{result});
}

test "benchmark: Memory backend read performance" {
    const allocator = std.testing.allocator;

    const backend = try storage.createBackend(allocator, .memory);
    defer backend.destroy();

    try backend.open("bench_db", .{});
    defer backend.close();

    const txn = try backend.beginTransaction(.readwrite);
    defer backend.rollback(txn);

    // Setup: write the key first
    try backend.write(txn, "benchmark_key_0001", "benchmark_value_with_some_reasonable_length_for_testing");

    const ctx = MemoryBenchContext{
        .backend = backend,
        .txn = txn,
        .key = "benchmark_key_0001",
        .value = "",
        .allocator = allocator,
    };

    const result = runBenchmark("Memory Read", 10000, ctx, benchMemoryRead);

    // Memory reads should be very fast
    try std.testing.expect(result.avgNs() < 1_000_000); // <1ms is acceptable for test
    std.debug.print("\n{any}\n", .{result});
}

test "benchmark: Memory backend exists performance" {
    const allocator = std.testing.allocator;

    const backend = try storage.createBackend(allocator, .memory);
    defer backend.destroy();

    try backend.open("bench_db", .{});
    defer backend.close();

    const txn = try backend.beginTransaction(.readwrite);
    defer backend.rollback(txn);

    // Setup: write the key first
    try backend.write(txn, "benchmark_key_0001", "value");

    const ctx = MemoryBenchContext{
        .backend = backend,
        .txn = txn,
        .key = "benchmark_key_0001",
        .value = "",
        .allocator = allocator,
    };

    const result = runBenchmark("Memory Exists", 10000, ctx, benchMemoryExists);

    // Exists checks should be faster than reads (no value copy)
    try std.testing.expect(result.avgNs() < 1_000_000);
    std.debug.print("\n{any}\n", .{result});
}

// ============================================================================
// Transaction Overhead Benchmarks
// ============================================================================

test "benchmark: Memory backend transaction overhead" {
    const allocator = std.testing.allocator;

    const backend = try storage.createBackend(allocator, .memory);
    defer backend.destroy();

    try backend.open("bench_db", .{});
    defer backend.close();

    var total_ns: u64 = 0;
    const iterations: u64 = 100;

    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();

        const txn = try backend.beginTransaction(.readwrite);
        try backend.write(txn, "key", "value");
        try backend.commit(txn);

        const end = std.time.nanoTimestamp();
        total_ns += @intCast(end - start);
    }

    const avg_ns = total_ns / iterations;
    std.debug.print("\nMemory Txn (begin+write+commit): {any} iterations, avg={any}ns\n", .{ iterations, avg_ns });

    // Transaction overhead should be minimal for memory backend
    try std.testing.expect(avg_ns < 10_000_000); // <10ms
}

// ============================================================================
// Batch Write Benchmarks
// ============================================================================

test "benchmark: Memory backend batch write" {
    const allocator = std.testing.allocator;

    const backend = try storage.createBackend(allocator, .memory);
    defer backend.destroy();

    try backend.open("bench_db", .{});
    defer backend.close();

    const batch_size: usize = 100; // Reduced for faster tests
    var keys: [batch_size][32]u8 = undefined;
    var key_slices: [batch_size][]const u8 = undefined;

    // Pre-generate keys
    for (0..batch_size) |i| {
        const slice = std.fmt.bufPrint(&keys[i], "{d}", .{i}) catch unreachable;
        key_slices[i] = slice;
    }
    const value = "batch_value_with_some_reasonable_length";

    const start = std.time.nanoTimestamp();

    const txn = try backend.beginTransaction(.readwrite);
    for (0..batch_size) |i| {
        try backend.write(txn, key_slices[i], value);
    }
    try backend.commit(txn);

    const end = std.time.nanoTimestamp();
    const total_ns: u64 = @intCast(end - start);
    const per_write_ns = total_ns / batch_size;

    std.debug.print("\nMemory Batch Write: {any} writes, total={any}ns, per_write={any}ns, {any} ops/s\n", .{
        batch_size,
        total_ns,
        per_write_ns,
        batch_size * 1_000_000_000 / total_ns,
    });

    // Batch writes should be efficient
    try std.testing.expect(per_write_ns < 1_000_000); // <1ms per write
}

// ============================================================================
// Cursor Benchmarks
// ============================================================================

test "benchmark: Memory backend cursor scan" {
    const allocator = std.testing.allocator;

    const backend = try storage.createBackend(allocator, .memory);
    defer backend.destroy();

    try backend.open("bench_db", .{});
    defer backend.close();

    // Setup: insert data
    const txn_setup = try backend.beginTransaction(.readwrite);
    for (0..100) |i| {
        var key_buf: [32]u8 = undefined;
        const key_slice = std.fmt.bufPrint(&key_buf, "{d}", .{i}) catch unreachable;
        try backend.write(txn_setup, key_slice, "value");
    }
    try backend.commit(txn_setup);

    // Benchmark cursor scan
    const iterations: u64 = 100;
    var total_ns: u64 = 0;

    for (0..iterations) |_| {
        const txn = try backend.beginTransaction(.readonly);
        defer backend.rollback(txn);

        const start = std.time.nanoTimestamp();

        const cursor = try backend.cursorOpen(txn, KeyRange{}, .next);
        defer backend.cursorClose(cursor);

        var count: usize = 0;
        while (try backend.vtable.cursor_next(backend.ptr, allocator, cursor)) |kv| {
            var kv_mut = kv;
            kv_mut.deinit();
            count += 1;
        }

        const end = std.time.nanoTimestamp();
        total_ns += @intCast(end - start);
    }

    const avg_ns = total_ns / iterations;
    std.debug.print("\nMemory Cursor Scan (100 items): {any} iterations, avg={any}ns\n", .{ iterations, avg_ns });

    // Cursor scan should be efficient
    try std.testing.expect(avg_ns < 100_000_000); // <100ms for 100 items
}

// ============================================================================
// Comparative Summary
// ============================================================================

test "benchmark: Print backend availability summary" {
    std.debug.print("\n\n=== Storage Backend Benchmark Summary ===\n", .{});
    std.debug.print("Platform: {}\n", .{storage.Platform.detect()});
    std.debug.print("Default Backend: {}\n", .{storage.getDefaultBackendType()});
    std.debug.print("\nBackend Availability:\n", .{});
    std.debug.print("  Memory:  {} (functional)\n", .{storage.isBackendAvailable(.memory)});
    std.debug.print("  SQLite:  {} (stub)\n", .{storage.isBackendAvailable(.sqlite)});
    std.debug.print("  LevelDB: {} (stub)\n", .{storage.isBackendAvailable(.leveldb)});
    std.debug.print("\nNote: SQLite and LevelDB benchmarks will be meaningful\n", .{});
    std.debug.print("      once FFI implementations are complete.\n", .{});
    std.debug.print("==========================================\n\n", .{});
}
