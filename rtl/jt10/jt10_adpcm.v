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

module jt10_adpcm(
    input           rst_n,
    input           clk,
    input           cen,
    input   [3:0]   data,
    input           chon,
    input           clr,
    output signed [15:0] pcm
);

localparam sigw = 12;

reg signed [sigw-1:0] x1, x2, x3, x4, x5, x6;
reg signed [sigw:0]   inc4;
reg [5:0] step1, step2, step6, step3, step4, step5;
reg [5:0] step_next, step_1p;
reg       sign2, sign3, sign4, sign5, xsign5;

assign pcm = { {16-sigw{x1[sigw-1]}}, x1 };

always @(*) begin
    casez( data[2:0] )
        3'b0??: step_next = step1==6'd0 ? 6'd0 : (step1-1'd1);
        3'b100: step_next = step1+6'd2;
        3'b101: step_next = step1+6'd5;
        3'b110: step_next = step1+6'd7;
        3'b111: step_next = step1+6'd9;
    endcase
    step_1p = step_next > 6'd48 ? 6'd48 : step_next;
end

//================================================================
// LOCAL MODIFICATION - second edit to vendored jt10. See rtl/VENDOR.txt.
//
// THE INCREMENT NEEDS 13 BITS, NOT 12. The LUT is correct - all 392 entries
// match ymfm's (2*(data&7)+1) * s_steps[step] / 8 exactly, checked - and it
// holds values up to 2910. But inc4 below is `signed [sigw-1:0]` with sigw=12,
// and 12-bit SIGNED tops out at 2047. Eight of the 392 deltas exceed that, so
// they are stored as NEGATIVE numbers: +2910 is added as -1186.
//
//   step=45 d=7  2186 -> -1910      step=47 d=6  2292 -> -1804
//   step=46 d=6  2083 -> -2013      step=47 d=7  2645 -> -1451
//   step=46 d=7  2403 -> -1693      step=48 d=5  2134 -> -1962
//                                   step=48 d=6  2522 -> -1574
//                                   step=48 d=7  2910 -> -1186
//
// This looks like an upstream regression rather than a design choice: the LUT's
// superseded values, still present in comments, are all 12'o3777 = 2047, i.e.
// deliberately clamped to fit 12-bit signed. Someone replaced them with the
// accurate values and did not widen the path that carries them.
//
// Steps 45-48 are the top of the adaptation range, reached only in loud,
// rapidly-changing passages, and ADPCM is DIFFERENTIAL so a sign-flipped delta
// corrupts the accumulator from that point on. Quiet audio decodes perfectly.
// That is exactly the reported symptom: a recognisable sound whose loud moments
// break up.
//
// sigw stays 12 - the ACCUMULATOR is 12-bit and wraps, which is correct and
// matches ymfm's `m_accumulator = (m_accumulator + delta) & 0xfff`. Only the
// increment widens. x5 is [sigw-1:0], so the sum still truncates to 12 bits and
// the wrap is preserved.
//================================================================
wire [11:0] inc3;
reg [8:0] lut_addr2;

jt10_adpcma_lut u_lut(
    .clk    ( clk        ),
    .rst_n  ( rst_n      ),
    .cen    ( cen        ),
    .addr   ( lut_addr2  ),
    .inc    ( inc3       )
);

reg chon2, chon3, chon4;
wire signed [sigw:0] inc3_long = { {sigw+1-12{1'b0}}, inc3 };

always @( posedge clk or negedge rst_n )
    if( ! rst_n ) begin
        x1 <= 'd0; step1 <= 0;
        x2 <= 'd0; step2 <= 0;
        x3 <= 'd0; step3 <= 0;
        x4 <= 'd0; step4 <= 0;
        x5 <= 'd0; step5 <= 0;
        x6 <= 'd0; step6 <= 0;
        sign2 <= 'b0;
        chon2 <= 'b0;   chon3 <= 'b0; chon4 <= 'b0;
        lut_addr2 <= 'd0;
        inc4 <= 'd0;
    end else if(cen) begin
        sign2     <= data[3];
        x2        <= clr ? {sigw{1'b0}} : x1;
        step2     <= clr ? 6'd0 : (chon ? step_1p : step1);
        chon2     <= ~clr && chon;
        lut_addr2 <= { step1, data[2:0] };
        sign3     <= sign2;
        x3        <= x2;
        step3     <= step2;
        chon3     <= chon2;
        inc4      <= sign3 ? ~inc3_long + 1'd1 : inc3_long;
        x4        <= x3;
        step4     <= step3;
        chon4     <= chon3;
        x5        <= chon4 ? x4 + inc4 : x4;
        step5     <= step4;
        x6        <= x5;
        step6     <= step5;
        x1        <= x6;
        step1     <= step6;
    end

endmodule
