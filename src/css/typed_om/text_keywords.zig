//! Integrator Q59: cold inspection of native canonical SharedText for the
//! explicitly listed properties, using the existing tokenizer only.
const std = @import("std");
const tokens = @import("../tokenizer.zig");
const properties = @import("../properties.zig");
const Allocator = std.mem.Allocator;

// This exception must remain off parsing/computation paths. Pin the direct
// import boundary for every producer and the two style consumers.
comptime {
    @setEvalBranchQuota(2_000_000);
    for (.{
        @embedFile("../cascade.zig"),
        @embedFile("../computed_style.zig"),
        @embedFile("../properties.zig"),
        @embedFile("../font_variants.zig"),
        @embedFile("../font_shorthand.zig"),
        @embedFile("../font_settings.zig"),
        @embedFile("../decoration_values.zig"),
    }) |source| {
        if (std.mem.indexOf(u8, source, "typed_om/text_keywords.zig") != null or std.mem.indexOf(u8, source, "typed_om.text_keywords") != null)
            @compileError("Typed OM canonical-text inspection must remain off the CSS parsing/computation path");
    }
}

pub const Keywords = struct {
    allocator: Allocator,
    items: [][]u8,
    pub fn deinit(self: *Keywords) void {
        for (self.items) |item| self.allocator.free(item);
        self.allocator.free(self.items);
    }
};

fn next(tokenizer: *tokens.Tokenizer) tokens.Token {
    while (true) {
        const token = tokenizer.next();
        if (token.token_type != .whitespace) return token;
    }
}

pub fn classify(allocator: Allocator, longhand: properties.Longhand, canonical: []const u8) Allocator.Error!?Keywords {
    // Q59's closed allowlist. A new text-backed property needs a ruling.
    switch (longhand) {
        .anchor_name,
        .anchor_scope,
        .position_anchor,
        .font_variant_ligatures,
        .font_variant_caps,
        .font_variant_alternates,
        .font_variant_numeric,
        .font_variant_east_asian,
        .font_variant_position,
        .font_variant_emoji,
        .font_language_override,
        .text_emphasis_style,
        .color_scheme,
        .page, // Q86's named fifth custom-name exception; singleton only.
        => {},
        else => return null,
    }
    var tokenizer = tokens.Tokenizer.init(canonical);
    var items: std.ArrayList([]u8) = .empty;
    defer {
        for (items.items) |item| allocator.free(item);
        items.deinit(allocator);
    }
    while (true) {
        const token = next(&tokenizer);
        if (token.token_type != .ident) return null;
        const decoded = try tokens.decode(allocator, token.value);
        items.append(allocator, decoded) catch |err| {
            allocator.free(decoded);
            return err;
        };
        const after = next(&tokenizer);
        if (after.token_type == .eof) return .{ .allocator = allocator, .items = try items.toOwnedSlice(allocator) };
        return null; // Q69/Q59 correction: every named property is singleton-only.
    }
}
