from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    # Existing views
    CustomTokenObtainPairView, RegisterView, LoginView, GoogleLoginView, 
    ProfileView, ProfileImageView, LogoutView, ValidateTokenView, 
    VerifyEmailView, ResendVerificationCodeView, ForgotPasswordView, 
    VerifyResetCodeView, ResetPasswordView, all_users_minimal,
    
    # New Profile views
    UserProfileView, UserProfileUpdateView, UserProfileDetailView,
    UserFollowView, UserUnfollowView, UserFollowersView,
    UserFollowingView, UserSearchView, UserRandomView,
)

urlpatterns = [
    # JWT authentication endpoints
    path('token/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('token/validate/', ValidateTokenView.as_view(), name='token_validate'),
    
    # User management endpoints
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('google-login/', GoogleLoginView.as_view(), name='google_login'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('all-users/', all_users_minimal, name='all_users_minimal'),
    
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
    
    # New user profile endpoints
    path('users/profile/', UserProfileView.as_view(), name='user_profile'),
    path('users/profile/update/', UserProfileUpdateView.as_view(), name='user_profile_update'),
    path('users/<int:user_id>/profile/', UserProfileDetailView.as_view(), name='user_profile_detail'),
    path('users/<int:user_id>/follow/', UserFollowView.as_view(), name='user_follow'),
    path('users/<int:user_id>/unfollow/', UserUnfollowView.as_view(), name='user_unfollow'),
    path('users/<int:user_id>/followers/', UserFollowersView.as_view(), name='user_followers'),
    path('users/<int:user_id>/following/', UserFollowingView.as_view(), name='user_following'),
    path('users/search/', UserSearchView.as_view(), name='user_search'),
    path('users/random/', UserRandomView.as_view(), name='user_random'),
]
