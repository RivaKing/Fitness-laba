# Инициализация маршрутов
from app.routes.auth import bp as auth_bp
from app.routes.trainings import bp as trainings_bp
from app.routes.progress import bp as progress_bp
#from app.routes.admin import bp as admin_bp
#from app.routes.api import bp as api_bp
from app.routes.main import bp as main_bp

__all__ = ['auth_bp', 'trainings_bp', 'progress_bp', 'admin_bp', 'api_bp', 'main_bp']