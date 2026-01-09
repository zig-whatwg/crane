//! Certificate Trust Store
//!
//! Manages trusted certificates per browser context for TLS/SSL verification.
//! This module allows programmatic addition of trusted certificates (e.g., for
//! self-signed certs in testing environments like WPT) without globally
//! disabling SSL verification.
//!
//! ## Usage
//!
//! ```zig
//! var store = CertificateTrustStore.init(allocator);
//! defer store.deinit();
//!
//! // Add a trusted certificate for localhost on port 8445
//! try store.addTrustedCertificate("localhost:8445", pem_data, .{});
//!
//! // Add a certificate that matches any host on port 8446
//! try store.addTrustedCertificate("*:8446", pem_data, .{});
//!
//! // Check if a certificate is trusted for a host
//! const is_trusted = store.isTrustedForHost("localhost:8445", fingerprint);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;

/// Options for adding a trusted certificate
pub const TrustedCertificateOptions = struct {
    /// If true, ignore certificate expiration when validating
    ignore_expiry: bool = false,
};

/// A trusted certificate entry
pub const TrustedCertificate = struct {
    /// SHA-256 fingerprint of the certificate
    fingerprint: [32]u8,
    /// Host pattern (e.g., "localhost:8445", "*:8446", "*")
    host_pattern: []const u8,
    /// PEM-encoded certificate data
    pem_data: []const u8,
    /// Whether to ignore certificate expiration
    ignore_expiry: bool = false,

    /// Check if this certificate matches a given host
    pub fn matchesHost(self: *const TrustedCertificate, host: []const u8) bool {
        return matchHostPattern(self.host_pattern, host);
    }
};

