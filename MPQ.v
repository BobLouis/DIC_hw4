module MPQ(
    input clk,
    input rst,
    input data_valid,
    input [7:0] data,
    input cmd_valid,
    input [2:0] cmd,
    input [7:0] index,
    input [7:0] value,
    output reg busy,
    output reg RAM_valid,
    output reg [7:0] RAM_A,
    output reg [7:0] RAM_D,
    output reg done
);

    reg [7:0] array [1:30];
    reg [2:0] state, next_state;
    reg [2:0] cmd_reg;
    reg [3:0] heapify_idx, build_idx;
    reg [3:0] idx_reg;
    reg [3:0] array_size;
    reg [4:0] l, r, largest;
    reg [2:0] cnt;
    reg [3:0] out_cnt;
    reg cal_done;
    reg heap;
    integer i;
    parameter 
        IDLE    = 3'd0,
        READ    = 3'd1,
        CMD     = 3'd2,
        CAL     = 3'd3,
        HEAPIFY = 3'd4,
        OUT     = 3'd5;


    // State transition
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else 
            state <= next_state;
    end

    // Next state logic
    always @(*) begin
        if (rst)
            next_state = IDLE;
        else begin
            case(state)
                IDLE: begin
                    if (data_valid)
                        next_state = READ;
                    else
                        next_state = IDLE;
                end
                READ: begin
                    if (!data_valid)
                        next_state = CMD;
                    else
                        next_state = READ;
                end
                CMD: begin
                    if (cmd_reg == 3'd4) 
                        next_state = OUT;
                    else if (cmd_reg < 3'd4) 
                        next_state = CAL;
                    else
                        next_state = CMD;
                end 
                CAL: begin
                    if (cal_done) 
                        next_state = CMD;
                    else if(heap)
                        next_state = HEAPIFY;
                    else
                        next_state = CAL;
                end
                HEAPIFY: begin
                    if (!heap) 
                        next_state = CAL;
                    else
                        next_state = HEAPIFY;
                end
                OUT: begin
                    if (done)
                        next_state = IDLE;
                    else
                        next_state = OUT;
                end
                default:    
                    next_state = IDLE;
            endcase
        end 
    end

    // Output logic and register reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy <= 0;
            RAM_valid <= 0;
            RAM_A <= 8'd0;
            RAM_D <= 8'd0;
            cmd_reg <= 3'd5;
            done <= 0;
            array_size <= 0;
            for (i = 1; i <= 30; i = i + 1) begin
                array[i] <= 8'd0;
            end
            heapify_idx <= 0;
            build_idx <= 0;
            idx_reg <= 0;
            array_size <= 0;
            l <= 0;
            r <= 0;
            largest <= 0;
            cnt <= 0;
            cal_done <= 0;
            heap <= 0;
            out_cnt <= 0;
        end
        else begin
            case(next_state)
                IDLE: begin
                    busy <= 0;
                    done <= 0;
                    
                end
                READ: begin
                    if (data_valid) begin
                        array[array_size+1] <= data;
                        array_size <= array_size + 1;
                    end
                end
                CMD: begin
                    busy <= 1;
                    cal_done <= 0;
                    if(cmd_valid)begin
                        cmd_reg <= cmd;
                        case(cmd)
                            3'd0: begin//build 
                                build_idx <= array_size>>1;
                            end
                            3'd1: begin//extract max
                                array_size <= array_size - 1;
                                array[1] <= array[array_size];
                                array[array_size] <= 8'd0;
                                heapify_idx <= 1;
                                heap <= 1;
                            end
                            3'd2: begin//increase value
                                array[index] <= value;
                                idx_reg <= index;
                            end
                            3'd3: begin //insert data
                                array[array_size+1] <= value;
                                array_size <= array_size + 1;
                                idx_reg <= array_size + 1;                                
                            end
                            3'd4: begin //write
                                RAM_A <= 8'd0;

                                
                            end
                        endcase
                    end    
                end
                CAL: begin
                    
                    case(cmd_reg)
                        3'd0: begin //build
                            if(build_idx > 0) begin
                                // heapify
                                heap <= 1;
                                cnt <= 0;
                                build_idx <= build_idx - 1;
                                heapify_idx <= build_idx;
                            end
                            else begin
                                cal_done <= 1;
                                busy <= 0;
                            end
                        end
                        3'd1: begin //extract max
                            if(heap==0)
                            begin
                                cal_done <= 1;
                                busy <= 0;
                            end
                        end
                        3'd2, 3'd3: begin//increase value
                            if(idx_reg > 1 && array[(idx_reg>>1)] < array[idx_reg])begin
                                array[idx_reg] <= array[(idx_reg>>1)];
                                array[(idx_reg>>1)] <= array[idx_reg];
                                idx_reg <= idx_reg >> 1;
                            end
                            else begin
                                cal_done <= 1;
                                busy <= 0;
                            end
                        end
                    endcase

                    
                end

                HEAPIFY: begin
                    case(cnt)
                        0: begin
                            l <= heapify_idx << 1;
                            r <= (heapify_idx << 1) + 1;
                            largest <= heapify_idx; 
                            cnt <= 1;
                        end
                        1:begin
                            if(l <= array_size && array[l] > array[heapify_idx])
                                largest <= l;
                            cnt <= 2;
                        end
                        2:begin
                            if(r <= array_size && array[r] > array[largest])
                                largest <= r;
                            cnt <= 3;
                        end
                        3: begin
                            if(largest != heapify_idx) begin
                                array[heapify_idx] <= array[largest];
                                array[largest] <= array[heapify_idx];
                                heapify_idx <= largest;
                            end
                            else begin
                                heap <= 0;
                            end
                            cnt <= 0;

                        end
                    endcase

                end
                OUT: begin
                    if(RAM_A < array_size) 
                    begin
                        RAM_valid <= 1;
                        
                        RAM_D <= array[out_cnt+1];
                        out_cnt <= out_cnt + 1;
                        if(state == OUT)
                            RAM_A <= RAM_A + 1;
                    end
                    else
                        done <= 1;
                end
            endcase
        end
    end

endmodule
