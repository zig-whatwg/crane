//! Named unions for union arguments the binding must convert in argument order.
//!
//! WebIDL converts an operation's arguments - every one of them, in order -
//! before the operation's steps run (3.7.6 "create an operation function"
//! step 2.8, and the overload resolution algorithm it calls). Codegen types an
//! inline union argument `(A or B) x` as `runtime.JSValue`, which the binding
//! passes through unconverted; the impl then converts it itself, AFTER the
//! binding converted every later argument. When the union's conversion is
//! observable - a dictionary arm's getters, an object's toString - and a later
//! argument's conversion can throw, the order is visible: SubtleCrypto
//! importKey's keyData `(BufferSource or JsonWebKey)` must run its `alg`
//! getter before a Symbol algorithm's TypeError, and the impl never ran.
//!
//! So an inline union argument that has a LATER argument, and whose members
//! the binding converts faithfully, becomes a named union typedef, converted
//! by the binding in its place: `typedefs.BufferSourceOrJsonWebKey`. The last
//! argument keeps its JSValue - converted first thing by the impl, nothing
//! follows it - and so does a union with a member the binding's union
//! conversion does not take faithfully (`convertsFaithfully`): a sequence
//! (the binding's union path takes only an Array, not any iterable), a
//! record, a callback, `any` or `object`, a nested union, or a dictionary
//! with a member the binding leaves to the impl (a union, typed JSValue) or
//! a sequence of `any` (whose element handles it keeps).
//!
//! The typedef is recorded in the IR under `source`, so every writer sees an
//! ordinary typedef: the typedef file, its root.zig entry, the interface's
//! parameter type and the impl stub's.
//!
//! Trusted Types sinks (`nameTrustedTypeUnions`): a union with a Trusted Type
//! member - `(TrustedHTML or DOMString)`, `(TrustedType or DOMString)`,
//! `(TrustedScriptURL or USVString)` - is named in EVERY position: the
//! sink's steps ("get trusted type compliant string" step 1: "if input is an
//! instance of expectedType") need the arm the binding took, which a string
//! cannot carry. Arguments - the last, a variadic's element, a constructor's
//! and a static operation's included - take the typedef as their type; an
//! attribute keeps its union (its getter returns the string arm's type) and
//! its setter takes the typedef (`trustedTypeSetterUnion`). The typedef
//! `TrustedType` is flattened into its three interfaces, so every arm is an
//! interface or a string the binding's union conversion takes.

const std = @import("std");
const types = @import("types.zig");
const ir_mod = @import("ir.zig");

/// The source the named unions are recorded under in the IR.
pub const source = "(argument unions)";

