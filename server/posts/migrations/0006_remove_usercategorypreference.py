from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('posts', '0005_remove_unused_tables'),
    ]

    operations = [
        # Remove unused UserCategoryPreference table
        migrations.RunSQL(
            sql="DROP TABLE IF EXISTS posts_usercategorypreference CASCADE;",
            reverse_sql="-- No reverse operation needed"
        ),
    ]
