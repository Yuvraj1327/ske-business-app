"""
Re-authentication (password re-entry) verification for sensitive admin
actions — currently only the "Reset Data" flow.

Deliberately does NOT reimplement password checking or touch any stored
credential: Supabase Auth is the sole owner of credentials (see the
architecture notes in core/security.py), so the only correct way to verify
"is this really the admin's current password" is to attempt the exact same
sign-in Supabase Auth itself would perform for a real login, using the
public anon key (never the service-role key — this must behave exactly
like a normal user login attempt, not an admin override). Success/failure
of that attempt IS the verification.

This creates a new, short-lived Supabase Auth session as a side effect of
verification (Supabase's API has no "check password without a session"
endpoint) — that session is discarded immediately and never stored,
returned to the client, or used for anything.
"""
from supabase import create_client

from app.config import get_settings

settings = get_settings()


def verify_password(email: str, password: str) -> bool:
    """Returns True only if `password` is genuinely the current Supabase
    Auth password for `email`. Never raises for a wrong password — that's
    an expected, non-exceptional outcome here; only genuine
    infrastructure/network failures propagate as exceptions."""
    client = create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)
    try:
        result = client.auth.sign_in_with_password({"email": email, "password": password})
        return result.user is not None
    except Exception:
        # Wrong password, unknown email, rate-limited, etc. — all treated
        # as "not verified" rather than distinguishing the reason, so this
        # endpoint doesn't become an email/account enumeration oracle.
        return False
