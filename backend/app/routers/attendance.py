
import hashlib
import os
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from google.api_core.exceptions import AlreadyExists
from google.auth.transport import requests
from google.oauth2 import id_token
from pydantic import BaseModel, Field
from firebase_admin import firestore
from typing import Annotated, Literal

from app.firebase import db


router = APIRouter(prefix="/attendance", tags=["Attendance"])

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")

TEST_TEACHER_EMAILS = {
    "likhith.0037@gmail.com",
}




class AttendanceRecord(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    status: Literal["Present", "Absent"]


class AttendanceConfirmation(BaseModel):
    subject: str = Field(min_length=1, max_length=80)
    hour: int = Field(ge=1, le=12)
    class_date: date
    section: str = Field(min_length=1, max_length=40)
    department: str = Field(min_length=1, max_length=100)
    semester: int = Field(ge=1, le=12)
    attendance_records: list[AttendanceRecord] = Field(min_length=1)


def require_attendance_teacher(
    authorization: Annotated[str, Header()],
) -> str:
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="A valid Bearer token is required.",
        )

    if not GOOGLE_CLIENT_ID:
        raise HTTPException(
            status_code=500,
            detail="Google Client ID is not configured.",
        )

    token = authorization.removeprefix("Bearer ").strip()

    try:
        google_user = id_token.verify_oauth2_token(
            token,
            requests.Request(),
            GOOGLE_CLIENT_ID,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired Google ID token.",
        ) from exc

    email = str(google_user.get("email") or "").strip().lower()

    if (
        not email.endswith("@saividya.ac.in")
        and email not in TEST_TEACHER_EMAILS
    ):
        raise HTTPException(
            status_code=403,
            detail="Account is not allowed for teacher access.",
        )

    teacher_doc = db.collection("teachers").document(email).get()

    if not teacher_doc.exists:
        raise HTTPException(
            status_code=403,
            detail="Teacher account is not registered.",
        )

    if (teacher_doc.to_dict() or {}).get("role") != "teacher":
        raise HTTPException(
            status_code=403,
            detail="Teacher access required.",
        )

    return email


@router.get("/sessions")
def get_attendance_sessions(
    department: str | None = None,
    semester: int | None = Query(default=None, ge=1, le=12),
    section: str | None = None,
    limit: int = Query(default=100, ge=1, le=200),
    teacher_email: str = Depends(require_attendance_teacher),
):
    """Return saved attendance sessions for the authenticated teacher."""

    sessions = []

    for doc in db.collection("attendance_sessions").stream():
        data = doc.to_dict() or {}

        # Only return sessions recorded by this teacher.
        if str(data.get("teacher_email", "")).strip().lower() != teacher_email:
            continue

        if department and str(data.get("department", "")).strip().casefold() != department.strip().casefold():
            continue

        if semester is not None:
            try:
                if int(data.get("semester", 0)) != semester:
                    continue
            except (TypeError, ValueError):
                continue

        if section and str(data.get("section", "")).strip().casefold() != section.strip().casefold():
            continue

        # Return plain JSON-compatible session data.
        sessions.append({
            "session_id": doc.id,
            "subject": data.get("subject", ""),
            "hour": data.get("hour"),
            "class_date": data.get("class_date", ""),
            "department": data.get("department", ""),
            "semester": data.get("semester"),
            "section": data.get("section", ""),
            "teacher_email": data.get("teacher_email", ""),
            "total_students": data.get("total_students", 0),
            "present_count": data.get("present_count", 0),
            "absent_count": data.get("absent_count", 0),
            "records": data.get("records", []),
        })

    # Sort newest class date first, then by hour.
    sessions.sort(
        key=lambda item: (
            str(item.get("class_date", "")),
            int(item.get("hour") or 0),
        ),
        reverse=True,
    )

    return {
        "count": len(sessions[:limit]),
        "sessions": sessions[:limit],
    }

