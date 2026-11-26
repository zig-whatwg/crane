//! Formatting and byte-size parsing for MCP heap snapshot analysis tools.
//!
//! Translated from:
//! - chrome-devtools-mcp v1.13.0 `src/formatters/HeapSnapshotFormatter.ts` and
//!   `src/utils/bytes.ts` (Copyright 2026 Google LLC, Apache-2.0)
//! - Chromium DevTools Frontend `front_end/core/i18n/ByteUtilities.ts` and
//!   `front_end/core/i18n/NumberFormatter.ts` (Copyright The Chromium Authors,
//!   BSD-3-Clause)
//! See THIRD_PARTY_NOTICES.md.

const std = @import("std");
const Allocator = std.mem.Allocator;
const text_util = @import("text.zig");
const heap = @import("heap_snapshot.zig");

/// Default maximum length of node/class/edge names before truncation.
pub const max_name_length: usize = 100;

/// Non-breaking space (U+00A0) used by DevTools NumberFormatter.formatAndEnsureSpace
/// between the numeric value and the "kB" unit.
const nbsp = "\xc2\xa0";

pub const ByteSizeRange = struct {
    min: u64,
    max: ?u64 = null,
};

pub const ParseSizeResult = union(enum) {
    ok: u64,
    err: []const u8,
};

pub const ParseRangeResult = union(enum) {
    ok: ByteSizeRange,
    err: []const u8,
};

const ByteUnit = struct {
    name: []const u8,
    multiplier: f64,
};

const byte_units = [_]ByteUnit{
    .{ .name = "b", .multiplier = 1 },
    .{ .name = "byte", .multiplier = 1 },
    .{ .name = "bytes", .multiplier = 1 },
    .{ .name = "k", .multiplier = 1_000 },
    .{ .name = "kb", .multiplier = 1_000 },
    .{ .name = "kib", .multiplier = 1024 },
    .{ .name = "m", .multiplier = 1_000_000 },
    .{ .name = "mb", .multiplier = 1_000_000 },
    .{ .name = "mib", .multiplier = 1024 * 1024 },
    .{ .name = "g", .multiplier = 1_000_000_000 },
    .{ .name = "gb", .multiplier = 1_000_000_000 },
    .{ .name = "gib", .multiplier = 1024 * 1024 * 1024 },
    .{ .name = "t", .multiplier = 1_000_000_000_000 },
    .{ .name = "tb", .multiplier = 1_000_000_000_000 },
    .{ .name = "tib", .multiplier = 1024.0 * 1024.0 * 1024.0 * 1024.0 },
};

fn trimAsciiSpace(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n\x0b\x0c");
}

fn lookupUnit(unit: []const u8) ?f64 {
    for (byte_units) |entry| {
        if (std.ascii.eqlIgnoreCase(entry.name, unit)) return entry.multiplier;
    }
    return null;
}

