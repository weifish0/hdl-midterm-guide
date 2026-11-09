"""Generate the per-problem starter kits in code/kits/.

Each kit has what the exam hands out: an SV template (I/O only), and either
testbench + pattern file (simulation problems) or an XDC (FPGA problems).

  2023: built from the teacher's original files (templates and testbenches
        converted from Verilog to SystemVerilog; patterns and XDC unchanged).
        The originals are kept in kits/2023/original/.
  2021, 2022, mock: the teacher's files were not available, so the testbenches
        follow the style of the 2023 official ones, patterns come from Python
        reference models of the problem rules, and the XDC is the 2023 XDC
        with the port list adjusted.

usage:  python tools/make_kits.py <path to 11210 mid code folder>
"""
import random
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KITS = ROOT / "code" / "kits"
ORIG = Path(sys.argv[1])
PROVIDED = (ROOT / "code/common/provided.sv").read_text(encoding="utf-8")
PROVIDED_BODY = PROVIDED[PROVIDED.index("module clock_divider"):]


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.replace("\r\n", "\n"), encoding="utf-8", newline="\n")


def to_sv(verilog):
    """Minimal Verilog -> SystemVerilog conversion for the testbenches: reg/wire -> logic."""
    s = verilog.replace("\r\n", "\n")
    s = re.sub(r"\breg\b", "logic", s)
    s = re.sub(r"\bwire\b", "logic", s)
    return s


HEADER_ID = "// <Student_ID> <Name>\n// Add your ID and name to the FIRST line of the file, or you will get a 5-point penalty\n`timescale 1ns/1ps\n"

# ---------------------------------------------------------------- templates
TPL_A = HEADER_ID + """
`define WIDTH 8

module exam1_A (
    input  logic clk,
    input  logic rst,
    input  logic [`WIDTH-1:0] A,
    input  logic [`WIDTH-1:0] B,
    input  logic [1:0] ctrl,
    output logic [`WIDTH*2-1:0] out
);
    // Hint: declare signals as "signed" to get signed operations, e.g.
    //   logic signed [7:0] data;

endmodule
"""

TPL_B_2023 = HEADER_ID + """
`define WIDTH 12

module exam1_B (
    input  logic clk,
    input  logic rst,
    input  logic [`WIDTH-1:0] data,
    output logic [7:0] decoded,
    output logic [2:0] out
);

endmodule
"""

TPL_B_2022 = HEADER_ID + """
module exam1_B (
    input  logic        clk,
    input  logic        rst,
    output logic [15:0] out
);
    // "/" is forbidden in count-up, "%" is forbidden in count-down.

endmodule
"""

TPL_B_2021 = HEADER_ID + """
module exam1_B (
    input  logic        clk,
    input  logic        rst,
    output logic [19:0] result
);

endmodule
"""

C_PORTS_2223 = """    input  logic clk,      // 100 MHz
    input  logic rst,      // btnC
    input  logic en,       // btnR
    input  logic set,      // btnL
    input  logic up,       // btnU
    input  logic down,     // btnD
    input  logic [15:0] sw,
    output logic [3:0]  DIGIT,
    output logic [6:0]  DISPLAY,
    output logic [15:0] led"""

C_PORTS_2021 = """    input  logic clk,        // 100 MHz
    input  logic rst_btn,    // btnC
    input  logic start_btn,  // btnL
    input  logic [15:0] sw,
    output logic [3:0]  DIGIT,
    output logic [6:0]  DISPLAY,
    output logic [15:0] led"""

C_PORTS_MOCK = """    input  logic clk,      // 100 MHz
    input  logic rst,      // btnC
    input  logic btnL,
    input  logic btnR,
    input  logic btnU,
    input  logic btnD,
    output logic [3:0]  DIGIT,
    output logic [6:0]  DISPLAY,
    output logic [15:0] led"""


def tpl_c(name, ports):
    return (HEADER_ID + f"\nmodule {name} (\n{ports}\n);\n    // Your design here\n\nendmodule\n\n"
            "// ===================================================================\n"
            "// Provided modules. You may modify them if needed (e.g. add letters to\n"
            "// SevenSegment). Every module you use must stay in THIS file.\n"
            "// ===================================================================\n\n" + PROVIDED_BODY)


