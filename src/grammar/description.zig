const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseStringLiteral = @import("./value.zig").parseStringLiteral;

pub fn parseDescription(p: *Parser) !?ast.StringValueNode {
    p.debug("parseDescription");
    if (!try p.peekKind(TokenKind.StringValue)) {
        return null;
    }

    const val = try parseStringLiteral(p);
    return val;
}
