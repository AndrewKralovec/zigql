const std = @import("std");
const ast = @import("../grammar/ast.zig");
const ValidationContext = @import("validation_context.zig").ValidationContext;

// TODO: im using this file to basically house the tests
// break this up and make it more readable once i settle on the testing structure

const document_validation = @import("validations/document.zig");

pub fn validateDocument(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
    try document_validation.validateDocument(ctx, doc);
}

pub fn validateSchema(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
    try document_validation.validateSchema(ctx, doc);
}

//
// Tests
//

const parse = @import("../zig_ql.zig").parse;
const Schema = @import("./schema.zig").Schema;
const ValidationErrorKind = @import("errors.zig").ValidationErrorKind;

// LoneAnonymousOperation

test "should allow no operations" {
    try expectErrorCount(
        \\ fragment fragA on Type {
        \\   field
        \\ }
    ,
        0,
        .MultipleAnonymousOperations,
    );
}

test "should allow one operation" {
    try expectValid(
        \\ {
        \\   field
        \\ }
    );
}

test "should allow multiple named operations" {
    try expectValid(
        \\ query Foo {
        \\   field
        \\ }
        \\ query Bar {
        \\   field
        \\ }
    );
}

test "should allow anonymous operation with fragment" {
    try expectValid(
        \\ {
        \\   ...Foo
        \\ }
        \\ fragment Foo on Type {
        \\   field
        \\ }
    );
}

test "should return errors when multiple anon operations are used" {
    try expectErrors(
        \\ {
        \\   fieldA
        \\ }
        \\ {
        \\   fieldB
        \\ }
    , 2);
}

