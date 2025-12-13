"""
Системные модели для администрирования
"""

from app import db
from datetime import datetime
import json

class AuditLog(db.Model):
    """Логи аудита действий в системе"""
    __tablename__ = 'audit_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # Кто совершил действие
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    user_ip = db.Column(db.String(45))
    user_agent = db.Column(db.Text)
    
    # Что произошло
    action = db.Column(db.String(100), nullable=False, index=True)
    resource_type = db.Column(db.String(50), nullable=False, index=True)
    resource_id = db.Column(db.String(100), index=True)
    
    # Детали
    details_before = db.Column(db.Text)  # JSON состояние до
    details_after = db.Column(db.Text)   # JSON состояние после
    changes = db.Column(db.Text)         # JSON изменения
    
    # Контекст
    request_path = db.Column(db.String(500))
    request_method = db.Column(db.String(10))
    status_code = db.Column(db.Integer)
    
    # Время
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    duration_ms = db.Column(db.Integer)  # длительность в миллисекундах
    
    def log_action(user_id, action, resource_type, resource_id=None, 
                  details_before=None, details_after=None, request=None):
        """Создание записи в логе аудита"""
        log = AuditLog(
            user_id=user_id,
            action=action,
            resource_type=resource_type,
            resource_id=str(resource_id) if resource_id else None,
            details_before=json.dumps(details_before, ensure_ascii=False) if details_before else None,
            details_after=json.dumps(details_after, ensure_ascii=False) if details_after else None
        )
        
        if request:
            log.user_ip = request.remote_addr
            log.user_agent = request.user_agent.string
            log.request_path = request.path
            log.request_method = request.method
        
        # Вычисление изменений
        if details_before and details_after:
            changes = {}
            for key in set(details_before.keys()) | set(details_after.keys()):
                if details_before.get(key) != details_after.get(key):
                    changes[key] = {
                        'before': details_before.get(key),
                        'after': details_after.get(key)
                    }
            log.changes = json.dumps(changes, ensure_ascii=False)
        
        db.session.add(log)
        db.session.commit()
        
        return log
    
    def __repr__(self):
        return f'<AuditLog {self.action} by User:{self.user_id}>'

class SystemSetting(db.Model):
    """Системные настройки"""
    __tablename__ = 'system_settings'
    
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(100), nullable=False, unique=True, index=True)
    value = db.Column(db.Text)
    value_type = db.Column(db.String(20), default='string')  # string, integer, float, boolean, json, list
    category = db.Column(db.String(50), index=True)
    description = db.Column(db.Text)
    
    # Ограничения
    is_public = db.Column(db.Boolean, default=False)
    is_editable = db.Column(db.Boolean, default=True)
    is_encrypted = db.Column(db.Boolean, default=False)
    
    # Валидация
    validation_regex = db.Column(db.String(200))
    min_value = db.Column(db.String(50))
    max_value = db.Column(db.String(50))
    allowed_values = db.Column(db.Text)  # JSON список разрешенных значений
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    updated_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    
    def get_value(self):
        """Получение значения с правильным типом"""
        if self.value is None:
            return None
        
        try:
            if self.value_type == 'integer':
                return int(self.value)
            elif self.value_type == 'float':
                return float(self.value)
            elif self.value_type == 'boolean':
                return self.value.lower() in ('true', '1', 'yes', 'y')
            elif self.value_type == 'json':
                return json.loads(self.value)
            elif self.value_type == 'list':
                return [item.strip() for item in self.value.split(',')]
            else:  # string
                return self.value
        except (ValueError, json.JSONDecodeError):
            return self.value
    
    def set_value(self, new_value):
        """Установка значения с преобразованием типа"""
        if new_value is None:
            self.value = None
        elif self.value_type == 'json':
            self.value = json.dumps(new_value, ensure_ascii=False)
        elif self.value_type == 'list' and isinstance(new_value, list):
            self.value = ','.join(str(item) for item in new_value)
        elif self.value_type == 'boolean':
            self.value = 'true' if new_value else 'false'
        else:
            self.value = str(new_value)
    
    @classmethod
    def get_setting(cls, key, default=None):
        """Получение значения настройки"""
        setting = cls.query.filter_by(key=key).first()
        if setting:
            return setting.get_value()
        return default
    
    @classmethod
    def set_setting(cls, key, value, value_type='string', category='general'):
        """Установка значения настройки"""
        setting = cls.query.filter_by(key=key).first()
        if not setting:
            setting = cls(key=key, value_type=value_type, category=category)
        
        setting.set_value(value)
        db.session.add(setting)
        db.session.commit()
        
        return setting
    
    def __repr__(self):
        return f'<SystemSetting {self.key}>'

class ContentModeration(db.Model):
    """Модерация контента"""
    __tablename__ = 'content_moderation'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # Что модерируется
    content_type = db.Column(db.String(50), nullable=False, index=True)  # training, feedback, comment, user
    content_id = db.Column(db.Integer, nullable=False, index=True)
    
    # Кто и когда
    reported_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    reported_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Причина
    reason = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    
    # Статус
    status = db.Column(db.String(20), default='pending', index=True)  # pending, reviewing, approved, rejected, removed
    moderated_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    moderated_at = db.Column(db.DateTime)
    moderation_notes = db.Column(db.Text)
    
    # Действия
    actions_taken = db.Column(db.Text)  # JSON список предпринятых действий
    penalty_points = db.Column(db.Integer, default=0)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def approve(self, moderator_id, notes=None):
        """Одобрение контента"""
        self.status = 'approved'
        self.moderated_by = moderator_id
        self.moderation_notes = notes
        self.moderated_at = datetime.utcnow()
        db.session.commit()
    
    def reject(self, moderator_id, notes, actions=None, penalty=0):
        """Отклонение контента"""
        self.status = 'rejected'
        self.moderated_by = moderator_id
        self.moderation_notes = notes
        self.moderated_at = datetime.utcnow()
        self.penalty_points = penalty
        
        if actions:
            self.actions_taken = json.dumps(actions, ensure_ascii=False)
        
        db.session.commit()
    
    def remove(self, moderator_id, notes, actions=None, penalty=0):
        """Удаление контента"""
        self.status = 'removed'
        self.moderated_by = moderator_id
        self.moderation_notes = notes
        self.moderated_at = datetime.utcnow()
        self.penalty_points = penalty
        
        if actions:
            self.actions_taken = json.dumps(actions, ensure_ascii=False)
        
        db.session.commit()
    
    def __repr__(self):
        return f'<ContentModeration {self.content_type}:{self.content_id}>'