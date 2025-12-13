"""
Декораторы для проверки прав доступа
"""
from functools import wraps
from flask import flash, redirect, url_for, abort, current_app, request
from flask_login import current_user
import logging

logger = logging.getLogger(__name__)

def role_required(required_roles):
    """
    Декоратор для проверки ролей пользователя
    
    Args:
        required_roles: строка или список ролей, которые имеют доступ
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not current_user.is_authenticated:
                flash('Для доступа к этой странице необходимо войти в систему', 'warning')
                return redirect(url_for('auth.login', next=request.url))
            
            # Преобразуем в список, если передана строка
            if isinstance(required_roles, str):
                allowed_roles = [required_roles]
            else:
                allowed_roles = required_roles
            
            # Проверяем роль пользователя
            if current_user.role not in allowed_roles:
                logger.warning(
                    f'Unauthorized access attempt: user {current_user.id} '
                    f'({current_user.role}) tried to access {request.path}'
                )
                flash('У вас нет прав для доступа к этой странице', 'danger')
                abort(403)
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def admin_required(f):
    """Декоратор для проверки прав администратора"""
    return role_required('admin')(f)

def trainer_required(f):
    """Декоратор для проверки прав тренера"""
    return role_required('trainer')(f)

def client_required(f):
    """Декоратор для проверки прав клиента"""
    return role_required('client')(f)

def log_action(action_name):
    """
    Декоратор для логирования действий пользователя
    
    Args:
        action_name: название действия для логирования
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            try:
                result = f(*args, **kwargs)
                
                # Логируем успешное действие
                if current_user.is_authenticated:
                    logger.info(
                        f'User {current_user.id} ({current_user.role}) '
                        f'performed action: {action_name}'
                    )
                
                return result
            except Exception as e:
                # Логируем ошибку
                logger.error(
                    f'Error in action {action_name}: {str(e)} '
                    f'User: {current_user.id if current_user.is_authenticated else "Anonymous"}'
                )
                raise
        return decorated_function
    return decorator

def validate_json(*required_fields):
    """
    Декоратор для валидации JSON данных в запросе
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not request.is_json:
                return {'error': 'Content-Type должен быть application/json'}, 400
            
            data = request.get_json()
            if data is None:
                return {'error': 'Невалидный JSON'}, 400
            
            # Проверяем обязательные поля
            for field in required_fields:
                if field not in data:
                    return {'error': f'Отсутствует обязательное поле: {field}'}, 400
            
            # Добавляем данные в kwargs для использования в функции
            kwargs['json_data'] = data
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def rate_limit(requests_per_minute=60):
    """
    Простой декоратор для ограничения количества запросов
    В реальном приложении используй Redis или другую систему
    """
    from datetime import datetime, timedelta
    
    requests = {}
    
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not current_app.config.get('DEBUG'):
                # Получаем IP пользователя
                ip = request.remote_addr
                now = datetime.now()
                
                # Очищаем старые записи
                requests[ip] = [
                    timestamp for timestamp in requests.get(ip, [])
                    if now - timestamp < timedelta(minutes=1)
                ]
                
                # Проверяем лимит
                if len(requests.get(ip, [])) >= requests_per_minute:
                    logger.warning(f'Rate limit exceeded for IP: {ip}')
                    return {'error': 'Слишком много запросов. Попробуйте позже.'}, 429
                
                # Добавляем текущий запрос
                requests.setdefault(ip, []).append(now)
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def cache_response(timeout=300):
    """
    Декоратор для кэширования ответов
    """
    from functools import lru_cache
    import hashlib
    
    def decorator(f):
        @wraps(f)
        @lru_cache(maxsize=128)
        def cached_function(*args, **kwargs):
            return f(*args, **kwargs)
        
        def decorated_function(*args, **kwargs):
            # В реальном приложении используй Redis или Memcached
            # Здесь простое in-memory кэширование через lru_cache
            cache_key = hashlib.md5(
                f"{request.path}{request.args}{current_user.id if current_user.is_authenticated else 'anonymous'}".encode()
            ).hexdigest()
            
            return cached_function(*args, **kwargs)
        
        return decorated_function
    return decorator

def handle_exceptions(f):
    """
    Декоратор для обработки исключений
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except Exception as e:
            logger.error(f'Unhandled exception: {str(e)}', exc_info=True)
            
            if request.is_json:
                return {
                    'error': 'Внутренняя ошибка сервера',
                    'message': str(e) if current_app.debug else 'Обратитесь к администратору'
                }, 500
            else:
                flash('Произошла ошибка. Пожалуйста, попробуйте позже.', 'danger')
                return redirect(url_for('main.index'))
    
    return decorated_function