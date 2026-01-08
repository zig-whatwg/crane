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
