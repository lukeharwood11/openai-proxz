//!## Example
//!```zig
//!const proxz = @import("proxz");
//!const OpenAI = proxz.OpenAI;
//!pub fn main() !void {
//!     const openai = try OpenAI.init(.{});
//!     defer openai.deinit();
//!     // ... call openai.chat.completions.create
//!}
//!```
//!
const std = @import("std");
const http = std.http;
const log = std.log;
const models = @import("models.zig");
const chat = @import("chat.zig");
const embeddings = @import("embeddings.zig");

/// Options to be passed through to the `OpenAI.init` function.
pub const OpenAIConfig = struct {
    /// Your OpenAI API key. If left null, it will attempt to read from the `OPENAI_API_KEY` environment variable.
    api_key: ?[]const u8 = null,
    /// Your OpenAI base url. If left null, it will attempt to read from the `OPENAI_BASE_URL` environment variable, otherwise will default to `"https://api.openai.com/v1"`.
    base_url: ?[]const u8 = null,
    /// Your OpenAI organization id. If left null, it will attempt to read from `OPENAI_ORG_ID` environment variable.
    organization: ?[]const u8 = null,
    /// Your OpenAI project id. If left null, it will attempt to read from `OPENAI_project` environment variable.
    project: ?[]const u8 = null,
    /// The maximum number of retries the client will attempt. Defaults to `3`.
    max_retries: usize = 3,
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

/// A wrapper for all OpenAI responses, whether successful or otherwise.
/// This allows the caller to determine whether the call was successful or not.
/// This is an internal API level struct.
fn OpenAIResponse(comptime T: type) type {
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

/// Errors pertaining to OpenAI struct creation
pub const OpenAIClientError = error{
    OpenAIAPIKeyNotSet,
    MemoryError,
};

/// Internal model for API calls
const RequestOptions = struct {
    body: ?[]const u8 = null,
};

/// Different OpenAI API errors
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

/// A general purpose openai client that initializes all base parameters (API key, Base URL, Org ID, Project ID)
/// and through which all requests should be made through. The creator must call `deinit` to clean up all resources created
/// by this struct.
pub const OpenAI = struct {
    allocator: std.mem.Allocator,
    client: http.Client,
    chat: chat.Chat,
    embeddings: embeddings.Embeddings,
    api_key: []const u8,
    base_url: []const u8,
    organization: ?[]const u8,
    project: ?[]const u8,
    headers: http.Client.Request.Headers,
    extra_headers: []const http.Header,
    arena: *std.heap.ArenaAllocator,

    fn moveNullableString(self: *OpenAI, str: ?[]const u8) !?[]const u8 {
        if (str) |s| {
            return self.arena.allocator().dupe(u8, s) catch {
                return OpenAIClientError.MemoryError;
            };
        } else {
            return null;
        }
    }

    /// Creates a new `OpenAI` object, initializing subcomponents and reading in environment variables for
    /// `base_url`, `api_key`, `organization`, and `project`.
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
            .organization = null,
            .project = null,
            .headers = undefined, // set below
            .extra_headers = &.{},
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
        const organization = try self.moveNullableString(openai_config.organization orelse env_map.get("OPENAI_ORG_ID"));
        const project = try self.moveNullableString(openai_config.project orelse env_map.get("OPENAI_PROJECT_ID"));

        // init client config
        self.api_key = api_key orelse {
            return OpenAIClientError.OpenAIAPIKeyNotSet;
        };
        self.base_url = base_url orelse {
            unreachable; // default is provided, this can't happen
        };
        self.organization = organization;
        self.project = project;

        // init sub components
        self.chat = chat.Chat.init(self);
        self.embeddings = embeddings.Embeddings.init(self);

        // client headers
        const auth_header = std.fmt.allocPrint(self.arena.allocator(), "Bearer {s}", .{self.api_key}) catch {
            return OpenAIClientError.MemoryError;
        };
        self.headers = .{ .authorization = .{ .override = auth_header }, .content_type = .{ .override = "application/json" } };
        if (self.project != null or self.organization != null) {
            var arr = std.ArrayList(http.Header).initCapacity(self.arena.allocator(), 2) catch {
                return OpenAIClientError.MemoryError;
            };
            defer arr.deinit();
            if (self.project) |p| {
                arr.append(.{
                    .name = "OpenAI-Organization",
                    .value = p,
                }) catch return OpenAIClientError.MemoryError;
            }
            if (self.organization) |o| {
                arr.append(.{
                    .name = "OpenAI-Project",
                    .value = o,
                }) catch return OpenAIClientError.MemoryError;
            }
            self.extra_headers = arr.toOwnedSlice() catch return OpenAIClientError.MemoryError;
        }
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

    /// Makes a request to the OpenAI base_url provided to the client, with the corresponding method, path, and options provided.
    /// This is an ***internal*** function not meant to be used outside of `proxz`.
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
            .extra_headers = self.extra_headers,
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

        const body = try req.reader().readAllAlloc(allocator, 1024 * 1024);
        defer allocator.free(body);

        if (req.response.status != .ok) {
            const err = try models.Response(APIErrorResponse).parse(allocator, body);
            return OpenAIResponse(T){ .err = err };
        }

        const response = try models.Response(T).parse(allocator, body);
        return OpenAIResponse(T){ .ok = response };
    }
};
