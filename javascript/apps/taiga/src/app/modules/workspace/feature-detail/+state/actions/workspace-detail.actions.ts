/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { createAction, props } from '@ngrx/store';
import { Project, Workspace } from '@taiga/data';

export const fetchWorkspace = createAction(
  '[Workspace] Fetch',
  props<{ slug: Workspace['slug'] }>()
);

export const fetchWorkspaceSuccess = createAction(
  '[Workspace] Fetch Success',
  props<{ workspace: Workspace }>()
);

export const fetchWorkspaceProjectsSuccess = createAction(
  '[Workspace] Fetch Projects Success',
  props<{ projects: Project[]; invitedProjects: Project[] }>()
);

export const resetWorkspace = createAction('[Workspace] Reset workspace');

export const invitationDetailCreateEvent = createAction(
  '[Workspace Detail] new invitation event, fetch invitations',
  props<{
    projectSlug: Project['slug'];
    workspaceSlug: Workspace['slug'];
    role: string;
  }>()
);

export const fetchWorkspaceDetailInvitationsSuccess = createAction(
  '[Workspace Detail API] Fetch workspace detail Invitations success',
  props<{
    projectSlug: Project['slug'];
    invitations: Project[];
    project: Project[];
    role: string;
  }>()
);

export const invitationDetailRevokedEvent = createAction(
  '[Workspace Detail] revoked invitation event, update workspace',
  props<{ projectSlug: Project['slug'] }>()
);
