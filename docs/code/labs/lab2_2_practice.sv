// Lab 2 Practice 2 — loadable down counter with a one-cycle "done" flag
`timescale 1ns/1ps
module lab2_2_practice (
    input  logic       clk,
    input  logic       rst,    // synchronous
    input  logic       load,
    input  logic [7:0] N,
    output logic [7:0] out,
    output logic       done
);
    always_ff @(posedge clk) begin
        if (rst) begin
            out  <= 8'd0;
            done <= 1'b0;
        end else if (load) begin
            out  <= N;
            done <= 1'b0;
        end else if (out != 8'd0) begin
            out  <= out - 8'd1;
            done <= (out == 8'd1);      // we are about to reach 0
        end else begin
            done <= 1'b0;
        end
    end
endmodule
