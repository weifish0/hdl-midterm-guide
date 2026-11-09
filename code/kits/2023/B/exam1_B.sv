// <Student_ID> <Name>
// Add your ID and name to the FIRST line of the file, or you will get a 5-point penalty
`timescale 1ns/1ps

`define WIDTH 12

module exam1_B (
    input  logic clk,
    input  logic rst,
    input  logic [`WIDTH-1:0] data,
    output logic [7:0] decoded,
    output logic [2:0] out
);

endmodule