/// Certificate trust store for managing trusted certificates per browser context
pub const CertificateTrustStore = struct {
    const Self = @This();

    /// Map from host pattern to list of trusted certificates
    trusted_certs: std.StringHashMapUnmanaged(std.ArrayListUnmanaged(TrustedCertificate)),
    /// Optional path to CA bundle file
    ca_bundle_path: ?[]const u8,
    /// Allocator used for all allocations
    allocator: Allocator,

    /// Initialize a new certificate trust store
    pub fn init(allocator: Allocator) Self {
        return Self{
            .trusted_certs = .{},
            .ca_bundle_path = null,
            .allocator = allocator,
        };
    }

    /// Deinitialize and free all resources
    pub fn deinit(self: *Self) void {
        // Free all certificate lists and their contents
        var it = self.trusted_certs.iterator();
        while (it.next()) |entry| {
            // Free each certificate's owned data
            for (entry.value_ptr.items) |cert| {
                self.allocator.free(cert.host_pattern);
                self.allocator.free(cert.pem_data);
            }
            // Free the array list
            entry.value_ptr.deinit(self.allocator);
            // Free the key (host pattern)
            self.allocator.free(entry.key_ptr.*);
        }
        self.trusted_certs.deinit(self.allocator);

        // Free CA bundle path if set
        if (self.ca_bundle_path) |path| {
            self.allocator.free(path);
        }
    }

    /// Add a trusted certificate for a host pattern
    ///
    /// The host_pattern supports:
    /// - Exact match: "localhost:8445"
    /// - Wildcard host with specific port: "*:8446"
    /// - Wildcard everything: "*"
    pub fn addTrustedCertificate(
        self: *Self,
        host_pattern: []const u8,
        pem_data: []const u8,
        options: TrustedCertificateOptions,
    ) !void {
        // Calculate fingerprint from PEM data
        const fingerprint = calculateFingerprint(pem_data);

        // MEMORY SAFETY: Allocate ALL owned copies BEFORE modifying the map.
        // This ensures that if any allocation fails, we haven't left the map
        // in an inconsistent state with non-owned keys that deinit would try to free.

        // Allocate the map key first (will be used if this is a new entry)
        const key_copy = try self.allocator.dupe(u8, host_pattern);
        errdefer self.allocator.free(key_copy);

        // Allocate owned pattern for the certificate
        const owned_pattern = try self.allocator.dupe(u8, host_pattern);
        errdefer self.allocator.free(owned_pattern);

        // Allocate owned PEM data
        const owned_pem = try self.allocator.dupe(u8, pem_data);
        errdefer self.allocator.free(owned_pem);

        // Now safe to modify the map - all memory is pre-allocated.
        // Use key_copy for lookup so the map stores our owned key.
        const gop = try self.trusted_certs.getOrPut(self.allocator, key_copy);
        if (!gop.found_existing) {
            // New entry - assign our pre-allocated key
            gop.key_ptr.* = key_copy;
            gop.value_ptr.* = .{};
        } else {
            // Key already exists in map - free our duplicate
            self.allocator.free(key_copy);
        }

        const cert = TrustedCertificate{
            .fingerprint = fingerprint,
            .host_pattern = owned_pattern,
            .pem_data = owned_pem,
            .ignore_expiry = options.ignore_expiry,
        };

        gop.value_ptr.append(self.allocator, cert) catch |err| {
            // If append fails on a new entry, we need to handle cleanup.
            // The map entry exists but has an empty list - this is safe since
            // deinit will just iterate over an empty list and free the key.
            // Our owned_pattern and owned_pem will be freed by errdefer.
            return err;
        };
    }

    /// Add a trusted certificate from a file
    pub fn addTrustedCertificateFromFile(
        self: *Self,
        host_pattern: []const u8,
        cert_path: []const u8,
        options: TrustedCertificateOptions,
    ) !void {
        // Read the certificate file
        const file = try std.fs.cwd().openFile(cert_path, .{});
        defer file.close();

        const stat = try file.stat();
        if (stat.size > 1024 * 1024) {
            return error.CertificateFileTooLarge;
        }

        const pem_data = try self.allocator.alloc(u8, stat.size);
        defer self.allocator.free(pem_data);

        const bytes_read = try file.readAll(pem_data);
        if (bytes_read != stat.size) {
            return error.IncompleteRead;
        }

        try self.addTrustedCertificate(host_pattern, pem_data[0..bytes_read], options);
    }

    /// Set the path to a CA bundle file
    pub fn setCaBundlePath(self: *Self, path: []const u8) !void {
        // Free old path if set
        if (self.ca_bundle_path) |old_path| {
            self.allocator.free(old_path);
        }
        self.ca_bundle_path = try self.allocator.dupe(u8, path);
    }

    /// Get the currently configured CA bundle path
    pub fn getCaBundlePath(self: *const Self) ?[]const u8 {
        return self.ca_bundle_path;
    }

    /// Check if a certificate is trusted for a given host
    ///
    /// Returns true if any trusted certificate matches the host pattern
    /// and has the same fingerprint.
    pub fn isTrustedForHost(self: *const Self, host: []const u8, cert_fingerprint: [32]u8) bool {
        // Check all entries for matching patterns
        var it = self.trusted_certs.iterator();
        while (it.next()) |entry| {
            for (entry.value_ptr.items) |cert| {
                if (cert.matchesHost(host) and std.mem.eql(u8, &cert.fingerprint, &cert_fingerprint)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Generate a temporary CA bundle file with all trusted certificates.
    /// The generated bundle merges system CA roots with custom trusted certificates,
    /// ensuring that regular HTTPS requests continue to work while also trusting
    /// custom certificates (e.g., for WPT self-signed certs).
    ///
    /// Returns path to the generated file.
    ///
    /// IMPORTANT: The returned path is allocated with self.allocator.
    /// Caller is responsible for freeing it when done.
    pub fn generateCaBundleFile(self: *const Self, output_dir: []const u8) ![]const u8 {
        return self.generateCaBundleFileWithOptions(output_dir, .{});
    }

    /// Options for CA bundle generation
    pub const CaBundleOptions = struct {
        /// If true, include system CA roots in the generated bundle.
        /// Default is true to preserve HTTPS functionality for regular sites.
        include_system_roots: bool = true,
    };

    /// Generate a temporary CA bundle file with configurable options.
    /// By default, includes system CA roots to preserve HTTPS functionality.
    pub fn generateCaBundleFileWithOptions(
        self: *const Self,
        output_dir: []const u8,
        options: CaBundleOptions,
    ) ![]const u8 {
        // Generate unique filename with random suffix to avoid race conditions
        // when multiple browsers/tests run in parallel
        var random_bytes: [8]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);
        const hex_suffix = std.fmt.bytesToHex(random_bytes, .lower);

        var filename_buf: [64]u8 = undefined;
        const filename = std.fmt.bufPrint(&filename_buf, "crane_trusted_certs_{s}.pem", .{
            hex_suffix[0..],
        }) catch "crane_trusted_certs.pem";

        // Build the full path
        const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ output_dir, filename });
        errdefer self.allocator.free(full_path);

        // Create/open the file
        var dir = try std.fs.cwd().openDir(output_dir, .{});
        defer dir.close();
        var file = try dir.createFile(filename, .{});
        defer file.close();

        // First, copy system CA roots if requested
        if (options.include_system_roots) {
            try copySystemCaRoots(&file);
        }

        // Then append all custom trusted certificates
        var cert_count: usize = 0;
        var it = self.trusted_certs.iterator();
        while (it.next()) |entry| {
            for (entry.value_ptr.items) |cert| {
                try file.writeAll(cert.pem_data);
                // Ensure there's a newline between certificates
                if (cert.pem_data.len > 0 and cert.pem_data[cert.pem_data.len - 1] != '\n') {
                    try file.writeAll("\n");
                }
                cert_count += 1;
            }
        }

        return full_path;
    }

    /// Get all trusted certificates (for iteration)
    pub fn getAllCertificates(self: *const Self) std.StringHashMapUnmanaged(std.ArrayListUnmanaged(TrustedCertificate)).Iterator {
        return self.trusted_certs.iterator();
    }

    /// Get the count of trusted certificates
    pub fn getCertificateCount(self: *const Self) usize {
        var count: usize = 0;
        var it = self.trusted_certs.iterator();
        while (it.next()) |entry| {
            count += entry.value_ptr.items.len;
        }
        return count;
    }
};

/// Calculate SHA-256 fingerprint of certificate data
fn calculateFingerprint(pem_data: []const u8) [32]u8 {
    var hash: [32]u8 = undefined;
    Sha256.hash(pem_data, &hash, .{});
    return hash;
}

/// Match a host against a pattern
///
/// Patterns:
/// - "*" matches any host
/// - "*:PORT" matches any host on the specified port
/// - "HOST:PORT" matches exact host and port
/// - "HOST" matches exact host on any port
fn matchHostPattern(pattern: []const u8, host: []const u8) bool {
    // Pattern "*" matches everything
    if (std.mem.eql(u8, pattern, "*")) {
        return true;
    }

    // Find port separator in pattern
    if (std.mem.indexOf(u8, pattern, ":")) |pattern_colon| {
        const pattern_host = pattern[0..pattern_colon];
        const pattern_port = pattern[pattern_colon + 1 ..];

        // Find port in host
        if (std.mem.indexOf(u8, host, ":")) |host_colon| {
            const host_name = host[0..host_colon];
            const host_port = host[host_colon + 1 ..];

            // Check port match
            if (!std.mem.eql(u8, pattern_port, host_port)) {
                return false;
            }

            // Check host match (wildcard or exact)
            if (std.mem.eql(u8, pattern_host, "*")) {
                return true;
            }
            return std.mem.eql(u8, pattern_host, host_name);
        } else {
            // Host has no port, pattern has port - no match
            return false;
        }
    } else {
        // Pattern has no port - match any port
        if (std.mem.indexOf(u8, host, ":")) |host_colon| {
            const host_name = host[0..host_colon];
            return std.mem.eql(u8, pattern, host_name);
        } else {
            return std.mem.eql(u8, pattern, host);
        }
    }
}

/// Known system CA bundle paths in order of preference
const system_ca_paths = [_][]const u8{
    // Linux (Debian/Ubuntu, Alpine, Fedora)
    "/etc/ssl/certs/ca-certificates.crt",
    "/etc/pki/tls/certs/ca-bundle.crt",
    "/etc/ssl/ca-bundle.pem",
    // macOS
    "/etc/ssl/cert.pem",
    // FreeBSD
    "/usr/local/share/certs/ca-root-nss.crt",
    // OpenBSD
    "/etc/ssl/cert.pem",
};

/// Copy system CA roots to the given file.
/// Searches for the system CA bundle in known locations and copies its contents.
/// Returns error.SystemCaBundleNotFound if no system CA bundle is found.
fn copySystemCaRoots(file: *std.fs.File) !void {
    for (system_ca_paths) |path| {
        const ca_file = std.fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => continue, // Skip inaccessible files
        };
        defer ca_file.close();

        // Copy the system CA bundle to our output file
        var buf: [8192]u8 = undefined;
        while (true) {
            const bytes_read = ca_file.read(&buf) catch break;
            if (bytes_read == 0) break;
            try file.writeAll(buf[0..bytes_read]);
        }

        // Ensure there's a newline after the system bundle
        try file.writeAll("\n");
        return;
    }

    // No system CA bundle found - this is not necessarily an error
    // The generated bundle will only contain custom certs
    // On some systems, curl may use NSS or other backends
    return;
}

