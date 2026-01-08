//! Minimal V8 Snapshot Test
//!
//! This tool tests V8 snapshots in isolation to find where they break.
//! It starts with ZERO external references and incrementally adds complexity.
//!
//! Usage:
//!   zig build minimal-snapshot-test
//!   ./zig-out/bin/minimal_snapshot_test
//!
//! The test creates snapshots in /tmp/ and reports success/failure at each stage.

const std = @import("std");
const v8 = @import("v8");

// ============================================================================
// Test Levels - Each level adds more complexity
// ============================================================================

const TestLevel = enum {
    /// Level 0: Absolutely minimal - zero external refs, empty context
    bare_minimum,
    /// Level 1: Add one simple callback
    single_callback,
    /// Level 2: Add a few callbacks
    few_callbacks,
    /// Level 3: Add C++ callbacks (async iterator)
    cpp_callbacks,
    /// Level 4: Add many callbacks (simulate interfaces)
    many_callbacks,
};

/// Test result for reporting
const TestResult = struct {
    level: TestLevel,
    create_success: bool,
    load_success: bool,
    blob_size: usize,
    error_message: ?[]const u8,
};

// ============================================================================
// Simple Test Callbacks
// ============================================================================

fn dummyCallback1(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {}
fn dummyCallback2(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {}
fn dummyCallback3(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {}
fn dummyCallback4(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {}
fn dummyCallback5(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {}

// More callbacks for stress testing
fn dummyCallback6(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {}
fn dummyCallback7(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {}
fn dummyCallback8(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {}
fn dummyCallback9(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {}
fn dummyCallback10(_: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {}

// ============================================================================
// Main Test Runner
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout();

    // Check for --multi-context flag (BSCOPE-10 test mode)
    var args = std.process.args();
    _ = args.skip(); // skip program name
    var multi_context_mode = false;
    var snapshot_path: []const u8 = "whatwg_snapshot.bin";

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--multi-context")) {
            multi_context_mode = true;
        } else if (std.mem.startsWith(u8, arg, "--snapshot=")) {
            snapshot_path = arg[11..];
        }
    }

    if (multi_context_mode) {
        try testMultiContextSnapshot(snapshot_path);
        return;
    }

    try stdout.writeAll("=================================================\n");
    try stdout.writeAll("Minimal V8 Snapshot Test - Isolating Failure Point\n");
    try stdout.writeAll("=================================================\n\n");

    // Initialize V8 platform with proper flags for snapshots
    // CRITICAL: Flags MUST be set BEFORE platform initialization
    try stdout.writeAll("Setting V8 flags for deterministic snapshots...\n");
    v8.ffi.v8_SetFlagsFromString(v8.snapshot_loader.SNAPSHOT_V8_FLAGS);

    try stdout.writeAll("Initializing V8 platform...\n");
    v8.ffi.v8_Platform_Initialize();
    defer v8.ffi.v8_Platform_Dispose();
    try stdout.writeAll("V8 platform initialized.\n\n");

    // Run tests at each level
    var results: [5]TestResult = undefined;
    var all_passed = true;

    inline for (std.meta.fields(TestLevel)) |field| {
        const level: TestLevel = @enumFromInt(field.value);
        results[field.value] = testSnapshotLevel(allocator, level, stdout);
        if (!results[field.value].create_success or !results[field.value].load_success) {
            all_passed = false;
        }
    }

    // Print summary
    try stdout.writeAll("\n=================================================\n");
    try stdout.writeAll("SUMMARY\n");
    try stdout.writeAll("=================================================\n");

    for (results) |r| {
        var buf: [256]u8 = undefined;
        const status = if (r.create_success and r.load_success) "PASS" else "FAIL";
        const formatted = std.fmt.bufPrint(&buf, "{s}: {s} (create={}, load={}, size={})\n", .{
            @tagName(r.level),
            status,
            r.create_success,
            r.load_success,
            r.blob_size,
        }) catch continue;
        try stdout.writeAll(formatted);
        if (r.error_message) |msg| {
            const err_formatted = std.fmt.bufPrint(&buf, "  Error: {s}\n", .{msg}) catch continue;
            try stdout.writeAll(err_formatted);
        }
    }

    try stdout.writeAll("\n");
    if (all_passed) {
        try stdout.writeAll("All tests PASSED!\n");
    } else {
        try stdout.writeAll("Some tests FAILED - see above for details.\n");
    }
}

fn testSnapshotLevel(allocator: std.mem.Allocator, level: TestLevel, stdout: std.fs.File) TestResult {
    var buf: [512]u8 = undefined;

    const header = std.fmt.bufPrint(&buf, "\n--- Testing Level: {s} ---\n", .{@tagName(level)}) catch "";
    stdout.writeAll(header) catch {};

    var result = TestResult{
        .level = level,
        .create_success = false,
        .load_success = false,
        .blob_size = 0,
        .error_message = null,
    };

    // Build external references array based on level
    var refs: [100]isize = [_]isize{0} ** 100;
    var ref_count: usize = 0;

    switch (level) {
        .bare_minimum => {
            // No external references - just null terminator
        },
        .single_callback => {
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback1));
            ref_count += 1;
        },
        .few_callbacks => {
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback1));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback2));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback3));
            ref_count += 1;
        },
        .cpp_callbacks => {
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback1));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback2));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback3));
            ref_count += 1;
            // Add C++ callbacks from v8_wrapper.cpp
            refs[ref_count] = @bitCast(@intFromPtr(v8.ffi.v8_GetAsyncIteratorNextCallback()));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(v8.ffi.v8_GetAsyncIteratorReturnCallback()));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(v8.ffi.v8_GetAsyncIteratorSelfCallback()));
            ref_count += 1;
        },
        .many_callbacks => {
            // Add many callbacks to simulate real interface scenario
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback1));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback2));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback3));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback4));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback5));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback6));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback7));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback8));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback9));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(&dummyCallback10));
            ref_count += 1;
            // Add C++ callbacks
            refs[ref_count] = @bitCast(@intFromPtr(v8.ffi.v8_GetAsyncIteratorNextCallback()));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(v8.ffi.v8_GetAsyncIteratorReturnCallback()));
            ref_count += 1;
            refs[ref_count] = @bitCast(@intFromPtr(v8.ffi.v8_GetAsyncIteratorSelfCallback()));
            ref_count += 1;
        },
    }

    // Null-terminate
    refs[ref_count] = 0;

    const info = std.fmt.bufPrint(&buf, "Using {d} external references\n", .{ref_count}) catch "";
    stdout.writeAll(info) catch {};

    // Step 1: Create snapshot
    stdout.writeAll("Creating snapshot...\n") catch {};

    const create_result = createMinimalSnapshot(&refs, level);
    if (create_result.err) |err| {
        result.error_message = err;
        stdout.writeAll("  FAILED to create snapshot\n") catch {};
        return result;
    }

    result.create_success = true;
    result.blob_size = create_result.size;

    const size_info = std.fmt.bufPrint(&buf, "  Created snapshot: {d} bytes\n", .{create_result.size}) catch "";
    stdout.writeAll(size_info) catch {};

    // Step 2: Load snapshot
    stdout.writeAll("Loading snapshot...\n") catch {};

    const load_result = loadMinimalSnapshot(allocator, create_result.data.?, create_result.size, &refs);
    if (load_result.err) |err| {
        result.error_message = err;
        stdout.writeAll("  FAILED to load snapshot\n") catch {};
        // Free snapshot data
        v8.ffi.v8_Snapshot_FreeData(create_result.data);
        return result;
    }

    result.load_success = true;
    stdout.writeAll("  Successfully loaded snapshot!\n") catch {};

    // Step 3: Try to evaluate JavaScript in loaded context
    stdout.writeAll("Evaluating JS in loaded context...\n") catch {};

    const isolate = load_result.isolate.?;
    const context = load_result.context.?;

    v8.ffi.v8_Context_Enter(context);

    // Simple JS evaluation
    const test_code = "1 + 1";
    const source = v8.ffi.v8_String_NewFromUtf8(isolate, test_code.ptr, @intCast(test_code.len));
    if (source) |src| {
        const script = v8.ffi.v8_Script_Compile(context, src);
        if (script) |s| {
            const eval_result = v8.ffi.v8_Script_Run(context, s);
            if (eval_result) |_| {
                stdout.writeAll("  JS evaluation: OK (1+1 works)\n") catch {};
            } else {
                stdout.writeAll("  JS evaluation: FAILED (run error)\n") catch {};
            }
            v8.ffi.v8_Script_Dispose(s);
        } else {
            stdout.writeAll("  JS evaluation: FAILED (compile error)\n") catch {};
        }
        v8.ffi.v8_String_Dispose(src);
    } else {
        stdout.writeAll("  JS evaluation: FAILED (string creation)\n") catch {};
    }

    // Cleanup
    v8.ffi.v8_Context_Exit(context);
    v8.ffi.v8_Context_Dispose(context);
    v8.ffi.v8_Isolate_Exit(isolate);
    v8.ffi.v8_Isolate_Dispose(isolate);
    v8.ffi.v8_Snapshot_FreeData(create_result.data);

    return result;
}

