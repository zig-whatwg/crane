const std = @import("std");

const V8Link = enum { static, dynamic };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const v8_dir = b.option([]const u8, "v8-dir", "Path to extracted V8 archive directory");
    const v8_link = b.option(V8Link, "v8-link", "V8 link mode: static (default) or dynamic") orelse .static;

    const crane = b.dependency("crane", .{
        .target = target,
        .optimize = optimize,
        .@"v8-dir" = v8_dir orelse "",
        .@"v8-link" = v8_link,
    });

    // 1. High-level Zig API consumer (`@import("crane")`).
    const zig_exe = b.addExecutable(.{
        .name = "zig-consumer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    zig_exe.root_module.addImport("crane", crane.module("crane"));
    b.installArtifact(zig_exe);

    const run_zig = b.addRunArtifact(zig_exe);
    b.step("run-zig", "Run the Zig module sample consumer").dependOn(&run_zig.step);

    // 2. C ABI static library consumer (`libcrane.a` + `include/crane.h`).
    const capi_exe = b.addExecutable(.{
        .name = "capi-consumer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/capi_main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    capi_exe.root_module.addImport("crane_c", crane.module("crane-c"));
    capi_exe.root_module.linkLibrary(crane.artifact("crane"));
    b.installArtifact(capi_exe);

    const run_capi = b.addRunArtifact(capi_exe);
    b.step("run-capi", "Run the C ABI static library sample consumer").dependOn(&run_capi.step);
}
