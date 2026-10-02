//! Web Cryptography API primitives and shared algorithms.
//! https://w3c.github.io/webcrypto/

pub const random = @import("random.zig");
pub const hash = @import("hash.zig");
pub const integers = @import("integers.zig");
pub const hmac = @import("hmac.zig");
pub const kdf = @import("kdf.zig");
pub const registry = @import("registry.zig");
pub const key = @import("key.zig");
pub const aes = @import("aes.zig");

test {
    _ = random;
    _ = hash;
    _ = integers;
    _ = hmac;
    _ = kdf;
    _ = registry;
    _ = key;
    _ = aes;
}