const CreateResult = struct {
    data: ?[*]const u8,
    size: usize,
    err: ?[]const u8,
};

fn createMinimalSnapshot(refs: [*]const isize, level: TestLevel) CreateResult {
    // Create SnapshotCreator
    const creator = v8.ffi.v8_SnapshotCreator_New(refs) orelse {
        return .{ .data = null, .size = 0, .err = "v8_SnapshotCreator_New failed" };
    };

    // Get isolate
    const isolate = v8.ffi.v8_SnapshotCreator_GetIsolate(creator) orelse {
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return .{ .data = null, .size = 0, .err = "v8_SnapshotCreator_GetIsolate failed" };
    };

    // Enter isolate
    v8.ffi.v8_Isolate_Enter(isolate);

    // Enable snapshot mode
    v8.ffi.v8_Snapshot_EnableMode();

    // Create context
    const context = v8.ffi.v8_Context_New(isolate) orelse {
        v8.ffi.v8_Snapshot_DisableMode();
        v8.ffi.v8_Isolate_Exit(isolate);
        v8.ffi.v8_SnapshotCreator_Dispose(creator);
        return .{ .data = null, .size = 0, .err = "v8_Context_New failed" };
    };

    v8.ffi.v8_Context_Enter(context);

    // For levels that add callbacks, create a simple FunctionTemplate
    if (level != .bare_minimum) {
        // Create a simple function and add it to global
        const callback: v8.ffi.FunctionCallback = &dummyCallback1;
        const func_template = v8.ffi.v8_FunctionTemplate_New(isolate, callback, null);
        if (func_template) |ft| {
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(ft, context);
            if (func) |f| {
                const global = v8.ffi.v8_Context_Global(context);
                if (global) |g| {
                    const name = v8.ffi.v8_String_NewFromUtf8(isolate, "testFunc", 8);
                    if (name) |n| {
                        _ = v8.ffi.v8_Object_Set(g, context, @ptrCast(n), @ptrCast(f));
                        v8.ffi.v8_String_Dispose(n);
                    }
                }
            }
        }
    }

    // Exit context
    v8.ffi.v8_Context_Exit(context);

    // Set default context
    v8.ffi.v8_SnapshotCreator_SetDefaultContext(creator, context);

    // Exit isolate before creating blob
    v8.ffi.v8_Isolate_Exit(isolate);

    // Clear global handles
    v8.ffi.v8_Snapshot_ClearGlobalHandles();

    // Create blob
    var out_data: ?[*]const u8 = null;
    var out_size: c_int = 0;

    const success = v8.ffi.v8_SnapshotCreator_CreateBlob(
        creator,
        @intFromEnum(v8.ffi.FunctionCodeHandling.Keep),
        &out_data,
        &out_size,
    );

    // Dispose creator
    v8.ffi.v8_SnapshotCreator_Dispose(creator);

    // Disable snapshot mode
    v8.ffi.v8_Snapshot_DisableMode();

    if (!success or out_data == null) {
        return .{ .data = null, .size = 0, .err = "v8_SnapshotCreator_CreateBlob failed" };
    }

    return .{ .data = out_data, .size = @intCast(out_size), .err = null };
}

