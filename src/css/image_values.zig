//! CSS Images4 §2.4 and Color5 §7: owned image choices, never resource loading.
//! Legacy cross-fade follows Chrome/WebKit (Q21); standard gradients are typed.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const resources = @import("resource_values.zig");
const Scheme = @import("color_scheme.zig").Scheme;
const tokenizer = @import("tokenizer.zig");
const gradients = @import("gradient_values.zig");
const math = @import("math_values.zig");
const image_values = @This();
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Resolution = struct {
    number: f64 = 1,
    unit: enum { x, dppx, dpi, dpcm } = .x,

    pub fn dppx(self: Resolution) f64 {
        return self.number * switch (self.unit) {
            .x, .dppx => @as(f64, 1),
            .dpi => 1.0 / 96.0,
            .dpcm => 2.54 / 96.0,
        };
    }
    fn serialize(self: Resolution, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try values.appendNumber(self.number, out, allocator);
        try out.appendSlice(allocator, @tagName(self.unit));
    }
};

pub const Candidate = struct {
    image: Value,
    resolution_dppx: f64 = 1,
    mime_type: ?[]const u8 = null,
    resolution: Resolution = .{},
    /// Images4 §2.4: omitted resolution defaults selection to 1x, but does
    /// not override an image's intrinsic resolution supplied by its format.
    resolution_explicit: bool = false,
    /// Images4 §2.4: a specified math descriptor owns this value until compute.
    /// While pending, resolution_dppx is inactive; readers use resolutionDppx.
    resolution_value: ?Value = null,

    pub fn resolutionDppx(self: Candidate) ?f64 {
        return if (self.resolution_value != null) null else self.resolution_dppx;
    }
};
pub const Set = struct { candidates: []const Candidate };
pub const CrossFade = struct {
    inputs: [2]Value,
    weight: f64,
    /// Q143: a specified expression owns its pending progress. Consumers use
    /// the nullable accessor, never the inactive numeric field before compute.
    weight_value: ?Value = null,

    pub fn normalizedWeight(self: CrossFade) ?f64 {
        return if (self.weight_value != null) null else self.weight;
    }
};

pub const TypeSupport = struct {
    context: *const anyopaque,
    /// True only for a valid MIME type naming a supported image format.
    supports: *const fn (*const anyopaque, []const u8) bool,
};

/// Images4 §2.4 selection steps 1–5, with Blink/WebKit's scale choice:
/// the lowest supported resolution >= scale, or the largest below it.
/// Equal resolutions never replace an earlier supported choice (step 2).
/// The returned index borrows the ORIGINAL list; nothing is filtered in place.
pub fn select(candidates: []const Candidate, scale: f64, support: TypeSupport) ?usize {
    std.debug.assert(std.math.isFinite(scale) and scale > 0);
    // Q114: selection consumes a fully computed set, never a partial choice
    // that hides an unresolved descriptor later in the original list.
    for (candidates) |candidate| if (candidate.resolutionDppx() == null) return null;
    var best: ?usize = null;
    for (candidates, 0..) |candidate, i| {
        // Step 1 precedes duplicate removal: an unsupported earlier image
        // must not hide a later supported image at the same resolution.
        if (candidate.mime_type) |mime| if (!support.supports(support.context, mime)) continue;
        // Blink IsSupported rejects 0dppx; WebKit returns InvalidImage when
        // its best result has zero scale. Zero remains valid specified CSS.
        const next = candidate.resolutionDppx().?;
        if (!(next > 0)) continue;
        const old_index = best orelse {
            best = i;
            continue;
        };
        const old = candidates[old_index].resolutionDppx().?;
        const improves = if (old >= scale)
            next >= scale and next < old
        else
            next >= scale or next > old;
        if (improves) best = i;
    }
    // Step 3: null means an invalid image, not a request for fallthrough.
    return best;
}

