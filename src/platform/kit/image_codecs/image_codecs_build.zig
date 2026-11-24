//! The build side of kit/image_codecs (src/platform/kit/kit_build.zig): the
//! testing image codecs - libjpeg-turbo, Expat and NanoSVG under the kit's
//! own jpeg.c and svg.c - built from their pinned sources. Moved whole from
//! the root build.zig (build migration batch P2).
const std = @import("std");
const kit_build = @import("../kit_build.zig");

/// The words that name this part's libraries (kit_build.lint_words).
pub const words = [_][]const u8{ "jpeg", "expat", "nanosvg" };

/// The testing image decoders. Unmodified pinned sources; no tools, test
/// corpus, system JPEG/XML dependency, or build-time interpreter. Scalar JPEG
/// builds on every target, including iOS, without assembler or CPU globals.
pub fn buildImageCodecs(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, sanitize_c: ?std.zig.SanitizeC, prepare: ?kit_build.PrepareC) ?*std.Build.Step.Compile {
    const jpeg = b.lazyDependency("jpeg", .{}) orelse return null;
    const nanosvg = b.lazyDependency("nanosvg", .{}) orelse return null;
    const expat = b.lazyDependency("expat", .{}) orelse return null;
    const headers = b.addWriteFiles();
    _ = headers.add("jconfig.h",
        \\#define JPEG_LIB_VERSION 62
        \\#define LIBJPEG_TURBO_VERSION 3.1.3
        \\#define LIBJPEG_TURBO_VERSION_NUMBER 3001003
        \\#define MEM_SRCDST_SUPPORTED 1
        \\#ifndef BITS_IN_JSAMPLE
        \\#define BITS_IN_JSAMPLE 8
        \\#endif
        \\#define C_ARITH_CODING_SUPPORTED 1
        \\#define D_ARITH_CODING_SUPPORTED 1
        \\
    );
    _ = headers.add("jconfigint.h", b.fmt(
        \\#define BUILD "crane-3.1.3"
        \\#define HIDDEN __attribute__((visibility("hidden")))
        \\#define INLINE inline __attribute__((always_inline))
        \\#define THREAD_LOCAL _Thread_local
        \\#define PACKAGE_NAME "libjpeg-turbo"
        \\#define VERSION "3.1.3"
        \\#define SIZEOF_SIZE_T {d}
        \\#define HAVE_BUILTIN_CTZL 1
        \\#define FALLTHROUGH __attribute__((fallthrough));
        \\#ifndef BITS_IN_JSAMPLE
        \\#define BITS_IN_JSAMPLE 8
        \\#endif
        \\#undef C_ARITH_CODING_SUPPORTED
        \\#undef D_ARITH_CODING_SUPPORTED
        \\#if BITS_IN_JSAMPLE == 8
        \\#define C_ARITH_CODING_SUPPORTED 1
        \\#define D_ARITH_CODING_SUPPORTED 1
        \\#endif
        \\
    , .{target.result.ptrBitWidth() / 8}));
    const jpeg_version = b.addConfigHeader(.{ .style = .{ .cmake = jpeg.path("src/jversion.h.in") }, .include_path = "jversion.h" }, .{ .COPYRIGHT_YEAR = "1991-2025" });
    const jpeg_lib = b.addLibrary(.{ .name = "jpeg", .linkage = .static, .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .sanitize_c = sanitize_c }) });
    jpeg_lib.root_module.addIncludePath(headers.getDirectory());
    jpeg_lib.root_module.addIncludePath(jpeg.path("src"));
    jpeg_lib.root_module.addConfigHeader(jpeg_version);
    // jinclude.h's PUTENV_S calls setenv(), which glibc declares under
    // -std=c11 only with a feature-test macro (setenv is POSIX, not ISO C).
    // libjpeg-turbo's CMake build compiles with the compiler's default GNU
    // dialect, which implies _DEFAULT_SOURCE; ask for it explicitly here.
    // Apple's libc declares setenv unconditionally.
    if (target.result.os.tag == .linux) jpeg_lib.root_module.addCMacro("_DEFAULT_SOURCE", "1");
    jpeg_lib.root_module.addCSourceFiles(.{ .root = jpeg.path("src"), .files = &jpeg_sources, .flags = &.{"-std=c11"} });

    const xml_headers = b.addWriteFiles();
    _ = xml_headers.add("expat_config.h", b.fmt(
        \\#define BYTEORDER {d}
        \\#define XML_CONTEXT_BYTES 1024
        \\#define XML_GE 1
        \\#define XML_NS 1
        \\#define HAVE_STDINT_H 1
        \\#define HAVE_STDLIB_H 1
        \\#define HAVE_STRING_H 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_SYS_TYPES_H 1
        \\#define HAVE_FCNTL_H 1
        \\#define HAVE_{s} 1
        \\
    , .{ if (target.result.cpu.arch.endian() == .little) @as(u16, 1234) else 4321, if (target.result.os.tag == .linux) "GETRANDOM" else "ARC4RANDOM_BUF" }));
    const xml_lib = b.addLibrary(.{ .name = "expat", .linkage = .static, .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .sanitize_c = sanitize_c }) });
    xml_lib.root_module.addIncludePath(xml_headers.getDirectory());
    xml_lib.root_module.addIncludePath(expat.path("expat/lib"));
    xml_lib.root_module.addCMacro("XML_STATIC", "1");
    xml_lib.root_module.addCSourceFiles(.{ .root = expat.path("expat/lib"), .files = &.{ "xcs.c", "xmlparse.c", "xmlrole.c", "xmltok.c", if (target.result.os.tag == .linux) "random_getrandom.c" else "random_arc4random_buf.c" }, .flags = &.{"-std=c11"} });

    const lib = b.addLibrary(.{ .name = "crane_image_codecs", .linkage = .static, .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .sanitize_c = sanitize_c }) });
    lib.root_module.addIncludePath(headers.getDirectory());
    lib.root_module.addIncludePath(jpeg.path("src"));
    lib.root_module.addIncludePath(expat.path("expat/lib"));
    lib.root_module.addIncludePath(nanosvg.path("src"));
    lib.root_module.addCMacro("XML_STATIC", "1");
    lib.root_module.addCSourceFiles(.{ .root = b.path("src/platform/kit/image_codecs"), .files = &.{ "jpeg.c", "svg.c" }, .flags = &.{"-std=c11"} });
    lib.root_module.linkLibrary(jpeg_lib);
    lib.root_module.linkLibrary(xml_lib);
    if (target.result.os.tag == .linux) lib.root_module.linkSystemLibrary("m", .{});
    lib.installHeader(b.path("src/platform/kit/image_codecs/image_codecs.h"), "image_codecs.h");
    if (prepare) |p| for ([_]*std.Build.Step.Compile{ jpeg_lib, xml_lib, lib }) |part| p.module(part.root_module);
    return lib;
}

