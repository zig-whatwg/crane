//! Conditional5 §§2–2.1.1: font support queries accept one identifier.
//! This support matrix is separate from Fonts4's @font-face src grammar.
const tokenizer = @import("tokenizer.zig");

pub const Kind = enum { tech, format };

/// The caller has already validated and removed the balanced function block.
/// Blink ConsumeFontTechFn/ConsumeFontFormatFn use the same single-identifier
/// boundary; no engine code is copied.
pub fn evaluate(kind: Kind, argument: []const u8) bool {
    var tokens = tokenizer.Tokenizer.init(argument);
    tokens.skipWhitespace();
    const keyword = tokens.next();
    if (keyword.token_type != .ident) return false;
    tokens.skipWhitespace();
    if (!tokens.next().isEof()) return false;
    return switch (kind) {
        .tech => supportsTech(keyword.value),
        .format => supportsFormat(keyword.value),
    };
}

fn supportsTech(keyword: []const u8) bool {
    // Integrator probes 1023m, 2026-10-23: per-keyword browser majority.
    // COLRv1: C/F; sbix: C/S; SVG: F/S. CBDT: false F/S; graphite:
    // false C/S; all incremental spellings: false 3/3. Others below: 3/3.
    inline for (.{ "features-opentype", "features-aat", "color-colrv0", "color-colrv1", "color-svg", "color-sbix", "variations", "palettes" }) |supported| {
        if (tokenizer.nameEql(keyword, supported)) return true;
    }
    return false;
}

fn supportsFormat(keyword: []const u8) bool {
    // 1023m: these four true 3/3; collection false F/S; SVG false C/F;
    // embedded-opentype false 3/3. Quoted names are never support queries.
    inline for (.{ "opentype", "truetype", "woff", "woff2" }) |supported| {
        if (tokenizer.nameEql(keyword, supported)) return true;
    }
    return false;
}
