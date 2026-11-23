//! HTML 4.8.4.3 "Images": parsing a srcset attribute, parsing a sizes
//! attribute and selecting an image source from a source set - the img
//! element's ("update the image data"), and the speculative HTML parser's
//! for a speculative img (13.2.8: "the URL that element would fetch if it
//! was processed normally"), so both pick the same candidate.
//!
//! Moved unchanged from src/webidl/impls/HTMLImageElement.zig (lane pscan1):
//! a helper two callers share lives outside src/webidl/impls/ (the impls
//! boundary), and takes the allocator the element's context gave it.
//!
//! Spec: https://html.spec.whatwg.org/multipage/images.html#parse-a-srcset-attribute
//! Spec: https://html.spec.whatwg.org/multipage/images.html#parse-a-sizes-attribute
//! Spec: https://html.spec.whatwg.org/multipage/images.html#select-an-image-source

const std = @import("std");
const platform = @import("platform");
const dom = @import("dom");

/// HTML 4.8.4.3.10, "parse a srcset attribute". The iterator borrows its
/// input and does not allocate: each candidate is used during this update,
/// before a URL is copied into the existing image request.
pub const Srcset = struct {
    input: []const u8,
    position: usize = 0,

    pub const Candidate = struct {
        url: []const u8,
        width: ?f64 = null,
        density: ?f64 = null,
        height: ?f64 = null,
        invalid: bool = false,

        fn descriptor(self: *Candidate, text: []const u8) void {
            if (text.len < 2) {
                self.invalid = true;
                return;
            }
            const number = text[0 .. text.len - 1];
            switch (text[text.len - 1]) {
                'w', 'h' => |unit| {
                    var value: f64 = 0;
                    for (number) |c| {
                        if (!std.ascii.isDigit(c)) {
                            self.invalid = true;
                            return;
                        }
                        value = @min(value * 10 + @as(f64, @floatFromInt(c - '0')), std.math.floatMax(f64));
                    }
                    if (value == 0 or self.density != null or (if (unit == 'w') self.width != null else self.height != null)) {
                        self.invalid = true;
                        return;
                    }
                    if (unit == 'w') self.width = value else self.height = value;
                },
                'x' => {
                    if (self.width != null or self.height != null or self.density != null or !validFloat(number)) {
                        self.invalid = true;
                        return;
                    }
                    const value = std.fmt.parseFloat(f64, number) catch {
                        self.invalid = true;
                        return;
                    };
                    if (value < 0 or !std.math.isFinite(value)) self.invalid = true else self.density = if (value == 0) 0 else value;
                },
                else => self.invalid = true,
            }
        }
    };

    fn whitespace(c: u8) bool {
        return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '\x0c';
    }

    /// HTML "valid floating-point number", not the permissive prefix
    /// parser: no leading plus, no trailing dot, and a nonempty exponent.
    fn validFloat(text: []const u8) bool {
        var p: usize = 0;
        if (p < text.len and text[p] == '-') p += 1;
        const integer_start = p;
        while (p < text.len and std.ascii.isDigit(text[p])) : (p += 1) {}
        const integer_digits = p - integer_start;
        if (p < text.len and text[p] == '.') {
            p += 1;
            const fraction_start = p;
            while (p < text.len and std.ascii.isDigit(text[p])) : (p += 1) {}
            if (p == fraction_start) return false;
        } else if (integer_digits == 0) return false;
        if (p < text.len and (text[p] == 'e' or text[p] == 'E')) {
            p += 1;
            if (p < text.len and (text[p] == '+' or text[p] == '-')) p += 1;
            const exponent_start = p;
            while (p < text.len and std.ascii.isDigit(text[p])) : (p += 1) {}
            if (p == exponent_start) return false;
        }
        return p == text.len;
    }

    pub fn next(self: *Srcset) ?Candidate {
        while (true) {
            // Steps 4–6: commas delimit candidates only after the URL.
            while (self.position < self.input.len and (whitespace(self.input[self.position]) or self.input[self.position] == ',')) : (self.position += 1) {}
            if (self.position == self.input.len) return null;
            const start = self.position;
            while (self.position < self.input.len and !whitespace(self.input[self.position])) : (self.position += 1) {}
            var candidate: Candidate = .{ .url = self.input[start..self.position] };
            if (candidate.url[candidate.url.len - 1] == ',') {
                candidate.url = std.mem.trimEnd(u8, candidate.url, ",");
            } else {
                // Step 8: descriptor, after-descriptor and in-parens
                // states; a comma inside parentheses is not a separator.
                while (self.position < self.input.len) {
                    while (self.position < self.input.len and whitespace(self.input[self.position])) : (self.position += 1) {}
                    const descriptor_start = self.position;
                    var in_parens = false;
                    while (self.position < self.input.len) : (self.position += 1) {
                        const c = self.input[self.position];
                        if (in_parens) {
                            if (c == ')') in_parens = false;
                        } else {
                            if (whitespace(c) or c == ',') break;
                            if (c == '(') in_parens = true;
                        }
                    }
                    if (self.position > descriptor_start) candidate.descriptor(self.input[descriptor_start..self.position]);
                    if (self.position < self.input.len and self.input[self.position] == ',') {
                        self.position += 1;
                        break;
                    }
                }
            }
            // Steps 14–15: a future-compatible h descriptor requires w.
            if (!candidate.invalid and (candidate.height == null or candidate.width != null)) return candidate;
        }
    }
};

