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
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const properties = @import("properties.zig");
const rules = @import("rules.zig");
const values = @import("style_values.zig");
const custom_properties = @import("custom_properties.zig");
const computed_style = @import("computed_style.zig");
const pending_values = @import("pending_values.zig");

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
    /// `contentHash`, cached: 24 bits, little-endian, 0 when not computed
    /// (Blink's CSSPropertyValueSet `hash_`, computed lazily by GetHash).
    /// It sits in the 3 bytes of padding after `custom_count` and
    /// `context`, so a block stays 48 B and an ElementStyle does not grow
    /// (the size pin below). Every writer resets it (`content_writers`).
    content_hash: [3]u8 = .{ 0, 0, 0 },

    /// Every pub method that can change the entries the cascade reads; each
    /// resets the cached content hash (`contentChanged`), as each of
    /// Blink's CSSPropertyValueSet mutators calls InvalidateHashIfComputed
    /// (css_property_value_set.cc, chromium f1bd91298bf0: RemovePropertyAtIndex,
    /// SetProperty, SetLonghandProperty, Clear, RemovePropertiesInSet ...).
    /// A pub method taking `*DeclarationBlock` that is not listed here fails
    /// to compile (the check after this struct): review it, make it reset
    /// the hash, then list it. Code outside this file that writes `entries`
    /// directly (page descriptors, font faces, font requests, animation
    /// effect blocks) never writes an element's own block, the only blocks
    /// whose hash is read; Debug builds recompute every cached hash read.
    pub const content_writers = [_][]const u8{ "deinit", "clear", "appendDeclarations", "setProperty", "setValidatedProperty", "setValidatedCustom", "removeProperty", "setCssText" };

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
        self.contentChanged();
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

    /// CSS Syntax 3 section 5.5.5: continue a declaration run after a
    /// discarded rule, preserving importance and specified order without
    /// reparsing the declarations already in this block.
    pub fn appendDeclarations(self: *DeclarationBlock, options: properties.ParseOptions, parsed: []const rules.Declaration) Allocator.Error!void {
        self.contentChanged();
        for (parsed) |d| try self.addParsed(options, d.name, d.value, d.important);
    }

    /// One parsed declaration into the block. A later declaration of a
    /// longhand replaces an earlier one, and moves to the end - unless the
    /// earlier is important and the later is not, which the cascade's
    /// order would make lose anyway (Blink's parsed declaration sets do the
    /// same).
    fn addParsed(self: *DeclarationBlock, options: properties.ParseOptions, name: []const u8, value_text: []const u8, important: bool) Allocator.Error!void {
        self.contentChanged();
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
        self.contentChanged();
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
        self.contentChanged();
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
            self.contentChanged();
            existing.value.release();
            existing.value = value;
            existing.important = important;
            return true;
        }
        errdefer value.release();
        const name_text = try custom_properties.Text.create(self.allocator, name);
        errdefer name_text.release();
        try self.entries.append(self.allocator, .{ .custom = .{ .name = name_text, .value = value, .important = important } });
        self.contentChanged();
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
                    if (important) |imp| if (imp != d.important) return;
                    important = d.important;
                    vs[i] = d.value;
                }
                // CSSOM getPropertyValue 1.2.2–1.2.3 / Q200: an entirely
                // pending system-font variant has empty getter readback.
                // Q9 (codex-cssfam): an independently overridden member
                // reaches the existing serializer; cssText is unchanged.
                if (s == .font_variant) {
                    const all_system = for (vs[0..s.longhands().len]) |value| {
                        if (value != .value or value.value != .font_system) break false;
                    } else true;
                    if (all_system) return;
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
        // CSSOM "parse a CSS value": value is the whole input, so its open
        // functions and blocks close at EOF (CSS Syntax 3).
        var eof_options = options;
        eof_options.closes_at_eof = true;
        if (!try properties.parseDeclaration(eof_options, property, value_text, &assignments)) return false;
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

    /// Typed OM §3: install a complete already-validated native value.
    /// Borrowed assignments are retained before any old declaration can die.
    /// The existing CSSOM mutation algorithm preserves position and observes
    /// logical-group ordering; all allocation precedes the first mutation.
    pub fn setValidatedProperty(self: *DeclarationBlock, property: Property, assignments: []const Assignment) (Allocator.Error || error{Invalid})!bool {
        if (!self.context.allows(property, false)) return error.Invalid;
        const longhands: []const Longhand = switch (property) {
            .longhand => |l| &.{l},
            .shorthand => |s| s.longhands(),
        };
        if (assignments.len != longhands.len or assignments.len > properties.max_assignments) return error.Invalid;
        var copy: [properties.max_assignments]Assignment = undefined;
        for (longhands, 0..) |l, i| {
            var found = false;
            for (assignments) |assignment| if (assignment.longhand == l) {
                if (found) return error.Invalid;
                copy[i] = assignment;
                found = true;
            };
            if (!found) return error.Invalid;
        }
        try self.entries.ensureUnusedCapacity(self.allocator, assignments.len);
        for (copy[0..assignments.len]) |assignment| assignment.value.retain();
        var changed = false;
        for (copy[0..assignments.len]) |assignment| {
            // Capacity was reserved for every append, including replacements
            // moved by a logical mapping conflict. No failure remains here.
            if (self.setDeclaration(assignment.longhand, assignment.value, false) catch unreachable) changed = true;
        }
        return changed;
    }

    /// Typed OM's custom-property form; a borrowed, parsed Specified value.
    /// Q57 keeps CSS declaration tokenization separate from string names.
    pub fn setValidatedCustom(self: *DeclarationBlock, name: []const u8, value: custom_properties.Specified) (Allocator.Error || error{Invalid})!bool {
        if (!custom_properties.isName(name) or self.context == .position_try) return error.Invalid;
        if (self.indexOfCustom(name)) |i| {
            const existing = &self.entries.items[i].custom;
            if (!existing.important and existing.value.eql(value)) return false;
            self.contentChanged();
            value.retain();
            existing.value.release();
            existing.value = value;
            existing.important = false;
            return true;
        }
        const name_text = try custom_properties.Text.create(self.allocator, name);
        errdefer name_text.release();
        try self.entries.ensureUnusedCapacity(self.allocator, 1);
        self.contentChanged();
        value.retain();
        self.entries.appendAssumeCapacity(.{ .custom = .{ .name = name_text, .value = value, .important = false } });
        self.custom_count += 1;
        return true;
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
                self.contentChanged();
                existing.value.release();
                existing.value = value;
                existing.important = important;
                return true;
            }
            self.contentChanged();
            var old = self.entries.orderedRemove(i);
            self.freeEntry(&old);
        }
        errdefer value.release();
        try self.entries.append(self.allocator, .{ .typed = .{ .longhand = l, .value = value, .important = important } });
        self.contentChanged();
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
                self.contentChanged();
                var old = self.entries.orderedRemove(i);
                self.freeEntry(&old);
                removed = true;
            }
            return removed;
        }
        const property = properties.lookup(property_name) orelse {
            if (self.indexOfNameInsensitive(property_name)) |i| {
                self.contentChanged();
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
                self.contentChanged();
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
        // clear() resets the content hash.
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
                    try appendDeclaration(.raw, out, allocator, &first, u.name, u.value, u.important);
                    done[index] = true;
                },
                .custom => |c| {
                    var value: std.ArrayList(u8) = .empty;
                    defer value.deinit(allocator);
                    try c.value.serialize(&value, allocator);
                    // CSSOM block serialization step4.4 / identifier serialization;
                    // Variables1 §4.1 preserves name code points, including case.
                    // variable-names.html requires cssText to round-trip escaped
                    // names; indexed/name getters keep the decoded name unchanged.
                    try appendDeclaration(.identifier, out, allocator, &first, c.name.bytes, value.items, c.important);
                    done[index] = true;
                },
                .typed => |d| {
                    // "If property maps to one or more shorthand properties,
                    // let shorthands be an array of those shorthand
                    // properties, in preferred order."
                    // Q16: this alias alone keeps its declaring name in
                    // pending cssText, while item() stays canonical.
                    if (d.longhand == .perspective and d.value == .value and d.value.value == .pending) {
                        if (d.value.value.pending.property) |declared| {
                            if (declared == .shorthand and declared.shorthand == ._webkit_perspective and
                                try self.serializeAsShorthand(._webkit_perspective, done, out, &first)) continue;
                        }
                    }
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
                    try appendDeclaration(.raw, out, allocator, &first, d.longhand.name(), value.items, d.important);
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
        try appendDeclaration(.raw, out, self.allocator, first, s.name(), value.items, important.?);
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

    // ------------------------------------------------------------------------
    // Content identity: the matched-properties cache keys and compares an
    // element's own blocks (its style attribute's, its presentational
    // hints') by content, as Blink does its inline style (lane style1 b5;
    // tmp/redesign/style-memory-design.md 3.6).
    // ------------------------------------------------------------------------

    /// The entries changed: the cached content hash is stale.
    fn contentChanged(self: *DeclarationBlock) void {
        self.content_hash = .{ 0, 0, 0 };
    }

    /// A 24-bit hash of what the cascade reads in this block, computed on
    /// first use and cached until a writer changes the entries (Blink
    /// CSSPropertyValueSet::GetHash / ComputeHash: each property's id,
    /// importance and CSSValue::Hash). Equal content - `interchangeable`
    /// blocks - hashes equal in the common case; a collision or an unequal
    /// hash costs the matched-properties cache a compare or a miss, never a
    /// value, because it compares content. Never 0. Takes a const block:
    /// the cache is not part of its value (Blink's `mutable hash_`).
    pub fn contentHash(self: *const DeclarationBlock) u32 {
        const cached = std.mem.readInt(u24, &self.content_hash, .little);
        if (cached != 0) {
            // Debug builds: a writer that changed the entries without
            // resetting the hash is a bug (content_writers).
            if (comptime builtin.mode == .debug) {
                if (self.computeContentHash()) |fresh| if (fresh != cached)
                    std.debug.panic("declaration block content hash stale: cached {x}, now {x}", .{ cached, fresh });
            }
            return cached;
        }
        const fresh = self.computeContentHash() orelse return @truncate(@intFromPtr(self) | 1);
        std.mem.writeInt(u24, &@constCast(self).content_hash, fresh, .little);
        return fresh;
    }

    /// Null when out of memory (serializing a value): not cached then.
    fn computeContentHash(self: *const DeclarationBlock) ?u24 {
        // Serializing a value allocates; the hash is computed once per change.
        const scratch = self.allocator;
        var h = std.hash.Wyhash.init(0x6f776e);
        hashScalar(&h, @backingInt(self.context));
        for (self.entries.items) |*e| switch (e.*) {
            // Kept for read-back only: the cascade never reads it.
            .unparsed => {},
            .typed => |d| {
                hashScalar(&h, @backingInt(d.longhand));
                hashScalar(&h, @intFromBool(d.important));
                switch (d.value) {
                    .css_wide => |k| hashScalar(&h, @backingInt(k)),
                    .value => |v| hashValue(&h, d.longhand, v, scratch) catch return null,
                }
            },
            .custom => |c| {
                h.update(c.name.bytes);
                hashScalar(&h, @as(u64, @intFromBool(c.important)) | 2);
                switch (c.value) {
                    .css_wide => |k| hashScalar(&h, @backingInt(k)),
                    .text => |t| h.update(t.bytes),
                    .pending => |p| h.update(p.text),
                }
            },
        };
        const full = h.final();
        const folded: u24 = @truncate(full ^ (full >> 24) ^ (full >> 48));
        return if (folded == 0) 1 else folded;
    }

    /// Whether the cascade computes the same from `a` as from `b` in every
    /// place - element-attached or not - so a style computed with one may
    /// stand for one computed with the other (Blink CachedMatchedProperties::
    /// CorrespondsTo: CSSPropertyValueSet::Equals, value and importance per
    /// property). Compared: the context; the entries the cascade reads, in
    /// order (an unsupported declaration kept for read-back is not one):
    /// a typed declaration's longhand, importance and value, a custom one's
    /// name, importance and value.
    ///
    /// A value: `identical`, else computed_style.interchangeable's rule
    /// (Value.eql AND Value.resourcesEql: each url()'s resolved URL, flags
    /// and source - base URL, referrer, referrer policy, origin-clean). What
    /// that rule cannot see in a DECLARED value (audit, lane style1 b5):
    /// a pending-substitution value (var(), env(), attr(), random-item())
    /// keeps its url()s and their base unresolved - Pending.eql compares its
    /// text and property only and resourceUrls() is empty for it - so its
    /// provenance is compared field by field (`samePending`): its source
    /// (the base its substituted url()s resolve against, the referrer and
    /// its policy, origin-clean), the quirks and SVG-presentation modes it
    /// re-parses in, its captured url()s, its namespace map (attr()), its
    /// resolver flag. A custom property's text (Text.eql: bytes and taint)
    /// resolves nothing itself. Every other declared payload is a computed
    /// one's type, audited by b4 (computed_style.interchangeable).
    pub fn interchangeable(a: *const DeclarationBlock, b: *const DeclarationBlock) bool {
        if (a == b) return true;
        if (a.context != b.context) return false;
        var i: usize = 0;
        var j: usize = 0;
        while (true) {
            while (i < a.entries.items.len and a.entries.items[i] == .unparsed) i += 1;
            while (j < b.entries.items.len and b.entries.items[j] == .unparsed) j += 1;
            if (i == a.entries.items.len or j == b.entries.items.len) return i == a.entries.items.len and j == b.entries.items.len;
            const x = &a.entries.items[i];
            const y = &b.entries.items[j];
            switch (x.*) {
                .typed => |d| {
                    if (y.* != .typed) return false;
                    const e = y.typed;
                    if (d.longhand != e.longhand or d.important != e.important or !sameAssigned(d.value, e.value)) return false;
                },
                .custom => |c| {
                    if (y.* != .custom) return false;
                    const k = y.custom;
                    if (c.important != k.important or !std.mem.eql(u8, c.name.bytes, k.name.bytes) or !sameSpecified(c.value, k.value)) return false;
                },
                .unparsed => unreachable,
            }
            i += 1;
            j += 1;
        }
    }

    /// A copy of the entries the cascade reads, sharing their values (each
    /// retained): what a matched-properties cache entry keeps of an
    /// element's own block, so the owner's later writes to its block leave
    /// the entry as it was. `allocator` owns the copy (deinit releases it).
    pub fn snapshot(self: *const DeclarationBlock, allocator: Allocator) Allocator.Error!DeclarationBlock {
        var copy = DeclarationBlock.init(allocator);
        copy.context = self.context;
        copy.content_hash = self.content_hash;
        try copy.entries.ensureTotalCapacity(allocator, self.entries.items.len);
        for (self.entries.items) |e| switch (e) {
            .unparsed => {},
            .typed => |d| {
                d.value.retain();
                copy.entries.appendAssumeCapacity(e);
            },
            .custom => |c| {
                c.name.retain();
                c.value.retain();
                copy.entries.appendAssumeCapacity(e);
                copy.custom_count += 1;
            },
        };
        return copy;
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

fn appendDeclaration(comptime name_encoding: enum { raw, identifier }, out: *std.ArrayList(u8), allocator: Allocator, first: *bool, name: []const u8, value: []const u8, important: bool) Allocator.Error!void {
    // "serialize a CSS declaration": "property: value[ !important];",
    // joined by a space.
    if (!first.*) try out.append(allocator, ' ');
    first.* = false;
    if (name_encoding == .identifier) {
        try @import("serialize.zig").appendIdentifier(out, allocator, name);
    } else {
        try out.appendSlice(allocator, name);
    }
    try out.appendSlice(allocator, ": ");
    // CSSOM "serialize a CSS declaration", step 4: omit whitespace-only values.
    if (std.mem.trim(u8, value, " \t\n\r\x0c").len != 0) try out.appendSlice(allocator, value);
    if (important) try out.appendSlice(allocator, " !important");
    try out.append(allocator, ';');
}

fn containsLonghand(ls: []const Longhand, l: Longhand) bool {
    for (ls) |x| if (x == l) return true;
    return false;
}

/// CSSOM "preferred order" steps 1, 3-5: more longhands first, then
/// unprefixed names, -webkit- names, other prefixed names, and name order.
/// `all` is never chosen to serialize a block (browsers write the longhands).
const preferred_shorthands = blk: {
    @setEvalBranchQuota(100_000);
    // Zig 0.17: @typeInfo is struct-of-arrays; rebuild the old field list.
    const fields = zig017_fields: {
        const zig017_info = @typeInfo(Shorthand).@"enum";
        var zig017_out: [zig017_info.field_names.len]struct { name: [:0]const u8, value: comptime_int } = undefined;
        for (zig017_info.field_names, zig017_info.field_values, 0..) |zig017_n, zig017_v, zig017_i| zig017_out[zig017_i] = .{ .name = zig017_n, .value = zig017_v };
        break :zig017_fields zig017_out;
    };
    var out: [fields.len]Shorthand = undefined;
    var n: usize = 0;
    for (fields) |f| {
        const s: Shorthand = @fromBackingInt(@intCast(f.value));
        // Legacy one-member aliases are emitted with their canonical longhand.
        // color-adjust (Color Adjustment 1 §3.1) is one too: cssText keeps
        // print-color-adjust, as Firefox and Safari serialize it.
        if (s == .all or s == ._webkit_text_orientation or s == ._webkit_transform or s == ._webkit_perspective or s == .color_adjust or s.isLegacyShorthand()) continue;
        out[n] = s;
        n += 1;
    }
    // Insertion sort, comptime.
    for (1..n) |i| {
        var j = i;
        while (j > 0) : (j -= 1) {
            const a = out[j - 1];
            const b = out[j];
            const before = order: {
                const a_count = a.longhands().len;
                const b_count = b.longhands().len;
                if (a_count != b_count) break :order a_count > b_count;
                const a_name = a.name();
                const b_name = b.name();
                const a_prefix: u2 = if (std.mem.startsWith(u8, a_name, "-webkit-")) 1 else if (std.mem.startsWith(u8, a_name, "-")) 2 else 0;
                const b_prefix: u2 = if (std.mem.startsWith(u8, b_name, "-webkit-")) 1 else if (std.mem.startsWith(u8, b_name, "-")) 2 else 0;
                break :order a_prefix < b_prefix or (a_prefix == b_prefix and std.mem.lessThan(u8, a_name, b_name));
            };
            if (before) break;
            out[j - 1] = b;
            out[j] = a;
        }
    }
    break :blk out[0..n].*;
};

fn logicalGroup(l: Longhand) ?properties.Logical.Group {
    if (l.logical()) |lg| return lg.group;
    switch (l) {
        .width, .height => return .size,
        .min_width, .min_height => return .min_size,
        .max_width, .max_height => return .max_size,
        .overflow_x, .overflow_y => return .overflow,
        .overscroll_behavior_x, .overscroll_behavior_y => return .overscroll,
        .contain_intrinsic_width, .contain_intrinsic_height => return .contain_intrinsic,
        .corner_top_left_shape, .corner_top_right_shape, .corner_bottom_right_shape, .corner_bottom_left_shape => return .corner_shape,
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

comptime {
    // content_writers is the reviewed list of every pub method that takes
    // a mutable block (DeclarationBlock.content_hash).
    @setEvalBranchQuota(20_000);
    for (@typeInfo(DeclarationBlock).@"struct".decl_names) |name| {
        const info = @typeInfo(@TypeOf(@field(DeclarationBlock, name)));
        if (info != .@"fn" or info.@"fn".param_types.len == 0) continue;
        if (info.@"fn".param_types[0] != *DeclarationBlock) continue;
        const listed = for (DeclarationBlock.content_writers) |w| {
            if (std.mem.eql(u8, w, name)) break true;
        } else false;
        if (!listed) @compileError("DeclarationBlock." ++ name ++ " takes a mutable block: make it reset the content hash (contentChanged) and list it in content_writers");
    }
}

fn hashScalar(h: *std.hash.Wyhash, x: u64) void {
    h.update(std.mem.asBytes(&x));
}

/// A declared value into the content hash: a payload that holds no
/// reference by its bits (so `identical` values hash equal), a
/// pending-substitution value by its text and property (Pending.eql's
/// fields), any other by its CSSOM serialization, so equal values parsed
/// apart share a key (Blink's CSSValue::Hash hashes what it can by content
/// and the rest by pointer).
fn hashValue(h: *std.hash.Wyhash, l: Longhand, v: values.Value, scratch: Allocator) Allocator.Error!void {
    hashScalar(h, @backingInt(std.meta.activeTag(v)));
    switch (v) {
        .pending => |p| {
            h.update(p.text);
            if (p.property) |property| switch (property) {
                .longhand => |x| hashScalar(h, @backingInt(x)),
                .shorthand => |x| hashScalar(h, @as(u64, @backingInt(x)) | 1 << 32),
            };
        },
        inline else => |payload| {
            if (comptime !computed_style.mayHoldReference(@TypeOf(payload))) {
                hashPlain(@TypeOf(payload), h, payload);
            } else {
                var out: std.ArrayList(u8) = .empty;
                defer out.deinit(scratch);
                try properties.serializeAssigned(l, .{ .value = v }, &out, scratch);
                h.update(out.items);
            }
        },
    }
}

/// The bits of a payload that holds no reference, as computed_style.identical
/// compares them.
fn hashPlain(comptime T: type, h: *std.hash.Wyhash, x: T) void {
    switch (@typeInfo(T)) {
        .float => hashScalar(h, @as(u64, @as(@Int(.unsigned, @bitSizeOf(T)), @bitCast(x)))),
        .bool => hashScalar(h, @intFromBool(x)),
        .int => hashInt(T, h, x),
        .@"enum" => |e| hashInt(e.tag_type, h, @backingInt(x)),
        .void => {},
        .optional => |o| if (x) |y| {
            hashScalar(h, 1);
            hashPlain(o.child, h, y);
        } else hashScalar(h, 0),
        .array => |a| for (x) |y| hashPlain(a.child, h, y),
        .@"struct" => |s| if (s.layout == .@"packed") {
            hashPlain(s.backing_integer.?, h, @bitCast(x));
        } else inline for (s.field_names, s.field_types) |f_name, f_type| hashPlain(f_type, h, @field(x, f_name)),
        .@"union" => switch (x) {
            inline else => |y, tag| {
                hashScalar(h, @backingInt(tag));
                hashPlain(@TypeOf(y), h, y);
            },
        },
        else => @compileError("no plain hash for " ++ @typeName(T)),
    }
}

fn hashInt(comptime T: type, h: *std.hash.Wyhash, x: T) void {
    if (comptime @bitSizeOf(T) <= 64) {
        hashScalar(h, @as(@Int(.unsigned, @bitSizeOf(T)), @bitCast(x)));
    } else h.update(std.mem.asBytes(&x));
}

fn sameAssigned(a: Assigned, b: Assigned) bool {
    return switch (a) {
        .css_wide => |k| b == .css_wide and b.css_wide == k,
        .value => |v| b == .value and sameValue(v, b.value),
    };
}

fn sameValue(a: values.Value, b: values.Value) bool {
    if (computed_style.identical(a, b)) return true;
    if (a == .pending) return b == .pending and samePending(a.pending, b.pending);
    return computed_style.interchangeable(values.Value, a, b);
}

fn sameSpecified(a: custom_properties.Specified, b: custom_properties.Specified) bool {
    return switch (a) {
        .css_wide => |k| b == .css_wide and b.css_wide == k,
        .text => |t| b == .text and t.eql(b.text),
        .pending => |p| b == .pending and samePending(p, b.pending),
    };
}

/// Two pending-substitution values the cascade substitutes alike: equal
/// (text and property) and of the same provenance, field by field (the
/// audit at DeclarationBlock.interchangeable).
fn samePending(a: *const pending_values.Pending, b: *const pending_values.Pending) bool {
    if (a == b) return true;
    if (!a.eql(b)) return false;
    if (a.quirks != b.quirks or a.svg_presentation != b.svg_presentation or a.had_resolver != b.had_resolver) return false;
    if ((a.namespaces == null) != (b.namespaces == null)) return false;
    if (a.namespaces) |n| if (n != b.namespaces.?) return false;
    // A UA declaration's -internal-auto-base(): never an element's own.
    if (a.auto_base != null or b.auto_base != null) return false;
    if (a.urls.len != b.urls.len) return false;
    for (a.urls, b.urls) |x, y| {
        if (!std.mem.eql(u8, x.raw, y.raw) or (x.resolved == null) != (y.resolved == null)) return false;
        if (x.resolved) |r| if (!std.mem.eql(u8, r, y.resolved.?)) return false;
    }
    const s = a.source orelse return b.source == null;
    const t = b.source orelse return false;
    if (s == t) return true;
    if (s.origin_clean != t.origin_clean or !std.mem.eql(u8, s.base_url, t.base_url) or
        !std.mem.eql(u8, s.referrer_policy, t.referrer_policy)) return false;
    if ((s.referrer == null) != (t.referrer == null)) return false;
    if (s.referrer) |r| if (!std.mem.eql(u8, r, t.referrer.?)) return false;
    return true;
}

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

test "page-break repair preserves every preferred shorthand in its original order" {
    const expected = [_][]const u8{
        "font",
        "border",
        "mask",
        "animation",
        "background",
        "rule-inset",
        "font-variant",
        "border-block",
        "border-inline",
        "grid",
        "rule",
        "border-image",
        "mask-border",
        "offset",
        "transition",
        "block-step",
        "border-color",
        "border-radius",
        "border-style",
        "border-width",
        "column-rule-inset",
        "corner-shape",
        "font-synthesis",
        "grid-area",
        "inset",
        "margin",
        "padding",
        "row-rule-inset",
        "rule-inset-cap",
        "rule-inset-end",
        "rule-inset-junction",
        "rule-inset-start",
        "scroll-margin",
        "scroll-padding",
        "text-decoration",
        "border-block-end",
        "border-block-start",
        "border-bottom",
        "border-inline-end",
        "border-inline-start",
        "border-left",
        "border-right",
        "border-top",
        "column-rule",
        "columns",
        "flex",
        "grid-template",
        "line-clamp",
        "list-style",
        "marker",
        "outline",
        "row-rule",
        "vertical-align",
        "-webkit-line-clamp",
        "animation-range",
        "background-position",
        "border-block-color",
        "border-block-style",
        "border-block-width",
        "border-inline-color",
        "border-inline-style",
        "border-inline-width",
        "column-rule-inset-cap",
        "column-rule-inset-end",
        "column-rule-inset-junction",
        "column-rule-inset-start",
        "contain-intrinsic-size",
        "container",
        "corner-block-end-shape",
        "corner-block-start-shape",
        "corner-bottom-shape",
        "corner-inline-end-shape",
        "corner-inline-start-shape",
        "corner-left-shape",
        "corner-right-shape",
        "corner-top-shape",
        "flex-flow",
        "gap",
        "grid-column",
        "grid-row",
        "inset-block",
        "inset-inline",
        "margin-block",
        "margin-inline",
        "overflow",
        "overscroll-behavior",
        "padding-block",
        "padding-inline",
        "place-content",
        "place-items",
        "place-self",
        "position-try",
        "row-rule-inset-cap",
        "row-rule-inset-end",
        "row-rule-inset-junction",
        "row-rule-inset-start",
        "rule-break",
        "rule-color",
        "rule-style",
        "rule-visibility-items",
        "rule-width",
        "scroll-margin-block",
        "scroll-margin-inline",
        "scroll-padding-block",
        "scroll-padding-inline",
        "text-box",
        "text-emphasis",
        "text-spacing",
        "text-wrap",
        "white-space",
        "-webkit-text-stroke",
    };
    try std.testing.expectEqual(expected.len, preferred_shorthands.len);
    for (expected, preferred_shorthands) |name, shorthand|
        try std.testing.expectEqualStrings(name, shorthand.name());
}

// ---------------------------------------------------------------------------
// Lane style1 b5: content identity (contentHash, interchangeable, snapshot).
// ---------------------------------------------------------------------------

test "a block's content hash costs no memory: DeclarationBlock and an optional one keep their sizes" {
    // The fields before the hash (main 11e1c6a8b86): an ElementStyle keeps a
    // ?DeclarationBlock by value, so a bigger block is a bigger element.
    const Before = struct {
        allocator: Allocator,
        context: DeclarationBlock.Context,
        entries: std.ArrayList(Entry),
        custom_count: u32,
    };
    try testing.expectEqual(@sizeOf(Before), @sizeOf(DeclarationBlock));
    try testing.expectEqual(@sizeOf(?Before), @sizeOf(?DeclarationBlock));
}

fn contentHashOf(text: []const u8) !u32 {
    var block = try DeclarationBlock.parse(testOptions(), text);
    defer block.deinit();
    return block.contentHash();
}

test "equal content hashes equal whatever the spelling; importance, values and names hash apart" {
    try testing.expectEqual(try contentHashOf("margin-top: 3px"), try contentHashOf("margin-top:3px;"));
    try testing.expectEqual(try contentHashOf("opacity: 0.6;"), try contentHashOf("opacity:0.6"));
    try testing.expectEqual(try contentHashOf("color: blue; --a: 1px"), try contentHashOf("color:blue;--a:1px"));
    // Unsupported declarations are kept for read-back only.
    try testing.expectEqual(try contentHashOf("margin-top: 3px"), try contentHashOf("margin-top: 3px; -crane-unknown: 1"));
    // A value with a reference (a transform list) hashes its serialization.
    try testing.expectEqual(try contentHashOf("transform: translateY(4px)"), try contentHashOf("transform:translateY(4px)"));
    try testing.expect(try contentHashOf("transform: translateY(4px)") != try contentHashOf("transform: translateY(5px)"));
    try testing.expect(try contentHashOf("margin-top: 3px") != try contentHashOf("margin-top: 3px !important"));
    try testing.expect(try contentHashOf("margin-top: 3px") != try contentHashOf("margin-top: 4px"));
    try testing.expect(try contentHashOf("margin-top: 3px") != try contentHashOf("margin-bottom: 3px"));
    try testing.expect(try contentHashOf("--a: 1px") != try contentHashOf("--b: 1px"));
    try testing.expect(try contentHashOf("width: var(--a)") != try contentHashOf("width: var(--b)"));
}

/// The hash `block` caches now, 0 when none.
fn cachedHash(block: *const DeclarationBlock) u24 {
    return std.mem.readInt(u24, &block.content_hash, .little);
}

test "every writer resets the cached content hash, and the next hash is the new content's" {
    const Write = enum { set, set_custom, set_validated, set_validated_custom, remove, css_text, append, clear };
    for (std.enums.values(Write)) |write| {
        var block = try DeclarationBlock.parse(testOptions(), "margin-top: 3px; --a: 1px");
        defer block.deinit();
        const before = block.contentHash();
        try testing.expect(cachedHash(&block) != 0);
        switch (write) {
            .set => try testing.expect(try block.setProperty(testOptions(), "margin-top", "4px", "")),
            .set_custom => try testing.expect(try block.setProperty(testOptions(), "--a", "2px", "")),
            .set_validated => {
                var assignments: std.ArrayList(Assignment) = .empty;
                defer assignments.deinit(testing.allocator);
                try testing.expect(try properties.parseDeclaration(testOptions(), .{ .longhand = .margin_top }, "5px", &assignments));
                defer for (assignments.items) |a| a.value.release();
                try testing.expect(try block.setValidatedProperty(.{ .longhand = .margin_top }, assignments.items));
            },
            .set_validated_custom => {
                const value = (try custom_properties.parse(testOptions(), "9px")).?;
                defer value.release();
                try testing.expect(try block.setValidatedCustom("--a", value));
            },
            .remove => {
                var out: std.ArrayList(u8) = .empty;
                defer out.deinit(testing.allocator);
                try testing.expect(try block.removeProperty("margin-top", &out));
            },
            .css_text => try block.setCssText(testOptions(), "margin-top: 3px; --a: 1px; color: red"),
            .append => {
                const parsed = try rules.parseDeclarationList(testing.allocator, "color: red");
                defer rules.freeDeclarationList(testing.allocator, parsed);
                try block.appendDeclarations(testOptions(), parsed);
            },
            .clear => block.clear(),
        }
        try testing.expectEqual(@as(u24, 0), cachedHash(&block));
        const after = block.contentHash();
        try testing.expect(after != before);
        // The same content parsed afresh hashes the same.
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.serialize(&out);
        try testing.expectEqual(after, try contentHashOf(out.items));
    }
}

test "a write that changes nothing keeps the cached hash" {
    var block = try DeclarationBlock.parse(testOptions(), "margin-top: 3px");
    defer block.deinit();
    const before = block.contentHash();
    try testing.expect(!try block.setProperty(testOptions(), "margin-top", "3px", ""));
    try testing.expectEqual(before, cachedHash(&block));
}

const TestUrlResolver = struct {
    prefix: []const u8,
    fn resolve(context: *const anyopaque, allocator: Allocator, raw: []const u8) ?[]u8 {
        const self: *const TestUrlResolver = @ptrCast(@alignCast(context));
        return std.mem.concat(allocator, u8, &.{ self.prefix, raw }) catch null;
    }
};

/// `text` parsed as a style attribute under `base` with referrer policy
/// `policy`, url()s resolved by prefixing the base.
fn blockUnder(text: []const u8, base: []const u8, policy: []const u8) !DeclarationBlock {
    const resolver: TestUrlResolver = .{ .prefix = base };
    const source = try values.ResourceSource.create(testing.allocator, .{ .base_url = base, .referrer_policy = policy });
    defer source.unref();
    return DeclarationBlock.parse(.{ .allocator = testing.allocator, .resource_source = source, .url_resolver = .{ .context = &resolver, .resolve = TestUrlResolver.resolve } }, text);
}

test "blocks are interchangeable only with the same declarations, importance, values and resource provenance" {
    const Pair = struct { a: []const u8, b: []const u8, base_b: []const u8 = "https://one.test/", policy_b: []const u8 = "", same: bool };
    const pairs = [_]Pair{
        .{ .a = "margin-top: 3px", .b = "margin-top:3px", .same = true },
        .{ .a = "margin-top: 3px", .b = "margin-top: 3px; -crane-unknown: 2", .same = true },
        .{ .a = "background-image: url(./a.png)", .b = "background-image: url(./a.png)", .same = true },
        .{ .a = "margin-top: 3px", .b = "margin-top: 3px !important", .same = false },
        .{ .a = "margin-top: 3px", .b = "margin-top: 4px", .same = false },
        .{ .a = "margin-top: 3px", .b = "margin-bottom: 3px", .same = false },
        .{ .a = "margin-top: 3px; color: red", .b = "color: red; margin-top: 3px", .same = false },
        .{ .a = "--a: 1px", .b = "--b: 1px", .same = false },
        .{ .a = "--a: 1px", .b = "--a: 2px", .same = false },
        .{ .a = "--a: 1px", .b = "--a: 1px !important", .same = false },
        // CSS Values 4 4.5.1: the same url() under another base or another
        // referrer policy is another request.
        .{ .a = "background-image: url(./a.png)", .b = "background-image: url(./a.png)", .base_b = "https://two.test/", .same = false },
        .{ .a = "background-image: url(./a.png)", .b = "background-image: url(./a.png)", .policy_b = "no-referrer", .same = false },
        // A pending-substitution value resolves its url()s at substitution,
        // against its own source (CSS Variables 1 2.1).
        .{ .a = "background-image: var(--u)", .b = "background-image: var(--u)", .same = true },
        .{ .a = "background-image: var(--u)", .b = "background-image: var(--u)", .base_b = "https://two.test/", .same = false },
        .{ .a = "background-image: var(--u)", .b = "background-image: var(--u)", .policy_b = "no-referrer", .same = false },
    };
    for (pairs) |pair| {
        var a = try blockUnder(pair.a, "https://one.test/", "");
        defer a.deinit();
        var b = try blockUnder(pair.b, pair.base_b, pair.policy_b);
        defer b.deinit();
        if (a.interchangeable(&b) != pair.same or b.interchangeable(&a) != pair.same) {
            std.debug.print("\ninterchangeable({s}, {s} under {s} {s}) is not {}\n", .{ pair.a, pair.b, pair.base_b, pair.policy_b, pair.same });
            return error.TestUnexpectedResult;
        }
        if (pair.same) try testing.expectEqual(a.contentHash(), b.contentHash());
    }
}

test "a snapshot keeps the content it was taken with when its block is rewritten in place" {
    var block = try DeclarationBlock.parse(testOptions(), "margin-top: 3px; --a: 1px; -crane-unknown: 2");
    defer block.deinit();
    var copy = try block.snapshot(testing.allocator);
    defer copy.deinit();
    try testing.expect(copy.interchangeable(&block));
    try testing.expectEqual(block.contentHash(), copy.contentHash());
    try testing.expect(try block.setProperty(testOptions(), "margin-top", "7px", ""));
    try testing.expect(try block.setProperty(testOptions(), "--a", "2px", ""));
    try testing.expect(!copy.interchangeable(&block));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try copy.serialize(&out);
    try testing.expectEqualStrings("margin-top: 3px; --a: 1px;", out.items);
    block.clear();
    try testing.expectEqual(@as(usize, 2), copy.entries.items.len);
}