# ---------------------------------------------------------------- XDC
XDC_2023 = (ORIG / "exam1_C.xdc").read_text(encoding="utf-8").replace("\r\n", "\n")


def xdc_for(ports, rename):
    """Comment out constraints of ports the design does not have; rename button ports."""
    out = []
    for line in XDC_2023.split("\n"):
        m = re.search(r"get_ports\s+\{?(\w+)", line)
        if m and not line.lstrip().startswith("#"):
            port = m.group(1)
            if port in rename:
                line = re.sub(rf"\b{port}\b", rename[port], line)
                port = rename[port]
            if port not in ports:
                line = "#" + line
        out.append(line)
    return "\n".join(out)


# ---------------------------------------------------------------- A testbench (2023 style)
def tb_a(magic, mapping, weights, total):
    """mapping: list of (case label, flag name, title) in order; last one is default."""
    flags = [f for _, f, _ in mapping]
    case_lines = "\n".join(
        f"                    {lab}:\n                        {f} = 1'b0;" for lab, f, _ in mapping)
    checks = "\n".join(f"""        if({f}) begin
            scores = scores + {w};
            $display("{t:<24}PASS!");
        end
        else begin
            $display("{t:<24}FAIL!");
        end""" for (_, f, t), w in zip(mapping, weights))
    return f"""`timescale 10ps/1ps

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
    logic {", ".join(flags)}, feed_finish;

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
        if(mem[1] !== 36'h{magic}) begin
            $display(">>>>>>>>>>> [ERROR] Can not find pattern_A.dat, make sure you have added it to simulation source!");
            $finish;
        end

{chr(10).join(f"        {f} = 1'b1;" for f in flags)}
        feed_finish = 1'b0;

        #(`CYCLE*10);
        ctrl = {{2{{1'bz}}}};
        A = {{`WIDTH{{1'bz}}}};
        B = {{`WIDTH{{1'bz}}}};
        rst = 1'b1;
        #(`CYCLE*10);
        rst = 1'b0;

        // Feed input
        for(feed_i = 0; feed_i < `PATTERN_NUM; feed_i = feed_i+1) begin
            @(posedge clk);
            #1;
            {{last_ctrl, last_A, last_B, last_ans}} = {{ctrl, A, B, ans}};
            {{ctrl, A, B, ans}} = mem[feed_i][33:0];
        end
        feed_finish = 1'b1;

        // Input feeding stop
        #(`CYCLE*10);
        ctrl = {{2{{1'bz}}}};
        A = {{`WIDTH{{1'bz}}}};
        B = {{`WIDTH{{1'bz}}}};
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
{case_lines.replace("                    " + mapping[-1][0] + ":", "                    default:")}
                endcase
            end
        end

        #(`CYCLE*20);
        scores = 0;

{checks}

        if(feed_finish)
            $display("Pattern Score: %d/{total}", scores);
        else
            $display("<ERROR> Simulation time is not enough, please add it to 10000ps");

        $finish;
    end

endmodule
"""


# ---------------------------------------------------------------- B testbench for counters
def tb_counter(port, width, n_lines, note):
    return f"""`timescale 10ps/1ps
// Self-made testbench in the style of the 2023 official one ({note}).
// pattern_B.dat: one line per clock cycle, "<phase>_<value>" in hex.
//   phase 0 = first count-up, 1 = first count-down, 2 = counting again
//   line 0 is the value expected while rst = 1.

`define PATTERN_NUM {n_lines}
`define CYCLE 10
module exam1_B_tb;

    logic clk, rst;
    logic [{width - 1}:0] {port};
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
        .{port}({port})
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
        if({port} !== mem[0][{width - 1}:0]) begin
            $display("<ERROR> [reset] {port}=%0d, ans=%0d", {port}, mem[0][19:0]);
            up_pass = 1'b0;
        end
        rst = 1'b0;

        for(i = 1; i < `PATTERN_NUM; i = i+1) begin
            @(negedge clk);
            {{phase, ans}} = mem[i];
            if({port} !== ans[{width - 1}:0]) begin
                $display("<ERROR> [cycle %0d] {port}=%0d, ans=%0d", i, {port}, ans);
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
"""


