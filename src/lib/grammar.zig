const std = @import("std");

/// This enum defines the locations where directives can be used in the GraphQL syntax.
/// They are uppercase to match the GraphQL spec.
/// The locations are used to validate the usage of directives in the AST.
pub const DirectiveLocation = enum {
    QUERY,
    MUTATION,
    SUBSCRIPTION,
    FIELD,
    FRAGMENT_DEFINITION,
    FRAGMENT_SPREAD,
    INLINE_FRAGMENT,
    VARIABLE_DEFINITION,
    SCHEMA,
    SCALAR,
    OBJECT,
    FIELD_DEFINITION,
    ARGUMENT_DEFINITION,
    INTERFACE,
    UNION,
    ENUM,
    ENUM_VALUE,
    INPUT_OBJECT,
    INPUT_FIELD_DEFINITION,
};

// TODO: Look into comptime maps vs stringToEnum for better performance, and cleaner enum code.
pub fn stringToDirectiveLocation(str: []const u8) ?DirectiveLocation {
    return std.meta.stringToEnum(DirectiveLocation, str);
}

/// This enum defines the keywords in the GraphQL syntax.
/// They are lowercase to match the GraphQL spec.
/// The keywords are used to identify the type of node in the AST.
/// This is used so i can do a switch on keyword strings in the parser.
pub const SyntaxKeyWord = enum {
    directive,
    @"enum",
    extend,
    fragment,
    input,
    interface,
    type,
    query,
    mutation,
    subscription,
    @"{",
    scalar,
    schema,
    @"union",
    implements,
    on,
    repeatable,
};

// TODO(keyword-switching): Look into comptime maps vs stringToEnum for better performance, and cleaner enum code.
pub fn stringToKeyword(str: []const u8) ?SyntaxKeyWord {
    return std.meta.stringToEnum(SyntaxKeyWord, str);
}

pub const SyntaxKind = enum {
    Document,
    OperationDefinition,
    SelectionSet,
    Field,
    FragmentSpread,
    InlineFragment,
    Name,
    VariableDefinition,
    Int,
    Float,
    NamedType,
    ListType,
    NonNullType,
    Variable,
    String,
    Directive,
    Argument,
    ExecutableDefinition,
    OperationType,
    FieldDefinition,
    InputValueDefinition,
    SchemaDefinition,
    OperationTypeDefinition,
    ScalarTypeDefinition,
    ObjectTypeDefinition,
    InterfaceTypeDefinition,
    UnionTypeDefinition,
    EnumTypeDefinition,
    EnumValueDefinition,
    InputObjectTypeDefinition,
    DirectiveDefinition,
    FragmentDefinition,
    ScalarTypeExtension,
    ObjectTypeExtension,
    InterfaceTypeExtension,
    UnionTypeExtension,
    EnumTypeExtension,
    InputObjectTypeExtension,
    SchemaExtension,
    List,
    Object,
    ObjectField,
    Boolean,
    Null,
    Enum,
};

pub const DocumentNode = struct {
    kind: SyntaxKind = SyntaxKind.Document,
    definitions: []const DefinitionNode,
};

pub const DefinitionNode = union(enum) {
    ExecutableDefinition: ExecutableDefinitionNode,
    TypeSystemDefinition: TypeSystemDefinitionNode,
    TypeSystemExtension: TypeSystemExtensionNode,
};

pub const ExecutableDefinitionNode = union(enum) {
    OperationDefinition: OperationDefinitionNode,
    FragmentDefinition: FragmentDefinitionNode,
};

pub const TypeSystemDefinitionNode = union(enum) {
    TypeDefinition: TypeDefinitionNode,
    SchemaDefinition: SchemaDefinitionNode,
    DirectiveDefinition: DirectiveDefinitionNode,
};

pub const OperationDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.OperationDefinition,
    operation: OperationType,
    name: ?NameNode,
    variableDefinitions: ?[]const VariableDefinitionNode,
    directives: ?[]const DirectiveNode,
    selectionSet: ?SelectionSetNode,
};

pub const OperationType = enum {
    Query,
    Mutation,
    Subscription,
};

pub const SelectionSetNode = struct {
    kind: SyntaxKind = SyntaxKind.SelectionSet,
    selections: []const SelectionNode,
};

pub const SelectionNode = union(enum) {
    Field: FieldNode,
    FragmentSpread: FragmentSpreadNode,
    InlineFragment: InlineFragmentNode,
};

pub const FieldNode = struct {
    kind: SyntaxKind = SyntaxKind.Field,
    name: NameNode,
    alias: ?NameNode,
    arguments: ?[]const ArgumentNode,
    directives: ?[]const DirectiveNode,
    selectionSet: ?SelectionSetNode,
};