test "should return errors when anon operation with a mutation are used" {
    try expectErrors(
        \\ {
        \\   fieldA
        \\ }
        \\ mutation Foo {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when anon operation with a subscription are used" {
    try expectErrors(
        \\ {
        \\   fieldA
        \\ }
        \\ subscription Foo {
        \\   fieldB
        \\ }
    , 1);
}

// UniqueOperationNames

test "should allow no operations for unique operation names" {
    // fragment fragA is unused, no operations reference itv
    try expectErrors(
        \\ fragment fragA on Type {
        \\   field
        \\ }
    , 1);
}

test "should allow anonymous operation" {
    try expectValid(
        \\ {
        \\  field
        \\ }
    );
}

test "should allow one operation for unique operation names" {
    try expectValid(
        \\ query Foo {
        \\   field
        \\ }
    );
}

test "should allow multiple operations" {
    try expectValid(
        \\ query Foo {
        \\   field
        \\ }
        \\ query Bar {
        \\   field
        \\ }
    );
}

test "should allow multiple operations with different types" {
    try expectValid(
        \\ query Foo {
        \\   field
        \\ }
        \\ mutation Bar {
        \\   field
        \\ }
        \\ subscription Baz {
        \\   field
        \\ }
    );
}

test "should allow fragment and operation named the same" {
    try expectValid(
        \\ query Foo {
        \\   ...Foo
        \\ }
        \\ fragment Foo on Type {
        \\   field
        \\ }
    );
}

test "should return errors when operations have the same name" {
    try expectErrors(
        \\ query Foo {
        \\   fieldA
        \\ }
        \\ query Foo {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when operations ops of same name and different types (mutation)" {
    try expectErrors(
        \\ query Foo {
        \\   fieldA
        \\ }
        \\ mutation Foo {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when operations ops of same name and different types (subscription)" {
    try expectErrors(
        \\ query Foo {
        \\   fieldA
        \\ }
        \\ subscription Foo {
        \\   fieldB
        \\ }
    , 1);
}

// UniqueVariableNamesRule

test "should allow operations with no variables" {
    try expectValid(
        \\ query {
        \\   field
        \\ }
    );
}

test "should allow unique variable names" {
    try expectValid(
        \\ query A($x: Int, $y: String) { field(a: $x, b: $y) }
        \\ query B($x: String, $y: Int) { field(a: $x, b: $y) }
    );
}

test "should return errors for duplicate variables with different types" {
    try expectErrorCount(
        \\ query($bar: String, $foo: Int, $bar: Boolean) {
        \\   field
        \\ }
    ,
        1,
        .DuplicateVariableName,
    );
}

test "should return errors for duplicate variable names" {
    // query A: $x x3 => 2 errors (one for each occurrence after the first)
    // query B: $x x2 => 1 error
    // query C: $x x2 => 1 error
    // total  : 4 errors

    try expectErrorCount(
        \\ query A($x: Int, $x: Int, $x: String) { __typename }
        \\ query B($x: String, $x: Int) { __typename }
        \\ query C($x: Int, $x: Int) { __typename }
    ,
        4,
        .DuplicateVariableName,
    );
}

// UniqueArgumentNamesRule

test "should allow fields with no arguments" {
    try expectValid(
        \\ {
        \\   field
        \\ }
    );
}

test "should allow no arguments on directive" {
    try expectErrorsWithSchema(
        \\directive @directive on FIELD
    ,
        \\ {
        \\   field @directive
        \\ }
    , 0);
}

test "should allow fields with one argument" {
    try expectValid(
        \\ {
        \\   field(arg: "value")
        \\ }
    );
}

test "should allow argument on directive" {
    try expectErrorsWithSchema(
        \\directive @directive(arg: String) on FIELD
    ,
        \\ {
        \\   field @directive(arg: "value")
        \\ }
    , 0);
}

test "should allow same argument on two fields" {
    try expectValid(
        \\ {
        \\   one: field(arg: "value")
        \\   two: field(arg: "value")
        \\ }
    );
}

test "should allow same argument on field and directive" {
    try expectErrorsWithSchema(
        \\directive @directive(arg: String) on FIELD
    ,
        \\ {
        \\   field(arg: "value") @directive(arg: "value")
        \\ }
    , 0);
}

test "should allow same argument on two directives" {
    try expectErrorsWithSchema(
        \\directive @directive1(arg: String) on FIELD
        \\directive @directive2(arg: String) on FIELD
    ,
        \\ {
        \\   field @directive1(arg: "value") @directive2(arg: "value")
        \\ }
    , 0);
}

test "should allow multiple field arguments" {
    try expectValid(
        \\ {
        \\   field(arg1: "value", arg2: "value", arg3: "value")
        \\ }
    );
}

test "should allow multiple directive arguments" {
    try expectErrorsWithSchema(
        \\directive @directive(arg1: String, arg2: String, arg3: String) on FIELD
    ,
        \\ {
        \\   field @directive(arg1: "value", arg2: "value", arg3: "value")
        \\ }
    , 0);
}

test "should return errors on duplicate field arguments" {
    try expectErrors(
        \\ {
        \\   field(arg1: "value", arg1: "value")
        \\ }
    , 1);
}

test "should return errors on many duplicate field arguments" {
    try expectErrors(
        \\ {
        \\   field(arg1: "value", arg1: "value", arg1: "value")
        \\ }
    , 2);
}

test "should return errors on duplicate directive arguments" {
    try expectErrorsWithSchema(
        \\directive @directive(arg1: String) on FIELD
    ,
        \\ {
        \\   field @directive(arg1: "value", arg1: "value")
        \\ }
    , 1);
}

test "should return errors on many duplicate directive arguments" {
    try expectErrorsWithSchema(
        \\directive @directive(arg1: String) on FIELD
    ,
        \\ {
        \\   field @directive(arg1: "value", arg1: "value", arg1: "value")
        \\ }
    , 2);
}

// UniqueFragmentNamesRule

test "should allow no fragments" {
    try expectValid(
        \\ {
        \\   field
        \\ }
    );
}

test "should allow one fragment" {
    try expectValid(
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   field
        \\ }
    );
}

test "should allow many fragment" {
    try expectValid(
        \\ {
        \\   ...fragA
        \\   ...fragB
        \\   ...fragC
        \\ }
        \\ fragment fragA on Type {
        \\   fieldA
        \\ }
        \\ fragment fragB on Type {
        \\   fieldB
        \\ }
        \\ fragment fragC on Type {
        \\   fieldC
        \\ }
    );
}

test "should allow unique inline fragments" {
    try expectValid(
        \\ {
        \\   ...on Type {
        \\     fieldA
        \\   }
        \\   ...on Type {
        \\     fieldB
        \\   }
        \\ }
    );
}

test "should allow a fragment and operation named the same" {
    try expectValid(
        \\ query Foo {
        \\   ...Foo
        \\ }
        \\ fragment Foo on Type {
        \\   field
        \\ }
    );
}

test "should return errors when fragments are named the same" {
    try expectErrors(
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   fieldA
        \\ }
        \\ fragment fragA on Type {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when fragments named the same without being referenced" {
    try expectErrorCount(
        \\ fragment fragA on Type {
        \\   fieldA
        \\ }
        \\ fragment fragA on Type {
        \\   fieldB
        \\ }
    ,
        1,
        .DuplicateFragmentName,
    );
}

// KnownFragmentNamesRule

test "should allow known fragment names" {
    try expectErrors(
        \\ {
        \\   human(id: 4) {
        \\     ...HumanFields1
        \\     ... on Human {
        \\       ...HumanFields2
        \\     }
        \\     ... {
        \\       name
        \\     }
        \\   }
        \\ }
        \\ fragment HumanFields1 on Human {
        \\   name
        \\   ...HumanFields3
        \\ }
        \\ fragment HumanFields2 on Human {
        \\   name
        \\ }
        \\ fragment HumanFields3 on Human {
        \\   name
        \\ }
    , 0);
}

test "should return errors when fragment names are unknown" {
    try expectErrorCount(
        \\ {
        \\   human(id: 4) {
        \\     ...UnknownFragment1
        \\     ... on Human {
        \\       ...UnknownFragment2
        \\     }
        \\   }
        \\ }
        \\ fragment HumanFields on Human {
        \\   name
        \\   ...UnknownFragment3
        \\ }
    ,
        3,
        .UndefinedFragment,
    );
}

test "should allow known fragment spread defined before use" {
    try expectValid(
        \\ fragment fragA on Type {
        \\   field
        \\ }
        \\ {
        \\   ...fragA
        \\ }
    );
}

test "should return errors for undefined and duplicate fragment" {
    // fragA is defined twice, 1 duplicate error
    // fragB is undefined, 1 undefined error
    try expectErrors(
        \\ {
        \\   ...fragA
        \\   ...fragB
        \\ }
        \\ fragment fragA on Type {
        \\   field
        \\ }
        \\ fragment fragA on Type {
        \\   field
        \\ }
    , 2);
}

// NoUnusedFragmentsRule

test "should allow all fragment names to be used" {
    try expectValid(
        \\ query Foo {
        \\   human(id: 4) {
        \\     ...HumanFields1
        \\     ... on Human {
        \\       ...HumanFields2
        \\     }
        \\   }
        \\ }
        \\ fragment HumanFields1 on Human {
        \\   name
        \\   ...HumanFields3
        \\ }
        \\ fragment HumanFields2 on Human {
        \\   name
        \\ }
        \\ fragment HumanFields3 on Human {
        \\   name
        \\ }
    );
}

test "should allow all fragment names to be used by multiple operations" {
    try expectValid(
        \\ query Foo {
        \\   human(id: 4) {
        \\     ...HumanFields1
        \\   }
        \\ }
        \\ query Bar {
        \\   human(id: 4) {
        \\     ...HumanFields2
        \\   }
        \\ }
        \\ fragment HumanFields1 on Human {
        \\   name
        \\ }
        \\ fragment HumanFields2 on Human {
        \\   name
        \\ }
    );
}

test "should allow fragments used by other fragments" {
    try expectValid(
        \\ query Foo {
        \\   human(id: 4) {
        \\     ...HumanFields1
        \\   }
        \\ }
        \\ fragment HumanFields1 on Human {
        \\   name
        \\   ...HumanFields2
        \\ }
        \\ fragment HumanFields2 on Human {
        \\   name
        \\ }
    );
}

test "should allow deeply nested transitive fragment usage" {
    try expectValid(
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   ...fragB
        \\ }
        \\ fragment fragB on Type {
        \\   ...fragC
        \\ }
        \\ fragment fragC on Type {
        \\   field
        \\ }
    );
}

test "should detect unused fragment" {
    try expectErrors(
        \\ query Foo {
        \\   human(id: 4) {
        \\     ...HumanFields1
        \\   }
        \\ }
        \\ fragment HumanFields1 on Human {
        \\   name
        \\ }
        \\ fragment HumanFields2 on Human {
        \\   name
        \\ }
    , 1);
}

test "should return errors for multiple unused fragments" {
    try expectErrors(
        \\ {
        \\   field
        \\ }
        \\ fragment fragA on Type {
        \\   fieldA
        \\ }
        \\ fragment fragB on Type {
        \\   fieldB
        \\ }
    , 2);
}

test "should return errors when fragment is only used by another unused fragment" {
    try expectErrors(
        \\ {
        \\   field
        \\ }
        \\ fragment fragA on Type {
        \\   ...fragB
        \\ }
        \\ fragment fragB on Type {
        \\   field
        \\ }
    , 2);
}

test "should allow fragment used alongside inline fragments" {
    try expectValid(
        \\ {
        \\   ... on Type {
        \\     ...fragA
        \\   }
        \\ }
        \\ fragment fragA on Type {
        \\   field
        \\ }
    );
}

test "should allow fragment used in nested field selection" {
    try expectValid(
        \\ {
        \\   parent {
        \\     ...fragA
        \\   }
        \\ }
        \\ fragment fragA on Type {
        \\   field
        \\ }
    );
}

// NoFragmentCyclesRule

test "should detect direct fragment cycle (self-reference)" {
    try expectErrorCount(
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   ...fragA
        \\ }
    , 1, .RecursiveFragmentDefinition);
}

test "should detect mutual fragment cycle" {
    try expectErrorCount(
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   ...fragB
        \\ }
        \\ fragment fragB on Type {
        \\   ...fragA
        \\ }
    , 1, .RecursiveFragmentDefinition);
}

test "should detect three-fragment cycle" {
    try expectErrorCount(
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   ...fragB
        \\ }
        \\ fragment fragB on Type {
        \\   ...fragC
        \\ }
        \\ fragment fragC on Type {
        \\   ...fragA
        \\ }
    , 1, .RecursiveFragmentDefinition);
}

test "should allow linear fragment chain without cycle" {
    try expectErrorCount(
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   ...fragB
        \\ }
        \\ fragment fragB on Type {
        \\   ...fragC
        \\ }
        \\ fragment fragC on Type {
        \\   field
        \\ }
    , 0, .RecursiveFragmentDefinition);
}

test "should detect fragment cycle through inline fragment" {
    try expectErrorCount(
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   ... on Type {
        \\     ...fragA
        \\   }
        \\ }
    , 1, .RecursiveFragmentDefinition);
}

