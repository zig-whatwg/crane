//! CSS Values 4 §4.5: immutable source data travels with each URL value.
//! Gecko URLExtraData and Blink CSSUrlData keep this separate from CSS text.
//! This layer owns strings and counted records, never a sheet, DOM or realm.
const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;

pub const ResourceSource = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    base_url: []const u8,
    /// null means the request's client/document.
    referrer: ?[]const u8,
    /// Canonical Referrer Policy spelling; empty means the client default.
    referrer_policy: []const u8,
    origin_clean: bool,

    pub const Descriptor = struct {
        base_url: []const u8,
        referrer: ?[]const u8 = null,
        referrer_policy: []const u8 = "",
        origin_clean: bool = true,
    };

    /// One owned reference. Callers can share it across a sheet's values;
    /// non-resource declarations never construct a source themselves.
    pub fn create(allocator: Allocator, descriptor: Descriptor) Allocator.Error!*ResourceSource {
        const result = try allocator.create(ResourceSource);
        errdefer allocator.destroy(result);
        const base = try allocator.dupe(u8, descriptor.base_url);
        errdefer allocator.free(base);
        const referrer = if (descriptor.referrer) |r| try allocator.dupe(u8, r) else null;
        errdefer if (referrer) |r| allocator.free(r);
        const policy = try allocator.dupe(u8, descriptor.referrer_policy);
        result.* = .{ .allocator = allocator, .base_url = base, .referrer = referrer, .referrer_policy = policy, .origin_clean = descriptor.origin_clean };
        return result;
    }

    pub fn ref(self: *ResourceSource) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *ResourceSource) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        const allocator = self.allocator;
        allocator.free(self.base_url);
        if (self.referrer) |r| allocator.free(r);
        allocator.free(self.referrer_policy);
        allocator.destroy(self);
    }

    pub fn eql(a: *const ResourceSource, b: *const ResourceSource) bool {
        if (a == b) return true;
        if (a.origin_clean != b.origin_clean or (a.referrer == null) != (b.referrer == null)) return false;
        return std.mem.eql(u8, a.base_url, b.base_url) and
            std.mem.eql(u8, a.referrer_policy, b.referrer_policy) and
            (a.referrer == null or std.mem.eql(u8, a.referrer.?, b.referrer.?));
    }
};

pub const ResourceUrl = struct {
    /// Resolved when a resolver was supplied; decoded input otherwise.
    /// Empty input stays empty even if the resolver returns the base URL.
    url: []const u8,
    /// Values 4 §4.5.1.1: set from the decoded ORIGINAL value, not its base.
    local_fragment: bool,
    /// Empty URLs and explicit resolution failures never initiate requests.
    valid: bool,
    source: ?*ResourceSource,
    /// Half-open range of the URL component in the owning value's CSS text.
    /// For image-set's URL strings, this includes the quotes.
    range: Range,
    /// A quoted URL argument or image-set string, including its quotes.
    /// Replacing only this span preserves URL modifiers and the wrapper.
    argument_range: ?Range = null,

    pub const Range = struct { start: usize, end: usize };

    /// Borrowed descriptor: clone it before retaining it past the parse.
    pub fn describe(raw: []const u8, resolved: ?[]const u8, had_resolver: bool, source: ?*ResourceSource, range: Range) ResourceUrl {
        return .{
            .url = if (raw.len == 0) "" else resolved orelse raw,
            .local_fragment = std.mem.startsWith(u8, raw, "#"),
            .valid = raw.len != 0 and (!had_resolver or resolved != null),
            .source = source,
            .range = range,
        };
    }

    pub fn clone(self: ResourceUrl, allocator: Allocator, offset: usize) Allocator.Error!ResourceUrl {
        var result = self;
        result.url = try allocator.dupe(u8, self.url);
        if (self.source) |s| s.ref();
        result.range.start += offset;
        result.range.end += offset;
        if (result.argument_range) |*argument| {
            argument.start += offset;
            argument.end += offset;
        }
        return result;
    }

    pub fn deinit(self: ResourceUrl, allocator: Allocator) void {
        if (self.source) |s| s.unref();
        allocator.free(self.url);
    }

    pub fn eql(a: ResourceUrl, b: ResourceUrl) bool {
        if (a.local_fragment != b.local_fragment or a.valid != b.valid or
            a.range.start != b.range.start or a.range.end != b.range.end or
            !std.mem.eql(u8, a.url, b.url)) return false;
        if (!std.meta.eql(a.argument_range, b.argument_range)) return false;
        if (a.source) |s| return if (b.source) |other| s.eql(other) else false;
        return b.source == null;
    }
};

pub const UrlResolver = struct {
    context: *const anyopaque,
    resolve: *const fn (*const anyopaque, Allocator, []const u8) ?[]u8,
};

pub fn releaseAll(allocator: Allocator, urls: []const ResourceUrl) void {
    for (urls) |url| url.deinit(allocator);
    allocator.free(urls);
}

