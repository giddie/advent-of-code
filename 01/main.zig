const std = @import("std");
const FileLineIterator = @import("FileLineIterator.zig");

const input_file = "input";

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Part 1: {d}\n", .{try part1(allocator)});
}

fn part1(allocator: std.mem.Allocator) !usize {
    var file_line_iterator = try FileLineIterator.init(allocator, input_file);
    defer file_line_iterator.deinit();

    var left_list: std.ArrayList(isize) = .empty;
    var right_list: std.ArrayList(isize) = .empty;
    defer left_list.deinit(allocator);
    defer right_list.deinit(allocator);

    var line_number: usize = 0;

    while (try file_line_iterator.next()) |line| {
        line_number += 1;
        const parsed = parseLine(line) catch |err| {
            std.debug.print("Line {d}: \"{s}\"\n", .{ line_number, line });
            return err;
        };
        try left_list.append(allocator, parsed.left);
        try right_list.append(allocator, parsed.right);
    }

    std.mem.sort(isize, left_list.items, {}, std.sort.asc(isize));
    std.mem.sort(isize, right_list.items, {}, std.sort.asc(isize));

    var sum: usize = 0;
    for (left_list.items, right_list.items) |left, right| {
        sum += @abs(left - right);
    }

    return sum;
}

fn parseLine(line: []const u8) !struct { left: isize, right: isize } {
    var token_iterator = std.mem.tokenizeScalar(u8, line, ' ');

    const left_token = token_iterator.next() orelse return error.NoLeftToken;
    const right_token = token_iterator.next() orelse return error.NoRightToken;
    if (token_iterator.peek() != null) return error.UnexpectedToken;

    const left = std.fmt.parseInt(isize, left_token, 10) catch return error.NotInteger;
    const right = std.fmt.parseInt(isize, right_token, 10) catch return error.NotInteger;

    return .{
        .left = left,
        .right = right,
    };
}