test "should detect fragment cycle through nested field" {
    try expectErrorCount(
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   field {
        \\     ...fragA
        \\   }
        \\ }
    , 1, .RecursiveFragmentDefinition);
}

test "should not report cycle for fragment spreading different fragments" {
    try expectErrorCount(
        \\ {
        \\   ...fragA
        \\   ...fragB
        \\ }
        \\ fragment fragA on Type {
        \\   ...fragC
        \\ }
        \\ fragment fragB on Type {
        \\   ...fragC
        \\ }
        \\ fragment fragC on Type {
        \\   field
        \\ }
    , 0, .RecursiveFragmentDefinition);
}

// KnownArgumentNamesRule, field argument tests

test "should allow known arguments on field defined in schema" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   dog(name: String, breed: String): Dog
        \\ }
        \\ type Dog {
        \\   name: String
        \\ }
    ,
        \\ {
        \\   dog(name: "Rex", breed: "Husky") { name }
        \\ }
    , 0);
}

test "should return error for unknown argument on field" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   dog(name: String): Dog
        \\ }
        \\ type Dog {
        \\   name: String
        \\ }
    ,
        \\ {
        \\   dog(unknown: true) { name }
        \\ }
    , 1);
}

test "should return errors for multiple unknown arguments on field" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   dog(name: String): Dog
        \\ }
        \\ type Dog {
        \\   name: String
        \\ }
    ,
        \\ {
        \\   dog(bad1: true, bad2: false) { name }
        \\ }
    , 2);
}

