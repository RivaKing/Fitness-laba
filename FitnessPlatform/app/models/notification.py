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