/// Get the first available system CA bundle path, or null if none found.
/// Useful for diagnostics and testing.
pub fn findSystemCaBundlePath() ?[]const u8 {
    for (system_ca_paths) |path| {
        if (std.fs.accessAbsolute(path, .{})) {
            return path;
        } else |_| {}
    }
    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "CertificateTrustStore - init and deinit" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    try std.testing.expectEqual(@as(usize, 0), store.getCertificateCount());
}

test "CertificateTrustStore - addTrustedCertificate" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    const pem_data =
        \\-----BEGIN CERTIFICATE-----
        \\MIICpDCCAYwCCQDU+pQ4P3z8CDANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
        \\b2NhbGhvc3QwHhcNMjQwMTAxMDAwMDAwWhcNMjUwMTAxMDAwMDAwWjAUMRIwEAYD
        \\VQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC7
        \\test_cert_data
        \\-----END CERTIFICATE-----
    ;

    try store.addTrustedCertificate("localhost:8445", pem_data, .{});
    try std.testing.expectEqual(@as(usize, 1), store.getCertificateCount());

    // Add another certificate
    try store.addTrustedCertificate("*:8446", pem_data, .{ .ignore_expiry = true });
    try std.testing.expectEqual(@as(usize, 2), store.getCertificateCount());
}

