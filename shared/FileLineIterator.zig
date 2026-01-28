const std = @import("std");

file: std.fs.File,
reader_buffer: [8192]u8,
file_reader: std.fs.File.Reader,
line_buffer: std.io.Writer.Allocating,

pub fn init(allocator: std.mem.Allocator, file_path: []const u8) !@This() {
    var self = @This(){
        .file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only }),
        .reader_buffer = undefined,
        .file_reader = undefined,
        .line_buffer = undefined,
    };
    self.file_reader = self.file.reader(&self.reader_buffer);
    self.line_buffer = .init(allocator);
    return self;
}

pub fn deinit(self: *@This()) void {
    self.line_buffer.deinit();
    self.file.close();
}

pub fn next(self: *@This()) !?[]const u8 {
    self.line_buffer.clearRetainingCapacity();
    _ = self.file_reader.interface.streamDelimiter(&self.line_buffer.writer, '\n') catch |err| switch (err) {
        error.EndOfStream => {
            if (self.line_buffer.written().len > 0) {
                return self.line_buffer.written();
            } else {
                return null;
            }
        },
        else => return err,
    };
    self.file_reader.interface.toss(1);
    return self.line_buffer.written();
}
