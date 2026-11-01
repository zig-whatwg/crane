//! Images4 §5.1: object-fit's independent optional scale-down flag.
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const keyword = @import("shape_components.zig").keyword;
const tokenizer = @import("tokenizer.zig");
const shapes = @import("shape_values.zig");
const Allocator = @import("std").mem.Allocator;

pub fn consumeFit(stream: *properties.Stream) ?values.Value {
    if (keyword(stream, "fill")) return values.Value.kw(.fill);
    if (keyword(stream, "none")) return values.Value.kw(.none);
    var fit: ?values.Keyword = null;
    var scale_down = false;
    for (0..2) |_| {
        if (fit == null) {
            if (keyword(stream, "contain")) {
                fit = .contain;
                continue;
            }
            if (keyword(stream, "cover")) {
                fit = .cover;
                continue;
            }
        }
        if (!scale_down and keyword(stream, "scale-down")) {
            scale_down = true;
            continue;
        }
        break;
    }
    if (fit == null and !scale_down) return null;
    // Q10: the Level4 combinations are newer spec/WPT behavior; all three
    // stable browsers pass 5/9 valid cases and have not shipped the extension.
    // §5.1 makes contain scale-down equivalent to the shorter scale-down.
    if (scale_down) return if (fit == .cover)
        .{ .box_keywords = .{ .first = .cover, .second = .scale_down } }
    else
        values.Value.kw(.scale_down);
    return values.Value.kw(fit.?);
}

/// Images5 §3.1: the rectangular shape's natural-size reference box is a
/// used-value input; specified and computed storage retain the shared Shape.
pub fn consumeViewBox(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?values.Value {
    if (keyword(stream, "none")) return values.Value.kw(.none);
    const token = stream.peek();
    if (token.token_type != .function) return null;
    if (!tokenizer.nameEql(token.value, "inset") and
        !tokenizer.nameEql(token.value, "rect") and
        !tokenizer.nameEql(token.value, "xywh")) return null;
    return .{ .shape = try shapes.consumeBasicShape(options, stream) orelse return null };
}