test "should return error for mixed known and unknown arguments on field" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   dog(name: String): Dog
        \\ }
        \\ type Dog {
        \\   name: String
        \\ }
    ,
        \\ {
        \\   dog(name: "Rex", unknown: true) { name }
        \\ }
    , 1);
}

test "should allow field with no arguments when none defined" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   dog: Dog
        \\ }
        \\ type Dog {
        \\   name: String
        \\ }
    ,
        \\ {
        \\   dog { name }
        \\ }
    , 0);
}

test "should not error for arguments on field not defined in schema" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   dog: Dog
        \\ }
        \\ type Dog {
        \\   name: String
        \\ }
    ,
        \\ {
        \\   unknownField(arg: true)
        \\ }
    , 0);
}

test "should validate field arguments inside fragment with type condition" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   dog: Dog
        \\ }
        \\ type Dog {
        \\   name(style: String): String
        \\ }
    ,
        \\ {
        \\   ...DogFields
        \\ }
        \\ fragment DogFields on Dog {
        \\   name(unknown: true)
        \\ }
    , 2); // InvalidFragmentSpread (Dog fragment on Query) + UndefinedArgument
}

test "should validate field arguments on interface via inline fragment" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   node: Node
        \\ }
        \\ interface Node {
        \\   id(format: String): ID
        \\ }
    ,
        \\ {
        \\   ... on Node {
        \\     id(bad: true)
        \\   }
        \\ }
    , 2); // InvalidFragmentSpread (Node fragment on Query) + UndefinedArgument
}

// KnownArgumentNamesRule, directive argument tests

test "should allow when directive args are known" {
    try expectValid(
        \\ {
        \\   dog @skip(if: true)
        \\ }
    );
}

test "should return errors when field args are invalid" {
    try expectErrors(
        \\ {
        \\   dog @skip(unless: true)
        \\ }
    , 1);
}

test "should allow when directive without args is valid" {
    try expectErrorsWithSchema(
        \\directive @onField on FIELD
    ,
        \\ {
        \\   dog @onField
        \\ }
    , 0);
}

test "should return errors when misspelled directive args are reported" {
    try expectErrors(
        \\ {
        \\   dog @skip(iff: true)
        \\ }
    , 1);
}

test "should allow known arguments on multiple directives" {
    try expectValid(
        \\ {
        \\   field @skip(if: true) @include(if: false)
        \\ }
    );
}

test "should return error for unknown argument on include directive" {
    try expectErrors(
        \\ {
        \\   field @include(when: true)
        \\ }
    , 1);
}

test "should return error for unknown argument on deprecated directive" {
    // 1 UndefinedArgument ("message" is not valid, "reason" is) +
    // 1 UnsupportedDirectiveLocation (@deprecated not valid on FIELD)
    try expectErrors(
        \\ {
        \\   field @deprecated(message: "old")
        \\ }
    , 2);
}

test "should return errors for multiple unknown arguments on directive" {
    try expectErrors(
        \\ {
        \\   field @skip(unless: true, when: false)
        \\ }
    , 2);
}

test "should return error for mixed known and unknown directive arguments" {
    try expectErrors(
        \\ {
        \\   field @skip(if: true, unless: false)
        \\ }
    , 1);
}

// KnownArgumentNamesRule, custom directive tests

test "should allow known args on custom directive" {
    try expectErrorsWithSchema(
        \\ directive @myDirective(arg1: String, arg2: Int) on FIELD
    ,
        \\ {
        \\   field @myDirective(arg1: "hello", arg2: 42)
        \\ }
    , 0);
}

test "should return error for unknown arg on custom directive" {
    try expectErrorsWithSchema(
        \\ directive @myDirective(arg1: String) on FIELD
    ,
        \\ {
        \\   field @myDirective(unknown: true)
        \\ }
    , 1);
}

test "should return errors for multiple unknown args on custom directive" {
    try expectErrorsWithSchema(
        \\ directive @myDirective(arg1: String) on FIELD
    ,
        \\ {
        \\   field @myDirective(bad1: true, bad2: false)
        \\ }
    , 2);
}

test "should return error for mix of known and unknown args on custom directive" {
    try expectErrorsWithSchema(
        \\ directive @myDirective(arg1: String, arg2: Int) on FIELD
    ,
        \\ {
        \\   field @myDirective(arg1: "hello", unknown: true)
        \\ }
    , 1);
}

test "should return error for undefined directive" {
    try expectErrorsWithSchema(
        \\ directive @other(x: String) on FIELD
    ,
        \\ {
        \\   field @unknownDirective(arg: true)
        \\ }
    , 1);
}

