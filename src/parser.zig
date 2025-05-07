const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("lib/tokens.zig").Token;
const TokenKind = @import("lib/tokens.zig").TokenKind;
const grammar = @import("lib/grammar.zig");
const config = @import("config.zig");

// Debugging functions to print the parser state
fn noopDebug(_: *Parser, _: []const u8) void {}
fn printDebug(p: *Parser, tag: []const u8) void {
    std.debug.print("{s}:\n", .{tag});
    std.debug.print("peek |{any}|\n", .{p.peek()});
}

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    currentToken: ?Token,

    pub const debug = if (config.debug) printDebug else noopDebug;

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Parser {
        return Parser{
            .allocator = allocator,
            .lexer = Lexer.init(source),
            .currentToken = null,
        };
    }

    pub fn withLimit(self: Parser, limit: usize) Parser {
        return Parser{
            .allocator = self.allocator,
            .currentToken = self.currentToken,
            .lexer = self.lexer.withLimit(limit),
        };
    }

    pub fn nextToken(self: *Parser) ?Token {
        return nextNonIgnorableToken(&self.lexer);
    }

    pub fn lookahead(self: *Parser) ?Token {
        var lexer = self.lexer;
        return nextNonIgnorableToken(&lexer);
    }

    // TODO: Should we throw an error if the token is null?
    // Or just return null and let the caller handle it?
    pub fn peek(self: *Parser) ?Token {
        if (self.currentToken == null) {
            self.currentToken = self.nextToken();
        }
        return self.currentToken;
    }

    pub fn peekKind(self: *Parser, kind: TokenKind) bool {
        const token = self.peek() orelse return false;
        return (token.kind == kind);
    }

    pub fn pop(self: *Parser) ?Token {
        const token = self.peek();
        self.currentToken = null;
        return token;
    }

    pub fn expectOptionalKeyword(self: *Parser, keyword: grammar.SyntaxKeyWord) bool {
        const token = self.peek() orelse return false;
        const tkw = grammar.stringToKeyword(token.data) orelse return false;
        if (token.kind == TokenKind.Name and tkw == keyword) {
            _ = self.pop();
            return true;
        }
        return false;
    }

    pub fn expectKeyword(self: *Parser, keyword: grammar.SyntaxKeyWord) !void {
        const token = self.peek() orelse return error.UnexpectedNullToken;
        const tkw = grammar.stringToKeyword(token.data) orelse return error.UnknownKeyword;
        if (token.kind == TokenKind.Name and tkw == keyword) {
            _ = self.pop();
        } else {
            return error.UnexpectedKeyword;
        }
    }

    pub fn expectOptionalToken(self: *Parser, kind: TokenKind) bool {
        const token = self.peek() orelse return true;
        if (token.kind == kind) {
            _ = self.pop();
            return true;
        }
        return false;
    }

    pub fn expect(self: *Parser, kind: TokenKind) !Token {
        const token = self.peek() orelse return error.UnexpectedNullToken;
        if (token.kind != kind) {
            return error.UnexpectedToken;
        }
        _ = self.pop();
        return token;
    }

    pub fn parse(self: *Parser) !grammar.DocumentNode {
        return self.parseDocument();
    }

    pub fn parseDocument(self: *Parser) !grammar.DocumentNode {
        self.debug("parseDocument");
        const definitions = try self.parseDefinitions();
        const node = grammar.DocumentNode{
            .kind = grammar.SyntaxKind.Document,
            .definitions = definitions,
        };
        return node;
    }

    pub fn parseDefinitions(self: *Parser) ![]grammar.DefinitionNode {
        self.debug("parseDefinitions");
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, figure out a zig way reduce this.
        var nodes = std.ArrayList(grammar.DefinitionNode).init(self.allocator);
        defer nodes.deinit();

        while (self.peek()) |_| {
            const def = try self.parseDefinition();
            try nodes.append(def);

            if (self.expectOptionalToken(TokenKind.Eof)) {
                break;
            }
        }
        return try nodes.toOwnedSlice();
    }

    pub fn parseDefinition(self: *Parser) !grammar.DefinitionNode {
        self.debug("parseDefinition");
        var token = self.peek() orelse return error.UnexpectedNullToken;
        if (token.kind == TokenKind.StringValue) {
            token = self.lookahead() orelse return error.UnexpectedNullToken;
        }

        const keyword = grammar.stringToKeyword(token.data) orelse return error.UnknownKeyword;
        switch (keyword) {
            grammar.SyntaxKeyWord.schema => {
                const def = try self.parseSchemaDefinition();
                return grammar.DefinitionNode{
                    .TypeSystemDefinition = grammar.TypeSystemDefinitionNode{
                        .SchemaDefinition = def,
                    },
                };
            },
            grammar.SyntaxKeyWord.scalar => {
                const def = try self.parseScalarTypeDefinition();
                return grammar.DefinitionNode{
                    .TypeSystemDefinition = grammar.TypeSystemDefinitionNode{
                        .TypeDefinition = grammar.TypeDefinitionNode{
                            .ScalarTypeDefinition = def,
                        },
                    },
                };
            },
            grammar.SyntaxKeyWord.type => {
                const def = try self.parseObjectTypeDefinition();
                return grammar.DefinitionNode{
                    .TypeSystemDefinition = grammar.TypeSystemDefinitionNode{
                        .TypeDefinition = grammar.TypeDefinitionNode{
                            .ObjectTypeDefinition = def,
                        },
                    },
                };
            },
            grammar.SyntaxKeyWord.interface => {
                const def = try self.parseInterfaceTypeDefinition();
                return grammar.DefinitionNode{
                    .TypeSystemDefinition = grammar.TypeSystemDefinitionNode{
                        .TypeDefinition = grammar.TypeDefinitionNode{
                            .InterfaceTypeDefinition = def,
                        },
                    },
                };
            },
            grammar.SyntaxKeyWord.@"union" => {
                const def = try self.parseUnionTypeDefinition();
                return grammar.DefinitionNode{
                    .TypeSystemDefinition = grammar.TypeSystemDefinitionNode{
                        .TypeDefinition = grammar.TypeDefinitionNode{
                            .UnionTypeDefinition = def,
                        },
                    },
                };
            },
            grammar.SyntaxKeyWord.@"enum" => {
                const def = try self.parseEnumTypeDefinition();
                return grammar.DefinitionNode{
                    .TypeSystemDefinition = grammar.TypeSystemDefinitionNode{
                        .TypeDefinition = grammar.TypeDefinitionNode{
                            .EnumTypeDefinition = def,
                        },
                    },
                };
            },
            grammar.SyntaxKeyWord.input => {
                const def = try self.parseInputObjectTypeDefinition();
                return grammar.DefinitionNode{
                    .TypeSystemDefinition = grammar.TypeSystemDefinitionNode{
                        .TypeDefinition = grammar.TypeDefinitionNode{
                            .InputObjectTypeDefinition = def,
                        },
                    },
                };
            },
            grammar.SyntaxKeyWord.directive => {
                const def = try self.parseDirectiveDefinition();
                return grammar.DefinitionNode{
                    .TypeSystemDefinition = grammar.TypeSystemDefinitionNode{ .DirectiveDefinition = def },
                };
            },
            grammar.SyntaxKeyWord.query, grammar.SyntaxKeyWord.mutation, grammar.SyntaxKeyWord.subscription, grammar.SyntaxKeyWord.@"{" => {
                const def = try self.parseOperationDefinition();
                return grammar.DefinitionNode{
                    .ExecutableDefinition = grammar.ExecutableDefinitionNode{
                        .OperationDefinition = def,
                    },
                };
            },
            grammar.SyntaxKeyWord.fragment => {
                const def = try self.parseFragmentDefinition();
                return grammar.DefinitionNode{
                    .ExecutableDefinition = grammar.ExecutableDefinitionNode{
                        .FragmentDefinition = def,
                    },
                };
            },
            grammar.SyntaxKeyWord.extend => {
                const def = try self.parseTypeSystemExtension();
                return grammar.DefinitionNode{
                    .TypeSystemExtension = def,
                };
            },
            else => {
                return error.UnexpectedToken;
            },
        }
    }

    pub fn parseSchemaDefinition(self: *Parser) !grammar.SchemaDefinitionNode {
        self.debug("parseSchemaDefinition");
        const description = try self.parseDescription();
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.schema);
        const directives = try self.parseConstDirectives();
        const operationTypes = try self.parseOperationTypeDefinitions();
        return grammar.SchemaDefinitionNode{
            .description = description,
            .directives = directives,
            .operationTypes = operationTypes,
        };
    }

    pub fn parseScalarTypeDefinition(self: *Parser) !grammar.ScalarTypeDefinitionNode {
        self.debug("parseScalarTypeDefinition");
        const description = try self.parseDescription();
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.scalar);
        const name = try self.parseName();
        const directives = try self.parseConstDirectives();
        return grammar.ScalarTypeDefinitionNode{
            .description = description,
            .name = name,
            .directives = directives,
        };
    }

    pub fn parseObjectTypeDefinition(self: *Parser) !grammar.ObjectTypeDefinitionNode {
        self.debug("parseObjectTypeDefinition");
        const description = try self.parseDescription();
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.type);

        const name = try self.parseName();
        const interfaces = try self.parseImplementsInterfaces();
        const directives = try self.parseConstDirectives();
        const fields = try self.parseFieldsDefinition();

        return grammar.ObjectTypeDefinitionNode{
            .kind = grammar.SyntaxKind.ObjectTypeDefinition,
            .description = description,
            .name = name,
            .interfaces = interfaces,
            .directives = directives,
            .fields = fields,
        };
    }

    pub fn parseInterfaceTypeDefinition(self: *Parser) !grammar.InterfaceTypeDefinitionNode {
        self.debug("parseInterfaceTypeDefinition");
        const description = try self.parseDescription();
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.interface);
        const name = try self.parseName();
        const interfaces = try self.parseImplementsInterfaces();
        const directives = try self.parseConstDirectives();
        const fields = try self.parseFieldsDefinition();

        return grammar.InterfaceTypeDefinitionNode{
            .kind = grammar.SyntaxKind.InterfaceTypeDefinition,
            .description = description,
            .name = name,
            .interfaces = interfaces,
            .directives = directives,
            .fields = fields,
        };
    }

    pub fn parseUnionTypeDefinition(self: *Parser) !grammar.UnionTypeDefinitionNode {
        self.debug("parseUnionTypeDefinition");
        const description = try self.parseDescription();
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.@"union");
        const name = try self.parseName();
        const directives = try self.parseConstDirectives();
        const types = try self.parseUnionMemberTypes();

        return grammar.UnionTypeDefinitionNode{
            .description = description,
            .name = name,
            .directives = directives,
            .types = types,
        };
    }

    pub fn parseEnumTypeDefinition(self: *Parser) !grammar.EnumTypeDefinitionNode {
        self.debug("parseEnumTypeDefinition");
        const description = try self.parseDescription();
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.@"enum");
        const name = try self.parseName();
        const directives = try self.parseConstDirectives();
        const values = try self.parseEnumValuesDefinitions();

        return grammar.EnumTypeDefinitionNode{
            .description = description,
            .name = name,
            .directives = directives,
            .values = values,
        };
    }

    pub fn parseInputObjectTypeDefinition(self: *Parser) !grammar.InputObjectTypeDefinitionNode {
        self.debug("parseInputObjectTypeDefinition");
        const description = try self.parseDescription();
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.input);
        const name = try self.parseName();
        const directives = try self.parseConstDirectives();
        const fields = try self.parseInputFieldsDefinition();

        return grammar.InputObjectTypeDefinitionNode{
            .description = description,
            .name = name,
            .directives = directives,
            .fields = fields,
        };
    }

    pub fn parseDirectiveDefinition(self: *Parser) !grammar.DirectiveDefinitionNode {
        self.debug("parseDirectiveDefinition");
        const description = try self.parseDescription();
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.directive);
        _ = try self.expect(TokenKind.At);

        const name = try self.parseName();
        const args = try self.parseInputFieldsDefinition();
        const repeatable = self.expectOptionalKeyword(grammar.SyntaxKeyWord.repeatable);
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.on);

        const locations = try self.parseDirectiveLocations();
        return grammar.DirectiveDefinitionNode{
            .description = description,
            .name = name,
            .arguments = args,
            .repeatable = repeatable,
            .locations = locations,
        };
    }

    pub fn parseOperationDefinition(self: *Parser) !grammar.OperationDefinitionNode {
        self.debug("parseOperationDefinition");
        const token = self.peek() orelse return error.UnexpectedNullToken;
        if (token.kind == TokenKind.LCurly) {
            const selectionSet = try self.parseSelectionSet();
            return grammar.OperationDefinitionNode{
                .operation = grammar.OperationType.Query,
                .name = null,
                .variableDefinitions = null,
                .directives = null,
                .selectionSet = selectionSet,
            };
        }

        const operation = try self.parseOperationType();
        var name: ?grammar.NameNode = null;
        if (self.peekKind(TokenKind.Name)) {
            name = try self.parseName();
        }

        const varDefs = try self.parseVariableDefinitions();
        const dirs = try self.parseDirectives(false);
        const selSet = try self.parseSelectionSet();

        return grammar.OperationDefinitionNode{
            .operation = operation,
            .name = name,
            .variableDefinitions = varDefs,
            .directives = dirs,
            .selectionSet = selSet,
        };
    }

    pub fn parseFragmentDefinition(self: *Parser) !grammar.FragmentDefinitionNode {
        self.debug("parseFragmentDefinition");
        try self.expectKeyword(grammar.SyntaxKeyWord.fragment);

        const name = try self.parseFragmentName();

        try self.expectKeyword(grammar.SyntaxKeyWord.on);
        const typeCondition = try self.parseNamedType();
        const directives = try self.parseDirectives(false);
        const selectionSet = try self.parseSelectionSet();

        return grammar.FragmentDefinitionNode{
            .name = name,
            .typeCondition = typeCondition,
            .directives = directives,
            .selectionSet = selectionSet,
        };
    }

    pub fn parseTypeSystemExtension(self: *Parser) !grammar.TypeSystemExtensionNode {
        self.debug("parseTypeSystemExtension");
        const token = self.lookahead() orelse return error.UnexpectedNullToken;

        if (token.kind == TokenKind.Name) {
            const keyword = grammar.stringToKeyword(token.data) orelse return error.UnknownKeyword;
            switch (keyword) {
                grammar.SyntaxKeyWord.schema => {
                    return grammar.TypeSystemExtensionNode{
                        .SchemaExtension = try self.parseSchemaExtension(),
                    };
                },
                grammar.SyntaxKeyWord.scalar => {
                    return grammar.TypeSystemExtensionNode{
                        .TypeExtension = grammar.TypeExtensionNode{
                            .ScalarTypeExtension = try self.parseScalarTypeExtension(),
                        },
                    };
                },
                grammar.SyntaxKeyWord.type => {
                    return grammar.TypeSystemExtensionNode{
                        .TypeExtension = grammar.TypeExtensionNode{
                            .ObjectTypeExtension = try self.parseObjectTypeExtension(),
                        },
                    };
                },
                grammar.SyntaxKeyWord.interface => {
                    return grammar.TypeSystemExtensionNode{
                        .TypeExtension = grammar.TypeExtensionNode{
                            .InterfaceTypeExtension = try self.parseInterfaceTypeExtension(),
                        },
                    };
                },
                grammar.SyntaxKeyWord.@"union" => {
                    return grammar.TypeSystemExtensionNode{
                        .TypeExtension = grammar.TypeExtensionNode{
                            .UnionTypeExtension = try self.parseUnionTypeExtension(),
                        },
                    };
                },
                grammar.SyntaxKeyWord.@"enum" => {
                    return grammar.TypeSystemExtensionNode{
                        .TypeExtension = grammar.TypeExtensionNode{
                            .EnumTypeExtension = try self.parseEnumTypeExtension(),
                        },
                    };
                },
                grammar.SyntaxKeyWord.input => {
                    return grammar.TypeSystemExtensionNode{
                        .TypeExtension = grammar.TypeExtensionNode{
                            .InputObjectTypeExtension = try self.parseInputObjectTypeExtension(),
                        },
                    };
                },
                else => {
                    return error.UnexpectedToken;
                },
            }
        }
        return error.UnexpectedToken;
    }

    pub fn parseEnumValuesDefinitions(self: *Parser) !?[]grammar.EnumValueDefinitionNode {
        self.debug("parseEnumValuesDefinitions");
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, optionalMany.
        if (!self.expectOptionalToken(TokenKind.LCurly)) {
            return null;
        }

        var nodes = std.ArrayList(grammar.EnumValueDefinitionNode).init(self.allocator);
        defer nodes.deinit();
        while (self.peek()) |_| {
            const value = try self.parseEnumValueDefinition();
            try nodes.append(value);

            if (self.expectOptionalToken(TokenKind.RCurly)) {
                break;
            }
        }

        return try nodes.toOwnedSlice();
    }

    pub fn parseEnumValueDefinition(self: *Parser) !grammar.EnumValueDefinitionNode {
        self.debug("parseEnumValueDefinition");
        const description = try self.parseDescription();
        const name = try self.parseEnumValueName();
        const directives = try self.parseConstDirectives();

        return grammar.EnumValueDefinitionNode{
            .description = description,
            .name = name,
            .directives = directives,
        };
    }

    pub fn parseEnumValueName(self: *Parser) !grammar.NameNode {
        self.debug("parseEnumValueName");
        const token = self.peek() orelse return error.UnexpectedNullToken;
        if (std.mem.eql(u8, token.data, "true") or
            std.mem.eql(u8, token.data, "false") or
            std.mem.eql(u8, token.data, "null"))
        {
            return error.ReservedEnumValueName;
        }

        const name = try self.parseName();
        return name;
    }

    pub fn parseOperationType(self: *Parser) !grammar.OperationType {
        self.debug("parseOperationType");
        const token = try self.expect(TokenKind.Name);
        const keyword = grammar.stringToKeyword(token.data) orelse {
            return error.UnknownDefinition;
        };

        switch (keyword) {
            grammar.SyntaxKeyWord.query => {
                return grammar.OperationType.Query;
            },
            grammar.SyntaxKeyWord.mutation => {
                return grammar.OperationType.Mutation;
            },
            grammar.SyntaxKeyWord.subscription => {
                return grammar.OperationType.Subscription;
            },
            else => {
                // "expected a query, mutation or subscription"
                return error.UnexpectedToken;
            },
        }
        return error.UnexpectedToken;
    }

    pub fn parseDescription(self: *Parser) !?grammar.StringValueNode {
        self.debug("parseDescription");
        if (!self.peekKind(TokenKind.StringValue)) {
            return null;
        }

        const val = try self.parseStringLiteral();
        return val;
    }

    pub fn parseImplementsInterfaces(self: *Parser) !?[]grammar.NamedTypeNode {
        self.debug("parseImplementsInterfaces");
        if (!self.expectOptionalKeyword(grammar.SyntaxKeyWord.implements)) {
            return null;
        }

        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, delimitedMany.
        _ = self.expectOptionalToken(TokenKind.Amp);

        var nodes = std.ArrayList(grammar.NamedTypeNode).init(self.allocator);
        defer nodes.deinit();
        while (self.peek()) |_| {
            const name = try self.parseNamedType();
            try nodes.append(name);

            if (!self.expectOptionalToken(TokenKind.Amp)) {
                break;
            }
        }
        return try nodes.toOwnedSlice();
    }

    pub fn parseFieldsDefinition(self: *Parser) !?[]grammar.FieldDefinitionNode {
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, optionalMany.
        self.debug("parseFieldsDefinition");
        if (!self.expectOptionalToken(TokenKind.LCurly)) {
            return null;
        }

        var nodes = std.ArrayList(grammar.FieldDefinitionNode).init(self.allocator);
        defer nodes.deinit();
        while (self.peek()) |_| {
            const field = try self.parseFieldDefinition();
            try nodes.append(field);

            if (self.expectOptionalToken(TokenKind.RCurly)) {
                break;
            }
        }

        return try nodes.toOwnedSlice();
    }

    pub fn parseFieldDefinition(self: *Parser) !grammar.FieldDefinitionNode {
        self.debug("parseFieldDefinition");
        const description = try self.parseDescription();
        const name = try self.parseName();
        const args = try self.parseArgumentDefs();
        _ = try self.expect(TokenKind.Colon);
        const typeNode = try self.parseTypeReference();
        const directives = try self.parseConstDirectives();

        return grammar.FieldDefinitionNode{
            .name = name,
            .type = typeNode,
            .arguments = args,
            .description = description,
            .directives = directives,
        };
    }

    pub fn parseArgumentDefs(self: *Parser) !?[]grammar.InputValueDefinitionNode {
        self.debug("parseArgumentDefs");
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, optionalMany.
        if (!self.expectOptionalToken(TokenKind.LParen)) {
            return null;
        }

        var nodes = std.ArrayList(grammar.InputValueDefinitionNode).init(self.allocator);
        defer nodes.deinit();
        while (self.peek()) |_| {
            const arg = try self.parseInputValueDef();
            try nodes.append(arg);

            if (self.expectOptionalToken(TokenKind.RParen)) {
                break;
            }
        }

        return try nodes.toOwnedSlice();
    }

    pub fn parseInputValueDef(self: *Parser) !grammar.InputValueDefinitionNode {
        self.debug("parseInputValueDef");
        const name = try self.parseName();
        _ = try self.expect(TokenKind.Colon);
        const typeNode = try self.parseTypeReference();
        var defaultValue: ?grammar.ValueNode = null;
        if (self.expectOptionalToken(TokenKind.Eq)) {
            defaultValue = try self.parseConstValueLiteral();
        }
        const directives = try self.parseConstDirectives();

        return grammar.InputValueDefinitionNode{
            .name = name,
            .type = typeNode,
            .defaultValue = defaultValue,
            .directives = directives,
        };
    }

    pub fn parseOperationTypeDefinitions(self: *Parser) !?[]grammar.OperationTypeDefinitionNode {
        self.debug("parseOperationTypeDefinitions");
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, many.
        var nodes = std.ArrayList(grammar.OperationTypeDefinitionNode).init(self.allocator);
        defer nodes.deinit();
        _ = try self.expect(TokenKind.LCurly);
        while (self.peek()) |_| {
            const otd = try self.parseOperationTypeDefinition();
            try nodes.append(otd);

            if (self.expectOptionalToken(TokenKind.RCurly)) {
                break;
            }
        }
        return try nodes.toOwnedSlice();
    }

    pub fn parseOperationTypeDefinition(self: *Parser) !grammar.OperationTypeDefinitionNode {
        self.debug("parseOperationTypeDefinition");
        const operation = try self.parseOperationType();
        _ = try self.expect(TokenKind.Colon);
        const typeNode = try self.parseNamedType();
        return grammar.OperationTypeDefinitionNode{
            .operation = operation,
            .type = typeNode,
        };
    }

    pub fn parseUnionMemberTypes(self: *Parser) !?[]grammar.NamedTypeNode {
        self.debug("parseUnionMemberTypes");
        if (!self.expectOptionalToken(TokenKind.Eq)) {
            return null;
        }

        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, delimitedMany.
        _ = self.expectOptionalToken(TokenKind.Pipe);

        var nodes = std.ArrayList(grammar.NamedTypeNode).init(self.allocator);
        defer nodes.deinit();
        while (self.peek()) |_| {
            const name = try self.parseNamedType();
            try nodes.append(name);

            if (!self.expectOptionalToken(TokenKind.Pipe)) {
                break;
            }
        }
        return try nodes.toOwnedSlice();
    }

    pub fn parseInputFieldsDefinition(self: *Parser) !?[]grammar.InputValueDefinitionNode {
        self.debug("parseInputFieldsDefinition");
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, optionalMany.
        if (!self.expectOptionalToken(TokenKind.LCurly)) {
            return null;
        }

        var nodes = std.ArrayList(grammar.InputValueDefinitionNode).init(self.allocator);
        defer nodes.deinit();
        while (self.peek()) |_| {
            const field = try self.parseInputValueDef();
            try nodes.append(field);

            if (self.expectOptionalToken(TokenKind.RCurly)) {
                break;
            }
        }

        return try nodes.toOwnedSlice();
    }

    pub fn parseDirectiveLocations(self: *Parser) ![]grammar.NameNode {
        self.debug("parseDirectiveLocations");
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, delimitedMany.
        _ = self.expectOptionalToken(TokenKind.Pipe);

        var nodes = std.ArrayList(grammar.NameNode).init(self.allocator);
        defer nodes.deinit();
        while (self.peek()) |_| {
            const name = try self.parseDirectiveLocation();
            try nodes.append(name);

            if (!self.expectOptionalToken(TokenKind.Pipe)) {
                break;
            }
        }
        return try nodes.toOwnedSlice();
    }

    pub fn parseDirectiveLocation(self: *Parser) !grammar.NameNode {
        self.debug("parseDirectiveLocation");
        const token = self.peek() orelse return error.UnexpectedNullToken;
        _ = grammar.stringToDirectiveLocation(token.data) orelse {
            return error.UnknownDirectiveLocation;
        };
        const name = try self.parseName();
        return name;
    }

    pub fn parseSelectionSet(self: *Parser) anyerror!grammar.SelectionSetNode {
        self.debug("parseSelectionSet");
        const selections = try self.parseSelections();
        const node = grammar.SelectionSetNode{
            .selections = selections,
        };
        return node;
    }

    pub fn parseSelections(self: *Parser) ![]grammar.SelectionNode {
        self.debug("parseSelections");
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, many.
        var nodes = std.ArrayList(grammar.SelectionNode).init(self.allocator);
        defer nodes.deinit();

        _ = try self.expect(TokenKind.LCurly);
        while (self.peek()) |_| {
            const sel = try self.parseSelection();
            try nodes.append(sel);

            if (self.expectOptionalToken(TokenKind.RCurly)) {
                break;
            }
        }
        return nodes.toOwnedSlice();
    }

    pub fn parseSelection(self: *Parser) !grammar.SelectionNode {
        self.debug("parseSelection");
        const token = self.peek() orelse return error.UnexpectedNullToken;
        // Field.
        if (token.kind != TokenKind.Spread) {
            const field = try self.parseField();
            return grammar.SelectionNode{ .Field = field };
        }

        // Fragment spread.
        _ = try self.expect(TokenKind.Spread);
        const hasTypeCondition = self.expectOptionalKeyword(grammar.SyntaxKeyWord.on);
        if (!hasTypeCondition and self.peekKind(TokenKind.Name)) {
            const name = try self.parseFragmentName();
            const directives = try self.parseDirectives(false);
            return grammar.SelectionNode{
                .FragmentSpread = grammar.FragmentSpreadNode{
                    .name = name,
                    .directives = directives,
                },
            };
        }

        // Inline Fragment.
        var typeCondition: ?grammar.NamedTypeNode = null;
        if (hasTypeCondition) {
            typeCondition = try self.parseNamedType();
        }

        const directives = try self.parseDirectives(false);
        const selectionSet = try self.parseSelectionSet();

        return grammar.SelectionNode{
            .InlineFragment = grammar.InlineFragmentNode{
                .typeCondition = typeCondition,
                .directives = directives,
                .selectionSet = selectionSet,
            },
        };
    }

    pub fn parseFragmentName(self: *Parser) !grammar.NameNode {
        self.debug("parseFragmentName");
        const token = self.peek() orelse return error.UnexpectedNullToken;
        // TODO: Keyword check eats the token. Use an if statement instead. Come back to this later.
        if (std.mem.eql(u8, token.data, "on")) {
            return error.UnexpectedFragmentName;
        }

        const name = try self.parseName();
        return name;
    }

    pub fn parseField(self: *Parser) anyerror!grammar.FieldNode {
        self.debug("parseField");
        const nameOrAlias = try self.parseName();

        var name: grammar.NameNode = undefined;
        var alias: ?grammar.NameNode = null;

        if (self.expectOptionalToken(TokenKind.Colon)) {
            alias = nameOrAlias;
            name = try self.parseName();
        } else {
            name = nameOrAlias;
        }

        const arguments = try self.parseArguments(false);
        const directives = try self.parseDirectives(false);
        var selectionSet: ?grammar.SelectionSetNode = null;
        if (self.peekKind(TokenKind.LCurly)) {
            selectionSet = try self.parseSelectionSet();
        }

        return grammar.FieldNode{
            .kind = grammar.SyntaxKind.Field,
            .name = name,
            .alias = alias,
            .arguments = arguments,
            .directives = directives,
            .selectionSet = selectionSet,
        };
    }

    pub fn parseName(self: *Parser) !grammar.NameNode {
        self.debug("parseName");
        const token = try self.expect(TokenKind.Name);
        return grammar.NameNode{
            .value = token.data,
        };
    }

    pub fn parseArguments(self: *Parser, isConst: bool) !?[]grammar.ArgumentNode {
        self.debug("parseArguments");
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, optionalMany.
        if (!self.expectOptionalToken(TokenKind.LParen)) {
            return null;
        }

        var nodes = std.ArrayList(grammar.ArgumentNode).init(self.allocator);
        defer nodes.deinit();
        while (self.peek()) |_| {
            const arg = try self.parseArgument(isConst);
            try nodes.append(arg);

            if (self.expectOptionalToken(TokenKind.RParen)) {
                break;
            }
        }

        return try nodes.toOwnedSlice();
    }

    pub fn parseArgument(self: *Parser, isConst: bool) !grammar.ArgumentNode {
        self.debug("parseArgument");
        const name = try self.parseName();
        _ = try self.expect(TokenKind.Colon);

        const value = try self.parseValueLiteral(isConst);
        return grammar.ArgumentNode{
            .name = name,
            .value = value,
        };
    }

    pub fn parseDirectives(self: *Parser, isConst: bool) !?[]grammar.DirectiveNode {
        self.debug("parseDirectives");
        if (!self.peekKind(TokenKind.At)) {
            return null;
        }

        var nodes = std.ArrayList(grammar.DirectiveNode).init(self.allocator);
        defer nodes.deinit();
        while (self.peek()) |token| {
            if (token.kind != TokenKind.At) {
                break;
            }
            const dir = try self.parseDirective(isConst);
            try nodes.append(dir);
        }

        return try nodes.toOwnedSlice();
    }

    pub fn parseDirective(self: *Parser, isConst: bool) !grammar.DirectiveNode {
        self.debug("parseDirective");
        _ = try self.expect(TokenKind.At);
        const name = try self.parseName();
        const arguments = try self.parseArguments(isConst);
        return grammar.DirectiveNode{
            .name = name,
            .arguments = arguments,
        };
    }

    pub fn parseVariableDefinitions(self: *Parser) !?[]grammar.VariableDefinitionNode {
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, optionalMany.
        if (!self.expectOptionalToken(TokenKind.LParen)) {
            return null;
        }

        var nodes = std.ArrayList(grammar.VariableDefinitionNode).init(self.allocator);
        defer nodes.deinit();
        while (self.peek()) |_| {
            self.debug("parseVariableDefinitions");
            const varDef = try self.parseVariableDefinition();
            try nodes.append(varDef);

            if (self.expectOptionalToken(TokenKind.RParen)) {
                break;
            }
        }

        return try nodes.toOwnedSlice();
    }

    pub fn parseVariableDefinition(self: *Parser) !grammar.VariableDefinitionNode {
        self.debug("parseVariableDefinition");
        const variable = try self.parseVariable();
        _ = try self.expect(TokenKind.Colon);
        const typeNode = try self.parseTypeReference();

        var defaultValue: ?grammar.ValueNode = null;
        if (self.expectOptionalToken(TokenKind.Eq)) {
            defaultValue = try self.parseConstValueLiteral();
        }

        const directives = try self.parseConstDirectives();

        return grammar.VariableDefinitionNode{
            .variable = variable,
            .type = typeNode,
            .defaultValue = defaultValue,
            .directives = directives,
        };
    }

    pub fn parseVariable(self: *Parser) !grammar.VariableNode {
        self.debug("parseVariable");
        _ = try self.expect(TokenKind.Dollar);
        const name = try self.parseName();
        return grammar.VariableNode{
            .name = name,
        };
    }

    pub fn parseTypeReference(self: *Parser) !*grammar.TypeNode {
        self.debug("parseTypeReference");
        const typeNode = try self.allocator.create(grammar.TypeNode);

        if (self.expectOptionalToken(TokenKind.LBracket)) {
            const innerType = try self.parseTypeReference();
            _ = try self.expect(TokenKind.RBracket);

            typeNode.* = grammar.TypeNode{
                .ListType = grammar.ListTypeNode{
                    .type = innerType,
                },
            };
        } else {
            const name = try self.parseNamedType();
            typeNode.* = grammar.TypeNode{ .NamedType = name };
        }

        if (self.expectOptionalToken(TokenKind.Bang)) {
            const non_null = try self.allocator.create(grammar.TypeNode);
            non_null.* = grammar.TypeNode{
                .NonNullType = grammar.NonNullTypeNode{
                    .type = typeNode,
                },
            };
            return non_null;
        }

        return typeNode;
    }

    pub fn parseNamedType(self: *Parser) !grammar.NamedTypeNode {
        self.debug("parseNamedType");
        const name = try self.parseName();
        return grammar.NamedTypeNode{
            .name = name,
        };
    }

    pub fn parseConstValueLiteral(self: *Parser) !grammar.ValueNode {
        self.debug("parseConstValueLiteral");
        return self.parseValueLiteral(true);
    }

    pub fn parseConstDirectives(self: *Parser) !?[]grammar.DirectiveNode {
        self.debug("parseConstDirectives");
        return self.parseDirectives(true);
    }

    pub fn parseValueLiteral(self: *Parser, isConst: bool) anyerror!grammar.ValueNode {
        self.debug("parseValueLiteral");
        const token = self.peek() orelse return error.UnexpectedNullToken;

        switch (token.kind) {
            TokenKind.LBracket => {
                const list = try self.parseList(isConst);
                return grammar.ValueNode{
                    .List = list,
                };
            },
            TokenKind.LCurly => {
                const obj = try self.parseObject(isConst);
                return grammar.ValueNode{
                    .Object = obj,
                };
            },
            TokenKind.Int => {
                _ = self.pop();
                return grammar.ValueNode{
                    .Int = grammar.IntValueNode{
                        .value = token.data,
                    },
                };
            },
            TokenKind.Float => {
                _ = self.pop();
                return grammar.ValueNode{
                    .Float = grammar.FloatValueNode{
                        .value = token.data,
                    },
                };
            },
            TokenKind.StringValue => {
                const str = try self.parseStringLiteral();
                return grammar.ValueNode{ .String = str };
            },
            TokenKind.Name => {
                _ = self.pop();

                if (std.mem.eql(u8, token.data, "true")) {
                    return grammar.ValueNode{
                        .Boolean = grammar.BooleanValueNode{ .value = true },
                    };
                } else if (std.mem.eql(u8, token.data, "false")) {
                    return grammar.ValueNode{
                        .Boolean = grammar.BooleanValueNode{ .value = false },
                    };
                } else if (std.mem.eql(u8, token.data, "null")) {
                    return grammar.ValueNode{
                        .Null = grammar.NullValueNode{},
                    };
                } else {
                    return grammar.ValueNode{
                        .Enum = grammar.EnumValueNode{
                            .value = token.data,
                        },
                    };
                }
            },
            TokenKind.Dollar => {
                if (isConst) {
                    _ = try self.expect(TokenKind.Dollar);

                    if (self.peekKind(TokenKind.Name)) {
                        return error.UnexpectedVariable;
                    } else {
                        return error.UnexpectedToken;
                    }
                }

                const variable = try self.parseVariable();
                return grammar.ValueNode{ .Variable = variable };
            },
            else => {
                return error.UnexpectedToken;
            },
        }
        return error.UnexpectedToken;
    }

    pub fn parseList(self: *Parser, isConst: bool) !grammar.ListValueNode {
        self.debug("parseList");
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, any.
        _ = try self.expect(TokenKind.LBracket);

        var nodes = std.ArrayList(grammar.ValueNode).init(self.allocator);
        defer nodes.deinit();
        while (!self.expectOptionalToken(TokenKind.RBracket)) {
            const value = try self.parseValueLiteral(isConst);
            try nodes.append(value);
        }

        return grammar.ListValueNode{
            .values = try nodes.toOwnedSlice(),
        };
    }

    pub fn parseObject(self: *Parser, isConst: bool) !grammar.ObjectValueNode {
        self.debug("parseObject");
        // TODO(repeat-parsing-loop): Repeat logic for parsing nodes, any.
        _ = try self.expect(TokenKind.LCurly);

        var nodes = std.ArrayList(grammar.ObjectFieldNode).init(self.allocator);
        defer nodes.deinit();
        while (!self.expectOptionalToken(TokenKind.RCurly)) {
            const field = try self.parseObjectField(isConst);
            try nodes.append(field);
        }

        return grammar.ObjectValueNode{
            .fields = try nodes.toOwnedSlice(),
        };
    }

    pub fn parseObjectField(self: *Parser, isConst: bool) !grammar.ObjectFieldNode {
        self.debug("parseObjectField");
        const name = try self.parseName();
        _ = try self.expect(TokenKind.Colon);
        const value = try self.parseValueLiteral(isConst);
        return grammar.ObjectFieldNode{
            .name = name,
            .value = value,
        };
    }

    pub fn parseStringLiteral(self: *Parser) !grammar.StringValueNode {
        self.debug("parseStringLiteral");
        const token = self.pop() orelse return error.UnexpectedNullToken;
        return grammar.StringValueNode{
            .value = token.data,
        };
    }

    pub fn parseSchemaExtension(self: *Parser) !grammar.SchemaExtensionNode {
        self.debug("parseSchemaExtension");
        try self.expectKeyword(grammar.SyntaxKeyWord.extend);
        try self.expectKeyword(grammar.SyntaxKeyWord.schema);
        const directives = try self.parseConstDirectives();
        const operationTypes = try self.parseOperationTypeDefinitions();

        if (directives.?.len == 0 and operationTypes.?.len == 0) {
            return error.UnexpectedToken;
        }

        return grammar.SchemaExtensionNode{
            .directives = directives,
            .operationTypes = operationTypes,
        };
    }

    pub fn parseScalarTypeExtension(self: *Parser) !grammar.ScalarTypeExtensionNode {
        self.debug("parseScalarTypeExtension");
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.extend);
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.scalar);
        const name = try self.parseName();
        const directives = try self.parseConstDirectives();

        if (directives.?.len == 0) {
            return error.UnexpectedToken;
        }

        return grammar.ScalarTypeExtensionNode{
            .name = name,
            .directives = directives,
        };
    }

    pub fn parseObjectTypeExtension(self: *Parser) !grammar.ObjectTypeExtensionNode {
        self.debug("parseObjectTypeExtension");
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.extend);
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.type);
        const name = try self.parseName();
        const interfaces = try self.parseImplementsInterfaces();
        const directives = try self.parseConstDirectives();
        const fields = try self.parseFieldsDefinition();

        if (interfaces.?.len == 0 and directives.?.len == 0 and fields.?.len == 0) {
            return error.UnexpectedToken;
        }

        return grammar.ObjectTypeExtensionNode{
            .name = name,
            .interfaces = interfaces,
            .directives = directives,
            .fields = fields,
        };
    }

    pub fn parseInterfaceTypeExtension(self: *Parser) !grammar.InterfaceTypeExtensionNode {
        self.debug("parseInterfaceTypeExtension");
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.extend);
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.interface);
        const name = try self.parseName();
        const interfaces = try self.parseImplementsInterfaces();
        const directives = try self.parseConstDirectives();
        const fields = try self.parseFieldsDefinition();

        if (interfaces.?.len == 0 and directives.?.len == 0 and fields.?.len == 0) {
            return error.UnexpectedToken;
        }

        return grammar.InterfaceTypeExtensionNode{
            .name = name,
            .interfaces = interfaces,
            .directives = directives,
            .fields = fields,
        };
    }

    pub fn parseUnionTypeExtension(self: *Parser) !grammar.UnionTypeExtensionNode {
        self.debug("parseUnionTypeExtension");
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.extend);
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.@"union");
        const name = try self.parseName();
        const directives = try self.parseConstDirectives();
        const types = try self.parseUnionMemberTypes();

        if (directives.?.len == 0 and types.?.len == 0) {
            return error.UnexpectedToken;
        }

        return grammar.UnionTypeExtensionNode{
            .name = name,
            .directives = directives,
            .types = types,
        };
    }

    pub fn parseEnumTypeExtension(self: *Parser) !grammar.EnumTypeExtensionNode {
        self.debug("parseEnumTypeExtension");
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.extend);
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.@"enum");
        const name = try self.parseName();
        const directives = try self.parseConstDirectives();
        const values = try self.parseEnumValuesDefinitions();

        if (directives.?.len == 0 and values.?.len == 0) {
            return error.UnexpectedToken;
        }

        return grammar.EnumTypeExtensionNode{
            .name = name,
            .directives = directives,
            .values = values,
        };
    }

    pub fn parseInputObjectTypeExtension(self: *Parser) !grammar.InputObjectTypeExtensionNode {
        self.debug("parseInputObjectTypeExtension");
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.extend);
        _ = try self.expectKeyword(grammar.SyntaxKeyWord.input);
        const name = try self.parseName();
        const directives = try self.parseConstDirectives();
        const fields = try self.parseInputFieldsDefinition();

        if (directives.?.len == 0 and fields.?.len == 0) {
            return error.UnexpectedToken;
        }

        return grammar.InputObjectTypeExtensionNode{
            .name = name,
            .directives = directives,
            .fields = fields,
        };
    }
};

