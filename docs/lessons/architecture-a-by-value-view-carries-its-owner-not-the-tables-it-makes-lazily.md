# Architecture: A by-value view carries its owner, not the tables the owner makes lazily

**Date**: 2026-11-10
**Lesson**: When a reader's view decodes ids through tables its owner makes on first use, store the OWNER in the view and look the tables up on each call. A table pointer copied in when the view was made is null if the table did not exist yet, and stays null after it does.

**Why**: Lane nd2 batch 2's `dom.element_data.View` decodes attribute name and value ids through its Browser's `.attribute_names` and `.attribute_values` tables. Those tables are made by the first intern (`BrowserScope.table`). The first design copied `Tables.of(scope)` into the view, and only when the element had attributes. A view taken from an element with no attributes therefore carried null tables. If the caller then set an attribute and read through the same view - a test fixture did exactly this (`const data = page.data(div);` then `setAttribute`, then `data.findAttribute(...)`) - every value decode unwrapped null. Nothing in the type said the view had a "made before" moment.

**What Happened**: The bug was caught while adapting a size-pin test, before the first build ran. The view became `{ data, name, scope }`. Each read method calls `Tables.of(self.scope)` (two acquire loads), and the id/class readers read only the values table, plus the names table on a saturated index. The element's scope comes from its address (`BrowserScope.ofInstance`), so the cost is one slab-header load per `of(element)`.

**Fix**:
1. A by-value view holds the data it borrows and the owner of anything made on demand, never a snapshot of the owner's lazily made parts.
2. Resolve the parts at the call, as late as the read: per call, not per view.
3. Hot readers that need one table read only that one.

**Takeaway**: **A view outlives the moment it was made; anything it copied from a lazily built owner is a snapshot of that moment. Carry the owner and resolve per call.**
