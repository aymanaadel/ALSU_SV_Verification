import ALSU_pckg::*;
module ALSU_tb;
  // inputs
  logic clk, rst;
  logic cin, red_op_A, red_op_B, bypass_A, bypass_B, direction, serial_in;
  opcode_e opcode;
  logic signed [2:0] A, B;
  // outputs
  logic [15:0] leds;
  logic signed [5:0] out;

  // golden model variables and parameters
  parameter INPUT_PRIORITY = "A";
  parameter FULL_ADDER = "ON";
  logic [15:0] leds_golden=0;
  logic signed [5:0] out_golden=0;
  // old out to use it in SHIFT and ROTATE to generate new values! 
  logic signed [5:0] out_golden_old=0;
  // old leds to use it in toggling the leds!
  logic [15:0] leds_golden_old=0;

  // module instantiation
  ALSU dut (.*);

  // transaction class object
  transaction tr=new();

  // clock generation
  initial begin
    clk=0;
    forever begin
      #1 clk=~clk;
    end
  end

  // stimulus
  initial begin
    do_reset();

    // disable constraint number 8
    tr.opcode_array_c.constraint_mode(0);
    // first loop
    repeat (10000) begin // many iterations to cover ALU_cp: "Bins_trans (0 > 1 > 2 > 3 > 4 > 5)"
      assert (tr.randomize());
      rst=tr.rst;
      cin=tr.cin;
      red_op_A=tr.red_op_A;
      red_op_B=tr.red_op_B;
      bypass_A=tr.bypass_A;
      bypass_B=tr.bypass_B;
      direction=tr.direction;
      serial_in=tr.serial_in;
      opcode=tr.opcode;
      A=tr.A;
      B=tr.B;
      @(negedge clk);
      golden_model_check();
    end

    // disable all constraints
    tr.constraint_mode(0);
    // enable constraint number 8 (opcode_array_c)
    tr.opcode_array_c.constraint_mode(1);
    // second loop
    repeat (10000) begin 
      // In-line constraint to force rst, bypass_A, bypass_B, red_op_A and red_op_B to 0
      assert (tr.randomize() with {rst==0; bypass_A==0; bypass_B==0; red_op_A==0; red_op_B==0;} );
      rst=tr.rst;
      cin=tr.cin;
      red_op_A=tr.red_op_A;
      red_op_B=tr.red_op_B;
      bypass_A=tr.bypass_A;
      bypass_B=tr.bypass_B;
      direction=tr.direction;
      serial_in=tr.serial_in;
      A=tr.A;   
      B=tr.B;
      for (int i = 0; i < 6; i++) begin
        opcode=tr.opcode_arr[i];
        @(negedge clk);
        golden_model_check();
      end
    end // second loop

    // directed test cases to cover ALU_cp: "Bins_trans (0 > 1 > 2 > 3 > 4 > 5)"
    for (int i = 0; i < 6; i++) begin
      assert (tr.randomize() with { opcode==i; });
      opcode=tr.opcode;
      @(negedge clk);
      golden_model_check();
    end

    $stop();
  end

  // assert the reset task
  task do_reset();
    rst=1;
    @(negedge clk);
    rst=0;
  endtask

  // using sample task to sample the values
  always @ (posedge clk) begin
    tr.cvr_gp.sample();
  end
  // stop sampling the input values when the reset or the bypass_A or the bypass_B are asserted
  always @(rst, bypass_A, bypass_B) begin
    if (rst || bypass_A || bypass_B) begin
      tr.cvr_gp.stop();
    end
    else begin
      tr.cvr_gp.start();
    end
  end

  // golden model
  task golden_model_check();
    logic invalid_red_op, invalid_opcode, invalid;
    // invalid
    invalid_red_op = (red_op_A | red_op_B) & !(~opcode[2] & ~opcode[1]);
    invalid_opcode = opcode[2] & opcode[1];
    invalid = invalid_red_op | invalid_opcode;
    if (rst) begin
      out_golden=0;
      leds_golden=0;
    end
    else begin
      // leds_golden
      if (invalid)
        leds_golden = ~leds_golden_old;
      else
        leds_golden = 0;

      // out_golden
      if (invalid)
        out_golden = 0;
      else if (bypass_A && bypass_B)
        out_golden = (INPUT_PRIORITY == "A")? A: B;
      else if (bypass_A)
        out_golden = A;
      else if (bypass_B)
        out_golden = B;
      else begin
        case (opcode)
          OR: begin 
            if (red_op_A && red_op_B)
              out_golden = (INPUT_PRIORITY == "A")? |A: |B;
            else if (red_op_A) 
              out_golden = |A;
            else if (red_op_B)
              out_golden = |B;
            else 
              out_golden = A | B;
          end
          XOR: begin
            if (red_op_A && red_op_B)
              out_golden = (INPUT_PRIORITY == "A")? ^A: ^B;
            else if (red_op_A) 
              out_golden = ^A;
            else if (red_op_B)
              out_golden = ^B;
            else 
              out_golden = A ^ B;
          end
          ADD: begin
            if (FULL_ADDER == "ON")
              out_golden = A + B + signed'({5'b0,cin});
            else
              out_golden = A + B;
          end
          MULT: out_golden = A * B;
          SHIFT: begin
            if (direction)
              out_golden = {out_golden_old[4:0], serial_in};
            else
              out_golden = {serial_in, out_golden_old[5:1]};
          end
          ROTATE: begin
            if (direction)
              out_golden = {out_golden_old[4:0], out_golden_old[5]};
            else
              out_golden = {out_golden_old[0], out_golden_old[5:1]};
          end
          default: out_golden=0;
        endcase
      end

    end
    // call the check_result task
    check_result(leds_golden_old, out_golden_old);
    // old out to use it in SHIFT and ROTATE to generate new values!
    out_golden_old=out_golden;
    // old leds to use it in toggling the leds! 
    leds_golden_old=leds_golden;
  endtask

  task check_result(logic [15:0] leds_golden_c, logic signed [5:0] out_golden_c);
    if (!rst) begin // Async. reset has separate check
      leds_check_assert: assert(leds_golden_c==leds);
      leds_check_cover:  cover (leds_golden_c==leds);
      out_check_assert:  assert(out_golden_c==out);
      out_check_cover:   cover (out_golden_c==out);
    end
  endtask

  // Async. reset check
  always_comb begin
    if (rst) begin
      Async_reset_assert: assert final (out==0 && leds==0);
      Async_reset_cover:  cover final  (out==0 && leds==0);
    end
  end

endmodule