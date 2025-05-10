import os
import psycopg2
from dotenv import load_dotenv

"""
This script will reset your database tables.
Use with caution as it will delete all your data.
"""

load_dotenv()

# Connection parameters
conn_params = {
    "dbname": os.getenv("DATABASE_NAME"),
    "user": os.getenv("DATABASE_USER"),
    "password": os.getenv("DATABASE_PASSWORD"),
    "host": os.getenv("DATABASE_HOST"),
    "port": os.getenv("DATABASE_PORT")
}

# Tables to exclude from dropping (PostGIS related tables)
POSTGIS_TABLES = [
    'spatial_ref_sys',
    'geography_columns',
    'geometry_columns',
    'raster_columns',
    'raster_overviews'
]

try:
    # Connect to the database
    conn = psycopg2.connect(**conn_params)
    conn.autocommit = True
    cursor = conn.cursor()
    
    # Get all tables
    cursor.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema='public'
        AND table_type='BASE TABLE';
    """)
    
    tables = cursor.fetchall()
    
    # Disable triggers
    cursor.execute("SET session_replication_role = 'replica';")
    
    # Drop all tables except PostGIS tables
    for table in tables:
        table_name = table[0]
        if table_name not in POSTGIS_TABLES:
            print(f"Dropping table: {table_name}")
            cursor.execute(f"DROP TABLE IF EXISTS {table_name} CASCADE;")
        else:
            print(f"Skipping PostGIS table: {table_name}")
    
    # Enable triggers
    cursor.execute("SET session_replication_role = 'origin';")
    
    print("All non-PostGIS tables have been dropped successfully.")
    
    cursor.close()
    conn.close()
    
    print("\nNow run these commands in order:")
    print("1. python manage.py makemigrations accounts")
    print("2. python manage.py migrate")
    
except Exception as e:
    print(f"An error occurred: {e}")
