# Spec Compliance: Template fragment parsing uses the content registry

**Date**: 2026-10-07

**Lesson**: A template element's own custom-element registry is not the registry for nodes parsed into its inert content.

**Why**: HTML fragment parsing step 17 makes a DocumentFragment the root insertion target. The parser's create-for-token step 6 looks up the custom-element registry of the intended parent, which is the template content fragment for `template.innerHTML`.

**What Happened**: A shared fragment converter copied the context element's registry into every top-level parsed node. That gave `template.innerHTML` descendants the document's global registry, causing custom-element constructors to run unexpectedly. Two custom-element WPT files became harness ERRORs even though most of their subtests passed.

**Fix**: Keep the template context for tokenizer and insertion-mode setup, but pass an explicit null registry when converting its root descendants. Continue to pass the target registry for ordinary element and shadow-root fragment contexts. Test both top-level template content and nested templates under `std.testing.allocator`, then rerun the affected script-visible WPT files.

**Takeaway**: **For parser-created elements, derive registry from the intended insertion parent, not just the fragment context.**
