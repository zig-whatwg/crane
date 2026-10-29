//! CSS Shapes 1 §6.1: shape-outside's boxes around the shared shape/image grammars.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const shapes = @import("shape_values.zig");
const components = @import("shape_components.zig");

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) std.mem.Allocator.Error!?values.Value {
    if (components.keyword(stream, "none")) return values.Value.kw(.none);

    var image_stream = stream.*;
    if (try @import("image_values.zig").parse(options, &image_stream, .{})) |image| {
        stream.* = image_stream;
        return image;
    }

    var box = consumeBox(stream);
    var shape_stream = stream.*;
    if (try shapes.consumeBasicShape(options, &shape_stream)) |shape| {
        stream.* = shape_stream;
        if (box == null) box = consumeBox(stream);
        shape.box = box;
        return .{ .shape = shape };
    }

    // A failed function trial must leave its tokens for the caller's
    // end-of-value check, including after a valid leading shape box.
    if (box == null) return null;
    const shape = try options.allocator.create(shapes.Shape);
    shape.* = .{ .allocator = options.allocator, .box = box, .data = .box };
    return .{ .shape = shape };
}

fn consumeBox(stream: *properties.Stream) ?shapes.GeometryBox {
    // Shapes 1 §5: SVG's fill/stroke/view boxes belong to clip-path only.
    inline for (.{ .margin_box, .border_box, .padding_box, .content_box }) |tag| {
        const box: shapes.GeometryBox = tag;
        if (components.keyword(stream, box.name())) return box;
    }
    return null;
}

/// Q40: shape-outside's resolved path uses absolute SVG coordinates, while
/// specified values and clip-path keep the shared Shape's canonical text.
pub fn serializeResolved(shape: *const shapes.Shape, out: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
    const path = shape.data.path;
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try @import("path_values.zig").serializeAbsolute(path.text.bytes, &text, allocator);
    try out.appendSlice(allocator, if (path.evenodd) "path(evenodd, " else "path(");
    try values.appendString(text.items, out, allocator);
    try out.append(allocator, ')');
    if (shape.box) |box| if (box != .margin_box) {
        try out.append(allocator, ' ');
        try out.appendSlice(allocator, box.name());
    };
}
