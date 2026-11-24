//! WebIDL typedef: PasswordCredentialInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const PasswordCredentialInit = union(enum) {
    password_credential_data: dictionaries.PasswordCredentialData,
    htmlform_element: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "password_credential_data", .kind = .dictionary },
        .{ .field = "htmlform_element", .kind = .{ .interface = "HTMLFormElement" } },
    };
};