pub const Data = union(enum) {
    image_set: Set,
    light_dark: [2]Value,
    cross_fade: CrossFade,
    solid_color: values.Color,
    gradient: gradients.Gradient,

    fn clone(self: Data, allocator: Allocator) Allocator.Error!Data {
        return switch (self) {
            .gradient => |gradient| .{ .gradient = try gradient.clone(allocator) },
            .image_set => |set| blk: {
                const copy = try allocator.alloc(Candidate, set.candidates.len);
                errdefer allocator.free(copy);
                var count: usize = 0;
                errdefer for (copy[0..count]) |item| {
                    item.image.release();
                    if (item.resolution_value) |value| value.release();
                    if (item.mime_type) |mime| allocator.free(mime);
                };
                for (set.candidates, copy) |item, *dest| {
                    const mime = if (item.mime_type) |mime_text| try allocator.dupe(u8, mime_text) else null;
                    dest.* = item;
                    dest.mime_type = mime;
                    item.image.retain();
                    if (item.resolution_value) |value| value.retain();
                    count += 1;
                }
                break :blk .{ .image_set = .{ .candidates = copy } };
            },
            .light_dark => |pair| blk: {
                for (pair) |item| item.retain();
                break :blk self;
            },
            .cross_fade => |cross| blk: {
                for (cross.inputs) |item| item.retain();
                if (cross.weight_value) |value| value.retain();
                break :blk self;
            },
            .solid_color => |color| blk: {
                color.retain();
                break :blk self;
            },
        };
    }

    fn release(self: Data, allocator: Allocator) void {
        switch (self) {
            .gradient => |gradient| gradient.release(allocator),
            .image_set => |set| {
                for (set.candidates) |item| {
                    item.image.release();
                    if (item.resolution_value) |value| value.release();
                    if (item.mime_type) |mime| allocator.free(mime);
                }
                allocator.free(set.candidates);
            },
            .light_dark => |pair| for (pair) |item| item.release(),
            .cross_fade => |cross| {
                for (cross.inputs) |item| item.release();
                if (cross.weight_value) |value| value.release();
            },
            .solid_color => |color| color.release(),
        }
    }

    fn text(self: Data, allocator: Allocator) Allocator.Error!*values.SharedText {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        var urls = resources.Builder{ .allocator = allocator };
        defer urls.deinit();
        switch (self) {
            .gradient => |gradient| {
                try gradient.serialize(&out, allocator);
                return values.SharedText.create(allocator, out.items);
            },
            .image_set => |set| {
                try out.appendSlice(allocator, "image-set(");
                for (set.candidates, 0..) |candidate, i| {
                    if (i != 0) try out.appendSlice(allocator, ", ");
                    try appendImage(candidate.image, &out, &urls, allocator);
                    try out.append(allocator, ' ');
                    if (candidate.resolution_value) |value|
                        try properties.serializeValue(.margin_left, value, &out, allocator)
                    else
                        try candidate.resolution.serialize(&out, allocator);
                    if (candidate.mime_type) |mime| {
                        try out.appendSlice(allocator, " type(");
                        try values.appendString(mime, &out, allocator);
                        try out.append(allocator, ')');
                    }
                }
            },
            .light_dark => |pair| {
                try out.appendSlice(allocator, "light-dark(");
                try appendImage(pair[0], &out, &urls, allocator);
                try out.appendSlice(allocator, ", ");
                try appendImage(pair[1], &out, &urls, allocator);
            },
            .cross_fade => |cross| {
                try out.appendSlice(allocator, "-webkit-cross-fade(");
                try appendImage(cross.inputs[0], &out, &urls, allocator);
                try out.appendSlice(allocator, ", ");
                try appendImage(cross.inputs[1], &out, &urls, allocator);
                try out.appendSlice(allocator, ", ");
                // Q148: specified math keeps calc; literals and computed
                // progress use the normalized number (WebKit's spelling).
                if (cross.weight_value) |value|
                    try properties.serializeValue(.margin_left, value, &out, allocator)
                else
                    try values.appendNumber(cross.normalizedWeight().?, &out, allocator);
            },
            .solid_color => |color| {
                try out.appendSlice(allocator, "image(");
                try color.serializeSpecified(&out, allocator);
            },
        }
        try out.append(allocator, ')');
        const result = try values.SharedText.create(allocator, out.items);
        errdefer result.unref();
        result.resource_urls = try urls.take();
        return result;
    }
};

