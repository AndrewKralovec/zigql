# ZigQL
A graphql parsing library written in zig.
After reading that [bun](https://bun.sh/) was coded in zig, i wanted to try it out.

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

### Lexer

The `Lexer` tokenizes GraphQL text into individual tokens. These tokens can then be processed by the parser or analyzed directly.


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
    std.debug.print("Token={any}\n", .{ token });
}
for (result.errors) |err| {
    std.debug.print("Error={any}\n", .{ err });
}
```

### Parser
The `Parser` converts GraphQL text into a structured representation of GraphQL nodes (AST). This is used for analyzing or transforming GraphQL operations. The nodes can contain slices, and you must free these slices after use to avoid memory leaks.

```zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit(); // Free memory

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

for (doc.definitions) |def| {
    if (def.ExecutableDefinition == .OperationDefinition) {
        const operationDef = def.ExecutableDefinition.OperationDefinition;
        std.debug.print("Operations={any}\n", .{operationDef});
    }
}
```

## TODO

### Known Issues

#### LLVM Issue
There seems to be a problem with the LLVM version when splitting long-running functions into smaller ones. Investigate why valid syntax raises issues with LLVM 18.1.7. Once this is resolved we can clean up the code.

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

### Inspiration And Resources
This project was inspired by a mix of curiosity for [zig](https://ziglang.org/), and a desire to see its use in web services.

I also drew inspiration from existing GraphQL libraries like [graphql-js](https://github.com/graphql/graphql-js) ([MIT](https://github.com/apollographql/apollo-rs/blob/main/LICENSE-MIT)) and [apollo-rs](https://github.com/apollographql/apollo-rs) ([MIT](https://github.com/apollographql/apollo-rs/blob/main/LICENSE-MIT)). They provided a great reference for how a GraphQL parser should behave.

This project follows the [October 2021 GraphQL specification](https://spec.graphql.org/October2021) for its grammar and parsing rules.