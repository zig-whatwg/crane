const std = @import("std");

/// Helper function to add all .zig test files from a directory
fn addTestFilesFromDir(
    builder: *std.Build,
    step: *std.Build.Step,
    dir_path: []const u8,
    target: std.Build.ResolvedTarget,
    modules: []const std.Build.Module.Import,
    link_v8: bool,
) !void {
    const allocator = builder.allocator;
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
        // Directory might not exist yet, skip silently
        if (err == error.FileNotFound) return;
        return err;
    };
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, "_test.zig")) continue;

        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.path });
        defer allocator.free(full_path);

        const test_exe = builder.addTest(.{
            .root_module = builder.createModule(.{
                .root_source_file = builder.path(full_path),
                .target = target,
                .imports = modules,
            }),
        });

        // Link V8 libraries if requested (for V8 tests)
        if (link_v8) {
            // Add V8 C++ wrapper
            test_exe.addCSourceFile(.{
                .file = builder.path("src/runtime/engines/v8/v8_wrapper.cpp"),
                .flags = &.{
                    "-std=c++20",
                    "-fno-exceptions",
                    "-fno-rtti",
                    "-DV8_COMPRESS_POINTERS",
                    "-DV8_ENABLE_SANDBOX",
                },
            });

            test_exe.linkSystemLibrary("v8");
            test_exe.linkSystemLibrary("v8_libplatform");
            test_exe.linkSystemLibrary("v8_libbase");
            test_exe.linkLibCpp();

            // Add library search paths for Homebrew V8
            test_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
            test_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
        }

        const run_test = builder.addRunArtifact(test_exe);
        step.dependOn(&run_test.step);
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================================
    // BUILD OPTIONS
    // ========================================================================

    const spec_filter = b.option(
        []const u8,
        "spec",
        "Run tests for a specific spec (infra, webidl, dom, encoding, url, console, streams, mimesniff, or 'all')",
    );

    // Validate spec filter
    if (spec_filter) |spec| {
        const valid_specs = [_][]const u8{
            "all",
            "infra",
            "webidl",
            "dom",
            "encoding",
            "url",
            "console",
            "streams",
            "mimesniff",
            "runtime",
            "codegen",
            "v8",
        };
        var is_valid = false;
        for (valid_specs) |valid_spec| {
            if (std.mem.eql(u8, spec, valid_spec)) {
                is_valid = true;
                break;
            }
        }
        if (!is_valid) {
            std.debug.print("Error: Invalid spec '{s}'\n", .{spec});
            std.debug.print("Valid specs: all, infra, webidl, dom, encoding, url, console, streams, mimesniff, runtime, codegen, v8\n", .{});
            std.process.exit(1);
        }
    }

    // ========================================================================
    // LIBRARY MODULE
    // ========================================================================

    const whatwg_mod = b.addModule("whatwg", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // ========================================================================
    // INDIVIDUAL SPEC MODULES
    // ========================================================================

    const infra_mod = b.addModule("infra", .{
        .root_source_file = b.path("src/infra/root.zig"),
        .target = target,
    });

    const webidl_mod = b.addModule("webidl", .{
        .root_source_file = b.path("src/webidl/root.zig"),
        .target = target,
    });
    webidl_mod.addImport("infra", infra_mod);

    // Runtime module (WebIDL runtime infrastructure)
    const runtime_mod = b.addModule("runtime", .{
        .root_source_file = b.path("src/runtime/root.zig"),
        .target = target,
    });
    runtime_mod.addImport("webidl", webidl_mod);
    runtime_mod.addImport("infra", infra_mod);

    // V8 bindings module
    const v8_mod = b.addModule("v8", .{
        .root_source_file = b.path("src/runtime/engines/v8/root.zig"),
        .target = target,
    });
    v8_mod.addImport("runtime", runtime_mod);
    // v8_mod will need event_loop - added later after streams_event_loop_mod is defined

    // JS bindings module
    const js_bindings_mod = b.addModule("js_bindings", .{
        .root_source_file = b.path("src/js_bindings/root.zig"),
        .target = target,
    });
    js_bindings_mod.addImport("runtime", runtime_mod);

    // WebIDL codegen module
    const codegen_mod = b.addModule("codegen", .{
        .root_source_file = b.path("src/webidl/codegen/root.zig"),
        .target = target,
    });
    codegen_mod.addImport("webidl", webidl_mod);
    codegen_mod.addImport("infra", infra_mod);

    // ========================================================================
    // WEBIDL CALLBACKS MODULE
    // ========================================================================

    const callbacks_mod = b.addModule("callbacks", .{
        .root_source_file = b.path("src/webidl/callbacks/root.zig"),
        .target = target,
    });
    callbacks_mod.addImport("runtime", runtime_mod);

    // ========================================================================
    // WEBIDL DICTIONARIES MODULE
    // ========================================================================

    const dictionaries_mod = b.addModule("dictionaries", .{
        .root_source_file = b.path("src/webidl/dictionaries/root.zig"),
        .target = target,
    });
    dictionaries_mod.addImport("runtime", runtime_mod);

    // ========================================================================
    // WEBIDL ENUMS MODULE
    // ========================================================================

    const enums_mod = b.addModule("enums", .{
        .root_source_file = b.path("src/webidl/enums/root.zig"),
        .target = target,
    });

    // ========================================================================
    // WEBIDL NAMESPACES MODULE
    // ========================================================================

    const namespaces_mod = b.addModule("namespaces", .{
        .root_source_file = b.path("src/webidl/namespaces/root.zig"),
        .target = target,
    });
    namespaces_mod.addImport("runtime", runtime_mod);

    // ========================================================================
    // WEBIDL TYPEDEFS MODULE
    // ========================================================================

    const typedefs_mod = b.addModule("typedefs", .{
        .root_source_file = b.path("src/webidl/typedefs/root.zig"),
        .target = target,
    });
    typedefs_mod.addImport("runtime", runtime_mod);
    typedefs_mod.addImport("callbacks", callbacks_mod);
    typedefs_mod.addImport("webidl", webidl_mod);

    // ========================================================================
    // INTERFACES MODULE (WebIDL interface definitions)
    // All interfaces in one module so they can import each other with relative paths
    // ========================================================================

    const interfaces_mod = b.addModule("interfaces", .{
        .root_source_file = b.path("src/webidl/interfaces/root.zig"),
        .target = target,
    });
    interfaces_mod.addImport("runtime", runtime_mod);

    // ========================================================================
    // IMPLEMENTATIONS MODULE (WebIDL interface implementations)
    // ========================================================================

    const impls_mod = b.addModule("impls", .{
        .root_source_file = b.path("src/webidl/impls/root.zig"),
        .target = target,
    });
    impls_mod.addImport("runtime", runtime_mod);
    impls_mod.addImport("v8", v8_mod);

    // Cross-imports for WebIDL modules
    interfaces_mod.addImport("interfaces", interfaces_mod); // Self-import for cross-interface refs
    interfaces_mod.addImport("impls", impls_mod);
    namespaces_mod.addImport("impls", impls_mod); // Namespaces need access to impls
    interfaces_mod.addImport("typedefs", typedefs_mod);
    interfaces_mod.addImport("dictionaries", dictionaries_mod);
    interfaces_mod.addImport("enums", enums_mod);
    interfaces_mod.addImport("callbacks", callbacks_mod);
    impls_mod.addImport("interfaces", interfaces_mod);
    impls_mod.addImport("typedefs", typedefs_mod);
    impls_mod.addImport("dictionaries", dictionaries_mod);
    impls_mod.addImport("enums", enums_mod);
    impls_mod.addImport("callbacks", callbacks_mod);
    impls_mod.addImport("webidl", webidl_mod); // For error types and WebIDL infrastructure

    // V8 module needs interfaces for automatic constructor inheritance setup
    v8_mod.addImport("interfaces", interfaces_mod);

    // DOM module
    const dom_mod = b.addModule("dom", .{
        .root_source_file = b.path("src/dom/root.zig"),
        .target = target,
    });
    dom_mod.addImport("infra", infra_mod);
    dom_mod.addImport("webidl", webidl_mod);
    dom_mod.addImport("runtime", runtime_mod);
    dom_mod.addImport("interfaces", interfaces_mod);

    // Selector module (CSS Selectors Level 4 implementation)
    const selector_mod = b.addModule("selector", .{
        .root_source_file = b.path("src/selector/root.zig"),
        .target = target,
    });
    selector_mod.addImport("infra", infra_mod);
    selector_mod.addImport("dom", dom_mod);

    // Add selector to dom (after selector_mod is defined to avoid undefined reference)
    dom_mod.addImport("selector", selector_mod);
    // Add unified interfaces module
    dom_mod.addImport("interfaces", interfaces_mod);

    const encoding_mod = b.addModule("encoding", .{
        .root_source_file = b.path("src/encoding/root.zig"),
        .target = target,
    });
    encoding_mod.addImport("infra", infra_mod);
    encoding_mod.addImport("webidl", webidl_mod);

    // URL internal modules that generated interfaces need
    // URL internal modules need to be created first for cross-dependencies
    const url_internal_host_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/host.zig"),
        .target = target,
    });

    const url_internal_path_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/path.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const url_blob_url_mod = b.createModule(.{
        .root_source_file = b.path("src/url/blob_url.zig"),
        .target = target,
    });

    const url_internal_url_record_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/url_record.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "host", .module = url_internal_host_mod },
            .{ .name = "path", .module = url_internal_path_mod },
            .{ .name = "blob_url", .module = url_blob_url_mod },
        },
    });

    const url_parser_api_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/api_url_parser.zig"),
        .target = target,
    });

    const url_host_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/host_serializer.zig"),
        .target = target,
    });
    url_host_serializer_mod.addImport("host", url_internal_host_mod);
    url_host_serializer_mod.addImport("infra", infra_mod);

    const url_path_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/url_path_serializer.zig"),
        .target = target,
    });
    url_path_serializer_mod.addImport("url_record", url_internal_url_record_mod);
    url_path_serializer_mod.addImport("infra", infra_mod);

    const url_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/url_serializer.zig"),
        .target = target,
    });
    url_serializer_mod.addImport("url_record", url_internal_url_record_mod);
    url_serializer_mod.addImport("path_serializer", url_path_serializer_mod);
    url_serializer_mod.addImport("host_serializer", url_host_serializer_mod);
    url_serializer_mod.addImport("infra", infra_mod);

    const url_basic_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/basic_url_parser.zig"),
        .target = target,
    });
    url_basic_parser_mod.addImport("infra", infra_mod);
    url_basic_parser_mod.addImport("url_record", url_internal_url_record_mod);
    url_basic_parser_mod.addImport("host", url_internal_host_mod);
    url_basic_parser_mod.addImport("path", url_internal_path_mod);

    // Add imports to url_parser_api_mod now that dependencies are defined
    url_parser_api_mod.addImport("infra", infra_mod);
    url_parser_api_mod.addImport("url_record", url_internal_url_record_mod);
    url_parser_api_mod.addImport("basic_parser", url_basic_parser_mod);

    const url_parser_state_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/parser_state.zig"),
        .target = target,
    });

    const url_helpers_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/helpers.zig"),
        .target = target,
    });

    // Add late imports to url_basic_parser_mod now that helpers and parser_state are defined
    url_basic_parser_mod.addImport("parser_state", url_parser_state_mod);
    url_basic_parser_mod.addImport("helpers", url_helpers_mod);

    const url_percent_encoding_mod = b.createModule(.{
        .root_source_file = b.path("src/url/encoding/percent_encoding.zig"),
        .target = target,
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const url_encode_sets_mod = b.createModule(.{
        .root_source_file = b.path("src/url/encoding/encode_sets.zig"),
        .target = target,
    });

    const url_search_params_impl_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/url_search_params_impl.zig"),
        .target = target,
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const url_form_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/form_urlencoded/parser.zig"),
        .target = target,
    });
    url_form_parser_mod.addImport("infra", infra_mod);
    url_form_parser_mod.addImport("percent_encoding", url_percent_encoding_mod);

    const url_form_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/form_urlencoded/serializer.zig"),
        .target = target,
    });
    url_form_serializer_mod.addImport("form_parser", url_form_parser_mod);
    url_form_serializer_mod.addImport("infra", infra_mod);
    url_form_serializer_mod.addImport("percent_encoding", url_percent_encoding_mod);
    url_form_serializer_mod.addImport("encode_sets", url_encode_sets_mod);

    // Additional URL modules for internal use
    const url_validation_mod = b.createModule(.{
        .root_source_file = b.path("src/url/validation.zig"),
        .target = target,
    });

    const url_ipv4_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/ipv4_serializer.zig"),
        .target = target,
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const url_ipv6_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/ipv6_serializer.zig"),
        .target = target,
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    // Add serializer dependencies to host_serializer (needed after ipv4/ipv6 serializers are defined)
    url_host_serializer_mod.addImport("ipv4_serializer", url_ipv4_serializer_mod);
    url_host_serializer_mod.addImport("ipv6_serializer", url_ipv6_serializer_mod);

    const url_ipv4_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/ipv4_parser.zig"),
        .target = target,
    });

    const url_ipv6_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/ipv6_parser.zig"),
        .target = target,
    });

    const url_idna_mod = b.createModule(.{
        .root_source_file = b.path("src/url/idna/root.zig"),
        .target = target,
    });
    url_idna_mod.addImport("infra", infra_mod);

    const url_host_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/host_parser.zig"),
        .target = target,
    });
    url_host_parser_mod.addImport("infra", infra_mod);
    url_host_parser_mod.addImport("idna", url_idna_mod);
    url_host_parser_mod.addImport("validation", url_validation_mod);
    url_host_parser_mod.addImport("host", url_internal_host_mod);
    url_host_parser_mod.addImport("ipv4_parser", url_ipv4_parser_mod);
    url_host_parser_mod.addImport("ipv6_parser", url_ipv6_parser_mod);
    url_host_parser_mod.addImport("percent_encoding", url_percent_encoding_mod);
    url_host_parser_mod.addImport("encode_sets", url_encode_sets_mod);

    // Add host_parser import to url_basic_parser_mod now that it's defined
    url_basic_parser_mod.addImport("host_parser", url_host_parser_mod);

    const url_windows_drive_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/windows_drive.zig"),
        .target = target,
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    // Add remaining imports to url_basic_parser_mod now that all dependencies are defined
    url_basic_parser_mod.addImport("percent_encoding", url_percent_encoding_mod);
    url_basic_parser_mod.addImport("encode_sets", url_encode_sets_mod);
    url_basic_parser_mod.addImport("windows_drive", url_windows_drive_mod);

    const url_special_schemes_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/special_schemes.zig"),
        .target = target,
    });

    const url_origin_mod_internal = b.createModule(.{
        .root_source_file = b.path("src/url/origin.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "url_record", .module = url_internal_url_record_mod },
            .{ .name = "host", .module = url_internal_host_mod },
            .{ .name = "host_serializer", .module = url_host_serializer_mod },
            .{ .name = "path", .module = url_internal_path_mod },
            .{ .name = "path_serializer", .module = url_path_serializer_mod },
            .{ .name = "api_url_parser", .module = url_parser_api_mod },
        },
    });

    const url_equivalence_mod = b.createModule(.{
        .root_source_file = b.path("src/url/equivalence.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "url_record", .module = url_internal_url_record_mod },
            .{ .name = "host", .module = url_internal_host_mod },
            .{ .name = "url_serializer", .module = url_serializer_mod },
            .{ .name = "path", .module = url_internal_path_mod },
        },
    });

    // Add dependencies for internal modules
    url_search_params_impl_mod.addImport("form_parser", url_form_parser_mod);
    url_search_params_impl_mod.addImport("form_serializer", url_form_serializer_mod);

    url_ipv4_parser_mod.addImport("infra", infra_mod);
    url_ipv4_parser_mod.addImport("validation", url_validation_mod);
    url_ipv6_parser_mod.addImport("infra", infra_mod);
    url_ipv6_parser_mod.addImport("validation", url_validation_mod);
    url_percent_encoding_mod.addImport("encode_sets", url_encode_sets_mod);
    url_blob_url_mod.addImport("origin", url_origin_mod_internal);

    // Main url module
    const url_mod = b.addModule("url", .{
        .root_source_file = b.path("src/url/root.zig"),
        .target = target,
    });
    url_mod.addImport("infra", infra_mod);
    url_mod.addImport("webidl", webidl_mod);
    url_mod.addImport("encoding", encoding_mod);
    url_mod.addImport("url_search_params_impl", url_search_params_impl_mod);
    url_mod.addImport("url_record", url_internal_url_record_mod);
    url_mod.addImport("host_serializer", url_host_serializer_mod);
    url_mod.addImport("basic_parser", url_basic_parser_mod);
    url_mod.addImport("parser_state", url_parser_state_mod);
    url_mod.addImport("encode_sets", url_encode_sets_mod);
    url_mod.addImport("percent_encoding", url_percent_encoding_mod);
    url_mod.addImport("windows_drive", url_windows_drive_mod);
    url_mod.addImport("special_schemes", url_special_schemes_mod);
    url_mod.addImport("validation", url_validation_mod);
    url_mod.addImport("host", url_internal_host_mod);
    url_mod.addImport("ipv4_parser", url_ipv4_parser_mod);
    url_mod.addImport("ipv6_parser", url_ipv6_parser_mod);
    url_mod.addImport("idna", url_idna_mod);
    url_mod.addImport("host_parser", url_host_parser_mod);
    url_mod.addImport("ipv4_serializer", url_ipv4_serializer_mod);
    url_mod.addImport("ipv6_serializer", url_ipv6_serializer_mod);
    url_mod.addImport("helpers", url_helpers_mod);
    url_mod.addImport("origin", url_origin_mod_internal);
    url_mod.addImport("blob_url", url_blob_url_mod);
    url_mod.addImport("equivalence", url_equivalence_mod);
    url_mod.addImport("path_serializer", url_path_serializer_mod);

    // URL infrastructure modules for impls (needed by URL.zig and URLSearchParams.zig impl)
    impls_mod.addImport("url_record", url_internal_url_record_mod);
    impls_mod.addImport("api_parser", url_parser_api_mod);
    impls_mod.addImport("basic_parser", url_basic_parser_mod);
    impls_mod.addImport("url_serializer", url_serializer_mod);
    impls_mod.addImport("host_serializer", url_host_serializer_mod);
    impls_mod.addImport("path_serializer", url_path_serializer_mod);
    impls_mod.addImport("origin", url_origin_mod_internal);
    impls_mod.addImport("percent_encoding", url_percent_encoding_mod);
    impls_mod.addImport("encode_sets", url_encode_sets_mod);
    impls_mod.addImport("parser_state", url_parser_state_mod);
    impls_mod.addImport("form_parser", url_form_parser_mod);
    impls_mod.addImport("form_serializer", url_form_serializer_mod);

    // Infra module for URLSearchParams (List type)
    impls_mod.addImport("infra", infra_mod);

    const console_mod = b.addModule("console", .{
        .root_source_file = b.path("src/console/root.zig"),
        .target = target,
    });
    console_mod.addImport("webidl", webidl_mod);
    console_mod.addImport("interfaces", interfaces_mod);
    console_mod.addImport("namespaces", namespaces_mod);

    // Streams internal modules (used by both root.zig and generated interfaces)
    // All internal files need to import each other via modules to avoid circular file ownership

    const streams_common_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/common.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
        },
    });

    const streams_event_loop_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/event_loop.zig"),
        .target = target,
    });

    const streams_async_promise_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/async_promise.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "event_loop", .module = streams_event_loop_mod },
            .{ .name = "common", .module = streams_common_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const streams_test_event_loop_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/test_event_loop.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "event_loop", .module = streams_event_loop_mod },
        },
    });

    const streams_queue_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/queue_with_sizes.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "common", .module = streams_common_mod },
        },
    });

    const streams_read_request_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/read_request.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "queue_with_sizes", .module = streams_queue_mod },
        },
    });

    const streams_write_request_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/write_request.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "queue_with_sizes", .module = streams_queue_mod },
            .{ .name = "async_promise", .module = streams_async_promise_mod },
            .{ .name = "event_loop", .module = streams_event_loop_mod },
            .{ .name = "webidl", .module = webidl_mod },
        },
    });

    const streams_read_into_request_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/read_into_request.zig"),
        .target = target,
    });

    const streams_read_into_request_promise_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/read_into_request_promise.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "event_loop", .module = streams_event_loop_mod },
            .{ .name = "async_promise", .module = streams_async_promise_mod },
            .{ .name = "read_into_request", .module = streams_read_into_request_mod },
        },
    });

    const streams_pull_into_descriptor_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/pull_into_descriptor.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
        },
    });

    const streams_async_iterator_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/async_iterator.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "common", .module = streams_common_mod },
        },
    });

    const streams_message_port_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/message_port.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "common", .module = streams_common_mod },
        },
    });

    const streams_cross_realm_transform_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/cross_realm_transform.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "common", .module = streams_common_mod },
            .{ .name = "message_port", .module = streams_message_port_mod },
        },
    });

    const streams_view_construction_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/view_construction.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "pull_into_descriptor", .module = streams_pull_into_descriptor_mod },
        },
    });

    const streams_structured_clone_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/structured_clone.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "common", .module = streams_common_mod },
            .{ .name = "pull_into_descriptor", .module = streams_pull_into_descriptor_mod },
            .{ .name = "message_port", .module = streams_message_port_mod },
        },
    });

    // Main streams module
    const streams_mod = b.addModule("streams", .{
        .root_source_file = b.path("src/streams/root.zig"),
        .target = target,
    });
    streams_mod.addImport("infra", infra_mod);
    streams_mod.addImport("webidl", webidl_mod);
    streams_mod.addImport("runtime", runtime_mod);
    streams_mod.addImport("dom", dom_mod);

    // Add event loop to runtime and v8 for async operations (streams, promises)
    runtime_mod.addImport("event_loop", streams_event_loop_mod);
    v8_mod.addImport("event_loop", streams_event_loop_mod);

    // Add v8 to runtime so context can create V8EventLoop
    runtime_mod.addImport("v8", v8_mod);

    // Add internal modules so root.zig can access them
    streams_mod.addImport("common", streams_common_mod);
    streams_mod.addImport("event_loop", streams_event_loop_mod);
    streams_mod.addImport("async_promise", streams_async_promise_mod);
    streams_mod.addImport("test_event_loop", streams_test_event_loop_mod);
    streams_mod.addImport("queue_with_sizes", streams_queue_mod);
    streams_mod.addImport("read_request", streams_read_request_mod);
    streams_mod.addImport("read_into_request", streams_read_into_request_mod);
    streams_mod.addImport("pull_into_descriptor", streams_pull_into_descriptor_mod);
    streams_mod.addImport("write_request", streams_write_request_mod);
    streams_mod.addImport("structured_clone", streams_structured_clone_mod);
    streams_mod.addImport("view_construction", streams_view_construction_mod);
    streams_mod.addImport("async_iterator", streams_async_iterator_mod);
    streams_mod.addImport("message_port", streams_message_port_mod);
    streams_mod.addImport("cross_realm_transform", streams_cross_realm_transform_mod);
    // Add unified interfaces module
    streams_mod.addImport("interfaces", interfaces_mod);

    // Add streams event loop to interfaces for ReadableStreamBYOBReader init
    interfaces_mod.addImport("streams_event_loop", streams_event_loop_mod);

    // Add streams modules to impls for ReadableStream, WritableStream, TransformStream implementations
    impls_mod.addImport("streams_common", streams_common_mod);
    impls_mod.addImport("streams_event_loop", streams_event_loop_mod);
    impls_mod.addImport("streams_async_promise", streams_async_promise_mod);
    impls_mod.addImport("streams_test_event_loop", streams_test_event_loop_mod);
    impls_mod.addImport("streams_queue", streams_queue_mod);
    impls_mod.addImport("streams_read_request", streams_read_request_mod);
    impls_mod.addImport("streams_write_request", streams_write_request_mod);
    impls_mod.addImport("streams_read_into_request", streams_read_into_request_mod);
    impls_mod.addImport("streams_read_into_request_promise", streams_read_into_request_promise_mod);
    impls_mod.addImport("streams_pull_into_descriptor", streams_pull_into_descriptor_mod);

    // ArrayBufferView is part of runtime module, no separate module needed
    // (ReadableStreamBYOBReader accesses it via runtime.arraybuffer_view)

    const mimesniff_mod = b.addModule("mimesniff", .{
        .root_source_file = b.path("src/mimesniff/root.zig"),
        .target = target,
    });
    mimesniff_mod.addImport("infra", infra_mod);

    // Wire spec modules into whatwg module
    whatwg_mod.addImport("infra", infra_mod);
    whatwg_mod.addImport("webidl", webidl_mod);
    whatwg_mod.addImport("runtime", runtime_mod);
    whatwg_mod.addImport("dom", dom_mod);
    whatwg_mod.addImport("encoding", encoding_mod);
    whatwg_mod.addImport("url", url_mod);
    whatwg_mod.addImport("console", console_mod);
    whatwg_mod.addImport("streams", streams_mod);
    whatwg_mod.addImport("mimesniff", mimesniff_mod);
    whatwg_mod.addImport("interfaces", interfaces_mod);
    whatwg_mod.addImport("impls", impls_mod);

    // ========================================================================
    // TESTS - GENERIC SPEC FILTERING
    // ========================================================================

    const test_step = b.step("test", "Run WHATWG spec tests (use -Dspec=<name> to filter)");

    const test_all = spec_filter == null or std.mem.eql(u8, spec_filter.?, "all");
    const test_infra = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "infra"));
    const test_webidl = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "webidl"));
    const test_dom = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "dom"));
    const test_selector = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "selector"));
    const test_encoding = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "encoding"));
    const test_url = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "url"));
    const test_console = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "console"));
    const test_streams = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "streams"));
    const test_mimesniff = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "mimesniff"));

    if (test_infra) {
        const infra_tests = b.addTest(.{ .root_module = infra_mod });
        const run_infra_tests = b.addRunArtifact(infra_tests);
        test_step.dependOn(&run_infra_tests.step);
    }

    if (test_webidl) {
        const webidl_tests = b.addTest(.{ .root_module = webidl_mod });
        const run_webidl_tests = b.addRunArtifact(webidl_tests);
        test_step.dependOn(&run_webidl_tests.step);

        // Add dedicated test files from tests/webidl/
        const webidl_imports = [_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "dom", .module = dom_mod },
            .{ .name = "streams", .module = streams_mod },
            .{ .name = "console", .module = console_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/webidl", target, &webidl_imports, false) catch |err| {
            std.debug.print("Warning: Failed to add webidl test files: {}\n", .{err});
        };
    }

    if (test_dom) {
        const dom_tests = b.addTest(.{ .root_module = dom_mod });
        const run_dom_tests = b.addRunArtifact(dom_tests);
        test_step.dependOn(&run_dom_tests.step);

        // Add dedicated test files from tests/dom/
        const dom_imports = [_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "dom", .module = dom_mod },
            .{ .name = "selector", .module = selector_mod },
            .{ .name = "runtime", .module = runtime_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/dom", target, &dom_imports, false) catch |err| {
            std.debug.print("Warning: Failed to add dom test files: {}\n", .{err});
        };
    }

    if (test_selector) {
        const selector_tests = b.addTest(.{ .root_module = selector_mod });
        const run_selector_tests = b.addRunArtifact(selector_tests);
        test_step.dependOn(&run_selector_tests.step);

        // Add dedicated test files from tests/selector/
        const selector_imports = [_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "dom", .module = dom_mod },
            .{ .name = "selector", .module = selector_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/selector", target, &selector_imports, false) catch |err| {
            std.debug.print("Warning: Failed to add selector test files: {}\n", .{err});
        };
    }

    if (test_encoding) {
        const encoding_tests = b.addTest(.{ .root_module = encoding_mod });
        const run_encoding_tests = b.addRunArtifact(encoding_tests);
        test_step.dependOn(&run_encoding_tests.step);

        // Add dedicated test files from tests/encoding/
        const encoding_imports = [_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "encoding", .module = encoding_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/encoding", target, &encoding_imports, false) catch |err| {
            std.debug.print("Warning: Failed to add encoding test files: {}\n", .{err});
        };
    }

    if (test_url) {
        const url_tests = b.addTest(.{ .root_module = url_mod });
        const run_url_tests = b.addRunArtifact(url_tests);
        test_step.dependOn(&run_url_tests.step);

        // Add dedicated test files from tests/url/
        const url_imports = [_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "encoding", .module = encoding_mod },
            .{ .name = "url", .module = url_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/url", target, &url_imports, false) catch |err| {
            std.debug.print("Warning: Failed to add url test files: {}\n", .{err});
        };
    }

    if (test_console) {
        const console_tests = b.addTest(.{ .root_module = console_mod });
        const run_console_tests = b.addRunArtifact(console_tests);
        test_step.dependOn(&run_console_tests.step);

        // Add dedicated test files from tests/console/
        const console_imports = [_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "console", .module = console_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/console", target, &console_imports, false) catch |err| {
            std.debug.print("Warning: Failed to add console test files: {}\n", .{err});
        };
    }

    if (test_streams) {
        const streams_tests = b.addTest(.{ .root_module = streams_mod });
        const run_streams_tests = b.addRunArtifact(streams_tests);
        test_step.dependOn(&run_streams_tests.step);

        // Add dedicated test files from tests/streams/
        const streams_imports = [_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "dom", .module = dom_mod },
            .{ .name = "streams", .module = streams_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/streams", target, &streams_imports, false) catch |err| {
            std.debug.print("Warning: Failed to add streams test files: {}\n", .{err});
        };
    }

    if (test_mimesniff) {
        const mimesniff_tests = b.addTest(.{ .root_module = mimesniff_mod });
        const run_mimesniff_tests = b.addRunArtifact(mimesniff_tests);
        test_step.dependOn(&run_mimesniff_tests.step);

        // Add dedicated test files from tests/mimesniff/
        const mimesniff_imports = [_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "mimesniff", .module = mimesniff_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/mimesniff", target, &mimesniff_imports, false) catch |err| {
            std.debug.print("Warning: Failed to add mimesniff test files: {}\n", .{err});
        };
    }

    // Runtime tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "runtime")) {
        const runtime_imports = [_]std.Build.Module.Import{
            .{ .name = "runtime", .module = runtime_mod },
            .{ .name = "webidl", .module = webidl_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/runtime", target, &runtime_imports, false) catch |err| {
            std.debug.print("Warning: Failed to add runtime test files: {}\n", .{err});
        };
    }

    // Codegen tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "codegen")) {
        const codegen_imports = [_]std.Build.Module.Import{
            .{ .name = "codegen", .module = codegen_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "infra", .module = infra_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/codegen", target, &codegen_imports, false) catch |err| {
            std.debug.print("Warning: Failed to add codegen test files: {}\n", .{err});
        };
    }

    // V8 tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "v8")) {
        const v8_imports = [_]std.Build.Module.Import{
            .{ .name = "v8", .module = v8_mod },
            .{ .name = "runtime", .module = runtime_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/v8", target, &v8_imports, true) catch |err| {
            std.debug.print("Warning: Failed to add v8 test files: {}\n", .{err});
        };
    }

    // ========================================================================
    // EXECUTABLE (optional CLI tool)
    // ========================================================================

    const exe = b.addExecutable(.{
        .name = "whatwg",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "whatwg", .module = whatwg_mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the WHATWG CLI tool");
    run_step.dependOn(&run_cmd.step);

    // ========================================================================
    // IDL PARSER TOOL
    // ========================================================================

    const parse_idls_exe = b.addExecutable(.{
        .name = "parse-idls",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/webidl/parser/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "infra", .module = infra_mod },
            },
        }),
    });

    const install_parse_idls = b.addInstallArtifact(parse_idls_exe, .{});
    const parse_idls_cmd = b.addRunArtifact(parse_idls_exe);
    parse_idls_cmd.step.dependOn(&install_parse_idls.step);

    // Add arguments to parse webref IDLs
    parse_idls_cmd.addArg("/Users/bcardarella/projects/webref/ed/idl/");
    parse_idls_cmd.addArg("webidl/idls/");

    const parse_idls_step = b.step("parse-idls", "Parse WebIDL files from webref");
    parse_idls_step.dependOn(&parse_idls_cmd.step);

    // ========================================================================
    // WEBIDL TOOLS
    // ========================================================================

    // Codegen tool
    const codegen_exe = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/codegen_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "codegen", .module = codegen_mod },
                .{ .name = "webidl", .module = webidl_mod },
                .{ .name = "infra", .module = infra_mod },
            },
        }),
    });
    b.installArtifact(codegen_exe);

    // Add run step for codegen (don't depend on full install to avoid build errors in other tools)
    const run_codegen = b.addRunArtifact(codegen_exe);
    if (b.args) |args| run_codegen.addArgs(args);

    const codegen_step = b.step("codegen", "Run WebIDL code generator (use -- to pass args)");
    codegen_step.dependOn(&run_codegen.step);

    // IDL scanner tool
    const idl_scanner_exe = b.addExecutable(.{
        .name = "idl-scanner",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/idl_scanner_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "codegen", .module = codegen_mod },
                .{ .name = "webidl", .module = webidl_mod },
            },
        }),
    });
    b.installArtifact(idl_scanner_exe);

    // Add run step for idl-scanner
    const run_idl_scanner = b.addRunArtifact(idl_scanner_exe);
    run_idl_scanner.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_idl_scanner.addArgs(args);

    const idl_scanner_step = b.step("idl-scanner", "Run IDL scanner tool (use -- to pass args)");
    idl_scanner_step.dependOn(&run_idl_scanner.step);

    // Interfaces tool
    const interfaces_exe = b.addExecutable(.{
        .name = "interfaces",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/interfaces_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "interfaces", .module = interfaces_mod },
                .{ .name = "runtime", .module = runtime_mod },
            },
        }),
    });
    b.installArtifact(interfaces_exe);

    // Add run step for interfaces tool
    const run_interfaces_tool = b.addRunArtifact(interfaces_exe);
    run_interfaces_tool.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_interfaces_tool.addArgs(args);

    const interfaces_tool_step = b.step("interfaces-tool", "Run interfaces tool (use -- to pass args)");
    interfaces_tool_step.dependOn(&run_interfaces_tool.step);

    // REPL tool
    const repl_exe = b.addExecutable(.{
        .name = "repl",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/repl.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "runtime", .module = runtime_mod },
                .{ .name = "v8", .module = v8_mod },
                .{ .name = "interfaces", .module = interfaces_mod },
                .{ .name = "namespaces", .module = namespaces_mod },
            },
        }),
    });

    // Add V8 C++ wrapper
    repl_exe.addCSourceFile(.{
        .file = b.path("src/runtime/engines/v8/v8_wrapper.cpp"),
        .flags = &.{
            "-std=c++20",
            "-fno-exceptions",
            "-fno-rtti",
            "-DV8_COMPRESS_POINTERS",
            "-DV8_ENABLE_SANDBOX",
        },
    });

    // Add V8 include paths (Homebrew on macOS)
    repl_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/v8/include" });

    // Link V8 libraries
    repl_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/v8/lib" });
    repl_exe.linkSystemLibrary("v8");
    repl_exe.linkSystemLibrary("v8_libplatform");
    repl_exe.linkSystemLibrary("v8_libbase");

    // Link C++ standard library
    repl_exe.linkLibCpp();

    b.installArtifact(repl_exe);

    // Add run step for REPL
    const run_repl = b.addRunArtifact(repl_exe);
    run_repl.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_repl.addArgs(args);

    const repl_step = b.step("repl", "Run REPL tool (use -- to pass args)");
    repl_step.dependOn(&run_repl.step);

    // ========================================================================
    // V8 JAVASCRIPT TEST RUNNER
    // ========================================================================

    // Test runner executable for V8 JavaScript tests
    const test_runner_exe = b.addExecutable(.{
        .name = "test-runner",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/v8/test_runner.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(test_runner_exe);

    // V8 WebIDL bindings conformance tests
    const test_v8_step = b.step("test-v8", "Run V8 WebIDL bindings JavaScript tests");

    // Run basic tests
    const run_basic_tests = b.addRunArtifact(test_runner_exe);
    run_basic_tests.addArtifactArg(repl_exe);
    run_basic_tests.addArg("tests/v8/bindings_test.js");

    // Run advanced tests
    const run_advanced_tests = b.addRunArtifact(test_runner_exe);
    run_advanced_tests.step.dependOn(&run_basic_tests.step);
    run_advanced_tests.addArtifactArg(repl_exe);
    run_advanced_tests.addArg("tests/v8/bindings_advanced_test.js");

    // Run prototype chain tests
    const run_prototype_chain_tests = b.addRunArtifact(test_runner_exe);
    run_prototype_chain_tests.step.dependOn(&run_advanced_tests.step);
    run_prototype_chain_tests.addArtifactArg(repl_exe);
    run_prototype_chain_tests.addArg("tests/v8/prototype_chain_test.js");

    test_v8_step.dependOn(&run_prototype_chain_tests.step);

    // Note: bindings_test_verbose.js and prototype_property_access_test.js use
    // console.log() format and are not compatible with the simple test runner.
    // Run them manually with: ./zig-out/bin/repl < tests/v8/[test-file].js

    // ========================================================================
    // COMPREHENSIVE BUILD TEST
    // ========================================================================

    const comprehensive_exe = b.addExecutable(.{
        .name = "comprehensive",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/comprehensive_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "whatwg", .module = whatwg_mod },
                .{ .name = "infra", .module = infra_mod },
                .{ .name = "webidl", .module = webidl_mod },
                .{ .name = "runtime", .module = runtime_mod },
                .{ .name = "dom", .module = dom_mod },
                .{ .name = "encoding", .module = encoding_mod },
                .{ .name = "url", .module = url_mod },
                .{ .name = "console", .module = console_mod },
                .{ .name = "streams", .module = streams_mod },
                .{ .name = "mimesniff", .module = mimesniff_mod },
                .{ .name = "interfaces", .module = interfaces_mod },
                .{ .name = "impls", .module = impls_mod },
            },
        }),
    });

    b.installArtifact(comprehensive_exe);

    const comprehensive_run = b.addRunArtifact(comprehensive_exe);
    comprehensive_run.step.dependOn(b.getInstallStep());

    const comprehensive_step = b.step("comprehensive", "Build comprehensive binary with all WHATWG specs");
    comprehensive_step.dependOn(&comprehensive_run.step);

    // ========================================================================
    // INTERFACES BUILD STEP - Check that all interfaces compile
    // ========================================================================

    const interfaces_check = b.addTest(.{
        .root_module = interfaces_mod,
    });

    const run_interfaces_check = b.addRunArtifact(interfaces_check);

    const interfaces_step = b.step("interfaces", "Check that all interfaces compile");
    interfaces_step.dependOn(&run_interfaces_check.step);
}
