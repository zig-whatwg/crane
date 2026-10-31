//! Permissions 3.2: the Browser's automation overrides, before the platform
//! default. A BrowserScope supplement owns this store; it contains values,
//! never realms, platform objects, or script handles.
//!
//! The caller supplies the feature's already-generated permission key.
//! Key generation belongs to the environment settings object (5.1 step 5),
//! not to this store: an origin or site guessed from a URL is not a key.
const std = @import("std");
const types = @import("types.zig");
const Descriptor = types.PermissionDescriptor;
const State = types.PermissionState;

pub const OverrideStore = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    entries: std.HashMapUnmanaged(Key, States, KeyContext, 80) = .empty,

    const Key = struct { permission_key: []const u8, name: types.PermissionName };
    const States = [2]?State;
    const KeyContext = struct {
        pub fn hash(_: @This(), key: Key) u64 {
            var h = std.hash.Wyhash.init(0);
            h.update(key.permission_key);
            h.update(&.{@intFromEnum(key.name)});
            return h.final();
        }

        pub fn eql(_: @This(), a: Key, b: Key) bool {
            return a.name == b.name and std.mem.eql(u8, a.permission_key, b.permission_key);
        }
    };

    pub fn init(allocator: std.mem.Allocator) OverrideStore {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *OverrideStore) void {
        var entries = self.entries.keyIterator();
        while (entries.next()) |key| self.allocator.free(key.permission_key);
        self.entries.deinit(self.allocator);
    }

    /// Permissions 3.2 "get a permission store entry", steps 1-2. Absence
    /// is distinct from an explicit prompt, which overrides a platform grant.
    pub fn get(self: *OverrideStore, permission_key: []const u8, descriptor: Descriptor) ?State {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const states = self.entries.get(.{ .permission_key = permission_key, .name = descriptor.name }) orelse return null;
        return states[strength(descriptor)];
    }

    /// Permissions 3.2 "set a permission store entry", steps 1-3. Returns
    /// whether any descriptor's value changed. A replacement allocates
    /// nothing; a failed insertion leaves all entries unchanged.
    pub fn set(self: *OverrideStore, permission_key: []const u8, descriptor: Descriptor, state: State) std.mem.Allocator.Error!bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const key: Key = .{ .permission_key = permission_key, .name = descriptor.name };
        if (self.entries.getPtr(key)) |states| return update(states, descriptor, state);

        const owned_key = try self.allocator.dupe(u8, permission_key);
        errdefer self.allocator.free(owned_key);
        var states: States = @splat(null);
        _ = update(&states, descriptor, state);
        try self.entries.put(self.allocator, .{ .permission_key = owned_key, .name = descriptor.name }, states);
        return true;
    }

    fn update(states: *States, descriptor: Descriptor, state: State) bool {
        const before = states.*;
        const index = strength(descriptor);
        states[index] = state;
        // Permissions 4's partial order: granting the stronger descriptor
        // grants the weaker; denying the weaker denies the stronger. When
        // resetting either side to prompt, remove an incompatible prior
        // grant/denial on the other side. Both states change under one lock.
        // Compare Chromium PermissionOverrides::Set (content/browser/
        // permissions/permission_overrides.cc): related MIDI overrides are
        // updated together before subscriptions are notified.
        if (hasStrength(descriptor.name)) {
            if (index == 1) {
                if (state == .granted or states[0] == .denied) states[0] = state;
            } else if (state == .denied or states[1] == .granted) {
                states[1] = state;
            }
        }
        return !std.meta.eql(before, states.*);
    }

    fn hasStrength(name: types.PermissionName) bool {
        return switch (name) {
            .midi, .camera, .push => true,
            else => false,
        };
    }

    /// The feature specifications' descriptor defaults and partial orders:
    /// MIDI sysex and camera panTiltZoom strengthen a grant; push's
    /// userVisibleOnly restricts one, so false is the stronger descriptor.
    fn strength(descriptor: Descriptor) u1 {
        return @intFromBool(switch (descriptor.name) {
            .midi => descriptor.extra == .midi and descriptor.extra.midi.sysex,
            .camera => descriptor.extra == .camera and descriptor.extra.camera.pan_tilt_zoom,
            .push => descriptor.extra != .push or !descriptor.extra.push.user_visible_only,
            else => false,
        });
    }
};
