//! Custom properties (CSS Variables 1 §2): their specified values in a
//! declaration block, and their computed values on a ComputedStyle.
//!
//! A custom property's value is token text. Specified, it is the original
//! text (`Text`), a CSS-wide keyword, or - when it holds an arbitrary
//! substitution function - a pending-substitution value (pending_values.zig,
//! no grammar). Computed, it is "the specified value with variables
//! substituted, or the guaranteed-invalid value": a `Text` again, so a
//! declaration without substitution shares its text with every element it
//! applies to.
//!
//! Computed values live in a `CustomProperties` record, reference-counted
//! and SHARED: an element whose cascade changes no custom property keeps its
//! parent's record, so an unchanged inherited map is never copied. A record
//! that changes values follows WebKit's Style::CustomPropertyData: it
//! references its parent record (lookup walks the chain) when the parent is
//! the root record or holds more than 8 values of its own, and copies the
//! parent's own values otherwise; a chain is at most 4 ancestors deep, so a
//! lookup visits at most 5 records (WebKit maximumAncestorCount).
//!
//! Spec: https://drafts.csswg.org/css-variables-1/#defining-variables
//! Spec: https://drafts.csswg.org/css-variables-1/#serializing-custom-props
const std = @import("std");
const Allocator = std.mem.Allocator;
const values = @import("style_values.zig");
const substitution = @import("substitution.zig");
const Pending = @import("pending_values.zig").Pending;

/// Reference-counted token text: a custom property's name or value. The
/// count is not atomic: every holder is on its Browser's thread
/// (docs/instances.md), as for style_values.SharedText.
pub const Text = struct {
    refs: u32 = 1,
    allocator: Allocator,
    bytes: []u8,
    /// CSS Values 5 §8.7.2: where substitution brought tainted tokens into
    /// a computed value (empty for every specified value).
    taint: []substitution.TaintRange = &.{},

    pub fn create(allocator: Allocator, bytes: []const u8) Allocator.Error!*Text {
        const self = try allocator.create(Text);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .bytes = try allocator.dupe(u8, bytes) };
        return self;
    }

    /// Takes `bytes` and `taint`, both owned by `allocator`, on success only.
    pub fn adopt(allocator: Allocator, bytes: []u8, taint: []substitution.TaintRange) Allocator.Error!*Text {
        const self = try allocator.create(Text);
        self.* = .{ .allocator = allocator, .bytes = bytes, .taint = taint };
        return self;
    }

    pub fn retain(self: *Text) void {
        self.refs += 1;
    }

    pub fn release(self: *Text) void {
        self.refs -= 1;
        if (self.refs != 0) return;
        self.allocator.free(self.bytes);
        if (self.taint.len != 0) self.allocator.free(self.taint);
        self.allocator.destroy(self);
    }

    pub fn eql(a: *const Text, b: *const Text) bool {
        if (a == b) return true;
        if (!std.mem.eql(u8, a.bytes, b.bytes)) return false;
        if (a.taint.len != b.taint.len) return false;
        for (a.taint, b.taint) |x, y| if (!std.meta.eql(x, y)) return false;
        return true;
    }

    pub fn computed(self: *const Text) substitution.Computed {
        return .{ .text = self.bytes, .taint = self.taint };
    }
};

/// A custom property declaration's value.
pub const Specified = union(enum) {
    /// CSS Variables 1 §2: "The CSS-wide keywords can be used in custom
    /// properties, with the same meaning as in any another property."
    css_wide: values.CssWide,
    /// A value with no arbitrary substitution function: its own computed
    /// value.
    text: *Text,
    /// A value with one (Values 5 Appendix A), substituted per element.
    pending: *Pending,

    pub fn retain(self: Specified) void {
        switch (self) {
            .css_wide => {},
            .text => |t| t.retain(),
            .pending => |p| p.ref(),
        }
    }

    pub fn release(self: Specified) void {
        switch (self) {
            .css_wide => {},
            .text => |t| t.release(),
            .pending => |p| p.unref(),
        }
    }

    pub fn eql(a: Specified, b: Specified) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .css_wide => |k| k == b.css_wide,
            .text => |t| t.eql(b.text),
            .pending => |p| p.eql(b.pending),
        };
    }

    /// CSS Variables 1 §4.1: "Specified values of custom properties must be
    /// serialized exactly as specified by the author ... [except that] an
    /// empty custom property (such as --foo:;) must serialize with a single
    /// space as its value" - setProperty() treats "" as removeProperty(), so
    /// "" would not round-trip (integrator Q2: the spec, which WPT carries in
    /// css/css-variables/variable-definition.html).
    pub fn serialize(self: Specified, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .css_wide => |k| try out.appendSlice(allocator, k.name()),
            .text => |t| try appendValue(t.bytes, out, allocator),
            .pending => |p| try appendValue(p.text, out, allocator),
        }
    }
};

