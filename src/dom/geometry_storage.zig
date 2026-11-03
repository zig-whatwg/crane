//! lint-impls: hook for DOMPointReadOnly, DOMRectReadOnly, DOMMatrixReadOnly
//! Geometry Interfaces: setting a point's, rectangle's or matrix's internal
//! member variables.
//!
//! Those variables belong to the read-only interface - "DOMPointReadOnly as
//! well as the inheriting interface DOMPoint must be able to access and set
//! the value of these variables" (Geometry 2; 3 and 6 say the same of
//! rectangles and matrices). The read-only interface keeps them; everyone
//! else reads them through its IDL members (interfaces.DOMPointReadOnly.get_x)
//! and sets them here, since the read-only interface has no IDL member that
//! writes them: the mutable interface's setters and constructor (DOMPoint,
//! DOMRect, DOMMatrix), and whoever makes one with given values (a DOMQuad's
//! points, a deserialized object). Each owner installs its step once, at
//! process start, from its installHooks.
//!
//! Spec: https://drafts.fxtf.org/geometry/

const runtime = @import("runtime");
const geometry = @import("css").geometry;
const Hook = @import("hook.zig").Hook;

pub const Point = geometry.Point;
pub const Rect = geometry.Rect;
pub const Matrix = geometry.Matrix;

/// Set `point`'s (a DOMPointReadOnly or a DOMPoint) x coordinate, y
/// coordinate, z coordinate and w perspective.
pub const SetPoint = *const fn (point: *runtime.Instance, value: Point) void;
/// Set `rect`'s (a DOMRectReadOnly or a DOMRect) x coordinate, y coordinate,
/// width dimension and height dimension.
pub const SetRect = *const fn (rect: *runtime.Instance, value: Rect) void;
/// Set `matrix`'s (a DOMMatrixReadOnly or a DOMMatrix) m11 to m44 elements
/// and is 2D.
pub const SetMatrix = *const fn (matrix: *runtime.Instance, value: Matrix) void;

// process-wide: hook written once at process start by DOMPointReadOnly.installHooks (B0); comptime in B9
var set_point: Hook(?SetPoint) = .init(null);
// process-wide: hook written once at process start by DOMRectReadOnly.installHooks (B0); comptime in B9
var set_rect: Hook(?SetRect) = .init(null);
// process-wide: hook written once at process start by DOMMatrixReadOnly.installHooks (B0); comptime in B9
var set_matrix: Hook(?SetMatrix) = .init(null);

pub fn installPoint(step: SetPoint) void {
    set_point.install(step);
}

pub fn installRect(step: SetRect) void {
    set_rect.install(step);
}

pub fn installMatrix(step: SetMatrix) void {
    set_matrix.install(step);
}

pub fn setPoint(point: *runtime.Instance, value: Point) error{NotSupportedError}!void {
    (set_point.get() orelse return error.NotSupportedError)(point, value);
}

pub fn setRect(rect: *runtime.Instance, value: Rect) error{NotSupportedError}!void {
    (set_rect.get() orelse return error.NotSupportedError)(rect, value);
}

pub fn setMatrix(matrix: *runtime.Instance, value: Matrix) error{NotSupportedError}!void {
    (set_matrix.get() orelse return error.NotSupportedError)(matrix, value);
}
