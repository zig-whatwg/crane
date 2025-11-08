const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================================
    // BUILD OPTIONS
    // ========================================================================

    const spec_filter = b.option(
        []const u8,
        "spec",
        "Run tests for a specific spec (infra, webidl, encoding, url, console, streams, mimesniff, or 'all')",
    );

    // Validate spec filter
    if (spec_filter) |spec| {
        const valid_specs = [_][]const u8{
            "all",
            "infra",
            "webidl",
            "encoding",
            "url",
            "console",
            "streams",
            "mimesniff",
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
            std.debug.print("Valid specs: all, infra, webidl, encoding, url, console, streams, mimesniff\n", .{});
            std.process.exit(1);
        }
    }

    // ========================================================================
    // ZOOP CODEGEN STEP - UNIFIED
    // ========================================================================

    const zoop_dep = b.dependency("zoop", .{
        .target = target,
        .optimize = optimize,
    });
    const zoop_exe = zoop_dep.artifact("zoop-codegen");
    const zoop = zoop_dep.module("zoop");

    // Single codegen invocation - scans all of zoop_src/, outputs to interfaces/
    const zoop_codegen = b.addRunArtifact(zoop_exe);
    zoop_codegen.addArgs(&.{
        "--source-dir",
        "zoop_src",
        "--output-dir",
        "interfaces",
        "--getter-prefix",
        "get_",
        "--setter-prefix",
        "set_",
    });

    const codegen_step = b.step("codegen", "Run zoop code generation for all specs");
    codegen_step.dependOn(&zoop_codegen.step);

    // ========================================================================
    // LIBRARY MODULE
    // ========================================================================

    const whatwg_mod = b.addModule("whatwg", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    whatwg_mod.addImport("zoop", zoop);

    // ========================================================================
    // GENERATED INTERFACE MODULES
    // ========================================================================

    // Create modules for generated interfaces
    const console_interface_mod = b.addModule("console_interface", .{
        .root_source_file = b.path("interfaces/console/console.zig"),
        .target = target,
    });
    console_interface_mod.addImport("zoop", zoop);

    const encoding_interface_mod = b.addModule("encoding_interface", .{
        .root_source_file = b.path("interfaces/encoding/text_encoder.zig"),
        .target = target,
    });
    encoding_interface_mod.addImport("zoop", zoop);

    const url_interface_mod = b.addModule("url_interface", .{
        .root_source_file = b.path("interfaces/url/url.zig"),
        .target = target,
    });
    url_interface_mod.addImport("zoop", zoop);

    const streams_interface_mod = b.addModule("streams_interface", .{
        .root_source_file = b.path("interfaces/streams/readable_stream.zig"),
        .target = target,
    });
    streams_interface_mod.addImport("zoop", zoop);

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

    const encoding_mod = b.addModule("encoding", .{
        .root_source_file = b.path("src/encoding/root.zig"),
        .target = target,
    });
    encoding_mod.addImport("infra", infra_mod);
    encoding_mod.addImport("webidl", webidl_mod);
    encoding_mod.addImport("zoop", zoop);

    // Create interface modules with proper dependencies
    const text_encoder_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/encoding/text_encoder.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "zoop", .module = zoop },
        },
    });

    const text_encoder_result_mod = b.createModule(.{
        .root_source_file = b.path("zoop_src/encoding/text_encoder_encode_into_result.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "zoop", .module = zoop },
        },
    });
    text_encoder_mod.addImport("text_encoder_encode_into_result", text_encoder_result_mod);

    const text_decoder_options_mod = b.createModule(.{
        .root_source_file = b.path("zoop_src/encoding/text_decoder_options.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "zoop", .module = zoop },
        },
    });

    const text_decode_options_mod = b.createModule(.{
        .root_source_file = b.path("zoop_src/encoding/text_decode_options.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "zoop", .module = zoop },
        },
    });

    const text_decoder_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/encoding/text_decoder.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "zoop", .module = zoop },
            .{ .name = "text_decoder_options", .module = text_decoder_options_mod },
            .{ .name = "text_decode_options", .module = text_decode_options_mod },
            .{ .name = "encoding", .module = encoding_mod },
        },
    });

    // Add anonymous imports for generated files
    encoding_mod.addImport("text_encoder", text_encoder_mod);
    encoding_mod.addImport("text_decoder", text_decoder_mod);
    encoding_mod.addImport("text_encoder_encode_into_result", text_encoder_result_mod);
    encoding_mod.addImport("text_decoder_options", text_decoder_options_mod);
    encoding_mod.addImport("text_decode_options", text_decode_options_mod);

    // URL internal modules that generated interfaces need
    // URL internal modules need to be created first for cross-dependencies
    const url_internal_host_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/host.zig"),
        .target = target,
    });

    const url_internal_path_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/path.zig"),
        .target = target,
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

    const url_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/url_serializer.zig"),
        .target = target,
    });

    const url_origin_mod = b.createModule(.{
        .root_source_file = b.path("src/url/origin.zig"),
        .target = target,
    });

    const url_host_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/host_serializer.zig"),
        .target = target,
    });

    const url_path_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/url_path_serializer.zig"),
        .target = target,
    });

    const url_basic_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/basic_url_parser.zig"),
        .target = target,
    });

    const url_parser_state_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/parser_state.zig"),
        .target = target,
    });

    const url_helpers_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/helpers.zig"),
        .target = target,
    });

    const url_percent_encoding_mod = b.createModule(.{
        .root_source_file = b.path("src/url/encoding/percent_encoding.zig"),
        .target = target,
        .imports = &.{},
    });

    const url_encode_sets_mod = b.createModule(.{
        .root_source_file = b.path("src/url/encoding/encode_sets.zig"),
        .target = target,
    });

    const url_search_params_impl_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/url_search_params_impl.zig"),
        .target = target,
        .imports = &.{},
    });

    const url_form_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/form_urlencoded/parser.zig"),
        .target = target,
    });

    const url_form_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/form_urlencoded/serializer.zig"),
        .target = target,
    });

    // Additional URL modules for internal use
    const url_validation_mod = b.createModule(.{
        .root_source_file = b.path("src/url/validation.zig"),
        .target = target,
    });

    const url_ipv4_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/ipv4_serializer.zig"),
        .target = target,
    });

    const url_ipv6_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/ipv6_serializer.zig"),
        .target = target,
    });

    const url_ipv4_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/ipv4_parser.zig"),
        .target = target,
    });

    const url_ipv6_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/ipv6_parser.zig"),
        .target = target,
    });

    const url_host_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/host_parser.zig"),
        .target = target,
    });

    const url_windows_drive_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/windows_drive.zig"),
        .target = target,
    });

    const url_special_schemes_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/special_schemes.zig"),
        .target = target,
    });

    const url_origin_mod_internal = b.createModule(.{
        .root_source_file = b.path("src/url/origin.zig"),
        .target = target,
    });

    // Add dependencies for internal modules
    url_search_params_impl_mod.addImport("form_parser", url_form_parser_mod);
    url_search_params_impl_mod.addImport("form_serializer", url_form_serializer_mod);

    url_ipv4_parser_mod.addImport("validation", url_validation_mod);
    url_ipv6_parser_mod.addImport("validation", url_validation_mod);
    url_percent_encoding_mod.addImport("encode_sets", url_encode_sets_mod);

    // Common imports for URL interface modules
    const url_iface_imports = [_]std.Build.Module.Import{
        .{ .name = "infra", .module = infra_mod },
        .{ .name = "webidl", .module = webidl_mod },
        .{ .name = "zoop", .module = zoop },
        .{ .name = "url_record", .module = url_internal_url_record_mod },
        .{ .name = "host", .module = url_internal_host_mod },
        .{ .name = "path", .module = url_internal_path_mod },
        .{ .name = "blob_url", .module = url_blob_url_mod },
        .{ .name = "api_parser", .module = url_parser_api_mod },
        .{ .name = "url_serializer", .module = url_serializer_mod },
        .{ .name = "origin", .module = url_origin_mod },
        .{ .name = "host_serializer", .module = url_host_serializer_mod },
        .{ .name = "path_serializer", .module = url_path_serializer_mod },
        .{ .name = "basic_parser", .module = url_basic_parser_mod },
        .{ .name = "parser_state", .module = url_parser_state_mod },
        .{ .name = "helpers", .module = url_helpers_mod },
        .{ .name = "percent_encoding", .module = url_percent_encoding_mod },
        .{ .name = "encode_sets", .module = url_encode_sets_mod },
        .{ .name = "url_search_params_impl", .module = url_search_params_impl_mod },
        .{ .name = "form_parser", .module = url_form_parser_mod },
        .{ .name = "form_serializer", .module = url_form_serializer_mod },
        .{ .name = "validation", .module = url_validation_mod },
        .{ .name = "ipv4_serializer", .module = url_ipv4_serializer_mod },
        .{ .name = "ipv6_serializer", .module = url_ipv6_serializer_mod },
        .{ .name = "ipv4_parser", .module = url_ipv4_parser_mod },
        .{ .name = "ipv6_parser", .module = url_ipv6_parser_mod },
        .{ .name = "host_parser", .module = url_host_parser_mod },
        .{ .name = "windows_drive", .module = url_windows_drive_mod },
        .{ .name = "special_schemes", .module = url_special_schemes_mod },
        .{ .name = "origin", .module = url_origin_mod_internal },
    };

    // URL interface modules
    const url_url_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/url/url.zig"),
        .target = target,
        .imports = &url_iface_imports,
    });

    const url_search_params_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/url/url_search_params.zig"),
        .target = target,
        .imports = &url_iface_imports,
    });

    // Add cross-references between URL interfaces
    url_url_mod.addImport("url_search_params", url_search_params_mod);
    url_search_params_mod.addImport("url", url_url_mod);

    // Main url module
    const url_mod = b.addModule("url", .{
        .root_source_file = b.path("src/url/root.zig"),
        .target = target,
    });
    url_mod.addImport("infra", infra_mod);
    url_mod.addImport("webidl", webidl_mod);
    url_mod.addImport("encoding", encoding_mod);
    url_mod.addImport("zoop", zoop);
    url_mod.addImport("url", url_url_mod);
    url_mod.addImport("url_search_params", url_search_params_mod);
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
    url_mod.addImport("host_parser", url_host_parser_mod);
    url_mod.addImport("ipv4_serializer", url_ipv4_serializer_mod);
    url_mod.addImport("ipv6_serializer", url_ipv6_serializer_mod);
    url_mod.addImport("helpers", url_helpers_mod);
    url_mod.addImport("origin", url_origin_mod_internal);
    url_mod.addImport("path_serializer", url_path_serializer_mod);

    // Console supporting modules
    const console_types_mod = b.createModule(.{
        .root_source_file = b.path("zoop_src/console/types.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "zoop", .module = zoop },
        },
    });

    const console_format_mod = b.createModule(.{
        .root_source_file = b.path("zoop_src/console/format.zig"),
        .target = target,
    });

    const console_console_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/console/console.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "zoop", .module = zoop },
            .{ .name = "types", .module = console_types_mod },
            .{ .name = "format", .module = console_format_mod },
        },
    });

    const console_mod = b.addModule("console", .{
        .root_source_file = b.path("src/console/root.zig"),
        .target = target,
    });
    console_mod.addImport("webidl", webidl_mod);
    console_mod.addImport("zoop", zoop);
    // Add imports for generated files
    console_mod.addImport("console", console_console_mod);
    console_mod.addImport("types", console_types_mod);

    // Streams internal modules (used by both root.zig and generated interfaces)
    // All internal files need to import each other via modules to avoid circular file ownership

    const streams_common_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/common.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
        },
    });

    const streams_queue_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/queue_with_sizes.zig"),
        .target = target,
        .imports = &.{
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
        },
    });

    const streams_read_into_request_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/read_into_request.zig"),
        .target = target,
    });

    const streams_pull_into_descriptor_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/pull_into_descriptor.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
        },
    });

    const streams_event_loop_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/event_loop.zig"),
        .target = target,
    });

    const streams_test_event_loop_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/test_event_loop.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "event_loop", .module = streams_event_loop_mod },
        },
    });

    const streams_async_promise_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/async_promise.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "common", .module = streams_common_mod },
            .{ .name = "event_loop", .module = streams_event_loop_mod },
            .{ .name = "test_event_loop", .module = streams_test_event_loop_mod },
        },
    });

    const streams_dict_types_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/dictionary_types.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "common", .module = streams_common_mod },
        },
    });

    // Note: dict_parsing needs readable_stream and writable_stream added later
    // after those modules are created (see below where we add them)
    const streams_dict_parsing_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/dictionary_parsing.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "common", .module = streams_common_mod },
            .{ .name = "dict_types", .module = streams_dict_types_mod },
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

    // Main streams module
    const streams_mod = b.addModule("streams", .{
        .root_source_file = b.path("src/streams/root.zig"),
        .target = target,
    });
    streams_mod.addImport("infra", infra_mod);
    streams_mod.addImport("webidl", webidl_mod);
    streams_mod.addImport("zoop", zoop);
    // Add internal modules so root.zig can access them
    streams_mod.addImport("common", streams_common_mod);
    streams_mod.addImport("queue_with_sizes", streams_queue_mod);
    streams_mod.addImport("read_request", streams_read_request_mod);
    streams_mod.addImport("read_into_request", streams_read_into_request_mod);
    streams_mod.addImport("pull_into_descriptor", streams_pull_into_descriptor_mod);
    streams_mod.addImport("write_request", streams_write_request_mod);

    // Create interface modules that reference the main streams module for internals
    // This avoids the module collision by sharing the same internal file instances
    const streams_iface_imports = [_]std.Build.Module.Import{
        .{ .name = "infra", .module = infra_mod },
        .{ .name = "webidl", .module = webidl_mod },
        .{ .name = "zoop", .module = zoop },
        .{ .name = "common", .module = streams_common_mod },
        .{ .name = "queue_with_sizes", .module = streams_queue_mod },
        .{ .name = "read_request", .module = streams_read_request_mod },
        .{ .name = "read_into_request", .module = streams_read_into_request_mod },
        .{ .name = "pull_into_descriptor", .module = streams_pull_into_descriptor_mod },
        .{ .name = "dict_parsing", .module = streams_dict_parsing_mod },
        .{ .name = "event_loop", .module = streams_event_loop_mod },
        .{ .name = "async_promise", .module = streams_async_promise_mod },
        .{ .name = "test_event_loop", .module = streams_test_event_loop_mod },
        .{ .name = "view_construction", .module = streams_view_construction_mod },
    };

    const byte_length_queuing_strategy_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/byte_length_queuing_strategy.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const count_queuing_strategy_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/count_queuing_strategy.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const readable_stream_default_controller_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/readable_stream_default_controller.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const writable_stream_default_controller_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/writable_stream_default_controller.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const transform_stream_default_controller_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/transform_stream_default_controller.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const readable_stream_byob_request_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/readable_stream_byob_request.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const readable_byte_stream_controller_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/readable_byte_stream_controller.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const readable_stream_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/readable_stream.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const readable_stream_default_reader_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/readable_stream_default_reader.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const readable_stream_byob_reader_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/readable_stream_byob_reader.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const writable_stream_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/writable_stream.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const writable_stream_default_writer_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/writable_stream_default_writer.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    const transform_stream_mod = b.createModule(.{
        .root_source_file = b.path("interfaces/streams/transform_stream.zig"),
        .target = target,
        .imports = &streams_iface_imports,
    });

    // Add interface modules to streams
    streams_mod.addImport("byte_length_queuing_strategy", byte_length_queuing_strategy_mod);
    streams_mod.addImport("count_queuing_strategy", count_queuing_strategy_mod);
    streams_mod.addImport("readable_stream_default_controller", readable_stream_default_controller_mod);
    streams_mod.addImport("writable_stream_default_controller", writable_stream_default_controller_mod);
    streams_mod.addImport("transform_stream_default_controller", transform_stream_default_controller_mod);
    streams_mod.addImport("readable_stream_byob_request", readable_stream_byob_request_mod);
    streams_mod.addImport("readable_byte_stream_controller", readable_byte_stream_controller_mod);
    streams_mod.addImport("readable_stream", readable_stream_mod);
    streams_mod.addImport("readable_stream_default_reader", readable_stream_default_reader_mod);
    streams_mod.addImport("readable_stream_byob_reader", readable_stream_byob_reader_mod);
    streams_mod.addImport("writable_stream", writable_stream_mod);
    streams_mod.addImport("writable_stream_default_writer", writable_stream_default_writer_mod);
    streams_mod.addImport("transform_stream", transform_stream_mod);

    // Add cross-module imports to resolve circular dependencies
    // All interface modules need access to each other for proper operation

    // dict_parsing needs the stream types
    streams_dict_parsing_mod.addImport("readable_stream", readable_stream_mod);
    streams_dict_parsing_mod.addImport("writable_stream", writable_stream_mod);

    // readable_stream needs its controllers and readers, plus writable components for pipeTo
    readable_stream_mod.addImport("readable_stream_default_controller", readable_stream_default_controller_mod);
    readable_stream_mod.addImport("readable_stream_default_reader", readable_stream_default_reader_mod);
    readable_stream_mod.addImport("readable_stream_byob_reader", readable_stream_byob_reader_mod);
    readable_stream_mod.addImport("readable_byte_stream_controller", readable_byte_stream_controller_mod);
    readable_stream_mod.addImport("writable_stream", writable_stream_mod);
    readable_stream_mod.addImport("writable_stream_default_writer", writable_stream_default_writer_mod);

    // writable_stream needs its controller and writer
    writable_stream_mod.addImport("writable_stream_default_controller", writable_stream_default_controller_mod);
    writable_stream_mod.addImport("writable_stream_default_writer", writable_stream_default_writer_mod);

    // transform_stream needs readable and writable streams
    transform_stream_mod.addImport("readable_stream", readable_stream_mod);
    transform_stream_mod.addImport("writable_stream", writable_stream_mod);
    transform_stream_mod.addImport("transform_stream_default_controller", transform_stream_default_controller_mod);

    // Controllers need their parent streams
    readable_stream_default_controller_mod.addImport("readable_stream", readable_stream_mod);
    writable_stream_default_controller_mod.addImport("writable_stream", writable_stream_mod);
    writable_stream_default_controller_mod.addImport("transform_stream_default_controller", transform_stream_default_controller_mod);
    transform_stream_default_controller_mod.addImport("transform_stream", transform_stream_mod);
    transform_stream_default_controller_mod.addImport("readable_stream", readable_stream_mod);

    // Readers/writers need their parent streams
    readable_stream_default_reader_mod.addImport("readable_stream", readable_stream_mod);
    readable_stream_byob_reader_mod.addImport("readable_stream", readable_stream_mod);
    readable_stream_byob_reader_mod.addImport("readable_byte_stream_controller", readable_byte_stream_controller_mod);
    writable_stream_default_writer_mod.addImport("writable_stream", writable_stream_mod);

    // Byte stream controller needs BYOB request and readable stream
    readable_byte_stream_controller_mod.addImport("readable_stream", readable_stream_mod);
    readable_byte_stream_controller_mod.addImport("readable_stream_byob_request", readable_stream_byob_request_mod);

    // BYOB request needs byte stream controller (circular dependency)
    readable_stream_byob_request_mod.addImport("readable_byte_stream_controller", readable_byte_stream_controller_mod);

    const mimesniff_mod = b.addModule("mimesniff", .{
        .root_source_file = b.path("src/mimesniff/root.zig"),
        .target = target,
    });
    mimesniff_mod.addImport("infra", infra_mod);

    // Wire spec modules into whatwg module
    whatwg_mod.addImport("infra", infra_mod);
    whatwg_mod.addImport("webidl", webidl_mod);
    whatwg_mod.addImport("encoding", encoding_mod);
    whatwg_mod.addImport("url", url_mod);
    whatwg_mod.addImport("console", console_mod);
    whatwg_mod.addImport("streams", streams_mod);
    whatwg_mod.addImport("mimesniff", mimesniff_mod);

    // ========================================================================
    // TESTS - GENERIC SPEC FILTERING
    // ========================================================================

    const test_step = b.step("test", "Run WHATWG spec tests (use -Dspec=<name> to filter)");

    const test_all = spec_filter == null or std.mem.eql(u8, spec_filter.?, "all");
    const test_infra = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "infra"));
    const test_webidl = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "webidl"));
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
    }

    if (test_encoding) {
        const encoding_tests = b.addTest(.{ .root_module = encoding_mod });
        const run_encoding_tests = b.addRunArtifact(encoding_tests);
        test_step.dependOn(&run_encoding_tests.step);
    }

    if (test_url) {
        const url_tests = b.addTest(.{ .root_module = url_mod });
        const run_url_tests = b.addRunArtifact(url_tests);
        test_step.dependOn(&run_url_tests.step);
    }

    if (test_console) {
        const console_tests = b.addTest(.{ .root_module = console_mod });
        const run_console_tests = b.addRunArtifact(console_tests);
        test_step.dependOn(&run_console_tests.step);
    }

    if (test_streams) {
        const streams_tests = b.addTest(.{ .root_module = streams_mod });
        const run_streams_tests = b.addRunArtifact(streams_tests);
        test_step.dependOn(&run_streams_tests.step);
    }

    if (test_mimesniff) {
        const mimesniff_tests = b.addTest(.{ .root_module = mimesniff_mod });
        const run_mimesniff_tests = b.addRunArtifact(mimesniff_tests);
        test_step.dependOn(&run_mimesniff_tests.step);
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
}
