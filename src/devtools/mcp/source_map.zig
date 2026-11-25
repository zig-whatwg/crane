//! Source Map V3 parser and forward/reverse location mapper for set_logpoints
//! (batch 4b item 3b), reproducing the DevTools frontend's SourceMap model:
//!
//! - Upstream project: Chrome DevTools Frontend (devtools-frontend, bundled in
//!   chrome-devtools-mcp v1.13.0), BSD-3-Clause (Copyright The Chromium
//!   Authors; THIRD_PARTY_NOTICES.md).
//! - Upstream files reproduced (algorithm, not copied verbatim):
//!   - `front_end/core/sdk/SourceMap.ts`: `parseSourceMap`, `SourceMapEntry`,
//!     `SourceMap` (`#parseSources`, `#parseMap`, `#computeReverseMappings`,
//!     `findEntry`, `findEntryExact`, `findEntryRanges`, `sourceLineMapping`,
//!     `findReverseEntries`, `compatibleForURL`, `TokenIterator` Base64 VLQ decoder)
//!   - `front_end/core/sdk/SourceMapRangeMappings.ts`: `decodeRangeMappings`,
//!     `interpolateOriginalPosition`
//!   - `front_end/core/common/ParsedURL.ts`: `ParsedURL.completeURL`,
//!     `ParsedURL.isRelativeURL`, `normalizePath`

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Error = error{
    InvalidSourceMap,
    InvalidVlq,
    OutOfMemory,
};

/// One decoded Source Map V3 mapping entry (0-based coordinates).
pub const Entry = struct {
    line: i64,
    column: i64,
    source_index: ?usize = null,
    /// Owned by the parent SourceMap's arena.
    source_url: ?[]const u8 = null,
    source_line: i64 = 0,
    source_column: i64 = 0,
    /// Owned by the parent SourceMap's arena.
    name: ?[]const u8 = null,
    is_range_mapping: bool = false,
};

pub const SourceInfo = struct {
    source_url: []const u8,
    content: ?[]const u8,
    ignore_list_hint: bool,
    /// Indices into `SourceMap.mappings`, sorted by
    /// `(source_line, source_column, line, column)`.
    reverse_mappings: []usize = &.{},
};

pub const TextRange = struct {
    start_line: i64,
    start_column: i64,
    end_line: i64,
    end_column: i64,
};

pub const EntryRanges = struct {
    range: TextRange,
    source_range: TextRange,
    source_url: []const u8,
};

