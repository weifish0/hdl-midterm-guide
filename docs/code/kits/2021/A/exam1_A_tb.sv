// Self-made testbench in the style of the 2023 official one (2021 functions).
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
    logic mul_pass, concat_pass, shift_pass, minus_pass, feed_finish;

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
        if(mem[1] !== 36'h1_91_63_ff2e) begin
            $display(">>>>>>>>>>> [ERROR] Can not find pattern_A.dat, make sure you have added it to simulation source!");
            $finish;
        end

        mul_pass = 1'b1;
        concat_pass = 1'b1;
        shift_pass = 1'b1;
        minus_pass = 1'b1;
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
                    2'b10:
                        concat_pass = 1'b0;
                    2'b11:
                        shift_pass = 1'b0;
                    default:
                        minus_pass = 1'b0;
                endcase
            end
        end

        #(`CYCLE*20);
        scores = 0;

        if(mul_pass) begin
            scores = scores + 6;
            $display("Function 1 A*B          PASS!");
        end
        else begin
            $display("Function 1 A*B          FAIL!");
        end
        if(concat_pass) begin
            scores = scores + 6;
            $display("Function 2 {and,or}     PASS!");
        end
        else begin
            $display("Function 2 {and,or}     FAIL!");
        end
        if(shift_pass) begin
            scores = scores + 6;
            $display("Function 3 A>>>3        PASS!");
        end
        else begin
            $display("Function 3 A>>>3        FAIL!");
        end
        if(minus_pass) begin
            scores = scores + 6;
            $display("Function 4 A-B          PASS!");
        end
        else begin
            $display("Function 4 A-B          FAIL!");
        end

        if(feed_finish)
            $display("Pattern Score: %d/24", scores);
        else
            $display("<ERROR> Simulation time is not enough, please add it to 10000ps");

        $finish;
    end

endmodule
