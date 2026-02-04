const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("tokens.zig").Token;
const TokenKind = @import("tokens.zig").TokenKind;
const ast = @import("../grammar/ast.zig");
const document = @import("../grammar/document.zig");
const config = @import("build_config.zig");

// Debugging functions to print the parser state.
// Configurable through build options.
// Might be removed in the future. This is a beta feature.
fn noopDebug(_: *Parser, _: []const u8) void {}
fn printDebug(p: *Parser, tag: []const u8) void {
    std.debug.print("{s}:\n", .{tag});
    std.debug.print("peek |{any}|\n", .{p.peek()});
}

/// The `Parser` struct handles converting GraphQL text into an
/// abstract syntax tree. It uses a `Lexer` to tokenize the input,
/// and provides methods for navigating and consuming tokens during parsing.
///
/// This struct is passed into grammar specific parsing functions
/// which walk the token stream, from the `Lexer`, and returns the top level `DocumentNode`.
pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    current_token: ?Token,

    /// Debug function to print the parser state.
    pub const debug = if (config.debug) printDebug else noopDebug;

    /// Initializes a new `Parser` from source text.
    /// The `Lexer` is set up with the given source, and no token is loaded... yet.
    pub fn init(allocator: std.mem.Allocator, source: []const u8) Parser {
        return Parser{
            .allocator = allocator,
            .lexer = Lexer.init(source),
            .current_token = null,
        };
    }

    /// Initializes a new `Parser` with a `Lexer` that has a limit on how far
    /// it can look ahead in the token stream. Useful for bounded parsing.
    pub fn withLimit(self: Parser, limit: usize) Parser {
        return Parser{
            .allocator = self.allocator,
            .current_token = self.current_token,
            .lexer = self.lexer.withLimit(limit),
        };
    }

    /// Next non-ignorable token from the `Lexer`.
    pub fn nextToken(self: *Parser) !Token {
        return nextNonIgnorableToken(&self.lexer);
    }

    /// Lookahead at the next non-ignorable token without advancing the `Lexer`.
    /// This is done by cloning the `Lexer` and scanning ahead.
    pub fn lookahead(self: *Parser) !Token {
        // TODO: Inefficient, refactor the lexer/cursor to allow lookahead without cloning.
        var lexer = self.lexer;
        return nextNonIgnorableToken(&lexer);
    }

    /// Peek the next token from the `Lexer`.
    /// This will load the next token until it is popped.
    pub fn peek(self: *Parser) !Token {
        if (self.current_token == null) {
            self.current_token = try self.nextToken();
        }
        return self.current_token.?;
    }

    /// Peek and check if the next token is of a given kind.
    pub fn peekKind(self: *Parser, kind: TokenKind) !bool {
        const token = try self.peek();
        return (token.kind == kind);
    }

    /// Pop the current token and reset the peeked state.
    pub fn pop(self: *Parser) !Token {
        const token = try self.peek();
        self.current_token = null;
        return token;
    }

    /// If the next token is a given keyword and matches the expected keyword,
    /// pop it and return true. Otherwise, return false and no-op.
    pub fn expectOptionalKeyword(self: *Parser, keyword: ast.SyntaxKeyWord) !bool {
        const token = try self.peek();
        const tkw = ast.stringToKeyword(token.data) orelse return false;
        if (token.kind == TokenKind.Name and tkw == keyword) {
            _ = try self.pop();
            return true;
        }
        return false;
    }

    /// Expect the next token is a given keyword. If it's not there, throw an error.
    pub fn expectKeyword(self: *Parser, keyword: ast.SyntaxKeyWord) !void {
        const token = try self.peek();
        const tkw = ast.stringToKeyword(token.data) orelse return error.UnknownKeyword;
        if (token.kind == TokenKind.Name and tkw == keyword) {
            _ = try self.pop();
        } else {
            return error.UnexpectedKeyword;
        }
    }

    /// If the next token is of the expected kind, pop it and return true.
    /// Otherwise, return false and no-op.
    pub fn expectOptionalToken(self: *Parser, kind: TokenKind) !bool {
        const token = try self.peek();
        if (token.kind == kind) {
            _ = try self.pop();
            return true;
        }
        return false;
    }

    /// Expect the next token is a given kind. If it's not, throw an error.
    pub fn expect(self: *Parser, kind: TokenKind) !Token {
        const token = try self.peek();
        if (token.kind != kind) {
            return error.UnexpectedToken;
        }
        _ = try self.pop();
        return token;
    }

    /// Parse the entire document and return the top level `DocumentNode`.
    /// This is the main entry point for parsing GraphQL text.
    pub fn parse(self: *Parser) !ast.DocumentNode {
        const doc = try document.parseDocument(self);
        return doc;
    }
};

