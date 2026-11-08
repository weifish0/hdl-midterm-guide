// Lab 1 Practice 1 — function selector with a gate-level 2-to-1 MUX
`timescale 1ns/100ps
module practice_1 (
    input  wire A,
    input  wire B,
    input  wire C,
    output wire out
);
    wire and_ab, or_ab;
    and g_and (and_ab, A, B);          // primitive: output first, then inputs
    or  g_or  (or_ab,  A, B);
    mux u_mux (.a(and_ab), .b(or_ab), .c(C), .y(out));   // C=0 -> AND, C=1 -> OR
endmodule

module mux (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire y
);
    wire c_n, t0, t1;
    not g0 (c_n, c);
    and g1 (t0, a, c_n);    // a & ~c
    and g2 (t1, b, c);      // b &  c
    or  g3 (y, t0, t1);
endmodule
