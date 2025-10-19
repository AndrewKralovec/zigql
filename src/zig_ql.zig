//! ZigQL - A GraphQL parser library for Zig
//!
//! This library provides comprehensive lexical analysis and parsing capabilities
//! for GraphQL documents, supporting both executable documents (queries, mutations,
//! subscriptions) and type system definitions (schemas, types, directives).
const std = @import("std");
pub const ast = @import("grammar/ast.zig");
pub const Lexer = @import("core/lexer.zig").Lexer;
pub const Parser = @import("core/parser.zig").Parser;
pub const parse = @import("core/parser.zig").parse;
pub const parseWithLimit = @import("core/parser.zig").parseWithLimit;

//
// Test cases for the zigql module
//

test {
    // Reference all declarations to ensure they compile
    std.testing.refAllDecls(@This());

    // Import test suites from submodules
    _ = @import("grammar/ast.zig");
    _ = @import("core/lexer.zig");
    _ = @import("core/parser.zig");
}
