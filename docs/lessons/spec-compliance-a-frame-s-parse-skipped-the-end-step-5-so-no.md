# Spec Compliance: A frame's parse skipped "the end" step 5, so no module script ran in a frame

**Date**: 2026-09-24
**Lesson**: The top-level parser (`HTMLParser`) runs the list of scripts that execute when parsing finishes, between "parsing stopped" and "finish loading". The frame parse (`HTMLIFrameElement.parseHtmlForIframe`) called the two lifecycle steps and skipped the list.

**Why**: a parser-inserted `<script type=module>` and every `defer` script is queued on that list, not run on insertion. A frame whose parse never drains it runs none of them.

**What Happened**: `origin-keyed-agent-clusters/` loads its frames from a helper page whose only script is a module, so every test waiting on a frame's reply hung: 45 files TIMEOUT. Only a probe that asked a srcdoc frame to report a module's side effect named it.

**Fix**: run `script_execution.executeScriptsWhenParsingFinished` in the frame path too. `crane/frame-module-scripts.html` pins it. Frame A/B over 753 frame-heavy worklist files: blocking 249 -> 212, 45 TIMEOUT -> OK.

**Takeaway**: **Every parser driver owes the whole of "the end".** When a feature works at top level and not in a frame, diff the two drivers' ends before the feature.