# ---------------------------------------------------------------- reference models
def s8(x):
    return x - 256 if x > 127 else x


def alu_patterns(f, seed):
    rnd = random.Random(seed)
    edge = [-128, -127, -1, 0, 1, 127, 126, -2, 64, -64]
    lines = []
    for k in range(800):
        c = rnd.randrange(4)
        a = rnd.choice(edge) if k % 5 == 0 else rnd.randrange(-128, 128)
        b = rnd.choice(edge) if k % 7 == 0 else rnd.randrange(-128, 128)
        lines.append(f"{c:x}_{a & 255:02x}_{b & 255:02x}_{f(c, a, b) & 0xFFFF:04x}")
    return lines


def f2021(c, a, b):
    if c == 0: return a * b
    if c == 2: return ((a & b) & 255) << 8 | ((a | b) & 255)
    if c == 3: return a >> 3
    return a - b


def f2022(c, a, b):
    if c == 0: return a * (-b)
    if c == 1: return ((a ^ b) & 255) << 8 | (~(a | b) & 255)
    if c == 3: return a + b
    return -1 if a < b else 1


def seq2021(n):
    out, cur, i, up = [0], 0, 1, True
    for _ in range(n - 1):
        if up:
            cur = cur + 3 * i if cur % 8 == i % 8 else cur + i
            if cur >= 183921: up, i = False, 1
            else: i += 1
        else:
            if cur <= i: cur, up, i = 0, True, 1
            else: cur, i = cur - i, i + 1
        out.append(cur)
    return out