/// Parses a byte size string (e.g. "1M", "1MB", "500KB", "1.5GB", "1024") into bytes.
/// Matches chrome-devtools-mcp `src/utils/bytes.ts` `parseByteSize`.
pub fn parseByteSize(arena: Allocator, value: []const u8) Allocator.Error!ParseSizeResult {
    const trimmed = trimAsciiSpace(value);
    if (trimmed.len == 0) {
        return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size: \"{s}\"", .{value}) };
    }
    // Match /^(\d+(?:\.\d+)?)\s*([a-zA-Z]+)?$/
    var i: usize = 0;
    const num_start = i;
    while (i < trimmed.len and std.ascii.isDigit(trimmed[i])) : (i += 1) {}
    if (i == num_start) {
        return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size format: \"{s}\". Expected a number or format like \"1024\", \"1M\", \"1MB\", \"1G\", \"1GB\".", .{value}) };
    }
    if (i < trimmed.len and trimmed[i] == '.') {
        i += 1;
        const frac_start = i;
        while (i < trimmed.len and std.ascii.isDigit(trimmed[i])) : (i += 1) {}
        if (i == frac_start) {
            return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size format: \"{s}\". Expected a number or format like \"1024\", \"1M\", \"1MB\", \"1G\", \"1GB\".", .{value}) };
        }
    }
    const num_str = trimmed[num_start..i];
    while (i < trimmed.len and std.ascii.isWhitespace(trimmed[i])) : (i += 1) {}
    const unit_start = i;
    while (i < trimmed.len and std.ascii.isAlphabetic(trimmed[i])) : (i += 1) {}
    if (i != trimmed.len) {
        return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size format: \"{s}\". Expected a number or format like \"1024\", \"1M\", \"1MB\", \"1G\", \"1GB\".", .{value}) };
    }
    const unit_str = trimmed[unit_start..i];

    const num = std.fmt.parseFloat(f64, num_str) catch {
        return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size: \"{s}\"", .{value}) };
    };
    if (!std.math.isFinite(num) or num < 0) {
        return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size: \"{s}\"", .{value}) };
    }
    if (unit_str.len == 0) {
        const rounded = @floor(num + 0.5);
        if (!std.math.isFinite(rounded) or rounded > @as(f64, @floatFromInt(std.math.maxInt(u64)))) {
            return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size: \"{s}\"", .{value}) };
        }
        return .{ .ok = @intFromFloat(rounded) };
    }
    const mult = lookupUnit(unit_str) orelse {
        return .{ .err = try std.fmt.allocPrint(arena, "Unknown unit \"{s}\" in \"{s}\". Supported units: B, KB, KiB, MB, MiB, GB, GiB, TB, TiB.", .{ unit_str, value }) };
    };
    const bytes = @floor(num * mult + 0.5);
    if (!std.math.isFinite(bytes) or bytes > @as(f64, @floatFromInt(std.math.maxInt(u64)))) {
        return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size: \"{s}\"", .{value}) };
    }
    return .{ .ok = @intFromFloat(bytes) };
}

/// Parses an inclusive byte-size range (e.g. "1MB", "1MB-2MB", "-1MB", "1MB-").
/// Matches chrome-devtools-mcp `src/utils/bytes.ts` `parseByteSizeRange`.
pub fn parseByteSizeRange(arena: Allocator, value: []const u8) Allocator.Error!ParseRangeResult {
    const trimmed = trimAsciiSpace(value);
    const dash = std.mem.indexOfScalar(u8, trimmed, '-');
    if (dash == null) {
        return switch (try parseByteSize(arena, trimmed)) {
            .ok => |n| .{ .ok = .{ .min = n, .max = null } },
            .err => |msg| .{ .err = msg },
        };
    }
    const dash_idx = dash.?;
    if (std.mem.indexOfScalarPos(u8, trimmed, dash_idx + 1, '-') != null) {
        return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size range: \"{s}\". Expected a size or range like \"1MB\", \"1MB-2MB\", \"-1MB\", or \"1MB-\".", .{value}) };
    }
    const min_text = trimAsciiSpace(trimmed[0..dash_idx]);
    const max_text = trimAsciiSpace(trimmed[dash_idx + 1 ..]);
    if (min_text.len == 0 and max_text.len == 0) {
        return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size range: \"{s}\". At least one bound is required.", .{value}) };
    }
    const min: u64 = if (min_text.len == 0) 0 else switch (try parseByteSize(arena, min_text)) {
        .ok => |n| n,
        .err => |msg| return .{ .err = msg },
    };
    const max: ?u64 = if (max_text.len == 0) null else switch (try parseByteSize(arena, max_text)) {
        .ok => |n| n,
        .err => |msg| return .{ .err = msg },
    };
    if (max) |m| {
        if (min > m) {
            return .{ .err = try std.fmt.allocPrint(arena, "Invalid byte size range: \"{s}\". The lower bound must not exceed the upper bound.", .{value}) };
        }
    }
    return .{ .ok = .{ .min = min, .max = max } };
}

