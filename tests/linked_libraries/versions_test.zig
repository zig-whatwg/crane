//! The TLS and compression libraries Crane links, by the version the BINARY
//! reports - not by what a build.zig.zon declares.
//!
//! Crane's root build.zig.zon once declared mbedTLS 3.6.6 and zlib 1.3.2 while
//! nothing consumed either entry: libcurl linked the curl package's own pins,
//! mbedTLS 3.6.4 and zlib 1.3.1, and the security releases between them never
//! reached the binary (docs/lessons/architecture-link-the-library-your-dependency-actually-built.md).
//! These tests ask the linked code itself, so a pin that stops reaching the link
//! fails here.
//!
//! Built by build.zig's `test-deps` step (and `test`), which links this module
//! against the mbedTLS artifact configureStaticLibcurl returns - the one libcurl
//! and src/webcrypto link - with the same threading macros.

const std = @import("std");
const curl = @import("fetch").network.curl_ffi.c;
const mbedtls = @cImport({
    @cInclude("mbedtls/version.h");
});

/// The versions root build.zig.zon pins (`.mbedtls`, `.zlib`). Bump with them.
const expected_mbedtls = "3.6.6";
const expected_zlib = "1.3.2";

test "libcurl links the mbedTLS and zlib that build.zig.zon pins" {
    const info = curl.curl_version_info(curl.CURLVERSION_NOW);
    try std.testing.expect(info != null);
    // curl's mbedTLS backend formats ssl_version from mbedtls_version_get_number()
    // (lib/vtls/mbedtls.c, MBEDTLS_VERSION_C is on): the library's own answer.
    const ssl = std.mem.span(info.*.ssl_version orelse return error.NoTlsBackend);
    const libz = std.mem.span(info.*.libz_version orelse return error.NoZlib);
    std.debug.print("linked: libcurl {s}, {s}, zlib {s}\n", .{ std.mem.span(info.*.version), ssl, libz });
    try std.testing.expectEqualStrings("mbedTLS/" ++ expected_mbedtls, ssl);
    try std.testing.expectEqualStrings(expected_zlib, libz);
}

test "the mbedTLS headers WebCrypto compiles against match the library it links" {
    // "Should be at least 9 bytes in size" (mbedtls/version.h).
    var buffer: [16]u8 = @splat(0);
    mbedtls.mbedtls_version_get_string(&buffer);
    const library = std.mem.sliceTo(&buffer, 0);
    std.debug.print("linked: mbedtls_version_get_string {s}, MBEDTLS_VERSION_STRING {s}\n", .{ library, mbedtls.MBEDTLS_VERSION_STRING });
    try std.testing.expectEqualStrings(expected_mbedtls, library);
    try std.testing.expectEqualStrings(expected_mbedtls, mbedtls.MBEDTLS_VERSION_STRING);
}
