"""
Маршруты для аутентификации и управления пользователями
"""

from flask import Blueprint, render_template, redirect, url_for, flash, request, jsonify, current_app
from flask_login import login_user, logout_user, login_required, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from sqlalchemy.exc import IntegrityError
import logging

from app import db
from app.forms.auth import (
    LoginForm, RegistrationForm, ProfileForm, ChangePasswordForm,
    ForgotPasswordForm, ResetPasswordForm, TrainerProfileForm
)
from app.models import User, UserProfile, Trainer, Client, AuditLog
from app.utils.decorators import role_required
import traceback 

bp = Blueprint('auth', __name__, url_prefix='/auth')

# Настройка логирования
logger = logging.getLogger(__name__)

@bp.route('/login', methods=['GET', 'POST'])
def login():
    """Страница входа в систему"""
    if current_user.is_authenticated:
        flash('Вы уже вошли в систему', 'info')
        return redirect(url_for('main.index'))
    
    form = LoginForm()
    
    if form.validate_on_submit():
        try:
            user = User.query.filter_by(email=form.email.data).first()
            
            if user and user.check_password(form.password.data):
                if not user.is_active:
                    flash('Ваш аккаунт деактивирован. Обратитесь к администратору.', 'danger')
                    return redirect(url_for('auth.login'))
                
                # Вход пользователя
                login_user(user, remember=form.remember.data)
                user.last_login = db.func.now()
                db.session.commit()
                
                # Логирование входа
                AuditLog.log_action(
                    user_id=user.id,
                    action='user_login',
                    resource_type='user',
                    resource_id=user.id,
                    request=request
                )
                
                logger.info(f'User {user.email} logged in successfully')
                flash('Вы успешно вошли в систему!', 'success')
                
                # Перенаправление в зависимости от роли
                if user.role == 'admin':
                    return redirect(url_for('admin.dashboard'))
                else:
                    return redirect(url_for('main.index'))
            else:
                flash('Неверный email или пароль', 'danger')
                logger.warning(f'Failed login attempt for email: {form.email.data}')
                
        except Exception as e:
            db.session.rollback()
            logger.error(f'Login error: {str(e)}')
            flash('Произошла ошибка при входе в систему', 'danger')
    
    return render_template('auth/login.html', form=form, title='Вход в систему')

@bp.route('/register', methods=['GET', 'POST'])
def register():
    """Страница регистрации"""
    if current_user.is_authenticated:
        flash('Вы уже зарегистрированы', 'info')
        return redirect(url_for('main.index'))
    
    form = RegistrationForm()
    
    if form.validate_on_submit():
        try:
            # Отладочная информация
            logger.info(f"Регистрация пользователя: email={form.email.data}, username={form.username.data}, role={form.role.data}")
            
            # ВАЖНО: Проверка существования пользователя перед созданием
            existing_user = User.query.filter(
                (User.email == form.email.data) | (User.username == form.username.data)
            ).first()
            
            if existing_user:
                if existing_user.email == form.email.data:
                    flash('Пользователь с таким email уже существует', 'danger')
                else:
                    flash('Пользователь с таким именем уже существует', 'danger')
                return render_template('auth/register.html', form=form, title='Регистрация')
            
            # Создание пользователя
            user = User(
                email=form.email.data,
                username=form.username.data,
                role=form.role.data
            )
            user.set_password(form.password.data)
            
            db.session.add(user)
            db.session.flush()  # Получаем ID пользователя
            
            logger.info(f"Создан пользователь с ID: {user.id}")
            
            # Создание профиля
            profile = UserProfile(
                user_id=user.id,
                full_name=form.full_name.data,
                date_of_birth=form.date_of_birth.data,
                gender=form.gender.data,
                phone=form.phone.data,
                height=form.height.data,
                weight=form.weight.data,
                fitness_level=form.fitness_level.data,
                medical_conditions=form.medical_conditions.data,
                allergies=form.allergies.data
            )
            db.session.add(profile)
            logger.info(f"Создан профиль для пользователя ID: {user.id}")
            
            # Создание записи в зависимости от роли
            # В обработчике регистрации auth.py:

            if form.role.data == 'trainer':
                # Проверяем наличие обязательных полей для тренера
                if not all([form.specialization.data, form.certification.data]):
                    flash('Для регистрации тренера необходимо заполнить специализацию и сертификацию', 'danger')
                    return render_template('auth/register.html', form=form, title='Регистрация')
                
                trainer = Trainer(
                    user_id=user.id,
                    specialization=form.specialization.data,
                    experience_years=form.experience_years.data or 0,
                    certification=form.certification.data,
                    is_available=True,
                    rating=0.0,
                    total_ratings=0,
                    completed_sessions=0
                )
                db.session.add(trainer)
                logger.info(f"Создан тренер: {user.username}")
                
            elif form.role.data == 'client':
                client = Client(user_id=user.id)
                db.session.add(client)
                logger.info(f"Создан клиент: {user.username}")
            
            # Для админа не создаем дополнительных записей
            elif form.role.data == 'admin':
                logger.info(f"Создан администратор: {user.username}")
                # Если нужна отдельная модель админа, создайте ее здесь
            
            # Проверяем данные перед коммитом
            try:
                db.session.commit()
                logger.info(f"Коммит успешен для пользователя: {user.email}")
            except Exception as commit_error:
                db.session.rollback()
                logger.error(f"Ошибка коммита: {str(commit_error)}")
                flash('Ошибка сохранения данных в базу', 'danger')
                return render_template('auth/register.html', form=form, title='Регистрация')
            
            # Логирование регистрации
            try:
                AuditLog.log_action(
                    user_id=user.id,
                    action='user_registration',
                    resource_type='user',
                    resource_id=user.id,
                    details_after={'role': user.role, 'email': user.email},
                    request=request
                )
            except Exception as audit_error:
                logger.error(f"Ошибка логгирования: {str(audit_error)}")
                # Не прерываем регистрацию из-за ошибки логгирования
            
            logger.info(f'New user registered successfully: {user.email} ({user.role})')
            flash('Регистрация прошла успешно! Теперь вы можете войти в систему.', 'success')
            
            return redirect(url_for('auth.login'))
            
        except IntegrityError as ie:
            db.session.rollback()
            logger.error(f'Registration integrity error: {str(ie)}')
            logger.error(f'Для email: {form.email.data}')
            flash('Пользователь с таким email или именем уже существует', 'danger')
        except Exception as e:
            db.session.rollback()
            logger.error(f'Registration error: {str(e)}')
            logger.error(f'Traceback: {traceback.format_exc()}')  # Добавим трассировку
            flash('Произошла ошибка при регистрации. Попробуйте еще раз.', 'danger')
    
    return render_template('auth/register.html', form=form, title='Регистрация')

