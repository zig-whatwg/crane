//! WebIDL 2.5.6 special operations: which of an interface's operations (its
//! own, or the derived-most one it inherits) is its indexed or named property
//! getter, setter or deleter, and which generated function runs each.
//!
//! The model is written into the interface's Meta as
//! `special_operations: webidl.SpecialOperations` (src/webidl/
//! special_operations.zig), and the engine adapter installs a legacy platform
//! object's exotic internal methods (WebIDL 3.9) from it - never from function
//! names. The function names are the binding map's own: `call_<identifier>`
//! for an operation declared with an identifier (it is a regular operation
//! too, WebIDL 2.5.3), and for an anonymous one `call_<keyword>`, numbered
//! `call_<keyword>__<k>` when the interface declares more than one anonymous
//! operation of that keyword - HTMLFormElement's `getter Element (unsigned
//! long index)` is `call_getter`, its `getter (RadioNodeList or Element)
//! (DOMString name)` `call_getter__1`, in declaration order.
const std = @import("std");
const types = @import("types.zig");
const ir_mod = @import("ir.zig");

pub const Kind = enum {
    indexed_getter,
    indexed_setter,
    named_getter,
    named_setter,
    named_deleter,

    fn isNamed(self: Kind) bool {
        return switch (self) {
            .named_getter, .named_setter, .named_deleter => true,
            else => false,
        };
    }
};

/// The variety of special operation `op` is, or null when it is none -
/// WebIDL 2.5.6: "Getters and setters come in two varieties: ones that take a
/// DOMString as a property name, known as named property getters and named
/// property setters, and ones that take an unsigned long as a property index,
/// known as indexed property getters and indexed property setters. There is
/// only one variety of deleter: named property deleters." A stringifier is
/// not one of these.
pub fn kindOf(op: types.Operation) ?Kind {
    const special = op.special orelse return null;
    if (op.static or op.arguments.len == 0) return null;
    const first = op.arguments[0].idlType.type;
    const indexed = std.mem.eql(u8, first, "unsigned long");
    return switch (special) {
        .getter => if (op.arguments.len != 1) null else if (indexed) .indexed_getter else .named_getter,
        .setter => if (op.arguments.len != 2) null else if (indexed) .indexed_setter else .named_setter,
        .deleter => if (op.arguments.len != 1 or indexed) null else .named_deleter,
        .stringifier => null,
    };
}

/// Whether `op` is an anonymous getter, setter or deleter - one whose
/// delegate is named after its keyword (see `anonymousFunctions`).
pub fn isAnonymous(op: types.Operation) bool {
    const special = op.special orelse return false;
    return op.name == null and !op.static and special != .stringifier;
}

/// An anonymous getter, setter or deleter of an interface, and the name of
/// its delegate.
pub const Anonymous = struct {
    op: types.Operation,
    /// `call_getter`, `call_getter__1`, `call_setter`, `call_deleter`.
    function: []const u8,
};

/// `operations`' anonymous getters, setters and deleters in declaration
/// order, each with its delegate's name: `call_<keyword>` for the first of
/// its keyword and `call_<keyword>__<k>` for the k-th after it. A repeated
/// declaration (the same keyword and argument types, from two IDL sources) is
/// one operation. The generated delegates and the Meta table both take their
/// names from here. The caller frees the slice and each `function`
/// (`freeAnonymous`).
pub fn anonymousFunctions(allocator: std.mem.Allocator, operations: []const types.Operation) ![]Anonymous {
    var list: std.ArrayList(Anonymous) = .empty;
    errdefer freeAnonymous(allocator, list.items);
    defer list.deinit(allocator);
    for (operations) |op| {
        if (!isAnonymous(op)) continue;
        const keyword = @tagName(op.special.?);
        var k: usize = 0;
        const repeated = for (list.items) |seen| {
            if (seen.op.special.? != op.special.?) continue;
            if (sameArgumentTypes(seen.op, op)) break true;
            k += 1;
        } else false;
        if (repeated) continue;
        const function = if (k == 0)
            try std.fmt.allocPrint(allocator, "call_{s}", .{keyword})
        else
            try std.fmt.allocPrint(allocator, "call_{s}__{d}", .{ keyword, k });
        errdefer allocator.free(function);
        try list.append(allocator, .{ .op = op, .function = function });
    }
    return list.toOwnedSlice(allocator);
}