const LoadResult = struct {
    isolate: ?*v8.ffi.Isolate,
    context: ?*v8.ffi.Context,
    err: ?[]const u8,
};

fn loadMinimalSnapshot(allocator: std.mem.Allocator, data: [*]const u8, size: usize, refs: [*]const isize) LoadResult {
    _ = allocator;

    // Validate snapshot
    if (!v8.ffi.v8_Snapshot_IsValid(data, @intCast(size))) {
        return .{ .isolate = null, .context = null, .err = "Snapshot validation failed" };
    }

    // Create isolate from snapshot
    const isolate = v8.ffi.v8_Isolate_NewFromSnapshot(data, @intCast(size), refs) orelse {
        return .{ .isolate = null, .context = null, .err = "v8_Isolate_NewFromSnapshot failed" };
    };

    // Enter isolate
    v8.ffi.v8_Isolate_Enter(isolate);

    // Create a FRESH context for the snapshot-loaded isolate.
    // We use v8_Context_New instead of v8_Context_NewFromSnapshot because:
    // 1. Context::FromSnapshot(0) fails with V8 14.x alignment issues
    // 2. The snapshot benefit is in isolate startup (pre-compiled builtins)
    // 3. A fresh context still benefits from the fast isolate
    const context = v8.ffi.v8_Context_New(isolate) orelse {
        v8.ffi.v8_Isolate_Exit(isolate);
        v8.ffi.v8_Isolate_Dispose(isolate);
        return .{ .isolate = null, .context = null, .err = "v8_Context_New failed" };
    };

    return .{ .isolate = isolate, .context = context, .err = null };
}