/// Name every qualifying union argument of every interface operation and
/// constructor (see the file comment), rewriting the argument's type to the
/// typedef. Deterministic: interfaces are visited by name, members and
/// arguments in order, and a union of the same members in the same order is
/// one typedef.
pub fn nameArgumentUnions(ir: *ir_mod.IR) !void {
    var names = std.ArrayList([]const u8).empty;
    defer names.deinit(ir.allocator);
    var iter = ir.interfaces.keyIterator();
    while (iter.next()) |key| try names.append(ir.allocator, key.*);
    std.mem.sort([]const u8, names.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    for (names.items) |name| {
        const iface = ir.interfaces.getPtr(name) orelse continue;
        // A callback interface's operation is called by the platform, with
        // values the platform made: nothing converts its arguments from script.
        if (iface.callback) continue;
        for (iface.members.items) |member| {
            const arguments: []types.Argument = switch (member.type) {
                .operation => (member.operation orelse continue).arguments,
                .constructor => (member.constructor orelse continue).arguments,
                else => continue,
            };
            if (arguments.len < 2) continue;
            for (arguments[0 .. arguments.len - 1]) |*argument| {
                if (argument.variadic) continue;
                const members = argument.idlType.unionTypes orelse continue;
                if (writtenAsAnotherType(members)) continue;
                if (!convertsFaithfully(ir, members)) continue;
                const typedef_name = try unionTypedef(ir, members);
                // The same type, now named: nullability and the rest stay.
                argument.idlType.type = typedef_name;
                argument.idlType.unionTypes = null;
            }
        }
    }
}

/// Name every union with a Trusted Type member (see the file comment): an
/// operation's or constructor's argument becomes the typedef; a writable
/// attribute's union gets its typedef recorded for its setter. Runs before
/// `nameArgumentUnions`, which then never sees one.
pub fn nameTrustedTypeUnions(ir: *ir_mod.IR) !void {
    var names = std.ArrayList([]const u8).empty;
    defer names.deinit(ir.allocator);
    var iter = ir.interfaces.keyIterator();
    while (iter.next()) |key| try names.append(ir.allocator, key.*);
    std.mem.sort([]const u8, names.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    for (names.items) |name| {
        const iface = ir.interfaces.getPtr(name) orelse continue;
        if (iface.callback) continue;
        for (iface.members.items) |member| {
            switch (member.type) {
                .operation => if (member.operation) |op| try nameTrustedArguments(ir, op.arguments),
                .constructor => if (member.constructor) |ctor| try nameTrustedArguments(ir, ctor.arguments),
                .attribute => if (member.attribute) |attr| {
                    if (attr.readonly) continue;
                    const members = attr.idlType.unionTypes orelse continue;
                    if (!hasTrustedTypeMember(members)) continue;
                    _ = try trustedTypeUnionTypedef(ir, members);
                },
                else => {},
            }
        }
    }
}

fn nameTrustedArguments(ir: *ir_mod.IR, arguments: []types.Argument) !void {
    for (arguments) |*argument| {
        const members = argument.idlType.unionTypes orelse continue;
        if (!hasTrustedTypeMember(members)) continue;
        argument.idlType.type = try trustedTypeUnionTypedef(ir, members);
        argument.idlType.unionTypes = null;
    }
}

/// Whether `members` has a Trusted Type (TrustedHTML, TrustedScript,
/// TrustedScriptURL, or the typedef TrustedType).
pub fn hasTrustedTypeMember(members: []const types.IDLType) bool {
    for (members) |member| {
        if (std.mem.startsWith(u8, member.type, "Trusted")) return true;
    }
    return false;
}

/// The typedef an attribute of union type `members` - one with a Trusted
/// Type member - takes in its setter, named as `nameTrustedTypeUnions`
/// recorded it; null for any other type. OWNED by `allocator`.
pub fn trustedTypeSetterUnion(allocator: std.mem.Allocator, idl_type: types.IDLType) !?[]const u8 {
    const members = idl_type.unionTypes orelse return null;
    if (!hasTrustedTypeMember(members)) return null;
    return try unionName(allocator, members);
}

/// The typedef for a union with a Trusted Type member: named for its members
/// as written ("TrustedTypeOrDOMString"), its arms with TrustedType
/// flattened into TrustedHTML, TrustedScript and TrustedScriptURL.
fn trustedTypeUnionTypedef(ir: *ir_mod.IR, members: []types.IDLType) ![]const u8 {
    const arena = ir.merged.allocator();
    const name = try unionName(arena, members);
    if (ir.source_map.get(name)) |sources| {
        for (sources.items) |s| if (std.mem.eql(u8, s, source)) return ir.source_map.getKey(name).?;
        std.log.err("Trusted Types union {s} is already defined", .{name});
        return error.DuplicateDefinition;
    }
    var arms = std.ArrayList(types.IDLType).empty;
    for (members) |member| {
        if (std.mem.eql(u8, member.type, "TrustedType")) {
            for ([_][]const u8{ "TrustedHTML", "TrustedScript", "TrustedScriptURL" }) |interface| {
                try arms.append(arena, .{ .type = interface });
            }
        } else {
            var arm = member;
            // The binding applies [LegacyNullToEmptyString] before it
            // converts (the attribute's legacy_null_to_empty table).
            arm.legacy_null_to_empty = false;
            try arms.append(arena, arm);
        }
    }
    try ir.addTypedef(.{ .name = name, .idlType = .{ .type = name, .unionTypes = arms.items } }, source);
    return ir.source_map.getKey(name).?;
}

/// A union the writers already give a type of its own, which the binding
/// converts in place: (Node or DOMString) is mixins.ParentNode.NodeOrString.
/// A union with a Trusted Types member never reaches here: it is named first
/// (nameTrustedTypeUnions).
fn writtenAsAnotherType(members: []const types.IDLType) bool {
    var node = false;
    var string = false;
    for (members) |member| {
        if (std.mem.startsWith(u8, member.type, "Trusted")) return true;
        if (std.mem.eql(u8, member.type, "Node")) node = true;
        if (std.mem.eql(u8, member.type, "DOMString")) string = true;
    }
    return members.len == 2 and node and string;
}

/// The typedef named for `members`, recorded in the IR the first time.
fn unionTypedef(ir: *ir_mod.IR, members: []types.IDLType) ![]const u8 {
    const arena = ir.merged.allocator();
    const name = try unionName(arena, members);
    if (ir.source_map.get(name)) |sources| {
        // One of ours, made for an earlier argument: the same union.
        for (sources.items) |s| if (std.mem.eql(u8, s, source)) return ir.source_map.getKey(name).?;
        // A definition of the IDL's own under this name would be shadowed.
        std.log.err("argument union {s} is already defined", .{name});
        return error.DuplicateDefinition;
    }
    try ir.addTypedef(.{ .name = name, .idlType = .{ .type = name, .unionTypes = members } }, source);
    return ir.source_map.getKey(name).?;
}

/// `members`' type names joined by "Or", each in upper camel case:
/// (BufferSource or JsonWebKey) is "BufferSourceOrJsonWebKey", (unsigned
/// long or DOMString) "UnsignedLongOrDOMString".
pub fn unionName(allocator: std.mem.Allocator, members: []const types.IDLType) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    for (members, 0..) |member, i| {
        if (i > 0) try out.appendSlice(allocator, "Or");
        var words = std.mem.tokenizeScalar(u8, member.type, ' ');
        while (words.next()) |word| {
            try out.append(allocator, std.ascii.toUpper(word[0]));
            try out.appendSlice(allocator, word[1..]);
        }
    }
    return out.toOwnedSlice(allocator);
}

/// Does the binding's union conversion (conversions.zig, fromV8Value's union
/// path) take every member of `members` the way WebIDL 3.2.25 does, leaving
/// no handle it would not release: a string, numeric or boolean type, an
/// interface, a buffer source (BufferSource, ArrayBufferView), a typedef of
/// one of those, or a dictionary whose members are all such
/// (`dictionaryConvertsFaithfully`)?
pub fn convertsFaithfully(ir: *const ir_mod.IR, members: []const types.IDLType) bool {
    for (members) |member| {
        if (member.nullable or member.unionTypes != null) return false;
        if (!simpleConverts(ir, member, 0)) return false;
    }
    return true;
}

/// A non-union, non-container type the binding converts faithfully - in a
/// union arm or a dictionary member.
fn simpleConverts(ir: *const ir_mod.IR, t: types.IDLType, depth: u32) bool {
    if (depth > 8) return false;
    if (t.unionTypes != null or t.sequence != null or t.record != null or t.generic != null) return false;
    const name = t.type;
    if (std.mem.indexOfScalar(u8, name, '<') != null) return false;
    if (isStringType(name) or isNumericType(name) or std.mem.eql(u8, name, "boolean")) return true;
    // The buffer source typedefs: a reference to the object, released with
    // the converted value (interface.freeConvertedArg).
    if (std.mem.eql(u8, name, "BufferSource") or std.mem.eql(u8, name, "ArrayBufferView")) return true;
    const kind = ir.type_registry.lookup(name) orelse return false;
    return switch (kind) {
        .interface => true,
        .typedef => blk: {
            const typedef = ir.typedefs.get(name) orelse break :blk false;
            if (typedef.idlType.nullable) break :blk false;
            break :blk simpleConverts(ir, typedef.idlType, depth + 1);
        },
        .dictionary => dictionaryConvertsFaithfully(ir, name, depth + 1),
        else => false,
    };
}

/// A dictionary the binding converts member by member (fromV8Value's struct
/// path), each member - its own and its inherited dictionaries' - a type
/// `simpleConverts` takes, an enumeration, a sequence of such, or `any` /
/// `object` (a handle the binding releases with the dictionary). A union
/// member is typed `runtime.JSValue` and converted by the impl, later than
/// WebIDL converts it; a sequence of `any` keeps its elements' handles:
/// either keeps the dictionary with the impl.
pub fn dictionaryConvertsFaithfully(ir: *const ir_mod.IR, name: []const u8, depth: u32) bool {
    if (depth > 8) return false;
    const dictionary = ir.dictionaries.get(name) orelse return false;
    if (dictionary.inheritance) |base| {
        if (!dictionaryConvertsFaithfully(ir, base, depth + 1)) return false;
    }
    for (dictionary.members) |member| {
        if (!memberConverts(ir, member.idlType, depth)) return false;
    }
    return true;
}

fn memberConverts(ir: *const ir_mod.IR, t: types.IDLType, depth: u32) bool {
    // An `any` or `object` member needs no conversion but its handle, which
    // the binding releases with the dictionary (interface.freeConvertedArg).
    // Not as a sequence's element: those it keeps (conservatively).
    if (t.unionTypes == null and t.sequence == null and
        (std.mem.eql(u8, t.type, "any") or std.mem.eql(u8, t.type, "object"))) return true;
    if (sequenceElement(t)) |element| return elementConverts(ir, element, depth + 1);
    return elementConverts(ir, t, depth);
}

fn elementConverts(ir: *const ir_mod.IR, t: types.IDLType, depth: u32) bool {
    if (sequenceElement(t)) |element| return elementConverts(ir, element, depth + 1);
    if (ir.type_registry.lookup(t.type)) |kind| {
        if (kind == .enum_type) return true;
    }
    var plain = t;
    plain.nullable = false;
    return simpleConverts(ir, plain, depth);
}

/// The element type of a sequence, in whichever form the parser stored it.
fn sequenceElement(t: types.IDLType) ?types.IDLType {
    if (t.sequence) |element| return element.*;
    if (std.mem.eql(u8, t.type, "sequence")) {
        if (t.generic) |inner| return .{ .type = std.mem.trim(u8, inner, " \t") };
    }
    if (std.mem.startsWith(u8, t.type, "sequence<") and std.mem.endsWith(u8, t.type, ">")) {
        return .{ .type = std.mem.trim(u8, t.type["sequence<".len .. t.type.len - 1], " \t") };
    }
    return null;
}

fn isStringType(name: []const u8) bool {
    return std.mem.eql(u8, name, "DOMString") or std.mem.eql(u8, name, "USVString") or std.mem.eql(u8, name, "ByteString");
}

fn isNumericType(name: []const u8) bool {
    const numeric = [_][]const u8{
        "byte",  "octet",              "short",     "unsigned short",
        "long",  "unsigned long",      "long long", "unsigned long long",
        "float", "unrestricted float", "double",    "unrestricted double",
    };
    for (numeric) |n| if (std.mem.eql(u8, n, name)) return true;
    return false;
}
