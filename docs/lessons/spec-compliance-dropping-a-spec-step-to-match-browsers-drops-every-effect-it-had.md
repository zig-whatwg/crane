# Spec Compliance: Dropping a spec step to match the browsers on one test drops every effect the step had

**Date**: 2026-11-18
**Lesson**: Before removing a spec step because the browsers do otherwise on one test, list everything the step does and find a test for each effect. A neighbouring test usually pins the effect the browsers keep.

**Why**: HTML's SVG script end tag sets the parser pause flag while the SVG script runs. Chrome, Firefox and Safari all run an inline SVG script that a document.write() inserted during the write (execution-timing/141.html, 1/1 in all three), and with the pause flag set that cannot happen. The flag also did a second job, though: it kept a document.write()'d EXTERNAL SVG script from running inside the write. All three browsers keep that external script parser-blocking (execution-timing/142.html, 1/1 in all three). Blink sends SVG scripts through the same HTMLParserScriptRunner as HTML scripts, so an inline one runs nested and an external one blocks.

**What Happened**: Lane blk1 dropped the pause flag for SVG script end tags. That unblocked 141, and the area runs were green because 142 was not in the area list. The FULL A/B against generation 228 caught it: 142.html went from OK 1/1 to NONE-PASSED, newly blocking.

**Fix**: cfcf1c4a670. An external SVG script that a nested invocation meets becomes the tree builder's pending_svg_script, a held structure like scripts_to_process, and the pause flag is set. The script that wrote it runs it once that script returns, at script nesting level one: after the outer script end tag's callback, and after each pending parsing-blocking script the parser executes. A targeted A/B over html/semantics/scripting-1/ and five more directories: 0 losses, with 141 and 142 both passing.

**Takeaway**: **When golden rule 2 makes you drop or change a spec step, run every test in the step's own directory, not only the one that motivated it, before you trust an area run; and copy the browser's mechanism (here: SVG scripts are HTML scripts to the parser) rather than deleting the step.**