@bp.route('/logout')
@login_required
def logout():
    """Выход из системы"""
    # Логирование выхода
    AuditLog.log_action(
        user_id=current_user.id,
        action='user_logout',
        resource_type='user',
        resource_id=current_user.id,
        request=request
    )
    
    logout_user()
    flash('Вы вышли из системы', 'info')
    return redirect(url_for('main.index'))

@bp.route('/profile', methods=['GET', 'POST'])
@login_required
def profile():
    """Страница профиля пользователя"""
    user_profile = current_user.profile
    form = ProfileForm(obj=user_profile) if user_profile else ProfileForm()
    
    if form.validate_on_submit():
        try:
            if not user_profile:
                user_profile = UserProfile(user_id=current_user.id)
                db.session.add(user_profile)
            
            # Обновление профиля
            form.populate_obj(user_profile)
            db.session.commit()
            
            # Логирование изменения профиля
            AuditLog.log_action(
                user_id=current_user.id,
                action='profile_update',
                resource_type='user_profile',
                resource_id=current_user.id,
                request=request
            )
            
            flash('Профиль успешно обновлен', 'success')
            return redirect(url_for('auth.profile'))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Profile update error: {str(e)}')
            flash('Ошибка при обновлении профиля', 'danger')
    
    return render_template('auth/profile.html', form=form, title='Мой профиль')

@bp.route('/profile/trainer', methods=['GET', 'POST'])
@login_required
@role_required('trainer')
def trainer_profile():
    """Профиль тренера"""
    trainer = Trainer.query.filter_by(user_id=current_user.id).first()
    
    if not trainer:
        # Создание записи тренера, если она отсутствует
        trainer = Trainer(user_id=current_user.id)
        db.session.add(trainer)
        db.session.commit()
    
    form = TrainerProfileForm(obj=trainer)
    
    if form.validate_on_submit():
        try:
            form.populate_obj(trainer)
            db.session.commit()
            
            # Логирование обновления профиля тренера
            AuditLog.log_action(
                user_id=current_user.id,
                action='trainer_profile_update',
                resource_type='trainer',
                resource_id=trainer.id,
                request=request
            )
            
            flash('Профиль тренера успешно обновлен', 'success')
            return redirect(url_for('auth.trainer_profile'))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Trainer profile update error: {str(e)}')
            flash('Ошибка при обновлении профиля тренера', 'danger')
    
    return render_template('auth/trainer_profile.html', form=form, title='Профиль тренера')

@bp.route('/change-password', methods=['GET', 'POST'])
@login_required
def change_password():
    """Смена пароля"""
    form = ChangePasswordForm()
    
    if form.validate_on_submit():
        try:
            current_user.set_password(form.new_password.data)
            db.session.commit()
            
            # Логирование смены пароля
            AuditLog.log_action(
                user_id=current_user.id,
                action='password_change',
                resource_type='user',
                resource_id=current_user.id,
                request=request
            )
            
            flash('Пароль успешно изменен', 'success')
            return redirect(url_for('auth.profile'))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Password change error: {str(e)}')
            flash('Ошибка при изменении пароля', 'danger')
    
    return render_template('auth/change_password.html', form=form, title='Смена пароля')

