"""Маршруты для тренировок"""
from flask import Blueprint, render_template, flash, redirect, url_for, request, jsonify
from flask_login import login_required, current_user
from datetime import datetime, timedelta
import json

from app import db
from app.models.training import Training, TrainingCategory, TrainingRegistration
from app.models.feedback import Feedback, Rating
from app.forms.training import TrainingForm  # Убедитесь, что это правильный путь

# Создаем Blueprint здесь
bp = Blueprint('trainings', __name__, url_prefix='/trainings')

@bp.route('/', endpoint='training_list')
def list_trainings():
    """Список всех тренировок"""
    page = request.args.get('page', 1, type=int)
    category_id = request.args.get('category', type=int)
    training_type = request.args.get('type')
    difficulty = request.args.get('difficulty')
    training_date = request.args.get('date')
    
    query = Training.query.filter(Training.status.in_(['active', 'approved', 'draft']))
    
    # Фильтры
    if category_id:
        query = query.filter_by(category_id=category_id)
    if training_type:
        query = query.filter_by(training_type=training_type)
    if difficulty:
        query = query.filter_by(difficulty=difficulty)
    if training_date:
        try:
            filter_date = datetime.strptime(training_date, '%Y-%m-%d').date()
            query = query.filter(db.func.date(Training.schedule_time) == filter_date)
        except ValueError:
            pass
    
    # Только активные для обычных пользователей
    if not current_user.is_authenticated or current_user.role not in ['trainer', 'admin']:
        query = query.filter(Training.status.in_(['active', 'approved']))
    
    # Сортировка
    query = query.order_by(Training.schedule_time.asc())
    
    # Пагинация
    trainings = query.paginate(page=page, per_page=9, error_out=False)
    
    categories = TrainingCategory.query.filter_by(is_active=True).all()
    
    return render_template('trainings/list.html',
                         trainings=trainings.items,
                         categories=categories,
                         pagination=trainings)

@bp.route('/my')
@login_required
def my_trainings():
    """Мои тренировки"""
    status = request.args.get('status', 'upcoming')
    page = request.args.get('page', 1, type=int)
    
    # Время сейчас
    now = datetime.utcnow()
    
    # Предстоящие тренировки
    upcoming_query = TrainingRegistration.query.filter_by(
        user_id=current_user.id,
        status='registered'  # Только активные регистрации
    ).join(Training).filter(
        Training.schedule_time > now  # Будущие тренировки
    ).order_by(Training.schedule_time.asc())
    
    upcoming_count = upcoming_query.count()
    
    # Для пагинации используем все предстоящие тренировки
    upcoming_pagination = upcoming_query.paginate(page=page, per_page=6, error_out=False)
    upcoming_registrations = upcoming_pagination.items
    
    # Прошедшие тренировки
    past_query = TrainingRegistration.query.filter_by(
        user_id=current_user.id
    ).join(Training).filter(
        Training.schedule_time < now
    ).order_by(Training.schedule_time.desc())
    
    past_count = past_query.count()
    past_registrations = past_query.limit(6).all()
    
    # Тренировки, созданные пользователем (для тренеров)
    created_trainings = None
    created_count = 0
    created_pagination = None
    
    if current_user.role in ['trainer', 'admin']:
        created_query = Training.query.filter_by(trainer_user_id=current_user.id)
        created_count = created_query.count()
        created_pagination = created_query.order_by(
            Training.created_at.desc()
        ).paginate(page=page, per_page=6, error_out=False)
        created_trainings = created_pagination.items
    
    # Определяем, что показывать в зависимости от статуса
    if status == 'past':
        return render_template('trainings/my_trainings.html',
                             status=status,
                             upcoming_count=upcoming_count,
                             past_count=past_count,
                             created_count=created_count,
                             past_registrations=past_registrations,
                             title='Прошедшие тренировки')
    
    elif status == 'created':
        return render_template('trainings/my_trainings.html',
                             status=status,
                             upcoming_count=upcoming_count,
                             past_count=past_count,
                             created_count=created_count,
                             created_trainings=created_trainings,
                             pagination=created_pagination,
                             title='Созданные тренировки')
    
    else:  # upcoming (по умолчанию)
        return render_template('trainings/my_trainings.html',
                             status=status,
                             upcoming_count=upcoming_count,
                             past_count=past_count,
                             created_count=created_count,
                             upcoming_registrations=upcoming_registrations,
                             pagination=upcoming_pagination,
                             title='Предстоящие тренировки')

