//! Implementation for CSSStyleDeclaration interface (CSSOM 6.6.1)
//!
//! A CSSStyleDeclaration object is a view of a CSS declaration block
//! (css.declarations.DeclarationBlock). Three kinds of block stand behind
//! one:
//!
//! - `inline_style`: an element's style attribute's block (CSSOM 7.1
//!   `element.style`), which the element keeps in its style state
//!   (dom.style.inline_style) - so the declarations outlive this object,
//!   whose wrapper the collector may take - and which every change writes
//!   back to the style attribute ("update style attribute for").
//! - `computed`: getComputedStyle()'s live, read-only view (CSSOM 7.2):
//!   every member resolves the element's computed style now
//!   (dom.style.computedStyle) and reads the resolved values of every
//!   supported longhand, in lexicographic order. It holds its element, as
//!   Blink's CSSComputedStyleDeclaration holds its Member<Element>.
//! - `rule`: a CSS rule's declaration block (CSSOM 6.4.3 CSSStyleRule
//!   `style`), which the rule (dom.style.Rule, held) owns - every change
//!   moves its sheet's version, so the sheet is compiled again for the
//!   cascade - and whose rule is `parentRule`.
//! - `detached`: a block of the object's own (an object script cannot
//!   otherwise make).
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-cssstyledeclaration-interface

const std = @import("std");
const log = std.log.scoped(.css);
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const webidl = @import("webidl");
const css = @import("css");
const dom = @import("dom");
const CSSStyleDeclaration = interfaces.CSSStyleDeclaration;

const DeclarationBlock = css.declarations.DeclarationBlock;
const properties = css.properties;

pub const State = CSSStyleDeclaration.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Facts given at construction (interfaces.X.initWith): the element whose
/// inline style this is, or the element (and pseudo-element) whose computed
/// style this is.
pub const construction_args = .{ "inline_owner", "computed_for", "rule_block_of" };

/// getComputedStyle's object: its element and pseudo-element.
pub const ComputedFor = dom.style.ComputedFor;

const Registry = runtime.InstanceRegistry(.css_style_declaration, InternalState);

/// The edge from a computed declaration to its element (dom.node_holds).
const element_slot: @import("engine").TracedSlot = .{ .name = "CSSStyleDeclaration:element" };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    kind: Kind = .detached,
    /// `inline_style`: the owner element, a raw back link - the element
    /// keeps this object ([SameObject]), not the other way.
    inline_owner: ?*runtime.Instance = null,
    inline_owner_generation: u64 = 0,
    /// `computed`: the element, held.
    computed_element: dom.node_holds.MemberHold = .{},
    pseudo: ?[]u8 = null,
    no_object: bool = false,
    /// `rule`: the rule whose block this is, held.
    rule: ?*dom.style.Rule = null,
    /// `detached`: the block.
    own: DeclarationBlock,

    pub const Kind = enum { inline_style, computed, rule, detached };

    fn deinit(self: *InternalState, instance: *runtime.Instance) void {
        if (self.kind == .computed) self.computed_element.release(instance, element_slot);
        if (self.rule) |r| r.unref();
        self.rule = null;
        if (self.pseudo) |p| self.allocator.free(p);
        self.pseudo = null;
        self.own.deinit();
    }

    fn inlineOwner(self: *const InternalState) ?*runtime.Instance {
        const owner = self.inline_owner orelse return null;
        if (runtime.SlabAllocator.generationOf(owner) != self.inline_owner_generation) return null;
        return owner;
    }
};

pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// The construction chain's own step: the state, and the facts given.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = .{ .allocator = allocator, .own = DeclarationBlock.init(allocator) };
    if (@hasField(@TypeOf(args), "inline_owner")) {
        const owner: *runtime.Instance = args.inline_owner;
        internal.kind = .inline_style;
        internal.inline_owner = owner;
        internal.inline_owner_generation = runtime.SlabAllocator.generationOf(owner);
    }
    if (@hasField(@TypeOf(args), "computed_for")) {
        const target: ComputedFor = args.computed_for;
        internal.kind = .computed;
        internal.no_object = target.no_object;
        if (target.pseudo) |p| internal.pseudo = try allocator.dupe(u8, p);
        internal.computed_element.take(instance, target.element, element_slot);
    }
    if (@hasField(@TypeOf(args), "rule_block_of")) {
        const rule: *dom.style.Rule = args.rule_block_of;
        internal.kind = .rule;
        internal.rule = rule;
        rule.ref();
    }
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    if (Registry.get(instance)) |internal| internal.deinit(instance);
    Registry.remove(instance);
}