@bp.route('/forgot-password', methods=['GET', 'POST'])
def forgot_password():
    """Запрос на восстановление пароля"""
    if current_user.is_authenticated:
        return redirect(url_for('main.index'))
    
    form = ForgotPasswordForm()
    
    if form.validate_on_submit():
        try:
            user = User.query.filter_by(email=form.email.data).first()
            
            if user:
                # Генерация токена сброса пароля
                # В реальном приложении здесь была бы отправка email
                flash('Инструкции по восстановлению пароля отправлены на ваш email', 'success')
                
                # Логирование запроса на восстановление
                AuditLog.log_action(
                    user_id=user.id,
                    action='password_reset_request',
                    resource_type='user',
                    resource_id=user.id,
                    request=request
                )
            else:
                # Для безопасности не сообщаем, что пользователь не найден
                flash('Если email зарегистрирован, инструкции будут отправлены', 'success')
            
            return redirect(url_for('auth.login'))
            
        except Exception as e:
            logger.error(f'Password reset request error: {str(e)}')
            flash('Произошла ошибка. Попробуйте еще раз.', 'danger')
    
    return render_template('auth/forgot_password.html', form=form, title='Восстановление пароля')

@bp.route('/reset-password/<token>', methods=['GET', 'POST'])
def reset_password(token):
    """Сброс пароля по токену"""
    if current_user.is_authenticated:
        return redirect(url_for('main.index'))
    
    # В реальном приложении здесь была бы проверка токена
    form = ResetPasswordForm()
    
    if form.validate_on_submit():
        try:
            # Здесь должна быть логика проверки и использования токена
            # Для демонстрации просто показываем сообщение
            flash('Пароль успешно изменен. Теперь вы можете войти в систему.', 'success')
            return redirect(url_for('auth.login'))
            
        except Exception as e:
            logger.error(f'Password reset error: {str(e)}')
            flash('Неверный или просроченный токен', 'danger')
    
    return render_template('auth/reset_password.html', form=form, title='Сброс пароля')

@bp.route('/users')
@login_required
@role_required('admin')
def user_list():
    """Список пользователей (только для администраторов)"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    users = User.query.order_by(User.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    return render_template('auth/user_list.html', users=users, title='Пользователи')

@bp.route('/users/<int:user_id>')
@login_required
def user_detail(user_id):
    """Детальная информация о пользователе"""
    user = User.query.get_or_404(user_id)
    
    # Проверка прав доступа
    if current_user.id != user_id and current_user.role != 'admin':
        flash('У вас нет прав для просмотра этого профиля', 'danger')
        return redirect(url_for('main.index'))
    
    return render_template('auth/user_detail.html', user=user, title=f'Профиль {user.username}')

@bp.route('/users/<int:user_id>/toggle-active', methods=['POST'])
@login_required
@role_required('admin')
def toggle_user_active(user_id):
    """Активация/деактивация пользователя"""
    user = User.query.get_or404(user_id)
    
    # Нельзя деактивировать себя
    if user.id == current_user.id:
        flash('Вы не можете деактивировать свой собственный аккаунт', 'danger')
        return redirect(url_for('auth.user_list'))
    
    try:
        user.is_active = not user.is_active
        db.session.commit()
        
        action = 'активирован' if user.is_active else 'деактивирован'
        
        # Логирование действия
        AuditLog.log_action(
            user_id=current_user.id,
            action=f'user_{"activate" if user.is_active else "deactivate"}',
            resource_type='user',
            resource_id=user.id,
            details_after={'is_active': user.is_active},
            request=request
        )
        
        flash(f'Пользователь {user.username} успешно {action}', 'success')
        
    except Exception as e:
        db.session.rollback()
        logger.error(f'User activation error: {str(e)}')
        flash('Ошибка при изменении статуса пользователя', 'danger')
    
    return redirect(url_for('auth.user_list'))

# API endpoints
@bp.route('/api/check-email', methods=['POST'])
def check_email():
    """API проверки доступности email"""
    data = request.get_json()
    email = data.get('email', '')
    
    if not email:
        return jsonify({'available': False, 'message': 'Email не указан'})
    
    user = User.query.filter_by(email=email).first()
    available = user is None
    
    return jsonify({
        'available': available,
        'message': 'Email доступен' if available else 'Email уже используется'
    })

@bp.route('/api/check-username', methods=['POST'])
def check_username():
    """API проверки доступности имени пользователя"""
    data = request.get_json()
    username = data.get('username', '')
    
    if not username:
        return jsonify({'available': False, 'message': 'Имя пользователя не указано'})
    
    user = User.query.filter_by(username=username).first()
    available = user is None
    
    return jsonify({
        'available': available,
        'message': 'Имя пользователя доступно' if available else 'Имя пользователя уже используется'
    })