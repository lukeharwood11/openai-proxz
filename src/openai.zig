/// We want to build this out so others can call
/// ```zig
/// const proxz = @import("proxz");
/// const openai = proxz.openai
///
/// ...
/// client = openai.OpenAI.init(allocator);
/// ```
const std = @import("std");
const http = std.http;
const log = std.log;

pub const OpenAIConfig = struct {
    api_key: ?[]const u8 = null,
    base_url: ?[]const u8 = null,
    organization_id: ?[]const u8 = null,
    project_id: ?[]const u8 = null,
};

pub const ChatMessage = struct {
    role: []const u8,
    content: []const u8,
};

pub const ChatRequest = struct {
    model: []const u8,
    messages: []const ChatMessage,
};

pub const ChatChoice = struct {
    message: ChatMessage,
    finish_reason: []const u8,
    index: u64,
};

pub const ChatResponse = struct {
    id: []const u8,
    object: []const u8,
    created: u64,
    choices: []const ChatChoice,
};

pub const Completions = struct {
    openai: *const OpenAI,

    pub fn init(openai: *const OpenAI) Completions {
        return Completions{
            .openai = openai,
        };
    }

    pub fn deinit(_: *Completions) void {}

    pub fn create(self: *Completions, request: ChatRequest) ![]const u8 {
        // const allocator = self.openai.allocator;
        _ = request;
        std.debug.print("The type of self.openai.allocator: {s}\n", .{@typeName(@TypeOf(self.openai.allocator))});

        std.debug.print("Base URL Before: {s}\n", .{self.openai.base_url});
        // Use the arena allocator for the JSON string
        // const body = try std.json.stringifyAlloc(allocator, .{
        //     .model = request.model,
        //     .messages = request.messages,
        // }, .{});
        const body = "{\"model\":\"gpt-4o\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}";

        std.debug.print("Base URL After: {s}\n", .{self.openai.base_url});

        // Now use this body for the request
        return self.openai.request(.POST, "/chat/completions", .{
            .body = body,
        });
    }
};

pub const Chat = struct {
    openai: *const OpenAI,
    completions: Completions,

    pub fn init(openai: *const OpenAI) Chat {
        return Chat{
            .openai = openai,
            .completions = Completions.init(openai),
        };
    }

    pub fn create(self: *Chat, request: ChatRequest) !void {
        _ = self;
        _ = request;
    }

    pub fn createStream(self: *Chat, request: ChatRequest) !void {
        _ = self;
        _ = request;
    }

    pub fn deinit(_: *Chat) void {}
};

pub const Embeddings = struct {
    openai: *const OpenAI,

    pub fn init(openai: *const OpenAI) Embeddings {
        return Embeddings{
            .openai = openai,
        };
    }

    pub fn deinit(_: *Embeddings) void {}
};

