# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2023-present Kaleidos INC
from typing import Any

from fastapi import Query
from humps.main import decamelize
from pydantic import validator
from taiga.base.serializers import BaseModel

ALLOWED_ORDER_BY_FIELDS = [
    "created_at",
    "-created_at",
    "text",
    "-text",
]

DEFAULT_ORDER_BY_FIELDS = [
    "-created_at",
]


class OrderByParams(BaseModel):
    order: list[str] = Query(None)

    def __init__(self, order: list[str] = Query(DEFAULT_ORDER_BY_FIELDS)):
        self.order = self.check_is_valid_field(order)

    def __setattr__(self, name: str, value: Any) -> None:
        self.__dict__[name] = value

    @validator("order")
    def check_is_valid_field(cls, order_by_params: list[str]) -> list[str]:
        order_by_list = []
        for order in order_by_params:
            order_by_field = decamelize(order)
            if order_by_field in ALLOWED_ORDER_BY_FIELDS:
                order_by_list.append(order_by_field)

        return order_by_list or DEFAULT_ORDER_BY_FIELDS
