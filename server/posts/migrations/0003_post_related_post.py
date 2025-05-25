from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('posts', '0002_postthread'),
    ]

    operations = [
        migrations.AddField(
            model_name='post',
            name='related_post',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='related_posts',
                to='posts.post'
            ),
        ),
    ]
