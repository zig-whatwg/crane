//! Credentials API
//!
//! Spec: Credential Management Level 1
//! https://w3c.github.io/webappsec-credential-management/
//!
//! This module implements the CredentialsContainer interface which
//! provides access to credential storage.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Credential mediation requirement
pub const CredentialMediationRequirement = enum {
    silent,
    optional,
    conditional,
    required,
};

/// Base credential interface
pub const Credential = struct {
    id: []const u8,
    type_name: []const u8,
};

/// Credential request options
pub const CredentialRequestOptions = struct {
    mediation: CredentialMediationRequirement = .optional,
    password: bool = false,
};

/// Credential creation options
pub const CredentialCreationOptions = struct {
    mediation: CredentialMediationRequirement = .optional,
};

/// Error types for credential operations
pub const CredentialError = error{
    /// User denied access
    NotAllowedError,
    /// Credential not found
    NotFoundError,
    /// Invalid state
    InvalidStateError,
    /// Abort requested
    AbortError,
    /// Out of memory
    OutOfMemory,
};

/// CredentialsContainer interface implementation
/// Spec: CredentialsContainer interface
/// [SecureContext] required
pub const CredentialsContainer = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Get a credential
    /// Spec: get(options)
    pub fn get(self: *Self, options: CredentialRequestOptions) CredentialError!?Credential {
        _ = self;
        _ = options;
        // Stub: no credentials available
        return null;
    }

    /// Store a credential
    /// Spec: store(credential)
    pub fn store(self: *Self, credential: Credential) CredentialError!void {
        _ = self;
        _ = credential;
        // Stub: silently succeed
    }

    /// Create a new credential
    /// Spec: create(options)
    pub fn create(self: *Self, options: CredentialCreationOptions) CredentialError!?Credential {
        _ = self;
        _ = options;
        // Stub: no creation support
        return null;
    }

    /// Prevent silent access
    /// Spec: preventSilentAccess()
    pub fn preventSilentAccess(self: *Self) CredentialError!void {
        _ = self;
        // Stub: silently succeed
    }

    /// Check if conditional mediation is available
    /// Spec: Credential.isConditionalMediationAvailable()
    pub fn isConditionalMediationAvailable(_: *Self) bool {
        return false;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "CredentialsContainer - init and deinit" {
    const allocator = std.testing.allocator;

    var credentials = CredentialsContainer.init(allocator);
    defer credentials.deinit();

    // Should return null (no credentials)
    const result = try credentials.get(.{});
    try std.testing.expect(result == null);
}

test "CredentialsContainer - preventSilentAccess" {
    const allocator = std.testing.allocator;

    var credentials = CredentialsContainer.init(allocator);
    defer credentials.deinit();

    // Should succeed silently
    try credentials.preventSilentAccess();
}

test "CredentialsContainer - isConditionalMediationAvailable" {
    const allocator = std.testing.allocator;

    var credentials = CredentialsContainer.init(allocator);
    defer credentials.deinit();

    // Stub returns false
    try std.testing.expect(!credentials.isConditionalMediationAvailable());
}
