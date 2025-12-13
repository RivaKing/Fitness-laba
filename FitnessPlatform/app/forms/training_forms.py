"""Формы для тренировок"""
from flask_wtf import FlaskForm
from wtforms import StringField, TextAreaField, SelectField, DateTimeField, IntegerField, FloatField, BooleanField
from wtforms.validators import DataRequired, Length, Optional, NumberRange, URL
from datetime import datetime

class TrainingForm(FlaskForm):
    """Форма создания/редактирования тренировки"""
    title = StringField('Название', validators=[DataRequired(), Length(max=200)])
    description = TextAreaField('Описание', validators=[DataRequired()])
    short_description = TextAreaField('Краткое описание', validators=[Length(max=500)])
    
    category_id = SelectField('Категория', coerce=int)
    training_type = SelectField('Тип тренировки', choices=[
        ('group', 'Групповая'),
        ('individual', 'Индивидуальная'),
        ('recorded', 'Запись')
    ], validators=[DataRequired()])
    
    difficulty = SelectField('Сложность', choices=[
        ('beginner', 'Начинающий'),
        ('intermediate', 'Средний'),
        ('advanced', 'Продвинутый')
    ])
    
    intensity = SelectField('Интенсивность', choices=[
        ('low', 'Низкая'),
        ('medium', 'Средняя'),
        ('high', 'Высокая')
    ])
    
    schedule_time = DateTimeField('Дата и время', 
                                 format='%Y-%m-%d %H:%M',
                                 validators=[DataRequired()])
    duration = IntegerField('Длительность (минут)', 
                           validators=[DataRequired(), NumberRange(min=15, max=240)])
    timezone = SelectField('Часовой пояс', 
                          choices=[('Europe/Moscow', 'Москва'), ('UTC', 'UTC')],
                          default='Europe/Moscow')
    
    max_participants = IntegerField('Максимум участников', 
                                   default=10, 
                                   validators=[NumberRange(min=1, max=100)])
    min_participants = IntegerField('Минимум участников', 
                                   default=1, 
                                   validators=[Optional(), NumberRange(min=1, max=10)])
    
    age_limit_min = IntegerField('Минимальный возраст', 
                                validators=[Optional(), NumberRange(min=0, max=100)])
    age_limit_max = IntegerField('Максимальный возраст', 
                                validators=[Optional(), NumberRange(min=0, max=100)])
    
    video_link = StringField('Ссылка на видео', validators=[Optional(), URL(), Length(max=500)])
    meeting_link = StringField('Ссылка на конференцию', validators=[Optional(), URL(), Length(max=500)])
    materials_link = StringField('Ссылка на материалы', validators=[Optional(), URL(), Length(max=500)])
    
    price = FloatField('Цена', default=0.0, validators=[Optional(), NumberRange(min=0)])
    currency = SelectField('Валюта', choices=[('RUB', 'Рубль'), ('USD', 'Доллар')], default='RUB')
    
    keywords = StringField('Ключевые слова', validators=[Optional(), Length(max=500)])
    language = SelectField('Язык', choices=[('ru', 'Русский'), ('en', 'Английский')], default='ru')