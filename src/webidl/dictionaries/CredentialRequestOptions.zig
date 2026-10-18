//! WebIDL dictionary: CredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const OTPCredentialRequestOptions = @import("OTPCredentialRequestOptions.zig").OTPCredentialRequestOptions;
const DigitalCredentialRequestOptions = @import("DigitalCredentialRequestOptions.zig").DigitalCredentialRequestOptions;
const FederatedCredentialRequestOptions = @import("FederatedCredentialRequestOptions.zig").FederatedCredentialRequestOptions;
const PublicKeyCredentialRequestOptions = @import("PublicKeyCredentialRequestOptions.zig").PublicKeyCredentialRequestOptions;
const IdentityCredentialRequestOptions = @import("IdentityCredentialRequestOptions.zig").IdentityCredentialRequestOptions;

pub const CredentialRequestOptions = struct {
    mediation: ?enums.CredentialMediationRequirement = null,
    uiMode: ?runtime.DOMString = null,
    signal: ?*runtime.Instance = null,
    password: ?bool = null,
    federated: ?FederatedCredentialRequestOptions = null,
    digital: ?DigitalCredentialRequestOptions = null,
    identity: ?IdentityCredentialRequestOptions = null,
    otp: ?OTPCredentialRequestOptions = null,
    publicKey: ?PublicKeyCredentialRequestOptions = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "mediation", .{ .string = "optional" } },
        .{ "password", .{ .boolean = false } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
