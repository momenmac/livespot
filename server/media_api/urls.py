from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'files', views.MediaFileViewSet, basename='mediafile')

urlpatterns = [
    path('', include(router.urls)),
    path('upload/', views.upload_media, name='upload_media'),
    path('get/<uuid:file_id>/', views.get_media, name='get_media'),
    path('delete/<uuid:file_id>/', views.delete_media, name='delete_media'),
    path('list/', views.list_user_media, name='list_user_media'),
]