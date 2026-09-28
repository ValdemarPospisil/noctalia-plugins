#!/usr/bin/env python3
"""Fetch unread Gmail messages for every Google account in GNOME Online Accounts.

Usage:
  mail-check.py fetch '<json config>'
      config: {"defaultQuery": str, "accountQueries": {email: str}, "maxMessages": int}
      prints {"accounts": [{"email", "count", "messages": [...], "error"}]}
  mail-check.py mark-read <email> <uid>
  mail-check.py mark-all-read <email> <gmail query>
"""
import email.header
import email.utils
import imaplib
import json
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import gi

gi.require_version("Goa", "1.0")
from gi.repository import Goa  # noqa: E402


def google_accounts():
    for obj in Goa.Client.new_sync(None).get_accounts():
        account = obj.get_account()
        mail = obj.get_mail()
        if account.props.provider_type != "google" or mail is None or account.props.mail_disabled:
            continue
        yield obj, mail


def connect(obj, mail):
    token, _ = obj.get_oauth2_based().call_get_access_token_sync(None)
    user = mail.props.imap_user_name
    conn = imaplib.IMAP4_SSL(mail.props.imap_host, timeout=15)
    conn.authenticate("XOAUTH2", lambda _: f"user={user}\x01auth=Bearer {token}\x01\x01".encode())
    return conn


def decode(value):
    if not value:
        return ""
    return str(email.header.make_header(email.header.decode_header(value))).replace("\r\n", " ").replace("\n", " ").strip()


def parse_message(meta, header_bytes, address):
    uid = re.search(rb"UID (\d+)", meta)
    thrid = re.search(rb"X-GM-THRID (\d+)", meta)
    msgid = re.search(rb"X-GM-MSGID (\d+)", meta)
    date = imaplib.Internaldate2tuple(meta)
    headers = email.message_from_bytes(header_bytes)
    name, sender = email.utils.parseaddr(decode(headers.get("From")))
    thread_hex = format(int(thrid.group(1)), "x") if thrid else ""
    return {
        "uid": int(uid.group(1)) if uid else 0,
        "id": msgid.group(1).decode() if msgid else "",
        "from": name or sender,
        "fromAddress": sender,
        "subject": decode(headers.get("Subject")) or "(bez předmětu)",
        "date": int(time.mktime(date)) if date else 0,
        "url": f"https://mail.google.com/mail/u/{address}/#all/{thread_hex}" if thread_hex else f"https://mail.google.com/mail/u/{address}/",
    }


def search(conn, query):
    _, data = conn.uid("SEARCH", "X-GM-RAW", '"' + query.replace('"', '\\"') + '"')
    return data[0].split()


def fetch_account(obj, mail, config):
    address = mail.props.email_address
    query = config.get("accountQueries", {}).get(address) or config.get("defaultQuery") or "is:unread in:inbox"
    result = {"email": address, "query": query, "count": 0, "messages": [], "error": ""}
    try:
        conn = connect(obj, mail)
        try:
            conn.select("INBOX", readonly=True)
            uids = search(conn, query)
            result["count"] = len(uids)
            latest = uids[-int(config.get("maxMessages", 20)):]
            if latest:
                _, fetched = conn.uid(
                    "FETCH", b",".join(latest),
                    "(UID X-GM-THRID X-GM-MSGID INTERNALDATE BODY.PEEK[HEADER.FIELDS (FROM SUBJECT)])",
                )
                for part in fetched:
                    if isinstance(part, tuple):
                        result["messages"].append(parse_message(part[0], part[1], address))
            result["messages"].sort(key=lambda m: m["date"], reverse=True)
        finally:
            conn.logout()
    except Exception as e:  # report per account so one failing account doesn't hide the other
        result["error"] = str(e)
    return result


def fetch(config):
    accounts = list(google_accounts())
    with ThreadPoolExecutor(max_workers=max(1, len(accounts))) as pool:
        results = list(pool.map(lambda a: fetch_account(a[0], a[1], config), accounts))
    print(json.dumps({"accounts": results}, ensure_ascii=False))


def mark_read(address, uid=None, query=None):
    """Mark one message (by UID) or every INBOX message matching a Gmail query as read."""
    for obj, mail in google_accounts():
        if mail.props.email_address == address:
            conn = connect(obj, mail)
            try:
                conn.select("INBOX")
                uids = search(conn, query) if query else [str(uid).encode()]
                for i in range(0, len(uids), 500):
                    conn.uid("STORE", b",".join(uids[i:i + 500]), "+FLAGS", "(\\Seen)")
                print(len(uids))
            finally:
                conn.logout()
            return
    sys.exit(f"account {address} not found")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "fetch":
        fetch(json.loads(sys.argv[2]) if len(sys.argv) > 2 else {})
    elif len(sys.argv) == 4 and sys.argv[1] == "mark-read":
        mark_read(sys.argv[2], uid=int(sys.argv[3]))
    elif len(sys.argv) == 4 and sys.argv[1] == "mark-all-read":
        mark_read(sys.argv[2], query=sys.argv[3])
    else:
        sys.exit(__doc__)
