#!/usr/bin/env python
import os
import django
import sys

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

# Apply migrations
from django.core.management import call_command
call_command('migrate')

print("Migration complete. Unused tables have been removed.")
