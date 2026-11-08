// Lab 3 Practice — LED controller FSM (INITIAL -> LOAD -> PLAY -> FINAL -> INITIAL)
`timescale 1ns/1ps
module lab3_practice (
    input  logic        clk,
    input  logic        rst,        // asynchronous, active-high (SW15)
    input  logic        slow,       // SW0
    input  logic        fast,       // SW1
    input  logic        end_light,  // SW2
    output logic [15:0] led
);
    typedef enum logic [1:0] {INITIAL, LOAD, PLAY, FINAL} state_t;
    state_t state, next_state;

    // ---- timers: one-cycle "tick" pulses (exact time, not powers of two) ----
    logic tick_q, tick_h;                     // 0.25 s and 0.5 s
    timer #(.COUNT(25_000_000)) t_q (.clk, .rst, .enable(state == LOAD),  .tick(tick_q));
    timer #(.COUNT(50_000_000)) t_h (.clk, .rst, .enable(state == FINAL), .tick(tick_h));

    // ---- clock dividers for the flashing in PLAY (2^28 and 2^27) ----
    logic div_slow, div_fast;
    clock_divider #(.n(28)) d_s (.clk, .rst, .enable(state == PLAY), .clk_div(div_slow));
    clock_divider #(.n(27)) d_f (.clk, .rst, .enable(state == PLAY), .clk_div(div_fast));

    logic [4:0] load_cnt;   // how many LEDs are on in LOAD (0..16)
    logic [2:0] half_cnt;   // number of finished 0.5 s periods in FINAL (0..5)

    // ---- state register (async reset) ----
    always_ff @(posedge clk or posedge rst) begin
        if (rst) state <= INITIAL;
        else     state <= next_state;
    end

    // ---- next-state logic ----
    always_comb begin
        next_state = state;
        case (state)
            INITIAL: next_state = LOAD;
            LOAD:    if (load_cnt == 5'd16)          next_state = PLAY;
            PLAY:    if (end_light)                  next_state = FINAL;
            FINAL:   if (tick_h && half_cnt == 3'd5) next_state = INITIAL;
        endcase
    end

    // ---- datapath counters ----
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            load_cnt <= '0; half_cnt <= '0;
        end else begin
            if (state != LOAD)                    load_cnt <= '0;
            else if (tick_q && load_cnt != 5'd16) load_cnt <= load_cnt + 5'd1;

            if (state != FINAL) half_cnt <= '0;
            else if (tick_h)    half_cnt <= half_cnt + 3'd1;
        end
    end

    // ---- outputs (Moore: depend on state + datapath only) ----
    always_comb begin
        case (state)
            INITIAL: led = 16'hFFFF;
            LOAD:    led = ~(16'hFFFF << load_cnt);                     // load_cnt LEDs on, from LD0
            PLAY: begin
                led = 16'h0000;
                if (slow) led = led | (div_slow ? 16'h5555 : 16'h0000);  // even LEDs
                if (fast) led = led | (div_fast ? 16'hAAAA : 16'h0000);  // odd LEDs
            end
            default: led = half_cnt[0] ? 16'h0000 : 16'hFFFF;           // FINAL: on/off x3
        endcase
    end
endmodule

// ---- modules given in the template ----
module timer #(parameter integer COUNT = 100_000_000) (
    input logic clk, input logic rst, input logic enable, output logic tick
);
    logic [31:0] num;
    always_ff @(posedge clk or posedge rst) begin
        if (rst)                   num <= 32'd0;
        else if (!enable)          num <= 32'd0;
        else if (num == COUNT - 1) num <= 32'd0;
        else                       num <= num + 1'b1;
    end
    assign tick = enable && (num == COUNT - 1);
endmodule

module clock_divider #(parameter n = 10) (
    input logic clk, input logic rst, input logic enable, output logic clk_div
);
    logic [n-1:0] num;
    always_ff @(posedge clk or posedge rst) begin
        if (rst)         num <= '0;
        else if (enable) num <= num + 1'b1;
        else             num <= '0;
    end
    assign clk_div = num[n-1];
endmodule
