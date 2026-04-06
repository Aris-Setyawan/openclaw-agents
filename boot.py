"""
Boot script for Wemos D1 Mini MicroPython
Runs before main.py on boot
"""

import machine
import time
import sys

print("\n=== Wemos D1 Mini Booting ===")
print("MicroPython " + sys.version)
print("Platform: " + sys.platform)

# Configure CPU frequency (optional)
# machine.freq(160000000)  # 160 MHz for ESP8266

# Blink onboard LED to indicate boot
led = machine.Pin(2, machine.Pin.OUT)  # D4 = GPIO2 = onboard LED (active LOW)
for i in range(3):
    led.value(0)  # LED ON (active LOW)
    time.sleep(0.1)
    led.value(1)  # LED OFF
    time.sleep(0.1)

print("Boot script complete.")
print("Starting main application...\n")

# Note: main.py will be executed automatically after this script