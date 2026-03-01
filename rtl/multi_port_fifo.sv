module multi_port_fifo #(parameter DATA_WIDTH_OUT = 8                 ,
                        parameter  DATA_WIDTH_IN  = 2 * DATA_WIDTH_OUT,
                        parameter  FIFO_DEPTH     = 16) (

  input  logic                        aclk_i    ,
  input  logic                        aresetn_i ,   

  // Slave Interface
  input  logic [DATA_WIDTH_IN  - 1:0] s_tdata_i  ,
  input  logic                        s_tvalid_i ,
  output logic                        s_tready_o ,

  // Master Interface 1
  output logic [DATA_WIDTH_OUT - 1:0] m_tdata1_o ,
  output logic                        m_tvalid1_o,
  input  logic                        m_tready1_i,
  output logic                        m_tuser1_o ,

  // Master Interface 2
  output logic [DATA_WIDTH_OUT - 1:0] m_tdata2_o ,
  output logic                        m_tvalid2_o,
  input  logic                        m_tready2_i,
  output logic                        m_tuser2_o 
);

  localparam ONE_RAM_DEPTH = FIFO_DEPTH / 2;
  localparam PTR_WIDTH     = $clog2(ONE_RAM_DEPTH);

  logic [DATA_WIDTH_OUT - 1:0] data_in1        ;
  logic [DATA_WIDTH_OUT - 1:0] data_in2        ;
  logic [PTR_WIDTH         :0] wr_ptr1         ;
  logic [PTR_WIDTH         :0] wr_ptr2         ;
  logic [PTR_WIDTH         :0] rd_ptr1         ;
  logic [PTR_WIDTH         :0] rd_ptr2         ;
  logic [DATA_WIDTH_OUT - 1:0] data_ram_out1   ;
  logic [DATA_WIDTH_OUT - 1:0] data_ram_out2   ;
  logic [DATA_WIDTH_OUT - 1:0] head_reg1       ;
  logic [DATA_WIDTH_OUT - 1:0] head_reg2       ;

  logic                        full            ;
  logic                        full1           ;
  logic                        full2           ;
  logic                        empty_ram       ;
  logic                        empty1          ;
  logic                        empty2          ;
  logic                        bypass_en1      ; // управляет мультиплексором на выходном порте №1
  logic                        bypass_en2      ; // управляет мультиплексором на выходном порте №2
  logic                        m_handshake1    ;
  logic                        m_handshake2    ;
  logic                        s_handshake     ;
  logic                        enable_head_reg1; // разрешение на запись в head register №1
  logic                        enable_head_reg2; // разрешение на запись в head register №2
  logic                        almost_empty1   ; // почти пуст по первому порту
  logic                        almost_empty2   ; // почти пуст по второму порту
  logic                        wr_en1          ; // запись в RAM память №1
  logic                        wr_en2          ; // запись в RAM память №2
  logic                        rd_en1          ; // чтение из RAM памяти №1
  logic                        rd_en2          ; // чтение из RAM памяти №2

  assign data_in1         = s_tdata_i[DATA_WIDTH_OUT - 1:0];
  assign data_in2         = s_tdata_i[DATA_WIDTH_IN  - 1: DATA_WIDTH_OUT];

  assign full1            = wr_ptr1[PTR_WIDTH - 1:0] == rd_ptr1[PTR_WIDTH - 1:0] && (wr_ptr1[PTR_WIDTH] != rd_ptr1[PTR_WIDTH]);
  assign full2            = wr_ptr2[PTR_WIDTH - 1:0] == rd_ptr2[PTR_WIDTH - 1:0] && (wr_ptr2[PTR_WIDTH] != rd_ptr2[PTR_WIDTH]);
  assign empty1           = wr_ptr1[PTR_WIDTH - 1:0] == rd_ptr1[PTR_WIDTH - 1:0] && (wr_ptr1[PTR_WIDTH] == rd_ptr1[PTR_WIDTH]);
  assign empty2           = wr_ptr2[PTR_WIDTH - 1:0] == rd_ptr2[PTR_WIDTH - 1:0] && (wr_ptr2[PTR_WIDTH] == rd_ptr2[PTR_WIDTH]);

  assign almost_empty1    = empty1 && bypass_en1 || (wr_ptr1 == 'b1 && wr_ptr1 != rd_ptr1);
  assign almost_empty2    = empty2 && bypass_en2 || (wr_ptr2 == 'b1 && wr_ptr2 != rd_ptr2);

  assign full             = full1 || full2  ;
  assign empty_ram        = empty1 && empty2;

  assign m_handshake1     = m_tvalid1_o && m_tready1_i;
  assign m_handshake2     = m_tvalid2_o && m_tready2_i;
  assign s_handshake      = s_tvalid_i  && s_tready_o ;

  assign s_tready_o       = ~full;
  assign m_tvalid1_o      = ~empty1 || bypass_en1;
  assign m_tvalid2_o      = ~empty2 || bypass_en2;

  assign enable_head_reg1 = s_handshake && (empty1 || m_handshake1 && almost_empty1);
  assign enable_head_reg2 = s_handshake && (empty2 || m_handshake2 && almost_empty2);

  assign wr_en1           = s_handshake && ~enable_head_reg1;
  assign wr_en2           = s_handshake && ~enable_head_reg2;

  assign rd_en1           = m_handshake1;
  assign rd_en2           = m_handshake2;

  dual_port_ram #(.DATA_WIDTH(DATA_WIDTH_OUT), .RAM_DEPTH(ONE_RAM_DEPTH), .ADDR_WIDTH(PTR_WIDTH)) i_ram1
  (
    .clk_i    (aclk_i       ),
    .wr_addr_i(wr_ptr1      ),
    .data_i   (data_in1     ),
    .wr_en_i  (wr_en1       ),
    .rd_en_i  (rd_en1       ),
    .rd_addr_i(rd_ptr1 + 'b1),
    .data_o   (data_ram_out1)
  );

  dual_port_ram #(.DATA_WIDTH(DATA_WIDTH_OUT), .RAM_DEPTH(ONE_RAM_DEPTH), .ADDR_WIDTH(PTR_WIDTH)) i_ram2
  (
    .clk_i    (aclk_i       ),
    .wr_addr_i(wr_ptr2      ),
    .data_i   (data_in2     ),
    .wr_en_i  (wr_en2       ),
    .rd_en_i  (rd_en2       ),
    .rd_addr_i(rd_ptr2 + 'b1),
    .data_o   (data_ram_out2)
  );

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i) begin
      wr_ptr1 <= {PTR_WIDTH{1'b0}};
      wr_ptr2 <= {PTR_WIDTH{1'b0}};
    end
    else if (s_handshake) begin
      wr_ptr1 <= wr_ptr1 + 'b1;
      wr_ptr2 <= wr_ptr2 + 'b1;
    end

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i)
      rd_ptr1 <= {PTR_WIDTH{1'b0}};
    else if (m_handshake1)
      rd_ptr1 <= rd_ptr1 + 'b1;

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i)
      rd_ptr2 <= {PTR_WIDTH{1'b0}};
    else if (m_handshake2)
      rd_ptr2 <= rd_ptr2 + 'b1;

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i)
      head_reg1 <= {DATA_WIDTH_OUT{1'b0}};
    else if (enable_head_reg1)
      head_reg1 <= data_in1;

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i)
      head_reg2 <= {DATA_WIDTH_OUT{1'b0}};
    else if (enable_head_reg2)
      head_reg2 <= data_in2;

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i)
      bypass_en1 <= 1'b0;
    else if (enable_head_reg1)
      bypass_en1 <= 1'b1;
    else if (m_handshake1)
      bypass_en1 <= 1'b0;

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i)
      bypass_en2 <= 1'b0;
    else if (enable_head_reg2)
      bypass_en2 <= 1'b1;
    else if (m_handshake2)
      bypass_en2 <= 1'b0;

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i) 
      m_tuser1_o <= 1'b1;
    else if (m_handshake1 && m_handshake2)
      m_tuser1_o <= m_tuser1_o;
    else if (m_handshake1)
      m_tuser1_o <= 1'b0;
    else if (m_handshake2)
      m_tuser1_o <= 1'b1;

  always_ff @(posedge aclk_i or negedge aresetn_i)
    if (~aresetn_i) 
      m_tuser2_o <= 1'b0;
    else if (m_handshake1 && m_handshake2)
      m_tuser2_o <= m_tuser2_o;
    else if (m_handshake1)
      m_tuser2_o <= 1'b1;
    else if (m_handshake2)
      m_tuser2_o <= 1'b0;

  assign m_tdata1_o = bypass_en1 ? head_reg1 : data_ram_out1;
  assign m_tdata2_o = bypass_en2 ? head_reg2 : data_ram_out2;

endmodule