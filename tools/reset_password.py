#!/usr/bin/env python3
"""Reset a ContinuumXI account password given the account's login name.

The login server (src/login/auth_session.cpp) stores account passwords in the
`accounts` table as bcrypt hashes produced by zach2good/libbcrypt with a work
factor of 12 and the `$2b$` version prefix. The Python `bcrypt` package (already
listed in tools/requirements.txt) generates hashes that the server's
`BCrypt::validatePassword` accepts, so we can safely write a fresh hash here.

Database connection details are read the same way dbtool.py reads them:
    1. defaults from settings/default/*.lua
    2. overridden by settings/*.lua
    3. overridden by XI_NETWORK_SQL_* environment variables

Usage:
    python reset_password.py <login_name>                    # prompt for new password
    python reset_password.py <login_name> --password pw      # set explicitly
    python reset_password.py <login_name> --random           # generate a random one
    python reset_password.py <login_name> --random -y        # no confirmation prompt
    python reset_password.py <login_name> --clear-trust-tokens  # also clear TOTP trust
"""

# Internal Deps
import argparse
import getpass
import os
import secrets
import string
import sys

# server_dir_path resolves to <root> whether this is run from tools/ or elsewhere
tools_dir_path = os.path.normpath(os.path.realpath(os.path.dirname(__file__)))
server_dir_path = os.path.normpath(os.path.realpath(os.path.dirname(tools_dir_path)))

# External Deps (requirements.txt)
try:
    import bcrypt
    import mariadb
    from mariadb.constants import ERR
except Exception as e:
    print("ERROR: Exception occured while importing external dependencies:")
    print(e)
    print(
        "Ensure you've installed the python dependencies "
        "(ex: pip install --upgrade -r requirements.txt)"
    )
    sys.exit(-1)

# bcrypt work factor used by the server (zach2good/libbcrypt default).
BCRYPT_WORK_FACTOR = 12

# The login parser rejects passwords longer than 32 characters
# (loginHelpers::isStringMalformed(password, 32) in auth_session.cpp).
MAX_LOGIN_PASSWORD_LENGTH = 32

# bcrypt only hashes the first 72 bytes of a password.
BCRYPT_MAX_PASSWORD_BYTES = 72


def from_server_path(path):
    """Return an absolute path relative to the server root directory."""
    return os.path.normpath(os.path.join(server_dir_path, path))


def load_network_settings():
    """Read SQL_* values from the lua settings files, mirroring dbtool.py.

    Later files override earlier ones, so settings/network.lua wins over
    settings/default/network.lua. Returns a dict of the raw string values.
    """
    settings = {}

    def load_into_dict(filename):
        if not (os.path.exists(filename) and os.path.isfile(filename)):
            return
        with open(filename) as f:
            for line in f.readlines():
                if not line:
                    break
                if "=" not in line:
                    continue

                line = line.replace("\n", "")
                # split once so the value (which may contain '=') is preserved
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip()

                # ignore commented out entries
                if key.startswith("--"):
                    continue

                # strip off trailing comments
                val = val.rsplit("--")[0].strip()

                # pop off leading quote
                if val.startswith('"') or val.startswith("'"):
                    val = val[1:]

                # pop off trailing comma
                if val.endswith(","):
                    val = val[:-1]

                # pop off trailing quote
                if val.endswith('"') or val.endswith("'"):
                    val = val[:-1]

                settings[key] = val

    load_into_dict(from_server_path("settings/default/network.lua"))
    load_into_dict(from_server_path("settings/network.lua"))
    return settings


def get_connection_params():
    """Resolve DB connection params with env-var overrides (as dbtool.py does)."""
    settings = load_network_settings()

    def resolve(env_key, settings_key):
        value = os.getenv(env_key) or settings.get(settings_key)
        if value is None:
            print(
                f"ERROR: Could not find {settings_key} in settings/network.lua "
                f"or the {env_key} environment variable."
            )
            sys.exit(-1)
        return value

    return {
        "host": resolve("XI_NETWORK_SQL_HOST", "SQL_HOST"),
        "port": int(resolve("XI_NETWORK_SQL_PORT", "SQL_PORT")),
        "user": resolve("XI_NETWORK_SQL_LOGIN", "SQL_LOGIN"),
        "password": resolve("XI_NETWORK_SQL_PASSWORD", "SQL_PASSWORD"),
        "database": resolve("XI_NETWORK_SQL_DATABASE", "SQL_DATABASE"),
    }


def connect(params):
    """Open a MariaDB connection, exiting with a helpful message on failure."""
    try:
        return mariadb.connect(
            host=params["host"],
            port=params["port"],
            user=params["user"],
            passwd=params["password"],
            db=params["database"],
        )
    except mariadb.Error as err:
        if err.errno == ERR.ER_ACCESS_DENIED_ERROR:
            print(
                "ERROR: Incorrect SQL login or password, "
                "update settings/network.lua."
            )
        else:
            print(f"ERROR: Unable to connect to the database: {err}")
        sys.exit(-1)


