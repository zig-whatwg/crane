//! Named unions: every inline union becomes a union typedef the binding
//! converts in its place (lane bind1 batch B, B2: `nameEveryUnion`).
//!
//! WebIDL converts every value at its position - an operation's arguments,
//! all of them, in order, before the operation's steps run (3.7.6 "create an
//! operation function" step 2.8); a dictionary's members when the dictionary
//! is (3.2.18 step 4); a setter's value before the setter's steps. Codegen
//! typed an inline union `runtime.JSValue`, which the binding passed through
//! unconverted, and each impl converted it itself - after every later
//! argument, by rules of its own. Until lane bind1 only a union argument
//! followed by another, whose members a shape-driven union conversion took
//! "faithfully", was named. Now the binding converts every member type by
//! WebIDL 3.2.25 from the union's arms table (union_arms.zig), so every
//! union, in every position, is named: `(BufferSource or JsonWebKey)` is
//! `typedefs.BufferSourceOrJsonWebKey`.
//!
//! A typedef is recorded in the IR under `source`, so every writer sees an
//! ordinary typedef: the typedef file and its arms table, its root.zig
//! entry, the position's type and the impl stub's.
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

/// Every inline union in every position becomes a named union typedef
/// (lane bind1 batch B, B2): an operation's arguments - the last and a
/// variadic one's element included - and return type, a constructor's
/// arguments, an attribute, a dictionary member, a namespace's members, a
/// callback's arguments and return type, a typedef's members and a sequence's
/// or record's element types. Codegen then types each one as the typedef,
/// which carries its arms table (union_arms.zig), and the binding converts it
/// by WebIDL 3.2.25 in its place - no impl receives a union as an
/// unconverted runtime.JSValue. A union inside a union is named first, and is
/// that union's nested member (2.13.32: its flattened member types are the
/// outer union's). A union that includes a nullable type makes its position
/// nullable (3.2.25 step 2). Deterministic, as `nameArgumentUnions` is.
///
/// Two unions stay as they are: one with a Trusted Type member, named by
/// `nameTrustedTypeUnions` (which runs first) wherever its setter or sink
/// needs the arm, its attribute getter typed by the string member; and
/// (Node or DOMString), mixins.ParentNode.NodeOrString (`writtenAsAnotherType`).
pub fn nameEveryUnion(ir: *ir_mod.IR) !void {
    const allocator = ir.allocator;
    {
        const names = try sortedNames(allocator, &ir.interfaces);
        defer allocator.free(names);
        for (names) |name| {
            const iface = ir.interfaces.getPtr(name) orelse continue;
            for (iface.members.items) |*member| {
                if (member.type == .attribute) if (member.attribute) |attribute| {
                    if (keepsObjectIdentity(name, attribute.name)) continue;
                };
                try nameMemberUnions(ir, name, iface.mixins.items, member);
            }
        }
    }
    {
        const names = try sortedNames(allocator, &ir.namespaces);
        defer allocator.free(names);
        for (names) |name| {
            const namespace = ir.namespaces.getPtr(name) orelse continue;
            for (namespace.members) |*member| try nameMemberUnions(ir, name, &.{}, member);
        }
    }
    {
        const names = try sortedNames(allocator, &ir.dictionaries);
        defer allocator.free(names);
        for (names) |name| {
            const dictionary = ir.dictionaries.getPtr(name) orelse continue;
            for (dictionary.members) |*member| {
                if (convertedByImpl(name, &.{}, member.name, "")) continue;
                try nameType(ir, &member.idlType);
            }
        }
    }
    {
        const names = try sortedNames(allocator, &ir.callbacks);
        defer allocator.free(names);
        for (names) |name| {
            const callback = ir.callbacks.getPtr(name) orelse continue;
            for (callback.arguments) |*argument| try nameType(ir, &argument.idlType);
            try nameType(ir, &callback.idlType);
        }
    }
    {
        // Every typedef the IDL defines (the typedefs named above are made of
        // types already named): a union typedef's members, and a sequence's
        // or record's element types. Adding a typedef can move the map's
        // entries, so each is looked up again.
        const names = try sortedNames(allocator, &ir.typedefs);
        defer allocator.free(names);
        for (names) |name| {
            const typedef = ir.typedefs.getPtr(name) orelse continue;
            if (typedef.idlType.unionTypes) |members| {
                for (members) |*member| try nameType(ir, member);
            } else {
                var idl_type = typedef.idlType;
                try nameType(ir, &idl_type);
                (ir.typedefs.getPtr(name) orelse continue).idlType = idl_type;
            }
        }
    }
}

