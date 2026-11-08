// Mock Exam Problem C — LED Whack-a-Mole (reference solution)
//   IDLE --btnD--> PLAY --(time = 0)--> OVER --btnD--> IDLE      rst (btnC) -> IDLE at any time
// One 100 MHz clock everywhere; slow events are 1-cycle "tick" pulses.
`timescale 1ns/1ps
module mock_C #(
    parameter int SEC  = 100_000_000,  // cycles per second (shrink it for simulation)
    parameter int LIFE = 27,           // a mole lives 2^27 cycles (~1.34 s)
    parameter int DB   = 16
) (
    input  logic        clk,
    input  logic        rst,      // btnC, synchronous
    input  logic        btnL,     // hammer toward LD15
    input  logic        btnR,     // hammer toward LD0
    input  logic        btnU,     // hit
    input  logic        btnD,     // start / back to IDLE
    output logic [3:0]  DIGIT,
    output logic [6:0]  DISPLAY,
    output logic [15:0] led
);
    logic pL, pR, pU, pD;
    btn_pulse #(DB) u0 (.clk, .rst, .btn(btnL), .pulse(pL));
    btn_pulse #(DB) u1 (.clk, .rst, .btn(btnR), .pulse(pR));
    btn_pulse #(DB) u2 (.clk, .rst, .btn(btnU), .pulse(pU));
    btn_pulse #(DB) u3 (.clk, .rst, .btn(btnD), .pulse(pD));

    typedef enum logic [1:0] {IDLE, PLAY, OVER} state_t;
    state_t state;

    // ---- free-running 8-bit LFSR (x^8 + x^6 + x^5 + x^4 + 1, never 0) ----
    logic [7:0] lfsr;
    always_ff @(posedge clk) begin
        if (rst) lfsr <= 8'h01;
        else     lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    // ---- exact 1-second timer (only in PLAY) ----
    logic [31:0] sec_cnt;
    logic        sec_tick;
    assign sec_tick = (state == PLAY) && (sec_cnt == SEC - 1);

    // ---- mole life counter and blink ----
    logic [LIFE-1:0] life_cnt;
    logic            life_over;
    assign life_over = (life_cnt == '1);
    logic [24:0]     blink = '0;     // free-running, blink[23] toggles every 2^23
    always_ff @(posedge clk) blink <= blink + 1'b1;

    logic [3:0] hammer, mole;
    logic       has_mole;
    logic [4:0] time_left;           // 20 .. 0
    logic [6:0] score;               // 0 .. 99

    always_ff @(posedge clk) begin
        if (rst || (state == OVER && pD)) begin
            state <= IDLE;
            hammer <= 4'd7; has_mole <= 1'b0; mole <= 4'd0;
            time_left <= 5'd20; score <= '0;
            sec_cnt <= '0; life_cnt <= '0;
        end else begin
            case (state)
                IDLE: if (pD) state <= PLAY;

                PLAY: begin
                    // 1-second countdown
                    sec_cnt <= sec_tick ? '0 : sec_cnt + 1;
                    if (sec_tick) begin
                        time_left <= time_left - 5'd1;
                        if (time_left == 5'd1) state <= OVER;
                    end

                    // hammer (clamped, no wrap-around)
                    if (pL && hammer != 4'd15) hammer <= hammer + 4'd1;
                    if (pR && hammer != 4'd0)  hammer <= hammer - 4'd1;

                    // mole: spawn, hit, or time out
                    if (!has_mole) begin
                        if (lfsr[3:0] != hammer) begin     // never spawn under the hammer
                            mole <= lfsr[3:0]; has_mole <= 1'b1; life_cnt <= '0;
                        end
                    end else if (pU && hammer == mole) begin
                        has_mole <= 1'b0;                  // hit!  next mole spawns soon
                        if (score != 7'd99) score <= score + 7'd1;
                    end else if (life_over) begin
                        has_mole <= 1'b0;                  // escaped
                    end else begin
                        life_cnt <= life_cnt + 1'b1;
                    end
                end

                default: ;  // OVER: wait for btnD (handled above)
            endcase
        end
    end

    // ---- outputs ----
    logic [15:0] hmask, mmask;
    assign hmask = 16'b1 << hammer;
    assign mmask = (has_mole && blink[23]) ? (16'b1 << mole) : 16'b0;   // mole blinks

    always_comb begin
        case (state)
            IDLE:    led = hmask;
            PLAY:    led = hmask | mmask;
            default: led = blink[24] ? 16'hFFFF : 16'h0000;
        endcase
    end

    // 7-seg: [time tens][time ones][score tens][score ones]; OVER shows "--" + score
    localparam logic [4:0] DASH = 5'd19;
    logic [4:0] c3, c2, c1, c0;
    always_comb begin
        c3 = (time_left >= 5'd20) ? 5'd2 : (time_left >= 5'd10) ? 5'd1 : 5'd0;
        c2 = time_left - ((time_left >= 5'd20) ? 5'd20 : (time_left >= 5'd10) ? 5'd10 : 5'd0);
        c1 = 5'(score / 10);         // "/" and "%" by constants are fine for synthesis
        c0 = 5'(score % 10);
        if (state == OVER) begin c3 = DASH; c2 = DASH; end
    end

    seven_seg u_seg (.clk, .c3, .c2, .c1, .c0, .DIGIT, .DISPLAY);
endmodule

// ===================================================================
//  Reusable helper modules for FPGA problems (Basys3, 100 MHz clock)
//  Paste these at the bottom of your exam file: the exam requires
//  ONE file that contains every module you use.
// ===================================================================

// -------------------------------------------------------------------
// btn_pulse: debounce + one-pulse in ONE clock domain (100 MHz).
//   * The button is sampled once every 2^DB clock cycles
//     (DB = 16 -> every 0.65 ms), shifted into a 4-bit register.
//   * "stable" = the last 4 samples were all 1.
//   * pulse   = rising edge of "stable", exactly ONE 100 MHz cycle wide.
// -------------------------------------------------------------------
module btn_pulse #(parameter int DB = 16) (
    input  logic clk,
    input  logic rst,
    input  logic btn,
    output logic pulse
);
    logic [DB-1:0] div;
    logic [3:0]    samples;
    logic          stable, stable_d;

    assign stable = &samples;

    always_ff @(posedge clk) begin
        if (rst) begin
            div <= '0; samples <= '0; stable_d <= 1'b0;
        end else begin
            div <= div + 1'b1;
            if (div == '0) samples <= {samples[2:0], btn};
            stable_d <= stable;
        end
    end

    assign pulse = stable & ~stable_d;
endmodule

// -------------------------------------------------------------------
// seven_seg: 4-digit multiplexed display driver.
//   * c3 is the LEFTMOST digit, c0 the RIGHTMOST.
//   * each cN is a 5-bit character code (see the localparams below).
//   * DIGIT and DISPLAY are ACTIVE-LOW on Basys3.
//   * DISPLAY = {g, f, e, d, c, b, a}
// -------------------------------------------------------------------
module seven_seg (
    input  logic       clk,
    input  logic [4:0] c3, c2, c1, c0,
    output logic [3:0] DIGIT,
    output logic [6:0] DISPLAY
);
    // character codes: 0..9 are the digits themselves
    localparam logic [4:0] CH_A = 5'd10, CH_E = 5'd14, CH_P = 5'd16,
                           CH_R = 5'd17, CH_U = 5'd18, CH_DASH = 5'd19,
                           CH_BLANK = 5'd31;
    // 'S' looks like 5 and 'I' looks like 1 -> just use 5 and 1

    logic [16:0] refresh = '0;     // 2^15 cycles per digit (~0.33 ms); '= 0' sets the FPGA power-up value
    logic [4:0]  ch;

    always_ff @(posedge clk) refresh <= refresh + 1'b1;

    always_comb begin
        case (refresh[16:15])
            2'd0: begin DIGIT = 4'b1110; ch = c0; end
            2'd1: begin DIGIT = 4'b1101; ch = c1; end
            2'd2: begin DIGIT = 4'b1011; ch = c2; end
            default: begin DIGIT = 4'b0111; ch = c3; end
        endcase
    end

    always_comb begin
        case (ch)
            5'd0: DISPLAY = 7'b1000000;
            5'd1: DISPLAY = 7'b1111001;
            5'd2: DISPLAY = 7'b0100100;
            5'd3: DISPLAY = 7'b0110000;
            5'd4: DISPLAY = 7'b0011001;
            5'd5: DISPLAY = 7'b0010010;
            5'd6: DISPLAY = 7'b0000010;
            5'd7: DISPLAY = 7'b1111000;
            5'd8: DISPLAY = 7'b0000000;
            5'd9: DISPLAY = 7'b0010000;
            CH_A: DISPLAY = 7'b0001000;
            CH_E: DISPLAY = 7'b0000110;
            CH_P: DISPLAY = 7'b0001100;
            CH_R: DISPLAY = 7'b0101111;   // lowercase r
            CH_U: DISPLAY = 7'b1000001;
            CH_DASH: DISPLAY = 7'b0111111;
            default: DISPLAY = 7'b1111111; // blank
        endcase
    end
endmodule
