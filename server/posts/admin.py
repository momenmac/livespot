from django.contrib import admin
from .models import Post, Thread, PostCoordinates, PostVote

@admin.register(PostCoordinates)
class PostCoordinatesAdmin(admin.ModelAdmin):
    list_display = ('id', 'latitude', 'longitude', 'address')
    search_fields = ('address',)

class PostInline(admin.TabularInline):
    model = Post
    extra = 0
    fields = ('title', 'author', 'category', 'status', 'created_at')
    readonly_fields = ('created_at',)

@admin.register(Thread)
class ThreadAdmin(admin.ModelAdmin):
    list_display = ('id', 'title', 'category', 'created_at', 'updated_at', 'honesty_score')
    list_filter = ('category', 'created_at')
    search_fields = ('title', 'tags')
    inlines = [PostInline]

class PostVoteInline(admin.TabularInline):
    model = PostVote
    extra = 0
    fields = ('user', 'is_upvote', 'created_at')
    readonly_fields = ('created_at',)

@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ('id', 'title', 'author', 'category', 'status', 'created_at', 'upvotes', 'downvotes', 'honesty_score')
    list_filter = ('category', 'status', 'created_at', 'is_verified_location')
    search_fields = ('title', 'content', 'tags')
    readonly_fields = ('created_at', 'updated_at', 'upvotes', 'downvotes')
    inlines = [PostVoteInline]

@admin.register(PostVote)
class PostVoteAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'post', 'is_upvote', 'created_at')
    list_filter = ('is_upvote', 'created_at')
    search_fields = ('user__username', 'post__title')
    readonly_fields = ('created_at',)
