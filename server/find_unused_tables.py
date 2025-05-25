import os
import sys
import django
from django.db import connection

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

# Get all model tables from Django
from django.apps import apps
django_tables = set()
for model in apps.get_models():
    django_tables.add(model._meta.db_table)

# Add Django-specific tables that we want to keep
django_system_tables = {
    'django_migrations',
    'django_content_type', 
    'django_admin_log',
    'auth_permission',
    'auth_group',
    'auth_group_permissions',
    'spatial_ref_sys',  # PostgreSQL spatial extension
}
django_tables.update(django_system_tables)

# Get all tables from the database
with connection.cursor() as cursor:
    cursor.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public'
    """)
    db_tables = {row[0] for row in cursor.fetchall()}

# Find tables in the database that aren't in Django models
unused_tables = db_tables - django_tables

if unused_tables:
    print("Tables in database that aren't in Django models:")
    for table in sorted(unused_tables):
        print(f"  - {table}")
    print("\nTo remove these tables, you can run the following SQL:")
    for table in sorted(unused_tables):
        print(f"DROP TABLE IF EXISTS {table} CASCADE;")
else:
    print("No unused tables found. Database matches Django models.")

# Now check for unused columns
print("\nChecking for unused columns...")
model_fields = {}

# Get all fields for each model
for model in apps.get_models():
    table_name = model._meta.db_table
    model_fields[table_name] = set()
    
    # Add primary key
    model_fields[table_name].add(model._meta.pk.column)
    
    # Add regular fields
    for field in model._meta.fields:
        model_fields[table_name].add(field.column)
    
    # Add relationship fields (which create foreign key columns)
    for field in model._meta.many_to_many:
        # M2M fields usually have their own tables
        pass

# Check each table for columns that aren't in the model
with connection.cursor() as cursor:
    for table_name in django_tables:
        if table_name in django_system_tables:
            continue  # Skip Django system tables
            
        cursor.execute(f"""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = %s
        """, [table_name])
        
        db_columns = {row[0] for row in cursor.fetchall()}
        if table_name in model_fields:
            model_columns = model_fields[table_name]
            unused_columns = db_columns - model_columns
            
            if unused_columns:
                print(f"\nUnused columns in table '{table_name}':")
                for column in sorted(unused_columns):
                    print(f"  - {column}")
                print("\nTo remove these columns, you can run the following SQL:")
                for column in sorted(unused_columns):
                    print(f"ALTER TABLE {table_name} DROP COLUMN IF EXISTS {column};")
