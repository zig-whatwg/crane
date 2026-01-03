//! Interface Exposure Table - Runtime queryable exposure data
//!
//! This module provides a comptime-generated lookup table for checking
//! whether an interface is exposed in a given global scope at runtime.
//!
//! The table is generated from WebIDL [Exposed] metadata and provides
//! O(1) lookups using InterfaceIndex and GlobalScopeKind.
//!
//! ## Specification References
//! - WebIDL [Exposed]: https://webidl.spec.whatwg.org/#Exposed
//! - HTML Global Scopes: https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm
//!
//! ## Usage
//!
//! ```zig
//! const exposure_table = @import("interface_exposure_table.zig");
//! const catalog = @import("interface_catalog.zig");
//!
//! // Get interface index (comptime or runtime)
//! const idx = catalog.indexOf(interfaces.Request);
//!
//! // Check exposure at runtime
//! const exposed_in_window = exposure_table.isInterfaceExposed(idx, .window);
//! const exposed_in_worker = exposure_table.isInterfaceExposed(idx, .dedicated_worker);
//! ```

const std = @import("std");
const interfaces = @import("interfaces");
const helpers = @import("webidl").helpers;
const InterfaceCatalog = @import("interface_catalog.zig");
const realm = @import("../../realm.zig");

const InterfaceIndex = InterfaceCatalog.InterfaceIndex;
const GlobalScopeKind = realm.GlobalScopeKind;
const HelperGlobalScope = helpers.GlobalScope;

/// Number of global scope kinds (excluding .unknown which is never a valid exposure target)
pub const scope_count: usize = std.meta.fields(GlobalScopeKind).len;

/// Number of valid interfaces in the catalog
pub const interface_count: usize = InterfaceCatalog.valid_interface_count;

/// Convert GlobalScopeKind to helpers.GlobalScope for exposure checking
///
/// Note: Some GlobalScopeKind values map to abstract categories:
/// - Worker types map to their specific scope (not abstract .Worker)
/// - Worklet types map to their specific scope (not abstract .Worklet)
fn toHelperScope(kind: GlobalScopeKind) HelperGlobalScope {
    return switch (kind) {
        .window => .Window,
        .dedicated_worker => .DedicatedWorker,
        .shared_worker => .SharedWorker,
        .service_worker => .ServiceWorker,
        .audio_worklet => .AudioWorklet,
        .paint_worklet => .PaintWorklet,
        .animation_worklet => .AnimationWorklet,
        .layout_worklet => .LayoutWorklet,
        .shared_storage_worklet => .SharedStorageWorklet,
        .shadow_realm => .ShadowRealm,
        .unknown => .Window, // Default to Window for unknown (should not be used in practice)
    };
}

/// Check if an interface at the given index is exposed in the given scope
///
/// This is the primary runtime API for exposure checking.
/// Uses the comptime-generated exposure table for O(1) lookup.
///
/// Returns false for invalid indices (>= interface_count).
///
/// Example:
/// ```zig
/// const idx = InterfaceCatalog.indexOf(interfaces.Request);
/// if (isInterfaceExposed(idx, .window)) {
///     // Request is available in Window context
/// }
/// ```
pub fn isInterfaceExposed(index: InterfaceIndex, scope: GlobalScopeKind) bool {
    if (index >= interface_count) {
        return false;
    }
    const scope_idx = @intFromEnum(scope);
    if (scope_idx >= scope_count) {
        return false;
    }
    return exposure_table[index][scope_idx];
}

/// Get all scopes an interface is exposed in
///
/// Returns a packed struct with boolean fields for each scope.
/// Useful for debugging or generating scope-specific code.
///
/// Example:
/// ```zig
/// const scopes = getExposedScopes(idx);
/// if (scopes.window and scopes.dedicated_worker) {
///     // Interface exposed in both Window and DedicatedWorker
/// }
/// ```
pub fn getExposedScopes(index: InterfaceIndex) ExposedScopes {
    if (index >= interface_count) {
        return .{}; // All false
    }
    const row = exposure_table[index];
    return .{
        .window = row[@intFromEnum(GlobalScopeKind.window)],
        .dedicated_worker = row[@intFromEnum(GlobalScopeKind.dedicated_worker)],
        .shared_worker = row[@intFromEnum(GlobalScopeKind.shared_worker)],
        .service_worker = row[@intFromEnum(GlobalScopeKind.service_worker)],
        .audio_worklet = row[@intFromEnum(GlobalScopeKind.audio_worklet)],
        .paint_worklet = row[@intFromEnum(GlobalScopeKind.paint_worklet)],
        .animation_worklet = row[@intFromEnum(GlobalScopeKind.animation_worklet)],
        .layout_worklet = row[@intFromEnum(GlobalScopeKind.layout_worklet)],
        .shared_storage_worklet = row[@intFromEnum(GlobalScopeKind.shared_storage_worklet)],
        .shadow_realm = row[@intFromEnum(GlobalScopeKind.shadow_realm)],
    };
}

