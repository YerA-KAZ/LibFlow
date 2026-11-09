"""Provision the first administrator with access to the local database."""
import argparse
import getpass

from backend.access import add_account, migrate_access, normalized_email
from backend.app import connect


def provision(email, password):
    if len(password) < 16:
        raise ValueError('Use a password of at least 16 characters.')
    with connect() as db:
        migrate_access(db)
        db.execute('SELECT pg_advisory_xact_lock(1280199750)')
        if db.execute("SELECT 1 FROM accounts WHERE role = 'admin' LIMIT 1").fetchone():
            raise ValueError('An administrator already exists. Manage roles in the application.')
        account = add_account(db, normalized_email(email), 'LibFlow Admin', password, 'admin')
        if account is None:
            raise ValueError('An account already uses this email.')
    return account


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('email')
    args = parser.parse_args()
    password = getpass.getpass('New administrator password: ')
    if getpass.getpass('Repeat password: ') != password:
        parser.error('Passwords do not match.')
    try:
        account = provision(args.email, password)
    except ValueError as error:
        parser.error(str(error))
    print(f"Administrator created: {account['email']}")
