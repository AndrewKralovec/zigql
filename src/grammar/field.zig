const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseDescription = @import("./description.zig").parseDescription;
const parseName = @import("./name.zig").parseName;
const parseArgumentDefs = @import("./argument.zig").parseArgumentDefs;
const parseTypeReference = @import("./type.zig").parseTypeReference;
const parseConstDirectives = @import("./directive.zig").parseConstDirectives;
const parseArguments = @import("./argument.zig").parseArguments;
const parseDirectives = @import("./directive.zig").parseDirectives;
const parseSelectionSet = @import("./selection.zig").parseSelectionSet;

pub fn parseFieldsDefinition(p: *Parser) !?[]ast.FieldDefinitionNode {
    p.debug("parseFieldsDefinition");
    if (!p.expectOptionalToken(TokenKind.LCurly)) {
        return null;
    }

    var nodes = std.ArrayList(ast.FieldDefinitionNode).init(p.allocator);
    defer nodes.deinit();
    while (p.peek()) |_| {
        const field = try parseFieldDefinition(p);
        try nodes.append(field);

        if (p.expectOptionalToken(TokenKind.RCurly)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseFieldDefinition(p: *Parser) !ast.FieldDefinitionNode {
    p.debug("parseFieldDefinition");
    const description = try parseDescription(p);
    const name = try parseName(p);
    const args = try parseArgumentDefs(p);
    _ = try p.expect(TokenKind.Colon);
    const typeNode = try parseTypeReference(p);
    const directives = try parseConstDirectives(p);

    return ast.FieldDefinitionNode{
        .name = name,
        .type = typeNode,
        .arguments = args,
        .description = description,
        .directives = directives,
    };
}

pub fn parseField(p: *Parser) anyerror!ast.FieldNode {
    p.debug("parseField");
    const nameOrAlias = try parseName(p);

    var name: ast.NameNode = undefined;
    var alias: ?ast.NameNode = null;

    if (p.expectOptionalToken(TokenKind.Colon)) {
        alias = nameOrAlias;
        name = try parseName(p);
    } else {
        name = nameOrAlias;
    }

    const arguments = try parseArguments(p, false);
    const directives = try parseDirectives(p, false);
    var selectionSet: ?ast.SelectionSetNode = null;
    if (p.peekKind(TokenKind.LCurly)) {
        selectionSet = try parseSelectionSet(p);
    }

    return ast.FieldNode{
        .kind = ast.SyntaxKind.Field,
        .name = name,
        .alias = alias,
        .arguments = arguments,
        .directives = directives,
        .selectionSet = selectionSet,
    };
}