pub const SourceMap = struct {
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    compiled_url: []const u8,
    source_mapping_url: []const u8,
    base_url: []const u8,
    source_infos: []SourceInfo,
    /// Unique resolved original source URLs in first-seen order.
    unique_urls: [][]const u8,
    /// Maps each unique source URL to its first `SourceInfo` index.
    url_to_info: std.StringHashMapUnmanaged(usize),
    /// Decoded mapping entries sorted stably by `(line, column)`.
    mappings: []Entry,

    pub fn deinit(self: *SourceMap) void {
        const alloc = self.allocator;
        self.arena.deinit();
        alloc.destroy(self);
    }

    pub fn sourceUrls(self: *const SourceMap) []const []const u8 {
        return self.unique_urls;
    }

    pub fn embeddedContentByUrl(self: *const SourceMap, source_url: []const u8) ?[]const u8 {
        const idx = self.url_to_info.get(source_url) orelse return null;
        return self.source_infos[idx].content;
    }

    pub fn hasIgnoreListHint(self: *const SourceMap, source_url: []const u8) bool {
        const idx = self.url_to_info.get(source_url) orelse return false;
        return self.source_infos[idx].ignore_list_hint;
    }

    /// SourceMap.compatibleForURL: whether two source maps agree on inline
    /// content and ignore-list hint for `source_url`.
    pub fn compatibleForUrl(self: *const SourceMap, source_url: []const u8, other: *const SourceMap) bool {
        if (self.hasIgnoreListHint(source_url) != other.hasIgnoreListHint(source_url)) return false;
        const a = self.embeddedContentByUrl(source_url);
        const b = other.embeddedContentByUrl(source_url);
        if (a == null and b == null) return true;
        if (a == null or b == null) return false;
        return std.mem.eql(u8, a.?, b.?);
    }

    /// SourceMap.findEntry: last mapping at or before `(line, column)`,
    /// interpolating range mappings when covered.
    pub fn findEntry(self: *const SourceMap, line: i64, column: i64) ?Entry {
        const index = upperBoundEntry(self.mappings, line, column);
        if (index == 0) return null;
        const entry = self.mappings[index - 1];
        if (!entry.is_range_mapping or (entry.line == line and entry.column == column)) {
            return entry;
        }
        const pos = interpolateOriginalPosition(entry, line, column);
        return .{
            .line = line,
            .column = column,
            .source_index = entry.source_index,
            .source_url = entry.source_url,
            .source_line = pos.line,
            .source_column = pos.column,
            .name = null,
            .is_range_mapping = true,
        };
    }

    /// SourceMap.findEntryExact.
    pub fn findEntryExact(self: *const SourceMap, line: i64, column: i64) ?Entry {
        const entry = self.findEntry(line, column) orelse return null;
        if (entry.line == line and entry.column == column) return entry;
        return null;
    }

    /// SourceMap.findEntryRanges: returns the generated range and corresponding
    /// original source range covering `(line, column)`, used by
    /// `NamesResolver.resolveSourceName` when `entry.name` is absent.
    pub fn findEntryRanges(self: *const SourceMap, line: i64, column: i64) ?EntryRanges {
        const max_pos: i64 = (1 << 31) - 1;
        const end_index = upperBoundEntry(self.mappings, line, column);
        if (end_index == 0) return null;
        const start_index = end_index - 1;
        const start_entry = self.mappings[start_index];
        const source_url = start_entry.source_url orelse return null;
        const end_line: i64 = if (end_index < self.mappings.len) self.mappings[end_index].line else max_pos;
        const end_column: i64 = if (end_index < self.mappings.len) self.mappings[end_index].column else max_pos;
        const range: TextRange = .{
            .start_line = start_entry.line,
            .start_column = start_entry.column,
            .end_line = end_line,
            .end_column = end_column,
        };
        if (start_entry.is_range_mapping) {
            const source_end = if (end_index < self.mappings.len)
                interpolateOriginalPosition(start_entry, end_line, end_column)
            else
                LineCol{ .line = end_line, .column = end_column };
            return .{
                .range = range,
                .source_range = .{
                    .start_line = start_entry.source_line,
                    .start_column = start_entry.source_column,
                    .end_line = source_end.line,
                    .end_column = source_end.column,
                },
                .source_url = source_url,
            };
        }
        const rev = self.reversedMappings(source_url);
        const end_rev = upperBoundReversePos(self.mappings, rev, start_entry.source_line, start_entry.source_column);
        if (end_rev == 0) return null;
        const end_src_line: i64 = if (end_rev < rev.len) self.mappings[rev[end_rev]].source_line else max_pos;
        const end_src_col: i64 = if (end_rev < rev.len) self.mappings[rev[end_rev]].source_column else max_pos;
        return .{
            .range = range,
            .source_range = .{
                .start_line = start_entry.source_line,
                .start_column = start_entry.source_column,
                .end_line = end_src_line,
                .end_column = end_src_col,
            },
            .source_url = source_url,
        };
    }

    fn reversedMappings(self: *const SourceMap, source_url: []const u8) []const usize {
        const idx = self.url_to_info.get(source_url) orelse return &.{};
        return self.source_infos[idx].reverse_mappings;
    }

    /// SourceMap.sourceLineMapping: the first mapping on `line` of `source_url`
    /// at or after `column` (or the last mapping on `line` if `column` is past
    /// all mappings on that line); null if `line` has no mappings at all.
    pub fn sourceLineMapping(self: *const SourceMap, source_url: []const u8, line: i64, column: i64) ?Entry {
        const rev = self.reversedMappings(source_url);
        const first = lowerBoundReverseLine(self.mappings, rev, line);
        const last = upperBoundReverseLine(self.mappings, rev, line);
        if (first >= rev.len or self.mappings[rev[first]].source_line != line) return null;
        const column_mappings = rev[first..last];
        if (column_mappings.len == 0) return null;
        const idx = lowerBoundReverseColumn(self.mappings, column_mappings, column);
        const chosen = if (idx >= column_mappings.len) column_mappings[column_mappings.len - 1] else column_mappings[idx];
        return self.mappings[chosen];
    }

    /// SourceMap.findReverseEntries: all entries mapping to the highest
    /// original `(source_line, source_column)` <= `(line, column)`, optionally
    /// filtering contiguous mapping indices as `CompilerScriptMapping` does.
    pub fn findReverseEntries(
        self: *const SourceMap,
        arena: Allocator,
        source_url: []const u8,
        line: i64,
        column: i64,
        filter_contiguous: bool,
    ) Allocator.Error![]Entry {
        const rev = self.reversedMappings(source_url);
        const end_index = upperBoundReversePos(self.mappings, rev, line, column);
        if (end_index == 0) return &.{};
        const target_line = self.mappings[rev[end_index - 1]].source_line;
        const target_col = self.mappings[rev[end_index - 1]].source_column;
        var start_index = end_index;
        while (start_index > 0 and
            self.mappings[rev[start_index - 1]].source_line == target_line and
            self.mappings[rev[start_index - 1]].source_column == target_col)
        {
            start_index -= 1;
        }
        const indices = rev[start_index..end_index];
        var out: std.ArrayList(Entry) = .empty;
        for (indices, 0..) |mapping_idx, i| {
            if (filter_contiguous and i > 0 and mapping_idx == indices[i - 1] + 1) continue;
            try out.append(arena, self.mappings[mapping_idx]);
        }
        return out.items;
    }
};

