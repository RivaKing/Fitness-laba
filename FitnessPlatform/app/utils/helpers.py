"""
Вспомогательные функции
"""
"""
Вспомогательные функции
"""
import hashlib
import random
import string
import re
from datetime import datetime, timedelta, date
from flask import request, url_for, current_app
import pytz
import json

def get_pending_trainings_count(user=None):
    """Возвращает количество тренировок на проверке"""
    # Если передали пользователя, используем его
    # Иначе импортируем current_user
    if user is None:
        try:
            from flask_login import current_user
            user = current_user
        except:
            return 0
    
    if user.is_authenticated and user.role == 'admin':
        try:
            from app.models.training import Training
            return Training.query.filter(
                Training.status.in_(['draft', 'pending'])
            ).count()
        except Exception as e:
            current_app.logger.error(f'Error getting pending trainings count: {e}')
            return 0
    return 0

# Остальные функции остаются без изменений

def generate_password(length=12):
    """Генерация случайного пароля"""
    chars = string.ascii_letters + string.digits + "!@#$%^&*"
    return ''.join(random.choice(chars) for _ in range(length))

def hash_string(text):
    """Хеширование строки"""
    return hashlib.sha256(text.encode()).hexdigest()

def validate_email(email):
    """Валидация email"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

def validate_phone(phone):
    """Валидация телефона"""
    # Простая валидация для российских номеров
    pattern = r'^\+?7\d{10}$|^8\d{10}$|^\d{10,11}$'
    return re.match(pattern, phone) is not None

def format_datetime(dt, format_str='%d.%m.%Y %H:%M'):
    """Форматирование даты и времени"""
    if dt is None:
        return ''
    
    if isinstance(dt, str):
        dt = datetime.fromisoformat(dt.replace('Z', '+00:00'))
    
    return dt.strftime(format_str)

def format_duration(minutes):
    """Форматирование длительности"""
    if minutes is None:
        return ''
    
    hours = minutes // 60
    mins = minutes % 60
    
    if hours > 0:
        return f"{hours} ч {mins} мин"
    else:
        return f"{mins} мин"

def calculate_age(birth_date):
    """Расчет возраста по дате рождения"""
    if not birth_date:
        return None
    
    today = datetime.now().date()
    age = today.year - birth_date.year
    
    # Проверяем, был ли уже день рождения в этом году
    if (today.month, today.day) < (birth_date.month, birth_date.day):
        age -= 1
    
    return age

def paginate_query(query, page, per_page=20):
    """Пагинация запроса"""
    return query.paginate(page=page, per_page=per_page, error_out=False)

def get_client_timezone():
    """Получение часового пояса клиента"""
    # Пытаемся определить по заголовку
    tz_header = request.headers.get('X-Timezone')
    if tz_header:
        try:
            return pytz.timezone(tz_header)
        except pytz.exceptions.UnknownTimeZoneError:
            pass
    
    # По умолчанию московское время
    return pytz.timezone('Europe/Moscow')

def convert_timezone(dt, from_tz='UTC', to_tz='Europe/Moscow'):
    """Конвертация времени между часовыми поясами"""
    try:
        from_tz_obj = pytz.timezone(from_tz)
        to_tz_obj = pytz.timezone(to_tz)
        
        if dt.tzinfo is None:
            dt = from_tz_obj.localize(dt)
        
        return dt.astimezone(to_tz_obj)
    except Exception:
        return dt

def sanitize_filename(filename):
    """Очистка имени файла от небезопасных символов"""
    # Удаляем небезопасные символы
    filename = re.sub(r'[^\w\-_.]', '_', filename)
    # Ограничиваем длину
    if len(filename) > 255:
        name, ext = filename.rsplit('.', 1)
        filename = name[:255 - len(ext) - 1] + '.' + ext
    return filename

def calculate_bmi(weight_kg, height_cm):
    """Расчет индекса массы тела (ИМТ)"""
    if not weight_kg or not height_cm or height_cm == 0:
        return None
    
    height_m = height_cm / 100
    bmi = weight_kg / (height_m ** 2)
    return round(bmi, 2)

def get_bmi_category(bmi):
    """Категория ИМТ"""
    if bmi is None:
        return None
    
    if bmi < 18.5:
        return 'Недостаточный вес'
    elif 18.5 <= bmi < 25:
        return 'Нормальный вес'
    elif 25 <= bmi < 30:
        return 'Избыточный вес'
    else:
        return 'Ожирение'

def calculate_calories(weight_kg, height_cm, age, gender, activity_level=1.2):
    """
    Расчет дневной нормы калорий (формула Миффлина-Сан Жеора)
    """
    if gender.lower() == 'male':
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
    else:  # female
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161
    
    return round(bmr * activity_level)

def truncate_text(text, max_length=100, suffix='...'):
    """Обрезка текста с добавлением суффикса"""
    if len(text) <= max_length:
        return text
    return text[:max_length - len(suffix)] + suffix

def generate_verification_code(length=6):
    """Генерация кода подтверждения"""
    return ''.join(random.choice(string.digits) for _ in range(length))

def is_safe_url(url):
    """Проверка безопасного URL для редиректа"""
    from urllib.parse import urlparse, urljoin
    
    ref_url = urlparse(request.host_url)
    test_url = urlparse(urljoin(request.host_url, url))
    
    return test_url.scheme in ('http', 'https') and \
           ref_url.netloc == test_url.netloc

def json_serial(obj):
    """Сериализатор для JSON для datetime объектов"""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")

def to_json(data):
    """Конвертация в JSON с поддержкой datetime"""
    return json.dumps(data, default=json_serial, ensure_ascii=False)

def get_pending_trainings_count(user=None):
    """Возвращает количество тренировок на проверке"""
    if user is None:
        try:
            from flask_login import current_user
            user = current_user
        except:
            return 0
    
    if user.is_authenticated and user.role == 'admin':
        try:
            from app.models.training import Training
            return Training.query.filter(
                Training.status.in_(['draft', 'pending'])
            ).count()
        except Exception as e:
            # Логируем ошибку, но возвращаем 0
            from flask import current_app
            current_app.logger.error(f'Error getting pending trainings count: {e}')
            return 0
    return 0