/// Formats a byte count into kilobytes matching DevTools
/// `ByteUtilities.formatBytesToKb` (en-US narrow kilobyte unit with U+00A0
/// separator): base-1000, 1 decimal digit when `kilobytes < 100`, else
/// rounded integer with US comma thousands separators.
pub fn formatBytesToKb(arena: Allocator, bytes: i64) Allocator.Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    const negative = bytes < 0;
    const abs_bytes: u64 = if (negative) @intCast(-@as(i128, bytes)) else @intCast(bytes);
    if (negative or abs_bytes < 100_000) {
        // kilobytes < 100: 1 decimal digit, halfExpand rounding.
        const tenths = (abs_bytes + 50) / 100;
        const whole = tenths / 10;
        const frac = tenths % 10;
        if (negative) try out.append(arena, '-');
        try appendGroupedU64(arena, &out, whole);
        try out.append(arena, '.');
        try out.append(arena, @intCast('0' + frac));
        try out.appendSlice(arena, nbsp);
        try out.appendSlice(arena, "kB");
        return out.items;
    }
    // kilobytes >= 100: integer rounded, halfExpand rounding.
    const whole = (abs_bytes + 500) / 1000;
    try appendGroupedU64(arena, &out, whole);
    try out.appendSlice(arena, nbsp);
    try out.appendSlice(arena, "kB");
    return out.items;
}

pub fn formatBytesToKbU64(arena: Allocator, bytes: u64) Allocator.Error![]const u8 {
    if (bytes <= std.math.maxInt(i64)) {
        return formatBytesToKb(arena, @intCast(bytes));
    }
    var out: std.ArrayList(u8) = .empty;
    const whole = (bytes + 500) / 1000;
    try appendGroupedU64(arena, &out, whole);
    try out.appendSlice(arena, nbsp);
    try out.appendSlice(arena, "kB");
    return out.items;
}

fn appendGroupedU64(arena: Allocator, out: *std.ArrayList(u8), value: u64) Allocator.Error!void {
    var buf: [32]u8 = undefined;
    const digits = std.fmt.bufPrint(&buf, "{d}", .{value}) catch unreachable;
    for (digits, 0..) |ch, idx| {
        if (idx > 0 and (digits.len - idx) % 3 == 0) {
            try out.append(arena, ',');
        }
        try out.append(arena, ch);
    }
}

/// Renders a name for single-line output: truncated to `max_len` UTF-16 code
/// units (appending "..." when cut) and with CR/LF escaped.
pub fn formatName(arena: Allocator, name: []const u8, max_len: usize) Allocator.Error![]const u8 {
    const truncated = try text_util.truncateText(arena, name, max_len, .{});
    if (std.mem.indexOfAny(u8, truncated, "\r\n") == null) return truncated;
    var out: std.ArrayList(u8) = .empty;
    try out.ensureTotalCapacity(arena, truncated.len + 8);
    for (truncated) |c| {
        switch (c) {
            '\r' => try out.appendSlice(arena, "\\r"),
            '\n' => try out.appendSlice(arena, "\\n"),
            else => try out.append(arena, c),
        }
    }
    return out.items;
}

/// Formats `Statistics` exactly like `JSON.stringify(stats, null, 2)`.
pub fn formatStatisticsJson(arena: Allocator, stats: heap.Statistics) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        arena,
        "{{\n" ++
            "  \"total\": {d},\n" ++
            "  \"native\": {{\n" ++
            "    \"total\": {d},\n" ++
            "    \"typedArrays\": {d}\n" ++
            "  }},\n" ++
            "  \"v8heap\": {{\n" ++
            "    \"total\": {d},\n" ++
            "    \"code\": {d},\n" ++
            "    \"jsArrays\": {d},\n" ++
            "    \"strings\": {d},\n" ++
            "    \"system\": {d}\n" ++
            "  }}\n" ++
            "}}",
        .{
            stats.total,
            stats.native.total,
            stats.native.typed_arrays,
            stats.v8heap.total,
            stats.v8heap.code,
            stats.v8heap.js_arrays,
            stats.v8heap.strings,
            stats.v8heap.system,
        },
    );
}

