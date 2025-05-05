from django.contrib import admin
from .models import Account, VerificationCode, UserProfile

class AccountAdmin(admin.ModelAdmin):
    list_display = ('id', 'email', 'first_name', 'last_name', 'is_verified', 'is_admin')
    search_fields = ('email', 'first_name', 'last_name')
    readonly_fields = ('created_at', 'last_login')
    list_filter = ('is_verified', 'is_admin')
    ordering = ('-created_at',)

class VerificationCodeAdmin(admin.ModelAdmin):
    list_display = ('user', 'code', 'created_at', 'expires_at', 'is_used')
    search_fields = ('user__email', 'code')
    list_filter = ('is_used',)
    ordering = ('-created_at',)

class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('username', 'user_email', 'location', 'honesty_score', 
                   'activity_status', 'is_verified', 'followers_count', 'following_count')
    search_fields = ('username', 'user__email', 'user__first_name', 'user__last_name', 'location')
    list_filter = ('is_verified', 'activity_status')
    ordering = ('username',)
    
    def user_email(self, obj):
        return obj.user.email
    
    user_email.short_description = 'Email'
    
    def followers_count(self, obj):
        return obj.followers.count()
    
    followers_count.short_description = 'Followers'
    
    def following_count(self, obj):
        return obj.following.count()
    
    following_count.short_description = 'Following'

admin.site.register(Account, AccountAdmin)
admin.site.register(VerificationCode, VerificationCodeAdmin)
admin.site.register(UserProfile, UserProfileAdmin)
