//! CSS Color 4 §§7–11, 13–14: floating-point conversion and interpolation.
//! Components keep their color space and missingness until a destination
//! explicitly requests bytes. Matrix coefficients are the §19 colorimetry.
const std = @import("std");
const tokens = @import("tokenizer.zig");

pub const Space = enum {
    srgb,
    srgb_linear,
    display_p3,
    display_p3_linear,
    a98_rgb,
    prophoto_rgb,
    rec2020,
    xyz_d50,
    xyz_d65,
    lab,
    lch,
    oklab,
    oklch,
    hsl,
    hwb,

    pub fn name(self: Space) []const u8 {
        return switch (self) {
            .srgb_linear => "srgb-linear",
            .display_p3 => "display-p3",
            .display_p3_linear => "display-p3-linear",
            .a98_rgb => "a98-rgb",
            .prophoto_rgb => "prophoto-rgb",
            .xyz_d50 => "xyz-d50",
            .xyz_d65 => "xyz-d65",
            else => @tagName(self),
        };
    }
    pub fn parse(text: []const u8) ?Space {
        if (tokens.nameEql(text, "xyz")) return .xyz_d65;
        inline for (@typeInfo(Space).@"enum".field_values) |field_value| {
            const space: Space = @enumFromInt(field_value);
            if (tokens.nameEql(text, space.name())) return space;
        }
        return null;
    }
    pub fn predefined(self: Space) bool {
        return @intFromEnum(self) <= @intFromEnum(Space.xyz_d65);
    }
    pub fn hue(self: Space) ?usize {
        return switch (self) {
            .hsl, .hwb => 0,
            .lch, .oklch => 2,
            else => null,
        };
    }
    fn categories(self: Space) [3]Category {
        return switch (self) {
            .lab, .oklab => .{ .lightness, .opponent_a, .opponent_b },
            .lch, .oklch => .{ .lightness, .colorfulness, .hue },
            .hsl => .{ .hue, .colorfulness, .lightness },
            .hwb => .{ .hue, .white, .black },
            else => .{ .red, .green, .blue },
        };
    }
};
const Category = enum { red, green, blue, lightness, colorfulness, hue, opponent_a, opponent_b, white, black };
pub const HueMethod = enum { shorter, longer, increasing, decreasing };

pub const Components = struct {
    space: Space,
    channels: [3]f64,
    alpha: f64 = 1,
    /// Bits 0–2 are channels; bit 3 is alpha. Missing is distinct from zero.
    missing: u4 = 0,

    pub fn absent(self: Components, index: usize) bool {
        return self.missing & (@as(u4, 1) << @intCast(index)) != 0;
    }
    pub fn setMissing(self: *Components, index: usize) void {
        self.missing |= @as(u4, 1) << @intCast(index);
    }
    pub fn channel(self: Components, index: usize) f64 {
        if (self.absent(index)) return 0;
        return if (index == 3) self.alpha else self.channels[index];
    }
    pub fn eql(a: Components, b: Components) bool {
        if (a.space != b.space or a.missing != b.missing) return false;
        for (0..4) |index| if (a.channel(index) != b.channel(index)) return false;
        return true;
    }

    /// §§11.2, 13.3 steps 1–4: carry individual analogs and entire residual
    /// analogous sets. Find the original missing set before powerless fixup.
    pub fn convert(self: Components, destination: Space) Components {
        if (self.space == destination) return self;
        const carry = missingAfterConversion(self, destination);
        var prepared = self;
        prepared.powerless();
        var input = prepared.channels;
        for (&input, 0..) |*v, i| if (prepared.absent(i)) {
            v.* = 0;
        };
        var result = Components{
            .space = destination,
            .channels = convertChannels(self.space, destination, input),
            .alpha = self.alpha,
        };
        // §13.3 steps 2–4: detect powerless converted components before
        // reinserting the original analogous missing components.
        result.powerless();
        result.missing |= carry;
        return result;
    }

    /// §4.4.1: only converted colors turn powerless hue into missing.
    /// Authored hue in a same-space calculation remains as authored.
    fn powerless(self: *Components) void {
        const hue_index = self.space.hue() orelse return;
        const epsilon: f64 = switch (self.space) {
            .hsl => 0.001,
            .lch => 0.0015,
            .oklch => 0.000004,
            .hwb => {
                const sum = self.channel(1) + self.channel(2);
                if (sum < 99.999) return;
                if (sum < 100) {
                    if (!self.absent(1) and !self.absent(2)) {
                        self.channels[2] = 100 - self.channels[1];
                    } else if (!self.absent(1)) {
                        self.channels[1] = 100;
                    } else if (!self.absent(2)) {
                        self.channels[2] = 100;
                    }
                }
                self.setMissing(0);
                return;
            },
            else => unreachable,
        };
        const colorfulness = self.channel(1);
        if (colorfulness > epsilon) return;
        if (colorfulness > 0) self.channels[1] = 0;
        self.setMissing(hue_index);
    }
};