fn appendImage(value: Value, out: *std.ArrayList(u8), urls: *resources.Builder, allocator: Allocator) Allocator.Error!void {
    try urls.append(value.resourceUrls(), out.items.len);
    try properties.serializeValue(.list_style_image, value, out, allocator);
}

pub const Image = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    data: Data,
    text: *values.SharedText,

    /// All arguments are borrowed. The new immutable image owns each copy.
    pub fn create(allocator: Allocator, data: Data) Allocator.Error!*Image {
        const owned = try data.clone(allocator);
        errdefer owned.release(allocator);
        const text = try owned.text(allocator);
        errdefer text.unref();
        const self = try allocator.create(Image);
        self.* = .{ .allocator = allocator, .data = owned, .text = text };
        return self;
    }
    pub fn ref(self: *Image) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Image) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.data.release(self.allocator);
        self.text.unref();
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Image, other: *const Image) bool {
        if (self == other) return true;
        if (std.meta.activeTag(self.data) != std.meta.activeTag(other.data)) return false;
        if (!std.mem.eql(u8, self.text.bytes, other.text.bytes)) return false;
        // An omitted resolution and an explicit 1x serialize alike but have
        // different natural-resolution behavior (Images4 §2.4).
        switch (self.data) {
            .image_set => |set| {
                const a = set.candidates;
                const b = other.data.image_set.candidates;
                if (a.len != b.len) return false;
                for (a, b) |x, y| {
                    if (x.resolution_explicit != y.resolution_explicit or !x.image.eql(y.image)) return false;
                    if ((x.resolution_value == null) != (y.resolution_value == null)) return false;
                    if (x.resolution_value) |value| if (!value.eql(y.resolution_value.?)) return false;
                }
            },
            .light_dark => |pair| {
                for (pair, other.data.light_dark) |a, b| if (!a.eql(b)) return false;
            },
            .cross_fade => |cross| {
                for (cross.inputs, other.data.cross_fade.inputs) |a, b| if (!a.eql(b)) return false;
                if ((cross.weight_value == null) != (other.data.cross_fade.weight_value == null)) return false;
                if (cross.weight_value) |value| if (!value.eql(other.data.cross_fade.weight_value.?)) return false;
            },
            .solid_color => |color| if (!color.eql(other.data.solid_color)) return false,
            .gradient => |gradient| if (!gradient.eql(other.data.gradient)) return false,
        }
        return true;
    }

    pub fn needsUnavailableMetrics(self: *const Image, geometry_length: bool) bool {
        return switch (self.data) {
            .image_set => |set| blk: {
                for (set.candidates) |candidate| {
                    if (candidate.image.needsUnavailableMetrics(geometry_length)) break :blk true;
                    if (candidate.resolution_value) |value| if (value.needsUnavailableMetrics(false)) break :blk true;
                }
                break :blk false;
            },
            .light_dark => |pair| pair[0].needsUnavailableMetrics(geometry_length) or pair[1].needsUnavailableMetrics(geometry_length),
            .cross_fade => |cross| cross.inputs[0].needsUnavailableMetrics(geometry_length) or cross.inputs[1].needsUnavailableMetrics(geometry_length) or
                (if (cross.weight_value) |value| value.needsUnavailableMetrics(false) else false),
            .solid_color => |color| color.needsUnavailableMetrics(geometry_length),
            .gradient => |gradient| gradient.needsUnavailableMetrics(geometry_length),
        };
    }

    pub fn needsTreeCounts(self: *const Image) bool {
        return switch (self.data) {
            .image_set => |set| blk: {
                for (set.candidates) |candidate| {
                    if (candidate.image.needsTreeCounts()) break :blk true;
                    if (candidate.resolution_value) |value| if (value.needsTreeCounts()) break :blk true;
                }
                break :blk false;
            },
            .light_dark => |pair| pair[0].needsTreeCounts() or pair[1].needsTreeCounts(),
            .cross_fade => |cross| cross.inputs[0].needsTreeCounts() or cross.inputs[1].needsTreeCounts() or
                (if (cross.weight_value) |value| value.needsTreeCounts() else false),
            .solid_color => |color| color.needsTreeCounts(),
            .gradient => |gradient| gradient.needsTreeCounts(),
        };
    }

    pub fn needsRandomBase(self: *const Image) bool {
        return switch (self.data) {
            .image_set => |set| blk: {
                for (set.candidates) |candidate| {
                    if (candidate.image.needsRandomBase()) break :blk true;
                    if (candidate.resolution_value) |value| if (value.needsRandomBase()) break :blk true;
                }
                break :blk false;
            },
            .light_dark => |pair| pair[0].needsRandomBase() or pair[1].needsRandomBase(),
            .cross_fade => |cross| cross.inputs[0].needsRandomBase() or cross.inputs[1].needsRandomBase() or
                (if (cross.weight_value) |value| value.needsRandomBase() else false),
            .solid_color => |color| color.needsRandomBase(),
            .gradient => |gradient| gradient.needsRandomBase(),
        };
    }

    /// Structural dependency query; Color alone owns color graph inspection.
    pub fn containsCurrentColor(self: *const Image) bool {
        return switch (self.data) {
            .gradient => |gradient| gradient.containsCurrentColor(),
            .solid_color => |color| color.containsCurrentColor(),
            .image_set => |set| blk: {
                for (set.candidates) |candidate| if (image_values.containsCurrentColor(candidate.image)) break :blk true;
                break :blk false;
            },
            .light_dark => |pair| image_values.containsCurrentColor(pair[0]) or image_values.containsCurrentColor(pair[1]),
            .cross_fade => |cross| image_values.containsCurrentColor(cross.inputs[0]) or image_values.containsCurrentColor(cross.inputs[1]),
        };
    }

    // Image.create borrows each temporary, clones its owned data and rebuilds
    // URL occurrence offsets against the replacement text. No selection,
    // descriptor computation or URL resolution belongs to this CSSOM copy.
    fn resolveColors(self: *const Image, allocator: Allocator, context: values.Color.Context) Allocator.Error!Value {
        switch (self.data) {
            .gradient => |gradient| {
                const resolved = try gradient.resolveCurrentColors(allocator, context);
                defer resolved.release(allocator);
                return .{ .image = try create(allocator, .{ .gradient = resolved }) };
            },
            .solid_color => |color| {
                const resolved = try color.resolveComputed(allocator, context);
                defer resolved.release();
                return .{ .image = try create(allocator, .{ .solid_color = resolved }) };
            },
            .image_set => |set| {
                const candidates = try allocator.alloc(Candidate, set.candidates.len);
                var initialized: usize = 0;
                defer {
                    for (candidates[0..initialized]) |candidate| candidate.image.release();
                    allocator.free(candidates);
                }
                for (set.candidates, candidates) |candidate, *replacement| {
                    var resolved = candidate;
                    resolved.image = try resolveCurrentColors(allocator, .list_style_image, candidate.image, context);
                    replacement.* = resolved;
                    initialized += 1;
                }
                // These temporary records own only the replacement images;
                // MIME strings and every descriptor stay borrowed until create.
                return .{ .image = try create(allocator, .{ .image_set = .{ .candidates = candidates } }) };
            },
            .light_dark => |pair| {
                const first = try resolveCurrentColors(allocator, .list_style_image, pair[0], context);
                defer first.release();
                const second = try resolveCurrentColors(allocator, .list_style_image, pair[1], context);
                defer second.release();
                return .{ .image = try create(allocator, .{ .light_dark = .{ first, second } }) };
            },
            .cross_fade => |cross| {
                const first = try resolveCurrentColors(allocator, .list_style_image, cross.inputs[0], context);
                defer first.release();
                const second = try resolveCurrentColors(allocator, .list_style_image, cross.inputs[1], context);
                defer second.release();
                var resolved = cross;
                resolved.inputs = .{ first, second };
                return .{ .image = try create(allocator, .{ .cross_fade = resolved }) };
            },
        }
    }

    pub fn compute(self: *const Image, allocator: Allocator, scheme: Scheme, context: anytype) Allocator.Error!Value {
        switch (self.data) {
            .gradient => |gradient| {
                const computed = try gradient.compute(allocator, scheme, context);
                defer computed.release(allocator);
                return .{ .image = try create(allocator, .{ .gradient = computed }) };
            },
            .light_dark => |pair| {
                // Color5 §7: choose at computed time BEFORE inheritance.
                const chosen = pair[if (scheme == .dark) @as(usize, 1) else 0];
                if (chosen.isKeyword(.none)) {
                    // Color5 §7 synthesizes image(transparent); Color4 §15.5
                    // still computes its specified keyword to transparent black.
                    const computed = try context.color(values.Color.transparent);
                    defer computed.release();
                    return .{ .image = try create(allocator, .{ .solid_color = computed }) };
                }
                return context.component(.list_style_image, chosen);
            },
            .image_set => |set| {
                var items: std.ArrayList(Candidate) = .empty;
                defer {
                    for (items.items) |item| item.image.release();
                    items.deinit(allocator);
                }
                try items.ensureTotalCapacity(allocator, set.candidates.len);
                for (set.candidates) |candidate| {
                    // Images4 §2.4: compute every descriptor before the later
                    // selection step. Context carries the winning Source.
                    const dppx = if (candidate.resolution_value) |value| blk: {
                        const result = try context.length(value);
                        defer result.release();
                        std.debug.assert(result == .calculation);
                        const number = result.calculation.computedNumber().?;
                        std.debug.assert(number.unit == .dppx);
                        break :blk number.value;
                    } else candidate.resolutionDppx().?;
                    var computed = candidate;
                    computed.resolution_value = null;
                    computed.resolution_dppx = dppx;
                    computed.resolution = .{ .number = dppx, .unit = .dppx };
                    computed.image = try context.component(.list_style_image, candidate.image);
                    items.appendAssumeCapacity(computed);
                }
                // Keep EVERY option; selection is a separate used-value step.
                return .{ .image = try create(allocator, .{ .image_set = .{ .candidates = items.items } }) };
            },
            .cross_fade => |cross| {
                // Values §10.11–10.12: compute with the winning Source,
                // normalizing percentages and clamping only the outer result.
                const weight = if (cross.weight_value) |value| blk: {
                    const result = try context.length(value);
                    defer result.release();
                    std.debug.assert(result == .number);
                    break :blk result.number;
                } else cross.normalizedWeight().?;
                const first = try context.component(.list_style_image, cross.inputs[0]);
                defer first.release();
                const second = try context.component(.list_style_image, cross.inputs[1]);
                defer second.release();
                return .{ .image = try create(allocator, .{ .cross_fade = .{ .inputs = .{ first, second }, .weight = weight } }) };
            },
            .solid_color => |color| {
                const computed = try context.color(color);
                defer computed.release();
                return .{ .image = try create(allocator, .{ .solid_color = computed }) };
            },
        }
    }
};

