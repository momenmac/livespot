from django.shortcuts import render
from django.contrib.auth import authenticate, login
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework.authtoken.models import Token
from .models import Account, VerificationCode
from .serializers import AccountSerializer
import json
import logging
from django.views.decorators.csrf import csrf_exempt, ensure_csrf_cookie
from django.utils.decorators import method_decorator
import random
import string
from django.core.mail import send_mail
from django.conf import settings
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger(__name__)

# Add CORS headers to all responses
def add_cors_headers(response):
    response["Access-Control-Allow-Origin"] = "*"  # In production, replace with specific origins
    response["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    response["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
    return response

def generate_verification_code(length=6):
    """Generate a random verification code."""
    return ''.join(random.choices(string.digits, k=length))

def send_verification_email(user, code):
    """Send verification code to user's email."""
    subject = 'Your Verification Code'
    
    # Plain text version as fallback
    text_message = f'Hello {user.first_name},\n\nYour verification code is: {code}\n\nThis code will expire in 10 minutes.\n\nThank you for registering with our app!'
    
    # HTML version with styling based on ThemeConstants
    html_message = f'''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{
                font-family: Arial, sans-serif;
                line-height: 1.6;
                color: #202020;
                margin: 0;
                padding: 0;
            }}
            .container {{
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
            }}
            .header {{
                background: linear-gradient(to right, #004CFF, #004CFF, rgba(0, 76, 255, 0.73));
                padding: 20px;
                text-align: center;
                color: white;
                border-radius: 5px 5px 0 0;
            }}
            .content {{
                background-color: #F2F5FE;
                padding: 30px;
                border-radius: 0 0 5px 5px;
            }}
            .code-container {{
                background-color: white;
                padding: 15px;
                text-align: center;
                border-radius: 5px;
                margin: 20px 0;
                border: 1px solid #d9e4ff;
            }}
            .code {{
                font-size: 32px;
                font-weight: bold;
                color: #004CFF;
                letter-spacing: 5px;
            }}
            .expiration {{
                color: #F34D75;
                font-weight: bold;
                margin-top: 10px;
            }}
            .footer {{
                margin-top: 20px;
                text-align: center;
                font-size: 12px;
                color: #707070;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>Email Verification</h2>
            </div>
            <div class="content">
                <p>Hello <strong>{user.first_name}</strong>,</p>
                <p>Thank you for registering with our app. Please use the verification code below to complete your registration:</p>
                <div class="code-container">
                    <div class="code">{code}</div>
                </div>
                <p class="expiration">This code will expire in 10 minutes.</p>
                <p>If you didn't request this code, please ignore this email.</p>
            </div>
            <div class="footer">
                <p>This is an automated message, please do not reply to this email.</p>
            </div>
        </div>
    </body>
    </html>
    '''
    
    email_from = settings.EMAIL_HOST_USER
    recipient_list = [user.email]
    
    try:
        send_mail(
            subject, 
            text_message, 
            email_from, 
            recipient_list, 
            html_message=html_message,
            fail_silently=False
        )
        logger.info(f"Verification email sent to: {user.email}")
        return True
    except Exception as e:
        logger.error(f"Failed to send verification email: {str(e)}")
        return False

# Add profile picture helper function
def save_profile_picture_from_url(user, profile_picture_url):
    """Save profile picture from URL for user"""
    if not profile_picture_url:
        return False
        
    try:
        from urllib.request import urlopen, Request
        from django.core.files.base import ContentFile
        import uuid
        
        print(f"Downloading profile picture from: {profile_picture_url}")
        
        # Create a proper request with user-agent to avoid 403 errors
        request = Request(
            profile_picture_url,
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        
        # Open the URL with our custom request
        img_temp = urlopen(request, timeout=10)
        
        # Get content type for file extension
        content_type = img_temp.info().get_content_type()
        print(f"Image content type: {content_type}")
        
        # Determine file extension
        if 'jpeg' in content_type or 'jpg' in content_type:
            img_temp_ext = 'jpg'
        elif 'png' in content_type:
            img_temp_ext = 'png'
        else:
            # Default to jpg
            img_temp_ext = 'jpg'
            
        # Read the image data
        img_data = img_temp.read()
        
        if len(img_data) < 100:
            print(f"Warning: Very small image data received ({len(img_data)} bytes)")
            return False
            
        # Save profile picture with proper filename
        filename = f"{uuid.uuid4()}.{img_temp_ext}"
        user.profile_picture.save(
            filename, 
            ContentFile(img_data), 
            save=True
        )
        
        print(f"Successfully saved profile picture as {filename}")
        return True
        
    except Exception as e:
        print(f"Failed to save profile picture: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

@method_decorator(csrf_exempt, name='dispatch')
class RegisterView(APIView):
    permission_classes = [AllowAny]

    def options(self, request, *args, **kwargs):
        logger.info("OPTIONS request received for /accounts/register/")
        response = Response(status=200)
        return add_cors_headers(response)

    def head(self, request, *args, **kwargs):
        logger.info("HEAD request received for /accounts/register/")
        response = Response(status=200)
        return add_cors_headers(response)

    def post(self, request):
        try:
            # Log the request for debugging
            logger.info(f"Register request received with data: {request.data}")
            print(f"Register request data: {request.data}")
            
            email = request.data.get('email')
            first_name = request.data.get('first_name')
            last_name = request.data.get('last_name')
            password = request.data.get('password')

            # Validate request data
            if not email or not password or not first_name or not last_name:
                logger.warning(f"Missing required fields: {request.data}")
                return add_cors_headers(Response({"error": "Missing required fields"}, status=400))

            if Account.objects.filter(email=email).exists():
                logger.warning(f"Email already registered: {email}")
                return add_cors_headers(Response({"error": "Email already registered"}, status=400))

            user = Account.objects.create_user(
                email=email, 
                first_name=first_name, 
                last_name=last_name, 
                password=password,
                is_verified=False
            )
            token, _ = Token.objects.get_or_create(user=user)
            
            # Generate verification code
            verification_code = generate_verification_code()
            expires_at = datetime.now() + timedelta(minutes=10)
            
            # Save verification code
            VerificationCode.objects.create(
                user=user,
                code=verification_code,
                expires_at=expires_at
            )
            
            # Send verification email
            email_sent = send_verification_email(user, verification_code)
            
            logger.info(f"User registered successfully: {email}, verification email sent: {email_sent}")
            response = Response({
                "message": "User registered successfully. Please check your email for verification code.", 
                "token": token.key,
                "user": {
                    "id": user.id,
                    "email": user.email,
                    "first_name": user.first_name,
                    "last_name": user.last_name,
                    "is_verified": user.is_verified
                },
                "email_sent": email_sent
            })
            return add_cors_headers(response)
        except Exception as e:
            logger.error(f"Register error: {str(e)}")
            print(f"Register error: {str(e)}")
            response = Response({"error": str(e)}, status=500)
            return add_cors_headers(response)

@method_decorator(csrf_exempt, name='dispatch')
class VerifyEmailView(APIView):
    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)
    
    def post(self, request):
        try:
            user = request.user
            verification_code = request.data.get('code')
            
            if not user.is_authenticated:
                return add_cors_headers(Response({"error": "Authentication required"}, status=401))
                
            if user.is_verified:
                return add_cors_headers(Response({"message": "Email already verified"}, status=200))
                
            if not verification_code:
                return add_cors_headers(Response({"error": "Verification code is required"}, status=400))
            
            # Check if verification code exists and is valid
            code_obj = VerificationCode.objects.filter(
                user=user, 
                code=verification_code, 
                expires_at__gt=datetime.now(),
                is_used=False
            ).first()
            
            if not code_obj:
                return add_cors_headers(Response({"error": "Invalid or expired verification code"}, status=400))
            
            # Mark user as verified
            user.is_verified = True
            user.save()
            
            # Mark code as used
            code_obj.is_used = True
            code_obj.save()
            
            logger.info(f"Email verified for user: {user.email}")
            return add_cors_headers(Response({
                "message": "Email verified successfully",
                "user": {
                    "id": user.id,
                    "email": user.email,
                    "first_name": user.first_name,
                    "last_name": user.last_name,
                    "is_verified": user.is_verified
                }
            }))
            
        except Exception as e:
            logger.error(f"Email verification error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

@method_decorator(csrf_exempt, name='dispatch')
class ResendVerificationCodeView(APIView):
    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)
    
    def post(self, request):
        try:
            user = request.user
            
            if not user.is_authenticated:
                return add_cors_headers(Response({"error": "Authentication required"}, status=401))
                
            if user.is_verified:
                return add_cors_headers(Response({"message": "Email already verified"}, status=200))
            
            # Check for rate limiting (prevent too many requests)
            recent_codes = VerificationCode.objects.filter(
                user=user,
                created_at__gt=datetime.now() - timedelta(minutes=2)
            ).count()
            
            if recent_codes > 0:
                return add_cors_headers(Response(
                    {"error": "Please wait before requesting a new code"}, 
                    status=429
                ))
                
            # Generate new verification code
            verification_code = generate_verification_code()
            expires_at = datetime.now() + timedelta(minutes=10)
            
            # Save new verification code
            VerificationCode.objects.create(
                user=user,
                code=verification_code,
                expires_at=expires_at
            )
            
            # Send verification email
            email_sent = send_verification_email(user, verification_code)
            
            logger.info(f"Verification code resent to: {user.email}")
            return add_cors_headers(Response({
                "message": "Verification code resent. Please check your email.",
                "email_sent": email_sent
            }))
            
        except Exception as e:
            logger.error(f"Resend verification code error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

@method_decorator(csrf_exempt, name='dispatch')
class LoginView(APIView):
    permission_classes = [AllowAny]

    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)

    def post(self, request):
        try:
            email = request.data.get('email')
            password = request.data.get('password')

            user = authenticate(email=email, password=password)
            if user:
                login(request, user)
                token, _ = Token.objects.get_or_create(user=user)
                
                # Return user data including verification status
                response = Response({
                    "message": "Logged in",
                    "token": token.key,
                    "user": {
                        "id": user.id,
                        "email": user.email,
                        "first_name": user.first_name,
                        "last_name": user.last_name,
                        "is_verified": user.is_verified,
                        "profile_picture_url": user.profile_picture.url if user.profile_picture else None
                    }
                })
                return add_cors_headers(response)
            
            response = Response({"error": "Invalid credentials"}, status=401)
            return add_cors_headers(response)
        except Exception as e:
            print(f"Login error: {str(e)}")
            response = Response({"error": str(e)}, status=500)
            return add_cors_headers(response)

@method_decorator(csrf_exempt, name='dispatch')
class GoogleLoginView(APIView):
    permission_classes = [AllowAny]

    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)

    def post(self, request):
        try:
            google_id = request.data.get('google_id')
            email = request.data.get('email')
            first_name = request.data.get('first_name')
            last_name = request.data.get('last_name')
            profile_picture = request.data.get('profile_picture')

            logger.info(f"Google login request for: {email}")
            print(f"Google login request for: {email}")
            print(f"Profile picture URL: {profile_picture}")

            if not google_id or not email:
                logger.warning(f"Invalid Google credentials: {request.data}")
                return add_cors_headers(Response({"error": "Invalid Google credentials"}, status=400))

            # Try to find an existing user with this email
            try:
                user = Account.objects.get(email=email)
                
                # If user exists but doesn't have google_id, this is an existing account
                # We should link the Google account to the existing account
                account_linked = False
                
                if not user.google_id:
                    logger.info(f"Linking Google account to existing account: {email}")
                    print(f"Linking Google account to existing account: {email}")
                    user.google_id = google_id
                    account_linked = True
                    
                    # Update user profile with Google info if provided
                    if first_name and not user.first_name:
                        user.first_name = first_name
                    if last_name and not user.last_name:
                        user.last_name = last_name
                    
                    # Save profile picture if provided and user doesn't have one
                    if profile_picture and (not user.profile_picture or not user.profile_picture.name):
                        # Save profile picture using our helper function
                        save_profile_picture_from_url(user, profile_picture)
                    else:
                        # Always save the user object since we updated google_id
                        user.save()
                
                # User already exists, just log them in
                logger.info(f"Existing user logging in via Google: {email}")
                print(f"Existing user logging in via Google: {email}")
                
                login(request, user)
                token, _ = Token.objects.get_or_create(user=user)
                
                user_data = AccountSerializer(user).data
                # Ensure profile picture URL is fully qualified
                if user.profile_picture and user.profile_picture.url:
                    user_data['profile_picture_url'] = request.build_absolute_uri(user.profile_picture.url)
                
                return add_cors_headers(Response({
                    "message": "User logged in",
                    "user": user_data,
                    "token": token.key,
                    "is_new_account": False,
                    "account_linked": account_linked
                }))
                
            except Account.DoesNotExist:
                # User doesn't exist, create a new account
                logger.info(f"Creating new account via Google: {email}")
                print(f"Creating new account via Google: {email}")
                
                user = Account.objects.create_user(
                    email=email,
                    first_name=first_name,
                    last_name=last_name,
                    google_id=google_id,
                    is_verified=True  # Google accounts are pre-verified
                )
                
                # Save profile picture if provided
                if profile_picture:
                    saved = save_profile_picture_from_url(user, profile_picture)
                    if not saved:
                        print(f"Couldn't save profile picture during user creation")
                
                login(request, user)
                token, _ = Token.objects.get_or_create(user=user)
                
                user_data = AccountSerializer(user).data
                # Ensure profile picture URL is fully qualified
                if user.profile_picture and user.profile_picture.url:
                    user_data['profile_picture_url'] = request.build_absolute_uri(user.profile_picture.url)
                
                return add_cors_headers(Response({
                    "message": "New user created and logged in",
                    "user": user_data,
                    "token": token.key,
                    "is_new_account": True,
                    "account_linked": False
                }))

        except Exception as e:
            logger.error(f"Google login error: {str(e)}")
            print(f"Google login error: {str(e)}")
            import traceback
            traceback.print_exc()
            response = Response({"error": str(e)}, status=500)
            return add_cors_headers(response)

# Add a profile view
@method_decorator(csrf_exempt, name='dispatch')
class ProfileView(APIView):
    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)
        
    def get(self, request):
        try:
            user = request.user
            response = Response(AccountSerializer(user).data)
            return add_cors_headers(response)
        except Exception as e:
            response = Response({"error": str(e)}, status=500)
            return add_cors_headers(response)

