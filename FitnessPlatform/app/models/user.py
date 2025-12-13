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
    
    # Связи - все с явным указанием foreign_keys
    
    # Профиль пользователя
    profile = db.relationship('UserProfile', backref='user', uselist=False, lazy=True, cascade='all, delete-orphan')
    
    # Тренировки, на которые пользователь зарегистрирован как клиент
    training_registrations = db.relationship('TrainingRegistration', 
                                           backref='user_reg', 
                                           lazy='dynamic',
                                           foreign_keys='TrainingRegistration.user_id',
                                           cascade='all, delete-orphan')
    
    # Тренировки, созданные пользователем как тренером
    trainings_created = db.relationship('Training', 
                                      backref='trainer_creator', 
                                      lazy='dynamic',
                                      foreign_keys='Training.trainer_user_id',
                                      cascade='all, delete-orphan')
    
    # Тренировки, которые пользователь модерировал
    trainings_moderated = db.relationship('Training', 
                                        backref='training_moderator', 
                                        lazy='dynamic',
                                        foreign_keys='Training.moderator_id')
    
    # Записи прогресса
    progress_entries = db.relationship('Progress', 
                                     backref='progress_owner', 
                                     lazy='dynamic',
                                     foreign_keys='Progress.user_id',
                                     cascade='all, delete-orphan')
    
    # Отзывы, которые пользователь оставил
    feedbacks_given = db.relationship('Feedback', 
                                    backref='feedback_author', 
                                    lazy='dynamic',
                                    foreign_keys='Feedback.user_id',
                                    cascade='all, delete-orphan')
    
    # Отзывы, которые пользователь модерировал
    feedbacks_moderated = db.relationship('Feedback', 
                                        backref='feedback_moderator', 
                                        lazy='dynamic',
                                        foreign_keys='Feedback.moderated_by')
    
    # Уведомления пользователя
    notifications = db.relationship('Notification', 
                                  backref='notification_recipient', 
                                  lazy='dynamic',
                                  foreign_keys='Notification.user_id',
                                  cascade='all, delete-orphan')
    
    # Цели пользователя
    goals = db.relationship('Goal', 
                          backref='goal_owner', 
                          lazy='dynamic',
                          foreign_keys='Goal.user_id',
                          cascade='all, delete-orphan')
    
    # Комментарии к отзывам, которые пользователь оставил
    comments_made = db.relationship('Comment', 
                                  backref='comment_author', 
                                  lazy='dynamic',
                                  foreign_keys='Comment.user_id',
                                  cascade='all, delete-orphan')
    
    # Комментарии, которые пользователь модерировал
    comments_moderated = db.relationship('Comment', 
                                       backref='comment_moderator', 
                                       lazy='dynamic',
                                       foreign_keys='Comment.moderated_by')
    
    # Логи аудита, связанные с пользователем
    audit_logs = db.relationship('AuditLog', 
                               backref='audit_user', 
                               lazy='dynamic',
                               foreign_keys='AuditLog.user_id',
                               cascade='all, delete-orphan')
    
    # Жалобы, которые пользователь отправил
    content_reports = db.relationship('ContentModeration', 
                                    backref='report_author', 
                                    lazy='dynamic',
                                    foreign_keys='ContentModeration.reported_by',
                                    cascade='all, delete-orphan')
    
    # Модерации контента, выполненные пользователем
    content_moderations = db.relationship('ContentModeration', 
                                        backref='content_moderator', 
                                        lazy='dynamic',
                                        foreign_keys='ContentModeration.moderated_by')
    
    # Системные настройки, обновленные пользователем
    system_settings_updated = db.relationship('SystemSetting', 
                                            backref='setting_updater', 
                                            lazy='dynamic',
                                            foreign_keys='SystemSetting.updated_by')
    
    # Связь с тренером (если пользователь - тренер)
    trainer_info = db.relationship('Trainer', 
                                 backref='trainer_user', 
                                 uselist=False, 
                                 lazy=True,
                                 foreign_keys='Trainer.user_id',
                                 cascade='all, delete-orphan')
    
    # Связь с клиентом (если пользователь - клиент)
    client_info = db.relationship('Client', 
                                backref='client_user', 
                                uselist=False, 
                                lazy=True,
                                foreign_keys='Client.user_id',
                                cascade='all, delete-orphan')
    
    # Достижения пользователя
    achievements = db.relationship('Achievement', 
                                 backref='achievement_owner', 
                                 lazy='dynamic',
                                 foreign_keys='Achievement.user_id',
                                 cascade='all, delete-orphan')
    
    # Метрики прогресса (через Progress)
    def get_progress_metrics(self):
        """Получить все метрики прогресса пользователя"""
        metrics = []
        for progress in self.progress_entries:
            metrics.extend(progress.metrics.all())
        return metrics
    
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
    
    @property
    def is_trainer(self):
        """Проверка, является ли пользователь тренером"""
        return self.role == 'trainer' and self.trainer_info is not None
    
    @property
    def is_client(self):
        """Проверка, является ли пользователь клиентом"""
        return self.role == 'client' and self.client_info is not None
    
    @property
    def full_name(self):
        """Полное имя пользователя из профиля"""
        if self.profile and self.profile.full_name:
            return self.profile.full_name
        return self.username
    
    def get_upcoming_trainings(self):
        """Получить предстоящие тренировки пользователя"""
        from app.models import TrainingRegistration, Training
        from datetime import datetime
        
        return TrainingRegistration.query.join(Training).filter(
            TrainingRegistration.user_id == self.id,
            TrainingRegistration.status == 'registered',
            Training.schedule_time > datetime.utcnow()
        ).order_by(Training.schedule_time).all()
    
    def get_past_trainings(self):
        """Получить прошедшие тренировки пользователя"""
        from app.models import TrainingRegistration, Training
        from datetime import datetime
        
        return TrainingRegistration.query.join(Training).filter(
            TrainingRegistration.user_id == self.id,
            Training.schedule_time < datetime.utcnow()
        ).order_by(Training.schedule_time.desc()).all()
    
    def get_unread_notifications_count(self):
        """Получить количество непрочитанных уведомлений"""
        return self.notifications.filter_by(is_read=False).count()
    
    def get_active_goals(self):
        """Получить активные цели пользователя"""
        return self.goals.filter_by(status='active').all()
    
    def __repr__(self):
        return f'<User {self.username} ({self.role})>'

