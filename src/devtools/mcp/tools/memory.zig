//! Memory tools - chrome-devtools-mcp v1.13.0's `src/tools/memory.ts`
//! (Copyright 2025-2026 Google LLC, Apache-2.0; THIRD_PARTY_NOTICES.md):
//! - `take_heapsnapshot` (always enabled; captures V8 heap snapshot over CDP
//!   `HeapProfiler.takeHeapSnapshot` + `addHeapSnapshotChunk`)
//! - Heap snapshot analysis tools gated behind `--memoryDebugging`:
//!   `get_heapsnapshot_summary`, `get_heapsnapshot_details`,
//!   `get_heapsnapshot_class_nodes`, `get_heapsnapshot_object_details`,
//!   `get_heapsnapshot_edges`, `get_heapsnapshot_retainers`,
//!   `get_heapsnapshot_dominators`, `close_heapsnapshot`.

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;
const console_tools = @import("console.zig");
const heap = @import("../heap_snapshot.zig");
const formatter = @import("../heap_formatter.zig");

pub const list = [_]Tool{
    .{
        .name = "take_heapsnapshot",
        .page_tool = true,
        .blocked_by_dialog = true,
        .files = &.{.{ .name = "filePath" }},
        .run = takeHeapSnapshot,
    },
    .{
        .name = "get_heapsnapshot_summary",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = getHeapSnapshotSummary,
    },
    .{
        .name = "get_heapsnapshot_details",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = getHeapSnapshotDetails,
    },
    .{
        .name = "get_heapsnapshot_class_nodes",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = getHeapSnapshotClassNodes,
    },
    .{
        .name = "get_heapsnapshot_object_details",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = getHeapSnapshotObjectDetails,
    },
    .{
        .name = "get_heapsnapshot_edges",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = getHeapSnapshotEdges,
    },
    .{
        .name = "get_heapsnapshot_retainers",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = getHeapSnapshotRetainers,
    },
    .{
        .name = "get_heapsnapshot_dominators",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = getHeapSnapshotDominators,
    },
    .{
        .name = "close_heapsnapshot",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = closeHeapSnapshot,
    },
    .{
        .name = "get_heapsnapshot_retaining_paths",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = getHeapSnapshotRetainingPaths,
    },
    .{
        .name = "get_heapsnapshot_duplicate_strings",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = getHeapSnapshotDuplicateStrings,
    },
    .{
        .name = "query_heapsnapshot_objects",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = queryHeapSnapshotObjects,
    },
    .{
        .name = "compare_heapsnapshots",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{ .{ .name = "baseFilePath" }, .{ .name = "currentFilePath" } },
        .memory_debugging = true,
        .run = compareHeapSnapshots,
    },
    .{
        .name = "analyze_heapsnapshot_contexts",
        .page_tool = false,
        .blocked_by_dialog = false,
        .files = &.{.{ .name = "filePath" }},
        .memory_debugging = true,
        .run = analyzeHeapSnapshotContexts,
    },
};

/// V8 heap snapshot walk timeout (generous for debug / TSan builds).
const heap_snapshot_timeout_ms: u32 = 60_000;

/// DEFAULT_HEAP_SNAPSHOT_PAGE_SIZE in chrome-devtools-mcp src/tools/memory.ts.
const default_page_size: usize = 50;

fn takeHeapSnapshot(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const path = registry.stringArg(args, "filePath") orelse return ctx.fail("The \"path\" argument must be of type string. Received undefined", .{});

    var capture: session_mod.HeapCapture = .{
        .session_id = target.session_id,
        .allocator = ctx.session.allocator,
    };
    defer capture.chunks.deinit(ctx.session.allocator);
    ctx.session.heap_capture = &capture;
    defer ctx.session.heap_capture = null;

    var r = try ctx.session.client.call(
        "HeapProfiler.takeHeapSnapshot",
        "{\"reportProgress\":false,\"treatGlobalObjectsAsRoots\":true,\"captureNumericValue\":false}",
        target.session_id,
        heap_snapshot_timeout_ms,
    );
    defer r.deinit();
    if (r.errorMessage()) |msg| return ctx.fail("{s}", .{msg});
    if (capture.failed) return error.OutOfMemory;

    const saved = ctx.session.paths.saveFile(ctx.arena, capture.chunks.items, path, ".heapsnapshot") catch |err| switch (err) {
        error.Denied => return ctx.fail("{s}", .{ctx.session.paths.message}),
        error.OutOfMemory => return error.OutOfMemory,
    };
    try response.line("Heap snapshot saved to {s}", .{saved});
}

