const std = @import("std");
const Io = std.Io;

const test_raylib = @import("test_raylib");

const rl = @import("raylib");

var HOURS: u6 = 0;
var MINUTES: u6 = 0;
var SECONDS: u6 = 0;
var IS_PAUSED: bool = false;

var mutex: std.Io.Mutex = .init;
var running: std.atomic.Value(bool) = .init(true);

fn incrementTime(init: std.process.Init) !void {
    const io = init.io;

    while (running.load(.monotonic)) {
        var ts = std.posix.timespec{ .sec = 1, .nsec = 0 };
        _ = std.posix.system.nanosleep(&ts, &ts);

        try mutex.lock(io);
        defer mutex.unlock(io);

        if (!IS_PAUSED) {
            if (SECONDS + 1 < 60) SECONDS += 1 else {
                SECONDS = 0;

                if (MINUTES + 1 < 60) MINUTES += 1 else {
                    MINUTES = 0;

                    if (HOURS + 1 < 24) HOURS += 1 else {
                        HOURS = 0;
                    }
                }
            }
        }
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var thread: std.Thread = undefined;

    const screen_width: u16 = 800;
    const screen_hight: u16 = 450;

    rl.InitWindow(screen_width, screen_hight, "Timer for MeLove");
    defer rl.CloseWindow();

    const background = rl.LoadTexture("src/resources/mage.png");
    defer rl.UnloadTexture(background);

    rl.SetTargetFPS(60);

    thread = try std.Thread.spawn(.{}, incrementTime, .{init});

    const white_tint = rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyPressed(rl.KEY_SPACE)) {
            try mutex.lock(io);
            IS_PAUSED = !IS_PAUSED;
            mutex.unlock(io);
        }

        if (rl.IsKeyPressed(rl.KEY_R)) {
            try mutex.lock(io);
            SECONDS = 0;
            MINUTES = 0;
            HOURS = 0;
            mutex.unlock(io);
        }

        var buf: [64]u8 = undefined;
        const text = try std.fmt.bufPrintSentinel(
            &buf,
            "{d}:{d}:{d}\n",
            .{ HOURS, MINUTES, SECONDS },
            0,
        );

        var status_buf: [64]u8 = undefined;
        const status_text = try std.fmt.bufPrintSentinel(
            &status_buf,
            "[{s}] - [SPACE] Pause/Resume | [R] Reset",
            .{if (IS_PAUSED) "PAUSED" else "RUNNING"},
            0,
        );

        rl.BeginDrawing();
        rl.ClearBackground(rl.GetColor(0x052c46ff));

        const source_rec = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(background.width),
            .height = @floatFromInt(background.height),
        };
        const dest_rec = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(screen_width),
            .height = @floatFromInt(screen_hight),
        };
        rl.DrawTexturePro(background, source_rec, dest_rec, .{ .x = 0, .y = 0 }, 0.0, white_tint);

        rl.DrawText(text.ptr, 300, 200, 90, rl.RAYWHITE);
        rl.DrawText(status_text.ptr, 120, 280, 20, if (IS_PAUSED) rl.RED else rl.WHITE);

        rl.EndDrawing();
    }

    running.store(false, .monotonic);
    thread.join();
}