/// Whether an image aggregate contains a receiver-dependent color. Unrelated
/// Value arms and opaque leaves have no typed image colors to inspect.
pub fn containsCurrentColor(value: Value) bool {
    return switch (value) {
        .image => |image| image.containsCurrentColor(),
        .layers => |layers| blk: {
            for (layers.items) |item| if (containsCurrentColor(item)) break :blk true;
            break :blk false;
        },
        .content => |content| blk: {
            for (content.items) |item| if (item.image) |image| {
                if (containsCurrentColor(image)) break :blk true;
            };
            break :blk false;
        },
        else => false,
    };
}

const ResolvedColorContext = struct {
    allocator: Allocator,
    color: values.Color.Context,

    pub fn component(self: ResolvedColorContext, longhand: properties.Longhand, value: Value) Allocator.Error!Value {
        return resolveCurrentColors(self.allocator, longhand, value, self.color);
    }
};

/// Owned CSSOM image value (CSSOM §6.7.2 step 4, Color4 §15.5). Preserve
/// computed numbers, image choices and resource identities; only resolve
/// dependent colors. A graph without currentcolor is retained allocation-free.
pub fn resolveCurrentColors(allocator: Allocator, longhand: properties.Longhand, value: Value, context: values.Color.Context) Allocator.Error!Value {
    if (!containsCurrentColor(value)) {
        value.retain();
        return value;
    }
    const narrow = ResolvedColorContext{ .allocator = allocator, .color = context };
    return switch (value) {
        .image => |image| image.resolveColors(allocator, context),
        .layers => |layers| .{ .layers = try layers.compute(allocator, longhand, narrow) },
        .content => |content| .{ .content = try content.computeImages(allocator, narrow) },
        else => unreachable,
    };
}

