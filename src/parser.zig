const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("lib/tokens.zig").Token;
const TokenKind = @import("lib/tokens.zig").TokenKind;
const ast = @import("grammar/ast.zig");
const config = @import("config.zig");
const document = @import("grammar/document.zig");

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
    currentToken: ?Token,

    /// Debug function to print the parser state.
    pub const debug = if (config.debug) printDebug else noopDebug;

    /// Initializes a new `Parser` from source text.
    /// The `Lexer` is set up with the given source, and no token is loaded... yet.
    pub fn init(allocator: std.mem.Allocator, source: []const u8) Parser {
        return Parser{
            .allocator = allocator,
            .lexer = Lexer.init(source),
            .currentToken = null,
        };
    }

    /// Initializes a new `Parser` with a `Lexer` that has a limit on how far
    /// it can look ahead in the token stream. Useful for bounded parsing.
    pub fn withLimit(self: Parser, limit: usize) Parser {
        return Parser{
            .allocator = self.allocator,
            .currentToken = self.currentToken,
            .lexer = self.lexer.withLimit(limit),
        };
    }

    /// Next non-ignorable token from the `Lexer`.
    pub fn nextToken(self: *Parser) ?Token {
        return nextNonIgnorableToken(&self.lexer);
    }

    /// Lookahead at the next non-ignorable token without advancing the `Lexer`.
    /// This is done by cloning the `Lexer` and scanning ahead.
    pub fn lookahead(self: *Parser) ?Token {
        // TODO: Inefficient, refactor the lexer/cursor to allow lookahead without cloning.
        var lexer = self.lexer;
        return nextNonIgnorableToken(&lexer);
    }

    /// Peek the next token from the `Lexer`.
    /// This will load the next token until it is popped.
    pub fn peek(self: *Parser) ?Token {
        if (self.currentToken == null) {
            self.currentToken = self.nextToken();
        }
        return self.currentToken;
    }

    /// Peek and check if the next token is of a given kind.
    pub fn peekKind(self: *Parser, kind: TokenKind) bool {
        const token = self.peek() orelse return false;
        return (token.kind == kind);
    }

    /// Pop the current token and reset the peeked state.
    pub fn pop(self: *Parser) ?Token {
        const token = self.peek();
        self.currentToken = null;
        return token;
    }

    /// If the next token is a given keyword and matches the expected keyword,
    /// pop it and return true. Otherwise, return false and no-op.
    pub fn expectOptionalKeyword(self: *Parser, keyword: ast.SyntaxKeyWord) !bool {
        const token = self.peek() orelse return error.UnexpectedNullToken; // TODO: comeback and use try once peek starts throwing token errors.
        const tkw = ast.stringToKeyword(token.data) orelse return false;
        if (token.kind == TokenKind.Name and tkw == keyword) {
            _ = self.pop();
            return true;
        }
        return false;
    }

    /// Expect the next token is a given keyword. If it's not there, throw an error.
    pub fn expectKeyword(self: *Parser, keyword: ast.SyntaxKeyWord) !void {
        const token = self.peek() orelse return error.UnexpectedNullToken;
        const tkw = ast.stringToKeyword(token.data) orelse return error.UnknownKeyword;
        if (token.kind == TokenKind.Name and tkw == keyword) {
            _ = self.pop();
        } else {
            return error.UnexpectedKeyword;
        }
    }

    /// If the next token is of the expected kind, pop it and return true.
    /// Otherwise, return false and no-op.
    pub fn expectOptionalToken(self: *Parser, kind: TokenKind) !bool {
        const token = self.peek() orelse return error.UnexpectedNullToken; // TODO: comeback and use try once peek starts throwing token errors.
        if (token.kind == kind) {
            _ = self.pop();
            return true;
        }
        return false;
    }

    /// Expect the next token is a given kind. If it's not, throw an error.
    pub fn expect(self: *Parser, kind: TokenKind) !Token {
        const token = self.peek() orelse return error.UnexpectedNullToken;
        if (token.kind != kind) {
            return error.UnexpectedToken;
        }
        _ = self.pop();
        return token;
    }

    /// Parse the entire document and return the top level `DocumentNode`.
    /// This is the main entry point for parsing GraphQL text.
    pub fn parse(self: *Parser) !ast.DocumentNode {
        const doc = try document.parseDocument(self);
        return doc;
    }
};

