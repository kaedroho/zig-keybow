const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const i2c = rp2xxx.i2c;
const I2C_Device = rp2xxx.drivers.I2C_Device;

const pin_config = rp2xxx.pins.GlobalConfiguration{
    // Switch pins
    .GPIO21 = .{
        .name = "sw0",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO20 = .{
        .name = "sw1",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO19 = .{
        .name = "sw2",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO18 = .{
        .name = "sw3",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO17 = .{
        .name = "sw4",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO16 = .{
        .name = "sw5",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO15 = .{
        .name = "sw6",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO14 = .{
        .name = "sw7",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO13 = .{
        .name = "sw8",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO12 = .{
        .name = "sw9",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO11 = .{
        .name = "sw10",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO10 = .{
        .name = "sw11",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO9 = .{
        .name = "sw12",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO8 = .{
        .name = "sw13",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO7 = .{
        .name = "sw14",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    .GPIO6 = .{
        .name = "sw15",
        .function = .SIO,
        .direction = .in,
        .pull = .up,
    },
    // I2C pins used for LED driver
    .GPIO4 = .{
        .name = "led_sda",
        .function = .I2C0_SDA,
        .slew_rate = .slow,
        //.schmitt_trigger = .enabled,
    },
    .GPIO5 = .{
        .name = "led_scl",
        .function = .I2C0_SCL,
        .slew_rate = .slow,
        //.schmitt_trigger = .enabled,
    },
};

const pins = pin_config.pins();
const i2c0 = i2c.instance.num(0);

const SWITCHES: [16]@TypeOf(pins.sw0) = .{
    pins.sw0,
    pins.sw1,
    pins.sw2,
    pins.sw3,
    pins.sw4,
    pins.sw5,
    pins.sw6,
    pins.sw7,
    pins.sw8,
    pins.sw9,
    pins.sw10,
    pins.sw11,
    pins.sw12,
    pins.sw13,
    pins.sw14,
    pins.sw15,
};

// Switches are pulled up so they are 0 when pressed and 1 when released
const SWITCH_PRESSED: u1 = 0;
const SWITCH_RELEASED: u1 = 1;

const LED_DRIVER_ADDRESS: i2c.Address = .new(0x74);
const LED_DRIVER_CONFIG_BANK = 0x0b;

const Buffer = [0xb3]u8;

const Register = enum(u8) {
    MODE = 0x00,
    FRAME = 0x01,
    AUTPLAY1 = 0x02,
    AUTOPLAY2 = 0x03,
    BLINK = 0x05,
    AUDIOSYNC = 0x06,
    BREATH1 = 0x07,
    BREATH2 = 0x08,
    SHUTDOWN = 0x0a,
    GAIN = 0x0b,
    ADC = 0x0c,
    BANK = 0xfd,
};

pub fn led_driver_write_register(reg: Register, value: u8) !void {
    try i2c0.write_blocking(LED_DRIVER_ADDRESS, &[2]u8{ @intFromEnum(reg), value }, null);
}

pub fn led_driver_init(buffer: *Buffer) !void {
    i2c0.apply(.{
        .clock_config = rp2xxx.clock_config,
    });

    try led_driver_write_register(.BANK, LED_DRIVER_CONFIG_BANK);
    try led_driver_write_register(.SHUTDOWN, 0x00);
    try led_driver_update(0, buffer);
    try led_driver_write_register(.SHUTDOWN, 0x01);
}

pub fn led_driver_update(frame: u8, buffer: *Buffer) !void {
    try led_driver_write_register(.BANK, frame);
    try i2c0.write_blocking(LED_DRIVER_ADDRESS, buffer, null);
    try led_driver_write_register(.BANK, LED_DRIVER_CONFIG_BANK);
}

// A mapping of colour/switch number to positions in the buffer that is sent to the LED driver
// First byte is the byte offset in the buffer, second byte is the bit to use
const LED_MAP: [3][16][2]u8 = .{
    // RED
    .{
        .{ 0x10, 0x08 },
        .{ 0x10, 0x04 },
        .{ 0x10, 0x02 },
        .{ 0x10, 0x01 },
        .{ 0x12, 0x08 },
        .{ 0x12, 0x04 },
        .{ 0x12, 0x02 },
        .{ 0x12, 0x01 },
        .{ 0x0f, 0x08 },
        .{ 0x0f, 0x04 },
        .{ 0x0f, 0x02 },
        .{ 0x0f, 0x01 },
        .{ 0x11, 0x08 },
        .{ 0x11, 0x04 },
        .{ 0x11, 0x02 },
        .{ 0x11, 0x01 },
    },
    // GREEN
    .{
        .{ 0x0c, 0x08 },
        .{ 0x0c, 0x04 },
        .{ 0x0c, 0x02 },
        .{ 0x0c, 0x01 },
        .{ 0x04, 0x04 },
        .{ 0x04, 0x02 },
        .{ 0x06, 0x02 },
        .{ 0x06, 0x01 },
        .{ 0x0b, 0x08 },
        .{ 0x0b, 0x04 },
        .{ 0x0b, 0x02 },
        .{ 0x0b, 0x01 },
        .{ 0x03, 0x04 },
        .{ 0x03, 0x02 },
        .{ 0x05, 0x02 },
        .{ 0x05, 0x01 },
    },
    // BLUE
    .{
        .{ 0x0e, 0x08 },
        .{ 0x0e, 0x04 },
        .{ 0x0e, 0x02 },
        .{ 0x0e, 0x01 },
        .{ 0x0a, 0x08 },
        .{ 0x0a, 0x04 },
        .{ 0x0a, 0x02 },
        .{ 0x0a, 0x01 },
        .{ 0x0d, 0x08 },
        .{ 0x0d, 0x04 },
        .{ 0x0d, 0x02 },
        .{ 0x0d, 0x01 },
        .{ 0x09, 0x08 },
        .{ 0x09, 0x04 },
        .{ 0x09, 0x02 },
        .{ 0x09, 0x01 },
    },
};

const Colour = enum {
    Red,
    Green,
    Blue,
};

pub fn set_led_state(buffer: *Buffer, switch_number: u8, colour: Colour, state: bool) void {
    const colour_number: u8 = if (colour == .Red) 0 else if (colour == .Green) 1 else 2;

    if (state) {
        buffer[LED_MAP[colour_number][switch_number][0]] |= LED_MAP[colour_number][switch_number][1];
    } else {
        buffer[LED_MAP[colour_number][switch_number][0]] &= ~LED_MAP[colour_number][switch_number][1];
    }
}

pub fn main() !void {
    pin_config.apply();

    var led_buffer: Buffer = std.mem.zeroes(Buffer);

    // Set all PWMs to max
    @memset(std.mem.asBytes(led_buffer[0x24..]), 0xff);

    try led_driver_init(&led_buffer);

    while (true) {
        // Switch all LEDs
        @memset(led_buffer[0..0x24], 0x00);

        inline for (SWITCHES, 0..) |sw, idx| {
            if (sw.read() == SWITCH_PRESSED) {
                set_led_state(&led_buffer, idx, .Red, true);
            }
        }

        try led_driver_update(0, &led_buffer);
    }
}
