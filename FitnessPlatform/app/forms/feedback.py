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