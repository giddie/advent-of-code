const std = @import("std");
const FileLineIterator = @import("FileLineIterator.zig");

const input_file = "input";

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Part 1: {d}\n", .{try part1(allocator)});
    std.debug.print("Part 2: {d}\n", .{try part2(allocator)});
}

fn part1(allocator: std.mem.Allocator) !usize {
    var lists = try readLists(allocator);
    defer lists.left.deinit(allocator);
    defer lists.right.deinit(allocator);

    std.mem.sort(isize, lists.left.items, {}, std.sort.asc(isize));
    std.mem.sort(isize, lists.right.items, {}, std.sort.asc(isize));

    var sum: usize = 0;
    for (lists.left.items, lists.right.items) |left, right| {
        sum += @abs(left - right);
    }

    return sum;
}

fn part2(allocator: std.mem.Allocator) !isize {
    var lists = try readLists(allocator);
    defer lists.left.deinit(allocator);
    defer lists.right.deinit(allocator);

    var frequencies: std.AutoHashMap(isize, isize) = .init(allocator);
    defer frequencies.deinit();

    for (lists.right.items) |item| {
        const result = try frequencies.getOrPut(item);
        if (result.found_existing) {
            result.value_ptr.* += 1;
        } else {
            result.value_ptr.* = 1;
        }
    }

    var sum: isize = 0;
    for (lists.left.items) |item| {
        if (frequencies.get(item)) |frequency| {
            sum += item * frequency;
        }
    }

    return sum;
}

fn readLists(allocator: std.mem.Allocator) !struct { left: std.ArrayList(isize), right: std.ArrayList(isize) } {
    var file_line_iterator = try FileLineIterator.init(allocator, input_file);
    defer file_line_iterator.deinit();

    var left_list: std.ArrayList(isize) = .empty;
    var right_list: std.ArrayList(isize) = .empty;

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

    return .{
        .left = left_list,
        .right = right_list,
    };
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
