module gg2p_video
(
	input             clk,
	input             ce_pix,

	input      [8:0]  x1,
	input      [8:0]  y1,
	input             hblank1,
	input             vblank1,
	input             smode1_m1,
	input      [11:0] color1,

	input      [8:0]  x2,
	input      [8:0]  y2,
	input             hblank2,
	input             vblank2,
	input             smode2_m1,
	input      [11:0] color2,

	input             separator,

	output reg        ce_pix_out,
	output reg        hsync,
	output reg        vsync,
	output reg        hblank,
	output reg        vblank,
	output reg [3:0]  r,
	output reg [3:0]  g,
	output reg [3:0]  b
);

localparam [8:0] GG_W9    = 9'd160;
localparam [8:0] GG_H9    = 9'd144;
localparam [8:0] OUT_W9   = 9'd320;
localparam [8:0] V_TOTAL9 = 9'd262;

reg [11:0] linebuf1_0[0:159];
reg [11:0] linebuf1_1[0:159];
reg [11:0] linebuf2_0[0:159];
reg [11:0] linebuf2_1[0:159];

wire [8:0] y1_base = smode1_m1 ? 9'd40 : 9'd24;
wire [8:0] y2_base = smode2_m1 ? 9'd40 : 9'd24;

wire       cap1 = ce_pix && !hblank1 && !vblank1 && x1 > 9'd48 && x1 <= 9'd208 &&
                  y1 >= y1_base && y1 < (y1_base + GG_H9);
wire       cap2 = ce_pix && !hblank2 && !vblank2 && x2 > 9'd48 && x2 <= 9'd208 &&
                  y2 >= y2_base && y2 < (y2_base + GG_H9);

wire [7:0] cap1_x = x1[7:0] - 8'd49;
wire [7:0] cap2_x = x2[7:0] - 8'd49;
wire [7:0] cap1_y = y1[7:0] - y1_base[7:0];
wire [7:0] cap2_y = y2[7:0] - y2_base[7:0];

reg [8:0] h_cnt = 0;
reg [8:0] v_cnt = 0;

wire       src_out_vactive = y1 > y1_base && y1 <= (y1_base + GG_H9);
wire [7:0] out_line = y1[7:0] - y1_base[7:0] - 8'd1;
wire       out_read_bank = out_line[0];
wire       out_active = h_cnt < OUT_W9 && src_out_vactive;
wire       out_right  = h_cnt >= GG_W9;
wire       out_sep    = separator && (h_cnt == 9'd159 || h_cnt == GG_W9);
wire [7:0] out_x      = out_right ? (h_cnt[7:0] - 8'd160) : h_cnt[7:0];
wire [7:0] rd_x       = (h_cnt < OUT_W9) ? out_x : 8'd0;

wire hsync_raw  = h_cnt >= 9'd326 && h_cnt < 9'd336;
wire vsync_raw  = v_cnt >= 9'd244 && v_cnt < 9'd247;
wire hblank_raw = h_cnt >= OUT_W9;
wire vblank_raw = !src_out_vactive;

reg [11:0] rd;
reg        active_q;
reg        sep_q;
reg        hsync_q;
reg        vsync_q;
reg        hblank_q;
reg        vblank_q;

always @(posedge clk) begin
	ce_pix_out <= ce_pix;

	if (cap1) begin
		if (cap1_y[0]) linebuf1_1[cap1_x] <= color1;
		else           linebuf1_0[cap1_x] <= color1;
	end

	if (cap2) begin
		if (cap2_y[0]) linebuf2_1[cap2_x] <= color2;
		else           linebuf2_0[cap2_x] <= color2;
	end

	if (ce_pix) begin
		if (out_right) begin
			rd <= out_read_bank ? linebuf2_1[rd_x] : linebuf2_0[rd_x];
		end else begin
			rd <= out_read_bank ? linebuf1_1[rd_x] : linebuf1_0[rd_x];
		end

		active_q <= out_active;
		sep_q    <= out_sep;
		hsync_q  <= hsync_raw;
		vsync_q  <= vsync_raw;
		hblank_q <= hblank_raw;
		vblank_q <= vblank_raw;

		hsync  <= hsync_q;
		vsync  <= vsync_q;
		hblank <= hblank_q;
		vblank <= vblank_q;

		if (!active_q || sep_q) begin
			{r, g, b} <= 12'h000;
		end else begin
			{b, g, r} <= rd;
		end

		if (x1 == 9'd511) begin
			h_cnt <= 0;
			if (y1 == 9'd511) v_cnt <= 0;
			else if (v_cnt == V_TOTAL9 - 1'd1) v_cnt <= 0;
			else v_cnt <= v_cnt + 1'd1;
		end else begin
			h_cnt <= h_cnt + 1'd1;
		end
	end
end

endmodule
