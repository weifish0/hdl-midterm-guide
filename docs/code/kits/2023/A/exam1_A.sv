// <Student_ID> <Name>
// Add your ID and name to the FIRST line of the file, or you will get a 5-point penalty
`timescale 1ns/1ps

`define WIDTH 8

module exam1_A (
    input  logic clk,
    input  logic rst,
    input  logic [`WIDTH-1:0] A,
    input  logic [`WIDTH-1:0] B,
    input  logic [1:0] ctrl,
    output logic [`WIDTH*2-1:0] out
);
    // Hint: declare signals as "signed" to get signed operations, e.g.
    //   logic signed [7:0] data;

endmodule
