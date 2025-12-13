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