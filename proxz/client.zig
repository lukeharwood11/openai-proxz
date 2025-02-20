const std = @import("std");
const http = std.http;
const log = std.log;
const models = @import("models.zig");
const chat = @import("chat.zig");
const embeddings = @import("embeddings.zig");

pub const OpenAIConfig = struct {
    api_key: ?[]const u8 = null,
    base_url: ?[]const u8 = null,
    organization_id: ?[]const u8 = null,
    project_id: ?[]const u8 = null,
};

pub const APIErrorResponse = struct {
    @"error": APIError,
};

pub const APIError = struct {
    message: []const u8,
    type: []const u8,
    param: ?[]const u8 = null,
    code: ?[]const u8 = null,
};

pub fn OpenAIResponse(comptime T: type) type {
    return union(enum) {
        ok: models.Response(T),
        err: models.Response(APIErrorResponse),

        pub fn deinit(self: *@This()) void {
            switch (self.*) {
                .ok => |*ok| ok.deinit(),
                .err => |*err| err.deinit(),
            }
        }
    };
}

pub const OpenAIClientError = error{
    OpenAIAPIKeyNotSet,
    MemoryError,
};

pub const RequestOptions = struct {
    body: ?[]const u8 = null,
};

pub const OpenAIError = error{
    BadRequest,
    Unauthorized,
    PaymentRequired,
    Forbidden,
    NotFound,
    MethodNotAllowed,
    TooManyRequests,
    InternalServerError,
};

pub const OpenAI = struct {
    allocator: std.mem.Allocator,
    client: http.Client,
    chat: chat.Chat,
    embeddings: embeddings.Embeddings,
    api_key: []const u8,
    base_url: []const u8,
    organization_id: ?[]const u8,
    project_id: ?[]const u8,
    headers: std.http.Client.Request.Headers,
    arena: *std.heap.ArenaAllocator,

    pub fn moveNullableString(self: *OpenAI, str: ?[]const u8) !?[]const u8 {
        if (str) |s| {
            return self.arena.allocator().dupeZ(u8, s) catch {
                return OpenAIClientError.MemoryError;
            };
        } else {
            return null;
        }
    }

    pub fn init(allocator: std.mem.Allocator, openai_config: OpenAIConfig) OpenAIClientError!*OpenAI {
        const arena = allocator.create(std.heap.ArenaAllocator) catch {
            return OpenAIClientError.MemoryError;
        };
        arena.* = std.heap.ArenaAllocator.init(allocator);
        errdefer blk: {
            arena.deinit();
            allocator.destroy(arena);
            break :blk;
        }
        var self = allocator.create(OpenAI) catch {
            return OpenAIClientError.MemoryError;
        };
        self.* = OpenAI{
            .allocator = allocator,
            .client = http.Client{ .allocator = arena.allocator() },
            .chat = undefined, // have to pass in self
            .embeddings = undefined, // have to pass in self
            .api_key = undefined,
            .base_url = undefined,
            .organization_id = null,
            .project_id = null,
            .headers = undefined, // set below
            .arena = arena,
        };
        errdefer allocator.destroy(self);

        // get env vars
        var env_map = std.process.getEnvMap(self.allocator) catch {
            return OpenAIClientError.MemoryError;
        };
        defer env_map.deinit();

        // make all strings managed on the heap via the arena allocator
        const api_key = try self.moveNullableString(openai_config.api_key orelse env_map.get("OPENAI_API_KEY"));
        const base_url = try self.moveNullableString(openai_config.base_url orelse env_map.get("OPENAI_BASE_URL") orelse "https://api.openai.com/v1");
        const organization_id = try self.moveNullableString(openai_config.organization_id orelse env_map.get("OPENAI_ORGANIZATION_ID"));
        const project_id = try self.moveNullableString(openai_config.project_id orelse env_map.get("OPENAI_PROJECT_ID"));

        // init client config
        self.api_key = api_key orelse {
            return OpenAIClientError.OpenAIAPIKeyNotSet;
        };
        self.base_url = base_url orelse {
            unreachable;
        };
        self.organization_id = organization_id;
        self.project_id = project_id;

        // init sub components
        self.chat = chat.Chat.init(self);
        self.embeddings = embeddings.Embeddings.init(self);

        // client headers
        const auth_header = std.fmt.allocPrint(self.arena.allocator(), "Bearer {s}", .{self.api_key}) catch {
            return OpenAIClientError.MemoryError;
        };
        self.headers = .{ .authorization = .{ .override = auth_header }, .content_type = .{ .override = "application/json" } };
        return self;
    }

    pub fn deinit(self: *OpenAI) void {
        self.client.deinit();
        self.chat.deinit();
        self.embeddings.deinit();
        self.arena.deinit();
        self.allocator.destroy(self.arena);
        self.allocator.destroy(self);
    }

    /// Makes a request to the OpenAI base_url provided to the client, with the corresponding method, path, and options provided
    pub fn request(self: *const OpenAI, method: http.Method, path: []const u8, options: RequestOptions, comptime T: type) !OpenAIResponse(T) {
        const allocator = self.allocator;
        const url_string = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.base_url, path });
        defer allocator.free(url_string);

        log.debug("{s} - {s}", .{ @tagName(method), url_string });

        const uri = try std.Uri.parse(url_string);

        const server_header_buffer = try allocator.alloc(u8, 8 * 1024 * 4);
        defer allocator.free(server_header_buffer);

        // Create a new client for each request to avoid connection pool issues
        var client = http.Client{ .allocator = allocator };
        defer client.deinit();

        var req = try client.open(method, uri, .{
            .server_header_buffer = server_header_buffer,
            .headers = self.headers,
        });
        defer req.deinit();

        if (options.body) |body| {
            req.transfer_encoding = .{ .content_length = body.len };
        }
        try req.send();
        if (options.body) |body| {
            log.debug("{s}", .{body});
            try req.writer().writeAll(body);
            try req.finish();
        }
        try req.wait();

        const body = try req.reader().readAllAlloc(allocator, 10 * 1024 * 1024);
        defer allocator.free(body);

        if (req.response.status != .ok) {
            const err = try models.Response(APIErrorResponse).parse(allocator, body);
            return OpenAIResponse(T){ .err = err };
        }

        const response = try models.Response(T).parse(allocator, body);
        return OpenAIResponse(T){ .ok = response };
    }
};
