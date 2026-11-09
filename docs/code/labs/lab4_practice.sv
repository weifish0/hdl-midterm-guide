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

    // ---- every button -> one clean pulse (provided debounce + one_pulse) ----
    // debounce samples every 2^16 cycles (~0.65 ms); one_pulse makes a 1-cycle pulse at 100 MHz
    logic clk_db;
    clock_divider #(.n(16)) u_cd_db (.clk(clk), .clk_div(clk_db));
    logic dL, dR, dD, dU, pL, pR, pD, pU;
    debounce  u_db_l (.clk(clk_db), .pb(btnL), .pb_debounced(dL));
    debounce  u_db_r (.clk(clk_db), .pb(btnR), .pb_debounced(dR));
    debounce  u_db_d (.clk(clk_db), .pb(btnD), .pb_debounced(dD));
    debounce  u_db_u (.clk(clk_db), .pb(btnU), .pb_debounced(dU));
    one_pulse u_op_l (.clk(clk), .pb_in(dL), .pb_out(pL));
    one_pulse u_op_r (.clk(clk), .pb_in(dR), .pb_out(pR));
    one_pulse u_op_d (.clk(clk), .pb_in(dD), .pb_out(pD));
    one_pulse u_op_u (.clk(clk), .pb_in(dU), .pb_out(pU));

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

// ---- provided modules (unchanged) ----
module clock_divider #(
    parameter n = 27 // 2^27 / 100M Hz = 1.34s
)(
    input logic  clk,
    output logic clk_div  
);

    logic [n-1:0] num;
    logic [n-1:0] next_num;

    always_ff @(posedge clk) begin
        num <= next_num;
    end

    assign next_num = num + 1'b1;
    assign clk_div = num[n-1];
endmodule


module debounce #(
    parameter n = 8
)(
    input logic clk,
    input logic pb,
    output logic pb_debounced
);

    logic [n-1:0] shift_reg;

    always_ff @(posedge clk) begin
        shift_reg[n-1:1] <= shift_reg[n-2:0];
        shift_reg[0] <= pb;
    end

    assign pb_debounced = &shift_reg;
endmodule


module one_pulse (
    input logic clk,
    input logic pb_in,
    output logic pb_out
);

	logic pb_in_delay;

	always_ff @(posedge clk) begin
		pb_out <= (pb_in & ~pb_in_delay);
		pb_in_delay <= pb_in;
	end
endmodule
