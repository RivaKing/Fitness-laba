# Complete-FitnessPlatform-Project.ps1
# Полный скрипт создания проекта Flask для платформы виртуальных фитнес-тренировок

Write-Host "Создание полной структуры проекта для платформы виртуальных фитнес-тренировок..." -ForegroundColor Green
Write-Host "Это займет несколько минут..." -ForegroundColor Yellow

# Основная папка проекта
$projectRoot = "FitnessPlatform"
if (Test-Path $projectRoot) {
    $response = Read-Host "Папка '$projectRoot' уже существует. Удалить и создать заново? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Отмена операции." -ForegroundColor Red
        exit
    }
    Remove-Item -Path $projectRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
Set-Location $projectRoot

Write-Host "Создана корневая папка проекта: $projectRoot" -ForegroundColor Green

# Создание структуры директорий
Write-Host "`nСоздание структуры директорий..." -ForegroundColor Cyan

$directories = @(
    "app",
    "app/static",
    "app/static/css",
    "app/static/js",
    "app/static/images",
    "app/templates",
    "app/templates/auth",
    "app/templates/trainings",
    "app/templates/progress",
    "app/templates/admin",
    "app/templates/errors",
    "app/models",
    "app/routes",
    "app/utils",
    "app/forms",
    "app/middleware",
    "app/services",
    "migrations",
    "tests",
    "tests/unit",
    "tests/integration",
    "tests/fixtures",
    "config",
    "docs",
    "scripts",
    "logs",
    "data",
    "uploads",
    "uploads/training_videos",
    "uploads/user_avatars"
)

foreach ($dir in $directories) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Host "  Создана директория: $dir" -ForegroundColor DarkCyan
}

# 1. Основной файл приложения app/__init__.py
Write-Host "`nСоздание основных файлов Python..." -ForegroundColor Cyan

$appInitContent = @'
"""
Основной файл приложения Flask для платформы виртуальных фитнес-тренировок.
Инициализация приложения, базы данных, миграций и менеджера логина.
"""

import os
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, g
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from flask_migrate import Migrate
from flask_mail import Mail
from flask_cors import CORS
from datetime import datetime, timedelta, date
import logging
from logging.handlers import RotatingFileHandler
import json

# Инициализация расширений
db = SQLAlchemy()
migrate = Migrate()
login_manager = LoginManager()
mail = Mail()

def create_app(config_class='config.Config'):
    """Фабрика создания приложения"""
    app = Flask(__name__)
    app.config.from_object(config_class)
    
    # Инициализация расширений
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
    
    # Импорт моделей (после инициализации db)
    from app.models.user import User, Trainer, Client
    from app.models.training import Training, TrainingRegistration, TrainingCategory
    from app.models.progress import Progress, Goal, Achievement
    from app.models.feedback import Feedback, Rating
    from app.models.notification import Notification
    from app.models.system import AuditLog, SystemSetting
    
    # Настройка загрузчика пользователей
    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))
    
    @login_manager.unauthorized_handler
    def unauthorized():
        flash('Пожалуйста, войдите в систему для доступа к этой странице.', 'warning')
        return redirect(url_for('auth.login'))
    
    # Регистрация Blueprints
    from app.routes.auth import bp as auth_bp
    from app.routes.trainings import bp as trainings_bp
    from app.routes.progress import bp as progress_bp
    from app.routes.admin import bp as admin_bp
    from app.routes.api import bp as api_bp
    from app.routes.main import bp as main_bp
    
    app.register_blueprint(auth_bp)
    app.register_blueprint(trainings_bp)
    app.register_blueprint(progress_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(api_bp)
    app.register_blueprint(main_bp)
    
    # Регистрация обработчиков ошибок
    register_error_handlers(app)
    
    # Контекстные процессоры
    @app.context_processor
    def inject_current_year():
        return {'current_year': datetime.now().year}
    
    @app.context_processor
    def inject_user_stats():
        if current_user.is_authenticated:
            from app.models import TrainingRegistration, Progress
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
    
    return app

def register_error_handlers(app):
    """Регистрация обработчиков ошибок"""
    @app.errorhandler(404)
    def not_found_error(error):
        return render_template('errors/404.html'), 404
    
    @app.errorhandler(500)
    def internal_error(error):
        db.session.rollback()
        return render_template('errors/500.html'), 500
    
    @app.errorhandler(403)
    def forbidden_error(error):
        return render_template('errors/403.html'), 403

# Создание экземпляра приложения
app = create_app()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
'@
New-Item -ItemType File -Path "app/__init__.py" -Value $appInitContent -Force | Out-Null
Write-Host "  Создан файл: app/__init__.py" -ForegroundColor DarkGreen

# 2. Модели данных
# app/models/__init__.py
$modelsInit = @'
# Инициализация моделей
from app.models.user import User, Trainer, Client, UserProfile
from app.models.training import Training, TrainingRegistration, TrainingCategory, TrainingSchedule
from app.models.progress import Progress, Goal, Achievement, ProgressMetric
from app.models.feedback import Feedback, Rating, Comment
from app.models.notification import Notification, NotificationTemplate
from app.models.system import AuditLog, SystemSetting, ContentModeration

__all__ = [
    'User', 'Trainer', 'Client', 'UserProfile',
    'Training', 'TrainingRegistration', 'TrainingCategory', 'TrainingSchedule',
    'Progress', 'Goal', 'Achievement', 'ProgressMetric',
    'Feedback', 'Rating', 'Comment',
    'Notification', 'NotificationTemplate',
    'AuditLog', 'SystemSetting', 'ContentModeration'
]
'@
New-Item -ItemType File -Path "app/models/__init__.py" -Value $modelsInit -Force | Out-Null

# app/models/user.py
$userModel = @'
"""
Модели пользователей системы
"""

from app import db
from flask_login import UserMixin
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash
import uuid

class User(UserMixin, db.Model):
    """Основная модель пользователя"""
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    public_id = db.Column(db.String(100), unique=True, default=lambda: str(uuid.uuid4()))
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='client')  # client, trainer, admin
    is_active = db.Column(db.Boolean, default=True)
    is_verified = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    last_activity = db.Column(db.DateTime)
    
    # Связи
    profile = db.relationship('UserProfile', backref='user', uselist=False, lazy=True)
    trainings_as_client = db.relationship('TrainingRegistration', backref='client_user', lazy='dynamic', 
                                        foreign_keys='TrainingRegistration.user_id')
    created_trainings = db.relationship('Training', backref='creator', lazy='dynamic',
                                       foreign_keys='Training.trainer_id')
    progress_entries = db.relationship('Progress', backref='user', lazy='dynamic')
    feedbacks = db.relationship('Feedback', backref='user', lazy='dynamic')
    notifications = db.relationship('Notification', backref='user', lazy='dynamic')
    goals = db.relationship('Goal', backref='user', lazy='dynamic')
    
    def set_password(self, password):
        """Хеширование пароля"""
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        """Проверка пароля"""
        return check_password_hash(self.password_hash, password)
    
    def update_last_activity(self):
        """Обновление времени последней активности"""
        self.last_activity = datetime.utcnow()
        db.session.commit()
    
    def get_role_display(self):
        """Отображаемое название роли"""
        roles = {
            'client': 'Клиент',
            'trainer': 'Тренер',
            'admin': 'Администратор'
        }
        return roles.get(self.role, self.role)
    
    def __repr__(self):
        return f'<User {self.username} ({self.role})>'

class UserProfile(db.Model):
    """Профиль пользователя с дополнительной информацией"""
    __tablename__ = 'user_profiles'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), unique=True, nullable=False)
    full_name = db.Column(db.String(100))
    date_of_birth = db.Column(db.Date)
    gender = db.Column(db.String(10))  # male, female, other
    phone = db.Column(db.String(20))
    address = db.Column(db.String(200))
    city = db.Column(db.String(50))
    country = db.Column(db.String(50))
    
    # Фитнес-данные
    height = db.Column(db.Float)  # см
    weight = db.Column(db.Float)  # кг
    fitness_level = db.Column(db.String(20))  # beginner, intermediate, advanced
    preferred_activities = db.Column(db.String(200))  # JSON список активностей
    
    # Медицинская информация
    medical_conditions = db.Column(db.Text)
    allergies = db.Column(db.Text)
    medications = db.Column(db.Text)
    emergency_contact = db.Column(db.String(200))
    
    # Настройки
    email_notifications = db.Column(db.Boolean, default=True)
    push_notifications = db.Column(db.Boolean, default=True)
    language = db.Column(db.String(10), default='ru')
    timezone = db.Column(db.String(50), default='Europe/Moscow')
    
    avatar_url = db.Column(db.String(500))
    bio = db.Column(db.Text)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def calculate_bmi(self):
        """Расчет индекса массы тела"""
        if self.height and self.weight:
            height_m = self.height / 100
            return round(self.weight / (height_m ** 2), 2)
        return None
    
    def get_age(self):
        """Возраст пользователя"""
        if self.date_of_birth:
            today = date.today()
            return today.year - self.date_of_birth.year - (
                (today.month, today.day) < (self.date_of_birth.month, self.date_of_birth.day)
            )
        return None
    
    def __repr__(self):
        return f'<UserProfile {self.user_id}>'

class Trainer(db.Model):
    """Модель тренера (расширение пользователя)"""
    __tablename__ = 'trainers'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), unique=True, nullable=False)
    certification = db.Column(db.String(200))
    specialization = db.Column(db.String(100))
    experience_years = db.Column(db.Integer, default=0)
    hourly_rate = db.Column(db.Float)
    is_available = db.Column(db.Boolean, default=True)
    
    # Рейтинги и статистика
    rating = db.Column(db.Float, default=0.0)
    total_ratings = db.Column(db.Integer, default=0)
    completed_sessions = db.Column(db.Integer, default=0)
    
    # Расписание
    work_schedule = db.Column(db.Text)  # JSON с расписанием
    
    # Социальные ссылки
    website = db.Column(db.String(200))
    instagram = db.Column(db.String(100))
    youtube = db.Column(db.String(100))
    
    # Дополнительная информация
    education = db.Column(db.Text)
    achievements = db.Column(db.Text)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Связи
    user = db.relationship('User', backref='trainer_info', lazy=True)
    trainings = db.relationship('Training', backref='trainer', lazy='dynamic')
    
    def update_rating(self, new_rating):
        """Обновление рейтинга тренера"""
        total_score = self.rating * self.total_ratings + new_rating
        self.total_ratings += 1
        self.rating = round(total_score / self.total_ratings, 2)
    
    def __repr__(self):
        return f'<Trainer {self.user_id}>'

class Client(db.Model):
    """Модель клиента (расширение пользователя)"""
    __tablename__ = 'clients'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), unique=True, nullable=False)
    
    # Цели клиента
    fitness_goals = db.Column(db.Text)  # JSON с целями
    target_weight = db.Column(db.Float)
    target_calories = db.Column(db.Integer)
    
    # Предпочтения
    preferred_trainers = db.relationship('Trainer', secondary='client_trainer_preferences', lazy='dynamic')
    preferred_training_types = db.Column(db.String(200))  # JSON список
    
    # Подписка и платежи
    subscription_type = db.Column(db.String(20))  # free, basic, premium
    subscription_end = db.Column(db.DateTime)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    user = db.relationship('User', backref='client_info', lazy=True)
    
    def is_subscription_active(self):
        """Проверка активной подписки"""
        if self.subscription_end:
            return self.subscription_end > datetime.utcnow()
        return False
    
    def __repr__(self):
        return f'<Client {self.user_id}>'

# Таблица многие-ко-многим для предпочтений клиентов
client_trainer_preferences = db.Table('client_trainer_preferences',
    db.Column('client_id', db.Integer, db.ForeignKey('clients.id'), primary_key=True),
    db.Column('trainer_id', db.Integer, db.ForeignKey('trainers.id'), primary_key=True),
    db.Column('preference_score', db.Float, default=1.0),
    db.Column('created_at', db.DateTime, default=datetime.utcnow)
)
'@
New-Item -ItemType File -Path "app/models/user.py" -Value $userModel -Force | Out-Null

# app/models/training.py
$trainingModel = @'
"""
Модели тренировок и расписаний
"""

from app import db
from datetime import datetime, time, timedelta
import json

class TrainingCategory(db.Model):
    """Категории тренировок"""
    __tablename__ = 'training_categories'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False, unique=True)
    description = db.Column(db.Text)
    icon = db.Column(db.String(50))
    color = db.Column(db.String(7))  # hex цвет
    is_active = db.Column(db.Boolean, default=True)
    order = db.Column(db.Integer, default=0)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    trainings = db.relationship('Training', backref='category', lazy='dynamic')
    
    def __repr__(self):
        return f'<TrainingCategory {self.name}>'

class Training(db.Model):
    """Модель тренировки"""
    __tablename__ = 'trainings'
    
    id = db.Column(db.Integer, primary_key=True)
    public_id = db.Column(db.String(50), unique=True, default=lambda: f"TR{datetime.now().strftime('%Y%m%d%H%M%S')}")
    title = db.Column(db.String(200), nullable=False, index=True)
    description = db.Column(db.Text)
    short_description = db.Column(db.String(500))
    
    # Основные данные
    trainer_id = db.Column(db.Integer, db.ForeignKey('trainers.id'), nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('training_categories.id'))
    
    # Расписание
    schedule_time = db.Column(db.DateTime, nullable=False, index=True)
    duration = db.Column(db.Integer, nullable=False)  # в минутах
    timezone = db.Column(db.String(50), default='Europe/Moscow')
    
    # Тип и сложность
    training_type = db.Column(db.String(20), nullable=False)  # group, individual, recorded
    difficulty = db.Column(db.String(20))  # beginner, intermediate, advanced
    intensity = db.Column(db.String(20))  # low, medium, high
    
    # Ограничения
    max_participants = db.Column(db.Integer, default=10)
    min_participants = db.Column(db.Integer, default=1)
    age_limit_min = db.Column(db.Integer)
    age_limit_max = db.Column(db.Integer)
    
    # Ссылки и медиа
    video_link = db.Column(db.String(500))
    meeting_link = db.Column(db.String(500))  # для онлайн-трансляций
    materials_link = db.Column(db.String(500))  # дополнительные материалы
    
    # Медицинские ограничения
    medical_contraindications = db.Column(db.Text)  # JSON список противопоказаний
    required_equipment = db.Column(db.Text)  # JSON список оборудования
    
    # Статус и модерация
    status = db.Column(db.String(20), default='draft')  # draft, pending, approved, active, cancelled, completed
    moderation_status = db.Column(db.String(20), default='pending')  # pending, approved, rejected
    moderation_notes = db.Column(db.Text)
    moderator_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    
    # Цена
    price = db.Column(db.Float, default=0.0)
    currency = db.Column(db.String(3), default='RUB')
    
    # Рейтинги и статистика
    average_rating = db.Column(db.Float, default=0.0)
    total_ratings = db.Column(db.Integer, default=0)
    views_count = db.Column(db.Integer, default=0)
    registrations_count = db.Column(db.Integer, default=0)
    attendance_rate = db.Column(db.Float, default=0.0)  # процент посещаемости
    
    # Метаданные
    tags = db.Column(db.String(500))  # JSON список тегов
    keywords = db.Column(db.String(500))
    language = db.Column(db.String(10), default='ru')
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    published_at = db.Column(db.DateTime)
    
    # Связи
    registrations = db.relationship('TrainingRegistration', backref='training', lazy='dynamic', cascade='all, delete-orphan')
    feedbacks = db.relationship('Feedback', backref='training', lazy='dynamic')
    schedules = db.relationship('TrainingSchedule', backref='training', lazy='dynamic')
    
    # Свойства
    @property
    def is_upcoming(self):
        """Тренировка еще не началась"""
        return self.schedule_time > datetime.utcnow()
    
    @property
    def is_ongoing(self):
        """Тренировка идет прямо сейчас"""
        end_time = self.schedule_time + timedelta(minutes=self.duration)
        return self.schedule_time <= datetime.utcnow() <= end_time
    
    @property
    def is_past(self):
        """Тренировка уже прошла"""
        end_time = self.schedule_time + timedelta(minutes=self.duration)
        return end_time < datetime.utcnow()
    
    @property
    def available_spots(self):
        """Количество свободных мест"""
        registered = self.registrations.filter_by(status='registered').count()
        return max(0, self.max_participants - registered)
    
    @property
    def is_full(self):
        """Все места заняты"""
        return self.available_spots <= 0
    
    @property
    def end_time(self):
        """Время окончания тренировки"""
        return self.schedule_time + timedelta(minutes=self.duration)
    
    def check_time_conflict(self, user_id):
        """Проверка накладки времени с другими тренировками пользователя"""
        from app.models import TrainingRegistration
        
        user_registrations = TrainingRegistration.query.filter_by(
            user_id=user_id,
            status='registered'
        ).join(Training).filter(
            Training.status.in_(['active', 'approved'])
        ).all()
        
        for registration in user_registrations:
            other_training = registration.training
            if (self.schedule_time < other_training.end_time and 
                self.end_time > other_training.schedule_time):
                return other_training
        
        return None
    
    def check_medical_contraindications(self, user):
        """Проверка медицинских противопоказаний"""
        if not self.medical_contraindications:
            return False
        
        try:
            contraindications = json.loads(self.medical_contraindications)
            user_conditions = user.profile.medical_conditions.lower() if user.profile and user.profile.medical_conditions else ''
            
            for condition in contraindications:
                if condition.lower() in user_conditions:
                    return True
        except:
            pass
        
        return False
    
    def increment_views(self):
        """Увеличение счетчика просмотров"""
        self.views_count += 1
        db.session.commit()
    
    def update_rating(self, new_rating):
        """Обновление среднего рейтинга"""
        total_score = self.average_rating * self.total_ratings + new_rating
        self.total_ratings += 1
        self.average_rating = round(total_score / self.total_ratings, 2)
        db.session.commit()
    
    def __repr__(self):
        return f'<Training {self.title} ({self.schedule_time})>'

class TrainingRegistration(db.Model):
    """Регистрация пользователя на тренировку"""
    __tablename__ = 'training_registrations'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    training_id = db.Column(db.Integer, db.ForeignKey('trainings.id'), nullable=False, index=True)
    
    # Статус участия
    status = db.Column(db.String(20), default='registered')  # registered, attended, cancelled, no_show
    registration_type = db.Column(db.String(20), default='standard')  # standard, waitlist, trial
    
    # Платеж
    payment_status = db.Column(db.String(20), default='pending')  # pending, paid, refunded
    payment_amount = db.Column(db.Float)
    payment_id = db.Column(db.String(100))
    
    # Время
    registered_at = db.Column(db.DateTime, default=datetime.utcnow)
    cancelled_at = db.Column(db.DateTime)
    attended_at = db.Column(db.DateTime)
    
    # Примечания
    notes = db.Column(db.Text)
    cancellation_reason = db.Column(db.String(200))
    
    # Уникальный constraint
    __table_args__ = (
        db.UniqueConstraint('user_id', 'training_id', name='unique_user_training_registration'),
    )
    
    def cancel(self, reason=None):
        """Отмена регистрации"""
        self.status = 'cancelled'
        self.cancelled_at = datetime.utcnow()
        self.cancellation_reason = reason
        db.session.commit()
    
    def mark_attended(self):
        """Отметка посещения"""
        self.status = 'attended'
        self.attended_at = datetime.utcnow()
        db.session.commit()
    
    def is_attendance_possible(self):
        """Возможно ли еще отметить посещение"""
        training_end = self.training.end_time
        grace_period = training_end + timedelta(hours=24)  # 24 часа на отметку
        return datetime.utcnow() <= grace_period
    
    @property
    def can_be_cancelled(self):
        """Можно ли отменить регистрацию"""
        # Можно отменить не позднее чем за 1 час до начала
        cancellation_deadline = self.training.schedule_time - timedelta(hours=1)
        return datetime.utcnow() < cancellation_deadline
    
    def __repr__(self):
        return f'<TrainingRegistration User:{self.user_id} Training:{self.training_id}>'

class TrainingSchedule(db.Model):
    """Расписание повторяющихся тренировок"""
    __tablename__ = 'training_schedules'
    
    id = db.Column(db.Integer, primary_key=True)
    training_id = db.Column(db.Integer, db.ForeignKey('trainings.id'), nullable=False)
    
    # Паттерн повторения
    recurrence_pattern = db.Column(db.String(20))  # daily, weekly, monthly, custom
    recurrence_days = db.Column(db.String(50))  # JSON список дней недели [1,3,5] = Пн, Ср, Пт
    recurrence_interval = db.Column(db.Integer, default=1)  # каждые N дней/недель/месяцев
    
    # Время
    start_time = db.Column(db.Time, nullable=False)
    end_time = db.Column(db.Time, nullable=False)
    
    # Период действия
    start_date = db.Column(db.Date, nullable=False)
    end_date = db.Column(db.Date)
    max_occurrences = db.Column(db.Integer)  # максимальное количество повторений
    
    # Исключения
    exceptions = db.Column(db.Text)  # JSON список дат исключений
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def generate_occurrences(self, from_date=None, to_date=None):
        """Генерация дат тренировок по расписанию"""
        from datetime import datetime, date, timedelta
        
        occurrences = []
        current_date = from_date or self.start_date
        end_date = to_date or self.end_date or (date.today() + timedelta(days=365))
        
        if self.recurrence_pattern == 'daily':
            delta = timedelta(days=self.recurrence_interval)
            while current_date <= end_date:
                occurrences.append(current_date)
                current_date += delta
        
        elif self.recurrence_pattern == 'weekly':
            days_of_week = json.loads(self.recurrence_days) if self.recurrence_days else []
            current_date = self.find_next_weekday(current_date, days_of_week[0] if days_of_week else current_date.weekday())
            
            while current_date <= end_date:
                for day in days_of_week:
                    occurrence = self.find_next_weekday(current_date, day)
                    if occurrence <= end_date:
                        occurrences.append(occurrence)
                current_date += timedelta(weeks=self.recurrence_interval)
        
        elif self.recurrence_pattern == 'monthly':
            while current_date <= end_date:
                occurrences.append(current_date)
                # Добавить месяц
                month = current_date.month + self.recurrence_interval
                year = current_date.year + (month - 1) // 12
                month = (month - 1) % 12 + 1
                day = min(current_date.day, [31,29 if year%4==0 and (year%100!=0 or year%400==0) else 28,31,30,31,30,31,31,30,31,30,31][month-1])
                current_date = date(year, month, day)
        
        return sorted(set(occurrences))
    
    @staticmethod
    def find_next_weekday(start_date, target_weekday):
        """Найти следующую дату с заданным днем недели"""
        days_ahead = target_weekday - start_date.weekday()
        if days_ahead < 0:
            days_ahead += 7
        return start_date + timedelta(days=days_ahead)
    
    def __repr__(self):
        return f'<TrainingSchedule Training:{self.training_id}>'
