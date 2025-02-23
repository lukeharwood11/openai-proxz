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
const chat = @import("chat.zig");
const embeddings = @import("embeddings.zig");
const models = @import("models.zig");

const INITIAL_RETRY_DELAY = 0.5;
const MAX_RETRY_DELAY = 8;

/// An OpenAI API response wrapper, returns a struct with the following fields:
/// ```
/// data: T,
/// parsed: ?std.json.Parsed(T) = null,
/// allocator: std.mem.Allocator,
/// ```
/// The caller is responsible of calling `deinit` on this object to clean up resources
pub fn Response(comptime T: type) type {
    return struct {
        /// The response payload
        data: T,
        /// The backing json Parsed object, that contains all memory created for this object
        parsed: ?std.json.Parsed(T) = null,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Parses the response from the API into a struct of type T, which is accessible via the .data field
        /// The caller is also responsible for calling deinit() on the response to free all allocated memory
        pub fn parse(allocator: std.mem.Allocator, source: []const u8) !Self {
            const parsed = try std.json.parseFromSlice(T, allocator, source, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
            return Self{
                .data = parsed.value,
                .parsed = parsed,
                .allocator = allocator,
            };
        }

        /// Deinitializes all memory allocated for the response
        pub fn deinit(self: *const Self) void {
            if (self.parsed) |parsed| {
                parsed.deinit();
            }
        }
    };
}

pub const APIError = struct {
    message: []const u8,
    type: []const u8,
    param: ?[]const u8 = null,
    code: ?[]const u8 = null,
};

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

/// OpenAI Error Response Body.
/// Currently not exposed.
const APIErrorResponse = struct {
    @"error": APIError,
};

/// Errors pertaining to OpenAI struct creation
pub const OpenAIClientError = error{
    OpenAIAPIKeyNotSet,
    MemoryError,
};

/// Internal model for API calls
const RequestOptions = struct {
    body: ?[]const u8 = null,
};

/// Different OpenAI API errors:
/// https://platform.openai.com/docs/guides/error-codes
pub const OpenAIError = error{
    /// 400 - Bad Request
    /// Generic bad request error
    BadRequest,

    /// 404 - Not Found
    /// Model/resource isn't found
    NotFound,

    /// 401 - Invalid Authentication
    /// Cause: Invalid API key, incorrect API key, or missing organization membership
    /// Solution: Verify API key is correct, clear cache, or ensure organization membership
    InvalidAuthentication,

    /// 403 - Not Supported
    /// Cause: Accessing API from an unsupported country/region/territory
    /// Solution: See documentation for supported regions
    NotSupported,

    /// 429 - Rate Limit
    /// Cause: Too many requests or exceeded quota
    /// Solution: Pace requests according to rate limits or upgrade plan/billing
    RateLimit,

    /// 500 - Server Error
    /// Cause: Internal server error
    /// Solution: Retry after waiting, contact support if persistent
    ServerError,

    /// 503 - Service Overloaded
    /// Cause: Server is currently overloaded
    /// Solution: Retry request after waiting
    ServiceOverloaded,

    /// Unknown error occurred
    Unknown,
};

pub fn getErrorFromStatus(status: std.http.Status) OpenAIError {
    return switch (status) {
        .bad_request => OpenAIError.BadRequest,
        .not_found => OpenAIError.NotFound,
        .unauthorized => OpenAIError.InvalidAuthentication,
        .forbidden => OpenAIError.NotSupported,
        .too_many_requests => OpenAIError.RateLimit,
        .internal_server_error => OpenAIError.ServerError,
        .service_unavailable => OpenAIError.ServiceOverloaded,
        else => OpenAIError.Unknown,
    };
}

/// A general purpose openai client that initializes all base parameters (API key, Base URL, Org ID, Project ID)
/// and through which all requests should be made through. The creator must call `deinit` to clean up all resources created
/// by this struct.
pub const OpenAI = struct {
    allocator: std.mem.Allocator,
    client: http.Client,
    chat: chat.Chat,
    models: models.Models,
    embeddings: embeddings.Embeddings,
    api_key: []const u8,
    base_url: []const u8,
    organization: ?[]const u8,
    project: ?[]const u8,
    headers: http.Client.Request.Headers,
    extra_headers: []const http.Header,
    arena: *std.heap.ArenaAllocator,
    max_retries: usize,

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
            .models = undefined, // have to pass in self
            .api_key = undefined,
            .base_url = undefined,
            .organization = null,
            .project = null,
            .headers = undefined, // set below
            .extra_headers = &.{},
            .arena = arena,
            .max_retries = openai_config.max_retries,
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
        self.models = models.Models.init(self);

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

    pub const OpenAIRequest = struct {
        method: http.Method,
        path: []const u8,
        json: ?[]const u8 = null,
    };

    /// Makes a request to the OpenAI base_url provided to the client, with the corresponding method, path, and options provided.
    /// If there isn't a proxz method to hit an endpoint, this can be used and will automatically pass in required headers.
    /// ```zig
    /// const response = try self.openai.request(.{
    ///     .method = .POST, // .GET, .PUT, .etc.
    //      .path = "/my/endpoint",
    ///     .json = body,
    /// }, ResponseBodyStruct); // pass in null for no response body
    /// ````
    pub fn request(self: *const OpenAI, options: OpenAIRequest, comptime ResponseType: ?type) !if (ResponseType) |T| Response(T) else void {
        const method = options.method;
        const path = options.path;
        const allocator = self.allocator;
        const url_string = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.base_url, path });
        defer allocator.free(url_string);

        // log.debug("{s} - {s}", .{ @tagName(method), url_string });

        const uri = try std.Uri.parse(url_string);

        const server_header_buffer = try allocator.alloc(u8, 8 * 1024 * 4);
        defer allocator.free(server_header_buffer);

        // Create a new client for each request to avoid connection pool issues
        var client = http.Client{ .allocator = allocator };
        defer client.deinit();
        var backoff: f32 = INITIAL_RETRY_DELAY;

        for (0..self.max_retries + 1) |attempt| {
            var req = try client.open(method, uri, .{
                .server_header_buffer = server_header_buffer,
                .headers = self.headers,
                .extra_headers = self.extra_headers,
            });
            defer req.deinit();

            if (options.json) |body| {
                req.transfer_encoding = .{ .content_length = body.len };
            }
            try req.send();
            if (options.json) |body| {
                try req.writer().writeAll(body);
                try req.finish();
            }
            try req.wait();

            const body = try req.reader().readAllAlloc(allocator, 1024 * 1024);
            defer allocator.free(body);

            const status_int = @intFromEnum(req.response.status);
            log.info("{s} - {s} - {d} {s}", .{ @tagName(method), url_string, status_int, req.response.status.phrase() orelse "Unknown" });
            if (status_int < 200 or status_int >= 300) {
                if (attempt != self.max_retries and @intFromEnum(req.response.status) >= 429) {
                    // retry on 429, 500, and 503
                    log.info("Retrying ({d}/{d}) after {d} seconds.", .{ attempt + 1, self.max_retries, backoff });
                    std.time.sleep(@as(u64, @intFromFloat(backoff * std.time.ns_per_s)));
                    backoff = if (backoff * 2 <= MAX_RETRY_DELAY) backoff * 2 else MAX_RETRY_DELAY;
                } else {
                    const err = Response(APIErrorResponse).parse(allocator, body) catch {
                        log.err("{s}", .{body});
                        // if we can't parse the error, it was a bad request.
                        return OpenAIError.BadRequest;
                    };
                    defer err.deinit();
                    log.err("{s} ({s}): {s}", .{ err.data.@"error".type, err.data.@"error".code orelse "None", err.data.@"error".message });
                    return getErrorFromStatus(req.response.status);
                }
            } else {
                if (ResponseType) |T| {
                    const response = try Response(T).parse(allocator, body);
                    return response;
                } else {
                    return;
                }
            }
        }
        // max_retries must be >= 0 (since it's usize) and loop condition is 0..max_retries+1
        unreachable;
    }
};
