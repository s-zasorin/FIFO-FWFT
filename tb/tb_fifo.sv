module tb_fifo();

  localparam DATA_WIDTH_OUT = 32;
  localparam DATA_WIDTH_IN  = 2 * DATA_WIDTH_OUT;
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

  task automatic reset_gen();
    aresetn <= 1'b0;
    #(2*CLK_PERIOD);
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
    repeat(10) begin
      logic [DATA_WIDTH_IN - 1:0] data;
      data = {$urandom, $urandom};
      axis_write(data);
    end
  endtask

multi_port_fifo
  #(
  .DATA_WIDTH_OUT(DATA_WIDTH_OUT),
  .DATA_WIDTH_IN (DATA_WIDTH_IN )
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
    
  // Тесты.

  initial begin
    s_tvalid  <= 1'b0;
    s_tdata   <=  'b0;
    m_tready1 <= 1'b0;
    m_tready2 <= 1'b0;
    reset_gen();
    // Тесты.
    push_data ();
    repeat (40) @(posedge clk);
    push_data ();
    $finish();
  end

  initial begin
    repeat (5) @(posedge clk);
    m_tready1 <= 1'b1;
    @(posedge clk);
    repeat(15) begin
      m_tready1 <= ~m_tready1;
      @(posedge clk);
    end
  end

  initial begin
    repeat (6) @(posedge clk);
    repeat(15) begin
      m_tready2 <= ~m_tready2;
      @(posedge clk);
    end
  end
endmodule