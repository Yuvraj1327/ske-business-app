import uuid

from pydantic import BaseModel, ConfigDict


class PermissionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    key: str
    module: str
    description: str | None


class RoleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    description: str | None
    permission_keys: list[str]

    @classmethod
    def from_model(cls, role) -> "RoleResponse":
        return cls(
            id=role.id,
            name=role.name,
            description=role.description,
            permission_keys=sorted(p.key for p in role.permissions),
        )


class RoleCreateRequest(BaseModel):
    name: str
    description: str | None = None


class RolePermissionsUpdateRequest(BaseModel):
    permission_ids: list[uuid.UUID]
