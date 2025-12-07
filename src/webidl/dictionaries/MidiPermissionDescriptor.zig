//! WebIDL dictionary: MidiPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const MidiPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    sysex: ?bool = null,
};
