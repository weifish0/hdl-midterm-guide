// 2023 Exam1 Problem A — Synchronous ALU (SystemVerilog reference solution)
`timescale 1ns/1ps
module exam1_A (
    input  logic              clk,
    input  logic              rst,      // synchronous, active-high
    input  logic signed [7:0] A,
    input  logic signed [7:0] B,
    input  logic        [1:0] ctrl,
    output logic signed [15:0] out
);
    logic signed [15:0] result;   // combinational result (next value of out)

    // 1) Combinational part: compute the answer for the CURRENT inputs
    always_comb begin
        case (ctrl)
            // A*B+3 : every operand is signed, so the whole expression is
            // sign-extended to the 16-bit context before multiplying.
            2'b00:   result = A * B + 16'sd3;
            // {A&B, A^B}: a concatenation is just bits (8 + 8 = 16 bits)
            2'b01:   result = {A & B, A ^ B};
            // (A+B)<<2 : evaluated in 16 bits, so no overflow of the 8-bit sum
            2'b11:   result = (A + B) <<< 2;
            // A/4 > B without "/" : arithmetic right shift by 2 keeps the sign
            default: result = ((A >>> 2) > B) ? 16'sd1 : -16'sd1;
        endcase
    end

    // 2) Sequential part: one flip-flop in front of the output port
    always_ff @(posedge clk) begin
        if (rst) out <= 16'sd0;     // synchronous reset -> only at the clock edge
        else     out <= result;
    end
endmodule