fn nextNonIgnorableToken(lexer: *Lexer) ?Token {
    while (true) {
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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source = "{ user { id } }";
    var p = Parser.init(allocator, source);
    const doc = try p.parse();

    try std.testing.expect(doc.definitions.len == 1);
    const dn = doc.definitions[0];

    try std.testing.expect(dn == grammar.DefinitionNode.ExecutableDefinition);
    const def = dn.ExecutableDefinition;

    try std.testing.expect(def == grammar.ExecutableDefinitionNode.OperationDefinition);
    const op = def.OperationDefinition;

    try std.testing.expect(op.selectionSet != null);
    try std.testing.expect(op.selectionSet.?.selections.len == 1);
    const sel = op.selectionSet.?.selections[0];

    try std.testing.expect(sel == grammar.SelectionNode.Field);
    const f = sel.Field;
    try std.testing.expect(std.mem.eql(u8, f.name.value, "user"));
    try std.testing.expect(f.alias == null);
    try std.testing.expect(f.arguments == null);
    try std.testing.expect(f.selectionSet != null);
    try std.testing.expect(f.selectionSet.?.selections.len == 1);

    const subSel = f.selectionSet.?.selections[0];
    try std.testing.expect(subSel == grammar.SelectionNode.Field);
    const subF = subSel.Field;
    try std.testing.expect(std.mem.eql(u8, subF.name.value, "id"));
    try std.testing.expect(subF.alias == null);
    try std.testing.expect(subF.arguments == null);
    try std.testing.expect(subF.selectionSet == null);
}

test "should parse a query operation with a single field" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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

    try std.testing.expect(dn == grammar.DefinitionNode.ExecutableDefinition);
    const def = dn.ExecutableDefinition;

    try std.testing.expect(def == grammar.ExecutableDefinitionNode.OperationDefinition);
    const op = def.OperationDefinition;

    try std.testing.expect(op.selectionSet != null);
    try std.testing.expect(op.selectionSet.?.selections.len == 1);
    const sel = op.selectionSet.?.selections[0];

    try std.testing.expect(sel == grammar.SelectionNode.Field);
    const f = sel.Field;
    try std.testing.expect(std.mem.eql(u8, f.name.value, "users"));
    try std.testing.expect(f.alias == null);
    try std.testing.expect(f.arguments != null);
    try std.testing.expect(f.arguments.?.len == 1);
    try std.testing.expect(f.selectionSet != null);
    try std.testing.expect(f.selectionSet.?.selections.len == 1);

    const subSel = f.selectionSet.?.selections[0];
    try std.testing.expect(subSel == grammar.SelectionNode.Field);
    const subF = subSel.Field;
    try std.testing.expect(std.mem.eql(u8, subF.name.value, "id"));
    try std.testing.expect(subF.alias == null);
    try std.testing.expect(subF.arguments == null);
    try std.testing.expect(subF.selectionSet == null);
}

