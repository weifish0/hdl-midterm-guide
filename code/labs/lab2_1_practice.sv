// Lab 2 Practice 1 — registered 8-bit signed SATURATING adder
`timescale 1ns/1ps
module lab2_1_practice (
    input  logic              clk,
    input  logic              rst,     // synchronous
    input  logic signed [7:0] A,
    input  logic signed [7:0] B,
    output logic signed [7:0] out
);
    logic signed [8:0] sum;            // one extra bit: never overflows
    logic signed [7:0] sat;

    always_comb begin
        sum = A + B;                   // 9-bit context -> both operands sign-extended
        if      (sum >  9'sd127)  sat = 8'sd127;
        else if (sum < -9'sd128)  sat = -8'sd128;
        else                      sat = sum[7:0];
    end

    always_ff @(posedge clk) begin
        if (rst) out <= '0;
        else     out <= sat;
    end
endmodule
