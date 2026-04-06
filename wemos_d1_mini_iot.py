#!/usr/bin/env python3
"""
Wemos D1 Mini IoT Controller - MicroPython Script
Untuk Wemos D1 Mini (ESP8266) dengan:
- DHT11 Sensor (suhu & kelembapan)
- 2x Relay 5V (1 channel masing-masing)
- OLED Shield 0.66" (I2C, SSD1306)
- Dual Base Expansion Shield D1 Mini

PIN MAPPING (default D1 Mini):
- DHT11   : GPIO2 (D4) - one wire data
- Relay 1 : GPIO5 (D1) - aktif HIGH
- Relay 2 : GPIO4 (D2) - aktif HIGH
- OLED I2C: SDA=GPIO4 (D2), SCL=GPIO5 (D1) *HATI: bentrok dengan relay!
  Jika bentrok, ganti pin relay ke GPIO0 (D3) dan GPIO14 (D5)

Cara deploy:
1. Install MicroPython di Wemos D1 Mini
2. Copy file ini ke board (rename ke main.py)
3. Upload library ssd1306.py jika belum ada
4. Sesuaikan config WiFi dan pin mapping
5. Reset board

Author: Santa (OpenClaw Assistant)
Date: 2026-04-06
"""

# ========== KONFIGURASI ==========
# WiFi Settings
WIFI_SSID = "Your_WiFi_SSID"
WIFI_PASS = "Your_WiFi_Password"

# Pin Mapping (sesuaikan dengan koneksi hardware)
PIN_DHT = 2      # GPIO2 = D4
PIN_RELAY1 = 5   # GPIO5 = D1
PIN_RELAY2 = 4   # GPIO4 = D2
PIN_SDA = 4      # GPIO4 = D2 (I2C SDA)
PIN_SCL = 5      # GPIO5 = D1 (I2C SCL)

# OLED Settings
OLED_WIDTH = 64   # 0.66" OLED biasanya 64x48
OLED_HEIGHT = 48
OLED_I2C_ADDR = 0x3C  # Alamat I2C SSD1306

# Interval pembacaan sensor (detik)
READ_INTERVAL = 5

# ========== IMPORTS ==========
import machine
import dht
import ssd1306
import network
import time
import sys

# ========== INISIALISASI HARDWARE ==========
def init_hardware():
    """Inisialisasi semua hardware (DHT, relay, OLED)"""
    print("Initializing hardware...")
    
    # DHT11 Sensor
    dht_sensor = dht.DHT11(machine.Pin(PIN_DHT))
    
    # Relay (active HIGH)
    relay1 = machine.Pin(PIN_RELAY1, machine.Pin.OUT)
    relay2 = machine.Pin(PIN_RELAY2, machine.Pin.OUT)
    relay1.value(0)  # Matikan relay awal
    relay2.value(0)
    
    # OLED Display (I2C)
    i2c = machine.I2C(scl=machine.Pin(PIN_SCL), sda=machine.Pin(PIN_SDA))
    try:
        oled = ssd1306.SSD1306_I2C(OLED_WIDTH, OLED_HEIGHT, i2c, OLED_I2C_ADDR)
        oled.fill(0)
        oled.text("Wemos D1 Mini", 0, 0, 1)
        oled.text("Starting...", 0, 16, 1)
        oled.show()
        print("OLED initialized")
    except Exception as e:
        print(f"OLED error: {e}")
        oled = None
    
    return {
        'dht': dht_sensor,
        'relay1': relay1,
        'relay2': relay2,
        'oled': oled,
        'i2c': i2c
    }

# ========== FUNGSI WiFi ==========
def connect_wifi():
    """Koneksi ke WiFi"""
    print(f"Connecting to WiFi: {WIFI_SSID}")
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    if not wlan.isconnected():
        wlan.connect(WIFI_SSID, WIFI_PASS)
        timeout = 20
        while not wlan.isconnected() and timeout > 0:
            time.sleep(1)
            timeout -= 1
            print(".", end="")
    
    if wlan.isconnected():
        ip = wlan.ifconfig()[0]
        print(f"\nWiFi connected! IP: {ip}")
        return ip
    else:
        print("\nWiFi connection failed!")
        return None