fn missingAfterConversion(source: Components, destination: Space) u4 {
    var result: u4 = source.missing & 8;
    var remaining_source: u4 = 7;
    var remaining_destination: u4 = 7;
    for (source.space.categories(), 0..) |category, index| {
        for (destination.categories(), 0..) |other, output| {
            if (category != other) continue;
            const a = @as(u4, 1) << @intCast(index);
            const b = @as(u4, 1) << @intCast(output);
            remaining_source &= ~a;
            remaining_destination &= ~b;
            if (source.absent(index)) result |= b;
        }
    }
    if (remaining_source != 0 and source.missing & remaining_source == remaining_source)
        result |= remaining_destination;
    return result;
}

/// §13 steps 1–9. The caller normalizes its two quantities to sum to one.
pub fn interpolate(left: Components, right: Components, destination: Space, hue: HueMethod, right_weight: f64) Components {
    const a = left.convert(destination);
    const b = right.convert(destination);
    var first: [4]f64 = undefined;
    var second: [4]f64 = undefined;
    for (0..4) |i| {
        first[i] = if (a.absent(i)) b.channel(i) else a.channel(i);
        second[i] = if (b.absent(i)) a.channel(i) else b.channel(i);
    }
    const missing = a.missing & b.missing;
    if (destination.hue()) |index| {
        const difference = second[index] - first[index];
        switch (hue) {
            .shorter => if (difference > 180) {
                first[index] += 360;
            } else if (difference < -180) {
                second[index] += 360;
            },
            .longer => if (difference > 0 and difference < 180) {
                first[index] += 360;
            } else if (difference > -180 and difference <= 0) {
                second[index] += 360;
            },
            .increasing => if (second[index] < first[index]) {
                second[index] += 360;
            },
            .decreasing => if (first[index] < second[index]) {
                first[index] += 360;
            },
        }
    }
    const alpha = first[3] * (1 - right_weight) + second[3] * right_weight;
    var result = Components{ .space = destination, .channels = undefined, .alpha = alpha, .missing = missing };
    for (&result.channels, 0..) |*value, i| {
        const premultiply = destination.hue() != i and missing & 8 == 0;
        const x = first[i] * (if (premultiply) first[3] else 1);
        const y = second[i] * (if (premultiply) second[3] else 1);
        value.* = x * (1 - right_weight) + y * right_weight;
        if (premultiply and alpha != 0) value.* /= alpha;
    }
    if (destination.hue()) |index| result.channels[index] = normalizeHue(result.channels[index]);
    return result;
}

