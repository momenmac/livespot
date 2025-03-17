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
from django.views.decorators.csrf import csrf_exempt
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
                response = Response({"message": "Logged in", "token": token.key})
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

            if not google_id or not email:
                response = Response({"error": "Invalid Google credentials"}, status=400)
                return add_cors_headers(response)

            user, created = Account.objects.get_or_create(email=email, defaults={
                "first_name": first_name,
                "last_name": last_name,
                "google_id": google_id
            })

            if created or not user.google_id:
                user.google_id = google_id
                if profile_picture:
                    user.profile_picture = profile_picture
                user.save()

            login(request, user)
            token, _ = Token.objects.get_or_create(user=user)

            response = Response({
                "message": "User logged in",
                "user": AccountSerializer(user).data,
                "token": token.key
            })
            return add_cors_headers(response)
        except Exception as e:
            print(f"Google login error: {str(e)}")
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
