pub fn mergeStructs(comptime A: type, comptime B: type) type {
    return @Type(.{
        .Struct = .{
            .layout = .auto,
            .fields = @typeInfo(A).Struct.fields ++ @typeInfo(B).Struct.fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}
