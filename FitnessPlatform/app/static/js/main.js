/**
 * Основной JavaScript файл для фитнес-платформы
 */

document.addEventListener('DOMContentLoaded', function() {
    // Инициализация всех компонентов
    initTooltips();
    initForms();
    initNotifications();
    initCharts();
    initCalendar();
    initProgressTracking();
    initTrainingRegistration();
    
    // Обновление уведомлений каждые 30 секунд
    if (window.userAuthenticated) {
        setInterval(updateNotifications, 30000);
    }
});

/**
 * Инициализация всплывающих подсказок
 */
function initTooltips() {
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
}

/**
 * Инициализация форм с дополнительной логикой
 */
function initForms() {
    // Формы с подтверждением
    const confirmForms = document.querySelectorAll('form[data-confirm]');
    confirmForms.forEach(form => {
        form.addEventListener('submit', function(e) {
            const message = this.getAttribute('data-confirm');
            if (!confirm(message)) {
                e.preventDefault();
                return false;
            }
        });
    });
    
    // Формы с динамической валидацией
    const dynamicForms = document.querySelectorAll('form[data-validate-dynamic]');
    dynamicForms.forEach(form => {
        form.addEventListener('input', debounce(function() {
            validateFormAsync(form);
        }, 500));
    });
    
    // Формы с предварительным просмотром
    const previewForms = document.querySelectorAll('form[data-preview]');
    previewForms.forEach(form => {
        const previewBtn = form.querySelector('[data-preview-btn]');
        if (previewBtn) {
            previewBtn.addEventListener('click', function() {
                showFormPreview(form);
            });
        }
    });
}

/**
 * Инициализация системы уведомлений
 */
function initNotifications() {
    const notificationBell = document.getElementById('notificationBell');
    if (notificationBell) {
        notificationBell.addEventListener('click', function(e) {
            e.preventDefault();
            toggleNotificationsPanel();
        });
    }
    
    // Закрытие уведомлений по клику снаружи
    document.addEventListener('click', function(e) {
        const notificationsPanel = document.getElementById('notificationsPanel');
        if (notificationsPanel && !notificationsPanel.contains(e.target) && 
            notificationBell && !notificationBell.contains(e.target)) {
            notificationsPanel.classList.remove('show');
        }
    });
    
    // Обновление уведомлений при загрузке
    updateNotifications();
}

/**
 * Обновление уведомлений
 */
async function updateNotifications() {
    if (!window.userAuthenticated) return;
    
    try {
        const response = await fetch('/api/notifications');
        if (response.ok) {
            const data = await response.json();
            updateNotificationBadge(data.notifications.length);
            updateNotificationsPanel(data.notifications);
        }
    } catch (error) {
        console.error('Ошибка при получении уведомлений:', error);
    }
}

/**
 * Обновление бейджа уведомлений
 */
function updateNotificationBadge(count) {
    const badge = document.getElementById('notificationBadge');
    if (badge) {
        if (count > 0) {
            badge.textContent = count > 99 ? '99+' : count;
            badge.classList.remove('d-none');
            badge.classList.add('pulse');
        } else {
            badge.classList.add('d-none');
            badge.classList.remove('pulse');
        }
    }
}

/**
 * Обновление панели уведомлений
 */
function updateNotificationsPanel(notifications) {
    const panel = document.getElementById('notificationsPanel');
    if (!panel) return;
    
    const list = panel.querySelector('.notifications-list');
    if (!list) return;
    
    if (notifications.length === 0) {
        list.innerHTML = '<div class="text-center p-3 text-muted">Нет новых уведомлений</div>';
        return;
    }
    
    let html = '';
    notifications.forEach(notification => {
        const timeAgo = formatTimeAgo(new Date(notification.created_at));
        html += `
            <div class="notification-item ${notification.is_read ? '' : 'unread'}" data-id="${notification.id}">
                <div class="notification-icon">
                    <i class="fas ${getNotificationIcon(notification.type)}"></i>
                </div>
                <div class="notification-content">
                    <div class="notification-title">${escapeHtml(notification.title)}</div>
                    <div class="notification-message">${escapeHtml(notification.message)}</div>
                    <div class="notification-time">${timeAgo}</div>
                </div>
                ${!notification.is_read ? '<div class="notification-unread-dot"></div>' : ''}
            </div>
        `;
    });
    
    list.innerHTML = html;
    
    // Добавление обработчиков кликов
    list.querySelectorAll('.notification-item').forEach(item => {
        item.addEventListener('click', function() {
            const notificationId = this.getAttribute('data-id');
            markNotificationAsRead(notificationId);
            
            if (this.querySelector('.notification-unread-dot')) {
                this.querySelector('.notification-unread-dot').remove();
                this.classList.remove('unread');
            }
        });
    });
}

/**
 * Пометить уведомление как прочитанное
 */