pub fn normalizeHue(value: f64) f64 {
    return if (std.math.isFinite(value)) @mod(value, 360) else 0;
}
fn signedPow(value: f64, exponent: f64) f64 {
    return std.math.copysign(std.math.pow(f64, @abs(value), exponent), value);
}
const Matrix = [3][3]f64;
const srgb_xyz: Matrix = .{
    .{ 506752.0 / 1228815.0, 87881.0 / 245763.0, 12673.0 / 70218.0 },
    .{ 87098.0 / 409605.0, 175762.0 / 245763.0, 12673.0 / 175545.0 },
    .{ 7918.0 / 409605.0, 87881.0 / 737289.0, 1001167.0 / 1053270.0 },
};
const p3_xyz: Matrix = .{
    .{ 608311.0 / 1250200.0, 189793.0 / 714400.0, 198249.0 / 1000160.0 },
    .{ 35783.0 / 156275.0, 247089.0 / 357200.0, 198249.0 / 2500400.0 },
    .{ 0, 32229.0 / 714400.0, 5220557.0 / 5000800.0 },
};
const a98_xyz: Matrix = .{
    .{ 573536.0 / 994567.0, 263643.0 / 1420810.0, 187206.0 / 994567.0 },
    .{ 591459.0 / 1989134.0, 6239551.0 / 9945670.0, 374412.0 / 4972835.0 },
    .{ 53769.0 / 1989134.0, 351524.0 / 4972835.0, 4929758.0 / 4972835.0 },
};
const prophoto_xyz: Matrix = .{
    .{ 0.79776664490064230, 0.13518129740053308, 0.03134773412839220 },
    .{ 0.28807482881940130, 0.71183523424187300, 0.00008993693872564 },
    .{ 0, 0, 0.82510460251046020 },
};
const rec2020_xyz: Matrix = .{
    .{ 63426534.0 / 99577255.0, 20160776.0 / 139408157.0, 47086771.0 / 278816314.0 },
    .{ 26158966.0 / 99577255.0, 472592308.0 / 697040785.0, 8267143.0 / 139408157.0 },
    .{ 0, 19567812.0 / 697040785.0, 295819943.0 / 278816314.0 },
};
const d50_d65: Matrix = .{
    .{ 0.955473421488075, -0.02309845494876471, 0.06325924320057072 },
    .{ -0.0283697093338637, 1.0099953980813041, 0.021041441191917323 },
    .{ 0.012314014864481998, -0.020507649298898964, 1.330365926242124 },
};
const lms_xyz: Matrix = .{
    .{ 1.2268798758459243, -0.5578149944602171, 0.2813910456659647 },
    .{ -0.0405757452148008, 1.1122868032803170, -0.0717110580655164 },
    .{ -0.0763729366746601, -0.4214933324022432, 1.5869240198367816 },
};
const oklab_lms: Matrix = .{
    .{ 1, 0.3963377773761749, 0.2158037573099136 },
    .{ 1, -0.1055613458156586, -0.0638541728258133 },
    .{ 1, -0.0894841775298119, -1.2914855480194092 },
};

fn multiply(matrix: Matrix, vector: [3]f64) [3]f64 {
    var result: [3]f64 = undefined;
    for (matrix, &result) |row, *out| out.* = row[0] * vector[0] + row[1] * vector[1] + row[2] * vector[2];
    return result;
}
fn inverse(comptime m: Matrix) Matrix {
    const a = m[0][0];
    const b = m[0][1];
    const c = m[0][2];
    const d = m[1][0];
    const e = m[1][1];
    const f = m[1][2];
    const g = m[2][0];
    const h = m[2][1];
    const i = m[2][2];
    const determinant = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    return .{
        .{ (e * i - f * h) / determinant, (c * h - b * i) / determinant, (b * f - c * e) / determinant },
        .{ (f * g - d * i) / determinant, (a * i - c * g) / determinant, (c * d - a * f) / determinant },
        .{ (d * h - e * g) / determinant, (b * g - a * h) / determinant, (a * e - b * d) / determinant },
    };
}
fn linearSrgb(value: f64) f64 {
    return if (@abs(value) <= 0.04045) value / 12.92 else std.math.copysign(std.math.pow(f64, (@abs(value) + 0.055) / 1.055, 2.4), value);
}
fn encodedSrgb(value: f64) f64 {
    return if (@abs(value) <= 0.0031308) value * 12.92 else std.math.copysign(1.055 * std.math.pow(f64, @abs(value), 1.0 / 2.4) - 0.055, value);
}
fn transfer(space: Space, value: f64, encode: bool) f64 {
    return switch (space) {
        .srgb, .display_p3 => if (encode) encodedSrgb(value) else linearSrgb(value),
        .a98_rgb => signedPow(value, if (encode) 256.0 / 563.0 else 563.0 / 256.0),
        .prophoto_rgb => if (encode)
            (if (@abs(value) <= 1.0 / 512.0) value * 16 else signedPow(value, 1.0 / 1.8))
        else
            (if (@abs(value) <= 16.0 / 512.0) value / 16 else signedPow(value, 1.8)),
        // Color 4 §10.8 / CSSWG #12574: display-referred signed gamma 2.4.
        .rec2020 => signedPow(value, if (encode) 1.0 / 2.4 else 2.4),
        .srgb_linear, .display_p3_linear => value,
        else => unreachable,
    };
}

