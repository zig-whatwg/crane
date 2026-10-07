//! Compatibility exports while callers move to html.dom_parser.
//! Shared parser algorithms live with HTML, outside interface implementations.
const parser = @import("html").dom_parser;
pub const ParseError = parser.ParseError;
pub const ParseOptions = parser.ParseOptions;
pub const Namespace = parser.Namespace;
pub const ScriptingParseOptions = parser.ScriptingParseOptions;
pub const ScriptLoader = parser.ScriptLoader;
pub const TypedScriptLoader = parser.TypedScriptLoader;
pub const parseHTML = parser.parseHTML;
pub const parseHTMLWithScripting = parser.parseHTMLWithScripting;
pub const parseFragment = parser.parseFragment;
