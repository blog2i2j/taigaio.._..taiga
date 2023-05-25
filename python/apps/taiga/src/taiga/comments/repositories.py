# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2023-present Kaleidos INC

from typing import Literal, TypedDict
from uuid import UUID

from asgiref.sync import sync_to_async

from taiga.base.db.models import QuerySet
from taiga.comments.models import Comment

##########################################################
# filters and querysets
##########################################################


DEFAULT_QUERYSET = Comment.objects.all()


class CommentsFilters(TypedDict, total=False):
    id: UUID
    workspace_id: UUID
    user_id: UUID
    story_id: str


def _apply_filters_to_queryset(
    qs: QuerySet[Comment],
    filters: CommentsFilters = {},
) -> QuerySet[Comment]:
    filter_data = dict(filters.copy())

    if "story_id" in filters:
        filter_data["story__id"] = filter_data.pop("story_id")

    return qs.filter(**filter_data)


CommentSelectRelated = list[
    Literal[
        "user",
        "workspace",
    ]
]


def _apply_select_related_to_queryset(
    qs: QuerySet[Comment],
    select_related: CommentSelectRelated,
) -> QuerySet[Comment]:
    return qs.select_related(*select_related)


CommentOrderBy = list[
    Literal[
        "created_at",
        "-created_at",
    ]
]


def _apply_order_by_to_queryset(
    qs: QuerySet[Comment],
    order_by: CommentOrderBy,
) -> QuerySet[Comment]:
    order_by_data = []

    print(f"repo ============================>>>> {order_by}")

    for key in order_by:
        if key == "newest":
            order_by_data.append("-created_at")
        elif key == "oldest":
            order_by_data.append("created_at")
        else:
            order_by_data.append(key)
    return qs.order_by(*order_by_data)


##########################################################
# list project memberships
##########################################################


@sync_to_async
def list_comments(
    filters: CommentsFilters = {},
    select_related: CommentSelectRelated = [],
    order_by: list[CommentOrderBy] = ["created_at"],
    offset: int | None = None,
    limit: int | None = None,
) -> list[Comment]:
    qs = _apply_filters_to_queryset(qs=DEFAULT_QUERYSET, filters=filters)
    qs = _apply_select_related_to_queryset(qs=qs, select_related=select_related)
    qs = _apply_order_by_to_queryset(order_by=order_by, qs=qs)

    if limit is not None and offset is not None:
        limit += offset
    print(qs.query)

    return list(qs[offset:limit])


##########################################################
# misc
##########################################################


@sync_to_async
def get_total_comments(filters: CommentsFilters = {}) -> int:
    qs = _apply_filters_to_queryset(qs=DEFAULT_QUERYSET, filters=filters)
    return qs.count()
