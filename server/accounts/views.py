from django.shortcuts import render
from django.contrib.auth import authenticate, login
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework.authtoken.models import Token
from .models import Account
from .serializers import AccountSerializer
import json
import logging
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator

# Configure logging
logger = logging.getLogger(__name__)

# Add CORS headers to all responses
def add_cors_headers(response):
    response["Access-Control-Allow-Origin"] = "*"  # In production, replace with specific origins
    response["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    response["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
    return response

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

            user = Account.objects.create_user(email=email, first_name=first_name, last_name=last_name, password=password)
            token, _ = Token.objects.get_or_create(user=user)
            
            logger.info(f"User registered successfully: {email}")
            response = Response({
                "message": "User registered", 
                "token": token.key,
                "user": {
                    "id": user.id,
                    "email": user.email,
                    "first_name": user.first_name,
                    "last_name": user.last_name
                }
            })
            return add_cors_headers(response)
        except Exception as e:
            logger.error(f"Register error: {str(e)}")
            print(f"Register error: {str(e)}")
            response = Response({"error": str(e)}, status=500)
            return add_cors_headers(response)

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
