//! One executable for the resource-loader and font-event regression loop.
comptime {
    _ = @import("style_resource_lifetime_test.zig");
    _ = @import("style_font_load_event_test.zig");
    _ = @import("style_font_face_state_test.zig");
    _ = @import("style_font_set_state_test.zig");
}
