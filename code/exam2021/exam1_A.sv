// 2021 Exam1 Problem A — Synchronous ALU (SystemVerilog reference solution)
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
            2'b00:   result = A * B;           // signed x signed -> 16-bit context
            2'b10:   result = {A & B, A | B};  // concatenation (8 + 8 bits)
            2'b11:   result = A >>> 3;         // arithmetic shift keeps the sign
            default: result = A - B;           // 2'b01
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) out <= '0;
        else     out <= result;
    end
endmodule
