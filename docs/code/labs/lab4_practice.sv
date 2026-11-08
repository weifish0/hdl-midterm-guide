// Lab 4 Practice — direction game: 4-bit LFSR + one FSM
`timescale 1ns/1ps
module lab4_basic (
    input  logic        clk,
    input  logic        rst,     // asynchronous, active-high (BTNC)
    input  logic        btnL,
    input  logic        btnR,
    input  logic        btnD,
    input  logic        btnU,
    output logic [15:0] LED
);
    typedef enum logic [1:0] {INIT, PLAY, FINAL} state_t;
    state_t state;

    // ---- every button -> one clean pulse ----
    logic pL, pR, pD, pU;
    btn_pulse u_l (.clk, .rst, .btn(btnL), .pulse(pL));
    btn_pulse u_r (.clk, .rst, .btn(btnR), .pulse(pR));
    btn_pulse u_d (.clk, .rst, .btn(btnD), .pulse(pD));
    btn_pulse u_u (.clk, .rst, .btn(btnU), .pulse(pU));

    // ---- 4-bit LFSR: shift left, feedback = lfsr[3] ^ lfsr[0]  (0001 -> 0011 -> 0111 ...) ----
    logic [3:0] lfsr, lfsr_next;
    assign lfsr_next = {lfsr[2:0], lfsr[3] ^ lfsr[0]};

    // ---- which button was pressed (Left 00, Right 01, Down 10, Up 11) ----
    logic       any_p;
    logic [1:0] code;
    assign any_p = pL | pR | pD | pU;
    always_comb begin
        if      (pL) code = 2'b00;
        else if (pR) code = 2'b01;
        else if (pD) code = 2'b10;
        else         code = 2'b11;
    end

    // ---- 3-second timer in FINAL ----
    parameter ONE_SEC = 27'd100_000_000;
    logic [26:0] sec_cnt;
    logic [1:0]  secs;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT; lfsr <= 4'b0001; sec_cnt <= '0; secs <= '0;
        end else begin
            case (state)
                INIT: begin
                    if (pR)      lfsr  <= lfsr_next;            // pick the starting state
                    else if (pU) state <= PLAY;
                end
                PLAY: begin
                    if (any_p) begin
                        if (code == lfsr[1:0]) lfsr  <= lfsr_next;  // correct -> next round
                        else                   state <= FINAL;      // wrong -> game over
                    end
                    sec_cnt <= '0; secs <= '0;
                end
                FINAL: begin
                    if (sec_cnt == ONE_SEC - 1) begin
                        sec_cnt <= '0;
                        if (secs == 2'd2) begin                // 3 seconds have passed
                            state <= INIT; lfsr <= 4'b0001; secs <= '0;
                        end else secs <= secs + 2'd1;
                    end else sec_cnt <= sec_cnt + 27'd1;
                end
                default: state <= INIT;
            endcase
        end
    end

    always_comb begin
        case (state)
            INIT:    LED = {9'b0, 2'b00,     1'b0, lfsr};
            PLAY:    LED = {9'b0, lfsr[1:0], 1'b0, lfsr};
            default: LED = 16'hFFFF;
        endcase
    end
endmodule

module btn_pulse #(parameter int DB = 16) (
    input logic clk, input logic rst, input logic btn, output logic pulse
);
    logic [DB-1:0] div;
    logic [3:0]    samples;
    logic          stable, stable_d;
    assign stable = &samples;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin div <= '0; samples <= '0; stable_d <= 1'b0; end
        else begin
            div <= div + 1'b1;
            if (div == '0) samples <= {samples[2:0], btn};
            stable_d <= stable;
        end
    end
    assign pulse = stable & ~stable_d;
endmodule
