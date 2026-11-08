// Testbench for Mock Problem A. Add pattern_mock_A.dat to the simulation sources.
`timescale 1ns/1ps
module mock_A_tb;
    localparam int N = 600;
    logic clk = 1'b0, rst;
    logic signed [7:0]  A, B;
    logic        [1:0]  ctrl;
    logic signed [15:0] out;
    logic        [15:0] exp_q;
    logic [35:0] mem [0:N-1];
    int err = 0;
    int fail [4] = '{0, 0, 0, 0};

    mock_A dut (.*);
    always #5 clk = ~clk;

    initial begin
        $readmemh("pattern_mock_A.dat", mem);
        if (^mem[0] === 1'bx) begin
            $display(">>> [ERROR] pattern_mock_A.dat not found (add it to simulation sources)");
            $finish;
        end
        rst = 1'b1; A = 0; B = 0; ctrl = 0;
        repeat (3) @(negedge clk);
        if (out !== 16'd0) begin $display("<ERROR> synchronous reset"); err++; end
        rst = 1'b0;
        for (int k = 0; k < N; k++) begin
            {ctrl, A, B, exp_q} = {mem[k][33:32], mem[k][31:24], mem[k][23:16], mem[k][15:0]};
            @(negedge clk);                  // result is registered at the posedge in between
            if (out !== exp_q) begin
                err++; fail[ctrl]++;
                if (err <= 10)
                    $display("<ERROR> ctrl=%b A=%0d B=%0d  out=%0d  expected=%0d",
                             ctrl, A, B, out, $signed(exp_q));
            end
        end
        for (int f = 0; f < 4; f++)
            $display("Function %0d (ctrl=%b) %s", f + 1, f[1:0], fail[f] == 0 ? "PASS!" : "FAIL!");
        if (err == 0) $display("==== Mock A: ALL PASS ====");
        $finish;
    end
endmodule
