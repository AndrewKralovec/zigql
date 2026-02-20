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

ZigQL provides three main components for working with GraphQL.

- [Lexer](#lexer) for tokenization.
- [Parser](#parser) for building an abstract syntax tree (AST).
- [Validator](#validator) (Work in progress) for validating GraphQL documents against the specification.

### Lexer

The `Lexer` tokenizes GraphQL text into individual tokens, which can then be processed by the parser or analyzed directly. It exposes several methods for tokenization and navigation.

#### Batch Lexing

The simplest way to use the lexer is to tokenize an entire GraphQL document at once. The `lex()` method returns both tokens and any errors encountered during scanning.
This approach is useful when you need an error resilient lexer that will not stop at the first error it encounters. This method instead collections errors and tokens, giving you the TODO tokenized data.


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

### Validator

TODO: WIP

#### Validation Rules

The validator implements the following GraphQL validation rules:

| Rule | Description | Status |
|------|-------------|--------|
| **Executable Definition Rules** | | |
| ExecutableDefinitionsRule | A GraphQL document is only valid for execution if all definitions are either operation or fragment definitions. | COMPLETE |
| FieldsOnCorrectTypeRule | Fields selected on an object, interface, or union must be defined on that type. | TODO |
| FragmentsOnCompositeTypesRule | Fragments can only be spread into a composite type (object, interface, or union). | TODO |
| KnownArgumentNamesRule | All arguments provided to a field or directive must be defined by that field or directive. | TODO |
| KnownDirectivesRule | All directives used must be defined in the schema and used in valid locations. | TODO |
| KnownFragmentNamesRule | All fragment spreads must refer to fragments defined in the same document. | TODO |
| KnownTypeNamesRule | All referenced types (in variable definitions and fragment conditions) must be defined in the schema. | TODO |
| LoneAnonymousOperationRule | A document containing an anonymous operation must contain only that one operation. | COMPLETE |
| NoFragmentCyclesRule | Fragments must not form cycles via fragment spreads. | TODO |
| NoUndefinedVariablesRule | All variables used in an operation must be defined by that operation. | TODO |
| NoUnusedFragmentsRule | All fragment definitions must be used within operations or other used fragments. | TODO |
| NoUnusedVariablesRule | All variables defined by an operation must be used in that operation. | TODO |
| OverlappingFieldsCanBeMergedRule | Fields selected in the same scope must have compatible types and arguments. | TODO |
| PossibleFragmentSpreadsRule | Fragment spreads must be on types that are possible given the parent type. | TODO |
| ProvidedRequiredArgumentsRule | All required arguments on fields and directives must be provided. | TODO |
| ScalarLeafsRule | Leaf fields (fields without sub-selections) must be scalar or enum types. | TODO |
| SingleFieldSubscriptionsRule | Subscription operations must contain exactly one root field. | TODO |
| UniqueArgumentNamesRule | Argument names must be unique within a field or directive call. | TODO |
| UniqueDirectivesPerLocationRule | Directives that are not repeatable must appear at most once per location. | TODO |
| UniqueFragmentNamesRule | Fragment names must be unique within a document. | COMPLETE |
| UniqueInputFieldNamesRule | Input field names must be unique within an input object value. | TODO |
| UniqueOperationNamesRule | Operation names must be unique within a document. | COMPLETE |
| UniqueVariableNamesRule | Variable names must be unique within an operation. | TODO |
| ValuesOfCorrectTypeRule | Input values must be compatible with their expected input types. | TODO |
| VariablesAreInputTypesRule | Variables must be of input types (scalar, enum, or input object). | TODO |
| VariablesInAllowedPositionRule | Variables must be used in locations compatible with their defined types. | TODO |
| **Schema Definition Rules** | | |
| LoneSchemaDefinitionRule | A document must contain at most one schema definition. | TODO |
| UniqueOperationTypesRule | There must be at most one of each operation type (query, mutation, subscription) in a schema definition. | TODO |
| UniqueTypeNamesRule | Type names must be unique within a schema. | TODO |
| UniqueEnumValueNamesRule | Enum value names must be unique within an enum type definition. | TODO |
| UniqueFieldDefinitionNamesRule | Field names must be unique within an object, interface, or input object type definition. | TODO |
| UniqueArgumentDefinitionNamesRule | Argument names must be unique within a field or directive definition. | TODO |
| UniqueDirectiveNamesRule | Directive names must be unique within the schema. | TODO |
| PossibleTypeExtensionsRule | Type extensions must extend a type that exists in the schema. | TODO |
| **Recommended Security Rules** | | |
| MaxIntrospectionDepthRule | Introspection queries must not exceed a depth limit to prevent DoS attacks. | TODO |

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