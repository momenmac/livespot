import os
import subprocess
import sys

def run_command(command):
    print(f"Running: {command}")
    result = subprocess.run(command, shell=True, text=True)
    if result.returncode != 0:
        print(f"Command failed with exit code {result.returncode}")
        sys.exit(result.returncode)
    return result

# 1. Make migrations for accounts
run_command("python manage.py makemigrations accounts")

# 2. Fake initial migration for contenttypes
run_command("python manage.py migrate contenttypes --fake-initial")

# 3. Fake initial migration for auth
run_command("python manage.py migrate auth --fake-initial")

# 4. Apply accounts migrations
run_command("python manage.py migrate accounts")

# 5. Apply remaining migrations
run_command("python manage.py migrate")

print("Migration completed successfully!")
