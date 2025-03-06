pub fn mergeStructs(comptime A: type, comptime B: type) type {
    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = @typeInfo(A).@"struct".fields ++ @typeInfo(B).@"struct".fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}