def generate_random_password(length=12):
    """Generate a random password using letters and digits (login-safe)."""
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def prompt_for_password():
    """Securely prompt for a new password and confirm it."""
    while True:
        password = getpass.getpass("New password: ")
        if not password:
            print("Password cannot be empty.")
            continue
        confirm = getpass.getpass("Confirm new password: ")
        if password != confirm:
            print("Passwords did not match, try again.")
            continue
        return password


def validate_password(password):
    """Warn about lengths the login server / bcrypt cannot fully honour."""
    if len(password) > MAX_LOGIN_PASSWORD_LENGTH:
        print(
            f"WARNING: Password is {len(password)} characters. The login server "
            f"rejects passwords longer than {MAX_LOGIN_PASSWORD_LENGTH} "
            "characters, so the account may be unable to log in."
        )
    if len(password.encode("utf-8")) > BCRYPT_MAX_PASSWORD_BYTES:
        print(
            "WARNING: Only the first 72 bytes of the password are used by bcrypt."
        )


def hash_password(password):
    """Produce a server-compatible bcrypt hash string for the given password."""
    pw_bytes = password.encode("utf-8")[:BCRYPT_MAX_PASSWORD_BYTES]
    salt = bcrypt.gensalt(rounds=BCRYPT_WORK_FACTOR)
    return bcrypt.hashpw(pw_bytes, salt).decode("utf-8")


def clear_trust_tokens(cur, account_id):
    """Delete all 'trust this computer' tokens for the account.

    Mirrors otpHelpers::removeAllTrustTokens; these tokens let a device skip the
    TOTP prompt, so clearing them forces TOTP re-verification on next login. The
    table is created at runtime by the login server and may not exist yet, so a
    missing table is treated as a no-op rather than an error.
    """
    try:
        cur.execute(
            "DELETE FROM accounts_trust_tokens WHERE accid = ?", (account_id,)
        )
        print(f"Cleared {cur.rowcount} TOTP trust token(s).")
    except mariadb.Error as err:
        if err.errno == ERR.ER_NO_SUCH_TABLE:
            print(
                "No accounts_trust_tokens table found; "
                "nothing to clear (skipping)."
            )
        else:
            raise


def reset_password(login_name, new_password, assume_yes, clear_trust):
    """Update the account's password hash, returning True on success."""
    params = get_connection_params()
    conn = connect(params)
    try:
        cur = conn.cursor()

        cur.execute(
            "SELECT id, login FROM accounts WHERE login = ?", (login_name,)
        )
        row = cur.fetchone()
        if row is None:
            print(f"ERROR: No account found with login name '{login_name}'.")
            return False

        account_id, actual_login = row[0], row[1]
        print(f"Found account id {account_id} (login '{actual_login}').")

        if not assume_yes:
            answer = input(
                f"Reset the password for account '{actual_login}'? [y/N]: "
            ).strip().lower()
            if answer not in ("y", "yes"):
                print("Aborted, no changes made.")
                return False

        password_hash = hash_password(new_password)

        # Mirror the server's password-change behaviour: clearing timelastmodify
        # forces the client to re-sync the account on next login.
        cur.execute(
            "UPDATE accounts SET password = ?, timelastmodify = NULL "
            "WHERE id = ?",
            (password_hash, account_id),
        )

        if cur.rowcount < 1:
            conn.rollback()
            print("ERROR: The password was not updated (no rows affected).")
            return False

        if clear_trust:
            clear_trust_tokens(cur, account_id)

        conn.commit()

        print(f"Password reset successfully for account '{actual_login}'.")
        return True
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(
        description="Reset a ContinuumXI account password by login name."
    )
    parser.add_argument("login_name", help="The account login name to reset.")
    parser.add_argument(
        "--password",
        help="The new password. If omitted, you will be prompted securely.",
    )
    parser.add_argument(
        "--random",
        action="store_true",
        help="Generate and display a random password instead of prompting.",
    )
    parser.add_argument(
        "-y",
        "--yes",
        action="store_true",
        help="Skip the confirmation prompt.",
    )
    parser.add_argument(
        "--clear-trust-tokens",
        action="store_true",
        help=(
            "Also clear the account's TOTP 'trust this computer' tokens, "
            "forcing TOTP re-verification on next login (matches the login "
            "server's behaviour on a password change)."
        ),
    )
    args = parser.parse_args()

    if args.random and args.password:
        print("ERROR: Use either --password or --random, not both.")
        sys.exit(-1)

    if args.random:
        new_password = generate_random_password()
        print(f"Generated password: {new_password}")
    elif args.password:
        new_password = args.password
    else:
        new_password = prompt_for_password()

    validate_password(new_password)

    success = reset_password(
        args.login_name, new_password, args.yes, args.clear_trust_tokens
    )
    sys.exit(0 if success else -1)


if __name__ == "__main__":
    main()
