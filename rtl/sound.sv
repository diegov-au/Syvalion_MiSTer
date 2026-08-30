module sound (
	input             clk,
	input             reset_i,
	input             cen,
	input             cen_ym,

	input             rom_wr,
	input      [15:0] rom_addr,
	input       [7:0] rom_data,

	output            syt_sel,
	output            syt_a,
	output            syt_we,
	output      [7:0] syt_din,
	input       [7:0] syt_dout,
	input             nmi,

	output signed [15:0] snd_left,
	output signed [15:0] snd_right,
	output               snd_sample,

	output     [24:0] p3_addr,
	output            p3_req,
	input             p3_ack,
	input       [7:0] p3_dout,

	output reg        dbg_ym_ev,
	output reg        dbg_ym_ev_we,
	output reg  [1:0] dbg_ym_ev_a,
	output reg  [7:0] dbg_ym_ev_d,

	output reg [31:0] dbg_m1_cnt,
	output reg [31:0] dbg_ym_cnt,
	output reg [31:0] dbg_ym_irq,
	output reg [31:0] dbg_ym_ta,
	output     [31:0] dbg_ym_prog,

	output reg [31:0] dbg_adpcm_fetch,
	output reg [31:0] dbg_adpcm_min,
	output reg [31:0] dbg_adpcm_roe,
	output reg [31:0] dbg_adpcm_under,

	output reg [31:0] dbg_adpcmb_fetch,
	output reg [31:0] dbg_adpcmb_under,

	output     [15:0] dbg_addr,
	output      [1:0] dbg_bank
);

reg [1:0] reset_sr = 2'b11;
always @(posedge clk) reset_sr <= {reset_sr[0], reset_i};
wire reset = reset_sr[1];

reg [7:0] srom [0:65535] /* verilator public_flat_rw */;
reg [7:0] sram [0:8191]  /* verilator public_flat_rw */;

reg [7:0] srom_q, sram_q;
reg [1:0] bank;

wire [15:0] a;
wire  [7:0] cpu_dout;
wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
reg   [7:0] cpu_din;

