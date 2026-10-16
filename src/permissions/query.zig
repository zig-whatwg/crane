//! Pure rules for the Permissions API's live query implementation.
//! The legacy storage/registry types are not a Browser permission store.
const types = @import("types.zig");

/// Permissions 6.2.1 step 4: supported powerful features, default unsupported.
/// This allowlist follows the shipped browser majority (aligned wpt.fyi stable
/// runs 6218298311311360, 4877098740350976, 5164107446878208). Storage access
/// is also in Blink, Gecko and WebKit's Permissions implementations.
pub fn supportedName(name: []const u8) ?types.PermissionName {
    const parsed = types.PermissionName.fromString(name) orelse return null;
    return switch (parsed) {
        .geolocation, .notifications, .push, .persistent_storage, .midi, .storage_access, .screen_wake_lock, .camera, .microphone => parsed,
        else => null,
    };
}

/// Permissions 5.1 steps 2 and 8, before a Browser has a permission store or
/// an adapter that governs permissions: insecure contexts deny; secure ones
/// use the ungoverned platform default.
pub fn defaultState(is_secure_context: bool) types.PermissionState {
    return if (is_secure_context) .prompt else .denied;
}

/// The default permission query algorithm, with Storage Access 4's query
/// algorithm step 2: do not reveal a denied storage-access permission.
pub fn resultState(name: types.PermissionName, state: types.PermissionState) types.PermissionState {
    return if (name == .storage_access and state == .denied) .prompt else state;
}
