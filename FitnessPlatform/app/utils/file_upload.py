"""
Утилиты для загрузки файлов
"""
import os
import uuid
from werkzeug.utils import secure_filename
from PIL import Image
import magic
from flask import current_app
import logging

logger = logging.getLogger(__name__)

ALLOWED_EXTENSIONS = {
    'image': {'png', 'jpg', 'jpeg', 'gif', 'webp'},
    'document': {'pdf', 'doc', 'docx', 'txt'},
    'video': {'mp4', 'avi', 'mov', 'mkv'},
    'audio': {'mp3', 'wav', 'ogg'}
}

def allowed_file(filename, file_type='image'):
    """
    Проверка разрешенных расширений файлов
    
    Args:
        filename: имя файла
        file_type: тип файла (image, document, video, audio)
    
    Returns:
        bool: разрешен ли файл
    """
    if '.' not in filename:
        return False
    
    ext = filename.rsplit('.', 1)[1].lower()
    allowed_extensions = ALLOWED_EXTENSIONS.get(file_type, set())
    
    return ext in allowed_extensions

def generate_unique_filename(filename):
    """
    Генерация уникального имени файла
    
    Args:
        filename: оригинальное имя файла
    
    Returns:
        str: уникальное имя файла
    """
    ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else ''
    unique_id = str(uuid.uuid4())
    
    if ext:
        return f"{unique_id}.{ext}"
    else:
        return unique_id

def save_uploaded_file(file, upload_folder='uploads', file_type='image'):
    """
    Сохранение загруженного файла
    
    Args:
        file: файловый объект из request.files
        upload_folder: папка для сохранения
        file_type: тип файла
    
    Returns:
        dict: информация о сохраненном файле или None в случае ошибки
    """
    if not file or file.filename == '':
        return None
    
    # Проверяем разрешенные расширения
    if not allowed_file(file.filename, file_type):
        logger.warning(f'Invalid file extension: {file.filename}')
        return None
    
    # Создаем безопасное имя файла
    original_filename = secure_filename(file.filename)
    unique_filename = generate_unique_filename(original_filename)
    
    # Создаем папку, если её нет
    upload_path = os.path.join(current_app.config.get('UPLOAD_FOLDER', 'uploads'), upload_folder)
    os.makedirs(upload_path, exist_ok=True)
    
    filepath = os.path.join(upload_path, unique_filename)
    
    try:
        # Сохраняем файл
        file.save(filepath)
        
        # Проверяем MIME-тип
        mime = magic.Magic(mime=True)
        detected_type = mime.from_file(filepath).split('/')[0]
        
        if file_type == 'image' and detected_type != 'image':
            os.remove(filepath)
            logger.warning(f'Invalid MIME type for image: {detected_type}')
            return None
        
        # Для изображений можно дополнительно обработать
        if file_type == 'image':
            optimize_image(filepath)
        
        file_info = {
            'original_filename': original_filename,
            'filename': unique_filename,
            'filepath': filepath,
            'relative_path': os.path.join(upload_folder, unique_filename),
            'size': os.path.getsize(filepath),
            'mime_type': detected_type,
            'extension': original_filename.rsplit('.', 1)[1].lower() if '.' in original_filename else ''
        }
        
        logger.info(f'File uploaded successfully: {file_info["filename"]}')
        return file_info
        
    except Exception as e:
        logger.error(f'Error saving file: {str(e)}')
        # Удаляем файл, если он был частично сохранен
        if os.path.exists(filepath):
            os.remove(filepath)
        return None

def optimize_image(filepath, max_size=(1920, 1080), quality=85):
    """
    Оптимизация изображения
    
    Args:
        filepath: путь к файлу
        max_size: максимальные размеры (ширина, высота)
        quality: качество JPEG (1-100)
    """
    try:
        with Image.open(filepath) as img:
            # Конвертируем в RGB, если нужно
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            
            # Изменяем размер, если нужно
            img.thumbnail(max_size, Image.Resampling.LANCZOS)
            
            # Сохраняем с оптимизацией
            img.save(filepath, optimize=True, quality=quality)
            
    except Exception as e:
        logger.error(f'Error optimizing image {filepath}: {str(e)}')

def delete_file(filepath):
    """
    Удаление файла
    
    Args:
        filepath: путь к файлу
    
    Returns:
        bool: успешно ли удален файл
    """
    try:
        if os.path.exists(filepath):
            os.remove(filepath)
            logger.info(f'File deleted: {filepath}')
            return True
    except Exception as e:
        logger.error(f'Error deleting file {filepath}: {str(e)}')
    
    return False

def get_file_url(relative_path):
    """
    Получение URL файла
    
    Args:
        relative_path: относительный путь к файлу
    
    Returns:
        str: полный URL файла
    """
    if not relative_path:
        return None
    
    # В реальном приложении здесь может быть CDN
    upload_folder = current_app.config.get('UPLOAD_FOLDER', 'uploads')
    static_folder = current_app.config.get('STATIC_FOLDER', 'static')
    
    # Проверяем, находится ли файл в статической папке
    if relative_path.startswith('static/'):
        return url_for('static', filename=relative_path[7:], _external=True)
    else:
        # Для загруженных файлов используем специальный маршрут
        return url_for('main.serve_uploaded_file', filename=relative_path, _external=True)

def validate_file_size(file, max_size_mb=10):
    """
    Проверка размера файла
    
    Args:
        file: файловый объект
        max_size_mb: максимальный размер в МБ
    
    Returns:
        bool: соответствует ли файл ограничению по размеру
    """
    # Перемещаем курсор в конец, чтобы получить размер
    file.seek(0, 2)  # seek to end
    size = file.tell()
    file.seek(0)  # seek back to start
    
    max_size = max_size_mb * 1024 * 1024  # Convert to bytes
    
    return size <= max_size