// ---------------------------------------------------------------------------
// Heap snapshot analysis helpers
// ---------------------------------------------------------------------------

fn maxNameLengthArg(args: std.json.ObjectMap) usize {
    const n = registry.numberArg(args, "maxNameLength") orelse return formatter.max_name_length;
    if (n < 1) return 1;
    return @intFromFloat(n);
}

fn heapPageSizeArg(args: std.json.ObjectMap) usize {
    return console_tools.pageSize(args) orelse default_page_size;
}

fn heapPageIdxArg(args: std.json.ObjectMap) i64 {
    return console_tools.pageIdx(args) orelse 0;
}

fn u64Arg(args: std.json.ObjectMap, key: []const u8) ?u64 {
    const n = registry.numberArg(args, key) orelse return null;
    if (n < 0 or !std.math.isFinite(n)) return null;
    return @intFromFloat(n);
}

fn loadSnapshot(ctx: *Context, args: std.json.ObjectMap) anyerror!*heap.HeapSnapshot {
    return loadSnapshotByKey(ctx, args, "filePath");
}

fn loadSnapshotByKey(ctx: *Context, args: std.json.ObjectMap, key: []const u8) anyerror!*heap.HeapSnapshot {
    const file_path = registry.stringArg(args, key) orelse return ctx.fail("{s} is required", .{key});
    return switch (try ctx.session.heap_snapshots.getOrLoad(ctx.session.allocator, &ctx.session.paths, ctx.arena, file_path)) {
        .ok => |snap| snap,
        .err => |msg| ctx.fail("{s}", .{msg}),
    };
}

fn mapQueryError(ctx: *Context, err: anyerror, node_id: ?u64, class_id: ?u64) anyerror {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.NodeNotFound => ctx.fail("Node with ID {d} not found", .{node_id orelse 0}),
        error.ClassNotFound => ctx.fail("Class with ID {d} not found in heap snapshot", .{class_id orelse 0}),
        error.MissingObjectId => ctx.fail("objectId is required when filterName is attributedToSpecificNativeContext", .{}),
        error.InvalidFilterName => ctx.fail("Invalid filter name", .{}),
        error.InvalidRegex => ctx.fail("Invalid regular expression", .{}),
        else => err,
    };
}

// ---------------------------------------------------------------------------
// Tool handlers
// ---------------------------------------------------------------------------

fn getHeapSnapshotSummary(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);

    const stats = snap.getStatistics();
    const static_data = snap.getStaticData();
    const nc_sizes = snap.getNativeContextSizes();
    const retained_summary = snap.getRetainedByContextSummary() catch |err| return mapQueryError(ctx, err, null, null);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("Statistics: {s}", .{try formatter.formatStatisticsJson(ctx.arena, stats)});
    try response.line("Static Data: {s}", .{try formatter.formatStaticDataJson(ctx.arena, static_data)});
    try response.line("### Native Contexts", .{});
    try response.line("{s}", .{try formatter.formatNativeContextSizes(ctx.arena, nc_sizes, max_len)});
    try response.line("### Retained by Context Summary", .{});
    try response.line("{s}", .{try formatter.formatRetainedByContextSummary(ctx.arena, retained_summary)});
}