test "should allow custom directive with no args when definition has no args" {
    try expectErrorsWithSchema(
        \\ directive @simple on FIELD
    ,
        \\ {
        \\   field @simple
        \\ }
    , 0);
}

// KnownDirectivesRule (UndefinedDirective)

test "should allow built-in directive @skip on field" {
    try expectValid(
        \\ {
        \\   field @skip(if: true)
        \\ }
    );
}

test "should allow built-in directive @include on field" {
    try expectValid(
        \\ {
        \\   field @include(if: false)
        \\ }
    );
}

test "should allow schema-defined directive" {
    try expectErrorsWithSchema(
        \\directive @custom on FIELD
    ,
        \\ {
        \\   field @custom
        \\ }
    , 0);
}

test "should return error for single undefined directive" {
    try expectErrorCount(
        \\ {
        \\   field @unknown
        \\ }
    , 1, .UndefinedDirective);
}

test "should return errors for multiple undefined directives" {
    try expectErrorCount(
        \\ {
        \\   field @unknown1 @unknown2
        \\ }
    , 2, .UndefinedDirective);
}

// DirectivesAreInValidLocationsRule (UnsupportedDirectiveLocation)

test "should allow @skip on field" {
    try expectErrorCount(
        \\ {
        \\   field @skip(if: true)
        \\ }
    , 0, .UnsupportedDirectiveLocation);
}

test "should allow @skip on fragment spread" {
    try expectErrorCount(
        \\ {
        \\   ...fragA @skip(if: true)
        \\ }
        \\ fragment fragA on Type {
        \\   field
        \\ }
    , 0, .UnsupportedDirectiveLocation);
}

test "should allow @skip on inline fragment" {
    try expectErrorCount(
        \\ {
        \\   ... @skip(if: true) {
        \\     field
        \\   }
        \\ }
    , 0, .UnsupportedDirectiveLocation);
}

test "should return error for @deprecated on field" {
    try expectErrorCount(
        \\ {
        \\   field @deprecated(reason: "old")
        \\ }
    , 1, .UnsupportedDirectiveLocation);
}

test "should allow @deprecated on field definition in schema" {
    try expectSchemaErrors(
        \\type Query {
        \\  field: String @deprecated(reason: "use newField")
        \\}
    , 0);
}

test "should return error for custom directive at wrong location" {
    try expectErrorsWithSchema(
        \\directive @fieldOnly on FIELD
    ,
        \\ query @fieldOnly {
        \\   field
        \\ }
    , 1);
}

test "should allow custom directive at valid location" {
    try expectErrorsWithSchema(
        \\directive @onQuery on QUERY
    ,
        \\ query @onQuery {
        \\   field
        \\ }
    , 0);
}

// UniqueDirectivesPerLocationRule (DuplicateDirective)

test "should allow different directives on same field" {
    try expectValid(
        \\ {
        \\   field @skip(if: true) @include(if: false)
        \\ }
    );
}

test "should return error for duplicate non-repeatable directive" {
    try expectErrorCount(
        \\ {
        \\   field @skip(if: true) @skip(if: false)
        \\ }
    , 1, .DuplicateDirective);
}

test "should allow repeatable custom directive multiple times" {
    try expectErrorsWithSchema(
        \\directive @tag repeatable on FIELD
    ,
        \\ {
        \\   field @tag @tag @tag
        \\ }
    , 0);
}

test "should return error for duplicate non-repeatable custom directive" {
    try expectErrorsWithSchema(
        \\directive @once on FIELD
    ,
        \\ {
        \\   field @once @once
        \\ }
    , 1);
}

// UniqueInputFieldNamesRule

test "should allow input object with fields" {
    try expectValid(
        \\ {
        \\   field(arg: { f: true })
        \\ }
    );
}

test "should allow input object with no fields" {
    try expectValid(
        \\ {
        \\   field(arg: {})
        \\ }
    );
}

test "should allow input object within two args" {
    try expectValid(
        \\ {
        \\   field(arg1: { f: true }, arg2: { f: true })
        \\ }
    );
}

test "should allow multiple input object fields" {
    try expectValid(
        \\ {
        \\   field(arg: { f1: "value", f2: "value", f3: "value" })
        \\ }
    );
}

test "should allow for nested input objects with similar fields" {
    try expectValid(
        \\ {
        \\   field(arg: {
        \\     deep: {
        \\       deep: {
        \\         id: 1
        \\       }
        \\       id: 1
        \\     }
        \\     id: 1
        \\   })
        \\ }
    );
}

test "should return errors on duplicate input object fields" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   field(arg: SomeInput): String
        \\ }
        \\ input SomeInput {
        \\   f1: String
        \\ }
    ,
        \\ {
        \\   field(arg: { f1: "value", f1: "value" })
        \\ }
    , 1);
}

test "should return errors on many duplicate input object fields" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   field(arg: SomeInput): String
        \\ }
        \\ input SomeInput {
        \\   f1: String
        \\ }
    ,
        \\ {
        \\   field(arg: { f1: "value", f1: "value", f1: "value" })
        \\ }
    , 2);
}

