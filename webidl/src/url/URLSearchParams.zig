const std = @import("std");
const webidl = @import("webidl");

// Import internal implementation
const URLSearchParamsImpl = @import("url_search_params_impl").URLSearchParamsImpl;

pub const URLSearchParams = webidl.interface(struct {
    // ========================================================================
    // Internal Implementation
    // ========================================================================

    /// The internal implementation wrapping all the logic
    impl: URLSearchParamsImpl,

    // ========================================================================
    // Constructor
    // ========================================================================

    /// Initialize URLSearchParams with empty list
    pub fn init(allocator: std.mem.Allocator) !URLSearchParams {
        return .{
            .impl = URLSearchParamsImpl.init(allocator),
        };
    }

    /// Initialize URLSearchParams from query string
    /// Spec: https://url.spec.whatwg.org/#concept-urlsearchparams-new (lines 2041-2056)
    pub fn initWithString(allocator: std.mem.Allocator, query: []const u8) !URLSearchParams {
        return .{
            .impl = try URLSearchParamsImpl.initFromString(allocator, query),
        };
    }

    pub fn deinit(self: *URLSearchParams) void {
        self.impl.deinit();
    }

    // ========================================================================
    // Update Steps Algorithm
    // ========================================================================

    /// Update a URLSearchParams object
    /// Spec: https://url.spec.whatwg.org/#concept-urlsearchparams-update (lines 2057-2065)
    pub fn updateSteps(self: *URLSearchParams) !void {
        try self.impl.update();
    }

    // ========================================================================
    // Attributes
    // ========================================================================

    /// size attribute getter
    /// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-size (line 2062)
    pub fn size(self: *const URLSearchParams) usize {
        return self.impl.list.items.len;
    }

    // ========================================================================
    // Methods (delegate to impl - will be fully implemented in subsequent beads)
    // ========================================================================

    // Methods will be implemented in:
    // - whatwg-rmz: append()
    // - whatwg-1fo: delete()
    // - whatwg-0lz: get()
    // - whatwg-7in: getAll()
    // - whatwg-5g2: has()
    // - whatwg-jle: set()
    // - whatwg-fxm: sort()
    // - whatwg-1wv: iteration support
    // - whatwg-3cn: stringifier

}, .{
    .exposed = &.{.global},
});
