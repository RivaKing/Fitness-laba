#!/usr/bin/env python
"""
Точка входа в приложение
"""

import os
import sys

# Добавляем текущую директорию в путь Python
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

try:
    from app import create_app
    from config import config
    print("✓ Все модули импортированы успешно")
except ImportError as e:
    print(f"✗ Ошибка импорта: {e}")
    print("Текущая рабочая директория:", os.getcwd())
    print("Содержимое папки:", os.listdir('.'))
    sys.exit(1)

# Определение конфига
config_name = os.getenv('FLASK_CONFIG', 'default')
print(f"Используется конфиг: {config_name}")

# Создаем приложение
app = create_app(config[config_name])

if __name__ == '__main__':
    # Проверка маршрутов
    print("\nЗарегистрированные маршруты:")
    for rule in app.url_map.iter_rules():
        print(f"  {rule.endpoint}: {rule.rule}")
    
    # Запуск приложения
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'true').lower() == 'true'
    
    print(f"\n✓ Запуск приложения на порту {port} (debug={debug})")
    app.run(
        host='0.0.0.0',
        port=port,
        debug=debug,
        threaded=True
    )