/// The keys of `map`, sorted: an OWNED slice of borrowed keys.
fn sortedNames(allocator: std.mem.Allocator, map: anytype) ![][]const u8 {
    var names = std.ArrayList([]const u8).empty;
    errdefer names.deinit(allocator);
    var iter = map.keyIterator();
    while (iter.next()) |key| try names.append(allocator, key.*);
    std.mem.sort([]const u8, names.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);
    return names.toOwnedSlice(allocator);
}

/// Union attributes whose getter returns the very JavaScript object a
/// platform object keeps - not a platform object's wrapper made on demand -
/// and so stay `runtime.JSValue` (`any`): IndexedDB's `source` attributes
/// return the source object itself "including after its realm retires and
/// its native wrapper association has been severed" (IDBCursor.zig,
/// IDBRequest.zig; lesson architecture-a-traced-wrapper-does-not-retain-its-
/// native-instance.md): the native Instance an interface member would carry
/// may no longer exist, while the traced wrapper does.
pub const object_identity_attributes = [_]struct { []const u8, []const u8 }{
    .{ "IDBCursor", "source" },
    .{ "IDBRequest", "source" },
};

fn keepsObjectIdentity(interface_name: []const u8, attribute_name: []const u8) bool {
    for (object_identity_attributes) |entry| {
        if (std.mem.eql(u8, entry[0], interface_name) and std.mem.eql(u8, entry[1], attribute_name)) return true;
    }
    return false;
}

