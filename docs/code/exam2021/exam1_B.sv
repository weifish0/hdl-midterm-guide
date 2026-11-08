// 2021 Exam1 Problem B — up/down "rule" counter (SystemVerilog reference solution)
`timescale 1ns/1ps
module exam1_B (
    input  logic        clk,
    input  logic        rst,      // synchronous, active-high
    output logic [19:0] result
);
    localparam logic [19:0] MAX = 20'd183921;

    logic        up;      // 1: counting up, 0: counting down
    logic [19:0] i;       // the i-th step inside the current direction (starts at 1)
    logic [19:0] next_val;

    // next value for the up direction  (S % 8 == i % 8  <=>  S[2:0] == i[2:0])
    always_comb begin
        if (result[2:0] == i[2:0]) next_val = result + (i << 1) + i;  // + 3i
        else                       next_val = result + i;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            result <= 20'd0;
            i      <= 20'd1;
            up     <= 1'b1;
        end else if (up) begin
            result <= next_val;
            if (next_val >= MAX) begin   // reached the top: next step counts down
                up <= 1'b0;
                i  <= 20'd1;
            end else begin
                i  <= i + 20'd1;
            end
        end else begin                   // counting down: S <- S - i
            if (result <= i) begin       // would reach (or pass) 0
                result <= 20'd0;
                up     <= 1'b1;
                i      <= 20'd1;
            end else begin
                result <= result - i;
                i      <= i + 20'd1;
            end
        end
    end
endmodule
