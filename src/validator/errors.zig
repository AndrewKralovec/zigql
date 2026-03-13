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
    MultipleAnonymousOperations,
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
    /// A GraphQL document is only valid if all `...Fragment` fragment spreads refer
    /// to fragments defined in the same document.
    ///
    /// See https://spec.graphql.org/draft/#sec-Fragment-spread-target-defined
    UndefinedFragment,
    /// No unused fragments
    ///
    /// A GraphQL document is only valid if all fragment definitions are spread
    /// within operations, or spread within other fragments spread within operations.
    ///
    /// See https://spec.graphql.org/draft/#sec-Fragments-Must-Be-Used
    UnusedFragment,
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
    /// Known argument names
    ///
    /// A GraphQL field is only valid if all supplied arguments are defined by
    /// that field.
    ///
    /// See https:///spec.graphql.org/draft/#sec-Argument-Names
    /// See https://spec.graphql.org/draft/#sec-Directives-Are-In-Valid-Locations
    UndefinedArgument,
    /// Unique input field names
    ///
    /// A GraphQL input object value is only valid if all supplied fields are
    /// uniquely named.
    ///
    /// See https://spec.graphql.org/draft/#sec-Input-Object-Field-Uniqueness
    DuplicateInputField,
    /// No undefined variables
    ///
    /// A GraphQL operation is only valid if all variables encountered, both directly
    /// and via fragment spreads, are defined by that operation.
    ///
    /// See https://spec.graphql.org/draft/#sec-All-Variable-Uses-Defined
    UndefinedVariable,
    /// No unused variables
    ///
    /// A GraphQL operation is only valid if all variables defined by an operation
    /// are used, either directly or within a spread fragment.
    ///
    /// See https://spec.graphql.org/draft/#sec-All-Variables-Used
    UnusedVariable,
    /// Reserved names
    ///
    /// Names beginning with "__" (two underscores) are reserved by the
    /// GraphQL introspection system and must not be used by user-defined entities.
    ///
    /// See https://spec.graphql.org/draft/#sec-Names.Reserved-Names
    ReservedName,
    /// Single root field subscriptions
    ///
    /// A subscription operation must have exactly one root field.
    ///
    /// See https://spec.graphql.org/draft/#sec-Single-root-field
    SubscriptionMultipleRootFields,
    /// Subscription must not use introspection fields
    ///
    /// The root field of a subscription operation must not be an introspection
    /// field like __schema or __type.
    ///
    /// See https://spec.graphql.org/draft/#sec-Single-root-field
    SubscriptionIntrospection,
    /// Subscription must not use conditional selection
    ///
    /// The root selections of a subscription must not use @skip or @include directives.
    ///
    /// See https://spec.graphql.org/draft/#sec-Single-root-field
    SubscriptionConditionalSelection,
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
