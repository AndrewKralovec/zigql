const std = @import("std");
const ast = @import("../grammar/ast.zig");

pub const Schema = struct {
    allocator: std.mem.Allocator,
    directive_definitions: std.StringHashMap([]const ast.InputValueDefinitionNode),
    types: std.StringHashMap(TypeDefinition),
    query_type: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) Schema {
        return Schema{
            .allocator = allocator,
            .directive_definitions = std.StringHashMap([]const ast.InputValueDefinitionNode).init(allocator),
            .types = std.StringHashMap(TypeDefinition).init(allocator),
            .query_type = null,
        };
    }

    pub fn deinit(self: *Schema) void {
        self.directive_definitions.deinit();
        self.types.deinit();
    }

    pub fn getDirectiveArguments(self: *const Schema, directive_name: []const u8) ?[]const ast.InputValueDefinitionNode {
        return self.directive_definitions.get(directive_name);
    }

    pub fn getType(self: *const Schema, name: []const u8) ?TypeDefinition {
        return self.types.get(name);
    }

    pub fn typeField(self: *const Schema, type_name: []const u8, field_name: []const u8) FieldLookupError!ast.FieldDefinitionNode {
        const type_info = self.types.get(type_name) orelse return error.NoSuchType;

        const fields: ?[]const ast.FieldDefinitionNode = switch (type_info) {
            .Object => |obj| obj.fields,
            .Interface => |iface| iface.fields,
            .Scalar, .Union, .Enum, .InputObject => null,
        };

        if (fields) |field_defs| {
            for (field_defs) |field_def| {
                if (std.mem.eql(u8, field_def.name.value, field_name)) {
                    return field_def;
                }
            }
        }

        return error.NoSuchField;
    }
};

pub fn buildSchema(allocator: std.mem.Allocator, document: ast.DocumentNode) !Schema {
    var schema = Schema.init(allocator);
    errdefer schema.deinit();

    for (document.definitions) |def| {
        switch (def) {
            .TypeSystemDefinition => |type_sys_def| {
                switch (type_sys_def) {
                    .DirectiveDefinition => |dir_def| {
                        try schema.directive_definitions.put(dir_def.name.value, dir_def.arguments orelse &.{});
                    },
                    .TypeDefinition => |type_def| {
                        try collectType(&schema, type_def);
                    },
                    .SchemaDefinition => |schema_def| {
                        for (schema_def.operation_types) |op_type| {
                            if (op_type.operation == .Query) {
                                schema.query_type = op_type.type.name.value;
                            }
                        }
                    },
                }
            },
            .TypeSystemExtension => |type_sys_ext| {
                switch (type_sys_ext) {
                    else => {},
                }
            },
            else => {},
        }
    }

    // default query type per GraphQL spec
    if (schema.query_type == null) {
        schema.query_type = "Query";
    }

    return schema;
}

fn collectType(schema: *Schema, type_def: ast.TypeDefinitionNode) !void {
    switch (type_def) {
        .ScalarTypeDefinition => |scalar| {
            try schema.types.put(scalar.name.value, .{ .Scalar = .{
                .directives = scalar.directives,
            } });
        },
        .ObjectTypeDefinition => |obj| {
            try schema.types.put(obj.name.value, .{ .Object = .{
                .fields = obj.fields,
                .interfaces = obj.interfaces,
                .directives = obj.directives,
            } });
        },
        .InterfaceTypeDefinition => |iface| {
            try schema.types.put(iface.name.value, .{ .Interface = .{
                .fields = iface.fields,
                .interfaces = iface.interfaces,
                .directives = iface.directives,
            } });
        },
        .UnionTypeDefinition => |union_def| {
            try schema.types.put(union_def.name.value, .{ .Union = .{
                .members = union_def.types,
                .directives = union_def.directives,
            } });
        },
        .EnumTypeDefinition => |enum_def| {
            try schema.types.put(enum_def.name.value, .{ .Enum = .{
                .values = enum_def.values,
                .directives = enum_def.directives,
            } });
        },
        .InputObjectTypeDefinition => |input| {
            try schema.types.put(input.name.value, .{ .InputObject = .{
                .fields = input.fields,
                .directives = input.directives,
            } });
        },
    }
}

pub const FieldLookupError = error{
    NoSuchType,
    NoSuchField,
};

pub const TypeDefinition = union(enum) {
    Scalar: ScalarType,
    Object: ObjectType,
    Interface: InterfaceType,
    Union: UnionType,
    Enum: EnumType,
    InputObject: InputObjectType,
};

pub const ScalarType = struct {
    directives: ?[]const ast.DirectiveNode,
};

pub const ObjectType = struct {
    fields: ?[]const ast.FieldDefinitionNode,
    interfaces: ?[]const ast.NamedTypeNode,
    directives: ?[]const ast.DirectiveNode,
};

pub const InterfaceType = struct {
    fields: ?[]const ast.FieldDefinitionNode,
    interfaces: ?[]const ast.NamedTypeNode,
    directives: ?[]const ast.DirectiveNode,
};

pub const UnionType = struct {
    members: ?[]const ast.NamedTypeNode,
    directives: ?[]const ast.DirectiveNode,
};

pub const EnumType = struct {
    values: ?[]const ast.EnumValueDefinitionNode,
    directives: ?[]const ast.DirectiveNode,
};

pub const InputObjectType = struct {
    fields: ?[]const ast.InputValueDefinitionNode,
    directives: ?[]const ast.DirectiveNode,
};