pub fn freeAnonymous(allocator: std.mem.Allocator, list: []const Anonymous) void {
    for (list) |a| allocator.free(a.function);
    allocator.free(list);
}

fn sameArgumentTypes(a: types.Operation, b: types.Operation) bool {
    if (a.arguments.len != b.arguments.len) return false;
    for (a.arguments, b.arguments) |x, y| {
        if (!std.mem.eql(u8, x.idlType.type, y.idlType.type)) return false;
    }
    return true;
}

/// The special operations the IDL declares and no browser binds (AGENTS.md
/// golden rule 2: where the browsers and the spec text disagree, Crane does
/// what the browsers do). An interface named here does not record the named
/// properties of `kind`'s variety - named getter, setter and deleter go
/// together, since a setter or deleter needs the getter (WebIDL 2.5.6).
const browser_exceptions = [_]struct { interface: []const u8, kind: Kind }{
    // Touch Events (https://w3c.github.io/touch-events/#touchevent-interface,
    // checked 2026-10-11) declares `getter boolean getModifierState(DOMString
    // keyArg)`, which would make every TouchEvent a legacy platform object
    // whose every unknown property reads getModifierState(name). Chrome
    // (third_party/blink/renderer/core/events/touch_event.idl), Firefox
    // (dom/webidl/TouchEvent.webidl) and Safari (Source/WebCore/dom/
    // TouchEvent.idl) declare no getModifierState on TouchEvent at all; the
    // operation stays a regular one here.
    .{ .interface = "TouchEvent", .kind = .named_getter },
    // HTML declares Document's named getter on `partial interface Document`
    // (html.idl), so XMLDocument would inherit it. Firefox (dom/webidl/
    // HTMLDocument.webidl, `getter object (DOMString name)`) and Safari
    // (Source/WebCore/html/HTMLDocument.idl) declare it on HTMLDocument, and
    // Chrome implements it by hand for HTML documents (core/dom/document.idl:
    // "Named getter is implemented without IDL code generation"): none gives
    // an XMLDocument named properties.
    .{ .interface = "XMLDocument", .kind = .named_getter },
};

/// The interfaces whose named properties no browser lists in
/// [[OwnPropertyKeys]] (WebIDL 3.9.6 step 3), though each finds them by named
/// lookup (golden rule 2): their table says `named_properties_in_own_keys =
/// false`, and the binding leaves the names out of the key list only.
const own_keys_without_names = [_][]const u8{
    // HTML's supported property names of a form (4.10.3) are its controls'
    // and images' names and ids. WebKit's HTMLFormElement::
    // supportedPropertyNames() returns {} ("FIXME: Should be implemented
    // (only needed for enumeration with includeDontEnumProperties mode since
    // this class is annotated with LegacyUnenumerableNamedProperties)"),
    // Gecko's HTMLFormElement::GetSupportedNames is empty ("TODO
    // https://github.com/whatwg/html/issues/1731"), and Blink declares the
    // named getter [NotEnumerable] (core/html/forms/html_form_element.idl),
    // for which bind_gen/interface.py installs no named enumerator - all
    // three keep named lookup. Checked 2026-10-12.
    "HTMLFormElement",
};

fn omitsNamesFromOwnKeys(interface_name: []const u8) bool {
    for (own_keys_without_names) |name| {
        if (std.mem.eql(u8, name, interface_name)) return true;
    }
    return false;
}

fn isBrowserException(interface_name: []const u8, kind: Kind) bool {
    for (browser_exceptions) |e| {
        if (!std.mem.eql(u8, e.interface, interface_name)) continue;
        if (e.kind == kind or (e.kind.isNamed() and kind.isNamed())) return true;
    }
    return false;
}

/// One special operation of an interface.
pub const Entry = struct {
    /// The generated function that runs it (owned by the model).
    function: []const u8,
    /// Declared without an identifier: its delegate is gated on the impl.
    anonymous: bool,
    /// Null for the interface's own; otherwise its parent, which declares or
    /// inherits it and whose generated file the heir takes it from.
    inherited_from: ?[]const u8 = null,
    /// One of CSSOM's camelCase properties, which Crane's binding serves as
    /// named properties of the CSS declaration interfaces
    /// (writer.writeCSSPropertyNamedHandlers) - not of the IDL, and not
    /// inherited by their other heirs.
    crane_css: bool = false,
};

