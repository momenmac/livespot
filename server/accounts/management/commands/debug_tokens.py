from django.core.management.base import BaseCommand
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from accounts.models import Account
from datetime import timedelta


class Command(BaseCommand):
    help = 'Debug JWT token issues and show token statistics'

    def add_arguments(self, parser):
        parser.add_argument(
            '--user-email',
            type=str,
            help='Check tokens for specific user email',
        )
        parser.add_argument(
            '--show-stats',
            action='store_true',
            help='Show overall token statistics',
        )
        parser.add_argument(
            '--cleanup-expired',
            action='store_true',
            help='Clean up expired blacklisted tokens',
        )

    def handle(self, *args, **options):
        if options['user_email']:
            self.check_user_tokens(options['user_email'])
        
        if options['show_stats']:
            self.show_token_stats()
            
        if options['cleanup_expired']:
            self.cleanup_expired_tokens()

    def check_user_tokens(self, email):
        try:
            user = Account.objects.get(email=email)
            self.stdout.write(f"\n=== Token Status for {email} ===")
            
            # Get user's outstanding tokens
            outstanding_tokens = OutstandingToken.objects.filter(user=user)
            self.stdout.write(f"Outstanding tokens: {outstanding_tokens.count()}")
            
            for token in outstanding_tokens:
                is_blacklisted = BlacklistedToken.objects.filter(token=token).exists()
                status = "BLACKLISTED" if is_blacklisted else "ACTIVE"
                self.stdout.write(f"  Token ID: {token.id} - Status: {status}")
                self.stdout.write(f"  Created: {token.created_at}")
                self.stdout.write(f"  Expires: {token.expires_at}")
                self.stdout.write(f"  Token: {token.token[:50]}...")
                self.stdout.write("  ---")
                
        except Account.DoesNotExist:
            self.stdout.write(f"User with email {email} not found")

    def show_token_stats(self):
        self.stdout.write("\n=== JWT Token Statistics ===")
        
        total_outstanding = OutstandingToken.objects.count()
        total_blacklisted = BlacklistedToken.objects.count()
        active_tokens = total_outstanding - total_blacklisted
        
        # Tokens expiring in next 24 hours
        tomorrow = timezone.now() + timedelta(days=1)
        expiring_soon = OutstandingToken.objects.filter(
            expires_at__lt=tomorrow,
            expires_at__gt=timezone.now()
        ).count()
        
        # Expired tokens
        expired_tokens = OutstandingToken.objects.filter(
            expires_at__lt=timezone.now()
        ).count()
        
        self.stdout.write(f"Total outstanding tokens: {total_outstanding}")
        self.stdout.write(f"Blacklisted tokens: {total_blacklisted}")
        self.stdout.write(f"Active tokens: {active_tokens}")
        self.stdout.write(f"Expiring in 24h: {expiring_soon}")
        self.stdout.write(f"Expired tokens: {expired_tokens}")

    def cleanup_expired_tokens(self):
        self.stdout.write("\n=== Cleaning up expired tokens ===")
        
        # Remove expired outstanding tokens
        expired_outstanding = OutstandingToken.objects.filter(
            expires_at__lt=timezone.now()
        )
        expired_count = expired_outstanding.count()
        expired_outstanding.delete()
        
        self.stdout.write(f"Removed {expired_count} expired outstanding tokens")
        
        # Remove orphaned blacklisted tokens
        orphaned_blacklisted = BlacklistedToken.objects.filter(
            token__isnull=True
        )
        orphaned_count = orphaned_blacklisted.count()
        orphaned_blacklisted.delete()
        
        self.stdout.write(f"Removed {orphaned_count} orphaned blacklisted tokens")
