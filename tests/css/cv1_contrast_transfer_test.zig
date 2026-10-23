//! Q94: CSS curves; Rec2020 deliberately differs from all three browsers
//! (CSSWG #12574, Mozilla 1987176, pinned Color4 WPT). A98 follows
//! Firefox/Safari over Chrome; ProPhoto follows their linear toe.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
fn check(text: []const u8, expected: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "color", text, "");
    try testing.expectEqual(@as(usize, 1), block.entries.items.len);
    const color = block.entries.items[0].typed.value.value.color;
    const computed = try color.resolveComputed(testing.allocator, .{});
    defer computed.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try computed.serializeComputed(&out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "contrast CSS transfer contrast-color(color(rec2020 0.38 0.38 0.38))" {
    try check("contrast-color(color(rec2020 0.38 0.38 0.38))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(rec2020 0.41 0.41 0.41))" {
    try check("contrast-color(color(rec2020 0.41 0.41 0.41))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(rec2020 0.42 0.42 0.42))" {
    try check("contrast-color(color(rec2020 0.42 0.42 0.42))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(rec2020 0.43 0.43 0.43))" {
    try check("contrast-color(color(rec2020 0.43 0.43 0.43))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(rec2020 0.44 0.44 0.44))" {
    try check("contrast-color(color(rec2020 0.44 0.44 0.44))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(rec2020 0.45 0.45 0.45))" {
    try check("contrast-color(color(rec2020 0.45 0.45 0.45))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(rec2020 0.46 0.46 0.46))" {
    try check("contrast-color(color(rec2020 0.46 0.46 0.46))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(rec2020 0.47 0.47 0.47))" {
    try check("contrast-color(color(rec2020 0.47 0.47 0.47))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(rec2020 0.48 0.48 0.48))" {
    try check("contrast-color(color(rec2020 0.48 0.48 0.48))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(rec2020 0.52 0.52 0.52))" {
    try check("contrast-color(color(rec2020 0.52 0.52 0.52))", "rgb(0, 0, 0)");
}

test "contrast CSS transfer contrast-color(color(a98-rgb 0.458 0.458 0.458))" {
    try check("contrast-color(color(a98-rgb 0.458 0.458 0.458))", "rgb(0, 0, 0)");
}

test "contrast CSS transfer contrast-color(color(a98-rgb 0.45805 0.45805 0.45805))" {
    try check("contrast-color(color(a98-rgb 0.45805 0.45805 0.45805))", "rgb(0, 0, 0)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.6048 0.0055 0.4526))" {
    try check("contrast-color(color(prophoto-rgb 0.6048 0.0055 0.4526))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.0201 0.4145 0.064))" {
    try check("contrast-color(color(prophoto-rgb 0.0201 0.4145 0.064))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.6056 0.0253 0.3981))" {
    try check("contrast-color(color(prophoto-rgb 0.6056 0.0253 0.3981))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.607 0.0005 0.3898))" {
    try check("contrast-color(color(prophoto-rgb 0.607 0.0005 0.3898))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.6139 0.0202 0.0539))" {
    try check("contrast-color(color(prophoto-rgb 0.6139 0.0202 0.0539))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.5976 0.0068 0.6283))" {
    try check("contrast-color(color(prophoto-rgb 0.5976 0.0068 0.6283))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.0115 0.3793 0.554))" {
    try check("contrast-color(color(prophoto-rgb 0.0115 0.3793 0.554))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.5953 0.0211 0.6745))" {
    try check("contrast-color(color(prophoto-rgb 0.5953 0.0211 0.6745))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.0143 0.3587 0.6904))" {
    try check("contrast-color(color(prophoto-rgb 0.0143 0.3587 0.6904))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.5995 0.0039 0.5724))" {
    try check("contrast-color(color(prophoto-rgb 0.5995 0.0039 0.5724))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.6124 0.0234 0.111))" {
    try check("contrast-color(color(prophoto-rgb 0.6124 0.0234 0.111))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.599 0.0208 0.6443))" {
    try check("contrast-color(color(prophoto-rgb 0.599 0.0208 0.6443))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.3274 0.4057 0.0214))" {
    try check("contrast-color(color(prophoto-rgb 0.3274 0.4057 0.0214))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.6199 0.1246 0.0153))" {
    try check("contrast-color(color(prophoto-rgb 0.6199 0.1246 0.0153))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.611 0.0178 0.1538))" {
    try check("contrast-color(color(prophoto-rgb 0.611 0.0178 0.1538))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.6111 0.0086 0.2151))" {
    try check("contrast-color(color(prophoto-rgb 0.6111 0.0086 0.2151))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.6114 0.0136 0.0889))" {
    try check("contrast-color(color(prophoto-rgb 0.6114 0.0136 0.0889))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.0195 0.4074 0.2188))" {
    try check("contrast-color(color(prophoto-rgb 0.0195 0.4074 0.2188))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.5961 0.0145 0.6574))" {
    try check("contrast-color(color(prophoto-rgb 0.5961 0.0145 0.6574))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.6071 0.017 0.4175))" {
    try check("contrast-color(color(prophoto-rgb 0.6071 0.017 0.4175))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.01 0.3654 0.6332))" {
    try check("contrast-color(color(prophoto-rgb 0.01 0.3654 0.6332))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.0261 0.3935 0.4284))" {
    try check("contrast-color(color(prophoto-rgb 0.0261 0.3935 0.4284))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.6036 0.0168 0.4807))" {
    try check("contrast-color(color(prophoto-rgb 0.6036 0.0168 0.4807))", "rgb(255, 255, 255)");
}

test "contrast CSS transfer contrast-color(color(prophoto-rgb 0.6105 0.0181 0.2495))" {
    try check("contrast-color(color(prophoto-rgb 0.6105 0.0181 0.2495))", "rgb(255, 255, 255)");
}
