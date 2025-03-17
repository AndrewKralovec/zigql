# Graphql Parser Zig
A graphql parsing library written in zig.
After reading that [bun](https://bun.sh/) was coded in zig, i wanted to try it out. 
This is a toy project to see i can build a graphql parser. 

## Usage

Parses GraphQL source text into tokens.
```
const Lexer = @import("./lexer.zig").Lexer;

const allocator = std.heap.page_allocator;
const input = "{ user { id } }";

var lexer = Lexer
    .init(allocator, input);

const tokens = try lexer.lex();
defer allocator.free(tokens);

for (tokens) |token| {
    std.debug.print("kind={any}, data={s}\n", .{ token.kind, token.data });
}

// output
// kind=tokens.TokenKind.LCurly, data={    
// kind=tokens.TokenKind.Whitespace, data= 
// kind=tokens.TokenKind.Name, data=user   
// kind=tokens.TokenKind.Whitespace, data= 
// kind=tokens.TokenKind.LCurly, data={
// kind=tokens.TokenKind.Whitespace, data=
// kind=tokens.TokenKind.Name, data=id
// kind=tokens.TokenKind.Whitespace, data=
// kind=tokens.TokenKind.RCurly, data=}
// kind=tokens.TokenKind.Whitespace, data=
// kind=tokens.TokenKind.RCurly, data=}
// kind=tokens.TokenKind.Eof, data=
```