fn getHeapSnapshotDetails(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);
    const filter_name = registry.stringArg(args, "filterName");
    const object_id = u64Arg(args, "objectId");

    const data = snap.getAggregates(ctx.arena, filter_name, object_id) catch |err| return mapQueryError(ctx, err, object_id, null);

    var pagination_lines: std.ArrayList([]const u8) = .empty;
    const shown = try console_tools.paginate(ctx.arena, data.aggregates.len, heapPageSizeArg(args), heapPageIdxArg(args), &pagination_lines);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("Objects: {d}", .{data.object_count});
    try response.line("Total shallow size: {s}", .{try formatter.formatBytesToKbU64(ctx.arena, data.total_self_size)});
    for (pagination_lines.items) |l| try response.line("{s}", .{l});
    try response.line("{s}", .{try formatter.formatAggregates(ctx.arena, data.aggregates[shown.start..shown.end], max_len)});
}

fn getHeapSnapshotClassNodes(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);
    const raw_id = registry.numberArg(args, "id") orelse return ctx.fail("Class with ID undefined not found in heap snapshot", .{});
    const filter_name = registry.stringArg(args, "filterName");
    const object_id = u64Arg(args, "objectId");

    if (raw_id < 1 or raw_id != @floor(raw_id) or raw_id > std.math.maxInt(u32)) {
        // Check filter error first if attributedToSpecificNativeContext is missing objectId (matches HeapSnapshotManager.getNodesById).
        if (filter_name) |fnm| {
            if (std.mem.eql(u8, fnm, "attributedToSpecificNativeContext") and object_id == null) {
                return ctx.fail("objectId is required when filterName is attributedToSpecificNativeContext", .{});
            }
        }
        return ctx.fail("Class with ID {d} not found in heap snapshot", .{@as(i64, @intFromFloat(raw_id))});
    }
    const class_id: u32 = @intFromFloat(raw_id);
    const nodes = snap.getClassNodes(ctx.arena, class_id, filter_name, object_id) catch |err| return mapQueryError(ctx, err, object_id, class_id);

    var pagination_lines: std.ArrayList([]const u8) = .empty;
    const shown = try console_tools.paginate(ctx.arena, nodes.len, heapPageSizeArg(args), heapPageIdxArg(args), &pagination_lines);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("{s}", .{try formatter.formatNodeItems(ctx.arena, nodes[shown.start..shown.end], max_len)});
    for (pagination_lines.items) |l| try response.line("{s}", .{l});
}

fn getHeapSnapshotObjectDetails(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);
    const raw_id = registry.numberArg(args, "nodeId") orelse return ctx.fail("Node with ID undefined not found", .{});
    if (raw_id < 0 or raw_id != @floor(raw_id)) {
        return ctx.fail("Node with ID {d} not found", .{raw_id});
    }
    const node_id: u64 = @intFromFloat(raw_id);
    const info = snap.getObjectInfo(ctx.arena, node_id) catch |err| return mapQueryError(ctx, err, node_id, null);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("### Object Details", .{});
    try response.line("{s}", .{try formatter.formatObjectInfo(ctx.arena, info, max_len)});
}

fn getHeapSnapshotEdges(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    // Parse zod-transformed byteSizeRange before loading the snapshot (schema validation order).
    var min_retained: ?u64 = null;
    if (registry.stringArg(args, "retainedSize")) |range_str| {
        switch (try formatter.parseByteSizeRange(ctx.arena, range_str)) {
            .ok => |r| min_retained = r.min,
            .err => |msg| return ctx.failPlain("Input validation error: Invalid arguments for tool get_heapsnapshot_edges: retainedSize: {s}", .{msg}),
        }
    }

    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);
    const raw_id = registry.numberArg(args, "nodeId") orelse return ctx.fail("Node with ID undefined not found", .{});
    if (raw_id < 0 or raw_id != @floor(raw_id)) {
        return ctx.fail("Node with ID {d} not found", .{raw_id});
    }
    const node_id: u64 = @intFromFloat(raw_id);

    const sort_by: heap.EdgeSortBy = if (registry.stringArg(args, "sortBy")) |sb| blk: {
        if (std.mem.eql(u8, sb, "selfSize")) break :blk .self_size;
        if (std.mem.eql(u8, sb, "name")) break :blk .name;
        break :blk .retained_size;
    } else .retained_size;
    const exclude_primitives = registry.boolArg(args, "excludePrimitives") orelse true;

    const edges = snap.getEdges(ctx.arena, node_id, .{
        .sort_by = sort_by,
        .min_retained_size = min_retained,
        .exclude_primitives = exclude_primitives,
    }) catch |err| return mapQueryError(ctx, err, node_id, null);

    var pagination_lines: std.ArrayList([]const u8) = .empty;
    const shown = try console_tools.paginate(ctx.arena, edges.len, heapPageSizeArg(args), heapPageIdxArg(args), &pagination_lines);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("{s}", .{try formatter.formatEdgeItems(ctx.arena, edges[shown.start..shown.end], max_len)});
    for (pagination_lines.items) |l| try response.line("{s}", .{l});
}

