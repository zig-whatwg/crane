# Architecture: CDP commands wait for a page's navigation: Chrome suspends its sessions

**Date**: 2026-11-22
**Lesson**: From a page's navigation starting its request until it commits or ends, Chrome holds every command the page itself would answer. Page.navigate's answer comes before the commit, so a command sent after that answer must reach the new document, never the one it replaces.

**Why**: Chrome answers Page.navigate at ready-to-commit. The chain is NavigationRequest::ReadyToCommitNavigation, then FrameTreeNode::TransferNavigationRequestOwnership, then PageHandler::NavigationReset, so the document has not changed yet when a client sends its next command. Chrome makes that safe on the DevTools side:
- RenderFrameDevToolsAgentHost::DidStartNavigation suspends every session of the page's frame (SuspendMode kAll).
- DevToolsSession::FallThrough queues each command no browser handler answered, except the IO-thread list (Debugger.pause, Debugger.resume, Runtime.terminateExecution and a few others).
- DidFinishNavigation resumes the sessions and sends the queued commands in order.

The hold starts after beforeunload (Navigator::Navigate runs beforeunload before BeginNavigation). Runtime.runIfWaitingForDebugger resumes a waiting target before anything is held. (chromium/src 65b1b80ff52b.)

**What Happened**: tests/devtools tpg_scheme_network_events navigates, waits for the document's Network.loadingFinished, then fetches a refused port through Runtime.evaluate. Crane answers Page.navigate at ready-to-commit but commits in a later job, and the document's body can finish before that job runs. So the evaluate ran in the outgoing about:blank. Its fetch, slowed by the two connect retries (100 + 200 ms), was cancelled by the commit, and the test read net::ERR_ABORTED instead of net::ERR_CONNECTION_REFUSED: 1 run in 5 alone on macOS, and once in a full Linux gate. Two other theories were tested first and disproved for the ABORTED: a foreign listener taking the port, and a retry race. Both gave ERR_CONNECTION_RESET, never ABORTED. A refused port below the ephemeral range still failed.

**Fix**: src/devtools/held_commands.zig:
- What Chrome's browser process answers without falling through: derived from content/browser/devtools/protocol_config.json, chrome/browser/devtools/inspector_protocol_config.json and each handler's FallThrough / fallThrough() paths.
- The IO-thread list and the kExecutionOnly list.
- A per-Browser record of each tab's navigations in flight (BrowserSide.navigations), fed by a new `request_started` milestone placed after beforeunload, and cleared on commit, abort, navigable end and tab end.

PageSession.handleMessage holds a matching command. When the tab's last navigation ends, a session message of its own (ReleaseTask) sends the held commands in order, after the commit. A detach drops them. tests/devtools/fw2_navigate_holds_commands_test.zig covers:
- release at commit, failure, no-document end and replacement;
- dropping on detach;
- Debugger.pause going through;
- a session attaching mid-navigation;
- a tab closed mid-navigation;
- a target waiting for the debugger;
- stepping inside beforeunload.

**Takeaway**: **When a CDP command's answer can depend on which document is current, check what Chrome does with it during a navigation: its sessions hold the page's commands from the request's start to the commit. A browser-side reply such as Page.navigate's is not a sign that the page has changed.**
