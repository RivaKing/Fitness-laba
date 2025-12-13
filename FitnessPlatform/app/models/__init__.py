"""
Инициализация моделей для избежания циклических импортов
"""

from app import db

# Импортируем все модели
from app.models.user import User, UserProfile, Trainer, Client
from app.models.training import Training, TrainingCategory, TrainingRegistration, TrainingSchedule
from app.models.feedback import Feedback, Rating, Comment
from app.models.progress import Progress, ProgressMetric, Goal, Achievement
from app.models.system import AuditLog, SystemSetting, ContentModeration
from app.models.notification import Notification, NotificationTemplate

# Экспортируем все модели для удобного импорта
__all__ = [
    'User', 'UserProfile', 'Trainer', 'Client',
    'Training', 'TrainingCategory', 'TrainingRegistration', 'TrainingSchedule',
    'Feedback', 'Rating', 'Comment',
    'Progress', 'ProgressMetric', 'Goal', 'Achievement',
    'AuditLog', 'SystemSetting', 'ContentModeration',
    'Notification', 'NotificationTemplate'
]