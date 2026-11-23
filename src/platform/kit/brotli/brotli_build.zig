//! The build side of kit/brotli (src/platform/kit/kit_build.zig): Brotli,
//! the RFC 7932 codec, built from Google's pinned sources. Moved whole from
//! the root build.zig (build migration batch P2).
const std = @import("std");
const kit_build = @import("../kit_build.zig");

/// The words that name this part's libraries (kit_build.lint_words).
pub const words = [_][]const u8{"brotli"};

/// Google's pinned RFC 7932 implementation, following upstream CMake's three
/// library source sets. Only the C codec is built, for the requested target.
pub const BrotliLibraries = struct { common: *std.Build.Step.Compile, decoder: *std.Build.Step.Compile, encoder: *std.Build.Step.Compile };
pub fn buildBrotli(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, sanitize_c: ?std.zig.SanitizeC, prepare: ?kit_build.PrepareC) ?BrotliLibraries {
    const upstream = b.lazyDependency("brotli", .{}) orelse return null;
    var libs: [3]*std.Build.Step.Compile = undefined;
    const groups = .{ .{ "common", &brotli_common_sources }, .{ "dec", &brotli_dec_sources }, .{ "enc", &brotli_enc_sources } };
    inline for (groups, 0..) |group, i| {
        const lib = b.addLibrary(.{
            .name = "brotli" ++ group[0],
            .linkage = .static,
            .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true }),
        });
        if (sanitize_c) |sanitizer| lib.root_module.sanitize_c = sanitizer;
        lib.root_module.addIncludePath(upstream.path("c/include"));
        lib.root_module.addCSourceFiles(.{ .root = upstream.path("c"), .files = group[1], .flags = &.{"-std=c99"} });
        lib.installHeadersDirectory(upstream.path("c/include/brotli"), "brotli", .{});
        if (prepare) |p| p.module(lib.root_module);
        libs[i] = lib;
    }
    libs[1].root_module.linkLibrary(libs[0]);
    // The upstream default calls exit() on OOM; embedders must unwind instead.
    libs[2].root_module.addCMacro("BROTLI_ENCODER_CLEANUP_ON_OOM", "1");
    libs[2].root_module.linkLibrary(libs[0]);
    return .{ .common = libs[0], .decoder = libs[1], .encoder = libs[2] };
}

const brotli_common_sources = [_][]const u8{
    "common/constants.c",
    "common/context.c",
    "common/dictionary.c",
    "common/platform.c",
    "common/shared_dictionary.c",
    "common/transform.c",
};

const brotli_dec_sources = [_][]const u8{
    "dec/bit_reader.c",
    "dec/decode.c",
    "dec/huffman.c",
    "dec/prefix.c",
    "dec/state.c",
    "dec/static_init.c",
};

const brotli_enc_sources = [_][]const u8{
    "enc/backward_references.c",
    "enc/backward_references_hq.c",
    "enc/bit_cost.c",
    "enc/block_splitter.c",
    "enc/brotli_bit_stream.c",
    "enc/cluster.c",
    "enc/command.c",
    "enc/compound_dictionary.c",
    "enc/compress_fragment.c",
    "enc/compress_fragment_two_pass.c",
    "enc/dictionary_hash.c",
    "enc/encode.c",
    "enc/encoder_dict.c",
    "enc/entropy_encode.c",
    "enc/fast_log.c",
    "enc/histogram.c",
    "enc/literal_cost.c",
    "enc/memory.c",
    "enc/metablock.c",
    "enc/static_dict.c",
    "enc/static_dict_lut.c",
    "enc/static_init.c",
    "enc/utf8_util.c",
};
