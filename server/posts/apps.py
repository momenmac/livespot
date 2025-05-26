from django.apps import AppConfig


class PostsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "posts"
    
    def ready(self):
        """
        Register signal handlers when the app is ready.
        """
        import posts.signals  # Import signals to register the handlers