/// A custom property value serialized (css-variables-1 §4.1's one
/// exception: the empty value is a single space).
pub fn appendValue(bytes: []const u8, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (bytes.len == 0) return out.append(allocator, ' ');
    try out.appendSlice(allocator, bytes);
}

/// CSS Variables 1 §2: a <custom-property-name> is any <dashed-ident>
/// except `--` itself, "reserved for future use by CSS". The rule parser
/// and CSSOM accept any name string starting with two dashes beyond that,
/// as all three browsers do (css/css-variables/variable-definition.html
/// "CSSOM.setProperty with space": Chrome 156, Firefox 158 and Safari 27 all
/// set "--varUnique2 ").
pub fn isName(name: []const u8) bool {
    return name.len > 2 and name[0] == '-' and name[1] == '-';
}

/// A custom property declaration's value parsed (CSS Variables 1 §2.1): a
/// CSS-wide keyword alone; else any <declaration-value>? whose arbitrary
/// substitution functions match their argument grammars (§2.1: "if the
/// value of a custom property contains a var() reference, the var()
/// reference must be valid according to the specified var() grammar. If
/// not, the custom property is invalid and must be ignored"). Null when
/// invalid. `text` is trimmed to its original text first.
pub fn parse(options: @import("properties.zig").ParseOptions, text: []const u8) Allocator.Error!?Specified {
    const source = substitution.originalText(text);
    if (cssWideKeyword(source)) |k| return .{ .css_wide = k };
    if (!@import("rules.zig").isDeclarationValue(source)) return null;
    // A url() keeps what it resolves to at parse time, while the sheet's
    // resolver is alive: a registered <url> or <image> computes against its
    // declaration's base (Properties and Values API 1 §2.4, "Relative
    // URLs"), and registrations may come after the sheet is parsed.
    if (substitution.mentionsFunction(source) or (options.url_resolver != null and mentionsUrl(source))) {
        const pending = try Pending.create(options, null, source) orelse return null;
        return .{ .pending = pending };
    }
    return .{ .text = try Text.create(options.allocator, source) };
}

/// Whether `text` holds a url (a url token, or a url()/src()/image-set()
/// function, whose strings are URLs).
fn mentionsUrl(text: []const u8) bool {
    const tokenizer_mod = @import("tokenizer.zig");
    var tokenizer = tokenizer_mod.Tokenizer.init(text);
    while (true) {
        const token = tokenizer.next();
        switch (token.token_type) {
            .eof => return false,
            .url => return true,
            .function => inline for (.{ "url", "src", "image-set", "-webkit-image-set" }) |name| {
                if (tokenizer_mod.nameEql(token.value, name)) return true;
            },
            else => {},
        }
    }
}

/// The CSS-wide keyword `text` is, alone (whitespace and comments around
/// it allowed), or null.
pub fn cssWideKeyword(text: []const u8) ?values.CssWide {
    var tokenizer = @import("tokenizer.zig").Tokenizer.init(text);
    tokenizer.skipWhitespace();
    const token = tokenizer.next();
    if (token.token_type != .ident) return null;
    tokenizer.skipWhitespace();
    if (tokenizer.next().token_type != .eof) return null;
    return values.CssWide.parse(token.value);
}