/// Union positions an impl still converts by hand, kept `runtime.JSValue`
/// until a lane bind1 B5 commit moves that area's impl onto the typed union
/// and deletes its entries: `.{ owner, member, position }` - an interface,
/// interface mixin or dictionary; a member (an operation, attribute or
/// dictionary member; "constructor"; "" for an anonymous special
/// operation); an argument's name, "return", or "" for an attribute's or a
/// dictionary member's type. A mixin's entry covers its includers. THIS
/// TABLE ONLY SHRINKS, and is empty before batch B is done
/// (tests/codegen/argument_unions_test.zig pins it).
pub const unions_converted_by_impl = [_]struct { []const u8, []const u8, []const u8 }{
    // animations (dom/animations: effectOptions, keyframes)
    .{ "Animatable", "animate", "options" },
    .{ "KeyframeEffect", "constructor", "options" },
    .{ "BasePropertyIndexedKeyframe", "composite", "" },
    .{ "BasePropertyIndexedKeyframe", "easing", "" },
    .{ "BasePropertyIndexedKeyframe", "offset", "" },
    .{ "EffectTiming", "duration", "" },
    .{ "OptionalEffectTiming", "duration", "" },
    // canvas (CanvasFillStrokeStyles' styleValue / setStyle)
    .{ "CanvasFillStrokeStyles", "fillStyle", "" },
    .{ "CanvasFillStrokeStyles", "strokeStyle", "" },
    // css (CSSStyleSheet's constructor, typed OM's mapSet)
    .{ "CSSStyleSheetInit", "media", "" },
    .{ "StylePropertyMap", "append", "values" },
    .{ "StylePropertyMap", "set", "values" },
    // dom (element creation options, importNode, view transitions)
    .{ "Document", "createElement", "options" },
    .{ "Document", "createElementNS", "options" },
    .{ "Document", "importNode", "options" },
    .{ "Document", "startViewTransition", "callbackOptions" },
    // events and observers (EventTarget's options; lane rc8 is in these files)
    .{ "EventTarget", "addEventListener", "options" },
    .{ "EventTarget", "removeEventListener", "options" },
    .{ "IntersectionObserver", "root", "" },
    .{ "IntersectionObserverInit", "root", "" },
    .{ "IntersectionObserverInit", "threshold", "" },
    // forms (options.add's `before`, setFormValue, the form's named getter)
    .{ "HTMLOptionsCollection", "add", "before" },
    .{ "HTMLSelectElement", "add", "before" },
    .{ "ElementInternals", "setFormValue", "state" },
    .{ "HTMLFormElement", "", "return" },
    // HTMLAllCollection (its legacy caller and named getter bind `item` and
    // `namedItem` through a special path that takes the JSValue)
    .{ "HTMLAllCollection", "item", "return" },
    .{ "HTMLAllCollection", "namedItem", "return" },
    // fs
    .{ "WriteParams", "data", "" },
    // idb
    .{ "IDBDatabase", "transaction", "storeNames" },
    .{ "IDBObjectStore", "createIndex", "keyPath" },
    .{ "IDBObjectStoreParameters", "keyPath", "" },
    // media
    .{ "MediaStreamConstraints", "audio", "" },
    .{ "MediaStreamConstraints", "video", "" },
    // performance
    .{ "Performance", "measure", "startOrMeasureOptions" },
    .{ "PerformanceMeasureOptions", "start", "" },
    .{ "PerformanceMeasureOptions", "end", "" },
    // popover
    .{ "HTMLElement", "togglePopover", "options" },
    // sanitizer (html/sanitizer.zig, parser_options.zig)
    .{ "Sanitizer", "constructor", "configuration" },
    .{ "SetHTMLOptions", "sanitizer", "" },
    .{ "SetHTMLUnsafeOptions", "sanitizer", "" },
    .{ "ParseHTMLUnsafeOptions", "sanitizer", "" },
    // service workers and workers (lane hard1 is in ExtendableMessageEvent)
    .{ "InstallEvent", "addRoutes", "rules" },
    .{ "ExtendableMessageEventInit", "source", "" },
    .{ "SharedWorker", "constructor", "options" },
    // url
    // websocket and xhr
    .{ "WebSocket", "constructor", "protocols" },
    .{ "WebSocket", "send", "data" },
    .{ "XMLHttpRequest", "send", "body" },
};

/// Whether position (`member`, `position`) of `owner` - or of a mixin
/// `owner_mixins` names - is one `unions_converted_by_impl` keeps.
fn convertedByImpl(owner: []const u8, owner_mixins: []const []const u8, member: []const u8, position: []const u8) bool {
    for (unions_converted_by_impl) |entry| {
        if (!std.mem.eql(u8, entry[1], member) or !std.mem.eql(u8, entry[2], position)) continue;
        if (std.mem.eql(u8, entry[0], owner)) return true;
        for (owner_mixins) |mixin| {
            if (std.mem.eql(u8, entry[0], mixin)) return true;
        }
    }
    return false;
}

/// Name the unions of one member of interface or namespace `owner` (which
/// includes `mixins`), but the positions `unions_converted_by_impl` keeps.
fn nameMemberUnions(ir: *ir_mod.IR, owner: []const u8, mixins: []const []const u8, member: *types.Member) !void {
    switch (member.type) {
        .operation => if (member.operation) |*operation| {
            const name = operation.name orelse "";
            for (operation.arguments) |*argument| {
                if (convertedByImpl(owner, mixins, name, argument.name)) continue;
                try nameType(ir, &argument.idlType);
            }
            if (!convertedByImpl(owner, mixins, name, "return")) try nameType(ir, &operation.idlType);
        },
        .constructor => if (member.constructor) |*constructor| {
            for (constructor.arguments) |*argument| {
                if (convertedByImpl(owner, mixins, "constructor", argument.name)) continue;
                try nameType(ir, &argument.idlType);
            }
        },
        .attribute => if (member.attribute) |*attribute| {
            if (!convertedByImpl(owner, mixins, attribute.name, "")) try nameType(ir, &attribute.idlType);
        },
        .iterable => if (member.iterable) |*iterable| {
            try nameType(ir, &iterable.keyType);
            if (iterable.valueType) |*value| try nameType(ir, value);
        },
        .async_iterable => if (member.async_iterable) |*iterable| {
            try nameType(ir, &iterable.keyType);
            if (iterable.valueType) |*value| try nameType(ir, value);
        },
        .setlike => if (member.setlike) |*setlike| try nameType(ir, &setlike.value_type),
        .maplike => if (member.maplike) |*maplike| {
            try nameType(ir, &maplike.key_type);
            try nameType(ir, &maplike.value_type);
        },
        .constant => {},
    }
}

