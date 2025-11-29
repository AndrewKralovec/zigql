# ZigQL
A graphql parsing library written in zig.
After reading that [bun](https://bun.sh/) was coded in zig, i wanted to try it out.

## Table of Contents

- [Getting Started](#getting-started)
- [Usage](#usage)
- [TODO](#todo)
- [Inspiration And Resources](#inspiration-and-resources)

## Getting Started

### Prerequisites

- [Zig](https://ziglang.org/) (version 0.14.0 or later)

### Building

To build the project, use the following command

```bash
zig build
```

To enable debug mode, pass the `-Ddebug=true` flag when building or testing the project

```bash
zig build -Ddebug=true
```

When debug mode is enabled, the parser will print additional state and parsing details.
This option might go away after the project matures.

### Testing

To run the project tests

```bash
zig build test
```

## Usage

ZigQL provides two main components for working with GraphQL.

- [Lexer](#lexer) for tokenization.
- [Parser](#parser) for building an abstract syntax tree (AST).

### Lexer

The `Lexer` tokenizes GraphQL text into individual tokens, which can then be processed by the parser or analyzed directly. It exposes several methods for tokenization and navigation.

#### Batch Lexing

The simplest way to use the lexer is to tokenize an entire GraphQL document at once. The `lex()` method returns both tokens and any errors encountered during scanning.
This approach is useful when you need an error resilient lexer that will not stop at the first error it encounters. This method instead collections errors and tokens, giving you the complete tokenized data.


Example.
```zig
const allocator = std.heap.page_allocator;
const source =
    \\ query {
    \\  users(id: 1) {
    \\   id
    \\  }
    \\ }
;
var lexer = Lexer.init(source);
const result = try lexer.lex(allocator);
defer {
    allocator.free(result.tokens);
    allocator.free(result.errors);
}

for (result.tokens) |token| {
    // Process each valid token
}
for (result.errors) |err| {
    // Handle each error that occurred during lexing
}
```

#### Stream Lexing

Sometimes you need more control over the tokenization process. The `next()` method allows you to read tokens one at a time, which is useful for streaming scenarios or when you want to process tokens immediately as they are read. The `next()` method returns an optional token when you hit the end of the input, you get `null`. This makes it safe to call repeatedly without worrying about going past the end.


Example.
```zig
const source =
    \\ query {
    \\  users(id: 1) {
    \\   id
    \\  }
    \\ }
;
var lexer = Lexer.init(source);
while (try lexer.next()) |token| {
    if (token.kind == TokenKind.Eof) {
        break; // Reached EOF
    }
    // Process token
}
```

#### Bounded Parsing

It is recommended to limit how far the lexer can scan. Use `withLimit()` to create a lexer that has a limit on the number of tokens that can be scanned.


Example.
```zig
var lexer = Lexer.init(source);
var limited_lexer = lexer.withLimit(10); // Only scan up to 10 tokens

const result = try limited_lexer.lex(allocator);
defer {
    allocator.free(result.tokens);
    allocator.free(result.errors);
}
// result.errors will contain LimitReached if we hit the limit
```

### Parser

The `Parser` converts GraphQL text into a structured AST, which you can use for analyzing or transforming GraphQL operations. It exposes several methods for parsing and token navigation. You should only pay attention to `init()` and `parse()` for basic usage.


Since the AST nodes contain slices, you will need to manage their memory appropriately to avoid leaks.
Using an `ArenaAllocator` is recommended for simpler memory management. You can just defer the arena's memory to clean up everything at once.

#### Basic Parsing

The simplest way to use the Parser is to parse an entire GraphQL document at once. The `parse()` method returns a structured AST that you can traverse and analyze.

Example.
```zig
const source =
    \\ query {
    \\  users(id: 1) {
    \\   id
    \\  }
    \\ }
;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit(); // Clean up all allocated memory

const allocator = arena.allocator();
var parser = Parser.init(allocator, source);
const doc = try parser.parse();

for (doc.definitions) |definition| {
    // Process each definition in the document
}
```


For basic parsing, the library exposes a `parse()` function, which provides a convenient way to parse GraphQL documents without manually creating a parser instance.


Example.
```zig
const zigql = @import("zig_ql");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();

const doc = try zigql.parse(arena.allocator(), source);
```

#### Bounded Parsing

Similar to the lexer, it is recommended to limit how far the parser can process tokens. You can use the `parseWithLimit()` function or create a parser with `withLimit()`.

Example with `parseWithLimit()`.
```zig
const doc = try zigql.parseWithLimit(allocator, source, 100);
// Will throw LimitReached error if we hit the limit
```

Example with `withLimit()`.
```zig
var parser = Parser.init(allocator, source);
var limited_parser = parser.withLimit(100); // Only process up to 100 tokens

const doc = try limitedParser.parse();
// Will throw LimitReached error if we hit the limit
```

## TODO

### Improvements

#### ArrayList vs Slices.
Find out if the types should be changed from slices to `ArrayList`.
Returning slices may involve unnecessary allocations, which could impact performance.
`toOwnedSlice` tries to remap the original list and if it cant then it memcopies.
[toOwnedSlice docs](https://ziglang.org/documentation/master/std/#std.array_list.ArrayListAlignedUnmanaged.toOwnedSlice).

An `ArrayList` can be appended to. But, for our use case the document and nodes were parsed and dont need further appending. Slice seems more suitable, but revisit this later.

#### Custom Deinit Methods
The user has to manage the memory of the document. It would be nice to have a deinit method so they dont have to recursively free the memory. We can add a deinit method on the document to do this for the user.
The allocator can be passed in. Using an arena allocator, also provides an elegant way to free the memory after use without having to recursively free the memory.

#### Enhanced Error Handling
Zig has a way of creating custom error types. We should implement this, as the native error type does not include context of the issue.

Lets also think about error resilience. It seems more useful to collect the errors it encounters, than to return on the first occurrence. 

#### Repeat Parsing Loop
Investigate a Ziggy way to handle repeated parsing logic without duplicating code. Currently, methods with a bound `self` cannot be passed as arguments.

#### Testing
Research best practices for organizing and executing tests in Zig. Currently, unit tests are embedded in the source files, which seems to align with Zig conventions but may not scale well as the project gets bigger.

## Inspiration And Resources
This project was inspired by a mix of curiosity for [zig](https://ziglang.org/), and a desire to see its use in web services.

I also drew inspiration from existing GraphQL libraries like [graphql-js](https://github.com/graphql/graphql-js) ([MIT](https://github.com/apollographql/apollo-rs/blob/main/LICENSE-MIT)) and [apollo-rs](https://github.com/apollographql/apollo-rs) ([MIT](https://github.com/apollographql/apollo-rs/blob/main/LICENSE-MIT)). They provided a great reference for how a GraphQL parser should behave.

This project follows the [October 2021 GraphQL specification](https://spec.graphql.org/October2021) for its grammar and parsing rules.