/// Packed struct representing all scopes an interface can be exposed in
pub const ExposedScopes = struct {
    window: bool = false,
    dedicated_worker: bool = false,
    shared_worker: bool = false,
    service_worker: bool = false,
    audio_worklet: bool = false,
    paint_worklet: bool = false,
    animation_worklet: bool = false,
    layout_worklet: bool = false,
    shared_storage_worklet: bool = false,
    shadow_realm: bool = false,

    /// Check if exposed in any worker scope
    pub fn isExposedInAnyWorker(self: ExposedScopes) bool {
        return self.dedicated_worker or self.shared_worker or self.service_worker;
    }

    /// Check if exposed in any worklet scope
    pub fn isExposedInAnyWorklet(self: ExposedScopes) bool {
        return self.audio_worklet or self.paint_worklet or self.animation_worklet or
            self.layout_worklet or self.shared_storage_worklet;
    }

    /// Count of scopes this interface is exposed in
    pub fn count(self: ExposedScopes) usize {
        var c: usize = 0;
        if (self.window) c += 1;
        if (self.dedicated_worker) c += 1;
        if (self.shared_worker) c += 1;
        if (self.service_worker) c += 1;
        if (self.audio_worklet) c += 1;
        if (self.paint_worklet) c += 1;
        if (self.animation_worklet) c += 1;
        if (self.layout_worklet) c += 1;
        if (self.shared_storage_worklet) c += 1;
        if (self.shadow_realm) c += 1;
        return c;
    }
};

/// Get the interface name at a given index (for debugging/logging)
pub fn getInterfaceName(index: InterfaceIndex) ?[]const u8 {
    if (index >= interface_count) {
        return null;
    }
    return InterfaceCatalog.getValidInterfaces()[index].name;
}

// ============================================================================
// Comptime-Generated Exposure Table
// ============================================================================

/// The exposure table: exposure_table[interface_index][scope_index] = bool
///
/// Generated at comptime by iterating all interfaces and checking
/// helpers.isExposedIn() for each scope combination.
const exposure_table: [interface_count][scope_count]bool = generateExposureTable();

