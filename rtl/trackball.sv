module trackball (
	input               clk,
	input               reset,

	input      [24:0]   ps2_mouse,

	input               dp_up,
	input               dp_down,
	input               dp_left,
	input               dp_right,

	input               swap_xy,
	input               neg_vert,

	input               taken_px,
	input               taken_py,

	output signed [7:0] tb_x,
	output signed [7:0] tb_y
);

reg        ps2_tog_d;
reg signed [11:0] acc_x, acc_y;

wire taken_x = swap_xy ? taken_py : taken_px;
wire taken_y = swap_xy ? taken_px : taken_py;

wire signed [8:0] mouse_dx = $signed({ps2_mouse[4], ps2_mouse[15:8]});
wire signed [8:0] mouse_dy = $signed({ps2_mouse[5], ps2_mouse[23:16]});
wire              mouse_ev = (ps2_mouse[24] != ps2_tog_d);

always @(posedge clk) begin
	ps2_tog_d <= ps2_mouse[24];

	if (reset) begin
		acc_x <= 12'sd0;
		acc_y <= 12'sd0;
	end
	else begin
		if (taken_x) acc_x <= mouse_ev ? {{3{mouse_dx[8]}}, mouse_dx} : 12'sd0;
		else if (mouse_ev)
		             acc_x <= acc_x + {{3{mouse_dx[8]}}, mouse_dx};

		if (taken_y) acc_y <= mouse_ev ? {{3{mouse_dy[8]}}, mouse_dy} : 12'sd0;
		else if (mouse_ev)
		             acc_y <= acc_y + {{3{mouse_dy[8]}}, mouse_dy};
	end
end

localparam signed [11:0] KEYDELTA = 12'sd30;

wire signed [11:0] pad_x = dp_right ? KEYDELTA : dp_left ? -KEYDELTA : 12'sd0;
wire signed [11:0] pad_y = dp_up    ? KEYDELTA : dp_down ? -KEYDELTA : 12'sd0;

wire signed [11:0] sum_x = acc_x + pad_x;
wire signed [11:0] sum_y = acc_y + pad_y;

function automatic signed [7:0] sat8(input signed [11:0] v);
	sat8 = (v >  12'sd127) ?  8'sd127 :
	       (v < -12'sd128) ? -8'sd128 : v[7:0];
endfunction

wire signed [11:0] vert = neg_vert ? -sum_y : sum_y;

wire signed [7:0] out_x = sat8(sum_x);
wire signed [7:0] out_y = sat8(vert);

assign tb_x = swap_xy ? out_y : out_x;
assign tb_y = swap_xy ? out_x : out_y;

endmodule
