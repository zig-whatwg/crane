//! HTML Image Button state: the submitter's selected coordinate.
const runtime = @import("runtime");

/// The image submitter's selected coordinate in CSS pixels.
pub const Coordinate = struct { x: u32, y: u32 };

/// Synthetic activation currently selects the default origin. Form entries
/// and method=dialog both read this source; host hit coordinates belong here
/// when the image-input activation path supplies them.
pub fn selected(submitter: *runtime.Instance) Coordinate {
    _ = submitter;
    return .{ .x = 0, .y = 0 };
}
