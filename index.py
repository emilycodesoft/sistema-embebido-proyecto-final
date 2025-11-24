from PIL import Image
import numpy as np
import matplotlib.pyplot as plt

import serial
import time

# --------------------------------------------------------
# 1. Cargar imagen y preparar procesamiento
# --------------------------------------------------------
img = Image.open("imagen.jpeg")      # <-- Cambia por tu imagen
img_gray = img.convert("L")         # "L" = escala de grises 8 bits
img_resized = img_gray.resize((640, 480))

# Convertir a arreglo numpy (480, 640)
img_np = np.array(img_resized)

# 4. Mostrar imágenes
plt.figure(figsize=(12, 4))

plt.subplot(1, 3, 1)
plt.title("Original")
plt.imshow(img)
plt.axis("off")

plt.subplot(1, 3, 2)
plt.title("Grises 8 bits")
plt.imshow(img_gray, cmap="gray")
plt.axis("off")

plt.subplot(1, 3, 3)
plt.title("640×480 Grises")
plt.imshow(img_resized, cmap="gray")
plt.axis("off")

plt.show()

# --------------------------------------------------------
# 2. Convertir cada pixel a 3 bits (0–7)
# --------------------------------------------------------
# Fórmula: floor((p * 7) / 255)
img_3bits = (img_np * 7) // 255
img_3bits = img_3bits.astype(np.uint8)

# --------------------------------------------------------
# 3. Flatten para envío secuencial por UART
# --------------------------------------------------------
flat = img_3bits.flatten()   # tamaño: 640*480 = 307200 bytes

print("Tamaño en bytes a enviar:", len(flat))


# --------------------------------------------------------
# 4. Guardar en archivo binario para verificación
# --------------------------------------------------------
with open("imagen_3bits.bin", "wb") as f:
    for pixel in flat:
        f.write(bytes([pixel]))  # solo 3 bits en los 3 LSB, el resto = 0

print("Archivo 'imagen_3bits.bin' generado correctamente.")

# --------------------------------------------------------
# 5. Enviar por UART usando PySerial
# --------------------------------------------------------
# Ajusta el puerto COM según tu PC:
# En Windows es COM3, COM4...
# En Linux /dev/ttyUSB0
""" ser = serial.Serial(
    port="COM4",
    baudrate=115200,
    bytesize=serial.EIGHTBITS,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_TWO,
    timeout=1
)

time.sleep(2)  # espera a que el FT232 se estabilice

# Enviar imagen byte por byte
for value in flat:
    ser.write(bytes([value]))
    time.sleep(0.00001)  # 10 microsegundos opcional

ser.close()

print("Imagen enviada correctamente.") """