pub const FragmentSpreadNode = struct {
    kind: SyntaxKind = SyntaxKind.FragmentSpread,
    name: NameNode,
    directives: ?[]const DirectiveNode,
};

pub const InlineFragmentNode = struct {
    kind: SyntaxKind = SyntaxKind.InlineFragment,
    typeCondition: ?NamedTypeNode,
    directives: ?[]const DirectiveNode,
    selectionSet: SelectionSetNode,
};

pub const NameNode = struct {
    kind: SyntaxKind = SyntaxKind.Name,
    value: []const u8,
};

pub const DirectiveNode = struct {
    name: NameNode,
    arguments: ?[]const ArgumentNode,
};

pub const ArgumentNode = struct {
    name: NameNode,
    value: ValueNode,
};

// TODO: should we separate node for const values?
// These include const values as well as variables.
pub const ValueNode = union(enum) {
    Variable: VariableNode,
    Int: IntValueNode,
    Float: FloatValueNode,
    String: StringValueNode,
    Boolean: BooleanValueNode,
    Null: NullValueNode,
    Enum: EnumValueNode,
    List: ListValueNode,
    Object: ObjectValueNode,
};

pub const VariableNode = struct {
    name: NameNode,
};

pub const StringValueNode = struct {
    kind: SyntaxKind = SyntaxKind.String,
    value: []const u8,
};

pub const IntValueNode = struct {
    kind: SyntaxKind = SyntaxKind.Int,
    value: []const u8,
};

pub const FloatValueNode = struct {
    kind: SyntaxKind = SyntaxKind.Float,
    value: []const u8,
};

pub const ListValueNode = struct {
    kind: SyntaxKind = SyntaxKind.List,
    values: []const ValueNode,
};

pub const ObjectValueNode = struct {
    kind: SyntaxKind = SyntaxKind.Object,
    fields: []const ObjectFieldNode,
};

pub const ObjectFieldNode = struct {
    kind: SyntaxKind = SyntaxKind.ObjectField,
    name: NameNode,
    value: ValueNode,
};

pub const BooleanValueNode = struct {
    kind: SyntaxKind = SyntaxKind.Boolean,
    value: bool,
};

pub const NullValueNode = struct {
    kind: SyntaxKind = SyntaxKind.Null,
};

pub const EnumValueNode = struct {
    kind: SyntaxKind = SyntaxKind.Enum,
    value: []const u8,
};

pub const VariableDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.VariableDefinition,
    variable: VariableNode,
    type: *TypeNode,
    defaultValue: ?ValueNode, // ConstValueNode
    directives: ?[]const DirectiveNode, // ConstDirectiveNode
};

pub const TypeNode = union(enum) {
    NamedType: NamedTypeNode,
    ListType: ListTypeNode,
    NonNullType: NonNullTypeNode,
};

pub const NamedTypeNode = struct {
    kind: SyntaxKind = SyntaxKind.NamedType,
    name: NameNode,
};

pub const ListTypeNode = struct {
    kind: SyntaxKind = SyntaxKind.ListType,
    type: *TypeNode,
};

pub const NonNullTypeNode = struct {
    kind: SyntaxKind = SyntaxKind.NonNullType,
    type: *TypeNode,
};

pub const SchemaDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.SchemaDefinition,
    description: ?StringValueNode,
    directives: ?[]const DirectiveNode,
    operationTypes: ?[]const OperationTypeDefinitionNode,
};

pub const OperationTypeDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.OperationTypeDefinition,
    operation: OperationType,
    type: NamedTypeNode,
};

pub const TypeDefinitionNode = union(enum) {
    ScalarTypeDefinition: ScalarTypeDefinitionNode,
    ObjectTypeDefinition: ObjectTypeDefinitionNode,
    InterfaceTypeDefinition: InterfaceTypeDefinitionNode,
    UnionTypeDefinition: UnionTypeDefinitionNode,
    EnumTypeDefinition: EnumTypeDefinitionNode,
    InputObjectTypeDefinition: InputObjectTypeDefinitionNode,
};

pub const ScalarTypeDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.ScalarTypeDefinition,
    description: ?StringValueNode,
    name: NameNode,
    directives: ?[]const DirectiveNode, // ConstDirectiveNode
};

pub const ObjectTypeDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.ObjectTypeDefinition,
    name: NameNode,
    description: ?StringValueNode,
    interfaces: ?[]const NamedTypeNode,
    directives: ?[]const DirectiveNode,
    fields: ?[]const FieldDefinitionNode,
};

pub const InterfaceTypeDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.InterfaceTypeDefinition,
    name: NameNode,
    description: ?StringValueNode,
    interfaces: ?[]const NamedTypeNode,
    directives: ?[]const DirectiveNode, // ConstDirectiveNode
    fields: ?[]const FieldDefinitionNode,
};