@bp.route('/create', methods=['GET', 'POST'])
@login_required
def create_training():
    """Создание новой тренировки"""
    if current_user.role not in ['trainer', 'admin']:
        flash('Только тренеры и администраторы могут создавать тренировки', 'danger')
        return redirect(url_for('trainings.training_list'))
    
    form = TrainingForm()
    
    # Заполняем категории
    categories = TrainingCategory.query.filter_by(is_active=True).all()
    form.category_id.choices = [(c.id, c.name) for c in categories]
    
    if request.method == 'POST':
        print("Form submitted")  # Отладочное сообщение
        print("Form data:", form.data)  # Посмотрите данные формы
        if form.errors:
            print("Form errors:", form.errors)  # Посмотрите ошибки валидации
            for field, errors in form.errors.items():
                for error in errors:
                    flash(f'{field}: {error}', 'danger')
    
    if form.validate_on_submit():
        print("Form validation passed")  # Отладочное сообщение
        try:
            # Получаем данные из обычных полей формы (не WTForms)
            equipment = request.form.getlist('equipment[]')
            contraindications = request.form.getlist('contraindications[]')
            
            # Очищаем пустые значения
            equipment = [eq.strip() for eq in equipment if eq.strip()]
            contraindications = [c.strip() for c in contraindications if c.strip()]
            
            # Создаем тренировку
            training = Training(
                title=form.title.data,
                description=form.description.data,
                short_description=form.short_description.data,
                trainer_user_id=current_user.id,
                category_id=form.category_id.data,
                training_type=form.training_type.data,
                difficulty=form.difficulty.data,
                intensity=form.intensity.data,
                schedule_time=form.schedule_time.data,
                duration=form.duration.data,
                timezone=form.timezone.data,
                max_participants=form.max_participants.data,
                min_participants=form.min_participants.data,
                age_limit_min=form.age_limit_min.data,
                age_limit_max=form.age_limit_max.data,
                video_link=form.video_link.data,
                meeting_link=form.meeting_link.data,
                materials_link=form.materials_link.data,
                price=form.price.data or 0.0,
                currency=form.currency.data,
                # Используем текстовые поля формы
                medical_contraindications=form.medical_contraindications.data,
                required_equipment=form.required_equipment.data,
                tags=form.tags.data,
                keywords=form.keywords.data,
                language=form.language.data,
                status='draft' if current_user.role == 'trainer' else 'active'
            )
            
            # Если динамические поля не пустые, добавляем их в соответствующие поля
            if equipment:
                if training.required_equipment:
                    training.required_equipment += "\n" + "\n".join(equipment)
                else:
                    training.required_equipment = "\n".join(equipment)
            
            if contraindications:
                if training.medical_contraindications:
                    training.medical_contraindications += "\n" + "\n".join(contraindications)
                else:
                    training.medical_contraindications = "\n".join(contraindications)
            
            db.session.add(training)
            db.session.commit()
            
            flash(f'Тренировка "{training.title}" успешно создана!', 'success')
            return redirect(url_for('trainings.detail', training_id=training.id))
            
        except Exception as e:
            db.session.rollback()
            print(f"Error creating training: {str(e)}")  # Отладочное сообщение
            flash(f'Ошибка при создании тренировки: {str(e)}', 'danger')
    else:
        if request.method == 'POST':
            print("Form validation failed")  # Отладочное сообщение
            print("Errors:", form.errors)  # Детальный вывод ошибок
            flash('Пожалуйста, исправьте ошибки в форме', 'danger')
    
    return render_template('trainings/create.html', form=form, categories=categories)