pub const ImageSource = struct { url: []const u8, density: f64 };

pub fn sourceTypeSupported(allocator: std.mem.Allocator, text: []const u8) bool {
    // Empty/whitespace type means no restriction (all browsers and WPT
    // update-the-source-set.html). Parameters do not affect decoder support.
    if (std.mem.trim(u8, text, " \t\n\r\x0c").len == 0) return true;
    if (platform.capabilities.image_decoding == .unsupported) return false;
    var scratch_buffer: [2048]u8 = undefined;
    var scratch: std.heap.BufferFirstAllocator = .init(&scratch_buffer, allocator);
    const temporary = scratch.allocator();
    var mime = (@import("mimesniff").mime_type.parseMimeType(temporary, text) catch return false) orelse return false;
    defer mime.deinit();
    const essence = temporary.alloc(u8, mime.type.len + 1 + mime.subtype.len) catch return false;
    defer temporary.free(essence);
    for (mime.type, essence[0..mime.type.len]) |unit, *byte| byte.* = @intCast(unit);
    essence[mime.type.len] = '/';
    for (mime.subtype, essence[mime.type.len + 1 ..]) |unit, *byte| byte.* = @intCast(unit);
    return platform.imageMimeTypeSupported(.from(essence));
}

/// 4.8.4.3.8/12: normalize and select from one element's attributes.
pub fn selectFromAttributes(allocator: std.mem.Allocator, default_source: []const u8, srcset: []const u8, sizes: []const u8, environment: dom.style.css.media_queries.MediaValues) ?ImageSource {
    var candidates: Srcset = .{ .input = srcset };
    var chosen: ?ImageSource = null;
    var width_seen = false;
    var density_one_seen = false;
    var size: ?f64 = null;
    while (candidates.next()) |candidate| {
        width_seen = width_seen or candidate.width != null;
        density_one_seen = density_one_seen or candidate.density == 1;
        const density = candidate.density orelse if (candidate.width) |width| blk: {
            if (size == null) size = sourceSize(allocator, sizes, environment);
            break :blk width / size.?;
        } else 1;
        considerSource(&chosen, .{ .url = candidate.url, .density = density }, environment.resolution);
    }
    if (!width_seen and !density_one_seen and default_source.len > 0) {
        considerSource(&chosen, .{ .url = default_source, .density = 1 }, environment.resolution);
    }
    return chosen;
}

fn considerSource(chosen: *?ImageSource, candidate: ImageSource, resolution: f64) void {
    const current = chosen.* orelse {
        chosen.* = candidate;
        return;
    };
    if (current.density < resolution) {
        if (candidate.density > current.density) chosen.* = candidate;
    } else if (candidate.density >= resolution and candidate.density < current.density) chosen.* = candidate;
}

/// HTML 4.8.4.3.11. Component values, rather than splitting on commas or
/// spaces, preserve functions, media conditions, comments and escapes.
/// `text` belongs to the selected source, or to the img's own fallback set.
fn sourceSize(allocator: std.mem.Allocator, text: []const u8, environment: dom.style.css.media_queries.MediaValues) f64 {
    const css = dom.style.css;
    var tokenizer = css.tokenizer.Tokenizer.init(text);
    var item_start: usize = 0;
    var last_start: usize = 0;
    var last_end: usize = 0;
    while (true) {
        const token = tokenizer.next();
        if (token.token_type == .whitespace) continue;
        if (token.token_type == .comma or token.token_type == .eof) {
            if (last_end > item_start) {
                if (sourceSizeValue(allocator, text[last_start..last_end], environment)) |size| {
                    const condition = std.mem.trim(u8, text[item_start..last_start], " \t\n\r\x0c");
                    if (condition.len == 0) return size;
                    var condition_tokens = css.tokenizer.Tokenizer.init(condition);
                    condition_tokens.skipWhitespace();
                    const first = condition_tokens.next();
                    if (first.token_type == .eof) return size; // comments only
                    var query = css.media_queries.MediaQueryList.parse(allocator, condition) catch return environment.width;
                    defer query.deinit();
                    // sizes accepts a media CONDITION, not a media type.
                    if (query.queries.len == 1 and query.queries[0].media_type == null and query.matches(&environment)) return size;
                }
            }
            if (token.token_type == .eof) return environment.width;
            item_start = tokenizer.pos;
            last_end = item_start;
            continue;
        }
        last_start = @intFromPtr(token.value.ptr) - @intFromPtr(text.ptr);
        // The tokenizer exposes function and '(' separately. Consume the
        // complete CSS block as one component, including its EOF closure.
        if (token.token_type == .function) _ = tokenizer.next();
        if (token.token_type == .function or token.token_type == .left_paren or token.token_type == .left_bracket or token.token_type == .left_brace) {
            var depth: usize = 1;
            while (depth > 0) {
                const nested = tokenizer.next();
                switch (nested.token_type) {
                    .left_paren, .left_bracket, .left_brace => depth += 1,
                    .right_paren, .right_bracket, .right_brace => depth -= 1,
                    .eof => break,
                    else => {},
                }
            }
        }
        last_end = tokenizer.pos;
    }
}

