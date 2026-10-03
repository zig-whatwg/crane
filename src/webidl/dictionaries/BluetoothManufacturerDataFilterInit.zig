//! WebIDL dictionary: BluetoothManufacturerDataFilterInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const BluetoothDataFilterInit = @import("BluetoothDataFilterInit.zig").BluetoothDataFilterInit;

pub const BluetoothManufacturerDataFilterInit = struct {
    // Inherited from BluetoothDataFilterInit
    base: BluetoothDataFilterInit,

    companyIdentifier: u16,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"companyIdentifier"};
};
