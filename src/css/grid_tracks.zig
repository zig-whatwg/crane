//! CSS Grid 2 §§7.2–7.8; Grid 3 §3.1.1. No layout-sized track expansion.
//! Design reference: Blink css_parsing_utils::ConsumeGridTrackList and
//! ConsumeGridTrackRepeatFunction, independently implemented.
const std = @import("std");
const properties = @import("properties.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const values = @import("style_values.zig");
const Allocator = std.mem.Allocator;
const Error = Allocator.Error || error{Invalid};
const Stream = properties.Stream;

pub const Mode = enum { template, automatic, explicit };
const Scalar = union(enum) {
    numeric: math.Numeric,
    calculation: *math.Expression,

    fn eql(a: Scalar, b: Scalar) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .numeric => |n| n.unit == b.numeric.unit and n.value == b.numeric.value,
            .calculation => |e| e.eql(b.calculation),
        };
    }
    fn serialize(self: Scalar, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .numeric => |n| {
                try values.appendNumber(n.value, out, allocator);
                try out.appendSlice(allocator, n.unit.name());
            },
            .calculation => |e| try e.serialize(out, allocator),
        }
    }
};
const Breadth = union(enum) {
    intrinsic: enum { auto, min_content, max_content },
    numeric: struct { scalar: Scalar, flex: bool = false },

    fn fixed(self: Breadth) bool {
        return self == .numeric and !self.numeric.flex;
    }
    fn eql(a: Breadth, b: Breadth) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .intrinsic => |k| k == b.intrinsic,
            .numeric => |n| n.flex == b.numeric.flex and n.scalar.eql(b.numeric.scalar),
        };
    }
    fn serialize(self: Breadth, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .intrinsic => |k| try out.appendSlice(allocator, switch (k) {
                .auto => "auto",
                .min_content => "min-content",
                .max_content => "max-content",
            }),
            .numeric => |n| try n.scalar.serialize(out, allocator),
        }
    }
};

pub const Track = union(enum) {
    breadth: Breadth,
    minmax: struct { min: Breadth, max: Breadth },
    fit_content: Scalar,

    fn fixed(self: Track) bool {
        return switch (self) {
            .breadth => |b| b.fixed(),
            .minmax => |m| m.min.fixed() or m.max.fixed(),
            .fit_content => false,
        };
    }
    pub fn isAuto(self: Track) bool {
        return self == .breadth and self.breadth == .intrinsic and self.breadth.intrinsic == .auto;
    }
    fn eql(a: Track, b: Track) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .breadth => |x| x.eql(b.breadth),
            .minmax => |x| x.min.eql(b.minmax.min) and x.max.eql(b.minmax.max),
            .fit_content => |x| x.eql(b.fit_content),
        };
    }
    pub fn serialize(self: Track, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .breadth => |b| try b.serialize(out, allocator),
            .minmax => |m| {
                try out.appendSlice(allocator, "minmax(");
                try m.min.serialize(out, allocator);
                try out.appendSlice(allocator, ", ");
                try m.max.serialize(out, allocator);
                try out.append(allocator, ')');
            },
            .fit_content => |e| {
                try out.appendSlice(allocator, "fit-content(");
                try e.serialize(out, allocator);
                try out.append(allocator, ')');
            },
        }
    }
};

pub const Item = union(enum) {
    names: []const []const u8,
    track: Track,
    repeat: struct {
        count: union(enum) { integer: Scalar, auto_fill, auto_fit },
        items: []const Item,
    },

    fn eql(a: Item, b: Item) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .names => |names| blk: {
                if (names.len != b.names.len) break :blk false;
                for (names, b.names) |x, y| if (!std.mem.eql(u8, x, y)) break :blk false;
                break :blk true;
            },
            .track => |track| track.eql(b.track),
            .repeat => |r| std.meta.activeTag(r.count) == std.meta.activeTag(b.repeat.count) and
                (r.count != .integer or r.count.integer.eql(b.repeat.count.integer)) and itemsEqual(r.items, b.repeat.items),
        };
    }
};

fn itemsEqual(a: []const Item, b: []const Item) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| if (!x.eql(y)) return false;
    return true;
}

