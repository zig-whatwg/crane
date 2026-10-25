//! CSS Fonts4 §1.2: font-affecting values use the parent's font metrics.
const properties = @import("properties.zig");

/// Q45: all supported font shorthand longhands except the two explicit
/// exclusions. The default is ordinary element-relative length resolution.
pub fn isFontAffecting(longhand: properties.Longhand) bool {
    return switch (longhand) {
        .font_family, .font_size, .font_style, .font_weight, .font_width, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_variant_alternates, .font_variant_caps, .font_variant_east_asian, .font_variant_ligatures, .font_variant_numeric, .font_variant_position, .font_variation_settings => true,
        // line-height has its own existing rule; emoji is not font-affecting.
        else => false,
    };
}
