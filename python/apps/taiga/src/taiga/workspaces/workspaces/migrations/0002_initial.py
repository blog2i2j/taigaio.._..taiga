# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2023-present Kaleidos INC

# Generated by Django 4.1.3 on 2023-06-12 18:57

from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("workspaces", "0001_initial"),
        ("workspaces_memberships", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="workspace",
            name="members",
            field=models.ManyToManyField(
                related_name="workspaces",
                through="workspaces_memberships.WorkspaceMembership",
                to=settings.AUTH_USER_MODEL,
                verbose_name="members",
            ),
        ),
    ]
