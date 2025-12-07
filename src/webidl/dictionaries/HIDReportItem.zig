//! WebIDL dictionary: HIDReportItem
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const HIDReportItem = struct {
    isAbsolute: ?bool = null,
    isArray: ?bool = null,
    isBufferedBytes: ?bool = null,
    isConstant: ?bool = null,
    isLinear: ?bool = null,
    isRange: ?bool = null,
    isVolatile: ?bool = null,
    hasNull: ?bool = null,
    hasPreferredState: ?bool = null,
    wrap: ?bool = null,
    usages: ?[]const u32 = null,
    usageMinimum: ?u32 = null,
    usageMaximum: ?u32 = null,
    reportSize: ?u16 = null,
    reportCount: ?u16 = null,
    unitExponent: ?i8 = null,
    unitSystem: ?enums.HIDUnitSystem = null,
    unitFactorLengthExponent: ?i8 = null,
    unitFactorMassExponent: ?i8 = null,
    unitFactorTimeExponent: ?i8 = null,
    unitFactorTemperatureExponent: ?i8 = null,
    unitFactorCurrentExponent: ?i8 = null,
    unitFactorLuminousIntensityExponent: ?i8 = null,
    logicalMinimum: ?i32 = null,
    logicalMaximum: ?i32 = null,
    physicalMinimum: ?i32 = null,
    physicalMaximum: ?i32 = null,
    strings: ?[]const runtime.DOMString = null,
};
