from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    CustomTokenObtainPairView, RegisterView, LoginView, GoogleLoginView, ProfileView, ProfileImageView,
    VerifyEmailView, ResendVerificationCodeView,
    ForgotPasswordView, VerifyResetCodeView, ResetPasswordView,
    LogoutView
)

urlpatterns = [
    # JWT authentication endpoints
    path('token/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # User management endpoints
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('google-login/', GoogleLoginView.as_view(), name='google_login'),
    path('logout/', LogoutView.as_view(), name='logout'),
    
    # Profile management
    path('profile/', ProfileView.as_view(), name='profile'),
    path('profile-image/', ProfileImageView.as_view(), name='profile_image'),
    
    # Email verification
    path('verify-email/', VerifyEmailView.as_view(), name='verify_email'),
    path('resend-verification-code/', ResendVerificationCodeView.as_view(), name='resend_verification'),
    
    # Password reset
    path('forgot-password/', ForgotPasswordView.as_view(), name='forgot_password'),
    path('verify-reset-code/', VerifyResetCodeView.as_view(), name='verify_reset_code'),
    path('reset-password/', ResetPasswordView.as_view(), name='reset_password'),
    
    # Remove the CSRF token endpoint
]
