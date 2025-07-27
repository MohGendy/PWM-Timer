
module pwm_timer (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_extclk,
    input  wire [15:0] i_DC,
    input  wire        i_DC_valid,
    input  wire        i_wb_cyc,
    input  wire        i_wb_stb,
    input  wire        i_wb_we,
    input  wire [15:0] i_wb_adr,
    input  wire [15:0] i_wb_data,
    output reg  [15:0] o_wb_data,
    output reg         o_wb_ack,
    output reg         o_pwm);
   
    // Control Register Bits
    localparam use_ext_clk      = 0;
    localparam pwm_mode         = 1;
    localparam counter_enable   = 2;
    localparam continuous_run   = 3;
    localparam pwm_output_en    = 4;
    localparam interrupt_flag   = 5;
    localparam use_input_dc     = 6;
    localparam reset_counter    = 7;

    reg [7:0]   Ctrl;
    reg [15:0]  Divisor;
    reg [15:0]  Period;
    reg [15:0]  DC;
    reg [15:0]  clk_div_cnt;
    reg [15:0]  main_counter;
    
    wire selected_clk = Ctrl[use_ext_clk] ? i_extclk : i_clk;
    wire count_tick   = (Divisor <= 1) || (clk_div_cnt == Divisor - 1);

    //  Down Clocking Logic
    always @(posedge selected_clk or posedge i_rst)
    begin
        if (i_rst || Ctrl[reset_counter]) 
        begin
            clk_div_cnt <= 16'd0;
        end 
        else if (Ctrl[counter_enable])
        begin
            if (count_tick)
                clk_div_cnt <= 0;
            else
                clk_div_cnt <= clk_div_cnt + 1;
        end
    end

    // Main Counter 
    always @(posedge selected_clk or posedge i_rst)
    begin
        if (i_rst || Ctrl[reset_counter])
        begin
            main_counter <= 16'd0;
            o_pwm  <= 0;
            Ctrl[interrupt_flag] <= 1'b0;  // Clear interrupt flag
        end 
        else if (count_tick && Ctrl[counter_enable]) 
        begin
            if (Ctrl[pwm_mode])
            begin 
                if (main_counter >= Period)
                    main_counter <= 0;
                if (Ctrl[pwm_output_en])
                    o_pwm <= (main_counter < ((Ctrl[use_input_dc] && i_DC_valid) ? i_DC : DC)) ? 1'b1 : 1'b0;
                else
                    o_pwm <= 0;
            end  
            else  
            begin
                if (main_counter >= Period)
                begin
                    Ctrl[interrupt_flag] <= 1;
                    main_counter <= 0;
                    o_pwm <= 1;
                    if (!Ctrl[continuous_run])
                        Ctrl[counter_enable] <= 0;
                end
                else
                begin
                    main_counter <= main_counter + 1;
                    o_pwm <= 0;
                end
            end
        end
    end
 
    // Wishbone Interface 
    always @(posedge i_clk or posedge i_rst) 
    begin
        if (i_rst) begin
            Ctrl      <= 8'd0;
            Divisor   <= 16'd1;
            Period    <= 16'd0;
            DC        <= 16'd0;
            o_wb_data <= 16'd0;
            o_wb_ack  <= 1'b0;
        end 
        else        
        begin
            // Generate  ack
            if (i_wb_cyc && i_wb_stb && !o_wb_ack)
                o_wb_ack <= 1'b1;
            else
                o_wb_ack <= 1'b0;

            if (i_wb_cyc && i_wb_stb) 
            begin
                if (i_wb_we) 
                begin
                    case (i_wb_adr)
                        0: begin
                            Ctrl[reset_counter:use_input_dc] <= i_wb_data[7:6];
                            if (i_wb_data[5] == 1'b0)
                                Ctrl[interrupt_flag] <= 1'b0;
                            Ctrl[pwm_output_en:use_ext_clk] <= i_wb_data[4:0];
                        end
                        2: Divisor <= i_wb_data;
                        4: Period  <= i_wb_data;
                        6: DC      <= i_wb_data;
                        default:;
                    endcase
                end 
                else 
                begin
                    case (i_wb_adr)
                        0: o_wb_data <= {8'd0, Ctrl};
                        2: o_wb_data <= Divisor;
                        4: o_wb_data <= Period;
                        6: o_wb_data <= DC;
                        default:   o_wb_data <= 16'd0;
                    endcase
                end
            end
        end
    end

endmodule