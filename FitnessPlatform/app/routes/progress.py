"""
Маршруты для отслеживания прогресса
"""

from flask import Blueprint, render_template, redirect, url_for, flash, request, jsonify, current_app
from flask_login import login_required, current_user
from sqlalchemy import func, desc, extract
from datetime import datetime, date, timedelta
import logging
import json

from app import db
from app.forms.progress import ProgressEntryForm, GoalForm, ProgressFilterForm
from app.models import Progress, Goal, Achievement, ProgressMetric, TrainingRegistration
from app.utils.decorators import role_required

bp = Blueprint('progress', __name__, url_prefix='/progress')

# Настройка логирования
logger = logging.getLogger(__name__)

@bp.route('/')
@login_required
def dashboard():
    """Дашборд прогресса пользователя"""
    
    # Получение временных диапазонов
    today = date.today()
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)
    year_ago = today - timedelta(days=365)
    
    # Общая статистика
    total_activities = Progress.query.filter_by(user_id=current_user.id).count()
    total_calories = db.session.query(func.coalesce(func.sum(Progress.calories_burned), 0)).filter(
        Progress.user_id == current_user.id
    ).scalar()
    total_distance = db.session.query(func.coalesce(func.sum(Progress.distance), 0)).filter(
        Progress.user_id == current_user.id
    ).scalar()
    total_duration = db.session.query(func.coalesce(func.sum(Progress.duration), 0)).filter(
        Progress.user_id == current_user.id
    ).scalar()
    
    # Статистика за последнюю неделю
    week_stats = db.session.query(
        func.count(Progress.id).label('activities'),
        func.coalesce(func.sum(Progress.calories_burned), 0).label('calories'),
        func.coalesce(func.sum(Progress.distance), 0).label('distance'),
        func.coalesce(func.sum(Progress.duration), 0).label('duration')
    ).filter(
        Progress.user_id == current_user.id,
        Progress.date >= week_ago
    ).first()
    
    # Последние активности
    recent_activities = Progress.query.filter_by(
        user_id=current_user.id
    ).order_by(Progress.date.desc(), Progress.created_at.desc()).limit(5).all()
    
    # Цели
    active_goals = Goal.query.filter_by(
        user_id=current_user.id,
        status='active'
    ).order_by(Goal.target_date).limit(5).all()
    
    # Достижения
    recent_achievements = Achievement.query.filter_by(
        user_id=current_user.id
    ).order_by(Achievement.unlocked_at.desc() if Achievement.unlocked_at else Achievement.created_at.desc()).limit(5).all()
    
    # График активности за последний месяц
    monthly_activities = db.session.query(
        Progress.date,
        func.count(Progress.id).label('count'),
        func.coalesce(func.sum(Progress.duration), 0).label('duration'),
        func.coalesce(func.sum(Progress.calories_burned), 0).label('calories')
    ).filter(
        Progress.user_id == current_user.id,
        Progress.date >= month_ago
    ).group_by(Progress.date).order_by(Progress.date).all()
    
    # Подготовка данных для графика
    chart_labels = [a.date.strftime('%d.%m') for a in monthly_activities]
    chart_duration = [a.duration for a in monthly_activities]
    chart_calories = [a.calories for a in monthly_activities]
    
    return render_template(
        'progress/dashboard.html',
        total_activities=total_activities,
        total_calories=total_calories,
        total_distance=total_distance,
        total_duration=total_duration,
        week_stats=week_stats,
        recent_activities=recent_activities,
        active_goals=active_goals,
        recent_achievements=recent_achievements,
        chart_labels=chart_labels,
        chart_duration=chart_duration,
        chart_calories=chart_calories,
        title='Мой прогресс'
    )

