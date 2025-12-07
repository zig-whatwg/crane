//! WebIDL dictionary: LayoutConstraintsOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const LayoutConstraintsOptions = struct {
    availableInlineSize: ?f64 = null,
    availableBlockSize: ?f64 = null,
    fixedInlineSize: ?f64 = null,
    fixedBlockSize: ?f64 = null,
    percentageInlineSize: ?f64 = null,
    percentageBlockSize: ?f64 = null,
    blockFragmentationOffset: ?f64 = null,
    blockFragmentationType: ?enums.BlockFragmentationType = null,
    data: ?v8.JSValue = null,
};