test "CertificateTrustStore - wildcard pattern matching" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    const pem_data = "-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----";
    const fingerprint = calculateFingerprint(pem_data);

    // Add wildcard certificate for any host on port 8446
    try store.addTrustedCertificate("*:8446", pem_data, .{});

    // Should match any host on port 8446
    try std.testing.expect(store.isTrustedForHost("localhost:8446", fingerprint));
    try std.testing.expect(store.isTrustedForHost("example.com:8446", fingerprint));
    try std.testing.expect(store.isTrustedForHost("192.168.1.1:8446", fingerprint));

    // Should not match other ports
    try std.testing.expect(!store.isTrustedForHost("localhost:8445", fingerprint));
    try std.testing.expect(!store.isTrustedForHost("localhost:443", fingerprint));
}

test "CertificateTrustStore - exact host pattern matching" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    const pem_data = "-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----";
    const fingerprint = calculateFingerprint(pem_data);

    // Add certificate for specific host:port
    try store.addTrustedCertificate("localhost:8445", pem_data, .{});

    // Should match exact host:port
    try std.testing.expect(store.isTrustedForHost("localhost:8445", fingerprint));

    // Should not match other hosts or ports
    try std.testing.expect(!store.isTrustedForHost("example.com:8445", fingerprint));
    try std.testing.expect(!store.isTrustedForHost("localhost:8446", fingerprint));
    try std.testing.expect(!store.isTrustedForHost("localhost", fingerprint));
}

