// 2023 Exam1 Problem B — Hamming(12,8) single-error correction + tiny ALU
`timescale 1ns/1ps
module exam1_B (
    input  logic        clk,
    input  logic        rst,            // synchronous, active-high
    input  logic [11:0] data,           // data[0] = B1 ... data[11] = B12
    output logic [7:0]  decoded,
    output logic [2:0]  out
);
    logic [3:0]  syndrome;              // {c4, c3, c2, c1}
    logic [11:0] fixed;                 // corrected code word
    logic [7:0]  dec_c;                 // combinational decoded data
    logic [2:0]  out_c;                 // combinational final output

    always_comb begin
        // B(k) is data[k-1]
        syndrome[0] = data[0] ^ data[2] ^ data[4] ^ data[6] ^ data[8] ^ data[10]; // c1: B1 B3 B5 B7 B9 B11
        syndrome[1] = data[1] ^ data[2] ^ data[5] ^ data[6] ^ data[9] ^ data[10]; // c2: B2 B3 B6 B7 B10 B11
        syndrome[2] = data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[11];           // c3: B4 B5 B6 B7 B12
        syndrome[3] = data[7] ^ data[8] ^ data[9] ^ data[10] ^ data[11];          // c4: B8 B9 B10 B11 B12

        // The syndrome IS the position of the wrong bit (1..12); 0 = no error
        fixed = data;
        if (syndrome != 4'd0 && syndrome <= 4'd12)
            fixed[syndrome - 4'd1] = ~data[syndrome - 4'd1];

        // drop r1(B1) r2(B2) r3(B4) r4(B8): keep d8..d1 = B12 B11 B10 B9 B7 B6 B5 B3
        dec_c = {fixed[11], fixed[10], fixed[9], fixed[8],
                 fixed[6],  fixed[5],  fixed[4], fixed[2]};

        // request = dec[7:6], a = dec[5:3], b = dec[2:0]
        case (dec_c[7:6])
            2'b00: out_c = dec_c[5:3] & dec_c[2:0];
            2'b01: out_c = dec_c[5:3] | dec_c[2:0];
            2'b10: out_c = dec_c[5:3];
            2'b11: out_c = dec_c[2:0];
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            decoded <= 8'd0;
            out     <= 3'd0;
        end else begin
            decoded <= dec_c;
            out     <= out_c;
        end
    end
endmodule
