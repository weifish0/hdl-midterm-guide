// Lab 5 Practice — 8 x 4-bit RAM, 1 read + 1 write port, write-first, valid bits
`timescale 1ns/1ps
module lab5_practice (
    input  logic       clk,
    input  logic       rst,        // synchronous
    input  logic       we,
    input  logic [6:0] w_addr,
    input  logic [3:0] din,
    input  logic       re,
    input  logic [6:0] r_addr,
    output logic [3:0] dout,
    output logic [3:0] cnt_valid
);
    logic [3:0] memory [0:7];
    logic [7:0] valid;
    logic [2:0] wi, ri;            // mapped 3-bit indices

    // XOR folding: 7-bit address -> 3-bit index
    assign wi = w_addr[2:0] ^ w_addr[6:4] ^ w_addr[3:1];
    assign ri = r_addr[2:0] ^ r_addr[6:4] ^ r_addr[3:1];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int k = 0; k < 8; k++) memory[k] <= 4'd0;
            valid     <= 8'd0;
            cnt_valid <= 4'd0;
            dout      <= 4'd0;
        end else begin
            // ---- write port ----
            if (we) begin
                memory[wi] <= din;
                valid[wi]  <= 1'b1;
                if (!valid[wi]) cnt_valid <= cnt_valid + 4'd1;   // first write only
            end
            // ---- read port (registered) ----
            if (!re)                    dout <= 4'd0;
            else if (we && wi == ri)    dout <= din;             // write-first bypass
            else if (valid[ri])         dout <= memory[ri];
            else                        dout <= 4'd0;
        end
    end
endmodule
