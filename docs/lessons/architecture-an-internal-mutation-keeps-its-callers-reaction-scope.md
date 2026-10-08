# Architecture: An internal mutation keeps its caller's reaction scope

**Date**: 2026-10-08
**Lesson**: Implement a specification's internal tree algorithm through its shared DOM algorithm, without introducing another public member's custom-element reaction scope.

**Why**: A public Node operation ends its own CEReactions scope before returning. Calling it inside another algorithm can run user callbacks before that outer algorithm has established its final state.

**What Happened**: Integrating persistent document.write parsers with custom-element reactions exposed a document.open path that removed each child through Node.removeChild. A disconnected callback could reopen the Document before the outer open installed its parser; the outer assignment then lost the callback-created parser's owner. The per-child calls also produced separate observer records instead of replace-all's grouped record.

**Fix**: For document.open step 11, call the existing dom.mutation.replaceAll algorithm with null under Document.open's generated outer CEReactions scope. Its removals enqueue reactions; callbacks run after the outer parser is installed. Add allocator-backed controls for a callback-created parser and continued writes, and script-visible controls for callback timing and the grouped mutation record.

**Takeaway**: **The owning public operation supplies the reaction boundary; an internal specification step uses the shared algorithm inside that boundary.**
