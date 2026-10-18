//! WebIDL dictionary: PublicKeyCredentialRequestOptionsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const PublicKeyCredentialDescriptorJSON = @import("PublicKeyCredentialDescriptorJSON.zig").PublicKeyCredentialDescriptorJSON;
const AuthenticationExtensionsClientInputsJSON = @import("AuthenticationExtensionsClientInputsJSON.zig").AuthenticationExtensionsClientInputsJSON;

pub const PublicKeyCredentialRequestOptionsJSON = struct {
    challenge: typedefs.Base64URLString,
    timeout: ?u32 = null,
    rpId: ?runtime.DOMString = null,
    allowCredentials: ?[]const PublicKeyCredentialDescriptorJSON = null,
    userVerification: ?runtime.DOMString = null,
    hints: ?[]const runtime.DOMString = null,
    extensions: ?AuthenticationExtensionsClientInputsJSON = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "allowCredentials", .empty_sequence },
        .{ "userVerification", .{ .string = "preferred" } },
        .{ "hints", .empty_sequence },
    };
};
