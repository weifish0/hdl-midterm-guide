# HDL Exam 1 Prep

硬體設計與實驗（Hardware Design and Lab）期中上機考的自學網站：SystemVerilog 教學、Lab 1–5 回顧、2021–2023 考古題詳解、模擬考與觀念測驗。

網站：https://weifish0.github.io/hdl-midterm-guide/

## 內容

| 頁面 | 內容 |
|---|---|
| 總覽 | 考試格式、規則、讀書路線、時間分配 |
| SystemVerilog 語法 | logic、寬度、有號數、always_comb / always_ff、Verilog 對照 |
| 設計模式 | FSM、tick、按鈕去彈跳、LFSR、記憶體、不用 / % 的技巧 |
| FPGA 實作 | Basys3 腳位、七段顯示器、C 題架構、Vivado 流程、常見錯誤 |
| 模擬與 Testbench | testbench 結構、pattern 檔、考試 testbench 的時序 |
| Lab 1–5 | 每個 practice 的重點與解答 |
| 歷屆考題 | 2021–2023 A/B/C 九題 |
| 模擬考 | 三題新題目 + testbench、20 題觀念測驗、程式預測題 |
| 考場速查 | 骨架、規則、編碼表、交卷檢查 |

## 驗證

- `code/exam2023/exam1_A.sv`、`exam1_B.sv`：助教原始 testbench 與 pattern，28/28、30/30。
- `code/exam2021`、`code/exam2022` 的 A、B：依題目規則的 Python 參考模型產生 pattern，xsim 全對。
- 三年的 `exam1_C.sv`：Vivado 2022.1 合成成功、無 latch；縮短時間的模擬檢查過題目範例情境。沒有上板實測。
- `code/labs`：Lab 1、2、5 通過課程 testbench；Lab 3、4 通過編譯。
- `code/mock`：A、B 通過附的 testbench；C 通過模擬檢查。

## 建置

```bash
python build.py      # src/pages/*.html -> docs/*.html，並把 code/ 複製到 docs/code/
```

GitHub Pages 從 `main` 分支的 `/docs` 發布。