tv80s_ce z80 (
	.clk     (clk),
	.cen     (cen),
	.reset_n (~reset),
	.wait_n  (1'b1),
	.int_n   (~ym_irq),
	.nmi_n   (~nmi),
	.busrq_n (1'b1),
	.m1_n    (m1_n),
	.mreq_n  (mreq_n),
	.iorq_n  (iorq_n),
	.rd_n    (rd_n),
	.wr_n    (wr_n),
	.rfsh_n  (rfsh_n),
	.halt_n  (),
	.busak_n (),
	.A       (a),
	.di      (cpu_din),
	.dout    (cpu_dout)
);

wire mem = ~mreq_n & rfsh_n;
wire rd  = mem & ~rd_n;
wire wr  = mem & ~wr_n;

wire sel_rom_fixed = (a[15:14] == 2'b00);
wire sel_rom_bank  = (a[15:14] == 2'b01);
wire sel_ram       = (a[15:13] == 3'b110);
wire sel_ym        = (a[15:2]  == 14'h3800);
wire sel_syt       = (a[15:1]  == 15'h7100);
wire sel_bank      = (a        == 16'hF200);

wire [15:0] rom_index = sel_rom_bank ? {bank, a[13:0]} : {2'b00, a[13:0]};

always @(posedge clk) begin
	srom_q <= srom[rom_index];
	sram_q <= sram[a[12:0]];

	if (rom_wr) srom[rom_addr] <= rom_data;
	if (wr && sel_ram) sram[a[12:0]] <= cpu_dout;

	if (reset) bank <= 2'd0;
	else if (wr && sel_bank) bank <= cpu_dout[1:0];
end

assign syt_sel = sel_syt & mem & (~rd_n | ~wr_n);
assign syt_a   = a[0];
assign syt_we  = ~wr_n;
assign syt_din = cpu_dout;

wire [7:0] ym_dout;
wire       ym_irq_n;
wire       ym_irq = ~ym_irq_n;

wire [19:0] adpcma_addr;
wire  [3:0] adpcma_bank;
wire        adpcma_roe_n;
wire  [7:0] adpcma_data_r = have_data;

wire [23:0] adpcmb_addr;
wire        adpcmb_roe_n;
wire  [7:0] adpcmb_data_r = b_have_data;

wire ym_acc      = sel_ym & mem;
wire ym_wr_level = ym_acc & ~wr_n;
reg  ym_wr_d;
always @(posedge clk) ym_wr_d <= ym_wr_level;
wire ym_wr_pulse = ym_wr_level & ~ym_wr_d;

jt10 ym (
	.rst          (reset),
	.clk          (clk),
	.cen          (cen_ym),
	.din          (cpu_dout),
	.addr         (a[1:0]),
	.cs_n         (1'b0),
	.wr_n         (~ym_wr_pulse),
	.dout         (ym_dout),
	.irq_n        (ym_irq_n),

	.adpcma_addr  (adpcma_addr),
	.adpcma_bank  (adpcma_bank),
	.adpcma_roe_n (adpcma_roe_n),
	.adpcma_data  (adpcma_data_r),

	.adpcmb_addr  (adpcmb_addr),
	.adpcmb_roe_n (adpcmb_roe_n),
	.adpcmb_data  (adpcmb_data_r),

	.psg_A        (),
	.psg_B        (),
	.psg_C        (),
	.fm_snd       (),
	.psg_snd      (),
	.snd_right    (snd_right),
	.snd_left     (snd_left),
	.snd_sample   (snd_sample),
	.ch_enable    (6'b111111)
);

reg [7:0] ym_reg;
reg       ym_irq_d;
reg [7:0] ta_hi, ym_ctrl, tb_per;
reg [1:0] ta_lo;

always @(posedge clk) begin
	if (reset) begin
		dbg_ym_irq  <= 32'd0;
		dbg_ym_ta   <= 32'd0;
		ym_irq_d    <= 1'b0;
		ym_reg      <= 8'd0;
		ta_hi       <= 8'd0;
		ta_lo       <= 2'd0;
		ym_ctrl     <= 8'd0;
		tb_per      <= 8'd0;
	end
	else begin
		ym_irq_d <= ym_irq;
		if (ym_irq & ~ym_irq_d) begin
			dbg_ym_irq <= dbg_ym_irq + 1'b1;
			dbg_ym_ta  <= dbg_ym_ta  + 1'b1;
		end
		if (ym_wr_pulse && !a[0]) ym_reg <= cpu_dout;
		if (ym_wr_pulse &&  a[0]) begin
			case (ym_reg)
				8'h24: ta_hi <= cpu_dout;
				8'h25: ta_lo <= cpu_dout[1:0];
				8'h27: ym_ctrl <= cpu_dout;
				8'h26: tb_per  <= cpu_dout;
				default: ;
			endcase
		end
	end
end

assign dbg_ym_prog = {6'd0, ta_hi, ta_lo, ym_ctrl, tb_per};

localparam [24:0] ADPCMA_BASE = 25'h290000;

reg [19:0] fetch_addr;
reg        fetching;
reg [19:0] have_addr;
reg  [7:0] have_data;
reg        have_valid;
reg [19:0] next_addr;
reg  [7:0] next_data;
reg        next_valid;
reg        adpcma_roe_d2;

wire hit      = have_valid && (have_addr == adpcma_addr);
wire next_hit = next_valid && (next_addr == adpcma_addr);

wire [24:0] a_p3_addr = ADPCMA_BASE + {6'd0, fetch_addr[18:0]};
wire        a_p3_req  = fetching;

always @(posedge clk) begin
	adpcma_roe_d2 <= adpcma_roe_n;

	if (reset) begin
		fetch_addr      <= 20'hFFFFF;
		fetching        <= 1'b0;
		have_addr       <= 20'hFFFFF;
		have_data       <= 8'd0;
		have_valid      <= 1'b0;
		next_addr       <= 20'hFFFFF;
		next_data       <= 8'd0;
		next_valid      <= 1'b0;
		dbg_adpcm_under <= 32'd0;
		adpcma_roe_d2   <= 1'b1;
	end
	else begin
		if (~adpcma_roe_n & adpcma_roe_d2) begin
			if (hit) begin
				;
			end
			else if (next_hit) begin
				have_addr  <= next_addr;
				have_data  <= next_data;
				have_valid <= 1'b1;
				next_valid <= 1'b0;
				if (!fetching) begin
					fetch_addr <= next_addr + 20'd1;
					fetching   <= 1'b1;
				end
			end
			else begin
				dbg_adpcm_under <= dbg_adpcm_under + 1'b1;
				fetch_addr      <= adpcma_addr;
				fetching        <= 1'b1;
				have_valid      <= 1'b0;
				next_valid      <= 1'b0;
			end
		end

		if (fetching && a_ack) begin
			fetching <= 1'b0;
			if (!have_valid && fetch_addr == adpcma_addr) begin
				have_addr  <= fetch_addr;
				have_data  <= p3_dout;
				have_valid <= 1'b1;
				fetch_addr <= fetch_addr + 20'd1;
				fetching   <= 1'b1;
			end
			else begin
				next_addr  <= fetch_addr;
				next_data  <= p3_dout;
				next_valid <= 1'b1;
			end
		end
	end
end

localparam [24:0] ADPCMB_BASE = 25'h310000;

reg [18:0] b_fetch_addr;
reg        b_fetching;
reg [18:0] b_have_addr;
reg  [7:0] b_have_data;
reg        b_have_valid;
reg [18:0] b_next_addr;
reg  [7:0] b_next_data;
reg        b_next_valid;
reg        adpcmb_roe_d2;

wire [18:0] b_addr19   = adpcmb_addr[18:0];
wire        b_hit      = b_have_valid && (b_have_addr == b_addr19);
wire        b_next_hit = b_next_valid && (b_next_addr == b_addr19);

wire [24:0] b_p3_addr  = ADPCMB_BASE + {6'd0, b_fetch_addr};
wire        b_p3_req   = b_fetching;

reg grant_b;
reg granted;
reg last_b;

wire a_ack = granted && !grant_b && p3_ack;
wire b_ack = granted &&  grant_b && p3_ack;

assign p3_addr = grant_b ? b_p3_addr : a_p3_addr;
assign p3_req  = granted;

always @(posedge clk) begin
	if (reset) begin
		granted <= 1'b0;
		grant_b <= 1'b0;
		last_b  <= 1'b0;
	end
	else if (granted) begin
		if (p3_ack) begin
			granted <= 1'b0;
			last_b  <= grant_b;
		end
	end
	else if (a_p3_req || b_p3_req) begin
		grant_b <= last_b ? (a_p3_req ? 1'b0 : 1'b1)
		                  : (b_p3_req ? 1'b1 : 1'b0);
		granted <= 1'b1;
	end
end

always @(posedge clk) begin
	adpcmb_roe_d2 <= adpcmb_roe_n;

	if (reset) begin
		b_fetch_addr     <= 19'h7FFFF;
		b_fetching       <= 1'b0;
		b_have_addr      <= 19'h7FFFF;
		b_have_data      <= 8'd0;
		b_have_valid     <= 1'b0;
		b_next_addr      <= 19'h7FFFF;
		b_next_data      <= 8'd0;
		b_next_valid     <= 1'b0;
		adpcmb_roe_d2    <= 1'b1;
		dbg_adpcmb_under <= 32'd0;
		dbg_adpcmb_fetch <= 32'd0;
	end
	else begin
		if (~adpcmb_roe_n & adpcmb_roe_d2) begin
			if (b_hit) begin
				;
			end
			else if (b_next_hit) begin
				b_have_addr  <= b_next_addr;
				b_have_data  <= b_next_data;
				b_have_valid <= 1'b1;
				b_next_valid <= 1'b0;
				if (!b_fetching) begin
					b_fetch_addr <= b_next_addr + 19'd1;
					b_fetching   <= 1'b1;
				end
			end
			else begin
				dbg_adpcmb_under <= dbg_adpcmb_under + 1'b1;
				b_fetch_addr     <= b_addr19;
				b_fetching       <= 1'b1;
				b_have_valid     <= 1'b0;
				b_next_valid     <= 1'b0;
			end
		end

		if (b_fetching && b_ack) begin
			b_fetching       <= 1'b0;
			dbg_adpcmb_fetch <= dbg_adpcmb_fetch + 1'b1;
			if (!b_have_valid && b_fetch_addr == b_addr19) begin
				b_have_addr  <= b_fetch_addr;
				b_have_data  <= p3_dout;
				b_have_valid <= 1'b1;
				b_fetch_addr <= b_fetch_addr + 19'd1;
				b_fetching   <= 1'b1;
			end
			else begin
				b_next_addr  <= b_fetch_addr;
				b_next_data  <= p3_dout;
				b_next_valid <= 1'b1;
			end
		end
	end
end

reg [19:0] adpcma_addr_d;
reg [31:0] adpcm_gap;
reg        adpcma_roe_d;

always @(posedge clk) begin
	if (reset) begin
		dbg_adpcm_fetch <= 32'd0;
		dbg_adpcm_min   <= 32'hFFFFFFFF;
		dbg_adpcm_roe   <= 32'd0;
		adpcm_gap       <= 32'd0;
		adpcma_addr_d   <= 20'd0;
		adpcma_roe_d    <= 1'b1;
	end
	else begin
		adpcma_addr_d <= adpcma_addr;
		adpcma_roe_d  <= adpcma_roe_n;

		if (~adpcma_roe_n & adpcma_roe_d) dbg_adpcm_roe <= dbg_adpcm_roe + 1'b1;

		if (adpcma_addr != adpcma_addr_d)
			dbg_adpcm_fetch <= dbg_adpcm_fetch + 1'b1;

		adpcm_gap <= adpcm_gap + 1'b1;
		if (~adpcma_roe_n & adpcma_roe_d) begin
			adpcm_gap <= 32'd1;
			if (dbg_adpcm_roe != 32'd0 && adpcm_gap < dbg_adpcm_min)
				dbg_adpcm_min <= adpcm_gap;
		end
	end
end

always @(*) begin
	if      (sel_rom_fixed || sel_rom_bank) cpu_din = srom_q;
	else if (sel_ram)                       cpu_din = sram_q;
	else if (sel_syt)                       cpu_din = syt_dout;
	else if (sel_ym)                        cpu_din = ym_dout;
	else                                    cpu_din = 8'h00;
end

reg m1_d, ym_d;
always @(posedge clk) begin
	if (reset) begin
		dbg_m1_cnt <= 32'd0;
		dbg_ym_cnt <= 32'd0;
		m1_d       <= 1'b0;
		ym_d       <= 1'b0;
	end
	else begin
		m1_d <= ~m1_n & rd;
		if (~m1_n & rd & ~m1_d) dbg_m1_cnt <= dbg_m1_cnt + 1'b1;

		ym_d <= sel_ym & (rd | wr);
		if (sel_ym & (rd | wr) & ~ym_d) dbg_ym_cnt <= dbg_ym_cnt + 1'b1;
	end
end

always @(posedge clk) begin
	if (reset) begin
		dbg_ym_ev    <= 1'b0;
		dbg_ym_ev_we <= 1'b0;
		dbg_ym_ev_a  <= 2'd0;
		dbg_ym_ev_d  <= 8'd0;
	end
	else begin
		dbg_ym_ev    <= sel_ym & (rd | wr) & ~ym_d;
		dbg_ym_ev_we <= ~wr_n;
		dbg_ym_ev_a  <= a[1:0];
		dbg_ym_ev_d  <= wr ? cpu_dout : ym_dout;
	end
end

reg [15:0] last_m1;
always @(posedge clk) begin
	if (reset) last_m1 <= 16'd0;
	else if (~m1_n & rd & ~m1_d) last_m1 <= a;
end

assign dbg_addr = last_m1;
assign dbg_bank = bank;

wire _unused = &{1'b0, iorq_n, 1'b0};

endmodule