/// One immutable aggregate owns its names/items in an arena, and every math
/// expression in a flat cleanup list. Partially parsed children cannot escape
/// cleanup when an allocation fails before they reach the top-level item list.
pub const Tracks = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    expressions: std.ArrayList(*math.Expression) = .empty,
    items: []const Item = &.{},
    subgrid: bool = false,

    fn create(allocator: Allocator) Allocator.Error!*Tracks {
        const self = try allocator.create(Tracks);
        self.* = .{ .allocator = allocator, .arena = std.heap.ArenaAllocator.init(allocator) };
        return self;
    }
    fn own(self: *Tracks, expression: *math.Expression) Allocator.Error!*math.Expression {
        errdefer expression.unref();
        try self.expressions.append(self.arena.allocator(), expression);
        return expression;
    }
    pub fn ref(self: *Tracks) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Tracks) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.expressions.items) |e| e.unref();
        self.arena.deinit();
        self.allocator.destroy(self);
    }
    pub fn eql(a: *const Tracks, b: *const Tracks) bool {
        return a == b or (a.subgrid == b.subgrid and itemsEqual(a.items, b.items));
    }
    pub fn needsUnavailableMetrics(self: *const Tracks) bool {
        // Lengths may keep unavailable metrics; numeric repeat counts may not.
        for (self.expressions.items) |e| if (e.needsUnavailableMetrics(e.grammar.kind == .length_percentage)) return true;
        return false;
    }
    pub fn needsTreeCounts(self: *const Tracks) bool {
        for (self.expressions.items) |e| if (e.needsTreeCounts()) return true;
        return false;
    }

    pub fn needsRandomBase(self: *const Tracks) bool {
        for (self.expressions.items) |e| if (e.needsRandomBase()) return true;
        return false;
    }
    pub fn compute(self: *const Tracks, allocator: Allocator, context: math.Context) Allocator.Error!*Tracks {
        const result = try create(allocator);
        errdefer result.unref();
        result.subgrid = self.subgrid;
        result.items = try result.copyItems(self.items, context);
        return result;
    }
    fn copyBreadth(self: *Tracks, b: Breadth, context: math.Context) Allocator.Error!Breadth {
        return switch (b) {
            .intrinsic => b,
            .numeric => |n| .{ .numeric = .{ .scalar = try self.copyScalar(n.scalar, context), .flex = n.flex } },
        };
    }
    fn copyScalar(self: *Tracks, scalar: Scalar, context: math.Context) Allocator.Error!Scalar {
        return switch (scalar) {
            .numeric => |n| blk: {
                var resolved = context.resolve(n);
                // Values 4 §10.12: conversion may overflow even when the
                // specified dimension was finite. Store a finite range-
                // clamped numeric result, as Expression.computedNumber does.
                resolved.value = if (std.math.isNan(resolved.value)) 0 else std.math.clamp(resolved.value, 0, std.math.floatMax(f64));
                break :blk .{ .numeric = resolved };
            },
            .calculation => |e| .{ .calculation = try self.own(try e.compute(self.allocator, context)) },
        };
    }
    fn copyItems(self: *Tracks, items: []const Item, context: math.Context) Allocator.Error![]const Item {
        const allocator = self.arena.allocator();
        const result = try allocator.alloc(Item, items.len);
        for (items, result) |source, *target| target.* = switch (source) {
            .names => |names| blk: {
                const copied = try allocator.alloc([]const u8, names.len);
                for (names, copied) |name, *copy| copy.* = try allocator.dupe(u8, name);
                break :blk .{ .names = copied };
            },
            .track => |track| .{ .track = switch (track) {
                .breadth => |b| .{ .breadth = try self.copyBreadth(b, context) },
                .minmax => |m| .{ .minmax = .{ .min = try self.copyBreadth(m.min, context), .max = try self.copyBreadth(m.max, context) } },
                .fit_content => |e| .{ .fit_content = try self.copyScalar(e, context) },
            } },
            .repeat => |r| .{ .repeat = .{
                .count = switch (r.count) {
                    .integer => |e| .{ .integer = try self.copyScalar(e, context) },
                    else => r.count,
                },
                .items = try self.copyItems(r.items, context),
            } },
        };
        return result;
    }
    pub fn serialize(self: *const Tracks, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self.subgrid) {
            try out.appendSlice(allocator, "subgrid");
            if (self.items.len != 0) try out.append(allocator, ' ');
        }
        try serializeItems(self.items, out, allocator);
    }

    pub fn consume(options: properties.ParseOptions, stream: *Stream, mode: Mode) Allocator.Error!?*Tracks {
        const self = try create(options.allocator);
        errdefer self.unref();
        if (mode == .template and keyword(stream.peek(), "subgrid")) {
            _ = stream.next();
            self.subgrid = true;
        }
        var parser = Parser{ .owner = self, .options = options, .stream = stream };
        self.items = parser.list(mode, false) catch |err| switch (err) {
            error.Invalid => {
                self.unref();
                return null;
            },
            error.OutOfMemory => return error.OutOfMemory,
        };
        return self;
    }
};