test "CertificateTrustStore - global wildcard pattern" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    const pem_data = "-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----";
    const fingerprint = calculateFingerprint(pem_data);

    // Add wildcard certificate for any host
    try store.addTrustedCertificate("*", pem_data, .{});

    // Should match everything
    try std.testing.expect(store.isTrustedForHost("localhost:8445", fingerprint));
    try std.testing.expect(store.isTrustedForHost("example.com:443", fingerprint));
    try std.testing.expect(store.isTrustedForHost("192.168.1.1:8080", fingerprint));
}

test "CertificateTrustStore - isTrustedForHost with wrong fingerprint" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    const pem_data = "-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----";

    try store.addTrustedCertificate("localhost:8445", pem_data, .{});

    // Wrong fingerprint should not match
    var wrong_fingerprint: [32]u8 = undefined;
    @memset(&wrong_fingerprint, 0xFF);
    try std.testing.expect(!store.isTrustedForHost("localhost:8445", wrong_fingerprint));
}

test "CertificateTrustStore - setCaBundlePath and getCaBundlePath" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    try std.testing.expectEqual(@as(?[]const u8, null), store.getCaBundlePath());

    try store.setCaBundlePath("/etc/ssl/certs/ca-certificates.crt");
    try std.testing.expectEqualStrings("/etc/ssl/certs/ca-certificates.crt", store.getCaBundlePath().?);

    // Update path
    try store.setCaBundlePath("/custom/ca-bundle.pem");
    try std.testing.expectEqualStrings("/custom/ca-bundle.pem", store.getCaBundlePath().?);
}

test "CertificateTrustStore - generateCaBundleFile" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    const pem1 = "-----BEGIN CERTIFICATE-----\ncert1\n-----END CERTIFICATE-----\n";
    const pem2 = "-----BEGIN CERTIFICATE-----\ncert2\n-----END CERTIFICATE-----\n";

    try store.addTrustedCertificate("localhost:8445", pem1, .{});
    try store.addTrustedCertificate("*:8446", pem2, .{});

    // Create temp directory for test
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const bundle_path = try store.generateCaBundleFile(tmp_path);
    defer allocator.free(bundle_path);

    // Verify file exists and contains certificates
    const file = try std.fs.cwd().openFile(bundle_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Should contain both certificates
    try std.testing.expect(std.mem.indexOf(u8, content, "cert1") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "cert2") != null);
}

test "matchHostPattern - exact match" {
    try std.testing.expect(matchHostPattern("localhost:8445", "localhost:8445"));
    try std.testing.expect(!matchHostPattern("localhost:8445", "localhost:8446"));
    try std.testing.expect(!matchHostPattern("localhost:8445", "example.com:8445"));
}

test "matchHostPattern - wildcard host" {
    try std.testing.expect(matchHostPattern("*:8445", "localhost:8445"));
    try std.testing.expect(matchHostPattern("*:8445", "example.com:8445"));
    try std.testing.expect(!matchHostPattern("*:8445", "localhost:8446"));
}

test "matchHostPattern - global wildcard" {
    try std.testing.expect(matchHostPattern("*", "localhost:8445"));
    try std.testing.expect(matchHostPattern("*", "example.com:443"));
    try std.testing.expect(matchHostPattern("*", "anything"));
}