/// Formats `StaticData` exactly like `JSON.stringify(staticData, null, 2)`.
pub fn formatStaticDataJson(arena: Allocator, data: heap.StaticData) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        arena,
        "{{\n" ++
            "  \"nodeCount\": {d},\n" ++
            "  \"rootNodeIndex\": {d},\n" ++
            "  \"totalSize\": {d},\n" ++
            "  \"maxJSObjectId\": {d}\n" ++
            "}}",
        .{
            data.node_count,
            data.root_node_index,
            data.total_size,
            data.max_js_object_id,
        },
    );
}

pub fn formatNativeContextSizes(arena: Allocator, sizes: heap.NativeContextSizes, max_len: usize) Allocator.Error![]const u8 {
    const sorted = try arena.dupe(heap.NativeContextInfo, sizes.native_contexts);
    std.sort.block(heap.NativeContextInfo, sorted, {}, struct {
        fn lessThan(_: void, a: heap.NativeContextInfo, b: heap.NativeContextInfo) bool {
            return a.attributed_size > b.attributed_size;
        }
    }.lessThan);

    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, "nodeId,nodeName,selfSize,retainedSize,attributedSize");
    for (sorted) |nc| {
        try lines.append(arena, try std.fmt.allocPrint(arena, "{d},{s},{s},{s},{s}", .{
            nc.node_id,
            try formatName(arena, nc.node_name, max_len),
            try formatBytesToKbU64(arena, nc.self_size),
            try formatBytesToKbU64(arena, nc.retained_size),
            try formatBytesToKbU64(arena, nc.attributed_size),
        }));
    }
    try lines.append(arena, try std.fmt.allocPrint(arena, "Shared Size: {s}", .{try formatBytesToKbU64(arena, sizes.shared_size)}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "Unattributed Size: {s}", .{try formatBytesToKbU64(arena, sizes.no_attribution_size)}));
    return std.mem.join(arena, "\n", lines.items);
}

pub fn formatRetainedByContextSummary(arena: Allocator, summary: heap.RetainedByContextSummary) Allocator.Error![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, try std.fmt.allocPrint(arena, "Context count: {d}", .{summary.context_count}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "Retained by context size: {s} ({d} objects)", .{
        try formatBytesToKbU64(arena, summary.retained_by_context_size),
        summary.retained_by_context_count,
    }));
    try lines.append(arena, try std.fmt.allocPrint(arena, "Not retained by context size: {s} ({d} objects)", .{
        try formatBytesToKbU64(arena, summary.not_retained_by_context_size),
        summary.not_retained_by_context_count,
    }));
    try lines.append(arena, try std.fmt.allocPrint(arena, "Total size: {s}", .{try formatBytesToKbU64(arena, summary.total_size)}));
    return std.mem.join(arena, "\n", lines.items);
}

pub fn formatAggregates(arena: Allocator, aggregates: []const heap.AggregateInfo, max_len: usize) Allocator.Error![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, "id,className,count,selfSize,retainedSize");
    for (aggregates) |info| {
        try lines.append(arena, try std.fmt.allocPrint(arena, "{d},{s},{d},{s},{s}", .{
            info.id,
            try formatName(arena, info.class_name, max_len),
            info.count,
            try formatBytesToKbU64(arena, info.self_size),
            try formatBytesToKbU64(arena, info.retained_size),
        }));
    }
    return std.mem.join(arena, "\n", lines.items);
}

pub fn formatNodeItems(arena: Allocator, items: []const heap.NodeItem, max_len: usize) Allocator.Error![]const u8 {
    if (items.len == 0) return "";
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, "nodeId,nodeName,type,distance,selfSize,retainedSize");
    for (items) |item| {
        try lines.append(arena, try std.fmt.allocPrint(arena, "{d},{s},{s},{d},{s},{s}", .{
            item.id,
            try formatName(arena, item.name, max_len),
            item.type_name,
            item.distance,
            try formatBytesToKbU64(arena, item.self_size),
            try formatBytesToKbU64(arena, item.retained_size),
        }));
    }
    return std.mem.join(arena, "\n", lines.items);
}