'@
New-Item -ItemType File -Path "app/models/training.py" -Value $trainingModel -Force | Out-Null

# app/models/progress.py
$progressModel = @'
"""
Модели для отслеживания прогресса пользователей
"""

from app import db
from datetime import datetime, date
import json

class Progress(db.Model):
    """Запись о прогрессе пользователя"""
    __tablename__ = 'progress'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    training_id = db.Column(db.Integer, db.ForeignKey('trainings.id'), index=True)
    
    # Основные метрики
    date = db.Column(db.Date, nullable=False, default=date.today, index=True)
    entry_type = db.Column(db.String(20), default='manual')  # manual, auto, import
    
    # Активность
    activity_type = db.Column(db.String(50))  # running, cycling, strength, yoga, etc.
    duration = db.Column(db.Integer)  # в минутах
    calories_burned = db.Column(db.Float)
    distance = db.Column(db.Float)  # в км
    
    # Показатели здоровья
    weight = db.Column(db.Float)  # кг
    body_fat_percentage = db.Column(db.Float)
    muscle_mass = db.Column(db.Float)
    resting_heart_rate = db.Column(db.Integer)
    blood_pressure_systolic = db.Column(db.Integer)
    blood_pressure_diastolic = db.Column(db.Integer)
    sleep_duration = db.Column(db.Integer)  # в минутах
    sleep_quality = db.Column(db.Integer)  # 1-10
    
    # Настроение и самочувствие
    energy_level = db.Column(db.Integer)  # 1-10
    mood = db.Column(db.Integer)  # 1-10
    stress_level = db.Column(db.Integer)  # 1-10
    
    # Дополнительные данные
    notes = db.Column(db.Text)
    location = db.Column(db.String(100))
    weather = db.Column(db.String(50))
    
    # Метаданные
    source = db.Column(db.String(50))  # app, wearable, manual
    device_id = db.Column(db.String(100))
    is_verified = db.Column(db.Boolean, default=False)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Связи
    metrics = db.relationship('ProgressMetric', backref='progress', lazy='dynamic', cascade='all, delete-orphan')
    
    def to_dict(self):
        """Преобразование в словарь"""
        return {
            'id': self.id,
            'date': self.date.isoformat(),
            'activity_type': self.activity_type,
            'duration': self.duration,
            'calories_burned': self.calories_burned,
            'distance': self.distance,
            'weight': self.weight,
            'notes': self.notes
        }
    
    @property
    def pace(self):
        """Темп (мин/км)"""
        if self.duration and self.distance:
            return round(self.duration / self.distance, 2) if self.distance > 0 else None
        return None
    
    @property
    def calories_per_minute(self):
        """Калории в минуту"""
        if self.calories_burned and self.duration:
            return round(self.calories_burned / self.duration, 2) if self.duration > 0 else None
        return None
    
    def __repr__(self):
        return f'<Progress User:{self.user_id} Date:{self.date}>'

class ProgressMetric(db.Model):
    """Детальные метрики прогресса"""
    __tablename__ = 'progress_metrics'
    
    id = db.Column(db.Integer, primary_key=True)
    progress_id = db.Column(db.Integer, db.ForeignKey('progress.id'), nullable=False)
    metric_type = db.Column(db.String(50), nullable=False)  # heart_rate, speed, elevation, etc.
    value = db.Column(db.Float, nullable=False)
    unit = db.Column(db.String(20))
    timestamp = db.Column(db.DateTime)  # время в течение активности
    interval = db.Column(db.Integer)  # интервал в секундах
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        db.Index('idx_progress_metric', 'progress_id', 'metric_type', 'timestamp'),
    )
    
    def __repr__(self):
        return f'<ProgressMetric {self.metric_type}:{self.value}>'

class Goal(db.Model):
    """Цели пользователя"""
    __tablename__ = 'goals'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    
    # Основные данные цели
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text)
    goal_type = db.Column(db.String(50), nullable=False)  # weight_loss, muscle_gain, endurance, etc.
    
    # Целевые значения
    target_value = db.Column(db.Float, nullable=False)
    current_value = db.Column(db.Float, default=0.0)
    unit = db.Column(db.String(20))
    
    # Временные рамки
    start_date = db.Column(db.Date, default=date.today)
    target_date = db.Column(db.Date)
    is_recurring = db.Column(db.Boolean, default=False)
    recurrence_pattern = db.Column(db.String(20))  # weekly, monthly
    
    # Прогресс
    progress_percentage = db.Column(db.Float, default=0.0)
    status = db.Column(db.String(20), default='active')  # active, completed, failed, cancelled
    
    # Мотивация
    motivation = db.Column(db.Text)
    rewards = db.Column(db.Text)  # JSON список наград
    
    # Напоминания
    reminder_enabled = db.Column(db.Boolean, default=False)
    reminder_frequency = db.Column(db.String(20))  # daily, weekly
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    completed_at = db.Column(db.DateTime)
    
    # Связи
    achievements = db.relationship('Achievement', backref='goal', lazy='dynamic')
    
    def update_progress(self, new_value=None):
        """Обновление прогресса"""
        if new_value is not None:
            self.current_value = new_value
        
        if self.target_value != 0:
            self.progress_percentage = min(100.0, (self.current_value / self.target_value) * 100)
        
        if self.progress_percentage >= 100:
            self.status = 'completed'
            self.completed_at = datetime.utcnow()
        
        db.session.commit()
    
    def is_on_track(self):
        """Проверка, идет ли прогресс по плану"""
        if not self.target_date or self.progress_percentage == 0:
            return True
        
        total_days = (self.target_date - self.start_date).days
        elapsed_days = (date.today() - self.start_date).days
        
        if elapsed_days <= 0 or total_days <= 0:
            return True
        
        expected_progress = (elapsed_days / total_days) * 100
        return self.progress_percentage >= expected_progress * 0.8  # 80% от ожидаемого
    
    @property
    def time_remaining(self):
        """Оставшееся время до дедлайна"""
        if self.target_date:
            remaining = (self.target_date - date.today()).days
            return max(0, remaining)
        return None
    
    def __repr__(self):
        return f'<Goal {self.title} ({self.progress_percentage}%)>'

class Achievement(db.Model):
    """Достижения пользователей"""
    __tablename__ = 'achievements'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    goal_id = db.Column(db.Integer, db.ForeignKey('goals.id'))
    
    # Данные достижения
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text)
    achievement_type = db.Column(db.String(50))  # milestone, completion, streak, special
    
    # Критерии
    criteria = db.Column(db.Text)  # JSON с критериями
    points = db.Column(db.Integer, default=0)
    
    # Изображение/иконка
    icon = db.Column(db.String(100))
    badge_image = db.Column(db.String(500))
    
    # Время
    achieved_at = db.Column(db.DateTime, default=datetime.utcnow)
    unlocked_at = db.Column(db.DateTime)
    
    # Социальные функции
    shareable = db.Column(db.Boolean, default=True)
    shared_at = db.Column(db.DateTime)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def unlock(self):
        """Разблокировка достижения"""
        self.unlocked_at = datetime.utcnow()
        db.session.commit()
    
    def to_dict(self):
        """Преобразование в словарь"""
        return {
            'id': self.id,
            'title': self.title,
            'description': self.description,
            'type': self.achievement_type,
            'points': self.points,
            'icon': self.icon,
            'achieved_at': self.achieved_at.isoformat() if self.achieved_at else None,
            'unlocked_at': self.unlocked_at.isoformat() if self.unlocked_at else None
        }
    
    def __repr__(self):
        return f'<Achievement {self.title}>'
'@
New-Item -ItemType File -Path "app/models/progress.py" -Value $progressModel -Force | Out-Null

# app/models/feedback.py
$feedbackModel = @'
"""
Модели для системы отзывов и рейтингов
"""

from app import db
from datetime import datetime
import json

class Feedback(db.Model):
    """Отзывы о тренировках"""
    __tablename__ = 'feedbacks'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    training_id = db.Column(db.Integer, db.ForeignKey('trainings.id'), nullable=False)
    
    # Основные данные
    title = db.Column(db.String(200))
    comment = db.Column(db.Text)
    is_anonymous = db.Column(db.Boolean, default=False)
    
    # Модерация
    moderation_status = db.Column(db.String(20), default='pending')  # pending, approved, rejected
    moderated_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    moderation_notes = db.Column(db.Text)
    moderated_at = db.Column(db.DateTime)
    
    # Взаимодействия
    likes_count = db.Column(db.Integer, default=0)
    reports_count = db.Column(db.Integer, default=0)
    is_edited = db.Column(db.Boolean, default=False)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Связи
    ratings = db.relationship('Rating', backref='feedback', lazy='dynamic', cascade='all, delete-orphan')
    comments = db.relationship('Comment', backref='feedback', lazy='dynamic', cascade='all, delete-orphan')
    
    # Уникальный constraint
    __table_args__ = (
        db.UniqueConstraint('user_id', 'training_id', name='unique_user_training_feedback'),
    )
    
    def approve(self, moderator_id, notes=None):
        """Одобрение отзыва модератором"""
        self.moderation_status = 'approved'
        self.moderated_by = moderator_id
        self.moderation_notes = notes
        self.moderated_at = datetime.utcnow()
        db.session.commit()
    
    def reject(self, moderator_id, notes):
        """Отклонение отзыва модератором"""
        self.moderation_status = 'rejected'
        self.moderated_by = moderator_id
        self.moderation_notes = notes
        self.moderated_at = datetime.utcnow()
        db.session.commit()
    
    def add_like(self):
        """Добавление лайка"""
        self.likes_count += 1
        db.session.commit()
    
    def remove_like(self):
        """Удаление лайка"""
        self.likes_count = max(0, self.likes_count - 1)
        db.session.commit()
    
    def report(self):
        """Жалоба на отзыв"""
        self.reports_count += 1
        db.session.commit()
    
    @property
    def is_visible(self):
        """Виден ли отзыв другим пользователям"""
        return self.moderation_status == 'approved'
    
    def __repr__(self):
        return f'<Feedback User:{self.user_id} Training:{self.training_id}>'

class Rating(db.Model):
    """Рейтинги тренировок по различным критериям"""
    __tablename__ = 'ratings'
    
    id = db.Column(db.Integer, primary_key=True)
    feedback_id = db.Column(db.Integer, db.ForeignKey('feedbacks.id'), nullable=False)
    rating_type = db.Column(db.String(50), nullable=False)  # overall, trainer, content, difficulty, etc.
    score = db.Column(db.Float, nullable=False)  # 1-5 или 1-10
    max_score = db.Column(db.Float, default=5.0)
    
    comment = db.Column(db.String(500))  # комментарий к конкретному рейтингу
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def normalized_score(self):
        """Нормализованный балл (0-1)"""
        return self.score / self.max_score
    
    def __repr__(self):
        return f'<Rating {self.rating_type}:{self.score}/{self.max_score}>'

class Comment(db.Model):
    """Комментарии к отзывам"""
    __tablename__ = 'feedback_comments'
    
    id = db.Column(db.Integer, primary_key=True)
    feedback_id = db.Column(db.Integer, db.ForeignKey('feedbacks.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    parent_id = db.Column(db.Integer, db.ForeignKey('feedback_comments.id'))  # для ответов
    
    content = db.Column(db.Text, nullable=False)
    is_edited = db.Column(db.Boolean, default=False)
    
    # Модерация
    moderation_status = db.Column(db.String(20), default='pending')
    moderated_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    
    # Взаимодействия
    likes_count = db.Column(db.Integer, default=0)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    deleted_at = db.Column(db.DateTime)
    
    # Связи
    user = db.relationship('User', backref='feedback_comments', lazy=True)
    replies = db.relationship('Comment', backref=db.backref('parent', remote_side=[id]), lazy='dynamic')
    
    @property
    def is_deleted(self):
        """Удален ли комментарий"""
        return self.deleted_at is not None
    
    def soft_delete(self):
        """Мягкое удаление комментария"""
        self.deleted_at = datetime.utcnow()
        self.content = '[Комментарий удален]'
        db.session.commit()
    
    def add_like(self):
        """Добавление лайка"""
        self.likes_count += 1
        db.session.commit()
    
    def __repr__(self):
        return f'<Comment User:{self.user_id} on Feedback:{self.feedback_id}>'
'@
New-Item -ItemType File -Path "app/models/feedback.py" -Value $feedbackModel -Force | Out-Null

# app/models/notification.py
$notificationModel = @'
"""
Модели для системы уведомлений
"""

from app import db
from datetime import datetime
import json

class Notification(db.Model):
    """Уведомления пользователей"""
    __tablename__ = 'notifications'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    
    # Основные данные
    title = db.Column(db.String(200), nullable=False)
    message = db.Column(db.Text, nullable=False)
    notification_type = db.Column(db.String(50), nullable=False, index=True)  # training, system, reminder, achievement, etc.
    
    # Ссылка и данные
    action_url = db.Column(db.String(500))
    action_text = db.Column(db.String(100))
    data = db.Column(db.Text)  # JSON с дополнительными данными
    
    # Статус
    is_read = db.Column(db.Boolean, default=False, index=True)
    is_important = db.Column(db.Boolean, default=False)
    priority = db.Column(db.Integer, default=0)  # 0-10, где 10 - наивысший
    
    # Каналы доставки
    send_email = db.Column(db.Boolean, default=False)
    send_push = db.Column(db.Boolean, default=False)
    send_in_app = db.Column(db.Boolean, default=True)
    
    # Время
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    scheduled_for = db.Column(db.DateTime, index=True)
    sent_at = db.Column(db.DateTime)
    read_at = db.Column(db.DateTime)
    expires_at = db.Column(db.DateTime)
    
    # Отслеживание
    email_sent = db.Column(db.Boolean, default=False)
    push_sent = db.Column(db.Boolean, default=False)
    delivery_attempts = db.Column(db.Integer, default=0)
    
    # Связи
    template_id = db.Column(db.Integer, db.ForeignKey('notification_templates.id'))
    
    def mark_as_read(self):
        """Отметка уведомления как прочитанного"""
        if not self.is_read:
            self.is_read = True
            self.read_at = datetime.utcnow()
            db.session.commit()
    
    def mark_as_sent(self, channel):
        """Отметка отправки по каналу"""
        if channel == 'email':
            self.email_sent = True
        elif channel == 'push':
            self.push_sent = True
        self.sent_at = datetime.utcnow()
        db.session.commit()
    
    def get_data_dict(self):
        """Получение данных в виде словаря"""
        if self.data:
            try:
                return json.loads(self.data)
            except:
                return {}
        return {}
    
    def set_data_dict(self, data_dict):
        """Установка данных из словаря"""
        self.data = json.dumps(data_dict, ensure_ascii=False)
    
    @property
    def is_expired(self):
        """Истекло ли уведомление"""
        if self.expires_at:
            return datetime.utcnow() > self.expires_at
        return False
    
    @property
    def is_scheduled(self):
        """Запланировано ли уведомление на будущее"""
        if self.scheduled_for:
            return self.scheduled_for > datetime.utcnow()
        return False
    
    def __repr__(self):
        return f'<Notification {self.notification_type} for User:{self.user_id}>'

class NotificationTemplate(db.Model):
    """Шаблоны уведомлений"""
    __tablename__ = 'notification_templates'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False, unique=True)
    description = db.Column(db.Text)
    
    # Шаблоны
    title_template = db.Column(db.Text, nullable=False)
    message_template = db.Column(db.Text, nullable=False)
    email_subject_template = db.Column(db.Text)
    email_body_template = db.Column(db.Text)
    push_title_template = db.Column(db.Text)
    push_body_template = db.Column(db.Text)
    
    # Настройки
    notification_type = db.Column(db.String(50))
    default_priority = db.Column(db.Integer, default=0)
    default_channels = db.Column(db.String(100))  # JSON список каналов
    
    # Переменные
    variables = db.Column(db.Text)  # JSON описание переменных шаблона
    example_data = db.Column(db.Text)  # JSON пример данных
    
    # Активность
    is_active = db.Column(db.Boolean, default=True)
    version = db.Column(db.String(20), default='1.0')
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Связи
    notifications = db.relationship('Notification', backref='template', lazy='dynamic')
    
    def render(self, context):
        """Рендеринг шаблона с контекстом"""
        from string import Template
        
        try:
            title = Template(self.title_template).safe_substitute(context)
            message = Template(self.message_template).safe_substitute(context)
            return title, message
        except Exception as e:
            return f"Ошибка рендеринга: {str(e)}", ""
    
    def get_variables_list(self):
        """Получение списка переменных"""
        if self.variables:
            try:
                return json.loads(self.variables)
            except:
                return []
        return []
    
    def __repr__(self):
        return f'<NotificationTemplate {self.name}>'
'@
New-Item -ItemType File -Path "app/models/notification.py" -Value $notificationModel -Force | Out-Null

# app/models/system.py
$systemModel = @'
"""
Системные модели для администрирования
"""

from app import db
from datetime import datetime
import json

class AuditLog(db.Model):
    """Логи аудита действий в системе"""
    __tablename__ = 'audit_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # Кто совершил действие
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    user_ip = db.Column(db.String(45))
    user_agent = db.Column(db.Text)
    
    # Что произошло
    action = db.Column(db.String(100), nullable=False, index=True)
    resource_type = db.Column(db.String(50), nullable=False, index=True)
    resource_id = db.Column(db.String(100), index=True)
    
    # Детали
    details_before = db.Column(db.Text)  # JSON состояние до
    details_after = db.Column(db.Text)   # JSON состояние после
    changes = db.Column(db.Text)         # JSON изменения
    
    # Контекст
    request_path = db.Column(db.String(500))
    request_method = db.Column(db.String(10))
    status_code = db.Column(db.Integer)
    
    # Время
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    duration_ms = db.Column(db.Integer)  # длительность в миллисекундах
    
    def log_action(user_id, action, resource_type, resource_id=None, 
                  details_before=None, details_after=None, request=None):
        """Создание записи в логе аудита"""
        log = AuditLog(
            user_id=user_id,
            action=action,
            resource_type=resource_type,
            resource_id=str(resource_id) if resource_id else None,
            details_before=json.dumps(details_before, ensure_ascii=False) if details_before else None,
            details_after=json.dumps(details_after, ensure_ascii=False) if details_after else None
        )
        
        if request:
            log.user_ip = request.remote_addr
            log.user_agent = request.user_agent.string
            log.request_path = request.path
            log.request_method = request.method
        
        # Вычисление изменений
        if details_before and details_after:
            changes = {}
            for key in set(details_before.keys()) | set(details_after.keys()):
                if details_before.get(key) != details_after.get(key):
                    changes[key] = {
                        'before': details_before.get(key),
                        'after': details_after.get(key)
                    }
            log.changes = json.dumps(changes, ensure_ascii=False)
        
        db.session.add(log)
        db.session.commit()
        
        return log
    
    def __repr__(self):
        return f'<AuditLog {self.action} by User:{self.user_id}>'

class SystemSetting(db.Model):
    """Системные настройки"""
    __tablename__ = 'system_settings'
    
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(100), nullable=False, unique=True, index=True)
    value = db.Column(db.Text)
    value_type = db.Column(db.String(20), default='string')  # string, integer, float, boolean, json, list
    category = db.Column(db.String(50), index=True)
    description = db.Column(db.Text)
    
    # Ограничения
    is_public = db.Column(db.Boolean, default=False)
    is_editable = db.Column(db.Boolean, default=True)
    is_encrypted = db.Column(db.Boolean, default=False)
    
    # Валидация
    validation_regex = db.Column(db.String(200))
    min_value = db.Column(db.String(50))
    max_value = db.Column(db.String(50))
    allowed_values = db.Column(db.Text)  # JSON список разрешенных значений
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    updated_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    
    def get_value(self):
        """Получение значения с правильным типом"""
        if self.value is None:
            return None
        
        try:
            if self.value_type == 'integer':
                return int(self.value)
            elif self.value_type == 'float':
                return float(self.value)
            elif self.value_type == 'boolean':
                return self.value.lower() in ('true', '1', 'yes', 'y')
            elif self.value_type == 'json':
                return json.loads(self.value)
            elif self.value_type == 'list':
                return [item.strip() for item in self.value.split(',')]
            else:  # string
                return self.value
        except (ValueError, json.JSONDecodeError):
            return self.value
    
    def set_value(self, new_value):
        """Установка значения с преобразованием типа"""
        if new_value is None:
            self.value = None
        elif self.value_type == 'json':
            self.value = json.dumps(new_value, ensure_ascii=False)
        elif self.value_type == 'list' and isinstance(new_value, list):
            self.value = ','.join(str(item) for item in new_value)
        elif self.value_type == 'boolean':
            self.value = 'true' if new_value else 'false'
        else:
            self.value = str(new_value)
    
    @classmethod
    def get_setting(cls, key, default=None):
        """Получение значения настройки"""
        setting = cls.query.filter_by(key=key).first()
        if setting:
            return setting.get_value()
        return default
    
    @classmethod
    def set_setting(cls, key, value, value_type='string', category='general'):
        """Установка значения настройки"""
        setting = cls.query.filter_by(key=key).first()
        if not setting:
            setting = cls(key=key, value_type=value_type, category=category)
        
        setting.set_value(value)
        db.session.add(setting)
        db.session.commit()
        
        return setting
    
    def __repr__(self):
        return f'<SystemSetting {self.key}>'

class ContentModeration(db.Model):
    """Модерация контента"""
    __tablename__ = 'content_moderation'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # Что модерируется
    content_type = db.Column(db.String(50), nullable=False, index=True)  # training, feedback, comment, user
    content_id = db.Column(db.Integer, nullable=False, index=True)
    
    # Кто и когда
    reported_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    reported_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Причина
    reason = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    
    # Статус
    status = db.Column(db.String(20), default='pending', index=True)  # pending, reviewing, approved, rejected, removed
    moderated_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    moderated_at = db.Column(db.DateTime)
    moderation_notes = db.Column(db.Text)
    
    # Действия
    actions_taken = db.Column(db.Text)  # JSON список предпринятых действий
    penalty_points = db.Column(db.Integer, default=0)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def approve(self, moderator_id, notes=None):
        """Одобрение контента"""
        self.status = 'approved'
        self.moderated_by = moderator_id
        self.moderation_notes = notes
        self.moderated_at = datetime.utcnow()
        db.session.commit()
    
    def reject(self, moderator_id, notes, actions=None, penalty=0):
        """Отклонение контента"""
        self.status = 'rejected'
        self.moderated_by = moderator_id
        self.moderation_notes = notes
        self.moderated_at = datetime.utcnow()
        self.penalty_points = penalty
        
        if actions:
            self.actions_taken = json.dumps(actions, ensure_ascii=False)
        
        db.session.commit()
    
    def remove(self, moderator_id, notes, actions=None, penalty=0):
        """Удаление контента"""
        self.status = 'removed'
        self.moderated_by = moderator_id
        self.moderation_notes = notes
        self.moderated_at = datetime.utcnow()
        self.penalty_points = penalty
        
        if actions:
            self.actions_taken = json.dumps(actions, ensure_ascii=False)
        
        db.session.commit()
    
    def __repr__(self):
        return f'<ContentModeration {self.content_type}:{self.content_id}>'