test "should return errors on nested duplicate input object fields" {
    try expectErrorsWithSchema(
        \\ type Query {
        \\   field(arg: SomeInput): String
        \\ }
        \\ input SomeInput {
        \\   f1: NestedInput
        \\ }
        \\ input NestedInput {
        \\   f2: String
        \\ }
    ,
        \\ {
        \\   field(arg: { f1: {f2: "value", f2: "value" }})
        \\ }
    , 1);
}

// Schema test

// UniqueInputFieldNamesRule schema tests

test "should allow input object with unique fields via the schema" {
    try expectSchemaValid(
        \\ input Point {
        \\   x: Float
        \\   y: Float
        \\ }
    );
}

test "should return error for input object with duplicate fields via the schema" {
    try expectSchemaErrors(
        \\ input Point {
        \\   x: Float
        \\   x: Int
        \\ }
    , 1);
}

// NoUndefinedVariablesRule

test "should allow all variables to be defined" {
    try expectValid(
        \\ query Foo($a: String, $b: String) {
        \\   field(a: $a, b: $b)
        \\ }
    );
}

test "should return error for undefined variable" {
    try expectErrorCount(
        \\ query Foo {
        \\   field(a: $a)
        \\ }
    ,
        1,
        .UndefinedVariable,
    );
}

test "should return error for variable used in fragment but not defined in operation" {
    try expectErrorCount(
        \\ query Foo {
        \\   ...FragA
        \\ }
        \\ fragment FragA on Type {
        \\   field(a: $a)
        \\ }
    ,
        1,
        .UndefinedVariable,
    );
}

test "should allow variable defined in operation used in fragment" {
    try expectValid(
        \\ query Foo($a: String) {
        \\   ...FragA
        \\ }
        \\ fragment FragA on Type {
        \\   field(a: $a)
        \\ }
    );
}

test "should allow variable used in nested fragment" {
    try expectValid(
        \\ query Foo($a: String) {
        \\   ...FragA
        \\ }
        \\ fragment FragA on Type {
        \\   ...FragB
        \\ }
        \\ fragment FragB on Type {
        \\   field(a: $a)
        \\ }
    );
}

test "should return error for multiple undefined variables" {
    try expectErrorCount(
        \\ query Foo($a: String) {
        \\   field(a: $a, b: $b, c: $c)
        \\ }
    ,
        2,
        .UndefinedVariable,
    );
}

// NoUnusedVariablesRule

test "should return error for unused variable" {
    try expectErrorCount(
        \\ query Foo($a: String) {
        \\   field
        \\ }
    ,
        1,
        .UnusedVariable,
    );
}

test "should not return error when variable is used" {
    try expectValid(
        \\ query Foo($a: String) {
        \\   field(a: $a)
        \\ }
    );
}

test "should not return error when variable used in fragment" {
    try expectValid(
        \\ query Foo($a: String) {
        \\   ...FragA
        \\ }
        \\ fragment FragA on Type {
        \\   field(a: $a)
        \\ }
    );
}

test "should return error for multiple unused variables" {
    try expectErrorCount(
        \\ query Foo($a: String, $b: Int, $c: Float) {
        \\   field(a: $a)
        \\ }
    ,
        2,
        .UnusedVariable,
    );
}

test "should allow variable used in directive argument" {
    try expectValid(
        \\ query Foo($cond: Boolean) {
        \\   field @skip(if: $cond)
        \\ }
    );
}

// ReservedNameRule (schema-level only, matching Apollo-RS)

test "should return error for type name starting with __" {
    try expectSchemaErrors(
        \\ type __Foo {
        \\   field: String
        \\ }
    , 1);
}

test "should return error for enum name starting with __" {
    try expectSchemaErrors(
        \\ enum __Bar {
        \\   VALUE
        \\ }
    , 1);
}

test "should return error for directive name starting with __" {
    try expectSchemaErrors(
        \\ directive @__myDir on FIELD
    , 1);
}

test "should allow type with normal name" {
    try expectSchemaValid(
        \\ type Query {
        \\   field: String
        \\ }
    );
}

// EmptyValueSetRule (enum definitions)

test "should allow enum with values" {
    try expectSchemaValid(
        \\ enum Color {
        \\   RED
        \\   GREEN
        \\   BLUE
        \\ }
    );
}

test "should return error for enum with no values" {
    // The parser requires at least one value inside braces,
    // so we test the no-braces case where values is null.
    try expectSchemaErrorCount(
        \\ enum Empty @deprecated
    ,
        1,
        .EmptyValueSet,
    );
}

test "should return error for enum value name starting with __" {
    try expectSchemaErrorCount(
        \\ enum Bad {
        \\   __reserved
        \\ }
    ,
        1,
        .ReservedName,
    );
}

test "should allow enum value with normal name" {
    try expectSchemaValid(
        \\ enum Status {
        \\   ACTIVE
        \\   INACTIVE
        \\ }
    );
}

test "should return errors for multiple reserved enum value names" {
    try expectSchemaErrorCount(
        \\ enum Bad {
        \\   __one
        \\   __two
        \\   GOOD
        \\ }
    ,
        2,
        .ReservedName,
    );
}

// SubscriptionUsesMultipleFieldsRule

test "should allow subscription with one field" {
    try expectValid(
        \\ subscription Foo {
        \\   newMessage
        \\ }
    );
}

