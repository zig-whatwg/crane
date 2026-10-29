//! CSS Grid 2 §§8.3–8.4: typed grid lines, without layout placement.
//! Design reference: Blink css_parsing_utils::ConsumeGridLine keeps an
//! integer calculation separate from the optional case-sensitive name.
const std = @import("std");
const properties = @import("properties.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Allocator = std.mem.Allocator;

pub const Line = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    span: bool,
    name: []u8,
    count: ?Count,

    const Count = union(enum) {
        integer: i32,
        calculation: *math.Expression,

        fn ref(self: Count) void {
            if (self == .calculation) self.calculation.ref();
        }
        fn unref(self: Count) void {
            if (self == .calculation) self.calculation.unref();
        }
        fn eql(a: Count, b: Count) bool {
            if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
            return switch (a) {
                .integer => |n| n == b.integer,
                .calculation => |c| c.eql(b.calculation),
            };
        }
    };

    /// Copies the name and retains a calculation; inputs stay borrowed.
    fn create(allocator: Allocator, span: bool, name: []const u8, count: ?Count) Allocator.Error!*Line {
        const result = try allocator.create(Line);
        errdefer allocator.destroy(result);
        var normalized = count;
        // §8.3: span's omitted integer is one, but a bare named line and
        // `1 name` have different placement semantics and stay distinct.
        if (span and name.len != 0) if (count) |n| {
            if (n == .integer and n.integer == 1) normalized = null;
        };
        result.* = .{ .allocator = allocator, .span = span, .name = try allocator.dupe(u8, name), .count = normalized };
        if (normalized) |n| n.ref();
        return result;
    }

    pub fn ref(self: *Line) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Line) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.count) |n| n.unref();
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    pub fn eql(a: *const Line, b: *const Line) bool {
        if (a == b) return true;
        if (a.span != b.span or !std.mem.eql(u8, a.name, b.name)) return false;
        if (a.count) |n| return if (b.count) |other| n.eql(other) else false;
        return b.count == null;
    }

    pub fn isCustomIdent(self: *const Line) bool {
        return !self.span and self.count == null;
    }

    pub fn needsUnavailableMetrics(self: *const Line) bool {
        const count = self.count orelse return false;
        return count == .calculation and count.calculation.needsUnavailableMetrics(false);
    }
    pub fn needsTreeCounts(self: *const Line) bool {
        const count = self.count orelse return false;
        return count == .calculation and count.calculation.needsTreeCounts();
    }

    pub fn needsRandomBase(self: *const Line) bool {
        const count = self.count orelse return false;
        return count == .calculation and count.calculation.needsRandomBase();
    }

    pub fn compute(self: *Line, allocator: Allocator, context: math.Context) Allocator.Error!*Line {
        const count = self.count orelse {
            self.ref();
            return self;
        };
        if (count != .calculation) {
            self.ref();
            return self;
        }
        const expression = try count.calculation.compute(allocator, context);
        defer expression.unref();
        if (expression.computedNumber()) |number| {
            // Values 4 §10.12: clamp to the grammar's allowed range after
            // rounding. Zero lies between the two non-span integer ranges;
            // the equidistant positive value wins.
            const n: i32 = @intFromFloat(number.value);
            return create(allocator, self.span, self.name, .{ .integer = if (n == 0) 1 else n });
        }
        return create(allocator, self.span, self.name, .{ .calculation = expression });
    }

    pub fn serialize(self: *const Line, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        var wrote = false;
        if (self.span) {
            try out.appendSlice(allocator, "span");
            wrote = true;
        }
        if (self.count) |n| {
            if (wrote) try out.append(allocator, ' ');
            switch (n) {
                .integer => |integer| try out.print(allocator, "{d}", .{integer}),
                .calculation => |expression| try expression.serialize(out, allocator),
            }
            wrote = true;
        }
        if (self.name.len != 0) {
            if (wrote) try out.append(allocator, ' ');
            const escaped = try @import("serialize.zig").serializeIdentifier(allocator, self.name);
            defer allocator.free(escaped);
            try out.appendSlice(allocator, escaped);
        }
    }

    pub fn consume(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?*Line {
        const allocator = options.allocator;
        var name: ?[]u8 = null;
        defer if (name) |n| allocator.free(n);
        var count: ?Count = null;
        defer if (count) |n| n.unref();
        var span_at: ?usize = null;
        var components: usize = 0;
        while (!stream.atEnd() and !slash(stream.peek())) : (components += 1) {
            if (components == 3) return null;
            const token = stream.peek();
            if (token.token_type == .ident) {
                _ = stream.next();
                if (tokens.nameEql(token.value, "span")) {
                    if (span_at != null) return null;
                    span_at = components;
                    continue;
                }
                if (name != null) return null;
                name = try tokens.decode(allocator, token.value);
                if (std.ascii.eqlIgnoreCase(name.?, "auto") or std.ascii.eqlIgnoreCase(name.?, "default") or
                    @import("style_values.zig").CssWide.parse(name.?) != null) return null;
            } else if (token.token_type == .number) {
                if (count != null or !token.is_integer) return null;
                const n = token.numeric_value orelse return null;
                _ = stream.next();
                count = .{ .integer = @intFromFloat(std.math.clamp(n, @as(f64, std.math.minInt(i32)), @as(f64, std.math.maxInt(i32)))) };
            } else if (math.isFunction(token)) {
                if (count != null) return null;
                const value = try properties.mathValue(options, stream, .{ .kind = .integer, .minimum = std.math.minInt(i32), .maximum = std.math.maxInt(i32), .minimum_kind = .representation, .maximum_kind = .representation }) orelse return null;
                count = .{ .calculation = value.calculation };
            } else return null;
        }
        if (name == null and count == null) return null;
        // Browser consensus (all three grid-area-invalid WPTs): span may
        // precede or follow the integer/name group, never split that group.
        if (span_at) |at| if (at != 0 and at != components - 1) return null;
        if (count) |n| switch (n) {
            .integer => |integer| if (integer == 0 or (span_at != null and integer < 0)) return null,
            .calculation => |expression| if (span_at != null) {
                // This expression is fresh and has not escaped this parser.
                expression.grammar.minimum = 1;
                expression.grammar.minimum_kind = .grammar;
            },
        };
        return create(allocator, span_at != null, name orelse "", count);
    }
};

pub fn slash(token: tokens.Token) bool {
    return token.token_type == .delim and std.mem.eql(u8, token.value, "/");
}

/// Grid 2 §8.4's omitted placement value; the caller decides ownership.
pub fn omitted(first: @import("style_values.zig").Value) @import("style_values.zig").Value {
    return if (first == .grid_line and first.grid_line.isCustomIdent()) first else .kw(.auto);
}
