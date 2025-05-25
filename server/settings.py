# settings.py

# Ensure UTF-8 encoding support
DEFAULT_CHARSET = 'utf-8'
FILE_CHARSET = 'utf-8'

# Database configuration with UTF-8 support
DATABASES = {
    'default': {
        # ...existing database config...
        'OPTIONS': {
            'charset': 'utf8mb4',  # For MySQL
            # or for PostgreSQL:
            # 'charset': 'utf8',
        },
    }
}

# ...existing code...