/// `parseSourceMap` + `new SourceMap(...)` + `#ensureSourceMapProcessed`.
pub fn parse(
    allocator: Allocator,
    compiled_url: []const u8,
    source_mapping_url: []const u8,
    raw_content: []const u8,
) Error!*SourceMap {
    var content = raw_content;
    // XSSI protection prefix (SourceMap.ts parseSourceMap).
    if (std.mem.startsWith(u8, content, ")]}")) {
        const nl = std.mem.indexOfScalar(u8, content, '\n') orelse return error.InvalidSourceMap;
        content = content[nl + 1 ..];
    }
    // UTF-8 BOM (U+FEFF).
    if (std.mem.startsWith(u8, content, "\xEF\xBB\xBF")) {
        content = content[3..];
    }

    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const tmp = scratch.allocator();

    const parsed = std.json.parseFromSliceLeaky(std.json.Value, tmp, content, .{}) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidSourceMap,
    };
    if (parsed != .object) return error.InvalidSourceMap;
    const root = parsed.object;

    const sm = try allocator.create(SourceMap);
    errdefer allocator.destroy(sm);
    sm.* = .{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .compiled_url = &.{},
        .source_mapping_url = &.{},
        .base_url = &.{},
        .source_infos = &.{},
        .unique_urls = &.{},
        .url_to_info = .empty,
        .mappings = &.{},
    };
    errdefer sm.arena.deinit();

    const a = sm.arena.allocator();
    sm.compiled_url = try a.dupe(u8, compiled_url);
    sm.source_mapping_url = try a.dupe(u8, source_mapping_url);
    sm.base_url = if (schemeIs(sm.source_mapping_url, "data:")) sm.compiled_url else sm.source_mapping_url;

    // Collect sections (standard map = one section at offset 0, 0).
    const Section = struct {
        map: std.json.ObjectMap,
        base_source_index: usize,
        base_line: i64,
        base_column: i64,
    };
    var sections: std.ArrayList(Section) = .empty;
    if (root.get("sections")) |sec_val| {
        if (sec_val != .array) return error.InvalidSourceMap;
        var source_index_offset: usize = 0;
        for (sec_val.array.items) |item| {
            if (item != .object) continue;
            const map_val = item.object.get("map") orelse continue;
            if (map_val != .object) continue;
            const offset_val = item.object.get("offset") orelse return error.InvalidSourceMap;
            if (offset_val != .object) return error.InvalidSourceMap;
            const off_line = jsonInt(offset_val.object.get("line")) orelse return error.InvalidSourceMap;
            const off_col = jsonInt(offset_val.object.get("column")) orelse return error.InvalidSourceMap;
            const sources_len: usize = if (map_val.object.get("sources")) |sv| (if (sv == .array) sv.array.items.len else 0) else 0;
            try sections.append(tmp, .{
                .map = map_val.object,
                .base_source_index = source_index_offset,
                .base_line = off_line,
                .base_column = off_col,
            });
            source_index_offset += sources_len;
        }
    } else {
        try sections.append(tmp, .{
            .map = root,
            .base_source_index = 0,
            .base_line = 0,
            .base_column = 0,
        });
    }

    // Pass 1: #parseSources across all sections.
    var infos: std.ArrayList(SourceInfo) = .empty;
    var unique: std.ArrayList([]const u8) = .empty;
    for (sections.items) |sec| {
        try parseSources(a, tmp, sm.base_url, sec.map, &infos, &unique, &sm.url_to_info);
    }
    sm.source_infos = infos.items;
    sm.unique_urls = unique.items;

    // Pass 2: #parseMap across all sections.
    var mappings_list: std.ArrayList(Entry) = .empty;
    for (sections.items) |sec| {
        parseMapSection(a, tmp, sec.map, sm.source_infos, sec.base_source_index, sec.base_line, sec.base_column, &mappings_list) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => {
                // SourceMap.ts #ensureSourceMapProcessed catches parse errors
                // and leaves mappings empty.
                mappings_list.clearRetainingCapacity();
                break;
            },
        };
    }

    // Stable sort by (line, column) - std.sort.block is stable.
    std.sort.block(Entry, mappings_list.items, {}, struct {
        fn lessThan(_: void, x: Entry, y: Entry) bool {
            if (x.line != y.line) return x.line < y.line;
            return x.column < y.column;
        }
    }.lessThan);
    sm.mappings = mappings_list.items;

    // Pass 3: #computeReverseMappings.
    try computeReverseMappings(a, tmp, sm);

    return sm;
}

fn parseSources(
    arena: Allocator,
    tmp: Allocator,
    base_url: []const u8,
    map: std.json.ObjectMap,
    infos: *std.ArrayList(SourceInfo),
    unique: *std.ArrayList([]const u8),
    url_to_info: *std.StringHashMapUnmanaged(usize),
) Error!void {
    const sources_val = map.get("sources") orelse return;
    if (sources_val != .array) return error.InvalidSourceMap;
    const source_root = jsonStr(map.get("sourceRoot")) orelse "";
    const contents: ?[]const std.json.Value = if (map.get("sourcesContent")) |sc| (if (sc == .array) sc.array.items else null) else null;

    var ignore_set: std.AutoHashMapUnmanaged(usize, void) = .empty;
    const ignore_val = map.get("ignoreList") orelse map.get("x_google_ignoreList");
    if (ignore_val) |iv| if (iv == .array) {
        for (iv.array.items) |elem| {
            if (jsonInt(elem)) |idx| {
                if (idx >= 0) try ignore_set.put(tmp, @intCast(idx), {});
            }
        }
    };

    for (sources_val.array.items, 0..) |src_val, i| {
        const raw_href = jsonStr(src_val) orelse "";
        var href = raw_href;
        if (isRelativeUrl(href)) {
            if (source_root.len > 0 and !std.mem.endsWith(u8, source_root, "/") and href.len > 0 and !std.mem.startsWith(u8, href, "/")) {
                href = try std.fmt.allocPrint(tmp, "{s}/{s}", .{ source_root, href });
            } else if (source_root.len > 0) {
                href = try std.fmt.allocPrint(tmp, "{s}{s}", .{ source_root, href });
            }
        }
        const resolved = (try completeUrl(tmp, base_url, href)) orelse href;
        const owned_url = try arena.dupe(u8, resolved);
        const content: ?[]const u8 = if (contents) |cs| blk: {
            if (i < cs.len) {
                if (jsonStr(cs[i])) |s| break :blk try arena.dupe(u8, s);
            }
            break :blk null;
        } else null;
        const info_idx = infos.items.len;
        try infos.append(arena, .{
            .source_url = owned_url,
            .content = content,
            .ignore_list_hint = ignore_set.contains(i),
        });
        if (!url_to_info.contains(owned_url)) {
            try url_to_info.put(arena, owned_url, info_idx);
            try unique.append(arena, owned_url);
        }
    }
}

