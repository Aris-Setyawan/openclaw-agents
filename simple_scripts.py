#!/usr/bin/env python3
"""
Kumpulan Script Python Sederhana
Oleh: Santa 🧑‍🎄
"""

import os
import sys
import json
import datetime
import hashlib
import random
import string
from pathlib import Path
from typing import List, Dict, Optional

# ==================== UTILITY FUNCTIONS ====================

def generate_password(length: int = 12, include_symbols: bool = True) -> str:
    """
    Generate password acak dengan panjang tertentu.
    
    Args:
        length: Panjang password (default: 12)
        include_symbols: Apakah termasuk simbol (default: True)
    
    Returns:
        Password acak
    """
    chars = string.ascii_letters + string.digits
    if include_symbols:
        chars += "!@#$%^&*()_+-=[]{}|;:,.<>?"
    
    return ''.join(random.choice(chars) for _ in range(length))

def calculate_file_hash(filepath: str, algorithm: str = "sha256") -> str:
    """
    Hitung hash dari file.
    
    Args:
        filepath: Path ke file
        algorithm: Algoritma hash (md5, sha1, sha256)
    
    Returns:
        Hash string
    """
    hash_func = hashlib.new(algorithm)
    
    try:
        with open(filepath, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b''):
                hash_func.update(chunk)
        return hash_func.hexdigest()
    except FileNotFoundError:
        return f"File tidak ditemukan: {filepath}"
    except Exception as e:
        return f"Error: {str(e)}"

def format_size(size_bytes: int) -> str:
    """
    Format ukuran bytes menjadi human readable.
    
    Args:
        size_bytes: Ukuran dalam bytes
    
    Returns:
        String format (KB, MB, GB, etc)
    """
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} PB"

def list_files_info(directory: str = ".") -> List[Dict]:
    """
    List semua file dalam direktori dengan info.
    
    Args:
        directory: Path direktori (default: current)
    
    Returns:
        List dictionary berisi info file
    """
    files_info = []
    try:
        for item in os.listdir(directory):
            full_path = os.path.join(directory, item)
            if os.path.isfile(full_path):
                stat = os.stat(full_path)
                files_info.append({
                    'name': item,
                    'size': stat.st_size,
                    'size_human': format_size(stat.st_size),
                    'modified': datetime.datetime.fromtimestamp(stat.st_mtime),
                    'created': datetime.datetime.fromtimestamp(stat.st_ctime)
                })
    except Exception as e:
        print(f"Error membaca direktori: {e}")
    
    return files_info

def count_words_in_file(filepath: str) -> Dict:
    """
    Hitung jumlah kata, karakter, dan baris dalam file.
    
    Args:
        filepath: Path ke file teks
    
    Returns:
        Dictionary dengan statistik
    """
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        lines = content.split('\n')
        words = content.split()
        
        return {
            'file': filepath,
            'lines': len(lines),
            'words': len(words),
            'characters': len(content),
            'characters_no_space': len(content.replace(' ', '')),
            'avg_word_length': sum(len(w) for w in words) / len(words) if words else 0
        }
    except Exception as e:
        return {'error': str(e)}

# ==================== MAIN MENU ====================

def show_menu():
    """Tampilkan menu utama."""
    print("\n" + "="*50)
    print("SCRIPT PYTHON SEDERHANA")
    print("="*50)
    print("1. Generate Password")
    print("2. Hitung Hash File")
    print("3. List File dengan Info")
    print("4. Analisis File Teks")
    print("5. Konverter Suhu")
    print("6. Kalkulator Sederhana")
    print("7. Keluar")
    print("="*50)

def temperature_converter():
    """Konverter suhu antara Celsius, Fahrenheit, dan Kelvin."""
    print("\n--- KONVERTER SUHU ---")
    print("1. Celsius → Fahrenheit")
    print("2. Fahrenheit → Celsius")
    print("3. Celsius → Kelvin")
    print("4. Kelvin → Celsius")
    
    try:
        choice = input("Pilih konversi (1-4): ").strip()
        value = float(input("Masukkan nilai suhu: "))
        
        if choice == '1':
            result = (value * 9/5) + 32
            print(f"{value}°C = {result:.2f}°F")
        elif choice == '2':
            result = (value - 32) * 5/9
            print(f"{value}°F = {result:.2f}°C")
        elif choice == '3':
            result = value + 273.15
            print(f"{value}°C = {result:.2f}K")
        elif choice == '4':
            result = value - 273.15
            print(f"{value}K = {result:.2f}°C")
        else:
            print("Pilihan tidak valid!")
    except ValueError:
        print("Input harus berupa angka!")

