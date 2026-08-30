module ym2610_timer (
	input             clk,
	input             reset,
	input             cen,

	input             sel,
	input       [1:0] a,
	input             we,
	input       [7:0] din,
	output      [7:0] dout,

	output            irq,

	output reg [31:0] dbg_irq_cnt,
	output reg [31:0] dbg_ta_cnt,
	output     [31:0] dbg_ym_prog
);

localparam [17:0] TA_SCALE = 18'd144;
localparam [17:0] TB_SCALE = 18'd2304;

reg  [9:0] ta_period;
reg  [7:0] tb_period;
reg  [7:0] ctrl;
reg  [7:0] addr_a;

reg [17:0] ta_cnt, tb_cnt;
reg        ta_flag, tb_flag;
reg        irq_d;

wire ta_vis = ta_flag & ctrl[2];
wire tb_vis = tb_flag & ctrl[3];

assign dout = {6'd0, tb_vis, ta_vis};
assign irq  = ta_vis | tb_vis;

wire [17:0] ta_limit = TA_SCALE * (18'd1024 - {8'd0, ta_period});
wire [17:0] tb_limit = TB_SCALE * (18'd256  - {10'd0, tb_period});

assign dbg_ym_prog = {6'd0, ta_period, ctrl, tb_period};

reg sel_d, we_h;
reg [1:0] a_h;
reg [7:0] din_h;

always @(posedge clk) begin
	sel_d <= sel;
	if (sel) begin a_h <= a; we_h <= we; din_h <= din; end
end

wire acc_done = sel_d & ~sel;

always @(posedge clk) begin
	if (reset) begin
		ta_period   <= 10'd0;
		tb_period   <= 8'd0;
		ctrl        <= 8'd0;
		addr_a      <= 8'd0;
		ta_cnt      <= 18'd0;
		tb_cnt      <= 18'd0;
		ta_flag     <= 1'b0;
		tb_flag     <= 1'b0;
		dbg_irq_cnt <= 32'd0;
		dbg_ta_cnt  <= 32'd0;
	end
	else begin
		if (acc_done && we_h) begin
			case (a_h)
			2'd0: addr_a <= din_h;
			2'd1: begin
				case (addr_a)
				8'h24: ta_period[9:2] <= din_h;
				8'h25: ta_period[1:0] <= din_h[1:0];
				8'h26: tb_period      <= din_h;
				8'h27: begin
					ctrl <= din_h;
					if (din_h[4]) ta_flag <= 1'b0;
					if (din_h[5]) tb_flag <= 1'b0;
					if (din_h[0] && !ctrl[0]) ta_cnt <= 18'd0;
					if (din_h[1] && !ctrl[1]) tb_cnt <= 18'd0;
				end
				default: ;
				endcase
			end
			default: ;
			endcase
		end

		if (cen) begin
			if (ctrl[0]) begin
				if (ta_cnt + 18'd1 >= ta_limit) begin
					ta_cnt  <= 18'd0;
					ta_flag <= 1'b1;
					dbg_ta_cnt <= dbg_ta_cnt + 1'b1;
				end
				else ta_cnt <= ta_cnt + 18'd1;
			end

			if (ctrl[1]) begin
				if (tb_cnt + 18'd1 >= tb_limit) begin
					tb_cnt  <= 18'd0;
					tb_flag <= 1'b1;
				end
				else tb_cnt <= tb_cnt + 18'd1;
			end
		end

		if (irq && !irq_d) dbg_irq_cnt <= dbg_irq_cnt + 1'b1;
		irq_d <= irq;
	end
end

endmodule
