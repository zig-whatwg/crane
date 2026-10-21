
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# Core Accessibility API Mappings 1.2

[W3C Editor\'s Draft](https://www.w3.org/standards/types#ED) 02 July
2026

More details about this document

This version:
: [https://w3c.github.io/core-aam/](https://w3c.github.io/core-aam/)

Latest published version:
: <https://www.w3.org/TR/core-aam-1.2/>

Latest editor\'s draft:
: <https://w3c.github.io/core-aam/>

History:
: <https://www.w3.org/standards/history/core-aam-1.2/>
: [Commit history](https://github.com/w3c/aria/commits/main/core-aam/)

Implementation report:
: <https://w3c.github.io/test-results/core-aam-1.2/>

Latest Recommendation:
: <https://www.w3.org/TR/core-aam-1.1/>

Editors:
: [Valerie Young] ([Igalia,
 S.L.](https://www.igalia.com))
: [Cynthia Shelly](mailto:buphie@gmail.com) ([W3C Invited Expert])

Former editors:
: [Alexander Surkov] ([Igalia,
 S.L.](https://www.igalia.com)) (Editor until
 August 2025)
: [Joanmarie Diggs] ([Igalia,
 S.L.](https://www.igalia.com)) (Editor until
 October 2022)
: [Richard Schwerdtfeger]
 ([Knowbility](https://www.knowbility.org/))
 (Editor until October 2017)
: [Joseph Scheuhammer] ([Inclusive Design Research
 Centre, OCAD University](http://idrc.ocad.ca))
 (Editor until May 2017)
: [Andi Snow-Weaver] ([IBM](http://www.ibm.com)) (Editor until December 2012)
: [Aaron Leventhal] ([IBM](http://www.ibm.com)) (Editor until January 2009)
: [Michael Cooper] ([W3C](https://www.w3.org)) (Editor until July 2023)

Platform Mapping Maintainers:
: [Benjamin Beaudry] ([Microsoft
 Corp.](https://microsoft.com/)) (UIA)
: [James Craig] ([Apple,
 Inc.](https://apple.com/accessibility)) (AX API)
: [Joanmarie Diggs] ([Igalia,
 S.L.](https://www.igalia.com)) (ATK / AT-SPI)
: [Alexander Surkov] ([Igalia,
 S.L.](https://www.igalia.com)) (MSAA,
 IAccessible2)
: [David Tseng] ([Google LLC])
 (Android Accessibility API)

Feedback:
: [GitHub w3c/core-aam](https://github.com/w3c/core-aam/) ([pull
 requests](https://github.com/w3c/aria/pulls?q=is%3Apr+is%3Aopen+label%3A%22spec%3Acore-aam%22),
 [new issue](https://github.com/w3c/core-aam/issues/new/choose),
 [open issues](https://github.com/w3c/core-aam/issues/))

[Copyright](https://www.w3.org/policies/#copyright) © 2014-2026 [World
Wide Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

This document describes how [user
agents](https://infra.spec.whatwg.org/#user-agent)
should expose semantics of web content languages to [accessibility
[APIs]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api). This helps users with disabilities to
obtain and interact with information using [assistive
technologies](https://www.w3.org/TR/wai-aria/#assistive-technology). Documenting these mappings promotes
interoperable exposure of roles, states, properties, and events
implemented by accessibility [APIs] and helps to ensure that
this information appears in a manner consistent with author intent.

This Core Accessibility [API] Mappings specification
defines support that applies across multiple content technologies,
including general keyboard navigation support and mapping of
general-purpose
[roles](https://www.w3.org/TR/wai-aria-1.3/#dfn-role), states, and
properties provided in Web content via [[WAI-ARIA]](http://www.w3.org/TR/wai-aria-1.2/)
\[[WAI-ARIA-1.2](#bib-wai-aria-1-2 "Accessible Rich Internet Applications (WAI-ARIA) 1.2")\]. Other Accessibility [API] Mappings specifications
depend on and extend this Core specification for specific technologies,
including native technology features and [WAI-ARIA] extensions. This document
updates and will eventually supersede the guidance in the [Core
Accessibility [API]
Mappings 1.1](http://www.w3.org/TR/core-aam-1.1/)
\[[CORE-AAM-1.1](#bib-core-aam-1-1 "Core Accessibility API Mappings 1.1")\] [W3C]
Recommendation. It is part of the [WAI-ARIA] suite described in the
[[WAI-ARIA]
Overview](http://www.w3.org/WAI/intro/aria.php).

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

The Accessible Rich Internet Applications Working Group seeks feedback
on any aspect of the specification. When submitting feedback, please
consider issues in the context of the companion documents. To comment,
[file an issue in the [W3C]
core-aam GitHub repository](https://github.com/w3c/core-aam/issues/new).
If this is not feasible, send email to
[public-aria@w3.org](mailto:public-aria@w3.org?subject=Comment%20on%20Core-AAM%201.2)
([comment archive](http://lists.w3.org/Archives/Public/public-aria/)).
In-progress updates to the document may be viewed in the [publicly
visible editors\' draft](http://w3c.github.io/core-aam/).

**Living specification** --- This document is maintained as a living
specification. For the latest normative version, visit [Core
Accessibility [API]
Mappings](https://www.w3.org/TR/core-aam-1.2/).

This document was published by the [Accessible Rich Internet
Applications Working Group](https://www.w3.org/groups/wg/aria) as an
Editor\'s Draft.

Publication as an Editor\'s Draft does not imply endorsement by
[W3C] and its Members.

This is a draft document and may be updated, replaced, or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than a work in progress.

This document was produced by a group operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/aria/ipr){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent that the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the
[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

This document is governed by the [18 August 2025 [W3C] Process
Document](https://www.w3.org/policies/process/20250818/).

## Table of Contents

1. [Abstract](#abstract)
2. [Status of This Document](#sotd)
3. [1. Introduction](#intro)
 1. [1.1 Accessibility [APIs]](#intro_aapi)
 2. [1.2 Comparing Accessibility [APIs]](#comparing-accessibility-apis)
 1. [1.2.1 [ATK]/[AT]-SPI](#atk-at-spi)
 2. [1.2.2 [UIA] (UI
 Automation)](#uia-ui-automation)
 3. [1.2.3 Android Accessibility [API]](#android-accessibility-api)
 4. [1.2.4 Accessible Names and
 Descriptions](#accessible-names-and-descriptions)
4. [2. Conformance](#conformance)
 1. [2.1 Features Deprecated in [WAI-ARIA]](#features-deprecated-in-wai-aria)
5. [3. Mapping [WAI-ARIA] to Accessibility
 [APIs]](#mapping)
 1. [3.1 General rules for exposing [WAI-ARIA]
 semantics](#mapping_general)
 2. [3.2 Conflicts between native markup semantics and
 [WAI-ARIA]](#mapping_conflicts)
 3. [3.3 Exposing attributes that do not directly map to
 accessibility [API]
 properties](#mapping_nodirect)
 4. [3.4 Role mapping](#mapping_role)
 1. [3.4.1 General rules](#roleMappingGeneralRules)
 2. [3.4.2 Computed Role](#roleMappingComputedRole)
 3. [3.4.3 Role Mapping Tables](#mapping_role_table)
 1. [3.4.3.1 `alert`](#role-map-alert)
 2. [3.4.3.2 `alertdialog`](#role-map-alertdialog)
 3. [3.4.3.3 `application`](#role-map-application)
 4. [3.4.3.4 `article`](#role-map-article)
 5. [3.4.3.5 `banner`](#role-map-banner)
 6. [3.4.3.6 `blockquote`](#role-map-blockquote)
 7. [3.4.3.7 `button` with default values for `aria-pressed`
 and `aria-haspopup`](#role-map-button)
 8. [3.4.3.8 `button` with non-`false` value for
 `aria-haspopup`](#role-map-button-haspopup)
 9. [3.4.3.9 `button` with defined value for
 `aria-pressed`](#role-map-button-pressed)
 10. [3.4.3.10 `caption`](#role-map-caption)
 11. [3.4.3.11 `cell`](#role-map-cell)
 12. [3.4.3.12 `checkbox`](#role-map-checkbox)
 13. [3.4.3.13 `code`](#role-map-code)
 14. [3.4.3.14
 `columnheader`](#role-map-columnheader)
 15. [3.4.3.15 `combobox`](#role-map-combobox)
 16. [3.4.3.16 `comment`](#role-map-comment)
 17. [3.4.3.17
 `complementary`](#role-map-complementary)
 18. [3.4.3.18
 `contentinfo`](#role-map-contentinfo)
 19. [3.4.3.19 `definition`](#role-map-definition)
 20. [3.4.3.20 `deletion`](#role-map-deletion)
 21. [3.4.3.21 `dialog`](#role-map-dialog)
 22. [3.4.3.22 `directory`
 (deprecated)](#role-map-directory)
 23. [3.4.3.23 `document`](#role-map-document)
 24. [3.4.3.24 `emphasis`](#role-map-emphasis)
 25. [3.4.3.25 `feed`](#role-map-feed)
 26. [3.4.3.26 `figure`](#role-map-figure)
 27. [3.4.3.27 `form` with an accessible
 name](#role-map-form)
 28. [3.4.3.28 `form` without an accessible
 name](#role-map-form-nameless)
 29. [3.4.3.29 `generic`](#role-map-generic)
 30. [3.4.3.30 `grid`](#role-map-grid)
 31. [3.4.3.31 `gridcell`](#role-map-gridcell)
 32. [3.4.3.32 `group`](#role-map-group)
 33. [3.4.3.33 `heading`](#role-map-heading)
 34. [3.4.3.34 `image`](#role-map-image)
 35. [3.4.3.35 `img`](#role-map-img)
 36. [3.4.3.36 `insertion`](#role-map-insertion)
 37. [3.4.3.37 `link`](#role-map-link)
 38. [3.4.3.38 `list`](#role-map-list)
 39. [3.4.3.39 `listbox` without an accessibility parent of
 `combobox`](#role-map-listbox)
 40. [3.4.3.40 `listbox` with an accessibility parent of
 `combobox`](#role-map-listbox-in-combobox)
 41. [3.4.3.41 `listitem`](#role-map-listitem)
 42. [3.4.3.42 `log`](#role-map-log)
 43. [3.4.3.43 `main`](#role-map-main)
 44. [3.4.3.44 `mark`](#role-map-mark)
 45. [3.4.3.45 `marquee`](#role-map-marquee)
 46. [3.4.3.46 `math`](#role-map-math)
 47. [3.4.3.47 `menu`](#role-map-menu)
 48. [3.4.3.48 `menubar`](#role-map-menubar)
 49. [3.4.3.49 `menuitem`](#role-map-menuitem)
 50. [3.4.3.50
 `menuitemcheckbox`](#role-map-menuitemcheckbox)
 51. [3.4.3.51
 `menuitemradio`](#role-map-menuitemradio)
 52. [3.4.3.52 `meter`](#role-map-meter)
 53. [3.4.3.53 `navigation`](#role-map-navigation)
 54. [3.4.3.54 `none`](#role-map-none)
 55. [3.4.3.55 `note`](#role-map-note)
 56. [3.4.3.56 `option` not inside
 `combobox`](#role-map-option)
 57. [3.4.3.57 `option` inside
 `combobox`](#role-map-option-in-combobox)
 58. [3.4.3.58 `paragraph`](#role-map-paragraph)
 59. [3.4.3.59
 `presentation`](#role-map-presentation)
 60. [3.4.3.60
 `progressbar`](#role-map-progressbar)
 61. [3.4.3.61 `radio`](#role-map-radio)
 62. [3.4.3.62 `radiogroup`](#role-map-radiogroup)
 63. [3.4.3.63 `region` with an accessible
 name](#role-map-region)
 64. [3.4.3.64 `region` without an accessible
 name](#role-map-region-nameless)
 65. [3.4.3.65 `row` not inside
 `treegrid`](#role-map-row)
 66. [3.4.3.66 `row` inside
 `treegrid`](#role-map-row-in-treegrid)
 67. [3.4.3.67 `rowgroup`](#role-map-rowgroup)
 68. [3.4.3.68 `rowheader`](#role-map-rowheader)
 69. [3.4.3.69 `scrollbar`](#role-map-scrollbar)
 70. [3.4.3.70 `search`](#role-map-search)
 71. [3.4.3.71 `searchbox`](#role-map-searchbox)
 72. [3.4.3.72
 `sectionfooter`](#role-map-sectionfooter)
 73. [3.4.3.73
 `sectionheader`](#role-map-sectionheader)
 74. [3.4.3.74 `separator`
 (non-focusable)](#role-map-separator)
 75. [3.4.3.75 `separator`
 (focusable)](#role-map-separator-focusable)
 76. [3.4.3.76 `slider`](#role-map-slider)
 77. [3.4.3.77 `spinbutton`](#role-map-spinbutton)
 78. [3.4.3.78 `status`](#role-map-status)
 79. [3.4.3.79 `strong`](#role-map-strong)
 80. [3.4.3.80 `subscript`](#role-map-subscript)
 81. [3.4.3.81 `suggestion`](#role-map-suggestion)
 82. [3.4.3.82
 `superscript`](#role-map-superscript)
 83. [3.4.3.83 `switch`](#role-map-switch)
 84. [3.4.3.84 `tab`](#role-map-tab)
 85. [3.4.3.85 `table`](#role-map-table)
 86. [3.4.3.86 `tablist`](#role-map-tablist)
 87. [3.4.3.87 `tabpanel`](#role-map-tabpanel)
 88. [3.4.3.88 `term`](#role-map-term)
 89. [3.4.3.89 `textbox` when `aria-multiline` is
 `false`](#role-map-textbox)
 90. [3.4.3.90 `textbox` when `aria-multiline` is
 `true`](#role-map-textbox-multiline)
 91. [3.4.3.91 `time`](#role-map-time)
 92. [3.4.3.92 `timer`](#role-map-timer)
 93. [3.4.3.93 `toolbar`](#role-map-toolbar)
 94. [3.4.3.94 `tooltip`](#role-map-tooltip)
 95. [3.4.3.95 `tree`](#role-map-tree)
 96. [3.4.3.96 `treegrid`](#role-map-treegrid)
 97. [3.4.3.97 `treeitem`](#role-map-treeitem)
 5. [3.5 State and Property
 Mapping](#mapping_state-property)
 1. [3.5.1 General
 rules](#statePropertyMappingGeneralRules)
 2. [3.5.2 State and Property Mapping
 Tables](#mapping_state-property_table)
 1. [3.5.2.1 Not Mapped](#not_mapped)
 2. [3.5.2.2
 `aria-activedescendant`](#ariaActiveDescendant)
 3. [3.5.2.3
 `aria-atomic`=`true`](#ariaAtomicTrue)
 4. [3.5.2.4
 `aria-atomic`=`false`](#ariaAtomicFalse)
 5. [3.5.2.5 `aria-autocomplete`=`inline`, `list`, or
 `both`](#ariaAutocompleteInlineListBoth)
 6. [3.5.2.6
 `aria-autocomplete`=`none`](#ariaAutocompleteNone)
 7. [3.5.2.7
 `aria-braillelabel`](#ariaBraillelabel)
 8. [3.5.2.8
 `aria-brailleroledescription`](#ariaBrailleroledescription)
 9. [3.5.2.9 `aria-brailleroledescription` is undefined or
 the empty
 string](#ariaBrailleroledescriptionUndefined)
 10. [3.5.2.10 `aria-busy`=`true`](#ariaBusyTrue)
 11. [3.5.2.11 `aria-busy`=`false`](#ariaBusyFalse)
 12. [3.5.2.12
 `aria-checked`=`true`](#ariaCheckedTrue)
 13. [3.5.2.13
 `aria-checked`=`false`](#ariaCheckedFalse)
 14. [3.5.2.14
 `aria-checked`=`mixed`](#ariaCheckedMixed)
 15. [3.5.2.15 `aria-checked` is
 undefined](#ariaCheckedUndefined)
 16. [3.5.2.16 `aria-colcount`](#ariaColCount)
 17. [3.5.2.17 `aria-colindex`](#ariaColIndex)
 18. [3.5.2.18
 `aria-colindextext`](#ariaColIndexText)
 19. [3.5.2.19 `aria-colspan`](#ariaColSpan)
 20. [3.5.2.20 `aria-controls`](#ariaControls)
 21. [3.5.2.21 `aria-current` with non-`false` allowed
 value](#ariaCurrent)
 22. [3.5.2.22 `aria-current` with unrecognized
 value](#ariaCurrentUnrecognizedValue)
 23. [3.5.2.23 `aria-current` is `false` or
 undefined](#ariaCurrentUndefined)
 24. [3.5.2.24
 `aria-describedby`](#ariaDescribedBy)
 25. [3.5.2.25
 `aria-description`](#ariaDescription)
 26. [3.5.2.26 `aria-details`](#ariaDetails)
 27. [3.5.2.27
 `aria-disabled`=`true`](#ariaDisabledTrue)
 28. [3.5.2.28
 `aria-disabled`=`false`](#ariaDisabledFalse)
 29. [3.5.2.29 `aria-dropeffect`=`copy`, `move`, `link`,
 `execute`, or `popup`
 (deprecated)](#ariaDropeffectMoveLinkExecutePopup)
 30. [3.5.2.30 `aria-dropeffect`=`none`
 (deprecated)](#ariaDropeffectNone)
 31. [3.5.2.31
 `aria-errormessage`](#ariaErrorMessage)
 32. [3.5.2.32
 `aria-expanded`=`true`](#ariaExpandedTrue)
 33. [3.5.2.33
 `aria-expanded`=`false`](#ariaExpandedFalse)
 34. [3.5.2.34 `aria-expanded` is
 undefined](#ariaExpandedUndefined)
 35. [3.5.2.35 `aria-flowto`](#ariaFlowto)
 36. [3.5.2.36
 `aria-grabbed`=`true`](#ariaGrabbedTrue)
 37. [3.5.2.37
 `aria-grabbed`=`false`](#ariaGrabbedFalse)
 38. [3.5.2.38 `aria-grabbed` is
 undefined](#ariaGrabbedUndefined)
 39. [3.5.2.39
 `aria-haspopup`=`true`](#ariaHaspopupTrue)
 40. [3.5.2.40
 `aria-haspopup`=`false`](#ariaHaspopupFalse)
 41. [3.5.2.41
 `aria-haspopup`=`dialog`](#ariaHaspopupDialog)
 42. [3.5.2.42
 `aria-haspopup`=`grid`](#ariaHaspopupGrid)
 43. [3.5.2.43
 `aria-haspopup`=`listbox`](#ariaHaspopupListbox)
 44. [3.5.2.44
 `aria-haspopup`=`menu`](#ariaHaspopupMenu)
 45. [3.5.2.45
 `aria-haspopup`=`tree`](#ariaHaspopupTree)
 46. [3.5.2.46 `aria-hidden`=`true` on unfocused
 element](#ariaHiddenTrue)
 47. [3.5.2.47 `aria-hidden`=`true` when element is focused
 or fires an accessibility
 event](#ariaHiddenTrueElementExposed)
 48. [3.5.2.48
 `aria-hidden`=`false`](#ariaHiddenFalse)
 49. [3.5.2.49
 `aria-invalid`=`true`](#ariaInvalidTrue)
 50. [3.5.2.50
 `aria-invalid`=`false`](#ariaInvalidFalse)
 51. [3.5.2.51 `aria-invalid`=`spelling` or
 `grammar`](#ariaInvalidSpellingGrammar)
 52. [3.5.2.52 `aria-invalid` with unrecognized
 value](#ariaInvalidUnrecognizedValue)
 53. [3.5.2.53
 `aria-keyshortcuts`](#ariaKeyshortcuts)
 54. [3.5.2.54 `aria-label`](#ariaLabel)
 55. [3.5.2.55 `aria-labelledby`](#ariaLabelledBy)
 56. [3.5.2.56 `aria-level` on
 non-`heading`](#ariaLevel)
 57. [3.5.2.57 `aria-level` on
 `heading`](#ariaLevelHeading)
 58. [3.5.2.58
 `aria-live`=`assertive`](#ariaLiveAssertive)
 59. [3.5.2.59
 `aria-live`=`polite`](#ariaLivePolite)
 60. [3.5.2.60 `aria-live`=`off`](#ariaLiveOff)
 61. [3.5.2.61 `aria-modal`=`true`](#ariaModalTrue)
 62. [3.5.2.62
 `aria-modal`=`false`](#ariaModalFalse)
 63. [3.5.2.63
 `aria-multiline`=`true`](#ariaMultilineTrue)
 64. [3.5.2.64
 `aria-multiline`=`false`](#ariaMultilineFalse)
 65. [3.5.2.65
 `aria-multiselectable`=`true`](#ariaMultiselectableTrue)
 66. [3.5.2.66
 `aria-multiselectable`=`false`](#ariaMultiselectableFalse)
 67. [3.5.2.67
 `aria-orientation`=`horizontal`](#ariaOrientationHorizontal)
 68. [3.5.2.68
 `aria-orientation`=`vertical`](#ariaOrientationVertical)
 69. [3.5.2.69 `aria-orientation` is
 undefined](#ariaOrientationUndefined)
 70. [3.5.2.70 `aria-owns`](#ariaOwns)
 71. [3.5.2.71
 `aria-placeholder`](#ariaPlaceholder)
 72. [3.5.2.72 `aria-posinset`](#ariaPosinset)
 73. [3.5.2.73
 `aria-pressed`=`true`](#ariaPressedTrue)
 74. [3.5.2.74
 `aria-pressed`=`mixed`](#ariaPressedMixed)
 75. [3.5.2.75
 `aria-pressed`=`false`](#ariaPressedFalse)
 76. [3.5.2.76 `aria-pressed` is
 undefined](#ariaPressedUndefined)
 77. [3.5.2.77
 `aria-readonly`=`true`](#ariaReadonlyTrue)
 78. [3.5.2.78
 `aria-readonly`=`false`](#ariaReadonlyFalse)
 79. [3.5.2.79 `aria-readonly` is unspecified on
 `gridcell`](#ariaReadonlyUnspecifiedOnGridcell)
 80. [3.5.2.80 `aria-relevant`](#ariaRelevant)
 81. [3.5.2.81
 `aria-required`=`true`](#ariaRequiredTrue)
 82. [3.5.2.82
 `aria-required`=`false`](#ariaRequiredFalse)
 83. [3.5.2.83
 `aria-roledescription`](#ariaRoleDescription)
 84. [3.5.2.84 `aria-roledescription` is undefined or the
 empty string](#ariaRoleDescriptionEmptyString)
 85. [3.5.2.85 `aria-rowcount`](#ariaRowCount)
 86. [3.5.2.86 `aria-rowindex`](#ariaRowIndex)
 87. [3.5.2.87
 `aria-rowindextext`](#ariaRowIndexText)
 88. [3.5.2.88 `aria-rowspan`](#ariaRowSpan)
 89. [3.5.2.89
 `aria-selected`=`true`](#ariaSelectedTrue)
 90. [3.5.2.90
 `aria-selected`=`false`](#ariaSelectedFalse)
 91. [3.5.2.91 `aria-selected` is
 undefined](#ariaSelectedUndefined)
 92. [3.5.2.92 `aria-setsize`](#ariaSetsize)
 93. [3.5.2.93
 `aria-sort`=`ascending`](#ariaSortAscending)
 94. [3.5.2.94
 `aria-sort`=`descending`](#ariaSortDescending)
 95. [3.5.2.95 `aria-sort`=`other`](#ariaSortOther)
 96. [3.5.2.96 `aria-sort`=`none`](#ariaSortNone)
 97. [3.5.2.97 `aria-valuemax`](#ariaValueMax)
 98. [3.5.2.98 `aria-valuemin`](#ariaValueMin)
 99. [3.5.2.99 `aria-valuenow`](#ariaValueNow)
 100. [3.5.2.100 `aria-valuetext`](#ariaValueText)
 6. [3.6 Special Processing Requiring Additional
 Computation](#mapping_additional)
 1. [3.6.1 Name and
 Description](#mapping_additional_nd)
 2. [3.6.2 Relations](#mapping_additional_relations)
 1. [3.6.2.1 Reverse
 Relations](#mapping_additional_relations_reverse_relations)
 2. [3.6.2.2 Implied reverse
 relations](#mapping_additional_relations_implied)
 3. [3.6.3 Group
 Position](#mapping_additional_position)
 7. [3.7 Actions](#mapping_actions)
 8. [3.8 Events](#mapping_events)
 1. [3.8.1 State and Property Change
 Events](#mapping_events_state-change)
 1. [3.8.1.1
 `aria-activedescendant`](#event-aria-activedescendant)
 2. [3.8.1.2 `aria-busy`
 (state)](#event-aria-busy)
 3. [3.8.1.3 `aria-checked`
 (state)](#event-aria-checked)
 4. [3.8.1.4 `aria-current`
 (state)](#event-aria-current)
 5. [3.8.1.5 `aria-disabled`
 (state)](#event-aria-disabled)
 6. [3.8.1.6
 `aria-describedby`](#event-aria-describedby)
 7. [3.8.1.7 `aria-dropeffect` (property,
 deprecated)](#event-aria-dropeffect)
 8. [3.8.1.8 `aria-expanded`
 (state)](#event-aria-expanded)
 9. [3.8.1.9 `aria-grabbed` (state,
 deprecated)](#event-aria-grabbed)
 10. [3.8.1.10 `aria-hidden`
 (state)](#event-aria-hidden)
 11. [3.8.1.11 `aria-invalid`
 (state)](#event-aria-invalid)
 12. [3.8.1.12 `aria-label` and
 `aria-labelledby`](#event-aria-label)
 13. [3.8.1.13 `aria-pressed`
 (state)](#event-aria-pressed)
 14. [3.8.1.14
 `aria-readonly`](#event-aria-readonly)
 15. [3.8.1.15
 `aria-required`](#event-aria-required)
 16. [3.8.1.16 `aria-selected`
 (state)](#event-aria-selected)
 17. [3.8.1.17
 `aria-valuenow`](#event-aria-valuenow)
 18. [3.8.1.18
 `aria-valuetext`](#event-aria-valuetext)
 2. [3.8.2 Changes to document content or node
 visibility](#mapping_events_visibility)
 3. [3.8.3 Focus Changes](#focus_state_event_table)
 4. [3.8.4 Selection](#mapping_events_selection)
 5. [3.8.5 Special Events for
 Menus](#mapping_events_menus)
6. [4. Algorithms](#mapping_algorithms)
 1. [4.1 ARIANotifyMixin Algorithm Mapping
 Tables](#arianotifymixin-algorithm-mapping-tables)
 1. [4.1.1
 ariaNotify](#arianotifymixin-map-arianotify)
7. [5. Privacy considerations](#privacy-considerations)
8. [6. Security considerations](#security-considerations)
9. [A. Change Log](#changelog)
 1. [A.1 Substantive changes since the last [Candidate
 Recommendation
 Snapshot]](#substantive-changes-since-the-last-candidate-recommendation-snapshot)
 2. [A.2 Substantive changes since the [Core Accessibility
 [API] Mappings
 1.1
 Recommendation]](#substantive-changes-since-the-core-accessibility-api-mappings-1-1-recommendation)
10. [B. Acknowledgments](#acknowledgements)
 1. [B.1 ARIA WG participants at the time of
 publication](#ack_group)
 2. [B.2 Enabling funders](#ack_funders)
11. [C. References](#references)
 1. [C.1 Normative references](#normative-references)
 2. [C.2 Informative references](#informative-references)

::: header-wrapper
## 1. Introduction

*This section is non-normative.*

The Core Accessibility [API] Mappings specifies how
[WAI-ARIA]
[roles](https://www.w3.org/TR/wai-aria-1.3/#dfn-role),
[states](https://www.w3.org/TR/wai-aria/#dfn-state), and
[properties](https://www.w3.org/TR/wai-aria/#dfn-property)
are expected to be exposed by user agents via platform accessibility
[APIs]. It is part of
a set of resources that define and support the [WAI-ARIA] specification which
includes the following documents:

- [Accessible Rich Internet Applications ([WAI-ARIA])
 1.2](https://w3c.github.io/aria/)
 \[[WAI-ARIA-1.2](#bib-wai-aria-1-2 "Accessible Rich Internet Applications (WAI-ARIA) 1.2")\], a [W3C] recommendation, defines the
 [WAI-ARIA]
 standard.
- [[WAI-ARIA]
 Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/),
 describes how web content developers can develop accessible rich
 internet applications using [WAI-ARIA]. It provides detailed
 advice and examples directed primarily to web application developers,
 yet also useful to user agent and developers of assistive
 technologies.
- [Roadmap for Accessible Rich Internet Applications ([WAI-ARIA]
 Roadmap)](http://www.w3.org/TR/wai-aria-roadmap/)
 \[[WAI-ARIA-ROADMAP](#bib-wai-aria-roadmap "Roadmap for Accessible Rich Internet Applications (WAI-ARIA Roadmap)")\], defines the path to make rich web content
 accessible, including steps already taken, remaining future steps, and
 a time line.

For an introduction to [WAI-ARIA], see the
[[WAI-ARIA]
Overview](http://www.w3.org/WAI/intro/aria.php).

::: header-wrapper
### 1.1 Accessibility [APIs]

[Accessibility [APIs]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api) make it possible to communicate
accessibility information about user interfaces to assistive
technologies. This information includes:

1. Descriptive properties (role, name, value, position, etc.)
2. Transient states (pressed, focused, etc.)
3. Events (text changed, button was clicked, checkbox was toggled)
4. Actions the user might take (click, check/toggle, drag, etc.)
5. Relationships (parent/child, description/described object, previous
 object/next object, etc.)
6. Textual content

Accessibility [APIs]
covered by this specification are:

- [MSAA] with IAccessible2
 1.3 \[[IAccessible2](#bib-iaccessible2 "IAccessible2")\]
- User Interface Automation
 \[[UI-AUTOMATION](#bib-ui-automation "UI Automation")\]
- [ATK] - Accessibility Toolkit
 \[[ATK](#bib-atk "ATK - Accessibility Toolkit")\] and Assistive Technology Service Provider
 Interface
 \[[AT-SPI](#bib-at-spi "Assistive Technology Service Provider Interface")\], referred to hereafter as \"[ATK]/[AT]-SPI\"
- macOS Accessibility Protocol
 \[[AXAPI](#bib-axapi "The NSAccessibility Protocol for macOS")\]
- [Android](https://developer.android.com/reference/android/view/accessibility/package-summary)
 \[[Android-Accessibility-API](#bib-android-accessibility-api "Android Accessibility API")\]

The [[WAI-ARIA] 1.0
User Agent Implementation
Guide](http://www.w3.org/TR/wai-aria-implementation/) included mappings
for
\[[UIA-EXPRESS](#bib-uia-express "The IAccessibleEx Interface")\], also known as IAccessibleEx, which was
implemented in Microsoft Internet Explorer 8.0 - 11. New implementations
are strongly encouraged to use [UI
Automation](https://docs.microsoft.com/en-us/windows/win32/winauto/ui-automation-specification){matched-text="[[[UI-AUTOMATION]]]"}
instead.

If user agent developers need to expose information using other
accessibility [APIs],
it is recommended that they work closely with the developer of the
platform where the [API] runs, and assistive
technology developers on that platform.

::: header-wrapper
### 1.2 Comparing Accessibility [APIs]

For various technological and historical reasons, accessibility
[APIs] do not all work
in the same way. In many cases, there is no simple one-to-one
relationship between how each of them names or exposes roles, states,
and properties to assistive technologies. The following subsections
describe a few of the distinguishing characteristics of some of the
[APIs].

::: header-wrapper
#### 1.2.1 [ATK]/[AT]-SPI

[MSAA], IAccessible2,
[UIA], and [AX API] each define an [API] that is shared by both the
software application exposing information about its content and
interactive components, and the assistive technology consuming that
information. Conversely, Linux/GNOME separates that shared interface
into its two aspects, each represented by a different accessibility
[API]: [ATK] or [AT]-SPI.

[ATK] defines an interface that is
implemented by software in order to expose accessibility information,
whereas [AT]-SPI is a desktop
service that gathers accessibility information from active applications
and relays it to other interested applications, usually assistive
technologies.

For example, the GNOME [GUI]
toolkit \[GTK\], implements the relevant aspects of [ATK] for each widget (menu, combobox,
checkbox, etc.) in order that GTK widgets expose accessibility
information about themselves. [AT]-SPI then acquires the information from
applications built with GTK and makes it available to interested
parties.

[ATK] is most relevant to
implementors, whereas [AT]-SPI is
relevant to consumers. In the context of mapping [WAI-ARIA] roles, states and
properties, user agents are implementors and use [ATK]. Assistive Technologies are consumers,
and use [AT]-SPI.

::: header-wrapper
#### 1.2.2 [UIA] (UI Automation)

UI Automation expresses every element of the application user interface
as an automation element. Automation elements form the nodes of the
application accessibility tree, that can be queried, traversed and
interacted with by automation clients.

There are several concepts central to UI Automation:

- Automation element - controls and some application content are
 presented as automation elements.
- Element properties - Automation elements have several common
 properties describing native framework element characteristics in an
 agnostic way that all automation clients can understand. There are
 several ways to access element property values, described below.
- Control Patterns - Some common interactivity in different frameworks
 is expressed as control patterns in [UIA], allowing different automation
 clients to interact with controls using common programmatic
 interfaces.
- Events - Similar to other accessibility [APIs], automation elements
 support various events that allow automation providers to notify
 clients on important state changes.

All automation elements inherit from the `IUIAutomationElement`
interface and all properties that are not specific to a particular
control pattern can be queried through that interface. There are several
ways to access UI Automation element properties:

- Direct property accessors to the current values -
 `Current{PropertyName}`, e.g. `IUIAutomationElement::CurrentName` for
 the `Name` property
- Cached property accessors - `Cached{PropertyName}`, e.g.
 `IUIAutomationElement::CachedName` for the `Name` property. Using
 cached values is preferred when providers and clients are used in
 remote environments.
- `GetCurrentPropertyValue` and passing the [UIA] Property ID enumeration value
 corresponding to that property to get the current value, e.g.
 `IUIAutomationElement::GetCurrentPropertyValue(UIA_NamePropertyId)`
 for the `Name` property.
- `GetCachedPropertyValue` and passing the [UIA] Property ID enumeration value
 corresponding to that property to get the cached value, e.g.
 `IUIAutomationElement::GetCachedPropertyValue(UIA_NamePropertyId)` for
 the `Name` property.

Properties for specific [UIA]
control patterns are queried the same way using relevant control pattern
interfaces. Taking Toggle Pattern as an example, to query the
ToggleState property clients can use
IUIAutomationTogglePattern::CurrentToggleState or
IUIAutomationElement::GetCurrentPropertyValue(UIA_ToggleToggleStatePropertyId)
to get the current value.

The property mappings in this specification provide the `{PropertyName}`
and do not specify all specific ways to access the property value.
Automation clients can access current or cached values using conventions
described above, depending on specific needs and coding style
conventions.

::: header-wrapper
#### 1.2.3 Android Accessibility [API]

Android accessibility services and applications both express user
interface elements as a tree of `AccessibilityNodeInfo` objects.
Accessibility services receive events, traverse the
`AccessibilityNodeInfo` tree, retrieve properties, and perform actions
on a node. Conversely, Android applications build the
`AccessibilityNodeInfo` tree indirectly by constructing views or
composables, or directly via an `AccessibilityNodeProvider`. They then
subsequently fire events, and handle actions.

For [WAI-ARIA]
implementers, of particular interest is the mapping into properties,
actions, and events on `AccessibilityNodeInfo` and `AccessibilityEvent`.

Note: Many ARIA roles in this specification are mapped to
`android.view.View` as a default or fallback mapping. This often
reflects a baseline level of support where a more specific Android
widget class is not available or has not been defined yet. These
mappings are subject to change as the Android accessibility ecosystem
evolves and more specific mappings are identified. In cases where no
specific role mapping is available, Android\'s
[`setRoleDescription`](https://developer.android.com/reference/androidx/core/view/accessibility/AccessibilityNodeInfoCompat#setRoleDescription(java.lang.CharSequence))
can be used to convey the specific ARIA role semantics to assistive
technologies.

::: header-wrapper
#### 1.2.4 Accessible Names and Descriptions

Each platform accessibility [API] includes a way to assign and
retrieve [accessible
name](https://www.w3.org/TR/accname-1.2/#dfn-accessible-name) and [accessible
description](https://www.w3.org/TR/accname-1.2/#dfn-accessible-description) properties for each [accessible
object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) created in the [accessibility
tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree). How these properties are implemented and
what they are called vary depending on the [API].

For instance, in [MSAA],
all [accessible
objects](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) support the `accName` property, which
stores the object\'s [accessible
name](https://www.w3.org/TR/accname-1.2/#dfn-accessible-name). Where the object also supports having an [accessible
description](https://www.w3.org/TR/accname-1.2/#dfn-accessible-description), [MSAA]
stores this property in the object\'s `accDescription` property.

Software using [ATK] can read and
write to an object\'s `accessible-name` and `accessible-description`
properties. In turn, [AT]-SPI can
query the values of those properties through its
`atspi_accessible_get_name` and `atspi_accessible_get_description`
functions.

Automation elements in the [UIA] accessibility tree have a `Name`
property. Where the object also supports having an [accessible
description](https://www.w3.org/TR/accname-1.2/#dfn-accessible-description), [UIA] stores
this property in the object\'s `FullDescription` property.

An object\'s [accessible
description](https://www.w3.org/TR/accname-1.2/#dfn-accessible-description), where provided by
[`aria-description`](https://w3c.github.io/aria/#aria-description)
or
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby),
should be exposed in the `accessibilityCustomContent` [API]. Otherwise, it should be
exposed as `AXHelp`.

In Android, accessible names map to a number of properties defined on
`AccessibilityNodeInfo` such as content description, supplemental
description, and text.

For more detail, see the [Accessible Name and Description
Computation](https://w3c.github.io/accname/) specification.

::: header-wrapper
## 2. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

The key words *MAY*, *MUST*, *MUST NOT*, *SHOULD*, and *SHOULD NOT* in
this document are to be interpreted as described in [BCP
14](https://www.rfc-editor.org/info/bcp14)
\[[RFC2119](#bib-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels")\]
\[[RFC8174](#bib-rfc8174 "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words")\] when, and only when, they appear in all capitals,
as shown here.

Normative sections provide requirements that user agents and assistive
technologies *MUST* follow for an implementation to conform to this
specification.

Non-normative (informative) sections provide information useful to
understanding the specification. Such sections may contain examples of
recommended practice, but it is not required to follow such
recommendations in order to conform to this specification.

::: header-wrapper
### 2.1 Features Deprecated in [WAI-ARIA]

The [WAI-ARIA]
specification [lists some features as
deprecated](https://w3c.github.io/aria/#deprecated). Although
this means authors are encouraged not to use such features, it is
expected that the features could still be used in legacy content.
Therefore, it is important that user agents continue to map these
features to accessibility [APIs], and doing so is part of
conformance to this specification. When future versions of the
[WAI-ARIA]
specification change such features from deprecated to removed, they will
be removed from the mappings as well and user agents will no longer be
asked to continue support for those features.

::: header-wrapper
## 3. Mapping [WAI-ARIA] to Accessibility [APIs]

::: header-wrapper
### 3.1 General rules for exposing [WAI-ARIA] semantics

Where supported by the platform [Accessibility [API]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api), [user
agents](https://infra.spec.whatwg.org/#user-agent)
expose [WAI-ARIA]
[semantics](https://www.w3.org/TR/wai-aria/#dfn-semantics) through the standard mechanisms of the
desktop accessibility [API]. For example, for
[WAI-ARIA]
[widgets](https://www.w3.org/TR/wai-aria/#dfn-widget), compare how the widget is exposed in a
similar desktop widget. In general most [WAI-ARIA] widget capabilities are
exposed through the
[role](https://www.w3.org/TR/wai-aria-1.3/#dfn-role), value,
Boolean [states](https://www.w3.org/TR/wai-aria/#dfn-state), and relations of the accessibility
[API].

With respect to [WAI-ARIA] 1.0 and 1.1,
accessibility [APIs]
operate in one direction only. User agents publish [WAI-ARIA] information (roles,
states, and properties) via an accessibility [API], and an [AT] can acquire that information using the
same [API]. However,
the other direction is not supported. [WAI-ARIA] 1.0 and 1.1 do not define
mechanisms for assistive technologies to directly modify
[WAI-ARIA]
information.

The terms \"exposing\", \"mapping\", and \"including\" refer to the
creation of [accessible
object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object)
[nodes](https://dom.spec.whatwg.org/#concept-node) within the [accessibility
tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree), and populating these objects with
[Accessibility [API]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api) specific
[states](https://www.w3.org/TR/wai-aria/#dfn-state) and
[properties](https://www.w3.org/TR/wai-aria/#dfn-property "Normative reference to non-normative term.").

::: header-wrapper
### 3.2 Conflicts between native markup semantics and [WAI-ARIA]

[WAI-ARIA] roles,
states, and properties are intended to add
[semantic](https://www.w3.org/TR/wai-aria/#dfn-semantics) information when native host language
[elements](https://dom.spec.whatwg.org/#concept-element) with these semantics are not available,
and are generally used on elements that have no native semantics of
their own. They can also be used on elements that have similar but not
identical semantics to the intended object (for instance, a nested list
could be used to represent a tree structure). This method can be part of
a fallback strategy for older browsers that have no [WAI-ARIA] implementation, or because
native presentation of the repurposed element reduces the amount of
style and/or script needed. Except for the cases outlined below, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* always use the [WAI-ARIA] semantics to define how it
exposes the element to [accessibility [APIs]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api), rather than using the host language
semantics.

Host languages can have features that have implicit [WAI-ARIA] semantics corresponding to
[roles](https://www.w3.org/TR/wai-aria-1.3/#dfn-role). When a
[WAI-ARIA] role is
provided that has a corresponding role in the accessibility [API], user agents *MUST* use the
semantic of the [WAI-ARIA] role for processing, not
the native semantic, unless the role requires [WAI-ARIA] states and properties
whose attributes are explicitly forbidden on the native element by the
host language. Values for roles do not conflict in the same way as
values for states and properties, and because authors are expected to
have a valid reason to provide a [WAI-ARIA] role even on elements that
would not normally be repurposed. For example, spin buttons are
typically constructed from text fields (`<input type="text">`) in order
to get most of the default keyboard support. But, the native role,
\"text field\", is not correct because it does not properly communicate
the additional features of a spin button. The author adds the
[WAI-ARIA] role of
`spinbutton` (`<input type="text" ...>`) so that the
control is properly mapped in the accessibility [API]. When a [WAI-ARIA] role is provided that does
not have a corresponding role in the accessibility [API], user agents *MAY* expose the
native semantic in addition to the [WAI-ARIA] role. If the host language
element is overridden by a [WAI-ARIA] role whose semantics or
structure is not equivalent to the native host language semantics or to
a subclass of those semantics, then treat any child elements having
roles specified as Allowed Accessibility Child Roles as having
[presentation](#role-map-presentation) or [none](#role-map-none).

The above text differs slightly from the [WAI-ARIA] specification. The
requirement for user agents to expose the [WAI-ARIA] role instead of the native
role was intended to only apply in cases where there is a direct mapping
from the [WAI-ARIA]
role to a corresponding role in the accessibility [API]. The wording of the
requirement is not clear in the [WAI-ARIA] specification, however,
and has been interpreted differently by implementers. The requirement
has been clarified here and an additional statement added to indicate
that user agents may expose native semantics if there is not a direct
mapping to a role in the accessibility [API]. Because there are differing
implementations, authors will be advised against adding such
[WAI-ARIA] roles to
native elements that have their own semantics in the [WAI-ARIA] Authoring Practices Guide.

When [WAI-ARIA]
states and properties correspond to host language features that have the
same implicit [WAI-ARIA] semantic, it can be
problematic if the values become out of sync. For example, the
[HTML] `checked` attribute and
the `aria-checked` attribute could have conflicting values. Therefore to
prevent providing conflicting states and properties to assistive
technologies, host languages will explicitly declare where the use of
[WAI-ARIA]
attributes on a host language element conflict with native attributes
for that element. When a host language declares a [WAI-ARIA]
[attribute](https://dom.spec.whatwg.org/#concept-attribute) to be in direct semantic conflict with a
native attribute for a given element, user agents *MUST* ignore the
[WAI-ARIA]
attribute and instead use the host language attribute with the same
implicit semantic.

Host languages might also document features that cannot be overridden
with [WAI-ARIA]
(these are called \"strong native semantics\"). These can be features
that have implicit [WAI-ARIA] semantics as well as
features where the processing would be uncertain if the semantics were
changed with [WAI-ARIA]. While conformance
checkers might signal an error or warning when a [WAI-ARIA] role is used on elements
with strong native semantics, user agents *MUST* still use the value of
the semantic of the [WAI-ARIA] role when exposing the
element to accessibility [APIs].

::: header-wrapper
### 3.3 Exposing attributes that do not directly map to accessibility [API] properties

Platform [accessibility [APIs]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api) might have features that are not in
[WAI-ARIA].
Likewise, [WAI-ARIA]
exposes capabilities that are not supported by accessibility
[APIs] at the time of
publication. There typically is not a one to one relationship between
all [WAI-ARIA]
[attributes](https://dom.spec.whatwg.org/#concept-attribute) and platform accessibility [APIs]. When [WAI-ARIA]
[roles](https://www.w3.org/TR/wai-aria-1.3/#dfn-role),
[states](https://www.w3.org/TR/wai-aria/#dfn-state) and
[properties](https://www.w3.org/TR/wai-aria/#dfn-property "Normative reference to non-normative term.") do not directly map to an
accessibility [API],
and there is a mechanism in the [API] to expose the
[WAI-ARIA] role,
states, and properties and their values, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* expose the [WAI-ARIA] data using that mechanism
as follows:

- In IAccessible2 and [ATK]/[AT-SPI], use object
 attributes to expose
 [semantics](https://www.w3.org/TR/wai-aria/#dfn-semantics) that are not directly supported in the
 [APIs]. Object
 attributes are name-value pairs that are loosely specified, and very
 flexible for exposing things where there is no specific interface in
 an accessibility [API]. For example, at this time,
 the
 [`aria-live`](https://w3c.github.io/aria/#aria-live)
 attribute can be exposed via an object attribute because accessibility
 [APIs] have no such
 property available. Specific rules for exposing object attribute
 name-value pairs are described throughout this document, and rules for
 the general cases are in [State and Property
 Mapping](#mapping_state-property).
- In Microsoft [UIA], use the
 `AriaRole` and `AriaProperties` properties to expose semantics that
 are not directly supported in the control type.

[MSAA] does not provide a
mechanism for exposing attributes that do not map directly to the
[API] and among
implementers, there is no agreement on how to do it.

User agents *MUST* also expose the entire role string through this
mechanism and *MAY* also expose [WAI-ARIA] attributes and values
through this mechanism even when there is a direct mapping to an
accessibility [API].

Browser implementers are advised to publicly document their [API] methods for exposing any
relevant information, so that [assistive
technology](https://www.w3.org/TR/wai-aria/#assistive-technology) developers can use the [API] to support user features.

::: header-wrapper
### 3.4 Role mapping

Platform [accessibility [APIs]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api) traditionally have had a finite set of
predefined
[roles](https://www.w3.org/TR/wai-aria-1.3/#dfn-role) that are
expected by [assistive
technologies](https://www.w3.org/TR/wai-aria/#assistive-technology) on that platform and only one or two roles
may be exposed. In contrast, [WAI-ARIA] allows multiple roles to
be specified as an ordered set of space-separated valid role tokens. The
additional roles are fallback roles similar to the concept of specifying
multiple fonts in case the first choice font type is not supported.

::: header-wrapper
#### 3.4.1 General rules

User agents *MUST* expose the [WAI-ARIA] role string if the
[API] supports a
mechanism to do so. This allows assistive technologies to do their own
additional processing of roles.

- [MSAA]: [not
 supported](https://msdn.microsoft.com/en-us/library/windows/desktop/dd373608(v=vs.85).aspx "Object Roles (Windows)").
 User agents *SHOULD NOT* expose a custom role in [MSAA]\'s `accRole` property.
- IAccessible2: expose as an object attribute pair
 (`xml-roles:"string"`)
- [UIA]: expose as `AriaRole`
 property. The `AriaRole property` can also support secondary roles
 using a space as a separator.
- [ATK]/[AT-SPI]: expose as
 an object attribute pair (`xml-roles:"string"`)

::: header-wrapper
#### 3.4.2 Computed Role

The `computedrole` of an element is a string that represents the role of
the element as computed by the browser engine. The `computedrole` is
used primarily for the purposes of developer tools and specification
conformance and interoperability testing.

User agents provide this role string, for example, in developer tools,
and in response to the WebDriver function
[`getComputedRole`](https://w3c.github.io/webdriver/#get-computed-role),
which is used for [interoperability testing of ARIA, [HTML]-AAM, and other
specifications](https://github.com/w3c/aria/blob/main/documentation/tests.md).

[Example 1](#example-1)

``` {aria-busy="false"}
<button> <!-- computedrole returns "button" -->

<a href="#" > <!-- computedrole returns "button" -->
```

When an element has a role but is not contained in the required context
(for example, an orphaned `listitem` without the required accessible
parent of role `list`), this is an authoring error, but the user agent
behavior is not specified as a single rule. For most roles, user agents
can either recover the error by ignoring the role, or respect the
author\'s intended role in scenarios deemed by the implementation to be
harmless. Please note that this permissiveness in how engines treat
author role errors might be overridden in a language-specific mapping
document such as
\[[HTML-AAM](#bib-html-aam "HTML Accessibility API Mappings 1.0")\].

[Example 2](#example-2)

``` {aria-busy="false"}
<div > <!-- Author error: orphaned listitem. computedrole is unspecified. -->

<div > <!-- computedrole returns "list" -->
 <div > <!-- computedrole returns "listitem" in the appropriate context. -->
```

When host language elements do not have an exact or equivalent mapping
to a valid, non-abstract role, the related Accessibilty [API] Mapping extension
specification *MAY* specify a unique `computedrole` string as the return
value for interoperability testing purposes, such as
`<video> -> "html-video"` in
\[[HTML-AAM](#bib-html-aam "HTML Accessibility API Mappings 1.0")\]. However, authors *MUST NOT* use any
host-language-prefixed `computedrole` string in the `role` attribute
(such as `html-video`), unless the token also matches valid, defined
role (such as `dpub-chapter`). User Agents *MUST* ignore any abstract or
invalid role token.

[Example 3](#example-3)

``` {aria-busy="false"}
<video> <!-- computedrole returns "html-video" -->

<main > <!-- Author error. computedrole returns "main" -->
```

::: header-wrapper
#### 3.4.3 Role Mapping Tables

::: header-wrapper
##### 3.4.3.1 `alert`

+------------------------------------------------------------------+---------------------------------------------------------------+
| ARIA Specification | [`alert`](https://w3c.github.io/aria/#alert) |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Computed Role | `alert` |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_ALERT`]\ |
| IAccessible2 | [Event: The user agent *SHOULD* fire `EVENT_SYSTEM_ALERT`. |
| | ^\[[Note\ 2](#ftn.note2)\]^] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `alert`]\ |
| | [LiveSetting: `Assertive (2)`]\ |
| | [Event: The user agent *SHOULD* fire a system alert |
| | [event](https://dom.spec.whatwg.org/#concept-event). |
| | ^\[[Note\ 2](#ftn.note2)\]^] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Event: The user agent *SHOULD* fire a system alert |
| | [event](https://dom.spec.whatwg.org/#concept-event). |
| | ^\[[Note\ 2](#ftn.note2)\]^] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXApplicationAlert`]\ |
| | [Event: The user agent *SHOULD* fire a system alert |
| | [event](https://dom.spec.whatwg.org/#concept-event). |
| | ^\[[Note\ 2](#ftn.note2)\]^] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.2 `alertdialog`

+------------------------------------------------------------------+---------------------------------------------------------------------------+
| ARIA Specification | [`alertdialog`](https://w3c.github.io/aria/#alertdialog) |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| Computed Role | `alertdialog` |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_DIALOG`]\ |
| IAccessible2 | [Event: The user agent *SHOULD* fire `EVENT_SYSTEM_ALERT`. |
| | ^\[[Note\ 2](#ftn.note2)\]^] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [UIA] | [Control Type: `Pane`]\ |
| | [Event: The user agent *SHOULD* fire a system alert |
| | [event](https://dom.spec.whatwg.org/#concept-event). ^\[[Note\ 2](#ftn.note2)\]^] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [[ATK] Interface: |
| | `Window`]\ |
| | [Event: The user agent *SHOULD* fire a system alert |
| | [event](https://dom.spec.whatwg.org/#concept-event). ^\[[Note\ 2](#ftn.note2)\]^] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXApplicationAlertDialog`]\ |
| | [Event: The user agent *SHOULD* fire a system alert |
| | [event](https://dom.spec.whatwg.org/#concept-event). ^\[[Note\ 2](#ftn.note2)\]^] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| Android | `android.app.Dialog / android.app.AlertDialog` |
+------------------------------------------------------------------+---------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.3 `application`

+------------------------------------------------------------------+---------------------------------------------------------------------------+
| ARIA Specification | [`application`](https://w3c.github.io/aria/#application) |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| Computed Role | `application` |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_APPLICATION`] |
| IAccessible2 | |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [UIA] | [Control Type: `Pane`]\ |
| | [Localized Control Type: `application`] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXWebApplication`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.4 `article`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`article`](https://w3c.github.io/aria/#article) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `article` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_DOCUMENT`]\ |
| IAccessible2 | [State: `STATE_SYSTEM_READONLY`]\ |
| | [Object Attribute: `xml-roles:article`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `article`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:article`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXDocumentArticle`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.5 `banner`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`banner`](https://w3c.github.io/aria/#banner) |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `banner` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_LANDMARK`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:banner`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `banner`]\ |
| | [Landmark Type: `Custom`]\ |
| | [Localized Landmark Type: `banner`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:banner`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXLandmarkBanner`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.6 `blockquote`

+------------------------------------------------------------------+-------------------------------------------------------------------------+
| ARIA Specification | [`blockquote`](https://w3c.github.io/aria/#blockquote) |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Computed Role | `blockquote` |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Role: `IA2_ROLE_BLOCK_QUOTE`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `blockquote`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.7 `button` with default values for `aria-pressed` and `aria-haspopup`

+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| ARIA Specification | [`button`](https://w3c.github.io/aria/#button) with default |
| | values for |
| | [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed) |
| | and |
| | [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| Computed Role | `button` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_PUSHBUTTON`] |
| IAccessible2 | |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [UIA] | [Control Type: `Button`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| Android | `android.widget.Button` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.8 `button` with non-`false` value for `aria-haspopup`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`button`](https://w3c.github.io/aria/#button) |
| | with non-`false` value for `aria-haspopup` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `button` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_BUTTONMENU`] |
| IAccessible2 | |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `Button`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.widget.Button` |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.9 `button` with defined value for `aria-pressed`

+------------------------------------------------------------------+---------------------------------------------------------------------------------+
| ARIA Specification | [`button`](https://w3c.github.io/aria/#button) with defined |
| | value for |
| | [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed) |
+------------------------------------------------------------------+---------------------------------------------------------------------------------+
| Computed Role | `button` |
+------------------------------------------------------------------+---------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_PUSHBUTTON`]\ |
| IAccessible2 | [Role: `IA2_ROLE_TOGGLE_BUTTON`] |
+------------------------------------------------------------------+---------------------------------------------------------------------------------+
| [UIA] | [Control Type: `Button`] |
+------------------------------------------------------------------+---------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+---------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXToggle`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------------------+
| Android | `android.widget.ToggleButton` |
+------------------------------------------------------------------+---------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.10 `caption`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`caption`](https://w3c.github.io/aria/#caption) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `caption` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Role: `IA2_ROLE_CAPTION`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `Text`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.11 `cell`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`cell`](https://w3c.github.io/aria/#cell) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `cell` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_CELL`]\ |
| IAccessible2 | [Interface: `IAccessibleTableCell`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `DataItem`]\ |
| | [Localized Control Type: `item`]\ |
| | [Control Pattern: `GridItem`]\ |
| | [Control Pattern: `TableItem`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `TableCell`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.12 `checkbox`

+------------------------------------------------------------------+---------------------------------------------------------------------+
| ARIA Specification | [`checkbox`](https://w3c.github.io/aria/#checkbox) |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Computed Role | `checkbox` |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_CHECKBUTTON`]\ |
| IAccessible2 | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [UIA] | [Control Type: `CheckBox`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Android | `android.widget.CheckBox` |
+------------------------------------------------------------------+---------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.13 `code`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`code`](https://w3c.github.io/aria/#code) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `code` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_TEXT_FRAME`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:code`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Text`]\ |
| | [Localized Control Type: `code`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:code`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXCodeStyleGroup`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.14 `columnheader`

+------------------------------------------------------------------+-----------------------------------------------------------------------------+
| ARIA Specification | [`columnheader`](https://w3c.github.io/aria/#columnheader) |
+------------------------------------------------------------------+-----------------------------------------------------------------------------+
| Computed Role | `columnheader` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_COLUMNHEADER`]\ |
| IAccessible2 | [Interface: `IAccessibleTableCell`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------+
| [UIA] | [Control Type: `DataItem`]\ |
| | [Localized Control Type: `column header`]\ |
| | [Control Pattern: `GridItem`]\ |
| | [Control Pattern: `TableItem`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `TableCell`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.15 `combobox`

+------------------------------------------------------------------+--------------------------------------------------------------------------------+
| ARIA Specification | [`combobox`](https://w3c.github.io/aria/#combobox) |
+------------------------------------------------------------------+--------------------------------------------------------------------------------+
| Computed Role | `combobox` |
+------------------------------------------------------------------+--------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_COMBOBOX`]\ |
| IAccessible2 | [State: `STATE_SYSTEM_HASPOPUP`]\ |
| | [State: `STATE_SYSTEM_COLLAPSED` if |
| | [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | is not `"true"`] |
+------------------------------------------------------------------+--------------------------------------------------------------------------------+
| [UIA] | [Control Type: `ComboBox`] |
+------------------------------------------------------------------+--------------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [State: `STATE_EXPANDABLE`]\ |
| | [State: `STATE_HAS_POPUP`] |
+------------------------------------------------------------------+--------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+--------------------------------------------------------------------------------+
| Android | `android.widget.EditText` |
+------------------------------------------------------------------+--------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.16 `comment`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`comment`](https://w3c.github.io/aria/#comment) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `comment` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_COMMENT`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:comment`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `comment`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:comment`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.17 `complementary`

+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| ARIA Specification | [`complementary`](https://w3c.github.io/aria/#complementary) |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| Computed Role | `complementary` |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_LANDMARK`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:complementary`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `complementary`]\ |
| | [Landmark Type: `Custom`]\ |
| | [Localized Landmark Type: `complementary`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:complementary`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXLandmarkComplementary`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.18 `contentinfo`

+------------------------------------------------------------------+---------------------------------------------------------------------------+
| ARIA Specification | [`contentinfo`](https://w3c.github.io/aria/#contentinfo) |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| Computed Role | `contentinfo` |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_LANDMARK`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:contentinfo`] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `content information`]\ |
| | [Landmark Type: `Custom`]\ |
| | [Localized Landmark Type: `content information`] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:contentinfo`] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXLandmarkContentInfo`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.19 `definition`

+------------------------------------------------------------------+-------------------------------------------------------------------------+
| ARIA Specification | [`definition`](https://w3c.github.io/aria/#definition) |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Computed Role | `definition` |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [MSAA] + | [Object Attribute: `xml-roles:definition`] |
| IAccessible2 | |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `definition`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:definition`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXDefinition`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.20 `deletion`

+------------------------------------------------------------------+---------------------------------------------------------------------+
| ARIA Specification | [`deletion`](https://w3c.github.io/aria/#deletion) |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Computed Role | `deletion` |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_CONTENT_DELETION`] |
| IAccessible2 | |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [UIA] | [Control Type: `Text`]\ |
| | [Localized Control Type: `deletion`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:deletion`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXDeleteStyleGroup`]\ |
| | [AXAttributedStringForTextMarkerRange: contains |
| | `AXIsSuggestedDeletion = 1;` for all text contained in a |
| | `deletion`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.21 `dialog`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`dialog`](https://w3c.github.io/aria/#dialog) |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `dialog` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_DIALOG`] |
| IAccessible2 | |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `Pane`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [[ATK] Interface: |
| | `Window`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXApplicationDialog`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.app.Dialog / android.app.AlertDialog` |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.22 `directory` (deprecated)

+------------------------------------------------------------------+-----------------------------------------------------------------------+
| ARIA Specification | [`directory`](https://w3c.github.io/aria/#directory) |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Computed Role | list |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_LIST`] |
| IAccessible2 | |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [UIA] | [Control Type: `List`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXContentList`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.23 `document`

+------------------------------------------------------------------+---------------------------------------------------------------------+
| ARIA Specification | [`document`](https://w3c.github.io/aria/#document) |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Computed Role | `document` |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_DOCUMENT`]\ |
| IAccessible2 | [State: `STATE_SYSTEM_READONLY`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [UIA] | [Control Type: `Document`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXDocument`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.24 `emphasis`

+------------------------------------------------------------------+---------------------------------------------------------------------+
| ARIA Specification | [`emphasis`](https://w3c.github.io/aria/#emphasis) |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Computed Role | `emphasis` |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_TEXT_FRAME`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:emphasis`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [UIA] | [Control Type: `Text`]\ |
| | [Localized Control Type: `emphasis`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:emphasis`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXEmphasisStyleGroup`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.25 `feed`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`feed`](https://w3c.github.io/aria/#feed) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `feed` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:feed`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `feed`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:feed`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXApplicationGroup`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.26 `figure`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`figure`](https://w3c.github.io/aria/#figure) |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `figure` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:figure`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `figure`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:figure`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.27 `form` with an accessible name

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`form`](https://w3c.github.io/aria/#form) |
| | with an accessible name |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `form` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_FORM`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:form`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `form`]\ |
| | [Landmark Type: `Form`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:form`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXLandmarkForm`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.28 `form` without an accessible name

---------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ARIA Specification [`form`](https://w3c.github.io/aria/#form) without an accessible name
 Computed Role `form`
 [MSAA] + IAccessible2 [Do not expose the [element](https://dom.spec.whatwg.org/#concept-element) as a landmark. Use the native host language role of the element instead.]
 [UIA] [Do not expose the [element](https://dom.spec.whatwg.org/#concept-element) as a landmark. Use the native host language role of the element instead.]
 [ATK]/[AT-SPI] [Do not expose the [element](https://dom.spec.whatwg.org/#concept-element) as a landmark. Use the native host language role of the element instead.]
 [AX API]^\[[Note\ 1](#ftn.note1)\]^ [Do not expose the [element](https://dom.spec.whatwg.org/#concept-element) as a landmark. Use the native host language role of the element instead.]
 Android `android.view.View`
 ---------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.4.3.29 `generic`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`generic`](https://w3c.github.io/aria/#generic) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `generic` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Role: `IA2_ROLE_SECTION`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | Note: Exposed as `android.widget.TextView` if the element has |
| | only text children. |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.30 `grid`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`grid`](https://w3c.github.io/aria/#grid) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `grid` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_TABLE`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:grid`]\ |
| | [Interface: `IAccessibleTable2`]\ |
| | [Method: `IAccessible::accSelect()`]\ |
| | [Method: `IAccessible::get_accSelection()`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `DataGrid`]\ |
| | [Control Pattern: `Grid`]\ |
| | [Control Pattern: `Table`]\ |
| | [Control Pattern: `Selection`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:grid`]\ |
| | [Interface: `Table`]\ |
| | [Interface: `Selection`] |
| | |
| | Because [WAI-ARIA] does not |
| | support modifying the selection via the accessibility |
| | [API], |
| | user agents *MUST* return `false` for all `Selection` |
| | methods that provide a means to modify the selection. |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
| | [AXColumnHeaderUIElements: a list of pointers to the |
| | columnheader elements]\ |
| | [AXHeader: a pointer to the row or group containing those |
| | columnheader elements]\ |
| | [AXRowHeaderUIElements: a list of pointers to the rowheader |
| | elements] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.widget.GridView` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.31 `gridcell`

+------------------------------------------------------------------+---------------------------------------------------------------------+
| ARIA Specification | [`gridcell`](https://w3c.github.io/aria/#gridcell) |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Computed Role | `gridcell` |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_CELL`]\ |
| IAccessible2 | [Interface: `IAccessibleTableCell`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [UIA] | [Control Type: `DataItem`]\ |
| | [Localized Control Type: `item`]\ |
| | [Control Pattern: `SelectionItem`]\ |
| | [Control Pattern: `GridItem`]\ |
| | [Control Pattern: `TableItem`]\ |
| | [SelectionItem.SelectionContainer: the containing |
| | `grid`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `TableCell`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.32 `group`

+------------------------------------------------------------------+---------------------------------------------------------------+
| ARIA Specification | [`group`](https://w3c.github.io/aria/#group) |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Computed Role | `group` |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`] |
| IAccessible2 | |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [UIA] | [Control Type: `Group`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXApplicationGroup`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.33 `heading`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`heading`](https://w3c.github.io/aria/#heading) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `heading` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_HEADING`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:heading`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `Text`]\ |
| | [Localized Control Type: `heading`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.isHeading`: `true`]\ |
| | Note: Exposed as `android.widget.TextView` if the element has |
| | only text children. |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.34 `image`

+------------------------------------------------------------------+---------------------------------------------------------------+
| ARIA Specification | [`image`](https://w3c.github.io/aria/#image) |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Computed Role | `image` |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GRAPHIC`]\ |
| IAccessible2 | [Interface: `IAccessibleImage`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [UIA] | [Control Type: `Image`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Image`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Android | `android.widget.Image` |
+------------------------------------------------------------------+---------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.35 `img`

+------------------------------------------------------------------+-----------------------------------------------------------+
| ARIA Specification | [`img`](https://w3c.github.io/aria/#img) |
+------------------------------------------------------------------+-----------------------------------------------------------+
| Computed Role | `image` |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GRAPHIC`]\ |
| IAccessible2 | [Interface: `IAccessibleImage`] |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [UIA] | [Control Type: `Image`] |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Image`] |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------+
| Android | `android.widget.Image / android.widget.ImageButton` |
+------------------------------------------------------------------+-----------------------------------------------------------+

::: header-wrapper
##### 3.4.3.36 `insertion`

+------------------------------------------------------------------+-----------------------------------------------------------------------+
| ARIA Specification | [`insertion`](https://w3c.github.io/aria/#insertion) |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Computed Role | `insertion` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_CONTENT_INSERTION`] |
| IAccessible2 | |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [UIA] | [Control Type: `Text`]\ |
| | [Localized Control Type: `insertion`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:insertion`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXInsertStyleGroup`]\ |
| | [AXAttributedStringForTextMarkerRange: contains |
| | `AXIsSuggestedInsertion = 1;` for all text contained in a |
| | `insertion`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.37 `link`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`link`](https://w3c.github.io/aria/#link) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `link` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_LINK`]\ |
| IAccessible2 | [State: `STATE_SYSTEM_LINKED`]\ |
| | [State: `STATE_SYSTEM_LINKED`] on its |
| | descendants\ |
| | [Interface: `IAccessibleHypertext`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `HyperLink`]\ |
| | [Control Pattern: `Value`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `HyperlinkImpl`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.getText` returns text |
| | containing an `android.text.style.URLSpan` when exposed as |
| | part of formatted text.] |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.38 `list`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`list`](https://w3c.github.io/aria/#list) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `list` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_LIST`]\ |
| IAccessible2 | [State: `STATE_SYSTEM_READONLY`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `List`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXContentList`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.widget.ListView` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.39 `listbox` without an accessibility parent of `combobox`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`listbox`](https://w3c.github.io/aria/#listbox) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `listbox` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_LIST`]\ |
| IAccessible2 | [Method: `IAccessible::accSelect()`]\ |
| | [Method: `IAccessible::get_accSelection()`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `List`]\ |
| | [Control Pattern: `Selection`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Selection`] |
| | |
| | Because [WAI-ARIA] does not support |
| | modifying the selection via the accessibility [API], user agents *MUST* |
| | return `false` for all `Selection` methods that provide a means |
| | to modify the selection. |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.widget.ListView` |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.40 `listbox` with an accessibility parent of `combobox`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`listbox`](https://w3c.github.io/aria/#listbox) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `listbox` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_LIST`]\ |
| IAccessible2 | [Method: `IAccessible::accSelect()`]\ |
| | [Method: `IAccessible::get_accSelection()`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `List`]\ |
| | [Control Pattern: `Selection`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Selection`] |
| | |
| | Because [WAI-ARIA] does not support |
| | modifying the selection via the accessibility [API], user agents *MUST* |
| | return `false` for all `Selection` methods that provide a means |
| | to modify the selection. |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.widget.ListView` |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.41 `listitem`

+------------------------------------------------------------------+---------------------------------------------------------------------+
| ARIA Specification | [`listitem`](https://w3c.github.io/aria/#listitem) |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Computed Role | `listitem` |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_LISTITEM`]\ |
| IAccessible2 | [State: `STATE_SYSTEM_READONLY`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [UIA] | [Control Type: `ListItem`]\ |
| | [Control Pattern: `SelectionItem`]\ |
| | [SelectionItem.SelectionContainer: the containing |
| | `list`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.42 `log`

+------------------------------------------------------------------+-----------------------------------------------------------+
| ARIA Specification | [`log`](https://w3c.github.io/aria/#log) |
+------------------------------------------------------------------+-----------------------------------------------------------+
| Computed Role | `log` |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [MSAA] + | [Object Attribute: `xml-roles:log`]\ |
| IAccessible2 | [Object Attribute: `container-live:polite`]\ |
| | [Object Attribute: `live:polite`]\ |
| | [Object Attribute: `container-live-role:log`] |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `log`]\ |
| | [LiveSetting: `Polite (1)`] |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:log`]\ |
| | [Object Attribute: `container-live:polite`]\ |
| | [Object Attribute: `live:polite`]\ |
| | [Object Attribute: `container-live-role:log`] |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXApplicationLog`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------+

::: header-wrapper
##### 3.4.3.43 `main`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`main`](https://w3c.github.io/aria/#main) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `main` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_LANDMARK`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:main`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `main`]\ |
| | [Landmark Type: `Main`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:main`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXLandmarkMain`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.44 `mark`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`mark`](https://w3c.github.io/aria/#mark) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `mark` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Role: `IA2_ROLE_MARK`]\ |
| | [Object Attribute: `xml-roles:mark`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Group`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:mark`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXRoleDescription: `highlight`]\ |
| | [AXAttributedStringForTextMarkerRange: contains |
| | `AXHighlight = 1;` for all text contained in a |
| | `mark`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.45 `marquee`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`marquee`](https://w3c.github.io/aria/#marquee) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `marquee` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_ANIMATION`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:marquee`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `marquee`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXApplicationMarquee`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.46 `math`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`math`](https://w3c.github.io/aria/#math) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `math` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_EQUATION`] |
| IAccessible2 | |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `math`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXDocumentMath`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.getStructuredDataInfo` |
| | returns mathematical content in an |
| | `AccessibilityNodeInfo.MathInfo` object.] |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.47 `menu`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`menu`](https://w3c.github.io/aria/#menu) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `menu` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_MENUPOPUP`]\ |
| IAccessible2 | [Method: `IAccessible::accSelect()`]\ |
| | [Method: `IAccessible::get_accSelection()`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Menu`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Selection`] |
| | |
| | Because [WAI-ARIA] does not |
| | support modifying the selection via the accessibility |
| | [API], |
| | user agents *MUST* return `false` for all `Selection` |
| | methods that provide a means to modify the selection. |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.getCollectionInfo` returns |
| | an `AccessibilityNodeInfo.CollectionInfo` object.] |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.48 `menubar`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`menubar`](https://w3c.github.io/aria/#menubar) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `menubar` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_MENUBAR`]\ |
| IAccessible2 | [Method: `IAccessible::accSelect()`]\ |
| | [Method: `IAccessible::get_accSelection()`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `MenuBar`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Selection`] |
| | |
| | Because [WAI-ARIA] does not support |
| | modifying the selection via the accessibility [API], user agents *MUST* |
| | return `false` for all `Selection` methods that provide a means |
| | to modify the selection. |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.getCollectionInfo` returns an |
| | `AccessibilityNodeInfo.CollectionInfo` object.] |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.49 `menuitem`

+------------------------------------------------------------------+---------------------------------------------------------------------+
| ARIA Specification | [`menuitem`](https://w3c.github.io/aria/#menuitem) |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Computed Role | `menuitem` |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_MENUITEM`] |
| IAccessible2 | |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [UIA] | [Control Type: `MenuItem`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Android | `android.view.MenuItem` |
+------------------------------------------------------------------+---------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.50 `menuitemcheckbox`

+------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| ARIA Specification | [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
+------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Computed Role | `menuitemcheckbox` |
+------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_CHECKBUTTON` or `ROLE_SYSTEM_MENUITEM`]\ |
| IAccessible2 | [Role: `IA2_ROLE_CHECK_MENU_ITEM`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| [UIA] | [Control Type: `MenuItem`]\ |
| | [Control Pattern: `Toggle`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Android | `android.view.MenuItem` |
+------------------------------------------------------------------+-------------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.51 `menuitemradio`

+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| ARIA Specification | [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| Computed Role | `menuitemradio` |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_RADIOBUTTON` or `ROLE_SYSTEM_MENUITEM`]\ |
| IAccessible2 | [Role: `IA2_ROLE_RADIO_MENU_ITEM`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [UIA] | [Control Type: `MenuItem`]\ |
| | [Control Pattern: `Toggle`]\ |
| | [Control Pattern: `SelectionItem`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| Android | `android.view.MenuItem` |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.52 `meter`

+------------------------------------------------------------------+---------------------------------------------------------------+
| ARIA Specification | [`meter`](https://w3c.github.io/aria/#meter) |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Computed Role | `meter` |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_LEVEL_BAR`]\ |
| IAccessible2 | [Interface: `IAccessibleValue`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [UIA] | [Control Type: `ProgressBar`]\ |
| | [Localized Control Type: `meter`]\ |
| | [Control Pattern: `RangeValue`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Value`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXMeter`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Android | `android.widget.ProgressBar`\ |
| | [Method: `AccessibilityNodeInfo.getRangeInfo` returns an |
| | `AccessibilityNodeInfo.RangeInfo` object if it represents a |
| | numeric range without `aria-valuetext`.] |
+------------------------------------------------------------------+---------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.53 `navigation`

+------------------------------------------------------------------+-------------------------------------------------------------------------+
| ARIA Specification | [`navigation`](https://w3c.github.io/aria/#navigation) |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Computed Role | `navigation` |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_LANDMARK`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:navigation`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `navigation`]\ |
| | [Landmark Type: `Navigation`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:navigation`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXLandmarkNavigation`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Android | com.google.android.material.navigation.NavigationView |
+------------------------------------------------------------------+-------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.54 `none`

---------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ARIA Specification [`none`](https://w3c.github.io/aria/#none)
 Computed Role `none`
 [MSAA] + IAccessible2 For objects that have specified allowed accessibility children (e.g., a grid with gridcell children, a list with listitem children), and the descendant is in the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree), expose it as `IA2_ROLE_TEXT_FRAME`. [user agents](https://infra.spec.whatwg.org/#user-agent) *SHOULD* prune empty descendants from the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree).
 [UIA] For objects that have specified allowed accessibility children (e.g., a grid with gridcell children, a list with listitem children), and the descendant is in the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree), expose it using the `text` pattern. [user agents](https://infra.spec.whatwg.org/#user-agent) *SHOULD* prune empty descendants from the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree).
 [ATK]/[AT-SPI] For objects that have specified allowed accessibility children (e.g., a grid with gridcell children, a list with listitem children), and the descendant is in the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree), expose it as `ROLE_SECTION`. [user agents](https://infra.spec.whatwg.org/#user-agent) *SHOULD* prune empty descendants from the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree).
 [AX API]^\[[Note\ 1](#ftn.note1)\]^ For objects that have specified allowed accessibility children (e.g., a grid with gridcell children, a list with listitem children), and the descendant is in the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree), expose it as `AXGroup`. [user agents](https://infra.spec.whatwg.org/#user-agent) *SHOULD* prune empty descendants from the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree).
 Android `android.view.View`
 ---------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.4.3.55 `note`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`note`](https://w3c.github.io/aria/#note) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `note` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_NOTE`] |
| IAccessible2 | |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `note`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXDocumentNote`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.56 `option` not inside `combobox`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`option`](https://w3c.github.io/aria/#option) |
| | not inside `combobox` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `option` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_LISTITEM`]\ |
| IAccessible2 | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `ListItem`]\ |
| | [Control Pattern: `Invoke`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)\ |
| | ] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.57 `option` inside `combobox`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`option`](https://w3c.github.io/aria/#option) |
| | inside `combobox` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `option` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_LISTITEM`]\ |
| IAccessible2 | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `ListItem`]\ |
| | [Control Pattern: `Invoke`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)\ |
| | ] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.getCollectionItemInfo` returns |
| | an `AccessibilityNodeInfo.CollectionItemInfo` object.] |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.58 `paragraph`

+------------------------------------------------------------------+-----------------------------------------------------------------------+
| ARIA Specification | [`paragraph`](https://w3c.github.io/aria/#paragraph) |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Computed Role | `paragraph` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Role: `IA2_ROLE_PARAGRAPH`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [UIA] | [Control Type: `Text`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | Note: Exposed as `android.widget.TextView` if the element has only |
| | text children. |
+------------------------------------------------------------------+-----------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.59 `presentation`

---------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ARIA Specification [`presentation`](https://w3c.github.io/aria/#presentation)
 Computed Role `none`
 [MSAA] + IAccessible2 For objects that have specified allowed accessibility children (e.g., a grid with gridcell children, a list with listitem children), and the descendant is in the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree), expose it as `IA2_ROLE_TEXT_FRAME`. [user agents](https://infra.spec.whatwg.org/#user-agent) *SHOULD* prune empty descendants from the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree).
 [UIA] For objects that have specified allowed accessibility children (e.g., a grid with gridcell children, a list with listitem children), and the descendant is in the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree), expose it using the `text` pattern. [user agents](https://infra.spec.whatwg.org/#user-agent) *SHOULD* prune empty descendants from the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree).
 [ATK]/[AT-SPI] For objects that have specified allowed accessibility children (e.g., a grid with gridcell children, a list with listitem children), and the descendant is in the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree), expose it as `ROLE_SECTION`. [user agents](https://infra.spec.whatwg.org/#user-agent) *SHOULD* prune empty descendants from the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree).
 [AX API]^\[[Note\ 1](#ftn.note1)\]^ For objects that have specified allowed accessibility children (e.g., a grid with gridcell children, a list with listitem children), and the descendant is in the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree), expose it as `AXGroup`. [user agents](https://infra.spec.whatwg.org/#user-agent) *SHOULD* prune empty descendants from the [accessibility tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree).
 Android `android.view.View`
 ---------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.4.3.60 `progressbar`

+------------------------------------------------------------------+---------------------------------------------------------------------------+
| ARIA Specification | [`progressbar`](https://w3c.github.io/aria/#progressbar) |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| Computed Role | `progressbar` |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_PROGRESSBAR`]\ |
| IAccessible2 | [State: `STATE_SYSTEM_READONLY`]\ |
| | [Interface: `IAccessibleValue`] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [UIA] | [Control Type: `ProgressBar`]\ |
| | [Control Pattern: `RangeValue` if `aria-valuenow`, `aria-valuemax`, or |
| | `aria-valuemin`] is present |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Value`] |
| | |
| | Because [WAI-ARIA] |
| | does not support modifying the value via the accessibility [API], user agents *MUST* return |
| | `false` for all `Value` methods that provide a means to modify the value. |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| Android | `android.widget.ProgressBar`\ |
| | Note: Exposed with `RangeInfo` if it represents a numeric range without |
| | `aria-valuetext`. |
+------------------------------------------------------------------+---------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.61 `radio`

+------------------------------------------------------------------+---------------------------------------------------------------+
| ARIA Specification | [`radio`](https://w3c.github.io/aria/#radio) |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Computed Role | `radio` |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_RADIOBUTTON`]\ |
| IAccessible2 | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [UIA] | [Control Type: `RadioButton`]\ |
| | [Control Pattern: `Toggle`]\ |
| | [Control Pattern: `SelectionItem`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Android | `android.widget.RadioButton` |
+------------------------------------------------------------------+---------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.62 `radiogroup`

+------------------------------------------------------------------+-------------------------------------------------------------------------+
| ARIA Specification | [`radiogroup`](https://w3c.github.io/aria/#radiogroup) |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Computed Role | `radiogroup` |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`] |
| IAccessible2 | |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [UIA] | [Control Type: `List`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Android | `android.widget.RadioGroup` |
+------------------------------------------------------------------+-------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.63 `region` with an accessible name

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`region`](https://w3c.github.io/aria/#region) |
| | with an accessible name |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `region` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_LANDMARK`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:region`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `region`]\ |
| | [Landmark Type: `Custom`]\ |
| | [Localized Landmark Type: `region`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:region`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXLandmarkRegion`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.64 `region` without an accessible name

---------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ARIA Specification [`region`](https://w3c.github.io/aria/#region) without an accessible name
 Computed Role Use native host language role.
 [MSAA] + IAccessible2 [Do not expose the [element](https://dom.spec.whatwg.org/#concept-element) as a landmark. Use the native host language role of the element instead.]
 [UIA] [Do not expose the [element](https://dom.spec.whatwg.org/#concept-element) as a landmark. Use the native host language role of the element instead.]
 [ATK]/[AT-SPI] [Do not expose the [element](https://dom.spec.whatwg.org/#concept-element) as a landmark. Use the native host language role of the element instead.]
 [AX API]^\[[Note\ 1](#ftn.note1)\]^ [Do not expose the [element](https://dom.spec.whatwg.org/#concept-element) as a landmark. Use the native host language role of the element instead.]
 Android `android.view.View`
 ---------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.4.3.65 `row` not inside `treegrid`

+------------------------------------------------------------------+-----------------------------------------------------------+
| ARIA Specification | [`row`](https://w3c.github.io/aria/#row) |
| | not inside `treegrid` |
+------------------------------------------------------------------+-----------------------------------------------------------+
| Computed Role | `row` |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_ROW`] |
| IAccessible2 | |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [UIA] | [Control Type: `DataItem`]\ |
| | [Localized Control Type: `row`]\ |
| | [Control Pattern: `SelectionItem`] |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------+

::: header-wrapper
##### 3.4.3.66 `row` inside `treegrid`

+------------------------------------------------------------------+-----------------------------------------------------------+
| ARIA Specification | [`row`](https://w3c.github.io/aria/#row) |
| | inside `treegrid` |
+------------------------------------------------------------------+-----------------------------------------------------------+
| Computed Role | `row` |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_OUTLINEITEM`] |
| IAccessible2 | |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [UIA] | [Control Type: `DataItem`]\ |
| | [Localized Control Type: `row`]\ |
| | [Control Pattern: `SelectionItem`] |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-----------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------+
| Android | `android.view.View`\ |
| | Note: Exposed with `CollectionItemInfo`. |
+------------------------------------------------------------------+-----------------------------------------------------------+

::: header-wrapper
##### 3.4.3.67 `rowgroup`

---------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------
 ARIA Specification [`rowgroup`](https://w3c.github.io/aria/#rowgroup)
 Computed Role `rowgroup`
 [MSAA] + IAccessible2 [Role: `ROLE_SYSTEM_GROUPING`]
 [UIA] [Control Type: `Group`]
 [ATK]/[AT-SPI] [Role: `ROLE_PANEL`]
 [AX API]^\[[Note\ 1](#ftn.note1)\]^ [[Not mapped](#not_mapped)]
 Android `android.view.View`
 ---------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------

::: header-wrapper
##### 3.4.3.68 `rowheader`

+------------------------------------------------------------------+-----------------------------------------------------------------------+
| ARIA Specification | [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Computed Role | `rowheader` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_ROWHEADER`]\ |
| IAccessible2 | [Interface: `IAccessibleTableCell`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [UIA] | [Control Type: `HeaderItem`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `TableCell`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.69 `scrollbar`

+------------------------------------------------------------------+-----------------------------------------------------------------------+
| ARIA Specification | [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Computed Role | `scrollbar` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_SCROLLBAR`]\ |
| IAccessible2 | [Interface: `IAccessibleValue`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [UIA] | [Control Type: `ScrollBar`]\ |
| | [Control Pattern: `RangeValue`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Value`] |
| | |
| | Because [WAI-ARIA] does not support |
| | modifying the value via the accessibility [API], user agents *MUST* return |
| | `false` for all `Value` methods that provide a means to modify the |
| | value. |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | Note: Exposed with `RangeInfo` if it represents a numeric range |
| | without `aria-valuetext`. |
+------------------------------------------------------------------+-----------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.70 `search`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`search`](https://w3c.github.io/aria/#search) |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `search` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_LANDMARK`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:search`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `search`]\ |
| | [Landmark Type: `Search`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:search`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXLandmarkSearch`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.widget.SearchView` |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.71 `searchbox`

+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| ARIA Specification | [`searchbox`](https://w3c.github.io/aria/#searchbox) |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| Computed Role | `searchbox` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_TEXT`]\ |
| IAccessible2 | [Object Attribute: `text-input-type:search`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [UIA] | [Control Type: `Edit`]\ |
| | [Localized Control Type: `search box`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:searchbox`]\ |
| | [Object Attribute: `text-input-type:search` ]\ |
| | [Interface: `EditableText` if |
| | [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | is not `"true"`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXSearchField`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| Android | `android.widget.EditText` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.72 `sectionfooter`

+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| ARIA Specification | [`sectionfooter`](https://w3c.github.io/aria/#sectionfooter) |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| Computed Role | `sectionfooter` |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:sectionfooter`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `section footer`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXSectionFooter`]\ |
| | [AXRoleDescription: `section footer`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.73 `sectionheader`

+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| ARIA Specification | [`sectionheader`](https://w3c.github.io/aria/#sectionheader) |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| Computed Role | `sectionheader` |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:sectionheader`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `section header`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXSectionHeader`]\ |
| | [AXRoleDescription: `section header`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.74 `separator` (non-focusable)

+------------------------------------------------------------------+-----------------------------------------------------------------------+
| ARIA Specification | [`separator`](https://w3c.github.io/aria/#separator) |
| | (non-focusable) |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Computed Role | `seperator` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_SEPARATOR`] |
| IAccessible2 | |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [UIA] | [Control Type: `Separator`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.75 `separator` (focusable)

+------------------------------------------------------------------+-----------------------------------------------------------------------+
| ARIA Specification | [`separator`](https://w3c.github.io/aria/#separator) |
| | (focusable) |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Computed Role | `seperator` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_SEPARATOR`]\ |
| IAccessible2 | [Interface: `IAccessibleValue`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [UIA] | [Control Type: `Thumb`]\ |
| | [Control Pattern: `RangeValue`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Value`] |
| | |
| | Because [WAI-ARIA] does not support |
| | modifying the value via the accessibility [API], user agents *MUST* return |
| | `false` for all `Value` methods that provide a means to modify the |
| | value. |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | Note: Exposed with `RangeInfo` if it represents a numeric range |
| | without `aria-valuetext`. |
+------------------------------------------------------------------+-----------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.76 `slider`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`slider`](https://w3c.github.io/aria/#slider) |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `slider` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_SLIDER`]\ |
| IAccessible2 | [Interface: `IAccessibleValue`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `Slider`]\ |
| | [Control Pattern: `RangeValue`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Value`] |
| | |
| | Because [WAI-ARIA] does not support |
| | modifying the value via the accessibility [API], user agents *MUST* |
| | return `false` for all `Value` methods that provide a means to |
| | modify the value. |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.widget.SeekBar` |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.77 `spinbutton`

+------------------------------------------------------------------+-------------------------------------------------------------------------+
| ARIA Specification | [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Computed Role | `spinbutton` |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_SPINBUTTON`]\ |
| IAccessible2 | [Interface: `IAccessibleValue`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [UIA] | [Control Type: `Spinner`]\ |
| | [Control Pattern: `RangeValue`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Value`] |
| | |
| | Because [WAI-ARIA] |
| | does not support modifying the value via the accessibility [API], user agents *MUST* return |
| | `false` for all `Value` methods that provide a means to modify the |
| | value. |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Android | `android.widget.EditText`\ |
| | Note: Exposed with `RangeInfo` if it represents a numeric range without |
| | `aria-valuetext`. |
+------------------------------------------------------------------+-------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.78 `status`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`status`](https://w3c.github.io/aria/#status) |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `status` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_STATUSBAR`]\ |
| IAccessible2 | [Object Attribute: `container-live:polite`]\ |
| | [Object Attribute: `live:polite`]\ |
| | [Object Attribute: `container-live-role:status`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `status`]\ |
| | [LiveSetting: `Polite (1)`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `container-live:polite`]\ |
| | [Object Attribute: `live:polite`]\ |
| | [Object Attribute: `container-live-role:status`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXApplicationStatus`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.getLiveRegion`: |
| | `View.ACCESSIBILITY_LIVE_REGION_POLITE`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.79 `strong`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`strong`](https://w3c.github.io/aria/#strong) |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `strong` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_TEXT_FRAME`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:strong`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `Text`]\ |
| | [Localized Control Type: `strong`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:strong`] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXStrongStyleGroup`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.getText` returns text |
| | containing an `android.text.style.StyleSpan` with |
| | `android.graphics.Typeface.BOLD`.] |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.80 `subscript`

+------------------------------------------------------------------+-----------------------------------------------------------------------+
| ARIA Specification | [`subscript`](https://w3c.github.io/aria/#subscript) |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Computed Role | `subscript` |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Role: `IA2_ROLE_TEXT_FRAME`]\ |
| | [Text Attribute: `text-position:sub`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [UIA] | [Control Type: `Text`]\ |
| | [Styles used are exposed by `IsSubscript` attribute of the |
| | `TextRange` Control Pattern implemented on the accessible |
| | object.] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXSubscriptStyleGroup`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.getText` returns text containing an |
| | `android.text.style.SubscriptSpan`.] |
+------------------------------------------------------------------+-----------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.81 `suggestion`

+------------------------------------------------------------------+-------------------------------------------------------------------------+
| ARIA Specification | [`suggestion`](https://w3c.github.io/aria/#suggestion) |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Computed Role | `suggestion` |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_SUGGESTION`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:suggestion`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `suggestion`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:suggestion`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXAttributedStringForTextMarkerRange: contains `AXIsSuggestion = 1;` |
| | for all text contained in a `suggestion`] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.getText` returns text containing an |
| | `android.text.style.SuggestionSpan`.] |
+------------------------------------------------------------------+-------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.82 `superscript`

+------------------------------------------------------------------+---------------------------------------------------------------------------+
| ARIA Specification | [`superscript`](https://w3c.github.io/aria/#superscript) |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| Computed Role | `superscript` |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Role: `IA2_ROLE_TEXT_FRAME`]\ |
| | [Text Attribute: `text-position:super`] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [UIA] | [Control Type: `Text`]\ |
| | [Styles used are exposed by `IsSuperscript` attribute of the `TextRange` |
| | Control Pattern implemented on the accessible object.] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXSuperscriptStyleGroup`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | [Method: `AccessibilityNodeInfo.getText` returns text containing an |
| | `android.text.style.SuperscriptSpan`.] |
+------------------------------------------------------------------+---------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.83 `switch`

+------------------------------------------------------------------+-----------------------------------------------------------------+
| ARIA Specification | [`switch`](https://w3c.github.io/aria/#switch) |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Computed Role | `switch` |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_CHECKBUTTON`]\ |
| IAccessible2 | [Role: `IA2_ROLE_TOGGLE_BUTTON`]\ |
| | [Object Attribute: `xml-roles:switch`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [UIA] | [Control Type: `Button`]\ |
| | [Localized Control Type: `toggleswitch`]\ |
| | [Control Pattern: `Toggle`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:switch`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXSwitch`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+-----------------------------------------------------------------+
| Android | `android.widget.Switch` |
+------------------------------------------------------------------+-----------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.84 `tab`

+------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| ARIA Specification | [`tab`](https://w3c.github.io/aria/#tab) |
+------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| Computed Role | `tab` |
+------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_PAGETAB`]\ |
| IAccessible2 | [State: `STATE_SYSTEM_SELECTED` if focus is inside |
| | [`tabpanel`](https://w3c.github.io/aria/#tabpanel) associated with |
| | [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)] |
+------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| [UIA] | [Control Type: `TabItem`] |
+------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [State: `STATE_SELECTED` if focus is inside |
| | [`tabpanel`](https://w3c.github.io/aria/#tabpanel) associated with |
| | [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)] |
+------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXTabButton`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | Note: Exposed with `CollectionItemInfo`. |
+------------------------------------------------------------------+---------------------------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.85 `table`

+------------------------------------------------------------------+---------------------------------------------------------------+
| ARIA Specification | [`table`](https://w3c.github.io/aria/#table) |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Computed Role | `table` |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_TABLE`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:table`]\ |
| | [Interface: `IAccessibleTable2`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [UIA] | [Control Type: `Table`]\ |
| | [Control Pattern: `Grid`]\ |
| | [Control Pattern: `Table`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:table`]\ |
| | [Interface: `Table`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
| | [AXColumnHeaderUIElements: a list of pointers to the |
| | columnheader elements]\ |
| | [AXHeader: a pointer to the row or group containing those |
| | columnheader elements]\ |
| | [AXRowHeaderUIElements: a list of pointers to the rowheader |
| | elements] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Android | `android.widget.GridView` |
+------------------------------------------------------------------+---------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.86 `tablist`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`tablist`](https://w3c.github.io/aria/#tablist) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `tablist` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_PAGETABLIST`]\ |
| IAccessible2 | [Method: `IAccessible::accSelect()`]\ |
| | [Method: `IAccessible::get_accSelection()`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `Tab`]\ |
| | [Control Pattern: `Selection`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Selection`] |
| | |
| | Because [WAI-ARIA] does not support |
| | modifying the selection via the accessibility [API], user agents *MUST* |
| | return `false` for all `Selection` methods that provide a means |
| | to modify the selection. |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.widget.TabWidget` |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.87 `tabpanel`

+------------------------------------------------------------------+---------------------------------------------------------------------+
| ARIA Specification | [`tabpanel`](https://w3c.github.io/aria/#tabpanel) |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Computed Role | `tabpanel` |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_PANE` or `ROLE_SYSTEM_PROPERTYPAGE`] |
| IAccessible2 | |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [UIA] | [Control Type: `Pane`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXTabPanel`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.88 `term`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`term`](https://w3c.github.io/aria/#term) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `term` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `IA2_ROLE_TEXT_FRAME`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:term`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Text`]\ |
| | [Localized Control Type: `term`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXTerm`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.89 `textbox` when `aria-multiline` is `false`

+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| ARIA Specification | [`textbox`](https://w3c.github.io/aria/#textbox) when |
| | `aria-multiline` is `false` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| Computed Role | `textbox` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_TEXT`]\ |
| IAccessible2 | [State: `IA2_STATE_SINGLE_LINE`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [UIA] | [Control Type: `Edit`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [State: `STATE_SINGLE_LINE`]\ |
| | [Interface: `EditableText` if |
| | [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | is not `"true"`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| Android | `android.widget.EditText` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.90 `textbox` when `aria-multiline` is `true`

+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| ARIA Specification | [`textbox`](https://w3c.github.io/aria/#textbox) when |
| | `aria-multiline` is `true` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| Computed Role | `textbox` |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_TEXT`]\ |
| IAccessible2 | [State: `IA2_STATE_MULTI_LINE`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [UIA] | [Control Type: `Edit`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [State: `STATE_MULTI_LINE`]\ |
| | [Interface: `EditableText` if |
| | [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | is not `"true"`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+
| Android | `android.widget.EditText`\ |
| | [Method: `AccessibilityNodeInfo.isMultiLine`: `true`] |
+------------------------------------------------------------------+-----------------------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.91 `time`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`time`](https://w3c.github.io/aria/#time) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `time` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_GROUPING`]\ |
| IAccessible2 | [Object Attribute: `xml-roles:time`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Text`]\ |
| | [Localized Control Type: `time`]\ |
| | Note: create a separate [UIA] Control of type Text. |
| | This is different from most [UIA] text mappings, which |
| | only create ranges in the page text pattern. |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Object Attribute: `xml-roles:time`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXTimeGroup`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.widget.TimePicker` |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.92 `timer`

+------------------------------------------------------------------+---------------------------------------------------------------+
| ARIA Specification | [`timer`](https://w3c.github.io/aria/#timer) |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Computed Role | `timer` |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [MSAA] + | [Object Attribute: `xml-roles:timer`] |
| IAccessible2 | |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [UIA] | [Control Type: `Group`]\ |
| | [Localized Control Type: `timer`] |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+---------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXApplicationTimer`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+---------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.93 `toolbar`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`toolbar`](https://w3c.github.io/aria/#toolbar) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `toolbar` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_TOOLBAR`] |
| IAccessible2 | |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `ToolBar`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.view.View` |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.94 `tooltip`

+------------------------------------------------------------------+-------------------------------------------------------------------+
| ARIA Specification | [`tooltip`](https://w3c.github.io/aria/#tooltip) |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Computed Role | `tooltip` |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_TOOLTIP`] |
| IAccessible2 | |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [UIA] | [Control Type: `ToolTip`] |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [ATK]/[AT-SPI] |
| title="Assistive Technology - Service Provider Interface"} | |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXUserInterfaceTooltip`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | Note: The tooltip text is typically exposed via |
| | `AccessibilityNodeInfo.getTooltipText` on the associated anchor |
| | element. |
+------------------------------------------------------------------+-------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.95 `tree`

+------------------------------------------------------------------+-------------------------------------------------------------+
| ARIA Specification | [`tree`](https://w3c.github.io/aria/#tree) |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Computed Role | `tree` |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_OUTLINE`]\ |
| IAccessible2 | [Method: `IAccessible::accSelect()`]\ |
| | [Method: `IAccessible::get_accSelection()`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [UIA] | [Control Type: `Tree`] |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Selection`] |
| | |
| | Because [WAI-ARIA] does not |
| | support modifying the selection via the accessibility |
| | [API], |
| | user agents *MUST* return `false` for all `Selection` |
| | methods that provide a means to modify the selection. |
+------------------------------------------------------------------+-------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+-------------------------------------------------------------+
| Android | `android.view.View`\ |
| | Note: Exposed with `CollectionInfo`. |
+------------------------------------------------------------------+-------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.96 `treegrid`

+------------------------------------------------------------------+---------------------------------------------------------------------+
| ARIA Specification | [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Computed Role | `treegrid` |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_OUTLINE`]\ |
| IAccessible2 | [Interface: `IAccessibleTable2`]\ |
| | [Method: `IAccessible::accSelect()`]\ |
| | [Method: `IAccessible::get_accSelection()`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [UIA] | [Control Type: `DataGrid`] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [Interface: `Table`]\ |
| | [Interface: `Selection`] |
| | |
| | Because [WAI-ARIA] does not support |
| | modifying the selection via the accessibility [API], user agents *MUST* |
| | return `false` for all `Selection` methods that provide a means to |
| | modify the selection. |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `<nil>`]\ |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Android | `android.widget.GridView` |
+------------------------------------------------------------------+---------------------------------------------------------------------+

::: header-wrapper
##### 3.4.3.97 `treeitem`

+------------------------------------------------------------------+---------------------------------------------------------------------+
| ARIA Specification | [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Computed Role | `treeitem` |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [MSAA] + | [Role: `ROLE_SYSTEM_OUTLINEITEM`]\ |
| IAccessible2 | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [UIA] | [Control Type: `TreeItem`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [ATK]/[AT-SPI]\ |
| title="Assistive Technology - Service Provider Interface"} | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| [AX API]\ |
| title="macOS Accessibility Protocol"}^\[[Note\ 1](#ftn.note1)\]^ | [AXSubrole: `AXOutlineRow`]\ |
| | [See also: `aria-checked` in the [State and Property Mapping |
| | Tables](#mapping_state-property_table)] |
+------------------------------------------------------------------+---------------------------------------------------------------------+
| Android | `android.view.View`\ |
| | Note: Exposed with `CollectionItemInfo`. |
+------------------------------------------------------------------+---------------------------------------------------------------------+

^\[Note\ 1\]^ User agent should return a user-presentable, localized
string value for the AXRoleDescription.

^\[Note\ 2\]^ This specification does not currently contain guidance for
when user agents should fire system alert events. Some guidance may be
added to the specification at a later date but it will be a
recommendation (*SHOULD*), not a requirement (*MUST*).

::: header-wrapper
### 3.5 State and Property Mapping

This section describes how to expose [WAI-ARIA]
[states](https://www.w3.org/TR/wai-aria/#dfn-state) and
[properties](https://www.w3.org/TR/wai-aria/#dfn-property "Normative reference to non-normative term.").

::: header-wrapper
#### 3.5.1 General rules

1. [User
 agents](https://infra.spec.whatwg.org/#user-agent)
 *MUST* compute [managed
 states](https://www.w3.org/TR/wai-aria/#dfn-managed-state) `VISIBLE`/`INVISIBLE`,
 `SHOWING`/`OFFSCREEN`, etc. This typically is done in the same way
 as for ordinary
 [elements](https://dom.spec.whatwg.org/#concept-element) that do not have [WAI-ARIA] attributes present.
 The `FOCUSABLE`/`FOCUSED` states may be affected by
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant).
2. User agents *MUST* continue to expose native semantics in addition
 to [WAI-ARIA]
 state and property semantics except where an explicit
 [WAI-ARIA]
 override is allowed by the host language. For example, an
 [HTML] checkbox may have an
 [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
 attribute but the native [HTML] semantics must still be exposed.
3. User agents *MUST* expose additional states for certain
 [roles](https://www.w3.org/TR/wai-aria-1.3/#dfn-role) as defined
 in the [Role Mapping Tables](#mapping_role_table).
4. User agents *MUST* compute states for the relevant [WAI-ARIA]
 [attributes](https://dom.spec.whatwg.org/#concept-attribute) and map to the [accessibility
 [API]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api) as specified in the [State and
 Property Mapping Tables](#mapping_state-property_table). To
 determine the relevant [WAI-ARIA] attributes, refer to
 the [Definition of
 Roles](https://w3c.github.io/aria/#role_definitions)
 \[[WAI-ARIA-1.2](#bib-wai-aria-1-2 "Accessible Rich Internet Applications (WAI-ARIA) 1.2")\]\]. Where the author has not provided values
 for required attributes, user agents *SHOULD* process as if the
 default value was provided.
5. Some [WAI-ARIA]
 properties are not global, and are only supported on certain roles.
 If a non-global [WAI-ARIA] state or property is
 used where it is not supported, user agents *SHOULD NOT* map the
 given [WAI-ARIA]
 property to the platform accessibility [API]. For example, if
 `aria-checked="true"` is specified on `<div >`, it should
 not be exposed in [MSAA] implementations as
 `STATE_SYSTEM_CHECKED`.
6. When an explicit or inherited role of `none` or `presentation` is
 applied to an element, the user agent *MUST* implement the rules for
 the [`none`](https://w3c.github.io/aria/#none) or
 the
 [`presentation`](https://w3c.github.io/aria/#presentation)
 [role](https://www.w3.org/TR/wai-aria-1.3/#dfn-role) defined in
 [Accessible Rich Internet Applications ([WAI-ARIA])
 1.2](https://w3c.github.io/aria/)
 \[[WAI-ARIA-1.2](#bib-wai-aria-1-2 "Accessible Rich Internet Applications (WAI-ARIA) 1.2")\]\].

::: header-wrapper
#### 3.5.2 State and Property Mapping Tables

::: header-wrapper
##### 3.5.2.1 Not Mapped

There are a number of occurrences in the table where a given state or
property is declared \"Not mapped\". In some cases, this occurs for the
default value of the state/property, and is equivalent to its absence.
User agents might find it quicker to map the value than check to see if
it is the default. For computational efficiency, user agents *MAY*
expose the state or property value if doing so is equivalent to not
mapping it. These cases are marked with an asterisk.

In other cases, it is mandatory that the state/property not be mapped,
since exposing it implies a related affordance. An example is
[`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed).
Its absence not only indicates that the accessible object is not
grabbed, but further defines it as not grab-able. These cases are marked
as \"Not mapped\" without an asterisk.

::: header-wrapper
##### 3.5.2.2 `aria-activedescendant`

---------------------------------------------------------- ---------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)

 [MSAA] + See [Focus Changes](#focus_state_event_table).
 IAccessible2

 [UIA] See [Focus Changes](#focus_state_event_table).

 [ATK]/[AT-SPI]

 [AX API] See [Focus Changes](#focus_state_event_table).\
 [Property: `AXSelectedRows`: pointer to active descendant node]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.3 `aria-atomic`=`true`

---------------------------------------------------------- --------------------------------------------------------------------------------------
 ARIA Specification [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)=`true`

 [MSAA] + [Object Attribute: `atomic:true`]\
 IAccessible2 [Object Attribute: `container-atomic:true`]\
 [Object Attribute: `container-atomic:true` on all descendants]\
 [Relation: `IA2_RELATION_MEMBER_OF` pointing to this element (the atomic
 root)]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [UIA] [Property: `AriaProperties.atomic`: `true`]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `container-atomic:true`]\
 [Object Attribute: `container-atomic:true` on all descendants]\
 [Relation: `RELATION_MEMBER_OF` pointing to this element (the atomic
 root)]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [AX API] [Property: `AXARIAAtomic`: `YES`]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 Android TBD
 ---------------------------------------------------------- --------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.4 `aria-atomic`=`false`

---------------------------------------------------------- ---------------------------------------------------------------------------------------
 ARIA Specification [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)=`false`

 [MSAA] + [[Not mapped\*](#not_mapped), but if mapped:]\
 IAccessible2 [Object Attribute: `atomic:false`]\
 [Object Attribute: `container-atomic:false`]\
 [Object Attribute: `container-atomic:false` on all descendants]\
 [Relation: `IA2_RELATION_MEMBER_OF` pointing to this element (the atomic
 root)]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [UIA] [Property: `AriaProperties.atomic`: `false`]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `atomic:false`]\
 [Object Attribute: `container-atomic:false`]\
 [Object Attribute: `container-atomic:false` on all descendants]\
 [Relation: `RELATION_MEMBER_OF` pointing to this element (the atomic root)]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [AX API] [Property: `AXARIAAtomic`: `NO`]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.5 `aria-autocomplete`=`inline`, `list`, or `both`

---------------------------------------------------------- -----------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-autocomplete`](https://w3c.github.io/aria/#aria-autocomplete)=`inline`,
 `list`, or `both`

 [MSAA] + [Object Attribute: `autocomplete:<value>`]\
 IAccessible2 [State: `IA2_STATE_SUPPORTS_AUTOCOMPLETION`]

 [UIA] [[Not mapped](#not_mapped)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_SUPPORTS_AUTOCOMPLETION`]

 [AX API] [[Not mapped](#not_mapped)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.6 `aria-autocomplete`=`none`

-------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-autocomplete`](https://w3c.github.io/aria/#aria-autocomplete)=`none`
 [MSAA] + IAccessible2 [[Not mapped\*](#not_mapped)]
 [UIA] [[Not mapped\*](#not_mapped)]
 [ATK]/[AT-SPI] [[Not mapped\*](#not_mapped)]
 [AX API] [[Not mapped\*](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.7 `aria-braillelabel`

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel)
 [MSAA] + IAccessible2 [Object Attribute: `braillelabel:<value>`]
 [UIA] [Property: `AriaProperties.braillelabel`: `<value>`]
 [ATK]/[AT-SPI] [Object Attribute: `braillelabel:<value>`]
 [AX API] [Property: AXBrailleLabel]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.8 `aria-brailleroledescription`

-------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription)
 [MSAA] + IAccessible2 [Object Attribute: `brailleroledescription:<value>`]
 [UIA] [Property: `AriaProperties.brailleroledescription`: `<value>`]
 [ATK]/[AT-SPI] [Object Attribute: `brailleroledescription:<value>`]
 [AX API] [Property: AXBrailleRoleDescription]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.9 `aria-brailleroledescription` is undefined or the empty string

-------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) is undefined or the empty string
 [MSAA] + IAccessible2 [[Not mapped](#not_mapped)]
 [UIA] [[Not mapped](#not_mapped)]
 [ATK]/[AT-SPI] [[Not mapped](#not_mapped)]
 [AX API] [[Not mapped](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.10 `aria-busy`=`true`

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------
 ARIA Specification [`aria-busy`](https://w3c.github.io/aria/#aria-busy)=`true`
 [MSAA] + IAccessible2 [State: `STATE_SYSTEM_BUSY`]
 [UIA] [Property: `AriaProperties.busy`: `true`]
 [ATK]/[AT-SPI] [State: `STATE_BUSY`]
 [AX API] [Property: `AXElementBusy`: `YES`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.11 `aria-busy`=`false`

-------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------
 ARIA Specification [`aria-busy`](https://w3c.github.io/aria/#aria-busy)=`false`
 [MSAA] + IAccessible2 [State: `STATE_SYSTEM_BUSY` not exposed]
 [UIA] [Property: `AriaProperties.busy`: `false`]
 [ATK]/[AT-SPI] [State: `STATE_BUSY` not exposed]
 [AX API] [Property: `AXElementBusy`: `NO`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.12 `aria-checked`=`true`

---------------------------------------------------------- -------------------------------------------------------------------------------------
 ARIA Specification [`aria-checked`](https://w3c.github.io/aria/#aria-checked)=`true`

 [MSAA] + [State: `STATE_SYSTEM_CHECKED`]\
 IAccessible2 [Object Attribute: `checkable:true`]

 [UIA] [Property: `Toggle.ToggleState`: `On (1)`]\
 [Property: `SelectionItem.IsSelected`: `True` for `radio` and
 `menuitemradio`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_CHECKED`]

 [AX API] [Property: `AXValue`: `1`]\
 [Property: `AXMenuItemMarkChar`: `✓` for `menuitemcheckbox` and
 `menuitemradio`]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.13 `aria-checked`=`false`

---------------------------------------------------------- --------------------------------------------------------------------------------------
 ARIA Specification [`aria-checked`](https://w3c.github.io/aria/#aria-checked)=`false`

 [MSAA] + [State: `STATE_SYSTEM_CHECKED` not exposed]\
 IAccessible2 [Object Attribute: `checkable:true`]

 [UIA] [Property: `Toggle.ToggleState`: `Off (0)`]\
 [Property: `SelectionItem.IsSelected`: `False` for `radio` and
 `menuitemradio`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_CHECKED` not exposed]

 [AX API] [Property: `AXValue`: `0`]\
 [Property: `AXMenuItemMarkChar`: `<nil>` for `menuitemcheckbox` and
 `menuitemradio`]

 Android TBD
 ---------------------------------------------------------- --------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.14 `aria-checked`=`mixed`

---------------------------------------------------------- --------------------------------------------------------------------------------------
 ARIA Specification [`aria-checked`](https://w3c.github.io/aria/#aria-checked)=`mixed`

 [MSAA] + [State: `STATE_SYSTEM_MIXED`]\
 IAccessible2 [Object Attribute: `checkable:true`]

 [UIA] [Property: `Toggle.ToggleState`: `Indeterminate (2)`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_CHECKABLE`]\
 [State: `STATE_CHECKED` not exposed]

 [AX API] [Property: `AXValue`: `2`]\
 [Property: `AXMenuItemMarkChar`: `<nil>` for `menuitemcheckbox` and
 `menuitemradio`]

 Android TBD
 ---------------------------------------------------------- --------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.15 `aria-checked` is undefined

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-checked`](https://w3c.github.io/aria/#aria-checked) is undefined
 [MSAA] + IAccessible2 [[Not mapped](#not_mapped)]
 [UIA] [[Not mapped](#not_mapped)]
 [ATK]/[AT-SPI] [[Not mapped](#not_mapped)]
 [AX API] [[Not mapped](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.16 `aria-colcount`

---------------------------------------------------------- -----------------------------------------------------------------------------------
 ARIA Specification [`aria-colcount`](https://w3c.github.io/aria/#aria-colcount)

 [MSAA] + [Object Attribute: `colcount:<value>`]\
 IAccessible2 [Method: `IAccessible2::groupPosition()`: `similarItemsInGroup=<value>` on cells
 and headers]

 [UIA] [Property: `Grid.ColumnCount`: `<value>`]

 [ATK]/[AT-SPI] value.]\
 [Method: `atk_table_get_n_columns()` should return the actual number of
 columns.]

 [AX API] [Property: `AXARIAColumnCount`: `<value>`]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.17 `aria-colindex`

---------------------------------------------------------- -----------------------------------------------------------------------------------
 ARIA Specification [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)

 [MSAA] + [Object Attribute: `colindex:<value>`]\
 IAccessible2 [Method: `IAccessible2::groupPosition()`: `positionInGroup=<value>` on cells and
 headers]

 [UIA] [Property: `GridItem.Column`: `<value>` (zero-based)]

 [ATK]/[AT-SPI] value.]\
 [Method: `atk_table_cell_get_position()` should return the actual (zero-based)
 column index.]

 [AX API] [Property: `AXARIAColumnIndex`: `<value>`]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.18 `aria-colindextext`

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext)
 [MSAA] + IAccessible2 [Object Attribute: `colindextext:<value>`]
 [UIA] [Property: `AriaProperties.colindextext`: `<value>`]
 [ATK]/[AT-SPI] [Object Attribute: `colindextext:<value>`]
 [AX API] [Property: `AXColumnIndexDescription`: `<value>`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.19 `aria-colspan`

---------------------------------------------------------- ---------------------------------------------------------------------------------
 ARIA Specification [`aria-colspan`](https://w3c.github.io/aria/#aria-colspan)

 [MSAA] + [Object Attribute: `colspan:<value>`]\
 IAccessible2 [Method: `IAccessibleTableCell::columnExtent()`: `<value>`]

 [UIA] [Property: `GridItem.ColumnSpan`: `<value>`]

 [ATK]/[AT-SPI] value.]\
 [Method: `atk_table_cell_get_row_column_span()` should return the actual column
 span.]

 [AX API] [Property: `AXColumnIndexRange.length`: `<value>`]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.20 `aria-controls`

---------------------------------------------------------- -----------------------------------------------------------------------------------
 ARIA Specification [`aria-controls`](https://w3c.github.io/aria/#aria-controls)

 [MSAA] + [Relation: `IA2_RELATION_CONTROLLER_FOR` points to accessible nodes matching
 IAccessible2 IDREFs]\
 [Reverse Relation: `IA2_RELATION_CONTROLLED_BY` points to element]\
 [See also: [Mapping Additional Relations](#mapping_additional_relations)]

 [UIA] [Property: `ControllerFor`: pointers to accessible nodes matching
 IDREFs]

 [ATK]/[AT-SPI] IDREFs]\
 [Reverse Relation: `RELATION_CONTROLLED_BY` points to element]\
 [See also: [Mapping Additional Relations](#mapping_additional_relations)]

 [AX API] [Property: `AXLinkedUIElements`: pointers to accessible nodes matching
 IDREFs]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.21 `aria-current` with non-`false` allowed value

---------------------------------------------------------- ------------------------------------------------------------------------------
 ARIA Specification [`aria-current`](https://w3c.github.io/aria/#aria-current)
 with non-`false` allowed value

 [MSAA] + [Object Attribute: `current:<value>`]
 IAccessible2

 [UIA] [Property: `AriaProperties.current`: `<value>`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_ACTIVE`]

 [AX API] [Property: `AXARIACurrent`: `<value>`]

 Android TBD
 ---------------------------------------------------------- ------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.22 `aria-current` with unrecognized value

---------------------------------------------------------- ------------------------------------------------------------------------------
 ARIA Specification [`aria-current`](https://w3c.github.io/aria/#aria-current)
 with unrecognized value

 [MSAA] + [Object Attribute: `current:true`]
 IAccessible2

 [UIA] [Property: `AriaProperties.current`: `true`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_ACTIVE`]

 [AX API] [Property: `AXARIACurrent`: `true`]

 Android TBD
 ---------------------------------------------------------- ------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.23 `aria-current` is `false` or undefined

-------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-current`](https://w3c.github.io/aria/#aria-current) is `false` or undefined
 [MSAA] + IAccessible2 [[Not mapped\*](#not_mapped)]
 [UIA] [[Not mapped\*](#not_mapped)]
 [ATK]/[AT-SPI] [[Not mapped\*](#not_mapped)]
 [AX API] [[Not mapped\*](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.24 `aria-describedby`

---------------------------------------------------------- -----------------------------------------------------------------------------------------
 ARIA Specification [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)

 [MSAA] + [Property: `accDescription`: `<value>`]\
 IAccessible2 [Relation: `IA2_RELATION_DESCRIBED_BY` points to accessible nodes matching IDREFs, if the
 referenced objects are in the accessibility tree]\
 [Reverse Relation: `IA2_RELATION_DESCRIPTION_FOR` points to element]\
 [See also: [Name Computation](#mapping_additional_nd) and [Mapping Additional
 Relations](#mapping_additional_relations)]

 [UIA] [Property: `FullDescription`: `<value>`]\
 [See also: [Name Computation](#mapping_additional_nd)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Relation: `RELATION_DESCRIBED_BY` points to accessible nodes matching IDREFs, if the
 referenced objects are in the accessibility tree]\
 [Reverse Relation: `RELATION_DESCRIPTION_FOR` points to element]\
 [See also: [Name Computation](#mapping_additional_nd) and [Mapping Additional
 Relations](#mapping_additional_relations)]

 [AX API] [In the accessibilityCustomContent [API], expose as an `AXCustomContent` object with
 `{ label: "description" }` and \``value`\` set to the description string.]\
 - [See also: [Name Computation](#mapping_additional_nd)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.25 `aria-description`

---------------------------------------------------------- -----------------------------------------------------------------------------------------
 ARIA Specification [`aria-description`](https://w3c.github.io/aria/#aria-description)

 [MSAA] + [Property: `accDescription`: `<value>`]\
 IAccessible2 [See also: [Name Computation](#mapping_additional_nd)]

 [UIA] [Property: `FullDescription`: `<value>`]\
 [See also: [Name Computation](#mapping_additional_nd)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [Name Computation](#mapping_additional_nd)]

 [AX API] [In the accessibilityCustomContent [API], expose as an `AXCustomContent` object with
 `{ label: "description" }` and \``value`\` set to the description string.]\
 [See also: [Name Computation](#mapping_additional_nd)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.26 `aria-details`

---------------------------------------------------------- ---------------------------------------------------------------------------------
 ARIA Specification [`aria-details`](https://w3c.github.io/aria/#aria-details)

 [MSAA] + [Relation: `IA2_RELATION_DETAILS` points to accessible nodes matching IDREFs, if
 IAccessible2 the referenced objects are in the accessibility tree]\
 [Reverse Relation: `IA2_RELATION_DETAILS_FOR` points to element]\
 [See also: [Mapping Additional
 Relations](#mapping_additional_relations)]

 [UIA] [Property: `DescribedBy`: points to accessible nodes matching IDREFs, if the
 referenced objects are in the accessibility tree]

 [ATK]/[AT-SPI] referenced objects are in the accessibility tree]\
 [Reverse Relation: `RELATION_DETAILS_FOR` points to element]\
 [See also: [Mapping Additional
 Relations](#mapping_additional_relations)]

 [AX API] [Property: `AXDetailsElements`: pointers to accessible nodes matching
 IDREFs]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.27 `aria-disabled`=`true`

---------------------------------------------------------- ---------------------------------------------------------------------------------------
 ARIA Specification [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)=`true`

 [MSAA] + [State: `STATE_SYSTEM_UNAVAILABLE`]\
 IAccessible2 [State: `STATE_SYSTEM_UNAVAILABLE` on all descendants with
 `STATE_SYSTEM_FOCUSABLE`]

 [UIA] [Property: `IsEnabled`: `false`]

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] [Property: `AXEnabled`: `NO`]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.28 `aria-disabled`=`false`

-------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------
 ARIA Specification [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)=`false`
 [MSAA] + IAccessible2 [State: `STATE_SYSTEM_UNAVAILABLE` not exposed]
 [UIA] [Property: `IsEnabled`: `true`]
 [ATK]/[AT-SPI] [State: `STATE_ENABLED`]
 [AX API] [Property: `AXEnabled`: `YES`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.29 `aria-dropeffect`=`copy`, `move`, `link`, `execute`, or `popup` (deprecated)

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect)=`copy`, `move`, `link`, `execute`, or `popup`
 [MSAA] + IAccessible2 [Object Attribute: `dropeffect:<value>`]
 [UIA] [Property: `AriaProperties.dropeffect`: `<value>`]
 [ATK]/[AT-SPI] [Object Attribute: `dropeffect:<value>`]
 [AX API] `array AXDropEffects`
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.30 `aria-dropeffect`=`none` (deprecated)

---------------------------------------------------------- ----------------------------------------------------------------------------------------------
 ARIA Specification [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect)=`none`

 [MSAA] + [Object Attribute: `dropeffect:none` if there are no other valid tokens]\
 IAccessible2 [[Not mapped\*](#not_mapped) if not specified by the author]

 [UIA] [[Not mapped\*](#not_mapped)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [[Not mapped\*](#not_mapped) if not specified by the author]

 [AX API] [[Not mapped\*](#not_mapped)]

 Android TBD
 ---------------------------------------------------------- ----------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.31 `aria-errormessage`

---------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage)

 [MSAA] + [Relation: `IA2_RELATION_ERROR` points to accessible nodes matching IDREFs, if the
 IAccessible2 referenced objects are in the accessibility tree]\
 [Reverse Relation: `IA2_RELATION_ERROR_FOR` points to element]\
 [See also: [Mapping Additional Relations](#mapping_additional_relations)]

 [UIA] [Property: `ControllerFor`: pointer to the target accessible object]

 [ATK]/[AT-SPI] referenced objects are in the accessibility tree]\
 [Reverse Relation: `RELATION_ERROR_FOR` points to element]\
 [See also: [Mapping Additional Relations](#mapping_additional_relations)]

 [AX API] [Property: `AXErrorMessageElements`: pointers to accessible nodes matching
 IDREFs]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.32 `aria-expanded`=`true`

---------------------------------------------------------- ---------------------------------------------------------------------------------------
 ARIA Specification [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)=`true`

 [MSAA] + [State: `STATE_SYSTEM_EXPANDED`]
 IAccessible2

 [UIA] [Property: `ExpandCollapse.ExpandCollapseState`: `Expanded`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_EXPANDED`]

 [AX API] [Property: `AXExpanded`: `YES`]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.33 `aria-expanded`=`false`

---------------------------------------------------------- ----------------------------------------------------------------------------------------
 ARIA Specification [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)=`false`

 [MSAA] + [State: `STATE_SYSTEM_COLLAPSED`]
 IAccessible2

 [UIA] [Property: `ExpandCollapse.ExpandCollapseState`: `Collapsed`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_EXPANDED` not exposed]

 [AX API] [Property: `AXExpanded`: `NO`]

 Android TBD
 ---------------------------------------------------------- ----------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.34 `aria-expanded` is undefined

-------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------
 ARIA Specification [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) is undefined
 [MSAA] + IAccessible2 [[Not mapped](#not_mapped)]
 [UIA] [[Not mapped](#not_mapped)]
 [ATK]/[AT-SPI] [[Not mapped](#not_mapped)]
 [AX API] [[Not mapped](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.35 `aria-flowto`

---------------------------------------------------------- -------------------------------------------------------------------------------
 ARIA Specification [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto)

 [MSAA] + [Relation: `IA2_RELATION_FLOW_TO` points to accessible nodes matching
 IAccessible2 IDREFs]\
 [Reverse Relation: `IA2_RELATION_FLOW_FROM` points to element]\
 [See also: [Mapping Additional
 Relations](#mapping_additional_relations)]

 [UIA] [Property: `FlowsTo`: pointers to accessible nodes matching IDREFs]

 [ATK]/[AT-SPI] IDREFs]\
 [Reverse Relation: `RELATION_FLOWS_FROM` points to element]\
 [See also: [Mapping Additional
 Relations](#mapping_additional_relations)]

 [AX API] [Property: `AXLinkedUIElements`: pointers to accessible nodes matching
 IDREFs]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.36 `aria-grabbed`=`true`

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------
 ARIA Specification [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed)=`true`
 [MSAA] + IAccessible2 [Object Attribute: `grabbed:true`]
 [UIA] [Property: `AriaProperties.grabbed`: `true`]
 [ATK]/[AT-SPI] [Object Attribute: `grabbed:true`]
 [AX API] [Property: `AXGrabbed`: `YES`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.37 `aria-grabbed`=`false`

-------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------
 ARIA Specification [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed)=`false`
 [MSAA] + IAccessible2 [Object Attribute: `grabbed:false`]
 [UIA] [Property: `AriaProperties.grabbed`: `false`]
 [ATK]/[AT-SPI] [Object Attribute: `grabbed:false`]
 [AX API] [Property: `AXGrabbed`: `NO`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.38 `aria-grabbed` is undefined

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) is undefined
 [MSAA] + IAccessible2 [[Not mapped](#not_mapped)]
 [UIA] [[Not mapped](#not_mapped)]
 [ATK]/[AT-SPI] [[Not mapped](#not_mapped)]
 [AX API] [[Not mapped](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.39 `aria-haspopup`=`true`

---------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)=`true`

 [MSAA] + [State: `STATE_SYSTEM_HASPOPUP`]\
 IAccessible2 [Object Attribute: `haspopup:menu`]

 [UIA] [Control Pattern: `ExpandCollapse`] [See also:
 [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `haspopup:menu`]

 [AX API] [Property: `AXPopupValue:menu`]\
 [Action: `AXShowMenu`]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.40 `aria-haspopup`=`false`

---------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)=`false`

 [MSAA] + [State: `STATE_SYSTEM_HASPOPUP` not exposed]\
 IAccessible2 [Object Attribute: `haspopup:false`]

 [UIA] [[Not mapped\*](#not_mapped)]

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] [[Not mapped\*](#not_mapped)]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.41 `aria-haspopup`=`dialog`

---------------------------------------------------------- --------------------------------------------------------------------------------------------
 ARIA Specification [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)=`dialog`

 [MSAA] + [State: `STATE_SYSTEM_HASPOPUP`]\
 IAccessible2 [Object Attribute: `haspopup:dialog`]

 [UIA] [Control Pattern: `ExpandCollapse`]\
 [See also:
 [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `haspopup:dialog`]

 [AX API] [Property: `AXPopupValue:dialog`]\
 [Action: `AXShowMenu`]

 Android TBD
 ---------------------------------------------------------- --------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.42 `aria-haspopup`=`grid`

---------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)=`grid`

 [MSAA] + [State: `STATE_SYSTEM_HASPOPUP`]\
 IAccessible2 [Object Attribute: `haspopup:grid`]

 [UIA] [Control Pattern: `ExpandCollapse`]\
 [See also:
 [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `haspopup:grid`]

 [AX API] [Property: `AXPopupValue:grid`]\
 [Action: `AXShowMenu`]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.43 `aria-haspopup`=`listbox`

---------------------------------------------------------- ---------------------------------------------------------------------------------------------
 ARIA Specification [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)=`listbox`

 [MSAA] + [State: `STATE_SYSTEM_HASPOPUP`]\
 IAccessible2 [Object Attribute: `haspopup:listbox`]

 [UIA] [Control Pattern: `ExpandCollapse`]\
 [See also:
 [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `haspopup:listbox`]

 [AX API] [Property: `AXPopupValue:listbox`]\
 [Action: `AXShowMenu`]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.44 `aria-haspopup`=`menu`

---------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)=`menu`

 [MSAA] + [State: `STATE_SYSTEM_HASPOPUP`]\
 IAccessible2 [Object Attribute: `haspopup:menu`]

 [UIA] [Control Pattern: `ExpandCollapse`]\
 [See also:
 [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `haspopup:menu`]

 [AX API] [Property: `AXPopupValue:menu`]\
 [Action: `AXShowMenu`]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.45 `aria-haspopup`=`tree`

---------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)=`tree`

 [MSAA] + [State: `STATE_SYSTEM_HASPOPUP`]\
 IAccessible2 [Object Attribute: `haspopup:tree`]

 [UIA] [Control Pattern: `ExpandCollapse`]\
 [See also:
 [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `haspopup:tree`]

 [AX API] [Property: `AXPopupValue:tree`]\
 [Action: `AXShowMenu`]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.46 `aria-hidden`=`true` on unfocused element

---------------------------------------------------------- -----------------------------------------------------------------------------------
 ARIA Specification [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden)=`true`
 on unfocused element

 [MSAA] + [Element *SHOULD NOT* be exposed]\
 IAccessible2 [See also: [Including Elements in the Accessibility Tree in the [WAI-ARIA]
 specification](https://w3c.github.io/aria/#tree_inclusion)]

 [UIA] [Element *SHOULD NOT* be exposed]\
 [See also: [Including Elements in the Accessibility Tree in the [WAI-ARIA]
 specification](https://w3c.github.io/aria/#tree_inclusion)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [Including Elements in the Accessibility Tree in the [WAI-ARIA]
 specification](https://w3c.github.io/aria/#tree_inclusion)]

 [AX API] [Element *SHOULD NOT* be exposed]\
 [See also: [Including Elements in the Accessibility Tree in the [WAI-ARIA]
 specification](https://w3c.github.io/aria/#tree_inclusion)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.47 `aria-hidden`=`true` when element is focused or fires an accessibility event

---------------------------------------------------------- -----------------------------------------------------------------------------------
 ARIA Specification [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden)=`true`
 when element is focused or fires an accessibility event

 [MSAA] + [Object Attribute: `hidden:true`]\
 IAccessible2 [See also: [Including Elements in the Accessibility Tree in the [WAI-ARIA]
 specification](https://w3c.github.io/aria/#tree_inclusion)]

 [UIA] [Property: `AriaProperties.hidden`: `true`]\
 [See also: [Including Elements in the Accessibility Tree in the [WAI-ARIA]
 specification](https://w3c.github.io/aria/#tree_inclusion)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [Including Elements in the Accessibility Tree in the [WAI-ARIA]
 specification](https://w3c.github.io/aria/#tree_inclusion)]

 [AX API] [[Not mapped](#not_mapped)]\
 [See also: [Including Elements in the Accessibility Tree in the [WAI-ARIA]
 specification](https://w3c.github.io/aria/#tree_inclusion)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.48 `aria-hidden`=`false`

-------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------
 ARIA Specification [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden)=`false`
 [MSAA] + IAccessible2 [[Not mapped](#not_mapped)]
 [UIA] [[Not mapped](#not_mapped)]
 [ATK]/[AT-SPI] [[Not mapped](#not_mapped)]
 [AX API] [[Not mapped](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.49 `aria-invalid`=`true`

---------------------------------------------------------- -------------------------------------------------------------------------------------
 ARIA Specification [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)=`true`

 [MSAA] + [State: `IA2_STATE_INVALID_ENTRY`]\
 IAccessible2 [Text Attribute: `invalid:true`]

 [UIA] [Property: `IsDataValidForForm`: `false`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Text Attribute: `invalid:true`]

 [AX API] [Property: `AXInvalid`: `true`]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.50 `aria-invalid`=`false`

-------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------
 ARIA Specification [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)=`false`
 [MSAA] + IAccessible2 [State: `IA2_STATE_INVALID_ENTRY` not exposed]
 [UIA] [Property: `IsDataValidForForm`: `true`]
 [ATK]/[AT-SPI] [State: `STATE_INVALID_ENTRY` not exposed]
 [AX API] [Property: `AXInvalid`: `false`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.51 `aria-invalid`=`spelling` or `grammar`

---------------------------------------------------------- -----------------------------------------------------------------------------------------
 ARIA Specification [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)=`spelling`
 or `grammar`

 [MSAA] + [State: `IA2_STATE_INVALID_ENTRY`]\
 IAccessible2 [Text Attribute: `invalid:<value>`]

 [UIA] [Property: `IsDataValidForForm`: `<value>`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Text Attribute: `invalid:<value>`]

 [AX API] [Property: `AXInvalid`: `<value>`]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.52 `aria-invalid` with unrecognized value

---------------------------------------------------------- ------------------------------------------------------------------------------
 ARIA Specification [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
 with unrecognized value

 [MSAA] + [State: `IA2_STATE_INVALID_ENTRY`]\
 IAccessible2 [Text Attribute: `invalid:true`]

 [UIA] [Property: `IsDataValidForForm`: `false`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Text Attribute: `invalid:true`]

 [AX API] [Property: `AXInvalid`: `true`]

 Android TBD
 ---------------------------------------------------------- ------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.53 `aria-keyshortcuts`

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts)
 [MSAA] + IAccessible2 [Property: `accKeyboardShortcut`: `<value>`]
 [UIA] [Property: `AcceleratorKey`: `<value>`]
 [ATK]/[AT-SPI] [Object Attribute: `keyshortcuts:<value>`]
 [AX API] [Property: `AXKeyShortcutsValue`: `<value>`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.54 `aria-label`

---------------------------------------------------------- -----------------------------------------------------------------------------
 ARIA Specification [`aria-label`](https://w3c.github.io/aria/#aria-label)

 [MSAA] + [Property: `accName`: `<value>`]\
 IAccessible2 [See also: [Name Computation](#mapping_additional_nd)]

 [UIA] [Property: `Name`: `<value>`]\
 [See also: [Name Computation](#mapping_additional_nd)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [Name Computation](#mapping_additional_nd)]

 [AX API] [Property: `AXTitle`: `<value>`]\
 [See also: [Name Computation](#mapping_additional_nd)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.55 `aria-labelledby`

---------------------------------------------------------- ---------------------------------------------------------------------------------------
 ARIA Specification [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)

 [MSAA] + [Property: `accName`: `<value>`]\
 IAccessible2 [Relation: `IA2_RELATION_LABELLED_BY` points to accessible nodes matching IDREFs, if
 the referenced objects are in the accessibility tree]\
 [Reverse Relation: `IA2_RELATION_LABEL_FOR` points to element]\
 [See also: [Name Computation](#mapping_additional_nd) and [Mapping Additional
 Relations](#mapping_additional_relations)]

 [UIA] [Property: `Name`: `<value>`]\
 [Property: `LabeledBy`: points to accessible nodes matching IDREFs, if the referenced
 objects are in the accessibility tree]\
 [See also: [Name Computation](#mapping_additional_nd)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Relation: `RELATION_LABELLED_BY` points to accessible nodes matching IDREFs, if the
 referenced objects are in the accessibility tree]\
 [Reverse Relation: `RELATION_LABEL_FOR` points to element]\
 [See also: [Name Computation](#mapping_additional_nd) and [Mapping Additional
 Relations](#mapping_additional_relations)]

 [AX API] [Property: `AXTitle`: `<value>`]\
 [Property: `AXTitleUIElement` points to accessible node matching IDREF, if there is a
 single referenced element that is in the accessibility tree]\
 [See also: [Name Computation](#mapping_additional_nd)]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.56 `aria-level` on non-`heading`

---------------------------------------------------------- -----------------------------------------------------------------------------
 ARIA Specification [`aria-level`](https://w3c.github.io/aria/#aria-level)
 on non-`heading`

 [MSAA] + [Object Attribute: `level:<value>`]\
 IAccessible2 [Method: `IAccessible2::groupPosition()`: `groupLevel=<value>` on roles that
 support `aria-posinset` and `aria-setsize`]\
 [See also: [`groupPosition()`](#mapping_group_position)]

 [UIA] [Property: `AriaProperties.level`: `<value>`]

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] [Property: `AXDisclosureLevel`: `<value>` (zero-based), when used on an
 outline row (like a
 [`treeitem`](https://w3c.github.io/aria/#treeitem) or
 [`group`](https://w3c.github.io/aria/#group))]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.57 `aria-level` on `heading`

---------------------------------------------------------- -----------------------------------------------------------------------------
 ARIA Specification [`aria-level`](https://w3c.github.io/aria/#aria-level)
 on `heading`

 [MSAA] + [Object Attribute: `level:<value>`]
 IAccessible2

 [UIA] [Property: `AriaProperties.level`: `<value>`]\
 [Property: `StyleId_Heading`: `<value>`]

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] [Property: `AXValue`: `<value>`]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.58 `aria-live`=`assertive`

---------------------------------------------------------- ---------------------------------------------------------------------------------------
 ARIA Specification [`aria-live`](https://w3c.github.io/aria/#aria-live)=`assertive`

 [MSAA] + [Object Attribute: `live:assertive`]\
 IAccessible2 [Object Attribute: `container-live:assertive`]\
 [Object Attribute: `container-live:assertive` on all descendants]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [UIA] [Property: `LiveSetting`: `"assertive"`]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `container-live:assertive`]\
 [Object Attribute: `container-live:assertive` on all descendants]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [AX API] [Property: `AXARIALive`: `"assertive"`]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.59 `aria-live`=`polite`

---------------------------------------------------------- ------------------------------------------------------------------------------------
 ARIA Specification [`aria-live`](https://w3c.github.io/aria/#aria-live)=`polite`

 [MSAA] + [Object Attribute: `live:polite`]\
 IAccessible2 [Object Attribute: `container-live:polite`]\
 [Object Attribute: `container-live:polite` on all descendants]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [UIA] [Property: `LiveSetting`: `"polite"`]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `container-live:polite`]\
 [Object Attribute: `container-live:polite` on all descendants]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [AX API] [Property: `AXARIALive`: `"polite"`]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 Android TBD
 ---------------------------------------------------------- ------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.60 `aria-live`=`off`

---------------------------------------------------------- ---------------------------------------------------------------------------------
 ARIA Specification [`aria-live`](https://w3c.github.io/aria/#aria-live)=`off`

 [MSAA] + [Object Attribute: `live:off`]\
 IAccessible2 [Object Attribute: `container-live:off`]\
 [Object Attribute: `container-live:off` on all descendants]

 [UIA] [Property: `LiveSetting`: `"off"`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `container-live:off`]\
 [Object Attribute: `container-live:off` on all descendants]\

 [AX API] [Property: `AXARIALive`: `"off"`]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.61 `aria-modal`=`true`

---------------------------------------------------------- ------------------------------------------------------------------------------------
 ARIA Specification [`aria-modal`](https://w3c.github.io/aria/#aria-modal)=`true`

 [MSAA] + [State: `IA2_STATE_MODAL`]
 IAccessible2

 [UIA] [Property: `Window.IsModal`: `true`]\

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] Prune the accessibility tree such that the background content is no longer exposed.
 No specific property is set on the [accessible
 object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) that corresponds to the
 [element](https://dom.spec.whatwg.org/#concept-element) with `aria-modal="true"`. Only the tree whose root is that modal
 accessible object is exposed.

 Android TBD
 ---------------------------------------------------------- ------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.62 `aria-modal`=`false`

---------------------------------------------------------- -------------------------------------------------------------------------------------
 ARIA Specification [`aria-modal`](https://w3c.github.io/aria/#aria-modal)=`false`

 [MSAA] + [State: `IA2_STATE_MODAL` not exposed]
 IAccessible2

 [UIA] [Property: `Window.IsModal`: `false`]\

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] Grow the accessibility tree such that the background content is exposed. No specific
 property is set on the [accessible
 object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) that corresponds to the
 [element](https://dom.spec.whatwg.org/#concept-element) with `aria-modal="false"`.

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.63 `aria-multiline`=`true`

---------------------------------------------------------- --------------------------------------------------------------------------------------------
 ARIA Specification [`aria-multiline`](https://w3c.github.io/aria/#aria-multiline)=`true`

 [MSAA] + [State: `IA2_STATE_MULTI_LINE`]\
 IAccessible2 [State: `IA2_STATE_SINGLE_LINE` not exposed]

 [UIA] [Property: `AriaProperties.multiline`: `true`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_SINGLE_LINE` not exposed]

 [AX API] [[Not mapped](#not_mapped)]\
 [See also: [`textbox`](#role-map-textbox) in the Role Mapping Tables]

 Android TBD
 ---------------------------------------------------------- --------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.64 `aria-multiline`=`false`

---------------------------------------------------------- ---------------------------------------------------------------------------------------------
 ARIA Specification [`aria-multiline`](https://w3c.github.io/aria/#aria-multiline)=`false`

 [MSAA] + [State: `IA2_STATE_SINGLE_LINE`]\
 IAccessible2 [State: `IA2_STATE_MULTI_LINE` not exposed]

 [UIA] [[Not mapped](#not_mapped)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_MULTI_LINE` not exposed]

 [AX API] [[Not mapped](#not_mapped)]\
 [See also: [`textbox`](#role-map-textbox) in the Role Mapping Tables]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.65 `aria-multiselectable`=`true`

---------------------------------------------------------- --------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable)=`true`

 [MSAA] + [State: `STATE_SYSTEM_MULTISELECTABLE`]\
 IAccessible2 [State: `STATE_SYSTEM_EXTSELECTABLE`]\
 [See also: [Selection](#mapping_events_selection) for details on accessibility events]

 [UIA] [Property: `Selection.CanSelectMultiple`: `true`]\
 [See also: [Selection](#mapping_events_selection) for details on accessibility events]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [Selection](#mapping_events_selection) for details on accessibility events]

 [AX API] [Property: `AXIsMultiSelectable`: `YES`]\
 [See also: [Selection](#mapping_events_selection) for details on accessibility events]

 Android TBD
 ---------------------------------------------------------- --------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.66 `aria-multiselectable`=`false`

---------------------------------------------------------- ---------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable)=`false`

 [MSAA] + [State: `STATE_SYSTEM_MULTISELECTABLE` not exposed]\
 IAccessible2 [State: `STATE_SYSTEM_EXTSELECTABLE` not exposed]\
 [See also: [Selection](#mapping_events_selection) for details on accessibility events]

 [UIA] [[Not mapped\*](#not_mapped)]

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] [[Not mapped\*](#not_mapped)]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.67 `aria-orientation`=`horizontal`

---------------------------------------------------------- ------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)=`horizontal`

 [MSAA] + [State: `IA2_STATE_HORIZONTAL`]\
 IAccessible2 [State: `IA2_STATE_VERTICAL` not exposed]

 [UIA] [Property: `Orientation`: `horizontal`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_VERTICAL` not exposed]

 [AX API] [Property: `AXOrientation`: `AXHorizontalOrientation`]

 Android TBD
 ---------------------------------------------------------- ------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.68 `aria-orientation`=`vertical`

---------------------------------------------------------- ----------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)=`vertical`

 [MSAA] + [State: `IA2_STATE_VERTICAL`]\
 IAccessible2 [State: `IA2_STATE_HORIZONTAL` not exposed]

 [UIA] [Property: `Orientation`: `vertical`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_HORIZONTAL` not exposed]

 [AX API] [Property: `AXOrientation`: `AXVerticalOrientation`]

 Android TBD
 ---------------------------------------------------------- ----------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.69 `aria-orientation` is undefined

---------------------------------------------------------- -----------------------------------------------------------------------------------------
 ARIA Specification [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
 is undefined

 [MSAA] + [[Not mapped\*](#not_mapped)]
 IAccessible2

 [UIA] [[Not mapped\*](#not_mapped)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_HORIZONTAL` not exposed]

 [AX API] [Property: `AXOrientation`: `AXUnknownOrientation`]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.70 `aria-owns`

+----------------------------------------------------------+---------------------------------------------------------------------------+
| ARIA Specification | [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
+----------------------------------------------------------+---------------------------------------------------------------------------+
| [MSAA] + | User agents *MAY* expose the elements that are referenced by this |
| IAccessible2 | property as children of the current element. In which case, if multiple |
| | [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | relationships are found, use only the first one. If the accessibility |
| | tree is not modified, expose as: |
| | |
| | [Relation: `IA2_RELATION_NODE_PARENT_OF` points to accessible nodes |
| | matching IDREFs, if the referenced objects are in the accessibility |
| | tree]\ |
| | [Reverse Relation: `IA2_RELATION_NODE_CHILD_OF` points to |
| | element]\ |
| | [See also: [Mapping Additional |
| | Relations](#mapping_additional_relations)] |
+----------------------------------------------------------+---------------------------------------------------------------------------+
| [UIA] | Expose the elements that are referenced by this property as children of |
| | the current element. If multiple |
| | [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | relationships are found, use only the first one. |
+----------------------------------------------------------+---------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | relationships are found, use only the first one. If the accessibility |
| | tree is not modified, expose as: |
| | |
| | [Relation: `RELATION_NODE_PARENT_OF` points to accessible nodes matching |
| | IDREFs, if the referenced objects are in the accessibility |
| | tree]\ |
| | [Reverse Relation: `RELATION_NODE_CHILD_OF` points to |
| | element]\ |
| | [See also: [Mapping Additional |
| | Relations](#mapping_additional_relations)] |
+----------------------------------------------------------+---------------------------------------------------------------------------+
| [AX API] | [Property: `AXOwns`: pointers to accessible nodes matching |
| | IDREFs] |
+----------------------------------------------------------+---------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+---------------------------------------------------------------------------+

::: header-wrapper
##### 3.5.2.71 `aria-placeholder`

-------------------------------------------------------------------------------------------------------------------- -----------------------------------------------------------------------------------------
 ARIA Specification [`aria-placeholder`](https://w3c.github.io/aria/#aria-placeholder)
 [MSAA] + IAccessible2 [Object Attribute: `placeholder-text:<value>`]
 [UIA] [Property: `HelpText`: `<value>`]
 [ATK]/[AT-SPI] [Object Attribute: `placeholder-text:<value>`]
 [AX API] [Property: `AXPlaceholderValue`: `<value>`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -----------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.72 `aria-posinset`

---------------------------------------------------------- -----------------------------------------------------------------------------------
 ARIA Specification [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)

 [MSAA] + [Object Attribute: `posinset:<value>`]\
 IAccessible2 [See also: [Group Position](#mapping_additional_position)]

 [UIA] [Property: `AriaProperties.posinset`: `<value>`]\
 [See also: [Group Position](#mapping_additional_position)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [Group Position](#mapping_additional_position)]

 [AX API] [Property: `AXARIAPosInSet`: `<value>`]\
 [See also: [Group Position](#mapping_additional_position)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.73 `aria-pressed`=`true`

---------------------------------------------------------- -------------------------------------------------------------------------------------
 ARIA Specification [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed)=`true`

 [MSAA] + [State: `STATE_SYSTEM_PRESSED`]\
 IAccessible2 [See also: [`button` with defined value for
 `aria-pressed`](#role-map-button-pressed)]

 [UIA] [Property: `Toggle.ToggleState`: `On (1)`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [`button` with defined value for
 `aria-pressed`](#role-map-button-pressed)]

 [AX API] [Property: `AXValue`: `1`]\
 [See also: [`button` with defined value for
 `aria-pressed`](#role-map-button-pressed)]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.74 `aria-pressed`=`mixed`

---------------------------------------------------------- --------------------------------------------------------------------------------------
 ARIA Specification [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed)=`mixed`

 [MSAA] + [State: `STATE_SYSTEM_MIXED`]\
 IAccessible2 [See also: [`button` with defined value for
 `aria-pressed`](#role-map-button-pressed)]

 [UIA] [Property: `Toggle.ToggleState`: `Indeterminate (2)`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [`button` with defined value for
 `aria-pressed`](#role-map-button-pressed)]

 [AX API] [Property: `AXValue`: `2`]\
 [See also: [`button` with defined value for
 `aria-pressed`](#role-map-button-pressed)]

 Android TBD
 ---------------------------------------------------------- --------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.75 `aria-pressed`=`false`

---------------------------------------------------------- --------------------------------------------------------------------------------------
 ARIA Specification [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed)=`false`

 [MSAA] + [State: `STATE_SYSTEM_PRESSED` not exposed]\
 IAccessible2 [See also: [`button` with defined value for
 `aria-pressed`](#role-map-button-pressed)]

 [UIA] [Property: `Toggle.ToggleState`: `Off (3)`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [`button` with defined value for
 `aria-pressed`](#role-map-button-pressed)]

 [AX API] [Property: `AXValue`: `0`]\
 [See also: [`button` with defined value for
 `aria-pressed`](#role-map-button-pressed)]

 Android TBD
 ---------------------------------------------------------- --------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.76 `aria-pressed` is undefined

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed) is undefined
 [MSAA] + IAccessible2 [[Not mapped\*](#not_mapped)]
 [UIA] [[Not mapped\*](#not_mapped)]
 [ATK]/[AT-SPI] [[Not mapped\*](#not_mapped)]
 [AX API] [[Not mapped\*](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.77 `aria-readonly`=`true`

---------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)=`true`

 [MSAA] + [State: `STATE_SYSTEM_READONLY`]
 IAccessible2

 [UIA] [Property: `Value.IsReadOnly`: `true`, if the element implements
 [`IValueProvider`](https://learn.microsoft.com/en-us/dotnet/api/system.windows.automation.provider.ivalueprovider).]\
 [Property: `RangeValue.IsReadOnly`: `true`, if the element implements
 [`IRangeValueProvider`](https://learn.microsoft.com/en-us/dotnet/api/system.windows.automation.provider.irangevalueprovider).]\
 [Property: `AriaProperties.readonly`: `true`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_EDITABLE` not exposed on text input roles]\
 [State: `STATE_CHECKABLE` not exposed on roles supporting
 [`aria-checked`](https://w3c.github.io/aria/#aria-checked)]\
 [State: `STATE_CHECKABLE` not exposed on [radio](https://w3c.github.io/aria/#radio) descendants when used on a
 `radiogroup`]

 [AX API] [Method: `AXUIElementIsAttributeSettable(AXValue)`: `NO`]

 Android TBD
 ---------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.78 `aria-readonly`=`false`

---------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)=`false`

 [MSAA] + [State: `STATE_SYSTEM_READONLY` not exposed]\
 IAccessible2 [State: `IA2_STATE_EDITABLE`]

 [UIA] [Property: `Value.IsReadOnly`: `false`, if the element implements
 [`IValueProvider`](https://learn.microsoft.com/en-us/dotnet/api/system.windows.automation.provider.ivalueprovider).]\
 [Property: `RangeValue.IsReadOnly`: `false`, if the element implements
 [`IRangeValueProvider`](https://learn.microsoft.com/en-us/dotnet/api/system.windows.automation.provider.irangevalueprovider).]\
 [Property: `AriaProperties.readonly`: `false`]

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] [Method: `AXUIElementIsAttributeSettable(AXValue)`: `YES`]

 Android TBD
 ---------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.79 `aria-readonly` is unspecified on `gridcell`

-------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) is unspecified on `gridcell`
 [MSAA] + IAccessible2 The `gridcell` *MUST* inherit any author-provided value for `aria-readonly` from the containing `grid` or `treegrid`. Expose the inherited value on the `gridcell` as described for [`aria-readonly="true"`](#ariaReadonlyTrue) and [`aria-readonly="false"`](#ariaReadonlyFalse).
 [UIA] The `gridcell` *MUST* inherit any author-provided value for `aria-readonly` from the containing `grid` or `treegrid`. Expose the inherited value on the `gridcell` as described for [`aria-readonly="true"`](#ariaReadonlyTrue) and [`aria-readonly="false"`](#ariaReadonlyFalse).
 [ATK]/[AT-SPI] The `gridcell` *MUST* inherit any author-provided value for `aria-readonly` from the containing `grid` or `treegrid`. Expose the inherited value on the `gridcell` as described for [`aria-readonly="true"`](#ariaReadonlyTrue) and [`aria-readonly="false"`](#ariaReadonlyFalse).
 [AX API] The `gridcell` *MUST* inherit any author-provided value for `aria-readonly` from the containing `grid` or `treegrid`. Expose the inherited value on the `gridcell` as described for [`aria-readonly="true"`](#ariaReadonlyTrue) and [`aria-readonly="false"`](#ariaReadonlyFalse).
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.80 `aria-relevant`

---------------------------------------------------------- -----------------------------------------------------------------------------------
 ARIA Specification [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)

 [MSAA] + [Object Attribute: `relevant:<value>`]\
 IAccessible2 [Object Attribute: `container-relevant:<value>`]\
 [Object Attribute: `container-relevant:<value>` on all descendants]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [UIA] [Property: `AriaProperties.relevant`: `<value>`]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [Object Attribute: `container-relevant:<value>`]\
 [Object Attribute: `container-relevant:<value>` on all descendants]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 [AX API] [Property: `AXARIARelevant`: `<value>`]\
 [See also: [Changes to document content or node
 visibility](#mapping_events_visibility)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.81 `aria-required`=`true`

-------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------
 ARIA Specification [`aria-required`](https://w3c.github.io/aria/#aria-required)=`true`
 [MSAA] + IAccessible2 [State: `IA2_STATE_REQUIRED`]
 [UIA] [Property: `IsRequiredForForm`: `true`]
 [ATK]/[AT-SPI] [State: `STATE_REQUIRED`]
 [AX API] [Property: `AXRequired`: `YES`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.82 `aria-required`=`false`

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-required`](https://w3c.github.io/aria/#aria-required)=`false`
 [MSAA] + IAccessible2 [[Not mapped\*](#not_mapped)]
 [UIA] [[Not mapped\*](#not_mapped)]
 [ATK]/[AT-SPI] [[Not mapped\*](#not_mapped)]
 [AX API] [[Not mapped\*](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.83 `aria-roledescription`

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription)
 [MSAA] + IAccessible2 [Method: `localizedExtendedRole()`: `<value>`]
 [UIA] [Localized Control Type: `<value>`]
 [ATK]/[AT-SPI] [Object Attribute: `roledescription:<value>`]
 [AX API] [Property: `AXRoleDescription`: `<value>`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.84 `aria-roledescription` is undefined or the empty string

-------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) is undefined or the empty string
 [MSAA] + IAccessible2 [[Not mapped](#not_mapped)]
 [UIA] [Localized Control Type is defined as that specified for the role of the element: based on the explicit role if the role attribute is provided; otherwise, based on the implicit role for the host language.]
 [ATK]/[AT-SPI] [[Not mapped](#not_mapped)]
 [AX API] [AXRoleDescription is defined as that specified for the role of the element: based on the explicit role if the role attribute is provided; otherwise, based on the implicit role for the host language.]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.85 `aria-rowcount`

---------------------------------------------------------- -----------------------------------------------------------------------------------
 ARIA Specification [`aria-rowcount`](https://w3c.github.io/aria/#aria-rowcount)

 [MSAA] + [Object Attribute: `rowcount:<value>`]\
 IAccessible2 [Method: `IAccessible2::groupPosition()`: `similarItemsInGroup=<value>` on
 rows]

 [UIA] [Property: `Grid.RowCount`: `<value>`]

 [ATK]/[AT-SPI] value.]\
 [Method: `atk_table_get_n_rows()` should return the actual number of
 rows.]

 [AX API] [Property: `AXARIARowCount`: `<value>`]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.86 `aria-rowindex`

---------------------------------------------------------- -----------------------------------------------------------------------------------
 ARIA Specification [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)

 [MSAA] + [Object Attribute: `rowindex:<value>`]\
 IAccessible2 [Method: `IAccessible2::groupPosition()`: `positionInGroup=<value>` on
 rows]

 [UIA] [Property: `GridItem.Row`: `<value>` (zero-based)]

 [ATK]/[AT-SPI] value.]\
 [Method: `atk_table_cell_get_position()` should return the actual (zero-based) row
 index.]

 [AX API] [Property: `AXARIARowIndex`: `<value>`]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.87 `aria-rowindextext`

-------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext)
 [MSAA] + IAccessible2 [Object Attribute: `rowindextext:<value>`]
 [UIA] [Property: `AriaProperties.rowindextext`: `<value>`]
 [ATK]/[AT-SPI] [Object Attribute: `rowindextext:<value>`]
 [AX API] [Property: `AXRowIndexDescription`: `<value>`]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.88 `aria-rowspan`

---------------------------------------------------------- ---------------------------------------------------------------------------------
 ARIA Specification [`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan)

 [MSAA] + [Object Attribute: `rowspan:<value>`]\
 IAccessible2 [Method: `IAccessibleTableCell::rowExtent()`: `column=<value>`]

 [UIA] [Property: `GridItem.RowSpan`: `<value>`]

 [ATK]/[AT-SPI] value.]\
 [Method: `atk_table_cell_get_row_column_span()` should return the actual row
 span.]

 [AX API] [Property: `AXRowIndexRange.length`: `<value>`]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.89 `aria-selected`=`true`

---------------------------------------------------------- ---------------------------------------------------------------------------------------
 ARIA Specification [`aria-selected`](https://w3c.github.io/aria/#aria-selected)=`true`

 [MSAA] + [State: `STATE_SYSTEM_SELECTABLE`]\
 IAccessible2 [State: `STATE_SYSTEM_SELECTED`]\
 [See also: [Selection](#mapping_events_selection) for details on accessibility
 events]

 [UIA] [Property: `SelectionItem.IsSelected`: `true`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_SELECTED`]\
 [See also: [Selection](#mapping_events_selection) for details on accessibility
 events]

 [AX API] [Property: `AXSelected`: `YES`]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.90 `aria-selected`=`false`

---------------------------------------------------------- ----------------------------------------------------------------------------------------
 ARIA Specification [`aria-selected`](https://w3c.github.io/aria/#aria-selected)=`false`

 [MSAA] + [State: `STATE_SYSTEM_SELECTABLE`]\
 IAccessible2 [State: `STATE_SYSTEM_SELECTED` not exposed]\
 [See also: [Selection](#mapping_events_selection) for details on accessibility
 events]

 [UIA] [Property: `SelectionItem.IsSelected`: `false`]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [State: `STATE_SELECTED` not exposed]\
 [See also: [Selection](#mapping_events_selection) for details on accessibility
 events]

 [AX API] [Property: `AXSelected`: `NO`]

 Android TBD
 ---------------------------------------------------------- ----------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.91 `aria-selected` is undefined

-------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------
 ARIA Specification [`aria-selected`](https://w3c.github.io/aria/#aria-selected) is undefined
 [MSAA] + IAccessible2 [[Not mapped](#not_mapped)]
 [UIA] [[Not mapped](#not_mapped)]
 [ATK]/[AT-SPI] [[Not mapped](#not_mapped)]
 [AX API] [[Not mapped](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.92 `aria-setsize`

+----------------------------------------------------------+---------------------------------------------------------------------------------+
| ARIA Specification | [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+----------------------------------------------------------+---------------------------------------------------------------------------------+
| [MSAA] + | [Object Attribute: `setsize:<value>`]\ |
| IAccessible2 | [See also: [Group Position](#mapping_additional_position)] |
+----------------------------------------------------------+---------------------------------------------------------------------------------+
| [UIA] | [Property: `AriaProperties.setsize`: `<value>`]\ |
| | [See also: [Group Position](#mapping_additional_position)] |
+----------------------------------------------------------+---------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | title="Document Object Model"}. |
| | |
| | [Object Attribute: `setsize:<value>`]\ |
| | [State: `STATE_INDETERMINATE` if the author-provided value is `-1`]\ |
| | [See also: [Group Position](#mapping_additional_position)] |
+----------------------------------------------------------+---------------------------------------------------------------------------------+
| [AX API] | [Property: `AXARIASetSize`: `<value>`]\ |
| | [See also: [Group Position](#mapping_additional_position)] |
+----------------------------------------------------------+---------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+---------------------------------------------------------------------------------+

::: header-wrapper
##### 3.5.2.93 `aria-sort`=`ascending`

---------------------------------------------------------- ---------------------------------------------------------------------------------------
 ARIA Specification [`aria-sort`](https://w3c.github.io/aria/#aria-sort)=`ascending`

 [MSAA] + [Object Attribute: `sort:ascending`]
 IAccessible2

 [UIA] [Property: `AriaProperties.sort`: `ascending`]\
 [Property: `ItemStatus`: `ascending` if the element maps to
 [`HeaderItem`](https://msdn.microsoft.com/en-us/library/windows/apps/ee671630.aspx)
 Control Type]

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] [Property: `AXSortDirection`: `AXAscendingSortDirection`]

 Android TBD
 ---------------------------------------------------------- ---------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.94 `aria-sort`=`descending`

---------------------------------------------------------- ----------------------------------------------------------------------------------------
 ARIA Specification [`aria-sort`](https://w3c.github.io/aria/#aria-sort)=`descending`

 [MSAA] + [Object Attribute: `sort:descending`]
 IAccessible2

 [UIA] [Property: `AriaProperties.sort`: `descending`]\
 [Property: `ItemStatus`: `descending` if the element maps to
 [`HeaderItem`](https://msdn.microsoft.com/en-us/library/windows/apps/ee671630.aspx)
 Control Type]

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] [Property: `AXSortDirection`: `AXDescendingSortDirection`]

 Android TBD
 ---------------------------------------------------------- ----------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.95 `aria-sort`=`other`

---------------------------------------------------------- -------------------------------------------------------------------------------------
 ARIA Specification [`aria-sort`](https://w3c.github.io/aria/#aria-sort)=`other`

 [MSAA] + [Object Attribute: `sort:other`]
 IAccessible2

 [UIA] [Property: `AriaProperties.sort`: `other`]\
 [Property: `ItemStatus`: `other` if the element maps to
 [`HeaderItem`](https://msdn.microsoft.com/en-us/library/windows/apps/ee671630.aspx)
 Control Type]

 [ATK]/[AT-SPI]
 title="Assistive Technology-Service Provider Interface"}

 [AX API] [Property: `AXSortDirection`: `AXUnknownSortDirection`]

 Android TBD
 ---------------------------------------------------------- -------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.96 `aria-sort`=`none`

-------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------
 ARIA Specification [`aria-sort`](https://w3c.github.io/aria/#aria-sort)=`none`
 [MSAA] + IAccessible2 [Object Attribute: `sort:none`, if the value is not unspecified]
 [UIA] [[Not mapped\*](#not_mapped)]
 [ATK]/[AT-SPI] [Object Attribute: `sort:none`, if the value is not unspecified]
 [AX API] [[Not mapped\*](#not_mapped)]
 Android TBD
 -------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.97 `aria-valuemax`

---------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)

 [MSAA] + [Method: `IAccessibleValue::maximumValue()`: `<value>`]\
 IAccessible2 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [UIA] [Property: `RangeValue.Maximum`: `<value>`]\
 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [AX API] [Property: `AXMaxValue`: `<value>`]\
 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.98 `aria-valuemin`

---------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)

 [MSAA] + [Method: `IAccessibleValue::minimumValue()`: `<value>`]\
 IAccessible2 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [UIA] [Property: `RangeValue.Minimum`: `<value>`]\
 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [AX API] [Property: `AXMinValue`: `<value>`]\
 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.99 `aria-valuenow`

---------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)

 [MSAA] + [Method: `IAccessibleValue::currentValue()`: `<value>`]\
 IAccessible2 [Method: `IAccessible::get_accValue()`: `<value>` if `aria-valuetext` is not defined]\
 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [UIA] [Property: `RangeValue.Value`: `<value>`]\
 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [AX API] [Property: `AXValue`: `<value>`]\
 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.5.2.100 `aria-valuetext`

---------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------
 ARIA Specification [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)

 [MSAA] + [Method: `IAccessible::get_accValue()`: `<value>`]\
 IAccessible2 [Object Attribute: `valuetext:<value>`]\
 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [UIA] [Property: `Value.Value`: `<value>`]\
 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [ATK]/[AT-SPI]\
 title="Assistive Technology-Service Provider Interface"} [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 [AX API] [Property: `AXValueDescription`: `<value>`]\
 [See also: [Handling Author Errors for States and
 Properties](https://w3c.github.io/aria/#document-handling_author-errors_states-properties)]

 Android TBD
 ---------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------

::: header-wrapper
### 3.6 Special Processing Requiring Additional Computation

::: header-wrapper
#### 3.6.1 Name and Description

For information on how to compute an [accessible
name](https://www.w3.org/TR/accname-1.2/#dfn-accessible-name) or [accessible
description](https://www.w3.org/TR/accname-1.2/#dfn-accessible-description), see the section titled [Accessible Name and Description
Computation](https://w3c.github.io/accname/#mapping_additional_nd_te)
of the [Accessible Name and Description
Computation](https://w3c.github.io/accname/) specification.

::: header-wrapper
#### 3.6.2 Relations

Often in a [GUI], there are
[relationships](https://www.w3.org/TR/wai-aria/#dfn-relationship) between the
[widgets](https://www.w3.org/TR/wai-aria/#dfn-widget) that can be exposed programmatically to
[assistive
technology](https://www.w3.org/TR/wai-aria/#assistive-technology). [WAI-ARIA] provides several
relationship
[properties](https://www.w3.org/TR/wai-aria/#dfn-property "Normative reference to non-normative term.") which are globally applicable
to any [element](https://dom.spec.whatwg.org/#concept-element):
[`aria-controls`](https://w3c.github.io/aria/#aria-controls),
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby),
[`aria-flowto`](https://w3c.github.io/aria/#aria-flowto),
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby),
[`aria-owns`](https://w3c.github.io/aria/#aria-owns),
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset),
and
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize).
Therefore, it is not important to check the
[role](https://www.w3.org/TR/wai-aria-1.3/#dfn-role) before
computing them. [User
agents](https://infra.spec.whatwg.org/#user-agent) can
simply map these relations to [accessibility [APIs]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api) as defined in the section titled [State
and Property Mapping](#mapping_state-property).

::: header-wrapper
##### 3.6.2.1 Reverse Relations

A reverse relation exists when an element\'s ID is referenced by a
[property](https://www.w3.org/TR/wai-aria/#dfn-property "Normative reference to non-normative term.") in another
[element](https://dom.spec.whatwg.org/#concept-element). For [APIs] that support reverse
relations, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* use the mapping defined in the [State and Property Mapping
Tables](#mapping_state-property_table) when an element\'s ID is
referenced by a relation property of another element and the referenced
element is in the accessibility tree. All [WAI-ARIA] references must point to
an element that is exposed as an accessible object in the accessibility
tree. When the referenced object is not exposed in the accessibility
tree (e.g. because it is
[hidden](https://www.w3.org/TR/wai-aria/#dfn-hidden "Normative reference to non-normative term.")), the reference is null.
`aria-labelledby` and `aria-describedby` have an additional feature,
which allows them to pull a flattened string from the referenced element
to populate the name or description fields of the accessibility
[API]. This feature is
described in the [Name and Description](#mapping_additional_nd) section.

Special case: If both
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
and [HTML] `<label for= … >`
are used, the user agent *MUST* use the [WAI-ARIA] relation and *MUST* ignore
the [HTML] label relation.

Note that
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
may reference structured or interactive information where users would
want to be able to navigate to different sections of content. User
agents *MAY* provide a way for the user to navigate to structured
information referenced by
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
and [assistive
technology](https://www.w3.org/TR/wai-aria/#assistive-technology) *SHOULD* provide such a method.

::: header-wrapper
##### 3.6.2.2 Implied reverse relations

In addition to the explicit relations defined by [WAI-ARIA]
[properties](https://www.w3.org/TR/wai-aria/#dfn-property "Normative reference to non-normative term."), reverse relations are
implied in two other situations:
[elements](https://dom.spec.whatwg.org/#concept-element) with `` where the ancestor
does not have an
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
property and descendants of elements with
[`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)
property.

In the case of
``,
when
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
is not used, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* do the following where reverse relations are supported by the
[API]:

- If the current
 [`treeitem`](https://w3c.github.io/aria/#treeitem)
 uses
 [`aria-level`](https://w3c.github.io/aria/#aria-level),
 then walk backwards in the tree until a
 [`treeitem`](https://w3c.github.io/aria/#treeitem) is
 found with a lower
 [`aria-level`](https://w3c.github.io/aria/#aria-level),
 then set `RELATION_NODE_CHILD_OF` to that element. If the top of the
 tree is reached, then set `RELATION_NODE_CHILD_OF` to the tree element
 itself.
- If the parent of the
 [`treeitem`](https://w3c.github.io/aria/#treeitem)
 has a [role](https://www.w3.org/TR/wai-aria-1.3/#dfn-role) of
 [`group`](https://w3c.github.io/aria/#group), then
 walk backwards from the
 [`group`](https://w3c.github.io/aria/#group) until an
 element with a role of
 [`treeitem`](https://w3c.github.io/aria/#treeitem) is
 found, then set `RELATION_NODE_CHILD_OF` to that element.

In the case of
[`aria-atomic`](https://w3c.github.io/aria/#aria-atomic),
where reverse relations are supported by the [API]:

- User agents *SHOULD* check the chain of ancestor elements for
 [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)`="true"`.
 If found, user agents *SHOULD* set the `RELATION_MEMBER_OF` relation
 to point to the ancestor that sets
 [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)`="true"`.

::: header-wrapper
#### 3.6.3 Group Position

[`aria-level`](https://w3c.github.io/aria/#aria-level),
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset),
and
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize)
are all 1-based. When the
[property](https://www.w3.org/TR/wai-aria/#dfn-property "Normative reference to non-normative term.") is not present or is \"0\",
it indicates the property is not computed or not supported. If any of
these properties are specified by the author as either \"0\" or a
negative number, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* use \"1\" instead.

If
[`aria-level`](https://w3c.github.io/aria/#aria-level)
is not provided or inherited for an element of
[role](https://www.w3.org/TR/wai-aria-1.3/#dfn-role)
[`treeitem`](https://w3c.github.io/aria/#treeitem) or
[`comment`](https://w3c.github.io/aria/#comment), user
agents implementing IAccessible2 or [ATK]/[AT-SPI] *MUST* compute
it by following the explicit or computed `RELATION_NODE_CHILD_OF`
relations.

If
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
and
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize)
are not provided, user agents *MUST* compute them as follows:

- for
 ``
 and
 ``,
 walk the tree backward and forward until the explicit or computed
 level becomes less than the current item\'s level. Count items only if
 they are at the same level as the current item.
- Otherwise, if the role supports
 [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
 and
 [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize),
 process the parent ([DOM] parent
 or parent defined by
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns)),
 counting items that have the same role.
- Because these value are 1-based, include the current item in the
 computation. For
 [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset),
 include the current item and other group items if they are before the
 current item in the [DOM]. For
 [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize),
 add to that the number of items in the same group after the current
 item in the [DOM].

If the author provides one or more of `aria-setsize` and
`aria-posinset`, it is the author\'s responsibility to supply them for
all elements in the set. [User
agent](https://infra.spec.whatwg.org/#user-agent)
correction of missing values in this case is not defined.

[MSAA]/IAccessible2
[API] mappings involve
an additional function, `groupPosition()`
\[[IAccessible2](#bib-iaccessible2 "IAccessible2")\], when
[`aria-level`](https://w3c.github.io/aria/#aria-level),
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset),
and/or
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize)
are present on an element, or are computed by the user agent. When this
occurs:

- [`aria-level`](https://w3c.github.io/aria/#aria-level)
 is exposed in the `groupLevel` parameter of `groupPosition()`,
- [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize)
 is exposed in the `similarItemsInGroup` parameter, and
- [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
 is exposed in the `positionInGroup` parameter.

::: header-wrapper
### 3.7 Actions

As part of mapping roles to accessible objects as defined in [Role
Mapping](#mapping_role), users agents expose a default action on the
object.

- [MSAA]: If an [AT] calls `DoDefaultAction` on an accessible
 object, the user agent *SHOULD* simulate a click on the [DOM] element which is mapped to that
 accessible object.
- IAccessible2: If an [AT] calls the
 `IAccessibleAction` on an accessible object, the user agent *SHOULD*
 simulate a click on the [DOM]
 element which is mapped to that accessible object.
- [UIA] Automation: If an
 [AT] calls any [UIA] pattern method on an accessible
 object, the user agent *SHOULD* simulate a click on the [DOM] element which is mapped to that
 accessible object.
- [ATK]/[AT-SPI]: If an
 [AT] calls an action on an
 accessible object, the user agent *SHOULD* simulate a click on the
 [DOM] element which is mapped to
 that accessible object.
- [AX API]: If an [AT] triggers an `AXPress` action on an
 accessible object, the user agent *SHOULD* simulate a click on the
 [DOM] element which is mapped to
 that accessible object.

Authors will need to create handlers for those click events that update
[WAI-ARIA] states
and properties in the [DOM]
accordingly, so that those updated states can be populated by the user
agent in the Accessibility [API].

::: header-wrapper
### 3.8 Events

[User
agents](https://infra.spec.whatwg.org/#user-agent) fire
[events](https://dom.spec.whatwg.org/#concept-event) for user actions, [WAI-ARIA]
[state](https://www.w3.org/TR/wai-aria/#dfn-state) changes, changes to document content or node
visibility, changes in selection and operation of menus as defined in
the following sections.

::: header-wrapper
#### 3.8.1 State and Property Change Events

[User
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* notify [assistive
technology](https://www.w3.org/TR/wai-aria/#assistive-technology) of
[state](https://www.w3.org/TR/wai-aria/#dfn-state) changes as defined in the table below, *SHOULD* notify
assistive technology of
[property](https://www.w3.org/TR/wai-aria/#dfn-property "Normative reference to non-normative term.") changes if the [accessibility
[API]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api) defines a change
[event](https://dom.spec.whatwg.org/#concept-event) for the property, and *SHOULD NOT* notify
assistive technology of property changes if the accessibility
[API] does not define a
change event for the property. For example, IAccessible2 defines an
event to be used when
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
changes. [WAI-ARIA]
properties that are expected to change include
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant),
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow),
and
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext).

In some [APIs],
[AT] will only be notified of events
to which it has subscribed.

For simplicity and performance the user agent *MAY* trim out change
events for state or property changes that [assistive
technologies](https://www.w3.org/TR/wai-aria/#assistive-technology) typically ignore, such as events that are
happening in a window that does not currently have focus.

Translators: For label text associated with the following table and its
toggle buttons, see the `mappingTableLabels` object in the `<head>`
section of this document.

::: header-wrapper
##### 3.8.1.1 `aria-activedescendant`

+----------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| ARIA Specification | [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
+----------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| [MSAA] + | See [Focus Changes](#focus_state_event_table). |
| IAccessible2 event | |
| | In addition: |
| | |
| | `IA2_EVENT_ACTIVE_DESCENDANT_CHANGED` |
+----------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| [UIA] event | See [Focus Changes](#focus_state_event_table). |
| | |
| | In addition: |
| | |
| | `PropertyChangedEvent` |
| | |
| | Property: `AriaProperties` |
+----------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| [AX API] | See [Focus Changes](#focus_state_event_table). |
| Notification | |
| | In addition: `AXSelectedChildrenChanged` |
+----------------------------------------------------------+---------------------------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+---------------------------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.2 `aria-busy` (state)

+----------------------------------------------------------+------------------------------------------------------------------------+
| ARIA Specification | [`aria-busy`](https://w3c.github.io/aria/#aria-busy) |
| | (state) |
+----------------------------------------------------------+------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_STATECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Property: `AriaProperties` |
+----------------------------------------------------------+------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+------------------------------------------------------------------------+
| [AX API] | `AXElementBusyChanged` |
| Notification | |
+----------------------------------------------------------+------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.3 `aria-checked` (state)

+----------------------------------------------------------+------------------------------------------------------------------------------+
| ARIA Specification | [`aria-checked`](https://w3c.github.io/aria/#aria-checked) |
| | (state) |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_STATECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Properties: `AriaProperties`, `ToggleState` as part of `toggle` pattern |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [AX API] | `AXValueChanged` |
| Notification | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.4 `aria-current` (state)

+----------------------------------------------------------+------------------------------------------------------------------------------+
| ARIA Specification | [`aria-current`](https://w3c.github.io/aria/#aria-current) |
| | (state) |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [MSAA] + | `IA2_EVENT_OBJECT_ATTRIBUTE_CHANGED` |
| IAccessible2 event | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Property: `AriaProperties` |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [AX API] | `AXCurrentStateChanged` |
| Notification | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.5 `aria-disabled` (state)

+----------------------------------------------------------+--------------------------------------------------------------------------------+
| ARIA Specification | [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
| | (state) |
+----------------------------------------------------------+--------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_STATECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+--------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Properties: `AriaProperties`, `IsEnabled` |
+----------------------------------------------------------+--------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+--------------------------------------------------------------------------------+
| [AX API] | `AXDisabledStateChanged` |
| Notification | |
+----------------------------------------------------------+--------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+--------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.6 `aria-describedby`

+----------------------------------------------------------+-----------------------------------------------------------------------------------------+
| ARIA Specification | [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
+----------------------------------------------------------+-----------------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_DESCRIPTIONCHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Properties: `DescribedBy` |
+----------------------------------------------------------+-----------------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------------+
| [AX API] | `AXDescribedByChanged` |
| Notification | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+-----------------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.7 `aria-dropeffect` (property, deprecated)

+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| ARIA Specification | [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | (property, deprecated) |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| [MSAA] + | `IA2_EVENT_OBJECT_ATTRIBUTE_CHANGED` |
| IAccessible2 event | |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Property: `AriaProperties` |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| [AX API] | `AXDropEffectChanged` |
| Notification | |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.8 `aria-expanded` (state)

+----------------------------------------------------------+--------------------------------------------------------------------------------+
| ARIA Specification | [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | (state) |
+----------------------------------------------------------+--------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_STATECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+--------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Properties: `AriaProperties`, `ExpandCollapseState` as part of the |
| | `ExpandCollapse` pattern |
+----------------------------------------------------------+--------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+--------------------------------------------------------------------------------+
| [AX API] | `AXRowExpanded`,\ |
| Notification | `AXRowCollapsed`,\ |
| | `AXRowCountChanged` |
+----------------------------------------------------------+--------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+--------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.9 `aria-grabbed` (state, deprecated)

+----------------------------------------------------------+------------------------------------------------------------------------------+
| ARIA Specification | [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) |
| | (state, deprecated) |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_SELECTION` |
| IAccessible2 event | |
| | `IA2_EVENT_OBJECT_ATTRIBUTE_CHANGED` |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Property: `AriaProperties` |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [AX API] | `AXGrabbedStateChanged` |
| Notification | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.10 `aria-hidden` (state)

+----------------------------------------------------------+----------------------------------------------------------------------------+
| ARIA Specification | [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) |
| | (state) |
+----------------------------------------------------------+----------------------------------------------------------------------------+
| [MSAA] + | ` IA2_EVENT_OBJECT_ATTRIBUTE_CHANGED` |
| IAccessible2 event | |
+----------------------------------------------------------+----------------------------------------------------------------------------+
| [UIA] event | `StructureChangedEvent` |
| | |
| | `PropertyChangedEvent` |
| | |
| | Property: `AriaProperties` |
+----------------------------------------------------------+----------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+----------------------------------------------------------------------------+
| [AX API] | `AXUIElementDestroyed`,\ |
| Notification | `AXUIElementCreated` |
+----------------------------------------------------------+----------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+----------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.11 `aria-invalid` (state)

+----------------------------------------------------------+------------------------------------------------------------------------------+
| ARIA Specification | [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
| | (state) |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_STATECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Properties: `AriaProperties`, `IsDataValidForForm` |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [AX API] | `AXInvalidStatusChanged` |
| Notification | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.12 `aria-label` and `aria-labelledby`

+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| ARIA Specification | [`aria-label`](https://w3c.github.io/aria/#aria-label) and |
| | [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_NAMECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Property for `aria-label`: `AriaProperties` |
| | |
| | Property for `aria-labelledby`: `LabeledBy` |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| [AX API] | `AXLabelCreated` |
| Notification | |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+---------------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.13 `aria-pressed` (state)

+----------------------------------------------------------+------------------------------------------------------------------------------+
| ARIA Specification | [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed) |
| | (state) |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_STATECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Properties: `AriaProperties`, `ToggleState` as part of `toggle` pattern |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| [AX API] | `AXPressedStateChanged` |
| Notification | |
+----------------------------------------------------------+------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.14 `aria-readonly`

+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| ARIA Specification | [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_STATECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Property: `AriaProperties` |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [AX API] | `AXReadOnlyStatusChanged` |
| Notification | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.15 `aria-required`

+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| ARIA Specification | [`aria-required`](https://w3c.github.io/aria/#aria-required) |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_STATECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Properties: `AriaProperties`, `IsRequiredForForm` |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [AX API] | `AXRequiredStatusChanged` |
| Notification | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.16 `aria-selected` (state)

-------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
 ARIA Specification [`aria-selected`](https://w3c.github.io/aria/#aria-selected) (state)
 [MSAA] + IAccessible2 event See section [Selection](#mapping_events_selection) for details.
 [UIA] event See section [Selection](#mapping_events_selection) for details.
 [ATK]/[AT-SPI] event See section [Selection](#mapping_events_selection) for details.
 [AX API] Notification See section [Selection](#mapping_events_selection) for details.
 Android TBD
 -------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------

::: header-wrapper
##### 3.8.1.17 `aria-valuenow`

+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| ARIA Specification | [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_VALUECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Properties: `AriaProperties`, also `RangeValueValue` if element is mapped with |
| | `RangeValue` Control Pattern |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| [AX API] | `AXValueChanged` |
| Notification | |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+-----------------------------------------------------------------------------------+

::: header-wrapper
##### 3.8.1.18 `aria-valuetext`

+----------------------------------------------------------+-------------------------------------------------------------------------------------+
| ARIA Specification | [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext) |
+----------------------------------------------------------+-------------------------------------------------------------------------------------+
| [MSAA] + | `EVENT_OBJECT_VALUECHANGE` |
| IAccessible2 event | |
+----------------------------------------------------------+-------------------------------------------------------------------------------------+
| [UIA] event | `PropertyChangedEvent` |
| | |
| | Property: `AriaProperties` |
+----------------------------------------------------------+-------------------------------------------------------------------------------------+
| [ATK]/[AT-SPI] | |
| event | |
+----------------------------------------------------------+-------------------------------------------------------------------------------------+
| [AX API] | `AXValueChanged` |
| Notification | |
+----------------------------------------------------------+-------------------------------------------------------------------------------------+
| Android | TBD |
+----------------------------------------------------------+-------------------------------------------------------------------------------------+

::: header-wrapper
#### 3.8.2 Changes to document content or node visibility

Processing document changes is important regardless of [WAI-ARIA]. The events described in
the table below are used by user agents to inform [AT] of changes to the [DOM] via the accessibility tree. For the
purposes of conformance with this standard, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* implement the behavior described in this section whenever
[WAI-ARIA]
attributes are applied to dynamic content on a Web page.

 -------------- ------------------------------------------- ------------------------------------ ---------------------------------------------------------- -------------------------------------------------------------------
 Scenario [MSAA]/[AT-SPI] Notification
 title="Microsoft Active Accessibility"} + title="User Interface Automation"} title="Assistive Technology-Service Provider Interface"}
 IAccessible2 event event event

 When text is `IA2_EVENT_TEXT_REMOVED` `EVENT_OBJECT_LIVEREGIONCHANGED` `text_changed::delete` If in a [live
 removed region](https://www.w3.org/TR/wai-aria/#dfn-live-region), `AXLiveRegionChanged`.\
 If in `aria-errormessage`, `AXValidationErrorChanged`.

 When text is `IA2_EVENT_TEXT_INSERTED` `EVENT_OBJECT_LIVEREGIONCHANGED` `text_changed::insert` If in a [live
 inserted region](https://www.w3.org/TR/wai-aria/#dfn-live-region), `AXLiveRegionChanged`.\
 If in `aria-errormessage`, `AXValidationErrorChanged`.

 When text is `IA2_EVENT_TEXT_REMOVE` and `EVENT_OBJECT_LIVEREGIONCHANGED` `text_changed::delete` and `text_changed::insert` If in a [live
 changed `IA2_EVENT_TEXT_INSERTED` region](https://www.w3.org/TR/wai-aria/#dfn-live-region), `AXLiveRegionChanged`.\
 If in `aria-errormessage`, `AXValidationErrorChanged`.
 -------------- ------------------------------------------- ------------------------------------ ---------------------------------------------------------- -------------------------------------------------------------------

 : Table of document change scenarios and events to be fired in each
 [API]

Fire the following events for node changes where the node in question is
an element and has an [accessible
object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object). The [accessibility
subtree] of a node is its [accessible
object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) in the [accessibility
tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree)
and all of it\'s [accessibility
descendants](https://www.w3.org/TR/wai-aria/#dfn-accessibility-descendant).
It does not include objects which have relationships other than
parent-child in that tree. For example, it does not include objects
linked via
[aria-flowto](https://w3c.github.io/aria/#aria-flowto) unless
those objects are also descendants in the [accessibility
tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree).

+----------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------+-----------------------------------------------+----------------------------------------------------------+---------------------------------------+
| Scenario | [MSAA] | title="User Interface Automation"} event | title="Accessibility Toolkit"}/[AT-SPI] |
| | | | title="Assistive Technology-Service Provider Interface"} | Notification |
| | | | event | |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------+-----------------------------------------------+----------------------------------------------------------+---------------------------------------+
| When an [accessibility subtree](#dfn-accessibility-subtree) is | `EVENT_OBJECT_HIDE`\ | `AutomationElement..::.StructureChangedEvent` | `children_changed::remove` | `AXUIElementDestroyed` |
| [hidden](https://www.w3.org/TR/wai-aria/#dfn-hidden "Normative reference to non-normative term.") | title="Microsoft Active Accessibility"} | | | If in a live region, |
| | event called `EVENT_OBJECT_DESTROY` is | | | `AXLiveRegionChanged` |
| | not used because this has a history of | | | |
| | stability issues and assistive | | | |
| | technology avoids it. In any case, from | | | |
| | the user\'s point of view, there is no | | | |
| | difference between something that is | | | |
| | hidden or destroyed. | | | |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------+-----------------------------------------------+----------------------------------------------------------+---------------------------------------+
| When an accessibility subtree is removed | `EVENT_OBJECT_REORDER`\ | `AutomationElement..::.StructureChangedEvent` | `children_changed::remove` | `AXUIElementDestroyed` |
| | The [MSAA] | | | If in a live region, |
| | event called `EVENT_OBJECT_DESTROY` is | | | `AXLiveRegionChanged` |
| | not used because this has a history of | | | |
| | stability issues and assistive | | | |
| | technology avoids it. In any case, from | | | |
| | the user\'s point of view, there is no | | | |
| | difference between something that is | | | |
| | hidden or destroyed. | | | |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------+-----------------------------------------------+----------------------------------------------------------+---------------------------------------+
| When an accessibility subtree is shown | `EVENT_OBJECT_SHOW` |   | `children_changed::add` | `AXUIElementCreated` |
| | | | | |
| | | | | If in a live region, |
| | | | | `AXLiveRegionChanged` |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------+-----------------------------------------------+----------------------------------------------------------+---------------------------------------+
| When an accessibility subtree is inserted | `EVENT_OBJECT_REORDER` |   | `children_changed::add` | `AXUIElementCreated` |
| | | | | |
| | | | | If in a live region, |
| | | | | `AXLiveRegionChanged` |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------+-----------------------------------------------+----------------------------------------------------------+---------------------------------------+
| When an accessibility subtree is moved | Treat it as a removal from one place | Treat it as a removal from one place and | Treat it as a removal from one place and insertion in | `AXUIElementDestroyed`/ |
| | and insertion in another | insertion in another | another | `AXUIElementCreated` |
| | | | | |
| | | | | If in a live region, |
| | | | | `AXLiveRegionChanged` |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------+-----------------------------------------------+----------------------------------------------------------+---------------------------------------+
| When an accessibility subtree is changed (e.g. replaceNode) | Treat it as a removal and insertion | Treat it as a removal and insertion | Treat it as a removal and insertion | `AXUIElementDestroyed`/ |
| | | | | `AXUIElementCreated` |
| | | | | |
| | | | | If in a live region, |
| | | | | `AXLiveRegionChanged` |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------+-----------------------------------------+-----------------------------------------------+----------------------------------------------------------+---------------------------------------+

: Table of document change scenarios and events to be fired in each
[API]

In some cases, node changes may occur where the node is not an element
or has no accessible object. For example, a numbered list bullet
(\"12.\") may have a node in the accessibility tree but not in the
[DOM] tree. For text within a
paragraph marked in [HTML] as
`<strong>`, the `<strong>` element has a node in the [DOM] tree but may not have one in the
accessibility tree. The text itself will of course be in the
accessibility tree along with the identification of the range of text
that is formatted as strong. If any of the changes described in the
table above occur on such a node, user agents *SHOULD* compute and fire
relevant text change events as described above.

User agents *SHOULD* ensure that an assistive technology, running in
process can receive notification of a node being removed prior to
removal. This allows an assistive technology, such as a screen reader,
to refer back to the corresponding [DOM] node being deleted. This is important for
[live regions](https://www.w3.org/TR/wai-aria/#dfn-live-region) where removals are important. For example,
a screen reader would want to notify a user that another user has left a
chat room. The event in [MSAA] would be` EVENT_OBJECT_HIDE`.
For [ATK]/[AT-SPI] this would be
`children_changed::remove`. And in macOS, the event is
`AXLiveRegionChanged`. This also requires the user agent to provide a
unique ID in the [accessibility [API]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api) notification identifying the unique node
being removed.

When firing any of the above-mentioned change events, it is very useful
to provide information about whether the change was caused by user input
(as opposed to a timeout initiated from the page load, etc.). This
allows the assistive technology to have different rules for presenting
changes from the real world as opposed to from user action. Mouse hovers
are not considered explicit user input because they can occur from
accidental bumps of the mouse.

To expose whether a change occurred from user input:

- In [ATK]/[AT-SPI] this can be
 provided by appending the string \":system\" to the event name when
 the user did not cause the change.
- In IAccessible2, which screen readers typically access in process on
 the same thread, the best practice is to expose the object attribute
 `event-from-user-input:true` on the accessible object for the event,
 if the user caused the change.

Exposing additional useful information about the context of the change:

- In [ATK]/[AT-SPI] and
 IAccessible2, the `RELATION_MEMBER_OF` relation on the accessible
 event\'s target accessible object *SHOULD* point to any ancestor with
 [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)`="true"`
 (if any).
- In [ATK]/[AT-SPI] and
 IAccessible2, the `container-live`, `container-relevant`,
 `container-busy`, `container-atomic` object attributes *SHOULD* be
 exposed on the accessible event object, providing the computed value
 for the related [WAI-ARIA] properties. The computed
 value is the value of the closest ancestor. It is recommended to not
 expose the object attribute if the default value is used.

Additional [MSAA] events
may be necessary:

- If something changes in an ancestor with a mapped [MSAA] role of `ROLE_SYSTEM_ALERT`,
 then an `EVENT_SYSTEM_ALERT` event *SHOULD* be fired for the alert.
 The alert role has an implied value of \"assertive\" for the
 [`aria-live`](https://w3c.github.io/aria/#aria-live)
 property.
- Menu events may need to be fired. See [Special Events for
 Menus](#mapping_events_menus).

::: header-wrapper
#### 3.8.3 Focus Changes

The following table defines the accessibility [API] keyboard focus states and
events.

+-------------+-----------------------------------------+-----------------------------------------------------+---------------------------------------------------------------------------+---------------------------------------+
|   | [MSAA]/[AT-SPI] | title="User Interface Automation"} | title="Assistive Technology - Service Provider Interface"} | title="macOS Accessibility Protocol"} |
+-------------+-----------------------------------------+-----------------------------------------------------+---------------------------------------------------------------------------+---------------------------------------+
| Focusable | `STATE_SYSTEM_FOCUSABLE` | Current state reflected in | `STATE_FOCUSABLE` | `boolean AXFocused`: the |
| state | | `IUIAutomationElement::CurrentIsKeyboardFocusable`, | | `AXUIElementIsAttributeSettable` |
| | | can be retrieved with | | method returns `YES`. |
| | | `IUIAutomationElement::GetCurrentPropertyValue` | | |
| | | method using `UIA_IsKeyboardFocusablePropertyId` | | |
| | | property identifier. | | |
+-------------+-----------------------------------------+-----------------------------------------------------+---------------------------------------------------------------------------+---------------------------------------+
| Focused | `STATE_SYSTEM_FOCUSED` | Current state reflected in | `STATE_FOCUSED` | `boolean AXFocused` |
| state | | `IUIAutomationElement::CurrentHasKeyboardFocus`, | | |
| | | can be retrieved with | | |
| | | `IUIAutomationElement::GetCurrentPropertyValue` | | |
| | | method using `UIA_HasKeyboardFocusPropertyId` | | |
| | | property identifier. | | |
+-------------+-----------------------------------------+-----------------------------------------------------+---------------------------------------------------------------------------+---------------------------------------+
| Focus event | `EVENT_OBJECT_FOCUS` | Clients can subscribe with | `object:state-changed:focused` and: | `AXFocusedUIElementChanged` |
| | | `IUIAutomation::AddFocusChangedEventHandler` using | | |
| | | callback interface is | - `detail1 = 1` for the [accessible | |
| | | `IUIAutomationFocusChangedEventHandler` | object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) which just gained focus. | |
| | | | - `detail1 = 0` for the [accessible | |
| | | | object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) which just lost focus. | |
+-------------+-----------------------------------------+-----------------------------------------------------+---------------------------------------------------------------------------+---------------------------------------+

: Table of [accessibility [APIs]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api) for focus states and
[events](https://dom.spec.whatwg.org/#concept-event)

::: header-wrapper
#### 3.8.4 Selection

There are two cases for selection:

- Single selection
- Multiple selection

In the single selection case, selection follows focus (see the section
\"[Focus States and Events Table](#focus_state_event_table)\" for
information about focus events). User agents *MUST* fire the following
events when
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
changes:

+-------------+-----------------------------------------+---------------------------------------------+---------------------------------------------------------------------------+---------------------------------------+
| Scenario | [MSAA]/[AT-SPI] | title="User Interface Automation"} | title="Assistive Technology - Service Provider Interface"} | title="macOS Accessibility Protocol"} |
+-------------+-----------------------------------------+---------------------------------------------+---------------------------------------------------------------------------+---------------------------------------+
| Focus | `EVENT_OBJECT_SELECTION` and | `UIA_SelectionItem_ElementSelectedEventId` | - `object:selection-changed` on the current container, | `AXSelectedChildrenChanged` |
| change | `EVENT_OBJECT_STATECHANGE` on newly | on the newly focused element. | - `object:state-changed:selected` on the descendant [accessible | |
| | focused item. | | object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) whose selection has changed: | |
| | | `tab`, fire | - `detail1 = 1` for the descendant which just became selected. | |
| | | `UIA_SelectionItem_ElementSelectedEventId`. | - `detail1 = 0` for the descendant which just became unselected. | |
+-------------+-----------------------------------------+---------------------------------------------+---------------------------------------------------------------------------+---------------------------------------+

: Single selection events

The multiple selection case occurs when
[`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable)`="true"`
on an [element](https://dom.spec.whatwg.org/#concept-element) with a
[role](https://www.w3.org/TR/wai-aria-1.3/#dfn-role) that supports
that
[property](https://www.w3.org/TR/wai-aria/#dfn-property "Normative reference to non-normative term."). User agents *MUST* fire the
following events when
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
changes on a descendant, as follows:

The multiple selection case occurs when
[`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable)`="true"`
on an [element](https://dom.spec.whatwg.org/#concept-element) with a
[role](https://www.w3.org/TR/wai-aria-1.3/#dfn-role) that supports
that
[property](https://www.w3.org/TR/wai-aria/#dfn-property "Normative reference to non-normative term."). There are several important
aspects:

1. In Microsoft [UIA], the
 `Selection` and `SelectionItem` Control Patterns expose the
 selection availability, state, and methods.
2. User agents *MUST* fire the following events when
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected)
 changes on a descendant, as follows:

+--------------------------------------------------------------------------------+------------------------------------------------------------+------------------------------------------------------------------------------------+-----------------------------------------------------------------------------+---------------------------------------+
| Scenario | [MSAA] | Microsoft [UIA] | [ATK]/[AT-SPI] | title="macOS Accessibility Protocol"} |
+--------------------------------------------------------------------------------+------------------------------------------------------------+------------------------------------------------------------------------------------+-----------------------------------------------------------------------------+---------------------------------------+
| Toggle | `EVENT_OBJECT_SELECTIONADD`/`EVENT_OBJECT_SELECTIONREMOVE` | `SelectionItem Control Pattern`:`UIA_SelectionItem_ElementAddedToSelectionEventId` | - `object:selection-changed` on the current container, | `AXSelectedChildrenChanged` |
| [`aria-selected`](https://w3c.github.io/aria/#aria-selected) | on the item. | or `UIA_SelectionItem_ElementRemovedFromSelectionEventId` on the item. | - `object:state-changed:selected` on any descendant [accessible | |
| | | | object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) whose selection has changed: | |
| | | | - `detail1 = 1` for any descendant which just became selected. | |
| | | | - `detail1 = 0` for any descendant which just became unselected. | |
+--------------------------------------------------------------------------------+------------------------------------------------------------+------------------------------------------------------------------------------------+-----------------------------------------------------------------------------+---------------------------------------+
| Selection follows focus | `EVENT_OBJECT_SELECTION` and `EVENT_OBJECT_STATECHANGE` on | `FocusChangedEvent` should be fired but individual selection event may not happen, | - `object:selection-changed` on the current container, | `AXSelectedChildrenChanged` |
| | newly focused item. | to avoid redundancy. | - `object:state-changed:selected` on any descendant [accessible | |
| | | | object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) whose selection has changed: | |
| | | | - `detail1 = 1` for any [accessible | |
| | | | object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) which just became selected. | |
| | | | - `detail1 = 0` for any [accessible | |
| | | | object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) which just became unselected. | |
+--------------------------------------------------------------------------------+------------------------------------------------------------+------------------------------------------------------------------------------------+-----------------------------------------------------------------------------+---------------------------------------+
| Select or deselect many items at once | User agent *MAY* fire an `EVENT_OBJECT_SELECTIONWITHIN`. | For each element selected or deselected, fire `SelectionItem` Control Pattern: | - the user agent *MAY* fire a single `object:selection-changed` event on | `AXSelectedChildrenChanged` |
| | If this event is fired the other events noted above *MAY* | `UIA_SelectionItem_ElementAddedToSelectionEventId` or | the container, vs. multiple events, for performance, | |
| | be trimmed out for performance. | `UIA_SelectionItem_ElementRemovedFromSelectionEventId` on the current container. | - `object:state-changed:selected` on any descendant [accessible | |
| | | User agents *MAY* choose to fire the Selection Control Pattern Invalidated event, | object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) whose selection has changed: | |
| | | requires sending more addition and removal events than the `InvalidateLimit` | - `detail1 = 1` for any [accessible | |
| | | constant permits. | object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) which just became selected. | |
| | | | - `detail1 = 0` for any [accessible | |
| | | | object](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) which just became unselected. | |
+--------------------------------------------------------------------------------+------------------------------------------------------------+------------------------------------------------------------------------------------+-----------------------------------------------------------------------------+---------------------------------------+

: Multiple selection events

::: header-wrapper
#### 3.8.5 Special Events for Menus

Some [APIs], provide
special [events](https://dom.spec.whatwg.org/#concept-event) whenever a menu is opened or closed. [User
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* provide the events as described in the table below. If
provided, because menus can be made visible or
[hidden](https://www.w3.org/TR/wai-aria/#dfn-hidden "Normative reference to non-normative term.") using a variety of
techniques, a [user
agent](https://infra.spec.whatwg.org/#user-agent)
*MUST* ensure that the events are nested and symmetrical.

Frequently, a
[`menubar`](https://w3c.github.io/aria/#menubar) is
used to organize a hierarchy of menus. In those cases, the menubar
*MUST* be a [DOM] parent of the
associated
[`menuitem`](https://w3c.github.io/aria/#menuitem)s, or
one defined by
[`aria-owns`](https://w3c.github.io/aria/#aria-owns).
In other cases, no menubar is involved; for example, when the
[`menu`](https://w3c.github.io/aria/#menu) is
associated with a toolbar button, or is a context menu. Nonetheless the
relevant menu events are provided as described in the following table.

+-----------------+-----------------------------------------+------------------------------------+---------------------------------------+
| Scenario | [MSAA] | title="User Interface Automation"} | title="macOS Accessibility Protocol"} |
+-----------------+-----------------------------------------+------------------------------------+---------------------------------------+
| Menubar is | Activate the menubar and fire | `MenuModeStartEvent` on the | `AXMenuOpenedNotification` |
| currently not | `EVENT_SYSTEM_MENUSTART` on the | accessible object for the menu. | |
| active, and | accessible object for the menubar. | | |
| user moves | | | |
| focus to the | | | |
| menubar from | | | |
| elsewhere | | | |
| thereby | | | |
| activating it. | | | |
| As a result, a | | | |
| menuitem in the | | | |
| menubar is | | | |
| focused. | | | |
+-----------------+-----------------------------------------+------------------------------------+---------------------------------------+
| Focus a | `EVENT_OBJECT_FOCUS` | `AutomationFocusChangedEvent` | `AXMenuItemSelectedNotification` |
| menuitem while | | | |
| menubar is | | | |
| activated, or | | | |
| focus a | | | |
| menuitem in a | | | |
| menu. | | | |
+-----------------+-----------------------------------------+------------------------------------+---------------------------------------+
| Menu popup made | `EVENT_SYSTEM_MENUPOPUPSTART` | `MenuOpenedEvent`, then a `focus` | `AXMenuOpenedNotification` |
| visible (menu | | event on a menuitem. | |
| is opened). | | | |
| | | | |
| Should only be | | | |
| fired once | | | |
| until the menu | | | |
| is closed and | | | |
| opened again. | | | |
+-----------------+-----------------------------------------+------------------------------------+---------------------------------------+
| Menu popup | `EVENT_SYSTEM_MENUPOPUPEND` once only | `MenuClosedEvent` | `AXMenuClosedNotification` |
| hidden (menu is | for accessible menu object and only if | | |
| closed). | `EVENT_SYSTEM_MENUPOPUPSTART` was fired | | |
| | for it. | | |
+-----------------+-----------------------------------------+------------------------------------+---------------------------------------+
| Any open menus | `EVENT_SYSTEM_MENUEND` on the menubar | `MenuClosedEvent`, then | `AXMenuClosedNotification` |
| are closed | and deactivate the menubar. | `MenuModeEndEvent` | |
| including | | | |
| sub-menus, and | | | |
| user moves | | | |
| focus away from | | | |
| the menubar; | | | |
| menubar is | | | |
| deactivated. | | | |
+-----------------+-----------------------------------------+------------------------------------+---------------------------------------+

: Menu events

::: header-wrapper
## 4. Algorithms

Some [APIs] provide
methods which require specific algorithms to be followed. The following
sections provide the algorithm mapping tables for these methods.

::: header-wrapper
### 4.1 ARIANotifyMixin Algorithm Mapping Tables

The `ARIANotifyMixin` provides a method for announcing content to
assistive technologies. The following algorithm mappings specify how
these announcements will be implemented across different accessibility
[APIs] to ensure
consistent behavior for users of assistive technologies.

::: header-wrapper
#### 4.1.1 ariaNotify

To `aria notify` given `node`, `announcement`, and
`priority`:

+------------------------------------------------------------+--------------------------------------------------------------------------------------------------+
| ARIA Specification | [`aria notify`](#arianotify) |
+------------------------------------------------------------+--------------------------------------------------------------------------------------------------+
| Preconditions | If `node` is [excluded from the accessibility |
| | tree](https://w3c.github.io/aria/#tree_exclusion), then abort these steps. |
+------------------------------------------------------------+--------------------------------------------------------------------------------------------------+
| Language | User agents and assistive technologies *MUST* determine the language of the announcement by |
| | taking the first valid BCP 47 language tag from the following sources: |
| | |
| | 1. The `node`\'s nearest ancestor element\'s `lang` attribute (including |
| | `node` itself). |
| | 2. The document element\'s `lang` attribute (including when called on the document). |
| | 3. A user agent or platform default. |
| | |
| | Assistive technologies *MUST* present the announcement using that language (for example, voice, |
| | pronunciation rules, braille table). |
+------------------------------------------------------------+--------------------------------------------------------------------------------------------------+
| [MSAA] + | No implementation specified ([see fallback note](#arianotify-fallback-note)). |
| IAccessible2 | |
+------------------------------------------------------------+--------------------------------------------------------------------------------------------------+
| [UIA] | 1. Let `mapped_priority` be `NotificationProcessing_ImportantAll` if |
| | `priority` is \"high\", otherwise `NotificationProcessing_All`. |
| | |
| | 2. Call `UiaRaiseNotificationEvent` with `node`, `NotificationKind_ActionCompleted`, |
| | `mapped_priority`, `announcement`, and the empty string. |
| | |
| | :::: |
| | ::: |
| | Note |
| | ::: |
| | |
| | If the platform accessibility implementation determines that `node` is not |
| | represented in the [UIA] [Control |
| | view](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-treeoverview#control-view) |
| | or [Content |
| | view](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-treeoverview#content-view), |
| | user agents *SHOULD* instead raise the notification event on the nearest ancestor that is |
| | represented as a [UIA] Control. If no such ancestor |
| | exists, user agents *SHOULD* raise it on the document root (which is expected to be in one of |
| | these views) to ensure assistive technologies that ignore events on elements not in the Control |
| | or Content view receive the notification. |
| | :::: |
+------------------------------------------------------------+--------------------------------------------------------------------------------------------------+
| [ATK] | 1. Let `mapped_priority` be `Atk.Live.ATK_LIVE_ASSERTIVE` if `priority` |
| | is \"high\", otherwise `Atk.Live.ATK_LIVE_POLITE`. |
| | |
| | 2. Call `g_signal_emit_by_name` with `node`, `"notification"`, |
| | `announcement`, and `mapped_priority`. |
| | |
| | On older Linux accessibility stacks prior to [ATK] 2.50.0, |
| | user agents *MAY* use the fallback; [see fallback note](#arianotify-fallback-note). |
+------------------------------------------------------------+--------------------------------------------------------------------------------------------------+
| [AT-SPI] be `ATSPI_LIVE_ASSERTIVE` if `priority` is |
| title="Assistive Technology - Service Provider Interface"} | \"high\", otherwise `ATSPI_LIVE_POLITE`. |
| | |
| | 2. Send a DBUS signal `ATSPI_DBUS_INTERFACE_EVENT_OBJECT` with `node`, |
| | `"announcement"`, `announcement`, and `mapped_priority`. |
+------------------------------------------------------------+--------------------------------------------------------------------------------------------------+
| [AX API] | 1. Let `mapped_priority` be `NSAccessibilityPriorityHigh` if `priority` |
| | is \"high\", otherwise `NSAccessibilityPriorityMedium`. |
| | |
| | 2. Let `userInfo` be a `NSDictionary` with the following keys: |
| | |
| | 1. `NSAccessibilityAnnouncementKey` as `announcement` |
| | 2. `NSAccessibilityPriorityKey` as `mapped_priority` |
| | |
| | 3. Call `NSAccessibilityPostNotificationWithUserInfo` with `node`, |
| | `NSAccessibilityAnnouncementRequestedNotification`, and `userInfo`. |
+------------------------------------------------------------+--------------------------------------------------------------------------------------------------+

When no suitable platform notification [API] is available (for example,
older Linux accessibility stacks prior to [ATK] 2.50.0 that lack the newer notification
signal, or on Windows when the user agent is not able to use [UIA]), a user agent *MAY* synthesize a
temporary, assistive-technology-only live region in its accessibility
tree to convey an `aria notify` announcement. Such fallback nodes are
not exposed to or detectable by web content and this behavior is not
required.

::: header-wrapper
## 5. Privacy considerations

In accordance with [Web Platform Design
Principles](https://w3ctag.github.io/design-principles/#do-not-expose-use-of-assistive-tech),
this specification provides no programmatic interface to determine if
information is being used by Assistive Technologies. However, this
specification does allow an author to present different information to
users of Assistive Technologies from the information available to users
who do not use Assistive Technologies. This is possible using many
features of the ARIA and CORE-AAM specifications, just as this is
possible using many other parts of the web technology stack. This
content disparity could be abused to perform [active
fingerprinting](https://www.w3.org/TR/fingerprinting-guidance/#active-0)
of users of Assistive Technologies.

::: header-wrapper
## 6. Security considerations

This specification introduces no new security considerations.

::: header-wrapper
## A. Change Log

::: header-wrapper
### A.1 Substantive changes since the last [Candidate Recommendation Snapshot](https://www.w3.org/TR/2022/CR-core-aam-1.2-20221122/)

- 14-Nov-2022: add new [AX API] mappings for
 colindextext/rowindextext
- 4-Jan-2024: Fix: errant computed role for treegrid row
- 31-Oct-2023: Update [UIA]
 aria-readonly mappings
- 31-Oct-2023: Add aria-haspopup=\'grid\' mappings
- 31-Oct-2023: Correct AXAPI notifications
- 26-Oct-2023: Remove UIA_DescribedBy property from aria-describedby
 [UIA] mappings
- 12-Oct-2023: Make haspopup=\'true\' mapping identical to
 haspopup=\'menu\'
- 1-Sep-2023: Fix [AX API]
 aria-haspopup mappings
- 25-Aug-2023: Add map for `role=image` (synonym of `img`)
- 17-Aug-2023: add normative expectations and examples for computedrole
- 16-Aug-2023: Update mapping for aria-errormessage
- 15-May-2023: Add computed role section and mappings
- 8-May-2023: update [UIA]
 ins/del
- 13-Apr-2023: Add mapping for aria-braillelabel and
 aria-brailleroledescription
- 9-Apr-2023: Update annotation roles AXAPI mapping
- 6-Apr-2023: Update aria-describedby and aria-description AXAPI
- 6-Apr-2023: Update role=\'meter\' subrole for AXAPI
- 1-Feb-2023: remove AXAPI-specific \'menuitem in group\' guidance
- 1-Feb-2023: Update AXAPI mapping for aria-keyshortcuts
- 1-Feb-2023: Update IA2 role=\'blockquote\' map
- 1-Feb-2023: Update [MSAA] mapping for paragraph and time
 and caption

::: header-wrapper
### A.2 Substantive changes since the [Core Accessibility [API] Mappings 1.1 Recommendation](https://www.w3.org/TR/core-aam-1.1/)

- 1-Nov-2022: draft privacy and security
- 13-Oct-2022: fix: remove label and legend
- 12-Oct-2022: Remove mappings for `label` and `legend`.
- 05-Apr-2021: Update [ATK]
 mappings for `aria-colindex`, `aria-colspan`, `aria-colcount`,
 `aria-rowindex`, `aria-rowspan`, and `aria-rowcount`.
- 06-Apr-2020: Update [ATK]
 mappings for `alert` and `alertdialog`.
- 25-Feb-2020: Add mappings for `comment`, `mark`, and `suggestion`
 roles. Include `comment` in calculation for `aria-label` and group
 position.
- 25-Feb-2020: Add mappings for `aria-description`.
- 03-Nov-2019: Remove explicit AXRoleDescription values for [AX
 API]. User agents should
 follow the guidance described in the note.
- 22-Oct-2019: Add mappings for `strong` and `emphasis` roles for [AX
 API].
- 22-Oct-2019: Add mappings for `code` role for [AX API].
- 21-Oct-2019: Add mappings for `aria-colindextext` and
 `aria-rowindextext` roles for [ATK], IA2, and [UIA].
- 21-Oct-2019: Add mappings for `strong` and `emphasis` roles for
 [ATK], IA2, and [UIA].
- 21-Oct-2019: Add mappings for `code` role for [ATK], IA2, and [UIA].
- 18-Sep-2019: Update [MSAA] mappings for `subscript` and
 `superscript`
- 10-Sep-2019: Add mappings for `generic` role.
- 09-Jul-2019: Add mappings for `insertion` and `deletion` roles.
- 14-May-2019: Add mappings for `legend` role.
- 14-May-2019: Add mappings for `label` role.
- 14-May-2019: Add mappings for `time` role.
- 25-Apr-2019: Add mappings for `subscript` and `superscript` roles.
- 25-Feb-2019: Add mappings for `meter` role.
- 05-Feb-2019: Update [UIA]
 state and property change events.
- 06-Jun-2018: Update [UIA]
 mappings for `aria-placeholder`.
- 04-Jun-2018: Add mappings for `blockquote`, `caption`, and `paragraph`
 roles.
- 05-Mar-2018: Add mention of `AXTitle` for exposing rendered labels for
 AXAPI.
- 05-Mar-2018: Add events for `aria-label`, `aria-labelledby`, and
 `aria-describedby`.

::: header-wrapper
## B. Acknowledgments

*This section is non-normative.*

The following people contributed to the development of this document.

- [Aaron Leventhal](https://github.com/aleventhal)
- [Benjamin Beaudry](https://github.com/benbeaudry)
- [Bogdan Brinza](https://github.com/boggydigital)
- [Carolyn MacLeod](https://github.com/carmacleod)
- [Daniel Montalvo](https://github.com/daniel-montalvo)
- [Denis Ah-Kang](https://github.com/deniak)
- [Dominique Hazael-Massieux](https://github.com/dontcallmedom)
- [James Craig](https://github.com/cookiecrook)
- [James Nurthen](https://github.com/jnurthen)
- [Jason Kiss](https://github.com/jasonkiss)
- [joanmarie](https://github.com/joanmarie)
- [Joseph Scheuhammer](https://github.com/klown)
- [Matt King](https://github.com/mcking65)
- [Melanie Richards](https://github.com/melanierichards)
- [Peter Krautzberger](https://github.com/pkra)
- [Philippe Le Hegaret](https://github.com/plehegar)
- [R Brown](https://github.com/ricksbrown)
- [Rahim Abdi](https://github.com/rahimabdi)
- [Richard Schwerdtfeger](https://github.com/richschwer)
- [Sarah Higley](https://github.com/smhigley)
- [Sayan Sivakumaran](https://github.com/sivakusayan)
- [Scott O\'Hara](https://github.com/scottaohara)
- [Steve Faulkner](https://github.com/stevefaulkner)

::: header-wrapper
### B.1 ARIA WG participants at the time of publication

- Rahim Abdi (Apple Inc.)
- NAVYA AGARWAL (Adobe)
- Joey Arhar (Google LLC)
- Benjamin Beaudry (Microsoft Corporation)
- Curt Bellew (Oracle Corporation)
- Zoë Bijl ([W3C] Invited
 Experts)
- Gautier Chomel (EDRLab)
- Aleksandar Cindrikj (Netcetera)
- Keith Cirkel (Mozilla Foundation)
- Daniel Clark (Microsoft Corporation)
- Sydney Coleman (Google LLC)
- James Craig (Apple Inc.)
- Chris Cuellar (Bocoup)
- Diego Della Rossa (UsableNet)
- Joanmarie Diggs (Igalia)
- Tamsin Ewing ([W3C])
- Mayuri Faldu (Navy Federal Credit Union)
- Betsy Fanning (PDF Association)
- Steve Faulkner (TetraLogical Services Ltd)
- Patrick Foster (axes4 GmbH)
- Jane Fulton (Cisco)
- Bryan Garaventa ([W3C]
 Invited Experts)
- Matt Garrish (DAISY Consortium)
- Doug Geoffray (Microsoft Corporation)
- Ariella Gilmore (IBM Corporation)
- Taylore Givens (Microsoft Corporation)
- David Grogan (Google LLC)
- Shirisha Gubba (Google LLC)
- Jon Gunderson (University of Illinois)
- Oliver Habersetzer (SAP SE)
- Theo Hale ([W3C] Invited
 Experts)
- Sunny Hardasani (Adobe)
- Matthew Hardy (Adobe)
- Chris Harrelson (Google LLC)
- Sarah Higley (Microsoft Corporation)
- Hans Hillen (TPGi)
- takumi hiramatsu (Cybozu)
- Stanley Hon (Microsoft Corporation)
- Michael Jackson (Microsoft Corporation)
- John Jansen (Microsoft Corporation)
- Jilin Jiang (Ant Group Co., Ltd.)
- Duff Johnson (PDF Association)
- Summer Jones (Thomson Reuters Corp.)
- Yuki Kamahori (Cybozu)
- William Kilian (Kilian Codes LLC)
- Matthew King ([W3C] Invited
 Experts)
- Zachary Kinsey (TargetStream Technologies)
- Daisuke Kobayashi (Cybozu)
- Peter Krautzberger (krautzource UG)
- Nina Krauß (SAP SE)
- JaEun Jemma Ku (University of Illinois)
- Joe Lamyman (TetraLogical Services Ltd)
- Christopher Land (Oracle Corporation)
- Charles LaPierre (Benetech)
- Patrick Lauke (TetraLogical Services Ltd)
- Philip Lazarevic (Level Access)
- Leo Lee (Microsoft Corporation)
- Brett Lewis (TPGi)
- Alison Maher (Microsoft Corporation)
- Gurpreet Kaur Mangera (Rakuten Group, Inc.)
- Mark McCarthy (University of Illinois)
- Eduardo Meza Etienne (Navy Federal Credit Union)
- Clay Miller (Microsoft Corporation)
- Hirotaka Minamida (Cybozu)
- Daniel Montalvo ([W3C])
- Baldino Morelli (UsableNet)
- Jacques Newman (Microsoft Corporation)
- James Nurthen (Evinced Inc.)
- Scott O\'Hara (Microsoft Corporation)
- Lola Odelola ([W3C] Invited
 Experts)
- Neil Osman (Evinced Inc.)
- Yusuke Oyama (Cybozu)
- Adam Page (Hilton)
- Michael Pennisi (Bocoup)
- Giacomo Petri (UsableNet)
- Noah Praskins (TPGi)
- Lucas Radaelli (Google LLC)
- Paul Rayius (PDFix-US)
- Mark Rogers (Powermapper Software)
- Priti Rohra (BarrierBreak Solutions Private Limited)
- Adrian Roselli ([W3C] Invited
 Experts)
- Marco Sabidussi (UsableNet)
- Trisha Salas (Level Access)
- Stefan Schnabel (SAP SE)
- Harris Schneiderman (Deque Systems, Inc.)
- Raymond Schwartz (Navy Federal Credit Union)
- Davis Shaver (The Washington Post)
- Cynthia Shelly ([W3C] Invited
 Experts)
- Tzviya Siegman ([W3C])
- Avneesh Singh (DAISY Consortium)
- Michael\[tm\] Smith (sideshowbarker) ([W3C])
- Francis Storr (Intel Corporation)
- Nobukiyo Sugisaki (Cybozu)
- Melanie Sumner (IBM Corporation)
- Alexander Surkov (Igalia)
- James Teh (Mozilla Foundation)
- Roman Toda (Foxit software)
- David Tseng (Google LLC)
- Cybozu [W3C] (Cybozu)
- Tyler Wilcock (Apple Inc.)

::: header-wrapper
### B.2 Enabling funders

This publication has been funded in part with U.S. Federal funds from
the Department of Education, National Institute on Disability,
Independent Living, and Rehabilitation Research (NIDILRR), initially
under contract number ED-OSE-10-C-0067, then under contract number
HHSP23301500054C, and now under HHS75P00120P00168. The content of this
publication does not necessarily reflect the views or policies of the
U.S. Department of Education, nor does mention of trade names,
commercial products, or organizations imply endorsement by the U.S.
Government.

::: header-wrapper
## C. References

::: header-wrapper
### C.1 Normative references

\[HTML-AAM\]
: [HTML Accessibility API Mappings
 1.0](https://www.w3.org/TR/html-aam-1.0/). Scott O\'Hara; Rahim
 Abdi. W3C. 29 May 2026. W3C Working Draft. URL:
 <https://www.w3.org/TR/html-aam-1.0/>

\[IAccessible2\]
: [IAccessible2](https://wiki.linuxfoundation.org/accessibility/iaccessible2/).
 Linux Foundation. URL:
 <https://wiki.linuxfoundation.org/accessibility/iaccessible2/>

\[infra\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[RFC2119\]
: [Key words for use in RFCs to Indicate Requirement
 Levels](https://www.rfc-editor.org/info/rfc2119/). S. Bradner. IETF.
 March 1997. Best Current Practice. URL:
 <https://www.rfc-editor.org/info/rfc2119/>

\[RFC8174\]
: [Ambiguity of Uppercase vs Lowercase in RFC 2119 Key
 Words](https://www.rfc-editor.org/info/rfc8174/). B. Leiba. IETF.
 May 2017. Best Current Practice. URL:
 <https://www.rfc-editor.org/info/rfc8174/>

\[wai-aria\]
: [Accessible Rich Internet Applications (WAI-ARIA)
 1.0](https://www.w3.org/TR/wai-aria/). James Craig; Michael Cooper
 et al. W3C. 20 March 2014. W3C Recommendation. URL:
 <https://www.w3.org/TR/wai-aria/>

\[WAI-ARIA-1.2\]
: [Accessible Rich Internet Applications (WAI-ARIA)
 1.2](https://www.w3.org/TR/wai-aria-1.2/). Joanmarie Diggs; James
 Nurthen; Michael Cooper; Carolyn MacLeod. W3C. 6 June 2023. W3C
 Recommendation. URL: <https://www.w3.org/TR/wai-aria-1.2/>

::: header-wrapper
### C.2 Informative references

\[accname-1.2\]
: [Accessible Name and Description Computation
 1.2](https://www.w3.org/TR/accname-1.2/). Bryan Garaventa; Melanie
 Sumner. W3C. 29 May 2026. W3C Working Draft. URL:
 <https://www.w3.org/TR/accname-1.2/>

\[Android-Accessibility-API\]
: [Android Accessibility
 API](https://developer.android.com/guide/topics/ui/accessibility).
 Google. URL:
 <https://developer.android.com/guide/topics/ui/accessibility>

\[AT-SPI\]
: [Assistive Technology Service Provider
 Interface](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/).
 The GNOME Project. URL:
 <https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/>

\[ATK\]
: [ATK - Accessibility
 Toolkit](https://developer.gnome.org/atk/stable/). The GNOME
 Project. URL: <https://developer.gnome.org/atk/stable/>

\[AXAPI\]
: [The NSAccessibility Protocol for
 macOS](https://developer.apple.com/documentation/appkit/nsaccessibility).
 Apple, Inc. URL:
 <https://developer.apple.com/documentation/appkit/nsaccessibility>

\[CORE-AAM-1.1\]
: [Core Accessibility API Mappings
 1.1](https://www.w3.org/TR/core-aam-1.1/). Joanmarie Diggs; Joseph
 Scheuhammer; Richard Schwerdtfeger; Michael Cooper; Andi
 Snow-Weaver; Aaron Leventhal. W3C. 14 December 2017. W3C
 Recommendation. URL: <https://www.w3.org/TR/core-aam-1.1/>

\[dom\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[UI-AUTOMATION\]
: [UI
 Automation](https://docs.microsoft.com/en-us/windows/win32/winauto/ui-automation-specification).
 Microsoft Corporation. URL:
 <https://docs.microsoft.com/en-us/windows/win32/winauto/ui-automation-specification>

\[UIA-EXPRESS\]
: [The IAccessibleEx
 Interface](https://docs.microsoft.com/en-us/windows/win32/winauto/iaccessibleex).
 Microsoft Corporation. URL:
 <https://docs.microsoft.com/en-us/windows/win32/winauto/iaccessibleex>

\[WAI-ARIA-ROADMAP\]
: [Roadmap for Accessible Rich Internet Applications (WAI-ARIA
 Roadmap)](https://www.w3.org/TR/wai-aria-roadmap/). Richard
 Schwerdtfeger. W3C. 4 February 2008. W3C Working Draft. URL:
 <https://www.w3.org/TR/wai-aria-roadmap/>

[[↑]](#title)

[Permalink](#dfn-accessibility-subtree)
[exported]

**Referenced in:**

- [§ 3.8.2 Changes to document content or node
 visibility](#ref-for-dfn-accessibility-subtree-1 "§ 3.8.2 Changes to document content or node visibility")
