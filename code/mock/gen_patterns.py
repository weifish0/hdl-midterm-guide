"""Generate pattern files for the mock exam (Problem A and B).

python gen_patterns.py   ->  pattern_mock_A.dat, pattern_mock_B.dat
"""
import random

random.seed(2026)


# ---------------- Problem A ----------------
def alu(ctrl, a, b):
    if ctrl == 0:
        return a * a - b
    if ctrl == 1:
        return (((a | b) & 0xFF) << 8) | (~(a & b) & 0xFF)
    if ctrl == 2:
        return abs(a - b)
    return a >> (b & 7)          # Python >> on negative ints is arithmetic


edge = [-128, -127, -1, 0, 1, 127, 64, -64]
lines = []
for k in range(600):
    c = random.randrange(4)
    a = random.choice(edge) if k % 6 == 0 else random.randrange(-128, 128)
    b = random.choice(edge) if k % 5 == 0 else random.randrange(-128, 128)
    lines.append(f"{c:x}_{a & 0xFF:02x}_{b & 0xFF:02x}_{alu(c, a, b) & 0xFFFF:04x}")
open("pattern_mock_A.dat", "w").write("\n".join(lines) + "\n")

# ---------------- Problem B ----------------
stack = []
lines = []
for k in range(500):
    valid = 1 if random.random() < 0.85 else 0
    # bias toward pushes early, pops later, so full/empty both happen
    w = [5, 3, 1, 1] if (k // 60) % 2 == 0 else [2, 5, 1, 1]
    op = random.choices(range(4), weights=w)[0]
    data = random.randrange(256)
    out, err = 0, 0
    if valid:
        if op == 0:
            if len(stack) < 8:
                stack.append(data); out = data
            else:
                err = 1
        elif op == 1:
            if stack:
                out = stack.pop()
            else:
                err = 1
        elif op == 2:
            out = stack[-1] if stack else 0
        else:
            out = sum(stack) & 0xFF
    lines.append(f"{valid:x}_{op:x}_{data:02x}_{out:02x}_{len(stack):x}_{err:x}")
open("pattern_mock_B.dat", "w").write("\n".join(lines) + "\n")
print("done")