'@
New-Item -ItemType File -Path "app/models/system.py" -Value $systemModel -Force | Out-Null

Write-Host "  Созданы все модели данных" -ForegroundColor DarkGreen

# 3. Формы
# app/forms/__init__.py
$formsInit = @'
# Инициализация форм
from app.forms.auth import *
from app.forms.training import *
from app.forms.progress import *
from app.forms.feedback import *
from app.forms.admin import *
'@
New-Item -ItemType File -Path "app/forms/__init__.py" -Value $formsInit -Force | Out-Null

# app/forms/auth.py
$authForms = @'
"""
Формы для аутентификации и регистрации
"""

from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, TextAreaField, SelectField, DateTimeField, IntegerField, FloatField, BooleanField, DateField
from wtforms.validators import DataRequired, Email, Length, EqualTo, ValidationError, Optional, NumberRange
from app.models import User
from datetime import datetime, date

class LoginForm(FlaskForm):
    """Форма входа в систему"""
    email = StringField('Email', validators=[DataRequired(message='Введите email'), Email(message='Введите корректный email')])
    password = PasswordField('Пароль', validators=[DataRequired(message='Введите пароль')])
    remember = BooleanField('Запомнить меня')
    
    def validate_email(self, field):
        """Проверка существования пользователя"""
        user = User.query.filter_by(email=field.data).first()
        if not user:
            raise ValidationError('Пользователь с таким email не найден')
        if not user.is_active:
            raise ValidationError('Аккаунт деактивирован. Обратитесь к администратору.')

class RegistrationForm(FlaskForm):
    """Форма регистрации пользователя"""
    # Основные данные
    email = StringField('Email', validators=[
        DataRequired(message='Введите email'),
        Email(message='Введите корректный email'),
        Length(max=120, message='Email слишком длинный')
    ])
    username = StringField('Имя пользователя', validators=[
        DataRequired(message='Введите имя пользователя'),
        Length(min=3, max=80, message='Имя пользователя должно быть от 3 до 80 символов')
    ])
    password = PasswordField('Пароль', validators=[
        DataRequired(message='Введите пароль'),
        Length(min=8, message='Пароль должен содержать минимум 8 символов'),
        EqualTo('confirm_password', message='Пароли не совпадают')
    ])
    confirm_password = PasswordField('Подтвердите пароль', validators=[DataRequired(message='Подтвердите пароль')])
    
    # Роль
    role = SelectField('Роль', choices=[
        ('client', 'Клиент'),
        ('trainer', 'Тренер'),
        ('admin', 'Администратор')
    ], validators=[DataRequired(message='Выберите роль')])
    
    # Личная информация
    full_name = StringField('Полное имя', validators=[
        DataRequired(message='Введите полное имя'),
        Length(max=100, message='Имя слишком длинное')
    ])
    date_of_birth = DateField('Дата рождения', format='%Y-%m-%d', validators=[Optional()])
    gender = SelectField('Пол', choices=[
        ('', 'Не указано'),
        ('male', 'Мужской'),
        ('female', 'Женский'),
        ('other', 'Другой')
    ], validators=[Optional()])
    phone = StringField('Телефон', validators=[Optional(), Length(max=20)])
    
    # Фитнес-данные (для клиентов)
    height = FloatField('Рост (см)', validators=[
        Optional(),
        NumberRange(min=50, max=250, message='Рост должен быть от 50 до 250 см')
    ])
    weight = FloatField('Вес (кг)', validators=[
        Optional(),
        NumberRange(min=20, max=300, message='Вес должен быть от 20 до 300 кг')
    ])
    fitness_level = SelectField('Уровень подготовки', choices=[
        ('', 'Не указано'),
        ('beginner', 'Начинающий'),
        ('intermediate', 'Средний'),
        ('advanced', 'Продвинутый')
    ], validators=[Optional()])
    
    # Медицинская информация
    medical_conditions = TextAreaField('Медицинские противопоказания', validators=[Optional(), Length(max=1000)])
    allergies = TextAreaField('Аллергии', validators=[Optional(), Length(max=500)])
    
    # Дополнительно для тренеров
    specialization = StringField('Специализация', validators=[Optional(), Length(max=100)])
    experience_years = IntegerField('Опыт работы (лет)', validators=[Optional(), NumberRange(min=0, max=100)])
    certification = StringField('Сертификация', validators=[Optional(), Length(max=200)])
    bio = TextAreaField('Биография', validators=[Optional(), Length(max=2000)])
    
    # Соглашения
    terms_accepted = BooleanField('Я принимаю условия использования', validators=[DataRequired(message='Необходимо принять условия использования')])
    privacy_accepted = BooleanField('Я согласен на обработку персональных данных', validators=[DataRequired(message='Необходимо согласиться на обработку данных')])
    
    def validate_email(self, field):
        """Проверка уникальности email"""
        user = User.query.filter_by(email=field.data).first()
        if user:
            raise ValidationError('Пользователь с таким email уже зарегистрирован')
    
    def validate_username(self, field):
        """Проверка уникальности имени пользователя"""
        user = User.query.filter_by(username=field.data).first()
        if user:
            raise ValidationError('Имя пользователя уже занято')
    
    def validate_date_of_birth(self, field):
        """Проверка даты рождения"""
        if field.data:
            if field.data > date.today():
                raise ValidationError('Дата рождения не может быть в будущем')
            
            age = (date.today() - field.data).days // 365
            if age < 14:
                raise ValidationError('Для регистрации необходимо быть старше 14 лет')
            if age > 120:
                raise ValidationError('Проверьте правильность даты рождения')

class ProfileForm(FlaskForm):
    """Форма редактирования профиля"""
    full_name = StringField('Полное имя', validators=[
        DataRequired(message='Введите полное имя'),
        Length(max=100, message='Имя слишком длинное')
    ])
    date_of_birth = DateField('Дата рождения', format='%Y-%m-%d', validators=[Optional()])
    gender = SelectField('Пол', choices=[
        ('', 'Не указано'),
        ('male', 'Мужской'),
        ('female', 'Женский'),
        ('other', 'Другой')
    ], validators=[Optional()])
    phone = StringField('Телефон', validators=[Optional(), Length(max=20)])
    
    # Фитнес-данные
    height = FloatField('Рост (см)', validators=[
        Optional(),
        NumberRange(min=50, max=250, message='Рост должен быть от 50 до 250 см')
    ])
    weight = FloatField('Вес (кг)', validators=[
        Optional(),
        NumberRange(min=20, max=300, message='Вес должен быть от 20 до 300 кг')
    ])
    fitness_level = SelectField('Уровень подготовки', choices=[
        ('', 'Не указано'),
        ('beginner', 'Начинающий'),
        ('intermediate', 'Средний'),
        ('advanced', 'Продвинутый')
    ], validators=[Optional()])
    
    # Медицинская информация
    medical_conditions = TextAreaField('Медицинские противопоказания', validators=[Optional(), Length(max=1000)])
    allergies = TextAreaField('Аллергии', validators=[Optional(), Length(max=500)])
    medications = TextAreaField('Лекарства', validators=[Optional(), Length(max=500)])
    emergency_contact = StringField('Экстренный контакт', validators=[Optional(), Length(max=200)])
    
    # Предпочтения
    preferred_activities = StringField('Предпочитаемые активности', validators=[Optional(), Length(max=200)])
    
    # Настройки
    email_notifications = BooleanField('Email уведомления', default=True)
    push_notifications = BooleanField('Push уведомления', default=True)
    language = SelectField('Язык', choices=[
        ('ru', 'Русский'),
        ('en', 'English')
    ], default='ru')
    timezone = SelectField('Часовой пояс', choices=[
        ('Europe/Moscow', 'Москва (UTC+3)'),
        ('Europe/London', 'Лондон (UTC+0)'),
        ('America/New_York', 'Нью-Йорк (UTC-5)'),
        ('Asia/Tokyo', 'Токио (UTC+9)')
    ], default='Europe/Moscow')
    
    bio = TextAreaField('О себе', validators=[Optional(), Length(max=2000)])
    avatar_url = StringField('Ссылка на аватар', validators=[Optional(), Length(max=500)])

class ChangePasswordForm(FlaskForm):
    """Форма смены пароля"""
    current_password = PasswordField('Текущий пароль', validators=[DataRequired(message='Введите текущий пароль')])
    new_password = PasswordField('Новый пароль', validators=[
        DataRequired(message='Введите новый пароль'),
        Length(min=8, message='Пароль должен содержать минимум 8 символов'),
        EqualTo('confirm_password', message='Пароли не совпадают')
    ])
    confirm_password = PasswordField('Подтвердите новый пароль', validators=[DataRequired(message='Подтвердите новый пароль')])
    
    def validate_current_password(self, field):
        """Проверка текущего пароля"""
        from flask_login import current_user
        if not current_user.check_password(field.data):
            raise ValidationError('Неверный текущий пароль')

class ForgotPasswordForm(FlaskForm):
    """Форма восстановления пароля"""
    email = StringField('Email', validators=[
        DataRequired(message='Введите email'),
        Email(message='Введите корректный email')
    ])

class ResetPasswordForm(FlaskForm):
    """Форма сброса пароля"""
    new_password = PasswordField('Новый пароль', validators=[
        DataRequired(message='Введите новый пароль'),
        Length(min=8, message='Пароль должен содержать минимум 8 символов'),
        EqualTo('confirm_password', message='Пароли не совпадают')
    ])
    confirm_password = PasswordField('Подтвердите новый пароль', validators=[DataRequired(message='Подтвердите новый пароль')])

class TrainerProfileForm(FlaskForm):
    """Форма профиля тренера"""
    certification = StringField('Сертификация', validators=[Optional(), Length(max=200)])
    specialization = StringField('Специализация', validators=[
        DataRequired(message='Введите специализацию'),
        Length(max=100, message='Специализация слишком длинная')
    ])
    experience_years = IntegerField('Опыт работы (лет)', validators=[
        DataRequired(message='Введите опыт работы'),
        NumberRange(min=0, max=100, message='Опыт должен быть от 0 до 100 лет')
    ])
    hourly_rate = FloatField('Ставка в час', validators=[
        Optional(),
        NumberRange(min=0, max=10000, message='Ставка должна быть от 0 до 10000')
    ])
    
    # Социальные сети
    website = StringField('Веб-сайт', validators=[Optional(), Length(max=200)])
    instagram = StringField('Instagram', validators=[Optional(), Length(max=100)])
    youtube = StringField('YouTube', validators=[Optional(), Length(max=100)])
    
    # Образование и достижения
    education = TextAreaField('Образование', validators=[Optional(), Length(max=2000)])
    achievements = TextAreaField('Достижения', validators=[Optional(), Length(max=2000)])
    
    # Расписание
    work_schedule = StringField('Рабочее расписание', validators=[Optional(), Length(max=500)])
    
    # Дополнительно
    is_available = BooleanField('Доступен для новых клиентов', default=True)
'@
New-Item -ItemType File -Path "app/forms/auth.py" -Value $authForms -Force | Out-Null

# app/forms/training.py
$trainingForms = @'
"""
Формы для работы с тренировками
"""

from flask_wtf import FlaskForm
from wtforms import StringField, TextAreaField, SelectField, DateTimeField, IntegerField, FloatField, BooleanField, TimeField, DateField
from wtforms.validators import DataRequired, Length, Optional, NumberRange, ValidationError
from datetime import datetime, time, timedelta

class TrainingForm(FlaskForm):
    """Форма создания/редактирования тренировки"""
    # Основные данные
    title = StringField('Название тренировки', validators=[
        DataRequired(message='Введите название тренировки'),
        Length(min=5, max=200, message='Название должно быть от 5 до 200 символов')
    ])
    description = TextAreaField('Описание', validators=[
        DataRequired(message='Введите описание тренировки'),
        Length(min=10, max=5000, message='Описание должно быть от 10 до 5000 символов')
    ])
    short_description = StringField('Краткое описание', validators=[
        Optional(),
        Length(max=500, message='Краткое описание не должно превышать 500 символов')
    ])
    
    # Категория и тип
    category_id = SelectField('Категория', coerce=int, validators=[DataRequired(message='Выберите категорию')])
    training_type = SelectField('Тип тренировки', choices=[
        ('group', 'Групповая'),
        ('individual', 'Индивидуальная'),
        ('recorded', 'Запись')
    ], validators=[DataRequired(message='Выберите тип тренировки')])
    
    # Сложность
    difficulty = SelectField('Сложность', choices=[
        ('beginner', 'Начинающий'),
        ('intermediate', 'Средний'),
        ('advanced', 'Продвинутый')
    ], validators=[DataRequired(message='Выберите сложность')])
    intensity = SelectField('Интенсивность', choices=[
        ('low', 'Низкая'),
        ('medium', 'Средняя'),
        ('high', 'Высокая')
    ], validators=[DataRequired(message='Выберите интенсивность')])
    
    # Время и продолжительность
    schedule_time = DateTimeField('Время проведения', format='%Y-%m-%d %H:%M', validators=[
        DataRequired(message='Введите время проведения')
    ])
    duration = IntegerField('Продолжительность (минут)', validators=[
        DataRequired(message='Введите продолжительность'),
        NumberRange(min=15, max=300, message='Продолжительность должна быть от 15 до 300 минут')
    ])
    timezone = SelectField('Часовой пояс', choices=[
        ('Europe/Moscow', 'Москва (UTC+3)'),
        ('Europe/London', 'Лондон (UTC+0)'),
        ('America/New_York', 'Нью-Йорк (UTC-5)'),
        ('Asia/Tokyo', 'Токио (UTC+9)')
    ], default='Europe/Moscow')
    
    # Участники
    max_participants = IntegerField('Максимальное количество участников', validators=[
        DataRequired(message='Введите максимальное количество участников'),
        NumberRange(min=1, max=1000, message='Количество участников должно быть от 1 до 1000')
    ])
    min_participants = IntegerField('Минимальное количество участников', validators=[
        Optional(),
        NumberRange(min=1, max=100, message='Минимальное количество участников должно быть от 1 до 100')
    ])
    
    # Возрастные ограничения
    age_limit_min = IntegerField('Минимальный возраст', validators=[
        Optional(),
        NumberRange(min=0, max=100, message='Минимальный возраст должен быть от 0 до 100 лет')
    ])
    age_limit_max = IntegerField('Максимальный возраст', validators=[
        Optional(),
        NumberRange(min=0, max=100, message='Максимальный возраст должен быть от 0 до 100 лет')
    ])
    
    # Ссылки
    video_link = StringField('Ссылка на видео', validators=[Optional(), Length(max=500)])
    meeting_link = StringField('Ссылка на онлайн-трансляцию', validators=[Optional(), Length(max=500)])
    materials_link = StringField('Ссылка на материалы', validators=[Optional(), Length(max=500)])
    
    # Цена
    price = FloatField('Цена', validators=[
        Optional(),
        NumberRange(min=0, max=100000, message='Цена должна быть от 0 до 100000')
    ])
    currency = SelectField('Валюта', choices=[
        ('RUB', 'Рубли (RUB)'),
        ('USD', 'Доллары (USD)'),
        ('EUR', 'Евро (EUR)')
    ], default='RUB')
    
    # Медицинские ограничения
    medical_contraindications = TextAreaField('Медицинские противопоказания', validators=[Optional(), Length(max=2000)])
    required_equipment = TextAreaField('Необходимое оборудование', validators=[Optional(), Length(max=2000)])
    
    # Теги и ключевые слова
    tags = StringField('Теги (через запятую)', validators=[Optional(), Length(max=500)])
    keywords = StringField('Ключевые слова', validators=[Optional(), Length(max=500)])
    
    # Настройки
    language = SelectField('Язык', choices=[
        ('ru', 'Русский'),
        ('en', 'English')
    ], default='ru')
    
    def validate_schedule_time(self, field):
        """Проверка времени проведения"""
        if field.data:
            # Тренировка должна быть запланирована минимум за 1 час
            min_time = datetime.utcnow() + timedelta(hours=1)
            if field.data < min_time:
                raise ValidationError('Тренировка должна быть запланирована минимум за 1 час от текущего времени')
            
            # Тренировка не должна быть запланирована больше чем на год вперед
            max_time = datetime.utcnow() + timedelta(days=365)
            if field.data > max_time:
                raise ValidationError('Тренировка не может быть запланирована более чем на год вперед')
    
    def validate_age_limit_min(self, field):
        """Проверка минимального возраста"""
        if field.data and self.age_limit_max.data:
            if field.data > self.age_limit_max.data:
                raise ValidationError('Минимальный возраст не может быть больше максимального')
    
    def validate_age_limit_max(self, field):
        """Проверка максимального возраста"""
        if field.data and self.age_limit_min.data:
            if field.data < self.age_limit_min.data:
                raise ValidationError('Максимальный возраст не может быть меньше минимального')

class TrainingSearchForm(FlaskForm):
    """Форма поиска тренировок"""
    query = StringField('Поиск', validators=[Optional(), Length(max=100)])
    category_id = SelectField('Категория', coerce=int, validators=[Optional()])
    training_type = SelectField('Тип', choices=[
        ('', 'Любой'),
        ('group', 'Групповая'),
        ('individual', 'Индивидуальная'),
        ('recorded', 'Запись')
    ], validators=[Optional()])
    difficulty = SelectField('Сложность', choices=[
        ('', 'Любая'),
        ('beginner', 'Начинающий'),
        ('intermediate', 'Средний'),
        ('advanced', 'Продвинутый')
    ], validators=[Optional()])
    
    # Цена
    min_price = FloatField('Минимальная цена', validators=[Optional(), NumberRange(min=0)])
    max_price = FloatField('Максимальная цена', validators=[Optional(), NumberRange(min=0)])
    
    # Время
    date_from = DateField('Дата от', format='%Y-%m-%d', validators=[Optional()])
    date_to = DateField('Дата до', format='%Y-%m-%d', validators=[Optional()])
    
    # Сортировка
    sort_by = SelectField('Сортировать по', choices=[
        ('schedule_time', 'Дате проведения'),
        ('price', 'Цене'),
        ('rating', 'Рейтингу'),
        ('created_at', 'Дате создания')
    ], default='schedule_time')
    sort_order = SelectField('Порядок', choices=[
        ('asc', 'По возрастанию'),
        ('desc', 'По убыванию')
    ], default='asc')
    
    # Фильтры
    only_upcoming = BooleanField('Только предстоящие', default=True)
    only_available = BooleanField('Только со свободными местами', default=False)
    only_free = BooleanField('Только бесплатные', default=False)

class TrainingRegistrationForm(FlaskForm):
    """Форма регистрации на тренировку"""
    registration_type = SelectField('Тип регистрации', choices=[
        ('standard', 'Стандартная'),
        ('waitlist', 'Лист ожидания'),
        ('trial', 'Пробная')
    ], default='standard')
    notes = TextAreaField('Примечания', validators=[Optional(), Length(max=1000)])

class TrainingScheduleForm(FlaskForm):
    """Форма создания расписания тренировок"""
    recurrence_pattern = SelectField('Повторение', choices=[
        ('daily', 'Ежедневно'),
        ('weekly', 'Еженедельно'),
        ('monthly', 'Ежемесячно')
    ], validators=[DataRequired(message='Выберите тип повторения')])
    
    # Для недельного расписания
    recurrence_days = StringField('Дни недели (через запятую, 1=Пн)', validators=[Optional()])
    recurrence_interval = IntegerField('Интервал', validators=[
        DataRequired(message='Введите интервал'),
        NumberRange(min=1, max=365, message='Интервал должен быть от 1 до 365')
    ])
    
    # Время
    start_time = TimeField('Время начала', format='%H:%M', validators=[DataRequired(message='Введите время начала')])
    end_time = TimeField('Время окончания', format='%H:%M', validators=[DataRequired(message='Введите время окончания')])
    
    # Период
    start_date = DateField('Дата начала', format='%Y-%m-%d', validators=[DataRequired(message='Введите дату начала')])
    end_date = DateField('Дата окончания', format='%Y-%m-%d', validators=[Optional()])
    max_occurrences = IntegerField('Максимальное количество повторений', validators=[Optional(), NumberRange(min=1)])
    
    def validate_start_time(self, field):
        """Проверка времени начала"""
        if field.data and self.end_time.data:
            if field.data >= self.end_time.data:
                raise ValidationError('Время начала должно быть раньше времени окончания')
    
    def validate_start_date(self, field):
        """Проверка даты начала"""
        if field.data:
            if field.data < datetime.now().date():
                raise ValidationError('Дата начала не может быть в прошлом')
    
    def validate_end_date(self, field):
        """Проверка даты окончания"""
        if field.data and self.start_date.data:
            if field.data < self.start_date.data:
                raise ValidationError('Дата окончания не может быть раньше даты начала')
    
    def validate_recurrence_days(self, field):
        """Проверка дней недели"""
        if self.recurrence_pattern.data == 'weekly' and field.data:
            try:
                days = [int(d.strip()) for d in field.data.split(',')]
                for day in days:
                    if day < 0 or day > 6:
                        raise ValidationError('Дни недели должны быть от 0 (Пн) до 6 (Вс)')
            except ValueError:
                raise ValidationError('Введите дни недели через запятую (например: 1,3,5)')
'@
New-Item -ItemType File -Path "app/forms/training.py" -Value $trainingForms -Force | Out-Null

# app/forms/progress.py
$progressForms = @'
"""
Формы для отслеживания прогресса
"""

from flask_wtf import FlaskForm
from wtforms import StringField, TextAreaField, SelectField, DateField, IntegerField, FloatField, BooleanField
from wtforms.validators import DataRequired, Length, Optional, NumberRange, ValidationError
from datetime import date, datetime

