"""
Supabase Storage helper for preserving uploaded Excel files.

Uses the same service-role admin client already established in
app/core/supabase_admin.py (the only place that key is used) — storage
uploads via the service role bypass bucket-level RLS the same way DB writes
do, which is appropriate since only admins can reach the upload endpoint
this is called from.

If the upload fails for any reason (bucket not yet created, network issue,
Storage not configured for this project), we fall back to a local
placeholder rather than failing the whole import — the import itself (the
data that matters) should not be blocked by an optional file-preservation
step. The failure is logged so it's visible, not silent.
"""
import uuid

from loguru import logger

from app.config import get_settings
from app.core.supabase_admin import get_admin_client

settings = get_settings()


def upload_import_file(file_name: str, file_bytes: bytes) -> str:
    """
    Uploads the original file to the configured imports bucket and returns
    a URL to it. Storage paths are namespaced by a random prefix so two
    uploads of a same-named file never collide.
    """
    bucket = settings.SUPABASE_STORAGE_BUCKET_IMPORTS
    storage_path = f"{uuid.uuid4()}/{file_name}"

    try:
        client = get_admin_client()
        client.storage.from_(bucket).upload(
            storage_path,
            file_bytes,
            file_options={"content-type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"},
        )
        # Signed URL valid for a long time (this is an internal admin-only
        # file, not a public download link) — 7 days, renewed by re-signing
        # if ever needed; simplest option that doesn't require making the
        # bucket public.
        signed = client.storage.from_(bucket).create_signed_url(storage_path, 60 * 60 * 24 * 7)
        url = signed.get("signedURL") or signed.get("signedUrl")
        if url:
            return url
        # Some supabase-py versions return the path differently; fall back
        # to a bucket-relative reference if the signed URL shape changes.
        return f"{bucket}/{storage_path}"
    except Exception as exc:
        logger.warning(f"Could not upload '{file_name}' to Supabase Storage bucket '{bucket}': {exc}")
        return f"uploaded:{file_name}"