fn sourceSizeValue(allocator: std.mem.Allocator, text: []const u8, environment: dom.style.css.media_queries.MediaValues) ?f64 {
    const css = dom.style.css;
    var tokenizer = css.tokenizer.Tokenizer.init(text);
    const token = tokenizer.next();
    if (token.isIdent("auto")) {
        // Step 3.3: no concrete rendered object size in the headless media
        // environment. Ignore auto and try the following size.
        return null;
    }
    if (token.token_type == .function) {
        // HTML 4.8.4.3.11 step 3.2: only CSS math functions, yielding a
        // non-negative length. The existing grammar rejects other functions.
        var divided_by_zero = false;
        const parsed = (css.math_values.parseWithDivisionCheck(allocator, text, .{ .kind = .length, .minimum = 0 }, &divided_by_zero) catch return null) orelse return null;
        defer parsed.expression.unref();
        if (parsed.consumed != text.len) return null;
        // Sizes has the initial font and viewport, not an element's style,
        // line-height metrics, sibling counts or a random-value provider.
        // Preflight those inputs before compute; never invent them.
        if (parsed.expression.needsUnavailableMetrics(false) or parsed.expression.needsLineHeight() or
            parsed.expression.needsTreeCounts() or parsed.expression.needsRandomBase()) return null;
        const computed = parsed.expression.computeWithDivisionCheck(allocator, .{
            .font_size = environment.font_size,
            .root_font_size = environment.font_size,
            .viewport_width = environment.width,
            .viewport_height = environment.height,
        }, &divided_by_zero) catch return null;
        defer computed.unref();
        // Browser probes Q31/Q39-Q41 (2026-10-27, C156/F158/S27):
        // C/S reject zero division anywhere and nonfinite keyword results,
        // unlike CSS Values 4's unconditional outer normalization. F/S use
        // finite keyword branches; C/F normalize numeric overflow (inf to
        // the largest size, overflow NaN to zero). All clamp finite negative
        // math to zero. Inspect those distinctions before computedNumber.
        if (divided_by_zero) return null;
        const raw = computed.knownNumber() orelse return null;
        if (raw.unit != .px) return null;
        if (!std.math.isFinite(raw.value)) {
            // The evaluator has folded away keyword provenance. Reuse the
            // CSS tokenizer's decoded identifier comparison, including escapes.
            while (true) {
                const keyword = tokenizer.next();
                if (keyword.token_type == .eof) break;
                if (keyword.token_type != .ident) continue;
                if (css.tokenizer.nameEql(keyword.value, "infinity") or
                    css.tokenizer.nameEql(keyword.value, "-infinity") or
                    css.tokenizer.nameEql(keyword.value, "nan")) return null;
            }
        }
        const number = computed.computedNumber() orelse return null;
        return number.value;
    }
    const value = token.numeric_value orelse return null;
    if (value < 0) return null;
    if (token.token_type == .number) return if (value == 0) 0 else null;
    if (token.token_type != .dimension) return null;
    const unit_text = token.unit orelse return null;
    const unit_decoded = css.tokenizer.decode(allocator, unit_text) catch return null;
    defer allocator.free(unit_decoded);
    // As in the media-query evaluator, there are no dynamic toolbars:
    // small, large and dynamic viewport lengths share this viewport.
    const viewport_variant = unit_decoded.len > 2 and
        (std.ascii.toLower(unit_decoded[0]) == 's' or std.ascii.toLower(unit_decoded[0]) == 'l' or std.ascii.toLower(unit_decoded[0]) == 'd') and
        std.ascii.toLower(unit_decoded[1]) == 'v';
    const unit = css.LengthUnit.fromString(if (viewport_variant) unit_decoded[1..] else unit_decoded) orelse return null;
    // Relative units use the media environment's initial font metrics and
    // viewport, as sizes and media queries require, never element styles.
    const factor: f64 = switch (unit) {
        .px => 1,
        .cm => 96.0 / 2.54,
        .mm => 96.0 / 25.4,
        .in => 96,
        .pt => 96.0 / 72.0,
        .pc => 16,
        .Q => 96.0 / 101.6,
        .em, .rem => environment.font_size,
        .ex, .ch => environment.font_size / 2,
        .lh, .rlh => return null, // the media environment has no line-height metric
        .vw, .vi => environment.width / 100,
        .vh, .vb => environment.height / 100,
        .vmin => @min(environment.width, environment.height) / 100,
        .vmax => @max(environment.width, environment.height) / 100,
        .percent => return null,
    };
    // Q39: all three browsers saturate plain lengths, including a numeric
    // token that already overflowed, at the px conversion boundary.
    return std.math.clamp(value * factor, 0, std.math.floatMax(f64));
}
