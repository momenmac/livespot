from django.core.mail import send_mail
from django.conf import settings
import sys

def test_email_settings(recipient_email=None):
    """
    Test email settings by sending a test email.
    
    Run this file directly to test:
    python manage.py shell < accounts/email_debug.py
    
    Or import and call the function:
    from accounts.email_debug import test_email_settings
    test_email_settings('your.email@example.com')
    """
    if recipient_email is None and len(sys.argv) > 1:
        recipient_email = sys.argv[1]
    
    if not recipient_email:
        print("Please provide a recipient email address")
        return False
    
    print(f"Email configuration:")
    print(f"EMAIL_HOST: {settings.EMAIL_HOST}")
    print(f"EMAIL_PORT: {settings.EMAIL_PORT}")
    print(f"EMAIL_HOST_USER: {settings.EMAIL_HOST_USER}")
    print(f"EMAIL_USE_TLS: {settings.EMAIL_USE_TLS}")
    
    try:
        subject = 'Test Email from Django App'
        message = 'This is a test email to verify your email settings are working correctly.'
        email_from = settings.EMAIL_HOST_USER
        recipient_list = [recipient_email]
        
        send_mail(
            subject,
            message,
            email_from,
            recipient_list,
            fail_silently=False,
        )
        
        print(f"Test email sent to {recipient_email}")
        return True
    except Exception as e:
        print(f"Failed to send test email: {str(e)}")
        return False

if __name__ == "__main__" and len(sys.argv) > 1:
    test_email_settings(sys.argv[1])
