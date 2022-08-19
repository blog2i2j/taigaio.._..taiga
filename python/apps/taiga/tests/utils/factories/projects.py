# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

from asgiref.sync import sync_to_async
from taiga.projects import repositories as projects_repositories
from taiga.projects.models import ProjectTemplate
from tests.utils import factories as f
from tests.utils.images import valid_image_f

from .base import Factory, factory


class ProjectFactory(Factory):
    name = factory.Sequence(lambda n: f"Project {n}")
    slug = factory.Sequence(lambda n: f"project-{n}")
    description = factory.Sequence(lambda n: f"Description {n}")
    owner = factory.SubFactory("tests.utils.factories.UserFactory")
    workspace = factory.SubFactory("tests.utils.factories.WorkspaceFactory")
    logo = valid_image_f

    class Meta:
        model = "projects.Project"


@sync_to_async
def create_simple_project(**kwargs):
    return ProjectFactory.create(**kwargs)


@sync_to_async
def create_project(**kwargs):
    """Create project and its dependencies"""
    defaults = {}
    defaults.update(kwargs)
    workspace = defaults.pop("workspace", None) or f.WorkspaceFactory.create(**defaults)
    defaults["workspace"] = workspace
    defaults["owner"] = defaults.pop("owner", None) or workspace.owner

    project = ProjectFactory.create(**defaults)
    template = ProjectTemplate.objects.first()
    projects_repositories.apply_template_to_project_sync(project=project, template=template)

    admin_role = project.roles.get(is_admin=True)
    f.ProjectMembershipFactory.create(user=project.owner, project=project, role=admin_role)

    return project


def build_project(**kwargs):
    return ProjectFactory.build(**kwargs)