async function markNotificationAsRead(notificationId) {
    try {
        const response = await fetch(`/api/notifications/${notificationId}/read`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': getCSRFToken()
            }
        });
        
        if (response.ok) {
            // Обновляем счетчик
            updateNotifications();
        }
    } catch (error) {
        console.error('Ошибка при отметке уведомления:', error);
    }
}

/**
 * Переключение панели уведомлений
 */
function toggleNotificationsPanel() {
    const panel = document.getElementById('notificationsPanel');
    if (panel) {
        panel.classList.toggle('show');
        
        if (panel.classList.contains('show')) {
            // При открытии обновляем уведомления
            updateNotifications();
        }
    }
}

/**
 * Инициализация графиков
 */
function initCharts() {
    // Инициализация всех графиков на странице
    const chartContainers = document.querySelectorAll('[data-chart]');
    chartContainers.forEach(container => {
        const chartType = container.getAttribute('data-chart');
        const dataUrl = container.getAttribute('data-url');
        
        if (dataUrl) {
            loadChartData(container, chartType, dataUrl);
        }
    });
}

/**
 * Загрузка данных для графика
 */
async function loadChartData(container, chartType, dataUrl) {
    try {
        const response = await fetch(dataUrl);
        if (response.ok) {
            const data = await response.json();
            renderChart(container, chartType, data);
        }
    } catch (error) {
        console.error('Ошибка при загрузке данных графика:', error);
        container.innerHTML = '<div class="alert alert-danger">Не удалось загрузить данные графика</div>';
    }
}

/**
 * Рендеринг графика
 */
function renderChart(container, chartType, data) {
    const canvas = document.createElement('canvas');
    container.innerHTML = '';
    container.appendChild(canvas);
    
    const ctx = canvas.getContext('2d');
    
    switch (chartType) {
        case 'line':
            renderLineChart(ctx, data);
            break;
        case 'bar':
            renderBarChart(ctx, data);
            break;
        case 'pie':
            renderPieChart(ctx, data);
            break;
        case 'radar':
            renderRadarChart(ctx, data);
            break;
        default:
            console.error('Неизвестный тип графика:', chartType);
    }
}

/**
 * Инициализация календаря тренировок
 */
function initCalendar() {
    const calendarEl = document.getElementById('trainingCalendar');
    if (!calendarEl) return;
    
    const calendar = new FullCalendar.Calendar(calendarEl, {
        initialView: 'dayGridMonth',
        locale: 'ru',
        firstDay: 1,
        headerToolbar: {
            left: 'prev,next today',
            center: 'title',
            right: 'dayGridMonth,timeGridWeek,timeGridDay'
        },
        buttonText: {
            today: 'Сегодня',
            month: 'Месяц',
            week: 'Неделя',
            day: 'День'
        },
        events: '/trainings/api/trainings/calendar',
        eventClick: function(info) {
            info.jsEvent.preventDefault();
            if (info.event.url) {
                window.location.href = info.event.url;
            }
        },
        eventDisplay: 'block',
        eventColor: '#4a6fa5',
        eventTimeFormat: {
            hour: '2-digit',
            minute: '2-digit',
            meridiem: false
        }
    });
    
    calendar.render();
}

/**
 * Инициализация отслеживания прогресса
 */
function initProgressTracking() {
    // Форма добавления прогресса
    const progressForm = document.getElementById('progressForm');
    if (progressForm) {
        progressForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            const data = Object.fromEntries(formData.entries());
            
            try {
                const response = await fetch('/progress/api/add', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-CSRF-Token': getCSRFToken()
                    },
                    body: JSON.stringify(data)
                });
                
                if (response.ok) {
                    const result = await response.json();
                    showAlert('success', result.message);
                    setTimeout(() => {
                        window.location.href = '/progress';
                    }, 1500);
                } else {
                    showAlert('danger', 'Ошибка при сохранении прогресса');
                }
            } catch (error) {
                console.error('Ошибка:', error);
                showAlert('danger', 'Ошибка при сохранении прогресса');
            }
        });
    }
    
    // Графики прогресса
    initProgressCharts();
}

/**
 * Инициализация графиков прогресса
 */
