
This spec is incomplete and it is not expected that it will advance
beyond draft status. Authors should not use most of these features
directly, but instead use JavaScript editing libraries. The features
described in this document are not implemented consistently or fully by
user agents, and it is not expected that this will change in the
foreseeable future. There is currently no alternative to some
execCommand actions related to clipboard content and
contentEditable=true is often used to draw the caret and move the caret
in the block direction as well as a few minor subpoints. This spec is to
meant to help implementations in standardizing these existing features.
It is predicted that in the future both specs will be replaced by
[Content Editable](https://w3c.github.io/contentEditable/) and [Input
Events](https://w3c.github.io/input-events/).

This document defines the behavior of the editing commands that can be
executed with `execCommand`.

## Introduction

The APIs specified here were originally introduced in Microsoft\'s
Internet Explorer, but have subsequently been copied by other browsers
in a haphazard and imprecise fashion. Although the behavior specified
here does not exactly match any browser at the time of writing, it can
serve as a target to converge to in the future.

Where the reasoning behind the specification is of interest, such as
when major preexisting rendering engines are known not to match it, the
reasoning is available by clicking the \"comments\" button on the right
(requires JavaScript). If you have questions about why the specification
says something, check the comments first. They\'re sometimes longer than
the specification text itself, and commonly record what the major
browsers do and other essential information.

The principles used for writing this reference list are:

- If all browsers that implement a particular feature agree on some
 detail of how it works, match them unless there\'s very good reason
 not to. When it\'s not clear what behavior is best, try to follow the
 implementations with the most market share. But if one browser\'s
 behavior is clearly better than the others\', go with the better
 behavior.
- If a command is issued to format some text in a particular way, we
 will format the text that way no matter what. If the user clicks the
 \"bold\" button, they don\'t care that the text didn\'t become bold
 because of an external CSS rule or for any other reason, they only
 care that it didn\'t work. The only exception (beyond where it\'s
 simply impossible, like propagated text-decorations we can\'t remove)
 is that we don\'t try to override !important rules from external
 stylesheets, although we also don\'t go out of our way to respect
 them.
- When we\'re given a presentational command like \"bold\", don\'t
 modify anything other than presentational markup related to that
 command. If an element has non-presentational attributes like id or
 class, don\'t split it up or remove it or anything. At most convert it
 to a span, if it\'s some type of presentational element.
 (\"Presentational\" here really means \"browsers produce it in
 response to execCommand() so we need to treat it as presentational\",
 so it includes things like \[\^strong\^\] and \[\^em\^\].) Of course,
 in some cases we have to remove elements, like when merging two
 blocks.
- Don\'t interfere with more markup than necessary. If the user modifies
 only a small run of text, don\'t go around simplifying ancestors or
 siblings or whatever unless it\'s necessary to produce simpler markup
 in the place that was actually modified.
- But if we are already changing around something\'s style, convert
 existing styles to the preferred format. For instance, we use
 `<b>`{title=""} for bold (if the CSS styling flag is false), and
 convert `<strong>`{title=""} and
 `<span style="font-weight: bold">`{title=""} if we happen to be
 modifying that node anyway.
- Try not to make the document less conforming than it originally was.
 If we happen to make it more conforming, good, although we don\'t have
 to go out of our way to do that. In some cases we do make the document
 less conforming, generally because there\'s some clear use-case that
 requires it or because it matches existing browsers behavior. (For
 instance, see the styleWithCSS = false mode, and the fact that
 insertImage doesn\'t add an alt attribute, etc.)
- Keep the markup as concise as possible. (I\'ve received feedback that
 this is very important to authors.) Ideally, the markup should look as
 simple and neat as what a human would have produced by hand-editing.
 We do complicated manipulation to pull styles down from ancestors
 rather than having to use inline CSS, and make sure to tidy up any
 styles on elements that we happen to be modifying anyway. Previous
 principles take precedence over this one, however.

## Tests

Tests can be found [here](https://w3c-test.org/editing/).

## Issues

This specification is mostly feature-complete. It should be considered
mostly stable and awaiting implementater review and feedback.

Significant known issues that I need feedback on, or otherwise am not
planning to fix just yet:

- Need to make CSS terminology more precise, about setting/unsetting CSS
 properties. The intent is to modify the style attribute, CSSOM-style.
 Suggestions appreciated on how I should spec this.

- I use [resolved value](http://dev.w3.org/csswg/cssom/#resolved-value)
 instead of computed or used or anything like that, just because
 that\'s what my test implementation uses (via getComputedStyle). This
 is not necessarily the best actual choice: if it should be something
 else, please tell me.

- I haven\'t paid much attention to performance. The algorithms here
 aren\'t performance-critical in most cases, but I might have
 accidentally included some algorithms that are too slow anyway on
 large pages. Generally I haven\'t worried about throwing nodes away
 and recreating them multiple times or things like that, as long as it
 produces the correct result.

 If it would be useful to implementers for me to spend time and spec
 complexity on avoiding some of the masses of useless operations that
 are currently required, please say so. All intermediate DOM states are
 black-box detectable via mutation events or whatever their replacement
 will be, so implementers theoretically can\'t optimize most of this
 stuff too much themselves, but in practice I doubt anyone will rely on
 the intermediate DOM states much.

- \[\^br\^\]s are a nightmare. I have tons of hacks all over the place
 which are totally wrong, mostly to account for the fact that sometimes
 \[\^br\^\]s do nothing and we need to treat that case magically. I
 don\'t know what a good way is to fix this. At this point I\'ve mostly
 gotten the evil concentrated in the definitions \"collapsed line
 break\", \"extraneous line break\", and \"collapsed block prop\", but
 there\'s lots of other special-case handling scattered about. Feedback
 appreciated. How do browsers handle this?

- The CSS styling flag is an issue. Currently authors are forced to turn
 it entirely on or entirely off. If it\'s on, it produces stuff like
 `<span style=font-weight:bold>`{title=""} instead of `<b>`{title=""},
 while if it\'s off, it produces stuff like
 `<font color=red>`{title=""} instead of
 `<span style=color:red>`{title=""}. The issue is that authors might
 want a mix, like making the markup as concise as possible while still
 conforming, and they can\'t do that. Changing the flag on a
 per-command basis doesn\'t help because of things like the \"restore
 the values\" algorithm, which might create several different types of
 style at once and has to use the same styling flag for all of them.
 This was discussed back in March in [this
 thread](http://lists.whatwg.org/htdig.cgi/whatwg-whatwg.org/2011-March/030714.html),
 along with a number of other things, but at that time I hadn\'t
 written commands that change multiple styles at once, so it seemed
 feasible to ask authors to switch styleWithCSS on or off on a
 per-command basis.

- I haven\'t defined the \"undo\" or \"redo\" commands yet. They look
 very complicated to define precisely, and other people are working on
 them right now.

A variety of other issues are also noted in the text, formatted like
this. Feedback would be appreciated on all of them.

TODO:

- Scour browser bug trackers to try spotting issues I haven\'t thought
 of.
- The wording I use for DOM stuff is not maximally precise. Really I
 want DOM Core to define nice concepts that I can xref, like \"insert a
 node\". I don\'t want to have to explicitly refer to DOM methods like
 insertBefore() every time I want to move things.
- JavaScript can modify the DOM synchronously in some cases, such as DOM
 mutation events and onunload when moving around iframes and objects.
 This has to be dealt with somehow. (Pointed out by Ryosuke Niwa of
 WebKit:
 [1](http://lists.whatwg.org/pipermail/whatwg-whatwg.org/2011-March/030730.html)
 [2](http://lists.whatwg.org/pipermail/whatwg-whatwg.org/2011-March/030751.html))
- What happens if you do something like delete a selection or insert
 text or whatnot in the middle of a surrogate pair? This could make the
 content not serialize through a character encoding change.
- Some more thought needs to go into what happens to the selection when
 you mutate the DOM. In some cases the results are pretty arbitrary. It
 might make sense to do some kind of normalization.
- I\'m sloppy about handling things like nodes that don\'t descend from
 a Document, comments that are children of a Document, that sort of
 thing. Not essential for prototyping, but needs to be cleaned up
 eventually. Mostly we should be able to avoid the problems by
 requiring that everything be editable, since that immediately means it
 has to descend from an element or Document (and cannot be parentless
 itself).
- I need to pay more attention to invisible nodes. These will have no
 visual effect, but they\'ll make many algorithms behave differently:
 decomposing a range, block-extending, etc. Also, need to improve the
 definition to include things like whitespace-only nodes.
- Have to make sure that in all the places where we set a selection,
 it\'s valid.
- Redefine things in terms of ranges, not selections.
- Allow some type of switch to affect non-editable regions too, perhaps
 on a per-command basis.
- Things like delete, forwardDelete, insertText need to handle non-BMP
 characters.

Also TODO: Things that are only implemented by a couple of browsers and
may or may not be useful to spec:

- decreaseFontSize, increaseFontSize: Only implemented in Gecko and
 Opera.
- contentReadOnly, enableInlineTableEditing, enableObjectResizing,
 heading, insertBrOnReturn: MDC docs say not implemented in IE (didn\'t
 test).
- readOnly: MDC docs say it\'s a deprecated equivalent of
 contentReadOnly, so presumably like useCSS but less popular.
- 2D-Position, absolutePosition, clearAuthenticationCache,
 createBookmark, insertButton, insertFieldset, insertIframe,
 insertInput\*, insertMarquee, insertSelectDropdown,
 insertSelectListbox, insertTextarea, liveResize, multipleSelection,
 overwrite, print, refresh, saveAs, unbookmark: Mentioned in MSDN docs
 but not MDC, so presumably IE-only. Some of these seem inappropriate
 or useless, others will bear investigation.
- findString, fontSizeDelta, insertNewlineInQuotedContent, justifyNone,
 print, transpose: There\'s code for these in WebKit,
 Source/WebCore/editing/EditorCommand.cpp, but I didn\'t see them
 mentioned elsewhere. Some might be worth adding.
- unselect: Seems to not be implemented by Gecko or Opera, and IE
 behaves oddly: it seems to collapse the selection instead of removing
 it. Will only implement if there seems to be demand; it\'s redundant
 to Selection.removeAllRanges() anyway.

Things I haven\'t looked at that multiple browsers implement:

- redo, undo: Needs review of the Google work on this; will probably be
 quite complicated.

Things that would be useful to address for the future but aren\'t
important to fix right now are in comments prefixed with \"TODO\".

## Commands

### Properties of commands

This specification defines a number of [commands], identified by [ASCII
case-insensitive](http://dom.spec.whatwg.org/#ascii-case-insensitive) strings. Each [command](#command) can have
several pieces of data associated with it:

- [Action]: What the [command](#command) does when
 executed via [`execCommand()`](#execcommand()). Every
 [command](#command) defined in this specification has an
 [action](#action) defined for it in the relevant section. For example,
 [the `bold`{title=""} command](#the-bold-command)\'s [action](#action)
 generally makes the current selection bold, or removes bold if the
 selection is already bold. An editing toolbar might provide buttons
 that execute the [action](#action) for a [command](#command) if
 clicked, or a script might run an [action](#action) without user
 interaction to achieve some particular effect. Actions return either
 true or false, which can affect the return value of
 [`execCommand()`](#execcommand()).
- [Indeterminate]: A boolean value returned by
 [`queryCommandIndeterm()`](#querycommandindeterm()), depending on the
 current state of the document. Generally, a [command](#command) that
 has a [state](#state) defined will be [indeterminate](#indeterminate)
 if the [state](#state) is true for part but not all of the current
 selection, and a [command](#command) that has a [value](#value)
 defined will be [indeterminate](#indeterminate) if different parts of
 the selection have different [values](#value "value"). An editing
 toolbar might display a button or control in a special way if the
 [command](#command) is [indeterminate](#indeterminate), like showing a
 \"bold\" button as partially depressed, or leaving a font size
 selector blank instead of showing the font size of the current
 selection. As a rule, a [command](#command) can only be
 [indeterminate](#indeterminate) if its [state](#state) is false,
 supposing it has a [state](#state).
- [State]: A boolean value returned by
 [`queryCommandState()`](#querycommandstate()), depending on the
 current state of the document. The [state](#state) of a
 [command](#command) is true if it is already in effect, in some sense
 specific to the [command](#command). Most
 [commands](#command "command") that have a [state](#state) defined
 will take opposite [actions](#action "action") depending on whether
 the [state](#state) is true or false, such as making the selection
 bold if the [state](#state) is false and removing bold if the
 [state](#state) is true. Others will just have no effect if the
 [state](#state) is true, like [the `justifyCenter`{title=""}
 command](#the-justifycenter-command). Still others will have the same
 effect regardless, like [the `styleWithCss`{title=""}
 command](#the-stylewithcss-command). An editing toolbar might display
 a button or control differently depending on the [state](#state) and
 [indeterminacy](#indeterminate "indeterminate") of the
 [command](#command).
- [Value]: A string returned by
 [`queryCommandValue()`](#querycommandvalue()), depending on the
 current state of the document. A [command](#command) usually has a
 [value](#value) instead of a [state](#state) if the property it
 modifies can take more than two different values, like [the
 `foreColor`{title=""} command](#the-forecolor-command). If the
 [command](#command) is [indeterminate](#indeterminate), its
 [value](#value) is generally based on the start of the selection.
 Otherwise, in most cases the [value](#value) holds true for the entire
 selection, but see [the `justifyCenter`{title=""}
 command](#the-justifycenter-command) and
 [its](#the-justifyfull-command "the justifyFull command")
 [three](#the-justifyleft-command "the justifyLeft command")
 [companions](#the-justifyright-command "the justifyRight command") for
 an exception. An editing toolbar might display the [value](#value) of
 a [command](#command) as selected in a drop-down or filled in in a
 text box, if the [command](#command) isn\'t
 [indeterminate](#indeterminate).
- [Relevant CSS property]: This is defined
 for certain [inline formatting commands](#inline-formatting-commands),
 and is used in algorithms specific to those commands. It is an
 implementation detail, and is not exposed to authors. If a
 [command](#command) does not have a [relevant CSS
 property](#relevant-css-property) specified, it defaults to null.

### Supported commands

If you try doing anything with an unrecognized command (except
queryCommandSupported), IE10 Developer Preview throws an \"Invalid
argument\" exception. Firefox 15.0a1 throws NS_ERROR_NOT_IMPLEMENTED on
querying indeterm/state/value, and returns false from
execCommand/queryCommandEnabled. Chrome 19 dev returns false from
everything. Opera Next 12.00 alpha throws NOT_SUPPORTED_ERR for
execCommand and returns false for enabled/state/value. Originally I went
with IE, although of course with a standard exception type. But after
discussion ([WebKit bug](https://bugs.webkit.org/show_bug.cgi?id=83993),
[Mozilla bug](https://bugzilla.mozilla.org/show_bug.cgi?id=742240)), I
changed to match WebKit (except that I return \"\" for value instead of
false). The issue is that there are a whole bunch of IE commands that no
one else supports or wants to support, and throwing on execCommand()
would make lots of pages break. WebKit was unwilling to take the compat
risk, so we took the safer option.

Some [commands](#command "command") will be [supported]
in a given user agent, and some will not. All
[commands](#command "command") defined in this specification must be
[supported](#supported), except optionally [the `copy`{title=""}
command](#the-copy-command), [the `cut`{title=""}
command](#the-cut-command), and/or [the `paste`{title=""}
command](#the-paste-command). Additional [vendor-specific
commands]
can also be [supported](#supported), but implementers must prefix any
[vendor-specific command](#vendor-specific-command) names with a
vendor-specific string (e.g., \"ms\", \"moz\", \"webkit\", \"opera\").

I.e., no trying to look good on lazy conformance tests by just sticking
in a stub implementation that does nothing.

A [command](#command) that does absolutely nothing in a particular user
agent, such that [`execCommand()`](#execcommand()) never has any effect
and [`queryCommandEnabled()`](#querycommandenabled()) and
[`queryCommandIndeterm()`](#querycommandindeterm()) and
[`queryCommandState()`](#querycommandstate()) and
[`queryCommandValue()`](#querycommandvalue()) each return the same value
all the time, must not be [supported](#supported).

In a particular user agent, every [command](#command) must be
consistently either [supported](#supported) or not. Specifically, a user
agent must not permit one page to see the same [command](#command)
sometimes [supported](#supported) and sometimes not over the course of
the same browsing session, unless the user agent has been upgraded or
reconfigured in the middle of a session. However, user agents may treat
the same [command](#command) as [supported](#supported) for some pages
and not others, e.g., if the [command](#command) is only supported for
certain origins for security reasons.

Authors can tell whether a [command](#command) is
[supported](#supported) using
[`queryCommandSupported()`](#querycommandsupported()).

### Enabled commands

At any given time, a [supported](#supported) command can be either
[enabled] or not. Authors can tell whether a
[command](#command) is currently [enabled](#enabled) using
[`queryCommandEnabled()`](#querycommandenabled()).
[Commands](#command "command") that are not [enabled](#enabled) do
nothing, as described in the definitions of the various methods that
invoke [commands](#command "command").

Testing with bold:

IE10PP2 seems to return true if the active range\'s start node is
editable, false otherwise.

Firefox 6.0a2 seems to always return true if there\'s anything editable
on the page, and throw otherwise. (This is [bug
676401](https://bugzilla.mozilla.org/show_bug.cgi?id=676401).)

Chrome 14 dev seems to behave the same as IE10PP2.

Opera 11.11 seems to always return true if there\'s anything editable on
the page, and false otherwise.

Firefox and Opera behave more or less uselessly. IE doesn\'t make much
sense, in that whether a command is enabled seems meaningless: it will
execute it on all nodes in the selection, editable or not. Chrome\'s
definition makes sense in that it will only run the command if it\'s
enabled, but it doesn\'t make much sense to only have the command run if
the start is editable.

It\'s not clear to me what the point of this method is. There\'s no way
we\'re going to always return true if the command will do something and
false if it won\'t. I originally just stuck with a really conservative
definition that happens to be convenient: if there\'s nothing selected,
obviously nothing will work, and we want to bail out early in that case
anyway because all the algorithms will talk about the active range. If
there are use-cases for it to be more precise, I could make it so.

[Bug 16094](https://www.w3.org/Bugs/Public/show_bug.cgi?id=16094)
illustrated that we don\'t really want to be able to modify multiple
editing hosts at once, nor do we want to do anything if the start and
end aren\'t both editable, so I co-opted this definition to fit my ends.

Among [commands](#command "command") defined in this specification,
those listed in [Miscellaneous commands](#miscellaneous-commands) are
always [enabled](#enabled), except for [the `cut`{title=""}
command](#the-cut-command) and [the `paste`{title=""}
command](#the-paste-command). The other [commands](#command "command")
defined here are [enabled](#enabled) if the [active
range](#active-range) is not null, its \[=range/start node=\] is either
[editable](#editable) or an \[=editing host=\], the [editing host
of](#editing-host-of) its \[=range/start node=\] is not an [EditContext
editing
host](https://w3c.github.io/edit-context/#dfn-editcontext-editing-host),
its \[=range/end node=\] is either [editable](#editable) or an
\[=editing host=\], the [editing host of](#editing-host-of) its
\[=range/end node=\] is not an [EditContext editing
host](https://w3c.github.io/edit-context/#dfn-editcontext-editing-host),
and there is some \[=editing host=\] that is an \[=tree/inclusive
ancestor=\] of both its \[=range/start node=\] and its \[=range/end
node=\].

## Methods to query and execute commands

``` idl

 partial interface Document {
 [CEReactions] boolean execCommand(DOMString commandId, optional boolean showUI = false, optional (TrustedHTML or DOMString) value = "");
 };

```

TODO: Add IDL for queryCommand\* functions.

TODO: Define behavior for `show UI`.

When the [`execCommand(``command``, ``show UI``, ``value``)`] method on the
{{Document}} interface is invoked, the user agent must run the following
steps:

1. If only one argument was provided, let `show UI`
 be false.

2. If only one or two arguments were provided, let `value` be the empty string.

3. ::: note
 For supported: see comment before [Supported
 commands](#supported-commands).

 For enabled: I didn\'t research this closely, but at a first glance,
 this is possibly how Chrome 14 dev and Opera 11.11 behave. Maybe
 also Firefox 6.0a2, except it throws if the command isn\'t enabled,
 I think. IE9 returns true in at least some cases even if the command
 is disabled. TODO: Is this right? Maybe we should be returning false
 in other cases too?
 :::

 If `command` is not [supported](#supported) or
 not [enabled](#enabled), return false.

4. If `command` is not in the [Miscellaneous
 commands](#miscellaneous-commands) section:

 We don\'t fire events for copy/cut/paste/undo/redo/selectAll because
 they should all have their own events. We don\'t fire events for
 styleWithCSS/useCSS because it\'s not obvious where to fire them, or
 why anyone would want them. We don\'t fire events for unsupported
 commands, because then if they became supported and were classified
 with the miscellaneous events, we\'d have to stop firing events for
 consistency\'s sake.

 1. Let `affected editing host` be the \[=editing host=\]
 that is an \[=tree/inclusive ancestor=\] of the [active
 range](#active-range)\'s \[=range/start node=\] and \[=range/end
 node=\], and is not the \[=tree/ancestor=\] of any \[=editing
 host=\] that is an \[=tree/inclusive ancestor=\] of the [active
 range](#active-range)\'s \[=range/start node=\] and \[=range/end
 node=\].

 Such an editing host must exist, because otherwise the command
 would not be [enabled](#enabled).

 2. \[=Fire an event=\] named \"beforeinput\" at
 `affected editing host` using {{InputEvent}}, with
 its {{Event/bubbles}} and {{Event/cancelable}} attributes
 initialized to true, and its {{InputEvent/data}} attribute
 initialized to null.

 3. If the value returned by the previous step is false, return
 false.

 4. If `command` is not [enabled](#enabled),
 return false.

 We have to check again whether the command is enabled, because
 the beforeinput handler might have done something annoying like
 getSelection().removeAllRanges().

 5. Let `affected editing host` be the
 \[=editing host=\] that is an \[=tree/inclusive ancestor=\] of
 the [active range](#active-range)\'s \[=range/start node=\] and
 \[=range/end node=\], and is not the \[=tree/ancestor=\] of any
 \[=editing host=\] that is an \[=tree/inclusive ancestor=\] of
 the [active range](#active-range)\'s \[=range/start node=\] and
 \[=range/end node=\].

 This new affected editing host is what we\'ll fire the input
 event at in a couple of lines. We want to compute it beforehand
 just to be safe: bugs in the command action might remove the
 selection or something bad like that, and we don\'t want to have
 to handle it later. We recompute it after the beforeinput event
 is handled so that if the handler moves the selection to some
 other editing host, the input event will be fired at the editing
 host that was actually affected.

5. Take the [action](#action) for `command`,
 passing `value` to the instructions as an
 argument.

6. If the previous step returned false, return false.

7. If the action modified DOM tree, then \[=fire an event=\] named
 \"input\" at `affected editing host` using
 {{InputEvent}}, with its {{Event/isTrusted}} and {{Event/bubbles}}
 attributes initialized to true, {{InputEvent/inputType}} attribute
 initialized to the \[=map an edit command to input type
 value\|mapped value=\] of `command`, and its
 {{InputEvent/data}} attribute initialized to null.

8. Return true.

To [map an edit command to input type value], follow this table:

edit command

inputType

backColor

formatBackColor

bold

formatBold

createLink

insertLink

fontName

formatFontName

foreColor

formatFontColor

strikethrough

formatStrikeThrough

superscript

formatSuperscript

delete

deleteContentBackward

forwardDelete

deleteContentForward

indent

formatIndent

insertHorizontalRule

insertHorizontalRule

insertLineBreak

insertLineBreak

insertOrderedList

insertOrderedList

insertParagraph

insertParagraph

insertText

insertText

insertUnorderedList

insertUnorderedList

justifyCenter

formatJustifyCenter

justifyFull

formatJustifyFull

justifyLeft

formatJustifyLeft

justifyRight

formatJustifyRight

outdent

formatOutdent

cut

deleteByCut

paste

insertFromPaste

redo

historyRedo

undo

historyUndo

If no mapping exists, return an empty string.

When the [`queryCommandEnabled(``command``)`]
method on the {{Document}} interface is invoked, the user agent must run
the following steps:

1. See comment before [Supported commands](#supported-commands).

2. Return true if `command` is both
 [supported](#supported) and [enabled](#enabled), false otherwise.

When the [`queryCommandIndeterm(``command``)`] method on the {{Document}} interface is
invoked, the user agent must run the following steps:

1. ::: note
 For supported: see comment before [Supported
 commands](#supported-commands).

 What happens if you call queryCommand(Indeterm\|State\|Value)() on a
 command where it makes no sense?

 IE9 consistently returns false for all three. However, any command
 that has a state defined also has a value defined, which is equal to
 the state: it returns boolean true or false.

 Firefox 6.0a2 consistently throws NS_ERROR_FAILURE for
 indeterm/state if not supported, and returns an empty string for
 value. Exceptions include unlink (seems to always return
 indeterm/state false), and styleWithCss/useCss (throw
 NS_ERROR_FAILURE even for value).

 Chrome 14 dev returns false for all three, and even does this for
 unrecognized commands. It also always defines value if state is
 defined: it returns the state cast to a string, either \"true\" or
 \"false\".

 Opera 11.11 returns false for state and \"\" for value (it doesn\'t
 support indeterm). Like Chrome, this is even for unrecognized
 commands.

 Gecko\'s behavior is the most useful. If the author tries querying
 some aspect of a command that makes no sense, they shouldn\'t
 receive a value that looks like it might make sense but is actually
 just a constant. Originally, I went even further than Gecko: I
 required exceptions even for value, since doing otherwise makes no
 sense. But throwing more exceptions is less compatible on the whole
 than throwing more exceptions, so based on
 [discussion](http://lists.whatwg.org/htdig.cgi/whatwg-whatwg.org/2011-September/033235.html),
 I switched to a behavior more like Opera, which is more or less
 IE/WebKit behavior but made slightly more sane.
 :::

 If `command` is not [supported](#supported) or
 has no [indeterminacy](#indeterminate "indeterminate"), return
 false.

2. Return true if `command` is
 [indeterminate](#indeterminate), otherwise false.

When the [`queryCommandState(``command``)`]
method on the {{Document}} interface is invoked, the user agent must run
the following steps:

1. See comment on the comparable line for
 [queryCommandIndeterm()](#querycommandindeterm()).

 If `command` is not [supported](#supported) or
 has no [state](#state), return false.

2. If the [state override](#state-override) for `command` is set, return it.

3. Return true if `command`\'s [state](#state) is
 true, otherwise false.

Firefox 6.0a2 always throws an exception when this is called. Opera
11.11 seems to return false if there\'s nothing editable on the page,
which is unhelpful. The spec follows IE9 and Chrome 14 dev. The reason
this is useful, compared to just running one of the other methods and
seeing if you get a NOT_SUPPORTED_ERR, is that other methods might throw
different exceptions for other reasons. It\'s easier to check a boolean
than to check exception types, especially since as of June 2011 UAs
aren\'t remotely consistent on what they do with unsupported commands.

Actually, correction: Firefox \< 15ish throws an exception if nothing
editable is on the page. Otherwise it behaves just like IE/Chrome. See
[Mozilla bug
742240](https://bugzilla.mozilla.org/show_bug.cgi?id=742240).

When the [`queryCommandSupported(``command``)`] method on the {{Document}} interface is
invoked, the user agent must return true if `command` is [supported](#supported) and available within the current
script on the current site, and false otherwise.

When the [`queryCommandValue(``command``)`]
method on the {{Document}} interface is invoked, the user agent must run
the following steps:

1. This is what Firefox 6.0a2 and Opera 11.11 seem to do when the
 command isn\'t enabled. Chrome 14 dev seems to return the string
 \"false\", and IE9 seems to return boolean false. For the case where
 there\'s no value, or the command isn\'t supported, see the comment
 on the comparable line for
 [queryCommandIndeterm()](#querycommandindeterm()).

 If `command` is not [supported](#supported) or
 has no [value](#value), return the empty string.

2. Yuck. This is incredibly messy, as are lots of other
 fontSize-related things, but I don\'t want to define a whole second
 notion of value for the sake of a single command . . .

 If `command` is \"fontSize\" and its [value
 override](#value-override) is set, convert the [value
 override](#value-override) to an integer number of pixels and return
 the [legacy font size for](#legacy-font-size-for) the result.

3. If the [value override](#value-override) for `command` is set, return it.

4. Return `command`\'s [value](#value).

All of these methods must treat their `command`
argument [ASCII
case-insensitively](http://dom.spec.whatwg.org/#ascii-case-insensitive "ASCII case-insensitive").

The methods in this section have mostly been designed so that the
following invariants hold after `execCommand()`{title=""} is called,
assuming it didn\'t throw an exception:

- `queryCommandIndeterm()`{title=""} will return false (or throw an
 exception).
- `queryCommandState()`{title=""} will return the opposite of what it
 did before `execCommand()`{title=""} was called (or throw an
 exception).
- `queryCommandValue()`{title=""} will return something equivalent to
 the value passed to `execCommand()`{title=""} (or throw an exception).
 \"Equivalent\" here needs to be construed broadly in some cases, such
 as `fontSize`{title=""}.

The first two points do not always hold for `strikethrough`{title=""} or
`underline`{title=""}, because it can be impossible to unset
text-decoration in CSS. Also, by design, the state of
`insertOrderedList`{title=""} and `insertUnorderedList`{title=""} might
be true both before and after calling, because they only remove one
level of indentation. `unlink`{title=""} should set the value to null.
And finally, the state of the various `justify`{title=""} commands
should always be true after calling, and the value should always be the
appropriate string (\"center\", \"justify\", \"left\", or \"right\").
Any other deviations from these invariants are bugs in the
specification.

## Common definitions

An [HTML element] is an {{Element}} whose
\[=Element/namespace=\] is the [HTML
namespace](http://dom.spec.whatwg.org/#html-namespace).

A [prohibited paragraph child name] is \"address\", \"article\", \"aside\", \"blockquote\",
\"caption\", \"center\", \"col\", \"colgroup\", \"dd\", \"details\",
\"dir\", \"div\", \"dl\", \"dt\", \"fieldset\", \"figcaption\",
\"figure\", \"footer\", \"form\", \"h1\", \"h2\", \"h3\", \"h4\",
\"h5\", \"h6\", \"header\", \"hgroup\", \"hr\", \"li\", \"listing\",
\"menu\", \"nav\", \"ol\", \"p\", \"plaintext\", \"pre\", \"section\",
\"summary\", \"table\", \"tbody\", \"td\", \"tfoot\", \"th\", \"thead\",
\"tr\", \"ul\", or \"xmp\".

These are all the things that will close a \<p\> if found as a
descendant. I think. Plus table stuff, since that can\'t be a descendant
of a p either, although it won\'t auto-close it.

A [prohibited paragraph child] is an
[HTML element](#html-element) whose \[=Element/local name=\] is a
[prohibited paragraph child name](#prohibited-paragraph-child-name).

The block/inline node definitions are CSS-based. \"Prohibited paragraph
child\" is conceptually similar to \"block node\", but based on the
element name. Generally we want to use block/inline node when we\'re
interested in the visual effect, and prohibited paragraph children when
we\'re concerned about parsing or semantics. TODO: Audit all \"block
node\" usages to see if they need to become \"visible block node\", now
that block nodes can be invisible (if they descend from display: none).

A [block node] is either an {{Element}} whose
\"display\" property does not have [resolved
value](http://dev.w3.org/csswg/cssom/#resolved-value) \"inline\" or
\"inline-block\" or \"inline-table\" or \"none\", or a \[=document=\],
or a {{DocumentFragment}}.

An [inline node] is a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is not a [block node](#block-node).

Something is [editable] if it is a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"); it is not an \[=editing host=\]; it does not have a
` `[`contenteditable`](http://www.whatwg.org/specs/web-apps/current-work/multipage/editing.html#attr-contenteditable)
attribute set to the false state; its \[=tree/parent=\] is an \[=editing
host=\] or [editable](#editable); and either it is an [HTML
element](#html-element), or it is an ` `[`svg`](http://www.whatwg.org/specs/web-apps/current-work/multipage/the-map-element.html#svg)
or ` `[`math`](http://www.whatwg.org/specs/web-apps/current-work/multipage/the-map-element.html#math)
element, or it is not an {{Element}} and its \[=tree/parent=\] is an
[HTML element](#html-element).

An [editable](#editable) node cannot be a \[=document=\] or
{{DocumentFragment}}, its \[=tree/parent=\] cannot be null, and it must
descend from either an {{Element}} or a \[=document=\].

The [editing host of] `node`
is null if `node` is neither [editable](#editable)
nor an \[=editing host=\]; `node` itself, if
`node` is an \[=editing host=\]; or the nearest
\[=tree/ancestor=\] of `node` that is an \[=editing
host=\], if `node` is [editable](#editable).

Two
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") are [in the same editing
host] if the [editing host
of](#editing-host-of) the first is non-null and the same as the [editing
host of](#editing-host-of) the second.

Barring bugs, the algorithms here will not alter the attributes of a
non-editable element; will not remove a non-editable node from its
parent (except to immediately give it a new parent in the same editing
host); and will not add, remove, or reorder children of a node unless it
is either editable or an editing host. An editing host is never
editable, so authors are assured that editing commands will only modify
the editing host\'s contents and not the editing host itself.

A [collapsed line break] is a \[\^br\^\]
that begins a line box which has nothing else in it, and therefore has
zero height.

Is this a good definition at all? I mean things like
\<p\>foo\<br\>\</p\>, or the second one in \<p\>foo\<br\>\<br\>\</p\>.
The way I test it is by adding a text node after it containing a zwsp;
if that changes the offsetHeight of its nearest non-inline ancestor, I
deem it collapsed. But what if it happens to be display: none right now,
for instance? Or its ancestor has a fixed height? Would it be better to
use some DOM-based definition?

TODO: The thing about li is a not very nice hack. The issue is that an
li won\'t collapse even if it has no children at all, but that\'s not
true in all browsers (at least not in Opera 11.11), and also it breaks
assumptions elsewhere. E.g., if it gets turned into a p.

An [extraneous line break] is a \[\^br\^\]
that has no visual effect, in that removing it from the DOM would not
change layout, except that a \[\^br\^\] that is the sole child of an
\[\^li\^\] is not extraneous.

Also possibly a bad definition. Again, I test by just removing it and
seeing what happens. (Actually, setting display: none, so that it
doesn\'t mess up ranges.)

A [whitespace node] is either a {{Text}} node
whose {{CharacterData/data}} is the empty string; or a {{Text}} node
whose {{CharacterData/data}} consists only of one or more tabs (0x0009),
line feeds (0x000A), carriage returns (0x000D), and/or spaces (0x0020),
and whose \[=tree/parent=\] is an {{Element}} whose [resolved
value](http://dev.w3.org/csswg/cssom/#resolved-value) for
\"white-space\" is \"normal\" or \"nowrap\"; or a {{Text}} node whose
{{CharacterData/data}} consists only of one or more tabs (0x0009),
carriage returns (0x000D), and/or spaces (0x0020), and whose
\[=tree/parent=\] is an {{Element}} whose [resolved
value](http://dev.w3.org/csswg/cssom/#resolved-value) for
\"white-space\" is \"pre-line\".

`node` is a [collapsed whitespace
node] if the following algorithm
returns true:

This definition is also bad. It\'s a crude attempt to emulate CSS2.1
16.6.1, but leaving out a ton of the subtleties. I actually don\'t want
the exact CSS definitions, because those depend on things like where
lines are broken, but I\'m not sure this definition is right anyway.
E.g., what about a pre-line text node consisting of a single line break
that\'s at the end of a block? That collapses, same idea as an
extraneous line break. We could also worry about nodes containing only
zwsp or such if we wanted, or display: none, or . . .

1. If `node` is not a [whitespace
 node](#whitespace-node), return false.

2. If `node`\'s {{CharacterData/data}} is the empty
 string, return true.

3. Let `ancestor` be `node`\'s
 \[=tree/parent=\].

4. If `ancestor` is null, return true.

5. If the \"display\" property of some \[=tree/ancestor=\] of
 `node` has [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) \"none\",
 return true.

6. While `ancestor` is not a [block
 node](#block-node) and its \[=tree/parent=\] is not null, set
 `ancestor` to its \[=tree/parent=\].

7. ::: note
 At this point we know `node` consists of some
 whitespace, of a sort that will collapse if it\'s at the start or
 end of a line. We go backwards until we find the first block
 boundary, and if everything until there is invisible or whitespace,
 we conclude that `node` is collapsed. We assume
 a block boundary is either when we hit a line break or block node,
 or we hit the end of `ancestor` (which is the
 nearest ancestor block node). All this is very imprecise, of course,
 but it\'s fairly simple and will work in common cases.

 We have to avoid invoking the definition of \"visible\" here to
 avoid infinite recursion: that depends on the concept of collapsed
 whitespace nodes. Instead, we repeat the parts we need, which turns
 out to be \"not much of it\".
 :::

 Let `reference` be `node`.

8. While `reference` is a \[=tree/descendant=\] of
 `ancestor`:
 1. Let `reference` be the
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") before it in \[=tree order=\].
 2. If `reference` is a [block
 node](#block-node) or a \[\^br\^\], return true.
 3. If `reference` is a {{Text}} node that is
 not a [whitespace node](#whitespace-node), or is an \[\^img\^\],
 break from this loop.

9. We found something before our text node on (probably) the same line,
 so presumably it\'s not at the line\'s start. Now we need to look
 forward and see if we\'re at the line\'s end. If we aren\'t there
 either, then we assume we\'re not collapsed, so return false.

 Let `reference` be `node`.

10. While `reference` is a \[=tree/descendant=\] of
 `ancestor`:
 1. Let `reference` be the
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") after it in \[=tree order=\], or null if
 there is no such
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node").
 2. If `reference` is a [block
 node](#block-node) or a \[\^br\^\], return true.
 3. If `reference` is a {{Text}} node that is
 not a [whitespace node](#whitespace-node), or is an \[\^img\^\],
 break from this loop.

11. Return false.

TODO: Consider whether we really want to depend on img specifically
here. It seems more likely that we want something like \"any replaced
content that has nonzero height and width\" or such. When fixing this,
make sure to audit for other occurrences of this assumption.

Something is [visible] if it is a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that either is a [block node](#block-node), or a
{{Text}} node that is not a [collapsed whitespace
node](#collapsed-whitespace-node), or an \[\^img\^\], or a \[\^br\^\]
that is not an [extraneous line break](#extraneous-line-break), or any
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") with a [visible](#visible) \[=tree/descendant=\];
excluding any
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") with an \[=tree/inclusive ancestor=\] {{Element}}
whose \"display\" property has [resolved
value](http://dev.w3.org/csswg/cssom/#resolved-value) \"none\".

Something is [invisible] if it is a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is not [visible](#visible).

TODO: Reconsider whether we want to lump invisible nodes in here. If we
don\'t and change the definition, make sure to audit all callers, since
then a block could have collapsed block prop descendants that aren\'t
children.

A [collapsed block prop] is either a
[collapsed line break](#collapsed-line-break) that is not an [extraneous
line break](#extraneous-line-break), or an {{Element}} that is an
[inline node](#inline-node) and whose \[=tree/children=\] are all either
[invisible](#invisible) or [collapsed block
props](#collapsed-block-prop "collapsed block prop") and that has at
least one \[=tree/child=\] that is a [collapsed block
prop](#collapsed-block-prop).

A collapsed block prop is something like the `<br>`{title=""} in
`<p><br></p>`{title=""}, or the `<br>`{title=""} and `<span>`{title=""}
in `<p><span><br></span></p>`{title=""}. These are necessary to stop the
block from having zero height when it has no other contents, but serve
no purpose and should be removed once the block has other contents that
stop it from collapsing.

TODO: I say \"first range\" because I think that\'s what Gecko actually
does, and Gecko is the only one that allows multiple ranges in a
selection. This is keeping in mind that it stores ranges sorted by
start, not by the order the user added them, and silently removes or
shortens existing ranges to avoid overlap. It probably makes the most
sense in the long term to have the command affect all ranges. But I\'ll
leave this for later.

The [active range] is the \[=range=\] of the
[selection](#concept-selection "concept-selection") given by calling
[`getSelection()`{title="dom-Document-getSelection"}](#dom-document-getselection)
on the [context
object](http://dom.spec.whatwg.org/#context-object). (Thus the [active range](#active-range) may be
null.)

Each {{Document}} has a boolean [CSS styling flag] associated with it, which must initially be false. ([The
`styleWithCSS`{title=""} command](#the-stylewithcss-command) can be used
to modify or query it, by means of the [`execCommand()`](#execcommand())
and [`queryCommandState()`](#querycommandstate()) methods.)

Each {{Document}} is associated with a string known as the [default
single-line container name],
which must initially be \"div\". ([The
`defaultParagraphSeparator`{title=""}
command](#the-defaultparagraphseparator-command) can be used to modify
or query it, by means of the [`execCommand()`](#execcommand()) and
[`queryCommandValue()`](#querycommandvalue()) methods.)

For some [commands](#command "command"), each {{Document}} must have a
boolean [state override] and/or a string [value
override]. These do not change the
[command](#command)\'s [state](#state) or [value](#value), but change
the way some algorithms behave, as specified in those algorithms\'
definitions. Initially, both must be unset for every
[command](#command). Whenever the number of \[=ranges=\] in the
[selection](#concept-selection "concept-selection") changes to something
different, and whenever a \[=boundary point=\] of the \[=range=\] at a
given index in the [selection](#concept-selection "concept-selection")
changes to something different, the [state override](#state-override)
and [value override](#value-override) must be unset for every
[command](#command). The [value override](#value-override) for [the
`backColor`{title=""} command](#the-backcolor-command) must be the same
as the [value override](#value-override) for [the
`hiliteColor`{title=""} command](#the-hilitecolor-command), such that
setting one sets the other to the same thing and unsetting one unsets
the other.

The primary purpose of state and value overrides is that if the user
runs a command like [`bold`{title=""}](#the-bold-command) with a
collapsed selection, then types something without moving the cursor,
they expect it to have the given style (bold or such). Thus the commands
like [`bold`{title=""}](#the-bold-command) set state and value
overrides, and [`insertText`{title=""}](#the-inserttext-command) checks
for them and applies them to the newly-inserted text. Other commands
like [`delete`{title=""}](#the-delete-command) also interact with
overrides.

See [bug 16207](https://www.w3.org/Bugs/Public/show_bug.cgi?id=16207).

When ` `[`document.open()`](http://www.whatwg.org/specs/web-apps/current-work/multipage/webappapis.html#dom-document-open)
is called and a \[=document=\]\'s singleton objects are all replaced by
new instances of those objects, editing state associated with that
document (including the [CSS styling flag](#css-styling-flag), [default
single-line container name](#default-single-line-container-name), and
any [state overrides](#state-override "state override") or [value
overrides](#value-override "value override")) must be reset.

Of course, any action that replaces a \[=document=\] object entirely,
such as reloading the page, will also reset any editing state associated
with the document.

When this specification refers to a method or attribute that is defined
in a specification, the user agent must treat the method or attribute as
defined by that specification. In particular, if a script has overridden
a standard property with a custom one, the user agent must only use the
overridden property when a script refers to it, and must continue to use
the specification-defined behavior when this specification refers to it.

When a list or set of
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") is assigned to a variable without specifying the
order, they must be initially in \[=tree order=\], if they share a root.
(If they don\'t share a root, the order will be specified.) When the
user agent is instructed to run particular steps for each member of a
list, it must do so sequentially in the list\'s order.

## Common algorithms

### Assorted common algorithms

To move a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") to a new location, [preserving
ranges], remove the
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") from its original \[=tree/parent=\] (if any), then
insert it in the new location. In doing so, follow these rules instead
of those defined by the \[=insert=\] and \[=remove=\] algorithms:

Many of the algorithms in this specification move nodes around in the
DOM. The normal rules for range mutation require that any range
endpoints inside those nodes are moved to the node\'s parent as soon as
the node is moved, which would corrupt the selection. For instance, if
the user selects the text \"foo\" and then bolds it, first we produce
`<b></b>foo`{title=""}, then `<b>foo</b>`{title=""}. When we move the
\"foo\" text node into its new parent, we have to do so \"preserving
ranges\", so that the text \"foo\" is still selected.

1. Let `node` be the moved
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node"), `old parent` and
 `old index` be the old \[=tree/parent=\] (which
 may be null) and \[=tree/index=\], and `new parent` and `new index` be the new
 \[=tree/parent=\] and \[=tree/index=\].

2. This is actually implicit, but I state it anyway for completeness.

 If a \[=boundary point=\]\'s
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") is the same as or a \[=tree/descendant=\] of
 `node`, leave it unchanged, so it moves to the
 new location.

3. If a \[=boundary point=\]\'s
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") is `new parent` and its
 \[=boundary point/offset=\] is greater than `new index`, add one to its \[=boundary point/offset=\].

4. If a \[=boundary point=\]\'s
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") is `old parent` and its
 \[=boundary point/offset=\] is `old index` or
 `old index` + 1, set its
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") to `new parent` and add
 `new index` − `old index` to
 its \[=boundary point/offset=\].

5. If a \[=boundary point=\]\'s
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") is `old parent` and its
 \[=boundary point/offset=\] is greater than `old index` + 1, subtract one from its \[=boundary point/offset=\].

TODO: Do we want to get rid of attributes that are no longer allowed
here?

To [set the tag name] of an {{Element}}
`element` to `new name`:

This is needed because the DOM doesn\'t allow any way of changing an
existing element\'s name. Sometimes we want to, e.g., convert a markup
element to a span. In that case we invoke this algorithm to create a new
element, move it to the right place, copy attributes from the old
element, move the old element\'s children, and remove the old element.

1. If `element` is an [HTML element](#html-element)
 with \[=Element/local name=\] equal to `new name`, return `element`.
2. If `element`\'s \[=tree/parent=\] is null,
 return `element`.
3. Let `replacement element` be the result of
 calling [`createElement(``new name``)`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `element`.
4. Insert `replacement element` into
 `element`\'s \[=tree/parent=\] immediately
 before ` element`.
5. Copy all attributes of `element` to
 `replacement element`, in order.
6. While `element` has \[=tree/children=\], append
 the first \[=tree/child=\] of `element` as the
 last \[=tree/child=\] of `replacement element`,
 [preserving ranges](#preserving-ranges).
7. Remove `element` from its \[=tree/parent=\].
8. Return `replacement element`.

To [remove extraneous line breaks
before] a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node`:

`<br>`{title=""} sometimes has no effect in CSS, such as in the markup
`foo<br><p>bar</p>`{title=""}. In such cases we like to remove the extra
markup to keep things tidy.

1. Let `ref` be the {{Node/ previousSibling}} of
 `node`.
2. If `ref` is null, abort these steps.
3. While `ref` has \[=tree/children=\], set
 `ref` to its {{Node/lastChild}}.
4. While `ref` is [invisible](#invisible) but not
 an [extraneous line break](#extraneous-line-break), and
 `ref` does not equal `node`\'s \[=tree/parent=\], set `ref` to the
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") before it in \[=tree order=\].
5. If `ref` is an [editable](#editable) [extraneous
 line break](#extraneous-line-break), remove it from its
 \[=tree/parent=\].

To [remove extraneous line breaks at the end
of] a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node`:

1. Let `ref` be `node`.
2. While `ref` has \[=tree/children=\], set
 `ref` to its {{Node/lastChild}}.
3. While `ref` is [invisible](#invisible) but not
 an [extraneous line break](#extraneous-line-break), and
 `ref` does not equal `node`,
 set `ref` to the
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") before it in \[=tree order=\].
4. If `ref` is an [editable](#editable) [extraneous
 line break](#extraneous-line-break):
 1. If the block ends with `<span><br></span>`{title=""}, for
 instance, we want to remove the span too.

 While `ref`\'s \[=tree/parent=\] is
 [editable](#editable) and [invisible](#invisible), set
 `ref` to its \[=tree/parent=\].

 2. Remove `ref` from its \[=tree/parent=\].

To [remove extraneous line breaks
from] a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"), first [remove extraneous line breaks
before](#remove-extraneous-line-breaks-before) it, then [remove
extraneous line breaks at the end
of](#remove-extraneous-line-breaks-at-the-end-of) it.

### Wrapping a list of nodes

To [wrap] a list `node list` of
consecutive \[=tree/sibling=\]
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), run the following algorithm. In addition to
`node list`, the algorithm accepts two inputs: an
algorithm `sibling criteria` that accepts a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") as input and outputs a boolean, and an algorithm
`new parent instructions` that accepts nothing as
input and outputs a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") or null. If not provided,
`sibling criteria` returns false and
`new parent instructions` returns null.

This algorithm basically does two things. First, it looks at the
previous and next siblings of the nodes in `node list`. If running `sibling criteria` on one or
both of the siblings returns true, the nodes in `node list` are moved into the sibling(s). Otherwise,
`new parent instructions` is run, and the result is
used to wrap `node list`. For instance, to wrap
`node list` in a `<b>`{title=""}, one might invoke
this algorithm with `sibling criteria` returning
true only for `<b>`{title=""} elements and
`new parent instructions` creating and returning a
new `<b>`{title=""} element.

1. We need to treat \[\^br\^\]s as visible here even if they\'re not,
 because wrapping them might be significant even if they\'re
 invisible: it can turn an extraneous line break into a
 non-extraneous one.

 If every member of `node list` is
 [invisible](#invisible), and none is a \[\^br\^\], return null and
 abort these steps.

2. If `node list`\'s first member\'s
 \[=tree/parent=\] is null, return null and abort these steps.

3. Trailing br\'s like this always need to go along with their line.
 Otherwise they\'ll create an extra line if we wrap in a block
 element, instead of vanishing as they should.

 If `node list`\'s last member is an [inline
 node](#inline-node) that\'s not a \[\^br\^\], and
 `node list`\'s last member\'s
 {{Node/nextSibling}} is a \[\^br\^\], append that \[\^br\^\] to
 `node list`.

4. See [bug
 13811](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13811), [bug
 14231](https://www.w3.org/Bugs/Public/show_bug.cgi?id=14231). If
 there\'s a non-adjacent sibling that matches the sibling criteria
 and only invisible nodes intervene, we want to skip over the
 invisible nodes. For instance, bolding
 `<b>foo</b><!--bar-->[baz]`{title=""} should produce
 `<b>foo<!--bar-->baz</b>`{title=""}. Similarly, and more usefully,
 creating an ordered list with
 `<ol><li>foo</ol> <p>[bar]</p>`{title=""} should produce
 `<ol><li>foo</li> <li>[bar]</ol>`{title=""}, not
 `<ol><li>foo</ol> <ol><li>[bar]</ol>`{title=""}.

 While `node list`\'s first member\'s
 {{Node/previousSibling}} is [invisible](#invisible), prepend it to
 `node list`.

5. While `node list`\'s last member\'s
 {{Node/nextSibling}} is [invisible](#invisible), append it to
 `node list`.

6. If the {{Node/previousSibling}} of the first member of
 `node list` is [editable](#editable) and running
 `sibling criteria` on it returns true, let
 `new parent` be the {{Node/previousSibling}} of
 the first member of `node list`.

7. Otherwise, if the {{Node/ nextSibling}} of the last member of
 `node list` is [editable](#editable) and running
 `sibling criteria` on it returns true, let
 `new parent` be the {{Node/nextSibling}} of the
 last member of `node list`.

8. Otherwise, run `new parent instructions`, and
 let `new parent` be the result.

9. This can only happen if `new parent instructions` is run and it returns null. This can be used to only merge
 with adjacent siblings, in case you don\'t want to create a new
 parent if that fails.

 If `new parent` is null, abort these steps and
 return null.

10. Most callers will create a new element to return in
 `new parent instructions`, whose parent will
 therefore be null. But they can also return an existing node if that
 makes sense, so the nodes will be moved to an uncle or something.
 The toggle lists algorithm makes use of this.

 If `new parent`\'s \[=tree/parent=\] is null:

 1. Insert `new parent` into the
 \[=tree/parent=\] of the first member of `node list` immediately before the first member of
 ` node list`.

 2. ::: note
 Basically, we want any boundary points around the wrapped nodes
 to go inside the wrapper. Without this step, wrapping
 \"\<br\>\" in a blockquote would go like

 <br>
 -> <blockquote></blockquote><br>
 -> <blockquote><br></blockquote>.

 The second line is due to range mutation rules: a boundary point
 with an offset equal to the index of a newly-inserted node stays
 put, so it remains before it. With this step, it goes like

 <br>
 -> <blockquote></blockquote><br>
 -> <blockquote></blockquote><br>
 -> <blockquote><br></blockquote>.

 The difference in the final step is because we move the \<br\>
 \"preserving ranges\". This means that adjacent boundary points
 get swept along with it. Previously, the \<blockquote\>
 intervened, so a boundary point after it would get taken along
 but one before it would not.

 Another solution that one might be tempted to consider would be
 to just put the wrapper after the wrapped elements. Then the
 boundary points would stay put, before the wrapper, so they\'d
 still be adjacent to the nodes to be wrapped, like:

 {<p>foo</p>}
 -> {<p>foo</p>}<blockquote></blockquote>
 -> <blockquote>{<p>foo</p>}</blockquote>.

 The problem is that this completely breaks if you\'re wrapping
 multiple things and not all are selected. It would go like this:

 <p>foo</p>{<p>bar</p>}
 -> <p>foo</p>{<p>bar</p>}<blockquote></blockquote>
 -> <p>foo</p><blockquote>{<p>bar</p>}</blockquote>
 -> <blockquote>{<p>foo</p><p>bar</p>}</blockquote>.

 The last step is again because of the range mutation rules: the
 boundary point stays put when a new node is inserted. They\'re
 fundamentally asymmetric.

 An alternative solution would be to define the concept of moving
 a list of adjacent sibling nodes while preserving ranges, and
 handle this explicitly at a more abstract level.

 TODO: Think about this some more. Maybe there\'s a better way.
 :::

 If any \[=range=\] has a \[=boundary point=\] with
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") equal to the \[=tree/parent=\] of
 `new parent` and \[=boundary point/offset=\]
 equal to the \[=tree/index=\] of `new parent`, add one to that \[=boundary point=\]\'s \[=boundary
 point/offset=\].

11. Let `original parent` be the \[=tree/parent=\]
 of the first member of `node list`.

12. If `new parent` is before the first member of
 `node list` in \[=tree order=\]:
 1. If `new parent` is not an [inline
 node](#inline-node), but the last [visible](#visible)
 \[=tree/child=\] of `new parent` and the
 first [visible](#visible) member of `node list` are both [inline nodes](#inline-node "inline node"),
 and the last \[=tree/child=\] of `new parent` is not a \[\^br\^\], call
 [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ ownerDocument}} of `new parent` and append the result as the last \[=tree/child=\] of
 `new parent`.
 2. For each `node` in `node list`, append `node` as the last
 \[=tree/child=\] of `new parent`,
 [preserving ranges](#preserving-ranges).

13. Otherwise:
 1. If `new parent` is not an [inline
 node](#inline-node), but the first [visible](#visible)
 \[=tree/child=\] of `new parent` and the
 last [visible](#visible) member of `node list` are both [inline nodes](#inline-node "inline node"),
 and the last member of `node list` is not a
 \[\^br\^\], call [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ ownerDocument}} of `new parent` and insert the result as the first \[=tree/child=\] of
 `new parent`.
 2. For each `node` in `node list`, *in reverse order*, insert `node`
 as the first \[=tree/child=\] of `new parent`, [preserving ranges](#preserving-ranges).

14. This could happen if `new parent instructions`
 returned a node whose parent wasn\'t null.

 If `original parent` is [editable](#editable)
 and has no \[=tree/children=\], remove it from its
 \[=tree/parent=\].

15. Probably because both the previous and next sibling met them. We
 want to merge them in this case.

 If `new parent`\'s {{Node/nextSibling}} is
 [editable](#editable) and running `sibling criteria` on it returns true:

 1. If `new parent` is not an [inline
 node](#inline-node), but `new parent`\'s
 last \[=tree/child=\] and `new parent`\'s
 {{Node/nextSibling}}\'s first \[=tree/child=\] are both [inline
 nodes](#inline-node "inline node"), and `new parent`\'s last \[=tree/child=\] is not a \[\^br\^\], call
 [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ ownerDocument}} of `new parent` and append the result as the last \[=tree/child=\] of
 `new parent`.
 2. While `new parent`\'s {{Node/nextSibling}}
 has \[=tree/children=\], append its first \[=tree/child=\] as
 the last \[=tree/child=\] of `new parent`,
 [preserving ranges](#preserving-ranges).
 3. Remove `new parent`\'s {{Node/nextSibling}}
 from its \[=tree/parent=\].

16. [Remove extraneous line breaks
 from](#remove-extraneous-line-breaks-from) `new parent`.

17. Return `new parent`.

### Allowed children

List is mostly based on current HTML5, together with obsolete elements.
I mostly got the obsolete element list by testing what Firefox 5.0a2
splits when you do insertHorizontalRule.

TODO: The definitions of prohibited paragraph children and elements with
inline contents should be in the HTML spec (possibly under a different
name) so they don\'t fall out of sync. They\'ll do for now.

A [name of an element with inline
contents] is \"a\",
\"abbr\", \"b\", \"bdi\", \"bdo\", \"cite\", \"code\", \"dfn\", \"em\",
\"h1\", \"h2\", \"h3\", \"h4\", \"h5\", \"h6\", \"i\", \"kbd\",
\"mark\", \"p\", \"pre\", \"q\", \"rp\", \"rt\", \"ruby\", \"s\",
\"samp\", \"small\", \"span\", \"strong\", \"sub\", \"sup\", \"u\",
\"var\", \"acronym\", \"listing\", \"strike\", \"xmp\", \"big\",
\"blink\", \"font\", \"marquee\", \"nobr\", or \"tt\".

An [element with inline contents] is
an [HTML element](#html-element) whose \[=Element/local name=\] is a
[name of an element with inline
contents](#name-of-an-element-with-inline-contents).

TODO: This list doesn\'t currently match HTML\'s validity requirements
for a few reasons:

1. We need to handle invalid elements, which have no conformance
 requirements but should be treated properly. In particular, they can
 interfere with serialization (e.g., center cannot descend from p).
2. Sometimes users give instructions that have to produce invalid DOMs
 to get the expected effect, like indenting the first item of a list.
3. The HTML validity requirements are sometimes quite complicated.
4. I just haven\'t had bothered to be systematic about it yet. I\'ve
 only covered what\'s come up in my tests.

I deliberately allow \[\^dt\^\] to contain headers and such, in
violation of HTML. If I didn\'t, then when the user tried to formatBlock
a \[\^dt\^\] as a header, it would break apart the whole \[\^dl\^\],
which seems worse. See [bug
13201](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13201).

[node](http://dom.spec.whatwg.org/#concept-node "concept-node") or string `child` is an [allowed
child] of a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") or string `parent` if the
following algorithm returns true:

Often we move around nodes, and sometimes this can result in
unreasonable things like two `<p>`{title=""}\'s nested inside one
another. This algorithm checks for DOMs we never want to have, so that
other algorithms can avoid creating them or fix them if they do happen.
The [fix disallowed ancestors](#fix-disallowed-ancestors) algorithm is
one frequently-invoked caller of this algorithm.

1. If `parent` is \"colgroup\", \"table\",
 \"tbody\", \"tfoot\", \"thead\", \"tr\", or an [HTML
 element](#html-element) with \[=Element/local name=\] equal to one
 of those, and `child` is a {{Text}} node whose
 {{CharacterData/data}} does not consist solely of [space
 characters](http://encoding.spec.whatwg.org/#ascii-whitespace "ascii whitespace"), return false.

2. Actually, no node can occur in the DOM after plaintext, generally.
 But let\'s not get too carried away.

 If `parent` is \"script\", \"style\",
 \"plaintext\", or \"xmp\", or an [HTML element](#html-element) with
 \[=Element/local name=\] equal to one of those, and
 `child` is not a {{Text}} node, return false.

3. If `child` is a \[=document=\],
 {{DocumentFragment}}, or {{DocumentType}}, return false.

4. If `child` is an [HTML element](#html-element),
 set `child` to the \[=Element/local name=\] of
 `child`.

5. If `child` is not a string, return true.

6. If `parent` is an [HTML element](#html-element):
 1. Cannot be serialized as text/html. In some cases it can, like
 \<a\>foo\<table\>\<td\>\<a\>bar\</a\>\</td\>\</table\>baz\</a\>,
 but it\'s invalid in those cases too, so no need for
 complication.

 If `child` is \"a\", and `parent` or some \[=tree/ancestor=\] of `parent` is an \[\^a\^\], return false.

 2. This generally cannot be serialized either, for p. For other
 elements with inline contents, this serves to prevent things
 like \<span\>\<p\>foo\</p\>\</span\>, which will parse fine but
 aren\'t supposed to happen anyway.

 If `child` is a [prohibited paragraph child
 name](#prohibited-paragraph-child-name) and `parent` or some \[=tree/ancestor=\] of `parent` is an [element with inline
 contents](#element-with-inline-contents), return false.

 3. Also can\'t be serialized as text/html.

 If `child` is \"h1\", \"h2\", \"h3\",
 \"h4\", \"h5\", or \"h6\", and `parent` or
 some \[=tree/ancestor=\] of `parent` is an
 [HTML element](#html-element) with \[=Element/local name=\]
 \"h1\", \"h2\", \"h3\", \"h4\", \"h5\", or \"h6\", return false.

 4. Further requirements only care about the parent itself, not
 ancestors, so we don\'t need to know the node itself.

 Let `parent` be the \[=Element/local name=\]
 of `parent`.

7. If `parent` is an {{Element}} or
 {{DocumentFragment}}, return true.

8. If `parent` is not a string, return false.

9. We allow children even where some intervening nodes will be
 inserted, like tr as a child of table.

 If `parent` is on the left-hand side of an entry
 on the following list, then return true if `child` is listed on the right-hand side of that entry, and false
 otherwise.

 - colgroup: col
 - table: caption, col, colgroup, tbody, td, tfoot, th, thead, tr
 - tbody, tfoot, thead: td, th, tr
 - tr: td, th
 - dl: dt, dd
 - dir, ol, ul: dir, li, ol, ul
 - hgroup: h1, h2, h3, h4, h5, h6

10. If `child` is \"body\", \"caption\", \"col\",
 \"colgroup\", \"frame\", \"frameset\", \"head\", \"html\",
 \"tbody\", \"td\", \"tfoot\", \"th\", \"thead\", or \"tr\", return
 false.

11. dd/dt/li will serialize fine as the child of random stuff, but it
 makes no sense at all, so we want to avoid it anyway.

 If `child` is \"dd\" or \"dt\" and
 `parent` is not \"dl\", return false.

12. If `child` is \"li\" and `parent` is not \"ol\" or \"ul\", return false.

13. If `parent` is on the left-hand side of an entry
 on the following list and `child` is listed on
 the right-hand side of that entry, return false.
 - a: a
 - dd, dt: dd, dt
 - h1, h2, h3, h4, h5, h6: h1, h2, h3, h4, h5, h6
 - li: li
 - nobr: nobr
 - All [names of an element with inline
 contents](#name-of-an-element-with-inline-contents "name of an element with inline contents"):
 all [prohibited paragraph child
 names](#prohibited-paragraph-child-name "prohibited paragraph child name")
 - td, th: caption, col, colgroup, tbody, td, tfoot, th, thead, tr

14. Return true.

## Inline formatting commands

### Inline formatting command definitions

The difference between \"contained\" and \"effectively contained\" is
basically that 1) in \<b\>\[foo\]\</b\>, the text node and the \<b\> are
effectively contained but not contained; and 2) in \<b\>f\[o\]o\</b\>,
the text node is effectively contained but not contained, and the \<b\>
is neither effectively contained nor contained.

A
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node` is [effectively
contained] in a \[=range=\]
`range` if `range` is not
\[=range/collapsed=\], and at least one of the following holds:

- `node` is
 [contained](http://dom.spec.whatwg.org/#contained) in `range`.

- So like \<b\>f\[oo\]\</b\> or \<b\>f\[o\]o\</b\> or \<b\>f\[oo\</b\>},
 but not \<b\>foo\[\</b\>} or \<b\>f\[\]oo\</b\>.

 `node` is `range`\'s
 \[=range/start node=\], it is a {{Text}} node, and its
 \[=Node/length=\] is different from `range`\'s
 \[=range/start offset=\].

- `node` is `range`\'s
 \[=range/end node=\], it is a {{Text}} node, and `range`\'s \[=range/end offset=\] is not 0.

- Basically, anything whose children are all effectively contained
 should be effectively contained itself, except that in a case like
 \<b\>f\[o\]o\</b\> we don\'t want \<b\> to be effectively contained
 even though the text node is. That\'s because we split the text node
 before we actually do anything, and the \<b\> will no longer be
 effectively contained.

 `node` has at least one \[=tree/child=\]; and all
 its \[=tree/children=\] are [effectively
 contained](#effectively-contained) in `range`; and
 either `range`\'s \[=range/start node=\] is not a
 \[=tree/descendant=\] of `node` or is not a
 {{Text}} node or `range`\'s \[=range/start
 offset=\] is zero; and either `range`\'s
 \[=range/end node=\] is not a \[=tree/descendant=\] of
 `node` or is not a {{Text}} node or
 `range`\'s \[=range/end offset=\] is its
 \[=range/end node=\]\'s \[=Node/length=\].

A [modifiable element] is a \[\^b\^\],
\[\^em\^\], \[\^i\^\], \[\^s\^\], \[\^span\^\], \[\^strike\^\],
\[\^strong\^\], ` `[`sub`](https://html.spec.whatwg.org/multipage/semantics.html#the-sub-and-sup-elements),
` `[`sup`](https://html.spec.whatwg.org/multipage/semantics.html#the-sub-and-sup-elements),
or \[\^u\^\] element with no attributes except possibly ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute);
or a \[\^font\^\] element with no attributes except possibly
` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute),
` `[`color`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-color),
` `[`face`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-face),
and/or ` `[`size`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-size);
or an \[\^a\^\] element with no attributes except possibly ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
and/or ` `[`href`](http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#attr-hyperlink-href).

A [simple modifiable element] is an
[HTML element](#html-element) for which at least one of the following
holds:

- It is an \[\^a\^\], \[\^b\^\], \[\^em\^\], \[\^font\^\], \[\^i\^\],
 \[\^s\^\], \[\^span\^\], \[\^strike\^\], \[\^strong\^\], ` `[`sub`](https://html.spec.whatwg.org/multipage/semantics.html#the-sub-and-sup-elements),
 ` `[`sup`](https://html.spec.whatwg.org/multipage/semantics.html#the-sub-and-sup-elements),
 or \[\^u\^\] element with no attributes.
- It is an \[\^a\^\], \[\^b\^\], \[\^em\^\], \[\^font\^\], \[\^i\^\],
 \[\^s\^\], \[\^span\^\], \[\^strike\^\], \[\^strong\^\], ` `[`sub`](https://html.spec.whatwg.org/multipage/semantics.html#the-sub-and-sup-elements),
 ` `[`sup`](https://html.spec.whatwg.org/multipage/semantics.html#the-sub-and-sup-elements),
 or \[\^u\^\] element with exactly one attribute, which is
 ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute),
 which sets no CSS properties (including invalid or unrecognized
 properties).
- It is an \[\^a\^\] element with exactly one attribute, which is
 ` `[`href`](http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#attr-hyperlink-href).
- It is a \[\^font\^\] element with exactly one attribute, which is
 either ` `[`color`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-color),
 ` `[`face`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-face),
 or ` `[`size`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-size).
- It is a \[\^b\^\] or \[\^strong\^\] element with exactly one
 attribute, which is ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute),
 and the ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute sets exactly one CSS property (including invalid or
 unrecognized properties), which is \"font-weight\".
- It is an \[\^i\^\] or \[\^em\^\] element with exactly one attribute,
 which is ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute),
 and the ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute sets exactly one CSS property (including invalid or
 unrecognized properties), which is \"font-style\".
- It is an \[\^a\^\], \[\^font\^\], or \[\^span\^\] element with exactly
 one attribute, which is ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute),
 and the ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute sets exactly one CSS property (including invalid or
 unrecognized properties), and that property is not
 \"text-decoration\".
- It is an \[\^a\^\], \[\^font\^\], \[\^s\^\], \[\^span\^\],
 \[\^strike\^\], or \[\^u\^\] element with exactly one attribute, which
 is ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute),
 and the ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute sets exactly one CSS property (including invalid or
 unrecognized properties), which is \"text-decoration\", which is set
 to \"line-through\" or \"underline\" or \"overline\" or \"none\".

Conceptually, a simple modifiable element is a modifiable element which
specifies a value for at most one command. As the names imply, inline
formatting commands will try not to modify anything other than
modifiable elements. For instance, `<dfn>`{title=""} normally creates
italics, but it\'s not modifiable, so running [the `italic`{title=""}
command](#the-italic-command) will not remove it: it will nest
`<span style="font-style: normal">`{title=""} inside.

A [formattable node] is an [editable](#editable)
[visible](#visible)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is either a {{Text}} node, an \[\^img\^\], or a
\[\^br\^\].

Two quantities are [equivalent values] for a
[command](#command) if either both are null, or both are strings and
they\'re equal and the [command](#command) does not define any
[equivalent values](#equivalent-values), or both are strings and the
[command](#command) defines [equivalent values](#equivalent-values) and
they match the definition.

Two quantities are [loosely equivalent
values] for a [command](#command) if
either they are [equivalent values](#equivalent-values) for the
[command](#command), or if the [command](#command) is [the
`fontSize`{title=""} command](#the-fontsize-command); one of the
quantities is one of \"x-small\", \"small\", \"medium\", \"large\",
\"x-large\", \"xx-large\", or \"xxx-large\"; and the other quantity is
the [resolved value](http://dev.w3.org/csswg/cssom/#resolved-value) of
\"font-size\" on a \[\^font\^\] element whose ` `[`size`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-size)
attribute has the corresponding value set (\"1\" through \"7\"
respectively).

Loose equivalence needs to be used when comparing effective command
values to other values, while regular equivalence is used in other
cases. The effective command value for fontSize is converted to pixels,
so comparing it to a specified value literally would produce false
negatives. But a *specified* value in pixels is actually different from
a *specified* value like \"small\" or \"x-large\", because there is no
precise mapping from such keywords to pixels.

If a [command](#command) has [inline command activated
values] defined but nothing else
defines when it is [indeterminate](#indeterminate), it is
[indeterminate](#indeterminate) if among [formattable
nodes](#formattable-node "formattable node") [effectively
contained](#effectively-contained) in the [active range](#active-range),
there is at least one whose [effective command
value](#effective-command-value) is one of the given values and at least
one whose [effective command value](#effective-command-value) is not one
of the given values.

For bold and similar commands, IE 9 RC seems to consider the state true
or false depending on the first element. All other browsers follow the
same general idea as the spec, considering a range bold only if all text
in it is bold, and this seems to match at least OpenOffice.org\'s bold
feature. Opera 11.11 seemingly doesn\'t take CSS into account, and only
looks at whether something descends from a \<b\>. I couldn\'t properly
test IE9 because it threw exceptions (Error: Unspecified error.) on most
of the tests I ran. But what I have here seems to match Firefox 6.0a2 in
every case, and Chrome 14 dev in all cases with a few exceptions.

If a [command](#command) has [inline command activated
values](#inline-command-activated-values) defined, its [state](#state)
is true if either no [formattable node](#formattable-node) is
[effectively contained](#effectively-contained) in the [active
range](#active-range), and the [active range](#active-range)\'s
\[=range/start node=\]\'s [effective command
value](#effective-command-value) is one of the given values; or if there
is at least one [formattable node](#formattable-node) [effectively
contained](#effectively-contained) in the [active range](#active-range),
and all of them have an [effective command
value](#effective-command-value) equal to one of the given values.

Testing with hiliteColor: Opera 11.11 seems to always return the
effective command value of the active range\'s start node. Chrome 14 dev
returns boolean false consistently, bizarrely enough. Firefox 6.0a2
seems to follow the same idea as the spec, but it likes to return
\"transparent\", including sometimes when the answer really clearly
should not be \"transparent\". IE9 throws exceptions most of the time
for backColor, so I can\'t say for sure, but in the few cases where it
doesn\'t throw it returns a random-looking number, so I\'ll assume it\'s
crazy like for foreColor.

I decided on something that would guarantee the following invariant:
whenever you execute a command with a value provided (assuming value is
relevant), queryCommandValue() will always return something equivalent
to what you set.

If a command is a [standard inline value
command], it is
[indeterminate](#indeterminate) if among [formattable
nodes](#formattable-node "formattable node") that are [effectively
contained](#effectively-contained) in the [active range](#active-range),
there are two that have distinct [effective command
values](#effective-command-value "effective command value"). Its
[value](#value) is the [effective command
value](#effective-command-value) of the first [formattable
node](#formattable-node) that is [effectively
contained](#effectively-contained) in the [active range](#active-range);
or if there is no such node, the [effective command
value](#effective-command-value) of the [active range](#active-range)\'s
\[=range/start node=\]; or if that is null, the empty string.

The notions of inline command activated values and standard inline value
commands are mostly just shorthand to avoid repeating the same
boilerplate half a dozen times.

### Assorted inline formatting command algorithms

The [effective command value] of a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node` for a given
`command` is returned by the following algorithm,
which will return either a string or null:

This is logically somewhat like CSS computed or resolved values, and in
fact for most commands it\'s identical to CSS resolved values (see the
end of the algorithm). We need a separate concept for some commands
where we can\'t rely on CSS for some reason: createLink and unlink
aren\'t CSS-related at all, backColor and hiliteColor need special
treatment because background-color isn\'t an inherited property,
subscript and superscript rely on `<sub>`{title=""}/`<sup>`{title=""}
instead of CSS vertical-align, and strikethrough and underline don\'t
map to unique CSS properties.

1. If neither `node` nor its \[=tree/parent=\] is
 an {{Element}}, return null.
2. If `node` is not an {{Element}}, return the
 [effective command value](#effective-command-value) of its
 \[=tree/parent=\] for `command`.
3. If `command` is \"createLink\" or \"unlink\":
 1. While `node` is not null, and is not an
 \[\^a\^\] element that has an ` `[`href`](http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#attr-hyperlink-href)
 attribute, set `node` to its
 \[=tree/parent=\].
 2. If `node` is null, return null.
 3. Return the \[=Attr/value=\] of `node`\'s
 ` `[`href`](http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#attr-hyperlink-href)
 attribute.
4. If `command` is \"backColor\" or
 \"hiliteColor\":
 1. While the [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) of
 \"background-color\" on `node` is any fully
 transparent value, and `node`\'s
 \[=tree/parent=\] is an {{Element}}, set `node` to its \[=tree/parent=\].

 2. ::: note
 What happens if everything\'s background is fully transparent?
 See [bug](https://www.w3.org/Bugs/Public/show_bug.cgi?id=14068).
 If you do queryCommandValue() for backColor/hiliteColor when no
 backgrounds are set anywhere, so it goes up to the root element,
 no two engines agree. IE10PP2 just returns a random-looking
 number (16777215). Firefox 8.0a2 returns \"transparent\", Chrome
 15 dev returns \"rgba(0, 0, 0, 0)\", and Opera 11.50 returns
 \"rgb(255, 255, 255)\".

 Opera\'s behavior is incorrect. The current page might be an
 iframe, in which case the background really will be transparent
 and the (inaccessible) background color of the parent page will
 show through. Also, the user might have changed their
 preferences, but I\'m not too worried about that.

 So instead we just return the value as-is. This means that it
 will be fully transparent, which is perhaps somewhat useless
 information, but it\'s the best we can do. More generally, any
 non-opaque value is not going to tell you what you actually
 want, namely \"what color is the user actually seeing?\" We have
 no realistic way to work around this in the general case.
 :::

 Return the [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) of
 \"background-color\" for `node`.
5. If `command` is \"subscript\" or
 \"superscript\":
 1. Let `affected by subscript` and
 `affected by superscript` be two boolean
 variables, both initially false.
 2. While `node` is an [inline
 node](#inline-node):
 1. Firefox 6.0a2 ignores vertical-align for this purpose, and
 only cares about \<sub\> and \<sup\> tags themselves. Opera
 11.11 is similar, and in fact behaves like that even for
 commands like bold. The spec originally followed Chrome 14
 dev, mainly because WebKit itself will produce spans with
 vertical-align sub or super, and we want to handle them
 correctly. However, Ryosuke
 [informs](https://lists.whatwg.org/htdig.cgi/whatwg-whatwg.org/2011-August/032809.html)
 me that WebKit\'s behavior here is viewed as [a
 bug](https://bugs.webkit.org/show_bug.cgi?id=11089), so I
 changed it to match Gecko/Opera.

 If `node` is a ` `[`sub`](https://html.spec.whatwg.org/multipage/semantics.html#the-sub-and-sup-elements),
 set `affected by subscript` to true.

 2. Otherwise, if `node` is a ` `[`sup`](https://html.spec.whatwg.org/multipage/semantics.html#the-sub-and-sup-elements),
 set `affected by superscript` to true.

 3. Set `node` to its \[=tree/parent=\].
 3. If `affected by subscript` and
 `affected by superscript` are both true,
 return the string \"mixed\".
 4. If `affected by subscript` is true, return
 \"subscript\".
 5. If `affected by superscript` is true, return
 \"superscript\".
 6. Return null.
6. If `command` is \"strikethrough\", and the
 \"text-decoration\" property of `node` or any of
 its \[=tree/ancestors=\] has [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) containing
 \"line-through\", return \"line-through\". Otherwise, return null.
7. If `command` is \"underline\", and the
 \"text-decoration\" property of `node` or any of
 its \[=tree/ancestors=\] has [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) containing
 \"underline\", return \"underline\". Otherwise, return null.
8. Return the [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) for
 `node` of the [relevant CSS
 property](#relevant-css-property) for `command`.

The [specified command value] of an
{{Element}} `element` for a given
`command` is returned by the following algorithm,
which will return either a string or null:

This is logically somewhat like CSS inline style. In addition to the
caveats for effective command value, we also treat elements like
`<b>`{title=""} and `<font>`{title=""} as having the same meaning as
`<span>`{title=""}s with inline style set, because they\'re logically
pretty much the same and can in fact be produced by the same command
depending on the [CSS styling flag](#css-styling-flag).

1. If `command` is \"backColor\" or \"hiliteColor\"
 and the {{Element}}\'s display property does not have [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) \"inline\",
 return null.
2. If `command` is \"createLink\" or \"unlink\":
 1. If `element` is an \[\^a\^\] element and has
 an ` `[`href`](http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#attr-hyperlink-href)
 attribute, return the \[=Attr/value=\] of that attribute.
 2. Return null.
3. If `command` is \"subscript\" or
 \"superscript\":
 1. If `element` is a ` `[`sup`](https://html.spec.whatwg.org/multipage/semantics.html#the-sub-and-sup-elements),
 return \"superscript\".
 2. If `element` is a ` `[`sub`](https://html.spec.whatwg.org/multipage/semantics.html#the-sub-and-sup-elements),
 return \"subscript\".
 3. Return null.
4. If `command` is \"strikethrough\", and
 `element` has a ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute set, and that attribute sets \"text-decoration\":
 1. If `element`\'s ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute sets \"text-decoration\" to a value containing
 \"line-through\", return \"line-through\".
 2. Return null.
5. If `command` is \"strikethrough\" and
 `element` is an \[\^s\^\] or \[\^strike\^\]
 element, return \"line-through\".
6. If `command` is \"underline\", and
 ` element` has a ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute set, and that attribute sets \"text-decoration\":
 1. If `element`\'s ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute sets \"text-decoration\" to a value containing
 \"underline\", return \"underline\".
 2. Return null.
7. If `command` is \"underline\" and
 ` element` is a \[\^u\^\] element, return
 \"underline\".
8. Let `property` be the [relevant CSS
 property](#relevant-css-property) for ` command`.
9. If `property` is null, return null.
10. If `element` has a ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute set, and that attribute has the effect of setting
 `property`, return the value that it sets
 `property` to.
11. If `element` is a \[\^font\^\] element that has
 an attribute whose effect is to create a [presentational
 hint](http://www.whatwg.org/specs/web-apps/current-work/multipage/rendering.html#presentational-hints "presentational hints") for `property`, return the
 value that the hint sets `property` to. (For a
 ` `[`size`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-size)
 of 7, this will be the non-CSS value \"xxx-large\".)
12. If `element` is in the following list, and
 `property` is equal to the CSS property name
 listed for it, return the string listed for it.
 - \[\^b\^\], \[\^strong\^\]: font-weight: \"bold\"
 - \[\^i\^\], \[\^em\^\]: font-style: \"italic\"
13. Return null.

To [record the values] of a list of
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") `node list`:

When we move nodes around, we often change their parents. If their
parents had any styles applied, this will make the nodes\' styles change
too, which often isn\'t what we want. For instance, if something is
wrapped in `<blockquote style="color: red">`{title=""}, and a script
runs [the `outdent`{title=""} command](#the-outdent-command) on it, the
blockquote will be removed and the style will go along with it.
Recording the values of its children first, then restoring them
afterward, will ensure the nodes don\'t change color when outdented.

1. Let `values` be a list of
 ([node](http://dom.spec.whatwg.org/#concept-node "concept-node"), [command](#command), [specified command
 value](#specified-command-value)) triples, initially empty.

2. As with removeFormat, we put subscript first so it doesn\'t
 interfere with fontSize, and omit superscript because it\'s
 redundant with subscript.

 For each `node` in `node list`, for each `command` in the list
 \"subscript\", \"bold\", \"fontName\", \"fontSize\", \"foreColor\",
 \"hiliteColor\", \"italic\", \"strikethrough\", and \"underline\" in
 that order:

 1. Let `ancestor` equal `node`.
 2. If `ancestor` is not an {{Element}}, set it
 to its \[=tree/parent=\].
 3. While `ancestor` is an {{Element}} and its
 [specified command value](#specified-command-value) for
 `command` is null, set it to its
 \[=tree/parent=\].
 4. If `ancestor` is an {{Element}}, add
 (`node`, `command`,
 `ancestor`\'s [specified command
 value](#specified-command-value) for `command`) to `values`. Otherwise add
 (`node`, `command`,
 null) to `values`.

3. Return `values`.

To [restore the values] specified by a list
`values` returned by the [record the
values](#record-the-values) algorithm:

1. For each (`node`, `command`,
 `value`) triple in `values`:
 1. Let `ancestor` equal `node`.
 2. If `ancestor` is not an {{Element}}, set it
 to its \[=tree/parent=\].
 3. While `ancestor` is an {{Element}} and its
 [specified command value](#specified-command-value) for
 `command` is null, set it to its
 \[=tree/parent=\].
 4. If `value` is null and `ancestor` is an {{Element}}, [push down
 values](#push-down-values) on `node` for
 `command`, with `new value` null.
 5. Otherwise, if `ancestor` is an {{Element}}
 and its [specified command value](#specified-command-value) for
 `command` is not
 [equivalent](#equivalent-values "equivalent values") to
 `value`, or if `ancestor` is not an {{Element}} and `value`
 is not null, [force the value](#force-the-value) of
 ` command` to `value` on
 `node`.

### Clearing an element\'s value

To [clear the value] of an {{Element}}
`element`:

The idea is to remove any [specified command
value](#specified-command-value) that the element might have for the
command. This might involve changing its attributes, [setting its tag
name](#set-the-tag-name "set the tag name"), or removing it entirely
while leaving its children in place. The key caller is [set the
selection\'s value](#set-the-selection's-value), which clears the values
of everything in the selection before doing anything else to keep the
markup tidy.

1. Let `command` be the current
 [command](#command).

2. If `element` is not [editable](#editable),
 return the empty list.

3. We want to abort early so that we don\'t try unsetting
 background-color on a non-inline element.

 If `element`\'s [specified command
 value](#specified-command-value) for `command`
 is null, return the empty list.

4. If `element` is a [simple modifiable
 element](#simple-modifiable-element):
 1. Let `children` be the \[=tree/children=\] of
 `element`.
 2. For each `child` in `children`, insert `child` into
 `element`\'s \[=tree/parent=\] immediately
 before `element`, [preserving
 ranges](#preserving-ranges).
 3. Remove `element` from its \[=tree/parent=\].
 4. Return `children`.

5. If `command` is \"strikethrough\", and
 `element` has a ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute that sets \"text-decoration\" to some value containing
 \"line-through\", delete \"line-through\" from the value.

6. If `command` is \"underline\", and
 ` element` has a ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute that sets \"text-decoration\" to some value containing
 \"underline\", delete \"underline\" from the value.

7. If the [relevant CSS property](#relevant-css-property) for
 `command` is not null, unset that property of
 `element`.

8. If `element` is a \[\^font\^\] element:
 1. If `command` is \"foreColor\", unset
 `element`\'s ` `[`color`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-color)
 attribute, if set.
 2. If `command` is \"fontName\", unset
 `element`\'s ` `[`face`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-face)
 attribute, if set.
 3. If `command` is \"fontSize\", unset
 `element`\'s ` `[`size`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-size)
 attribute, if set.

9. If `element` is an \[\^a\^\] element and
 `command` is \"createLink\" or \"unlink\", unset
 the ` `[`href`](http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#attr-hyperlink-href)
 property of `element`.

10. If we get past this step, we\'re something like \<b class=foo\>
 where we want to keep the extra attributes, so we stick them on a
 span.

 If `element`\'s [specified command
 value](#specified-command-value) for `command`
 is null, return the empty list.

11. [Set the tag name](#set-the-tag-name) of `element` to \"span\", and return the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of the result.

### Pushing down values

This algorithm goes up to just below the nearest ancestor with the right
style, then re-applies the bad styles repeatedly going down, omitting
the things we want to have the new style. This is basically what WebKit
does, although WebKit sometimes starts higher up and therefore makes
more intrusive changes, often creating more markup. IE follows the same
general approach too.

Gecko instead seems to start breaking up elements from the bottom, so
that the range consists of a few consecutive siblings, and it can then
break up the problematic element into a maximum of two pieces. The
spec\'s approach seems to create fewer elements and simpler markup (or
at least markup that\'s no more complex) in most cases I throw at it.

Gecko\'s approach does have the major advantage that it gets underlines
right in many cases for free. E.g.,

 <u>foo<font color=red>[bar]baz</font></u>
 -> <u>foo</u><font color=red>bar<u>baz</u></font> (spec)
 -> <u>foo</u><font color=red>bar</font><u><font color=red>baz</font></u> (Gecko)

The spec\'s markup here is much shorter and contains fewer elements, but
is wrong: the underline under \"baz\" has changed color from black to
red. It might be worth trying to copy Gecko\'s results in such cases,
but that won\'t solve all underline problems, so perhaps it\'s not worth
it.

Opera also seems to break up the markup surrounding the range, but even
more aggressively: even if it doesn\'t need to pull down styles. In some
cases this does actually result in shorter markup, specifically if the
existing tags are short (like i or b) and we\'re adding tags that are
long (like span with a style attribute).

To [push down values] to a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node`, given a new value
`new value`:

The idea here is that if an undesired value is being propagated from an
ancestor, we remove that style from the ancestor and re-apply it to all
the descendants other than `node`. This way we
don\'t have to have nested styles, which is usually more cluttered
(although not always).

1. Let `command` be the current
 [command](#command).

2. E.g., a text node child of a document fragment.

 If `node`\'s \[=tree/parent=\] is not an
 {{Element}}, abort this algorithm.

3. If the [effective command value](#effective-command-value) of
 `command` is [loosely
 equivalent](#loosely-equivalent-values "loosely equivalent values")
 to ` new value` on `node`,
 abort this algorithm.

4. Let `current ancestor` be `node`\'s \[=tree/parent=\].

5. Let `ancestor list` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.

6. While `current ancestor` is an
 [editable](#editable) {{Element}} and the [effective command
 value](#effective-command-value) of `command` is
 not [loosely
 equivalent](#loosely-equivalent-values "loosely equivalent values")
 to `new value` on it, append
 `current ancestor` to `ancestor list`, then set `current ancestor` to its
 \[=tree/parent=\].

7. If `ancestor list` is empty, abort this
 algorithm.

8. Let `propagated value` be the [specified command
 value](#specified-command-value) of `command` on
 the last member of `ancestor list`.

9. We can only remove specified values, so if the value isn\'t
 specified, give up. Unless we\'re actually trying to push down a
 null specified value, like for unlink.

 If `propagated value` is null and is not equal
 to `new value`, abort this algorithm.

10. ::: note
 If we go all the way up to the root and still don\'t have the
 desired value, pushing down values is pointless. It will create
 extra markup for no purpose. Except if the value is null, which
 basically just means \"try to get rid of anything affecting the
 current element but don\'t aim for any specific value\".

 Nevertheless, Chrome 14 dev does seem to do this. Running bold on
 \<span style=font-weight:300\>f\[o\]o\</span\> breaks up the span
 and adds a \<b\> as a sibling. In IE9, Firefox 6.0a2, and Opera
 11.50, it instead nests the \<b\> inside the \<span\>. It\'s a
 tradeoff: WebKit\'s behavior is better for things like

 <font color=red>fo[o</font><font color=blue>b]ar</font>
 -> <font color=red>fo</font><font color=green>[ob]</font><font color=blue>ar</font>

 (where the spec adds two extra font tags instead of one), but the
 spec is simpler for things like

 <font color=red>f[o]o</font>
 -> <font color=red>f<font color=green>[o]</font>o</font>

 (where WebKit splits the existing tag up in addition to creating a
 new tag). I\'m not particularly sure which approach is better
 overall, so I\'ll go with the majority of browsers. If these
 algorithms move to use runs of consecutive siblings instead of doing
 everything node-by-node, it might make sense to break up the parent
 as long as it won\'t create an extra node (i.e., we\'re styling
 something that includes the first or last child).
 :::

 If the [effective command value](#effective-command-value) of
 `command` is not [loosely
 equivalent](#loosely-equivalent-values "loosely equivalent values")
 to `new value` on the \[=tree/parent=\] of the
 last member of `ancestor list`, and
 `new value` is not null, abort this algorithm.

11. While `ancestor list` is not empty:
 1. Let `current ancestor` be the last member of
 `ancestor list`.
 2. Remove the last member from `ancestor list`.
 3. If the [specified command value](#specified-command-value) of
 `current ancestor` for `command` is not null, set `propagated value` to that value.
 4. Let `children` be the \[=tree/children=\] of
 `current ancestor`.
 5. If the [specified command value](#specified-command-value) of
 `current ancestor` for `command` is not null, [clear the value](#clear-the-value) of
 `current ancestor`.
 6. For every `child` in `children`:
 1. If `child` is `node`, continue with the next `child`.

 2. TODO: This will be incorrect for relative font sizes. If the
 font size on the parent was removed and the font size on the
 child is in ems or percents or something, it will now change
 value. This isn\'t likely to come up, so we\'ll ignore it
 for now.

 If `child` is an {{Element}} whose
 [specified command value](#specified-command-value) for
 `command` is neither null nor
 [equivalent](#equivalent-values "equivalent values") to
 `propagated value`, continue with the
 next `child`.

 3. If `child` is the last member of
 `ancestor list`, continue with the next
 `child`.

 4. [Force the value](#force-the-value) of `child`, with `command` as in this
 algorithm and `new value` equal to
 `propagated value`.

### Forcing the value of a node

To [force the value] of a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node` to `new value`:

This algorithm checks if the node has the desired value, and if not, it
wraps the node (or, if that\'s not possible, its descendants) in a
[simple modifiable element](#simple-modifiable-element). After forcing
the value, descendants might still have a different value.

1. Let `command` be the current
 [command](#command).

2. If `node`\'s \[=tree/parent=\] is null, abort
 this algorithm.

3. If `new value` is null, abort this algorithm.

4. If `node` is an [allowed child](#allowed-child)
 of \"span\":
 1. ::: note
 Even if the value matches, we stick it in a preceding sibling if
 possible. This ensures \"a\<cite\>b\</cite\>c\" -\>
 \"\<i\>a\<cite\>b\</cite\>c\</i\>\" instead of
 \"\<i\>a\</i\>\<cite\>b\</cite\>\<i\>c\</i\>\". While we\'re at
 it, we also handle more elaborate cases like
 \<b\>foo\</b\>\[bar\]\<b\>baz\</b\> and even
 \<i\>\<b\>foo\</b\>\</i\>\[bar\]\<i\>\<b\>baz\</b\>\</i\> (the
 latter becomes \<b\>\<i\>foo\</i\>bar\<i\>baz\</i\>\</b\>).

 Theoretically this algorithm could pointlessly reorganize the
 DOM in the event of unreasonable style rules, but it\'s not a
 big enough deal for us to care, since the resulting style will
 still be right.
 :::

 [Reorder modifiable
 descendants](#reorder-modifiable-descendants) of
 `node`\'s {{Node/ previousSibling}}.

 2. [Reorder modifiable
 descendants](#reorder-modifiable-descendants) of
 `node`\'s {{Node/nextSibling}}.

 3. The `new parent instructions` we\'d want are
 too complicated to reasonably feed into the wrap algorithm, so
 we just let them return null and do the wrapping ourselves if
 `sibling criteria` didn\'t return true.

 [Wrap](#wrap) the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `node`, with `sibling criteria` returning
 true for a [simple modifiable
 element](#simple-modifiable-element) whose [specified command
 value](#specified-command-value) is
 [equivalent](#equivalent-values "equivalent values") to
 `new value` and whose [effective command
 value](#effective-command-value) is [loosely
 equivalent](#loosely-equivalent-values "loosely equivalent values")
 to `new value` and false otherwise, and with
 `new parent instructions` returning null.

5. [Bug 13996](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13996).

 If `node` is [invisible](#invisible), abort this
 algorithm.

6. If the [effective command value](#effective-command-value) of
 `command` is [loosely
 equivalent](#loosely-equivalent-values "loosely equivalent values")
 to ` new value` on `node`,
 abort this algorithm.

7. If `node` is not an [allowed
 child](#allowed-child) of \"span\":
 1. Let `children` be all \[=tree/children=\] of
 `node`, omitting any that are {{Element}}s
 whose [specified command value](#specified-command-value) for
 `command` is neither null nor
 [equivalent](#equivalent-values "equivalent values") to
 `new value`.

 2. This means that if it has no children, we do nothing. IE9
 inserts an empty wrapper element in that case, but I\'m not sure
 what the point is, and no one else does, so I don\'t. WebKit
 seems to ignore the node if its only child consists solely of
 whitespace, but I don\'t see any grounds for that and no one
 else does, so I don\'t.

 [Force the value](#force-the-value) of each
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") in `children`, with
 `command` and `new value` as in this invocation of the algorithm.

 3. Abort this algorithm.

8. If the [effective command value](#effective-command-value) of
 `command` is [loosely
 equivalent](#loosely-equivalent-values "loosely equivalent values")
 to ` new value` on `node`,
 abort this algorithm.

9. Let `new parent` be null.

10. If the [CSS styling flag](#css-styling-flag) is false:
 1. If `command` is \"bold\" and
 `new value` is \"bold\", let
 `new parent` be the result of calling
 [`createElement("b")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `node`.

 2. If `command` is \"italic\" and
 ` new value` is \"italic\", let
 `new parent` be the result of calling
 [`createElement("i")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `node`.

 3. TODO: Actual UAs use strike, not s, but s is shorter and HTML5
 makes strike invalid. I\'ve gone with s for now, but maybe we
 want to change the spec to require strike.

 If `command` is \"strikethrough\" and
 `new value` is \"line-through\", let
 `new parent` be the result of calling
 [`createElement("s")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ ownerDocument}} of `node`.

 4. If `command` is \"underline\" and
 `new value` is \"underline\", let
 `new parent` be the result of calling
 [`createElement("u")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `node`.

 5. See comment for foreColor for discussion. TODO: Define more
 carefully what happens when things are out of range or not
 integers or whatever.

 If `command` is \"foreColor\", and
 `new value` is fully opaque with red, green,
 and blue components in the range 0 to 255:

 1. Let `new parent` be the result of
 calling [`createElement("font")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ ownerDocument}} of `node`.
 2. Set the ` `[`color`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-color)
 attribute of `new parent` to the result
 of applying the [rules for serializing simple color
 values](http://www.whatwg.org/specs/web-apps/current-work/multipage/common-microsyntaxes.html#rules-for-serializing-simple-color-values) to `new value`
 (interpreted as a [simple
 color](http://www.whatwg.org/specs/web-apps/current-work/multipage/common-microsyntaxes.html#simple-color)).

 6. If `command` is \"fontName\", let
 `new parent` be the result of calling
 [`createElement("font")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `node`,
 then set the ` `[`face`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-face)
 attribute of `new parent` to
 `new value`.

11. If `command` is \"createLink\" or \"unlink\":
 1. Let `new parent` be the result of calling
 [`createElement("a")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `node`.

 2. Set the ` `[`href`](http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#attr-hyperlink-href)
 attribute of `new parent` to
 `new value`.

 3. Nested a elements are bad, because they can\'t be serialized to
 text/html. hrefs should already have been cleared in a previous
 step, but we might have \<a name\> or such lurking about.

 Let `ancestor` be `node`\'s \[=tree/parent=\].

 4. While `ancestor` is not null:
 1. TODO: This will mean any link-specific attributes will be
 transferred, which makes them both invalid and useless. Is
 that okay? I don\'t really want to list them all, because
 that sort of list is prone to bitrot.

 If `ancestor` is an \[\^a\^\], [set the
 tag name](#set-the-tag-name) of `ancestor` to \"span\", and let `ancestor` be the result.

 2. Set `ancestor` to its \[=tree/parent=\].

12. WebKit is the only engine that ever outputs anything but font tags
 for fontSize. For size=7, it uses font-size: -webkit-xxx-large. We
 just output a font tag no matter what for size=7.

 If `command` is \"fontSize\"; and
 `new value` is one of \"x-small\", \"small\",
 \"medium\", \"large\", \"x-large\", \"xx-large\", or \"xxx-large\";
 and either the [CSS styling flag](#css-styling-flag) is false, or
 `new value` is \"xxx-large\": let
 `new parent` be the result of calling
 [`createElement("font")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `node`, then
 set the ` `[`size`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-size)
 attribute of `new parent` to the number from the
 following table based on `new value`:

 - x-small: 1
 - small: 2
 - normal: 3
 - large: 4
 - x-large: 5
 - xx-large: 6
 - xxx-large: 7

13. We always use sup/sub elements, even in CSS mode, following Gecko
 and contradicting WebKit. This is because \<span
 value=\"vertical-align: sub/super\"\>, the obvious equivalent (and
 what WebKit uses), behaves quite differently: it doesn\'t reduce
 font-size, which is ugly. WebKit\'s behavior is [a
 bug](https://bugs.webkit.org/show_bug.cgi?id=11089) anyway.

 If `command` is \"subscript\" or \"superscript\"
 and `new value` is \"subscript\", let
 `new parent` be the result of calling
 [`createElement("sub")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `node`.

14. If `command` is \"subscript\" or \"superscript\"
 and `new value` is \"superscript\", let
 `new parent` be the result of calling
 [`createElement("sup")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `node`.

15. If `new parent` is null, let
 `new parent` be the result of calling
 [`createElement("span")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `node`.

16. This preserves boundary points correctly, as usual.

 Insert `new parent` in `node`\'s \[=tree/parent=\] before `node`.

17. If the [effective command value](#effective-command-value) of
 `command` for `new parent`
 is not [loosely
 equivalent](#loosely-equivalent-values "loosely equivalent values")
 to ` new value`, and the [relevant CSS
 property](#relevant-css-property) for `command`
 is not null, set that CSS property of `new parent` to `new value` (if the new value would
 be valid).

 Need to be explicit. I think \"if the new value would be valid\"
 means \"if the new value isn\'t xxx-large for font-size\", need to
 double-check.

18. If `command` is \"strikethrough\", and
 `new value` is \"line-through\", and the
 [effective command value](#effective-command-value) of
 \"strikethrough\" for `new parent` is not
 \"line-through\", set the \"text-decoration\" property of
 `new parent` to \"line-through\".

19. If `command` is \"underline\", and
 ` new value` is \"underline\", and the
 [effective command value](#effective-command-value) of \"underline\"
 for `new parent` is not \"underline\", set the
 \"text-decoration\" property of `new parent` to
 \"underline\".

20. Append `node` to `new parent` as its last \[=tree/child=\], [preserving
 ranges](#preserving-ranges).

21. If `node` is an {{Element}} and the [effective
 command value](#effective-command-value) of `command` for `node` is not [loosely
 equivalent](#loosely-equivalent-values "loosely equivalent values")
 to `new value`:
 1. Insert `node` into the \[=tree/parent=\] of
 `new parent` before `new parent`, [preserving ranges](#preserving-ranges).
 2. Remove `new parent` from its
 \[=tree/parent=\].
 3. Let `children` be all \[=tree/children=\] of
 `node`, omitting any that are {{Element}}s
 whose [specified command value](#specified-command-value) for
 `command` is neither null nor
 [equivalent](#equivalent-values "equivalent values") to
 `new value`.
 4. [Force the value](#force-the-value) of each
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") in `children`, with
 `command` and `new value` as in this invocation of the algorithm.

To [reorder modifiable descendants] of a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node`, given a
[command](#command) `command` and a value
`new value`:

1. Let `candidate` equal `node`.

2. While `candidate` is a [modifiable
 element](#modifiable-element), and `candidate`
 has exactly one \[=tree/child=\], and that \[=tree/child=\] is also
 a [modifiable element](#modifiable-element), and
 `candidate` is not a [simple modifiable
 element](#simple-modifiable-element) or `candidate`\'s [specified command value](#specified-command-value) for
 `command` is not
 [equivalent](#equivalent-values "equivalent values") to
 `new value`, set `candidate`
 to its \[=tree/child=\].

3. If `candidate` is `node`, or
 is not a [simple modifiable element](#simple-modifiable-element), or
 its [specified command value](#specified-command-value) is not
 [equivalent](#equivalent-values "equivalent values") to
 `new value`, or its [effective command
 value](#effective-command-value) is not [loosely
 equivalent](#loosely-equivalent-values "loosely equivalent values")
 to ` new value`, abort these steps.

4. While `candidate` has \[=tree/children=\],
 insert the first \[=tree/child=\] of `candidate`
 into `candidate`\'s \[=tree/parent=\]
 immediately before `candidate`, [preserving
 ranges](#preserving-ranges).

5. ::: note
 If candidate had no children, any boundary point inside it will get
 moved to its parent here, which is okay. We don\'t want to preserve
 ranges, because that would move boundary points that originally were
 in candidate but were moved to its parent by the last step to move
 to node\'s parent.

 We move to after node so that boundary points before and after node
 wind up consistently inside candidate when we move preserving
 ranges. If we had

 {<node>foo<candidate></candidate></node>}

 it thus becomes

 {<node>foo</node>}<candidate></candidate>

 by the range mutation rules, and then when we move preserving
 ranges, it becomes

 <candidate>{<node>foo</node>}</candidate>

 which is reasonable.

 If we had inserted candidate before node, instead it would go

 {<candidate></candidate><node>foo</node>}
 {<candidate><node>foo</node>}</candidate>

 because of the interaction of regular range mutation rules with
 preserving-ranges rules.
 :::

 Insert `candidate` into `node`\'s \[=tree/parent=\] immediately after `node`.

6. Append the `node` as the last \[=tree/child=\]
 of `candidate`, [preserving
 ranges](#preserving-ranges).

### Setting the selection\'s value

To [set the selection\'s value] to
`new value`:

The effect of this algorithm is to ensure that all nodes [effectively
contained](#effectively-contained) in the selection have the value
requested, producing the simplest markup possible to achieve that
effect. It\'s inspired by the approach WebKit takes. The only places
where the algorithm should fail are when there\'s an !important CSS rule
that conflicts with the requested style (which we don\'t try to override
because we assume it\'s !important for a reason), or when it\'s
literally impossible to succeed (such as when a text-decoration or link
URL is propagated from a non-editable ancestor). Any other failures are
bugs.

First, if a node has a [specified command
value](#specified-command-value) for the command, we unset it ([clear
its value](#clear-the-value "clear the value")). This step also removes
[simple modifiable
elements](#simple-modifiable-element "simple modifiable element")
entirely, and replaces elements like \[\^b\^\] or \[\^font\^\] with
\[\^span\^\]s if they aren\'t simple modifiable elements. This will be
sufficient if the desired value is inherited from an ancestor, or if
it\'s the default (like font-style: normal) and no conflicting value is
inherited from an ancestor. Even if clearing values doesn\'t actually
fix the style of the node we\'re dealing with, we do it anyway to
simplify the generated markup.

If clearing values didn\'t work, and it looks like an ancestor has a
[specified command value](#specified-command-value) that we\'re
inheriting, we push the value down from that ancestor. Thus if we\'re
unbolding the letter \"r\" in

 foo bar baz,

we get

 foo bar baz.

If we didn\'t push down values, the final step (forcing values) would
instead give us

 foo bar baz,

which is much longer and uglier. We take care not to disturb the style
or semantics of anything but the node we\'re dealing with.

We\'ll only push down values if some ancestor actually has the value we
want, so we can inherit it. Otherwise, it will just create useless
markup.

Finally, if neither of the above strategies worked, we have to add new
markup to get the desired value ([forcing the
value](#force-the-value "force the value")). First we try just sticking
it into its previous or next sibling, if that\'s a [simple modifiable
element](#simple-modifiable-element) (so it won\'t add any styles or
semantics we don\'t want). Otherwise, we create a new simple modifiable
element and wrap it in that. It\'s common that a previous sibling is the
simple modifiable element we want, because often we\'ll set the value of
several consecutive siblings in succession. In that case, the element
created for the first can be reused for the later ones.

This last step works a bit differently if the node isn\'t an [allowed
child](#allowed-child) of \"span\". In that case, wrapping it in a
simple modifiable element would make the document less conforming than
it already was, or would cause other problems. Instead, we recursively
force the value of its children. The recursion will terminate when we
hit a node that\'s an allowed child of \"span\", or when there are no
further descendants. (In the latter case, there are no descendants that
are text nodes or such, so we don\'t really need to style anything.)

After all this, the node is guaranteed to have the value we want,
barring bugs in the algorithm or the two exceptions noted earlier
(!important style rules, and impossible cases). We then re-run the
algorithm on each child recursively. Typically this means just clearing
the value of each descendant, because it should then inherit the value
we just set on its ancestor. In the unusual case that a descendant\'s
value is wrong even after we clear its value, such as because of a
non-inline style rule (like trying to unbold a heading), we\'ll repeat
the above steps to ensure that the value really gets set as desired.

1. Let `command` be the current
 [command](#command).

2. IE9 seems to wrap the whole line instead, or something like that,
 although it does nothing for createLink. We follow all other
 browsers\' general behavior: change the state/value, and then make
 sure that takes effect if the user types something before changing
 the cursor position.

 If there is no [formattable node](#formattable-node) [effectively
 contained](#effectively-contained) in the [active
 range](#active-range):

 1. If `command` has [inline command activated
 values](#inline-command-activated-values), set the [state
 override](#state-override) to true if `new value` is among them and false if it\'s not.
 2. If `command` is \"subscript\", unset the
 [state override](#state-override) for \"superscript\".
 3. If `command` is \"superscript\", unset the
 [state override](#state-override) for \"subscript\".
 4. If `new value` is null, unset the [value
 override](#value-override) (if any).
 5. Otherwise, if `command` is \"createLink\" or
 it has a [value](#value) specified, set the [value
 override](#value-override) to `new value`.
 6. Abort these steps.

3. The last sentence here just prettifies the resulting range a bit.

 If the [active range](#active-range)\'s \[=range/start node=\] is an
 [editable](#editable) {{Text}} node, and its \[=range/start
 offset=\] is neither zero nor its \[=range/start node=\]\'s
 \[=Node/length=\], call [`splitText()`](http://dom.spec.whatwg.org/#dom-text-splittext)
 on the [active range](#active-range)\'s \[=range/start node=\], with
 argument equal to the [active range](#active-range)\'s
 \[=range/start offset=\]. Then set the [active
 range](#active-range)\'s \[=range/start node=\] to the result, and
 its \[=range/start offset=\] to zero.

4. If the [active range](#active-range)\'s \[=range/end node=\] is an
 [editable](#editable) {{Text}} node, and its \[=range/end offset=\]
 is neither zero nor its \[=range/end node=\]\'s \[=Node/length=\],
 call [`splitText()`](http://dom.spec.whatwg.org/#dom-text-splittext)
 on the [active range](#active-range)\'s \[=range/end node=\], with
 argument equal to the [active range](#active-range)\'s \[=range/end
 offset=\].

5. Let `element list` be all [editable](#editable)
 {{Element}}s [effectively contained](#effectively-contained) in the
 [active range](#active-range).

6. For each `element` in `element list`, [clear the value](#clear-the-value) of
 `element`.

7. ::: note
 We skip non-editable nodes.

 IE9
 : Allows everything to be modified by execCommand(), regardless of
 whether it\'s editable.

 Firefox 4.0
 : Ignores execCommand() if the start and end of the selection are
 not both editable. If the start and end are editable but
 something in the middle is not, seems to relocate the
 non-editable part in the middle or something like that.

 Chrome 12 dev
 : Ignores execCommand() if the start and end of the selection are
 not both editable. If the start and end are editable but
 something in the middle is not, applies the given command but
 skips the non-editable parts. But the state doesn\'t ignore the
 non-editable parts, so if you bold such a selection you can\'t
 unbold it, for instance, since the middle part will remain bold
 (so it will keep on trying to bold it instead of switching to
 unbold).

 Opera 11.00
 : Ignores execCommand() if the start and end of the selection are
 not both editable. If the start and end are editable but
 something in the middle is not, applies the command to
 everything, even the non-editable part.

 I chose to go with the non-IE behavior, per
 [discussion](http://lists.whatwg.org/htdig.cgi/whatwg-whatwg.org/2011-April/031147.html).
 Ignoring non-editable things is convenient for the common use-case
 of an editor, where you don\'t want the user to bold random parts of
 the UI when they hit the bold button. For cases where it\'s not
 desired, you can always turn designMode on briefly before using
 execCommand(), so the non-IE behavior is a lot easier to work around
 than the IE behavior.

 I don\'t see the value in ever just ignoring execCommand(). If the
 start and end are not editable, I\'m going to say you should still
 style any editable nodes in between. I\'m also going to ignore
 non-editable nodes for the purposes of determining state, so (for
 instance) if all the editable nodes are bolded, it will unbold
 instead of bolding.
 :::

 Let `node list` be all [editable](#editable)
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") [effectively contained](#effectively-contained)
 in the [active range](#active-range).

8. TODO: This is inefficient. It would be most efficient to only push
 down values on the highest-level effectively contained nodes, and to
 batch operations so we handle runs of adjacent siblings at once.
 Should we bother fixing this?

 For each `node` in `node list`:

 1. [Push down values](#push-down-values) on `node`.

 2. If the node isn\'t an allowed child of \"span\", forcing its
 value will just force its children\'s value, which is redundant.
 So don\'t.

 If `node` is an [allowed
 child](#allowed-child) of \"span\", [force the
 value](#force-the-value) of `node`.

### [The `backColor`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

For historical reasons, backColor and hiliteColor behave identically.

We have three behaviors to choose from for this one:

1. Chrome 11 dev and IE 9 RC treat it the same as hiliteColor (although
 IE 9 RC doesn\'t support hiliteColor itself).
2. Firefox 4 in non-CSS mode sets the bgcolor of the nearest td or
 body, or something like that. In testing, it seems to jump out of
 contenteditable elements to style non-editable ancestors, which is
 alarming.
3. Firefox 4 in CSS mode and Opera 11 set the background of the nearest
 block container, although it doesn\'t seem to be very dependable
 (probably I just don\'t get what exactly it\'s doing).

\(1\) is obviously redundant, but has plurality support, so we could
spec it that way if the other ways were useless.

\(3\) is incoherent from a user perspective. For instance, if you try it
on paragraphs the background will have big gaps where the margins are.
If you try it on an inline element that\'s a child of the editing host,
it will do nothing or apply the background to everything or such, even
though such an inline element is visually indistinguishable from one
sitting inside a div. This would only make sense if we take considerable
effort to ensure that block elements all have no margins, or if we wrap
things in a div if they have margins, or something like that.

That leaves (2). That might be useful if it actually set the document\'s
background color, but it seems like it sets table cell backgrounds
sometimes instead, which is really confusing.

The path of least resistance is to standardize this as meaning the same
thing as hiliteColor, and make up new commands if we want to do things
like set the document background color. See hiliteColor for comments.

[Action](#action):

1. If `value` is not a valid CSS color, prepend
 \"#\" to it.
2. If `value` is still not a valid CSS color, or if
 it is currentColor, return false.
3. [Set the selection\'s value](#set-the-selection's-value) to
 `value`.
4. Return true.

[Standard inline value command](#standard-inline-value-command)

[Relevant CSS property](#relevant-css-property): \"background-color\"

[Equivalent values](#equivalent-values): Either both strings are valid
CSS colors and have the same red, green, blue, and alpha components, or
neither string is a valid CSS color.

### [The `bold`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

If the selection is collapsed (but not if it contains nothing but is not
collapsed), IE9 wraps the whole line in a \<strong\>. This seems bizarre
and no one else does it, so I don\'t do it. It\'s a similar story for
similar commands (fontName, italic, etc.). Except not for strikethrough,
where it just does nothing if the selection is empty. Why strikethrough?
I don\'t know.

[Action](#action): If
[`queryCommandState("bold")`{title="queryCommandState()"}](#querycommandstate())
returns true, [set the selection\'s value](#set-the-selection's-value)
to \"normal\". Otherwise [set the selection\'s
value](#set-the-selection's-value) to \"bold\". Either way, return true.

The cutoff of 600 matches Chrome 14 dev. The cutoff used by IE9 and
Firefox 6.0a2 seems to be 500, and the distinction isn\'t relevant for
Opera 11.11 (it doesn\'t use CSS here at all AFAICT). On my test systems
with default fonts, Chrome 14 dev displays 700 and up as bold, while the
other three display 600 and up as bold.

Thus in Chrome on my system, the bold command will behave a bit oddly
the first time you hit it if there\'s anything in the range with
font-weight: 600, but it will look right in other browsers. On the other
hand, if I followed IE/Firefox, it would look wrong on all my browsers
for font-weight: 500.

700 actually makes more sense: then you\'d view 100-300 as light,
400-600 as medium, 700-900 as bold. But that\'s not how it seems to work
in browsers, so I\'ll go with 600 as the cutoff.

[Inline command activated values](#inline-command-activated-values):
\"bold\", \"600\", \"700\", \"800\", or \"900\"

[Relevant CSS property](#relevant-css-property): \"font-weight\"

[Equivalent values](#equivalent-values): Either the two strings are
equal, or one is \"bold\" and the other is \"700\", or one is \"normal\"
and the other is \"400\".

### [The `createLink`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

If the selection doesn\'t contain anything (meaning, e.g.,
deleteContents() doesn\'t change anything), then Chrome 12 dev inserts a
link at the selection start, with the text equal to the link URL. Other
browsers don\'t do it, so I don\'t either.

IE10PP2, Firefox 7.0a2, Chrome 14 dev, and Opera 11.50 all do not
support indeterminate, state, or value for createLink or unlink. I
previously defined indeterminate and value anyway because they make
sense, but then [undefined
them](https://www.w3.org/Bugs/Public/show_bug.cgi?id=14067). The
nontrivial thing is what value to return if there\'s no link, since any
string can occur as a link href, in principle.

What are the use-cases for indeterm, state, or value for
createLink/unlink?

[Action](#action):

1. Firefox 4b11 and Chrome 11 dev both silently do nothing in this
 case. IE 9 RC and Opera 11 both treat the request literally. Gecko
 and WebKit probably have it right here: users who enter no URL are
 very unlikely to want to link to a relative URL resolving to the
 current document. If they really want to, they can always specify
 \"#\" for the value, or the author can rewrite it, so it\'s not like
 this makes the API less useful.

 If `value` is the empty string, return false.

2. ::: note
 There are three approaches here. For instance, if you ask browsers
 to create a link to \"http://example.org\" on the \"b\" here:

 <a href=http://example.com><b>Abc</b></a>

 Chrome 10 dev produces:

 <b><a href=http://example.com>A</a><a href=http://example.org>b</a><a href=http://example.com>c</a></b>

 Firefox 4b11 produces (roughly):

 <a href=http://example.com><b>A<a href=http://example.org>b</a>c</b></a>

 (This doesn\'t round-trip through text/html serialization.) IE 9 RC
 and Opera 11 produce simply:

 <a href=http://example.org><b>Abc</b></a>

 The last behavior probably best matches user expectations. If you
 happen to miss out a character when selecting the link you want to
 change, do you really intend to only change the link of part of it?
 :::

 For each [editable](#editable) \[\^a\^\] element that has an
 ` `[`href`](http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#attr-hyperlink-href)
 attribute and is an \[=tree/ancestor=\] of some
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") [effectively contained](#effectively-contained)
 in the [active range](#active-range), set that \[\^a\^\] element\'s
 ` `[`href`](http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#attr-hyperlink-href)
 attribute to `value`.

3. [Set the selection\'s value](#set-the-selection's-value) to
 `value`.

4. Return true.

### [The `fontName`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

UAs differ a bit in the details here:

IE 9 RC
: Empty string sets \<font face=\"\"\>

Firefox 4b11
: Empty string does nothing

Chrome 11 dev
: Empty string does nothing, \'\"monospace\"\' same as \'monospace\'
 (i.e., cannot escape font-family keywords because quotes are
 stripped, clearly wrong)

Opera 11
: Empty string sets \<font face=\"\"\>

Setting an empty font-family has the effect of inheriting the font from
the parent (although I don\'t see where the February 24, 2011 CSS 3
Fonts draft says that). Thus it makes sense that if we special-case
this, it should be to unset the font somehow.

Special-casing the empty string to do nothing doesn\'t make sense to me.
With createLink we\'d expect the user to enter the URL themselves, so it
makes sense to special-case clicking OK without entering anything. But
here it\'s very likely that the font list will be fixed by the author
(how many users will understand CSS font-family syntax?), so I don\'t
think such usability concerns apply.

[Action](#action): [Set the selection\'s
value](#set-the-selection's-value) to `value`, then
return true.

The value is complicated.

IE 9 RC
: Always the empty string. Not very useful.

Firefox 4b11
: Confusing. Sometimes it returns generic family names, like
 \"sans-serif\". Sometimes it gives specific font names, like \"tt\"
 when the font is specified as \"monospace\". Sometimes it gives the
 literal font-family string. Not sure what it\'s doing here.

Chrome 11 dev
: Gives the literal value of font-family, except if it\'s inherited
 from default values (no explicit style declarations anywhere), when
 it seems to return the exact font name.

Opera 11
: Returns the literal value of font-family, except if it\'s inherited
 from default values, when it returns the empty string.

I\'m just going to punt on this and say it should be the resolved value
of font-family. I\'ll leave CSSOM to decide what that means if there are
no applicable style rules.

[Standard inline value command](#standard-inline-value-command)

[Relevant CSS property](#relevant-css-property): \"font-family\"

### [The `fontSize`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

IE 9
: Parses the value as a number (allowing floating-point), rounds to
 the nearest integer, then clamps to the range 1 to 7. If the value
 is not a valid number, including if it has trailing characters (like
 \"2em\"), does nothing. Normalizes relative sizes, so \"+0\" is the
 same as \"+3\", etc. Treats empty string the same as \"1\".

Firefox 4.0
: Passes the value through literally to \<font size=\>, so \"2em\"
 gets you \<font size=\"2em\"\>. Always uses \<font\>, even with
 styleWithCss true. Ignores the command if the value is the empty
 string.

Chrome 12 dev
: Parses the value as a legacy font size, so \"2em\" becomes \"2\",
 then outputs a \<font\> with the resulting number. If there is no
 resulting number, like for a value of \"xx-small\", does nothing. In
 styleWithCss mode, outputs a span with corresponding CSS keywords: 1
 = x-small, 2 = small, . . ., 6 = xx-large, 7 = -webkit-xxx-large.
 Normalizes relative sizes, so \"+0\" is the same as \"3\", etc.
 Ignores the command if the value is the empty string.

Opera 11
: Parses the value as an integer (ignoring floating-point as trailing
 characters), then outputs that. This means that \"+0\" becomes
 \<font size=0\> instead of \<font size=+0\> or \<font size=3\>.
 Non-numeric values get interpreted as 0. Does not clamp, and is
 willing to output negative numbers. Treats empty string as \"0\".

What all of these have in common is that they force the author to deal
with legacy font values and don\'t let them use CSS. This is
undesirable, but to avoid it we\'d really have to create a new command.
If nothing else, the value returned by `queryCommandValue()`{title=""}
has to be numeric, so authors can\'t really use the command sanely no
matter what we do. See [bug
14251](https://www.w3.org/Bugs/Public/show_bug.cgi?id=14251).

Note that 1 is the same size as x-small in browsers, not xx-small,
contrary to the CSS Fonts spec.

[Action](#action):

1. [Strip leading and trailing
 whitespace](http://www.whatwg.org/specs/web-apps/current-work/multipage/common-microsyntaxes.html#strip-leading-and-trailing-whitespace) from `value`.

2. If `value` is not a [valid floating point
 number](http://www.whatwg.org/specs/web-apps/current-work/multipage/common-microsyntaxes.html#valid-floating-point-number), and would not be a [valid floating point
 number](http://www.whatwg.org/specs/web-apps/current-work/multipage/common-microsyntaxes.html#valid-floating-point-number) if a single leading \"+\" character were
 stripped, return false.

3. If the first character of `value` is \"+\",
 delete the character and let `mode` be
 \"relative-plus\".

4. Otherwise, if the first character of `value` is
 \"-\", delete the character and let `mode` be
 \"relative-minus\".

5. Otherwise, let `mode` be \"absolute\".

6. Apply the [rules for parsing non-negative
 integers](http://www.whatwg.org/specs/web-apps/current-work/multipage/common-microsyntaxes.html#rules-for-parsing-non-negative-integers) to `value`, and let
 `number` be the result.

7. If `mode` is \"relative-plus\", add three to
 `number`.

8. If `mode` is \"relative-minus\", negate
 `number`, then add three to it.

9. If `number` is less than one, let
 `number` equal 1.

10. If `number` is greater than seven, let
 `number` equal 7.

11. Set `value` to the string here corresponding to
 `number`:

 The entry for 7 here is an issue: there\'s no CSS value that
 corresponds to it. Even if we got one added to the drafts, it
 wouldn\'t be backward-compatible to use it. WebKit is the only
 engine that supports CSS output for fontSize, and it uses
 -webkit-xxx-large in this case, which is unworkable. Instead, we
 just always output a font tag for size 7. If authors want conforming
 markup, they\'ll need to give CSS sizes above size 7, not legacy
 sizes.

 - 1: x-small
 - 2: small
 - 3: medium
 - 4: large
 - 5: x-large
 - 6: xx-large
 - 7: xxx-large

12. [Set the selection\'s value](#set-the-selection's-value) to
 `value`.

13. Return true.

This follows Firefox 6.0a2. Chrome 14 dev always returns false. Note
that indeterminacy here keys off the effective command value, while the
value is based only on an approximation (a number from one to seven).
Thus it\'s possible for every subrange of the selection to have the same
value, but for the selection to still be indeterminate. Setting the
fontSize to the value will make it determinate without changing
anything\'s value.

[Indeterminate](#indeterminate): True if among [formattable
nodes](#formattable-node "formattable node") that are [effectively
contained](#effectively-contained) in the [active range](#active-range),
there are two that have distinct [effective command
values](#effective-command-value "effective command value"). Otherwise
false.

IE9
: Seems to return a number based on the computed font-size, but only
 if it\'s exactly right, otherwise it returns null. Something like
 that.

Firefox 6.0a2
: Seemingly goes up to the nearest ancestor that\'s a \<font size\>
 and returns the literal value of that attribute, or \"\" if there\'s
 no such ancestor.

Chrome 14 dev
: Gets the computed font-size in pixels, and rounds to the nearest
 \<font size\> equivalent, rounding up in the event of a tie. Except
 that if it\'s small enough, it returns \"0\", which doesn\'t make
 sense because that behaves the same as \"1\".

Opera 11.11
: Like Firefox, except it returns \"3\" if there\'s no \<font size\>
 ancestor, and it converts relative values to absolute (\"+1\" -\>
 \"4\").

Chrome\'s behavior seems the most useful. As usual, IE returns a
variable type and all other browsers return strings, and we follow other
browsers.

If the selection isn\'t someplace editable, Chrome works like usual;
some other browsers behave differently. I see no reason to behave
differently.

[Value](#value):

1. If the [active range](#active-range) is null, return the empty
 string.

2. See comment for standard inline value commands on how I decided on
 this choice of node.

 Let `pixel size` be the [effective command
 value](#effective-command-value) of the first [formattable
 node](#formattable-node) that is [effectively
 contained](#effectively-contained) in the [active
 range](#active-range), or if there is no such node, the [effective
 command value](#effective-command-value) of the [active
 range](#active-range)\'s \[=range/start node=\], in either case
 interpreted as a number of pixels.

3. Return the [legacy font size for](#legacy-font-size-for)
 `pixel size`.

[Relevant CSS property](#relevant-css-property): \"font-size\"

The [legacy font size for] an integer
`pixel size` is returned by the following algorithm:

1. Let `returned size` be 1.
2. While `returned size` is less than 7:
 1. Let `lower bound` be the [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) of
 \"font-size\" in pixels of a \[\^font\^\] element whose
 ` `[`size`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-size)
 attribute is set to `returned size`.
 2. Let `upper bound` be the [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) of
 \"font-size\" in pixels of a \[\^font\^\] element whose
 ` `[`size`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#dom-font-size)
 attribute is set to one plus `returned size`.
 3. Let `average` be the average of
 `upper bound` and `lower bound`.
 4. If `pixel size` is less than
 ` average`, return the one-[code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit)
 string consisting of the digit `returned size`.
 5. Add one to `returned size`.
3. Return \"7\".

### [The `foreColor`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

Color interpretations:

::: {style="height:1px;background:white;z-index:2;position:absolute;left:0;right:0"}

``` {style="white-space:pre; overflow:auto; float:right; background:white; padding:0.5em; border: 1px solid gray; border-right: none; margin-top: 0; margin-bottom: 0"}

 IE10PP2 Firefox 7.0a2 Chrome 14 dev Opera 11.50
blue blue blue #0000ff #0000ff
f #f - - #f00000
#f #f - - #f00000
00f #00f - #0000ff #00000f
#00f #00f rgb(0, 0, 255) #0000ff #00000f
0000ff #0000ff - #0000ff #0000ff
#0000ff #0000ff rgb(0, 0, 255) #0000ff #0000ff
000000fff #0000ff - - -
#000000fff #0000ff - - -
rgb(0, 0, 255) rgb(0,0,255) rgb(0, 0, 255) #0000ff #00b000
rgb(0%, 0%, 100%) rgb(0,0,255) rgb(0, 0, 255) #0000ff #00b000
rgb( 0 ,0 ,255) rgb(0,0,255) rgb(0, 0, 255) #0000ff #00b000
rgba(0, 0, 255, 0.0) #ba0000 rgba(0, 0, 255, 0) rgba(0, 0, 255, 0) #00ba00
rgb(15, -10, 375) rgb(15,0,255) rgb(15, 0, 255) #0f00ff #00b015
rgba(0, 0, 0, 1) #ba0010 rgb(0, 0, 0) - #00ba00
rgba(255, 255, 255, 1) #000055 rgb(255, 255, 255) #ffffff #00ba02
rgba(0, 0, 255, 0.5) #ba0000 rgba(0, 0, 255, 0.5) rgba(0, 0, 255, 0.5) #00ba00
hsl(240, 100%, 50%) #000150 rgb(0, 0, 255) #0000ff #000024
cornsilk cornsilk cornsilk #fff8dc #fff8dc
potato quiche #0000c0 - - #000a00
transparent transparent - rgba(0, 0, 0, 0) #00a000
currentColor #c0e000 currentcolor rgba(0, 0, 0, 0) #c000e0
```

::: {style="clear:right"}

::: {style="height:1px;background:white;z-index:2;position:absolute;left:0;right:0;margin-top:-1px"}

The interpretations given for Firefox are only in styleWithCSS mode. In
non-styleWithCSS mode, it just outputs the string literally as the
\<font color\> attribute value, which can lead to different results. The
given output for Chrome is for \<font\>; the output in styleWithCSS mode
is the same, but rgb() is used instead of hex notation, and
\"transparent\" and \"currentcolor\" are passed through under those
names. IE and Opera only support \<font\> to begin with.

Conclusions:

- Everyone accepts simple color keywords and #xxxxxx notation.
- Opera mangles #xxx, but everyone else handles it fine.
- The leading \# is optional in all browsers but Gecko.
- rgb() is accepted by everyone but Opera.
- rgba() and hsl() are accepted by Gecko and WebKit, but rejected by IE
 and Opera.
- IE and Opera mangle unrecognized stuff, Gecko and WebKit ignore.
- Browsers will happily output stuff like \"transparent\" and \"rgba()\"
 into \<font color\> even though it won\'t be uniformly accepted there.
- Opera and WebKit normalize the output color very aggressively, Gecko
 leaves keywords intact but otherwise normalizes for CSS output (but
 doesn\'t normalize at all for \<font\>), and IE normalizes
 inconsistently.

What I\'m going to say is that it either has to be a valid CSS color, or
prefixing it with \# must result in a valid CSS color. For
`<font>`{title=""}, I\'ll say that the output color should be normalized
to #xxxxxx form. If the color is not a simple color (fully opaque with
all channels between 0 and 255), I\'ll force `style=""`{title=""} even
if styleWithCSS mode is off. Some of this disagrees with all browsers,
but it\'s unlikely to hurt and it makes sense.

[Action](#action):

1. TODO: Define \"valid CSS color\" (here and in other color places).

 If `value` is not a valid CSS color, prepend
 \"#\" to it.

2. currentColor is bad for the same reason as relative font sizes. It
 will confuse the algorithm, and doesn\'t seem very useful anyway.

 If `value` is still not a valid CSS color, or if
 it is currentColor, return false.

3. [Set the selection\'s value](#set-the-selection's-value) to
 `value`.

4. Return true.

Opera 11 seems to return true for the state if there\'s some color style
applied, false otherwise, which seems fairly useless; authors want to
use value here, not state. So I\'ll match other browsers and not define
any state.

For value, the spec essentially matches Firefox 6.0a2 and Chrome 14 dev,
as far as how to decide what color the node has. IE9 seems to always
return the number 0 for some bizarre reason. There are some cases where
Firefox returns the empty string for some reason, and it seems to select
the active node a little differently. Opera uses #xxxxxx format for
getComputedStyle() but rgb() here, and also drops the transparent part
of the color if there is any.

[Standard inline value command](#standard-inline-value-command)

[Relevant CSS property](#relevant-css-property): \"color\"

[Equivalent values](#equivalent-values): Either both strings are valid
CSS colors and have the same red, green, blue, and alpha components, or
neither string is a valid CSS color.

### [The `hiliteColor`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

For historical reasons, backColor and hiliteColor behave identically.

IE 9 RC doesn\'t support this. It uses backColor instead, but Gecko and
Opera treat that differently, while all non-IE browsers treat
hiliteColor the same, so I\'m standardizing hiliteColor as the way to
highlight text.

This is slightly tricky, because background-color does different things
on block and inline elements. Given the name (\"hiliteColor\"), we
really only want to apply it to inline elements. This is how everyone
but Gecko behaves, but Gecko sometimes applies it to blocks too. WebKit
doesn\'t set it on non-inline elements, but does clear it and push it
down from them.

The spec doesn\'t do any of these: background-color on non-inline
elements is not touched by hiliteColor, neither created nor removed. If
users want to remove the style, they need to use removeFormat. Adding it
usually makes no sense; see the comment for backColor.

For color parsing, see the comment for foreColor.

See [bug 13829](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13829).

[Action](#action):

1. If `value` is not a valid CSS color, prepend
 \"#\" to it.

2. currentColor is bad for the same reason as relative font sizes. It
 will confuse the algorithm, and doesn\'t seem very useful anyway.
 For hiliteColor you could conceive of it being useful, but it will
 still confuse the algorithm, so ban it for now anyway.

 If `value` is still not a valid CSS color, or if
 it is currentColor, return false.

3. [Set the selection\'s value](#set-the-selection's-value) to
 `value`.

4. Return true.

For indeterminacy, this follows no one. Firefox 6.0a2 and Chrome 14 dev
both always return false. However, the spec makes sense, since it\'s
consistent with other commands.

[Standard inline value command](#standard-inline-value-command)

[Relevant CSS property](#relevant-css-property): \"background-color\"

[Equivalent values](#equivalent-values): Either both strings are valid
CSS colors and have the same red, green, blue, and alpha components, or
neither string is a valid CSS color.

### [The `italic`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Action](#action): If
[`queryCommandState("italic")`{title="queryCommandState()"}](#querycommandstate())
returns true, [set the selection\'s value](#set-the-selection's-value)
to \"normal\". Otherwise [set the selection\'s
value](#set-the-selection's-value) to \"italic\". Either way, return
true.

[Inline command activated values](#inline-command-activated-values):
\"italic\" or \"oblique\"

[Relevant CSS property](#relevant-css-property): \"font-style\"

### [The `removeFormat`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

See [bug](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13632), and
also [research by Ryosuke for
WebKit](https://bugs.webkit.org/show_bug.cgi?id=43017).

Tested in IE 9, Firefox 4.0, Chrome 12 dev, Opera 11.00.

- Tags stripped by everyone: b big cite code dfn em font i ins kbd s
 samp small strike strong sub sup tt u var
- Tags left alone by everyone: br hr img
- Unrecognized elements: stripped by Firefox and Opera, left alone by IE
 and Chrome.
- blink: stripped only by IE
- abbr: stripped only by Firefox
- a, wbr: stripped only by Opera
- nobr: left alone only by Firefox
- acronym, bdo, q: left alone only by Opera
- bdi, del, mark, span, svg: treated the same as unknown elements

All elements whose default rendering is display: block are left
untouched by all browsers (although IE seems to throw an exception on
\<marquee\> for some reason).

It\'s not clear to me why we should leave \<a\> alone, but everyone but
Opera does. In OpenOffice.org 3.2.1, doing \"Default Formatting
(Ctrl+M)\" doesn\'t remove links. In Microsoft Word 2007, doing \"Clear
Formatting\" also doesn\'t remove links. Verdict: don\'t remove links.
Apparently they don\'t logically qualify as \"formatting\".

Conclusion: IE/WebKit is a solid majority by market share and they\'re
closely interoperable, since WebKit copied IE here. Also, it makes more
sense to assume that unrecognized elements don\'t represent any kind of
inline formatting, i.e., have a blacklist of elements to remove instead
of a whitelist to keep. Thus I remove more or less the same things as
IE/WebKit.

I remove blink because IE does it and it makes sense, although Chrome
doesn\'t; I remove abbr although only Firefox does, for consistency with
acronym; and I remove bdi and mark because they\'re evidently left alone
only because they\'re unrecognized. Finally, I remove span because
otherwise, something like
`<span style="font-variant: small-caps">`{title=""} will be left intact,
which isn\'t expected and matches no browser except IE. (Chrome doesn\'t
remove spans in general, but it does remove spans with style attributes,
or something like that.)

Browsers will split up all these inline elements if the selection is
contained within them. Opera does strip unrecognized elements with
display: block if they\'re within the selection, but doesn\'t split them
up if they contain the selection.

Chrome 14 dev removes style attributes from every element in the range,
but IE10PP2, Firefox 7.0a2, and Opera 11.50 do not, so I go with them.
As noted above, this means I need to remove spans. I could conceivably
change to remove only spans with style attributes, but it doesn\'t seem
worth it: I\'ll just match Gecko.

TODO: This has to be kept in sync when new HTML elements are added. I
need to figure out some way of coordinating this.

A [removeFormat candidate] is an
[editable](#editable) [HTML element](#html-element) with
\[=Element/local name=\] \"abbr\", \"acronym\", \"b\", \"bdi\", \"bdo\",
\"big\", \"blink\", \"cite\", \"code\", \"dfn\", \"em\", \"font\",
\"i\", \"ins\", \"kbd\", \"mark\", \"nobr\", \"q\", \"s\", \"samp\",
\"small\", \"span\", \"strike\", \"strong\", \"sub\", \"sup\", \"tt\",
\"u\", or \"var\".

[Action](#action):

1. Let `elements to remove` be a list of every
 [removeFormat candidate](#removeformat-candidate) [effectively
 contained](#effectively-contained) in the [active
 range](#active-range).

2. For each `element` in
 `elements to remove`:
 1. While `element` has \[=tree/children=\],
 insert the first \[=tree/child=\] of `element` into the \[=tree/parent=\] of `element` immediately before `element`,
 [preserving ranges](#preserving-ranges).
 2. Remove `element` from its \[=tree/parent=\].

3. The last sentence just prettifies the resulting range a bit.

 If the [active range](#active-range)\'s \[=range/start node=\] is an
 [editable](#editable) {{Text}} node, and its \[=range/start
 offset=\] is neither zero nor its \[=range/start node=\]\'s
 \[=Node/length=\], call [`splitText()`](http://dom.spec.whatwg.org/#dom-text-splittext)
 on the [active range](#active-range)\'s \[=range/start node=\], with
 argument equal to the [active range](#active-range)\'s
 \[=range/start offset=\]. Then set the [active
 range](#active-range)\'s \[=range/start node=\] to the result, and
 its \[=range/start offset=\] to zero.

4. If the [active range](#active-range)\'s \[=range/end node=\] is an
 [editable](#editable) {{Text}} node, and its \[=range/end offset=\]
 is neither zero nor its \[=range/end node=\]\'s \[=Node/length=\],
 call [`splitText()`](http://dom.spec.whatwg.org/#dom-text-splittext)
 on the [active range](#active-range)\'s \[=range/end node=\], with
 argument equal to the [active range](#active-range)\'s \[=range/end
 offset=\].

5. Let `node list` consist of all
 [editable](#editable)
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") [effectively contained](#effectively-contained)
 in the [active range](#active-range).

6. TODO: Splitting the parent is really a block algorithm. It\'s not
 clear whether it\'s desirable to use for inline nodes. Perhaps it\'s
 okay, but it makes me a little uneasy.

 For each `node` in `node list`, while `node`\'s \[=tree/parent=\] is
 a [removeFormat candidate](#removeformat-candidate) [in the same
 editing host](#in-the-same-editing-host) as `node`, [split the parent](#split-the-parent) of the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `node`.

7. This step is for cases like \<p
 style=font-weight:bold\>foo\[bar\]baz\</p\>, where
 splitting/removing tags won\'t help. We don\'t need to run
 superscript, since subscript does the same thing here. We run
 subscript first so \<sub\>/\<sup\> won\'t upset fontSize.

 For each of the entries in the following list, in the given order,
 [set the selection\'s value](#set-the-selection's-value) to null,
 with `command` as given.

 1. subscript
 2. bold
 3. fontName
 4. fontSize
 5. foreColor
 6. hiliteColor
 7. italic
 8. strikethrough
 9. underline

8. Return true.

### [The `strikethrough`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

TODO: See underline TODO.

[Action](#action): If
[`queryCommandState("strikethrough")`{title="queryCommandState()"}](#querycommandstate())
returns true, [set the selection\'s value](#set-the-selection's-value)
to null. Otherwise [set the selection\'s
value](#set-the-selection's-value) to \"line-through\". Either way,
return true.

[Inline command activated values](#inline-command-activated-values):
\"line-through\"

### [The `subscript`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Action](#action):

1. Call
 [`queryCommandState("subscript")`{title="queryCommandState()"}](#querycommandstate()),
 and let `state` be the result.
2. [Set the selection\'s value](#set-the-selection's-value) to null.
3. If `state` is false, [set the selection\'s
 value](#set-the-selection's-value) to \"subscript\".
4. Return true.

[Indeterminate](#indeterminate): True if either among [formattable
nodes](#formattable-node "formattable node") that are [effectively
contained](#effectively-contained) in the [active range](#active-range),
there is at least one with [effective command
value](#effective-command-value) \"subscript\" and at least one with
some other [effective command value](#effective-command-value); or if
there is some [formattable node](#formattable-node) [effectively
contained](#effectively-contained) in the [active range](#active-range)
with [effective command value](#effective-command-value) \"mixed\".
Otherwise false.

For \<sup\>\<sub\>foo\</sub\>\</sup\>, Firefox 6.0a2 and Opera 11.11 say
the state is true for both superscript and subscript, and indeterminate
is false; Chrome 14 dev says it\'s true for subscript but not
superscript, and indeterminate is false. We follow neither of these
behaviors: we return false for both states, and say indeterminate is
true. The reason is because we want to return true for a state if we\'ll
do nothing, false if we\'ll do something; and if we have nesting like
this, we\'ll always do something, namely get rid of all those ancestors
and replace them with a single tag. This matches what happens in other
indeterminate situations, so it\'s fair to consider it indeterminate.

[Inline command activated values](#inline-command-activated-values):
\"subscript\"

### [The `superscript`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Action](#action):

1. Call
 [`queryCommandState("superscript")`{title="queryCommandState()"}](#querycommandstate()),
 and let `state` be the result.
2. [Set the selection\'s value](#set-the-selection's-value) to null.
3. If `state` is false, [set the selection\'s
 value](#set-the-selection's-value) to \"superscript\".
4. Return true.

[Indeterminate](#indeterminate): True if either among [formattable
nodes](#formattable-node "formattable node") that are [effectively
contained](#effectively-contained) in the [active range](#active-range),
there is at least one with [effective command
value](#effective-command-value) \"superscript\" and at least one with
some other [effective command value](#effective-command-value); or if
there is some [formattable node](#formattable-node) [effectively
contained](#effectively-contained) in the [active range](#active-range)
with [effective command value](#effective-command-value) \"mixed\".
Otherwise false.

[Inline command activated values](#inline-command-activated-values):
\"superscript\"

### [The `underline`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

TODO: There are a lot of problems with underline color and thickness,
because text-decoration in CSS is horrible. These aren\'t prohibitive
for normal use and existing browsers don\'t handle them either, so
fixing these problems or working around them can be put off for now.

- Pushing down underlines can change their color, since the color of an
 underline follows the color of the element where it\'s declared
 instead of the text it\'s drawn under. This could be fixed by adding a
 special case for this condition and inserting extra color rules, such
 as by setting a color on the underlining element and then having
 another element inside it that resets the color. Horrible, but that\'s
 text-decoration for you. Alternatively, the new text-decoration-color
 property in the CSS 3 Text draft could come in handy here, in which
 case we\'d degrade pretty gracefully in legacy UAs.
- Underline thickness depends on font-size in all rendering engines but
 WebKit, so pushing them down creates thickness problems as well as
 color problems. Working around this is a similar story to the
 previous, except we have no text-decoration-width property yet (see
 [www-style
 post](https://lists.w3.org/Archives/Public/www-style/2011Mar/0593.html)).
- The preceding two points can\'t be avoided, because the only way to
 remove underlines in CSS is to push down styles (unlike most other
 things where you could override it). Recent (February 2011) CSS 3 Text
 drafts have added support for a \"text-decoration-line:
 cancel-underline\" property, but we can only use that if there\'s no
 other possibility, since it won\'t work in legacy browsers. (Although
 we should use it once there\'s no other possibility.)
- More generally, from a user\'s perspective, color and thickness of
 underlines is going to be more or less random if they\'re applying
 them to text with varying size or color. If they underline a bunch of
 text all at once, it will all get the same color/thickness, probably.
 But if they underline letter-by-letter, it probably will vary. But
 sometimes when they underline a bunch of text at once it will also
 vary, if the algorithm decides to create multiple elements for
 whatever reason (like an intervening unwrappable node). This is
 unlikely to match user expectations. There\'s not much we can do about
 this without entirely revamping text-decoration, so we\'ll have to
 live with it.
- Currently we don\'t treat non-underline text-decorations properly,
 because we have no way to set (or cancel) underlines independently of
 other text-decorations from within CSS. I\'ve sent
 [feedback](https://lists.w3.org/Archives/Public/www-style/2011Mar/0591.html)
 to www-style.

[Action](#action): If
[`queryCommandState("underline")`{title="queryCommandState()"}](#querycommandstate())
returns true, [set the selection\'s value](#set-the-selection's-value)
to null. Otherwise [set the selection\'s
value](#set-the-selection's-value) to \"underline\". Either way, return
true.

[Inline command activated values](#inline-command-activated-values):
\"underline\"

### [The `unlink`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

IE 9 RC unlinks the whole link you\'re pointing at, while others only
unlink the current text. The latter behavior seems less expected, as
with createLink, although I can\'t articulate precisely why. Word 2007
and OpenOffice.org 3.2.1 (Ubuntu) seem to give an option to remove the
whole link or none of it, which backs the spec\'s requirement. See also
#whatwg logs starting at 2011-05-13 at 16:53 EDT (UTC-0400).

See comment for [the `createLink`{title=""}
command](#the-createlink-command) about indeterm/state/value.

[Action](#action):

1. Let `hyperlinks` be a list of every \[\^a\^\]
 element that has an ` `[`href`](http://www.whatwg.org/specs/web-apps/current-work/multipage/links.html#attr-hyperlink-href)
 attribute and is
 [contained](http://dom.spec.whatwg.org/#contained) in the [active range](#active-range) or is an
 \[=tree/ancestor=\] of one of its \[=boundary points=\].
2. [Clear the value](#clear-the-value) of each member of
 `hyperlinks`.
3. Return true.

## Block formatting commands

### Block formatting command definitions

An [indentation element] is either a
\[\^blockquote\^\], or a \[\^div\^\] that has a ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
attribute that sets \"margin\" or some subproperty of it.

We need to allow stuff that sets border/padding because WebKit (Chrome
12 dev) sets \"border: none; padding: 0px\" when indenting. We need to
allow stuff that sets classes because WebKit sets
class=\"webkit-indent-blockquote\". We need to allow stuff that sets dir
because IE9 does. The criteria could probably be tightened up a bit to
reduce false positives, but it\'ll do for now.

A [simple indentation element] is an
[indentation element](#indentation-element) that has no attributes
except possibly

- a ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute that sets no properties other than \"margin\", \"border\",
 \"padding\", or subproperties of those; and/or
- a ` `[`dir`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-dir-attribute)
 attribute.

The notions of indentation element and simple indentation element
parallel those of [modifiable element](#modifiable-element) and [simple
modifiable element](#simple-modifiable-element).

listing and xmp are included because otherwise insertParagraph inside
them won\'t work, since paragraphs aren\'t an allowed child.

A [non-list single-line container]
is an [HTML element](#html-element) with \[=Element/local name=\]
\"address\", \"div\", \"h1\", \"h2\", \"h3\", \"h4\", \"h5\", \"h6\",
\"listing\", \"p\", \"pre\", or \"xmp\".

A [single-line container] is either a
[non-list single-line container](#non-list-single-line-container), or an
[HTML element](#html-element) with \[=Element/local name=\] \"li\",
\"dt\", or \"dd\".

The [block node of] a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node` is either a [block
node](#block-node) or null, as returned by the following algorithm:

1. While `node` is an [inline node](#inline-node),
 set `node` to its \[=tree/parent=\].
2. Return `node`.

[Bug 14062](https://www.w3.org/Bugs/Public/show_bug.cgi?id=14062). See
also [Mozilla bug
590640](https://bugzilla.mozilla.org/show_bug.cgi?id=590640),
specifically comments 48 and on.

If a [command](#command) [preserves overrides], then before taking its [action](#action), the user agent must
[record current overrides](#record-current-overrides). After taking the
[action](#action), if the [active range](#active-range) is
\[=range/collapsed=\], it must [restore states and
values](#restore-states-and-values) from the recorded list.

All block commands preserve overrides except [the `insertText`{title=""}
command](#the-inserttext-command), which treats overrides specially.

### Assorted block formatting command algorithms

TODO: When breaking a non-inline element out of an inline element, like
p in b or whatever, it would make sense to re-wrap the contents in the
inline tag.

To [fix disallowed ancestors] of
`node`:

We often run this algorithm after we move a node someplace, just in case
it wound up somewhere it\'s not supposed to be. This avoids things like
unserializable DOMs, blocks nested inside inlines, etc.

1. If `node` is not [editable](#editable), abort
 these steps.

2. This case is really intended to handle stuff like list items or
 table cells that wander outside their proper place. We generally
 convert them into \[\^p\^\]s.

 If `node` is not an [allowed
 child](#allowed-child) of any of its \[=tree/ancestors=\] [in the
 same editing host](#in-the-same-editing-host):

 1. If `node` is a \[\^dd\^\] or \[\^dt\^\],
 [wrap](#wrap) the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `node`, with `sibling criteria` returning
 true for any \[\^dl\^\] with no
 [attributes](http://dom.spec.whatwg.org/#concept-attribute "concept-attribute") and false otherwise, and
 `new parent instructions` returning the
 result of calling [`createElement("dl")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object). Then abort these steps.

 2. There\'s no reason to change the node to a paragraph if that
 won\'t make it an allowed child anyway.

 If \"p\" is not an [allowed child](#allowed-child) of the
 [editing host of](#editing-host-of) `node`,
 abort these steps.

 3. If `node` is not a [prohibited paragraph
 child](#prohibited-paragraph-child), abort these steps.

 4. [Set the tag name](#set-the-tag-name) of `node` to the [default single-line container
 name](#default-single-line-container-name), and let
 `node` be the result.

 5. Because maybe it somehow wound up as the child of a p, like via
 insertHTML.

 [Fix disallowed ancestors](#fix-disallowed-ancestors) of
 `node`.

 6. Let `children` be `node`\'s \[=tree/children=\].

 7. For each `child` in `children`, if `child` is a [prohibited
 paragraph child](#prohibited-paragraph-child):
 1. [Record the values](#record-the-values) of the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `child`, and let `values` be the
 result.
 2. [Split the parent](#split-the-parent) of the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `child`.
 3. [Restore the values](#restore-the-values) from
 `values`.

 8. Abort these steps.

3. [Record the values](#record-the-values) of the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `node`,
 and let `values` be the result.

4. While `node` is not an [allowed
 child](#allowed-child) of its \[=tree/parent=\], [split the
 parent](#split-the-parent) of the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `node`.

5. [Restore the values](#restore-the-values) from `values`.

This algorithm implies that we don\'t support a sublist in the middle of
an item, only at the end. For instance,

 <li>foo<ol>...</ol>bar</li>

gets transformed to

 <li>foo</li><ol>...</ol><li>bar</li>

which in particular creates an extra list marker for \"bar\". This is
okay; we don\'t need to expose all of HTML\'s markup abilities through
execCommand(). Similarly, the superscript and subscript commands don\'t
allow nesting. I didn\'t see any way to get a sublist in the middle of
an item in Word 2007 or in OpenOffice.org 3.2.1 Ubuntu package, nor in
any browser using just execCommand(), so it should be no big problem if
we require that such nesting not occur. (Existing browsers behave
weirdly and inconsistently when confronted with this kind of nesting.)

The reason we need this is that otherwise it gets very confusing to
figure out what happens in cases like trying to outdent

 <ol><li>[foo<ol><li>bar]</ol>baz</ol>

If we first normalize, then the natural answer is something like

 <p>[foo<ol><li>bar]<li>baz</ol>

but if we don\'t, we\'d have to special-case in the toggle lists and
outdent algorithms. This might be worthwhile, but it\'s not at all
clear, and what I have works okay, so I\'ll stick with it for now.

TODO: Investigate fixing this.

To [normalize sublists] in a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `item`:

1. If `item` is not an \[\^li\^\] or it is not
 [editable](#editable) or its \[=tree/parent=\] is not
 [editable](#editable), abort these steps.
2. Let `new item` be null.
3. While `item` has an \[\^ol\^\] or \[\^ul\^\]
 \[=tree/child=\]:
 1. Let `child` be the last \[=tree/child=\] of
 `item`.
 2. If `child` is an \[\^ol\^\] or \[\^ul\^\],
 or `new item` is null and `child` is a {{Text}} node whose {{CharacterData/ data}}
 consists of zero of more [space
 characters](http://encoding.spec.whatwg.org/#ascii-whitespace "ascii whitespace"):
 1. Set `new item` to null.
 2. Insert `child` into the
 \[=tree/parent=\] of `item` immediately
 following `item`, [preserving
 ranges](#preserving-ranges).
 3. Otherwise:
 1. If `new item` is null, let
 `new item` be the result of calling
 [`createElement("li")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ ownerDocument}} of `item`, then insert `new item` into
 the \[=tree/parent=\] of `item`
 immediately after `item`.
 2. Insert `child` into `new item` as its first \[=tree/child=\], [preserving
 ranges](#preserving-ranges).

The [selection\'s list state] is returned
by the following algorithm:

This is just a helper to tell the state and indeterminacy of [the
`insertOrderedList`{title=""} command](#the-insertorderedlist-command)
and [the `insertUnorderedList`{title=""}
command](#the-insertunorderedlist-command):

 ol indeterm ol state ul indeterm ul state
 ---------- ------------- ---------- ------------- ----------
 ol false true false false
 ul false false false true
 mixed true false true false
 mixed ol true false false false
 mixed ul false false true false
 none false false false false

1. If the [active range](#active-range) is null, return \"none\".

2. [Block-extend](#block-extend) the [active range](#active-range), and
 let `new range` be the result.

3. Let `node list` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.

4. For each `node`
 [contained](http://dom.spec.whatwg.org/#contained) in `new range`, append
 `node` to `node list` if the
 last member of `node list` (if any) is not an
 \[=tree/ancestor=\] of `node`; `node` is [editable](#editable); `node` is
 not an [indentation element](#indentation-element); and
 `node` is either an \[\^ol\^\] or \[\^ul\^\], or
 the \[=tree/child=\] of an \[\^ol\^\] or \[\^ul\^\], or an [allowed
 child](#allowed-child) of \"li\".

5. If `node list` is empty, return \"none\".

6. ::: note
 The child-of-child case is necessary right now because of the
 following:

 <ol><li>[foo<ol><li>bar]</ol>baz</ol>

 With the current (July 2011) block-extend algorithm, this will
 become:

 {<ol><li>foo<ol><li>bar</ol>}baz</ol>

 because of the magical li handling in block-extend. We want this to
 register as ol, because after normalizing sublists it will become

 {<ol><li>foo</li><ol><li>bar</ol>}<li>baz</ol>

 But the text node \"foo\" will wind up in node list, and is not the
 child of an ol. This is all very messy and has to do with
 questionable decisions about how to handle nested lists.
 :::

 If every member of `node list` is either an
 \[\^ol\^\] or the \[=tree/child=\] of an \[\^ol\^\] or the
 \[=tree/child=\] of an \[\^li\^\] \[=tree/child=\] of an \[\^ol\^\],
 and none is a \[\^ul\^\] or an \[=tree/ancestor=\] of a \[\^ul\^\],
 return \"ol\".

7. This condition and the last are mutually exclusive, so the order is
 actually irrelevant. Clearly they could only both hold if no member
 of node list is an ol or ul, so if they both held, every member
 would have to be either the child of an ol and of a ul, or of an ol
 and an li, or a ul and an li, or of an li that\'s the child of both
 an ol and a ul. This is impossible unless the list is empty, in
 which case we already aborted.

 If every member of `node list` is either a
 \[\^ul\^\] or the \[=tree/child=\] of a \[\^ul\^\] or the
 \[=tree/child=\] of an \[\^li\^\] \[=tree/child=\] of a \[\^ul\^\],
 and none is an \[\^ol\^\] or an \[=tree/ancestor=\] of an
 \[\^ol\^\], return \"ul\".

8. If some member of `node list` is either an
 \[\^ol\^\] or the \[=tree/child=\] or \[=tree/ancestor=\] of an
 \[\^ol\^\] or the \[=tree/child=\] of an \[\^li\^\] \[=tree/child=\]
 of an \[\^ol\^\], and some member of `node list`
 is either a \[\^ul\^\] or the \[=tree/child=\] or
 \[=tree/ancestor=\] of a \[\^ul\^\] or the \[=tree/child=\] of an
 \[\^li\^\] \[=tree/child=\] of a \[\^ul\^\], return \"mixed\".

9. If some member of `node list` is either an
 \[\^ol\^\] or the \[=tree/child=\] or \[=tree/ancestor=\] of an
 \[\^ol\^\] or the \[=tree/child=\] of an \[\^li\^\] \[=tree/child=\]
 of an \[\^ol\^\], return \"mixed ol\".

10. If some member of `node list` is either a
 \[\^ul\^\] or the \[=tree/child=\] or \[=tree/ancestor=\] of a
 \[\^ul\^\] or the \[=tree/child=\] of an \[\^li\^\] \[=tree/child=\]
 of a \[\^ul\^\], return \"mixed ul\".

11. Return \"none\".

When querying the value of justify\*, IE9 seems to return boolean false
across the board when it doesn\'t throw exceptions, which it usually
does in my tests. Chrome 14 dev returns the string \"true\" or \"false\"
depending on state, as in other cases, which is useless. Opera 11.11
returns \"\" across the board. Firefox 6.0a2 behaves like with other
command values: it returns \"center\"/\"justify\"/\"left\"/\"right\"
depending on the active range\'s start node. Since this is the only
behavior that\'s possibly useful, it\'s what I specced. Firefox ties the
value closely to the state, returning true for the state if and only if
the value matches the desired value, but this seems less useful than
what I\'ve specced for the state.

This API is based on the four-state text-align of CSS 2.1. We do some
crude mapping to make it not break too badly with CSS3 values, but it\'s
not going to work well given the design of the API.

The [alignment value] of a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node` is returned by the
following algorithm:

This is basically like the resolved value of text-align, but with two
key differences. First, it only ever evaluates to
center/justify/left/right, since that\'s the model that the justify
commands work with. Second, it ignores inline elements, because
text-align has no effect on them and their alignment is actually
governed by their nearest block ancestor (if any).

1. While `node` is neither null nor an {{Element}},
 or it is an {{Element}} but its \"display\" property has [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) \"inline\" or
 \"none\", set `node` to its \[=tree/parent=\].

2. This means there\'s no applicable style rule, so probably it will
 wind up left-aligned. Of course this ignores the fact that the
 alignment will really be \"start\", so this is wrong for RTL, but
 it\'s a pretty marginal corner case anyway. (It will only happen if,
 e.g., everything up to and including the html and body elements have
 display: inline or none.)

 If `node` is not an {{Element}}, return
 \"left\".

3. If `node`\'s \"text-align\" property has
 [resolved value](http://dev.w3.org/csswg/cssom/#resolved-value)
 \"start\", return \"left\" if the
 [directionality](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-directionality "the directionality") of `node` is \"ltr\",
 \"right\" if it is \"rtl\".

4. If `node`\'s \"text-align\" property has
 [resolved value](http://dev.w3.org/csswg/cssom/#resolved-value)
 \"end\", return \"right\" if the
 [directionality](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-directionality "the directionality") of `node` is \"ltr\",
 \"left\" if it is \"rtl\".

5. If `node`\'s \"text-align\" property has
 [resolved value](http://dev.w3.org/csswg/cssom/#resolved-value)
 \"center\", \"justify\", \"left\", or \"right\", return that value.

6. Return \"left\".

Sometimes one location corresponds to multiple distinct boundary points.
For instance, in the DOM `<p>Hello</p>`{title=""}, a boundary point
might lie at the beginning of the text node or the beginning of the
element node, but these don\'t logically differ much and will appear the
same to the user, so we often want to treat them the same. The
algorithms here allow navigating through such equivalent boundary
points, for when we want to make the selection as inclusive or exclusive
as possible. For deletion, we want to delete as few nodes as possible,
so we move the start node forward and the end node backward. In other
cases we might do the reverse, expanding the selection. In still other
cases we might want to move forward or backward to try getting to a text
node.

Given a \[=boundary point=\] (`node`,
`offset`), the [next equivalent
point] is either a \[=boundary point=\] or
null, as returned by the following algorithm:

1. If `node`\'s \[=Node/length=\] is zero, return
 null.
2. We don\'t want to move into or out of zero-length nodes, because
 that would move us straight through them. For instance, if
 `<span></span>`{title=""} were equivalent to
 `<span></span>`{title=""}, it would also be equivalent to
 `<span></span>`{title=""}. This produces very unexpected results
 for nodes like `<br>`{title=""}.
3. If `offset` is `node`\'s
 \[=Node/length=\], and `node`\'s
 \[=tree/parent=\] is not null, and `node` is an
 [inline node](#inline-node), return (`node`\'s
 \[=tree/parent=\], 1 + `node`\'s
 \[=tree/index=\]).
4. For instance, `<span>foo</span>`{title=""} is equivalent to
 `<span>foo</span>`{title=""}, which is equivalent to
 `<span>foo</span>`{title=""}. However, `<p>foo</p>`{title=""} is
 *not* equivalent to `<p>foo</p>`{title=""} -- the cursor might
 look like it\'s in a visibly different position.
5. If `node` has a \[=tree/child=\] with
 \[=tree/index=\] `offset`, and that
 \[=tree/child=\]\'s \[=Node/length=\] is not zero, and that
 \[=tree/child=\] is an [inline node](#inline-node), return (that
 \[=tree/child=\], 0).
6. For instance, `<span>foo</span>`{title=""} is equivalent to
 `<span>foo</span>`{title=""}, which is equivalent to
 `<span>foo</span>`{title=""}. As noted before, though, we don\'t
 descend into empty nodes. And again, `<p>foo</p>`{title=""} is
 different from `<p>foo</p>`{title=""}.
7. Return null.

Given a \[=boundary point=\] (`node`,
`offset`), the [previous equivalent
point] is either a \[=boundary point=\]
or null, as returned by the following algorithm:

1. If `node`\'s \[=Node/length=\] is zero, return
 null.
2. If `offset` is 0, and `node`\'s \[=tree/parent=\] is not null, and `node` is an [inline node](#inline-node), return
 (`node`\'s \[=tree/parent=\], `node`\'s \[=tree/index=\]).
3. If `node` has a \[=tree/child=\] with
 \[=tree/index=\] `offset` − 1, and that
 \[=tree/child=\]\'s \[=Node/length=\] is not zero, and that
 \[=tree/child=\] is an [inline node](#inline-node), return (that
 \[=tree/child=\], that \[=tree/child=\]\'s \[=Node/length=\]).
4. Return null.

The [first equivalent point] of a
\[=boundary point=\] (`node`, `offset`) is returned by the following algorithm:

1. While (`node`, `offset`)\'s
 [previous equivalent point](#previous-equivalent-point) is not null,
 set (`node`, `offset`) to
 its [previous equivalent point](#previous-equivalent-point).
2. Return (`node`, `offset`).

The [last equivalent point] of a
\[=boundary point=\] (`node`, `offset`) is returned by the following algorithm:

1. While (`node`, `offset`)\'s
 [next equivalent point](#next-equivalent-point) is not null, set
 (`node`, `offset`) to its
 [next equivalent point](#next-equivalent-point).
2. Return (`node`, `offset`).

### Block-extending a range

A \[=boundary point=\] (`node`, `offset`) is a [block start point] if either
`node`\'s \[=tree/parent=\] is null and
`offset` is zero; or `node` has
a \[=tree/child=\] with \[=tree/index=\] `offset` −
1, and that \[=tree/child=\] is either a [visible](#visible) [block
node](#block-node) or a [visible](#visible) \[\^br\^\].

A \[=boundary point=\] (`node`, `offset`) is a [block end point] if either
`node`\'s \[=tree/parent=\] is null and
`offset` is `node`\'s
\[=Node/length=\]; or `node` has a \[=tree/child=\]
with \[=tree/index=\] `offset`, and that
\[=tree/child=\] is a [visible](#visible) [block node](#block-node).

A \[=boundary point=\] is a [block boundary point] if it is either a [block start point](#block-start-point) or a
[block end point](#block-end-point).

When a user agent is to [block-extend] a \[=range=\]
`range`, it must run the following steps:

Generally, block commands work on any block that contains part of the
selection, even if the selection doesn\'t include the whole block. This
algorithm takes an input range, copies it, stretches out the copy to
contain entire blocks, and returns the result. Then the caller will
normally use it instead of the range it started with. For instance, if
the cursor is collapsed in a text node inside a paragraph, this will
generally return a range that includes the whole paragraph.

Two bits of magic worth noting. First, `<br>`{title=""} counts as a
block delimiter here, since it looks the same as a block boundary
(assuming no margin etc.) and this is a visual API. We include the
`<br>`{title=""} as part of the line that precedes it. Second, if the
selection is inside an `<li>`{title=""}, this will extend it to include
the whole `<li>`{title=""}. This latter point is weird, and I should
re-examine it sometime, but it seems to work.

1. Let `start node`, `start offset`, `end node`, and
 `end offset` be the \[=range/start=\] and
 \[=range/end=\]
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") and \[=boundary point/offsets=\] of
 `range`.

2. If some \[=tree/inclusive ancestor=\] of `start node` is an \[\^li\^\], set `start offset`
 to the \[=tree/index=\] of the last such \[\^li\^\] in \[=tree
 order=\], and set `start node` to that
 \[\^li\^\]\'s \[=tree/parent=\].

3. If (`start node`, `start offset`) is not a [block start point](#block-start-point), repeat
 the following steps:
 1. If `start offset` is zero, set it to
 `start node`\'s \[=tree/index=\], then set
 `start node` to its \[=tree/parent=\].
 2. Otherwise, subtract one from `start offset`.
 3. If (`start node`, `start offset`) is a [block boundary point](#block-boundary-point),
 break from this loop.

4. This just changes something like `<div>{<p>foo]</p></div>`{title=""}
 to `{<div><p>foo]</p></div>`{title=""}.

 While `start offset` is zero and
 `start node`\'s \[=tree/parent=\] is not null,
 set `start offset` to `start node`\'s \[=tree/index=\], then set `start node` to its \[=tree/parent=\].

5. If some \[=tree/inclusive ancestor=\] of `end node` is an \[\^li\^\], set `end offset` to
 one plus the \[=tree/index=\] of the last such \[\^li\^\] in \[=tree
 order=\], and set `end node` to that
 \[\^li\^\]\'s \[=tree/parent=\].

6. If (`end node`, `end offset`) is not a [block end point](#block-end-point), repeat the
 following steps:
 1. If `end offset` is `end node`\'s \[=Node/length=\], set it to one plus
 `end node`\'s \[=tree/index=\], then set
 `end node` to its \[=tree/parent=\].
 2. Otherwise, add one to `end offset`.
 3. If (`end node`, `end offset`) is a [block boundary point](#block-boundary-point),
 break from this loop.

7. While `end offset` is `end node`\'s \[=Node/length=\] and `end node`\'s
 \[=tree/parent=\] is not null, set `end offset`
 to one plus `end node`\'s \[=tree/index=\], then
 set `end node` to its \[=tree/parent=\].

8. Let `new range` be a new \[=range=\] whose
 \[=range/start=\] and \[=range/end=\]
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") and \[=boundary point/offsets=\] are
 `start node`, `start offset`, `end node`, and
 `end offset`.

9. Return `new range`.

A
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node` [follows a line
break] if the following algorithm returns
true:

1. Let `offset` be zero.
2. While (`node`, `offset`) is
 not a [block boundary point](#block-boundary-point):
 1. If `node` has a [visible](#visible)
 \[=tree/child=\] with \[=tree/index=\] `offset` minus one, return false.
 2. If `offset` is zero or `node` has no \[=tree/children=\], set `offset` to `node`\'s \[=tree/index=\],
 then set `node` to its \[=tree/parent=\].
 3. Otherwise, set `node` to its
 \[=tree/child=\] with \[=tree/index=\] `offset` minus one, then set `offset` to
 `node`\'s \[=Node/length=\].
3. Return true.

A
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node` [precedes a line
break] if the following algorithm returns
true:

1. Let `offset` be `node`\'s
 \[=Node/length=\].
2. While (`node`, `offset`) is
 not a [block boundary point](#block-boundary-point):
 1. If `node` has a [visible](#visible)
 \[=tree/child=\] with \[=tree/index=\] `offset`, return false.
 2. If `offset` is `node`\'s
 \[=Node/length=\] or `node` has no
 \[=tree/children=\], set `offset` to one
 plus `node`\'s \[=tree/index=\], then set
 `node` to its \[=tree/parent=\].
 3. Otherwise, set `node` to its
 \[=tree/child=\] with \[=tree/index=\] `offset` and set `offset` to zero.
3. Return true.

### Recording and restoring overrides

To [record current overrides]:

1. Let `overrides` be a list of (string, string or
 boolean) ordered pairs, initially empty.

2. ::: note
 When restoring, some commands can interfere with others.
 Specifically, we want to restore createLink before foreColor and
 underline, and subscript and superscript before fontSize. TODO: This
 approach only works for default styles (although I\'m not sure
 offhand how we could handle non-default styles in principle).

 Firefox 7.0a2 and Opera 11.50 don\'t honor createLink with collapsed
 selections. If you insert text, it\'s not linked. The spec follows
 Chrome 14 dev. IE9 also ignores createLink with collapsed
 selections, but its behavior in other cases for collapsed selections
 is totally different from all other browsers, so it\'s not a fair
 comparison.
 :::

 If there is a [value override](#value-override) for \"createLink\",
 add (\"createLink\", [value override](#value-override) for
 \"createLink\") to `overrides`.

3. Firefox 7.0a2 and Opera 11.50 will honor repeated
 subscript/superscript commands on a collapsed selection, allowing
 you to nest them. The spec follows the general philosophy that we
 don\'t allow users to nest subscript/superscript, so the last one
 wins. Chrome 14 dev is similar to the spec.

 For each `command` in the list \"bold\",
 \"italic\", \"strikethrough\", \"subscript\", \"superscript\",
 \"underline\", in order: if there is a [state
 override](#state-override) for `command`, add
 (`command`, `command`\'s
 [state override](#state-override)) to `overrides`.

4. For each `command` in the list \"fontName\",
 \"fontSize\", \"foreColor\", \"hiliteColor\", in order: if there is
 a [value override](#value-override) for `command`, add (`command`, `command`\'s [value override](#value-override)) to
 `overrides`.

5. Return `overrides`.

To [record current states and values]:

1. Let `overrides` be a list of (string, string or
 boolean) ordered pairs, initially empty.

2. Let `node` be the first [formattable
 node](#formattable-node) [effectively
 contained](#effectively-contained) in the [active
 range](#active-range), or null if there is none.

3. If `node` is null, return `overrides`.

4. Add (\"createLink\", `node`\'s [effective
 command value](#effective-command-value) for \"createLink\") to
 `overrides`.

5. Thus we will set state overrides based on the first formattable
 node, to match values. This means that if you have
 `<p>foo<b>[bar</b>baz]</p>`{title=""} and hit backspace and hit A,
 you\'ll get `<p>foo<b>a</b></p>`{title=""}, although bold was
 previously indeterminate. This is needed to match the behavior of
 hitting A straight away, since innerText doesn\'t strip wrappers
 when it invokes \"delete the contents\".

 For each `command` in the list \"bold\",
 \"italic\", \"strikethrough\", \"subscript\", \"superscript\",
 \"underline\", in order: if `node`\'s [effective
 command value](#effective-command-value) for `command` is one of its [inline command activated
 values](#inline-command-activated-values), add (`command`, true) to `overrides`, and otherwise
 add (`command`, false) to `overrides`.

6. For each `command` in the list \"fontName\",
 \"foreColor\", \"hiliteColor\", in order: add (`command`, `command`\'s [value](#value)) to
 `overrides`.

7. Special case for fontSize, because its values are weird.

 Add (\"fontSize\", `node`\'s [effective command
 value](#effective-command-value) for \"fontSize\") to
 `overrides`.

 This is wrong: it will convert non-pixel sizes to pixel sizes. But I
 don\'t see any way to avoid it. Hopefully it won\'t come up too
 often. font-size is a real problem, because the mapping from
 specified value to computed value is lossy and not fully defined
 (e.g., how many px is \"small\"?).

8. Return `overrides`.

To [restore states and values]
specified by a list `overrides` returned by the
[record current overrides](#record-current-overrides) or [record current
states and values](#record-current-states-and-values) algorithm:

1. Let `node` be the first [formattable
 node](#formattable-node) [effectively
 contained](#effectively-contained) in the [active
 range](#active-range), or null if there is none.
2. If `node` is not null, then for each
 (`command`, `override`) pair
 in `overrides`, in order:
 1. If `override` is a boolean, and
 [`queryCommandState(`{title="queryCommandState()"}`command``)`{title="queryCommandState()"}](#querycommandstate())
 returns something different from `override`,
 take the [action](#action) for `command`,
 with `value` equal to the empty string.

 2. Otherwise, if `override` is a string, and
 `command` is neither \"createLink\" nor
 \"fontSize\", and
 [`queryCommandValue(`{title="queryCommandValue()"}`command``)`{title="queryCommandValue()"}](#querycommandvalue())
 returns something not
 [equivalent](#equivalent-values "equivalent values") to
 `override`, take the [action](#action) for
 `command`, with `value`
 equal to `override`.

 3. This special case is needed because [createLink has no
 value](https://www.w3.org/Bugs/Public/show_bug.cgi?id=14067).

 Otherwise, if `override` is a string; and
 `command` is \"createLink\"; and either
 there is a [value override](#value-override) for \"createLink\"
 that is not equal to `override`, or there is
 no [value override](#value-override) for \"createLink\" and
 `node`\'s [effective command
 value](#effective-command-value) for \"createLink\" is not equal
 to `override`: take the `action` for \"createLink\", with `value`
 equal to `override`.

 4. The override will be some CSS value, so we have to convert it to
 a legacy font size.

 Otherwise, if `override` is a string; and
 `command` is \"fontSize\"; and either there
 is a [value override](#value-override) for \"fontSize\" that is
 not equal to `override`, or there is no
 [value override](#value-override) for \"fontSize\" and
 `node`\'s [effective command
 value](#effective-command-value) for \"fontSize\" is not
 [loosely
 equivalent](#loosely-equivalent-values "loosely equivalent values")
 to `override`:

 1. Convert `override` to an integer number
 of pixels, and set `override` to the
 [legacy font size for](#legacy-font-size-for) the result.
 2. Take the [action](#action) for \"fontSize\", with
 `value` equal to `override`.

 5. Otherwise, continue this loop from the beginning.

 6. If we took the action for a command, we need to reset
 `node`, because it might have changed. For
 instance, if the selection was `foo[bar]baz`{title=""}, the text
 node could have been split so that the first part is now outside
 the active range.

 Set `node` to the first [formattable
 node](#formattable-node) [effectively
 contained](#effectively-contained) in the [active
 range](#active-range), if there is one.
3. Otherwise, for each (`command`,
 ` override`) pair in `overrides`, in order:
 1. If `override` is a boolean, set the [state
 override](#state-override) for `command` to
 `override`.
 2. If `override` is a string, set the [value
 override](#value-override) for `command` to
 `override`.

### Deleting the selection

TODO: Consider what should happen for block merging in corner cases like
display: inline-table.

To [delete the selection], given a
`block merging` flag that defaults to true, a
`strip wrappers` flag that defaults to true, and a
string `direction` that defaults to \"forward\":

The idea behind this algorithm is self-explanatory, but the details wind
up being remarkably complicated.

First, any editable nodes inside the selection will be deleted, and the
selection will be collapsed. By way of contrast, [effectively
contained](#effectively-contained) tries to expand the range to include
as much as possible, so `<p>[foo]</p>`{title=""} contains the
`<p>`{title=""}. What we do here is contract the range to include as
little as possible, so `{<p>foo</p>}`{title=""} contains only
`foo`{title=""} and doesn\'t delete the paragraph.

After that, if the selection originally started and ended in different
blocks, and the `block merging` flag is true, the
end block will get merged into the start block. This is needed so if the
user selects text on several lines and deletes it, the text immediately
that was before the selection winds up on the same line as the text
immediately after it. For example,
`<p>fo[o</p><div>b]ar</div>`{title=""} becomes
`<p>foar</p>`{title=""}. This procedure winds up being tricky, and
takes up a large chunk of the logic.

Tables are a notable special case. If an entire table is contained in
the range, it will be deleted. If it\'s anything less, only the contents
of the cells will be deleted and the table structure will be left
intact.

The `strip wrappers` flag controls what happens if
the deletion removes all the contents of an inline element. If wrappers
are being stripped, the empty inline element will be removed: this is
usually what you want, because the user can\'t position the selection
inside it. But callers like [the `insertText`{title=""}
command](#the-inserttext-command) that intend to immediately insert new
contents want to leave the wrappers, so the new contents are wrapped by
the same thing as the old.

Even if `strip wrappers` is true, the algorithm will
set a [state override](#state-override) and [value
override](#value-override) for any styles it winds up removing. This
way, if the user deletes a wrapper that adds a style (or link for that
matter), then types something, the new text will get the style from the
old text.

1. If the [active range](#active-range) is null, abort these steps and
 do nothing.

2. [Canonicalize whitespace](#canonicalize-whitespace) at the [active
 range](#active-range)\'s \[=range/start=\].

3. [Canonicalize whitespace](#canonicalize-whitespace) at the [active
 range](#active-range)\'s \[=range/end=\].

4. Let (`start node`, `start offset`) be the [last equivalent point](#last-equivalent-point)
 for the [active range](#active-range)\'s \[=range/start=\].

5. Let (`end node`, `end offset`) be the [first equivalent point](#first-equivalent-point)
 for the [active range](#active-range)\'s \[=range/end=\].

6. If (`end node`, `end offset`) is not \[=boundary point/after=\] (`start node`, `start offset`):

 This is a selection like
 `<span>foo[</span></span>]bar</span>`{title=""}, where the boundary
 points are equivalent but not identical. We just collapse it and
 abort, since there\'s nothing to delete.

 1. If `direction` is \"forward\", call
 [`collapseToStart()`{title="dom-Selection-collapseToStart"}](#dom-selection-collapsetostart)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 2. Otherwise, call
 [`collapseToEnd()`{title="dom-Selection-collapseToEnd"}](#dom-selection-collapsetoend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 3. Abort these steps.

7. If `start node` is a {{Text}} node and
 `start offset` is 0, set
 `start offset` to the \[=tree/index=\] of
 `start node`, then set `start node` to its \[=tree/parent=\].

8. If `end node` is a {{Text}} node and
 `end offset` is its \[=Node/length=\], set
 `end offset` to one plus the \[=tree/index=\] of
 `end node`, then set `end node` to its \[=tree/parent=\].

 The previous two steps are so that we won\'t leave empty text nodes
 anywhere.

9. Call
 [`collapse(`{title="dom-Selection-collapse"}`start node``, `{title="dom-Selection-collapse"}`start offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

10. Call [`extend(`{title="dom-Selection-extend"}`end node``, `{title="dom-Selection-extend"}`end offset``)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

11. When we delete a selection that spans multiple blocks, we merge the
 end block\'s contents into the start block, like

 <p>fo[o</p><pre>b]ar</pre>
 -> <p>foar</p>.

 We figure out what the start and end blocks are before we start
 deleting anything.

12. Let `start block` be the [active
 range](#active-range)\'s \[=range/start node=\].

13. While `start block`\'s \[=tree/parent=\] is [in
 the same editing host](#in-the-same-editing-host) and
 `start block` is an [inline node](#inline-node),
 set `start block` to its \[=tree/parent=\].

14. ::: note
 We only merge to or from block nodes or editing hosts. (This is just
 in case someone makes a span into an editing host and sticks
 paragraphs inside it or something . . . we could probably drop that
 proviso.) Firefox 7.0a2 ignores the display property when merging,
 so it doesn\'t merge `<span style=display:block>`{title=""} but does
 merge `<p style=display:inline>`{title=""}. This is undesirable,
 because it\'s visually wrong. IE10PP2 and Chrome 14 dev behave more
 like the spec, and Opera 11.50 seems to be unable to make up its
 mind.

 If span isn\'t an allowed child, it\'s probably something unpleasant
 like a table row or a list or such. We don\'t want to merge to or
 from something like that, because we\'d most likely wind up with the
 wrong type of child somewhere. It should be pretty hard for this to
 happen given the normalization we do on the selection; I\'m not
 actually sure how it could happen at all, actually, unless you start
 out with a DOM that has non-allowed children someplace. So it\'s
 basically a sanity check.

 We don\'t let either start block or end block be a td or th. This
 means we\'ll never merge to or from a td or th. This matches Firefox
 5.0a2, and reportedly Word as well. Chrome 13 dev and Opera 11.11
 allow merging from a non-table cell end block to a table cell start
 block, but not vice versa. In IE9 the delete key just does nothing.
 :::

 If `start block` is neither a [block
 node](#block-node) nor an \[=editing host=\], or \"span\" is not an
 [allowed child](#allowed-child) of `start block`, or `start block` is a \[\^td\^\] or
 \[\^th\^\], set `start block` to null.

15. Let `end block` be the [active
 range](#active-range)\'s \[=range/end node=\].

16. While `end block`\'s \[=tree/parent=\] is [in
 the same editing host](#in-the-same-editing-host) and
 `end block` is an [inline node](#inline-node),
 set `end block` to its \[=tree/parent=\].

17. If `end block` is neither a [block
 node](#block-node) nor an \[=editing host=\], or \"span\" is not an
 [allowed child](#allowed-child) of `end block`,
 or `end block` is a \[\^td\^\] or \[\^th\^\],
 set `end block` to null.

18. Later on we\'ll restore `overrides`. This
 ensures that if we delete inline formatting elements and the user
 then types something, the typed text will have the same style as
 before.

19. ::: note
 As far as I can tell, IE9 and Opera 11.50 don\'t do this at all. If
 you delete a selection and then start typing, the new text doesn\'t
 take on the styles of the old text.

 Firefox 7.0a2 seems to do it for some styles but not others.
 Strikethrough, superscript, subscript, and links seem to be lost, at
 a minimum.

 The spec goes with something like Chrome 14 dev, which tries to
 preserve lots of stuff.
 :::

 [Record current states and
 values](#record-current-states-and-values), and let
 `overrides` be the result.

20. Now we actually begin deleting things.

21. This whole piece of the algorithm is based on deleteContents() in
 DOM Range, copy-pasted and then adjusted to fit.

 If `start node` and `end node` are the same, and `start node` is an
 [editable](#editable) {{Text}} node:

 1. Call [`deleteData(``start offset``, ``end offset`` − ``start offset``)`](http://dom.spec.whatwg.org/#dom-characterdata-deletedata)
 on `start node`.

 2. [Canonicalize whitespace](#canonicalize-whitespace) at
 (`start node`, `start offset`), with `fix collapsed space`
 false.

 3. If `direction` is \"forward\", call
 [`collapseToStart()`{title="dom-Selection-collapseToStart"}](#dom-selection-collapsetostart)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

 4. Otherwise, call
 [`collapseToEnd()`{title="dom-Selection-collapseToEnd"}](#dom-selection-collapsetoend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

 5. This is needed to restore any overrides that would otherwise be
 lost. TODO: In this and similar cases, we could optimize by
 saving only overrides, not the full state/value.

 [Restore states and values](#restore-states-and-values) from
 `overrides`.

 6. Abort these steps.

22. If `start node` is an [editable](#editable)
 {{Text}} node, call ` `[`deleteData()`](http://dom.spec.whatwg.org/#dom-characterdata-deletedata)
 on it, with `start offset` as the first argument
 and (\[=Node/length=\] of `start node` −
 `start offset`) as the second argument.

23. Let `node list` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.

24. IE9 doesn\'t seem to let you do any intercell deletions: the delete
 key does nothing if you select across multiple cells. Firefox 5.0a2
 and Opera 11.11 behave as the spec says, not removing any table
 things. Chrome 13 dev will remove entire rows if selected. Note that
 IE, Firefox, Word 2007, and OpenOffice.org 3.2.1 Ubuntu all switch
 to a magic cell-selection mode when you try to select between cells,
 at least in some cases, instead of selecting letter-by-letter.

 For each `node`
 [contained](http://dom.spec.whatwg.org/#contained) in the [active range](#active-range), append
 `node` to `node list` if the
 last member of `node list` (if any) is not an
 \[=tree/ancestor=\] of `node`; `node` is [editable](#editable); and `node`
 is not a \[\^thead\^\], \[\^tbody\^\], \[\^tfoot\^\], \[\^tr\^\],
 \[\^th\^\], or \[\^td\^\].

25. For each `node` in `node list`:
 1. Let `parent` be the \[=tree/parent=\] of
 `node`.

 2. Remove `node` from `parent`.

 3. Do this before stripping wrappers: see [bug
 13831](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13831).

 If the [block node of](#block-node-of) `parent` has no [visible](#visible) \[=tree/children=\], and
 `parent` is [editable](#editable) or an
 \[=editing host=\], call [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and append the result as the last
 \[=tree/child=\] of `parent`.

 4. Taking insertText to test the case where strip wrappers is
 false, with value a: `<p>[foo<b>bar</b>]baz`{title=""} becomes
 `<p>abaz`{title=""} per spec, in IE9, and in Chrome 14 dev.
 Firefox 7.0a2 and Opera 11.50 make it
 `<p>a<b></b>baz`{title=""}, with a useless wrapper.
 `<p>foo<b>[bar</b>baz]`{title=""} becomes
 `<p>foo<b>a</b>`{title=""} per spec and in IE9 and Firefox
 7.0a2 and Opera 11.50; in Chrome 14 dev apparently it initially
 becomes `<p>fooa`{title=""}, but then the style is recreated.
 This is detectable if you do something weird like
 `<span style=color:#aBcDeF>`{title=""} instead of
 `<b>`{title=""}: it comes
 `<font class=Apple-style-span color=#abcdef>`{title=""} or such.
 I follow IE9 in all cases, because it makes the most sense.

 If `strip wrappers` is true or
 `parent` is not an \[=tree/inclusive
 ancestor=\] of `start node`, while
 `parent` is an [editable](#editable) [inline
 node](#inline-node) with \[=Node/length=\] 0, let
 `grandparent` be the \[=tree/parent=\] of
 `parent`, then remove `parent` from `grandparent`, then set
 `parent` to `grandparent`.

 Even if `strip wrappers` is false, we still
 want to strip wrappers that aren\'t \[=tree/inclusive
 ancestors=\] of `start node`. The idea of
 not stripping wrappers is that we\'re going to insert new
 content right afterward, like text or an image, but that new
 content will be inserted at the start node. Wrappers in other
 places still need to be removed, because they would otherwise
 remain empty.

26. If `end node` is an [editable](#editable)
 {{Text}} node, call ` `[`deleteData(0, ``end offset``)`](http://dom.spec.whatwg.org/#dom-characterdata-deletedata)
 on it.

27. [Canonicalize whitespace](#canonicalize-whitespace) at the [active
 range](#active-range)\'s \[=range/start=\], with
 `fix collapsed space` false.

28. [Canonicalize whitespace](#canonicalize-whitespace) at the [active
 range](#active-range)\'s \[=range/end=\], with
 `fix collapsed space` false.

29. Now we need to merge blocks. The simplest case is something like

 <p>fo[o</p><p>bar</p><p>b]az</p>
 -> <p>fo</p><p>az</p>
 -> <p>foaz</p>

 where neither block descends from the other. More complicated is
 something like

 foo[<p>]bar</p>
 -> foobar

 or

 <p>foo[</p>]bar
 -> <p>foobar</p>

 where one descends from the other.

30. If `block merging` is false, or
 ` start block` or `end block` is null, or `start block` is not [in
 the same editing host](#in-the-same-editing-host) as
 `end block`, or `start block` and `end block` are the same:
 1. If `direction` is \"forward\", call
 [`collapseToStart()`{title="dom-Selection-collapseToStart"}](#dom-selection-collapsetostart)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 2. Otherwise, call
 [`collapseToEnd()`{title="dom-Selection-collapseToEnd"}](#dom-selection-collapsetoend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 3. [Restore states and values](#restore-states-and-values) from
 `overrides`.
 4. Abort these steps.

31. We might have added a br to the start/end block in an earlier step.
 Now we\'re about to merge the blocks, and we don\'t want the br\'s
 to get in the way. The end block is being destroyed no matter what.
 If the start block winds up empty after merging, we\'ll add a new br
 child at the end so it doesn\'t collapse.

 If `start block` has one \[=tree/child=\], which
 is a [collapsed block prop](#collapsed-block-prop), remove its
 \[=tree/child=\] from it.

32. Just repeatedly blow up the end block in this case.

 If `start block` is an \[=tree/ancestor=\] of
 `end block`:

 1. Let `reference node` be
 `end block`.
 2. While `reference node` is not a
 \[=tree/child=\] of `start block`, set
 `reference node` to its \[=tree/parent=\].
 3. Call
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection"), with first
 argument `start block` and second argument
 the \[=tree/index=\] of `reference node`.
 4. If `end block` has no \[=tree/children=\]:
 1. While `end block` is
 [editable](#editable) and is the only \[=tree/child=\] of
 its \[=tree/parent=\] and is not a \[=tree/child=\] of
 `start block`, let `parent` equal `end block`, then remove
 `end block` from `parent`, then set `end block` to
 `parent`.
 2. If `end block` is [editable](#editable)
 and is not an [inline node](#inline-node), and its {{Node/
 previousSibling}} and {{Node/ nextSibling}} are both [inline
 nodes](#inline-node "inline node"), call
 [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and insert it into `end block`\'s \[=tree/parent=\] immediately after
 `end block`.
 3. If `end block` is [editable](#editable),
 remove it from its \[=tree/parent=\].
 4. [Restore states and values](#restore-states-and-values) from
 `overrides`.
 5. Abort these steps.
 5. If `end block`\'s {{Node/firstChild}} is not
 an [inline node](#inline-node), [restore states and
 values](#restore-states-and-values) from `record`, then abort these steps.
 6. Let `children` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.
 7. Append the first \[=tree/child=\] of `end block` to `children`.
 8. While `children`\'s last member is not a
 \[\^br\^\], and `children`\'s last member\'s
 {{Node/nextSibling}} is an [inline node](#inline-node), append
 `children`\'s last member\'s
 {{Node/nextSibling}} to `children`.
 9. [Record the values](#record-the-values) of `children`, and let `values` be the result.
 10. While `children`\'s first member\'s
 \[=tree/parent=\] is not `start block`,
 [split the parent](#split-the-parent) of `children`.
 11. If `children`\'s first member\'s {{Node/
 previousSibling}} is an [editable](#editable) \[\^br\^\], remove
 that \[\^br\^\] from its \[=tree/parent=\].

33. In this case, pull in everything that comes after
 `start block`, until we hit a br or block node.

 Otherwise, if `start block` is a
 \[=tree/descendant=\] of `end block`:

 1. Call
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection"), with first
 argument `start block` and second argument
 `start block`\'s \[=Node/length=\].
 2. Let `reference node` be
 `start block`.
 3. While `reference node` is not a
 \[=tree/child=\] of `end block`, set
 `reference node` to its \[=tree/parent=\].
 4. If `reference node`\'s {{Node/nextSibling}}
 is an [inline node](#inline-node) and `start block`\'s {{Node/lastChild}} is a \[\^br\^\], remove
 `start block`\'s {{Node/lastChild}} from it.
 5. Let `nodes to move` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.
 6. If `reference node`\'s {{Node/nextSibling}}
 is neither null nor a [block node](#block-node), append it to
 `nodes to move`.
 7. While `nodes to move` is nonempty and its
 last member isn\'t a \[\^br\^\] and its last member\'s
 {{Node/nextSibling}} is neither null nor a [block
 node](#block-node), append its last member\'s
 {{Node/nextSibling}} to `nodes to move`.
 8. [Record the values](#record-the-values) of
 `nodes to move`, and let `values` be the result.
 9. For each `node` in `nodes to move`, append `node` as the last
 \[=tree/child=\] of `start block`,
 [preserving ranges](#preserving-ranges).

34. In the last case, just move all the children of the end block to the
 start block, and then get rid of any elements we emptied that way.

 Otherwise:

 1. Call
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection"), with first
 argument `start block` and second argument
 `start block`\'s \[=Node/length=\].
 2. If `end block`\'s {{Node/firstChild}} is an
 [inline node](#inline-node) and `start block`\'s {{Node/lastChild}} is a \[\^br\^\], remove
 `start block`\'s {{Node/lastChild}} from it.
 3. [Record the values](#record-the-values) of `end block`\'s \[=tree/children=\], and let `values` be the result.
 4. While `end block` has \[=tree/children=\],
 append the first \[=tree/child=\] of `end block` to `start block`, [preserving
 ranges](#preserving-ranges).
 5. While `end block` has no
 \[=tree/children=\], let `parent` be the
 \[=tree/parent=\] of `end block`, then
 remove `end block` from `parent`, then set `end block` to
 `parent`.

35. We might have deleted the contents between two lists, in which case
 we should merge them. See [bug
 13976](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13976).

36. Let `ancestor` be `start block`.

37. While `ancestor` has an \[=tree/inclusive
 ancestor=\] \[\^ol\^\] [in the same editing
 host](#in-the-same-editing-host) whose {{Node/ nextSibling}} is also
 an \[\^ol\^\] [in the same editing host](#in-the-same-editing-host),
 or an \[=tree/inclusive ancestor=\] \[\^ul\^\] [in the same editing
 host](#in-the-same-editing-host) whose {{Node/ nextSibling}} is also
 a \[\^ul\^\] [in the same editing host](#in-the-same-editing-host):
 1. While `ancestor` and its
 {{Node/nextSibling}} are not both \[\^ol\^\]s [in the same
 editing host](#in-the-same-editing-host), and are also not both
 \[\^ul\^\]s [in the same editing
 host](#in-the-same-editing-host), set `ancestor` to its \[=tree/parent=\].
 2. While `ancestor`\'s {{Node/nextSibling}} has
 \[=tree/children=\], append `ancestor`\'s
 {{Node/nextSibling}}\'s {{Node/firstChild}} as the last
 \[=tree/child=\] of `ancestor`, [preserving
 ranges](#preserving-ranges).
 3. Remove `ancestor`\'s {{Node/nextSibling}}
 from its \[=tree/parent=\].

38. [Restore the values](#restore-the-values) from `values`.

39. If `start block` has no \[=tree/children=\],
 call [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and append the result as the last
 \[=tree/child=\] of `start block`.

40. [Remove extraneous line breaks at the end
 of](#remove-extraneous-line-breaks-at-the-end-of)
 `start block`.

41. [Restore states and values](#restore-states-and-values) from
 `overrides`.

### Splitting a node list\'s parent

To [split the parent] of a list
`node list` of consecutive \[=tree/sibling=\]
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"):

This algorithm breaks up the parent of `node list`.
If they\'re the only children of their parent, the parent is removed
entirely. If there are preceding or following siblings, the original
parent is left intact as the parent of those siblings. If there are both
preceding and following siblings, the original parent is left as the
parent of the following siblings and a clone is used for the parent of
the preceding siblings.

We make sure not to disrupt the appearance any more than necessary.
Obviously margins or such on the parent will be lost, but the children
will not wind up on the same line as anything they weren\'t already on
the same line as. E.g., if we split the parent of \"bar\" in
`foo<p>bar</p>`{title=""}, we get `foo<br>bar`{title=""}, not
`foobar`{title=""}. (This is amazingly complicated and error-prone.) We
don\'t preserve inline styles: callers that want to do that should call
[record the values](#record-the-values) and [restore the
values](#restore-the-values) themselves.

All this is useful in a lot of situations, like for outdenting. For
inline formatting commands, we almost always rely on [pushing down
values](#push-down-values "push down values") instead, since that often
leads to tidier markup.

1. Let `original parent` be the \[=tree/parent=\]
 of the first member of `node list`.

2. If `original parent` is not
 [editable](#editable) or its \[=tree/parent=\] is null, do nothing
 and abort these steps.

3. If the first \[=tree/child=\] of `original parent` is in `node list`, [remove extraneous
 line breaks before](#remove-extraneous-line-breaks-before)
 `original parent`.

4. If the first \[=tree/child=\] of `original parent` is in `node list`, and
 ` original parent` [follows a line
 break](#follows-a-line-break), set `follows line break` to true. Otherwise, set `follows line break` to false.

5. If the last \[=tree/child=\] of `original parent` is in `node list`, and
 `original parent` [precedes a line
 break](#precedes-a-line-break), set `precedes line break` to true. Otherwise, set `precedes line break` to false.

6. ::: note
 TODO: We insert things after the parent. This is bad, because it
 will cause them to become part of any ranges that immediately
 follow. For instance, if we\'re hitting \"bar\" in

 <div><p>foo<p>bar</div>{<p>baz}

 it becomes

 <div><p>foo</div>{<p>bar<p>baz}

 instead of

 <div><p>foo</div><p>bar{<p>baz}

 because of how range mutation rules work. This doesn\'t happen if we
 insert before. This may or may not be important enough to bother
 working around.
 :::

 If the first \[=tree/child=\] of `original parent` is not in `node list`, but its last
 \[=tree/child=\] is:

 1. For each `node` in `node list`, *in reverse order*, insert `node`
 into the \[=tree/parent=\] of `original parent` immediately after `original parent`, [preserving ranges](#preserving-ranges).
 2. If `precedes line break` is true, and the
 last member of `node list` does not [precede
 a line break](#precedes-a-line-break "precedes a line break"),
 call [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and insert the result immediately after the
 last member of `node list`.
 3. [Remove extraneous line breaks at the end
 of](#remove-extraneous-line-breaks-at-the-end-of)
 `original parent`.
 4. Abort these steps.

7. If the first \[=tree/child=\] of `original parent` is not in `node list`:
 1. Let `cloned parent` be the result of calling
 [`cloneNode(false)`](http://dom.spec.whatwg.org/#dom-node-clonenode)
 on `original parent`.
 2. If `original parent` has an ` `[`id`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-id-attribute)
 attribute, unset it.
 3. Insert `cloned parent` into the
 \[=tree/parent=\] of `original parent`
 immediately before `original parent`.
 4. While the {{Node/ previousSibling}} of the first member of
 `node list` is not null, append the first
 \[=tree/child=\] of `original parent` as the
 last \[=tree/child=\] of `cloned parent`,
 [preserving ranges](#preserving-ranges).

8. Notice that a boundary point that was immediately before the element
 will now be immediately before its children, just because of the
 regular range mutation rules, without needing to worry about
 preserving ranges. Likewise for boundary points immediately after
 the element, if we wind up removing the element in the final step.
 Preserving ranges is only necessary for the sake of boundary points
 in the element or its descendants.

 For each `node` in `node list`, insert `node` into the
 \[=tree/parent=\] of `original parent`
 immediately before `original parent`,
 [preserving ranges](#preserving-ranges).

9. If `follows line break` is true, and the first
 member of `node list` does not [follow a line
 break](#follows-a-line-break "follows a line break"), call
 [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and insert the result immediately before the
 first member of `node list`.

10. If the last member of `node list` is an [inline
 node](#inline-node) other than a \[\^br\^\], and the first
 \[=tree/child=\] of `original parent` is a
 \[\^br\^\], and `original parent` is not an
 [inline node](#inline-node), remove the first \[=tree/child=\] of
 `original parent` from
 `original parent`.

11. If `original parent` has no \[=tree/children=\]:
 1. Remove `original parent` from its
 \[=tree/parent=\].
 2. If `precedes line break` is true, and the
 last member of `node list` does not [precede
 a line break](#precedes-a-line-break "precedes a line break"),
 call [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and insert the result immediately after the
 last member of `node list`.

12. Otherwise, [remove extraneous line breaks
 before](#remove-extraneous-line-breaks-before)
 `original parent`.

13. The parent might be null if it\'s a br that we removed in the last
 step, in which case this step isn\'t necessary.

 If `node list`\'s last member\'s
 {{Node/nextSibling}} is null, but its \[=tree/parent=\] is not null,
 [remove extraneous line breaks at the end
 of](#remove-extraneous-line-breaks-at-the-end-of)
 `node list`\'s last member\'s \[=tree/parent=\].

To remove a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node` while [preserving its
descendants], [split the
parent](#split-the-parent) of `node`\'s
\[=tree/children=\] if it has any. If it has no \[=tree/children=\],
instead remove it from its \[=tree/parent=\].

### Canonical space sequences

Whitespace in HTML normally collapses. However, if the user hits the
space bar twice in an HTML editor, they expect to see two spaces, not
one. Even if they hit the space bar once at the beginning or end of a
line, it would collapse without special handling. The only good solution
here is for the author to set white-space: pre-wrap on the editable
area, and on everywhere the content is reproduced. But if they don\'t,
we have to painfully hack around the problem.

This is a basically intractable problem because of the unfortunate
confluence of three factors. One, our characters are Unicode, and
Unicode doesn\'t know about whitespace collapsing, so it provides no
special characters to control it. Two, HTML itself provides no features
that control whitespace collapsing without undesired side effects (like
inhibiting line breaks or not being allowed inside `<p>`{title=""}).
Three, we need to support user agents that don\'t reliably support CSS,
since that includes many popular mail clients.

The upshot is we have no good way to control whitespace collapse, so we
rely on the least bad way available: `&nbsp;`{title=""}. This doesn\'t
collapse with adjacent whitespace in browsers, which is good. But it
also doesn\'t allow a line break opportunity, which is bad. In any run
of whitespace that we don\'t want to collapse, any two regular spaces
must be separated by an `&nbsp;`{title=""} so they don\'t collapse
together, but we need to carefully limit runs of consecutive
`&nbsp;`{title=""}s to minimize the damage to line-breaking behavior.

The result is an elaborate and meticulously-crafted hodgepodge of bad
compromises that frankly isn\'t worth the effort to explain here. The
saving grace is that it all gets disabled if white-space is set to
pre-wrap as it should be, so authors can opt out of the insanity.
Interested readers will find detailed rationale for the exact sequences
required in the comments.

See long comment before [insertText](#the-inserttext-command).

The [canonical space sequence] of length
`n`, with boolean flags
`non-breaking start` and
`non-breaking end`, is returned by the following
algorithm:

1. If `n` is zero, return the empty string.
2. If `n` is one and both
 `non-breaking start` and
 `non-breaking end` are false, return a single
 space (U+0020).
3. If `n` is one, return a single non-breaking
 space (U+00A0).
4. Let `buffer` be the empty string.
5. If `non-breaking start` is true, let
 `repeated pair` be U+00A0 U+0020. Otherwise, let
 it be U+0020 U+00A0.
6. While `n` is greater than three, append
 `repeated pair` to `buffer`
 and subtract two from `n`.
7. If `n` is three, append a three-[code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit) string to
 `buffer` depending on
 `non-breaking start` and
 `non-breaking end`:

 `non-breaking start` and `non-breaking end` false
 : U+0020 U+00A0 U+0020

 `non-breaking start` true, `non-breaking end` false
 : U+00A0 U+00A0 U+0020

 `non-breaking start` false, `non-breaking end` true
 : U+0020 U+00A0 U+00A0

 `non-breaking start` and `non-breaking end` both true
 : U+00A0 U+0020 U+00A0
8. Otherwise, append a two-[code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit) string to
 `buffer` depending on
 `non-breaking start` and
 `non-breaking end`:

 `non-breaking start` and `non-breaking end` false\
 `non-breaking start` true, `non-breaking end` false
 : U+00A0 U+0020

 `non-breaking start` false, `non-breaking end` true
 : U+0020 U+00A0

 `non-breaking start` and `non-breaking end` both true
 : U+00A0 U+00A0
9. Return `buffer`.

To [canonicalize whitespace] at
(`node`, `offset`), given an
optional boolean argument `fix collapsed space` that
defaults to true:

1. If `node` is neither [editable](#editable) nor
 an [editing host], abort these steps.

2. Let `start node` equal `node` and let `start offset` equal
 `offset`.

3. First we go to the beginning of the current whitespace run.

 Repeat the following steps:

 1. If `start node` has a \[=tree/child=\] [in
 the same editing host](#in-the-same-editing-host) with
 \[=tree/index=\] `start offset` minus one,
 set `start node` to that \[=tree/child=\],
 then set `start offset` to
 `start node`\'s \[=Node/length=\].

 2. TODO: Following a line break is unlikely to be the right
 criterion.

 Otherwise, if `start offset` is zero and
 `start node` does not [follow a line
 break](#follows-a-line-break "follows a line break") and
 `start node`\'s \[=tree/parent=\] is [in the
 same editing host](#in-the-same-editing-host), set
 `start offset` to `start node`\'s \[=tree/index=\], then set `start node` to its \[=tree/parent=\].

 3. Otherwise, if `start node` is a {{Text}}
 node and its \[=tree/parent=\]\'s [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) for
 \"white-space\" is neither \"pre\" nor \"pre-wrap\" and
 `start offset` is not zero and the
 (`start offset` − 1)st [code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit) of
 `start node`\'s {{CharacterData/ data}} is a
 space (0x0020) or non-breaking space (0x00A0), subtract one from
 `start offset`.

 4. Otherwise, break from this loop.

4. Now we collapse any consecutive spaces, if
 `fix collapsed space` is true.

 Let `end node` equal `start node` and `end offset` equal
 `start offset`.

5. Let `length` equal zero.

6. This tries to delete spaces at the beginning of a line ([bug
 14119](https://www.w3.org/Bugs/Public/show_bug.cgi?id=14119)).

 Let `collapse spaces` be true if
 `start offset` is zero and
 `start node` [follows a line
 break](#follows-a-line-break), otherwise false.

7. Repeat the following steps:
 1. If `end node` has a \[=tree/child=\] [in the
 same editing host](#in-the-same-editing-host) with
 \[=tree/index=\] `end offset`, set
 `end node` to that \[=tree/child=\], then
 set `end offset` to zero.

 2. TODO: Preceding a line break is unlikely to be the right
 criterion.

 Otherwise, if `end offset` is
 `end node`\'s \[=Node/length=\] and
 `end node` does not [precede a line
 break](#precedes-a-line-break "precedes a line break") and
 `end node`\'s \[=tree/parent=\] is [in the
 same editing host](#in-the-same-editing-host), set
 `end offset` to one plus
 `end node`\'s \[=tree/index=\], then set
 `end node` to its \[=tree/parent=\].

 3. Otherwise, if `end node` is a {{Text}} node
 and its \[=tree/parent=\]\'s [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) for
 \"white-space\" is neither \"pre\" nor \"pre-wrap\" and
 `end offset` is not `end node`\'s \[=Node/length=\] and the `end offset`th [code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit) of
 `end node`\'s {{CharacterData/ data}} is a
 space (0x0020) or non-breaking space (0x00A0):
 1. If `fix collapsed space` is true, and
 `collapse spaces` is true, and the
 `end offset`th [code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit)
 of `end node`\'s {{CharacterData/ data}}
 is a space (0x0020): call ` `[`deleteData(``end offset``, 1)`](http://dom.spec.whatwg.org/#dom-characterdata-deletedata)
 on `end node`, then continue this loop
 from the beginning.
 2. Set `collapse spaces` to true if the
 `end offset`th [code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit)
 of `end node`\'s {{CharacterData/ data}}
 is a space (0x0020), false otherwise.
 3. Add one to `end offset`.
 4. Add one to `length`.

 4. Otherwise, break from this loop.

8. We\'ve already stripped leading whitespace, and collapsed
 consecutive spaces. Now we try to strip any collapsed trailing
 whitespace ([bug
 14119](https://www.w3.org/Bugs/Public/show_bug.cgi?id=14119) again).

 If `fix collapsed space` is true, then while
 (`start node`, `start offset`) is \[=boundary point/before=\] (`end node`, `end offset`):

 1. If `end node` has a \[=tree/child=\] [in the
 same editing host](#in-the-same-editing-host) with
 \[=tree/index=\] `end offset` − 1, set
 `end node` to that \[=tree/child=\], then
 set `end offset` to `end node`\'s \[=Node/length=\].
 2. Otherwise, if `end offset` is zero and
 `end node`\'s \[=tree/parent=\] is [in the
 same editing host](#in-the-same-editing-host), set
 `end offset` to `end node`\'s \[=tree/index=\], then set `end node` to its \[=tree/parent=\].
 3. Otherwise, if `end node` is a {{Text}} node
 and its \[=tree/parent=\]\'s [resolved
 value](http://dev.w3.org/csswg/cssom/#resolved-value) for
 \"white-space\" is neither \"pre\" nor \"pre-wrap\" and
 `end offset` is `end node`\'s \[=Node/length=\] and the last [code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit) of
 `end node`\'s {{CharacterData/ data}} is a
 space (0x0020) and `end node` [precedes a
 line break](#precedes-a-line-break):
 1. Subtract one from `end offset`.
 2. Subtract one from `length`.
 3. Call [`deleteData(``end offset``, 1)`](http://dom.spec.whatwg.org/#dom-characterdata-deletedata)
 on `end node`.
 4. Otherwise, break from this loop.

9. Finally we replace with the canonical sequence.

 Let `replacement whitespace` be the [canonical
 space sequence](#canonical-space-sequence) of length
 `length`. `non-breaking start` is true if `start offset` is zero and
 `start node` [follows a line
 break](#follows-a-line-break), and false otherwise.
 `non-breaking end` is true if
 `end offset` is `end node`\'s {{CharacterData/length}} and `end node` [precedes a line break](#precedes-a-line-break), and false
 otherwise.

10. While (`start node`, `start offset`) is \[=boundary point/before=\] (`end node`, `end offset`):
 1. If `start node` has a \[=tree/child=\] with
 \[=tree/index=\] `start offset`, set
 `start node` to that \[=tree/child=\], then
 set `start offset` to zero.
 2. Otherwise, if `start node` is not a {{Text}}
 node or if `start offset` is
 `start node`\'s \[=Node/length=\], set
 `start offset` to one plus
 `start node`\'s \[=tree/index=\], then set
 `start node` to its \[=tree/parent=\].
 3. Otherwise:
 1. Remove the first [code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit)
 from `replacement whitespace`, and let
 `element` be that [code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit).
 2. If `element` is not the same as the
 `start offset`th [code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit)
 of `start node`\'s {{CharacterData/
 data}}:
 1. We need to insert then delete, so that we don\'t change
 range boundary points. TODO: switch to using \"replace
 data\" now that DOM Core has defined that.

 Call ` `[`insertData(``start offset``, ``element``)`](http://dom.spec.whatwg.org/#dom-characterdata-insertdata)
 on `start node`.

 2. Call ` `[`deleteData(``start offset`` + 1, 1)`](http://dom.spec.whatwg.org/#dom-characterdata-deletedata)
 on `start node`.
 3. Add one to `start offset`.

### Indenting and outdenting

There are two basically different types of indent/outdent: lists, and
everything else. For lists we\'ll wrap the item in a nested list to
indent, and [split its parent](#split-the-parent "split the parent") to
outdent. For everything else we\'ll wrap in a `<blockquote>`{title=""}
to indent, and try breaking it out of an ancestor [indentation
element](#indentation-element) to outdent.

Indenting winds up being pretty simple: just add an appropriate wrapper.
There\'s not really anything to think about here except which wrapper we
want (`<ol>`{title=""} or `<ul>`{title=""} or `<blockquote>`{title=""}),
and establishing that is not rocket science.

Outdenting is considerably more complicated. The basic idea we follow is
to first find the nearest editable ancestor that\'s a list or
[indentation element](#indentation-element). If we succeed, and the node
we\'re trying to outdent is the only descendant of the ancestor, of
course we can just remove the ancestor and that\'s that. Otherwise, what
we do is remove the ancestor and then indent all its other descendants,
much like [pushing down values](#push-down-values "push down values").

But of course, there are complications. We don\'t always actually want
to remove the *closest* ancestor that\'s causing indentation. For one
thing, we prefer ancestors that we can remove completely, i.e., [simple
indentation
elements](#simple-indentation-element "simple indentation element").
When outdenting
`<blockquote><blockquote id="abc">foo</blockquote></blockquote>`{title=""},
removing the inner tag would result in
`<blockquote><div id="abc">foo</div></blockquote>`{title=""}, since we
don\'t want to lose the id. Thus we prefer to remove the outer tag and
wind up with `<blockquote id="abc">foo</blockquote>`{title=""}.

Also, if the node we\'re outdenting is itself a list, we prefer to
remove an ancestor [indentation element](#indentation-element) rather
than the list. Otherwise, if the user selected some text, indented it,
then added a list, there would be no way to remove the indentation
without removing the list first. This way, the user could remove the
list with the appropriate list-toggling command or remove the
indentation with the outdent command.

We have to handle entire lists of siblings at once, or else we\'d wind
up doing something like

 <ol>
 {<li>foo</li>
 <ol><li>bar</li></ol>}
 </ol>
 ->
 <ol><ol>
 <li>foo</li>
 <li>bar</li>
 </ol></ol>
 ->
 <ol><ol><ol>
 <li>foo</li>
 <li>bar</li>
 </ol></ol></ol>

since by the time we got to doing the \<ol\> that originally contained
\"bar\", we won\'t remember that we aren\'t supposed to indent \"foo\" a
second time.

To [indent] a list `node list` of
consecutive \[=tree/sibling=\]
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"):

1. If `node list` is empty, do nothing and abort
 these steps.

2. Let `first node` be the first member of
 `node list`.

3. If `first node`\'s \[=tree/parent=\] is an
 \[\^ol\^\] or \[\^ul\^\]:
 1. Let `tag` be the \[=Element/local name=\] of
 the \[=tree/parent=\] of `first node`.

 2. ::: note
 This matches IE9, Firefox 4.0, and Chrome 12 dev. If there\'s a
 preceding \<li\>, Opera 11.10 instead adds the new parent to the
 end of that \<li\>, so it\'s not the child of another list,
 which is invalid. But the other browsers\' way of doing things
 makes things simpler. E.g., if we want to indent an \<li\> and
 it has \<ol\>/\<ul\> children, we have to distinguish between
 the case where we want to indent the whole \<li\> or only the
 first part. It also allows things like

 <ol><li>
 foo
 <ol><li>bar</li></ol>
 baz
 </li></ol>

 in which case it\'s unclear what we should do if the user
 selects \"foo\" and indents. I\'ve filed [a
 bug](https://www.w3.org/Bugs/Public/show_bug.cgi?id=12609) on
 HTML5.
 :::

 [Wrap](#wrap) `node list`, with
 `sibling criteria` returning true for an
 [HTML element](#html-element) with \[=Element/local name=\]
 `tag` and false otherwise, and
 `new parent instructions` returning the
 result of calling [`createElement(``tag``)`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ ownerDocument}} of `first node`.

 3. Abort these steps.

4. ::: note
 Firefox 4.0 respects the CSS styling flag for indent, but Chrome 12
 dev does not. I always produce blockquotes, even if CSS styling is
 on, for two reasons. One, IE9 handles inline margin attributes
 badly: when outdenting, it propagates the margin to the parent,
 which doesn\'t actually remove it. Two, in CSS mode I\'d want to use
 \<div style=\"margin: 1em 40px\"\> to match non-CSS mode, but
 authors are very likely to want to remove the top/bottom margin,
 which they can\'t do if it\'s not a special tag. Authors who really
 want divs for indentation could always convert the blockquotes to
 divs themselves. But if people really want it, I could respect CSS
 styling mode here too.

 The top/bottom margins might be undesirable here, but no more so
 than for \<ol\>/\<ul\>/\<p\>/etc. Here as there, authors can remove
 them with CSS if they want.

 blockquote indents on both sides, so we don\'t have to worry about
 directionality. In theory it would be better if we indented only on
 the start side, but that requires care to get right in
 mixed-direction cases. Even once browsers start to support
 margin-start and so on, we can\'t use them because a) we have to
 work okay in legacy browsers and b) it doesn\'t help if a descendant
 block has different direction (so should be indented the other way).
 So let\'s not worry about it: most browsers don\'t, and the ones
 that do get it wrong. Just indent on both sides.
 :::

 [Wrap](#wrap) `node list`, with
 `sibling criteria` returning true for a [simple
 indentation element](#simple-indentation-element) and false
 otherwise, and `new parent instructions`
 returning the result of calling
 [`createElement("blockquote")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the {{Node/ownerDocument}} of `first node`.
 Let `new parent` be the result.

5. [Fix disallowed ancestors](#fix-disallowed-ancestors) of
 `new parent`.

Things that are produced for indentation that we need to consider
removing:

- Plain \<blockquote\> (produced by spec, Firefox 4.0 non-CSS, Opera
 11.00)
- \<blockquote style=\"margin-right: 0\" dir=\"ltr\"\> and \<blockquote
 style=\"margin-left: 0\" dir=\"rtl\"\> (IE9)
- \<blockquote class=\"webkit-indent-blockquote\" style=\"margin: 0 0 0
 40px; border: none; padding: 0px\"\> (Chrome 12 dev)
- \<div style=\"margin-left: 40px\"\> and \<div style=\"margin-right:
 40px\"\> (Firefox 4.0 CSS if no other element available)
- Other random things with display: block whose left or right margin was
 increased by 40px (Firefox 4.0 CSS)

For discussion on the list-related stuff, see the comment for
[insertOrderedList](#the-insertorderedlist-command).

Gecko in CSS mode just adds margin properties to random elements that
are lying around. We don\'t attempt to remove those, because 1) the
amount and position of the margin can vary (it increases the margin if
there\'s a preexisting one), so it\'s potentially complicated, and 2) no
browser removes such margins on outdent, including Gecko, except for
Gecko in CSS mode. TODO: Consider removing it anyway.

To [outdent] a
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node`:

1. If `node` is not [editable](#editable), abort
 these steps.

2. The easy case is when the whole element is indented. In this case we
 remove the whole thing indiscriminately. In the case of blockquotes
 created by IE, this might change the direction of some children, but
 then their direction was probably changed incorrectly in the first
 place, so no harm.

 If `node` is a [simple indentation
 element](#simple-indentation-element), remove `node`, [preserving its
 descendants](#preserving-its-descendants). Then abort these steps.

3. This might be a simple indentation element that had style added to
 it by Firefox in CSS mode, for instance (color, font-family, etc.).

 If `node` is an [indentation
 element](#indentation-element):

 1. Unset the ` `[`dir`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-dir-attribute)
 attribute of `node`, if any.
 2. Unset the margin, padding, and border CSS properties of
 `node`.
 3. [Set the tag name](#set-the-tag-name) of `node` to \"div\".
 4. Abort these steps.

4. ::: note
 Approximate algorithms when an ancestor is causing the indentation
 appear to be:

 IE9
 : Go to the innermost element causing indentation. If the stuff to
 be outdented includes all the contents of that element, get rid
 of it, but if it has any attributes, change it to a \<p\> with
 those same attributes. This is an excellent idea in general, but
 unfortunately it preserves explicitly-specified margins in style
 attributes, which isn\'t great. In other cases, it moves the
 stuff to be outdented outside. Not clear on all the details,
 seems to be pretty confusing. Also does a bunch of seemingly
 arbitrary normalization like removing divs and some attributes
 from some things . . .

 Firefox 4.0
 : Go to the innermost element causing indentation. If the stuff to
 be outdented includes all the contents of that element, get rid
 of it, even if it has arbitrary attributes. Otherwise, move the
 stuff to be outdented outside the indenting element. If there
 are any intervening elements that include stuff not to be
 outdented, wrap the outdented stuff in copies (which can
 duplicate id\'s, etc.).

 Chrome 12 dev
 : Go to the outermost element causing indentation (even if the
 current element is itself causing indentation). Move the text to
 be outdented outside that outermost element, without regard to
 any intervening elements. Then recreate the original styles on
 the moved text, in some fashion. Something like that; it
 confuses me and doesn\'t seem to be reasonable.

 Opera 11.00
 : Like Firefox, except it goes to the outermost element, not the
 innermost. Also seems to special-case to avoid duplicate id\'s,
 and has a few other quirks.

 Overall, all flawed, so I\'ll make up my own, patterned after
 pushing down styles. First we search ancestors for a simple
 indentation element, which we stand a chance of completely removing.
 Failing that, we look for an indentation element that\'s not simple,
 so we can\'t completely remove it.
 :::

 Let `current ancestor` be `node`\'s \[=tree/parent=\].

5. Let `ancestor list` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.

6. While `current ancestor` is an
 [editable](#editable) {{Element}} that is neither a [simple
 indentation element](#simple-indentation-element) nor an \[\^ol\^\]
 nor a \[\^ul\^\], append `current ancestor` to
 `ancestor list` and then set
 `current ancestor` to its \[=tree/parent=\].

7. If `current ancestor` is not an
 [editable](#editable) [simple indentation
 element](#simple-indentation-element):
 1. Let `current ancestor` be `node`\'s \[=tree/parent=\].
 2. Let `ancestor list` be the empty list.
 3. While `current ancestor` is an
 [editable](#editable) {{Element}} that is neither an
 [indentation element](#indentation-element) nor an \[\^ol\^\]
 nor a \[\^ul\^\], append `current ancestor`
 to `ancestor list` and then set
 `current ancestor` to its \[=tree/parent=\].

8. When asked to outdent a list wrapped in a simple indentation
 element, Chrome 12 dev removes the list instead of the simple
 indentation element. Opera 11.10 seems to remove both. IE9 and
 Firefox 4.0 remove the simple indentation element, as does the spec.

 If `node` is an \[\^ol\^\] or \[\^ul\^\] and
 `current ancestor` is not an
 [editable](#editable) [indentation element](#indentation-element):

 1. Unset the ` `[`reversed`](http://www.whatwg.org/specs/web-apps/current-work/multipage/grouping-content.html#attr-ol-reversed),
 ` `[`start`](http://www.whatwg.org/specs/web-apps/current-work/multipage/grouping-content.html#attr-ol-start),
 and ` `[`type`](http://www.whatwg.org/specs/web-apps/current-work/multipage/grouping-content.html#attr-ol-type)
 attributes of `node`, if any are set.

 2. Let `children` be the \[=tree/children=\] of
 `node`.

 3. We can\'t turn it into a div if it\'s the child of an ol or ul,
 because that\'s not allowed: there\'s no way to group li\'s (see
 [HTML bug
 13128](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13128)).

 If `node` has attributes, and its
 \[=tree/parent=\] is not an \[\^ol\^\] or \[\^ul\^\], [set the
 tag name](#set-the-tag-name) of `node` to
 \"div\".

 4. Otherwise:
 1. [Record the values](#record-the-values) of `node`\'s \[=tree/children=\], and let `values` be the result.
 2. Remove `node`, [preserving its
 descendants](#preserving-its-descendants).
 3. [Restore the values](#restore-the-values) from
 `values`.

 5. [Fix disallowed ancestors](#fix-disallowed-ancestors) of each
 member of `children`.

 6. Abort these steps.

9. If `current ancestor` is not an
 [editable](#editable) [indentation element](#indentation-element),
 abort these steps.

10. If we get to this point, we have an ancestor to split up.

 Append `current ancestor` to
 `ancestor list`.

11. We can\'t outdent it yet, because we need its children to remain
 intact for the loop.

 Let `original ancestor` be
 `current ancestor`.

12. While `ancestor list` is not empty:
 1. Let `current ancestor` be the last member of
 `ancestor list`.
 2. Remove the last member from `ancestor list`.
 3. Let `target` be the \[=tree/child=\] of
 `current ancestor` that is equal to either
 `node` or the last member of
 `ancestor list`.
 4. If `target` is an [inline
 node](#inline-node) that is not a \[\^br\^\], and its
 {{Node/nextSibling}} is a \[\^br\^\], remove `target`\'s {{Node/nextSibling}} from its \[=tree/parent=\].
 5. Let `preceding siblings` be the
 \[=tree/precedings=\] \[=tree/siblings=\] of `target`, and let `following siblings` be
 the \[=tree/followings=\] \[=tree/siblings=\] of
 `target`.
 6. [Indent](#indent) `preceding siblings`.
 7. [Indent](#indent) `following siblings`.

13. [Outdent](#outdent) `original ancestor`.

### Toggling lists

This is the action for [the `insertOrderedList`{title=""}
command](#the-insertorderedlist-command) and [the
`insertUnorderedList`{title=""}
command](#the-insertunorderedlist-command), which behave identically
except for which list type they target. It does several things that vary
contextually.

If everything in the selection is contained in the target list type
already, this more or less just outdents everything one step. This is
relatively simple.

Otherwise, it\'s slightly more complicated:

First, any lists of the opposite list type (`other tag name`) get converted to the target list type (`tag name`). They get merged into a sibling if appropriate, otherwise we
[set the tag name](#set-the-tag-name).

Then we go through all the affected nodes, handling each run of
consecutive siblings separately. Any line that\'s not already wrapped in
an `<li>`{title=""} gets wrapped. If the parent at this point isn\'t a
list at all, the run gets wrapped in a list. If it\'s the wrong type of
list, we [split the parent](#split-the-parent) and rewrap it in the
right type of list. That\'s basically it, except that we have to
exercise the usual care to try merging with siblings and so forth.

Research for insertOrderedList/insertUnorderedList: tested the following
command sequences in IE9, Firefox 4.0, Chrome 12 dev, Opera 11.10,
OpenOffice.org 3.2.1 Ubuntu package, Microsoft Office Word 2007. The
commands \"ol\", \"ul\", \"indent\", \"outdent\" correspond in browsers
to \"insertOrderedList\", \"insertUnorderedList\", \"indent\", and
\"outdent\"; in OO.org to \"Numbering On/Off\", \"Bullets On/Off\",
\"Increase Indent\", \"Decrease Indent\"; and in Word to \"Numbering\",
\"Bullets\", \"Increase Indent\", \"Decrease Indent\".

Note: OO has a bunch of extra options, like \"Promote One Level\",
\"Demote One Level\", \"Promote One Level With Subpoints\", \"Demote One
Level With Subpoints\", \"Insert Unnumbered Entry\", \"Restart
Numbering\". The regular \"Increase/Decrease Indent\" commands work
oddly, and I assume they\'re not really meant to be used inside lists.
Thus I also tested with \"Promote One Level\" and \"Demote One Level\".
These are denoted by OO\' instead of OO.

Assume that there are style rules in effect like

 ol ol { list-style-type: lower-alpha }
 ol ol ol { list-style-type: lower-roman }

This is the default appearance in Word, and I set OO to something
similar with Bullets and Numbering → Outline in the list editing
toolbox. I\'m ignoring bullet style throughout, for no particular
reason.

- In an existing ordered list equivalent to
 \<ol\>\<li\>foo\<li\>bar\<li\>baz\</ol\>quz:
 - Select \"bar\", do \"ol\":

 Word/OO
 : Remove indent and number \"2\", change \"3\" to \"2\".

 Browsers
 : Remove indent and number \"2\", change \"3\" to \"1\".

 Spec
 : Same as browsers.
 - Select \"bar\", do \"ul\":

 Word
 : Leave indent the same, change \"2\" to a bullet, change \"3\" to
 \"2\".

 OO
 : Increase indent, change \"2\" to a bullet, change \"3\" to
 \"2\".

 IE
 : Change all numbers to bullets.

 Firefox/Chrome/Opera
 : Leave indent the same, change \"2\" to a bullet, change \"3\" to
 \"1\".

 Spec
 : Same as Firefox/Chrome/Opera.
 - Select \"bar\", do \"indent\":

 Word/OO\'/Browsers
 : Increase indent, change \"2\" to \"a\", change \"3\" to \"2\".

 OO
 : Increase indent, do not change any numbers.

 Spec
 : Same as Word/OO\'/Browsers.
 - Select \"bar\", do \"outdent\":

 Word
 : Do nothing.

 OO
 : Leave indent the same, de-indent \"2\" so it goes past the left
 margin (?!), do not change any numbers.

 OO\'
 : Option grayed out.

 Browsers
 : Remove indent and the number \"2\", change \"3\" to \"1\".

 Spec
 : Same as browsers.
 - Select \"quz\", do \"ol\":

 Word/OO/IE/Chrome
 : Add as fourth item to existing list, numbered \"4\".

 Firefox/Opera
 : Create new list, number the item \"1\".

 Spec
 : Same as OO/Word/IE/Chrome.
- In an existing ordered list equivalent to
 \<ol\>\<li\>foo\<br\>bar\<li\>baz\</ol\>:
 - Select \"foo\", do \"ol\":

 Word/OO/IE/Chrome/Opera
 : Remove indent from both \"foo\" and \"bar\", change \"2\" -\>
 \"1\".

 Firefox
 : Increase indent for \"foo\" only, add additional \"a\" marker
 after \"1\" and before \"foo\".

 Spec
 : Same as Word/OO/IE/Chrome/Opera.
 - Select \"foo\", do \"ul\":

 Word/Opera
 : Change \"1\" -\> bullet, \"2\" -\> \"1\".

 OO
 : Increase indent for both \"foo\" and \"bar\", change \"1\" -\>
 bullet, \"2\" -\> \"1\".

 IE
 : Change all numbers to bullets.

 Firefox
 : Increase indent for \"foo\" only, add additional bullet marker
 after \"1\" and before \"foo\".

 Chrome
 : Remove indent from \"bar\", change \"1\" -\> bullet, \"2\" -\>
 \"1\".

 Spec
 : Same as Word/Opera.
 - Select \"foo\", do \"indent\":

 Word
 : Increase indent for whole list.

 OO
 : Increase indent for both \"foo\" and \"bar\".

 OO\'
 : Increase indent for \"foo\", change \"1\" -\> \"a\".

 IE/Firefox non-CSS/Opera
 : Increase indent for both \"foo\" and \"bar\", change \"1\" -\>
 \"a\", \"2\" -\> \"1\".

 Firefox CSS
 : Increase indent for \"foo\" only (\<div style=\"margin-left:
 40px\"\>).

 Chrome
 : Increase indent for \"foo\" only, add \"a\" before \"foo\", move
 \"1\" to be before \"bar\".

 Spec
 : Same as IE/Firefox non-CSS/Opera.
 - Select \"foo\", do \"outdent\":

 Word
 : Decrease indent for whole list, so it goes past the left margin.

 OO
 : Decrease indent for \"bar\" and \"1.\" (so \"1.\" goes past the
 left margin), but not \"foo\".

 OO\'
 : Option grayed out.

 IE/Chrome/Opera
 : Remove indent from both \"foo\" and \"bar\", remove \"1\",
 change \"2\" -\> \"1\".

 Firefox
 : Do nothing.

 Spec
 : Same as IE/Chrome/Opera.
 - Select \"bar\", do \"ol\":

 Word/OO/IE/Chrome/Opera
 : Remove indent from both \"foo\" and \"bar\", change \"2\" -\>
 \"1\".

 Firefox
 : Increase indent for \"bar\" only, add \"a\" marker before it.

 Spec
 : Same as Word/OO/IE/Chrome/Opera.
 - Select \"bar\", do \"ul\":

 Word/Opera
 : Change \"1\" -\> bullet, \"2\" -\> \"1\".

 OO
 : Increase indent for both \"foo\" and \"bar\", change \"1\" -\>
 bullet, \"2\" -\> \"1\".

 IE
 : Change all numbers to bullets.

 Firefox
 : Increase indent for \"bar\" only, add bullet marker before it.

 Chrome
 : Remove indent from \"foo\", change \"1\" -\> bullet and move it
 before \"bar\", change \"2\" -\> \"1\".

 Spec
 : Same as Word/Opera.
 - Select \"bar\", do \"indent\":

 Word
 : Increase indent for whole list.

 OO
 : Increase indent for both \"foo\" and \"bar\".

 OO\'
 : Increase indent for \"foo\", change \"1\" -\> \"a\".

 IE/Firefox non-CSS/Opera
 : Increase indent for both \"foo\" and \"bar\", change \"1\" -\>
 \"a\", \"2\" -\> \"1\".

 Firefox CSS
 : Increase indent for \"bar\" only (\<div style=\"margin-left:
 40px\"\>).

 Chrome
 : Increase indent for \"bar\" only, add \"a\" before \"bar\", move
 \"bar\" above \"foo\" (?!).

 Spec
 : Same as IE/Firefox non-CSS/Opera.
 - Select \"bar\", do \"outdent\":

 Word
 : Decrease indent for whole list, so it goes past the left margin.

 OO
 : Decrease indent for \"bar\" and \"1.\" (so \"1.\" goes past the
 left margin), but not \"foo\".

 OO\'
 : Option grayed out.

 IE/Chrome/Opera
 : Remove indent from both \"foo\" and \"bar\", remove \"1\",
 change \"2\" -\> \"1\".

 Firefox
 : Do nothing.

 Spec
 : Same as IE/Chrome/Opera.
- In an existing nested ordered list equivalent to
 \<ol\>\<li\>foo\<ol\>\<li\>bar\<li\>baz\</ol\>\<li\>quz\</ol\>:
 - Select \"bar\", do \"ol\":

 Word/IE/Firefox
 : Decrease indent, remove \"a\" (\"bar\" is aligned with \"foo\"
 with no marker of its own), change \"b\" -\> \"a\".

 OO
 : Remove all indent, change \"b\" -\> \"a\".

 Chrome
 : Decrease indent, change \"a\" -\> \"2\", \"b\" -\> \"a\", \"2\"
 -\> \"3\".

 Opera
 : Decrease indent, change \"a\" -\> \"2\", \"b\" -\> \"a\", \"2\"
 -\> \"4\", insert extra \"3\" list marker before new \"a\".

 Spec
 : Same as Chrome.
 - Select \"bar\", do \"ul\":

 Word/Firefox/Chrome
 : Change \"a\" -\> bullet, \"b\" -\> \"a\".

 OO
 : Increase indent, change \"a\" -\> bullet, \"b\" -\> \"a\".

 IE
 : Change \"a\" and \"b\" to bullets.

 Opera
 : Change \"a\" -\> bullet, \"b\" -\> \"a\", \"2\" -\> \"4\",
 insert extra list markers \"2\" and \"3\" before new bullet and
 \"a\".

 Spec
 : Same as Word/Firefox/Chrome.
 - Select \"bar\", do \"indent\":

 Word/OO\'/IE
 : Increase indent, change \"a\" -\> \"i\", leave \"b\" alone.

 OO
 : Increase indent, do not change numbers.

 Firefox/Chrome/Opera
 : Increase indent, change \"a\" -\> \"i\", \"b\" -\> \"a\".

 Spec
 : Same as Firefox/Chrome/Opera.
 - Select \"bar\", do \"outdent\":

 Word/OO\'/IE/Chrome
 : Decrease indent, change \"a\" -\> \"2\", \"b\" -\> \"a\", \"2\"
 -\> \"3\".

 OO
 : Leave indent the same, de-indent \"a\" so it goes past the left
 margin (?!).

 Firefox
 : Decrease indent, remove \"a\" (\"bar\" is aligned with \"foo\"
 with no marker of its own), change \"b\" -\> \"a\".

 Opera
 : Decrease indent, change \"a\" -\> \"2\", \"b\" -\> \"a\", \"2\"
 -\> \"4\", insert extra list marker \"3\" before new \"a\".

 Spec
 : Same as Word/OO\'/IE/Chrome.
- In existing nested lists equivalent to
 \<ol\>\<li\>foo\<ul\>\<li\>bar\<li\>baz\</ul\>\<li\>quz\</ol\>:
 - Select \"bar\", do \"ol\":

 Word
 : Change all bullets to numbers. (Not letters, even though
 indented!)

 OO
 : Decrease indent, change first bullet -\> \"2\", \"2\" -\> \"3\".

 IE
 : Change all bullets to letters.

 Firefox/Chrome
 : Change first bullet to \"a\".

 Opera
 : Change first bullet -\> \"a\", \"2\" -\> \"4\", insert extra
 list markers \"2\" and \"3\" before new \"a\" and bullet.

 Spec
 : Same as Firefox/Chrome.
 - Select \"bar\", do \"ul\":

 Word/IE/Firefox
 : Decrease indent, remove first bullet (\"bar\" is aligned with
 \"foo\" with no marker of its own).

 OO
 : Remove all indent, remove first bullet, leave all else the same.

 Chrome
 : Decrease indent, change first bullet -\> \"2\", \"2\" -\> \"3\".

 Opera
 : Decrease indent, change first bullet -\> \"2\", \"2\" -\> \"4\",
 insert extra list marker \"3\" before old bullet.

 Spec
 : Same as Chrome.
 - Select \"bar\", do \"indent\":

 Word
 : Increase indent, change first bullet to \"i\" (?!).

 OO/OO\'/Firefox/Chrome/Opera
 : Increase indent.

 IE
 : Increase indent, change \"2\" -\> \"3\" (?!?!). (I don\'t see
 from the markup why the 2 actually changes to a 3. The markup
 seems to be as other browsers.)

 Spec
 : Same as OO/OO\'/Firefox/Chrome/Opera.
 - Select \"bar\", do \"outdent\":

 Word/IE/Chrome
 : Decrease indent, change first bullet -\> \"2\", \"2\" -\> \"3\".

 OO
 : Usual crazy stuff, move bullet left but leave text alone.

 OO\'
 : Option grayed out. (Interesting.)

 Firefox
 : Decrease indent, remove first bullet (\"bar\" is aligned with
 \"foo\" with no marker of its own).

 Opera
 : Decrease indent, change first bullet -\> \"2\", \"2\" -\> \"4\",
 insert extra list marker \"3\" before old bullet.

 Spec
 : Same as Word/IE/Chrome.
- In an existing nested ordered list equivalent to
 \<ol\>\<li\>foo\<li\>bar\<ol\>\<li\>baz\</ol\>\<li\>quz\</ol\>:
 - Select \"bar\", do \"ol\":

 Word/OO
 : Remove indent and \"2\", change \"3\" -\> \"2\".

 IE/Chrome/Opera
 : Remove indent and \"2\", decrease indent of \"baz\", change
 \"2\" and \"3\" -\> \"1\".

 Firefox
 : Increase indent, add extra \"a\" marker between \"2\" and
 \"bar\".

 Spec
 : Different from all of them: remove indent and \"2\", change
 \"3\" -\> \"1\".
 - Select \"bar\", do \"ul\":

 Word
 : Change \"2\" -\> bullet.

 OO
 : Increase indent, change \"2\" -\> bullet, \"3\" -\> \"2\".

 IE
 : Change \"1\", \"2\", \"3\" -\> bullets (and \"a\" to \"1\").

 Firefox
 : Increase indent, add extra bullet marker between \"2\" and
 \"bar\".

 Chrome
 : Decrease indent of \"baz\", change \"2\" -\> bullet, \"a\" and
 \"3\" -\> \"1\".

 Opera
 : Change \"2\" -\> bullet, \"a\" and \"3\" -\> \"1\".

 Spec
 : Different from all of them: change \"2\" -\> bullet, \"3\" -\>
 \"1\".
 - Select \"bar\", do \"indent\":

 Word/OO\'
 : Increase indent, change \"2\" -\> \"a\", \"a\" -\> \"b\", \"3\"
 -\> \"2\".

 OO
 : Increase indent (double amount, past \"baz\").

 Firefox non-CSS/Opera
 : Increase indent of both \"bar\" and \"baz\", change \"2\" -\>
 \"a\", \"a\" -\> \"i\", \"3\" -\> \"2\".

 Firefox CSS
 : Increase indent.

 Chrome
 : Increase indent, add \"a\" marker before \"bar\", move \"2\"
 marker to before the \"a\" marker of \"baz\".

 Spec
 : Same as Word/OO\'.
 - Select \"bar\", do \"outdent\":

 Word/Firefox
 : Do nothing.

 OO
 : Decrease indent on \"2\", leave \"bar\" alone.

 OO\'
 : Option grayed out.

 IE
 : Decrease indent of \"baz\", change \"2\" and \"3\" -\> \"1\",
 \"a\" -\> \"2\".

 Chrome/Opera
 : Decrease indent of \"bar\" and \"baz\", remove \"2\", change
 \"a\" and \"3\" -\> \"1\".

 Spec
 : Different from all of them: remove indent and \"2\", change
 \"3\" -\> \"1\".
- In an existing nested ordered list equivalent to
 \<ol\>\<li\>foo\<li\>bar\<ol\>\<li\>baz\</ol\>quz\<li\>qoz\</ol\>:
 - Does not appear to be possible in Word or OO.
 - Also might be impossible to actually make such a list using
 execCommand() in browsers.
 - Suffice it to say that there\'s a lot of variation.
- In an existing indented region equivalent to
 foo\<blockquote\>bar\</blockquote\>baz:
 - Select \"bar\", do \"ol\":

 Word/OO/Firefox/Chrome
 : Increase indent, add \"1\".

 IE
 : Increase indent, add \"a\".

 Opera
 : Add \"1\" (but do not increase indent).
 - Select \"foobar\", do \"ol\":

 Word/IE
 : Increase indent of both, add \"1\" before \"foo\" and \"a\"
 before \"bar\".

 OO
 : Increase indent of \"bar\" one step, increase indent of \"foo\"
 two steps so it\'s aligned with \"bar\", add \"1\" before
 \"foo\" and \"2\" before \"bar\".

 Firefox
 : Increase indent of both, add \"1\" before foo\", add \"2\"
 before \"bar\" aligned with the \"1\" of \"foo\" (so large gap
 between \"2\" and \"bar\").

 Chrome
 : Increase indent of \"foo\", add \"1\" before \"foo\" and \"2\"
 before \"bar\".

 Opera
 : Mash everything together on one line. But if you do
 \<p\>foo\</p\>\<blockquote\>bar\</blockquote\>\<p\>baz\</p\>
 instead, same as Chrome.
 - Select \"foo\" and do \"ol\", then select \"bar\" and do \"ol\":

 Word/OO/Firefox/Opera
 : Different than doing both at once (often in exciting ways).

 IE/Chrome
 : Same as doing both at once.
- \<p\>foo\</p\>\<blockquote\>\<p\>bar\</p\>\<p\>baz\</p\>\</blockquote\>
 - Select \"foobar\" and do \"ol\":

 Word
 : One-item list with sublist.

 OO/Firefox/Chrome/Opera
 : One two-item list, unindented.

 IE9
 : Two one-item lists.
 - Select \"foo\", do \"ol\", then select \"bar\" and do \"ol\":

 Word/OO/Chrome
 : One two-item list, unindented.

 IE9/Firefox
 : Two one-item lists.

 Opera
 : Two one-item lists, both unindented.
 - Desired behavior: One-item list with sublist in both cases.
- In an existing multi-line indented region equivalent to
 \<blockquote\>foo\<br\>bar\<br\>baz\</blockquote\>:
 - Select \"bar\", do \"ol\":

 Word/OO/Firefox/Chrome
 : Increase indent, add \"1\".

 IE
 : Increase indent of everything, add \"a\" before \"foo\". If you
 do \<blockquote\>\<p\>foo\<p\>bar\<p\>baz\</blockquote\>, same
 as Word/OO/Firefox/Chrome.

 Opera
 : Don\'t increase indent of anything, add \"1\" before \"bar\".
- In an existing multi-line indented region equivalent to
 \<blockquote\>foo\<br\>bar\</blockquote\>baz:
 - Select \"barbaz\", do \"ol\":

 Word
 : Indent both, add \"a\" before \"bar\" and \"2\" before \"baz\".

 OO
 : Indent \"baz\", add \"1\" before \"bar\" and \"2\" before
 \"baz\".

 IE
 : Indent everything, add \"a\" before \"foo\" and \"1\" before
 \"baz\". If you do
 \<blockquote\>\<p\>foo\<p\>bar\</blockquote\>\<p\>baz, indent
 \"bar\" and \"baz\" and put \"1\" before each.

 Firefox
 : Indent \"bar\" and put \"1\" before it, put \"baz\" after
 \"bar\" on the same line. If you do
 \<blockquote\>\<p\>foo\<p\>bar\</blockquote\>\<p\>baz, same as
 Chrome.

 Chrome
 : Indent \"bar\" once and \"baz\" twice, put \"1\" before \"bar\"
 and \"2\" before \"baz\".

 Opera
 : Put a \"1\" before \"bar\" and move \"baz\" to the same line. If
 you do \<blockquote\>\<p\>foo\<p\>bar\</blockquote\>\<p\>baz,
 indent \"baz\", put a \"1\" before \"bar\" and a \"2\" before
 \"baz\".
 - Select \"bar\", do \"ol\", then select \"baz\" and do \"ol\":

 Word/OO/Opera
 : Different from if you do both together.

 IE
 : Different with \<br\>, same with \<p\>.

 Firefox
 : Three behaviors, depending on whether you do it in one step with
 \<br\>, one step with \<p\>, or two steps with either (same
 behavior regardless with two steps).

 Chrome
 : Same behavior in all four cases.
- \<blockquote\>foo\<ol\>\<li\>bar\</ol\>\</blockquote\>baz:
 - Select \"baz\", do \"ol\":

 Word/OO/Chrome
 : Add \"baz\" as a new item to existing list.

 IE/Firefox/Opera
 : Make \"baz\" its own new list.
- \<ul\>\<li\>foo\</li\>\<ol\>\<li\>bar\</li\>\</ol\>\</ul\>baz:
 - Select \"baz\", do \"ol\":

 IE/Firefox/Chrome/Opera
 : Separate list.

Ignoring the conceptual model of HTML, which users won\'t understand,
here\'s the conceptual model I\'ve developed for lists: text is divided
up into blocks. Each block has an indentation level and a list marker
type. The list marker type can be either nothing, ordered, or unordered.
A list block cannot have indentation level less than one. Any given
piece of text is part of only one block. A block may be visually
non-contiguous, such as if a single list block is interrupted by a
further-indented block.

To find the right number (or letter) for an ordered-list block, look at
the immediately preceding block, but skip over any blocks of higher
indentation level. If there is no immediately preceding block, or it\'s
not an ordered-list block, or it has a lower indentation level, the
number is 1 (or a, i, etc.). Otherwise, it\'s the number of the
preceding block plus one.

ol/ul commands change the selected block to that list marker type, or
remove the list marker type if it\'s already the chosen type. If the
block has indentation level zero, it increases to one.

indent/outdent commands change the selected block\'s indentation level.
If a list block\'s indentation level is reduced to zero, it\'s converted
to a regular block.

What this means from an HTML perspective, roughly:

- A list block is the entire contents of an \<li\> element, ignoring any
 nested list elements or indentation elements. A non-list block is a
 line box.
- Indentation level is equal to the number of ancestor elements that are
 either \<li\>s or indentation elements (blockquotes or indenting
 divs).
- To find the list marker type, go to the first ancestor that\'s either
 an \<li\> or indentation element.
- Correct numbering should automatically follow from the way \<ol\>
 works in HTML (which is one of the reasons I use this model).
- An ol command in an ordered-list block removes the surrounding \<li\>,
 migrating its contents into the parent of the \<ol\>. This splits up
 the \<ol\> if it\'s not the first or last child, and wraps the
 contents in a new \<li\> if necessary. If there\'s another list or
 indentation element nested in the \<li\> we\'re removing, it will get
 re-wrapped in a new \<ol\>, outside the newly-created \<li\>, so that
 it maintains its indentation. This might cause the new \<li\> to wind
 up in multiple pieces, if the original block was not contiguous, which
 means the non-contiguous block is split into several blocks (with
 different numbers).
- An ol command in an unordered-list block breaks up the parent \<ul\>
 and puts a new \<ol\> in between the two pieces, moving the parent
 \<li\> into it. If the \<li\> was the first or last child, we merge
 with an existing adjacent \<ol\> if possible. All children stay as
 they are.
- An ol command in a non-list block with indentation zero wraps it in a
 new \<ol\>\<li\>, or merges with an adjacent \<ol\> if possible.
- An ol command in a non-list block with nonzero indentation converts
 the parent to an \<ol\>\<li\>, breaking it up if necessary.
- The ul command works similarly to ol.
- indent in a non-list block wraps in an indentation element. In a list
 block, it wraps the \<li\> in an extra \<ol\> or \<ul\> as
 appropriate. With merging. Whatever. Let me just write the spec.
- outdent in a non-list block strips an indentation element, if one is
 present. In a list block, it breaks apart the parent \<ol\> or \<ul\>
 and makes the affected block a sibling in between the newly-split list
 elements. Will create new \<li\>s, etc. etc.

Sheesh, lists are complicated.

To [toggle lists], given a string
`tag name` (either \"ol\" or \"ul\"):

1. Let `mode` be \"disable\" if the [selection\'s
 list state](#selection's-list-state) is `tag name`, and \"enable\" otherwise.

2. Let `other tag name` be \"ol\" if
 ` tag name` is \"ul\", and \"ul\" if
 `tag name` is \"ol\".

3. Let `items` be a list of all \[\^li\^\]s that
 are \[=tree/inclusive ancestors=\] of the [active
 range](#active-range)\'s \[=range/start=\] and/or \[=range/end=\]
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node").

4. TODO: This overnormalizes, but it seems like the simplest solution
 for now.

 For each `item` in `items`,
 [normalize sublists](#normalize-sublists) of `item`.

5. [Block-extend](#block-extend) the [active range](#active-range), and
 let `new range` be the result.

6. If `mode` is \"enable\", then let
 ` lists to convert` consist of every
 [editable](#editable) [HTML element](#html-element) with
 \[=Element/local name=\] `other tag name` that
 is [contained](http://dom.spec.whatwg.org/#contained) in `new range`, and for every
 `list` in `lists to convert`:
 1. Convert it to the right name. If possible, we want to merge with
 a neighboring list of the correct type. Failing that, we set the
 tag name.

 If `list`\'s {{Node/ previousSibling}} or
 {{Node/nextSibling}} is an [editable](#editable) [HTML
 element](#html-element) with \[=Element/local name=\]
 `tag name`:

 1. Let `children` be `list`\'s \[=tree/children=\].
 2. [Record the values](#record-the-values) of
 `children`, and let `values` be the result.
 3. [Split the parent](#split-the-parent) of
 `children`.
 4. [Wrap](#wrap) `children`, with
 `sibling criteria` returning true for an
 [HTML element](#html-element) with \[=Element/local name=\]
 `tag name` and false otherwise.
 5. [Restore the values](#restore-the-values) from
 `values`.

 2. Otherwise, [set the tag name](#set-the-tag-name) of
 `list` to `tag name`.

7. Let `node list` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.

8. ::: note
 We exclude indentation elements so that selecting some random text
 and doing indent followed by insertOrderedList will have the same
 result as the reverse. Specifically,

 <blockquote>[foo]</blockquote> ->
 <blockquote><ol><li>[foo]</li></ol></blockquote>

 per spec and Firefox 4.0 and (more or less) Chrome 12 dev. Opera
 11.10 instead does \<ol\>\<li\>foo\</li\>\</ol\>, so the indentation
 vanishes. IE9 does \<ol\>\<ol\>\<li\>foo\</li\>\</ol\>\</ol\>, but
 that doesn\'t make semantic sense and is different from how it would
 work if you reversed the commands. OpenOffice.org 3.2.1 (Ubuntu) and
 Word 2007 both agree with the spec in this case.
 :::

 For each
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node`
 [contained](http://dom.spec.whatwg.org/#contained) in `new range`, if
 `node` is [editable](#editable); the last member
 of `node list` (if any) is not an
 \[=tree/ancestor=\] of `node`; `node` is not an [indentation element](#indentation-element); and
 either `node` is an \[\^ol\^\] or \[\^ul\^\], or
 its \[=tree/parent=\] is an \[\^ol\^\] or \[\^ul\^\], or it is an
 [allowed child](#allowed-child) of \"li\"; then append
 `node` to `node list`.

9. ::: note
 We don\'t want to touch these. E.g., assuming tag name is \"ol\",

 [foo<ol><li>bar</ol>baz]
 -> <ol><li>[foo<li>bar<li>baz]</ol>
 not <ol><li>[foo</li><ol><li>bar</ol><li>baz]</ol>.

 But

 <ul><li>foo<li>[bar</li><ol><li>baz</ol><li>quz]</ul>
 -> <ul><li>foo</ul><ol><li>[bar</li><ol><li>baz</ol><li>quz]</ol>
 not <ul><li>foo</ul><ol><li>[bar</ol><ul><ol><li>baz</ol></ul><ol><li>quz]</ol>
 :::

 If `mode` is \"enable\", remove from
 `node list` any \[\^ol\^\] or \[\^ul\^\] whose
 \[=tree/parent=\] is not also an \[\^ol\^\] or \[\^ul\^\].

10. If `mode` is \"disable\", then while
 `node list` is not empty:
 1. Let `sublist` be an empty list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node").
 2. Remove the first member from `node list` and
 append it to `sublist`.
 3. If the first member of `sublist` is an [HTML
 element](#html-element) with \[=Element/local name=\]
 `tag name`, [outdent](#outdent) it and
 continue this loop from the beginning.
 4. While `node list` is not empty, and the
 first member of `node list` is the
 {{Node/nextSibling}} of the last member of `sublist` and is not an [HTML element](#html-element) with
 \[=Element/local name=\] `tag name`, remove
 the first member from `node list` and append
 it to `sublist`.
 5. [Record the values](#record-the-values) of `sublist`, and let `values` be the result.
 6. [Split the parent](#split-the-parent) of `sublist`.
 7. [Fix disallowed ancestors](#fix-disallowed-ancestors) of each
 member of `sublist`.
 8. [Restore the values](#restore-the-values) from
 `values`.

11. Otherwise, while `node list` is not empty:
 1. Let `sublist` be an empty list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node").

 2. Accumulate consecutive sibling nodes in sublist, first
 converting them all to li\'s (except if they\'re already lists).

 While either `sublist` is empty, or
 `node list` is not empty and its first
 member is the {{Node/nextSibling}} of `sublist`\'s last member:

 1. Thus \<p\>foo\</p\> becomes \<ol\>\<li\>foo\</ol\> instead
 of \<ol\>\<li\>\<p\>foo\</ol\>, and likewise for div, but
 other things will be put inside the \<li\>.

 If `node list`\'s first member is a
 \[\^p\^\] or \[\^div\^\], [set the tag
 name](#set-the-tag-name) of `node list`\'s first member to \"li\", and append the result
 to `sublist`. Remove the first member
 from `node list`.

 2. Otherwise, if the first member of `node list` is an \[\^li\^\] or \[\^ol\^\] or \[\^ul\^\],
 remove it from `node list` and append it
 to ` sublist`.

 3. Otherwise:
 1. Let `nodes to wrap` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.
 2. While `nodes to wrap` is empty, or
 `node list` is not empty and its
 first member is the {{Node/ nextSibling}} of
 `nodes to wrap`\'s last member and
 the first member of `node list` is
 an [inline node](#inline-node) and the last member of
 `nodes to wrap` is an [inline
 node](#inline-node) other than a \[\^br\^\], remove the
 first member from `node list` and
 append it to `nodes to wrap`.
 3. [Wrap](#wrap) `nodes to wrap`, with
 `new parent instructions` returning
 the result of calling ` `[`createElement("li")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object). Append the result to
 `sublist`.

 3. In this case it\'s already wrapped properly, nothing more to do.

 If `sublist`\'s first member\'s
 \[=tree/parent=\] is an [HTML element](#html-element) with
 \[=Element/local name=\] `tag name`, or if
 every member of `sublist` is an \[\^ol\^\]
 or \[\^ul\^\], continue this loop from the beginning.

 4. If `sublist`\'s first member\'s
 \[=tree/parent=\] is an [HTML element](#html-element) with
 \[=Element/local name=\] `other tag name`:
 1. [Record the values](#record-the-values) of
 `sublist`, and let `values` be the result.
 2. [Split the parent](#split-the-parent) of `sublist`.
 3. [Wrap](#wrap) `sublist`, with
 `sibling criteria` returning true for an
 [HTML element](#html-element) with \[=Element/local name=\]
 `tag name` and false otherwise, and
 `new parent instructions` returning the
 result of calling [`createElement(``tag name``)`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object).
 4. [Restore the values](#restore-the-values) from
 `values`.
 5. Continue this loop from the beginning.

 5. [Wrap](#wrap) `sublist`, with
 `sibling criteria` returning true for an
 [HTML element](#html-element) with \[=Element/local name=\]
 `tag name` and false otherwise, and
 `new parent instructions` being the
 following:
 1. ::: note
 Special case: something like

 <ol><li>foo</ol><blockquote>[bar]</blockquote>

 becomes

 <ol><li>foo</li><ol><li>[bar]</ol></ol>

 instead of

 <ol><li>foo</ol><blockquote><ol><li>[bar]</ol></blockquote>.

 We handle the special case in
 `new parent instructions` instead of
 outside because we\'d prefer to wind up in a sibling if
 there is one. We handle only previousSibling, not
 nextSibling, because we really mean for this to cover
 something like

 [foo<blockquote>bar]</blockquote>

 which we\'ll handle node-by-node. TODO: Maybe we should do
 this differently, like just special-case simple indentation
 elements in an earlier part of the algorithm? This way\'s a
 bit weird.
 :::

 If `sublist`\'s first member\'s
 \[=tree/parent=\] is not an [editable](#editable) [simple
 indentation element](#simple-indentation-element), or
 `sublist`\'s first member\'s
 \[=tree/parent=\]\'s {{Node/ previousSibling}} is not an
 [editable](#editable) [HTML element](#html-element) with
 \[=Element/local name=\] `tag name`,
 call [`createElement(``tag name``)`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and return the result.

 2. Let `list` be `sublist`\'s first member\'s \[=tree/parent=\]\'s {{Node/
 previousSibling}}.

 3. [Normalize sublists](#normalize-sublists) of
 `list`\'s {{Node/ lastChild}}.

 4. If `list`\'s {{Node/ lastChild}} is not
 an [editable](#editable) [HTML element](#html-element) with
 \[=Element/local name=\] `tag name`,
 call [`createElement(``tag name``)`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object), and append the result as the last
 \[=tree/child=\] of `list`.

 5. Return the last \[=tree/child=\] of `list`.

 6. [Fix disallowed ancestors](#fix-disallowed-ancestors) of the
 previous step\'s result.

### Justifying the selection

This is the [action](#action) for the four `justify*`{title=""}
commands. It\'s pretty straightforward, with no notable gotchas or
special cases. It works more or less like a stripped-down version of
[set the selection\'s value](#set-the-selection's-value), except it gets
to be much simpler because it\'s much less general. (It\'s not similar
enough to just invoke that algorithm: too many things differ between
block and inline elements.)

There are two basic ways this works in browsers: using the align
attribute, and using CSS text-align. IE9 and Opera 11.11 use only the
align attribute, Chrome 13 dev uses only text-align, and Firefox 5.0a2
varies based on styleWithCSS. The two ways produce entirely different
results, which is a real problem, so I don\'t think Firefox\'s approach
is tenable. text-align is more valid, and for typical contenteditable
cases it works the same. But for cases where you have fixed-width
blocks, like tables or just divs with a width set, it behaves
differently, and in those cases the align attribute is more useful.

TODO: text-align doesn\'t behave as expected if there are descendant
blocks with non-100% width, like tables. The align attribute behaves a
lot more nicely in such cases, but it\'s not valid. Not clear what to
do. For now I\'ve stuck with text-align, just because the cases where it
misbehaves can\'t be created by any sequence of stock execCommand()s
that I know of, but this needs more careful consideration. Gecko in CSS
mode seems to special-case tables, adding auto margins to the table
element to get it to align correctly.

TODO: We could do something along the lines of pushing down values here,
although no browser does. In fact, it\'s very likely this can be
rewritten in terms of the inline formatting command primitives, but
it\'s not clear if it would be worth the added complexity.

To [justify the selection] to a string
`alignment` (either \"center\", \"justify\",
\"left\", or \"right\"):

1. [Block-extend](#block-extend) the [active range](#active-range), and
 let `new range` be the result.

2. No browser actually removes center, but it makes sense to do so.

 Let `element list` be a list of all
 [editable](#editable) {{Element}}s
 [contained](http://dom.spec.whatwg.org/#contained) in `new range` that either
 has an attribute in the [HTML
 namespace](http://dom.spec.whatwg.org/#html-namespace) whose \[=Attr/local name=\] is \"align\", or has
 a ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute that sets \"text-align\", or is a ` `[`center`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#center).

3. For each `element` in `element list`:
 1. If `element` has an attribute in the [HTML
 namespace](http://dom.spec.whatwg.org/#html-namespace) whose \[=Attr/local name=\] is \"align\",
 remove that attribute.
 2. Unset the CSS property \"text-align\" on `element`, if it\'s set by a ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute.
 3. If `element` is a \[\^div\^\] or
 \[\^span\^\] or ` `[`center`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#center)
 with no attributes, remove it, [preserving its
 descendants](#preserving-its-descendants).
 4. If `element` is a ` `[`center`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#center)
 with one or more attributes, [set the tag
 name](#set-the-tag-name) of `element` to
 \"div\".

4. This could theoretically be necessary, like if it converted \"\<div
 align=right\>foo\</div\>bar\" to \"foo\<br\>bar\". Now we need to
 select \"foo\<br\>\", nor just \"foo\".

 [Block-extend](#block-extend) the [active range](#active-range), and
 let `new range` be the result.

5. Let `node list` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.

6. Of tested browsers, only Chrome 13 dev seems to not apply the
 alignment to nodes that are already aligned. Even then, it does
 apply it if the alignment is just inherited from the root.

 For each
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node`
 [contained](http://dom.spec.whatwg.org/#contained) in `new range`, append
 `node` to `node list` if the
 last member of `node list` (if any) is not an
 \[=tree/ancestor=\] of `node`; `node` is [editable](#editable); `node` is an
 [allowed child](#allowed-child) of \"div\"; and `node`\'s [alignment value](#alignment-value) is not
 `alignment`.

7. While `node list` is not empty:
 1. Let `sublist` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.

 2. Remove the first member of `node list` and
 append it to `sublist`.

 3. While `node list` is not empty, and the
 first member of `node list` is the
 {{Node/nextSibling}} of the last member of `sublist`, remove the first member of `node list` and append it to `sublist`.

 4. [Wrap](#wrap) `sublist`.
 `Sibling criteria` returns true for any
 \[\^div\^\] that has one or both of the following two attributes
 and no other attributes, and false otherwise:

 - An ` `[`align`](http://www.whatwg.org/specs/web-apps/current-work/multipage/obsolete.html#attr-div-align)
 attribute whose \[=Attr/value=\] is an [ASCII
 case-insensitive](http://dom.spec.whatwg.org/#ascii-case-insensitive) match for `alignment`.
 - A ` `[`style`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-style-attribute)
 attribute which sets exactly one CSS property (including
 unrecognized or invalid attributes), which is \"text-align\",
 which is set to `alignment`.

 As with inline formatting, I only ever create new elements, and
 don\'t ever modify existing ones. This doesn\'t match how any
 browser behaves in this case, but for inline formatting it
 matches everyone but Gecko\'s CSS mode, so I\'m just being
 consistent.

 `New parent instructions` are to call
 [`createElement("div")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object), then set its CSS property \"text-align\" to
 `alignment` and return the result.

### Automatic linking

[Bug 13807](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13807).

When the user inserts whitespace immediately following something that
looks like a URL or e-mail address, we automatically run [the
`createLink`{title=""} command](#the-createlink-command) on it.

An [autolinkable URL] is a string of the
following form:

1. IE9 and LibreOffice 3.3.4 both have a whitelist of URL schemes. That
 would be complicated and involve political decisions, so instead,
 we\'ll just accept anything that looks like a hierarchical URL
 scheme. Google Docs is similar (as of November 9, 2011), but it\'s
 too lax, and allows characters in the scheme that can\'t be in a
 scheme. For non-hierarchical schemes, we just whitelist mailto:,
 since it\'s the only common one that makes sense to autolink.

 Either a string matching the `scheme` pattern
 from [RFC 3986 section
 3.1](https://tools.ietf.org/html/rfc3986#section-3.1) followed by
 the literal string `://`{title=""}, or the literal string
 `mailto:`{title=""}; followed by

2. We don\'t try to enforce that the URL is anything resembling valid
 per spec. Too complicated for not enough gain.

 Zero or more characters other than [space
 characters](http://encoding.spec.whatwg.org/#ascii-whitespace "ascii whitespace"); followed by

3. ::: note
 If the user types a URL followed by some punctuation, we still want
 to autolink, but we don\'t want to include the punctuation if it\'s
 probably not meant as part of the URL.

 IE9 excludes `` !#&()*+,-.:;<=?@^_`{|}~ ``{title=""} as trailing
 characters from both URLs and e-mails. A trailing `"`{title=""} or
 `>`{title=""} will prevent autolinking, and a trailing
 `$%'/\`{title=""} is included in the link.

 LibreOffice 3.3.4 excludes trailing
 `` !”#'()*+,.:;<=>?[\]^_`{|}~ ``{title=""}, and prevents autolinking
 on `$%&-@`{title=""}. It includes a trailing `/`{title=""} in URLs,
 but it inhibits linking for e-mails.

 Google Docs (as of November 9, 2011) is complicated. Trailing
 `”’,-.`{title=""} always prevents autolinking of a URL, and trailing
 `#%/?_`{title=""} is always included in a URL. Trailing
 `` !&=$()*+:;<>@[\]^`{|}~ ``{title=""} prevent autolinking if
 there\'s no `?`{title=""} before them, but are included in the URL
 if there is a `?`{title=""}. For e-mails, `_`{title=""} is included,
 and everything else prevents autolinking.

 None of these behaviors makes maximal sense. We should exclude
 characters if they\'re more likely as delimiters than actual
 trailing characters; include them if they\'re more likely as actual
 trailing characters; and prevent autolinking if their presence
 suggests that we\'re not actually looking at a link or e-mail
 address. The lists I made up for URLs are: exclude trailing
 `` !"'(),-.:;<>` ``{title=""}, include anything else. For
 e-mail, exclude anything at all.
 :::

 A character that is not one of the ASCII characters
 `` !"'(),-.:;<>` ``{title=""}.

To [autolink] (`node`,
`end offset`):

1. While (`node`, `end offset`)\'s [previous equivalent
 point](#previous-equivalent-point) is not null, set it to its
 [previous equivalent point](#previous-equivalent-point).
2. If `node` is not a {{Text}} node, or has an
 \[\^a\^\] \[=tree/ancestor=\], do nothing and abort these steps.
3. Let `search` be the largest substring of
 `node`\'s {{CharacterData/ data}} whose end is
 `end offset` and that contains no [space
 characters](http://encoding.spec.whatwg.org/#ascii-whitespace "ascii whitespace").
4. If some substring of `search` is an
 [autolinkable URL](#autolinkable-url):
 1. While there is no substring of `node`\'s
 {{CharacterData/ data}} ending at `end offset` that is an [autolinkable URL](#autolinkable-url),
 decrement `end offset`.
 2. Let `start offset` be the start index of the
 longest substring of `node`\'s
 {{CharacterData/ data}} that is an [autolinkable
 URL](#autolinkable-url) ending at ` end offset`.
 3. Let `href` be the substring of
 `node`\'s {{CharacterData/data}} starting at
 `start offset` and ending at
 `end offset`.
5. Otherwise, if some substring of `search` is a
 [valid e-mail
 address](http://www.whatwg.org/specs/web-apps/current-work/multipage/states-of-the-type-attribute.html#valid-e-mail-address):
 1. While there is no substring of `node`\'s
 {{CharacterData/ data}} ending at `end offset` that is a [valid e-mail
 address](http://www.whatwg.org/specs/web-apps/current-work/multipage/states-of-the-type-attribute.html#valid-e-mail-address), decrement `end offset`.
 2. Let `start offset` be the start index of the
 longest substring of `node`\'s
 {{CharacterData/ data}} that is a [valid e-mail
 address](http://www.whatwg.org/specs/web-apps/current-work/multipage/states-of-the-type-attribute.html#valid-e-mail-address) ending at `end offset`.
 3. Let `href` be \"mailto:\" concatenated with
 the substring of `node`\'s
 {{CharacterData/data}} starting at `start offset` and ending at `end offset`.
6. Otherwise, do nothing and abort these steps.
7. Let `original range` be the [active
 range](#active-range).
8. Create a new \[=range=\] with \[=range/start=\] (`node`, `start offset`) and \[=range/end=\]
 (`node`, `end offset`), and
 set the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection")\'s \[=range=\]
 to it.
9. Take the [action](#action) for \"createLink\", with
 `value` equal to `href`.
10. Set the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection")\'s \[=range=\]
 to `original range`.

### [The `delete`{title=""} command]

This is the same as hitting backspace (see [Additional
requirements](#additional-requirements)). The easy part is if the
selection isn\'t collapsed: just [delete the
selection](#delete-the-selection). But it turns out rich-text editors
have a lot of special behaviors for hitting backspace with a collapsed
selection. Most obviously, if there\'s a text node right before the
cursor (maybe wrapped in some inline elements), we delete its last
character. But some of the special cases we run into are:

- [Invisible](#invisible) nodes are removed before anything else
 happens.
- An `<a>`{title=""} gets removed if you backspace while the cursor is
 right after it, so the link disappears.
- A `<br>`{title=""} or `<hr>`{title=""} or `<img>`{title=""} gets
 deleted.
- Backspacing at the start of most blocks merges with the previous
 block. (Visually, this is a matter of deleting a line break.)
- Backspacing at the start of an [indentation
 element](#indentation-element), or an `<li>`{title=""} or
 `<dt>`{title=""} or `<dd>`{title=""} that\'s at the beginning of a
 list, outdents the current block (rather than merging with the
 previous block).
- Backspacing at the start of a table cell does nothing.
- Backspacing immediately after a table selects the table, so a second
 backspace deletes it.
- Backspacing at the start of a list item that\'s not at the beginning
 of a list merges with the previous list item, but keeps the contents
 on a separate line, so you have to hit backspace a second time to get
 them on the same line.

[Preserves overrides](#preserves-overrides)

For all the deletions here, Firefox 7.0a2 will remove wrapper elements
like \<b\> only if they\'re selected, like {\<b\>foo\</b\>}. IE9, Chrome
14 dev, and Opera 11.50 will all remove them even if only their contents
are selected, like \<b\>\[foo\]\</b\>. Gecko\'s behavior in the latter
case leaves things like \<b\>\</b\> in the DOM, which is unhelpful, so
I don\'t.

[Action](#action):

1. If the [active range](#active-range) is not \[=range/collapsed=\],
 [delete the selection](#delete-the-selection) and return true.

2. Needed so that if there are multiple consecutive spaces we backspace
 over all at once.

 [Canonicalize whitespace](#canonicalize-whitespace) at the [active
 range](#active-range)\'s \[=range/start=\].

3. Let `node` and `offset` be
 the [active range](#active-range)\'s \[=range/start=\]
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") and \[=boundary point/offset=\].

4. First go up as high as possible within the current block, then drill
 down to the lowest possible level, in the hopes that we\'ll wind up
 at the end of a text node, or maybe in a br or hr.

 Repeat the following steps:

 1. If there\'s an invisible node somewhere, Firefox 5.0a2 removes
 that node and then stops, so each backspace removes one
 invisible node. All others remove the invisible node and then
 continue on looking for something visible to remove. The spec
 follows the latter behavior, since it makes more sense to the
 user. Of course, the definition of \"invisible node\" is not
 necessarily anything like the spec\'s.

 If `offset` is zero and `node`\'s {{Node/ previousSibling}} is an
 [editable](#editable) [invisible](#invisible)
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node"), remove `node`\'s {{Node/
 previousSibling}} from its \[=tree/parent=\].

 2. Otherwise, if `node` has a \[=tree/child=\]
 with \[=tree/index=\] `offset` − 1 and that
 \[=tree/child=\] is an [editable](#editable)
 [invisible](#invisible)
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node"), remove that \[=tree/child=\] from
 `node`, then subtract one from
 `offset`.

 3. Otherwise, if `offset` is zero and
 `node` is an [inline node](#inline-node), or
 if `node` is an [invisible](#invisible)
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node"), set `offset` to the
 \[=tree/index=\] of `node`, then set
 `node` to its \[=tree/parent=\].

 4. When backspacing a link, Firefox 7.0a2, Chrome 14 dev, Opera
 11.50, and OpenOffice.org 3.2.1 Ubuntu have no special behavior.
 IE9 and Word 2007 remove the link instead of deleting its last
 character. The latter behavior seems more useful and intuitive.

 Otherwise, if `node` has a \[=tree/child=\]
 with \[=tree/index=\] `offset` − 1 and that
 \[=tree/child=\] is an [editable](#editable) \[\^a\^\], remove
 that \[=tree/child=\] from `node`,
 [preserving its descendants](#preserving-its-descendants). Then
 return true.

 5. Otherwise, if `node` has a \[=tree/child=\]
 with \[=tree/index=\] `offset` − 1 and that
 \[=tree/child=\] is not a [block node](#block-node) or a
 \[\^br\^\] or an \[\^img\^\], set `node` to
 that \[=tree/child=\], then set `offset` to
 the \[=Node/length=\] of `node`.

 6. Otherwise, break from this loop.

5. ::: note
 At this point, node cannot be an invisible node. There are three
 cases:

 1. `offset` is zero and node is a block node.
 Then we\'ll usually merge with the previous block if one exists.
 2. `offset` is not zero, `node` is not a block node, and `node`
 does not have a child with index `offset`
 − 1. The only way this is possible is if node has a length
 greater than zero but no children, which implies it\'s a text or
 comment or PI. Comments and PIs are invisible nodes, so it must
 be a text node. We delete the previous character.
 3. `offset` is not zero, and the child of
 `node` with index `offset` − 1 is a block node or a br or an img. Then we\'ll
 usually merge the `offset`th child of
 `node` with the last descendant of the
 `offset` − 1st.

 Unlike forwardDelete, there\'s no special case for diacritics. This
 means backspacing will just delete the last combining diacritic
 typed, or the whole character if it\'s precomposed. This matches
 everything I tested (IE9, Firefox 7.0a2, Chrome 14 dev, etc.).
 :::

 If `node` is a {{Text}} node and
 `offset` is not zero, or if `node` is a [block node](#block-node) that has a \[=tree/child=\]
 with \[=tree/index=\] `offset` − 1 and that
 \[=tree/child=\] is a \[\^br\^\] or \[\^hr\^\] or \[\^img\^\]:

 1. Call
 [`collapse(`{title="dom-Selection-collapse"}`node``, `{title="dom-Selection-collapse"}`offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 2. Call [`extend(`{title="dom-Selection-extend"}`node``, `{title="dom-Selection-extend"}`offset`` − 1)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 3. [Delete the selection](#delete-the-selection).
 4. Return true.

6. At the time of this writing, this should be impossible. Just being
 safe.

 If `node` is an [inline node](#inline-node),
 return true.

7. If we\'re at the beginning of a list, we want to outdent the first
 list item. This doesn\'t actually match anyone or anything. Word
 2007 and OpenOffice.org 3.2.1 Ubuntu just remove the list marker,
 which is weird and doesn\'t map well to HTML. Browsers tend to just
 merge with the preceding block, which isn\'t expected.

 If `node` is an \[\^li\^\] or \[\^dt\^\] or
 \[\^dd\^\] and is the first \[=tree/child=\] of its
 \[=tree/parent=\], and `offset` is zero:

 1. Let `items` be a list of all \[\^li\^\]s
 that are \[=tree/ancestors=\] of `node`.

 2. [Normalize sublists](#normalize-sublists) of each
 `item` in `items`.

 3. [Record the values](#record-the-values) of the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `node`, and let `values` be the result.

 4. [Split the parent](#split-the-parent) of the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `node`.

 5. [Restore the values](#restore-the-values) from
 `values`.

 6. Annoying hack to prevent the dl from being re-added when fixing
 disallowed ancestors. In most cases we want a wrapper dl added,
 but in two cases (delete and insertParagraph) we\'re actually
 trying to outdent the list item. TODO: there might be a better
 way to do this.

 If `node` is a \[\^dd\^\] or \[\^dt\^\], and
 it is not an [allowed child](#allowed-child) of any of its
 \[=tree/ancestors=\] [in the same editing
 host](#in-the-same-editing-host), [set the tag
 name](#set-the-tag-name) of `node` to the
 [default single-line container
 name](#default-single-line-container-name) and let
 `node` be the result.

 7. [Fix disallowed ancestors](#fix-disallowed-ancestors) of
 `node`.

 8. Return true.

8. By this point, we\'re almost certainly going to merge something, and
 the only question is what.

 Let `start node` equal `node` and let `start offset` equal
 `offset`.

9. Repeat the following steps:
 1. If `start offset` is zero, set
 `start offset` to the \[=tree/index=\] of
 `start node` and then set
 `start node` to its \[=tree/parent=\].
 2. Otherwise, if `start node` has an
 [editable](#editable) [invisible](#invisible) \[=tree/child=\]
 with \[=tree/index=\] `start offset` minus
 one, remove it from `start node` and
 subtract one from `start offset`.
 3. Otherwise, break from this loop.

10. At the beginning of an indented block, outdent it, similar to a list
 item. Browsers don\'t do this, word processors do. Note: this
 copy-pastes from the outdent command action.

 If `offset` is zero, and `node` has an [editable](#editable) \[=tree/inclusive ancestor=\]
 [in the same editing host](#in-the-same-editing-host) that\'s an
 [indentation element](#indentation-element):

 1. [Block-extend](#block-extend) the \[=range=\] whose
 \[=range/start=\] and \[=range/end=\] are both (`node`, 0), and let `new range` be the
 result.
 2. Let `node list` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.
 3. For each
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") `current node`
 [contained](http://dom.spec.whatwg.org/#contained) in `new range`, append
 `current node` to `node list` if the last member of `node list`
 (if any) is not an \[=tree/ancestor=\] of
 `current node`, and `current node` is [editable](#editable) but has no
 [editable](#editable) \[=tree/descendants=\].
 4. [Outdent](#outdent) each
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") in `node list`.
 5. Return true.

11. ::: note
 This is to avoid stripping a line break from

 foo<br><br><table><tr><td>bar</table>

 and similarly for \<hr\>. We should just do nothing here.
 :::

 If the \[=tree/child=\] of `start node` with
 \[=tree/index=\] `start offset` is a
 \[\^table\^\], return true.

12. If you try backspacing into a table, select it. This doesn\'t match
 any browser; it matches the recommendation of the \"behavior when
 typing in contentEditable elements\" document. The idea is that then
 you can delete it with a second backspace.

 If `start node` has a \[=tree/child=\] with
 \[=tree/index=\] `start offset` − 1, and that
 \[=tree/child=\] is a \[\^table\^\]:

 1. Call
 [`collapse(`{title="dom-Selection-collapse"}`start node``, `{title="dom-Selection-collapse"}`start offset`` − 1)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 2. Call
 [`extend(`{title="dom-Selection-extend"}`start node``, `{title="dom-Selection-extend"}`start offset``)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 3. Return true.

13. ::: note
 Special case:

 <p>foo</p><br><p>bar</p>
 -> <p>foo</p><p>bar</p>

 and likewise for \<hr\>. But with \<img\> we merge like in other
 cases:

 <p>foo</p><img><p>bar</p>
 -> <p>foo</p><img>bar.

 Browsers don\'t do this consistently. Firefox 5.0a2 doesn\'t seem to
 do it at all.
 :::

 If `offset` is zero; and either the
 \[=tree/child=\] of `start node` with
 \[=tree/index=\] `start offset` minus one is an
 \[\^hr\^\], or the \[=tree/child=\] is a \[\^br\^\] whose
 {{Node/previousSibling}} is either a \[\^br\^\] or not an [inline
 node](#inline-node):

 1. Call
 [`collapse(`{title="dom-Selection-collapse"}`start node``, `{title="dom-Selection-collapse"}`start offset`` − 1)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 2. Call
 [`extend(`{title="dom-Selection-extend"}`start node``, `{title="dom-Selection-extend"}`start offset``)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 3. [Delete the selection](#delete-the-selection).
 4. Call
 [`collapse(`{title="dom-Selection-collapse"}`node``, `{title="dom-Selection-collapse"}`offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [selection](#concept-selection "concept-selection").
 5. Return true.

14. ::: note
 If you try backspacing out of a list item, merge it with the
 previous item, but add a line break. Then you have to backspace
 again if you really want them to be on the same line. This matches
 Word 2007 and OpenOffice.org 3.2.1 Ubuntu, and also matches
 \"behavior when typing in contentEditable elements\", but does not
 match any browser.

 Note that this behavior is quite different from what happens if you
 actually select the linebreak in between the two lines. In that
 case, the blocks are merged as normal.

 Also note that hitting backspace twice will merge with the previous
 item. This matches OO.org, but Word will outdent the item on
 subsequent backspaces. Word\'s behavior doesn\'t fit well with the
 way lists work in HTML, and we probably don\'t want it.
 :::

 If the \[=tree/child=\] of `start node` with
 \[=tree/index=\] `start offset` is an \[\^li\^\]
 or \[\^dt\^\] or \[\^dd\^\], and that \[=tree/child=\]\'s
 {{Node/firstChild}} is an [inline node](#inline-node), and
 `start offset` is not zero:

 1. Let `previous item` be the \[=tree/child=\]
 of `start node` with \[=tree/index=\]
 `start offset` minus one.

 2. If the last child is already a br, we only need to append one
 extra br. Otherwise we need to append two, since the first will
 do nothing.

 If `previous item`\'s {{Node/lastChild}} is
 an [inline node](#inline-node) other than a \[\^br\^\], call
 [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and append the result as the last
 \[=tree/child=\] of `previous item`.

 3. If `previous item`\'s {{Node/lastChild}} is
 an [inline node](#inline-node), call
 [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and append the result as the last
 \[=tree/child=\] of `previous item`.

15. When merging adjacent list items, make sure we only merge the items
 themselves, not any block children. We want
 `<li><p>foo<li><p>bar`{title=""} to become
 `<li><p>foo<p>bar`{title=""}, not `<li><p>foo<br>bar`{title=""}
 or `<li><p>foobar`{title=""}. To do the deletion, we need to wipe
 out the current selection, so we save it as a range. Saving it as a
 node/offset pair isn\'t enough, because it might be invalid after we
 do the deletion. A range will update according to the range mutation
 rules.

 If `start node`\'s \[=tree/child=\] with
 \[=tree/index=\] `start offset` is an \[\^li\^\]
 or \[\^dt\^\] or \[\^dd\^\], and that \[=tree/child=\]\'s
 {{Node/previousSibling}} is also an \[\^li\^\] or \[\^dt\^\] or
 \[\^dd\^\]:

 1. Call [`cloneRange()`](http://dom.spec.whatwg.org/#dom-range-clonerange)
 on the [active range](#active-range), and let
 `original range` be the result.
 2. Set `start node` to its \[=tree/child=\]
 with \[=tree/index=\] `start offset` − 1.
 3. Set `start offset` to `start node`\'s \[=Node/length=\].
 4. Set `node` to `start node`\'s {{Node/nextSibling}}.
 5. Call
 [`collapse(`{title="dom-Selection-collapse"}`start node``, `{title="dom-Selection-collapse"}`start offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 6. Call [`extend(`{title="dom-Selection-extend"}`node``, 0)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 7. [Delete the selection](#delete-the-selection).
 8. Call
 [`removeAllRanges()`{title="dom-Selection-removeAllRanges"}](#dom-selection-removeallranges)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 9. Call
 [`addRange(`{title="dom-Selection-addRange"}`original range``)`{title="dom-Selection-addRange"}](#dom-selection-addrange)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 10. Return true.

16. General block-merging case.

 While `start node` has a \[=tree/child=\] with
 \[=tree/index=\] `start offset` minus one:

 1. If `start node`\'s \[=tree/child=\] with
 \[=tree/index=\] `start offset` minus one is
 [editable](#editable) and [invisible](#invisible), remove it
 from `start node`, then subtract one from
 `start offset`.
 2. Otherwise, set `start node` to its
 \[=tree/child=\] with \[=tree/index=\] `start offset` minus one, then set `start offset`
 to the \[=Node/length=\] of `start node`.

17. Call
 [`collapse(`{title="dom-Selection-collapse"}`start node``, `{title="dom-Selection-collapse"}`start offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

18. Call [`extend(`{title="dom-Selection-extend"}`node``, `{title="dom-Selection-extend"}`offset``)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

19. [Delete the selection](#delete-the-selection), with
 `direction` \"backward\".

20. Return true.

### [The `formatBlock`{title=""} command]

This command lets you change what block element particular lines are
wrapped in. It will convert an existing wrapper if one exists, and
otherwise will create a new one.

A [formattable block name] is \"address\",
\"dd\", \"div\", \"dt\", \"h1\", \"h2\", \"h3\", \"h4\", \"h5\", \"h6\",
\"p\", or \"pre\".

Tested browser versions: IE9, Firefox 4.0, Chrome 13 dev, Opera 11.10.

Firefox and Chrome will replace a \<blockquote\> by a \<p\> or other
given tag. IE and Opera will nest the \<p\> inside instead. The latter
makes more sense, given that a) we don\'t support formatBlock with
\<blockquote\> and b) \<blockquote\>s are logically different, since
they can contain many lines.

Firefox will not convert other tags like \<p\> to \<div\>, it will only
wrap unwrapped lines in a \<div\>. Firefox also won\'t replace \<div\>
by things like \<p\>, it will nest the \<p\> inside. The spec follows
other browsers.

If you try to convert a \<dt\> to a \<div\> or \<p\> or such, Firefox
breaks out of the \<dl\> entirely, leaving
\...\<dt\>\<br\>\</dt\>\</dl\>. Chrome will convert a \<dt\> or \<dd\>
to the given element, leaving a \<div\> or \<p\> or such as the child of
a \<dl\>. I follow IE/Opera, which only affect the contents of
\<dt\>/\<dd\> (Firefox behaves this way for \<dd\> as well, just not
\<dt\>). This means you can get invalid DOMs like
\<dt\>\<p\>foo\<p\>\</dt\>, but they can be serialized as text/html, so
I\'m not too fussy.

When it comes to \<li\>, IE/Opera behave like with \<dt\>/\<dd\>, which
is how I behave too. Firefox apparently refuses to do anything. Chrome
tries to wrap the parent list element, breaking it up if only some of
the children are selected; this produces unserializable DOMs if you\'re
wrapping with \<p\>.

When you\'re converting multiple blocks at once, Chrome replaces them
all by one block with \<br\> stuck in, like \<p\>foo\</p\>\<p\>bar\</p\>
-\> \<div\>foo\<br\>bar\</div\>. It wipes out intervening block
containers too in some cases. This might make sense for
\<address\>/\<h\*\>/\<pre\>, but other browsers don\'t do it.

[Preserves overrides](#preserves-overrides)

[Action](#action):

1. IE9 requires the brackets. If they\'re not provided, it does
 nothing.

 If `value` begins with a \"\<\" character and
 ends with a \"\>\" character, remove the first and last characters
 from it.

2. Let `value` be [converted to ASCII
 lowercase](http://dom.spec.whatwg.org/#converted-to-ascii-lowercase).

3. ::: note
 Opera 11.10 throws NOT_SUPPORTED_ERR for bad elements, all other
 tested browsers ignore the input. Testing in IE9, Firefox 4.0,
 Chrome 13 dev, and Opera 11.10, supported elements seem to be:

 Everyone
 : address, div, h\*, p, pre

 Everyone but IE
 : blockquote

 Everyone but Opera
 : dd, dt

 IE only
 : dir, menu, ol, ul

 Firefox and Chrome only
 : dl

 Chrome only
 : article, aside, footer, header, hgroup, nav, section

 HTML5 as of May 2011 supports: address, article, aside, blockquote,
 div, footer, h\*, header, hgroup, nav, p, pre, section, which
 exactly matches Chrome except minus dd/dt/dl.

 See [mailing list
 discussion](http://lists.whatwg.org/htdig.cgi/whatwg-whatwg.org/2011-May/031765.html)
 on the subject.
 :::

 If `value` is not a [formattable block
 name](#formattable-block-name), return false.

4. [Block-extend](#block-extend) the [active range](#active-range), and
 let `new range` be the result.

5. Let `node list` be an empty list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node").

6. For each
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node`
 [contained](http://dom.spec.whatwg.org/#contained) in `new range`, append
 `node` to `node list` if it
 is [editable](#editable), the last member of
 `original node list` (if any) is not an
 \[=tree/ancestor=\] of `node`, `node` is either a [non-list single-line
 container](#non-list-single-line-container) or an [allowed
 child](#allowed-child) of \"p\" or a \[\^dd\^\] or \[\^dt\^\], and
 `node` is not the \[=tree/ancestor=\] of a
 [prohibited paragraph child](#prohibited-paragraph-child).

7. [Record the values](#record-the-values) of `node list`, and let `values` be the result.

8. This tries to avoid misnesting if only some lines of an element are
 selected, so \<h1\>\[foo\]\<br\>bar\</h1\> becomes
 \<p\>\[foo\]\</p\>\<h1\>bar\</h1\> instead of
 \<h1\>\<p\>\[foo\]\</p\>\<br\>bar\</h1\> or such. It tries to
 heuristically distinguish between divs used as line-breakers and
 divs used as actual wrappers by checking if they have prohibited
 paragraph children as descendants. It works for address too, in case
 there are paragraphs nested inside. Thus
 \<address\>\[foo\]\<br\>bar\</address\> becomes
 \<p\>\[foo\]\</p\>\<address\>bar\</address\>, but
 \<address\>\[foo\]\<p\>bar\</p\>\</address\> becomes
 \<address\>\<p\>\[foo\]\</p\>\<p\>bar\</p\>\</address\>. Likewise,
 we don\'t break things out of lists or tables or such if they happen
 to be nested in a \<div\>.

 For each `node` in `node list`, while `node` is the
 \[=tree/descendant=\] of an [editable](#editable) [HTML
 element](#html-element) [in the same editing
 host](#in-the-same-editing-host), whose \[=Element/local name=\] is
 a [formattable block name](#formattable-block-name), and which is
 not the \[=tree/ancestor=\] of a [prohibited paragraph
 child](#prohibited-paragraph-child), [split the
 parent](#split-the-parent) of the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `node`.

9. [Restore the values](#restore-the-values) from `values`.

10. ::: note
 We have two different behaviors, one for div and p and one for
 everything else. The basic difference is that for div and p, we
 assume that it should be one line per element, while for other
 elements, we put in multiple lines separated by \<br\>. So if you do
 formatBlock to p on

 <div>foo</div><div>bar</div>

 or

 foo<br>bar

 you get

 <p>foo</p><p>bar</p>

 but formatBlock to h1 will get you

 <h1>foo<br>bar</h1>.

 IE9 will just change the elements as they are, so it gives
 \<p\>foo\</p\>\<p\>bar\</p\> and \<h1\>foo\</h1\>\<h1\>bar\</h1\>
 for \<div\>foo\</div\>\<div\>bar\</div\>, but
 \<p\>foo\<br\>bar\</p\> and \<h1\>foo\<br\>bar\</h1\> for
 foo\<br\>bar. This is unreasonable, because the two possible inputs
 here look identical to the user and might have been produced by
 identical user input.

 Firefox 5.0a2 will give results like \<p\>foo\</p\>\<p\>bar\</p\> or
 \<h1\>foo\</h1\>\<h1\>bar\</h1\> no matter what (modulo oddities in
 its handling of divs). Opera 11.10 is similar, except it leaves a
 trailing \<br\> in the first element.

 Chrome 13 dev will give results like \<p\>foo\<br\>bar\</p\> or
 \<h1\>foo\<br\>bar\</h1\> no matter what.

 The specced behavior is a compromise between the existing behaviors,
 predicated on the fact that \<h1\>foo\</h1\>\<h1\>bar\</h1\> almost
 never makes sense, and \<p\>foo\<br\>bar\</p\> isn\'t usually
 what\'s wanted either.
 :::

 While `node list` is not empty:

 1. If the first member of `node list` is a
 [single-line container](#single-line-container):
 1. ::: note
 If you try to format a single-line container with no
 children, IE10PP2 inserts an nbsp before formatting. (It
 uses nbsp instead of \<br\> to make blocks not collapse, so
 the equivalent for us would be to insert a \<br\>.) Firefox
 7.0a2 and Opera 11.50 make the element disappear. Chrome 14
 dev leaves it alone and doesn\'t format it. I follow
 Firefox/Opera just because it\'s the simplest given how I
 happen to have written the spec, and it\'s a corner case, so
 exact behavior isn\'t important.

 For blocks that contain only a collapsed whitespace node,
 IE10PP2 and Firefox 7.0a2 convert them like normal. Chrome
 14 dev and Opera 11.50 leave it alone and don\'t format it.
 I go with the majority, which is again simpler to spec.
 :::

 Let `sublist` be the \[=tree/children=\]
 of the first member of `node list`.

 2. [Record the values](#record-the-values) of
 `sublist`, and let `values` be the result.

 3. Remove the first member of `node list`
 from its \[=tree/parent=\], [preserving its
 descendants](#preserving-its-descendants).

 4. [Restore the values](#restore-the-values) from
 `values`.

 5. Remove the first member from `node list`.
 2. Otherwise:
 1. Let `sublist` be an empty list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node").
 2. Remove the first member of `node list`
 and append it to `sublist`.
 3. While `node list` is not empty, and the
 first member of `node list` is the
 {{Node/ nextSibling}} of the last member of
 `sublist`, and the first member of
 `node list` is not a [single-line
 container](#single-line-container), and the last member of
 `sublist` is not a \[\^br\^\], remove
 the first member of `node list` and
 append it to `sublist`.
 3. [Wrap](#wrap) `sublist`. If
 `value` is \"div\" or \"p\",
 `sibling criteria` returns false; otherwise
 it returns true for an [HTML element](#html-element) with
 \[=Element/local name=\] `value` and no
 attributes, and false otherwise.
 `New parent instructions` return the result
 of running [`createElement(``value``)`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object). Then [fix disallowed
 ancestors](#fix-disallowed-ancestors) of the result.

11. Return true.

Firefox 6.0a2 throws, Chrome 14 dev always returns false, Opera 11.11
doesn\'t support indeterm to start with, IE9 was uncooperative in
testing so I\'m not sure what it does. I\'m speccing it just because it
makes sense.

[Indeterminate](#indeterminate):

1. If the [active range](#active-range) is null, return the empty
 string.
2. [Block-extend](#block-extend) the [active range](#active-range), and
 let `new range` be the result.
3. Let `node list` be all [visible](#visible)
 [editable](#editable)
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") that are
 [contained](http://dom.spec.whatwg.org/#contained) in `new range` and have no
 \[=tree/children=\].
4. If `node list` is empty, return false.
5. Let `type` be null.
6. For each `node` in `node list`:
 1. While `node`\'s \[=tree/parent=\] is
 [editable](#editable) and [in the same editing
 host](#in-the-same-editing-host) as `node`,
 and `node` is not an [HTML
 element](#html-element) whose \[=Element/local name=\] is a
 [formattable block name](#formattable-block-name), set
 `node` to its \[=tree/parent=\].
 2. Let `current type` be the empty string.
 3. If `node` is an [editable](#editable) [HTML
 element](#html-element) whose \[=Element/local name=\] is a
 [formattable block name](#formattable-block-name), and
 `node` is not the \[=tree/ancestor=\] of a
 [prohibited paragraph child](#prohibited-paragraph-child), set
 `current type` to ` node`\'s \[=Element/local name=\].
 4. If `type` is null, set `type` to `current type`.
 5. Otherwise, if `type` does not equal
 `current type`, return true.
7. Return false.

IE9 returns human-readable strings like \"Normal\" (p/div/etc.),
\"Formatted\" (pre), \"Heading 1\" (h1), etc. Firefox 6.0a2 and Chrome
14 dev both return the appropriate tag name in lowercase, or the empty
string if there is no appropriate tag. Opera 11.11 behaves the same, but
with uppercase.

IE9 looks like it recognizes address, h\*, pre, dd, dt, ol, ul, and dir,
with everything else registering as \"Normal\". Firefox 6.0a2 recognizes
only the arguments it accepts for formatBlock, namely address, h\*, p,
and pre. Chrome 14 dev recognizes address, div, h\*, dd, dl, dt, p, pre
plus lots of random other stuff like blockquote and section. I\'ll go
with everything that execCommand(\"formatblock\") accepts as an
argument, which at the time of this writing means what Firefox supports
plus div.

[Value](#value):

1. If the [active range](#active-range) is null, return the empty
 string.

2. [Block-extend](#block-extend) the [active range](#active-range), and
 let `new range` be the result.

3. Let `node` be the first [visible](#visible)
 [editable](#editable)
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is
 [contained](http://dom.spec.whatwg.org/#contained) in `new range` and has no
 \[=tree/children=\]. If there is no such
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node"), return the empty string.

4. Opera 11.11 doesn\'t require it be editable, so it will return
 \"DIV\" instead of \"\" for \<div contenteditable\>foo\</div\>.

 While `node`\'s \[=tree/parent=\] is
 [editable](#editable) and [in the same editing
 host](#in-the-same-editing-host) as `node`, and
 `node` is not an [HTML element](#html-element)
 whose \[=Element/local name=\] is a [formattable block
 name](#formattable-block-name), set `node` to
 its \[=tree/parent=\].

5. ::: note
 Chrome 14 dev will report \"div\" for
 \<div\>\<ol\>\<li\>foo\</ol\>\</div\> or such. Opera 11.11 reports
 \"\". IE and Firefox didn\'t cooperate with testing. Opera makes
 more sense, and matches the fact that formatBlock now doesn\'t
 recognize such a div as a formatBlock candidate, so Opera it is.

 We don\'t really need to specify \"editable\" here, since it has to
 be editable if we got to this point.
 :::

 If `node` is an [editable](#editable) [HTML
 element](#html-element) whose \[=Element/local name=\] is a
 [formattable block name](#formattable-block-name), and
 `node` is not the \[=tree/ancestor=\] of a
 [prohibited paragraph child](#prohibited-paragraph-child), return
 `node`\'s \[=Element/local name=\], [converted
 to ASCII
 lowercase](http://dom.spec.whatwg.org/#converted-to-ascii-lowercase).

6. Return the empty string.

### [The `forwardDelete`{title=""} command]

This is the same as hitting the delete key (see [Additional
requirements](#additional-requirements)). It behaves much the same as
[the `delete`{title=""} command](#the-delete-command), except of course
backwards. Also, some of the special cases for backspacing don\'t apply,
as noted in the comments. The one special case you get when deleting
forward but not backward is that if the cursor is before a grapheme
cluster that consists of multiple characters, like a base character with
combining diacritics, we delete the diacritics too. (Backspacing just
deletes the last diacritic, so you have to backspace several times to
remove the whole cluster.)

[Preserves overrides](#preserves-overrides)

Copy-pasted from delete, see there for comments.

[Action](#action):

1. If the [active range](#active-range) is not \[=range/collapsed=\],
 [delete the selection](#delete-the-selection) and return true.

2. [Canonicalize whitespace](#canonicalize-whitespace) at the [active
 range](#active-range)\'s \[=range/start=\].

3. Let `node` and `offset` be
 the [active range](#active-range)\'s \[=range/start=\]
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") and \[=boundary point/offset=\].

4. Repeat the following steps:
 1. If `offset` is the \[=Node/length=\] of
 `node` and `node`\'s
 {{Node/nextSibling}} is an [editable](#editable)
 [invisible](#invisible)
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node"), remove `node`\'s
 {{Node/nextSibling}} from its \[=tree/parent=\].

 2. Otherwise, if `node` has a \[=tree/child=\]
 with \[=tree/index=\] `offset` and that
 \[=tree/child=\] is an [editable](#editable)
 [invisible](#invisible)
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node"), remove that \[=tree/child=\] from
 `node`.

 3. Otherwise, if `offset` is the
 \[=Node/length=\] of `node` and
 `node` is an [inline node](#inline-node), or
 if `node` is [invisible](#invisible), set
 `offset` to one plus the \[=tree/index=\] of
 `node`, then set `node`
 to its \[=tree/parent=\].

 4. No special link behavior for forwardDelete here, unlike delete.

 Otherwise, if `node` has a \[=tree/child=\]
 with \[=tree/index=\] `offset` and that
 \[=tree/child=\] is neither a [block node](#block-node) nor a
 \[\^br\^\] nor an \[\^img\^\] nor a [collapsed block
 prop](#collapsed-block-prop), set `node` to
 that \[=tree/child=\], then set `offset` to
 zero.

 5. Otherwise, break from this loop.

5. If `node` is a {{Text}} node and
 ` offset` is not `node`\'s
 \[=Node/length=\]:
 1. Let `end offset` be `offset` plus one.

 2. ::: note
 Firefox 7.0a2, Chrome 14 dev, Word 2007, and OpenOffice.org
 3.2.1 Ubuntu act as the spec says, getting rid of all diacritics
 on forward delete. IE9 and Opera 11.50 have no special case and
 just delete the next character. I go with
 Firefox/Chrome/Word/OO.

 However, when I actually type in the text box as opposed to
 running semi-automated tests, IE9 has magical behavior: it
 replaces the base character with something that looks like ◌
 U+25CC DOTTED CIRCLE. Further strikes of the delete key remove
 the diacritics, and the circle vanishes along with the last of
 them. I wasn\'t able to get it to actually replace the base
 character, so I\'m not sure what the point is. The circle
 doesn\'t seem to appear in the DOM, and apparently it disappears
 in some circumstances. This might be worth standardizing
 somehow, I don\'t know.

 TODO: The way we remove diacritics is probably not right. We
 probably want to normalize to grapheme cluster boundaries, using
 UAX#29 or something. We also need to handle non-BMP stuff. The
 idea is that if the cursor is before a character that precedes a
 combining mark, you need to delete the combining mark too.
 :::

 While `end offset` is not `node`\'s \[=Node/length=\] and the `end offset`th [code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit) of
 `node`\'s {{CharacterData/ data}} has
 general category M when interpreted as a Unicode code point, add
 one to `end offset`.

 3. Call
 [`collapse(`{title="dom-Selection-collapse"}`node``, `{title="dom-Selection-collapse"}`offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

 4. Call [`extend(`{title="dom-Selection-extend"}`node``, `{title="dom-Selection-extend"}`end offset``)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

 5. [Delete the selection](#delete-the-selection).

 6. Return true.

6. If `node` is an [inline node](#inline-node),
 return true.

7. If `node` has a \[=tree/child=\] with
 \[=tree/index=\] `offset` and that
 \[=tree/child=\] is a \[\^br\^\] or \[\^hr\^\] or \[\^img\^\], but
 is not a [collapsed block prop](#collapsed-block-prop):
 1. Call
 [`collapse(`{title="dom-Selection-collapse"}`node``, `{title="dom-Selection-collapse"}`offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 2. Call [`extend(`{title="dom-Selection-extend"}`node``, `{title="dom-Selection-extend"}`offset`` + 1)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 3. [Delete the selection](#delete-the-selection).
 4. Return true.

8. No special list-item behavior for forwardDelete here, unlike delete.

 Let `end node` equal `node`
 and let `end offset` equal `offset`.

9. If `end node` has a \[=tree/child=\] with
 \[=tree/index=\] `end offset`, and that
 \[=tree/child=\] is a [collapsed block prop](#collapsed-block-prop),
 add one to `end offset`.

10. Repeat the following steps:
 1. If `end offset` is the \[=Node/length=\] of
 `end node`, set `end offset` to one plus the \[=tree/index=\] of
 `end node` and then set `end node` to its \[=tree/parent=\].
 2. Otherwise, if `end node` has an
 [editable](#editable) [invisible](#invisible) \[=tree/child=\]
 with \[=tree/index=\] `end offset`, remove
 it from `end node`.
 3. Otherwise, break from this loop.

11. No special indentation element behavior for forwardDelete here,
 unlike delete.

 If the \[=tree/child=\] of `end node` with
 \[=tree/index=\] `end offset` minus one is a
 \[\^table\^\], return true.

12. If the \[=tree/child=\] of `end node` with
 \[=tree/index=\] `end offset` is a
 \[\^table\^\]:
 1. Call
 [`collapse(`{title="dom-Selection-collapse"}`end node``, `{title="dom-Selection-collapse"}`end offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 2. Call
 [`extend(`{title="dom-Selection-extend"}`end node``, `{title="dom-Selection-extend"}`end offset`` + 1)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 3. Return true.

13. Note, any br will do here: a br immediately after a block is always
 significant.

 If `offset` is the \[=Node/length=\] of
 `node`, and the \[=tree/child=\] of
 `end node` with \[=tree/index=\]
 `end offset` is an \[\^hr\^\] or \[\^br\^\]:

 1. Call
 [`collapse(`{title="dom-Selection-collapse"}`end node``, `{title="dom-Selection-collapse"}`end offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 2. Call
 [`extend(`{title="dom-Selection-extend"}`end node``, `{title="dom-Selection-extend"}`end offset`` + 1)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 3. [Delete the selection](#delete-the-selection).
 4. Call
 [`collapse(`{title="dom-Selection-collapse"}`node``, `{title="dom-Selection-collapse"}`offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [selection](#concept-selection "concept-selection").
 5. Return true.

14. No special list-item behavior for forwardDelete here, unlike delete.

 While `end node` has a \[=tree/child=\] with
 \[=tree/index=\] `end offset`:

 1. If `end node`\'s \[=tree/child=\] with
 \[=tree/index=\] `end offset` is
 [editable](#editable) and [invisible](#invisible), remove it
 from `end node`.
 2. Otherwise, set `end node` to its
 \[=tree/child=\] with \[=tree/index=\] `end offset` and set `end offset` to zero.

15. Call [`collapse(`{title="dom-Selection-collapse"}`node``, `{title="dom-Selection-collapse"}`offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

16. Call [`extend(`{title="dom-Selection-extend"}`end node``, `{title="dom-Selection-extend"}`end offset``)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

17. [Delete the selection](#delete-the-selection).

18. Return true.

### [The `indent`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

IE9
: Outputs \<blockquote style=\"margin-right: 0px\" dir=\"ltr\"\>, or
 when surrounding RTL blocks, \<blockquote style=\"margin-left: 0px\"
 dir=\"rtl\"\>. The direction seems to go by the end of the
 selection. The presence of the dir attribute means that any contents
 that were inheriting a different dir from an ancestor get their
 direction changed as a side effect, but if they actually have the
 opposite dir specified, they won\'t appear to be indented. It
 doesn\'t reset top or bottom margins on the blockquote, so it adds
 them. If it\'s not wrapping a block element, like if it\'s only
 wrapping up until a \<br\>, it adds a \<p\>.

Firefox 4.0
: In styleWithCSS mode, adds style=\"margin-left: 40px\" to the
 appropriate block container (or margin-right if it\'s RTL). If
 there\'s no appropriate block container, adds a div. If multiple
 blocks are affected, it goes by the direction of the block whose
 style it\'s changing, which winds up being wrong for descendants
 with different direction. In non-styleWithCSS mode, uses
 \<blockquote\>, so it indents on both sides and also adds top/bottom
 margins.

Chrome 12 dev
: Outputs \<blockquote class=\"webkit-indent-blockquote\"
 style=\"margin: 0 0 0 40px; border: none; padding: 0px\"\> in both
 modes for both LTR and RTL (which is broken for RTL, since it
 indents only on the left).

Opera 11.00
: Outputs \<blockquote\>, so it indents on both sides and on the
 top/bottom.

For repeated indentation, everyone except Opera that outputs
\<blockquote\>s just puts them at the outermost possible location, which
works well. Opera puts them in the innermost position, which is broken,
because it will even put them inside \<p\> (which will not round-trip
through text/html serialization).

Gecko in CSS mode messes up by adding margins even to things like
\<blockquote\> that already have margins from CSS rules, instead of
nesting a div, so it doesn\'t actually increase the indentation.
However, if an element has an explicit left margin (assuming LTR), it
will increase the margin to 80px, so it works with WebKit\'s
blockquotes.

We have two strategies for handling directionality: always indent on
both sides (Firefox non-CSS, Opera) or try to figure out heuristically
which side we want (IE, Firefox CSS). The latter approach is only
possible by adding extra markup and complexity, so for now we\'ll take
the easy way out and go with just indenting on both sides.

This reasoning doesn\'t discuss lists. For research on lists, see the
comment for [insertOrderedList](#the-insertorderedlist-command). List
handling is more complicated and I wound up differing from all browsers
in lots of ways.

[Preserves overrides](#preserves-overrides)

[Action](#action):

1. Let `items` be a list of all \[\^li\^\]s that
 are \[=tree/inclusive ancestors=\] of the [active
 range](#active-range)\'s \[=range/start=\] and/or \[=range/end=\]
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node").

2. TODO: This overnormalizes, but it seems like the simplest solution
 for now.

 For each `item` in `items`,
 [normalize sublists](#normalize-sublists) of `item`.

3. [Block-extend](#block-extend) the [active range](#active-range), and
 let `new range` be the result.

4. Let `node list` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.

5. For each
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node`
 [contained](http://dom.spec.whatwg.org/#contained) in `new range`, if
 `node` is [editable](#editable) and is an
 [allowed child](#allowed-child) of \"div\" or \"ol\" and if the last
 member of `node list` (if any) is not an
 \[=tree/ancestor=\] of `node`, append
 `node` to `node list`.

6. Without this step, the last child of the previous sibling might be a
 list, which the li wouldn\'t get appended to.

 If the first [visible](#visible) member of `node list` is an \[\^li\^\] whose \[=tree/parent=\] is an \[\^ol\^\]
 or \[\^ul\^\]:

 1. Let `sibling` be `node list`\'s first [visible](#visible) member\'s {{Node/
 previousSibling}}.
 2. While `sibling` is [invisible](#invisible),
 set `sibling` to its {{Node/
 previousSibling}}.
 3. If `sibling` is an \[\^li\^\], [normalize
 sublists](#normalize-sublists) of `sibling`.

7. While `node list` is not empty:
 1. Let `sublist` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.
 2. Remove the first member of `node list` and
 append it to `sublist`.
 3. While the first member of `node list` is the
 {{Node/nextSibling}} of the last member of `sublist`, remove the first member of `node list` and append it to `sublist`.
 4. [Indent](#indent) `sublist`.

8. Return true.

### [The `insertHorizontalRule`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Preserves overrides](#preserves-overrides)

You\'d think interop here would be simple, right? Nope: we have three
different behaviors across four browsers. Opera 11.00 is the only one
that acts more or less like the spec. IE9 and Chrome 12 dev treat the
value as an id, which is weird and probably useless, so I don\'t do it.
Firefox 4.0 produces \<hr size=2 width=100%\> instead of \<hr\>, which
is also weird and almost definitely useless, so I don\'t do it. Then you
have the varying behavior in splitting up parents to ensure validity . .
.

[Action](#action):

1. Let `start node`, `start offset`, `end node`, and
 `end offset` be the [active
 range](#active-range)\'s \[=range/start=\] and \[=range/end=\]
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") and \[=boundary point/offsets=\].

2. While `start offset` is 0 and
 `start node`\'s \[=tree/parent=\] is not null,
 set ` start offset` to `start node`\'s \[=tree/index=\], then set `start node` to its \[=tree/parent=\].

3. While `end offset` is `end node`\'s \[=Node/length=\], and `end node`\'s \[=tree/parent=\] is not null, set
 `end offset` to one plus `end node`\'s \[=tree/index=\], then set `end node` to its \[=tree/parent=\].

4. Call
 [`collapse(`{title="dom-Selection-collapse"}`start node``, `{title="dom-Selection-collapse"}`start offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

5. Call [`extend(`{title="dom-Selection-extend"}`end node``, `{title="dom-Selection-extend"}`end offset``)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

6. [Delete the selection](#delete-the-selection), with
 `block merging` false.

7. If the [active range](#active-range)\'s \[=range/start node=\] is
 neither [editable](#editable) nor an \[=editing host=\], return
 true.

8. We don\'t want to call insertNode at the start or end of a text
 node, because that will leave an empty text node.

 If the [active range](#active-range)\'s \[=range/start node=\] is a
 {{Text}} node and its \[=range/start offset=\] is zero, call
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection"), with first
 argument the [active range](#active-range)\'s \[=range/start
 node=\]\'s \[=tree/parent=\] and second argument the [active
 range](#active-range)\'s \[=range/start node=\]\'s \[=tree/index=\].

9. If the [active range](#active-range)\'s \[=range/start node=\] is a
 {{Text}} node and its \[=range/start offset=\] is the
 \[=Node/length=\] of its \[=range/start node=\], call
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection"), with first
 argument the [active range](#active-range)\'s \[=range/start
 node=\]\'s \[=tree/parent=\], and the second argument one plus the
 [active range](#active-range)\'s \[=range/start node=\]\'s
 \[=tree/index=\].

10. Let `hr` be the result of calling
 [`createElement("hr")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object).

11. Run [`insertNode(``hr``)`](http://dom.spec.whatwg.org/#dom-range-insertnode)
 on the [active range](#active-range).

12. IE9 and Chrome 13 dev seem to never break up any ancestors, which
 can lead to unserializable DOMs like \<hr\> inside \<p\>. Opera
 11.11 seems to always break up parents going all the way up to the
 contenteditable root, even ones like \<div\> that can contain
 \<hr\>. Firefox 5.0a2 acts the most sensibly: it only breaks up
 things like \<p\> or \<b\> that shouldn\'t contain \<hr\>. The spec
 goes with Firefox here (although the list of what to break up isn\'t
 precisely identical).

 [Fix disallowed ancestors](#fix-disallowed-ancestors) of
 `hr`.

13. Run
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection"), with first
 argument `hr`\'s \[=tree/parent=\] and the
 second argument equal to one plus `hr`\'s
 \[=tree/index=\].

14. Return true.

### [The `insertHTML`{title=""} command]

[Preserves overrides](#preserves-overrides)

Not supported by IE9. Handling of disallowed children is interesting:

Firefox 5.0a2
: Will allow \<dt\> inside \<dt\> (doesn\'t serialize). If you try
 inserting dir/ol/ul inside an existing dir/ol/ul, it will strip the
 list element and leave only the li\'s, so inserting
 \<ul\>\<li\>abc\</ul\> into \<ol\>\<li\>f\[o\]o\</ol\> creates
 \<ol\>\<li\>f\<li\>abc\<li\>o\</ol\>. \<dt\>/\<dd\>/\<li\> that
 don\'t descend from a list will be left alone, not converted to
 \<p\>. Empty elements seem not to be inserted. \<li\> will get put
 inside \<p\>, which breaks serialization. Nothing is allowed inside
 \<xmp\>, not even text.

Chrome 13 dev
: Inserting a \<p\> into a \<p\> or \<li\> or such will remove the
 child \<p\>, adding its contents to the parent instead. Adding an
 \<li\> or \<hr\> as the child of a \<p\> works, as does an \<a\>
 inside an \<a\>, \<h2\> inside \<h1\>, \<li\> inside \<li\>,
 \<nobr\> inside \<nobr\>, \<b\> inside \<xmp\>, etc. (all
 unserializable). But \<dt\> and \<dd\> seem to get converted to
 their contents like \<p\>. \<ol\>\<li\>abc\</ol\> inside
 \<ol\>\<li\>f\[o\]o\</ol\> becomes
 \<ol\>\<li\>f\<li\>abc\<li\>\<li\>o\</ol\>, interestingly (note the
 empty \<li\>). I don\'t understand how it works, but it doesn\'t
 seem to make much sense.

Opera 11.11
: Seems to do almost no validity or serialization checks, except that
 it prevents \<a\> inside \<a\>, \<nobr\> inside \<nobr\>, and block
 elements inside inline elements. Interestingly, most of the places
 where it\'s non-serializable per HTML parsing are actually
 serializable in Opera\'s own parser.

[Action](#action):

1. Set `value` to the result of invoking [get trusted types
 compliant
 string](https://w3c.github.io/trusted-types/dist/spec/#get-trusted-type-compliant-string-algorithm)
 with
 [`TrustedHTML`](https://w3c.github.io/trusted-types/dist/spec/#trusted-html),
 this\'s relevant global object, `value`, \"Document
 execCommand\", and \"script\".

2. ::: note
 Chrome 14 dev and Opera 11.11 do this even if the value is empty.
 Firefox 5.0a2 throws an exception.

 Firefox 7.0a2 and Chrome 14 dev do strip wrappers here, so inserting
 HTML in the place of \<b\>\[foo\]\</b\> will remove the \<b\>. Opera
 11.50 keeps the wrappers. I follow the majority and leave the
 \"strip wrappers\" flag true.
 :::

 [Delete the selection](#delete-the-selection).

3. If the [active range](#active-range)\'s \[=range/start node=\] is
 neither [editable](#editable) nor an \[=editing host=\], return
 true.

4. TODO: This has some interesting consequences. For instance, table
 cells and similar will just vanish if they\'re not in an appropriate
 place; and inside a script or style or xmp or such, the argument
 will effectively be HTML-escaped before use. Some of these
 consequences might be undesirable.

 Let `frag` be the result of calling
 ` `[`createContextualFragment(``value``)`](http://domparsing.spec.whatwg.org/#dom-range-createcontextualfragment)
 on the [active range](#active-range).

5. Let `last child` be the {{Node/lastChild}} of
 `frag`.

6. Firefox 5.0a2 also seems to not add empty elements like \<b\>\</b\>,
 but Chrome 13 dev and Opera 11.11 do.

 If `last child` is null, return true.

7. Let `descendants` be all \[=tree/descendants=\]
 of `frag`.

8. ::: note
 This is so we don\'t get something like

 <div>[foo]</div>
 -> <div><br></div>
 -> <div><p>Some HTML</p><br></div>

 with an extra bogus line break at the end.
 :::

 If the [active range](#active-range)\'s \[=range/start node=\] is a
 [block node](#block-node):

 1. Let `collapsed block props` be all
 [editable](#editable) [collapsed block
 prop](#collapsed-block-prop) \[=tree/children=\] of the [active
 range](#active-range)\'s \[=range/start node=\] that have
 \[=tree/index=\] greater than or equal to the [active
 range](#active-range)\'s \[=range/start offset=\].
 2. For each `node` in
 `collapsed block props`, remove
 `node` from its \[=tree/parent=\].

9. We could canonicalize whitespace after inserting the fragment, but
 let\'s not. If the author wants HTML, give them HTML behavior. When
 asked to replace a paragraph\'s contents with a single space,
 Firefox 7.0a2 does so but inserts a \<br\> before it (not after);
 Chrome 14 dev does so and doesn\'t insert a \<br\>, so the paragraph
 collapses; Opera 11.50 doesn\'t insert the space at all, and just
 inserts a \<br\>. Correct behavior is to insert a space, then insert
 a \<br\> after it in the next step because it\'s an invisible node.

 Call [`insertNode(``frag``)`](http://dom.spec.whatwg.org/#dom-range-insertnode)
 on the [active range](#active-range).

10. In case we remove all the contents, then remove the extra \<br\>,
 then only add a comment or something. In that case we want to re-add
 the extra \<br\>. We don\'t try fixing the actual inserted content:
 that\'s the author\'s lookout.

 If the [active range](#active-range)\'s \[=range/start node=\] is a
 [block node](#block-node) with no [visible](#visible)
 \[=tree/children=\], call [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and append the result as the last child of the
 [active range](#active-range)\'s \[=range/start node=\].

11. Need to do this before fixing disallowed ancestors, since otherwise
 the last child might have been removed (e.g., it\'s an li).

 Call
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection"), with
 `last child`\'s \[=tree/parent=\] as the first
 argument and one plus its \[=tree/index=\] as the second.

12. We want to fix all descendants, not just children. Consider
 \<div\>\<li\>foo\</li\>\</div\>, for example.

 [Fix disallowed ancestors](#fix-disallowed-ancestors) of each member
 of `descendants`.

13. Return true.

### [The `insertImage`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Preserves overrides](#preserves-overrides)

[Action](#action):

1. Similar logic to createLink, except even more compelling, since an
 HTML document linking to itself as an image is just silly. In fact,
 the current HTML spec instructs UAs to not even try displaying the
 image, and just fail immediately if the URL is empty. Firefox 4b11
 silently does nothing on an empty string, but the other three
 browsers I tested stick in the \<img\> anyway.

 If `value` is the empty string, return false.

2. Firefox 7.0a2 seems to strip the wrapper or not depending on the
 exact positioning of the selection: \<b\>{foo}\</b\> yes,
 \<b\>\[foo\]\</b\> no. Chrome 14 dev seems to strip the wrapper
 regardless. Opera 11.50 seems to keep the wrapper, but place the
 image outside it. I didn\'t get IE to cooperate with my tests. I
 chose to leave wrappers across the board because they might be
 meaningful: e.g., a background-color when the image is small or not
 fully opaque.

 [Delete the selection](#delete-the-selection), with
 `strip wrappers` false.

3. Let `range` be the [active
 range](#active-range).

4. If the [active range](#active-range)\'s \[=range/start node=\] is
 neither [editable](#editable) nor an \[=editing host=\], return
 true.

5. Same logic as with insertHTML.

 If `range`\'s \[=range/start node=\] is a [block
 node](#block-node) whose sole \[=tree/child=\] is a \[\^br\^\], and
 its \[=range/start offset=\] is 0, remove its \[=range/start
 node=\]\'s \[=tree/child=\] from it.

6. Let `img` be the result of calling
 [`createElement("img")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object).

7. No alt text, so it\'s probably invalid. This matches all browsers.

 Run [`setAttribute("src", ``value``)`](http://dom.spec.whatwg.org/#dom-element-setattribute)
 on `img`.

8. This winds up putting it at the original start point of the active
 range, as currently specced. This matches IE9 and Firefox 5.0a2.
 Chrome 13 dev puts it at the end point, and Opera 11.11 puts it in
 between (where the range would collapse if you called
 deleteContents()).

 Run [`insertNode(``img``)`](http://dom.spec.whatwg.org/#dom-range-insertnode)
 on `range`.

 An image could be inserted inside a link, with either this command
 or insertHTML. On Chrome 51 dev, inserting an image (with
 insertImage or insertHTML) inside a link will remove the parent
 link. Firefox 48 allows this nesting.

9. Let `selection` be the result of calling
 [`getSelection()`{title="dom-Document-getSelection"}](#dom-document-getselection)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object).

10. Run
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on `selection`, with first argument equal to the
 \[=tree/parent=\] of `img` and the second
 argument equal to one plus the \[=tree/index=\] of `img`.

11. Return true.

### [The `insertLineBreak`{title=""} command]

This is the same as hitting Shift-Enter or such (see [Additional
requirements](#additional-requirements)). It deletes the selection, and
replaces it with a `<br>`{title=""}. No real complications.

Only implemented in WebKit (Chrome 14 dev). Other tests are entirely
manual (i.e., actually hitting Shift-Enter instead of running a
command). There\'s a surprisingly large amount of interop.

IE9 is tripped up by \<xmp\>, and also often doesn\'t add an extra
\<br\> when the one it just inserted is extraneous.

Firefox 6.0a2 doesn\'t notice if you\'re trying to put the \<br\> in a
bad place, which can result in unserializable DOMs.

Chrome 14 dev inserts a literal linebreak for pre and xmp and maybe
other similar elements. This doesn\'t seem very useful, so I don\'t
bother.

Opera 11.11 isn\'t heedful of \<xmp\>, and treats \<pre\> somewhat
oddly.

[Preserves overrides](#preserves-overrides)

[Action](#action):

1. IE9 doesn\'t strip wrappers (IE10PP2 didn\'t work in tests). Firefox
 7.0a2 strips wrappers inconsistently depending on the exact
 selection endpoints. Chrome 14 dev strips wrappers but recreates any
 styles using new wrappers. Opera 11.50 strips all wrappers.

 [Delete the selection](#delete-the-selection), with
 `strip wrappers` false.

2. If the [active range](#active-range)\'s \[=range/start node=\] is
 neither [editable](#editable) nor an \[=editing host=\], return
 true.

3. script, xmp, table, . . .

 If the [active range](#active-range)\'s \[=range/start node=\] is an
 {{Element}}, and \"br\" is not an [allowed child](#allowed-child) of
 it, return true.

4. If the [active range](#active-range)\'s \[=range/start node=\] is
 not an {{Element}}, and \"br\" is not an [allowed
 child](#allowed-child) of the [active range](#active-range)\'s
 \[=range/start node=\]\'s \[=tree/parent=\], return true.

5. We don\'t want to call insertNode at the start or end of a text
 node, because that will leave an empty text node.

 If the [active range](#active-range)\'s \[=range/start node=\] is a
 {{Text}} node and its \[=range/start offset=\] is zero, call
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection"), with first
 argument equal to the [active range](#active-range)\'s
 \[=range/start node=\]\'s \[=tree/parent=\] and second argument
 equal to the [active range](#active-range)\'s \[=range/start
 node=\]\'s \[=tree/index=\].

6. If the [active range](#active-range)\'s \[=range/start node=\] is a
 {{Text}} node and its \[=range/start offset=\] is the
 \[=Node/length=\] of its \[=range/start node=\], call
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection"), with first
 argument equal to the [active range](#active-range)\'s
 \[=range/start node=\]\'s \[=tree/parent=\] and second argument
 equal to one plus the [active range](#active-range)\'s
 \[=range/start node=\]\'s \[=tree/index=\].

7. Let `br` be the result of calling
 [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object).

8. Call [`insertNode(``br``)`](http://dom.spec.whatwg.org/#dom-range-insertnode)
 on the [active range](#active-range).

9. Call
 [`collapse()`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection"), with
 `br`\'s \[=tree/parent=\] as the first argument
 and one plus `br`\'s \[=tree/index=\] as the
 second argument.

10. If `br` is a [collapsed line
 break](#collapsed-line-break), call ` `[`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and let `extra br` be the
 result, then call [`insertNode(``extra br``)`](http://dom.spec.whatwg.org/#dom-range-insertnode)
 on the [active range](#active-range).

11. Return true.

### [The `insertOrderedList`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Preserves overrides](#preserves-overrides)

[Action](#action): [Toggle lists](#toggle-lists) with
`tag name` \"ol\", then return true.

Firefox 6.0a2 sort of supports this, but it throws exceptions most of
the time. It has the quirk that even if there are no ol\'s around, it
will say it\'s indeterminate if there are some things that are ul\'s and
some that are not lists at all, but this doesn\'t make sense and I
don\'t duplicate it. No one else supports indeterminate for
insert\*List, but it makes sense if you support state.

[Indeterminate](#indeterminate): True if the [selection\'s list
state](#selection's-list-state) is \"mixed\" or \"mixed ol\", false
otherwise.

IE9 throws exceptions in most cases, Firefox 6.0a2 in some cases as
well, for no apparent reason. Ignoring those, the spec basically matches
all browsers, except with a few weird random mismatches that looked like
browser bugs to me.

[State](#state): True if the [selection\'s list
state](#selection's-list-state) is \"ol\", false otherwise.

### [The `insertParagraph`{title=""} command]

This is the same as hitting enter (see [Additional
requirements](#additional-requirements)). The general rule is that we
find the nearest [single-line container](#single-line-container)
ancestor, clone it and insert the clone after it, and then move all the
contents after the cursor (along with the cursor itself) to the clone.
But there are a few special cases:

- If we can\'t find a single-line container to use, first we wrap the
 current line in a new container with the [default single-line
 container name](#default-single-line-container-name).
- For `<address>`{title=""}, `<listing>`{title=""}, and
 `<pre>`{title=""}, we add a `<br>`{title=""} instead of cloning it.
 These are all elements that are meant to contain multiple lines, not
 have one line per element.
- If the cursor is in a list item with no contents, hitting enter breaks
 out of the list entirely, outdenting the current item. This means that
 if you\'re in a list, you can hit enter twice to break out.
- If the cursor is at the end of a heading, hitting enter doesn\'t make
 a new heading, it switches to the [default single-line container
 name](#default-single-line-container-name).
- If the cursor is at the end of a `<dt>`{title=""} or `<dd>`{title=""},
 the new element is the opposite type, so you naturally switch between
 entering terms and definitions.

[Preserves overrides](#preserves-overrides)

There are three major behaviors here. Firefox 5.0a2 behaves identically
to execCommand(\"formatBlock\", false, \"p\"), which is not really
useful. IE9 actually just overwrites the selection with an empty
paragraph element, which seems not very useful either. Chrome 13 dev and
Opera 11.10 behave basically the same as if the user hit the Return key.
This latter behavior seems much more useful, even though it\'s horribly
misnamed, so it\'s what I\'ll spec. Comments about IE/Firefox are based
on manual tests, where I hit Enter instead of running commands.

(Actually, Opera doesn\'t behave quite the same for insertParagraph and
line breaks. But it\'s pretty close, and I expect the differences are
bugs.)

Then, of course, we have several flavors of line-breaking behavior to
choose from. Firefox prefers \<br\>s, unless it\'s in the middle of a
\<p\> or something. Opera and IE like \<p\>. Chrome prefers \<div\>. And
there are lots of subtleties besides. I go with IE/Opera-style behavior,
as discussed in [a whatwg
thread](http://lists.whatwg.org/htdig.cgi/whatwg-whatwg.org/2011-May/031577.html).

Update August 2016: The consensus of current browsers is now to use div
as the separator, not p, so the spec is updated accordingly.

[Action](#action):

1. [Delete the selection](#delete-the-selection).

2. If the [active range](#active-range)\'s \[=range/start node=\] is
 neither [editable](#editable) nor an \[=editing host=\], return
 true.

3. Let `node` and `offset` be
 the [active range](#active-range)\'s \[=range/start=\]
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") and \[=boundary point/offset=\].

4. If `node` is a {{Text}} node, and
 `offset` is neither 0 nor the \[=Node/length=\]
 of `node`, call [`splitText(``offset``)`](http://dom.spec.whatwg.org/#dom-text-splittext)
 on `node`.

5. If `node` is a {{Text}} node and
 ` offset` is its \[=Node/length=\], set
 `offset` to one plus the \[=tree/index=\] of
 `node`, then set `node` to
 its \[=tree/parent=\].

6. If `node` is a {{Text}} or {{Comment}} node, set
 `offset` to the \[=tree/index=\] of
 `node`, then set `node` to
 its \[=tree/parent=\].

7. Call [`collapse(`{title="dom-Selection-collapse"}`node``, `{title="dom-Selection-collapse"}`offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

8. Let `container` equal `node`.

9. While `container` is not a [single-line
 container](#single-line-container), and `container`\'s \[=tree/parent=\] is [editable](#editable) and [in the
 same editing host](#in-the-same-editing-host) as `node`, set `container` to its
 \[=tree/parent=\].

10. [Bug 13841](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13841).

 If `container` is an [editable](#editable)
 [single-line container](#single-line-container) [in the same editing
 host](#in-the-same-editing-host) as `node`, and
 its \[=Element/local name=\] is \"p\" or \"div\":

 1. Let `outer container` equal
 ` container`.
 2. While `outer container` is not a \[\^dd\^\]
 or \[\^dt\^\] or \[\^li\^\], and `outer container`\'s \[=tree/parent=\] is [editable](#editable), set
 `outer container` to its \[=tree/parent=\].
 3. If `outer container` is a \[\^dd\^\] or
 \[\^dt\^\] or \[\^li\^\], set `container` to
 `outer container`.

11. We add the default wrapper in this case.

 If `container` is not [editable](#editable) or
 not [in the same editing host](#in-the-same-editing-host) as
 `node` or is not a [single-line
 container](#single-line-container):

 1. Let `tag` be the [default single-line
 container name](#default-single-line-container-name).

 2. [Block-extend](#block-extend) the [active range](#active-range),
 and let `new range` be the result.

 3. Let `node list` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.

 4. Append to `node list` the first
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") in \[=tree order=\] that is
 [contained](http://dom.spec.whatwg.org/#contained) in `new range` and is an
 [allowed child](#allowed-child) of \"p\", if any.

 5. If `node list` is empty:
 1. Ideally, we should normalize things so that the cursor is
 never in a weird place after deletion, but let\'s be safe
 and bail out if we do hit this scenario. It\'s not clear if
 we need this line in the long term, but at the time of this
 writing there\'s at least one corner case where deleting can
 leave the cursor inside a \<tr\>.

 If `tag` is not an [allowed
 child](#allowed-child) of the [active
 range](#active-range)\'s \[=range/start node=\], return
 true.

 2. Set `container` to the result of calling
 [`createElement(``tag``)`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object).

 3. Call [`insertNode(``container``)`](http://dom.spec.whatwg.org/#dom-range-insertnode)
 on the [active range](#active-range).

 4. Call [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object), and append the result as the last
 \[=tree/child=\] of `container`.

 5. Call
 [`collapse(`{title="dom-Selection-collapse"}`container``, 0)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

 6. Return true.

 6. TODO: It is not at all obvious that this is the correct list of
 nodes in all cases. It should probably work because of how the
 block-extend algorithm works, but further thought would be good.

 While the {{Node/nextSibling}} of the last member of
 `node list` is not null and is an [allowed
 child](#allowed-child) of \"p\", append it to
 `node list`.

 7. [Wrap](#wrap) `node list`, with
 `sibling criteria` returning false and
 `new parent instructions` returning the
 result of calling [`createElement(``tag``)`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object). Set `container` to the
 result.

12. ::: note
 IE9 and Chrome 13 dev just break \<pre\> up into multiple \<pre\>s.
 Firefox 5.0a2 and Opera 11.10 insert a \<br\> instead, treating it
 differently from \<p\>. The latter makes more sense. What might make
 the most sense is to just insert an actual newline character,
 though, since this is a pre after all . . .

 IE9 and Chrome 13 dev also break \<address\> up into multiple
 \<address\>es. Firefox 5.0a2 inserts \<br\> instead. Opera 11.10
 nests \<p\>s inside. I don\'t like Opera\'s behavior, because it
 means we nest formatBlock candidates inside one another, so I\'ll go
 with Firefox.

 listing and xmp work the same as pre in all browsers. For Firefox
 and Opera, this results in trying to put a br inside an xmp, so I go
 with IE/Chrome for xmp.

 TODO: In cases where hitting enter in a header doesn\'t break out of
 the header, we should probably follow this code path too, instead of
 creating an adjoining header. No browser does this, though, so we
 don\'t.
 :::

 If `container`\'s \[=Element/local name=\] is
 \"address\", \"listing\", or \"pre\":

 1. Let `br` be the result of calling
 [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object).

 2. Call [`insertNode(``br``)`](http://dom.spec.whatwg.org/#dom-range-insertnode)
 on the [active range](#active-range).

 3. Call
 [`collapse(`{title="dom-Selection-collapse"}`node``, `{title="dom-Selection-collapse"}`offset`` + 1)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

 4. Necessary because adding a br to the end of a block element does
 nothing if there wasn\'t one there already. A single newline
 immediately preceding a block boundary does nothing.

 If `br` is the last \[=tree/descendant=\] of
 `container`, let `br` be
 the result of calling [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object), then call [`insertNode(``br``)`](http://dom.spec.whatwg.org/#dom-range-insertnode)
 on the [active range](#active-range).

 5. Return true.

13. Including dt/dd here follows Firefox 5.0a2, as with the special
 dt/dd handling below.

 If `container`\'s \[=Element/local name=\] is
 \"li\", \"dt\", or \"dd\"; and either it has no \[=tree/children=\]
 or it has a single \[=tree/child=\] and that \[=tree/child=\] is a
 \[\^br\^\]:

 1. [Split the parent](#split-the-parent) of the
 one-[node](http://dom.spec.whatwg.org/#concept-node "concept-node") list consisting of `container`.

 2. If `container` has no \[=tree/children=\],
 call [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object) and append the result as the last
 \[=tree/child=\] of `container`.

 3. Annoying hack to prevent the dl from being re-added when fixing
 disallowed ancestors. In most cases we want a wrapper dl added,
 but in two cases (delete and insertParagraph) we\'re actually
 trying to outdent the list item. TODO: there might be a better
 way to do this.

 If `container` is a \[\^dd\^\] or
 \[\^dt\^\], and it is not an [allowed child](#allowed-child) of
 any of its \[=tree/ancestors=\] [in the same editing
 host](#in-the-same-editing-host), [set the tag
 name](#set-the-tag-name) of `container` to
 the [default single-line container
 name](#default-single-line-container-name) and let
 `container` be the result.

 4. [Fix disallowed ancestors](#fix-disallowed-ancestors) of
 `container`.

 5. Return true.

14. Let `new line range` be a new \[=range=\] whose
 \[=range/start=\] is the same as the [active
 range](#active-range)\'s, and whose \[=range/end=\] is
 (`container`, \[=Node/length=\] of
 `container`).

15. We don\'t want the start to be just inside a node, because if it is,
 we\'ll leave behind an empty element either in the new or old
 container. Empty block nodes are fine, and we\'ll add a \[\^br\^\]
 later, but empty inline nodes are bad, since the user can\'t
 interact with them.

 While `new line range`\'s \[=range/start
 offset=\] is zero and its \[=range/start node=\] is not a
 [prohibited paragraph child](#prohibited-paragraph-child), set its
 \[=range/start=\] to (\[=tree/parent=\] of \[=range/start node=\],
 \[=tree/index=\] of \[=range/start node=\]).

16. While `new line range`\'s \[=range/start
 offset=\] is the \[=Node/length=\] of its \[=range/start node=\] and
 its \[=range/start node=\] is not a [prohibited paragraph
 child](#prohibited-paragraph-child), set its \[=range/start=\] to
 (\[=tree/parent=\] of \[=range/start node=\], 1 + \[=tree/index=\]
 of \[=range/start node=\]).

17. Let `end of line` be true if
 `new line range`
 [contains](http://dom.spec.whatwg.org/#contained "contained") either nothing or a single \[\^br\^\], and false
 otherwise.

18. IE9 makes a new header if there\'s a trailing \<br\>. Firefox 5.0a2,
 Chrome 13 dev, and Opera 11.10 do not, and I follow them, since it
 makes more sense (such a \<br\> is invisible).

 If the \[=Element/local name=\] of `container`
 is \"h1\", \"h2\", \"h3\", \"h4\", \"h5\", or \"h6\", and
 `end of line` is true, let
 `new container name` be the [default single-line
 container name](#default-single-line-container-name).

19. This step and the next follow Firefox 5.0a2. IE9 and Chrome 13 dev
 act as though these two lines were not present (they clone the
 existing element). Opera 11.10 nests a \<p\> inside. Firefox is the
 most useful, assuming a definition list somehow winds up inside the
 content (like via formatBlock).

 Otherwise, if the \[=Element/local name=\] of `container` is \"dt\" and `end of line` is true,
 let `new container name` be \"dd\".

20. Otherwise, if the \[=Element/local name=\] of `container` is \"dd\" and `end of line` is true,
 let `new container name` be \"dt\".

21. Otherwise, let `new container name` be the
 \[=Element/local name=\] of `container`.

22. Let `new container` be the result of calling
 [`createElement(``new container name``)`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object).

23. Copy all attributes of `container` to
 `new container`.

24. If `new container` has an ` `[`id`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-id-attribute)
 attribute, unset it.

25. Insert `new container` into the
 \[=tree/parent=\] of `container` immediately
 after `container`.

26. Let `contained nodes` be all
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node")
 [contained](http://dom.spec.whatwg.org/#contained) in `new line range`.

27. TODO: This blows up any ranges (other than the selection, which we
 reset), and can alter non-editable nodes, and maybe other bad stuff.
 May or may not be the best solution. The intermediate fragment is
 also possibly black-box detectable by DOM mutation events, but I
 like to pretend those don\'t exist.

 Let `frag` be the result of calling
 [`extractContents()`](http://dom.spec.whatwg.org/#dom-range-extractcontents)
 on `new line range`.

28. Unset the ` `[`id`](http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#the-id-attribute)
 attribute (if any) of each {{Element}} \[=tree/descendant=\] of
 `frag` that is not in
 `contained nodes`.

29. Call [`appendChild(``frag``)`](http://dom.spec.whatwg.org/#dom-node-appendchild)
 on `new container`.

30. Needed in case we have something like
 `<ol><li><p>foo</ol>`{title=""}, which becomes
 `<ol><li><p><li><p>foo</ol>`{title=""}. In this case we want to add
 the \[\^br\^\] to the \[\^p\^\], not the \[\^li\^\]. Likewise for
 `<ol><li><p>foo</ol>`{title=""}.

 While `container`\'s {{Node/lastChild}} is a
 [prohibited paragraph child](#prohibited-paragraph-child), set
 `container` to its {{Node/lastChild}}.

31. While `new container`\'s [`lastChild`](http://dom.spec.whatwg.org/#dom-node-lastchild)
 is a [prohibited paragraph child](#prohibited-paragraph-child), set
 `new container` to its {{Node/lastChild}}.

32. If `container` has no [visible](#visible)
 \[=tree/children=\], call [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object), and append the result as the last
 \[=tree/child=\] of `container`.

33. These two steps follow Firefox 5.0a2, Chrome 13 dev, and Opera
 11.10. IE9 instead inserts an \&nbsp; which magically does not
 appear in innerHTML. In all cases, the reason is that an empty block
 box in CSS will have zero height, so the user won\'t be able to put
 the selection cursor inside it.

 If `new container` has no [visible](#visible)
 \[=tree/children=\], call [`createElement("br")`](http://dom.spec.whatwg.org/#dom-document-createelement)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object), and append the result as the last
 \[=tree/child=\] of `new container`.

34. Call
 [`collapse(`{title="dom-Selection-collapse"}`new container``, 0)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

35. Return true.

### [The `insertText`{title=""} command]

This is the same as typing text (see [Additional
requirements](#additional-requirements)). If the input string is more
than one character, first we split it up into one execution per
character, for simplicity. The general rule is then that we record each
command\'s [state override](#state-override) or [value
override](#value-override), insert the new character and select it,
restore any overrides that we saved, and collapse the selection to its
end.

The idea of the override business is that the user might run a command
like bold when the selection is collapsed. There\'s nothing to bold in
that case, but if the user runs bold and then types a character, they
expect it to be bold. Thus we save the requested state in an override
and restore it when the user types. Deleting things can also set
overrides, if the deleted text was styled.

Whitespace is a special case. The note for [canonical space
sequences](#canonical-space-sequences) gives some of the background. If
the user tries typing a space, we make it non-breaking so it doesn\'t
collapse with anything, then canonicalize whitespace around the
insertion point so line breaking isn\'t adversely affected.

One last special case is a newline. For that we just pass off to [the
`insertParagraph`{title=""} command](#the-insertparagraph-command).

Supported only by WebKit. Tests in other browsers were manual.

TODO: This doesn\'t work well if the input contains things that aren\'t
supposed to appear in HTML, like carriage returns or nulls. Nor is it
going to work well if the current cursor position is in between two
halves of a non-BMP character. This will result in unserializability.
The current spec disregards this, as Chrome 14 dev does. (It\'s not
relevant to other browsers, since they don\'t support this as a
command.)

Important issue: non-breaking space fun! The issue: if the user hits
space twice, they expect it to create two spaces, not collapse. Also, if
they\'re at the beginning or end of a line and hit space, again, they
expect it not to collapse. Since we don\'t want to require that all
contenteditable element contents always be used only with white-space:
pre-wrap, we need to convert to and from non-breaking spaces.

But there\'s a catch: you can\'t just make spaces non-breaking
willy-nilly, because that doesn\'t just stop the space from collapsing,
it also prevents breaking. (Chrome 14 dev actually cheats here: in
contenteditable, it doesn\'t collapse nbsp, but breaks after it like a
regular space.) The upshot of this is that any nbsp needs to be followed
by a space, or else it might end up at the beginning of a line and be
visible there; and it needs to be preceded by a space, or else it might
break a line prematurely. How to achieve both of these goals when there
are an even number of spaces to display is left as an exercise for the
reader.

Browsers vary greatly in how they handle all this, of course!

The basic philosophy of IE9 is that if you\'re inserting a space, and
one or both of the neighboring characters is a space, change the
neighboring characters to non-breaking spaces. This breaks if one of the
neighboring characters is part of a run of collapsed whitespace: \"foo
\[\]bar\" becomes \"foo \&nbsp; \[\]bar\", which converts one visible
space to three.

Firefox 6.0a2 will sometimes convert the space you\'re inserting to an
nbsp, sometimes convert neighboring spaces to nbsps, and sometimes
convert neighboring nbsps to spaces. I cannot discern any clear reason
to when it chooses what, except that it seems to prefer runs of nbsp\'s
followed by a single space (although not always). I didn\'t find any
outright bugs, except the inevitable ones like nbsp\'s sometimes being
right after letters.

Chrome 14 dev tries to normalize everything to look like \" \&nbsp;
\&nbsp; \...\", alternating with space then nbsp. Unfortunately, it does
so buggily, because it converts collapsed spaces to nbsp\'s, so
inserting a space before \" \" makes it into \" \&nbsp; \&nbsp;\", which
changes one visible space to four (or arbitrarily many).

Opera 11.11 has varying behavior, like Firefox and Chrome. Like Firefox,
I didn\'t discern an obvious pattern.

This was all
[discussed](http://lists.whatwg.org/pipermail/whatwg-whatwg.org/2011-June/032187.html).

Unfortunately, we\'re stuck with this nbsp stuff, because of 1) legacy
reasons, 2) mail clients might not support CSS equivalents, 3) authors
might not know to apply any CSS to wherever the content is eventually
used. The behavior I decided on to minimize the evil is as follows:

- If the first and last spaces are in non-collapsing positions, two
 spaces is nbsp+space, three is space+nbsp+space, four or more is
 space+nbsp followed by the pattern for two less.
- If the first space has to be an nbsp so it doesn\'t collapse, three is
 instead nbsp+nbsp+space, four or more is nbsp+space followed by the
 pattern for two less.
- If the last space has to be nbsp, two is space+nbsp, three is
 space+nbsp+nbsp, four or more is space+nbsp followed by the pattern
 for two less.
- If the first and last space must both be nbsp, two is nbsp+nbsp, three
 is nbsp+space+nbsp, four or more nbsp+space followed by the pattern
 for two less.

This avoids nbsp at the end of a run except where it\'s needed, so words
won\'t appear indented if they wrap to the next line. It avoids more
than two nbsp\'s in a row, so there won\'t be huge chunks of space that
get wrapped all at once. And it avoids nbsp at the beginning of a run
except where it\'s needed or if there are only two spaces in the run, so
words won\'t have to wrap unnecessarily.

This is still a huge headache, though.

[Action](#action):

1. ::: note
 Chrome 14 dev does the deletion even if the value is empty. Of
 course, other browsers don\'t expose this as an execCommand(), so no
 one else has any defined behavior in this case at all, so I follow
 Chrome.

 IE9, Firefox 7.0a2, Chrome 14 dev, and Opera 11.50 all don\'t strip
 wrappers, except that as usual, Gecko does if you select the whole
 wrapper, like {\<b\>foo\</b\>}. Also, Chrome 14 dev seems to strip
 the wrapper and try recreating the style in cases like
 \<b\>\[foo\</b\>bar\], where it starts in a wrapper but ends after
 it; this doesn\'t always work so well, so I don\'t do it. Firefox
 7.0a2 also has the deletion set overrides for indeterminate state
 commands, so if you run insertText on \[foo\<b\>bar\</b\>baz\] it
 will make the result bold.

 These things don\'t make any sense to me, so I don\'t do them. I set
 overrides based on the first editable text node in the range when
 deleting; preserve any wrappers at the start of the range; and
 restore the overrides in case preserving the wrappers isn\'t enough
 (like if they weren\'t set by deletion at all). This behavior seems
 to closely match IE9.
 :::

 [Delete the selection](#delete-the-selection), with
 `strip wrappers` false.

2. If the [active range](#active-range)\'s \[=range/start node=\] is
 neither [editable](#editable) nor an \[=editing host=\], return
 true.

3. If `value`\'s
 [length](http://es5.github.com/#x15.5.5.1) is greater than one:
 1. For each [code
 unit](http://dev.w3.org/2006/webapi/WebIDL/#dfn-code-unit)
 `el` in `value`, take
 the [action](#action) for [the `insertText`{title=""}
 command](#the-inserttext-command), with `value` equal to `el`.
 2. Return true.

4. If `value` is the empty string, return true.

5. TODO: WebKit also does magic for tabs, wrapping them in a
 whitespace-preserving span. Should we?

 If `value` is a newline (U+000A), take the
 [action](#action) for [the `insertParagraph`{title=""}
 command](#the-insertparagraph-command) and return true.

6. Let `node` and `offset` be
 the [active range](#active-range)\'s \[=range/start node=\] and
 \[=boundary point/offset=\].

7. Just to be tidy, add to an existing text node if there is one.
 Firefox 5.0a2 only adds to an existing one if the range is in a text
 node. IE9, Chrome 14 dev, and Opera 11.11 also add to an existing
 text node if the range is in an element adjacent to a text node. If
 there are two text nodes and it\'s in between, like foobar, IE and
 Opera add to the first, Chrome adds to the second, although it
 probably doesn\'t matter in practice exactly which we choose.

 If `node` has a \[=tree/child=\] whose
 \[=tree/index=\] is `offset` − 1, and that
 \[=tree/child=\] is a {{Text}} node, set `node`
 to that \[=tree/child=\], then set `offset` to
 `node`\'s \[=Node/length=\].

8. If `node` has a \[=tree/child=\] whose
 \[=tree/index=\] is `offset`, and that
 \[=tree/child=\] is a {{Text}} node, set `node`
 to that \[=tree/child=\], then set `offset` to
 zero.

9. [Record current overrides](#record-current-overrides), and let
 `overrides` be the result.

10. Call [`collapse(`{title="dom-Selection-collapse"}`node``, `{title="dom-Selection-collapse"}`offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

11. [Canonicalize whitespace](#canonicalize-whitespace) at
 (`node`, `offset`).

12. Let (`node`, `offset`) be
 the [active range](#active-range)\'s \[=range/start=\].

13. If `node` is a {{Text}} node:
 1. Call [`insertData(``offset``, ``value``)`](http://dom.spec.whatwg.org/#dom-characterdata-insertdata)
 on `node`.
 2. Call
 [`collapse(`{title="dom-Selection-collapse"}`node``, `{title="dom-Selection-collapse"}`offset``)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").
 3. Call [`extend(`{title="dom-Selection-extend"}`node``, `{title="dom-Selection-extend"}`offset`` + 1)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

14. Otherwise:
 1. If some text is inserted into \<p\>\<br\>\</p\> or similar, we
 no longer need the \<br\>.

 If `node` has only one \[=tree/child=\],
 which is a [collapsed line break](#collapsed-line-break), remove
 its \[=tree/child=\] from it.

 2. Let `text` be the result of calling
 [`createTextNode(``value``)`](http://dom.spec.whatwg.org/#dom-document-createtextnode)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object).

 3. Call [`insertNode(``text``)`](http://dom.spec.whatwg.org/#dom-range-insertnode)
 on the [active range](#active-range).

 4. Call
 [`collapse(`{title="dom-Selection-collapse"}`text``, 0)`{title="dom-Selection-collapse"}](#dom-selection-collapse)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

 5. Call [`extend(`{title="dom-Selection-extend"}`text``, 1)`{title="dom-Selection-extend"}](#dom-selection-extend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

15. [Restore states and values](#restore-states-and-values) from
 `overrides`.

16. [Canonicalize whitespace](#canonicalize-whitespace) at the [active
 range](#active-range)\'s \[=range/start=\], with
 `fix collapsed space` false.

17. [Canonicalize whitespace](#canonicalize-whitespace) at the [active
 range](#active-range)\'s \[=range/end=\], with
 `fix collapsed space` false.

18. If `value` is a [space
 character](http://encoding.spec.whatwg.org/#ascii-whitespace "ascii whitespace"), [autolink](#autolink) the [active
 range](#active-range)\'s \[=range/start=\].

19. Call
 [`collapseToEnd()`{title="dom-Selection-collapseToEnd"}](#dom-selection-collapsetoend)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s
 [selection](#concept-selection "concept-selection").

20. Return true.

### [The `insertUnorderedList`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Preserves overrides](#preserves-overrides)

See comments for [insertOrderedList](#the-insertorderedlist-command).

[Action](#action): [Toggle lists](#toggle-lists) with
`tag name` \"ul\", then return true.

[Indeterminate](#indeterminate): True if the [selection\'s list
state](#selection's-list-state) is \"mixed\" or \"mixed ul\", false
otherwise.

[State](#state): True if the [selection\'s list
state](#selection's-list-state) is \"ul\", false otherwise.

### [The `justifyCenter`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Preserves overrides](#preserves-overrides)

[Action](#action): [Justify the selection](#justify-the-selection) with
`alignment` \"center\", then return true.

This roughly matches Chrome 14 dev, although not exactly. Firefox 6.0a2
always returns false.

As a general rule, ignoring nodes with children saves us from treating
\<div align=left\>\<div align=center\>foo\</div\>\</div\> as though
it\'s indeterminate. Chrome 14 dev seems to only pay attention to text
nodes, instead, or something like that. At any rate, it fails on images.
Firefox 6.0a2 (for state and value) gets tripped up by examples like the
one given.

If we ever support centering of tables and similar, we\'d want to pay
attention even to some nodes that do have children.

[Indeterminate](#indeterminate): Return false if the [active
range](#active-range) is null. Otherwise, [block-extend](#block-extend)
the [active range](#active-range). Return true if among
[visible](#visible) [editable](#editable)
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") that are
[contained](http://dom.spec.whatwg.org/#contained) in the result and have no \[=tree/children=\], at
least one has [alignment value](#alignment-value) \"center\" and at
least one does not. Otherwise return false.

IE9 throws exceptions in almost every case when querying the state of
justify\*, and Opera 11.11 returns false in every case except some
seemingly random crazy ones.

Firefox 6.0a2 returns true for the state of justify\* if anything in the
range has the right alignment, not if everything does. This isn\'t
consistent with how state works for the inline commands, nor with
WebKit.

Chrome 14 dev counts text-align on inline elements, which is wrong,
because the property has no effect. It also counts it on non-editable
elements, which is wrong, because then the state for justify\* wouldn\'t
necessarily be true after executing it. (Chrome actually does align the
non-editable elements, but that\'s just a bug.) Chrome further returns
false for justify\* if the justification is just the default inherited
justification, e.g., left for LTR. This doesn\'t seem to make sense
either.

State is kind of redundant here, because it\'s true if and only if
indeterminate is false and the value is equal to the desired value.
However, I\'ll support it anyway, since Gecko/WebKit do.

[State](#state): Return false if the [active range](#active-range) is
null. Otherwise, [block-extend](#block-extend) the [active
range](#active-range). Return true if there is at least one
[visible](#visible) [editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is
[contained](http://dom.spec.whatwg.org/#contained) in the result and has no \[=tree/children=\], and all
such
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") have [alignment value](#alignment-value) \"center\".
Otherwise return false.

Not bidi-safe, but it\'s a pretty marginal corner case where it fails.
Firefox 6.0a2 behaves weirdly here: it keys off the start node of the
active range, even if that\'s not contained. Thus {\<div
align=center\>foo\</div\>} has value \"left\" and indeterminate false,
which would suggest that the whole selection is aligned left, but
that\'s not the case. Chrome 14 dev returns the state cast to a string,
as usual. Opera 11.11 always returns the empty string.

[Value](#value): Return the empty string if the [active
range](#active-range) is null. Otherwise, [block-extend](#block-extend)
the [active range](#active-range), and return the [alignment
value](#alignment-value) of the first [visible](#visible)
[editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is
[contained](http://dom.spec.whatwg.org/#contained) in the result and has no \[=tree/children=\]. If
there is no such
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"), return \"left\".

### [The `justifyFull`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Preserves overrides](#preserves-overrides)

[Action](#action): [Justify the selection](#justify-the-selection) with
`alignment` \"justify\", then return true.

[Indeterminate](#indeterminate): Return false if the [active
range](#active-range) is null. Otherwise, [block-extend](#block-extend)
the [active range](#active-range). Return true if among
[visible](#visible) [editable](#editable)
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") that are
[contained](http://dom.spec.whatwg.org/#contained) in the result and have no \[=tree/children=\], at
least one has [alignment value](#alignment-value) \"justify\" and at
least one does not. Otherwise return false.

[State](#state): Return false if the [active range](#active-range) is
null. Otherwise, [block-extend](#block-extend) the [active
range](#active-range). Return true if there is at least one
[visible](#visible) [editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is
[contained](http://dom.spec.whatwg.org/#contained) in the result and has no \[=tree/children=\], and all
such
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") have [alignment value](#alignment-value) \"justify\".
Otherwise return false.

[Value](#value): Return the empty string if the [active
range](#active-range) is null. Otherwise, [block-extend](#block-extend)
the [active range](#active-range), and return the [alignment
value](#alignment-value) of the first [visible](#visible)
[editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is
[contained](http://dom.spec.whatwg.org/#contained) in the result and has no \[=tree/children=\]. If
there is no such
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"), return \"left\".

### [The `justifyLeft`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Preserves overrides](#preserves-overrides)

[Action](#action): [Justify the selection](#justify-the-selection) with
`alignment` \"left\", then return true.

[Indeterminate](#indeterminate): Return false if the [active
range](#active-range) is null. Otherwise, [block-extend](#block-extend)
the [active range](#active-range). Return true if among
[visible](#visible) [editable](#editable)
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") that are
[contained](http://dom.spec.whatwg.org/#contained) in the result and have no \[=tree/children=\], at
least one has [alignment value](#alignment-value) \"left\" and at least
one does not. Otherwise return false.

[State](#state): Return false if the [active range](#active-range) is
null. Otherwise, [block-extend](#block-extend) the [active
range](#active-range). Return true if there is at least one
[visible](#visible) [editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is
[contained](http://dom.spec.whatwg.org/#contained) in the result and has no \[=tree/children=\], and all
such
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") have [alignment value](#alignment-value) \"left\".
Otherwise return false.

[Value](#value): Return the empty string if the [active
range](#active-range) is null. Otherwise, [block-extend](#block-extend)
the [active range](#active-range), and return the [alignment
value](#alignment-value) of the first [visible](#visible)
[editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is
[contained](http://dom.spec.whatwg.org/#contained) in the result and has no \[=tree/children=\]. If
there is no such
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"), return \"left\".

### [The `justifyRight`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Preserves overrides](#preserves-overrides)

[Action](#action): [Justify the selection](#justify-the-selection) with
`alignment` \"right\", then return true.

[Indeterminate](#indeterminate): Return false if the [active
range](#active-range) is null. Otherwise, [block-extend](#block-extend)
the [active range](#active-range). Return true if among
[visible](#visible) [editable](#editable)
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") that are
[contained](http://dom.spec.whatwg.org/#contained) in the result and have no \[=tree/children=\], at
least one has [alignment value](#alignment-value) \"right\" and at least
one does not. Otherwise return false.

[State](#state): Return false if the [active range](#active-range) is
null. Otherwise, [block-extend](#block-extend) the [active
range](#active-range). Return true if there is at least one
[visible](#visible) [editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is
[contained](http://dom.spec.whatwg.org/#contained) in the result and has no \[=tree/children=\], and all
such
[nodes](http://dom.spec.whatwg.org/#concept-node "concept-node") have [alignment value](#alignment-value) \"right\".
Otherwise return false.

[Value](#value): Return the empty string if the [active
range](#active-range) is null. Otherwise, [block-extend](#block-extend)
the [active range](#active-range), and return the [alignment
value](#alignment-value) of the first [visible](#visible)
[editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node") that is
[contained](http://dom.spec.whatwg.org/#contained) in the result and has no \[=tree/children=\]. If
there is no such
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"), return \"left\".

### [The `outdent`{title=""} command]

This command must not be enabled if the [editing host]
is in the *plaintext-only* state.

[Preserves overrides](#preserves-overrides)

[Action](#action):

1. Let `items` be a list of all \[\^li\^\]s that
 are \[=tree/inclusive ancestors=\] of the [active
 range](#active-range)\'s \[=range/start=\] and/or \[=range/end=\]
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node").

2. TODO: This overnormalizes, but it seems like the simplest solution
 for now.

 For each `item` in `items`,
 [normalize sublists](#normalize-sublists) of `item`.

3. [Block-extend](#block-extend) the [active range](#active-range), and
 let `new range` be the result.

4. Let `node list` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.

5. ::: note
 This step is kind of weird. For regular outdenting, we start at the
 inside and outdent going out, so that we remove the innermost
 indentation, on the theory that that will produce the cleanest
 markup (remove the most nodes). For lists, we remove the outermost
 indentation, because it makes a difference whether we remove inner
 or outer indentation, and logically we want to remove outer. E.g.,

 <ol><li>foo</li><ul><li>bar</li></ul></ol>

 should become

 foo<ul><li>bar</li></ul>

 not

 foo<ol><li>bar</li></ol>.

 But this is a bit weird and I\'m wondering if it\'s really correct.
 TODO: Reexamine this.
 :::

 For each
 [node](http://dom.spec.whatwg.org/#concept-node "concept-node") `node`
 [contained](http://dom.spec.whatwg.org/#contained) in `new range`, append
 `node` to `node list` if the
 last member of `node list` (if any) is not an
 \[=tree/ancestor=\] of `node`; `node` is [editable](#editable); and either `node` has no [editable](#editable) \[=tree/descendants=\], or is
 an \[\^ol\^\] or \[\^ul\^\], or is an \[\^li\^\] whose
 \[=tree/parent=\] is an \[\^ol\^\] or \[\^ul\^\].

6. While `node list` is not empty:
 1. While the first member of `node list` is an
 \[\^ol\^\] or \[\^ul\^\] or is not the \[=tree/child=\] of an
 \[\^ol\^\] or \[\^ul\^\], [outdent](#outdent) it and remove it
 from `node list`.
 2. If `node list` is empty, break from these
 substeps.
 3. Let `sublist` be a list of
 [nodes](http://dom.spec.whatwg.org/#concept-node "concept-node"), initially empty.
 4. Remove the first member of `node list` and
 append it to `sublist`.
 5. While the first member of `node list` is the
 {{Node/nextSibling}} of the last member of `sublist`, and the first member of `node list` is not an \[\^ol\^\] or \[\^ul\^\], remove the first
 member of `node list` and append it to
 `sublist`.
 6. [Record the values](#record-the-values) of `sublist`, and let `values` be the result.
 7. [Split the parent](#split-the-parent) of `sublist`.
 8. [Fix disallowed ancestors](#fix-disallowed-ancestors) of each
 member of `sublist`.
 9. [Restore the values](#restore-the-values) from
 `values`.

7. Return true.

## Clipboard commands

### [The `copy`{title=""} command]

[Action](#action): The user agent must either copy the current selection
to the clipboard as though the user had requested it, or
\[=exception/throw=\] a {{\"SecurityError\"}} exception.

If an implementation supports the document.execCommand method and allows
calling it with the commands \"copy\", the implementation *must* trigger
the [copy
action](https://w3c.github.io/clipboard-apis/#the-copy-action), which
again will dispatch the \"copy\" clipboard event, if the \"copy\" action
did not throw a SecurityError exception.

These are the steps to follow when triggering copy actions through the
document.execCommand() API:

1. Set the action\'s *script-triggered* flag.
2. If the script thread is allowed to modify the clipboard, set the
 action\'s *script-may-access-clipboard* flag, otherwise throw a
 SecurityError and break.
3. Dispatch the copy event synchronously.
4. If the copy event is not canceled, execute the copy action
 synchronously.
5. Use the action\'s return value as the return value for the
 document.execCommand() call.

Copy commands triggered from document.execCommand() will only affect the
contents of the real clipboard if the event is dispatched from an event
that is trusted and triggered by the user, or if the implementation is
configured to allow this. How implementations can be configured to allow
write access to the clipboard is outside the scope of this
specification.

IE9 supports copy with a security warning.

### [The `cut`{title=""} command]

[Action](#action): The user agent must either copy the current selection
to the clipboard and then delete it, as though the user had requested
it, or \[=exception/throw=\] a {{\"SecurityError\"}} exception.

If an implementation supports the document.execCommand method and allows
calling it with the commands \"cut\", the implementation *must* trigger
the [cut action](https://w3c.github.io/clipboard-apis/#the-cut-action),
which again will dispatch the \"cut\" clipboard event.

These are the steps to follow when triggering cut actions through the
document.execCommand() API:

1. Set the action\'s *script-triggered* flag.
2. If the script thread is allowed to modify the clipboard, set the
 action\'s *script-may-access-clipboard* flag, otherwise throw a
 SecurityError and break.
3. Dispatch the cut event synchronously.
4. If the cut event is not canceled, execute the cut action
 synchronously.
5. Use the action\'s return value as the return value for the
 document.execCommand() call.

Cut commands triggered from document.execCommand() will only affect the
contents of the real clipboard if the event is dispatched from an event
that is trusted and triggered by the user, or if the implementation is
configured to allow this. How implementations can be configured to allow
write access to the clipboard is outside the scope of this
specification.

IE9 supports cut with a security warning.

### [The `paste`{title=""} command]

[Action](#action): The user agent must either [delete the
selection](#delete-the-selection) and then paste the clipboard\'s
contents to the current cursor position, as though the user had
requested it, or \[=exception/throw=\] a {{\"SecurityError\"}}
exception.

If an implementation supports the document.execCommand method and allows
calling it with the commands \"paste\", the implementation *must*
trigger the [paste
action](https://w3c.github.io/clipboard-apis/#the-paste-action), which
again will dispatch the \"paste\" clipboard event.

These are the steps to follow when triggering paste actions through the
document.execCommand() API:

1. Set the action\'s *script-triggered* flag.
2. If the script thread is allowed to read from the clipboard, set the
 action\'s *script-may-access-clipboard* flag, otherwise throw a
 SecurityError and break.
3. Dispatch the paste event synchronously.
4. If the paste event is not canceled, execute the paste action
 synchronously.
5. Use the action\'s return value as the return value for the
 document.execCommand() call.

Paste commands triggered from document.execCommand() will only give
access to the contents of the real clipboard if the event is dispatched
from an event that is trusted and triggered by the user, or if the
implementation is configured to allow this. How implementations can be
configured to allow read access to the clipboard is outside the scope of
this specification.

IE9 supports paste with a security warning. Firefox reportedly only
supports it if you set a pref.

## Miscellaneous commands

### [The `defaultParagraphSeparator`{title=""} command]

This is a new feature, added by request in [bug
15527](https://www.w3.org/Bugs/Public/show_bug.cgi?id=15527). (Opera
already had an o-defaultblock command that worked similarly.) **If you
are implementing this, please make sure to file any feedback as bugs.
The spec is not finalized yet and can still be easily changed.**

[Action](#action): Let `value` be [converted to
ASCII
lowercase](http://dom.spec.whatwg.org/#converted-to-ascii-lowercase). If `value` is then equal to
\"p\" or \"div\", set the [context
object](http://dom.spec.whatwg.org/#context-object)\'s [default single-line container
name](#default-single-line-container-name) to `value`, then return true. Otherwise, return false.

[Value](#value): Return the [context
object](http://dom.spec.whatwg.org/#context-object)\'s [default single-line container
name](#default-single-line-container-name).

### [The `redo`{title=""} command]

[Action](#action): As defined by the
[UndoManager](https://github.com/WebKit/explainers/tree/main/UndoManager)
specification.

### [The `selectAll`{title=""} command]

This is totally broken: if executed inside an editing host, it has to
select the editing host contents, not the whole document. See
[bug](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13840).

Tested using roughly
[this](http://software.hixie.ch/utilities/js/live-dom-viewer/saved/1018).

IE9
: A bit confusing. The gist seems to be that it does
 selectAllChildren() on the body, except sometimes it doesn\'t.

Firefox 5.0a2
: Throws an exception if nothing in the document is editable, which
 apparently it always does for execCommand(). If there\'s a body, it
 does selectAllChildren() on that, and otherwise it does
 selectAllChildren() on the root element. If there\'s no root
 element, throws an exception.

Chrome 13 dev
: If there\'s no root element, removes the selection. If there\'s a
 root element but no body, collapses the selection at (document, 0).
 If there\'s a body, it selects all the contents of the body,
 although that doesn\'t mean the resulting anchor or focus actually
 are the body node (they\'re usually text nodes). But it seems to
 \*avoid\* selecting contenteditable stuff: if all the visible things
 in the body are contenteditable, it removes all ranges from the
 selection, and if some are, it freaks out and behaves oddly. But
 designMode doesn\'t trouble it.

Opera 11.11
: Was characteristically uncooperative in my tests, and I didn\'t try
 to investigate further.

The behavior here is relatively simple and largely matches
implementations.

[Action](#action):

1. TODO: Is this right even for framesets?

 Let `target` be [the body
 element](http://www.whatwg.org/specs/web-apps/current-work/multipage/dom.html#the-body-element-0 "the-body-element-0") of the [context
 object](http://dom.spec.whatwg.org/#context-object).

 TODO: Is this right even for documents whose root element is not an
 HTML element?

 If `target` is null, let `target` be the [context
 object](http://dom.spec.whatwg.org/#context-object)\'s {{Document/documentElement}}.

2. If `target` is null, call
 [`getSelection()`{title="dom-Document-getSelection"}](#dom-document-getselection)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object), and call
 [`removeAllRanges()`{title="dom-Selection-removeAllRanges"}](#dom-selection-removeallranges)
 on the result.

3. Otherwise, call
 [`getSelection()`{title="dom-Document-getSelection"}](#dom-document-getselection)
 on the [context
 object](http://dom.spec.whatwg.org/#context-object), and call
 [`selectAllChildren(`{title="dom-Selection-selectAllChildren"}`target``)`{title="dom-Selection-selectAllChildren"}](#dom-selection-selectallchildren)
 on the result.

4. Return true.

### [The `styleWithCSS`{title=""} command]

IE9 and Opera 11.00 don\'t support this command. By and large, they act
the way Gecko and WebKit do when styleWithCSS is off. Gecko invented it,
and WebKit also
[supports](https://bugs.webkit.org/show_bug.cgi?id=13490) it. The
default in Firefox 4.0 is off, while all other browsers behave like the
default is on (and IE/Opera give no way to turn it off), so I default it
to on.

Handling of `value` matches Firefox 5.0a2. Chrome 13
dev treats the case-sensitive string \"true\" as true, the
case-sensitive string \"false\" as false, and does nothing for any other
string. I went with Gecko because this way there are only two possible
effects, not three, which makes it easier to reason about and debug.
Also, Gecko made up the command, so this is probably more
web-compatible. Cursory searches of Google Code and GitHub suggest that
authors almost always pass a boolean as the third argument when using
styleWithCSS, in which case the two behaviors work the same.

[Action](#action): If `value` is an [ASCII
case-insensitive](http://dom.spec.whatwg.org/#ascii-case-insensitive) match for the string \"false\", set the [CSS
styling flag](#css-styling-flag) to false. Otherwise, set the [CSS
styling flag](#css-styling-flag) to true. Either way, return true.

This follows Chrome 13 dev. Firefox 5.0a2 doesn\'t support
queryCommandState() for styleWithCSS.

[State](#state): True if the [CSS styling flag](#css-styling-flag) is
true, otherwise false.

### [The `undo`{title=""} command]

[Action](#action): As defined by the
[UndoManager](https://github.com/WebKit/explainers/tree/main/UndoManager)
specification.

### [The `useCSS` command]

\[=Action=\]: If `value` is an \[=ASCII case-insensitive=\]
match for the string \"false\", set the \[=CSS styling flag=\] to true.
Otherwise, set the \[=CSS styling flag=\] to false. Either way, return
true.

This command works the same as \[=the styleWithCSS
command\|styleWithCSS=\] but with the opposite values and with no
[queryCommandState()] support. Authors
are encouraged to use \[=the styleWithCSS command=\] instead.

## Dependencies

The Trusted Types \[\[TRUSTED-TYPES\]\] specification defines:

- The
 [[TrustedHTML](https://w3c.github.io/trusted-types/dist/spec/#trustedhtml)] IDL interface

## Additional requirements

It has been
[suggested](http://lists.whatwg.org/htdig.cgi/whatwg-whatwg.org/2009-December/024628.html)
that some things here need to be platform-dependent, not fully
standardized. For now I\'m standardizing them anyway, because the large
majority of behavior should be platform-agnostic. If anyone has
suggestions as to particular things that should be left up to platform
behavior, please say so.

When the user instructs the user agent to insert a line break inside an
\[=editing host=\], such as by pressing the Enter key while the cursor
is in an [editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"), the user agent must call
[`execCommand("insertparagraph")`{title="execCommand()"}](#execcommand())
on the relevant \[=document=\].

When the user instructs the user agent to insert a line break inside an
\[=editing host=\] without breaking out of the current block, such as by
pressing Shift-Enter or Option-Enter while the cursor is in an
[editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"), the user agent must call
[`execCommand("insertlinebreak")`{title="execCommand()"}](#execcommand())
on the relevant \[=document=\].

When the user instructs the user agent to delete the previous character
inside an \[=editing host=\], such as by pressing the Backspace key
while the cursor is in an [editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"), the user agent must call
[`execCommand("delete")`{title="execCommand()"}](#execcommand()) on the
relevant \[=document=\].

When the user instructs the user agent to delete the next character
inside an \[=editing host=\], such as by pressing the Delete key while
the cursor is in an [editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"), the user agent must call
[`execCommand("forwarddelete")`{title="execCommand()"}](#execcommand())
on the relevant \[=document=\].

When the user instructs the user agent to insert text inside an
\[=editing host=\], such as by typing on the keyboard while the cursor
is in an [editable](#editable)
[node](http://dom.spec.whatwg.org/#concept-node "concept-node"), the user agent must call
[`execCommand("inserttext", false, `{title="execCommand()"}`value``)`{title="execCommand()"}](#execcommand()) on the relevant
\[=document=\], with `value` equal to the text the
user provided. If the user inserts multiple characters at once or in
quick succession, this specification does not define whether it is
treated as one insertion or several consecutive insertions.

[Bug 13938](https://www.w3.org/Bugs/Public/show_bug.cgi?id=13938).

The user agent may allow the user to make other changes to editable
content, such as causing Ctrl-B to call
[`execCommand("bold")`{title="execCommand()"}](#execcommand()), when the
[editing host] is in the *true* state. Any such change
must be accomplished by calling [`execCommand()`](#execcommand()), so
that in particular, \"beforeinput\" and \"input\" events fire as
appropriate. The [command](#command) invoked should be one of the
standard [commands](#command "command") defined in this specification if
possible, and otherwise must be a [vendor-specific
command](#vendor-specific-command).

## Acknowledgements

Thanks to:

- Google and Mozilla, for initially funding this work
- Ian Hickson, for overseeing it initially
- Ian Hickson and Ms2ger, for starting the selection work
- Julie Parent, Ojan Vafai, Alex Russel, and Eric Seidel for their
 [research](http://lists.whatwg.org/htdig.cgi/whatwg-whatwg.org/2009-December/024627.html)
 on how browsers and other rich text editors behave in many common
 scenarios
- Ehsan Akhgari, Tab Atkins, Mathias Bynens, Tim Down, Markus Ernst,
 Daniel Glazman, Tali Gregor (née Fuss), Stig Halvorsen, Jeff Harris,
 Ian Hickson, Cameron Heavon-Jones, Anne van Kesteren, Alfonso Martínez
 de Lizarrondo, Glenn Maynard, Ms2ger, Ryosuke Niwa, Robert
 O\'Callahan, Julie Parent, Simon Pieters, Michael A. Puls II, Rich
 Schwerdtfeger, Jonas Sicking, Henri Sivonen, Smylers, Hallvord R. M.
 Steen, Roland Steiner, Annie Sullivan, timeless, Ojan Vafai, Brett
 Zamir, and Boris Zbarsky for their feedback, participation, or other
 helpful contributions
