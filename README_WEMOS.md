# Wemos D1 Mini IoT Controller

Script MicroPython untuk Wemos D1 Mini (ESP8266) dengan:
- DHT11 Sensor (suhu & kelembapan)
- 2x Relay 5V (1 channel masing-masing)
- OLED Shield 0.66" (I2C, SSD1306)
- Dual Base Expansion Shield D1 Mini

## 📦 Hardware Requirements

1. **Wemos D1 Mini** (ESP8266) atau **Wemos D1 R32** (ESP32)
2. **DHT11** Temperature & Humidity Sensor
3. **2x Relay Module** 5V 1 Channel
4. **OLED Shield 0.66"** (SSD1306, I2C)
5. **Dual Base Expansion Shield** untuk D1 Mini
6. **Kabel jumper** male-female
7. **Power supply** 5V untuk relay dan Wemos

## 🔌 Pin Mapping (Default)

| Komponen | Pin Wemos | GPIO | Keterangan |
|----------|-----------|------|------------|
| DHT11 Data | D4 | GPIO2 | One-wire data |
| Relay 1 | D1 | GPIO5 | Active HIGH |
| Relay 2 | D2 | GPIO4 | Active HIGH |
| OLED SDA | D2 | GPIO4 | I2C Data (bentrok dengan relay2!) |
| OLED SCL | D1 | GPIO5 | I2C Clock (bentrok dengan relay1!) |

**⚠️ PERHATIAN:** Pin I2C default (D1/D2) bentrok dengan relay. Solusi:

### Opsi 1: Ganti pin relay
```python
PIN_RELAY1 = 0   # GPIO0 = D3
PIN_RELAY2 = 14  # GPIO14 = D5
```

### Opsi 2: Ganti pin I2C (jika OLED shield support)
```python
PIN_SDA = 12  # GPIO12 = D6
PIN_SCL = 13  # GPIO13 = D7
```

### Opsi 3: Pakai pin berbeda untuk masing-masing

## 🚀 Cara Deploy

### 1. Install MicroPython di Wemos D1 Mini

```bash
# Download firmware MicroPython untuk ESP8266
# dari: https://micropython.org/download/esp8266/

# Flash menggunakan esptool
esptool.py --port /dev/ttyUSB0 erase_flash
esptool.py --port /dev/ttyUSB0 --baud 460800 write_flash --flash_size=detect 0 esp8266-xxx.bin
```

### 2. Upload File ke Board

Gunakan **ampy** atau **rshell**:

```bash
# Install ampy
pip install adafruit-ampy

# Upload file (sesuaikan port serial)
ampy --port /dev/ttyUSB0 put wemos_d1_mini_iot.py main.py
ampy --port /dev/ttyUSB0 put ssd1306.py
```

### 3. Konfigurasi WiFi

Edit file `main.py` (sebelum upload) atau gunakan REPL:

```python
WIFI_SSID = "Nama_WiFi_Anda"
WIFI_PASS = "Password_WiFi_Anda"
```

### 4. Sesuaikan Pin Mapping

Edit bagian `# ========== KONFIGURASI ==========` di `main.py` sesuai koneksi hardware.

### 5. Reset Board

Reset Wemos D1 Mini, script akan jalan otomatis.

## 📟 Fitur

1. **Baca DHT11** setiap 5 detik
2. **Kontrol Relay** via program (otomatis berdasarkan suhu)
3. **Display OLED** menampilkan:
   - Suhu & kelembapan
   - Status relay (ON/OFF)
   - IP address jika terkoneksi WiFi
4. **Koneksi WiFi** otomatis
5. **Kontrol otomatis**: Relay 1 nyala jika suhu >30°C (untuk kipas)

## 🛠️ Modifikasi & Customization

### Tambah Web Server (Opsional)

Uncomment fungsi `start_web_server()` dan tambahkan di `main()` untuk kontrol via browser.

### Tambah MQTT

```python
import umqtt.simple

def mqtt_callback(topic, msg):
    # Handle MQTT messages
    pass

mqtt = umqtt.simple.MQTTClient("wemos_client", "broker.ip")
mqtt.set_callback(mqtt_callback)
mqtt.connect()
```

### Simpan Data ke SD Card

Jika pakai SD card shield, tambahkan:
```python
import sdcard
import os

sd = sdcard.SDCard(machine.SPI(1), machine.Pin(15))
os.mount(sd, '/sd')
```

## 🔧 Troubleshooting

### 1. OLED tidak muncul
- Cek koneksi SDA/SCL
- Cek alamat I2C (biasanya 0x3C atau 0x3D)
- Cek power OLED (3.3V)

### 2. DHT11 tidak terbaca
- Tambahkan resistor 10k pull-up antara data dan VCC
- Cek koneksi ground
- Ganti pin jika perlu

### 3. Relay tidak berfungsi
- Pastikan relay aktif HIGH (bisa aktif LOW tergantung module)
- Cek power 5V untuk relay
- Relay mungkin butuh current lebih besar, gunakan transistor driver

### 4. WiFi tidak konek
- Cek SSID/password
- Jarak dari router
- ESP8266 butuh WiFi 2.4GHz

## 📁 File Structure

```
wemos_project/
├── main.py                 # Script utama (rename dari wemos_d1_mini_iot.py)
├── ssd1306.py              # Driver OLED
├── boot.py                 # Script startup (opsional)
└── README_WEMOS.md         # Dokumentasi ini
```

## 📞 Support

Jika ada masalah:
1. Cek serial monitor (115200 baud)
2. Periksa koneksi hardware
3. Sesuaikan pin mapping
4. Coba contoh code sederhana dulu per komponen

## 📄 License

MIT License - bebas modifikasi dan distribusi.

---
**Dibuat oleh:** Santa (OpenClaw Assistant)  
**Tanggal:** 6 April 2026  
**Untuk:** Aris Setiawan