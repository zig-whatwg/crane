//! WebIDL overload resolution.
//!
//! Spec: https://webidl.spec.whatwg.org/#dfn-overload-resolution-algorithm
//!       https://webidl.spec.whatwg.org/#compute-the-effective-overload-set
//!       https://webidl.spec.whatwg.org/#dfn-distinguishing-argument-index
//!
//! Given an operation's overloads and the arguments of one call, pick the
//! overload the call means. This module is the algorithm and nothing else: it
//! never converts a value. What it needs to know about the argument at the
//! distinguishing index - is it undefined, a platform object implementing some
//! interface, iterable - it asks through `select`'s `args`, which the V8
//! binding answers for real values and `tests/webidl/overload_resolution_test.zig`
//! answers with a struct.
//!
//! The overloads are described by codegen from the IDL (`Meta.overloads` in a
//! generated interface): for each argument, the categories of IDL type that
//! step 12 distinguishes on, whether it is nullable, and its optionality.
//! Converting the arguments is then the chosen overload's ordinary binding,
//! which is what steps 11, 15 and 16 amount to - every entry left in S agrees
//! on the types before the distinguishing index.

const std = @import("std");

/// An interface's identity, for step 12.4. Opaque here; the binding and the
/// generated descriptors use the address `runtime.typeId` gives the
/// interface's State type.
pub const Id = *const anyopaque;

/// A category of IDL type, as step 12 distinguishes them. A union type is its
/// flattened member types, so an argument carries a list of these.
pub const Kind = union(enum) {
    /// DOMString, ByteString, USVString, an enumeration.
    string,
    /// byte, octet, short, ..., unrestricted double.
    numeric,
    boolean,
    bigint,
    object,
    any,
    /// A dictionary type. Kept apart from `record` and `callback_interface`
    /// because step 12.3 (null or undefined) matches dictionaries only.
    dictionary,
    record,
    callback_interface,
    callback_function,
    /// sequence<T> and FrozenArray<T>.
    sequence,
    async_sequence,
    /// ArrayBuffer and SharedArrayBuffer (step 12.5 does not tell them apart).
    array_buffer,
    data_view,
    /// A typed array type, by its [[TypedArrayName]] (e.g. "Uint8Array").
    typed_array: []const u8,
    /// An interface type: matches a platform object that implements it.
    interface: Id,
    /// Anything step 12 never matches on (Promise<T>, undefined).
    other,
};

pub const Optionality = enum { required, optional, variadic };

/// One declared argument of one overload.
pub const Arg = struct {
    /// The type's categories: one, or a union's flattened members.
    kinds: []const Kind,
    /// A nullable type, or a union that includes one.
    nullable: bool = false,
    optionality: Optionality = .required,
};

/// One overload of an operation.
pub const Overload = struct {
    /// The generated interface function that runs this overload, e.g.
    /// "call_open__1". Only the binding reads it.
    function: []const u8,
    args: []const Arg,
    /// Whether the impl provides this overload. Resolution does not look at
    /// it - the spec picks among all overloads - but the binding does, to fall
    /// back to the first overload when the chosen one is not implemented yet.
    implemented: bool = true,
};

/// The most overloads one operation has in the whole IDL corpus is 5; this is
/// a bound on a bitset, not a limit anyone should approach.
const max_overloads = 32;

/// Is there an effective-overload-set entry for `overload` whose type list has
/// exactly `length` types?
///
/// Step 5 of "compute the effective overload set": the full argument list;
/// one entry per extra variadic argument; and, walking back from the end while
/// the arguments are optional (or variadic), one entry per truncation.
fn hasEntryOfLength(overload: Overload, length: usize) bool {
    const n = overload.args.len;
    if (length == n) return true;
    if (length > n) return isVariadic(overload);
    for (overload.args[length..]) |arg| {
        if (arg.optionality == .required) return false;
    }
    return true;
}

fn isVariadic(overload: Overload) bool {
    const n = overload.args.len;
    return n > 0 and overload.args[n - 1].optionality == .variadic;
}

/// The argument an entry of `overload` has at index `i`. Past the declared
/// arguments only a variadic overload has entries, and they repeat its last
/// argument's type.
fn argAt(overload: Overload, i: usize) Arg {
    return if (i < overload.args.len) overload.args[i] else overload.args[overload.args.len - 1];
}

fn kindEql(a: Kind, b: Kind) bool {
    if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
    return switch (a) {
        .typed_array => |name| std.mem.eql(u8, name, b.typed_array),
        .interface => |id| id == b.interface,
        else => true,
    };
}