@bp.route('/add', methods=['GET', 'POST'])
@login_required
def add_progress():
    """Добавление записи о прогрессе"""
    form = ProgressEntryForm()
    
    if form.validate_on_submit():
        try:
            # Проверка существующей записи на эту дату
            existing_entry = Progress.query.filter_by(
                user_id=current_user.id,
                date=form.date.data,
                activity_type=form.activity_type.data
            ).first()
            
            if existing_entry:
                flash('Запись с таким типом активности на эту дату уже существует', 'warning')
                return redirect(url_for('progress.add_progress'))
            
            # Создание записи
            progress = Progress(
                user_id=current_user.id,
                date=form.date.data,
                activity_type=form.activity_type.data,
                duration=form.duration.data,
                calories_burned=form.calories_burned.data,
                distance=form.distance.data,
                weight=form.weight.data,
                body_fat_percentage=form.body_fat_percentage.data,
                muscle_mass=form.muscle_mass.data,
                resting_heart_rate=form.resting_heart_rate.data,
                blood_pressure_systolic=form.blood_pressure_systolic.data,
                blood_pressure_diastolic=form.blood_pressure_diastolic.data,
                sleep_duration=form.sleep_duration.data,
                sleep_quality=form.sleep_quality.data,
                energy_level=form.energy_level.data,
                mood=form.mood.data,
                stress_level=form.stress_level.data,
                notes=form.notes.data,
                location=form.location.data,
                weather=form.weather.data,
                source=form.source.data
            )
            
            db.session.add(progress)
            db.session.commit()
            
            # Проверка достижения целей
            check_goals_for_progress(progress)
            
            flash('Запись о прогрессе успешно добавлена!', 'success')
            return redirect(url_for('progress.dashboard'))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Progress entry creation error: {str(e)}')
            flash('Ошибка при добавлении записи о прогрессе', 'danger')
    
    return render_template(
        'progress/add.html',
        form=form,
        title='Добавить запись о прогрессе'
    )

@bp.route('/history')
@login_required
def history():
    """История прогресса"""
    form = ProgressFilterForm(request.args)
    
    # Базовый запрос
    query = Progress.query.filter_by(user_id=current_user.id)
    
    # Применение фильтров
    if form.date_from.data:
        query = query.filter(Progress.date >= form.date_from.data)
    
    if form.date_to.data:
        query = query.filter(Progress.date <= form.date_to.data)
    
    if form.activity_type.data:
        query = query.filter_by(activity_type=form.activity_type.data)
    
    if form.min_duration.data is not None:
        query = query.filter(Progress.duration >= form.min_duration.data)
    
    if form.max_duration.data is not None:
        query = query.filter(Progress.duration <= form.max_duration.data)
    
    if form.min_calories.data is not None:
        query = query.filter(Progress.calories_burned >= form.min_calories.data)
    
    if form.max_calories.data is not None:
        query = query.filter(Progress.calories_burned <= form.max_calories.data)
    
    if form.min_distance.data is not None:
        query = query.filter(Progress.distance >= form.min_distance.data)
    
    if form.max_distance.data is not None:
        query = query.filter(Progress.distance <= form.max_distance.data)
    
    # Сортировка
    sort_column = {
        'date': Progress.date,
        'duration': Progress.duration,
        'calories_burned': Progress.calories_burned,
        'distance': Progress.distance
    }.get(form.sort_by.data, Progress.date)
    
    if form.sort_order.data == 'desc':
        sort_column = sort_column.desc()
    
    query = query.order_by(sort_column)
    
    # Пагинация
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    progress_entries = query.paginate(page=page, per_page=per_page, error_out=False)
    
    # Статистика по фильтру
    stats = {
        'count': query.count(),
        'total_duration': db.session.query(func.coalesce(func.sum(Progress.duration), 0)).filter(
            Progress.user_id == current_user.id,
            *query.whereclause
        ).scalar(),
        'total_calories': db.session.query(func.coalesce(func.sum(Progress.calories_burned), 0)).filter(
            Progress.user_id == current_user.id,
            *query.whereclause
        ).scalar(),
        'total_distance': db.session.query(func.coalesce(func.sum(Progress.distance), 0)).filter(
            Progress.user_id == current_user.id,
            *query.whereclause
        ).scalar()
    }
    
    return render_template(
        'progress/history.html',
        progress_entries=progress_entries,
        form=form,
        stats=stats,
        title='История прогресса'
    )

