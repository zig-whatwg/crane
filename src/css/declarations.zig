//! A CSS declaration block (CSSOM 6.6): the declarations of a style rule
//! or of an element's style attribute, and the CSSOM algorithms over them.
//!
//! A block normally holds longhands - a shorthand is expanded when it is set
//! (Cascade 5 section 3) and coalesced again when the block is serialized
//! ("serialize a CSS declaration block"). A declaration of a property Crane
//! does not support is kept as written, for read-back only (stated, design
//! section 6.2, ruling Q7): CSSOM returns it, the cascade never sees it.
//! A declaration with var(), env() or random-item() is a pending-substitution
//! value of each longhand it sets (Values 5 Appendix A, pending_values.zig);
//! a custom property declaration is a `.custom` entry (CSS Variables 1).
//!
//! Spec: https://drafts.csswg.org/cssom-1/#css-declaration-blocks
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssstyledeclaration-interface

const std = @import("std");
const Allocator = std.mem.Allocator;
const properties = @import("properties.zig");
const rules = @import("rules.zig");
const values = @import("style_values.zig");
const custom_properties = @import("custom_properties.zig");

const Longhand = properties.Longhand;
const Shorthand = properties.Shorthand;
const Property = properties.Property;
const Assigned = properties.Assigned;
const Assignment = properties.Assignment;

/// One CSS declaration of a supported longhand.
pub const Declaration = struct {
    longhand: Longhand,
    value: Assigned,
    important: bool,
};

/// A declaration of a property Crane does not support, as written.
pub const Unparsed = struct {
    /// Lowercased unless a custom property.
    name: []u8,
    value: []u8,
    important: bool,
};

/// A custom property declaration (CSS Variables 1 §2): its case-sensitive
/// name and its value, both shared by reference with the computed styles
/// they reach.
pub const Custom = struct {
    name: *custom_properties.Text,
    value: custom_properties.Specified,
    important: bool,
};

pub const Entry = union(enum) {
    typed: Declaration,
    unparsed: Unparsed,
    custom: Custom,

    pub fn name(self: *const Entry) []const u8 {
        return switch (self.*) {
            .typed => |d| d.longhand.name(),
            .unparsed => |u| u.name,
            .custom => |c| c.name.bytes,
        };
    }

    pub fn important(self: *const Entry) bool {
        return switch (self.*) {
            .typed => |d| d.important,
            .unparsed => |u| u.important,
            .custom => |c| c.important,
        };
    }
};

