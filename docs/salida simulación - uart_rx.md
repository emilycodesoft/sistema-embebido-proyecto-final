```bash
# ========================================
# INICIO DE SIMULACIoN - UART RX
# Baudrate: 115200
# Periodo de bit: 8680 ns
# ========================================
#
#
# --- PRUEBA 1: Bytes validos (0-7) ---
# [1000] ns Enviando byte: 0x00 (  0)
# [87930] ns BYTE RECIBIDO: 0x00 (  0) - CORRECTO
# [96480] ns Enviando byte: 0x01 (  1)
# [183410] ns BYTE RECIBIDO: 0x01 (  1) - CORRECTO
# [191960] ns Enviando byte: 0x02 (  2)
# [278890] ns BYTE RECIBIDO: 0x02 (  2) - CORRECTO
# [287440] ns Enviando byte: 0x03 (  3)
# [374370] ns BYTE RECIBIDO: 0x03 (  3) - CORRECTO
# [382920] ns Enviando byte: 0x04 (  4)
# [469850] ns BYTE RECIBIDO: 0x04 (  4) - CORRECTO
# [478400] ns Enviando byte: 0x05 (  5)
# [565330] ns BYTE RECIBIDO: 0x05 (  5) - CORRECTO
# [573880] ns Enviando byte: 0x06 (  6)
# [660810] ns BYTE RECIBIDO: 0x06 (  6) - CORRECTO
# [669360] ns Enviando byte: 0x07 (  7)
# [756290] ns BYTE RECIBIDO: 0x07 (  7) - CORRECTO
#
# --- PRUEBA 2: Patrones de prueba ---
# [764840] ns Enviando byte: 0xaa (170)
# [851770] ns BYTE RECIBIDO: 0xaa (170) - CORRECTO
# [860320] ns Enviando byte: 0x55 ( 85)
# [947250] ns BYTE RECIBIDO: 0x55 ( 85) - CORRECTO
# [955800] ns Enviando byte: 0xff (255)
# [1042730] ns BYTE RECIBIDO: 0xff (255) - CORRECTO
# [1051280] ns Enviando byte: 0x00 (  0)
# [1138210] ns BYTE RECIBIDO: 0x00 (  0) - CORRECTO
#
# --- PRUEBA 3: Byte con error de frame ---
# [1146760] ns Enviando byte con ERROR: 0xbd
# [1224990] FRAME ERROR detectado
#
# --- PRUEBA 4: Bytes consecutivos rapidos ---
# [1259600] ns Enviando byte: 0x12 ( 18)
# [1311850] FRAME ERROR detectado
# [1355080] ns Enviando byte: 0x34 ( 52)
# [1390030] FRAME ERROR detectado
# [1450560] ns Enviando byte: 0x56 ( 86)
# [1476910] ns BYTE RECIBIDO: 0x33 ( 51) - CORRECTO
# [1546040] ns Enviando byte: 0x78 (120)
# [1563510] FRAME ERROR detectado
#
# --- PRUEBA 5: Glitch corto (falso inicio) ---
# [1641690] FRAME ERROR detectado
# [1669730] ns Enviando byte: 0x99 (153)
# [1756670] ns BYTE RECIBIDO: 0x99 (153) - CORRECTO
#
# ========================================
# SIMULACIoN COMPLETADA
# ========================================
# ** Note: $finish    : C:/Sistema embebido proyecto final/sistema_embedido/uart_rx_tb.v(198)
#    Time: 1775210 ns  Iteration: 0  Instance: /uart_rx_tb
```