// libjpeg-turbo 3.1.3 CMakeLists.txt JPEG_SOURCES, including all sample precisions.
const jpeg_sources = [_][]const u8{
    "jcapimin.c",
    "wrapper/jcapistd-8.c",
    "wrapper/jcapistd-12.c",
    "wrapper/jcapistd-16.c",
    "wrapper/jccoefct-8.c",
    "wrapper/jccoefct-12.c",
    "wrapper/jccolor-8.c",
    "wrapper/jccolor-12.c",
    "wrapper/jccolor-16.c",
    "wrapper/jcdctmgr-8.c",
    "wrapper/jcdctmgr-12.c",
    "wrapper/jcdiffct-8.c",
    "wrapper/jcdiffct-12.c",
    "wrapper/jcdiffct-16.c",
    "jchuff.c",
    "jcicc.c",
    "jcinit.c",
    "jclhuff.c",
    "wrapper/jclossls-8.c",
    "wrapper/jclossls-12.c",
    "wrapper/jclossls-16.c",
    "wrapper/jcmainct-8.c",
    "wrapper/jcmainct-12.c",
    "wrapper/jcmainct-16.c",
    "jcmarker.c",
    "jcmaster.c",
    "jcomapi.c",
    "jcparam.c",
    "jcphuff.c",
    "wrapper/jcprepct-8.c",
    "wrapper/jcprepct-12.c",
    "wrapper/jcprepct-16.c",
    "wrapper/jcsample-8.c",
    "wrapper/jcsample-12.c",
    "wrapper/jcsample-16.c",
    "jctrans.c",
    "jdapimin.c",
    "wrapper/jdapistd-8.c",
    "wrapper/jdapistd-12.c",
    "wrapper/jdapistd-16.c",
    "jdatadst.c",
    "jdatasrc.c",
    "wrapper/jdcoefct-8.c",
    "wrapper/jdcoefct-12.c",
    "wrapper/jdcolor-8.c",
    "wrapper/jdcolor-12.c",
    "wrapper/jdcolor-16.c",
    "wrapper/jddctmgr-8.c",
    "wrapper/jddctmgr-12.c",
    "wrapper/jddiffct-8.c",
    "wrapper/jddiffct-12.c",
    "wrapper/jddiffct-16.c",
    "jdhuff.c",
    "jdicc.c",
    "jdinput.c",
    "jdlhuff.c",
    "wrapper/jdlossls-8.c",
    "wrapper/jdlossls-12.c",
    "wrapper/jdlossls-16.c",
    "wrapper/jdmainct-8.c",
    "wrapper/jdmainct-12.c",
    "wrapper/jdmainct-16.c",
    "jdmarker.c",
    "jdmaster.c",
    "wrapper/jdmerge-8.c",
    "wrapper/jdmerge-12.c",
    "jdphuff.c",
    "wrapper/jdpostct-8.c",
    "wrapper/jdpostct-12.c",
    "wrapper/jdpostct-16.c",
    "wrapper/jdsample-8.c",
    "wrapper/jdsample-12.c",
    "wrapper/jdsample-16.c",
    "jdtrans.c",
    "jerror.c",
    "jfdctflt.c",
    "wrapper/jfdctfst-8.c",
    "wrapper/jfdctfst-12.c",
    "wrapper/jfdctint-8.c",
    "wrapper/jfdctint-12.c",
    "wrapper/jidctflt-8.c",
    "wrapper/jidctflt-12.c",
    "wrapper/jidctfst-8.c",
    "wrapper/jidctfst-12.c",
    "wrapper/jidctint-8.c",
    "wrapper/jidctint-12.c",
    "wrapper/jidctred-8.c",
    "wrapper/jidctred-12.c",
    "jmemmgr.c",
    "jmemnobs.c",
    "jpeg_nbits.c",
    "wrapper/jquant1-8.c",
    "wrapper/jquant1-12.c",
    "wrapper/jquant2-8.c",
    "wrapper/jquant2-12.c",
    "wrapper/jutils-8.c",
    "wrapper/jutils-12.c",
    "wrapper/jutils-16.c",
    "jaricom.c",
    "jcarith.c",
    "jdarith.c",
};
