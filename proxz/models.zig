const std = @import("std");
const openai = @import("client.zig");
const OpenAI = openai.OpenAI;
const log = std.log;

pub const ListModelResponse = struct { object: []const u8, data: []const Object };
pub const Object = struct { id: []const u8, object: []const u8, created: u64, owned_by: []const u8 };

pub const Models = struct {
    client: *const OpenAI,

    pub fn init(client: *const OpenAI) Models {
        return Models{
            .client = client,
        };
    }

    pub fn deinit(self: *Models) void {
        _ = self;
    }

    pub fn list(self: *const Models) !openai.Response(ListModelResponse) {
        const response = try self.client.request(.{ .method = .GET, .path = "/models" }, ListModelResponse);
        switch (response) {
            .err => |err| {
                log.err("{s} ({s}): {s}", .{ err.data.@"error".type, err.data.@"error".code orelse "None", err.data.@"error".message });
                // TODO: figure out how we want to handle errors
                // for now just return a generic error
                defer err.deinit();
                return openai.OpenAIError.BadRequest;
            },
            .ok => |ok| {
                return ok;
            },
        }
    }

    pub fn retrieve(self: *const Models, id: []const u8) !openai.Response(Object) {
        const path = try std.fmt.allocPrint(self.client.allocator, "/models/{s}", .{id});
        defer self.client.allocator.free(path);
        const response = try self.client.request(.{ .method = .GET, .path = path }, Object);
        switch (response) {
            .err => |err| {
                log.err("{s} ({s}): {s}", .{ err.data.@"error".type, err.data.@"error".code orelse "None", err.data.@"error".message });
                // TODO: figure out how we want to handle errors
                // for now just return a generic error
                defer err.deinit();
                return openai.OpenAIError.BadRequest;
            },
            .ok => |ok| {
                return ok;
            },
        }
    }
};