def seq2022(n):
    p, c, i, up = 0, 0, 1, True
    out = [0]
    for _ in range(n - 1):
        if up and c == 0:
            p, c, i = 0, 1, 1
        else:
            s = p + c
            if up:
                nx = (s // 2 * 3 if s < 16384 else c + i) if s % 4 == 0 else (c + 4 if i % 2 else c + 1)
            else:
                nx = c >> (i % 4) if s % 8 == i % 8 else max(c - 6 * i, 0)
            p, c = c, nx
            if up and nx == 65176: up, i = False, 1
            elif not up and nx == 0: up, i = True, 1
            else: i += 1
        out.append(c)
    return out


def phased(seq, top):
    """phase 0 until the first top value, 1 until the following 0, 2 afterwards."""
    lines, phase = [], 0
    for k, v in enumerate(seq):
        lines.append(f"{phase:x}_{v:05x}")
        if phase == 0 and v == top: phase = 1
        elif phase == 1 and v == 0: phase = 2
    return lines


# ---------------------------------------------------------------- build
def main():
    if KITS.exists():
        shutil.rmtree(KITS)

    # ----- 2023 (official)
    k = KITS / "2023"
    for f in ["exam1_A.v", "exam1_A_tb.v", "pattern_A.dat", "exam1_B.v", "exam1_B_tb.v",
              "pattern_B.dat", "exam1_C.v", "exam1_C.xdc"]:
        (k / "original").mkdir(parents=True, exist_ok=True)
        shutil.copy(ORIG / f, k / "original" / f)
    write(k / "A/exam1_A.sv", TPL_A)
    write(k / "A/exam1_A_tb.sv", "// Official 2023 testbench, converted to SystemVerilog (reg/wire -> logic).\n"
          + to_sv((ORIG / "exam1_A_tb.v").read_text(encoding="utf-8")))
    shutil.copy(ORIG / "pattern_A.dat", k / "A/pattern_A.dat")
    write(k / "B/exam1_B.sv", TPL_B_2023)
    write(k / "B/exam1_B_tb.sv", "// Official 2023 testbench, converted to SystemVerilog (reg/wire -> logic).\n"
          + to_sv((ORIG / "exam1_B_tb.v").read_text(encoding="utf-8")))
    shutil.copy(ORIG / "pattern_B.dat", k / "B/pattern_B.dat")
    write(k / "C/exam1_C.sv", tpl_c("exam1_C", C_PORTS_2223))
    write(k / "C/exam1_C.xdc", XDC_2023)

    # ----- 2022 (self-made)
    k = KITS / "2022"
    pa = alu_patterns(f2022, 2022)
    write(k / "A/exam1_A.sv", TPL_A)
    write(k / "A/pattern_A.dat", "\n".join(pa) + "\n")
    write(k / "A/exam1_A_tb.sv", "// Self-made testbench in the style of the 2023 official one (2022 functions).\n" + tb_a(
        pa[1], [("2'b00", "mul_pass", "Function 1 A*(-B)"), ("2'b01", "concat_pass", "Function 2 {xor,nor}"),
                ("2'b11", "plus_pass", "Function 3 A+B"), ("other", "compare_pass", "Function 4 compare")],
        [8, 6, 8, 6], 28))
    sb = phased(seq2022(700), 65176)
    write(k / "B/exam1_B.sv", TPL_B_2022)
    write(k / "B/pattern_B.dat", "\n".join(sb) + "\n")
    write(k / "B/exam1_B_tb.sv", tb_counter("out", 16, len(sb), "2022: reset -> 0, then 1, 5, 6, ..."))
    write(k / "C/exam1_C.sv", tpl_c("exam1_C", C_PORTS_2223))
    write(k / "C/exam1_C.xdc", XDC_2023)

    # ----- 2021 (self-made)
    k = KITS / "2021"
    pa = alu_patterns(f2021, 2021)
    write(k / "A/exam1_A.sv", TPL_A)
    write(k / "A/pattern_A.dat", "\n".join(pa) + "\n")
    write(k / "A/exam1_A_tb.sv", "// Self-made testbench in the style of the 2023 official one (2021 functions).\n" + tb_a(
        pa[1], [("2'b00", "mul_pass", "Function 1 A*B"), ("2'b10", "concat_pass", "Function 2 {and,or}"),
                ("2'b11", "shift_pass", "Function 3 A>>>3"), ("other", "minus_pass", "Function 4 A-B")],
        [6, 6, 6, 6], 24))
    sb = phased(seq2021(1400), 183921)
    write(k / "B/exam1_B.sv", TPL_B_2021)
    write(k / "B/pattern_B.dat", "\n".join(sb) + "\n")
    write(k / "B/exam1_B_tb.sv", tb_counter("result", 20, len(sb), "2021: reset -> 0, then 1, 3, 12, ..."))
    write(k / "C/exam1_C.sv", tpl_c("exam1_C", C_PORTS_2021))
    write(k / "C/exam1_C.xdc", xdc_for({"clk", "rst_btn", "start_btn", "sw", "led", "DIGIT", "DISPLAY"},
                                       {"rst": "rst_btn", "set": "start_btn"}))

    # ----- mock exam
    k = KITS / "mock"
    mock = ROOT / "code/mock"
    write(k / "A/mock_A.sv", HEADER_ID + "\nmodule mock_A (\n    input  logic               clk,\n    input  logic               rst,\n"
          "    input  logic signed [7:0]  A,\n    input  logic signed [7:0]  B,\n    input  logic        [1:0]  ctrl,\n"
          "    output logic signed [15:0] out\n);\n\nendmodule\n")
    shutil.copy(mock / "mock_A_tb.sv", k / "A/mock_A_tb.sv")
    shutil.copy(mock / "pattern_mock_A.dat", k / "A/pattern_mock_A.dat")
    write(k / "B/mock_B.sv", HEADER_ID + "\nmodule mock_B (\n    input  logic       clk,\n    input  logic       rst,\n"
          "    input  logic       valid,\n    input  logic [1:0] op,\n    input  logic [7:0] data,\n"
          "    output logic [7:0] out,\n    output logic [3:0] cnt,\n    output logic       err\n);\n"
          "    logic [7:0] mem [0:7];\n\nendmodule\n")
    shutil.copy(mock / "mock_B_tb.sv", k / "B/mock_B_tb.sv")
    shutil.copy(mock / "pattern_mock_B.dat", k / "B/pattern_mock_B.dat")
    write(k / "C/mock_C.sv", tpl_c("mock_C", C_PORTS_MOCK))
    write(k / "C/mock_C.xdc", xdc_for({"clk", "rst", "btnL", "btnR", "btnU", "btnD", "led", "DIGIT", "DISPLAY"},
                                      {"set": "btnL", "en": "btnR", "up": "btnU", "down": "btnD"}))
    print("kits written to", KITS)


if __name__ == "__main__":
    main()
