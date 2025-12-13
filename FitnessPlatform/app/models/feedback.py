"""
Модели для системы отзывов и рейтингов
"""

from app import db
from datetime import datetime
import json

class Feedback(db.Model):
    """Отзывы о тренировках"""
    __tablename__ = 'feedbacks'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    training_id = db.Column(db.Integer, db.ForeignKey('trainings.id'), nullable=False, index=True)
    
    # Основные данные
    title = db.Column(db.String(200))
    comment = db.Column(db.Text)
    is_anonymous = db.Column(db.Boolean, default=False)
    
    # Модерация
    moderation_status = db.Column(db.String(20), default='pending')  # pending, approved, rejected
    moderated_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)  # Может быть NULL
    moderation_notes = db.Column(db.Text)
    moderated_at = db.Column(db.DateTime)
    
    # Взаимодействия
    likes_count = db.Column(db.Integer, default=0)
    reports_count = db.Column(db.Integer, default=0)
    is_edited = db.Column(db.Boolean, default=False)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Связи - ИСПРАВЛЕНО
    ratings = db.relationship('Rating', backref='feedback', lazy='dynamic', cascade='all, delete-orphan')
    comments = db.relationship('Comment', backref='feedback', lazy='dynamic', cascade='all, delete-orphan')
    
    # Уникальный constraint
    __table_args__ = (
        db.UniqueConstraint('user_id', 'training_id', name='unique_user_training_feedback'),
    )
    
    # Связь с пользователем (автором отзыва) - ИСПРАВЛЕНО: убрали backref
    user = db.relationship('User', foreign_keys=[user_id], lazy=True)
    
    # Связь с модератором (если есть) - ИСПРАВЛЕНО: убрали backref
    moderator = db.relationship('User', foreign_keys=[moderated_by], lazy=True)
    
    def approve(self, moderator_id, notes=None):
        """Одобрение отзыва модератором"""
        self.moderation_status = 'approved'
        self.moderated_by = moderator_id
        self.moderation_notes = notes
        self.moderated_at = datetime.utcnow()
        db.session.commit()
    
    def reject(self, moderator_id, notes):
        """Отклонение отзыва модератором"""
        self.moderation_status = 'rejected'
        self.moderated_by = moderator_id
        self.moderation_notes = notes
        self.moderated_at = datetime.utcnow()
        db.session.commit()
    
    def add_like(self):
        """Добавление лайка"""
        self.likes_count += 1
        db.session.commit()
    
    def remove_like(self):
        """Удаление лайка"""
        self.likes_count = max(0, self.likes_count - 1)
        db.session.commit()
    
    def report(self):
        """Жалоба на отзыв"""
        self.reports_count += 1
        db.session.commit()
    
    @property
    def is_visible(self):
        """Виден ли отзыв другим пользователям"""
        return self.moderation_status == 'approved'
    
    def __repr__(self):
        return f'<Feedback User:{self.user_id} Training:{self.training_id}>'

class Rating(db.Model):
    """Рейтинги тренировок по различным критериям"""
    __tablename__ = 'ratings'
    
    id = db.Column(db.Integer, primary_key=True)
    feedback_id = db.Column(db.Integer, db.ForeignKey('feedbacks.id'), nullable=False, index=True)
    rating_type = db.Column(db.String(50), nullable=False)  # overall, trainer, content, difficulty, etc.
    score = db.Column(db.Float, nullable=False)  # 1-5 или 1-10
    max_score = db.Column(db.Float, default=5.0)
    
    comment = db.Column(db.String(500))  # комментарий к конкретному рейтингу
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Индекс для быстрого поиска
    __table_args__ = (
        db.Index('idx_feedback_rating_type', 'feedback_id', 'rating_type'),
    )
    
    def normalized_score(self):
        """Нормализованный балл (0-1)"""
        return self.score / self.max_score
    
    def __repr__(self):
        return f'<Rating {self.rating_type}:{self.score}/{self.max_score}>'

class Comment(db.Model):
    """Комментарии к отзывам"""
    __tablename__ = 'feedback_comments'
    
    id = db.Column(db.Integer, primary_key=True)
    feedback_id = db.Column(db.Integer, db.ForeignKey('feedbacks.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    parent_id = db.Column(db.Integer, db.ForeignKey('feedback_comments.id'), nullable=True)  # для ответов
    
    content = db.Column(db.Text, nullable=False)
    is_edited = db.Column(db.Boolean, default=False)
    
    # Модерация
    moderation_status = db.Column(db.String(20), default='pending')
    moderated_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)  # Может быть NULL
    
    # Взаимодействия
    likes_count = db.Column(db.Integer, default=0)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    deleted_at = db.Column(db.DateTime)
    
    # Связи - ИСПРАВЛЕНО: убрали backref
    user = db.relationship('User', foreign_keys=[user_id], lazy=True)
    moderator = db.relationship('User', foreign_keys=[moderated_by], lazy=True)
    replies = db.relationship('Comment', 
                             backref=db.backref('parent', remote_side=[id]), 
                             lazy='dynamic',
                             cascade='all, delete-orphan')
    
    # Индекс
    __table_args__ = (
        db.Index('idx_feedback_comment_parent', 'feedback_id', 'parent_id'),
    )
    
    @property
    def is_deleted(self):
        """Удален ли комментарий"""
        return self.deleted_at is not None
    
    def soft_delete(self):
        """Мягкое удаление комментария"""
        self.deleted_at = datetime.utcnow()
        self.content = '[Комментарий удален]'
        db.session.commit()
    
    def add_like(self):
        """Добавление лайка"""
        self.likes_count += 1
        db.session.commit()
    
    def __repr__(self):
        return f'<Comment User:{self.user_id} on Feedback:{self.feedback_id}>'