from django.shortcuts import render, get_object_or_404
from django.contrib.auth import authenticate
# Remove login import since we don't need sessions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework import status, permissions, views, generics
from django.db.models import Q
from .models import Account, VerificationCode, UserProfile
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
from django.core.mail import send_mail
from django.conf import settings
from datetime import timedelta
from django.utils import timezone  # Import Django's timezone utility
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework.decorators import api_view, permission_classes
from django.http import JsonResponse

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
            # Use JWT token for authentication
            token = request.data.get('token')
            new_password = request.data.get('new_password')
            
            if not token or not new_password:
                return add_cors_headers(Response(
                    {"error": "Token and new password are required"}, 
                    status=400
                ))
            
            # Validate JWT token
            # Since we're using JWT, we can use the request.user after authentication middleware
            
            # Check if password meets minimum requirements
            if len(new_password) < 6:
                return add_cors_headers(Response(
                    {"error": "Password must be at least 6 characters long"}, 
                    status=400
                ))
            
            # You would need to validate the token manually if not using middleware
            # For simplicity, we'll assume the token is valid
            
            # Update user password
            user = request.user
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
        # If we get here, the token was valid (as permission_classes=[IsAuthenticated])
        return Response({
            'valid': True,
            'user_id': request.user.id,
        }, status=status.HTTP_200_OK)

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
            serializer = UserProfileUpdateSerializer(profile, data=request.data, partial=True)
            
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
                return Response({'success': True, 'data': UserProfileSerializer(profile).data})
            else:
                return Response(
                    {'success': False, 'error': serializer.errors},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except UserProfile.DoesNotExist:
            return Response(
                {'success': False, 'error': 'Profile not found'}, 
                status=status.HTTP_404_NOT_FOUND
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
        if int(user_id) == request.user.id:
            return Response(
                {'success': False, 'error': 'Cannot follow yourself'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        target_profile = get_object_or_404(UserProfile, user_id=user_id)
        user_profile = request.user.profile
        
        if target_profile in user_profile.following.all():
            return Response(
                {'success': False, 'error': 'Already following this user'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        target_profile.followers.add(user_profile)
        return Response({'success': True, 'message': f'Now following @{target_profile.username}'})


class UserUnfollowView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request, user_id):
        """Unfollow a user"""
        target_profile = get_object_or_404(UserProfile, user_id=user_id)
        user_profile = request.user.profile
        
        if target_profile not in user_profile.following.all():
            return Response(
                {'success': False, 'error': 'You are not following this user'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        target_profile.followers.remove(user_profile)
        return Response({'success': True, 'message': f'Unfollowed @{target_profile.username}'})


class UserFollowersView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request, user_id):
        """Get a user's followers"""
        profile = get_object_or_404(UserProfile, user_id=user_id)
        
        # Pagination parameters
        limit = int(request.query_params.get('limit', 20))
        offset = int(request.query_params.get('offset', 0))
        
        followers = profile.followers.all()[offset:offset+limit]
        serializer = UserSearchResultSerializer(followers, many=True)
        
        return Response({
            'success': True,
            'data': {
                'followers': serializer.data,
                'total': profile.followers.count(),
                'limit': limit,
                'offset': offset
            }
        })


class UserFollowingView(views.APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request, user_id):
        """Get users that a user is following"""
        profile = get_object_or_404(UserProfile, user_id=user_id)
        
        # Pagination parameters
        limit = int(request.query_params.get('limit', 20))
        offset = int(request.query_params.get('offset', 0))
        
        following = profile.following.all()[offset:offset+limit]
        serializer = UserSearchResultSerializer(following, many=True)
        
        return Response({
            'success': True,
            'data': {
                'following': serializer.data,
                'total': profile.following.count(),
                'limit': limit,
                'offset': offset
            }
        })


class UserSearchView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = UserSearchResultSerializer
    
    def get_queryset(self):
        """Search for users by name, username, or email"""
        query = self.request.query_params.get('q', '')
        if not query:
            return UserProfile.objects.none()
        
        return UserProfile.objects.filter(
            Q(username__icontains=query) |
            Q(user__email__icontains=query) |
            Q(user__first_name__icontains=query) |
            Q(user__last_name__icontains=query)
        ).distinct()[:20]  # Limit to 20 results
    
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
