//! Dictionary members whose inline union the binding converts.
//!
//! WebIDL converts a dictionary - every member, its union members included -
//! when the dictionary argument is converted (3.2.18 step 4: each member's
//! value "converted to an IDL value whose type is the type member is
//! declared to be of"), before the operation's steps run; Chrome and Firefox
//! do. Codegen types an inline union member `runtime.JSValue`, which the
//! binding hands over unconverted: the impl converts it later, after every
//! member after it and every argument after the dictionary, and has to write
//! the conversion itself (html/sanitizer.zig's SetHTMLOptions.sanitizer, read
//! by hand member by member).
//!
//! A member listed here gets a NAMED union typedef instead - the one
//! argument_unions.zig makes for an argument (`unionName`: SetHTMLOptions'
//! `(Sanitizer or SanitizerConfig or SanitizerPresets)` would be
//! `typedefs.SanitizerOrSanitizerConfigOrSanitizerPresets`) - which the
//! binding converts in the member's place (conversions.zig's union
//! conversion, WebIDL 3.2.25: an interface arm by implements, a dictionary
//! arm for an object no other arm took and for null and undefined, an
//! enumeration arm as a string type). Every arm must be one that conversion
//! takes faithfully (`convertsFaithfully`); a listed member whose union has
//! another arm fails the regeneration.
//!
//! A member joins the table in the commit that moves its consumer onto the
//! typed union: the member's Zig type changes with it. The table is empty
//! until the first consumer moves (the sanitizer options, once Codex row 59
//! has merged); the mechanism is tested on a fixture.

const std = @import("std");
const types = @import("types.zig");
const ir_mod = @import("ir.zig");
const argument_unions = @import("argument_unions.zig");

pub const Entry = struct {
    dictionary: []const u8,
    member: []const u8,
};

/// The dictionary members whose union the binding converts.
pub const table = [_]Entry{};

/// Name the union of every member `entries` lists (see the file comment),
/// rewriting the member's type to the typedef - a union of the same members
/// in the same order is one typedef, shared with the argument unions.
pub fn nameMemberUnions(ir: *ir_mod.IR, entries: []const Entry) !void {
    for (entries) |entry| {
        const dictionary = ir.dictionaries.getPtr(entry.dictionary) orelse {
            std.debug.print("  error: member_unions: no dictionary {s}\n", .{entry.dictionary});
            return error.UnknownMemberUnion;
        };
        const member = for (dictionary.members) |*m| {
            if (std.mem.eql(u8, m.name, entry.member)) break m;
        } else {
            std.debug.print("  error: member_unions: {s} has no member {s}\n", .{ entry.dictionary, entry.member });
            return error.UnknownMemberUnion;
        };
        const arms = member.idlType.unionTypes orelse {
            std.debug.print("  error: member_unions: {s}.{s} is not a union\n", .{ entry.dictionary, entry.member });
            return error.UnknownMemberUnion;
        };
        if (!convertsFaithfully(ir, arms)) {
            std.debug.print("  error: member_unions: the binding cannot convert {s}.{s}'s union\n", .{ entry.dictionary, entry.member });
            return error.MemberUnionNotConverted;
        }
        // The same type, now named: nullability and the rest stay.
        member.idlType.type = try argument_unions.unionTypedef(ir, arms);
        member.idlType.unionTypes = null;
    }
}

/// argument_unions.convertsFaithfully, and an enumeration arm: 3.2.25 counts
/// enumerations among the string types, and the binding's union conversion
/// takes one as it takes a string (an invalid value is its TypeError).
/// argument_unions' own rule is unchanged - widening it would rename argument
/// unions whose impls take the JSValue today.
pub fn convertsFaithfully(ir: *const ir_mod.IR, arms: []const types.IDLType) bool {
    for (arms) |arm| {
        if (ir.type_registry.lookup(arm.type)) |kind| {
            if (kind == .enum_type and !arm.nullable and arm.unionTypes == null) continue;
        }
        if (!argument_unions.convertsFaithfully(ir, &.{arm})) return false;
    }
    return true;
}
