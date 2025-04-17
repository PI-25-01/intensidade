const std = @import("std");
const rl = @import("raylib");

const WINDOW_WIDTH = 1080;
const WINDOW_HEIGHT = 720;

var camera = rl.Camera2D{
    .offset = .{ .x = WINDOW_WIDTH / 2, .y = WINDOW_HEIGHT / 2 },
    .target = .{ .x = WINDOW_WIDTH / 2, .y = WINDOW_HEIGHT / 2 },
    .rotation = 0,
    .zoom = 1,
};

var img_tx: ?rl.Texture = null;

var ln_tx: ?rl.Texture = null;

const GAMMA = 0.4;
const C_CONST = 1.0;

pub fn main() !void {
    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Transformação de intensidade");
    defer {
        if (img_tx) |_| {
            rl.unloadTexture(img_tx.?);
            rl.unloadTexture(ln_tx.?);
        }
        rl.closeWindow();
    }

    while (!rl.windowShouldClose()) {
        if (rl.isFileDropped()) {
            if (img_tx) |_| {
                rl.unloadTexture(img_tx.?);
                rl.unloadTexture(ln_tx.?);
            }
            const files = rl.loadDroppedFiles();
            defer rl.unloadDroppedFiles(files);

            if (files.count > 1) {
                std.debug.print("Err: Número de errado de arquivos", .{});
            } else {
                img_tx = try rl.loadTexture(std.mem.span(files.paths[0]));

                const img = try rl.loadImageFromTexture(img_tx.?);
                const img_colors = try rl.loadImageColors(img);
                defer rl.unloadImageColors(img_colors);
                const format = img_tx.?.format;

                var ln = rl.imageCopy(img);
                const ln_colors = try rl.loadImageColors(ln);

                var max = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
                var min = rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

                for (ln_colors) |*cor| {
                    const grey: u8 = @intCast((@as(u16, cor.r) + @as(u16, cor.g) + @as(u16, cor.r)) / 3);
                    cor.r = @intFromFloat(std.math.round(C_CONST * std.math.pow(f32, @floatFromInt(grey), GAMMA)));
                    cor.g = cor.r;
                    cor.b = cor.r;
                    max.r = if (max.r < cor.r) cor.r else max.r;
                    max.g = if (max.r < cor.g) cor.g else max.g;
                    max.b = if (max.r < cor.b) cor.b else max.b;
                    min.r = if (cor.r < min.r) cor.r else min.r;
                    min.g = if (cor.g < min.g) cor.g else min.g;
                    min.b = if (cor.b < min.b) cor.b else min.b;
                }

                for (ln_colors) |*cor| {
                    if (max.r - min.r != 0) {
                        cor.r = @as(u8, @intFromFloat(std.math.clamp(
                            std.math.round(@as(f64, @floatFromInt(cor.r)) / @as(f64, @floatFromInt(max.r - min.r)) * 255),
                            0,
                            255,
                        )));
                    }
                    cor.g = cor.r;
                    cor.b = cor.r;
                }

                ln.data = ln_colors.ptr;
                ln.format = .uncompressed_r8g8b8a8;

                rl.imageFormat(&ln, format);

                ln_tx = try rl.loadTextureFromImage(ln);
            }
        }

        if (rl.isMouseButtonDown(.left)) {
            camera.target.x -= rl.getMouseDelta().x * rl.getFrameTime() * 3000.0 * (1 / camera.zoom);
            camera.target.y -= rl.getMouseDelta().y * rl.getFrameTime() * 3000.0 * (1 / camera.zoom);
        }

        if (camera.zoom + rl.getMouseWheelMove() / 10 > 0) {
            camera.zoom += rl.getMouseWheelMove() / 10;
        }

        rl.beginDrawing();
        rl.beginMode2D(camera);
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);

        // Imagem original

        // Transformação de potência

        if (img_tx) |_| {
            // Imagem original
            rl.drawTexture(img_tx.?, 0, 64, .white);
            rl.drawText("Imagem original", 4, 4, 32, .black);

            // Transformação de potência
            rl.drawTexture(ln_tx.?, img_tx.?.width + 64, 64, .white);
            rl.drawText("Transformação de potência", ln_tx.?.width + 64, 4, 32, .black);
        } else {
            rl.drawText("Arraste uma imagem aqui para começar", 4, 4, 32, .black);
        }
        rl.endMode2D();
    }
}
