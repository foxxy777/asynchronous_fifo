`timescale 1ns/1ps
module tb_top();

// 参数重定义
parameter FIFO_DEPTH = 8;
parameter FIFO_WIDTH = 16;

// 接口声明
reg                      rst;
reg                      wr_clk;
reg                      wr_en;
reg     [FIFO_WIDTH-1:0] din;
wire                     full;

reg                      rd_clk;
reg                      rd_en;
wire    [FIFO_WIDTH-1:0] dout;
wire                     empty;

// 时钟参数
localparam WR_CLK_PERIOD = 10; // 100MHz写时钟
localparam RD_CLK_PERIOD = 15; // ~66.6MHz读时钟

// 测试控制变量
integer write_count = 0;
integer read_count = 0;
reg [FIFO_WIDTH-1:0] data_queue[$]; // 数据验证队列

// 实例化被测模块
top #(
    .FIFO_DEPTH(FIFO_DEPTH),
    .FIFO_WIDTH(FIFO_WIDTH)
) dut (
    .rst(rst),
    .wr_clk(wr_clk),
    .wr_en(wr_en),
    .din(din),
    .full(full),
    .rd_clk(rd_clk),
    .rd_en(rd_en),
    .dout(dout),
    .empty(empty)
);

initial begin
    // Initialize dump tasks
    $dumpfile("dump.vcd");  // Create a VCD file named "dump.vcd"
    $dumpvars;              // Record all signals in the design hierarchy
    // ... rest of the testbench code (reset, transactions, etc.)
end

// 时钟生成
initial begin
    wr_clk = 0;
    forever #(WR_CLK_PERIOD/2) wr_clk = ~wr_clk;
end

initial begin
    rd_clk = 0;
    forever #(RD_CLK_PERIOD/2) rd_clk = ~rd_clk;
end

// 复位控制
initial begin
    rst = 1;
    #100; // 延长复位时间确保跨时钟域同步
    rst = 0;
end

// 写操作任务
task automatic write_transaction;
    input integer num;
begin
    repeat(num) begin
        @(posedge wr_clk);
        #1; // 建立时间
        wr_en = 1;
        din = $urandom_range(0, (1<<FIFO_WIDTH)-1);
        data_queue.push_back(din);
        write_count++;
        @(posedge wr_clk);
        wr_en = 0;
        #5; // 随机写入间隔
    end
end
endtask

// 读操作任务
task automatic read_transaction;
    input integer num;
    reg [FIFO_WIDTH-1:0] expected;
begin
    repeat(num) begin
        @(posedge rd_clk);
        #1;
        rd_en = 1;
        @(posedge rd_clk);
        expected = data_queue.pop_front();
        if(dout !== expected) begin
            $error("[%t] 数据不匹配! 期望:0x%h 实际:0x%h", 
                $time, expected, dout);
        end
        read_count++;
        rd_en = 0;
        #7; // 随机读取间隔
    end
end
endtask

// 主测试流程
initial begin
    // 初始化信号
    wr_en = 0;
    rd_en = 0;
    din = 0;
    #200; // 等待复位完成
    
    // 测试场景1：连续写入直到满
    $display("===== 测试满状态 =====");
    while(!full) begin
        write_transaction(1);
    end
    $display("[%t] FIFO满状态达成，写入次数：%0d", $time, write_count);
    
    // 测试场景2：连续读取直到空
    $display("===== 测试空状态 =====");
    while(!empty) begin
        read_transaction(1);
    end
    $display("[%t] FIFO空状态达成，读取次数：%0d", $time, read_count);
    
    // 测试场景3：交叉读写测试
    $display("===== 交叉读写测试 =====");
    fork
        write_transaction(20);
        read_transaction(20);
    join
    
    // 测试场景4：边界条件测试
    $display("===== 边界条件测试 =====");
    repeat(3) begin
        write_transaction(FIFO_DEPTH-1);
        read_transaction(FIFO_DEPTH-1);
    end
    
    #100;
    $display("===== 所有测试完成 =====");
    $finish;
end

// 实时监控
always @(posedge wr_clk) begin
    if(wr_en && !full) begin
        $display("[%t] 写入数据：0x%h 写指针：%0d", 
            $time, din, dut.wr_add);
    end
end

always @(posedge rd_clk) begin
    if(rd_en && !empty) begin
        $display("[%t] 读取数据：0x%h 读指针：%0d", 
            $time, dout, dut.rd_add);
    end
end

endmodule