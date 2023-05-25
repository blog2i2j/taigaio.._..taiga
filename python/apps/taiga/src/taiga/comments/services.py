# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2023-present Kaleidos INC
from taiga.base.api import Pagination
from taiga.comments import repositories as comment_repositories
from taiga.comments.serializers import CommentDetailSerializer
from taiga.comments.serializers import services as comments_serializers
from taiga.stories.stories.models import Story


async def list_paginated_comments(
    story: Story,
    offset: int,
    limit: int,
    order_by: list[str] = [],
) -> tuple[Pagination, list[CommentDetailSerializer]]:
    comments = await comment_repositories.list_comments(
        filters={"story_id": story.id},
        select_related=["object_content_type", "created_by"],
        order_by=order_by,
        offset=offset,
        limit=limit,
    )
    print(comments[0])
    total_comments = await comment_repositories.get_total_comments(
        filters={"story_id": story.id},
    )

    pagination = Pagination(offset=offset, limit=limit, total=total_comments)
    serialized_comments = [comments_serializers.serialize_comment(c) for c in comments]

    return pagination, serialized_comments
