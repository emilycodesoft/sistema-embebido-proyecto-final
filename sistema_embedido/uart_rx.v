// ============================================================================
// Módulo: uart_rx
// ============================================================================

module uart_rx (
    input  wire clk,              // Reloj 50 MHz
    input  wire rx_raw,           // RX desde pin (sin sincronizar)
    output reg  [7:0] data_out,   // Byte recibido
    output reg  data_valid,       // Pulso cuando byte válido
    output reg  frame_error,       // Error en stop bits
	 output reg  [2:0] state             // estado actual para debug solamente
);

    // ========================================================================
    // Parámetros
    // ========================================================================
    localparam BAUD_TICK = 434;       // Ticks por bit (50MHz / 115200)
    localparam HALF_TICK = BAUD_TICK / 2;  // Medio tick = 217

    // ========================================================================
    // Sincronizador de 2 etapas (anti-metaestabilidad)
    // ========================================================================
    reg rx_sync1 = 1;
    reg rx_sync2 = 1;
    
    always @(posedge clk) begin
        rx_sync1 <= rx_raw;      // Primera etapa
        rx_sync2 <= rx_sync1;    // Segunda etapa
    end
    
    wire rx = rx_sync2;          // Señal sincronizada

    // ========================================================================
    // Generador de ticks
    // ========================================================================
    reg [15:0] baud_cnt = 0;
    reg        baud_tick = 0;
    reg        tick_reset = 0;   // Control para resetear contador

    always @(posedge clk) begin
        if (tick_reset) begin
            baud_cnt <= 0;       // Resetear al detectar start
            baud_tick <= 0;
        end else if (baud_cnt == BAUD_TICK - 1) begin
            baud_cnt  <= 0;
            baud_tick <= 1;
        end else begin
            baud_cnt  <= baud_cnt + 1;
            baud_tick <= 0;
        end
    end

    // ========================================================================
    // FSM del Receptor
    // ========================================================================
    localparam IDLE       = 0,
               START      = 1,
               DATA       = 2,
               STOP1      = 3,
               STOP2      = 4,
               VALID_DATA = 5;

    //reg [2:0] state = IDLE;
    reg [7:0] rx_shift = 0;
    reg [2:0] bit_idx  = 0;

    always @(posedge clk) begin
        data_valid  <= 0;      // Pulso corto por defecto
        frame_error <= 0;      // Sin error por defecto
        tick_reset  <= 0;

        case (state)

            // ----------------------------------------------------------------
            // IDLE: Esperar start bit
            // ----------------------------------------------------------------
            IDLE: begin
                if (rx == 0) begin              // Detecta flanco de bajada
                    state      <= START;
                    tick_reset <= 1;            // RESETEAR CONTADOR
                end
            end

            // ----------------------------------------------------------------
            // START: Esperar medio tick y verificar start bit
            // ----------------------------------------------------------------
            START: begin
                if (baud_cnt == HALF_TICK) begin   // Medio tick
                    if (rx == 0) begin             // Verificar que sigue en 0
                        state    <= DATA;
                        bit_idx  <= 0;
                    end else begin
                        state <= IDLE;             // Falso inicio
                    end
                end
            end

            // ----------------------------------------------------------------
            // DATA: Recibir 8 bits (muestrear en el centro)
            // ----------------------------------------------------------------
            DATA: begin
                if (baud_tick) begin               // Tick completo
                    rx_shift[bit_idx] <= rx;       // Muestrear en el centro
                    
                    if (bit_idx == 7)
                        state <= STOP1;
                    else
                        bit_idx <= bit_idx + 1;
                end
            end

            // ----------------------------------------------------------------
            // STOP1: Verificar primer stop bit
            // ----------------------------------------------------------------
            STOP1: begin
                if (baud_tick) begin
                    if (rx == 1) begin             // Verificar stop = 1
                        state <= STOP2;
                    end else begin
                        frame_error <= 1;          // Error de frame
                        state       <= IDLE;
                    end
                end
            end

            // ----------------------------------------------------------------
            // STOP2: Verificar segundo stop bit
            // ----------------------------------------------------------------
            STOP2: begin
                if (baud_tick) begin
                    if (rx == 1) begin             // Verificar stop = 1
                        state <= VALID_DATA;
                    end else begin
                        frame_error <= 1;          // Error de frame
                        state       <= IDLE;
                    end
                end
            end

            // ----------------------------------------------------------------
            // VALID_DATA: Entregar byte válido
            // ----------------------------------------------------------------
            VALID_DATA: begin
                data_out   <= rx_shift;
                data_valid <= 1;                   // Pulso de 1 ciclo
                state      <= IDLE;
            end

        endcase
    end

endmodule