@method_decorator(csrf_exempt, name='dispatch')
class ProfileImageView(APIView):
    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)
        
    def post(self, request):
        try:
            # Log the request for debugging
            logger.info(f"Profile image upload request received")
            
            # Check if user is authenticated
            if not request.user.is_authenticated:
                logger.warning("Unauthenticated profile image upload attempt")
                return add_cors_headers(Response({"error": "Authentication required"}, status=401))
                
            # Get the image from request
            image_file = request.FILES.get('profile_image')
            if not image_file:
                logger.warning("No image file in request")
                return add_cors_headers(Response({"error": "No image file provided"}, status=400))
                
            # Update user's profile picture
            user = request.user
            user.profile_picture = image_file
            user.save()
            
            logger.info(f"Profile image updated for user: {user.email}")
            return add_cors_headers(Response({
                "message": "Profile image updated successfully",
                "profile_picture_url": user.profile_picture.url if user.profile_picture else None
            }))
            
        except Exception as e:
            logger.error(f"Profile image upload error: {str(e)}")
            print(f"Profile image upload error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

@method_decorator(csrf_exempt, name='dispatch')
class ForgotPasswordView(APIView):
    permission_classes = [AllowAny]

    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)

    def post(self, request):
        try:
            email = request.data.get('email')
            
            logger.info(f"Received password reset request for email: {email}")
            print(f"Received password reset request for email: {email}")
            
            if not email:
                logger.warning("Missing email in password reset request")
                return add_cors_headers(Response({"error": "Email is required"}, status=400))
            
            # Check if user exists with this email
            try:
                user = Account.objects.get(email=email)
                logger.info(f"Found user for password reset: {email}")
                print(f"Found user for password reset: {email}")
                
                # Generate a verification code
                verification_code = generate_verification_code()
                expires_at = datetime.now() + timedelta(minutes=15)
                
                # Save code for password reset
                VerificationCode.objects.filter(user=user).update(is_used=True)  # Mark any existing codes as used
                reset_code = VerificationCode.objects.create(
                    user=user,
                    code=verification_code,
                    expires_at=expires_at
                )
                print(f"Created reset code: {verification_code} for user: {user.email}")
                
                # Send verification email
                subject = 'Password Reset Code'
                
                # Plain text version as fallback
                text_message = f'Hello {user.first_name},\n\nYour password reset code is: {verification_code}\n\nThis code will expire in 15 minutes.\n\nIf you did not request a password reset, please ignore this email.'
                
                # HTML version with styling
                html_message = f'''
                <!DOCTYPE html>
                <html>
                <head>
                    <style>
                        body {{
                            font-family: Arial, sans-serif;
                            line-height: 1.6;
                            color: #202020;
                            margin: 0;
                            padding: 0;
                        }}
                        .container {{
                            max-width: 600px;
                            margin: 0 auto;
                            padding: 20px;
                        }}
                        .header {{
                            background: linear-gradient(to right, #004CFF, #004CFF, rgba(0, 76, 255, 0.73));
                            padding: 20px;
                            text-align: center;
                            color: white;
                            border-radius: 5px 5px 0 0;
                        }}
                        .content {{
                            background-color: #F2F5FE;
                            padding: 30px;
                            border-radius: 0 0 5px 5px;
                        }}
                        .code-container {{
                            background-color: white;
                            padding: 15px;
                            text-align: center;
                            border-radius: 5px;
                            margin: 20px 0;
                            border: 1px solid #d9e4ff;
                        }}
                        .code {{
                            font-size: 32px;
                            font-weight: bold;
                            color: #004CFF;
                            letter-spacing: 5px;
                        }}
                        .expiration {{
                            color: #F34D75;
                            font-weight: bold;
                            margin-top: 10px;
                        }}
                        .footer {{
                            margin-top: 20px;
                            text-align: center;
                            font-size: 12px;
                            color: #707070;
                        }}
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="header">
                            <h2>Password Reset</h2>
                        </div>
                        <div class="content">
                            <p>Hello <strong>{user.first_name}</strong>,</p>
                            <p>We received a request to reset your password. Please use the code below to reset your password:</p>
                            <div class="code-container">
                                <div class="code">{verification_code}</div>
                            </div>
                            <p class="expiration">This code will expire in 15 minutes.</p>
                            <p>If you didn't request a password reset, please ignore this email.</p>
                        </div>
                        <div class="footer">
                            <p>This is an automated message, please do not reply to this email.</p>
                        </div>
                    </div>
                </body>
                </html>
                '''
                
                email_from = settings.EMAIL_HOST_USER
                recipient_list = [user.email]
                
                # Print email configuration for debugging
                print(f"Email host: {settings.EMAIL_HOST}")
                print(f"Email port: {settings.EMAIL_PORT}")
                print(f"Email host user: {settings.EMAIL_HOST_USER}")
                print(f"Email using TLS: {settings.EMAIL_USE_TLS}")
                print(f"Email recipient: {recipient_list}")
                
                try:
                    send_mail(
                        subject, 
                        text_message, 
                        email_from, 
                        recipient_list, 
                        html_message=html_message,
                        fail_silently=False
                    )
                    logger.info(f"Password reset email sent to: {user.email}")
                    print(f"Password reset email sent to: {user.email}")
                    email_sent = True
                except Exception as e:
                    logger.error(f"Failed to send password reset email: {str(e)}")
                    print(f"Failed to send password reset email: {str(e)}")
                    email_sent = False
                
                # Return success response
                return add_cors_headers(Response({
                    "message": "Password reset code sent to your email",
                    "email_sent": email_sent,
                    "exists": True  # Add flag to indicate email exists
                }))
                
            except Account.DoesNotExist:
                # Email doesn't exist in the database
                logger.warning(f"Password reset requested for non-existent email: {email}")
                print(f"Password reset requested for non-existent email: {email}")
                
                return add_cors_headers(Response({
                    "message": "If your email is registered, you will receive a password reset code",
                    "email_sent": False,
                    "exists": False  # Add flag to indicate email doesn't exist
                }))
            
        except Exception as e:
            logger.error(f"Forgot password error: {str(e)}")
            print(f"Forgot password error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

@method_decorator(csrf_exempt, name='dispatch')
class VerifyResetCodeView(APIView):
    permission_classes = [AllowAny]

    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)
    
    def post(self, request):
        try:
            email = request.data.get('email')
            code = request.data.get('code')
            
            if not email or not code:
                return add_cors_headers(Response({"error": "Email and code are required"}, status=400))
            
            try:
                user = Account.objects.get(email=email)
            except Account.DoesNotExist:
                return add_cors_headers(Response({"error": "Invalid email or code"}, status=400))
            
            # Check if verification code exists and is valid
            code_obj = VerificationCode.objects.filter(
                user=user,
                code=code,
                expires_at__gt=datetime.now(),
                is_used=False
            ).first()
            
            if not code_obj:
                return add_cors_headers(Response({"error": "Invalid or expired code"}, status=400))
            
            # Generate a temporary token for resetting password
            reset_token, _ = Token.objects.get_or_create(user=user)
            
            return add_cors_headers(Response({
                "message": "Code verified successfully",
                "reset_token": reset_token.key
            }))
            
        except Exception as e:
            logger.error(f"Verify reset code error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

@method_decorator(csrf_exempt, name='dispatch')
class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)
    
    def post(self, request):
        try:
            reset_token = request.data.get('reset_token')
            new_password = request.data.get('new_password')
            
            if not reset_token or not new_password:
                return add_cors_headers(Response(
                    {"error": "Reset token and new password are required"}, 
                    status=400
                ))
            
            try:
                token = Token.objects.get(key=reset_token)
                user = token.user
            except Token.DoesNotExist:
                return add_cors_headers(Response({"error": "Invalid reset token"}, status=400))
            
            # Check if password meets minimum requirements
            if len(new_password) < 6:
                return add_cors_headers(Response(
                    {"error": "Password must be at least 6 characters long"}, 
                    status=400
                ))
            
            # Update user password
            user.set_password(new_password)
            user.save()
            
            # Mark all verification codes as used
            VerificationCode.objects.filter(user=user).update(is_used=True)
            
            # Optional: Generate a new token for immediate login
            token.delete()  # Delete old token
            new_token, _ = Token.objects.get_or_create(user=user)
            
            return add_cors_headers(Response({
                "message": "Password reset successfully",
                "token": new_token.key
            }))
            
        except Exception as e:
            logger.error(f"Reset password error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

@method_decorator(csrf_exempt, name='dispatch')
class VerifyTokenView(APIView):
    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)
        
    def post(self, request):
        try:
            token_key = request.data.get('token') or request.META.get('HTTP_AUTHORIZATION', '').replace('Token ', '')
            
            if not token_key:
                return add_cors_headers(Response({"error": "Token is required"}, status=400))
                
            try:
                token = Token.objects.get(key=token_key)
                user = token.user
                
                # Check if token is still valid (e.g., not expired)
                # You could add token expiration logic here
                
                return add_cors_headers(Response({
                    "valid": True,
                    "user_id": user.id
                }))
            except Token.DoesNotExist:
                return add_cors_headers(Response({"valid": False}, status=200))
                
        except Exception as e:
            logger.error(f"Token verification error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

@method_decorator(csrf_exempt, name='dispatch')
class LogoutView(APIView):
    def options(self, request, *args, **kwargs):
        response = Response(status=200)
        return add_cors_headers(response)
        
    def post(self, request):
        try:
            token_key = request.data.get('token') or request.META.get('HTTP_AUTHORIZATION', '').replace('Token ', '')
            
            if token_key:
                try:
                    token = Token.objects.get(key=token_key)
                    token.delete()
                    return add_cors_headers(Response({"message": "Successfully logged out"}))
                except Token.DoesNotExist:
                    pass  # Token already deleted or invalid
            
            # Even if token doesn't exist, we return success to be consistent
            return add_cors_headers(Response({"message": "Successfully logged out"}))
            
        except Exception as e:
            logger.error(f"Logout error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

# Add a CSRF token endpoint
@method_decorator(ensure_csrf_cookie, name='dispatch')
class GetCSRFToken(APIView):
    permission_classes = [AllowAny]
    
    def get(self, request):
        return add_cors_headers(Response({"message": "CSRF cookie set"}))
