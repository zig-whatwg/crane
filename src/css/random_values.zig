//! CSS Values 5 §9: a document-seeded mapping, without retained DOM state.
const std = @import("std");
const tokens = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;

pub const Function = enum(u8) { numeric, item };
pub const CacheKey = struct {
    name: ?[]const u8 = null,
    property: ?[]const u8 = null,
    element_scoped: bool = false,
    /// CSSWG #14330: only property-index buckets distinguish the functions.
    /// Explicit names and bare element-scoped keys stay shared.
    indexed_function: ?Function = null,

    pub fn eql(a: CacheKey, b: CacheKey) bool {
        return nullableEql(a.name, b.name) and nullableEql(a.property, b.property) and
            a.element_scoped == b.element_scoped and a.indexed_function == b.indexed_function;
    }

    pub fn clone(self: CacheKey, allocator: Allocator) Allocator.Error!CacheKey {
        const name = if (self.name) |n| try allocator.dupe(u8, n) else null;
        errdefer if (name) |n| allocator.free(n);
        const property = if (self.property) |p| try allocator.dupe(u8, p) else null;
        return .{ .name = name, .property = property, .element_scoped = self.element_scoped, .indexed_function = self.indexed_function };
    }

    pub fn deinit(self: CacheKey, allocator: Allocator) void {
        if (self.name) |n| allocator.free(n);
        if (self.property) |p| allocator.free(p);
    }

    pub fn serialize(self: CacheKey, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        var separated = false;
        if (self.name) |n| {
            try appendIdent(n, out, allocator);
            separated = true;
        }
        if (self.element_scoped) {
            if (separated) try out.append(allocator, ' ');
            try out.appendSlice(allocator, "element-scoped");
            separated = true;
        }
        if (self.property) |p| {
            if (separated) try out.append(allocator, ' ');
            try appendIdent(p, out, allocator);
        }
    }
};

fn nullableEql(a: ?[]const u8, b: ?[]const u8) bool {
    if ((a == null) != (b == null)) return false;
    return if (a) |x| std.mem.eql(u8, x, b.?) else true;
}

pub const Identity = struct { address: usize, generation: u64, pseudo: ?[]const u8 };
pub const Provider = struct {
    context: *anyopaque,
    get: *const fn (*anyopaque, CacheKey) Allocator.Error!f64,
};

/// §9.4 permits a PRNG seeded by the cache tuple instead of storing keys.
/// BLAKE3's keyed mapping keeps fields independent; 53 bits exactly span
/// representable equally spaced fractions in [0,1), with no allocation.
pub fn baseValue(seed: [32]u8, key: CacheKey, identity: Identity) f64 {
    var hash = std.crypto.hash.Blake3.init(.{ .key = seed });
    hash.update("Crane CSS random v1");
    hashNullable(&hash, key.name);
    hashNullable(&hash, key.property);
    hash.update(&.{if (key.indexed_function) |f| @intFromEnum(f) + 1 else 0});
    hash.update(&.{@intFromBool(key.element_scoped)});
    if (key.element_scoped) {
        hashInteger(&hash, @intCast(identity.address));
        hashInteger(&hash, identity.generation);
        hashNullable(&hash, identity.pseudo);
    }
    var digest: [8]u8 = undefined;
    hash.final(&digest);
    const bits = std.mem.readInt(u64, &digest, .little) >> 11;
    return @as(f64, @floatFromInt(bits)) / 9007199254740992.0;
}

fn hashInteger(hash: *std.crypto.hash.Blake3, value: u64) void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .little);
    hash.update(&bytes);
}

fn hashNullable(hash: *std.crypto.hash.Blake3, value: ?[]const u8) void {
    hash.update(&.{@intFromBool(value != null)});
    if (value) |bytes| {
        hashInteger(hash, @intCast(bytes.len));
        hash.update(bytes);
    }
}

pub fn fixedBase(value: f64) f64 {
    if (std.math.isNan(value)) return 0;
    return std.math.clamp(value, 0, @as(f64, @bitCast(@as(u64, @bitCast(@as(f64, 1))) - 1)));
}

/// §9.1.1 then §9.3. This consumes canonical values of one consistent type.
pub fn evaluate(base: f64, minimum: f64, maximum: f64, step: ?f64) f64 {
    const nan = std.math.nan(f64);
    if (std.math.isNan(minimum) or std.math.isNan(maximum) or
        (step != null and std.math.isNan(step.?))) return nan;
    if (std.math.isInf(minimum)) return minimum;
    const high = @max(minimum, maximum);
    const range = high - minimum;
    if (std.math.isInf(range)) return nan;
    const r = fixedBase(base);
    if (step) |increment| {
        if (std.math.isInf(increment)) return minimum;
        if (increment > 0 and std.math.isFinite(range / increment)) {
            const epsilon = @max(increment / 1000, @as(f64, @bitCast(@as(u64, 1))));
            var n = @floor(range / increment);
            if (@abs(minimum + n * increment - high) > epsilon and
                @abs(minimum + (n + 1) * increment - high) <= epsilon) n += 1;
            const index = @min(n, @floor(r * (n + 1)));
            const value = minimum + index * increment;
            if (index == n and @abs(value - high) <= epsilon) return high;
            return value;
        }
    }
    return minimum + r * range;
}

fn appendIdent(text: []const u8, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const escaped = try @import("serialize.zig").serializeIdentifier(allocator, text);
    defer allocator.free(escaped);
    try out.appendSlice(allocator, escaped);
}

/// Borrowed parse-time inputs. The caller assigns this ordinal before parsing
/// the function's children, and owns the per-kind counters (Q75/Q82).
pub const KeySource = struct {
    property: []const u8,
    index: usize,
    function: Function,
    early: bool = false,
};

