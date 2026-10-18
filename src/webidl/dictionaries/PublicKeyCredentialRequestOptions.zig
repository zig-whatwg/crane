//! WebIDL dictionary: PublicKeyCredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const AuthenticationExtensionsClientInputs = @import("AuthenticationExtensionsClientInputs.zig").AuthenticationExtensionsClientInputs;
const PublicKeyCredentialDescriptor = @import("PublicKeyCredentialDescriptor.zig").PublicKeyCredentialDescriptor;

pub const PublicKeyCredentialRequestOptions = struct {
    challenge: typedefs.BufferSource,
    timeout: ?u32 = null,
    rpId: ?runtime.DOMString = null,
    allowCredentials: ?[]const PublicKeyCredentialDescriptor = null,
    userVerification: ?runtime.DOMString = null,
    hints: ?[]const runtime.DOMString = null,
    extensions: ?AuthenticationExtensionsClientInputs = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "allowCredentials", .empty_sequence },
        .{ "userVerification", .{ .string = "preferred" } },
        .{ "hints", .empty_sequence },
    };
};
