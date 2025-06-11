from django.shortcuts import render, get_object_or_404
from django.contrib.auth import authenticate
# Remove login import since we don't need sessions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework import status, permissions, views, generics
from django.db.models import Q
from .models import Account, VerificationCode, UserProfile, VerificationRequest
from .serializers import (
    AccountSerializer,
    UserProfileSerializer,
    UserProfileUpdateSerializer,
    UserSearchResultSerializer
)
import json
import logging
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
import random
import string
from django.core.mail import send_mail, EmailMultiAlternatives
from django.conf import settings
from datetime import timedelta
from django.utils import timezone  # Import Django's timezone utility
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework.decorators import api_view, permission_classes
from django.http import JsonResponse

# Import notification models for follow/unfollow notifications
from notifications.models import NotificationQueue, FCMToken, NotificationSettings
import uuid
import traceback

# Configure logging
logger = logging.getLogger(__name__)

# Create custom token serializer
class MyTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        
        # Add custom claims
        token['email'] = user.email
        token['first_name'] = user.first_name
        token['last_name'] = user.last_name
        token['is_verified'] = user.is_verified
        token['is_admin'] = user.is_admin
        
        return token

# Implement custom token view properly
class CustomTokenObtainPairView(TokenObtainPairView):
    """
    Takes email and password and returns access and refresh tokens
    """
    serializer_class = MyTokenObtainPairSerializer

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
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        serializer = AccountSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            tokens = user.get_tokens()
            return Response({
                'user': serializer.data,
                'tokens': tokens
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@method_decorator(csrf_exempt, name='dispatch')
class VerifyEmailView(APIView):
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
                expires_at__gt=timezone.now(),  # Use timezone.now() instead of datetime.now()
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
                created_at__gt=timezone.now() - timedelta(minutes=2)  # Use timezone.now()
            ).count()
            
            if recent_codes > 0:
                return add_cors_headers(Response(
                    {"error": "Please wait before requesting a new code"}, 
                    status=429
                ))
                
            # Generate new verification code
            verification_code = generate_verification_code()
            expires_at = timezone.now() + timedelta(minutes=10)  # Use timezone.now()
            
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

    def post(self, request):
        try:
            email = request.data.get('email')
            password = request.data.get('password')

            user = authenticate(email=email, password=password)
            if user:
                # Update last_login time with timezone aware datetime
                user.last_login = timezone.now()
                user.save(update_fields=['last_login'])
                
                # Use only JWT tokens
                tokens = user.get_tokens()
                
                # Return user data including verification status
                response = Response({
                    "message": "Logged in",
                    "tokens": tokens,
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
                
                # Don't update last_login yet - we'll do this after all modifications
                needs_save = False
                
                # If user exists but doesn't have google_id, this is an existing account
                # We should link the Google account to the existing account
                account_linked = False
                
                if not user.google_id:
                    logger.info(f"Linking Google account to existing account: {email}")
                    print(f"Linking Google account to existing account: {email}")
                    user.google_id = google_id
                    account_linked = True
                    needs_save = True
                    
                    # Update user profile with Google info if provided
                    if first_name and not user.first_name:
                        user.first_name = first_name
                    if last_name and not user.last_name:
                        user.last_name = last_name
                    
                    # Save profile picture if provided and user doesn't have one
                    if profile_picture and (not user.profile_picture or not user.profile_picture.name):
                        # Save profile picture using our helper function
                        save_profile_picture_from_url(user, profile_picture)
                    elif needs_save:
                        # Only save if we made changes but didn't save via profile picture
                        user.save()
                
                # Update last_login time - do this after all other modifications
                user.last_login = timezone.now()
                user.save(update_fields=['last_login'])
                
                # User already exists, just log them in
                logger.info(f"Existing user logging in via Google: {email}")
                print(f"Existing user logging in via Google: {email}")
                
                # Remove login(request, user) - we don't need session login
                
                # Generate JWT tokens
                tokens = user.get_tokens()
                
                user_data = AccountSerializer(user).data
                # Ensure profile picture URL is fully qualified
                if user.profile_picture and user.profile_picture.url:
                    user_data['profile_picture_url'] = request.build_absolute_uri(user.profile_picture.url)
                
                return add_cors_headers(Response({
                    "message": "User logged in",
                    "user": user_data,
                    "tokens": tokens,
                    "is_new_account": False,
                    "account_linked": account_linked
                }))
                
            except Account.DoesNotExist:
                # User doesn't exist, create a new account
                logger.info(f"Creating new account via Google: {email}")
                print(f"Creating new account via Google: {email}")
                
                # Generate a secure random password - user won't use this
                # since they'll authenticate with Google
                import secrets
                random_password = secrets.token_urlsafe(32)
                
                # Create new user with random password
                # Note: last_login will be set automatically by Django when the user is created
                user = Account.objects.create_user(
                    email=email,
                    password=random_password,
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
                
                # Remove login(request, user) - we don't need session login
                
                # Generate JWT tokens
                tokens = user.get_tokens()
                
                user_data = AccountSerializer(user).data
                # Ensure profile picture URL is fully qualified
                if user.profile_picture and user.profile_picture.url:
                    user_data['profile_picture_url'] = request.build_absolute_uri(user.profile_picture.url)
                
                return add_cors_headers(Response({
                    "message": "New user created and logged in",
                    "user": user_data,
                    "tokens": tokens,
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
    def get(self, request):
        try:
            user = request.user
            
            # First, check if user has a profile
            try:
                profile = user.profile
                # Return both account and profile data
                serializer = UserProfileSerializer(profile)
                return add_cors_headers(Response({
                    'success': True, 
                    'data': serializer.data
                }))
            except UserProfile.DoesNotExist:
                # If no profile exists, return just account data with error flag
                serializer = AccountSerializer(user)
                return add_cors_headers(Response({
                    'success': False,
                    'error': 'Profile not found',
                    'data': {
                        'account': serializer.data
                    }
                }, status=status.HTTP_404_NOT_FOUND))
                
        except Exception as e:
            logger.error(f"Error fetching user profile: {str(e)}")
            return add_cors_headers(Response({
                "success": False,
                "error": str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR))

@method_decorator(csrf_exempt, name='dispatch')
class ProfileImageView(APIView):
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
                expires_at = timezone.now() + timedelta(minutes=15)  # Use timezone.now()
                
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
                expires_at__gt=timezone.now(),  # Use timezone.now()
                is_used=False
            ).first()
            
            if not code_obj:
                return add_cors_headers(Response({"error": "Invalid or expired code"}, status=400))
            
            # Generate JWT tokens for password reset
            tokens = user.get_tokens()
            
            return add_cors_headers(Response({
                "message": "Code verified successfully",
                "reset_token": tokens['access'],  # Use access token as reset token
                "tokens": tokens
            }))
            
        except Exception as e:
            logger.error(f"Verify reset code error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

@method_decorator(csrf_exempt, name='dispatch')
class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        try:
            # Get reset token and new password from request
            reset_token = request.data.get('reset_token')
            new_password = request.data.get('new_password')
            
            if not reset_token or not new_password:
                return add_cors_headers(Response(
                    {"error": "Reset token and new password are required"}, 
                    status=400
                ))
            
            # Check if password meets minimum requirements
            if len(new_password) < 6:
                return add_cors_headers(Response(
                    {"error": "Password must be at least 6 characters long"}, 
                    status=400
                ))
            
            # Validate JWT token manually since this is AllowAny endpoint
            try:
                from rest_framework_simplejwt.tokens import AccessToken
                decoded_token = AccessToken(reset_token)
                user_id = decoded_token['user_id']
                user = Account.objects.get(id=user_id)
            except Exception as e:
                logger.error(f"Invalid reset token: {str(e)}")
                return add_cors_headers(Response(
                    {"error": "Invalid or expired reset token"}, 
                    status=400
                ))
            
            # Update user password
            user.set_password(new_password)
            user.save()
            
            # Mark all verification codes as used
            VerificationCode.objects.filter(user=user).update(is_used=True)
            
            # Generate new JWT tokens
            tokens = user.get_tokens()
            
            return add_cors_headers(Response({
                "message": "Password reset successfully",
                "tokens": tokens
            }))
            
        except Exception as e:
            logger.error(f"Reset password error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

@method_decorator(csrf_exempt, name='dispatch')
class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        try:
            # Handle refresh token blacklisting for JWT
            refresh_token = request.data.get("refresh")
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
                
            return Response({"message": "Successfully logged out"}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

@method_decorator(csrf_exempt, name='dispatch')
class ValidateTokenView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        try:
            # If we get here, the token was valid (as permission_classes=[IsAuthenticated])
            user = request.user
            
            # Get token from request header
            auth_header = request.META.get('HTTP_AUTHORIZATION', '')
            if auth_header.startswith('Bearer '):
                access_token = auth_header.split(' ')[1]
                
                # Decode token to get expiration info
                from rest_framework_simplejwt.tokens import AccessToken
                try:
                    token = AccessToken(access_token)
                    exp_timestamp = token.get('exp')
                    
                    # Calculate time until expiration
                    exp_datetime = timezone.datetime.fromtimestamp(exp_timestamp, tz=timezone.timezone.utc)
                    time_until_exp = exp_datetime - timezone.now()
                    
                    return Response({
                        'valid': True,
                        'user_id': user.id,
                        'user_email': user.email,
                        'expires_at': exp_datetime.isoformat(),
                        'expires_in_seconds': int(time_until_exp.total_seconds()),
                        'expires_in_minutes': int(time_until_exp.total_seconds() / 60),
                        'needs_refresh_soon': time_until_exp.total_seconds() < 300,  # Less than 5 minutes
                    }, status=status.HTTP_200_OK)
                    
                except Exception as token_error:
                    logger.warning(f"Error decoding token: {token_error}")
                    # Fallback to basic validation
                    return Response({
                        'valid': True,
                        'user_id': user.id,
                        'user_email': user.email,
                        'token_decode_error': str(token_error)
                    }, status=status.HTTP_200_OK)
            
            # Fallback if no token in header
            return Response({
                'valid': True,
                'user_id': user.id,
                'user_email': user.email,
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Token validation error: {e}")
            return Response({
                'valid': False,
                'error': str(e)
            }, status=status.HTTP_401_UNAUTHORIZED)

@api_view(['GET'])
@permission_classes([AllowAny])
def all_users_minimal(request):
    """
    Return all users with minimal info: id, name, email, avatarUrl.
    Ensures avatarUrl is a full URL using BASE_URL if needed.
    """
    users = Account.objects.all()
    data = []
    from django.conf import settings
    base_url = getattr(settings, "BASE_URL", None)
    for user in users:
        name = f"{user.first_name} {user.last_name}".strip()
        avatar_url = user.profile_picture.url if user.profile_picture else ""
        if avatar_url and not avatar_url.startswith("http"):
            # Add BASE_URL if needed
            if base_url:
                # Ensure avatar_url starts with a single slash
                if not avatar_url.startswith("/"):
                    avatar_url = "/" + avatar_url
                avatar_url = base_url.rstrip("/") + avatar_url
        data.append({
            "id": str(user.id),
            "name": name,
            "email": user.email,
            "avatarUrl": avatar_url,
            "is_admin": user.is_admin,
        })
    return add_cors_headers(JsonResponse(data, safe=False))

class UserProfileView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        """Get current user's profile"""
        try:
            profile = request.user.profile
            serializer = UserProfileSerializer(profile)
            return Response({'success': True, 'data': serializer.data})
        except UserProfile.DoesNotExist:
            return Response(
                {'success': False, 'error': 'Profile not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
    
    def post(self, request):
        """Create a profile if it doesn't exist (should rarely be needed due to signal)"""
        try:
            # Check if profile already exists
            profile = UserProfile.objects.get(user=request.user)
            return Response(
                {'success': False, 'error': 'Profile already exists'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        except UserProfile.DoesNotExist:
            # Create new profile with data from request
            data = request.data.copy()
            
            # Default username to email prefix if not provided
            if 'username' not in data:
                data['username'] = request.user.email.split('@')[0]
            
            # Ensure username is unique
            username = data['username']
            counter = 1
            while UserProfile.objects.filter(username=username).exists():
                username = f"{data['username']}{counter}"
                counter += 1
            data['username'] = username
            
            # Create profile
            profile = UserProfile.objects.create(
                user=request.user,
                username=data['username'],
                bio=data.get('bio', ''),
                location=data.get('location', ''),
                website=data.get('website', ''),
                interests=data.get('interests')
            )
            
            serializer = UserProfileSerializer(profile)
            return Response({'success': True, 'data': serializer.data}, status=status.HTTP_201_CREATED)


class UserProfileUpdateView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        """Update current user's profile"""
        try:
            profile = request.user.profile
            user_account = request.user
            
            # Separate the data for profile and account updates
            profile_data = {}
            account_data = {}
            
            # Parse the name field if present
            if 'name' in request.data:
                name = request.data['name'].strip()
                if name:
                    # Split name into first and last name
                    name_parts = name.split(' ', 1)
                    account_data['first_name'] = name_parts[0]
                    account_data['last_name'] = name_parts[1] if len(name_parts) > 1 else ''
                else:
                    account_data['first_name'] = ''
                    account_data['last_name'] = ''
            
            # Add other profile fields
            for field in ['username', 'bio', 'location', 'website', 'interests']:
                if field in request.data:
                    profile_data[field] = request.data[field]
            
            # Update user account (name fields) if there's account data
            if account_data:
                for key, value in account_data.items():
                    setattr(user_account, key, value)
                user_account.save()
                logger.info(f"Updated account for user {user_account.id}: {account_data}")
            
            # Update profile if there's profile data
            if profile_data:
                serializer = UserProfileUpdateSerializer(profile, data=profile_data, partial=True)
                
                if serializer.is_valid():
                    # Check username uniqueness if it's being changed
                    if 'username' in serializer.validated_data:
                        new_username = serializer.validated_data['username']
                        if new_username != profile.username and UserProfile.objects.filter(username=new_username).exists():
                            return Response(
                                {'success': False, 'error': 'Username is already taken'},
                                status=status.HTTP_400_BAD_REQUEST
                            )
                    
                    serializer.save()
                    logger.info(f"Updated profile for user {user_account.id}: {profile_data}")
                else:
                    return Response(
                        {'success': False, 'error': serializer.errors},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            
            # Return the updated profile data
            return Response({'success': True, 'data': UserProfileSerializer(profile).data})
            
        except UserProfile.DoesNotExist:
            return Response(
                {'success': False, 'error': 'Profile not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"Error updating profile for user {request.user.id}: {str(e)}")
            return Response(
                {'success': False, 'error': 'An error occurred while updating profile'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class UserProfileDetailView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request, user_id):
        """Get another user's profile by ID"""
        profile = get_object_or_404(UserProfile, user_id=user_id)
        serializer = UserProfileSerializer(profile)
        return Response({'success': True, 'data': serializer.data})


class UserFollowView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request, user_id):
        """Follow another user"""
        print(f"🔄 DEBUG: Follow request - User {request.user.id} wants to follow User {user_id}")
        
        if int(user_id) == request.user.id:
            print(f"❌ DEBUG: User {request.user.id} tried to follow themselves")
            return Response(
                {'success': False, 'error': 'Cannot follow yourself'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        target_profile = get_object_or_404(UserProfile, user_id=user_id)
        user_profile = request.user.profile
        
        print(f"✅ DEBUG: Found target profile: {target_profile.username} (ID: {target_profile.user.id})")
        print(f"✅ DEBUG: Follower profile: {user_profile.username} (ID: {user_profile.user.id})")
        
        if target_profile in user_profile.following.all():
            print(f"⚠️ DEBUG: User {user_profile.username} is already following {target_profile.username}")
            return Response(
                {'success': False, 'error': 'Already following this user'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Add the follow relationship
        target_profile.followers.add(user_profile)
        print(f"✅ DEBUG: Successfully added follow relationship: {user_profile.username} -> {target_profile.username}")
        
        # Send follow notification
        try:
            print(f"🔔 DEBUG: Attempting to send follow notification to {target_profile.user.email}")
            
            # Check if target user has notification settings
            notification_settings = getattr(target_profile.user, 'notification_settings', None)
            print(f"🔔 DEBUG: Target user notification settings: {notification_settings}")
            
            if not notification_settings:
                print(f"⚠️ DEBUG: No notification settings found for user {target_profile.user.email}")
                # Create default notification settings with correct field names
                notification_settings = NotificationSettings.objects.create(
                    user=target_profile.user,
                    friend_requests=True,
                    follow_notifications=True,
                    events=True,
                    reminders=True,
                    nearby_events=True,
                    system_notifications=True
                )
                print(f"✅ DEBUG: Created default notification settings for user {target_profile.user.email}")
            
            # Now check if follow notifications are enabled and send notification if so
            print(f"🔔 DEBUG: Follow notifications enabled: {notification_settings.follow_notifications}")
            if notification_settings.follow_notifications:
                # Get follower avatar URL
                follower_avatar = ''
                if user_profile.user.profile_picture:
                    follower_avatar = request.build_absolute_uri(user_profile.user.profile_picture.url)
                
                print(f"🔔 DEBUG: Creating notification with follower avatar: {follower_avatar}")
                
                notification = NotificationQueue.objects.create(
                    user=target_profile.user,
                    notification_type='new_follower',
                    title='New Follower',
                    body=f'{user_profile.username} started following you',
                    data={
                        'type': 'new_follower',
                        'followerUserId': str(user_profile.user.id),
                        'followerUserName': user_profile.username,
                        'followerUserAvatar': follower_avatar,
                    },
                    priority='normal'
                )
                print(f"✅ DEBUG: Successfully queued follow notification (ID: {notification.id}) for {target_profile.user.email}")
                
                # Import and use the notification service to send immediately
                try:
                    from notifications.services import notification_service
                    print(f"🚀 DEBUG: Sending notification immediately...")
                    success = notification_service.send_notification(notification)
                    if success:
                        print(f"✅ DEBUG: Follow notification sent successfully!")
                        # Mark as sent to prevent duplicate processing
                        notification.status = 'sent'
                        notification.processed_at = timezone.now()
                        notification.save()
                    else:
                        print(f"❌ DEBUG: Failed to send follow notification")
                except Exception as service_error:
                    print(f"❌ DEBUG: Notification service error: {service_error}")
                    print(f"❌ DEBUG: Service exception details: {traceback.format_exc()}")
                
                logger.info(f"Queued follow notification for {target_profile.user.email}")
            else:
                print(f"⚠️ DEBUG: Follow notifications are disabled for user {target_profile.user.email}")
                
        except Exception as e:
            print(f"❌ DEBUG: Failed to queue follow notification: {str(e)}")
            print(f"❌ DEBUG: Exception details: {traceback.format_exc()}")
            logger.warning(f"Failed to queue follow notification: {e}")
        
        print(f"🎉 DEBUG: Follow operation completed successfully")
        return Response({'success': True, 'message': f'Now following @{target_profile.username}'})

class UserUnfollowView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request, user_id):
        """Unfollow another user"""
        print(f"🔄 DEBUG: Unfollow request - User {request.user.id} wants to unfollow User {user_id}")
        
        if int(user_id) == request.user.id:
            print(f"❌ DEBUG: User {request.user.id} tried to unfollow themselves")
            return Response(
                {'success': False, 'error': 'Cannot unfollow yourself'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        target_profile = get_object_or_404(UserProfile, user_id=user_id)
        user_profile = request.user.profile
        
        print(f"✅ DEBUG: Found target profile: {target_profile.username} (ID: {target_profile.user.id})")
        print(f"✅ DEBUG: Unfollower profile: {user_profile.username} (ID: {user_profile.user.id})")
        
        if target_profile not in user_profile.following.all():
            print(f"⚠️ DEBUG: User {user_profile.username} is not following {target_profile.username}")
            return Response(
                {'success': False, 'error': 'Not following this user'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Remove the follow relationship
        target_profile.followers.remove(user_profile)
        print(f"✅ DEBUG: Successfully removed follow relationship: {user_profile.username} -/-> {target_profile.username}")
        
        print(f"🎉 DEBUG: Unfollow operation completed successfully")
        return Response({'success': True, 'message': f'Unfollowed @{target_profile.username}'})

class UserFollowersView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request, user_id):
        """Get list of users who follow the specified user"""
        try:
            target_profile = get_object_or_404(UserProfile, user_id=user_id)
            
            # Get followers
            followers = target_profile.followers.all().select_related('user')
            
            # Serialize the results
            serializer = UserSearchResultSerializer(followers, many=True)
            
            return Response({
                'success': True,
                'data': {
                    'followers': serializer.data,
                    'total': followers.count(),
                    'user_id': user_id
                }
            })
            
        except Exception as e:
            logger.error(f"Error fetching followers for user {user_id}: {str(e)}")
            return Response(
                {'success': False, 'error': 'Failed to fetch followers'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class UserFollowingView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request, user_id):
        """Get list of users that the specified user follows"""
        try:
            target_profile = get_object_or_404(UserProfile, user_id=user_id)
            
            # Get following (users that this user follows)
            following = target_profile.following.all().select_related('user')
            
            # Serialize the results
            serializer = UserSearchResultSerializer(following, many=True)
            
            return Response({
                'success': True,
                'data': {
                    'following': serializer.data,
                    'total': following.count(),
                    'user_id': user_id
                }
            })
            
        except Exception as e:
            logger.error(f"Error fetching following for user {user_id}: {str(e)}")
            return Response(
                {'success': False, 'error': 'Failed to fetch following'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class UserSearchView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        """Search for users by username, name, or email"""
        try:
            query = request.query_params.get('q', '').strip()
            limit = int(request.query_params.get('limit', 20))
            limit = min(limit, 50)  # Cap at 50 to prevent abuse
            
            if not query or len(query) < 2:
                return Response(
                    {'success': False, 'error': 'Query must be at least 2 characters long'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Search in multiple fields
            search_results = UserProfile.objects.filter(
                Q(username__icontains=query) |
                Q(user__first_name__icontains=query) |
                Q(user__last_name__icontains=query) |
                Q(user__email__icontains=query)
            ).exclude(
                user_id=request.user.id  # Exclude current user
            ).select_related('user')[:limit]
            
            # Serialize the results
            serializer = UserSearchResultSerializer(search_results, many=True)
            
            return Response({
                'success': True,
                'data': {
                    'users': serializer.data,
                    'total': len(serializer.data),
                    'query': query,
                    'limit': limit
                }
            })
            
        except ValueError:
            return Response(
                {'success': False, 'error': 'Invalid limit parameter'},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.error(f"Error searching users with query '{query}': {str(e)}")
            return Response(
                {'success': False, 'error': 'Failed to search users'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class VerificationRequestView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        """Submit a verification request"""
        try:
            reason = request.data.get('reason', '').strip()
            
            if not reason:
                return Response({
                    'success': False,
                    'error': 'Reason for verification is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            user = request.user
            
            # Check if user already has a pending request
            existing_request = VerificationRequest.objects.filter(
                user=user,
                status=VerificationRequest.PENDING
            ).first()
            
            if existing_request:
                return Response({
                    'success': False,
                    'error': 'You already have a pending verification request'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Create new verification request
            verification_request = VerificationRequest.objects.create(
                user=user,
                reason=reason
            )
            
            # Send email notification to user
            try:
                self._send_verification_request_email(user, reason)
            except Exception as e:
                logger.error(f"Failed to send verification email to {user.email}: {e}")
                # Don't fail the request if email fails
            
            return Response({
                'success': True,
                'message': 'Verification request submitted successfully. We will contact you via email soon.',
                'data': {
                    'request_id': verification_request.id,
                    'status': verification_request.status,
                    'created_at': verification_request.created_at
                }
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            logger.error(f"Error submitting verification request: {e}")
            return Response({
                'success': False,
                'error': 'Failed to submit verification request'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def get(self, request):
        """Get user's verification requests"""
        try:
            user = request.user
            requests = VerificationRequest.objects.filter(user=user)
            
            request_data = []
            for req in requests:
                request_data.append({
                    'id': req.id,
                    'reason': req.reason,
                    'status': req.status,
                    'admin_notes': req.admin_notes,
                    'created_at': req.created_at,
                    'updated_at': req.updated_at
                })
            
            return Response({
                'success': True,
                'data': {
                    'requests': request_data
                }
            })
            
        except Exception as e:
            logger.error(f"Error fetching verification requests: {e}")
            return Response({
                'success': False,
                'error': 'Failed to fetch verification requests'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def _send_verification_request_email(self, user, reason):
        """Send verification request confirmation email to user"""
        try:
            subject = 'Verification Request Received - LiveSpot'
            
            # Create HTML email content
            html_content = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Verification Request Received</title>
                <style>
                    body {{
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                        line-height: 1.6;
                        color: #333;
                        max-width: 600px;
                        margin: 0 auto;
                        padding: 20px;
                        background-color: #f8f9fa;
                    }}
                    .container {{
                        background-color: white;
                        border-radius: 12px;
                        padding: 40px;
                        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                    }}
                    .header {{
                        text-align: center;
                        margin-bottom: 30px;
                    }}
                    .logo {{
                        font-size: 28px;
                        font-weight: bold;
                        color: #007bff;
                        margin-bottom: 10px;
                    }}
                    .title {{
                        font-size: 24px;
                        font-weight: 600;
                        color: #2c3e50;
                        margin-bottom: 20px;
                    }}
                    .content {{
                        margin-bottom: 30px;
                    }}
                    .highlight {{
                        background-color: #e3f2fd;
                        padding: 20px;
                        border-radius: 8px;
                        border-left: 4px solid #007bff;
                        margin: 20px 0;
                    }}
                    .footer {{
                        text-align: center;
                        color: #6c757d;
                        font-size: 14px;
                        margin-top: 30px;
                        padding-top: 20px;
                        border-top: 1px solid #e9ecef;
                    }}
                    .button {{
                        display: inline-block;
                        padding: 12px 24px;
                        background-color: #007bff;
                        color: white;
                        text-decoration: none;
                        border-radius: 6px;
                        font-weight: 500;
                        margin: 20px 0;
                    }}
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <div class="logo">LiveSpot</div>
                        <div class="title">Verification Request Received</div>
                    </div>
                    
                    <div class="content">
                        <p>Hello {user.first_name} {user.last_name},</p>
                        
                        <p>We've received your verification request for your LiveSpot account. Thank you for your interest in getting verified!</p>
                        
                        <div class="highlight">
                            <strong>Your verification reason:</strong><br>
                            "{reason}"
                        </div>
                        
                        <p><strong>What happens next?</strong></p>
                        <ul>
                            <li>Our verification team will review your request</li>
                            <li>We may contact you for additional information or documentation</li>
                            <li>The review process typically takes 3-7 business days</li>
                            <li>You'll receive an email notification with the decision</li>
                        </ul>
                        
                        <p><strong>Requirements for verification:</strong></p>
                        <ul>
                            <li>Active and authentic account</li>
                            <li>Complete profile information</li>
                            <li>Notable presence in your field (business, content creation, public figure, etc.)</li>
                            <li>Compliance with our community guidelines</li>
                        </ul>
                        
                        <p>If you have any questions about the verification process, feel free to reply to this email.</p>
                        
                        <p>Best regards,<br>
                        The LiveSpot Verification Team</p>
                    </div>
                    
                    <div class="footer">
                        <p>This email was sent to {user.email}</p>
                        <p>© 2025 LiveSpot. All rights reserved.</p>
                    </div>
                </div>
            </body>
            </html>
            """
            
            # Create plain text version
            text_content = f"""
            Verification Request Received - LiveSpot
            
            Hello {user.first_name} {user.last_name},
            
            We've received your verification request for your LiveSpot account.
            
            Your verification reason: "{reason}"
            
            What happens next?
            - Our verification team will review your request
            - We may contact you for additional information
            - Review process takes 3-7 business days
            - You'll receive an email with the decision
            
            Best regards,
            The LiveSpot Verification Team
            
            This email was sent to {user.email}
            """
            
            # Send email
            email = EmailMultiAlternatives(
                subject=subject,
                body=text_content,
                from_email=settings.DEFAULT_FROM_EMAIL,
                to=[user.email]
            )
            email.attach_alternative(html_content, "text/html")
            email.send()
            
            logger.info(f"Verification request email sent to {user.email}")
            
        except Exception as e:
            logger.error(f"Failed to send verification email: {e}")
            raise

# Change Password View
@method_decorator(csrf_exempt, name='dispatch')
class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            current_password = request.data.get('current_password')
            new_password = request.data.get('new_password')
            
            if not current_password or not new_password:
                return add_cors_headers(Response({
                    "error": "Current password and new password are required"
                }, status=400))
            
            user = request.user
            
            # Verify current password
            if not user.check_password(current_password):
                return add_cors_headers(Response({
                    "error": "Current password is incorrect"
                }, status=400))
            
            # Validate new password
            if len(new_password) < 6:
                return add_cors_headers(Response({
                    "error": "New password must be at least 6 characters long"
                }, status=400))
            
            # Set new password
            user.set_password(new_password)
            user.save()
            
            logger.info(f"Password changed for user: {user.email}")
            
            return add_cors_headers(Response({
                "message": "Password changed successfully"
            }))
            
        except Exception as e:
            logger.error(f"Change password error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

# Change Email View
@method_decorator(csrf_exempt, name='dispatch')
class ChangeEmailView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            new_email = request.data.get('new_email')
            password = request.data.get('password')
            
            if not new_email or not password:
                return add_cors_headers(Response({
                    "error": "New email and password are required"
                }, status=400))
            
            user = request.user
            
            # Verify password
            if not user.check_password(password):
                return add_cors_headers(Response({
                    "error": "Password is incorrect"
                }, status=400))
            
            # Check if email is already in use
            if Account.objects.filter(email=new_email).exclude(id=user.id).exists():
                return add_cors_headers(Response({
                    "error": "Email is already in use"
                }, status=400))
            
            # Update email
            old_email = user.email
            user.email = new_email
            user.is_verified = False  # Require re-verification for new email
            user.save()
            
            logger.info(f"Email changed from {old_email} to {new_email}")
            
            return add_cors_headers(Response({
                "message": "Email changed successfully. Please verify your new email address."
            }))
            
        except Exception as e:
            logger.error(f"Change email error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

# Data Download Request View
@method_decorator(csrf_exempt, name='dispatch')
class DataDownloadRequestView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            user = request.user
            
            # Create data download request record (you can create a model for this)
            # For now, we'll just send an email notification
            
            subject = f"Data Download Request - {user.email}"
            
            # Send email to user
            user_message = f"""
            Hello {user.first_name} {user.last_name},
            
            We have received your request to download your personal data from LiveSpot.
            
            Your data package will be prepared within 24-48 hours and sent to this email address.
            
            The package will include:
            - Account information
            - Profile data
            - Posts and comments
            - Activity history
            
            If you have any questions, please contact our support team.
            
            Best regards,
            The LiveSpot Team
            """
            
            from django.core.mail import send_mail
            send_mail(
                subject="Your Data Download Request - LiveSpot",
                message=user_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                fail_silently=False
            )
            
            # Also notify admin/support team
            admin_message = f"Data download request from {user.email} ({user.first_name} {user.last_name})"
            send_mail(
                subject=subject,
                message=admin_message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[settings.DEFAULT_FROM_EMAIL],  # Send to admin email
                fail_silently=True
            )
            
            logger.info(f"Data download request from {user.email}")
            
            return add_cors_headers(Response({
                "message": "Data download request submitted successfully. You will receive your data via email within 24-48 hours."
            }))
            
        except Exception as e:
            logger.error(f"Data download request error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))

# Account Deactivation View
@method_decorator(csrf_exempt, name='dispatch')
class DeactivateAccountView(APIView):
    permission_classes = [IsAuthenticated]
    
    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        return Response({
            'success': True,
            'data': {
                'users': serializer.data,
                'total': len(serializer.data)
            }
        })
    
    def post(self, request):
        try:
            user = request.user
            
            # Mark account as inactive (you might want to add an is_active field to Account model)
            # For now, we'll just clear sensitive data and logout
            
            # Clear FCM tokens
            FCMToken.objects.filter(user=user).delete()
            
            # You could add an is_active field to Account model and set it to False
            # user.is_active = False
            # user.save()
            
            logger.info(f"Account deactivated for user: {user.email}")
            
            return add_cors_headers(Response({
                "message": "Account deactivated successfully"
            }))
            
        except Exception as e:
            logger.error(f"Account deactivation error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))


class UserRandomView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        """Get random users for suggestions"""
        try:
            # Get limit parameter, default to 10
            limit = int(request.query_params.get('limit', 10))
            limit = min(limit, 50)  # Cap at 50 to prevent abuse
            
            # Get current user to exclude from suggestions
            current_user = request.user
            
            # Get users that current user is already following to exclude them
            try:
                current_profile = current_user.profile
                following_ids = current_profile.following.values_list('user_id', flat=True)
            except UserProfile.DoesNotExist:
                following_ids = []
            
            # Get random user profiles, excluding current user and users they're already following
            # Also exclude users without profiles (just in case)
            random_profiles = UserProfile.objects.exclude(
                user_id=current_user.id
            ).exclude(
                user_id__in=following_ids
            ).select_related('user').order_by('?')[:limit]
            
            # Serialize the results
            serializer = UserSearchResultSerializer(random_profiles, many=True)
            
            return Response({
                'success': True,
                'data': {
                    'users': serializer.data,
                    'total': len(serializer.data),
                    'limit': limit
                }
            })
            
        except ValueError:
            return Response(
                {'success': False, 'error': 'Invalid limit parameter'},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.error(f"Error fetching random users: {str(e)}")
            return Response(
                {'success': False, 'error': 'Failed to fetch suggested users'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# Account Deletion View
@method_decorator(csrf_exempt, name='dispatch')
class DeleteAccountView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            password = request.data.get('password')
            
            if not password:
                return add_cors_headers(Response({
                    "error": "Password confirmation is required"
                }, status=400))
            
            user = request.user
            
            # Verify password
            if not user.check_password(password):
                return add_cors_headers(Response({
                    "error": "Password is incorrect"
                }, status=400))
            
            user_email = user.email
            
            # Delete related data
            try:
                # Delete FCM tokens
                FCMToken.objects.filter(user=user).delete()
                
                # Delete notifications
                NotificationQueue.objects.filter(user=user).delete()
                
                # Delete notification settings
                NotificationSettings.objects.filter(user=user).delete()
                
                # Delete user profile if exists
                UserProfile.objects.filter(account=user).delete()
                
                # Delete verification codes
                VerificationCode.objects.filter(user=user).delete()
                
                # Delete verification requests
                VerificationRequest.objects.filter(user=user).delete()
                
                # Finally delete the user account
                user.delete()
                
                logger.info(f"Account permanently deleted: {user_email}")
                
                return add_cors_headers(Response({
                    "message": "Account deleted successfully"
                }))
                
            except Exception as deletion_error:
                logger.error(f"Error during account deletion: {deletion_error}")
                return add_cors_headers(Response({
                    "error": "Failed to delete account completely"
                }, status=500))
            
        except Exception as e:
            logger.error(f"Account deletion error: {str(e)}")
            return add_cors_headers(Response({"error": str(e)}, status=500))