fn getHeapSnapshotRetainers(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);
    const raw_id = registry.numberArg(args, "nodeId") orelse return ctx.fail("Node with ID undefined not found", .{});
    if (raw_id < 0 or raw_id != @floor(raw_id)) {
        return ctx.fail("Node with ID {d} not found", .{raw_id});
    }
    const node_id: u64 = @intFromFloat(raw_id);
    const retainers = snap.getRetainers(ctx.arena, node_id) catch |err| return mapQueryError(ctx, err, node_id, null);

    var pagination_lines: std.ArrayList([]const u8) = .empty;
    const shown = try console_tools.paginate(ctx.arena, retainers.len, heapPageSizeArg(args), heapPageIdxArg(args), &pagination_lines);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("{s}", .{try formatter.formatEdgeItems(ctx.arena, retainers[shown.start..shown.end], max_len)});
    for (pagination_lines.items) |l| try response.line("{s}", .{l});
}

fn getHeapSnapshotDominators(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);
    const raw_id = registry.numberArg(args, "nodeId") orelse return ctx.fail("Node with ID undefined not found", .{});
    if (raw_id < 0 or raw_id != @floor(raw_id)) {
        return ctx.fail("Node with ID {d} not found", .{raw_id});
    }
    const node_id: u64 = @intFromFloat(raw_id);
    const dominators = snap.getDominatorsOf(ctx.arena, node_id) catch |err| return mapQueryError(ctx, err, node_id, null);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("### Dominator Chain", .{});
    if (dominators.len == 0) {
        try response.line("No dominators found.", .{});
    } else {
        try response.line("{s}", .{try formatter.formatDominators(ctx.arena, dominators, max_len)});
    }
}

fn closeHeapSnapshot(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    const file_path = registry.stringArg(args, "filePath") orelse return ctx.fail("Failed to close heap snapshot: undefined was not loaded.", .{});
    if (!ctx.session.heap_snapshots.close(ctx.session.allocator, file_path)) {
        return ctx.fail("Failed to close heap snapshot: {s} was not loaded.", .{file_path});
    }
    try response.line("Closed heap snapshot: {s}", .{file_path});
}

fn usizeArg(args: std.json.ObjectMap, key: []const u8) ?usize {
    const n = registry.numberArg(args, key) orelse return null;
    if (n < 0 or !std.math.isFinite(n)) return null;
    return @intFromFloat(n);
}