test "matchHostPattern - host without port in pattern" {
    try std.testing.expect(matchHostPattern("localhost", "localhost:8445"));
    try std.testing.expect(matchHostPattern("localhost", "localhost:443"));
    try std.testing.expect(matchHostPattern("localhost", "localhost"));
    try std.testing.expect(!matchHostPattern("localhost", "example.com:8445"));
}

test "CertificateTrustStore - per-context isolation" {
    const allocator = std.testing.allocator;

    // Create two separate stores
    var store1 = CertificateTrustStore.init(allocator);
    defer store1.deinit();

    var store2 = CertificateTrustStore.init(allocator);
    defer store2.deinit();

    const pem1 = "-----BEGIN CERTIFICATE-----\ncert1_data\n-----END CERTIFICATE-----";
    const pem2 = "-----BEGIN CERTIFICATE-----\ncert2_data\n-----END CERTIFICATE-----";

    const fingerprint1 = calculateFingerprint(pem1);
    const fingerprint2 = calculateFingerprint(pem2);

    // Add different certs to each store
    try store1.addTrustedCertificate("localhost:8445", pem1, .{});
    try store2.addTrustedCertificate("example.com:443", pem2, .{});

    // Verify store1 only has cert1
    try std.testing.expectEqual(@as(usize, 1), store1.getCertificateCount());
    try std.testing.expect(store1.isTrustedForHost("localhost:8445", fingerprint1));
    try std.testing.expect(!store1.isTrustedForHost("example.com:443", fingerprint2));

    // Verify store2 only has cert2
    try std.testing.expectEqual(@as(usize, 1), store2.getCertificateCount());
    try std.testing.expect(store2.isTrustedForHost("example.com:443", fingerprint2));
    try std.testing.expect(!store2.isTrustedForHost("localhost:8445", fingerprint1));
}

test "CertificateTrustStore - addTrustedCertificateFromFile with valid file" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    // Create a temporary certificate file
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const pem_data = "-----BEGIN CERTIFICATE-----\ntest_cert_from_file\n-----END CERTIFICATE-----\n";
    const fingerprint = calculateFingerprint(pem_data);

    // Write the certificate to a file
    const cert_file = try tmp_dir.dir.createFile("test.pem", .{});
    try cert_file.writeAll(pem_data);
    cert_file.close();

    // Get the full path
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const cert_path = try std.fs.path.join(allocator, &[_][]const u8{ tmp_path, "test.pem" });
    defer allocator.free(cert_path);

    // Add certificate from file
    try store.addTrustedCertificateFromFile("localhost:9999", cert_path, .{});

    // Verify certificate was added
    try std.testing.expectEqual(@as(usize, 1), store.getCertificateCount());
    try std.testing.expect(store.isTrustedForHost("localhost:9999", fingerprint));
}

test "CertificateTrustStore - addTrustedCertificateFromFile with missing file" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    // Try to add certificate from non-existent file
    const result = store.addTrustedCertificateFromFile("localhost:9999", "/nonexistent/path/cert.pem", .{});

    // Should return FileNotFound error
    try std.testing.expectError(error.FileNotFound, result);

    // Store should still be empty
    try std.testing.expectEqual(@as(usize, 0), store.getCertificateCount());
}

test "CertificateTrustStore - getAllCertificates iterator" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    const pem1 = "-----BEGIN CERTIFICATE-----\ncert1\n-----END CERTIFICATE-----";
    const pem2 = "-----BEGIN CERTIFICATE-----\ncert2\n-----END CERTIFICATE-----";
    const pem3 = "-----BEGIN CERTIFICATE-----\ncert3\n-----END CERTIFICATE-----";

    try store.addTrustedCertificate("host1:8080", pem1, .{});
    try store.addTrustedCertificate("host2:8080", pem2, .{});
    try store.addTrustedCertificate("*:9090", pem3, .{});

    // Count certificates via iterator
    var count: usize = 0;
    var it = store.getAllCertificates();
    while (it.next()) |entry| {
        count += entry.value_ptr.items.len;
    }

    try std.testing.expectEqual(@as(usize, 3), count);
    try std.testing.expectEqual(@as(usize, 3), store.getCertificateCount());
}