/// BSCOPE-10: Test loading all 9 scope-specific contexts from production snapshot
/// with real timing measurements. Validates p95 < 5ms requirement.
pub fn testMultiContextSnapshot(snapshot_path: []const u8) !void {
    const stdout = std.fs.File.stdout();
    var buf: [4096]u8 = undefined;

    stdout.writeAll("\n=== BSCOPE-10: Multi-Context Snapshot Performance Test ===\n") catch {};

    // Read snapshot file
    const snapshot_data = std.fs.cwd().readFileAlloc(
        std.heap.page_allocator,
        snapshot_path,
        100 * 1024 * 1024, // 100MB max
    ) catch |err| {
        const err_msg = std.fmt.bufPrint(&buf, "Failed to read snapshot file '{s}': {}\n", .{ snapshot_path, err }) catch "Error reading snapshot\n";
        std.fs.File.stderr().writeAll(err_msg) catch {};
        return err;
    };
    defer std.heap.page_allocator.free(snapshot_data);

    const size_msg = std.fmt.bufPrint(&buf, "Snapshot size: {} bytes\n", .{snapshot_data.len}) catch "Size unknown\n";
    stdout.writeAll(size_msg) catch {};

    // Create isolate from snapshot using the direct API
    const isolate = v8.ffi.v8_Isolate_NewFromSnapshot(
        snapshot_data.ptr,
        @intCast(snapshot_data.len),
        null, // No external references for this test
    ) orelse {
        std.fs.File.stderr().writeAll("Failed to create isolate from snapshot\n") catch {};
        return error.IsolateCreationFailed;
    };
    defer v8.ffi.v8_Isolate_Dispose(isolate);

    v8.ffi.v8_Isolate_Enter(isolate);
    defer v8.ffi.v8_Isolate_Exit(isolate);

    // Scope names for logging
    const scope_names = [_][]const u8{
        "Window",
        "DedicatedWorkerGlobalScope",
        "SharedWorkerGlobalScope",
        "ServiceWorkerGlobalScope",
        "AudioWorkletGlobalScope",
        "PaintWorkletGlobalScope",
        "AnimationWorkletGlobalScope",
        "LayoutWorkletGlobalScope",
        "SharedStorageWorkletGlobalScope",
    };

    // Timing measurements (in nanoseconds)
    var timings: [9]u64 = undefined;
    var success_count: usize = 0;

    stdout.writeAll("\nLoading contexts from snapshot indices 0-8:\n") catch {};

    for (0..9) |idx| {
        var timer = std.time.Timer.start() catch {
            const timer_err = std.fmt.bufPrint(&buf, "  [{d}] Timer start failed\n", .{idx}) catch "Timer error\n";
            std.fs.File.stderr().writeAll(timer_err) catch {};
            timings[idx] = 0;
            continue;
        };

        const context = v8.ffi.v8_Context_NewFromSnapshotAt(isolate, @intCast(idx));

        const elapsed_ns = timer.read();
        timings[idx] = elapsed_ns;

        if (context) |ctx| {
            success_count += 1;
            const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
            const success_msg = std.fmt.bufPrint(&buf, "  [{d}] {s}: {d:.3}ms OK\n", .{ idx, scope_names[idx], elapsed_ms }) catch "OK\n";
            stdout.writeAll(success_msg) catch {};
            v8.ffi.v8_Context_Dispose(ctx);
        } else {
            const fail_msg = std.fmt.bufPrint(&buf, "  [{d}] {s}: FAILED\n", .{ idx, scope_names[idx] }) catch "FAILED\n";
            std.fs.File.stderr().writeAll(fail_msg) catch {};
        }
    }

    // Calculate statistics
    var sorted_timings: [9]u64 = timings;
    std.mem.sort(u64, &sorted_timings, {}, std.sort.asc(u64));

    const p50_ns = sorted_timings[4]; // median
    const p95_ns = sorted_timings[8]; // 95th percentile (last element for 9 samples)
    const p50_ms = @as(f64, @floatFromInt(p50_ns)) / 1_000_000.0;
    const p95_ms = @as(f64, @floatFromInt(p95_ns)) / 1_000_000.0;

    stdout.writeAll("\n=== Results ===\n") catch {};
    const count_msg = std.fmt.bufPrint(&buf, "Contexts loaded: {d}/9\n", .{success_count}) catch "Count unknown\n";
    stdout.writeAll(count_msg) catch {};
    const p50_msg = std.fmt.bufPrint(&buf, "p50 latency: {d:.3}ms\n", .{p50_ms}) catch "p50 unknown\n";
    stdout.writeAll(p50_msg) catch {};
    const p95_msg = std.fmt.bufPrint(&buf, "p95 latency: {d:.3}ms\n", .{p95_ms}) catch "p95 unknown\n";
    stdout.writeAll(p95_msg) catch {};

    // BSCOPE-10 requirement: p95 < 5ms
    const p95_threshold_ms: f64 = 5.0;
    if (p95_ms < p95_threshold_ms) {
        const pass_msg = std.fmt.bufPrint(&buf, "p95 < {d}ms: PASS\n", .{p95_threshold_ms}) catch "PASS\n";
        stdout.writeAll(pass_msg) catch {};
    } else {
        const fail_msg = std.fmt.bufPrint(&buf, "p95 < {d}ms: FAIL (actual: {d:.3}ms)\n", .{ p95_threshold_ms, p95_ms }) catch "FAIL\n";
        std.fs.File.stderr().writeAll(fail_msg) catch {};
        return error.PerformanceThresholdExceeded;
    }

    if (success_count < 9) {
        std.fs.File.stderr().writeAll("Not all contexts loaded successfully\n") catch {};
        return error.ContextLoadFailed;
    }

    std.fs.File.stdout().writeAll("\nBSCOPE-10: All tests passed!\n") catch {};
}
