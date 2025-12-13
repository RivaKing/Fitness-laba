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
    # Связываем тренера напрямую с пользователем
    trainer_user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
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
    moderator_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    
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
    
    # Связь с пользователем-тренером - ИСПРАВЛЕНО: убрали backref, так как он уже определен в User
    trainer_user = db.relationship('User', foreign_keys=[trainer_user_id], lazy=True)
    
    # Связь с модератором - ИСПРАВЛЕНО: убрали backref, так как он уже определен в User
    moderator_user = db.relationship('User', foreign_keys=[moderator_id], lazy=True)
    
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