pub fn formatEdgeItems(arena: Allocator, items: []const heap.EdgeItem, max_len: usize) Allocator.Error![]const u8 {
    if (items.len == 0) return "";
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, "name,type,nodeId,nodeName,selfSize,retainedSize");
    for (items) |item| {
        try lines.append(arena, try std.fmt.allocPrint(arena, "{s},{s},{d},{s},{s},{s}", .{
            try formatName(arena, item.name, max_len),
            item.type_name,
            item.node.id,
            try formatName(arena, item.node.name, max_len),
            try formatBytesToKbU64(arena, item.node.self_size),
            try formatBytesToKbU64(arena, item.node.retained_size),
        }));
    }
    return std.mem.join(arena, "\n", lines.items);
}

pub fn formatObjectInfo(arena: Allocator, info: heap.ObjectInfo, max_len: usize) Allocator.Error![]const u8 {
    const detachedness = switch (info.detachedness) {
        .attached => "attached",
        .detached => "detached",
        .unknown => "unknown",
    };
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, try std.fmt.allocPrint(arena, "id: @{d}", .{info.id}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "name: {s}", .{try formatName(arena, info.name, max_len)}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "type: {s}", .{info.type_name}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "detachedness: {s}", .{detachedness}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "selfSize: {s}", .{try formatBytesToKbU64(arena, info.self_size)}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "retainedSize: {s}", .{try formatBytesToKbU64(arena, info.retained_size)}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "distance: {d}", .{info.distance}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "edgeCount: {d}", .{info.edge_count}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "retainerCount: {d}", .{info.retainer_count}));
    return std.mem.join(arena, "\n", lines.items);
}

pub fn formatDominators(arena: Allocator, dominators: []const heap.DominatorItem, max_len: usize) Allocator.Error![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, "nodeId,nodeName,selfSize,retainedSize");
    for (dominators) |node| {
        try lines.append(arena, try std.fmt.allocPrint(arena, "{d},{s},{s},{s}", .{
            node.node_id,
            try formatName(arena, node.node_name, max_len),
            try formatBytesToKbU64(arena, node.self_size),
            try formatBytesToKbU64(arena, node.retained_size),
        }));
    }
    return std.mem.join(arena, "\n", lines.items);
}

pub fn formatRetainingPaths(arena: Allocator, paths: []const heap.RetainingPathNode, max_len: usize) Allocator.Error![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    const Helper = struct {
        fn appendNode(ar: Allocator, out: *std.ArrayList([]const u8), edge: heap.RetainingPathNode, depth: usize, max_l: usize) Allocator.Error!void {
            const indent = try ar.alloc(u8, depth * 2);
            @memset(indent, ' ');
            try out.append(ar, try std.fmt.allocPrint(ar, "{s}<- @{d} {s} via {s} {s} (distance: {d})", .{
                indent,
                edge.node_id,
                try formatName(ar, edge.node_name, max_l),
                edge.edge_type,
                try formatName(ar, edge.edge_name, max_l),
                edge.distance,
            }));
            for (edge.children) |child| {
                try appendNode(ar, out, child, depth + 1, max_l);
            }
        }
    };
    for (paths) |p| {
        try Helper.appendNode(arena, &lines, p, 0, max_len);
    }
    return std.mem.join(arena, "\n", lines.items);
}

