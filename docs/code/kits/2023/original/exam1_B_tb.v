`timescale 10ps/1ps

`define WIDTH 12
`define DELAY 10
`define PATTERN_NUM 256
`define CYCLE 10
module exam1_B_tb;
    
    reg clk, rst;
    reg  [`WIDTH-1:0] data, last_data;
    wire  [7:0] decoded;
    wire  [2:0] out;

    reg  [7:0] decoded_ans, last_decoded_ans;
    reg  [2:0] ans, last_ans;
    reg [35:0] mem [0:998];
    reg decoded_pass, op_pass, feed_finish;

    integer feed_i, fetch_i;
    // integer file;
    integer scores;
    integer file;
    initial begin
        clk = 1'b0;
        while(1) #(`CYCLE/2) clk = ~clk;
    end

    exam1_B ALU(
        .clk(clk),
        .rst(rst),
        .data(data),
        .decoded(decoded),
        .out(out)
    );
    
    initial begin
        // input feeding init
        //$readmemh("pattern_B.dat", mem);
        file = $fopen("pattern_B.dat", "r");
        if(!file) begin
            $display(">>>>>>>>>>> [ERROR] Can not find patter_B.dat, make sure you have added it to simulation source!");
            $finish;
        end

        decoded_pass = 1'b1;
        op_pass = 1'b1;
        feed_finish =1'b0;
        #(`CYCLE*10);
        data = {`WIDTH{1'bz}};
        rst = 1'b1;
        #(`CYCLE*10);
        rst = 1'b0;

        // Feed addition input
        for(feed_i = 0; feed_i < `PATTERN_NUM; feed_i = feed_i+1) begin
            @(posedge clk);
            #1;
            {last_data, last_decoded_ans, last_ans} = { data, decoded_ans, ans}; 
            $fscanf(file,"%b %b %b" ,data, decoded_ans, ans);
        end 
        feed_finish = 1'b1;

        // Input feeding stop
        #(`CYCLE*10);
        data = {`WIDTH{1'bz}};
    end

    initial begin
        wait(rst == 1'b1);
        wait(rst == 1'b0);
        
        // Check your design
        @(negedge clk);
        for(fetch_i = 0; fetch_i < `PATTERN_NUM-1; fetch_i = fetch_i+1) begin
            @(negedge clk);
            if(out !== last_ans||decoded!==last_decoded_ans) begin
                $display("<ERROR> [pattern %0d] data=%b, decoded=%b, decoded_ans=%b, out=%d, ans=%d", fetch_i,  last_data, decoded,last_decoded_ans,out, last_ans);
                if(out !== last_ans)
                    op_pass  = 1'b0;
                if(decoded!==last_decoded_ans)
                    decoded_pass = 1'b0;
                
            end
        end 

        #(`CYCLE*20);
        scores = 0;

        // Check function 1
        if(decoded_pass) begin
            scores = scores + 20;
            $display("Function 1              PASS!");
        end
        else begin
            $display("Function 1              FAIL!");
        end

        // Check function 2
        if(op_pass) begin
            scores = scores + 10;
            $display("Function 2              PASS!");
        end
        else begin
            $display("Function 2              FAIL!");
        end
        

        // Output current score
        if(feed_finish)
            $display("Pattern Score: %d/30", scores);
        else
            $display("<ERROR> Simulation time is not enough, please add it to 10000ps");

        $finish;
    end

endmodule