pub fn convertChannels(source: Space, destination: Space, channels: [3]f64) [3]f64 {
    if (source == destination) return channels;
    // §§7.1, 7.2, 8.1, 8.2: HSL and HWB are coordinates of sRGB itself.
    // Their direct algorithms preserve achromatic values and exact halves;
    // an unnecessary XYZ round trip introduces color and rounding noise.
    if ((source == .srgb or source == .hsl or source == .hwb) and
        (destination == .srgb or destination == .hsl or destination == .hwb))
    {
        const rgb = switch (source) {
            .hsl => hslToRgb(channels),
            .hwb => hwbToRgb(channels),
            else => channels,
        };
        return switch (destination) {
            .hsl => rgbToHsl(rgb),
            .hwb => rgbToHwb(rgb),
            else => rgb,
        };
    }
    return fromXyz(destination, toXyz(source, channels));
}
fn toXyz(space: Space, channels: [3]f64) [3]f64 {
    switch (space) {
        .xyz_d65 => return channels,
        .xyz_d50 => return multiply(d50_d65, channels),
        .lab => return multiply(d50_d65, labToXyz(channels)),
        .lch => return toXyz(.lab, polarToRect(channels)),
        .oklch => return toXyz(.oklab, polarToRect(channels)),
        .oklab => {
            var lms = multiply(oklab_lms, channels);
            for (&lms) |*value| value.* = value.* * value.* * value.*;
            return multiply(lms_xyz, lms);
        },
        .hsl => return toXyz(.srgb, hslToRgb(channels)),
        .hwb => return toXyz(.srgb, hwbToRgb(channels)),
        else => {},
    }
    var linear = channels;
    for (&linear) |*value| value.* = transfer(space, value.*, false);
    const xyz = multiply(switch (space) {
        .srgb, .srgb_linear => srgb_xyz,
        .display_p3, .display_p3_linear => p3_xyz,
        .a98_rgb => a98_xyz,
        .rec2020 => rec2020_xyz,
        .prophoto_rgb => prophoto_xyz,
        else => unreachable,
    }, linear);
    return if (space == .prophoto_rgb) multiply(d50_d65, xyz) else xyz;
}
fn fromXyz(space: Space, xyz: [3]f64) [3]f64 {
    switch (space) {
        .xyz_d65 => return xyz,
        .xyz_d50 => return multiply(comptime inverse(d50_d65), xyz),
        .lab => return xyzToLab(multiply(comptime inverse(d50_d65), xyz)),
        .lch => return rectToPolar(fromXyz(.lab, xyz)),
        .oklch => return rectToPolar(fromXyz(.oklab, xyz)),
        .oklab => {
            var lms = multiply(comptime inverse(lms_xyz), xyz);
            for (&lms) |*value| value.* = std.math.cbrt(value.*);
            return multiply(comptime inverse(oklab_lms), lms);
        },
        .hsl => return rgbToHsl(fromXyz(.srgb, xyz)),
        .hwb => return rgbToHwb(fromXyz(.srgb, xyz)),
        else => {},
    }
    var result = multiply(switch (space) {
        .srgb, .srgb_linear => comptime inverse(srgb_xyz),
        .display_p3, .display_p3_linear => comptime inverse(p3_xyz),
        .a98_rgb => comptime inverse(a98_xyz),
        .rec2020 => comptime inverse(rec2020_xyz),
        .prophoto_rgb => comptime inverse(prophoto_xyz),
        else => unreachable,
    }, if (space == .prophoto_rgb) multiply(comptime inverse(d50_d65), xyz) else xyz);
    for (&result) |*value| value.* = transfer(space, value.*, true);
    return result;
}
fn polarToRect(polar: [3]f64) [3]f64 {
    const radians = normalizeHue(polar[2]) * std.math.pi / 180;
    return .{ polar[0], polar[1] * @cos(radians), polar[1] * @sin(radians) };
}
fn rectToPolar(rect: [3]f64) [3]f64 {
    return .{ rect[0], @sqrt(rect[1] * rect[1] + rect[2] * rect[2]), normalizeHue(std.math.atan2(rect[2], rect[1]) * 180 / std.math.pi) };
}
const white50: [3]f64 = .{ 0.3457 / 0.3585, 1, (1.0 - 0.3457 - 0.3585) / 0.3585 };
fn labToXyz(lab: [3]f64) [3]f64 {
    const kappa = 24389.0 / 27.0;
    const epsilon = 216.0 / 24389.0;
    const y = (lab[0] + 16) / 116;
    var xyz = [3]f64{ y + lab[1] / 500, y, y - lab[2] / 200 };
    for (&xyz, white50) |*value, white| {
        const cube = value.* * value.* * value.*;
        value.* = white * (if (cube > epsilon) cube else (116 * value.* - 16) / kappa);
    }
    return xyz;
}
fn xyzToLab(xyz: [3]f64) [3]f64 {
    const kappa = 24389.0 / 27.0;
    const epsilon = 216.0 / 24389.0;
    var f = xyz;
    for (&f, white50) |*value, white| {
        const n = value.* / white;
        value.* = if (n > epsilon) std.math.cbrt(n) else (kappa * n + 16) / 116;
    }
    return .{ 116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2]) };
}
fn hslToRgb(hsl: [3]f64) [3]f64 {
    const hue = normalizeHue(hsl[0]) / 30;
    const light = hsl[2] / 100;
    const a = hsl[1] / 100 * @min(light, 1 - light);
    var rgb: [3]f64 = undefined;
    for ([_]f64{ 0, 8, 4 }, &rgb) |offset, *value| {
        const k = @mod(offset + hue, 12);
        value.* = light - a * @max(-1, @min(@min(k - 3, 9 - k), 1));
    }
    return rgb;
}
fn rgbHue(rgb: [3]f64) f64 {
    const high = @max(rgb[0], @max(rgb[1], rgb[2]));
    const low = @min(rgb[0], @min(rgb[1], rgb[2]));
    const d = high - low;
    if (d == 0) return 0;
    const sector = if (high == rgb[0]) (rgb[1] - rgb[2]) / d else if (high == rgb[1]) (rgb[2] - rgb[0]) / d + 2 else (rgb[0] - rgb[1]) / d + 4;
    return normalizeHue(sector * 60);
}
fn rgbToHsl(rgb: [3]f64) [3]f64 {
    const high = @max(rgb[0], @max(rgb[1], rgb[2]));
    const low = @min(rgb[0], @min(rgb[1], rgb[2]));
    const light = (high + low) / 2;
    var saturation = if (high == low or light == 0 or light == 1) 0 else (high - light) / @min(light, 1 - light);
    var hue = rgbHue(rgb);
    if (saturation < 0) {
        saturation = -saturation;
        hue = normalizeHue(hue + 180);
    }
    return .{ hue, saturation * 100, light * 100 };
}
fn hwbToRgb(hwb: [3]f64) [3]f64 {
    const white = hwb[1] / 100;
    const black = hwb[2] / 100;
    if (white + black >= 1) return @splat(white / (white + black));
    var rgb = hslToRgb(.{ hwb[0], 100, 50 });
    // §8.1's white + component * (1 - white - black), expressed as
    // interpolation between white and 1 - black to preserve both endpoints.
    for (&rgb) |*value| value.* = (1 - black) * value.* + white * (1 - value.*);
    return rgb;
}
fn rgbToHwb(rgb: [3]f64) [3]f64 {
    return .{ rgbHue(rgb), @reduce(.Min, @as(@Vector(3, f64), rgb)) * 100, (1 - @reduce(.Max, @as(@Vector(3, f64), rgb))) * 100 };
}

