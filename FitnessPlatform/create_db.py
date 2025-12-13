"""Скрипт для создания базы данных и таблиц"""
import sys
import os

# Добавляем текущую директорию в путь Python
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

try:
    from app import create_app, db
    from config import config
    print("✓ Модули импортированы успешно")
except ImportError as e:
    print(f"✗ Ошибка импорта: {e}")
    print("Текущая рабочая директория:", os.getcwd())
    print("Содержимое папки:", os.listdir('.'))
    sys.exit(1)

# Создаем приложение с конфигом по умолчанию
app = create_app(config['default'])

with app.app_context():
    try:
        # Создаем все таблицы
        print("Создание базы данных...")
        db.create_all()
        print("✓ Таблицы созданы успешно!")
        
        # Импортируем модели после создания app
        from app.models.user import User, UserProfile
        from app.models.training import TrainingCategory
        from app.models.system import SystemSetting
        
        # Создаем начальные данные (опционально)
        # Создаем категории тренировок
        categories = [
            {'name': 'Йога', 'description': 'Тренировки по йоге', 'color': '#FF6B6B'},
            {'name': 'Кардио', 'description': 'Кардио тренировки', 'color': '#4ECDC4'},
            {'name': 'Силовые', 'description': 'Силовые тренировки', 'color': '#45B7D1'},
            {'name': 'Пилатес', 'description': 'Тренировки пилатес', 'color': '#96CEB4'},
            {'name': 'Стретчинг', 'description': 'Растяжка', 'color': '#FFEAA7'},
        ]
        
        for cat_data in categories:
            if not TrainingCategory.query.filter_by(name=cat_data['name']).first():
                category = TrainingCategory(**cat_data)
                db.session.add(category)
                print(f"✓ Создана категория: {cat_data['name']}")
        
        # Создаем системные настройки
        settings = [
            {'key': 'site_name', 'value': 'FitTrack', 'value_type': 'string', 'category': 'general'},
            {'key': 'maintenance_mode', 'value': 'false', 'value_type': 'boolean', 'category': 'system'},
            {'key': 'default_language', 'value': 'ru', 'value_type': 'string', 'category': 'localization'},
            {'key': 'timezone', 'value': 'Europe/Moscow', 'value_type': 'string', 'category': 'localization'},
            {'key': 'max_trainings_per_day', 'value': '3', 'value_type': 'integer', 'category': 'trainings'},
            {'key': 'cancellation_deadline_hours', 'value': '1', 'value_type': 'integer', 'category': 'trainings'},
        ]
        
        for setting_data in settings:
            if not SystemSetting.query.filter_by(key=setting_data['key']).first():
                setting = SystemSetting(**setting_data)
                db.session.add(setting)
                print(f"✓ Создана настройка: {setting_data['key']}")
        
        # Создаем тестового администратора
        if not User.query.filter_by(email='admin@example.com').first():
            admin = User(
                email='admin@example.com',
                username='admin',
                role='admin',
                is_active=True,
                is_verified=True
            )
            admin.set_password('admin123')
            db.session.add(admin)
            
            # Создаем профиль
            profile = UserProfile(
                user=admin,
                full_name='Администратор Системы',
                city='Москва',
                country='Россия',
                language='ru',
                timezone='Europe/Moscow'
            )
            db.session.add(profile)
            
            print("✓ Создан тестовый администратор: admin@example.com / admin123")
        
        db.session.commit()
        print("\n✓ База данных успешно инициализирована!")
        print("Для запуска приложения выполните: python run.py")
        
    except Exception as e:
        print(f"✗ Ошибка при создании базы данных: {e}")
        import traceback
        traceback.print_exc()
        db.session.rollback()