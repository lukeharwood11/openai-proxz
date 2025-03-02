const std = @import("std");

/// Validate the given struct to ensure that it is valid for `parseJson`.
/// This will throw a `@compileError` if the struct isn't valid.
fn validateStruct(comptime T: type) void {
    comptime var valid_arena = false;
    const ti = @typeInfo(T);
    inline for (ti.Struct.fields) |field| {
        if (comptime std.mem.eql(u8, field.name, "arena")) {
            if (field.type == *std.heap.ArenaAllocator) {
                valid_arena = true;
            }
        }
    }
    if (!valid_arena) {
        @compileError("Type '" ++ @typeName(T) ++ "' must have a field `arena` of type `*std.heap.ArenaAllocator`");
    }
}

/// This will parse a string slice into type `T`, where `T` is a type that has a field `arena` of type `*std.heap.ArenaAllocator`
/// All memory will managed by that arena allocator, and the type is reponsible for freeing that memory (via `arena.deinit()`) and destroying the arena ``
pub fn deserializeStructWithArena(comptime T: type, allocator: std.mem.Allocator, slice: []const u8) !T {
    // validate the struct at compile time
    comptime validateStruct(T);
    // grab every field except the "arena" one
    const ti = @typeInfo(T);
    comptime var fields: [ti.Struct.fields.len - 1]std.builtin.Type.StructField = undefined;
    comptime var i: usize = 0;
    inline for (ti.Struct.fields) |field| {
        if (!comptime std.mem.eql(u8, field.name, "arena")) {
            fields[i] = field;
            i += 1;
        }
    }
    // reify a type that has everything except the "arena" field
    const Tp = @Type(.{
        .Struct = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
    var self: T = undefined;
    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    errdefer allocator.destroy(arena);
    errdefer arena.deinit();

    // use the default json parse function with an arena allocator
    const result = try std.json.parseFromSliceLeaky(
        Tp,
        arena.allocator(),
        slice,
        .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
        },
    );
    // copy the values over to the original struct T
    inline for (ti.Struct.fields) |field| {
        if (!comptime std.mem.eql(u8, field.name, "arena")) {
            @field(self, field.name) = @field(result, field.name);
        }
    }
    // save the arena allocator used, so that `self` 'owns' its own memory and can deinitialize it by
    // calling self.arena.deinit() and self.arena.child_allocator.destroy(self.arena);
    self.arena = arena;
    return self;
}

test "deserializeStructWithArena - success" {
    const allocator = std.testing.allocator;
    const slice =
        \\ {
        \\ "hello": "test",
        \\ "world": 32.12
        \\ }
    ;
    const Test = struct {
        hello: []const u8,
        world: f64,
        arena: *std.heap.ArenaAllocator,
    };
    const result = try deserializeStructWithArena(Test, allocator, slice);
    defer result.arena.child_allocator.destroy(result.arena);
    defer result.arena.deinit();

    try std.testing.expect(std.mem.eql(u8, result.hello, "test"));
}