/// All fields are borrowed from the retained Value. No CSS is reparsed here.
pub const View = union(enum) {
    none,
    url: resources.ResourceUrl,
    image_set: *const Set,
    light_dark: *const [2]Value,
    cross_fade: *const CrossFade,
    solid_color: values.Color,
    gradient: *const values.SharedText,
    other: *const values.SharedText,
};

pub fn view(value: Value) ?View {
    if (value.isKeyword(.none)) return .none;
    if (value == .image) return switch (value.image.data) {
        .image_set => .{ .image_set = &value.image.data.image_set },
        .light_dark => .{ .light_dark = &value.image.data.light_dark },
        .cross_fade => .{ .cross_fade = &value.image.data.cross_fade },
        .solid_color => |color| .{ .solid_color = color },
        .gradient => .{ .gradient = value.image.text },
    };
    if (value == .text) return switch (value.text.image_kind) {
        .generic => null,
        .url => .{ .url = value.text.resource_urls[0] },
        .gradient => .{ .gradient = value.text },
        .other => .{ .other = value.text },
    };
    return null;
}

pub const Policy = struct {
    /// CSS UI4 §5.1.1's url-set accepts URL leaves only; light-dark must
    /// propagate this restriction rather than admit a generated cursor.
    generated: bool = true,
    image_set: bool = true,
    none: bool = false,
};

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream, policy: Policy) Allocator.Error!?Value {
    return parseAtDepth(options, stream, policy, 0);
}

