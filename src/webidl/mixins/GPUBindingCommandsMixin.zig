//! Auto-generated mixin: GPUBindingCommandsMixin
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUBindingCommandsMixinImpl = @import("impls").GPUBindingCommandsMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUIndex32 = @import("typedefs").GPUIndex32;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUBindGroup = @import("interfaces").GPUBindGroup;
const GPUBufferDynamicOffset = @import("typedefs").GPUBufferDynamicOffset;
const GPUSize32 = @import("typedefs").GPUSize32;

pub const impl = @import("impls").GPUBindingCommandsMixin;

pub fn call_setBindGroup(instance: *runtime.Instance, index: GPUIndex32, bindGroup: ?*runtime.Instance, dynamicOffsets: webidl.Opt(runtime.JSValue)) anyerror!void {
    return try GPUBindingCommandsMixinImpl.call_setBindGroup(instance, index, bindGroup, dynamicOffsets);
}

pub fn call_setBindGroup__1(instance: *runtime.Instance, index: GPUIndex32, bindGroup: ?*runtime.Instance, dynamicOffsetsData: runtime.JSValue, dynamicOffsetsDataStart: GPUSize64, dynamicOffsetsDataLength: GPUSize32) anyerror!void {
    if (comptime @hasDecl(GPUBindingCommandsMixinImpl, "call_setBindGroup__1")) {
        return try GPUBindingCommandsMixinImpl.call_setBindGroup__1(instance, index, bindGroup, dynamicOffsetsData, dynamicOffsetsDataStart, dynamicOffsetsDataLength);
    } else {
        return error.NotImplemented;
    }
}

/// WebIDL overload sets: every overload of each overloaded operation,
/// in IDL order, for the overload resolution algorithm
/// (webidl.overload_resolution). The binding is installed for the first
/// overload and forwards to the one the arguments select.
pub const overloads = .{
    .{ "setBindGroup", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_setBindGroup", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "GPUBindGroup")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").GPUBindGroup.State) } else .other)}, .nullable = true }, .{ .kinds = &.{.sequence}, .optionality = .optional } } },
        .{ .function = "call_setBindGroup__1", .implemented = @hasDecl(GPUBindingCommandsMixinImpl, "call_setBindGroup__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "GPUBindGroup")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").GPUBindGroup.State) } else .other)}, .nullable = true }, .{ .kinds = &.{.{ .typed_array = "Uint32Array" }} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
    } },
};
