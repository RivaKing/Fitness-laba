"""
Формы для работы с тренировками
"""

from flask_wtf import FlaskForm
from wtforms import StringField, TextAreaField, SelectField, DateTimeField, IntegerField, FloatField, BooleanField, TimeField, DateField
from wtforms.validators import DataRequired, Length, Optional, NumberRange, ValidationError, URL
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