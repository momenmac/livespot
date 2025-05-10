from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'posts', views.PostViewSet)
router.register(r'threads', views.ThreadViewSet)
router.register(r'post_threads', views.PostThreadViewSet, basename='post_threads')

urlpatterns = [
    path('', include(router.urls)),
]