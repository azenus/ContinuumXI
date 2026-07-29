#!/usr/bin/python3
"""Interactive tool to list items for sale on the Auction House.

Prompts for an item id, a single/stack listing, a price, and how many copies
to post, then inserts the matching rows into the `auction_house` table as an
active (unsold) listing. The seller is a fake system account so the listings
behave exactly like player-posted ones.

Run from the `tools/` directory (it reads ../settings/network.lua for the
database credentials, the same way give_items.py / price_checker.py do).
"""

import os
import re
import time

try:
    import mariadb
except ImportError:
    raise SystemExit(
        "The 'mariadb' Python module is required. Install it with:\n"
        "    python -m pip install mariadb"
    )

# Fake seller used for system-listed items. seller charid 0 has no inventory,
# so nothing is removed from a real player when the listing is created.
SELLER_ID = 0
DEFAULT_SELLER_NAME = "AH-System"  # auction_house.seller_name is varchar(15)

# auction_house.price is an unsigned 32-bit int.
MAX_PRICE = 4294967295


def load_credentials():
    """Parse SQL_* credentials out of settings/network.lua.

    Returns a dict with host, port, login, password and database keys.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    filename = os.path.join(script_dir, "..", "settings", "network.lua")
    print("Loading {}".format(os.path.normpath(filename)))

    credentials = {}
    with open(filename) as f:
        for line in f:
            match = re.findall(
                r"(SQL_\w+)\s*=\s*(?:[\'\"](.*?)[\'\"]|([^\'\s,]+)),", line
            )
            if match:
                credentials[match[0][0]] = match[0][2] if match[0][2] else match[0][1]

    return {
        "host": credentials["SQL_HOST"],
        "port": int(credentials["SQL_PORT"]),
        "login": credentials["SQL_LOGIN"],
        "password": credentials["SQL_PASSWORD"],
        "database": credentials["SQL_DATABASE"],
    }


def connect():
    """Open a MariaDB connection using the parsed network.lua credentials."""
    creds = load_credentials()
    db = mariadb.connect(
        host=creds["host"],
        user=creds["login"],
        passwd=creds["password"],
        db=creds["database"],
        port=creds["port"],
    )
    print("Connected to database: " + creds["database"])
    return db


def prompt_int(prompt, minimum=None, maximum=None):
    """Prompt repeatedly until the user enters a valid integer in range.

    Returns the integer, or None if the user enters a blank line to cancel.
    """
    while True:
        raw = input(prompt).strip()
        if raw == "":
            return None
        try:
            value = int(raw)
        except ValueError:
            print("  Please enter a whole number (or blank to cancel).")
            continue
        if minimum is not None and value < minimum:
            print("  Value must be at least {}.".format(minimum))
            continue
        if maximum is not None and value > maximum:
            print("  Value must be at most {}.".format(maximum))
            continue
        return value


def prompt_yes_no(prompt, default=True):
    """Prompt for a yes/no answer, returning a bool. Blank uses the default."""
    suffix = " [Y/n] " if default else " [y/N] "
    while True:
        raw = input(prompt + suffix).strip().lower()
        if raw == "":
            return default
        if raw in ("y", "yes"):
            return True
        if raw in ("n", "no"):
            return False
        print("  Please answer y or n.")


def lookup_item(cur, itemid):
    """Return (name, stack_size, ah_category) for an itemid, or None if absent."""
    cur.execute(
        "SELECT name, stackSize, aH FROM item_basic WHERE itemid = %s LIMIT 1",
        (itemid,),
    )
    row = cur.fetchone()
    if row is None:
        return None
    return row[0], int(row[1]), int(row[2])


def insert_listing(db, cur, itemid, stack, price, copies, seller_name):
    """Insert `copies` identical AH listings and register the item as listable.

    stack is 0 for a single item or 1 for a full stack.
    """
    now = int(time.time())
    rows = [
        (itemid, stack, SELLER_ID, seller_name, now, price)
        for _ in range(copies)
    ]
    cur.executemany(
        "INSERT INTO auction_house "
        "(itemid, stack, seller, seller_name, date, price, buyer_name, sale, sell_date) "
        "VALUES (%s, %s, %s, %s, %s, %s, NULL, 0, 0)",
        rows,
    )
    # Mirror add_imperial_pieces_to_ah.sql: make sure the item is registered as
    # AH-listable so it shows up under its category for buyers.
    cur.execute(
        "INSERT IGNORE INTO auction_house_items (itemid) VALUES (%s)",
        (itemid,),
    )
    db.commit()


def list_one_item(db, cur):
    """Walk the user through listing a single item. Returns True on success."""
    itemid = prompt_int("\nEnter item id (blank to cancel): ", minimum=1, maximum=65535)
    if itemid is None:
        return False

    item = lookup_item(cur, itemid)
    if item is None:
        print("  No item with id {} exists in item_basic.".format(itemid))
        return False

    name, stack_size, ah_category = item
    print("  Item {}: {} (stack size {}, AH category {})".format(
        itemid, name, stack_size, ah_category))

    if ah_category == 99:
        print("  NOTE: this item's AH category is 99 (not a normal AH item).")
        print("        The listing will still work, but players cannot post it themselves.")

    # Single vs stack.
    as_stack = False
    if stack_size > 1:
        as_stack = prompt_yes_no(
            "  List as a full stack of {} (instead of a single item)?".format(stack_size),
            default=False,
        )
    else:
        print("  This item does not stack; listing as a single item.")

    stack_flag = 1 if as_stack else 0
    unit = "stack of {}".format(stack_size) if as_stack else "single"

    price = prompt_int(
        "  Enter price in gil for one {} (blank to cancel): ".format(unit),
        minimum=1,
        maximum=MAX_PRICE,
    )
    if price is None:
        return False

    copies = prompt_int(
        "  How many of these listings to post? [default 1]: ",
        minimum=1,
        maximum=10000,
    )
    if copies is None:
        copies = 1

    seller_name = input(
        "  Seller name shown in AH history [default {}]: ".format(DEFAULT_SELLER_NAME)
    ).strip()
    if seller_name == "":
        seller_name = DEFAULT_SELLER_NAME
    seller_name = seller_name[:15]  # column is varchar(15)

    print("\n  About to post:")
    print("    {} x  {} ({}) @ {:,} gil each, seller '{}'".format(
        copies, name, unit, price, seller_name))
    if not prompt_yes_no("  Confirm?", default=True):
        print("  Cancelled.")
        return False

    insert_listing(db, cur, itemid, stack_flag, price, copies, seller_name)
    print("  Posted {} listing(s) for {}.".format(copies, name))
    return True


def main():
    print("=== Auction House item lister ===")
    try:
        db = connect()
    except mariadb.Error as err:
        raise SystemExit("Could not connect to the database: {}".format(err))

    cur = db.cursor()
    try:
        while True:
            list_one_item(db, cur)
            if not prompt_yes_no("\nList another item?", default=True):
                break
    finally:
        cur.close()
        db.close()
        print("Closed database connection.")


if __name__ == "__main__":
    main()
