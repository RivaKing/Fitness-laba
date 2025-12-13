"""
Утилиты для приложения
"""
from app.utils.decorators import (
    role_required,
    admin_required,
    trainer_required,
    client_required,
    log_action,
    validate_json,
    rate_limit,
    cache_response,
    handle_exceptions
)

from app.utils.helpers import (
    generate_password,
    hash_string,
    validate_email,
    validate_phone,
    format_datetime,
    format_duration,
    calculate_age,
    paginate_query,
    get_client_timezone,
    convert_timezone,
    sanitize_filename,
    calculate_bmi,
    get_bmi_category,
    calculate_calories,
    truncate_text,
    generate_verification_code,
    is_safe_url,
    to_json
)

from app.utils.file_upload import (
    allowed_file,
    generate_unique_filename,
    save_uploaded_file,
    optimize_image,
    delete_file,
    get_file_url,
    validate_file_size,
    ALLOWED_EXTENSIONS
)

__all__ = [
    # Декораторы
    'role_required',
    'admin_required',
    'trainer_required',
    'client_required',
    'log_action',
    'validate_json',
    'rate_limit',
    'cache_response',
    'handle_exceptions',
    
    # Хелперы
    'generate_password',
    'hash_string',
    'validate_email',
    'validate_phone',
    'format_datetime',
    'format_duration',
    'calculate_age',
    'paginate_query',
    'get_client_timezone',
    'convert_timezone',
    'sanitize_filename',
    'calculate_bmi',
    'get_bmi_category',
    'calculate_calories',
    'truncate_text',
    'generate_verification_code',
    'is_safe_url',
    'to_json',
    
    # Загрузка файлов
    'allowed_file',
    'generate_unique_filename',
    'save_uploaded_file',
    'optimize_image',
    'delete_file',
    'get_file_url',
    'validate_file_size',
    'ALLOWED_EXTENSIONS'
]