@bp.route('/<int:training_id>')
@login_required
def detail(training_id):
    """Детальная информация о тренировке"""
    training = Training.query.get_or_404(training_id)
    
    # Увеличиваем счетчик просмотров
    training.increment_views()
    
    # Проверяем, записан ли пользователь
    registration = None
    feedback = None
    if current_user.is_authenticated:
        registration = TrainingRegistration.query.filter_by(
            user_id=current_user.id,
            training_id=training_id
        ).first()
        
        # Проверяем, оставлял ли пользователь отзыв
        feedback = Feedback.query.filter_by(
            user_id=current_user.id,
            training_id=training_id
        ).first()
    
    # Получаем отзывы
    feedbacks = Feedback.query.filter_by(
        training_id=training_id,
        moderation_status='approved'
    ).order_by(Feedback.created_at.desc()).limit(5).all()
    
    # Получаем рейтинги
    ratings_summary = {}
    all_ratings = Rating.query.join(Feedback).filter(
        Feedback.training_id == training_id,
        Feedback.moderation_status == 'approved'
    ).all()
    
    for rating in all_ratings:
        if rating.rating_type not in ratings_summary:
            ratings_summary[rating.rating_type] = {'sum': 0, 'count': 0}
        ratings_summary[rating.rating_type]['sum'] += rating.score
        ratings_summary[rating.rating_type]['count'] += 1
    
    avg_ratings = {}
    for rating_type, data in ratings_summary.items():
        avg_ratings[rating_type] = data['sum'] / data['count'] if data['count'] > 0 else 0
    
    # Парсим JSON данные
    equipment = []
    contraindications = []
    
    if training.required_equipment:
        try:
            equipment = json.loads(training.required_equipment)
        except:
            equipment = [training.required_equipment] if training.required_equipment else []
    
    if training.medical_contraindications:
        try:
            contraindications = json.loads(training.medical_contraindications)
        except:
            contraindications = [training.medical_contraindications] if training.medical_contraindications else []
    
    return render_template('trainings/detail.html',
                         training=training,
                         registration=registration,
                         feedback=feedback,
                         feedbacks=feedbacks,
                         avg_ratings=avg_ratings,
                         equipment=equipment,
                         contraindications=contraindications)

@bp.route('/<int:training_id>/register', methods=['POST'])
@login_required
def register(training_id):
    """Запись на тренировку"""
    training = Training.query.get_or_404(training_id)
    
    # Проверки
    if training.trainer_user_id == current_user.id:
        flash('Вы не можете записаться на свою собственную тренировку', 'danger')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    if training.is_full:
        flash('На эту тренировку нет свободных мест', 'danger')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    if not training.is_upcoming:
        flash('Нельзя записаться на прошедшую тренировку', 'danger')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    # Проверка накладки времени
    conflicting_training = training.check_time_conflict(current_user.id)
    if conflicting_training:
        flash(f'У вас уже есть тренировка в это время: {conflicting_training.title}', 'danger')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    # Проверка существующей регистрации
    existing_registration = TrainingRegistration.query.filter_by(
        user_id=current_user.id,
        training_id=training_id
    ).first()
    
    # Если есть активная регистрация
    if existing_registration and existing_registration.status == 'registered':
        flash('Вы уже записаны на эту тренировку', 'info')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    # Если регистрация отменена, АКТИВИРУЕМ ее снова
    if existing_registration and existing_registration.status == 'cancelled':
        existing_registration.status = 'registered'
        existing_registration.cancelled_at = None
        existing_registration.cancellation_reason = None
        
        db.session.commit()
        flash('Ваша запись восстановлена!', 'success')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    # Создание новой регистрации (если нет регистрации)
    registration = TrainingRegistration(
        user_id=current_user.id,
        training_id=training_id,
        payment_amount=training.price
    )
    
    db.session.add(registration)
    training.registrations_count += 1
    db.session.commit()
    
    flash(f'Вы успешно записались на тренировку "{training.title}"!', 'success')
    return redirect(url_for('trainings.detail', training_id=training_id))

