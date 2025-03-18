from django.urls import path
from .views import (
    RegisterView, LoginView, GoogleLoginView, ProfileView, ProfileImageView,
    VerifyEmailView, ResendVerificationCodeView,
    ForgotPasswordView, VerifyResetCodeView, ResetPasswordView,
    VerifyTokenView, LogoutView, GetCSRFToken
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('google-login/', GoogleLoginView.as_view(), name='google_login'),
    path('profile/', ProfileView.as_view(), name='profile'),
    path('profile-image/', ProfileImageView.as_view(), name='profile_image'),
    path('verify-email/', VerifyEmailView.as_view(), name='verify_email'),
    path('resend-verification-code/', ResendVerificationCodeView.as_view(), name='resend_verification'),
    path('forgot-password/', ForgotPasswordView.as_view(), name='forgot_password'),
    path('verify-reset-code/', VerifyResetCodeView.as_view(), name='verify_reset_code'),
    path('reset-password/', ResetPasswordView.as_view(), name='reset_password'),
    path('verify-token/', VerifyTokenView.as_view(), name='verify_token'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('csrf-token/', GetCSRFToken.as_view(), name='csrf_token'),
]
