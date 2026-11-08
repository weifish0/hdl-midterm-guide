// 2023 Exam1 Problem C — Two snakes eating apples (SystemVerilog reference solution)
// Design style: ONE clock (100 MHz) everywhere + "tick" enable pulses.
//   T0 = 24 -> tick0 every 2^24, tick1 every 2^25, tick2 every 2^26 cycles.
//   (For simulation you can override T0/DB with small numbers.)
`timescale 1ns/1ps
module exam1_C #(parameter int T0 = 24, parameter int DB = 16) (
    input  logic        clk,
    input  logic        rst,      // btnC, synchronous active-high
    input  logic        en,       // btnR
    input  logic        set,      // btnL
    input  logic        up,       // btnU
    input  logic        down,     // btnD
    input  logic [15:0] sw,
    output logic [3:0]  DIGIT,
    output logic [6:0]  DISPLAY,
    output logic [15:0] led
);
    // ---------------- buttons -> single-cycle pulses ----------------
    logic en_p, set_p, up_p, down_p;
    btn_pulse #(DB) u_en  (.clk, .rst, .btn(en),   .pulse(en_p));
    btn_pulse #(DB) u_set (.clk, .rst, .btn(set),  .pulse(set_p));
    btn_pulse #(DB) u_up  (.clk, .rst, .btn(up),   .pulse(up_p));
    btn_pulse #(DB) u_dn  (.clk, .rst, .btn(down), .pulse(down_p));

    // ---------------- FSM ----------------
    typedef enum logic [1:0] {S_RESET, S_START, S_FINISH} state_t;
    state_t state;

    // ---------------- tick generator ----------------
    logic [T0+1:0] cnt;                                   // T0+2 bits
    logic tick0, tick1, tick2;
    assign tick0 = (state == S_START) && (cnt[T0-1:0] == '1);  // 2^24
    assign tick1 = (state == S_START) && (cnt[T0:0]   == '1);  // 2^25
    assign tick2 = (state == S_START) && (cnt         == '1);  // 2^26

    // ---------------- game registers ----------------
    localparam logic L = 1'b1, R = 1'b0;   // L: toward LD15 (index +1), R: toward LD0 (index -1)
    logic [3:0]  p;        // Snake111 LEFT end; it occupies p, p-1, p-2
    logic        d111;
    logic [1:0]  mode;     // 0: 2^24, 1: 2^25, 2: 2^26
    logic [3:0]  q;        // Snake1 position
    logic        d1;
    logic [15:0] apple;
    logic [4:0]  s111, s1; // scores
    logic [3:0]  timer;    // 0..10

    // ---------------- combinational helpers ----------------
    logic [15:0] mask111, mask1, occ;
    logic [3:0]  r;                       // right end of Snake111
    logic        contact, eff111, eff1, tick111;
    logic signed [5:0] diff;
    logic        hit111, hit1, game_over;

    assign r       = p - 4'd2;
    assign mask111 = 16'b111 << r;
    assign mask1   = 16'b1 << q;
    assign occ     = mask111 | mask1;

    // contact: the two ends are next to each other OR overlap (q is always right of r)
    assign contact = ({1'b0, q} + 5'd1 >= {1'b0, r});

    // effective direction for THIS cycle (contact has the highest priority)
    always_comb begin
        if (contact)           eff111 = L;
        else if (p == 4'd15)   eff111 = R;
        else if (r == 4'd0)    eff111 = L;
        else                   eff111 = d111;

        if (contact)           eff1 = R;
        else if (q == 4'd0)    eff1 = L;
        else if (q == 4'd15)   eff1 = R;
        else                   eff1 = d1;
    end

    always_comb begin
        case (mode)
            2'd0:    tick111 = tick0;
            2'd1:    tick111 = tick1;
            default: tick111 = tick2;
        endcase
    end

    // eating: Snake111 has priority when both touch the same apple
    assign hit111 = |(apple & mask111);
    assign hit1   = |(apple & mask1 & ~mask111);

    assign diff      = $signed({1'b0, s111}) - $signed({1'b0, s1});
    assign game_over = (timer == 4'd10) || (diff >= 6'sd3) || (diff <= -6'sd3);

    // ---------------- main sequential block ----------------
    always_ff @(posedge clk) begin
        if (rst || (state == S_FINISH && en_p)) begin
            state <= S_RESET;
            cnt   <= '0;
            p     <= 4'd15;  d111 <= R;  mode <= 2'd1;
            q     <= 4'd0;   d1   <= L;
            apple <= '0;
            s111  <= '0;     s1   <= '0;
            timer <= '0;
        end else begin
            case (state)
                S_RESET: begin
                    cnt <= '0;
                    if (en_p) state <= S_START;
                end

                S_START: begin
                    cnt <= cnt + 1'b1;

                    // directions are re-evaluated every cycle
                    d111 <= eff111;
                    d1   <= eff1;

                    // movement (stay in place if blocked on both sides)
                    if (tick111) begin
                        if (eff111 == L && p != 4'd15)                  p <= p + 4'd1;
                        else if (eff111 == R && r != 4'd0 && !contact)  p <= p - 4'd1;
                    end
                    if (tick1) begin
                        if (eff1 == R && q != 4'd0)                     q <= q - 4'd1;
                        else if (eff1 == L && q != 4'd15 && !contact)   q <= q + 4'd1;
                    end

                    // mode change (only in START)
                    if (up_p   && mode != 2'd2) mode <= mode + 2'd1;
                    if (down_p && mode != 2'd0) mode <= mode - 2'd1;

                    // apples: remove eaten ones, add new ones (never on a snake)
                    apple <= (apple & ~occ) | (set_p ? (sw & ~occ) : 16'd0);
                    if (hit111) s111 <= s111 + 5'd1;
                    if (hit1)   s1   <= s1 + 5'd1;

                    // timer (~1 s)
                    if (tick2 && timer != 4'd10) timer <= timer + 4'd1;

                    if (game_over) state <= S_FINISH;
                end

                default: ;  // S_FINISH: wait for en (handled above)
            endcase
        end
    end

    // ---------------- outputs ----------------
    localparam logic [4:0] DASH = 5'd19, BLANK = 5'd31;
    logic [4:0] c3, c2, c1, c0;
    logic [5:0] abs_diff;
    assign abs_diff = diff[5] ? -diff : diff;

    always_comb begin
        if (state == S_FINISH) begin
            led = 16'hFFFF;
            if (diff > 0)      {c3, c2, c1, c0} = {5'd5, 5'd1, 5'd1, 5'd1};  // "S111"
            else if (diff < 0) {c3, c2, c1, c0} = {DASH, DASH, 5'd5, 5'd1};  // "--S1"
            else               {c3, c2, c1, c0} = {DASH, DASH, DASH, DASH};  // "----"
        end else begin
            led = apple | occ;
            c3  = (timer == 4'd10) ? 5'd1 : 5'd0;                  // timer tens
            c2  = (timer == 4'd10) ? 5'd0 : {1'b0, timer};         // timer ones
            c1  = diff[5] ? DASH : BLANK;                           // sign
            c0  = abs_diff[4:0];                                    // |diff| (0..3)
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
