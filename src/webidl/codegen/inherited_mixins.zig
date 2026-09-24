//! The interface mixins whose members their includers inherit.
//!
//! WebIDL `includes` makes a mixin's members the including interface's own:
//! each is on the includer's prototype, guarded by the includer's brand
//! check, and runs with the includer's instance as `this`. So an includer's
//! generated interface lists them in its own tables and inherits their
//! functions from the mixin's generated module -
//! `pub const get_onclick = mixins.GlobalEventHandlers.get_onclick;` - and the
//! member is implemented once, in the mixin's impl. Nothing calls a mixin on
//! its own, and an includer's impl never implements (or overrides) one of its
//! members: WebIDL does not let an interface redeclare a member it includes.
//!
//! Transitional. A mixin moves onto this list in the commit that moves its
//! implementation out of its includers' impls and into its own. The mixins
//! not listed yet still have each includer's generated delegates call the
//! includer's impl. When every mixin is here the list goes, and inheritance is
//! simply what `includes` generates.

const std = @import("std");

pub const names = [_][]const u8{
    "BluetoothDeviceEventHandlers",
    "CanvasCompositing",
    "CanvasDrawImage",
    "CanvasDrawPath",
    "CanvasFilters",
    "CanvasImageData",
    "CanvasImageSmoothing",
    "CanvasRect",
    "CanvasSettings",
    "CanvasShadowStyles",
    "CanvasState",
    "CanvasText",
    "CanvasTextDrawingStyles",
    "CanvasTransform",
    "CanvasUserInterface",
    "CharacteristicEventHandlers",
    "ChildNode",
    "CredentialUserData",
    "DestroyableModel",
    "GPUBindingCommandsMixin",
    "GPUDebugCommandsMixin",
    "GPUObjectBase",
    "GPUPipelineBase",
    "GPURenderCommandsMixin",
    "GlobalEventHandlers",
    "GlobalPrivacyControl",
    "HTMLHyperlinkElementUtils",
    "NavigatorAutomationInformation",
    "NavigatorBadge",
    "NavigatorContentUtils",
    "NavigatorDeviceMemory",
    "NavigatorGPU",
    "NavigatorLocks",
    "NavigatorML",
    "NavigatorNetworkInformation",
    "NavigatorPlugins",
    "NavigatorStorageBuckets",
    "NavigatorUA",
    "NetworkInformationSaveData",
    "NonDocumentTypeChildNode",
    "NonElementParentNode",
    "ParentNode",
    "PushManagerAttribute",
    "SFrameKeyManagement",
    "SVGAnimatedPoints",
    "SVGFilterPrimitiveStandardAttributes",
    "SVGFitToViewBox",
    "SVGPathData",
    "SVGTests",
    "SVGURIReference",
    "ServiceEventHandlers",
    "WindowEventHandlers",
    "XRViewGeometry",
};

pub fn isInherited(name: []const u8) bool {
    for (names) |inherited| {
        if (std.mem.eql(u8, inherited, name)) return true;
    }
    return false;
}

test "a listed mixin is inherited, any other is not yet" {
    for (names) |name| try std.testing.expect(isInherited(name));
    try std.testing.expect(!isInherited("NotAMixin"));
    try std.testing.expect(!isInherited(""));
}