fn argTypeEql(a: Arg, b: Arg) bool {
    if (a.nullable != b.nullable or a.kinds.len != b.kinds.len) return false;
    for (a.kinds, b.kinds) |ka, kb| {
        if (!kindEql(ka, kb)) return false;
    }
    return true;
}

/// Does `arg`'s type have a member satisfying `pred`?
fn argHas(arg: Arg, comptime pred: fn (Kind) bool) bool {
    for (arg.kinds) |kind| {
        if (pred(kind)) return true;
    }
    return false;
}

fn isTag(comptime tags: []const std.meta.Tag(Kind)) fn (Kind) bool {
    return struct {
        fn f(kind: Kind) bool {
            inline for (tags) |t| {
                if (kind == t) return true;
            }
            return false;
        }
    }.f;
}

pub const Error = error{TypeError};

/// The overload resolution algorithm, up to the choice of callable.
///
/// `overloads` is the operation's overload set in IDL order; `arg_count` is
/// the number of arguments passed; `args.at(i)` describes the JavaScript value
/// at index `i` (see the fake in the test file for the full question list).
/// Returns the index of the chosen overload.
///
/// Errors: `error.TypeError` where the spec throws one, and whatever
/// `hasIteratorMethod` / `hasAsyncIteratorMethod` report - GetMethod runs
/// script and can throw.
pub fn select(overloads: []const Overload, arg_count: usize, args: anytype) !usize {
    std.debug.assert(overloads.len > 0 and overloads.len <= max_overloads);

    // Step 1: Let maxarg be the length of the longest type list of the entries
    // in S - the most arguments any overload is declared to take (a variadic
    // argument counting once).
    var maxarg: usize = 0;
    for (overloads) |overload| maxarg = @max(maxarg, overload.args.len);

    // Steps 2-3: argcount = min(maxarg, n).
    const argcount = @min(maxarg, arg_count);

    // Step 4: Remove from S all entries whose type list is not of length
    // argcount. What is left is at most one entry per overload.
    var in_s = std.StaticBitSet(max_overloads).initEmpty();
    for (overloads, 0..) |overload, k| {
        if (hasEntryOfLength(overload, argcount)) in_s.set(k);
    }

    // Step 5: If S is empty, then throw a TypeError.
    const first = in_s.findFirstSet() orelse return error.TypeError;
    if (in_s.count() == 1) return first;

    // Step 8: d is the distinguishing argument index for the entries of S -
    // for valid IDL, the first index at which their types differ (every pair
    // is distinguishable there, and identical before it). Identical everywhere
    // is invalid IDL; the first overload is as good an answer as any.
    const d = distinguishingIndex(overloads, in_s, argcount) orelse return first;

    // Steps 9-11 convert the arguments before d, on which every entry agrees:
    // that is the chosen overload's own conversion, which the binding runs.

    // Step 12: narrow S on args[d].
    const v = args.at(d);

    // 12.2: undefined, and an entry whose argument at d is optional.
    if (v.isUndefined()) {
        var it = in_s.iterator(.{});
        while (it.next()) |k| {
            if (argAt(overloads[k], d).optionality == .optional) return k;
        }
    }

    // 12.3: null or undefined, and an entry with a nullable type or a
    // dictionary type at d.
    if (v.isUndefined() or v.isNull()) {
        if (firstMatching(overloads, in_s, d, struct {
            fn f(arg: Arg) bool {
                return arg.nullable or argHas(arg, isTag(&.{.dictionary}));
            }
        }.f)) |k| return k;
    }

    // 12.4: a platform object, and an entry with an interface type it
    // implements, or `object`.
    if (v.isPlatformObject()) {
        var it = in_s.iterator(.{});
        while (it.next()) |k| {
            for (argAt(overloads[k], d).kinds) |kind| {
                switch (kind) {
                    .object => return k,
                    .interface => |id| if (v.implements(id)) return k,
                    else => {},
                }
            }
        }
    }

    if (v.isObject()) {
        // 12.5: [[ArrayBufferData]].
        if (v.hasArrayBufferData()) {
            if (firstWithKind(overloads, in_s, d, &.{ .array_buffer, .object })) |k| return k;
        }
        // 12.6: [[DataView]].
        if (v.isDataView()) {
            if (firstWithKind(overloads, in_s, d, &.{ .data_view, .object })) |k| return k;
        }
        // 12.7: [[TypedArrayName]].
        if (v.typedArrayName()) |name| {
            var it = in_s.iterator(.{});
            while (it.next()) |k| {
                for (argAt(overloads[k], d).kinds) |kind| {
                    switch (kind) {
                        .object => return k,
                        .typed_array => |t| if (std.mem.eql(u8, t, name)) return k,
                        else => {},
                    }
                }
            }
        }
    }

    // 12.8: IsCallable, and a callback function type or `object`.
    if (v.isCallable()) {
        if (firstWithKind(overloads, in_s, d, &.{ .callback_function, .object })) |k| return k;
    }

    if (v.isObject()) {
        // 12.9: an async sequence type - unless V is a String object and S
        // also has a string type at d - and V has @@asyncIterator or
        // @@iterator.
        if (firstWithKind(overloads, in_s, d, &.{.async_sequence})) |k| {
            const string_object_to_string = v.hasStringData() and
                firstWithKind(overloads, in_s, d, &.{.string}) != null;
            if (!string_object_to_string and try v.hasAsyncIteratorMethod()) return k;
        }
        // 12.10: a sequence type, and V has @@iterator.
        if (firstWithKind(overloads, in_s, d, &.{.sequence})) |k| {
            if (try v.hasIteratorMethod()) return k;
        }
        // 12.11: a callback interface, dictionary, record or `object`.
        if (firstWithKind(overloads, in_s, d, &.{ .callback_interface, .dictionary, .record, .object })) |k| return k;
    }

    // 12.12-12.14: a primitive, and an entry of its own type.
    if (v.isBoolean()) {
        if (firstWithKind(overloads, in_s, d, &.{.boolean})) |k| return k;
    }
    if (v.isNumber()) {
        if (firstWithKind(overloads, in_s, d, &.{.numeric})) |k| return k;
    }
    if (v.isBigInt()) {
        if (firstWithKind(overloads, in_s, d, &.{.bigint})) |k| return k;
    }

    // 12.15-12.19: otherwise whatever the value converts to, in this order.
    if (firstWithKind(overloads, in_s, d, &.{.string})) |k| return k;
    if (firstWithKind(overloads, in_s, d, &.{.numeric})) |k| return k;
    if (firstWithKind(overloads, in_s, d, &.{.boolean})) |k| return k;
    if (firstWithKind(overloads, in_s, d, &.{.bigint})) |k| return k;
    if (firstWithKind(overloads, in_s, d, &.{.any})) |k| return k;

    // 12.20: Otherwise, throw a TypeError.
    return error.TypeError;
}