pub fn parseList(options: properties.ParseOptions, longhand: properties.Longhand, stream: *properties.Stream) Allocator.Error!?Value {
    return @import("image_layers.zig").parse(options, longhand, stream, parseLayer);
}

fn parseLayer(options: properties.ParseOptions, _: properties.Longhand, stream: *properties.Stream) Allocator.Error!?Value {
    return parse(options, stream, .{ .none = true });
}

/// Q36: accept 128 composite levels, reject the 129th before allocating it.
/// A shared counter also covers cross-fade's deliberately different nesting
/// grammar; resetting its image-set policy never resets the recursion bound.
fn parseAtDepth(options: properties.ParseOptions, stream: *properties.Stream, policy: Policy, depth: usize) Allocator.Error!?Value {
    const token = stream.peek();
    if (token.token_type == .ident and tokenizer.nameEql(token.value, "none")) {
        if (!policy.none) return null;
        _ = stream.next();
        return Value.kw(.none);
    }
    if (token.token_type == .function) {
        if (policy.generated and tokenizer.nameEql(token.value, "image")) {
            // Images4 §2.5: recognize the complete sole-color production.
            // Q168 preserves the legacy URL/direction/fallback grammar below
            // when this production does not match; no rejection is widened.
            const original = stream.*;
            if (try parseSolidColor(options, stream)) |image| return image;
            stream.* = original;
        }
        if (policy.generated and gradients.function(token) != null) {
            const gradient = try gradients.parse(options, stream) orelse return null;
            defer gradient.release(options.allocator);
            return .{ .image = try Image.create(options.allocator, .{ .gradient = gradient }) };
        }
        if (tokenizer.nameEql(token.value, "image-set") or tokenizer.nameEql(token.value, "-webkit-image-set")) {
            if (!policy.image_set or depth == 128) return null;
            return parseSet(options, stream, policy, depth + 1);
        }
        if (tokenizer.nameEql(token.value, "light-dark")) {
            if (depth == 128) return null;
            return parseLightDark(options, stream, policy, depth + 1);
        }
        if (tokenizer.nameEql(token.value, "-webkit-cross-fade")) {
            if (!policy.generated or depth == 128) return null;
            return parseCrossFade(options, stream, depth + 1);
        }
    }
    if (!policy.generated and !isUrl(token)) return null;
    // The legacy leaf grammar retains its URLs and nonstandard functions,
    // with resolver and provenance behavior unchanged.
    const leaf = (try properties.parseImageLeaf(options, stream)) orelse return null;
    if (!policy.image_set and leaf == .text) {
        // The raw legacy leaf branch has not acquired its complete grammar
        // yet. It must still obey the surrounding image-set nesting rule.
        var tokens = tokenizer.Tokenizer.init(leaf.text.bytes);
        while (true) {
            const child = tokens.next();
            if (child.token_type == .eof) break;
            if (child.token_type == .function and (tokenizer.nameEql(child.value, "image-set") or tokenizer.nameEql(child.value, "-webkit-image-set"))) {
                leaf.release();
                return null;
            }
        }
    }
    return leaf;
}