pub const Model = struct {
    entries: std.EnumArray(Kind, ?Entry) = .initFill(null),
    legacy_override_built_ins: bool = false,
    legacy_unenumerable_named_properties: bool = false,
    /// webidl.SpecialOperations.named_properties_in_own_keys: true unless the
    /// interface, or the parent whose named getter it inherits, is one of
    /// `own_keys_without_names`.
    named_properties_in_own_keys: bool = true,

    pub fn get(self: *const Model, kind: Kind) ?Entry {
        return self.entries.get(kind);
    }

    /// Whether the interface has any special operation - no table otherwise.
    pub fn any(self: *const Model) bool {
        for (std.enums.values(Kind)) |kind| if (self.entries.get(kind) != null) return true;
        return false;
    }

    pub fn deinit(self: *Model, allocator: std.mem.Allocator) void {
        for (std.enums.values(Kind)) |kind| if (self.entries.get(kind)) |e| allocator.free(e.function);
        self.* = .{};
    }
};

fn hasExtAttr(ext_attrs: []const types.ExtendedAttribute, name: []const u8) bool {
    for (ext_attrs) |attr| if (std.mem.eql(u8, attr.name, name)) return true;
    return false;
}

/// The special operations of interface `name`: its own, from `operations`
/// (every operation it declares, partials merged), then for every variety it
/// does not declare the one its parent has (WebIDL 3.9: the derived-most
/// interface's), with [LegacyOverrideBuiltIns] and
/// [LegacyUnenumerableNamedProperties] from it or any ancestor ("it applies to
/// all its derived interfaces", 3.4.9). Without a model only its own count.
/// `css_declaration`: one of the interfaces Crane gives CSSOM's camelCase
/// named properties.
pub fn build(
    allocator: std.mem.Allocator,
    model: ?*ir_mod.IR,
    name: []const u8,
    operations: []const types.Operation,
    ext_attrs: []const types.ExtendedAttribute,
    parent: ?[]const u8,
    css_declaration: bool,
) error{OutOfMemory}!Model {
    var result: Model = .{};
    errdefer result.deinit(allocator);

    // Own: the first of each variety (an interface has at most one, 2.5.6).
    const anonymous = try anonymousFunctions(allocator, operations);
    defer freeAnonymous(allocator, anonymous);
    for (operations) |op| {
        const kind = kindOf(op) orelse continue;
        if (result.entries.get(kind) != null) continue;
        const function = if (op.name) |op_name|
            try std.fmt.allocPrint(allocator, "call_{s}", .{op_name})
        else for (anonymous) |a| {
            if (a.op.special.? == op.special.? and sameArgumentTypes(a.op, op)) break try allocator.dupe(u8, a.function);
        } else unreachable;
        result.entries.set(kind, .{ .function = function, .anonymous = op.name == null });
    }
    if (css_declaration) {
        // writer.writeCSSPropertyNamedHandlers' delegates.
        if (result.entries.get(.named_getter) == null) result.entries.set(.named_getter, .{ .function = try allocator.dupe(u8, "call_namedItem"), .anonymous = false, .crane_css = true });
        if (result.entries.get(.named_setter) == null) result.entries.set(.named_setter, .{ .function = try allocator.dupe(u8, "call_setNamedItem"), .anonymous = false, .crane_css = true });
    }
    result.legacy_override_built_ins = hasExtAttr(ext_attrs, "LegacyOverrideBuiltIns");
    result.legacy_unenumerable_named_properties = hasExtAttr(ext_attrs, "LegacyUnenumerableNamedProperties");

    // Inherited: what the parent has (its own and its ancestors').
    if (model) |m| if (parent) |parent_name| if (m.interfaces.get(parent_name)) |p| {
        var parent_ops: std.ArrayList(types.Operation) = .empty;
        defer parent_ops.deinit(allocator);
        for (p.members.items) |member| {
            if (member.type == .operation) if (member.operation) |op| try parent_ops.append(allocator, op);
        }
        var inherited = try build(allocator, m, parent_name, parent_ops.items, p.extAttrs.items, p.inheritance, false);
        defer inherited.deinit(allocator);
        // Each variety separately: an heir that redeclares only the named
        // getter (HTMLFormControlsCollection's namedItem) keeps whatever
        // setter or deleter its parent has.
        for (std.enums.values(Kind)) |kind| {
            if (result.entries.get(kind) != null) continue;
            const e = inherited.entries.get(kind) orelse continue;
            if (e.crane_css) continue;
            result.entries.set(kind, .{ .function = try allocator.dupe(u8, e.function), .anonymous = e.anonymous, .inherited_from = parent_name });
            // An inherited named getter's names go where its declarer's do.
            if (kind == .named_getter) result.named_properties_in_own_keys = inherited.named_properties_in_own_keys;
        }
        result.legacy_override_built_ins = result.legacy_override_built_ins or inherited.legacy_override_built_ins;
        result.legacy_unenumerable_named_properties = result.legacy_unenumerable_named_properties or inherited.legacy_unenumerable_named_properties;
    };

    // The browsers' exceptions, and the named varieties' rule that a setter
    // or deleter needs a getter.
    for (std.enums.values(Kind)) |kind| {
        if (!isBrowserException(name, kind)) continue;
        if (result.entries.get(kind)) |e| allocator.free(e.function);
        result.entries.set(kind, null);
    }
    if (result.entries.get(.named_getter) == null) {
        for ([_]Kind{ .named_setter, .named_deleter }) |kind| {
            if (result.entries.get(kind)) |e| allocator.free(e.function);
            result.entries.set(kind, null);
        }
    }
    if (result.entries.get(.indexed_getter) == null) {
        if (result.entries.get(.indexed_setter)) |e| allocator.free(e.function);
        result.entries.set(.indexed_setter, null);
    }
    if (omitsNamesFromOwnKeys(name)) result.named_properties_in_own_keys = false;
    if (result.entries.get(.named_getter) == null) {
        // The extended attributes are about named properties only.
        result.legacy_override_built_ins = false;
        result.legacy_unenumerable_named_properties = false;
        result.named_properties_in_own_keys = true;
    }
    return result;
}

