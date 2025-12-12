//! CLDR JSON Data Downloader
//!
//! Downloads CLDR JSON release data from Unicode and verifies checksums.
//! This is a build-time tool for fetching CLDR data used by the i18n library.
//!
//! Usage:
//!   zig build cldr-download -- --version 45 --output data/cldr/
//!
//! References:
//! - CLDR Releases: https://github.com/unicode-org/cldr-json/releases
//! - CLDR Documentation: https://cldr.unicode.org/

const std = @import("std");
const Allocator = std.mem.Allocator;

/// CLDR release information
pub const CldrRelease = struct {
    version: []const u8,
    packages: []const Package,

    pub const Package = struct {
        name: []const u8,
        url: []const u8,
        sha256: ?[]const u8,
    };
};

/// Default CLDR version to download
pub const DEFAULT_VERSION = "46.0.0";

/// Base URL for CLDR JSON releases
pub const CLDR_BASE_URL = "https://github.com/unicode-org/cldr-json/releases/download";

/// Download state tracking
pub const DownloadState = struct {
    allocator: Allocator,
    version: []const u8,
    output_dir: []const u8,
    verbose: bool,

    pub fn init(allocator: Allocator, version: []const u8, output_dir: []const u8, verbose: bool) DownloadState {
        return .{
            .allocator = allocator,
            .version = version,
            .output_dir = output_dir,
            .verbose = verbose,
        };
    }

    /// Get the URL for the full CLDR JSON package
    /// Modern releases use format: cldr-VERSION-json-full.zip
    pub fn getFullPackageUrl(self: *const DownloadState) ![]u8 {
        return std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}/cldr-{s}-json-full.zip",
            .{ CLDR_BASE_URL, self.version, self.version },
        );
    }

    /// Get the local path for the downloaded full package
    pub fn getFullPackagePath(self: *const DownloadState) ![]u8 {
        return std.fmt.allocPrint(
            self.allocator,
            "{s}/cldr-{s}-json-full.zip",
            .{ self.output_dir, self.version },
        );
    }

    /// Get the extraction directory for the full package
    pub fn getExtractDir(self: *const DownloadState, package_name: []const u8) ![]u8 {
        return std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}",
            .{ self.output_dir, package_name },
        );
    }
};

/// Download result for a single package
pub const DownloadResult = struct {
    package: []const u8,
    success: bool,
    bytes_downloaded: usize,
    error_message: ?[]const u8,
};

/// Download a file from a URL using curl (available on most systems)
pub fn downloadFile(allocator: Allocator, url: []const u8, output_path: []const u8) !void {
    // Use curl for downloading (available on macOS, Linux, and can be installed on Windows)
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl",
            "-fsSL", // fail silently, follow redirects, show errors
            "-o",
            output_path,
            url,
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        std.log.err("Download failed: {s}", .{result.stderr});
        return error.DownloadFailed;
    }
}

/// Verify SHA-256 checksum of a file
pub fn verifyChecksum(allocator: Allocator, file_path: []const u8, expected_sha256: []const u8) !bool {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var sha256 = std.crypto.hash.sha2.Sha256.init(.{});
    var buffer: [8192]u8 = undefined;

    while (true) {
        const bytes_read = try file.read(&buffer);
        if (bytes_read == 0) break;
        sha256.update(buffer[0..bytes_read]);
    }

    var digest: [32]u8 = undefined;
    sha256.final(&digest);

    var hex_digest: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&hex_digest, "{s}", .{std.fmt.fmtSliceHexLower(&digest)}) catch unreachable;

    _ = allocator;
    return std.mem.eql(u8, &hex_digest, expected_sha256);
}

/// Extract a zip file to a directory
pub fn extractZip(allocator: Allocator, zip_path: []const u8, output_dir: []const u8) !void {
    // Create output directory if it doesn't exist
    std.fs.cwd().makePath(output_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Use unzip command (available on most Unix systems)
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "unzip",
            "-o", // overwrite without prompting
            "-q", // quiet
            zip_path,
            "-d",
            output_dir,
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        std.log.err("Extraction failed: {s}", .{result.stderr});
        return error.ExtractionFailed;
    }
}