/// Parses sole-color image() from a borrowed stream and returns an owned value.
/// Callers trying another grammar must restore their stream on a non-match.
pub fn parseSolidColor(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    // Images4 §2.5 and Syntax3 §5.5.10: EOF closes an open image() just
    // as it closes a nested color function. Colors never enable quirks here.
    if (!beginFunction(stream)) return null;
    var strict = options;
    strict.quirks = false;
    const color = try properties.parseLonghand(strict, .color, stream) orelse return null;
    defer color.release();
    if (color != .color or !endFunction(stream)) return null;
    return .{ .image = try Image.create(options.allocator, .{ .solid_color = color.color }) };
}

fn isUrl(token: tokenizer.Token) bool {
    return token.token_type == .url or (token.token_type == .function and
        (tokenizer.nameEql(token.value, "url") or tokenizer.nameEql(token.value, "src")));
}

fn beginFunction(stream: *properties.Stream) bool {
    _ = stream.next();
    return stream.next().token_type == .left_paren;
}

/// Syntax3 §5.5.10: EOF closes each open function, including nested ones.
fn endFunction(stream: *properties.Stream) bool {
    return switch (stream.next().token_type) {
        .right_paren, .eof => true,
        else => false,
    };
}

fn parseResolution(stream: *properties.Stream) ?Resolution {
    const token = stream.peek();
    if (token.token_type != .dimension) return null;
    const number = token.numeric_value orelse return null;
    if (!std.math.isFinite(number) or number < 0) return null;
    const unit = token.unit orelse return null;
    inline for (.{ "x", "dppx", "dpi", "dpcm" }) |name| {
        if (tokenizer.nameEql(unit, name)) {
            _ = stream.next();
            return .{ .number = number, .unit = @field(@FieldType(Resolution, "unit"), name) };
        }
    }
    return null;
}

fn parseSet(options: properties.ParseOptions, stream: *properties.Stream, policy: Policy, depth: usize) Allocator.Error!?Value {
    const original = stream.*;
    if (!beginFunction(stream)) return null;
    const allocator = options.allocator;
    var candidates: std.ArrayList(Candidate) = .empty;
    defer {
        for (candidates.items) |candidate| {
            candidate.image.release();
            if (candidate.resolution_value) |value| value.release();
            if (candidate.mime_type) |mime| allocator.free(mime);
        }
        candidates.deinit(allocator);
    }
    while (true) {
        const token = stream.peek();
        const argument_start = stream.*;
        const image = if (token.token_type == .string) blk: {
            const begin = stream.peeked_offset;
            _ = stream.next();
            if (properties.urlRangeTainted(options, .{ .start = begin, .end = stream.tok.pos })) return null;
            const decoded = try tokenizer.decode(allocator, token.stringContents());
            defer allocator.free(decoded);
            break :blk try properties.urlValue(options, decoded);
        } else (try parseAtDepth(options, stream, .{ .generated = policy.generated, .image_set = false }, depth)) orelse {
            // Q81 interim: preserve the old opaque whole-function value only
            // for a quoted URL with a tail. The queued CSS URL REQUEST
            // MODIFIERS row replaces this with typed parsing and request data.
            if (quotedUrlHasTail(argument_start)) {
                stream.* = original;
                return properties.parseImageLeaf(options, stream);
            }
            return null;
        };
        var candidate = Candidate{ .image = image };
        var transferred = false;
        defer if (!transferred) {
            image.release();
            if (candidate.resolution_value) |value| value.release();
            if (candidate.mime_type) |mime| allocator.free(mime);
        };
        // Images4 §2.4: resolution || type(string), either order, once each.
        for (0..2) |_| {
            const next = stream.peek();
            if (candidate.mime_type == null and next.token_type == .function and tokenizer.nameEql(next.value, "type")) {
                if (!beginFunction(stream)) return null;
                const mime = stream.next();
                if (mime.token_type != .string or !endFunction(stream)) return null;
                candidate.mime_type = try tokenizer.decode(allocator, mime.stringContents());
            } else if (!candidate.resolution_explicit) {
                if (math.isFunction(next)) {
                    candidate.resolution_value = (try properties.mathValue(options, stream, .{ .kind = .resolution, .minimum = 0 })) orelse return null;
                } else {
                    const resolution = parseResolution(stream) orelse break;
                    candidate.resolution = resolution;
                    candidate.resolution_dppx = resolution.dppx();
                }
                candidate.resolution_explicit = true;
            } else break;
        }
        try candidates.append(allocator, candidate);
        transferred = true;
        switch (stream.next().token_type) {
            .comma => continue,
            .right_paren, .eof => break,
            else => return null,
        }
    }
    return .{ .image = try Image.create(allocator, .{ .image_set = .{ .candidates = candidates.items } }) };
}