class ProgressEntryForm(FlaskForm):
    """Форма добавления записи о прогрессе"""
    date = DateField('Дата', format='%Y-%m-%d', default=date.today, validators=[
        DataRequired(message='Выберите дату')
    ])
    activity_type = SelectField('Тип активности', choices=[
        ('', 'Выберите тип активности'),
        ('running', 'Бег'),
        ('walking', 'Ходьба'),
        ('cycling', 'Велосипед'),
        ('swimming', 'Плавание'),
        ('strength', 'Силовая тренировка'),
        ('yoga', 'Йога'),
        ('pilates', 'Пилатес'),
        ('crossfit', 'Кроссфит'),
        ('dance', 'Танцы'),
        ('other', 'Другое')
    ], validators=[DataRequired(message='Выберите тип активности')])
    
    # Основные метрики
    duration = IntegerField('Продолжительность (минут)', validators=[
        DataRequired(message='Введите продолжительность'),
        NumberRange(min=1, max=1440, message='Продолжительность должна быть от 1 до 1440 минут')
    ])
    calories_burned = FloatField('Сожженные калории', validators=[
        Optional(),
        NumberRange(min=0, max=10000, message='Калории должны быть от 0 до 10000')
    ])
    distance = FloatField('Дистанция (км)', validators=[
        Optional(),
        NumberRange(min=0, max=1000, message='Дистанция должна быть от 0 до 1000 км')
    ])
    
    # Показатели здоровья
    weight = FloatField('Вес (кг)', validators=[
        Optional(),
        NumberRange(min=20, max=300, message='Вес должен быть от 20 до 300 кг')
    ])
    body_fat_percentage = FloatField('Процент жира (%)', validators=[
        Optional(),
        NumberRange(min=3, max=60, message='Процент жира должен быть от 3 до 60%')
    ])
    muscle_mass = FloatField('Мышечная масса (кг)', validators=[
        Optional(),
        NumberRange(min=10, max=200, message='Мышечная масса должна быть от 10 до 200 кг')
    ])
    
    # Сердечный ритм и давление
    resting_heart_rate = IntegerField('Пульс в покое (уд/мин)', validators=[
        Optional(),
        NumberRange(min=30, max=200, message='Пульс должен быть от 30 до 200 уд/мин')
    ])
    blood_pressure_systolic = IntegerField('Давление (систолическое)', validators=[
        Optional(),
        NumberRange(min=60, max=250, message='Систолическое давление должно быть от 60 до 250')
    ])
    blood_pressure_diastolic = IntegerField('Давление (диастолическое)', validators=[
        Optional(),
        NumberRange(min=40, max=150, message='Диастолическое давление должно быть от 40 до 150')
    ])
    
    # Сон
    sleep_duration = IntegerField('Продолжительность сна (минут)', validators=[
        Optional(),
        NumberRange(min=0, max=1440, message='Продолжительность сна должна быть от 0 до 1440 минут')
    ])
    sleep_quality = IntegerField('Качество сна (1-10)', validators=[
        Optional(),
        NumberRange(min=1, max=10, message='Качество сна должно быть от 1 до 10')
    ])
    
    # Самочувствие
    energy_level = IntegerField('Уровень энергии (1-10)', validators=[
        Optional(),
        NumberRange(min=1, max=10, message='Уровень энергии должен быть от 1 до 10')
    ])
    mood = IntegerField('Настроение (1-10)', validators=[
        Optional(),
        NumberRange(min=1, max=10, message='Настроение должно быть от 1 до 10')
    ])
    stress_level = IntegerField('Уровень стресса (1-10)', validators=[
        Optional(),
        NumberRange(min=1, max=10, message='Уровень стресса должен быть от 1 до 10')
    ])
    
    # Дополнительно
    notes = TextAreaField('Заметки', validators=[Optional(), Length(max=2000)])
    location = StringField('Местоположение', validators=[Optional(), Length(max=100)])
    weather = StringField('Погода', validators=[Optional(), Length(max=50)])
    
    # Источник данных
    source = SelectField('Источник данных', choices=[
        ('manual', 'Вручную'),
        ('wearable', 'Умное устройство'),
        ('import', 'Импорт')
    ], default='manual')
    
    def validate_date(self, field):
        """Проверка даты"""
        if field.data:
            if field.data > date.today():
                raise ValidationError('Дата не может быть в будущем')
            # Не слишком далеко в прошлом
            if (date.today() - field.data).days > 3650:  # 10 лет
                raise ValidationError('Дата не может быть более 10 лет назад')
    
    def validate_blood_pressure_systolic(self, field):
        """Проверка давления"""
        if field.data and self.blood_pressure_diastolic.data:
            if field.data <= self.blood_pressure_diastolic.data:
                raise ValidationError('Систолическое давление должно быть выше диастолического')

class GoalForm(FlaskForm):
    """Форма создания цели"""
    title = StringField('Название цели', validators=[
        DataRequired(message='Введите название цели'),
        Length(min=5, max=200, message='Название должно быть от 5 до 200 символов')
    ])
    description = TextAreaField('Описание', validators=[Optional(), Length(max=2000)])
    
    goal_type = SelectField('Тип цели', choices=[
        ('weight_loss', 'Похудение'),
        ('muscle_gain', 'Набор мышечной массы'),
        ('endurance', 'Выносливость'),
        ('strength', 'Сила'),
        ('flexibility', 'Гибкость'),
        ('running_distance', 'Дистанция бега'),
        ('cycling_distance', 'Дистанция велосипеда'),
        ('calorie_burn', 'Сжигание калорий'),
        ('body_fat', 'Процент жира'),
        ('other', 'Другое')
    ], validators=[DataRequired(message='Выберите тип цели')])
    
    target_value = FloatField('Целевое значение', validators=[
        DataRequired(message='Введите целевое значение'),
        NumberRange(min=0.1, max=1000000, message='Целевое значение должно быть от 0.1 до 1000000')
    ])
    unit = StringField('Единица измерения', validators=[
        DataRequired(message='Введите единицу измерения'),
        Length(max=20, message='Единица измерения слишком длинная')
    ])
    
    # Временные рамки
    start_date = DateField('Дата начала', format='%Y-%m-%d', default=date.today, validators=[DataRequired(message='Выберите дату начала')])
    target_date = DateField('Целевая дата', format='%Y-%m-%d', validators=[DataRequired(message='Выберите целевую дату')])
    
    # Повторяемость
    is_recurring = BooleanField('Повторяющаяся цель', default=False)
    recurrence_pattern = SelectField('Повторение', choices=[
        ('weekly', 'Еженедельно'),
        ('monthly', 'Ежемесячно')
    ], validators=[Optional()])
    
    # Мотивация
    motivation = TextAreaField('Мотивация', validators=[Optional(), Length(max=1000)])
    rewards = StringField('Награды (через запятую)', validators=[Optional(), Length(max=500)])
    
    # Напоминания
    reminder_enabled = BooleanField('Включить напоминания', default=False)
    reminder_frequency = SelectField('Частота напоминаний', choices=[
        ('daily', 'Ежедневно'),
        ('weekly', 'Еженедельно'),
        ('monthly', 'Ежемесячно')
    ], default='weekly', validators=[Optional()])
    
    def validate_target_date(self, field):
        """Проверка целевой даты"""
        if field.data:
            if field.data <= self.start_date.data:
                raise ValidationError('Целевая дата должна быть позже даты начала')
            
            # Максимум 5 лет для цели
            max_date = self.start_date.data.replace(year=self.start_date.data.year + 5)
            if field.data > max_date:
                raise ValidationError('Цель не может быть установлена более чем на 5 лет вперед')

class ProgressFilterForm(FlaskForm):
    """Форма фильтрации записей о прогрессе"""
    date_from = DateField('Дата от', format='%Y-%m-%d', validators=[Optional()])
    date_to = DateField('Дата до', format='%Y-%m-%d', validators=[Optional()])
    
    activity_type = SelectField('Тип активности', choices=[
        ('', 'Все активности'),
        ('running', 'Бег'),
        ('walking', 'Ходьба'),
        ('cycling', 'Велосипед'),
        ('swimming', 'Плавание'),
        ('strength', 'Силовая тренировка'),
        ('yoga', 'Йога'),
        ('other', 'Другое')
    ], validators=[Optional()])
    
    min_duration = IntegerField('Минимальная продолжительность (мин)', validators=[Optional(), NumberRange(min=0)])
    max_duration = IntegerField('Максимальная продолжительность (мин)', validators=[Optional(), NumberRange(min=0)])
    
    min_calories = FloatField('Минимум калорий', validators=[Optional(), NumberRange(min=0)])
    max_calories = FloatField('Максимум калорий', validators=[Optional(), NumberRange(min=0)])
    
    min_distance = FloatField('Минимальная дистанция (км)', validators=[Optional(), NumberRange(min=0)])
    max_distance = FloatField('Максимальная дистанция (км)', validators=[Optional(), NumberRange(min=0)])
    
    sort_by = SelectField('Сортировать по', choices=[
        ('date', 'Дате'),
        ('duration', 'Продолжительности'),
        ('calories_burned', 'Калориям'),
        ('distance', 'Дистанции')
    ], default='date')
    sort_order = SelectField('Порядок', choices=[
        ('desc', 'По убыванию'),
        ('asc', 'По возрастанию')
    ], default='desc')
    
    def validate_date_from(self, field):
        """Проверка даты начала"""
        if field.data and self.date_to.data:
            if field.data > self.date_to.data:
                raise ValidationError('Дата "от" не может быть позже даты "до"')
    
    def validate_min_duration(self, field):
        """Проверка минимальной продолжительности"""
        if field.data and self.max_duration.data:
            if field.data > self.max_duration.data:
                raise ValidationError('Минимальная продолжительность не может быть больше максимальной')
    
    def validate_min_calories(self, field):
        """Проверка минимального количества калорий"""
        if field.data and self.max_calories.data:
            if field.data > self.max_calories.data:
                raise ValidationError('Минимальное количество калорий не может быть больше максимального')
    
    def validate_min_distance(self, field):
        """Проверка минимальной дистанции"""
        if field.data and self.max_distance.data:
            if field.data > self.max_distance.data:
                raise ValidationError('Минимальная дистанция не может быть больше максимальной')
'@
New-Item -ItemType File -Path "app/forms/progress.py" -Value $progressForms -Force | Out-Null

# app/forms/feedback.py
$feedbackForms = @'
"""
Формы для системы отзывов и рейтингов
"""

from flask_wtf import FlaskForm
from wtforms import StringField, TextAreaField, SelectField, FloatField, BooleanField, IntegerField
from wtforms.validators import DataRequired, Length, Optional, NumberRange, ValidationError

class FeedbackForm(FlaskForm):
    """Форма добавления отзыва о тренировке"""
    title = StringField('Заголовок', validators=[
        Optional(),
        Length(max=200, message='Заголовок не должен превышать 200 символов')
    ])
    comment = TextAreaField('Отзыв', validators=[
        DataRequired(message='Напишите отзыв'),
        Length(min=10, max=5000, message='Отзыв должен быть от 10 до 5000 символов')
    ])
    
    # Рейтинги
    rating_overall = FloatField('Общая оценка (1-5)', validators=[
        DataRequired(message='Поставьте общую оценку'),
        NumberRange(min=1, max=5, message='Оценка должна быть от 1 до 5')
    ])
    rating_trainer = FloatField('Оценка тренера (1-5)', validators=[
        Optional(),
        NumberRange(min=1, max=5, message='Оценка должна быть от 1 до 5')
    ])
    rating_content = FloatField('Оценка содержания (1-5)', validators=[
        Optional(),
        NumberRange(min=1, max=5, message='Оценка должна быть от 1 до 5')
    ])
    rating_difficulty = FloatField('Оценка сложности (1-5)', validators=[
        Optional(),
        NumberRange(min=1, max=5, message='Оценка должна быть от 1 до 5')
    ])
    rating_organization = FloatField('Оценка организации (1-5)', validators=[
        Optional(),
        NumberRange(min=1, max=5, message='Оценка должна быть от 1 до 5')
    ])
    
    # Анонимность
    is_anonymous = BooleanField('Опубликовать анонимно', default=False)
    
    # Рекомендации
    would_recommend = SelectField('Рекомендую ли я эту тренировку?', choices=[
        ('yes', 'Да, рекомендую'),
        ('maybe', 'Возможно'),
        ('no', 'Нет, не рекомендую')
    ], validators=[DataRequired(message='Укажите, рекомендуете ли вы тренировку')])
    
    # Достижения
    goals_achieved = StringField('Достигнутые цели', validators=[Optional(), Length(max=500)])
    challenges_faced = TextAreaField('С какими трудностями столкнулись?', validators=[Optional(), Length(max=1000)])
    suggestions = TextAreaField('Предложения по улучшению', validators=[Optional(), Length(max=1000)])
    
    def validate_rating_overall(self, field):
        """Проверка общей оценки"""
        try:
            value = float(field.data)
            if value < 1 or value > 5:
                raise ValidationError('Оценка должна быть от 1 до 5')
        except ValueError:
            raise ValidationError('Введите числовое значение')

class CommentForm(FlaskForm):
    """Форма добавления комментария к отзыву"""
    content = TextAreaField('Комментарий', validators=[
        DataRequired(message='Напишите комментарий'),
        Length(min=1, max=1000, message='Комментарий должен быть от 1 до 1000 символов')
    ])
    
    def validate_content(self, field):
        """Проверка содержимого комментария"""
        # Простая проверка на спам
        spam_keywords = ['купить', 'продать', 'дешево', 'акция', 'скидка', 'bit.ly', 'tinyurl']
        content_lower = field.data.lower()
        for keyword in spam_keywords:
            if keyword in content_lower:
                raise ValidationError('Комментарий содержит запрещенные слова')

class FeedbackSearchForm(FlaskForm):
    """Форма поиска отзывов"""
    query = StringField('Поиск', validators=[Optional(), Length(max=100)])
    
    # Фильтры по оценкам
    min_rating = FloatField('Минимальная оценка', validators=[
        Optional(),
        NumberRange(min=1, max=5, message='Оценка должна быть от 1 до 5')
    ])
    max_rating = FloatField('Максимальная оценка', validators=[
        Optional(),
        NumberRange(min=1, max=5, message='Оценка должна быть от 1 до 5')
    ])
    
    # Типы отзывов
    has_comment = SelectField('Только с текстом', choices=[
        ('', 'Любые'),
        ('yes', 'Только с текстом'),
        ('no', 'Только оценки')
    ], validators=[Optional()])
    
    # Рекомендации
    would_recommend = SelectField('Рекомендация', choices=[
        ('', 'Любые'),
        ('yes', 'Рекомендуют'),
        ('no', 'Не рекомендуют')
    ], validators=[Optional()])
    
    # Сортировка
    sort_by = SelectField('Сортировать по', choices=[
        ('created_at', 'Дате'),
        ('rating_overall', 'Оценке'),
        ('likes_count', 'Количеству лайков')
    ], default='created_at')
    sort_order = SelectField('Порядок', choices=[
        ('desc', 'По убыванию'),
        ('asc', 'По возрастанию')
    ], default='desc')
    
    # Дополнительно
    only_with_photos = BooleanField('Только с фотографиями', default=False)
    only_recent = BooleanField('Только за последний месяц', default=False)
    
    def validate_min_rating(self, field):
        """Проверка минимальной оценки"""
        if field.data and self.max_rating.data:
            if field.data > self.max_rating.data:
                raise ValidationError('Минимальная оценка не может быть больше максимальной')

class FeedbackModerationForm(FlaskForm):
    """Форма модерации отзыва"""
    moderation_status = SelectField('Статус модерации', choices=[
        ('pending', 'На рассмотрении'),
        ('approved', 'Одобрено'),
        ('rejected', 'Отклонено')
    ], validators=[DataRequired(message='Выберите статус модерации')])
    
    moderation_notes = TextAreaField('Примечания модератора', validators=[
        Optional(),
        Length(max=2000, message='Примечания не должны превышать 2000 символов')
    ])
    
    # Действия
    actions_taken = StringField('Предпринятые действия', validators=[Optional(), Length(max=500)])
    penalty_points = IntegerField('Штрафные баллы', validators=[
        Optional(),
        NumberRange(min=0, max=100, message='Штрафные баллы должны быть от 0 до 100')
    ])
    
    def validate_moderation_notes(self, field):
        """Проверка примечаний при отклонении"""
        if self.moderation_status.data == 'rejected' and not field.data:
            raise ValidationError('При отклонении отзыва необходимо указать причину')

class ReportForm(FlaskForm):
    """Форма жалобы на контент"""
    reason = SelectField('Причина жалобы', choices=[
        ('spam', 'Спам'),
        ('inappropriate', 'Неуместный контент'),
        ('harassment', 'Оскорбления или домогательства'),
        ('false_information', 'Ложная информация'),
        ('copyright', 'Нарушение авторских прав'),
        ('other', 'Другое')
    ], validators=[DataRequired(message='Выберите причину жалобы')])
    
    description = TextAreaField('Описание проблемы', validators=[
        DataRequired(message='Опишите проблему'),
        Length(min=10, max=1000, message='Описание должно быть от 10 до 1000 символов')
    ])
    
    contact_email = StringField('Email для связи', validators=[Optional(), Length(max=120)])
    
    def validate_description(self, field):
        """Проверка описания"""
        # Проверка на наличие оскорблений
        offensive_words = ['идиот', 'дурак', 'мудак', 'кретин']  # Упрощенный список
        content_lower = field.data.lower()
        for word in offensive_words:
            if word in content_lower:
                raise ValidationError('Описание содержит недопустимые выражения')
'@
New-Item -ItemType File -Path "app/forms/feedback.py" -Value $feedbackForms -Force | Out-Null

Write-Host "  Созданы все формы" -ForegroundColor DarkGreen

# 4. Маршруты
# app/routes/__init__.py
$routesInit = @'
# Инициализация маршрутов
from app.routes.auth import bp as auth_bp
from app.routes.trainings import bp as trainings_bp
from app.routes.progress import bp as progress_bp
from app.routes.admin import bp as admin_bp
from app.routes.api import bp as api_bp
from app.routes.main import bp as main_bp

__all__ = ['auth_bp', 'trainings_bp', 'progress_bp', 'admin_bp', 'api_bp', 'main_bp']
'@
New-Item -ItemType File -Path "app/routes/__init__.py" -Value $routesInit -Force | Out-Null

# app/routes/auth.py
$authRoutes = @'
"""
Маршруты для аутентификации и управления пользователями
"""

from flask import Blueprint, render_template, redirect, url_for, flash, request, jsonify, current_app
from flask_login import login_user, logout_user, login_required, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from sqlalchemy.exc import IntegrityError
import logging

from app import db
from app.forms.auth import (
    LoginForm, RegistrationForm, ProfileForm, ChangePasswordForm,
    ForgotPasswordForm, ResetPasswordForm, TrainerProfileForm
)
from app.models import User, UserProfile, Trainer, Client, AuditLog
from app.utils.decorators import role_required

bp = Blueprint('auth', __name__, url_prefix='/auth')

# Настройка логирования
logger = logging.getLogger(__name__)

@bp.route('/login', methods=['GET', 'POST'])
def login():
    """Страница входа в систему"""
    if current_user.is_authenticated:
        flash('Вы уже вошли в систему', 'info')
        return redirect(url_for('main.index'))
    
    form = LoginForm()
    
    if form.validate_on_submit():
        try:
            user = User.query.filter_by(email=form.email.data).first()
            
            if user and user.check_password(form.password.data):
                if not user.is_active:
                    flash('Ваш аккаунт деактивирован. Обратитесь к администратору.', 'danger')
                    return redirect(url_for('auth.login'))
                
                # Вход пользователя
                login_user(user, remember=form.remember.data)
                user.last_login = db.func.now()
                db.session.commit()
                
                # Логирование входа
                AuditLog.log_action(
                    user_id=user.id,
                    action='user_login',
                    resource_type='user',
                    resource_id=user.id,
                    request=request
                )
                
                logger.info(f'User {user.email} logged in successfully')
                flash('Вы успешно вошли в систему!', 'success')
                
                # Перенаправление в зависимости от роли
                if user.role == 'admin':
                    return redirect(url_for('admin.dashboard'))
                else:
                    return redirect(url_for('main.index'))
            else:
                flash('Неверный email или пароль', 'danger')
                logger.warning(f'Failed login attempt for email: {form.email.data}')
                
        except Exception as e:
            db.session.rollback()
            logger.error(f'Login error: {str(e)}')
            flash('Произошла ошибка при входе в систему', 'danger')
    
    return render_template('auth/login.html', form=form, title='Вход в систему')

@bp.route('/register', methods=['GET', 'POST'])
def register():
    """Страница регистрации"""
    if current_user.is_authenticated:
        flash('Вы уже зарегистрированы', 'info')
        return redirect(url_for('main.index'))
    
    form = RegistrationForm()
    
    if form.validate_on_submit():
        try:
            # Создание пользователя
            user = User(
                email=form.email.data,
                username=form.username.data,
                role=form.role.data
            )
            user.set_password(form.password.data)
            
            db.session.add(user)
            db.session.flush()  # Получаем ID пользователя
            
            # Создание профиля
            profile = UserProfile(
                user_id=user.id,
                full_name=form.full_name.data,
                date_of_birth=form.date_of_birth.data,
                gender=form.gender.data,
                phone=form.phone.data,
                height=form.height.data,
                weight=form.weight.data,
                fitness_level=form.fitness_level.data,
                medical_conditions=form.medical_conditions.data,
                allergies=form.allergies.data
            )
            db.session.add(profile)
            
            # Создание записи в зависимости от роли
            if form.role.data == 'trainer':
                trainer = Trainer(
                    user_id=user.id,
                    specialization=form.specialization.data,
                    experience_years=form.experience_years.data,
                    certification=form.certification.data,
                    bio=form.bio.data
                )
                db.session.add(trainer)
            elif form.role.data == 'client':
                client = Client(user_id=user.id)
                db.session.add(client)
            
            db.session.commit()
            
            # Логирование регистрации
            AuditLog.log_action(
                user_id=user.id,
                action='user_registration',
                resource_type='user',
                resource_id=user.id,
                details_after={'role': user.role, 'email': user.email},
                request=request
            )
            
            logger.info(f'New user registered: {user.email} ({user.role})')
            flash('Регистрация прошла успешно! Теперь вы можете войти в систему.', 'success')
            
            # Отправка email подтверждения (если настроено)
            # send_confirmation_email(user)
            
            return redirect(url_for('auth.login'))
            
        except IntegrityError:
            db.session.rollback()
            flash('Пользователь с таким email или именем уже существует', 'danger')
            logger.error(f'Registration integrity error for email: {form.email.data}')
        except Exception as e:
            db.session.rollback()
            logger.error(f'Registration error: {str(e)}')
            flash('Произошла ошибка при регистрации. Попробуйте еще раз.', 'danger')
    
    return render_template('auth/register.html', form=form, title='Регистрация')