// ============================================================================
// The block behind the object
// ============================================================================

/// The block of a non-computed declaration: the element's inline block, or
/// the object's own.
fn writableBlock(internal: *InternalState) !?*DeclarationBlock {
    return switch (internal.kind) {
        .detached => &internal.own,
        .inline_style => blk: {
            const owner = internal.inlineOwner() orelse break :blk null;
            break :blk try dom.style.inline_style.blockOf(owner);
        },
        .rule => if (internal.rule) |r| r.block() else null,
        .computed => null,
    };
}

fn parseOptions(instance: *runtime.Instance, internal: *InternalState, text: []const u8) std.mem.Allocator.Error!dom.style.engine.resource_loading.ParseContext {
    if (internal.kind == .inline_style) if (internal.inlineOwner()) |owner| return dom.style.inline_style.parseOptions(owner, text);
    if (internal.kind == .rule) if (internal.rule) |r| {
        if (r.sheet()) |sheet| return dom.style.engine.resource_loading.ParseContext.forSheet(sheet, instance, text);
        return .{ .parse = .{ .allocator = r.allocator } };
    };
    return .{ .parse = .{ .allocator = internal.allocator } };
}

/// After a change: a rule's sheet is compiled again; an inline block runs
/// CSSOM "update style attribute for".
fn changed(internal: *InternalState) !void {
    if (internal.kind == .rule) {
        if (internal.rule) |r| if (r.sheet()) |s| s.changed();
        return;
    }
    if (internal.kind != .inline_style) return;
    const owner = internal.inlineOwner() orelse return;
    try dom.style.inline_style.updateStyleAttribute(owner);
}

/// A computed declaration's style, resolved now; null when its declarations
/// are empty (CSSOM 7.2 step 5's conditions fail).
fn computedStyleOf(internal: *InternalState) !?*const css.computed_style.ComputedStyle {
    if (internal.no_object) return null;
    const element = internal.computed_element.get() orelse return null;
    if (!try dom.style.hasComputedStyle(element)) return null;
    return dom.style.computedStyle(element, internal.pseudo);
}

fn ownedString(allocator: std.mem.Allocator, bytes: []const u8) !runtime.DOMString {
    if (bytes.len == 0) return runtime.DOMString.initEmpty();
    return runtime.DOMString.initOwned(try allocator.dupe(u8, bytes));
}

// ============================================================================
// Attributes
// ============================================================================

/// cssText getter: "If the computed flag is set, then return the empty
/// string. Return the result of serializing the declarations."
pub fn get_cssText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    const block = (try writableBlock(internal)) orelse return runtime.DOMString.initEmpty();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(internal.allocator);
    try block.serialize(&out);
    return ownedString(instance.ctx.allocator, out.items);
}

/// cssText setter: "If the readonly flag is set, then throw a
/// NoModificationAllowedError exception." Then the declarations are
/// replaced by the parse of the value, and the style attribute updated.
pub fn set_cssText(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.kind == .rule) if (internal.rule) |rule| if (rule.kind() == .font_face) {
        var context = try parseOptions(instance, internal, value.asSlice());
        defer context.deinit();
        try rule.data.font_face.setCssText(context.options(), value.asSlice());
        try changed(internal);
        return;
    };
    if (internal.kind == .computed) return error.NoModificationAllowedError;
    const block = (try writableBlock(internal)) orelse return;
    var context = try parseOptions(instance, internal, value.asSlice());
    defer context.deinit();
    try block.setCssText(context.options(), value.asSlice());
    try changed(internal);
}

/// length: the number of declarations - for a computed declaration, every
/// supported longhand (CSSOM 7.2 step 5).
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    if (internal.kind == .computed) {
        return if ((try computedStyleOf(internal)) != null) @intCast(properties.Longhand.count) else 0;
    }
    const block = (try writableBlock(internal)) orelse return 0;
    return @intCast(block.length());
}

/// parentRule: "the CSS rule the CSS declaration block is associated
/// with" - a rule's block's rule; null for an inline or computed block.
pub fn get_parentRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const rule = internal.rule orelse return null;
    return try dom.style.objects.ruleObject(rule, instance.ctx);
}

