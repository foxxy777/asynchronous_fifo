module top #(
    parameter FIFO_DEPTH = 8,
    parameter FIFO_WIDTH = 16

) (
    input                       rst,
    input                       wr_clk,
    input                       wr_en,
    input      [FIFO_WIDTH-1:0] din,
    output reg                  full,

    input                       rd_clk,
    input                       rd_en,
    output     [FIFO_WIDTH-1:0] dout,
    output reg                  empty
);

  //定义: [15:0] mem [7:0] 深度为 8 entry
  reg [FIFO_WIDTH-1:0] mem[FIFO_DEPTH-1:0];
  //8entry 正常Index只要3bit，这里为了方便格雷码判断空满，用了4bit
  reg [3:0] wr_add;
  wire [3:0] wr_add_next;
  wire [3:0] wr_add_gray_next;
  reg [3:0] wp, wr1_rp, wr2_rp;

  reg  [3:0] rd_add;
  wire [3:0] rd_add_next;
  wire [3:0] rd_add_gray_next;
  reg [3:0] rp, rd1_wp, rd2_wp;

  wire full_r;
  wire empty_r;

  //输入数据
  always @(posedge wr_clk) begin
    if (wr_en && !full) mem[wr_add] <= din;
    else mem[wr_add] <= 16'h0000;
  end

  //输出数据
  assign dout = mem[rd_add];

  //写时钟域
  assign wr_add_next = wr_add + (wr_en & ~full);
  assign wr_add_gray_next = (wr_add_next >> 1) ^ wr_add_next;
  always @(posedge wr_clk or posedge rst) begin
    if (rst) {wr_add, wp} <= {4'b0000, 4'b0000};
    else {wr_add, wp} <= {wr_add_next, wr_add_gray_next};

  end

  //读时钟域
  assign rd_add_next = rd_add + (rd_en & ~empty);
  assign rd_add_gray_next = (rd_add_next >> 1) ^ rd_add_next;
  always @(posedge rd_clk or posedge rst) begin
    if (rst) {rd_add, rp} <= {4'b0000, 4'b0000};
    else {rd_add, rp} <= {rd_add_next, rd_add_gray_next};
  end

  //读指针同步到写时钟域
  always @(posedge wr_clk or posedge rst) begin
    if (rst) {wr2_rp, wr1_rp} <= {4'b0000, 4'b0000};
    else {wr2_rp, wr1_rp} <= {wr1_rp, rp};

  end

  //写时钟同步到读时钟域
  always @(posedge rd_clk or posedge rst) begin
    if (rst) {rd2_wp, rd1_wp} <= {4'b0000, 4'b0000};
    else {rd2_wp, rd1_wp} <= {rd1_wp, wp};
  end

  //空信号判断
  //读写指针格雷码完全相同，则空
  assign empty_r = (rd2_wp == rd_add_gray_next) ? 1 : 0;
  always @(posedge rd_clk or posedge rst) begin
    if (rst) empty <= 1'b1;
    else empty <= empty_r;
  end

  //满信号判断
  //读写指针格雷码最高2位相反，其它地位完全相同，则满
  assign full_r = (~wr2_rp[3:2] == wr_add_gray_next[3:2]) ? 1 : 0;
  always @(posedge wr_clk or posedge rst) begin
    if (rst) full <= 1'b0;
    else full <= full_r;
  end

endmodule