@bp.route('/logout')
@login_required
def logout():
    """Выход из системы"""
    # Логирование выхода
    AuditLog.log_action(
        user_id=current_user.id,
        action='user_logout',
        resource_type='user',
        resource_id=current_user.id,
        request=request
    )
    
    logout_user()
    flash('Вы вышли из системы', 'info')
    return redirect(url_for('main.index'))

@bp.route('/profile', methods=['GET', 'POST'])
@login_required
def profile():
    """Страница профиля пользователя"""
    user_profile = current_user.profile
    form = ProfileForm(obj=user_profile) if user_profile else ProfileForm()
    
    if form.validate_on_submit():
        try:
            if not user_profile:
                user_profile = UserProfile(user_id=current_user.id)
                db.session.add(user_profile)
            
            # Обновление профиля
            form.populate_obj(user_profile)
            db.session.commit()
            
            # Логирование изменения профиля
            AuditLog.log_action(
                user_id=current_user.id,
                action='profile_update',
                resource_type='user_profile',
                resource_id=current_user.id,
                request=request
            )
            
            flash('Профиль успешно обновлен', 'success')
            return redirect(url_for('auth.profile'))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Profile update error: {str(e)}')
            flash('Ошибка при обновлении профиля', 'danger')
    
    return render_template('auth/profile.html', form=form, title='Мой профиль')

@bp.route('/profile/trainer', methods=['GET', 'POST'])
@login_required
@role_required('trainer')
def trainer_profile():
    """Профиль тренера"""
    trainer = Trainer.query.filter_by(user_id=current_user.id).first()
    
    if not trainer:
        # Создание записи тренера, если она отсутствует
        trainer = Trainer(user_id=current_user.id)
        db.session.add(trainer)
        db.session.commit()
    
    form = TrainerProfileForm(obj=trainer)
    
    if form.validate_on_submit():
        try:
            form.populate_obj(trainer)
            db.session.commit()
            
            # Логирование обновления профиля тренера
            AuditLog.log_action(
                user_id=current_user.id,
                action='trainer_profile_update',
                resource_type='trainer',
                resource_id=trainer.id,
                request=request
            )
            
            flash('Профиль тренера успешно обновлен', 'success')
            return redirect(url_for('auth.trainer_profile'))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Trainer profile update error: {str(e)}')
            flash('Ошибка при обновлении профиля тренера', 'danger')
    
    return render_template('auth/trainer_profile.html', form=form, title='Профиль тренера')

@bp.route('/change-password', methods=['GET', 'POST'])
@login_required
def change_password():
    """Смена пароля"""
    form = ChangePasswordForm()
    
    if form.validate_on_submit():
        try:
            current_user.set_password(form.new_password.data)
            db.session.commit()
            
            # Логирование смены пароля
            AuditLog.log_action(
                user_id=current_user.id,
                action='password_change',
                resource_type='user',
                resource_id=current_user.id,
                request=request
            )
            
            flash('Пароль успешно изменен', 'success')
            return redirect(url_for('auth.profile'))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Password change error: {str(e)}')
            flash('Ошибка при изменении пароля', 'danger')
    
    return render_template('auth/change_password.html', form=form, title='Смена пароля')

@bp.route('/forgot-password', methods=['GET', 'POST'])
def forgot_password():
    """Запрос на восстановление пароля"""
    if current_user.is_authenticated:
        return redirect(url_for('main.index'))
    
    form = ForgotPasswordForm()
    
    if form.validate_on_submit():
        try:
            user = User.query.filter_by(email=form.email.data).first()
            
            if user:
                # Генерация токена сброса пароля
                # В реальном приложении здесь была бы отправка email
                flash('Инструкции по восстановлению пароля отправлены на ваш email', 'success')
                
                # Логирование запроса на восстановление
                AuditLog.log_action(
                    user_id=user.id,
                    action='password_reset_request',
                    resource_type='user',
                    resource_id=user.id,
                    request=request
                )
            else:
                # Для безопасности не сообщаем, что пользователь не найден
                flash('Если email зарегистрирован, инструкции будут отправлены', 'success')
            
            return redirect(url_for('auth.login'))
            
        except Exception as e:
            logger.error(f'Password reset request error: {str(e)}')
            flash('Произошла ошибка. Попробуйте еще раз.', 'danger')
    
    return render_template('auth/forgot_password.html', form=form, title='Восстановление пароля')

@bp.route('/reset-password/<token>', methods=['GET', 'POST'])
def reset_password(token):
    """Сброс пароля по токену"""
    if current_user.is_authenticated:
        return redirect(url_for('main.index'))
    
    # В реальном приложении здесь была бы проверка токена
    form = ResetPasswordForm()
    
    if form.validate_on_submit():
        try:
            # Здесь должна быть логика проверки и использования токена
            # Для демонстрации просто показываем сообщение
            flash('Пароль успешно изменен. Теперь вы можете войти в систему.', 'success')
            return redirect(url_for('auth.login'))
            
        except Exception as e:
            logger.error(f'Password reset error: {str(e)}')
            flash('Неверный или просроченный токен', 'danger')
    
    return render_template('auth/reset_password.html', form=form, title='Сброс пароля')

@bp.route('/users')
@login_required
@role_required('admin')
def user_list():
    """Список пользователей (только для администраторов)"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    users = User.query.order_by(User.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    return render_template('auth/user_list.html', users=users, title='Пользователи')

@bp.route('/users/<int:user_id>')
@login_required
def user_detail(user_id):
    """Детальная информация о пользователе"""
    user = User.query.get_or_404(user_id)
    
    # Проверка прав доступа
    if current_user.id != user_id and current_user.role != 'admin':
        flash('У вас нет прав для просмотра этого профиля', 'danger')
        return redirect(url_for('main.index'))
    
    return render_template('auth/user_detail.html', user=user, title=f'Профиль {user.username}')

@bp.route('/users/<int:user_id>/toggle-active', methods=['POST'])
@login_required
@role_required('admin')
def toggle_user_active(user_id):
    """Активация/деактивация пользователя"""
    user = User.query.get_or_404(user_id)
    
    # Нельзя деактивировать себя
    if user.id == current_user.id:
        flash('Вы не можете деактивировать свой собственный аккаунт', 'danger')
        return redirect(url_for('auth.user_list'))
    
    try:
        user.is_active = not user.is_active
        db.session.commit()
        
        action = 'активирован' if user.is_active else 'деактивирован'
        
        # Логирование действия
        AuditLog.log_action(
            user_id=current_user.id,
            action=f'user_{"activate" if user.is_active else "deactivate"}',
            resource_type='user',
            resource_id=user.id,
            details_after={'is_active': user.is_active},
            request=request
        )
        
        flash(f'Пользователь {user.username} успешно {action}', 'success')
        
    except Exception as e:
        db.session.rollback()
        logger.error(f'User activation error: {str(e)}')
        flash('Ошибка при изменении статуса пользователя', 'danger')
    
    return redirect(url_for('auth.user_list'))

# API endpoints
@bp.route('/api/check-email', methods=['POST'])
def check_email():
    """API проверки доступности email"""
    data = request.get_json()
    email = data.get('email', '')
    
    if not email:
        return jsonify({'available': False, 'message': 'Email не указан'})
    
    user = User.query.filter_by(email=email).first()
    available = user is None
    
    return jsonify({
        'available': available,
        'message': 'Email доступен' if available else 'Email уже используется'
    })

@bp.route('/api/check-username', methods=['POST'])
def check_username():
    """API проверки доступности имени пользователя"""
    data = request.get_json()
    username = data.get('username', '')
    
    if not username:
        return jsonify({'available': False, 'message': 'Имя пользователя не указано'})
    
    user = User.query.filter_by(username=username).first()
    available = user is None
    
    return jsonify({
        'available': available,
        'message': 'Имя пользователя доступно' if available else 'Имя пользователя уже используется'
    })
'@
New-Item -ItemType File -Path "app/routes/auth.py" -Value $authRoutes -Force | Out-Null

# app/routes/trainings.py
$trainingsRoutes = @'
"""
Маршруты для работы с тренировками
"""

from flask import Blueprint, render_template, redirect, url_for, flash, request, jsonify, current_app
from flask_login import login_required, current_user
from sqlalchemy import or_, and_, func
from datetime import datetime, timedelta
import logging
import json

from app import db
from app.forms.training import (
    TrainingForm, TrainingSearchForm, TrainingRegistrationForm,
    TrainingScheduleForm
)
from app.forms.feedback import FeedbackForm
from app.models import (
    User, Training, TrainingRegistration, Trainer, TrainingCategory,
    Feedback, Rating, Notification, AuditLog, ContentModeration
)
from app.utils.decorators import role_required

bp = Blueprint('trainings', __name__, url_prefix='/trainings')

# Настройка логирования
logger = logging.getLogger(__name__)

@bp.route('/')
def training_list():
    """Список тренировок"""
    form = TrainingSearchForm(request.args)
    
    # Базовый запрос
    query = Training.query.filter(
        Training.status.in_(['approved', 'active'])
    )
    
    # Применение фильтров
    if form.query.data:
        search_term = f"%{form.query.data}%"
        query = query.filter(
            or_(
                Training.title.ilike(search_term),
                Training.description.ilike(search_term),
                Training.short_description.ilike(search_term),
                Training.tags.ilike(search_term)
            )
        )
    
    if form.category_id.data:
        query = query.filter_by(category_id=form.category_id.data)
    
    if form.training_type.data:
        query = query.filter_by(training_type=form.training_type.data)
    
    if form.difficulty.data:
        query = query.filter_by(difficulty=form.difficulty.data)
    
    if form.min_price.data is not None:
        query = query.filter(Training.price >= form.min_price.data)
    
    if form.max_price.data is not None:
        query = query.filter(Training.price <= form.max_price.data)
    
    if form.date_from.data:
        query = query.filter(Training.schedule_time >= form.date_from.data)
    
    if form.date_to.data:
        # Добавляем 1 день, чтобы включить полный день
        date_to = form.date_to.data + timedelta(days=1)
        query = query.filter(Training.schedule_time < date_to)
    
    if form.only_upcoming.data:
        query = query.filter(Training.schedule_time > datetime.utcnow())
    
    if form.only_available.data:
        # Подзапрос для подсчета регистраций
        from sqlalchemy import func
        registrations_subquery = db.session.query(
            TrainingRegistration.training_id,
            func.count(TrainingRegistration.id).label('reg_count')
        ).filter(TrainingRegistration.status == 'registered').group_by(TrainingRegistration.training_id).subquery()
        
        query = query.outerjoin(
            registrations_subquery,
            Training.id == registrations_subquery.c.training_id
        ).filter(
            or_(
                registrations_subquery.c.reg_count.is_(None),
                Training.max_participants > registrations_subquery.c.reg_count
            )
        )
    
    if form.only_free.data:
        query = query.filter(Training.price == 0)
    
    # Сортировка
    sort_column = {
        'schedule_time': Training.schedule_time,
        'price': Training.price,
        'rating': Training.average_rating,
        'created_at': Training.created_at
    }.get(form.sort_by.data, Training.schedule_time)
    
    if form.sort_order.data == 'desc':
        sort_column = sort_column.desc()
    
    query = query.order_by(sort_column)
    
    # Пагинация
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 12, type=int)
    trainings = query.paginate(page=page, per_page=per_page, error_out=False)
    
    # Получение категорий для формы
    categories = TrainingCategory.query.filter_by(is_active=True).order_by(TrainingCategory.order).all()
    form.category_id.choices = [(0, 'Все категории')] + [(c.id, c.name) for c in categories]
    
    # Получение тренировок пользователя (если авторизован)
    user_trainings = []
    if current_user.is_authenticated:
        user_registrations = TrainingRegistration.query.filter_by(
            user_id=current_user.id,
            status='registered'
        ).all()
        user_trainings = [reg.training_id for reg in user_registrations]
    
    return render_template(
        'trainings/list.html',
        trainings=trainings,
        form=form,
        user_trainings=user_trainings,
        categories=categories,
        title='Тренировки'
    )

@bp.route('/<int:training_id>')
def training_detail(training_id):
    """Детальная информация о тренировке"""
    training = Training.query.get_or_404(training_id)
    
    # Увеличение счетчика просмотров
    training.increment_views()
    
    # Проверка прав доступа
    if training.status == 'draft' and not (
        current_user.is_authenticated and 
        (current_user.role == 'admin' or 
         (current_user.role == 'trainer' and training.trainer.user_id == current_user.id))
    ):
        flash('Эта тренировка еще не опубликована', 'warning')
        return redirect(url_for('trainings.training_list'))
    
    # Проверка регистрации пользователя
    is_registered = False
    user_registration = None
    if current_user.is_authenticated:
        user_registration = TrainingRegistration.query.filter_by(
            user_id=current_user.id,
            training_id=training_id
        ).first()
        is_registered = user_registration is not None
    
    # Получение отзывов
    feedbacks = Feedback.query.filter_by(
        training_id=training_id,
        moderation_status='approved'
    ).order_by(Feedback.created_at.desc()).limit(10).all()
    
    # Проверка, может ли пользователь оставить отзыв
    can_add_feedback = False
    if current_user.is_authenticated and user_registration and user_registration.status == 'attended':
        # Проверяем, не оставлял ли уже пользователь отзыв
        existing_feedback = Feedback.query.filter_by(
            user_id=current_user.id,
            training_id=training_id
        ).first()
        can_add_feedback = not existing_feedback
    
    feedback_form = FeedbackForm() if can_add_feedback else None
    
    # Похожие тренировки
    similar_trainings = Training.query.filter(
        Training.id != training_id,
        Training.category_id == training.category_id,
        Training.status.in_(['approved', 'active']),
        Training.schedule_time > datetime.utcnow()
    ).order_by(Training.schedule_time).limit(4).all()
    
    return render_template(
        'trainings/detail.html',
        training=training,
        is_registered=is_registered,
        user_registration=user_registration,
        feedbacks=feedbacks,
        feedback_form=feedback_form,
        can_add_feedback=can_add_feedback,
        similar_trainings=similar_trainings,
        title=training.title
    )

@bp.route('/create', methods=['GET', 'POST'])
@login_required
@role_required(['trainer', 'admin'])
def create_training():
    """Создание новой тренировки"""
    form = TrainingForm()
    
    # Получение категорий для формы
    categories = TrainingCategory.query.filter_by(is_active=True).order_by(TrainingCategory.order).all()
    form.category_id.choices = [(c.id, c.name) for c in categories]
    
    if form.validate_on_submit():
        try:
            # Получение тренера
            if current_user.role == 'trainer':
                trainer = Trainer.query.filter_by(user_id=current_user.id).first()
                if not trainer:
                    flash('Профиль тренера не найден', 'danger')
                    return redirect(url_for('auth.trainer_profile'))
                trainer_id = trainer.id
            else:  # admin может выбрать любого тренера
                # В реальном приложении здесь был бы выбор тренера
                trainer = Trainer.query.first()
                trainer_id = trainer.id if trainer else None
            
            # Создание тренировки
            training = Training(
                title=form.title.data,
                description=form.description.data,
                short_description=form.short_description.data,
                trainer_id=trainer_id,
                category_id=form.category_id.data,
                schedule_time=form.schedule_time.data,
                duration=form.duration.data,
                timezone=form.timezone.data,
                training_type=form.training_type.data,
                difficulty=form.difficulty.data,
                intensity=form.intensity.data,
                max_participants=form.max_participants.data,
                min_participants=form.min_participants.data or 1,
                age_limit_min=form.age_limit_min.data,
                age_limit_max=form.age_limit_max.data,
                video_link=form.video_link.data,
                meeting_link=form.meeting_link.data,
                materials_link=form.materials_link.data,
                price=form.price.data or 0,
                currency=form.currency.data,
                medical_contraindications=form.medical_contraindications.data,
                required_equipment=form.required_equipment.data,
                tags=form.tags.data,
                keywords=form.keywords.data,
                language=form.language.data,
                status='pending'  # На модерации
            )
            
            db.session.add(training)
            db.session.flush()  # Получаем ID тренировки
            
            # Логирование создания
            AuditLog.log_action(
                user_id=current_user.id,
                action='training_create',
                resource_type='training',
                resource_id=training.id,
                details_after=training.to_dict(),
                request=request
            )
            
            # Создание уведомления для администраторов
            admins = User.query.filter_by(role='admin').all()
            for admin in admins:
                notification = Notification(
                    user_id=admin.id,
                    title='Новая тренировка на модерации',
                    message=f'Тренер {current_user.username} создал новую тренировку "{training.title}"',
                    notification_type='moderation',
                    action_url=url_for('admin.moderate_trainings', _external=True),
                    data=json.dumps({'training_id': training.id})
                )
                db.session.add(notification)
            
            db.session.commit()
            
            flash('Тренировка успешно создана и отправлена на модерацию!', 'success')
            return redirect(url_for('trainings.training_detail', training_id=training.id))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Training creation error: {str(e)}')
            flash('Ошибка при создании тренировки', 'danger')
    
    return render_template(
        'trainings/create.html',
        form=form,
        categories=categories,
        title='Создание тренировки'
    )

@bp.route('/<int:training_id>/edit', methods=['GET', 'POST'])
@login_required
def edit_training(training_id):
    """Редактирование тренировки"""
    training = Training.query.get_or_404(training_id)
    
    # Проверка прав доступа
    if not (current_user.role == 'admin' or 
            (current_user.role == 'trainer' and training.trainer.user_id == current_user.id)):
        flash('У вас нет прав для редактирования этой тренировки', 'danger')
        return redirect(url_for('trainings.training_detail', training_id=training_id))
    
    # Нельзя редактировать завершенные тренировки
    if training.is_past:
        flash('Нельзя редактировать завершенные тренировки', 'warning')
        return redirect(url_for('trainings.training_detail', training_id=training_id))
    
    form = TrainingForm(obj=training)
    
    # Получение категорий для формы
    categories = TrainingCategory.query.filter_by(is_active=True).order_by(TrainingCategory.order).all()
    form.category_id.choices = [(c.id, c.name) for c in categories]
    
    if form.validate_on_submit():
        try:
            # Сохранение старых данных для лога
            old_data = training.to_dict()
            
            # Обновление тренировки
            form.populate_obj(training)
            training.status = 'pending'  # Снова на модерацию после изменений
            training.updated_at = datetime.utcnow()
            
            # Логирование изменения
            AuditLog.log_action(
                user_id=current_user.id,
                action='training_update',
                resource_type='training',
                resource_id=training.id,
                details_before=old_data,
                details_after=training.to_dict(),
                request=request
            )
            
            db.session.commit()
            
            flash('Тренировка успешно обновлена и отправлена на модерацию', 'success')
            return redirect(url_for('trainings.training_detail', training_id=training.id))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Training update error: {str(e)}')
            flash('Ошибка при обновлении тренировки', 'danger')
    
    return render_template(
        'trainings/edit.html',
        form=form,
        training=training,
        categories=categories,
        title='Редактирование тренировки'
    )

@bp.route('/<int:training_id>/register', methods=['GET', 'POST'])
@login_required
def register_for_training(training_id):
    """Регистрация на тренировку"""
    training = Training.query.get_or_404(training_id)
    
    # Проверка доступности тренировки
    if training.status not in ['approved', 'active']:
        flash('Эта тренировка не доступна для регистрации', 'danger')
        return redirect(url_for('trainings.training_detail', training_id=training_id))
    
    if training.is_past:
        flash('Эта тренировка уже прошла', 'warning')
        return redirect(url_for('trainings.training_detail', training_id=training_id))
    
    # Проверка, не зарегистрирован ли уже пользователь
    existing_registration = TrainingRegistration.query.filter_by(
        user_id=current_user.id,
        training_id=training_id
    ).first()
    
    if existing_registration:
        if existing_registration.status == 'registered':
            flash('Вы уже зарегистрированы на эту тренировку', 'info')
            return redirect(url_for('trainings.training_detail', training_id=training_id))
        elif existing_registration.status == 'cancelled':
            # Позволяем повторную регистрацию после отмены
            db.session.delete(existing_registration)
            db.session.flush()
    
    form = TrainingRegistrationForm()
    
    if request.method == 'GET':
        # Основной бизнес-процесс регистрации
        
        # 1. Проверка накладки времени
        time_conflict_training = training.check_time_conflict(current_user.id)
        if time_conflict_training:
            flash(f'У вас уже есть тренировка в это время: {time_conflict_training.title}', 'danger')
            return redirect(url_for('trainings.training_detail', training_id=training_id))
        
        # 2. Проверка медицинских противопоказаний
        if training.check_medical_contraindications(current_user):
            flash('У вас есть медицинские противопоказания для этой тренировки', 'danger')
            return redirect(url_for('trainings.training_detail', training_id=training_id))
        
        # 3. Проверка возраста
        user_age = current_user.profile.get_age() if current_user.profile else None
        if user_age:
            if training.age_limit_min and user_age < training.age_limit_min:
                flash(f'Для этой тренировки минимальный возраст: {training.age_limit_min} лет', 'danger')
                return redirect(url_for('trainings.training_detail', training_id=training_id))
            
            if training.age_limit_max and user_age > training.age_limit_max:
                flash(f'Для этой тренировки максимальный возраст: {training.age_limit_max} лет', 'danger')
                return redirect(url_for('trainings.training_detail', training_id=training_id))
        
        # 4. Проверка свободных мест
        if training.is_full:
            flash('На эту тренировку нет свободных мест', 'warning')
            
            # Предложить запись в лист ожидания
            return render_template(
                'trainings/waitlist.html',
                training=training,
                form=form,
                title='Запись в лист ожидания'
            )
    
    if form.validate_on_submit():
        try:
            # Создание регистрации
            registration = TrainingRegistration(
                user_id=current_user.id,
                training_id=training_id,
                status='registered',
                registration_type=form.registration_type.data,
                notes=form.notes.data
            )
            
            db.session.add(registration)
            
            # Обновление счетчика регистраций
            training.registrations_count += 1
            
            # Создание уведомления
            notification = Notification(
                user_id=current_user.id,
                title='Вы записались на тренировку!',
                message=f'Вы успешно записались на тренировку "{training.title}"',
                notification_type='registration',
                action_url=url_for('trainings.training_detail', training_id=training_id, _external=True),
                data=json.dumps({
                    'training_id': training_id,
                    'training_title': training.title,
                    'schedule_time': training.schedule_time.isoformat()
                })
            )
            db.session.add(notification)
            
            # Логирование регистрации
            AuditLog.log_action(
                user_id=current_user.id,
                action='training_registration',
                resource_type='training_registration',
                resource_id=training_id,
                details_after={
                    'training_id': training_id,
                    'registration_type': form.registration_type.data
                },
                request=request
            )
            
            db.session.commit()
            
            flash('Вы успешно зарегистрировались на тренировку!', 'success')
            return redirect(url_for('trainings.training_detail', training_id=training_id))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Training registration error: {str(e)}')
            flash('Ошибка при регистрации на тренировку', 'danger')
    
    return render_template(
        'trainings/register.html',
        training=training,
        form=form,
        title='Регистрация на тренировку'
    )

@bp.route('/<int:training_id>/cancel-registration', methods=['POST'])
@login_required
def cancel_registration(training_id):
    """Отмена регистрации на тренировку"""
    registration = TrainingRegistration.query.filter_by(
        user_id=current_user.id,
        training_id=training_id,
        status='registered'
    ).first_or_404()
    
    training = registration.training
    
    # Проверка возможности отмены
    if not registration.can_be_cancelled:
        flash('Регистрацию нельзя отменить менее чем за 1 час до начала тренировки', 'danger')
        return redirect(url_for('trainings.training_detail', training_id=training_id))
    
    try:
        registration.cancel('Отмена пользователем')
        
        # Обновление счетчика регистраций
        training.registrations_count = max(0, training.registrations_count - 1)
        
        # Создание уведомления
        notification = Notification(
            user_id=current_user.id,
            title='Регистрация отменена',
            message=f'Вы отменили регистрацию на тренировку "{training.title}"',
            notification_type='cancellation',
            action_url=url_for('trainings.training_list', _external=True)
        )
        db.session.add(notification)
        
        # Логирование отмены
        AuditLog.log_action(
            user_id=current_user.id,
            action='training_registration_cancel',
            resource_type='training_registration',
            resource_id=registration.id,
            request=request
        )
        
        db.session.commit()
        
        flash('Регистрация на тренировку успешно отменена', 'success')
        
    except Exception as e:
        db.session.rollback()
        logger.error(f'Registration cancellation error: {str(e)}')
        flash('Ошибка при отмене регистрации', 'danger')
    
    return redirect(url_for('trainings.training_detail', training_id=training_id))

@bp.route('/my-trainings')
@login_required
def my_trainings():
    """Мои тренировки"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 10, type=int)
    status_filter = request.args.get('status', 'all')
    
    # Базовый запрос
    query = TrainingRegistration.query.filter_by(user_id=current_user.id)
    
    # Фильтр по статусу
    if status_filter == 'upcoming':
        query = query.filter_by(status='registered').join(Training).filter(
            Training.schedule_time > datetime.utcnow()
        )
    elif status_filter == 'past':
        query = query.filter_by(status='attended').join(Training).filter(
            Training.schedule_time <= datetime.utcnow()
        )
    elif status_filter == 'cancelled':
        query = query.filter_by(status='cancelled')
    
    # Сортировка по времени тренировки
    query = query.join(Training).order_by(Training.schedule_time.desc())
    
    registrations = query.paginate(page=page, per_page=per_page, error_out=False)
    
    # Статистика
    stats = {
        'total': TrainingRegistration.query.filter_by(user_id=current_user.id).count(),
        'upcoming': TrainingRegistration.query.filter_by(
            user_id=current_user.id, status='registered'
        ).join(Training).filter(Training.schedule_time > datetime.utcnow()).count(),
        'attended': TrainingRegistration.query.filter_by(
            user_id=current_user.id, status='attended'
        ).count(),
        'cancelled': TrainingRegistration.query.filter_by(
            user_id=current_user.id, status='cancelled'
        ).count()
    }
    
    return render_template(
        'trainings/my_trainings.html',
        registrations=registrations,
        stats=stats,
        status_filter=status_filter,
        title='Мои тренировки'
    )

