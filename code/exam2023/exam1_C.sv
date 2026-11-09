// 2023 Exam1 Problem C — Two snakes eating apples (SystemVerilog reference solution)
// Built from the PROVIDED modules: clock_divider, debounce, one_pulse, SevenSegment.
// One clock (100 MHz) for all logic; slow events are 1-cycle tick pulses.
//   T0 = 24 -> t24 every 2^24, t25 every 2^25, t26 every 2^26 cycles.
//   (For simulation, override T0 / DB with small numbers.)
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
    // ---------------- buttons: provided debounce + one_pulse ----------------
    // debounce samples on a slow clock (every 2^DB cycles, ~0.65 ms) so its 8 samples
    // cover ~5 ms of bouncing; one_pulse runs on the 100 MHz clk, so each press becomes
    // exactly ONE clk cycle that the FSM below cannot miss.
    logic clk_db;
    clock_divider #(.n(DB)) u_cd_db (.clk(clk), .clk_div(clk_db));
    logic en_d, set_d, up_d, down_d;
    logic en_p, set_p, up_p, down_p;
    debounce  u_db_en   (.clk(clk_db), .pb(en), .pb_debounced(en_d));
    one_pulse u_op_en   (.clk(clk),    .pb_in(en_d), .pb_out(en_p));
    debounce  u_db_set  (.clk(clk_db), .pb(set), .pb_debounced(set_d));
    one_pulse u_op_set  (.clk(clk),    .pb_in(set_d), .pb_out(set_p));
    debounce  u_db_up   (.clk(clk_db), .pb(up), .pb_debounced(up_d));
    one_pulse u_op_up   (.clk(clk),    .pb_in(up_d), .pb_out(up_p));
    debounce  u_db_down (.clk(clk_db), .pb(down), .pb_debounced(down_d));
    one_pulse u_op_down (.clk(clk),    .pb_in(down_d), .pb_out(down_p));

    // ---------------- FSM ----------------
    typedef enum logic [1:0] {S_RESET, S_START, S_FINISH} state_t;
    state_t state;

    // ---------------- ticks: provided clock_divider + one_pulse ----------------
    // clk_div falls (1 -> 0) exactly when its counter wraps, i.e. once every 2^n cycles.
    // one_pulse(~clk_div) turns that moment into a 1-cycle "tick" in the 100 MHz domain.
    // All dividers start at 0, so every 2^(T0+2) tick also lands on a 2^(T0+1) and 2^T0 tick.
    logic cd0, cd1, cd2, t24, t25, t26;
    clock_divider #(.n(T0))   u_cd0 (.clk(clk), .clk_div(cd0));
    clock_divider #(.n(T0+1)) u_cd1 (.clk(clk), .clk_div(cd1));
    clock_divider #(.n(T0+2)) u_cd2 (.clk(clk), .clk_div(cd2));
    one_pulse u_t0 (.clk(clk), .pb_in(~cd0), .pb_out(t24));   // every 2^24 cycles
    one_pulse u_t1 (.clk(clk), .pb_in(~cd1), .pb_out(t25));   // every 2^25
    one_pulse u_t2 (.clk(clk), .pb_in(~cd2), .pb_out(t26));   // every 2^26
    logic tick0, tick1, tick2;
    assign tick0 = (state == S_START) && t24;
    assign tick1 = (state == S_START) && t25;
    assign tick2 = (state == S_START) && t26;

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
            p     <= 4'd15;  d111 <= R;  mode <= 2'd1;
            q     <= 4'd0;   d1   <= L;
            apple <= '0;
            s111  <= '0;     s1   <= '0;
            timer <= '0;
        end else begin
            case (state)
                S_RESET: if (en_p) state <= S_START;

                S_START: begin
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
    // SevenSegment shows nums[15:12] on the LEFTMOST digit ... nums[3:0] on the rightmost.
    // codes: 0-9 digits, 5 doubles as 'S', 12 = blank, 15 = '-'
    localparam logic [3:0] BLANK = 4'd12, DASH = 4'd15;
    logic [15:0] nums;
    logic [5:0]  abs_diff;
    assign abs_diff = diff[5] ? -diff : diff;

    always_comb begin
        if (state == S_FINISH) begin
            led = 16'hFFFF;
            if (diff > 0)      nums = {4'd5, 4'd1, 4'd1, 4'd1};     // "S111"
            else if (diff < 0) nums = {DASH, DASH, 4'd5, 4'd1};     // "--S1"
            else               nums = {DASH, DASH, DASH, DASH};     // "----"
        end else begin
            led  = apple | occ;
            nums = {(timer == 4'd10) ? 4'd1 : 4'd0,                 // timer tens
                    (timer == 4'd10) ? 4'd0 : timer,                // timer ones
                    diff[5] ? DASH : BLANK,                         // sign
                    abs_diff[3:0]};                                 // |diff|
        end
    end

    SevenSegment u_seg (.display(DISPLAY), .digit(DIGIT), .nums(nums), .rst(rst), .clk(clk));
endmodule

// ===================================================================
// Provided modules (given in the exam: clock_divider, debounce, one_pulse,
// SevenSegment). Pasted unchanged, except: SevenSegment got codes 12 (blank) and 15 (-).
// ===================================================================
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


module SevenSegment(
	output logic [6:0] display,
	output logic [3:0] digit,
	input logic [15:0] nums,
	input logic rst,
	input logic clk
);
    
    logic [15:0] clk_divider;
    logic [3:0] display_num;
    
    always_ff @(posedge clk or posedge rst) begin
    	if (rst) begin
    		clk_divider <= 16'd0;
    	end else begin
    		clk_divider <= clk_divider + 16'd1;
    	end
    end
    
    always_ff @(posedge clk_divider[15] or posedge rst) begin
    	if (rst) begin
    		display_num <= 4'b0000;
    		digit <= 4'b1111;
    	end else begin
    		case (digit)
    			4'b1110 : begin
					display_num <= nums[7:4];
					digit <= 4'b1101;
    			end
    			4'b1101 : begin
					display_num <= nums[11:8];
					digit <= 4'b1011;
				end
    			4'b1011 : begin
					display_num <= nums[15:12];
					digit <= 4'b0111;
				end
    			4'b0111 : begin
					display_num <= nums[3:0];
					digit <= 4'b1110;
				end
    			default : begin
					display_num <= nums[3:0];
					digit <= 4'b1110;
				end				
    		endcase
    	end
    end
    
    always_comb begin
    	case (display_num)
    		4'd0: display = 7'b1000000;
            4'd1: display = 7'b1111001;
            4'd2: display = 7'b0100100;
            4'd3: display = 7'b0110000;
            4'd4: display = 7'b0011001;
            4'd5: display = 7'b0010010;
            4'd6: display = 7'b0000010;
            4'd7: display = 7'b1111000;
            4'd8: display = 7'b0000000;
            4'd9: display = 7'b0010000;
            4'd12: display = 7'b1111111;   // blank  <- added for this problem
            4'd15: display = 7'b0111111;   // -  <- added for this problem
			default : display = 7'b1111111;
    	endcase
    end
endmodule