fn parseMapSection(
    arena: Allocator,
    tmp: Allocator,
    map: std.json.ObjectMap,
    source_infos: []const SourceInfo,
    base_source_index: usize,
    base_line: i64,
    base_column: i64,
    mappings: *std.ArrayList(Entry),
) Error!void {
    const mappings_str = jsonStr(map.get("mappings")) orelse return;
    const names_val = map.get("names");
    var names: []const ?[]const u8 = &.{};
    if (names_val) |nv| if (nv == .array) {
        const list = try arena.alloc(?[]const u8, nv.array.items.len);
        for (nv.array.items, 0..) |item, i| {
            list[i] = if (jsonStr(item)) |s| try arena.dupe(u8, s) else null;
        }
        names = list;
    };

    var source_index: i64 = @intCast(base_source_index);
    var line: i64 = base_line;
    var column: i64 = base_column;
    var source_line: i64 = 0;
    var source_column: i64 = 0;
    var name_index: i64 = 0;
    var source_url: ?[]const u8 = if (source_index >= 0 and @as(usize, @intCast(source_index)) < source_infos.len)
        source_infos[@intCast(source_index)].source_url
    else
        null;

    // Per-line starts/counts for optional `rangeMappings`.
    const LineSpan = struct { start: usize = 0, count: usize = 0 };
    var line_spans: std.ArrayList(LineSpan) = .empty;

    var iter: TokenIterator = .{ .text = mappings_str };
    while (true) {
        if (iter.peek() == ',') {
            _ = iter.next();
        } else {
            while (iter.peek() == ';') {
                line += 1;
                column = 0;
                _ = iter.next();
            }
            if (!iter.hasNext()) break;
        }
        column += try iter.nextVlq();
        const rel_line: usize = if (line >= base_line) @intCast(line - base_line) else 0;
        if (rel_line >= line_spans.items.len) {
            try line_spans.appendNTimes(tmp, .{}, rel_line + 1 - line_spans.items.len);
        }
        if (line_spans.items[rel_line].count == 0) {
            line_spans.items[rel_line].start = mappings.items.len;
        }
        line_spans.items[rel_line].count += 1;

        if (!iter.hasNext() or isSeparator(iter.peek())) {
            try mappings.append(arena, .{ .line = line, .column = column });
            continue;
        }
        const source_index_delta = try iter.nextVlq();
        if (source_index_delta != 0) {
            source_index += source_index_delta;
            source_url = if (source_index >= 0 and @as(usize, @intCast(source_index)) < source_infos.len)
                source_infos[@intCast(source_index)].source_url
            else
                null;
        }
        source_line += try iter.nextVlq();
        source_column += try iter.nextVlq();
        const si_opt: ?usize = if (source_index >= 0 and @as(usize, @intCast(source_index)) < source_infos.len) @intCast(source_index) else null;

        if (!iter.hasNext() or isSeparator(iter.peek())) {
            try mappings.append(arena, .{
                .line = line,
                .column = column,
                .source_index = si_opt,
                .source_url = source_url,
                .source_line = source_line,
                .source_column = source_column,
            });
            continue;
        }
        name_index += try iter.nextVlq();
        const name: ?[]const u8 = if (name_index >= 0 and @as(usize, @intCast(name_index)) < names.len) names[@intCast(name_index)] else null;
        try mappings.append(arena, .{
            .line = line,
            .column = column,
            .source_index = si_opt,
            .source_url = source_url,
            .source_line = source_line,
            .source_column = source_column,
            .name = name,
        });
    }

    // Optional TC39 `rangeMappings`: a malformed field is ignored without
    // invalidating the map.
    if (jsonStr(map.get("rangeMappings"))) |rm_str| {
        if (decodeRangeMappings(tmp, rm_str)) |rm_lines| {
            for (rm_lines, 0..) |indices, rm_line| {
                if (rm_line >= line_spans.items.len) break;
                const span = line_spans.items[rm_line];
                for (indices) |idx| {
                    if (idx >= span.count) break;
                    const mapping_idx = span.start + idx;
                    if (mappings.items[mapping_idx].source_url == null) continue;
                    mappings.items[mapping_idx].is_range_mapping = true;
                }
            }
        } else |_| {}
    }
}

fn decodeRangeMappings(tmp: Allocator, encoded: []const u8) Error![][]usize {
    var lines: std.ArrayList([]usize) = .empty;
    var indices: std.ArrayList(usize) = .empty;
    var current: u64 = 0;
    var iter: TokenIterator = .{ .text = encoded };
    while (iter.hasNext()) {
        if (iter.peek() == ';') {
            _ = iter.next();
            try lines.append(tmp, try indices.toOwnedSlice(tmp));
            current = 0;
            continue;
        }
        const delta = try iter.nextUnsignedVlq();
        current += delta;
        if (current > std.math.maxInt(u32)) return error.InvalidVlq;
        try indices.append(tmp, @intCast(current));
    }
    try lines.append(tmp, try indices.toOwnedSlice(tmp));
    return lines.items;
}

const LineCol = struct { line: i64, column: i64 };

fn interpolateOriginalPosition(entry: Entry, line: i64, column: i64) LineCol {
    const line_offset = line - entry.line;
    return .{
        .line = entry.source_line + line_offset,
        .column = if (line_offset == 0) entry.source_column + (column - entry.column) else column,
    };
}