fn propertyKey(allocator: Allocator, source: KeySource, indexed: bool) Allocator.Error![]u8 {
    const prefix: []const u8 = if (source.early) "ua-early-" else "ua-";
    return if (indexed)
        std.fmt.allocPrint(allocator, "{s}{s}-{d}", .{ prefix, source.property, source.index })
    else
        std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, source.property });
}

fn automaticKey(allocator: Allocator, source: KeySource) Allocator.Error!CacheKey {
    return .{ .property = try propertyKey(allocator, source, true), .element_scoped = true, .indexed_function = source.function };
}

/// Values 5 §§9.4–9.4.1. Parse only the auto/cache-key arms; the numeric tree
/// owner parses fixed <number> with its own grammar and dependency tracking.
/// null text is an omitted numeric key; an explicitly empty key is invalid.
/// Every successful result owns its strings and must be deinitialized.
pub fn parseCacheKey(allocator: Allocator, text: ?[]const u8, source: ?KeySource) Allocator.Error!?CacheKey {
    const input = text orelse return try automaticKey(allocator, source orelse return null);
    var tokenizer = tokens.Tokenizer.init(input);
    tokenizer.skipWhitespace();
    const first = tokenizer.next();
    if (first.token_type == .ident and tokens.nameEql(first.value, "auto")) {
        tokenizer.skipWhitespace();
        if (tokenizer.next().token_type != .eof) return null;
        return try automaticKey(allocator, source orelse return null);
    }
    tokenizer = tokens.Tokenizer.init(input);
    var key = CacheKey{};
    var success = false;
    defer if (!success) key.deinit(allocator);
    var consumed = false;
    while (true) {
        tokenizer.skipWhitespace();
        const token = tokenizer.next();
        if (token.token_type == .eof) break;
        if (token.token_type != .ident) return null;
        consumed = true;
        if (tokens.nameEql(token.value, "element-scoped")) {
            if (key.element_scoped) return null;
            key.element_scoped = true;
        } else if (tokens.nameEql(token.value, "property-scoped") or tokens.nameEql(token.value, "property-index-scoped")) {
            if (key.property != null) return null;
            const indexed = tokens.nameEql(token.value, "property-index-scoped");
            key.property = try propertyKey(allocator, source orelse return null, indexed);
            if (indexed) key.indexed_function = source.?.function;
        } else {
            const decoded = try tokens.decode(allocator, token.value);
            var adopted = false;
            defer if (!adopted) allocator.free(decoded);
            // Values 4 §4.3: a <dashed-ident> starts with two dashes;
            // there is no requirement for a nonempty suffix.
            if (std.mem.startsWith(u8, decoded, "--")) {
                if (key.name != null) return null;
                key.name = decoded;
            } else if (std.mem.startsWith(u8, decoded, "ua-")) {
                if (key.property != null) return null;
                // <random-ua-ident> is an arbitrary custom identifier with
                // this prefix; it need not name a supported CSS property.
                // Re-specified ua keys keep Q75's documented round-trip gap:
                // only automatically generated index keys carry a kind tag.
                key.property = decoded;
            } else return null;
            adopted = true;
        }
    }
    if (!consumed) return null;
    success = true;
    return key;
}

/// Q90 / Values5 §9.4.1: immutable source ordinals survive parser retries.
/// Only entries are owned. Text and property names are borrowed until deinit;
/// parsed trees clone their normalized keys and retain none of this scope.
pub const ParseScope = struct {
    allocator: Allocator,
    text: []const u8,
    entries: []const Entry,

    pub const Entry = struct { offset: usize, source: KeySource };
    pub const Options = struct {
        early: bool = false,
        numeric_offset: usize = 0,
        item_offset: usize = 0,
    };

    pub fn init(allocator: Allocator, text: []const u8, property: []const u8, options: Options) Allocator.Error!ParseScope {
        var entries: std.ArrayList(Entry) = .empty;
        errdefer entries.deinit(allocator);
        var counters = [_]usize{ options.numeric_offset, options.item_offset };
        var tokenizer = tokens.Tokenizer.init(text);
        while (true) {
            const token = tokenizer.next();
            if (token.token_type == .eof) break;
            if (token.token_type != .function) continue;
            const kind: Function = if (tokens.nameEql(token.value, "random")) .numeric else if (tokens.nameEql(token.value, "random-item")) .item else continue;
            const counter = &counters[@intFromEnum(kind)];
            counter.* += 1;
            try entries.append(allocator, .{
                .offset = @intFromPtr(token.value.ptr) - @intFromPtr(text.ptr),
                .source = .{ .property = property, .index = counter.*, .function = kind, .early = options.early },
            });
        }
        return .{ .allocator = allocator, .text = text, .entries = try entries.toOwnedSlice(allocator) };
    }

    pub fn deinit(self: *ParseScope) void {
        self.allocator.free(self.entries);
        self.* = undefined;
    }

    /// A parser can use a substring of the original declaration. Token
    /// addresses identify source positions, but never enter a parsed value.
    pub fn sourceFor(self: *const ParseScope, token: []const u8) ?KeySource {
        const address = @intFromPtr(token.ptr);
        const start = @intFromPtr(self.text.ptr);
        if (address < start or address - start >= self.text.len) return null;
        const offset = address - start;
        var low: usize = 0;
        var high = self.entries.len;
        while (low < high) {
            const middle = low + (high - low) / 2;
            const entry = self.entries[middle];
            if (entry.offset < offset) low = middle + 1 else high = middle;
        }
        return if (low < self.entries.len and self.entries[low].offset == offset) self.entries[low].source else null;
    }
};