fn getHeapSnapshotRetainingPaths(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);
    const raw_id = registry.numberArg(args, "nodeId") orelse return ctx.fail("Node with ID undefined not found", .{});
    if (raw_id < 0 or raw_id != @floor(raw_id)) {
        return ctx.fail("Node with ID {d} not found", .{raw_id});
    }
    const node_id: u64 = @intFromFloat(raw_id);
    const result = snap.getRetainingPaths(
        ctx.arena,
        node_id,
        usizeArg(args, "maxDepth"),
        usizeArg(args, "maxNodes"),
        usizeArg(args, "maxSiblings"),
    ) catch |err| return mapQueryError(ctx, err, node_id, null);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("### Retaining Paths", .{});
    if (result.paths.len == 0) {
        try response.line("No retaining paths found.", .{});
    } else {
        try response.line("{s}", .{try formatter.formatRetainingPaths(ctx.arena, result.paths, max_len)});
    }
    if (result.limits_reached.len > 0) {
        var names: std.ArrayList([]const u8) = .empty;
        for (result.limits_reached) |lim| try names.append(ctx.arena, lim.name());
        try response.line("Note: results are truncated, the following limits were reached: {s}.", .{try std.mem.join(ctx.arena, ", ", names.items)});
    }
}

fn getHeapSnapshotDuplicateStrings(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);
    const groups = snap.getDuplicateStrings(ctx.arena) catch |err| return mapQueryError(ctx, err, null, null);

    var pagination_lines: std.ArrayList([]const u8) = .empty;
    const shown = try console_tools.paginate(ctx.arena, groups.len, heapPageSizeArg(args), heapPageIdxArg(args), &pagination_lines);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("### Duplicate Strings", .{});
    for (pagination_lines.items) |l| try response.line("{s}", .{l});
    try response.line("{s}", .{try formatter.formatDuplicateStrings(ctx.arena, groups[shown.start..shown.end], max_len)});
}

fn queryHeapSnapshotObjects(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    var ret_range: ?formatter.ByteSizeRange = null;
    if (registry.stringArg(args, "retainedSize")) |s| {
        switch (try formatter.parseByteSizeRange(ctx.arena, s)) {
            .ok => |r| ret_range = r,
            .err => |msg| return ctx.failPlain("Input validation error: Invalid arguments for tool query_heapsnapshot_objects: retainedSize: {s}", .{msg}),
        }
    }
    var self_range: ?formatter.ByteSizeRange = null;
    if (registry.stringArg(args, "selfSize")) |s| {
        switch (try formatter.parseByteSizeRange(ctx.arena, s)) {
            .ok => |r| self_range = r,
            .err => |msg| return ctx.failPlain("Input validation error: Invalid arguments for tool query_heapsnapshot_objects: selfSize: {s}", .{msg}),
        }
    }

    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);
    const sort_by: heap.ObjectQuerySortBy = if (registry.stringArg(args, "sortBy")) |sb| blk: {
        if (std.mem.eql(u8, sb, "selfSize")) break :blk .self_size;
        if (std.mem.eql(u8, sb, "id")) break :blk .id;
        break :blk .retained_size;
    } else .retained_size;

    const nodes = snap.queryObjects(ctx.arena, .{
        .class_name = registry.stringArg(args, "className"),
        .property_name = registry.stringArg(args, "propertyName"),
        .node_type = registry.stringArg(args, "nodeType"),
        .min_retained_size = if (ret_range) |r| r.min else null,
        .max_retained_size = if (ret_range) |r| r.max else null,
        .min_self_size = if (self_range) |r| r.min else null,
        .max_self_size = if (self_range) |r| r.max else null,
        .is_detached = registry.boolArg(args, "isDetached"),
        .sort_by = sort_by,
    }) catch |err| return mapQueryError(ctx, err, null, null);

    // McpResponse.ts:1419 stably re-sorts NodeLike items descending by retainedSize.
    std.sort.block(heap.NodeItem, nodes, {}, struct {
        fn lessThan(_: void, a: heap.NodeItem, b: heap.NodeItem) bool {
            return a.retained_size > b.retained_size;
        }
    }.lessThan);

    var pagination_lines: std.ArrayList([]const u8) = .empty;
    const shown = try console_tools.paginate(ctx.arena, nodes.len, heapPageSizeArg(args), heapPageIdxArg(args), &pagination_lines);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("{s}", .{try formatter.formatNodeItems(ctx.arena, nodes[shown.start..shown.end], max_len)});
    for (pagination_lines.items) |l| try response.line("{s}", .{l});
}