# ========== FUNGSI BACA SENSOR ==========
def read_sensor(dht_sensor):
    """Baca data dari DHT11"""
    try:
        dht_sensor.measure()
        temp = dht_sensor.temperature()
        hum = dht_sensor.humidity()
        return temp, hum
    except Exception as e:
        print(f"DHT11 read error: {e}")
        return None, None

# ========== FUNGSI KONTROL RELAY ==========
def set_relay(relay, state, relay_name=""):
    """Kontrol relay (state: True=ON, False=OFF)"""
    relay.value(1 if state else 0)
    status = "ON" if state else "OFF"
    print(f"Relay {relay_name}: {status}")
    return state

# ========== FUNGSI OLED DISPLAY ==========
def update_display(oled, temp, hum, relay1_state, relay2_state, ip=None):
    """Update tampilan OLED"""
    if oled is None:
        return
    
    oled.fill(0)
    
    # Baris 1: Suhu & Kelembapan
    if temp is not None and hum is not None:
        oled.text(f"T:{temp}C H:{hum}%", 0, 0, 1)
    else:
        oled.text("Sensor Error", 0, 0, 1)
    
    # Baris 2: Status Relay
    r1 = "ON" if relay1_state else "OFF"
    r2 = "ON" if relay2_state else "OFF"
    oled.text(f"R1:{r1} R2:{r2}", 0, 10, 1)
    
    # Baris 3: IP Address jika ada
    if ip:
        oled.text(f"IP:{ip[-8:]}", 0, 20, 1)  # Tampilkan 8 char terakhir
    
    # Baris 4: Status
    oled.text("Wemos D1 Mini", 0, 30, 1)
    
    oled.show()

# ========== MAIN LOOP ==========
def main():
    """Program utama"""
    print("=== Wemos D1 Mini IoT Controller ===")
    
    # Inisialisasi hardware
    hw = init_hardware()
    
    # Koneksi WiFi
    ip = connect_wifi()
    
    # Variabel status
    relay1_state = False
    relay2_state = False
    last_read = time.time() - READ_INTERVAL
    
    print("System ready! Starting main loop...")
    print("Press Ctrl+C to stop")
    
    try:
        while True:
            current_time = time.time()
            
            # Baca sensor setiap interval
            if current_time - last_read >= READ_INTERVAL:
                temp, hum = read_sensor(hw['dht'])
                last_read = current_time
                
                # Update OLED
                update_display(
                    hw['oled'], temp, hum, 
                    relay1_state, relay2_state, ip
                )
                
                # Print ke serial monitor
                if temp is not None and hum is not None:
                    print(f"Sensor: {temp}C, {hum}%")
            
            # Contoh kontrol relay otomatis (bisa dihapus/modifikasi)
            # Jika suhu > 30°C, nyalakan relay 1 untuk kipas
            if temp is not None and temp > 30 and not relay1_state:
                relay1_state = set_relay(hw['relay1'], True, "1 (Fan)")
            elif temp is not None and temp <= 28 and relay1_state:
                relay1_state = set_relay(hw['relay1'], False, "1 (Fan)")
            
            # Delay kecil untuk hemat CPU
            time.sleep(0.1)
            
    except KeyboardInterrupt:
        print("\nProgram stopped by user")
    except Exception as e:
        print(f"Error in main loop: {e}")
        sys.print_exception(e)
    
    # Matikan relay saat exit
    hw['relay1'].value(0)
    hw['relay2'].value(0)
    print("Relays turned OFF")
    print("Goodbye!")

# ========== WEB SERVER OPTIONAL ==========
def start_web_server():
    """
    Fungsi opsional: web server untuk kontrol via browser
    Uncomment jika ingin fitur web control
    """
    # import socket
    # ... kode web server sederhana ...
    pass

# ========== RUN PROGRAM ==========
if __name__ == "__main__":
    main()