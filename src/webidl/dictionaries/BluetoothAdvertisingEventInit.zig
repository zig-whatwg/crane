//! WebIDL dictionary: BluetoothAdvertisingEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const BluetoothAdvertisingEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    device: anyopaque,
    uuids: ?anyopaque = null,
    name: ?runtime.DOMString = null,
    appearance: ?u16 = null,
    txPower: ?i8 = null,
    rssi: ?i8 = null,
    manufacturerData: ?anyopaque = null,
    serviceData: ?anyopaque = null,
};