test "should parse a query operation with fields and arguments" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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

    try std.testing.expect(dn == grammar.DefinitionNode.ExecutableDefinition);
    const def = dn.ExecutableDefinition;

    try std.testing.expect(def == grammar.ExecutableDefinitionNode.OperationDefinition);
    const op = def.OperationDefinition;

    try std.testing.expect(op.selectionSet != null);
    try std.testing.expect(op.selectionSet.?.selections.len == 1);
    const sel = op.selectionSet.?.selections[0];

    try std.testing.expect(sel == grammar.SelectionNode.Field);
    const f = sel.Field;
    try std.testing.expect(std.mem.eql(u8, f.name.value, "users"));
    try std.testing.expect(f.alias == null);

    try std.testing.expect(f.arguments != null);
    try std.testing.expect(f.arguments.?.len == 1);
    const args = f.arguments.?;
    const arg = args[0];
    try std.testing.expect(std.mem.eql(u8, arg.name.value, "createdTime"));

    try std.testing.expect(arg.value == grammar.ValueNode.Variable);
    const varNode = arg.value.Variable;
    try std.testing.expect(std.mem.eql(u8, varNode.name.value, "createdTime"));

    try std.testing.expect(f.selectionSet != null);
    try std.testing.expect(f.selectionSet.?.selections.len == 2);

    const subSelOne = f.selectionSet.?.selections[0];
    try std.testing.expect(subSelOne == grammar.SelectionNode.Field);
    const subFOne = subSelOne.Field;
    try std.testing.expect(std.mem.eql(u8, subFOne.name.value, "id"));
    try std.testing.expect(subFOne.alias == null);
    try std.testing.expect(subFOne.arguments == null);
    try std.testing.expect(subFOne.selectionSet == null);

    const subSelTwo = f.selectionSet.?.selections[1];
    try std.testing.expect(subSelTwo == grammar.SelectionNode.Field);

    const subFTwo = subSelTwo.Field;
    try std.testing.expect(std.mem.eql(u8, subFTwo.name.value, "friends"));
    try std.testing.expect(subFTwo.alias == null);
    try std.testing.expect(subFTwo.arguments == null);
    try std.testing.expect(subFTwo.selectionSet != null);
    try std.testing.expect(subFTwo.selectionSet.?.selections.len == 1);
}

