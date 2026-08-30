module jtframe_dual_ram #(
	parameter DW = 8,
	parameter AW = 10
)(
	input                clk0,
	input       [DW-1:0] data0,
	input       [AW-1:0] addr0,
	input                we0,
	output reg  [DW-1:0] q0,

	input                clk1,
	input       [DW-1:0] data1,
	input       [AW-1:0] addr1,
	input                we1,
	output reg  [DW-1:0] q1
);

(* ramstyle = "no_rw_check" *) reg [DW-1:0] mem [0:(2**AW)-1];

always @(posedge clk0) begin
	q0 <= mem[addr0];
	if (we0) mem[addr0] <= data0;
end

always @(posedge clk1) begin
	q1 <= mem[addr1];
	if (we1) mem[addr1] <= data1;
end

endmodule
