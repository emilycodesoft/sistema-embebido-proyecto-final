module uart_fsm (
    input  wire clk,         // reloj del FPGA 50 MHz
    input  wire rx,          // pin RX desde FT232
    output wire tx,          // pin TX hacia FT232 (eco)
    output reg  [7:0] data_out,   // byte recibido
    output reg  data_valid        // pulso 1 clk cuando llega un byte
);

    // ================================================
    // Parámetros UART
    // ================================================
    localparam BAUD_TICK = 434; // divisor para 115200 baudios a 50 MHz

    // ================================================
    // Generador de ticks a 115200 Hz
    // ================================================
    reg [15:0] baud_cnt = 0;
    reg        baud_tick = 0;

    always @(posedge clk) begin
        if (baud_cnt == BAUD_TICK) begin
            baud_cnt  <= 0;
            baud_tick <= 1;
        end else begin
            baud_cnt  <= baud_cnt + 1;
            baud_tick <= 0;
        end
    end

    // ================================================
    // FSM RECEPTOR UART
    // ================================================
    localparam RX_IDLE  = 0,
               RX_START = 1,
               RX_DATA  = 2,
               RX_STOP1 = 3,
               RX_STOP2 = 4,
               RX_DONE  = 5;

    reg [2:0]  rx_state = RX_IDLE;
    reg [7:0]  rx_shift = 0;
    reg [2:0]  bit_idx  = 0;

    always @(posedge clk) begin
        data_valid <= 0; // pulso corto

        case (rx_state)

            // ----------------------------------------------------------
            RX_IDLE: begin
                if (rx == 0)  // detecta start bit
                    rx_state <= RX_START;
            end

            // ----------------------------------------------------------
            RX_START: begin
                if (baud_tick) begin
                    rx_state <= RX_DATA;
                    bit_idx  <= 0;
                end
            end

            // ----------------------------------------------------------
            RX_DATA: begin
                if (baud_tick) begin
                    rx_shift[bit_idx] <= rx; // guardar bit
                    bit_idx <= bit_idx + 1;

                    if (bit_idx == 7)
                        rx_state <= RX_STOP1;
                end
            end

            // ----------------------------------------------------------
            RX_STOP1: begin
                if (baud_tick)
                    rx_state <= RX_STOP2;
            end

            RX_STOP2: begin
                if (baud_tick)
                    rx_state <= RX_DONE;
            end

            // ----------------------------------------------------------
            RX_DONE: begin
                data_out   <= rx_shift;
                data_valid <= 1;
                rx_state   <= RX_IDLE;
            end

        endcase
    end

    // ====================================================
    // FSM TRANSMISOR (eco)
    // ====================================================
    localparam TX_IDLE  = 0,
               TX_START = 1,
               TX_DATA  = 2,
               TX_STOP1 = 3,
               TX_STOP2 = 4;

    reg [2:0]  tx_state = TX_IDLE;
    reg [7:0]  tx_shift = 0;
    reg [2:0]  tx_idx   = 0;
    reg        tx_reg   = 1;

    assign tx = tx_reg;

    always @(posedge clk) begin
        case (tx_state)

            TX_IDLE: begin
                tx_reg <= 1;

                if (data_valid) begin
                    tx_shift <= data_out;
                    tx_state <= TX_START;
                end
            end

            TX_START: begin
                if (baud_tick) begin
                    tx_reg   <= 0; // start bit
                    tx_state <= TX_DATA;
                    tx_idx   <= 0;
                end
            end

            TX_DATA: begin
                if (baud_tick) begin
                    tx_reg <= tx_shift[tx_idx];
                    tx_idx <= tx_idx + 1;

                    if (tx_idx == 7)
                        tx_state <= TX_STOP1;
                end
            end

            TX_STOP1: begin
                if (baud_tick) begin
                    tx_reg <= 1;
                    tx_state <= TX_STOP2;
                end
            end

            TX_STOP2: begin
                if (baud_tick) begin
                    tx_reg <= 1;
                    tx_state <= TX_IDLE;
                end
            end

        endcase
    end

endmodule
