/* This file is part of JT12.

    JT12 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT12 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT12.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 21-03-2019
*/

module jt10(
    input           rst,
    input           clk,
    input           cen,
    input   [7:0]   din,
    input   [1:0]   addr,
    input           cs_n,
    input           wr_n,

    output  [7:0]   dout,
    output          irq_n,
    output  [19:0]  adpcma_addr,
    output  [3:0]   adpcma_bank,
    output          adpcma_roe_n,
    input   [7:0]   adpcma_data,
    output  [23:0]  adpcmb_addr,
    output          adpcmb_roe_n,
    input   [7:0]   adpcmb_data,
    output          [ 7:0] psg_A,
    output          [ 7:0] psg_B,
    output          [ 7:0] psg_C,
    output  signed  [15:0] fm_snd,
    output          [ 9:0] psg_snd,
    output  signed  [15:0] snd_right,
    output  signed  [15:0] snd_left,
    output          snd_sample,
    input           [ 5:0] ch_enable
);

jt12_top #(
    .use_lfo(1),.use_ssg(1), .num_ch(6), .use_pcm(0), .use_adpcm(1),
    .JT49_DIV(3) )
u_jt12(
    .rst            ( rst          ),
    .clk            ( clk          ),
    .cen            ( cen          ),
    .din            ( din          ),
    .addr           ( addr         ),
    .cs_n           ( cs_n         ),
    .wr_n           ( wr_n         ),

    .dout           ( dout         ),
    .irq_n          ( irq_n        ),
    .adpcma_addr    ( adpcma_addr  ),
    .adpcma_bank    ( adpcma_bank  ),
    .adpcma_roe_n   ( adpcma_roe_n ),
    .adpcma_data    ( adpcma_data  ),
    .adpcmb_addr    ( adpcmb_addr  ),
    .adpcmb_roe_n   ( adpcmb_roe_n ),
    .adpcmb_data    ( adpcmb_data  ),
    .psg_A          ( psg_A        ),
    .psg_B          ( psg_B        ),
    .psg_C          ( psg_C        ),
    .psg_snd        ( psg_snd      ),
    .fm_snd_left    ( fm_snd       ),
    .fm_snd_right   (              ),
    .adpcmA_l       (              ),
    .adpcmA_r       (              ),
    .adpcmB_l       (              ),
    .adpcmB_r       (              ),
    .IOA_in         ( 8'b0          ),
    .IOB_in         ( 8'b0          ),
    .IOA_out        (               ),
    .IOB_out        (               ),
    .IOA_oe         (               ),
    .IOB_oe         (               ),
    .debug_bus      ( 8'd0          ),
    .snd_right      ( snd_right    ),
    .snd_left       ( snd_left     ),
    .snd_sample     ( snd_sample   ),
    .ch_enable      ( ch_enable    ),
    .en_hifi_pcm    ( 1'b0         ),
    .debug_view     (              )
);

endmodule