test "should parse a query operation with descriptions" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == grammar.TypeSystemDefinitionNode.TypeDefinition);

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == grammar.TypeDefinitionNode.ObjectTypeDefinition);

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
    try std.testing.expect(field.type.NamedType.kind == grammar.SyntaxKind.NamedType);
}

test "should parse a schema definition" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == grammar.TypeSystemDefinitionNode.SchemaDefinition);

    const schemaDef = def.SchemaDefinition;
    try std.testing.expect(schemaDef.description == null);
    try std.testing.expect(schemaDef.directives == null);
    try std.testing.expect(schemaDef.operationTypes != null);
    try std.testing.expect(schemaDef.operationTypes.?.len == 2);

    const operationTypes = schemaDef.operationTypes.?;
    try std.testing.expect(operationTypes[0].operation == grammar.OperationType.Query);
    try std.testing.expect(std.mem.eql(u8, operationTypes[0].type.name.value, "Query"));
    try std.testing.expect(operationTypes[1].operation == grammar.OperationType.Mutation);
    try std.testing.expect(std.mem.eql(u8, operationTypes[1].type.name.value, "Mutation"));
}

test "should parse a schema definition with directives" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == grammar.TypeSystemDefinitionNode.SchemaDefinition);

    const schemaDef = def.SchemaDefinition;

    try std.testing.expect(schemaDef.description == null);
    try std.testing.expect(schemaDef.directives != null);
    try std.testing.expect(schemaDef.directives.?.len == 1);
}