fn nextNonIgnorableToken(lexer: *Lexer) ?Token {
    while (true) {
        // TODO: Until errors are refactored, the lexer will return null on error.
        // Which will be caught in the parsing, but will produce UnexpectedNullToken instead
        // of the token error.
        const result = lexer.next() catch return null;
        const token = result orelse return null;
        switch (token.kind) {
            TokenKind.Comment, TokenKind.Whitespace, TokenKind.Comma => {
                // Ignore comments and whitespace.
                continue;
            },
            else => return token,
        }
    }
    return null;
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

    try std.testing.expect(op.selectionSet != null);
    try std.testing.expect(op.selectionSet.?.selections.len == 1);
    const sel = op.selectionSet.?.selections[0];

    try std.testing.expect(sel == ast.SelectionNode.Field);
    const f = sel.Field;
    try std.testing.expect(std.mem.eql(u8, f.name.value, "user"));
    try std.testing.expect(f.alias == null);
    try std.testing.expect(f.arguments == null);
    try std.testing.expect(f.selectionSet != null);
    try std.testing.expect(f.selectionSet.?.selections.len == 1);

    const subSel = f.selectionSet.?.selections[0];
    try std.testing.expect(subSel == ast.SelectionNode.Field);
    const subF = subSel.Field;
    try std.testing.expect(std.mem.eql(u8, subF.name.value, "id"));
    try std.testing.expect(subF.alias == null);
    try std.testing.expect(subF.arguments == null);
    try std.testing.expect(subF.selectionSet == null);
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

    try std.testing.expect(op.selectionSet != null);
    try std.testing.expect(op.selectionSet.?.selections.len == 1);
    const sel = op.selectionSet.?.selections[0];

    try std.testing.expect(sel == ast.SelectionNode.Field);
    const f = sel.Field;
    try std.testing.expect(std.mem.eql(u8, f.name.value, "users"));
    try std.testing.expect(f.alias == null);
    try std.testing.expect(f.arguments != null);
    try std.testing.expect(f.arguments.?.len == 1);
    try std.testing.expect(f.selectionSet != null);
    try std.testing.expect(f.selectionSet.?.selections.len == 1);

    const subSel = f.selectionSet.?.selections[0];
    try std.testing.expect(subSel == ast.SelectionNode.Field);
    const subF = subSel.Field;
    try std.testing.expect(std.mem.eql(u8, subF.name.value, "id"));
    try std.testing.expect(subF.alias == null);
    try std.testing.expect(subF.arguments == null);
    try std.testing.expect(subF.selectionSet == null);
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

    try std.testing.expect(op.selectionSet != null);
    try std.testing.expect(op.selectionSet.?.selections.len == 1);
    const sel = op.selectionSet.?.selections[0];

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
    const varNode = arg.value.Variable;
    try std.testing.expect(std.mem.eql(u8, varNode.name.value, "createdTime"));

    try std.testing.expect(f.selectionSet != null);
    try std.testing.expect(f.selectionSet.?.selections.len == 2);

    const subSelOne = f.selectionSet.?.selections[0];
    try std.testing.expect(subSelOne == ast.SelectionNode.Field);
    const subFOne = subSelOne.Field;
    try std.testing.expect(std.mem.eql(u8, subFOne.name.value, "id"));
    try std.testing.expect(subFOne.alias == null);
    try std.testing.expect(subFOne.arguments == null);
    try std.testing.expect(subFOne.selectionSet == null);

    const subSelTwo = f.selectionSet.?.selections[1];
    try std.testing.expect(subSelTwo == ast.SelectionNode.Field);

    const subFTwo = subSelTwo.Field;
    try std.testing.expect(std.mem.eql(u8, subFTwo.name.value, "friends"));
    try std.testing.expect(subFTwo.alias == null);
    try std.testing.expect(subFTwo.arguments == null);
    try std.testing.expect(subFTwo.selectionSet != null);
    try std.testing.expect(subFTwo.selectionSet.?.selections.len == 1);
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

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == ast.TypeDefinitionNode.ObjectTypeDefinition);

    const objDef = typeDef.ObjectTypeDefinition;
    try std.testing.expect(objDef.description != null);
    try std.testing.expect(std.mem.eql(u8, objDef.description.?.value, "\"\"\"\n The query description\n \"\"\""));
    try std.testing.expect(std.mem.eql(u8, objDef.name.value, "Query"));
    try std.testing.expect(objDef.interfaces == null);
    try std.testing.expect(objDef.directives == null);
    try std.testing.expect(objDef.fields != null);
    try std.testing.expect(objDef.fields.?.len == 1);

    const fields = objDef.fields.?;

    const field = fields[0];
    const namedType = field.type.NamedType;

    try std.testing.expect(std.mem.eql(u8, field.name.value, "users"));
    try std.testing.expect(std.mem.eql(u8, namedType.name.value, "User"));
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

    const schemaDef = def.SchemaDefinition;
    try std.testing.expect(schemaDef.description == null);
    try std.testing.expect(schemaDef.directives == null);
    try std.testing.expect(schemaDef.operationTypes.len == 2);

    const operationTypes = schemaDef.operationTypes;
    try std.testing.expect(operationTypes[0].operation == ast.OperationType.Query);
    try std.testing.expect(std.mem.eql(u8, operationTypes[0].type.name.value, "Query"));
    try std.testing.expect(operationTypes[1].operation == ast.OperationType.Mutation);
    try std.testing.expect(std.mem.eql(u8, operationTypes[1].type.name.value, "Mutation"));
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

    const schemaDef = def.SchemaDefinition;

    try std.testing.expect(schemaDef.description == null);
    try std.testing.expect(schemaDef.directives != null);
    try std.testing.expect(schemaDef.directives.?.len == 1);
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

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == ast.TypeDefinitionNode.ScalarTypeDefinition);

    const scalarDef = typeDef.ScalarTypeDefinition;
    try std.testing.expect(std.mem.eql(u8, scalarDef.name.value, "DateTime"));
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

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == ast.TypeDefinitionNode.ObjectTypeDefinition);

    const objDef = typeDef.ObjectTypeDefinition;
    try std.testing.expect(objDef.description == null);
    try std.testing.expect(std.mem.eql(u8, objDef.name.value, "User"));
    try std.testing.expect(objDef.interfaces == null);
    try std.testing.expect(objDef.directives == null);

    try std.testing.expect(objDef.fields != null);
    try std.testing.expect(objDef.fields.?.len == 3);
    try std.testing.expect(std.mem.eql(u8, objDef.fields.?[0].name.value, "id"));
    try std.testing.expect(std.mem.eql(u8, objDef.fields.?[1].name.value, "name"));
    try std.testing.expect(std.mem.eql(u8, objDef.fields.?[2].name.value, "friends"));
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

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == ast.TypeDefinitionNode.InterfaceTypeDefinition);

    const objDef = typeDef.InterfaceTypeDefinition;
    try std.testing.expect(objDef.description == null);
    try std.testing.expect(std.mem.eql(u8, objDef.name.value, "User"));
    try std.testing.expect(objDef.interfaces == null);
    try std.testing.expect(objDef.directives == null);
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

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == ast.TypeDefinitionNode.UnionTypeDefinition);

    const objDef = typeDef.UnionTypeDefinition;
    try std.testing.expect(objDef.description == null);
    try std.testing.expect(std.mem.eql(u8, objDef.name.value, "SearchResult"));
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

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == ast.TypeDefinitionNode.EnumTypeDefinition);

    const objDef = typeDef.EnumTypeDefinition;
    try std.testing.expect(objDef.description == null);
    try std.testing.expect(std.mem.eql(u8, objDef.name.value, "UserType"));

    try std.testing.expect(objDef.values != null);
    try std.testing.expect(objDef.values.?.len == 3);

    const values = objDef.values.?;
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

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == ast.TypeDefinitionNode.InputObjectTypeDefinition);

    const objDef = typeDef.InputObjectTypeDefinition;
    try std.testing.expect(objDef.description == null);
    try std.testing.expect(std.mem.eql(u8, objDef.name.value, "UserInput"));

    try std.testing.expect(objDef.directives == null);
    try std.testing.expect(objDef.fields != null);
    try std.testing.expect(objDef.fields.?.len == 2);

    const fields = objDef.fields.?;
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

    const dirDef = def.DirectiveDefinition;
    try std.testing.expect(dirDef.description == null);
    try std.testing.expect(std.mem.eql(u8, dirDef.name.value, "auth"));
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

    const fragDef = def.FragmentDefinition;
    try std.testing.expect(std.mem.eql(u8, fragDef.name.value, "UserFragment"));

    try std.testing.expect(std.mem.eql(u8, fragDef.typeCondition.name.value, "User"));
    try std.testing.expect(fragDef.selectionSet.selections.len == 2);

    const selOne = fragDef.selectionSet.selections[0];
    try std.testing.expect(selOne == ast.SelectionNode.Field);

    const fOne = selOne.Field;
    try std.testing.expect(std.mem.eql(u8, fOne.name.value, "id"));

    const selTwo = fragDef.selectionSet.selections[1];
    try std.testing.expect(selTwo == ast.SelectionNode.Field);

    const fTwo = selTwo.Field;
    try std.testing.expect(std.mem.eql(u8, fTwo.name.value, "name"));
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
    const schemaExt = def.SchemaExtension;

    try std.testing.expect(schemaExt.directives != null);
    try std.testing.expect(schemaExt.directives.?.len == 1);
    try std.testing.expect(std.mem.eql(u8, schemaExt.directives.?[0].name.value, "directive"));

    try std.testing.expect(schemaExt.operationTypes != null);
    try std.testing.expect(schemaExt.operationTypes.?.len == 2);
    try std.testing.expect(std.mem.eql(u8, schemaExt.operationTypes.?[0].type.name.value, "Query"));
    try std.testing.expect(std.mem.eql(u8, schemaExt.operationTypes.?[1].type.name.value, "Mutation"));
    try std.testing.expect(schemaExt.operationTypes.?[0].operation == ast.OperationType.Query);
    try std.testing.expect(schemaExt.operationTypes.?[1].operation == ast.OperationType.Mutation);
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
    const tagField = def.fields.?[0];

    try std.testing.expect(tagField.type.* == ast.TypeNode.NonNullType); // !
    try std.testing.expect(tagField.type.*.NonNullType.type.* == ast.TypeNode.ListType); // []
    try std.testing.expect(tagField.type.*.NonNullType.type.*.ListType.type.* == ast.TypeNode.NonNullType); // !
    try std.testing.expect(tagField.type.*.NonNullType.type.*.ListType.type.*.NonNullType.type.* == ast.TypeNode.NamedType); // String
    try std.testing.expect(std.mem.eql(u8, tagField.type.*.NonNullType.type.*.ListType.type.*.NonNullType.type.*.NamedType.name.value, "String"));
}
