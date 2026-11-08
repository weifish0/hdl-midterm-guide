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
