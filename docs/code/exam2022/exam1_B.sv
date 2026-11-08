// 2022 Exam1 Problem B — Fibonacci-like up/down counter (SystemVerilog reference solution)
// No "/" in count-up and no "%" in count-down: use shifts and bit slices instead.
`timescale 1ns/1ps
module exam1_B (
    input  logic        clk,
    input  logic        rst,      // synchronous, active-high
    output logic [15:0] out       // c_i (current value)
);
    localparam logic [15:0] TOP = 16'd65176;

    logic        up;
    logic [15:0] prev;            // c_(i-1)
    logic [15:0] i;
    logic [16:0] S;               // c_(i-1) + c_i  (needs 17 bits!)
    logic [16:0] nxt;             // c_(i+1), one extra bit for the sign check
    logic [16:0] six_i;

    assign S     = prev + out;
    assign six_i = (i << 2) + (i << 1);          // 6*i = 4i + 2i

    always_comb begin
        if (up) begin
            if (S[1:0] == 2'b00)                   // S % 4 == 0
                nxt = (S < 17'd16384) ? (S >> 1) + ((S >> 1) << 1)   // (S/2)*3
                                      : out + i;
            else
                nxt = i[0] ? out + 16'd4 : out + 16'd1;           // i odd / even
        end else begin
            if (S[2:0] == i[2:0])                   // S % 8 == i % 8
                nxt = out >> i[1:0];                // c_i >> (i % 4)
            else if (out < six_i)                   // would become negative
                nxt = 17'd0;
            else
                nxt = out - six_i;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            // reset to 0; the "restart" branch below makes the next value 1
            out <= 16'd0; prev <= 16'd0; i <= 16'd1; up <= 1'b1;
        end else if (up && out == 16'd0) begin   // restart: c0 = 0, c1 = 1
            out <= 16'd1; prev <= 16'd0; i <= 16'd1;
        end else begin
            prev <= out;
            out  <= nxt[15:0];
            if (up && nxt[15:0] == TOP) begin     // reached the top -> count down
                up <= 1'b0; i <= 16'd1;           // down: c0 = 64752, c1 = 65176
            end else if (!up && nxt[15:0] == 16'd0) begin
                up <= 1'b1; i <= 16'd1;           // finished counting down
            end else begin
                i <= i + 16'd1;
            end
        end
    end
endmodule
