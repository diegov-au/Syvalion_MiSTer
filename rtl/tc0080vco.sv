module tc0080vco #(
	parameter [24:0] GFX_BASE = 25'h090000,
	parameter int    V_ACTIVE = 400,
	parameter int    V_TOTAL  = 448,
	parameter int    Y_OFFSET = 48,
	parameter int    FLIP_BIT_X = 6,
	parameter int    FLIP_BIT_Y = 7
) (
	input             clk,
	input             reset,

	input             ce_pix,
	input       [9:0] hcnt,
	input       [9:0] vcnt,

	output reg [16:0] ram_addr,
	input      [15:0] ram_q,

	output reg  [9:0] pal_idx,

	output     [24:0] sd_addr,
	output            sd_req,
	output            sd_burst,
	input             sd_ack,
	input      [15:0] sd_dout,

	output reg [15:0] dbg_line_ticks,
	output reg        dbg_line_over,
	output reg [15:0] dbg_zoom_odd,
	output reg        dbg_flipscreen,
	output reg        dbg_rowscroll_nz,
	output reg        dbg_tile_hi,
	output reg [15:0] dbg_flip40,
	output reg [15:0] dbg_flip80,
	output reg [15:0] dbg_zoom0,
	output reg [15:0] dbg_zoom1,
	output reg [15:0] dbg_spr_zoomed
);

localparam [16:0] A_BG0_TILE = 17'h06000;
localparam [16:0] A_BG1_TILE = 17'h07000;
localparam [16:0] A_BG0_ATTR = 17'h0E000;
localparam [16:0] A_BG1_ATTR = 17'h0F000;
localparam [16:0] A_ROWSCROLL= 17'h10000;
localparam [16:0] A_CTRL     = 17'h10400;
localparam [16:0] A_FG0_MAP  = 17'h00800;
localparam [16:0] A_FG0_GFX0 = 17'h00000;
localparam [16:0] A_FG0_GFX1 = 17'h08000;
localparam [16:0] A_SPRRAM   = 17'h10200;
localparam [16:0] A_CHAIN0   = 17'h00000;
localparam [16:0] A_CHAIN1   = 17'h08000;

localparam int SPR_FLIP_BIT_X = 6;
localparam int SPR_FLIP_BIT_Y = 7;

(* ramstyle = "no_rw_check, MLAB" *)
reg [9:0] lb [0:15][0:63] /* verilator public_flat_rw */;

reg [4:0] lb_rpos;
reg [3:0] lb_rlane;
reg       lb_rbuf;
always @(posedge clk) begin
	if (ce_pix) begin
		lb_rpos  <= hcnt[8:4];
		lb_rlane <= hcnt[3:0];
		lb_rbuf  <= vcnt[0];
	end
end
always @(posedge clk) pal_idx <= lb[lb_rlane][{lb_rbuf, lb_rpos}];

reg [9:0] vcnt_q;
always @(posedge clk) vcnt_q <= vcnt;
wire line_start = (vcnt != vcnt_q);

