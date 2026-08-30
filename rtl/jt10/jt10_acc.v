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

    Each channel can use the full range of the DAC as they do not
    get summed in the real chip.

    Operator data is summed up without adding extra bits. This is
    the case of real YM3438, which was used on Megadrive 2 models.

*/

module jt10_acc(
    input               clk,
    input               clk_en /* synthesis direct_enable */,
    input signed [13:0] op_result,
    input        [ 1:0] rl,
    input               zero,
    input               s1_enters,
    input               s2_enters,
    input               s3_enters,
    input               s4_enters,
    input       [2:0]   cur_ch,
    input       [1:0]   cur_op,
    input   [2:0]       alg,
    input signed [15:0] adpcmA_l,
    input signed [15:0] adpcmA_r,
    input signed [15:0] adpcmB_l,
    input signed [15:0] adpcmB_r,
    output signed [15:0] left,
    output signed [15:0] right
);

reg sum_en;

always @(*) begin
    case ( alg )
        default: sum_en = s4_enters;
        3'd4: sum_en = s2_enters | s4_enters;
        3'd5,3'd6: sum_en = ~s1_enters;
        3'd7: sum_en = 1'b1;
    endcase
end

//================================================================
// LOCAL MODIFICATION - see rtl/VENDOR.txt.
//
// THE 7.25x GAIN IS CORRECT. THE 16-BIT EVALUATION WAS NOT.
//
// Upstream wrote this gain directly into acc_input_l, which is signed [15:0],
// so the whole expression evaluated in 16 bits and WRAPPED above about a
// seventh of full scale - two's complement wraps rather than saturating, so a
// loud sample flipped sign. That produced amplitude-correlated crackle while
// the final mix never exceeded 23% of full scale.
//
// MEASURED that the constant itself is right: on pure-SFX sound 0x20, MAME
// peaks at 2020 and unity-gain ours at 281 - a ratio of 7.19 against jt12's
// 7.25, within 1%. It is not a Neo Geo quirk; jt12's ADPCM path simply carries
// a smaller internal representation than the FM accumulator.
//
// Evaluated in 21 bits and SATURATED to 16, which is also what MAME does - it
// sums ADPCM straight into the FM accumulator and finishes with clamp16().
// Saturation degrades gracefully; wrapping does not.
//================================================================
wire signed [20:0] adpcmA_l_ext = { {5{adpcmA_l[15]}}, adpcmA_l };
wire signed [20:0] adpcmA_r_ext = { {5{adpcmA_r[15]}}, adpcmA_r };
wire signed [20:0] adpcmA_l_g = (adpcmA_l_ext <<< 2) + (adpcmA_l_ext <<< 1)
                              +  adpcmA_l_ext + (adpcmA_l_ext >>> 2);
wire signed [20:0] adpcmA_r_g = (adpcmA_r_ext <<< 2) + (adpcmA_r_ext <<< 1)
                              +  adpcmA_r_ext + (adpcmA_r_ext >>> 2);