pub const DeclarationBlock = struct {
    allocator: Allocator,
    /// Anchor Position 1 §6.4 limits position-try descriptors at every
    /// entry point, including later CSSOM mutation. Ordinary blocks keep
    /// their existing property and unsupported-descriptor behavior.
    context: Context = .style,
    /// CSSOM "declarations", in order.
    entries: std.ArrayList(Entry) = .empty,
    /// The number of custom property declarations: the cascade looks for
    /// them only in a block that has some.
    custom_count: u32 = 0,

    pub const Context = enum {
        style,
        position_try,
        keyframe,

        fn allows(self: Context, property: Property, important: bool) bool {
            if (self == .style) return true;
            if (important) return false;
            const longhands: []const Longhand = switch (property) {
                .longhand => |l| &.{l},
                .shorthand => |s| s.longhands(),
            };
            for (longhands) |l| {
                if (self == .keyframe) {
                    if (!keyframePropertyAllowed(l.name())) return false;
                } else if (!position_try_properties.has(l.name())) return false;
            }
            return true;
        }
    };

    // Animations 1 §3 and Animations 2 §4.10 permit timing-function and
    // composition inside keyframes, but none of the other animation controls.
    fn keyframePropertyAllowed(name: []const u8) bool {
        if (std.ascii.eqlIgnoreCase(name, "animation-timing-function") or
            std.ascii.eqlIgnoreCase(name, "animation-composition")) return true;
        return !std.ascii.eqlIgnoreCase(name, "animation") and !std.ascii.startsWithIgnoreCase(name, "animation-");
    }

    const position_try_properties = std.StaticStringMap(void).initComptime(.{
        .{ "top", {} },                .{ "right", {} },            .{ "bottom", {} },              .{ "left", {} },
        .{ "inset-block-start", {} },  .{ "inset-block-end", {} },  .{ "inset-inline-start", {} },  .{ "inset-inline-end", {} },
        .{ "margin-top", {} },         .{ "margin-right", {} },     .{ "margin-bottom", {} },       .{ "margin-left", {} },
        .{ "margin-block-start", {} }, .{ "margin-block-end", {} }, .{ "margin-inline-start", {} }, .{ "margin-inline-end", {} },
        .{ "width", {} },              .{ "min-width", {} },        .{ "max-width", {} },           .{ "height", {} },
        .{ "min-height", {} },         .{ "max-height", {} },       .{ "block-size", {} },          .{ "min-block-size", {} },
        .{ "max-block-size", {} },     .{ "inline-size", {} },      .{ "min-inline-size", {} },     .{ "max-inline-size", {} },
        .{ "align-self", {} },         .{ "justify-self", {} },     .{ "position-anchor", {} },     .{ "position-area", {} },
    });

    pub fn init(allocator: Allocator) DeclarationBlock {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *DeclarationBlock) void {
        self.clear();
        self.entries.deinit(self.allocator);
    }

    /// Empty the declarations.
    pub fn clear(self: *DeclarationBlock) void {
        for (self.entries.items) |*e| self.freeEntry(e);
        self.entries.clearRetainingCapacity();
        std.debug.assert(self.custom_count == 0);
    }

    fn freeEntry(self: *DeclarationBlock, e: *Entry) void {
        switch (e.*) {
            .typed => |d| d.value.release(),
            .unparsed => |u| {
                self.allocator.free(u.name);
                self.allocator.free(u.value);
            },
            .custom => |c| {
                c.name.release();
                c.value.release();
                self.custom_count -= 1;
            },
        }
    }

    /// CSSOM "parse a CSS declaration block" from `text` (a style
    /// attribute's value, a cssText). `options.allocator` is the block's.
    pub fn parse(options: properties.ParseOptions, text: []const u8) Allocator.Error!DeclarationBlock {
        return parseInContext(options, text, .style);
    }

    pub fn parseInContext(options: properties.ParseOptions, text: []const u8, context: Context) Allocator.Error!DeclarationBlock {
        const parsed = try rules.parseDeclarationList(options.allocator, text);
        defer rules.freeDeclarationList(options.allocator, parsed);
        return fromDeclarationsInContext(options, parsed, context);
    }

    /// A block from a rule's parsed declarations: each property's grammar
    /// applied, an invalid declaration dropped.
    pub fn fromDeclarations(options: properties.ParseOptions, parsed: []const rules.Declaration) Allocator.Error!DeclarationBlock {
        return fromDeclarationsInContext(options, parsed, .style);
    }

    pub fn fromDeclarationsInContext(options: properties.ParseOptions, parsed: []const rules.Declaration, context: Context) Allocator.Error!DeclarationBlock {
        var block = DeclarationBlock.init(options.allocator);
        block.context = context;
        errdefer block.deinit();
        for (parsed) |d| try block.addParsed(options, d.name, d.value, d.important);
        return block;
    }

    /// One parsed declaration into the block. A later declaration of a
    /// longhand replaces an earlier one, and moves to the end - unless the
    /// earlier is important and the later is not, which the cascade's
    /// order would make lose anyway (Blink's parsed declaration sets do the
    /// same).
    fn addParsed(self: *DeclarationBlock, options: properties.ParseOptions, name: []const u8, value_text: []const u8, important: bool) Allocator.Error!void {
        if (std.mem.startsWith(u8, name, "--")) return self.addCustom(options, name, value_text, important);
        const property = properties.lookup(name) orelse {
            if (self.context == .position_try) return;
            if (self.context == .keyframe and (important or !keyframePropertyAllowed(name))) return;
            try self.setUnparsed(name, value_text, important);
            return;
        };
        if (!self.context.allows(property, important)) return;
        var assignments: std.ArrayList(Assignment) = .empty;
        defer assignments.deinit(self.allocator);
        if (!try properties.parseDeclaration(options, property, value_text, &assignments)) return;
        var consumed: usize = 0;
        defer for (assignments.items[consumed..]) |a| a.value.release();
        for (assignments.items) |a| {
            const previous = self.indexOf(a.longhand);
            if (previous) |i| {
                if (self.entries.items[i].important() and !important) {
                    a.value.release();
                    consumed += 1;
                    continue;
                }
            }
            if (previous) |i| {
                var old = self.entries.orderedRemove(i);
                self.freeEntry(&old);
            }
            try self.entries.append(self.allocator, .{ .typed = .{ .longhand = a.longhand, .value = a.value, .important = important } });
            consumed += 1;
        }
    }

    fn setUnparsed(self: *DeclarationBlock, name: []const u8, value_text: []const u8, important: bool) Allocator.Error!void {
        if (rules.declarationValueHasBadToken(value_text)) return;
        const custom = std.mem.startsWith(u8, name, "--");
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        if (!custom) _ = std.ascii.lowerString(name_copy, name_copy);
        const value_copy = try self.allocator.dupe(u8, std.mem.trim(u8, value_text, " \t\n\r\x0c"));
        errdefer self.allocator.free(value_copy);
        if (self.indexOfName(name_copy)) |i| {
            var old = self.entries.orderedRemove(i);
            self.freeEntry(&old);
        }
        try self.entries.append(self.allocator, .{ .unparsed = .{ .name = name_copy, .value = value_copy, .important = important } });
    }

    /// A parsed custom property declaration (CSS Variables 1 §2). Invalid
    /// values and the reserved name `--` are dropped. Like a longhand, a
    /// later declaration replaces an earlier one and moves to the end -
    /// unless the earlier is important and the later is not (Blink's parsed
    /// declaration sets; css-variables variable-definition.html "!important
    /// 2"). Not in @position-try (Anchor Position 1 §6.4 lists its
    /// properties); in @keyframes only without !important.
    fn addCustom(self: *DeclarationBlock, options: properties.ParseOptions, name: []const u8, value_text: []const u8, important: bool) Allocator.Error!void {
        if (!custom_properties.isName(name)) return;
        switch (self.context) {
            .style => {},
            .position_try => return,
            .keyframe => if (important) return,
        }
        if (self.indexOfCustom(name)) |i| if (self.entries.items[i].custom.important and !important) return;
        const value = try custom_properties.parse(options, value_text) orelse return;
        errdefer value.release();
        const name_text = try custom_properties.Text.create(self.allocator, name);
        errdefer name_text.release();
        try self.entries.ensureUnusedCapacity(self.allocator, 1);
        if (self.indexOfCustom(name)) |i| {
            var old = self.entries.orderedRemove(i);
            self.freeEntry(&old);
        }
        self.entries.appendAssumeCapacity(.{ .custom = .{ .name = name_text, .value = value, .important = important } });
        self.custom_count += 1;
    }

    /// setProperty() of a custom property (CSSOM 6.6.1 steps 5-9): the value
    /// parsed; "set a CSS declaration" replaces it in place, whatever its
    /// importance. True when the block changed.
    fn setCustom(self: *DeclarationBlock, options: properties.ParseOptions, name: []const u8, value_text: []const u8, important: bool) Allocator.Error!bool {
        if (!custom_properties.isName(name)) return false;
        switch (self.context) {
            .style => {},
            .position_try => return false,
            .keyframe => if (important) return false,
        }
        const value = try custom_properties.parse(options, value_text) orelse return false;
        if (self.indexOfCustom(name)) |i| {
            const existing = &self.entries.items[i].custom;
            if (existing.important == important and existing.value.eql(value)) {
                value.release();
                return false;
            }
            existing.value.release();
            existing.value = value;
            existing.important = important;
            return true;
        }
        errdefer value.release();
        const name_text = try custom_properties.Text.create(self.allocator, name);
        errdefer name_text.release();
        try self.entries.append(self.allocator, .{ .custom = .{ .name = name_text, .value = value, .important = important } });
        self.custom_count += 1;
        return true;
    }

    fn indexOfCustom(self: *const DeclarationBlock, name: []const u8) ?usize {
        if (self.custom_count == 0) return null;
        for (self.entries.items, 0..) |e, i| switch (e) {
            .custom => |c| if (std.mem.eql(u8, c.name.bytes, name)) return i,
            else => {},
        };
        return null;
    }

    /// The custom property declaration named `name` (case-sensitively).
    pub fn getCustom(self: *const DeclarationBlock, name: []const u8) ?*const Custom {
        const i = self.indexOfCustom(name) orelse return null;
        return &self.entries.items[i].custom;
    }

    pub fn indexOf(self: *const DeclarationBlock, l: Longhand) ?usize {
        for (self.entries.items, 0..) |e, i| switch (e) {
            .typed => |d| if (d.longhand == l) return i,
            .unparsed, .custom => {},
        };
        return null;
    }

    fn indexOfName(self: *const DeclarationBlock, name: []const u8) ?usize {
        for (self.entries.items, 0..) |e, i| switch (e) {
            .typed, .custom => {},
            .unparsed => |u| if (std.mem.eql(u8, u.name, name)) return i,
        };
        return null;
    }

    pub fn get(self: *const DeclarationBlock, l: Longhand) ?*const Declaration {
        const i = self.indexOf(l) orelse return null;
        return &self.entries.items[i].typed;
    }

    /// The number of declarations (CSSOM `length`).
    pub fn length(self: *const DeclarationBlock) usize {
        return self.entries.items.len;
    }

    /// The property name of the declaration at `index` (CSSOM `item()`).
    pub fn item(self: *const DeclarationBlock, index: usize) ?[]const u8 {
        if (index >= self.entries.items.len) return null;
        return self.entries.items[index].name();
    }

    // ------------------------------------------------------------------------
    // CSSOM 6.6.1 algorithms
    // ------------------------------------------------------------------------

    /// getPropertyValue(property), appended to `out`.
    pub fn getPropertyValue(self: *const DeclarationBlock, property_name: []const u8, out: *std.ArrayList(u8)) Allocator.Error!void {
        // 3. A custom property's declaration, by a case-sensitive match
        //    (CSS Variables 1 §4: custom property declarations have the
        //    case-sensitive flag set).
        if (std.mem.startsWith(u8, property_name, "--")) {
            if (self.getCustom(property_name)) |c| try c.value.serialize(out, self.allocator);
            return;
        }
        // 1. "If property is not a custom property, follow these substeps:
        //    Let property be property converted to ASCII lowercase."
        const property = properties.lookup(property_name) orelse {
            const i = self.indexOfNameInsensitive(property_name) orelse return;
            try out.appendSlice(self.allocator, self.entries.items[i].unparsed.value);
            return;
        };
        switch (property) {
            // 2. "If property is a shorthand property, then follow these
            //    substeps": each longhand's declaration, or ""; one
            //    importance, or "".
            .shorthand => |s| {
                var vs: [properties.max_assignments]Assigned = undefined;
                var important: ?bool = null;
                for (s.longhands(), 0..) |l, i| {
                    const d = self.get(l) orelse return;
                    // CSSOM getPropertyValue steps 1.2.2–1.2.3: serialize
                    // the shorthand from its longhands. Pending system-font
                    // members have no serializable longhand value here.
                    // Q200, tmp/analysis/integrator-probes-1024d: the coupled
                    // longhand/getter rule follows Safari; cssText is separate.
                    if (s == .font_variant and d.value == .value and d.value.value == .font_system) return;
                    if (important) |imp| if (imp != d.important) return;
                    important = d.important;
                    vs[i] = d.value;
                }
                const start = out.items.len;
                if (!try properties.serializeShorthand(s, vs[0..s.longhands().len], .specified, out, self.allocator)) out.shrinkRetainingCapacity(start);
            },
            // 3. "If property is a case-sensitive match for a property name
            //    of a CSS declaration in the declarations, then return the
            //    result of invoking serialize a CSS value of that
            //    declaration." 4. "Return the empty string."
            .longhand => |l| if (self.get(l)) |d| try properties.serializeAssigned(l, d.value, out, self.allocator),
        }
    }

    fn indexOfNameInsensitive(self: *const DeclarationBlock, name: []const u8) ?usize {
        const custom = std.mem.startsWith(u8, name, "--");
        for (self.entries.items, 0..) |e, i| switch (e) {
            .typed, .custom => {},
            .unparsed => |u| {
                if (custom and std.mem.eql(u8, u.name, name)) return i;
                if (!custom and std.ascii.eqlIgnoreCase(u.name, name)) return i;
            },
        };
        return null;
    }

    /// getPropertyPriority(property): whether it is "important".
    pub fn getPropertyPriority(self: *const DeclarationBlock, property_name: []const u8) bool {
        if (std.mem.startsWith(u8, property_name, "--")) return if (self.getCustom(property_name)) |c| c.important else false;
        const property = properties.lookup(property_name) orelse {
            const i = self.indexOfNameInsensitive(property_name) orelse return false;
            return self.entries.items[i].important();
        };
        switch (property) {
            .shorthand => |s| {
                for (s.longhands()) |l| {
                    const d = self.get(l) orelse return false;
                    if (!d.important) return false;
                }
                return true;
            },
            .longhand => |l| return if (self.get(l)) |d| d.important else false,
        }
    }

    /// setProperty(property, value, priority), from its step 2 (the
    /// readonly check is the caller's). True when the declarations changed
    /// - the caller then runs "update style attribute for".
    pub fn setProperty(self: *DeclarationBlock, options: properties.ParseOptions, property_name: []const u8, value_text: []const u8, priority: []const u8) Allocator.Error!bool {
        // 3. "If value is the empty string, invoke removeProperty() with
        //    property as argument and return."
        if (value_text.len == 0) {
            var scratch: std.ArrayList(u8) = .empty;
            defer scratch.deinit(self.allocator);
            return self.removeProperty(property_name, &scratch);
        }
        // 4. "If priority is not the empty string and is not an ASCII
        //    case-insensitive match for the string "important", then return."
        if (priority.len != 0 and !std.ascii.eqlIgnoreCase(priority, "important")) return false;
        const important = priority.len != 0;
        // 1. A custom property keeps its case; 5-9 below, for its grammar.
        if (std.mem.startsWith(u8, property_name, "--")) return self.setCustom(options, property_name, value_text, important);
        // 2. "If property is not a case-sensitive match for a supported CSS
        //    property, then return." (Parsing keeps an unsupported
        //    declaration for read-back; setProperty, as the spec says, does
        //    not - ruling Q7.)
        const property = properties.lookup(property_name) orelse return false;
        if (!self.context.allows(property, important)) return false;
        // 5. "Let component value list be the result of parsing value for
        //    property property. If component value list is null, then return."
        var assignments: std.ArrayList(Assignment) = .empty;
        defer assignments.deinit(self.allocator);
        if (!try properties.parseDeclaration(options, property, value_text, &assignments)) return false;
        var consumed: usize = 0;
        defer for (assignments.items[consumed..]) |a| a.value.release();
        // 6-9: "set the CSS declaration" each longhand.
        var updated = false;
        for (assignments.items) |a| {
            // setDeclaration consumes this reference on success AND error.
            consumed += 1;
            if (try self.setDeclaration(a.longhand, a.value, important)) updated = true;
        }
        return updated;
    }

    /// CSSOM "set a CSS declaration": the value consumed (released when not
    /// kept). True when the block changed.
    fn setDeclaration(self: *DeclarationBlock, l: Longhand, value: Assigned, important: bool) Allocator.Error!bool {
        // CSSOM "set a CSS declaration" steps 1-2.
        if (self.indexOf(l)) |i| {
            // "If property is in a logical property group and there is a
            // declaration after it in declarations whose property is in the
            // same group but uses a different mapping logic, needs append is
            // true" - remove it and append.
            const needs_append = self.mappingConflictAfter(l, i);
            const existing = &self.entries.items[i].typed;
            if (!needs_append) {
                if (existing.important == important and assignedEql(existing.value, value)) {
                    value.release();
                    return false;
                }
                existing.value.release();
                existing.value = value;
                existing.important = important;
                return true;
            }
            var old = self.entries.orderedRemove(i);
            self.freeEntry(&old);
        }
        errdefer value.release();
        try self.entries.append(self.allocator, .{ .typed = .{ .longhand = l, .value = value, .important = important } });
        return true;
    }

    fn mappingConflictAfter(self: *const DeclarationBlock, l: Longhand, index: usize) bool {
        const group = logicalGroup(l) orelse return false;
        const logical = l.logical() != null;
        for (self.entries.items[index + 1 ..]) |e| switch (e) {
            .typed => |d| {
                const g = logicalGroup(d.longhand) orelse continue;
                if (g == group and (d.longhand.logical() != null) != logical) return true;
            },
            .unparsed, .custom => {},
        };
        return false;
    }

    /// removeProperty(property), from step 2: the old value appended to
    /// `out`. True when a declaration was removed.
    pub fn removeProperty(self: *DeclarationBlock, property_name: []const u8, out: *std.ArrayList(u8)) Allocator.Error!bool {
        // 3. "Let value be the return value of invoking getPropertyValue()
        //    with property as argument."
        const start = out.items.len;
        try self.getPropertyValue(property_name, out);
        // 4-5. Remove the longhands (or the property).
        var removed = false;
        if (std.mem.startsWith(u8, property_name, "--")) {
            if (self.indexOfCustom(property_name)) |i| {
                var old = self.entries.orderedRemove(i);
                self.freeEntry(&old);
                removed = true;
            }
            return removed;
        }
        const property = properties.lookup(property_name) orelse {
            if (self.indexOfNameInsensitive(property_name)) |i| {
                var old = self.entries.orderedRemove(i);
                self.freeEntry(&old);
                removed = true;
            }
            return removed;
        };
        const longhands: []const Longhand = switch (property) {
            .shorthand => |s| s.longhands(),
            .longhand => |l| &.{l},
        };
        // A shorthand whose value is a pending substitution returns "" -
        // integrator probe 1026a: Chrome and Safari return "" for
        // removeProperty('border') after `border: var(--x)`; Firefox
        // returns "var(--x)", CSSOM's step 3. No newer spec: golden rule 2,
        // the majority. The value read above and the longhands removed
        // below are as CSSOM says.
        if (property == .shorthand and self.holdsPendingShorthand(property.shorthand)) out.shrinkRetainingCapacity(start);
        for (longhands) |l| {
            if (self.indexOf(l)) |i| {
                var old = self.entries.orderedRemove(i);
                self.freeEntry(&old);
                removed = true;
            }
        }
        return removed;
    }

    /// Whether a longhand of `s` holds the pending-substitution value of
    /// a declaration of `s` itself (`border: var(--x)`).
    fn holdsPendingShorthand(self: *const DeclarationBlock, s: properties.Shorthand) bool {
        for (s.longhands()) |l| {
            const i = self.indexOf(l) orelse continue;
            const d = self.entries.items[i].typed;
            if (d.value != .value or d.value.value != .pending) continue;
            const owner = d.value.value.pending.property orelse continue;
            if (owner == .shorthand and owner.shorthand == s) return true;
        }
        return false;
    }

    /// The cssText setter's steps after the readonly check: "Empty the
    /// declarations. Parse the given value and, if the return value is not
    /// the empty list, insert the items in the list into the declarations,
    /// in specified order."
    pub fn setCssText(self: *DeclarationBlock, options: properties.ParseOptions, text: []const u8) Allocator.Error!void {
        var parsed = try parseInContext(options, text, self.context);
        self.clear();
        self.entries.deinit(self.allocator);
        self.entries = parsed.entries;
        self.custom_count = parsed.custom_count;
        parsed.entries = .empty;
        parsed.custom_count = 0;
    }

    /// CSSOM "serialize a CSS declaration block" (the cssText getter),
    /// appended to `out`.
    pub fn serialize(self: *const DeclarationBlock, out: *std.ArrayList(u8)) Allocator.Error!void {
        const allocator = self.allocator;
        // "Let already serialized be an empty array."
        var done = try allocator.alloc(bool, self.entries.items.len);
        defer allocator.free(done);
        @memset(done, false);
        var first = true;
        for (self.entries.items, 0..) |*e, index| {
            if (done[index]) continue;
            switch (e.*) {
                .unparsed => |u| {
                    try appendDeclaration(out, allocator, &first, u.name, u.value, u.important);
                    done[index] = true;
                },
                .custom => |c| {
                    var value: std.ArrayList(u8) = .empty;
                    defer value.deinit(allocator);
                    try c.value.serialize(&value, allocator);
                    try appendDeclaration(out, allocator, &first, c.name.bytes, value.items, c.important);
                    done[index] = true;
                },
                .typed => |d| {
                    // "If property maps to one or more shorthand properties,
                    // let shorthands be an array of those shorthand
                    // properties, in preferred order."
                    var wrote_shorthand = false;
                    for (preferred_shorthands) |s| {
                        if (!containsLonghand(s.longhands(), d.longhand)) continue;
                        if (try self.serializeAsShorthand(s, done, out, &first)) {
                            wrote_shorthand = true;
                            break;
                        }
                    }
                    if (wrote_shorthand) continue;
                    var value: std.ArrayList(u8) = .empty;
                    defer value.deinit(allocator);
                    try properties.serializeAssigned(d.longhand, d.value, &value, allocator);
                    try appendDeclaration(out, allocator, &first, d.longhand.name(), value.items, d.important);
                    done[index] = true;
                },
            }
        }
    }

    /// The shorthand steps of "serialize a CSS declaration block": every
    /// longhand of `s` present and not yet serialized, with one importance
    /// and either all or none CSS-wide keywords; then "shorthand: value".
    fn serializeAsShorthand(self: *const DeclarationBlock, s: Shorthand, done: []bool, out: *std.ArrayList(u8), first: *bool) Allocator.Error!bool {
        const ls = s.longhands();
        var vs: [properties.max_assignments]Assigned = undefined;
        var indices: [properties.max_assignments]usize = undefined;
        var important: ?bool = null;
        for (ls, 0..) |l, k| {
            const i = self.indexOf(l) orelse return false;
            if (done[i]) return false;
            const d = self.entries.items[i].typed;
            if (important) |imp| if (imp != d.important) return false;
            important = d.important;
            vs[k] = d.value;
            indices[k] = i;
        }
        var value: std.ArrayList(u8) = .empty;
        defer value.deinit(self.allocator);
        if (!try properties.serializeShorthand(s, vs[0..ls.len], .specified, &value, self.allocator)) return false;
        if (value.items.len == 0) return false;
        try appendDeclaration(out, self.allocator, first, s.name(), value.items, important.?);
        for (indices[0..ls.len]) |i| done[i] = true;
        return true;
    }

    /// The declarations the cascade reads: the typed ones.
    pub fn typed(self: *const DeclarationBlock) TypedIterator {
        return .{ .entries = self.entries.items };
    }

    /// The custom property declarations, in order.
    pub fn customs(self: *const DeclarationBlock) CustomIterator {
        return .{ .entries = if (self.custom_count == 0) &.{} else self.entries.items };
    }

    pub const CustomIterator = struct {
        entries: []const Entry,
        index: usize = 0,

        pub fn next(self: *CustomIterator) ?*const Custom {
            while (self.index < self.entries.len) {
                const e = &self.entries[self.index];
                self.index += 1;
                switch (e.*) {
                    .custom => |*c| return c,
                    .typed, .unparsed => {},
                }
            }
            return null;
        }
    };

    pub const TypedIterator = struct {
        entries: []const Entry,
        index: usize = 0,

        pub fn next(self: *TypedIterator) ?*const Declaration {
            while (self.index < self.entries.len) {
                const e = &self.entries[self.index];
                self.index += 1;
                switch (e.*) {
                    .typed => |*d| return d,
                    .unparsed, .custom => {},
                }
            }
            return null;
        }
    };
};