test "should return error for subscription with multiple fields" {
    try expectErrorCount(
        \\ subscription Foo {
        \\   newMessage
        \\   disallowedSecondField
        \\ }
    ,
        1,
        .SubscriptionMultipleRootFields,
    );
}

test "should return error for subscription with multiple fields via fragment" {
    try expectErrorCount(
        \\ subscription Foo {
        \\   ...multiFields
        \\ }
        \\ fragment multiFields on Subscription {
        \\   newMessage
        \\   disallowedSecondField
        \\ }
    ,
        1,
        .SubscriptionMultipleRootFields,
    );
}

// SubscriptionUsesIntrospectionRule

test "should return error for subscription using __schema" {
    try expectErrorCount(
        \\ subscription Foo {
        \\   __schema { queryType { name } }
        \\ }
    ,
        1,
        .SubscriptionIntrospection,
    );
}

test "should return error for subscription using __type" {
    try expectErrorCount(
        \\ subscription Foo {
        \\   __type(name: "Foo") { name }
        \\ }
    ,
        1,
        .SubscriptionIntrospection,
    );
}

// SubscriptionUsesConditionalSelectionRule

test "should return error for subscription with @skip on root field" {
    try expectErrorCount(
        \\ subscription Foo($cond: Boolean) {
        \\   newMessage @skip(if: $cond)
        \\ }
    ,
        1,
        .SubscriptionConditionalSelection,
    );
}

test "should return error for subscription with @include on root field" {
    try expectErrorCount(
        \\ subscription Foo($cond: Boolean) {
        \\   newMessage @include(if: $cond)
        \\ }
    ,
        1,
        .SubscriptionConditionalSelection,
    );
}

test "should allow subscription with @skip on nested field" {
    try expectValid(
        \\ subscription Foo($cond: Boolean) {
        \\   newMessage {
        \\     body @skip(if: $cond)
        \\   }
        \\ }
    );
}

// Test helpers

fn expectErrors(
    query_source: []const u8,
    expected_error_count: usize,
) !void {
    const allocator = std.testing.allocator;
    var schema = Schema.init(allocator);
    defer schema.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const query_doc = try parse(arena.allocator(), query_source);

    var ctx = ValidationContext.init(allocator, &schema);
    defer ctx.deinit();

    try validateDocument(&ctx, query_doc);

    std.testing.expectEqual(expected_error_count, ctx.errorCount()) catch |err| {
        std.debug.print("\nerrors={any}\n", .{ctx.errors.items});
        return err;
    };
}

fn expectValid(
    query_source: []const u8,
) !void {
    try expectErrors(query_source, 0);
}

const buildSchema = @import("./schema.zig").buildSchema;

fn expectErrorsWithSchema(
    schema_source: []const u8,
    query_source: []const u8,
    expected_error_count: usize,
) !void {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const schema_doc = try parse(arena.allocator(), schema_source);
    var s = try buildSchema(allocator, schema_doc);
    defer s.deinit();

    const query_doc = try parse(arena.allocator(), query_source);

    var ctx = ValidationContext.init(allocator, &s);
    defer ctx.deinit();

    try validateDocument(&ctx, query_doc);

    std.testing.expectEqual(expected_error_count, ctx.errorCount()) catch |err| {
        std.debug.print("\nerrors={any}\n", .{ctx.errors.items});
        return err;
    };
}

fn expectSchemaErrors(
    schema_source: []const u8,
    expected_error_count: usize,
) !void {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const doc = try parse(arena.allocator(), schema_source);

    var s = try buildSchema(allocator, doc);
    defer s.deinit();

    var ctx = ValidationContext.init(allocator, &s);
    defer ctx.deinit();

    try validateSchema(&ctx, doc);

    std.testing.expectEqual(expected_error_count, ctx.errorCount()) catch |err| {
        std.debug.print("\nschema errors={any}\n", .{ctx.errors.items});
        return err;
    };
}

fn expectErrorCount(
    query_source: []const u8,
    expected_error_count: usize,
    expected_error: ValidationErrorKind,
) !void {
    const allocator = std.testing.allocator;
    var schema = Schema.init(allocator);
    defer schema.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const query_doc = try parse(arena.allocator(), query_source);

    var ctx = ValidationContext.init(allocator, &schema);
    defer ctx.deinit();

    try validateDocument(&ctx, query_doc);

    var err_count: u32 = 0;
    for (ctx.errors.items) |err| {
        if (err.kind == expected_error) {
            err_count = err_count + 1;
        }
    }

    std.testing.expectEqual(expected_error_count, err_count) catch |err| {
        std.debug.print("\nerrors={any}\n", .{ctx.errors.items});
        return err;
    };
}

fn expectSchemaErrorCount(
    schema_source: []const u8,
    expected_error_count: usize,
    expected_error: ValidationErrorKind,
) !void {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const doc = try parse(arena.allocator(), schema_source);

    var s = try buildSchema(allocator, doc);
    defer s.deinit();

    var ctx = ValidationContext.init(allocator, &s);
    defer ctx.deinit();

    try validateSchema(&ctx, doc);

    var err_count: u32 = 0;
    for (ctx.errors.items) |err| {
        if (err.kind == expected_error) {
            err_count = err_count + 1;
        }
    }

    std.testing.expectEqual(expected_error_count, err_count) catch |err| {
        std.debug.print("\nschema errors={any}\n", .{ctx.errors.items});
        return err;
    };
}

