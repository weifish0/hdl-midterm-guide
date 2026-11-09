// 2021 Exam1 Problem C — Two LED racers with walls (SystemVerilog reference solution)
// Built from the PROVIDED modules: clock_divider, debounce, one_pulse, SevenSegment.
// One clock (100 MHz) for all logic; racers move on a 1-cycle tick every 2^T cycles.
`timescale 1ns/1ps
module exam1_C #(parameter int T0 = 25, parameter int DB = 16) (
    input  logic        clk,
    input  logic        rst_btn,    // BTNC, synchronous active-high
    input  logic        start_btn,  // BTNL, start / pause
    input  logic [15:0] sw,         // walls
    output logic [3:0]  DIGIT,
    output logic [6:0]  DISPLAY,
    output logic [15:0] led
);
    logic rst;
    assign rst = rst_btn;

    // ---------------- buttons: provided debounce + one_pulse ----------------
    // debounce samples on a slow clock (every 2^DB cycles, ~0.65 ms) so its 8 samples
    // cover ~5 ms of bouncing; one_pulse runs on the 100 MHz clk, so each press becomes
    // exactly ONE clk cycle that the FSM below cannot miss.
    logic clk_db;
    clock_divider #(.n(DB)) u_cd_db (.clk(clk), .clk_div(clk_db));
    logic start_d;
    logic start_p;
    debounce  u_db_start(.clk(clk_db), .pb(start_btn), .pb_debounced(start_d));
    one_pulse u_op_start(.clk(clk),    .pb_in(start_d), .pb_out(start_p));

    typedef enum logic [1:0] {S_RESET, S_START, S_PAUSE} state_t;
    state_t state;

    // ---------------- tick: provided clock_divider + one_pulse ----------------
    // clk_div falls (1 -> 0) once every 2^T0 cycles; one_pulse turns that into a 1-cycle tick.
    logic cd, t25, step;
    clock_divider #(.n(T0)) u_cd (.clk(clk), .clk_div(cd));
    one_pulse u_tick (.clk(clk), .pb_in(~cd), .pb_out(t25));
    assign step = (state == S_START) && t25;

    // ---------------- racers ----------------
    // dir = 1 : LEFT  (toward LD15, index + 1)   dir = 0 : RIGHT (toward LD0, index - 1)
    // 4-bit arithmetic wraps automatically: 15 + 1 = 0, 0 - 1 = 15
    logic [3:0] m1, m2;
    logic       d1, d2;
    logic [4:0] hits;           // number of racer-racer collisions (0..15)

    logic [3:0] n1, n2, b1, b2; // next (forward) and back positions
    assign n1 = d1 ? m1 + 4'd1 : m1 - 4'd1;
    assign n2 = d2 ? m2 + 4'd1 : m2 - 4'd1;
    assign b1 = d1 ? m1 - 4'd1 : m1 + 4'd1;
    assign b2 = d2 ? m2 - 4'd1 : m2 + 4'd1;

    // a racer is blocked by a wall, by the other racer, or when both
    // would step onto the same LED
    logic racer_col, blk1, blk2;
    assign racer_col = (n1 == m2) || (n2 == m1) || (n1 == n2);
    assign blk1 = sw[n1] || (n1 == m2) || (n1 == n2);
    assign blk2 = sw[n2] || (n2 == m1) || (n1 == n2);

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= S_RESET;
            m1 <= 4'd1;  d1 <= 1'b1;    // Mr.1 at LED1, LEFT
            m2 <= 4'd10; d2 <= 1'b0;    // Mr.2 at LED10, RIGHT
            hits <= '0;
        end else begin
            case (state)
                S_RESET: if (start_p) state <= S_START;

                S_START: begin
                    if (start_p || hits == 5'd15) state <= S_PAUSE;

                    if (step) begin
                        // Mr.1: bounce = reverse and move the other way (stay if stuck)
                        if (blk1) begin
                            d1 <= ~d1;
                            if (!sw[b1] && b1 != m2) m1 <= b1;
                        end else m1 <= n1;
                        // Mr.2
                        if (blk2) begin
                            d2 <= ~d2;
                            if (!sw[b2] && b2 != m1) m2 <= b2;
                        end else m2 <= n2;

                        if (racer_col && hits != 5'd15) hits <= hits + 5'd1;
                    end
                end

                default: // S_PAUSE: resume only if fewer than 15 collisions
                    if (start_p && hits != 5'd15) state <= S_START;
            endcase
        end
    end

    // ---------------- outputs ----------------
    assign led = sw | (16'b1 << m1) | (16'b1 << m2);

    // codes for SevenSegment: 0-9 digits (5 = 'S'), 10 = r, 11 = P, 12 = blank
    localparam logic [3:0] CH_R = 4'd10, CH_P = 4'd11, BLANK = 4'd12;
    logic [3:0] letter;
    always_comb begin
        case (state)
            S_RESET: letter = CH_R;
            S_START: letter = 4'd5;      // "S"
            default: letter = CH_P;
        endcase
    end

    logic [15:0] nums;
    assign nums = {letter, BLANK,
                   (hits >= 5'd10) ? 4'd1 : 4'd0,                       // tens
                   (hits >= 5'd10) ? 4'(hits - 5'd10) : hits[3:0]};     // ones

    SevenSegment u_seg (.display(DISPLAY), .digit(DIGIT), .nums(nums), .rst(rst), .clk(clk));
endmodule

// ===================================================================
// Provided modules (given in the exam: clock_divider, debounce, one_pulse,
// SevenSegment). Pasted unchanged, except: SevenSegment got codes 10 (r), 11 (P), 12 (blank).
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
            4'd10: display = 7'b0101111;   // r  <- added for this problem
            4'd11: display = 7'b0001100;   // P  <- added for this problem
            4'd12: display = 7'b1111111;   // blank  <- added for this problem
			default : display = 7'b1111111;
    	endcase
    end
endmodule