test "should parse a scalar type definition" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ scalar DateTime
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == grammar.TypeSystemDefinitionNode.TypeDefinition);

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == grammar.TypeDefinitionNode.ScalarTypeDefinition);

    const scalarDef = typeDef.ScalarTypeDefinition;
    try std.testing.expect(std.mem.eql(u8, scalarDef.name.value, "DateTime"));
}

test "should parse a type definition" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == grammar.TypeSystemDefinitionNode.TypeDefinition);

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == grammar.TypeDefinitionNode.ObjectTypeDefinition);

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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == grammar.TypeSystemDefinitionNode.TypeDefinition);

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == grammar.TypeDefinitionNode.InterfaceTypeDefinition);

    const objDef = typeDef.InterfaceTypeDefinition;
    try std.testing.expect(objDef.description == null);
    try std.testing.expect(std.mem.eql(u8, objDef.name.value, "User"));
    try std.testing.expect(objDef.interfaces == null);
    try std.testing.expect(objDef.directives == null);
}

test "should parse a union type definition" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ union SearchResult = User | Post | Comment
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == grammar.TypeSystemDefinitionNode.TypeDefinition);

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == grammar.TypeDefinitionNode.UnionTypeDefinition);

    const objDef = typeDef.UnionTypeDefinition;
    try std.testing.expect(objDef.description == null);
    try std.testing.expect(std.mem.eql(u8, objDef.name.value, "SearchResult"));
}

