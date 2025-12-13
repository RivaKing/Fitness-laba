# app/routes/main.py
from flask import Blueprint, render_template
from flask_login import current_user

bp = Blueprint('main', __name__)

@bp.route('/')
def index():
    """Главная страница"""
    if current_user.is_authenticated:
        return render_template('index.html', 
                             title='Главная',
                             current_year=2025)
    else:
        return render_template('landing.html',
                             title='Фитнес Платформа - Начни тренироваться онлайн',
                             current_year=2025)

@bp.route('/about')
def about():
    """Страница о нас"""
    return render_template('about.html',
                         title='О нас',
                         current_year=2025)

@bp.route('/contact')
def contact():
    """Страница контактов"""
    return render_template('contact.html',
                         title='Контакты',
                         current_year=2025)