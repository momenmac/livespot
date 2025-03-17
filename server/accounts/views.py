from django.shortcuts import render

# Create your views here.
from django.contrib.auth import authenticate, login
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework.authtoken.models import Token
from .models import Account
from .serializers import AccountSerializer

class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email')
        first_name = request.data.get('first_name')
        last_name = request.data.get('last_name')
        password = request.data.get('password')

        if Account.objects.filter(email=email).exists():
            return Response({"error": "Email already registered"}, status=400)

        user = Account.objects.create_user(email=email, first_name=first_name, last_name=last_name, password=password)
        token, _ = Token.objects.get_or_create(user=user)

        return Response({"message": "User registered", "token": token.key})

class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')

        user = authenticate(email=email, password=password)
        if user:
            login(request, user)
            token, _ = Token.objects.get_or_create(user=user)
            return Response({"message": "Logged in", "token": token.key})
        return Response({"error": "Invalid credentials"}, status=401)

class GoogleLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        google_id = request.data.get('google_id')
        email = request.data.get('email')
        first_name = request.data.get('first_name')
        last_name = request.data.get('last_name')
        profile_picture = request.data.get('profile_picture')

        if not google_id or not email:
            return Response({"error": "Invalid Google credentials"}, status=400)

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

        return Response({
            "message": "User logged in",
            "user": AccountSerializer(user).data,
            "token": token.key
        })