fn distinguishingIndex(
    overloads: []const Overload,
    in_s: std.StaticBitSet(max_overloads),
    argcount: usize,
) ?usize {
    const first = in_s.findFirstSet().?;
    var i: usize = 0;
    while (i < argcount) : (i += 1) {
        const t = argAt(overloads[first], i);
        var it = in_s.iterator(.{});
        while (it.next()) |k| {
            if (!argTypeEql(argAt(overloads[k], i), t)) return i;
        }
    }
    return null;
}

fn firstWithKind(
    overloads: []const Overload,
    in_s: std.StaticBitSet(max_overloads),
    d: usize,
    comptime tags: []const std.meta.Tag(Kind),
) ?usize {
    var it = in_s.iterator(.{});
    while (it.next()) |k| {
        if (argHas(argAt(overloads[k], d), isTag(tags))) return k;
    }
    return null;
}

fn firstMatching(
    overloads: []const Overload,
    in_s: std.StaticBitSet(max_overloads),
    d: usize,
    comptime pred: fn (Arg) bool,
) ?usize {
    var it = in_s.iterator(.{});
    while (it.next()) |k| {
        if (pred(argAt(overloads[k], d))) return k;
    }
    return null;
}

/// WebIDL's `length` for an overloaded operation's function object: the
/// shortest argument list in the effective overload set - the fewest REQUIRED
/// arguments any overload takes.
///
/// Spec: https://webidl.spec.whatwg.org/#dfn-create-operation-function step 4
/// ("the length of the shortest argument list in the effective overload set").
pub fn functionLength(overloads: []const Overload) usize {
    var shortest: usize = std.math.maxInt(usize);
    for (overloads) |overload| {
        var required: usize = 0;
        for (overload.args) |arg| {
            if (arg.optionality != .required) break;
            required += 1;
        }
        shortest = @min(shortest, required);
    }
    return shortest;
}