/// Name every inline union in `t`, `t` itself last (see `nameEveryUnion`).
fn nameType(ir: *ir_mod.IR, t: *types.IDLType) anyerror!void {
    if (t.sequence) |element| try nameType(ir, element);
    if (t.record) |record| {
        try nameType(ir, record.key);
        try nameType(ir, record.value);
    }
    // A sequence, frozen array or record the parser kept as text:
    // `sequence<(JsonLdRecord or USVString)>` - its element type named, the
    // text then naming the typedef.
    if (t.generic) |text| {
        if (std.mem.indexOfScalar(u8, text, '(') != null) t.generic = try nameGenericText(ir, text);
    }
    const members = t.unionTypes orelse return;
    for (members) |*member| try nameType(ir, member);
    if (writtenAsAnotherType(members)) return;
    // 3.2.25 step 2, "the union type includes a nullable type": the position
    // takes null.
    for (members) |member| {
        if (member.nullable) t.nullable = true;
    }
    t.type = try unionTypedef(ir, members);
    t.unionTypes = null;
}

/// A generic type's argument text with each parenthesized union in it named:
/// "(JsonLdRecord or USVString)" is "JsonLdRecordOrUSVString", "USVString,
/// (USVString or undefined)" (a record's) "USVString, USVStringOrUndefined".
fn nameGenericText(ir: *ir_mod.IR, text: []const u8) anyerror![]const u8 {
    const arena = ir.merged.allocator();
    var out = std.ArrayList(u8).empty;
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] != '(') {
            try out.append(arena, text[i]);
            i += 1;
            continue;
        }
        // The matching parenthesis.
        var depth: usize = 0;
        var end = i;
        while (end < text.len) : (end += 1) {
            if (text[end] == '(') depth += 1;
            if (text[end] == ')') {
                depth -= 1;
                if (depth == 0) break;
            }
        }
        if (end >= text.len) return error.UnbalancedUnionText;
        var union_type = try parseTypeText(arena, text[i .. end + 1]);
        try nameType(ir, &union_type);
        try out.appendSlice(arena, union_type.type);
        if (union_type.nullable) try out.append(arena, '?');
        i = end + 1;
    }
    return out.toOwnedSlice(arena);
}

