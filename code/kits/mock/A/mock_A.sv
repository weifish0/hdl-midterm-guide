// <Student_ID> <Name>
// Add your ID and name to the FIRST line of the file, or you will get a 5-point penalty
`timescale 1ns/1ps

module mock_A (
    input  logic               clk,
    input  logic               rst,
    input  logic signed [7:0]  A,
    input  logic signed [7:0]  B,
    input  logic        [1:0]  ctrl,
    output logic signed [15:0] out
);

endmodule
