const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseNamedType = @import("./type.zig").parseNamedType;
const parseDirectives = @import("./directive.zig").parseDirectives;
const parseSelectionSet = @import("./selection.zig").parseSelectionSet;
const parseName = @import("./name.zig").parseName;

pub fn parseFragmentDefinition(p: *Parser) !ast.FragmentDefinitionNode {
    p.debug("parseFragmentDefinition");
    try p.expectKeyword(ast.SyntaxKeyWord.Fragment);

    const name = try parseFragmentName(p);

    try p.expectKeyword(ast.SyntaxKeyWord.On);
    const typeCondition = try parseNamedType(p);
    const directives = try parseDirectives(p, false);
    const selectionSet = try parseSelectionSet(p);

    return ast.FragmentDefinitionNode{
        .name = name,
        .typeCondition = typeCondition,
        .directives = directives,
        .selectionSet = selectionSet,
    };
}

pub fn parseFragmentName(p: *Parser) !ast.NameNode {
    p.debug("parseFragmentName");
    const token = try p.peek();
    // TODO: Keyword check eats the token. Use an if statement instead. Come back to this later.
    if (std.mem.eql(u8, token.data, "on")) {
        return error.UnexpectedFragmentName;
    }

    const name = try parseName(p);
    return name;
}
