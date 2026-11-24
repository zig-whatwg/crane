//! WebIDL typedef: URLPatternCompatible
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const URLPatternCompatible = union(enum) {
    usvstring: runtime.USVString,
    urlpattern_init: dictionaries.URLPatternInit,
    urlpattern: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "usvstring", .kind = .string },
        .{ .field = "urlpattern_init", .kind = .dictionary },
        .{ .field = "urlpattern", .kind = .{ .interface = "URLPattern" } },
    };
};
