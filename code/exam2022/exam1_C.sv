// 2022 Exam1 Problem C — player_AI vs player_user grabbing flags (SystemVerilog reference solution)
// Built from the PROVIDED modules: clock_divider, debounce, one_pulse, SevenSegment.
// One clock (100 MHz) for all logic; t24 / t25 / t26 are 1-cycle tick pulses.
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

    typedef enum logic [1:0] {S_RESET, S_START, S_PAUSE, S_FINISH} state_t;
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
    // codes for SevenSegment: 0-9 digits (1 = 'I', 5 = 'S'), 10 = A, 11 = E, 13 = U, 14 = r
    localparam logic [3:0] CH_A = 4'd10, CH_E = 4'd11, CH_U = 4'd13, CH_R = 4'd14;
    logic [15:0] nums;
    always_comb begin
        if (state == S_FINISH) begin
            led = led_phase ? 16'hAAAA : 16'h5555;
            if (ai_sc == 4'd10) nums = {CH_A, 4'd1, CH_A, 4'd1};     // "AIAI"
            else                nums = {CH_U, 4'd5, CH_E, CH_R};     // "USEr"
        end else begin
            led  = flag | amask | umask;
            nums = {(ai_sc == 4'd10) ? 4'd1 : 4'd0, (ai_sc == 4'd10) ? 4'd0 : ai_sc,
                    (us_sc == 4'd10) ? 4'd1 : 4'd0, (us_sc == 4'd10) ? 4'd0 : us_sc};
        end
    end

    SevenSegment u_seg (.display(DISPLAY), .digit(DIGIT), .nums(nums), .rst(rst), .clk(clk));
endmodule

// ===================================================================
// Provided modules (given in the exam: clock_divider, debounce, one_pulse,
// SevenSegment). Pasted unchanged, except: SevenSegment got codes 10 (A), 11 (E), 13 (U), 14 (r).
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
            4'd10: display = 7'b0001000;   // A  <- added for this problem
            4'd11: display = 7'b0000110;   // E  <- added for this problem
            4'd13: display = 7'b1000001;   // U  <- added for this problem
            4'd14: display = 7'b0101111;   // r  <- added for this problem
			default : display = 7'b1111111;
    	endcase
    end
endmodule

