//! A Browser's pages opening a file chooser (<input type="file"> activation
//! or showPicker()), as its host sees them: the Browser's one hook slot
//! (`Navigables.file_chooser`), set to its own dispatcher, which fans out to
//! the host's listeners (CDP's Page.setInterceptFileChooserDialog /
//! Page.fileChooserOpened; Blink's FileInputType::OpenPopupView ->
//! ChromeClient::OpenFileChooser -> InspectorPageAgent::InterceptFileChooserDialog).
const browsing_context = @import("../window/browsing_context.zig");

const Navigables = browsing_context.Navigables;

/// A request to open a file chooser for an `<input type="file">` element.
pub const Opening = struct {
    /// The input's top-level traversable (its tab) and its own navigable.
    tab: u64,
    navigable: u64,
    /// The `<input type="file">` `*runtime.Instance` (opaque in html_core).
    input: *anyopaque,
    /// Whether the input has the `multiple` attribute.
    multiple: bool,
    /// Set by a listener that intercepts the file chooser (CDP
    /// `Page.setInterceptFileChooserDialog { enabled: true }`). When true,
    /// no native picker is shown and `cancel` decides whether a `cancel`
    /// event is queued.
    intercepted: *bool,
    /// Set when an intercepting listener asked to cancel the chooser (CDP
    /// `Page.setInterceptFileChooserDialog { enabled: true, cancel: true }`).
    cancel: *bool,
};

/// The Browser's hook (`Navigables.file_chooser`).
pub const Hook = struct {
    context: *anyopaque,
    opening: *const fn (context: *anyopaque, request: *const Opening) void,
};

/// Tell `navigables`' hook that a page is opening a file chooser.
pub fn opened(navigables: ?*const Navigables, request: *const Opening) void {
    const list = navigables orelse return;
    const hook = list.file_chooser orelse return;
    hook.opening(hook.context, request);
}