fn computeReverseMappings(arena: Allocator, tmp: Allocator, sm: *SourceMap) Allocator.Error!void {
    const count = sm.source_infos.len;
    if (count == 0) return;
    const buckets = try tmp.alloc(std.ArrayList(usize), count);
    @memset(buckets, .empty);
    for (sm.mappings, 0..) |entry, i| {
        const u = entry.source_url orelse continue;
        const info_idx = sm.url_to_info.get(u) orelse continue;
        try buckets[info_idx].append(tmp, i);
    }
    const Ctx = struct {
        mappings: []const Entry,
        fn lessThan(ctx: @This(), a_idx: usize, b_idx: usize) bool {
            const a = ctx.mappings[a_idx];
            const b = ctx.mappings[b_idx];
            if (a.source_line != b.source_line) return a.source_line < b.source_line;
            if (a.source_column != b.source_column) return a.source_column < b.source_column;
            if (a.line != b.line) return a.line < b.line;
            return a.column < b.column;
        }
    };
    for (buckets, 0..) |*bucket, idx| {
        if (bucket.items.len == 0) continue;
        std.sort.block(usize, bucket.items, Ctx{ .mappings = sm.mappings }, Ctx.lessThan);
        sm.source_infos[idx].reverse_mappings = try arena.dupe(usize, bucket.items);
    }
}

// ---------------------------------------------------------------------------
// Binary search helpers (DevTools ArrayUtilities lowerBound / upperBound)
// ---------------------------------------------------------------------------

fn upperBoundEntry(mappings: []const Entry, line: i64, column: i64) usize {
    var l: usize = 0;
    var r: usize = mappings.len;
    while (l < r) {
        const m = l + (r - l) / 2;
        const e = mappings[m];
        const cmp = if (line != e.line) line - e.line else column - e.column;
        if (cmp < 0) {
            r = m;
        } else {
            l = m + 1;
        }
    }
    return l;
}

fn lowerBoundReverseLine(mappings: []const Entry, rev: []const usize, line: i64) usize {
    var l: usize = 0;
    var r: usize = rev.len;
    while (l < r) {
        const m = l + (r - l) / 2;
        if (mappings[rev[m]].source_line < line) {
            l = m + 1;
        } else {
            r = m;
        }
    }
    return l;
}

fn upperBoundReverseLine(mappings: []const Entry, rev: []const usize, line: i64) usize {
    var l: usize = 0;
    var r: usize = rev.len;
    while (l < r) {
        const m = l + (r - l) / 2;
        if (mappings[rev[m]].source_line <= line) {
            l = m + 1;
        } else {
            r = m;
        }
    }
    return l;
}

fn lowerBoundReverseColumn(mappings: []const Entry, rev: []const usize, column: i64) usize {
    var l: usize = 0;
    var r: usize = rev.len;
    while (l < r) {
        const m = l + (r - l) / 2;
        if (mappings[rev[m]].source_column < column) {
            l = m + 1;
        } else {
            r = m;
        }
    }
    return l;
}

fn upperBoundReversePos(mappings: []const Entry, rev: []const usize, line: i64, column: i64) usize {
    var l: usize = 0;
    var r: usize = rev.len;
    while (l < r) {
        const m = l + (r - l) / 2;
        const e = mappings[rev[m]];
        const cmp = if (line != e.source_line) line - e.source_line else column - e.source_column;
        if (cmp < 0) {
            r = m;
        } else {
            l = m + 1;
        }
    }
    return l;
}

// ---------------------------------------------------------------------------
// Base64 VLQ decoder (SourceMap.ts TokenIterator)
// ---------------------------------------------------------------------------

const vlq_base_shift: u6 = 5;
const vlq_base_mask: u32 = (1 << 5) - 1;
const vlq_continuation_mask: u32 = 1 << 5;

const base64_codes: [128]u8 = blk: {
    var table: [128]u8 = @splat(0);
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    for (chars, 0..) |c, i| table[c] = @intCast(i);
    break :blk table;
};

fn isSeparator(c: u8) bool {
    return c == ',' or c == ';';
}

const TokenIterator = struct {
    text: []const u8,
    pos: usize = 0,

    fn hasNext(self: *const TokenIterator) bool {
        return self.pos < self.text.len;
    }

    fn peek(self: *const TokenIterator) u8 {
        return if (self.pos < self.text.len) self.text[self.pos] else 0;
    }

    fn next(self: *TokenIterator) u8 {
        const c = self.text[self.pos];
        self.pos += 1;
        return c;
    }

    fn nextVlq(self: *TokenIterator) Error!i64 {
        const raw = try self.decodeVlq(false);
        const negative = (raw & 1) != 0;
        const magnitude: i64 = @intCast(raw >> 1);
        return if (negative) -magnitude else magnitude;
    }

    fn nextUnsignedVlq(self: *TokenIterator) Error!u32 {
        const raw = try self.decodeVlq(true);
        if (raw > std.math.maxInt(u32)) return error.InvalidVlq;
        return @intCast(raw);
    }

    fn decodeVlq(self: *TokenIterator, unsigned: bool) Error!u64 {
        var result: u64 = 0;
        var shift: u6 = 0;
        var digit: u32 = vlq_continuation_mask;
        while ((digit & vlq_continuation_mask) != 0) {
            if (!self.hasNext()) return error.InvalidVlq;
            if (unsigned and shift > 30) return error.InvalidVlq;
            if (shift >= 60) return error.InvalidVlq;
            const c = self.next();
            if (c >= 128) return error.InvalidVlq;
            digit = base64_codes[c];
            if (c != 'A' and digit == 0) return error.InvalidVlq;
            result += @as(u64, digit & vlq_base_mask) << shift;
            shift += vlq_base_shift;
        }
        return result;
    }
};

// ---------------------------------------------------------------------------
// DevTools ParsedURL (completeURL, isRelativeURL, normalizePath)
// ---------------------------------------------------------------------------

