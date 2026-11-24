//! A generated union's value for a platform object (lane bind1 batch B, B2).
//!
//! An attribute or operation whose IDL type is a union returns the generated
//! union (codegen's typedefs, each with its arms table, webidl.union_arms)
//! since every union is named in every position. An impl that holds a
//! platform object - the source of a message event, the track of a
//! TrackEvent, an IDB request's source - answers with the member interface
//! the object implements, chosen as WebIDL 3.2.25 step 5.1 chooses it for a
//! value converted the other way: the first interface member, in member
//! order (a nested union's in its place), that the object implements.

const runtime = @import("runtime");
const interfaces = @import("interfaces");

/// `instance` as a value of union `U`: its first interface member that
/// `instance` implements, or null when it implements none.
pub fn ofInstance(comptime U: type, instance: *runtime.Instance) ?U {
    inline for (U.arms) |arm| {
        const Field = @FieldType(U, arm.field);
        switch (arm.kind) {
            .interface => |name| {
                if (instance.implements(@field(interfaces, name).State)) return @unionInit(U, arm.field, instance);
            },
            .@"union" => if (ofInstance(Field, instance)) |nested| return @unionInit(U, arm.field, nested),
            else => {},
        }
    }
    return null;
}

const std = @import("std");

test "a union with no interface member takes no instance" {
    const NoInterface = union(enum) {
        domstring: runtime.DOMString,
        long: i32,
        pub const arms = [_]@import("webidl").UnionArm{
            .{ .field = "domstring", .kind = .string },
            .{ .field = "long", .kind = .numeric },
        };
    };
    var instance: runtime.Instance = undefined;
    try std.testing.expect(ofInstance(NoInterface, &instance) == null);
}
