from fastapi import APIRouter, HTTPException

from app.firebase import db


router = APIRouter(
    prefix="/students",
    tags=["Students"]
)


@router.get("/{email}")
def get_student_profile(email: str):

    email = email.lower()

    doc = db.collection("students").document(email).get()

    if not doc.exists:
        raise HTTPException(
            status_code=404,
            detail="Student profile not found"
        )

    student = doc.to_dict()

    return {
        "id": student["id"],
        "name": student["name"],
        "email": student["email"],
        "profile_photo_url": student["profile_photo_url"],
        "usn": student["usn"],
        "student_id": student["student_id"],
        "department": student["department"],
        "semester": student["semester"],
        "section_id": student["section_id"],
    }
