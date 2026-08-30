module syvalion (
	input             clk_sys,
	input             clk_snd,
	input             reset_sys,
	input             reset,

	input             fast_clk,

	input             test_pattern,

	input             ioctl_download,
	input             ioctl_wr,
	input      [24:0] ioctl_addr,
	input       [7:0] ioctl_dout,
	input      [15:0] ioctl_index,
	output            ioctl_wait,

	input       [7:0] dsw_a,
	input       [7:0] dsw_b,
	input       [7:0] in0,
	input       [7:0] in1,
	input       [7:0] in2,
	input signed [7:0] tb1_x,
	input signed [7:0] tb1_y,
	input signed [7:0] tb2_x,
	input signed [7:0] tb2_y,
	output      [3:0] tb_taken,

	output     [12:0] SDRAM_A,
	output      [1:0] SDRAM_BA,
	input      [15:0] SDRAM_DQ_IN,
	output     [15:0] SDRAM_DQ_OUT,
	output            SDRAM_DQ_OE,
	output            SDRAM_DQML,
	output            SDRAM_DQMH,
	output            SDRAM_nCS,
	output            SDRAM_nRAS,
	output            SDRAM_nCAS,
	output            SDRAM_nWE,
	output            SDRAM_CKE,
	output            SDRAM_CLK,

	output            ce_pix,
	output            hsync,
	output            vsync,
	output            hblank,
	output            vblank,
	output      [7:0] red,
	output      [7:0] green,
	output      [7:0] blue,

	output signed [15:0] audio_l,
	output signed [15:0] audio_r,

	output     [31:0] dbg_rom_crc,
	output            dbg_rom_checked,
	output     [24:0] dbg_rom_bytes,
	output     [15:0] dbg_hcnt,
	output     [15:0] dbg_vcnt,

	output     [23:1] dbg_cpu_addr,
	output            dbg_cpu_as_n,
	output            dbg_cpu_rw_n,
	output            dbg_cpu_uds_n,
	output            dbg_cpu_lds_n,
	output     [15:0] dbg_cpu_dout,
	output     [15:0] dbg_cpu_din,
	output     [63:0] dbg_cpu_cycles,
	output     [31:0] dbg_cpu_frames,
	output     [31:0] dbg_iack_cnt,

	output     [31:0] dbg_coin_edge,
	output     [31:0] dbg_syt_stub_rd,
	output     [31:0] dbg_syt_cmd_cnt,
	output     [31:0] dbg_syt_nmi_cnt,
	output     [31:0] dbg_syt_reply_cnt,
	output     [31:0] dbg_syt_poll_cnt,
	output     [31:0] dbg_syt_reset_cnt,
	output     [31:0] dbg_syt_nmi_en_cnt,
	output     [31:0] dbg_snd_m1_cnt,
	output     [31:0] dbg_snd_ym_cnt,
	output     [31:0] dbg_snd_ym_irq,
	output     [31:0] dbg_snd_ym_ta,
	output     [31:0] dbg_snd_ym_prog,
	output     [31:0] dbg_adpcm_fetch,
	output     [31:0] dbg_adpcm_min,
	output     [31:0] dbg_adpcm_roe,
	output     [31:0] dbg_adpcm_under,
	output     [31:0] dbg_adpcmb_fetch,
	output     [31:0] dbg_adpcmb_under,
	output     [24:0] dbg_p3_addr,
	output      [7:0] dbg_p3_data,
	output            dbg_p3_ack,
	output            dbg_ym_ev,
	output            dbg_ym_ev_we,
	output      [1:0] dbg_ym_ev_a,
	output      [7:0] dbg_ym_ev_d,
	output     [15:0] dbg_snd_pc,
	output      [1:0] dbg_snd_bank,

	output     [31:0] dbg_p2_stall,

	output     [15:0] dbg_vco_ticks,
	output            dbg_vco_over,
	output     [15:0] dbg_vco_zoom,
	output            dbg_vco_flip,
	output            dbg_vco_rowsc,
	output            dbg_vco_tilehi,
	output     [15:0] dbg_vco_flip40,
	output     [15:0] dbg_vco_flip80,
	output     [15:0] dbg_vco_zoom0,
	output     [15:0] dbg_vco_zoom1,
	output     [15:0] dbg_vco_sprzoom
);