/// An element's computed custom properties, shared by reference (see the
/// file comment). Values are guaranteed-invalid when null: such an entry
/// hides an inherited value.
pub const CustomProperties = struct {
    /// Not atomic: a record is shared only between the computed styles of
    /// one Document's style engine, on its Browser's window-agent thread
    /// (the rule computed_style.zig's groups rest on; docs/instances.md).
    refs: u32 = 1,
    allocator: Allocator,
    parent: ?*CustomProperties = null,
    /// The number of records `parent` chains through.
    ancestors: u8 = 0,
    /// This record's own values, sorted by name (code units).
    entries: []Entry,

    pub const Entry = struct {
        name: *Text,
        value: ?*Text,
    };

    /// WebKit Style::CustomPropertyData's limits.
    pub const max_ancestors = 4;
    pub const reference_threshold = 8;

    /// A record of `changes` (sorted by name, unique) over `parent`'s values,
    /// each entry retained. The parent is referenced or flattened per the
    /// WebKit policy in the file comment.
    pub fn create(allocator: Allocator, parent: ?*CustomProperties, changes: []const Entry) Allocator.Error!*CustomProperties {
        const self = try allocator.create(CustomProperties);
        errdefer allocator.destroy(self);
        var base: ?*CustomProperties = parent;
        var inherited: []const Entry = &.{};
        if (parent) |p| {
            // "Always reference the root style since it likely gets shared a
            // lot"; limit the chain; copy small maps rather than link them.
            const reference = (p.parent == null and p.entries.len != 0) or
                (p.ancestors < max_ancestors and p.entries.len > reference_threshold);
            if (!reference) {
                base = p.parent;
                inherited = p.entries;
            }
        }
        const merged = try merge(allocator, inherited, changes);
        if (base) |b| b.retain();
        self.* = .{
            .allocator = allocator,
            .parent = base,
            .ancestors = if (base) |b| b.ancestors + 1 else 0,
            .entries = merged,
        };
        return self;
    }

    /// `a` and `b` (both sorted) merged, `b` winning a shared name; every
    /// entry retained.
    fn merge(allocator: Allocator, a: []const Entry, b: []const Entry) Allocator.Error![]Entry {
        var out: std.ArrayList(Entry) = try .initCapacity(allocator, a.len + b.len);
        errdefer out.deinit(allocator);
        var i: usize = 0;
        var j: usize = 0;
        while (i < a.len or j < b.len) {
            const take_b = i == a.len or (j < b.len and !lessThan(a[i].name.bytes, b[j].name.bytes));
            if (take_b) {
                if (i < a.len and std.mem.eql(u8, a[i].name.bytes, b[j].name.bytes)) i += 1;
                out.appendAssumeCapacity(b[j]);
                j += 1;
            } else {
                out.appendAssumeCapacity(a[i]);
                i += 1;
            }
        }
        const slice = try out.toOwnedSlice(allocator);
        for (slice) |e| {
            e.name.retain();
            if (e.value) |v| v.retain();
        }
        return slice;
    }

    pub fn retain(self: *CustomProperties) void {
        self.refs += 1;
    }

    pub fn release(self: *CustomProperties) void {
        self.refs -= 1;
        if (self.refs != 0) return;
        for (self.entries) |e| {
            e.name.release();
            if (e.value) |v| v.release();
        }
        self.allocator.free(self.entries);
        if (self.parent) |p| p.release();
        self.allocator.destroy(self);
    }

    pub const Lookup = union(enum) {
        /// No record in the chain sets the name: its initial value, the
        /// guaranteed-invalid value.
        absent,
        /// The guaranteed-invalid value, set by a record.
        invalid,
        value: *Text,
    };

    pub fn lookup(self: *const CustomProperties, name: []const u8) Lookup {
        var record: ?*const CustomProperties = self;
        while (record) |r| : (record = r.parent) {
            if (r.find(name)) |e| return if (e.value) |v| .{ .value = v } else .invalid;
        }
        return .absent;
    }

    /// The computed value of `name`, or null for the guaranteed-invalid value.
    pub fn get(self: *const CustomProperties, name: []const u8) ?*Text {
        return switch (self.lookup(name)) {
            .value => |v| v,
            else => null,
        };
    }

    fn find(self: *const CustomProperties, name: []const u8) ?*const Entry {
        var lo: usize = 0;
        var hi = self.entries.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            switch (std.mem.order(u8, self.entries[mid].name.bytes, name)) {
                .eq => return &self.entries[mid],
                .lt => lo = mid + 1,
                .gt => hi = mid,
            }
        }
        return null;
    }

    /// The names with a valid value, in code-point order (the integrator,
    /// Q3: getComputedStyle lists them after the longhands; guaranteed-
    /// invalid ones are not listed). Borrowed names, valid while the record
    /// is retained; the slice is the caller's.
    pub fn names(self: *const CustomProperties, allocator: Allocator) Allocator.Error![]const []const u8 {
        var out: std.ArrayList([]const u8) = .empty;
        errdefer out.deinit(allocator);
        var seen: std.ArrayList([]const u8) = .empty;
        defer seen.deinit(allocator);
        var record: ?*const CustomProperties = self;
        while (record) |r| : (record = r.parent) {
            for (r.entries) |e| {
                if (contains(seen.items, e.name.bytes)) continue;
                try seen.append(allocator, e.name.bytes);
                if (e.value != null) try out.append(allocator, e.name.bytes);
            }
        }
        std.mem.sort([]const u8, out.items, {}, struct {
            fn lt(_: void, a: []const u8, b: []const u8) bool {
                return lessThan(a, b);
            }
        }.lt);
        return out.toOwnedSlice(allocator);
    }

    fn contains(list: []const []const u8, name: []const u8) bool {
        for (list) |n| if (std.mem.eql(u8, n, name)) return true;
        return false;
    }
};

fn lessThan(a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}