pub fn serializeNames(names: []const []const u8, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try out.append(allocator, '[');
    for (names, 0..) |name, i| {
        if (i != 0) try out.append(allocator, ' ');
        const escaped = try @import("serialize.zig").serializeIdentifier(allocator, name);
        defer allocator.free(escaped);
        try out.appendSlice(allocator, escaped);
    }
    try out.append(allocator, ']');
}

fn serializeItems(items: []const Item, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    for (items, 0..) |item, i| {
        if (i != 0) try out.append(allocator, ' ');
        switch (item) {
            .names => |names| try serializeNames(names, out, allocator),
            .track => |track| try track.serialize(out, allocator),
            .repeat => |r| {
                try out.appendSlice(allocator, "repeat(");
                switch (r.count) {
                    .integer => |e| try e.serialize(out, allocator),
                    .auto_fill => try out.appendSlice(allocator, "auto-fill"),
                    .auto_fit => try out.appendSlice(allocator, "auto-fit"),
                }
                try out.appendSlice(allocator, ", ");
                try serializeItems(r.items, out, allocator);
                try out.append(allocator, ')');
            },
        }
    }
}

fn keyword(token: tokens.Token, name: []const u8) bool {
    return token.token_type == .ident and tokens.nameEql(token.value, name);
}

fn function(token: tokens.Token, name: []const u8) bool {
    return token.token_type == .function and tokens.nameEql(token.value, name);
}