fn appendDeclaration(out: *std.ArrayList(u8), allocator: Allocator, first: *bool, name: []const u8, value: []const u8, important: bool) Allocator.Error!void {
    // "serialize a CSS declaration": "property: value[ !important];",
    // joined by a space.
    if (!first.*) try out.append(allocator, ' ');
    first.* = false;
    try out.appendSlice(allocator, name);
    try out.appendSlice(allocator, ": ");
    try out.appendSlice(allocator, value);
    if (important) try out.appendSlice(allocator, " !important");
    try out.append(allocator, ';');
}

fn containsLonghand(ls: []const Longhand, l: Longhand) bool {
    for (ls) |x| if (x == l) return true;
    return false;
}

/// CSSOM "preferred order": shorthands with more longhands first, then by
/// name. `all` is never chosen to serialize a block (browsers write the
/// longhands).
const preferred_shorthands = blk: {
    @setEvalBranchQuota(100_000);
    const fields = @typeInfo(Shorthand).@"enum".fields;
    var out: [fields.len - 2]Shorthand = undefined;
    var n: usize = 0;
    for (fields) |f| {
        const s: Shorthand = @enumFromInt(f.value);
        // Legacy one-member aliases are emitted with their canonical longhand.
        if (s == .all or s == ._webkit_text_orientation) continue;
        out[n] = s;
        n += 1;
    }
    // Insertion sort, comptime.
    for (1..out.len) |i| {
        var j = i;
        while (j > 0) : (j -= 1) {
            const a = out[j - 1];
            const b = out[j];
            const before = a.longhands().len > b.longhands().len or
                (a.longhands().len == b.longhands().len and std.mem.lessThan(u8, a.name(), b.name()));
            if (before) break;
            out[j - 1] = b;
            out[j] = a;
        }
    }
    break :blk out;
};

