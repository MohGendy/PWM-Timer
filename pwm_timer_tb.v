module pwm_timer_tb;

    parameter base = 0; //? base address to start

    // Control Register Bits
    localparam use_ext_clk      = 0;
    localparam pwm_mode         = 1;
    localparam counter_enable   = 2;
    localparam continuous_run   = 3;
    localparam pwm_output_en    = 4;
    localparam interrupt_flag   = 5;
    localparam use_input_dc     = 6;
    localparam reset_counter    = 7;

    localparam [15:0] CTRL_REG = base + 16'b0;
    localparam [15:0] DIVISOR_REG = base + 16'b10;
    localparam [15:0] PERIOD_REG0 = base + 16'b100;
    localparam [15:0] DC_REG0 = base + 16'b110;
    localparam [15:0] PERIOD_REG1 = base + 16'b1000;
    localparam [15:0] DC_REG1 = base + 16'b1010;
    localparam [15:0] PERIOD_REG2 = base + 16'b1100;
    localparam [15:0] DC_REG2 = base + 16'b1110;
    localparam [15:0] PERIOD_REG3 = base + 16'b10000;
    localparam [15:0] DC_REG3 = base + 16'b10010;
    localparam [15:0] INT_SRC = base + 16'b10100;

    //! wishbone interfacing compatible signals (B4)
    reg o_clk;
    reg o_rst;
    reg o_wb_cyc;
    reg o_wb_stb;
    reg o_wb_we;

    reg [15:0]o_wb_adr;
    reg [15:0]o_wb_data;

    wire i_wb_ack;
    wire [15:0]i_wb_data;    

    //! wishbone interfacing incompatible signals
    reg o_extclk;
    reg [15:0]o_DC;
    reg o_DC_valid;

    wire [3:0]i_pwm;

    pwm_timer DUT(
        .i_clk      (o_clk),
        .i_rst      (o_rst),
        .i_extclk   (o_extclk),
        .i_DC       (o_DC),
        .i_DC_valid (o_DC_valid),
        .i_wb_cyc   (o_wb_cyc),
        .i_wb_stb   (o_wb_stb),
        .i_wb_we    (o_wb_we),
        .i_wb_adr   (o_wb_adr),
        .i_wb_data  (o_wb_data),
        .o_wb_data  (i_wb_data),
        .o_wb_ack   (i_wb_ack),
        .o_pwm      (i_pwm)
    );

    reg [15:0] outputs;
    reg [7:0] ctrls;

    initial begin
        init();
        //? set clk
        forever begin
            #5 o_clk = (~o_clk);
        end
    end

    initial begin
        //! test bench start here
        wb_write(PERIOD_REG0 ,{8'b0,8'b00001000});
        wb_write(DC_REG0     ,{8'b0,8'b00000110});
        clr_ctrls();
        set_ctrls(pwm_mode      , 1'b1);
        set_ctrls(counter_enable, 1'b1);
        set_ctrls(pwm_output_en , 1'b1);

        wb_write(CTRL_REG   ,{8'b0,ctrls});

        #10000
        $stop;
    end

    //!helper tasks
    task init();
    begin
        o_rst = 1'b1;
        o_wb_cyc = 1'b0;
        o_wb_stb = 1'b0;
        o_wb_we = 1'b0;
        o_wb_adr = 16'b0;
        o_wb_data = 16'b0;
        o_DC = 16'b0;
        o_DC_valid = 1'b0;
        o_extclk = 1'b0;
        o_clk = 1'b0;
        #10;
        o_rst = 1'b0;
    end
    endtask

    task reset();
    begin
        o_rst = 1'b1;
        #10;
        o_rst = 1'b0;
    end
    endtask

    task wb_write(input [15:0]adr, input [15:0]data);
    begin
        @ (posedge o_clk);
        o_wb_cyc = 1'b1;
        o_wb_stb = 1'b1;
        o_wb_we  = 1'b1;
        o_wb_adr = adr;
        o_wb_data = data;
        wait(i_wb_ack);
        @ (posedge o_clk);
        o_wb_stb = 1'b0;
        o_wb_cyc = 1'b0;
        @ (negedge i_wb_ack);
    end
    endtask

    task set_extclk_half_period(input half_period, input duration_cycles);
        integer i;
    begin
        for (i = 0; i < duration_cycles; i = i + 1) begin
            o_extclk = 1'b1;
            #(half_period);
            o_extclk = 1'b0;
            #(half_period);
        end
    end
    endtask

    task set_extDC(input DC);
    begin
        @ (posedge o_clk);
        o_DC = DC;
        o_DC_valid = 1'b1;
    end
    endtask

    task wb_read(input [15:0]adr, output [15:0]data);
    begin
        @ (posedge o_clk);
        o_wb_cyc = 1'b1;
        o_wb_stb = 1'b1;
        o_wb_adr = adr;
        o_wb_we  = 1'b0;
        wait(i_wb_ack);
        @ (posedge o_clk);
        data = o_wb_data;
        o_wb_stb = 1'b0;
        o_wb_cyc = 1'b0;
        @ (negedge i_wb_ack);
    end
    endtask

    task clr_ctrls();
    begin
        ctrls = 8'b0;
    end
    endtask

    task set_ctrls(input integer bit, input value);
    begin
        ctrls[bit] = value;
    end
    endtask


endmodule