pub const UnionTypeDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.UnionTypeDefinition,
    name: NameNode,
    description: ?StringValueNode,
    directives: ?[]const DirectiveNode, // ConstDirectiveNode
    types: ?[]const NamedTypeNode,
};

pub const EnumTypeDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.EnumTypeDefinition,
    name: NameNode,
    description: ?StringValueNode,
    directives: ?[]const DirectiveNode, // ConstDirectiveNode
    values: ?[]const EnumValueDefinitionNode,
};

pub const EnumValueDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.EnumValueDefinition,
    name: NameNode,
    description: ?StringValueNode,
    directives: ?[]const DirectiveNode, // ConstDirectiveNode
};

pub const FieldDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.FieldDefinition,
    name: NameNode,
    type: *TypeNode,
    description: ?StringValueNode,
    arguments: ?[]const InputValueDefinitionNode,
    directives: ?[]const DirectiveNode,
};

pub const InputObjectTypeDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.InputObjectTypeDefinition,
    name: NameNode,
    description: ?StringValueNode,
    directives: ?[]const DirectiveNode, // ConstDirectiveNode
    fields: ?[]const InputValueDefinitionNode,
};

pub const InputValueDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.InputValueDefinition,
    name: NameNode,
    type: *TypeNode,
    defaultValue: ?ValueNode,
    directives: ?[]const DirectiveNode,
};

pub const DirectiveDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.DirectiveDefinition,
    description: ?StringValueNode,
    name: NameNode,
    arguments: ?[]const InputValueDefinitionNode,
    repeatable: bool,
    locations: []const NameNode,
};

pub const FragmentDefinitionNode = struct {
    kind: SyntaxKind = SyntaxKind.FragmentDefinition,
    name: NameNode,
    typeCondition: NamedTypeNode,
    directives: ?[]const DirectiveNode,
    selectionSet: SelectionSetNode,
};

pub const TypeSystemExtensionNode = union(enum) {
    SchemaExtension: SchemaExtensionNode,
    TypeExtension: TypeExtensionNode,
};

pub const SchemaExtensionNode = struct {
    kind: SyntaxKind = SyntaxKind.SchemaExtension,
    directives: ?[]const DirectiveNode,
    operationTypes: ?[]const OperationTypeDefinitionNode,
};

// TODO: This is very similar to TypeDefinitionNode.
// We should consider merging them in the future.
// But for now, we will keep them separate for clarity.
// This is a type extension node. It is used to extend existing types in the schema.
pub const TypeExtensionNode = union(enum) {
    ScalarTypeExtension: ScalarTypeExtensionNode,
    ObjectTypeExtension: ObjectTypeExtensionNode,
    InterfaceTypeExtension: InterfaceTypeExtensionNode,
    UnionTypeExtension: UnionTypeExtensionNode,
    EnumTypeExtension: EnumTypeExtensionNode,
    InputObjectTypeExtension: InputObjectTypeExtensionNode,
};

pub const ScalarTypeExtensionNode = struct {
    kind: SyntaxKind = SyntaxKind.ScalarTypeExtension,
    name: NameNode,
    directives: ?[]const DirectiveNode,
};

pub const ObjectTypeExtensionNode = struct {
    kind: SyntaxKind = SyntaxKind.ObjectTypeExtension,
    name: NameNode,
    interfaces: ?[]const NamedTypeNode,
    directives: ?[]const DirectiveNode,
    fields: ?[]const FieldDefinitionNode,
};

pub const InterfaceTypeExtensionNode = struct {
    kind: SyntaxKind = SyntaxKind.InterfaceTypeExtension,
    name: NameNode,
    interfaces: ?[]const NamedTypeNode,
    directives: ?[]const DirectiveNode,
    fields: ?[]const FieldDefinitionNode,
};

pub const UnionTypeExtensionNode = struct {
    kind: SyntaxKind = SyntaxKind.UnionTypeExtension,
    name: NameNode,
    directives: ?[]const DirectiveNode,
    types: ?[]const NamedTypeNode,
};

pub const EnumTypeExtensionNode = struct {
    kind: SyntaxKind = SyntaxKind.EnumTypeExtension,
    name: NameNode,
    directives: ?[]const DirectiveNode,
    values: ?[]const EnumValueDefinitionNode,
};

pub const InputObjectTypeExtensionNode = struct {
    kind: SyntaxKind = SyntaxKind.InputObjectTypeExtension,
    name: NameNode,
    directives: ?[]const DirectiveNode,
    fields: ?[]const InputValueDefinitionNode,
};
