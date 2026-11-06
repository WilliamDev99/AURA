"""Uji ujung-ke-ujung terhadap project Supabase AURA.

Menjalankan alur nyata lewat REST API dengan sesi anonim biasa, persis seperti
yang dilakukan aplikasi, lalu memastikan penguncinya benar-benar bekerja:
bukti tidak bisa diubah, dan isi peringatan tidak bisa dipalsukan.

Pakai: python tool/verify_supabase.py
"""

import json
import sys
import urllib.error
import urllib.request

URL = "https://fkjdfpbqwaasbabterrd.supabase.co"
KEY = "sb_publishable_YNMkRajPMUK1ZEDV6KoYNA_h7A7kM5a"

OK, FAIL = "  OK  ", " GAGAL"
results = []


def call(method, path, token=None, body=None, prefer=None):
    headers = {"apikey": KEY, "Content-Type": "application/json"}
    headers["Authorization"] = f"Bearer {token or KEY}"
    if prefer:
        headers["Prefer"] = prefer

    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        f"{URL}{path}", data=data, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read().decode()
            return response.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as error:
        raw = error.read().decode()
        try:
            return error.code, json.loads(raw)
        except json.JSONDecodeError:
            return error.code, raw


def check(label, passed, detail=""):
    results.append(passed)
    print(f"[{OK if passed else FAIL}] {label}")
    if detail:
        print(f"         {detail}")


# --- 1. Sesi anonim ----------------------------------------------------------
status, auth = call("POST", "/auth/v1/signup", body={})
token = auth.get("access_token") if isinstance(auth, dict) else None
uid = auth.get("user", {}).get("id") if token else None
check("Login anonim", bool(token), "" if token else str(auth))
if not token:
    sys.exit("Tidak bisa lanjut tanpa sesi.")

# --- 2. Tabel tersedia -------------------------------------------------------
for table in (
    "profiles",
    "families",
    "alerts",
    "evidence",
    "guardian_messages",
    "device_tokens",
):
    status, body = call("GET", f"/rest/v1/{table}?select=*&limit=1", token)
    check(f"Tabel {table}", status == 200, "" if status == 200 else str(body))

# --- 3. Profil dan keluarga --------------------------------------------------
status, body = call(
    "POST",
    "/rest/v1/profiles",
    token,
    {"id": uid, "name": "Uji Bunda", "role": "parent"},
    prefer="return=representation",
)
check("Membuat profil orang tua", status == 201, "" if status == 201 else str(body))

status, body = call(
    "POST",
    "/rest/v1/families",
    token,
    {"name": "Keluarga Uji AURA", "owner_id": uid, "pairing_code": f"T{uid[:5]}"},
    prefer="return=representation",
)
family_id = body[0]["id"] if status == 201 else None
check("Membuat keluarga", bool(family_id), "" if family_id else str(body))
if not family_id:
    sys.exit("Tidak bisa lanjut tanpa keluarga.")

status, body = call(
    "PATCH", f"/rest/v1/profiles?id=eq.{uid}", token, {"family_id": family_id}
)
check("Menautkan profil ke keluarga", status in (200, 204), str(body) if status not in (200, 204) else "")

# --- 4. Peringatan -----------------------------------------------------------
alert = {
    "family_id": family_id,
    "child_id": uid,
    "child_name": "Uji Ayu",
    "risk_level": "high",
    "categories": ["grooming"],
    "source": "messageScan",
    "platform": "Uji",
    "detected_at": "2026-10-17T10:00:00Z",
    "summary": "Peringatan uji coba.",
    "excerpt": "jangan bilang siapa siapa",
    "status": "unread",
}
status, body = call(
    "POST", "/rest/v1/alerts", token, alert, prefer="return=representation"
)
alert_id = body[0]["id"] if status == 201 else None
check("Memunculkan peringatan", bool(alert_id), "" if alert_id else str(body))

# --- 5. Bukti ----------------------------------------------------------------
evidence = {
    "family_id": family_id,
    "child_id": uid,
    "alert_id": alert_id,
    "kind": "messageTranscript",
    "captured_at": "2026-10-17T10:00:00Z",
    "description": "Transkrip uji coba",
    "payload": "jangan bilang siapa siapa ya",
    "content_hash": "a" * 64,
    "chain_hash": "b" * 64,
    "previous_hash": "0" * 64,
    "sequence": 1,
}
status, body = call(
    "POST", "/rest/v1/evidence", token, evidence, prefer="return=representation"
)
evidence_id = body[0]["id"] if status == 201 else None
check("Menyimpan bukti", bool(evidence_id), "" if evidence_id else str(body))

# --- 6. Penguncinya benar-benar bekerja? -------------------------------------
if evidence_id:
    status, body = call(
        "PATCH",
        f"/rest/v1/evidence?id=eq.{evidence_id}",
        token,
        {"description": "DIUBAH OLEH PENYERANG"},
    )
    check(
        "Bukti menolak diubah",
        status >= 400,
        "BAHAYA: bukti bisa diubah!" if status < 400 else f"ditolak ({status})",
    )

    status, body = call("DELETE", f"/rest/v1/evidence?id=eq.{evidence_id}", token)
    check(
        "Bukti menolak dihapus",
        status >= 400,
        "BAHAYA: bukti bisa dihapus!" if status < 400 else f"ditolak ({status})",
    )

if alert_id:
    status, body = call(
        "PATCH",
        f"/rest/v1/alerts?id=eq.{alert_id}",
        token,
        {"summary": "ISI DIPALSUKAN"},
    )
    check(
        "Isi peringatan menolak diubah",
        status >= 400,
        "BAHAYA: isi peringatan bisa dipalsukan!" if status < 400 else f"ditolak ({status})",
    )

    status, body = call(
        "PATCH", f"/rest/v1/alerts?id=eq.{alert_id}", token, {"status": "reviewed"}
    )
    check("Status peringatan boleh diubah orang tua", status in (200, 204), str(body))

# --- 7. Isolasi antar keluarga ----------------------------------------------
status, body = call("GET", "/rest/v1/alerts?select=*", token)
visible = len(body) if isinstance(body, list) else -1
check(
    "Hanya melihat peringatan keluarga sendiri",
    visible == 1,
    f"terlihat {visible} baris (seharusnya 1)",
)

print()
print(f"Hasil: {sum(results)}/{len(results)} lolos")
print(f"Keluarga uji: {family_id}")
sys.exit(0 if all(results) else 1)
