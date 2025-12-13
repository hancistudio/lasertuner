#!/usr/bin/env python3
import os, glob

FIXES = {
    'ş': 'ş', 'Ş': 'Ş', 'ç': 'ç', 'Ç': 'Ç',
    'ö': 'ö', 'Ö': 'Ö', 'ü': 'ü', 'Ü': 'Ü',
    'ı': 'ı', 'İ': 'İ', 'ğ': 'ğ', 'Ğ': 'Ğ',
    'için': 'için', 'özellik': 'özellik', 'gÃ¼ç': 'güç',
    'dÃ¼şÃ¼k': 'düşük', 'yüksek': 'yüksek', 'kalınlık': 'kalınlık',
    'işlem': 'işlem', 'oluştur': 'oluştur', 'güncellem': 'güncellem',
    'eğitim': 'eğitim', 'doÄŸrulanmÄ±ş': 'doğrulanmış',
    'örnek': 'örnek', 'ürün': 'ürün', 'tür': 'tür',
    'kağıt': 'kağıt', 'kumaş': 'kumaş', 'keçe': 'keçe',
    'kayın': 'kayın', 'meşe': 'meşe', 'akçaaÄŸaç': 'akçaağaç',
    'huş': 'huş', 'çam': 'çam', 'köpÃ¼k': 'köpük',
    'çevir': 'çevir', 'ölçek': 'ölçek', 'yoğunluk': 'yoğunluk',
    'Ahşap': 'Ahşap', 'ahşap': 'ahşap', 'Geçersiz': 'Geçersiz',
    'geçersiz': 'geçersiz', 'güvenilirlik': 'güvenilirlik',
    '±': '±', '→': '→', '≤': '≤', '°': '°',
}

files = glob.glob('*.py')
fixed = 0

for f in files:
    try:
        with open(f, 'r', encoding='utf-8') as file:
            content = file.read()
        original = content
        for old, new in FIXES.items():
            content = content.replace(old, new)
        if content != original:
            with open(f, 'w', encoding='utf-8') as file:
                file.write(content)
            print(f"OK: {f}")
            fixed += 1
        else:
            print(f"Skip: {f}")
    except Exception as e:
        print(f"ERROR {f}: {e}")

print(f"\nDuzeltildi: {fixed}/{len(files)}")