class UserProfile(db.Model):
    """Профиль пользователя с дополнительной информацией"""
    __tablename__ = 'user_profiles'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), unique=True, nullable=False, index=True)
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
        from datetime import date
        if self.date_of_birth:
            today = date.today()
            return today.year - self.date_of_birth.year - (
                (today.month, today.day) < (self.date_of_birth.month, self.date_of_birth.day)
            )
        return None
    
    def get_preferred_activities_list(self):
        """Получить список предпочитаемых активностей"""
        import json
        if self.preferred_activities:
            try:
                return json.loads(self.preferred_activities)
            except:
                return []
        return []
    
    def set_preferred_activities_list(self, activities_list):
        """Установить список предпочитаемых активностей"""
        import json
        self.preferred_activities = json.dumps(activities_list, ensure_ascii=False)
    
    def __repr__(self):
        return f'<UserProfile for User:{self.user_id}>'

class Trainer(db.Model):
    """Модель тренера (расширение пользователя)"""
    __tablename__ = 'trainers'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), unique=True, nullable=False, index=True)
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
    
    # Связь с тренировками через пользователя
    def get_trainings(self):
        """Получить тренировки тренера"""
        from app.models import Training
        if self.user and self.user.trainings_created:
            return self.user.trainings_created.all()
        return []
    
    def get_upcoming_trainings(self):
        """Получить предстоящие тренировки тренера"""
        from app.models import Training
        from datetime import datetime
        
        if self.user:
            return self.user.trainings_created.filter(
                Training.schedule_time > datetime.utcnow()
            ).order_by(Training.schedule_time).all()
        return []
    
    def get_past_trainings(self):
        """Получить прошедшие тренировки тренера"""
        from app.models import Training
        from datetime import datetime
        
        if self.user:
            return self.user.trainings_created.filter(
                Training.schedule_time < datetime.utcnow()
            ).order_by(Training.schedule_time.desc()).all()
        return []
    
    def update_rating(self, new_rating):
        """Обновление рейтинга тренера"""
        total_score = self.rating * self.total_ratings + new_rating
        self.total_ratings += 1
        self.rating = round(total_score / self.total_ratings, 2)
        db.session.commit()
    
    def get_work_schedule_dict(self):
        """Получить расписание работы в виде словаря"""
        import json
        if self.work_schedule:
            try:
                return json.loads(self.work_schedule)
            except:
                return {}
        return {}
    
    def set_work_schedule_dict(self, schedule_dict):
        """Установить расписание работы из словаря"""
        import json
        self.work_schedule = json.dumps(schedule_dict, ensure_ascii=False)
    
    def __repr__(self):
        return f'<Trainer {self.user_id} ({self.specialization})>'

class Client(db.Model):
    """Модель клиента (расширение пользователя)"""
    __tablename__ = 'clients'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), unique=True, nullable=False, index=True)
    
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
    
    def is_subscription_active(self):
        """Проверка активной подписки"""
        if self.subscription_end:
            return self.subscription_end > datetime.utcnow()
        return False
    
    def get_fitness_goals_dict(self):
        """Получить цели фитнеса в виде словаря"""
        import json
        if self.fitness_goals:
            try:
                return json.loads(self.fitness_goals)
            except:
                return {}
        return {}
    
    def set_fitness_goals_dict(self, goals_dict):
        """Установить цели фитнеса из словаря"""
        import json
        self.fitness_goals = json.dumps(goals_dict, ensure_ascii=False)
    
    def get_preferred_training_types_list(self):
        """Получить список предпочитаемых типов тренировок"""
        import json
        if self.preferred_training_types:
            try:
                return json.loads(self.preferred_training_types)
            except:
                return []
        return []
    
    def set_preferred_training_types_list(self, types_list):
        """Установить список предпочитаемых типов тренировок"""
        import json
        self.preferred_training_types = json.dumps(types_list, ensure_ascii=False)
    
    def get_active_trainings(self):
        """Получить активные тренировки клиента"""
        from app.models import TrainingRegistration
        if self.user:
            return self.user.training_registrations.filter_by(status='registered').all()
        return []
    
    def __repr__(self):
        return f'<Client {self.user_id}>'

# Таблица многие-ко-многим для предпочтений клиентов
client_trainer_preferences = db.Table('client_trainer_preferences',
    db.Column('client_id', db.Integer, db.ForeignKey('clients.id'), primary_key=True),
    db.Column('trainer_id', db.Integer, db.ForeignKey('trainers.id'), primary_key=True),
    db.Column('preference_score', db.Float, default=1.0),
    db.Column('created_at', db.DateTime, default=datetime.utcnow)
)