test "should parse a enum type definition" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == grammar.TypeSystemDefinitionNode.TypeDefinition);

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == grammar.TypeDefinitionNode.EnumTypeDefinition);

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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == grammar.TypeSystemDefinitionNode.TypeDefinition);

    const typeDef = def.TypeDefinition;
    try std.testing.expect(typeDef == grammar.TypeDefinitionNode.InputObjectTypeDefinition);

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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const source =
        \\ directive @auth on FIELD_DEFINITION
    ;
    var p = Parser.init(allocator, source);
    const doc = try p.parse();
    try std.testing.expect(doc.definitions.len == 1);

    const dn = doc.definitions[0];
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemDefinition);

    const def = dn.TypeSystemDefinition;
    try std.testing.expect(def == grammar.TypeSystemDefinitionNode.DirectiveDefinition);

    const dirDef = def.DirectiveDefinition;
    try std.testing.expect(dirDef.description == null);
    try std.testing.expect(std.mem.eql(u8, dirDef.name.value, "auth"));
}

test "should parse a fragment definition" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
    try std.testing.expect(dn == grammar.DefinitionNode.ExecutableDefinition);

    const def = dn.ExecutableDefinition;
    try std.testing.expect(def == grammar.ExecutableDefinitionNode.FragmentDefinition);

    const fragDef = def.FragmentDefinition;
    try std.testing.expect(std.mem.eql(u8, fragDef.name.value, "UserFragment"));

    try std.testing.expect(std.mem.eql(u8, fragDef.typeCondition.name.value, "User"));
    try std.testing.expect(fragDef.selectionSet.selections.len == 2);

    const selOne = fragDef.selectionSet.selections[0];
    try std.testing.expect(selOne == grammar.SelectionNode.Field);

    const fOne = selOne.Field;
    try std.testing.expect(std.mem.eql(u8, fOne.name.value, "id"));

    const selTwo = fragDef.selectionSet.selections[1];
    try std.testing.expect(selTwo == grammar.SelectionNode.Field);

    const fTwo = selTwo.Field;
    try std.testing.expect(std.mem.eql(u8, fTwo.name.value, "name"));
}

test "should parse a schema extension" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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
    try std.testing.expect(dn == grammar.DefinitionNode.TypeSystemExtension);

    const def = dn.TypeSystemExtension;
    try std.testing.expect(def == grammar.TypeSystemExtensionNode.SchemaExtension);
    const schemaExt = def.SchemaExtension;

    try std.testing.expect(schemaExt.directives != null);
    try std.testing.expect(schemaExt.directives.?.len == 1);
    try std.testing.expect(std.mem.eql(u8, schemaExt.directives.?[0].name.value, "directive"));

    try std.testing.expect(schemaExt.operationTypes != null);
    try std.testing.expect(schemaExt.operationTypes.?.len == 2);
    try std.testing.expect(std.mem.eql(u8, schemaExt.operationTypes.?[0].type.name.value, "Query"));
    try std.testing.expect(std.mem.eql(u8, schemaExt.operationTypes.?[1].type.name.value, "Mutation"));
    try std.testing.expect(schemaExt.operationTypes.?[0].operation == grammar.OperationType.Query);
    try std.testing.expect(schemaExt.operationTypes.?[1].operation == grammar.OperationType.Mutation);
}