@bp.route('/goals')
@login_required
def goals():
    """Цели пользователя"""
    status_filter = request.args.get('status', 'active')
    
    # Базовый запрос
    query = Goal.query.filter_by(user_id=current_user.id)
    
    # Фильтр по статусу
    if status_filter != 'all':
        query = query.filter_by(status=status_filter)
    
    # Сортировка
    query = query.order_by(
        Goal.status,
        Goal.target_date,
        Goal.created_at.desc()
    )
    
    goals_list = query.all()
    
    # Статистика по целям
    stats = {
        'total': Goal.query.filter_by(user_id=current_user.id).count(),
        'active': Goal.query.filter_by(user_id=current_user.id, status='active').count(),
        'completed': Goal.query.filter_by(user_id=current_user.id, status='completed').count(),
        'failed': Goal.query.filter_by(user_id=current_user.id, status='failed').count(),
        'average_progress': db.session.query(func.avg(Goal.progress_percentage)).filter(
            Goal.user_id == current_user.id,
            Goal.status == 'active'
        ).scalar() or 0
    }
    
    return render_template(
        'progress/goals.html',
        goals=goals_list,
        status_filter=status_filter,
        stats=stats,
        title='Мои цели'
    )

@bp.route('/goals/add', methods=['GET', 'POST'])
@login_required
def add_goal():
    """Добавление новой цели"""
    form = GoalForm()
    
    if form.validate_on_submit():
        try:
            goal = Goal(
                user_id=current_user.id,
                title=form.title.data,
                description=form.description.data,
                goal_type=form.goal_type.data,
                target_value=form.target_value.data,
                unit=form.unit.data,
                start_date=form.start_date.data,
                target_date=form.target_date.data,
                is_recurring=form.is_recurring.data,
                recurrence_pattern=form.recurrence_pattern.data if form.is_recurring.data else None,
                motivation=form.motivation.data,
                rewards=form.rewards.data,
                reminder_enabled=form.reminder_enabled.data,
                reminder_frequency=form.reminder_frequency.data if form.reminder_enabled.data else None,
                status='active'
            )
            
            db.session.add(goal)
            db.session.commit()
            
            flash('Цель успешно добавлена!', 'success')
            return redirect(url_for('progress.goals'))
            
        except Exception as e:
            db.session.rollback()
            logger.error(f'Goal creation error: {str(e)}')
            flash('Ошибка при добавлении цели', 'danger')
    
    return render_template(
        'progress/add_goal.html',
        form=form,
        title='Добавить цель'
    )

@bp.route('/goals/<int:goal_id>')
@login_required
def goal_detail(goal_id):
    """Детальная информация о цели"""
    goal = Goal.query.get_or_404(goal_id)
    
    # Проверка прав доступа
    if goal.user_id != current_user.id:
        flash('У вас нет прав для просмотра этой цели', 'danger')
        return redirect(url_for('progress.goals'))
    
    # Прогресс по цели
    progress_entries = Progress.query.filter_by(
        user_id=current_user.id
    ).filter(
        Progress.date.between(goal.start_date, goal.target_date)
    ).order_by(Progress.date).all()
    
    # Рассчет прогресса на основе данных
    if goal.goal_type == 'weight_loss' and goal.target_value:
        current_weight = Progress.query.filter_by(
            user_id=current_user.id
        ).filter(
            Progress.weight.isnot(None),
            Progress.date <= date.today()
        ).order_by(Progress.date.desc()).first()
        
        if current_weight and current_weight.weight:
            goal.current_value = current_weight.weight
            goal.update_progress()
    
    return render_template(
        'progress/goal_detail.html',
        goal=goal,
        progress_entries=progress_entries,
        title=goal.title
    )