fn logicalGroup(l: Longhand) ?properties.Logical.Group {
    if (l.logical()) |lg| return lg.group;
    switch (l) {
        .width, .height => return .size,
        .min_width, .min_height => return .min_size,
        .max_width, .max_height => return .max_size,
        else => {},
    }
    const sides = [_]PhysicalSides{
        .{ .group = .margin, .ls = .{ .margin_top, .margin_right, .margin_bottom, .margin_left } },
        .{ .group = .padding, .ls = .{ .padding_top, .padding_right, .padding_bottom, .padding_left } },
        .{ .group = .inset, .ls = .{ .top, .right, .bottom, .left } },
        .{ .group = .border_width, .ls = .{ .border_top_width, .border_right_width, .border_bottom_width, .border_left_width } },
        .{ .group = .border_style, .ls = .{ .border_top_style, .border_right_style, .border_bottom_style, .border_left_style } },
        .{ .group = .border_color, .ls = .{ .border_top_color, .border_right_color, .border_bottom_color, .border_left_color } },
        .{ .group = .scroll_margin, .ls = .{ .scroll_margin_top, .scroll_margin_right, .scroll_margin_bottom, .scroll_margin_left } },
        .{ .group = .scroll_padding, .ls = .{ .scroll_padding_top, .scroll_padding_right, .scroll_padding_bottom, .scroll_padding_left } },
    };
    for (sides) |g| for (g.ls) |x| if (x == l) return g.group;
    return null;
}