const Parser = struct {
    owner: *Tracks,
    options: properties.ParseOptions,
    stream: *Stream,

    fn require(self: *Parser, kind: tokens.TokenType) error{Invalid}!void {
        if (self.stream.next().token_type != kind) return error.Invalid;
    }
    fn numeric(self: *Parser, kind: math.Kind) Error!Scalar {
        const grammar = math.Grammar{ .kind = kind, .minimum = if (kind == .integer) 1 else 0 };
        const token = self.stream.peek();
        if (math.isFunction(token)) {
            const value = try properties.mathValue(self.options, self.stream, grammar) orelse return error.Invalid;
            return .{ .calculation = try self.owner.own(value.calculation) };
        }
        var unit: math.Unit = undefined;
        const number = token.numeric_value orelse return error.Invalid;
        switch (token.token_type) {
            .number => {
                if (kind == .integer) {
                    if (!token.is_integer) return error.Invalid;
                    unit = .number;
                } else {
                    if (number != 0) return error.Invalid;
                    unit = .px;
                }
            },
            .percentage => unit = .percent,
            .dimension => unit = math.Unit.parse(token.unit orelse return error.Invalid) orelse return error.Invalid,
            else => return error.Invalid,
        }
        if (number < grammar.minimum) return error.Invalid;
        const valid = switch (kind) {
            .integer => unit == .number,
            .flex => unit == .fr,
            .length_percentage => unit.base() == .length or unit == .percent,
            else => unreachable,
        };
        if (!valid) return error.Invalid;
        _ = self.stream.next();
        return .{ .numeric = .{ .value = @min(number, grammar.maximum), .unit = unit } };
    }
    fn breadth(self: *Parser, allow_flex: bool) Error!Breadth {
        const token = self.stream.peek();
        inline for (.{ .{ "auto", .auto }, .{ "min-content", .min_content }, .{ "max-content", .max_content } }) |entry| {
            if (keyword(token, entry[0])) {
                _ = self.stream.next();
                return .{ .intrinsic = entry[1] };
            }
        }
        if (token.token_type == .dimension and tokens.nameEql(token.unit orelse "", "fr")) {
            if (!allow_flex) return error.Invalid;
            return .{ .numeric = .{ .scalar = try self.numeric(.flex), .flex = true } };
        }
        const saved = self.stream.*;
        const scalar = self.numeric(.length_percentage) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.Invalid => {
                if (!allow_flex or !math.isFunction(token)) return error.Invalid;
                // Values 4 §10 permits typed calculations wherever a flex
                // is valid, including minmax's maximum but not its minimum.
                // Q58: this is documented implementation lag, not a new
                // grammar. Both pinned and current WPT reject only mixed
                // length/flex calculations; signs-abs-computed expects flex.
                // https://github.com/w3c/css-houdini-drafts/issues/734
                // https://github.com/w3c/csswg-drafts/issues/6989
                // https://crbug.com/993136
                // https://github.com/w3c/csswg-drafts/issues/13007
                // https://bugzilla.mozilla.org/show_bug.cgi?id=1866236
                // https://bugs.webkit.org/show_bug.cgi?id=265276
                // https://github.com/web-platform-tests/wpt/pull/43322
                self.stream.* = saved;
                return .{ .numeric = .{ .scalar = try self.numeric(.flex), .flex = true } };
            },
        };
        return .{ .numeric = .{ .scalar = scalar } };
    }
    fn track(self: *Parser) Error!Track {
        if (function(self.stream.peek(), "minmax")) {
            _ = self.stream.next();
            try self.require(.left_paren);
            const min = try self.breadth(false);
            try self.require(.comma);
            const max = try self.breadth(true);
            try self.require(.right_paren);
            return .{ .minmax = .{ .min = min, .max = max } };
        }
        if (function(self.stream.peek(), "fit-content")) {
            _ = self.stream.next();
            try self.require(.left_paren);
            const expression = try self.numeric(.length_percentage);
            try self.require(.right_paren);
            return .{ .fit_content = expression };
        }
        return .{ .breadth = try self.breadth(true) };
    }
    fn names(self: *Parser) Error![]const []const u8 {
        try self.require(.left_bracket);
        const allocator = self.owner.arena.allocator();
        var result: std.ArrayList([]const u8) = .empty;
        while (self.stream.peek().token_type != .right_bracket) {
            const token = self.stream.next();
            if (token.token_type != .ident) return error.Invalid;
            const name = try tokens.decode(allocator, token.value);
            if (std.ascii.eqlIgnoreCase(name, "auto") or std.ascii.eqlIgnoreCase(name, "span") or
                std.ascii.eqlIgnoreCase(name, "default") or values.CssWide.parse(name) != null) return error.Invalid;
            try result.append(allocator, name);
        }
        _ = self.stream.next();
        return result.items;
    }
    fn list(self: *Parser, mode: Mode, in_repeat: bool) Error![]const Item {
        const allocator = self.owner.arena.allocator();
        var result: std.ArrayList(Item) = .empty;
        var saw_names = false;
        var saw_track = false;
        var auto_repeat = false;
        var all_fixed = true;
        while (!self.stream.atEnd() and self.stream.peek().token_type != .right_paren and !@import("grid_values.zig").slash(self.stream.peek())) {
            if (self.stream.peek().token_type == .left_bracket) {
                if (mode == .automatic or (!self.owner.subgrid and saw_names)) return error.Invalid;
                const group = try self.names();
                if (group.len != 0 or self.owner.subgrid) try result.append(allocator, .{ .names = group });
                saw_names = true;
                continue;
            }
            if (function(self.stream.peek(), "repeat")) {
                if (in_repeat or mode != .template) return error.Invalid;
                _ = self.stream.next();
                try self.require(.left_paren);
                var repetition: @FieldType(Item, "repeat") = undefined;
                const is_auto = keyword(self.stream.peek(), "auto-fill") or keyword(self.stream.peek(), "auto-fit");
                if (is_auto) {
                    if (auto_repeat or (self.owner.subgrid and keyword(self.stream.peek(), "auto-fit"))) return error.Invalid;
                    auto_repeat = true;
                    repetition.count = if (keyword(self.stream.next(), "auto-fill")) .auto_fill else .auto_fit;
                } else repetition.count = .{ .integer = try self.numeric(.integer) };
                try self.require(.comma);
                repetition.items = try self.list(.template, true);
                try self.require(.right_paren);
                if (!self.owner.subgrid and !is_auto) for (repetition.items) |item| {
                    if (item == .track and !item.track.fixed()) all_fixed = false;
                };
                try result.append(allocator, .{ .repeat = repetition });
            } else {
                if (self.owner.subgrid) return error.Invalid;
                const size = try self.track();
                all_fixed = all_fixed and size.fixed();
                try result.append(allocator, .{ .track = size });
            }
            saw_track = true;
            saw_names = false;
        }
        if (self.owner.subgrid) {
            if (in_repeat and result.items.len == 0) return error.Invalid;
        } else {
            if (!saw_track) return error.Invalid;
            // Q38: Grid 3 changes the AUTO-REPEAT interior only. Ordinary
            // siblings and finite repeats still satisfy Grid 2 fixed-size.
            if (auto_repeat and !all_fixed) return error.Invalid;
        }
        return result.items;
    }
};