pub fn schemeIs(u: []const u8, scheme_with_colon: []const u8) bool {
    if (u.len < scheme_with_colon.len) return false;
    return std.ascii.eqlIgnoreCase(u[0..scheme_with_colon.len], scheme_with_colon);
}

fn beginsWithScheme(u: []const u8) bool {
    if (u.len < 2 or !std.ascii.isAlphabetic(u[0])) return false;
    var i: usize = 1;
    while (i < u.len) : (i += 1) {
        const c = u[i];
        if (c == ':') return true;
        if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '-' and c != '.') return false;
    }
    return false;
}

fn beginsWithWindowsDriveLetter(u: []const u8) bool {
    return u.len >= 2 and std.ascii.isAlphabetic(u[0]) and u[1] == ':';
}

/// ParsedURL.isRelativeURL.
pub fn isRelativeUrl(u: []const u8) bool {
    return !beginsWithScheme(u) or beginsWithWindowsDriveLetter(u);
}

const Parsed = struct {
    scheme: []const u8,
    host: []const u8,
    port: []const u8,
    path: []const u8,
    query: []const u8,
    fragment: []const u8,
    folder_path: []const u8,
    is_data: bool = false,
    is_blob: bool = false,
    blob_inner_scheme: []const u8 = "",

    fn securityOrigin(self: Parsed, arena: Allocator) Allocator.Error![]const u8 {
        if (self.is_data) return "data:";
        const s = if (self.is_blob) self.blob_inner_scheme else self.scheme;
        if (s.len == 0 and self.host.len == 0 and self.port.len == 0) return "";
        if (self.port.len != 0) return std.fmt.allocPrint(arena, "{s}://{s}:{s}", .{ s, self.host, self.port });
        return std.fmt.allocPrint(arena, "{s}://{s}", .{ s, self.host });
    }
};

/// ParsedURL.fromString: matches `scheme://[user@]host[:port][/path][?query][#fragment]`.
fn parseDevtoolsUrl(arena: Allocator, input: []const u8) Allocator.Error!?Parsed {
    const is_blob = std.mem.startsWith(u8, input, "blob:");
    const rest_in = if (is_blob) input["blob:".len..] else input;

    const sep = std.mem.indexOf(u8, rest_in, "://") orelse return null;
    if (sep == 0 or !std.ascii.isAlphabetic(rest_in[0])) return null;
    for (rest_in[1..sep]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '-' and c != '.') return null;
    }
    const raw_scheme = try std.ascii.allocLowerString(arena, rest_in[0..sep]);
    const after_scheme = rest_in[sep + 3 ..];

    // Authority ends at first '/', '?', or '#'.
    const auth_end = std.mem.indexOfAny(u8, after_scheme, "/?#") orelse after_scheme.len;
    const authority = after_scheme[0..auth_end];
    // Reject whitespace inside authority (matches `[^\s/:]*`).
    for (authority) |c| if (std.ascii.isWhitespace(c)) return null;

    // Optional userinfo@
    const host_port = if (std.mem.indexOfScalar(u8, authority, '@')) |at| authority[at + 1 ..] else authority;
    var host: []const u8 = host_port;
    var port: []const u8 = "";
    if (host_port.len > 0 and host_port[0] == '[') {
        const close = std.mem.indexOfScalar(u8, host_port, ']') orelse return null;
        host = host_port[0 .. close + 1];
        if (close + 1 < host_port.len) {
            if (host_port[close + 1] != ':') return null;
            port = host_port[close + 2 ..];
            if (port.len == 0) return null;
            for (port) |c| if (!std.ascii.isDigit(c)) return null;
        }
    } else if (std.mem.indexOfScalar(u8, host_port, ':')) |colon| {
        host = host_port[0..colon];
        port = host_port[colon + 1 ..];
        if (port.len == 0) return null;
        for (port) |c| if (!std.ascii.isDigit(c)) return null;
    }

    const tail = after_scheme[auth_end..];
    var path: []const u8 = "/";
    var query: []const u8 = "";
    var fragment: []const u8 = "";

    var pos: usize = 0;
    if (pos < tail.len and tail[pos] == '/') {
        const q_or_h = std.mem.indexOfAnyPos(u8, tail, pos, "?#") orelse tail.len;
        path = tail[pos..q_or_h];
        pos = q_or_h;
    }
    if (pos < tail.len and tail[pos] == '?') {
        const h = std.mem.indexOfScalarPos(u8, tail, pos + 1, '#') orelse tail.len;
        query = tail[pos + 1 .. h];
        pos = h;
    }
    if (pos < tail.len and tail[pos] == '#') {
        fragment = tail[pos + 1 ..];
    }

    const folder_path = if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| path[0..slash] else "";
    return .{
        .scheme = if (is_blob) "blob" else raw_scheme,
        .blob_inner_scheme = if (is_blob) raw_scheme else "",
        .is_blob = is_blob,
        .host = host,
        .port = port,
        .path = path,
        .query = query,
        .fragment = fragment,
        .folder_path = folder_path,
    };
}

/// DevTools ParsedURL `normalizePath`.
pub fn normalizePath(arena: Allocator, path: []const u8) Allocator.Error![]const u8 {
    if (std.mem.indexOf(u8, path, ".") == null) return path;
    const leading_slash = path.len > 0 and path[0] == '/';
    const stripped = if (leading_slash) path[1..] else path;
    var segs: std.ArrayList([]const u8) = .empty;
    var last_seg: []const u8 = "";
    var it = std.mem.splitScalar(u8, stripped, '/');
    while (it.next()) |seg| {
        last_seg = seg;
        if (std.mem.eql(u8, seg, ".")) continue;
        if (std.mem.eql(u8, seg, "..")) {
            _ = segs.pop();
        } else {
            try segs.append(arena, seg);
        }
    }
    var out: std.ArrayList(u8) = .empty;
    if (leading_slash and segs.items.len > 0) try out.append(arena, '/');
    for (segs.items, 0..) |seg, i| {
        if (i > 0) try out.append(arena, '/');
        try out.appendSlice(arena, seg);
    }
    const trailing = (path.len > 0 and path[path.len - 1] == '/') or std.mem.eql(u8, last_seg, ".") or std.mem.eql(u8, last_seg, "..");
    if (trailing and (out.items.len == 0 or out.items[out.items.len - 1] != '/')) {
        try out.append(arena, '/');
    }
    return out.items;
}