@router.get("/{email}")
def get_attendance(email: str):
    email = email.strip().lower()

    student_doc = db.collection("students").document(email).get()
    if not student_doc.exists:
        raise HTTPException(status_code=404, detail="Student not found")

    attendance_doc = db.collection("attendance").document(email).get()

    if not attendance_doc.exists:
        return {
            "email": email,
            "overall_percentage": 0,
            "subjects": [],
        }

    data = attendance_doc.to_dict() or {}

    return {
        "email": email,
        "overall_percentage": data.get("overall_percentage", 0),
        "subjects": data.get("subjects", []),
    }



@router.get("/roster/class")
def get_class_roster(
    department: str,
    semester: int,
    section: str,
    teacher_email: str = Depends(require_attendance_teacher),
):
    """Return registered students belonging to the requested class."""

    department = department.strip()
    section = section.strip()

    if not department or not section:
        raise HTTPException(
            status_code=400,
            detail="Department and section are required.",
        )

    students = []

    for doc in db.collection("students").stream():
        student = doc.to_dict() or {}

        if (
            str(student.get("department", "")).strip().casefold()
            == department.casefold()
            and int(student.get("semester", 0)) == semester
            and str(student.get("section_id", "")).strip().casefold()
            == section.casefold()
        ):
            students.append({
                "email": doc.id,
                "name": student.get("name", "Student"),
                "usn": student.get("usn"),
                "department": student.get("department"),
                "semester": student.get("semester"),
                "section_id": student.get("section_id"),
                "face_registered": False,
            })

    # Add face-registration status without exposing biometric embeddings.
    for student in students:
        registration = (
            db.collection("face_registrations")
            .document(student["email"])
            .get()
        )
        registration_data = registration.to_dict() or {}

        student["face_registered"] = (
            registration.exists
            and registration_data.get("registered") is True
            and registration_data.get("embedding_status") == "completed"
        )

    students.sort(key=lambda item: item["name"].casefold())

    return {
        "department": department,
        "semester": semester,
        "section": section,
        "student_count": len(students),
        "students": students,
    }



