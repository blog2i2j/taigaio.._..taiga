# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2023-present Kaleidos INC

from unittest.mock import patch

import pytest
from taiga.comments import services
from tests.utils import factories as f

pytestmark = pytest.mark.django_db


#####################################################
# create_comment
#####################################################


async def test_create_comment():
    project = f.build_project()
    story = f.build_story()
    comment = f.build_comment()

    with (
        patch("taiga.comments.services.comments_repositories", autospec=True) as fake_comments_repositories,
        patch("taiga.comments.services.comments_serializers", autospec=True) as fake_comments_serializers,
    ):
        fake_comments_repositories.create_comment.return_value = comment

        await services.create_comment(
            project=project,
            content_object=story,
            text=comment.text,
            created_by=comment.created_by,
        )

        fake_comments_repositories.create_comment.assert_awaited_once_with(
            content_object=story,
            text=comment.text,
            created_by=comment.created_by,
        )
        fake_comments_serializers.serialize_comment.assert_called_once_with(comment=comment)


#####################################################
# list_comments
#####################################################


async def test_list_comments():
    story = f.build_story(id="")
    comment = f.build_comment()

    filters = {"content_object": story}
    select_related = ["created_by"]
    order_by = ["-created_at"]
    offset = 0
    limit = 100
    total = 1

    with (
        patch("taiga.comments.services.comments_repositories", autospec=True) as fake_comments_repositories,
        patch("taiga.comments.services.comments_serializers", autospec=True) as fake_comments_serializers,
    ):

        fake_comments_repositories.list_comments.return_value = [comment]
        fake_comments_repositories.get_total_comments.return_value = total
        pagination, comments_list = await services.list_paginated_comments(
            content_object=story, order_by=order_by, offset=offset, limit=limit
        )
        fake_comments_repositories.list_comments.assert_awaited_once_with(
            filters=filters,
            select_related=select_related,
            order_by=order_by,
            offset=offset,
            limit=limit,
        )
        fake_comments_repositories.get_total_comments.assert_awaited_once_with(filters=filters)
        fake_comments_serializers.serialize_comment.assert_called_once_with(comment=comment)
        assert len(comments_list) == 1
        assert pagination.offset == offset
        assert pagination.limit == limit
        assert pagination.total == total