fn quotedUrlHasTail(original: properties.Stream) bool {
    var probe = original;
    const token = probe.next();
    if (token.token_type != .function or !isUrl(token)) return false;
    if (probe.next().token_type != .left_paren or probe.next().token_type != .string) return false;
    const after_string = probe.next().token_type;
    return after_string != .right_paren and after_string != .eof;
}

fn parseLightDark(options: properties.ParseOptions, stream: *properties.Stream, policy: Policy, depth: usize) Allocator.Error!?Value {
    if (!beginFunction(stream)) return null;
    var child_policy = policy;
    child_policy.none = true;
    const light = (try parseAtDepth(options, stream, child_policy, depth)) orelse return null;
    defer light.release();
    if (stream.next().token_type != .comma) return null;
    const dark = (try parseAtDepth(options, stream, child_policy, depth)) orelse return null;
    defer dark.release();
    if (!endFunction(stream)) return null;
    return .{ .image = try Image.create(options.allocator, .{ .light_dark = .{ light, dark } }) };
}

fn parseCrossFade(options: properties.ParseOptions, stream: *properties.Stream, depth: usize) Allocator.Error!?Value {
    if (!beginFunction(stream)) return null;
    // Blink ConsumeDeprecatedWebkitCrossFade / WebKit consumeWebkitCrossfade:
    // both inputs permit none; number/percentage progress clamps at 0 and 1.
    // Q21: this legacy wrapper permits image-set even inside an image-set.
    const first = (try parseAtDepth(options, stream, .{ .none = true }, depth)) orelse return null;
    defer first.release();
    if (stream.next().token_type != .comma) return null;
    const second = (try parseAtDepth(options, stream, .{ .none = true }, depth)) orelse return null;
    defer second.release();
    if (stream.next().token_type != .comma) return null;
    if (stream.peek().token_type == .function) {
        const value = (try properties.mathValue(options, stream, .{ .kind = .number_percentage, .minimum = 0, .maximum = 1, .minimum_kind = .computation, .maximum_kind = .computation })) orelse return null;
        defer value.release();
        if (!endFunction(stream)) return null;
        return .{ .image = try Image.create(options.allocator, .{ .cross_fade = .{ .inputs = .{ first, second }, .weight = 0, .weight_value = value } }) };
    }
    const token = stream.next();
    if (token.token_type != .number and token.token_type != .percentage) return null;
    const number = token.numeric_value orelse return null;
    if (!std.math.isFinite(number)) return null;
    const weight = std.math.clamp(if (token.token_type == .percentage) number / 100 else number, 0, 1);
    if (!endFunction(stream)) return null;
    return .{ .image = try Image.create(options.allocator, .{ .cross_fade = .{ .inputs = .{ first, second }, .weight = weight } }) };
}
