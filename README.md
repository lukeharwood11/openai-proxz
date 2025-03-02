![Static Badge](https://img.shields.io/badge/zig-0.13.0-%23F7A41D?logo=zig&logoColor=%23F7A41D)
![Static Badge](https://img.shields.io/badge/License-MIT-blue)

# ProxZ 🦎

An OpenAI API library for the Zig programming language!

## ⭐️ Features ⭐️

- An easy to use interface, similar to that of `openai-python`
- Built-in retry logic
- Environment variable config support for API keys, org. IDs, project IDs, and base urls
- Response streaming support
- Integration with the most popular OpenAI endpoints with a generic `request`/`requestStream` method for missing endpoints

## Installation

> [!NOTE]  
> This is only compatible with zig version 0.13.0 at this time.

To install the latest version of `proxz`, run

```bash
 zig fetch --save "git+https://github.com/lukeharwood11/openai-proxz"
```

To install a specific version, run

```bash
zig fetch --save "https://github.com/lukeharwood11/openai-proxz/archive/refs/tags/<version>.tar.gz"
```

And add the following to your `build.zig`

```zig
const proxz = b.dependency("proxz", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("proxz", proxz.module("proxz"));
```

## Usage

|✨ Documentation ✨||
|--|--|
|📙 ProxZ Docs |<https://proxz.mle.academy> |
|📗 OpenAI API Docs|<https://platform.openai.com/docs/api-reference>|

### Client Configuration

```zig
const proxz = @import("proxz");
const OpenAI = proxz.OpenAI;
```

```zig
// make sure you have an OPENAI_API_KEY environment variable set,
// or pass in a .api_key field to explicitly set!
var openai = try OpenAI.init(allocator, .{});
defer openai.deinit();
```

### Chat Completions

#### Regular

```zig
const ChatMessage = proxz.ChatMessage;

var response = try openai.chat.completions.create(.{
    .model = "gpt-4o",
    .messages = &[_]ChatMessage{
        .{
            .role = "user",
            .content = "Hello, world!",
        },
    },
});
// This will free all the memory allocated for the response
defer response.deinit();
std.log.debug("{s}", .{response.choices[0].message.content});
```

#### Streamed Response

```zig
var stream = try openai.chat.completions.createStream(.{
    .model = "gpt-4o-mini",
    .messages = &[_]ChatMessage{
        .{
            .role = "user",
            .content = "Write me a poem about lizards. Make it a paragraph or two.",
        },
    },
});
defer stream.deinit();

std.debug.print("\n", .{});
while (try stream.next()) |val| {
    std.debug.print("{s}", .{val.choices[0].delta.content});
}
std.debug.print("\n", .{});
```

### Embeddings

```zig
const inputs = [_][]const u8{ "Hello", "Foo", "Bar" };
const response = try openai.embeddings.create(.{
    .model = "text-embedding-3-small",
    .input = &inputs,
});
// Don't forget to free resources!
defer response.deinit();
std.log.debug("Model: {s}\nNumber of Embeddings: {d}\nDimensions of Embeddings: {d}", .{
    response.model,
    response.data.len,
    response.data[0].embedding.len,
});
```

### Models

#### Get model details

```zig
var response = try openai.models.retrieve("gpt-4o");
defer response.deinit();
std.log.debug("Model is owned by '{s}'", .{response.owned_by});
```

#### List all models

```zig
var response = try openai.models.list();
defer response.deinit();
std.log.debug("The first model you have available is '{s}'", .{response.data[0].id})
```

## Configuring Logging

By default all logs are enabled for your entire application.
To configure your application, and set the log level for `proxz`, include the following in your `main.zig`.

```zig
pub const std_options = std.Options{
    .log_level = .debug, // this sets your app level log config
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{
            .scope = .proxz,
            .level = .info, // set to .debug, .warn, .info, or .err
        },
    },
};
```

All logs in `proxz` use the scope `.proxz`, so if you don't want to see debug/info logs of the requests being sent, set `.level = .err`. This will only display when an error occurs that `proxz` can't recover from.

## Contributions

Contributions are welcome and encouraged! Submit an issue for any bugs/feature requests and open a PR if you tackled one of them!

## Building Docs

```bash
zig build docs
```