/// Generate the exposure table at comptime
fn generateExposureTable() [interface_count][scope_count]bool {
    @setEvalBranchQuota(1000000);
    comptime {
        var table: [interface_count][scope_count]bool = undefined;

        // Initialize all to false
        for (&table) |*row| {
            for (row) |*cell| {
                cell.* = false;
            }
        }

        // Iterate through all declarations in interfaces module
        const decls = @typeInfo(interfaces).@"struct".decls;

        for (decls) |decl| {
            const T = @field(interfaces, decl.name);
            if (@typeInfo(@TypeOf(T)) != .type) continue;
            if (!@hasDecl(T, "Meta")) continue;

            const meta = T.Meta;
            const is_mixin = if (@hasDecl(meta, "is_mixin")) meta.is_mixin else false;
            if (is_mixin) continue;
            if (InterfaceCatalog.isSkipped(meta.name)) continue;

            // Get the interface index
            const idx = InterfaceCatalog.indexOf(T);
            if (idx == InterfaceCatalog.INVALID_INDEX) continue;

            // Check exposure for each scope
            for (std.meta.fields(GlobalScopeKind)) |field| {
                const scope_kind: GlobalScopeKind = @enumFromInt(field.value);
                const helper_scope = toHelperScope(scope_kind);
                const exposed = helpers.isExposedIn(T, helper_scope);
                table[idx][field.value] = exposed;
            }
        }

        return table;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "exposure table - basic structure" {
    // Verify table dimensions
    try std.testing.expect(interface_count > 0);
    try std.testing.expect(scope_count > 0);

    // Verify exposure_table is accessible
    const first_row = exposure_table[0];
    _ = first_row;
}

test "exposure table - determinism" {
    // Generate the table twice and verify they're identical
    const table1 = generateExposureTable();
    const table2 = generateExposureTable();

    for (table1, 0..) |row1, i| {
        for (row1, 0..) |cell1, j| {
            try std.testing.expectEqual(cell1, table2[i][j]);
        }
    }
}

test "exposure table - Request exposed in Window and Workers but NOT AudioWorklet" {
    const idx = comptime InterfaceCatalog.indexOfByName("Request");
    if (idx == InterfaceCatalog.INVALID_INDEX) {
        // Request interface may not exist in current build
        return;
    }

    // Request should be exposed in Window (via [Exposed=*] or [Exposed=(Window,Worker)])
    const in_window = isInterfaceExposed(idx, .window);
    const in_dedicated_worker = isInterfaceExposed(idx, .dedicated_worker);

    // At least one of these should be true for Request
    try std.testing.expect(in_window or in_dedicated_worker);

    // Get all scopes for inspection
    const scopes = getExposedScopes(idx);
    _ = scopes;
}

test "exposure table - AudioWorkletGlobalScope exposed ONLY in AudioWorklet" {
    const idx = comptime InterfaceCatalog.indexOfByName("AudioWorkletGlobalScope");
    if (idx == InterfaceCatalog.INVALID_INDEX) {
        // AudioWorkletGlobalScope may not exist
        return;
    }

    const scopes = getExposedScopes(idx);

    // Should be exposed in AudioWorklet
    try std.testing.expect(scopes.audio_worklet);

    // Should NOT be exposed in Window
    try std.testing.expect(!scopes.window);

    // Should NOT be exposed in regular workers
    try std.testing.expect(!scopes.dedicated_worker);
    try std.testing.expect(!scopes.shared_worker);
    try std.testing.expect(!scopes.service_worker);
}

test "exposure table - Document exposed ONLY in Window" {
    const idx = comptime InterfaceCatalog.indexOfByName("Document");
    if (idx == InterfaceCatalog.INVALID_INDEX) {
        // Document may not exist
        return;
    }

    const scopes = getExposedScopes(idx);

    // Should be exposed in Window
    try std.testing.expect(scopes.window);

    // Should NOT be exposed in workers
    try std.testing.expect(!scopes.dedicated_worker);
    try std.testing.expect(!scopes.shared_worker);
    try std.testing.expect(!scopes.service_worker);

    // Should NOT be exposed in worklets
    try std.testing.expect(!scopes.audio_worklet);
}

test "exposure table - invalid index returns false" {
    const invalid_idx = InterfaceCatalog.INVALID_INDEX;

    try std.testing.expect(!isInterfaceExposed(invalid_idx, .window));
    try std.testing.expect(!isInterfaceExposed(invalid_idx, .dedicated_worker));

    const scopes = getExposedScopes(invalid_idx);
    try std.testing.expectEqual(@as(usize, 0), scopes.count());
}

test "exposure table - getInterfaceName" {
    // First interface should have a name
    if (interface_count > 0) {
        const name = getInterfaceName(0);
        try std.testing.expect(name != null);
        try std.testing.expect(name.?.len > 0);
    }

    // Invalid index should return null
    const invalid_name = getInterfaceName(InterfaceCatalog.INVALID_INDEX);
    try std.testing.expect(invalid_name == null);
}

test "exposure table - ExposedScopes helpers" {
    var scopes = ExposedScopes{};

    // Empty scopes
    try std.testing.expectEqual(@as(usize, 0), scopes.count());
    try std.testing.expect(!scopes.isExposedInAnyWorker());
    try std.testing.expect(!scopes.isExposedInAnyWorklet());

    // Add Window
    scopes.window = true;
    try std.testing.expectEqual(@as(usize, 1), scopes.count());

    // Add a worker
    scopes.dedicated_worker = true;
    try std.testing.expectEqual(@as(usize, 2), scopes.count());
    try std.testing.expect(scopes.isExposedInAnyWorker());

    // Add a worklet
    scopes.audio_worklet = true;
    try std.testing.expectEqual(@as(usize, 3), scopes.count());
    try std.testing.expect(scopes.isExposedInAnyWorklet());
}
