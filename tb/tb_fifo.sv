module tb_fifo();

  localparam DATA_WIDTH_OUT = 32;
  localparam DATA_WIDTH_IN  = 2 * DATA_WIDTH_OUT;
  localparam FIFO_DEPTH     = 16;
  localparam RAM_DEPTH      = FIFO_DEPTH / 2;
  int        CLK_PERIOD     = 5;

  logic clk;
  logic aresetn;

  logic [DATA_WIDTH_IN  - 1:0] s_tdata ;
  logic                        s_tvalid;
  logic                        s_tready;

  logic [DATA_WIDTH_OUT - 1:0] m_tdata1 ;
  logic                        m_tvalid1;
  logic                        m_tready1;
  logic                        m_tuser1 ;

  logic [DATA_WIDTH_OUT - 1:0] m_tdata2 ;
  logic                        m_tvalid2;
  logic                        m_tready2;
  logic                        m_tuser2 ;

  // TB reg model
  logic [DATA_WIDTH_OUT - 1: 0]    ram1 [$: RAM_DEPTH - 1];
  logic [DATA_WIDTH_OUT - 1: 0]    ram2 [$: RAM_DEPTH - 1];
  logic [DATA_WIDTH_OUT - 1: 0]    ref_tdata1;
  logic [DATA_WIDTH_OUT - 1: 0]    ref_tdata2;


  task automatic reset_gen();
    aresetn <= 1'b0;
    @(posedge clk);
    aresetn <= 1'b1;
  endtask

  task automatic axis_write(input logic [DATA_WIDTH_IN - 1:0] data);
    @(posedge clk);
    s_tvalid <= 1'b1;
    s_tdata  <= data;
    do begin
        @(posedge clk);
    end
    while(!s_tready);
    // Drop.
    s_tvalid <= 1'b0;
  endtask

  task push_data();
    logic [DATA_WIDTH_IN - 1:0] data;
    data = {$urandom, $urandom};
    axis_write(data);
  endtask

multi_port_fifo
  #(
  .DATA_WIDTH_OUT(DATA_WIDTH_OUT),
  .DATA_WIDTH_IN (DATA_WIDTH_IN ),
  .FIFO_DEPTH    (FIFO_DEPTH)
  )
  DUT (
  .aclk_i     (clk      ),
  .aresetn_i  (aresetn  ),

  .s_tdata_i  (s_tdata  ),
  .s_tvalid_i (s_tvalid ),
  .s_tready_o (s_tready ),

  .m_tdata1_o (m_tdata1 ),
  .m_tvalid1_o(m_tvalid1),
  .m_tready1_i(m_tready1),
  .m_tuser1_o (m_tuser1 ),

  .m_tdata2_o (m_tdata2 ),
  .m_tvalid2_o(m_tvalid2),
  .m_tready2_i(m_tready2),
  .m_tuser2_o (m_tuser2 )
);

  initial begin
    clk <= 1'b0;
    forever begin
      #CLK_PERIOD;
      clk <= ~clk;
    end
  end

  // Подача сброса, завершение симуляции
  initial begin
    reset_gen();
    repeat(600) @(posedge clk);
    $finish();
  end

  initial begin
    wait(aresetn);
    repeat(100) test_read_without_both();
  end

  // Блок отправки 64-битных транзакций
  // Будет отправлено случайное число транзакций,
  // после этого процессор должен поспать (спокойной ночи)
  initial begin
    int sleep_time, data_amount;

    s_tvalid  <= 1'b0;
    s_tdata   <=  'b0;
    m_tready1 <= 1'b0;
    m_tready2 <= 1'b0;
    wait(aresetn);

    forever begin
      sleep_time  = $urandom_range(0, 50);
      data_amount = $urandom_range(0, FIFO_DEPTH);
      repeat (data_amount) push_data();
      repeat (sleep_time ) @(posedge clk);
    end
  end

  initial begin
    forever begin
      if (s_tvalid && s_tready) begin
        ram1.push_front(s_tdata[DATA_WIDTH_IN/2 - 1 : 0]);
        ram2.push_front(s_tdata[DATA_WIDTH_IN   - 1 : DATA_WIDTH_IN/2]);
        $display($sformatf("Ram1 size is: %d", ram1.size()));
      end
      @(posedge clk);
    end
  end

  task read1();
    m_tready1 <= 1'b1;
    wait(m_tready1 && m_tvalid1);
    ref_tdata1 = ram1.pop_back();
    @(posedge clk);
    m_tready1 <= 1'b0;
  endtask
  task read2();
    m_tready2 <= 1'b1;
    wait(m_tready2 && m_tvalid2);
    ref_tdata2 = ram2.pop_back();
    @(posedge clk);
    m_tready2 <= 1'b0;
  endtask
  task read_last();
    if (m_tuser1)
      read1();
    else if (m_tuser2)
      read2();
  endtask
  task read_both();
    fork
      read1();
      read2();
    join
  endtask

  // Tests
  task test_read_without_both();
    read_last();
  endtask

  task test_read_both();
    wait(m_tvalid1 && m_tvalid2);
    read_both();
  endtask

  task test_read_random();
    bit is_both_read;
    std::randomize(is_both_read);

    if (is_both_read) begin
      wait(m_tvalid1 && m_tvalid2);
      read_both();
    end
    else begin
      read_last();
    end
  endtask

  // При заполненном FIFO сигнал tvalid не может быть в 1
  assert property (@(posedge clk) (ram1.size() == RAM_DEPTH || ram2.size() == RAM_DEPTH) |=> ~s_tready);

  // При чтении из FIFO данные соответствуют эталонной модели
  assert property
    (@(posedge clk) (m_tready1 && m_tvalid1) |-> ref_tdata1 === $sampled(m_tdata1))
  else
    $error("Ref data: %h not match act data: %h", ref_tdata1, $sampled(m_tdata1));

  // assert property
  //   (@(posedge clk) (m_tready2 && m_tvalid2) |-> ref_tdata2 === $sampled(m_tdata2))
  // else
  //   $error("Ref data: %h not match act data: %h", ref_tdata2, $sampled(m_tdata2));
endmodule