localparam int DIV_PIX  = 6;
localparam int DIV_CPU  = 8;

localparam int FDIV_PIX = 3;
localparam int FDIV_CPU = 4;

wire [3:0] div     = fast_clk ? FDIV_PIX[3:0] : DIV_PIX[3:0];
wire [3:0] cpu_divn = fast_clk ? FDIV_CPU[3:0] : DIV_CPU[3:0];

reg [3:0] clkdiv = 0;
always @(posedge clk_sys) begin
	if (clkdiv >= div - 1'b1) clkdiv <= 0;
	else                      clkdiv <= clkdiv + 1'b1;
end

wire ce_pix_i = (clkdiv == 4'd0);

reg [3:0] cpudiv = 0;
always @(posedge clk_sys) begin
	if (cpudiv >= cpu_divn - 1'b1) cpudiv <= 0;
	else                           cpudiv <= cpudiv + 1'b1;
end

wire cen_p1  = (cpudiv == 4'd0);
wire cen_p2  = (cpudiv == (cpu_divn >> 1));

localparam int DIV_SND_YM = 6;
wire [3:0] div_snd = fast_clk ? 4'd3 : DIV_SND_YM[3:0];

reg [3:0] clkdiv_snd = 0;
reg       phase4_snd = 0;

always @(posedge clk_snd) begin
	if (clkdiv_snd >= div_snd - 1'b1) begin
		clkdiv_snd <= 0;
		phase4_snd <= ~phase4_snd;
	end
	else clkdiv_snd <= clkdiv_snd + 1'b1;
end

wire cen_ym_snd  = (clkdiv_snd == 4'd0);
wire cen_z80_snd = (clkdiv_snd == 4'd0) && phase4_snd;

localparam HTOTAL = 640, HACTIVE = 512, HSYNC_S = 528, HSYNC_E = 592;
localparam VTOTAL = 448, VACTIVE = 400, VSYNC_S = 410, VSYNC_E = 413;

reg [9:0] hcnt = 0;
reg [9:0] vcnt = 0;

always @(posedge clk_sys) begin
	if (reset_sys) begin
		hcnt <= 0; vcnt <= 0;
	end
	else if (ce_pix_i) begin
		if (hcnt == HTOTAL - 1) begin
			hcnt <= 0;
			vcnt <= (vcnt == VTOTAL - 1) ? 10'd0 : vcnt + 1'b1;
		end
		else hcnt <= hcnt + 1'b1;
	end
end

wire hblank_raw = (hcnt >= HACTIVE);
wire vblank_raw = (vcnt >= VACTIVE);
wire hsync_raw  = (hcnt >= HSYNC_S) && (hcnt < HSYNC_E);
wire vsync_raw  = (vcnt >= VSYNC_S) && (vcnt < VSYNC_E);

assign dbg_hcnt = {6'd0, hcnt};
assign dbg_vcnt = {6'd0, vcnt};

wire        active = !hblank_raw && !vblank_raw;
wire        border = (hcnt == 0) || (hcnt == HACTIVE - 1) ||
                     (vcnt == 0) || (vcnt == VACTIVE - 1);
wire [7:0]  grid_col = (hcnt[4] ^ vcnt[4]) ? 8'h40 : 8'h10;

wire [7:0] tp_r = !active ? 8'h00 : border ? 8'hFF : grid_col;
wire [7:0] tp_g = !active ? 8'h00 : border ? 8'hFF : {hcnt[7:4], 4'h0};
wire [7:0] tp_b = !active ? 8'h00 : border ? 8'hFF : {vcnt[7:4], 4'h0};

assign audio_l = ym_left;
assign audio_r = ym_right;

localparam [24:0] ROM_BYTES = 25'h390000;

localparam [24:0] BASE_MAINCPU = 25'h000000;
localparam [24:0] BASE_AUDIOCPU= 25'h080000;
localparam [24:0] BASE_GFX     = 25'h090000;
localparam [24:0] BASE_ADPCMA  = 25'h290000;
localparam [24:0] BASE_ADPCMB  = 25'h310000;

wire        sdram_ready;
reg  [24:0] p0_addr;
reg  [15:0] p0_din;
reg         p0_wide = 1'b0;
reg   [7:0] dl_even = 8'd0;
reg         p0_we;
reg         p0_req;
wire        p0_ack;
wire  [7:0] p0_dout;

sdram #(.CLK_HZ(96_000_000)) sdram_inst (
	.clk        (clk_sys),
	.init       (reset_sys),
	.SDRAM_A    (SDRAM_A),
	.SDRAM_BA   (SDRAM_BA),
	.SDRAM_DQ_IN  (SDRAM_DQ_IN),
	.SDRAM_DQ_OUT (SDRAM_DQ_OUT),
	.SDRAM_DQ_OE  (SDRAM_DQ_OE),
	.SDRAM_DQML (SDRAM_DQML),
	.SDRAM_DQMH (SDRAM_DQMH),
	.SDRAM_nCS  (SDRAM_nCS),
	.SDRAM_nRAS (SDRAM_nRAS),
	.SDRAM_nCAS (SDRAM_nCAS),
	.SDRAM_nWE  (SDRAM_nWE),
	.SDRAM_CKE  (SDRAM_CKE),
	.SDRAM_CLK  (SDRAM_CLK),
	.p0_addr    (p0_addr),
	.p0_din     (p0_din),
	.p0_wide    (p0_wide),
	.p0_mask_all(1'b0),
	.p0_we      (p0_we),
	.p0_req     (p0_req),
	.p0_ack     (p0_ack),
	.p0_dout    (p0_dout),
	.p1_addr    (p1_addr),
	.p1_req     (p1_req),
	.p1_ack     (p1_ack),
	.p1_dout    (p1_dout),
	.p2_addr    (p2_addr),
	.p2_req     (p2_req),
	.p2_burst   (p2_burst),
	.p2_ack     (p2_ack),
	.p2_dout    (p2_dout),
	.p3_addr    (p3_addr),
	.p3_req     (p3_req),
	.p3_ack     (p3_ack),
	.p3_dout    (p3_dout),
	.dbg_p2_stall (dbg_p2_stall),
	.ready      (sdram_ready)
);

wire rom_dl = ioctl_download && (ioctl_index[15:6] == 10'd0);

localparam [3:0] DL_IDLE = 0, DL_WRITE = 1, DL_WAIT = 2,
                 DL_VERIFY = 3, DL_VWAIT = 4, DL_DONE = 5;
reg  [3:0] dl_state = DL_IDLE;

reg [24:0] vaddr    = 0;
reg [31:0] crc      = 32'hFFFFFFFF;
reg [24:0] nbytes   = 0;
reg        checked  = 0;
reg  [7:0] dl_byte;
reg [24:0] dl_addr;
reg        dl_pending = 0;
reg        dl_seen    = 0;

reg        old_rom_dl = 0;
wire       dl_start   = ~old_rom_dl & rom_dl;

assign ioctl_wait = dl_pending ||
                    (dl_state == DL_WRITE) || (dl_state == DL_WAIT);

function automatic [31:0] crc32_byte(input [31:0] c, input [7:0] d);
	integer i;
	reg [31:0] x;
	begin
		x = c ^ {24'd0, d};
		for (i = 0; i < 8; i = i + 1)
			x = x[0] ? ((x >> 1) ^ 32'hEDB88320) : (x >> 1);
		crc32_byte = x;
	end
endfunction

always @(posedge clk_sys) begin
	if (p0_ack) p0_req <= 1'b0;

	old_rom_dl <= rom_dl;

	if (dl_start) begin
		dl_state   <= DL_IDLE;
		vaddr      <= 0;
		crc        <= 32'hFFFFFFFF;
		nbytes     <= 0;
		checked    <= 1'b0;
		dl_pending <= 1'b0;
		dl_seen    <= 1'b0;
	end

	if (rom_dl && ioctl_wr && !dl_pending) begin
		dl_byte    <= ioctl_dout;
		dl_addr    <= ioctl_addr;
		dl_pending <= 1'b1;
		dl_seen    <= 1'b1;
	end

	if (!dl_start) begin
		case (dl_state)
		DL_IDLE:
			if (dl_pending && sdram_ready) begin
				if (!dl_addr[0]) begin
					dl_even    <= dl_byte;
					dl_pending <= 1'b0;
				end
				else begin
					p0_addr <= {dl_addr[24:1], 1'b0};
					p0_din  <= {dl_byte, dl_even};
					p0_wide <= 1'b1;
					p0_we   <= 1'b1;
					p0_req  <= 1'b1;
					dl_state<= DL_WAIT;
				end
			end
			else if (dl_seen && !ioctl_download && !dl_pending && !checked
			         && sdram_ready && nbytes == 0) begin
				vaddr    <= 0;
				crc      <= 32'hFFFFFFFF;
				dl_state <= DL_VERIFY;
			end

		DL_WAIT:
			if (p0_ack) begin
				dl_pending <= 1'b0;
				dl_state   <= DL_IDLE;
			end

		DL_VERIFY: begin
			p0_addr  <= vaddr;
			p0_we    <= 1'b0;
			p0_req   <= 1'b1;
			dl_state <= DL_VWAIT;
		end

		DL_VWAIT:
			if (p0_ack) begin
				crc    <= crc32_byte(crc, p0_dout);
				nbytes <= nbytes + 1'b1;
				if (vaddr >= ROM_BYTES - 1) begin
					checked  <= 1'b1;
					dl_state <= DL_DONE;
				end
				else begin
					vaddr    <= vaddr + 1'b1;
					dl_state <= DL_VERIFY;
				end
			end

		DL_DONE: ;
		default: dl_state <= DL_IDLE;
		endcase
	end
end

assign dbg_rom_crc     = ~crc;
assign dbg_rom_checked = checked;
assign dbg_rom_bytes   = nbytes;

wire        cpu_reset = reset | ioctl_download | ~checked;

wire [23:1] eab;
wire        ASn, LDSn, UDSn, eRWn;
wire [15:0] oEdb;
reg  [15:0] iEdb;
reg         DTACKn;

wire cs_rom  = (eab[23:20] == 4'h0);
wire cs_ram  = (eab[23:20] == 4'h1);
wire cs_io   = (eab[23:20] == 4'h2);
wire cs_syt  = (eab[23:20] == 4'h3);
wire cs_vco  = (eab[23:20] == 4'h4) && (eab[19:1] < 19'h10800);
wire cs_160  = (eab[23:20] == 4'h4) && (eab[19:1] >= 19'h10800);
wire cs_pal  = (eab[23:20] == 4'h5);

wire cs_nop  = cs_160;

(* ramstyle = "M10K" *) reg [7:0] wram_hi [0:32767] /* verilator public_flat_rw */;
(* ramstyle = "M10K" *) reg [7:0] wram_lo [0:32767] /* verilator public_flat_rw */;
(* ramstyle = "no_rw_check, M10K" *) reg [7:0] palr_hi [0:1023]  /* verilator public_flat_rw */;
(* ramstyle = "no_rw_check, M10K" *) reg [7:0] palr_lo [0:1023]  /* verilator public_flat_rw */;

(* ramstyle = "no_rw_check, M10K" *) reg [7:0] vco_hi [0:67583] /* verilator public_flat_rw */;
(* ramstyle = "no_rw_check, M10K" *) reg [7:0] vco_lo [0:67583] /* verilator public_flat_rw */;

reg  [7:0] wram_hi_q, wram_lo_q, palr_hi_q, palr_lo_q, vco_hi_q, vco_lo_q;
wire [15:0] wram_q = {wram_hi_q, wram_lo_q};
wire [15:0] palr_q = {palr_hi_q, palr_lo_q};
wire [15:0] vco_q  = {vco_hi_q,  vco_lo_q};

wire cpu_wr = !eRWn && !ASn;

wire [14:0] cpu_wa = eab[15:1];
wire  [9:0] cpu_pa = eab[10:1];
wire [16:0] cpu_va = eab[17:1];

wire        we_hi  = cpu_wr && cen_p2 && !UDSn;
wire        we_lo  = cpu_wr && cen_p2 && !LDSn;

always @(posedge clk_sys) begin
	wram_hi_q <= wram_hi[cpu_wa];
	if (we_hi && cs_ram) wram_hi[cpu_wa] <= oEdb[15:8];
end
always @(posedge clk_sys) begin
	wram_lo_q <= wram_lo[cpu_wa];
	if (we_lo && cs_ram) wram_lo[cpu_wa] <= oEdb[7:0];
end

always @(posedge clk_sys) begin
	palr_hi_q <= palr_hi[cpu_pa];
	if (we_hi && cs_pal) palr_hi[cpu_pa] <= oEdb[15:8];
end
always @(posedge clk_sys) begin
	palr_lo_q <= palr_lo[cpu_pa];
	if (we_lo && cs_pal) palr_lo[cpu_pa] <= oEdb[7:0];
end

always @(posedge clk_sys) begin
	vco_hi_q <= vco_hi[cpu_va];
	if (we_hi && cs_vco) vco_hi[cpu_va] <= oEdb[15:8];
end
always @(posedge clk_sys) begin
	vco_lo_q <= vco_lo[cpu_va];
	if (we_lo && cs_vco) vco_lo[cpu_va] <= oEdb[7:0];
end

wire [16:0] vco_raddr;
reg   [7:0] vco_hi_r, vco_lo_r;
always @(posedge clk_sys) vco_hi_r <= vco_hi[vco_raddr];
always @(posedge clk_sys) vco_lo_r <= vco_lo[vco_raddr];
wire [15:0] vco_rq = {vco_hi_r, vco_lo_r};

wire  [9:0] pal_idx;
reg   [7:0] palr_hi_r, palr_lo_r;
always @(posedge clk_sys) palr_hi_r <= palr_hi[pal_idx];
always @(posedge clk_sys) palr_lo_r <= palr_lo[pal_idx];
wire [15:0] pal_word = {palr_hi_r, palr_lo_r};

reg [7:0] ioc_port;
reg [7:0] ioc_reg4;

wire ioc_sel   = cs_io && !ASn;
wire ioc_idx_a = eab[1];

reg  ioc_sel_d;
wire ioc_done = ioc_sel_d & ~ioc_sel;

reg signed [7:0] tb_sel_v;
always @(*) begin
	case (ioc_port[2:1])
		2'd0: tb_sel_v = tb2_y;
		2'd1: tb_sel_v = tb2_x;
		2'd2: tb_sel_v = tb1_y;
		default: tb_sel_v = tb1_x;
	endcase
end

wire ioc_is_tb    = (ioc_port[7:4] == 4'h0) && ioc_port[3];
wire ioc_tb_lo    = ioc_is_tb && !ioc_port[0];
wire ioc_tb_hi    = ioc_is_tb &&  ioc_port[0];

reg [7:0] ioc_data;
always @(*) begin
	if      (ioc_tb_lo) ioc_data = tb_sel_v;
	else if (ioc_tb_hi) ioc_data = tb_sel_v[7] ? 8'hFF : 8'h00;
	else case (ioc_port)
		8'h00:   ioc_data = dsw_a;
		8'h01:   ioc_data = dsw_b;
		8'h02:   ioc_data = in0;
		8'h03:   ioc_data = in1;
		8'h04:   ioc_data = ioc_reg4;
		8'h07:   ioc_data = in2;
		default: ioc_data = 8'hFF;
	endcase
end

wire tb_take_any = ioc_done && eRWn && !ioc_idx_a && ioc_tb_lo;
assign tb_taken  = {4{tb_take_any}} & (4'd1 << ioc_port[2:1]);

always @(posedge clk_sys) begin
	if (cpu_reset) begin
		ioc_port  <= 8'd0;
		ioc_reg4  <= 8'd0;
		ioc_sel_d <= 1'b0;
	end
	else begin
		ioc_sel_d <= ioc_sel;
		if (cpu_wr && cen_p2 && cs_io && !LDSn) begin
			if (ioc_idx_a) ioc_port <= oEdb[7:0];
			else if (ioc_port == 8'h04) ioc_reg4 <= oEdb[7:0];
		end
	end
end

reg coin_d;
reg [31:0] coin_edge;
always @(posedge clk_sys) begin
	coin_d <= in0[2];
	if (cpu_reset) coin_edge <= 32'd0;
	else if (in0[2] & ~coin_d) coin_edge <= coin_edge + 1'b1;
end
assign dbg_coin_edge = coin_edge;

wire [7:0] syt_dout;
wire [7:0] syt_s_dout;
wire       snd_syt_sel, snd_syt_a, snd_syt_we;
wire [7:0] snd_syt_din;
wire       snd_nmi, snd_reset;

wire signed [15:0] ym_left, ym_right;
wire               ym_sample;

wire [24:0] p3_addr;
wire        p3_req;
wire        p3_ack;
wire  [7:0] p3_dout;

assign dbg_p3_addr = p3_addr;
assign dbg_p3_data = p3_dout;
assign dbg_p3_ack  = p3_ack;

tc0140syt syt (
	.clk         (clk_sys),
	.reset       (cpu_reset),

	.m_sel       (cs_syt && !ASn),
	.m_a         (eab[1]),
	.m_we        (cpu_wr),
	.m_din       (oEdb[7:0]),
	.m_dout      (syt_dout),

	.s_sel       (snd_syt_sel),
	.s_a         (snd_syt_a),
	.s_we        (snd_syt_we),
	.s_din       (snd_syt_din),
	.s_dout      (syt_s_dout),

	.nmi         (snd_nmi),
	.snd_reset   (snd_reset),

	.dbg_cmd_cnt    (dbg_syt_cmd_cnt),
	.dbg_reply_cnt  (dbg_syt_reply_cnt),
	.dbg_poll_cnt   (dbg_syt_poll_cnt),
	.dbg_reset_cnt  (dbg_syt_reset_cnt),
	.dbg_nmi_cnt    (dbg_syt_nmi_cnt),
	.dbg_nmi_en_cnt (dbg_syt_nmi_en_cnt),
	.dbg_stub_rd    (dbg_syt_stub_rd)
);

wire        snd_rom_wr   = rom_dl && ioctl_wr && !dl_pending &&
                           (ioctl_addr >= BASE_AUDIOCPU) && (ioctl_addr < BASE_GFX);
wire [15:0] snd_rom_addr = ioctl_addr[15:0];

reg snd_rom_wr_x = 1'b0, p3_ack_x = 1'b0;
always @(posedge clk_sys) begin
	snd_rom_wr_x <= snd_rom_wr;
	p3_ack_x     <= p3_ack;
end
wire snd_rom_wr_snd = snd_rom_wr | snd_rom_wr_x;
wire p3_ack_snd     = p3_ack     | p3_ack_x;

sound snd (
	.clk        (clk_snd),
	.reset_i    (cpu_reset | snd_reset),
	.cen        (cen_z80_snd),
	.cen_ym     (cen_ym_snd),
	.rom_wr     (snd_rom_wr_snd),
	.rom_addr   (snd_rom_addr),
	.rom_data   (ioctl_dout),
	.syt_sel    (snd_syt_sel),
	.syt_a      (snd_syt_a),
	.syt_we     (snd_syt_we),
	.syt_din    (snd_syt_din),
	.syt_dout   (syt_s_dout),
	.nmi        (snd_nmi),
	.snd_left   (ym_left),
	.snd_right  (ym_right),
	.snd_sample (ym_sample),
	.p3_addr    (p3_addr),
	.p3_req     (p3_req),
	.p3_ack     (p3_ack_snd),
	.p3_dout    (p3_dout),
	.dbg_m1_cnt (dbg_snd_m1_cnt),
	.dbg_ym_cnt (dbg_snd_ym_cnt),
	.dbg_ym_irq (dbg_snd_ym_irq),
	.dbg_ym_ta  (dbg_snd_ym_ta),
	.dbg_ym_prog(dbg_snd_ym_prog),
	.dbg_ym_ev   (dbg_ym_ev),
	.dbg_ym_ev_we(dbg_ym_ev_we),
	.dbg_ym_ev_a (dbg_ym_ev_a),
	.dbg_ym_ev_d (dbg_ym_ev_d),
	.dbg_adpcm_fetch(dbg_adpcm_fetch),
	.dbg_adpcm_min  (dbg_adpcm_min),
	.dbg_adpcm_roe  (dbg_adpcm_roe),
	.dbg_adpcm_under(dbg_adpcm_under),
	.dbg_adpcmb_fetch (dbg_adpcmb_fetch),
	.dbg_adpcmb_under(dbg_adpcmb_under),
	.dbg_addr   (dbg_snd_pc),
	.dbg_bank   (dbg_snd_bank)
);

reg vbl_prev;
wire vbl_edge = vblank_raw & ~vbl_prev;
always @(posedge clk_sys) vbl_prev <= vblank_raw;

reg [31:0] cpu_frames;
always @(posedge clk_sys) begin
	if (cpu_reset)     cpu_frames <= 32'd0;
	else if (vbl_edge) cpu_frames <= cpu_frames + 1'b1;
end
assign dbg_cpu_frames = cpu_frames;

reg  [24:0] p1_addr;
reg         p1_req;
wire        p1_ack;
wire [15:0] p1_dout;
reg  [15:0] rom_q;
reg         rom_pending;
reg         rom_valid;
reg         rom_stale;

always @(posedge clk_sys) begin
	if (cpu_reset) begin
		p1_req      <= 1'b0;
		rom_pending <= 1'b0;
		rom_valid   <= 1'b0;
		rom_stale   <= 1'b0;
	end
	else begin
		if (p1_ack) begin
			p1_req      <= 1'b0;
			rom_pending <= 1'b0;
			rom_stale   <= 1'b0;
			rom_valid   <= ~rom_stale;
			rom_q <= {p1_dout[7:0], p1_dout[15:8]};
		end

		if (ASn) begin
			rom_valid <= 1'b0;
			if (rom_pending && !p1_ack) rom_stale <= 1'b1;
		end
		else if (cs_rom && !rom_pending && !rom_valid) begin
			p1_addr     <= BASE_MAINCPU + {6'd0, eab[18:1], 1'b0};
			p1_req      <= 1'b1;
			rom_pending <= 1'b1;
		end
	end
end

wire iack = FC2 & FC1 & FC0 & ~ASn;

always @(*) begin
	if      (iack)    iEdb = 16'h0000;
	else if (cs_rom)  iEdb = rom_q;
	else if (cs_ram)  iEdb = wram_q;
	else if (cs_vco)  iEdb = vco_q;
	else if (cs_pal)  iEdb = palr_q;
	else if (cs_io)   iEdb = {8'd0, ioc_idx_a ? ioc_port : ioc_data};
	else if (cs_syt)  iEdb = {8'd0, syt_dout};
	else              iEdb = 16'h0000;
end

always @(posedge clk_sys) begin
	if (cpu_reset) DTACKn <= 1'b1;
	else if (!ASn && !iack && cs_rom) DTACKn <= ~rom_valid;
	else if (cen_p2) begin
		if (ASn)          DTACKn <= 1'b1;
		else if (iack)    DTACKn <= 1'b1;
		else if (cs_rom)  DTACKn <= ~rom_valid;
		else              DTACKn <= 1'b0;
	end
end

reg [63:0] cpu_cyc;
always @(posedge clk_sys) begin
	if (cpu_reset) cpu_cyc <= 0;
	else if (cen_p1) cpu_cyc <= cpu_cyc + 1'b1;
end

wire FC0, FC1, FC2;

fx68k cpu (
	.clk      (clk_sys),
	.HALTn    (1'b1),
	.extReset (cpu_reset),
	.pwrUp    (cpu_reset),
	.enPhi1   (cen_p1),
	.enPhi2   (cen_p2),

	.eRWn (eRWn), .ASn (ASn), .LDSn (LDSn), .UDSn (UDSn),
	.E (), .VMAn (),
	.FC0 (FC0), .FC1 (FC1), .FC2 (FC2),
	.BGn (), .oRESETn (), .oHALTEDn (),

	.DTACKn (DTACKn),
	.VPAn   (~iack),
	.BERRn  (1'b1),
	.BRn    (1'b1),
	.BGACKn (1'b1),
	.IPL0n  (1'b1), .IPL1n (~vbl_irq), .IPL2n (1'b1),

	.iEdb (iEdb), .oEdb (oEdb), .eab (eab)
);

reg vbl_irq;
always @(posedge clk_sys) begin
	if (cpu_reset)     vbl_irq <= 1'b0;
	else if (vbl_edge) vbl_irq <= 1'b1;
	else if (iack)     vbl_irq <= 1'b0;
end

reg        iack_d;
reg [31:0] iack_cnt;
always @(posedge clk_sys) begin
	if (cpu_reset) begin
		iack_d   <= 1'b0;
		iack_cnt <= 32'd0;
	end
	else begin
		iack_d <= iack;
		if (iack && !iack_d) iack_cnt <= iack_cnt + 1'b1;
	end
end
assign dbg_iack_cnt = iack_cnt;

assign dbg_cpu_addr   = eab;
assign dbg_cpu_as_n   = ASn;
assign dbg_cpu_rw_n   = eRWn;
assign dbg_cpu_uds_n  = UDSn;
assign dbg_cpu_lds_n  = LDSn;
assign dbg_cpu_dout   = oEdb;
assign dbg_cpu_din    = iEdb;
assign dbg_cpu_cycles = cpu_cyc;

wire [24:0] p2_addr;
wire        p2_req;
wire        p2_burst;
wire        p2_ack;
wire [15:0] p2_dout;

tc0080vco #(
	.GFX_BASE (BASE_GFX),
	.V_ACTIVE (VACTIVE),
	.V_TOTAL  (VTOTAL),
	.Y_OFFSET (48)
) vco (
	.clk      (clk_sys),
	.reset    (reset_sys | ioctl_download | ~checked),
	.ce_pix   (ce_pix_i),
	.hcnt     (hcnt),
	.vcnt     (vcnt),

	.ram_addr (vco_raddr),
	.ram_q    (vco_rq),
	.pal_idx  (pal_idx),

	.sd_addr  (p2_addr),
	.sd_req   (p2_req),
	.sd_burst (p2_burst),
	.sd_ack   (p2_ack),
	.sd_dout  (p2_dout),

	.dbg_line_ticks   (dbg_vco_ticks),
	.dbg_line_over    (dbg_vco_over),
	.dbg_zoom_odd     (dbg_vco_zoom),
	.dbg_flipscreen   (dbg_vco_flip),
	.dbg_rowscroll_nz (dbg_vco_rowsc),
	.dbg_tile_hi      (dbg_vco_tilehi),
	.dbg_flip40       (dbg_vco_flip40),
	.dbg_flip80       (dbg_vco_flip80),
	.dbg_zoom0        (dbg_vco_zoom0),
	.dbg_zoom1        (dbg_vco_zoom1),
	.dbg_spr_zoomed   (dbg_vco_sprzoom)
);

function automatic [7:0] ex5(input [4:0] c);
	ex5 = {c, c[4:2]};
endfunction

reg [7:0] r_q, g_q, b_q;
always @(posedge clk_sys) begin
	r_q <= ex5(pal_word[ 4: 0]);
	g_q <= ex5(pal_word[ 9: 5]);
	b_q <= ex5(pal_word[14:10]);
end

reg [4:0] vsr [0:3];
always @(posedge clk_sys) begin
	vsr[0] <= {ce_pix_i, hblank_raw, vblank_raw, hsync_raw, vsync_raw};
	vsr[1] <= vsr[0];
	vsr[2] <= vsr[1];
	vsr[3] <= vsr[2];
end

assign ce_pix = vsr[3][4];
assign hblank = vsr[3][3];
assign vblank = vsr[3][2];
assign hsync  = vsr[3][1];
assign vsync  = vsr[3][0];

reg [23:0] tp_sr [0:3];
always @(posedge clk_sys) begin
	tp_sr[0] <= {tp_r, tp_g, tp_b};
	tp_sr[1] <= tp_sr[0];
	tp_sr[2] <= tp_sr[1];
	tp_sr[3] <= tp_sr[2];
end

wire blanked = vsr[3][3] | vsr[3][2];

assign red   = test_pattern ? tp_sr[3][23:16] : blanked ? 8'h00 : r_q;
assign green = test_pattern ? tp_sr[3][15:8]  : blanked ? 8'h00 : g_q;
assign blue  = test_pattern ? tp_sr[3][7:0]   : blanked ? 8'h00 : b_q;

wire _unused = &{1'b0, cs_nop, cs_160, ym_sample,
                 palr_q[15], pal_word[15], BASE_ADPCMA,
                 BASE_ADPCMB, 1'b0};

endmodule
