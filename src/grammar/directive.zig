const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../core/parser.zig").Parser;
const TokenKind = @import("../core/tokens.zig").TokenKind;

const parseDescription = @import("./description.zig").parseDescription;
const parseName = @import("./name.zig").parseName;
const parseArguments = @import("./argument.zig").parseArguments;
const parseArgumentDefs = @import("./argument.zig").parseArgumentDefs;

pub fn parseDirectiveDefinition(p: *Parser) !ast.DirectiveDefinitionNode {
    p.debug("parseDirectiveDefinition");
    const description = try parseDescription(p);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Directive);
    _ = try p.expect(TokenKind.At);

    const name = try parseName(p);
    const args = try parseArgumentDefs(p);
    const repeatable = try p.expectOptionalKeyword(ast.SyntaxKeyWord.Repeatable);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.On);

    const locations = try parseDirectiveLocations(p);
    return ast.DirectiveDefinitionNode{
        .description = description,
        .name = name,
        .arguments = args,
        .repeatable = repeatable,
        .locations = locations,
    };
}

pub fn parseDirectiveLocations(p: *Parser) ![]ast.DirectiveLocation {
    p.debug("parseDirectiveLocations");
    _ = try p.expectOptionalToken(TokenKind.Pipe);

    var nodes = std.ArrayList(ast.DirectiveLocation).init(p.allocator);
    defer nodes.deinit();
    while (true) {
        const loc = try parseDirectiveLocation(p);
        try nodes.append(loc);

        if (!try p.expectOptionalToken(TokenKind.Pipe)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseDirectiveLocation(p: *Parser) !ast.DirectiveLocation {
    p.debug("parseDirectiveLocation");
    const token = try p.peek();
    const loc = ast.DirectiveLocation.fromString(token.data) orelse {
        return error.UnknownDirectiveLocation;
    };

    // Consume the token
    _ = try parseName(p);
    return loc;
}

pub fn parseConstDirectives(p: *Parser) !?[]ast.DirectiveNode {
    p.debug("parseConstDirectives");
    return parseDirectives(p, true);
}

pub fn parseDirectives(p: *Parser, is_const: bool) !?[]ast.DirectiveNode {
    p.debug("parseDirectives");
    if (!try p.peekKind(TokenKind.At)) {
        return null;
    }

    var nodes = std.ArrayList(ast.DirectiveNode).init(p.allocator);
    defer nodes.deinit();
    while (try p.peekKind(TokenKind.At)) {
        const dir = try parseDirective(p, is_const);
        try nodes.append(dir);
    }

    return try nodes.toOwnedSlice();
}

pub fn parseDirective(p: *Parser, is_const: bool) !ast.DirectiveNode {
    p.debug("parseDirective");
    _ = try p.expect(TokenKind.At);
    const name = try parseName(p);
    const arguments = try parseArguments(p, is_const);
    return ast.DirectiveNode{
        .name = name,
        .arguments = arguments,
    };
}
