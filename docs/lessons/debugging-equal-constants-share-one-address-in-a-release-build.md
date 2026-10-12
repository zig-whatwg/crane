# Debugging: Equal constants - and identical functions - share one address in a release build

**Date**: 2026-10-02
**Lesson**: Zig keeps distinct variables at distinct addresses, but not equal
constants. `typeId(T)` was the address of a per-type `const marker: u8 = 0`;
a ReleaseSafe build merged all 1,068 of them into one symbol, and every
`Instance.stateAs` brand check passed.

**Why**: `stateAs(T)` walks the instance's vtable ancestry comparing each
level's `typeId` with `typeId(T)`. With every id equal, the first level
matched whatever `T` was asked for, and its state was returned as a `*T`.
LLVM marks constants `unnamed_addr` and merges identical ones; Debug does not
run that pass. `nm` told the whole story: 1,068 `TypeIdHolder(...).marker`
symbols in the Debug runner, ONE in the ReleaseSafe runner.

**What Happened**: after the callback-pointer fix, the ReleaseSafe runner
still crashed FileAPI/url/url-with-xhr.any.js (SIGSEGV in
`ErrorEvent.get_filename`). The event handler processing algorithm's
"special error event handling" asks two brand questions - is the event an
ErrorEvent, is the target a Window or WorkerGlobalScope - and an
XMLHttpRequest's `error` ProgressEvent answered yes to both, so its state was
read as an ErrorEvent's. crane/td-event-handler-brand.html: Debug 4/4,
ReleaseSafe 1/4 (an ErrorEvent at a `div` reached `onerror` with five
arguments).

**Fix**: `var marker: u8 = 0` - the idiom for a unique address per type (Zig
merges no variables). Marked `// process-wide:` for lint-global-state: an
address, never written. tests/runtime/state_brand_test.zig pins distinct ids
for two same-shaped types; the Crane test is what shows the merge.

**Takeaway**: **An identity built on the address of a `const` is an identity
only in Debug. Use a `var` (or a value) when the address must be unique, and
check a release binary with `nm` when identities misbehave there.**

## The same for functions (2026-10-11)

**What Happened**: the parity runs of the ReleaseSafe runner (lane relsafe)
showed three files doing worse than in Debug, 3 of 3 times:
dom/nodes/Element-closest.html (`:invalid`),
dom/nodes/namespaced-attribute-mutations.html (a select's reset and an
option's selectedness threw NotSupported), and
crane/hd-form-collections-keep-root.html. `dom.form_controls.install` keyed
its entries by the brand-check function (`existing.is == control.is`,
replace). HTMLSelectElement installs a select's validity flags with
`isValidationControl`, and HTMLOptionElement installs the select's selection
model and reset with `isSelectElement`. Both functions are
`stateAs(HTMLSelectElement.State) != null`. `nm`: the Debug runner has both
symbols, the ReleaseSafe runner only the option's. The functions had been
folded, so the second install replaced the first and selects lost half their
algorithms, in release builds only.

**Fix**: an entry's identity is its whole value (`std.meta.eql`): a duplicate
is an install whose every function is the installed one's. Folding can make
two predicates equal, never two whole entries that differ, so a release
build's table is a Debug build's less exact duplicates. Done in
form_controls, activation (it replaced, so the LAST behaviour won in release
and the first in Debug) and document_fetches (it dropped the second owner's
abort steps). global_settings keeps its `owns` key: it keeps the first
install, and `of` answers with the first match, which is the same answer in
both modes. Each has a test that installs two entries with ONE predicate
function. That test is red under a key on the predicate in Debug as well, so
no release build is needed to see it.

Tables keyed by a function that is the whole entry (unloading_cleanup,
teardown_sweeps, cloning_steps, range_boundaries) can only drop a second
call of identical code. That is harmless while those steps are idempotent.

**Takeaway**: **A function's address is an identity only in Debug. A release
build folds functions with identical code, so never key a table by one
function pointer of a larger entry: key it by the whole entry, or by
something named.**
