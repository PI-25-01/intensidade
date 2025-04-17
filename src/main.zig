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
                    cor.r = @intFromFloat(std.math.round(C_CONST * std.math.pow(f32, @floatFromInt(cor.r), GAMMA)));
                    cor.g = @intFromFloat(std.math.round(C_CONST * std.math.pow(f32, @floatFromInt(cor.g), GAMMA)));
                    cor.b = @intFromFloat(std.math.round(C_CONST * std.math.pow(f32, @floatFromInt(cor.b), GAMMA)));
                    cor.a = @intFromFloat(std.math.round(C_CONST * std.math.pow(f32, @floatFromInt(cor.a), GAMMA)));
                    max.r = if (max.r < cor.r) cor.r else max.r;
                    max.g = if (max.r < cor.g) cor.g else max.g;
                    max.b = if (max.r < cor.b) cor.b else max.b;
                    max.a = if (max.r < cor.a) cor.a else max.a;
                    min.r = if (cor.r < min.r) cor.r else min.r;
                    min.g = if (cor.g < min.g) cor.g else min.g;
                    min.b = if (cor.b < min.b) cor.b else min.b;
                    min.a = if (cor.a < min.a) cor.a else min.a;
                }

                for (ln_colors) |*cor| {
                    //std.debug.print("{d} {d}\n", .{ max.r, min.r });
                    cor.r = if (max.r - min.r == 0) 0 else (cor.r / (max.r - min.r)) * 255;
                    cor.g = if (max.g - min.g == 0) 0 else (cor.g / (max.g - min.g)) * 255;
                    cor.b = if (max.b - min.b == 0) 0 else (cor.b / (max.b - min.b)) * 255;
                    cor.a = if (max.a - min.a == 0) 0 else (cor.a / (max.a - min.a)) * 255;
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
        if (img_tx) |_| {
            // Imagem original
            rl.drawText("Imagem original", 0, 4, 32, .black);
            rl.drawTexture(img_tx.?, 0, 64, .white);

            // Transformação de potência
            rl.drawText("Transformação de potência", ln_tx.?.width + 64, 4, 32, .black);
            rl.drawTexture(ln_tx.?, img_tx.?.width + 64, 64, .white);
        }
        rl.endMode2D();
    }
}

fn sumImgColors(rs_colors: *[]rl.Color, colors1: []rl.Color, colors2: []rl.Color) void {
    for (0..colors1.len) |i| {
        if (@as(u16, colors1[i].r) + @as(u16, colors2[i].r) > 255) {
            rs_colors.ptr[i].r = @intCast((@as(u16, colors1[i].r) + @as(u16, colors2[i].r)) / 2);
        } else {
            rs_colors.ptr[i].r = colors1[i].r + colors2[i].r;
        }

        if (@as(u16, colors1[i].g) + @as(u16, colors2[i].g) > 255) {
            rs_colors.ptr[i].g = @intCast((@as(u16, colors1[i].g) + @as(u16, colors2[i].g)) / 2);
        } else {
            rs_colors.ptr[i].g = colors1[i].g + colors2[i].g;
        }

        if (@as(u16, colors1[i].b) + @as(u16, colors2[i].b) > 255) {
            rs_colors.ptr[i].b = @intCast((@as(u16, colors1[i].b) + @as(u16, colors2[i].b)) / 2);
        } else {
            rs_colors.ptr[i].b = colors1[i].b + colors2[i].b;
        }

        if (@as(u16, colors1[i].a) + @as(u16, colors2[i].a) > 255) {
            rs_colors.ptr[i].a = @intCast((@as(u16, colors1[i].a) + @as(u16, colors2[i].a)) / 2);
        } else {
            rs_colors.ptr[i].a = colors1[i].a + colors2[i].a;
        }
    }
}

fn subImgColors(rs_colors: *[]rl.Color, colors1: []rl.Color, colors2: []rl.Color) void {
    var negativest: i32 = 255;
    for (0..colors1.len) |i| {
        const r_sub = @as(i32, colors1[i].r) - @as(i32, colors2[i].r);
        if (r_sub < negativest) {
            negativest = r_sub;
        }
        const g_sub = @as(i32, colors1[i].g) - @as(i32, colors2[i].g);
        if (g_sub < negativest) {
            negativest = g_sub;
        }
        const b_sub = @as(i32, colors1[i].b) - @as(i32, colors2[i].b);
        if (b_sub < negativest) {
            negativest = b_sub;
        }
        const a_sub = @as(i32, colors1[i].a) - @as(i32, colors2[i].a);
        if (a_sub < negativest) {
            negativest = a_sub;
        }
    }

    for (0..colors1.len) |i| {
        const r_sub = @as(i32, colors1[i].r) - @as(i32, colors2[i].r);
        const g_sub = @as(i32, colors1[i].g) - @as(i32, colors2[i].g);
        const b_sub = @as(i32, colors1[i].b) - @as(i32, colors2[i].b);
        const a_sub = @as(i32, colors1[i].a) - @as(i32, colors2[i].a);

        rs_colors.ptr[i].r = @intCast(@divTrunc((r_sub - negativest) * 255, (255 - negativest)));
        rs_colors.ptr[i].g = @intCast(@divTrunc((g_sub - negativest) * 255, (255 - negativest)));
        rs_colors.ptr[i].b = @intCast(@divTrunc((b_sub - negativest) * 255, (255 - negativest)));
        rs_colors.ptr[i].a = @intCast(@divTrunc((a_sub - negativest) * 255, (255 - negativest)));
    }
}

fn flipImgColors(rs_colors: *[]rl.Color) void {
    const half = rs_colors.*.len / 2;
    for (0..half) |i| {
        rs_colors.*.ptr[i].r = rs_colors.*.ptr[i].r ^ rs_colors.*.ptr[rs_colors.*.len - i].r;
        rs_colors.*.ptr[i].g = rs_colors.*.ptr[i].g ^ rs_colors.*.ptr[rs_colors.*.len - i].g;
        rs_colors.*.ptr[i].b = rs_colors.*.ptr[i].b ^ rs_colors.*.ptr[rs_colors.*.len - i].b;
        rs_colors.*.ptr[i].a = rs_colors.*.ptr[i].a ^ rs_colors.*.ptr[rs_colors.*.len - i].a;

        rs_colors.*.ptr[rs_colors.*.len - i].r = rs_colors.*.ptr[i].r ^ rs_colors.*.ptr[rs_colors.*.len - i].r;
        rs_colors.*.ptr[rs_colors.*.len - i].g = rs_colors.*.ptr[i].g ^ rs_colors.*.ptr[rs_colors.*.len - i].g;
        rs_colors.*.ptr[rs_colors.*.len - i].b = rs_colors.*.ptr[i].b ^ rs_colors.*.ptr[rs_colors.*.len - i].b;
        rs_colors.*.ptr[rs_colors.*.len - i].a = rs_colors.*.ptr[i].a ^ rs_colors.*.ptr[rs_colors.*.len - i].a;

        rs_colors.*.ptr[i].r = rs_colors.*.ptr[i].r ^ rs_colors.*.ptr[rs_colors.*.len - i].r;
        rs_colors.*.ptr[i].g = rs_colors.*.ptr[i].g ^ rs_colors.*.ptr[rs_colors.*.len - i].g;
        rs_colors.*.ptr[i].b = rs_colors.*.ptr[i].b ^ rs_colors.*.ptr[rs_colors.*.len - i].b;
        rs_colors.*.ptr[i].a = rs_colors.*.ptr[i].a ^ rs_colors.*.ptr[rs_colors.*.len - i].a;
    }
}
