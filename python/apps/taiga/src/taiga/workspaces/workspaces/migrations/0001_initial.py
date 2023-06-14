# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2023-present Kaleidos INC

# Generated by Django 4.1.3 on 2023-06-12 18:57

import django.db.models.deletion
import taiga.base.db.models
import taiga.base.utils.datetime
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="Workspace",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        blank=True,
                        default=taiga.base.db.models.uuid_generator,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "created_at",
                    models.DateTimeField(default=taiga.base.utils.datetime.aware_utcnow, verbose_name="created at"),
                ),
                ("modified_at", models.DateTimeField(auto_now=True, verbose_name="modified at")),
                ("name", models.CharField(max_length=40, verbose_name="name")),
                ("color", models.IntegerField(default=1, verbose_name="color")),
                (
                    "created_by",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.SET_NULL,
                        to=settings.AUTH_USER_MODEL,
                        verbose_name="created by",
                    ),
                ),
            ],
            options={
                "verbose_name": "workspace",
                "verbose_name_plural": "workspaces",
                "ordering": ["name"],
            },
        ),
    ]
