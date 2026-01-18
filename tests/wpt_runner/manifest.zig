//! WPT MANIFEST.json Parser
//!
//! This module parses the official WPT MANIFEST.json file to resolve
//! test URLs to source files. The manifest is the authoritative source
//! for test discovery in WPT.
//!
//! ## Manifest Structure
//!
//! The MANIFEST.json has this structure:
//! ```json
//! {
//!   "version": 8,
//!   "url_base": "/",
//!   "items": {
//!     "testharness": {
//!       "url": {
//!         "url-searchparams.any.js": [
//!           "hash",
//!           ["url/url-searchparams.any.html", {}],
//!           ["url/url-searchparams.any.worker.html", {}]
//!         ]
//!       }
//!     }
//!   }
//! }
//! ```
//!
//! For .any.js files, the manifest maps the source file to multiple
//! virtual test URLs (.any.html, .any.worker.html, etc.)

const std = @import("std");
const Allocator = std.mem.Allocator;

/// URL list type for storing test URLs per source file
const UrlList = std.ArrayListUnmanaged([]const u8);

/// WPT Manifest - maps test URLs to source files
pub const Manifest = struct {
    allocator: Allocator,
    /// Maps test URL (e.g., "url/url-searchparams.any.html") to source file (e.g., "url/url-searchparams.any.js")
    url_to_source: std.StringHashMap([]const u8),
    /// Maps source file to list of test URLs
    source_to_urls: std.StringHashMap(UrlList),

    pub fn init(allocator: Allocator) Manifest {
        return .{
            .allocator = allocator,
            .url_to_source = std.StringHashMap([]const u8).init(allocator),
            .source_to_urls = std.StringHashMap(UrlList).init(allocator),
        };
    }

    pub fn deinit(self: *Manifest) void {
        // Free url_to_source keys and values
        var url_iter = self.url_to_source.iterator();
        while (url_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.url_to_source.deinit();

        // Free source_to_urls
        var source_iter = self.source_to_urls.iterator();
        while (source_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.items) |url| {
                self.allocator.free(url);
            }
            entry.value_ptr.deinit(self.allocator);
        }
        self.source_to_urls.deinit();
    }

    /// Resolve a test URL to its source file
    /// Returns null if the URL is not found in the manifest
    pub fn resolveUrlToSource(self: *Manifest, test_url: []const u8) ?[]const u8 {
        // Strip leading slash if present (WPT URLs can have leading /)
        const url = if (test_url.len > 0 and test_url[0] == '/') test_url[1..] else test_url;

        // Try exact match first
        if (self.url_to_source.get(url)) |source| {
            return source;
        }

        // If no exact match, check if this URL is the base of a URL with query parameters
        // e.g., "url/url-constructor.any.html" should match "url/url-constructor.any.html?include=file"
        var iter = self.url_to_source.iterator();
        while (iter.next()) |entry| {
            const manifest_url = entry.key_ptr.*;
            // Check if manifest URL starts with our URL and has a '?' after it
            if (manifest_url.len > url.len and
                std.mem.startsWith(u8, manifest_url, url) and
                manifest_url[url.len] == '?')
            {
                return entry.value_ptr.*;
            }
        }

        return null;
    }

    /// Get all test URLs for a source file
    pub fn getUrlsForSource(self: *Manifest, source_file: []const u8) ?[]const []const u8 {
        if (self.source_to_urls.get(source_file)) |list| {
            return list.items;
        }
        return null;
    }
};

/// Load and parse the WPT MANIFEST.json file
pub fn loadManifest(allocator: Allocator, wpt_root: []const u8) !Manifest {
    var manifest = Manifest.init(allocator);
    errdefer manifest.deinit();

    // Build path to MANIFEST.json
    const manifest_path = try std.fs.path.join(allocator, &.{ wpt_root, "MANIFEST.json" });
    defer allocator.free(manifest_path);

    // Read the manifest file
    const file = std.fs.cwd().openFile(manifest_path, .{}) catch |err| {
        std.debug.print("Warning: Could not open MANIFEST.json: {}\n", .{err});
        std.debug.print("  Path: {s}\n", .{manifest_path});
        std.debug.print("  Run 'wpt manifest' to generate it.\n", .{});
        return manifest; // Return empty manifest
    };
    defer file.close();

    // Read file contents
    const stat = try file.stat();
    const contents = try allocator.alloc(u8, stat.size);
    defer allocator.free(contents);
    _ = try file.readAll(contents);

    // Parse JSON
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch |err| {
        std.debug.print("Warning: Failed to parse MANIFEST.json: {}\n", .{err});
        return manifest;
    };
    defer parsed.deinit();

    const root = parsed.value;

    // Navigate to items.testharness
    const items = root.object.get("items") orelse return manifest;
    const testharness = items.object.get("testharness") orelse return manifest;

    // Iterate over directories in testharness
    var dir_iter = testharness.object.iterator();
    while (dir_iter.next()) |dir_entry| {
        const dir_name = dir_entry.key_ptr.*;
        const dir_tests = dir_entry.value_ptr.*;

        // Iterate over test files in this directory
        var test_iter = dir_tests.object.iterator();
        while (test_iter.next()) |test_entry| {
            const source_filename = test_entry.key_ptr.*;
            const test_data = test_entry.value_ptr.*;

            // The test_data is an array: [hash, [url1, options], [url2, options], ...]
            // Check conditions BEFORE allocating source_path to avoid leaks on continue
            if (test_data != .array) continue;
            const items_array = test_data.array.items;
            if (items_array.len < 2) continue;

            // Build the full source path (e.g., "url/url-searchparams.any.js")
            const source_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_name, source_filename });
            errdefer allocator.free(source_path);

            // Create list of URLs for this source
            var url_list: UrlList = .{};
            errdefer {
                for (url_list.items) |url| allocator.free(url);
                url_list.deinit(allocator);
            }

            // Skip first element (hash), process the rest (test URLs)
            for (items_array[1..]) |item| {
                if (item != .array) continue;
                const url_array = item.array.items;
                if (url_array.len == 0) continue;

                if (url_array[0] == .string) {
                    const test_url = url_array[0].string;
                    const url_copy = try allocator.dupe(u8, test_url);
                    errdefer allocator.free(url_copy);

                    // Add to url_to_source mapping
                    const source_copy_for_url = try allocator.dupe(u8, source_path);
                    try manifest.url_to_source.put(url_copy, source_copy_for_url);

                    // Add to source's url list
                    try url_list.append(allocator, try allocator.dupe(u8, test_url));
                }
            }

            // Store the url list for this source
            if (url_list.items.len > 0) {
                try manifest.source_to_urls.put(source_path, url_list);
            } else {
                allocator.free(source_path);
                url_list.deinit(allocator);
            }
        }
    }

    return manifest;
}

// Tests
test "Manifest init and deinit" {
    const allocator = std.testing.allocator;
    var manifest = Manifest.init(allocator);
    defer manifest.deinit();
}

test "resolveUrlToSource strips leading slash" {
    const allocator = std.testing.allocator;
    var manifest = Manifest.init(allocator);
    defer manifest.deinit();

    // Add a test mapping
    const url = try allocator.dupe(u8, "url/test.any.html");
    const source = try allocator.dupe(u8, "url/test.any.js");
    try manifest.url_to_source.put(url, source);

    // Should resolve with or without leading slash
    try std.testing.expectEqualStrings("url/test.any.js", manifest.resolveUrlToSource("url/test.any.html").?);
    try std.testing.expectEqualStrings("url/test.any.js", manifest.resolveUrlToSource("/url/test.any.html").?);
}
