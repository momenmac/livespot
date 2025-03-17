from django.contrib import admin
from .models import Account

# Simplify admin implementation even further
class AccountAdmin(admin.ModelAdmin):
    list_display = ('email', 'first_name', 'last_name', 'is_admin')
    search_fields = ('email', 'first_name', 'last_name')
    
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal info', {'fields': ('first_name', 'last_name', 'profile_picture')}),
        ('Google Auth', {'fields': ('google_id',)}),
        ('Permissions', {'fields': ('is_admin', 'is_active')}),
    )
    
    ordering = ('email',)

admin.site.register(Account, AccountAdmin)
