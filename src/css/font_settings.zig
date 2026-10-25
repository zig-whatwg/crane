//! CSS Fonts4 §§6.12–13, 8.2: owned OpenType feature/variation maps.
//! Specified order is preserved; computed tags are last-wins and sorted.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Kind = enum { feature, variation };
pub const Entry = struct { tag: [4]u8, value: Value };

pub const Settings = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    kind: Kind,
    entries: []const Entry,

    /// Retains borrowed components only after all allocations succeed.
    pub fn create(allocator: Allocator, kind: Kind, entries: []const Entry) Allocator.Error!*Settings {
        const owned = try allocator.dupe(Entry, entries);
        errdefer allocator.free(owned);
        const self = try allocator.create(Settings);
        self.* = .{ .allocator = allocator, .kind = kind, .entries = owned };
        for (owned) |entry| entry.value.retain();
        return self;
    }
    pub fn ref(self: *Settings) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Settings) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.entries) |entry| entry.value.release();
        self.allocator.free(self.entries);
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Settings, other: *const Settings) bool {
        if (self == other) return true;
        if (self.kind != other.kind or self.entries.len != other.entries.len) return false;
        for (self.entries, other.entries) |a, b| {
            if (!std.mem.eql(u8, &a.tag, &b.tag) or !a.value.eql(b.value)) return false;
        }
        return true;
    }
    pub fn serialize(self: *const Settings, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.entries, 0..) |entry, i| {
            if (i != 0) try out.appendSlice(allocator, ", ");
            try values.appendString(&entry.tag, out, allocator);
            // §6.12: omitted, on and 1 have the same shortest serialization.
            if (self.kind == .feature and entry.value == .number and entry.value.number == 1) continue;
            try out.append(allocator, ' ');
            try properties.serializeValue(.font_weight, entry.value, out, allocator);
        }
    }

    pub fn compute(self: *const Settings, allocator: Allocator, context: math.Context) Allocator.Error!*Settings {
        var entries: std.ArrayList(Entry) = .empty;
        defer {
            for (entries.items) |entry| entry.value.release();
            entries.deinit(allocator);
        }
        // §§6.12 and 8.2: the last occurrence supersedes earlier ones before
        // the computed map is serialized in code-unit order.
        for (self.entries, 0..) |entry, i| {
            if (superseded(self.entries, i)) continue;
            const computed = if (entry.value == .calculation) blk: {
                const expression = try entry.value.calculation.compute(allocator, context);
                if (expression.computedNumber()) |number| {
                    defer expression.unref();
                    std.debug.assert(number.unit == .number);
                    break :blk Value{ .number = number.value };
                }
                break :blk Value{ .calculation = expression };
            } else blk: {
                entry.value.retain();
                break :blk entry.value;
            };
            errdefer computed.release();
            try entries.append(allocator, .{ .tag = entry.tag, .value = computed });
        }
        std.mem.sort(Entry, entries.items, {}, struct {
            fn less(_: void, a: Entry, b: Entry) bool {
                return std.mem.order(u8, &a.tag, &b.tag) == .lt;
            }
        }.less);
        return create(allocator, self.kind, entries.items);
    }

    pub fn needsUnavailableMetrics(self: *const Settings) bool {
        for (self.entries, 0..) |entry, i| {
            if (superseded(self.entries, i)) continue;
            if (entry.value == .calculation and entry.value.calculation.needsUnavailableMetrics(false)) return true;
        }
        return false;
    }

    /// Fonts 4 §§6.12 and 8.2: only effective tags are evaluated by compute.
    pub fn needsTreeCounts(self: *const Settings) bool {
        for (self.entries, 0..) |entry, i| {
            if (superseded(self.entries, i)) continue;
            if (entry.value == .calculation and entry.value.calculation.needsTreeCounts()) return true;
        }
        return false;
    }

    /// Superseded tags cannot introduce an input that compute never reads.
    pub fn needsRandomBase(self: *const Settings) bool {
        for (self.entries, 0..) |entry, i| {
            if (superseded(self.entries, i)) continue;
            if (entry.value == .calculation and entry.value.calculation.needsRandomBase()) return true;
        }
        return false;
    }
};

fn superseded(entries: []const Entry, index: usize) bool {
    for (entries[index + 1 ..]) |later| if (std.mem.eql(u8, &entries[index].tag, &later.tag)) return true;
    return false;
}

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream, kind: Kind) Allocator.Error!?Value {
    if (takeNormal(stream)) return Value.kw(.normal);
    var entries: std.ArrayList(Entry) = .empty;
    defer {
        for (entries.items) |entry| entry.value.release();
        entries.deinit(options.allocator);
    }
    while (true) {
        const token = stream.next();
        if (token.token_type != .string) return null;
        const tag = try tokens.decode(options.allocator, token.stringContents());
        defer options.allocator.free(tag);
        if (tag.len != 4 or !printable(tag)) return null;
        const value = (try parseNumber(options, stream, kind)) orelse return null;
        errdefer value.release();
        try entries.append(options.allocator, .{ .tag = tag[0..4].*, .value = value });
        if (stream.peek().token_type != .comma) break;
        _ = stream.next();
    }
    return .{ .font_settings = try Settings.create(options.allocator, kind, entries.items) };
}

fn parseNumber(options: properties.ParseOptions, stream: *properties.Stream, kind: Kind) Allocator.Error!?Value {
    const token = stream.peek();
    if (math.isFunction(token)) return properties.mathValue(options, stream, .{
        .kind = if (kind == .feature) .integer else .number,
        .minimum = if (kind == .feature) 0 else -std.math.floatMax(f64),
    });
    if (token.token_type == .number) {
        const n = token.numeric_value orelse return null;
        if (!std.math.isFinite(n) or (kind == .feature and (!token.is_integer or n < 0))) return null;
        _ = stream.next();
        return .{ .number = n };
    }
    if (kind == .variation) return null;
    if (token.token_type == .ident) {
        if (tokens.nameEql(token.value, "on")) {
            _ = stream.next();
            return .{ .number = 1 };
        }
        if (tokens.nameEql(token.value, "off")) {
            _ = stream.next();
            return .{ .number = 0 };
        }
    }
    return .{ .number = 1 };
}

pub fn parseLanguage(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (takeNormal(stream)) return Value.kw(.normal);
    const token = stream.next();
    if (token.token_type != .string) return null;
    const tag = try tokens.decode(options.allocator, token.stringContents());
    defer options.allocator.free(tag);
    // Chrome/Firefox's shipped grammar, pinned by WPT: 1–4 printable ASCII
    // characters, then shortest serialization drops only trailing spaces.
    if (tag.len == 0 or tag.len > 4 or !printable(tag)) return null;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(options.allocator);
    try values.appendString(std.mem.trimEnd(u8, tag, " "), &out, options.allocator);
    return .{ .text = try values.SharedText.create(options.allocator, out.items) };
}

fn printable(text: []const u8) bool {
    for (text) |ch| if (ch < 0x20 or ch > 0x7e) return false;
    return true;
}
fn takeNormal(stream: *properties.Stream) bool {
    const token = stream.peek();
    if (token.token_type != .ident or !tokens.nameEql(token.value, "normal")) return false;
    _ = stream.next();
    return true;
}