wire [9:0] next_line = (vcnt == V_TOTAL[9:0] - 10'd1) ? 10'd0 : (vcnt + 10'd1);
wire       want_render = (next_line < V_ACTIVE[9:0]);

reg [9:0] cur_line;
reg       wbuf;

wire [9:0] bitmap_y = cur_line + Y_OFFSET[9:0];

reg         gfx_req;
reg  [13:0] gfx_tile;
reg   [3:0] gfx_row;
reg         gfx_fx, gfx_fy;
wire        gfx_done;
wire [63:0] gfx_pixels;

gfx_fetch #(.GFX_BASE(GFX_BASE)) fetch (
	.clk      (clk),
	.reset    (reset),
	.req      (gfx_req),
	.tile     (gfx_tile),
	.row      (gfx_row),
	.flipx    (gfx_fx),
	.flipy    (gfx_fy),
	.busy     (),
	.done     (gfx_done),
	.pixels   (gfx_pixels),
	.sd_addr  (sd_addr),
	.sd_req   (sd_req),
	.sd_burst (sd_burst),
	.sd_ack   (sd_ack),
	.sd_dout  (sd_dout)
);

localparam S_IDLE  = 5'd0,
           S_CTRL  = 5'd1,
           S_ROWS  = 5'd2,
           S_LAYER = 5'd3,
           S_T0    = 5'd4,
           S_T1    = 5'd5,
           S_T2    = 5'd6,
           S_T3    = 5'd7,
           S_T4    = 5'd8,
           S_WAIT  = 5'd9,
           S_WRITE = 5'd10,
           S_FG0   = 5'd11,
           S_F0    = 5'd12,
           S_F1    = 5'd13,
           S_F2    = 5'd14,
           S_F3    = 5'd15,
           S_F4    = 5'd16,
           S_F5    = 5'd17,
           S_FWR   = 5'd18,
           S_SCAN  = 5'd19,
           S_SPRRD = 5'd20,
           S_SPREV = 5'd21,
           S_SC0   = 5'd22,
           S_SC1   = 5'd23,
           S_SC2   = 5'd24,
           S_SC3   = 5'd25,
           S_SC4   = 5'd26,
           S_SCW   = 5'd27,
           S_ROWCHK= 5'd28,
           S_SCEM  = 5'd29,
           S_ROWACT= 5'd30;

reg  [4:0] state;
reg  [3:0] cnt;
reg [15:0] ctrl [0:7];
reg [15:0] rowscroll;

reg        layer;
reg  [5:0] tnum;
reg  [5:0] tcol;
reg  [5:0] trow;
reg  [3:0] prow;

reg signed [10:0] wx;
reg  [4:0] wcolour;

reg [15:0] tick;

wire  [9:0] bg0_scrollx = ctrl[1][9:0];
wire  [9:0] bg1_scrollx = ctrl[2][9:0];
wire  [9:0] bg0_scrolly = ctrl[3][9:0];
wire  [9:0] bg1_scrolly = ctrl[4][9:0];

function automatic [17:0] zy_step_of;
	input [7:0] zy;
	reg [8:0] t;
	reg [8:0] dy;
	reg [4:0] ey;
	begin
		if (zy < 8'd127) begin
			t  = {1'b0, zy} + 9'd2;
			dy = 9'd16 - {5'd0, t[7:4]};
			ey = {1'b0, t[3:0]};
			zy_step_of = ({dy, 4'd0} - {13'd0, ey}) << 9;
		end
		else
			zy_step_of = 18'h10000 - (({10'd0, zy} - 18'h7f) << 9);
	end
endfunction

wire  [7:0] bg0_zy = ctrl[6][7:0];
wire  [7:0] bg1_zy = ctrl[7][7:0];
wire  [7:0] bg0_zx = ctrl[6][15:8];
wire  [7:0] bg1_zx = ctrl[7][15:8];

reg  [9:0] src_y0_r, src_y1_r;
wire [28:0] y_index0 = {bg0_scrolly - 10'd1, 16'd0}
                     + {9'd0, bitmap_y} * {11'd0, zy_step_of(bg0_zy)};
wire [28:0] y_index1 = {bg1_scrolly - 10'd1, 16'd0}
                     + {9'd0, bitmap_y} * {11'd0, zy_step_of(bg1_zy)};
always @(posedge clk) begin
	src_y0_r <= y_index0[25:16];
	src_y1_r <= y_index1[25:16];
end

wire  [9:0] src_y = layer ? src_y1_r : src_y0_r;
wire        bg_zoomed = layer ? (bg1_zy != 8'h7f) : (bg0_zy != 8'h7f);

wire  [8:0] rowscroll_index = bg_zoomed ? src_y[8:0] : {1'b0, src_y[9:1]};
wire  [9:0] src_x = layer ? (10'd0 - 10'd1 - bg1_scrollx)
                          : (10'd0 - 10'd1 - bg0_scrollx - rowscroll[9:0]);

wire [16:0] tile_addr = (layer ? A_BG1_TILE : A_BG0_TILE) + {5'd0, trow, tcol};
wire [16:0] attr_addr = (layer ? A_BG1_ATTR : A_BG0_ATTR) + {5'd0, trow, tcol};

reg  [7:0] fg_tile;
reg [15:0] fg_w0;
reg  [5:0] fcol;

localparam int SPRW = 47;
reg [SPRW-1:0] spr_cache [0:127] /* verilator public_flat_rw */;
reg [SPRW-1:0] spr_q;

reg  [9:0] scnt;
reg [15:0] sw0, sw1, sw2;
reg  [7:0] sidx;
reg  [1:0] scell;
reg  [1:0] sj;
reg        row_hit_q;
reg  [1:0] schunk;
reg [15:0] scell_off;
reg signed [10:0] sx0;
reg  [5:0] srow;

reg  [5:0] z_size_l;
reg  [5:0] z_space_l;
reg [16:0] z_step_l;
reg        spr_fx, spr_fy;

reg [16:0] step_rom [0:63];
initial begin
	for (int q = 0; q < 64; q++) step_rom[q] = 17'd65536;
	step_rom[6'd9]  = 17'd116508;  step_rom[6'd10] = 17'd104857;
	step_rom[6'd11] = 17'd95325;   step_rom[6'd12] = 17'd87381;
	step_rom[6'd13] = 17'd80659;   step_rom[6'd14] = 17'd74898;
	step_rom[6'd15] = 17'd69905;   step_rom[6'd16] = 17'd65536;
	step_rom[6'd17] = 17'd61680;   step_rom[6'd18] = 17'd58254;
	step_rom[6'd19] = 17'd55188;   step_rom[6'd20] = 17'd52428;
	step_rom[6'd21] = 17'd49932;   step_rom[6'd22] = 17'd47662;
	step_rom[6'd23] = 17'd45590;   step_rom[6'd24] = 17'd43690;
	step_rom[6'd25] = 17'd41943;   step_rom[6'd26] = 17'd40329;
	step_rom[6'd27] = 17'd38836;   step_rom[6'd28] = 17'd37449;
	step_rom[6'd29] = 17'd36157;   step_rom[6'd30] = 17'd34952;
	step_rom[6'd31] = 17'd33825;   step_rom[6'd32] = 17'd32768;
	step_rom[6'd33] = 17'd31775;   step_rom[6'd34] = 17'd30840;
end

wire [10:0] spr_y0    = spr_q[10:0];
wire [10:0] spr_x0    = spr_q[21:11];
wire  [2:0] spr_ysize = spr_q[24:22];
wire [14:0] spr_toffs = spr_q[39:25];
wire  [6:0] spr_zoom  = spr_q[46:40];

wire  [7:0] zt_lo   = {1'b0, spr_zoom} + 8'd2;
wire  [7:0] zt_hi   = {1'b0, spr_zoom} - 8'd63;
wire        z_small = (spr_zoom < 7'd63);
wire  [5:0] z_space = z_small ? (6'd8 + zt_lo[7:3]) : (6'd16 + zt_hi[7:2]);
wire  [6:0] z_mant  = z_small ? ({z_space, 1'b0} + {4'd0, zt_lo[2:0]})
                             :  ({1'b0, z_space} + {5'd0, zt_hi[1:0]});
wire [17:0] z_scale = z_small ? ({11'd0, z_mant} << 11)
                              : ({11'd0, z_mant} << 12);
wire  [5:0] z_size  = (z_scale + 18'd2048) >> 12;

wire  [7:0] j_off = {6'd0, sj} * z_space_l;
wire signed [12:0] row_rel =
	$signed({3'b000, bitmap_y}) - $signed({{2{spr_y0[10]}}, spr_y0})
	                            - $signed({5'd0, j_off});
wire row_hit = (spr_toffs != 15'd0) && (row_rel >= 0) &&
               (row_rel < $signed({7'd0, z_size_l}));

wire  [5:0] srow_eff = spr_fy ? (z_size_l - 6'd1 - srow) : srow;
wire [22:0] srow_prod = srow_eff * z_step_l;

wire  [7:0] cell_dx    = {6'd0, scell} * z_space_l;
wire  [6:0] chunk_c0   = {schunk, 4'd0};
wire  [6:0] chunk_rem  = {1'b0, z_size_l} - chunk_c0;
wire        last_chunk = (chunk_rem <= 7'd16);
wire  [4:0] chunk_n    = last_chunk ? chunk_rem[4:0] : 5'd16;

wire [5:0] frow  = cur_line[8:3];
wire [2:0] fsub  = cur_line[2:0];

wire [16:0] fmap_addr = A_FG0_MAP + {6'd0, frow, fcol[5:1]};
wire  [7:0] fmap_tile = fcol[0] ? ram_q[7:0] : ram_q[15:8];

integer i;

always @(posedge clk) begin
	gfx_req <= 1'b0;
	wr_go   <= 1'b0;

	wr_c0   <= 6'd0;
	wr_dsz  <= 6'd16;
	wr_step <= 17'd65536;
	wr_fx   <= 1'b0;

	if (reset) begin
		state            <= S_IDLE;
		dbg_line_ticks   <= 16'd0;
		dbg_line_over    <= 1'b0;
		dbg_zoom_odd     <= 16'd0;
		dbg_flipscreen   <= 1'b0;
		dbg_rowscroll_nz <= 1'b0;
		dbg_tile_hi      <= 1'b0;
		dbg_flip40       <= 16'd0;
		dbg_flip80       <= 16'd0;
		dbg_zoom0        <= 16'd0;
		dbg_zoom1        <= 16'd0;
		dbg_spr_zoomed   <= 16'd0;
		cur_line         <= 10'd0;
		wbuf             <= 1'b0;
		tick             <= 16'd0;
		for (i = 0; i < 8; i = i + 1) ctrl[i] <= 16'd0;
	end
	else begin
		if (state != S_IDLE) tick <= tick + 16'd1;

		if (line_start) begin
			if (state != S_IDLE) dbg_line_over <= 1'b1;
			if (tick > dbg_line_ticks) dbg_line_ticks <= tick;
			tick <= 16'd0;

			if (want_render) begin
				cur_line <= next_line;
				wbuf     <= next_line[0];
				cnt      <= 4'd0;
				layer    <= 1'b0;
				state    <= S_CTRL;
			end
			else if (vcnt == V_TOTAL[9:0] - 10'd2) begin
				scnt  <= 10'd0;
				state <= S_SCAN;
			end
			else state <= S_IDLE;
		end
		else case (state)

		S_IDLE: ;

		S_CTRL: begin
			if (cnt <= 4'd7)                  ram_addr <= A_CTRL + {13'd0, cnt};
			if (cnt >= 4'd2 && cnt <= 4'd9)   ctrl[cnt - 4'd2] <= ram_q;
			if (cnt == 4'd10) begin
				ram_addr <= A_ROWSCROLL + {8'd0, rowscroll_index};
				cnt      <= 4'd0;
				state    <= S_ROWS;
			end
			else cnt <= cnt + 4'd1;
		end

		S_ROWS: begin
			if (cnt == 4'd1) begin
				rowscroll <= ram_q;
				if (ram_q != 16'd0) dbg_rowscroll_nz <= 1'b1;
				if (ctrl[0][9:8] == 2'b11) begin
					if (ctrl[0][11:10] != 2'b00) dbg_flipscreen <= 1'b1;
					if (ctrl[6][15:8] != 8'h3F || ctrl[7][15:8] != 8'h3F)
						dbg_zoom_odd <= dbg_zoom_odd + 16'd1;
				end
				dbg_zoom0 <= ctrl[6];
				dbg_zoom1 <= ctrl[7];
				state <= S_LAYER;
			end
			else cnt <= cnt + 4'd1;
		end

		S_LAYER: begin
			trow  <= src_y[9:4];
			prow  <= src_y[3:0];
			tcol  <= src_x[9:4];
			wx    <= 11'sd0 - $signed({7'd0, src_x[3:0]});
			tnum  <= 6'd0;
			state <= S_T0;
		end

		S_T0: begin ram_addr <= tile_addr; state <= S_T1; end
		S_T1: begin ram_addr <= attr_addr; state <= S_T2; end

		S_T2: begin
			gfx_tile <= ram_q[13:0];
			if (ram_q[14]) dbg_tile_hi <= 1'b1;
			state <= S_T3;
		end

		S_T3: begin
			wcolour <= ram_q[4:0];
			gfx_fy  <= ram_q[FLIP_BIT_Y];
			gfx_fx  <= ram_q[FLIP_BIT_X];
			gfx_row <= prow;
			if (ram_q[6]) dbg_flip40 <= dbg_flip40 + 16'd1;
			if (ram_q[7]) dbg_flip80 <= dbg_flip80 + 16'd1;
			state   <= S_T4;
		end

		S_T4: begin gfx_req <= 1'b1; state <= S_WAIT; end

		S_WAIT:
			if (gfx_done) begin
				wr_go     <= 1'b1;
				wr_x0     <= wx;
				wr_n      <= 5'd16;
				wr_pix    <= gfx_pixels;
				wr_colour <= wcolour;
				wr_fg     <= 1'b0;
				wr_opaque <= ~layer;
				state     <= S_WRITE;
			end

		S_WRITE: begin
			wx   <= wx + 11'sd16;
			tcol <= tcol + 6'd1;
			if (tnum == 6'd32) begin
				if (layer == 1'b0) begin
					layer <= 1'b1;
					state <= S_LAYER;
				end
				else begin
					sidx  <= 8'd127;
					state <= S_SPRRD;
				end
			end
			else begin
				tnum  <= tnum + 6'd1;
				state <= S_T0;
			end
		end

		S_SCAN: begin
			if (scnt < 10'd512) ram_addr <= A_SPRRAM + {7'd0, scnt};
			if (scnt >= 10'd2) begin
				case (scnt[1:0])
				2'd2: sw0 <= ram_q;
				2'd3: sw1 <= ram_q;
				2'd0: sw2 <= ram_q;
				default: begin
					spr_cache[(scnt - 10'd3) >> 2] <= {
						sw2[14:8],
						{ram_q[12:0], 2'b00},
						(sw0[11:10] == 2'b00) ? 3'd1 :
						(sw0[11:10] == 2'b01) ? 3'd2 : 3'd4,
						(sw1[9] ? {2'b11, sw1[8:0]} : {2'b00, sw1[8:0]})
						    + 11'sd1,
						(sw0[9] ? {2'b11, sw0[8:0]} : {2'b00, sw0[8:0]})
						    + 11'sd2
					};
				end
				endcase
			end
			if (scnt == 10'd514) state <= S_IDLE;
			else scnt <= scnt + 10'd1;
		end

		S_SPRRD: begin spr_q <= spr_cache[sidx[6:0]]; state <= S_SPREV; end

		S_SPREV: begin
			z_space_l <= z_space;
			z_size_l  <= z_size;
			z_step_l  <= step_rom[z_size];
			sj        <= 2'd0;
			if (spr_toffs == 15'd0) begin
				if (sidx == 8'd0) state <= S_FG0;
				else begin sidx <= sidx - 8'd1; state <= S_SPRRD; end
			end
			else state <= S_ROWCHK;
		end

		S_ROWCHK: begin
			row_hit_q <= row_hit;
			srow      <= row_rel[5:0];
			scell_off <= {1'b0, spr_toffs} + {12'd0, sj, 2'b00};
			sx0       <= $signed(spr_x0);
			state     <= S_ROWACT;
		end

		S_ROWACT:
			if (row_hit_q) begin
				scell <= 2'd0;
				if (spr_zoom != 7'h3f) dbg_spr_zoomed <= dbg_spr_zoomed + 16'd1;
				state <= S_SC0;
			end
			else if ({1'b0, sj} + 3'd1 < spr_ysize) begin
				sj    <= sj + 2'd1;
				state <= S_ROWCHK;
			end
			else if (sidx == 8'd0) state <= S_FG0;
			else begin sidx <= sidx - 8'd1; state <= S_SPRRD; end

		S_SC0:
			if (scell_off < 16'h1000) begin
				if (scell == 2'd3) begin
					if ({1'b0, sj} + 3'd1 < spr_ysize) begin
						sj    <= sj + 2'd1;
						state <= S_ROWCHK;
					end
					else if (sidx == 8'd0) state <= S_FG0;
					else begin sidx <= sidx - 8'd1; state <= S_SPRRD; end
				end
				else begin
					scell     <= scell + 2'd1;
					scell_off <= scell_off + 16'd1;
				end
			end
			else begin
				ram_addr <= A_CHAIN0 + {1'b0, scell_off};
				state    <= S_SC1;
			end

		S_SC1: begin ram_addr <= A_CHAIN1 + {1'b0, scell_off}; state <= S_SC2; end

		S_SC2: begin
			gfx_tile <= ram_q[13:0];
			if (ram_q[14]) dbg_tile_hi <= 1'b1;
			state <= S_SC3;
		end

		S_SC3: begin
			wcolour <= ram_q[4:0];
			spr_fx  <= ram_q[SPR_FLIP_BIT_X];
			spr_fy  <= ram_q[SPR_FLIP_BIT_Y];
			gfx_fx  <= 1'b0;
			gfx_fy  <= 1'b0;
			state   <= S_SC4;
		end

		S_SC4: begin
			gfx_row <= srow_prod[19:16];
			gfx_req <= 1'b1;
			state   <= S_SCW;
		end

		S_SCW:
			if (gfx_done) begin
				wr_pix    <= gfx_pixels;
				wr_colour <= wcolour;
				wr_fg     <= 1'b0;
				wr_opaque <= 1'b0;
				schunk    <= 2'd0;
				state     <= S_SCEM;
			end

		S_SCEM: begin
			wr_go   <= 1'b1;
			wr_x0   <= sx0 + $signed({3'd0, cell_dx}) + $signed({4'd0, chunk_c0});
			wr_n    <= chunk_n;
			wr_c0   <= chunk_c0[5:0];
			wr_step <= z_step_l;
			wr_dsz  <= z_size_l;
			wr_fx   <= spr_fx;
			if (!last_chunk) schunk <= schunk + 2'd1;
			else if (scell == 2'd3) begin
				if ({1'b0, sj} + 3'd1 < spr_ysize) begin
					sj    <= sj + 2'd1;
					state <= S_ROWCHK;
				end
				else if (sidx == 8'd0) state <= S_FG0;
				else begin sidx <= sidx - 8'd1; state <= S_SPRRD; end
			end
			else begin
				scell     <= scell + 2'd1;
				scell_off <= scell_off + 16'd1;
				state     <= S_SC0;
			end
		end

		S_FG0: begin fcol <= 6'd0; state <= S_F0; end

		S_F0: begin ram_addr <= fmap_addr; state <= S_F1; end
		S_F1: state <= S_F2;

		S_F2: begin
			fg_tile  <= fmap_tile;
			ram_addr <= A_FG0_GFX0 + {6'd0, fmap_tile, fsub};
			state    <= S_F3;
		end
		S_F3: begin
			ram_addr <= A_FG0_GFX1 + {6'd0, fg_tile, fsub};
			state    <= S_F4;
		end
		S_F4: begin fg_w0 <= ram_q; state <= S_F5; end

		S_F5: begin
			wr_go     <= 1'b1;
			wr_x0     <= $signed({5'd0, fcol, 3'd0});
			wr_n      <= 5'd8;
			wr_fg     <= 1'b1;
			wr_opaque <= 1'b0;
			wr_colour <= 5'd0;
			for (i = 0; i < 8; i = i + 1)
				wr_pix[i*4 +: 4] <= {1'b0,
				                     ram_q[7 - i[2:0]],
				                     fg_w0[15 - i[2:0]],
				                     fg_w0[7 - i[2:0]]};
			state <= S_FWR;
		end

		S_FWR:
			if (fcol == 6'd63) state <= S_IDLE;
			else begin
				fcol  <= fcol + 6'd1;
				state <= S_F0;
			end

		default: state <= S_IDLE;
		endcase
	end
end

reg               wr_go;
reg signed [10:0] wr_x0;
reg         [4:0] wr_n;
reg        [63:0] wr_pix;
reg         [4:0] wr_colour;
reg               wr_fg;
reg               wr_opaque;

reg         [5:0] wr_c0;
reg         [5:0] wr_dsz;
reg        [16:0] wr_step;
reg               wr_fx;

reg [63:0] pix_q;
reg  [4:0] colour_q;
reg        fg_q, opaque_q, wbuf_q;
always @(posedge clk) begin
	pix_q    <= wr_pix;
	colour_q <= wr_colour;
	fg_q     <= wr_fg;
	opaque_q <= wr_opaque;
	wbuf_q   <= wbuf;
end

genvar L;
generate
	for (L = 0; L < 16; L = L + 1) begin : lane
		wire  [3:0] idx = L[3:0] - wr_x0[3:0];
		wire signed [10:0] lx = wr_x0 + $signed({7'd0, idx});

		wire  [5:0] c    = wr_c0 + {2'd0, idx};
		wire  [5:0] ceff = wr_fx ? (wr_dsz - 6'd1 - c) : c;
		wire [22:0] prod = ceff * wr_step;
		wire in_run = ({1'b0, idx} < wr_n);
		wire on_scr = (lx >= 0) && (lx < 11'sd512);

		reg  [3:0] col_q;
		reg signed [10:0] lx_q;
		reg        live_q;
		always @(posedge clk) begin
			col_q  <= prod[19:16];
			lx_q   <= lx;
			live_q <= wr_go && in_run && on_scr;
		end

		wire [3:0] pen4 = pix_q[{col_q, 2'b00} +: 4];
		wire opaque = opaque_q || (fg_q ? (pen4[2:0] != 3'd0) : (pen4 != 4'd0));
		wire [9:0] data = fg_q ? {1'b1, 6'd0, pen4[2:0]}
		                       : {1'b0, colour_q, pen4};

		always @(posedge clk)
			if (live_q && opaque) lb[L][{wbuf_q, lx_q[8:4]}] <= data;
	end
endgenerate

endmodule
