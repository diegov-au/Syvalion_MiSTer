//============================================================================
//
//  Syvalion (Taito, 1988) - Taito H System - MiSTer top level.
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_MIX = 0;

assign BUTTONS   = 0;

`include "build_id.v"
localparam CONF_STR = {
	"Syvalion;;",

	"O[122:121],Aspect Ratio,Original,Full Screen;",

	"O[3:2],Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
	"-;",

	"P1,DIP Switches;",
	"P1-;",

	"P1O[9],Service Mode,Off,On;",
	"P1O[10],Demo Sounds,On,Off;",
	"P1O[11],Flip Screen,Off,On;",
	"P1O[12],Cabinet,Upright,Cocktail;",
	"P1O[14:13],Coin A,1C 1C,1C 2C,2C 1C,2C 3C;",
	"P1O[16:15],Coin B,1C 1C,1C 2C,2C 1C,2C 3C;",
	"P1-;",

	"P1O[8:7],Difficulty,Medium,Easy,Hard,Hardest;",
	"P1O[18:17],Bonus Life,1500k,1000k,2000k,None;",
	"P1O[6:5],Lives,2,5,4,3;",

	"-;",
	"R[0],Reset;",

	"J1,Fire,Start,Coin;",
	"jn,A,Start,Select;",
	"V,v",`BUILD_DATE
};

wire [127:0] status;
wire   [1:0] buttons;
wire         forced_scandoubler;
wire  [21:0] gamma_bus;

wire  [31:0] joystick_0, joystick_1;
wire  [24:0] ps2_mouse;

wire         ioctl_download;
wire         ioctl_wr;
wire  [24:0] ioctl_addr;
wire   [7:0] ioctl_dout;
wire  [15:0] ioctl_index;
wire         ioctl_wait;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(gamma_bus),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask(16'd0),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.ioctl_wait(ioctl_wait),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),

	.ps2_mouse(ps2_mouse)
);

wire clk_sys;
wire clk_snd;
wire pll_locked;

reg        rst_pll     = 1'b0;
reg  [7:0] rst_pll_cnt = 8'd0;
reg        old_locked  = 1'b0;

pll pll
(
	.refclk(CLK_50M),
	.rst(rst_pll),
	.outclk_0(clk_sys),
	.outclk_1(clk_snd),
	.locked(pll_locked)
);

always @(posedge CLK_50M) begin
	old_locked <= pll_locked;
	if (old_locked && !pll_locked) begin
		rst_pll_cnt <= 8'hFF;
		rst_pll     <= 1'b1;
	end
	else if (rst_pll_cnt) rst_pll_cnt <= rst_pll_cnt - 1'b1;
	else                  rst_pll     <= 1'b0;
end

wire reset_async_sys = RESET | ~pll_locked;
wire reset_async     = reset_async_sys | status[0] | buttons[1];
wire reset_sys;
wire reset;

reset_ctrl reset_sys_ctrl
(
	.clk   (clk_sys),
	.rst_i (reset_async_sys),
	.rst_o (reset_sys)
);

reset_ctrl reset_game_ctrl
(
	.clk   (clk_sys),
	.rst_i (reset_async),
	.rst_o (reset)
);

wire m_fire1  = joystick_0[4] | ps2_mouse[0] | ps2_mouse[1];
wire m_start1 = joystick_0[5];
wire m_coin1  = joystick_0[6];

wire m_fire2  = joystick_1[4];
wire m_start2 = joystick_1[5];
wire m_coin2  = joystick_1[6];

