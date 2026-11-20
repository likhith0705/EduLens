
from app.firebase import db

COLLECTION = "students"

STUDENTS = [
    {
        "name": "Lekhana Jain R",
        "email": "lekhanajainr.23ds@saividya.ac.in",
        "usn": "1VA23CD043",  # Duplicate: correct before creating
        "student_id": "demo-lekhana",
        "department": "Data Science",
        "semester": 7,
        "section_id": "A",
    },
    {
        "name": "Nikesh N",
        "email": "nikeshn.23ds@saividya.ac.in",
        "usn": "1VA23CD058",
        "student_id": "demo-nikesh",
        "department": "Data Science",
        "semester": 7,
        "section_id": "A",
    },
    {
        "name": "Darshan H N",
        "email": "darshanhn.23ds@saividya.ac.in",
        "usn": "1VA23CD025",
        "student_id": "demo-darshan",
        "department": "Data Science",
        "semester": 7,
        "section_id": "A",
    },
]


def normalize(value):
    return str(value or "").strip().casefold()


def main():
    existing_docs = list(db.collection(COLLECTION).stream())

    existing_emails = set()
    existing_usns = set()
    existing_student_ids = set()

    for doc in existing_docs:
        data = doc.to_dict() or {}
        existing_emails.add(normalize(doc.id))
        existing_emails.add(normalize(data.get("email")))
        existing_usns.add(normalize(data.get("usn")))
        existing_student_ids.add(normalize(data.get("student_id")))

    next_id = max(
        [
            int((doc.to_dict() or {}).get("id", 0))
            for doc in existing_docs
            if isinstance((doc.to_dict() or {}).get("id"), int)
        ],
        default=0,
    ) + 1

    created = 0

    for student in STUDENTS:
        name = student["name"].strip()
        email = student["email"].strip().lower()
        usn = student["usn"].strip().upper()
        student_id = student["student_id"].strip()

        if not all([name, email, usn, student_id]):
            print(f"SKIPPED: Incomplete record for {email or name}")
            continue

        if normalize(email) in existing_emails:
            print(f"SKIPPED: Email already exists: {email}")
            continue

        if normalize(usn) in existing_usns:
            print(f"SKIPPED: USN already exists: {usn} ({name})")
            continue

        if normalize(student_id) in existing_student_ids:
            print(f"SKIPPED: Student ID already exists: {student_id}")
            continue

        record = {
            "id": next_id,
            "google_id": None,
            "name": name,
            "email": email,
            "role": "student",
            "profile_photo_url": None,
            "usn": usn,
            "student_id": student_id,
            "department": student["department"],
            "semester": student["semester"],
            "section_id": student["section_id"],
        }

        # create() fails if this email document already exists.
        db.collection(COLLECTION).document(email).create(record)

        print(f"CREATED: {name} | {email} | {usn}")

        existing_emails.add(normalize(email))
        existing_usns.add(normalize(usn))
        existing_student_ids.add(normalize(student_id))
        next_id += 1
        created += 1

    print(f"\nFinished. New student records created: {created}")


if __name__ == "__main__":
    main()
