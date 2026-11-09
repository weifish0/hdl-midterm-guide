// Self-made testbench in the style of the 2023 official one (2022 functions).
`timescale 10ps/1ps

`define WIDTH 8
`define DELAY 10
`define PATTERN_NUM 800
`define CYCLE 10
module exam1_A_tb;

    logic clk, rst;
    logic signed [`WIDTH-1:0] A, B, last_A, last_B;
    logic [1:0] ctrl, last_ctrl;
    logic signed [`WIDTH*2-1:0] out;

    logic signed [`WIDTH*2-1:0] ans, last_ans;
    logic [35:0] mem [0:998];
    logic mul_pass, concat_pass, plus_pass, compare_pass, feed_finish;

    integer feed_i, fetch_i;
    integer scores;

    initial begin
        clk = 1'b0;
        while(1) #(`CYCLE/2) clk = ~clk;
    end

    exam1_A ALU(
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .ctrl(ctrl),
        .out(out)
    );

    initial begin
        // input feeding init
        $readmemh("pattern_A.dat", mem);
        if(mem[1] !== 36'h2_9f_53_ffff) begin
            $display(">>>>>>>>>>> [ERROR] Can not find pattern_A.dat, make sure you have added it to simulation source!");
            $finish;
        end

        mul_pass = 1'b1;
        concat_pass = 1'b1;
        plus_pass = 1'b1;
        compare_pass = 1'b1;
        feed_finish = 1'b0;

        #(`CYCLE*10);
        ctrl = {2{1'bz}};
        A = {`WIDTH{1'bz}};
        B = {`WIDTH{1'bz}};
        rst = 1'b1;
        #(`CYCLE*10);
        rst = 1'b0;

        // Feed input
        for(feed_i = 0; feed_i < `PATTERN_NUM; feed_i = feed_i+1) begin
            @(posedge clk);
            #1;
            {last_ctrl, last_A, last_B, last_ans} = {ctrl, A, B, ans};
            {ctrl, A, B, ans} = mem[feed_i][33:0];
        end
        feed_finish = 1'b1;

        // Input feeding stop
        #(`CYCLE*10);
        ctrl = {2{1'bz}};
        A = {`WIDTH{1'bz}};
        B = {`WIDTH{1'bz}};
    end

    initial begin
        wait(rst == 1'b1);
        wait(rst == 1'b0);

        // Check your design
        @(negedge clk);
        for(fetch_i = 0; fetch_i < `PATTERN_NUM-1; fetch_i = fetch_i+1) begin
            @(negedge clk);
            if(out !== last_ans) begin
                $display("<ERROR> [pattern %0d] ctrl=%b, A=%d, B=%d, out=%d, ans=%d", fetch_i, last_ctrl, last_A, last_B, out, last_ans);
                case(last_ctrl)
                    2'b00:
                        mul_pass = 1'b0;
                    2'b01:
                        concat_pass = 1'b0;
                    2'b11:
                        plus_pass = 1'b0;
                    default:
                        compare_pass = 1'b0;
                endcase
            end
        end

        #(`CYCLE*20);
        scores = 0;

        if(mul_pass) begin
            scores = scores + 8;
            $display("Function 1 A*(-B)       PASS!");
        end
        else begin
            $display("Function 1 A*(-B)       FAIL!");
        end
        if(concat_pass) begin
            scores = scores + 6;
            $display("Function 2 {xor,nor}    PASS!");
        end
        else begin
            $display("Function 2 {xor,nor}    FAIL!");
        end
        if(plus_pass) begin
            scores = scores + 8;
            $display("Function 3 A+B          PASS!");
        end
        else begin
            $display("Function 3 A+B          FAIL!");
        end
        if(compare_pass) begin
            scores = scores + 6;
            $display("Function 4 compare      PASS!");
        end
        else begin
            $display("Function 4 compare      FAIL!");
        end

        if(feed_finish)
            $display("Pattern Score: %d/28", scores);
        else
            $display("<ERROR> Simulation time is not enough, please add it to 10000ps");

        $finish;
    end

endmodule
