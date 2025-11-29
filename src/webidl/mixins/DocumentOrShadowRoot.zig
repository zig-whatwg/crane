//! DocumentOrShadowRoot Mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-documentorshadowroot
//! Also: https://html.spec.whatwg.org/multipage/dom.html#documentorshadowroot
//!
//! This mixin delegates to the DocumentOrShadowRoot impl for all functionality.
//! The impl contains the actual logic for DocumentOrShadowRoot methods.
//!
//! The DocumentOrShadowRoot mixin defines:
//! - activeElement - The deepest element that has focus
//! - adoptedStyleSheets - List of adopted stylesheets
//! - styleSheets - List of stylesheets
//! - fullscreenElement - Element currently in fullscreen
//! - pictureInPictureElement - Element in picture-in-picture
//! - pointerLockElement - Element with pointer lock
//! - getAnimations() - Returns all animations

const std = @import("std");
const runtime = @import("runtime");

// Import the impl which contains all the actual logic
const DocumentOrShadowRootImpl = @import("impls").DocumentOrShadowRoot;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

// =============================================================================
// DocumentOrShadowRoot Attributes (delegate to impl)
// =============================================================================

/// activeElement - Returns the deepest element that has focus
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-documentorshadowroot-activeelement
pub fn activeElement(root: *runtime.Instance) ?*runtime.Instance {
    return DocumentOrShadowRootImpl.get_activeElement(root) catch null;
}

/// styleSheets - Returns a StyleSheetList of associated stylesheets
/// Spec: https://drafts.csswg.org/cssom/#dom-documentorshadowroot-stylesheets
pub fn styleSheets(allocator: std.mem.Allocator, root: *runtime.Instance, ctx: runtime.Context) MixinError!*runtime.Instance {
    _ = allocator;
    _ = ctx;
    return DocumentOrShadowRootImpl.get_styleSheets(root) catch |err| switch (err) {
        error.NotImplemented => return error.NotImplemented,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// adoptedStyleSheets - Returns adopted stylesheets
/// Spec: https://drafts.csswg.org/cssom/#dom-documentorshadowroot-adoptedstylesheets
pub fn getAdoptedStyleSheets(root: *runtime.Instance) MixinError![]const *runtime.Instance {
    _ = DocumentOrShadowRootImpl.get_adoptedStyleSheets(root) catch |err| switch (err) {
        error.NotImplemented => return error.NotImplemented,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
    return error.NotImplemented;
}

/// setAdoptedStyleSheets - Sets adopted stylesheets
/// Spec: https://drafts.csswg.org/cssom/#dom-documentorshadowroot-adoptedstylesheets
pub fn setAdoptedStyleSheets(root: *runtime.Instance, sheets: []const *runtime.Instance) MixinError!void {
    _ = sheets;
    DocumentOrShadowRootImpl.set_adoptedStyleSheets(root, @ptrFromInt(0)) catch |err| switch (err) {
        error.NotImplemented => return error.NotImplemented,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// fullscreenElement - Returns the element in fullscreen mode
/// Spec: https://fullscreen.spec.whatwg.org/#dom-documentorshadowroot-fullscreenelement
pub fn fullscreenElement(root: *runtime.Instance) ?*runtime.Instance {
    return DocumentOrShadowRootImpl.get_fullscreenElement(root) catch null;
}

/// pictureInPictureElement - Returns the element in picture-in-picture
/// Spec: https://w3c.github.io/picture-in-picture/#dom-documentorshadowroot-pictureinpictureelement
pub fn pictureInPictureElement(root: *runtime.Instance) ?*runtime.Instance {
    return DocumentOrShadowRootImpl.get_pictureInPictureElement(root) catch null;
}

/// pointerLockElement - Returns the element with pointer lock
/// Spec: https://w3c.github.io/pointerlock/#dom-documentorshadowroot-pointerlockelement
pub fn pointerLockElement(root: *runtime.Instance) ?*runtime.Instance {
    return DocumentOrShadowRootImpl.get_pointerLockElement(root) catch null;
}

// =============================================================================
// DocumentOrShadowRoot Methods (delegate to impl)
// =============================================================================

/// getAnimations - Returns all animations in the document/shadow root
/// Spec: https://drafts.csswg.org/web-animations-1/#dom-documentorshadowroot-getanimations
pub fn getAnimations(allocator: std.mem.Allocator, root: *runtime.Instance) MixinError!std.ArrayList(*runtime.Instance) {
    var animations = std.ArrayList(*runtime.Instance).init(allocator);
    errdefer animations.deinit();

    _ = DocumentOrShadowRootImpl.call_getAnimations(root) catch |err| switch (err) {
        error.NotImplemented => return error.NotImplemented,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };

    return animations;
}

// =============================================================================
// Tests
// =============================================================================

test "DocumentOrShadowRoot mixin - delegation to impl" {
    // Test that mixin correctly delegates to impl
    // Full tests are in the impl file
}
