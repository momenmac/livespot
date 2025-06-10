# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey and OneToOneField has `on_delete` set to the desired behavior
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.db import models


class AccountsAccount(models.Model):
    id = models.BigAutoField(primary_key=True)
    password = models.CharField(max_length=128)
    last_login = models.DateTimeField()
    is_superuser = models.BooleanField()
    email = models.CharField(unique=True, max_length=254)
    first_name = models.CharField(max_length=50)
    last_name = models.CharField(max_length=50)
    profile_picture = models.CharField(max_length=100, blank=True, null=True)
    google_id = models.CharField(max_length=255, blank=True, null=True)
    is_active = models.BooleanField()
    is_admin = models.BooleanField()
    is_verified = models.BooleanField()
    created_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'accounts_account'


class AccountsAccountGroups(models.Model):
    id = models.BigAutoField(primary_key=True)
    account = models.ForeignKey(AccountsAccount, models.DO_NOTHING)
    group = models.ForeignKey('AuthGroup', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'accounts_account_groups'
        unique_together = (('account', 'group'),)


class AccountsAccountUserPermissions(models.Model):
    id = models.BigAutoField(primary_key=True)
    account = models.ForeignKey(AccountsAccount, models.DO_NOTHING)
    permission = models.ForeignKey('AuthPermission', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'accounts_account_user_permissions'
        unique_together = (('account', 'permission'),)


class AccountsUserprofile(models.Model):
    id = models.BigAutoField(primary_key=True)
    username = models.CharField(unique=True, max_length=30)
    bio = models.TextField()
    location = models.CharField(max_length=100)
    website = models.CharField(max_length=200)
    honesty_score = models.IntegerField()
    cover_photo = models.CharField(max_length=100, blank=True, null=True)
    activity_status = models.CharField(max_length=15)
    is_verified = models.BooleanField()
    interests = models.JSONField(blank=True, null=True)
    last_active = models.DateTimeField()
    user = models.OneToOneField(AccountsAccount, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'accounts_userprofile'


class AccountsUserprofileFollowers(models.Model):
    id = models.BigAutoField(primary_key=True)
    from_userprofile = models.ForeignKey(AccountsUserprofile, models.DO_NOTHING)
    to_userprofile = models.ForeignKey(AccountsUserprofile, models.DO_NOTHING, related_name='accountsuserprofilefollowers_to_userprofile_set')

    class Meta:
        managed = False
        db_table = 'accounts_userprofile_followers'
        unique_together = (('from_userprofile', 'to_userprofile'),)


class AccountsUserprofileSavedPosts(models.Model):
    id = models.BigAutoField(primary_key=True)
    userprofile = models.ForeignKey(AccountsUserprofile, models.DO_NOTHING)
    post = models.ForeignKey('PostsPost', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'accounts_userprofile_saved_posts'
        unique_together = (('userprofile', 'post'),)


class AccountsVerificationcode(models.Model):
    id = models.BigAutoField(primary_key=True)
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField()
    expires_at = models.DateTimeField()
    is_used = models.BooleanField()
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'accounts_verificationcode'


class AccountsVerificationrequest(models.Model):
    id = models.BigAutoField(primary_key=True)
    reason = models.TextField()
    status = models.CharField(max_length=10)
    admin_notes = models.TextField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    reviewed_by = models.ForeignKey(AccountsAccount, models.DO_NOTHING, blank=True, null=True)
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING, related_name='accountsverificationrequest_user_set')

    class Meta:
        managed = False
        db_table = 'accounts_verificationrequest'


class AuthGroup(models.Model):
    name = models.CharField(unique=True, max_length=150)

    class Meta:
        managed = False
        db_table = 'auth_group'


class AuthGroupPermissions(models.Model):
    id = models.BigAutoField(primary_key=True)
    group = models.ForeignKey(AuthGroup, models.DO_NOTHING)
    permission = models.ForeignKey('AuthPermission', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'auth_group_permissions'
        unique_together = (('group', 'permission'),)


class AuthPermission(models.Model):
    name = models.CharField(max_length=255)
    content_type = models.ForeignKey('DjangoContentType', models.DO_NOTHING)
    codename = models.CharField(max_length=100)

    class Meta:
        managed = False
        db_table = 'auth_permission'
        unique_together = (('content_type', 'codename'),)


class DjangoAdminLog(models.Model):
    action_time = models.DateTimeField()
    object_id = models.TextField(blank=True, null=True)
    object_repr = models.CharField(max_length=200)
    action_flag = models.SmallIntegerField()
    change_message = models.TextField()
    content_type = models.ForeignKey('DjangoContentType', models.DO_NOTHING, blank=True, null=True)
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'django_admin_log'


class DjangoContentType(models.Model):
    app_label = models.CharField(max_length=100)
    model = models.CharField(max_length=100)

    class Meta:
        managed = False
        db_table = 'django_content_type'
        unique_together = (('app_label', 'model'),)


class DjangoMigrations(models.Model):
    id = models.BigAutoField(primary_key=True)
    app = models.CharField(max_length=255)
    name = models.CharField(max_length=255)
    applied = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'django_migrations'


class EventConfirmations(models.Model):
    id = models.UUIDField(primary_key=True)
    event_id = models.CharField(max_length=255)
    is_still_there = models.BooleanField()
    response_message = models.TextField()
    notification_id = models.UUIDField(blank=True, null=True)
    confirmation_request_sent = models.BooleanField()
    response_received = models.BooleanField()
    requested_at = models.DateTimeField()
    responded_at = models.DateTimeField(blank=True, null=True)
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'event_confirmations'
        unique_together = (('event_id', 'user', 'requested_at'),)


class FcmTokens(models.Model):
    id = models.BigAutoField(primary_key=True)
    token = models.TextField()
    device_platform = models.CharField(max_length=20)
    is_active = models.BooleanField()
    created_at = models.DateTimeField()
    last_used = models.DateTimeField()
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'fcm_tokens'
        unique_together = (('user', 'token'),)


class FriendRequests(models.Model):
    id = models.UUIDField(primary_key=True)
    status = models.CharField(max_length=20)
    message = models.TextField()
    notification_sent = models.BooleanField()
    notification_id = models.UUIDField(blank=True, null=True)
    created_at = models.DateTimeField()
    responded_at = models.DateTimeField(blank=True, null=True)
    from_user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)
    to_user = models.ForeignKey(AccountsAccount, models.DO_NOTHING, related_name='friendrequests_to_user_set')

    class Meta:
        managed = False
        db_table = 'friend_requests'
        unique_together = (('from_user', 'to_user'),)


class MediaApiMediafile(models.Model):
    id = models.UUIDField(primary_key=True)
    file = models.CharField(max_length=100)
    content_type = models.CharField(max_length=20)
    original_filename = models.CharField(max_length=255)
    file_size = models.IntegerField()
    firebase_url = models.CharField(max_length=500, blank=True, null=True)
    uploaded_at = models.DateTimeField()
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)
    thumbnail_url = models.CharField(max_length=500, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'media_api_mediafile'


class NotificationHistory(models.Model):
    id = models.UUIDField(primary_key=True)
    notification_type = models.CharField(max_length=50)
    title = models.CharField(max_length=255)
    body = models.TextField()
    data = models.JSONField()
    sent = models.BooleanField()
    delivered = models.BooleanField()
    read = models.BooleanField()
    processed = models.BooleanField()
    sent_at = models.DateTimeField(blank=True, null=True)
    delivered_at = models.DateTimeField(blank=True, null=True)
    read_at = models.DateTimeField(blank=True, null=True)
    processed_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField()
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'notification_history'


class NotificationQueue(models.Model):
    id = models.UUIDField(primary_key=True)
    notification_type = models.CharField(max_length=50)
    title = models.CharField(max_length=255)
    body = models.TextField()
    data = models.JSONField()
    priority = models.CharField(max_length=10)
    status = models.CharField(max_length=20)
    scheduled_for = models.DateTimeField()
    max_retries = models.IntegerField()
    retry_count = models.IntegerField()
    processing_started_at = models.DateTimeField(blank=True, null=True)
    processed_at = models.DateTimeField(blank=True, null=True)
    error_message = models.TextField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'notification_queue'


class NotificationSettings(models.Model):
    id = models.BigAutoField(primary_key=True)
    friend_requests = models.BooleanField()
    events = models.BooleanField()
    reminders = models.BooleanField()
    nearby_events = models.BooleanField()
    system_notifications = models.BooleanField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    user = models.OneToOneField(AccountsAccount, models.DO_NOTHING)
    follow_notifications = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'notification_settings'


class NotificationTemplates(models.Model):
    id = models.BigAutoField(primary_key=True)
    name = models.CharField(unique=True, max_length=100)
    notification_type = models.CharField(max_length=50)
    title_template = models.CharField(max_length=255)
    body_template = models.TextField()
    data_template = models.JSONField()
    available_variables = models.JSONField()
    description = models.TextField()
    is_active = models.BooleanField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'notification_templates'


class PostsCategoryinteraction(models.Model):
    id = models.BigAutoField(primary_key=True)
    category = models.CharField(max_length=20)
    interaction_type = models.CharField(max_length=20)
    created_at = models.DateTimeField()
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)
    count = models.IntegerField()
    last_updated = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'posts_categoryinteraction'
        unique_together = (('user', 'category', 'interaction_type'),)


class PostsEventstatusvote(models.Model):
    id = models.BigAutoField(primary_key=True)
    voted_ended = models.BooleanField()
    created_at = models.DateTimeField()
    post = models.ForeignKey('PostsPost', models.DO_NOTHING)
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'posts_eventstatusvote'
        unique_together = (('user', 'post'),)


class PostsPost(models.Model):
    id = models.BigAutoField(primary_key=True)
    title = models.CharField(max_length=100)
    content = models.TextField()
    media_urls = models.JSONField()
    category = models.CharField(max_length=20)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField(blank=True, null=True)
    upvotes = models.IntegerField()
    downvotes = models.IntegerField()
    honesty_score = models.IntegerField()
    status = models.CharField(max_length=20)
    is_verified_location = models.BooleanField()
    taken_within_app = models.BooleanField()
    tags = models.JSONField()
    author = models.ForeignKey(AccountsAccount, models.DO_NOTHING)
    location = models.ForeignKey('PostsPostcoordinates', models.DO_NOTHING, blank=True, null=True)
    is_anonymous = models.BooleanField()
    related_post = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'posts_post'


class PostsPostcoordinates(models.Model):
    id = models.BigAutoField(primary_key=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    address = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'posts_postcoordinates'


class PostsPostvote(models.Model):
    id = models.BigAutoField(primary_key=True)
    is_upvote = models.BooleanField()
    created_at = models.DateTimeField()
    post = models.ForeignKey(PostsPost, models.DO_NOTHING)
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'posts_postvote'
        unique_together = (('user', 'post'),)


class SpatialRefSys(models.Model):
    srid = models.IntegerField(primary_key=True)
    auth_name = models.CharField(max_length=256, blank=True, null=True)
    auth_srid = models.IntegerField(blank=True, null=True)
    srtext = models.CharField(max_length=2048, blank=True, null=True)
    proj4text = models.CharField(max_length=2048, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'spatial_ref_sys'


class TokenBlacklistBlacklistedtoken(models.Model):
    id = models.BigAutoField(primary_key=True)
    blacklisted_at = models.DateTimeField()
    token = models.OneToOneField('TokenBlacklistOutstandingtoken', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'token_blacklist_blacklistedtoken'


class TokenBlacklistOutstandingtoken(models.Model):
    id = models.BigAutoField(primary_key=True)
    token = models.TextField()
    created_at = models.DateTimeField(blank=True, null=True)
    expires_at = models.DateTimeField()
    user = models.ForeignKey(AccountsAccount, models.DO_NOTHING, blank=True, null=True)
    jti = models.CharField(unique=True, max_length=255)

    class Meta:
        managed = False
        db_table = 'token_blacklist_outstandingtoken'
