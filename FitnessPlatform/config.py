import os
from datetime import timedelta

class Config:
    """Базовый конфиг"""
    # Безопасность
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    
    # База данных
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'sqlite:///fitness_platform.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
    }
    
    # Flask-Login
    REMEMBER_COOKIE_DURATION = timedelta(days=30)
    SESSION_PROTECTION = 'strong'
    
    # Flask-Mail
    MAIL_SERVER = os.environ.get('MAIL_SERVER', 'smtp.gmail.com')
    MAIL_PORT = int(os.environ.get('MAIL_PORT', 587))
    MAIL_USE_TLS = os.environ.get('MAIL_USE_TLS', 'true').lower() == 'true'
    MAIL_USERNAME = os.environ.get('MAIL_USERNAME')
    MAIL_PASSWORD = os.environ.get('MAIL_PASSWORD')
    MAIL_DEFAULT_SENDER = os.environ.get('MAIL_DEFAULT_SENDER', 'noreply@fitnessplatform.com')
    
    # Загрузка файлов
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB
    UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
    ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'mp4', 'mov', 'avi'}
    
    # Настройки приложения
    APP_NAME = 'Фитнес Платформа'
    APP_VERSION = '1.0.0'
    ITEMS_PER_PAGE = 20
    
    # Настройки тренировок
    MAX_TRAINING_DURATION = 240  # 4 часа
    MIN_TRAINING_DURATION = 15   # 15 минут
    MAX_TRAINING_PARTICIPANTS = 100
    TRAINING_REGISTRATION_DEADLINE = 1  # час до начала
    
    # Настройки безопасности
    PASSWORD_RESET_TIMEOUT = 3600  # 1 час
    ACCOUNT_VERIFICATION_TIMEOUT = 86400  # 24 часа
    MAX_LOGIN_ATTEMPTS = 5
    LOCKOUT_TIME = 300  # 5 минут
    
    # API
    API_PREFIX = '/api/v1'
    JSON_SORT_KEYS = False
    JSON_AS_ASCII = False
    
    # Логирование
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    LOG_FILE = 'logs/app.log'
    
    # Отладка
    DEBUG = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'
    TESTING = False
    
    @staticmethod
    def init_app(app):
        """Инициализация приложения с конфигом"""
        # Создание папок, если они не существуют
        for folder in ['logs', 'uploads', 'uploads/training_videos', 'uploads/user_avatars']:
            folder_path = os.path.join(app.root_path, '..', folder)
            os.makedirs(folder_path, exist_ok=True)

class DevelopmentConfig(Config):
    """Конфиг для разработки"""
    DEBUG = True
    SQLALCHEMY_DATABASE_URI = os.environ.get('DEV_DATABASE_URL') or 'sqlite:///dev_fitness_platform.db'
    LOG_LEVEL = 'DEBUG'

class TestingConfig(Config):
    """Конфиг для тестирования"""
    TESTING = True
    SQLALCHEMY_DATABASE_URI = os.environ.get('TEST_DATABASE_URL') or 'sqlite:///test_fitness_platform.db'
    WTF_CSRF_ENABLED = False
    SERVER_NAME = 'localhost:5000'

class ProductionConfig(Config):
    """Конфиг для продакшена"""
    DEBUG = False
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
    
    @classmethod
    def init_app(cls, app):
        Config.init_app(app)
        
        # Настройка логирования для продакшена
        import logging
        from logging.handlers import RotatingFileHandler
        
        file_handler = RotatingFileHandler(
            cls.LOG_FILE,
            maxBytes=10485760,  # 10MB
            backupCount=10
        )
        file_handler.setFormatter(logging.Formatter(
            '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
        ))
        file_handler.setLevel(logging.WARNING)
        app.logger.addHandler(file_handler)

# Словарь конфигов
config = {
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}