function initProgressCharts() {
    const progressChartEl = document.getElementById('progressChart');
    if (progressChartEl) {
        const ctx = progressChartEl.getContext('2d');
        
        // Загрузка данных прогресса
        fetch('/progress/api/chart-data?type=weekly')
            .then(response => response.json())
            .then(data => {
                const labels = data.map(item => item.week);
                const durationData = data.map(item => item.duration);
                const caloriesData = data.map(item => item.calories);
                
                new Chart(ctx, {
                    type: 'line',
                    data: {
                        labels: labels,
                        datasets: [
                            {
                                label: 'Продолжительность (мин)',
                                data: durationData,
                                borderColor: '#4a6fa5',
                                backgroundColor: 'rgba(74, 111, 165, 0.1)',
                                tension: 0.4
                            },
                            {
                                label: 'Калории',
                                data: caloriesData,
                                borderColor: '#ff7e5f',
                                backgroundColor: 'rgba(255, 126, 95, 0.1)',
                                tension: 0.4
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        plugins: {
                            legend: {
                                position: 'top',
                            },
                            tooltip: {
                                mode: 'index',
                                intersect: false
                            }
                        },
                        scales: {
                            y: {
                                beginAtZero: true
                            }
                        }
                    }
                });
            })
            .catch(error => {
                console.error('Ошибка при загрузке данных графика:', error);
            });
    }
}

/**
 * Инициализация регистрации на тренировки
 */
function initTrainingRegistration() {
    // Кнопки регистрации
    const registerButtons = document.querySelectorAll('[data-register-training]');
    registerButtons.forEach(button => {
        button.addEventListener('click', function() {
            const trainingId = this.getAttribute('data-training-id');
            registerForTraining(trainingId);
        });
    });
    
    // Кнопки отмены регистрации
    const cancelButtons = document.querySelectorAll('[data-cancel-registration]');
    cancelButtons.forEach(button => {
        button.addEventListener('click', function() {
            const trainingId = this.getAttribute('data-training-id');
            cancelTrainingRegistration(trainingId);
        });
    });
    
    // Отметка посещения
    const checkInButtons = document.querySelectorAll('[data-check-in]');
    checkInButtons.forEach(button => {
        button.addEventListener('click', function() {
            const trainingId = this.getAttribute('data-training-id');
            checkInToTraining(trainingId);
        });
    });
}

/**
 * Регистрация на тренировку
 */
async function registerForTraining(trainingId) {
    if (!confirm('Вы уверены, что хотите записаться на эту тренировку?')) {
        return;
    }
    
    try {
        const response = await fetch(`/trainings/${trainingId}/register`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': getCSRFToken()
            }
        });
        
        if (response.ok) {
            const result = await response.json();
            showAlert('success', result.message);
            setTimeout(() => {
                window.location.reload();
            }, 1500);
        } else {
            showAlert('danger', 'Ошибка при регистрации на тренировку');
        }
    } catch (error) {
        console.error('Ошибка:', error);
        showAlert('danger', 'Ошибка при регистрации на тренировку');
    }
}

/**
 * Отмена регистрации на тренировку
 */
async function cancelTrainingRegistration(trainingId) {
    if (!confirm('Вы уверены, что хотите отменить регистрацию на эту тренировку?')) {
        return;
    }
    
    try {
        const response = await fetch(`/trainings/${trainingId}/cancel-registration`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': getCSRFToken()
            }
        });
        
        if (response.ok) {
            showAlert('success', 'Регистрация успешно отменена');
            setTimeout(() => {
                window.location.reload();
            }, 1500);
        } else {
            showAlert('danger', 'Ошибка при отмене регистрации');
        }
    } catch (error) {
        console.error('Ошибка:', error);
        showAlert('danger', 'Ошибка при отмене регистрации');
    }
}

/**
 * Отметка посещения тренировки
 */
async function checkInToTraining(trainingId) {
    try {
        const response = await fetch(`/trainings/api/trainings/${trainingId}/check-in`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': getCSRFToken()
            }
        });
        
        if (response.ok) {
            const result = await response.json();
            showAlert('success', result.message);
            setTimeout(() => {
                window.location.reload();
            }, 1500);
        } else {
            showAlert('danger', 'Ошибка при отметке посещения');
        }
    } catch (error) {
        console.error('Ошибка:', error);
        showAlert('danger', 'Ошибка при отметке посещения');
    }
}

/**
 * Утилиты
 */

// Debounce функция
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Форматирование времени
function formatTimeAgo(date) {
    const seconds = Math.floor((new Date() - date) / 1000);
    
    if (seconds < 60) return 'только что';
    if (seconds < 3600) return `${Math.floor(seconds / 60)} минут назад`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)} часов назад`;
    if (seconds < 2592000) return `${Math.floor(seconds / 86400)} дней назад`;
    return `${Math.floor(seconds / 2592000)} месяцев назад`;
}

// Получение CSRF токена
function getCSRFToken() {
    const metaTag = document.querySelector('meta[name="csrf-token"]');
    return metaTag ? metaTag.getAttribute('content') : '';
}

// Экранирование HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Показ алертов
function showAlert(type, message) {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    const container = document.querySelector('.container') || document.body;
    container.insertBefore(alertDiv, container.firstChild);
    
    setTimeout(() => {
        alertDiv.classList.remove('show');
        setTimeout(() => alertDiv.remove(), 150);
    }, 5000);
}

// Получение иконки для типа уведомления
function getNotificationIcon(type) {
    const icons = {
        'training': 'fa-dumbbell',
        'registration': 'fa-calendar-check',
        'cancellation': 'fa-calendar-times',
        'reminder': 'fa-bell',
        'achievement': 'fa-trophy',
        'system': 'fa-info-circle',
        'moderation': 'fa-clipboard-check',
        'attendance': 'fa-user-check',
        'default': 'fa-bell'
    };
    
    return icons[type] || icons.default;
}