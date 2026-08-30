module gfx_fetch #(
	parameter [24:0] GFX_BASE = 25'h090000
) (
	input             clk,
	input             reset,

	input             req,
	input      [13:0] tile,
	input       [3:0] row,
	input             flipx,
	input             flipy,

	output reg        busy,
	output reg        done,
	output reg [63:0] pixels,

	output reg [24:0] sd_addr,
	output reg        sd_req,
	output reg        sd_burst,
	input             sd_ack,
	input      [15:0] sd_dout
);

wire [3:0] eff_row = flipy ? ~row : row;

localparam S_IDLE = 2'd0, S_WAIT = 2'd1, S_DONE = 2'd2;
reg [1:0] state;
reg [1:0] wcnt;

reg [63:0] acc;

always @(posedge clk) begin
	done <= 1'b0;

	if (reset) begin
		state    <= S_IDLE;
		busy     <= 1'b0;
		sd_req   <= 1'b0;
		sd_burst <= 1'b0;
		wcnt     <= 2'd0;
	end
	else case (state)

	S_IDLE:
		if (req) begin
			sd_addr  <= GFX_BASE + {4'd0, tile, eff_row, 3'd0};
			sd_req   <= 1'b1;
			sd_burst <= 1'b1;
			busy     <= 1'b1;
			wcnt     <= 2'd0;
			state    <= S_WAIT;
		end

	S_WAIT: begin
		if (sd_ack) begin
			sd_req   <= 1'b0;
			sd_burst <= 1'b0;

			case (wcnt)
			2'd0: begin
				acc[51:48] <= sd_dout[11: 8];
				acc[55:52] <= sd_dout[15:12];
				acc[59:56] <= sd_dout[ 3: 0];
				acc[63:60] <= sd_dout[ 7: 4];
			end
			2'd1: begin
				acc[35:32] <= sd_dout[11: 8];
				acc[39:36] <= sd_dout[15:12];
				acc[43:40] <= sd_dout[ 3: 0];
				acc[47:44] <= sd_dout[ 7: 4];
			end
			2'd2: begin
				acc[19:16] <= sd_dout[11: 8];
				acc[23:20] <= sd_dout[15:12];
				acc[27:24] <= sd_dout[ 3: 0];
				acc[31:28] <= sd_dout[ 7: 4];
			end
			default: begin
				acc[ 3: 0] <= sd_dout[11: 8];
				acc[ 7: 4] <= sd_dout[15:12];
				acc[11: 8] <= sd_dout[ 3: 0];
				acc[15:12] <= sd_dout[ 7: 4];
			end
			endcase

			if (wcnt == 2'd3) state <= S_DONE;
			else              wcnt  <= wcnt + 2'd1;
		end
	end

	S_DONE: begin
		if (flipx) begin
			integer i;
			for (i = 0; i < 16; i = i + 1)
				pixels[i*4 +: 4] <= acc[(15-i)*4 +: 4];
		end
		else pixels <= acc;
		done  <= 1'b1;
		busy  <= 1'b0;
		state <= S_IDLE;
	end

	default: state <= S_IDLE;
	endcase
end

endmodule