fn expectSchemaValid(
    schema_source: []const u8,
) !void {
    try expectSchemaErrors(schema_source, 0);
}

fn expectErrorCountWithSchema(
    schema_source: []const u8,
    query_source: []const u8,
    expected_error_count: usize,
    expected_error: ValidationErrorKind,
) !void {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const schema_doc = try parse(arena.allocator(), schema_source);
    var s = try buildSchema(allocator, schema_doc);
    defer s.deinit();

    const query_doc = try parse(arena.allocator(), query_source);

    var ctx = ValidationContext.init(allocator, &s);
    defer ctx.deinit();

    try validateDocument(&ctx, query_doc);

    var err_count: u32 = 0;
    for (ctx.errors.items) |err| {
        if (err.kind == expected_error) {
            err_count = err_count + 1;
        }
    }

    std.testing.expectEqual(expected_error_count, err_count) catch |err| {
        std.debug.print("\nerrors={any}\n", .{ctx.errors.items});
        return err;
    };
}

// Union type validation

test "valid union with object members" {
    try expectSchemaValid(
        \\type Query { field: String }
        \\type Foo { a: String }
        \\type Bar { b: String }
        \\union MyUnion = Foo | Bar
    );
}

test "empty union should return EmptyMemberSet error" {
    try expectSchemaErrorCount(
        \\type Query { field: String }
        \\union MyUnion
    ,
        1,
        .EmptyMemberSet,
    );
}

test "union member must be object type" {
    try expectSchemaErrorCount(
        \\type Query { field: String }
        \\scalar MyScalar
        \\union MyUnion = MyScalar
    ,
        1,
        .UnionMemberObjectType,
    );
}

test "union member must be defined" {
    try expectSchemaErrorCount(
        \\type Query { field: String }
        \\union MyUnion = Undefined
    ,
        1,
        .UndefinedDefinition,
    );
}

test "union with multiple non-object members" {
    try expectSchemaErrorCount(
        \\type Query { field: String }
        \\scalar A
        \\enum B { X Y }
        \\union MyUnion = A | B
    ,
        2,
        .UnionMemberObjectType,
    );
}

// LeafFieldSelectionsRule

test "scalar field without subselection is valid" {
    try expectErrorCountWithSchema(
        \\type Query { name: String }
    ,
        \\{ name }
    , 0, .MissingSubselection);
}

test "enum field without subselection is valid" {
    try expectErrorCountWithSchema(
        \\type Query { status: Status }
        \\enum Status { ACTIVE INACTIVE }
    ,
        \\{ status }
    , 0, .MissingSubselection);
}

test "object field with subselection is valid" {
    try expectErrorCountWithSchema(
        \\type Query { dog: Dog }
        \\type Dog { name: String }
    ,
        \\{ dog { name } }
    , 0, .MissingSubselection);
}

test "interface field with subselection is valid" {
    try expectErrorCountWithSchema(
        \\type Query { node: Node }
        \\interface Node { id: ID }
    ,
        \\{ node { id } }
    , 0, .MissingSubselection);
}

test "union field with subselection is valid" {
    try expectErrorCountWithSchema(
        \\type Query { pet: Pet }
        \\type Dog { name: String }
        \\type Cat { name: String }
        \\union Pet = Dog | Cat
    ,
        \\{ pet { ... on Dog { name } } }
    , 0, .MissingSubselection);
}

test "object field without subselection returns MissingSubselection" {
    try expectErrorCountWithSchema(
        \\type Query { dog: Dog }
        \\type Dog { name: String }
    ,
        \\{ dog }
    , 1, .MissingSubselection);
}

test "interface field without subselection returns MissingSubselection" {
    try expectErrorCountWithSchema(
        \\type Query { node: Node }
        \\interface Node { id: ID }
    ,
        \\{ node }
    , 1, .MissingSubselection);
}

test "union field without subselection returns MissingSubselection" {
    try expectErrorCountWithSchema(
        \\type Query { pet: Pet }
        \\type Dog { name: String }
        \\type Cat { name: String }
        \\union Pet = Dog | Cat
    ,
        \\{ pet }
    , 1, .MissingSubselection);
}

test "scalar field with subselection returns SubselectionOnScalarType" {
    try expectErrorCountWithSchema(
        \\type Query { name: String }
    ,
        \\{ name { foo } }
    , 1, .SubselectionOnScalarType);
}

test "enum field with subselection returns SubselectionOnEnumType" {
    try expectErrorCountWithSchema(
        \\type Query { status: Status }
        \\enum Status { ACTIVE INACTIVE }
    ,
        \\{ status { foo } }
    , 1, .SubselectionOnEnumType);
}

test "non-null list of objects without subselection returns MissingSubselection" {
    try expectErrorCountWithSchema(
        \\type Query { dogs: [Dog!]! }
        \\type Dog { name: String }
    ,
        \\{ dogs }
    , 1, .MissingSubselection);
}

test "non-null list of objects with subselection is valid" {
    try expectErrorCountWithSchema(
        \\type Query { dogs: [Dog!]! }
        \\type Dog { name: String }
    ,
        \\{ dogs { name } }
    , 0, .MissingSubselection);
}