/// Grid 2 §7.3: normalized template strings, with rectangle validation done
/// once at parse time. No area coordinates or object pointers reach the DOM.
pub const Areas = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    rows: []const []const u8 = &.{},
    columns: usize = 0,

    fn create(allocator: Allocator) Allocator.Error!*Areas {
        const self = try allocator.create(Areas);
        self.* = .{ .allocator = allocator, .arena = std.heap.ArenaAllocator.init(allocator) };
        return self;
    }
    pub fn ref(self: *Areas) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Areas) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.arena.deinit();
        self.allocator.destroy(self);
    }
    pub fn eql(a: *const Areas, b: *const Areas) bool {
        if (a == b) return true;
        if (a.columns != b.columns or a.rows.len != b.rows.len) return false;
        for (a.rows, b.rows) |x, y| if (!std.mem.eql(u8, x, y)) return false;
        return true;
    }
    pub fn serialize(self: *const Areas, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.rows, 0..) |row, i| {
            if (i != 0) try out.append(allocator, ' ');
            try values.appendString(row, out, allocator);
        }
    }
    pub fn consume(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?*Areas {
        const self = try create(options.allocator);
        errdefer self.unref();
        var parser = AreaParser{ .owner = self };
        defer parser.deinit(options.allocator);
        while (stream.peek().token_type == .string) {
            parser.row(stream.next()) catch |err| switch (err) {
                error.Invalid => {
                    self.unref();
                    return null;
                },
                error.OutOfMemory => return error.OutOfMemory,
            };
        }
        if (self.rows.len == 0) {
            self.unref();
            return null;
        }
        return self;
    }
};

