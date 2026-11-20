
import os

from fastapi import APIRouter, HTTPException
from google.auth.transport import requests
from google.oauth2 import id_token

from app.firebase import db

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")


TEST_TEACHER_EMAILS = {
        "likhith.0037@gmail.com",
    }


@router.post("/google")
def google_login(token: str):
    if not GOOGLE_CLIENT_ID:
        raise HTTPException(
            status_code=500,
            detail="Google Client ID is not configured",
        )

    try:
        google_user = id_token.verify_oauth2_token(
            token,
            requests.Request(),
            GOOGLE_CLIENT_ID,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=401,
            detail="Invalid Google ID token",
        ) from exc

    google_id = google_user.get("sub")
    email = str(google_user.get("email") or "").strip().lower()
    name = google_user.get("name")
    profile_photo_url = google_user.get("picture")

    if not google_id or not email:
        raise HTTPException(
            status_code=400,
            detail="Google account information is incomplete",
        )

    
    

    if (
        not email.endswith("@saividya.ac.in")
        and email not in TEST_TEACHER_EMAILS
    ):
        raise HTTPException(
            status_code=403,
            detail="This Google account is not allowed in EduLens",
        )


    # Check the teacher collection first.
    teacher_doc = db.collection("teachers").document(email).get()

    if teacher_doc.exists:
        teacher = teacher_doc.to_dict() or {}

        if teacher.get("role") != "teacher":
            raise HTTPException(
                status_code=403,
                detail="Teacher account is not configured correctly",
            )

        return {
            "message": "Teacher login successful",
            "user": {
                "id": teacher.get("id"),
                "name": name or teacher.get("name", "Teacher"),
                "email": email,
                "role": "teacher",
                "profile_photo_url": profile_photo_url,
            },
        }

    # Preserve the existing student login flow.
    student_doc = db.collection("students").document(email).get()

    if not student_doc.exists:
        raise HTTPException(
            status_code=403,
            detail="Your Google account is not registered in EduLens",
        )

    student = student_doc.to_dict() or {}

    if student.get("role") != "student":
        raise HTTPException(
            status_code=403,
            detail="Student account is not configured correctly",
        )

    return {
        "message": "Google login successful",
        "user": {
            "id": student.get("id"),
            "name": name or student.get("name", "Student"),
            "email": email,
            "role": "student",
            "profile_photo_url": profile_photo_url,
            "usn": student.get("usn"),
            "student_id": student.get("student_id"),
            "department": student.get("department"),
            "semester": student.get("semester"),
            "section_id": student.get("section_id"),
        },
    }