// ============================================================================
// Operations
// ============================================================================

/// item(index): "If index is greater than or equal to the number of
/// declarations, return the empty string. Return the property name of the
/// declaration at position index."
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!typedefs.CSSOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    if (internal.kind == .computed) {
        if ((try computedStyleOf(internal)) == null or index >= properties.Longhand.count) return runtime.DOMString.initEmpty();
        return runtime.DOMString.initInterned(properties.lexicographic[index].name());
    }
    const block = (try writableBlock(internal)) orelse return runtime.DOMString.initEmpty();
    const name = block.item(index) orelse return runtime.DOMString.initEmpty();
    return ownedString(instance.ctx.allocator, name);
}

/// getPropertyValue(property).
pub fn call_getPropertyValue(instance: *runtime.Instance, property: typedefs.CSSOMString) anyerror!typedefs.CSSOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    if (internal.kind == .rule) if (internal.rule) |rule| if (rule.kind() == .font_face)
        return ownedString(instance.ctx.allocator, dom.style.engine.resource_loading.font_loading.descriptorValue(rule.block().?, property.asSlice()));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(internal.allocator);
    if (internal.kind == .computed) {
        try computedValue(internal, property.asSlice(), &out);
    } else {
        const block = (try writableBlock(internal)) orelse return runtime.DOMString.initEmpty();
        try block.getPropertyValue(property.asSlice(), &out);
    }
    return ownedString(instance.ctx.allocator, out.items);
}

/// A computed declaration's getPropertyValue: a longhand's resolved value;
/// a shorthand's serialization from its longhands' (6.6.1 step 2; every
/// longhand of a supported shorthand is supported, so it always serializes
/// unless the shorthand cannot represent them).
fn computedValue(internal: *InternalState, name: []const u8, out: *std.ArrayList(u8)) !void {
    const style = (try computedStyleOf(internal)) orelse return;
    const property = properties.lookup(name) orelse return;
    switch (property) {
        .longhand => |l| try style.serializeResolved(l, out, internal.allocator),
        .shorthand => |s| {
            if (s == .all) return;
            var resolved: [properties.max_assignments]css.style_values.Value = undefined;
            var assigned: [properties.max_assignments]properties.Assigned = undefined;
            var initialized: usize = 0;
            defer for (resolved[0..initialized]) |value| value.release();
            for (s.longhands(), 0..) |l, i| {
                const value = style.get(l);
                if (value == .color) {
                    resolved[i] = .{ .color = try style.resolvedColor(l, internal.allocator) };
                } else if (value == .image or value == .layers or value == .content) {
                    resolved[i] = try style.resolvedImageValue(l, internal.allocator);
                } else {
                    value.retain();
                    resolved[i] = value;
                }
                initialized += 1;
                assigned[i] = .{ .value = resolved[i] };
            }
            const start = out.items.len;
            if (!try properties.serializeShorthand(s, assigned[0..s.longhands().len], .computed, out, internal.allocator)) out.shrinkRetainingCapacity(start);
        },
    }
}

/// getPropertyPriority(property): "important" or "".
pub fn call_getPropertyPriority(instance: *runtime.Instance, property: typedefs.CSSOMString) anyerror!typedefs.CSSOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    if (internal.kind == .rule) if (internal.rule) |rule| if (rule.kind() == .font_face) return runtime.DOMString.initEmpty();
    if (internal.kind == .computed) return runtime.DOMString.initEmpty();
    const block = (try writableBlock(internal)) orelse return runtime.DOMString.initEmpty();
    return if (block.getPropertyPriority(property.asSlice())) runtime.DOMString.initInterned("important") else runtime.DOMString.initEmpty();
}

