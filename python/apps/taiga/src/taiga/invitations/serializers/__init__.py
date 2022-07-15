# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL
from typing import Any

from pydantic import EmailStr, validator
from taiga.base.serializers import BaseModel
from taiga.projects.serializers.related import ProjectSmallSummarySerializer
from taiga.roles.serializers import BaseProjectRoleSerializer
from taiga.users.serializers import UserSerializer


class PublicProjectInvitationSerializer(BaseModel):
    email: EmailStr
    existing_user: bool
    project: ProjectSmallSummarySerializer

    class Config:
        orm_mode = True


class ProjectInvitationSerializer(BaseModel):
    user: UserSerializer | None
    role: BaseProjectRoleSerializer
    email: EmailStr

    class Config:
        orm_mode = True


class PrivateEmailProjectInvitationSerializer(BaseModel):
    user: UserSerializer | None
    role: BaseProjectRoleSerializer
    email: EmailStr | None

    class Config:
        orm_mode = True

    @validator("email")
    def avoid_to_publish_email_if_user(cls, email: str, values: dict[str, Any]) -> str | None:
        user = values.get("user")
        if user:
            return None
        else:
            return email


class CreateProjectInvitationsSerializer(BaseModel):
    invitations: list[PrivateEmailProjectInvitationSerializer]
    already_members: int

    class Config:
        orm_mode = True