@router.post("/confirm")
def confirm_attendance(
    payload: AttendanceConfirmation,
    teacher_email: str = Depends(require_attendance_teacher),
):
    subject = payload.subject.strip()
    section = payload.section.strip()
    department = payload.department.strip()

    if not subject or not section or not department:
        raise HTTPException(
            status_code=400,
            detail="Subject, section and department are required.",
        )

    # Load the authoritative class roster.
    class_students = {}

    for doc in db.collection("students").stream():
        student = doc.to_dict() or {}

        try:
            student_semester = int(student.get("semester", 0))
        except (TypeError, ValueError):
            continue

        if (
            str(student.get("department", "")).strip().casefold()
            == department.casefold()
            and student_semester == payload.semester
            and str(student.get("section_id", "")).strip().casefold()
            == section.casefold()
        ):
            class_students[doc.id.strip().lower()] = student

    if not class_students:
        raise HTTPException(
            status_code=400,
            detail="No registered students found for this class.",
        )

    # Normalize the submitted register and reject duplicates.
    submitted = {}

    for record in payload.attendance_records:
        email = record.email.strip().lower()

        if email in submitted:
            raise HTTPException(
                status_code=400,
                detail=f"Duplicate attendance entry: {email}",
            )

        submitted[email] = record.status

    roster_emails = set(class_students)
    submitted_emails = set(submitted)

    if submitted_emails != roster_emails:
        raise HTTPException(
            status_code=400,
            detail={
                "message": (
                    "Submit exactly one attendance status for every "
                    "student in the selected class."
                ),
                "missing_emails": sorted(roster_emails - submitted_emails),
                "invalid_emails": sorted(submitted_emails - roster_emails),
            },
        )

    records = [
        {
            "email": email,
            "name": class_students[email].get("name", "Student"),
            "status": submitted[email],
        }
        for email in sorted(roster_emails)
    ]

    present_records = [
        record for record in records
        if record["status"] == "Present"
    ]

    absent_records = [
        record for record in records
        if record["status"] == "Absent"
    ]

    # One session per date, subject, hour and section.
    session_key = "|".join([
        payload.class_date.isoformat(),
        subject.casefold(),
        str(payload.hour),
        section.casefold(),
    ])

    session_id = hashlib.sha256(
        session_key.encode("utf-8")
    ).hexdigest()

    session_ref = db.collection("attendance_sessions").document(session_id)

    if session_ref.get().exists:
        raise HTTPException(
            status_code=409,
            detail=(
                "Attendance for this subject, hour, section and date "
                "has already been recorded."
            ),
        )

    # Rebuild attendance summaries from recorded class sessions.
    # Every Present or Absent record contributes one total class.
    # Only Present records contribute to attended classes.
    #
    # This also migrates existing summaries away from the old
    # fixed-40 denominator using the saved session history.

    stats_by_email = {
        email: {}
        for email in class_students
    }

    def add_attendance_record(
        email: str,
        subject_name: str,
        status: str,
    ) -> None:
        email = email.strip().lower()
        subject_name = subject_name.strip()

        if email not in stats_by_email or not subject_name:
            return

        if status not in ("Present", "Absent"):
            return

        subject_key = subject_name.casefold()
        subject_stats = stats_by_email[email].setdefault(
            subject_key,
            {
                "name": subject_name,
                "attendedClasses": 0,
                "totalClasses": 0,
            },
        )

        subject_stats["totalClasses"] += 1

        if status == "Present":
            subject_stats["attendedClasses"] += 1

    # Reconstruct existing counts from saved attendance sessions.
    for old_session_doc in (
        db.collection("attendance_sessions").stream()
    ):
        old_session = old_session_doc.to_dict() or {}
        old_subject = str(old_session.get("subject", "")).strip()

        for old_record in old_session.get("records", []):
            if not isinstance(old_record, dict):
                continue

            add_attendance_record(
                str(old_record.get("email", "")),
                old_subject,
                str(old_record.get("status", "")),
            )

    # Include the session currently being confirmed.
    for record in records:
        add_attendance_record(
            record["email"],
            subject,
            record["status"],
        )

    # Prepare a rebuilt summary for every student in this class,
    # including students marked Absent.
    prepared = []

    for email in class_students:
        attendance_ref = (
            db.collection("attendance").document(email)
        )

        subject_stats = stats_by_email[email]

        subjects = []

        for subject_data in subject_stats.values():
            attended = subject_data["attendedClasses"]
            total = subject_data["totalClasses"]

            subjects.append({
                "name": subject_data["name"],
                "attendedClasses": attended,
                "totalClasses": total,
                "percentage": str(
                    round(attended / total * 100, 2)
                    if total > 0 else 0
                ),
            })

        subjects.sort(
            key=lambda item: item["name"].casefold()
        )

        total_attended = sum(
            item["attendedClasses"] for item in subjects
        )

        total_classes = sum(
            item["totalClasses"] for item in subjects
        )

        overall = (
            round(total_attended / total_classes * 100, 2)
            if total_classes > 0 else 0
        )

        prepared.append({
            "ref": attendance_ref,
            "subjects": subjects,
            "overall_percentage": overall,
        })


    session_data = {
        "session_id": session_id,
        "subject": subject,
        "hour": payload.hour,
        "class_date": payload.class_date.isoformat(),
        "department": department,
        "semester": payload.semester,
        "section": section,
        "teacher_email": teacher_email,
        "total_students": len(records),
        "present_count": len(present_records),
        "absent_count": len(absent_records),
        "records": records,
        "created_at": firestore.SERVER_TIMESTAMP,
    }

    batch = db.batch()
    batch.create(session_ref, session_data)

    for item in prepared:
        batch.set(
            item["ref"],
            {
                "subjects": item["subjects"],
                "overall_percentage": item["overall_percentage"],
            },
            merge=True,
        )

    try:
        batch.commit()
    except AlreadyExists as exc:
        raise HTTPException(
            status_code=409,
            detail="This class session has already been recorded.",
        ) from exc

    return {
        "message": "Attendance register saved successfully.",
        "session_id": session_id,
        "subject": subject,
        "hour": payload.hour,
        "class_date": payload.class_date.isoformat(),
        "department": department,
        "semester": payload.semester,
        "section": section,
        "total_students": len(records),
        "present_count": len(present_records),
        "absent_count": len(absent_records),
        "total_classes": total_classes,
        "records": records,
    }