pub fn formatDuplicateStrings(arena: Allocator, groups: []const heap.DuplicateStringGroup, max_len: usize) Allocator.Error![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, "value,count,totalSelfSize,totalRetainedSize,truncated,nodeIds");
    for (groups) |group| {
        const display_val = try text_util.truncateText(arena, group.value, max_len, .{});
        var json_val: std.Io.Writer.Allocating = .init(arena);
        std.json.Stringify.encodeJsonString(display_val, .{}, &json_val.writer) catch return error.OutOfMemory;

        var ids_buf: std.ArrayList(u8) = .empty;
        for (group.nodes, 0..) |n, idx| {
            if (idx > 0) try ids_buf.append(arena, ' ');
            try ids_buf.print(arena, "@{d}", .{n.id});
        }
        try lines.append(arena, try std.fmt.allocPrint(arena, "{s},{d},{s},{s},{s},{s}", .{
            json_val.written(),
            group.count,
            try formatBytesToKbU64(arena, group.total_self_size),
            try formatBytesToKbU64(arena, group.total_retained_size),
            if (group.truncated) "true" else "false",
            ids_buf.items,
        }));
    }
    return std.mem.join(arena, "\n", lines.items);
}

fn formatSignedCount(arena: Allocator, n: i64) Allocator.Error![]const u8 {
    return if (n > 0) std.fmt.allocPrint(arena, "+{d}", .{n}) else std.fmt.allocPrint(arena, "{d}", .{n});
}

fn formatSignedSize(arena: Allocator, bytes: i64) Allocator.Error![]const u8 {
    const formatted = try formatBytesToKb(arena, bytes);
    return if (bytes > 0) std.fmt.allocPrint(arena, "+{s}", .{formatted}) else formatted;
}

fn formatSignedSizeU64(arena: Allocator, bytes: u64) Allocator.Error![]const u8 {
    const formatted = try formatBytesToKbU64(arena, bytes);
    return if (bytes > 0) std.fmt.allocPrint(arena, "+{s}", .{formatted}) else formatted;
}

fn formatDiffCounts(arena: Allocator, added_count: u64, removed_count: u64, count_delta: i64, added_size: u64, removed_size: u64, size_delta: i64) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(arena, "# new: {d}, # deleted: {d}, # delta: {s}, alloc size: {s}, freed size: {s}, size delta: {s}", .{
        added_count,
        removed_count,
        try formatSignedCount(arena, count_delta),
        try formatSignedSizeU64(arena, added_size),
        try formatSignedSizeU64(arena, removed_size),
        try formatSignedSize(arena, size_delta),
    });
}

pub fn formatDiffTotals(arena: Allocator, totals: heap.DiffTotals) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(arena, "Total: {s}", .{
        try formatDiffCounts(arena, totals.added_count, totals.removed_count, totals.count_delta, totals.added_size, totals.removed_size, totals.size_delta),
    });
}

pub fn formatDiffSummary(arena: Allocator, diffs: []const heap.ClassDiff, max_len: usize) Allocator.Error![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, "index,className,addedCount,removedCount,countDelta,addedSize,removedSize,sizeDelta");
    for (diffs) |diff| {
        try lines.append(arena, try std.fmt.allocPrint(arena, "{d},{s},{d},{d},{d},{s},{s},{s}", .{
            diff.index,
            try formatName(arena, diff.class_name, max_len),
            diff.added_count,
            diff.removed_count,
            diff.count_delta,
            try formatBytesToKbU64(arena, diff.added_size),
            try formatBytesToKbU64(arena, diff.removed_size),
            try formatBytesToKb(arena, diff.size_delta),
        }));
    }
    return std.mem.join(arena, "\n", lines.items);
}

pub fn formatDetailedClassDiffHeader(arena: Allocator, diff: heap.ClassDiff, max_len: usize) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(arena, "{s}: {s}", .{
        try formatName(arena, diff.class_name, max_len),
        try formatDiffCounts(arena, diff.added_count, diff.removed_count, diff.count_delta, diff.added_size, diff.removed_size, diff.size_delta),
    });
}

pub fn formatDetailedClassDiffObjects(arena: Allocator, objects: []const heap.DiffObject) Allocator.Error![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, "Objects:");
    for (objects) |obj| {
        const sign: []const u8 = if (obj.change == .added) "+" else "-";
        try lines.append(arena, try std.fmt.allocPrint(arena, "  {s} @{d} (self_size: {s})", .{
            sign,
            obj.id,
            try formatBytesToKbU64(arena, obj.self_size),
        }));
    }
    return std.mem.join(arena, "\n", lines.items);
}