const AreaParser = struct {
    owner: *Areas,
    rows: std.ArrayList([]const u8) = .empty,
    rectangles: std.StringHashMapUnmanaged(Rectangle) = .empty,
    const Rectangle = struct { first: usize, end: usize, last_row: usize };

    fn deinit(self: *AreaParser, allocator: Allocator) void {
        self.rectangles.deinit(allocator);
    }
    fn row(self: *AreaParser, token: tokens.Token) Error!void {
        if (token.token_type != .string) return error.Invalid;
        const allocator = self.owner.arena.allocator();
        const contents = try tokens.decode(allocator, token.stringContents());
        var cells: std.ArrayList([]const u8) = .empty;
        var offset: usize = 0;
        // §7.3 steps 1–4: longest runs of identifier code points, dots,
        // whitespace, or trash. Numeric initial code points are valid here.
        while (offset < contents.len) {
            const first = offset;
            if (switch (contents[offset]) {
                ' ', '\t', '\n', '\r', '\x0c' => true,
                else => false,
            }) {
                offset += 1;
                continue;
            }
            if (contents[offset] == '.') {
                while (offset < contents.len and contents[offset] == '.') : (offset += 1) {}
                try cells.append(allocator, ".");
                continue;
            }
            while (offset < contents.len and nameCodePoint(contents[offset])) : (offset += 1) {}
            if (first == offset) return error.Invalid;
            try cells.append(allocator, contents[first..offset]);
        }
        if (cells.items.len == 0) return error.Invalid;
        if (self.rows.items.len == 0) self.owner.columns = cells.items.len else if (self.owner.columns != cells.items.len) return error.Invalid;
        // A name's cells must be one contiguous run on every adjacent row,
        // with the same horizontal extent. This proves a filled rectangle.
        var column: usize = 0;
        while (column < cells.items.len) {
            const first = column;
            const name = cells.items[column];
            column += 1;
            while (column < cells.items.len and std.mem.eql(u8, name, cells.items[column])) : (column += 1) {}
            if (std.mem.eql(u8, name, ".")) continue;
            const entry = try self.rectangles.getOrPut(self.owner.allocator, name);
            if (entry.found_existing) {
                const previous = entry.value_ptr.*;
                if (previous.first != first or previous.end != column or previous.last_row + 1 != self.rows.items.len) return error.Invalid;
            }
            entry.value_ptr.* = .{ .first = first, .end = column, .last_row = self.rows.items.len };
        }
        var normalized: std.ArrayList(u8) = .empty;
        for (cells.items, 0..) |cell, i| {
            if (i != 0) try normalized.append(allocator, ' ');
            try normalized.appendSlice(allocator, cell);
        }
        try self.rows.append(allocator, normalized.items);
        self.owner.rows = self.rows.items;
    }
};

fn nameCodePoint(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-' or byte >= 0x80;
}

pub const Template = struct {
    rows: values.Value = .kw(.none),
    columns: values.Value = .kw(.none),
    areas: values.Value = .kw(.none),

    pub fn deinit(self: Template) void {
        self.rows.release();
        self.columns.release();
        self.areas.release();
    }
};

fn takeKeyword(stream: *Stream, name: []const u8) bool {
    if (!keyword(stream.peek(), name)) return false;
    _ = stream.next();
    return true;
}

fn takeSlash(stream: *Stream) bool {
    if (!@import("grid_values.zig").slash(stream.peek())) return false;
    _ = stream.next();
    return true;
}

fn axis(options: properties.ParseOptions, stream: *Stream, mode: Mode) Error!values.Value {
    if (mode == .template and takeKeyword(stream, "none")) return .kw(.none);
    return .{ .grid_tracks = try Tracks.consume(options, stream, mode) orelse return error.Invalid };
}

