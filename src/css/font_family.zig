//! CSS Fonts4 §2.1 and CSS Shadow1 §4.2: owned, tree-scoped family names.
//! CSSOM serialization discards the scope but value equality preserves it.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
pub const TreeScopeRef = @FieldType(@import("cascade.zig").Source, "tree_scope");

pub const Generic = enum {
    serif,
    sans_serif,
    cursive,
    fantasy,
    monospace,
    system_ui,
    math,
    ui_serif,
    ui_sans_serif,
    ui_monospace,
    ui_rounded,

    pub fn name(self: Generic) []const u8 {
        return switch (self) {
            .sans_serif => "sans-serif",
            .system_ui => "system-ui",
            .ui_serif => "ui-serif",
            .ui_sans_serif => "ui-sans-serif",
            .ui_monospace => "ui-monospace",
            .ui_rounded => "ui-rounded",
            inline else => |g| @tagName(g),
        };
    }

    pub fn parse(text: []const u8) ?Generic {
        inline for (@typeInfo(Generic).@"enum".field_values) |field_value| {
            const g: Generic = @fromBackingInt(@intCast(field_value));
            if (std.ascii.eqlIgnoreCase(text, g.name())) return g;
        }
        return null;
    }
};

pub const FamilyRef = union(enum) {
    named: struct { name: []const u8, scope: TreeScopeRef = .{} },
    generic: Generic,

    pub fn eql(a: FamilyRef, b: FamilyRef) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .generic => |g| g == b.generic,
            .named => |n| n.scope.serial == b.named.scope.serial and std.mem.eql(u8, n.name, b.named.name),
        };
    }
};

pub const Families = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    items: []const FamilyRef,
    text: *values.SharedText,

    /// Copies every borrowed name. The caller's input is never consumed.
    pub fn create(allocator: Allocator, items: []const FamilyRef) Allocator.Error!*Families {
        std.debug.assert(items.len > 0);
        const owned = try allocator.alloc(FamilyRef, items.len);
        errdefer allocator.free(owned);
        var count: usize = 0;
        errdefer for (owned[0..count]) |item| if (item == .named) allocator.free(item.named.name);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        while (count < items.len) {
            const item = items[count];
            owned[count] = switch (item) {
                .generic => item,
                .named => |n| .{ .named = .{ .name = try allocator.dupe(u8, n.name), .scope = n.scope } },
            };
            count += 1;
            if (count > 1) try out.appendSlice(allocator, ", ");
            switch (item) {
                .generic => |g| try out.appendSlice(allocator, g.name()),
                .named => |n| if (canUnquote(n.name))
                    try out.appendSlice(allocator, n.name)
                else
                    try values.appendString(n.name, &out, allocator),
            }
        }
        const text = try values.SharedText.create(allocator, out.items);
        errdefer text.unref();
        const result = try allocator.create(Families);
        result.* = .{ .allocator = allocator, .items = owned, .text = text };
        return result;
    }

    pub fn ref(self: *Families) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *Families) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.items) |item| if (item == .named) self.allocator.free(item.named.name);
        self.allocator.free(self.items);
        self.text.unref();
        self.allocator.destroy(self);
    }

    pub fn eql(self: *const Families, other: *const Families) bool {
        if (self == other) return true;
        if (self.items.len != other.items.len) return false;
        for (self.items, other.items) |a, b| if (!a.eql(b)) return false;
        return true;
    }

    /// Shadow1 §4.2: capture the winning declaration's tree at computation.
    /// The cascade inherits the resulting value directly, without recapture.
    pub fn capture(self: *Families, allocator: Allocator, scope: TreeScopeRef) Allocator.Error!*Families {
        var different = false;
        for (self.items) |item| if (item == .named and item.named.scope.serial != scope.serial) {
            different = true;
            break;
        };
        if (!different) {
            self.ref();
            return self;
        }
        const scoped = try allocator.dupe(FamilyRef, self.items);
        defer allocator.free(scoped);
        for (scoped) |*item| if (item.* == .named) {
            item.named.scope = scope;
        };
        return create(allocator, scoped);
    }
};

fn reserved(text: []const u8) bool {
    return values.CssWide.parse(text) != null or std.ascii.eqlIgnoreCase(text, "default");
}

/// Fonts4 / CSSOM: optional quotes are omitted for an unchanged ident list.
/// Q40: CSS-wide words anywhere keep quotes (Chrome/Safari); a generic is
/// reserved only at the beginning (Firefox/Safari omit quotes in Foo serif).
fn canUnquote(name: []const u8) bool {
    var words = std.mem.splitScalar(u8, name, ' ');
    var first = true;
    while (words.next()) |word| {
        if (word.len == 0 or reserved(word)) return false;
        if (first and Generic.parse(word) != null) return false;
        first = false;
        const start: usize = if (word[0] == '-') 1 else 0;
        if (start == word.len) return false;
        if (!(word[start] >= 0x80 or std.ascii.isAlphabetic(word[start]) or word[start] == '_' or (start == 1 and word[start] == '-'))) return false;
        for (word) |byte| if (!(byte >= 0x80 or std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_')) return false;
    }
    return !first;
}

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    const allocator = options.allocator;
    var items: std.ArrayList(FamilyRef) = .empty;
    defer {
        for (items.items) |item| if (item == .named) allocator.free(item.named.name);
        items.deinit(allocator);
    }
    while (true) {
        const first = stream.peek();
        const family: FamilyRef = switch (first.token_type) {
            .string => blk: {
                _ = stream.next();
                break :blk .{ .named = .{ .name = try tokenizer.decode(allocator, first.stringContents()) } };
            },
            .ident => blk: {
                var name: std.ArrayList(u8) = .empty;
                defer name.deinit(allocator);
                var generic: ?Generic = null;
                var words: usize = 0;
                while (stream.peek().token_type == .ident) : (words += 1) {
                    const token = stream.next();
                    const decoded = try tokenizer.decode(allocator, token.value);
                    defer allocator.free(decoded);
                    if (words == 0) generic = Generic.parse(decoded) else {
                        // Q40: leading generic + another word is invalid.
                        if (generic != null) return null;
                        try name.append(allocator, ' ');
                    }
                    try name.appendSlice(allocator, decoded);
                }
                if (generic) |g| break :blk .{ .generic = g };
                // Q40: reserved words inside a multiword family are valid.
                if (words == 1 and reserved(name.items)) return null;
                break :blk .{ .named = .{ .name = try name.toOwnedSlice(allocator) } };
            },
            else => return null,
        };
        errdefer if (family == .named) allocator.free(family.named.name);
        try items.append(allocator, family);
        if (stream.peek().token_type != .comma) break;
        _ = stream.next();
    }
    return .{ .font_family = try Families.create(allocator, items.items) };
}
