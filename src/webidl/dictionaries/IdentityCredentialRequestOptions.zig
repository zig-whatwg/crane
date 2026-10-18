//! WebIDL dictionary: IdentityCredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const IdentityProviderRequestOptions = @import("IdentityProviderRequestOptions.zig").IdentityProviderRequestOptions;

pub const IdentityCredentialRequestOptions = struct {
    providers: []const IdentityProviderRequestOptions,
    context: ?enums.IdentityCredentialRequestOptionsContext = null,
    mode: ?enums.IdentityCredentialRequestOptionsMode = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "context", .{ .string = "signin" } },
        .{ "mode", .{ .string = "passive" } },
    };
};