@bp.route('/api/trainings/calendar')
@login_required
def training_calendar():
    """API для календаря тренировок"""
    start_date = request.args.get('start', type=lambda x: datetime.strptime(x, '%Y-%m-%d'))
    end_date = request.args.get('end', type=lambda x: datetime.strptime(x, '%Y-%m-%d'))
    
    if not start_date or not end_date:
        return jsonify({'error': 'Не указаны даты'}), 400
    
    # Тренировки пользователя
    registrations = TrainingRegistration.query.filter_by(
        user_id=current_user.id,
        status='registered'
    ).join(Training).filter(
        Training.schedule_time.between(start_date, end_date),
        Training.status.in_(['approved', 'active'])
    ).all()
    
    events = []
    for reg in registrations:
        training = reg.training
        events.append({
            'id': training.id,
            'title': training.title,
            'start': training.schedule_time.isoformat(),
            'end': (training.schedule_time + timedelta(minutes=training.duration)).isoformat(),
            'url': url_for('trainings.training_detail', training_id=training.id),
            'color': '#3788d8' if training.training_type == 'group' else '#28a745',
            'extendedProps': {
                'type': training.training_type,
                'trainer': training.trainer.user.full_name,
                'difficulty': training.difficulty
            }
        })
    
    # Если пользователь тренер, добавляем его тренировки
    if current_user.role == 'trainer':
        trainer = Trainer.query.filter_by(user_id=current_user.id).first()
        if trainer:
            trainer_trainings = Training.query.filter(
                Training.trainer_id == trainer.id,
                Training.schedule_time.between(start_date, end_date),
                Training.status.in_(['approved', 'active'])
            ).all()
            
            for training in trainer_trainings:
                events.append({
                    'id': f"trainer_{training.id}",
                    'title': f"[Тренер] {training.title}",
                    'start': training.schedule_time.isoformat(),
                    'end': (training.schedule_time + timedelta(minutes=training.duration)).isoformat(),
                    'url': url_for('trainings.training_detail', training_id=training.id),
                    'color': '#ffc107',
                    'extendedProps': {
                        'type': training.training_type,
                        'participants': training.registrations_count,
                        'is_trainer': True
                    }
                })
    
    return jsonify(events)

@bp.route('/api/trainings/<int:training_id>/check-in', methods=['POST'])
@login_required
def check_in_to_training(training_id):
    """Отметка посещения тренировки (API)"""
    registration = TrainingRegistration.query.filter_by(
        user_id=current_user.id,
        training_id=training_id,
        status='registered'
    ).first_or_404()
    
    training = registration.training
    
    # Проверка времени
    if training.schedule_time > datetime.utcnow():
        return jsonify({
            'success': False,
            'message': 'Тренировка еще не началась'
        }), 400
    
    if not registration.is_attendance_possible():
        return jsonify({
            'success': False,
            'message': 'Время для отметки посещения истекло'
        }), 400
    
    try:
        registration.mark_attended()
        
        # Создание уведомления
        notification = Notification(
            user_id=current_user.id,
            title='Тренировка завершена!',
            message=f'Вы отметили посещение тренировки "{training.title}"',
            notification_type='attendance',
            action_url=url_for('trainings.training_detail', training_id=training_id, _external=True)
        )
        db.session.add(notification)
        
        # Логирование
        AuditLog.log_action(
            user_id=current_user.id,
            action='training_check_in',
            resource_type='training_registration',
            resource_id=registration.id,
            request=request
        )
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Посещение успешно отмечено'
        })
        
    except Exception as e:
        db.session.rollback()
        logger.error(f'Check-in error: {str(e)}')
        return jsonify({
            'success': False,
            'message': 'Ошибка при отметке посещения'
        }), 500
'@
New-Item -ItemType File -Path "app/routes/trainings.py" -Value $trainingsRoutes -Force | Out-Null

# app/routes/progress.py
$progressRoutes = @'
"""
Маршруты для отслеживания прогресса
"""

from flask import Blueprint, render_template, redirect, url_for, flash, request, jsonify, current_app
from flask_login import login_required, current_user
from sqlalchemy import func, desc, extract
from datetime import datetime, date, timedelta
import logging
import json

from app import db
from app.forms.progress import ProgressEntryForm, GoalForm, ProgressFilterForm
from app.models import Progress, Goal, Achievement, ProgressMetric, TrainingRegistration
from app.utils.decorators import role_required

bp = Blueprint('progress', __name__, url_prefix='/progress')

# Настройка логирования
logger = logging.getLogger(__name__)

@bp.route('/')
@login_required
def dashboard():
    """Дашборд прогресса пользователя"""
    
    # Получение временных диапазонов
    today = date.today()
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)
    year_ago = today - timedelta(days=365)
    
    # Общая статистика
    total_activities = Progress.query.filter_by(user_id=current_user.id).count()
    total_calories = db.session.query(func.coalesce(func.sum(Progress.calories_burned), 0)).filter(
        Progress.user_id == current_user.id
    ).scalar()
    total_distance = db.session.query(func.coalesce(func.sum(Progress.distance), 0)).filter(
        Progress.user_id == current_user.id
    ).scalar()
    total_duration = db.session.query(func.coalesce(func.sum(Progress.duration), 0)).filter(
        Progress.user_id == current_user.id
    ).scalar()
    
    # Статистика за последнюю неделю
    week_stats = db.session.query(
        func.count(Progress.id).label('activities'),
        func.coalesce(func.sum(Progress.calories_burned), 0).label('calories'),
        func.coalesce(func.sum(Progress.distance), 0).label('distance'),
        func.coalesce(func.sum(Progress.duration), 0).label('duration')
    ).filter(
        Progress.user_id == current_user.id,
        Progress.date >= week_ago
    ).first()
    
    # Последние активности
    recent_activities = Progress.query.filter_by(
        user_id=current_user.id
    ).order_by(Progress.date.desc(), Progress.created_at.desc()).limit(5).all()
    
    # Цели
    active_goals = Goal.query.filter_by(
        user_id=current_user.id,
        status='active'
    ).order_by(Goal.target_date).limit(5).all()
    
    # Достижения
    recent_achievements = Achievement.query.filter_by(
        user_id=current_user.id
    ).order_by(Achievement.unlocked_at.desc() if Achievement.unlocked_at else Achievement.created_at.desc()).limit(5).all()
    
    # График активности за последний месяц
    monthly_activities = db.session.query(
        Progress.date,
        func.count(Progress.id).label('count'),
        func.coalesce(func.sum(Progress.duration), 0).label('duration'),
        func.coalesce(func.sum(Progress.calories_burned), 0).label('calories')
    ).filter(
        Progress.user_id == current_user.id,
        Progress.date >= month_ago
    ).group_by(Progress.date).order_by(Progress.date).all()
    
    # Подготовка данных для графика
    chart_labels = [a.date.strftime('%d.%m') for a in monthly_activities]
    chart_duration = [a.duration for a in monthly_activities]
    chart_calories = [a.calories for a in monthly_activities]
    
    return render_template(
        'progress/dashboard.html',
        total_activities=total_activities,
        total_calories=total_calories,
        total_distance=total_distance,
        total_duration=total_duration,
        week_stats=week_stats,
        recent_activities=recent_activities,
        active_goals=active_goals,
        recent_achievements=recent_achievements,
        chart_labels=chart_labels,
        chart_duration=chart_duration,
        chart_calories=chart_calories,
        title='Мой прогресс'
    )

@bp.route('/add', methods=['GET', 'POST'])
@login_required
def add_progress():
    """Добавление записи о прогрессе"""
    form = ProgressEntryForm()
    
    if form.validate_on_submit():
        try:
            # Проверка существующей записи на эту дату
            existing_entry = Progress.query.filter_by(
                user_id=current_user.id,
                date=form.date.data,
                activity_type=form.activity_type.data
            ).first()
            
            if existing_entry:
                flash('Запись с таким типом активности на эту дату уже существует', 'warning')
                return redirect(url_for('progress.add_progress'))
            
            # Создание записи
            progress = Progress(
                user_id=current_user.id,
                date=form.date.data,
                activity_type=form.activity_type.data,
                duration=form.duration.data,
                calories_burned=form.calories_burned.data,
                distance=form.distance.data,
                weight=form.weight.data,
                body_fat_percentage=form.body_fat_percentage.data,
                muscle_mass=form.muscle_mass.data,
                resting_heart_rate=form.resting_heart_rate.data,
                blood_pressure_systolic=form.blood_pressure_systolic.data,
                blood_pressure_diastolic=form.blood_pressure_diastolic.data,
                sleep_duration=form.sleep_duration.data,
                sleep_quality=form.sleep_quality.data,
                energy_level=form.energy_level.data,
                mood=form.mood.data,
                stress_level=form.stress_level.data,
                notes=form.notes.data,
                location=form.location.data,
                weather=form.weather.data,
                source=form.source.data
            )
            
            db.session.add(progress)
            db.session.commit()
            
            # Проверка достижения целей
            check_goals_for_progress(progress)
            
            flash('Запись о прогрессе успешно добавлена!', 'success')
            return redirect(url_for('progress.dashboard'))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Progress entry creation error: {str(e)}')
            flash('Ошибка при добавлении записи о прогрессе', 'danger')
    
    return render_template(
        'progress/add.html',
        form=form,
        title='Добавить запись о прогрессе'
    )

@bp.route('/history')
@login_required
def history():
    """История прогресса"""
    form = ProgressFilterForm(request.args)
    
    # Базовый запрос
    query = Progress.query.filter_by(user_id=current_user.id)
    
    # Применение фильтров
    if form.date_from.data:
        query = query.filter(Progress.date >= form.date_from.data)
    
    if form.date_to.data:
        query = query.filter(Progress.date <= form.date_to.data)
    
    if form.activity_type.data:
        query = query.filter_by(activity_type=form.activity_type.data)
    
    if form.min_duration.data is not None:
        query = query.filter(Progress.duration >= form.min_duration.data)
    
    if form.max_duration.data is not None:
        query = query.filter(Progress.duration <= form.max_duration.data)
    
    if form.min_calories.data is not None:
        query = query.filter(Progress.calories_burned >= form.min_calories.data)
    
    if form.max_calories.data is not None:
        query = query.filter(Progress.calories_burned <= form.max_calories.data)
    
    if form.min_distance.data is not None:
        query = query.filter(Progress.distance >= form.min_distance.data)
    
    if form.max_distance.data is not None:
        query = query.filter(Progress.distance <= form.max_distance.data)
    
    # Сортировка
    sort_column = {
        'date': Progress.date,
        'duration': Progress.duration,
        'calories_burned': Progress.calories_burned,
        'distance': Progress.distance
    }.get(form.sort_by.data, Progress.date)
    
    if form.sort_order.data == 'desc':
        sort_column = sort_column.desc()
    
    query = query.order_by(sort_column)
    
    # Пагинация
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    progress_entries = query.paginate(page=page, per_page=per_page, error_out=False)
    
    # Статистика по фильтру
    stats = {
        'count': query.count(),
        'total_duration': db.session.query(func.coalesce(func.sum(Progress.duration), 0)).filter(
            Progress.user_id == current_user.id,
            *query.whereclause
        ).scalar(),
        'total_calories': db.session.query(func.coalesce(func.sum(Progress.calories_burned), 0)).filter(
            Progress.user_id == current_user.id,
            *query.whereclause
        ).scalar(),
        'total_distance': db.session.query(func.coalesce(func.sum(Progress.distance), 0)).filter(
            Progress.user_id == current_user.id,
            *query.whereclause
        ).scalar()
    }
    
    return render_template(
        'progress/history.html',
        progress_entries=progress_entries,
        form=form,
        stats=stats,
        title='История прогресса'
    )

@bp.route('/goals')
@login_required
def goals():
    """Цели пользователя"""
    status_filter = request.args.get('status', 'active')
    
    # Базовый запрос
    query = Goal.query.filter_by(user_id=current_user.id)
    
    # Фильтр по статусу
    if status_filter != 'all':
        query = query.filter_by(status=status_filter)
    
    # Сортировка
    query = query.order_by(
        Goal.status,
        Goal.target_date,
        Goal.created_at.desc()
    )
    
    goals_list = query.all()
    
    # Статистика по целям
    stats = {
        'total': Goal.query.filter_by(user_id=current_user.id).count(),
        'active': Goal.query.filter_by(user_id=current_user.id, status='active').count(),
        'completed': Goal.query.filter_by(user_id=current_user.id, status='completed').count(),
        'failed': Goal.query.filter_by(user_id=current_user.id, status='failed').count(),
        'average_progress': db.session.query(func.avg(Goal.progress_percentage)).filter(
            Goal.user_id == current_user.id,
            Goal.status == 'active'
        ).scalar() or 0
    }
    
    return render_template(
        'progress/goals.html',
        goals=goals_list,
        status_filter=status_filter,
        stats=stats,
        title='Мои цели'
    )

@bp.route('/goals/add', methods=['GET', 'POST'])
@login_required
def add_goal():
    """Добавление новой цели"""
    form = GoalForm()
    
    if form.validate_on_submit():
        try:
            goal = Goal(
                user_id=current_user.id,
                title=form.title.data,
                description=form.description.data,
                goal_type=form.goal_type.data,
                target_value=form.target_value.data,
                unit=form.unit.data,
                start_date=form.start_date.data,
                target_date=form.target_date.data,
                is_recurring=form.is_recurring.data,
                recurrence_pattern=form.recurrence_pattern.data if form.is_recurring.data else None,
                motivation=form.motivation.data,
                rewards=form.rewards.data,
                reminder_enabled=form.reminder_enabled.data,
                reminder_frequency=form.reminder_frequency.data if form.reminder_enabled.data else None,
                status='active'
            )
            
            db.session.add(goal)
            db.session.commit()
            
            flash('Цель успешно добавлена!', 'success')
            return redirect(url_for('progress.goals'))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Goal creation error: {str(e)}')
            flash('Ошибка при добавлении цели', 'danger')
    
    return render_template(
        'progress/add_goal.html',
        form=form,
        title='Добавить цель'
    )

@bp.route('/goals/<int:goal_id>')
@login_required
def goal_detail(goal_id):
    """Детальная информация о цели"""
    goal = Goal.query.get_or_404(goal_id)
    
    # Проверка прав доступа
    if goal.user_id != current_user.id:
        flash('У вас нет прав для просмотра этой цели', 'danger')
        return redirect(url_for('progress.goals'))
    
    # Прогресс по цели
    progress_entries = Progress.query.filter_by(
        user_id=current_user.id
    ).filter(
        Progress.date.between(goal.start_date, goal.target_date)
    ).order_by(Progress.date).all()
    
    # Рассчет прогресса на основе данных
    if goal.goal_type == 'weight_loss' and goal.target_value:
        current_weight = Progress.query.filter_by(
            user_id=current_user.id
        ).filter(
            Progress.weight.isnot(None),
            Progress.date <= date.today()
        ).order_by(Progress.date.desc()).first()
        
        if current_weight and current_weight.weight:
            goal.current_value = current_weight.weight
            goal.update_progress()
    
    return render_template(
        'progress/goal_detail.html',
        goal=goal,
        progress_entries=progress_entries,
        title=goal.title
    )

@bp.route('/goals/<int:goal_id>/update-progress', methods=['POST'])
@login_required
def update_goal_progress(goal_id):
    """Обновление прогресса цели"""
    goal = Goal.query.get_or_404(goal_id)
    
    # Проверка прав доступа
    if goal.user_id != current_user.id:
        return jsonify({'success': False, 'message': 'Доступ запрещен'}), 403
    
    try:
        new_value = request.json.get('current_value')
        if new_value is not None:
            goal.current_value = float(new_value)
            goal.update_progress()
            db.session.commit()
            
            return jsonify({
                'success': True,
                'progress_percentage': goal.progress_percentage,
                'is_on_track': goal.is_on_track()
            })
        else:
            return jsonify({'success': False, 'message': 'Не указано значение'}), 400
            
    except Exception as e:
        db.session.rollback()
        logger.error(f'Goal progress update error: {str(e)}')
        return jsonify({'success': False, 'message': 'Ошибка при обновлении прогресса'}), 500

@bp.route('/achievements')
@login_required
def achievements():
    """Достижения пользователя"""
    achievements_list = Achievement.query.filter_by(
        user_id=current_user.id
    ).order_by(
        Achievement.unlocked_at.desc() if Achievement.unlocked_at else Achievement.created_at.desc()
    ).all()
    
    # Группировка по типу
    achievements_by_type = {}
    for achievement in achievements_list:
        if achievement.achievement_type not in achievements_by_type:
            achievements_by_type[achievement.achievement_type] = []
        achievements_by_type[achievement.achievement_type].append(achievement)
    
    # Общая статистика
    total_points = db.session.query(func.sum(Achievement.points)).filter(
        Achievement.user_id == current_user.id
    ).scalar() or 0
    
    total_achievements = len(achievements_list)
    
    return render_template(
        'progress/achievements.html',
        achievements_by_type=achievements_by_type,
        total_points=total_points,
        total_achievements=total_achievements,
        title='Мои достижения'
    )

@bp.route('/statistics')
@login_required
def statistics():
    """Подробная статистика"""
    # Временные диапазоны
    today = date.today()
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)
    year_ago = today - timedelta(days=365)
    
    # Агрегированная статистика по типам активности
    activity_stats = db.session.query(
        Progress.activity_type,
        func.count(Progress.id).label('count'),
        func.coalesce(func.sum(Progress.duration), 0).label('total_duration'),
        func.coalesce(func.sum(Progress.calories_burned), 0).label('total_calories'),
        func.coalesce(func.sum(Progress.distance), 0).label('total_distance')
    ).filter(
        Progress.user_id == current_user.id,
        Progress.date >= month_ago
    ).group_by(Progress.activity_type).all()
    
    # Еженедельная активность
    weekly_data = []
    for i in range(12):  # Последние 12 недель
        week_start = today - timedelta(weeks=i+1)
        week_end = today - timedelta(weeks=i)
        
        week_stats = db.session.query(
            func.coalesce(func.sum(Progress.duration), 0).label('duration'),
            func.coalesce(func.sum(Progress.calories_burned), 0).label('calories')
        ).filter(
            Progress.user_id == current_user.id,
            Progress.date.between(week_start, week_end)
        ).first()
        
        weekly_data.append({
            'week': week_start.strftime('%d.%m'),
            'duration': week_stats.duration,
            'calories': week_stats.calories
        })
    
    weekly_data.reverse()  # От старых к новым
    
    # Тренды веса (если есть данные)
    weight_data = Progress.query.filter(
        Progress.user_id == current_user.id,
        Progress.weight.isnot(None)
    ).order_by(Progress.date).all()
    
    weight_trend = [{'date': w.date.strftime('%d.%m'), 'weight': w.weight} for w in weight_data]
    
    # Лучшие результаты
    best_duration = Progress.query.filter_by(user_id=current_user.id).order_by(
        Progress.duration.desc()
    ).first()
    
    best_calories = Progress.query.filter_by(user_id=current_user.id).order_by(
        Progress.calories_burned.desc()
    ).first()
    
    best_distance = Progress.query.filter_by(user_id=current_user.id).order_by(
        Progress.distance.desc()
    ).first()
    
    return render_template(
        'progress/statistics.html',
        activity_stats=activity_stats,
        weekly_data=weekly_data,
        weight_trend=weight_trend,
        best_duration=best_duration,
        best_calories=best_calories,
        best_distance=best_distance,
        title='Статистика'
    )

