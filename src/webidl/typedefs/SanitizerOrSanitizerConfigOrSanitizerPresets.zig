//! WebIDL typedef: SanitizerOrSanitizerConfigOrSanitizerPresets
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");
const enums = @import("enums");

pub const SanitizerOrSanitizerConfigOrSanitizerPresets = union(enum) {
    sanitizer: *runtime.Instance,
    sanitizer_config: dictionaries.SanitizerConfig,
    sanitizer_presets: enums.SanitizerPresets,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "sanitizer", .kind = .{ .interface = "Sanitizer" } },
        .{ .field = "sanitizer_config", .kind = .dictionary },
        .{ .field = "sanitizer_presets", .kind = .enumeration },
    };
};
