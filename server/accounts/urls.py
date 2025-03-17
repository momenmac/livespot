from django.urls import path
from .views import (
    RegisterView, LoginView, GoogleLoginView, ProfileView, ProfileImageView,
    VerifyEmailView, ResendVerificationCodeView
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('google-login/', GoogleLoginView.as_view(), name='google-login'),
    path('profile/', ProfileView.as_view(), name='profile'),
    path('update-profile/', ProfileView.as_view(), name='update-profile'),
    path('profile-image/', ProfileImageView.as_view(), name='profile-image'),
    path('verify-email/', VerifyEmailView.as_view(), name='verify-email'),
    path('resend-verification-code/', ResendVerificationCodeView.as_view(), name='resend-verification-code'),
]
