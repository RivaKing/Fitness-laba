# app/forms/auth.py
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, TextAreaField, SelectField, DateTimeField, IntegerField, FloatField, BooleanField, DateField
from wtforms.validators import DataRequired, Email, Length, EqualTo, ValidationError, Optional, NumberRange
from app.models import User
from datetime import datetime, date
import re

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
        Length(min=8, message='Пароль должен содержать минимум 8 символов')
    ])
    confirm_password = PasswordField('Подтвердите пароль', validators=[
        DataRequired(message='Подтвердите пароль'),
        EqualTo('password', message='Пароли не совпадают')
    ])
    
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
    
    # Соглашения (поле должно называться agree_terms, как в шаблоне)
    agree_terms = BooleanField('Согласие с условиями', validators=[
        DataRequired(message='Вы должны согласиться с условиями использования')
    ])
    # Можно добавить второе соглашение, если нужно
    privacy_accepted = BooleanField('Я согласен на обработку персональных данных', default=True)
    
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
        
        # Дополнительная валидация имени пользователя
        if not re.match(r'^[a-zA-Z0-9_]+$', field.data):
            raise ValidationError('Имя пользователя может содержать только буквы, цифры и подчеркивания')
        
        if not field.data[0].isalpha():
            raise ValidationError('Имя пользователя должно начинаться с буквы')
    
    def validate_password(self, field):
        """Проверка сложности пароля"""
        password = field.data
        
        # Проверка на заглавные буквы
        if not any(char.isupper() for char in password):
            raise ValidationError('Пароль должен содержать хотя бы одну заглавную букву')
        
        # Проверка на строчные буквы
        if not any(char.islower() for char in password):
            raise ValidationError('Пароль должен содержать хотя бы одну строчную букву')
        
        # Проверка на цифры
        if not any(char.isdigit() for char in password):
            raise ValidationError('Пароль должен содержать хотя бы одну цифру')
    
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

# Остальные формы остаются без изменений...
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