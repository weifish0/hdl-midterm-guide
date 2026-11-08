// Lab 1 Practice 2 — gated D latch, gate level only (NAND version)
`timescale 1ns/100ps
module practice_2 (
    input  logic G,
    input  logic D,
    output logic P,
    output logic Pn
);
    logic D_n, s_n, r_n;
    not  g0 (D_n, D);
    nand g1 (s_n, D,   G);   // set   (active low) when G=1 and D=1
    nand g2 (r_n, D_n, G);   // reset (active low) when G=1 and D=0
    nand g3 (P,  s_n, Pn);   // cross-coupled NAND = SR latch
    nand g4 (Pn, r_n, P);
endmodule