/// setProperty(property, value, priority): "1. If the readonly flag is set,
/// then throw a NoModificationAllowedError exception." Then 6.6.1's steps;
/// "If updated is true, update style attribute for the CSS declaration
/// block."
pub fn call_setProperty(instance: *runtime.Instance, property: typedefs.CSSOMString, value: typedefs.CSSOMString, priority: webidl.Opt(typedefs.CSSOMString)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.kind == .rule) if (internal.rule) |rule| if (rule.kind() == .font_face) {
        const priority_text = if (priority.wasPassed()) priority.getValue().asSlice() else "";
        var context = try parseOptions(instance, internal, value.asSlice());
        defer context.deinit();
        if (try rule.data.font_face.setProperty(context.options(), property.asSlice(), value.asSlice(), priority_text)) try changed(internal);
        return;
    };
    if (internal.kind == .computed) return error.NoModificationAllowedError;
    const block = (try writableBlock(internal)) orelse return;
    const prio: []const u8 = if (priority.wasPassed()) priority.getValue().asSlice() else "";
    var context = try parseOptions(instance, internal, value.asSlice());
    defer context.deinit();
    if (try block.setProperty(context.options(), property.asSlice(), value.asSlice(), prio)) try changed(internal);
}

/// removeProperty(property): the readonly check, then 6.6.1's steps; the
/// old value returned.
pub fn call_removeProperty(instance: *runtime.Instance, property: typedefs.CSSOMString) anyerror!typedefs.CSSOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.kind == .rule) if (internal.rule) |rule| if (rule.kind() == .font_face) {
        const previous = try internal.allocator.dupe(u8, dom.style.engine.resource_loading.font_loading.descriptorValue(rule.block().?, property.asSlice()));
        defer internal.allocator.free(previous);
        if (try rule.data.font_face.setProperty(.{ .allocator = internal.allocator }, property.asSlice(), "", "")) try changed(internal);
        return ownedString(instance.ctx.allocator, previous);
    };
    if (internal.kind == .computed) return error.NoModificationAllowedError;
    const block = (try writableBlock(internal)) orelse return runtime.DOMString.initEmpty();
    var old: std.ArrayList(u8) = .empty;
    defer old.deinit(internal.allocator);
    if (try block.removeProperty(property.asSlice(), &old)) try changed(internal);
    return ownedString(instance.ctx.allocator, old.items);
}

// ============================================================================
// The camel-cased and dashed attributes (CSSOM 6.6.1 "CSS property to IDL
// attribute"), through the binding's named handlers
// ============================================================================

/// The CSS property an attribute name `name` stands for: the dashed name
/// itself, or the camel-cased one converted back ("IDL attribute to CSS
/// property": a hyphen before each uppercase letter, which is lowercased),
/// with `cssFloat` for `float`. Null when it is neither.
fn propertyNameOf(name: []const u8, buffer: []u8) ?[]const u8 {
    if (std.mem.eql(u8, name, "cssFloat")) return "float";
    if (properties.lookup(name) != null and !hasUpper(name)) return name;
    var n: usize = 0;
    // CSSOM 6.6.2, IDL attribute to CSS property step 2: the
    // webkit-cased attribute sets the dash-prefix flag.
    if (std.mem.startsWith(u8, name, "webkit") and name.len > 6 and std.ascii.isUpper(name[6])) {
        if (buffer.len == 0) return null;
        buffer[0] = '-';
        n = 1;
    }
    for (name) |c| {
        if (n + 2 > buffer.len) return null;
        if (c >= 'A' and c <= 'Z') {
            buffer[n] = '-';
            buffer[n + 1] = c + 32;
            n += 2;
        } else {
            buffer[n] = c;
            n += 1;
        }
    }
    return buffer[0..n];
}

fn hasUpper(name: []const u8) bool {
    for (name) |c| if (c >= 'A' and c <= 'Z') return true;
    return false;
}

/// The named getter: a supported property's value ("" when it has none);
/// for an unsupported name, the value a parsed declaration of it kept for
/// read-back, if any - otherwise not handled (the ordinary property
/// lookup answers: undefined, or the prototype's member).
pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return null;
    var buffer: [256]u8 = undefined;
    const property = propertyNameOf(name.asSlice(), &buffer) orelse return null;
    const supported = properties.lookup(property) != null;
    if (!supported) {
        if (internal.kind == .computed) return null;
        const block = (try writableBlock(internal)) orelse return null;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(internal.allocator);
        try block.getPropertyValue(property, &out);
        if (out.items.len == 0) return null;
        return try ownedString(instance.ctx.allocator, out.items);
    }
    return try call_getPropertyValue(instance, runtime.DOMString.initInterned(property));
}

