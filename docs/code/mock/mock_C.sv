// Mock Exam Problem C — LED Whack-a-Mole (reference solution)
//   IDLE --btnD--> PLAY --(time = 0)--> OVER --btnD--> IDLE      rst (btnC) -> IDLE at any time
// Built from the PROVIDED modules (clock_divider, debounce, one_pulse, SevenSegment).
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
    // ---------------- buttons: provided debounce + one_pulse ----------------
    // debounce samples on a slow clock (every 2^DB cycles, ~0.65 ms) so its 8 samples
    // cover ~5 ms of bouncing; one_pulse runs on the 100 MHz clk, so each press becomes
    // exactly ONE clk cycle that the FSM below cannot miss.
    logic clk_db;
    clock_divider #(.n(DB)) u_cd_db (.clk(clk), .clk_div(clk_db));
    logic pL_d, pR_d, pU_d, pD_d;
    logic pL, pR, pU, pD;
    debounce  u_db_pL   (.clk(clk_db), .pb(btnL), .pb_debounced(pL_d));
    one_pulse u_op_pL   (.clk(clk),    .pb_in(pL_d), .pb_out(pL));
    debounce  u_db_pR   (.clk(clk_db), .pb(btnR), .pb_debounced(pR_d));
    one_pulse u_op_pR   (.clk(clk),    .pb_in(pR_d), .pb_out(pR));
    debounce  u_db_pU   (.clk(clk_db), .pb(btnU), .pb_debounced(pU_d));
    one_pulse u_op_pU   (.clk(clk),    .pb_in(pU_d), .pb_out(pU));
    debounce  u_db_pD   (.clk(clk_db), .pb(btnD), .pb_debounced(pD_d));
    one_pulse u_op_pD   (.clk(clk),    .pb_in(pD_d), .pb_out(pD));

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
    logic blink23, blink24;          // provided clock_divider used as plain square waves
    clock_divider #(.n(24)) u_bl23 (.clk(clk), .clk_div(blink23));   // toggles every 2^23
    clock_divider #(.n(25)) u_bl24 (.clk(clk), .clk_div(blink24));   // toggles every 2^24

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
    assign mmask = (has_mole && blink23) ? (16'b1 << mole) : 16'b0;   // mole blinks

    always_comb begin
        case (state)
            IDLE:    led = hmask;
            PLAY:    led = hmask | mmask;
            default: led = blink24 ? 16'hFFFF : 16'h0000;
        endcase
    end

    // 7-seg: [time tens][time ones][score tens][score ones]; OVER shows "--" + score
    localparam logic [3:0] DASH = 4'd15;
    logic [15:0] nums;
    logic [3:0]  t_tens, t_ones;
    always_comb begin
        t_tens = (time_left >= 5'd20) ? 4'd2 : (time_left >= 5'd10) ? 4'd1 : 4'd0;
        t_ones = 4'(time_left - ((time_left >= 5'd20) ? 5'd20 : (time_left >= 5'd10) ? 5'd10 : 5'd0));
        nums   = {t_tens, t_ones, 4'(score / 10), 4'(score % 10)};   // "/" by a constant is fine here
        if (state == OVER) nums[15:8] = {DASH, DASH};
    end

    SevenSegment u_seg (.display(DISPLAY), .digit(DIGIT), .nums(nums), .rst(rst), .clk(clk));
endmodule

// ===================================================================
// Provided modules (given in the exam: clock_divider, debounce, one_pulse,
// SevenSegment). Pasted unchanged, except: SevenSegment got code 15 (-).
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
            4'd15: display = 7'b0111111;   // -  <- added for this problem
			default : display = 7'b1111111;
    	endcase
    end
endmodule