@bp.route('/<int:training_id>/cancel', methods=['POST'])
@login_required
def cancel_registration(training_id):
    """Отмена записи на тренировку"""
    registration = TrainingRegistration.query.filter_by(
        user_id=current_user.id,
        training_id=training_id
    ).first_or_404()
    
    # Проверяем, что регистрация активна
    if registration.status != 'registered':
        flash('Эта регистрация уже не активна', 'danger')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    # Проверяем, можно ли отменить регистрацию
    cancellation_deadline = registration.training.schedule_time - timedelta(hours=1)
    if datetime.utcnow() >= cancellation_deadline:
        flash('Слишком поздно для отмены регистрации', 'danger')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    # Меняем статус на 'cancelled'
    registration.status = 'cancelled'
    registration.cancelled_at = datetime.utcnow()
    registration.cancellation_reason = 'Отменено пользователем'
    
    db.session.commit()
    
    flash('Регистрация на тренировку отменена', 'success')
    return redirect(url_for('trainings.detail', training_id=training_id))

@bp.route('/<int:training_id>/feedback', methods=['POST'])
@login_required
def add_feedback(training_id):
    """Добавление отзыва"""
    training = Training.query.get_or_404(training_id)
    
    # Проверяем, посещал ли пользователь тренировку
    registration = TrainingRegistration.query.filter_by(
        user_id=current_user.id,
        training_id=training_id,
        status='attended'
    ).first()
    
    if not registration:
        flash('Вы не можете оставить отзыв на тренировку, которую не посетили', 'danger')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    # Проверяем, не оставлял ли уже отзыв
    existing_feedback = Feedback.query.filter_by(
        user_id=current_user.id,
        training_id=training_id
    ).first()
    
    if existing_feedback:
        flash('Вы уже оставили отзыв на эту тренировку', 'info')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    # Получаем данные из формы
    comment = request.form.get('comment')
    rating = request.form.get('rating', type=float)
    
    if not comment or not rating:
        flash('Заполните все обязательные поля', 'danger')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    # Создаем отзыв
    feedback = Feedback(
        user_id=current_user.id,
        training_id=training_id,
        comment=comment,
        moderation_status='pending'
    )
    
    # Создаем рейтинг
    rating_obj = Rating(
        feedback=feedback,
        rating_type='overall',
        score=rating
    )
    
    db.session.add(feedback)
    db.session.add(rating_obj)
    db.session.commit()
    
    flash('Спасибо за ваш отзыв! Он будет опубликован после проверки.', 'success')
    return redirect(url_for('trainings.detail', training_id=training_id))

@bp.route('/calendar')
@login_required
def calendar():
    """Календарь тренировок"""
    # Получаем месяц и год из запроса
    year = request.args.get('year', datetime.now().year, type=int)
    month = request.args.get('month', datetime.now().month, type=int)
    
    # Начало и конец месяца
    start_date = datetime(year, month, 1)
    if month == 12:
        end_date = datetime(year + 1, 1, 1)
    else:
        end_date = datetime(year, month + 1, 1)
    
    # Тренировки пользователя в этом месяце
    user_trainings = Training.query.join(TrainingRegistration).filter(
        TrainingRegistration.user_id == current_user.id,
        Training.schedule_time >= start_date,
        Training.schedule_time < end_date,
        TrainingRegistration.status == 'registered'
    ).all()
    
    # Группируем тренировки по дням
    training_by_date = {}
    for training in user_trainings:
        day = training.schedule_time.date()
        if day not in training_by_date:
            training_by_date[day] = []
        training_by_date[day].append(training)
    
    return render_template('trainings/calendar.html',
                         year=year,
                         month=month,
                         training_by_date=training_by_date)