/// The named setter: setProperty(property, value) for a supported property
/// (an empty value removes it).
pub fn call_setNamedItem(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    var buffer: [256]u8 = undefined;
    const property = propertyNameOf(name.asSlice(), &buffer) orelse return;
    if (properties.lookup(property) == null) return;
    if (internal.kind == .computed) return error.NoModificationAllowedError;
    // CSSOM 6.6.1: a named CSS setter invokes setProperty. Use its generated
    // interface so HTML CEReactions steps 1-6 finish before this setter returns.
    return interfaces.CSSStyleDeclaration.call_setProperty(instance, runtime.DOMString.initInterned(property), value, webidl.Opt(typedefs.CSSOMString).notPassed());
}

/// The names the binding's named handlers answer for: every supported CSS
/// property (dashed - the binding matches a camel-cased key through its
/// dashed form), `cssFloat`, and the property of any declaration kept for
/// read-back. A name not here falls through to the ordinary property
/// lookup: `cssText`, `length`, an expando.
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    var names: std.ArrayList(runtime.DOMString) = .empty;
    errdefer names.deinit(allocator);
    for (properties.lexicographic) |l| try names.append(allocator, runtime.DOMString.initInterned(l.name()));
    inline for (@typeInfo(properties.Shorthand).@"enum".fields) |field| {
        try appendPropertyNames(&names, allocator, comptime @as(properties.Shorthand, @enumFromInt(field.value)).name());
    }
    inline for (properties.legacy_alias_names) |name| try appendPropertyNames(&names, allocator, name);
    try names.append(allocator, runtime.DOMString.initInterned("cssFloat"));
    const internal = getInternal(instance) orelse return names.toOwnedSlice(allocator);
    if (internal.kind != .computed) {
        if (writableBlock(internal) catch null) |block| {
            for (block.entries.items) |*entry| if (entry.* == .unparsed) {
                try names.append(allocator, runtime.DOMString.initOwned(try allocator.dupe(u8, entry.name())));
            };
        }
    }
    return names.toOwnedSlice(allocator);
}

fn appendPropertyNames(names: *std.ArrayList(runtime.DOMString), allocator: std.mem.Allocator, comptime name: []const u8) !void {
    try names.append(allocator, runtime.DOMString.initInterned(name));
    // CSSOM 6.6.2: prefixed supported properties expose both WebkitFoo
    // and webkitFoo. Build the constant names once, not on each lookup.
    if (comptime std.mem.startsWith(u8, name, "-webkit-")) {
        try names.append(allocator, runtime.DOMString.initInterned(comptime prefixedAttribute(name, false)));
        try names.append(allocator, runtime.DOMString.initInterned(comptime prefixedAttribute(name, true)));
    }
}

fn prefixedAttribute(comptime property: []const u8, comptime lowercase_first: bool) []const u8 {
    var buffer: [property.len]u8 = undefined;
    var length: usize = 0;
    var upper = false;
    for (property[@intFromBool(lowercase_first)..]) |c| {
        if (c == '-') {
            upper = true;
        } else {
            buffer[length] = if (upper) std.ascii.toUpper(c) else c;
            length += 1;
            upper = false;
        }
    }
    const result = buffer;
    return result[0..length];
}

/// CSSOM "CSS property to IDL attribute": each hyphen and the letter after
/// it become that letter uppercased.
fn camelCased(allocator: std.mem.Allocator, property: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var upper = false;
    for (property) |c| {
        if (c == '-') {
            upper = true;
            continue;
        }
        try out.append(allocator, if (upper) std.ascii.toUpper(c) else c);
        upper = false;
    }
    return out.toOwnedSlice(allocator);
}

test "attribute names map to CSS properties" {
    var buffer: [256]u8 = undefined;
    try std.testing.expectEqualStrings("background-color", propertyNameOf("backgroundColor", &buffer).?);
    try std.testing.expectEqualStrings("margin-left", propertyNameOf("margin-left", &buffer).?);
    try std.testing.expectEqualStrings("float", propertyNameOf("cssFloat", &buffer).?);
    try std.testing.expectEqualStrings("-webkit-user-select", propertyNameOf("webkitUserSelect", &buffer).?);
    try std.testing.expectEqualStrings("-webkit-user-select", propertyNameOf("WebkitUserSelect", &buffer).?);
    const camel = try camelCased(std.testing.allocator, "border-top-left-radius");
    defer std.testing.allocator.free(camel);
    try std.testing.expectEqualStrings("borderTopLeftRadius", camel);
}

comptime {
    _ = log;
}
