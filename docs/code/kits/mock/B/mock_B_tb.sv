// Testbench for Mock Problem B. Add pattern_mock_B.dat to the simulation sources.
// Each pattern line (hex): valid_op_data_out_cnt_err  ->  32 bits
//   [31:28] valid  [27:24] op  [23:16] data  [15:8] out  [7:4] cnt  [3:0] err
`timescale 1ns/1ps
module mock_B_tb;
    localparam int N = 500;
    logic clk = 1'b0, rst, valid, err;
    logic [1:0] op;
    logic [7:0] data, out, exp_out;
    logic [3:0] cnt, exp_cnt;
    logic       exp_err;
    logic [31:0] raw [0:N-1];
    int errors = 0;

    mock_B dut (.*);
    always #5 clk = ~clk;

    initial begin
        $readmemh("pattern_mock_B.dat", raw);
        if (^raw[0] === 1'bx) begin
            $display(">>> [ERROR] pattern_mock_B.dat not found (add it to simulation sources)");
            $finish;
        end
        rst = 1'b1; valid = 0; op = 0; data = 0;
        repeat (3) @(negedge clk);
        if (out !== 0 || cnt !== 0 || err !== 0) begin $display("<ERROR> reset"); errors++; end
        rst = 1'b0;
        for (int k = 0; k < N; k++) begin
            valid   = raw[k][28];
            op      = raw[k][25:24];
            data    = raw[k][23:16];
            exp_out = raw[k][15:8];
            exp_cnt = raw[k][7:4];
            exp_err = raw[k][0];
            @(negedge clk);              // the DUT updates at the posedge in between
            if (out !== exp_out || cnt !== exp_cnt || err !== exp_err) begin
                errors++;
                if (errors <= 10)
                    $display("<ERROR> #%0d valid=%b op=%b data=%0d | out=%0d cnt=%0d err=%b | expected out=%0d cnt=%0d err=%b",
                             k, valid, op, data, out, cnt, err, exp_out, exp_cnt, exp_err);
            end
        end
        if (errors == 0) $display("==== Mock B: ALL PASS (%0d patterns) ====", N);
        else             $display("==== Mock B: %0d errors ====", errors);
        $finish;
    end
endmodule
