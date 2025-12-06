//! WebIDL typedef: PasswordCredentialInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const PasswordCredentialInit = union(enum) {
    password_credential_data: dictionaries.PasswordCredentialData,
    htmlform_element: *runtime.Instance,
};