# Добавим новый маршрут для одобрения тренировок
@bp.route('/<int:training_id>/approve', methods=['POST'])
@login_required
def approve_training(training_id):
    """Одобрение тренировки (для админа)"""
    if current_user.role != 'admin':
        flash('Только администраторы могут одобрять тренировки', 'danger')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    training = Training.query.get_or_404(training_id)
    
    # Меняем статус на 'active' или 'approved'
    training.status = 'active'  # или 'approved', в зависимости от вашей модели
    
    # Если есть поле для отметки об одобрении
    training.approved_by = current_user.id
    training.approved_at = datetime.utcnow()
    training.is_visible = True  # Делаем видимой для клиентов
    
    # Отправляем уведомление тренеру
    # send_notification(training.trainer_user_id, 'training_approved', training.id)
    
    db.session.commit()
    
    flash(f'Тренировка "{training.title}" одобрена и теперь видна клиентам!', 'success')
    return redirect(url_for('trainings.detail', training_id=training_id))

@bp.route('/<int:training_id>/reject', methods=['POST'])
@login_required
def reject_training(training_id):
    """Отклонение тренировки (для админа)"""
    if current_user.role != 'admin':
        flash('Только администраторы могут отклонять тренировки', 'danger')
        return redirect(url_for('trainings.detail', training_id=training_id))
    
    training = Training.query.get_or_404(training_id)
    
    # Получаем причину отклонения
    reason = request.form.get('reason', 'Тренировка не соответствует требованиям')
    
    # Меняем статус
    training.status = 'rejected'
    training.rejection_reason = reason
    training.rejected_by = current_user.id
    training.rejected_at = datetime.utcnow()
    training.is_visible = False
    
    # Отправляем уведомление тренеру
    # send_notification(training.trainer_user_id, 'training_rejected', training.id, reason=reason)
    
    db.session.commit()
    
    flash(f'Тренировка "{training.title}" отклонена', 'success')
    return redirect(url_for('trainings.detail', training_id=training_id))

@bp.route('/admin/pending')
@login_required
def admin_pending_trainings():
    """Страница с тренировками на проверку (для админа)"""
    if current_user.role != 'admin':
        flash('Доступ запрещен', 'danger')
        return redirect(url_for('main.index'))
    
    page = request.args.get('page', 1, type=int)
    
    # Тренировки на проверке
    pending_trainings = Training.query.filter(
        Training.status.in_(['draft', 'pending'])
    ).order_by(Training.created_at.desc()).paginate(page=page, per_page=10)
    
    return render_template('trainings/admin/pending.html',
                         trainings=pending_trainings.items,
                         pagination=pending_trainings)

@bp.route('/api/calendar')
@login_required
def api_calendar():
    """API для календаря (FullCalendar)"""
    start = request.args.get('start')
    end = request.args.get('end')
    
    try:
        start_date = datetime.fromisoformat(start.replace('Z', '+00:00'))
        end_date = datetime.fromisoformat(end.replace('Z', '+00:00'))
    except:
        return jsonify([])
    
    # Тренировки пользователя
    user_trainings = Training.query.join(TrainingRegistration).filter(
        TrainingRegistration.user_id == current_user.id,
        Training.schedule_time >= start_date,
        Training.schedule_time < end_date,
        TrainingRegistration.status == 'registered'
    ).all()
    
    events = []
    for training in user_trainings:
        events.append({
            'id': training.id,
            'title': training.title,
            'start': training.schedule_time.isoformat(),
            'end': training.end_time.isoformat(),
            'color': '#4e73df',
            'url': url_for('trainings.detail', training_id=training.id),
            'extendedProps': {
                'trainer': training.trainer_user.username,
                'type': training.training_type
            }
        })

    
    return jsonify(events)