fn inSrgb(rgb: [3]f64) bool {
    for (rgb) |value| if (value < 0 or value > 1 or std.math.isNan(value)) return false;
    return true;
}
fn clipped(rgb: [3]f64) [3]f64 {
    var result = rgb;
    for (&result) |*value| value.* = if (std.math.isNan(value.*)) 0 else std.math.clamp(value.*, 0, 1);
    return result;
}
fn deltaOk(first: [3]f64, second: [3]f64) f64 {
    var sum: f64 = 0;
    for (first, second) |a, b| sum += (a - b) * (a - b);
    return @sqrt(sum);
}
/// §14.2.2's complete binary local-MINDE algorithm, for a physical sRGB
/// destination. CSS value conversion itself never calls this mapping.
pub fn gamutMapSrgb(origin: Components) [3]f64 {
    var rgb = origin.convert(.srgb);
    for (&rgb.channels, 0..) |*value, i| if (rgb.absent(i)) {
        value.* = 0;
    };
    if (inSrgb(rgb.channels)) return rgb.channels;
    var current = origin.convert(.oklch);
    for (&current.channels, 0..) |*value, i| if (current.absent(i)) {
        value.* = 0;
    };
    if (current.channels[0] >= 1) return .{ 1, 1, 1 };
    if (current.channels[0] <= 0) return .{ 0, 0, 0 };
    var result = clipped(rgb.channels);
    const jnd = 0.02;
    const epsilon = 0.0001;
    if (deltaOk(convertChannels(.srgb, .oklab, result), convertChannels(.oklch, .oklab, current.channels)) < jnd) return result;
    var low: f64 = 0;
    var high = current.channels[1];
    var low_in_gamut = true;
    while (high - low > epsilon) {
        const midpoint = low + (high - low) / 2;
        // Q91: CSS data may contain infinity. A physical adapter must
        // terminate even when overflow or rounding prevents interval progress.
        // Retain the last clipped result; never rewrite the source components.
        if (!(midpoint > low and midpoint < high)) return result;
        current.channels[1] = midpoint;
        const candidate = convertChannels(.oklch, .srgb, current.channels);
        if (low_in_gamut and inSrgb(candidate)) {
            low = current.channels[1];
            continue;
        }
        result = clipped(candidate);
        const difference = deltaOk(convertChannels(.srgb, .oklab, result), convertChannels(.oklch, .oklab, current.channels));
        if (difference < jnd) {
            if (jnd - difference < epsilon) return result;
            low_in_gamut = false;
            low = current.channels[1];
        } else high = current.channels[1];
    }
    return result;
}
// Q91: the UA contrast destination is deliberately a float32, clamped
// 8-bit pipeline, following Blink Color::ToSRGB/ToXYZD50 and gfx's color
// conversion/luminance design (integrator probes1023h/i). It is separate
// from the unbounded CSS representation and from physical gamut mapping.
// Q94 keeps CSS Color4's transfer curves: Firefox/Safari agree for A98
// and ProPhoto. Rec2020's 2.4 is newer than all three browsers: CSSWG12574,
// Chromium implementer proposal, Mozilla1987176 NEW with WIP, and pinned
// color-computed-relative-color.html840–841 establish implementation lag.
pub fn contrastChoosesBlack(color: Components) bool {
    const rgb = contrastRgb(color);
    var linear: [3]f32 = undefined;
    for (rgb, &linear) |raw, *out| {
        const finite = if (std.math.isNan(raw)) 0 else std.math.clamp(raw, 0, 1);
        const channel = @round(finite * 255) / 255;
        // WCAG2.1 relative luminance, after the observable byte boundary.
        out.* = if (channel <= 0.04045) channel / 12.92 else std.math.pow(f32, (channel + 0.055) / 1.055, 2.4);
    }
    const luminance = linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722;
    return (luminance + 0.05) / 0.05 > 1.05 / (luminance + 0.05);
}

