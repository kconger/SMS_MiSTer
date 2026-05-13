//============================================================================
//  SMS replica
//
//  Port to MiSTer
//  Copyright (C) 2017-2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);


assign ADC_BUS  = 'Z;
assign VGA_F1 = 0;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign {SD_SCK, SD_MOSI, SD_CS} = '1;

assign LED_USER  = cart_download | bk_state | (status[25] & bk_pending);
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = osd_btn;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;
assign FB_FORCE_BLANK = 0;

wire video_rotated;
wire no_rotate = 1'b1;
wire flip = 1'b0;
wire rotate_ccw = 1'b0;
wire [5:0] arx = 6'd8;
wire [5:0] ary = 6'd3;

wire [1:0] ar = status[27:26];
wire vga_de;
screen_rotate screen_rotate (.*);
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? arx : (ar - 1'd1)),
	.ARY((!ar) ? ary : 12'd0),
	.CROP_SIZE(12'd0),
	.CROP_OFF(5'd0),
	.SCALE(status[31:30])
);


// Status Bit Map:
//             Upper                             Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXXXXXX XXXXXXXXXXXXXXX XXXXXXXXXXX       XXXXXXX XXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"GAMEGEAR2P;;",
	"-;",
	"H8FS2,GG;",
	"DIP;",
	"-;",
	"H8OP,Autosave,OFF,ON;",
	"H8H9D0R6,Load Backup RAM;",
	"H8H9D0R7,Save Backup RAM;",
	"H8-;",

	"H8OA,Region,US/EU,Japan;",
	"H8o8,Z80 Speed,Normal,Turbo;",

	"P1,Audio & Video;",
	"P1-;",
	"P1OQR,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1OUV,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1O8,Sprites Per Line,Standard,All;",
	"P1-;",
	"P1oT,Separator Line,Off,On;",
	"P1oUV,Audioselect,GG 1,GG 2,Mixed,Split 1=L 2=R;",

	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Pause;",
	"jn,A|P,B,Start;",
	"jp,Y|P,A,Start;",
	"V,v",`BUILD_DATE
};


////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(locked)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin
	reg pald = 0, pald2 = 0;
	reg [2:0] state = 0;
	reg pal_r;

	pald <= pal;
	pald2 <= pald;

	cfg_write <= 0;
	if(pald2 == pald && pald2 != pal_r) begin
		state <= 1;
		pal_r <= pald2;
	end

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 7;
					cfg_data <= pal_r ? 2201376125 : 2537930535;
					cfg_write <= 1;
				end
			7: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

// Game Gear-only build: no BIOS file, System E, SG/SC, or SK-1100 config reset paths.
wire ext_bios_loaded = 1'b0;
wire raw_reset = RESET | status[0] | buttons[1] | cart_download | bk_loading;

reg [13:0] ram_clr_addr;
reg        ram_clr_run = 0;

always_ff @(posedge clk_sys) begin
	if (raw_reset) begin
		ram_clr_addr <= 0;
		ram_clr_run  <= 1'b1;
	end else if (ram_clr_run) begin
		ram_clr_addr <= ram_clr_addr + 1'd1;
		if (ram_clr_addr == 14'h3FFF) ram_clr_run <= 1'b0;
	end
end

wire reset_active = raw_reset | ram_clr_run;
localparam [21:0] SYSTEM2_RESET_DELAY_CYCLES = 22'd3_000_000;
reg [21:0] system2_reset_delay = SYSTEM2_RESET_DELAY_CYCLES;

always_ff @(posedge clk_sys) begin
	if (reset_active)
		system2_reset_delay <= SYSTEM2_RESET_DELAY_CYCLES;
	else if (system2_reset_delay != 0)
		system2_reset_delay <= system2_reset_delay - 1'd1;
end

// Keep the second handheld in reset a little longer so link startup is not
// perfectly cycle-synchronized between the two emulated systems.
wire reset2_active = reset_active | (system2_reset_delay != 0);

//////////////////   HPS I/O   ///////////////////
wire [15:0] joy_0, joy_1, joy_2, joy_3;
wire  [7:0] joy[4];
wire  [7:0] joy0_x,joy0_y,joy1_x,joy1_y;
wire  [7:0] paddle_0, paddle_1;
wire  [1:0] buttons;
wire [10:0] ps2_key;
wire [63:0] status;
reg  [127:0] status_in = 0;
reg          status_set = 0;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire [31:0] ioctl_file_ext;
wire        ioctl_wait;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire        forced_scandoubler;
wire [21:0] gamma_bus;

wire [24:0] ps2_mouse;

hps_io #(.CONF_STR(CONF_STR), .WIDE(0)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.joystick_0(joy_0),
	.joystick_1(joy_1),
	.joystick_2(joy_2),
	.joystick_3(joy_3),
	.joystick_l_analog_0({joy0_y, joy0_x}),
	.joystick_l_analog_1({joy1_y, joy1_x}),
	.paddle_0(paddle_0),
	.paddle_1(paddle_1),

	.buttons(buttons),
	.ps2_key(ps2_key),
	.status(status),
	.status_in(status_in),
	.status_set(status_set),
	.status_menumask(10'd0),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(pal),
	.gamma_bus(gamma_bus),

	.ps2_kbd_led_use(0),
	.ps2_kbd_led_status(0),

	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_file_ext(ioctl_file_ext),

	.ioctl_wait(ioctl_wait),

	.sd_lba('{sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.ps2_mouse(ps2_mouse)
);

wire [21:0] ram_addr1;
wire  [7:0] ram_dout1;
wire        ram_rd1;
wire [21:0] ram_addr2;
wire  [7:0] ram_dout2;
wire        ram_rd2;

wire bios_download = 1'b0;
wire cart_download = ioctl_download & (ioctl_index[4:0] == 2);

wire bios_en      = 1'b0;
wire ext_bios_sel = 1'b0;
wire soft_reset_btn = 1'b0;

// SYSMODE[0]: [0]=EncryptBase,[1]=EncryptBank,[2]=Paddle,[3]=Pedal,[4,5]=E0Type,[6]=E1,[7]=E2
// SYSMODE[1]: [0]=
reg [7:0] SYSMODE[1];
reg [7:0] DSW[3];
always @(posedge clk_sys) begin
	if (ioctl_wr) begin
		if ((ioctl_index==4  ) && !ioctl_addr[24:1]) SYSMODE[ioctl_addr[0]] <= ioctl_dout;
		if ((ioctl_index==254) && !ioctl_addr[24:2]) DSW[ioctl_addr[1:0]] <= ioctl_dout;
	end
end

sdram ram
(
	.*,

	.init(~locked),
	.clk(clk_sys),
	.clkref(turbo ? ce_pix : ce_cpu),

	.waddr(romwr_a),
	.din(ioctl_dout),
	.we(rom_wr),
	.we_ack(sd_wrack),

	.raddr(cart_sz512 ? (ram_addr1 + 10'd512) & cart_mask512 : ram_addr1 & cart_mask),
	.dout(ram_dout1),
	.rd(ram_rd1),
	.rd_rdy(),

	.raddr2(cart_sz512 ? (ram_addr2 + 10'd512) & cart_mask512 : ram_addr2 & cart_mask),
	.dout2(ram_dout2),
	.rd2(ram_rd2),
	.rd2_rdy()
);

altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk_sys),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);

reg  rom_wr = 0;
wire sd_wrack;
reg  [23:0] romwr_a;
reg  ysj_quirk = 0;

always @(posedge clk_sys) begin
	reg [31:0] cart_id;
	reg old_download;
	old_download <= cart_download;

	if(~old_download && cart_download) {ysj_quirk} <= 0;

	if(ioctl_wr & cart_download) begin
		if(ioctl_addr == 'h7ffc) cart_id[31:24] <= ioctl_dout[7:0];
		if(ioctl_addr == 'h7ffd) cart_id[23:16] <= ioctl_dout[7:0];
		if(ioctl_addr == 'h7ffe) cart_id[15:08] <= ioctl_dout[7:0];
		if(ioctl_addr == 'h7fff) cart_id[07:00] <= ioctl_dout[7:0];
		if(ioctl_addr == 'h8000) begin
			if(cart_id == 32'h13_70_01_4F) ysj_quirk <= 1; // Ys (Japan) Graphics Fix, forces VDP Version 1
		end
	end
end

always @(posedge clk_sys) begin
	reg old_download, old_reset;

	old_download <= cart_download;
	old_reset <= reset_active;

	if(~old_reset && reset_active) ioctl_wait <= 0;
	if(~old_download && cart_download) romwr_a <= 0;
	else begin
		if(ioctl_wr & cart_download) begin
			ioctl_wait <= 1;
			rom_wr <= ~rom_wr;
		end else if(ioctl_wait && (rom_wr == sd_wrack)) begin
			ioctl_wait <= 0;
			romwr_a <= romwr_a + 1'd1;
		end
	end
end

assign AUDIO_S = 1;
assign AUDIO_MIX = 1;

reg dbr = 0;
always @(posedge clk_sys) begin
	if(cart_download) dbr <= 1;
end
// [Handled in unified control block above]

wire       gg          = 1'b1;
wire       systeme     = 1'b0;
wire       palettemode = 1'b0;
reg [21:0] cart_mask = 0;
reg [21:0] cart_mask512 = 0;
reg        cart_sz512 = 0;

always @(posedge clk_sys) begin
	reg old_download;
	old_download <= cart_download;
	status_set <= 1'b0;

	if (~old_download & cart_download) begin
		cart_mask <= 0;
		cart_mask512 <= 0;
		cart_sz512 <= 0;
	end else if (ioctl_wr & cart_download) begin
		cart_mask <= cart_mask | ioctl_addr[21:0];
		cart_mask512 <= cart_mask512 | (ioctl_addr[21:0] - 10'd512);
		if (!ioctl_addr)
			cart_mask <= 0;
		if (ioctl_addr == 512)
			cart_mask512 <= 0;
	end;
	if (old_download & ~cart_download) begin
		// Headered dumps end at size = N*1024 + 512, so the final byte address
		// has low 10 bits of 10'h1FF.
		cart_sz512 <= (ioctl_addr[9:0] == 10'h1FF);
	end;
end

wire [13:0] ram_a1;
wire        ram_we1;
wire  [7:0] ram_d1;
wire  [7:0] ram_q1;
wire [13:0] ram_a2;
wire        ram_we2;
wire  [7:0] ram_d2;
wire  [7:0] ram_q2;

wire [14:0] nvram_a1;
wire        nvram_we1;
wire  [7:0] nvram_d1;
wire  [7:0] nvram_q1;
wire [14:0] nvram_a2;
wire        nvram_we2;
wire  [7:0] nvram_d2;
wire  [7:0] nvram_q2;

system #(.MAX_SPPL(63), .GAMEGEAR_ONLY(1), .CHEATS_ENABLE(0)) system1
(
	.clk_sys(clk_sys),
	.ce_cpu(ce_cpu),
	.ce_vdp(ce_vdp),
	.ce_pix(ce_pix),
	.ce_sp(ce_sp),
	.turbo(turbo),
	.gg(1'b1),
	.ggres(1'b1),
	.systeme(1'b0),
	.bios_en(1'b0),
	.ext_bios_sel(1'b0),
	.ext_bios_loaded(1'b0),
	.dbr(dbr),

	.RESET_n(~reset_active),

	.GG_RESET(1'b0),
	.GG_EN(1'b1),
	.GG_CODE(129'd0),
	.GG_AVAIL(),
	.gg_link_en(gg_link),
	.gg_link_in(gg_link_in1),
	.gg_link_out(gg_link_out1),

	.rom_rd(ram_rd1),
	.rom_a(ram_addr1),
	.rom_do(ram_dout1),

	.j1_up(joya[3]),
	.j1_down(joya[2]),
	.j1_left(joya[1]),
	.j1_right(joya[0]),
	.j1_tl(joya[4]),
	.j1_tr(joya[5]),
	.j1_th(joya_th),
	.j1_start(1'b0),
	.j1_coin(1'b0),
	.j1_a3(1'b0),

	.j2_up(1'b1),
	.j2_down(1'b1),
	.j2_left(1'b1),
	.j2_right(1'b1),
	.j2_tl(1'b1),
	.j2_tr(1'b1),
	.j2_th(1'b1),
	.pause(joya[6]),
	.soft_reset(soft_reset_btn),
	.j2_start(1'b0),
	.j2_coin(1'b0),
	.j2_a3(1'b0),

	.j1_tr_out(joya_tr_out),
	.j1_th_out(joya_th_out),
	.j2_tr_out(joyb_tr_out),
	.j2_th_out(joyb_th_out),

	.E0Type(2'b00),
	.E1Use(1'b0),
	.E2Use(1'b0),
	.F2(8'd0),
	.F3(8'd0),
	.E0(8'd0),

	.has_pedal(1'b0),
	.has_paddle(1'b0),
	.paddle(8'd0),
	.paddle2(8'd0),
	.pedal(8'd0),
	.sc3000_en(1'b0),
	.sc_multicart_en(1'b0),
	.sc_megacart_en(1'b0),
	.sc_cart_ram(2'b00),
	.sk1100_en(1'b0),
	.sk1100_row_sel(sk1100_row_sel),
	.sk1100_row_data(sk1100_row_data),

	.x(x1),
	.y(y1),
	.color(color1),
	.palettemode(1'b0),
	.mask_column(mask_column1),
	.black_column(1'b0),
	.smode_M1(smode1_M1),
	.smode_M2(smode1_M2),
	.smode_M3(smode1_M3),
	.ysj_quirk(ysj_quirk),
	.pal(pal),
	.region(status[10]),
	.mapper_lock(1'b0),
	.mapper_zemina_force(1'b0),
	.vdp_enables(2'b00),
	.psg_enables(2'b00),

	.fm_ena(1'b0),
	.audioL(audio1_l),
	.audioR(audio1_r),

	.sp64(status[8]),

	.ram_a(ram_a1),
	.ram_we(ram_we1),
	.ram_d(ram_d1),
	.ram_q(ram_q1),

	.nvram_a(nvram_a1),
	.nvram_we(nvram_we1),
	.nvram_d(nvram_d1),
	.nvram_q(nvram_q1),

	.encrypt(2'b00),
	.key_a(),
	.key_d(8'd0),

	.ROMCL(clk_sys),
	.ROMAD(ioctl_addr),
	.ROMDT(ioctl_dout),
	.ROMEN(1'b0),
	.BIOSWEN(1'b0)
);

wire [7:0] joy2_gg = ~joy_1[7:0];
wire       joy2_j1_tr_out;
wire       joy2_j1_th_out;
wire       joy2_j2_tr_out;
wire       joy2_j2_th_out;

system #(.MAX_SPPL(63), .GAMEGEAR_ONLY(1), .CHEATS_ENABLE(0)) system2
(
	.clk_sys(clk_sys),
	.ce_cpu(ce_cpu),
	.ce_vdp(ce_vdp),
	.ce_pix(ce_pix),
	.ce_sp(ce_sp),
	.turbo(turbo),
	.gg(1'b1),
	.ggres(1'b1),
	.systeme(1'b0),
	.bios_en(1'b0),
	.ext_bios_sel(1'b0),
	.ext_bios_loaded(1'b0),
	.dbr(dbr),

	.RESET_n(~reset2_active),

	.GG_RESET(1'b0),
	.GG_EN(1'b1),
	.GG_CODE(129'd0),
	.GG_AVAIL(),
	.gg_link_en(gg_link),
	.gg_link_in(gg_link_in2),
	.gg_link_out(gg_link_out2),

	.rom_rd(ram_rd2),
	.rom_a(ram_addr2),
	.rom_do(ram_dout2),

	.j1_up(joy2_gg[3]),
	.j1_down(joy2_gg[2]),
	.j1_left(joy2_gg[1]),
	.j1_right(joy2_gg[0]),
	.j1_tl(joy2_gg[4]),
	.j1_tr(joy2_gg[5]),
	.j1_th(1'b1),
	.j1_start(1'b0),
	.j1_coin(1'b0),
	.j1_a3(1'b0),

	.j2_up(1'b1),
	.j2_down(1'b1),
	.j2_left(1'b1),
	.j2_right(1'b1),
	.j2_tl(1'b1),
	.j2_tr(1'b1),
	.j2_th(1'b1),
	.pause(joy2_gg[6]),
	.soft_reset(soft_reset_btn),
	.j2_start(1'b0),
	.j2_coin(1'b0),
	.j2_a3(1'b0),

	.j1_tr_out(joy2_j1_tr_out),
	.j1_th_out(joy2_j1_th_out),
	.j2_tr_out(joy2_j2_tr_out),
	.j2_th_out(joy2_j2_th_out),

	.E0Type(2'b00),
	.E1Use(1'b0),
	.E2Use(1'b0),
	.F2(8'd0),
	.F3(8'd0),
	.E0(8'd0),

	.has_pedal(1'b0),
	.has_paddle(1'b0),
	.paddle(8'd0),
	.paddle2(8'd0),
	.pedal(8'd0),
	.sc3000_en(1'b0),
	.sc_multicart_en(1'b0),
	.sc_megacart_en(1'b0),
	.sc_cart_ram(2'b00),
	.sk1100_en(1'b0),
	.sk1100_row_sel(),
	.sk1100_row_data(12'hFFF),

	.x(x2),
	.y(y2),
	.color(color2),
	.palettemode(1'b0),
	.mask_column(mask_column2),
	.black_column(1'b0),
	.smode_M1(smode2_M1),
	.smode_M2(smode2_M2),
	.smode_M3(smode2_M3),
	.ysj_quirk(ysj_quirk),
	.pal(pal),
	.region(status[10]),
	.mapper_lock(1'b0),
	.mapper_zemina_force(1'b0),
	.vdp_enables(2'b00),
	.psg_enables(2'b00),

	.fm_ena(1'b0),
	.audioL(audio2_l),
	.audioR(audio2_r),

	.sp64(status[8]),

	.ram_a(ram_a2),
	.ram_we(ram_we2),
	.ram_d(ram_d2),
	.ram_q(ram_q2),

	.nvram_a(nvram_a2),
	.nvram_we(nvram_we2),
	.nvram_d(nvram_d2),
	.nvram_q(nvram_q2),

	.encrypt(2'b00),
	.key_a(),
	.key_d(8'd0),

	.ROMCL(clk_sys),
	.ROMAD(ioctl_addr),
	.ROMDT(ioctl_dout),
	.ROMEN(1'b0),
	.BIOSWEN(1'b0)
);

assign joy[0] = status[1] ? joy_1[7:0] : joy_0[7:0];
assign joy[1] = status[1] ? joy_0[7:0] : joy_1[7:0];
assign joy[2] = joy_2[7:0];
assign joy[3] = joy_3[7:0];

wire [1:0] userio_mode = 2'd0;
wire       userio_snac = 1'b0;
wire       gg_link = 1'b1;
wire [6:0] gg_link_in1;
wire [6:0] gg_link_out1;
wire [6:0] gg_link_in2;
wire [6:0] gg_link_out2;
wire       raw_serial = 1'b0;
wire swap = status[1];
wire sk1100_en = 1'b0;
wire sc3000_en = 1'b0;
wire [1:0] sc_cart_ram = 2'b00;
wire sg_palette = 1'b0;
wire sc_multicart_en = 1'b0;
wire sc_megacart_en = 1'b0;

wire [7:0] joya;
wire [7:0] joyb;
wire [7:0] joyser;
wire [2:0] sk1100_row_sel;
wire [11:0] sk1100_row_data = 12'hFFF;

wire      joya_tr_out;
wire      joya_th_out;
wire      joyb_tr_out;
wire      joyb_th_out;
wire      joya_th;
wire      joyb_th;
wire      joyser_th;
reg [1:0] jcnt = 0;

wire has_pedal = 1'b0;
wire [7:0] pedal = paddle_en ? paddle_1 : !joy0_y[7] ? 8'h00: {~joy0_y[6:0],~joy0_y[6]};
wire [7:0] paddlein = paddle_en ? paddle_0 : has_pedal ? {~joy0_x[7],joy0_x[6:0]} : {joy0_x[7],joy0_x[7],joy0_x[7],joy0_x[7],joy0_x[7],joy0_x[7:5]};
wire [7:0] paddle2 = paddle_en ? paddle_1 : joy1_x;
wire [7:0] pedallimit = paddlein[7:5]==3'b111 ? 8'hE0 : paddlein[7:5]==3'b000 ? 8'h20 : paddlein;
wire [7:0] paddle = has_pedal ? pedallimit : paddlein;
wire [11:0] sk1100_joy_row = {
	joyb[5], joyb[4], joyb[0], joyb[1], joyb[2], joyb[3],
	joya[5], joya[4], joya[0], joya[1], joya[2], joya[3]
};

// Gear-to-Gear cable crossover. Internally these vectors are PC0..PC6.
// Cable mapping: PC0<->PC2, PC1<->PC3, PC4(TX)<->PC5(RX), PC6 straight.
assign gg_link_in1 = {gg_link_out2[6], gg_link_out2[4], gg_link_out2[5], gg_link_out2[1], gg_link_out2[0], gg_link_out2[3], gg_link_out2[2]};
assign gg_link_in2 = {gg_link_out1[6], gg_link_out1[4], gg_link_out1[5], gg_link_out1[1], gg_link_out1[0], gg_link_out1[3], gg_link_out1[2]};

always @(posedge clk_sys) begin
	reg old_th;
	reg [15:0] tmr;

	if (raw_serial) begin
		joyser[3] <= USER_IN[1];//up
		joyser[2] <= USER_IN[0];//down
		joyser[1] <= USER_IN[5];//left
		joyser[0] <= USER_IN[3];//right
		joyser[4] <= USER_IN[2];//trigger / button1
		joyser[5] <= USER_IN[6];//button2
		joyser_th <= USER_IN[4];//sensor

		if (tmr) tmr <= tmr - 1'd1;
		joyser[6] <= !tmr;
		joyser[7] <= 1'b0;

		joya <= swap ? ~joy[1] : joyser;
		joyb <= swap ? joyser : ~joy[0];
		joya_th <=  swap ? 1'b1 : joyser_th;
		joyb_th <=  swap ? joyser_th : 1'b1;

		USER_OUT <= {swap ? joyb_tr_out : joya_tr_out, 1'b1, swap ? joyb_th_out : joya_th_out, 4'b1111 };

	end else begin
		joya <= ~joy[jcnt];
		joyb <= status[14] ? 8'hFF : ~joy[1];
		joya_th <=  1'b1;
		joyb_th <=  1'b1;

		if(ce_cpu) begin
			if(tmr > 57000) jcnt <= 0;
			else if(joya_th) tmr <= tmr + 1'd1;

			old_th <= joya_th;
			if(old_th & ~joya_th) begin
				tmr <= 0;
			//first clock doesn't count as capacitor has not discharged yet
			if(tmr < 57000) jcnt <= jcnt + 1'd1;
			end
		end

		if(reset_active | ~status[14]) jcnt <= 0;

		USER_OUT <= 7'b1111111;
	end

	if(gun_en) begin
		if(gun_port) begin
			joyb_th <= ~gun_sensor;
			joyb <= {3'b111, ~gun_trigger ,4'b1111};
		end else begin
			joya_th <= ~gun_sensor;
			joya <= {3'b111, ~gun_trigger ,4'b1111};
			joyb <= raw_serial ? joyser : ~joy[0];
			joyb_th <= raw_serial ? joyser_th : 1'b1;
		end
	end

	if (paddle_en) begin
		{joya[0], joya[1], joya[2], joya[3], joya[5]} <= {paddle_0_nib, paddle_0_tr};
		{joyb[0], joyb[1], joyb[2], joyb[3], joyb[5]} <= {paddle_1_nib, paddle_1_tr};
	end
end

spram #(.widthad_a(14)) ram_inst
(
	.clock     (clk_sys),
	.address   (ram_clr_run ? ram_clr_addr : {1'b0,ram_a1[12:0]}),
	.wren      (ram_clr_run | ram_we1),
	.data      (ram_clr_run ? 8'h00 : ram_d1),
	.q         (ram_q1)
);

spram #(.widthad_a(14)) ram2_inst
(
	.clock     (clk_sys),
	.address   (ram_clr_run ? ram_clr_addr : {1'b0,ram_a2[12:0]}),
	.wren      (ram_clr_run | ram_we2),
	.data      (ram_clr_run ? 8'h00 : ram_d2),
	.q         (ram_q2)
);

wire [15:0] audio1_l, audio1_r;
wire [15:0] audio2_l, audio2_r;
wire [1:0]  audio_sel = status[63:62];

assign AUDIO_L = (audio_sel == 2'd0) ? audio1_l :
                 (audio_sel == 2'd1) ? audio2_l :
                 (audio_sel == 2'd2) ? ($signed(audio1_l[15:1]) + $signed(audio2_l[15:1])) :
                                       ($signed(audio1_l[15:1]) + $signed(audio1_r[15:1]));
assign AUDIO_R = (audio_sel == 2'd0) ? audio1_r :
                 (audio_sel == 2'd1) ? audio2_r :
                 (audio_sel == 2'd2) ? ($signed(audio1_r[15:1]) + $signed(audio2_r[15:1])) :
                                       ($signed(audio2_l[15:1]) + $signed(audio2_r[15:1]));

//compressor compressor
//(
//	clk_sys,
//	audio_l[15:4], audio_r[15:4],
//	AUDIO_L,       AUDIO_R
//);

wire [8:0] x1, y1;
wire [8:0] x2, y2;
wire [11:0] color1;
wire [11:0] color2;
wire mask_column1;
wire mask_column2;
wire smode1_M1, smode1_M2, smode1_M3;
wire smode2_M1, smode2_M2, smode2_M3;
wire pal = 1'b0;
wire border = 1'b0;
wire ggres = 1'b1;
wire turbo = status[40];
wire HS1, VS1;
wire HS2, VS2;
wire HBlank1, VBlank1;
wire HBlank2, VBlank2;

video video1
(
	.clk(clk_sys),
	.ce_pix(ce_pix),
	.pal(pal),
	.ggres(ggres),
	.border(border),
	.mask_column(mask_column1),
	.cut_mask(status[29]),
	.smode_M1(smode1_M1),
	.smode_M2(smode1_M2),
	.smode_M3(smode1_M3),
	.smode_M4(1'b1),
	.x(x1),
	.y(y1),
	.hsync(HS1),
	.vsync(VS1),
	.hblank(HBlank1),
	.vblank(VBlank1)
);

video video2
(
	.clk(clk_sys),
	.ce_pix(ce_pix),
	.pal(pal),
	.ggres(ggres),
	.border(border),
	.mask_column(mask_column2),
	.cut_mask(status[29]),
	.smode_M1(smode2_M1),
	.smode_M2(smode2_M2),
	.smode_M3(smode2_M3),
	.smode_M4(1'b1),
	.x(x2),
	.y(y2),
	.hsync(HS2),
	.vsync(VS2),
	.hblank(HBlank2),
	.vblank(VBlank2)
);

reg ce_cpu;
reg ce_snd;
reg ce_vdp;
reg ce_pix;
reg ce_sp;
always @(negedge clk_sys) begin
	reg [4:0] clkd;

	ce_sp <= clkd[0];
	ce_vdp <= 0;//div5
	ce_pix <= 0;//div10
	ce_cpu <= 0;//div15
	clkd <= clkd + 1'd1;
	if (clkd==29) begin
		clkd <= 0;
		ce_vdp <= 1;
		ce_pix <= 1;
	end else if (clkd==24) begin
		ce_cpu <= 1;  //-- changed cpu phase to please VDPTEST HCounter test;
		ce_vdp <= 1;
	end else if (clkd==19) begin
		ce_vdp <= 1;
		ce_pix <= 1;
	end else if (clkd==14) begin
		ce_vdp <= 1;
	end else if (clkd==9) begin
		ce_cpu <= 1;
		ce_vdp <= 1;
		ce_pix <= 1;
	end else if (clkd==4) begin
		ce_vdp <= 1;
	end
end

wire gg2p_ce_pix;
wire gg2p_HSync;
wire gg2p_VSync;
wire gg2p_HBlank;
wire gg2p_VBlank;
wire [3:0] gg2p_r;
wire [3:0] gg2p_g;
wire [3:0] gg2p_b;

wire [2:0] scale = status[5:3];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

assign CLK_VIDEO = clk_sys;
assign VGA_SL = sl[1:0];

gg2p_video gg2p_video
(
	.clk(clk_sys),
	.ce_pix(ce_pix),

	.x1(x1),
	.y1(y1),
	.hblank1(HBlank1),
	.vblank1(VBlank1),
	.smode1_m1(smode1_M1),
	.color1(color1),

	.x2(x2),
	.y2(y2),
	.hblank2(HBlank2),
	.vblank2(VBlank2),
	.smode2_m1(smode2_M1),
	.color2(color2),

	.separator(status[61]),

	.ce_pix_out(gg2p_ce_pix),
	.hsync(gg2p_HSync),
	.vsync(gg2p_VSync),
	.hblank(gg2p_HBlank),
	.vblank(gg2p_VBlank),
	.r(gg2p_r),
	.g(gg2p_g),
	.b(gg2p_b)
);

video_mixer #(.HALF_DEPTH(1), .LINE_LENGTH(320), .GAMMA(1)) video_mixer
(
	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(CE_PIXEL),
	.ce_pix(gg2p_ce_pix),
	.gamma_bus(gamma_bus),
	.HSync(gg2p_HSync),
	.VSync(gg2p_VSync),
	.HBlank(gg2p_HBlank),
	.VBlank(gg2p_VBlank),
	.HDMI_FREEZE(HDMI_FREEZE),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.VGA_DE(vga_de),
	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),
	.freeze_sync(),

	.R(gg2p_r),
	.G(gg2p_g),
	.B(gg2p_b)
);


/////////////////////////  STATE SAVE/LOAD  /////////////////////////////
wire bk_save_write = nvram_we1 | nvram_we2;
reg bk_pending;

always @(posedge clk_sys) begin
	if (bk_ena && ~OSD_STATUS && bk_save_write)
		bk_pending <= 1'b1;
	else if (bk_state)
		bk_pending <= 1'b0;
end

wire [14:0] nvram_sd_addr = {sd_lba[5:0], sd_buff_addr};
wire  [7:0] nvram_sd_q1;
wire  [7:0] nvram_sd_q2;
assign sd_buff_din = nvram_sd_q1;

dpram #(.widthad_a(15)) nvram_inst
(
	.clock_a     (clk_sys),
	.address_a   (nvram_a1),
	.wren_a      (nvram_we1),
	.data_a      (nvram_d1),
	.q_a         (nvram_q1),
	.clock_b     (clk_sys),
	.address_b   (nvram_sd_addr),
	.wren_b      (sd_buff_wr & sd_ack),
	.data_b      (sd_buff_dout),
	.q_b         (nvram_sd_q1)
);

dpram #(.widthad_a(15)) nvram2_inst
(
	.clock_a     (clk_sys),
	.address_a   (nvram_a2),
	.wren_a      (nvram_we2),
	.data_a      (nvram_d2),
	.q_a         (nvram_q2),
	.clock_b     (clk_sys),
	.address_b   (nvram_sd_addr),
	.wren_b      (sd_buff_wr & sd_ack),
	.data_b      (sd_buff_dout),
	.q_b         (nvram_sd_q2)
);

wire downloading = cart_download;
reg old_downloading = 0;
reg bk_ena = 0;
always @(posedge clk_sys) begin

	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly) bk_ena <= 1;
end

wire bk_load    = status[6];
wire bk_save    = status[7] | (bk_pending & OSD_STATUS && status[25]);
reg  bk_loading = 0;
reg  bk_state   = 0;

reg osd_btn = 0;
always @(posedge clk_sys) begin

	reg old_load = 0, old_save = 0, old_ack;
	integer timeout = 0;
	reg     last_rst = 0;

	if (RESET) last_rst = 0;
	if (status[0]) last_rst = 1;

	if (last_rst & ~status[0]) begin
		osd_btn <= 0;
		if(timeout < 24000000) begin
			timeout <= timeout + 1;
			osd_btn <= 1;
		end
	end

	old_load <= bk_load & bk_ena;
	old_save <= bk_save & bk_ena;
	old_ack  <= sd_ack;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if(!bk_state) begin
		if((~old_load & bk_load) | (~old_save & bk_save)) begin
			bk_state <= 1;
			bk_loading <= bk_load;
			sd_lba <= 0;
			sd_rd <=  bk_load;
			sd_wr <= ~bk_load;
		end
		if(old_downloading & ~downloading & |img_size & bk_ena) begin
			bk_state <= 1;
			bk_loading <= 1;
			sd_lba <= 0;
			sd_rd <= 1;
			sd_wr <= 0;
		end 
	end else begin
		if(old_ack & ~sd_ack) begin
			if(&sd_lba[5:0]) begin
				bk_loading <= 0;
				bk_state <= 0;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <=  bk_loading;
				sd_wr  <= ~bk_loading;
			end
		end
	end
end

wire [1:0] gun_mode = 2'b00;
wire       gun_btn_mode = 1'b0;
wire       gun_port = 1'b0;
wire       gun_en = 1'b0;
wire       gun_target;
wire       gun_sensor;
wire       gun_trigger;
wire [1:0] gun_crosshair = 2'b00;

lightgun lightgun
(
	.CLK(clk_sys),
	.RESET(reset_active),

	.MOUSE(ps2_mouse),
	.MOUSE_XY(&gun_mode),

	.JOY_X(gun_mode[0] ? joy0_x : joy1_x),
	.JOY_Y(gun_mode[0] ? joy0_y : joy1_y),
	.JOY(gun_mode[0] ? joy_0[7:0] : joy_1[7:0]),

	.HDE(~HBlank1),
	.VDE(~VBlank1),
	.CE_PIX(ce_pix),

	.BTN_MODE(gun_btn_mode),
	.SIZE(gun_crosshair),
	.SENSOR_DELAY(34),

	.TARGET(gun_target),
	.SENSOR(gun_sensor),
	.TRIGGER(gun_trigger)
);

// Paddle support
wire       jp_region    = status[10];
wire       paddle_en    = 1'b0;
wire       paddle_joy   = 1'b0;

reg  [3:0] paddle_0_nib,   paddle_1_nib;
reg  [3:0] paddle_0_nib_q, paddle_1_nib_q;
reg        paddle_0_tr,    paddle_1_tr;

reg        joya_th_out_q,  joyb_th_out_q;
wire       joya_th_rise,   joyb_th_rise;
wire       joya_th_fall,   joyb_th_fall;

always_ff @(posedge clk_sys) begin
	if (jp_region) begin
		// Japanese paddle (HPD-200)
		if (en16khz) begin
			if (paddle_0_tr) begin
				if (paddle_joy) begin
					{paddle_0_nib_q, paddle_0_nib} <= {~joy0_x[7], joy0_x[6:0]};
					{paddle_1_nib_q, paddle_1_nib} <= {~joy1_x[7], joy1_x[6:0]};
				end else begin
					{paddle_0_nib_q, paddle_0_nib} <= paddle_0;
					{paddle_1_nib_q, paddle_1_nib} <= paddle_1;
				end
				paddle_0_tr  <= 1'b0;
				paddle_1_tr  <= 1'b0;
			end else begin
				paddle_0_nib <= paddle_0_nib_q;
				paddle_1_nib <= paddle_1_nib_q;
				paddle_0_tr  <= 1'b1;
				paddle_1_tr  <= 1'b1;
			end
		end
	end else begin
		// Export paddle (Non-existent but implemented in some games?)
		joya_th_out_q <= joya_th_out;
		joyb_th_out_q <= joyb_th_out;

		if (joya_th_fall) begin
			if (paddle_joy) begin
				{paddle_0_nib_q, paddle_0_nib} <= {~joy0_x[7], joy0_x[6:0]};
			end else begin
				{paddle_0_nib_q, paddle_0_nib} <= paddle_0;
			end
			paddle_0_tr  <= 1'b0;
		end else if (joya_th_rise) begin
			paddle_0_nib <= paddle_0_nib_q;
			paddle_0_tr  <= 1'b0;
		end

		if (joyb_th_fall) begin
			if (paddle_joy) begin
				{paddle_1_nib_q, paddle_1_nib} <= {~joy1_x[7], joy1_x[6:0]};
			end else begin
				{paddle_1_nib_q, paddle_1_nib} <= paddle_1;
			end
			paddle_1_tr  <= 1'b0;
		end else if (joyb_th_rise) begin
			paddle_1_nib <= paddle_1_nib_q;
			paddle_1_tr  <= 1'b0;
		end
	end
end

assign joya_th_rise = ~joya_th_out_q &  joya_th_out;
assign joyb_th_rise = ~joyb_th_out_q &  joyb_th_out;
assign joya_th_fall =  joya_th_out_q & ~joya_th_out;
assign joyb_th_fall =  joyb_th_out_q & ~joyb_th_out;

wire       en16khz;
reg [11:0] cnt_en16khz;

always_ff @(posedge clk_sys) begin
	cnt_en16khz <= cnt_en16khz + 1'd1;
	if (cnt_en16khz == 3355) cnt_en16khz <= 0;
end
assign en16khz = cnt_en16khz == 0;

reg dbg_menu = 0;
always @(posedge clk_sys) begin
	reg old_stb;
	reg enter = 0;
	reg esc = 0;

	old_stb <= ps2_key[10];
	if(old_stb ^ ps2_key[10]) begin
		if(ps2_key[7:0] == 'h5A) enter <= ps2_key[9];
		if(ps2_key[7:0] == 'h76) esc   <= ps2_key[9];
	end

	if(enter & esc) begin
		dbg_menu <= ~dbg_menu;
		enter <= 0;
		esc <= 0;
	end
end

endmodule
