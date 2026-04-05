const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ValidationErrorKind = enum {
    // ExecutableDefinitionsRule
    /// Executable definitions
    ///
    /// A GraphQL document is only valid for execution if all definitions are either
    /// operation or fragment definitions.
    ///
    /// See https://spec.graphql.org/draft/#sec-Executable-Definitions
    NonExecutableDefinition,
    // LoneAnonymousOperationRule
    /// Lone anonymous operation
    ///
    /// A GraphQL document is only valid if when it contains an anonymous operation
    /// (the query short-hand) that it contains only that one operation definition.
    ///
    /// See https://spec.graphql.org/draft/#sec-Lone-Anonymous-Operation
    MultipleAnonymousOperations,
    // UniqueOperationNamesRule
    /// Unique operation names
    ///
    /// A GraphQL document is only valid if all defined operations have unique names.
    ///
    /// See https://spec.graphql.org/draft/#sec-Operation-Name-Uniqueness
    DuplicateOperationName,
    // UniqueFragmentNamesRule
    /// Unique fragment names
    ///
    /// A GraphQL document is only valid if all defined fragments have unique names.
    //
    /// See https://spec.graphql.org/draft/#sec-Fragment-Name-Uniqueness
    DuplicateFragmentName,
    // KnownFragmentNamesRule
    /// Known fragment names
    ///
    /// A GraphQL document is only valid if all `...Fragment` fragment spreads refer
    /// to fragments defined in the same document.
    ///
    /// See https://spec.graphql.org/draft/#sec-Fragment-spread-target-defined
    UndefinedFragment,
    // NoUnusedFragmentsRule
    /// No unused fragments
    ///
    /// A GraphQL document is only valid if all fragment definitions are spread
    /// within operations, or spread within other fragments spread within operations.
    ///
    /// See https://spec.graphql.org/draft/#sec-Fragments-Must-Be-Used
    UnusedFragment,
    // UniqueVariableNamesRule
    /// Unique variable names
    ///
    /// A GraphQL operation is only valid if all its variables are uniquely named.
    ///
    /// See https://spec.graphql.org/draft/#sec-Variable-Uniqueness
    DuplicateVariableName,
    // UniqueArgumentNamesRule
    /// Unique argument names
    ///
    /// A GraphQL field or directive is only valid if all supplied arguments are
    /// uniquely named.
    ///
    /// See https://spec.graphql.org/draft/#sec-Argument-Names
    DuplicateArgumentName,
    // KnownArgumentNamesRule
    /// Known argument names
    ///
    /// A GraphQL field is only valid if all supplied arguments are defined by
    /// that field.
    ///
    /// See https:///spec.graphql.org/draft/#sec-Argument-Names
    /// See https://spec.graphql.org/draft/#sec-Directives-Are-In-Valid-Locations
    UndefinedArgument,
    // UniqueInputFieldNamesRule
    /// Unique input field names
    ///
    /// A GraphQL input object value is only valid if all supplied fields are
    /// uniquely named.
    ///
    /// See https://spec.graphql.org/draft/#sec-Input-Object-Field-Uniqueness
    DuplicateInputField,
    // NoUndefinedVariablesRule
    /// No undefined variables
    ///
    /// A GraphQL operation is only valid if all variables encountered, both directly
    /// and via fragment spreads, are defined by that operation.
    ///
    /// See https://spec.graphql.org/draft/#sec-All-Variable-Uses-Defined
    UndefinedVariable,
    // NoUnusedVariablesRule
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
    /// Required argument
    ///
    /// A field or directive argument is required if it has a non-null type
    /// and does not have a default value.
    ///
    /// See https://spec.graphql.org/draft/#sec-Required-Arguments
    RequiredArgument,
    // FieldsOnCorrectTypeRule
    /// Fields on correct type
    ///
    /// A GraphQL document is only valid if all fields selected are defined by the
    /// parent type, or are an allowed meta field such as __typename.
    ///
    /// See https://spec.graphql.org/draft/#sec-Field-Selections
    FieldNotFound,
    // ScalarLeafsRule
    /// Scalar leafs
    ///
    /// A GraphQL document is valid only if all leaf fields (fields without
    /// sub selections) are of scalar or enum types.
    ///
    /// See https://spec.graphql.org/draft/#sec-Leaf-Field-Selections
    MissingSubselection,
    // ScalarLeafsRule
    /// Scalar leafs
    ///
    /// Field selections on scalars must not have subselections.
    ///
    /// See https://spec.graphql.org/draft/#sec-Leaf-Field-Selections
    SubselectionOnScalarType,
    // ScalarLeafsRule
    /// Scalar leafs
    ///
    /// Field selections on enums must not have subselections.
    ///
    /// See https://spec.graphql.org/draft/#sec-Leaf-Field-Selections
    SubselectionOnEnumType,
    // ValuesOfCorrectTypeRule
    /// Value literals of correct type
    ///
    /// A GraphQL document is only valid if all value literals are of the type
    /// expected at their position.
    ///
    /// See https://spec.graphql.org/draft/#sec-Values-of-Correct-Type
    UnsupportedValueType,
    // VariablesInAllowedPositionRule
    /// Variables in allowed position
    ///
    /// Variable usages must be compatible with the arguments they are passed to.
    ///
    /// See https://spec.graphql.org/draft/#sec-All-Variable-Usages-Are-Allowed
    DisallowedVariableUsage,
    /// Empty value set
    ///
    /// An enum type must define one or more unique enum values.
    ///
    /// See https://spec.graphql.org/draft/#sel-DAHfFVFBAAEXBAAh7S
    EmptyValueSet,
    /// Empty member set
    ///
    /// A Union type must include one or more unique member types.
    ///
    /// See https://spec.graphql.org/draft/#sel-HAHdfFBABAB6Bw3R
    EmptyMemberSet,
    /// Union member object type
    ///
    /// The member types of a Union type must all be Object base types.
    ///
    /// See https://spec.graphql.org/draft/#sel-HAHdfFBABAB6Bw3R
    UnionMemberObjectType,
    /// Undefined definition
    ///
    /// A referenced type must be defined in the schema.
    ///
    /// See https://spec.graphql.org/draft/#sel-HAHdfFBABAB6Bw3R
    UndefinedDefinition,
    // KnownDirectivesRule
    /// Undefined directive
    ///
    /// A directive used must be defined in the schema or be a built-in directive.
    ///
    /// See https://spec.graphql.org/draft/#sec-Directives-Are-Defined
    UndefinedDirective,
    // DirectivesAreInValidLocationsRule
    /// Unsupported directive location
    ///
    /// Directives must only be used in locations they are declared to support.
    ///
    /// See https://spec.graphql.org/draft/#sec-Directives-Are-In-Valid-Locations
    UnsupportedDirectiveLocation,
    // UniqueDirectivesPerLocationRule
    /// Duplicate directive
    ///
    /// Directives that are not declared repeatable must appear at most once per location.
    ///
    /// See https://spec.graphql.org/draft/#sec-Directives-Are-Unique-Per-Location
    DuplicateDirective,
    // FragmentsOnCompositeTypesRule
    /// Fragments on composite type
    ///
    /// Fragments use a type condition to determine if they apply, since fragments
    /// can only be spread into a composite type (object, interface, or union), the
    /// type condition must also be a composite type.
    InvalidFragmentTarget,
    // PossibleFragmentSpreadsRule
    /// Possible fragment spread
    ///
    /// A fragment spread is only valid if the type condition could ever possibly
    /// be true: if there is a non-empty intersection of the possible parent types,
    /// and possible types which pass the type condition.
    InvalidFragmentSpread,
    // NoFragmentCyclesRule
    /// No fragment cycles
    ///
    /// The graph of fragment spreads must not form any cycles including spreading itself.
    /// Otherwise an operation could infinitely spread or infinitely execute on cycles in the underlying data.
    ///
    /// See https://spec.graphql.org/draft/#sec-Fragment-spreads-must-not-form-cycles
    RecursiveFragmentDefinition,
    /// Deeply nested type
    ///
    /// A fragment definition contains too much nesting, indicating potential
    /// abuse or an excessively complex query.
    DeeplyNestedType,
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