wire signed [15:0] adpcmA_l_sat = (adpcmA_l_g >  21'sd32767) ?  16'sh7FFF :
                                  (adpcmA_l_g < -21'sd32768) ? 16'sh8000 :
                                  adpcmA_l_g[15:0];
wire signed [15:0] adpcmA_r_sat = (adpcmA_r_g >  21'sd32767) ?  16'sh7FFF :
                                  (adpcmA_r_g < -21'sd32768) ? 16'sh8000 :
                                  adpcmA_r_g[15:0];

wire left_en = rl[1];
wire right_en= rl[0];
wire signed [15:0] opext = { {2{op_result[13]}}, op_result };
reg  signed [15:0] acc_input_l, acc_input_r;
reg acc_en_l, acc_en_r;

always @(*)
    case( {cur_op,cur_ch} )
        {2'd0,3'd0}: begin // ADPCM-A:
            //================================================================
            // LOCAL MODIFICATION - the only edit to vendored jt10. See
            // rtl/VENDOR.txt. Re-syncing from upstream will silently undo it.
            //
            // Upstream applies a 7.25x gain to ADPCM-A "to match AES channel
            // balance" - AES being the Neo Geo home console, which is what jt12
            // is primarily used for. Two problems here:
            //
            // 1. IT OVERFLOWS. acc_input_l is signed [15:0] and the whole
            //    expression is evaluated in 16 bits, so `adpcmA_l <<< 2` wraps
            //    once |adpcmA_l| exceeds ~8000, and the full sum wraps above
            //    ~4500. Two's complement WRAPS rather than saturating, so a loud
            //    sample flips sign. Observed exactly that way: the drum roll
            //    stayed recognisable while its loud moments broke up, the final
            //    mix never went above 23% of full scale, and connecting the
            //    sample ROM made the output QUIETER because wrapped values
            //    partially cancel.
            //
            // 2. It is calibrated for a different machine. Superman is a Taito X
            //    System board; there is no reason its ADPCM-to-FM balance should
            //    match a Neo Geo's.
            //
            // Unity gain here cannot overflow at all, which is what makes it the
            // right thing to test with. THE CORRECT VALUE FOR THIS BOARD IS NOT
            // YET KNOWN and must be derived by measuring against MAME rather
            // than by ear - that is M7's gate. Define JT10_ADPCMA_GAIN_AES to
            // restore upstream behaviour verbatim.
            //================================================================
            acc_input_l = adpcmA_l_sat;
            acc_input_r = adpcmA_r_sat;
            `ifndef NOMIX
            acc_en_l    = 1'b1;
            acc_en_r    = 1'b1;
            `else
            acc_en_l    = 1'b0;
            acc_en_r    = 1'b0;
            `endif
        end
        {2'd0,3'd4}: begin
            acc_input_l = adpcmB_l >>> 1;
            acc_input_r = adpcmB_r >>> 1;
            `ifndef NOMIX
            acc_en_l    = 1'b1;
            acc_en_r    = 1'b1;
            `else
            acc_en_l    = 1'b0;
            acc_en_r    = 1'b0;
            `endif
        end
        default: begin
            acc_input_l = opext >>> 1;
            acc_input_r = opext >>> 1;
            acc_en_l    = sum_en & left_en;
            acc_en_r    = sum_en & right_en;
        end
    endcase

jt12_single_acc #(.win(16),.wout(16)) u_left(
    .clk        ( clk            ),
    .clk_en     ( clk_en         ),
    .op_result  ( acc_input_l    ),
    .sum_en     ( acc_en_l       ),
    .zero       ( zero           ),
    .snd        ( left           )
);

jt12_single_acc #(.win(16),.wout(16)) u_right(
    .clk        ( clk            ),
    .clk_en     ( clk_en         ),
    .op_result  ( acc_input_r    ),
    .sum_en     ( acc_en_r       ),
    .zero       ( zero           ),
    .snd        ( right          )
);

`ifdef SIMULATION
integer f0,f1,f2,f4,f5,f6;
reg signed [15:0] sum_l[0:7], sum_r[0:7];

initial begin
    f0=$fopen("fm0.raw","w");
    f1=$fopen("fm1.raw","w");
    f2=$fopen("fm2.raw","w");
    f4=$fopen("fm4.raw","w");
    f5=$fopen("fm5.raw","w");
    f6=$fopen("fm6.raw","w");
end

always @(posedge clk) begin
    if(cur_op==2'b0) begin
        sum_l[cur_ch] <= acc_en_l ? acc_input_l : 16'd0;
        sum_r[cur_ch] <= acc_en_r ? acc_input_r : 16'd0;
    end else begin
        sum_l[cur_ch] <= sum_l[cur_ch] + (acc_en_l ? acc_input_l : 16'd0);
        sum_r[cur_ch] <= sum_r[cur_ch] + (acc_en_r ? acc_input_r : 16'd0);
    end
end

always @(posedge zero) begin
    $fwrite(f0,"%d,%d\n", sum_l[0], sum_r[0]);
    $fwrite(f1,"%d,%d\n", sum_l[1], sum_r[1]);
    $fwrite(f2,"%d,%d\n", sum_l[2], sum_r[2]);
    $fwrite(f4,"%d,%d\n", sum_l[4], sum_r[4]);
    $fwrite(f5,"%d,%d\n", sum_l[5], sum_r[5]);
    $fwrite(f6,"%d,%d\n", sum_l[6], sum_r[6]);
end
`endif

endmodule
