// 2022 Exam1 Problem A — Synchronous ALU (SystemVerilog reference solution)
`timescale 1ns/1ps
module exam1_A (
    input  logic               clk,
    input  logic               rst,     // synchronous, active-high
    input  logic signed [7:0]  A,
    input  logic signed [7:0]  B,
    input  logic        [1:0]  ctrl,
    output logic signed [15:0] out
);
    logic signed [15:0] result;

    always_comb begin
        case (ctrl)
            // -B is evaluated in the 16-bit context, so B = -128 becomes +128
            // correctly (in 8 bits, -(-128) would overflow back to -128!)
            2'b00:   result = A * (-B);
            2'b01:   result = {A ^ B, ~(A | B)};          // xor ++ nor
            2'b11:   result = A + B;
            default: result = (A < B) ? -16'sd1 : 16'sd1; // both signed -> signed compare
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) out <= '0;
        else     out <= result;
    end
endmodule
