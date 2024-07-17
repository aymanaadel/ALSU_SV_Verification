package ALSU_pckg;
  typedef enum bit [2:0] {OR, XOR, ADD, MULT, SHIFT, ROTATE, INVALID_6, INVALID_7} opcode_e;
  parameter MAXPOS=3, MAXNEG=-4, ZERO=0; // A/B is 3-bit signed (from -4 to +3)
  class transaction;
    // inputs
    rand logic  rst;
    rand logic  cin, red_op_A, red_op_B, bypass_A, bypass_B, direction, serial_in;
    rand opcode_e opcode;
    rand logic  signed [2:0] A, B;
    // fixed array of type opcode_e (used in constraint no. 8)
    rand opcode_e opcode_arr [6];

    logic signed [2:0] corner_values[] = '{MAXPOS, ZERO, MAXNEG};
    rand logic signed [2:0] corner_values_t, corner_values_f;    

    logic signed [2:0] data_walkingones[] = '{3'b001, 3'b010, 3'b100};
    rand logic signed [2:0] data_walkingones_t, data_walkingones_f;

    /* ************************************* Randomization Constraints ******************************************** */
    // 1. Reset to be asserted with a low probability
    constraint rst_c { rst dist {1:=5, 0:=95}; }
    // 2. Constraint for adder inputs (A, B) to take the values (MAXPOS, ZERO, MAXNEG) more when the opcode is ADD or MULT
    constraint AB_corner_c {
    corner_values_t inside {corner_values};
    !(corner_values_f inside {corner_values});
      if (opcode==ADD || opcode==MULT) {
          A dist { corner_values_t:/70, corner_values_f:/30 };         
          B dist { corner_values_t:/70, corner_values_f:/30 };
      }
    }
    // 3. when opcode is (OR or XOR) and red_op_A is high, constraint A most to have one bit high (-4,2,1) and B to be low
    constraint A_one_bit_high_c {
    data_walkingones_t inside {data_walkingones};
    !(data_walkingones_f inside {data_walkingones});
      if ( (opcode==OR || opcode==XOR) && red_op_A ) {
        A dist { data_walkingones_t:/70, data_walkingones_f:/30 };
        B == 0;
      }
    }
    // 4. when opcode is (OR or XOR) and red_op_B is high, constraint B most to have one bit high (-4,2,1) and A to be low
    constraint B_one_bit_high_c {
      if ( (opcode==OR || opcode==XOR) && red_op_B && !red_op_A ) {
        A == 0;
        B dist { data_walkingones_t:/70, data_walkingones_f:/30 };
      }
    }
    // 5. Invalid cases should occur less frequent than the valid cases
    constraint Invalid_cases_c {
      opcode dist { [INVALID_6:INVALID_7]:/10, [OR:ROTATE]:/90 };    
    }
    // 6. bypass_A and bypass_B should be disabled most of the time
    constraint bypass_AB_c {
      bypass_A dist {0:=95, 1:=5};
      bypass_B dist {0:=95, 1:=5};
    }
    // 7. Do not constraint the inputs A or B when the operation is SHIFT or ROTATE
    // Done already

    // 8. constraint the elements of the opcode_arr using foreach to have a unique valid value each time randomize occurs
    constraint opcode_array_c {
      // valid value
      foreach (opcode_arr[i]) { opcode_arr[i]!=INVALID_6; opcode_arr[i]!=INVALID_7; }
      // unique
      foreach (opcode_arr[i]) {
        foreach (opcode_arr[j]) {
          if (i!=j) opcode_arr[i]!=opcode_arr[j];
        }
      } /* or you can use "unique{opcode_arr}" directly, instead of using the nested foreach */
    }

    /* **************************************** Functional Coverage ********************************************* */
    covergroup cvr_gp;
      // 1. coverpoint for port A
      A_cp: coverpoint A {
        bins A_data_0 = {ZERO};
        bins A_data_max = {MAXPOS};
        bins A_data_min = {MAXNEG};
        bins A_data_default = default;
      }
      // cover point for port A (001,010,100) if only the red_op_A is high
      A_walkingones_cp: coverpoint A iff (red_op_A) {
        bins A_data_walkingones[] = data_walkingones;
      }
      // 2. coverpoint for port B
      B_cp: coverpoint B {
        bins B_data_0 = {ZERO};
        bins B_data_max = {MAXPOS};
        bins B_data_min = {MAXNEG};
        bins B_data_default = default;
      }
      // cover point for port B if only the red_op_B is high and red_op_A is low
      B_walkingones_cp: coverpoint B iff (red_op_B && !red_op_A) {
        bins B_data_walkingones[] = data_walkingones;
      }
      // 3. cover point for opcode
      ALU_cp: coverpoint opcode {
        // generate bins for shift and rotate opcodes
        bins Bins_shift[] = {SHIFT, ROTATE};
        // generate bins for add and mult opcodes
        bins Bins_arith[] = {ADD, MULT};
        // generate bins for or and xor opcodes
        bins Bins_bitwise[] = {OR, XOR};
        // illegals bins for opcodes 6 or 7
        illegal_bins Bins_invalid = {INVALID_6, INVALID_7};
        // transition from opcode 0 > 1 > 2 > 3 > 4 > 5
        bins Bins_trans = (OR => XOR => ADD => MULT => SHIFT => ROTATE);
      }

      /* *** Cross Coverage *** */
      // 1. when the ALSU is ADD or MULT, A and B should have taken all permutations of maxpos, maxneg and zero.
      arith_corner_cases_cross: cross A_cp, B_cp, ALU_cp {
        option.cross_auto_bin_max=0; // non LRM option to stop auto generate bins
        bins arith_corner_cases = binsof (ALU_cp.Bins_arith) &&
                                  binsof (A_cp) intersect {MAXPOS,MAXNEG,ZERO} &&
                                  binsof (B_cp) intersect {MAXPOS,MAXNEG,ZERO};
      }
      // 2. when the ALSU is ADD, c_in should have taken 0 or 1
      cin_cp: coverpoint cin { 
        option.weight = 0;
        bins cin0_1 = {0,1};
      }
      ADD_cin_cross: cross ALU_cp, cin_cp {
        option.cross_auto_bin_max=0; 
        bins ADD_cin0_1 = binsof(ALU_cp) intersect {ADD} && binsof(cin_cp.cin0_1);
      }
      // 3. when the ALSU is SHIFT, then serial_in must take 0 or 1
      serial_in_cp: coverpoint serial_in { 
        option.weight = 0;
        bins serial_in0_1 = {0,1};
      }
      SHIFT_serial_in_cross: cross ALU_cp, serial_in_cp {
        option.cross_auto_bin_max=0; 
        bins SHIFT_serial_in0_1 = binsof(ALU_cp) intersect {SHIFT} && binsof(serial_in_cp.serial_in0_1);
      }
      // 4. when the ALSU is SHIFT or ROTATE, then direction must take 0 or 1
      direction_cp: coverpoint direction { 
        option.weight = 0;
        bins direction0_1 = {0,1};
      }
      SHIFT_direction_cross: cross ALU_cp, direction_cp {
        option.cross_auto_bin_max=0; 
        bins SHIFT_ROTATE_direction0_1 = binsof(ALU_cp.Bins_shift) && binsof(direction_cp.direction0_1);
      }
      // 5. when the ALSU is OR or XOR and red_op_A is high, then A took all patterns (001, 010, and 100) while B is 0
      bitwise_red_op_A_cross: cross ALU_cp, A_walkingones_cp, B_cp {
        option.cross_auto_bin_max=0; 
        bins bitwise_A_pattern = binsof(ALU_cp.Bins_bitwise) && binsof(A_walkingones_cp.A_data_walkingones)
                                 && binsof(B_cp.B_data_0);
      }
      // 6. when the ALSU is OR or XOR and red_op_B is high, then B took all patterns (001, 010, and 100) while A is 0
      bitwise_red_op_B_cross: cross ALU_cp, A_cp, B_walkingones_cp {
        option.cross_auto_bin_max=0; 
        bins bitwise_B_pattern = binsof(ALU_cp.Bins_bitwise) && binsof(B_walkingones_cp.B_data_walkingones)
                                 && binsof(A_cp.A_data_0);
      }
      // 7. cover the invalid case: reduction operation (red_op_A, red_op_B) is high while the opcode is not OR or XOR
      red_op_A_cp: coverpoint red_op_A {
        option.weight = 0;
        bins red_op_A_high = {1};
      }
      red_op_B_cp: coverpoint red_op_B {
        option.weight = 0;
        bins red_op_B_high = {1};
      }
      Invalid_case_cross: cross ALU_cp, red_op_A_cp, red_op_B_cp {
        option.cross_auto_bin_max=0; 
        bins invalid_case = ( binsof(red_op_A_cp.red_op_A_high) || binsof(red_op_B_cp.red_op_B_high) )
                              && !binsof(ALU_cp.Bins_bitwise);
      }
    endgroup

    // class constructor
    function new ();
      cvr_gp = new();
    endfunction

  endclass

endpackage
