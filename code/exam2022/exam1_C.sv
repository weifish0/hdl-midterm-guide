// 2022 Exam1 Problem C — player_AI vs player_user grabbing flags (SystemVerilog reference solution)
// ONE clock (100 MHz) + tick enables: tick0 = 2^24, tick1 = 2^25, tick2 = 2^26 cycles.
`timescale 1ns/1ps
module exam1_C #(parameter int T0 = 24, parameter int DB = 16) (
    input  logic        clk,
    input  logic        rst,      // btnC, synchronous active-high
    input  logic        en,       // btnR : RESET->START, START<->PAUSE
    input  logic        set,      // btnL : add flags where sw = 1
    input  logic        up,       // btnU : bigger & slower
    input  logic        down,     // btnD : smaller & faster
    input  logic [15:0] sw,
    output logic [3:0]  DIGIT,
    output logic [6:0]  DISPLAY,
    output logic [15:0] led
);
    logic en_p, set_p, up_p, down_p;
    btn_pulse #(DB) u_en  (.clk, .rst, .btn(en),   .pulse(en_p));
    btn_pulse #(DB) u_set (.clk, .rst, .btn(set),  .pulse(set_p));
    btn_pulse #(DB) u_up  (.clk, .rst, .btn(up),   .pulse(up_p));
    btn_pulse #(DB) u_dn  (.clk, .rst, .btn(down), .pulse(down_p));

    typedef enum logic [1:0] {S_RESET, S_START, S_PAUSE, S_FINISH} state_t;
    state_t state;

    // free-running counter -> tick pulses
    logic [T0+1:0] cnt;
    logic t24, t25, t26;
    always_ff @(posedge clk) begin
        if (rst) cnt <= '0;
        else     cnt <= cnt + 1'b1;
    end
    assign t24 = (cnt[T0-1:0] == '1);
    assign t25 = (cnt[T0:0]   == '1);
    assign t26 = (cnt         == '1);

    // ---------------- players ----------------
    logic [3:0]  ai;          // AI position
    logic        ai_left;     // 0: moving toward LD0 (index -1, wraps 0 -> 15), 1: toward LD15
    logic [3:0]  uc;          // user CENTER position, always moves toward LD15 (wraps 15 -> 0)
    logic [1:0]  mode;        // 0: 1 LED @2^24, 1: 3 LEDs @2^25, 2: 5 LEDs @2^26
    logic [15:0] flag;
    logic [3:0]  ai_sc, us_sc;
    logic        led_phase;   // FINISH flashing

    // user mask = base pattern centred at bit 0, rotated left by uc (wrap-around for free)
    logic [15:0] base, umask, amask;
    always_comb begin
        case (mode)
            2'd0:    base = 16'b0000_0000_0000_0001;  // {0}
            2'd1:    base = 16'b1000_0000_0000_0011;  // {15,0,1}
            default: base = 16'b1100_0000_0000_0111;  // {14,15,0,1,2}
        endcase
    end
    assign umask = (base << uc) | (base >> (5'd16 - uc));   // rotate-left (uc = 0 is fine)
    assign amask = 16'b1 << ai;


    logic u_tick;
    always_comb begin
        case (mode)
            2'd0:    u_tick = t24;
            2'd1:    u_tick = t25;
            default: u_tick = t26;
        endcase
    end

    // where the user WILL be after this edge (both players may move on the same edge)
    logic [3:0]  uc_n;
    logic [15:0] umask_n;
    assign uc_n    = u_tick ? uc + 4'd1 : uc;
    assign umask_n = (base << uc_n) | (base >> (5'd16 - uc_n));

    // AI next step / bounce
    // The user always moves toward LD15. If the user is about to cover the AI while the
    // AI is heading toward it (head-on), the AI turns around right now.
    logic       eff_left;
    logic [3:0] ai_fwd, ai_back;
    assign eff_left = (umask_n[ai] && !ai_left) ? 1'b1 : ai_left;
    assign ai_fwd   = eff_left ? ai + 4'd1 : ai - 4'd1;   // 4-bit wrap-around: 0-1 = 15
    assign ai_back  = eff_left ? ai - 4'd1 : ai + 4'd1;

    logic ai_hit, us_hit;
    assign ai_hit = |(flag & amask);
    assign us_hit = |(flag & umask & ~amask);     // AI wins a tie

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= S_RESET;
            ai <= 4'd15; ai_left <= 1'b0;
            uc <= 4'd1;  mode <= 2'd1;
            flag <= '0;  ai_sc <= '0; us_sc <= '0;
            led_phase <= 1'b0;
        end else begin
            // flags can be added in RESET / START / PAUSE
            if (set_p && state != S_FINISH) flag <= flag | sw;

            case (state)
                S_RESET: if (en_p) state <= S_START;

                S_START: begin
                    if (en_p) state <= S_PAUSE;

                    if (up_p   && mode != 2'd2) mode <= mode + 2'd1;  // expands at both sides
                    if (down_p && mode != 2'd0) mode <= mode - 2'd1;  // (centre stays)

                    if (u_tick) uc <= uc + 4'd1;

                    ai_left <= eff_left;
                    if (t25) begin
                        if (umask_n[ai_fwd]) begin            // would hit the user -> turn around
                            ai_left <= ~eff_left;
                            if (!umask_n[ai_back]) ai <= ai_back;
                        end else begin
                            ai <= ai_fwd;
                        end
                    end

                    // touching flags (overrides the "add" above for touched bits)
                    if (ai_hit || us_hit)
                        flag <= (flag | (set_p ? sw : 16'd0)) & ~(amask | umask);
                    if (ai_hit) ai_sc <= ai_sc + 4'd1;
                    if (us_hit) us_sc <= us_sc + 4'd1;

                    if (ai_sc == 4'd10 || us_sc == 4'd10) state <= S_FINISH;
                end

                S_PAUSE: if (en_p) state <= S_START;

                default: if (t24) led_phase <= ~led_phase;   // S_FINISH
            endcase
        end
    end

    // ---------------- outputs ----------------
    localparam logic [4:0] CH_A = 5'd10, CH_E = 5'd14, CH_R = 5'd17, CH_U = 5'd18;
    logic [4:0] c3, c2, c1, c0;
    always_comb begin
        if (state == S_FINISH) begin
            led = led_phase ? 16'hAAAA : 16'h5555;
            if (ai_sc == 4'd10) {c3, c2, c1, c0} = {CH_A, 5'd1, CH_A, 5'd1};     // "AIAI"
            else                {c3, c2, c1, c0} = {CH_U, 5'd5, CH_E, CH_R};     // "USER"
        end else begin
            led = flag | amask | umask;
            c3 = (ai_sc == 4'd10) ? 5'd1 : 5'd0;
            c2 = (ai_sc == 4'd10) ? 5'd0 : {1'b0, ai_sc};
            c1 = (us_sc == 4'd10) ? 5'd1 : 5'd0;
            c0 = (us_sc == 4'd10) ? 5'd0 : {1'b0, us_sc};
        end
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
