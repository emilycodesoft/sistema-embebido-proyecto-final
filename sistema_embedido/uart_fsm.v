// ============================================================================
// Módulo: uart_fsm
// Descripción: UART completo con RX y TX (eco) a 115200 baudios
// ============================================================================

module uart_fsm (
    input  wire clk,              // Reloj 50 MHz
    input  wire rst,              // Reset síncrono activo alto
    input  wire rx_raw,           // Pin RX desde FT232 (sin sincronizar)
    output wire tx,               // Pin TX hacia FT232 (eco)
    output reg  [7:0] data_out,   // Byte recibido
    output reg  data_valid,       // Pulso cuando byte válido
    output reg  frame_error,      // Error en stop bits
    output reg  [2:0] rx_state    // Estado RX para debug
);

    // ========================================================================
    // Parámetros
    // ========================================================================
    localparam BAUD_TICK = 434;              // 50MHz / 115200 ≈ 434
    localparam HALF_TICK = BAUD_TICK / 2;    // Medio tick = 217

    // ========================================================================
    // Sincronizador de 2 etapas para RX (anti-metaestabilidad)
    // ========================================================================
    reg rx_sync1 = 1;
    reg rx_sync2 = 1;
    
    always @(posedge clk) begin
        if (rst) begin
            rx_sync1 <= 1;
            rx_sync2 <= 1;
        end else begin
            rx_sync1 <= rx_raw;
            rx_sync2 <= rx_sync1;
        end
    end
    
    wire rx = rx_sync2;  // Señal sincronizada

    // ========================================================================
    // Generador de ticks para RX
    // ========================================================================
    reg [15:0] rx_baud_cnt = 0;
    reg        rx_baud_tick = 0;
    reg        rx_tick_reset = 0;
    
    always @(posedge clk) begin
        if (rst) begin
            rx_baud_cnt  <= 0;
            rx_baud_tick <= 0;
        end else if (rx_tick_reset) begin
            rx_baud_cnt  <= 0;
            rx_baud_tick <= 0;
        end else if (rx_baud_cnt == BAUD_TICK - 1) begin
            rx_baud_cnt  <= 0;
            rx_baud_tick <= 1;
        end else begin
            rx_baud_cnt  <= rx_baud_cnt + 1;
            rx_baud_tick <= 0;
        end
    end

    // ========================================================================
    // FSM RECEPTOR UART
    // ========================================================================
    localparam RX_IDLE       = 0,
               RX_START      = 1,
               RX_DATA       = 2,
               RX_STOP1      = 3,
               RX_STOP2      = 4,
               RX_VALID_DATA = 5;

    reg [7:0] rx_shift = 0;
    reg [2:0] rx_bit_idx = 0;
    
    always @(posedge clk) begin
        if (rst) begin
            rx_state       <= RX_IDLE;
            data_valid     <= 0;
            frame_error    <= 0;
            rx_tick_reset  <= 0;
            rx_shift       <= 0;
            rx_bit_idx     <= 0;
            data_out       <= 0;
        end else begin
            data_valid     <= 0;
            frame_error    <= 0;
            rx_tick_reset  <= 0;

            case (rx_state)

                // ------------------------------------------------------------
                // IDLE: Esperar start bit
                // ------------------------------------------------------------
                RX_IDLE: begin
                    if (rx == 0) begin              // Detecta flanco de bajada
                        rx_state      <= RX_START;
                        rx_tick_reset <= 1;         // Resetear contador
                    end
                end

                // ------------------------------------------------------------
                // START: Esperar medio tick y verificar start bit
                // ------------------------------------------------------------
                RX_START: begin
                    if (rx_baud_cnt == HALF_TICK) begin
                        if (rx == 0) begin          // Verificar que sigue en 0
                            rx_state    <= RX_DATA;
                            rx_bit_idx  <= 0;
                        end else begin
                            rx_state <= RX_IDLE;    // Falso inicio
                        end
                    end
                end

                // ------------------------------------------------------------
                // DATA: Recibir 8 bits (muestrear en el centro)
                // ------------------------------------------------------------
                RX_DATA: begin
                    if (rx_baud_tick) begin
                        rx_shift[rx_bit_idx] <= rx;
                        
                        if (rx_bit_idx == 7)
                            rx_state <= RX_STOP1;
                        else
                            rx_bit_idx <= rx_bit_idx + 1;
                    end
                end

                // ------------------------------------------------------------
                // STOP1: Verificar primer stop bit
                // ------------------------------------------------------------
                RX_STOP1: begin
                    if (rx_baud_tick) begin
                        if (rx == 1) begin
                            rx_state <= RX_STOP2;
                        end else begin
                            frame_error <= 1;
                            rx_state    <= RX_IDLE;
                        end
                    end
                end

                // ------------------------------------------------------------
                // STOP2: Verificar segundo stop bit
                // ------------------------------------------------------------
                RX_STOP2: begin
                    if (rx_baud_tick) begin
                        if (rx == 1) begin
                            rx_state <= RX_VALID_DATA;
                        end else begin
                            frame_error <= 1;
                            rx_state    <= RX_IDLE;
                        end
                    end
                end

                // ------------------------------------------------------------
                // VALID_DATA: Entregar byte válido
                // ------------------------------------------------------------
                RX_VALID_DATA: begin
                    data_out   <= rx_shift;
                    data_valid <= 1;
                    rx_state   <= RX_IDLE;
                end

            endcase
        end
    end

    // ========================================================================
    // Generador de ticks para TX (independiente del RX)
    // ========================================================================
    reg [15:0] tx_baud_cnt = 0;
    reg        tx_baud_tick = 0;
    
    always @(posedge clk) begin
        if (rst) begin
            tx_baud_cnt  <= 0;
            tx_baud_tick <= 0;
        end else if (tx_baud_cnt == BAUD_TICK - 1) begin
            tx_baud_cnt  <= 0;
            tx_baud_tick <= 1;
        end else begin
            tx_baud_cnt  <= tx_baud_cnt + 1;
            tx_baud_tick <= 0;
        end
    end

    // ========================================================================
    // FSM TRANSMISOR UART (eco)
    // ========================================================================
    localparam TX_IDLE  = 0,
               TX_START = 1,
               TX_DATA  = 2,
               TX_STOP1 = 3,
               TX_STOP2 = 4;

    reg [2:0] tx_state = TX_IDLE;
    reg [7:0] tx_shift = 0;
    reg [2:0] tx_bit_idx = 0;
    reg       tx_reg = 1;

    assign tx = tx_reg;

    always @(posedge clk) begin
        if (rst) begin
            tx_state   <= TX_IDLE;
            tx_shift   <= 0;
            tx_bit_idx <= 0;
            tx_reg     <= 1;
        end else begin
            case (tx_state)

                // ------------------------------------------------------------
                // IDLE: Esperar byte válido para transmitir
                // ------------------------------------------------------------
                TX_IDLE: begin
                    tx_reg <= 1;  // Línea inactiva en alto
                    
                    if (data_valid) begin
                        tx_shift <= data_out;
                        tx_state <= TX_START;
                    end
                end

                // ------------------------------------------------------------
                // START: Enviar start bit
                // ------------------------------------------------------------
                TX_START: begin
                    if (tx_baud_tick) begin
                        tx_reg     <= 0;        // Start bit = 0
                        tx_state   <= TX_DATA;
                        tx_bit_idx <= 0;
                    end
                end

                // ------------------------------------------------------------
                // DATA: Enviar 8 bits de datos
                // ------------------------------------------------------------
                TX_DATA: begin
                    if (tx_baud_tick) begin
                        tx_reg <= tx_shift[tx_bit_idx];
                        
                        if (tx_bit_idx == 7)
                            tx_state <= TX_STOP1;
                        else
                            tx_bit_idx <= tx_bit_idx + 1;
                    end
                end

                // ------------------------------------------------------------
                // STOP1: Enviar primer stop bit
                // ------------------------------------------------------------
                TX_STOP1: begin
                    if (tx_baud_tick) begin
                        tx_reg   <= 1;  // Stop bit = 1
                        tx_state <= TX_STOP2;
                    end
                end

                // ------------------------------------------------------------
                // STOP2: Enviar segundo stop bit
                // ------------------------------------------------------------
                TX_STOP2: begin
                    if (tx_baud_tick) begin
                        tx_reg   <= 1;  // Stop bit = 1
                        tx_state <= TX_IDLE;
                    end
                end

            endcase
        end
    end

endmodule