const Matrix32 = [3][3]f32;
// ICC16.16 D50 primaries, shared with browser byte destinations.
const contrast_srgb_d50: Matrix32 = .{
    .{ @as(f32, 0x6FA2) / 65536.0, @as(f32, 0x6299) / 65536.0, @as(f32, 0x24A0) / 65536.0 },
    .{ @as(f32, 0x38F5) / 65536.0, @as(f32, 0xB785) / 65536.0, @as(f32, 0x0F84) / 65536.0 },
    .{ @as(f32, 0x0390) / 65536.0, @as(f32, 0x18DA) / 65536.0, @as(f32, 0xB6CF) / 65536.0 },
};
const contrast_a98_d50: Matrix32 = .{
    .{ @as(f32, 0x9c18) / 65536.0, @as(f32, 0x348d) / 65536.0, @as(f32, 0x2631) / 65536.0 },
    .{ @as(f32, 0x4fa5) / 65536.0, @as(f32, 0xa02c) / 65536.0, @as(f32, 0x102f) / 65536.0 },
    .{ @as(f32, 0x04fc) / 65536.0, @as(f32, 0x0f95) / 65536.0, @as(f32, 0xbe9c) / 65536.0 },
};
const contrast_p3_d50: Matrix32 = .{
    .{ 0.515102, 0.291965, 0.157153 }, .{ 0.241182, 0.692236, 0.0665819 }, .{ -0.00104941, 0.0418818, 0.784378 },
};
const contrast_rec2020_d50: Matrix32 = .{
    .{ 0.673459, 0.165661, 0.125100 }, .{ 0.279033, 0.675338, 0.0456288 }, .{ -0.00193139, 0.0299794, 0.797162 },
};
const contrast_xyz_lms: Matrix32 = .{
    .{ 0.8190224432164319, 0.3619062562801221, -0.12887378261216414 },
    .{ 0.0329836671980271, 0.9292868468965546, 0.03614466816999844 },
    .{ 0.048177199566046255, 0.26423952494422764, 0.6335478258136937 },
};
const contrast_oklab_lms: Matrix32 = .{
    .{ 0.99999999845051981432, 0.39633779217376785678, 0.21580375806075880339 },
    .{ 1.0000000088817607767, -0.1055613423236563494, -0.063854174771705903402 },
    .{ 1.0000000546724109177, -0.089484182094965759684, -1.2914855378640917399 },
};
fn matrix32(comptime m: Matrix) Matrix32 {
    var result: Matrix32 = undefined;
    for (m, &result) |row, *target| for (row, target) |v, *out| {
        out.* = @floatCast(v);
    };
    return result;
}
fn inverse32(comptime m: Matrix32) Matrix32 {
    var wide: Matrix = undefined;
    for (m, &wide) |row, *target| for (row, target) |v, *out| {
        out.* = v;
    };
    return matrix32(inverse(wide));
}
fn multiply32(m: Matrix32, v: [3]f32) [3]f32 {
    var out: [3]f32 = undefined;
    for (m, &out) |row, *value| value.* = row[0] * v[0] + row[1] * v[1] + row[2] * v[2];
    return out;
}
fn power32(v: f32, exponent: f32) f32 {
    return std.math.copysign(std.math.pow(f32, @abs(v), exponent), v);
}
fn encode32(v: f32) f32 {
    return if (@abs(v) <= 0.0031308) v * 12.92 else std.math.copysign(1.055 * std.math.pow(f32, @abs(v), 1.0 / 2.4) - 0.055, v);
}
fn decode32(v: f32) f32 {
    return if (@abs(v) <= 0.04045) v / 12.92 else std.math.copysign(std.math.pow(f32, (@abs(v) + 0.055) / 1.055, 2.4), v);
}
fn labInverse32(v: f32) f32 {
    return if (v <= 24.0 / 116.0) (108.0 / 841.0) * (v - 16.0 / 116.0) else v * v * v;
}
fn contrastRgb(color: Components) [3]f32 {
    var v: [3]f32 = .{ @floatCast(color.channel(0)), @floatCast(color.channel(1)), @floatCast(color.channel(2)) };
    var space = color.space;
    if (space == .srgb) return v;
    if (space == .srgb_linear) return .{ encode32(v[0]), encode32(v[1]), encode32(v[2]) };
    if (space == .hsl or space == .hwb) {
        if (space == .hwb and v[1] + v[2] >= 100) {
            const gray = v[1] / (v[1] + v[2]);
            return .{ gray, gray, gray };
        }
        const saturation: f32 = if (space == .hsl) v[1] / 100 else 1;
        const lightness: f32 = if (space == .hsl) v[2] / 100 else 0.5;
        const amplitude = saturation * @min(lightness, 1 - lightness);
        var rgb: [3]f32 = undefined;
        for ([_]f32{ 0, 8, 4 }, &rgb) |offset, *out| {
            const k = @mod(offset + v[0] / 30, 12);
            out.* = lightness - amplitude * @max(-1, @min(@min(k - 3, 9 - k), 1));
            if (space == .hwb) out.* = out.* * (1 - (v[1] + v[2]) / 100) + v[1] / 100;
        }
        return rgb;
    }
    if (space == .lch or space == .oklch) {
        const angle = v[2] * (@as(f32, std.math.pi) / 180);
        // Materialize both coordinates before overwriting v: aggregate
        // result locations may write v[1] before reading it for v[2].
        const chroma = v[1];
        const a = chroma * @cos(angle);
        const b = chroma * @sin(angle);
        v = .{ v[0], a, b };
        space = if (space == .lch) .lab else .oklab;
    }
    const adaptation = comptime matrix32(inverse(d50_d65));
    switch (space) {
        .lab => {
            const y = (v[0] + 16) / 116;
            v = .{ labInverse32(y + v[1] / 500) * 0.9642, labInverse32(y), labInverse32(y - v[2] / 200) * 0.8251 };
        },
        .oklab => {
            v = multiply32(contrast_oklab_lms, v);
            for (&v) |*channel| channel.* = channel.* * channel.* * channel.*;
            v = multiply32(adaptation, multiply32(comptime inverse32(contrast_xyz_lms), v));
        },
        .xyz_d65 => v = multiply32(adaptation, v),
        .xyz_d50 => {},
        .display_p3, .display_p3_linear, .a98_rgb, .prophoto_rgb, .rec2020 => {
            for (&v) |*channel| channel.* = switch (space) {
                .display_p3 => decode32(channel.*),
                .display_p3_linear => channel.*,
                .a98_rgb => power32(channel.*, 563.0 / 256.0),
                .prophoto_rgb => if (@abs(channel.*) <= 16.0 / 512.0) channel.* / 16 else power32(channel.*, 1.8),
                .rec2020 => power32(channel.*, 2.4),
                else => unreachable,
            };
            v = multiply32(switch (space) {
                .display_p3, .display_p3_linear => contrast_p3_d50,
                .a98_rgb => contrast_a98_d50,
                .prophoto_rgb => comptime matrix32(prophoto_xyz),
                .rec2020 => contrast_rec2020_d50,
                else => unreachable,
            }, v);
        },
        else => unreachable,
    }
    // One transform preserves the infinity cancellation the browser probes
    // expose; a D50→D65→linear-sRGB sequence has different NaN propagation.
    v = multiply32(comptime inverse32(contrast_srgb_d50), v);
    for (&v) |*channel| channel.* = encode32(channel.*);
    return v;
}

