# Spec Compliance: "Child text content" means Text children only

**Date**: 2026-09-26
**Lesson**: A script's source is its child text content - the Text node children, concatenated - not the text of every descendant.

**Why**: Walking descendants made a nested script part of its parent's source.

**What Happened**: emptyish-script-elements passed 1/7, and script.text returned descendants' text.

**Fix**: Read only Text children (lane/scripting eaf042618, 5decc2298).

**Takeaway**: **Read the Infra/DOM definition of each text accessor; "child text content", "descendant text content" and textContent are three different things.**
