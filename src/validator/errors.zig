const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ValidationErrorKind = enum {
    /// Executable definitions
    ///
    /// A GraphQL document is only valid for execution if all definitions are either
    /// operation or fragment definitions.
    ///
    /// See https://spec.graphql.org/draft/#sec-Executable-Definitions
    NonExecutableDefinition,
    /// Lone anonymous operation
    ///
    /// A GraphQL document is only valid if when it contains an anonymous operation
    /// (the query short-hand) that it contains only that one operation definition.
    ///
    /// See https:///spec.graphql.org/draft/#sec-Lone-Anonymous-Operation
    ManyAnonymousOperations,
    /// Unique operation names
    ///
    /// A GraphQL document is only valid if all defined operations have unique names.
    ///
    /// See https://spec.graphql.org/draft/#sec-Operation-Name-Uniqueness
    DuplicateOperationName,
    /// Unique fragment names
    ///
    /// A GraphQL document is only valid if all defined fragments have unique names.
    //
    /// See https://spec.graphql.org/draft/#sec-Fragment-Name-Uniqueness
    DuplicateFragmentName,
    /// Known fragment names
    ///
    /// A fragment spread must refer to a fragment that is defined in the same
    /// document.
    ///
    /// See https://spec.graphql.org/draft/#sec-Fragment-spread-target-defined
    UndefinedFragment,
    /// Unique variable names
    ///
    /// A GraphQL operation is only valid if all its variables are uniquely named.
    ///
    /// See https://spec.graphql.org/draft/#sec-Variable-Uniqueness
    DuplicateVariableName,
    /// Unique argument names
    ///
    /// A GraphQL field or directive is only valid if all supplied arguments are
    /// uniquely named.
    ///
    /// See https://spec.graphql.org/draft/#sec-Argument-Names
    DuplicateArgumentName,
};

// TODO: import the validation object in the future
// for now, let it be a wrapper around the error kind.
// i can just replace ValidationError with the enum, would be easy if i choose.
pub const ValidationError = struct {
    kind: ValidationErrorKind,

    pub fn init(kind: ValidationErrorKind) !ValidationError {
        return ValidationError{ .kind = kind };
    }

    pub fn deinit(self: *ValidationError) void {
        _ = self;
    }
};