// Color4 §4.4.1 / CSSWG #14133, Q110. Pin the existing newer-spec
// normalization independently of the old white-mix WPT expectations.
test "converted powerless components suppress positive colorfulness noise" {
    const testing = std.testing;
    inline for (.{
        .{ Space.hsl, @as(f64, 0.001), @as(usize, 0) },
        .{ Space.lch, @as(f64, 0.0015), @as(usize, 2) },
        .{ Space.oklch, @as(f64, 0.000004), @as(usize, 2) },
    }) |case| {
        for ([_]f64{ case[1] / 2, case[1] }) |small| {
            var value = Components{ .space = case[0], .channels = .{ 30, small, 30 } };
            value.powerless();
            try testing.expect(value.absent(case[2]));
            try testing.expectEqual(@as(f64, 0), value.channels[1]);
        }
        var above = Components{ .space = case[0], .channels = .{ 30, case[1] * 2, 30 } };
        above.powerless();
        try testing.expect(!above.absent(case[2]));
        try testing.expectEqual(case[1] * 2, above.channels[1]);
        var negative = Components{ .space = case[0], .channels = .{ 30, -case[1], 30 } };
        negative.powerless();
        try testing.expect(negative.absent(case[2]));
        try testing.expectEqual(-case[1], negative.channels[1]);
    }
}