/// An IDL type written as text - a name ("unsigned long", "DOMPointInit"),
/// `T?`, `sequence<T>`, `record<K, V>`, `FrozenArray<T>` or a union `(A or
/// B ...)` - as the parser's IDLType.
fn parseTypeText(arena: std.mem.Allocator, text: []const u8) anyerror!types.IDLType {
    var trimmed = std.mem.trim(u8, text, " \t\n");
    // Extended attributes on the type (`[EnforceRange] unsigned long`): the
    // generic text keeps them and the writers ignore them, as before.
    while (trimmed.len > 0 and trimmed[0] == '[') {
        const close = std.mem.indexOfScalar(u8, trimmed, ']') orelse break;
        trimmed = std.mem.trim(u8, trimmed[close + 1 ..], " \t\n");
    }
    var nullable = false;
    if (std.mem.endsWith(u8, trimmed, "?")) {
        nullable = true;
        trimmed = std.mem.trim(u8, trimmed[0 .. trimmed.len - 1], " \t\n");
    }
    if (trimmed.len >= 2 and trimmed[0] == '(' and trimmed[trimmed.len - 1] == ')') {
        const inner = trimmed[1 .. trimmed.len - 1];
        var members = std.ArrayList(types.IDLType).empty;
        var depth: usize = 0;
        var start: usize = 0;
        var i: usize = 0;
        while (i < inner.len) : (i += 1) {
            switch (inner[i]) {
                '(', '<' => depth += 1,
                ')', '>' => depth -= 1,
                ' ' => if (depth == 0 and std.mem.startsWith(u8, inner[i..], " or ")) {
                    try members.append(arena, try parseTypeText(arena, inner[start..i]));
                    i += " or ".len - 1;
                    start = i + 1;
                },
                else => {},
            }
        }
        try members.append(arena, try parseTypeText(arena, inner[start..]));
        return .{ .type = "", .nullable = nullable, .unionTypes = try members.toOwnedSlice(arena) };
    }
    if (std.mem.indexOfScalar(u8, trimmed, '<')) |open| {
        if (std.mem.endsWith(u8, trimmed, ">")) {
            const base = std.mem.trim(u8, trimmed[0..open], " \t");
            const argument = std.mem.trim(u8, trimmed[open + 1 .. trimmed.len - 1], " \t");
            if (std.mem.eql(u8, base, "sequence")) {
                const element = try arena.create(types.IDLType);
                element.* = try parseTypeText(arena, argument);
                return .{ .type = "sequence", .nullable = nullable, .sequence = element };
            }
            return .{ .type = try arena.dupe(u8, base), .nullable = nullable, .generic = try arena.dupe(u8, argument) };
        }
    }
    return .{ .type = try arena.dupe(u8, trimmed), .nullable = nullable };
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

/// The typedef named for `members`, recorded in the IR the first time (and
/// shared with member_unions.zig's dictionary members).
pub fn unionTypedef(ir: *ir_mod.IR, members: []types.IDLType) ![]const u8 {
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
        try appendTypeName(allocator, &out, member);
    }
    return out.toOwnedSlice(allocator);
}

/// One member's part of a union's name: its type's words in upper camel
/// case, a sequence's or record's with its element types ("SequenceOfLong",
/// "RecordOfDOMStringToDOMString"), so that (DOMString or sequence<DOMString>)
/// and (DOMString or sequence<long>) are two unions.
fn appendTypeName(allocator: std.mem.Allocator, out: *std.ArrayList(u8), t: types.IDLType) !void {
    if (t.sequence) |element| {
        try out.appendSlice(allocator, "SequenceOf");
        return appendTypeName(allocator, out, element.*);
    }
    if (t.record) |record| {
        try out.appendSlice(allocator, "RecordOf");
        try appendTypeName(allocator, out, record.key.*);
        try out.appendSlice(allocator, "To");
        return appendTypeName(allocator, out, record.value.*);
    }
    try appendWords(allocator, out, t.type);
    if (t.generic) |text| {
        try out.appendSlice(allocator, "Of");
        // Extended attributes (`[EnforceRange]`) are no part of the name.
        var plain = std.ArrayList(u8).empty;
        defer plain.deinit(allocator);
        var in_brackets = false;
        for (text) |c| {
            if (c == '[') in_brackets = true;
            if (!in_brackets) try plain.append(allocator, c);
            if (c == ']') in_brackets = false;
        }
        // "K, V" (a record's), "T": each name's words, joined.
        var parts = std.mem.tokenizeAny(u8, plain.items, ",<>() ?");
        var first = true;
        while (parts.next()) |part| {
            if (!first and std.mem.eql(u8, t.type, "record")) try out.appendSlice(allocator, "To");
            first = false;
            try appendWords(allocator, out, part);
        }
    }
}

/// `text`'s words in upper camel case; an extended attribute (`[EnforceRange]`)
/// is no part of a type's name.
fn appendWords(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) !void {
    var words = std.mem.tokenizeScalar(u8, text, ' ');
    while (words.next()) |word| {
        if (std.mem.indexOfAny(u8, word, "[]=") != null) continue;
        try out.append(allocator, std.ascii.toUpper(word[0]));
        try out.appendSlice(allocator, word[1..]);
    }
}