@bp.route('/goals/<int:goal_id>/update-progress', methods=['POST'])
@login_required
def update_goal_progress(goal_id):
    """Обновление прогресса цели"""
    goal = Goal.query.get_or_404(goal_id)
    
    # Проверка прав доступа
    if goal.user_id != current_user.id:
        return jsonify({'success': False, 'message': 'Доступ запрещен'}), 403
    
    try:
        new_value = request.json.get('current_value')
        if new_value is not None:
            goal.current_value = float(new_value)
            goal.update_progress()
            db.session.commit()
            
            return jsonify({
                'success': True,
                'progress_percentage': goal.progress_percentage,
                'is_on_track': goal.is_on_track()
            })
        else:
            return jsonify({'success': False, 'message': 'Не указано значение'}), 400
            
    except Exception as e:
        db.session.rollback()
        logger.error(f'Goal progress update error: {str(e)}')
        return jsonify({'success': False, 'message': 'Ошибка при обновлении прогресса'}), 500

@bp.route('/achievements')
@login_required
def achievements():
    """Достижения пользователя"""
    achievements_list = Achievement.query.filter_by(
        user_id=current_user.id
    ).order_by(
        Achievement.unlocked_at.desc() if Achievement.unlocked_at else Achievement.created_at.desc()
    ).all()
    
    # Группировка по типу
    achievements_by_type = {}
    for achievement in achievements_list:
        if achievement.achievement_type not in achievements_by_type:
            achievements_by_type[achievement.achievement_type] = []
        achievements_by_type[achievement.achievement_type].append(achievement)
    
    # Общая статистика
    total_points = db.session.query(func.sum(Achievement.points)).filter(
        Achievement.user_id == current_user.id
    ).scalar() or 0
    
    total_achievements = len(achievements_list)
    
    return render_template(
        'progress/achievements.html',
        achievements_by_type=achievements_by_type,
        total_points=total_points,
        total_achievements=total_achievements,
        title='Мои достижения'
    )

@bp.route('/statistics')
@login_required
def statistics():
    """Подробная статистика"""
    # Временные диапазоны
    today = date.today()
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)
    year_ago = today - timedelta(days=365)
    
    # Агрегированная статистика по типам активности
    activity_stats = db.session.query(
        Progress.activity_type,
        func.count(Progress.id).label('count'),
        func.coalesce(func.sum(Progress.duration), 0).label('total_duration'),
        func.coalesce(func.sum(Progress.calories_burned), 0).label('total_calories'),
        func.coalesce(func.sum(Progress.distance), 0).label('total_distance')
    ).filter(
        Progress.user_id == current_user.id,
        Progress.date >= month_ago
    ).group_by(Progress.activity_type).all()
    
    # Еженедельная активность
    weekly_data = []
    for i in range(12):  # Последние 12 недель
        week_start = today - timedelta(weeks=i+1)
        week_end = today - timedelta(weeks=i)
        
        week_stats = db.session.query(
            func.coalesce(func.sum(Progress.duration), 0).label('duration'),
            func.coalesce(func.sum(Progress.calories_burned), 0).label('calories')
        ).filter(
            Progress.user_id == current_user.id,
            Progress.date.between(week_start, week_end)
        ).first()
        
        weekly_data.append({
            'week': week_start.strftime('%d.%m'),
            'duration': week_stats.duration,
            'calories': week_stats.calories
        })
    
    weekly_data.reverse()  # От старых к новым
    
    # Тренды веса (если есть данные)
    weight_data = Progress.query.filter(
        Progress.user_id == current_user.id,
        Progress.weight.isnot(None)
    ).order_by(Progress.date).all()
    
    weight_trend = [{'date': w.date.strftime('%d.%m'), 'weight': w.weight} for w in weight_data]
    
    # Лучшие результаты
    best_duration = Progress.query.filter_by(user_id=current_user.id).order_by(
        Progress.duration.desc()
    ).first()
    
    best_calories = Progress.query.filter_by(user_id=current_user.id).order_by(
        Progress.calories_burned.desc()
    ).first()
    
    best_distance = Progress.query.filter_by(user_id=current_user.id).order_by(
        Progress.distance.desc()
    ).first()
    
    return render_template(
        'progress/statistics.html',
        activity_stats=activity_stats,
        weekly_data=weekly_data,
        weight_trend=weight_trend,
        best_duration=best_duration,
        best_calories=best_calories,
        best_distance=best_distance,
        title='Статистика'
    )