fn nextNonIgnorableToken(lexer: *Lexer) !Token {
    while (true) {
        const token = try lexer.read();
        switch (token.kind) {
            TokenKind.Comment, TokenKind.Whitespace, TokenKind.Comma => {
                // Ignore comments and whitespace.
                continue;
            },
            else => return token,
        }
    }
    // unreachable;
}

/// Parse the given GraphQL source text into an AST representation, using the given allocator.
pub fn parse(allocator: std.mem.Allocator, source: []const u8) !ast.DocumentNode {
    var parser = Parser.init(allocator, source);
    return parser.parse();
}

/// Parse the given GraphQL source text with a limit on the number of tokens that can be scanned.
/// This is useful for bounded parsing to prevent excessive memory usage or infinite loops.
pub fn parseWithLimit(allocator: std.mem.Allocator, source: []const u8, limit: usize) !ast.DocumentNode {
    var parser = Parser.init(allocator, source).withLimit(limit);
    return parser.parse();
}

//
// Test cases for the Parser
//

test "should parse a operation definition with a single field" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source = "{ user { id } }";
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    try std.testing.expect(doc.definitions.len == 1);
    const dn = doc.definitions[0];

    try std.testing.expect(dn == ast.DefinitionNode.ExecutableDefinition);
    const def = dn.ExecutableDefinition;

    try std.testing.expect(def == ast.ExecutableDefinitionNode.OperationDefinition);
    const op = def.OperationDefinition;

    try std.testing.expect(op.selection_set != null);
    try std.testing.expect(op.selection_set.?.selections.len == 1);
    const sel = op.selection_set.?.selections[0];

    try std.testing.expect(sel == ast.SelectionNode.Field);
    const f = sel.Field;
    try std.testing.expect(std.mem.eql(u8, f.name.value, "user"));
    try std.testing.expect(f.alias == null);
    try std.testing.expect(f.arguments == null);
    try std.testing.expect(f.selection_set != null);
    try std.testing.expect(f.selection_set.?.selections.len == 1);

    const sub_sel = f.selection_set.?.selections[0];
    try std.testing.expect(sub_sel == ast.SelectionNode.Field);
    const sub_f = sub_sel.Field;
    try std.testing.expect(std.mem.eql(u8, sub_f.name.value, "id"));
    try std.testing.expect(sub_f.alias == null);
    try std.testing.expect(sub_f.arguments == null);
    try std.testing.expect(sub_f.selection_set == null);
}

test "should parse a query operation with a single field" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ query {
        \\  users(id: 1) {
        \\   id
        \\  }
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    try std.testing.expect(doc.definitions.len == 1);
    const dn = doc.definitions[0];

    try std.testing.expect(dn == ast.DefinitionNode.ExecutableDefinition);
    const def = dn.ExecutableDefinition;

    try std.testing.expect(def == ast.ExecutableDefinitionNode.OperationDefinition);
    const op = def.OperationDefinition;

    try std.testing.expect(op.selection_set != null);
    try std.testing.expect(op.selection_set.?.selections.len == 1);
    const sel = op.selection_set.?.selections[0];

    try std.testing.expect(sel == ast.SelectionNode.Field);
    const f = sel.Field;
    try std.testing.expect(std.mem.eql(u8, f.name.value, "users"));
    try std.testing.expect(f.alias == null);
    try std.testing.expect(f.arguments != null);
    try std.testing.expect(f.arguments.?.len == 1);
    try std.testing.expect(f.selection_set != null);
    try std.testing.expect(f.selection_set.?.selections.len == 1);

    const sub_sel = f.selection_set.?.selections[0];
    try std.testing.expect(sub_sel == ast.SelectionNode.Field);
    const sub_f = sub_sel.Field;
    try std.testing.expect(std.mem.eql(u8, sub_f.name.value, "id"));
    try std.testing.expect(sub_f.alias == null);
    try std.testing.expect(sub_f.arguments == null);
    try std.testing.expect(sub_f.selection_set == null);
}

