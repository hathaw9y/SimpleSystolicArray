module tb_w128_d512_blk_mem_latency;
  localparam int ADDR_W = 9;
  localparam int DATA_W = 128;

  logic              aclk;
  logic              ena;
  logic [      0:0] wea;
  logic [ADDR_W-1:0] addra;
  logic [DATA_W-1:0] dina;
  logic              enb;
  logic [ADDR_W-1:0] addrb;
  logic [DATA_W-1:0] doutb;

  logic [DATA_W-1:0] word10;
  logic [DATA_W-1:0] word11;
  logic [DATA_W-1:0] word12;

  int                saw10;
  int                saw11;
  int                saw12;

  w128_d512_blk_mem dut (
      .clka (aclk),
      .ena  (ena),
      .wea  (wea),
      .addra(addra),
      .dina (dina),
      .clkb (aclk),
      .enb  (enb),
      .addrb(addrb),
      .doutb(doutb)
  );

  initial begin
    aclk = 1'b0;
    forever #5 aclk = ~aclk;
  end

  function automatic logic [DATA_W-1:0] make_word(input int id);
    begin
      make_word = {
        32'hA000_0000 | 32'(id),
        32'hB000_0000 | 32'(id),
        32'hC000_0000 | 32'(id),
        32'hD000_0000 | 32'(id)
      };
    end
  endfunction

  function automatic string word_name(input logic [DATA_W-1:0] data);
    begin
      if (data === word10) begin
        word_name = "word10";
      end else if (data === word11) begin
        word_name = "word11";
      end else if (data === word12) begin
        word_name = "word12";
      end else if (data === '0) begin
        word_name = "zero";
      end else begin
        word_name = "other";
      end
    end
  endfunction

  task automatic tick;
    begin
      @(posedge aclk);
      #1;
    end
  endtask

  task automatic write_word(input logic [ADDR_W-1:0] addr_i,
                            input logic [DATA_W-1:0] data_i);
    begin
      ena   = 1'b1;
      wea   = 1'b1;
      addra = addr_i;
      dina  = data_i;
      tick();
      ena   = 1'b0;
      wea   = 1'b0;
      addra = '0;
      dina  = '0;
      tick();
    end
  endtask

  task automatic print_sample(input string tag, input int cycle_i);
    begin
      $display("%s cycle=%0d enb=%0b addrb=%0d doutb=%s low32=0x%08x full=0x%032x",
               tag,
               cycle_i,
               enb,
               addrb,
               word_name(doutb),
               doutb[31:0],
               doutb);
    end
  endtask

  task automatic idle_read_port(input int cycles_i);
    begin
      enb   = 1'b0;
      addrb = '0;
      for (int i = 0; i < cycles_i; i++) begin
        tick();
        print_sample("IDLE", i);
      end
    end
  endtask

  task automatic read_hold(input logic [ADDR_W-1:0] addr_i, input string tag);
    begin
      $display("---- %s: enb stays high, addrb holds %0d ----", tag, addr_i);
      enb   = 1'b1;
      addrb = addr_i;
      for (int i = 0; i < 6; i++) begin
        tick();
        print_sample(tag, i);
      end
      enb = 1'b0;
      tick();
    end
  endtask

  task automatic read_continuous_address_change;
    begin
      $display("---- CONTINUOUS: enb high while addrb changes 10 -> 11 -> 12 ----");
      enb   = 1'b1;
      addrb = ADDR_W'(10);
      tick();
      print_sample("CONT", 0);

      addrb = ADDR_W'(11);
      tick();
      print_sample("CONT", 1);

      addrb = ADDR_W'(12);
      tick();
      print_sample("CONT", 2);

      for (int i = 3; i < 8; i++) begin
        tick();
        print_sample("CONT", i);
      end

      enb = 1'b0;
      tick();
    end
  endtask

  task automatic note_seen;
    begin
      if (doutb === word10) saw10 = 1;
      if (doutb === word11) saw11 = 1;
      if (doutb === word12) saw12 = 1;
    end
  endtask

  task automatic read_gapped_address_change;
    begin
      $display("---- GAPPED: one idle cycle between read requests ----");
      saw10 = 0;
      saw11 = 0;
      saw12 = 0;

      enb   = 1'b1;
      addrb = ADDR_W'(10);
      tick();
      print_sample("GAP", 0);
      note_seen();

      enb = 1'b0;
      tick();
      print_sample("GAP", 1);
      note_seen();

      enb   = 1'b1;
      addrb = ADDR_W'(11);
      tick();
      print_sample("GAP", 2);
      note_seen();

      enb = 1'b0;
      tick();
      print_sample("GAP", 3);
      note_seen();

      enb   = 1'b1;
      addrb = ADDR_W'(12);
      tick();
      print_sample("GAP", 4);
      note_seen();

      enb = 1'b0;
      for (int i = 5; i < 12; i++) begin
        tick();
        print_sample("GAP", i);
        note_seen();
      end

      if (!saw10 || !saw11 || !saw12) begin
        $error("gapped read did not observe all words: saw10=%0d saw11=%0d saw12=%0d",
               saw10,
               saw11,
               saw12);
        $finish;
      end
    end
  endtask

  initial begin
    word10 = make_word(10);
    word11 = make_word(11);
    word12 = make_word(12);

    ena   = 1'b0;
    wea   = 1'b0;
    addra = '0;
    dina  = '0;
    enb   = 1'b0;
    addrb = '0;

    repeat (4) tick();

    write_word(ADDR_W'(10), word10);
    write_word(ADDR_W'(11), word11);
    write_word(ADDR_W'(12), word12);

    idle_read_port(3);
    read_hold(ADDR_W'(10), "HOLD10");
    idle_read_port(2);
    read_hold(ADDR_W'(11), "HOLD11");
    idle_read_port(2);
    read_continuous_address_change();
    idle_read_port(2);
    read_gapped_address_change();

    $display("tb_w128_d512_blk_mem_latency PASS");
    $finish;
  end

endmodule