def simple_calculator():
    """Kalkulator sederhana."""
    print("\n--- KALKULATOR SEDERHANA ---")
    print("Operasi: +, -, *, /, %, **")
    
    try:
        num1 = float(input("Masukkan angka pertama: "))
        operator = input("Masukkan operator (+, -, *, /, %, **): ").strip()
        num2 = float(input("Masukkan angka kedua: "))
        
        if operator == '+':
            result = num1 + num2
        elif operator == '-':
            result = num1 - num2
        elif operator == '*':
            result = num1 * num2
        elif operator == '/':
            if num2 == 0:
                print("Error: Pembagian dengan nol!")
                return
            result = num1 / num2
        elif operator == '%':
            result = num1 % num2
        elif operator == '**':
            result = num1 ** num2
        else:
            print("Operator tidak valid!")
            return
        
        print(f"Hasil: {num1} {operator} {num2} = {result}")
    except ValueError:
        print("Input harus berupa angka!")

# ==================== MAIN FUNCTION ====================

def main():
    """Fungsi utama."""
    print("Selamat datang di Kumpulan Script Python Sederhana!")
    print("Script ini berisi berbagai fungsi utilitas yang berguna.")
    
    while True:
        show_menu()
        choice = input("\nPilih menu (1-7): ").strip()
        
        if choice == '1':
            print("\n--- GENERATE PASSWORD ---")
            try:
                length = int(input("Panjang password (default 12): ") or "12")
                symbols = input("Include symbols? (y/n, default y): ").lower() != 'n'
                password = generate_password(length, symbols)
                print(f"Password: {password}")
                print(f"Strength: {'Strong' if length >= 12 else 'Medium' if length >= 8 else 'Weak'}")
            except ValueError:
                print("Panjang harus angka!")
        
        elif choice == '2':
            print("\n--- HITUNG HASH FILE ---")
            filepath = input("Masukkan path file: ").strip()
            if os.path.exists(filepath):
                print("Pilih algoritma:")
                print("1. MD5 (cepat, untuk checksum)")
                print("2. SHA1 (aman, cepat)")
                print("3. SHA256 (sangat aman, default)")
                algo_choice = input("Pilihan (1-3, default 3): ").strip()
                
                algo_map = {'1': 'md5', '2': 'sha1', '3': 'sha256'}
                algorithm = algo_map.get(algo_choice, 'sha256')
                
                hash_result = calculate_file_hash(filepath, algorithm)
                print(f"{algorithm.upper()} hash: {hash_result}")
            else:
                print(f"File tidak ditemukan: {filepath}")
        
        elif choice == '3':
            print("\n--- LIST FILE DENGAN INFO ---")
            directory = input("Masukkan path direktori (default .): ").strip() or "."
            files = list_files_info(directory)
            
            if files:
                print(f"\nDitemukan {len(files)} file di '{directory}':")
                for i, file_info in enumerate(files, 1):
                    print(f"{i}. {file_info['name']}")
                    print(f"   Size: {file_info['size_human']}")
                    print(f"   Modified: {file_info['modified'].strftime('%Y-%m-%d %H:%M:%S')}")
                    print()
            else:
                print("Tidak ada file atau direktori tidak ditemukan.")
        
        elif choice == '4':
            print("\n--- ANALISIS FILE TEKS ---")
            filepath = input("Masukkan path file teks: ").strip()
            if os.path.exists(filepath):
                stats = count_words_in_file(filepath)
                if 'error' not in stats:
                    print(f"\nStatistik untuk '{filepath}':")
                    print(f"  Baris: {stats['lines']}")
                    print(f"  Kata: {stats['words']}")
                    print(f"  Karakter (total): {stats['characters']}")
                    print(f"  Karakter (tanpa spasi): {stats['characters_no_space']}")
                    print(f"  Rata-rata panjang kata: {stats['avg_word_length']:.2f}")
                else:
                    print(f"Error: {stats['error']}")
            else:
                print(f"File tidak ditemukan: {filepath}")
        
        elif choice == '5':
            temperature_converter()
        
        elif choice == '6':
            simple_calculator()
        
        elif choice == '7':
            print("\nTerima kasih telah menggunakan script ini!")
            print("Sampai jumpa! 🧑‍🎄")
            break
        
        else:
            print("Pilihan tidak valid! Silakan pilih 1-7.")
        
        input("\nTekan Enter untuk melanjutkan...")

# ==================== RUN AS SCRIPT ====================

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nScript dihentikan oleh user.")
        sys.exit(0)
    except Exception as e:
        print(f"\nError tidak terduga: {e}")
        sys.exit(1)