test "should parse a query operation with fields and arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ query UserAndFriends($createdTime: DateTime) {
        \\   users(createdTime: $createdTime) {
        \\     id
        \\     friends {
        \\       id
        \\     }
        \\   }
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    try std.testing.expect(doc.definitions.len == 1);
    const dn = doc.definitions[0];

    try std.testing.expect(dn == ast.DefinitionNode.ExecutableDefinition);
    const def = dn.ExecutableDefinition;

    try std.testing.expect(def == ast.ExecutableDefinitionNode.OperationDefinition);
    const op = def.OperationDefinition;

    try std.testing.expect(op.selection_set != null);
    try std.testing.expect(op.selection_set.?.selections.len == 1);
    const sel = op.selection_set.?.selections[0];

    try std.testing.expect(sel == ast.SelectionNode.Field);
    const f = sel.Field;
    try std.testing.expect(std.mem.eql(u8, f.name.value, "users"));
    try std.testing.expect(f.alias == null);

    try std.testing.expect(f.arguments != null);
    try std.testing.expect(f.arguments.?.len == 1);
    const args = f.arguments.?;
    const arg = args[0];
    try std.testing.expect(std.mem.eql(u8, arg.name.value, "createdTime"));

    try std.testing.expect(arg.value == ast.ValueNode.Variable);
    const var_node = arg.value.Variable;
    try std.testing.expect(std.mem.eql(u8, var_node.name.value, "createdTime"));

    try std.testing.expect(f.selection_set != null);
    try std.testing.expect(f.selection_set.?.selections.len == 2);

    const sub_sel_one = f.selection_set.?.selections[0];
    try std.testing.expect(sub_sel_one == ast.SelectionNode.Field);
    const sub_f_one = sub_sel_one.Field;
    try std.testing.expect(std.mem.eql(u8, sub_f_one.name.value, "id"));
    try std.testing.expect(sub_f_one.alias == null);
    try std.testing.expect(sub_f_one.arguments == null);
    try std.testing.expect(sub_f_one.selection_set == null);

    const sub_sel_two = f.selection_set.?.selections[1];
    try std.testing.expect(sub_sel_two == ast.SelectionNode.Field);

    const sub_f_two = sub_sel_two.Field;
    try std.testing.expect(std.mem.eql(u8, sub_f_two.name.value, "friends"));
    try std.testing.expect(sub_f_two.alias == null);
    try std.testing.expect(sub_f_two.arguments == null);
    try std.testing.expect(sub_f_two.selection_set != null);
    try std.testing.expect(sub_f_two.selection_set.?.selections.len == 1);
}

