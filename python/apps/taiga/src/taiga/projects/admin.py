# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

from typing import Any

from taiga.base.db import admin
from taiga.base.db.admin.forms import ModelChoiceField
from taiga.base.db.admin.http import HttpRequest
from taiga.base.db.models import ForeignKey
from taiga.invitations.models import ProjectInvitation
from taiga.projects.models import Project, ProjectMembership, ProjectRole, ProjectTemplate


class ProjectRoleInline(admin.TabularInline[ProjectRole, Project]):
    model = ProjectRole
    extra = 0


class ProjectMembershipInline(admin.TabularInline[ProjectMembership, Project]):
    model = ProjectMembership
    extra = 0

    def get_formset(self, request: HttpRequest, obj: Project | None = None, **kwargs: Any) -> Any:
        self.parent_obj = obj  # Use in formfield_for_foreignkey()
        return super().get_formset(request, obj, **kwargs)

    def formfield_for_foreignkey(
        self, db_field: ForeignKey[Any, Any], request: HttpRequest, **kwargs: Any
    ) -> ModelChoiceField:
        if db_field.name in ["role"]:
            kwargs["queryset"] = db_field.related_model.objects.filter(project=self.parent_obj)

        return super().formfield_for_foreignkey(db_field, request, **kwargs)


class ProjectInvitationInline(admin.TabularInline[ProjectInvitation, Project]):
    model = ProjectInvitation
    extra = 0

    def get_formset(self, request: HttpRequest, obj: Project | None = None, **kwargs: Any) -> Any:
        self.parent_obj = obj  # Use in formfield_for_foreignkey()
        return super().get_formset(request, obj, **kwargs)

    def formfield_for_foreignkey(
        self, db_field: ForeignKey[Any, Any], request: HttpRequest, **kwargs: Any
    ) -> ModelChoiceField:
        if db_field.name in ["role"]:
            kwargs["queryset"] = db_field.related_model.objects.filter(project=self.parent_obj)

        return super().formfield_for_foreignkey(db_field, request, **kwargs)


@admin.register(Project)
class ProjectAdmin(admin.ModelAdmin[Project]):
    fieldsets = (
        (None, {"fields": ("id", "workspace", "name", "slug", "owner")}),
        (
            "Extra info",
            {"classes": ("collapse",), "fields": ("color", "logo", ("created_at", "modified_at"))},
        ),
        ("Permissions", {"fields": ("workspace_member_permissions", "public_permissions", "anon_permissions")}),
    )
    readonly_fields = ("id", "created_at", "modified_at")
    list_display = ["name", "slug", "workspace", "owner", "is_public", "is_anon"]
    list_filter = ("workspace", "owner")
    search_fields = [
        "id",
        "name",
        "slug",
        "workspace__name",
        "workspace__slug",
        "owner__username",
        "owner__email",
        "owner__full_name",
    ]
    ordering = ("name",)
    inlines = [ProjectRoleInline, ProjectMembershipInline, ProjectInvitationInline]

    @admin.display(description="allow public users", boolean=True)
    def is_public(self, obj: Project) -> bool:
        return obj.is_public

    @admin.display(description="allow annonymous users", boolean=True)
    def is_anon(self, obj: Project) -> bool:
        return obj.is_anon


@admin.register(ProjectTemplate)
class ProjectTemplateAdmin(admin.ModelAdmin[ProjectTemplate]):
    ...
