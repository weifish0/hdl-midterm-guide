// Mock Exam Problem A — Synchronous signed ALU (reference solution)
`timescale 1ns/1ps
module mock_A (
    input  logic               clk,
    input  logic               rst,     // synchronous, active-high
    input  logic signed [7:0]  A,
    input  logic signed [7:0]  B,
    input  logic        [1:0]  ctrl,
    output logic signed [15:0] out
);
    logic signed [15:0] result;
    logic signed [8:0]  diff;           // A - B needs 9 bits

    always_comb begin
        diff = A - B;
        case (ctrl)
            2'b00:   result = A * A - B;                    // 16-bit signed context
            2'b01:   result = {A | B, ~(A & B)};            // OR ++ NAND
            2'b10:   result = diff[8] ? -diff : diff;       // |A - B| (0..255)
            default: result = A >>> B[2:0];                 // arithmetic shift by 0..7
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) out <= '0;
        else     out <= result;
    end
endmodule