wire [7:0] in0 = { ~m_start2, ~m_start1, 1'b1, ~status[4],
                    m_coin2,   m_coin1,  2'b11 };

wire [7:0] in1 = { 3'b111, ~m_fire1, 3'b111, ~m_fire2 };

wire [7:0] in2 = 8'hFF;

wire [1:0] coin_a_sw = ~status[14:13];
wire [1:0] coin_b_sw = ~status[16:15];

wire       cabinet_sw = status[12];

wire [7:0] dsw_a = { coin_b_sw, coin_a_sw,
                     ~status[10],
                     ~status[9],
                     ~status[11],
                     cabinet_sw };

wire [1:0] lives_sw = status[6:5];
wire [1:0] diff_sw  = ~status[8:7];
wire [1:0] bonus_sw = ~status[18:17];

wire [7:0] dsw_b = { 1'b1,
                     1'b0,
                     lives_sw,
                     bonus_sw,
                     diff_sw };

wire [12:0] sd_a;
wire  [1:0] sd_ba;
wire [15:0] sd_dq_out;
wire        sd_dq_oe;
wire        sd_dqml, sd_dqmh, sd_ncs, sd_nras, sd_ncas, sd_nwe, sd_cke;

wire        ce_pix;
wire        hs, vs, hb, vb;
wire  [7:0] r, g, b;
wire signed [15:0] audio_l, audio_r;

wire        rom_checked;

wire [31:0] rom_crc;

localparam [31:0] ROM_CRC_SYVALION  = 32'h7DAB81E9;
localparam [31:0] ROM_CRC_SYVALIONP = 32'h55A5C1AE;

wire tb_is_proto = rom_checked && (rom_crc == ROM_CRC_SYVALIONP);
wire tb_swap_xy  = tb_is_proto;
wire tb_neg_vert = tb_is_proto;

wire signed [7:0] tb1_x, tb1_y, tb2_x, tb2_y;
wire        [3:0] tb_taken;

trackball tb_p1 (
	.clk       (clk_sys),
	.reset     (reset),
	.ps2_mouse (ps2_mouse),
	.dp_up     (joystick_0[3]),
	.dp_down   (joystick_0[2]),
	.dp_left   (joystick_0[1]),
	.dp_right  (joystick_0[0]),
	.swap_xy   (tb_swap_xy),
	.neg_vert  (tb_neg_vert),
	.taken_px  (tb_taken[3]),
	.taken_py  (tb_taken[2]),
	.tb_x      (tb1_x),
	.tb_y      (tb1_y)
);

trackball tb_p2 (
	.clk       (clk_sys),
	.reset     (reset),
	.ps2_mouse (25'd0),
	.dp_up     (joystick_1[3]),
	.dp_down   (joystick_1[2]),
	.dp_left   (joystick_1[1]),
	.dp_right  (joystick_1[0]),
	.swap_xy   (tb_swap_xy),
	.neg_vert  (tb_neg_vert),
	.taken_px  (tb_taken[1]),
	.taken_py  (tb_taken[0]),
	.tb_x      (tb2_x),
	.tb_y      (tb2_y)
);

syvalion syvalion
(
	.clk_sys(clk_sys),
	.clk_snd(clk_snd),
	.reset_sys(reset_sys),
	.reset(reset),

	.fast_clk(1'b0),
	.test_pattern(1'b0),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.dsw_a(dsw_a),
	.dsw_b(dsw_b),
	.in0(in0),
	.in1(in1),
	.in2(in2),

	.tb1_x(tb1_x), .tb1_y(tb1_y),
	.tb2_x(tb2_x), .tb2_y(tb2_y),
	.tb_taken(tb_taken),

	.SDRAM_A(sd_a),
	.SDRAM_BA(sd_ba),
	.SDRAM_DQ_IN(SDRAM_DQ),
	.SDRAM_DQ_OUT(sd_dq_out),
	.SDRAM_DQ_OE(sd_dq_oe),
	.SDRAM_DQML(sd_dqml),
	.SDRAM_DQMH(sd_dqmh),
	.SDRAM_nCS(sd_ncs),
	.SDRAM_nRAS(sd_nras),
	.SDRAM_nCAS(sd_ncas),
	.SDRAM_nWE(sd_nwe),
	.SDRAM_CKE(sd_cke),
	.SDRAM_CLK(),

	.ce_pix(ce_pix),
	.hsync(hs),
	.vsync(vs),
	.hblank(hb),
	.vblank(vb),
	.red(r),
	.green(g),
	.blue(b),
	.audio_l(audio_l),
	.audio_r(audio_r),

	.dbg_rom_crc(rom_crc), .dbg_rom_checked(rom_checked), .dbg_rom_bytes(),
	.dbg_hcnt(), .dbg_vcnt(),
	.dbg_cpu_addr(), .dbg_cpu_as_n(), .dbg_cpu_rw_n(), .dbg_cpu_uds_n(),
	.dbg_cpu_lds_n(), .dbg_cpu_dout(), .dbg_cpu_din(), .dbg_cpu_cycles(),
	.dbg_cpu_frames(), .dbg_iack_cnt(),
	.dbg_coin_edge(),
	.dbg_syt_stub_rd(), .dbg_syt_cmd_cnt(), .dbg_syt_nmi_cnt(),
	.dbg_syt_reply_cnt(), .dbg_syt_poll_cnt(), .dbg_syt_reset_cnt(),
	.dbg_syt_nmi_en_cnt(),
	.dbg_snd_m1_cnt(), .dbg_snd_ym_cnt(), .dbg_snd_ym_irq(), .dbg_snd_ym_ta(),
	.dbg_snd_ym_prog(),
	.dbg_adpcm_fetch(), .dbg_adpcm_min(), .dbg_adpcm_roe(), .dbg_adpcm_under(),
	.dbg_adpcmb_fetch(), .dbg_adpcmb_under(),
	.dbg_p3_addr(), .dbg_p3_data(), .dbg_p3_ack(),
	.dbg_ym_ev(), .dbg_ym_ev_we(), .dbg_ym_ev_a(), .dbg_ym_ev_d(),
	.dbg_snd_pc(), .dbg_snd_bank(),
	.dbg_p2_stall(),
	.dbg_vco_ticks(), .dbg_vco_over(), .dbg_vco_zoom(), .dbg_vco_flip(),
	.dbg_vco_rowsc(), .dbg_vco_tilehi(), .dbg_vco_flip40(), .dbg_vco_flip80(),
	.dbg_vco_zoom0(), .dbg_vco_zoom1(), .dbg_vco_sprzoom()
);

assign SDRAM_DQ = sd_dq_oe ? sd_dq_out : 16'bZZZZZZZZZZZZZZZZ;

assign SDRAM_A    = sd_a;
assign SDRAM_BA   = sd_ba;
assign SDRAM_DQML = sd_dqml;
assign SDRAM_DQMH = sd_dqmh;
assign SDRAM_nCS  = sd_ncs;
assign SDRAM_nRAS = sd_nras;
assign SDRAM_nCAS = sd_ncas;
assign SDRAM_nWE  = sd_nwe;
assign SDRAM_CKE  = sd_cke;

altddio_out
#(
	.extend_oe_disable ("OFF"),
	.intended_device_family ("Cyclone V"),
	.invert_output ("OFF"),
	.lpm_hint ("UNUSED"),
	.lpm_type ("altddio_out"),
	.oe_reg ("UNREGISTERED"),
	.power_up_high ("OFF"),
	.width (1)
)
sdramclk_ddr
(
	.datain_h   (1'b0),
	.datain_l   (1'b1),
	.outclock   (clk_sys),
	.dataout    (SDRAM_CLK),
	.aclr       (1'b0),
	.aset       (1'b0),
	.oe         (1'b1),
	.outclocken (1'b1),
	.sclr       (1'b0),
	.sset       (1'b0)
);

wire [2:0] fx = (status[3:2] == 2'd0) ? 3'd0 : (3'd1 + {1'b0, status[3:2]});

arcade_video #(.WIDTH(512), .DW(24)) arcade_video
(
	.clk_video(clk_sys),
	.ce_pix(ce_pix),

	.RGB_in({r, g, b}),
	.HBlank(hb),
	.VBlank(vb),
	.HSync(hs),
	.VSync(vs),

	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(CE_PIXEL),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.VGA_DE(VGA_DE),
	.VGA_SL(VGA_SL),

	.fx(fx),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus)
);

wire [1:0] ar = status[122:121];
assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

wire [5:0] vol_num = 6'd12;

function automatic signed [15:0] vol_scale(input signed [15:0] s, input [5:0] n);
	reg signed [23:0] wide;
	begin
		wide = $signed(s) * $signed({1'b0, n});
		wide = wide >>> 2;
		if      (wide >  24'sd32767) vol_scale = 16'sh7FFF;
		else if (wide < -24'sd32768) vol_scale = 16'sh8000;
		else                         vol_scale = wide[15:0];
	end
endfunction

assign AUDIO_L = vol_scale(audio_l, vol_num);
assign AUDIO_R = vol_scale(audio_r, vol_num);
assign AUDIO_S = 1;

reg [26:0] heartbeat = 0;
always @(posedge clk_sys) heartbeat <= heartbeat + 1'b1;

wire rom_crc_ok = (rom_crc == ROM_CRC_SYVALION) ||
                  (rom_crc == ROM_CRC_SYVALIONP);

assign LED_USER  = ioctl_download | ~rom_checked;
assign LED_POWER = {1'b1, rom_checked ? 1'b1 : heartbeat[25]};
assign LED_DISK  = {1'b1, rom_checked ? (rom_crc_ok ? 1'b1 : heartbeat[23]) : 1'b0};

endmodule