@bp.route('/api/chart-data')
@login_required
def chart_data():
    """API данных для графиков"""
    chart_type = request.args.get('type', 'weekly')
    
    if chart_type == 'weekly':
        # Данные за последние 4 недели
        data = []
        for i in range(4):
            week_start = date.today() - timedelta(weeks=i+1)
            week_end = date.today() - timedelta(weeks=i)
            
            week_stats = db.session.query(
                func.coalesce(func.sum(Progress.duration), 0).label('duration'),
                func.coalesce(func.sum(Progress.calories_burned), 0).label('calories'),
                func.coalesce(func.sum(Progress.distance), 0).label('distance')
            ).filter(
                Progress.user_id == current_user.id,
                Progress.date.between(week_start, week_end)
            ).first()
            
            data.append({
                'week': week_start.strftime('%d.%m'),
                'duration': week_stats.duration,
                'calories': week_stats.calories,
                'distance': week_stats.distance
            })
        
        data.reverse()
        return jsonify(data)
    
    elif chart_type == 'activity_types':
        # Распределение по типам активности
        stats = db.session.query(
            Progress.activity_type,
            func.count(Progress.id).label('count'),
            func.coalesce(func.sum(Progress.duration), 0).label('duration')
        ).filter(
            Progress.user_id == current_user.id,
            Progress.date >= date.today() - timedelta(days=30)
        ).group_by(Progress.activity_type).all()
        
        data = [{
            'type': stat.activity_type,
            'count': stat.count,
            'duration': stat.duration
        } for stat in stats]
        
        return jsonify(data)
    
    elif chart_type == 'weight_trend':
        # Тренд веса
        weight_data = Progress.query.filter(
            Progress.user_id == current_user.id,
            Progress.weight.isnot(None)
        ).order_by(Progress.date).all()
        
        data = [{
            'date': w.date.strftime('%Y-%m-%d'),
            'weight': w.weight
        } for w in weight_data]
        
        return jsonify(data)
    
    return jsonify({'error': 'Неизвестный тип графика'}), 400

def check_goals_for_progress(progress):
    """Проверка достижения целей на основе новой записи о прогрессе"""
    try:
        # Получение активных целей пользователя
        active_goals = Goal.query.filter_by(
            user_id=progress.user_id,
            status='active'
        ).all()
        
        for goal in active_goals:
            # Проверка соответствия типа цели типу активности
            if (goal.goal_type == 'running_distance' and progress.activity_type == 'running') or \
               (goal.goal_type == 'cycling_distance' and progress.activity_type == 'cycling') or \
               (goal.goal_type == 'calorie_burn' and progress.calories_burned) or \
               (goal.goal_type == 'weight_loss' and progress.weight):
                
                # Обновление текущего значения
                if goal.goal_type == 'running_distance' or goal.goal_type == 'cycling_distance':
                    if progress.distance:
                        goal.current_value += progress.distance
                elif goal.goal_type == 'calorie_burn':
                    if progress.calories_burned:
                        goal.current_value += progress.calories_burned
                elif goal.goal_type == 'weight_loss':
                    if progress.weight:
                        goal.current_value = progress.weight
                
                goal.update_progress()
                
                # Проверка достижения цели
                if goal.progress_percentage >= 100:
                    create_achievement_for_goal(goal)
        
        db.session.commit()
        
    except Exception as e:
        logger.error(f'Goals check error: {str(e)}')

def create_achievement_for_goal(goal):
    """Создание достижения при выполнении цели"""
    try:
        achievement = Achievement(
            user_id=goal.user_id,
            goal_id=goal.id,
            title=f'Цель достигнута: {goal.title}',
            description=f'Вы достигли цели "{goal.title}"!',
            achievement_type='goal_completion',
            points=100,
            icon='??',
            unlocked_at=datetime.utcnow()
        )
        
        db.session.add(achievement)
        
    except Exception as e:
        logger.error(f'Achievement creation error: {str(e)}')
'@
New-Item -ItemType File -Path "app/routes/progress.py" -Value $progressRoutes -Force | Out-Null

Write-Host "  Созданы основные маршруты" -ForegroundColor DarkGreen

# 5. Статические файлы и шаблоны
Write-Host "`nСоздание статических файлов и шаблонов..." -ForegroundColor Cyan

# app/static/css/main.css
$mainCss = @'
/* Основные стили для фитнес-платформы */

:root {
    /* Основные цвета */
    --primary-color: #4a6fa5;
    --primary-dark: #3a5a8c;
    --primary-light: #6b8cc0;
    --secondary-color: #ff7e5f;
    --secondary-dark: #e66b4a;
    --secondary-light: #ff9e8a;
    
    /* Дополнительные цвета */
    --success-color: #28a745;
    --info-color: #17a2b8;
    --warning-color: #ffc107;
    --danger-color: #dc3545;
    
    /* Нейтральные цвета */
    --light-color: #f8f9fa;
    --dark-color: #343a40;
    --gray-100: #f8f9fa;
    --gray-200: #e9ecef;
    --gray-300: #dee2e6;
    --gray-400: #ced4da;
    --gray-500: #adb5bd;
    --gray-600: #6c757d;
    --gray-700: #495057;
    --gray-800: #343a40;
    --gray-900: #212529;
    
    /* Тени */
    --shadow-sm: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
    --shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15);
    --shadow-lg: 0 1rem 3rem rgba(0, 0, 0, 0.175);
    
    /* Скругления */
    --border-radius: 0.375rem;
    --border-radius-lg: 0.5rem;
    --border-radius-xl: 1rem;
    
    /* Отступы */
    --spacing-xs: 0.25rem;
    --spacing-sm: 0.5rem;
    --spacing: 1rem;
    --spacing-lg: 1.5rem;
    --spacing-xl: 3rem;
    
    /* Анимации */
    --transition-fast: 150ms ease-in-out;
    --transition: 250ms ease-in-out;
    --transition-slow: 350ms ease-in-out;
}

/* Общие стили */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', 'Roboto', 'Helvetica Neue', Arial, sans-serif;
    font-size: 1rem;
    line-height: 1.6;
    color: var(--gray-800);
    background-color: #f5f7fa;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
}

.container {
    width: 100%;
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 var(--spacing);
}

/* Навигация */
.navbar {
    background: linear-gradient(135deg, var(--primary-color), var(--primary-dark));
    box-shadow: var(--shadow);
    padding: 0.75rem 0;
}

.navbar-brand {
    font-size: 1.5rem;
    font-weight: 700;
    color: white !important;
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.navbar-brand i {
    font-size: 1.75rem;
}

.nav-link {
    color: rgba(255, 255, 255, 0.9) !important;
    font-weight: 500;
    padding: 0.5rem 1rem !important;
    border-radius: var(--border-radius);
    transition: all var(--transition-fast);
}

.nav-link:hover,
.nav-link.active {
    color: white !important;
    background-color: rgba(255, 255, 255, 0.1);
}

/* Кнопки */
.btn {
    padding: 0.5rem 1.5rem;
    border-radius: var(--border-radius);
    font-weight: 500;
    transition: all var(--transition-fast);
    border: none;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
}

.btn-primary {
    background: linear-gradient(135deg, var(--primary-color), var(--primary-dark));
    color: white;
    border: none;
}

.btn-primary:hover {
    background: linear-gradient(135deg, var(--primary-dark), var(--primary-color));
    transform: translateY(-2px);
    box-shadow: var(--shadow);
}

.btn-success {
    background: linear-gradient(135deg, var(--success-color), #218838);
    color: white;
}

.btn-danger {
    background: linear-gradient(135deg, var(--danger-color), #c82333);
    color: white;
}

.btn-outline-primary {
    border: 2px solid var(--primary-color);
    color: var(--primary-color);
    background: transparent;
}

.btn-outline-primary:hover {
    background-color: var(--primary-color);
    color: white;
}

/* Карточки */
.card {
    background: white;
    border-radius: var(--border-radius-lg);
    box-shadow: var(--shadow-sm);
    border: none;
    overflow: hidden;
    transition: all var(--transition);
    margin-bottom: var(--spacing);
}

.card:hover {
    transform: translateY(-4px);
    box-shadow: var(--shadow);
}

.card-header {
    background: linear-gradient(135deg, var(--primary-color), var(--primary-dark));
    color: white;
    padding: 1rem 1.5rem;
    border-bottom: none;
}

.card-body {
    padding: 1.5rem;
}

.card-title {
    font-size: 1.25rem;
    font-weight: 600;
    margin-bottom: 0.75rem;
    color: var(--gray-800);
}

.card-text {
    color: var(--gray-600);
    margin-bottom: 1rem;
}

/* Формы */
.form-control {
    padding: 0.75rem 1rem;
    border: 1px solid var(--gray-300);
    border-radius: var(--border-radius);
    font-size: 1rem;
    transition: all var(--transition-fast);
}

.form-control:focus {
    border-color: var(--primary-color);
    box-shadow: 0 0 0 0.2rem rgba(74, 111, 165, 0.25);
    outline: none;
}

.form-label {
    font-weight: 500;
    color: var(--gray-700);
    margin-bottom: 0.5rem;
}

.form-text {
    color: var(--gray-600);
    font-size: 0.875rem;
}

/* Алерты */
.alert {
    padding: 1rem 1.5rem;
    border-radius: var(--border-radius);
    border: none;
    margin-bottom: var(--spacing);
}

.alert-success {
    background-color: #d4edda;
    color: #155724;
    border-left: 4px solid var(--success-color);
}

.alert-danger {
    background-color: #f8d7da;
    color: #721c24;
    border-left: 4px solid var(--danger-color);
}

.alert-warning {
    background-color: #fff3cd;
    color: #856404;
    border-left: 4px solid var(--warning-color);
}

.alert-info {
    background-color: #d1ecf1;
    color: #0c5460;
    border-left: 4px solid var(--info-color);
}

/* Таблицы */
.table {
    width: 100%;
    margin-bottom: var(--spacing);
    background-color: white;
    border-radius: var(--border-radius);
    overflow: hidden;
    box-shadow: var(--shadow-sm);
}

.table th {
    background-color: var(--gray-100);
    color: var(--gray-700);
    font-weight: 600;
    padding: 1rem;
    border-bottom: 2px solid var(--gray-300);
}

.table td {
    padding: 1rem;
    border-bottom: 1px solid var(--gray-200);
    vertical-align: middle;
}

.table tr:hover {
    background-color: var(--gray-50);
}

/* Прогресс-бары */
.progress {
    height: 0.75rem;
    background-color: var(--gray-200);
    border-radius: 0.375rem;
    overflow: hidden;
    margin-bottom: var(--spacing);
}

.progress-bar {
    background: linear-gradient(90deg, var(--primary-color), var(--primary-light));
    height: 100%;
    border-radius: 0.375rem;
    transition: width 0.6s ease;
}

/* Аватары */
.avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    object-fit: cover;
    border: 2px solid var(--gray-300);
}

.avatar-sm {
    width: 32px;
    height: 32px;
}

.avatar-lg {
    width: 64px;
    height: 64px;
}

/* Бейджи */
.badge {
    display: inline-block;
    padding: 0.25rem 0.5rem;
    font-size: 0.75rem;
    font-weight: 600;
    line-height: 1;
    text-align: center;
    white-space: nowrap;
    vertical-align: baseline;
    border-radius: 0.375rem;
}

.badge-primary {
    background-color: var(--primary-color);
    color: white;
}

.badge-success {
    background-color: var(--success-color);
    color: white;
}

.badge-warning {
    background-color: var(--warning-color);
    color: var(--dark-color);
}

.badge-danger {
    background-color: var(--danger-color);
    color: white;
}

/* Пагинация */
.pagination {
    display: flex;
    justify-content: center;
    gap: 0.5rem;
    margin-top: var(--spacing);
}

.page-item.active .page-link {
    background-color: var(--primary-color);
    border-color: var(--primary-color);
}

.page-link {
    color: var(--primary-color);
    border: 1px solid var(--gray-300);
    padding: 0.5rem 0.75rem;
    border-radius: var(--border-radius);
}

.page-link:hover {
    background-color: var(--gray-100);
    color: var(--primary-dark);
}

/* Футер */
.footer {
    background: linear-gradient(135deg, var(--gray-800), var(--gray-900));
    color: white;
    padding: 3rem 0 2rem;
    margin-top: auto;
}

.footer h5 {
    color: white;
    margin-bottom: 1.5rem;
    font-size: 1.125rem;
}

.footer a {
    color: rgba(255, 255, 255, 0.8);
    text-decoration: none;
    transition: color var(--transition-fast);
}

.footer a:hover {
    color: white;
}

.footer-bottom {
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    padding-top: 1.5rem;
    margin-top: 2rem;
    text-align: center;
    color: rgba(255, 255, 255, 0.6);
}

/* Утилиты */
.text-center { text-align: center; }
.text-right { text-align: right; }
.text-left { text-align: left; }

.mt-1 { margin-top: 0.25rem; }
.mt-2 { margin-top: 0.5rem; }
.mt-3 { margin-top: 1rem; }
.mt-4 { margin-top: 1.5rem; }
.mt-5 { margin-top: 3rem; }

.mb-1 { margin-bottom: 0.25rem; }
.mb-2 { margin-bottom: 0.5rem; }
.mb-3 { margin-bottom: 1rem; }
.mb-4 { margin-bottom: 1.5rem; }
.mb-5 { margin-bottom: 3rem; }

.p-1 { padding: 0.25rem; }
.p-2 { padding: 0.5rem; }
.p-3 { padding: 1rem; }
.p-4 { padding: 1.5rem; }
.p-5 { padding: 3rem; }

.d-flex { display: flex; }
.align-items-center { align-items: center; }
.justify-content-between { justify-content: space-between; }
.justify-content-center { justify-content: center; }

.gap-1 { gap: 0.25rem; }
.gap-2 { gap: 0.5rem; }
.gap-3 { gap: 1rem; }
.gap-4 { gap: 1.5rem; }

/* Анимации */
@keyframes fadeIn {
    from { opacity: 0; transform: translateY(20px); }
    to { opacity: 1; transform: translateY(0); }
}

.fade-in {
    animation: fadeIn 0.5s ease-out;
}

@keyframes pulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.05); }
    100% { transform: scale(1); }
}

.pulse {
    animation: pulse 2s infinite;
}

/* Адаптивность */
@media (max-width: 768px) {
    .container {
        padding: 0 1rem;
    }
    
    .navbar-nav {
        margin-top: 1rem;
    }
    
    .card {
        margin-bottom: 1rem;
    }
    
    .table-responsive {
        overflow-x: auto;
    }
    
    .footer {
        padding: 2rem 0 1.5rem;
    }
}

@media (max-width: 576px) {
    .btn {
        width: 100%;
        margin-bottom: 0.5rem;
    }
    
    .form-control {
        font-size: 16px; /* Предотвращает масштабирование на iOS */
    }
}

/* Кастомные стили для фитнес-платформы */
.training-card {
    height: 100%;
    border-left: 4px solid var(--primary-color);
}

.training-card.upcoming {
    border-left-color: var(--success-color);
}

.training-card.ongoing {
    border-left-color: var(--warning-color);
    animation: pulse 2s infinite;
}

.training-card.past {
    border-left-color: var(--gray-400);
    opacity: 0.8;
}

.progress-ring {
    width: 100px;
    height: 100px;
    position: relative;
}

.progress-ring-circle {
    transform: rotate(-90deg);
    transform-origin: 50% 50%;
}

.progress-ring-text {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    font-size: 1.5rem;
    font-weight: bold;
    color: var(--primary-color);
}

.achievement-badge {
    width: 80px;
    height: 80px;
    border-radius: 50%;
    background: linear-gradient(135deg, #ffd700, #ffed4e);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 2rem;
    box-shadow: var(--shadow);
    margin: 0 auto 1rem;
}

.stat-card {
    background: white;
    border-radius: var(--border-radius-lg);
    padding: 1.5rem;
    box-shadow: var(--shadow-sm);
    text-align: center;
    transition: all var(--transition);
}

.stat-card:hover {
    transform: translateY(-4px);
    box-shadow: var(--shadow);
}

.stat-card .stat-value {
    font-size: 2.5rem;
    font-weight: 700;
    color: var(--primary-color);
    margin-bottom: 0.5rem;
}

.stat-card .stat-label {
    color: var(--gray-600);
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 1px;
}

/* Календарь тренировок */
.calendar-event {
    padding: 0.5rem;
    margin: 0.25rem 0;
    border-radius: var(--border-radius);
    background-color: var(--primary-color);
    color: white;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all var(--transition-fast);
}

.calendar-event:hover {
    background-color: var(--primary-dark);
    transform: translateX(4px);
}

/* Визуализация данных */
.chart-container {
    background: white;
    border-radius: var(--border-radius-lg);
    padding: 1.5rem;
    box-shadow: var(--shadow-sm);
    margin-bottom: var(--spacing);
}
'@
New-Item -ItemType File -Path "app/static/css/main.css" -Value $mainCss -Force | Out-Null

# app/static/js/main.js
$mainJs = @'
/**
 * Основной JavaScript файл для фитнес-платформы
 */

document.addEventListener('DOMContentLoaded', function() {
    // Инициализация всех компонентов
    initTooltips();
    initForms();
    initNotifications();
    initCharts();
    initCalendar();
    initProgressTracking();
    initTrainingRegistration();
    
    // Обновление уведомлений каждые 30 секунд
    if (window.userAuthenticated) {
        setInterval(updateNotifications, 30000);
    }
});

/**
 * Инициализация всплывающих подсказок
 */
function initTooltips() {
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
}

/**
 * Инициализация форм с дополнительной логикой
 */
function initForms() {
    // Формы с подтверждением
    const confirmForms = document.querySelectorAll('form[data-confirm]');
    confirmForms.forEach(form => {
        form.addEventListener('submit', function(e) {
            const message = this.getAttribute('data-confirm');
            if (!confirm(message)) {
                e.preventDefault();
                return false;
            }
        });
    });
    
    // Формы с динамической валидацией
    const dynamicForms = document.querySelectorAll('form[data-validate-dynamic]');
    dynamicForms.forEach(form => {
        form.addEventListener('input', debounce(function() {
            validateFormAsync(form);
        }, 500));
    });
    
    // Формы с предварительным просмотром
    const previewForms = document.querySelectorAll('form[data-preview]');
    previewForms.forEach(form => {
        const previewBtn = form.querySelector('[data-preview-btn]');
        if (previewBtn) {
            previewBtn.addEventListener('click', function() {
                showFormPreview(form);
            });
        }
    });
}

/**
 * Инициализация системы уведомлений
 */
function initNotifications() {
    const notificationBell = document.getElementById('notificationBell');
    if (notificationBell) {
        notificationBell.addEventListener('click', function(e) {
            e.preventDefault();
            toggleNotificationsPanel();
        });
    }
    
    // Закрытие уведомлений по клику снаружи
    document.addEventListener('click', function(e) {
        const notificationsPanel = document.getElementById('notificationsPanel');
        if (notificationsPanel && !notificationsPanel.contains(e.target) && 
            notificationBell && !notificationBell.contains(e.target)) {
            notificationsPanel.classList.remove('show');
        }
    });
    
    // Обновление уведомлений при загрузке
    updateNotifications();
}

/**
 * Обновление уведомлений
 */
async function updateNotifications() {
    if (!window.userAuthenticated) return;
    
    try {
        const response = await fetch('/api/notifications');
        if (response.ok) {
            const data = await response.json();
            updateNotificationBadge(data.notifications.length);
            updateNotificationsPanel(data.notifications);
        }
    } catch (error) {
        console.error('Ошибка при получении уведомлений:', error);
    }
}

/**
 * Обновление бейджа уведомлений
 */
function updateNotificationBadge(count) {
    const badge = document.getElementById('notificationBadge');
    if (badge) {
        if (count > 0) {
            badge.textContent = count > 99 ? '99+' : count;
            badge.classList.remove('d-none');
            badge.classList.add('pulse');
        } else {
            badge.classList.add('d-none');
            badge.classList.remove('pulse');
        }
    }
}

/**
 * Обновление панели уведомлений
 */
function updateNotificationsPanel(notifications) {
    const panel = document.getElementById('notificationsPanel');
    if (!panel) return;
    
    const list = panel.querySelector('.notifications-list');
    if (!list) return;
    
    if (notifications.length === 0) {
        list.innerHTML = '<div class="text-center p-3 text-muted">Нет новых уведомлений</div>';
        return;
    }
    
    let html = '';
    notifications.forEach(notification => {
        const timeAgo = formatTimeAgo(new Date(notification.created_at));
        html += `
            <div class="notification-item ${notification.is_read ? '' : 'unread'}" data-id="${notification.id}">
                <div class="notification-icon">
                    <i class="fas ${getNotificationIcon(notification.type)}"></i>
                </div>
                <div class="notification-content">
                    <div class="notification-title">${escapeHtml(notification.title)}</div>
                    <div class="notification-message">${escapeHtml(notification.message)}</div>
                    <div class="notification-time">${timeAgo}</div>
                </div>
                ${!notification.is_read ? '<div class="notification-unread-dot"></div>' : ''}
            </div>
        `;
    });
    
    list.innerHTML = html;
    
    // Добавление обработчиков кликов
    list.querySelectorAll('.notification-item').forEach(item => {
        item.addEventListener('click', function() {
            const notificationId = this.getAttribute('data-id');
            markNotificationAsRead(notificationId);
            
            if (this.querySelector('.notification-unread-dot')) {
                this.querySelector('.notification-unread-dot').remove();
                this.classList.remove('unread');
            }
        });
    });
}

/**
 * Пометить уведомление как прочитанное
 */
async function markNotificationAsRead(notificationId) {
    try {
        const response = await fetch(`/api/notifications/${notificationId}/read`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': getCSRFToken()
            }
        });
        
        if (response.ok) {
            // Обновляем счетчик
            updateNotifications();
        }
    } catch (error) {
        console.error('Ошибка при отметке уведомления:', error);
    }
}

/**
 * Переключение панели уведомлений
 */
function toggleNotificationsPanel() {
    const panel = document.getElementById('notificationsPanel');
    if (panel) {
        panel.classList.toggle('show');
        
        if (panel.classList.contains('show')) {
            // При открытии обновляем уведомления
            updateNotifications();
        }
    }
}

/**
 * Инициализация графиков
 */
function initCharts() {
    // Инициализация всех графиков на странице
    const chartContainers = document.querySelectorAll('[data-chart]');
    chartContainers.forEach(container => {
        const chartType = container.getAttribute('data-chart');
        const dataUrl = container.getAttribute('data-url');
        
        if (dataUrl) {
            loadChartData(container, chartType, dataUrl);
        }
    });
}

