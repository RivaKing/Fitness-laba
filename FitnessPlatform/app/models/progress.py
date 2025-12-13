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