from django.core.management.base import BaseCommand
from django.utils import timezone
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken

class Command(BaseCommand):
    help = 'Clean up expired tokens from the database'

    def handle(self, *args, **options):
        # Delete expired blacklisted tokens
        expired_tokens = OutstandingToken.objects.filter(expires_at__lt=timezone.now())
        
        # Count tokens before deletion
        total_count = OutstandingToken.objects.count()
        expired_count = expired_tokens.count()
        
        # Count blacklisted tokens that will be deleted
        blacklisted_count = BlacklistedToken.objects.filter(token__expires_at__lt=timezone.now()).count()
        
        # Delete blacklisted tokens first as they reference outstanding tokens
        BlacklistedToken.objects.filter(token__in=expired_tokens).delete()
        
        # Then delete outstanding tokens
        deleted_count = expired_tokens.delete()[0]
        
        self.stdout.write(
            self.style.SUCCESS(
                f'Cleaned up {deleted_count} expired tokens\n'
                f'Removed {blacklisted_count} blacklisted tokens\n'
                f'Remaining tokens: {total_count - deleted_count}'
            )
        )