/// DevTools `ParsedURL.completeURL(baseURL, href)`.
pub fn completeUrl(arena: Allocator, base_url: []const u8, href: []const u8) Allocator.Error!?[]const u8 {
    if (std.mem.startsWith(u8, href, "data:") or
        std.mem.startsWith(u8, href, "blob:") or
        std.mem.startsWith(u8, href, "javascript:") or
        std.mem.startsWith(u8, href, "mailto:"))
    {
        return href;
    }
    const trimmed_href = std.mem.trim(u8, href, " \t\n\r\x0b\x0c");
    if (try parseDevtoolsUrl(arena, trimmed_href)) |parsed_href| {
        const origin = try parsed_href.securityOrigin(arena);
        const norm = try normalizePath(arena, parsed_href.path);
        const q = if (parsed_href.query.len != 0) try std.fmt.allocPrint(arena, "?{s}", .{parsed_href.query}) else "";
        const f = if (parsed_href.fragment.len != 0) try std.fmt.allocPrint(arena, "#{s}", .{parsed_href.fragment}) else "";
        return try std.fmt.allocPrint(arena, "{s}{s}{s}{s}", .{ origin, norm, q, f });
    }
    if (std.mem.startsWith(u8, base_url, "data:")) return href;
    const parsed_base = (try parseDevtoolsUrl(arena, base_url)) orelse return null;
    if (href.len > 1 and href[0] == '/' and href[1] == '/') {
        return try std.fmt.allocPrint(arena, "{s}:{s}", .{ parsed_base.scheme, href });
    }
    const origin = try parsed_base.securityOrigin(arena);
    const query_text = if (parsed_base.query.len != 0) try std.fmt.allocPrint(arena, "?{s}", .{parsed_base.query}) else "";
    if (href.len == 0) {
        return try std.fmt.allocPrint(arena, "{s}{s}{s}", .{ origin, parsed_base.path, query_text });
    }
    if (href[0] == '#') {
        return try std.fmt.allocPrint(arena, "{s}{s}{s}{s}", .{ origin, parsed_base.path, query_text, href });
    }
    if (href[0] == '?') {
        return try std.fmt.allocPrint(arena, "{s}{s}{s}", .{ origin, parsed_base.path, href });
    }
    const suffix_at = std.mem.indexOfAny(u8, href, "#?") orelse href.len;
    const href_path_raw = href[0..suffix_at];
    const href_suffix = href[suffix_at..];
    const combined_path = if (href_path_raw.len > 0 and href_path_raw[0] == '/')
        href_path_raw
    else
        try std.fmt.allocPrint(arena, "{s}/{s}", .{ parsed_base.folder_path, href_path_raw });
    const norm = try normalizePath(arena, combined_path);
    return try std.fmt.allocPrint(arena, "{s}{s}{s}", .{ origin, norm, href_suffix });
}

fn jsonStr(v: ?std.json.Value) ?[]const u8 {
    const val = v orelse return null;
    return if (val == .string) val.string else null;
}

fn jsonInt(v: ?std.json.Value) ?i64 {
    const val = v orelse return null;
    return switch (val) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => null,
    };
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

test "completeUrl: relative, dot-segments, sourceRoot, webpack, data base" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    try t.expectEqualStrings("http://127.0.0.1:8000/lp-sm/src/calc.ts", (try completeUrl(a, "http://127.0.0.1:8000/lp-sm/bundle.js.map", "src/calc.ts")).?);
    try t.expectEqualStrings("http://127.0.0.1:8000/src/calc.ts", (try completeUrl(a, "http://127.0.0.1:8000/lp-sm/bundle.js.map", "../src/calc.ts")).?);
    try t.expectEqualStrings("webpack:///app/sec-a.ts", (try completeUrl(a, "http://127.0.0.1:8000/lp-sm/indexed.js.map", "webpack:///app/sec-a.ts")).?);
    try t.expectEqualStrings("webpack://my-app/src/a.ts", (try completeUrl(a, "http://h/x.map", "webpack://my-app/./src/a.ts")).?);
    try t.expectEqualStrings("http://127.0.0.1:8000/abs/x.ts", (try completeUrl(a, "http://127.0.0.1:8000/a/b/c.map", "/abs/x.ts")).?);
    try t.expectEqualStrings("http://cdn.example/x.ts", (try completeUrl(a, "http://127.0.0.1:8000/a.map", "//cdn.example/x.ts")).?);
    try t.expectEqualStrings("src/a.ts", (try completeUrl(a, "data:text/javascript,1", "src/a.ts")).?);
}