test "should parse a query operation with descriptions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ """
        \\ The query description
        \\ """
        \\ type Query {
        \\   users(id: Int): User
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.TypeDefinition);

    const type_def = def.TypeDefinition;
    try std.testing.expect(type_def == ast.TypeDefinitionNode.ObjectTypeDefinition);

    const obj_def = type_def.ObjectTypeDefinition;
    try std.testing.expect(obj_def.description != null);
    try std.testing.expect(std.mem.eql(u8, obj_def.description.?.value, "\"\"\"\n The query description\n \"\"\""));
    try std.testing.expect(std.mem.eql(u8, obj_def.name.value, "Query"));
    try std.testing.expect(obj_def.interfaces == null);
    try std.testing.expect(obj_def.directives == null);
    try std.testing.expect(obj_def.fields != null);
    try std.testing.expect(obj_def.fields.?.len == 1);

    const fields = obj_def.fields.?;

    const field = fields[0];
    const named_type = field.type.NamedType;

    try std.testing.expect(std.mem.eql(u8, field.name.value, "users"));
    try std.testing.expect(std.mem.eql(u8, named_type.name.value, "User"));
    try std.testing.expect(field.arguments != null);
    try std.testing.expect(field.description == null);
    try std.testing.expect(field.directives == null);
    try std.testing.expect(field.type.NamedType.kind == ast.SyntaxKind.NamedType);
}

test "should parse a schema definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ schema {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.SchemaDefinition);

    const schema_def = def.SchemaDefinition;
    try std.testing.expect(schema_def.description == null);
    try std.testing.expect(schema_def.directives == null);
    try std.testing.expect(schema_def.operation_types.len == 2);

    const operation_types = schema_def.operation_types;
    try std.testing.expect(operation_types[0].operation == ast.OperationType.Query);
    try std.testing.expect(std.mem.eql(u8, operation_types[0].type.name.value, "Query"));
    try std.testing.expect(operation_types[1].operation == ast.OperationType.Mutation);
    try std.testing.expect(std.mem.eql(u8, operation_types[1].type.name.value, "Mutation"));
}

test "should parse a schema definition with directives" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ schema @directive {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.SchemaDefinition);

    const schema_def = def.SchemaDefinition;

    try std.testing.expect(schema_def.description == null);
    try std.testing.expect(schema_def.directives != null);
    try std.testing.expect(schema_def.directives.?.len == 1);
}

test "should parse a scalar type definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ scalar DateTime
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.TypeDefinition);

    const type_def = def.TypeDefinition;
    try std.testing.expect(type_def == ast.TypeDefinitionNode.ScalarTypeDefinition);

    const scalar_def = type_def.ScalarTypeDefinition;
    try std.testing.expect(std.mem.eql(u8, scalar_def.name.value, "DateTime"));
}

test "should parse a type definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ type User {
        \\   id: ID
        \\   name: String
        \\   friends: [User]
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.TypeDefinition);

    const type_def = def.TypeDefinition;
    try std.testing.expect(type_def == ast.TypeDefinitionNode.ObjectTypeDefinition);

    const obj_def = type_def.ObjectTypeDefinition;
    try std.testing.expect(obj_def.description == null);
    try std.testing.expect(std.mem.eql(u8, obj_def.name.value, "User"));
    try std.testing.expect(obj_def.interfaces == null);
    try std.testing.expect(obj_def.directives == null);

    try std.testing.expect(obj_def.fields != null);
    try std.testing.expect(obj_def.fields.?.len == 3);
    try std.testing.expect(std.mem.eql(u8, obj_def.fields.?[0].name.value, "id"));
    try std.testing.expect(std.mem.eql(u8, obj_def.fields.?[1].name.value, "name"));
    try std.testing.expect(std.mem.eql(u8, obj_def.fields.?[2].name.value, "friends"));
}

test "should parse a interface type definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ interface User {
        \\   id: ID
        \\   name: String
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.TypeDefinition);

    const type_def = def.TypeDefinition;
    try std.testing.expect(type_def == ast.TypeDefinitionNode.InterfaceTypeDefinition);

    const obj_def = type_def.InterfaceTypeDefinition;
    try std.testing.expect(obj_def.description == null);
    try std.testing.expect(std.mem.eql(u8, obj_def.name.value, "User"));
    try std.testing.expect(obj_def.interfaces == null);
    try std.testing.expect(obj_def.directives == null);
}

test "should parse a union type definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ union SearchResult = User | Post | Comment
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.TypeDefinition);

    const type_def = def.TypeDefinition;
    try std.testing.expect(type_def == ast.TypeDefinitionNode.UnionTypeDefinition);

    const obj_def = type_def.UnionTypeDefinition;
    try std.testing.expect(obj_def.description == null);
    try std.testing.expect(std.mem.eql(u8, obj_def.name.value, "SearchResult"));
}

test "should parse a enum type definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ enum UserType {
        \\   GUEST
        \\   REGISTERED
        \\   ADMIN
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.TypeDefinition);

    const type_def = def.TypeDefinition;
    try std.testing.expect(type_def == ast.TypeDefinitionNode.EnumTypeDefinition);

    const obj_def = type_def.EnumTypeDefinition;
    try std.testing.expect(obj_def.description == null);
    try std.testing.expect(std.mem.eql(u8, obj_def.name.value, "UserType"));

    try std.testing.expect(obj_def.values != null);
    try std.testing.expect(obj_def.values.?.len == 3);

    const values = obj_def.values.?;
    try std.testing.expect(std.mem.eql(u8, values[0].name.value, "GUEST"));
    try std.testing.expect(std.mem.eql(u8, values[1].name.value, "REGISTERED"));
    try std.testing.expect(std.mem.eql(u8, values[2].name.value, "ADMIN"));
}

test "should parse a input type definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ input UserInput {
        \\   id: ID
        \\   name: String
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.TypeDefinition);

    const type_def = def.TypeDefinition;
    try std.testing.expect(type_def == ast.TypeDefinitionNode.InputObjectTypeDefinition);

    const obj_def = type_def.InputObjectTypeDefinition;
    try std.testing.expect(obj_def.description == null);
    try std.testing.expect(std.mem.eql(u8, obj_def.name.value, "UserInput"));

    try std.testing.expect(obj_def.directives == null);
    try std.testing.expect(obj_def.fields != null);
    try std.testing.expect(obj_def.fields.?.len == 2);

    const fields = obj_def.fields.?;
    try std.testing.expect(std.mem.eql(u8, fields[0].name.value, "id"));
    try std.testing.expect(std.mem.eql(u8, fields[1].name.value, "name"));
}

test "should parse a directive definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ directive @auth on FIELD_DEFINITION
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.DirectiveDefinition);

    const dir_def = def.DirectiveDefinition;
    try std.testing.expect(dir_def.description == null);
    try std.testing.expect(std.mem.eql(u8, dir_def.name.value, "auth"));
}

test "should parse a directive definition with arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ directive @deprecated(
        \\   reason: String = "No longer supported"
        \\   removeDate: String
        \\ ) on FIELD_DEFINITION | ENUM_VALUE
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == ast.TypeSystemDefinitionNode.DirectiveDefinition);

    const dir_def = def.DirectiveDefinition;
    try std.testing.expect(dir_def.description == null);
    try std.testing.expect(std.mem.eql(u8, dir_def.name.value, "deprecated"));

    // Verify arguments are parsed correctly (this is the bug fix verification)
    try std.testing.expect(dir_def.arguments != null);
    try std.testing.expect(dir_def.arguments.?.len == 2);

    const args = dir_def.arguments.?;
    try std.testing.expect(std.mem.eql(u8, args[0].name.value, "reason"));
    try std.testing.expect(args[0].type.* == ast.TypeNode.NamedType);
    try std.testing.expect(std.mem.eql(u8, args[0].type.*.NamedType.name.value, "String"));
    try std.testing.expect(args[0].default_value != null);

    try std.testing.expect(std.mem.eql(u8, args[1].name.value, "removeDate"));
    try std.testing.expect(args[1].type.* == ast.TypeNode.NamedType);
    try std.testing.expect(std.mem.eql(u8, args[1].type.*.NamedType.name.value, "String"));
    try std.testing.expect(args[1].default_value == null);

    // Verify repeatable is false
    try std.testing.expect(dir_def.repeatable == false);

    // Verify locations
    try std.testing.expect(dir_def.locations.len == 2);
    try std.testing.expect(std.mem.eql(u8, dir_def.locations[0].value, "FIELD_DEFINITION"));
    try std.testing.expect(std.mem.eql(u8, dir_def.locations[1].value, "ENUM_VALUE"));
}

test "should parse a fragment definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ fragment UserFragment on User {
        \\   id
        \\   name
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.ExecutableDefinition);

    const def = dn.ExecutableDefinition;
    try std.testing.expect(def == ast.ExecutableDefinitionNode.FragmentDefinition);

    const frag_def = def.FragmentDefinition;
    try std.testing.expect(std.mem.eql(u8, frag_def.name.value, "UserFragment"));

    try std.testing.expect(std.mem.eql(u8, frag_def.type_condition.name.value, "User"));
    try std.testing.expect(frag_def.selection_set.selections.len == 2);

    const sel_one = frag_def.selection_set.selections[0];
    try std.testing.expect(sel_one == ast.SelectionNode.Field);

    const f_one = sel_one.Field;
    try std.testing.expect(std.mem.eql(u8, f_one.name.value, "id"));

    const sel_two = frag_def.selection_set.selections[1];
    try std.testing.expect(sel_two == ast.SelectionNode.Field);

    const f_two = sel_two.Field;
    try std.testing.expect(std.mem.eql(u8, f_two.name.value, "name"));
}

test "should parse a schema extension" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ extend schema @directive {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == ast.DefinitionNode.TypeSystemExtension);

    const def = dn.TypeSystemExtension;
    try std.testing.expect(def == ast.TypeSystemExtensionNode.SchemaExtension);
    const schema_ext = def.SchemaExtension;

    try std.testing.expect(schema_ext.directives != null);
    try std.testing.expect(schema_ext.directives.?.len == 1);
    try std.testing.expect(std.mem.eql(u8, schema_ext.directives.?[0].name.value, "directive"));

    try std.testing.expect(schema_ext.operation_types != null);
    try std.testing.expect(schema_ext.operation_types.?.len == 2);
    try std.testing.expect(std.mem.eql(u8, schema_ext.operation_types.?[0].type.name.value, "Query"));
    try std.testing.expect(std.mem.eql(u8, schema_ext.operation_types.?[1].type.name.value, "Mutation"));
    try std.testing.expect(schema_ext.operation_types.?[0].operation == ast.OperationType.Query);
    try std.testing.expect(schema_ext.operation_types.?[1].operation == ast.OperationType.Mutation);
}

test "should parse nested types like [String!]" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\type Post {
        \\  tags: [String!]!
        \\}
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    const def = doc.definitions[0].TypeSystemDefinition.TypeDefinition.ObjectTypeDefinition;
    const tag_field = def.fields.?[0];

    try std.testing.expect(tag_field.type.* == ast.TypeNode.NonNullType); // !
    try std.testing.expect(tag_field.type.*.NonNullType.type.* == ast.TypeNode.ListType); // []
    try std.testing.expect(tag_field.type.*.NonNullType.type.*.ListType.type.* == ast.TypeNode.NonNullType); // !
    try std.testing.expect(tag_field.type.*.NonNullType.type.*.ListType.type.*.NonNullType.type.* == ast.TypeNode.NamedType); // String
    try std.testing.expect(std.mem.eql(u8, tag_field.type.*.NonNullType.type.*.ListType.type.*.NonNullType.type.*.NamedType.name.value, "String"));
}

test "should parse a field with a single directive without arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ query {
        \\   user @deprecated {
        \\     id
        \\   }
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    try std.testing.expect(doc.definitions.len == 1);
    const op = doc.definitions[0].ExecutableDefinition.OperationDefinition;
    const field = op.selection_set.?.selections[0].Field;

    try std.testing.expect(std.mem.eql(u8, field.name.value, "user"));
    try std.testing.expect(field.directives != null);
    try std.testing.expect(field.directives.?.len == 1);

    const directive = field.directives.?[0];
    try std.testing.expect(std.mem.eql(u8, directive.name.value, "deprecated"));
    try std.testing.expect(directive.arguments == null);
}

test "should parse a field with a directive with arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ query {
        \\   user @deprecated(reason: "Use newUser instead") {
        \\     id
        \\   }
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    const op = doc.definitions[0].ExecutableDefinition.OperationDefinition;
    const field = op.selection_set.?.selections[0].Field;

    try std.testing.expect(field.directives != null);
    try std.testing.expect(field.directives.?.len == 1);

    const directive = field.directives.?[0];
    try std.testing.expect(std.mem.eql(u8, directive.name.value, "deprecated"));
    try std.testing.expect(directive.arguments != null);
    try std.testing.expect(directive.arguments.?.len == 1);

    const arg = directive.arguments.?[0];
    try std.testing.expect(std.mem.eql(u8, arg.name.value, "reason"));
    try std.testing.expect(arg.value == ast.ValueNode.String);
    try std.testing.expect(std.mem.eql(u8, arg.value.String.value, "\"Use newUser instead\""));
}

test "should parse directives on type definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ type User @auth @cached(ttl: 300) {
        \\   id: ID
        \\   name: String
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    const obj_def = doc.definitions[0].TypeSystemDefinition.TypeDefinition.ObjectTypeDefinition;

    try std.testing.expect(obj_def.directives != null);
    try std.testing.expect(obj_def.directives.?.len == 2);

    const dir_one = obj_def.directives.?[0];
    try std.testing.expect(std.mem.eql(u8, dir_one.name.value, "auth"));
    try std.testing.expect(dir_one.arguments == null);

    const dir_two = obj_def.directives.?[1];
    try std.testing.expect(std.mem.eql(u8, dir_two.name.value, "cached"));
    try std.testing.expect(dir_two.arguments != null);
    try std.testing.expect(dir_two.arguments.?.len == 1);
}

test "should parse directives on field definition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ type User {
        \\   email: String @deprecated(reason: "Use emailAddress")
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    const obj_def = doc.definitions[0].TypeSystemDefinition.TypeDefinition.ObjectTypeDefinition;
    const field = obj_def.fields.?[0];

    try std.testing.expect(std.mem.eql(u8, field.name.value, "email"));
    try std.testing.expect(field.directives != null);
    try std.testing.expect(field.directives.?.len == 1);

    const directive = field.directives.?[0];
    try std.testing.expect(std.mem.eql(u8, directive.name.value, "deprecated"));
    try std.testing.expect(directive.arguments != null);
    try std.testing.expect(directive.arguments.?.len == 1);
    try std.testing.expect(std.mem.eql(u8, directive.arguments.?[0].name.value, "reason"));
}

test "should parse query mixed type definitions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ query Foo {
        \\   user {
        \\     name
        \\   }
        \\ }
        \\ type User {
        \\   name: String
        \\ }
        \\ extend type Guest {
        \\   role: String
        \\ }
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 3);

    const operation_def = doc.definitions[0].ExecutableDefinition.OperationDefinition;
    try std.testing.expect(std.mem.eql(u8, operation_def.name.?.value, "Foo"));

    const type_def = doc.definitions[1].TypeSystemDefinition.TypeDefinition;
    try std.testing.expect(std.mem.eql(u8, type_def.ObjectTypeDefinition.name.value, "User"));

    const type_ext = doc.definitions[2].TypeSystemExtension.TypeExtension;
    try std.testing.expect(std.mem.eql(u8, type_ext.ObjectTypeExtension.name.value, "Guest"));
}

test "should return error when limit is reached" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const source = "{ user { id } }";
    var parser = Parser.init(arena.allocator(), source);
    var bounded = parser.withLimit(11);

    const result = bounded.parse();
    try std.testing.expectError(error.LimitReached, result);
}

test "should parse simple query with public parse function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const source = "{ user { id } }";
    const doc = try parse(arena.allocator(), source);

    try std.testing.expect(doc.definitions.len == 1);
}

test "should parse simple query with public parseWithLimit function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const source = "{ user { id } }";
    const doc = try parseWithLimit(arena.allocator(), source, 12);

    try std.testing.expect(doc.definitions.len == 1);
}

test "should return error when limit is reached using parseWithLimit function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const source = "{ user { id } }";
    const result = parseWithLimit(arena.allocator(), source, 11);

    try std.testing.expectError(error.LimitReached, result);
}
