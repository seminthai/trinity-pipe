module trinity_pipe_decoder (
    input  wire        clk,         // Тактовая частота шины
    input  wire        rst_n,       // Асинхронный сброс (активный ноль)
    input  wire [1:0]  trit_in,     // Входной троичный символ: 00=T0, 01=T1, 10=TZ
    
    output reg  [3:0]  data_out,    // Восстановленный 4-битный полубайт (nibble)
    output reg         data_ready,  // Строб готовности данных (на 1 такт clk)
    output reg         frame_error  // Флаг аппаратной ошибки (таймаут кадра)
);

    // Кодирование троичного алфавита для цифровой логики
    localparam TRIT_0 = 2'b00;
    localparam TRIT_1 = 2'b01;
    localparam TRIT_Z = 2'b10;

    // Внутренние регистры аппаратного счетчика
    reg [2:0] bit_count; // Счетчик бит перед маркером Z (0..4)
    reg [3:0] pattern;   // Сдвиговый регистр для накопления бинарного паттерна

    // Комбинаторная логика декодирования (аналог switch-case в симуляторе)
    reg [3:0] decoded_value;
    reg       invalid_combination;

    always @(*) begin
        decoded_value       = 4'b0000;
        invalid_combination = 1'b0;
        
        case (bit_count)
            3'd0: decoded_value = 4'd0; // Пачка 0 бит перед Z: [Z] -> 0
            
            3'd1: begin // Пачка 1 бит перед Z: [0Z]->1, [1Z]->2
                if (pattern == 1'b1) decoded_value = 4'd2;
                else                    decoded_value = 4'd1;
            end
            
            3'd2: begin // Пачка 2 бита перед Z: [00Z]->3 ... [11Z]->6
                decoded_value = 4'd3 + pattern[1:0];
            end
            
            3'd3: begin // Пачка 3 бита перед Z: [000Z]->7 ... [111Z]->14
                decoded_value = 4'd7 + pattern[2:0];
            end
            
            3'd4: begin // Пачка 4 бита перед Z: [0000Z] -> 15
                if (pattern[3:0] == 4'b0000) decoded_value = 4'd15;
                else                         invalid_combination = 1'b1; // Защита
            end
            
            default: invalid_combination = 1'b1;
        endcase
    end

    // Последовательная логика конечного автомата (FSM)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count   <= 3'b000;
            pattern     <= 4'b0000;
            data_out    <= 4'b0000;
            data_ready  <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            // Сброс строба готовности по умолчанию на каждом такте
            data_ready <= 1'b0;

            case (trit_in)
                TRIT_0, TRIT_1: begin
                    // Если лимит длины пачки (4 бита перед Z) превышен - аппаратный сбой
                    if (bit_count >= 3'd4) begin
                        frame_error <= 1'b1;
                        bit_count   <= 3'b000;
                        pattern     <= 4'b0000;
                    end else begin
                        // Сдвигаем пришедший бит в регистр паттерна и инкрементируем счетчик
                        pattern   <= (pattern << 1) | trit_in;
                        bit_count <= bit_count + 1'b1;
                    end
                end

                TRIT_Z: begin
                    // Прилетел топор физического фрейминга. Фиксируем данные за один такт!
                    if (!invalid_combination && !frame_error) begin
                        data_out   <= decoded_value;
                        data_ready <= 1'b1;
                    end
                    
                    // Мгновенный аппаратный сброс счетчиков для следующей пачки
                    bit_count   <= 3'b000;
                    pattern     <= 4'b0000;
                    frame_error <= 1'b0; // Сброс флага ошибки при получении нового Z
                end

                default: begin
                    // Любое неопознанное состояние шины активирует ошибку
                    frame_error <= 1'b1;
                    bit_count   <= 3'b000;
                end
            endcase
        end
    end

endmodule