/// Meta's table, inside `pub const Meta = struct {`:
///
///         pub const special_operations: webidl.SpecialOperations = .{
///             .named_getter = .{ .function = "call_getItem" },
///             ...
///         };
///
/// Nothing for an interface with no special operation. An anonymous
/// operation's `.implemented` is its impl's @hasDecl (its delegate is gated);
/// an inherited anonymous one's is its parent's entry.
pub fn writeMeta(writer: anytype, model: *const Model, interface_name: []const u8) !void {
    if (!model.any()) return;
    try writer.writeAll("        \n");
    try writer.writeAll("        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):\n");
    try writer.writeAll("        /// the function that runs each. The binding installs indexed and named\n");
    try writer.writeAll("        /// property handlers from this table (webidl.SpecialOperations).\n");
    try writer.writeAll("        pub const special_operations: webidl.SpecialOperations = .{\n");
    for (std.enums.values(Kind)) |kind| {
        const e = model.get(kind) orelse continue;
        try writer.print("            .{s} = .{{ .function = \"{s}\"", .{ @tagName(kind), e.function });
        if (e.anonymous) {
            if (e.inherited_from) |parent| {
                try writer.print(", .implemented = {s}.Meta.special_operations.{s}.?.implemented", .{ parent, @tagName(kind) });
            } else {
                try writer.print(", .implemented = @hasDecl({s}Impl, \"{s}\")", .{ interface_name, e.function });
            }
        }
        try writer.writeAll(" },\n");
    }
    if (model.legacy_override_built_ins) try writer.writeAll("            .legacy_override_built_ins = true,\n");
    if (model.legacy_unenumerable_named_properties) try writer.writeAll("            .legacy_unenumerable_named_properties = true,\n");
    if (!model.named_properties_in_own_keys) try writer.writeAll("            .named_properties_in_own_keys = false,\n");
    if (model.get(.named_getter)) |e| if (e.crane_css) try writer.writeAll("            .crane_css_properties = true,\n");
    try writer.writeAll("        };\n");
}