const PhysicalSides = struct { group: properties.Logical.Group, ls: [4]Longhand };

fn assignedEql(a: Assigned, b: Assigned) bool {
    return switch (a) {
        .css_wide => |k| b == .css_wide and b.css_wide == k,
        .value => |v| b == .value and v.eql(b.value) and v.resourcesEql(b.value),
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn testOptions() properties.ParseOptions {
    return .{ .allocator = testing.allocator };
}

fn expectCssText(block: *const DeclarationBlock, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings(expected, out.items);
}

fn expectValue(block: *const DeclarationBlock, property: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue(property, &out);
    try testing.expectEqualStrings(expected, out.items);
}

test "parse: invalid declarations dropped, duplicates keep the last, important wins" {
    var block = try DeclarationBlock.parse(testOptions(), "color: red; width: -1px; color: blue; margin-left: 2px !important; margin-left: 3px");
    defer block.deinit();
    try expectCssText(&block, "color: blue; margin-left: 2px !important;");
    try testing.expect(block.getPropertyPriority("margin-left"));
    try testing.expectEqual(@as(usize, 2), block.length());
    try testing.expectEqualStrings("color", block.item(0).?);
}

test "shorthands expand into longhands and serialize back" {
    var block = try DeclarationBlock.parse(testOptions(), "margin: 1px 2px; border-top: 1px solid red");
    defer block.deinit();
    try testing.expectEqual(@as(usize, 7), block.length());
    try expectValue(&block, "margin", "1px 2px");
    try expectValue(&block, "margin-right", "2px");
    try expectValue(&block, "border-top", "1px solid red");
    try expectCssText(&block, "margin: 1px 2px; border-top: 1px solid red;");
}

test "a shorthand with mixed importance or a missing longhand reads as empty" {
    var block = try DeclarationBlock.parse(testOptions(), "margin: 1px; margin-top: 2px !important; padding-left: 1px");
    defer block.deinit();
    try expectValue(&block, "margin", "");
    try expectValue(&block, "padding", "");
    try expectCssText(&block, "margin-right: 1px; margin-bottom: 1px; margin-left: 1px; margin-top: 2px !important; padding-left: 1px;");
}

test "unsupported properties are kept for read-back only" {
    var block = try DeclarationBlock.parse(testOptions(), "not-a-property: spin 1s; --x: { a }; color: red");
    defer block.deinit();
    try expectValue(&block, "not-a-property", "spin 1s");
    try expectValue(&block, "NOT-A-PROPERTY", "spin 1s");
    var it = block.typed();
    try testing.expectEqual(Longhand.color, it.next().?.longhand);
    try testing.expect(it.next() == null);
}

test "setProperty and removeProperty (CSSOM 6.6.1)" {
    var block = DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(testOptions(), "color", "red", ""));
    try testing.expect(!try block.setProperty(testOptions(), "color", "red", ""));
    try testing.expect(!try block.setProperty(testOptions(), "color", "nope", ""));
    try testing.expect(!try block.setProperty(testOptions(), "color", "blue", "bogus"));
    try testing.expect(!try block.setProperty(testOptions(), "not-a-property", "spin 1s", ""));
    try testing.expect(try block.setProperty(testOptions(), "Margin", "1px", "IMPORTANT"));
    try expectCssText(&block, "color: red; margin: 1px !important;");
    var old: std.ArrayList(u8) = .empty;
    defer old.deinit(testing.allocator);
    try testing.expect(try block.removeProperty("margin", &old));
    try testing.expectEqualStrings("1px", old.items);
    try testing.expect(try block.setProperty(testOptions(), "color", "", ""));
    try testing.expectEqual(@as(usize, 0), block.length());
}

test "setProperty in a logical property group appends when the mapping logic differs" {
    var block = try DeclarationBlock.parse(testOptions(), "margin-left: 1px; margin-inline-start: 2px");
    defer block.deinit();
    _ = try block.setProperty(testOptions(), "margin-left", "3px", "");
    try testing.expectEqualStrings("margin-left", block.item(1).?);
    _ = try block.setProperty(testOptions(), "margin-left", "4px", "");
    try testing.expectEqualStrings("margin-left", block.item(1).?);
}

test "setCssText replaces every declaration" {
    var block = try DeclarationBlock.parse(testOptions(), "color: red");
    defer block.deinit();
    try block.setCssText(testOptions(), "white-space: pre; display: none");
    try expectCssText(&block, "white-space: pre; display: none;");
    try expectValue(&block, "white-space-collapse", "preserve");
}

test "CSS-wide keywords serialize, and a shorthand of one keyword is that keyword" {
    var block = try DeclarationBlock.parse(testOptions(), "padding: inherit; color: initial");
    defer block.deinit();
    try expectCssText(&block, "padding: inherit; color: initial;");
}