pub const RankedContext = struct {
    scope: heap.AnalyzedScope,
    context: heap.AnalyzedContext,
};

pub fn collectRankedContexts(
    arena: Allocator,
    analysis: heap.ContextAnalysisResult,
    retained_size: ?ByteSizeRange,
    scope_info_node_id: ?u64,
) Allocator.Error![]const RankedContext {
    const min: u64 = if (retained_size) |r| r.min else 0;
    const max: ?u64 = if (retained_size) |r| r.max else null;
    var out: std.ArrayList(RankedContext) = .empty;
    for (analysis.scopes) |scope| {
        if (scope_info_node_id) |want_id| {
            if (scope.scope_info_node_id != want_id) continue;
        }
        for (scope.contexts) |ctx| {
            const score = ctx.dead_fields_retained_size_sum;
            if (score < min) continue;
            if (max) |m| if (score > m) continue;
            try out.append(arena, .{ .scope = scope, .context = ctx });
        }
    }
    std.sort.block(RankedContext, out.items, {}, struct {
        fn lessThan(_: void, left: RankedContext, right: RankedContext) bool {
            return left.context.dead_fields_retained_size_sum > right.context.dead_fields_retained_size_sum;
        }
    }.lessThan);
    return out.items;
}

const em_dash = "\xe2\x80\x94";

fn formatCount(arena: Allocator, count: usize, singular: []const u8) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(arena, "{d} {s}{s}", .{ count, singular, if (count == 1) "" else "s" });
}

fn formatScopeName(arena: Allocator, scope: heap.AnalyzedScope, max_len: usize) Allocator.Error![]const u8 {
    const script_name = if (scope.script_name.len > 0)
        try formatName(arena, scope.script_name, max_len)
    else
        try std.fmt.allocPrint(arena, "script @{d}", .{scope.script_node_id});
    if (scope.scope_name) |sn| if (sn.len > 0) {
        return std.fmt.allocPrint(arena, "{s} ({s})", .{ try formatName(arena, sn, max_len), script_name });
    };
    return script_name;
}

