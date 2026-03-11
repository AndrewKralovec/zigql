const std = @import("std");
const ast = @import("../grammar/ast.zig");

pub const Schema = struct {
    allocator: std.mem.Allocator,
    directive_definitions: std.StringHashMap([]const ast.InputValueDefinitionNode),
    field_arguments: std.StringHashMap(std.StringHashMap([]const ast.InputValueDefinitionNode)),

    pub fn init(allocator: std.mem.Allocator) Schema {
        return Schema{
            .allocator = allocator,
            .directive_definitions = std.StringHashMap([]const ast.InputValueDefinitionNode).init(allocator),
            .field_arguments = std.StringHashMap(std.StringHashMap([]const ast.InputValueDefinitionNode)).init(allocator),
        };
    }

    pub fn deinit(self: *Schema) void {
        var it = self.field_arguments.valueIterator();
        while (it.next()) |inner_map| {
            @constCast(inner_map).deinit();
        }
        self.field_arguments.deinit();
        self.directive_definitions.deinit();
    }

    pub fn getDirectiveArguments(self: *const Schema, directive_name: []const u8) ?[]const ast.InputValueDefinitionNode {
        return self.directive_definitions.get(directive_name);
    }

    pub fn getFieldArguments(self: *const Schema, type_name: []const u8, field_name: []const u8) ?[]const ast.InputValueDefinitionNode {
        const fields_map = self.field_arguments.get(type_name) orelse return null;
        return fields_map.get(field_name);
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
                        try collectTypeFieldArguments(&schema, type_def);
                    },
                    else => {},
                }
            },
            .TypeSystemExtension => |type_sys_ext| {
                switch (type_sys_ext) {
                    .TypeExtension => |type_ext| {
                        try collectExtensionFieldArguments(&schema, type_ext);
                    },
                    else => {},
                }
            },
            else => {},
        }
    }

    return schema;
}

fn collectTypeFieldArguments(schema: *Schema, type_def: ast.TypeDefinitionNode) !void {
    switch (type_def) {
        .ObjectTypeDefinition => |obj| {
            if (obj.fields) |fields| {
                try collectFieldArguments(schema, obj.name.value, fields);
            }
        },
        .InterfaceTypeDefinition => |iface| {
            if (iface.fields) |fields| {
                try collectFieldArguments(schema, iface.name.value, fields);
            }
        },
        else => {},
    }
}

fn collectExtensionFieldArguments(schema: *Schema, type_ext: ast.TypeExtensionNode) !void {
    switch (type_ext) {
        .ObjectTypeExtension => |obj_ext| {
            if (obj_ext.fields) |fields| {
                try collectFieldArguments(schema, obj_ext.name.value, fields);
            }
        },
        .InterfaceTypeExtension => |iface_ext| {
            if (iface_ext.fields) |fields| {
                try collectFieldArguments(schema, iface_ext.name.value, fields);
            }
        },
        else => {},
    }
}

fn collectFieldArguments(schema: *Schema, type_name: []const u8, fields: []const ast.FieldDefinitionNode) !void {
    for (fields) |field_def| {
        const args = field_def.arguments orelse continue;
        const gop = try schema.field_arguments.getOrPut(type_name);
        if (!gop.found_existing) {
            gop.value_ptr.* = std.StringHashMap([]const ast.InputValueDefinitionNode).init(schema.allocator);
        }
        try gop.value_ptr.*.put(field_def.name.value, args);
    }
}
