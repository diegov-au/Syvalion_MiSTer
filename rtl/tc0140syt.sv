module tc0140syt (
	input             clk,
	input             reset,

	input             m_sel,
	input             m_a,
	input             m_we,
	input       [7:0] m_din,
	output reg  [7:0] m_dout,

	input             s_sel,
	input             s_a,
	input             s_we,
	input       [7:0] s_din,
	output reg  [7:0] s_dout,

	output            nmi,
	output reg        snd_reset,

	output reg [31:0] dbg_cmd_cnt,
	output reg [31:0] dbg_reply_cnt,
	output reg [31:0] dbg_poll_cnt,
	output reg [31:0] dbg_reset_cnt,
	output reg [31:0] dbg_nmi_cnt,
	output reg [31:0] dbg_nmi_en_cnt,
	output reg [31:0] dbg_stub_rd
);

reg [3:0] slavedata  [0:3];
reg [3:0] masterdata [0:3];

reg [3:0] mainmode;
reg [3:0] submode;
reg [3:0] status;
reg       nmi_enabled;

assign nmi = nmi_enabled & |status[1:0];

reg       m_sel_d, s_sel_d;
reg       m_a_h, m_we_h, s_a_h, s_we_h;
reg [7:0] m_din_h, s_din_h;

wire m_done = m_sel_d & ~m_sel;
wire s_done = s_sel_d & ~s_sel;

always @(posedge clk) begin
	m_sel_d <= m_sel;
	s_sel_d <= s_sel;
	if (m_sel) begin m_a_h <= m_a; m_we_h <= m_we; m_din_h <= m_din; end
	if (s_sel) begin s_a_h <= s_a; s_we_h <= s_we; s_din_h <= s_din; end
end

wire [3:0] m_nib = m_din_h[3:0];
wire [3:0] s_nib = s_din_h[3:0];

wire m_comm    = m_done && m_a_h;
wire s_comm    = s_done && s_a_h;
wire m_comm_wr = m_comm &&  m_we_h;
wire m_comm_rd = m_comm && !m_we_h;
wire s_comm_wr = s_comm &&  s_we_h;
wire s_comm_rd = s_comm && !s_we_h;

wire set_01        = m_comm_wr && (mainmode == 4'd1);
wire set_23        = m_comm_wr && (mainmode == 4'd3);
wire clr_01        = s_comm_rd && (submode  == 4'd1);
wire clr_23        = s_comm_rd && (submode  == 4'd3);
wire set_01_master = s_comm_wr && (submode  == 4'd1);
wire set_23_master = s_comm_wr && (submode  == 4'd3);
wire clr_01_master = m_comm_rd && (mainmode == 4'd1);
wire clr_23_master = m_comm_rd && (mainmode == 4'd3);

integer i;

always @(posedge clk) begin
	if (reset) begin
		mainmode    <= 4'd0;
		submode     <= 4'd0;
		status      <= 4'd0;
		nmi_enabled <= 1'b0;
		snd_reset      <= 1'b0;
		dbg_cmd_cnt    <= 32'd0;
		dbg_reply_cnt  <= 32'd0;
		dbg_poll_cnt   <= 32'd0;
		dbg_reset_cnt  <= 32'd0;
		dbg_nmi_cnt    <= 32'd0;
		dbg_nmi_en_cnt <= 32'd0;
		dbg_stub_rd    <= 32'd0;
		for (i = 0; i < 4; i = i + 1) begin
			slavedata[i]  <= 4'd0;
			masterdata[i] <= 4'd0;
		end
	end
	else begin
		if (m_done) begin
			if (!m_a_h) begin
				if (m_we_h) mainmode <= m_nib;
			end
			else if (m_we_h) begin
				case (mainmode)
				4'd0, 4'd1, 4'd2, 4'd3: begin
					slavedata[mainmode[1:0]] <= m_nib;
					mainmode <= mainmode + 4'd1;
				end
				4'd4: snd_reset <= |m_nib;
				default: ;
				endcase
			end
			else begin
				case (mainmode)
				4'd0, 4'd1, 4'd2, 4'd3: mainmode <= mainmode + 4'd1;
				4'd4: ;
				default: ;
				endcase
			end
		end

		if (s_done) begin
			if (!s_a_h) begin
				if (s_we_h) submode <= s_nib;
			end
			else if (s_we_h) begin
				case (submode)
				4'd0, 4'd1, 4'd2, 4'd3: begin
					masterdata[submode[1:0]] <= s_nib;
					submode <= submode + 4'd1;
				end
				4'd4: ;
				4'd5: nmi_enabled <= 1'b0;
				4'd6: nmi_enabled <= 1'b1;
				default: ;
				endcase
			end
			else begin
				case (submode)
				4'd0, 4'd1, 4'd2, 4'd3: submode <= submode + 4'd1;
				default: ;
				endcase
			end
		end

		status[0] <= clr_01        ? 1'b0 : set_01        ? 1'b1 : status[0];
		status[1] <= clr_23        ? 1'b0 : set_23        ? 1'b1 : status[1];
		status[2] <= clr_01_master ? 1'b0 : set_01_master ? 1'b1 : status[2];
		status[3] <= clr_23_master ? 1'b0 : set_23_master ? 1'b1 : status[3];

		if (set_01 || set_23)               dbg_cmd_cnt    <= dbg_cmd_cnt    + 1'b1;
		if (set_01_master || set_23_master) dbg_reply_cnt  <= dbg_reply_cnt  + 1'b1;

		if (s_done && !s_a_h && s_we_h && (s_nib == 4'd4))
			dbg_poll_cnt   <= dbg_poll_cnt   + 1'b1;
		if (s_done && !s_a_h && s_we_h && (s_nib == 4'd6))
			dbg_nmi_en_cnt <= dbg_nmi_en_cnt + 1'b1;

		if (m_done && m_a_h && m_we_h && (mainmode == 4'd4) && |m_nib)
			dbg_reset_cnt <= dbg_reset_cnt + 1'b1;

		if (nmi_next && !nmi) dbg_nmi_cnt <= dbg_nmi_cnt + 1'b1;

		if (m_comm_rd && (mainmode == 4'd1) && !status[2]) dbg_stub_rd <= dbg_stub_rd + 1'b1;
		if (m_comm_rd && (mainmode == 4'd3) && !status[3]) dbg_stub_rd <= dbg_stub_rd + 1'b1;
	end
end

wire [1:0] status_next = {clr_23 ? 1'b0 : set_23 ? 1'b1 : status[1],
                          clr_01 ? 1'b0 : set_01 ? 1'b1 : status[0]};
wire       nmi_next    = (s_comm_wr && (submode == 4'd6) ? 1'b1 :
                          s_comm_wr && (submode == 4'd5) ? 1'b0 : nmi_enabled)
                         & |status_next;

always @(*) begin
	m_dout = 8'h00;
	if (m_a) begin
		case (mainmode)
		4'd0, 4'd1, 4'd2, 4'd3: m_dout = {4'h0, masterdata[mainmode[1:0]]};
		4'd4:                   m_dout = {4'h0, status};
		default:                m_dout = 8'h00;
		endcase
	end
end

always @(*) begin
	s_dout = 8'h00;
	if (s_a) begin
		case (submode)
		4'd0, 4'd1, 4'd2, 4'd3: s_dout = {4'h0, slavedata[submode[1:0]]};
		4'd4:                   s_dout = {4'h0, status};
		default:                s_dout = 8'h00;
		endcase
	end
end

endmodule
