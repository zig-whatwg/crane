//! WebIDL dictionary: BluetoothLEScanFilterInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const BluetoothLEScanFilterInit = struct {
    services: ?*const anyopaque = null,
    name: ?runtime.DOMString = null,
    namePrefix: ?runtime.DOMString = null,
    manufacturerData: ?*const anyopaque = null,
    serviceData: ?*const anyopaque = null,
};