/// What an heir takes from its parent to run the special operations it
/// inherits: each one's function, `get_length` for an indexed getter (the
/// supported indices are those below it), and `getSupportedPropertyNames` for
/// a named getter - all its parent's, which declares or inherits them.
/// Prototype inheritance alone does not publish the declarations the adapter
/// installs the exotic operations from. A name the heir declares itself is
/// not written again.
pub fn writeInherited(
    writer: anytype,
    model: *const Model,
    parent: []const u8,
    own_operations: []const types.Operation,
    own_attributes: []const types.Attribute,
    all_attributes: []const types.Attribute,
) !void {
    var written: [std.enums.values(Kind).len][]const u8 = undefined;
    var count: usize = 0;
    for (std.enums.values(Kind)) |kind| {
        const e = model.get(kind) orelse continue;
        if (e.inherited_from == null) continue;
        const already = for (written[0..count]) |w| {
            if (std.mem.eql(u8, w, e.function)) break true;
        } else false;
        if (already) continue;
        const own = for (own_operations) |op| {
            const op_name = op.name orelse continue;
            if (std.mem.eql(u8, e.function["call_".len..], op_name)) break true;
        } else false;
        if (own) continue;
        try writer.print("    pub const {s} = {s}.{s};\n\n", .{ e.function, parent, e.function });
        written[count] = e.function;
        count += 1;
    }
    if (model.get(.indexed_getter) != null) length: {
        for (own_attributes) |attr| if (std.mem.eql(u8, attr.name, "length")) break :length;
        for (all_attributes) |attr| if (std.mem.eql(u8, attr.name, "length")) {
            try writer.print("    pub const get_length = {s}.get_length;\n\n", .{parent});
            break :length;
        };
    }
    if (model.get(.named_getter)) |e| if (e.inherited_from != null) {
        try writer.print("    pub const getSupportedPropertyNames = {s}.getSupportedPropertyNames;\n\n", .{parent});
    };
}

/// Whether the interface writes its own `getSupportedPropertyNames`, to its
/// impl: it declares a named getter of the IDL's (a CSS declaration
/// interface's comes with writeCSSPropertyNamedHandlers).
pub fn ownsSupportedPropertyNames(model: *const Model) bool {
    const e = model.get(.named_getter) orelse return false;
    return e.inherited_from == null and !e.crane_css;
}

test "kindOf: the variety is the first argument's type, and a stringifier is none" {
    var index = [_]types.Argument{.{ .name = "i", .idlType = .{ .type = "unsigned long" } }};
    var name = [_]types.Argument{.{ .name = "n", .idlType = .{ .type = "DOMString" } }};
    var index_value = [_]types.Argument{ index[0], .{ .name = "v", .idlType = .{ .type = "any" } } };
    var name_value = [_]types.Argument{ name[0], .{ .name = "v", .idlType = .{ .type = "any" } } };
    try std.testing.expectEqual(Kind.indexed_getter, kindOf(.{ .idlType = .{ .type = "any" }, .arguments = &index, .special = .getter }).?);
    try std.testing.expectEqual(Kind.named_getter, kindOf(.{ .idlType = .{ .type = "any" }, .arguments = &name, .special = .getter }).?);
    try std.testing.expectEqual(Kind.indexed_setter, kindOf(.{ .idlType = .{ .type = "undefined" }, .arguments = &index_value, .special = .setter }).?);
    try std.testing.expectEqual(Kind.named_setter, kindOf(.{ .idlType = .{ .type = "undefined" }, .arguments = &name_value, .special = .setter }).?);
    try std.testing.expectEqual(Kind.named_deleter, kindOf(.{ .idlType = .{ .type = "undefined" }, .arguments = &name, .special = .deleter }).?);
    try std.testing.expectEqual(@as(?Kind, null), kindOf(.{ .idlType = .{ .type = "DOMString" }, .special = .stringifier }));
    // The default: a regular operation is no special one, whatever its name.
    try std.testing.expectEqual(@as(?Kind, null), kindOf(.{ .name = "item", .idlType = .{ .type = "any" }, .arguments = &index }));
}