/// Grid 2 §7.4: consume the three explicit properties as one owned result.
pub fn consumeTemplate(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Template {
    return template(options, stream) catch |err| switch (err) {
        error.Invalid => null,
        error.OutOfMemory => error.OutOfMemory,
    };
}

fn template(options: properties.ParseOptions, stream: *Stream) Error!Template {
    var result = Template{};
    errdefer result.deinit();
    if (takeKeyword(stream, "none")) {
        if (!takeSlash(stream)) return result;
        result.columns = try axis(options, stream, .template);
        return result;
    }
    var lookahead = stream.*;
    if (lookahead.peek().token_type == .left_bracket) {
        _ = lookahead.next();
        while (lookahead.peek().token_type == .ident) _ = lookahead.next();
        if (lookahead.next().token_type != .right_bracket) return error.Invalid;
    }
    if (lookahead.peek().token_type != .string) {
        result.rows = try axis(options, stream, .template);
        if (!takeSlash(stream)) return error.Invalid;
        result.columns = try axis(options, stream, .template);
        return result;
    }

    const rows = try Tracks.create(options.allocator);
    result.rows = .{ .grid_tracks = rows };
    const areas = try Areas.create(options.allocator);
    result.areas = .{ .grid_areas = areas };
    var parser = Parser{ .owner = rows, .options = options, .stream = stream };
    var area_parser = AreaParser{ .owner = areas };
    defer area_parser.deinit(options.allocator);
    var items: std.ArrayList(Item) = .empty;
    const allocator = rows.arena.allocator();
    while (true) {
        if (stream.peek().token_type == .left_bracket) try appendNames(allocator, &items, try parser.names());
        try area_parser.row(stream.next());
        const token = stream.peek();
        const omitted = token.token_type == .string or token.token_type == .left_bracket or token.token_type == .eof or @import("grid_values.zig").slash(token);
        const size: Track = if (omitted) .{ .breadth = .{ .intrinsic = .auto } } else try parser.track();
        try items.append(allocator, .{ .track = size });
        if (stream.peek().token_type == .left_bracket) try appendNames(allocator, &items, try parser.names());
        if (stream.atEnd() or @import("grid_values.zig").slash(stream.peek())) break;
    }
    rows.items = items.items;
    if (takeSlash(stream)) result.columns = try axis(options, stream, .explicit);
    return result;
}

fn appendNames(allocator: Allocator, items: *std.ArrayList(Item), names: []const []const u8) Allocator.Error!void {
    if (names.len == 0) return;
    if (items.items.len != 0 and items.items[items.items.len - 1] == .names) {
        const previous = &items.items[items.items.len - 1].names;
        const combined = try allocator.alloc([]const u8, previous.len + names.len);
        @memcpy(combined[0..previous.len], previous.*);
        @memcpy(combined[previous.len..], names);
        previous.* = combined;
    } else try items.append(allocator, .{ .names = names });
}

/// Grid 2 §7.7's default row is omitted only alongside dense.
pub const Flow = struct {
    column: bool = false,
    dense: bool = false,

    pub fn consume(stream: *Stream) ?Flow {
        var result = Flow{};
        var direction = false;
        var any = false;
        while (true) {
            const token = stream.peek();
            if (keyword(token, "row") or keyword(token, "column")) {
                if (direction) return null;
                direction = true;
                result.column = keyword(token, "column");
            } else if (keyword(token, "dense")) {
                if (result.dense) return null;
                result.dense = true;
            } else break;
            any = true;
            _ = stream.next();
        }
        return if (any) result else null;
    }
    pub fn serialize(self: Flow, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self.column) try out.appendSlice(allocator, if (self.dense) "column dense" else "column") else try out.appendSlice(allocator, if (self.dense) "dense" else "row");
    }
};

pub const Grid = struct {
    template: Template = .{},
    auto_rows: values.Value = .kw(.auto),
    auto_columns: values.Value = .kw(.auto),
    flow: Flow = .{},

    pub fn deinit(self: Grid) void {
        self.template.deinit();
        self.auto_rows.release();
        self.auto_columns.release();
    }
};

fn autoFlow(stream: *Stream) error{Invalid}!?bool {
    const dense_first = takeKeyword(stream, "dense");
    if (!takeKeyword(stream, "auto-flow")) {
        if (dense_first) return error.Invalid;
        return null;
    }
    return dense_first or takeKeyword(stream, "dense");
}

pub fn consumeGrid(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Grid {
    return grid(options, stream) catch |err| switch (err) {
        error.Invalid => null,
        error.OutOfMemory => error.OutOfMemory,
    };
}

fn grid(options: properties.ParseOptions, stream: *Stream) Error!Grid {
    const start = stream.*;
    var result = Grid{};
    errdefer result.deinit();
    if (try autoFlow(stream)) |dense| {
        result.flow.dense = dense;
        if (!@import("grid_values.zig").slash(stream.peek())) result.auto_rows = try axis(options, stream, .automatic);
        if (!takeSlash(stream)) return error.Invalid;
        result.template.columns = try axis(options, stream, .template);
        return result;
    }
    // The right-side auto-flow form cannot contain template strings. Probe
    // a complete left axis, then rewind for the full template grammar.
    const left: ?values.Value = axis(options, stream, .template) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.Invalid => null,
    };
    if (left) |rows| {
        result.template.rows = rows;
        if (takeSlash(stream)) if (try autoFlow(stream)) |dense| {
            result.flow = .{ .column = true, .dense = dense };
            if (!stream.atEnd()) result.auto_columns = try axis(options, stream, .automatic);
            return result;
        };
        result.template.rows.release();
        result.template.rows = .kw(.none);
    }
    stream.* = start;
    result.template = try template(options, stream);
    return result;
}