/**
 * Загрузка данных для графика
 */
async function loadChartData(container, chartType, dataUrl) {
    try {
        const response = await fetch(dataUrl);
        if (response.ok) {
            const data = await response.json();
            renderChart(container, chartType, data);
        }
    } catch (error) {
        console.error('Ошибка при загрузке данных графика:', error);
        container.innerHTML = '<div class="alert alert-danger">Не удалось загрузить данные графика</div>';
    }
}

/**
 * Рендеринг графика
 */
function renderChart(container, chartType, data) {
    const canvas = document.createElement('canvas');
    container.innerHTML = '';
    container.appendChild(canvas);
    
    const ctx = canvas.getContext('2d');
    
    switch (chartType) {
        case 'line':
            renderLineChart(ctx, data);
            break;
        case 'bar':
            renderBarChart(ctx, data);
            break;
        case 'pie':
            renderPieChart(ctx, data);
            break;
        case 'radar':
            renderRadarChart(ctx, data);
            break;
        default:
            console.error('Неизвестный тип графика:', chartType);
    }
}

/**
 * Инициализация календаря тренировок
 */
function initCalendar() {
    const calendarEl = document.getElementById('trainingCalendar');
    if (!calendarEl) return;
    
    const calendar = new FullCalendar.Calendar(calendarEl, {
        initialView: 'dayGridMonth',
        locale: 'ru',
        firstDay: 1,
        headerToolbar: {
            left: 'prev,next today',
            center: 'title',
            right: 'dayGridMonth,timeGridWeek,timeGridDay'
        },
        buttonText: {
            today: 'Сегодня',
            month: 'Месяц',
            week: 'Неделя',
            day: 'День'
        },
        events: '/trainings/api/trainings/calendar',
        eventClick: function(info) {
            info.jsEvent.preventDefault();
            if (info.event.url) {
                window.location.href = info.event.url;
            }
        },
        eventDisplay: 'block',
        eventColor: '#4a6fa5',
        eventTimeFormat: {
            hour: '2-digit',
            minute: '2-digit',
            meridiem: false
        }
    });
    
    calendar.render();
}

/**
 * Инициализация отслеживания прогресса
 */
function initProgressTracking() {
    // Форма добавления прогресса
    const progressForm = document.getElementById('progressForm');
    if (progressForm) {
        progressForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            const data = Object.fromEntries(formData.entries());
            
            try {
                const response = await fetch('/progress/api/add', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-CSRF-Token': getCSRFToken()
                    },
                    body: JSON.stringify(data)
                });
                
                if (response.ok) {
                    const result = await response.json();
                    showAlert('success', result.message);
                    setTimeout(() => {
                        window.location.href = '/progress';
                    }, 1500);
                } else {
                    showAlert('danger', 'Ошибка при сохранении прогресса');
                }
            } catch (error) {
                console.error('Ошибка:', error);
                showAlert('danger', 'Ошибка при сохранении прогресса');
            }
        });
    }
    
    // Графики прогресса
    initProgressCharts();
}

/**
 * Инициализация графиков прогресса
 */
function initProgressCharts() {
    const progressChartEl = document.getElementById('progressChart');
    if (progressChartEl) {
        const ctx = progressChartEl.getContext('2d');
        
        // Загрузка данных прогресса
        fetch('/progress/api/chart-data?type=weekly')
            .then(response => response.json())
            .then(data => {
                const labels = data.map(item => item.week);
                const durationData = data.map(item => item.duration);
                const caloriesData = data.map(item => item.calories);
                
                new Chart(ctx, {
                    type: 'line',
                    data: {
                        labels: labels,
                        datasets: [
                            {
                                label: 'Продолжительность (мин)',
                                data: durationData,
                                borderColor: '#4a6fa5',
                                backgroundColor: 'rgba(74, 111, 165, 0.1)',
                                tension: 0.4
                            },
                            {
                                label: 'Калории',
                                data: caloriesData,
                                borderColor: '#ff7e5f',
                                backgroundColor: 'rgba(255, 126, 95, 0.1)',
                                tension: 0.4
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        plugins: {
                            legend: {
                                position: 'top',
                            },
                            tooltip: {
                                mode: 'index',
                                intersect: false
                            }
                        },
                        scales: {
                            y: {
                                beginAtZero: true
                            }
                        }
                    }
                });
            })
            .catch(error => {
                console.error('Ошибка при загрузке данных графика:', error);
            });
    }
}

/**
 * Инициализация регистрации на тренировки
 */
function initTrainingRegistration() {
    // Кнопки регистрации
    const registerButtons = document.querySelectorAll('[data-register-training]');
    registerButtons.forEach(button => {
        button.addEventListener('click', function() {
            const trainingId = this.getAttribute('data-training-id');
            registerForTraining(trainingId);
        });
    });
    
    // Кнопки отмены регистрации
    const cancelButtons = document.querySelectorAll('[data-cancel-registration]');
    cancelButtons.forEach(button => {
        button.addEventListener('click', function() {
            const trainingId = this.getAttribute('data-training-id');
            cancelTrainingRegistration(trainingId);
        });
    });
    
    // Отметка посещения
    const checkInButtons = document.querySelectorAll('[data-check-in]');
    checkInButtons.forEach(button => {
        button.addEventListener('click', function() {
            const trainingId = this.getAttribute('data-training-id');
            checkInToTraining(trainingId);
        });
    });
}

/**
 * Регистрация на тренировку
 */
async function registerForTraining(trainingId) {
    if (!confirm('Вы уверены, что хотите записаться на эту тренировку?')) {
        return;
    }
    
    try {
        const response = await fetch(`/trainings/${trainingId}/register`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': getCSRFToken()
            }
        });
        
        if (response.ok) {
            const result = await response.json();
            showAlert('success', result.message);
            setTimeout(() => {
                window.location.reload();
            }, 1500);
        } else {
            showAlert('danger', 'Ошибка при регистрации на тренировку');
        }
    } catch (error) {
        console.error('Ошибка:', error);
        showAlert('danger', 'Ошибка при регистрации на тренировку');
    }
}

/**
 * Отмена регистрации на тренировку
 */
async function cancelTrainingRegistration(trainingId) {
    if (!confirm('Вы уверены, что хотите отменить регистрацию на эту тренировку?')) {
        return;
    }
    
    try {
        const response = await fetch(`/trainings/${trainingId}/cancel-registration`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': getCSRFToken()
            }
        });
        
        if (response.ok) {
            showAlert('success', 'Регистрация успешно отменена');
            setTimeout(() => {
                window.location.reload();
            }, 1500);
        } else {
            showAlert('danger', 'Ошибка при отмене регистрации');
        }
    } catch (error) {
        console.error('Ошибка:', error);
        showAlert('danger', 'Ошибка при отмене регистрации');
    }
}

/**
 * Отметка посещения тренировки
 */
async function checkInToTraining(trainingId) {
    try {
        const response = await fetch(`/trainings/api/trainings/${trainingId}/check-in`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': getCSRFToken()
            }
        });
        
        if (response.ok) {
            const result = await response.json();
            showAlert('success', result.message);
            setTimeout(() => {
                window.location.reload();
            }, 1500);
        } else {
            showAlert('danger', 'Ошибка при отметке посещения');
        }
    } catch (error) {
        console.error('Ошибка:', error);
        showAlert('danger', 'Ошибка при отметке посещения');
    }
}

/**
 * Утилиты
 */

// Debounce функция
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Форматирование времени
function formatTimeAgo(date) {
    const seconds = Math.floor((new Date() - date) / 1000);
    
    if (seconds < 60) return 'только что';
    if (seconds < 3600) return `${Math.floor(seconds / 60)} минут назад`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)} часов назад`;
    if (seconds < 2592000) return `${Math.floor(seconds / 86400)} дней назад`;
    return `${Math.floor(seconds / 2592000)} месяцев назад`;
}

// Получение CSRF токена
function getCSRFToken() {
    const metaTag = document.querySelector('meta[name="csrf-token"]');
    return metaTag ? metaTag.getAttribute('content') : '';
}

// Экранирование HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Показ алертов
function showAlert(type, message) {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    const container = document.querySelector('.container') || document.body;
    container.insertBefore(alertDiv, container.firstChild);
    
    setTimeout(() => {
        alertDiv.classList.remove('show');
        setTimeout(() => alertDiv.remove(), 150);
    }, 5000);
}

// Получение иконки для типа уведомления
function getNotificationIcon(type) {
    const icons = {
        'training': 'fa-dumbbell',
        'registration': 'fa-calendar-check',
        'cancellation': 'fa-calendar-times',
        'reminder': 'fa-bell',
        'achievement': 'fa-trophy',
        'system': 'fa-info-circle',
        'moderation': 'fa-clipboard-check',
        'attendance': 'fa-user-check',
        'default': 'fa-bell'
    };
    
    return icons[type] || icons.default;
}
'@
New-Item -ItemType File -Path "app/static/js/main.js" -Value $mainJs -Force | Out-Null

Write-Host "  Созданы статические файлы" -ForegroundColor DarkGreen

# 6. Создание основных шаблонов
Write-Host "`nСоздание основных HTML шаблонов..." -ForegroundColor Cyan

# app/templates/base.html
$baseHtml = @'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{% block title %}Фитнес Платформа{% endblock %}</title>
    
    <!-- Favicon -->
    <link rel="icon" type="image/x-icon" href="{{ url_for('static', filename='images/favicon.ico') }}">
    
    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- Font Awesome -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    
    <!-- FullCalendar -->
    <link href="https://cdn.jsdelivr.net/npm/fullcalendar@5.10.1/main.min.css" rel="stylesheet">
    
    <!-- Chart.js -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    
    <!-- Custom CSS -->
    <link rel="stylesheet" href="{{ url_for('static', filename='css/main.css') }}">
    
    {% block extra_css %}{% endblock %}
</head>
<body>
    <!-- Навигация -->
    <nav class="navbar navbar-expand-lg navbar-dark">
        <div class="container">
            <a class="navbar-brand" href="{{ url_for('main.index') }}">
                <i class="fas fa-dumbbell"></i>
                <span>ФитнесПлатформа</span>
            </a>
            
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link {% if request.endpoint == 'main.index' %}active{% endif %}" 
                           href="{{ url_for('main.index') }}">
                            <i class="fas fa-home"></i> Главная
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link {% if request.endpoint.startswith('trainings.') %}active{% endif %}" 
                           href="{{ url_for('trainings.training_list') }}">
                            <i class="fas fa-running"></i> Тренировки
                        </a>
                    </li>
                    {% if current_user.is_authenticated %}
                    <li class="nav-item">
                        <a class="nav-link {% if request.endpoint.startswith('progress.') %}active{% endif %}" 
                           href="{{ url_for('progress.dashboard') }}">
                            <i class="fas fa-chart-line"></i> Прогресс
                        </a>
                    </li>
                    {% if current_user.role in ['trainer', 'admin'] %}
                    <li class="nav-item">
                        <a class="nav-link {% if request.endpoint == 'trainings.create_training' %}active{% endif %}" 
                           href="{{ url_for('trainings.create_training') }}">
                            <i class="fas fa-plus-circle"></i> Создать тренировку
                        </a>
                    </li>
                    {% endif %}
                    {% if current_user.role == 'admin' %}
                    <li class="nav-item">
                        <a class="nav-link {% if request.endpoint.startswith('admin.') %}active{% endif %}" 
                           href="{{ url_for('admin.dashboard') }}">
                            <i class="fas fa-cog"></i> Админпанель
                        </a>
                    </li>
                    {% endif %}
                    {% endif %}
                </ul>
                
                <ul class="navbar-nav">
                    {% if current_user.is_authenticated %}
                    <!-- Уведомления -->
                    <li class="nav-item dropdown">
                        <a class="nav-link position-relative" href="#" id="notificationBell" role="button">
                            <i class="fas fa-bell"></i>
                            <span id="notificationBadge" class="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger d-none">
                                0
                            </span>
                        </a>
                        <div class="dropdown-menu dropdown-menu-end p-0" id="notificationsPanel" style="min-width: 300px; max-height: 400px; overflow-y: auto;">
                            <div class="notifications-header p-3 border-bottom">
                                <h6 class="mb-0">Уведомления</h6>
                            </div>
                            <div class="notifications-list">
                                <div class="text-center p-3 text-muted">Загрузка...</div>
                            </div>
                        </div>
                    </li>
                    
                    <!-- Профиль пользователя -->
                    <li class="nav-item dropdown">
                        <a class="nav-link dropdown-toggle d-flex align-items-center" href="#" id="userDropdown" role="button" data-bs-toggle="dropdown">
                            {% if current_user.profile and current_user.profile.avatar_url %}
                            <img src="{{ current_user.profile.avatar_url }}" class="avatar avatar-sm me-2" alt="Аватар">
                            {% else %}
                            <i class="fas fa-user-circle me-2"></i>
                            {% endif %}
                            <span>{{ current_user.full_name or current_user.username }}</span>
                        </a>
                        <ul class="dropdown-menu dropdown-menu-end">
                            <li>
                                <a class="dropdown-item" href="{{ url_for('auth.profile') }}">
                                    <i class="fas fa-user me-2"></i> Профиль
                                </a>
                            </li>
                            <li>
                                <a class="dropdown-item" href="{{ url_for('trainings.my_trainings') }}">
                                    <i class="fas fa-calendar-alt me-2"></i> Мои тренировки
                                </a>
                            </li>
                            <li>
                                <a class="dropdown-item" href="{{ url_for('progress.goals') }}">
                                    <i class="fas fa-bullseye me-2"></i> Мои цели
                                </a>
                            </li>
                            <li><hr class="dropdown-divider"></li>
                            {% if current_user.role == 'trainer' %}
                            <li>
                                <a class="dropdown-item" href="{{ url_for('auth.trainer_profile') }}">
                                    <i class="fas fa-chalkboard-teacher me-2"></i> Профиль тренера
                                </a>
                            </li>
                            {% endif %}
                            <li>
                                <a class="dropdown-item" href="{{ url_for('auth.change_password') }}">
                                    <i class="fas fa-key me-2"></i> Сменить пароль
                                </a>
                            </li>
                            <li><hr class="dropdown-divider"></li>
                            <li>
                                <a class="dropdown-item text-danger" href="{{ url_for('auth.logout') }}">
                                    <i class="fas fa-sign-out-alt me-2"></i> Выйти
                                </a>
                            </li>
                        </ul>
                    </li>
                    {% else %}
                    <li class="nav-item">
                        <a class="nav-link" href="{{ url_for('auth.login') }}">
                            <i class="fas fa-sign-in-alt"></i> Войти
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="btn btn-outline-light ms-2" href="{{ url_for('auth.register') }}">
                            Регистрация
                        </a>
                    </li>
                    {% endif %}
                </ul>
            </div>
        </div>
    </nav>

    <!-- Основной контент -->
    <main class="flex-grow-1">
        <div class="container py-4">
            <!-- Заголовок страницы -->
            {% block header %}
            <div class="row mb-4">
                <div class="col">
                    <h1 class="display-5 fw-bold">{% block page_title %}{{ title }}{% endblock %}</h1>
                    {% block breadcrumbs %}{% endblock %}
                </div>
                {% block header_actions %}{% endblock %}
            </div>
            {% endblock %}
            
            <!-- Флеш-сообщения -->
            {% with messages = get_flashed_messages(with_categories=true) %}
                {% if messages %}
                    <div class="row mb-4">
                        <div class="col">
                            {% for category, message in messages %}
                                <div class="alert alert-{{ category }} alert-dismissible fade show" role="alert">
                                    {{ message }}
                                    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                                </div>
                            {% endfor %}
                        </div>
                    </div>
                {% endif %}
            {% endwith %}
            
            <!-- Контент страницы -->
            {% block content %}{% endblock %}
        </div>
    </main>

    <!-- Футер -->
    <footer class="footer">
        <div class="container">
            <div class="row">
                <div class="col-md-4 mb-4">
                    <h5>ФитнесПлатформа</h5>
                    <p class="mt-3">Платформа для виртуальных фитнес-тренировок и мониторинга активности. Тренируйтесь онлайн с лучшими тренерами!</p>
                </div>
                <div class="col-md-2 mb-4">
                    <h5>Навигация</h5>
                    <ul class="list-unstyled">
                        <li><a href="{{ url_for('main.index') }}">Главная</a></li>
                        <li><a href="{{ url_for('trainings.training_list') }}">Тренировки</a></li>
                        <li><a href="#">Тренеры</a></li>
                        <li><a href="#">Цены</a></li>
                    </ul>
                </div>
                <div class="col-md-2 mb-4">
                    <h5>Помощь</h5>
                    <ul class="list-unstyled">
                        <li><a href="#">FAQ</a></li>
                        <li><a href="#">Поддержка</a></li>
                        <li><a href="#">Политика конфиденциальности</a></li>
                        <li><a href="#">Условия использования</a></li>
                    </ul>
                </div>
                <div class="col-md-4 mb-4">
                    <h5>Контакты</h5>
                    <ul class="list-unstyled">
                        <li><i class="fas fa-envelope me-2"></i> support@fitnessplatform.ru</li>
                        <li><i class="fas fa-phone me-2"></i> +7 (999) 123-45-67</li>
                        <li class="mt-3">
                            <a href="#" class="me-3"><i class="fab fa-vk fa-lg"></i></a>
                            <a href="#" class="me-3"><i class="fab fa-telegram fa-lg"></i></a>
                            <a href="#" class="me-3"><i class="fab fa-instagram fa-lg"></i></a>
                            <a href="#"><i class="fab fa-youtube fa-lg"></i></a>
                        </li>
                    </ul>
                </div>
            </div>
            <div class="footer-bottom">
                <p>&copy; {{ current_year }} ФитнесПлатформа. Все права защищены.</p>
            </div>
        </div>
    </footer>

    <!-- Скрипты -->
    <!-- Bootstrap Bundle with Popper -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    
    <!-- FullCalendar -->
    <script src="https://cdn.jsdelivr.net/npm/fullcalendar@5.10.1/main.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/fullcalendar@5.10.1/locales/ru.js"></script>
    
    <!-- Custom JavaScript -->
    <script>
        // Глобальные переменные для JavaScript
        window.userAuthenticated = {{ 'true' if current_user.is_authenticated else 'false' }};
        window.userRole = '{{ current_user.role if current_user.is_authenticated else "" }}';
        window.userId = {{ current_user.id if current_user.is_authenticated else 'null' }};
    </script>
    <script src="{{ url_for('static', filename='js/main.js') }}"></script>
    
    {% block extra_js %}{% endblock %}
    
    <!-- Инициализация компонентов -->
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            // Инициализация всех компонентов Bootstrap
            var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
            var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
                return new bootstrap.Tooltip(tooltipTriggerEl);
            });
            
            var popoverTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="popover"]'));
            var popoverList = popoverTriggerList.map(function (popoverTriggerEl) {
                return new bootstrap.Popover(popoverTriggerEl);
            });
        });
    </script>
</body>
</html>
'@
New-Item -ItemType File -Path "app/templates/base.html" -Value $baseHtml -Force | Out-Null

# Создаем остальные необходимые файлы
Write-Host "  Созданы основные файлы проекта" -ForegroundColor DarkGreen

# 7. requirements.txt
$requirements = @'
# Основные зависимости
Flask==2.3.3
Flask-SQLAlchemy==3.0.5
Flask-Login==0.6.2
Flask-WTF==1.1.1
Flask-Migrate==4.0.4
Flask-Mail==0.9.1
Flask-CORS==4.0.0

# Работа с данными
Werkzeug==2.3.6
WTForms==3.0.1
python-dotenv==1.0.0
SQLAlchemy==1.4.46
alembic==1.11.1

# Безопасность
bcrypt==4.0.1
cryptography==41.0.3

# Утилиты
requests==2.31.0
Pillow==10.0.0
python-dateutil==2.8.2
pytz==2023.3

# Разработка
blinker==1.6.2
click==8.1.6
itsdangerous==2.1.2
Jinja2==3.1.2
MarkupSafe==2.1.3

# Тестирование
pytest==7.4.2
pytest-flask==1.2.0
Faker==19.6.2
'@
New-Item -ItemType File -Path "requirements.txt" -Value $requirements -Force | Out-Null

# 8. config.py
$config = @'
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
'@
New-Item -ItemType File -Path "config.py" -Value $config -Force | Out-Null

# 9. run.py
$runPy = @'
#!/usr/bin/env python
"""
Точка входа в приложение
"""

import os
from app import create_app
from config import config

# Определение конфига
config_name = os.getenv('FLASK_CONFIG', 'default')
app = create_app(config[config_name])

if __name__ == '__main__':
    # Запуск приложения
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=debug,
        threaded=True
    )
'@
New-Item -ItemType File -Path "run.py" -Value $runPy -Force | Out-Null

# 10. .env.example
$envExample = @'
# Flask
FLASK_APP=run.py
FLASK_ENV=development
FLASK_DEBUG=true
FLASK_CONFIG=development
SECRET_KEY=your-secret-key-change-this-in-production

# Database
DATABASE_URL=sqlite:///fitness_platform.db
DEV_DATABASE_URL=sqlite:///dev_fitness_platform.db
TEST_DATABASE_URL=sqlite:///test_fitness_platform.db

# Mail
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
MAIL_USE_TLS=true
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_DEFAULT_SENDER=noreply@fitnessplatform.com

# App
APP_NAME=Fitness Platform
APP_URL=http://localhost:5000
ITEMS_PER_PAGE=20

# Security
PASSWORD_RESET_TIMEOUT=3600
ACCOUNT_VERIFICATION_TIMEOUT=86400
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_TIME=300

# Logging
LOG_LEVEL=INFO
LOG_FILE=logs/app.log

# Uploads
MAX_CONTENT_LENGTH=16777216
UPLOAD_FOLDER=uploads
ALLOWED_EXTENSIONS=png,jpg,jpeg,gif,mp4,mov,avi
'@
New-Item -ItemType File -Path ".env.example" -Value $envExample -Force | Out-Null

# 11. .gitignore
$gitignore = @'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual Environment
venv/
env/
ENV/
env.bak/
venv.bak/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Database
*.db
*.sqlite3

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Environment
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Flask
instance/

# Testing
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/

# Translations
*.mo
*.pot

# Sphinx
docs/_build/

# PyBuilder
.pybuilder/
target/

# Jupyter
.ipynb_checkpoints

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre
.pyre/

# pytype
.pytype/

# Cython debug symbols
cython_debug/

# Uploads
uploads/
!uploads/.gitkeep
'@
New-Item -ItemType File -Path ".gitignore" -Value $gitignore -Force | Out-Null