test "HWB powerless normalization handles epsilon boundary and missing components" {
    const testing = std.testing;
    for ([_]f64{ 99.999, 99.9995 }) |sum| {
        var value = Components{ .space = .hwb, .channels = .{ 30, sum, 0 } };
        value.powerless();
        try testing.expect(value.absent(0));
        try testing.expectEqual(@as(f64, 100), value.channels[1] + value.channels[2]);
        var missing_black = Components{ .space = .hwb, .channels = .{ 30, sum, 0 }, .missing = 4 };
        missing_black.powerless();
        try testing.expectEqual(@as(u4, 5), missing_black.missing);
        try testing.expectEqual(@as(f64, 100), missing_black.channels[1]);
        var missing_white = Components{ .space = .hwb, .channels = .{ 30, 0, sum }, .missing = 2 };
        missing_white.powerless();
        try testing.expectEqual(@as(u4, 3), missing_white.missing);
        try testing.expectEqual(@as(f64, 100), missing_white.channels[2]);
    }
    var above = Components{ .space = .hwb, .channels = .{ 30, 80, 30 } };
    above.powerless();
    try testing.expect(above.absent(0));
    try testing.expectEqual(@as(f64, 110), above.channels[1] + above.channels[2]);
    var below = Components{ .space = .hwb, .channels = .{ 30, 99.998, 0 } };
    below.powerless();
    try testing.expect(!below.absent(0));
    const authored = Components{ .space = .hwb, .channels = .{ 30, 100, 0 } };
    try testing.expect(authored.eql(authored.convert(.hwb)));
}
