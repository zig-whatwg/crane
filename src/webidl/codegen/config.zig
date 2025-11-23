//! Code Generation Configuration
//!
//! Configuration for the WebIDL code generator with organized directory structure.
//! Uses absolute paths for output locations.

const std = @import("std");

/// Configuration for WebIDL code generation
pub const CodegenConfig = struct {
    /// Allocator for config operations
    allocator: std.mem.Allocator,

    /// Root destination directory for all generated code
    /// All subdirectories will be created under this root
    dest_root: ?[]const u8 = null,

    /// Whether to generate implementation stub files
    /// When true and dest_root is set, generates to {dest_root}/impls
    generate_impls: bool = false,

    // Cached computed paths (allocated from dest_root)
    cached_interfaces_path: ?[]const u8 = null,
    cached_typedefs_path: ?[]const u8 = null,
    cached_dictionaries_path: ?[]const u8 = null,
    cached_enums_path: ?[]const u8 = null,
    cached_callbacks_path: ?[]const u8 = null,
    cached_namespaces_path: ?[]const u8 = null,
    cached_impls_path: ?[]const u8 = null,

    /// Create default configuration (generates nothing)
    pub fn default(allocator: std.mem.Allocator) CodegenConfig {
        return .{
            .allocator = allocator,
        };
    }

    /// Free all cached paths allocated during getXxxPath() calls
    pub fn deinit(self: *CodegenConfig) void {
        if (self.cached_interfaces_path) |path| self.allocator.free(path);
        if (self.cached_typedefs_path) |path| self.allocator.free(path);
        if (self.cached_dictionaries_path) |path| self.allocator.free(path);
        if (self.cached_enums_path) |path| self.allocator.free(path);
        if (self.cached_callbacks_path) |path| self.allocator.free(path);
        if (self.cached_namespaces_path) |path| self.allocator.free(path);
        if (self.cached_impls_path) |path| self.allocator.free(path);
    }

    /// Get the interfaces path from dest_root
    /// Caches the result to avoid repeated allocations
    pub fn getInterfacesPath(self: *CodegenConfig) !?[]const u8 {
        if (self.cached_interfaces_path) |path| return path;
        if (self.dest_root) |root| {
            const path = try std.fs.path.join(self.allocator, &.{ root, "interfaces" });
            self.cached_interfaces_path = path;
            return path;
        }
        return null;
    }

    /// Get the impls path, using dest_root if generate_impls is enabled
    /// Caches the result to avoid repeated allocations
    pub fn getImplsPath(self: *CodegenConfig) !?[]const u8 {
        if (!self.generate_impls) return null;
        if (self.cached_impls_path) |path| return path;
        if (self.dest_root) |root| {
            const path = try std.fs.path.join(self.allocator, &.{ root, "impls" });
            self.cached_impls_path = path;
            return path;
        }
        return null;
    }

    /// Get the typedefs path from dest_root
    /// Caches the result to avoid repeated allocations
    pub fn getTypedefsPath(self: *CodegenConfig) !?[]const u8 {
        if (self.cached_typedefs_path) |path| return path;
        if (self.dest_root) |root| {
            const path = try std.fs.path.join(self.allocator, &.{ root, "typedefs" });
            self.cached_typedefs_path = path;
            return path;
        }
        return null;
    }

    /// Get the dictionaries path from dest_root
    /// Caches the result to avoid repeated allocations
    pub fn getDictionariesPath(self: *CodegenConfig) !?[]const u8 {
        if (self.cached_dictionaries_path) |path| return path;
        if (self.dest_root) |root| {
            const path = try std.fs.path.join(self.allocator, &.{ root, "dictionaries" });
            self.cached_dictionaries_path = path;
            return path;
        }
        return null;
    }

    /// Get the enums path from dest_root
    /// Caches the result to avoid repeated allocations
    pub fn getEnumsPath(self: *CodegenConfig) !?[]const u8 {
        if (self.cached_enums_path) |path| return path;
        if (self.dest_root) |root| {
            const path = try std.fs.path.join(self.allocator, &.{ root, "enums" });
            self.cached_enums_path = path;
            return path;
        }
        return null;
    }

    /// Get the callbacks path from dest_root
    /// Caches the result to avoid repeated allocations
    pub fn getCallbacksPath(self: *CodegenConfig) !?[]const u8 {
        if (self.cached_callbacks_path) |path| return path;
        if (self.dest_root) |root| {
            const path = try std.fs.path.join(self.allocator, &.{ root, "callbacks" });
            self.cached_callbacks_path = path;
            return path;
        }
        return null;
    }

    /// Get the namespaces path from dest_root
    /// Caches the result to avoid repeated allocations
    pub fn getNamespacesPath(self: *CodegenConfig) !?[]const u8 {
        if (self.cached_namespaces_path) |path| return path;
        if (self.dest_root) |root| {
            const path = try std.fs.path.join(self.allocator, &.{ root, "namespaces" });
            self.cached_namespaces_path = path;
            return path;
        }
        return null;
    }

    /// Check if interfaces should be generated
    pub fn shouldGenerateInterfaces(self: CodegenConfig) bool {
        return self.dest_root != null;
    }

    /// Check if impls should be generated
    pub fn shouldGenerateImpls(self: CodegenConfig) bool {
        return self.generate_impls and self.dest_root != null;
    }
};
