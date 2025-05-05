#!/usr/bin/env python
import os
import sys
import django
import logging
import time
from datetime import datetime

# Setup Django environment
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import transaction
from accounts.models import Account, UserProfile
from django.utils import timezone

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(f'profile_creation_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
    ]
)
logger = logging.getLogger(__name__)

def create_profile_for_account(account):
    """Create a UserProfile for an Account if it doesn't exist."""
    try:
        # Check if profile already exists
        if hasattr(account, 'profile') and account.profile is not None:
            logger.info(f"Account {account.email} already has a profile")
            return False, "Profile already exists"
        
        # Create a default username from the email (remove domain part)
        default_username = account.email.split('@')[0]
        
        # Ensure username is unique by appending numbers if needed
        username = default_username
        counter = 1
        while UserProfile.objects.filter(username=username).exists():
            username = f"{default_username}{counter}"
            counter += 1
        
        # Create the profile with the unique username
        profile = UserProfile.objects.create(
            user=account,
            username=username
        )
        logger.info(f"Created profile for {account.email} with username {username}")
        return True, profile
    except Exception as e:
        logger.error(f"Error creating profile for {account.email}: {e}")
        return False, str(e)

def fix_missing_profiles():
    """Create profiles for all accounts that don't have one."""
    accounts = Account.objects.all()
    logger.info(f"Found {accounts.count()} total accounts")
    
    created_count = 0
    error_count = 0
    
    for account in accounts:
        success, result = create_profile_for_account(account)
        if success:
            created_count += 1
        else:
            if "Profile already exists" not in result:
                error_count += 1
    
    logger.info(f"Created {created_count} new profiles")
    logger.info(f"Encountered {error_count} errors")
    
    return created_count, error_count

def test_profile_creation_signal():
    """Test that the profile creation signal works correctly."""
    logger.info("Testing profile creation signal...")
    
    # Create a test account with a unique email
    test_email = f"test_user_{int(time.time())}@example.com"
    
    try:
        with transaction.atomic():
            logger.info(f"Creating test account with email {test_email}")
            test_account = Account.objects.create(
                email=test_email,
                first_name="Test",
                last_name="User",
                is_verified=True
            )
            
            # Check if profile was automatically created
            if hasattr(test_account, 'profile') and test_account.profile is not None:
                logger.info("✅ SUCCESS: Profile was automatically created")
                success = True
            else:
                logger.error("❌ FAILED: Profile was not automatically created")
                success = False
                
            # Delete the test account to clean up
            # Uncomment in production, comment during testing to inspect the account
            # test_account.delete()
            
        return success
    except Exception as e:
        logger.error(f"Error during signal test: {e}")
        return False

if __name__ == "__main__":
    logger.info("Starting profile creation process")
    
    # Fix missing profiles
    created, errors = fix_missing_profiles()
    
    # Test signal handler
    signal_works = test_profile_creation_signal()
    
    logger.info("\n" + "="*50)
    logger.info("Profile Creation Summary")
    logger.info("="*50)
    logger.info(f"Created {created} missing profiles")
    logger.info(f"Encountered {errors} errors")
    logger.info(f"Signal handler test: {'PASSED ✅' if signal_works else 'FAILED ❌'}")
    logger.info("="*50)