fn none(value: values.Value) bool {
    return value == .keyword and value.keyword == .none;
}

fn autoTracks(value: values.Value) bool {
    if (value == .keyword) return value.keyword == .auto;
    if (value != .grid_tracks) return false;
    const tracks = value.grid_tracks;
    return !tracks.subgrid and tracks.items.len == 1 and tracks.items[0] == .track and tracks.items[0].track.isAuto();
}

fn explicit(tracks: *const Tracks) bool {
    if (tracks.subgrid) return false;
    for (tracks.items) |item| if (item == .repeat) return false;
    return true;
}

/// Grid 2 §7.4 + CSSOM: only serialize a shorthand that parses back to all
/// three input longhands. The area form pairs each string with one row size.
pub fn serializeTemplate(value: Template, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    if (none(value.areas)) {
        if (none(value.rows) and none(value.columns)) {
            try out.appendSlice(allocator, "none");
            return true;
        }
        try properties.serializeValue(.grid_template_rows, value.rows, out, allocator);
        try out.appendSlice(allocator, " / ");
        try properties.serializeValue(.grid_template_columns, value.columns, out, allocator);
        return true;
    }
    if (value.areas != .grid_areas or value.rows != .grid_tracks or !explicit(value.rows.grid_tracks)) return false;
    if (!none(value.columns) and (value.columns != .grid_tracks or !explicit(value.columns.grid_tracks))) return false;
    const rows = value.rows.grid_tracks;
    var count: usize = 0;
    for (rows.items) |item| if (item == .track) {
        count += 1;
    };
    if (count != value.areas.grid_areas.rows.len) return false;
    var row: usize = 0;
    for (rows.items, 0..) |item, i| {
        if (i != 0) try out.append(allocator, ' ');
        switch (item) {
            .names => |names| try serializeNames(names, out, allocator),
            .track => |size| {
                try values.appendString(value.areas.grid_areas.rows[row], out, allocator);
                row += 1;
                if (!size.isAuto()) {
                    try out.append(allocator, ' ');
                    try size.serialize(out, allocator);
                }
            },
            .repeat => unreachable,
        }
    }
    if (!none(value.columns)) {
        try out.appendSlice(allocator, " / ");
        try properties.serializeValue(.grid_template_columns, value.columns, out, allocator);
    }
    return true;
}

/// Grid 2 §7.8: prefer grid-template whenever implicit properties are initial;
/// otherwise select the only auto-flow production that can round-trip.
pub fn serializeGrid(value: Grid, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    if (!value.flow.column and !value.flow.dense and autoTracks(value.auto_rows) and autoTracks(value.auto_columns)) return serializeTemplate(value.template, out, allocator);
    if (!none(value.template.areas)) return false;
    if (value.flow.column) {
        if (!none(value.template.columns) or !autoTracks(value.auto_rows)) return false;
        try properties.serializeValue(.grid_template_rows, value.template.rows, out, allocator);
        try out.appendSlice(allocator, " / auto-flow");
        if (value.flow.dense) try out.appendSlice(allocator, " dense");
        if (!autoTracks(value.auto_columns)) {
            try out.append(allocator, ' ');
            try properties.serializeValue(.grid_auto_columns, value.auto_columns, out, allocator);
        }
    } else {
        if (!none(value.template.rows) or !autoTracks(value.auto_columns)) return false;
        try out.appendSlice(allocator, "auto-flow");
        if (value.flow.dense) try out.appendSlice(allocator, " dense");
        if (!autoTracks(value.auto_rows)) {
            try out.append(allocator, ' ');
            try properties.serializeValue(.grid_auto_rows, value.auto_rows, out, allocator);
        }
        try out.appendSlice(allocator, " / ");
        try properties.serializeValue(.grid_template_columns, value.template.columns, out, allocator);
    }
    return true;
}
