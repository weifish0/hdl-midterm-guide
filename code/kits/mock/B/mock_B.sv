// <Student_ID> <Name>
// Add your ID and name to the FIRST line of the file, or you will get a 5-point penalty
`timescale 1ns/1ps

module mock_B (
    input  logic       clk,
    input  logic       rst,
    input  logic       valid,
    input  logic [1:0] op,
    input  logic [7:0] data,
    output logic [7:0] out,
    output logic [3:0] cnt,
    output logic       err
);
    logic [7:0] mem [0:7];

endmodule
