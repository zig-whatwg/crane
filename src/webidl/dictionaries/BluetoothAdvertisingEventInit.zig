//! WebIDL dictionary: BluetoothAdvertisingEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const BluetoothAdvertisingEventInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from EventInit
    base: EventInit,

    device: *runtime.Instance,
    uuids: ?[]const typedefs.DOMStringOrUnsignedLong = null,
    name: ?runtime.DOMString = null,
    appearance: ?u16 = null,
    txPower: ?i8 = null,
    rssi: ?i8 = null,
    manufacturerData: ?*runtime.Instance = null,
    serviceData: ?*runtime.Instance = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "device", "BluetoothDevice" },
        .{ "manufacturerData", "BluetoothManufacturerDataMap" },
        .{ "serviceData", "BluetoothServiceDataMap" },
    };
};
