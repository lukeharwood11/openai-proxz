![static](https://img.shields.io/badge/zig-0.13.0-orange)

# ProxZ

An OpenAI API library for the Zig programming language!

## Installation

To install `proxz`, run

```bash
 zig fetch --save "git+https://github.com/lukeharwood11/openai-proxz#3fd51f2247929c4d161e5a1ed53f2b8aef104261"
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

### Client Configuration

```zig
const proxz = @import("proxz");
const OpenAI = proxz.OpenAI;
```

```zig
// make sure you have an OPENAI_API_KEY environment variable set!
var openai = try OpenAI.init(allocator, .{});
defer openai.deinit();
```

### Chat Completions
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
std.log.debug("{s}", .{response.value.choices[0].message.content});
```

## Contributions

Contributions are welcome and encouraged! Submit an issue for any bugs/feature requests and open a PR if you tackled one of them!