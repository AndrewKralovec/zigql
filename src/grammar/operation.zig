const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseNamedType = @import("./type.zig").parseNamedType;
const parseSelectionSet = @import("./selection.zig").parseSelectionSet;
const parseName = @import("./name.zig").parseName;
const parseVariableDefinitions = @import("./variable.zig").parseVariableDefinitions;
const parseDirectives = @import("./directive.zig").parseDirectives;

pub fn parseOperationDefinition(p: *Parser) !ast.OperationDefinitionNode {
    p.debug("parseOperationDefinition");
    const token = p.peek() orelse return error.UnexpectedNullToken;
    if (token.kind == TokenKind.LCurly) {
        const selectionSet = try parseSelectionSet(p);
        return ast.OperationDefinitionNode{
            .operation = ast.OperationType.Query,
            .name = null,
            .variableDefinitions = null,
            .directives = null,
            .selectionSet = selectionSet,
        };
    }

    const operation = try parseOperationType(p);
    var name: ?ast.NameNode = null;
    if (try p.peekKind(TokenKind.Name)) {
        name = try parseName(p);
    }

    const varDefs = try parseVariableDefinitions(p);
    const dirs = try parseDirectives(p, false);
    const selSet = try parseSelectionSet(p);

    return ast.OperationDefinitionNode{
        .operation = operation,
        .name = name,
        .variableDefinitions = varDefs,
        .directives = dirs,
        .selectionSet = selSet,
    };
}

// TODO: Why is this optional?
pub fn parseOperationTypeDefinitions(p: *Parser) ![]ast.OperationTypeDefinitionNode {
    p.debug("parseOperationTypeDefinitions");
    _ = try p.expect(TokenKind.LCurly);

    var nodes = std.ArrayList(ast.OperationTypeDefinitionNode).init(p.allocator);
    defer nodes.deinit();
    while (p.peek()) |_| {
        const otd = try parseOperationTypeDefinition(p);
        try nodes.append(otd);

        if (try p.expectOptionalToken(TokenKind.RCurly)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseOptionalOperationTypeDefinitions(p: *Parser) !?[]ast.OperationTypeDefinitionNode {
    p.debug("parseOptionalOperationTypeDefinitions");
    if (!try p.expectOptionalToken(TokenKind.LCurly)) {
        return null;
    }

    var nodes = std.ArrayList(ast.OperationTypeDefinitionNode).init(p.allocator);
    defer nodes.deinit();
    while (p.peek()) |_| {
        const otd = try parseOperationTypeDefinition(p);
        try nodes.append(otd);

        if (try p.expectOptionalToken(TokenKind.RCurly)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseOperationTypeDefinition(p: *Parser) !ast.OperationTypeDefinitionNode {
    p.debug("parseOperationTypeDefinition");
    const operation = try parseOperationType(p);
    _ = try p.expect(TokenKind.Colon);
    const typeNode = try parseNamedType(p);
    return ast.OperationTypeDefinitionNode{
        .operation = operation,
        .type = typeNode,
    };
}

pub fn parseOperationType(p: *Parser) !ast.OperationType {
    p.debug("parseOperationType");
    const token = try p.expect(TokenKind.Name);
    const keyword = ast.stringToKeyword(token.data) orelse {
        return error.UnknownDefinition;
    };

    switch (keyword) {
        ast.SyntaxKeyWord.Query => {
            return ast.OperationType.Query;
        },
        ast.SyntaxKeyWord.Mutation => {
            return ast.OperationType.Mutation;
        },
        ast.SyntaxKeyWord.Subscription => {
            return ast.OperationType.Subscription;
        },
        else => {
            // "expected a query, mutation or subscription"
            return error.UnexpectedToken;
        },
    }
    return error.UnexpectedToken;
}
