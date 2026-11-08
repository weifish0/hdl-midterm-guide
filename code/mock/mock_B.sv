// Mock Exam Problem B — 8-entry stack (LIFO) built on a memory array (reference solution)
//   op = 00 PUSH : if not full, mem[sp] <= data, sp++     out <= data       (full: out <= 0)
//   op = 01 POP  : if not empty, sp--, out <= mem[sp-1]                     (empty: out <= 0)
//   op = 10 PEEK : out <= top element (empty: 0), stack unchanged
//   op = 11 SUM  : out <= sum of all stored elements (mod 256), stack unchanged
//   valid = 0    : nothing happens, out <= 0
//   cnt  = number of stored elements (0..8), err = 1 for one cycle on push-full / pop-empty
`timescale 1ns/1ps
module mock_B (
    input  logic       clk,
    input  logic       rst,      // synchronous, active-high
    input  logic       valid,
    input  logic [1:0] op,
    input  logic [7:0] data,
    output logic [7:0] out,
    output logic [3:0] cnt,
    output logic       err
);
    logic [7:0] mem [0:7];
    logic [7:0] sum;

    // combinational sum of the valid entries (a for-loop is just 8 adders in hardware)
    always_comb begin
        sum = 8'd0;
        for (int k = 0; k < 8; k++)
            if (k < cnt) sum = sum + mem[k];
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int k = 0; k < 8; k++) mem[k] <= 8'd0;
            cnt <= 4'd0; out <= 8'd0; err <= 1'b0;
        end else begin
            err <= 1'b0;
            out <= 8'd0;
            if (valid) begin
                case (op)
                    2'b00: if (cnt != 4'd8) begin
                               mem[cnt[2:0]] <= data;
                               cnt <= cnt + 4'd1;
                               out <= data;
                           end else err <= 1'b1;
                    2'b01: if (cnt != 4'd0) begin
                               out <= mem[cnt[2:0] - 3'd1];
                               cnt <= cnt - 4'd1;
                           end else err <= 1'b1;
                    2'b10: if (cnt != 4'd0) out <= mem[cnt[2:0] - 3'd1];
                    2'b11: out <= sum;
                endcase
            end
        end
    end
endmodule
