# Architecture: Two copies of one pointer become one only reader by reader - identity readers get a key that reads nothing

**Date**: 2026-11-14
**Lesson**: Folding two fields that name the same object into one word is safe only when each reader keeps the answer its own copy gave it, and readers that only COMPARE the pointer must not be routed through an accessor that checks or dereferences it.

**Why**: A node named its document twice: NodeBase held the Document's NodeBase, which src/dom's algorithms read with no check, and Node's state held the Document's Instance with a slab generation as the net under "a node keeps its document". The two copies had different readers with different needs: (1) readers that dereference the document, (2) readers that hand the Instance to script, (3) readers that only compare identity (`a.document == b.document`, `!= null`, cache keys), some of them the reference counts' bookkeeping at a teardown, where a document can go before a node that names it. A single checked accessor would have turned (3)'s "same stale pointer" into "null" exactly in that teardown case and changed the counts.

**What Happened**: Lane nm1's step 5 kept the Instance in one tagged word of NodeBase (bit 0: an Instance; bit 1: the document had no NodeBase when it was set, where the old NodeBase copy was null; untagged: an owner-less test tree's bare NodeBase) and moved the generation beside it. Three accessors replaced the two fields: `documentInstance()` for (2), `documentBase()` for (1) - checked, null where the old copy dangled - and `documentKey()` / `keyAsDocument()` for (3), which read nothing through the word. A fourth trap was a WRITER: `mutation.adopt` wrote the NodeBase copy and then called the Node impl's setter, which read the OTHER copy as "the previous document" to move the node between the documents' counts; with one word the early write would have made every adoption look like "no change". Adopt now leaves a platform node's document to the setter.

**Fix**:
1. List every reader of both copies and sort them: dereference, hand out, compare.
2. Give comparers a key accessor that reads nothing and never asks a net.
3. For each case where the two copies could disagree (set-time edge cases, test-only owners), encode the case in the word; do not "simplify" it away.
4. Read every writer for code that reads one copy AFTER writing the other.
5. Hold it with a test that asks every reader for created, parsed and adopted nodes, the document itself, and the test-only owner.

**Takeaway**: **Before two copies become one, sort their readers into dereference, hand out and compare: comparers get a key that reads nothing, and every writer is checked for a read of the other copy.**