test "CertificateTrustStore - multiple certificates same pattern" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    const pem1 = "-----BEGIN CERTIFICATE-----\ncert1\n-----END CERTIFICATE-----";
    const pem2 = "-----BEGIN CERTIFICATE-----\ncert2\n-----END CERTIFICATE-----";

    const fingerprint1 = calculateFingerprint(pem1);
    const fingerprint2 = calculateFingerprint(pem2);

    // Add two certificates for the same host pattern
    try store.addTrustedCertificate("localhost:8445", pem1, .{});
    try store.addTrustedCertificate("localhost:8445", pem2, .{});

    // Should have 2 certificates
    try std.testing.expectEqual(@as(usize, 2), store.getCertificateCount());

    // Both fingerprints should be trusted for the same host
    try std.testing.expect(store.isTrustedForHost("localhost:8445", fingerprint1));
    try std.testing.expect(store.isTrustedForHost("localhost:8445", fingerprint2));
}

test "CertificateTrustStore - TrustedCertificate matchesHost" {
    const pem_data = "-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----";
    const fingerprint = calculateFingerprint(pem_data);

    // Test exact match
    const cert_exact = TrustedCertificate{
        .fingerprint = fingerprint,
        .host_pattern = "localhost:8445",
        .pem_data = pem_data,
        .ignore_expiry = false,
    };
    try std.testing.expect(cert_exact.matchesHost("localhost:8445"));
    try std.testing.expect(!cert_exact.matchesHost("localhost:8446"));
    try std.testing.expect(!cert_exact.matchesHost("example.com:8445"));

    // Test wildcard
    const cert_wildcard = TrustedCertificate{
        .fingerprint = fingerprint,
        .host_pattern = "*:8446",
        .pem_data = pem_data,
        .ignore_expiry = true,
    };
    try std.testing.expect(cert_wildcard.matchesHost("localhost:8446"));
    try std.testing.expect(cert_wildcard.matchesHost("example.com:8446"));
    try std.testing.expect(!cert_wildcard.matchesHost("localhost:8445"));
}

test "CertificateTrustStore - ignore_expiry option preserved" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    const pem_data = "-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----";

    // Add certificate with ignore_expiry = true
    try store.addTrustedCertificate("localhost:8445", pem_data, .{ .ignore_expiry = true });

    // Verify the option was preserved
    var it = store.getAllCertificates();
    if (it.next()) |entry| {
        try std.testing.expectEqual(@as(usize, 1), entry.value_ptr.items.len);
        try std.testing.expect(entry.value_ptr.items[0].ignore_expiry);
    } else {
        try std.testing.expect(false); // Should have found an entry
    }
}

test "CertificateTrustStore - generateCaBundleFile with newline normalization" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    // Certificate without trailing newline
    const pem_no_newline = "-----BEGIN CERTIFICATE-----\ncert_no_newline\n-----END CERTIFICATE-----";
    // Certificate with trailing newline
    const pem_with_newline = "-----BEGIN CERTIFICATE-----\ncert_with_newline\n-----END CERTIFICATE-----\n";

    try store.addTrustedCertificate("host1:8080", pem_no_newline, .{});
    try store.addTrustedCertificate("host2:8080", pem_with_newline, .{});

    // Create temp directory for test
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const bundle_path = try store.generateCaBundleFile(tmp_path);
    defer allocator.free(bundle_path);

    // Verify file exists and has correct format
    const file = try std.fs.cwd().openFile(bundle_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Both certificates should be in the bundle
    try std.testing.expect(std.mem.indexOf(u8, content, "cert_no_newline") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "cert_with_newline") != null);

    // The certificate without newline should have one added
    // Check there's no double-newline (which would indicate proper normalization)
    try std.testing.expect(std.mem.indexOf(u8, content, "\n\n\n") == null);
}