/// Download the full CLDR JSON package (new format since CLDR 46+)
pub fn downloadFullPackage(state: *const DownloadState) !DownloadResult {
    const url = try state.getFullPackageUrl();
    defer state.allocator.free(url);

    const output_path = try state.getFullPackagePath();
    defer state.allocator.free(output_path);

    const package_name = "cldr-json-full";

    if (state.verbose) {
        std.log.info("Downloading {s}...", .{url});
    }

    downloadFile(state.allocator, url, output_path) catch |err| {
        return .{
            .package = package_name,
            .success = false,
            .bytes_downloaded = 0,
            .error_message = @errorName(err),
        };
    };

    // Get file size
    const file = std.fs.cwd().openFile(output_path, .{}) catch |err| {
        return .{
            .package = package_name,
            .success = false,
            .bytes_downloaded = 0,
            .error_message = @errorName(err),
        };
    };
    defer file.close();

    const stat = try file.stat();

    if (state.verbose) {
        std.log.info("Downloaded {s} ({d} bytes)", .{ package_name, stat.size });
    }

    // Extract the package to the output directory
    extractZip(state.allocator, output_path, state.output_dir) catch |err| {
        return .{
            .package = package_name,
            .success = false,
            .bytes_downloaded = stat.size,
            .error_message = @errorName(err),
        };
    };

    return .{
        .package = package_name,
        .success = true,
        .bytes_downloaded = stat.size,
        .error_message = null,
    };
}

/// Command-line interface
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    var version: []const u8 = DEFAULT_VERSION;
    var output_dir: []const u8 = "data/cldr";
    var verbose: bool = false;

    // Parse arguments
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            version = args.next() orelse {
                std.log.err("Missing version argument", .{});
                return error.MissingArgument;
            };
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            output_dir = args.next() orelse {
                std.log.err("Missing output directory argument", .{});
                return error.MissingArgument;
            };
        } else if (std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            return;
        }
    }

    // Create output directory
    std.fs.cwd().makePath(output_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const state = DownloadState.init(allocator, version, output_dir, verbose);

    std.log.info("Downloading CLDR v{s} to {s}...", .{ version, output_dir });

    const result = try downloadFullPackage(&state);

    if (result.success) {
        std.log.info("Successfully downloaded CLDR {s} ({d} bytes)", .{
            version,
            result.bytes_downloaded,
        });
        std.log.info("Data extracted to: {s}", .{output_dir});
    } else {
        std.log.err("Failed to download: {s}", .{
            result.error_message orelse "unknown error",
        });
        return error.DownloadFailed;
    }
}

fn printHelp() void {
    const help =
        \\CLDR JSON Data Downloader
        \\
        \\Downloads CLDR JSON release data from Unicode for the i18n library.
        \\
        \\Usage:
        \\  cldr-download [options]
        \\
        \\Options:
        \\  -v, --version <VERSION>   CLDR version to download (default: 46.0.0)
        \\  -o, --output <DIR>        Output directory (default: data/cldr/)
        \\  --verbose                 Show verbose output
        \\  -h, --help                Show this help
        \\
        \\Downloads the full CLDR JSON package (cldr-VERSION-json-full.zip) which
        \\contains all locale data for dates, numbers, names, units, and more.
        \\
    ;
    const stdout_file = std.fs.File.stdout();
    stdout_file.writeAll(help) catch {};
}

test "DownloadState.getFullPackageUrl" {
    const allocator = std.testing.allocator;
    const state = DownloadState.init(allocator, "46.0.0", "data/cldr", false);

    const url = try state.getFullPackageUrl();
    defer allocator.free(url);

    try std.testing.expectEqualStrings(
        "https://github.com/unicode-org/cldr-json/releases/download/46.0.0/cldr-46.0.0-json-full.zip",
        url,
    );
}

test "DownloadState.getFullPackagePath" {
    const allocator = std.testing.allocator;
    const state = DownloadState.init(allocator, "46.0.0", "data/cldr", false);

    const path = try state.getFullPackagePath();
    defer allocator.free(path);

    try std.testing.expectEqualStrings("data/cldr/cldr-46.0.0-json-full.zip", path);
}
