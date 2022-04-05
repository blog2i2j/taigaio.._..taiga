# Generated by Django 3.2.12 on 2022-04-05 13:14

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone
import taiga6.projects.models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('users', '0042_user_date_activation'),
        ('projects', '0078_auto_20220214_1515'),
    ]

    operations = [
        migrations.AlterField(
            model_name='membership',
            name='created_at',
            field=models.DateTimeField(default=django.utils.timezone.now, verbose_name='created at'),
        ),
        migrations.CreateModel(
            name='Invitation',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('email', models.EmailField(max_length=255, verbose_name='email')),
                ('status', models.CharField(choices=[(taiga6.projects.models.InvitationStatus['PENDING'], 'pending'), (taiga6.projects.models.InvitationStatus['ACCEPTED'], 'accepted')], default=taiga6.projects.models.InvitationStatus['PENDING'], max_length=50)),
                ('created_at', models.DateTimeField(default=django.utils.timezone.now, verbose_name='created at')),
                ('invited_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='ihaveinvited+', to=settings.AUTH_USER_MODEL)),
                ('project', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='invitations', to='projects.project')),
                ('role', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='invitations', to='users.role')),
                ('user', models.ForeignKey(blank=True, default=None, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='invitations', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'invitation',
                'verbose_name_plural': 'invitations',
                'ordering': ['project', 'user__full_name', 'user__username', 'user__email', 'email'],
                'unique_together': {('email', 'project')},
            },
        ),
    ]
