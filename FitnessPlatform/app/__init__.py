"""
Основной файл приложения Flask для платформы виртуальных фитнес-тренировок.
"""

import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, current_user
from flask_migrate import Migrate
from flask_mail import Mail
from flask_cors import CORS
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime

# Инициализация расширений
db = SQLAlchemy()
migrate = Migrate()
login_manager = LoginManager()
mail = Mail()

def create_app(config_class):
    """Фабрика создания приложения"""
    app = Flask(__name__)
    app.config.from_object(config_class)
    
    # Инициализация расширений с приложением
    db.init_app(app)
    migrate.init_app(app, db)
    login_manager.init_app(app)
    mail.init_app(app)
    CORS(app)
    
    # Настройка логирования
    if not app.debug:
        if not os.path.exists('logs'):
            os.mkdir('logs')
        file_handler = RotatingFileHandler('logs/fitness_platform.log', 
                                         maxBytes=10240, 
                                         backupCount=10)
        file_handler.setFormatter(logging.Formatter(
            '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
        ))
        file_handler.setLevel(logging.INFO)
        app.logger.addHandler(file_handler)
        app.logger.setLevel(logging.INFO)
        app.logger.info('Fitness Platform startup')
    
    # Настройка загрузчика пользователей
    @login_manager.user_loader
    def load_user(user_id):
        # Используем ленивый импорт
        from app.models.user import User
        return User.query.get(int(user_id))
    
    @login_manager.unauthorized_handler
    def unauthorized():
        from flask import flash, redirect, url_for
        flash('Пожалуйста, войдите в систему для доступа к этой странице.', 'warning')
        return redirect(url_for('auth.login'))
    
    # Контекстные процессоры
    @app.context_processor
    def inject_current_year():
        return {'current_year': datetime.now().year}
    
    from app.utils.helpers import get_pending_trainings_count

    @app.context_processor
    def inject_helpers():
        """Добавляет вспомогательные функции в контекст Jinja2"""
        return {
            'get_pending_trainings_count': get_pending_trainings_count,
        }
    
    @app.context_processor
    def inject_user_stats():
        # Импортируем внутри функции, чтобы избежать циклических импортов
        from flask_login import current_user
        
        if current_user.is_authenticated:
            try:
                from app.models import TrainingRegistration, Notification
                
                # Используем локальную переменную current_user
                stats = {
                    'upcoming_trainings': TrainingRegistration.query.filter_by(
                        user_id=current_user.id,
                        status='registered'
                    ).count(),
                    'completed_trainings': TrainingRegistration.query.filter_by(
                        user_id=current_user.id,
                        status='attended'
                    ).count(),
                    'unread_notifications': Notification.query.filter_by(
                        user_id=current_user.id,
                        is_read=False
                    ).count()
                }
                return {'user_stats': stats}
            except Exception as e:
                app.logger.error(f'Error in inject_user_stats: {e}')
                return {'user_stats': {}}
        return {'user_stats': {}}
    
    # Фильтры для Jinja2
    @app.template_filter('format_datetime')
    def format_datetime(value, format='%d.%m.%Y %H:%M'):
        if value is None:
            return ''
        return value.strftime(format)
    
    @app.template_filter('time_ago')
    def time_ago_filter(value):
        now = datetime.utcnow()
        diff = now - value
        if diff.days > 365:
            return f"{diff.days // 365} год(а) назад"
        if diff.days > 30:
            return f"{diff.days // 30} месяц(ев) назад"
        if diff.days > 0:
            return f"{diff.days} день(дней) назад"
        if diff.seconds > 3600:
            return f"{diff.seconds // 3600} час(а) назад"
        if diff.seconds > 60:
            return f"{diff.seconds // 60} минут(ы) назад"
        return "только что"
    
    # Регистрация Blueprints
    try:
        from app.routes.main import bp as main_bp
        app.register_blueprint(main_bp)
        app.logger.info('✓ Main blueprint registered')
    except Exception as e:
        app.logger.error(f'✗ Error registering main blueprint: {e}')
    
    try:
        from app.routes.auth import bp as auth_bp
        app.register_blueprint(auth_bp, url_prefix='/auth')
        app.logger.info('✓ Auth blueprint registered')
    except Exception as e:
        app.logger.error(f'✗ Error registering auth blueprint: {e}')
    
    try:
        from app.routes.trainings import bp as trainings_bp
        app.register_blueprint(trainings_bp, url_prefix='/trainings')
        app.logger.info('✓ Trainings blueprint registered')
    except Exception as e:
        app.logger.error(f'✗ Error registering trainings blueprint: {e}')
    
    try:
        from app.routes.progress import bp as progress_bp
        app.register_blueprint(progress_bp, url_prefix='/progress')
        app.logger.info('✓ Progress blueprint registered')
    except Exception as e:
        app.logger.error(f'✗ Error registering progress blueprint: {e}')
    
    return app