test "parse, findEntry, sourceLineMapping, findReverseEntries, XSSI, sections, rangeMappings" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    // Standard map with bundle.js.map's exact mappings.
    const sm = try parse(t.allocator, "http://h/lp-sm/bundle.js", "http://h/lp-sm/bundle.js.map",
        \\{"version":3,"sources":["src/calc.ts"],"sourcesContent":["// c\n"],"names":[],"mappings":"AACA,2BACE,qBACA;AAGF,wBACE,6BACA"}
    );
    defer sm.deinit();
    try t.expectEqual(@as(usize, 1), sm.sourceUrls().len);
    const calc_url = "http://h/lp-sm/src/calc.ts";
    try t.expectEqualStrings(calc_url, sm.sourceUrls()[0]);
    try t.expectEqualStrings("// c\n", sm.embeddedContentByUrl(calc_url).?);

    // Forward lookup: gen (0, 48) -> src line 3, col 2; gen (0, 50) -> same entry.
    const e1 = sm.findEntry(0, 48).?;
    try t.expectEqual(@as(i64, 3), e1.source_line);
    try t.expectEqual(@as(i64, 2), e1.source_column);
    const e2 = sm.findEntry(0, 50).?;
    try t.expectEqual(@as(i64, 3), e2.source_line);
    try t.expectEqual(@as(i64, 2), e2.source_column);

    // Reverse lookup: src line 3, col 0 -> gen (0, 48); unmapped line 0 -> null.
    const rev1 = sm.sourceLineMapping(calc_url, 3, 0).?;
    try t.expectEqual(@as(i64, 0), rev1.line);
    try t.expectEqual(@as(i64, 48), rev1.column);
    try t.expect(sm.sourceLineMapping(calc_url, 0, 0) == null);

    const rev_entries = try sm.findReverseEntries(a, calc_url, rev1.source_line, rev1.source_column, true);
    try t.expectEqual(@as(usize, 1), rev_entries.len);
    try t.expectEqual(@as(i64, 0), rev_entries[0].line);
    try t.expectEqual(@as(i64, 48), rev_entries[0].column);

    // XSSI prefix + BOM + sections + sourceRoot.
    const idx_sm = try parse(t.allocator, "http://h/lp-sm/indexed.js", "http://h/lp-sm/indexed.js.map", ")]}'\n\xEF\xBB\xBF" ++
        \\{"version":3,"sections":[{"offset":{"line":0,"column":0},"map":{"version":3,"sourceRoot":"webpack:///app/","sources":["sec-a.ts"],"names":[],"mappings":"AACA,qBACE,iBACA"}},{"offset":{"line":1,"column":0},"map":{"version":3,"sourceRoot":"webpack:///app/","sources":["sec-b.ts"],"names":[],"mappings":"AAEA,qBACE,iBACA"}}]}
    );
    defer idx_sm.deinit();
    try t.expectEqual(@as(usize, 2), idx_sm.sourceUrls().len);
    try t.expectEqualStrings("webpack:///app/sec-a.ts", idx_sm.sourceUrls()[0]);
    try t.expectEqualStrings("webpack:///app/sec-b.ts", idx_sm.sourceUrls()[1]);
    const rb = idx_sm.sourceLineMapping("webpack:///app/sec-b.ts", 4, 0).?;
    try t.expectEqual(@as(i64, 1), rb.line);
    try t.expectEqual(@as(i64, 38), rb.column);

    // Inline data: sourceMappingURL resolves relative sources against compiledURL.
    const data_sm = try parse(t.allocator, "http://h/lp-sm/inline-map.js", "data:application/json;base64,e30=",
        \\{"version":3,"sources":["src/inline.ts"],"mappings":"AAEA"}
    );
    defer data_sm.deinit();
    try t.expectEqualStrings("http://h/lp-sm/src/inline.ts", data_sm.sourceUrls()[0]);

    // Range mapping interpolation.
    const range_sm = try parse(t.allocator, "http://h/r.js", "http://h/r.js.map",
        \\{"version":3,"sources":["r.ts"],"mappings":"AAAA","rangeMappings":"A"}
    );
    defer range_sm.deinit();
    const interp = range_sm.findEntry(2, 5).?;
    try t.expectEqual(@as(i64, 2), interp.source_line);
    try t.expectEqual(@as(i64, 5), interp.source_column);
    try t.expect(interp.is_range_mapping);

    // findEntryRanges for names-free token extraction.
    const nn_sm = try parse(t.allocator, "http://h/lp-min/nonames.js", "http://h/lp-min/nonames.js.map",
        \\{"version":3,"sources":["src/nonames.ts"],"sourcesContent":["export function calcTax(subtotal: number) {\n  const tax = subtotal * 2;\n  return tax;\n}\n"],"names":[],"mappings":"AAAA,oBACE,MAAM,CAAG,CAAG,CAAQ,GACpB,OAAO,CAAG"}
    );
    defer nn_sm.deinit();
    const r_y = nn_sm.findEntryRanges(0, 26).?;
    try t.expectEqual(@as(i64, 0), r_y.range.start_line);
    try t.expectEqual(@as(i64, 26), r_y.range.start_column);
    try t.expectEqual(@as(i64, 27), r_y.range.end_column);
    try t.expectEqual(@as(i64, 1), r_y.source_range.start_line);
    try t.expectEqual(@as(i64, 8), r_y.source_range.start_column);
    try t.expectEqual(@as(i64, 11), r_y.source_range.end_column);
    const r_x = nn_sm.findEntryRanges(0, 28).?;
    try t.expectEqual(@as(i64, 28), r_x.range.start_column);
    try t.expectEqual(@as(i64, 29), r_x.range.end_column);
    try t.expectEqual(@as(i64, 14), r_x.source_range.start_column);
    try t.expectEqual(@as(i64, 22), r_x.source_range.end_column);

    // Invalid JSON rejected cleanly.
    try t.expectError(error.InvalidSourceMap, parse(t.allocator, "http://h/a.js", "http://h/a.js.map", "{bad"));
}
