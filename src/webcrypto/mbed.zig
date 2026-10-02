//! Operations missing from std.crypto, using curl's existing mbedTLS library.

const std = @import("std");
pub const available = @import("options").mbedtls;

pub const c = @cImport({
    @cInclude("psa/crypto.h");
    @cInclude("mbedtls/nist_kw.h");
});

pub fn check(status: i32) error{OperationError}!void {
    if (!available) return error.OperationError;
    if (status != c.PSA_SUCCESS) return error.OperationError;
}

/// A transient PSA key. Never stored in a CryptoKey; it stays in one call.
pub const Key = struct {
    id: if (available) c.mbedtls_svc_key_id_t else void,

    pub fn importAes(bytes: []const u8, algorithm: u32, usage: u32) !Key {
        if (!available) return error.NotSupportedError;
        // curl's mbedTLS cleanup frees every PSA key slot when its last Browser
        // closes. Keep no PSA key between calls, and initialize per operation.
        try check(c.psa_crypto_init());
        var attributes = c.psa_key_attributes_init();
        defer c.psa_reset_key_attributes(&attributes);
        c.psa_set_key_type(&attributes, c.PSA_KEY_TYPE_AES);
        c.psa_set_key_bits(&attributes, bytes.len * 8);
        c.psa_set_key_algorithm(&attributes, algorithm);
        c.psa_set_key_usage_flags(&attributes, usage);
        var result: Key = undefined;
        try check(c.psa_import_key(&attributes, bytes.ptr, bytes.len, &result.id));
        return result;
    }

    pub fn deinit(self: *Key) void {
        if (!available) return;
        _ = c.psa_destroy_key(self.id);
        std.crypto.secureZero(u8, std.mem.asBytes(self));
    }
};
