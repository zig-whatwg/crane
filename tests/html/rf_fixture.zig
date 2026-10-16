//! Engine-free document fixture for reflection algorithms.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const allocator = std.testing.allocator;

pub fn str(value: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(value);
}

pub const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    element: *runtime.Instance,

    pub fn open(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{
            .scope = runtime.BrowserScope.init(allocator),
            .ctx = undefined,
            .document = undefined,
            .element = undefined,
        };
        errdefer self.scope.deinit();
        self.ctx = try runtime.ContextData.init(allocator, .{});
        errdefer self.ctx.deinit();
        self.ctx.browser_scope = &self.scope;
        errdefer dom.teardown_sweeps.runAll(&self.scope);
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        errdefer interfaces.Document.deinit(self.document);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.element = try self.append(self.document, "div");
    }

    pub fn append(self: *Page, parent: *runtime.Instance, tag: []const u8) !*runtime.Instance {
        const element = try interfaces.Document.call_createElement(self.document, str(tag), .notPassed());
        errdefer runtime.Instance.deinit(element);
        _ = try interfaces.Node.call_appendChild(parent, element);
        return element;
    }

    pub fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};