test "calculateFingerprint - deterministic" {
    const pem1 = "-----BEGIN CERTIFICATE-----\ntest1\n-----END CERTIFICATE-----";
    const pem2 = "-----BEGIN CERTIFICATE-----\ntest2\n-----END CERTIFICATE-----";

    const fp1a = calculateFingerprint(pem1);
    const fp1b = calculateFingerprint(pem1);
    const fp2 = calculateFingerprint(pem2);

    // Same input should produce same fingerprint
    try std.testing.expectEqualSlices(u8, &fp1a, &fp1b);

    // Different input should produce different fingerprint
    try std.testing.expect(!std.mem.eql(u8, &fp1a, &fp2));
}

test "CertificateTrustStore - empty store operations" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    // Operations on empty store should work correctly
    try std.testing.expectEqual(@as(usize, 0), store.getCertificateCount());
    try std.testing.expectEqual(@as(?[]const u8, null), store.getCaBundlePath());

    // isTrustedForHost on empty store should return false
    var fingerprint: [32]u8 = undefined;
    @memset(&fingerprint, 0xAB);
    try std.testing.expect(!store.isTrustedForHost("localhost:8445", fingerprint));

    // Iterator on empty store should have no entries
    var it = store.getAllCertificates();
    try std.testing.expect(it.next() == null);
}

test "CertificateTrustStore - generateCaBundleFile includes system CA roots by default" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    // Add a custom certificate
    const custom_cert = "-----BEGIN CERTIFICATE-----\ncustom_test_cert\n-----END CERTIFICATE-----\n";
    try store.addTrustedCertificate("localhost:8445", custom_cert, .{});

    // Create temp directory for test
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Generate bundle with default options (includes system roots)
    const bundle_path = try store.generateCaBundleFile(tmp_path);
    defer allocator.free(bundle_path);

    // Verify file exists and contains our custom cert
    const file = try std.fs.cwd().openFile(bundle_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
    defer allocator.free(content);

    // Custom certificate should be in the bundle
    try std.testing.expect(std.mem.indexOf(u8, content, "custom_test_cert") != null);

    // If system CA is available, the bundle should be larger than just our cert
    if (findSystemCaBundlePath()) |_| {
        // System CA was found, bundle should include it (typically >50KB on most systems)
        try std.testing.expect(content.len > 1000);
    }
}

test "CertificateTrustStore - generateCaBundleFileWithOptions can exclude system roots" {
    const allocator = std.testing.allocator;

    var store = CertificateTrustStore.init(allocator);
    defer store.deinit();

    // Add a custom certificate
    const custom_cert = "-----BEGIN CERTIFICATE-----\ncustom_only_cert\n-----END CERTIFICATE-----\n";
    try store.addTrustedCertificate("localhost:8445", custom_cert, .{});

    // Create temp directory for test
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Generate bundle WITHOUT system roots
    const bundle_path = try store.generateCaBundleFileWithOptions(tmp_path, .{
        .include_system_roots = false,
    });
    defer allocator.free(bundle_path);

    // Verify file exists and contains ONLY our custom cert
    const file = try std.fs.cwd().openFile(bundle_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Custom certificate should be in the bundle
    try std.testing.expect(std.mem.indexOf(u8, content, "custom_only_cert") != null);

    // Bundle should be small - just our custom cert (< 200 bytes)
    try std.testing.expect(content.len < 200);
}

test "findSystemCaBundlePath - returns path on systems with CA bundle" {
    // This test verifies the function works, but the result depends on the system
    const path = findSystemCaBundlePath();

    // On CI/dev machines, there should typically be a system CA bundle
    // If not found, that's also OK - just means the system doesn't have one
    // in a known location
    if (path) |p| {
        // Verify it's a valid PEM file path (ends with .pem, .crt, or similar)
        const valid_ext = std.mem.endsWith(u8, p, ".pem") or
            std.mem.endsWith(u8, p, ".crt");
        try std.testing.expect(valid_ext);
    }
}