pub fn formatContextAnalysis(
    arena: Allocator,
    contexts: []const RankedContext,
    scripts_without_scopes: []const heap.ScriptWithoutScopes,
    max_len: usize,
) Allocator.Error![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    if (contexts.len == 0) {
        try lines.append(arena, "No live contexts with dead fields were found.");
    }
    for (contexts) |entry| {
        if (lines.items.len > 0) try lines.append(arena, "");
        try lines.append(arena, try std.fmt.allocPrint(arena, "#### Context @{d} in `{s}` " ++ em_dash ++ " {s}", .{
            entry.context.context_node_id,
            try formatScopeName(arena, entry.scope, max_len),
            try formatBytesToKbU64(arena, entry.context.dead_fields_retained_size_sum),
        }));
        try lines.append(arena, try std.fmt.allocPrint(arena, "Script @{d}, ScopeInfo @{d}, offsets {d}-{d}, {s}", .{
            entry.scope.script_node_id,
            entry.scope.scope_info_node_id,
            entry.scope.scope_start,
            entry.scope.scope_end,
            try formatCount(arena, entry.scope.context_field_count, "context field"),
        }));
        for (entry.context.dead_fields) |field| {
            try lines.append(arena, try std.fmt.allocPrint(arena, "- `{s}` ({s} @{d}) " ++ em_dash ++ " {s}", .{
                try formatName(arena, field.name, max_len),
                try formatName(arena, field.value_name, max_len),
                field.value_node_id,
                try formatBytesToKbU64(arena, field.retained_size),
            }));
        }
    }
    if (scripts_without_scopes.len > 0) {
        try lines.append(arena, "");
        try lines.append(arena, "Scripts without scope metadata could not be analyzed:");
        for (scripts_without_scopes) |script| {
            const script_name = if (script.script_name.len > 0)
                try formatName(arena, script.script_name, max_len)
            else
                try std.fmt.allocPrint(arena, "script @{d}", .{script.script_node_id});
            try lines.append(arena, try std.fmt.allocPrint(arena, "- `{s}` (@{d}) " ++ em_dash ++ " {s}", .{
                script_name,
                script.script_node_id,
                try formatCount(arena, script.context_count, "context"),
            }));
        }
    }
    return std.mem.join(arena, "\n", lines.items);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

test "formatBytesToKb matches DevTools ByteUtilities (NBSP, base-1000, rounding, grouping)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    try testing.expectEqualStrings("0.0" ++ nbsp ++ "kB", try formatBytesToKb(arena, 0));
    try testing.expectEqualStrings("0.0" ++ nbsp ++ "kB", try formatBytesToKb(arena, 49));
    try testing.expectEqualStrings("0.1" ++ nbsp ++ "kB", try formatBytesToKb(arena, 50));
    try testing.expectEqualStrings("1.5" ++ nbsp ++ "kB", try formatBytesToKb(arena, 1500));
    try testing.expectEqualStrings("2.0" ++ nbsp ++ "kB", try formatBytesToKb(arena, 2048));
    try testing.expectEqualStrings("99.9" ++ nbsp ++ "kB", try formatBytesToKb(arena, 99_949));
    try testing.expectEqualStrings("100.0" ++ nbsp ++ "kB", try formatBytesToKb(arena, 99_950));
    try testing.expectEqualStrings("100" ++ nbsp ++ "kB", try formatBytesToKb(arena, 100_000));
    try testing.expectEqualStrings("1,235" ++ nbsp ++ "kB", try formatBytesToKb(arena, 1_234_567));
    try testing.expectEqualStrings("-0.5" ++ nbsp ++ "kB", try formatBytesToKb(arena, -500));
    try testing.expectEqualStrings("-1,000.0" ++ nbsp ++ "kB", try formatBytesToKb(arena, -1_000_000));
}

test "parseByteSizeRange matches chrome-devtools-mcp bytes.ts" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    try testing.expectEqual(ByteSizeRange{ .min = 1024, .max = null }, (try parseByteSizeRange(arena, "1024")).ok);
    try testing.expectEqual(ByteSizeRange{ .min = 1024, .max = null }, (try parseByteSizeRange(arena, "1KiB")).ok);
    try testing.expectEqual(ByteSizeRange{ .min = 1_000_000, .max = 2_000_000 }, (try parseByteSizeRange(arena, "1MB-2MB")).ok);
    try testing.expectEqual(ByteSizeRange{ .min = 0, .max = 500_000 }, (try parseByteSizeRange(arena, "-500KB")).ok);
    try testing.expectEqual(ByteSizeRange{ .min = 1_500_000_000, .max = null }, (try parseByteSizeRange(arena, "1.5GB-")).ok);

    const bad_unit = (try parseByteSizeRange(arena, "10XB")).err;
    try testing.expectEqualStrings("Unknown unit \"XB\" in \"10XB\". Supported units: B, KB, KiB, MB, MiB, GB, GiB, TB, TiB.", bad_unit);
    const bad_order = (try parseByteSizeRange(arena, "2MB-1MB")).err;
    try testing.expectEqualStrings("Invalid byte size range: \"2MB-1MB\". The lower bound must not exceed the upper bound.", bad_order);
    const empty_range = (try parseByteSizeRange(arena, "-")).err;
    try testing.expectEqualStrings("Invalid byte size range: \"-\". At least one bound is required.", empty_range);
}

test "formatName truncates UTF-16 code units and escapes CR/LF" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    try testing.expectEqualStrings("a\\rb\\nc", try formatName(arena, "a\rb\nc", 100));
    try testing.expectEqualStrings("hello...", try formatName(arena, "hello world", 5));
}
