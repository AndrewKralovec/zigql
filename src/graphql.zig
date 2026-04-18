//! A GraphQL parser library for Zig
//!
//! This library provides comprehensive lexical analysis and parsing capabilities
//! for GraphQL documents, supporting both executable documents (queries, mutations,
//! subscriptions) and type system definitions (schemas, types, directives).
const std = @import("std");
pub const ast = @import("ast/ast.zig");
pub const Lexer = @import("lexer/lexer.zig").Lexer;
pub const Parser = @import("parser/parser.zig").Parser;
pub const parse = @import("parser/parser.zig").parse;
pub const parseWithLimit = @import("parser/parser.zig").parseWithLimit;
//
// Test cases for the graphql module
//

test {
    // Reference all declarations to ensure they compile
    std.testing.refAllDecls(@This());

    // Import test suites from submodules
    _ = @import("ast/ast.zig");
    _ = @import("lexer/lexer.zig");
    _ = @import("parser/parser.zig");
}