@bp.route('/api/chart-data')
@login_required
def chart_data():
    """API данных для графиков"""
    chart_type = request.args.get('type', 'weekly')
    
    if chart_type == 'weekly':
        # Данные за последние 4 недели
        data = []
        for i in range(4):
            week_start = date.today() - timedelta(weeks=i+1)
            week_end = date.today() - timedelta(weeks=i)
            
            week_stats = db.session.query(
                func.coalesce(func.sum(Progress.duration), 0).label('duration'),
                func.coalesce(func.sum(Progress.calories_burned), 0).label('calories'),
                func.coalesce(func.sum(Progress.distance), 0).label('distance')
            ).filter(
                Progress.user_id == current_user.id,
                Progress.date.between(week_start, week_end)
            ).first()
            
            data.append({
                'week': week_start.strftime('%d.%m'),
                'duration': week_stats.duration,
                'calories': week_stats.calories,
                'distance': week_stats.distance
            })
        
        data.reverse()
        return jsonify(data)
    
    elif chart_type == 'activity_types':
        # Распределение по типам активности
        stats = db.session.query(
            Progress.activity_type,
            func.count(Progress.id).label('count'),
            func.coalesce(func.sum(Progress.duration), 0).label('duration')
        ).filter(
            Progress.user_id == current_user.id,
            Progress.date >= date.today() - timedelta(days=30)
        ).group_by(Progress.activity_type).all()
        
        data = [{
            'type': stat.activity_type,
            'count': stat.count,
            'duration': stat.duration
        } for stat in stats]
        
        return jsonify(data)
    
    elif chart_type == 'weight_trend':
        # Тренд веса
        weight_data = Progress.query.filter(
            Progress.user_id == current_user.id,
            Progress.weight.isnot(None)
        ).order_by(Progress.date).all()
        
        data = [{
            'date': w.date.strftime('%Y-%m-%d'),
            'weight': w.weight
        } for w in weight_data]
        
        return jsonify(data)
    
    return jsonify({'error': 'Неизвестный тип графика'}), 400

def check_goals_for_progress(progress):
    """Проверка достижения целей на основе новой записи о прогрессе"""
    try:
        # Получение активных целей пользователя
        active_goals = Goal.query.filter_by(
            user_id=progress.user_id,
            status='active'
        ).all()
        
        for goal in active_goals:
            # Проверка соответствия типа цели типу активности
            if (goal.goal_type == 'running_distance' and progress.activity_type == 'running') or \
               (goal.goal_type == 'cycling_distance' and progress.activity_type == 'cycling') or \
               (goal.goal_type == 'calorie_burn' and progress.calories_burned) or \
               (goal.goal_type == 'weight_loss' and progress.weight):
                
                # Обновление текущего значения
                if goal.goal_type == 'running_distance' or goal.goal_type == 'cycling_distance':
                    if progress.distance:
                        goal.current_value += progress.distance
                elif goal.goal_type == 'calorie_burn':
                    if progress.calories_burned:
                        goal.current_value += progress.calories_burned
                elif goal.goal_type == 'weight_loss':
                    if progress.weight:
                        goal.current_value = progress.weight
                
                goal.update_progress()
                
                # Проверка достижения цели
                if goal.progress_percentage >= 100:
                    create_achievement_for_goal(goal)
        
        db.session.commit()
        
    except Exception as e:
        logger.error(f'Goals check error: {str(e)}')

def create_achievement_for_goal(goal):
    """Создание достижения при выполнении цели"""
    try:
        achievement = Achievement(
            user_id=goal.user_id,
            goal_id=goal.id,
            title=f'Цель достигнута: {goal.title}',
            description=f'Вы достигли цели "{goal.title}"!',
            achievement_type='goal_completion',
            points=100,
            icon='??',
            unlocked_at=datetime.utcnow()
        )
        
        db.session.add(achievement)
        
    except Exception as e:
        logger.error(f'Achievement creation error: {str(e)}')

