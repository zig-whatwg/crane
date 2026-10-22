//! Focused lane entry point; the directory-wide suite also imports these
//! same files, which Zig includes once in either composition.
test {
    _ = @import("xm1_xml_byte_errors_test.zig");
    _ = @import("xm1_contextual_fragment_test.zig");
    _ = @import("xm1_svg_interfaces_test.zig");
    _ = @import("xm1_svg_style_rect_test.zig");
    _ = @import("xm1_xml_script_loader_test.zig");
    _ = @import("xm1_cdata_validation_test.zig");
    _ = @import("xm1_pi_stylesheet_test.zig");
}