fn compareHeapSnapshots(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    const base_snap = try loadSnapshotByKey(ctx, args, "baseFilePath");
    const cur_snap = try loadSnapshotByKey(ctx, args, "currentFilePath");
    const max_len = maxNameLengthArg(args);

    if (registry.numberArg(args, "classIndex")) |raw_idx| {
        const idx: i64 = if (raw_idx == @floor(raw_idx) and std.math.isFinite(raw_idx)) @intFromFloat(raw_idx) else -1;
        switch (try heap.HeapSnapshot.getDetailedClassDiff(ctx.arena, base_snap, cur_snap, idx)) {
            .out_of_range => |total_changed| {
                if (raw_idx == @floor(raw_idx) and std.math.isFinite(raw_idx)) {
                    return ctx.fail("Invalid classIndex: {d}. Total classes with changes: {d}", .{ idx, total_changed });
                }
                return ctx.fail("Invalid classIndex: {d}. Total classes with changes: {d}", .{ raw_idx, total_changed });
            },
            .ok => |detailed| {
                var pagination_lines: std.ArrayList([]const u8) = .empty;
                const shown = try console_tools.paginate(ctx.arena, detailed.objects.len, heapPageSizeArg(args), heapPageIdxArg(args), &pagination_lines);

                try response.line("## Heap Snapshot Data", .{});
                try response.line("### Heap Snapshot Detailed Diff", .{});
                try response.line("{s}", .{try formatter.formatDetailedClassDiffHeader(ctx.arena, detailed.class_diff, max_len)});
                for (pagination_lines.items) |l| try response.line("{s}", .{l});
                try response.line("{s}", .{try formatter.formatDetailedClassDiffObjects(ctx.arena, detailed.objects[shown.start..shown.end])});
            },
        }
        return;
    }

    const diff = try heap.HeapSnapshot.compareSnapshots(ctx.arena, base_snap, cur_snap);
    var pagination_lines: std.ArrayList([]const u8) = .empty;
    const shown = try console_tools.paginate(ctx.arena, diff.class_diffs.len, heapPageSizeArg(args), heapPageIdxArg(args), &pagination_lines);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("### Heap Snapshot Diff", .{});
    try response.line("{s}", .{try formatter.formatDiffTotals(ctx.arena, diff.totals)});
    for (pagination_lines.items) |l| try response.line("{s}", .{l});
    try response.line("{s}", .{try formatter.formatDiffSummary(ctx.arena, diff.class_diffs[shown.start..shown.end], max_len)});
}

fn analyzeHeapSnapshotContexts(ctx: *Context, args: std.json.ObjectMap, _: ?*Page, response: *Response) anyerror!void {
    var ret_range: ?formatter.ByteSizeRange = null;
    if (registry.stringArg(args, "retainedSize")) |s| {
        switch (try formatter.parseByteSizeRange(ctx.arena, s)) {
            .ok => |r| ret_range = r,
            .err => |msg| return ctx.failPlain("Input validation error: Invalid arguments for tool analyze_heapsnapshot_contexts: retainedSize: {s}", .{msg}),
        }
    }

    const snap = try loadSnapshot(ctx, args);
    const max_len = maxNameLengthArg(args);
    const analysis = try snap.analyzeContexts(ctx.arena);
    const ranked = try formatter.collectRankedContexts(ctx.arena, analysis, ret_range, u64Arg(args, "scopeInfoNodeId"));

    var pagination_lines: std.ArrayList([]const u8) = .empty;
    const shown = try console_tools.paginate(ctx.arena, ranked.len, heapPageSizeArg(args), heapPageIdxArg(args), &pagination_lines);

    try response.line("## Heap Snapshot Data", .{});
    try response.line("### Context Analysis", .{});
    for (pagination_lines.items) |l| try response.line("{s}", .{l});
    try response.line("{s}", .{try formatter.formatContextAnalysis(ctx.arena, ranked[shown.start..shown.end], analysis.scripts_without_scopes, max_len)});
}