pub fn cloneAll(allocator: Allocator, urls: []const ResourceUrl, offset: usize) Allocator.Error![]ResourceUrl {
    if (urls.len == 0) return &.{};
    const result = try allocator.alloc(ResourceUrl, urls.len);
    errdefer allocator.free(result);
    var count: usize = 0;
    errdefer for (result[0..count]) |url| url.deinit(allocator);
    for (urls, result) |url, *copy| {
        copy.* = try url.clone(allocator, offset);
        count += 1;
    }
    return result;
}

pub fn eql(a: []const ResourceUrl, b: []const ResourceUrl) bool {
    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    for (a, b) |left, right| if (!left.eql(right)) return false;
    return true;
}

/// An owned list while joining shorthand layers or generated-content items.
pub const Builder = struct {
    allocator: Allocator,
    urls: std.ArrayList(ResourceUrl) = .empty,

    pub fn deinit(self: *Builder) void {
        for (self.urls.items) |url| url.deinit(self.allocator);
        self.urls.deinit(self.allocator);
    }

    pub fn append(self: *Builder, urls: []const ResourceUrl, offset: usize) Allocator.Error!void {
        try self.urls.ensureUnusedCapacity(self.allocator, urls.len);
        for (urls) |url| self.urls.appendAssumeCapacity(try url.clone(self.allocator, offset));
    }

    pub fn take(self: *Builder) Allocator.Error![]ResourceUrl {
        return self.urls.toOwnedSlice(self.allocator);
    }
};

/// Collect URL candidates only after a resource-bearing grammar accepted
/// the value. CSS text is untouched. This is token-based, so comments, CSS
/// escapes, quoted text and type("image/png") never become spurious URLs.
/// The consumer selects candidates using their ranges; this does not fetch.
pub fn collect(allocator: Allocator, text: []const u8, resolver: ?UrlResolver, source: ?*ResourceSource) Allocator.Error![]ResourceUrl {
    var out = Builder{ .allocator = allocator };
    defer out.deinit();
    var image_sets: std.ArrayList(usize) = .empty;
    defer image_sets.deinit(allocator);
    var depth: usize = 0;
    var pending_image_set = false;
    var tok = tokenizer.Tokenizer.init(text);
    while (true) {
        tok.skipWhitespace();
        const begin = tok.pos;
        const token = tok.next();
        switch (token.token_type) {
            .eof => break,
            .url => try appendToken(&out, token.value, .{ .start = begin, .end = tok.pos }, null, resolver, source),
            .function => {
                pending_image_set = tokenizer.nameEql(token.value, "image-set") or tokenizer.nameEql(token.value, "-webkit-image-set");
                if (tokenizer.nameEql(token.value, "url") or tokenizer.nameEql(token.value, "src")) {
                    var url_tokens = tok;
                    if (url_tokens.next().token_type != .left_paren) continue;
                    url_tokens.skipWhitespace();
                    const argument_start = url_tokens.pos;
                    const string = url_tokens.next();
                    if (string.token_type != .string) continue;
                    const argument_end = url_tokens.pos;
                    // Values 4 §4.5.3 permits URL modifiers after the string.
                    // Preserve their spelling and include them in the range.
                    var nesting: usize = 1;
                    while (nesting > 0) {
                        switch (url_tokens.next().token_type) {
                            .eof => break,
                            .left_paren => nesting += 1,
                            .right_paren => nesting -= 1,
                            else => {},
                        }
                    }
                    try appendToken(&out, string.stringContents(), .{ .start = begin, .end = url_tokens.pos }, .{ .start = argument_start, .end = argument_end }, resolver, source);
                    tok = url_tokens;
                }
            },
            .left_paren => {
                depth += 1;
                if (pending_image_set) try image_sets.append(allocator, depth);
                pending_image_set = false;
            },
            .right_paren => {
                if (image_sets.items.len > 0 and image_sets.items[image_sets.items.len - 1] == depth) _ = image_sets.pop();
                depth -|= 1;
            },
            // Images 4 §2.4: a top-level string option is a URL; a string
            // inside type(), gradients or other functions is not.
            .string => if (image_sets.items.len > 0 and image_sets.items[image_sets.items.len - 1] == depth) {
                const range: ResourceUrl.Range = .{ .start = begin, .end = tok.pos };
                try appendToken(&out, token.stringContents(), range, range, resolver, source);
            },
            else => {},
        }
    }
    return out.take();
}

fn appendToken(out: *Builder, encoded: []const u8, range: ResourceUrl.Range, argument_range: ?ResourceUrl.Range, resolver: ?UrlResolver, source: ?*ResourceSource) Allocator.Error!void {
    const raw = try tokenizer.decode(out.allocator, encoded);
    defer out.allocator.free(raw);
    const resolved = if (resolver) |r| r.resolve(r.context, out.allocator, raw) else null;
    defer if (resolved) |r| out.allocator.free(r);
    var url = ResourceUrl.describe(raw, resolved, resolver != null, source, range);
    url.argument_range = argument_range;
    try out.append(&.{url}, 0);
}
