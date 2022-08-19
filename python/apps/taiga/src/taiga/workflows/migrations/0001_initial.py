# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

# Generated by Django 4.1 on 2022-08-19 08:41

import django.db.models.deletion
import taiga.base.db.models
import taiga.base.utils.datetime
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ("projects", "0002_alter_projecttemplate_options_and_more"),
    ]

    operations = [
        migrations.CreateModel(
            name="Workflow",
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
                ("name", models.CharField(max_length=250, verbose_name="name")),
                ("slug", models.CharField(max_length=250, verbose_name="slug")),
                (
                    "order",
                    models.BigIntegerField(default=taiga.base.utils.datetime.timestamp_mics, verbose_name="order"),
                ),
                (
                    "project",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="workflows",
                        to="projects.project",
                        verbose_name="project",
                    ),
                ),
            ],
            options={
                "verbose_name": "workflow",
                "verbose_name_plural": "workflows",
                "ordering": ["order", "name"],
                "unique_together": {("slug", "project")},
            },
        ),
        migrations.CreateModel(
            name="WorkflowStatus",
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
                ("name", models.CharField(max_length=250, verbose_name="name")),
                ("slug", models.CharField(max_length=250, verbose_name="slug")),
                ("color", models.IntegerField(default=1, verbose_name="color")),
                (
                    "order",
                    models.BigIntegerField(default=taiga.base.utils.datetime.timestamp_mics, verbose_name="order"),
                ),
                (
                    "workflow",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="statuses",
                        to="workflows.workflow",
                        verbose_name="workflow",
                    ),
                ),
            ],
            options={
                "verbose_name": "workflow status",
                "verbose_name_plural": "workflow statuses",
                "ordering": ["order", "name"],
                "unique_together": {("slug", "workflow")},
            },
        ),
    ]