pub const ConfigError = error{
    OpenAIAPIKeyNotSet,
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
    chat: Chat,
    embeddings: Embeddings,
    api_key: []const u8,
    base_url: []const u8,
    organization_id: ?[]const u8,
    project_id: ?[]const u8,
    headers: std.http.Client.Request.Headers,
    arena: *std.heap.ArenaAllocator,

    pub fn moveNullableString(self: *OpenAI, str: ?[]const u8) !?[]const u8 {
        if (str) |s| {
            return try self.arena.allocator().dupeZ(u8, s);
        } else {
            return null;
        }
    }

    pub fn init(allocator: std.mem.Allocator, openai_config: OpenAIConfig) !OpenAI {
        const arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        var self = OpenAI{
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

        // get env vars
        var env_map = try std.process.getEnvMap(arena.allocator());
        defer env_map.deinit();

        // make all strings managed on the heap via the arena allocator
        const api_key = try self.moveNullableString(openai_config.api_key orelse env_map.get("OPENAI_API_KEY"));
        const base_url = try self.moveNullableString(openai_config.base_url orelse env_map.get("OPENAI_BASE_URL") orelse "https://api.openai.com/v1");
        const organization_id = try self.moveNullableString(openai_config.organization_id orelse env_map.get("OPENAI_ORGANIZATION_ID"));
        const project_id = try self.moveNullableString(openai_config.project_id orelse env_map.get("OPENAI_PROJECT_ID"));

        std.debug.print("api_key: {?s}, length {d}\n", .{ api_key, api_key.?.len });
        std.debug.print("base_url: {?s}, length {d}\n", .{ base_url, base_url.?.len });
        std.debug.print("organization_id: {?s}, length {d}\n", .{ organization_id, 0 });
        std.debug.print("project_id: {?s}, length {d}\n", .{ project_id, 0 });

        // init client config
        self.api_key = api_key orelse {
            return ConfigError.OpenAIAPIKeyNotSet;
        };
        self.base_url = base_url orelse {
            unreachable;
        };
        self.organization_id = organization_id;
        self.project_id = project_id;

        // init sub components
        self.chat = Chat.init(&self);
        self.embeddings = Embeddings.init(&self);

        // client headers
        const auth_header = try std.fmt.allocPrint(self.arena.allocator(), "Bearer {s}", .{self.api_key});
        self.headers = .{ .authorization = .{ .override = auth_header }, .content_type = .{ .override = "application/json" } };
        return self;
    }

    pub fn deinit(self: *OpenAI) void {
        std.debug.print("Deiniting client\n", .{});
        self.client.deinit();
        std.debug.print("Deiniting chat\n", .{});
        self.chat.deinit();
        std.debug.print("Deiniting embeddings\n", .{});
        self.embeddings.deinit();
        std.debug.print("Deiniting arena\n", .{});
        self.arena.deinit();
        std.debug.print("Deiniting allocator\n", .{});
        self.allocator.destroy(self.arena);
    }

    pub fn request(self: *const OpenAI, method: http.Method, path: []const u8, options: RequestOptions) ![]const u8 {
        // FUTURE ME, if I don't assign the allocator to a local variable, I get segfaults- no clue why
        const allocator = self.arena.allocator();
        std.debug.print("The type of allocator: {s}\n", .{@typeName(@TypeOf(allocator))});
        const url_string = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.base_url, path });
        defer allocator.free(url_string);

        log.debug("{s} - {s}", .{ @tagName(method), url_string });

        const uri = try std.Uri.parse(url_string);

        const server_header_buffer = try allocator.alloc(u8, 8 * 1024 * 4);
        defer allocator.free(server_header_buffer);

        // std.debug.print("server_header_buffer\n", .{});

        // Create a new client for each request to avoid connection pool issues
        var client = http.Client{ .allocator = allocator };
        defer client.deinit();

        // std.debug.print("client\n", .{});
        std.debug.print("headers: {any}\n", .{self.headers});

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
            // req.transfer_encoding = .chunked;
            std.debug.print("Sending Body: {s}\n", .{body});
            try req.writer().writeAll(body);
            try req.finish();
        }
        try req.wait();

        log.info("{s} - {s} - {d} {s}", .{ @tagName(method), url_string, @intFromEnum(req.response.status), req.response.status.phrase() orelse "None" });

        if (req.response.status == .ok) {
            const response = try req.reader().readAllAlloc(allocator, 2048);
            return response;
        } else {
            const response = try req.reader().readAllAlloc(allocator, 2048);
            return response;
        }
    }
};

test "OpenAI.init no api key" {
    const allocator = std.testing.allocator;
    const openai = OpenAI.init(allocator, .{});
    try std.testing.expectError(ConfigError.OpenAIAPIKeyNotSet, openai);
}

test "Completions.create" {
    const allocator = std.testing.allocator;
    var openai = try OpenAI.init(allocator, .{
        .api_key = "my_api_key",
    });
    defer openai.deinit();
    const request = ChatRequest{
        .model = "gpt-4o",
        .messages = &[_]ChatMessage{
            .{ .role = "user", .content = "Hello, world!" },
        },
    };
    const response = try openai.chat.completions.create(request);
    try std.testing.expect(std.mem.eql(u8, response, ""));
}
