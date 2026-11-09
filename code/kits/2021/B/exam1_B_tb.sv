`timescale 10ps/1ps
// Self-made testbench in the style of the 2023 official one (2021: reset -> 0, then 1, 3, 12, ...).
// pattern_B.dat: one line per clock cycle, "<phase>_<value>" in hex.
//   phase 0 = first count-up, 1 = first count-down, 2 = counting again
//   line 0 is the value expected while rst = 1.

`define PATTERN_NUM 1400
`define CYCLE 10
module exam1_B_tb;

    logic clk, rst;
    logic [19:0] result;
    logic [23:0] mem [0:`PATTERN_NUM-1];
    logic [3:0]  phase;
    logic [19:0] ans;
    logic up_pass, down_pass, again_pass;
    integer i, scores;

    initial begin
        clk = 1'b0;
        while(1) #(`CYCLE/2) clk = ~clk;
    end

    exam1_B CNT(
        .clk(clk),
        .rst(rst),
        .result(result)
    );

    initial begin
        $readmemh("pattern_B.dat", mem);
        if(^mem[1] === 1'bx) begin
            $display(">>>>>>>>>>> [ERROR] Can not find pattern_B.dat, make sure you have added it to simulation source!");
            $finish;
        end
        up_pass = 1'b1; down_pass = 1'b1; again_pass = 1'b1;

        rst = 1'b0;
        #(`CYCLE*5);
        @(negedge clk) rst = 1'b1;
        repeat(5) @(negedge clk);
        if(result !== mem[0][19:0]) begin
            $display("<ERROR> [reset] result=%0d, ans=%0d", result, mem[0][19:0]);
            up_pass = 1'b0;
        end
        rst = 1'b0;

        for(i = 1; i < `PATTERN_NUM; i = i+1) begin
            @(negedge clk);
            {phase, ans} = mem[i];
            if(result !== ans[19:0]) begin
                $display("<ERROR> [cycle %0d] result=%0d, ans=%0d", i, result, ans);
                case(phase)
                    4'd0: up_pass = 1'b0;
                    4'd1: down_pass = 1'b0;
                    default: again_pass = 1'b0;
                endcase
            end
        end

        scores = 0;
        if(up_pass)    begin scores = scores + 10; $display("Count Up                PASS!"); end
        else                                       $display("Count Up                FAIL!");
        if(down_pass)  begin scores = scores + 10; $display("Count Down              PASS!"); end
        else                                       $display("Count Down              FAIL!");
        if(again_pass) begin scores = scores + 10; $display("Count Again             PASS!"); end
        else                                       $display("Count Again             FAIL!");
        $display("Pattern Score: %d/30", scores);
        $finish;
    end

endmodule
